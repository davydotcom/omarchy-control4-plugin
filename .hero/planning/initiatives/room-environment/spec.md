---
title: Room environment
slug: room-environment
type: initiative
status: planning
domain: engineering
size: large
horizon: later
created: 2026-08-23
tags: [omarchy, control4, lighting, climate, shades, scenes]
relates-to:
  - control4-focused-room-remote
  - halo-remote-panel-style
  - rooms-from-ui-config-join-items
  - halo-panel-chrome
child:
  - experience-switch
  - room-lighting
  - room-climate
  - room-blinds
  - room-scenes
---
# Room environment

## Vision

The Halo panel is a **room remote**, not an AV-only remote. This house has Watch and Listen and nothing else — no lighting, climate, blinds, or scenes to drive — so those doors stay dark. The widget still has to be shaped so a later house (or this one, if Composer grows) can add them without rewriting the mode row, the room catalog, or Watch/Listen.

## Goal

Stage scenes, lighting, temperature, and blinds as later children, and ship one small now-child that makes the panel's experience switch a list of implemented modes instead of a hardcoded Watch | Listen pair. Success is: this house still shows exactly Watch and Listen, and adding Lighting later is "register a mode + handler," not a second two-tab rewrite.

## Kickoff

Stage lighting, climate, blinds, and scenes for later; open the Halo switch so those modes can register.

**Status:** planning — switch child is designed; the four environment children are stubs. This Director has no those experiences to implement against.

**Pick up at:** `/deliver experience-switch` — Repeater over `experienceModes`, `extractRooms` takes an implemented-types list.

→ `/deliver experience-switch`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `tests/director-client.test.js`

**Skip:** drawing Lighting/Climate/Shades/Scenes UI; inventing commands; cameras; changing Watch/Listen select.

## Why a sibling, not a child of the AV initiative

`control4-focused-room-remote` is the one-room AV remote and its Boundaries explicitly defer lights / climate / shades / scenes. Same pattern as `watch-source-virtual-remote` and `multi-room-audio`: a follow-on initiative, not a late child that reopens V1.

This house is the reason the four environment children stay `horizon: later`. We cannot verify their Director commands here. `/design` on those stubs starts by reading a Director that actually publishes that experience.

## What is already true in this repo

- `GET /api/v1/agents/ui_configuration` experiences carry `type` beyond AV: the rooms decision names `watch` / `listen` / cameras / comfort / … ([rooms-from-ui-config-join-items](../../knowledge/decisions/rooms-from-ui-config-join-items/spec.md)).
- `extractRooms` and `extractSources` only keep `watch` and `listen`. The test fixture already has `cameras`, `comfort`, and `lights` rooms and asserts they are skipped (`tests/director-client.test.js`).
- `Panel.qml` paints two fixed `HaloRow`s labeled Watch and Listen. `Service.sourceMode` is `"watch" | "listen"`.
- Rooms without watch/listen never appear. That was deliberate for an AV remote (thermostat-only / cameras-only rooms). Environment modes must **opt rooms in** when they ship, not dump every `typeName === "room"` item into the list.

## Specs

| # | Slug | Status | Size | Horizon | Depends-on | Priority | One-liner |
|---|---|---|---|---|---|---|---|
| 1 | `experience-switch` | planning | small | now | — | critical | Mode row is a Repeater over implemented modes; room catalog takes that same type list. |
| 2 | `room-lighting` | planning | medium | later | `experience-switch` | medium | Lights experience for the focused room. |
| 3 | `room-climate` | planning | medium | later | `experience-switch` | medium | Comfort / temperature for the focused room. |
| 4 | `room-blinds` | planning | medium | later | `experience-switch` | medium | Shades / blinds for the focused room. |
| 5 | `room-scenes` | planning | medium | later | `experience-switch` | medium | Room scenes — only after `/design` finds where this Director publishes them. |

## Sequenced work items

1. **Open the switch** (`experience-switch`) — the only now work. Replace the two hardcoded segments with a Repeater. Put the implemented type list in one place (`Service.experienceModes` + `extractRooms(..., types)`). Watch and Listen stay the only entries. Default `extractRooms` behavior (skip `cameras` / `comfort` / `lights`) does not change.
2. **Lighting** (`room-lighting`) — later. Leading catalog type in our tests is `lights`. `/design` must confirm live and find the commands. Do not invent them in this compose.
3. **Climate** (`room-climate`) — later. Leading type is `comfort`. UI will not be a source list (setpoint / mode). `/design` owns the control.
4. **Blinds** (`room-blinds`) — later. Type string is unverified (`shades` is the usual Control4 name; not in our fixture). Confirm live.
5. **Scenes** (`room-scenes`) — later and last. Scenes may be an experience, a lighting preset list, or Composer custom buttons. Do not assume a `scenes` type exists.

