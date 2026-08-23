---
title: Virtual remote D-pad
slug: virtual-remote-dpad
type: feature
status: planning
domain: engineering
size: large
horizon: next
parent: watch-source-virtual-remote
depends-on:
  - remote-command-metadata
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
---
# Virtual remote D-pad

## Context

Second child of `watch-source-virtual-remote` and the one that carries the initiative's value. Today Watch → Apple TV posts `SELECT_VIDEO_DEVICE` and stops; there is nothing to press afterwards. Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

After Watch selects a source that declares navigation, the panel shows a Halo-styled D-pad with Menu and Enter, and pressing a direction moves the device's on-screen UI in the focused room. Done when arrows and Menu drive a real Apple TV.

## Kickoff

D-pad, Menu, Enter for the selected watch source — rendered from metadata, Halo-styled.

**Status:** planning — blocked on `remote-command-metadata` and on one live command POST proving the endpoint.

**Pick up at:** `/design virtual-remote-dpad`. Before UI work, confirm one live press moves the Apple TV.

→ `/design virtual-remote-dpad`

**Files:** `Service.qml`, `Panel.qml`, `.hero/planning/features/virtual-remote-dpad/spec.md`

**Skip:** transport row (sibling), digits (sibling), driver icon art, per-brand layouts.

## Approach

Reuse the shape `listen-library-browse` established: selecting a source can replace the source list with a device-specific view, with Back returning to the list. The remote is that view for watch sources. Follow `halo-remote-panel-style` for chrome.

The panel is now three anchored regions (header / scrolling list / pinned footer). The remote is a fixed-size block, so it belongs in the list region without scrolling, leaving volume and Off pinned where they are.

**Unverified, and this child must settle it before building UI:** whether a nav command posts to `/api/v1/items/{deviceId}/commands` with the existing `{async, command, tParams}` body, whether it needs `ROOMID`, and whether the type-7 proxy (`295`) or the type-6 protocol parent (`294`) is the right target. One live press against a room nobody is using answers all three.

## Changes

Will be produced by `/design virtual-remote-dpad`. No file-level Changes until then.

## Boundaries

- Navigation only — no transport, no digits, no power
- No driver icon assets; glyphs are fine for this slice
- No key-repeat / press-and-hold in the first slice unless the device needs it
- No now-playing readback
- Sources declaring no navigation stay tap-to-select

## Risks

- Probing command shapes on live AV changes what is on someone's TV. Use an idle room.
- An IR driver accepts every command and may do nothing if no emitter is in range — a silent no-op reads as a plugin bug.
- Fitting a D-pad into a 320-wide panel without it looking like an afterthought.
- Latency: an unresponsive-feeling remote is worse than no remote. Fire-and-forget, do not block on the response.

## Acceptance Criteria

- WHEN a watch source declaring navigation is selected THE SYSTEM SHALL show a D-pad with Menu and Enter
- WHEN the user presses a direction THE SYSTEM SHALL send that command for the focused room without blocking the UI
- WHEN the user presses Back THE SYSTEM SHALL return to the watch source list
- IF the selected source declares no navigation commands THE SYSTEM SHALL show no remote

## Validation

One live POST must visibly move the Apple TV UI before layout work proceeds. Then: Watch → Apple TV → arrows and Menu drive the on-screen UI, Back returns to the source list, volume and Off stay reachable throughout. `qmllint` clean; `node tests/director-client.test.js` still passes.
