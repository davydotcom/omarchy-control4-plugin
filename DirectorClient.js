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
  var code = Number(exitCode)
  if (code === 28)
    return "Request timed out"
  if (code === 7)
    return "Could not connect"
  if (code === 26)
    return "Could not read request body"
  if (code === 15 || code === 143 || code === 130)
    return "Request interrupted"
  if (!isFinite(code) || code === 0)
    return "Network error"
  return "Network error (" + code + ")"
}

function isTransientCurl(exitCode) {
  var code = Number(exitCode)
  return code === 7 || code === 23 || code === 26 || code === 28
    || code === 52 || code === 56 || code === 15 || code === 130 || code === 143
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
  var args = ["curl", "-sS", "--max-time", "20"]
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

function isRoomHidden(value) {
  return value === true || value === "1" || value === 1
}

function sortRoomsByNameThenId(a, b) {
  var an = String(a && a.name != null ? a.name : "")
  var bn = String(b && b.name != null ? b.name : "")
  var cmp = an.localeCompare(bn)
  if (cmp !== 0)
    return cmp
  var aid = Number(a && a.id)
  var bid = Number(b && b.id)
  if (!isFinite(aid))
    aid = 0
  if (!isFinite(bid))
    bid = 0
  return aid - bid
}

function parseFocusFile(raw) {
  try {
    var text = String(raw || "").trim()
    if (!text)
      return null
    var json = JSON.parse(text)
    if (!json || typeof json !== "object" || Array.isArray(json))
      return null
    if (json.roomId === undefined || json.roomId === null || json.roomId === "")
      return null
    if (typeof json.roomId !== "number" && typeof json.roomId !== "string")
      return null
    var id = Number(json.roomId)
    if (!isFinite(id))
      return null
    return id
  } catch (e) {
    return null
  }
}

function extractRooms(uiConfig, items) {
  var experiences = uiConfig && uiConfig.experiences
  if (!Array.isArray(experiences))
    return []
  var itemList = Array.isArray(items) ? items : []

  var roomsById = {}
  for (var i = 0; i < itemList.length; i++) {
    var item = itemList[i]
    if (!item || item.typeName !== "room")
      continue
    var itemId = Number(item.id)
    if (!isFinite(itemId))
      continue
    roomsById[itemId] = item
  }

  var seen = {}
  var out = []
  for (var j = 0; j < experiences.length; j++) {
    var exp = experiences[j]
    if (!exp)
      continue
    if (exp.type !== "watch" && exp.type !== "listen")
      continue
    var roomId = Number(exp.room_id)
    if (!isFinite(roomId))
      continue
    if (seen[roomId])
      continue
    seen[roomId] = true
    var room = roomsById[roomId]
    if (!room)
      continue
    if (isRoomHidden(room.roomHidden))
      continue
    var name = room.name !== undefined && room.name !== null ? String(room.name).trim() : ""
    if (!name)
      continue
    out.push({ id: roomId, name: name })
  }
  out.sort(sortRoomsByNameThenId)
  return out
}

function sourceArray(exp) {
  if (!exp || !exp.sources)
    return []
  var s = exp.sources.source
  if (Array.isArray(s))
    return s
  if (s && typeof s === "object")
    return [s]
  return []
}

function extractSources(uiConfig, items, roomId, mode) {
  var type = mode === "listen" ? "listen" : "watch"
  var rid = Number(roomId)
  if (!isFinite(rid))
    return []
  var experiences = uiConfig && uiConfig.experiences
  if (!Array.isArray(experiences))
    return []
  var itemList = Array.isArray(items) ? items : []
  var namesById = {}
  for (var i = 0; i < itemList.length; i++) {
    var item = itemList[i]
    if (!item)
      continue
    var iid = Number(item.id)
    if (!isFinite(iid))
      continue
    var itemName = item.name !== undefined && item.name !== null ? String(item.name).trim() : ""
    if (itemName)
      namesById[iid] = itemName
  }
  var seen = {}
  var out = []
  for (var j = 0; j < experiences.length; j++) {
    var exp = experiences[j]
    if (!exp || exp.type !== type)
      continue
    if (Number(exp.room_id) !== rid)
      continue
    var srcs = sourceArray(exp)
    for (var k = 0; k < srcs.length; k++) {
      var src = srcs[k]
      if (!src)
        continue
      var id = Number(src.id)
      if (!isFinite(id) || seen[id])
        continue
      var name = src.name !== undefined && src.name !== null ? String(src.name).trim() : ""
      if (!name)
        name = namesById[id] || ""
      if (!name)
        continue
      seen[id] = true
      out.push({ id: id, name: name })
    }
  }
  out.sort(sortRoomsByNameThenId)
  return out
}

function _emptyRoomVolume() {
  return {
    volume: null,
    muted: false,
    power: null,
    videoDeviceId: null,
    playingAudioDeviceId: null,
    lastDeviceGroup: ""
  }
}

function _finiteId(value) {
  var n = Number(value)
  return isFinite(n) ? n : null
}

function parseRoomVolume(raw) {
  var out = _emptyRoomVolume()
  try {
    var list = JSON.parse(String(raw || ""))
    if (!Array.isArray(list))
      return out
    for (var i = 0; i < list.length; i++) {
      var row = list[i]
      if (!row)
        continue
      var key = String(row.varName || row.name || "")
      if (key === "CURRENT_VOLUME") {
        var n = Number(row.value)
        if (isFinite(n))
          out.volume = Math.max(0, Math.min(100, Math.round(n)))
      }
      if (key === "IS_MUTED") {
        var v = row.value
        out.muted = v === true || v === "true" || v === "1" || v === 1
      }
      if (key === "POWER_STATE") {
        var p = row.value
        out.power = !(p === 0 || p === "0" || p === false || p === "false")
      }
      if (key === "CURRENT_VIDEO_DEVICE")
        out.videoDeviceId = _finiteId(row.value)
      if (key === "PLAYING_AUDIO_DEVICE")
        out.playingAudioDeviceId = _finiteId(row.value)
      if (key === "LAST_DEVICE_GROUP") {
        var g = String(row.value == null ? "" : row.value).trim().toLowerCase()
        if (g === "watch" || g === "listen")
          out.lastDeviceGroup = g
      }
    }
  } catch (e) {
    return _emptyRoomVolume()
  }
  return out
}

function _nameFromSources(sources, id) {
  var n = Number(id)
  if (!isFinite(n) || !sources)
    return ""
  for (var i = 0; i < sources.length; i++) {
    if (!sources[i] || Number(sources[i].id) !== n)
      continue
    var name = sources[i].name != null ? String(sources[i].name).trim() : ""
    if (name)
      return name
  }
  return ""
}

function _nameFromItems(items, id) {
  var item = findItemById(items, id)
  if (!item || item.name == null)
    return ""
  return String(item.name).trim()
}

function nowPlayingLabel(parsed, items, watchSources, listenSources) {
  if (!parsed || parsed.power === false)
    return ""
  if (parsed.lastDeviceGroup === "listen") {
    var audioId = parsed.playingAudioDeviceId
    return _nameFromSources(listenSources, audioId) || _nameFromItems(items, audioId)
  }
  var watchId = matchWatchSourceId(watchSources, items, parsed.videoDeviceId)
  if (watchId != null)
    return _nameFromSources(watchSources, watchId) || _nameFromItems(items, watchId)
  if (parsed.videoDeviceId != null)
    return _nameFromItems(items, parsed.videoDeviceId)
  return ""
}

function curlNavArgs(opts) {
  var maxTime = opts && opts.maxTime != null ? String(opts.maxTime) : "35"
  var args = ["curl", "-sS", "--max-time", maxTime]
  if (opts && opts.insecure)
    args.push("-k")
  if (opts && opts.cookiePath) {
    args.push("-b", String(opts.cookiePath))
    args.push("-c", String(opts.cookiePath))
  }
  if (opts && opts.jwt)
    args.push("-H", "JWT: " + String(opts.jwt))
  if (opts && opts.bodyPath) {
    args.push("-H", "Content-Type: " + String(opts.contentType || "text/plain"))
    args.push("--data-binary", "@" + opts.bodyPath)
  }
  args.push(String(opts && opts.url || ""))
  return args
}

function parseEngineIoSid(raw) {
  var m = String(raw || "").match(/"sid":"([^"]+)"/)
  return m ? m[1] : ""
}

