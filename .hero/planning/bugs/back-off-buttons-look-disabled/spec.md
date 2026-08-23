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

1. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — add the missing token and say why it exists.
   - `halo.textSecondary` = `#C9C9C9` for de-emphasized but available actions
   - Retarget `halo.danger` from `#9B9B9B` to `#C9C9C9`; Off was already meant to be "muted, not alarm red", which the convention got right — the mistake was reaching for the status/hint grey to express it
   - Record that this is a semantic split, not a contrast fix (measurements below)
2. `Panel.qml` — split `mutedLook` into the two intents it was serving.
   - `haloTextSecondary` palette property, mirroring the convention token
   - `HaloRow.secondary` — label takes `haloTextSecondary`, keeps fill, border, and pointer cursor
   - `HaloRow.heading` — label takes `haloTextMuted` and the row drops fill, border, and pointer cursor (`MouseArea.enabled: false`, `Qt.ArrowCursor`)
3. `Panel.qml` — move the three call sites onto the right intent.
   - Back → `secondary: true`
   - Off → `secondary: true`
   - browse delegate → `heading: !!(modelData && modelData.isHeader)`

## Completion Ledger

| # | Item | Status | Evidence |
|---|---|---|---|
| C1 | Convention gains `halo.textSecondary`, `halo.danger` retargeted | DONE | `halo-remote-panel-style/spec.md:38,41` plus the "Muted is not the same as unavailable" note at `:43-51` |
| C2 | `HaloRow` split into `secondary` / `heading` | DONE | `Panel.qml:78,81` (properties), `:86-90` (fill/border), `:107-109` (label colour), `:116-120` (MouseArea) |
| C3 | Three call sites moved | DONE | `Panel.qml:450` Back, `:545` Off, `:594` browse delegate. `grep mutedLook Panel.qml` returns nothing |
| A1 | Back and Off read as available secondary actions | DONE | Both now `secondary: true` → `#C9C9C9` at 10.29:1, distinct from the `#9B9B9B` status/hint voice |
| A2 | Section headers keep reading as non-interactive | DONE | `heading: true` → no fill, no border, `ArrowCursor`, `MouseArea.enabled: false` |
| A3 | Headers no longer show a pointing-hand cursor | DONE | `Panel.qml:119` `cursorShape: haloRow.heading ? Qt.ArrowCursor : Qt.PointingHandCursor` |
| V1 | `qmllint` clean | DONE | 0 errors on `Panel.qml` |
| V2 | Existing suite still passes | DONE | `node tests/director-client.test.js` → ok |
| V3 | Automated regression test for the colour split | SKIPPED | See "Test coverage" below — no QML test harness exists in this repo and the panel cannot instantiate outside the shell |

### Test coverage

There is no automated test for this fix, and adding one is not currently
possible in this repo. The suite is `node`-driven against `DirectorClient.js`,
which is deliberately harness-free; the defect lives entirely in QML property
bindings. Instantiating `Panel.qml` under `qmltestrunner` needs the `qs.Ui` and
`qs.Commons` modules, which only resolve inside the running Omarchy shell —
`qmllint` already reports them as unresolved imports outside it.

What replaced it: the contrast ratios were computed rather than eyeballed, which
is what turned this from a guess into a diagnosis.

| Colour | On `halo.surface` `#1C1C1C` | Verdict |
|---|---|---|
| `#F2F2F2` primary | 15.22:1 | — |
| `#9B9B9B` old Back/Off | **6.13:1** | passes AA — so this was never a legibility bug |
| `#C9C9C9` new secondary | 10.29:1 | passes AA, clearly separated from the hint voice |

That 6.13:1 is the load-bearing number: it rules out "make it brighter" as the
fix and points at the real cause, which is one token carrying two meanings.

**Visual confirmation: PENDING.** The cold audit flagged that this spec's whole
acceptance is visual, yet nothing recorded anyone having looked. The fix is
deployed and the shell restarted, but as of this writing no human has confirmed
the rendering. That check is the last open item.

**User sign-off (2026-08-23):** David Estes accepted V3 as SKIPPED rather than
building a QML test harness or reshaping the code to be testable. Verification
is manual, per the Validation section.

## Boundaries

- Does not change what Off *does*, nor make it reflect room power state — that is `room-now-playing`
- Does not restyle the panel generally — `halo-panel-chrome` owns the palette
- Does not change the browse navigation model

## Risks

- Making the header rows more distinct risks them reading as tappable, which is the opposite failure.
- The palette is shared with `halo-panel-chrome`; a new token should be added there rather than hardcoded in `Panel.qml`.

## Validation

Open Listen → TuneIn → Browse → a folder with `is_header` rows (Local Radio has FM/AM headers). Back and Off read as available; the FM/AM headers do not, and do not show a pointing-hand cursor. `qmllint` clean.
