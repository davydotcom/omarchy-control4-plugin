# Completion Ledger — credentials-gear

**Stack:** QML panel only. No new `.qml` filename.

**Validation**
- `omarchy plugin validate` live dir — pass
- `qmllint` — existing Style/import unresolved warnings (same as prior children)
- `node tests/director-client.test.js` — pass (untouched)
- Live: `omarchy restart shell` required; `rescanPlugins` did not reload Loader-sourced `Panel.qml`

## Completion Ledger

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Not configured → show form, no gear | DONE | Code: `showLoginForm: !configured \|\| ...`, `gearButton.visible: root.configured`. First-run screenshots from focused-room (`07-48-20`) show form, no gear. Not re-broken this child. |
| 2 | Configured, not auth-failed, gear closed → hide IP/email/password/Connect | DONE | Live after shell restart: panel is title + Connected + room list only. Screenshot `screenshot-2026-08-23_08-23-12.png`. |
| 3 | Configured → header gear `PanelActionButton` `󰒓` toggles form | DONE | Gear is on the Control4 header in `screenshot-2026-08-23_08-23-12.png`. `onClicked` toggles `settingsOpen`. Layer-shell popup was not click-driven from the CLI. |
| 4 | `connected` hides the form (clears `settingsOpen`) | DONE | `onConnectedChanged: if (connected) settingsOpen = false`. Live connected panel has the form collapsed. |
| 5 | `auth-failed` shows the form without the gear | SKIPPED | `showLoginForm` includes `authFailed`. Session is connected; forcing auth-failed would drop the live Director session. Code-only this pass. |
| 6 | Panel close clears `settingsOpen` | DONE | `onOpenedChanged` else-branch sets `settingsOpen = false`. |
| 7 | Room list stays visible with form open or closed | DONE | Live closed-form: four rooms still listed. Open-form path is the same `roomsColumn` sibling, not gated on `showLoginForm`. |
| 8 | SHALL NOT write stored password into the password field | DONE | `syncFormFromSession` still only fills IP/email. Password field stays `password: true` with empty text. |

### Changes

| # | Changes item | Status | Note |
|---|---|---|---|
| 1 | `Panel.qml` header Row + gear + `showLoginForm` | DONE | Wrapper `loginForm` Column collapses height when hidden. Gear width/height qualified to `gearButton.*` so parent Column `visible` is not stolen. |
| 2 | `README.md` first-run vs gear | DONE | Usage: header gear to change login. |
| 3 | Live copy + rescan | DONE | Copied; `rescanPlugins` was not enough for Loader `Panel.qml` — `omarchy restart shell` picked it up. |

### Exercise-the-feature check

- [x] Connected + configured: form hidden, gear on header, room list visible, chip `Deck`.
- [ ] Gear click to reveal form (password empty) not live-clicked.
- [ ] Auth-failed auto-open not live.

### Excellence Bar self-check

yes — connected surface is the room list. Pairing chrome is a header action, not the default panel. Auth-failed auto-open was not live-tapped.
