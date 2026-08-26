---
title: Control4 focused-room remote
slug: control4-focused-room-remote
type: initiative
status: completed
domain: engineering
size: giant
tags: [omarchy, control4, bar-widget, av]
created: 2026-08-21
horizon: now
relates-to:
  - watch-source-virtual-remote
  - multi-room-audio
  - room-environment
child:
  - plugin-scaffold
  - director-session
  - focused-room
  - credentials-gear
  - watch-and-listen
  - listen-library-browse
  - room-volume-mute-off
  - halo-panel-chrome
  - room-now-playing
completed_at: 2026-08-23T21:06:12Z
---
# Control4 focused-room remote

## Vision

An Omarchy bar widget that behaves like a Control4 remote for one focused room. The bar chip shows that room. The nested details panel is the remote: pick the room, Watch or Listen to a source, then volume, mute, and room off. V1 is LAN-only AV for that room — not a whole-house dashboard and not a copy of the hardware remote overlay.

## Goal

Ship a third-party Omarchy plugin that authenticates to a local Control4 Director, keeps one room in focus, and lets the user Watch, Listen, adjust volume, mute, and turn that room off — with now-playing reflected on the chip and panel. Success is a working bar-widget on OS 3.x local REST with a cloud-issued director JWT, not feature parity with Composer or the Control4 app.

## Kickoff

Omarchy widget that acts like a Control4 remote for one focused room: Watch, Listen, volume, mute, off.

**Status:** planning — `plugin-scaffold` and `director-session` completed; `focused-room` designed.

**Pick up at:** `/deliver focused-room` — join ui_configuration watch/listen to items, persist focus.json, chip shows the room name.

→ `/deliver focused-room`

**Files:** `.hero/planning/features/focused-room/spec.md`, `Service.qml`, `Panel.qml`, `BarWidget.qml`

**Skip:** Python sidecar, HA proxy, second Quickshell process, overlay remote, OS 4.2 JWT workaround, lights/climate/shades/cameras.

## Follow-on initiatives

Scoped 2026-08-23, after Watch/Listen and library browse shipped. Both are siblings, not children — this initiative stays a one-room remote.

- **`watch-source-virtual-remote`** — Watch currently selects a source and stops. That initiative renders each device's own remote (D-pad, transport, digits) from the `commands[]` and `navigator_display_option` metadata the Director already publishes in `GET /api/v1/items`.
- **`multi-room-audio`** — this initiative's deliberate one-room scope, revisited. Adds rooms to what is playing and shows per-room volume, built on `/api/v1/media_sessions`.
- **`room-environment`** — lights / climate / shades / scenes, which this house does not have. Sibling so V1 stays an AV remote. First child (`experience-switch`) opens the Halo mode row so those doors can register later without rewriting Watch/Listen.

## Specs

Ordered children. Sizes and depends-on are locked for this compose; `/design` refines each child's internals, not this sequence.

| # | Slug | Status | Size | Horizon | Depends-on | One-liner |
|---|---|---|---|---|---|---|
| 1 | `plugin-scaffold` | completed | small | now | — | Valid Omarchy `bar-widget` with nested details `Panel.qml`, placeholder chip, empty panel. |
| 2 | `director-session` | completed | medium | now | `plugin-scaffold` | In-process JWT session to LAN Director; headless `service` so auth outlives the panel. |
| 3 | `focused-room` | completed | medium | now | `director-session` | Load rooms from `ui_configuration`, persist one focus, show the name on the chip. |
| 3b | `credentials-gear` | completed | trivial | now | `focused-room` | Hide IP/email/password once set; header gear reveals them to change login. |
| 4 | `watch-and-listen` | delivering | medium | now | `focused-room` | One source-picker; Watch vs Listen only changes experience filter and select command. |
| 4b | `listen-library-browse` | planning | medium | now | `watch-and-listen` | After Listen → Apple Music, pick playlists/songs (blocked on a Director list API). |
| 5 | `room-volume-mute-off` | delivering | small | next | `focused-room` | Volume up/down, mute toggle, room off — button chrome, not a mixer. |
| 5b | `halo-panel-chrome` | planning | small | now | `watch-and-listen` | Recolor the popup to Halo Remote tokens and layout. |
| 6 | `room-now-playing` | planning | small | now | `focused-room` | Chip is the Control4 mark (on/off); panel + tooltip name the source. Designed. |

