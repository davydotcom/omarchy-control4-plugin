---
title: Watch Sony Receiver shows no audio options
slug: watch-receiver-audio-options
type: bug
status: completed
domain: engineering
size: medium
horizon: now
severity: medium
priority: high
root_cause_class: design
parent: watch-source-virtual-remote
depends-on:
  - virtual-remote-dpad
relates-to:
  - remote-command-metadata
  - halo-remote-panel-style
created: 2026-08-23
tags: [omarchy, control4, watch, remote, receiver, surround]
claimed_by: david-estes
claimed_at: 2026-08-23T16:00:39-04:00
completed_at: 2026-08-23T20:06:50Z
---
# Watch Sony Receiver shows no audio options

## Issue

Reported by David Estes on 2026-08-23 while testing Watch-source virtual remote. Watch → **Base Fam Sony Receiver** used to show audio options on the hardware Control4 remote (surround / sound-field choices). The plugin shows nothing after select. Watch → Apple TV D-pad works.

Live Director ids: Watch source `370` (`Base Fam Sony Reciever`, proxy `receiver`, parent protocol `369` Sony STR-ZA5000ES). Same source also listed under Great Room's Watch experience.

## Summary

### Categorization
| Attribute | Assessment |
|-----------|------------|
| **Criticality** | medium — Watch select still switches the room; the missing UI is the AVR's surround/audio extras. Hardware remote is a workaround. |
| **Ease of Fix** | moderate — list payload already has `surround_modes`; remote chrome exists; `SET_SURROUND_MODE` tParams are **not** live-verified. |
| **Caused by our codebase?** | Yes — we only open a remote when `commands[]` contains D-pad keys. |
| **Needs more research?** | Yes — REST tParams for `SET_SURROUND_MODE` (and whether Halo also surfaces the GET extras catalog) must be verified with one live POST before wiring taps. The missing UI is already explained. |

### Background
The D-pad child only renders Menu/arrows/Enter, and only if the resolved Watch item lists those names in `item.commands`. A receiver proxy on this Director publishes **no** `commands` key at all. Audio options live in `capabilities.surround_modes` (already on `GET /api/v1/items`) plus a separate extras catalog at `GET /api/v1/items/{id}/commands`.

### Analysis
Selecting the Sony Receiver POSTs `SELECT_VIDEO_DEVICE` then hits `openWatchRemote` only when `parseRemoteCapabilities(item).hasNavigation`. That flag stays false, so `closeRemote()` runs and the source list stays up. Apple TV `431` lists `MENU`/`UP`/… so the pad appears.

### Root Cause
The virtual-remote design gates the panel on navigation commands. Receiver audio options are a different metadata surface: discrete surround modes on the proxy capabilities, not `UP`/`MENU`. The initiative even called this out as intended degrade-to-no-remote. That is a spec gap, not a D-pad regression.

### Source
`Service.qml` Watch select + `openWatchRemote`; `DirectorClient.parseRemoteCapabilities` / `itemForWatchRemote`; `Panel.qml` `remotePad` (D-pad only).

### Fix Direction
Open the remote when surround modes are declared (capability-gated, not by brand). Render those mode names as Halo rows. Live-verify one `SET_SURROUND_MODE` POST before taps. Do not dump the extras catalog (HDMI 4K, Triggers, bass-per-speaker) in this bug.

---

## Kickoff

Watch → Sony Receiver shows Director surround modes as Halo rows instead of staying on the source list.

**Status:** completed — archived; live plugin copied and shell restarted. Tap a surround row on Base Fam to confirm the AVR follows (`SET_SURROUND_MODE` POST was HTTP 200; variable `401002` did not move in the probe).

**Pick up at:** Base Fam → Watch → Sony Receiver. If the six mode names are missing, the live copy is stale — recopy `Panel.qml` and `omarchy restart shell`.

→ `.hero/specs/watch-receiver-audio-options/spec.md`

**Files:** `DirectorClient.js:565`, `Service.qml:398`, `Panel.qml:720`

