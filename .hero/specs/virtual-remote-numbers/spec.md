---
title: Virtual remote numbers
slug: virtual-remote-numbers
type: feature
status: completed
domain: engineering
size: small
horizon: now
parent: watch-source-virtual-remote
depends-on:
  - virtual-remote-dpad
relates-to:
  - remote-command-metadata
  - virtual-remote-transport
  - halo-remote-panel-style
created: 2026-08-23
tags: [omarchy, control4, watch, remote, cable]
claimed_by: david-estes
claimed_at: 2026-08-23T16:48:42-04:00
completed_at: 2026-08-23T20:50:33Z
---
# Virtual remote numbers

## Context

Last child of `watch-source-virtual-remote`. Parser already records `hasDigits`, `hasChannelUpDown`, and `hasDiscreteChannelSelect` (`remote-command-metadata`). D-pad, transport, and surround ship. Apple TVs list `NUMBER_0`…`NUMBER_9` but have **no** channel capability — a pad there is a fake control. Item `20` Cable DVR (`cable` / Xfinity X1) declares `has_channel_up_down` and `has_discrete_channel_select`. David Estes (2026-08-23): design and build now; **live channel-tune later** — no current device is in daily use for this pad.

`hasWatchRemoteUi` is nav OR transport OR surround. Cable DVR is none of those today, so Watch → Cable DVR never opens a remote.

Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

Channel-capable Watch sources get Ch− / Ch+ and a 0–9 pad (plus `*` / `#` when declared). Taps reuse `sendRemote`. Sources that only list `NUMBER_*` get no pad. Cable-only sources still open the remote. Live tune on the X1 is deferred.

## Kickoff

Channel pad for sources that declare channel capability — not Apple TV digits. Live tune later.

**Status:** completed — pad shipped; live X1 tune still later.

**Pick up at:** when Cable DVR is in use, Watch → Cable DVR and enter a channel.

→ done

**Files:** `DirectorClient.js:586`, `Service.qml:426`, `Panel.qml:63`, `tests/director-client.test.js:413`

**Skip:** channel guide / EPG; DVR recordings; favourites; buffered multi-digit commit; live Director POST; showing digits on Apple TV.

## Approach

**Gate (show).** `hasChannelUpDown` and/or `hasDiscreteChannelSelect`. Never `hasDigits` alone.

**Per-key visibility.** Flag **and** the matching command in `commands[]` (same honesty as nav/transport). `sendRemote` already no-ops unknown names.

| Flag | Keys | Commands |
|---|---|---|
| `hasChannelUpDown` | Ch− Ch+ | `CHANNEL_DOWN` `CHANNEL_UP` |
| `hasDiscreteChannelSelect` | 1–9, 0 | `NUMBER_1`…`NUMBER_9` `NUMBER_0` |
| same + command present | * # | `STAR` `POUND` |

**Open-remote.** `hasWatchRemoteUi` also true when either channel flag is set, so Cable DVR opens with only this cluster.

**Press.** Reuse `sendRemote`. One tap, one command, empty `tParams`, device item. No buffer, no timeout commit, no `SET_CHANNEL` (not verified). Prefix-tune risk is accepted until live test.

**Layout.** Under transport, above surround, same compact `Row` / `HaloRow` as transport (primary fill, `haloText`, centered, word labels — not emoji):

```
[ Ch- ] [ Ch+ ]
[ 1 ] [ 2 ] [ 3 ]
[ 4 ] [ 5 ] [ 6 ]
[ 7 ] [ 8 ] [ 9 ]
[ * ] [ 0 ] [ # ]
```

Omit an empty row. Last row equal-widths among visible keys (`*` / `0` / `#`). No orange rail (`drop-halo-row-accent-tick`). Height from `remotePad.implicitHeight` (already).

**Labels.** `Ch-` `Ch+` `0`–`9` `*` `#`.

## Changes

1. `DirectorClient.js` — `hasWatchRemoteUi` true when `hasChannelUpDown` or `hasDiscreteChannelSelect`. Parser stays as it is.
2. `tests/director-client.test.js`
   - `hasWatchRemoteUi(cableCaps) === true`
   - digits-only (no channel flags) does **not** open
   - dvd/c4z still open via nav and still `!hasChannelUpDown`
   - receiver still opens on surround, still no channel pad
