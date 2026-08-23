# Control4

Omarchy bar widget for a Control4 focused-room remote. Plugin ID:
`io.github.davydotcom.control4`.

Left-click the chip to open a details panel titled **Control4**. First run:
sign in with your Control4 customer email and password plus the LAN
controller IP. After credentials are saved, that form is hidden; a gear on
the header reveals it to change login. After Connect, pick a room from the
list. The bar chip then shows that room name (elided if long); without a
focused room it stays `C4`. The session lives in a headless service, so
closing the panel does not drop it or the focused room.

LAN only. This plugin talks to `apis.control4.com` to mint a director JWT,
then to `https://<controller-ip>/api/v1/...` on your network. It does not
use 4Sight.

Credentials are stored at
`$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json`
(mode 600). The focused room id is stored separately at
`$HOME/.local/state/omarchy/io.github.davydotcom.control4/focus.json`
(`{"roomId": 9}` only — no password, no JWT, no room name). Neither file is
written to `~/.config/omarchy/shell.json`.

V1 targets Control4 OS 3.x local REST. OS 4.2 currently rejects the same
cloud-issued JWT on local `/api/v1/*` (HTTP 401). The panel shows that as a
distinct auth-failed state. There is no workaround in this plugin.

## Install (published)

```sh
omarchy plugin add https://github.com/davydotcom/omarchy-control4-plugin.git --enable
```

The GitHub URL is a placeholder; no remote exists yet.

To place the chip on the right bar section explicitly:

```sh
omarchy plugin enable io.github.davydotcom.control4 --section right
```

## Local develop

Do **not** run `omarchy plugin add` on this checkout. That command git-clones
the whole repo, including Hero harness directories (`.claude/`, `.cursor/`)
that contain symlinks. Plugin folders cannot contain symlinks, so validation
fails.

Copy these files from this repo into the live plugin folder:

- `LICENSE`
- `README.md`
- `manifest.json`
- `BarWidget.qml`
- `Panel.qml`
- `Service.qml`
- `DirectorClient.js`

```sh
PLUGIN_ID=io.github.davydotcom.control4
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
mkdir -p "$PLUGIN_DIR"
cp LICENSE README.md manifest.json BarWidget.qml Panel.qml Service.qml DirectorClient.js "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins
# Adding new .qml files to a plugin folder that the running shell already
# scanned requires a process restart. rescanPlugins is not enough.
omarchy restart shell
omarchy plugin enable io.github.davydotcom.control4 --section right
```

Source of truth is this git repo. After editing existing files, copy them
again into `$PLUGIN_DIR` (saves under `~/.config/omarchy/plugins/`
hot-reload). After adding a **new** `.qml` file, also run `omarchy restart shell`.

Validate the **live** plugin folder, not the git root:

```sh
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.davydotcom.control4"
```

## Usage

- Left-click the chip to toggle the details panel (still `C4` until a room is focused)
- First run: enter controller IP, email, and password, then Connect
- After that the panel is the room list; use the header gear to change login
- When connected, pick a room in the panel; the chip shows that name
- Watch / Listen lists sources for that room; tap one to select it
- Volume slider shows the room level (0–100); release to set; right-click mutes; Off turns the room off
- Press Escape to close the panel

## Remove

```sh
omarchy plugin remove io.github.davydotcom.control4
```

Removing the plugin does not delete
`$HOME/.local/state/omarchy/io.github.davydotcom.control4/credentials.json` or
`focus.json`.

## License

MIT. See [LICENSE](LICENSE).
