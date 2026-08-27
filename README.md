# Control4

Unofficial Omarchy bar widget for a Control4 focused-room remote. From
the bar you can **watch Apple TV**, **listen to Apple Music**, or
**tune in local radio** (TuneIn) in the room you have focused. This is
a community plugin. It is **not** made, endorsed, or supported by
Control4 / Snap One.

Plugin ID: `io.github.davydotcom.control4`.

Left-click the chip to open a details panel titled **Control4**. First run:
sign in with your Control4 customer email and password plus the LAN
controller IP. After credentials are saved, that form is hidden; a gear on
the header reveals it to change login. After Connect, pick a room from the
list. The bar chip stays the Control4 mark (color when the room is on,
white when it is off, faded when not connected). The room name and
what is playing live in the tooltip and the panel status line. The
session lives in a headless service, so closing the panel does not drop
it or the focused room.

LAN only. This plugin talks to `apis.control4.com` to mint a director JWT,
then to `https://<controller-ip>/api/v1/...` on your network. It does not
use 4Sight.

State lives under
`$HOME/.local/state/omarchy/io.github.davydotcom.control4/` (mode 700). Only
these files are persisted:

- `credentials.json` (mode 600) — controller IP, email, and password; reads use
  bounded descriptor-level I/O (`O_NOFOLLOW | O_NONBLOCK`, regular-file check,
  byte cap); writes atomically replace via a private temp file so a preplaced
  FIFO, symlink, or hard link on the destination cannot block or hijack the write
- `focus.json` (mode 600) — `{"roomId": 9}` only; no password, JWT, or room name;
  same bounded read and atomic-write path as credentials
- `nav-cookies.txt` (mode 600) — short-lived navigator session cookie while
  connected; removed when you Disconnect from the panel gear menu

HTTP request and response bodies are not written to disk; they stream through
curl over stdin/stdout. Nothing from this state directory is written to
`~/.config/omarchy/shell.json`.

## Compatibility

Confirmed live on **Control4 OS 4.2.1.757028-res** (Core 3): cloud-issued
director JWT, then local `/api/v1/*`. OS 3.x and earlier OS 4 use the same
path and are expected to work.

A few **OS 4.2.0** controllers have been reported to reject that JWT on
local `/api/v1/*` (HTTP 401). If cloud sign-in succeeds but the panel shows
that the Director rejected the session, that is this case. There is no
workaround in this plugin.

## Install (published)

```sh
omarchy plugin add https://github.com/davydotcom/omarchy-control4-plugin.git --enable
```

After install, enable the chip on the right if it is not already there.

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
- `icon.png`
- `icon-off.png`

```sh
PLUGIN_ID=io.github.davydotcom.control4
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
mkdir -p "$PLUGIN_DIR"
cp LICENSE README.md manifest.json BarWidget.qml Panel.qml Service.qml DirectorClient.js icon.png icon-off.png "$PLUGIN_DIR"
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

- Left-click the Control4 mark on the bar to toggle the details panel
- First run: enter controller IP, email, and password, then Connect
- After that the panel is the room list; use the header gear to change login
- When connected, pick a room in the panel; the chip stays the Control4 mark and the tooltip has the room name and on/off plus the playing source
- Watch a source (Apple TV and other video devices) or Listen (Apple Music, TuneIn local radio, and other audio); tap one to select it; the panel status line names the current source
- Volume slider shows the room level (0–100); release to set; right-click mutes; Off turns the room off and selects the Off row
- Press Escape to close the panel

## Remove

```sh
omarchy plugin remove io.github.davydotcom.control4
```

Removing the plugin does not delete the state directory. `credentials.json`,
`focus.json`, and any leftover `nav-cookies.txt` remain until you delete that
folder yourself. Disconnect (gear menu) clears `nav-cookies.txt` but keeps
credentials and focus.

## Open to contribution

The panel is a focused-room remote. Watch and Listen are implemented. These
other Control4 experiences are staged and welcome if you have a Director
that actually publishes them — we do not, so we cannot verify the commands
here. Please read the spec first and do not invent API names.

The Halo mode row should stay a list of **implemented** modes (not a
hardcoded Watch | Listen pair). Rooms should appear only when they have
an implemented experience. See
[experience-switch](.hero/planning/features/experience-switch/spec.md)
and [room-environment](.hero/planning/initiatives/room-environment/spec.md).

- [ ] **Experience switch** — Repeater over implemented modes so later
      tabs can register without rewriting Watch/Listen
      ([spec](.hero/planning/features/experience-switch/spec.md))
- [ ] **Lighting** — Lights for the focused room (`lights` is the likely
      `ui_configuration` type; confirm live)
      ([spec](.hero/planning/features/room-lighting/spec.md))
- [ ] **Temperature / climate** — Comfort / HVAC for the focused room
      (not a source list; setpoint / mode)
      ([spec](.hero/planning/features/room-climate/spec.md))
- [ ] **Blinds / shades** — Confirm the live type string (`shades` is a
      guess) and the item commands
      ([spec](.hero/planning/features/room-blinds/spec.md))
- [ ] **Scenes** — Find where the Director lists scenes before adding a
      tab; they may be lighting presets or custom buttons
      ([spec](.hero/planning/features/room-scenes/spec.md))

Cameras, security, and Composer scene authoring are out of scope unless
someone opens a new spec.

## License

MIT. See [LICENSE](LICENSE). Control4 is a trademark of Snap One, LLC.
This project is not affiliated with Snap One.
