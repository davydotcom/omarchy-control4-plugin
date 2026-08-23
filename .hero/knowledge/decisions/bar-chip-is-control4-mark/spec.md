---
title: Bar chip is the Control4 mark
slug: bar-chip-is-control4-mark
type: decision
status: accepted
domain: engineering
created: 2026-08-23
tags: [omarchy, control4, bar-widget]
relates-to:
  - room-now-playing
  - focused-room
  - halo-remote-panel-style
---
# Bar chip is the Control4 mark

## Context

`focused-room` put the room name on the bar chip. Long names clipped at ~140px. The last child of the focused-room remote needs on/off and now-playing without that width fight, and several rooms exist in this house so the chip still has to be identifiable as Control4.

## Options considered

- **Keep the room name, elide it.** Still the width complaint; on/off is not visible at a glance.
- **Source name on the chip.** Same clip problem, and it goes stale when the room is off.
- **Control4 mark, room + source in tooltip and panel.** Chip stays a square; three plugin states stay distinguishable.

## Decision

The chip is the Control4 mark only: official 4-Ball when the focused room is on, white mark when it is off, faded white mark when the plugin is not connected. Room name and playing source belong in the tooltip and the Halo status line.

## Consequences

`BarWidget.qml` stays `labelVisible: false` with `icon.png` / `icon-off.png`. README must not say the chip shows the room name. Richer track metadata stays out — that is `multi-room-audio`.
