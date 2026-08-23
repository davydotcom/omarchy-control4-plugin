---
title: Director session
slug: director-session
type: feature
status: completed
domain: engineering
size: medium
horizon: now
parent: control4-focused-room-remote
depends-on:
  - plugin-scaffold
created: 2026-08-21
tags: [omarchy, control4]
relates-to:
  - in-process-director-rest
  - control4-os42-local-jwt-401
completed_at: 2026-08-22T01:53:21Z
---
# Director session

## Context

Second child of `control4-focused-room-remote`. `plugin-scaffold` is completed: plugin ID `io.github.davydotcom.control4`, files at repo root (`manifest.json`, `BarWidget.qml`, `Panel.qml`, `README.md`, `LICENSE`), live copy at `~/.config/omarchy/plugins/io.github.davydotcom.control4/`. The `C4` chip is on the right bar; the nested panel currently shows **Not connected**.

This child adds a headless `service` that authenticates with Control4 customer email/password, mints a director bearer JWT (pyControl4 `account.py` endpoints, copied exactly), and probes the LAN Director. Later children (`focused-room` and after) must call `directorGet` / `directorPost` on this service — they must not open their own HTTP.

OS 4.2 rejecting the same JWT on local `/api/v1/*` is a documented incompatibility ([pyControl4 #66](https://github.com/lawtancool/pyControl4/issues/66), knowledge `control4-os42-local-jwt-401`), not a workaround target. Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`. REST decision: `.hero/knowledge/decisions/in-process-director-rest/spec.md`.

## Goal

The plugin signs in with customer email/password plus a user-typed controller IP, keeps a director JWT in a `keepLoaded` `service`, and shows connected vs auth-failed vs error on the nested panel. HTTP is short-lived Quickshell `Process` + `curl` (Omarchy weather pattern). Credentials persist only under `$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json` — never in `shell.json`. JWT is in-memory only. A LAN 401 is a distinct, non-retrying auth-failed state with OS 4.2 copy. `directorGet` / `directorPost` exist for later children even though this panel only probes.

## Kickoff

Director JWT session: curl+Process HTTP, credentials on disk (not shell.json), keepLoaded service, connected vs 401 on the panel.

**Status:** completed — service loads; panel form ships; LAN Connected still needs the user's Director.

**Pick up at:** `/design focused-room` — rooms from `ui_configuration`, persist focus, chip shows the name.

→ `/design focused-room`

**Files:** `.hero/planning/features/focused-room/spec.md`, `Service.qml`, `Panel.qml`, `BarWidget.qml`

**Skip:** XMLHttpRequest, Python sidecar, password in shell.json, OS 4.2 JWT workaround.

## Approach

**HTTP — Omarchy weather, not XMLHttpRequest, not Python.** Accepted decision `in-process-director-rest` said QML/JS + Qt Network. In this shell, first-party HTTP is Quickshell `Process` + `curl` (`/usr/share/omarchy/shell/plugins/panels/weather/Panel.qml`: `command: ["curl", "-fsS", "--max-time", "10", url]`, `StdioCollector`, set `command` then `running = true`). QML `XMLHttpRequest` cannot ignore the Director's self-signed cert (pyControl4 uses `TCPConnector(verify_ssl=False)`). This is not a Python sidecar and not a long-running second process. `curl` is on PATH in Omarchy.

Lock:

- Cloud Control4 APIs (`apis.control4.com`): `curl -fsS --max-time 10` **with TLS verify**.
- LAN Director `https://<ip>/api/v1/...`: `curl -kfsS --max-time 10` (**`-k` required**).
- Always append `-w "\n%{http_code}"` so 401 is distinguishable from other 4xx/5xx (`-f` maps those to exit 22). Parse the last line as the status; the rest is the body. If `-f` swallows the status line, drop `-f` and keep `-sS` / `-k` / `--max-time 10` — those three are the invariant.
- Password and JSON bodies MUST NOT appear in `Process.command` argv (`ps` leak). Write POST body with `FileView.setText` to a 0600 temp file in the plugin state dir, pass `--data-binary @path`, then `rm -f` that file. Bearer token in `-H` is residual same-user `/proc` risk; acceptable under the unsandboxed plugin threat model. **Never** `console.warn` tokens, passwords, `Process.command`, or credentials-file contents.
- Serialize HTTP on one (or a small fixed set of) `Process` object(s). Do not fire overlapping curls that share a Process.

**Auth flow — copy pyControl4 `account.py` endpoints exactly.** `APPLICATION_KEY` is a public client key from pyControl4, not a user secret. Live in `DirectorClient.js`: `78f6791373d61bea49fdb9fb8897f1f3af193f11`.

1. POST `https://apis.control4.com/authentication/v1/rest`  
   Body:
   ```
   { "clientInfo": { "device": { "deviceName": "pyControl4", "deviceUUID": "0000000000000000", "make": "pyControl4", "model": "pyControl4", "os": "Android", "osVersion": "10" }, "userInfo": { "applicationKey": APPLICATION_KEY, "password": "<password>", "userName": "<email>" } } }
   ```
   Read `authToken.token` as the **account** bearer.

2. GET `https://apis.control4.com/account/v3/rest/accounts` with `Authorization: Bearer <account>`  
   Parse `account`: if object, use its `controllerCommonName`; if array, use the first element's `controllerCommonName`.

3. POST `https://apis.control4.com/authentication/v1/rest/authorization` with the account bearer  
   Body: `{ "serviceInfo": { "commonName": "<controllerCommonName>", "services": "director" } }`  
   Read `authToken.token` (director JWT) and `authToken.validSeconds` (usually 86400). Default `validSeconds` to 86400 if missing.

4. Probe LAN: GET `https://<controllerIp>/api/v1/agents/ui_configuration` with `Authorization: Bearer <director token>` and curl `-k`.
   - HTTP 200 → `connected`
   - HTTP 401 → `auth-failed` with copy that this is expected on Control4 OS 4.2. **Do not retry-loop.**
   - Other network / TLS / timeout / unexpected HTTP → `error`, distinct from `auth-failed` and from `unconfigured`.

Cloud login failure (bad password, missing token in JSON) is also `auth-failed`, with panel copy **Sign-in failed** (not the OS 4.2 Director sentence).

User types the controller IP (Home Assistant pattern; static IP). Do **not** discover IP from cloud. Use the typed value as the host in `https://<controllerIp>/...` (hostname is acceptable if the user types one).

**Service kind.** Add `service` to `kinds` **before** `bar-widget` (media plugin order: `["service", "bar-widget"]`). `entryPoints.service`: `"Service.qml"`. `keepLoaded: true` (media plugin). Shell loads enabled third-party services via `_syncServices` (`/usr/share/omarchy/shell/shell.qml`). The plugin is already enabled because the C4 chip is in the bar (`isEnabled` is true when the id is in bar layout).

The nested Panel is loaded by BarWidget, **not** by the shell's panel Instantiator, so the shell will **not** inject `item.service`. Widget and panel MUST look up:

```
bar.shell.serviceFor("io.github.davydotcom.control4")
```

Use `serviceFor`, not `firstPartyServiceFor` (they alias today; `serviceFor` is the third-party API). `ensureService` injects `shell` onto Service.qml if the property exists. Service.qml: `property var shell: null`.

**State (on Service.qml — later children depend on this).**

Machine: `unconfigured | connecting | connected | auth-failed | error`

- `statusText` / `lastError` for the panel.
- `controllerIp` (and email for the form; password field is write-only in the UI after load — keep it on the service in memory after reading the file, never log it).
- In-memory director JWT only. **Do not persist JWT.** Persist `{ controllerIp, email, password }` only.
- `function connectNow()` — persist credentials, run the four-step flow.
- `function disconnect()` — clear tokens and stop the refresh timer; stay configured unless the user clears fields.
- `function directorGet(path, callback)` and `function directorPost(path, command, params, callback)` for later children. POST body shape: `{ "async": true, "command": command, "tParams": params }` (pyControl4 `director.py`). Implement both in this child even if the panel only uses the GET probe. Later children must not open their own HTTP. If there is no director JWT, invoke the callback with an error; do not start a login from these helpers.
- Refresh: `Timer` at 80% of `validSeconds`. Re-run the full account→director flow (steps 1–3), then keep using the existing probe/connected path. If refresh 401s, go `auth-failed` and **stop the timer** — do not spin.

`statusText` mapping:

| State | Typical `statusText` |
|---|---|
| `unconfigured` (missing ip, email, or password) | Not configured |
| `unconfigured` (credentials present, no JWT — after `disconnect()` or before auto-connect) | Not connected |
| `connecting` | Connecting… |
| `connected` | Connected |
| `auth-failed` (cloud / bad password) | Sign-in failed |
| `auth-failed` (LAN probe HTTP 401) | Director rejected the session (HTTP 401). This is expected on Control4 OS 4.2. |
| `error` | `lastError` network/TLS/timeout text (no secrets) |

On Service start: mkdir the state dir; load credentials; if the file has ip+email+password, auto-connect.

**Credentials storage — not shell.json.** Do not put password in `barWidget.schema` / `shell.json` (that file is the bar layout and more likely copied).

Path: `$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json`  
(`Quickshell.env("HOME")` + `/local/state/omarchy/io.github.davydotcom.control4/credentials.json`)

Contents: `{ "controllerIp", "email", "password" }` only (no JWT).

- `mkdir -p` via Process — notifications pattern: `command: ["mkdir", "-p", stateDir]` (`/usr/share/omarchy/shell/plugins/notifications/Service.qml` `ensureDirsProc`).
- `FileView` with `atomicWrites: true`, `printErrors: false` (clipboard / notifications). Write with `setText(JSON.stringify(...) + "\n")`.
- After each write, `chmod 600` via Process (`command: ["chmod", "600", path]`) — `atomicWrites` may replace the inode.
- Never log file contents.

**Panel form** (`qs.Ui` `TextField`; password field uses `password: true` — `/usr/share/omarchy/shell/Ui/TextField.qml`). Connect is `qs.Ui` `Button`.

- Controller IP
- Email
- Password
- Connect button
- Status line replaces scaffold "Not connected" using `statusText` above.

Keep title `Control4`. Chip stays `C4`. Tooltip may include status (`Control4 — Connected`). No room list, no Watch/Listen.

Widen the panel (`fittedContentWidth(Style.space(320))` or similar). Escape still closes.

**JS vs QML.** `DirectorClient.js` owns JSON build/parse for the three cloud steps + probe classification, `APPLICATION_KEY`, account object-vs-array, POST command body `{ async, command, tParams }`, and curl argv **templates** that never embed password or JSON body (those go via `@file` / headers assembled in QML from in-memory token). `Service.qml` owns Process, FileView, Timer, state machine, credential IO. Keep QML thin.

**Live copy.** After git-root files are written, copy them into `~/.config/omarchy/plugins/io.github.davydotcom.control4/` and `omarchy-shell shell rescanPlugins` (same delivery step as scaffold). Validate the live folder, not the git root.

## Changes

1. `manifest.json` — add `keepLoaded: true`; set `kinds` to `["service", "bar-widget"]`; add `entryPoints.service`: `"Service.qml"`; leave `entryPoints.barWidget` as `"BarWidget.qml"`. Do not add `barWidget.schema` or any password field.
2. `DirectorClient.js` (new, repo root) — `APPLICATION_KEY`; builders for the two cloud POST bodies; parsers for account-token, `controllerCommonName` (object or array), director-token + `validSeconds`; probe/status classification from HTTP code; `directorPost` JSON `{ "async": true, "command": command, "tParams": params }`; helpers to split curl stdout into body + trailing `http_code`. No Process objects here.
3. `Service.qml` (new, repo root) — headless `Item`: `property var shell: null`; state machine and `statusText` / `lastError` / `controllerIp`; credential mkdir + FileView + chmod 600; serialized curl `Process` (cloud verify, LAN `-k`); temp-file POST bodies; `connectNow()` / `disconnect()`; refresh Timer at 80% of `validSeconds`; `directorGet(path, callback)` and `directorPost(path, command, params, callback)`; auto-connect on start when the credentials file is complete. Import `Quickshell`, `Quickshell.Io`, and `DirectorClient.js`.
4. `Panel.qml` — look up `bar.shell.serviceFor("io.github.davydotcom.control4")`; replace the static "Not connected" line with the form (IP, email, password `TextField` with `password: true`, Connect `Button`) and bound `statusText`; widen with `fittedContentWidth(Style.space(320))` or similar; keep title `Control4`, Escape-to-close, Tab `switchPanel`, `manageIpc: false`. Connect calls `connectNow()` after copying field values onto the service. Do not talk to curl from the panel.
5. `BarWidget.qml` — `serviceFor` lookup (same id); optional tooltip from session state (`Control4 — Connected` / current `statusText`); chip text stays `C4`. Still Loader → `Panel.qml` with existing injectPanel / open / close / opened / popout-switch forwards.
6. `README.md` — LAN-only; customer email/password + controller IP; secrets path `$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json`; OS 3.x happy path vs OS 4.2 local JWT 401 (no workaround). No example password. Local develop copy list now includes `Service.qml` and `DirectorClient.js` (plus the previous five). Rescan after copy. Still do not `omarchy plugin add` this dirty checkout.
7. Live plugin dir `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/` — copy the updated/new files (not a symlink) and `omarchy-shell shell rescanPlugins`. Same rule as scaffold. After adding a **new** `.qml` file (e.g. first `Service.qml`), also `omarchy restart shell` — Qt's directory listing cache otherwise reports `File name case mismatch` (see knowledge `qml-new-file-shell-restart`).
8. `tests/director-client.test.js` — Node parser tests for HTTP split, account/director token parse, object-vs-array `controllerCommonName`, 200/401 classification, curl argv templates without password.

## Boundaries

- No rooms, Watch/Listen, volume, now-playing
- No OS 4.2 workaround / jailbreak / 4Sight / Home Assistant / Python sidecar
- No password in `shell.json` or `barWidget.schema`
- No XMLHttpRequest-only design that cannot `-k` the Director
- No long-running second process
- No persisting the director JWT
- No discovering controller IP from cloud
- No retry loop on 401
- Permanent ID rename is still out of scope

## Risks

- curl `-k` is MITM-able on LAN; accepted because Director certs are self-signed (pyControl4).
- `APPLICATION_KEY` is a public client key; if Control4 revokes it, login breaks for all pyControl4/HA users too.
- `get_account_controllers` / accounts payload shape (object vs array) is messy — handle both in `DirectorClient.js`.
- Service is not loaded if the plugin is disabled; the C4 chip already enables it. Nested panel does not get `item.service` injected — missing `serviceFor` lookup looks like "Not configured" forever.
- Live dir vs git desync (same as scaffold). Always copy after editing; validate the live folder.
- POST body or password in `Process.command` would leak via `ps` / `/proc`. Temp file + `--data-binary @path` is mandatory for bodies.
- Token in `-H` is visible in same-user `/proc/<pid>/cmdline` for the curl lifetime. Do not log it. Do not put it in the credentials file.
- Refresh without stopping the timer on 401 will spin. Stop the timer on `auth-failed` and `error`.

## Acceptance Criteria

- WHEN the user saves controller IP plus Control4 customer email and password THE SYSTEM SHALL obtain a director bearer JWT and GET `/api/v1/agents/ui_configuration` on the LAN Director with that token
- WHILE the JWT session is valid THE SYSTEM SHALL keep it in the headless `service` so closing the panel does not drop the session
- IF the LAN Director probe returns HTTP 401 THEN THE SYSTEM SHALL enter `auth-failed` with copy that this is expected on Control4 OS 4.2, distinguishable from `unconfigured`, and SHALL NOT retry-loop
- IF cloud sign-in fails THEN THE SYSTEM SHALL enter `auth-failed` with copy `Sign-in failed`, distinguishable from `unconfigured` and from the Director 401 copy
- IF the Director call fails for network, TLS, or timeout reasons THEN THE SYSTEM SHALL enter `error`, distinguishable from `auth-failed` and from `unconfigured`
- THE SYSTEM SHALL perform HTTP via short-lived Quickshell `Process` + `curl` (no Python sidecar, no Home Assistant proxy, no QML `XMLHttpRequest` as the Director client)
- WHEN the LAN probe returns HTTP 200 THE SYSTEM SHALL show a connected state on the details panel
- THE SYSTEM SHALL persist credentials only at `$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json` and SHALL NOT write password or JWT into `shell.json`
- THE SYSTEM SHALL expose `directorGet` (and `directorPost` with `{ async, command, tParams }`) on the service for later children
- WHEN the service starts and the credentials file contains ip, email, and password THE SYSTEM SHALL auto-connect
- THE SYSTEM SHALL refresh the director JWT at 80% of `validSeconds` by re-running the account→director flow; IF that refresh returns 401 THEN THE SYSTEM SHALL go `auth-failed` and SHALL NOT spin
- THE SYSTEM SHALL NOT place password or JSON request bodies in `Process.command` argv

## Validation

`OMARCHY_PATH` on this machine is `/usr/share/omarchy`. Run against the **live** folder, not the git root. There is **no Director in CI**; the OS 3.x happy path is **manual on the user's LAN**.

```
PLUGIN_ID=io.github.davydotcom.control4
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/Service.qml" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
# If qmllint accepts JS:
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/DirectorClient.js"
omarchy plugin list --json | jq --arg id "$PLUGIN_ID" '.[] | select(.id == $id)'
```

`omarchy plugin validate` must see the `service` entry point file. `omarchy plugin list` must still show id `io.github.davydotcom.control4`, enabled.

Manual (LAN):

1. Unconfigured form: empty/missing credentials → panel **Not configured** (not a hang, not auth-failed).
2. Connect with a bad password → **Sign-in failed** (`auth-failed`), no retry loop.
3. OS 3.x happy path (user's LAN Director only): save real IP + email + password → panel **Connected**; close the panel; reopen — still connected (service kept the session). Confirm `credentials.json` exists at the state path with mode 600 and that `~/.config/omarchy/shell.json` has no password.
4. OS 4.2 (if present): cloud login may succeed and LAN probe 401 → the Director-rejected sentence, no retry loop.

Do not invent a CI Director. Do not put an example password in README or tests.
