---
title: Focused room
slug: focused-room
type: feature
status: completed
domain: engineering
size: medium
horizon: now
parent: control4-focused-room-remote
depends-on:
  - director-session
created: 2026-08-21
tags: [omarchy, control4]
relates-to:
  - rooms-from-ui-config-join-items
  - qml-new-file-shell-restart
  - in-process-director-rest
claimed_by: david-estes
claimed_at: 2026-08-23T07:33:51-04:00
completed_at: 2026-08-23T12:28:39Z
---
# Focused room

## Context

Third child of `control4-focused-room-remote`. A Control4 remote always addresses one room; Watch, Listen, volume, and off are relative to that focus ([SR-260](https://docs.control4.com/docs/product/system-remote-control-sr-260/user-guide/english/latest/system-remote-control-sr-260-user-guide-rev-c.pdf)). `director-session` is **completed** (`.hero/specs/director-session/spec.md`): `Service.qml` at repo root owns `sessionState` (`unconfigured | connecting | connected | auth-failed | error`), `directorGet(path, callback)` / `directorPost(path, command, params, callback)`, credentials at `$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json`, and HTTP via short-lived curl `Process` with LAN `-k`. The nested panel is loaded by `BarWidget.qml`; lookup is `bar.shell.serviceFor("io.github.davydotcom.control4")`. Chip text is still scaffold `C4`. Live copy: `~/.config/omarchy/plugins/io.github.davydotcom.control4/`.

Room catalog is **not** `audio_devices`. `GET /api/v1/agents/ui_configuration` experiences have `room_id` but not names or hidden. Home Assistant gets rooms from `GET /api/v1/items` where `typeName === "room"` (`id`, `name`, `roomHidden`). pyControl4 `is_room_hidden` reads variable `ROOM_HIDDEN` on the item — HA's `roomHidden` on the item is the same flag without N extra GETs. Decision: `.hero/knowledge/decisions/rooms-from-ui-config-join-items/spec.md`. Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`.

## Goal

When the Director session is connected, load a flat list of visible AV rooms by joining `ui_configuration` watch/listen experience `room_id`s to `items` rooms, let the user pick one, persist that id in `focus.json` (not `shell.json`, not `credentials.json`), and show the focused room name on the bar chip. Hidden rooms, cameras-only / thermostat-only rooms, and experience ids with no matching item never appear. Later children consume `focusedRoomId` as the only room context. This child does not send Watch, Listen, or volume commands.

## Kickoff

Pick one Control4 room, persist it, show the name on the bar chip.

**Status:** delivering — room list, `focus.json`, and chip name are live (Deck). Login form now behind `credentials-gear`. Composer gone-id / empty-list / single-room auto-select were not live-tapped; user signed off close-out.

**Pick up at:** `hero spec verify focused-room` then `/deliver watch-and-listen`.

→ `hero spec verify focused-room`

**Files:** `Panel.qml`, `Service.qml`, `BarWidget.qml`

**Skip:** `/locations/rooms/.../audio_devices`; new HTTP client; Watch/Listen/volume; floor tree; password in `shell.json`; OS 4.2 workaround.

## Approach

**Catalog = ui_configuration ⋈ items, via existing `directorGet` only.** Do not open a new HTTP client. Do not call `/locations/rooms/.../audio_devices`. When `sessionState` becomes `connected`, call `refreshRooms()` once (not on a timer in this child). `refreshRooms()` is a no-op unless `sessionState === "connected"`. Sequence:

1. `directorGet("/api/v1/agents/ui_configuration", cb)`
2. On success, `directorGet("/api/v1/items", cb)`
3. `JSON.parse` both bodies in `Service.qml`, then `DirectorClient.extractRooms(uiConfig, items)`

The connect probe already GETs `ui_configuration`. Still fetch it again through `directorGet` — do not special-case the probe body.

**Join (all in `DirectorClient.js` — keep QML thin).**

- Candidate ids = unique `experiences[].room_id` where `type` is `"watch"` or `"listen"` (AV remote). Skip cameras-only / thermostat-only / other types. If `uiConfig.experiences` is missing or not an array, candidates are empty.
- `items` must be an array; if the parsed payload is not an array, treat items as empty (do not walk a wrapper object in this child).
- Join to items with `typeName === "room"` and matching `id`. Coerce both sides with `Number(...)`; skip a candidate if the id is not finite.
- Name from `item.name` (`String`, trimmed). If name is missing/blank, skip — do not synthesize `"Room 9"`.
- Hidden if `item.roomHidden` is boolean `true` **or** a truthy string/number (`"1"`, `1`). Drop hidden rooms. If `roomHidden` is missing, treat as visible.
- If an experience `room_id` has no matching room item, skip it.
- Sort the visible list by name (`localeCompare`), then numeric id. Flat list — no floor/location tree.
- Return `[{ id: Number, name: String }, ...]`.

**Service API (contract for later children — this is the point of this child).**

```
property var rooms: []           // [{ id: Number, name: String }, ...]
property var focusedRoomId: null // number or null
property string focusedRoomName: ""
property string roomsHint: ""    // "" | "No rooms" | "Saved room is gone. Pick a room."
function setFocusedRoom(id)
function refreshRooms()          // no-op unless sessionState === "connected"
```

WHILE a focused room is persisted, later children MUST use `focusedRoomId` as the only room context. Do not send Watch/Listen/volume from this child.

**When to load / disconnect.** Hook `onSessionStateChanged` (or equivalent inside `_setState`): if next state is `connected`, call `refreshRooms()`. On disconnect / auth-failed / error / unconfigured: keep the persisted id in memory and in `focus.json`; do not call `refreshRooms()`. The chip falls back to `C4` unless `sessionState === "connected"` **and** the id is in the current visible list. Do not refresh in a loop in this child.

**Focus file load vs first refresh.** `credentials.json` auto-connect can reach `connected` before `focus.json` has been read. Gate the first `refreshRooms()` (or the apply-focus step) on the focus `FileView` having fired `onLoaded` or `onLoadFailed`, same `_credentialsLoaded` pattern. Otherwise a single-room house would auto-select and then get overwritten — or worse, persist over a saved id.

**GET / parse failures.** If either `directorGet` errors or `JSON.parse` throws, keep the previous `rooms` array and do not change focus. Do not treat a transport blip as "No rooms" / gone-id.

**Persistence — not `shell.json`, not `credentials.json`.**

Path: `$HOME/.local/state/omarchy/io.github.davydotcom.control4/focus.json`  
(`stateDir` already on Service + `"/focus.json"`)

Contents when a room is focused: `{ "roomId": 9 }` only (JSON number). No JWT, no password, no name.

- `FileView` with `atomicWrites: true`, `printErrors: false`, write via `setText(JSON.stringify(...) + "\n")` — same as credentials.
- After each write, `chmod 600` via Process (`atomicWrites` may replace the inode). Same dir as credentials, so `mkdir -p` is already done.
- When clearing focus, write `{}` (omit `roomId`) — never leave a stale number.
- Parse in `DirectorClient.js` (`parseFocusFile(raw)` → number or `null`). Invalid JSON / non-finite `roomId` → `null`.
- Never log file contents, tokens, or passwords.

**Selection after `extractRooms`.** Apply in this order in Service (not in the JS join):

1. Visible list empty → `focusedRoomId = null`, `focusedRoomName = ""`, persist `{}`, chip `C4`, `roomsHint = "No rooms"`.
2. Persisted id is in the visible list → restore it (set `focusedRoomId` / `focusedRoomName` from the list row; rewrite file only if needed to keep a number). `roomsHint = ""`.
3. Persisted id is set but missing from the visible list (Composer deleted/hid it) → clear focus (memory + file), chip `C4`, `roomsHint = "Saved room is gone. Pick a room."` Do **not** auto-select another room in this same refresh — the user must pick.
4. No persisted id and exactly one visible room → auto-select it (`setFocusedRoom` / same persist path). Single-room houses. `roomsHint = ""`.
5. No persisted id and two or more rooms → leave focus null, chip `C4`, `roomsHint = ""`, list only. Do not auto-select.

User tap on a room button → `setFocusedRoom(id)`: no-op if `id` is not in `rooms`; otherwise persist `{ "roomId": id }`, update `focusedRoomId` / `focusedRoomName`, clear `roomsHint`.

**Chip (`BarWidget.qml`).**

- Valid focus (`sessionState === "connected"` and non-empty `focusedRoomName`): chip text = room name. Cap painted width at about `Style.space(140)` (media-like `maxLabelWidth`; media uses 180) with `Text.ElideRight`. Tooltip: full name plus session status (`Kitchen — Connected`).
- Without: chip stays `C4`. Tooltip stays session status as today (`Control4 — Connected` / current `statusText`).
- `qs.Ui` `WidgetButton`'s inner `Text` has **no** `elide`. Implement the cap in `BarWidget.qml` (local eliding `Text` and/or clipped width). Do not edit first-party `/usr/share/omarchy/shell/Ui/WidgetButton.qml`.
- Left-click still toggles the nested panel. Do not change `moduleName` / plugin id.

**Panel (`Panel.qml`).**

- First-run still uses the login form (IP / email / password / Connect). After credentials are set, hide that form behind a header gear — owned by `credentials-gear`. Reconnect stays available; the fields are not the connected surface.
- WHEN `sessionState === "connected"`, show a flat `Column` + `Repeater` of `qs.Ui` `Button`s. **Not** `ButtonGroup` (that is a horizontal chip row). `text` = room name; `selected: true` on the focused id; `onClicked` → `session.setFocusedRoom(modelData.id)`.
- Show `roomsHint` when non-empty (`No rooms` / `Saved room is gone. Pick a room.`).
- No Watch/Listen, volume, now-playing.
- Keep title Control4, Escape-to-close, Tab `switchPanel`, `manageIpc: false`, `fittedContentWidth(Style.space(320))`. Height may grow with the list (`fittedContentHeight` already tracks `content.implicitHeight`).

**Live copy.** No new `.qml` filename in this child, so `omarchy-shell shell rescanPlugins` after copy is enough; do **not** force `omarchy restart shell`. If someone does add a new `.qml` file, that restart is required (knowledge `qml-new-file-shell-restart`).

## Changes

1. `DirectorClient.js` — added `extractRooms(uiConfig, items)`, `isRoomHidden(value)` (true for boolean `true`, `"1"`, `1`; false when missing), `sortRoomsByNameThenId` comparator, and `parseFocusFile(raw)` → number or `null`. Existing auth/curl helpers untouched.

2. `Service.qml` — added `rooms`, `focusedRoomId`, `focusedRoomName`, `roomsHint`, `setFocusedRoom(id)`, `refreshRooms()`, `focusPath`, focus `FileView` (`atomicWrites`, dedicated chmod 600 Process). `refreshRooms()` when `sessionState` becomes `connected`, gated on focus FileView `onLoaded`/`onLoadFailed`. mkdir also reloads the focus file. Selection rules applied in `_applyRooms`. GET/parse failures keep previous `rooms`. Disconnect keeps id in memory/file.

3. `Panel.qml` — when connected, shows `roomsHint` if non-empty and a `Column`/`Repeater` of `qs.Ui` `Button`s bound to `session.rooms`, `selected` when ids match, click → `setFocusedRoom`. No `ButtonGroup`. No `directorGet` from the panel. Login-form visibility after credentials are set is `credentials-gear`.

4. `BarWidget.qml` — chip text from `focusedRoomName` when connected with valid focus, else `C4`. Inner WidgetButton label hidden; overlay `Text` with `Text.ElideRight` capped at `Style.space(140)`. Tooltip `<full name> — <statusText>` vs `Control4 — <statusText>`. Left-click still `togglePanel()`. `moduleName` unchanged.

5. `tests/director-client.test.js` — Node fixtures for `extractRooms` / `isRoomHidden` / `parseFocusFile` / `sortRoomsByNameThenId` (hidden skipped, cameras-only skipped, name join, watch+listen dedupe, gone id 99 omitted, sort by name then id, missing/non-array experiences or items → `[]`, missing `roomHidden` visible, parseFocus number vs `{}` / invalid → `null`). Existing assertions kept.

6. `README.md` — chip shows the focused room name (elided); pick the room in the panel when connected; `focus.json` path (no secrets in that file). Usage: after Connect, pick a room; left-click still toggles the panel.

7. Live plugin dir `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/` — copied `DirectorClient.js`, `Service.qml`, `Panel.qml`, `BarWidget.qml`, `README.md` (plus `LICENSE`, `manifest.json` — dir was missing). No new `.qml` filename; `omarchy-shell shell rescanPlugins` only (see `qml-new-file-shell-restart`). Validated the live folder, not the git root.

## Boundaries

- No Watch/Listen source picker or `SELECT_*` commands
- No volume, mute, off, or now-playing
- No floor → location → room tree
- No hidden rooms in the list (`roomHidden` / installer-only spaces)
- Do not use `/locations/rooms/.../audio_devices` as the room catalog
- Do not open a new HTTP client; `directorGet` / `directorPost` on the existing service only
- No password or JWT in `shell.json` or in `focus.json`
- No OS 4.2 JWT workaround
- No lights / climate / shades / cameras UI
- Do not add a new `.qml` filename unless unavoidable (restart tax)

## Risks

- `ui_configuration` without `experiences` (or not an array) → empty list, **No rooms**, not a hang.
- `items` payload not an array → treat as empty; do not guess a wrapper key in this child.
- `roomHidden` vs pyControl4 `ROOM_HIDDEN` variable mismatch — prefer `item.roomHidden`; if the field is missing, treat as visible unless we later learn otherwise. Do not add per-room variable GETs here.
- Long room names on the bar — must elide; tooltip keeps the full name.
- Live plugin dir vs git desync — always copy after editing; validate the live folder.
- Focus file vs auto-connect race — first `refreshRooms` must wait until `focus.json` load attempted, or a single-room auto-select can clobber a saved id.
- Composer hide/delete of the saved room — must clear focus and show **Saved room is gone. Pick a room.**, not a stale name with no recovery.
- Transient GET failure must not look like gone-id (keep previous `rooms`).

## Acceptance Criteria

- WHEN `sessionState` becomes `connected` THE SYSTEM SHALL `directorGet("/api/v1/agents/ui_configuration")` then `directorGet("/api/v1/items")` and SHALL NOT open a new HTTP client
- WHEN those payloads are joined THE SYSTEM SHALL list unique rooms that have a `watch` or `listen` experience, a matching `items` row with `typeName === "room"`, a non-blank `name`, and SHALL omit hidden rooms (`roomHidden` true / `"1"` / `1`) and SHALL omit experience `room_id`s with no matching item
- THE SYSTEM SHALL sort that visible list by name, then id, as a flat list with no floor/location tree
- WHEN the user taps a room in the panel list THE SYSTEM SHALL `setFocusedRoom(id)`, persist `{ "roomId": <id> }` at `$HOME/.local/state/omarchy/io.github.davydotcom.control4/focus.json` (not `shell.json`, not `credentials.json`), and show that room name on the bar chip
- WHEN the visible list has exactly one room and no persisted id THE SYSTEM SHALL auto-select that room
- THE SYSTEM SHALL NOT auto-select when two or more rooms are visible and no id is persisted
- IF the persisted id is missing from the visible list after refresh THEN THE SYSTEM SHALL clear focus in memory and in `focus.json`, set the chip back to `C4`, and show panel copy `Saved room is gone. Pick a room.`
- IF the visible list is empty THEN THE SYSTEM SHALL set the chip to `C4` and show panel copy `No rooms`
- WHEN a valid focused room is connected THE SYSTEM SHALL set chip text to the room name with `Text.ElideRight` at about `Style.space(140)` and tooltip `<full name> — <statusText>`
- WHILE a focused room is persisted THE SYSTEM SHALL expose `focusedRoomId` on the service as the only room context for later children
- THE SYSTEM SHALL keep title `Control4`, Escape-to-close, and left-click panel toggle; chip stays `C4` when there is no valid focused room. First-run shows the login form; after credentials are set, that form is behind the settings gear (`credentials-gear`)

## Validation

`OMARCHY_PATH` on this machine is `/usr/share/omarchy`. Run against the **live** folder, not the git root. There is **no Director in CI**.

```
PLUGIN_ID=io.github.davydotcom.control4
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/Service.qml" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/DirectorClient.js"
node tests/director-client.test.js
omarchy plugin list --json | jq --arg id "$PLUGIN_ID" '.[] | select(.id == $id)'
```

`extractRooms` fixtures in `tests/director-client.test.js` must cover hidden skipped, cameras-only skipped, name join, and gone id not in the list. Plugin list must still show id `io.github.davydotcom.control4`, enabled.

Manual (LAN, after Connect):

1. Room list appears (flat buttons, not a chip `ButtonGroup`).
2. Pick a room → chip text becomes that name (elided if long); tooltip is `Name — Connected`.
3. Close the panel → chip name stays (service kept focus).
4. Hide/delete that room in Composer (or analog: persisted id not in the next join) → chip back to `C4`, panel **Saved room is gone. Pick a room.**
5. Empty join → chip `C4`, panel **No rooms**.
6. Single visible room and empty `focus.json` → auto-selected.
7. Confirm `focus.json` is `{ "roomId": <n> }` mode 600 and `shell.json` has no password / no room id.

Do not invent a CI Director.
