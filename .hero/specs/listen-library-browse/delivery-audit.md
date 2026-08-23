# Delivery audit — listen-library-browse

**Audited:** `git show 54f0cae` (first land) plus `git diff HEAD -- DirectorClient.js Service.qml Panel.qml tests/director-client.test.js` (working tree vs `1a98b21`). Same files also carry sibling Watch/remote work; this audit scores only Listen browse.
**Verdict:** SHIP
**Surface:** clean

Amazon/SiriusXM are Boundaries, not acceptance criteria. `_mspServiceOf` returns only `apple` / `tunein`.

## Acceptance criteria
- [✓] Apple Music from Listen shows Director stations/playlists/songs, not only the device name — `Service.qml:294-297,370-407` Listen tap → `SELECT_AUDIO_DEVICE` then `openMspBrowse` → `GetTabList` / `Browse`; `DirectorClient.js:777-824,851-859` `parseMspTabs` / `parseMspList` / `isAppleMusicItem`. Tests parse Stations + **My Personal Station** / **David Estes’ Station** (`tests/director-client.test.js:278-287`). Kickoff: Apple Music browse/play live.
- [✓] Pick playlist/song plays in `focusedRoomId` via `directorPost` — `Service.qml:566-581,665-708` `Play` / `PlayStation` with `ROOMID: String(focusedRoomId)` on existing `directorPost`; TuneIn play is `BrowseCommand` (`Service.qml:616`, `DirectorClient.js:832-848,938-958`). Tests: `mspPlayCommand` playlist→Play, station→PlayStation (`:288-289`); `tuneInTapArgs` for WFYI (`:367-371`). Live: TuneIn 90.1 WFYI, `PLAYING_AUDIO_DEVICE=10`.
- [✓] No browse catalog stays tap-to-select — `Service.qml:294-299` `openMspBrowse` only when `_mspServiceOf` is apple/tunein; else `closeBrowse()`. Classifiers reject ShairBridge / cross-dialect (`tests/director-client.test.js:298,335-336`).
- [✓] SHALL NOT call Apple’s public Music API or a new HTTP client — engine.io poll via `curlNavArgs` + existing `directorPost` (`DirectorClient.js:413-429`, `Service.qml:753-787,1470-1479`). No MusicKit / `music.apple` / sidecar in `.js`/`.qml`.

## Changes
- [✓] `DirectorClient.js` MSP + TuneIn parsers — `parseMspResponse(s)`, `parseMspTabs`, `parseMspList`, `mspArgXml`, `curlNavArgs`, `isAppleMusicItem`, `mspPlayCommand`, `isTuneInItem`, `driverXmlPath`, `parseTuneInTabs`, `parseTuneInList`, `tuneInTapArgs` (`DirectorClient.js:413-519,777-959`).
- [✓] `Service.qml` nav poll + browseTap/Back — `navProc` (`:1470`); `openMspBrowse`, `_loadTuneInTabs` / `_tuneInBrowse` / `_tuneInTap`, `browseTap` / `browseBack` (`:379-634`).
- [✓] `Panel.qml` Back + browse list — Back calls `browseBack` (`:511-524`); `browseList` (`:668-680`); TuneIn `isHeader` → `HaloRow.heading` muted, not pressable (`:132,151,170,678`).
- [✓] Parser tests both dialects — `tests/director-client.test.js:278-374` (MSP tabs/list/play + TuneIn tabs/list/headers/tap args).

## Open items (if any)

None.

## Audit notes

None.