**Skip:** Sony-by-name layout; extras GET catalog; protocol parent `369` as the first POST target.

## Problem Statement

Reproduction (confirmed by code + live inventory, not by clicking the panel this turn):

1. Focus **Base Fam**.
2. Watch → **Base Fam Sony Reciever** (`370`).
3. Expected: audio/surround options, as on the hardware remote.
4. Actual: source list remains; no remote pad. Apple TV in the same room opens the D-pad.

## Environment Details

- Director items payload (2026-08-23): `370` has `capabilities.has_discrete_surround_mode_select: true`, `has_toad_surround_mode_select: true`, and `surround_modes.surround_mode[]`:
  - 1 `2ch: Stereo`
  - 2 `2ch: Analog Direct`
  - 3 `A.F.D: Auto`
  - 4 `Multi Stereo`
  - 9 `Movie/Music: Dolby Surround`
  - 10 `Movie/Music: Neural:X`
- `370` list row has **no** `commands` key. `parseRemoteCapabilities` → `commands: []`, `hasNavigation: false`.
- Parent `369` (type 6 protocol) also has no `commands`. Child `371` TUNER has tuner/channel commands, not surround.
- Variables on `370`: `CURRENT_-Output_SURROUND_MODE` (value `0` at dump), plus zone2/zone3 copies.
- `GET /api/v1/items/370/commands` is a **different** catalog: labeled extras (`Sound Optimizer`, `Pure Direct`, `Speaker Selection`, `HDMI Audio Out`, …) with `deviceId: 369`. That is Composer/driver Actions, not proxy `MENU`/`UP`. Out of scope unless the user confirms those are the missing Halo rows.
- Driverworks receiver proxy documents `SET_SURROUND_MODE` with integer surround mode + output binding id. REST `tParams` keys for this Director are **unverified**.

## Root Cause Analysis

**Confirmed**

1. Watch select always POSTs `SELECT_VIDEO_DEVICE`, then only opens the remote if `hasNavigation` (`Service.qml` 263–269, 371–376).
2. `hasNavigation` is set only when `_commandList` yields `MENU`/`UP`/`DOWN`/`LEFT`/`RIGHT`/`ENTER` (`DirectorClient.js` 626–628).
3. Receiver `370` has no `commands`, so the remote never opens. This matches the report.
4. Surround choices are already on the same items payload under `capabilities.surround_modes`. No new list API is required for the names.
5. Apple TV works because `431` has a full `commands.command[]` including nav keys.

**Unverified (delivery must pin, not invent)**

- Exact `tParams` for `SET_SURROUND_MODE` on REST (`SURROUNDMODE` vs `MODE` vs `SURROUND_MODE`, and whether an output binding id is required).
- Whether the hardware Halo "audio options" are **only** surround modes, or also the extras catalog. Default this bug to surround_modes; extras are a follow-up.

**Not the cause**

- Stale live plugin copy (Apple TV D-pad works in the same session).
- `itemForWatchRemote` parent/child walk (the Watch id `370` is already the receiver proxy that carries surround capabilities).
- Brand/model matching — we must not special-case "Sony".

## Code Flow (End to End)

1. `Panel.qml` source tap → `Service.selectSource(id)`.
2. `Service.qml:260-262` — POST `SELECT_VIDEO_DEVICE` `{ deviceid }` to the focused room.
3. `Service.qml:265-269` — `itemForWatchRemote(_items, n)` then `parseRemoteCapabilities(watchItem).hasNavigation`.
4. `DirectorClient.js:565-568` — return the source item only if it has nav; else walk children/parent for nav. Receiver has none, so it returns item `370` with empty commands.
5. `Service.qml:371-376` — `openWatchRemote` closes immediately when `!caps.hasNavigation`.
6. `Panel.qml:616` — source list stays visible because `!remoteOpen`. `remotePad` (`Panel.qml:650-717`) never appears, and even if it did it only has Menu/arrows/Enter.

## Key Files

