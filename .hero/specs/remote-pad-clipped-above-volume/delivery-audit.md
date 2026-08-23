# Delivery audit — remote-pad-clipped-above-volume

**Audited:** `git diff HEAD -- Panel.qml tests/director-client.test.js .hero/planning/bugs/remote-pad-clipped-above-volume/spec.md` (working tree vs `1a98b21`)
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] AC-1 — bottom transport row draws in full above the volume slider — `Panel.qml:103-109` sizes `listNaturalHeight` from `remotePad.implicitHeight` when the remote is open (row-count fallback if still 0); `Panel.qml:334-338` `fittedContentHeight` has no `Style.space(720)` cap so the card can grow with the pad. `listArea` (`:634-645`) still clips leftover only against screen height. Live copy + `omarchy restart shell` on 2026-08-23 (Watch → Apple TV, rooms list showing).
- [✓] AC-2 — volume and Off stay pinned below the pad — `footerColumn` still `anchors.bottom` (`Panel.qml:575-581`); `listArea` still `anchors.bottom: footerColumn.top` (`:640`). Pinning unchanged by the height-budget change.
- [✓] AC-3 — must not cap `fittedContentHeight` at `Style.space(720)` — cap argument removed (`Panel.qml:334-338`). `rg` finds no `Style.space(720)` in `Panel.qml`. `tests/director-client.test.js:508-509` asserts `fittedContentHeight(...)` is not capped at that value.

## Changes
- [✓] `listNaturalHeight` from `remotePad.implicitHeight` when remote open — `Panel.qml:103-109`
- [✓] Drop `Style.space(720)` cap on `fittedContentHeight` — `Panel.qml:334-338`; screen `availableCardHeight` is now the ceiling
- [✓] Test that `Panel.qml` is not capped at 720 — `tests/director-client.test.js:508-509`

## Open items (if any)

None.

## Audit notes

None.
