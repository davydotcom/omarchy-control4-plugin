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
  onOpenedChanged: if (opened) {
    resolveSession()
    syncFormFromSession()
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

        Text {
          width: parent.width
          text: "Control4"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: root.sessionStatus
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

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
    }
  }
}