## In-flight overlap watch

All five children edit `Panel.qml` (mode row and/or the list under it) and `Service.qml` (mode registry / commands). Do not deliver two of them in the same `/drive` turn.

- `experience-switch` vs each later child — the later child appends a mode; it must not land while the Repeater/registry is being introduced.
- The four later children vs each other — they all add a handler next to the same list and registry.

Reciprocal `conflicts-with` on those pairs. Hard order for the four later children is not required; `depends-on: experience-switch` is. Prefer lighting → climate → blinds → scenes if several become deliverable at once, because lighting is the closest to today's list→select and scenes may piggyback on it.

## Approach

**Implemented modes are the allow-list.** A mode is visible on the switch only when it is in `experienceModes` and has a handler. A room is in the room list only when it has an experience whose `type` is in that same allow-list. Cameras-only rooms stay hidden until a cameras child exists (it is not in this initiative).

**Do not hardcode two tabs.** `Panel.qml` iterates `experienceModes`. Width is `(row - spacing*(n-1)) / n`. n=2 is today's look. n>3 wraps to a second row rather than shrinking labels unreadably — `/design experience-switch` may keep wrap out if this house will stay at n=2; the Repeater is the load-bearing change.

**Later children register, they do not fork.** Each adds `{ id, label }` to `experienceModes`, passes that id into `extractRooms`, and mounts its own list/controls when `sourceMode` (or a renamed `experienceMode`) matches. Watch/Listen select commands stay theirs.

**No API fiction.** Lighting / comfort / shades / scenes command names are unknown on this Director. Child `/design` reads `ui_configuration` + the item's `commands[]` on a house that has the experience. If the type is absent, the child stays parked.

## Cross-cutting concerns

- Same plugin, same focused room, same `directorGet` / `directorPost`. No second service.
- Halo tokens stay (`halo-remote-panel-style`). The convention's "Watch \| Listen" line becomes "equal segments for visible implemented modes" when `experience-switch` ships.
- Volume / Off / virtual remote stay AV chrome. Climate/lighting must not steal the volume slider.
- This house: after `experience-switch`, the panel must look the same — two segments, same rooms.

## Boundaries

- No cameras, security, sensors, or intercom (not requested)
- No Composer scene authoring
- No whole-house lighting dashboard
- No implementing lighting/climate/blinds/scenes in the switch child
- No expanding `extractRooms` default to "every experience type"
- Does not reopen Watch/Listen select or the virtual remote

## Risks

- Opening `extractRooms` to all types would surface thermostat/camera rooms the AV remote was written to skip. The allow-list is the mitigation.
- Control4 type strings are not stable in our heads: tests say `lights` and `comfort`; blinds may be `shades`. A wrong id ships a dead tab.
- Scenes may not be an experience at all. Designing them first would guess.
- A Repeater that always shows every registered mode (even with an empty catalog) would add empty Lighting/Climate tabs in this house if someone registers them early. Register only when the child ships.

## Progress

Compose landed. No children delivered.

**Next:** `/deliver experience-switch`

Then park. Do not `/design` lighting/climate/blinds/scenes until a Director in front of us actually has that experience.

## Acceptance Criteria

- AC-1: THE SYSTEM SHALL treat experience modes as an implemented allow-list, not a hardcoded Watch/Listen pair
- AC-2: WHILE this house has only watch/listen experiences THE SYSTEM SHALL show the same two segments and the same room list as today
- AC-3: WHEN a later child registers an implemented mode THE SYSTEM SHALL show that segment and include rooms that only have that experience type
- AC-4: THE SYSTEM SHALL NOT show cameras-only or comfort-only rooms until a child implements that type
- AC-5: IF a later child's experience type is absent on the Director THEN `/design` SHALL park that child rather than invent commands

## Recommended delivery order

1. `/deliver experience-switch`
2. Stop. The rest wait on a house that has the experience (or a later `/design` against live `ui_configuration` that proves one is already here and we missed it).
