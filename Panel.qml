import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.davydotcom.control4"
  manageIpc: false

  property var settings: ({})
  property var anchorItem: null
  property var hostWidget: null
  property var session: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. switchPanelFrom and KeyboardPanel.owner must use that widget.
  readonly property var barIdentity: hostWidget || root
  readonly property string sessionStatus: session ? String(session.statusText || "") : "Not configured"
  readonly property bool connecting: session && session.sessionState === "connecting"
  readonly property bool connected: session && session.sessionState === "connected"
  readonly property bool configured: session && session.configured === true
  readonly property bool authFailed: session && session.sessionState === "auth-failed"
  readonly property string roomsHint: session ? String(session.roomsHint || "") : ""
  readonly property bool showLoginForm: !configured || settingsOpen || authFailed
  readonly property bool hasFocusedRoom: connected
    && session
    && session.focusedRoomId !== null
    && session.focusedRoomId !== undefined
  readonly property string sourcesHint: session ? String(session.sourcesHint || "") : ""
  readonly property string sourceMode: session && session.sourceMode ? String(session.sourceMode) : "watch"

  property bool settingsOpen: false

  function resolveSession() {
    var sh = root.bar && root.bar.shell
    if (!sh || typeof sh.serviceFor !== "function")
      return
    var found = sh.serviceFor("io.github.davydotcom.control4")
    if (found)
      root.session = found
  }

  function syncFormFromSession() {
    if (!session)
      return
    if (ipField.text === "" && session.controllerIp)
      ipField.text = session.controllerIp
    if (emailField.text === "" && session.email)
      emailField.text = session.email
  }

  function submitConnect() {
    if (!session || connecting)
      return
    session.controllerIp = ipField.text
    session.email = emailField.text
    if (passwordField.text !== "")
      session.password = passwordField.text
    session.connectNow()
  }

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  onBarChanged: resolveSession()
  onSessionChanged: syncFormFromSession()
  onConnectedChanged: if (connected) settingsOpen = false
  onOpenedChanged: {
    if (opened) {
      resolveSession()
      syncFormFromSession()
    } else {
      settingsOpen = false
    }
  }

  Timer {
    interval: 250
    running: root.session === null && root.bar
    repeat: true
    onTriggered: root.resolveSession()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Row {
          id: headerRow
          width: parent.width
          spacing: Style.space(8)
          height: Math.max(titleLabel.implicitHeight, gearButton.visible ? gearButton.height : 0)

          Text {
            id: titleLabel
            width: parent.width - (gearButton.visible ? gearButton.width + headerRow.spacing : 0)
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            text: "Control4"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            wrapMode: Text.WordWrap
          }

          PanelActionButton {
            id: gearButton
            visible: root.configured
            width: gearButton.visible ? gearButton.implicitWidth : 0
            height: gearButton.visible ? gearButton.implicitHeight : 0
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: root.settingsOpen ? "Hide login" : "Change login"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            bordered: root.settingsOpen
            onClicked: root.settingsOpen = !root.settingsOpen
          }
        }

        Text {
          width: parent.width
          text: root.sessionStatus
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Column {
          id: loginForm
          visible: root.showLoginForm
          width: parent.width
          spacing: Style.space(8)
          height: loginForm.visible ? loginForm.implicitHeight : 0

          TextField {
            id: ipField
            width: parent.width
            enabled: !root.connecting
            placeholderText: "Controller IP"
            foreground: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            Keys.onReturnPressed: root.submitConnect()
            Keys.onEnterPressed: root.submitConnect()
          }

          TextField {
            id: emailField
            width: parent.width
            enabled: !root.connecting
            placeholderText: "Email"
            foreground: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            Keys.onReturnPressed: root.submitConnect()
            Keys.onEnterPressed: root.submitConnect()
          }

          TextField {
            id: passwordField
            width: parent.width
            enabled: !root.connecting
            placeholderText: "Password"
            password: true
            foreground: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            Keys.onReturnPressed: root.submitConnect()
            Keys.onEnterPressed: root.submitConnect()
          }

          Button {
            text: "Connect"
            foreground: root.barForeground
            bordered: true
            enabled: !root.connecting
            onClicked: root.submitConnect()
          }
        }

        Text {
          visible: root.connected && root.roomsHint !== ""
          width: parent.width
          text: root.roomsHint
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Column {
          id: roomsColumn
          visible: root.connected
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.session && root.session.rooms ? root.session.rooms : []

            Button {
              width: roomsColumn.width
              text: modelData && modelData.name ? String(modelData.name) : ""
              selected: root.session
                && root.session.focusedRoomId !== null
                && root.session.focusedRoomId !== undefined
                && Number(root.session.focusedRoomId) === Number(modelData.id)
              foreground: root.barForeground
              leftAlign: true
              onClicked: if (root.session) root.session.setFocusedRoom(modelData.id)
            }
          }
        }

        ButtonGroup {
          visible: root.hasFocusedRoom
          width: parent.width
          height: visible ? implicitHeight : 0
          options: [
            { value: "watch", label: "Watch" },
            { value: "listen", label: "Listen" }
          ]
          value: root.sourceMode
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onChanged: function(v) {
            if (root.session)
              root.session.setSourceMode(v)
          }
        }

        Text {
          visible: root.hasFocusedRoom && root.sourcesHint !== ""
          width: parent.width
          height: visible ? implicitHeight : 0
          text: root.sourcesHint
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Column {
          id: sourcesColumn
          visible: root.hasFocusedRoom
          width: parent.width
          spacing: Style.space(4)
          height: visible ? implicitHeight : 0

          Repeater {
            model: root.session && root.session.sources ? root.session.sources : []

            Button {
              width: sourcesColumn.width
              text: modelData && modelData.name ? String(modelData.name) : ""
              foreground: root.barForeground
              leftAlign: true
              onClicked: if (root.session) root.session.selectSource(modelData.id)
            }
          }
        }

        Row {
          id: volumeRow
          visible: root.hasFocusedRoom
          width: parent.width
          spacing: Style.space(8)
          height: visible ? implicitHeight : 0

          Button {
            width: (volumeRow.width - volumeRow.spacing * 2) / 3
            text: "−"
            foreground: root.barForeground
            bordered: true
            onClicked: if (root.session) root.session.pulseVolumeDown()
          }

          Button {
            width: (volumeRow.width - volumeRow.spacing * 2) / 3
            text: "Mute"
            foreground: root.barForeground
            bordered: true
            onClicked: if (root.session) root.session.toggleMute()
          }

          Button {
            width: (volumeRow.width - volumeRow.spacing * 2) / 3
            text: "+"
            foreground: root.barForeground
            bordered: true
            onClicked: if (root.session) root.session.pulseVolumeUp()
          }
        }

        Button {
          visible: root.hasFocusedRoom
          width: parent.width
          height: visible ? implicitHeight : 0
          text: "Off"
          foreground: root.barForeground
          bordered: true
          onClicked: if (root.session) root.session.roomOff()
        }
      }
    }
  }
}
