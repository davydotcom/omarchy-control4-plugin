---
title: Watch remote lost on reopen and room change
slug: watch-remote-lost-on-reopen
type: bug
status: completed
domain: engineering
size: small
horizon: now
severity: high
priority: high
root_cause_class: design
parent: watch-source-virtual-remote
relates-to:
  - room-now-playing
  - watch-and-listen
  - virtual-remote-dpad
  - focused-room
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
claimed_by: david-estes
claimed_at: 2026-08-23T16:30:06-04:00
completed_at: 2026-08-23T20:33:27Z
---
# Watch remote lost on reopen and room change

## Issue

Reported by David Estes on 2026-08-23. Every time the panel opens, it has forgotten that the focused room is already on Apple TV. Tapping that source again POSTs `SELECT_VIDEO_DEVICE`, which pauses playback or opens Apple TV My Menu. Same wipe on a room change: the new room's current Watch source is not shown drilled into the virtual remote.

## Investigation

### Observations

1. **`selectedSourceId` and `remoteOpen` are process memory only.** They are not in `focus.json` (that file is `{ "roomId" }`). A shell/plugin restart starts at the Watch list with nothing chosen.
2. **Room change wipes them on purpose.** `setFocusedRoom` (`Service.qml:222-236`):

```qml
selectedSourceId = null
closeBrowse()
closeRemote()
_rebuildSources(true)
refreshVolume()
```

3. **Watch tap always POSTs select.** `selectSource` (`Service.qml:250-278`) has no "already this device" guard. Every tap of Apple TV does:

```qml
var command = sourceMode === "listen" ? "SELECT_AUDIO_DEVICE" : "SELECT_VIDEO_DEVICE"
selectedSourceId = n
directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, { deviceid: n }, function() {})
```

then `openWatchRemote(n)`. Apple TV treats a fresh `SELECT_VIDEO_DEVICE` as a source (re)take — pause / My Menu — which matches the report.

4. **Director already knows the current device.** `room-now-playing` recorded a live `GET /api/v1/items/{roomId}/variables` on this house with `CURRENT_VIDEO_DEVICE`, `PLAYING_AUDIO_DEVICE`, `LAST_DEVICE_GROUP` (`"watch"` / `"listen"`), plus the volume/power vars we already poll. The volume GET is `varnames=CURRENT_VOLUME,IS_MUTED,POWER_STATE` only (`Service.qml:828`). Those media ids are never read, so the plugin cannot restore.

5. **Panel hide does not destroy Service.** `BarWidget.qml` Loader stays `active: true`; `controller.show()` / `hide()` only pop the panel. If the user left the remote open, it should still be open. The painful path is: Back (or room change, or restart) → source list → tap Apple TV again → SELECT. User asked that **opening the panel** show the remote drilled down, like the hardware remote waking onto the active source.

6. **Watch source ids on this Director match item ids** (Office Apple TV `295`, Base Fam `431`). `CURRENT_VIDEO_DEVICE` is expected to be that id. If it is a protocol parent/child, `itemForWatchRemote` already walks that graph.

### Root cause

`watch-and-listen` modeled every source row as "take this source now." The virtual remote then assumed you had just taken it. There is no path that means "this room is already on that source — show its remote, do not SELECT again." Room change clears memory and never asks the Director what the new room is watching.

Classification: **design** (missing restore; SELECT is not idempotent). Secondary **code**: `setFocusedRoom` nulls selection with no restore.

### Severity

High — a panel open or room switch interrupts whatever is on the TV. Workaround is "don't tap," which leaves you stuck on the source list with no D-pad.

## Kickoff

Opening the panel or changing rooms forgets Apple TV, so tapping it again POSTs SELECT and hits pause / My Menu.

**Status:** completed — archived; restore from `CURRENT_VIDEO_DEVICE`; tap of the current source skips SELECT.

**Pick up at:** `/design virtual-remote-numbers` — digit pad / channel up-down, only where the source declares channel capability.

→ `.hero/specs/watch-remote-lost-on-reopen/spec.md`

**Files:** `DirectorClient.js:373`, `Service.qml:306`, `Panel.qml:281`

**Skip:** chip now-playing (`room-now-playing`); auto-opening Listen MSP browse; persisting last tap in `focus.json` instead of Director state.

## Goal

On panel open and on room change, if the focused room is already watching a source that has Watch-remote UI, show that remote without posting `SELECT_VIDEO_DEVICE`. Tapping the already-current source must not SELECT again.

## Suggested Fix Approach

### 1. `DirectorClient.js` — `parseRoomVolume`

