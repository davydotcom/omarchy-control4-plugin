# Delivery audit — watch-receiver-audio-options

**Audited:** `git diff -- DirectorClient.js Service.qml Panel.qml tests/director-client.test.js .hero/planning/bugs/watch-receiver-audio-options/spec.md .hero/planning/initiatives/watch-source-virtual-remote/spec.md .hero/knowledge/conventions/halo-remote-panel-style/spec.md .hero/knowledge/context/receiver-audio-not-in-commands/spec.md` (working tree vs `1a98b21`)
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria
- [~] Open Watch remote and list `surround_modes` names when `commands[]` is missing — `DirectorClient.js:565-571` `hasWatchRemoteUi`; `Service.qml:264-270,373-384` open on that gate; `Panel.qml:720-728` Repeater labels `modelData.name`. Tests: receiver fixture `hasWatchRemoteUi === true` with empty commands (`tests/director-client.test.js:427-453`). On-panel list was not observed (no screenshot, no GUI driver).
- [✓] Tap a listed mode POSTs `SET_SURROUND_MODE` `{ SURROUNDMODE, OUTPUT: 4000 }` — `Panel.qml:728` `sendSurround(modelData.id)`; `Service.qml:398-419`; `DirectorClient.js:706-711` `surroundModeParams`. Test `surroundModeParams`. Live POST of `{SURROUNDMODE:3,OUTPUT:4000}` to item `370` returned HTTP 200 `{}`.
- [✓] Navigation-only source keeps D-pad and shows no empty surround rows — Apple TV fixture `surroundModes.length === 0` (`tests/director-client.test.js:455`); Repeater model is that array; D-pad `HaloRow.visible` still gated on `remoteMenu` / `remoteUp` / … (`Panel.qml:658-718`).
- [✓] Layout is not chosen by brand or model — gate is `surroundModes` / `hasNavigation` only; existing test `name is not a gate`; receiver fixture uses capabilities, no Sony/model string match.

## Changes
- [✓] `DirectorClient.js` parse surround from capabilities + tests — `parseRemoteCapabilities` fills `hasDiscreteSurroundModeSelect` and `surroundModes` (`DirectorClient.js:613-699`); live `370` shape, Apple TV empty, single-object, malformed skip, `surroundModeParams`.
- [✓] Open Watch remote when nav or `surroundModes.length` — `hasWatchRemoteUi`; `itemForWatchRemote` uses it; `openWatchRemote` no longer requires `hasNavigation`.
- [✓] `sendSurround` separate from `sendRemote` — `Service.qml:398-419`; `remoteSurroundModes` via `_applyRemoteCaps`; POST targets proxy `remoteDeviceId`.
- [✓] `Panel.qml` HaloRows for surround under D-pad — `Panel.qml:720-729`; `listRowCount` includes `remoteSurroundModes.length` (`Panel.qml:63-71`); press uses existing `HaloRow.lit`.
- [✓] Initiative child + relax no-nav AC — `.hero/planning/initiatives/watch-source-virtual-remote/spec.md` child `watch-receiver-audio-options`; AC allows surround-capable sources.

## Open items
- AC#1 residual — PARTIAL (auditor) — on-panel listing of the six mode names was not seen this turn (no GUI driver / no screenshot). Concrete: Base Fam → Watch → Sony Receiver and confirm the source list is replaced by those names.
- AC#2 residual — recorded by engineer — live POST used the specified body (HTTP 200) but `CURRENT_-Output_SURROUND_MODE` variableId `401002` stayed `9` after `SURROUNDMODE:3`. Spec Validation #1 required the AVR/variable to change. Concrete: tap a surround row on Base Fam and confirm the AVR follows. Spec Risks already name HTTP 200 + no effect as the wrong-tParams failure mode.

## Audit notes
- Ledger marked AC#1 and AC#2 `DONE`. Diff and unit tests are real; the user-visible list/tap was not exercised. Downgraded AC#1 to `~`, not `✗`.
- Exercise checkbox is checked while the same line says the surround row was not clicked. Deploy (`omarchy restart shell` exit 0) is not an on-panel check.
- Spec Kickoff still says the on-panel check is the pickup point. That matches the residual, not a completed visual validation.
- Live probe posted mode `3` while the variable was `9` and it stayed `9`. That is not “already at target.” Treat AVR effect as unconfirmed.
- `halo-remote-panel-style` and `receiver-audio-not-in-commands` are related knowledge, not extra product scope. Other dirty files (`BarWidget.qml`, etc.) were not graded.
