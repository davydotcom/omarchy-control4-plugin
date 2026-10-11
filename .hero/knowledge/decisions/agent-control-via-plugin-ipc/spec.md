---
title: Agent control via plugin IPC
slug: agent-control-via-plugin-ipc
type: decision
status: accepted
domain: engineering
created: 2026-10-11
tags: [omarchy, control4, ipc, agents, skill]
relates-to:
  - agent-skill
  - in-process-director-rest
  - implemented-experience-allow-list
---
# Agent control via plugin IPC

## Context

The user wants AI agents (Claude Code / Cursor / Codex skills) to operate their Control4 room. The running service already owns the Director session, token refresh, the curl queue, and the room/source catalogs. Omarchy plugin manifests (`schemaVersion` 1) have no skill kind, so neither `omarchy plugin add` nor `validate` can install one. On this machine skills live at `~/.agents/skills/<name>/SKILL.md`, and `~/.claude/skills/<name>` is a relative symlink to that copy.

## Options considered

- **Agent curls the Director with `credentials.json`.** Duplicates the session, puts the password and JWT into agent transcripts and argv, and breaks `in-process-director-rest`.
- **Separate CLI or sidecar.** A second client and session to supervise. Forbidden in spirit by `in-process-director-rest`.
- **Plugin `IpcHandler` via `omarchy-shell` (chosen).** Thin wrappers over the same service functions the panel calls. String args, string returns (JSON / `ok:` / `started:` / error token). Ids at the IPC layer; the skill resolves names by listing first.
- **Plugin auto-installs the skill.** No manifest support. Writing into `~/.agents` from a bar plugin is an unasked side effect.

## Decision

The agent control surface is the plugin's `IpcHandler` (target `io.github.davydotcom.control4`), called through `omarchy-shell`. It never returns credentials, tokens, navigator ids, or the controller IP, and it sends only the Director commands the panel already sends. The skill ships in the repo at `skills/control4/SKILL.md` and the user installs it manually from the README. Only implemented experiences (Watch, Listen) are exposed.

## Consequences

Every new panel capability that agents should use needs a matching IPC wrapper and a skill update. The skill can't hard-enforce safety: volume caps and "off only when asked" are skill policy. `status` / `browseApple` / `browseTap` stay as maintainer debug probes outside the agent contract.