**Before:** returns `{ volume, muted, power }` from `CURRENT_VOLUME` / `IS_MUTED` / `POWER_STATE`.

**After:** also parse, when present (same `varName` keying as volume):

- `CURRENT_VIDEO_DEVICE` → `videoDeviceId` (finite number or `null`)
- `PLAYING_AUDIO_DEVICE` → `playingAudioDeviceId` (not `CURRENT_AUDIO_DEVICE` — that is the digital-media player on this Director)
- `LAST_DEVICE_GROUP` → `lastDeviceGroup` (`"watch"` / `"listen"` / `""`)

Missing keys stay `null` / `""`. Existing volume tests must still pass.

Add `matchWatchSourceId(sources, items, deviceId)`: if `deviceId` is a Watch list id, return it; else return the Watch list id whose `itemForWatchRemote(items, source.id)` is `deviceId`; else `null`.

**Why:** one parser, no invented field names, parent/child Watch ids already solved.

### 2. `Service.qml` — poll extra varnames, stash, restore, skip SELECT

**Before:** `refreshVolume` GETs `CURRENT_VOLUME,IS_MUTED,POWER_STATE`. `setFocusedRoom` / `setSourceMode` null `selectedSourceId` and `closeRemote()`. `selectSource` always POSTs.

**After:**

- Extend the existing GET `varnames` with `CURRENT_VIDEO_DEVICE,PLAYING_AUDIO_DEVICE,LAST_DEVICE_GROUP`. Do **not** add a second poll. Stash `currentVideoDeviceId` / `playingAudioDeviceId` / `lastDeviceGroup` from every volume parse (like `roomOn`).
- `restoreActiveSource()` (no POST):
  - If `currentVideoDeviceId` matches a Watch source via `matchWatchSourceId`, set `sourceMode` to `"watch"`, `selectedSourceId` to that id, `closeBrowse()`, `openWatchRemote(id)` when `hasWatchRemoteUi`, else `closeRemote()`.
  - Else if `lastDeviceGroup === "listen"` and `playingAudioDeviceId` is in the Listen list, set Listen + `selectedSourceId`, `closeRemote()`, do **not** open MSP browse.
  - If `roomOn === false`, do not open the remote.
- Call `restoreActiveSource()` from: volume GET callback after `setFocusedRoom` / `_applyRooms` (when selection was just cleared), and from `Panel.open()`.
- Do **not** call it on every periodic volume tick — that would undo Back while the panel stays open.
- `selectSource`: if the tapped id already equals `currentVideoDeviceId` or the matched Watch id (Watch) / `playingAudioDeviceId` (Listen), skip the SELECT POST; still open the Watch remote if needed.

**Why:** Director is per-room truth. Local `focus.json` last-tap would restore the wrong room's Apple TV.

### 3. `Panel.qml` — restore on show

**Before:** `open()` only `controller.show()`.

**After:** `open()` also `session.restoreActiveSource()`.

**Why:** user wants reopen to land on the drilled-down remote, not the list.

### 4. `tests/director-client.test.js`

Fixtures: `varName: "CURRENT_VIDEO_DEVICE", value: 431`; string ids; absent → null; `PLAYING_AUDIO_DEVICE` vs ignoring `CURRENT_AUDIO_DEVICE`; `matchWatchSourceId` self + parent/child. Volume/power cases unchanged.

## Approach

Halo / this plugin should wake onto what the room is already doing. SELECT is for *changing* source. Restore is a read. Back still returns to the source list **until the panel is closed**; the next open restores again.

## Changes

1. `DirectorClient.js` — extend `parseRoomVolume`; add `matchWatchSourceId`.
2. `tests/director-client.test.js` — media-id fixtures + match helper.
3. `Service.qml` — extra varnames; stash; `restoreActiveSource`; skip duplicate SELECT; restore after room apply.
4. `Panel.qml` — `open()` calls `restoreActiveSource`.

## Boundaries

- No chip / header now-playing chrome — `room-now-playing` (reuse this parser when that spec is designed)
- No auto-open of Listen MSP browse (`listen-library-browse`)
- Do not write last source into `focus.json`
- Do not POST SELECT/AUDIO as part of restore
- Do not restore on every volume poll (preserves Back)
- Digits pad still `virtual-remote-numbers`

## Risks

- `CURRENT_VIDEO_DEVICE` might be a protocol parent, not the Watch list id — `matchWatchSourceId` must use `itemForWatchRemote`.
- Restoring on every panel open undoes Back-then-reopen; that is intended.
- Stale `currentVideoDeviceId` until the first GET after a room change — do not SELECT while waiting; wait for the callback.
- Listen highlight without browse may look like a no-op; acceptable for this bug.