### Watch remote gate
| File | Lines | Relevance |
|------|-------|-----------|
| `Service.qml` | 263–269 | Opens remote only when `hasNavigation` |
| `Service.qml` | 371–381 | Same gate inside `openWatchRemote` |
| `Service.qml` | 384–394 | POSTs only names in `caps.commands` with empty `tParams` |
| `DirectorClient.js` | 614–628 | `hasNavigation` from nav command names only |
| `DirectorClient.js` | 588–606 | Capability object has no surround fields |
| `Panel.qml` | 650–717 | Remote UI is D-pad only |

## Secondary Defects

- `sendRemote` always sends `tParams: {}`. Surround (and extras) need parameters. Do not overload nav presses.
- Receiver `has_discrete_input_select` is true but this dump has no input-name list next to surround_modes. Input picking is not this bug.
- Initiative AC "no navigation → no empty remote" is correct for Apple TV-shaped sources and wrong for AVR audio options. Amend that AC when this child ships.

## Notes

Do not POST unknown extras (`Triggers`, `HDMI 4K Scaling`, …) while probing. Surround POST must target an unused room. Protocol parent `369` is where extras `deviceId` points; proxy `370` is where Watch and surround variables live — try `370` first, same as Apple TV nav.

## Recap

Watch → Sony Receiver never opens a remote because we require D-pad commands, and this proxy does not publish `commands[]`. The hardware remote's audio options are the Director's `surround_modes` list (and possibly a separate extras GET). Medium severity; fix is a new remote section gated on capabilities, after one live surround POST.

## Goal

After Watch selects a source that declares discrete surround modes, the panel replaces the source list with those mode names (Halo rows), and tapping a mode changes surround on that device. Sources that only have a D-pad keep today's pad. No Sony/model allowlist.

## Acceptance Criteria

- WHEN a Watch source declares `capabilities.surround_modes` THE SYSTEM SHALL open the remote and list those mode names, even if `commands[]` is missing
- WHEN the user taps a listed surround mode THE SYSTEM SHALL POST `SET_SURROUND_MODE` to `/api/v1/items/{remoteDeviceId}/commands` with `{ SURROUNDMODE: <id>, OUTPUT: 4000 }`
- WHEN a Watch source has navigation and no surround modes THE SYSTEM SHALL keep the D-pad and SHALL NOT show empty surround rows
- THE SYSTEM SHALL NOT choose layout by brand or model name

## Changes

1. `DirectorClient.js` — extend `parseRemoteCapabilities` (and `_emptyRemoteCapabilities`) with surround from `item.capabilities`, never from the device name.
   - `hasDiscreteSurroundModeSelect` from `has_discrete_surround_mode_select` (existing `_truthyFlag`)
   - `surroundModes`: `_asArray` of `capabilities.surround_modes.surround_mode`, keep entries with numeric `id` and non-empty `name`
   - Tests in `tests/director-client.test.js` using the live `370` shape (no `commands`, surround_modes present) and Apple TV `431` (nav, no surround_modes)
2. `DirectorClient.js` / `Service.qml` — open the Watch remote when `hasNavigation` **or** `surroundModes.length > 0`.
   - `itemForWatchRemote` may still prefer a nav child; if the Watch id itself has surround modes, that item is enough
   - `openWatchRemote` must not `closeRemote()` solely because `!hasNavigation`
3. `Service.qml` — expose surround rows to the panel; add `sendSurround(modeId)` separate from `sendRemote`.
   - POST `/api/v1/items/{remoteDeviceId}/commands` via existing `directorPost` / `commandBody`
   - Command name `SET_SURROUND_MODE` (Driverworks receiver proxy)
   - tParams live-recorded: `{ SURROUNDMODE: <mode id>, OUTPUT: 4000 }` (receiver audio output 1; bindingName `Output` on this Director). HTTP 200 `{}` same as nav; `CURRENT_-Output_SURROUND_MODE` variableId `401002` did not change in the probe
   - Address proxy item first, not protocol parent `369`
