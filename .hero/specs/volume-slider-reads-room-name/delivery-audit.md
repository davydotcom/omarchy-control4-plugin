# Delivery audit — volume-slider-reads-room-name

**Audited:** `32c1bb1732249a03d77c990171841fa4870fb8ef` (`git show 32c1bb1`); current `DirectorClient.js` / `tests/director-client.test.js` still contain the same parse key and live Deck fixture
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] WHEN Director returns `{ varName: "CURRENT_VOLUME", name: "Deck", value: 32 }` THE SYSTEM SHALL set slider volume to 32 — `DirectorClient.js:383-387` (`key = varName || name`); `tests/director-client.test.js:259-263` (`liveDeck.volume === 32`); `Service.qml:919-920` assigns `parsed.volume` to `root.volume`; user used slider live 2026-08-23 (not stuck at 0)
- [✓] WHEN `varName` is `IS_MUTED` and `value` is `0` THE SYSTEM SHALL NOT treat the room as muted — `DirectorClient.js:389-391` (`muted` only for `true` / `"true"` / `"1"` / `1`); `liveDeck` fixture `value: 0` asserts `muted === false` (`tests/director-client.test.js:261-263`)
- [✓] THE SYSTEM SHALL still accept the old `{ name: "CURRENT_VOLUME", value: 42 }` shape — `DirectorClient.js:383` falls back to `name`; `tests/director-client.test.js:254-258` (`name: "CURRENT_VOLUME", value: "42"` → volume 42) and `:264-265` (`name` only, value 7)

## Changes
- [✓] `DirectorClient.js` — `parseRoomVolume` keys off `varName` — `32c1bb1` replaced `row.name` with `row.varName || row.name`; still at `DirectorClient.js:383`
- [✓] `tests/director-client.test.js` — fixture with `varName` + `name: "Deck"` + `value: 32` — `liveDeck` at `:259-263` matches the investigation payload

## Open items (if any)

None.

## Audit notes
- Ledger AC#3 cites `:264-265` (old `name` shape, value 7). The literal `{ name, value: 42 }` case is the pre-existing assert at `:254-258`. Both exercise the fallback; not a gap.
- Later uncommitted work in the same files (media-device fields, watch-remote helpers) is outside this spec. The `varName` key and live Deck fixture from `32c1bb1` are intact.
