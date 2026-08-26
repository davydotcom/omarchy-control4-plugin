---
title: In-process Director REST
slug: in-process-director-rest
type: decision
status: accepted
domain: engineering
created: 2026-08-21
tags: [omarchy, control4, networking]
relates-to:
  - control4-focused-room-remote
  - director-session
  - stream-curl-transport
---
# In-process Director REST

## Context

The Control4 Omarchy plugin needs a Director client. Community integrations often use Python (`pyControl4`) or Home Assistant as a proxy. Omarchy plugins share the long-running Quickshell, run unsandboxed, and must not start a second Quickshell process.

The original wording was "QML/JS + Qt Network." First-party Omarchy HTTP is not QML `XMLHttpRequest` and not a Qt Network QML API. It is Quickshell `Process` + `curl` (`/usr/share/omarchy/shell/plugins/panels/weather/Panel.qml`). `XMLHttpRequest` cannot ignore the Director's self-signed certificate (pyControl4 uses `TCPConnector(verify_ssl=False)`).

## Options considered

- **Quickshell `Process` + short-lived `curl`** (weather pattern). Matches this shell; `-k` covers self-signed Director certs; TLS verify stays on for `apis.control4.com`.
- **QML `XMLHttpRequest`.** Cannot disable TLS verify for the LAN Director.
- **Qt Network QML APIs.** Not what first-party plugins use here; would diverge from weather for no gain.
- **Home Assistant as required proxy.** Extra runtime the user may not have; makes this an HA widget, not a Control4 plugin.
- **Python sidecar / pyControl4 process.** A second long-running process; awkward to supervise from a bar widget and conflicts with the "no second Quickshell" spirit of the contract.

## Decision

Talk to Control4 in-process via QML/JS driving short-lived `curl` through Quickshell `Process`. Cloud APIs (`apis.control4.com`): TLS verify on. LAN Director (`https://<ip>/api/v1/...`): `-k` required. No HA dependency and no Python sidecar.

Nothing that is pure transport touches disk. The whole request — URL, repeated headers, and body — is written to `curl -K -` over **stdin**, so no password, bearer token, or navigator JWT ever appears in `Process.command` argv. The response body streams back on stdout through a bounded pipe (`head -c` at `MAX_RESPONSE_BYTES + 1`), so an oversized LAN/cloud/nav payload is truncated and rejected rather than retained in the long-lived shell; `--max-filesize` still aborts early when the response declares an oversized `Content-Length`. The HTTP status (`%{stderr}%{http_code}`) and curl's own exit code arrive as markers on stderr, which the pipe does not carry.

The curl command array is a compile-time constant with zero interpolation — that is what makes wrapping it in `sh -c` acceptable, and it is an invariant, not an incidental detail. Every per-request value goes over stdin. The shell's `umask 077` means any file curl itself creates (the navigator cookie jar) is mode 0600 at creation.

Only genuine cross-restart state is persisted: `credentials.json` and `focus.json` (both 0600, in a 0700 state dir), plus the navigator cookie jar, which is removed on disconnect. Never log tokens or passwords.

**Amended** by `stream-curl-transport` (2026-08-25), which replaced the original 0600 body/header temp files and `-o` response files with the stdin-config transport above. The rest of this decision — in-process `Process` + `curl`, `-k` for the LAN Director, TLS verify on for the cloud, no sidecar — is unchanged.

## Consequences

`director-session` implements this in a `keepLoaded` `service` kind. If in-process curl proves insufficient, that is a new initiative — not a silent sidecar.
