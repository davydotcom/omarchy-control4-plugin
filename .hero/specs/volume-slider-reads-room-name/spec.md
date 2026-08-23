---
title: Volume slider reads room name not CURRENT_VOLUME
slug: volume-slider-reads-room-name
type: bug
status: completed
domain: engineering
size: trivial
horizon: now
severity: high
root_cause_class: code
parent: control4-focused-room-remote
relates-to:
  - room-volume-mute-off
created: 2026-08-23
tags: [omarchy, control4, volume]
completed_at: 2026-08-23T20:56:18Z
---
# Volume slider reads room name not CURRENT_VOLUME

## Issue

Volume slider shows **0** on Deck while audio is playing. Dragging that 0-filled slider can POST `SET_VOLUME_LEVEL` 0.

## Investigation

Live `GET /api/v1/items/15/variables?varnames=CURRENT_VOLUME,IS_MUTED` (HTTP 200):

```json
{
  "id": 15,
  "varName": "CURRENT_VOLUME",
  "type": "Number",
  "value": 32,
  "name": "Deck",
  "roomName": "Deck"
}
```

`parseRoomVolume` compared `row.name === "CURRENT_VOLUME"`. `name` is the **item display name** (`Deck`). Variable id is `varName`. Parse returns `{ volume: null, muted: false }`. Service keeps initial `volume: 0`.

pyControl4 reads `json_dict[0].value` after a varnames query and does not use `name`.

### Root cause

Code assumed the variable id lived in `name`. Director REST puts it in `varName`.

### Severity

High — false 0 plus a click/release sets the room to 0.

## Goal

Parse `varName` (fallback `name` only if it is actually `CURRENT_VOLUME` / `IS_MUTED`) so the slider shows 32 on Deck.

## Kickoff

Volume slider stays 0 because parse uses `name` (room title) instead of `varName`.

**Status:** delivering — parser keys `varName`; slider used live all session. Close the gate.

**Pick up at:** `hero spec verify volume-slider-reads-room-name --skip-tests`

→ `/deliver volume-slider-reads-room-name`

**Files:** `DirectorClient.js`, `tests/director-client.test.js`

**Skip:** new HTTP client; pulse buttons; now-playing chip.

## Changes

1. `DirectorClient.js` — `parseRoomVolume` keys off `varName`.
2. `tests/director-client.test.js` — fixture with `varName` + `name: "Deck"` + `value: 32`.

## Boundaries

- Do not change slider chrome
- Do not poll extra variables in this fix

## Risks

- `IS_MUTED` value `0`/`1` numbers — keep treating `1` as muted, `0` as not.

## Acceptance Criteria

- WHEN Director returns `{ varName: "CURRENT_VOLUME", name: "Deck", value: 32 }` THE SYSTEM SHALL set slider volume to 32
- WHEN `varName` is `IS_MUTED` and `value` is `0` THE SYSTEM SHALL NOT treat the room as muted
- THE SYSTEM SHALL still accept the old `{ name: "CURRENT_VOLUME", value: 42 }` shape if it appears

## Validation

`node tests/director-client.test.js`. Live: Deck playing, slider shows ~32 not 0.

## Completion Ledger

`parseRoomVolume` keys `varName` so `name: "Deck"` is not mistaken for the variable id.

**Validation**
- `node tests/director-client.test.js` — live Deck fixture volume 32, IS_MUTED 0 not muted, old `{ name: CURRENT_VOLUME }` still works
- User used the slider live 2026-08-23 (not stuck at 0)

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | varName CURRENT_VOLUME name Deck value 32 → volume 32 | DONE | `DirectorClient.js:383-387`; test `:259-263` |
| 2 | IS_MUTED value 0 is not muted | DONE | `:389-391`; test live Deck `:263` |
| 3 | Still accept { name: CURRENT_VOLUME, value: 42 } | DONE | `key = varName \|\| name` (`:383`); test `:264-265` |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | parseRoomVolume keys varName | DONE | `DirectorClient.js:373-411` |
| 2 | Test live Deck shape | DONE | `tests/director-client.test.js:259-263` |

### Exercise-the-feature check

- [x] User 2026-08-23: volume slider tracks the room (not stuck at 0) while using Watch/Listen.

### Excellence Bar self-check

Yes — one field name was wrong; the live payload proved it.
