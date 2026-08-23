---
title: Room lighting
slug: room-lighting
type: feature
status: planning
domain: engineering
size: medium
horizon: later
priority: medium
parent: room-environment
depends-on:
  - experience-switch
created: 2026-08-23
tags: [omarchy, control4, lighting]
relations:
  - target: experience-switch
    kind: conflicts-with
  - target: room-climate
    kind: conflicts-with
  - target: room-blinds
    kind: conflicts-with
  - target: room-scenes
    kind: conflicts-with
---
# Room lighting

## Context

Second child of `room-environment`. This house has no lighting experience to implement against. Tests already mention a `lights` experience type that `extractRooms` skips. Parent: `.hero/planning/initiatives/room-environment/spec.md`.

## Goal

Lighting controls for the focused room, registered as one more implemented experience mode. Success is a Lights segment that lists or drives that room's lights the way Watch lists sources.

## Kickoff

Add a Lights experience mode for the focused room, after a Director that actually has `lights` is in front of us.

**Status:** planning — stub. No lighting on this Director; do not invent commands.

**Pick up at:** `/design room-lighting` on a house whose `ui_configuration` has `type: "lights"` (or whatever the live type is).

→ `/design room-lighting`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `tests/director-client.test.js`

**Skip:** scenes authoring; whole-house lighting; implementing from memory of Control4 command names.

## Approach

Register `{ id: "lights", label: "Lights" }` (id confirmed live) on `experienceModes` and pass it into `extractRooms`. Handler UI is `/design`'s: likely a list of loads/scenes plus level, but that is a guess until `commands[]` on those items are read.

## Changes

Will be produced by `/design room-lighting`. No file-level Changes until then.

## Boundaries

- No work until live `ui_configuration` shows this experience
- No Composer programming
- No cameras
- Do not rewrite the experience Repeater — only register a mode

## Risks

- Type may not be `lights` on every OS.
- Lighting commands are unpublished here; a guessed POST will no-op or fault the Director.

## Acceptance Criteria

- AC-1: WHEN the focused room has a lights experience THE SYSTEM SHALL show a Lights segment
- AC-2: IF the Director has no lights experience THEN THE SYSTEM SHALL NOT show a Lights segment
- AC-3: WHEN Lights is selected THE SYSTEM SHALL address lighting to the focused room only

## Validation

`/design` starts with a live dump of experience types. Delivery is blocked until that dump exists.
