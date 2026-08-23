# Delivery audit — back-off-buttons-look-disabled

**Audited:** `git diff HEAD -- Panel.qml .hero/knowledge/conventions/halo-remote-panel-style/spec.md` (uncommitted working tree)
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria

- [✓] **A1 — Back and Off read as available secondary actions** — `Panel.qml:450` (Back), `:545` (Off) both `secondary: true`; binding at `:107-109` resolves `secondary` → `haloTextSecondary` (`#C9C9C9`, declared `:39`). Rows keep fill (`:86-88`), border (`:89-90`), and `PointingHandCursor` (`:119`) because all three are gated on `heading`, not `secondary`. Contrast recomputed independently: `#C9C9C9` on `#1C1C1C` = 10.30:1, `#9B9B9B` = 6.13:1, `#F2F2F2` = 15.22:1 — all three ledger figures correct.
- [✓] **A2 — Section headers keep reading as non-interactive** — `Panel.qml:594` `heading: !!(modelData && modelData.isHeader)`. Data path verified end to end: `DirectorClient.js:647` emits `isHeader` from `is_header`, and `tests/director-client.test.js:325-329` already asserts it survives parsing. `heading` drops fill to `"transparent"` (`:86-87`), border to `transparent`/`0` (`:89-90`), sets `haloTextMuted` (`:108`), and `MouseArea.enabled: false` (`:118`). `Service.qml:421` already returned early on `isHeader`, so headers were functionally inert before — the fix supplies the missing *affordance*, which matches the diagnosis.
- [✓] **A3 — Headers no longer show a pointing-hand cursor** — `Panel.qml:119`: `cursorShape: haloRow.heading ? Qt.ArrowCursor : Qt.PointingHandCursor`. (Ledger cites `:127`; see Audit notes.)

## Changes

- [✓] **1. Convention gains `halo.textSecondary`, `halo.danger` retargeted** — `halo-remote-panel-style/spec.md:38` adds `halo.textSecondary` = `#C9C9C9`; `:41` retargets `halo.danger` `#9B9B9B` → `#C9C9C9`; `:37` re-scopes `halo.textMuted` to status/hints/non-interactive rows. The "Muted is not the same as unavailable" rationale is at `:43-51` and states the semantic-split-not-contrast-fix framing the spec asked for. All four ledger line citations exact.
- [✓] **2. `HaloRow` split into `secondary` / `heading`** — `Panel.qml:78` and `:81`, each with a comment naming the intent. `haloTextSecondary` palette property added at `:39` alongside the existing tokens, not hardcoded at the call site (satisfies the spec's stated Risk).
- [✓] **3. Three call sites moved** — exactly three, no more: `:450` Back → `secondary`, `:545` Off → `secondary`, `:594` browse delegate → `heading`. `grep -n "mutedLook" Panel.qml` returns nothing (exit 1) — independently re-run and confirmed. The other four `HaloRow` instantiations (`:409` rooms delegate, `:428`/`:436` Watch/Listen, `:571` sources delegate) correctly set neither flag.

## Verification

- [✓] **V1 — `qmllint` clean** — `/usr/lib/qt6/bin/qmllint Panel.qml` re-run: exit 0, `grep -c "^Error:"` = 0. Claim holds as stated ("0 errors"). Warning count went 96 → 97; see Audit notes.
- [✓] **V2 — Existing suite passes** — `node tests/director-client.test.js` re-run: prints `ok`, exit 0.
- [~] **V3 — Automated regression test** — SKIPPED, concrete reason, see Open items.

## Open items

- **V3 — automated regression test for the colour split** — SKIPPED. Engineer's reason: the repo's only suite is node-driven against `DirectorClient.js`; the defect lives in QML property bindings; `Panel.qml` cannot instantiate outside the Omarchy shell because `qs.Ui`/`qs.Commons` do not resolve. **Assessment: concrete, and independently verified.** `ls tests/` shows exactly one file (`director-client.test.js`); there is no `package.json`, no `tst_*`, no qmltestrunner config anywhere in the repo. The re-run `qmllint` output confirms the stated obstacle verbatim: `Failed to import qs.Commons` and `Failed to import qs.Ui`. Building a QML harness for a three-line colour-binding change is disproportionate, and the user signed off on 2026-08-23. This is a legitimate SKIP, not a soft one.

## Audit notes

- **Two ledger line citations are wrong.** Row C2 cites `Panel.qml:126-128` for the MouseArea; row A3 cites `Panel.qml:127` for `cursorShape`. The actual MouseArea block is `:116-120`, with `enabled:` at `:118` and `cursorShape:` at `:119` — off by 8-10 lines. The underlying claims are true and the code is present; only the pointers are stale. Every other citation in the ledger (C1's `:38,41,43-51`; C2's `:78,81,86-90,107-109`; C3's `:450,545,594`) is exact. Not a downgrade — the evidence holds when you open the file — but the ledger should be corrected before it becomes the durable record.
- **No downgrades. No performative DONE rows.** Every DONE row's evidence was located in the working tree.
- **`qmllint` warnings went 96 → 97.** The net-new warning is in the pre-existing `unqualified` class (`root.*` accessed from inside the `HaloRow` inline component, which wants `pragma ComponentBehavior: Bound`). It exists because the label-colour ternary grew from two `root.` references to three. Same category as the 96 already there, no new class of problem, and V1 claimed zero *errors*, not zero warnings — so the claim is honest. Flagged only so nobody reads the delta as a regression.
- **No remaining conflation of de-emphasis with non-interactive.** All five surviving `haloTextMuted` uses (`Panel.qml:331, 392, 473, 484, 513`) are plain `Text` elements — panel status, rooms hint, browse hint, sources hint, and the volume readout beside the slider. None is pressable, and none sits inside a `MouseArea`. The token now carries exactly one meaning.
- **Accent indicator on `heading` rows is handled acceptably, not explicitly.** The 2px `Rectangle` at `Panel.qml:92-98` is gated on `chosen`, which no `heading` row ever sets, so it renders transparent. It works, but by omission rather than by design — a future `heading: true, chosen: true` row would paint an accent bar on a non-interactive header. Out of scope for this fix; worth a line in the convention if `HaloRow` grows.
- **The fix is a real behavioural change, not a rename.** `mutedLook` mapped to one thing (label colour). The replacement drives five distinct properties: fill, border colour, border width, label colour, cursor shape, and `MouseArea.enabled`. Back and Off changed colour `#9B9B9B` → `#C9C9C9`; headers additionally lost their fill, border, and pointer affordance. The two intents now diverge on more than a name.
- **Visual confirmation is asserted but not recorded.** The spec's Validation section prescribes a manual check (Listen → TuneIn → Browse → Local Radio, observe FM/AM headers), and the ledger says "Verification is manual, per the Validation section" — but nothing in the spec, the repo, or the diff records that check having been *performed*, only that it is the plan. For A1/A2/A3 the risk is low: Back and Off take literal `secondary: true`, so their rendering is fully determined by static bindings with constant inputs, and A2's only dynamic input (`isHeader`) is covered by an existing parser test. I am not downgrading on this. It is called out because this is a purely cosmetic defect whose acceptance is "does it look right," and no one has yet written down that they looked.
