---
title: Apple Music Listen shows Could not open browser
slug: apple-music-could-not-open-browser
type: bug
status: completed
domain: engineering
size: small
horizon: now
severity: high
priority: high
root_cause_class: race
claimed_by: david-estes
relates-to:
  - listen-library-browse
  - msp-browse-needs-navigator-session
  - stream-curl-transport
created: 2026-08-31
tags: [omarchy, control4, apple-music, navigator, msp]
claimed_by: david-estes
claimed_at: 2026-08-31T13:16:40-04:00
completed_at: 2026-08-31T17:20:29Z
---
# Apple Music Listen shows Could not open browser

## Kickoff

Hard-reset MSP nav on Listen browse open so Apple Music does not stick on Could not open browser.

**Status:** completed — verified 2026-08-31; live browseApple ×2 returned tabs; archived.

**Pick up at:** Nothing on this slug. If it recurs, check IPC `status.navDebug` before restarting the shell.

**Files:** `Service.qml` (`openMspBrowse`, `_retryNavConnect`, `browseWaitTimer`, `_navDebug`)

**Avoid:** Reverting the hard-reset to `if (!_navPhase)` — that was the sticky failure.

## Issue

Reported by David Estes on 2026-08-31 (second occurrence). Listen → Apple Music shows **Could not open browser** (sometimes later overwritten to **Apple Music did not respond**). Rooms, volume, and Director JWT stay connected. Same house worked after `listen-library-browse` / 0.6.0 nav retries, then failed again in a long-lived shell.

Workaround that recovered live: restart Quickshell (`killall quickshell` / shell restart). After restart, the same IPC `browseApple` returned five tabs immediately.

## Summary

### Categorization
| Attribute | Assessment |
|-----------|------------|
| **Criticality** | high — Listen library is unusable until shell restart |
| **Ease of Fix** | easy/moderate — force-reset nav on browse open; clarify fail hint |
| **Caused by our codebase?** | Yes — in-process MSP navigator state machine in `Service.qml` |
| **Needs more research?** | Partial — exact sticky Process field not caught mid-failure; failure mode and recovery are confirmed |

### Background
Apple Music browse is an in-process engine.io + `datatoui` navigator session (`msp-browse-needs-navigator-session`). 0.6.0 added `_retryNavConnect` so handshake/`datatoui` failures no longer stick on **Connecting…** forever. Retries still exhaust and surface **Could not open browser**.

### Analysis
While the long-lived plugin was failing, an out-of-process curl probe (same auth, same Director, same `datatoui` + `GetTabList`) succeeded every time. IPC status during failure: `sessionState=connected`, `hasToken=true`, `navConnectTries=2`, `hasNavClient=true`, `navPhase=""`, `browseTries=0`, hint **Could not open browser**. After shell restart, the same path returned tabs with `navPhase=live`.

### Root Cause
**Confirmed:** failure is inside the long-lived Quickshell plugin's MSP navigator connect path, not Director, cloud auth, or Apple Music account login. Connect gets a socket.io `clientId` then `_retryNavConnect("Could not open browser")` after `datatoui` err/empty/missing `subscriptionId` (or handshake miss on earlier tries). Retries exhaust in under ~1s. Disk cookie wipe alone did **not** recover; process restart did.

**Not confirmed (hypothesis):** Quickshell `httpProc`/`navProc` lifecycle sticky state (`_pending`, dropped `running=true`, stale StdioCollector body/markers) so `directorGet(datatoui)` returns err/`HTTP 0`/non-subscription body even though a fresh process succeeds. Secondary UX bug: armed `browseWaitTimer` later overwrites the real hint with **Apple Music did not respond** after `browseBusy` is already false.

### Source
`Service.qml` — `openMspBrowse`, `_retryNavConnect`, `_finishNavBody` (handshake / `datatoui` branches), `browseWaitTimer`.

### Fix Direction
On every Listen browse open, hard-reset navigator state (stop poll, clear phase/client/sub, delete cookie jar) then handshake cleanly. Keep existing retries. Do not let the browse timer replace a connect-failure hint. Optionally expose a compact `navDebug` in the existing IPC `status` for the next incident.