3. `Service.qml` — `remoteChannelUp`, `remoteChannelDown`, `remoteNumberPad`, `remoteStar`, `remotePound`. `_applyRemoteCaps` sets them from flags + `hasRemoteCommand`. No new send function.
4. `Panel.qml` — channel row + four digit rows after transport, before surround. `listRowCount` includes those rows.
5. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — Exceptions: channel pad is this child, gated on channel capability.

## Acceptance Criteria

- **AC-1:** WHEN a watch source declares `has_channel_up_down` and the matching `CHANNEL_*` commands THE SYSTEM SHALL show Ch− / Ch+
- **AC-2:** WHEN a watch source declares `has_discrete_channel_select` and `NUMBER_0`…`NUMBER_9` THE SYSTEM SHALL show a 0–9 pad
- **AC-3:** IF a watch source declares `NUMBER_*` and neither channel flag THEN THE SYSTEM SHALL NOT show a channel pad
- **AC-4:** WHEN the user taps a visible channel or digit key THE SYSTEM SHALL POST that command to `/api/v1/items/{remoteDeviceId}/commands` with empty `tParams` without blocking
- **AC-5:** IF a watch source declares a channel flag and neither navigation, transport, nor surround THEN THE SYSTEM SHALL still open the watch remote
- **AC-6:** Live tune of a multi-digit channel on Cable DVR — deferred; user signed off 2026-08-23

## Boundaries

- No guide / EPG / recordings / favourites
- No buffered multi-digit entry or on-screen readout
- No Apple TV digit pad
- No live Director POST from the agent
- No Flickable unless a later live session clips

## Risks

- Per-digit send may tune a prefix on some boxes. Live test owns that; do not invent `SET_CHANNEL` now.
- Extending `hasWatchRemoteUi` flips the cable fixture from “does not open” to “opens.”
- A 12-key pad under a full Apple TV remote is tall — Apple TVs must not get it.

## Validation

`node tests/director-client.test.js` — pass (`ok`). Live copy + `omarchy restart shell`. Live X1 tune is later.

## Completion Ledger

Channel pad gated on capability flags, not `NUMBER_*`. Cable DVR now opens a remote. Taps reuse `sendRemote`. Live multi-digit tune deferred per user 2026-08-23.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- Live copy + `omarchy restart shell` on 2026-08-23
- Live Cable DVR tune: not run (user: test later)

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Channel flags + CHANNEL_* show Ch− / Ch+ | DONE | `Panel.qml:833-855`; flags `Service.qml:447-448` require `hasChannelUpDown` and `hasRemoteCommand` |
| 2 | Discrete select + digits show 0–9 pad | DONE | `Panel.qml:859-987`; `remoteNumberPad` is `hasDiscreteChannelSelect && hasDigits` (`Service.qml:449`) |
| 3 | NUMBER_* without channel flags shows no pad | DONE | `hasWatchRemoteUi(digitsOnlyCaps) === false` (`tests/director-client.test.js:476-479`); dvd `!hasChannelUpDown` (`:480`) |
| 4 | Tap POSTs CHANNEL_* / NUMBER_* with empty tParams | DONE | Keys call existing `sendRemote` (`Panel.qml:845,854,871+`); `Service.qml` sendRemote empty `{}` |
| 5 | Channel-only source still opens the remote | DONE | `DirectorClient.js:591-592`; `hasWatchRemoteUi(cableCaps) === true` (`tests/director-client.test.js:475`) |
| 6 | Live multi-digit tune on Cable DVR | SKIPPED | [signed-off] User 2026-08-23: no device in daily use; test later. Per-digit send, no buffer |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `hasWatchRemoteUi` includes channel flags | DONE | `DirectorClient.js:591-592` |
| 2 | Tests: cable opens, digits-only does not, dvd/receiver no pad | DONE | `tests/director-client.test.js:475-481` |
| 3 | Service channel/number flags | DONE | `Service.qml:50-54,447-451`; no new send function |
| 4 | Panel channel row + four digit rows + listRowCount | DONE | `Panel.qml:71-72,833-996` |
| 5 | Convention exception names this child | DONE | `halo-remote-panel-style` Exceptions: channel pad gates on capability flags |

### Exercise-the-feature check

- [x] Unit tests cover open-gate and Apple-TV-must-not-get-a-pad. Live plugin copied + shell restarted. Live X1 channel tune not exercised (user deferred).

### Excellence Bar self-check

Yes — the gate is the capability flags the parent already locked, Cable DVR can finally open a remote, and Apple TV digits stay unused.
