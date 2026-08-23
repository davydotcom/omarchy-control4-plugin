---
title: Remote command metadata
slug: remote-command-metadata
type: feature
status: completed
domain: engineering
size: medium
horizon: next
priority: critical
parent: watch-source-virtual-remote
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
completed_at: 2026-08-23T19:35:56Z
---
# Remote command metadata

## Context

First child of `watch-source-virtual-remote`. The Director already publishes, per proxy item in `GET /api/v1/items`, a `commands.command[]` array of accepted command names and a `capabilities.navigator_display_option` block. The plugin fetches that payload already (`refreshRooms` in `Service.qml` stores it as `_items`) and throws the command list away. Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

A pure parser in `DirectorClient.js` that turns one item into a button-capability object: which navigation keys it accepts, whether transport is declared, whether digits or channel entry apply, and which power commands exist. No UI in this child. Done when the parser answers correctly for the three live shapes on this Director — `dvd` (`.c4i`), `media_player` (`.c4z`), and `cable`.

## Kickoff

Turn each item's `commands[]` and `navigator_display_option` into a button-capability model. Parser only, no UI.

**Status:** delivering — `parseRemoteCapabilities` / `hasRemoteCommand` landed; `node tests/director-client.test.js` passes.

**Pick up at:** `hero spec verify remote-command-metadata`, then `/design virtual-remote-dpad`.

→ `hero spec verify remote-command-metadata`

**Files:** `DirectorClient.js:556`, `tests/director-client.test.js:358`

**Skip:** any `Panel.qml` / `Service.qml` change; sending commands; per-brand tables; driver icon fetching. Leave the uncommitted `parseRoomVolume` POWER_STATE work in `DirectorClient.js` alone.

## Approach

Mirror the existing MSP parser convention: plain functions in the `.pragma library`, exercised from `tests/director-client.test.js` under `node`. The shape to produce is a capability object, not a rendered layout — layout belongs to the sibling UI children.

**Command names.** Read `item.commands.command` through `_asArray`. Each entry is a name if it is a non-empty string, or — when it is an object — the first non-empty string among `name`, `command`, and `id`. Skip anything else. Trim, store uppercase, de-dupe preserving first-seen order. The live inventory listed the names (`UP`, `PLAY`, `NUMBER_0`, …) but not the per-entry JSON key; this extraction covers the string list and the `{name,id}` list `GET /api/v1/items/{id}/commands` uses, without inventing other fields.

**Gates (never `item.name` / `model` / `manufacturer` / `proxy` / filename).**

| Flag | True when |
|---|---|
| `hasNavigation` | at least one of `MENU UP DOWN LEFT RIGHT ENTER` is in `commands` |
| `nav.{menu,up,down,left,right,enter}` | that specific command is present |
| `hasTransport` | at least one of `PLAY STOP PAUSE SKIP_FWD SKIP_REV SCAN_FWD SCAN_REV` |
| `transport.{play,stop,pause,skipFwd,skipRev,scanFwd,scanRev}` | that specific command is present |
| `hasDigits` | any `NUMBER_0`…`NUMBER_9` is present (recorded only; not a channel-pad gate) |
| `hasChannelUpDown` | `capabilities.has_channel_up_down` is truthy (`true` / `"true"` / `"1"` / `1`) |
| `hasDiscreteChannelSelect` | `capabilities.has_discrete_channel_select` same coercion |
| `power.on` / `power.off` | `ON` / `OFF` present |

Channel entry for `virtual-remote-numbers` keys off the two capability flags, not `hasDigits`. Apple TVs declare digits they have no use for.

**`navigator_display_option` (defensive).** Missing `show_transport` is `null`, not `false` — the `.c4z` `media_player` shape omits the key; the `.c4i` `dvd` shape sets it. `displayIcon` is the string `display_icon` or `""`. `displayIcons` is `_asArray(display_icons)` mapped to strings (plain string, or object `url` if present); do not fetch `controller://` URLs.

**Empty / junk input.** `null`, non-object, missing `commands`, or unparseable entries return the empty object (all flags false, `commands: []`, `showTransport: null`) and do not throw.

Return shape (plain object, QML-safe — no `Set`, no methods on the value):

```
{
  commands: [],
  hasNavigation: false,
  nav: { menu, up, down, left, right, enter },
  hasTransport: false,
  transport: { play, stop, pause, skipFwd, skipRev, scanFwd, scanRev },
  hasDigits: false,
  hasChannelUpDown: false,
  hasDiscreteChannelSelect: false,
  power: { on, off },
  showTransport: null,   // true | false | null
  displayIcon: "",
  displayIcons: []
}
```

`hasRemoteCommand(caps, name)` is a separate helper: true when `caps.commands` contains the uppercase name.

## Changes

