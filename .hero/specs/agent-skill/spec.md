---
title: Agent skill
slug: agent-skill
type: feature
status: completed
domain: engineering
size: medium
horizon: now
priority: high
created: 2026-10-11
tags: [omarchy, control4, ipc, agents, skill]
relates-to:
  - in-process-director-rest
  - implemented-experience-allow-list
  - rooms-from-ui-config-join-items
  - plugin-id-from-day-one
  - room-volume-mute-off
  - watch-and-listen
  - experience-switch
  - agent-control-via-plugin-ipc
delivery_method: manual
completed_at: 2026-10-11T12:25:18Z
---
# Agent skill

## Goal

An AI agent (Claude Code, Cursor, Codex) can operate the user's Control4 room through the running plugin: list rooms, focus one, list Watch/Listen sources, select a source, set volume, mute/unmute, turn the room off, and report what is playing. It does this only through new agent-facing methods on the existing `IpcHandler` in `Service.qml`, called as `omarchy-shell io.github.davydotcom.control4 <method> [args]`. A `SKILL.md` ships in the plugin at `skills/control4/SKILL.md`. The user installs it by hand with a README one-liner. Done means every method in the IPC contract below behaves as specified against a live Director, no method ever returns credentials, and an agent with the installed skill can carry out "turn on Apple TV in the great room" end to end.

## Kickoff

Lets AI agents drive the Control4 room through new `omarchy-shell` IPC methods plus a hand-installed `SKILL.md`.

**Status:** delivered. IPC methods, helpers, tests, `SKILL.md`, and README landed; live-checked on the Great Room; skill installed on this machine.

**Pick up at:** nothing left here. Follow-up: `/diagnose` why `SET_VOLUME_LEVEL` doesn't change `CURRENT_VOLUME` in the Great Room on the Great Room Display (affects the panel slider too).

→ `/diagnose great-room-volume-not-applied`

**Files:** `Service.qml:1689`, `DirectorClient.js:426`, `tests/director-client.test.js`, `README.md:67`
**Skip:** auto-install by the plugin (manifests have no skill kind); name-based matching in QML; calling the Director directly from the skill.

## Problem

The user runs this plugin all day and wants their coding agent to handle requests like "turn on Apple TV in the great room", "what's playing", "volume to 30", and "turn the room off". Today an agent has no safe way to do any of that:

- The only IPC surface is a dev harness (`Service.qml:1689-1764`). `status()` dumps navigator debug fields. `browseApple()` and `browseTap(index)` are Apple Music browse probes. None of it can pick a room, pick a source, or change the volume.
- Without a sanctioned surface, an agent would reach for `credentials.json` and curl the Director itself. That breaks `in-process-director-rest` (one in-process session, secrets never in argv or on disk beyond the 0600 state files) and leaks the password into the transcript.
- Omarchy can't install the skill for us. Plugin manifests (`schemaVersion` 1) only have kinds like `service` and `bar-widget`, and `omarchy plugin add`/`validate` have no notion of a skill. The HEY skill at `~/.agents/skills/hey/` is installed by the HEY CLI, not by its plugin. The local convention is `~/.agents/skills/<name>/SKILL.md` as the canonical copy, with `~/.claude/skills/<name>` as a relative symlink to it (`hey -> ../../.agents/skills/hey`).

## Approach

**Control surface = the plugin's own `IpcHandler`.** The service already owns the Director session, token refresh, the curl queue, room and source catalogs, and the 2 s volume/now-playing poll. The new IPC methods are thin wrappers over the same `Service.qml` functions `Panel.qml` calls. They add no new Director endpoints or commands and do no direct HTTP:

| Panel action | Existing service function |
|---|---|
| Room list | `rooms` (built by `DirectorClient.extractRooms`, already limited to the watch/listen allow-list) |
| Tap room | `setFocusedRoom(id)` |
| Watch / Listen tab | `setSourceMode(mode)` |
| Source list | `DirectorClient.extractSources(_uiConfig, _items, focusedRoomId, mode)` (used by `_rebuildSources`) |
| Tap source | `selectSource(id)`, which posts `SELECT_VIDEO_DEVICE` / `SELECT_AUDIO_DEVICE` |
| Volume slider | `setVolume(level)`, which posts `SET_VOLUME_LEVEL` |
| Right-click slider | `toggleMute()`, which posts `MUTE_TOGGLE` |
| Off row | `roomOff()`, which posts `ROOM_OFF` |
| Status line | `roomOn`, `playingSourceName`, `lastDeviceGroup`, `volume`, `muted` (kept fresh by `refreshVolume`) |

