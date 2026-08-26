# Delivery audit — room-now-playing

**Audited:** HEAD `0e728f7` (implementation already committed) + dirty Completion Ledger on `.hero/planning/features/room-now-playing/spec.md`. Named `git diff` had no QML/JS/README/convention hunks. Icons `icon.png` / `icon-off.png` are tracked and clean.
**Verdict:** SHIP
**Surface:** clean

Scored only the named files against this spec. Unrelated dirty files were ignored.

## Acceptance criteria
- [✓] Keep the existing room-variables poll; no second Timer / `media_sessions` — `Service.qml:919` same GET `CURRENT_VOLUME,IS_MUTED,POWER_STATE,CURRENT_VIDEO_DEVICE,PLAYING_AUDIO_DEVICE,LAST_DEVICE_GROUP`; only `volumeTimer` at `Service.qml:1565-1570` interval 2000. No `media_sessions` in `*.qml` / `*.js`.
- [✓] POWER_STATE 0 → white mark, panel `Off`, no source name — `nowPlayingLabel` returns `""` when `power === false` (`DirectorClient.js:435-436`, test `:346-347`); `panelStatus` is `Off` (`Panel.qml:50-51`); chip shows `icon-off.png` when `!roomOn` (`BarWidget.qml:17,139-146`). Tooltip appends source only when state is `On` (`BarWidget.qml:24-27`).
- [✓] On + listen → `PLAYING_AUDIO_DEVICE` name in status and tooltip — listen branch uses `playingAudioDeviceId` (`DirectorClient.js:437-439`, test `:355-365` including capital-`L` `Listen` and ignore `100002`); `panelStatus` `Listen ·` when `lastDeviceGroup === "listen"` (`Panel.qml:55-57`); tooltip `On ·` + `playingSourceName` (`BarWidget.qml:24-27`).
- [✓] On + watch source → that name in status and tooltip — watch via `matchWatchSourceId` (`DirectorClient.js:441-443`, test `:353-354`); `panelStatus` `Watch ·` otherwise (`Panel.qml:56-57`).
- [✓] Not connected / no room → faded white mark, distinct from room-off — `hasFocusedRoom` false → opacity 0.55 and `!roomOn` white mark (`BarWidget.qml:12-17,125,146`); connected+focused+off is opacity 1.0.
- [✓] SHALL NOT spell room or source as chip text — `labelVisible: false` (`BarWidget.qml:113`); chip children are two `Image`s only (`:127-149`).
- [✓] Room off → Off row chosen, source rows not chosen — Off `chosen: session.roomOn === false` (`Panel.qml:640`); source `chosen` requires `roomOn !== false` (`Panel.qml:670-674`).
- [✓] Off tap shows off chip and `Off` status before next poll — `roomOff()` sets `roomOn = false` and `playingSourceName = ""` before POST (`Service.qml:902-905`).

## Changes
- [✓] `nowPlayingLabel` in `DirectorClient.js` — `DirectorClient.js:413-447`; reuses `matchWatchSourceId`; lives next to `parseRoomVolume`.
- [✓] nowPlayingLabel fixtures — `tests/director-client.test.js:332-372` (off-with-ids, watch 431, listen 10 vs Digital Media, unknown id, `Listen` lowercased).
- [✓] Service `playingSourceName` + optimistic off/select — property (`Service.qml:84`); clear on disconnect / unfocused / `setFocusedRoom` (`:150,241,912`); `refreshVolume` assign (`:930-935`); `roomOff` (`:902-905`); `selectSource` sets `roomOn` / name only when it posts SELECT (`:284-296`).
- [✓] Panel status + Off/source chosen — `Panel.qml:47-62,640,670-674`.
- [✓] BarWidget tooltip + dual-Image mark — `BarWidget.qml:18-31,116-149`.
- [✓] `icon.png` / `icon-off.png` in the plugin copy set — tracked in repo; README install list (`README.md:69-76`); live plugin copy matches repo on 2026-08-23.
- [✓] README leftover room-name chip sentence — chip is the mark; name/source live in tooltip and panel status (`README.md:13-16,99-101`).
- [✓] halo-remote-panel-style example + bar-chip exception — layout example `Listen · Apple Music` / `Off` (`halo-remote-panel-style/spec.md:55,69-80`); Exceptions name both PNGs (`:95`).

## Open items (if any)

None.

## Audit notes

None.
