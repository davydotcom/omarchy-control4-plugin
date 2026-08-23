# Delivery audit — credentials-gear

**Audited:** `git diff HEAD -- Panel.qml README.md`
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria
- [✓] Not configured → show form, no gear — `Panel.qml` `showLoginForm` / `gearButton.visible: root.configured`; first-run screenshots `07-48-20`
- [✓] Configured + gear closed → hide IP/email/password/Connect — live `screenshot-2026-08-23_08-23-12.png`
- [✓] Configured → header gear `󰒓` toggles form — gear visible in that screenshot; `onClicked` toggles `settingsOpen`
- [✓] `connected` hides the form — `onConnectedChanged`; live connected panel collapsed
- [~] `auth-failed` shows the form without a click — wired (`authFailed` in `showLoginForm`); SKIPPED live (session connected)
- [✓] Panel close clears `settingsOpen` — `onOpenedChanged` else-branch
- [✓] Room list stays visible — `roomsColumn` not gated on `showLoginForm`; live four rooms
- [✓] SHALL NOT write stored password into the field — `syncFormFromSession` IP/email only

## Changes
- [✓] `Panel.qml` — header Row + `PanelActionButton` gear + collapsing `loginForm`
- [✓] `README.md` — first-run vs gear
- [✓] Live copy — `omarchy restart shell` required; `rescanPlugins` did not reload Loader-sourced `Panel.qml`

## Open items (if any)
- AC auth-failed auto-open — SKIPPED — engineer: would drop live Director session — concrete

## Audit notes
- Loader-sourced `Panel.qml` does not hot-reload on `rescanPlugins`. Knowledge `qml-new-file-shell-restart` updated.
