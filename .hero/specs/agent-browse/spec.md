---
title: Agent browse
slug: agent-browse
type: feature
status: completed
domain: engineering
size: medium
horizon: now
priority: high
created: 2026-10-11
tags: [omarchy, control4, ipc, agents, skill, apple-music, tunein]
depends-on:
  - agent-skill
relates-to:
  - agent-skill
  - agent-control-via-plugin-ipc
  - listen-library-browse
  - apple-music-could-not-open-browser
  - great-room-volume-not-applied
  - tunein-is-legacy-msp-dialect
  - msp-browse-needs-navigator-session
  - apple-music-browse-not-on-rest
  - in-process-director-rest
delivery_method: manual
completed_at: 2026-10-11T13:11:17Z
---
# Agent browse

## Goal

An AI agent using the installed `control4` skill can play a specific Apple Music station (for example "My Personal Station") or a TuneIn radio station in the focused room. It does this by walking the same Listen browser the panel already uses, through four agent IPC methods on the existing `IpcHandler`: `browse`, `browseTap`, `browseBack`, and `browseClose`. These are thin wrappers over `Service.qml`'s browser. They add no new Director or MSP commands. Done means the unit tests pass, the skill documents a bounded browse workflow, and a fresh agent session can carry out "play my personal station" and "play <local station> on TuneIn" end to end in the focused room.

## Kickoff

Lets the Control4 agent skill browse and play Apple Music stations and TuneIn radio, not just pick the source.

**Status:** planning. Spec written, no code yet.

**Pick up at:** add `browseRowKind` and `agentBrowse` to `DirectorClient.js` next to `agentRooms`, with tests. Then add the IPC methods, moving `browseTap` above `status()`.

→ `/deliver agent-browse`

**Files:** `DirectorClient.js:550`, `Service.qml:586`, `Service.qml:1868`, `tests/director-client.test.js:838`, `skills/control4/SKILL.md`
**Skip:** a new `browseOpen` IPC method (`selectSource listen <id>` already opens the browser); search (neither dialect supports it here); paging Apple lists past 50 rows.

## Problem

The user asked: "Can you make the skill able to browse stations and TuneIn radio stations too, not just Apple Music?" Today an agent can run `selectSource listen 434`, and Apple Music starts with whatever it was last playing. It can't pick a station:

- The skill's Boundaries and Safety rules say station and playlist browsing isn't supported, and they tell agents not to call `browseTap`.
- The only browse IPC is the maintainer's dev probes. `browseApple()` hardcodes Apple Music. `browseTap(index)` returns `tapped:<n>` whether it opened a folder or started playback. It has no session or room guard, taps while a load is in flight, and turns `""` into row 0 (`Number("") === 0`). Nothing tells an agent what is on screen except `status()`, which shows only the first 8 titles and mixes them with navigator debug fields.

The maintainer has shown that the existing browser does the job. After `selectSource listen 434` the rows were `Charts, Stations, Recommendations, History, Library`. Tapping `Stations` showed `Stations By Genre, My Personal Station`. Tapping `My Personal Station` showed `David Estes’ Station`, and tapping that started audio. Agents need a safe, readable way to do the same walk, including on TuneIn (source id 10 in Listen on this house).

## Approach

**Wrap the panel's browser and add nothing beneath it.** `Service.qml` already owns one browser shared by both dialects. Its state is `browseOpen`, `browseBusy`, `browseTitle`, `browseHint`, `browseRows`, `_browseStack`, and `_mspSvc`. Its actions are `openMspBrowse`, `browseTap`, `browseBack`, and `closeBrowse`. The panel's list (`Panel.qml:680-691`) is a view of this same state, so an agent walking the browser moves the panel's list too. This is panel parity, the same as `focusRoom`. Every Director/MSP command used is one the panel already sends.

| Agent need | Existing service code |
|---|---|
| Open the browser at the source's root | `selectSource(id)` → `openMspBrowse(id, svc)` for Apple Music / TuneIn (`Service.qml:320-326`). This runs even when the source is already current (`_alreadyCurrentSource` only skips `SELECT_AUDIO_DEVICE`), so it always opens a fresh root. |
| See what's listed | `browseOpen`, `browseBusy`, `browseTitle`, `browseHint`, `browseRows`, `_browseStack.length`, `_mspSvc` |
| Tap a row | `browseTap(index)` (`Service.qml:586`). For Apple Music: a tab or `BrowseTab` row drills via `Browse`, a row with `mspPlayCommand(row)` plays via `_mspFire` (`Play`/`PlayStation`), and any other row drills via `SelectItem` + `Browse`. For TuneIn: `_tuneInTap` ignores headers, drills tabs and folders via `GetBrowseMenu`, and plays anything else via `BrowseCommand`. |
| Go up one level | `browseBack()`. At the root it calls `closeBrowse()`. |
| Close | `closeBrowse()`. This is local: it stops the navigator long-poll and clears the list. Playback keeps going. |

