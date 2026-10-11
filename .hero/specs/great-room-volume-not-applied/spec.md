---
title: Great Room volume not applied and mute IPC inverts intent
slug: great-room-volume-not-applied
type: bug
status: completed
domain: engineering
size: small
severity: medium
priority: high
root_cause_class: design
created: 2026-10-11
tags: [omarchy, control4, volume, mute, ipc, agents]
relates-to:
  - room-volume-mute-off
  - agent-skill
  - in-process-director-rest
  - volume-slider-reads-room-name
delivery_method: manual
completed_at: 2026-10-11T13:02:02Z
---
# Great Room volume not applied and mute IPC inverts intent

## Kickoff

In the Great Room, volume set from the panel or the agent IPC doesn't stick. In Watch it never takes, and in Listen it lands 7–12 s late. The agent's `setMute on` can also end up unmuted.

**Status:** delivered. Discrete `MUTE_ON`/`MUTE_OFF`, `lastRoomCommand` and `volumeCaps` in `status()`, and skill guidance landed and were live-checked. After the controller reboot, Listen volume applied within ~4 s, and the Great Room Display reports `has_discrete_volume_control: true`, so the "no discrete volume" hypothesis is refuted. The volume symptom points at the controller being unhealthy before the reboot.

**Pick up at:** nothing required. Optional: one Watch-mode `setVolume` on a healthy controller (E6) to close the Watch question for good; no ramp-fallback spec is warranted by current evidence.

→ none

