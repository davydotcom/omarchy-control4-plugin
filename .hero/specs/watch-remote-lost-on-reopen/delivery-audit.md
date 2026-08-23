# Delivery audit — watch-remote-lost-on-reopen

**Audited:** `git diff HEAD -- DirectorClient.js Service.qml Panel.qml tests/director-client.test.js` (working tree vs HEAD `1a98b21`)
**Verdict:** SHIP
**Surface:** clean

Sibling Watch-remote work (D-pad, transport, surround) lives in the same uncommitted files. This audit scores only restore/reopen: `CURRENT_VIDEO_DEVICE` / `PLAYING_AUDIO_DEVICE` / `LAST_DEVICE_GROUP`, `matchWatchSourceId`, `restoreActiveSource` without SELECT, skip duplicate SELECT, `Panel.open` restore.

## Acceptance criteria
- [✓] AC-1 Panel open restores Watch remote without SELECT — `Panel.qml:281-284` `open()` → `session.restoreActiveSource()`. `Service.qml:306-327` matches `currentVideoDeviceId` via `matchWatchSourceId`, sets `selectedSourceId`, `openWatchRemote` when `hasWatchRemoteUi`. No `directorPost` on this path; `openWatchRemote` (`Service.qml:452-463`) is local state only.
- [✓] AC-2 Room change restores the same way — `setFocusedRoom` clears selection/remote then `_wantSourceRestore = true` (`Service.qml:235-240`) and `refreshVolume()`. Volume GET stashes media ids then restores only when that flag is set (`Service.qml:898-905`). `_applyRooms` sets the same flag and calls `refreshVolume()` (`Service.qml:1045,1061`). Periodic ticks do not set the flag (Back stays closed).
- [✓] AC-3 Tap of already-current Watch source skips SELECT and still opens remote — `_alreadyCurrentSource` (`Service.qml:297-304`) matches via `matchWatchSourceId` or raw `currentVideoDeviceId`. `selectSource` skips POST when `already` (`Service.qml:273-277`) then still `openWatchRemote` (`:279-283`).
- [✓] AC-4 Tap of a different Watch source still POSTs `SELECT_VIDEO_DEVICE` — `already` false → `directorPost(..., "SELECT_VIDEO_DEVICE", { deviceid: n }, ...)` (`Service.qml:275-277`). Command and body unchanged.
- [✓] AC-5 Room off does not open the remote from restore — `Service.qml:318-320` `roomOn === false` → `closeRemote()` and return.

## Changes
- [✓] Extend `parseRoomVolume`; add `matchWatchSourceId` — `DirectorClient.js:357-411,617-642`. New fields `videoDeviceId` / `playingAudioDeviceId` / `lastDeviceGroup`; ignores `CURRENT_AUDIO_DEVICE`; parent/child walk reuses `itemForWatchRemote`.
- [✓] Tests for media ids + match helper — `tests/director-client.test.js:314-330,443-447`. Volume/power fixtures still present above those lines.
- [✓] Extra varnames, stash, restore, skip duplicate SELECT — `Service.qml:79-82,238,273-327,892-905,1045`. GET varnames extended on the existing volume poll (`:892`). Listen restore highlights only (`:329-350`); no MSP browse.
- [✓] `Panel.open` calls `restoreActiveSource` — `Panel.qml:281-284`.

## Open items (if any)

None.

## Audit notes
- Independent re-run this audit: `node tests/director-client.test.js` → `ok`, exit 0. `/usr/lib/qt6/bin/qmllint Panel.qml` and `Service.qml` → exit 0, 0 lines matching `^Error:`.
- Ledger records live plugin copy + `omarchy restart shell`. On-panel open after Watch Apple TV was not clicked this turn (no GUI driver).
