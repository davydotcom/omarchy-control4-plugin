# Delivery audit — focused-room

**Audited:** `git diff HEAD` (working tree vs `28e41295`)
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria
- [✓] Connected session SHALL `directorGet` `/api/v1/agents/ui_configuration` then `/api/v1/items`; no new HTTP client — `Service.qml:152-153,166-200` sequential `directorGet` on the existing queue; parse/transport errors `return` without `_applyRooms`; no `XMLHttpRequest` / second client
- [✓] Join unique watch/listen rooms; omit hidden, blank names, unmatched ids — `DirectorClient.js:198-280` `extractRooms` / `isRoomHidden`; tests hidden / cameras-only / gone 99 / blank name / watch+listen dedupe
- [✓] Sort visible list by name then id, flat, no floor tree — `DirectorClient.js:202-215,279` + test `3:Kitchen,5:Kitchen,1:Living Room`; `Panel.qml:176-197` `Column`/`Repeater` of `Button` (no `ButtonGroup`)
- [~] Tap room → `setFocusedRoom`, persist `{roomId}` in `focus.json`, chip shows name — wired `Service.qml:156-164,204-215`, `Panel.qml:185-194`, `BarWidget.qml:12-20`; not live-tapped
- [~] Exactly one visible room and no persisted id → auto-select — `Service.qml:275-277`; not live-exercised; no QML test of `_applyRooms`
- [~] SHALL NOT auto-select when two or more rooms and no id — `Service.qml:279-282`; not live-exercised
- [~] Persisted id missing after refresh → clear focus + file, chip `C4`, hint `Saved room is gone. Pick a room.` — `Service.qml:267-272`; not live-exercised
- [~] Empty visible list → chip `C4`, hint `No rooms` — `Service.qml:251-256`; empty-join unit-tested; panel hint not live-exercised
- [~] Valid-focus chip = room name, `Text.ElideRight` ~`Style.space(140)`, tooltip `Name — status` — `BarWidget.qml:12-20,96-130` (`labelVisible: false` + overlay `Text`); not seen on the bar with a room name
- [✓] Expose `focusedRoomId` as only room context for later children — `Service.qml:26-29,156-164` public `rooms` / `focusedRoomId` / `focusedRoomName` / `roomsHint` / `setFocusedRoom` / `refreshRooms`; no Watch/Listen/volume from this child
- [✓] Keep login form, title Control4, Escape-to-close, left-click toggle; chip `C4` without valid focus — live screenshots `screenshot-2026-08-23_07-48-18.png` (C4 on right bar) and `screenshot-2026-08-23_07-48-20.png` (panel Control4 / Not configured / IP / Email / Password / Connect); `Panel.qml:97,105-164`; `BarWidget.qml:15,132-136`

## Changes
- [✓] `DirectorClient.js` — `extractRooms` / `isRoomHidden` / `sortRoomsByNameThenId` / `parseFocusFile` appended; existing auth/curl helpers still present and unused by the join
- [✓] `Service.qml` — rooms API, `focus.json` `FileView` (`atomicWrites`, `chmodFocusProc`), `refreshRooms` on `connected` gated on `_focusLoaded`, mkdir reloads focus file, `_applyRooms` selection order, GET/parse keep previous `rooms`
- [✓] `Panel.qml` — `roomsHint` + connected `Column`/`Repeater` `Button`s; no `ButtonGroup`; no `directorGet` from the panel
- [✓] `BarWidget.qml` — eliding overlay chip, tooltip, `togglePanel` / `moduleName` unchanged; first-party `WidgetButton.qml` not edited
- [✓] `tests/director-client.test.js` — fixtures assert new join/hidden/sort/parse behavior; prior HTTP/auth assertions kept
- [✓] `README.md` — chip name, pick-room usage, `focus.json` path, no example password
- [✓] Live plugin dir `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/` — same seven files, no new `.qml`; live `Service.qml` / `BarWidget.qml` / `Panel.qml` / `DirectorClient.js` match the repo copies that implement the above

## Open items (if any)
- AC#4 tap room → persist + chip name — PARTIAL — engineer: not live-tapped, no Director — concrete (spec: do not invent a CI Director)
- AC#5 single-room auto-select — PARTIAL — engineer: `setFocusedRoom` wired, not live-exercised — concrete
- AC#6 do not auto-select when two or more rooms — PARTIAL — engineer: leaves focus null, not live-exercised — concrete
- AC#7 gone saved id → `C4` + `Saved room is gone. Pick a room.` — PARTIAL — engineer: `_applyRooms` branch, not live-exercised — concrete
- AC#8 empty list → `C4` + `No rooms` — PARTIAL — engineer: empty-join unit-tested; panel hint not live — concrete
- AC#9 eliding chip + `Name — status` tooltip — PARTIAL — engineer: overlay `Text` in `BarWidget.qml`; not seen on the bar — concrete

## Audit notes
- No `DONE` row was performative. AC#4–#9 are genuine PARTIAL: QML/JS implements the spec; the connected UI path was not run.
- `_applyRooms` selection rules have no unit test. Only `DirectorClient.extractRooms` / `parseFocusFile` are asserted in Node.
- Ledger/exercise-notes said the state dir had no `credentials.json`. At audit time that file is present (contents not reproduced). No `focus.json`. Screenshots still show **Not configured**, so this is not evidence of a connected session.
- Unified `git diff HEAD` was not executed in this auditor (no shell). File-level evidence is the working tree vs the last shipped director-session shape and HEAD `28e41295`. Named spec files all contain the focused-room code; no extra plugin `.qml` landed.