function parseSocketIoClientId(raw) {
  var m = String(raw || "").match(/"clientId","([^"]+)"/)
  return m ? m[1] : ""
}

function extractJsonObject(s, from) {
  var text = String(s || "")
  var i = text.indexOf("{", from == null ? 0 : from)
  if (i < 0)
    return null
  var depth = 0
  var inStr = false
  var esc = false
  for (var j = i; j < text.length; j++) {
    var ch = text.charAt(j)
    if (inStr) {
      if (esc)
        esc = false
      else if (ch === "\\")
        esc = true
      else if (ch === "\"")
        inStr = false
      continue
    }
    if (ch === "\"") {
      inStr = true
      continue
    }
    if (ch === "{")
      depth++
    else if (ch === "}") {
      depth--
      if (depth === 0) {
        try {
          return JSON.parse(text.substring(i, j + 1))
        } catch (e) {
          return null
        }
      }
    }
  }
  return null
}

function parseMspResponse(raw) {
  var all = parseMspResponses(raw)
  return all.length ? all[all.length - 1] : null
}

function parseMspResponses(raw) {
  var s = String(raw || "")
  var out = []
  var from = 0
  while (from < s.length) {
    var idx = s.indexOf("\"RESPONSE\"", from)
    if (idx < 0)
      break
    var obj = extractJsonObject(s, idx)
    if (obj && obj.SEQ != null)
      out.push(obj)
    from = idx + 10
  }
  return out
}

