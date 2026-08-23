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
  // The room name is in the tooltip, not the chip: spelling it across the bar
  // cost a lot of width and still never said "Control4". The mark is the
  // identity; colour carries the room's power state.
  readonly property bool roomOn: hasFocusedRoom && session.roomOn === true
  readonly property color chipOnColor: "#E4322B"
  readonly property string chipTooltip: {
    if (hasFocusedRoom) {
      var state = session.roomOn === true ? "On" : (session.roomOn === false ? "Off" : "")
      var parts = String(session.focusedRoomName)
      if (state !== "")
        parts += " — " + state
      if (sessionStatus !== "")
        parts += " · " + sessionStatus
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
    fixedWidth: root.vertical ? -1 : Math.max(12, chipClip.width + button.scaledHorizontalMargin * 2)

    // Control4's mark is a numeral in a rounded square. Drawn rather than
    // shipped as an asset so it scales with the bar and recolours for state.
    Item {
      id: chipClip
      enabled: false
      anchors.centerIn: parent
      width: badge.width
      height: badge.height

      Rectangle {
        id: badge
        width: Math.round(chipGlyph.implicitHeight * 1.45)
        height: width
        radius: Math.max(2, Math.round(width * 0.24))
        // Filled when the room is on, hollow otherwise — readable as state
        // even where the accent colour is hard to judge against a wallpaper.
        color: root.roomOn ? root.chipOnColor : "transparent"
        border.color: root.roomOn ? root.chipOnColor : button.foreground
        border.width: 1
        opacity: root.hasFocusedRoom ? 1.0 : 0.55

        Text {
          id: chipGlyph
          anchors.centerIn: parent
          text: "4"
          color: root.roomOn ? "#FFFFFF" : button.foreground
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          font.bold: true
          renderType: Text.NativeRendering
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) return
      if (b === Qt.MiddleButton) return
      root.togglePanel()
    }
  }
}
