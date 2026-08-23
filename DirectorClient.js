.pragma library

// Public pyControl4 client key — not a user secret.
var APPLICATION_KEY = "78f6791373d61bea49fdb9fb8897f1f3af193f11"

var ACCOUNT_AUTH_URL = "https://apis.control4.com/authentication/v1/rest"
var ACCOUNTS_URL = "https://apis.control4.com/account/v3/rest/accounts"
var DIRECTOR_AUTH_URL = "https://apis.control4.com/authentication/v1/rest/authorization"

var STATUS_NOT_CONFIGURED = "Not configured"
var STATUS_NOT_CONNECTED = "Not connected"
var STATUS_CONNECTING = "Connecting…"
var STATUS_CONNECTED = "Connected"
var STATUS_SIGN_IN_FAILED = "Sign-in failed"
var STATUS_DIRECTOR_401 = "Director rejected the session (HTTP 401). This is expected on Control4 OS 4.2."

function accountAuthBody(email, password) {
  return JSON.stringify({
    clientInfo: {
      device: {
        deviceName: "pyControl4",
        deviceUUID: "0000000000000000",
        make: "pyControl4",
        model: "pyControl4",
        os: "Android",
        osVersion: "10"
      },
      userInfo: {
        applicationKey: APPLICATION_KEY,
        password: String(password || ""),
        userName: String(email || "")
      }
    }
  })
}

function directorAuthBody(commonName) {
  return JSON.stringify({
    serviceInfo: {
      commonName: String(commonName || ""),
      services: "director"
    }
  })
}

function commandBody(command, params) {
  var tParams = params && typeof params === "object" ? params : {}
  return JSON.stringify({
    async: true,
    command: String(command || ""),
    tParams: tParams
  })
}

function normalizeHost(raw) {
  var s = String(raw || "").trim()
  s = s.replace(/^https?:\/\//i, "")
  var slash = s.indexOf("/")
  if (slash !== -1)
    s = s.substring(0, slash)
  return s
}

function credentialsComplete(ip, email, password) {
  return normalizeHost(ip).length > 0
    && String(email || "").trim().length > 0
    && String(password || "").length > 0
}

function parseHttp(stdout) {
  var text = String(stdout || "")
  var lastNl = text.lastIndexOf("\n")
  if (lastNl === -1)
    return { body: text, status: 0 }
  var codeStr = text.substring(lastNl + 1).trim()
  var status = parseInt(codeStr, 10)
  if (!isFinite(status))
    return { body: text, status: 0 }
  return { body: text.substring(0, lastNl), status: status }
}

function parseAccountToken(body) {
  try {
    var json = JSON.parse(body)
    var token = json && json.authToken && json.authToken.token
    if (!token)
      return { ok: false }
    return { ok: true, token: String(token) }
  } catch (e) {
    return { ok: false }
  }
}

function parseControllerCommonName(body) {
  try {
    var json = JSON.parse(body)
    var account = json && json.account
    if (Array.isArray(account))
      account = account.length > 0 ? account[0] : null
    var name = account && account.controllerCommonName
    if (!name)
      return { ok: false }
    return { ok: true, commonName: String(name) }
  } catch (e) {
    return { ok: false }
  }
}

function parseDirectorToken(body) {
  try {
    var json = JSON.parse(body)
    var auth = json && json.authToken
    var token = auth && auth.token
    if (!token)
      return { ok: false }
    var seconds = parseInt(auth.validSeconds, 10)
    if (!isFinite(seconds) || seconds <= 0)
      seconds = 86400
    return { ok: true, token: String(token), validSeconds: seconds }
  } catch (e) {
    return { ok: false }
  }
}

function classifyCloudStatus(status) {
  if (status === 200)
    return { kind: "ok" }
  if (status === 401 || status === 403)
    return { kind: "sign-in" }
  if (status <= 0)
    return { kind: "error", message: "Could not reach Control4" }
  return { kind: "error", message: "Control4 account request failed (HTTP " + status + ")" }
}

function classifyProbe(status) {
  if (status === 200)
    return { kind: "connected" }
  if (status === 401)
    return { kind: "director401" }
  if (status <= 0)
    return { kind: "error", message: "Could not reach the Director" }
  return { kind: "error", message: "Director request failed (HTTP " + status + ")" }
}

function networkErrorMessage(exitCode) {
  if (exitCode === 28)
    return "Request timed out"
  if (exitCode === 7)
    return "Could not connect"
  return "Network error"
}

function statusTextFor(sessionState, authFailedKind, lastError, hasCredentials, hasToken) {
  if (sessionState === "connecting")
    return STATUS_CONNECTING
  if (sessionState === "connected")
    return STATUS_CONNECTED
  if (sessionState === "auth-failed") {
    if (authFailedKind === "director401")
      return STATUS_DIRECTOR_401
    return STATUS_SIGN_IN_FAILED
  }
  if (sessionState === "error")
    return lastError || "Network error"
  if (hasCredentials && !hasToken)
    return STATUS_NOT_CONNECTED
  return STATUS_NOT_CONFIGURED
}

function curlArgs(opts) {
  var args = ["curl", "-sS", "--max-time", "10"]
  if (opts && opts.insecure)
    args.push("-k")
  args.push("-w", "\n%{http_code}")
  if (opts && opts.bodyPath) {
    args.push("-H", "Content-Type: application/json")
    args.push("--data-binary", "@" + opts.bodyPath)
  }
  args.push(String(opts && opts.url || ""))
  return args
}

function withAuthHeader(args, token) {
  if (!token)
    return args.slice()
  var out = args.slice()
  out.splice(out.length - 1, 0, "-H", "Authorization: Bearer " + String(token))
  return out
}

function directorUrl(host, path) {
  var p = String(path || "")
  if (p.charAt(0) !== "/")
    p = "/" + p
  return "https://" + normalizeHost(host) + p
}
