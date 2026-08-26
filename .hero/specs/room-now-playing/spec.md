---
title: Room now playing
slug: room-now-playing
type: feature
status: completed
domain: engineering
size: small
horizon: now
priority: medium
parent: control4-focused-room-remote
depends-on:
  - focused-room
relates-to:
  - watch-and-listen
  - room-volume-mute-off
  - watch-remote-lost-on-reopen
  - halo-panel-chrome
  - halo-remote-panel-style
  - back-off-buttons-look-disabled
created: 2026-08-21
tags: [omarchy, control4]
claimed_by: david-estes
claimed_at: 2026-08-23T17:03:05-04:00
completed_at: 2026-08-23T21:06:12Z
---
# Room now playing

## Context

Last open child of `control4-focused-room-remote`. Watch/Listen, volume/mute/Off, Halo chrome, and Watch-remote restore already shipped. The Director poll those specs share already reads `POWER_STATE`, `CURRENT_VIDEO_DEVICE`, `PLAYING_AUDIO_DEVICE`, and `LAST_DEVICE_GROUP` (`watch-remote-lost-on-reopen`). `Service.qml` already stashes `roomOn` and the device ids. The bar chip in the working tree already draws `icon.png` / `icon-off.png` from `roomOn`.

What is still missing: a Halo-style now-playing *readout* (source name, not a greyed-out control), Off reflecting power without looking disabled, and the chip tooltip naming the source so an icon-only mark still answers “what’s on.” Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`.

## Goal

The focused room’s power and current Watch/Listen source are legible without spelling the room name on the bar. The chip is a Control4 mark (on / off / not-connected). The panel status line and the chip tooltip name the playing source, or Off. Off stays pressable and reads as the selected state when the room is off.

## Kickoff

Show room on/off on the Control4 mark and name the playing source in the panel status line and tooltip.

**Status:** completed — mark, status line, and Off reflection shipped.

**Pick up at:** glance the live bar: Off → white mark and `Off`; Watch a source → 4-Ball and `Watch · <name>`.

→ done

**Files:** `DirectorClient.js:434`, `Service.qml:84`, `Panel.qml:47`, `BarWidget.qml:18`, `tests/director-client.test.js:332`

**Skip:** `media_sessions` / artwork; a second poll; websocket; putting the room or source name on the chip; restyling Off as muted.

## Approach

**Do not add a poll.** `refreshVolume` already GETs `CURRENT_VOLUME,IS_MUTED,POWER_STATE,CURRENT_VIDEO_DEVICE,PLAYING_AUDIO_DEVICE,LAST_DEVICE_GROUP` every 2s. Parse stays `DirectorClient.parseRoomVolume`. This child only *displays* `power` and a resolved source name.

**Resolve the source name** in `DirectorClient.nowPlayingLabel(parsed, items, watchSources, listenSources)`:

- If `parsed.power === false` → `""` (caller shows Off; never a stale name).
- If `parsed.lastDeviceGroup === "listen"` → name of `playingAudioDeviceId` from `listenSources`, else `_items`. Never `CURRENT_AUDIO_DEVICE` (that is the digital-media player `100002` on this Director).
- Otherwise (watch, or group empty with a video id) → `matchWatchSourceId(watchSources, items, parsed.videoDeviceId)`, then that source’s name, else the item name.
- No id or no name → `""`.

`Service.qml` keeps `playingSourceName` as a string, set on every successful volume parse (same `_volumeGen` guard). Rebuild watch/listen lists with the already-cached `_uiConfig` / `_items` / `focusedRoomId` — do not refetch items for the label.

**Chip (`BarWidget.qml`).** Keep the working-tree mark. Do not put room or source text on the chip.

| Session | Mark |
|---|---|
| Connected + focused + `roomOn === true` | Official 4-Ball `icon.png` |
| Connected + focused + `roomOn === false` or `null` | White mark `icon-off.png` |
| Not connected, or no focused room | White mark at `opacity: 0.55` |

Keep both `Image`s loaded and toggle `visible`. Swapping `Image.source` on `ROOM_OFF` left a blank chip while the white PNG decoded. `WidgetButton.text` stays unused (`labelVisible: false`). Room name stays in the tooltip, which already exists; append the source when the room is on and `playingSourceName` is non-empty:

- `Control4 · Deck — Off`
- `Control4 · Deck — On · Apple TV`
- `Control4 · Deck — On`
- not connected: `Control4 — <statusText>` (unchanged)

Vertical bar: the mark is square (`fontSize * 1.7`); no extra width.

**Panel status.** Replace `panelStatus`’s `Watch · Connected` once a room is focused. Connection is implied.

| State | `panelStatus` |
|---|---|
| No focused room | `sessionStatus` (unchanged) |
| `roomOn === false` | `Off` |
| On + named source | `Watch · Sony Reciever` or `Listen · Apple Music` (`LAST_DEVICE_GROUP`, else Watch when a video id matched) |
| On + no name | `On` |
| `roomOn === null` (first poll) | `sessionStatus` |

Title stays the room name. Status stays `haloTextMuted` (status voice, not a control).

**Source highlight.** `chosen` on a source row only while `roomOn !== false` and `selectedSourceId` matches. Restore already sets `selectedSourceId`; this child only suppresses the highlight when the room is off.

**Off.** Keep `secondary: true` (`back-off-buttons-look-disabled`). Add `chosen: session.roomOn === false` so Off is the selected surface when the room is off. Label stays `Off`. Do not paint it `haloTextMuted`.

**Optimistic power.** `roomOff()` sets `roomOn = false` and `playingSourceName = ""` before POST so the chip does not wait 2s. `selectSource` sets `roomOn = true` when it posts a SELECT (not when it skips SELECT for the already-current source — that room is already on). Poll remains source of truth after that.

## Changes

1. `DirectorClient.js` — add `nowPlayingLabel(parsed, items, watchSources, listenSources)` as specified in Approach. Reuse `matchWatchSourceId`. Export it next to `parseRoomVolume`.
2. `tests/director-client.test.js` — fixtures:
   - `POWER_STATE` 0 → `""` even when video/audio ids are present
   - watch id `431` + Base Fam Apple TV name
   - listen `PLAYING_AUDIO_DEVICE` 10 + TuneIn/Apple Music name; ignore a `CURRENT_AUDIO_DEVICE` of `100002` if someone adds it to the parse fixture
   - unknown ids → `""`
   - `LAST_DEVICE_GROUP: "Listen"` (capital L) already lowercased by parse
3. `Service.qml` — `playingSourceName` string; set it in `refreshVolume` from `nowPlayingLabel`; clear it on disconnect / unfocused / `setFocusedRoom`; optimistic `roomOff` / `selectSource` as in Approach. No new Timer. No `media_sessions` GET.
4. `Panel.qml` — rewrite `panelStatus`; source `chosen` requires `roomOn !== false`; Off `chosen` when `roomOn === false`.
5. `BarWidget.qml` — keep dual-Image mark; extend `chipTooltip` with `playingSourceName` when on. Do not revert to room-name chip text.
6. `icon.png` / `icon-off.png` — these are the on/off marks. They must stay in the plugin copy set (`README` already lists them).
7. `README.md` — remove the leftover “chip then shows that room name / stays `C4`” sentence. Document mark + tooltip + panel status.
8. `.hero/knowledge/conventions/halo-remote-panel-style/spec.md` — layout example uses `Listen · Apple Music` / `Off` instead of `Listen · Connected`; bar-chip exception names the two PNGs.

## Boundaries

- No transport play/pause *state* and no combined play/pause toggle
- No `GET /api/v1/media_sessions`, artwork, artist/album/title — `multi-room-audio` owns richer now-playing
- No second variables poll and no websocket
- No room name or source name as chip text
- No lights / climate / shades
- Volume slider and mute stay `room-volume-mute-off`
- Off chrome (secondary vs muted) stays `back-off-buttons-look-disabled`; this child only adds `chosen` when the room is off
- Do not restore the Watch remote from this spec (`watch-remote-lost-on-reopen` already does)

## Risks

- Reading `CURRENT_AUDIO_DEVICE` instead of `PLAYING_AUDIO_DEVICE` shows “Digital Media” forever.
- Showing a source name while `POWER_STATE` is 0 is the stale-on-off bug this child exists to prevent.
- Two `chosen` rows (a source and Off) if the source highlight is not gated on `roomOn`.
- Swapping `Image.source` instead of toggling two loaded images blanks the chip.
- Optimistic `roomOff` can lie for one poll if `ROOM_OFF` no-ops; the next 2s parse corrects it.

## Acceptance Criteria

- **AC-1:** WHILE a focused room is connected THE SYSTEM SHALL keep using the existing room-variables poll (no second Timer, no `media_sessions` GET)
- **AC-2:** WHEN `POWER_STATE` is 0 THE SYSTEM SHALL show the white Control4 mark on the chip, `Off` in the panel status line, and SHALL NOT show a source name
- **AC-3:** WHEN `POWER_STATE` is on and `LAST_DEVICE_GROUP` is listen THE SYSTEM SHALL show the name of `PLAYING_AUDIO_DEVICE` in the panel status line and the chip tooltip
- **AC-4:** WHEN `POWER_STATE` is on and the current video device matches a Watch source THE SYSTEM SHALL show that source name in the panel status line and the chip tooltip
- **AC-5:** WHEN the plugin is not connected or no room is focused THE SYSTEM SHALL show the white mark at reduced opacity, distinct from room-off
- **AC-6:** THE SYSTEM SHALL NOT spell the room name or the source name as chip text
- **AC-7:** WHILE the focused room is off THE SYSTEM SHALL mark the Off row chosen and SHALL NOT mark a source row chosen
- **AC-8:** WHEN the user activates Off THE SYSTEM SHALL show the off chip and `Off` status before the next poll returns

## Validation

```
node tests/director-client.test.js
```

Live copy of QML/JS + both PNGs, then `omarchy restart shell` if the icons are new to the live folder.

Manual: focused room Off → white mark, tooltip `… — Off`, panel status `Off`, Off row selected. Watch a source → official 4-Ball, tooltip names the source, panel `Watch · <name>`, that source row chosen. Listen → `Listen · <name>` from `PLAYING_AUDIO_DEVICE`, not Digital Media. Disconnect / no room → faded white mark. Room name only in the tooltip and the panel title.

## Completion Ledger

Chip is the Control4 mark (on/off/faded). Panel status and tooltip name the playing source or Off. Off is chosen when the room is off. Same 2s variables poll — no second timer, no media_sessions.

**Validation**
- `node tests/director-client.test.js` — pass (`ok`)
- Live copy of QML/JS + both PNGs into `~/.config/omarchy/plugins/io.github.davydotcom.control4/` on 2026-08-23

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Keep the existing room-variables poll; no second Timer / media_sessions | DONE | `Service.qml:919` same GET; only `volumeTimer` at `:1566` interval 2000; no `media_sessions` in repo |
| 2 | POWER_STATE 0 → white mark, panel `Off`, no source name | DONE | `nowPlayingLabel` empty when power false (`DirectorClient.js:435-436`, test `:346`); `panelStatus` `Off` (`Panel.qml:50-51`); chip `icon-off.png` when `!roomOn` (`BarWidget.qml:139-146`) |
| 3 | On + listen → PLAYING_AUDIO_DEVICE name in status and tooltip | DONE | `nowPlayingLabel` listen branch (`DirectorClient.js:437-440`, test `:362`); `panelStatus` `Listen ·` (`Panel.qml:55-57`); tooltip (`BarWidget.qml:24-27`) |
| 4 | On + watch source → that name in status and tooltip | DONE | watch via `matchWatchSourceId` (`DirectorClient.js:441-444`, test `:353`); `panelStatus` `Watch ·` (`Panel.qml:56-57`) |
| 5 | Not connected / no room → faded white mark, distinct from room-off | DONE | `hasFocusedRoom` false → opacity 0.55 and `!roomOn` white mark (`BarWidget.qml:16-17,125,146`); connected+off is opacity 1.0 |
| 6 | SHALL NOT spell room or source as chip text | DONE | `labelVisible: false` (`BarWidget.qml:113`); only Images in the chip |
| 7 | Room off → Off row chosen, source rows not chosen | DONE | Off `chosen: roomOn === false` (`Panel.qml:640`); source `chosen` requires `roomOn !== false` (`Panel.qml:670-674`) |
| 8 | Off tap shows off chip and Off status before next poll | DONE | `roomOff()` sets `roomOn = false` and clears `playingSourceName` before POST (`Service.qml:902-905`) |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `nowPlayingLabel` in DirectorClient.js | DONE | `DirectorClient.js:413-447`; reuses `matchWatchSourceId` |
| 2 | nowPlayingLabel fixtures | DONE | `tests/director-client.test.js:332-372` |
| 3 | Service `playingSourceName` + optimistic off/select | DONE | `Service.qml:84,150,241,288-296,902-905,930` |
| 4 | Panel status + Off/source chosen | DONE | `Panel.qml:47-62,640,670-674` |
| 5 | BarWidget tooltip + dual-Image mark | DONE | `BarWidget.qml:18-31,116-149` |
| 6 | icon.png / icon-off.png in the plugin copy set | DONE | copied to live plugin 2026-08-23; README install list already names them |
| 7 | README leftover room-name chip sentence | DONE | `README.md:13-16,99-101` |
| 8 | halo-remote-panel-style example + bar-chip exception | DONE | convention example `Listen · Apple Music` / Off; Exceptions name both PNGs |

### Exercise-the-feature check

- [x] `node tests/director-client.test.js` printed `ok` (off/watch/listen/unknown label cases). Live plugin files copied 2026-08-23. GUI glance is the user's next bar/panel open (existing QML hot-reloads).

### Excellence Bar self-check

Yes — the name resolver refuses stale sources when the room is off, Listen cannot say Digital Media, and Off is a selected state rather than a muted control.
