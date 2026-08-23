---
title: Room blinds
slug: room-blinds
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
tags: [omarchy, control4, shades]
relations:
  - target: experience-switch
    kind: conflicts-with
  - target: room-lighting
    kind: conflicts-with
  - target: room-climate
    kind: conflicts-with
  - target: room-scenes
    kind: conflicts-with
---
# Room blinds

## Context

Fourth child of `room-environment`. This house has no shades/blinds experience. The experience type string is **unverified** here (Control4 usually says shades; it is not in our test fixture). Parent: `.hero/planning/initiatives/room-environment/spec.md`.

## Goal

Shade / blind control for the focused room as one implemented experience mode.

## Kickoff

Add a Shades/blinds mode after a Director that publishes that experience is in front of us.

**Status:** planning — stub. Type id unknown on this Director.

**Pick up at:** `/design room-blinds` — confirm the `ui_configuration` type string and item commands live.

→ `/design room-blinds`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`

**Skip:** inventing `shades` vs `blinds` vs `window`; whole-house shade groups.

## Approach

Register the live type id. `/design` decides list-of-shades vs a single level. Do not guess the POST name in this stub.

## Changes

Will be produced by `/design room-blinds`. No file-level Changes until then.

## Boundaries

- No work until live `ui_configuration` shows this experience
- Do not rewrite the experience Repeater

## Risks

- Wrong type string ships a dead tab.
- Some houses expose shades under lighting or comfort, not a dedicated type.

## Acceptance Criteria

- AC-1: WHEN the focused room has a shades/blinds experience THE SYSTEM SHALL show that mode segment
- AC-2: IF the Director has no such experience THEN THE SYSTEM SHALL NOT show the segment
- AC-3: WHEN the type string on the Director differs from this stub's guess THEN `/design` SHALL use the live string

## Validation

`/design` starts with a live dump. Delivery is blocked until that dump exists.
