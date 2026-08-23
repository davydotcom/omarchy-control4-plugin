import QtQuick
import QtQuick.Controls
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
  readonly property int roomCount: session && session.rooms ? session.rooms.length : 0
  readonly property bool browseOpen: hasFocusedRoom && session && session.browseOpen === true
  readonly property color haloBg: "#111111"
  readonly property color haloSurface: "#1C1C1C"
  readonly property color haloSurfaceSelected: "#2E2E2E"
  readonly property color haloText: "#F2F2F2"
  readonly property color haloTextMuted: "#9B9B9B"
  readonly property color haloAccent: "#E87722"
  readonly property color haloBorder: "#2A2A2A"
  readonly property color panelFg: haloText
  readonly property string panelTitle: root.hasFocusedRoom && session && session.focusedRoomName
    ? String(session.focusedRoomName)
    : "Control4"
  readonly property string panelStatus: {
    if (!root.hasFocusedRoom)
      return root.sessionStatus
    var mode = root.sourceMode === "listen" ? "Listen" : "Watch"
    return mode + " · " + root.sessionStatus
  }

  readonly property int rowHeight: Style.space(40)
  readonly property int rowSpacing: Style.space(4)

  // The main list is whichever of sources / browse rows is on screen. Its
  // natural height decides how tall the panel asks to be; the list area
  // itself only ever gets what is left after the pinned header and footer.
  readonly property int listRowCount: {
    if (!root.hasFocusedRoom)
      return 0
    if (root.browseOpen)
      return session && session.browseRows ? session.browseRows.length : 0
    return session && session.sources ? session.sources.length : 0
  }
  readonly property int listNaturalHeight: listRowCount > 0
    ? listRowCount * (rowHeight + rowSpacing) - rowSpacing
    : 0

  property bool settingsOpen: false

  component HaloRow: Rectangle {
    id: haloRow
    property string label: ""
    property bool chosen: false
    property bool mutedLook: false
    property bool centered: false
    signal tapped()

    height: root.rowHeight
    color: chosen ? root.haloSurfaceSelected : root.haloSurface
    border.color: root.haloBorder
    border.width: 1

    Rectangle {
      width: 2
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      color: haloRow.chosen ? root.haloAccent : "transparent"
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: haloRow.label
      color: haloRow.mutedLook ? root.haloTextMuted : root.haloText
      elide: Text.ElideRight
      horizontalAlignment: haloRow.centered ? Text.AlignHCenter : Text.AlignLeft
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: haloRow.tapped()
    }
  }

  // A ListView rather than a Repeater in a Column: TuneIn folders run to
  // hundreds of stations, and only a view that owns its own scroll position
  // can keep those rows off the room controls below.
  component HaloList: ListView {
    id: haloList

    spacing: root.rowSpacing
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    // Qt's defaults (1500 / 2500) coast far too long for a list this short.
    flickDeceleration: 4000
    maximumFlickVelocity: 5000

    ScrollBar.vertical: ScrollBar {
      policy: haloList.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    NumberAnimation {
      id: wheelGlide
      target: haloList
      property: "contentY"
      duration: 160
      easing.type: Easing.OutCubic
    }

    // A wheel notch moves a Flickable in one discrete jump, so a fast scroll
    // reads as stutter and stalls the moment you stop turning. Accumulating
    // onto the running animation's target instead makes consecutive notches
    // build on each other and settle in a single glide.
    //
    // Flickable's default property puts this handler on contentItem, not on
    // the view — which is what makes it work. contentItem paints in front of
    // the Flickable, so its handlers are offered the wheel before Flickable's
    // own wheelEvent can step the list. Do not "fix" this by reparenting to
    // the view or wrapping the list in an Item; either way Flickable claims
    // the event first and the glide never runs.
    WheelHandler {
      enabled: haloList.interactive
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        if (event.angleDelta.y === 0)
          return
        var maxY = Math.max(0, haloList.contentHeight - haloList.height)
        if (maxY <= 0)
          return
        var from = wheelGlide.running ? wheelGlide.to : haloList.contentY
        var next = from - (event.angleDelta.y / 120) * Style.space(60)
        next = Math.max(0, Math.min(maxY, next))
        haloList.cancelFlick()
        wheelGlide.stop()
        wheelGlide.from = haloList.contentY
        wheelGlide.to = next
        wheelGlide.start()
      }
    }
  }

  function rowLabel(row) {
    if (!row)
      return ""
    if (row.name !== undefined && row.name !== null && String(row.name).length)
      return String(row.name)
    if (row.title !== undefined && row.title !== null && String(row.title).length)
      return String(row.title)
    if (row.id !== undefined && row.id !== null)
      return String(row.id)
    return ""
  }

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
    padding: 0
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(
      headerColumn.implicitHeight
        + (root.listNaturalHeight > 0 ? root.listNaturalHeight + Style.space(8) : 0)
        + (footerColumn.visible ? footerColumn.implicitHeight + Style.space(8) : 0)
        + Style.spacing.popupPadding * 2,
      Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Rectangle {
        anchors.fill: parent
        color: root.haloBg

        Column {
          id: headerColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.spacing.popupPadding
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
              text: root.panelTitle
              color: root.haloText
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
              foreground: root.haloText
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              bordered: root.settingsOpen
              onClicked: root.settingsOpen = !root.settingsOpen
            }
          }

          Text {
            width: parent.width
            text: root.panelStatus
            color: root.haloTextMuted
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
              foreground: root.haloText
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              Keys.onReturnPressed: root.submitConnect()
              Keys.onEnterPressed: root.submitConnect()
            }

            TextField {
              id: emailField
              width: parent.width
              enabled: !root.connecting
              placeholderText: "Email"
              foreground: root.haloText
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
              foreground: root.haloText
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              Keys.onReturnPressed: root.submitConnect()
              Keys.onEnterPressed: root.submitConnect()
            }

            Button {
              text: "Connect"
              foreground: root.haloText
              bordered: true
              enabled: !root.connecting
              onClicked: root.submitConnect()
            }
          }

          Text {
            visible: root.connected && root.roomsHint !== ""
            width: parent.width
            height: visible ? implicitHeight : 0
            text: root.roomsHint
            color: root.haloTextMuted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          // Rooms get their own bounded scroll so a large house cannot push
          // the source list off the panel before it is even reached.
          HaloList {
            id: roomsList
            visible: root.connected && root.roomCount > 1
            width: parent.width
            height: visible
              ? Math.min(contentHeight, Style.space(176))
              : 0
            model: root.session && root.session.rooms ? root.session.rooms : []

            delegate: HaloRow {
              required property var modelData
              width: roomsList.width
              label: root.rowLabel(modelData)
              chosen: root.session
                && root.session.focusedRoomId !== null
                && modelData
                && Number(root.session.focusedRoomId) === Number(modelData.id)
              onTapped: if (root.session && modelData) root.session.setFocusedRoom(modelData.id)
            }
          }

          Row {
            id: modeRow
            visible: root.hasFocusedRoom
            width: parent.width
            spacing: Style.space(4)
            height: visible ? root.rowHeight : 0

            HaloRow {
              width: (modeRow.width - modeRow.spacing) / 2
              label: "Watch"
              chosen: root.sourceMode === "watch"
              centered: true
              onTapped: if (root.session) root.session.setSourceMode("watch")
            }

            HaloRow {
              width: (modeRow.width - modeRow.spacing) / 2
              label: "Listen"
              chosen: root.sourceMode === "listen"
              centered: true
              onTapped: if (root.session) root.session.setSourceMode("listen")
            }
          }

          HaloRow {
            visible: root.browseOpen
            width: parent.width
            height: visible ? root.rowHeight : 0
            label: "Back"
            mutedLook: true
            onTapped: if (root.session) root.session.browseBack()
          }

          Text {
            width: parent.width
            visible: root.browseOpen && String(root.session.browseTitle || "") !== ""
            height: visible ? implicitHeight : 0
            text: root.session ? String(root.session.browseTitle || "") : ""
            color: root.haloText
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.browseOpen
              && (root.session.browseBusy || String(root.session.browseHint || "") !== "")
            height: visible ? implicitHeight : 0
            text: root.session && root.session.browseBusy && String(root.session.browseHint || "") === ""
              ? "Loading…"
              : (root.session ? String(root.session.browseHint || "") : "")
            color: root.haloTextMuted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            visible: root.hasFocusedRoom && !root.browseOpen && root.sourcesHint !== ""
            width: parent.width
            height: visible ? implicitHeight : 0
            text: root.sourcesHint
            color: root.haloTextMuted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }

        // Volume and Off are pinned to the bottom: a browse list hundreds of
        // rows deep must never scroll the room controls out of reach.
        Column {
          id: footerColumn
          visible: root.hasFocusedRoom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: Style.spacing.popupPadding
          spacing: Style.space(8)

          Row {
            id: volumeRow
            width: parent.width
            spacing: Style.space(8)
            height: Math.max(volumeLabel.implicitHeight, volumeSlider.implicitHeight)

            Text {
              id: volumeLabel
              width: Style.space(36)
              anchors.verticalCenter: parent.verticalCenter
              text: root.session && root.session.muted ? "M" : String(root.session ? root.session.volume : 0)
              color: root.haloTextMuted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignRight
            }

            PanelSlider {
              id: volumeSlider
              bar: root.bar
              width: parent.width - volumeLabel.width - volumeRow.spacing
              anchors.verticalCenter: parent.verticalCenter
              minimum: 0
              maximum: 100
              step: 1
              integer: true
              value: root.session ? root.session.volume : 0
              fillColor: root.haloAccent
              knobColor: root.haloAccent
              trackColor: root.haloSurface
              tickColor: root.haloBg
              opacity: root.session && root.session.muted ? 0.5 : 1
              onReleased: function(v) {
                if (root.session)
                  root.session.setVolume(v)
              }
              onRightClicked: if (root.session) root.session.toggleMute()
            }
          }

          HaloRow {
            width: parent.width
            label: "Off"
            mutedLook: true
            onTapped: if (root.session) root.session.roomOff()
          }
        }

        // Takes whatever height is left between the pinned header and footer,
        // so the list is the only thing that ever scrolls.
        Item {
          id: listArea
          visible: root.listRowCount > 0
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: headerColumn.bottom
          anchors.bottom: footerColumn.visible ? footerColumn.top : parent.bottom
          anchors.leftMargin: Style.spacing.popupPadding
          anchors.rightMargin: Style.spacing.popupPadding
          anchors.topMargin: Style.space(8)
          anchors.bottomMargin: Style.space(8)
          clip: true

          HaloList {
            id: sourcesList
            visible: !root.browseOpen
            anchors.fill: parent
            model: !root.browseOpen && root.session && root.session.sources ? root.session.sources : []

            delegate: HaloRow {
              required property var modelData
              width: sourcesList.width
              label: root.rowLabel(modelData)
              chosen: root.session
                && root.session.selectedSourceId !== null
                && modelData
                && Number(root.session.selectedSourceId) === Number(modelData.id)
              onTapped: if (root.session && modelData) root.session.selectSource(modelData.id)
            }
          }

          HaloList {
            id: browseList
            visible: root.browseOpen
            anchors.fill: parent
            model: root.browseOpen && root.session && root.session.browseRows ? root.session.browseRows : []

            delegate: HaloRow {
              required property var modelData
              required property int index
              width: browseList.width
              label: root.rowLabel(modelData)
              mutedLook: !!(modelData && modelData.isHeader)
              onTapped: if (root.session) root.session.browseTap(index)
            }
          }
        }
      }
    }
  }
}