**No `browseOpen` IPC method.** `selectSource listen <id>` already opens the browser at the root whenever the source is Apple Music or TuneIn, and the agent already has that method. A second opener would duplicate `selectSource` without the source-list validation. To start a walk over, the agent calls `selectSource` again. The trade-off: if the room is playing something else, `selectSource` switches the room's audio to that service before a station is picked. That is what the panel does too, and the user asked for that service anyway.

**Row kind is "what a tap will do", decided by one pure helper.** `DirectorClient.browseRowKind(row)` returns `"header"`, `"folder"`, or `"play"` with the same branch order `Service.qml`'s `browseTap` uses:

| Dialect | `header` | `folder` | `play` |
|---|---|---|---|
| TuneIn (`row.svc === "tunein"`) | `isHeader` | `isTab` or `folder` | everything else (`_tuneInTap` sends `BrowseCommand`) |
| Apple Music MSP (any other row) | never | `defaultAction === "BrowseTab"` or `itemType === "tab"`; otherwise any row where `mspPlayCommand(row)` is `null` (drills via `SelectItem`) | `mspPlayCommand(row)` non-null (`Play` / `PlayStation`) |

This matches the live walk. The `My Personal Station` fixture (`itemType: "link"`, `isLink: true`, `SelectItem`) is `folder`. `David Estes’ Station` (`PlayStation`, `itemType: "stations"`) is `play`. `Service.qml`'s own `browseTap` isn't refactored to call the helper, to keep the change surgical. Instead a static test pins the QML branch conditions the helper mirrors (Changes 3).

**`browse` is a whitelisted read.** `DirectorClient.agentBrowse(s)` builds a new object key by key, like `agentState`:

```json
{"open":true,"busy":false,"service":"apple","title":"My Personal Station","hint":"","depth":2,
 "rows":[{"index":0,"title":"David Estes’ Station","subtitle":"","kind":"play"}]}
```

- Top-level keys, in this order: `open` (`browseOpen`), `busy` (`browseBusy`), `service` (`_mspSvc`: `"apple"`, `"tunein"`, or `""`), `title` (`browseTitle`), `hint` (`browseHint`), `depth` (`_browseStack.length`), and `rows`.
- Row keys, in this order: `index` (the row's position in `browseRows`; header rows keep their index so indexes line up with `browseTap`), `title`, `subtitle` (TuneIn `subtext`; `""` for Apple Music, whose parser doesn't extract one), and `kind`.
- Left out on purpose: `href`, `url`, `guideId`, `image`, `id`, `screenId`/`screen`, `tabId`, `key`, `itemProp`, `isPreset`, `actionsList`, `defaultAction`, `itemType`, the MSP device id, and navigator ids. None of these are secret, but agents don't need them and they bloat output. TuneIn lists can run to hundreds of rows (`Panel.qml:585`).
- Output is compact `JSON.stringify` (no spaces), so `"busy":false` is a stable substring the skill's wait loop can match.
- `browse` always returns JSON, even when not connected, just like `state`. It reads properties and has no side effects.

**`browseTap` takes over the dev probe's name and signature and becomes part of the agent contract.** It keeps `browseTap(index: string): string` but gets the agent rules. Two near-identical tap methods would be confusing, and the maintainer's probe use keeps working, with clearer returns. Checks run in this order, and none of the error cases sends anything:

1. `root._agentRoomGuard()` → `not-connected:<state>` / `no-room`
2. `!root.browseOpen` → `browse-closed`
3. `root.browseBusy` → `browse-busy`. Tapping while a load is in flight would let the pending `_navWaitCb` overwrite the list the agent thinks it is tapping.
4. `DirectorClient.parseIdArg(index)` is `null`, or `n >= root.browseRows.length` → `bad-index:<index>`. This fixes the `""` → row 0 trap.
5. `browseRowKind(row) === "header"` → `header-row:<n>`
6. Call `root.browseTap(n)` and return `started:open:<n>` for `folder` or `started:play:<n>` for `play`. Both use the `started:` prefix because both send a navigator command to the Director (the agent-skill convention: `ok:` means nothing was sent). The middle segment tells the agent what happened.

