---
title: Transport play pause next look orange
slug: transport-glyphs-render-emoji
type: bug
status: completed
domain: engineering
size: trivial
horizon: now
severity: low
priority: medium
root_cause_class: code
parent: watch-source-virtual-remote
relates-to:
  - virtual-remote-transport
  - halo-remote-panel-style
created: 2026-08-23
tags: [omarchy, control4, watch, remote, ui]
claimed_by: david-estes
claimed_at: 2026-08-23T16:35:28-04:00
completed_at: 2026-08-23T20:37:20Z
---
# Transport play pause next look orange

## Issue

Reported by David Estes on 2026-08-23 after `virtual-remote-transport` shipped. Play, pause, and next work, but the buttons look orange and do not match the Halo remote (Menu / arrows / Enter are monochrome `haloText`).

## Investigation

`Panel.qml` transport rows use media-symbol Unicode:

| Key | Label | Code point |
|---|---|---|
| SKIP_REV | ⏮ | U+23EE |
| PLAY | ▶ | U+25B6 |
| PAUSE | ⏸ | U+23F8 |
| SKIP_FWD | ⏭ | U+23ED |
| SCAN_REV | ⏪ | U+23EA |
| STOP | ■ | U+25A0 |
| SCAN_FWD | ⏩ | U+23E9 |

Those media symbols default to **emoji presentation**. The Omarchy shell font stack includes a color-emoji font, so Qt draws an orange (or multi-color) pictograph and **ignores** `HaloRow`'s `haloText` `#F2F2F2`. D-pad arrows (`↑ ← → ↓`, U+2191…) stay text presentation, which is why only the transport cluster looks wrong. Stop (`■`) is a geometric square and usually stays text — the report named play / pause / next.

`virtual-remote-transport` already allowed an ASCII fallback if glyphs failed. They did not fail to render; they rendered as the wrong *kind* of glyph.

### Root cause

Transport labels used emoji-default code points. Color emoji does not take `halo.text`.

### Severity

Low — controls work. Cosmetic, but it breaks the Halo mono rule the rest of the pad follows.

## Kickoff

Play / pause / next look orange because they are color emoji, not Halo text.

**Status:** completed — word labels shipped; live plugin updated.

**Pick up at:** nothing on this spec. Next on the parent is `/design virtual-remote-numbers`.

→ done

**Files:** `Panel.qml:759`, `tests/director-client.test.js`, `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`

**Skip:** restyling HaloRow; driver icons; combining play/pause.

## Goal

Transport keys read as the same monochrome Halo text as Menu / Enter. Taps still send the same commands.

## Suggested Fix Approach

Replace emoji labels with short words (fits the ~80px slot, matches Menu / Enter):

| Command | Label |
|---|---|
| SKIP_REV | Prev |
| PLAY | Play |
| PAUSE | Pause |
| SKIP_FWD | Next |
| SCAN_REV | Rew |
| STOP | Stop |
| SCAN_FWD | FF |

Do **not** keep the media symbols with U+FE0E — Noto Color Emoji often still wins in Qt. Do not use ASCII `>` / `||` as the primary look; words match the pad.

Add a convention anti-pattern: media-symbol Unicode on this panel becomes color emoji and must not be used for transport.

## Changes

1. `Panel.qml` — seven transport `HaloRow.label` values as in the table above.
2. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — anti-pattern for media-symbol emoji.

## Acceptance Criteria

- **AC-1:** WHEN the Watch remote shows transport THE SYSTEM SHALL label those keys with monochrome text that uses `haloText`, not color-emoji code points
- **AC-2:** THE SYSTEM SHALL still send `PLAY` / `PAUSE` / `SKIP_FWD` / `SKIP_REV` / `STOP` / `SCAN_FWD` / `SCAN_REV` on tap
- **AC-3:** THE SYSTEM SHALL NOT use `▶` `⏸` `⏭` `⏮` `⏪` `⏩` as visible labels

## Boundaries

- No HaloRow chrome change
- No combined play/pause
- No driver icon art

## Risks

- "Rew" / "FF" are terse; they match the compact row. Words can wrap/elide — `ElideRight` already exists.

## Validation

`node tests/director-client.test.js` — pass (`ok`). `/usr/lib/qt6/bin/qmllint Panel.qml` — 0 errors (usual unresolved `qs.*` imports). Live: `Panel.qml` copied to `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and `omarchy restart shell`.

## Completion Ledger

Transport labels were color-emoji media symbols, so they painted orange and ignored `haloText`. Replaced with short words that match Menu / Enter. Stack: QML labels in `Panel.qml` plus a Node regression that reads that file.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- `/usr/lib/qt6/bin/qmllint Panel.qml` — 0 errors
- Live copy + `omarchy restart shell` on 2026-08-23

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Transport keys use monochrome `haloText`, not color emoji | DONE | `Panel.qml:759-823` labels are Prev / Play / Pause / Next / Rew / Stop / FF; HaloRow text still `haloText` `#F2F2F2` (`:147`) |
| 2 | Taps still send PLAY / PAUSE / SKIP_* / STOP / SCAN_* | DONE | `onTapped` handlers unchanged: PLAY `:770`, PAUSE `:779`, SKIP_FWD `:788`, SKIP_REV `:761`, STOP `:814`, SCAN_FWD `:823`, SCAN_REV `:805` |
| 3 | No ▶ ⏸ ⏭ ⏮ ⏪ ⏩ as visible labels | DONE | `tests/director-client.test.js` asserts those code points are absent from `Panel.qml` and that Play / Pause / Next word labels exist |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `Panel.qml` seven transport `HaloRow.label` values | DONE | `:759` Prev, `:768` Play, `:777` Pause, `:786` Next, `:803` Rew, `:812` Stop, `:821` FF |
| 2 | Convention anti-pattern for media-symbol emoji | DONE | `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` anti-pattern names the six code points and points at this spec |

### Exercise-the-feature check

- [x] Copied `Panel.qml` to `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and ran `omarchy restart shell`. Commands unchanged; labels are now words that take `haloText`. Visual confirm is the user's next look at Watch → Apple TV transport.

### Excellence Bar self-check

Yes — the orange was the glyph, not the row fill. Words match Menu / Enter and cannot be hijacked by a color-emoji font.
