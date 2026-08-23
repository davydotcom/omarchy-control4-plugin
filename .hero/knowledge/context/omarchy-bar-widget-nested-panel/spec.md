---
title: Omarchy bar-widget nested panel
slug: omarchy-bar-widget-nested-panel
type: context
status: active
domain: engineering
created: 2026-08-21
tags: [omarchy, bar-widget]
relates-to:
  - control4-focused-room-remote
  - plugin-scaffold
---
# Omarchy bar-widget nested panel

## Overview

A bar chip with a details popout is one `bar-widget` plugin. The manifest loads `BarWidget.qml`; that file loads `Panel.qml`. Do not declare a separate `panel` kind for this pattern.

## Details

Official develop tutorial: keep `kinds: ["bar-widget"]` and `entryPoints.barWidget: "BarWidget.qml"`. The bar entry point loads nested `Panel.qml`. Forward `opened`, `open()`, `close()`, and popout-switch helpers from the bar entry point to the loaded panel — otherwise the panel opens once and not again. Third-party IDs cannot use `omarchy.*`. Do not clone `omarchy.clock` to start a new widget (that replaces the built-in clock); identity is `io.github.davydotcom.control4` from day one (see `plugin-id-from-day-one`). Validate the live plugin folder with `omarchy plugin validate` and `qmllint -I "$OMARCHY_PATH/shell"` — not a git root that contains harness symlinks. Plugins share the unsandboxed Omarchy shell process; never start a second Quickshell process.

## References

- https://omarchyplugins.com/develop.html