**`browseBack` and `browseClose` are local and guarded.** Both check `_agentRoomGuard()` first, so every mutating agent method behaves the same way. `browseBack` returns `browse-closed` or `browse-busy` (same stale-callback reason as above). At `depth > 0` it calls `root.browseBack()` and returns `ok:back:<newDepth>`. At depth 0 it calls `root.closeBrowse()` and returns `ok:closed`, matching the panel's Back button. `browseClose` calls `root.closeBrowse()` if open and returns `ok:closed` either way (idempotent). It's allowed while busy because `closeBrowse` clears `_navWaitSeq`/`_navWaitCb`.

**Confirmation is limited, and the skill says so.** `hint: "Playing…"` is set locally the moment a play row is tapped and clears after 1.5 s (`playHintTimer`), so it means "sent". `state` after about 3 s confirms `power: "on"`, `playingGroup: "listen"`, and `playingName` = the source name. The plugin has no now-playing station or track field, so the agent reports "started <title> on <source>" and doesn't claim it confirmed the station. A now-playing field is a separate follow-up.

**Bounded waiting replaces "never poll" for browse only.** Opening the browser can include a navigator handshake. The plugin's own failure path takes 15 s (`browseWaitTimer`) plus up to two reconnect retries before it shows "<Source> did not respond" or "Could not open browser" with `busy: false`. A 10 s agent timeout would report failure while the plugin is still showing "Retrying…". So the skill waits up to 30 s per step: one `browse` read every 2 s. The plugin sometimes reopens the browser at its root on its own (a navigator reconnect while open, `Service.qml:948-951`). The skill therefore checks `depth`/`title` after every wait and restarts the walk once if it got bounced to the root.

## IPC contract

Target: `io.github.davydotcom.control4`. All arguments are strings and every return is a string. The methods from `agent-skill` are unchanged. These are new or changed:

| Method | Args | Success return | Errors (nothing sent) | Wraps |
|---|---|---|---|---|
| `browse` | none | JSON `{open, busy, service, title, hint, depth, rows:[{index, title, subtitle, kind}]}`, always, even when not connected or closed (`open:false`, `service:""`, `rows:[]`) | none | `DirectorClient.agentBrowse` over `browseOpen`, `browseBusy`, `_mspSvc`, `browseTitle`, `browseHint`, `_browseStack.length`, `browseRows` |
| `browseTap` *(promoted from dev probe; same signature)* | `index` | `started:open:<n>` (folder or tab: loading starts, `depth` +1, `busy` true) or `started:play:<n>` (playback command sent) | `not-connected:<state>`, `no-room`, `browse-closed`, `browse-busy`, `bad-index:<index>`, `header-row:<n>` | `root.browseTap(n)` |
| `browseBack` | none | `ok:back:<depth>`, or `ok:closed` when it was at the root | `not-connected:<state>`, `no-room`, `browse-closed`, `browse-busy` | `root.browseBack()` / `root.closeBrowse()` |
| `browseClose` | none | `ok:closed` (also when already closed) | `not-connected:<state>`, `no-room` | `root.closeBrowse()` |
| `selectSource` | unchanged | unchanged. With `listen` and an Apple Music or TuneIn id it opens `browse` at the root (existing behavior, now documented for agents) | unchanged | unchanged |
| `status`, `browseApple` | unchanged | unchanged | unchanged | dev probes, still excluded from the skill |

Old `browseTap` returns `tapped:<n>` and bare `bad-index` are gone. Only the maintainer's dev usage and archived specs referenced them.

## SKILL.md changes

File: `skills/control4/SKILL.md`.

