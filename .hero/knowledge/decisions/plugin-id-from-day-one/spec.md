---
title: Plugin ID from day one
slug: plugin-id-from-day-one
type: decision
status: accepted
domain: engineering
created: 2026-08-21
tags: [omarchy, plugin-id, control4]
relates-to:
  - plugin-scaffold
  - control4-focused-room-remote
  - omarchy-bar-widget-nested-panel
---
# Plugin ID from day one

## Decision

This plugin's ID is `io.github.davydotcom.control4` from day one. Do not clone `omarchy.clock` to bootstrap it.

## Context

Compose assumed `io.github.destes.control4` and `omarchy plugin clone omarchy.clock --edit` (keep clone ID until publish). Clock clone **replaces the built-in clock** in the bar. This is a new widget, not a clock fork. The author's published plugins use `io.github.davydotcom.*` (mozilla-vpn, z13flow); git user is David Estes / davydotcom@gmail.com.

## Alternatives Considered

- **Clone `omarchy.clock` and rename later.** Rejected: clone-ID dual identity steals the clock slot; disable/remove restores the clock instead of removing this widget.
- **`io.github.destes.control4`.** Rejected: does not match this author's published plugin IDs.
- **`omarchy.*` ID.** Forbidden for third-party plugins.

## Consequences

Author plugin files at git-repo root; copy into `~/.config/omarchy/plugins/io.github.davydotcom.control4/`. Do not `omarchy plugin add` a dirty Hero checkout (harness symlinks fail `omarchy plugin validate`). Nested-panel QML contract stays in `omarchy-bar-widget-nested-panel`.
