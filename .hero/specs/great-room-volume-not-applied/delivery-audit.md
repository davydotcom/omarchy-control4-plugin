# Delivery audit — great-room-volume-not-applied

**Audited:** `git diff HEAD -- Service.qml DirectorClient.js tests/director-client.test.js` plus untracked `skills/control4/SKILL.md` (working tree on `master`; the prior uncommitted `agent-skill` delivery in the same files was excluded from scope)
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria
- [✓] AC-1 IPC `setMute on` posts `MUTE_ON` and returns `started:on`, whatever `muted` is. IPC `setMute` (`Service.qml:1783-1794`) calls `root.setMuted(value === "on")` with no `ok:unchanged` short-circuit. `setMuted` (`Service.qml:989-993`) posts `muted ? "MUTE_ON" : "MUTE_OFF"`. Static tests at `tests/director-client.test.js:859-864`. Live per the ledger: a repeated `on` returned `started:on` with `MUTE_ON HTTP 200`.
- [✓] AC-2 IPC `setMute off` posts `MUTE_OFF` and returns `started:off`. Same code path. Live per the ledger: `MUTE_OFF HTTP 200`, muted false. The running shell's `status().lastRoomCommand` currently reads `MUTE_OFF HTTP 200`.
- [✓] AC-3 Toggle and right-click send the discrete opposite, never `MUTE_TOGGLE`. `toggleMute()` is `setMuted(!muted)` (`Service.qml:995-997`, test `:861`), and the panel right-click calls `session.toggleMute()` (`Panel.qml:632`). The right-click itself was not clicked live; the evidence is static only.
- [✓] AC-4 Nothing posts `MUTE_TOGGLE`. `rg MUTE_TOGGLE Service.qml Panel.qml` returns no matches (re-run by the auditor, exit 1). Test at `tests/director-client.test.js:858`.
- [✓] AC-5 Two `setMute on` calls during power-on leave `IS_MUTED` true. The only evidence is the ledger's live run: room off, then `selectSource listen 434` followed by two `setMute on` calls, and `muted: true` from +2 s to +15 s. The auditor could not re-run it, because write IPC was off-limits.
- [✓] AC-6 `lastRoomCommand` records `<CMD> HTTP <status>` or `<CMD> <error>`. The `_roomCommand` callback (`Service.qml:1052-1054`) sets `command + " " + (err || ("HTTP " + status))`, and `_finishHttp` passes `(err, body, status)` (`Service.qml:1281-1291`). The field is exposed in `status()` (`:1833`) and covered by tests `:865-868`. The auditor's live read showed `MUTE_OFF HTTP 200`.
- [✓] AC-7 `status().volumeCaps` returns raw flags, `null` when absent, and no other fields. Implemented in `DirectorClient.js:823-843` and wired in `Service.qml:1834`. Tests `:447-463` cover the exact key list, raw `"True"`/`"False"` strings, absence of names, the no-capabilities case, missing ids, and null items. The auditor's live read on Listen showed `video: null` and `audio: {id: 434, all null}`, which matches ledger E2.
- [✓] AC-8 `setVolume` is unchanged. There is no diff hunk in `setVolume` (`Service.qml:978-987`), the existing `SET_VOLUME_LEVEL` body test is intact (`:439-440`), and the ledger records E5 live.
- [✓] AC-9 SKILL.md documents the new `setMute` return and the power-on wait. `skills/control4/SKILL.md:41` lists `started:on`/`started:off` and contains no `ok:unchanged`, and Workflow step 5 (`:75-77`) is the power-on wait. Both installed copies (live plugin folder and `~/.agents/skills/control4/SKILL.md`) are byte-identical to the repo copy.
- [✓] AC-10 With no connection or no focused room, the existing tokens are returned and nothing is posted. `setMute` calls `_agentRoomGuard()` first, which the regex test at `:836-840` checks. `_roomCommand` also returns early when not connected or roomless (`Service.qml:1050-1051`).

## Changes
- [✓] Change 1 adds `setMuted(on)` and reimplements `toggleMute()` on top of it: `Service.qml:989-997`.
- [✓] Change 2 makes IPC `setMute` drop `ok:unchanged`: `Service.qml:1783-1794`.
- [✓] Change 3 adds the `_lastRoomCommand` property (`Service.qml:95`), the callback (`:1052-1054`), and the `status()` fields (`:1833-1834`).
- [✓] Change 4 adds `DirectorClient.volumeCaps` / `_volumeCapsOf` (`DirectorClient.js:823-843`). The test harness reaches them through its `vm` context load (`tests/director-client.test.js:7-11, 24`).
- [✓] Change 5 adds tests: the `MUTE_ON`/`MUTE_OFF` body loop (`:441-445`), `volumeCaps` fixtures (`:447-463`), and static mute/probe assertions (`:857-868`). `node tests/director-client.test.js` prints `ok` (re-run by the auditor).
- [✓] Change 6 updates SKILL.md and the README mirror. SKILL.md is updated. `README.md:145` only says "See the skill for return values", so no README edit was needed. The installed skill copy is refreshed (`cmp` identical).
- [✓] Change 7 deploys the live copy. `cmp` shows the repo and live plugin folder are identical for `Service.qml`, `DirectorClient.js` and `skills/control4/SKILL.md`, and `omarchy plugin validate` exits 0. The running shell answers `status()` with `lastRoomCommand` and `volumeCaps`.

## Open items (if any)
- Fix 5 (ramp fallback) is SKIPPED. The spec made it conditional on E1/E2, and the engineer reports E2 showed `discreteVolume: "true"` for Great Room Display 443, which refutes the trigger. The reason is concrete.
- E6 (Watch-mode `setVolume` on a healthy controller) is SKIPPED. The spec marked it optional. The reason given is that it wasn't re-run after the controller reboot. That is concrete, but see the first audit note.

## Audit notes
- **The title symptom was not fixed by code; it was attributed to controller health.** The delivery changes mute and adds observability. It ships no change to the volume path, by design: AC-8 says to keep it. Prompt Listen volume after the reboot (E5) is ledger evidence. Watch-mode volume, the original "never takes" case, was not re-tested after the reboot. Whether the Great Room Watch volume works now rests on inference: Listen works, and 443 reports discrete volume. The Kickoff states this honestly.
- **The live-only criteria have no evidence the auditor could reproduce.** AC-5 and the E2/E4/E5 results come only from the ledger, because write IPC was prohibited for this audit. The read-only probes the auditor could run are consistent with them.
- **The running shell's `status()` is stale.** It still returns temporary debug keys (`httpPending`, `httpPendingSeconds`, `httpQueue`, `httpRunning`, `ignoreHttpExit`, `refreshDueInSeconds`, `tokenAgeSeconds`, `volumePending`, `volumeTimerRunning`). The repo and live `Service.qml` do not emit them: the diff adds only `lastRoomCommand` and `volumeCaps`, and `cmp` matches. They go away on the next `omarchy restart shell`. None of them is a credential, but restart the shell before relying on `status()` output.
- **AC-3's right-click path was verified statically, not exercised live.** The panel calls the same `toggleMute()` that IPC `toggle` uses.
- **The diff stays in scope.** Everything else in the diffed files (`agentState`, `agentRooms`, `parseVolumeArg`, `parseIdArg`, the other IPC methods, and their tests) belongs to the prior `agent-skill` delivery, as stated in the invocation.
