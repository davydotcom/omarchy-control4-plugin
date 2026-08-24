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

Talk to Control4 in-process via QML/JS driving short-lived `curl` through Quickshell `Process`. Cloud APIs (`apis.control4.com`): TLS verify on. LAN Director (`https://<ip>/api/v1/...`): `-k` required. No HA dependency and no Python sidecar. POST bodies go to a 0600 temp file (`--data-binary @path`) so passwords never appear in `Process.command` argv. Bearer and navigator JWT headers go the same way: write a 0600 header file and pass `-H @path` — never put tokens in argv. Response bodies go to `-o` (mode 600) with `curl --max-filesize`; `StdioCollector` keeps only `%{http_code}`. Refuse to load a file larger than that cap so a large LAN/cloud/nav payload cannot exhaust the long-lived shell. Never log tokens or passwords.

## Consequences

`director-session` implements this in a `keepLoaded` `service` kind. If in-process curl proves insufficient, that is a new initiative — not a silent sidecar.
