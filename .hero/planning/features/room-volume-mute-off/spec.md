---
title: Room volume, mute, and off
slug: room-volume-mute-off
type: feature
status: delivering
domain: engineering
size: small
horizon: next
parent: control4-focused-room-remote
depends-on:
  - focused-room
  - watch-and-listen
created: 2026-08-21
tags: [omarchy, control4]
relates-to:
  - room-now-playing
claimed_by: david-estes
---
# Room volume, mute, and off

## Context

Fifth child of `control4-focused-room-remote`. First slice shipped pulse `−` / Mute / `+`. User asked for a **slider** so they can see the level and jump to it. pyControl4: `SET_VOLUME_LEVEL` `{ LEVEL: 0–100 }`, `MUTE_TOGGLE`, `ROOM_OFF`, variables `CURRENT_VOLUME` / `IS_MUTED` via `GET /api/v1/items/{id}/variables?varnames=CURRENT_VOLUME,IS_MUTED` ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). Omarchy audio uses `qs.Ui` `PanelSlider` (0–1) with right-click mute. This child now owns volume *readout* for the slider; chip now-playing stays `room-now-playing`.

## Goal

Focused-room volume is a slider showing 0–100. Drag/release posts `SET_VOLUME_LEVEL`. Poll `CURRENT_VOLUME` so the fill matches the Director. Right-click mutes (`MUTE_TOGGLE`, same as Omarchy audio). Off stays on the next row.

## Kickoff

Replace − / Mute / + with a volume slider that shows CURRENT_VOLUME and posts SET_VOLUME_LEVEL.

**Status:** delivering — pulse buttons live; slider design just landed.

**Pick up at:** parse `CURRENT_VOLUME` / `IS_MUTED`, poll while focused, `PanelSlider` 0–100 integer, POST on release only.

→ `/deliver room-volume-mute-off`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `tests/director-client.test.js`, `README.md`

**Skip:** pulse buttons; mixer; play/pause; whole-house; posting `SET_VOLUME_LEVEL` on every `moved`.

## Approach

**Read.** `directorGet("/api/v1/items/" + focusedRoomId + "/variables?varnames=CURRENT_VOLUME,IS_MUTED")`. Parse in `DirectorClient.parseRoomVolume(raw)` → `{ volume: number|null, muted: bool }`. Volume clamped 0–100. `IS_MUTED` true for `true` / `"1"` / `1`. Missing/invalid → keep previous volume, muted false if unknown on first read.

**Poll** every 2s while `connected` and a focused room (Timer). Also on focus change. While `Date.now() < _volumeHoldUntil` (1.5s after a local set), ignore poll so the slider does not snap back mid-drag.

**Write.** `setVolume(level)`: clamp 0–100 integer, set `volume` immediately, hold poll, `directorPost(..., "SET_VOLUME_LEVEL", { LEVEL: n })`. POST on `PanelSlider.released` (and wheel, which already emits released). Do **not** POST on every `moved`.

**Mute.** `toggleMute()` still `MUTE_TOGGLE`. Bound to `PanelSlider.rightClicked`. Slider `opacity` 0.5 while `muted`.

**Chrome.** Connected + focused, below sources:

- Row: numeric label (`volume` or `M` if muted) + `PanelSlider` (`minimum: 0`, `maximum: 100`, `integer: true`, `step: 1`, `bar: root.bar`).
- Next row: Off, full width, `ROOM_OFF`.

Remove `pulseVolumeUp` / `pulseVolumeDown` from the panel.

## Changes

1. `DirectorClient.js` — `parseRoomVolume`.
2. `Service.qml` — `volume`, `muted`, `setVolume`, poll Timer, hold-off after set; `_roomCommand` takes optional params; drop pulse helpers used only by the old row.
3. `Panel.qml` — `PanelSlider` + level label; right-click mute; keep Off.
4. `tests/director-client.test.js` — parse volume/mute fixtures.
5. `README.md` — slider, right-click mute, Off.

## Boundaries

- Not a mixer: no per-device levels, EQ, grouping
- No play/pause/stop
- No whole-house / party volume
- Chip now-playing text is still `room-now-playing`
- Do not flood `SET_VOLUME_LEVEL` on drag

## Risks

- Poll vs slider fight — hold-off after set is mandatory.
- Mute without a selected source may no-op; still send the command.
- `ROOM_OFF` stays off the slider row.

## Acceptance Criteria

- WHEN a room is focused THE SYSTEM SHALL show a 0–100 volume slider whose value is `CURRENT_VOLUME`
- WHEN the user releases the slider THE SYSTEM SHALL `directorPost` `SET_VOLUME_LEVEL` with `{ LEVEL: <0–100> }` for `focusedRoomId`
- THE SYSTEM SHALL NOT post `SET_VOLUME_LEVEL` on every drag tick
- WHEN the user right-clicks the slider THE SYSTEM SHALL `directorPost` `MUTE_TOGGLE`
- WHEN the user activates Off THE SYSTEM SHALL `directorPost` `ROOM_OFF`
- IF there is no focused room THE SYSTEM SHALL hide the slider and Off
- THE SYSTEM SHALL place Off on a different row from the slider

## Validation

```
node tests/director-client.test.js
```

Live copy + `omarchy restart shell`. Manual: focused room → slider shows a number; drag; Director volume matches; right-click mutes; Off still works. Unfocused: slider hidden.
