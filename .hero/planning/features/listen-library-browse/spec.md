---
title: Listen library browse
slug: listen-library-browse
type: feature
status: delivering
domain: engineering
size: medium
horizon: now
parent: control4-focused-room-remote
depends-on:
  - watch-and-listen
created: 2026-08-23
tags: [omarchy, control4, apple-music]
relates-to:
  - apple-music-browse-not-on-rest
  - tunein-is-legacy-msp-dialect
  - room-now-playing
  - msp-browse-needs-navigator-session
---
# Listen library browse

## Context

User: tapping Listen **Apple Music** should let them pick songs or playlists. `watch-and-listen` only POSTs `SELECT_AUDIO_DEVICE`. That is source-select, not a library. Live probe on this Director (item 434 / parent 433) is in knowledge `apple-music-browse-not-on-rest`.

## Goal

After Listen selects Apple Music, the panel shows that account's **personal stations**, playlists, and songs, and playing one goes through the existing Director session into the focused room. Not a fake folder. Not Apple's public Music API.

## Kickoff

After Listen → Apple Music, pick a personal station, playlist, or song in the focused room.

**Status:** delivering — Apple Music browse/play works. TuneIn now works too, over a second, older MSP dialect (`tunein-is-legacy-msp-dialect`): static driver.xml tabs, `GetBrowseMenu` lists, `BrowseCommand` taps. Verified live: Listen → TuneIn → Browse → Local Radio → **90.1 WFYI** played in the Office (`PLAYING_AUDIO_DEVICE=10`).

**Pick up at:** Amazon Music (436) and SiriusXM (438) both declare `GetTabList`, so they should ride Apple Music's existing path with only a detection change — untested.

→ `/deliver listen-library-browse`

**Files:** `DirectorClient.js`, `Service.qml`, `Panel.qml`

**Skip:** Apple Music web API; fake trees from driver.xml labels; posting driver Actions (`Logout`, …); Python sidecar.

## Approach

**Protocol (locked):** Apple Music is MSP. Driver UI is `GET /c4z/apple-music/driver.xml`. Halo/app sends PROTOCOL commands on proxy 434:

- `GetTabList` — dynamic tabs (Stations / Library / …)
- `Browse` — `CollectionScreen` list; ARGS include `screenId`, `tabId`, `id`, `itemType`, `offset`, `limit`
- `Play` / `PlayStation` / `SelectItem` — play or drill in

Each command carries `NAVID`, `SEQ`, `ROOMID`, XML `ARGS`. The driver answers with `DATA_RECEIVED` `{ NAVID, SEQ, DATA }` to that navigator. `POST /api/v1/items/434/commands` with those fields still returns empty `SendToDevice` — REST is fire-and-forget into Lua.

**List path (locked, live):** engine.io/socket.io on the Director (`GET/POST /socket.io/?EIO=4&transport=polling` with `-k` + Bearer + `JWT`). After `clientId`, `GET /api/v1/items/datatoui?SubscriptionClient=` then `42["startSubscription", subId]`. `POST /api/v1/items/{proxyId}/commands` `GetTabList` / `Browse` / `SelectItem` / `PlayStation` with `NAVID=clientId`, `ROOMID=focusedRoomId`, `SEQ`, ARGS as `<arg name="tabId">Stations</arg>`. The list is `OnDataToUI` on that socket (`iddevice` 434), not the HTTP body.

Live Stations list included **My Personal Station** → **David Estes’ Station** (`PlayStation`).

**Once that payload exists (lock the exact call here before coding):**

1. Listen tap on a browsable `DIGITAL_AUDIO_SERVER` still `SELECT_AUDIO_DEVICE`, then replace the source list with GetTabList / Browse rows.
2. Play uses `Play` or `PlayStation` with the row ids plus `ROOMID=focusedRoomId`. Confirm with one live POST.
3. Back returns to the Listen source list.
4. Sources that are not browsable stay tap-to-select.

Until then this spec stays planning.

## Changes

1. `DirectorClient.js` — MSP parsers (`parseMspResponse`, `parseMspTabs`, `parseMspList`, `mspArgXml`, `curlNavArgs`, `isAppleMusicItem`) plus the TuneIn dialect (`isTuneInItem`, `driverXmlPath`, `parseTuneInTabs`, `parseTuneInList`, `tuneInTapArgs`).
2. `Service.qml` — in-process engine.io poll (`navProc`), `openMspBrowse` on a media-service tap, `_loadTuneInTabs` / `_tuneInBrowse` / `_tuneInTap`, `browseTap` / `browseBack`.
3. `Panel.qml` — Back + browse rows when `browseOpen`; TuneIn `is_header` rows render muted.
4. `tests/director-client.test.js` — parser coverage for both dialects.

## Boundaries

- No Apple catalog/token outside Director
- No Spotify/Amazon/SiriusXM until each is tested live (TuneIn shipped)
- No search box in the first slice unless the list API requires a query
- No now-playing transport (sibling `room-now-playing`)
- Do not POST driver Actions while exploring

## Risks

- Probing `Logout` / auth actions on the live Apple Music driver can drop the house login.
- `SendToDevice` empty body looks like success and is not a catalog.
- Local playlist REST is the wrong library.
- Driver.xml tab/action *names* (Stations, Playlists) are UI chrome, not the user's stations. Rendering those without Browse rows is a fake folder.

## Acceptance Criteria

- WHEN the user opens Apple Music from Listen THE SYSTEM SHALL show personal stations, playlists, and/or songs from the Director, not only the device name
- WHEN the user picks a playlist or song THE SYSTEM SHALL play it in `focusedRoomId` through existing `directorPost`
- IF the source has no browse catalog THE SYSTEM SHALL keep tap-to-select (no empty fake folders)
- THE SYSTEM SHALL NOT call Apple's public Music API or a new HTTP client

## Validation

A GET or sync POST must return at least one named playlist or song for Apple Music on the live Director before UI work. Then: Listen → Apple Music → pick a playlist → Deck (or focused room) plays it. `node tests/director-client.test.js` still passes.