## Sequenced work items

1. **Scaffold the plugin** (`plugin-scaffold`) — new widget with ID `io.github.davydotcom.control4` from day one (do **not** clone `omarchy.clock`; that replaces the built-in clock). Land `manifest.json` + `BarWidget.qml` + nested `Panel.qml` at repo root; copy into `~/.config/omarchy/plugins/io.github.davydotcom.control4/`. `omarchy plugin validate` and `qmllint` clean against the live folder. No Control4 calls yet.
2. **Director session** (`director-session`) — add `service` kind. Customer email/password + controller IP → cloud account token → director bearer JWT → HTTPS to the LAN controller via Qt Network. Connected vs auth-failed (including 401) visible in the panel.
3. **Focused room** (`focused-room`) — `GET /api/v1/agents/ui_configuration`, skip `ROOM_HIDDEN`, flat list, persist the chosen room, chip shows its name.
4. **Watch and Listen** (`watch-and-listen`) — one picker UI. Watch filters `watch` experiences and posts `SELECT_VIDEO_DEVICE`; Listen filters `listen` and posts `SELECT_AUDIO_DEVICE`. Same list→select pattern. Do not split this child.
5. **Volume / mute / off** (`room-volume-mute-off`) — technically depends only on focused-room, but deliver after Watch/Listen so the first AV loop is source-then-volume. Prefer `PULSE_VOL_UP` / `PULSE_VOL_DOWN` over a slider unless `/design` has a reason.
6. **Now playing** (`room-now-playing`) — poll `POWER_STATE`, volume/mute, and current watch/listen source. Deliver after Watch/Listen so the chip can show a source this plugin selected.

Volume and now-playing are in this initiative (children 5–6). They are **not** in the opening `/design plugin-scaffold` pass.

## Child stubs summary

