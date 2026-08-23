---
title: Virtual remote D-pad
slug: virtual-remote-dpad
type: feature
status: completed
domain: engineering
size: medium
horizon: next
priority: high
parent: watch-source-virtual-remote
depends-on:
  - remote-command-metadata
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
completed_at: 2026-08-23T20:09:43Z
---
# Virtual remote D-pad

## Context

Second child of `watch-source-virtual-remote` and the one that carries the initiative's value. Today Watch → Apple TV posts `SELECT_VIDEO_DEVICE` and stops; there is nothing to press afterwards. Command metadata is completed (`.hero/specs/remote-command-metadata/spec.md`): `parseRemoteCapabilities(item)` and `hasRemoteCommand(caps, name)`. Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

After Watch selects a source that declares navigation, the panel shows a Halo-styled D-pad with Menu and Enter, and pressing a direction moves the device's on-screen UI in the focused room. Done when arrows and Menu drive a real Apple TV.

## Kickoff

D-pad, Menu, Enter for the selected watch source — rendered from metadata, Halo-styled.

**Status:** completed — archived; Apple TV live, parent/child Watch id resolve, Halo press feedback.

**Pick up at:** `/design virtual-remote-transport` — play/pause/skip under the pad, gated on declared transport commands.

→ `.hero/specs/virtual-remote-dpad/spec.md`

**Files:** `Service.qml:386`, `Panel.qml:650`, `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`

**Skip:** transport row (sibling), digits (sibling), driver icon art, per-brand layouts.

## Approach

**View.** Same UX as Listen browse: selecting a Watch source that declares navigation replaces the source list; Back returns to the list. Volume and Off stay pinned. This is a **new** `remoteOpen` flag, not a reuse of `browseOpen` — browse owns MSP rows and a socket.io session; mixing them would load an empty list and kill an in-flight navigator.

**Command target (locked from in-tree evidence, not a new API).**

- Source select already POSTs `SELECT_VIDEO_DEVICE` to **the room** with `{ deviceid }`.
- MSP already POSTs protocol commands to **the device item** (`/api/v1/items/{deviceId}/commands`) with `DirectorClient.commandBody`.
- The live inventory listed `MENU UP DOWN LEFT RIGHT ENTER` on the type-7 proxy the Watch list uses (`295`, `431`), not on a separate parent.

So a nav press POSTs to `/api/v1/items/{selectedSourceId}/commands` with `{ async: true, command: "UP", tParams: {} }` via existing `directorPost`. Do **not** send `ROOMID` (that is an MSP navigator field). Do **not** address the type-6 parent (`294`) unless a live press on the proxy is a documented no-op — then one retry on `item.parentId` if that field exists, not a spray.

Fire-and-forget: `directorPost(..., function() {})`. Do not wait on the HTTP body before accepting the next tap.

**When to open.** In `selectSource`, after the select POST:

- Watch + `parseRemoteCapabilities(_itemById(id)).hasNavigation` → `closeBrowse()`, `openWatchRemote(id)`
- Listen + MSP → existing browse path, `closeRemote()`
- Otherwise → `closeBrowse()`, `closeRemote()`, stay on the source list (tap-to-select, no empty pad)

`setFocusedRoom` / `setSourceMode` already clear browse; they also `closeRemote()`. Back on the remote calls `closeRemote()` and leaves `selectedSourceId` set so the source row stays chosen.

**Pad.** Fixed-size block in `listArea` (not a `HaloList`). Tokens from `halo-remote-panel-style`. Glyphs, not driver icons. Render only the keys `nav.*` is true for. Typical Apple TV (all six):

```
[ Menu ]
[  ↑   ]
[ ← | Enter | → ]
[  ↓   ]
```

Row height stays `Style.space(40)`. Center column of the middle row is Enter. Buttons use `HaloRow` (fill, border, pointer, `haloText`) — they are primary actions, not `secondary` / `heading`.

**Convention.** The Halo style spec currently forbids an on-screen D-pad as a v1 anti-pattern for `halo-panel-chrome`. This child is the intentional exception: a metadata-gated pad after Watch select. Update that anti-pattern so the next session does not "fix" the pad away.

**Live press.** Outward-facing. Do not probe the house Director from the agent. Exercise is Watch → a known Apple TV (Office `295` or Base Fam `431`) in a room nobody is using, then one Up. Great Room is a known room but is **not** in the live Apple TV inventory.

## Changes

1. `Service.qml` — `remoteOpen`, `remoteTitle`, per-key booleans (or one replaced `remoteCaps` object), `openWatchRemote(id)`, `closeRemote()`, `sendRemote(command)`. `selectSource` opens the remote for Watch sources with `hasNavigation`. `setFocusedRoom` / `setSourceMode` / disconnect close it. `sendRemote` no-ops unless connected, `remoteOpen`, and `hasRemoteCommand`.
2. `Panel.qml` — Back visible when `browseOpen || remoteOpen`; Back on remote calls `closeRemote()`. `listArea` shows a fixed D-pad when `remoteOpen` instead of the source/browse lists. `listNaturalHeight` accounts for the pad so volume/Off stay pinned. Only declared nav keys render.
3. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — replace the v1 "no on-screen d-pad" anti-pattern with: full hardware overlay stays out of scope; a metadata-gated Watch D-pad is `virtual-remote-dpad`.
4. `tests/director-client.test.js` — no new parser required unless a helper is extracted; existing dvd/c4z `hasNavigation` coverage still passes.

