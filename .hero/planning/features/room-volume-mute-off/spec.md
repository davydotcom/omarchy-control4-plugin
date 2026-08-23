---
title: Room volume, mute, and off
slug: room-volume-mute-off
type: feature
status: planning
domain: engineering
size: small
horizon: next
parent: control4-focused-room-remote
depends-on:
  - focused-room
created: 2026-08-21
tags: [omarchy, control4]
---
# Room volume, mute, and off

## Context

Fifth child of `control4-focused-room-remote`. Technical depends-on is only `focused-room`; **delivery order** is after `watch-and-listen` so the first AV loop is pick-source-then-volume, matching a Control4 remote (VOL + OFF on the focused room). Room commands: `PULSE_VOL_UP` / `PULSE_VOL_DOWN`, `MUTE_TOGGLE`, `ROOM_OFF` ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`.

## Goal

Volume up/down, mute toggle, and room off for the focused room. Button chrome, not a mixer. Prefer pulse volume buttons over a slider unless `/design` has a reason. Horizon is `next` — design after Watch/Listen.

## Kickoff

Focused-room volume up/down, mute toggle, and room off — buttons, not a mixer.

**Status:** planning — compose stub; `horizon: next`. Do not design until Watch/Listen is designed.

**Pick up at:** run `/design room-volume-mute-off` after `/design watch-and-listen`. Do not implement from this stub.

→ `/design room-volume-mute-off`

**Files:** `.hero/planning/features/room-volume-mute-off/spec.md`, `.hero/planning/initiatives/control4-focused-room-remote/spec.md`

**Skip:** mixer/slider-first unless `/design` justifies it; delivering before Watch/Listen; whole-house volume.

## Approach

Add remote-style buttons on the nested panel that POST room commands for the persisted focused room. Prefer `PULSE_VOL_UP` / `PULSE_VOL_DOWN` over `SET_VOLUME_LEVEL` so it feels like the hardware VOL rocker. Mute is toggle; Off is `ROOM_OFF`. `/design` may choose a slider only with a written reason. Now-playing readout of volume/mute is the next child, not this one.

## Changes

Will be produced by `/design room-volume-mute-off`. No file-level Changes until then.

## Boundaries

- Not a mixer: no per-device levels, no EQ, no grouping
- No play/pause/stop transport
- No whole-house or party-mode volume
- Do not deliver before `watch-and-listen` even though depends-on is only `focused-room`
- Now-playing poll/display is `room-now-playing`

## Risks

- Pulsing volume with no selected source may no-op or surprise; delivering after Watch/Listen reduces that.
- `ROOM_OFF` is destructive relative to mute — chrome should not make Off easy to hit by accident (`/design` places it).
- Using a slider without debounce could flood `SET_VOLUME_LEVEL` on the Director.

## Acceptance Criteria

- WHEN the user activates volume up or down THE SYSTEM SHALL POST `PULSE_VOL_UP` or `PULSE_VOL_DOWN` for the focused room (unless `/design` documents a slider and `SET_VOLUME_LEVEL` instead)
- WHEN the user activates mute THE SYSTEM SHALL POST `MUTE_TOGGLE` for the focused room
- WHEN the user activates room off THE SYSTEM SHALL POST `ROOM_OFF` for the focused room
- THE SYSTEM SHALL present these as buttons on the details panel, not as a multi-zone mixer

## Validation

This stub is ready for `/design room-volume-mute-off` after `watch-and-listen` is designed (horizon `next`). `/design` is next at that time; do not implement from this stub.
