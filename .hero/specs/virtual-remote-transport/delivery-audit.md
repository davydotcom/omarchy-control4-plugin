# Delivery audit — virtual-remote-transport

**Audited:** `git diff HEAD -- DirectorClient.js Service.qml Panel.qml tests/director-client.test.js .hero/knowledge/conventions/halo-remote-panel-style/spec.md` (working tree vs HEAD `1a98b21`)
**Verdict:** SHIP
**Surface:** clean

Sibling D-pad, surround rows, and Back/Off secondary live in the same working tree. This audit scores only the transport cluster: `hasWatchRemoteUi` + `hasTransport`, Service `remotePlay`… flags, two glyph Rows, tests, convention exception.

## Acceptance criteria
- [✓] AC-1 Declared transport keys appear under the D-pad — `Panel.qml:746-823` two `Row`s after Down (`737-744`) and before the surround Repeater (`825-835`). Keys gated on `remoteSkipRev` / `remotePlay` / `remotePause` / `remoteSkipFwd` / `remoteScanRev` / `remoteStop` / `remoteScanFwd` from `Service.qml:370-377` (`caps.transport`). Play and Pause stay separate glyphs (`▶` / `⏸`).
- [✓] AC-2 No declared transport → omit the cluster — rows `visible: transportMainCount > 0` / `transportScanCount > 0` (`Panel.qml:748,792`); undeclared keys `width: 0`. Receiver fixture `!hasTransport` (`tests/director-client.test.js:446`).
- [✓] AC-3 `show_transport` is never the show/hide gate — Panel/Service never read `showTransport`. Parser still records it; test `show_transport false does not hide declared keys` (`tests/director-client.test.js:456-464`). Existing c4z `showTransport === null` still `hasTransport` (`tests/director-client.test.js:392-393`).
- [✓] AC-4 Tap POSTs that command with empty `tParams` without blocking — each key calls existing `sendRemote` (`Panel.qml:759,768,777,786,803,812,821`). `Service.qml:401-410` POSTs `/api/v1/items/{remoteDeviceId}/commands` with `{}` and `directorPost(..., function() {})`. No `sendTransport`.
- [✓] AC-5 Transport-only still opens the remote — `DirectorClient.js:565-571` `hasWatchRemoteUi` is true when `hasTransport`. Test play-only (`tests/director-client.test.js:454-456`).

## Changes
- [✓] `hasWatchRemoteUi` also true for `hasTransport` — `DirectorClient.js:565-571`. Parser / `_TRANSPORT_KEYS` / `sendRemote` unchanged in this child.
- [✓] Tests: play-only open, `show_transport` false, parent dummy `ON`, receiver no transport — `tests/director-client.test.js:416,446,454-464`. `itemForWatchRemote` parent is `ON` so `PLAY` no longer short-circuits the child walk.
- [✓] Service transport flags + `_applyRemoteCaps` — `Service.qml:43-49,370-377`. `closeRemote` clears via `_applyRemoteCaps(null)`. No new send function.
- [✓] `Panel.qml` two glyph Rows + `listRowCount` — `Panel.qml:69-70,79-102,746-823`. Visible keys share width via `transportSlotWidth` (not the D-pad mid-row divide-by-3).
- [✓] Halo convention exception names this child — `.hero/knowledge/conventions/halo-remote-panel-style/spec.md:93`.

## Open items (if any)

None.

## Audit notes
- Live plugin copy + `omarchy restart shell` is recorded. On-panel Pause/Play was not clicked (no GUI driver; spec forbids agent live POST). Press path is the already-shipped `sendRemote`.
- Independent re-run this audit: `node tests/director-client.test.js` → `ok`, exit 0. `qmllint` on `Panel.qml` and `Service.qml` → exit 0, 0 lines matching `^Error:`.
