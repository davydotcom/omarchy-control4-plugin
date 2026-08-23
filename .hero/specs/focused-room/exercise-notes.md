# Exercise notes — focused-room

## Automated

```
node tests/director-client.test.js
# output: ok
```

Live plugin dir: `$HOME/.config/omarchy/plugins/io.github.davydotcom.control4/`
`omarchy plugin validate` on that dir: exit 0
qmllint (`/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell`) exit 0
`omarchy plugin list --json`: id `io.github.davydotcom.control4`, enabled true
Widget present in `~/.config/omarchy/shell.json` bar.layout.right

## Live UI (no Director)

Commands:

```
omarchy capture screenshot fullscreen save
# /home/destes/Pictures/screenshot-2026-08-23_07-48-18.png
omarchy-shell shell summon io.github.davydotcom.control4 '{}'
omarchy capture screenshot fullscreen save
# /home/destes/Pictures/screenshot-2026-08-23_07-48-20.png
omarchy-shell shell hide io.github.davydotcom.control4
```

Observed:
- Bar chip text is `C4` (top-right, between tray and agents).
- Summoned panel title `Control4`, status `Not configured`, fields Controller IP / Email / Password, Connect button.
- Room list not shown (session not connected) — expected.
- No `credentials.json` / `focus.json` on this machine, so Connect/room-pick/chip-name/elide/gone-id/auto-select were not live-tapped.

Do not invent a CI Director.
