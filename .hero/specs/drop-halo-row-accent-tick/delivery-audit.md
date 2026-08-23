# Delivery audit — drop-halo-row-accent-tick

**Audited:** `git diff HEAD -- Panel.qml tests/director-client.test.js .hero/knowledge/conventions/halo-remote-panel-style/spec.md .hero/planning/features/halo-panel-chrome/spec.md .hero/planning/features/drop-halo-row-accent-tick/spec.md` (working tree vs `1a98b21`). Spec dir is untracked; `ls -la .hero/planning/features/drop-halo-row-accent-tick/` showed only `spec.md`.
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] AC-1 Selected/pressed `HaloRow` shows `halo.surfaceSelected` and no orange leading edge — `Panel.qml:128-132` fill is `haloSurfaceSelected` when `chosen || lit`, else `haloSurface`. After `border.width`, the next child is `Text` (`:134`), not a 2px `Rectangle`. Workspace grep: `haloAccent` appears only as the token (`:41`) and on the slider (`:603-604`). The other `Rectangle` (`:338`) is the card fill (`haloBg`).
- [✓] AC-2 Volume slider fill and knob stay `halo.accent` — `Panel.qml:603-604` `fillColor: root.haloAccent` / `knobColor: root.haloAccent`. Token `#E87722` at `:41`.
- [✓] AC-3 Convention and `halo-panel-chrome` no longer prescribe a 2px leading edge / accent tick as the selected look — convention Pattern (`halo-remote-panel-style` `:19`) says orange is meter-only; token `halo.accent` (`:39`) is “Volume slider fill and knob only — not a row selection rail”; Watch \| Listen (`:56`) is `surfaceSelected` only, “not an accent tick”; anti-pattern (`:88`) names the 2px `#E87722` rail. `halo-panel-chrome` Approach (`:47`) is “Selected row `#2E2E2E` only — not a full orange button and not a 2px leading edge”; Risks (`:73`) retargets accent to the slider. No remaining prescription of a leading-edge rail as the selected look.

## Changes
- [✓] Remove 2px accent `Rectangle` from `HaloRow` — `Panel.qml:113-148`. `HaloRow` is a `Rectangle` whose selected/pressed look is the fill (`:128-130`). No child `Rectangle` with `width: 2` and `haloAccent`. Slider keeps `haloAccent` at `:603-604`.
- [✓] Convention: accent is slider-only; anti-pattern the rail — `halo-remote-panel-style` token table `:39`, layout #2 `:56`, Press `:61`, anti-pattern `:88`.
- [✓] Amend `halo-panel-chrome` Approach — `:47` drops the 2px leading edge; `:73` slider keeps `#E87722`.
- [✓] Test: no 2px `haloAccent` edge; slider still accent — `tests/director-client.test.js:510-514` (`!/width:\s*2[\s\S]{0,160}haloAccent/` plus `fillColor` / `knobColor` includes). Re-run: `node tests/director-client.test.js` printed `ok`, exit 0.

## Open items (if any)

None.

## Audit notes

None.
