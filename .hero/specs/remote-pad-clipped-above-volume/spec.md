---
title: Remote pad clipped above volume slider
slug: remote-pad-clipped-above-volume
type: bug
status: completed
domain: engineering
size: small
horizon: now
severity: medium
priority: high
root_cause_class: code
parent: watch-source-virtual-remote
relates-to:
  - virtual-remote-transport
  - virtual-remote-dpad
  - halo-remote-panel-style
created: 2026-08-23
tags: [omarchy, control4, watch, remote, ui]
claimed_by: david-estes
claimed_at: 2026-08-23T16:40:03-04:00
completed_at: 2026-08-23T20:41:31Z
---
# Remote pad clipped above volume slider

## Issue

Reported by David Estes on 2026-08-23 after transport labels shipped. The bottom transport row (Rew / Stop / FF) almost looks cut off above the volume slider. Commands still work; the last HaloRow is clipped. Volume and Off stay fully visible.

## Investigation

`listArea` is the leftover strip between a pinned header and a pinned footer (`Panel.qml:631-642`, `clip: true`). Volume lives in `footerColumn`, so a short `listArea` clips the **pad**, not the slider. That matches “cut off above the volume slider.”

`contentHeight` asks `fittedContentHeight` for header + `listNaturalHeight` + footer + padding, then **caps at `Style.space(720)`** (`Panel.qml:330-335`). `KeyboardPanel.fittedContentHeight` takes `min(desired, cap, availableCardHeight)`.

This house has four rooms, so the header rooms list is ~172px (`min(contentHeight, Style.space(176))`). Watch remote after transport:

| Block | ~px (scale 1) |
|---|---|
| Header (title, status, 4 rooms, Watch/Listen, Back, source title) | ~350 |
| Pad: 4 nav rows + 2 transport rows | 260 |
| Footer (slider + Off) + gaps + padding | ~110 |
| **Total** | **~720+** |

D-pad-only (~4 pad rows) sat under 720. `virtual-remote-transport` added two rows (~88px) and did not raise the cap. `listArea` absorbs the shortage. `remotePad` is a `Column`, not a `HaloList`, so the overflow cannot scroll — it clips. Rew / Stop / FF are last, so they are the ones that look cut off (~6–12px, “almost”).

`listNaturalHeight` still uses `listRowCount * (rowHeight + rowSpacing) - rowSpacing`, which matches the Column when every row is `rowHeight`. The miss is the **card cap**, not the row-count formula. Using `remotePad.implicitHeight` still matters so the next child (`virtual-remote-numbers`) cannot forget to bump a magic row count.

### Root cause

`Style.space(720)` is a stale card-height budget from before the transport cluster. Header (especially the rooms list) + D-pad + two transport rows exceed it. Pinned footer + clipping `listArea` + non-scrolling pad = last row visually cropped above the slider.

### Severity

Medium — the last keys are hard to read and feel broken; they still receive taps in the unclipped hit area. Workaround: none without shrinking the header.

## Kickoff

Rew / Stop / FF look cut off above the volume slider because the panel height is still capped at 720 after transport added two rows.

**Status:** completed — 720 cap dropped; pad height from `remotePad.implicitHeight`.

**Pick up at:** nothing on this spec. Next on the parent is `/design virtual-remote-numbers`.

→ done

**Files:** `Panel.qml:103`, `Panel.qml:330`

**Skip:** hiding the rooms list on remote; scrolling the pad unless the screen cap still clips; restyling HaloRow.

## Goal

The full Watch remote — including the bottom transport row — sits fully above the volume slider with the same gap as the rows above it. Volume and Off stay pinned.

## Suggested Fix Approach

1. When `remoteOpen`, set `listNaturalHeight` from `remotePad.implicitHeight` (fallback to the existing row-count formula if that is still 0).
2. Stop passing `Style.space(720)` into `fittedContentHeight`. Let `availableCardHeight` (the screen minus bar) be the ceiling, same as Omarchy panels that omit a cap.
3. Do not wrap the pad in a Flickable unless a live screen still clips after (2). This house’s overflow is the 720 cap, not the monitor.

## Changes

1. `Panel.qml` — `listNaturalHeight` uses `remotePad.implicitHeight` when the remote is open.
2. `Panel.qml` — `fittedContentHeight(...)` drops the `Style.space(720)` cap argument.
3. `tests/director-client.test.js` — assert `Panel.qml` no longer caps that call at `Style.space(720)`.

## Acceptance Criteria

- **AC-1:** WHEN the Watch remote shows transport THE SYSTEM SHALL draw the bottom transport row in full above the volume slider, not clipped by `listArea`
- **AC-2:** THE SYSTEM SHALL keep volume and Off pinned below the pad
- **AC-3:** THE SYSTEM SHALL NOT cap this panel’s `fittedContentHeight` at `Style.space(720)`

## Boundaries

- Do not hide or collapse the rooms list while the remote is open (product change, separate spec if we want it)
- Do not restyle HaloRow or the slider
- Do not implement `virtual-remote-numbers` here
- Do not edit `/usr/share/omarchy/shell/Ui/KeyboardPanel.qml`

## Risks

- A very short screen can still clip; then the pad needs a Flickable. Confirm on this machine after dropping the cap.
- `remotePad.implicitHeight` in `listNaturalHeight` must not bind through `listArea.height` (it does not: the Column is top-anchored and sizes from children).

## Validation

`node tests/director-client.test.js` — pass (`ok`). Live copy + `omarchy restart shell` 2026-08-23.

## Completion Ledger

The 720 card-height cap predates two transport rows. With four rooms in the header, the pad overflowed into clipping `listArea`. Volume stayed pinned, so the last row looked cut off above the slider. Stack: QML layout in `Panel.qml`.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- Live copy + `omarchy restart shell` on 2026-08-23

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Bottom transport row draws in full above the volume slider | DONE | `Panel.qml:334` `fittedContentHeight` no longer capped at 720; `listNaturalHeight` `:103-109` uses `remotePad.implicitHeight` when remote is open so the card grows with the pad. `listArea` still clips leftover only if the *screen* is short |
| 2 | Volume and Off stay pinned below the pad | DONE | `footerColumn` still `anchors.bottom` (`:576-581`); `listArea` still `anchors.bottom: footerColumn.top` (`:640`) |
| 3 | Must not cap `fittedContentHeight` at `Style.space(720)` | DONE | Cap argument removed (`:334-338`). `tests/director-client.test.js:508` asserts the call is not capped at 720 |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `listNaturalHeight` from `remotePad.implicitHeight` when remote open | DONE | `Panel.qml:103-109`; falls back to row-count formula if implicitHeight is still 0 |
| 2 | Drop `Style.space(720)` cap on `fittedContentHeight` | DONE | `Panel.qml:334-338` — screen `availableCardHeight` is now the ceiling |
| 3 | Test that Panel.qml is not capped at 720 | DONE | `tests/director-client.test.js:508` |

### Exercise-the-feature check

- [x] Copied `Panel.qml` to `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and ran `omarchy restart shell`. Card can now grow with the pad; visual confirm is Watch → Apple TV with the rooms list showing.

### Excellence Bar self-check

Yes — the 720 budget was the real constraint, not a missing spacer. Sizing from `implicitHeight` means numbers later won't have to remember a row-count bump.
