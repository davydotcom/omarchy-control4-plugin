---
title: Watch and Listen
slug: watch-and-listen
type: feature
status: planning
domain: engineering
size: medium
horizon: now
parent: control4-focused-room-remote
depends-on:
  - focused-room
created: 2026-08-21
tags: [omarchy, control4]
---
# Watch and Listen

## Context

Fourth child of `control4-focused-room-remote`, and the last `horizon: now` slice. On a Control4 remote, Watch and Listen are the same list→select gesture with different source sets ([SR-260](https://docs.control4.com/docs/product/system-remote-control-sr-260/user-guide/english/latest/system-remote-control-sr-260-user-guide-rev-c.pdf)). Catalogs live on `ui_configuration` experiences (`type: "watch"` / `"listen"`), not room device-inventory endpoints ([pyControl4 director](https://lawtancool.github.io/pyControl4/director.html), [pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). Select is `SELECT_VIDEO_DEVICE` vs `SELECT_AUDIO_DEVICE` with `deviceid`. Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`.

## Goal

One source-picker UI for both Watch and Listen. Choosing Watch vs Listen only changes the experience filter (`watch` / `listen`) and the command (`SELECT_VIDEO_DEVICE` / `SELECT_AUDIO_DEVICE`). Same list→select pattern. Do not split into two specs or two picker implementations.

## Kickoff

One source-picker for Watch and Listen; filter and command change, UI does not.

**Status:** planning — compose stub; depends on `focused-room`.

**Pick up at:** run `/design watch-and-listen` after focused-room is designed. Do not implement from this stub.

→ `/design watch-and-listen`

**Files:** `.hero/planning/features/watch-and-listen/spec.md`, `.hero/planning/initiatives/control4-focused-room-remote/spec.md`

**Skip:** two specs or two picker UIs; `/locations/rooms/.../audio_devices` as the catalog; volume/now-playing in this child.

## Approach

Reuse one list→select panel. Watch vs Listen is a mode that filters `ui_configuration` experiences and picks the POST command on the focused room's `/api/v1/items/{id}/commands`. Do not over-design internals here: `/design` owns chrome (tabs vs two buttons), empty lists, and exact payload JSON. Product shape is locked — one picker, experiences not devices.

## Changes

Will be produced by `/design watch-and-listen`. No file-level Changes until then.

## Boundaries

- Do not split Watch and Listen into two specs or two source-picker components
- No volume, mute, off, or now-playing (children 5–6, `horizon: next`)
- No cameras experience, lights, or climate
- No overlay remote, numeric keypad, or transport controls
- Do not use room `audio_devices` / `video_devices` endpoints for the list (known incomplete on OS 3.x)

## Risks

- Empty watch or listen experience for a room looks like a bug if the empty state is unclear.
- Posting the wrong command for the mode (audio select on Watch, or vice versa) will switch the wrong path on the Director.
- Device inventory vs experiences: using `/api/v1/items` or room device lists will not match what the Control4 app shows.

## Acceptance Criteria

- WHEN the user chooses Watch THE SYSTEM SHALL list sources from `ui_configuration` experiences of type `watch` for the focused room
- WHEN the user chooses Listen THE SYSTEM SHALL list sources from `ui_configuration` experiences of type `listen` for the focused room
- WHEN the user selects a Watch source THE SYSTEM SHALL POST `SELECT_VIDEO_DEVICE` with that source's `deviceid` to the focused room
- WHEN the user selects a Listen source THE SYSTEM SHALL POST `SELECT_AUDIO_DEVICE` with that source's `deviceid` to the focused room
- THE SYSTEM SHALL use one source-picker implementation for both modes (Watch vs Listen changes filter and command only)

## Validation

This stub is ready for `/design watch-and-listen` when `focused-room` is designed so the picker has a room id. `/design` refines chrome and payloads; do not implement from this stub. Do not start children 5–6 until this child is at least designed.