1. **Frontmatter `description`**: add station and radio triggers. Keep everything that is there and add, e.g., "play a specific Apple Music station or playlist, or a TuneIn radio station … e.g. 'play my personal station', 'play WFYI on TuneIn', 'put on some jazz radio'".
2. **How it works / returns list**: add `browse-closed`, `browse-busy`, `bad-index:<i>`, `header-row:<i>` to the error tokens.
3. **Commands table and examples**: add rows for `browse`, `browseTap <index>`, `browseBack`, and `browseClose` per the IPC contract, with one example each. Explain `kind`: `folder` opens a list, `play` starts playback, `header` is a section label and can't be tapped.
4. **New section `## Playing a station or radio`** (after Workflow):
   1. `state` first, focus the room if needed (existing steps). Pick the service: Apple Music for "my station", playlists, and Apple Music stations; TuneIn for "radio", call signs, and frequencies. "Jazz radio" with no service named goes to TuneIn. If the user named a service, use it. Find its id with `sources listen`.
   2. `selectSource listen <id>`. This opens the browser at the source's root, and starts that service in the room if it wasn't already playing.
   3. Wait with one bounded loop, then read the result:
      ```sh
      for i in $(seq 15); do b=$($C4 browse); case "$b" in *'"busy":false'*) break;; esac; sleep 2; done; echo "$b"
      ```
      If `open` is false, or `busy` is still true after the loop, or `hint` ends in "did not respond" or reads "Could not open browser", stop and tell the user, quoting `hint`.
   4. Walk by title. Match the user's words to `rows[].title` case-insensitively, treating ’ and ' as the same. Prefer an exact match, then a single "contains" match. Tap only folders on the path toward what the user asked for, then wait again (step 3). After each wait, check that `title` is the folder you tapped. If `depth` fell back to 0, the plugin reopened the root: restart the walk once.
   5. Play. Tap exactly one `play` row: the one the user named. If a folder the user named holds exactly one `play` row, play it. This is the personal-station case: Stations → My Personal Station → "<Name>’s Station". If several `play` rows match equally, list them and ask.
   6. TuneIn select race: if step 2 switched the room to this service, make sure at least 5 s have passed since `selectSource` before the play tap. Otherwise the station can queue while the room keeps its old audio (`tunein-is-legacy-msp-dialect`).
   7. Confirm: wait about 3 s, call `state` once, and report "started <row title> on <source>" with `power`/`playingName`. Say the plugin can't confirm the exact station. Leave the browser open (panel parity).
   - Known shapes on this house (examples, not guarantees): Apple Music root is `Charts, Stations, Recommendations, History, Library`; Stations has `Stations By Genre` and `My Personal Station`. TuneIn tabs are `Browse` and `My Favorites`; Browse leads to categories such as `Local Radio`.
   - Limits: Apple Music lists show at most the first 50 rows (no paging). There's no search in either service. If what the user asked for isn't in the lists on the path, say so and name a few titles that are there. Don't guess.
5. **Safety rules**:
   - Change "Never loop or poll" to allow exactly the bounded browse wait (≤ 30 s per step, a `browse` read every 2 s).
   - Add: at most 6 `started:open` taps and exactly one `started:play` tap per request. Never tap a `play` row the user didn't ask for, and never tap rows to explore or preview. Don't tap rows that look like settings or account actions (`Settings`, sign in/out, log out, account, remove, delete). Use `browseBack` to leave a wrong folder. Use `browseClose` only when the user asks to close or stop browsing.
   - On `browse-busy`, wait (step 3) instead of retrying the tap. On `bad-index`/`header-row`, re-read `browse`. Never re-send a play tap.
   - Change the dev-method rule to: don't call `status` or `browseApple`.
   - Remove "picking a specific station or playlist" from the unsupported list. Lighting, climate, blinds, scenes, and grouping rooms stay unsupported.

## Changes

1. **`DirectorClient.js`**: add two top-level pure functions after `parseIdArg` (`:570`). The test loads the file into a `vm` context, so they need no export:
   - `browseRowKind(row)`: returns `"header"` / `"folder"` / `"play"` per the kind table. TuneIn branch on `row.svc === "tunein"`. The MSP branch checks `defaultAction`/`default_action === "BrowseTab"` or `itemType === "tab"` → `folder`, then `mspPlayCommand(row)` non-null → `play`, otherwise `folder`. Falsy `row` → `"folder"`; callers bounds-check first.
   - `agentBrowse(s)`: takes `{ browseOpen, browseBusy, mspSvc, browseTitle, browseHint, depth, rows }` and returns the whitelisted `browse` object, building each row as `{ index: i, title: String(r.title || ""), subtitle: String(r.subtitle || ""), kind: browseRowKind(r) }`. Never spread or copy input objects. Use `service` only when `mspSvc` is `"apple"` or `"tunein"`, else `""`. `depth` is a finite non-negative integer, else 0. Non-array `rows` → `[]`.
2. **`Service.qml` `IpcHandler`** (`:1707-1877`):
   - Add `browse(): string`, `browseBack(): string`, and `browseClose(): string`. Move `browseTap(index: string): string` out of the dev-probe area and rewrite it per the IPC contract. Place all four after `off()` and before `status()`, so the existing static "agent IPC methods must not touch credentials" check (`tests/director-client.test.js:870`) covers them.
   - `browse()` passes `root.browseOpen`, `root.browseBusy`, `root._mspSvc`, `root.browseTitle`, `root.browseHint`, `root._browseStack ? root._browseStack.length : 0`, and `root.browseRows` into `DirectorClient.agentBrowse` and returns `JSON.stringify` of the result.
   - `browseTap`, `browseBack`, and `browseClose` start with the exact `var guard = root._agentRoomGuard()` / `if (guard)` / `return guard` preamble the existing tests match.
   - `browseTap` uses `DirectorClient.parseIdArg(index)`, never `Number(index)`, and picks the return from `DirectorClient.browseRowKind(row)` read before calling `root.browseTap(n)`.
   - Update the comment above the handler so the dev probes listed are `status, browseApple` only.
   - Don't change `root.browseTap`, `root.browseBack`, `closeBrowse`, `openMspBrowse`, `status()`, or `browseApple()`.