1. `DirectorClient.js` — add `parseRemoteCapabilities(item)` and `hasRemoteCommand(caps, name)` next to `_asArray`. Reuse `_asArray`. Do not change `extractSources`, MSP/TuneIn parsers, or `parseRoomVolume`.
2. `tests/director-client.test.js` — import the new functions; cover:
   - `dvd` `.c4i` shape: nav + transport + digits + `show_transport: true` + `display_icon` string → `hasNavigation` / `hasTransport` / `hasDigits` true, channel flags false, `showTransport === true`
   - `media_player` `.c4z` shape: same command set, no `show_transport`, `display_icons` present → `showTransport === null` (not false)
   - `cable` shape: channel flags true, digits optional; `hasDiscreteChannelSelect` true even if we also list `NUMBER_*`
   - no `commands` / `null` item → empty caps, no throw
   - `commands.command` as a single object `{ name: "UP" }` → one-element list, `nav.up === true`
   - item named `"Apple TV"` with empty commands → `hasNavigation === false` (name is not a gate)

## Boundaries

- No UI, no command sending, no state polling
- No brand or model detection
- No driver icon/translation fetching — record that the URLs exist, do not resolve them
- Do not touch the Listen-side MSP parsers
- Do not touch `Panel.qml` or `Service.qml` (siblings consume the parser later)
- Do not mix in the uncommitted `parseRoomVolume` POWER_STATE work already in the tree

## Risks

- `commands[]` describes what the proxy accepts, not what the physical device does. The parser must not imply the latter.
- Overfitting to the three shapes on this Director. Other proxies (receiver, TV, `rf_cable`) exist and should degrade to "no remote" rather than crash.
- Treating absent metadata as a negative rather than as unknown (`showTransport: null`).

## Acceptance Criteria

- **AC-1:** WHEN given an item declaring `UP DOWN LEFT RIGHT ENTER MENU` THE SYSTEM SHALL report navigation as available
- **AC-2:** WHEN given an item with no `commands` THE SYSTEM SHALL report no capabilities rather than throwing
- **AC-3:** WHEN given `commands.command` as a single object THE SYSTEM SHALL treat it as a one-element list
- **AC-4:** THE SYSTEM SHALL NOT use the item's name, model, or manufacturer to decide capabilities
- **AC-5:** WHEN given channel capability flags THE SYSTEM SHALL report channel entry from those flags, not from `NUMBER_*` commands
- **AC-6:** IF `show_transport` is absent THEN THE SYSTEM SHALL NOT treat transport display as false
- **AC-7:** WHEN given `ON` and/or `OFF` in `commands` THE SYSTEM SHALL report the matching power flags

## Validation

`node tests/director-client.test.js` covers the `dvd`, `media_player`, and `cable` shapes plus the empty, single-object, and name-is-not-a-gate cases. No live Director call is needed for this child.

## Completion Ledger

Parser-only child of `watch-source-virtual-remote`. Stack: JavaScript `.pragma library` + Node tests (same as `parseMspTabs`). Validation: `node tests/director-client.test.js` → `ok`.

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Nav commands → navigation available | DONE | `DirectorClient.js:556` `hasNavigation` / `nav.*`; test `dvd nav` |
| 2 | No commands → empty caps, no throw | DONE | `parseRemoteCapabilities(null)` / `{}`; tests `null item`, `no commands` |
| 3 | Single-object `commands.command` → one-element list | DONE | `_asArray` + `_commandName`; test `single object command` |
| 4 | SHALL NOT use name/model/manufacturer | DONE | Parser never reads those fields; test `name is not a gate` |
| 5 | Channel entry from capability flags, not `NUMBER_*` | DONE | `hasChannelUpDown` / `hasDiscreteChannelSelect`; dvd has digits but channel false; cable flags true |
| 6 | Absent `show_transport` is not false | DONE | `showTransport` stays `null`; test `c4z missing show_transport is not false` |
| 7 | `ON`/`OFF` → power flags | DONE | `power.on` / `power.off`; test `dvd power` |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `DirectorClient.js` — `parseRemoteCapabilities` + `hasRemoteCommand` | DONE | Added next to `_asArray` at `DirectorClient.js:500`; MSP/TuneIn/`parseRoomVolume` untouched by this work |
| 2 | `tests/director-client.test.js` — dvd / c4z / cable / empty / single-object / name-not-a-gate | DONE | Tests from `tests/director-client.test.js:358`; `node tests/director-client.test.js` prints `ok` |

### Exercise-the-feature check

- [x] Cannot be exercised in the panel because this child has no UI: `node tests/director-client.test.js` printed `ok` (dvd, media_player, cable, empty, single-object, name-is-not-a-gate).

### Excellence Bar self-check

Yes — same `_asArray` defensive pattern as MSP parsers, QML-safe plain object, channel vs digits split locked for the numbers sibling.
