---
title: Multi-room volume view
slug: multi-room-volume-view
type: feature
status: planning
domain: engineering
size: medium
horizon: later
parent: multi-room-audio
depends-on:
  - room-session-model
created: 2026-08-23
tags: [omarchy, control4, multi-room, audio, volume]
---
# Multi-room volume view

## Context

Third child of `multi-room-audio` — the read half made visible. The panel today shows one slider for the focused room. Parent: `.hero/planning/initiatives/multi-room-audio/spec.md`.

## Goal

A view listing every room in the current session, each with its own volume slider and mute, so the Deck can be trimmed without touching the Office.

## Kickoff

Every room in the session, each with its own volume and mute.

**Status:** planning — depends on `room-session-model`.

**Pick up at:** `/design multi-room-volume-view`.

→ `/design multi-room-volume-view`

**Files:** `Panel.qml`, `Service.qml`

**Skip:** per-room EQ/delay; whole-house dashboard; a master/group fader unless the session exposes one cleanly.

## Approach

Drive each row from the *room's* `CURRENT_VOLUME` / `IS_MUTED`, not the session's single `volume_level` — the session number is one value for the whole session and cannot express per-room trim. Reuse the write path and the hold-window guard from `room-volume-mute-off`, which already keeps a slider from fighting the poll (the bug `volume-slider-reads-room-name` fixed).

The panel is now three anchored regions with a scrolling list between a header and a pinned footer. Seven rooms of sliders belong in that scrolling region, following `halo-remote-panel-style`.

## Changes

Will be produced by `/design multi-room-volume-view`. No file-level Changes until then.

## Boundaries

- No per-room EQ, delay, or crossover
- No whole-house dashboard beyond the current session
- Does not add or remove rooms — that is `add-room-to-source`
- Does not replace the focused room's own slider

## Risks

- Session `volume_level` and per-room `CURRENT_VOLUME` are different numbers; driving the wrong one makes the slider lie.
- N sliders means N polls or one batched read; a naive per-room poll will hammer the Director.
- Each slider needs its own hold window, or the poll will yank rooms the user is mid-drag on.
- Layout: seven rooms plus source list plus pinned footer is a lot of panel.

## Acceptance Criteria

- WHEN a session covers several rooms THE SYSTEM SHALL show one volume row per room
- WHEN the user drags one room's slider THE SYSTEM SHALL change only that room
- WHEN a room leaves the session THE SYSTEM SHALL drop its row
- THE SYSTEM SHALL NOT drive per-room volume from the session-level `volume_level`

## Validation

Live with a source in two rooms: each row reads that room's real volume, dragging one moves only that room, and muting one leaves the other audible. Sliders do not jump back under an active drag.
