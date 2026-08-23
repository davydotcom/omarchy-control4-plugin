---
title: Room now playing
slug: room-now-playing
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
# Room now playing

## Context

Sixth child of `control4-focused-room-remote`. Technical depends-on is `focused-room`; **deliver after `watch-and-listen`** so the chip can reflect a source this plugin selected. pyControl4 room variables cover power and volume: `POWER_STATE`, `CURRENT_VOLUME`, `IS_MUTED` ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). Current watch/listen source names need `/design` to pin the `ui_configuration` / item-variable fields — do not invent them in this stub. Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`.

## Goal

Poll the focused room's `POWER_STATE`, volume/mute, and current watch/listen source. Show that state on the bar chip and the panel header. Horizon is `next` — design after Watch/Listen.

## Kickoff

Poll focused-room power, volume/mute, and source; show now-playing on the chip and panel header.

**Status:** planning — compose stub; `horizon: next`. Do not design until Watch/Listen is designed.

**Pick up at:** run `/design room-now-playing` after `/design watch-and-listen`. Do not implement from this stub.

→ `/design room-now-playing`

**Files:** `.hero/planning/features/room-now-playing/spec.md`, `.hero/planning/initiatives/control4-focused-room-remote/spec.md`

**Skip:** shipping before Watch/Listen; lights/climate metadata; websocket-only designs unless `/design` proves REST poll is insufficient.

## Approach

A simple poll on the existing Director session: power, volume, mute, and whatever source fields `/design` identifies on the focused room. Chip shows room plus a short now-playing hint; panel header shows the same with more room. Deliver after Watch/Listen so a source this plugin selected can appear. `/design` owns interval, truncation, and whether push/websocket is worth it (default: poll).

## Changes

Will be produced by `/design room-now-playing`. No file-level Changes until then.

## Boundaries

- No transport controls (play/pause/stop)
- No artwork/metadata browser beyond source name + power/volume/mute
- No lights/climate/shades status
- Do not deliver before `watch-and-listen`
- Volume *buttons* are `room-volume-mute-off`; this child is readout

## Risks

- Source variable names are not pinned in this stub — `/design` must cite Director fields or the chip will show room name forever.
- Too-aggressive polling will load the Director; too-slow polling will make Watch/Listen look broken.
- Room off vs mute vs idle: `POWER_STATE` vs empty source needs a clear chip string so "off" is not confused with "unknown."

## Acceptance Criteria

- WHILE a focused room is selected THE SYSTEM SHALL poll `POWER_STATE`, volume, and mute for that room and show them on the bar chip and panel header
- WHEN the focused room has a current watch or listen source THE SYSTEM SHALL show that source name on the chip and panel header
- IF the room is off THEN THE SYSTEM SHALL show an off state rather than a stale source name
- THE SYSTEM SHALL use the existing Director session (no second login path)

## Validation

This stub is ready for `/design room-now-playing` after `watch-and-listen` is designed (horizon `next`), so the chip can reflect a source this plugin selected. `/design` pins source fields and poll interval; do not implement from this stub.
