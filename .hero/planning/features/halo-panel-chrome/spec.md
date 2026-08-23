---
title: Halo panel chrome
slug: halo-panel-chrome
type: feature
status: delivering
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
---
# Halo panel chrome

## Context

The popup still reads as a stack of Omarchy buttons. The user wants Control4 Halo Remote styling as the design criteria. Convention: `.hero/knowledge/conventions/halo-remote-panel-style/spec.md`. Connected surface is room + Watch/Listen + source list + volume meter + Off.

## Goal

Recolor and regroup `Panel.qml` so the connected popup matches the Halo tokens and layout in that convention. Behavior (focus, select source, slider, Off, gear) stays the same.

## Kickoff

Restyle the Control4 popup to Halo Remote chrome: dark field, room title, Watch/Listen, dense lists, accent slider, Off footer.

**Status:** delivering — `Panel.qml` uses Halo tokens, dense `HaloRow`s, accent slider, Off footer. Live plugin copied; shell restarted. IPC summon did not leave a screenshotable popup.

**Pick up at:** click Deck on the bar and confirm the dark Halo card (room title, Watch/Listen, orange slider, Off). Then `hero spec verify`.

→ `/deliver halo-panel-chrome`

**Files:** `Panel.qml` (maybe a tiny `HaloStyle.js` if tokens clutter QML)

**Skip:** new `.qml` filename if a restart can be avoided; editing first-party Ui; changing Director APIs; bar chip restyle.

## Approach

Apply `halo-remote-panel-style` in `Panel.qml` only:

- Card background `#111111`. All labels/buttons `foreground`/`color` `#F2F2F2`. Selected row `#2E2E2E` plus `#E87722` as a 2px leading edge or slider fill — not a full orange button.
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
- Accent on every selected row will look loud; prefer surfaceSelected + thin accent.

## Acceptance Criteria

- WHILE connected THE SYSTEM SHALL paint the popup with Halo tokens (`#111111` field, `#F2F2F2` text) and SHALL NOT use `barForeground` for that text
- WHEN a room is focused THE SYSTEM SHALL use that room name as the panel title
- THE SYSTEM SHALL show Watch and Listen as two equal segments
- THE SYSTEM SHALL show volume as an accent-filled slider with a numeric level, not `−` / `+` buttons
- THE SYSTEM SHALL keep Off on a footer row separate from the list
- THE SYSTEM SHALL keep gear login, source select, and volume commands unchanged

## Validation

Live copy + `omarchy restart shell`. Screenshot: dark Halo-like card, room title, readable lists, orange-tinted slider, Off at the bottom. Unfocused/login still usable. `node tests/director-client.test.js` still passes (no JS join change required).
