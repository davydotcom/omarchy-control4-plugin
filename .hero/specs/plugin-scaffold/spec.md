---
title: Plugin scaffold
slug: plugin-scaffold
type: feature
status: completed
domain: engineering
size: small
horizon: now
parent: control4-focused-room-remote
created: 2026-08-21
tags: [omarchy, control4, bar-widget]
relates-to:
  - omarchy-bar-widget-nested-panel
  - plugin-id-from-day-one
completed_at: 2026-08-21T14:32:58Z
---
# Plugin scaffold

## Context

First child of `control4-focused-room-remote`. This repo has Hero scaffolding only; there is no plugin tree yet. Omarchy third-party plugins are git repos with `manifest.json` plus QML at **repo root**. Live load is a **copy** of those files under `~/.config/omarchy/plugins/<id>/` — not `omarchy plugin clone`, not a symlink, and not `omarchy plugin add` of this dirty checkout.

The official contract for a bar chip with a details surface is `bar-widget` + nested `Panel.qml`, not a separate `panel` kind ([Develop a Plugin](https://omarchyplugins.com/develop.html)). Sibling published plugins (`io.github.davydotcom.mozilla-vpn`, `io.github.davydotcom.z13flow`) use the namespaced ID and MIT/David Estes metadata; they do **not** use the nested-panel entry-point split this child needs.

Parent: `.hero/planning/initiatives/control4-focused-room-remote/spec.md`. Identity decision: `.hero/knowledge/decisions/plugin-id-from-day-one/spec.md`. Nested-panel contract: `.hero/knowledge/context/omarchy-bar-widget-nested-panel/spec.md`.

## Goal

A valid third-party Omarchy `bar-widget` with ID `io.github.davydotcom.control4` from day one: a `C4` chip on the right bar section that left-click toggles a nested details panel titled `Control4` with one line `Not connected`. `omarchy plugin validate` and `qmllint` are clean against the **live** plugin folder. No Director, no rooms, no clock clone.

## Kickoff

Valid Omarchy bar-widget: namespaced ID, C4 chip, nested empty Control4 panel.

**Status:** completed — five plugin files at repo root, copied and enabled on the right bar; validate / qmllint / summon / hide passed.

**Pick up at:** design Director login — in-process JWT session as a `service` kind. Do not re-open plugin identity.

→ `/design director-session`

**Files:** `.hero/planning/features/director-session/spec.md`, `BarWidget.qml`, `Panel.qml`, `manifest.json`

**Skip:** `omarchy plugin clone omarchy.clock`; mozilla-vpn `entryPoints.barWidget: "Panel.qml"`; `omarchy plugin add` on this git root.

## Approach

**Identity from day one.** Plugin ID is `io.github.davydotcom.control4` in `manifest.json` `id` and both QML `moduleName`s. Author: David Estes. License: MIT, copyright 2026 David Estes. Third-party IDs cannot use `omarchy.*`. Compose assumed `io.github.destes.control4`; tighten to `davydotcom` to match this author's published plugins and git identity (David Estes / davydotcom@gmail.com, GitHub `davydotcom`).

**Do not clone `omarchy.clock`.** `omarchy plugin clone omarchy.clock --edit` **replaces the built-in clock** in the bar. This plugin is a new widget, not a clock fork. Do not keep a clone ID, `omarchy.clonedFrom`, or any dual identity so disable/remove would restore the clock. Sibling third-party plugins are authored in a git repo and copied/added under `~/.config/omarchy/plugins/<id>/`.

**Source of truth vs live load.** This workspace (`/home/destes/projects/omarchy/omarchy-control4-plugin`) is source of truth. Plugin files live at **repo root** (sibling pattern): `manifest.json`, `BarWidget.qml`, `Panel.qml`, `README.md`, `LICENSE`. Live load: copy **those files only** into `~/.config/omarchy/plugins/io.github.davydotcom.control4/`, then `omarchy-shell shell rescanPlugins` and `omarchy plugin enable io.github.davydotcom.control4 --section right`. Saving under `~/.config/omarchy/plugins/` hot-reloads. Delivery writes the git repo **then** copies.

Plugin folders **cannot contain symlinks** (`omarchy-plugin-validate` fails on any symlink outside `.git`). This workspace has `.claude/` / `.cursor/` harness symlinks, so `omarchy plugin validate .` on the git root **will fail**. Validate the **live plugin folder**, not the repo root. Do not symlink the plugins dir to the git repo.

`omarchy plugin add` git-clones the whole repo. Do not use it for local develop (it would copy `.hero/` and fail symlink validation). Document `omarchy plugin add <git-url> --enable` as the future published install path only, with placeholder URL `https://github.com/davydotcom/omarchy-control4-plugin.git`.

**Shell contract (bar-widget + nested panel).** Follow first-party weather/clock split + official develop tutorial, **not** mozilla-vpn/z13flow `entryPoints.barWidget: "Panel.qml"` single-file pattern.

- `kinds: ["bar-widget"]` only. No `service` (that's `director-session`). No separate `panel` kind.
- `entryPoints.barWidget: "BarWidget.qml"`
- `BarWidget.qml` loads `Panel.qml` via `Loader`; forwards `opened`, `open()`, `close()`, `toggle()` (click uses `togglePanel`), `closeForPopoutSwitch()`, `popoutSwitchClosing`.
- `injectPanel()` sets `bar`, `anchorItem` (the chip), `hostWidget` (the BarWidget). Panel uses `hostWidget || root` as bar identity for `switchPanelFrom` (clock/weather comment: the bar tracks the widget in the slot, not the nested panel).
- Same `moduleName: "io.github.davydotcom.control4"` in both QML files.
- Panel: `manageIpc: false`. `KeyboardPanel` + `PanelKeyCatcher`. Escape closes. Tab calls `switchPanel`.
- Click chip: left click toggles panel. No right/middle actions in this child.
- Chip: `WidgetButton` with placeholder text `C4`, tooltip `Control4` (text chip, not `BarIconButton`).
- Panel content: title `Control4`, one line `Not connected`. No settings form, no Director, no room list.
- `barWidget.displayName`: Control4. `category`: Home. `allowMultiple`: false. `defaultSection`: right (matches this author's other plugins). `version`: `0.1.0`.

Do not copy clock calendar, `Model.js`, `IpcHandler`, or weather-specific APIs. Minimal tutorial-shaped QML using `qs.Ui` / `qs.Commons` / QtQuick / Quickshell. Do not start a second Quickshell process.

**Shape from these files (do not paste them into this spec; open them at delivery):**

- Official tutorial: https://omarchyplugins.com/develop.html
- `/usr/share/omarchy/shell/plugins/panels/weather/BarWidget.qml` — `injectPanel` / `open` / `close` / `opened` / popout-switch forwarding
- `/usr/share/omarchy/shell/plugins/panels/clock/BarWidget.qml` — `WidgetButton` + `Loader` structure only (not calendar, formats, `IpcHandler`, or right/middle clicks)
- `/usr/share/omarchy/shell/plugins/panels/weather/Panel.qml` — `manageIpc: false`, `hostWidget` / `barIdentity`, `KeyboardPanel` + `PanelKeyCatcher` (Escape / Tab). Strip weather content.
- `/home/destes/projects/omarchy/omarchy-mozilla-vpn-plugin/manifest.json` — third-party metadata shape (`id`, `author`, `license`, `defaultSection: "right"`), **not** `entryPoints` pattern
- `/home/destes/projects/omarchy/omarchy-mozilla-vpn-plugin/LICENSE` — copy MIT text verbatim
- `/usr/share/omarchy/bin/omarchy-plugin-validate` — no symlinks
- `/usr/share/omarchy/bin/omarchy-plugin-add` — git clone of the whole repo

## Changes

1. `LICENSE` — MIT text copied verbatim from the mozilla-vpn sibling; includes `Copyright (c) 2026 David Estes`
2. `manifest.json` — `id` `io.github.davydotcom.control4`, `kinds: ["bar-widget"]`, `entryPoints.barWidget: "BarWidget.qml"`, Home/right bar-widget metadata, no clone/settings schema
3. `BarWidget.qml` — `C4` `WidgetButton`, Loader → `Panel.qml`, injectPanel + open/close/toggle/togglePanel/opened/popoutSwitchClosing/closeForPopoutSwitch forwards
4. `Panel.qml` — nested `Panel` with `manageIpc: false`, `barIdentity` owner, KeyboardPanel + Escape/Tab, title `Control4` / line `Not connected`
5. `README.md` — published install placeholder, local copy-into-plugins develop path, usage, remove; no Director credentials
6. `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/` — real copy of the five files (not a symlink); rescanned and enabled on the right section
7. `.gitignore` — Hero-managed block left untouched; no extra plugin-noise ignores added

## Boundaries

- No Director HTTP, credentials, JWT, or settings form
- No room list, Watch/Listen, volume, mute, off, or now-playing
- No `service` kind (that's `director-session`)
- No separate `panel` / `overlay` / `menu` / `bar` kind
- No `omarchy plugin clone omarchy.clock` and no clone-ID / `omarchy.clonedFrom` dual identity
- No `omarchy plugin add` of this dirty repo
- No symlink from `~/.config/omarchy/plugins/` to this git repo
- No mozilla-vpn/z13flow single-file `entryPoints.barWidget: "Panel.qml"`
- No Python sidecar or second Quickshell process
- Do not document Control4 credentials
- Do not rewrite the Hero-managed `.gitignore` block

## Risks

- **Validate-on-repo-root symlink failure.** `omarchy plugin validate .` on the git root fails because `.claude/` / `.cursor/` are harness symlinks. Always validate `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4`.
- **Desync.** Someone editing only the live plugins copy (or only the git repo) will drift. Source of truth is the git repo; delivery copies after writing.
- **Forgetting `open` / `close` / `opened` forward.** If those are not on the BarWidget root, the panel opens once and summon/hide/`Bar.findPanelWidget` break. Same for `closeForPopoutSwitch` / `popoutSwitchClosing`.
- **Clock-clone would steal the clock slot.** `omarchy plugin clone omarchy.clock --edit` replaces the built-in clock. This plugin must never be that clone.
- **`omarchy plugin add` of this checkout** clones `.hero/` and harness symlink dirs into the plugins folder and fails validation.

## Acceptance Criteria

- WHEN the live plugin folder is validated with `omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.davydotcom.control4"` THE SYSTEM SHALL report a valid `bar-widget` whose entry point file exists
- WHEN `qmllint -I /usr/share/omarchy/shell` is run against the live `BarWidget.qml` and `Panel.qml` THE SYSTEM SHALL exit without error
- WHEN the user left-clicks the `C4` bar chip THE SYSTEM SHALL toggle the nested details panel
- WHEN the nested panel is open THE SYSTEM SHALL show title `Control4` and the line `Not connected`
- WHEN the nested panel is open and the user presses Escape THE SYSTEM SHALL close the panel
- WHEN `omarchy plugin list --json` is queried THE SYSTEM SHALL include an entry whose `id` is `io.github.davydotcom.control4`
- WHEN `omarchy-shell shell summon io.github.davydotcom.control4 '{}'` is run THE SYSTEM SHALL open the nested panel
- WHEN `omarchy-shell shell hide io.github.davydotcom.control4` is run THE SYSTEM SHALL close the nested panel
- THE SYSTEM SHALL use plugin ID `io.github.davydotcom.control4` in `manifest.json` `id` and both QML files' `moduleName`
- THE SYSTEM SHALL NOT declare a separate `panel` kind; `Panel.qml` is loaded by `BarWidget.qml`
- THE SYSTEM SHALL NOT clone `omarchy.clock` or keep an `omarchy.clonedFrom` / clone-ID dual identity
- THE SYSTEM SHALL place plugin files at git-repo root and a copy (not a symlink) under `~/.config/omarchy/plugins/io.github.davydotcom.control4/`

## Validation

`OMARCHY_PATH` on this machine is `/usr/share/omarchy`. Run against the **live** folder, not the git root:

```
PLUGIN_ID=io.github.davydotcom.control4
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
omarchy plugin list --json | jq --arg id "$PLUGIN_ID" '.[] | select(.id == $id)'
omarchy-shell shell summon "$PLUGIN_ID" '{}'
omarchy-shell shell hide "$PLUGIN_ID"
```

Manual: left-click the `C4` chip opens/closes the panel; Escape closes; disable then re-enable still works; after an Omarchy shell restart the plugin still appears in `omarchy plugin list`.