## Acceptance Criteria

- **AC-1:** WHEN the panel opens and the focused room's `CURRENT_VIDEO_DEVICE` is a Watch source with remote UI THE SYSTEM SHALL show that remote without posting `SELECT_VIDEO_DEVICE`
- **AC-2:** WHEN the user changes focused room THE SYSTEM SHALL restore that room's current Watch remote the same way, without SELECT
- **AC-3:** WHEN the user taps the Watch source that is already `CURRENT_VIDEO_DEVICE` THE SYSTEM SHALL NOT post `SELECT_VIDEO_DEVICE` and SHALL still open the remote if it was closed
- **AC-4:** WHEN the user taps a different Watch source THE SYSTEM SHALL post `SELECT_VIDEO_DEVICE` as today
- **AC-5:** IF the room is off THEN THE SYSTEM SHALL NOT open the Watch remote from restore

## Test Plan

**Existing:** `parseRoomVolume` volume/mute/power fixtures (`tests/director-client.test.js:254-313`); `itemForWatchRemote` parent/child; Watch `extractSources` ids.

**Needed:** parse `CURRENT_VIDEO_DEVICE` / `PLAYING_AUDIO_DEVICE` / `LAST_DEVICE_GROUP`; `matchWatchSourceId`; volume tests still pass when extra rows are present.

**Regression:** volume slider still tracks `CURRENT_VOLUME`; Back still closes the remote while the panel stays open; Sony Receiver surround-only still restores if it is `CURRENT_VIDEO_DEVICE`.

## Validation

`node tests/director-client.test.js` prints `ok`. Live: Watch → Apple TV → close panel → open panel → remote is up, TV does not pause / My Menu. Switch room that is on Apple TV → remote for that room, no SELECT. Tap the already-chosen Apple TV row after Back → remote opens, no hitch on the TV.

## Completion Ledger

Restore Watch remote from Director room variables. Stack: QML + `.pragma library` JS (Node `vm` tests). No SELECT on restore or on tap of the already-current source.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- `/usr/lib/qt6/bin/qmllint Panel.qml` and `Service.qml` — 0 errors
- Copied `DirectorClient.js` `Service.qml` `Panel.qml` to the live plugin and `omarchy restart shell`

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | WHEN the panel opens and CURRENT_VIDEO_DEVICE is a Watch source with remote UI THE SYSTEM SHALL show that remote without SELECT | DONE | `Panel.qml:281-284` `open()` → `restoreActiveSource()` (`Service.qml:306-327`); no `directorPost` in restore |
| 2 | WHEN the user changes focused room THE SYSTEM SHALL restore that room's Watch remote without SELECT | DONE | `setFocusedRoom` sets `_wantSourceRestore` (`Service.qml:238`); volume GET applies restore (`:903-905`). `_applyRooms` same flag (`:1045`) |
| 3 | WHEN the user taps the already-current Watch source THE SYSTEM SHALL NOT post SELECT and SHALL still open the remote | DONE | `_alreadyCurrentSource` (`Service.qml:297-304`); `selectSource` skips POST (`:273-277`) then still `openWatchRemote` (`:279-283`) |
| 4 | WHEN the user taps a different Watch source THE SYSTEM SHALL post SELECT_VIDEO_DEVICE | DONE | `already` false → POST (`Service.qml:275-277`) unchanged command/body |
| 5 | IF the room is off THEN THE SYSTEM SHALL NOT open the Watch remote from restore | DONE | `Service.qml:318-320` `roomOn === false` → `closeRemote()` |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Extend `parseRoomVolume`; add `matchWatchSourceId` | DONE | `DirectorClient.js:357-411,617-642` |
| 2 | Tests for media ids + match helper | DONE | `tests/director-client.test.js:314-330,443-447` |
| 3 | Extra varnames, stash, restore, skip duplicate SELECT | DONE | `Service.qml:79-82,238,273-327,892-905,1045` |
| 4 | `Panel.open` calls `restoreActiveSource` | DONE | `Panel.qml:281-284` |

### Exercise-the-feature check

- [x] Live plugin copy + `omarchy restart shell`. Parser/match unit-tested. On-panel open after Watch Apple TV was not clicked this turn (no GUI driver; user live).

### Excellence Bar self-check

Yes — restore is a read of Director room state, SELECT stays for changing source, Back is not undone by the volume poll, and parent/child Watch ids reuse `itemForWatchRemote`.
