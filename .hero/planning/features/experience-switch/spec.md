---
title: Experience switch
slug: experience-switch
type: feature
status: planning
domain: engineering
size: small
horizon: now
priority: critical
parent: room-environment
created: 2026-08-23
tags: [omarchy, control4, halo, ui]
relates-to:
  - halo-remote-panel-style
  - rooms-from-ui-config-join-items
  - watch-and-listen
  - halo-panel-chrome
relations:
  - target: room-lighting
    kind: conflicts-with
  - target: room-climate
    kind: conflicts-with
  - target: room-blinds
    kind: conflicts-with
  - target: room-scenes
    kind: conflicts-with
---
# Experience switch

## Context

First child of `room-environment`. The Halo panel hardcodes two `HaloRow`s (Watch / Listen) and `extractRooms` only keeps those two experience types. That is correct for this AV-only house, and it paints the next lighting/climate/blinds/scenes work into a corner: each would have to edit the same two-tab row. Parent: `.hero/planning/initiatives/room-environment/spec.md`.

## Goal

The mode row is a Repeater over an implemented-mode list on the service. Room discovery uses that same list. Watch and Listen remain the only implemented modes, so this house looks unchanged. A later child adds a mode by appending to the list, not by forking the row.

## Kickoff

Turn Watch/Listen into a Repeater over implemented experience modes; keep this house at two tabs.

**Status:** planning — designed, not delivered. This Director has no lighting/climate/shades to show.

**Pick up at:** `/deliver experience-switch`.

→ `/deliver experience-switch`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `tests/director-client.test.js`, `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`

**Skip:** Lighting/Climate/Shades/Scenes UI; changing select commands; wrapping for n>3 unless the Repeater is free.

## Approach

**One allow-list.** `Service.qml` grows `experienceModes: [{ id: "watch", label: "Watch" }, { id: "listen", label: "Listen" }]`. `setSourceMode` no-ops unless `id` is in that list (today that is still only watch/listen). Keep the property name `sourceMode` so Watch/Listen and the virtual remote do not churn.

**`extractRooms(uiConfig, items, types)`.** Third argument is optional. Omitted or empty → `["watch", "listen"]` so every existing test stays green, including "cameras-only and other types skipped" (`cameras` / `comfort` / `lights` rooms in `tests/director-client.test.js`). When a later child passes `["watch", "listen", "lights"]`, a lights-only room can appear. Do not default to "every type in the payload."

**Panel.** `modeRow` is a `Repeater` over `session.experienceModes`. Each segment width is `(modeRow.width - spacing * (n - 1)) / n` with n = model count. Selected = `sourceMode === modelData.id`. Tap → `setSourceMode(modelData.id)`. n=2 must match today's two equal segments.

**Convention.** `halo-remote-panel-style` layout line 2 today says "Watch | Listen — two equal segments." Change it to: equal segments for each **implemented** experience mode; Watch and Listen are the current pair.

**No empty future tabs.** Do not register lighting/climate/blinds/scenes in this child.

## Changes

1. `DirectorClient.js` — `extractRooms(uiConfig, items, types)` uses `types` when it is a non-empty array of strings; otherwise `["watch", "listen"]`. Filter `exp.type` with that list. Export stays the same.
2. `tests/director-client.test.js` — keep the cameras/comfort/lights skip on the default call. Add one assertion: `extractRooms(camerasUi, camerasItems, ["lights"])` returns the Hall lights room only.
3. `Service.qml` — add `experienceModes` as above. `refreshRooms` / room rebuild passes the mode ids into `extractRooms` (map `experienceModes[].id`). `setSourceMode` still rejects unknown ids.
4. `Panel.qml` — replace the two hardcoded `HaloRow`s in `modeRow` with a `Repeater` bound to `experienceModes`.
5. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — experience switch is N equal implemented-mode segments, not a literal two-tab Watch/Listen.

## Boundaries

- Do not add lighting, climate, blinds, or scenes to `experienceModes`
- Do not change `SELECT_VIDEO_DEVICE` / `SELECT_AUDIO_DEVICE`
- Do not show rooms that only have unimplemented types
- Do not add a new `.qml` file (shell restart for a Repeater change is unnecessary)
- Do not restyle the bar chip

## Risks

- A width binding that uses `Repeater.count` before the model lands can divide by zero — treat n < 1 as "hide the row" (same as `hasFocusedRoom` already hides it).
- Passing `types` incorrectly (e.g. always `Object.keys` of the payload) would show thermostat rooms immediately. Default must stay watch/listen.
- Renaming `sourceMode` would ripple through Watch/Listen, browse, and the virtual remote. Do not rename.

## Acceptance Criteria

- AC-1: WHILE a room is focused THE SYSTEM SHALL show one equal Halo segment per entry in `experienceModes`
- AC-2: THE SYSTEM SHALL keep Watch and Listen as the only `experienceModes` entries in this child
- AC-3: WHEN `extractRooms` is called without `types` THE SYSTEM SHALL skip cameras, comfort, and lights rooms
- AC-4: WHEN `extractRooms` is called with `types` that include `lights` THE SYSTEM SHALL include a lights-only room
- AC-5: IF `setSourceMode` is given an id not in `experienceModes` THEN THE SYSTEM SHALL no-op

## Validation

`node tests/director-client.test.js` — default skip still passes; new lights-allow assertion passes. Live: Deck/Office still show Watch | Listen only, same rooms as before. No new tabs.
