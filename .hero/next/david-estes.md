---
user: david-estes
updated: 2026-08-24T12:01:01Z
repo: davydotcom/omarchy-control4-plugin
---

# david-estes's handoff

## Session goal

> Listen Apple Music should list personal stations via MSP navigator, not fake folders

_possibly stale — 9 commit(s) since, last set 21h 47m ago_

## Last user ask

> Review and fix the Control4 omarchyplugins.com marketplace submission security comment (JWT in curl argv + unbounded StdioCollector responses) so we can release.

## Suggested next prompt

> Push the curl argv/token + response-size fix, then reply on HANCORE-linux/omarchy-plugin-marketplace#1941 so they can re-review Control4.

## Recent reflections

- ui_configuration already has lights/comfort/cameras types; extractRooms skips them on purpose — the open door is an implemented allow-list, not showing every experience
- virtual-remote-numbers only has a live test on Cable DVR 20 (Xfinity X1); Apple TVs must not get a digit pad even though they list NUMBER_*
- Linux color-emoji fonts paint ▶ ⏸ ⏭ orange and ignore QML text color — use words, not media-symbol Unicode
- FileView.setText is async and no-ops on identical text; deleting http-body.json after POST makes the next accountAuth curl exit 26 as Network error
- GetTabList was firing during socket.io subscribe with no poll in flight, so OnDataToUI was dropped.

## Tried and failed (this session)

Nothing this session.

## Your recent activity

Run `git log --oneline --author=<you> -10` for recent commits.

