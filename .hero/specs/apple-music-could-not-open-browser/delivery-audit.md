# Delivery audit — apple-music-could-not-open-browser

**Audited:** `git diff HEAD -- Service.qml` (working tree vs `fcf0755`)
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] After prior Could not open browser, tabs without shell restart — `Service.qml:417-432` hard-reset `_stopNav` + `rmProc` + always `_startNav` when not live; live `browseApple` ×2 in one shell → 5 tabs each (stuck fail state not re-induced post-fix; structural fix + double-browse evidence)
- [✓] Exhausted connect fail hint not overwritten by timer — `Service.qml:778` `browseWaitTimer.stop()` on exhaust; `Service.qml:1599-1600` early return when `browseOpen && !browseBusy`; live +16s hold kept empty hint
- [✓] Successful connect lists Director tabs — live IPC Charts/Stations/Recommendations/History/Library; `navPhase=live`

## Changes
- [✓] `openMspBrowse` force stop/wipe/always start — `Service.qml:415-431` in diff
- [✓] `_retryNavConnect` / timer hint stability — stop on exhaust `:778`; early return `:1597-1600`
- [✓] IPC `navDebug` — property `:80`; handshake/datatoui fill `:897`, `:919-931`; `status()` `:1698`
- [✓] Live check + unit tests — browseApple ×2 + 16s hold per ledger; `node tests/director-client.test.js` → `ok` (DirectorClient regression; QML path covered by live exercise)

## Open items (if any)

(none)

## Audit notes

(none)
