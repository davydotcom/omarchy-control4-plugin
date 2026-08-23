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
  readonly property bool remoteOpen: hasFocusedRoom && session && session.remoteOpen === true
  readonly property color haloBg: "#111111"
  readonly property color haloSurface: "#1C1C1C"
  readonly property color haloSurfaceSelected: "#2E2E2E"
  readonly property color haloText: "#F2F2F2"
  readonly property color haloTextMuted: "#9B9B9B"
  readonly property color haloTextSecondary: "#C9C9C9"
  readonly property color haloAccent: "#E87722"
  readonly property color haloBorder: "#2A2A2A"
  readonly property color panelFg: haloText
  readonly property string panelTitle: root.hasFocusedRoom && session && session.focusedRoomName
    ? String(session.focusedRoomName)
    : "Control4"
  readonly property string panelStatus: {
    if (!root.hasFocusedRoom || !session)
      return root.sessionStatus
    if (session.roomOn === false)
      return "Off"
    if (session.roomOn === true) {
      var name = session.playingSourceName ? String(session.playingSourceName) : ""
      if (name !== "") {
        var group = session.lastDeviceGroup ? String(session.lastDeviceGroup) : ""
        var mode = group === "listen" ? "Listen" : "Watch"
        return mode + " · " + name
      }
      return "On"
    }
    return root.sessionStatus
  }

  readonly property int rowHeight: Style.space(40)
  readonly property int rowSpacing: Style.space(4)

  // The main list is whichever of sources / browse rows is on screen. Its
  // natural height decides how tall the panel asks to be; the list area
  // itself only ever gets what is left after the pinned header and footer.
  readonly property int listRowCount: {
    if (!root.hasFocusedRoom)
      return 0
    if (root.remoteOpen) {
      var n = 0
      if (session && session.remoteMenu) n++
      if (session && session.remoteUp) n++
      if (session && (session.remoteLeft || session.remoteEnter || session.remoteRight)) n++
      if (session && session.remoteDown) n++
      if (root.transportMainCount) n++
      if (root.transportScanCount) n++
      if (session && (session.remoteChannelUp || session.remoteChannelDown)) n++
      if (session && session.remoteNumberPad) n += 4
      if (session && session.remoteSurroundModes)
        n += session.remoteSurroundModes.length
      return n
    }
    if (root.browseOpen)
      return session && session.browseRows ? session.browseRows.length : 0
    return session && session.sources ? session.sources.length : 0
  }
  readonly property int transportMainCount: {
    if (!session)
      return 0
    var n = 0
    if (session.remoteSkipRev) n++
    if (session.remotePlay) n++
    if (session.remotePause) n++
    if (session.remoteSkipFwd) n++
    return n
  }
  readonly property int transportScanCount: {
    if (!session)
      return 0
    var n = 0
    if (session.remoteScanRev) n++
    if (session.remoteStop) n++
    if (session.remoteScanFwd) n++
    return n
  }
  readonly property int numberLastCount: {
    if (!session || !session.remoteNumberPad)
      return 0
    var n = 1
    if (session.remoteStar) n++
    if (session.remotePound) n++
    return n
  }
  function transportSlotWidth(row, count) {
    if (!row || count < 1)
      return 0
    return (row.width - row.spacing * (count - 1)) / count
  }
  readonly property int listNaturalHeight: {
    if (root.remoteOpen && remotePad.implicitHeight > 0)
      return remotePad.implicitHeight
    if (listRowCount > 0)
      return listRowCount * (rowHeight + rowSpacing) - rowSpacing
    return 0
  }

  property bool settingsOpen: false

  component HaloRow: Rectangle {
    id: haloRow
    property string label: ""
    property bool chosen: false
    // De-emphasized but pressable (Back, Off). Distinct from `heading`:
    // painting an action in the status/hint grey makes it read as disabled.
    property bool secondary: false
    // A list section header — not a control. Drops the fill, border, and
    // pointer cursor, because colour alone does not say "not pressable".
    property bool heading: false
    property bool centered: false
    property bool lit: false
    signal tapped()

    height: root.rowHeight
    color: heading
      ? "transparent"
      : ((chosen || lit) ? root.haloSurfaceSelected : root.haloSurface)
    border.color: heading ? "transparent" : root.haloBorder
    border.width: heading ? 0 : 1

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: haloRow.label
      color: haloRow.heading
        ? root.haloTextMuted
        : (haloRow.secondary ? root.haloTextSecondary : root.haloText)
      elide: Text.ElideRight
      horizontalAlignment: haloRow.centered ? Text.AlignHCenter : Text.AlignLeft
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    Timer {
      id: litHold
      interval: 140
      repeat: false
      onTriggered: haloRow.lit = false
    }

    MouseArea {
      id: pressArea
      anchors.fill: parent
      enabled: !haloRow.heading
      cursorShape: haloRow.heading ? Qt.ArrowCursor : Qt.PointingHandCursor
      onPressed: {
        if (heading)
          return
        haloRow.lit = true
        litHold.stop()
      }
      onReleased: {
        if (pressArea.containsMouse)
          litHold.restart()
        else
          haloRow.lit = false
      }
      onCanceled: haloRow.lit = false
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
    if (root.session)
      root.session.restoreActiveSource()
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
        + Style.spacing.popupPadding * 2)

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
            visible: root.browseOpen || root.remoteOpen
            width: parent.width
            height: visible ? root.rowHeight : 0
            label: "Back"
            secondary: true
            onTapped: {
              if (!root.session)
                return
              if (root.remoteOpen)
                root.session.closeRemote()
              else
                root.session.browseBack()
            }
          }

          Text {
            width: parent.width
            visible: root.remoteOpen && String(root.session.remoteTitle || "") !== ""
            height: visible ? implicitHeight : 0
            text: root.session ? String(root.session.remoteTitle || "") : ""
            color: root.haloText
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
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
            visible: root.hasFocusedRoom && !root.browseOpen && !root.remoteOpen && root.sourcesHint !== ""
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
            secondary: true
            chosen: root.session && root.session.roomOn === false
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
            visible: !root.browseOpen && !root.remoteOpen
            anchors.fill: parent
            model: !root.browseOpen && !root.remoteOpen && root.session && root.session.sources ? root.session.sources : []

            delegate: HaloRow {
              required property var modelData
              width: sourcesList.width
              label: root.rowLabel(modelData)
              chosen: root.session
                && root.session.roomOn !== false
                && root.session.selectedSourceId !== null
                && modelData
                && Number(root.session.selectedSourceId) === Number(modelData.id)
              onTapped: if (root.session && modelData) root.session.selectSource(modelData.id)
            }
          }

          HaloList {
            id: browseList
            visible: root.browseOpen && !root.remoteOpen
            anchors.fill: parent
            model: root.browseOpen && !root.remoteOpen && root.session && root.session.browseRows ? root.session.browseRows : []

            delegate: HaloRow {
              required property var modelData
              required property int index
              width: browseList.width
              label: root.rowLabel(modelData)
              heading: !!(modelData && modelData.isHeader)
              onTapped: if (root.session) root.session.browseTap(index)
            }
          }

          Column {
            id: remotePad
            visible: root.remoteOpen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: root.rowSpacing

            HaloRow {
              visible: root.session && root.session.remoteMenu
              width: parent.width
              height: visible ? root.rowHeight : 0
              label: "Menu"
              centered: true
              onTapped: if (root.session) root.session.sendRemote("MENU")
            }

            HaloRow {
              visible: root.session && root.session.remoteUp
              width: parent.width
              height: visible ? root.rowHeight : 0
              label: "↑"
              centered: true
              onTapped: if (root.session) root.session.sendRemote("UP")
            }

            Row {
              id: remoteMid
              visible: root.session && (root.session.remoteLeft || root.session.remoteEnter || root.session.remoteRight)
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: root.session && root.session.remoteLeft
                width: visible ? (remoteMid.width - remoteMid.spacing * 2) / 3 : 0
                height: remoteMid.height
                label: "←"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("LEFT")
              }

              HaloRow {
                visible: root.session && root.session.remoteEnter
                width: visible ? (remoteMid.width - remoteMid.spacing * 2) / 3 : 0
                height: remoteMid.height
                label: "Enter"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("ENTER")
              }

              HaloRow {
                visible: root.session && root.session.remoteRight
                width: visible ? (remoteMid.width - remoteMid.spacing * 2) / 3 : 0
                height: remoteMid.height
                label: "→"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("RIGHT")
              }
            }

            HaloRow {
              visible: root.session && root.session.remoteDown
              width: parent.width
              height: visible ? root.rowHeight : 0
              label: "↓"
              centered: true
              onTapped: if (root.session) root.session.sendRemote("DOWN")
            }

            Row {
              id: transportMain
              visible: root.transportMainCount > 0
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: root.session && root.session.remoteSkipRev
                width: visible ? root.transportSlotWidth(transportMain, root.transportMainCount) : 0
                height: transportMain.height
                label: "Prev"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("SKIP_REV")
              }

              HaloRow {
                visible: root.session && root.session.remotePlay
                width: visible ? root.transportSlotWidth(transportMain, root.transportMainCount) : 0
                height: transportMain.height
                label: "Play"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("PLAY")
              }

              HaloRow {
                visible: root.session && root.session.remotePause
                width: visible ? root.transportSlotWidth(transportMain, root.transportMainCount) : 0
                height: transportMain.height
                label: "Pause"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("PAUSE")
              }

              HaloRow {
                visible: root.session && root.session.remoteSkipFwd
                width: visible ? root.transportSlotWidth(transportMain, root.transportMainCount) : 0
                height: transportMain.height
                label: "Next"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("SKIP_FWD")
              }
            }

            Row {
              id: transportScan
              visible: root.transportScanCount > 0
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: root.session && root.session.remoteScanRev
                width: visible ? root.transportSlotWidth(transportScan, root.transportScanCount) : 0
                height: transportScan.height
                label: "Rew"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("SCAN_REV")
              }

              HaloRow {
                visible: root.session && root.session.remoteStop
                width: visible ? root.transportSlotWidth(transportScan, root.transportScanCount) : 0
                height: transportScan.height
                label: "Stop"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("STOP")
              }

              HaloRow {
                visible: root.session && root.session.remoteScanFwd
                width: visible ? root.transportSlotWidth(transportScan, root.transportScanCount) : 0
                height: transportScan.height
                label: "FF"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("SCAN_FWD")
              }
            }

            Row {
              id: channelRow
              visible: root.session && (root.session.remoteChannelUp || root.session.remoteChannelDown)
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: root.session && root.session.remoteChannelDown
                width: visible ? root.transportSlotWidth(channelRow, (root.session.remoteChannelUp ? 2 : 1)) : 0
                height: channelRow.height
                label: "Ch-"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("CHANNEL_DOWN")
              }

              HaloRow {
                visible: root.session && root.session.remoteChannelUp
                width: visible ? root.transportSlotWidth(channelRow, (root.session.remoteChannelDown ? 2 : 1)) : 0
                height: channelRow.height
                label: "Ch+"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("CHANNEL_UP")
              }
            }

            Row {
              id: numberRow1
              visible: root.session && root.session.remoteNumberPad
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: numberRow1.visible
                width: visible ? root.transportSlotWidth(numberRow1, 3) : 0
                height: numberRow1.height
                label: "1"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_1")
              }

              HaloRow {
                visible: numberRow1.visible
                width: visible ? root.transportSlotWidth(numberRow1, 3) : 0
                height: numberRow1.height
                label: "2"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_2")
              }

              HaloRow {
                visible: numberRow1.visible
                width: visible ? root.transportSlotWidth(numberRow1, 3) : 0
                height: numberRow1.height
                label: "3"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_3")
              }
            }

            Row {
              id: numberRow2
              visible: root.session && root.session.remoteNumberPad
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: numberRow2.visible
                width: visible ? root.transportSlotWidth(numberRow2, 3) : 0
                height: numberRow2.height
                label: "4"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_4")
              }

              HaloRow {
                visible: numberRow2.visible
                width: visible ? root.transportSlotWidth(numberRow2, 3) : 0
                height: numberRow2.height
                label: "5"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_5")
              }

              HaloRow {
                visible: numberRow2.visible
                width: visible ? root.transportSlotWidth(numberRow2, 3) : 0
                height: numberRow2.height
                label: "6"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_6")
              }
            }

            Row {
              id: numberRow3
              visible: root.session && root.session.remoteNumberPad
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: numberRow3.visible
                width: visible ? root.transportSlotWidth(numberRow3, 3) : 0
                height: numberRow3.height
                label: "7"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_7")
              }

              HaloRow {
                visible: numberRow3.visible
                width: visible ? root.transportSlotWidth(numberRow3, 3) : 0
                height: numberRow3.height
                label: "8"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_8")
              }

              HaloRow {
                visible: numberRow3.visible
                width: visible ? root.transportSlotWidth(numberRow3, 3) : 0
                height: numberRow3.height
                label: "9"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_9")
              }
            }

            Row {
              id: numberRow0
              visible: root.session && root.session.remoteNumberPad
              width: parent.width
              height: visible ? root.rowHeight : 0
              spacing: root.rowSpacing

              HaloRow {
                visible: root.session && root.session.remoteStar
                width: visible ? root.transportSlotWidth(numberRow0, root.numberLastCount) : 0
                height: numberRow0.height
                label: "*"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("STAR")
              }

              HaloRow {
                visible: numberRow0.visible
                width: visible ? root.transportSlotWidth(numberRow0, root.numberLastCount) : 0
                height: numberRow0.height
                label: "0"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("NUMBER_0")
              }

              HaloRow {
                visible: root.session && root.session.remotePound
                width: visible ? root.transportSlotWidth(numberRow0, root.numberLastCount) : 0
                height: numberRow0.height
                label: "#"
                centered: true
                onTapped: if (root.session) root.session.sendRemote("POUND")
              }
            }

            Repeater {
              model: root.session && root.session.remoteSurroundModes ? root.session.remoteSurroundModes : []
              HaloRow {
                required property var modelData
                width: remotePad.width
                visible: !!(modelData && modelData.name)
                height: visible ? root.rowHeight : 0
                label: root.rowLabel(modelData)
                onTapped: if (root.session && modelData) root.session.sendSurround(modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
