---
title: MSP browse needs a navigator session
slug: msp-browse-needs-navigator-session
type: decision
status: accepted
domain: engineering
created: 2026-08-23
tags: [omarchy, control4, apple-music, navigator]
relates-to:
  - in-process-director-rest
  - listen-library-browse
  - apple-music-browse-not-on-rest
---
# MSP browse needs a navigator session

## Context

Listen → Apple Music should list personal stations / playlists. Item and room REST do not return that catalog (`apple-music-browse-not-on-rest`). The user asked to implement the Control4 navigator / Media Service Proxy (MSP) path instead.

Live Director: Apple Music protocol 433 / proxy 434 (`media_service.c4i`, binding 5001). Driver XML is at `GET /c4z/apple-music/driver.xml`.

## Options considered

- **More `/api/v1/items/{id}/commands` POSTs** (`Browse`, `GetTabList`, `GetItemList`, `async` true/false, with `NAVID`/`SEQ`/`ROOMID`/`ARGS`). HTTP body is always empty `SendToDevice`. The Lua driver replies later via `C4:SendToProxy(..., 'DATA_RECEIVED', { NAVID, SEQ, DATA })` to a navigator, not to the REST caller.
- **Treat Composer `CUSTOM_SELECT:GetItemList` as a GET.** Composer-only Lua callback. No REST collection. Invented `/custom_select` paths 404.
- **Director `socket.io` as the list channel.** Handshake works. Namespace `/api/v1/items/datatoui` is pyControl4 item-variable push, not MSP browse. Connecting it as a socket.io namespace returns `Invalid namespace`. `GetTabList`/`Browse` POSTs do not appear on that socket.
- **Python sidecar / pyControl4 / new HTTP client.** Forbidden by `in-process-director-rest`.
- **Fake Stations / Library rows from driver.xml labels.** Violates listen-library-browse: no empty fake folders.

## Decision

MSP browse is a **navigator session**: PROTOCOL commands (`GetTabList`, `Browse`, `Play`, `PlayStation`, `SelectItem`) with `NAVID` / `SEQ` / `ROOMID` / XML `ARGS`, and XML `DATA_RECEIVED` back to that `NAVID`.

This plugin does **not** have that session. `directorGet` / `directorPost` stay source-select, volume, and now-playing. Do not ship a Listen drill-in until one in-process call returns named stations (or tabs that then Browse to named rows).

`in-process-director-rest` still stands: if a navigator session is built, it is in-process (existing curl queue or a later accepted QML/WebSocket decision), not a sidecar.

## Consequences

`listen-library-browse` stays planning until a navigator `DATA_RECEIVED` payload is in hand. Next work is that session, not Panel.qml folders.
