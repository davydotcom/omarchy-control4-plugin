---
title: Back and Off buttons look disabled
slug: back-off-buttons-look-disabled
type: bug
status: diagnosed
domain: engineering
size: small
severity: low
priority: medium
horizon: now
created: 2026-08-23
tags: [omarchy, control4, ui, halo]
relates-to:
  - halo-panel-chrome
  - halo-remote-panel-style
  - room-now-playing
---
# Back and Off buttons look disabled

## Issue

Reported by David Estes on 2026-08-23 while testing the TuneIn browse work: the panel's **Back** and **Off** rows read as disabled controls. Both are fully functional. Reported alongside a separate observation — that Off does not reflect room power state — which is tracked in `room-now-playing`, not here.

## Investigation

Both rows are `HaloRow` instances declared with `mutedLook: true` in `Panel.qml`:

- the browse **Back** row in `headerColumn`
- the **Off** row in `footerColumn`

`HaloRow` maps `mutedLook` straight onto the label colour:

```qml
color: haloRow.mutedLook ? root.haloTextMuted : root.haloText
```

`haloTextMuted` is `#9B9B9B` against a `#1C1C1C` surface, while a normal row's `haloText` is `#F2F2F2`. That is the entire mechanism — a greyed label on an otherwise normal row is exactly the convention for a disabled control, so both rows inherit that reading.

The third `mutedLook` user is the TuneIn `is_header` row, where the muted treatment is correct: those rows genuinely are not tappable.

### Root cause

`mutedLook` conflates two different meanings. It is used both for *de-emphasis* (Back and Off are secondary actions, not disabled ones) and for *non-interactive* (TuneIn section headers). One property, one colour, two intents — so the secondary actions render as unavailable.

### Severity

Cosmetic, no functional impact — both rows work when clicked. Low severity, but it undermines confidence in the panel: a user who believes Off is disabled will not try it. Blast radius is the two rows plus any future secondary action that reaches for `mutedLook`.

## Kickoff

Back and Off render greyed and read as disabled. They work — `mutedLook` is doing double duty.

**Status:** diagnosed — root cause found in `Panel.qml`, fix not written.

**Pick up at:** `/deliver back-off-buttons-look-disabled` — split `mutedLook` into de-emphasis vs non-interactive, add the token to the Halo palette rather than hardcoding it.

→ `/deliver back-off-buttons-look-disabled`

**Files:** `Panel.qml`, `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`

**Skip:** making Off reflect room power state (`room-now-playing`); repainting the panel palette (`halo-panel-chrome`); the browse navigation model.

## Goal

Back and Off read as available secondary actions, while genuinely non-interactive rows (TuneIn section headers) keep reading as non-interactive.

## Changes

Will be produced by `/design` or taken directly at fix time. The shape of the fix: split the single `mutedLook` property into the two intents it is currently serving — a de-emphasis treatment for secondary actions and a non-interactive treatment for headers — and give the non-interactive one no hover/pointer affordance, since section headers currently still show a pointing-hand cursor.

## Boundaries

- Does not change what Off *does*, nor make it reflect room power state — that is `room-now-playing`
- Does not restyle the panel generally — `halo-panel-chrome` owns the palette
- Does not change the browse navigation model

## Risks

- Making the header rows more distinct risks them reading as tappable, which is the opposite failure.
- The palette is shared with `halo-panel-chrome`; a new token should be added there rather than hardcoded in `Panel.qml`.

## Validation

Open Listen → TuneIn → Browse → a folder with `is_header` rows (Local Radio has FM/AM headers). Back and Off read as available; the FM/AM headers do not, and do not show a pointing-hand cursor. `qmllint` clean.