## Boundaries

- Navigation only — no transport, no digits, no power
- No driver icon assets; glyphs are fine for this slice
- No key-repeat / press-and-hold in the first slice unless the device needs it
- No now-playing readback
- Sources declaring no navigation stay tap-to-select
- No live Director POST from the agent
- Do not overload `browseOpen` / `browseRows` for the pad

## Risks

- Probing command shapes on live AV changes what is on someone's TV. Exercise in an idle room.
- An IR driver accepts every command and may do nothing if no emitter in range — a silent no-op reads as a plugin bug. Office `295` is `dvd_Apple_TV_IR.c4i`; Base Fam `431` is `appleTV.c4z` (IP). Prefer `431` for the first live press if that room is idle.
- Fitting a D-pad into a 320-wide panel without it looking like an afterthought.
- Latency: fire-and-forget, do not block on the response.
- Mixing this work into the uncommitted `Panel.qml` Back/Off `secondary` split — keep that split; do not revert it.

## Acceptance Criteria

- **AC-1:** WHEN a watch source declaring navigation is selected THE SYSTEM SHALL show a D-pad with Menu and Enter
- **AC-2:** WHEN the user presses a direction THE SYSTEM SHALL send that command for the focused room without blocking the UI
- **AC-3:** WHEN the user presses Back THE SYSTEM SHALL return to the watch source list
- **AC-4:** IF the selected source declares no navigation commands THEN THE SYSTEM SHALL show no remote
- **AC-5:** THE SYSTEM SHALL POST each nav command to `/api/v1/items/{selectedSourceId}/commands` with the existing `commandBody` shape and empty `tParams`

## Validation

`node tests/director-client.test.js` still passes. `qmllint` on `Panel.qml` / `Service.qml` if available.

Live (idle room, not from the agent): Watch → Base Fam Apple TV (`431`) or Office Apple TV (`295`) → pad appears → Up moves the on-screen UI → Back returns to the source list → volume and Off stay reachable.

## Completion Ledger

D-pad after Watch select. Stack: QML + `.pragma library` JS (Node `vm` tests).

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- User live: Apple TV D-pad appears and drives the device (session). `itemForWatchRemote` parent/child walk after Great Room source id was not the nav proxy.
- User live (2026-08-23): Watch remote chrome still looks right after surround rows shipped on the same pad surface.

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | WHEN a watch source declaring navigation is selected THE SYSTEM SHALL show a D-pad with Menu and Enter | DONE | `Panel.qml:650-717` Menu / ↑ / ← Enter → / ↓ gated on `remoteMenu` etc.; `Service.qml:373-384` `openWatchRemote`; user confirmed Apple TV pad |
| 2 | WHEN the user presses a direction THE SYSTEM SHALL send that command without blocking the UI | DONE | `Service.qml:386-395` `sendRemote` fire-and-forget `directorPost(..., function() {})`; HaloRow `lit` press feedback; user confirmed Apple TV responds |
| 3 | WHEN the user presses Back THE SYSTEM SHALL return to the watch source list | DONE | `Panel.qml:477-491` Back when `remoteOpen` calls `closeRemote()`; source list `visible: !remoteOpen` |
| 4 | IF the selected source declares no navigation commands THEN THE SYSTEM SHALL show no remote | DONE | D-pad rows hidden when nav flags false. Later `watch-receiver-audio-options` may still open the remote for `surround_modes` without showing an empty pad. Cable-without-nav stays tap-to-select (`hasWatchRemoteUi` false) |
| 5 | THE SYSTEM SHALL POST each nav command to `/api/v1/items/{id}/commands` with `commandBody` and empty `tParams` | DONE | `Service.qml:395` empty `{}` tParams. Id is `remoteDeviceId` from `itemForWatchRemote` (the nav proxy, which may be child/parent of the Watch source id) |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `Service.qml` remoteOpen / openWatchRemote / sendRemote / selectSource | DONE | `Service.qml:34-42,264-270,366-395`; room/mode/disconnect close the remote |
| 2 | `Panel.qml` Back + listArea D-pad + listNaturalHeight | DONE | `Panel.qml:60-71,477-491,650-717`; only declared nav keys `visible` |
| 3 | Halo convention: metadata-gated D-pad is this child | DONE | `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` anti-pattern + Exceptions |
| 4 | `tests/director-client.test.js` still pass; helpers if extracted | DONE | dvd/c4z `hasNavigation`; `itemForWatchRemote` parent/child tests |

### Exercise-the-feature check

- [x] User: Watch → Apple TV shows the D-pad and arrows/Menu drive the device. Back returns to sources. Same remote surface later showed surround rows on the Sony Receiver ("they look great").

### Excellence Bar self-check

Yes — pad is metadata-gated Halo rows, POSTs to the resolved device item with empty tParams, and parent/child lookup was required for Great Room Watch ids. Transport/digits stayed out.

