import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.davydotcom.control4"

  property var session: null

  readonly property string sessionStatus: session ? String(session.statusText || "") : ""
  readonly property bool hasFocusedRoom: session
    && session.sessionState === "connected"
    && String(session.focusedRoomName || "").length > 0
  // The room name is in the tooltip, not the chip. Official 4-Ball when
  // the room is on; the same mark in white when it is off.
  readonly property bool roomOn: hasFocusedRoom && session.roomOn === true
  readonly property string chipTooltip: {
    if (hasFocusedRoom) {
      var state = session.roomOn === true ? "On" : (session.roomOn === false ? "Off" : "")
      var parts = String(session.focusedRoomName)
      if (state !== "")
        parts += " — " + state
      if (state === "On") {
        var src = session.playingSourceName ? String(session.playingSourceName) : ""
        if (src !== "")
          parts += " · " + src
      }
      return "Control4 · " + parts
    }
    return sessionStatus !== "" ? ("Control4 — " + sessionStatus) : "Control4"
  }

  function resolveSession() {
    var sh = root.bar && root.bar.shell
    if (!sh || typeof sh.serviceFor !== "function")
      return
    var found = sh.serviceFor("io.github.davydotcom.control4")
    if (found)
      root.session = found
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: {
    injectPanel()
    resolveSession()
  }
  onSettingsChanged: injectPanel()

  Timer {
    interval: 250
    running: root.session === null && root.bar
    repeat: true
    onTriggered: root.resolveSession()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "Control4"
    labelVisible: false
    tooltipText: root.chipTooltip
    fixedWidth: root.vertical ? -1 : Math.max(12, chip.width + button.scaledHorizontalMargin * 2)

    // Both marks stay loaded. Swapping Image.source on ROOM_OFF left a
    // blank chip while the white PNG decoded (or failed to).
    Item {
      id: chip
      enabled: false
      anchors.centerIn: parent
      width: Math.round(button.fontSize * 1.7)
      height: width
      opacity: root.hasFocusedRoom ? 1.0 : 0.55

      Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("icon.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
        visible: root.roomOn
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
      }

      Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("icon-off.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
        visible: !root.roomOn
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) return
      if (b === Qt.MiddleButton) return
      root.togglePanel()
    }
  }
}
