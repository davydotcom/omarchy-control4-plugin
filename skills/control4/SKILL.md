---
name: control4
description: Control the user's Control4 home AV through the Omarchy Control4 bar plugin — turn on a source (Apple TV, Apple Music, TuneIn radio, other Watch/Listen sources) in a room, play a specific Apple Music station or playlist or a TuneIn radio station, say what's playing, set or change volume, mute/unmute, or turn a room off. Use when the user mentions Control4, a room in their house together with TV, music, a station, radio, volume, mute, or "turn off the room", e.g. "turn on Apple TV in the great room", "play my personal station", "play WFYI on TuneIn", "put on some jazz radio", "what's playing", "volume to 30", "turn the room off".
---

# Control4

## How it works

The running Omarchy shell owns the Control4 session through the Control4 bar
plugin (`io.github.davydotcom.control4`). You talk to it only through its IPC
target:

```sh
omarchy-shell io.github.davydotcom.control4 <method> [args]
```

Every method returns one line on stdout, which is one of:

- JSON (`{…}` or `[…]`) for reads
- `ok:<detail>` — took effect locally, nothing sent to the controller
- `started:<detail>` — command sent to the controller. Sent, **not** confirmed
- an error token: `not-connected:<state>`, `no-room`, `unknown-room:<id>`,
  `bad-mode:<mode>`, `unknown-source:<id>`, `bad-level:<level>`, `bad-mute:<value>`,
  `browse-closed`, `browse-busy`, `bad-index:<index>`, `header-row:<index>`

The plugin acts on one **focused room** at a time, the same room shown in the
bar panel.

## Commands

All arguments are plain strings. Ids are numbers taken from `rooms` / `sources`.

| Method | Args | Returns |
|---|---|---|
| `state` | none | `{"connected","sessionState","statusText","roomId","roomName","power","playingGroup","playingName","volume","muted","hint"}` |
| `rooms` | none | `[{"id","name","focused"}]` |
| `focusRoom` | `id` | `ok:<id>` or `unknown-room:<id>` |
| `sources` | `watch` or `listen` | `[{"id","name"}]` for the focused room |
| `selectSource` | `watch`/`listen`, `id` | `started:<mode>:<id>` or `unknown-source:<id>` |
| `setVolume` | whole number 0–100 | `started:<n>` or `bad-level:<level>` |
| `setMute` | `on`, `off`, or `toggle` | `started:on` or `started:off` (always sent) |
| `off` | none | `started:off` |
| `browse` | none | `{"open","busy","service","title","hint","depth","rows":[{"index","title","subtitle","kind"}]}` |
| `browseTap` | row `index` | `started:open:<n>` (folder opening) or `started:play:<n>` (playback sent) |
| `browseBack` | none | `ok:back:<depth>`, or `ok:closed` at the top |
| `browseClose` | none | `ok:closed` |

`power` in `state` is `on`, `off`, or `unknown`. `playingGroup` is `watch`,
`listen`, or empty.

`browse` shows the Apple Music / TuneIn menu that `selectSource listen <id>`
opens (the same list the bar panel shows). `service` is `apple`, `tunein`, or
empty. Row `kind`: `folder` opens a list, `play` starts playback, `header` is a
section label and can't be tapped. `depth` is how many folders deep you are.

Examples:

```sh
C4="omarchy-shell io.github.davydotcom.control4"
$C4 state
$C4 rooms
$C4 focusRoom 13
$C4 sources watch
$C4 selectSource watch 231
$C4 setVolume 30
$C4 setMute on
$C4 off
$C4 browse
$C4 browseTap 1
$C4 browseBack
$C4 browseClose
```

## Workflow

1. **Always run `state` first.** For "what's playing" / "is the TV on" /
   "what's the volume", answer from `state` (`roomName`, `power`,
   `playingName`, `volume`, `muted`) and stop.
2. **Room by name:** run `rooms`, match the user's words to a `name`
   case-insensitively. Call `focusRoom <id>` only if it differs from
   `state.roomId`, and tell the user which room is now focused. No room named
   means the currently focused room.
3. **Source by name:** run `sources watch` and/or `sources listen`, match the
   name, then `selectSource <mode> <id>`. TVs, Apple TV, cable boxes are usually
   `watch`; Apple Music, TuneIn / radio, and other audio are `listen`.
