# Delivery audit — watch-and-listen

**Audited:** current working tree (HEAD `1a98b21` + dirty `DirectorClient.js` `Service.qml` `Panel.qml` `tests/director-client.test.js` `README.md`) against `.hero/planning/features/watch-and-listen/spec.md`. Feature first landed in `e9de20d` (same commit as `room-volume-mute-off`). Later siblings share these files; this audit scores only `watch-and-listen`.
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] Watch lists `watch` experiences for `focusedRoomId` — `DirectorClient.js:307-355` `extractSources(..., "watch")`; `Service.qml:937` rebuilds from stashed `_uiConfig` / `_items`. Tests `tests/director-client.test.js:240-241` (`33:Apple TV,1:Blank HDMI,59:Cable Box`). Live 2026-08-23: Watch → Apple TV.
- [✓] Listen lists `listen` experiences for `focusedRoomId` — same join with `mode === "listen"`. Tests `:242-243,246` (listen names; HDMI `59` not in listen). Live 2026-08-23: Listen → TuneIn / Apple Music.
- [✓] Watch select POSTs `SELECT_VIDEO_DEVICE` `{ deviceid }` to `/api/v1/items/{focusedRoomId}/commands` — `Service.qml:260-282` existing `directorPost`; command is `SELECT_VIDEO_DEVICE` unless `sourceMode === "listen"`. Later `_alreadyCurrentSource` skip does not remove the command path.
- [✓] Listen select POSTs `SELECT_AUDIO_DEVICE` `{ deviceid }` to that path — `Service.qml:281-282`. Live Listen taps reached TuneIn / Apple Music browse.
- [✓] One source-picker for both modes — `Panel.qml:487-508` Watch/Listen segments call `setSourceMode`; one `sourcesList` (`:649-663`) bound to `session.sources`. Not two Repeaters. (`qs.Ui` `ButtonGroup` from `e9de20d` restyled to `HaloRow`.)
- [✓] Blank experience name joins item `name`; still-blank skipped — `DirectorClient.js:344-348` trim source name, else `namesById`, else `continue` (no `"Unknown Device"`). Tests `:241` item join + whitespace fallback.
- [✓] No focused room hides Watch/Listen picker — `Panel.qml:26-29` `hasFocusedRoom` requires `focusedRoomId`; `modeRow.visible: root.hasFocusedRoom` (`:488-489`); `listRowCount` is 0 without focus (`:61-62`).
- [✓] Empty list shows `No watch sources` / `No listen sources` — `Service.qml:946-949`; hint `Panel.qml:563-567`. User tap uses `_rebuildSources(false)` so a listen-only room can show **No watch sources**. Auto-flip only when `allowFlip` (`:938-944`). Live: Deck listen-only auto-flips.

## Changes
- [✓] `DirectorClient.js` — `sourceArray` (`:296-305`) + `extractSources` (`:307-355`); unknown mode treated as watch (`:308`, test `:252`). Existing join/auth helpers still present.
- [✓] `Service.qml` — stash `_uiConfig` / `_items` in `refreshRooms` (`:78-79,987-988`); `sourceMode` / `sources` / `sourcesHint` / `setSourceMode` / `selectSource` (`:30-32,248-282`); rebuild on focus (`:244`) and `_applyRooms` (`:1070`); disconnect clears sources/hint, keeps `sourceMode` (`:142-145`).
- [✓] `Panel.qml` — Watch/Listen + one source list, gated on connected + focused room (`:487-508,649-663`). Halo restyle, not a second picker.
- [✓] `tests/director-client.test.js` — watch vs listen, source name, item name, other room skipped, single-object `source`, missing sources → `[]`, `sourceArray` wrap (`:240-252`).
- [✓] `README.md` — Watch/Listen after a room is focused (`:98`).

## Open items (if any)

None.

## Audit notes
- Later volume, virtual remote, and Listen browse sit on the same files. They do not remove the Watch/Listen picker, join, or select POST.
- `selectSource` now skips the POST when `_alreadyCurrentSource` is true (later restore/remote). A new Watch/Listen tap still posts the spec command.
- No QML unit test of `selectSource` / hint text. User-visible AC#3–#5, #7–#8 rest on `Service.qml` / `Panel.qml` plus live 2026-08-23 use.
