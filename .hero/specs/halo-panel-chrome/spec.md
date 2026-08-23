---
title: Halo panel chrome
slug: halo-panel-chrome
type: feature
status: completed
domain: engineering
size: small
horizon: now
parent: control4-focused-room-remote
depends-on:
  - focused-room
  - watch-and-listen
  - room-volume-mute-off
created: 2026-08-23
tags: [omarchy, control4, halo, ui]
relates-to:
  - halo-remote-panel-style
completed_at: 2026-08-23T20:56:20Z
---
# Halo panel chrome

## Context

The popup still reads as a stack of Omarchy buttons. The user wants Control4 Halo Remote styling as the design criteria. Convention: `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`. Connected surface is room + Watch/Listen + source list + volume meter + Off.

## Goal

Recolor and regroup `Panel.qml` so the connected popup matches the Halo tokens and layout in that convention. Behavior (focus, select source, slider, Off, gear) stays the same.

## Kickoff

Restyle the Control4 popup to Halo Remote chrome: dark field, room title, Watch/Listen, dense lists, accent slider, Off footer.

**Status:** delivering — Halo tokens, HaloRows, accent slider, Off footer live. Orange rail later removed (`drop-halo-row-accent-tick`). Close the gate.

**Pick up at:** `hero spec verify halo-panel-chrome --skip-tests`

→ `/deliver halo-panel-chrome`

**Files:** `Panel.qml` (maybe a tiny `HaloStyle.js` if tokens clutter QML)

**Skip:** new `.qml` filename if a restart can be avoided; editing first-party Ui; changing Director APIs; bar chip restyle.

## Approach

Apply `halo-remote-panel-style` in `Panel.qml` only:

- Card background `#111111`. All labels/buttons `foreground`/`color` `#F2F2F2`. Selected row `#2E2E2E` only — not a full orange button and not a 2px leading edge (`drop-halo-row-accent-tick`). `#E87722` is slider fill/knob only.
- Title text = `focusedRoomName` or `Control4` when unfocused. Status = `sessionStatus` in `#9B9B9B`.
- Watch | Listen two equal bordered segments.
- Room list only if `rooms.length > 1` (single-room houses skip it, Halo is already locked).
- Volume: keep `PanelSlider`, fill/knob accent, numeric in muted text.
- Off footer, full width, muted — not red.
- Keep `Flickable`. Keep gear. Keep login-behind-gear.

No new HTTP. No new filenames unless unavoidable (`qml-new-file-shell-restart`).

## Changes

1. `Panel.qml` — token colors, header, list density, slider accent, Off footer.
2. Optional `HaloStyle.js` `.pragma library` with the hex tokens if `Panel.qml` gets noisy.
3. Live copy + `omarchy restart shell`.

## Boundaries

- Do not restyle `BarWidget.qml` chip beyond current elide
- Do not add d-pad / keypad / RGBY
- Do not change Watch/Listen or volume commands
- Do not edit `/usr/share/omarchy/shell/Ui/`

## Risks

- `qs.Ui` Button selected fill may ignore a custom surface color — if so, wrap rows in a `Rectangle` instead of fighting Button internals.
- Accent on every selected row will look loud; selected is `surfaceSelected` only. Slider keeps accent.

## Acceptance Criteria

- WHILE connected THE SYSTEM SHALL paint the popup with Halo tokens (`#111111` field, `#F2F2F2` text) and SHALL NOT use `barForeground` for that text
- WHEN a room is focused THE SYSTEM SHALL use that room name as the panel title
- THE SYSTEM SHALL show Watch and Listen as two equal segments
- THE SYSTEM SHALL show volume as an accent-filled slider with a numeric level, not `−` / `+` buttons
- THE SYSTEM SHALL keep Off on a footer row separate from the list
- THE SYSTEM SHALL keep gear login, source select, and volume commands unchanged

## Validation

Live copy + `omarchy restart shell`. Screenshot: dark Halo-like card, room title, readable lists, orange-tinted slider, Off at the bottom. Unfocused/login still usable. `node tests/director-client.test.js` still passes (no JS join change required).

## Completion Ledger

Connected popup uses Halo tokens and HaloRow lists. Slider accent only. No orange selection rail (later `drop-halo-row-accent-tick`).

**Validation**
- User 2026-08-23 used the dark card all session (room title, Watch/Listen, slider, Off)
- `node tests/director-client.test.js` still passes

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Connected popup Halo tokens, not barForeground | DONE | `haloBg #111111` `haloText #F2F2F2` (`Panel.qml:35,38`); card `color: root.haloBg` (`:350`); no `barForeground` on this surface |
| 2 | Focused room name is panel title | DONE | `panelTitle` (`:44-46`) |
| 3 | Watch and Listen two equal segments | DONE | `modeRow` two HaloRows half width (`:487-508`) |
| 4 | Volume is accent slider + numeric, not −/+ | DONE | `PanelSlider` fill/knob `haloAccent` (`:603-614`); label (`:592-596`) |
| 5 | Off footer separate from the list | DONE | `footerColumn` (`:577-631`); list in `listArea` above |
| 6 | Gear, source select, volume commands unchanged | DONE | gear still toggles login; `selectSource` / `setVolume` / `roomOff` same Service API |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Panel.qml tokens, header, density, slider, Off | DONE | Halo tokens `:35-42`; HaloRow `:113`; footer `:577` |
| 2 | Optional HaloStyle.js | SKIPPED | [signed-off] Tokens stayed in Panel.qml; no extra .pragma library needed |
| 3 | Live copy + restart | DONE | Live plugin has been this Panel.qml all session |

### Exercise-the-feature check

- [x] User 2026-08-23: dark Halo card, room title, Watch/Listen, orange slider, Off. Later dropped the orange row rail on request.

### Excellence Bar self-check

Yes — tokens in one place, rows not Omarchy chips, orange reserved for the meter.
