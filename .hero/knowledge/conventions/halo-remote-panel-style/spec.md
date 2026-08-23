---
title: Halo Remote panel style
slug: halo-remote-panel-style
type: convention
status: active
domain: engineering
scope:
  - Panel.qml
  - BarWidget.qml
created: 2026-08-23
tags: [omarchy, control4, halo, ui]
relates-to:
  - control4-focused-room-remote
---
# Halo Remote panel style

## Pattern

The nested details panel is a **Control4 Halo-class remote** for one focused room: near-black field, flat full-width lists, monochrome experience switch, orange on the volume meter only. Selected rows are a darker fill, not an orange rail. It is not an Omarchy settings form and not an SR-260 color-blob clone.

## When to apply

Every visible chrome in `Panel.qml` (and any later QML the user sees in the popup). The **bar chip** stays an Omarchy `WidgetButton` — it must keep bar contrast. Login/gear may look like a settings sheet; once credentials are set, the connected surface must look like Halo.

## How

**Reference.** Halo / Halo Touch (OS 3.3.2+, Halo 2.0 UI refresh): 480-wide dark LCD, Watch / Listen / Now Playing as the three AV doors, dense list navigation, custom actions labeled at the bottom of the screen. Hardware volume stays on the remote; this plugin still needs an on-screen meter because the bar has no rocker.

**Tokens** (do not borrow `barForeground` / wallpaper contrast for popup text):

| Token | Hex | Use |
|---|---|---|
| `halo.bg` | `#111111` | Popup card fill (override `Color.popups.background` on this panel) |
| `halo.surface` | `#1C1C1C` | Idle list row |
| `halo.surfaceSelected` | `#2E2E2E` | Selected row / selected Watch-Listen / **pressed** row |
| `halo.text` | `#F2F2F2` | Primary labels |
| `halo.textMuted` | `#9B9B9B` | Status, hints, and **non-interactive** rows (list section headers) |
| `halo.textSecondary` | `#C9C9C9` | De-emphasized but **available** actions — Back, Off |
| `halo.accent` | `#E87722` | Volume slider fill and knob only — not a row selection rail |
| `halo.border` | `#2A2A2A` | Hairline row/card edge |
| `halo.danger` | `#C9C9C9` | Off — de-emphasized, not alarm red, and not `textMuted` |

**Muted is not the same as unavailable.** `halo.textMuted` and `halo.textSecondary`
both pass AA on `halo.surface` (6.1:1 and 10.3:1), so this is a semantic split,
not a contrast fix. `textMuted` is the status/hint voice; painting a *pressable*
row in it makes it read as disabled even though it is perfectly legible, which is
exactly what went wrong with Back and Off (`back-off-buttons-look-disabled`).
Secondary actions take `textSecondary` and keep their row fill, border, and
pointer cursor. Non-interactive rows take `textMuted` **and** drop the fill,
border, and pointer cursor — the affordance, not just the colour, is what says
"not pressable".

**Layout (top → bottom), one column:**

1. **Room** — focused room name is the title (Halo is room-locked). Plugin name "Control4" is secondary or omitted. Gear stays top-right, small. The muted line under the title is now-playing state (`Off`, `On`, or `Watch · <source>` / `Listen · <source>`), not `Connected`.
2. **Watch | Listen** — two equal segments, icon optional, monochrome. Selected segment uses `halo.surfaceSelected` only, not a loud fill and not an accent tick.
3. **List** — sources (and rooms if more than one). Full-width rows, ~40px, left-aligned name, selected row filled. No Omarchy default button padding as the look.
4. **Meter** — volume as a thin Halo-style bar + numeric level. Accent fill. Right-click mute allowed. Not `−` / `+` pills.
5. **Footer** — Off as a bottom labeled action (Halo custom-button row), separate from the list.

**Press.** A pressable `HaloRow` lights `halo.surfaceSelected` while the pointer is down, and holds that look ~140ms after release so a tap is visible. Headings do not.

**QML.** Keep `qs.Ui` primitives (`Button`, `PanelSlider`, `PanelActionButton`) but **recolor** them with the tokens above. `KeyboardPanel` card `color` must be `halo.bg`. Text and `Button.foreground` must be `halo.text`, never `Color.popups.text` or `barForeground` for this surface.

## Examples

Connected Halo-like stack (names only — implement in `halo-panel-chrome`):

```
Deck                    ⚙
Listen · Apple Music
[ Watch ] [ Listen ]
Amazon Music
Apple Music          ← selected surface
…
32  ────────●──────
Off
```

When the room is off, the muted line is `Off` and the Off row uses `halo.surfaceSelected` (still `textSecondary`, still pressable).

## Anti-patterns

- **`barForeground` / wallpaper-contrast on popup text** — light sky behind the bar made the whole list invisible on the dark card (2026-08-23).
- **Omarchy settings stack as the connected UI** — IP/email/password always on screen. Pairing lives behind the gear.
- **Default `qs.Ui` Button look as the product** — large padded chips, mixed alignment, no selected fill.
- **SR-260 / old Navigator color pages** — Halo 2.0 is flat and mostly mono; color is accent, not wallpaper.
- **Copying Halo hardware onto the panel** — no number pad, RGBY keys, or full hardware overlay. A metadata-gated D-pad after Watch selects a navigation source is `virtual-remote-dpad`, not a clone of the plastic remote.
- **Media-symbol Unicode on transport keys** (`▶` `⏸` `⏭` `⏮` `⏪` `⏩`) — those code points default to color emoji, so they paint orange and ignore `halo.text`. Use short words (Play, Pause, Next) like Menu / Enter (`transport-glyphs-render-emoji`).
- **Orange leading edge / accent tick on `HaloRow`** — invented here as a 2px `#E87722` rail (`halo-panel-chrome`). Selected and pressed rows are `halo.surfaceSelected` only (`drop-halo-row-accent-tick`). Orange stays on the volume slider.

## Exceptions

- Login form (first run / gear / auth-failed) may keep field chrome; still sit on `halo.bg` with `halo.text`.
- Bar chip (`BarWidget.qml`) uses Omarchy bar tokens so it remains readable on the wallpaper. It is the official 4-Ball (`icon.png`) when the focused room is on, the white mark (`icon-off.png`) when off or power is unknown, and the white mark at 0.55 opacity when not connected. Room name and source name live in the tooltip and the panel status line, never as chip text (`room-now-playing`). Keep both PNGs loaded and toggle `visible` — swapping `Image.source` blanks the chip while the other PNG decodes.
- Do not restyle first-party `/usr/share/omarchy/shell/Ui/*.qml`.
- Watch-source D-pad (`virtual-remote-dpad`): Menu / arrows / Enter after a Watch source that declares navigation, using these tokens. Surround/audio rows after a Watch source that declares `surround_modes` are `watch-receiver-audio-options`. A metadata-gated transport cluster (`PLAY` / `PAUSE` / `STOP` / skip / scan from `commands[]`) is `virtual-remote-transport`, not a hardware overlay. Channel up/down and a 0–9 pad (`virtual-remote-numbers`) gate on `has_channel_up_down` / `has_discrete_channel_select`, never on `NUMBER_*` alone.
