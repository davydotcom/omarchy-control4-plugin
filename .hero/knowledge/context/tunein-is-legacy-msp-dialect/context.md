---
title: TuneIn is a legacy MSP dialect, not Apple Music's
slug: tunein-is-legacy-msp-dialect
type: context
status: active
domain: engineering
created: 2026-08-23
tags: [omarchy, control4, tunein, navigator, msp]
relates-to:
  - listen-library-browse
  - msp-browse-needs-navigator-session
  - apple-music-browse-not-on-rest
---
# TuneIn is a legacy MSP dialect, not Apple Music's

## Overview

Both Apple Music and TuneIn browse over the same navigator session
(`msp-browse-needs-navigator-session`): socket.io `OnDataToUI`, PROTOCOL commands
carrying `NAVID` / `SEQ` / `ROOMID` / XML `ARGS`. The *commands themselves differ*.
TuneIn is `TuneIn (Legacy, OS2)`, driver version 131.

## The two dialects on this Director

| | Apple Music, Amazon Music, SiriusXM | TuneIn |
|---|---|---|
| driver.xml | `/c4z/apple-music/driver.xml` | `/c4z/TuneIn/driver.xml` (case-sensitive) |
| Tabs | `<Tabs><Command><Name>GetTabList</Name>` — dynamic | `<Tabs><Tab><Name>…</Name><ScreenId>…</ScreenId>` — static in XML |
| List | `Browse` + `screenId` / `tabId` / `offset` / `limit` | `GetBrowseMenu` + `screen` / `URL` |
| Tap | `SelectItem`, then `Play` / `PlayStation` | `BrowseCommand` with the row's own properties |
| Row title | `title` | `text` |
| Row is a folder | `isLink` / `itemType` | `folder` |

TuneIn's `<Tabs>` are **Browse** and **My Favorites**. `Settings` is a screen but not a tab.

TuneIn row properties: `text`, `subtext`, `folder`, `is_header`, `URL`, `type`, `key`,
`item`, `guide_id`, `is_preset`, `image`, `default_action`, `actions_list`.
Section rows arrive as `{ is_header: true, text: "FM" }` with no URL — render them, don't tap them.

`BrowseCommand` mirrors the driver's `Browse` action params:
`screen`, `type`, `URL`, `guide_id`, `item`, `is_preset`, `key`, `text`, `image`.
On a **folder** it answers `{ "NextScreen": "Browse" }` and plays nothing; calling
`GetBrowseMenu` with `screen` + the row's `URL` gets the child list directly and
skips that round trip. On a **station** it starts playback.

## Selecting the room is a separate, slower step

`SELECT_AUDIO_DEVICE` with `{ deviceid: 10 }` on the room and `BrowseCommand` fired
back to back is a **race** — the station lands in TuneIn's queue but the room keeps
playing whatever it had. Give the select time to land (in the panel the user spends
seconds drilling into a folder, so this is not a problem in practice).

Confirm with room variables, not `media_sessions`:

- `CURRENT_AUDIO_DEVICE` tracks the digital-media player (`100002` here), not the service.
- `PLAYING_AUDIO_DEVICE` is the service actually playing — this is the one to read.
- After a good play, `/api/v1/media_sessions` shows `deviceid: 100002` with `medSrcDev: 10`.

## Do not

- Assume a media service speaks Apple Music's dialect. Read its `driver.xml` `<Tabs>` block first.
- Lowercase the driver path. `/c4z/tunein/driver.xml` is a 404; `/c4z/TuneIn/driver.xml` is the file.
