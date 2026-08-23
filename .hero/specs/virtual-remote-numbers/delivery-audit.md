# Delivery audit — virtual-remote-numbers

**Audited:** `git diff HEAD -- DirectorClient.js Service.qml Panel.qml tests/director-client.test.js .hero/knowledge/conventions/halo-remote-panel-style/spec.md .hero/planning/features/virtual-remote-numbers/spec.md` (working tree vs HEAD `1a98b21`)
**Verdict:** SHIP
**Surface:** noteworthy

Sibling D-pad, transport, surround, and source-restore live in the same working tree. This audit scores only the channel pad: `hasWatchRemoteUi` channel branch, Service channel/number flags, Panel Ch−/Ch+ plus 0–9 rows, tests, convention exception.

## Acceptance criteria
- [✓] AC-1 Channel flags + `CHANNEL_*` show Ch− / Ch+ — `Service.qml:447-448` `remoteChannelUp` / `remoteChannelDown` require `hasChannelUpDown` and `hasRemoteCommand`. `Panel.qml:832-856` `channelRow` after transport, before digits; labels `Ch-` / `Ch+`.
- [✓] AC-2 Discrete select + digits show 0–9 pad — `Service.qml:449` `remoteNumberPad` is `hasDiscreteChannelSelect && hasDigits`. `Panel.qml:858-996` four rows (`1–3`, `4–6`, `7–9`, `*` / `0` / `#`). Cable fixture has both flags (`tests/director-client.test.js:418-419`).
- [✓] AC-3 `NUMBER_*` without channel flags shows no pad — `hasWatchRemoteUi(digitsOnlyCaps) === false` (`tests/director-client.test.js:476-479`). dvd `!hasChannelUpDown && !hasDiscreteChannelSelect` (`:392,480`). Service flags require a channel capability, so Apple TV digits cannot light the pad.
- [✓] AC-4 Tap POSTs `CHANNEL_*` / `NUMBER_*` with empty `tParams` — keys call existing `sendRemote` (`Panel.qml:845,854,871,880,889,906,915,924,941,950,959,976,985,994`). `Service.qml:475-484` POSTs `/api/v1/items/{remoteDeviceId}/commands` with `{}` and `directorPost(..., function() {})`. No new send function.
- [✓] AC-5 Channel-only source still opens the remote — `DirectorClient.js:591-592` `hasWatchRemoteUi` true on either channel flag. Cable fixture has no nav/transport (`tests/director-client.test.js:420`) and `hasWatchRemoteUi(cableCaps) === true` (`:475`).
- [~] AC-6 Live multi-digit tune on Cable DVR — SKIPPED `[signed-off]`. User 2026-08-23: no device in daily use; test later. Per-digit send, no buffer. Not a performative DONE.

## Changes
- [✓] `hasWatchRemoteUi` includes channel flags — `DirectorClient.js:586-593`. Parser unchanged in this child.
- [✓] Tests: cable opens, digits-only does not, dvd/receiver no pad — `tests/director-client.test.js:473-481`.
- [✓] Service channel/number flags — `Service.qml:50-54,447-451`. `remoteStar` / `remotePound` also require `hasRemoteCommand`. No new send function.
- [✓] Panel channel row + four digit rows + `listRowCount` — `Panel.qml:71-72,100-107,832-996`. Last row shares width via `numberLastCount`.
- [✓] Convention exception names this child — `.hero/knowledge/conventions/halo-remote-panel-style/spec.md:95` gates the pad on `has_channel_up_down` / `has_discrete_channel_select`, never `NUMBER_*` alone.

## Open items
- AC-6 Live multi-digit tune on Cable DVR — SKIPPED — User 2026-08-23: no device in daily use; test later. Per-digit send, no buffer. — concrete (`[signed-off]`)

## Audit notes
- Independent re-run: `node tests/director-client.test.js` → `ok`, exit 0.
- Live plugin copy + `omarchy restart shell` is recorded. Live Cable DVR open/tune was not run; that gap is AC-6, not a silent DONE on AC-1–5.
- Prefix-tune risk on per-digit send is named in the spec and owned by the deferred live test.
