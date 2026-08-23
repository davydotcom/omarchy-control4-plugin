# Delivery audit — room-volume-mute-off

**Audited:** landing `f2f5f03` (slider replace) + parse fix `32c1bb1`; current tree HEAD `1a98b21` + working copy of `DirectorClient.js` `Service.qml` `Panel.qml` `tests/director-client.test.js` `README.md`
**Verdict:** SHIP
**Surface:** clean

Sibling work in the same files (Watch remote, browse, `parseRoomVolume` power/media fields) is not scored against this spec.

## Acceptance criteria
- [✓] Focused room shows 0–100 slider from CURRENT_VOLUME — `Panel.qml:603-617` `PanelSlider` `minimum: 0` `maximum: 100` `integer: true` `value: session.volume`. Poll `Service.qml:892-921` GET `.../variables?varnames=CURRENT_VOLUME,IS_MUTED,...` → `DirectorClient.parseRoomVolume` (`DirectorClient.js:384-387`). Timer 2s (`Service.qml:1542-1547`); also `setFocusedRoom` (`Service.qml:245`). Hold-off 1.5s (`Service.qml:917-918`). Tests: `parseRoomVolume` fixtures (`tests/director-client.test.js:254-269`). User 2026-08-23: slider shows room level.
- [✓] Release POSTs SET_VOLUME_LEVEL `{ LEVEL }` — `Panel.qml:618-621` `onReleased` → `setVolume`. `Service.qml:872-879` clamps 0–100 integer, then `_roomCommand("SET_VOLUME_LEVEL", { LEVEL: n })` → `directorPost` `/api/v1/items/{focusedRoomId}/commands` (`Service.qml:925-928`). Test: `commandBody` LEVEL 42 (`tests/director-client.test.js:271-272`). User used slider live 2026-08-23.
- [✓] SHALL NOT post on every drag tick — only `onReleased` (`Panel.qml:618`); no `onMoved` handler.
- [✓] Right-click POSTs MUTE_TOGGLE — `Panel.qml:622` `onRightClicked` → `toggleMute`. `Service.qml:882-885` `_roomCommand("MUTE_TOGGLE", {})`. Slider `opacity` 0.5 while muted (`Panel.qml:617`).
- [✓] Off POSTs ROOM_OFF — `Panel.qml:626-631` HaloRow "Off" → `roomOff`. `Service.qml:888-889` `_roomCommand("ROOM_OFF", {})`. User used Off live 2026-08-23.
- [✓] No focused room hides slider and Off — `footerColumn.visible: root.hasFocusedRoom` (`Panel.qml:579`). `hasFocusedRoom` requires `connected` and a finite `focusedRoomId` (`Panel.qml:26-29`).
- [✓] Off on a different row from the slider — slider in `volumeRow` (`Panel.qml:586-624`); Off `HaloRow` is the next child of `footerColumn` (`Panel.qml:626-631`).

## Changes
- [✓] `DirectorClient.js` — `parseRoomVolume` — `DirectorClient.js:373-411`. Reads `varName || name`; clamps volume 0–100; `IS_MUTED` true for `true` / `"1"` / `1`.
- [✓] `Service.qml` — `volume` / `muted` / `setVolume` / poll / hold; `_roomCommand` takes optional params; pulse helpers gone — `Service.qml:80-88,872-928,1542-1547`. No `pulseVolumeUp` / `pulseVolumeDown` remain.
- [✓] `Panel.qml` — `PanelSlider` + level label (`volume` or `M`); right-click mute; Off kept — `Panel.qml:575-631`.
- [✓] `tests/director-client.test.js` — parse volume/mute fixtures — `tests/director-client.test.js:254-269` (muted, Director `varName`, missing IS_MUTED, invalid, clamp).
- [✓] `README.md` — slider, right-click mute, Off — `README.md:99`.

## Open items (if any)

None.

## Audit notes
- Ledger line `Service.qml:1543` for the poll timer is the `interval: 2000` line; the Timer block is `Service.qml:1542-1547`. Citation drift only.
- `parseRoomVolume` also returns `power` / media ids used by siblings. Volume/mute contract from this spec is present.
