---
title: Remote command metadata
slug: remote-command-metadata
type: feature
status: planning
domain: engineering
size: medium
horizon: next
parent: watch-source-virtual-remote
created: 2026-08-23
tags: [omarchy, control4, watch, remote]
---
# Remote command metadata

## Context

First child of `watch-source-virtual-remote`. The Director already publishes, per proxy item in `GET /api/v1/items`, a `commands.command[]` array of accepted command names and a `capabilities.navigator_display_option` block. The plugin fetches that payload already (`refreshRooms` in `Service.qml` stores it as `_items`) and throws the command list away. Parent: `.hero/planning/initiatives/watch-source-virtual-remote/spec.md`.

## Goal

A pure parser in `DirectorClient.js` that turns one item into a button-capability object: which navigation keys it accepts, whether transport is declared, whether digits or channel entry apply, and which power commands exist. No UI in this child. Done when the parser answers correctly for the three live shapes on this Director — `dvd` (`.c4i`), `media_player` (`.c4z`), and `cable`.

## Kickoff

Turn each item's `commands[]` and `navigator_display_option` into a button-capability model. Parser only, no UI.

**Status:** planning — metadata verified live, parser not written.

**Pick up at:** `/design remote-command-metadata`, then implement alongside tests the way `parseMspTabs` / `parseTuneInList` were.

→ `/design remote-command-metadata`

**Files:** `DirectorClient.js`, `tests/director-client.test.js`

**Skip:** any `Panel.qml` change; sending commands; per-brand tables; driver icon fetching.

## Approach

Mirror the existing MSP parser convention: plain functions in the `.pragma library`, exercised from `tests/director-client.test.js` under `node`. The shape to produce is a capability object, not a rendered layout — layout belongs to the sibling UI children.

Read defensively. `commands.command` may be an object rather than an array (the codebase already has `_asArray` for exactly this). `navigator_display_option` differs between `.c4i` proxies (`show_transport`, `display_icon`, `status_icon`) and `.c4z` drivers (`translation_url`, `display_icons`, no `show_transport`) — a missing `show_transport` must not be read as false.

Gate on declared commands, never on device name. Channel entry keys off `capabilities.has_channel_up_down` / `has_discrete_channel_select`, which is how the cable box differs from the Apple TVs.

## Changes

Will be produced by `/design remote-command-metadata`. No file-level Changes until then.

## Boundaries

- No UI, no command sending, no state polling
- No brand or model detection
- No driver icon/translation fetching — record that the URLs exist, do not resolve them
- Do not touch the Listen-side MSP parsers

## Risks

- `commands[]` describes what the proxy accepts, not what the physical device does. The parser must not imply the latter.
- Overfitting to the three shapes on this Director. Other proxies (receiver, TV, `rf_cable`) exist and should degrade to "no remote" rather than crash.
- Treating absent metadata as a negative rather than as unknown.

## Acceptance Criteria

- WHEN given an item declaring `UP DOWN LEFT RIGHT ENTER MENU` THE SYSTEM SHALL report navigation as available
- WHEN given an item with no `commands` THE SYSTEM SHALL report no capabilities rather than throwing
- WHEN given `commands.command` as a single object THE SYSTEM SHALL treat it as a one-element list
- THE SYSTEM SHALL NOT use the item's name, model, or manufacturer to decide capabilities

## Validation

`node tests/director-client.test.js` covers the `dvd`, `media_player`, and `cable` shapes plus the empty and single-object cases. No live Director call is needed for this child.