3. **`tests/director-client.test.js`**: add `browseRowKind` and `agentBrowse` to the import and add cases:
   - `browseRowKind`: Apple tab row from `parseMspTabs` → `folder`. The `My Personal Station` fixture (`:473`) → `folder`. `David Estes’ Station` (`PlayStation`/`stations`) → `play`. A `playlist` itemType row → `play`. TuneIn header → `header`, TuneIn tab from `parseTuneInTabs` → `folder`, TuneIn `folder:true` row → `folder`, TuneIn station row (`:590` fixture) → `play`.
   - `agentBrowse`: exact top-level key order `open, busy, service, title, hint, depth, rows`. Exact row key order `index, title, subtitle, kind`. Indexes keep header positions. A TuneIn row's `subtext` becomes `subtitle`. The JSON never contains a fixture's `href`, `URL`, `guide_id`, `image`, or MSP `id` values. A closed browser gives `open:false, service:"", depth:0, rows:[]`. `mspSvc: "spotify"` gives `service: ""`. `JSON.stringify` output contains `"busy":false` when not busy.
   - Static IPC checks: signatures `function browse(): string`, `function browseTap(index: string): string`, `function browseBack(): string`, `function browseClose(): string`. Add `browseTap(index: string)`, `browseBack()`, and `browseClose()` to the guard-first loop (`:844`). The `browseTap` body contains `DirectorClient.parseIdArg(index)` and `root.browseBusy` and doesn't contain `Number(index)`. The `browseBack` body checks `root.browseBusy`. All four agent browse methods sit before `function status()`.
   - Static drift guard for the kind mirror: `Service.qml`'s `browseTap` still contains `if (row.svc === "tunein")`, `action === "BrowseTab" || kind === "tab"`, and `DirectorClient.mspPlayCommand(row)`, and `_tuneInTap` still contains `if (row.isHeader)` and `if (row.isTab || row.folder)`.
4. **`skills/control4/SKILL.md`**: apply every item in "SKILL.md changes". Plain file, no symlinks.
5. **`README.md`** `## Agent skill`: add "play my personal station" to the example list. Extend the method list with `browse`, `browseTap <index>`, `browseBack`, `browseClose`, with a one-line note that `selectSource listen <id>` opens the Apple Music / TuneIn browser.
6. **`manifest.json`**: bump `version` `0.7.0` → `0.8.0` (new agent IPC surface). Nothing else.

## Acceptance Criteria

