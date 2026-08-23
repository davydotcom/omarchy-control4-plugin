---
id: fileview-settext-curl-body-race
pattern: Network error( \(\d+\))?|Could not read request body
stack: [qml, quickshell, curl]
severity: common
files: [Service.qml, DirectorClient.js]
---

## Symptom

Bar/panel shows Network error after a successful connect, token refresh, or plugin reload even though Director and Control4 cloud still answer.

## Root Cause

Quickshell FileView.setText is async and no-ops when the text is unchanged. The plugin chmod+curl'd the POST body after one event-loop tick and then deleted http-body.json. The next accountAuth with the same JSON skipped the write and curl exited 26, which mapped to a generic Network error with no retry.

## Fix

blockWrites:true on the body FileView, stop deleting http-body.json, retry transient curl exits (26/28/7/56/15), and include the curl exit in the chip copy.

