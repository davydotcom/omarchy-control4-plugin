---
title: Add room to source
slug: add-room-to-source
type: feature
status: planning
domain: engineering
size: medium
horizon: later
parent: multi-room-audio
depends-on:
  - room-session-model
created: 2026-08-23
tags: [omarchy, control4, multi-room, audio]
---
# Add room to source

## Context

Second child of `multi-room-audio` and the write half of the initiative. Parent: `.hero/planning/initiatives/multi-room-audio/spec.md`.

## Goal

From the panel, send what the focused room is playing to another room, and drop a room back out, with the session view reflecting it.

## Kickoff

Add another room to what is playing, and drop it back out.

**Status:** planning — the join mechanism is unverified and blocks UI work.

**Pick up at:** `/design add-room-to-source`. Confirm live how a room joins a session before building UI.

→ `/design add-room-to-source`

**Files:** `Service.qml`, `Panel.qml`

**Skip:** room groups/scenes; whole-house "everywhere" button; video multi-room.

## Approach

**Unverified, and this child must settle it first.** `SELECT_AUDIO_DEVICE` on the target room with the playing `deviceid` is the leading candidate — it is exactly what `selectSource` already posts, just aimed at another room. What is not known is whether that *joins* the existing session or starts a second independent one. `/api/v1/media_sessions` after the call answers it: one session with two room ids means join, two sessions means not.

Alternatives to rule out if that fails: a session-level command (the session endpoint is known to expose only `GET_SESSION`, `SET_VOL_LEVEL`, `TOGGLE_MUTE_STATE`), or Control4's room-linking variables — the latter is Composer configuration, not a runtime control, and should not be written by this plugin.

For dropping a room, `ROOM_OFF` on that room is the candidate; confirm it does not stop the others.

## Changes

Will be produced by `/design add-room-to-source`. No file-level Changes until then.

## Boundaries

- No room groups, scenes, or "play everywhere"
- No writes to `LINKED_ROOM_LIST` or any `*_IS_LINKED` variable
- No video multi-room
- Does not change how the focused room is chosen

## Risks

- **Every action in this child is audible in a room someone may be sitting in.** Probe against an idle room and confirm with the user before testing on occupied ones.
- A join that silently starts a second session produces two independent streams and a confusing UI.
- `ROOM_OFF` may do more than leave the session.
- Adding a room at that room's last volume can be startlingly loud. Consider what volume a joining room lands at.

## Acceptance Criteria

- WHEN the user adds a room THE SYSTEM SHALL play the focused room's source there and show it as part of the same session
- WHEN the user drops a room THE SYSTEM SHALL stop that room and leave the others playing
- IF nothing is playing THE SYSTEM SHALL NOT offer to add a room

## Validation

Live: start a source in the Office, add the Deck, confirm `/api/v1/media_sessions` reports one session with both room ids, then drop the Deck and confirm the Office keeps playing.
