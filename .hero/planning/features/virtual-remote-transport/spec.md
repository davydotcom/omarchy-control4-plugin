---
title: Virtual remote transport
slug: virtual-remote-transport
type: feature
status: planning
domain: engineering
size: medium
horizon: later
parent: watch-source-virtual-remote
depends-on:
  - virtual-remote-dpad
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
---
# Virtual remote transport

## Context

Third child of `watch-source-virtual-remote`. Both live Apple TVs declare `PLAY STOP PAUSE SKIP_FWD SKIP_REV SCAN_FWD SCAN_REV`; the `dvd` proxy also sets `navigator_display_option.show_transport: true`, while the `.c4z` `media_player` shape omits the flag entirely. Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

A transport row under the D-pad, shown only for sources that declare transport commands, sending play/pause/stop/skip/scan to the focused room's device.

## Kickoff

Transport row for watch sources that declare it — play, pause, stop, skip, scan.

**Status:** planning — depends on the D-pad child settling the command endpoint.

**Pick up at:** `/design virtual-remote-transport` after the D-pad ships.

→ `/design virtual-remote-transport`

**Files:** `Panel.qml`, `Service.qml`

**Skip:** playback *state* readback (that is `room-now-playing`); scrubbing/seek bars; Listen-side transport.

## Approach

Presence in `commands[]` is the gate. `show_transport` is a *hint* on one metadata shape and absent on the other, so it may raise confidence but must not be required — treating its absence as false would hide transport on every `.c4z` driver.

Reuse whatever press path the D-pad child establishes; this child adds buttons, not plumbing.

## Changes

Will be produced by `/design virtual-remote-transport`. No file-level Changes until then.

## Boundaries

- No play/pause *state* — the buttons are stateless until `room-now-playing` provides readback
- No seek/scrub UI
- No Listen-side transport controls
- No repeat/shuffle

## Risks

- Reading absent `show_transport` as false, hiding transport on every `.c4z` device.
- A stateless play/pause toggle is ambiguous when the user cannot see what is playing.

## Acceptance Criteria

- WHEN a source declares transport commands THE SYSTEM SHALL show a transport row
- WHEN a source declares none THE SYSTEM SHALL omit the row entirely
- THE SYSTEM SHALL NOT require `show_transport` to be present in order to show transport

## Validation

Transport appears for both Apple TVs (one `.c4i`, one `.c4z`) and is absent for a source declaring no transport commands. Pause visibly pauses playback in the focused room.