Each child lives at `.hero/planning/features/{slug}/spec.md` with `parent: control4-focused-room-remote`. Stubs carry Context, Goal, Kickoff, Approach (intent only), Boundaries, Risks, 2–5 EARS criteria, and Validation that `/design` is next. They do **not** contain a full Changes list except `plugin-scaffold`, which may name `manifest.json`, `BarWidget.qml`, and `Panel.qml` because the [Omarchy plugin contract](https://omarchyplugins.com/develop.html) already names them.

| Child | What `/design` must decide | What `/design` must not reopen |
|---|---|---|
| `plugin-scaffold` | Placeholder copy and README git-url (locked at `/design`) | Nested Panel vs separate `panel` kind; `omarchy.*` ID; clock clone; `destes` ID |
| `director-session` | Token refresh, self-signed TLS, where settings live, how `service` shares state with the widget | Python sidecar, HA proxy, 4Sight, OS 4.2 as a V1 target |
| `focused-room` | Persistence key, empty/error empty-states | Floor/location tree; hidden-room inclusion |
| `watch-and-listen` | Picker chrome, empty experience lists, command payload shape | Two separate specs; device inventory vs experiences |
| `room-volume-mute-off` | Pulse vs slider (prefer pulse), mute/off placement | Mixer UI; delivering before Watch/Listen |
| `room-now-playing` | Poll interval, chip truncation, source variable names | Shipping before Watch/Listen; lights/climate metadata |

## Dependencies

```
plugin-scaffold
      ↓
director-session
      ↓
focused-room
      ↓
      ├── watch-and-listen          (horizon: now)
      ├── room-volume-mute-off      (horizon: next; deliver after watch-and-listen)
      └── room-now-playing          (horizon: next; deliver after watch-and-listen)
```

- `plugin-scaffold` has no spec dependency. Greenfield: this repo has Hero scaffolding only. Plugin files live at repo root; the runnable copy is `~/.config/omarchy/plugins/io.github.davydotcom.control4/` (copy, not clone, not symlink).
- `director-session` needs a loadable `bar-widget` (and will add `service`) before settings UI and session lifetime make sense.
- `focused-room` needs a working Director JWT + REST client.
- `watch-and-listen`, `room-volume-mute-off`, and `room-now-playing` all need a persisted focused room id. Technical depends-on is `focused-room` only.
- **Delivery constraint (not a spec depends-on):** implement and ship Watch/Listen before volume/off and now-playing. Volume without a source is a mute remote; now-playing without Watch/Listen cannot reflect a source this plugin selected.

## Approach

Enough architecture for later `/design` passes to stay coherent. Children own the details.

**Shell shape.** One third-party plugin. Primary kind is `bar-widget`; the details surface is a nested `Panel.qml` loaded by `BarWidget.qml`, not a second manifest `panel` kind. That matches the official contract: keep `kinds: ["bar-widget"]` and `entryPoints.barWidget`, and load the panel internally ([Develop a Plugin](https://omarchyplugins.com/develop.html)). `director-session` adds a `service` kind so the Director JWT outlives panel open/close — same pattern as first-party plugins that are both `service` and `bar-widget`.

**Process and network.** In-process QML/JS using Qt Network against the local Director REST API (`https://<controller-ip>/api/v1/...`). No Home Assistant proxy. No Python sidecar. No second Quickshell process — plugins share the long-running Omarchy shell and run unsandboxed ([plugin contract](https://omarchyplugins.com/develop.html)). LAN-only: customer-account credentials plus controller IP in plugin-private config; cloud is used only to mint the director JWT.

**Auth target.** V1 is Control4 OS 3.x local REST with a cloud-issued director bearer JWT (the pyControl4 account → director token path). OS 4.2 rejecting that JWT on local `/api/v1/*` is a documented incompatibility ([pyControl4 #66](https://github.com/lawtancool/pyControl4/issues/66)), not a child of this initiative.

**Room and sources.** Rooms and Watch/Listen catalogs come from `GET /api/v1/agents/ui_configuration` ([pyControl4 director](https://lawtancool.github.io/pyControl4/director.html)), not from `/locations/rooms/.../audio_devices` (known incomplete). Experiences have `type: "watch"` / `"listen"` with source lists. Selecting a source posts `SELECT_VIDEO_DEVICE` or `SELECT_AUDIO_DEVICE` with `deviceid` on the focused room ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). That is the Control4 remote analog: Watch and Listen pick sources for the currently focused room ([SR-260 user guide](https://docs.control4.com/docs/product/system-remote-control-sr-260/user-guide/english/latest/system-remote-control-sr-260-user-guide-rev-c.pdf)).

**Identity.** Plugin ID from day one: `io.github.davydotcom.control4` (matches this author's published plugins — not `io.github.destes.control4`). Author: David Estes. License: MIT. Third-party IDs cannot use `omarchy.*`. Do **not** clone `omarchy.clock` — that replaces the built-in clock. This is a new widget: author files at this git repo's root and copy them into `~/.config/omarchy/plugins/io.github.davydotcom.control4/`.

**Unknowns deferred to `director-session` (not initiative blockers):** TLS trust for the Director's self-signed cert; JWT refresh/expiry. `/design director-session` decides those.

## Cross-cutting concerns

- **Plugin ID and live load.** Every child uses `io.github.davydotcom.control4` in `manifest.json` `id` and QML `moduleName`. Author in this git repo (plugin files at repo root); copy into `~/.config/omarchy/plugins/io.github.davydotcom.control4/` then `omarchy-shell shell rescanPlugins`. Do not clone `omarchy.clock`. Do not symlink the plugins dir to the git repo. Validate the live folder, not the git root (harness symlinks in `.claude/` / `.cursor/`).
- **Secrets.** Email/password live in plugin-private config inside an unsandboxed shell plugin. Minimize what is logged; never echo credentials into `qs log`.
- **Session vs UI.** JWT and HTTP live in the `service`; the bar chip and panel are views. Later children must not each open their own Director login.
- **Focused room as the only room context.** Watch, Listen, volume, mute, off, and now-playing all address the persisted focused room — not "whatever room the last command used."
- **Experiences, not device inventory.** Source lists come from `ui_configuration` watch/listen experiences. Do not rebuild catalogs from `/api/v1/items` or room `audio_devices` / `video_devices`.
- **LAN and OS 3.x.** No 4Sight remote access. No OS 4.2 auth fork in V1. A clear 401 is a product state, not a silent retry loop.
- **Validation tools.** `omarchy plugin validate` and `qmllint` stay green as kinds and files are added (`service` in director-session).
- **No second process.** Qt Network in-process only. A sidecar would violate the plugin contract and this initiative's boundaries.

## Boundaries

Deferred — not in this initiative, not in any child:

- Lights, climate, shades, cameras, sensors, scenes
- Overlay remote / fullscreen Control4 navigator clone
- 4Sight / remote-over-internet access
- Home Assistant as a proxy or dependency
- Control4 jailbreak or Composer-side patches
- OS 4.2 JWT 401 workaround (documented incompatibility, not a child)
- Floor/location tree for room pick (flat list only)
- Splitting Watch and Listen into two specs or two picker UIs
- Transport controls (play/pause/stop), numeric keypad, guide/channel
- Multi-room grouping, party mode, or whole-house volume
- Marketplace publish / git remote (ID is `io.github.davydotcom.control4` from day one; later work)

Volume and now-playing **are** in this initiative as children 5–6. They are out of the first `/design` only.

## Risks

- **OS 4.2 JWT 401.** Cloud-issued director tokens with `Realm: remote.control4.com:5080` are rejected on local `/api/v1/*` on OS 4.2 ([pyControl4 #66](https://github.com/lawtancool/pyControl4/issues/66)). V1 targets OS 3.x. Surface a clear 401; do not treat OS 4.2 as a silent support matrix row.
- **Secrets in an unsandboxed plugin.** The shell plugin runs with user permissions and is not sandboxed ([plugin contract](https://omarchyplugins.com/develop.html)). Credentials in plugin config are a real exposure; `/design director-session` must treat storage and logging as a risk, not an afterthought.
- **LAN-only.** No controller on the LAN, or DNS/TLS mismatch to the IP the user typed, means no session. There is no 4Sight fallback in V1.
- **Experiences vs devices.** Room `audio_devices` / `video_devices` endpoints are the devices *in* the room, not the playable catalog ([pyControl4 room](https://lawtancool.github.io/pyControl4/room.html)). Using them for Watch/Listen will look empty or wrong. Catalog = `ui_configuration` experiences.
- **Source vs live plugin dir.** This git repo is source of truth. Omarchy loads `~/.config/omarchy/plugins/io.github.davydotcom.control4/`. Edits only in the live copy desync. Do not `omarchy plugin clone omarchy.clock` — that steals the clock slot. Do not `omarchy plugin add` this dirty repo (copies `.hero/` and fails symlink validation). Validate the live folder, not the git root.
- **Self-signed Director TLS and token refresh.** Unknowns for `/design director-session`. If ignored, HTTPS calls fail or sessions die after expiry. Not initiative blockers.

## Progress

All children through Halo chrome and Watch/Listen have shipped. Live copy at `~/.config/omarchy/plugins/io.github.davydotcom.control4/`. `room-now-playing` is designed — last open child.

**Next:** `/deliver room-now-playing`

## Acceptance Criteria

Initiative-level invariants. Child `/design` passes refine per-spec criteria; these must still hold when all children are complete.

- THE SYSTEM SHALL ship as one third-party Omarchy `bar-widget` with a nested details `Panel.qml` (not a separate `panel` kind) plus a `service` added in `director-session`
- THE SYSTEM SHALL talk to a LAN Control4 Director in-process via QML/JS and Qt Network (no Python sidecar, no Home Assistant proxy, no second Quickshell process)
- WHEN the user focuses a room THE SYSTEM SHALL address Watch, Listen, volume, mute, off, and now-playing to that room only
- THE SYSTEM SHALL take Watch and Listen source lists from `ui_configuration` experiences, not from room device-inventory endpoints

## Recommended delivery order

1. `/design plugin-scaffold` then `/deliver plugin-scaffold`
2. `/design director-session` then `/deliver director-session`
3. `/design focused-room` then `/deliver focused-room`
4. `/design watch-and-listen` then `/deliver watch-and-listen`
5. `/design room-volume-mute-off` then `/deliver room-volume-mute-off` (after 4, even though depends-on is only `focused-room`)
6. `/design room-now-playing` then `/deliver room-now-playing` (after 4, so the chip can show a source this plugin selected)

Do not start `/design` on children 5–6 until Watch/Listen is at least designed. Do not implement any child from its stub — stubs are `/design` input.