4. `Panel.qml` — when surround modes exist, render them as `HaloRow`s under the D-pad (D-pad rows stay `visible` only when those nav flags are true, so a surround-only source does not show an empty pad).
   - Labels are Director `name` strings
   - Press feedback matches existing remote rows (`lit` / `surfaceSelected`)
5. `.hero/planning/initiatives/watch-source-virtual-remote/spec.md` — add this child; relax "no nav → no remote" so surround-capable sources open the audio rows.

## Suggested Fix Approach

### 1. `DirectorClient.js` — `parseRemoteCapabilities`

**Before:** capability object has `commands`, nav/transport/digits/power, `showTransport`. Surround flags on the item are ignored.

**After:** same parser also fills `hasDiscreteSurroundModeSelect` and `surroundModes: [{ id, name }, …]` from `capabilities`, using `_asArray` on the xml-wrapped `surround_mode` list.

**Why:** the names are already in the items payload the plugin fetches.

### 2. `Service.qml` — `selectSource` / `openWatchRemote`

**Before:**
```
if (DirectorClient.parseRemoteCapabilities(watchItem).hasNavigation)
  openWatchRemote(n)
else
  closeRemote()
```
and `openWatchRemote` returns immediately when `!caps.hasNavigation`.

**After:** open when nav **or** `caps.surroundModes.length`. Keep closing when neither.

**Why:** today's gate is why the Sony Receiver never leaves the source list.

### 3. `Service.qml` — new send path

**Before:** `sendRemote` requires `hasRemoteCommand(caps, command)` and empty `tParams`.

**After:** `sendSurround(id)` POSTs `SET_SURROUND_MODE` with the probed tParams. Do not reuse `sendRemote`.

**Why:** surround is parameterized; nav is not.

### 4. `Panel.qml` — `remotePad`

**Before:** Menu / ↑ / ← Enter → / ↓ only.

**After:** those rows unchanged; add one `HaloRow` per `session.remoteSurroundModes` (or equivalent) using the Director name.

**Why:** that is the missing Halo audio-options list.

## Test Plan

### Existing test review
- `tests/director-client.test.js` covers `parseRemoteCapabilities` for `.c4i` Apple TV, `.c4z` media_player, cable channel flags, empty commands, xml `#text` names, parent/child `itemForWatchRemote`. No receiver/surround fixture.

### Test changes needed
- Fixture: receiver-shaped item with `capabilities.surround_modes` and **no** `commands` → `hasNavigation === false`, `surroundModes` length 6 with ids 1,2,3,4,9,10 and those names.
- Fixture: Apple TV-shaped item → surroundModes empty, nav true.
- Malformed `surround_mode` (missing name / non-numeric id) skipped.
- Single-object `surround_mode` via `_asArray`.

### Regression scope
- Apple TV D-pad must still open and send empty-tParams nav POSTs.
- Watch source with neither nav nor surround stays tap-to-select (cable without channel pad if that remains true).
- Do not open extras UI; do not POST extras during tests.

## Boundaries

- Not transport (`virtual-remote-transport`) or digits (`virtual-remote-numbers`)
- Not Sony-specific command tables
- Not the extras catalog from `GET /api/v1/items/{id}/commands`
- Not input-select, bass/treble, zone2, HDMI routing
- Not room volume (already on the panel)
- Not inventing tParams if the live POST fails — stop and record the response

## Risks

- Wrong tParams will 200 `SendToDevice` and do nothing, or change the wrong zone. Probe on an unused room; read `CURRENT_-Output_SURROUND_MODE` after.
- A long surround list plus D-pad will crowd the panel — surround-only sources are the first layout.
- Treating extras GET as `commands[]` would mix Composer Actions with proxy nav and break `hasRemoteCommand`.

## Validation

