---
title: Room session model
slug: room-session-model
type: feature
status: planning
domain: engineering
size: medium
horizon: later
parent: multi-room-audio
created: 2026-08-23
tags: [omarchy, control4, multi-room, audio]
---
# Room session model

## Context

First child of `multi-room-audio`. `GET /api/v1/media_sessions` is already known to work and to report `roomids[]` per playing source — it was used to confirm TuneIn playback during `listen-library-browse`. Nothing in the plugin reads it yet. Parent: `.hero/planning/initiatives/multi-room-audio/spec.md`.

## Goal

A parser plus a poll that answers "what is playing, and in which rooms" for the whole house, exposed as session state on the service. No UI in this child.

## Kickoff

Parse and poll `/api/v1/media_sessions` into a rooms-per-session model. No UI.

**Status:** planning — endpoint verified live, nothing implemented.

**Pick up at:** `/design room-session-model`.

→ `/design room-session-model`

**Files:** `DirectorClient.js`, `Service.qml`, `tests/director-client.test.js`

**Skip:** any `Panel.qml` change; adding/removing rooms; per-room volume writes.

## Approach

Follow `parseRoomVolume`: a plain function in the `.pragma library` tested under `node`, plus a poll on the existing `directorGet` queue alongside the volume poll already in `Service.qml`.

The response is an array of sessions carrying `sessionid`, `deviceid`, `roomids[]`, `volume_level`, `muted`, and `mediainfo`. Handle the single-object case the way the MSP parsers do.

Poll cost matters — the focused-room volume poll already runs. `/design` owns the interval and whether this poll only runs while the panel is open.

## Changes

Will be produced by `/design room-session-model`. No file-level Changes until then.

## Boundaries

- No UI
- No writes of any kind
- Do not read or interpret `LINKED_ROOM_LIST` / `*_IS_LINKED` — those are a different concept and belong to no child yet
- Do not replace the focused-room volume poll

## Risks

- Polling the whole house adds Director load on top of the existing volume poll.
- Stale session data will make a later UI show rooms that have dropped out.
- Sessions appear and disappear as playback starts and stops; an empty array is normal, not an error.

## Acceptance Criteria

- WHEN a source is playing THE SYSTEM SHALL expose its session with every room id it covers
- WHEN nothing is playing THE SYSTEM SHALL expose an empty session list rather than an error
- WHEN the response carries a single session object THE SYSTEM SHALL treat it as a one-element list

## Validation

`node tests/director-client.test.js` covers the array, single-object, and empty responses. Against the live Director, the parsed model matches `/api/v1/media_sessions` while a source plays in two rooms.
