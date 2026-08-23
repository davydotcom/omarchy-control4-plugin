# Delivery audit — halo-panel-chrome

**Audited:** `git diff HEAD -- Panel.qml` (working tree vs `1a98b21`). Halo tokens / `HaloRow` / `modeRow` / footer slider+Off already in HEAD since `54f0cae`; working tree matches the amended Approach (no 2px orange rail). `ls HaloStyle.js` — file absent.
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria
- [✓] Connected popup Halo tokens, not `barForeground` — `Panel.qml:35` `haloBg "#111111"`; `:38` `haloText "#F2F2F2"`; card `color: root.haloBg` (`:350`); `panelFg` aliases `haloText` (`:43`). Workspace grep: no `barForeground` in `Panel.qml`. Selected fill is `haloSurfaceSelected` (`:140`), not a full orange button.
- [✓] Focused room name is panel title — `panelTitle` (`:44-46`) uses `session.focusedRoomName` when focused, else `"Control4"`. Title `Text` binds `root.panelTitle` (`:371`).
- [✓] Watch and Listen two equal segments — `modeRow` (`:487-508`); each `HaloRow` is `(modeRow.width - modeRow.spacing) / 2`.
- [✓] Volume is accent slider + numeric, not −/+ — `PanelSlider` (`:603-623`) `fillColor` / `knobColor` `root.haloAccent` (`:613-614`); numeric `volumeLabel` (`:592-596`). No −/+ volume buttons.
- [✓] Off footer separate from the list — `footerColumn` pinned bottom (`:577-631`); Off `HaloRow` (`:626-630`) `secondary: true`; sources live in `listArea` above (`:636-642`).
- [✓] Gear, source select, and volume commands unchanged — gear toggles `settingsOpen` (`:379-390`); `selectSource` (`:663`); `setVolume` (`:620`); `roomOff` (`:630`). `Service.qml` still exposes `setSourceMode` / `selectSource` / `setVolume` / `roomOff`.

## Changes
- [✓] `Panel.qml` tokens, header, density, slider, Off — tokens `:35-42`; `HaloRow` `:123`; header `:352+`; `rowHeight` 40 (`:54`); footer `:577`.
- [~] Optional `HaloStyle.js` — SKIPPED, see Open items.
- [✓] Live copy + restart — ledger + invocation: user used the Halo card live 2026-08-23 (room title, Watch/Listen, slider, Off).

## Open items
- **Changes #2 — Optional HaloStyle.js** — SKIPPED — `[signed-off]` — tokens stayed in `Panel.qml`; no extra `.pragma library`. **Assessment: concrete.** File does not exist. Spec named it only if tokens cluttered QML.

## Audit notes
- No DONE row downgraded. Ledger `HaloRow` cite `:113` is stale (component is `:123`); tokens / `modeRow` / footer cites match.
- Amended Approach (no 2px orange rail, `drop-halo-row-accent-tick`) holds on disk: after `HaloRow` `border.width` the next child is `Text` (`:144`). `haloAccent` appears only as the token (`:41`) and slider fill/knob (`:613-614`). `tests/director-client.test.js:516-520` asserts the same.
- Uncommitted `Panel.qml` also has later Watch-remote / press-`lit` work. This audit scored only the chrome slice. That sibling work did not undo tokens, title, `modeRow`, slider, Off, or gear/command wiring.
