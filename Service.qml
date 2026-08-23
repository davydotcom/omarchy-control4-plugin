import QtQuick
import Quickshell
import Quickshell.Io
import "DirectorClient.js" as DirectorClient

Item {
  id: root

  property var shell: null

  readonly property string pluginId: "io.github.davydotcom.control4"
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/" + pluginId
  readonly property string credentialsPath: stateDir + "/credentials.json"
  readonly property string focusPath: stateDir + "/focus.json"
  readonly property string bodyPath: stateDir + "/http-body.json"

  property string sessionState: "unconfigured"
  property string statusText: DirectorClient.STATUS_NOT_CONFIGURED
  property string lastError: ""
  property string authFailedKind: ""
  property string controllerIp: ""
  property string email: ""
  property string password: ""

  property var rooms: []
  property var focusedRoomId: null
  property string focusedRoomName: ""
  property string roomsHint: ""
  property string sourceMode: "watch"
  property var sources: []
  property string sourcesHint: ""
  property var _uiConfig: null
  property var _items: null
  property int volume: 0
  property bool muted: false
  property var _volumeHoldUntil: 0
  property int _volumeGen: 0

  property string _accountToken: ""
  property string _directorToken: ""
  property int _validSeconds: 86400
  property bool _refreshing: false
  property bool _hydrating: false
  property bool _autoConnectPending: false
  property bool _credentialsLoaded: false
  property bool _ignoreCredentialsLoad: false
  property bool _focusLoaded: false
  property bool _ignoreFocusLoad: false
  property int _roomsGen: 0
  property int _httpGen: 0
  property var _queue: []
  property var _pending: null
  property var _pendingCallback: null
  property bool _ignoreHttpExit: false

  readonly property bool configured: DirectorClient.credentialsComplete(controllerIp, email, password)
  readonly property bool hasToken: _directorToken.length > 0

  function connectNow() {
    controllerIp = DirectorClient.normalizeHost(controllerIp)
    if (!configured) {
      _directorToken = ""
      _accountToken = ""
      authFailedKind = ""
      lastError = ""
      _setState("unconfigured")
      return
    }
    persistCredentials()
    _refreshing = false
    _directorToken = ""
    _accountToken = ""
    authFailedKind = ""
    lastError = ""
    refreshTimer.stop()
    _abortHttp()
    _setState("connecting")
    _startAccountAuth()
  }

  function disconnect() {
    refreshTimer.stop()
    _abortHttp()
    _accountToken = ""
    _directorToken = ""
    _refreshing = false
    authFailedKind = ""
    lastError = ""
    _uiConfig = null
    _items = null
    sources = []
    sourcesHint = ""
    volume = 0
    muted = false
    volumeTimer.stop()
    _setState("unconfigured")
  }

  function _abortHttp() {
    _queue = []
    _pending = null
    _pendingCallback = null
    _httpGen += 1
    if (httpProc.running) {
      _ignoreHttpExit = true
      httpProc.running = false
    }
    if (chmodBodyProc.running)
      chmodBodyProc.running = false
  }

  function _startAccountAuth() {
    _enqueue({
      kind: "accountAuth",
      method: "POST",
      url: DirectorClient.ACCOUNT_AUTH_URL,
      body: DirectorClient.accountAuthBody(email, password)
    })
  }

  function directorGet(path, callback) {
    _directorCall("GET", path, "", callback)
  }

  function directorPost(path, command, params, callback) {
    _directorCall("POST", path, DirectorClient.commandBody(command, params), callback)
  }

  function _directorCall(method, path, body, callback) {
    var cb = typeof callback === "function" ? callback : function() {}
    if (!_directorToken) {
      cb("Not connected", "", 0)
      return
    }
    if (!DirectorClient.normalizeHost(controllerIp)) {
      cb("Not connected", "", 0)
      return
    }
    _enqueue({
      kind: method === "POST" ? "post" : "get",
      method: method,
      url: DirectorClient.directorUrl(controllerIp, path),
      insecure: true,
      body: method === "POST" ? body : "",
      token: _directorToken,
      callback: cb
    })
  }

  function persistCredentials() {
    controllerIp = DirectorClient.normalizeHost(controllerIp)
    email = String(email || "").trim()
    var payload = {
      controllerIp: controllerIp,
      email: email,
      password: password
    }
    _ignoreCredentialsLoad = true
    credentialsFile.setText(JSON.stringify(payload, null, 2) + "\n")
    chmodProc.command = ["chmod", "600", credentialsPath]
    chmodProc.running = true
  }

  function _setState(next) {
    sessionState = next
    if (next === "auth-failed" || next === "error")
      refreshTimer.stop()
    _refreshStatusText()
    if (next === "connected")
      refreshRooms()
  }

  function setFocusedRoom(id) {
    var match = _roomById(id)
    if (!match)
      return
    focusedRoomId = match.id
    focusedRoomName = match.name
    roomsHint = ""
    persistFocus(match.id)
    _rebuildSources(true)
    refreshVolume()
  }

  function setSourceMode(mode) {
    if (mode !== "watch" && mode !== "listen")
      return
    if (sourceMode === mode)
      return
    sourceMode = mode
    _rebuildSources(false)
  }

  function selectSource(id) {
    if (sessionState !== "connected" || focusedRoomId === null || focusedRoomId === undefined)
      return
    var n = Number(id)
    if (!isFinite(n))
      return
    var list = sources
    var found = false
    if (list && list.length) {
      for (var i = 0; i < list.length; i++) {
        if (Number(list[i].id) === n) {
          found = true
          break
        }
      }
    }
    if (!found)
      return
    var command = sourceMode === "listen" ? "SELECT_AUDIO_DEVICE" : "SELECT_VIDEO_DEVICE"
    directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, { deviceid: n }, function() {})
  }

  function setVolume(level) {
    var n = Math.round(Number(level))
    if (!isFinite(n))
      return
    n = Math.max(0, Math.min(100, n))
    volume = n
    _volumeHoldUntil = Date.now() + 1500
    _roomCommand("SET_VOLUME_LEVEL", { LEVEL: n })
  }

  function toggleMute() {
    muted = !muted
    _volumeHoldUntil = Date.now() + 1500
    _roomCommand("MUTE_TOGGLE", {})
  }

  function roomOff() {
    _roomCommand("ROOM_OFF", {})
  }

  function refreshVolume() {
    if (sessionState !== "connected" || focusedRoomId === null || focusedRoomId === undefined) {
      volumeTimer.stop()
      return
    }
    volumeTimer.restart()
    root._volumeGen += 1
    var gen = root._volumeGen
    var id = focusedRoomId
    directorGet("/api/v1/items/" + id + "/variables?varnames=CURRENT_VOLUME,IS_MUTED", function(err, body) {
      if (gen !== root._volumeGen)
        return
      if (err)
        return
      if (Date.now() < root._volumeHoldUntil)
        return
      var parsed = DirectorClient.parseRoomVolume(body)
      if (parsed.volume !== null)
        root.volume = parsed.volume
      root.muted = parsed.muted === true
    })
  }

  function _roomCommand(command, params) {
    if (sessionState !== "connected" || focusedRoomId === null || focusedRoomId === undefined)
      return
    directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, params || {}, function() {})
  }

  function _rebuildSources(allowFlip) {
    if (sessionState !== "connected" || focusedRoomId === null || focusedRoomId === undefined) {
      sources = []
      sourcesHint = ""
      return
    }
    sources = DirectorClient.extractSources(_uiConfig, _items, focusedRoomId, sourceMode)
    if ((!sources || !sources.length) && allowFlip) {
      var other = sourceMode === "listen" ? "watch" : "listen"
      var alt = DirectorClient.extractSources(_uiConfig, _items, focusedRoomId, other)
      if (alt && alt.length) {
        sourceMode = other
        sources = alt
      }
    }
    if (sources && sources.length)
      sourcesHint = ""
    else
      sourcesHint = sourceMode === "listen" ? "No listen sources" : "No watch sources"
  }

  function refreshRooms() {
    if (sessionState !== "connected")
      return
    if (!_focusLoaded)
      return
    root._roomsGen += 1
    var gen = root._roomsGen
    directorGet("/api/v1/agents/ui_configuration", function(err, body, status) {
      if (gen !== root._roomsGen)
        return
      if (root.sessionState !== "connected")
        return
      if (err)
        return
      var uiConfig
      try {
        uiConfig = JSON.parse(body)
      } catch (e) {
        return
      }
      root.directorGet("/api/v1/items", function(err2, body2, status2) {
        if (gen !== root._roomsGen)
          return
        if (root.sessionState !== "connected")
          return
        if (err2)
          return
        var items
        try {
          items = JSON.parse(body2)
        } catch (e2) {
          return
        }
        root._uiConfig = uiConfig
        root._items = items
        root._applyRooms(DirectorClient.extractRooms(uiConfig, items))
      })
    })
  }

  function persistFocus(id) {
    var payload = {}
    if (id !== null && id !== undefined) {
      var n = Number(id)
      if (isFinite(n))
        payload = { roomId: n }
    }
    _ignoreFocusLoad = true
    focusFile.setText(JSON.stringify(payload) + "\n")
    // atomicWrites can replace the inode; chmod after the write lands.
    Qt.callLater(function() {
      chmodFocusProc.command = ["chmod", "600", root.focusPath]
      chmodFocusProc.running = true
    })
  }

  function loadFocus(raw) {
    if (_ignoreFocusLoad) {
      _ignoreFocusLoad = false
      _focusLoaded = true
      return
    }
    focusedRoomId = DirectorClient.parseFocusFile(raw)
    if (focusedRoomId === null)
      focusedRoomName = ""
    var first = !_focusLoaded
    _focusLoaded = true
    if (first && sessionState === "connected")
      refreshRooms()
  }

  function _roomById(id) {
    if (id === null || id === undefined || id === "")
      return null
    var n = Number(id)
    if (!isFinite(n))
      return null
    var list = rooms
    if (!list || !list.length)
      return null
    for (var i = 0; i < list.length; i++) {
      if (Number(list[i].id) === n)
        return list[i]
    }
    return null
  }

  function _applyRooms(list) {
    rooms = list || []
    var visible = rooms
    if (!visible.length) {
      focusedRoomId = null
      focusedRoomName = ""
      roomsHint = "No rooms"
      persistFocus(null)
    } else {
      var match = _roomById(focusedRoomId)
      if (match) {
        focusedRoomId = match.id
        focusedRoomName = match.name
        roomsHint = ""
      } else if (focusedRoomId !== null && focusedRoomId !== undefined) {
        focusedRoomId = null
        focusedRoomName = ""
        roomsHint = "Saved room is gone. Pick a room."
        persistFocus(null)
      } else if (visible.length === 1) {
        setFocusedRoom(visible[0].id)
        return
      } else {
        focusedRoomId = null
        focusedRoomName = ""
        roomsHint = ""
      }
    }
    _rebuildSources(true)
    refreshVolume()
  }

  function _refreshStatusText() {
    statusText = DirectorClient.statusTextFor(
      sessionState, authFailedKind, lastError, configured, hasToken)
  }

  function _failSignIn() {
    _accountToken = ""
    _directorToken = ""
    _refreshing = false
    authFailedKind = "cloud"
    lastError = DirectorClient.STATUS_SIGN_IN_FAILED
    _setState("auth-failed")
  }

  function _failDirector401() {
    _directorToken = ""
    _refreshing = false
    authFailedKind = "director401"
    lastError = DirectorClient.STATUS_DIRECTOR_401
    _setState("auth-failed")
  }

  function _failError(message) {
    _refreshing = false
    lastError = message || "Network error"
    _setState("error")
  }

  function _enqueue(job) {
    var next = _queue.slice()
    next.push(job)
    _queue = next
    _pump()
  }

  function _pump() {
    if (httpProc.running || chmodBodyProc.running || rmBodyProc.running)
      return
    if (_pending)
      return
    if (!_queue.length)
      return
    var job = _queue[0]
    var rest = _queue.slice(1)
    _queue = rest
    _pending = job
    _pendingCallback = job.callback || null
    if (job.body) {
      root._httpGen += 1
      var gen = root._httpGen
      bodyFile.setText(job.body)
      Qt.callLater(function() {
        if (gen !== root._httpGen)
          return
        if (!root._pending)
          return
        chmodBodyProc.command = ["chmod", "600", bodyPath]
        chmodBodyProc.running = true
      })
      return
    }
    _startHttp(job)
  }

  function _startHttp(job) {
    var args = DirectorClient.curlArgs({
      url: job.url,
      insecure: job.insecure === true,
      bodyPath: job.body ? bodyPath : ""
    })
    args = DirectorClient.withAuthHeader(args, job.token || "")
    httpProc.command = args
    httpProc.running = true
  }

  function _finishHttp(exitCode, stdout) {
    var job = _pending
    var cb = _pendingCallback
    _pending = null
    _pendingCallback = null
    if (job && job.body)
      rmBodyProc.running = true
    var parsed = DirectorClient.parseHttp(stdout)
    if (exitCode !== 0 && parsed.status <= 0) {
      var net = DirectorClient.networkErrorMessage(exitCode)
      if (cb)
        cb(net, parsed.body, parsed.status)
      else if (job)
        _handleFlowFailure(job, net)
      if (!job || !job.body)
        _pump()
      return
    }
    if (cb) {
      if (parsed.status >= 200 && parsed.status < 300)
        cb("", parsed.body, parsed.status)
      else
        cb("HTTP " + parsed.status, parsed.body, parsed.status)
      if (!job || !job.body)
        _pump()
      return
    }
    if (job)
      _handleFlowResponse(job, parsed)
    if (!job || !job.body)
      _pump()
  }

  function _handleFlowFailure(job, message) {
    if (job.kind === "probe" || job.kind === "get" || job.kind === "post")
      _failError(message)
    else
      _failError(message)
  }

  function _handleFlowResponse(job, parsed) {
    if (job.kind === "accountAuth") {
      var cloud = DirectorClient.classifyCloudStatus(parsed.status)
      if (cloud.kind === "sign-in") {
        _failSignIn()
        return
      }
      if (cloud.kind !== "ok") {
        _failError(cloud.message)
        return
      }
      var account = DirectorClient.parseAccountToken(parsed.body)
      if (!account.ok) {
        _failSignIn()
        return
      }
      _accountToken = account.token
      _enqueue({
        kind: "accounts",
        method: "GET",
        url: DirectorClient.ACCOUNTS_URL,
        token: _accountToken
      })
      return
    }

    if (job.kind === "accounts") {
      var accountsCloud = DirectorClient.classifyCloudStatus(parsed.status)
      if (accountsCloud.kind === "sign-in") {
        _failSignIn()
        return
      }
      if (accountsCloud.kind !== "ok") {
        _failError(accountsCloud.message)
        return
      }
      var name = DirectorClient.parseControllerCommonName(parsed.body)
      if (!name.ok) {
        _failSignIn()
        return
      }
      _enqueue({
        kind: "directorAuth",
        method: "POST",
        url: DirectorClient.DIRECTOR_AUTH_URL,
        token: _accountToken,
        body: DirectorClient.directorAuthBody(name.commonName)
      })
      return
    }

    if (job.kind === "directorAuth") {
      var dirCloud = DirectorClient.classifyCloudStatus(parsed.status)
      if (dirCloud.kind === "sign-in") {
        _failSignIn()
        return
      }
      if (dirCloud.kind !== "ok") {
        _failError(dirCloud.message)
        return
      }
      var director = DirectorClient.parseDirectorToken(parsed.body)
      if (!director.ok) {
        _failSignIn()
        return
      }
      _directorToken = director.token
      _validSeconds = director.validSeconds
      if (_refreshing) {
        _refreshing = false
        _armRefresh()
        _setState("connected")
        return
      }
      _enqueue({
        kind: "probe",
        method: "GET",
        url: DirectorClient.directorUrl(controllerIp, "/api/v1/agents/ui_configuration"),
        insecure: true,
        token: _directorToken
      })
      return
    }

    if (job.kind === "probe") {
      var probe = DirectorClient.classifyProbe(parsed.status)
      if (probe.kind === "connected") {
        _armRefresh()
        lastError = ""
        authFailedKind = ""
        _setState("connected")
        return
      }
      if (probe.kind === "director401") {
        _failDirector401()
        return
      }
      _failError(probe.message)
    }
  }

  function _armRefresh() {
    var ms = Math.floor(_validSeconds * 0.8 * 1000)
    if (ms < 60000)
      ms = 60000
    refreshTimer.interval = ms
    refreshTimer.restart()
  }

  function loadCredentials(raw) {
    if (_ignoreCredentialsLoad) {
      _ignoreCredentialsLoad = false
      return
    }
    _hydrating = true
    var text = String(raw || "").trim()
    if (!text) {
      _credentialsLoaded = true
      _hydrating = false
      _setState("unconfigured")
      return
    }
    try {
      var parsed = JSON.parse(text)
      controllerIp = DirectorClient.normalizeHost(parsed.controllerIp)
      email = String(parsed.email || "").trim()
      password = parsed.password !== undefined && parsed.password !== null
        ? String(parsed.password) : ""
    } catch (e) {
      controllerIp = ""
      email = ""
      password = ""
    }
    _credentialsLoaded = true
    _hydrating = false
    _refreshStatusText()
    if (configured)
      _autoConnectPending = true
    if (_autoConnectPending) {
      _autoConnectPending = false
      connectNow()
    }
  }

  onControllerIpChanged: if (!_hydrating) _refreshStatusText()
  onEmailChanged: if (!_hydrating) _refreshStatusText()
  onPasswordChanged: if (!_hydrating) _refreshStatusText()
  onHasTokenChanged: _refreshStatusText()

  FileView {
    id: credentialsFile
    path: root.credentialsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadCredentials(text())
    onLoadFailed: root.loadCredentials("")
  }

  FileView {
    id: focusFile
    path: root.focusPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadFocus(text())
    onLoadFailed: root.loadFocus("")
  }

  FileView {
    id: bodyFile
    path: root.bodyPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
    running: false
    onExited: Qt.callLater(function() {
      if (credentialsFile)
        credentialsFile.reload()
      if (focusFile)
        focusFile.reload()
    })
  }

  Process {
    id: chmodProc
    running: false
    command: ["chmod", "600", root.credentialsPath]
  }

  Process {
    id: chmodFocusProc
    running: false
    command: ["chmod", "600", root.focusPath]
  }

  Process {
    id: chmodBodyProc
    running: false
    command: ["chmod", "600", root.bodyPath]
    onExited: {
      if (root._pending)
        root._startHttp(root._pending)
    }
  }

  Process {
    id: rmBodyProc
    running: false
    command: ["rm", "-f", root.bodyPath]
    onExited: root._pump()
  }

  Process {
    id: httpProc
    running: false
    command: ["true"]
    stdout: StdioCollector {
      id: httpStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: httpStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root._ignoreHttpExit) {
        root._ignoreHttpExit = false
        return
      }
      root._finishHttp(exitCode, httpStdout.text || "")
    }
  }

  Timer {
    id: refreshTimer
    repeat: false
    onTriggered: {
      if (!root.configured) {
        root._setState("unconfigured")
        return
      }
      root._refreshing = true
      root._accountToken = ""
      root._startAccountAuth()
    }
  }

  Timer {
    id: volumeTimer
    interval: 2000
    repeat: true
    running: false
    onTriggered: root.refreshVolume()
  }

  Component.onCompleted: mkdirProc.running = true
}
