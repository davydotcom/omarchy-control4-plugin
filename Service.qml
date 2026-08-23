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
  readonly property string bodyPath: stateDir + "/http-body.json"

  property string sessionState: "unconfigured"
  property string statusText: DirectorClient.STATUS_NOT_CONFIGURED
  property string lastError: ""
  property string authFailedKind: ""
  property string controllerIp: ""
  property string email: ""
  property string password: ""

  property string _accountToken: ""
  property string _directorToken: ""
  property int _validSeconds: 86400
  property bool _refreshing: false
  property bool _hydrating: false
  property bool _autoConnectPending: false
  property bool _credentialsLoaded: false
  property bool _ignoreCredentialsLoad: false
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
    _setState("unconfigured")
  }

  function _abortHttp() {
    _queue = []
    _pending = null
    _pendingCallback = null
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
      bodyFile.setText(job.body)
      Qt.callLater(function() {
        if (root._pending !== job)
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
    onExited: Qt.callLater(function() { credentialsFile.reload() })
  }

  Process {
    id: chmodProc
    running: false
    command: ["chmod", "600", root.credentialsPath]
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

  Component.onCompleted: mkdirProc.running = true
}
