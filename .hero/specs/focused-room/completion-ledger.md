# Completion Ledger — focused-room

Engineer: subagent 01a02e67-d479-7c33-98db-cb44fb3436e6
Delivery-lead follow-up: summoned live panel; screenshots of C4 chip + login form.

**Stack:** QML + `.pragma library` JS (Node `vm` tests).

**Validation**
- `node tests/director-client.test.js` — pass (git root)
- `omarchy plugin validate` live dir — pass (exit 0)
- `qmllint` via `/usr/lib/qt6/bin/qmllint` — exit 0 (existing Style/modelData unqualified warnings)
- Plugin list: `io.github.davydotcom.control4`, enabled: true
- `omarchy-shell shell rescanPlugins` — exit 0
- No new `.qml` filename

## Completion Ledger

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | WHEN connected SHALL `directorGet` ui_configuration then items; no new HTTP client | DONE | `Service.qml:166-200` — sequential `directorGet` only; parse failures return without applying |
| 2 | Join unique watch/listen rooms; omit hidden and unmatched ids | DONE | `DirectorClient.js:238-280`; tests hidden / cameras-only / gone 99 / blank name |
| 3 | Sort visible list by name then id, flat, no floor tree | DONE | `sortRoomsByNameThenId` + Panel `Column`/`Repeater` of Buttons (not ButtonGroup) |
| 4 | Tap room → `setFocusedRoom`, persist `{roomId}` in `focus.json`, chip shows name | DONE | Live: Base Fam then Deck. Chip `Deck`. `focus.json` `{"roomId":15}`. Screenshots `screenshot-2026-08-23_08-08-28.png`, `screenshot-2026-08-23_08-23-12.png` |
| 5 | Exactly one visible room and no persisted id → auto-select | SKIPPED | Four visible rooms on this Director. Cannot live a single-room house without Composer. Code: `Service.qml` `_applyRooms` `visible.length === 1` → `setFocusedRoom`. User signed off close-out. |
| 6 | SHALL NOT auto-select when two or more rooms and no id | DONE | Live: four rooms (Base Fam, Deck, Great Room, Office). First connected screenshot chip still `C4` until a room was picked. |
| 7 | Persisted id missing after refresh → clear focus + file, chip `C4`, hint `Saved room is gone. Pick a room.` | SKIPPED | Needs Composer hide/delete of the saved room. `_applyRooms` gone-id branch is in `Service.qml`. User signed off close-out. |
| 8 | Empty visible list → chip `C4`, hint `No rooms` | SKIPPED | Empty-join unit-tested in `tests/director-client.test.js`. Panel hint not live — this Director has four AV rooms. User signed off close-out. |
| 9 | Valid focus chip = room name, `Text.ElideRight` ~`Style.space(140)`, tooltip `Name — status` | DONE | Live chip `Base Fam` then `Deck` (`screenshot-2026-08-23_08-08-27.png`, `screenshot-2026-08-23_08-23-10.png`). Overlay `Text.ElideRight` cap `Style.space(140)`. Long-name elide not seen (names are short). |
| 10 | Expose `focusedRoomId` as only room context for later children | DONE | `Service.qml:26-29,156-164` — public `focusedRoomId` / `focusedRoomName` / `rooms` / `setFocusedRoom` / `refreshRooms` |
| 11 | Keep title Control4, Escape-to-close, left-click toggle; chip `C4` without valid focus. First-run form; after set, form is `credentials-gear` | DONE | First-run: `07-48-18` / `07-48-20`. After credentials: connected panel hides the form (`08-23-12`); chip `Deck` with valid focus. |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `DirectorClient.js` — extractRooms / isRoomHidden / sort / parseFocusFile | DONE | Appended helpers; auth/curl untouched |
| 2 | `Service.qml` — rooms API, focus.json FileView, refresh on connected, selection rules | DONE | Dedicated `chmodFocusProc`; mkdir reloads focus FileView; first refresh gated on `_focusLoaded` |
| 3 | `Panel.qml` — roomsHint + Column/Repeater Buttons | DONE | No ButtonGroup; no `directorGet` from panel |
| 4 | `BarWidget.qml` — eliding chip, tooltip, keep toggle / moduleName | DONE | `labelVisible: false` + overlay Text; cap `Style.space(140)` |
| 5 | `tests/director-client.test.js` — extractRooms / parseFocus fixtures | DONE | Existing assertions kept; all new cases pass |
| 6 | `README.md` — chip, pick room, focus.json path, no example password | DONE | Usage + persist path; no secrets |
| 7 | Live plugin copy + `rescanPlugins` | DONE | Copied to `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/`; validated live folder; rescan ok; widget is on the right bar section |

### Exercise-the-feature check

- [x] Unconnected path exercised live: C4 chip visible on bar; summon opens login panel (title Control4, Not configured, Connect form). Screenshots `screenshot-2026-08-23_07-48-18.png`, `screenshot-2026-08-23_07-48-20.png`.
- [x] Connected path: after Connect-hang fix (`_httpGen` + mkdir null-safe reload), panel listed Base Fam / Deck / Great Room / Office. Tap persisted `focus.json` `{roomId:15}` (Deck). Chip shows `Deck`. Screenshot `screenshot-2026-08-23_08-23-12.png`.
- [ ] Composer gone-id / empty-list / single-room auto-select not live-tapped. User signed off close-out. Join empty/hidden/gone-id covered by Node tests.

### Excellence Bar self-check

yes — join lives in JS with the exact hidden/unmatched/sort rules, QML stays thin, focus file is gated against auto-connect, and the chip elides without editing first-party `WidgetButton.qml`. Composer gone-id / empty-list / single-room auto-select were not live-tapped; user signed off close-out.
