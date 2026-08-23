---
title: Room now playing
slug: room-now-playing
type: feature
status: planning
domain: engineering
size: large
horizon: now
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

Poll the focused room's `POWER_STATE`, volume/mute, and current watch/listen source, and make that state legible in two places: the bar chip and the panel. The chip stops spelling out the room name — it becomes a Control4 mark whose icon state says whether the room is on or off. In the panel, room state reads in Halo style rather than being implied by controls that look disabled.

## Kickoff

Poll focused-room power, volume/mute, and source; show now-playing on the chip and panel header.

**Status:** planning — Watch/Listen has shipped, so this is unblocked and promoted to `horizon: now`. User asked for the chip to become a Control4 mark with on/off icon states, and for room state to read Halo-style in the panel.

**Pick up at:** `/design room-now-playing`. Room variables are already confirmed live (see Approach) — design the chip states and the panel's state treatment.

→ `/design room-now-playing`

**Files:** `BarWidget.qml`, `Panel.qml`, `Service.qml`, `.hero/planning/features/room-now-playing/spec.md`

**Skip:** lights/climate metadata; websocket-only designs unless `/design` proves REST poll is insufficient; transport controls; a second volume slider.

## Approach

A poll on the existing Director session. The room variables no longer need guessing — `GET /api/v1/items/{roomId}/variables` was read live on this Director and carries all of it:

- `POWER_STATE` — 0 when the room is off. This is the state the chip and the Off control should reflect.
- `CURRENT_VOLUME`, `IS_MUTED` — already polled by `room-volume-mute-off`; do not add a second poll.
- `CURRENT_SELECTED_DEVICE`, `CURRENT_AUDIO_DEVICE`, `CURRENT_VIDEO_DEVICE`, `PLAYING_AUDIO_DEVICE` — device ids, resolved to names through the `_items` list the plugin already holds.
- `LAST_DEVICE_GROUP` — `"watch"` or `"listen"`, useful for which mode to show.
- `CURRENT_MEDIA` / `CURRENT MEDIA INFO` — present but empty on this Director; richer now-playing comes from `/api/v1/media_sessions` (`mediainfo` with artist/album/title/art), which is also what `multi-room-audio` will read.

Note `CURRENT_AUDIO_DEVICE` tracks the digital-media *player* (`100002` here), not the media service — `PLAYING_AUDIO_DEVICE` is the one that names what is actually playing. Reading the wrong one will show "Digital Media" forever.

**Bar chip.** `BarWidget.qml` currently sets `chipText` to the room name with a 140-wide clip, which is the width complaint. Replace the text with a Control4 mark that carries on/off state — the room name moves to the tooltip, which already composes it. `/design` owns whether the mark is a glyph or an asset and how "connected but room off" differs visually from "not connected".

**Panel.** Room state should read as state, not as a greyed-out control. This is the other half of the bug `back-off-buttons-look-disabled`: today Off is permanently muted-looking, so it reads disabled *and* never indicates whether the room is on. Follow `halo-remote-panel-style`.

`/design` owns poll interval and whether push/websocket is worth it (default: poll, reusing the existing volume poll rather than adding a second).

## Changes

Will be produced by `/design room-now-playing`. No file-level Changes until then.

## Boundaries

- No transport controls (play/pause/stop) — those are `watch-source-virtual-remote`
- No artwork/metadata browser beyond source name + power/volume/mute
- No lights/climate/shades status
- Volume *slider* and mute are `room-volume-mute-off` (including the `CURRENT_VOLUME` poll). This child is state display, not a second volume control.
- No multi-room state — one focused room only (`multi-room-audio` owns the rest)
- Fixing the muted look of Back and Off is the bug `back-off-buttons-look-disabled`; this child owns what Off *reflects*, not the shared row styling

## Risks

- Reading `CURRENT_AUDIO_DEVICE` instead of `PLAYING_AUDIO_DEVICE` will show the digital-media player rather than the source, forever.
- Too-aggressive polling will load the Director on top of the existing volume poll; too-slow polling will make Watch/Listen look broken.
- Three states collapse easily into two: room off, room on but idle, and plugin not connected must stay distinguishable on a chip that is now an icon rather than text.
- Dropping the room name from the chip removes the only at-a-glance cue of *which* room is focused when several rooms exist. The tooltip carries it, but `/design` should confirm that is enough.
- An icon-only chip must still be legible in the bar's vertical orientation.

## Acceptance Criteria

- WHILE a focused room is selected THE SYSTEM SHALL poll `POWER_STATE`, volume, and mute for that room and show them on the bar chip and panel header
- WHEN the focused room has a current watch or listen source THE SYSTEM SHALL show that source name on the chip and panel header
- IF the room is off THEN THE SYSTEM SHALL show an off state rather than a stale source name
- THE SYSTEM SHALL use the existing Director session (no second login path)

## Validation

This stub is ready for `/design room-now-playing` after `watch-and-listen` is designed (horizon `next`), so the chip can reflect a source this plugin selected. `/design` pins source fields and poll interval; do not implement from this stub.

## Acceptance Criteria

- WHEN the focused room is off THE SYSTEM SHALL show an off state on the bar chip and in the panel
- WHEN the focused room is on THE SYSTEM SHALL show an on state and name the playing source
- WHEN the plugin is not connected THE SYSTEM SHALL show a state distinct from both room-on and room-off
- THE SYSTEM SHALL NOT spell the room name across the bar chip

## Validation

Live: turn the focused room off from the panel and watch the chip change state; start a source and watch it change back and name the source. Confirm the tooltip still identifies the room. `qmllint` clean.
