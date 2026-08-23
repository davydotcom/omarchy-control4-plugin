# Delivery audit — back-off-buttons-look-disabled

**Audited:** `git diff HEAD -- Panel.qml .hero/knowledge/conventions/halo-remote-panel-style/spec.md` (uncommitted working tree; spec slice already present in HEAD)
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria

- [✓] Back and Off read as available secondary actions — `Panel.qml:483` Back and `:596` Off are `secondary: true`. Label binding `:119-121` uses `haloTextSecondary` `#C9C9C9` (`:40`). Fill (`:98-100`), border (`:101-102`), and `PointingHandCursor` (`:139`) stay on because they gate on `heading`, not `secondary`. User confirmed 2026-08-23.
- [✓] Section headers keep reading as non-interactive — `Panel.qml:645` `heading: !!(modelData && modelData.isHeader)`. Heading sets fill/border transparent (`:98-102`), label `haloTextMuted` (`:119-120`), `MouseArea.enabled: false` (`:138`). `DirectorClient.js:872` emits `isHeader` from `is_header`; `tests/director-client.test.js:345` already asserts headers survive parsing.
- [✓] Headers no longer show a pointing-hand cursor — `Panel.qml:139` `cursorShape: haloRow.heading ? Qt.ArrowCursor : Qt.PointingHandCursor`.
- [~] Automated QML regression test for the colour split — SKIPPED, see Open items.

## Changes

- [✓] Convention gains `halo.textSecondary`; `halo.danger` retargeted — `.hero/knowledge/conventions/halo-remote-panel-style/spec.md:38` `halo.textSecondary` `#C9C9C9`; `:41` `halo.danger` `#C9C9C9` (not `textMuted`); `:43-51` records the semantic split. Present in HEAD and the working tree.
- [✓] `HaloRow` split into `secondary` / `heading` — `Panel.qml:89` `secondary`, `:92` `heading`; fill/border `:98-102`; label `:119-121`; MouseArea `:135-139`. `haloTextSecondary` palette property at `:40`.
- [✓] Three call sites moved — Back `:483` `secondary`; Off `:596` `secondary`; browse delegate `:645` `heading`. `mutedLook` is gone from `Panel.qml` (only remains as diagnosis text in this spec / QUEUE). Other `HaloRow` sites set neither flag.

## Open items

- **AC#4 — automated QML regression test for the colour split** — SKIPPED — `[signed-off]` — no QML harness; suite is Node against `DirectorClient.js`; `qs.Ui` / `qs.Commons` only resolve in the Omarchy shell. **Assessment: concrete.** `tests/` contains only `director-client.test.js`. Re-run `qmllint` reports those imports unresolved. User accepted 2026-08-23.

## Audit notes

- No DONE row was downgraded. Ledger line citations match the working tree.
- The uncommitted diff is mostly sibling Watch-remote / press-feedback work in the same two files. This audit scored only the `secondary` / `heading` split and the convention token change, per the invocation. That sibling work did not undo the split: Back and Off remain `secondary: true`; browse headers remain `heading`.
- Remaining `haloTextMuted` uses (`Panel.qml:364, 425, 524, 535, 564`) are non-interactive `Text` (status, hints, volume). The heading label is the only pressable-adjacent use, and that row is not pressable.
