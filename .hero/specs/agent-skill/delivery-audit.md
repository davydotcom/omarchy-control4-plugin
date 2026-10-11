# Delivery audit — agent-skill

**Audited:** `git diff HEAD` (uncommitted, master) plus untracked `skills/control4/SKILL.md`; `.hero/QUEUE.md` churn ignored
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria
- [✓] AC-1 — 8 agent methods, string args, string return — `Service.qml:1703-1794`; re-run `qs ipc -n -p /usr/share/omarchy/shell show` lists `state`, `rooms`, `focusRoom(id: string)`, `sources(mode: string)`, `selectSource(mode: string, id: string)`, `setVolume(level: string)`, `setMute(value: string)`, `off` (all `: string`), with `_agentRoomGuard` not exported; static signature test `tests/director-client.test.js` "IPC method …"
- [✓] AC-2 — `state` returns exactly 11 keys whatever the session state — `DirectorClient.js:532-548` builds the object key by key; tests "agentState exact key whitelist" and "agentState keys when disconnected" (`auth-failed`); re-run live `state` returned exactly the 11 keys
- [✓] AC-3 — no credentials, tokens, IP, navigator ids, or cookie path in any return — whitelist, no spread; leak test with email/password/IP/account+director tokens/nav id/cookie path; static test that agent IPC bodies (`state()`…`status()`) never reference `password|email|controllerIp|_directorToken|_accountToken`. `status` (dev, unchanged) still returns `hasToken`/`tokenAgeSeconds`, which is pre-existing and allowed by AC-14
- [✓] AC-4 — not connected returns `not-connected:<state>` with no request — `_agentRoomGuard` `Service.qml:1689-1695` is the first statement of `sources`/`selectSource`/`setVolume`/`setMute`/`off`; `rooms`/`focusRoom` check the session first (`:1717`, `:1725`). Asserted by regex ordering tests. **Not exercised live** (see notes)
- [✓] AC-5 — `rooms` returns `{id,name,focused}` — `agentRooms` `DirectorClient.js:550-561`; tests "agentRooms marks only focused"/"agentRooms shape"; re-run live: 4 rooms, only Great Room (13) `focused:true`
- [✓] AC-6 — valid `focusRoom` calls `setFocusedRoom`, returns `ok:<id>` — `Service.qml:1724-1732`; ledger reports live `focusRoom 13` → `ok:13` (not re-run: it changes the house)
- [✓] AC-7 — bad `focusRoom` returns `unknown-room:<id>` — `parseIdArg` + `_roomById` check before any call; re-run live `focusRoom 999999` → `unknown-room:999999`, `focusRoom abc` → `unknown-room:abc`
- [✓] AC-8 — no focused room returns `no-room` with no request — second branch of `_agentRoomGuard`; regex test "_agentRoomGuard returns not-connected then no-room". **Not exercised live** (see notes)
- [✓] AC-9 — `sources` read-only list, `bad-mode` — `Service.qml:1734-1742` calls `extractSources` with the requested mode and never touches `sourceMode`; re-run live: watch (4), listen (13), `tv` → `bad-mode:tv`; `state`/`status` still show `sourceMode: watch` after `sources listen`
- [✓] AC-10 — `selectSource` sets mode, selects, returns `started:`; unknown id returns `unknown-source` — `Service.qml:1744-1763` validates the id against `extractSources(…, mode)` before `setSourceMode`/`selectSource`; `_rebuildSources` (`:1050`) is synchronous, so the service's own `sources` check passes after a mode switch. Re-run live `selectSource watch 999999` → `unknown-source:999999`, `selectSource tv 1` → `bad-mode:tv`; ledger reports live `selectSource watch 443` → `started:watch:443` with `state` power on
- [✓] AC-11 — `setVolume` clamped `started:<n>`; bad input returns `bad-level` — `parseVolumeArg` `DirectorClient.js:563-568`; tests cover `""`, `" "`, `abc`, `30%`, `-5`, `3.5`, null/undefined, clamp 150→100; re-run live `abc`/`''`/`3.5`/`-5` → `bad-level:…`. Ledger reports `setVolume 25` → `started:25` but the Director did not apply the level (pre-existing, see notes)
- [✓] AC-12 — `setMute` on/off/toggle semantics — `Service.qml:1776-1786`; `toggleMute` flips `muted` optimistically (`:988-992`), so `started:<on|off>` reflects the new state; re-run live `setMute loud` → `bad-mute:loud`; ledger reports live `on`→`started:on`, `on`→`ok:unchanged`, `off`→`started:off`
- [✓] AC-13 — `off` calls `roomOff()`, returns `started:off` — `Service.qml:1788-1794`; ledger reports live `started:off` and `state` power off (re-run `state` shows `power:"off"`)
- [✓] AC-14 — `status`/`browseApple`/`browseTap` unchanged — the diff's only Service.qml hunk ends before `function status()`, so the bodies are untouched; re-run live `status` returns the navigator debug shape, and `browseTap abc` → `bad-index`
- [✓] AC-15 — SKILL.md ships with frontmatter, commands, workflow, safety, not-connected handling — `skills/control4/SKILL.md`: frontmatter `name: control4` plus the spec's description verbatim; Commands table and examples; Workflow with a single 3 s `state` confirmation; Safety rules (state dir/credentials, no sign-in, no curl, `off` only on request, 60/+20 cap, no dev methods, unsupported features); "When it can't connect" section. Session-state names match `_setState` values (`unconfigured`, `connecting`, `connected`, `auth-failed`, `error`)
- [✓] AC-16 — README covers install, removal, and local-develop copy — `README.md:120-146` `## Agent skill` after `## Usage` with the exact one-liner; `README.md:85,90,92` copy list/`mkdir`/`cp`; `README.md:152` `rm -rf` in Remove. Re-run: `~/.claude/skills/control4 -> ../../.agents/skills/control4`, and `cmp` shows `~/.agents/skills/control4/SKILL.md` matches the repo file
- [✓] AC-17 — `omarchy plugin validate` exits 0 with the skill present — re-run: exit 0; the live plugin folder's `skills/control4/SKILL.md`, `Service.qml`, `DirectorClient.js`, `manifest.json`, and `README.md` are byte-identical to the repo
- [✓] AC-18 — helpers covered, suite passes — `tests/director-client.test.js:772-836`; re-run `node tests/director-client.test.js` → `ok`, exit 0

