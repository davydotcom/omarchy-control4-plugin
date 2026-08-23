---
title: Multi-room audio
slug: multi-room-audio
type: initiative
status: planning
domain: engineering
size: x-large
horizon: later
created: 2026-08-23
tags: [omarchy, control4, multi-room, audio, volume]
relates-to:
  - control4-focused-room-remote
  - room-volume-mute-off
  - room-now-playing
child:
  - room-session-model
  - add-room-to-source
  - multi-room-volume-view
---
# Multi-room audio

## Vision

The plugin is a one-room remote by design, and that is the right V1. But whole-house audio is the thing Control4 is actually for: the same source playing in several rooms, each with its own volume. Today you can only see and adjust the one room you have focused, and there is no way to send what is playing to another room without leaving for the Control4 app.

## Goal

From the panel, add the focused room's playing source to another room, drop a room back out, and see every room currently in that session with its own volume and mute. Success is starting Apple Music on the Office, adding the Deck, and trimming the Deck's volume independently — all without leaving the bar.

## Kickoff

Add rooms to what is playing, and see every room in the session with its own volume.

**Status:** planning — session API verified live; no children designed.

**Pick up at:** `/design room-session-model` — parse `/api/v1/media_sessions` into a rooms-per-session model.

→ `/design room-session-model`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `.hero/planning/initiatives/multi-room-audio/spec.md`

**Skip:** whole-house dashboard; room *groups*/scenes authoring; video multi-room; per-room EQ; replacing the focused-room model.

## What the Director already publishes (verified live)

`GET /api/v1/media_sessions` returns exactly the primitive this initiative needs — one entry per playing source, naming every room it is in:

```json
{ "sessionid": 1018, "deviceid": 434, "roomids": [15],
  "has_discrete_volume": true, "volume_level": 59,
  "has_discrete_mute": true, "muted": false,
  "mediainfo": { "mediatype": "SONG", "artist": "Mt. Joy", "title": "Lucy" } }
```

Observed live with Apple Music in two rooms at once (`"roomids": [14, 15]`), so multi-room state is real and readable, not theoretical. There are 7 rooms on this Director (Mechanical Room, Great Room, Office, Deck, Master Bedroom, Base Fam, Routines).

Room items also carry link state that this initiative must not confuse with sessions: `VOLUME_IS_LINKED`, `MUTE_IS_LINKED`, `ROOMOFF_IS_LINKED`, `LINKED_ROOM_LIST`, `SELECTIONS_LINKED`, `CURRENT_LINKED_MEDIA_SCENE`. Linked rooms are a Composer-configured concept; session membership is a runtime one. They are different things and conflating them will produce a control that lies.

## Specs

Ordered children. `/design` refines each child's internals, not this sequence.

| # | Slug | Status | Size | Horizon | Depends-on | One-liner |
|---|---|---|---|---|---|---|
| 1 | `room-session-model` | planning | small | later | — | Poll and parse `/api/v1/media_sessions` into rooms-per-session; no UI. |
| 2 | `add-room-to-source` | planning | medium | later | `room-session-model` | Add or drop a room from what is playing. |
| 3 | `multi-room-volume-view` | planning | medium | later | `room-session-model` | List every room in the session, each with its own volume and mute. |

## Sequenced work items

1. **Session model** (`room-session-model`) — parser plus a poll, following the existing `parseRoomVolume` convention and the volume poll already in `Service.qml`. Answers "what is playing, where" for the whole house. No UI.
2. **Add a room** (`add-room-to-source`) — the write half. `SELECT_AUDIO_DEVICE` on another room with the same `deviceid` is the obvious candidate and is how the plugin already selects a source, but whether that joins the existing session or starts a second one is **unverified** and this child must confirm it live before building UI.
3. **Multi-room volumes** (`multi-room-volume-view`) — the read half made visible. Each room in the session gets a row with its own slider, using the per-room `CURRENT_VOLUME` / `IS_MUTED` the volume code already reads.

## Open questions for `/design`

- **How a room joins a session.** `SELECT_AUDIO_DEVICE` with the playing `deviceid` is the leading candidate. Alternatives to rule out: a session-level command on `/api/v1/media_sessions/{id}/commands` (known to expose `GET_SESSION`, `SET_VOL_LEVEL`, `TOGGLE_MUTE_STATE` — no documented add-room), or Control4's room-linking variables. Verify with one live call.
- **How a room leaves.** `ROOM_OFF` on that room is the obvious candidate but may do more than drop it from the session.
- **Which volume to drive.** Session `volume_level` is one number for the session; per-room volume is the room item's `CURRENT_VOLUME`. The multi-room view wants the latter. Confirm they do not fight.
- **Poll cost.** The volume poll already runs per focused room. A whole-house session poll adds load; interval and whether it only runs while the panel is open both need deciding.

## Boundaries

- Focused room stays the primary model — this adds a view, it does not replace it
- No whole-house dashboard, no room-group or scene authoring
- No video multi-room
- No per-room EQ, delay, or crossover
- Do not conflate Composer room *linking* with runtime session membership
- No new HTTP client — in-process Director REST only (`in-process-director-rest`)

## Risks

- Adding a room plays audio somewhere a person is. Every write in this initiative is audible in someone else's space; probing needs care and an idle room.
- Session membership and linked-room variables look interchangeable and are not.
- A stale session poll will show rooms that already dropped out, and the volume slider will fight the user the way the focused-room slider did before `volume-slider-reads-room-name`.
- Seven rooms of sliders will not fit the panel alongside everything else; the new scrolling list region helps but layout still needs an answer.

## Acceptance Criteria

- WHEN a source is playing THE SYSTEM SHALL list every room currently in that session
- WHEN the user adds a room THE SYSTEM SHALL play the same source in that room and show it in the session
- WHEN the user adjusts a room's volume THE SYSTEM SHALL change only that room
- WHEN the user drops a room THE SYSTEM SHALL stop that room without stopping the others
- THE SYSTEM SHALL NOT present Composer-linked rooms as session members

## Validation

Live on the Director: start a source in the Office, add the Deck, confirm `/api/v1/media_sessions` reports both room ids, trim the Deck's volume without moving the Office's, then drop the Deck and confirm the Office keeps playing. Parser coverage in `tests/director-client.test.js`.
