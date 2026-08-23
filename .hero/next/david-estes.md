---
user: david-estes
updated: 2026-08-23T16:14:29Z
repo: davydotcom/omarchy-control4-plugin
---

# david-estes's handoff

## Session goal

> Listen Apple Music should list personal stations via MSP navigator, not fake folders

## Last user ask

> ok we got a lot farther using grok on this. lets keep it going apple music browsing works now, awesome. but Tune In doesnt yet for grabbing radio stations, can you do that one next on listen to audio source

## Suggested next prompt

> open the Control4 panel — chip should be Deck/Connected, then Listen → Apple Music → Stations and play a station on the Deck

## Recent reflections

- FileView.setText is async and no-ops on identical text; deleting http-body.json after POST makes the next accountAuth curl exit 26 as Network error
- GetTabList was firing during socket.io subscribe with no poll in flight, so OnDataToUI was dropped.
- MSP lists arrive on socket.io OnDataToUI after datatoui subscribe; Browse ARGS must be <arg name=tabId> not nested tags.
- KeyboardPanel card color is hardcoded to Color.popups.background; Halo fill is an inner Rectangle with padding 0. IPC summon opens then dismisses before a screenshot.
- MSP Browse/GetTabList POSTs never return the list; DATA_RECEIVED goes to a navigator NAVID. Director socket.io is datatoui variables, not that list.

## Tried and failed (this session)

Nothing this session.

## Your recent activity

Run `git log --oneline --author=<you> -10` for recent commits.