function mspArgXml(map) {
  var keys = []
  if (map && typeof map === "object") {
    for (var k in map) {
      if (Object.prototype.hasOwnProperty.call(map, k) && map[k] != null && map[k] !== "")
        keys.push(k)
    }
  }
  var parts = ["<arguments>"]
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    var val = String(map[key])
    val = val.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    parts.push("<arg name=\"" + key + "\">" + val + "</arg>")
  }
  parts.push("</arguments>")
  return parts.join("")
}

function _asArray(v) {
  if (v == null)
    return []
  if (Array.isArray(v))
    return v
  return [v]
}

function _truthyFlag(v) {
  return v === true || v === "true" || v === "1" || v === 1
}

function _commandName(entry) {
  if (typeof entry === "string") {
    var s = entry.trim()
    return s ? s.toUpperCase() : ""
  }
  if (!entry || typeof entry !== "object")
    return ""
  var keys = ["name", "command", "id", "#text", "_"]
  for (var i = 0; i < keys.length; i++) {
    if (entry[keys[i]] == null)
      continue
    var t = String(entry[keys[i]]).trim()
    if (t)
      return t.toUpperCase()
  }
  return ""
}

function _commandList(item) {
  if (!item || typeof item !== "object")
    return []
  var commands = item.commands
  if (commands == null)
    return []
  if (typeof commands === "string")
    return _asArray(commands)
  if (Array.isArray(commands))
    return commands
  if (typeof commands === "object")
    return _asArray(commands.command)
  return []
}

function itemArray(items) {
  if (Array.isArray(items))
    return items
  if (items && Array.isArray(items.items))
    return items.items
  return []
}

function findItemById(items, id) {
  var n = Number(id)
  if (!isFinite(n))
    return null
  var list = itemArray(items)
  for (var i = 0; i < list.length; i++) {
    if (list[i] && Number(list[i].id) === n)
      return list[i]
  }
  return null
}

