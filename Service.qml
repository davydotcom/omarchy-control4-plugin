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
  property var selectedSourceId: null
  property bool remoteOpen: false
  property string remoteTitle: ""
  property var remoteDeviceId: null
  property bool remoteMenu: false
  property bool remoteUp: false
  property bool remoteDown: false
  property bool remoteLeft: false
  property bool remoteRight: false
  property bool remoteEnter: false
  property bool remotePlay: false
  property bool remoteStop: false
  property bool remotePause: false
  property bool remoteSkipFwd: false
  property bool remoteSkipRev: false
  property bool remoteScanFwd: false
  property bool remoteScanRev: false
  property bool remoteChannelUp: false
  property bool remoteChannelDown: false
  property bool remoteNumberPad: false
  property bool remoteStar: false
  property bool remotePound: false
  property var remoteSurroundModes: []
  property bool browseOpen: false
  property bool browseBusy: false
  property string browseTitle: ""
  property string browseHint: ""
  property var browseRows: []
  property var _browseStack: []
  property var _browseCtx: null
  property int _mspDeviceId: 0
  property string _mspSvc: ""
  property string _navSid: ""
  property string _navClientId: ""
  property string _navSubId: ""
  property string _navPhase: ""
  property int _navSeq: 100
  property int _navWaitSeq: 0
  property var _navWaitCb: null
  property bool _navIgnoreExit: false
  property bool _navRestartPending: false
  property string _navCookiePath: stateDir + "/nav-cookies.txt"
  property string _navQueuedUrl: ""
  property int _navQueuedMaxTime: 35
  property int _navPostMaxTime: 12
  property bool _browsePending: false
  property int _browseTries: 0
  property var _uiConfig: null
  property var _items: null
  property int volume: 0
  property bool muted: false
  // null until the Director reports POWER_STATE — off and unknown must stay distinct.
  property var roomOn: null
  property string playingSourceName: ""
  property var currentVideoDeviceId: null
  property var playingAudioDeviceId: null
  property string lastDeviceGroup: ""
  property bool _wantSourceRestore: false
  property var _volumeHoldUntil: 0
  property int _volumeGen: 0
  property bool _volumePending: false

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
  property int _errorRetries: 0
  property var _queue: []
  property var _pending: null
  property var _pendingCallback: null
  property bool _ignoreHttpExit: false
  // The curl config text for the request currently being started. Written to
  // the process's stdin in onStarted; never touches disk.
  property string _httpConfig: ""
  property string _navConfig: ""
  property string _credWritePayload: ""
  property string _focusWritePayload: ""

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
    roomOn = null
    playingSourceName = ""
    volumeTimer.stop()
    rmProc.running = true
    _setState("unconfigured")
  }

  function _abortHttp() {
    _queue = []
    _pending = null
    _pendingCallback = null
    // The in-flight volume request's callback will never run, so its guard has
    // to be released here or the 2 s poll would never issue another request.
    _volumePending = false
    if (httpProc.running) {
      _ignoreHttpExit = true
      httpProc.running = false
    }
    _stopNav()
    closeBrowse()
    closeRemote()
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
    _credWritePayload = JSON.stringify(payload, null, 2) + "\n"
    credWriteProc.stdinEnabled = true
    credWriteProc.running = true
  }

  function _setState(next) {
    sessionState = next
    if (next === "auth-failed" || next === "error")
      refreshTimer.stop()
    if (next === "connected")
      _errorRetries = 0
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
    roomOn = null
    playingSourceName = ""
    roomsHint = ""
    persistFocus(match.id)
    selectedSourceId = null
    closeBrowse()
    closeRemote()
    _wantSourceRestore = true
    _rebuildSources(true)
    refreshVolume()
  }

  function setSourceMode(mode) {
    if (mode !== "watch" && mode !== "listen")
      return
    if (sourceMode === mode)
      return
    sourceMode = mode
    selectedSourceId = null
    closeBrowse()
    closeRemote()
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
    var already = _alreadyCurrentSource(n)
    selectedSourceId = n
    if (!already) {
      var command = sourceMode === "listen" ? "SELECT_AUDIO_DEVICE" : "SELECT_VIDEO_DEVICE"
      directorPost("/api/v1/items/" + focusedRoomId + "/commands", command, { deviceid: n }, function() {})
      roomOn = true
      lastDeviceGroup = sourceMode
      var picked = ""
      if (list && list.length) {
        for (var j = 0; j < list.length; j++) {
          if (list[j] && Number(list[j].id) === n && list[j].name)
            picked = String(list[j].name)
        }
      }
      playingSourceName = picked
    }
    if (sourceMode === "watch") {
      closeBrowse()
      var watchItem = DirectorClient.itemForWatchRemote(_items, n)
      if (DirectorClient.hasWatchRemoteUi(DirectorClient.parseRemoteCapabilities(watchItem)))
        openWatchRemote(n)
      else
        closeRemote()
      return
    }
    closeRemote()
    var svc = _mspServiceOf(n)
    if (svc) {
      _browseTries = 0
      openMspBrowse(n, svc)
    } else
      closeBrowse()
  }

  function _alreadyCurrentSource(n) {
    if (sourceMode === "listen")
      return playingAudioDeviceId != null && Number(playingAudioDeviceId) === Number(n)
    var matched = DirectorClient.matchWatchSourceId(sources, _items, currentVideoDeviceId)
    if (matched != null && Number(matched) === Number(n))
      return true
    return currentVideoDeviceId != null && Number(currentVideoDeviceId) === Number(n)
  }

  function restoreActiveSource() {
    if (sessionState !== "connected" || focusedRoomId === null || focusedRoomId === undefined)
      return
    var watchList = DirectorClient.extractSources(_uiConfig, _items, focusedRoomId, "watch")
    var watchId = DirectorClient.matchWatchSourceId(watchList, _items, currentVideoDeviceId)
    if (watchId != null) {
      if (sourceMode !== "watch") {
        sourceMode = "watch"
        _rebuildSources(false)
      }
      selectedSourceId = watchId
      closeBrowse()
      if (roomOn === false) {
        closeRemote()
        return
      }
      var watchItem = DirectorClient.itemForWatchRemote(_items, watchId)
      if (DirectorClient.hasWatchRemoteUi(DirectorClient.parseRemoteCapabilities(watchItem)))
        openWatchRemote(watchId)
      else
        closeRemote()
      return
    }
    if (String(lastDeviceGroup) !== "listen" || playingAudioDeviceId == null)
      return
    var listenList = DirectorClient.extractSources(_uiConfig, _items, focusedRoomId, "listen")
    var audioId = Number(playingAudioDeviceId)
    var found = false
    if (listenList && listenList.length) {
      for (var i = 0; i < listenList.length; i++) {
        if (listenList[i] && Number(listenList[i].id) === audioId) {
          found = true
          break
        }
      }
    }
    if (!found)
      return
    if (sourceMode !== "listen") {
      sourceMode = "listen"
      _rebuildSources(false)
    }
    selectedSourceId = audioId
    closeRemote()
    closeBrowse()
  }

  function _itemById(id) {
    var n = Number(id)
    var list = _items
    if (!list || !list.length)
      return null
    for (var i = 0; i < list.length; i++) {
      if (list[i] && Number(list[i].id) === n)
        return list[i]
    }
    return null
  }

  function _mspServiceOf(id) {
    var item = _itemById(id)
    if (DirectorClient.isAppleMusicItem(item))
      return "apple"
    if (DirectorClient.isTuneInItem(item))
      return "tunein"
    return ""
  }

  function openMspBrowse(id, svc) {
    var item = _itemById(id)
    _mspDeviceId = Number(id)
    _mspSvc = svc || _mspSvc || "apple"
    browseOpen = true
    browseBusy = true
    browseHint = ""
    browseTitle = item && item.name ? String(item.name) : "Listen"
    browseRows = []
    _browseStack = []
    _browseCtx = null
    _browsePending = true
    if (_navPhase !== "live" || !_navClientId) {
      browseHint = "Connecting…"
      if (!_navPhase)
        _startNav()
      return
    }
    _browsePending = false
    if (_mspSvc === "tunein") {
      _loadTuneInTabs(item)
      return
    }
    _mspCommand("GetTabList", {}, function(resp) {
      browseRows = DirectorClient.parseMspTabs(resp && resp.DATA)
      browseBusy = false
      browseHint = browseRows.length ? "" : "No sections"
    })
  }

  function _loadTuneInTabs(item) {
    var path = DirectorClient.driverXmlPath(item)
    if (!path) {
      browseBusy = false
      browseHint = "No TuneIn driver"
      return
    }
    var deviceId = _mspDeviceId
    directorGet(path, function(err, body) {
      if (root._mspDeviceId !== deviceId || !root.browseOpen)
        return
      var tabs = err ? [] : DirectorClient.parseTuneInTabs(body)
      if (!tabs.length) {
        root._tuneInBrowse("Browse", "")
        return
      }
      root.browseRows = tabs
      root.browseBusy = false
      root.browseHint = ""
    })
  }

  function _applyRemoteCaps(caps) {
    var nav = caps && caps.nav ? caps.nav : {}
    remoteMenu = !!nav.menu
    remoteUp = !!nav.up
    remoteDown = !!nav.down
    remoteLeft = !!nav.left
    remoteRight = !!nav.right
    remoteEnter = !!nav.enter
    var tr = caps && caps.transport ? caps.transport : {}
    remotePlay = !!tr.play
    remoteStop = !!tr.stop
    remotePause = !!tr.pause
    remoteSkipFwd = !!tr.skipFwd
    remoteSkipRev = !!tr.skipRev
    remoteScanFwd = !!tr.scanFwd
    remoteScanRev = !!tr.scanRev
    remoteChannelUp = !!(caps && caps.hasChannelUpDown && DirectorClient.hasRemoteCommand(caps, "CHANNEL_UP"))
    remoteChannelDown = !!(caps && caps.hasChannelUpDown && DirectorClient.hasRemoteCommand(caps, "CHANNEL_DOWN"))
    remoteNumberPad = !!(caps && caps.hasDiscreteChannelSelect && caps.hasDigits)
    remoteStar = !!(caps && caps.hasDiscreteChannelSelect && DirectorClient.hasRemoteCommand(caps, "STAR"))
    remotePound = !!(caps && caps.hasDiscreteChannelSelect && DirectorClient.hasRemoteCommand(caps, "POUND"))
    remoteSurroundModes = caps && caps.surroundModes ? caps.surroundModes : []
  }

  function closeRemote() {
    remoteOpen = false
    remoteTitle = ""
    remoteDeviceId = null
    _applyRemoteCaps(null)
  }

  function openWatchRemote(id) {
    var item = DirectorClient.itemForWatchRemote(_items, id)
    var caps = DirectorClient.parseRemoteCapabilities(item)
    if (!DirectorClient.hasWatchRemoteUi(caps)) {
      closeRemote()
      return
    }
    remoteOpen = true
    remoteTitle = item && item.name ? String(item.name) : ""
    remoteDeviceId = item && item.id != null ? Number(item.id) : Number(id)
    _applyRemoteCaps(caps)
  }

  function sendRemote(command) {
    if (!remoteOpen || sessionState !== "connected")
      return
    var deviceId = remoteDeviceId
    if (deviceId === null || deviceId === undefined || !isFinite(Number(deviceId)))
      return
    var caps = DirectorClient.parseRemoteCapabilities(DirectorClient.findItemById(_items, deviceId))
    if (!DirectorClient.hasRemoteCommand(caps, command))
      return
    directorPost("/api/v1/items/" + deviceId + "/commands", String(command || "").toUpperCase(), {}, function() {})
  }

  function sendSurround(modeId) {
    if (!remoteOpen || sessionState !== "connected")
      return
    var deviceId = remoteDeviceId
    if (deviceId === null || deviceId === undefined || !isFinite(Number(deviceId)))
      return
    var caps = DirectorClient.parseRemoteCapabilities(DirectorClient.findItemById(_items, deviceId))
    var modes = caps && caps.surroundModes ? caps.surroundModes : []
    var n = Number(modeId)
    var found = false
    for (var i = 0; i < modes.length; i++) {
      if (Number(modes[i].id) === n) {
        found = true
        break
      }
    }
    if (!found)
      return
    var params = DirectorClient.surroundModeParams(n)
    if (!params)
      return
    directorPost("/api/v1/items/" + deviceId + "/commands", "SET_SURROUND_MODE", params, function() {})
  }

  function closeBrowse() {
    try { browseWaitTimer.stop() } catch (e) {}
    try { playHintTimer.stop() } catch (e) {}
    browseOpen = false
    browseBusy = false
    browseHint = ""
    browseTitle = ""
    browseRows = []
    _browseStack = []
    _browseCtx = null
    _navWaitSeq = 0
    _navWaitCb = null
    _browsePending = false
    _browseTries = 0
    _mspSvc = ""
    _stopNav()
  }

  function browseBack() {
    var stack = _browseStack
    if (!stack || !stack.length) {
      closeBrowse()
      return
    }
    var prev = stack[stack.length - 1]
    _browseStack = stack.slice(0, stack.length - 1)
    browseTitle = prev.title
    browseRows = prev.rows
    _browseCtx = prev.ctx
    browseBusy = false
    browseHint = ""
  }

  function browseTap(index) {
    var rows = browseRows
    if (!rows || index < 0 || index >= rows.length)
      return
    var row = rows[index]
    if (!row)
      return
    if (row.svc === "tunein") {
      _tuneInTap(row)
      return
    }
    var action = String(row.defaultAction || row.default_action || "")
    var kind = String(row.itemType || "")
    if (action === "BrowseTab" || kind === "tab") {
      _pushBrowse()
      browseTitle = row.title
      browseRows = []
      browseHint = "Loading…"
      _browseCtx = { screenId: row.screenId || "ListScreen", tabId: row.tabId || row.id }
      _mspBrowse(_browseCtx)
      return
    }
    var playCmd = DirectorClient.mspPlayCommand(row)
    if (playCmd) {
      var playArgs = {
        screenId: row.screenId || "ListScreen",
        tabId: row.tabId || "",
        id: row.id,
        itemType: kind
      }
      if (row.href)
        playArgs.href = row.href
      if (playCmd === "Play")
        playArgs.playOption = "NOW"
      browseBusy = false
      browseHint = "Playing…"
      playHintTimer.restart()
      _mspFire(playCmd, playArgs)
      return
    }
    _pushBrowse()
    browseTitle = row.title
    browseRows = []
    browseHint = "Loading…"
    _browseCtx = {
      screenId: row.screenId || "ListScreen",
      tabId: row.tabId || "",
      id: row.id,
      itemType: kind === "tab" ? "" : kind
    }
    _mspCommand("SelectItem", _browseCtx, function(resp) {
      var next = DirectorClient.parseMspNextScreen(resp && resp.DATA)
      if (next)
        _browseCtx.screenId = next
      _mspBrowse(_browseCtx)
    })
  }

  function _tuneInTap(row) {
    if (row.isHeader)
      return
    if (row.isTab || row.folder) {
      _pushBrowse()
      browseTitle = row.title
      browseRows = []
      browseHint = "Loading…"
      _tuneInBrowse(row.isTab ? row.screen : (row.screen || "Browse"), row.isTab ? "" : row.url)
      return
    }
    browseBusy = false
    browseHint = "Playing…"
    playHintTimer.restart()
    _mspFire("BrowseCommand", DirectorClient.tuneInTapArgs(row))
  }

  function _tuneInBrowse(screen, url) {
    var sid = screen || "Browse"
    var args = { screen: sid }
    if (url)
      args.URL = url
    _browseCtx = { svc: "tunein", screen: sid, url: url || "" }
    browseBusy = true
    if (!browseHint)
      browseHint = "Loading…"
    _mspCommand("GetBrowseMenu", args, function(resp) {
      var next = DirectorClient.parseTuneInList(resp && resp.DATA, sid)
      browseRows = next
      browseBusy = false
      browseHint = next.length ? "" : "Nothing in this folder"
    })
  }

  function _pushBrowse() {
    var stack = _browseStack ? _browseStack.slice() : []
    stack.push({ title: browseTitle, rows: browseRows, ctx: _browseCtx })
    _browseStack = stack
  }

  function _mspBrowse(ctx) {
    var c = ctx || {}
    var args = {
      screenId: c.screenId || "ListScreen",
      tabId: c.tabId || "",
      offset: "0",
      limit: "50"
    }
    if (c.id)
      args.id = c.id
    if (c.itemType && c.itemType !== "tab")
      args.itemType = c.itemType
    browseBusy = true
    if (!browseHint)
      browseHint = "Loading…"
    _mspCommand("Browse", args, function(resp) {
      var next = DirectorClient.parseMspList(resp && resp.DATA, c.screenId, c.tabId)
      browseRows = next
      browseBusy = false
      browseHint = next.length ? "" : "Nothing in this folder"
    })
  }

  function _mspFire(command, args) {
    if (!_navClientId || !_mspDeviceId || focusedRoomId === null || focusedRoomId === undefined)
      return
    if (!navProc.running)
      _navPoll()
    directorPost("/api/v1/items/" + _mspDeviceId + "/commands", command, {
      NAVID: _navClientId,
      ROOMID: String(focusedRoomId),
      SEQ: String(_navSeq + 1),
      ARGS: DirectorClient.mspArgXml(args || {})
    }, function() {})
  }

  function _mspCommand(command, args, done) {
    if (_navPhase !== "live" || !_navClientId || !_mspDeviceId || focusedRoomId === null || focusedRoomId === undefined) {
      browseBusy = true
      browseHint = "Connecting…"
      if (!_navPhase)
        _startNav()
      return
    }
    _navSeq += 1
    _navWaitSeq = _navSeq
    _navWaitCb = typeof done === "function" ? done : null
    browseBusy = true
    browseWaitTimer.restart()
    if (!navProc.running)
      _navPoll()
    var seq = _navWaitSeq
    var deviceId = _mspDeviceId
    var navid = _navClientId
    var roomId = focusedRoomId
    var cmd = command
    var tParams = {
      NAVID: navid,
      ROOMID: String(roomId),
      SEQ: String(seq),
      ARGS: DirectorClient.mspArgXml(args || {})
    }
    Qt.callLater(function() {
      if (root._navWaitSeq !== seq)
        return
      root.directorPost("/api/v1/items/" + deviceId + "/commands", cmd, tParams, function() {})
    })
  }

  function _onMspResponse(resp) {
    if (!resp || Number(resp.SEQ) !== Number(_navWaitSeq))
      return
    browseWaitTimer.stop()
    var cb = _navWaitCb
    _navWaitSeq = 0
    _navWaitCb = null
    if (cb)
      cb(resp)
  }

  function _startNav() {
    if (!_directorToken || !DirectorClient.normalizeHost(controllerIp))
      return
    _stopNav()
    _navPhase = "handshake"
    _navSid = ""
    _navClientId = ""
    _navSubId = ""
    // No touch needed: `cookie` on a nonexistent path is a no-op, and the curl
    // wrapper's `umask 077` creates the jar 0600 when `cookie-jar` first writes.
    //
    // _stopNav() only *requests* termination: Quickshell keeps Process.running
    // true until the child actually exits, and a running = true that lands
    // before then is silently dropped. Measured on Quickshell 0.3.1. So when a
    // long poll is still live — the reconnect-while-browsing path — hand the
    // handshake off to its exit signal instead of starting it here.
    if (navProc.running) {
      _navRestartPending = true
      return
    }
    _navHandshake()
  }

  function _navHandshake() {
    _navGet("/socket.io/?EIO=4&transport=polling", 12)
  }

  function _stopNav() {
    _navPhase = ""
    _navSid = ""
    _navClientId = ""
    _navSubId = ""
    _navQueuedUrl = ""
    _navRestartPending = false
    _navIgnoreExit = true
    if (navProc.running)
      navProc.running = false
  }

  function _navSocketUrl() {
    var q = "/socket.io/?EIO=4&transport=polling"
    if (_navSid)
      q += "&sid=" + encodeURIComponent(_navSid)
    return DirectorClient.directorUrl(controllerIp, q)
  }

  function _navGet(path, maxTime) {
    var url = path.indexOf("https:") === 0 ? path : DirectorClient.directorUrl(controllerIp, path)
    root._navQueuedUrl = url
    root._navQueuedMaxTime = maxTime || 35
    _startNavGet()
  }

  function _navPostRaw(body, maxTime) {
    root._navPostMaxTime = maxTime || 12
    _startNavPost(String(body || ""))
  }

  function _startNavGet() {
    if (!root._navPhase)
      return
    root._navConfig = DirectorClient.curlNavConfigText({
      url: root._navQueuedUrl,
      insecure: true,
      maxTime: root._navQueuedMaxTime,
      cookiePath: root._navCookiePath,
      token: root._directorToken
    })
    root._navIgnoreExit = false
    navProc.stdinEnabled = true
    navProc.running = true
  }

  function _startNavPost(body) {
    if (!root._navPhase)
      return
    root._navConfig = DirectorClient.curlNavConfigText({
      url: root._navSocketUrl(),
      insecure: true,
      maxTime: root._navPostMaxTime,
      body: body,
      contentType: "text/plain",
      cookiePath: root._navCookiePath,
      token: root._directorToken
    })
    root._navIgnoreExit = false
    navProc.stdinEnabled = true
    navProc.running = true
  }

  function _onNavExit(exitCode) {
    if (_navIgnoreExit) {
      _navIgnoreExit = false
      if (_navRestartPending) {
        _navRestartPending = false
        if (_navPhase === "handshake")
          _navHandshake()
      }
      return
    }
    if (exitCode === 63) {
      _stopNav()
      return
    }
    _finishNavBody(navStdout.text)
  }

  function _finishNavBody(stdout) {
    var text = String(stdout || "")
    if (DirectorClient.isOversizedResponse(text)) {
      _stopNav()
      return
    }
    if (_navPhase === "handshake") {
      _navSid = DirectorClient.parseEngineIoSid(text)
      if (!_navSid) {
        _navPhase = ""
        return
      }
      _navPhase = "ns"
      _navPostRaw("40", 12)
      return
    }
    if (_navPhase === "ns") {
      _navPhase = "client"
      _navGet(_navSocketUrl().replace(/^https:\/\/[^/]+/, ""), 20)
      return
    }
    var cid = DirectorClient.parseSocketIoClientId(text)
    if (cid && !_navClientId) {
      _navClientId = cid
      _navPhase = "subscribe"
      directorGet("/api/v1/items/datatoui?SubscriptionClient=" + encodeURIComponent(cid), function(err, body) {
        if (err || !body) {
          root._navPhase = "live"
          root._navPoll()
          return
        }
        try {
          var json = JSON.parse(body)
          root._navSubId = json && json.subscriptionId ? String(json.subscriptionId) : ""
        } catch (e) {
          root._navSubId = ""
        }
        if (root._navSubId)
          root._navPostRaw("42[\"startSubscription\",\"" + root._navSubId + "\"]", 12)
        else {
          root._navPhase = "live"
          root._navPoll()
          if (root.browseOpen && root.browseBusy && root._mspDeviceId)
            root.openMspBrowse(root._mspDeviceId, root._mspSvc)
        }
      })
      return
    }
    if (_navPhase === "subscribe") {
      _navPhase = "live"
      _navPoll()
      if (browseOpen && _mspDeviceId && _navClientId) {
        Qt.callLater(function() {
          if (root._navPhase === "live" && root.browseOpen)
            root.openMspBrowse(root._mspDeviceId, root._mspSvc)
        })
      }
      return
    }
    var resps = DirectorClient.parseMspResponses(text)
    if (!resps || !resps.length) {
      var one = DirectorClient.parseMspResponse(text)
      resps = one ? [one] : []
    }
    for (var ri = 0; ri < resps.length; ri++)
      _onMspResponse(resps[ri])
    if (String(text).trim() === "2") {
      _navPostRaw("3", 8)
      return
    }
    if (_navPhase === "live" || _navPhase === "client")
      _navPoll()
  }

  function _navPoll() {
    if (_navPhase !== "live" && _navPhase !== "client")
      return
    if (!_navSid || !_directorToken)
      return
    _navGet(_navSocketUrl().replace(/^https:\/\/[^/]+/, ""), 35)
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
    roomOn = false
    playingSourceName = ""
    _roomCommand("ROOM_OFF", {})
  }

  function refreshVolume() {
    if (sessionState !== "connected" || focusedRoomId === null || focusedRoomId === undefined) {
      volumeTimer.stop()
      roomOn = null
      playingSourceName = ""
      return
    }
    volumeTimer.restart()
    if (root._volumePending)
      return
    root._volumePending = true
    root._volumeGen += 1
    var gen = root._volumeGen
    var id = focusedRoomId
    directorGet("/api/v1/items/" + id + "/variables?varnames=CURRENT_VOLUME,IS_MUTED,POWER_STATE,CURRENT_VIDEO_DEVICE,PLAYING_AUDIO_DEVICE,LAST_DEVICE_GROUP", function(err, body) {
      root._volumePending = false
      if (gen !== root._volumeGen)
        return
      if (err)
        return
      var parsed = DirectorClient.parseRoomVolume(body)
      root.currentVideoDeviceId = parsed.videoDeviceId
      root.playingAudioDeviceId = parsed.playingAudioDeviceId
      root.lastDeviceGroup = parsed.lastDeviceGroup || ""
      if (parsed.power !== undefined)
        root.roomOn = parsed.power
      root.playingSourceName = DirectorClient.nowPlayingLabel(
        parsed,
        root._items,
        DirectorClient.extractSources(root._uiConfig, root._items, id, "watch"),
        DirectorClient.extractSources(root._uiConfig, root._items, id, "listen")
      )
      if (root._wantSourceRestore) {
        root._wantSourceRestore = false
        restoreActiveSource()
      }
      if (Date.now() < root._volumeHoldUntil)
        return
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
        if (items && !Array.isArray(items) && items.items)
          items = items.items
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
    _focusWritePayload = JSON.stringify(payload) + "\n"
    focusWriteProc.stdinEnabled = true
    focusWriteProc.running = true
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
        _wantSourceRestore = true
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
    console.warn("control4:", lastError)
    _setState("error")
    if (configured && _errorRetries < 2) {
      _errorRetries += 1
      retryConnectTimer.restart()
    }
  }

  function _enqueue(job) {
    var next = _queue.slice()
    next.push(job)
    _queue = next
    _pump()
  }

  function _pump() {
    if (httpProc.running || _pending || !_queue.length)
      return
    var job = _queue[0]
    _queue = _queue.slice(1)
    _pending = job
    _pendingCallback = job.callback || null
    _startHttp(job)
  }

  function _startHttp(job) {
    root._httpConfig = DirectorClient.curlConfigText({
      url: job.url,
      insecure: job.insecure === true,
      body: job.body || "",
      token: job.token || ""
    })
    // stdinEnabled latches false once onStarted has written the config, so it
    // has to be reopened before every run.
    httpProc.stdinEnabled = true
    httpProc.running = true
  }

  function _finishHttp(exitCode, body, statusText) {
    var job = _pending
    var cb = _pendingCallback
    _pending = null
    _pendingCallback = null
    if (DirectorClient.isOversizedResponse(body)) {
      var oversized = DirectorClient.networkErrorMessage(63)
      if (cb)
        cb(oversized, "", 0)
      else if (job)
        _handleFlowFailure(job, oversized, 63)
      _pump()
      return
    }
    var parsed = {
      body: String(body || ""),
      status: DirectorClient.parseHttpStatus(statusText)
    }
    if (exitCode !== 0 && parsed.status <= 0) {
      var net = DirectorClient.networkErrorMessage(exitCode)
      if (cb)
        cb(net, parsed.body, parsed.status)
      else if (job)
        _handleFlowFailure(job, net, exitCode)
      _pump()
      return
    }
    if (cb) {
      if (parsed.status >= 200 && parsed.status < 300)
        cb("", parsed.body, parsed.status)
      else
        cb("HTTP " + parsed.status, parsed.body, parsed.status)
      _pump()
      return
    }
    if (job)
      _handleFlowResponse(job, parsed)
    _pump()
  }

  function _handleFlowFailure(job, message, exitCode) {
    var flow = job && (job.kind === "probe" || job.kind === "accountAuth"
      || job.kind === "accounts" || job.kind === "directorAuth")
    if (flow && DirectorClient.isTransientCurl(exitCode) && (!job.tries || job.tries < 2)) {
      job.tries = (job.tries || 0) + 1
      _enqueue(job)
      return
    }
    if (sessionState === "connected" && job && (job.kind === "get" || job.kind === "post"))
      return
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
        if (browseOpen)
          _startNav()
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

  Process {
    id: stateDirProc
    command: ["install", "-d", "-m", "700", root.stateDir]
    running: false
    onExited: credReadProc.running = true
  }

  Process {
    id: credReadProc
    running: false
    command: DirectorClient.stateFileReadCommand(
      root.credentialsPath, DirectorClient.MAX_CREDENTIALS_FILE_BYTES)
    stdout: StdioCollector {
      id: credReadStdout
      waitForEnd: true
    }
    onExited: function(code) {
      root.loadCredentials(code === 0 ? credReadStdout.text : "")
      focusReadProc.running = true
    }
  }

  Process {
    id: credWriteProc
    running: false
    command: DirectorClient.stateFileWriteCommand(
      root.credentialsPath, DirectorClient.MAX_CREDENTIALS_FILE_BYTES)
    stdinEnabled: true
    onStarted: {
      credWriteProc.write(root._credWritePayload)
      credWriteProc.stdinEnabled = false
    }
    onExited: {
      root._ignoreCredentialsLoad = false
      root._credWritePayload = ""
    }
  }

  Process {
    id: focusReadProc
    running: false
    command: DirectorClient.stateFileReadCommand(
      root.focusPath, DirectorClient.MAX_FOCUS_FILE_BYTES)
    stdout: StdioCollector {
      id: focusReadStdout
      waitForEnd: true
    }
    onExited: function(code) {
      root.loadFocus(code === 0 ? focusReadStdout.text : "")
    }
  }

  Process {
    id: focusWriteProc
    running: false
    command: DirectorClient.stateFileWriteCommand(
      root.focusPath, DirectorClient.MAX_FOCUS_FILE_BYTES)
    stdinEnabled: true
    onStarted: {
      focusWriteProc.write(root._focusWritePayload)
      focusWriteProc.stdinEnabled = false
    }
    onExited: {
      root._ignoreFocusLoad = false
      root._focusWritePayload = ""
    }
  }

  Process {
    id: rmProc
    running: false
    command: ["rm", "-f", root._navCookiePath]
  }

  // Both curl processes run the same compile-time-constant wrapper command.
  // The per-request config — URL, bearer token, JWT, body — goes in over stdin
  // and never reaches argv or disk. `Process` has no flush(), and `curl -K -`
  // reads stdin to EOF before starting the transfer, so the write must happen
  // in onStarted and stdin must always be closed straight after: a missed close
  // is a hang until --max-time, not an error.
  Process {
    id: httpProc
    running: false
    command: DirectorClient.CURL_WRAPPER_COMMAND
    stdinEnabled: true
    stdout: StdioCollector {
      id: httpStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: httpStderr
      waitForEnd: true
    }
    onStarted: {
      httpProc.write(root._httpConfig)
      httpProc.stdinEnabled = false
    }
    onExited: {
      if (root._ignoreHttpExit) {
        root._ignoreHttpExit = false
        return
      }
      // The shell's own exit status is head's, not curl's — curl's code and the
      // HTTP status both arrive as markers on stderr.
      var markers = DirectorClient.parseStderrMarkers(httpStderr.text)
      if (markers.exitCode === 63) {
        root._finishHttp(63, "", "0")
        return
      }
      root._finishHttp(markers.exitCode, httpStdout.text, String(markers.status))
    }
  }

  Process {
    id: navProc
    running: false
    command: DirectorClient.CURL_WRAPPER_COMMAND
    stdinEnabled: true
    stdout: StdioCollector {
      id: navStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: navStderr
      waitForEnd: true
    }
    onStarted: {
      navProc.write(root._navConfig)
      navProc.stdinEnabled = false
    }
    onExited: {
      root._onNavExit(DirectorClient.parseStderrMarkers(navStderr.text).exitCode)
    }
  }

  Timer {
    id: browseWaitTimer
    interval: 15000
    repeat: false
    onTriggered: {
      root._navWaitSeq = 0
      root._navWaitCb = null
      if (root.browseOpen && (!root.browseRows || !root.browseRows.length) && root._browseTries < 1 && root._navPhase === "live") {
        root._browseTries += 1
        root.browseHint = "Retrying…"
        if (!navProc.running)
          root._navPoll()
        if (root._browseCtx && root._browseCtx.svc === "tunein")
          root._tuneInBrowse(root._browseCtx.screen, root._browseCtx.url)
        else if (root._browseCtx)
          root._mspBrowse(root._browseCtx)
        else
          root.openMspBrowse(root._mspDeviceId, root._mspSvc)
        return
      }
      root.browseBusy = false
      if (root.browseOpen && (!root.browseRows || !root.browseRows.length))
        root.browseHint = (root.browseTitle || "This source") + " did not respond"
    }
  }

  Timer {
    id: playHintTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (root.browseHint === "Playing…")
        root.browseHint = ""
    }
  }

  Timer {
    id: retryConnectTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (root.sessionState === "error" && root.configured)
        root.connectNow()
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

  Component.onCompleted: stateDirProc.running = true
}
