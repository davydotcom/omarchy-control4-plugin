---
title: Watch-source virtual remote
slug: watch-source-virtual-remote
type: initiative
status: planning
domain: engineering
size: x-large
horizon: next
created: 2026-08-23
tags: [omarchy, control4, watch, remote, av]
relates-to:
  - control4-focused-room-remote
  - halo-remote-panel-style
child:
  - remote-command-metadata
  - virtual-remote-dpad
  - virtual-remote-transport
  - virtual-remote-numbers
---
# Watch-source virtual remote

## Vision

Picking Watch → Apple TV should hand you that device's remote, not just select it. Control4's own navigators render a device-specific button layout — D-pad, menu, transport, digits — and the Director already publishes enough per-device metadata to reproduce it. This initiative makes the panel render the right buttons for whatever watch source is selected, from Director metadata rather than a hardcoded table of devices.

## Goal

After Watch selects a source, the panel shows a virtual remote whose buttons come from that item's own published command set: navigation for anything with a D-pad, transport where the device declares it, digits where the device declares channel entry. An Apple TV and a cable box get different remotes without the plugin knowing either brand by name. Success is pressing Menu/Up/Down/Left/Right/Enter on the focused room's Apple TV and seeing it respond.

## Kickoff

After Watch → a source, show that device's own remote: D-pad, transport, digits — laid out from Director metadata, not a per-brand table.

**Status:** planning — metadata located and verified live; no children designed yet.

**Pick up at:** `/design remote-command-metadata` — model the button set from `commands[]` + `navigator_display_option`, then design the D-pad child.

→ `/design remote-command-metadata`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`, `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`

**Skip:** per-brand hardcoded layouts; IR/RF learning; the hardware remote's full overlay; keyboard/text entry into the device; anything Listen-side (that is `listen-library-browse`).

## What the Director already publishes (verified live)

This is the load-bearing finding — the metadata is in the `GET /api/v1/items` payload the plugin already fetches, so no new API is needed.

Every proxy item carries a `commands.command[]` array naming exactly what it accepts, and a `capabilities.navigator_display_option` describing how a navigator should render it. Two live watch sources on this Director:

| | `295` Office Apple Tv | `431` Base Fam Apple TV |
|---|---|---|
| proxy | `dvd` (`dvd_Apple_TV_IR.c4i`) | `media_player` (`appleTV.c4z`) |
| commands | 30 | 31 |
| nav D-pad | `MENU UP DOWN LEFT RIGHT ENTER` | same |
| transport | `PLAY STOP PAUSE SKIP_FWD SKIP_REV SCAN_FWD SCAN_REV` | same |
| digits | `NUMBER_0`…`NUMBER_9 STAR POUND DASH` | same |
| power | `ON OFF` | same |
| display option keys | `type, show_transport, display_icon, status_icon` | `proxybindingid, type, translation_url, display_icons` |

`20` Cable DVR (`cable` proxy) instead advertises `capabilities.has_channel_up_down` and `has_discrete_channel_select`, which is what should gate a channel pad rather than the device's name.

Two consequences worth locking now:

- **Presence in `commands[]` is the gate**, not a device allowlist. A source that never lists `UP` gets no D-pad.
- **`navigator_display_option` differs in shape between `.c4i` proxies and `.c4z` drivers** (`display_icon` vs `display_icons`, `show_transport` present only on the former). Children must read it defensively; `show_transport` being absent is not the same as false.

## Specs

Ordered children. `/design` refines each child's internals, not this sequence.

| # | Slug | Status | Size | Horizon | Depends-on | One-liner |
|---|---|---|---|---|---|---|
| 1 | `remote-command-metadata` | planning | small | next | — | Parse `commands[]` + `navigator_display_option` into a button-capability model; no UI. |
| 2 | `virtual-remote-dpad` | planning | medium | next | `remote-command-metadata` | D-pad, Menu, Enter for the selected watch source, Halo-styled. |
| 3 | `virtual-remote-transport` | planning | small | later | `virtual-remote-dpad` | Transport row, shown only where the device declares it. |
| 4 | `virtual-remote-numbers` | planning | small | later | `virtual-remote-dpad` | Digit pad / channel entry for channel-capable sources. |

## Sequenced work items

1. **Command metadata** (`remote-command-metadata`) — pure parser work in `DirectorClient.js`, mirroring how `isAppleMusicItem` / `parseMspTabs` are unit-tested today. Produce a capability object per item id: which nav keys exist, whether transport is declared, whether digits/channel entry apply. No `Panel.qml` change in this child.
2. **D-pad** (`virtual-remote-dpad`) — the core value. Renders after Watch selects a source, sends each press as a command on the *device* item. This child must settle whether presses go to the room or the device item, and whether the panel replaces the source list the way browse does or sits under it.
3. **Transport** (`virtual-remote-transport`) — gated on the metadata, not on the source name.
4. **Digits** (`virtual-remote-numbers`) — gated on `has_channel_up_down` / `has_discrete_channel_select`; primarily the cable box.

## Open questions for `/design`

Named here rather than guessed, per the house rule about not inventing Director fields:

- **Command endpoint and payload.** Listen-side commands post to `/api/v1/items/{id}/commands` with `{async, command, tParams}`. Whether a watch device wants the same shape, and whether it needs `ROOMID`, is **not verified** — one live press must confirm before UI work, the same bar `listen-library-browse` had to clear.
- **Which item to address.** Watch sources come from `ui_configuration` experiences (e.g. `295`), but the type-6 protocol parent (`294`) also exists. Confirm which one accepts nav commands.
- **Icon assets.** `display_icons` points at `controller://driver/...` URLs. Whether those resolve over the Director's HTTP surface is unknown; the first slice should use glyphs and treat driver icons as a later enhancement.

## Boundaries

- No per-brand hardcoded layouts — if metadata does not describe it, it does not render
- No IR learning, no Composer programming, no macro/scene editing
- No text/keyboard entry into the device
- No Listen-side browse work (`listen-library-browse` owns that)
- No now-playing/transport *state* readback — that is `room-now-playing`
- Do not POST unknown driver Actions while probing a live Director

## Risks

- Probing an unverified command endpoint on live AV gear changes what is on the TV. Probe against a room nobody is using.
- `commands[]` lists what the *proxy* accepts, which is not proof the physical device responds — an IR driver with no emitter in range will accept and do nothing.
- The two `navigator_display_option` shapes will tempt a child into handling only the one in front of it.
- A 30-button remote will not fit the panel. Layout is a real design problem, not an afterthought.

## Acceptance Criteria

- WHEN a watch source is selected THE SYSTEM SHALL render only the buttons that source's `commands[]` declares
- WHEN the user presses a navigation button THE SYSTEM SHALL send that command to the Director for the focused room's device
- IF a source declares no navigation commands THE SYSTEM SHALL keep tap-to-select with no empty remote
- THE SYSTEM SHALL NOT identify devices by brand or model name to decide layout

## Validation

One live command POST must visibly move the Apple TV UI before any layout work proceeds. Then: Watch → Apple TV → arrows and Menu drive the on-screen UI in the focused room. Parser coverage in `tests/director-client.test.js` for both `.c4i` and `.c4z` metadata shapes.
