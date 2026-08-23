---
title: Watch and Listen
slug: watch-and-listen
type: feature
status: delivering
domain: engineering
size: medium
horizon: now
parent: control4-focused-room-remote
depends-on:
  - focused-room
created: 2026-08-21
tags: [omarchy, control4]
relates-to:
  - rooms-from-ui-config-join-items
  - room-volume-mute-off
claimed_by: david-estes
---
# Watch and Listen

## Context

Fourth child of `control4-focused-room-remote`. `focused-room` is completed: `focusedRoomId` is the only room context, catalog is `ui_configuration` ⋈ items, HTTP is existing `directorGet` / `directorPost`. On a Control4 remote, Watch and Listen are the same list→select gesture with different source sets ([SR-260](https://docs.control4.com/docs/product/system-remote-control-sr-260/user-guide/english/latest/system-remote-control-sr-260-user-guide-rev-c.pdf)). pyControl4 `get_ui_configuration` documents `experiences[].sources.source[]` with `id` / `type` / optional `name`. Watch HDMI rows often have no `name` — Home Assistant joins `items[id].name`. Select is `SELECT_VIDEO_DEVICE` vs `SELECT_AUDIO_DEVICE` with `{ deviceid }` on `/api/v1/items/{roomId}/commands` ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)).

## Goal

One source-picker. Watch vs Listen only changes the experience filter and the POST command. Sources for the focused room come from `ui_configuration` (already fetched by `refreshRooms`), names joined from the source row or the item. Tap a source → `directorPost` that command. No second HTTP client. No volume in this child.

## Kickoff

One Watch/Listen source picker on the focused room; filter and command change, UI does not.

**Status:** delivering — Deck listen-only auto-flips to Listen; Amazon Music / Apple Music / etc. listed live. Source tap not CLI-clicked.

**Pick up at:** tap a Listen source, then Watch on a video room; `hero spec verify` after live POST.

→ `/deliver watch-and-listen`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `tests/director-client.test.js`

**Skip:** two pickers; `audio_devices`; volume/mute/off; now-playing; cameras; transport.

## Approach

**Catalog is already in memory after `refreshRooms`.** Keep the parsed `ui_configuration` and `items` on the service (`_uiConfig`, `_items`). Do not GET them again for this child. Rebuild the visible source list when `focusedRoomId` or `sourceMode` changes.

**Join (all in `DirectorClient.js`).** `extractSources(uiConfig, items, roomId, mode)`:

- `mode` is `"watch"` or `"listen"` (anything else treated as `"watch"`).
- Find experiences with `type === mode` and `Number(room_id) === Number(roomId)`.
- Sources = `experiences.sources.source`: array, or a single object wrapped as `[obj]`. Missing/non-object → empty.
- Each source: `id` coerced with `Number`; skip non-finite. Dedupe by id.
- Name: `source.name` trimmed; if blank, `items` row with matching `id` (`String(item.name).trim()`). If still blank, skip — do not synthesize `"Unknown Device"`.
- Sort by name then id (`sortRoomsByNameThenId`).
- Return `[{ id: Number, name: String }, ...]`.

**Service API**

```
property string sourceMode: "watch"   // "watch" | "listen"
property var sources: []
property string sourcesHint: ""       // "" | "No watch sources" | "No listen sources"
function setSourceMode(mode)
function selectSource(id)
```

`setSourceMode`: no-op unless `"watch"` or `"listen"`; then rebuild **without** flipping. `selectSource`: no-op if not connected, no focused room, or id not in `sources`. Else `directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, { deviceid: id })` where command is `SELECT_VIDEO_DEVICE` (watch) or `SELECT_AUDIO_DEVICE` (listen). Transport errors do not clear `sources`. Disconnect clears `sources` / `sourcesHint` (keep `sourceMode`). No focused room → empty sources, empty hint (the room list is the prompt).

When applying a new room (focus restore / pick / refresh), if the current mode's list is empty and the other mode has sources, flip `sourceMode` to that other mode so a listen-only room does not open on **No watch sources**. User tapping Watch/Listen still shows the empty state for the mode they chose.

**Panel.** Only when `connected` and `focusedRoomId` is set, below the room list:

- `qs.Ui` `ButtonGroup` with Watch / Listen (`value` bound to `sourceMode`). This is the one mode switch — not two Repeaters.
- `sourcesHint` when non-empty.
- Same `Column`/`Repeater`/`Button` pattern as rooms (`leftAlign`, click → `selectSource`). Not `ButtonGroup` for the source list.

No selected-source highlight in this child (that is now-playing). Keep login gear, room list, Escape, title.

## Changes

1. `DirectorClient.js` — `extractSources` + `sourceArray` helper. Existing join/auth untouched.
2. `Service.qml` — stash `_uiConfig` / `_items` from `refreshRooms`; `sourceMode`, `sources`, `sourcesHint`, `setSourceMode`, `selectSource`; rebuild on focus/mode; disconnect clears sources.
3. `Panel.qml` — ButtonGroup + source Repeater, gated on connected + focused room.
4. `tests/director-client.test.js` — watch vs listen filter, name on source, name from item, blank skipped, other room skipped, single-object `source`, missing sources → `[]`.
5. `README.md` — Watch/Listen after a room is focused.

## Boundaries

- One picker implementation — Watch vs Listen is mode only
- No `audio_devices` / `video_devices`
- No volume, mute, off (sibling `room-volume-mute-off`)
- No now-playing / current-source highlight (`room-now-playing`)
- No cameras, lights, climate, transport, keypad
- Do not open a new HTTP client

## Risks

- Watch HDMI sources without `name` — must join items or the list looks empty.
- `sources.source` as a single object (XML-style JSON) vs array.
- POST with no focused room — must no-op.
- Empty list must say **No watch sources** / **No listen sources**, not reuse **No rooms**.

## Acceptance Criteria

- WHEN the user chooses Watch THE SYSTEM SHALL list `ui_configuration` experiences of type `watch` for `focusedRoomId`
- WHEN the user chooses Listen THE SYSTEM SHALL list experiences of type `listen` for `focusedRoomId`
- WHEN the user selects a Watch source THE SYSTEM SHALL `directorPost` `SELECT_VIDEO_DEVICE` with `{ deviceid }` to `/api/v1/items/{focusedRoomId}/commands`
- WHEN the user selects a Listen source THE SYSTEM SHALL `directorPost` `SELECT_AUDIO_DEVICE` with `{ deviceid }` to that same path
- THE SYSTEM SHALL use one source-picker for both modes
- IF a source has no name on the experience THEN THE SYSTEM SHALL use the matching item `name`, and SHALL skip the source if that is also blank
- IF there is no focused room THE SYSTEM SHALL hide the Watch/Listen picker
- IF the filtered list is empty THE SYSTEM SHALL show `No watch sources` or `No listen sources`

## Validation

```
node tests/director-client.test.js
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.davydotcom.control4"
omarchy plugin validate "$PLUGIN_DIR"
```

Copy `DirectorClient.js` `Service.qml` `Panel.qml` `README.md` to the live dir. Nested `Panel.qml` is Loader-sourced — `omarchy restart shell` after copy (knowledge `qml-new-file-shell-restart`).

Manual: focused room → Watch list → tap a source (video path). Switch Listen → different list → tap (audio path). Unfocused: picker hidden.
