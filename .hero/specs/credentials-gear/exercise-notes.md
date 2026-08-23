# Exercise notes — credentials-gear

## Automated

```
node tests/director-client.test.js
# output: ok
omarchy plugin validate $HOME/.config/omarchy/plugins/io.github.davydotcom.control4
# exit 0
```

`omarchy-shell shell rescanPlugins` after copying `Panel.qml` did **not** apply the gear UI. `omarchy restart shell` did. Nested `Panel.qml` is loaded via `BarWidget.qml` `Loader { source: Qt.resolvedUrl("Panel.qml") }`.

## Live UI (Director connected)

```
omarchy restart shell
omarchy-shell shell summon io.github.davydotcom.control4 '{}'
omarchy capture screenshot fullscreen save
# /home/destes/Pictures/screenshot-2026-08-23_08-23-12.png
omarchy-shell shell hide io.github.davydotcom.control4
```

Observed:
- Bar chip `Deck`.
- Panel title `Control4` with a gear on the right, status `Connected`.
- No Controller IP / Email / Password / Connect fields.
- Room buttons: Base Fam, Deck (selected), Great Room, Office.

Gear click and auth-failed auto-open were not tapped this pass.
