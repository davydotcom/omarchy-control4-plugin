---
user: david-estes
updated: 2026-08-23T21:04:07Z
repo: davydotcom/omarchy-control4-plugin
---

# david-estes's handoff

## Session goal

> Listen Apple Music should list personal stations via MSP navigator, not fake folders

_possibly stale — 7 commit(s) since, last set 6h 51m ago_

## Last user ask

> lets deliver it

## Suggested next prompt

> deliver room now playing so the chip is the Control4 mark and the panel names what's on

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