**Files:** `Service.qml:978`, `Service.qml:988`, `Service.qml:1776`, `Service.qml:1796`, `skills/control4/SKILL.md:41`
**Skip:** a longer volume hold (it hides real failures from the agent's 3 s confirm); blaming the navigator long-poll (it runs on its own `navProc`).

## Summary

### Categorization
| Attribute | Assessment |
|-----------|------------|
| **Criticality** | medium. The main-room volume control doesn't work in Watch, and the agent's flagship "volume to 30" fails there. A hardware remote or the Control4 app works around it. No data or safety risk. |
| **Ease of Fix** | easy for mute (discrete commands) and the probe. moderate if Watch needs a ramp (`PULSE_VOL_UP`/`DOWN`) fallback. |
| **Caused by our codebase?** | Partly. Mute inversion: yes. Watch volume: most likely the room's AV configuration (endpoint capability). The plugin's design gap is assuming every volume path accepts `SET_VOLUME_LEVEL` and reports `CURRENT_VOLUME`. |
| **Needs more research?** | Yes, for the Watch volume path only. One read-only check (E1/E2) settles whether the Great Room Display's volume device has `has_discrete_volume_control`. The mute fix doesn't need it. |

### Background
The volume feature (`room-volume-mute-off`) was verified live on 2026-08-23 in an unrecorded room, almost certainly not on the Great Room Display path. Today's agent IPC (`agent-skill`) calls the same `root.setVolume` / `root.toggleMute` the panel calls, so it exposed the gap in the house's main room.

### Analysis
The plugin sends exactly what pyControl4 sends: `SET_VOLUME_LEVEL {LEVEL}`, posted async to `/api/v1/items/13/commands`. Its single FIFO HTTP queue delivered the POST before the very `state` readings that showed volume 62. So the Director received the command, and `CURRENT_VOLUME` (which the Director updates only on the volume device's `VOLUME_LEVEL_CHANGED` feedback) did not move:
- In Watch it never moved.
- In Listen it moved 7–12 s after power-on.

Mute uses `MUTE_TOGGLE`, and the IPC decides whether to send it from the local `muted` flag. While the room is powering on, that flag can be stale, so two "on" requests become two toggles.

### Root Cause
Two related defects.

1. **Volume (design, external trigger).** The plugin assumes every room audio path accepts discrete `SET_VOLUME_LEVEL` and reflects it in `CURRENT_VOLUME`. On the Great Room's Watch path (Great Room Display, item 443), the volume endpoint most likely has no discrete volume control (ramp/IR only) or sends no volume feedback. The Director therefore ignores the level, or applies it without updating `CURRENT_VOLUME`. In Listen (Apple Music, 434) the endpoint applies the command late, around its power-on window. After 1.5 s the panel shows the Director's stale value, which reads as "didn't apply".
2. **Mute (code/design, confirmed).** `toggleMute()` posts `MUTE_TOGGLE`, and IPC `setMute on|off` chooses between `ok:unchanged` and a toggle by comparing against `root.muted`. A non-idempotent command plus stale local state can invert intent. The Director supports discrete `MUTE_ON` / `MUTE_OFF` room commands (pyControl4 `set_mute_on` / `set_mute_off`).

### Source
`Service.qml` `setVolume` / `toggleMute` / `refreshVolume` / `_roomCommand` / IPC `setMute`; `Panel.qml` slider right-click; `skills/control4/SKILL.md` `setMute` contract.

### Fix Direction
Send discrete `MUTE_ON` / `MUTE_OFF` for intent-based mute (agent and panel). Make room-command results and the playing devices' volume capabilities visible in the maintainer `status()` probe, so the Watch hypothesis can be confirmed without curling the controller. If E1/E2 show the Display lacks discrete volume, a follow-up adds a capability-gated −/+ ramp fallback.

---

## Problem Statement

Reported 2026-10-11 by the maintainer (David Estes) after delivering `agent-skill`. Room: Great Room (id 13). All calls go through `omarchy-shell io.github.davydotcom.control4 …`. `state` returns Director-polled values once the 1.5 s hold has passed.

| Run | Sequence | Observed |
|---|---|---|
| Watch A | room off, vol 62 → `selectSource watch 443` → ~4 s → `setVolume 25` (`started:25`) → +4 s; `setMute on`, `setMute off` | power on, **volume 62**. Mute on/off **did** reflect within ~4 s each. |
| Watch B | `selectSource watch 443` → wait 10 s (on, 62) → `setVolume 25` → +4 s, +7 s | **volume 62** both times. Stayed 62 after `off`. |
| Listen | room off, vol 62 → within ~0.5 s: `selectSource listen 434`, `setMute on` (`started:on`), `setVolume 10` (`started:10`) → +4 s, +7 s; at ~+8 s `setMute on` again (`started:on`) → ~+12 s | +4/+7: on, Apple Music, **62, unmuted**. +12: **10, unmuted**, stable for 20+ s. |

Read-only `state` during this investigation (08:3x): `power:on, playingGroup:listen, playingName:Apple Music, volume:10, muted:false`. `status`: `navPhase:""`, `browseOpen:false`, `hasToken:true`, session connected. Unit tests: `node tests/director-client.test.js` → `ok`.

## Environment Details

- Director REST over HTTPS, JWT from the cloud. One in-process session (`in-process-director-rest`).
- Great Room 13. Watch source "Great Room Display" 443 (the TV itself). Listen source Apple Music 434 (MSP). The Great Room Watch list also contains Base Fam's Sony receiver 370 (`watch-receiver-audio-options`), so the room's audio topology is non-trivial. Which device is the Great Room's volume endpoint per source is **unknown** (configured in Composer).
- Driverworks: room `CURRENT_VOLUME` follows the volume device's `VOLUME_LEVEL_CHANGED (LEVEL, OUTPUT)` notification. Proxy capability `has_discrete_volume_control` means "capable of directly specifying a volume setting". The SDK example falls back to volume up/down when it's `False` ([proxy docs](https://snap-one.github.io/docs-driverworks-proxyprotocol/), [XML capabilities](https://snap-one.github.io/docs-driverworks-xml/)).
- pyControl4 room ([room.html](https://lawtancool.github.io/pyControl4/room.html)): `set_volume` → `SET_VOLUME_LEVEL {"LEVEL": n}`; `set_mute_on` → `MUTE_ON`; `set_mute_off` → `MUTE_OFF`; `toggle_mute` → `MUTE_TOGGLE`; `set_increment_volume` / `set_decrement_volume` → `PULSE_VOL_UP` / `PULSE_VOL_DOWN`. It says nothing about capability gating; discrete volume depends on the endpoint driver.

---

## Root Cause Analysis

### Ruled out (confirmed by code reading)

1. **Navigator long-poll blocking the volume POST: no.** The navigator runs on its own `navProc` (`Service.qml:1589-1609`) with its own config (`curlNavConfigText`, 35 s max-time, `DirectorClient.js:331-355`). All REST GET/POST, including volume, go through `httpProc` (`Service.qml:1555-1587`) via `_enqueue` / `_pump` (`:1223-1238`). A 35 s long-poll cannot block them.
2. **Curl queue dropping or delaying the POST: no.** `_queue` is strict FIFO with one `httpProc` (`_pump` only starts a job when `!httpProc.running && !_pending`). Only `_abortHttp` clears it (`:167-181`), and only `connectNow()` / `disconnect()` call that. Neither runs during a connected session unless the state goes `error` (the watchdog), and `state` showed `connected` throughout. Every `_finishHttp` branch calls the callback and then `_pump()` (`:1253-1296`), so the queue can't stall without the 20 s max-time (`DirectorClient.js:314`) ending it.
   - **FIFO proof from the Listen run:** `selectSource`, `setMute` and `setVolume` were enqueued within ~0.5 s. The `state` at +4 s already showed the room **on** with Apple Music. That reading comes from a poll GET that had to run after the `SELECT_AUDIO_DEVICE` POST. Polls start every 2 s, so by +4 s (and certainly +7 s) a GET enqueued **after** the `SET_VOLUME_LEVEL` POST had completed. FIFO means the POST went out first. The Director had the command and still reported 62. Same in Watch: mute toggles enqueued in the same way reflected within ~4 s, so the queue was flowing.
3. **`_volumePending` stuck: no.** Every callback path clears it (`:1015`), and `_abortHttp` clears it for the dropped callback (`:172`). A stuck flag would also freeze power and now-playing, but they updated.
4. **`_volumeGen` mismatch dropping responses: no.** `_volumeGen` only increments when `_volumePending` is false (`:1009-1012`), so at most one volume GET is in flight and its `gen` always matches.
5. **Hold window masking: not the cause.** The hold is 1.5 s (`:984`). Readings at +4/+7 s are past it and show `parsed.volume` from the Director (`:1036-1039`).
6. **Wrong command or params: no.** `commandBody` → `{"async":true,"command":"SET_VOLUME_LEVEL","tParams":{"LEVEL":n}}` (`DirectorClient.js:131-138`; test `tests/director-client.test.js:439`), identical to pyControl4.
7. **Parse error: no.** `parseRoomVolume` reads `varName` `CURRENT_VOLUME` (`DirectorClient.js:593-631`), and the same parse later read 10.

### Volume: leading hypothesis (not yet confirmed; needs E1/E2)

- **Watch / Great Room Display:** the room's volume device for this path lacks discrete volume (ramp/IR-only TV or ARC path). The Director then ignores `SET_VOLUME_LEVEL`, and `CURRENT_VOLUME` stays at its last known 62. Alternative within the same class: the device applies discrete volume but never sends `VOLUME_LEVEL_CHANGED`, so the TV changed and the Director didn't. **Supporting:** two tries, including one 10 s after power-on, never moved. Mute does reflect, and the Director can track `IS_MUTED` itself for toggle-capable endpoints. **Confidence: medium (~60%).** Can't confirm without reading item 443's `capabilities` or watching the TV, both off-limits for this investigation.
- **Listen / Apple Music:** the volume device (likely different, and discrete-capable, since 10 eventually landed) applied or reported the level only after its power-on settle (somewhere between +7 s and +12 s). The plugin did nothing wrong. After the 1.5 s hold it truthfully showed the Director's 62. **Confidence: medium-low.** The +12 s landing came right after the second mute POST, which may be coincidence. One sample.

### Mute: confirmed (code)

`Service.qml:1776-1786`:
- `setMute on` while `root.muted` is false calls `toggleMute()`. That sets `muted = true` locally, holds 1.5 s, and posts `MUTE_TOGGLE`.
- After 1.5 s the poll overwrites `muted` with the Director's `IS_MUTED`. During power-on that is still false, because the toggle hasn't been applied or reported yet.
- A second `setMute on` therefore sees `muted == false` and sends **another** `MUTE_TOGGLE`. If both are applied late, as volume was in this window, they net to **unmuted**, which matches the final state.
- The reverse also fails: `setMute off` returns `ok:unchanged` without posting whenever the stale local flag already reads false.

The panel's right-click (`Panel.qml:632` → `toggleMute()`) has the same non-idempotency. It's less visible because a person clicks again.

---

## Code Flow (End to End)

1. `Panel.qml:630` slider `onReleased` → `session.setVolume(v)`; IPC `setVolume` `Service.qml:1766-1774` → `parseVolumeArg` → `root.setVolume(n)`.
2. `Service.qml:978-986` `setVolume`: clamps, sets `volume = n`, sets `_volumeHoldUntil = now + 1500`, then `_roomCommand("SET_VOLUME_LEVEL", { LEVEL: n })`.
3. `Service.qml:1044-1048` `_roomCommand` → `directorPost(".../items/13/commands", cmd, params, function() {})`. **The result is discarded.**
4. `Service.qml:196-219` `directorPost` / `_directorCall` → `_enqueue({ kind: "post", … })`.
5. `Service.qml:1223-1251` `_enqueue` → `_pump` → `_startHttp` → `curlConfigText` (max-time 20) → `httpProc.running = true`, config written on stdin in `onStarted`.
6. `Service.qml:1571-1587` `httpProc.onExited` → `_finishHttp` → `cb("", body, 200)` → no-op → `_pump()` next job.
7. Director: async command to room 13 → room proxy forwards to the current volume device. **CURRENT_VOLUME changes only on that device's `VOLUME_LEVEL_CHANGED`.** This is the divergence point.
8. `Service.qml:1681-1687` `volumeTimer` (2 s) → `refreshVolume` `:1000-1042` → GET `variables?varnames=CURRENT_VOLUME,IS_MUTED,POWER_STATE,…`.
9. `DirectorClient.js:593-631` `parseRoomVolume` → `Service.qml:1036-1040`: once the hold has passed, `volume` and `muted` are overwritten with Director values (62 / false).
10. IPC `state` `Service.qml:1703-1716` → `DirectorClient.agentState` returns `volume: 62`.
11. Mute: IPC `setMute` `Service.qml:1776-1786` → compares to `root.muted` → `toggleMute()` `:988-992` → `MUTE_TOGGLE` → same steps 3–9 for `IS_MUTED`.

## Key Files

### Volume / mute service
| File | Lines | Relevance |
|------|-------|-----------|
| `Service.qml` | 978–986 | `setVolume`: optimistic value, 1.5 s hold, `SET_VOLUME_LEVEL` |
| `Service.qml` | 988–992 | `toggleMute`: optimistic flip, `MUTE_TOGGLE` |
| `Service.qml` | 1000–1042 | `refreshVolume`: poll, pending/gen guards, hold, overwrite |
| `Service.qml` | 1044–1048 | `_roomCommand`: fire-and-forget, result discarded |
| `Service.qml` | 1681–1687 | `volumeTimer` 2 s |

### Transport
| File | Lines | Relevance |
|------|-------|-----------|
| `Service.qml` | 167–181 | `_abortHttp`: only queue-clearing path |
| `Service.qml` | 196–219 | `directorGet` / `directorPost` / `_directorCall` |
| `Service.qml` | 1223–1296 | `_enqueue`, `_pump`, `_startHttp`, `_finishHttp` (FIFO, single process) |
| `Service.qml` | 1555–1609 | `httpProc` (REST) vs `navProc` (navigator long-poll), separate processes |
| `DirectorClient.js` | 131–138, 310–355 | `commandBody`; `curlConfigText` 20 s, `curlNavConfigText` 35 s |
| `DirectorClient.js` | 593–631 | `parseRoomVolume` |

### Agent surface
| File | Lines | Relevance |
|------|-------|-----------|
| `Service.qml` | 1766–1786 | IPC `setVolume`, `setMute` (stale-flag comparison + toggle) |
| `Service.qml` | 1796–1826 | IPC `status()` maintainer probe (home for new debug fields) |
| `skills/control4/SKILL.md` | 41, 74–77 | `setMute` returns `ok:unchanged`; 3 s confirm workflow |
| `Panel.qml` | 630–632 | slider release → `setVolume`; right-click → `toggleMute` |

---

## Secondary Defects

1. **Room command results are discarded** (`_roomCommand`, `selectSource`, `sendRemote`: `function() {}`). A non-2xx response or a curl failure is invisible to the panel, the agent and the maintainer. The agent-skill spec accepted this, but it's why this bug couldn't be settled from logs. Async commands usually return HTTP 200 `{}` even when the device ignores them (seen in `watch-receiver-audio-options`), so this is observability, not a fix.
2. **`ok:unchanged` short-circuit trusts stale local state** (`Service.qml:1782`). With discrete commands, re-sending is harmless and correct.
3. **The skill's single 3 s confirmation is too early right after a power-on.** In the Listen run, volume landed 7–12 s after `selectSource`. The skill should tell the agent to wait until `power` is `on` before setting volume/mute after turning a room on, and not to retry mute.
4. **`refreshVolume` sets `muted = false` when `IS_MUTED` is absent** (`:1040`, `parsed.muted === true`). Minor; it can flash unmuted if the variable is missing. Not observed here.

## Notes

- `agent-skill` delivery-audit already flagged "Volume did not take effect live … stayed 62", and its kickoff names this slug.
- The panel's slider "snapping back" to 62 after 1.5 s is the plugin correctly showing the Director. Don't "fix" it with a longer hold: the agent confirms at 3 s and would read its own optimistic value.

---

## Suggested Fix Approach

### 1. Discrete mute: `Service.qml` `toggleMute` (`:988-992`)

**Before**
```qml
  function toggleMute() {
    muted = !muted
    _volumeHoldUntil = Date.now() + 1500
    _roomCommand("MUTE_TOGGLE", {})
  }
```

**After**
```qml
  function setMuted(on) {
    muted = on === true
    _volumeHoldUntil = Date.now() + 1500
    _roomCommand(muted ? "MUTE_ON" : "MUTE_OFF", {})
  }

  function toggleMute() {
    setMuted(!muted)
  }
```

**Why:** both the panel right-click and the IPC now send the state the user saw or asked for, and the Director sets it idempotently. Repeats no longer invert.

### 2. IPC `setMute`: `Service.qml` (`:1776-1786`)

**Before**
```qml
      if (value !== "on" && value !== "off" && value !== "toggle")
        return "bad-mute:" + value
      if (value !== "toggle" && (value === "on") === root.muted)
        return "ok:unchanged"
      root.toggleMute()
      return "started:" + (root.muted ? "on" : "off")
```

**After**
```qml
      if (value !== "on" && value !== "off" && value !== "toggle")
        return "bad-mute:" + value
      if (value === "toggle")
        root.toggleMute()
      else
        root.setMuted(value === "on")
      return "started:" + (root.muted ? "on" : "off")
```

**Why:** `on` / `off` always post a discrete command, so stale local state can't skip or invert it. This **changes the agent contract**: `ok:unchanged` is no longer returned. Update `skills/control4/SKILL.md:41` (`setMute` → `started:on` / `started:off`) and README `:145` if it lists return values.

### 3. Maintainer probe: `Service.qml` `_roomCommand` (`:1044-1048`) and `status()` (`:1796-1826`)

**Before**
```qml
    directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, params || {}, function() {})
```

**After**
```qml
    directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, params || {}, function(err, body, status) {
      root._lastRoomCommand = command + " " + (err || ("HTTP " + status))
    })
```

Add `property string _lastRoomCommand: ""` and, in `status()`:
- `lastRoomCommand: root._lastRoomCommand`
- `volumeCaps: DirectorClient.volumeCaps(root._items, root.currentVideoDeviceId, root.playingAudioDeviceId)`

New pure helper `DirectorClient.volumeCaps(items, videoId, audioId)` returns, for each of the two ids, `{ id, discreteVolume, upDownVolume, discreteMute, toggleMute }`. Values are the **raw** `item.capabilities.has_discrete_volume_control` / `has_up_down_volume_control` / `has_discrete_mute_control` / `has_toggle_mute_control`, stringified, or `null` when absent. They stay raw because the Director's spelling (`true` vs `"True"`) is unverified, and `_truthyFlag` doesn't accept `"True"`. It must not include anything beyond these ids and flags (the `status()` no-secrets rule).

**Why:** it answers the Watch hypothesis from the running plugin without curling the controller, and shows whether room commands return 200. Caveat: the room's volume endpoint may be neither the video nor the audio source item (e.g. a receiver or amp downstream). A `null` or `true` result there is inconclusive, and E2 then decides.

### 4. Skill guidance: `skills/control4/SKILL.md` Workflow step 5

Add: "After `selectSource` turns a room on, wait until `state.power` is `on` and about 5 s more before `setVolume` / `setMute`. Volume can take up to ~10 s to show after a power-on. Report it unconfirmed rather than re-sending."

### 5. (Conditional, follow-up spec): ramp fallback

**Only if** E1/E2 confirm the Great Room Display path lacks discrete volume: gate the slider on the volume device's `has_discrete_volume_control`, and show −/+ rows posting `PULSE_VOL_DOWN` / `PULSE_VOL_UP` otherwise. The IPC `setVolume` would then return a distinct token (e.g. `unsupported:discrete-volume`). This needs the room's actual volume-device mapping and is **not** part of this bug's delivery.

## Changes

1. `Service.qml`: add `setMuted(on)` posting `MUTE_ON` / `MUTE_OFF`, and reimplement `toggleMute()` as `setMuted(!muted)` (fix 1).
2. `Service.qml` IPC `setMute`: drop `ok:unchanged`; `on`/`off` → `setMuted`, `toggle` → `toggleMute` (fix 2).
3. `Service.qml`: `_lastRoomCommand` property set from the `_roomCommand` callback; `status()` gains `lastRoomCommand` and `volumeCaps` (fix 3).
4. `DirectorClient.js`: add pure `volumeCaps(items, videoId, audioId)` and export it the way other helpers are exported to tests (fix 3).
5. `tests/director-client.test.js`: `commandBody("MUTE_ON")` / `("MUTE_OFF")` shape; `volumeCaps` fixtures (fix 3, tests below).
6. `skills/control4/SKILL.md`: `setMute` returns `started:on|off`; power-on wait guidance (fixes 2, 4). Mirror any return-value text in `README.md:145`. Reinstall the skill copy (`~/.agents/skills/control4/SKILL.md`) per README.
7. After delivery, copy `Service.qml`, `DirectorClient.js` and `skills/` to `~/.config/omarchy/plugins/io.github.davydotcom.control4/`, then confirm with `qs ipc -n -p /usr/share/omarchy/shell show` or `omarchy restart shell`.

## Acceptance Criteria

- **AC-1:** WHEN IPC `setMute on` is called with a focused room while connected THE SYSTEM SHALL post `MUTE_ON` to `/api/v1/items/<focusedRoomId>/commands` and return `started:on`, regardless of the current `muted` value
- **AC-2:** WHEN IPC `setMute off` is called with a focused room while connected THE SYSTEM SHALL post `MUTE_OFF` and return `started:off`, regardless of the current `muted` value
- **AC-3:** WHEN IPC `setMute toggle` is called or the user right-clicks the volume slider THE SYSTEM SHALL post `MUTE_OFF` if `muted` is true and `MUTE_ON` otherwise, and SHALL NOT post `MUTE_TOGGLE`
- **AC-4:** THE SYSTEM SHALL NOT post `MUTE_TOGGLE` from any panel or IPC path
- **AC-5:** WHEN two IPC `setMute on` calls are made back to back during a room power-on THE SYSTEM SHALL leave the Director's `IS_MUTED` true once it settles (live, E4)
- **AC-6:** WHEN any room command completes THE SYSTEM SHALL record `<COMMAND> HTTP <status>` or `<COMMAND> <error>` and expose it as `lastRoomCommand` in IPC `status()`
- **AC-7:** WHEN IPC `status()` is called THE SYSTEM SHALL include `volumeCaps` with the raw discrete/up-down volume and discrete/toggle mute capability values of the current video and playing audio device items, or `null` when absent, and no other item fields
- **AC-8:** THE SYSTEM SHALL keep `setVolume` sending `SET_VOLUME_LEVEL { LEVEL }` with the existing 1.5 s hold, so a `state` read 3 s later reflects the Director, not the request
- **AC-9:** THE SYSTEM SHALL document in `skills/control4/SKILL.md` that `setMute` returns `started:on|off` (no `ok:unchanged`) and that volume/mute after a power-on should wait for `power: on`
- **AC-10:** IF `setMute` is called while not connected or with no focused room THEN THE SYSTEM SHALL return the existing `not-connected:<state>` / `no-room` tokens and post nothing

## Test Plan

### Existing test review
- `tests/director-client.test.js:77-78, 439`: `commandBody` shapes (`SELECT_AUDIO_DEVICE`, `SET_VOLUME_LEVEL`).
- `:422-498`: `parseRoomVolume` volume, mute, power, media ids.
- `:775-809`: `agentState` key whitelist / no secrets; `parseVolumeArg`.
- No QML tests exist; IPC behavior is verified live (precedent: `agent-skill`).

### Test changes needed
- `commandBody("MUTE_ON", {})` and `("MUTE_OFF", {})` → `async: true`, exact command, empty `tParams`.
- `volumeCaps`:
  - TV-shaped item with `has_discrete_volume_control: true` and `has_toggle_mute_control: true` → raw strings.
  - Item without `capabilities` → all `null`.
  - Missing ids → `null` entries.
  - String `"False"` stays `"False"`, not coerced.
  - Output JSON contains only `id` and the four flag keys (no `name`, no extra fields).
- `agentState` whitelist test unchanged (`status()` is not `agentState`).

### Regression scope
- Panel right-click mute still flips the icon and dims the slider (optimistic `muted`).
- Volume slider and IPC `setVolume` unchanged.
- `status()` still returns no credentials, controller IP, tokens or navigator ids (`navDebug` is unchanged).
- `node tests/director-client.test.js` passes.

## Live experiments to run

Ordered safest first. **E1–E2 send nothing to the house.** E3+ change the Great Room; run only with the maintainer present, one command at a time, at modest levels (never above the current level + 10, and nothing while someone is relying on the room). The investigating agent ran none of these.

- **E1 (zero-risk, Control4 app):** on a phone, open Great Room → Watch → Great Room Display **without changing anything** (if the room is on another source, just look at the volume card on the room screen). Does the room volume control show a **slider** (discrete) or only **− / +** (ramp-only)? Repeat the look on the Listen → Apple Music screen. A − / + on Watch confirms the leading hypothesis.
- **E2 (zero-risk, after Change 3 ships):** `omarchy-shell io.github.davydotcom.control4 status` while the room is on each source (read-only). Record `volumeCaps` for video id 443 and the Listen audio id. `discreteVolume` not true on the Watch path confirms it. All-`null` means the volume endpoint is a different item; ask the dealer/Composer which device is the Great Room's volume control for Watch.
- **E3 (read-only polling while Listen is already playing):** run `state` every 2 s for 30 s, with no commands, to establish a steady `volume` / `muted` baseline (currently 10 / false).
- **E4 (one discrete mute, Listen already on, after Change 1 ships):** `setMute on`; `state` at +3 s and +6 s → expect `muted: true`. `setMute on` again → still true (idempotent). `setMute off` → false. Then check `status().lastRoomCommand` reads `MUTE_OFF HTTP 200`. If `MUTE_ON` / `MUTE_OFF` don't reflect, record that and revert to `MUTE_TOGGLE` + discrete-intent fallback (stop; don't improvise).
- **E5 (one modest volume, Listen already on and settled > 30 s):** `setVolume 14` (current 10 + 4). `state` at +3, +6, +10 s. Expect 14 by +3 s once the room is past power-on, which would confirm the Listen delay was power-on latency, not the plugin. Then `setVolume 10` to restore.
- **E6 (Watch, only if E1/E2 are inconclusive):** with the maintainer watching the TV's on-screen volume, select Great Room Display, wait 15 s, `setVolume` to (current + 4). Note (a) whether the TV's OSD/volume changes and (b) `state.volume` at +3/+10 s. TV changes but `state` doesn't means no feedback; neither changes means command ignored (no discrete volume). Restore with the TV remote, and do not use `off` unless the maintainer wants the room off.

## Boundaries

- Not the ramp fallback UI (fix 5). That's a follow-up spec once E1/E2 confirm.
- Not multi-room / group volume (`multi-room-volume-view`).
- No longer hold window, no "wait for Director to match" retry loop.
- No new Director endpoints; `MUTE_ON` / `MUTE_OFF` go to the existing room `/commands` path (`in-process-director-rest`).
- Not changing the volume poll interval or transport queue (ruled out).

## Risks

- `MUTE_ON` / `MUTE_OFF` are documented by pyControl4 and Driverworks, but not yet exercised on this Director (OS 4.2). If the room ignores them, mute breaks outright, worse than today's toggle. E4 must pass before release; revert path is `MUTE_TOGGLE`.
- Endpoints with toggle-only mute (`has_toggle_mute_control` without discrete) depend on the Director translating `MUTE_ON` / `MUTE_OFF` using its own state. That's expected for room proxies but unverified.
- Dropping `ok:unchanged` is an agent-contract change. Any installed copy of the skill must be refreshed.
- `volumeCaps` may not point at the true volume endpoint (see fix 3 caveat). Don't treat `null` as "unsupported".

## Validation

1. `node tests/director-client.test.js` passes with the new fixtures.
2. `rg "MUTE_TOGGLE" Service.qml Panel.qml` returns nothing.
3. Live, maintainer present: E4, then E5. Record results in the Completion Ledger.
4. E1 (and E2 once shipped) answers the Watch question. File the ramp-fallback follow-up or close it as not needed.

## Recap

Volume set in the Great Room reaches the Director: the FIFO queue, poll guards and navigator are all ruled out. In Watch, the room's volume endpoint most likely can't take or report a discrete level. In Listen, the level lands late during power-on. Separately, `setMute` inverts intent because it sends `MUTE_TOGGLE` based on a stale local flag. That part is confirmed in code and fixed by discrete `MUTE_ON` / `MUTE_OFF`. Severity medium; the mute fix and probe are small, and the Watch fallback waits on one zero-risk check (E1).

## Completion Ledger

Delivered Changes 1–7 (fix 5, the ramp fallback, was conditional and is not warranted; see Outcome).

**Validation**
- `node tests/director-client.test.js` → `ok`. `rg MUTE_TOGGLE Service.qml Panel.qml` → no matches.
- `omarchy plugin validate` on the live folder → exit 0. Live copy of `Service.qml`, `DirectorClient.js`, `skills/control4/SKILL.md` matches the repo; `~/.agents/skills/control4/SKILL.md` refreshed.
- Live, maintainer present (2026-10-11, after the controller reboot), Great Room 13:
  - E2: `status().volumeCaps` on Listen/Apple Music → `audio` 434 all `null`; on Watch/Great Room Display → `video` 443 `discreteVolume: "true"`, `upDownVolume: "true"`, `discreteMute: "true"`, `toggleMute: "true"`.
  - E5: settled Listen, `setVolume 14` → 14 by the first post-hold read (≤ 4 s), `lastRoomCommand` `SET_VOLUME_LEVEL HTTP 200`; `setVolume 10` → 10 within 4 s.
  - E4 (settled): `setMute on` → muted true; `setMute on` again → `started:on`, still true; `setMute off` → false; `lastRoomCommand` `MUTE_ON HTTP 200` / `MUTE_OFF HTTP 200`.
  - Power-on (AC-5): room off (`ROOM_OFF HTTP 200`), then `selectSource listen 434`, `setMute on`, `setMute on` back to back → `muted: true` at +2 s through +15 s, `lastRoomCommand` `MUTE_ON HTTP 200`.

**Outcome on volume:** E2 refutes the "no discrete volume" hypothesis for the Great Room Display, and E5 shows Listen volume applying promptly after the controller reboot. The earlier symptoms (Watch volume never landing, Listen landing 7–12 s late) coincide with a controller the maintainer judged unhealthy and rebooted; one more `MUTE_OFF` timed out at the 20 s curl limit and one variables GET took ~20 s shortly after the reboot. No plugin defect was found on the volume path. Watch-mode `setVolume` was not re-run after the reboot (E6, optional).

**Interim note:** a temporary set of HTTP-queue debug fields was added to `status()` during a mistaken "poll stalled" investigation and then removed; the repo and live file no longer contain them. The running shell still has that `status()` until the next `omarchy restart shell` (not restarted, to avoid disturbing playback).

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | IPC `setMute on` posts `MUTE_ON`, `started:on`, regardless of `muted` | DONE | `Service.qml:1783` → `setMuted(true)` `:989`; static test `tests/director-client.test.js:864`; live repeat `on` → `started:on` + `MUTE_ON HTTP 200` |
| 2 | IPC `setMute off` posts `MUTE_OFF`, `started:off` | DONE | same path; live `MUTE_OFF HTTP 200`, muted false |
| 3 | toggle / right-click posts `MUTE_OFF` if muted else `MUTE_ON`, never `MUTE_TOGGLE` | DONE | `toggleMute()` = `setMuted(!muted)` `Service.qml:995`; Panel right-click calls `toggleMute` (`Panel.qml:632`); static test `:860`. Right-click not clicked live (no pointer access); same function as IPC `toggle` |
| 4 | No `MUTE_TOGGLE` from any panel or IPC path | DONE | `rg MUTE_TOGGLE` empty; test `:858` |
| 5 | Two `setMute on` during power-on leave `IS_MUTED` true | DONE | live power-on run above: muted true +2 s…+15 s |
| 6 | `lastRoomCommand` records `<CMD> HTTP <status>` / `<CMD> <error>` | DONE | `Service.qml:1049` callback; live `ROOM_OFF HTTP 200`, `MUTE_ON HTTP 200`, `SET_VOLUME_LEVEL HTTP 200`, and error form `MUTE_OFF Request timed out` |
| 7 | `status()` `volumeCaps` raw flags of video/audio items, `null` when absent, nothing else | DONE | `DirectorClient.js:824-843`; tests `:447-462` (keys only, raw strings, no names, nulls); live E2 values above |
| 8 | `setVolume` unchanged (`SET_VOLUME_LEVEL {LEVEL}`, 1.5 s hold) | DONE | `setVolume` untouched in diff; live E5 |
| 9 | SKILL.md: `setMute` → `started:on` / `started:off`, wait for `power: on` after power-on | DONE | `skills/control4/SKILL.md:41,75-81`; installed copy refreshed |
| 10 | Not connected / no room → existing tokens, nothing posted | DONE | guard-first unchanged; static guard-order test still passes |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `setMuted(on)` + `toggleMute()` via it | DONE | `Service.qml:989-997` |
| 2 | IPC `setMute` drops `ok:unchanged` | DONE | `Service.qml:1783-1793` |
| 3 | `_lastRoomCommand` + `status()` fields | DONE | `Service.qml:95,1049-1053,1833-1834` |
| 4 | `DirectorClient.volumeCaps` | DONE | `DirectorClient.js:824-843`, exported to tests via the vm context |
| 5 | Tests | DONE | `MUTE_ON`/`MUTE_OFF` bodies, `volumeCaps` fixtures, static mute/probe checks |
| 6 | SKILL.md + README mirror | DONE | SKILL.md updated; README `:145` lists no return values, so no change needed |
| 7 | Deploy live copy + verify | DONE | copied, `plugin validate` 0, shell restarted once to load (08:5x), live runs above |

### Exercise-the-feature check

- [x] User-visible behavior was exercised end-to-end: live `omarchy-shell io.github.davydotcom.control4` calls on the Great Room — power-on with two `setMute on` stayed muted, settled mute on/on/off, volume 14 → 10, `status()` showing `lastRoomCommand` and `volumeCaps`; maintainer confirmed audio earlier in the session.

### Excellence Bar self-check

Yes. Mute is now idempotent from both the panel and agents, the probe made the volume question answerable from the running plugin, and it refuted the spec's leading hypothesis instead of shipping an unneeded ramp fallback.
