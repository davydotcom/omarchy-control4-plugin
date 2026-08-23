# Delivery plan — focused-room

Mode: supervised
Size: medium (bumped from small; computed medium)

## Tasks
1. [engineer] DirectorClient.js — extractRooms, isRoomHidden, sort helper, parseFocusFile + Node fixtures
2. [engineer] Service.qml — rooms/focus properties, focus.json FileView, refreshRooms gated on focus load, selection rules
3. [engineer] Panel.qml — connected Column/Repeater of qs.Ui Buttons, roomsHint
4. [engineer] BarWidget.qml — chip name + ElideRight ~Style.space(140), tooltip
5. [engineer] README.md — chip/focus.json usage
6. [engineer] copy to live plugin dir, validate, rescanPlugins (no new .qml → no shell restart)

## Validation
- node tests/director-client.test.js
- omarchy plugin validate live dir
- qmllint on live QML/JS
- omarchy plugin list --json
- Exercise if Director reachable; otherwise ledger the LAN gap honestly

## Skip
- audio_devices, new HTTP client, Watch/Listen/volume, floor tree, OS 4.2 workaround, new .qml filenames