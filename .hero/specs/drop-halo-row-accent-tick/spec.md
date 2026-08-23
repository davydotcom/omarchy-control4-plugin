---
title: Drop orange rail on selected rows
slug: drop-halo-row-accent-tick
type: feature
status: completed
domain: engineering
size: trivial
horizon: now
priority: high
parent: control4-focused-room-remote
relates-to:
  - halo-panel-chrome
  - halo-remote-panel-style
created: 2026-08-23
tags: [omarchy, control4, halo, ui]
claimed_by: david-estes
claimed_at: 2026-08-23T16:44:23-04:00
completed_at: 2026-08-23T20:45:53Z
---
# Drop orange rail on selected rows

## Context

David Estes (2026-08-23) asked where the left orange bar on active `HaloRow`s came from, then: get rid of the orange. Provenance: `halo-remote-panel-style` “accent tick,” made concrete in `halo-panel-chrome` as a 2px `#E87722` leading edge so selected rows would not be full orange buttons. It is not a traced Halo hardware control.

## Goal

Selected and pressed rows use only `halo.surfaceSelected`. No orange on `HaloRow`. Volume slider keeps accent fill.

## Kickoff

Get rid of the orange left bar on selected / pressed buttons. Darker fill is enough.

**Status:** completed — orange rail gone; selected is darker fill only.

**Pick up at:** nothing on this spec. Next on the parent remote is `/design virtual-remote-numbers`.

→ done

**Files:** `Panel.qml:134`, `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`, `.hero/planning/features/halo-panel-chrome/spec.md`

**Skip:** restyling the volume slider; painting labels orange; full `halo-panel-chrome` close-out.

## Approach

Delete the 2px leading `Rectangle` on `HaloRow`. `chosen` / `lit` still flip the row to `#2E2E2E`. Retarget `halo.accent` in the convention to the meter only. Amend `halo-panel-chrome` so a later verify of that spec does not put the rail back.

## Changes

1. `Panel.qml` — remove the 2px left accent `Rectangle` from `HaloRow`. Keep `haloAccent` on `PanelSlider` fill/knob.
2. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — selected = `surfaceSelected` only; anti-pattern the rail; `halo.accent` is slider-only.
3. `.hero/planning/features/halo-panel-chrome/spec.md` — drop “2px leading edge” from Approach.
4. `tests/director-client.test.js` — assert `Panel.qml` has no 2px left edge painted with `haloAccent`.

## Acceptance Criteria

- **AC-1:** WHEN a `HaloRow` is selected or pressed THE SYSTEM SHALL show `halo.surfaceSelected` and SHALL NOT paint an orange leading edge
- **AC-2:** THE SYSTEM SHALL keep volume slider fill and knob as `halo.accent`
- **AC-3:** THE SYSTEM SHALL NOT describe selected rows as using a 2px leading edge or accent tick in the Halo convention or `halo-panel-chrome`

## Boundaries

- Do not finish or re-verify `halo-panel-chrome`
- Do not change slider color
- Do not change `halo.surfaceSelected` itself

## Risks

- Selected Watch/Listen and source rows are subtler without the rail. That is the request.

## Validation

`node tests/director-client.test.js` — pass (`ok`). Live copy + `omarchy restart shell` 2026-08-23.

## Completion Ledger

Removed the invented 2px orange rail. Selected/pressed `HaloRow` is `halo.surfaceSelected` only. Slider keeps `#E87722`.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- Live copy + `omarchy restart shell` on 2026-08-23

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Selected/pressed HaloRow has no orange leading edge | DONE | 2px `Rectangle` gone from `HaloRow` (`Panel.qml` after `:132` is `Text`). Fill still `haloSurfaceSelected` when `chosen \|\| lit` (`:130`) |
| 2 | Volume slider keeps halo.accent | DONE | `Panel.qml:603-604` `fillColor` / `knobColor` still `root.haloAccent` |
| 3 | Convention and halo-panel-chrome no longer prescribe the rail | DONE | Convention token + Watch/Listen + Press updated; anti-pattern names the rail. `halo-panel-chrome` Approach is surfaceSelected only |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Remove 2px accent Rectangle from HaloRow | DONE | `Panel.qml` HaloRow now Text immediately after border |
| 2 | Convention: accent is slider-only; anti-pattern the rail | DONE | `halo-remote-panel-style` token, layout #2, Press, anti-pattern |
| 3 | Amend halo-panel-chrome Approach | DONE | No 2px leading edge; slider keeps `#E87722` |
| 4 | Test: no 2px haloAccent edge; slider still accent | DONE | `tests/director-client.test.js:510-514` |

### Exercise-the-feature check

- [x] Copied `Panel.qml` to the live plugin and ran `omarchy restart shell`. Selected/pressed rows are darker grey only; slider remains orange.

### Excellence Bar self-check

Yes — one invented chrome deleted; the remaining selected state is the fill the convention already had.