4. **Volume:** use an explicit number as given. For vague requests ("a bit
   louder", "turn it down") step ±5 from `state.volume`.
5. **After turning a room on:** when `selectSource` powered the room on, wait
   until `state.power` is `on`, then about 5 seconds more, before `setVolume` or
   `setMute`. Volume can take up to ~10 seconds to show after a power-on.
6. **Confirm:** after any `started:` reply, wait about 3 seconds, call `state`
   once, and report the confirmed result. If the value did not change, report it
   as unconfirmed rather than re-sending. Some rooms (often a TV's own speakers)
   ignore exact volume levels.

## Playing a station or radio

1. `state` first, and focus the room if needed (Workflow steps 1–2). Pick the
   service: **Apple Music** for "my station", playlists, and Apple Music
   stations; **TuneIn** for "radio", call signs, and frequencies. "Jazz radio"
   with no service named means TuneIn. If the user named a service, use it.
   Find its id with `sources listen`.
2. `selectSource listen <id>`. This opens the browser at the service's top
   menu, and starts that service in the room if it wasn't already playing.
3. Wait with one bounded loop (up to 30 s, a `browse` read every 2 s), then read
   the result:
   ```sh
   for i in $(seq 15); do b=$($C4 browse); case "$b" in *'"busy":false'*) break;; esac; sleep 2; done; echo "$b"
   ```
   If `open` is false, `busy` is still true after the loop, or `hint` ends in
   "did not respond" or reads "Could not open browser", stop and tell the user,
   quoting `hint`.
4. **Walk by title.** Match the user's words to `rows[].title`
   case-insensitively, treating ’ and ' as the same. Prefer an exact match, then
   a single "contains" match. Tap only `folder` rows on the path toward what the
   user asked for, then wait again (step 3). After each wait, check that `title`
   is the folder you tapped. If `depth` fell back to 0, the plugin reopened the
   top menu: restart the walk once.
5. **Play.** Tap exactly one `play` row: the one the user named. If a folder the
   user named holds exactly one `play` row, play it (the personal-station case:
   Stations → My Personal Station → "<Name>’s Station"). If several `play` rows
   match equally, list them and ask.
6. **TuneIn timing:** if step 2 switched the room to TuneIn, make sure at least
   5 s have passed since `selectSource` before the play tap, or the station can
   queue while the room keeps its old audio.
7. **Confirm:** wait about 3 s, call `state` once, and report "started <row
   title> on <source>" with `power` / `playingName`. The plugin can't confirm
   which station is playing, so don't claim it did. Leave the browser open.

Known shapes on this house (examples, not guarantees): the Apple Music top menu
is `Charts, Stations, Recommendations, History, Library`; Stations has
`Stations By Genre` and `My Personal Station`. TuneIn's tabs are `Browse` and
`My Favorites`; Browse leads to categories such as `Local Radio`.

Limits: Apple Music lists show at most the first 50 rows (no paging), and
neither service has search here. If what the user asked for isn't in the lists
on the path, say so and name a few titles that are there. Don't guess.

## Safety rules

- Act only on what the user asked. One command per intent. Retry at most once.
  Never loop or poll, except the bounded `browse` wait above (≤ 30 s per step,
  one read every 2 s).
- Browsing: at most 6 `started:open` taps and exactly one `started:play` tap
  per request. Never tap a `play` row the user didn't ask for, and never tap
  rows to explore or preview. Don't tap rows that look like settings or account
  actions (Settings, sign in/out, log out, account, remove, delete). Use
  `browseBack` to leave a wrong folder; use `browseClose` only when the user
  asks to close or stop browsing.
- On `browse-busy`, wait (step 3) instead of retrying the tap. On `bad-index`
  or `header-row`, re-read `browse`. Never re-send a play tap.
- Never guess an id. If a name does not match, or matches more than one room or
  source, ask the user.
- Call `off` only when the user explicitly asks to turn the room off. Never as
  cleanup or a reset.
- Never set volume above 60, or raise it by more than 20 in one step, unless the
  user said that exact number.
- `focusRoom` changes the panel's focused room and it persists. Say so when you
  switch rooms.
- Never read anything under
  `~/.local/state/omarchy/io.github.davydotcom.control4/` (including
  `credentials.json`), never curl `apis.control4.com` or the controller, never
  try to sign in, never edit `~/.config/omarchy/shell.json`.
- Do not call `status` or `browseApple`. They are maintainer debug methods.
- Lighting, climate, blinds, scenes, and grouping several rooms are not
  supported. Say so instead of improvising.

## When it can't connect

- `state.connected` is false and `sessionState` is `connecting`: wait 3 seconds
  and check `state` once more.
- `sessionState` is `unconfigured`, `auth-failed`, or `error`: stop. Tell the
  user to click the Control4 mark on the bar and sign in or reconnect from the
  panel, quoting `statusText`.
- `omarchy-shell` exits non-zero saying the shell is not running or
  "Target not found.": the shell is down or the plugin is disabled. Tell the
  user (`omarchy plugin enable io.github.davydotcom.control4`). Do not try to
  start anything.