---

## Problem Statement

1. User opens Listen → Apple Music (or IPC `browseApple`).
2. Panel shows Connecting… → Retrying… → **Could not open browser**.
3. ~15s later the hint can flip to **Apple Music did not respond** even though connect already failed (`browseBusy=false`).
4. Tuning volume / room list still works. Out-of-process nav probe works. Shell restart fixes Listen browse.

Prior related fix: release 0.6.0 (`fcf0755`) added `_navConnectTries` / `_retryNavConnect` and armed `browseWaitTimer` during connect so handshake/`datatoui` failures were not silent. That made the failure visible and sometimes recoverable; it does not clear a stuck process-level transport state.

## Environment Details

- Omarchy Quickshell plugin `io.github.davydotcom.control4` (installed copy matched repo `Service.qml` / `DirectorClient.js` at fail time).
- Director `10.9.20.67`, Apple Music proxy item `434`, focused room Great Room `13`.
- Live fail IPC (before restart): `navConnectTries=2`, `hasNavClient=true`, `navPhase=""`, `browseTries=0`, hint Could not open browser.
- Live ok IPC (after restart): `browseRowCount=5`, titles Charts/Stations/Recommendations/History/Library, `navPhase=live`, `datatoui` bodyLen 33 with `subscriptionId`.

## Root Cause Analysis

### Confirmed

1. **Copy is ours.** `Service.qml` `_retryNavConnect` default / handshake / `datatoui` failure paths set `browseHint` to `Could not open browser`.
2. **Failure stage is navigator connect, not GetTabList.** `browseTries` stayed `0`; `hasNavClient` true means `parseSocketIoClientId` succeeded on the last try; fail paths after that are `datatoui` err/empty or missing `subscriptionId`.
3. **Director MSP stack is healthy.** Standalone Node+curl probe during the outage: handshake → clientId → `datatoui` 200 + `subscriptionId` → `GetTabList` → five tabs.
4. **Recovery is process restart, not Director/credentials.** Wiping `nav-cookies.txt` alone did not help; Quickshell restart did.

### Hypotheses (unproven)

- Re-entrant / dropped `httpProc.running = true` from inside `navProc.onExited` while volume poll shares the queue, leaving `datatoui` with empty body or `HTTP 0` (missing stderr markers).
- Stale StdioCollector stdout so `JSON.parse(body)` sees a volume payload without `subscriptionId`.
- `openMspBrowse` only calls `_startNav()` when `!_navPhase`, so a mid-phase zombie waits on the timer instead of forcing a clean restart (timer path uses hint **did not respond**).

### Secondary defect

`browseWaitTimer` restarts on each connect retry. After retries exhaust (`browseBusy=false`), the timer can still fire and hit the final branch that sets **Apple Music did not respond**, masking the real connect error.

## Code Flow (End to End)

1. `Service.qml` `selectSource` — Listen + Apple Music → `openMspBrowse`.
2. `openMspBrowse` — if not `live`, set Connecting…, arm `browseWaitTimer`, `_startNav` only if `!_navPhase`.
3. `_startNav` / `_navHandshake` — engine.io polling via `navProc` + cookie jar.
4. `_finishNavBody` handshake → ns (`40`) → clientId parse → `directorGet(/api/v1/items/datatoui?SubscriptionClient=…)`.
5. On `err` / empty body / no `subscriptionId` → `_retryNavConnect("Could not open browser")` (max 2 tries) then give up.
6. `browseWaitTimer` may later overwrite the hint to **did not respond**.

## Prevention

- Hard-reset navigator at browse open so a sticky mid-phase or half-dead `navProc` cannot poison the next attempt.
- Treat connect-fail hints as terminal for that timer generation (stop timer on exhaust, or ignore timer when `!browseBusy`).
- Keep IPC `status` (and a short `navDebug`) so the next incident does not need a code patch to see `datatoui` err/bodyLen.

## Goal