## Changes
- [✓] 1. `DirectorClient.js` four pure helpers — `agentState`, `agentRooms`, `parseVolumeArg`, `parseIdArg` at `:532-575`, after `extractSources`
- [✓] 2. `Service.qml` IPC methods, guard, and comment — 8 methods at `:1703-1794`; new comment at `:1697-1699` states the no-credentials constraint. The guard sits on root (`:1689`) instead of inside the handler. That is a deliberate deviation so it isn't exported as an IPC method; `qs ipc show` confirms it isn't listed
- [✓] 3. Tests — all spec-listed cases are present, plus static checks for signatures, guard-first ordering, and no credential references
- [✓] 4. `skills/control4/SKILL.md` — new plain file (untracked), no symlinks
- [✓] 5. README — `## Agent skill`, local-develop list and copy block, Remove line, and Remove note updated to say the skill isn't deleted
- [✓] 6. `manifest.json` — `version` 0.6.2 → 0.7.0, nothing else

## Open items (if any)
- None. The ledger has no PARTIAL, SKIPPED, or BLOCKED rows.

## Audit notes
- **AC-4 and AC-8 were never exercised live.** Evidence is code reading plus regex tests over the `Service.qml` source text, not behavior tests. The ledger's reasons are concrete: there's no disconnect over IPC, the house always has a saved focus, and the user approved code-plus-test coverage. However, the spec's Validation section prescribed a live check (panel gear → Disconnect, then call `rooms`/`setVolume 10`/`off`), and that check was not run. The guards are short and plainly correct on reading.
- **The skill was never tried in a fresh agent session.** The Goal's "an agent with the installed skill can carry out 'turn on Apple TV in the great room' end to end" and the Validation "Skill end to end" step were skipped to avoid driving the house again. The skill content meets AC-15, but no agent has actually run it.
- **Volume did not take effect live.** In the Great Room, `setVolume 25` returned `started:25`, yet `CURRENT_VOLUME` stayed at 62. The IPC calls the same `root.setVolume` as the panel slider, so this looks pre-existing and is flagged for its own `/diagnose`. Re-run `state` still shows `volume: 62`. The IPC contract defines `started:` as "sent, not confirmed", so AC-11 is met, but the user-level outcome ("volume to 30") does not currently work in this room.
- The four open questions were resolved by taking the spec's defaults, without the user answering them: persistent focus, copy install, 60/+20 cap, new `state` beside `status`. The ledger says so openly. Worth confirming with the user.
- In the user's house the Great Room watch list contains no source named "Apple TV" (only "Base Fam Apple TV" and "Great Room Display"). The skill's name-matching rules handle this by asking the user, but the spec's flagship phrase won't map directly here.
- Scope: also untracked is `.hero/knowledge/decisions/agent-control-via-plugin-ipc/spec.md`, a decision record that the spec's `relates-to` references. Spec status is still `planning`.