**Transport.** Agents call `omarchy-shell io.github.davydotcom.control4 <method> [args…]`. `/usr/bin/omarchy-shell` forwards to `qs ipc call` with a 2 s timeout. If the shell isn't running, or the target or method is missing, it prints a message and exits 1. Every handler is synchronous and only reads in-memory state or enqueues a curl job, so it returns well under the timeout.

**IPC type rules.** Quickshell 0.3.1 `IpcHandler` arguments and returns are limited to `string`/`int`/`bool`/`real`. Every new method takes `string` arguments and returns `string`. This matches the existing `browseTap(index: string)` and every first-party Omarchy target (no target uses `int` args). Parsing happens in our code, so a bad argument gets our error token instead of a raw Quickshell message. `omarchy-shell` exits 0 on such messages, so agents couldn't tell them apart from success.

**Return convention.** A return is exactly one of:

- JSON (first character `{` or `[`) for reads.
- `ok:<detail>` for a change that took effect locally and needed no Director command.
- `started:<detail>` for a Director command that was queued. This is fire-and-forget: the curl callback is `function() {}`, the same as the panel. It means "sent", not "confirmed".
- A bare error token: `not-connected:<sessionState>`, `no-room`, `unknown-room:<arg>`, `bad-mode:<arg>`, `unknown-source:<arg>`, `bad-level:<arg>`, `bad-mute:<arg>`. `not-connected:` and `no-room` are the tokens `browseApple()` already uses.

**Confirming async actions.** The service updates some fields optimistically: `setVolume` sets `volume`, `roomOff` sets `roomOn = false`, `selectSource` sets `roomOn = true` and `playingSourceName`. The poll then corrects them every 2 s, with a 1.5 s hold after a volume set. So a `state` call made right after a `started:` echoes the request, not the Director. The skill tells the agent to wait about 3 s, then call `state` once to confirm.

**Ids, not names, at the IPC layer.** Agents know names; the Director knows ids. Fuzzy matching in QML would pick wrong rooms in edge cases like "Great Room" vs "Great Room Patio". The IPC takes ids only. The skill makes the agent call `rooms` or `sources` first, match the user's words to a `name` case-insensitively, and ask the user when the match is ambiguous or missing.

**`state` is new and `status` stays.** `status()` is the maintainer's debug harness. A shipped spec (`apple-music-could-not-open-browser`) records verification through it, and its navigator fields (`navPhase`, `navDebug`, `tokenAgeSeconds`, …) are noise to an agent. `browseApple()` and `browseTap()` stay as dev probes too: removing them is unrelated churn, they return nothing secret, and the skill tells agents not to use them. Only the comment above the handler changes, to say it now serves both dev and agents.

**Shaping lives in `DirectorClient.js`.** The JSON shaping and argument parsing are pure functions so `tests/director-client.test.js` can cover them, especially the credential whitelist and the `Number("") === 0` trap. If `setVolume("")` went straight to the service, it would set the volume to 0.

**Skill placement.** `skills/control4/SKILL.md` in the repo root. `omarchy-plugin-validate` only rejects symlinks, bad manifests, and missing entry points; extra files and subdirectories are fine. `omarchy plugin add` git-clones the repo, so published installs get the file at `~/.config/omarchy/plugins/io.github.davydotcom.control4/skills/control4/SKILL.md`. The `skills/<name>/SKILL.md` layout mirrors `~/.agents/skills/<name>/SKILL.md`, so install is one copy. A repo-root `skills/` directory isn't auto-discovered by Claude Code, Cursor, or Codex, which use `.claude/skills`, `~/.claude/skills`, and `.agents/skills`.

## IPC contract

Target: `io.github.davydotcom.control4`. All arguments are strings. Methods marked *room-scoped* first check `sessionState === "connected"` (else `not-connected:<sessionState>`) and then check for a focused room (else `no-room`). On either error they send no Director request.

