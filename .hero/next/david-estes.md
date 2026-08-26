---
user: david-estes
updated: 2026-08-26T00:15:39Z
repo: davydotcom/omarchy-control4-plugin
---

# david-estes's handoff

## Session goal

> Listen Apple Music should list personal stations via MSP navigator, not fake folders

_possibly stale — 10 commit(s) since, last set 2d 10h ago_

## Last user ask

> can you check the latest comment on gh issue https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/1941 for this project and determine if its valid.

## Suggested next prompt

> let's tackle Add room to source

_Rationale: highest-priority open feature: Add room to source (`add-room-to-source`)_

_Source: auto-derived from open feature — `hero next suggest "..."` to override._

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

