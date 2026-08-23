---
title: Back and Off buttons look disabled
slug: back-off-buttons-look-disabled
type: bug
status: completed
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
completed_at: 2026-08-23T20:19:16Z
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

Back and Off looked disabled because `mutedLook` was also the non-interactive header colour.

**Status:** completed — archived; `HaloRow.secondary` / `heading` split. Broader button restyle is `halo-panel-chrome`.

**Pick up at:** `/design virtual-remote-transport` — play/pause/skip under the D-pad, only where the device declares it.

→ `.hero/specs/back-off-buttons-look-disabled/spec.md`

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

Semantic split of `mutedLook` into `secondary` vs `heading`. Stack: QML
(`HaloRow` in `Panel.qml`) plus the Halo convention tokens. No JS parser
change.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- `/usr/lib/qt6/bin/qmllint Panel.qml` — 0 errors
- User live (2026-08-23): David Estes confirmed Back and Off no longer read as disabled. Broader button restyle is deferred to `halo-panel-chrome`.

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Back and Off read as available secondary actions | DONE | `Panel.qml:483` Back and `:596` Off are `secondary: true`; label uses `haloTextSecondary` `#C9C9C9` (`:40`, `:119-121`); fill/border/pointer kept. User confirmed 2026-08-23 |
| 2 | Section headers keep reading as non-interactive | DONE | `Panel.qml:645` `heading: !!(modelData && modelData.isHeader)`; heading drops fill/border (`:98-102`) and `MouseArea.enabled` (`:138`) |
| 3 | Headers no longer show a pointing-hand cursor | DONE | `Panel.qml:139` `cursorShape: haloRow.heading ? Qt.ArrowCursor : Qt.PointingHandCursor` |
| 4 | Automated QML regression test for the colour split | SKIPPED | [signed-off] No QML harness; suite is Node against `DirectorClient.js`; `qs.Ui`/`qs.Commons` only resolve in the Omarchy shell. User accepted 2026-08-23 |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Convention gains `halo.textSecondary`; `halo.danger` retargeted | DONE | `.hero/knowledge/conventions/halo-remote-panel-style/spec.md:38,41` plus semantic-split note `:43-51` |
| 2 | `HaloRow` split into `secondary` / `heading` | DONE | `Panel.qml:89,92` properties; `:98-102` fill/border; `:119-121` label; `:135-139` MouseArea |
| 3 | Three call sites moved | DONE | Back `:483` `secondary`; Off `:596` `secondary`; browse delegate `:645` `heading`. `mutedLook` gone from `Panel.qml` |

### Exercise-the-feature check

- [x] User (2026-08-23): Back and Off look available, not disabled. Overall button restyle left for `halo-panel-chrome`.

### Excellence Bar self-check

Yes — one property was carrying two intents; the split is a token plus affordance (fill/border/cursor), not a brightness bump. Contrast already passed AA at the old grey.

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

**User sign-off (2026-08-23):** David Estes accepted AC#4 as SKIPPED rather than
building a QML test harness, and confirmed Back and Off now look available.
Broader Halo button restyle is `halo-panel-chrome`, not this spec.

## Boundaries

- Does not change what Off *does*, nor make it reflect room power state — that is `room-now-playing`
- Does not restyle the panel generally — `halo-panel-chrome` owns the palette
- Does not change the browse navigation model

## Risks

- Making the header rows more distinct risks them reading as tappable, which is the opposite failure.
- The palette is shared with `halo-panel-chrome`; a new token should be added there rather than hardcoded in `Panel.qml`.

## Validation

Open Listen → TuneIn → Browse → a folder with `is_header` rows (Local Radio has FM/AM headers). Back and Off read as available; the FM/AM headers do not, and do not show a pointing-hand cursor. `qmllint` clean.
