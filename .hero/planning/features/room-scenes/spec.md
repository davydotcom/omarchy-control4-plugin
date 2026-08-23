---
title: Room scenes
slug: room-scenes
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
tags: [omarchy, control4, scenes]
relations:
  - target: experience-switch
    kind: conflicts-with
  - target: room-lighting
    kind: conflicts-with
  - target: room-climate
    kind: conflicts-with
  - target: room-blinds
    kind: conflicts-with
---
# Room scenes

## Context

Last child of `room-environment`. This house has no scenes to drive, and we do not yet know whether Control4 publishes them as an experience type, a lighting preset list, or Composer custom buttons. Parent: `.hero/planning/initiatives/room-environment/spec.md`.

## Goal

Fire room scenes from the Halo panel for the focused room, once `/design` finds where this (or another) Director actually publishes them.

## Kickoff

Add room scenes after `/design` finds the live catalog — do not assume a `scenes` experience type.

**Status:** planning — stub. Source of scenes is unknown; this house has none.

**Pick up at:** `/design room-scenes`. First job is "where does the Director list scenes?" not UI.

→ `/design room-scenes`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`

**Skip:** Composer scene authoring; guessing a `scenes` experience type; delivering before lighting if scenes turn out to be lighting presets.

## Approach

`/design` must answer: experience type, lighting child list, agent, or custom buttons. If they are lighting presets, this child may shrink to a filter on `room-lighting` — do not pre-commit a fifth tab.

## Changes

Will be produced by `/design room-scenes`. No file-level Changes until then.

## Boundaries

- No work until a live catalog is found
- No scene editing
- Do not invent a `scenes` type to match the slug

## Risks

- A premature Scenes tab will be empty or duplicate Lights.
- Custom buttons may be house-specific and not worth a generic mode.

## Acceptance Criteria

- AC-1: WHEN `/design` finds a live scene catalog THE SYSTEM SHALL expose those scenes for the focused room
- AC-2: IF no catalog exists on the Director THEN THE SYSTEM SHALL NOT show a Scenes segment
- AC-3: IF scenes are lighting presets THEN `/design` SHALL reuse lighting rather than fork a second list

## Validation

`/design` starts by locating the catalog. Delivery is blocked until that location is known.
