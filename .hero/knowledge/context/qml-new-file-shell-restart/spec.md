---
title: New QML files need a shell restart
slug: qml-new-file-shell-restart
type: context
status: active
domain: engineering
created: 2026-08-21
tags: [omarchy, qml, plugins]
relates-to:
  - director-session
  - plugin-scaffold
---
# New QML files need a shell restart

## Overview

Qt 6.11's QML type loader caches a case-sensitive directory listing (`importDirCache`). After that cache is filled for `~/.config/omarchy/plugins/<id>/`, a **new** `.qml` file in the same folder fails `Qt.createComponent` with `File name case mismatch` — `fileExists` is false (not in the stale listing) while `QFileInfo::exists` is true. `omarchy-shell shell rescanPlugins` and `Qt.clearComponentCache()` do not drop that listing.

## Details

Hit when `director-session` added `Service.qml` beside the already-loaded scaffold. First-party plugins avoid it because they ship every `.qml` file before the shell starts. Workaround: `omarchy restart shell` after copying a newly added `.qml` file into the live plugin dir. Edits to files that were already in the listing still hot-reload.