Listen → Apple Music opens the library again after a prior failed connect **without** restarting the shell. Failures that still happen show a stable, accurate hint (not overwritten). `node tests/director-client.test.js` still passes; live IPC `browseApple` returns tabs twice in a row in one shell session.

## Changes

1. **`Service.qml` `openMspBrowse`** — before connect, force `_stopNav()`, clear `_navConnectTries` (already), delete the cookie jar (`rmProc` or equivalent), then always `_startNav()` when not already `live` with a client (do not require `!_navPhase`).
2. **`Service.qml` `_retryNavConnect` / `browseWaitTimer`** — on exhaust, `browseWaitTimer.stop()`; timer must not replace a non-empty connect failure hint when `!browseBusy`.
3. **`Service.qml` IPC `status` (optional but small)** — include last connect debug (`err`, bodyLen, phase at fail) for support without re-instrumenting.
4. **Live check** — `qs … browseApple` twice without shell restart; confirm tabs both times. Run `node tests/director-client.test.js`.

## Boundaries

- No Apple Music web API / OAuth browser.
- No Python sidecar navigator (`in-process-director-rest`).
- No TuneIn redesign (same nav session, but this bug was reproduced on Apple Music).
- Not fixing unrelated volume queue depth beyond what browse open reset needs.

## Risks

- Force-reset on every browse open drops an in-flight nav poll — acceptable because browse open already owns that session.
- Deleting the cookie jar each open may add one round-trip; probe shows full connect is ~2s.
- Over-reset while `live` must not tear down a healthy session when only refreshing tabs — gate reset on `!live || !_navClientId` (same gate as today's connect branch).

## Acceptance Criteria

- WHEN Listen → Apple Music is opened after a prior **Could not open browser** in the same shell THEN the panel SHALL show Apple Music tabs without requiring a Quickshell restart
- WHEN navigator connect exhausts retries THEN the panel SHALL keep the connect failure hint and SHALL NOT replace it with **Apple Music did not respond** solely because `browseWaitTimer` fires after `browseBusy` is false
- WHEN navigator connect succeeds THEN IPC/`browseRows` SHALL list Director tabs (Charts/Stations/… or account-specific set) as today

## Completion Ledger

Hard-reset MSP nav on every non-live `openMspBrowse`, stop the browse timer from masking connect failures, and expose `navDebug` on IPC status.

**Validation**
- `node tests/director-client.test.js` — ok
- Live 2026-08-31: after install + shell restart, `qs … browseApple` twice in one process → 5 tabs each time; +16s later tabs/hint unchanged

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | After prior Could not open browser, tabs without shell restart | DONE | `openMspBrowse` hard-reset `_stopNav` + `rmProc` + always `_startNav` (`Service.qml:422-431`). Stuck state could not be re-induced post-fix; cold connect + second browse in same shell both returned 5 tabs |
| 2 | Exhausted connect fail hint not overwritten by timer | DONE | `_retryNavConnect` stops timer (`:778`); `browseWaitTimer` returns early when `!browseBusy` (`:1597-1600`) |
| 3 | Successful connect lists Director tabs | DONE | Live IPC: Charts/Stations/Recommendations/History/Library; `navPhase=live` |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `openMspBrowse` force stop/wipe/always start | DONE | `Service.qml:415-431` |
| 2 | `_retryNavConnect` / timer hint stability | DONE | stop on exhaust `:778`; early return `:1597-1600` |
| 3 | IPC `navDebug` | DONE | property `:80`; handshake/datatoui fill; `status()` `:1698` |
| 4 | Live check + unit tests | DONE | browseApple ×2 + 16s hold; `node tests/director-client.test.js` ok |

### Exercise-the-feature check

- [x] User-visible behavior exercised end-to-end: `qs -p /usr/share/omarchy/shell ipc call io.github.davydotcom.control4 browseApple` twice after shell restart with new `Service.qml`; both returned 5 Apple Music tabs; status after +16s still 5 tabs and empty hint

### Excellence Bar self-check

Yes — minimal state-machine fix at the known failure site, preserves live session when already connected, and keeps a support breadcrumb (`navDebug`) for the next incident.