function hasWatchRemoteUi(caps) {
  if (!caps)
    return false
  if (caps.hasNavigation || caps.hasTransport)
    return true
  if (caps.hasChannelUpDown || caps.hasDiscreteChannelSelect)
    return true
  return !!(caps.surroundModes && caps.surroundModes.length)
}

function itemForWatchRemote(items, sourceId) {
  var item = findItemById(items, sourceId)
  if (item && hasWatchRemoteUi(parseRemoteCapabilities(item)))
    return item
  var n = Number(sourceId)
  var list = itemArray(items)
  if (isFinite(n)) {
    for (var i = 0; i < list.length; i++) {
      var child = list[i]
      if (!child || Number(child.parentId || child.parentid) !== n)
        continue
      if (hasWatchRemoteUi(parseRemoteCapabilities(child)))
        return child
    }
  }
  if (item && (item.parentId != null || item.parentid != null)) {
    var parent = findItemById(items, item.parentId != null ? item.parentId : item.parentid)
    if (parent && hasWatchRemoteUi(parseRemoteCapabilities(parent)))
      return parent
  }
  return item
}

function matchWatchSourceId(sources, items, deviceId) {
  var n = Number(deviceId)
  if (!isFinite(n))
    return null
  var list = sources || []
  var i
  for (i = 0; i < list.length; i++) {
    if (list[i] && Number(list[i].id) === n)
      return n
  }
  var resolved = itemForWatchRemote(items, n)
  if (resolved && resolved.id != null) {
    var rid = Number(resolved.id)
    for (i = 0; i < list.length; i++) {
      if (list[i] && Number(list[i].id) === rid)
        return rid
    }
  }
  for (i = 0; i < list.length; i++) {
    if (!list[i] || list[i].id == null)
      continue
    var walked = itemForWatchRemote(items, list[i].id)
    if (walked && Number(walked.id) === n)
      return Number(list[i].id)
  }
  return null
}

function _emptyRemoteCapabilities() {
  return {
    commands: [],
    hasNavigation: false,
    nav: { menu: false, up: false, down: false, left: false, right: false, enter: false },
    hasTransport: false,
    transport: {
      play: false, stop: false, pause: false,
      skipFwd: false, skipRev: false, scanFwd: false, scanRev: false
    },
    hasDigits: false,
    hasChannelUpDown: false,
    hasDiscreteChannelSelect: false,
    power: { on: false, off: false },
    showTransport: null,
    displayIcon: "",
    displayIcons: [],
    hasDiscreteSurroundModeSelect: false,
    surroundModes: []
  }
}

var _NAV_KEYS = { MENU: "menu", UP: "up", DOWN: "down", LEFT: "left", RIGHT: "right", ENTER: "enter" }
var _TRANSPORT_KEYS = {
  PLAY: "play", STOP: "stop", PAUSE: "pause",
  SKIP_FWD: "skipFwd", SKIP_REV: "skipRev", SCAN_FWD: "scanFwd", SCAN_REV: "scanRev"
}

