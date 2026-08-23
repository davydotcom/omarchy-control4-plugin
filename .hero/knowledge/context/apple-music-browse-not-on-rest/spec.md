---
title: Apple Music browse is not on Director REST
slug: apple-music-browse-not-on-rest
type: context
status: active
domain: engineering
created: 2026-08-23
tags: [omarchy, control4, apple-music]
relates-to:
  - watch-and-listen
  - in-process-director-rest
---
# Apple Music browse is not on Director REST

## Overview

Tapping Listen → Apple Music in this plugin POSTs `SELECT_AUDIO_DEVICE` with `{ deviceid }` on the focused room. That selects the source. It does not open songs or playlists.

## What the Director actually exposes

- Apple Music is a `DIGITAL_AUDIO_SERVER` (`id` 434 on this system, parent protocol driver 433, `MediaService` proxy binding 5001).
- The driver's Composer command is **Play Item** with `CUSTOM_SELECT:GetItemList` filters `albums` / `songs` / `playlists` / `stations`, plus Room and Shuffle. That list is for Composer programming, not a documented GET.
- POSTing `GetItemList`, `BROWSE` (any `loc`), `Play Item`, `CUSTOM_SELECT`, etc. to `/api/v1/items/{433|434}/commands` returns `{ "name": "SendToDevice", "result": 1, "$t": "" }` — fire-and-forget into the Lua driver, no catalog payload.
- Room command `SELECT_AUDIO_MEDIA:PLAYLIST` reads `GET /api/v1/locations/rooms/{id}/media/albums/playlists`. That is the **local** Control4 media database. On this Director it is `[]`. It is not the Apple Music library.
- `GET /api/v1/locations/rooms/{id}/media` lists listen devices (including Apple Music) but has no nested tracks.
- `GET /api/v1/media_sessions` **does** work. A live session for Apple Music on Deck (`deviceid` 434, `roomids` [15]) returns volume, mute, and `mediainfo` (e.g. song title/artist/album/art). Commands on `/api/v1/media_sessions/{id}/commands` are session/volume/mute only (`GET_SESSION`, `SET_VOL_LEVEL`, `TOGGLE_MUTE_STATE`, …). There is **no BROWSE / stations / playlists** command. `GET .../browse` and `.../stations` are 404.
- `GET /api/v1/agents/media_sessions` is 404. Sessions live at `/api/v1/media_sessions`, not under agents.
- `async: false` on `GetItemList` still returns empty `SendToDevice`. Same for invented GETs (`/GetItemList`, `/customselect/GetItemList`, `/commands/Play Item`).
- Item 434 capabilities: `HasGeneratesStartMediaDialog: true`, `can_scan_media: false`, `can_select: false`, `hide_in_media: true`, `ui_selects_device: false`. Browse is a navigator start-media dialog, not a REST catalog.
- Room listen devices list Apple Music as one `DIGITAL_AUDIO_SERVER` (434). There is no nested Stations/Library device.
- `GET /api/v1/agents/history` is Identity/auth events, not media. Recently Played Manager and Halo Remote Hub have no REST collection under `/api/v1/agents/{name}`.

Composer **Play Item** lists filter names `albums` / `songs` / `playlists` / `stations` (personal stations would be that last filter). Hydrating the list is not on this REST.

The Control4 app / Halo Listen browser talks to the media-service proxy (navigator), not these item or media_session REST calls.

Live follow-up (user asked to implement MSP anyway):

- Driver XML: `GET /c4z/apple-music/driver.xml`. CollectionScreen `DataCommand` is `Browse`. Tabs are `GetTabList` (not hardcoded). Play actions include `PlayStation`.
- POSTing `GetTabList` / `Browse` with `NAVID`/`SEQ`/`ROOMID`/`ARGS` is still empty `SendToDevice`. Results are `DATA_RECEIVED` to a navigator session this plugin does not have.
- Director `socket.io` handshake works; `/api/v1/items/datatoui` is item-variable push (`Invalid namespace` if treated as a socket.io namespace). Not the browse list.
- Decision: `msp-browse-needs-navigator-session`.

## Do not

- Invent a folder UI that cannot load rows.
- POST unknown driver **Actions** (`Logout`, `GetLinkForAPIAuthentication`, …) on a live Director while probing. Those are installer actions, not browse.
- Put Apple Music passwords or JWTs in `curl` argv (`-d`). Use the existing body-file queue.
