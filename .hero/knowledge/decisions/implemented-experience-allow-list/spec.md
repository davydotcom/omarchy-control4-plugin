---
title: Implemented experience allow-list
slug: implemented-experience-allow-list
type: decision
status: accepted
domain: engineering
created: 2026-08-23
tags: [omarchy, control4, experiences]
relates-to:
  - room-environment
  - experience-switch
  - rooms-from-ui-config-join-items
---
# Implemented experience allow-list

## Context

`ui_configuration` experiences include types this AV remote does not implement (`cameras`, `comfort`, `lights`, …). Listing every `typeName === "room"` item would show thermostat-only and cameras-only rooms. Hardcoding Watch | Listen in `Panel.qml` would force every later mode to rewrite the same row.

## Options considered

- **Hardcoded Watch | Listen tabs.** Matches this house. Closed to lighting/climate/blinds/scenes.
- **Show every experience type in the payload.** Open, but this house would grow empty or unhandled tabs and new rooms.
- **Implemented allow-list (chosen).** Switch and room catalog share one list of modes we actually handle. Today: watch, listen. Later children append.

## Decision

`experienceModes` on the service is the allow-list. The Halo mode row iterates it. `extractRooms` filters `exp.type` with the same ids (default `["watch", "listen"]`). Unimplemented types stay invisible — no segment, no extra rooms.

## Consequences

This house stays a two-tab AV remote. Adding Lights is register + handler. Cameras stay out until someone writes that child. Guessing type strings (`shades` vs `blinds`) is a `/design` job against a live Director, not a default-list change.
