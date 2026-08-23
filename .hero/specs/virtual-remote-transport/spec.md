---
title: Virtual remote transport
slug: virtual-remote-transport
type: feature
status: completed
domain: engineering
size: small
horizon: now
priority: high
parent: watch-source-virtual-remote
depends-on:
  - virtual-remote-dpad
relates-to:
  - remote-command-metadata
  - watch-receiver-audio-options
  - halo-remote-panel-style
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
claimed_by: david-estes
claimed_at: 2026-08-23T16:23:08-04:00
completed_at: 2026-08-23T20:26:00Z
---
# Virtual remote transport

## Context

Third child of `watch-source-virtual-remote`. D-pad and receiver surround rows already ship on the Watch remote. Parser already fills `hasTransport` / `transport.*` from `commands[]` (`PLAY STOP PAUSE SKIP_FWD SKIP_REV SCAN_FWD SCAN_REV`) and leaves `showTransport` as `true | false | null`. Both live Apple TVs declare all seven transport names; the `dvd` `.c4i` also sets `navigator_display_option.show_transport: true`, while the `.c4z` `media_player` omits that key (`showTransport === null`). Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`. Completed siblings: `.hero/specs/remote-command-metadata/spec.md`, `.hero/specs/virtual-remote-dpad/spec.md`, `.hero/specs/watch-receiver-audio-options/spec.md`.

## Goal

After Watch select, sources that declare transport commands show a compact play/pause/stop/skip/scan cluster under the D-pad. Taps reuse `sendRemote` (empty `tParams`, device item). Sources that declare none show no cluster. `show_transport` is never the gate.

## Kickoff

Transport cluster under the Watch D-pad — play, pause, stop, skip, scan — only where `commands[]` lists them.

**Status:** completed — archived; two glyph rows reuse `sendRemote`; `hasWatchRemoteUi` includes `hasTransport`.

**Pick up at:** `/design virtual-remote-numbers` — digit pad / channel up-down for sources that declare channel capability.

→ `.hero/specs/virtual-remote-transport/spec.md`

**Files:** `DirectorClient.js:565`, `Service.qml:43`, `Panel.qml:747`

**Skip:** playback state / combined play-pause toggle (`room-now-playing`); seek bars; Listen-side transport; requiring `show_transport`.

## Approach

**Gate.** `caps.hasTransport` (any of the seven names in `commands[]`). Do **not** read `showTransport` to show or hide the cluster. Absent is not false (already tested); an explicit `false` still must not hide keys that `commands[]` lists — `commands[]` is the source of truth locked by the parent initiative.

**Press path.** Reuse `Service.sendRemote(command)`. Same POST as nav: `/api/v1/items/{remoteDeviceId}/commands`, `commandBody`, empty `tParams`, fire-and-forget. Do **not** add `sendTransport`. Surround stays on `sendSurround`.

**Open-remote gate.** Today `hasWatchRemoteUi` is nav OR `surroundModes.length`. Add `hasTransport` so a transport-only source can open the remote. Apple TVs already open via nav; this mainly keeps the gate honest.

Updating that gate **changes a test fixture**: `itemForWatchRemote` currently uses a parent whose only command is `PLAY` as a “no UI” dummy so the walk can find a nav child. Once `PLAY` opens the remote, that parent *is* UI and the walk short-circuits. Change the dummy to a non-nav/non-transport/non-surround command (`ON` is fine) so the child-walk assertions still mean what they say.

**Layout.** Not seven full-width `HaloRow`s (the pad is already four nav rows plus optional surround). Two compact `Row`s under the D-pad and **above** the surround Repeater, same `rowHeight` / `rowSpacing` / primary `HaloRow` (fill, border, pointer, `haloText`, `centered`, `lit` press) as the D-pad mid row:

```
[ ⏮ ] [ ▶ ] [ ⏸ ] [ ⏭ ]     SKIP_REV  PLAY  PAUSE  SKIP_FWD
[ ⏪ ] [ ■ ] [ ⏩ ]           SCAN_REV  STOP  SCAN_FWD
```

Hide undeclared keys (`visible` + `height: 0`, same as nav). Size **visible** keys in a row equally — do not keep the D-pad mid-row’s always-divide-by-3 gap. Omit a whole row when none of its keys are declared.

Play and Pause stay **separate** buttons. No playback-state readback in this child, so a combined play/pause toggle would lie.

Glyphs (Unicode, matching D-pad arrows). If a glyph fails to render in the shell font, swap that label to ASCII (`|<` `>` `||` `>|` `<<` `Stop` `>>`) — do not introduce driver icons.

**No key-repeat.** A tap sends one command. SCAN without hold may be a short seek or a no-op depending on the driver; do not add press-and-hold in this child (same as D-pad).

**Height.** `listRowCount` adds 1 per visible transport row (0–2), on top of nav keys and `remoteSurroundModes.length`.

## Changes

1. `DirectorClient.js` — `hasWatchRemoteUi` returns true when `caps.hasTransport` as well as nav / surround. Parser, `_TRANSPORT_KEYS`, and `sendRemote` stay as they are.
2. `tests/director-client.test.js`
   - `hasWatchRemoteUi({ commands: { command: ["PLAY"] } }) === true`
   - receiver (surround, no transport) still opens; cable still does not
   - `itemForWatchRemote` parent dummy: replace `PLAY` with `ON` (or another non-UI command) so the child-walk tests still pass
   - existing dvd/c4z `hasTransport` / `showTransport === null` tests remain
3. `Service.qml` — properties `remotePlay`, `remoteStop`, `remotePause`, `remoteSkipFwd`, `remoteSkipRev`, `remoteScanFwd`, `remoteScanRev` (default false). `_applyRemoteCaps` copies `caps.transport.*`. `closeRemote` already clears via `_applyRemoteCaps(null)`. No new send function.
4. `Panel.qml` — two `Row`s in `remotePad` after Down, before the surround Repeater. Per-key `HaloRow`s as in Approach. `listRowCount` counts each visible transport row.
5. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — Exceptions: a metadata-gated transport cluster is this child, not a hardware overlay. Leave digits to `virtual-remote-numbers`.

## Acceptance Criteria

- **AC-1:** WHEN a watch source declaring any of `PLAY STOP PAUSE SKIP_FWD SKIP_REV SCAN_FWD SCAN_REV` is selected THE SYSTEM SHALL show those keys under the D-pad
- **AC-2:** WHEN a watch source declares none of those commands THE SYSTEM SHALL omit the transport cluster
- **AC-3:** THE SYSTEM SHALL NOT require `show_transport` (present, true, false, or absent) in order to show or hide a declared transport key
- **AC-4:** WHEN the user taps a visible transport key THE SYSTEM SHALL POST that command to `/api/v1/items/{remoteDeviceId}/commands` with empty `tParams` without blocking the UI
- **AC-5:** IF a watch source declares transport and neither navigation nor surround modes THEN THE SYSTEM SHALL still open the watch remote and show the cluster

## Boundaries

- No play/pause *state* and no combined play/pause toggle — `room-now-playing`
- No seek/scrub bar
- No Listen-side transport
- No repeat/shuffle
- No key-repeat / press-and-hold
- No digits / channel pad — `virtual-remote-numbers`
- No live Director POST from the agent

## Risks

- Extending `hasWatchRemoteUi` with `hasTransport` will break the current `itemForWatchRemote` parent-`PLAY` fixture unless that dummy command is changed (Changes §2).
- SCAN as a tap may do little on Apple TV; that is acceptable for this slice.
- Seven tiny buttons on a ~320-wide panel: two rows of equal visible keys, not seven stacked list rows.
- `Panel.qml` `remotePad` is also where `virtual-remote-numbers` will land — do not invent a numbers pad here.
- Stateless Play and Pause sitting together can look like a toggle. Keep both labeled as glyphs, not one “Play/Pause” row.

## Validation

`node tests/director-client.test.js` still prints `ok`, including the new `hasWatchRemoteUi` transport case and the updated parent-walk fixture. `qmllint` on `Panel.qml` / `Service.qml` if available.

Live (idle room, not from the agent): Watch → Base Fam Apple TV (`431`) or Office Apple TV (`295`) → cluster appears under the D-pad → Pause visibly pauses → Play resumes → Back still returns to sources. Sony Receiver (`370`) still shows surround rows and **no** transport cluster. Volume and Off stay pinned.

## Completion Ledger

Transport cluster under the Watch D-pad. Stack: QML + `.pragma library` JS (Node `vm` tests). Parser already had `transport.*`; this child opens the gate, exposes flags, and renders two glyph rows. Reuses `sendRemote`.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- `/usr/lib/qt6/bin/qmllint Panel.qml` and `Service.qml` — 0 errors
- Copied `DirectorClient.js` `Service.qml` `Panel.qml` to `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and `omarchy restart shell`

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | WHEN a source declares transport commands THE SYSTEM SHALL show those keys under the D-pad | DONE | `Panel.qml:746-821` two Rows after Down, before surround; keys gated on `remoteSkipRev`/`remotePlay`/… from `caps.transport` |
| 2 | WHEN a source declares none THE SYSTEM SHALL omit the cluster | DONE | Rows `visible: transportMainCount > 0` / `transportScanCount > 0` (`Panel.qml:748,792`). Receiver fixture `!hasTransport` (`tests/director-client.test.js:446`) |
| 3 | THE SYSTEM SHALL NOT require `show_transport` to show or hide a declared key | DONE | UI never reads `showTransport`. Test `show_transport false does not hide declared keys` (`tests/director-client.test.js:456-464`); c4z `showTransport === null` still `hasTransport` |
| 4 | WHEN the user taps a visible key THE SYSTEM SHALL POST that command with empty tParams without blocking | DONE | Each key calls existing `sendRemote` (`Panel.qml:759,768,777,786,803,812,821`); `Service.qml:401-410` empty `{}` tParams, `directorPost(..., function() {})` |
| 5 | IF transport and neither nav nor surround THEN THE SYSTEM SHALL still open the remote | DONE | `DirectorClient.js:568` `hasWatchRemoteUi` includes `hasTransport`; test play-only (`tests/director-client.test.js:454-456`) |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `hasWatchRemoteUi` also true for `hasTransport` | DONE | `DirectorClient.js:565-571` |
| 2 | Tests: play-only open, `show_transport` false, parent dummy `ON`, receiver no transport | DONE | `tests/director-client.test.js:416,446,454-464` |
| 3 | Service transport flags + `_applyRemoteCaps` | DONE | `Service.qml:43-49,370-377`; no new send function |
| 4 | `Panel.qml` two glyph Rows + `listRowCount` | DONE | `Panel.qml:69-70,79-102,746-821`; equal width among visible keys |
| 5 | Halo convention exception names this child | DONE | `.hero/knowledge/conventions/halo-remote-panel-style/spec.md:93` |

### Exercise-the-feature check

- [x] Live plugin copy + `omarchy restart shell`. Parser/gate unit-tested (play-only open, `show_transport` false, receiver has no transport). On-panel Pause/Play was not clicked this turn (no GUI driver; user live).

### Excellence Bar self-check

Yes — compact two-row cluster reuses `sendRemote`, gates on `commands[]` not `show_transport`, and the parent-walk fixture was updated so `PLAY` no longer masquerades as a no-UI dummy.
