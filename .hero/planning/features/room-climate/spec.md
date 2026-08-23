---
title: Room climate
slug: room-climate
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
tags: [omarchy, control4, climate]
relations:
  - target: experience-switch
    kind: conflicts-with
  - target: room-lighting
    kind: conflicts-with
  - target: room-blinds
    kind: conflicts-with
  - target: room-scenes
    kind: conflicts-with
---
# Room climate

## Context

Third child of `room-environment`. This house has no comfort/thermostat experience to implement against. Tests already mention `comfort` as a skipped type. Parent: `.hero/planning/initiatives/room-environment/spec.md`.

## Goal

Temperature / HVAC for the focused room as an implemented experience mode. This will not look like a Watch source list — it is a setpoint / mode control. `/design` picks the chrome after reading the item.

## Kickoff

Add a Comfort/temperature mode for the focused room after a Director with that experience is available.

**Status:** planning — stub. No climate on this Director.

**Pick up at:** `/design room-climate` against live `comfort` (or actual type) items and their `commands[]`.

→ `/design room-climate`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`

**Skip:** whole-house HVAC; inventing setpoints; stealing the AV volume slider.

## Approach

Register a mode (leading label "Comfort" or "Temp" — `/design` decides). Do not reuse the source Repeater for setpoints. Volume / Off stay AV chrome.

## Changes

Will be produced by `/design room-climate`. No file-level Changes until then.

## Boundaries

- No work until live `ui_configuration` shows this experience
- Do not bind climate to the volume slider
- Do not rewrite the experience Repeater

## Risks

- Comfort UIs vary by driver (heat/cool/auto, one setpoint vs two). A list-shaped guess will be wrong.
- A comfort-only room must stay hidden until this child ships (`extractRooms` allow-list).

## Acceptance Criteria

- AC-1: WHEN the focused room has a comfort experience THE SYSTEM SHALL show that mode segment
- AC-2: IF the Director has no comfort experience THEN THE SYSTEM SHALL NOT show the segment
- AC-3: THE SYSTEM SHALL NOT use the Watch/Listen source list as the climate control

## Validation

`/design` starts with a live dump. Delivery is blocked until that dump exists.