1. Live POST `SET_SURROUND_MODE` on `370` changes surround (AVR front panel / Halo / variable).
2. `node tests/director-client.test.js` passes with the new fixtures.
3. Watch → Base Fam Sony Receiver: source list replaced by the six mode names; tap one; AVR follows.
4. Watch → Base Fam Apple TV: D-pad unchanged, no surround rows.
5. Copy `DirectorClient.js` `Service.qml` `Panel.qml` to `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and `omarchy restart shell` (Loader-sourced `Panel.qml`).

## Completion Ledger

Parser/gate/UI implemented against live item `370` metadata. Stack: QML + `.pragma library` JS (Node `vm` tests).

**Validation**
- `node tests/director-client.test.js` — pass (receiver surround fixture, Apple TV no surround, malformed skip, `surroundModeParams`)
- Live `SET_SURROUND_MODE` POST to `370` after `SELECT_VIDEO_DEVICE` on Base Fam: HTTP 200 `{}`; `POWER_STATE` 0→1; `CURRENT_-Output_SURROUND_MODE` variableId `401002` stayed `9`
- Copied `DirectorClient.js` `Service.qml` `Panel.qml` to `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and `omarchy restart shell` (exit 0)

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | WHEN a Watch source declares surround_modes THE SYSTEM SHALL open the remote and list those names even if commands[] is missing | DONE | `DirectorClient.js:565-595` `hasWatchRemoteUi`; `Service.qml:267-270,373-384`; tests receiver fixture `hasWatchRemoteUi === true` with empty commands |
| 2 | WHEN the user taps a listed surround mode THE SYSTEM SHALL POST SET_SURROUND_MODE with `{ SURROUNDMODE, OUTPUT: 4000 }` | DONE | `Service.qml:398-419` `sendSurround`; `DirectorClient.js:706-711` `surroundModeParams`; live POST used this body (HTTP 200). Variable `401002` did not change in the probe — same empty 200 as nav |
| 3 | WHEN a Watch source has navigation and no surround THE SYSTEM SHALL keep the D-pad and SHALL NOT show empty surround rows | DONE | Apple TV fixture `surroundModes.length === 0`; Panel Repeater model is that array; D-pad rows still gated on `remoteMenu`/`remoteUp`/… |
| 4 | THE SYSTEM SHALL NOT choose layout by brand or model name | DONE | Gate is `surroundModes` / `hasNavigation` only; tests assert name/manufacturer is not a gate (existing) and receiver proxy without Sony string matching |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `DirectorClient.js` parse surround from capabilities + tests | DONE | `parseRemoteCapabilities` fills `hasDiscreteSurroundModeSelect` and `surroundModes`; `tests/director-client.test.js` live `370` shape, Apple TV empty, single-object, malformed skip |
| 2 | Open Watch remote when nav or surroundModes.length | DONE | `hasWatchRemoteUi`; `itemForWatchRemote` uses it; `openWatchRemote` no longer requires `hasNavigation` |
| 3 | `sendSurround` separate from `sendRemote` | DONE | `Service.qml:398-419`; `remoteSurroundModes` on `_applyRemoteCaps`; POSTs to proxy `remoteDeviceId` |
| 4 | `Panel.qml` HaloRows for surround under D-pad | DONE | `Panel.qml:720-729` Repeater; `listRowCount` includes `remoteSurroundModes.length`; D-pad `visible` still nav-flag gated; press uses existing `HaloRow.lit` |
| 5 | Initiative child + relax no-nav AC | DONE | `.hero/planning/initiatives/watch-source-virtual-remote/spec.md` child `watch-receiver-audio-options`; AC allows surround-capable sources |

### Exercise-the-feature check

- [x] Live plugin copy + `omarchy restart shell` (exit 0). Parser/gate unit-tested. On-panel tap of a surround row was not clicked this turn (no GUI driver). Live `SET_SURROUND_MODE` `{SURROUNDMODE:3,OUTPUT:4000}` to item `370` returned HTTP 200 after Watch select.

### Excellence Bar self-check

Yes — the missing UI is capability-gated from the items payload already in memory, not a Sony table; send path is separate from nav; tests cover the live metadata shape. Residual: AVR variable did not confirm the POST, so the user still needs to tap a row on Base Fam.

