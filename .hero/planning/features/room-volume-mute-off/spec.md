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

Fifth child of `control4-focused-room-remote`. User asked to land this with Watch/Listen. Technical depends-on is `focused-room`; delivery is after (or with) the source picker so VOL/OFF address a room that can have a source. pyControl4 room commands on `/api/v1/items/{roomId}/commands`: `PULSE_VOL_UP` / `PULSE_VOL_DOWN` (empty params), `MUTE_TOGGLE`, `ROOM_OFF` ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). Existing `directorPost` already wraps `commandBody`. Now-playing readout of volume/mute is the next child.

## Goal

Volume up/down, mute toggle, and room off as buttons on the details panel for `focusedRoomId`. Pulse, not a slider. Off is a separate row so it is not next to minus. No mixer. No now-playing numbers.

## Kickoff

Focused-room volume up/down, mute toggle, and Off — buttons, not a mixer.

**Status:** delivering — − / Mute / + / Off buttons live on the focused-room panel. Commands not CLI-clicked.

**Pick up at:** tap + / Mute / Off on Deck; confirm Director volume/off; then verify.

→ `/deliver room-volume-mute-off`

**Files:** `Service.qml`, `Panel.qml`, `README.md`

**Skip:** slider / `SET_VOLUME_LEVEL`; mixer; play/pause; whole-house; now-playing poll.

## Approach

**Commands via existing `directorPost` only.** Path `/api/v1/items/{focusedRoomId}/commands`. Params `{}` except none of these need tParams keys. No-op if not connected or `focusedRoomId` is null.

```
function pulseVolumeUp()
function pulseVolumeDown()
function toggleMute()
function roomOff()
```

One private `_roomCommand(command)` that posts and ignores the callback (transport blip does not change UI in this child). Do not open GET variable polling here.

**Chrome.** Visible only when connected with a focused room, below the source picker:

- One `Row` of three `qs.Ui` `Button`s: `−` / `Mute` / `+` (pulse down, `MUTE_TOGGLE`, pulse up). Not a slider.
- `Off` on the next row, full width, `bordered: true`, `ROOM_OFF`. Not in the volume row.

No confirm dialog. No mute selected-state (that needs `IS_MUTED` from now-playing).

## Changes

1. `Service.qml` — `_roomCommand`, the four functions. No new HTTP client.
2. `Panel.qml` — volume row + Off button, gated on connected + focused room.
3. `README.md` — volume / mute / Off after a room is focused.

## Boundaries

- Not a mixer: no per-device levels, EQ, grouping
- No `SET_VOLUME_LEVEL` slider
- No play/pause/stop
- No whole-house / party volume
- No now-playing poll (`room-now-playing`)

## Risks

- Pulse with no source may no-op on the Director — still send the command; do not fake a level.
- `ROOM_OFF` next to `−` would be an easy miss-hit — keep Off on its own row.
- Command errors are silent in this child (no toast API); status text stays session status.

## Acceptance Criteria

- WHEN the user activates volume up THE SYSTEM SHALL `directorPost` `PULSE_VOL_UP` for `focusedRoomId`
- WHEN the user activates volume down THE SYSTEM SHALL `directorPost` `PULSE_VOL_DOWN` for `focusedRoomId`
- WHEN the user activates mute THE SYSTEM SHALL `directorPost` `MUTE_TOGGLE` for `focusedRoomId`
- WHEN the user activates Off THE SYSTEM SHALL `directorPost` `ROOM_OFF` for `focusedRoomId`
- THE SYSTEM SHALL present these as buttons, not a slider or mixer
- IF there is no focused room THE SYSTEM SHALL hide volume, mute, and Off
- THE SYSTEM SHALL place Off on a different row from volume up/down

## Validation

Live copy + `omarchy restart shell` (Loader `Panel.qml`). Manual: focused room → `−` / `+` change Director volume; Mute toggles; Off turns the room off. Unfocused: buttons hidden. `node tests/director-client.test.js` still passes (no new join required).