function parseRemoteCapabilities(item) {
  var caps = _emptyRemoteCapabilities()
  if (!item || typeof item !== "object")
    return caps
  var list = _commandList(item)
  var seen = {}
  for (var i = 0; i < list.length; i++) {
    var name = _commandName(list[i])
    if (!name || seen[name])
      continue
    seen[name] = true
    caps.commands.push(name)
    if (_NAV_KEYS[name]) {
      caps.nav[_NAV_KEYS[name]] = true
      caps.hasNavigation = true
    }
    if (_TRANSPORT_KEYS[name]) {
      caps.transport[_TRANSPORT_KEYS[name]] = true
      caps.hasTransport = true
    }
    if (name.indexOf("NUMBER_") === 0 && name.length === 8) {
      var digit = name.charAt(7)
      if (digit >= "0" && digit <= "9")
        caps.hasDigits = true
    }
    if (name === "ON")
      caps.power.on = true
    if (name === "OFF")
      caps.power.off = true
  }
  var capab = item.capabilities
  if (capab && typeof capab === "object") {
    caps.hasChannelUpDown = _truthyFlag(capab.has_channel_up_down)
    caps.hasDiscreteChannelSelect = _truthyFlag(capab.has_discrete_channel_select)
    var opt = capab.navigator_display_option
    if (opt && typeof opt === "object") {
      if (opt.show_transport !== undefined) {
        if (_truthyFlag(opt.show_transport))
          caps.showTransport = true
        else if (opt.show_transport === false || opt.show_transport === "false"
            || opt.show_transport === 0 || opt.show_transport === "0")
          caps.showTransport = false
      }
      if (opt.display_icon != null) {
        var icon = String(opt.display_icon).trim()
        if (icon)
          caps.displayIcon = icon
      }
      var icons = _asArray(opt.display_icons)
      for (var j = 0; j < icons.length; j++) {
        var ic = icons[j]
        if (typeof ic === "string" && ic.trim()) {
          caps.displayIcons.push(ic.trim())
          continue
        }
        if (ic && typeof ic === "object" && ic.url != null) {
          var url = String(ic.url).trim()
          if (url)
            caps.displayIcons.push(url)
        }
      }
    }
    caps.hasDiscreteSurroundModeSelect = _truthyFlag(capab.has_discrete_surround_mode_select)
    var modes = []
    if (capab.surround_modes && typeof capab.surround_modes === "object")
      modes = _asArray(capab.surround_modes.surround_mode)
    for (var m = 0; m < modes.length; m++) {
      var mode = modes[m]
      if (!mode || typeof mode !== "object")
        continue
      var modeId = Number(mode.id)
      var modeName = mode.name != null ? String(mode.name).trim() : ""
      if (!isFinite(modeId) || !modeName)
        continue
      caps.surroundModes.push({ id: modeId, name: modeName })
    }
  }
  return caps
}

// Receiver proxy audio output 1 is binding 4000 in the Control4 receiver
// protocol (confirmed live on this Director as bindingName "Output").
function surroundModeParams(modeId) {
  var n = Number(modeId)
  if (!isFinite(n))
    return null
  return { SURROUNDMODE: n, OUTPUT: 4000 }
}

function hasRemoteCommand(caps, name) {
  if (!caps || !Array.isArray(caps.commands) || name == null)
    return false
  var want = String(name).trim().toUpperCase()
  if (!want)
    return false
  for (var k = 0; k < caps.commands.length; k++) {
    if (caps.commands[k] === want)
      return true
  }
  return false
}

function parseMspTabs(data) {
  var tabs = data && data.Tabs && data.Tabs.Tab
  var list = _asArray(tabs)
  var out = []
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (!t || !t.Id || !t.ScreenId)
      continue
    out.push({
      title: String(t.Name || t.Id),
      id: String(t.Id),
      itemType: "tab",
      defaultAction: "BrowseTab",
      isLink: true,
      screenId: String(t.ScreenId),
      tabId: String(t.Id)
    })
  }
  return out
}

function parseMspList(data, screenId, tabId) {
  var list = data && data.List && data.List.item
  var rows = _asArray(list)
  var out = []
  var sid = screenId ? String(screenId) : "ListScreen"
  var tid = tabId ? String(tabId) : ""
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (!r)
      continue
    var title = String(r.title || r.Name || "")
    if (!title)
      continue
    out.push({
      title: title,
      id: r.id != null ? String(r.id) : "",
      itemType: r.itemType != null ? String(r.itemType) : "",
      defaultAction: String(r.default_action || r.defaultAction || "SelectItem"),
      isLink: r.isLink === true || r.isLink === "true",
      href: r.href != null ? String(r.href) : "",
      actionsList: String(r.actions_list || r.actionsList || ""),
      screenId: sid,
      tabId: tid
    })
  }
  return out
}

function parseMspNextScreen(data) {
  if (!data || data.NextScreen == null)
    return ""
  return String(data.NextScreen)
}

