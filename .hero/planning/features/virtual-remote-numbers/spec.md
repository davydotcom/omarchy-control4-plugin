---
title: Virtual remote numbers
slug: virtual-remote-numbers
type: feature
status: planning
domain: engineering
size: medium
horizon: later
parent: watch-source-virtual-remote
depends-on:
  - virtual-remote-dpad
created: 2026-08-23
tags: [omarchy, control4, watch, remote, cable]
---
# Virtual remote numbers

## Context

Fourth child of `watch-source-virtual-remote`, and the one that is really about the cable box. Item `20` Cable DVR (`cable` proxy, Xfinity X1) declares `has_channel_up_down: true` and `has_discrete_channel_select: true`; the Apple TVs declare digits but no channel capability. Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

Channel entry for sources that declare it: channel up/down, and a digit pad where discrete select is supported, sending to the focused room's device.

## Kickoff

Digit pad and channel up/down for channel-capable watch sources.

**Status:** planning — lowest priority child; depends on the D-pad child.

**Pick up at:** `/design virtual-remote-numbers` after the D-pad ships.

→ `/design virtual-remote-numbers`

**Files:** `Panel.qml`, `Service.qml`

**Skip:** channel guides/listings; favourites; DVR recordings browse; last-channel toggle unless the device declares it.

## Approach

Gate on `capabilities.has_channel_up_down` and `has_discrete_channel_select`, not on the presence of `NUMBER_*` commands — the Apple TVs declare digits they have no meaningful use for, and rendering a channel pad there would be a fake control.

Multi-digit entry needs a decision `/design` owns: send each digit as it is pressed, or buffer and commit. Xfinity X1 tolerates per-digit IR, but a buffered entry with a visible readout is friendlier.

## Changes

Will be produced by `/design virtual-remote-numbers`. No file-level Changes until then.

## Boundaries

- No channel guide, listings, or EPG
- No DVR recordings browse
- No favourites list
- Not shown on sources that merely declare `NUMBER_*` without channel capability

## Risks

- Rendering a channel pad for the Apple TVs because they list digits — a control that does nothing is worse than no control.
- Per-digit sending races on multi-digit channels; a partial entry tunes the wrong channel.
- A 12-button pad plus a D-pad will not fit the panel at once. Layout needs a real answer.

## Acceptance Criteria

- WHEN a source declares channel capability THE SYSTEM SHALL show channel entry
- WHEN a source declares digits but no channel capability THE SYSTEM SHALL NOT show channel entry
- WHEN the user enters a multi-digit channel THE SYSTEM SHALL tune that channel, not a prefix of it

## Validation

Channel entry appears for Cable DVR and is absent for both Apple TVs. Entering a known multi-digit channel tunes it in the focused room.
