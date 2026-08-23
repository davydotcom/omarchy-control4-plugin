---
title: Receiver audio options are not in commands[]
slug: receiver-audio-not-in-commands
type: context
status: active
domain: engineering
created: 2026-08-23
tags: [omarchy, control4, receiver, surround]
relates-to:
  - watch-source-virtual-remote
  - watch-receiver-audio-options
  - remote-command-metadata
---
# Receiver audio options are not in commands[]

## Overview

On this Director, Watch source `370` (receiver proxy, Sony STR-ZA5000ES protocol `369`) has **no** `commands` key in `GET /api/v1/items`. Apple TV `431` does. Gating a virtual remote on `MENU`/`UP` therefore selects the receiver and shows nothing.

## What the Director actually exposes

- Discrete surround UI is on the proxy **capabilities**, already in the items list payload: `has_discrete_surround_mode_select`, `has_toad_surround_mode_select`, and `surround_modes.surround_mode[]` `{ id, name }`.
- Driverworks names the set command `SET_SURROUND_MODE` (integer mode + output binding). Live REST tParams on this Director: `{ SURROUNDMODE: <id>, OUTPUT: 4000 }` (audio output bindingName `Output`). POST returns HTTP 200 `{}` like nav; `CURRENT_-Output_SURROUND_MODE` at variableId `401002` did not change during the 2026-08-23 probe (device was selected and `POWER_STATE` went 0→1).
- `GET /api/v1/items/370/commands` is a **second** catalog: labeled extras (`Sound Optimizer`, `Pure Direct`, `Speaker Selection`, HDMI routing, Triggers, bass/treble) with `deviceId` pointing at protocol parent `369`. Same URL as the POST used for proxy nav, different payload shape. Do not treat this GET as `item.commands.command[]`.
- Tuner child `371` has channel/preset `commands[]`. That is not the Watch-source audio-options list.

## Do not

- Special-case "Sony" or the `.c4i` filename to decide layout.
- POST extras (`Triggers`, `HDMI 4K Scaling`, …) while probing a live Director.
- Assume a missing `commands` key means the device has no remote UI.
