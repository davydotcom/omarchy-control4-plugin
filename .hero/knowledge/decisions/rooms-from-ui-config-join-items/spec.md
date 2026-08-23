---
title: Rooms from ui_configuration joined to items
slug: rooms-from-ui-config-join-items
type: decision
status: accepted
domain: engineering
created: 2026-08-21
tags: [omarchy, control4, rooms]
relates-to:
  - focused-room
  - control4-focused-room-remote
  - director-session
---
# Rooms from ui_configuration joined to items

## Decision

The focused-room catalog is unique `ui_configuration` watch/listen experience `room_id`s joined to `GET /api/v1/items` rows with `typeName === "room"`. Name comes from `item.name`; hidden is `item.roomHidden` (boolean true or `"1"` / `1`). Both fetches go through existing `directorGet`. Do not use `/locations/rooms/.../audio_devices`.

## Context

`GET /api/v1/agents/ui_configuration` experiences carry `room_id` and `type` (`watch` / `listen` / cameras / comfort / …) but not display names or hidden. Home Assistant lists rooms from `GET /api/v1/items` (`id`, `name`, `roomHidden`). pyControl4 `is_room_hidden` reads variable `ROOM_HIDDEN` on the item; HA's `roomHidden` on the item is that same flag without one GET per room. Device-inventory endpoints (`audio_devices`) are the devices *in* a room, not the room catalog, and are known incomplete.

## Alternatives Considered

- **`ui_configuration` alone.** No names, no hidden — would force `"Room 9"` placeholders or extra per-room GETs.
- **`/locations/rooms/.../audio_devices` as the room list.** Wrong resource; incomplete on OS 3.x; rejected by the parent initiative.
- **Per-room `ROOM_HIDDEN` variable GETs (pyControl4).** Correct but N extra Director calls; `item.roomHidden` is the same flag.
- **`/api/v1/items` rooms without the experience filter.** Would include cameras-only / thermostat-only rooms that an AV remote should skip.