| Method | Args | Success return | Errors | Wraps |
|---|---|---|---|---|
| `state` | none | JSON object (shape below), always, even when not connected | none | reads service properties via `DirectorClient.agentState` |
| `rooms` | none | JSON array `[{"id":13,"name":"Great Room","focused":true}, …]`, sorted by name then id; `[]` while the catalog is still loading | `not-connected:<state>` | `root.rooms` via `DirectorClient.agentRooms` |
| `focusRoom` | `id` | `ok:<id>` | `not-connected:<state>`, `unknown-room:<id>` (non-numeric, or not in `rooms`) | `setFocusedRoom(id)` |
| `sources` | `mode` (`watch` \| `listen`) | JSON array `[{"id":231,"name":"Apple TV"}, …]` for the focused room. Read-only: doesn't change the panel's `sourceMode` | room-scoped errors, `bad-mode:<mode>` | `DirectorClient.extractSources(_uiConfig, _items, focusedRoomId, mode)` |
| `selectSource` | `mode`, `id` | `started:<mode>:<id>` | room-scoped errors, `bad-mode:<mode>`, `unknown-source:<id>` (non-numeric, or not in that mode's list) | `setSourceMode(mode)` if it differs, then `selectSource(id)` |
| `setVolume` | `level` (whole number) | `started:<n>` where `n` is clamped to 0–100 | room-scoped errors, `bad-level:<level>` (empty, non-integer, negative) | `setVolume(n)` |
| `setMute` | `value` (`on` \| `off` \| `toggle`) | `ok:unchanged` when `on`/`off` already matches `muted`; otherwise `started:<on\|off>` | room-scoped errors, `bad-mute:<value>` | `toggleMute()` |
| `off` | none | `started:off` | room-scoped errors | `roomOff()` |
| `status` / `browseApple` / `browseTap` | unchanged | unchanged | unchanged | dev harness, not mentioned in the skill |

`state` shape. Keys are exactly these, built from a whitelist:

```json
{
  "connected": true,
  "sessionState": "connected",
  "statusText": "Connected",
  "roomId": 13,
  "roomName": "Great Room",
  "power": "on",
  "playingGroup": "watch",
  "playingName": "Apple TV",
  "volume": 32,
  "muted": false,
  "hint": ""
}
```

- `power`: `roomOn` mapped `true` → `"on"`, `false` → `"off"`, `null` → `"unknown"`. Off and unknown must stay distinct (`Service.qml:85`).
- `playingGroup`: `lastDeviceGroup` (`"watch"`, `"listen"`, or `""`). `playingName`: `playingSourceName` (`""` when off or unknown).
- `roomId`/`roomName`: `null`/`""` when no room is focused. `hint` is `roomsHint` (e.g. `"Saved room is gone. Pick a room."`).
- Never present: `email`, `password`, `controllerIp`, `_accountToken`, `_directorToken`, `_nav*`, cookie paths, `hasToken`, or token ages.

`selectSource` keeps panel parity on purpose. In Watch it may open the virtual-remote state. In Listen, selecting Apple Music or TuneIn opens the navigator browse session, exactly as tapping the row does. Agents can't drill into stations or playlists (see Boundaries).

## SKILL.md content

File: `skills/control4/SKILL.md`. Required content:

1. **Frontmatter**
   ```yaml
   ---
   name: control4
   description: Control the user's Control4 home AV through the Omarchy Control4 bar plugin — turn on a source (Apple TV, Apple Music, TuneIn radio, other Watch/Listen sources) in a room, say what's playing, set or change volume, mute/unmute, or turn a room off. Use when the user mentions Control4, a room in their house together with TV, music, radio, volume, mute, or "turn off the room", e.g. "turn on Apple TV in the great room", "what's playing", "volume to 30", "turn the room off".
   ---
   ```
2. **How it works**: one paragraph. The running Omarchy shell owns the Control4 session, and the agent talks to it only through `omarchy-shell io.github.davydotcom.control4 <method> [args]`. Returns are JSON, `ok:…`, `started:…`, or an error token.
3. **Commands**: the IPC table above, minus the dev rows, with one example invocation each.
4. **Workflow**: one example per user request:
   - Always run `state` first. If it reports `power`, `playingName`, `volume`, or `roomName`, that answers "what's playing" directly.
   - Room by name: `rooms`, match the name case-insensitively, `focusRoom <id>` only if it differs from `state.roomId`, then tell the user which room is now focused.
   - Source by name: `sources watch` and/or `sources listen`, match the name, `selectSource <mode> <id>`.
   - Volume: use an explicit number as given. For vague requests ("a bit louder") step ±5 from `state.volume`.
   - After any `started:`, wait about 3 seconds, call `state` once, and report the confirmed result.
5. **Safety rules**:
   - Act only on what the user asked. One command per intent. Retry at most once. Never loop or poll.
   - Never guess an id. If the name doesn't match or matches more than one, ask.
   - `off` only when the user explicitly asks to turn the room off. Never as cleanup or a reset.
   - Never set volume above 60, or raise it by more than 20 at once, unless the user said that exact number.
   - `focusRoom` changes the panel's focused room, and it persists. Say so when switching rooms.
   - Never read anything under `~/.local/state/omarchy/io.github.davydotcom.control4/` (including `credentials.json`), never curl `apis.control4.com` or the controller, never try to sign in, never edit `~/.config/omarchy/shell.json`.
   - Don't call `status`, `browseApple`, or `browseTap`. They're maintainer debug methods.
   - Lighting, climate, blinds, scenes, and grouping several rooms at once aren't supported. Say so instead of improvising.
6. **When it can't connect**:
   - `state.connected == false` and `sessionState == "connecting"`: wait 3 s and re-check once.
   - `unconfigured`, `auth-failed`, or `error`: stop and tell the user to open the Control4 chip on the bar and sign in or reconnect from the panel, quoting `statusText`.
   - `omarchy-shell` exits non-zero with "not running" or "Target not found.": the shell isn't running or the plugin is disabled. Tell the user (`omarchy plugin enable io.github.davydotcom.control4`). Don't try to start anything.

## Changes

1. **`DirectorClient.js`**: add four pure helpers next to the room/source helpers (after `extractSources`, around `:530`):
   - `agentState(s)`: takes a plain object `{ sessionState, statusText, focusedRoomId, focusedRoomName, roomOn, lastDeviceGroup, playingSourceName, volume, muted, roomsHint }` and returns the whitelisted `state` object above. Build a new object key by key; never spread or copy `s`. `connected` is `sessionState === "connected"`. `roomId` is a finite number or `null`.
   - `agentRooms(rooms, focusedRoomId)`: maps to `[{ id, name, focused }]`, keeping input order (already sorted by `extractRooms`).
   - `parseVolumeArg(raw)`: returns an integer clamped to 0–100 for `/^\s*\d+\s*$/`, else `null`. `""`, `" "`, `"abc"`, `"30%"`, `"-5"`, and `"3.5"` all return `null`.
   - `parseIdArg(raw)`: returns a number for `/^\s*\d+\s*$/`, else `null`.
2. **`Service.qml` `IpcHandler`** (`:1689-1764`): add `state()`, `rooms()`, `focusRoom(id: string)`, `sources(mode: string)`, `selectSource(mode: string, id: string)`, `setVolume(level: string)`, `setMute(value: string)`, and `off()`, all returning `string`, per the IPC contract.
   - Put the shared guards in one local helper inside the handler, e.g. `function _roomGuard(): string` returning `""` or the error token, used by every room-scoped method.
   - `sources` and `selectSource` accept only `"watch"`/`"listen"`. `selectSource` checks the id against `DirectorClient.extractSources(…, mode)` before calling `root.setSourceMode(mode)` and `root.selectSource(n)`.
   - `setMute`: `on`/`off` compare against `root.muted`. Return `ok:unchanged` or call `root.toggleMute()`. `toggle` always calls it.
   - Leave `status()`, `browseApple()`, and `browseTap()` untouched.
   - Replace the comment at `:1689` with one that says the handler is the agent control surface (see `skills/control4/SKILL.md`) plus dev probes, and that it must never return credentials or tokens. That's a constraint the code can't show.
3. **`tests/director-client.test.js`**: add the four helpers to the destructured import and add cases:
   - `agentState` returns exactly the 11 keys when given an input that also has `password`, `email`, `controllerIp`, `_directorToken`, and `_navClientId`; none of those values appear in `JSON.stringify` output.
   - `agentState` maps `roomOn` `true`/`false`/`null` to `on`/`off`/`unknown`; `connected` is false for `auth-failed`; a missing room gives `roomId: null`.
   - `agentRooms` marks only the focused id.
   - `parseVolumeArg`: `"30"` → 30, `" 7 "` → 7, `"150"` → 100, and `null` for each rejected input listed above.
   - `parseIdArg`: `"13"` → 13, `""` / `"abc"` / `"1.5"` → `null`.
4. **`skills/control4/SKILL.md`** (new): content per the SKILL.md content section above. Plain file, no symlinks.
5. **`README.md`**:
   - New `## Agent skill` section after `## Usage`. Explain that the plugin ships a skill but doesn't install it, then give the published-install one-liner:
     ```sh
     P="$HOME/.config/omarchy/plugins/io.github.davydotcom.control4"
     mkdir -p ~/.agents/skills/control4 ~/.claude/skills
     cp "$P/skills/control4/SKILL.md" ~/.agents/skills/control4/SKILL.md
     ln -sfn ../../.agents/skills/control4 ~/.claude/skills/control4
     ```
     Note that re-running it after a plugin update refreshes the skill. Include a short IPC method list pointing at the skill for the details.
   - `## Local develop`: add `skills/control4/SKILL.md` to the file list, and add `mkdir -p "$PLUGIN_DIR/skills/control4"` plus `cp skills/control4/SKILL.md "$PLUGIN_DIR/skills/control4/"` to the copy block.
   - `## Remove`: add `rm -rf ~/.agents/skills/control4 ~/.claude/skills/control4`. Removing the plugin doesn't remove the skill.
6. **`manifest.json`**: bump `version` `0.6.2` → `0.7.0` (new user-visible IPC surface and shipped skill). No other manifest change; there's no skill kind.

## Boundaries

- **No auto-install.** The plugin never writes to `~/.agents`, `~/.claude`, or `~/.cursor`. The manifest has no skill kind, and the user chose manual install.
- **No login via the agent.** No IPC method takes or returns credentials, and none triggers `connectNow()`, `disconnect()`, or `persistCredentials()`.
- **No new Director calls.** Only the commands the panel already sends (`SELECT_VIDEO_DEVICE`, `SELECT_AUDIO_DEVICE`, `SET_VOLUME_LEVEL`, `MUTE_TOGGLE`, `ROOM_OFF`).
- **Implemented experiences only** (`implemented-experience-allow-list`): Watch and Listen. No lighting, climate, blinds, or scenes. Those are `room-environment` children, and once they exist, exposing them to agents is a follow-up.
- **No multi-room.** One focused room at a time. No grouping or "everywhere" (`multi-room-audio`).
- **No station or playlist browsing** for agents. Apple Music and TuneIn drill-down stays panel-only. `browseApple`/`browseTap` are not part of the agent contract.
- **No remote pad over IPC** (D-pad, transport, numbers, surround). A possible follow-up.
- **No name matching in QML.** Agents resolve names from `rooms` and `sources`.
- **No changes to `Panel.qml` or `BarWidget.qml`.**

## Risks

- **Focus side effect.** `focusRoom` calls `setFocusedRoom`, which persists `focus.json` and moves the panel to that room. This is intended: the agent acts like the user tapping. It may still surprise the user (see open question 1). The skill makes the agent say which room it switched to.
- **Optimistic state.** Reading `state` right after `started:` returns the request, not the Director. The 3 s wait in the skill covers the 2 s poll and the 1.5 s volume hold. Failed POSTs are silent (`function() {}`), the same as in the panel. The agent only sees that the value didn't change, and the skill makes it report that rather than retry repeatedly.
- **Re-selecting the current source while off.** `selectSource` skips the POST when `_alreadyCurrentSource(n)` is true. If the Director still reports the old `CURRENT_VIDEO_DEVICE` while the room is off, "turn on Apple TV" could do nothing. That's existing panel behavior, not fixed here. The confirmation `state` will show `power: "off"`, and the agent reports it. If it reproduces live, it gets its own `/diagnose`.
- **Navigator side effect in Listen.** Selecting Apple Music or TuneIn starts the navigator long-poll, as a panel tap does, and it stays up until browse is closed. This is accepted panel parity.
- **Loud volume.** The volume cap is skill policy, not code. `setVolume 100` from a misbehaving agent will still work. A hard code cap was rejected because the user can legitimately ask for 80.
- **`experience-switch` overlap.** That planned spec adds `experienceModes` to `Service.qml`. Whoever delivers second should switch the `watch`/`listen` checks in `sources`/`selectSource` to that list. The edits touch different regions of the file.
- **Hot reload.** Editing an existing `Service.qml` hot-reloads, but confirm the new functions appear in `qs ipc -n -p /usr/share/omarchy/shell show`. If not, `omarchy restart shell`.

## Open questions

1. **Should focus be restored after an agent action?** The spec leaves the agent's `focusRoom` in place, which is panel parity. Alternative: the skill switches back to the previous room afterwards. Affects AC-6 and AC-15.
2. **Copy or symlink for install?** The spec copies `SKILL.md` into `~/.agents/skills/control4/`, which needs re-running after plugin updates. Alternative: symlink `~/.agents/skills/control4` to the plugin folder's `skills/control4`. That updates automatically but dangles once the plugin is removed. Affects AC-16.
3. **Volume guardrail numbers.** The spec's cap of 60 and +20 per step are placeholder policy. The user may want different limits, or none. Affects AC-15.
4. **New `state` or rename `status`?** The spec adds `state` and leaves `status` alone. Alternative: rename `status` to `debugStatus` and make `status` the agent shape. Affects AC-2 and AC-14.

## Acceptance Criteria

- **AC-1:** THE SYSTEM SHALL expose `state`, `rooms`, `focusRoom`, `sources`, `selectSource`, `setVolume`, `setMute`, and `off` on IPC target `io.github.davydotcom.control4`, with only `string` arguments and a `string` return, as listed by `qs ipc -n -p /usr/share/omarchy/shell show`
- **AC-2:** WHEN `state` is called THE SYSTEM SHALL return a JSON object with exactly the keys `connected`, `sessionState`, `statusText`, `roomId`, `roomName`, `power`, `playingGroup`, `playingName`, `volume`, `muted`, `hint`, regardless of `sessionState`
- **AC-3:** THE SYSTEM SHALL NOT include the email, password, controller IP, account token, director token, navigator ids, or cookie path in the return value of any IPC method
- **AC-4:** IF `rooms`, `focusRoom`, `sources`, `selectSource`, `setVolume`, `setMute`, or `off` is called while `sessionState` is not `connected` THEN THE SYSTEM SHALL return `not-connected:<sessionState>` and enqueue no Director request
- **AC-5:** WHEN `rooms` is called while connected THE SYSTEM SHALL return a JSON array of `{id, name, focused}` built from the service's `rooms` (watch/listen allow-listed), with `focused` true only for `focusedRoomId`
- **AC-6:** WHEN `focusRoom` is called with the id of a room in `rooms` THE SYSTEM SHALL call `setFocusedRoom` with that id and return `ok:<id>`
- **AC-7:** IF `focusRoom` is called with a non-numeric id or an id not in `rooms` THEN THE SYSTEM SHALL return `unknown-room:<id>` and leave `focusedRoomId` unchanged
- **AC-8:** IF `sources`, `selectSource`, `setVolume`, `setMute`, or `off` is called while connected with no focused room THEN THE SYSTEM SHALL return `no-room` and enqueue no Director request
- **AC-9:** WHEN `sources` is called with `watch` or `listen` THE SYSTEM SHALL return a JSON array of `{id, name}` from `DirectorClient.extractSources` for the focused room without changing `sourceMode`, and IF called with any other mode THEN THE SYSTEM SHALL return `bad-mode:<mode>`
- **AC-10:** WHEN `selectSource` is called with `watch` or `listen` and an id in that mode's source list THE SYSTEM SHALL set `sourceMode` to that mode if it differs, call the service's `selectSource(id)`, and return `started:<mode>:<id>`; IF the id is non-numeric or not in that list THEN THE SYSTEM SHALL return `unknown-source:<id>` and post nothing
- **AC-11:** WHEN `setVolume` is called with a whole-number string THE SYSTEM SHALL call the service's `setVolume` with the value clamped to 0–100 and return `started:<n>`; IF the argument is empty, negative, fractional, or non-numeric THEN THE SYSTEM SHALL return `bad-level:<level>` and post nothing
- **AC-12:** WHEN `setMute` is called with `on` or `off` matching the current `muted` THE SYSTEM SHALL return `ok:unchanged` without posting; WHEN it differs, or the value is `toggle`, THE SYSTEM SHALL call `toggleMute()` and return `started:<on|off>`; IF the value is anything else THEN THE SYSTEM SHALL return `bad-mute:<value>`
- **AC-13:** WHEN `off` is called with a focused room while connected THE SYSTEM SHALL call `roomOff()` and return `started:off`
- **AC-14:** THE SYSTEM SHALL keep the signatures and behavior of the existing `status`, `browseApple`, and `browseTap` IPC methods unchanged
- **AC-15:** THE SYSTEM SHALL ship `skills/control4/SKILL.md` with frontmatter `name: control4` and a trigger-phrase `description`, plus sections covering the commands, the list-then-act workflow with a single 3 s confirmation `state`, the safety rules (no credential or state-dir reads, no sign-in, no direct Director calls, `off` only on explicit request, volume guardrail, no dev methods), and not-connected handling
- **AC-16:** THE SYSTEM SHALL document in `README.md` the manual skill install (copy to `~/.agents/skills/control4/SKILL.md` plus the `~/.claude/skills/control4` relative symlink), skill removal, and `skills/control4/SKILL.md` in the local-develop copy list and copy block
- **AC-17:** WHEN `omarchy plugin validate` runs on the live plugin folder containing `skills/control4/SKILL.md` THE SYSTEM SHALL exit 0
- **AC-18:** THE SYSTEM SHALL cover `agentState` (key whitelist and power mapping), `agentRooms`, `parseVolumeArg`, and `parseIdArg` in `tests/director-client.test.js`, and `node tests/director-client.test.js` SHALL pass

## Validation

**Unit:** `node tests/director-client.test.js` covers AC-3 (whitelist), AC-2 (shape), AC-5, AC-11 (parsing), and AC-18.

**Live** (copy files into `$PLUGIN_DIR` per README; `omarchy restart shell` only if the new functions don't show up). Use the `C4` shell variable below:

```sh
C4="omarchy-shell io.github.davydotcom.control4"
qs ipc -n -p /usr/share/omarchy/shell show | rg -A12 control4   # AC-1, AC-14
$C4 state            # AC-2; no secret fields (AC-3)
$C4 rooms            # AC-5
$C4 focusRoom 999999 # unknown-room:999999 (AC-7)
$C4 focusRoom <id>   # ok:<id>; panel shows that room (AC-6)
$C4 sources watch; $C4 sources listen; $C4 sources tv   # AC-9
$C4 selectSource watch <appleTvId>; sleep 3; $C4 state  # power on, playingName Apple TV (AC-10)
$C4 setVolume ""; $C4 setVolume abc; $C4 setVolume 25; sleep 3; $C4 state   # AC-11
$C4 setMute on; $C4 setMute on; $C4 setMute off          # started:on, ok:unchanged, started:off (AC-12)
$C4 off; sleep 3; $C4 state                              # power off (AC-13)
$C4 status; $C4 browseTap abc                            # unchanged output shape, bad-index (AC-14)
```

AC-4 and AC-8: use the panel gear to Disconnect, then call `rooms`, `setVolume 10`, and `off`. Each must return `not-connected:unconfigured`. Reconnect. To test `no-room`, use a house with more than one room and no saved focus, or clear `focus.json` while the shell is stopped.

`omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.davydotcom.control4"` exits 0 (AC-17).

**Skill end to end** (AC-15, AC-16): run the README one-liner, confirm `~/.claude/skills/control4` resolves to `~/.agents/skills/control4`, then in a fresh Claude Code or Cursor session ask, in order: "what's playing in the great room", "turn on Apple TV in the great room", "volume to 30", "mute it", "turn the room off". Each should take a minimal sequence of `omarchy-shell` calls followed by one confirming `state`, with no reads of the state directory.

## Completion Ledger

Delivered with the spec's defaults for the four open questions (user said "deliver it" without answering them): agent `focusRoom` persists, install copies the file, volume guardrail 60 / +20, new `state` beside unchanged `status`.

**Validation**
- `node tests/director-client.test.js` prints `ok` (helpers, credential whitelist, IPC signatures, guard-first ordering).
- `omarchy plugin validate` on the live folder exits 0 with `skills/control4/SKILL.md` present.
- After `omarchy restart shell`, `qs ipc -n -p /usr/share/omarchy/shell show` lists all 11 methods; `_agentRoomGuard` is not exposed.
- Live on the Great Room (user approved): every read and error path, then `focusRoom 13`, `selectSource watch 443`, `setVolume 25`, `setMute on/on/off`, `off`, each confirmed with `state`.

**Finding (pre-existing, not this spec):** in the Great Room with the Great Room Display selected, `SET_VOLUME_LEVEL` did not change `CURRENT_VOLUME` (stayed 62) on two tries, including one 10 s after power-on. The IPC calls the same `root.setVolume` the panel slider calls (`Panel.qml:630`). Needs its own `/diagnose`.

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Expose 8 agent methods, string args/returns | DONE | `Service.qml:1703-1794`; live `qs ipc show` lists them; signature test `tests/director-client.test.js:815` |
| 2 | `state` returns exactly 11 keys regardless of session | DONE | `DirectorClient.agentState` `DirectorClient.js:532`; key-order tests incl. `auth-failed`; live `state` output |
| 3 | No method returns credentials/tokens/nav ids | DONE | whitelist built key by key; leak test with email/password/IP/tokens/nav id/cookie path; static test that agent IPC bodies never reference credential fields |
| 4 | Not connected → `not-connected:<state>`, no request | DONE | `_agentRoomGuard` `Service.qml:1689` checked first in every room-scoped method; `rooms`/`focusRoom` check session first; guard-first ordering asserted in tests. Not exercised live (no IPC disconnect; user approved code+test coverage) |
| 5 | `rooms` returns `{id,name,focused}` | DONE | `agentRooms` `DirectorClient.js:550`; live: 4 rooms, only Great Room focused |
| 6 | `focusRoom` valid id → `setFocusedRoom`, `ok:<id>` | DONE | `Service.qml:1724`; live `focusRoom 13` → `ok:13` |
| 7 | `focusRoom` bad id → `unknown-room:<id>` | DONE | `parseIdArg` + `_roomById`; live `999999` and `abc` → `unknown-room:` |
| 8 | No focused room → `no-room`, no request | DONE | `_agentRoomGuard` second check; asserted in tests. Not exercised live (house always has saved focus) |
| 9 | `sources` read-only list, `bad-mode` | DONE | `Service.qml:1734` uses `extractSources`, never touches `sourceMode`; live watch (4) / listen (13) / `tv` → `bad-mode:tv` |
| 10 | `selectSource` sets mode, selects, `started:`; unknown → `unknown-source` | DONE | `Service.qml:1744`; live `selectSource watch 443` → `started:watch:443`, `state` power on, playing Great Room Display; `999999` → `unknown-source:999999` |
| 11 | `setVolume` clamped `started:<n>`; bad → `bad-level` | DONE | `parseVolumeArg` tests (`""`, `abc`, `30%`, `-5`, `3.5`, clamp 150→100); live bad inputs → `bad-level:`; `setVolume 25` → `started:25` and calls `root.setVolume`. Director not applying the level is the pre-existing finding above |
| 12 | `setMute` on/off/toggle semantics | DONE | `Service.qml:1776`; live `on` → `started:on`, `on` → `ok:unchanged`, `state` muted true, `off` → `started:off`, `loud` → `bad-mute:loud` |
| 13 | `off` → `roomOff()`, `started:off` | DONE | `Service.qml:1788`; live `started:off`, `state` power off |
| 14 | `status`/`browseApple`/`browseTap` unchanged | DONE | bodies untouched in diff; live `status` keys unchanged, `browseTap abc` → `bad-index` |
| 15 | Ship SKILL.md with frontmatter, commands, workflow, safety, not-connected | DONE | `skills/control4/SKILL.md`; session state names match `_setState` values. Fresh-agent conversational run not done (would drive the house again) |
| 16 | README install, removal, local-develop list | DONE | `README.md:85-92,120-152`; one-liner run on this machine, `~/.claude/skills/control4` → `~/.agents/skills/control4`, file identical |
| 17 | `omarchy plugin validate` exits 0 with skill | DONE | live folder validate exit 0 |
| 18 | Helpers covered in tests, suite passes | DONE | `tests/director-client.test.js:772-840`; `node tests/director-client.test.js` → `ok` |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `DirectorClient.js` four pure helpers | DONE | `agentState`, `agentRooms`, `parseVolumeArg`, `parseIdArg` at `:532-575` |
| 2 | `Service.qml` IPC methods + guard + comment | DONE | `_agentRoomGuard` on root (kept off the IpcHandler so it isn't exported); methods `:1703-1794`; comment states the no-credentials constraint |
| 3 | Tests | DONE | helper cases, leak test, IPC signature + guard-ordering static checks |
| 4 | `skills/control4/SKILL.md` | DONE | plain file, no symlinks |
| 5 | README agent skill, local develop, remove | DONE | `## Agent skill`, copy list/block, `rm -rf` in Remove |
| 6 | `manifest.json` 0.6.2 → 0.7.0 | DONE | version only |

### Exercise-the-feature check

- [x] User-visible behavior was exercised end-to-end: live `omarchy-shell io.github.davydotcom.control4 …` calls against the user's Director turned the Great Room on to the Great Room Display, muted/unmuted, and turned it off, each confirmed by `state`; README install one-liner run and symlink verified.

### Excellence Bar self-check

Yes. Thin wrappers over the panel's own functions, no new Director calls, secrets kept out by a tested whitelist, and every error token checked live. The one gap (volume not applying in the Great Room) is pre-existing panel behavior and is called out for a separate diagnosis.