function mspPlayCommand(row) {
  if (!row)
    return null
  var action = String(row.defaultAction || row.default_action || "")
  var kind = String(row.itemType || "")
  var actions = String(row.actionsList || row.actions_list || "")
  if (row.isLink === true || kind === "link" || kind === "tab" || action === "BrowseTab")
    return null
  if (action === "PlayStation" || kind === "stations")
    return "PlayStation"
  if (action === "Play" || action === "PlayNow")
    return "Play"
  if (actions.indexOf("PlayNow") !== -1)
    return "Play"
  if (kind.indexOf("playlist") !== -1 || kind.indexOf("song") !== -1 || kind.indexOf("album") !== -1)
    return "Play"
  return null
}

function isAppleMusicItem(item) {
  if (!item)
    return false
  var fn = String(item.protocolFilename || item.filename || "")
  if (fn.indexOf("apple-music") !== -1)
    return true
  if (String(item.name || "") === "Apple Music" && String(item.proxy || "") === "media_service")
    return true
  return false
}

function isTuneInItem(item) {
  if (!item)
    return false
  var fn = String(item.protocolFilename || item.filename || "")
  if (fn.toLowerCase().indexOf("tunein") !== -1)
    return true
  if (String(item.name || "") === "TuneIn" && String(item.proxy || "") === "media_service")
    return true
  return false
}

function driverXmlPath(item) {
  var fn = String(item && (item.protocolFilename || item.filename) || "")
  fn = fn.replace(/\.c4[zi]$/i, "")
  if (!fn)
    return ""
  return "/c4z/" + fn + "/driver.xml"
}

// TuneIn is a legacy OS2 media service: its tabs are static in driver.xml
// rather than answered by a GetTabList protocol command.
function parseTuneInTabs(xml) {
  var block = String(xml || "").match(/<Tabs>([\s\S]*?)<\/Tabs>/)
  if (!block)
    return []
  var out = []
  var re = /<Tab>([\s\S]*?)<\/Tab>/g
  var m
  while ((m = re.exec(block[1])) !== null) {
    var name = m[1].match(/<Name>([\s\S]*?)<\/Name>/)
    var screen = m[1].match(/<ScreenId>([\s\S]*?)<\/ScreenId>/)
    if (!name || !screen)
      continue
    out.push({
      svc: "tunein",
      title: name[1],
      screen: screen[1],
      isTab: true,
      folder: true
    })
  }
  return out
}

function parseTuneInList(data, screen) {
  var rows = _asArray(data && data.List && data.List.item)
  var sid = screen ? String(screen) : "Browse"
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (!r)
      continue
    var title = String(r.text || r.title || "")
    if (!title)
      continue
    out.push({
      svc: "tunein",
      title: title,
      subtitle: r.subtext != null ? String(r.subtext) : "",
      screen: sid,
      folder: r.folder === true || r.folder === "true",
      isHeader: r.is_header === true || r.is_header === "true",
      url: r.URL != null ? String(r.URL) : "",
      type: r.type != null ? String(r.type) : "",
      key: r.key != null ? String(r.key) : "",
      itemProp: r.item != null ? String(r.item) : "",
      guideId: r.guide_id != null ? String(r.guide_id) : "",
      isPreset: r.is_preset != null ? String(r.is_preset) : "",
      image: r.image != null ? String(r.image) : ""
    })
  }
  return out
}

// Mirrors the driver's Browse action params: screen, type, URL, guide_id,
// item, is_preset, key, text, image.
function tuneInTapArgs(row) {
  if (!row)
    return {}
  var args = { screen: row.screen || "Browse" }
  if (row.type)
    args.type = row.type
  if (row.url)
    args.URL = row.url
  if (row.guideId)
    args.guide_id = row.guideId
  if (row.itemProp)
    args.item = row.itemProp
  if (row.isPreset)
    args.is_preset = row.isPreset
  if (row.key)
    args.key = row.key
  if (row.title)
    args.text = row.title
  if (row.image)
    args.image = row.image
  return args
}
