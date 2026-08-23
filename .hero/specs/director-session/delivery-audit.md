# Delivery audit — director-session

**Audited:** untracked plugin files vs `/dev/null` (repo has no commits); live copy at `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/`
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] Save IP+email+password → director JWT + GET `/api/v1/agents/ui_configuration` — `Service.qml:41-61` `connectNow` → `_startAccountAuth`; `Service.qml:256-337` accountAuth → accounts → directorAuth → probe `DirectorClient.directorUrl(..., "/api/v1/agents/ui_configuration")`; tests `parseAccountToken` / `parseDirectorToken` / `parseControllerCommonName`. LAN happy path not live-run (no Director; spec Validation).
- [✓] WHILE JWT valid, keep session in headless service when panel closes — `manifest.json:9-16` `keepLoaded: true`, `kinds: ["service","bar-widget"]`, `entryPoints.service: "Service.qml"`; JWT is `_directorToken` in memory only (`Service.qml:26`, `324`); panel close does not call `disconnect()`. Ledger: summon/hide left state dir in place.
- [✓] LAN probe HTTP 401 → auth-failed OS 4.2 copy, no retry-loop — `DirectorClient.js:15,135-142` `classifyProbe(401)` → `director401`; `Service.qml:159-165,349-351` `_failDirector401`; `Service.qml:138-141` timer stop on `auth-failed`; test `classifyProbe(401)` + `statusTextFor(..., "director401")` → `STATUS_DIRECTOR_401`. Not run on OS 4.2 hardware.
- [✓] Cloud sign-in fail → `Sign-in failed`, distinct from unconfigured and Director 401 — `DirectorClient.js:14,125-129,158-161`; `Service.qml:150-157,258-270`; tests `classifyCloudStatus(401)` + `statusTextFor(..., "cloud")`. Ledger: live `apis.control4.com` POST HTTP 401 → `sign-in`.
- [✓] Network/TLS/timeout → `error`, distinct — `DirectorClient.js:140-150` `classifyProbe` non-401 + `networkErrorMessage` (28 timeout, 7 connect); `Service.qml:167-171,224-230,353` `_failError`; test `classifyProbe(500).kind === "error"`.
- [✓] HTTP via Process+curl, no Python, no XMLHttpRequest — `Service.qml:453-471` `httpProc`; `DirectorClient.js:170-180` `curlArgs`; no `XMLHttpRequest` / Python in plugin sources.
- [✓] LAN probe 200 → connected on panel — `Service.qml:340-347` `_setState("connected")`; `DirectorClient.js:13,156-157` `STATUS_CONNECTED`; `Panel.qml:18,113-119` binds `session.statusText`. Test `statusTextFor("connected")`. Not LAN-exercised.
- [✓] Persist credentials only at state path; not `shell.json` — `Service.qml:12-14,124-136` `credentialsPath` + `persistCredentials` writes `{controllerIp,email,password}` only; `manifest.json` has no `barWidget.schema`; `~/.config/omarchy/shell.json` right-bar entry is id-only (no password). `credentials.json` absent (never connected).
- [✓] Expose `directorGet` / `directorPost` `{async,command,tParams}` — `Service.qml:95-121`; no-JWT callbacks with error, no login start; `DirectorClient.js:46-53` `commandBody`; test `commandBody("SELECT_AUDIO_DEVICE", {deviceid:9})`.
- [✓] Service start + complete credentials file → auto-connect — `Service.qml:365-397,488` `loadCredentials` → `connectNow()` when `credentialsComplete`; `Component.onCompleted` mkdir then reload. Not live-exercised (no credentials file).
- [✓] Refresh at 80% `validSeconds`; 401 → auth-failed, no spin — `Service.qml:357-363,474-485` `_armRefresh` interval `_validSeconds * 0.8`; refresh re-runs `_startAccountAuth`; `Service.qml:138-141,150-157` `_failSignIn` / `_setState("auth-failed")` stop timer.
- [✓] MUST NOT place password or JSON bodies in `Process.command` argv — `DirectorClient.js:175-178` `--data-binary @bodyPath`; `Service.qml:192-213` FileView + chmod 600 then curl; test `curlArgs` argv has no `password` / `secret` and no `-f`.

## Changes
- [✓] `manifest.json` service kind, `keepLoaded`, `entryPoints.service` — `manifest.json:9-16`; no `barWidget.schema`.
- [✓] `DirectorClient.js` builders/parsers/classify/curl argv — `APPLICATION_KEY` `DirectorClient.js:4`; account/director bodies `17-44`; parsers `70-123`; `classifyCloudStatus` / `classifyProbe` `125-143`; `curlArgs` `-k` only when insecure, `-w \n%{http_code}`, no `-f` `170-180`; `commandBody` `46-53`.
- [✓] `Service.qml` state machine, FileView, curl queue, refresh, `directorGet`/`directorPost` — `sessionState` `17`; mkdir/FileView/chmod `405-451`; serialized `_queue`/`_pump`/`httpProc` `173-214,453-471`; `connectNow`/`disconnect` `41-72`; refresh Timer `474-485`.
- [✓] `Panel.qml` form + `serviceFor` + `statusText` — `Panel.qml:21-27,85-89,113-162` (`serviceFor`, `fittedContentWidth(Style.space(320))`, IP/email/password `password: true`, Connect, bound `sessionStatus`); title `Control4`; Escape/Tab/`manageIpc: false` retained.
- [✓] `BarWidget.qml` `serviceFor` + tooltip; chip stays `C4` — `BarWidget.qml:13-19,69-74,91-92`.
- [✓] `README.md` LAN-only, secrets path, OS 4.2, copy list includes `Service.qml` + `DirectorClient.js`, restart-shell note — `README.md:11-21,44-68,88-89`.
- [✓] Live plugin dir copy (not symlink) — `cmp` identical for LICENSE, README.md, manifest.json, BarWidget.qml, Panel.qml, Service.qml, DirectorClient.js; live path is a real directory; no symlinks inside.
- [✓] `tests/director-client.test.js` — HTTP split, account/director token parse, object-vs-array `controllerCommonName`, 200/401 classify, curl argv without password; ledger: `node tests/director-client.test.js` → `ok`.

## Open items (if any)

None.

## Audit notes

None.
