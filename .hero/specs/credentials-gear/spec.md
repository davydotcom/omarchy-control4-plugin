---
title: Credentials gear
slug: credentials-gear
type: feature
status: completed
domain: engineering
size: trivial
horizon: now
parent: control4-focused-room-remote
depends-on:
  - director-session
  - focused-room
created: 2026-08-23
tags: [omarchy, control4]
relates-to:
  - qml-new-file-shell-restart
claimed_by: david-estes
completed_at: 2026-08-23T12:28:39Z
---
# Credentials gear

## Context

Live focused-room panel still shows Controller IP, email, password, and Connect after the session is already connected. Those fields are pairing chrome. Once credentials are saved they do not belong on the remote surface; the room list does. Reconnect still has to exist. Found during `/deliver focused-room` close-out: chip is **Base Fam**, four rooms listed, login form still filling the panel.

`focused-room` originally said keep the login form because reconnect is required. This child keeps reconnect and hides the fields until the user asks.

## Goal

When credentials are set, the details panel hides IP / email / password / Connect and shows a gear on the Control4 header. The gear reveals that form so the user can change login and reconnect. First-run (not configured) still shows the form with no gear. Auth-failed auto-reveals the form. Connected room list stays visible either way.

## Kickoff

Hide the Control4 login form once credentials are saved; gear on the header reveals it to change login.

**Status:** delivering — connected panel hides IP/email/password; gear is on the Control4 header; room list remains. Gear click / auth-failed auto-open not live-tapped this pass.

**Pick up at:** click the gear to confirm the form returns with an empty password field, then close-out.

→ `/deliver credentials-gear`

**Files:** `Panel.qml`, `README.md`

**Skip:** new `.qml` filename; omarchy settings panel / `shell.json`; password echo into the field.

## Approach

**Hide on configured, not only on connected.** `Service.configured` is already `credentialsComplete(ip, email, password)`. Auto-connect on a later shell start should open the panel on the room list, not the pairing form.

**Gear is `qs.Ui` `PanelActionButton`** with Nerd Font `󰒓` (same glyph the first-party gallery uses for a settings action). Tooltip `Change login` / `Hide login` when open. Visible only when `configured`. `bordered` while the form is showing. No new `.qml` file.

**Local panel state only.** `property bool settingsOpen: false`. Do not persist. Closing the panel sets `settingsOpen = false` so the next open does not leave secrets on screen. Successful `connected` also clears `settingsOpen`.

**When the form shows**

- Not configured (first-run): always.
- Gear toggled on.
- `sessionState === "auth-failed"`: always, even if the gear is off — they have to fix email/password.

Network `error` with saved credentials does **not** auto-open the form. Status text is enough; gear is there if they want to change the host.

**Connect submit is unchanged.** Empty password field still means "keep the stored password" (`submitConnect` already skips `passwordField` when blank). Never write the stored password back into the field.

**Room list is independent of the form.** If connected, `roomsHint` + room buttons stay below, whether or not settings are open.

**Header.** Replace the lone title `Text` with a `Row`: title left, gear right. When the gear is hidden, give it width 0 so the title keeps the full row (QML `visible: false` still occupies Row space).

## Changes

1. `Panel.qml` — `settingsOpen`, `configured`, `showLoginForm`. Header `Row` with title + `PanelActionButton` gear. Bind IP/email/password/Connect `visible` to `showLoginForm`. Collapse settings on panel close and on `connected`. Auth-failed shows the form without a click.

2. `README.md` — first-run Connect; after that the panel is the room list and a gear to change login.

3. Live copy `Panel.qml` + `README.md` into `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/`. `omarchy-shell shell rescanPlugins` only.

## Boundaries

- No Watch/Listen, volume, mute, off, now-playing
- Do not add a new `.qml` filename
- Do not put credentials in `shell.json` or `focus.json`
- Do not echo the stored password into the password field
- Do not open Omarchy's first-party settings app
- Do not hide the room list while the gear form is open

## Risks

- QML `Row` still reserves space for `visible: false` children — gear must collapse width/height when hidden.
- Auth-failed without auto-open would trap the user behind a gear they may not notice.
- Collapsing the form on every `connected` also closes it after a gear-driven reconnect — that is intended.

## Acceptance Criteria

- WHEN credentials are not set THE SYSTEM SHALL show Controller IP, email, password, and Connect, and SHALL NOT show the gear
- WHILE credentials are set and `sessionState` is not `auth-failed` and the gear is not open THE SYSTEM SHALL hide IP, email, password, and Connect
- WHILE credentials are set THE SYSTEM SHALL show a header gear (`PanelActionButton`, icon `󰒓`) that toggles the login form
- WHEN `sessionState` becomes `connected` THE SYSTEM SHALL hide the login form (clear `settingsOpen`)
- WHEN `sessionState` is `auth-failed` THE SYSTEM SHALL show the login form without requiring the gear
- WHEN the panel closes THE SYSTEM SHALL clear `settingsOpen` so the next open does not show the form
- WHILE connected THE SYSTEM SHALL keep the room list visible whether or not the login form is showing
- THE SYSTEM SHALL NOT write the stored password into the password field

## Validation

Live plugin dir, not git root. No new `.qml` filename.

```
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.davydotcom.control4"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I /usr/share/omarchy/shell "$PLUGIN_DIR/Panel.qml"
omarchy-shell shell rescanPlugins
```

Manual (credentials already set, session connected):

1. Open the panel — IP/email/password/Connect are gone; gear is on the Control4 header; room list is visible.
2. Click the gear — form appears; password field is empty; room list still there.
3. Close the panel and reopen — form hidden again.
4. First-run analog (or empty credentials): form visible, no gear.
