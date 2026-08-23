# Delivery audit — virtual-remote-dpad

**Audited:** `git diff --` (working tree vs HEAD `1a98b216`) on `DirectorClient.js` `Service.qml` `Panel.qml` `tests/director-client.test.js` `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` `.hero/planning/features/virtual-remote-dpad/spec.md`
**Verdict:** SHIP
**Surface:** clean

Sibling `watch-receiver-audio-options` surround rows and Halo `secondary`/`heading` are present in the same working tree. This audit scores only the D-pad child. Surround under the pad is not a D-pad defect.

## Acceptance criteria
- [✓] AC-1 Watch source with navigation shows D-pad with Menu and Enter — `Panel.qml:650-718` Menu / ↑ / ← Enter → / ↓ `HaloRow`s gated on `remoteMenu` / `remoteUp` / `remoteLeft` / `remoteEnter` / `remoteRight` / `remoteDown`. `Service.qml:264-270,373-384` Watch select → `openWatchRemote`. User live: Apple TV pad appears.
- [✓] AC-2 Direction press sends the command without blocking UI — `Service.qml:386-395` `sendRemote` → `directorPost(..., function() {})`. `directorPost` wraps `DirectorClient.commandBody` (`Service.qml:165-166`). Pad rows call `sendRemote("UP"|"DOWN"|"LEFT"|"RIGHT"|"MENU"|"ENTER")`. HaloRow `lit` press feedback (`Panel.qml:94,128-152`). User live: Apple TV responds to arrows/Menu.
- [✓] AC-3 Back returns to the watch source list — `Panel.qml:478-491` Back visible when `remoteOpen`, calls `closeRemote()`. Source list `visible: !remoteOpen` (`Panel.qml:616-618`). `closeRemote` leaves `selectedSourceId` set (`Service.qml:366-370`).
- [✓] AC-4 No navigation → no D-pad; cable-without-nav stays tap-to-select — pad rows hidden when nav flags are false. `hasWatchRemoteUi(cableCaps) === false` (`tests/director-client.test.js:452`). Surround-only sources may still open the remote surface (sibling); D-pad is not shown.
- [✓] AC-5 POST `/api/v1/items/{id}/commands` with `commandBody` and empty `tParams` — `Service.qml:395` `directorPost("/api/v1/items/" + deviceId + "/commands", …, {}, …)`. `commandBody` emits `{ async: true, command, tParams }` (`DirectorClient.js:46-52`). `deviceId` is `remoteDeviceId` from `itemForWatchRemote` (nav proxy; parent/child walk). Tests: `tests/director-client.test.js:416-424`. User live: Great Room Watch id was not the nav proxy; resolved proxy drove the device.

## Changes
- [✓] `Service.qml` `remoteOpen` / `openWatchRemote` / `sendRemote` / Watch `selectSource` — `Service.qml:34-42,264-270,355-395`. `setFocusedRoom` / `setSourceMode` / disconnect call `closeRemote()` (`Service.qml:149,226,239`). `sendRemote` no-ops unless connected, `remoteOpen`, finite `remoteDeviceId`, and `hasRemoteCommand`.
- [✓] `Panel.qml` Back + listArea D-pad + `listNaturalHeight` — `Panel.qml:60-79,478-491,650-718`. Only declared nav keys `visible`. Pad uses primary `HaloRow` (no `secondary`/`heading` on Menu/arrows/Enter).
- [✓] Halo convention: metadata-gated D-pad is this child — `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` anti-pattern no longer forbids the pad; Exceptions names `virtual-remote-dpad`.
- [✓] `tests/director-client.test.js` still pass; helpers extracted — dvd/c4z `hasNavigation` still asserted; `itemForWatchRemote` parent/child/self tests. Claimed run: `node tests/director-client.test.js` exit 0, stdout `ok`.

## Open items (if any)

None.

## Audit notes
- POST target is the resolved nav proxy (`remoteDeviceId`), not always the Watch list id. Spec approach named `selectedSourceId`; live Great Room evidence required the parent/child walk. This matches the spec's own proxy-then-parent fallback, not a missing AC.
- Surround Repeater / `sendSurround` / `hasWatchRemoteUi` surround branch are sibling `watch-receiver-audio-options`. Not scored against this spec.
