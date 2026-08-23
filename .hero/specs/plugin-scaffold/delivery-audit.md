# Delivery audit — plugin-scaffold

**Audited:** untracked plugin files vs `/dev/null` (repo has no commits); live copy at `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/`
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] Live `omarchy plugin validate` reports a valid `bar-widget` whose entry point exists — `manifest.json` `kinds: ["bar-widget"]`, `entryPoints.barWidget: "BarWidget.qml"`; live dir contains `BarWidget.qml`; ledger: validate exit 0 against the live folder
- [✓] `qmllint -I /usr/share/omarchy/shell` on live QML exits without error — live `BarWidget.qml` and `Panel.qml` present and identical to repo; ledger: exit 0, no warnings
- [✓] Left-click `C4` chip toggles nested panel — `BarWidget.qml:64-75` (`WidgetButton` text `C4`; right/middle ignored; else `togglePanel()`)
- [✓] Open panel shows title `Control4` and line `Not connected` — `Panel.qml:58-74` (two `Text` nodes)
- [✓] Escape closes the open panel — `Panel.qml:47-50` (`PanelKeyCatcher.onCloseRequested → root.close()`)
- [✓] `omarchy plugin list --json` includes `io.github.davydotcom.control4` — live plugin dir exists; `~/.config/omarchy/shell.json` has `"id": "io.github.davydotcom.control4"` under `right`; ledger: listed, `enabled: true`, `firstParty: false`
- [✓] `omarchy-shell shell summon io.github.davydotcom.control4 '{}'` opens nested panel — `BarWidget.qml:20-36` (`opened` / `open` / `toggle` / `togglePanel` on the bar-widget root); ledger: printed `ok`, exit 0
- [✓] `omarchy-shell shell hide io.github.davydotcom.control4` closes nested panel — `BarWidget.qml:26-28` (`close()` forward); ledger: exit 0
- [✓] Plugin ID `io.github.davydotcom.control4` in manifest `id` and both `moduleName`s — `manifest.json:3`, `BarWidget.qml:7`, `Panel.qml:7`
- [✓] SHALL NOT declare a separate `panel` kind; `Panel.qml` loaded by `BarWidget.qml` — `manifest.json:9-14` `kinds: ["bar-widget"]` only; `BarWidget.qml:53-56` `Loader` `source: Qt.resolvedUrl("Panel.qml")`
- [✓] SHALL NOT clone `omarchy.clock` or keep `omarchy.clonedFrom` / clone-ID dual identity — no `omarchy` key in `manifest.json`; ledger: list `clonedFrom: ""`
- [✓] Plugin files at git-repo root and a copy (not a symlink) under live plugins dir — five files untracked at repo root; live path is a real directory (`is_symlink=no`); `cmp` identical for all five files; no symlinks inside the live dir

## Changes
- [✓] Add `LICENSE` at repo root (MIT verbatim, Copyright 2026 David Estes) — `LICENSE:1-3`; `cmp` identical to `omarchy-mozilla-vpn-plugin/LICENSE`
- [✓] Add `manifest.json` at repo root — schema 1, namespaced id, `bar-widget` only, `BarWidget.qml` entry, Home/right, no clone/settings schema
- [✓] Add `BarWidget.qml` at repo root — `injectPanel`, `opened`/`open`/`close`/`toggle`/`togglePanel`/`popoutSwitchClosing`/`closeForPopoutSwitch`, `C4` chip
- [✓] Add `Panel.qml` at repo root — `manageIpc: false`, `barIdentity` owner, Escape/Tab, title `Control4` / `Not connected`
- [✓] Add `README.md` at repo root — placeholder add URL, local copy-develop path, usage, remove; no credentials
- [✓] Copy five files into live plugin dir, rescan, enable `--section right` — live dir is a real copy with the same five files; `shell.json` `right` contains the plugin id
- [✓] `.gitignore` — do not replace Hero block; skip extra ignores — file is only the Hero-managed block; no extra nonempty lines

## Open items (if any)

None.

## Audit notes

None.