- **AC-1:** THE SYSTEM SHALL expose `browse`, `browseTap`, `browseBack`, and `browseClose` on IPC target `io.github.davydotcom.control4` with only `string` arguments and a `string` return, with `browseTap` keeping the signature `browseTap(index: string): string`
- **AC-2:** WHEN `browse` is called THE SYSTEM SHALL return compact JSON with exactly the keys `open`, `busy`, `service`, `title`, `hint`, `depth`, `rows`, in that order, where each row has exactly `index`, `title`, `subtitle`, `kind`, regardless of `sessionState` or whether the browser is open
- **AC-3:** THE SYSTEM SHALL NOT include row hrefs, URLs, guide ids, images, MSP item/screen/tab ids, the MSP device id, navigator ids, or any credential or token in the return value of `browse`, `browseTap`, `browseBack`, or `browseClose`
- **AC-4:** WHEN `browse` reports a TuneIn row THE SYSTEM SHALL set `kind` to `header` for `isHeader` rows, `folder` for tab or `folder` rows, and `play` for every other row
- **AC-5:** WHEN `browse` reports an Apple Music row THE SYSTEM SHALL set `kind` to `folder` for `BrowseTab`/tab rows and for rows whose `mspPlayCommand` is null, and `play` for rows whose `mspPlayCommand` is `Play` or `PlayStation`, matching the action `Service.qml`'s `browseTap` takes for that row
- **AC-6:** IF `browseTap`, `browseBack`, or `browseClose` is called while `sessionState` is not `connected` or with no focused room THEN THE SYSTEM SHALL return `not-connected:<sessionState>` or `no-room` and send no Director request
- **AC-7:** IF `browseTap` is called while the browser is closed, while `browseBusy` is true, with an index that is not a whole number or is out of range, or on a header row THEN THE SYSTEM SHALL return `browse-closed`, `browse-busy`, `bad-index:<index>`, or `header-row:<n>` respectively, and send no Director request
- **AC-8:** WHEN `browseTap` is called on a `folder` row THE SYSTEM SHALL call the service's `browseTap(n)` and return `started:open:<n>`, after which `browse` reports `busy` true and `depth` one higher until the list loads
- **AC-9:** WHEN `browseTap` is called on a `play` row THE SYSTEM SHALL call the service's `browseTap(n)` and return `started:play:<n>`
- **AC-10:** WHEN `browseBack` is called with the browser open and not busy THE SYSTEM SHALL return `ok:back:<depth>` after restoring the previous list when `depth > 0`, or close the browser and return `ok:closed` at depth 0; IF the browser is closed or busy THEN THE SYSTEM SHALL return `browse-closed` or `browse-busy` and change nothing
- **AC-11:** WHEN `browseClose` is called with a focused room while connected THE SYSTEM SHALL call `closeBrowse()` if the browser is open and return `ok:closed`, sending no Director command
- **AC-12:** THE SYSTEM SHALL send no Director or MSP command from the new methods other than those the panel's browser already sends (`GetTabList`, `Browse`, `SelectItem`, `Play`, `PlayStation`, `GetBrowseMenu`, `BrowseCommand`)
- **AC-13:** THE SYSTEM SHALL keep the signatures and behavior of the `status`, `browseApple`, and the eight `agent-skill` IPC methods unchanged
- **AC-14:** THE SYSTEM SHALL ship `skills/control4/SKILL.md` documenting the four browse methods and their tokens, the station/radio workflow (service choice, `selectSource` to open, the 30 s / 2 s bounded wait loop, title matching with apostrophe folding, root-bounce restart, TuneIn 5 s select-before-play, single `state` confirmation that doesn't claim the station), the limits (50-row Apple lists, no paging, no search), and the safety rules (≤ 6 folder taps and exactly one play tap per request, no unrequested or exploratory play taps, no settings/account rows, `status`/`browseApple` still forbidden), with station browsing removed from the unsupported list
- **AC-15:** THE SYSTEM SHALL list `browse`, `browseTap`, `browseBack`, and `browseClose` in `README.md`'s agent skill method list and set `manifest.json` `version` to `0.8.0`
- **AC-16:** THE SYSTEM SHALL cover `browseRowKind` (both dialects), `agentBrowse` (key whitelist, order, closed state), the new IPC signatures, guard-first ordering, the `browseTap` parse/busy checks, and the kind-mirror drift guard in `tests/director-client.test.js`, and `node tests/director-client.test.js` SHALL pass
- **AC-17:** WHEN an agent with the installed skill is asked "play my personal station" with the Great Room focused THE SYSTEM SHALL start the user's Apple Music personal station via `selectSource listen 434` → `Stations` → `My Personal Station` → the single `play` row, using one play tap
- **AC-18:** WHEN an agent with the installed skill is asked to play a named local station on TuneIn THE SYSTEM SHALL start it through `selectSource listen 10` and TuneIn's `Browse` folders with one play tap, and `state` SHALL then report `power: "on"` and `playingName` `TuneIn`

## Validation

**Unit:** `node tests/director-client.test.js` prints `ok`. Covers AC-2–AC-5, AC-16, and statically AC-1, AC-6, AC-7, AC-10 (guard and busy order), and AC-13 (existing signature list).

**Live.** These steps are for the maintainer or the delivering session with the user's go-ahead, because they change what the house plays. First copy files into `$PLUGIN_DIR` per README and re-run the README skill install one-liner. Then:

```sh
C4="omarchy-shell io.github.davydotcom.control4"
qs ipc -n -p /usr/share/omarchy/shell show | rg -A20 control4   # AC-1, AC-13
$C4 browse                       # open:false shape (AC-2, AC-3)
$C4 browseTap 0                  # browse-closed (AC-7)
$C4 browseClose                  # ok:closed (AC-11)
$C4 selectSource listen 434; sleep 1; $C4 browse          # busy:true, hint Connecting…/Loading…
# wait loop from the skill, then:
$C4 browseTap ""; $C4 browseTap abc; $C4 browseTap 999    # bad-index:… (AC-7)
$C4 browseTap <Stations>; $C4 browseTap <Stations>        # started:open:<n>, then browse-busy (AC-7, AC-8)
# wait; browse shows title Stations, depth 1, My Personal Station kind folder (AC-5)
$C4 browseBack                   # ok:back:0, root rows back (AC-10)
# re-tap Stations, then My Personal Station; wait; one play row
$C4 browseTap 0; sleep 3; $C4 state                        # started:play:0; power on, playingName Apple Music (AC-9)
$C4 selectSource listen 10       # TuneIn; wait; browse shows Browse/My Favorites, service tunein
# Browse → Local Radio; a header row: browseTap <header> → header-row:<n> (AC-4, AC-7)
```

AC-6: Disconnect from the panel gear, then call `browseTap 0`, `browseBack`, and `browseClose`. Each must return `not-connected:unconfigured`. Reconnect afterwards.

**Skill end to end** (AC-14, AC-17, AC-18). In a fresh Claude Code or Cursor session with the reinstalled skill, ask "play my personal station in the great room", then "play <a local station, e.g. WFYI> on TuneIn". Each run should use one `selectSource`, bounded wait loops, no more than the needed folder taps, exactly one play tap, and one confirming `state`, with no reads of the state directory and no `status`/`browseApple` calls.

## Boundaries

- **No new Director/MSP commands, endpoints, or parser changes.** No paging (`offset` stays 0, `limit` 50), no search, no Apple Music `subtitle` extraction.
- **No `browseOpen` IPC.** `selectSource listen <id>` is the opener.
- **No change to the panel's browser behavior** (`root.browseTap`, `browseBack`, `closeBrowse`, `openMspBrowse`), and no changes to `Panel.qml` or `BarWidget.qml`.
- **`status` and `browseApple` stay dev-only** and stay out of the skill.
- **No now-playing station or track metadata** (`/api/v1/media_sessions` `mediainfo`). That's a separate follow-up.
- **Only Apple Music and TuneIn.** Amazon Music, SiriusXM, and Spotify don't open a browser here (`_mspServiceOf`), and agents don't get them.
- **No queue/transport actions** (add to queue, skip, shuffle) and no multi-room.

## Risks

- **Shared browser with the panel.** The agent's walk moves the panel's list, and a user tapping the panel mid-walk can shift rows under the agent. Mitigation: the agent reads `browse` right before each tap, and `browse-busy` blocks taps during loads. An index can still go stale if the user taps at the same moment. That's accepted for a single-user desktop. A title-checked tap (`browseTap(index, title)`) is a possible follow-up if it bites.
- **Source switch before a station is found.** `selectSource` starts the service in the room right away. If the station isn't found, the room is left on that service with whatever it resumes. The skill reports this.
- **Root bounce.** A navigator reconnect while the browser is open (token refresh, `Service.qml:1391`, `:948-951`) reopens at the root. The skill detects `depth` 0 and restarts once.
- **Silent play no-op.** `_mspFire` returns early if the navigator id is gone, but the hint still reads "Playing…". `state` can't tell stations apart, so if the room was already on that service a failed play looks like success. Accepted, and the skill wording avoids claiming the station.
- **TuneIn select race** (`tunein-is-legacy-msp-dialect`). Handled by the 5 s rule in the skill. Usually moot, because walking folders takes longer than that.
- **Large TuneIn lists.** Hundreds of rows means tens of KB of JSON per `browse`. That's acceptable for agents. Capping rows would hide matches.
- **Overlap with `experience-switch`** (planning): it also edits `Service.qml`, but in source-mode code, not the IPC browse block. Whoever lands second rebases.
- **Hot reload.** Confirm the new methods appear in `qs ipc … show`. If not, `omarchy restart shell`.

## Open questions

None block delivery. The spec picks these defaults, and the user can override any of them at `/deliver`:

1. **Wait bound of 30 s per step**, rather than the ~10 s first suggested, so agents don't report failure while the plugin is still retrying its navigator connect. Affects AC-14.
2. **Leave the browser open after playing** (panel parity), rather than closing it to stop the navigator long-poll. Affects AC-14.

## Completion Ledger

Delivered all Changes. The open-question defaults were kept: 30 s wait bound and the browser left open after playing.

**Validation**
- `node tests/director-client.test.js` → `ok`.
- `omarchy plugin validate` on the live folder → exit 0. `Service.qml`, `DirectorClient.js`, `README.md`, `manifest.json`, and `skills/control4/SKILL.md` copied to the live plugin; `~/.agents/skills/control4/SKILL.md` refreshed. After `omarchy restart shell`, `qs ipc … show` lists `browse`, `browseTap`, `browseBack`, `browseClose` plus the existing ten methods.
- Live, Great Room 13, user approved (2026-10-11):
  - Browser closed: `browse` → `{"open":false,"busy":false,"service":"","title":"","hint":"","depth":0,"rows":[]}`; `browseTap 0` → `browse-closed`; `browseBack` → `browse-closed`; `browseClose` → `ok:closed`.
  - TuneIn: `selectSource listen 10` → `started:listen:10`; wait loop → root `Browse`/`My Favorites` (folder). `browseTap 0` → `started:open:0` → `Browse` (depth 1, ten folders incl. `Local Radio`). `browseTap 0` → `Local Radio` (depth 2), headers `FM`/`AM`/`Internet Only` as `header`, stations as `play` with subtitles. `browseTap 0` → `header-row:0`. `browseTap 6` (`90.1 / WFYI 90.1 FM (US News)`) 11 s after select → `started:play:6`; `state` → power `on`, playingName `TuneIn`, volume 10.
  - Tokens: `browseTap 999` → `bad-index:999`, `browseTap x` → `bad-index:x`, `browseTap -1` → `bad-index:-1`; `browseBack` at depth 2 → `ok:back:1`.
  - Apple Music: `selectSource listen 434` → root `Charts, Stations, Recommendations, History, Library` (folders). `Stations` → `Stations By Genre`, `My Personal Station` (folders). `My Personal Station` → one row `David Estes’ Station` kind `play`. `browseTap 0` → `started:play:0`; `state` → playingName `Apple Music`, power `on`, volume 10. Left playing, browser left open.
  - Busy: folder tap `Stations By Genre` → immediate `browse` shows `busy:true`, `hint` `Loading…`, `depth` 2, rows `[]`; a second `browseTap 0` and a `browseBack` during the load → `browse-busy`. After the load, `browseBack` → `ok:back:1`.
  - Leak scan of a live `browse` for `http`, `guide`, `Tune.ashx`, `/v1/`, MSP ids, `"id"`, `image`, `nav` → no matches.

| AC | Status | Evidence |
|---|---|---|
| AC-1 | done | `qs ipc show` lists the four methods with string args/returns; test signature list incl. `browseTap(index: string): string` |
| AC-2 | done | test key-order and row key-order asserts; live open, closed, and busy shapes |
| AC-3 | done | test asserts no URL, guide id, image, MSP ids/screens in output; live leak scan clean; credential check covers state()…status() block |
| AC-4 | done | test TuneIn header/tab/folder/station kinds; live Local Radio headers and stations |
| AC-5 | done | test Apple tab, personal-station link, station, playlist, no-play-command row; drift guard on Service browseTap branches; live Stations and personal station kinds |
| AC-6 | done | guard-first static test for browseTap/browseBack/browseClose; live disconnect not run (needs the panel gear), guard shared with the eight agent-skill methods already verified |
| AC-7 | done | live browse-closed, browse-busy, bad-index (999, x, -1), header-row:0; static parse/busy test |
| AC-8 | done | live started:open:0 then busy true, depth 2, Loading… |
| AC-9 | done | live started:play:6 (TuneIn) and started:play:0 (Apple) with state confirming the service |
| AC-10 | done | live ok:back:1 twice, browse-busy during load, browse-closed when closed; static busy check |
| AC-11 | done | live browseClose → ok:closed with browser closed; calls closeBrowse only when open |
| AC-12 | done | new methods only call existing browseTap/browseBack/closeBrowse; no DirectorClient request builders added |
| AC-13 | done | status/browseApple and the eight agent-skill signatures unchanged in qs ipc show and the test list |
| AC-14 | done | SKILL.md: Commands rows and tokens, Playing a station or radio section (service choice, wait loop, apostrophe folding, root-bounce restart, TuneIn 5 s rule, unclaimed confirmation), limits, browse safety rules; station picking removed from unsupported |
| AC-15 | done | README method list and examples; manifest version 0.8.0 |
| AC-16 | done | tests for browseRowKind, agentBrowse, signatures, guard-first, parse/busy, drift guard; `node tests/director-client.test.js` → ok |
| AC-17 | done | cold agent session given only the installed skill and "play my personal station in the great room": state, rooms, sources listen, selectSource listen 434, wait loop, Stations, My Personal Station, browseTap 0 → started:play:0 (2 folder taps, 1 play tap); state → playingName Apple Music, volume 10 |
| AC-18 | done | cold agent session given only the installed skill and "play WFYI on TuneIn in the great room": selectSource listen 10, My Favorites (empty) then back, Browse, Local Radio, browseTap 6 18 s after select → started:play:6 (3 folder taps, 1 play tap); state → power on, playingName TuneIn |

**Post-audit:** the cold audit flagged AC-17/AC-18 as partial (walks run by the delivering session). Both were then re-run by fresh agent sessions given only `~/.agents/skills/control4/SKILL.md` and the user's words; both stayed within the tap limits, used one confirming `state`, and declined to claim the station. The audit's test gap is closed: each of the four browse methods is now asserted to sit between `off()` and `status()`. Room left on Apple Music (personal station) at volume 10.

**Residual risk:** AC-6 was checked statically, not by a live disconnect.
