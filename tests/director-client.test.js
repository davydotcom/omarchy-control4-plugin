#!/usr/bin/env node
"use strict"

const fs = require("fs")
const path = require("path")
const { spawnSync } = require("child_process")
const vm = require("vm")
const src = fs.readFileSync(path.join(__dirname, "..", "DirectorClient.js"), "utf8")
  .replace(/^\.pragma library\s*/, "")
const ctx = vm.createContext({})
vm.runInContext(src, ctx)
const {
  parseHttp, parseHttpStatus, parseAccountToken, parseControllerCommonName, parseDirectorToken,
  classifyProbe, classifyCloudStatus, commandBody,
  curlConfigEscape, curlConfigText, curlNavConfigText, parseStderrMarkers, CURL_WRAPPER_COMMAND,
  MAX_RESPONSE_BYTES, MAX_CREDENTIALS_FILE_BYTES, MAX_FOCUS_FILE_BYTES,
  stateFileReadCommand, stateFileWriteCommand, STATE_FILE_PYTHON,
  isOversizedResponse,
  networkErrorMessage, isTransientCurl,
  normalizeHost, credentialsComplete, statusTextFor, accountAuthBody,
  APPLICATION_KEY, STATUS_NOT_CONFIGURED, STATUS_NOT_CONNECTED,
  STATUS_SIGN_IN_FAILED, STATUS_DIRECTOR_401, STATUS_CONNECTED,
  extractRooms, isRoomHidden, parseFocusFile, sortRoomsByNameThenId,
  extractSources, sourceArray, parseRoomVolume, nowPlayingLabel, parseRemoteCapabilities, hasRemoteCommand,
  itemForWatchRemote, findItemById, hasWatchRemoteUi, surroundModeParams, matchWatchSourceId,
  parseEngineIoSid, parseSocketIoClientId, parseMspResponse, parseMspResponses, mspArgXml,
  parseMspTabs, parseMspList, parseMspNextScreen, isAppleMusicItem, mspPlayCommand,
  isTuneInItem, driverXmlPath, parseTuneInTabs, parseTuneInList, tuneInTapArgs
} = ctx

function assert(cond, msg) {
  if (!cond) {
    console.error("FAIL:", msg)
    process.exit(1)
  }
}

const http = parseHttp("{\"ok\":true}\n200")
assert(http.status === 200, "parseHttp status")
assert(http.body === "{\"ok\":true}", "parseHttp body")
assert(parseHttpStatus("200") === 200, "parseHttpStatus")
assert(parseHttpStatus(" 404\n") === 404, "parseHttpStatus trim")
assert(parseHttpStatus("") === 0, "parseHttpStatus empty")

const token = parseAccountToken(JSON.stringify({ authToken: { token: "abc" } }))
assert(token.ok && token.token === "abc", "parseAccountToken")

const missing = parseAccountToken("{}")
assert(!missing.ok, "parseAccountToken missing")

const objName = parseControllerCommonName(JSON.stringify({
  account: { controllerCommonName: "control4_ca10_aabbccddeeff" }
}))
assert(objName.ok && objName.commonName === "control4_ca10_aabbccddeeff", "commonName object")

const arrName = parseControllerCommonName(JSON.stringify({
  account: [{ controllerCommonName: "first" }, { controllerCommonName: "second" }]
}))
assert(arrName.ok && arrName.commonName === "first", "commonName array")

const director = parseDirectorToken(JSON.stringify({
  authToken: { token: "jwt", validSeconds: 86400 }
}))
assert(director.ok && director.token === "jwt" && director.validSeconds === 86400, "director token")

const directorDefault = parseDirectorToken(JSON.stringify({
  authToken: { token: "jwt" }
}))
assert(directorDefault.validSeconds === 86400, "director validSeconds default")

assert(classifyProbe(200).kind === "connected", "probe 200")
assert(classifyProbe(401).kind === "director401", "probe 401")
assert(classifyProbe(500).kind === "error", "probe 500")
assert(classifyCloudStatus(401).kind === "sign-in", "cloud 401")

const post = JSON.parse(commandBody("SELECT_AUDIO_DEVICE", { deviceid: 9 }))
assert(post.async === true && post.command === "SELECT_AUDIO_DEVICE" && post.tParams.deviceid === 9, "commandBody")

// ---------------------------------------------------------------------------
// curl transport: the wrapper command is constant, every per-request value
// travels in the stdin config.
// ---------------------------------------------------------------------------

// Applies curl's config-file un-escape rules to a quoted value, so escaping can
// be asserted as a byte-exact round-trip rather than against a golden string.
function curlUnescape(s) {
  let out = ""
  for (let i = 0; i < s.length; i++) {
    if (s[i] !== "\\") { out += s[i]; continue }
    const n = s[++i]
    if (n === "\\") out += "\\"
    else if (n === "\"") out += "\""
    else if (n === "t") out += "\t"
    else if (n === "n") out += "\n"
    else if (n === "r") out += "\r"
    else if (n === "v") out += "\v"
    else out += n
  }
  return out
}

function configValue(text, key) {
  const m = text.match(new RegExp("^" + key + " = \"((?:[^\"\\\\]|\\\\.)*)\"$", "m"))
  return m ? m[1] : null
}

function configValues(text, key) {
  const re = new RegExp("^" + key + " = \"((?:[^\"\\\\]|\\\\.)*)\"$", "mg")
  const out = []
  let m
  while ((m = re.exec(text)) !== null) out.push(m[1])
  return out
}

// -- curlConfigEscape (AC-4) ------------------------------------------------
assert(curlConfigEscape("") === "", "escape empty string")
assert(curlConfigEscape(null) === "", "escape null")
assert(curlConfigEscape("plain text 123") === "plain text 123", "escape leaves plain text alone")
assert(curlConfigEscape("\\") === "\\\\", "escape a lone backslash")
assert(curlConfigEscape("\"") === "\\\"", "escape a lone quote")
// The JSON case: \" must become \\\" (backslash-first), never \\" (quote-first).
assert(curlConfigEscape("\\\"") === "\\\\\\\"", "escape backslash before quote")
assert(curlConfigEscape("\\\"") !== "\\\\\"", "quote-first ordering would corrupt \\\"")
;[
  "",
  "no specials",
  "\\",
  "\"",
  "\\\"",
  "a\"b\\c\"\\d",
  "{\"k\":\"v\\\\n\"}",
  accountAuthBody("u\"ser@x.com", "p\"a\\ss\nw\tor$d`x")
].forEach((raw, i) => {
  assert(curlUnescape(curlConfigEscape(raw)) === raw, "escape round-trips byte-for-byte [" + i + "]")
})

// -- curlConfigText (AC-1, AC-2, AC-5, AC-9) --------------------------------
const cfg = curlConfigText({
  url: "https://example/api", insecure: true,
  body: commandBody("SELECT_AUDIO_DEVICE", { deviceid: 9 }), token: "TOKEN"
})
assert(configValues(cfg, "header").filter(h => h === "Authorization: Bearer TOKEN").length === 1,
  "bearer token appears exactly once as a header line")
assert(/^insecure$/m.test(cfg), "insecure present when requested")
assert(!/^insecure$/m.test(curlConfigText({ url: "https://apis.control4.com/x" })),
  "insecure absent for the cloud host")
assert(/^silent$/m.test(cfg) && /^show-error$/m.test(cfg), "silent and show-error (the -sS equivalent)")
assert(configValue(cfg, "max-time") === "20", "director max-time is 20")
assert(configValue(cfg, "max-filesize") === String(MAX_RESPONSE_BYTES), "max-filesize is MAX_RESPONSE_BYTES")
assert(configValue(cfg, "write-out").indexOf("%{stderr}") !== -1
  && configValue(cfg, "write-out").indexOf("HTTP:") !== -1, "write-out puts the HTTP marker on stderr")
assert(!/^request = /m.test(cfg), "no explicit request method — POST stays implied by data-binary")
assert(configValues(cfg, "header").indexOf("Content-Type: application/json") !== -1, "json content type with a body")
assert(curlUnescape(configValue(cfg, "data-binary")) === commandBody("SELECT_AUDIO_DEVICE", { deviceid: 9 }),
  "body round-trips through the config")
assert(configValue(cfg, "url") === "https://example/api", "url in the config")

const cfgGet = curlConfigText({ url: "https://example/get", token: "TOKEN" })
assert(configValue(cfgGet, "data-binary") === null, "no data-binary without a body")
assert(configValues(cfgGet, "header").indexOf("Content-Type: application/json") === -1,
  "no content type without a body")

const cfgBare = curlConfigText({ url: "https://example/bare" })
assert(configValues(cfgBare, "header").length === 0, "no headers without a token or body")

// AC-5: data-binary must never be allowed to read a file.
let atRejected = false
try { curlConfigText({ url: "https://x", body: "@/etc/passwd" }) } catch (e) { atRejected = true }
assert(atRejected, "a body beginning with @ is rejected, not treated as a filename")
let atRejectedNav = false
try { curlNavConfigText({ url: "https://x", body: "@/etc/passwd" }) } catch (e) { atRejectedNav = true }
assert(atRejectedNav, "nav body beginning with @ is rejected too")

// A password carrying a quote must survive into the config as valid JSON.
const authCfg = curlConfigText({
  url: "https://apis.control4.com/auth", body: accountAuthBody("u@x.com", "pa\"ss\\word")
})
assert(JSON.parse(curlUnescape(configValue(authCfg, "data-binary"))).clientInfo.userInfo.password === "pa\"ss\\word",
  "a quoted password round-trips as valid JSON")

// -- curlNavConfigText (AC-9) -----------------------------------------------
const navCfg = curlNavConfigText({
  url: "https://x/socket.io", insecure: true, maxTime: 12,
  cookiePath: "/state/nav-cookies.txt", token: "SECRET", body: "40"
})
const navHeaders = configValues(navCfg, "header")
assert(navHeaders.indexOf("Authorization: Bearer SECRET") !== -1, "nav bearer header")
assert(navHeaders.indexOf("JWT: SECRET") !== -1, "nav JWT header")
assert(configValue(navCfg, "max-time") === "12", "nav max-time honours opts.maxTime")
assert(configValue(curlNavConfigText({ url: "https://x" }), "max-time") === "35", "nav max-time defaults to 35")
assert(configValue(navCfg, "cookie") === "/state/nav-cookies.txt", "nav cookie jar read")
assert(configValue(navCfg, "cookie-jar") === "/state/nav-cookies.txt", "nav cookie jar write")
assert(configValue(curlNavConfigText({ url: "https://x" }), "cookie") === null, "no cookie lines without a path")
assert(navHeaders.indexOf("Content-Type: text/plain") !== -1, "nav content type defaults to text/plain")
assert(configValues(curlNavConfigText({ url: "https://x", body: "40", contentType: "application/xml" }), "header")
  .indexOf("Content-Type: application/xml") !== -1, "nav content type is overridable")
assert(configValue(navCfg, "write-out") === null, "nav config carries no write-out")
assert(configValue(navCfg, "max-filesize") === String(MAX_RESPONSE_BYTES), "nav max-filesize")
assert(/^insecure$/m.test(navCfg), "nav insecure for the LAN Director")

// -- secret containment (AC-1, AC-2) ----------------------------------------
const wrapper = CURL_WRAPPER_COMMAND.join(" ")
assert(wrapper.indexOf("SECRET") === -1 && wrapper.indexOf("TOKEN") === -1,
  "no token sentinel in the wrapper command")
assert(wrapper.indexOf("Bearer") === -1 && wrapper.indexOf("JWT") === -1,
  "no auth header in the wrapper command")
assert(wrapper.indexOf("password") === -1 && wrapper.indexOf("https") === -1,
  "no password or URL in the wrapper command")
// The wrapper is a compile-time constant: identical for every request.
assert(JSON.stringify(CURL_WRAPPER_COMMAND) === JSON.stringify([
  "sh", "-c", "umask 077; { curl -sS -K -; echo \"RC:$?\" >&2; } | head -c " + (MAX_RESPONSE_BYTES + 1)
]), "wrapper command is the constant, capped at MAX_RESPONSE_BYTES + 1")
// ...and the sentinels live only in the config text.
assert(cfg.indexOf("TOKEN") !== -1, "token reaches the config text")
assert(navCfg.indexOf("SECRET") !== -1, "jwt reaches the config text")

// -- parseStderrMarkers (AC-7, AC-8) ----------------------------------------
const mOk = parseStderrMarkers("HTTP:200\nRC:0\n")
assert(mOk.status === 200 && mOk.exitCode === 0, "clean markers")
const mErr = parseStderrMarkers("curl: (28) Operation timed out after 20003 milliseconds\nHTTP:000\nRC:28\n")
assert(mErr.status === 0 && mErr.exitCode === 28, "markers survive leading curl error text")
const mResolve = parseStderrMarkers("curl: (6) Could not resolve host: nope.invalid\nHTTP:000\nRC:6\n")
assert(mResolve.status === 0 && mResolve.exitCode === 6, "resolve failure exit code")
assert(parseStderrMarkers("RC:7\n").status === 0, "missing HTTP marker yields status 0")
assert(parseStderrMarkers("HTTP:404\n").exitCode === 0, "missing RC marker yields exit code 0")
assert(parseStderrMarkers("").status === 0 && parseStderrMarkers("").exitCode === 0, "empty stderr")
assert(parseStderrMarkers(null).exitCode === 0, "null stderr")
const mDup = parseStderrMarkers("HTTP:301\nRC:0\nHTTP:200\nRC:52\n")
assert(mDup.status === 200 && mDup.exitCode === 52, "duplicated markers take the last")
// Risk 4: the retry path must still see curl's own exit codes.
assert(isTransientCurl(parseStderrMarkers("HTTP:000\nRC:56\n").exitCode), "transient curl code survives the marker round trip")

assert(isOversizedResponse("x".repeat(MAX_RESPONSE_BYTES + 1)), "oversized response")
assert(!isOversizedResponse("ok"), "small response not oversized")
assert(networkErrorMessage(63) === "Response too large", "max-filesize message")
assert(!isTransientCurl(63), "oversized not transient")

assert(normalizeHost("https://192.168.1.10/api") === "192.168.1.10", "normalizeHost")
assert(credentialsComplete("192.168.1.10", "a@b.c", "x"), "credentialsComplete")
assert(!credentialsComplete("", "a@b.c", "x"), "credentials incomplete")

assert(statusTextFor("unconfigured", "", "", false, false) === STATUS_NOT_CONFIGURED, "not configured")
assert(statusTextFor("unconfigured", "", "", true, false) === STATUS_NOT_CONNECTED, "not connected")
assert(statusTextFor("auth-failed", "cloud", "", true, false) === STATUS_SIGN_IN_FAILED, "sign-in failed")
assert(statusTextFor("auth-failed", "director401", "", true, false) === STATUS_DIRECTOR_401, "director 401 copy")
assert(statusTextFor("connected", "", "", true, true) === STATUS_CONNECTED, "connected")
assert(statusTextFor("error", "", "Network error", true, false) === "Network error", "error lastError")
assert(networkErrorMessage(28) === "Request timed out", "timeout message")
assert(networkErrorMessage(7) === "Could not connect", "connect message")
assert(networkErrorMessage(26) === "Could not read request body", "missing body message")
assert(networkErrorMessage(15) === "Request interrupted", "sigterm message")
assert(networkErrorMessage(56) === "Network error (56)", "other curl exit")
assert(isTransientCurl(26) && isTransientCurl(28) && !isTransientCurl(1), "transient curl")

const authBody = JSON.parse(accountAuthBody("user@example.com", "s3cret"))
assert(authBody.clientInfo.userInfo.userName === "user@example.com", "account body email")
assert(authBody.clientInfo.userInfo.applicationKey === APPLICATION_KEY, "application key")

assert(isRoomHidden(true) === true, "hidden boolean true")
assert(isRoomHidden("1") === true, "hidden string 1")
assert(isRoomHidden(1) === true, "hidden number 1")
assert(isRoomHidden(undefined) === false, "missing roomHidden visible")
assert(isRoomHidden(false) === false, "hidden false visible")
assert(isRoomHidden(0) === false, "hidden 0 visible")
assert(isRoomHidden("0") === false, "hidden string 0 visible")

function roomItem(id, name, hidden) {
  const item = { id, typeName: "room", name }
  if (hidden !== undefined)
    item.roomHidden = hidden
  return item
}

const hiddenItems = [
  roomItem(1, "HiddenBool", true),
  roomItem(2, "HiddenStr", "1"),
  roomItem(3, "HiddenNum", 1),
  roomItem(4, "Kitchen")
]
const hiddenUi = {
  experiences: [
    { type: "watch", room_id: 1 },
    { type: "listen", room_id: 2 },
    { type: "watch", room_id: 3 },
    { type: "listen", room_id: 4 }
  ]
}
const visible = extractRooms(hiddenUi, hiddenItems)
assert(visible.length === 1 && visible[0].id === 4 && visible[0].name === "Kitchen", "hidden rooms skipped")

const camerasUi = {
  experiences: [
    { type: "cameras", room_id: 10 },
    { type: "comfort", room_id: 11 },
    { type: "lights", room_id: 12 }
  ]
}
const camerasItems = [
  roomItem(10, "Cameras"),
  roomItem(11, "Thermostat"),
  roomItem(12, "Hall")
]
assert(extractRooms(camerasUi, camerasItems).length === 0, "cameras-only and other types skipped")

const joinUi = {
  experiences: [
    { type: "watch", room_id: 9 },
    { type: "listen", room_id: 9 },
    { type: "watch", room_id: 99 },
    { type: "listen", room_id: "8" }
  ]
}
const joinItems = [
  roomItem("9", "Theater"),
  roomItem(8, "Kitchen"),
  { id: 7, typeName: "device", name: "Amp" }
]
const joined = extractRooms(joinUi, joinItems)
assert(joined.length === 2, "watch+listen same room is one row; unmatched omitted")
assert(joined[0].id === 8 && joined[0].name === "Kitchen", "name join from items")
assert(joined[1].id === 9 && joined[1].name === "Theater", "watch+listen deduped")
assert(joined.every(r => r.id !== 99 && r.name !== "Room 99"), "gone id 99 not synthesized")

const sortUi = {
  experiences: [
    { type: "watch", room_id: 1 },
    { type: "listen", room_id: 5 },
    { type: "watch", room_id: 3 }
  ]
}
const sortItems = [
  roomItem(1, "Living Room"),
  roomItem(5, "Kitchen"),
  roomItem(3, "Kitchen")
]
const sorted = extractRooms(sortUi, sortItems)
assert(sorted.map(r => r.id + ":" + r.name).join(",") === "3:Kitchen,5:Kitchen,1:Living Room", "sort by name then id")
assert(sortRoomsByNameThenId(sorted[0], sorted[1]) < 0, "name-then-id helper")

assert(extractRooms({}, [roomItem(1, "A")]).length === 0, "missing experiences")
assert(extractRooms({ experiences: null }, [roomItem(1, "A")]).length === 0, "non-array experiences")
assert(extractRooms({ experiences: { room_id: 1 } }, [roomItem(1, "A")]).length === 0, "object experiences")
assert(extractRooms({ experiences: [{ type: "watch", room_id: 1 }] }, { id: 1 }).length === 0, "non-array items")
assert(extractRooms({ experiences: [{ type: "watch", room_id: 1 }] }, null).length === 0, "null items")

const missingHidden = extractRooms(
  { experiences: [{ type: "watch", room_id: 4 }] },
  [roomItem(4, "Den")]
)
assert(missingHidden.length === 1 && missingHidden[0].name === "Den", "missing roomHidden is visible")

assert(extractRooms(
  { experiences: [{ type: "watch", room_id: 6 }] },
  [roomItem(6, "   ")]
).length === 0, "blank name skipped")

assert(parseFocusFile('{"roomId":9}') === 9, "parseFocusFile number")
assert(parseFocusFile('{"roomId": 9}') === 9, "parseFocusFile spaced number")
assert(parseFocusFile("{}") === null, "parseFocusFile empty object")
assert(parseFocusFile("{") === null, "parseFocusFile invalid json")
assert(parseFocusFile("") === null, "parseFocusFile empty")
assert(parseFocusFile('{"roomId":null}') === null, "parseFocusFile null roomId")
assert(parseFocusFile('{"roomId":"x"}') === null, "parseFocusFile non-finite")
assert(parseFocusFile("not json") === null, "parseFocusFile garbage")

const srcUi = {
  experiences: [
    {
      type: "watch",
      room_id: 9,
      sources: { source: [
        { id: 59, type: "HDMI" },
        { id: 33, type: "VIDEO_SELECTION", name: "Apple TV" },
        { id: 1, type: "HDMI", name: "   " }
      ] }
    },
    {
      type: "listen",
      room_id: 9,
      sources: { source: [
        { id: 298, type: "DIGITAL_AUDIO_SERVER", name: "My Music" },
        { id: 937, name: "Spotify Connect" }
      ] }
    },
    {
      type: "watch",
      room_id: 8,
      sources: { source: { id: 77, name: "Other Room TV" } }
    }
  ]
}
const srcItems = [
  { id: 59, name: "Cable Box" },
  { id: 1, name: "Blank HDMI" },
  { id: 298, name: "Should not win" }
]
const watch9 = extractSources(srcUi, srcItems, 9, "watch")
assert(watch9.map(s => s.id + ":" + s.name).join(",") === "33:Apple TV,1:Blank HDMI,59:Cable Box", "watch names join items; whitespace source name falls back")
const listen9 = extractSources(srcUi, srcItems, 9, "listen")
assert(listen9.map(s => s.id + ":" + s.name).join(",") === "298:My Music,937:Spotify Connect", "listen filter; source.name wins")
assert(extractSources(srcUi, srcItems, 8, "watch").length === 1
  && extractSources(srcUi, srcItems, 8, "watch")[0].name === "Other Room TV", "single-object source")
assert(extractSources(srcUi, srcItems, 9, "listen").every(s => s.id !== 59), "watch HDMI not in listen")
assert(extractSources(srcUi, srcItems, 99, "watch").length === 0, "other room skipped")
assert(extractSources({}, srcItems, 9, "watch").length === 0, "missing experiences sources")
assert(extractSources({ experiences: [{ type: "watch", room_id: 9 }] }, srcItems, 9, "watch").length === 0, "missing sources")
assert(sourceArray({ sources: { source: { id: 1 } } }).length === 1, "sourceArray wraps object")
assert(sourceArray({ sources: { source: [{ id: 1 }, { id: 2 }] } }).length === 2, "sourceArray array")
assert(extractSources(srcUi, srcItems, 9, "nope").map(s => s.id).join(",") === "33,1,59", "unknown mode is watch")

const vol = parseRoomVolume(JSON.stringify([
  { name: "CURRENT_VOLUME", value: "42" },
  { name: "IS_MUTED", value: "1" }
]))
assert(vol.volume === 42 && vol.muted === true, "parseRoomVolume muted")
const liveDeck = parseRoomVolume(JSON.stringify([
  { id: 15, varName: "CURRENT_VOLUME", type: "Number", value: 32, name: "Deck", roomName: "Deck" },
  { id: 15, varName: "IS_MUTED", type: "Boolean", value: 0, name: "Deck", roomName: "Deck" }
]))
assert(liveDeck.volume === 32 && liveDeck.muted === false, "parseRoomVolume Director varName not item name")
const vol2 = parseRoomVolume(JSON.stringify([{ name: "CURRENT_VOLUME", value: 7 }]))
assert(vol2.volume === 7 && vol2.muted === false, "parseRoomVolume unmuted missing IS_MUTED")
assert(parseRoomVolume("{}").volume === null, "parseRoomVolume non-array")
assert(parseRoomVolume("nope").volume === null, "parseRoomVolume invalid")
const clamped = parseRoomVolume(JSON.stringify([{ name: "CURRENT_VOLUME", value: 140 }]))
assert(clamped.volume === 100, "parseRoomVolume clamp")

const setVol = JSON.parse(commandBody("SET_VOLUME_LEVEL", { LEVEL: 42 }))
assert(setVol.command === "SET_VOLUME_LEVEL" && setVol.tParams.LEVEL === 42, "SET_VOLUME_LEVEL body")

const sid = parseEngineIoSid('0{"sid":"abc123","upgrades":[]}')
assert(sid === "abc123", "parseEngineIoSid")
assert(parseSocketIoClientId('4228["clientId","ws-1"]') === "ws-1", "parseSocketIoClientId")
const tabFrame = '42["9",[{"evtName":"OnDataToUI","iddevice":434,"data":{"RESPONSE":{"NAVID":"n","SEQ":71,"DATA":{"Tabs":{"Tab":[{"Name":"Stations","ScreenId":"ListScreen","Id":"Stations"},{"Name":"Settings","ScreenCommand":{"Name":"GetSettingsScreen"},"Id":"Settings"}]}}}}}]]'
const tabResp = parseMspResponse(tabFrame)
assert(tabResp && tabResp.SEQ === 71, "parseMspResponse SEQ")
const tabs = parseMspTabs(tabResp.DATA)
assert(tabs.length === 1 && tabs[0].title === "Stations" && tabs[0].defaultAction === "BrowseTab", "parseMspTabs skips Settings")
const listFrame = '{"evtName":"OnDataToUI","data":{"RESPONSE":{"SEQ":201,"DATA":{"List":{"item":[{"title":"My Personal Station","itemType":"link","isLink":true,"id":"/v1/personal","default_action":"SelectItem"}]}}}}}'
const listResp = parseMspResponse(listFrame)
const items = parseMspList(listResp.DATA, "ListScreen", "Stations")
assert(items.length === 1 && items[0].title === "My Personal Station" && items[0].id.indexOf("personal") !== -1, "parseMspList array")
const one = parseMspList({ List: { item: { title: "David Estes’ Station", id: "ra.u-1", default_action: "PlayStation", itemType: "stations" } } }, "ListScreen", "Stations")
assert(one.length === 1 && one[0].defaultAction === "PlayStation", "parseMspList single item")
assert(mspPlayCommand({ defaultAction: "SelectItem", itemType: "library-playlists", actionsList: "PlayNow PlayShuffle" }) === "Play", "playlist tap is Play NOW")
assert(mspPlayCommand({ defaultAction: "PlayStation", itemType: "stations" }) === "PlayStation", "station tap is PlayStation")
assert(mspPlayCommand({ defaultAction: "SelectItem", itemType: "link", isLink: true, actionsList: "" }) === null, "folder tap is not play")
assert(mspPlayCommand({ defaultAction: "BrowseTab", itemType: "tab" }) === null, "tab is not play")
assert(parseMspNextScreen({ NextScreen: "ListScreen" }) === "ListScreen", "parseMspNextScreen")
const multi = parseMspResponses('42["1",{"status":"started"}]\x1e42["1",[{"evtName":"OnDataToUI","data":{"RESPONSE":{"SEQ":5,"DATA":{"List":{"item":[]}}}}}]]')
assert(multi.length === 1 && Number(multi[0].SEQ) === 5, "parseMspResponses skips status")
assert(mspArgXml({ tabId: "Stations", id: "a&b" }) === "<arguments><arg name=\"tabId\">Stations</arg><arg name=\"id\">a&amp;b</arg></arguments>", "mspArgXml")
assert(isAppleMusicItem({ protocolFilename: "apple-music.c4z", name: "Apple Music" }), "isAppleMusicItem protocol")
assert(isAppleMusicItem({ name: "Apple Music", proxy: "media_service" }), "isAppleMusicItem proxy")
assert(!isAppleMusicItem({ name: "ShairBridge", proxy: "media_service" }), "isAppleMusicItem not shair")

// POWER_STATE drives the bar chip. null (not reported) must stay distinct from
// false (room off), or the chip cannot tell "off" from "not connected yet".
const powerOff = parseRoomVolume(JSON.stringify([
  { id: 14, varName: "POWER_STATE", value: 0 },
  { id: 14, varName: "CURRENT_VOLUME", value: 30 }
]))
assert(powerOff.power === false && powerOff.volume === 30, "parseRoomVolume POWER_STATE 0 is off")
const powerOn = parseRoomVolume(JSON.stringify([{ id: 14, varName: "POWER_STATE", value: 1 }]))
assert(powerOn.power === true, "parseRoomVolume POWER_STATE 1 is on")
assert(parseRoomVolume(JSON.stringify([{ varName: "POWER_STATE", value: "0" }])).power === false,
  "parseRoomVolume POWER_STATE string zero is off")
assert(parseRoomVolume(JSON.stringify([{ varName: "CURRENT_VOLUME", value: 30 }])).power === null,
  "parseRoomVolume absent POWER_STATE is null, not false")
assert(parseRoomVolume("not json").power === null, "parseRoomVolume bad body reports null power")
assert(parseRoomVolume("{}").videoDeviceId === null && parseRoomVolume("{}").lastDeviceGroup === "",
  "parseRoomVolume missing media ids")
const media = parseRoomVolume(JSON.stringify([
  { varName: "CURRENT_VOLUME", value: 32, name: "Deck" },
  { varName: "CURRENT_VIDEO_DEVICE", value: 431, name: "Deck" },
  { varName: "PLAYING_AUDIO_DEVICE", value: "10" },
  { varName: "CURRENT_AUDIO_DEVICE", value: 100002 },
  { varName: "LAST_DEVICE_GROUP", value: "Watch" }
]))
assert(media.volume === 32 && media.videoDeviceId === 431, "parseRoomVolume CURRENT_VIDEO_DEVICE")
assert(media.playingAudioDeviceId === 10, "parseRoomVolume PLAYING_AUDIO_DEVICE string id")
assert(media.lastDeviceGroup === "watch", "parseRoomVolume LAST_DEVICE_GROUP lowercased")
assert(media.playingAudioDeviceId !== 100002, "parseRoomVolume ignores CURRENT_AUDIO_DEVICE")
assert(parseRoomVolume(JSON.stringify([{ varName: "LAST_DEVICE_GROUP", value: "listen" }])).lastDeviceGroup === "listen",
  "parseRoomVolume listen group")
assert(parseRoomVolume(JSON.stringify([{ varName: "CURRENT_VIDEO_DEVICE", value: "nope" }])).videoDeviceId === null,
  "parseRoomVolume bad video id")

const nowItems = [
  { id: 431, name: "Base Fam Apple TV" },
  { id: 10, name: "TuneIn" },
  { id: 100002, name: "Digital Media" }
]
const nowWatch = [{ id: 431, name: "Base Fam Apple TV" }]
const nowListen = [{ id: 10, name: "TuneIn" }]
const nowOff = parseRoomVolume(JSON.stringify([
  { varName: "POWER_STATE", value: 0 },
  { varName: "CURRENT_VIDEO_DEVICE", value: 431 },
  { varName: "PLAYING_AUDIO_DEVICE", value: 10 },
  { varName: "CURRENT_AUDIO_DEVICE", value: 100002 },
  { varName: "LAST_DEVICE_GROUP", value: "Watch" }
]))
assert(nowPlayingLabel(nowOff, nowItems, nowWatch, nowListen) === "",
  "nowPlayingLabel off is empty even with device ids")
const nowWatchOn = parseRoomVolume(JSON.stringify([
  { varName: "POWER_STATE", value: 1 },
  { varName: "CURRENT_VIDEO_DEVICE", value: 431 },
  { varName: "LAST_DEVICE_GROUP", value: "Watch" }
]))
assert(nowPlayingLabel(nowWatchOn, nowItems, nowWatch, nowListen) === "Base Fam Apple TV",
  "nowPlayingLabel watch source name")
const nowListenOn = parseRoomVolume(JSON.stringify([
  { varName: "POWER_STATE", value: 1 },
  { varName: "PLAYING_AUDIO_DEVICE", value: 10 },
  { varName: "CURRENT_AUDIO_DEVICE", value: 100002 },
  { varName: "LAST_DEVICE_GROUP", value: "Listen" }
]))
assert(nowListenOn.lastDeviceGroup === "listen", "parseRoomVolume Listen capital L")
assert(nowPlayingLabel(nowListenOn, nowItems, nowWatch, nowListen) === "TuneIn",
  "nowPlayingLabel listen uses PLAYING_AUDIO_DEVICE not Digital Media")
assert(nowPlayingLabel(nowListenOn, nowItems, nowWatch, []) === "TuneIn",
  "nowPlayingLabel listen falls back to item name")
const nowUnknown = parseRoomVolume(JSON.stringify([
  { varName: "POWER_STATE", value: 1 },
  { varName: "CURRENT_VIDEO_DEVICE", value: 999 },
  { varName: "LAST_DEVICE_GROUP", value: "watch" }
]))
assert(nowPlayingLabel(nowUnknown, nowItems, nowWatch, nowListen) === "",
  "nowPlayingLabel unknown id is empty")

// TuneIn is a legacy OS2 media service: static driver.xml tabs, GetBrowseMenu lists.
assert(isTuneInItem({ protocolFilename: "TuneIn.c4z", name: "TuneIn" }), "isTuneInItem protocol")
assert(isTuneInItem({ name: "TuneIn", proxy: "media_service" }), "isTuneInItem proxy")
assert(!isTuneInItem({ protocolFilename: "apple-music.c4z", name: "Apple Music" }), "isTuneInItem not apple")
assert(!isAppleMusicItem({ protocolFilename: "TuneIn.c4z", name: "TuneIn" }), "isAppleMusicItem not tunein")
assert(driverXmlPath({ protocolFilename: "TuneIn.c4z" }) === "/c4z/TuneIn/driver.xml", "driverXmlPath strips c4z")
assert(driverXmlPath({}) === "", "driverXmlPath empty")

const tuneInXml = "<Tabs><Tab><Name>Browse</Name><ScreenId>Browse</ScreenId></Tab>"
  + "<Tab><Name>My Favorites</Name><ScreenId>MyFavorites</ScreenId></Tab></Tabs>"
const tuneInTabs = parseTuneInTabs(tuneInXml)
assert(tuneInTabs.length === 2 && tuneInTabs[0].title === "Browse" && tuneInTabs[0].screen === "Browse",
  "parseTuneInTabs reads static tabs")
assert(tuneInTabs[1].isTab === true && tuneInTabs[1].screen === "MyFavorites", "parseTuneInTabs second tab")
assert(parseTuneInTabs("<Tabs><Command><Name>GetTabList</Name></Command></Tabs>").length === 0,
  "parseTuneInTabs ignores dynamic tab command")

const tuneInFolder = parseTuneInList({ List: { item: [
  { folder: true, type: "link", key: "local", URL: "http://opml/Browse.ashx?c=local", text: "Local Radio", default_action: "Browse" }
] } }, "Browse")
assert(tuneInFolder.length === 1 && tuneInFolder[0].folder === true && tuneInFolder[0].svc === "tunein",
  "parseTuneInList folder row")
assert(tuneInFolder[0].title === "Local Radio" && tuneInFolder[0].url === "http://opml/Browse.ashx?c=local",
  "parseTuneInList text and URL")

const tuneInStations = parseTuneInList({ List: { item: [
  { is_header: true, text: "FM" },
  { text: "90.1 | WFYI", subtext: "US News", type: "audio", item: "station", guide_id: "s28930",
    URL: "http://opml/Tune.ashx?id=s28930", image: "http://logo.png", default_action: "Browse" }
] } }, "Browse")
assert(tuneInStations.length === 2 && tuneInStations[0].isHeader === true, "parseTuneInList keeps headers")
assert(tuneInStations[1].folder === false && tuneInStations[1].guideId === "s28930", "parseTuneInList station row")
assert(parseTuneInList({ List: { item: { text: "One", folder: true } } }, "Browse").length === 1,
  "parseTuneInList single item")

const tapArgs = tuneInTapArgs(tuneInStations[1])
assert(tapArgs.screen === "Browse" && tapArgs.URL === "http://opml/Tune.ashx?id=s28930"
  && tapArgs.guide_id === "s28930" && tapArgs.item === "station" && tapArgs.type === "audio"
  && tapArgs.text === "90.1 | WFYI" && tapArgs.image === "http://logo.png",
  "tuneInTapArgs mirrors driver Browse action params")
assert(tuneInTapArgs(tuneInFolder[0]).key === "local", "tuneInTapArgs carries key")
const NAV = ["MENU", "UP", "DOWN", "LEFT", "RIGHT", "ENTER"]
const TRANSPORT = ["PLAY", "STOP", "PAUSE", "SKIP_FWD", "SKIP_REV", "SCAN_FWD", "SCAN_REV"]
const DIGITS = ["NUMBER_0", "NUMBER_1", "NUMBER_2", "NUMBER_3", "NUMBER_4",
  "NUMBER_5", "NUMBER_6", "NUMBER_7", "NUMBER_8", "NUMBER_9"]
const dvdItem = {
  id: 295, name: "Office Apple Tv", proxy: "dvd",
  commands: { command: NAV.concat(TRANSPORT, DIGITS, ["STAR", "POUND", "DASH", "ON", "OFF"]) },
  capabilities: {
    navigator_display_option: {
      type: "dvd", show_transport: true, display_icon: "controller://driver/dvd.png"
    }
  }
}
const dvdCaps = parseRemoteCapabilities(dvdItem)
assert(dvdCaps.hasNavigation && dvdCaps.nav.up && dvdCaps.nav.menu && dvdCaps.nav.enter, "dvd nav")
assert(dvdCaps.hasTransport && dvdCaps.transport.play && dvdCaps.transport.skipFwd, "dvd transport")
assert(dvdCaps.hasDigits && !dvdCaps.hasChannelUpDown && !dvdCaps.hasDiscreteChannelSelect, "dvd digits not channel")
assert(dvdCaps.power.on && dvdCaps.power.off, "dvd power")
assert(dvdCaps.showTransport === true && dvdCaps.displayIcon === "controller://driver/dvd.png", "dvd display")
assert(hasRemoteCommand(dvdCaps, "up") && hasRemoteCommand(dvdCaps, "MENU"), "hasRemoteCommand")

const c4zItem = {
  id: 431, name: "Base Fam Apple TV", proxy: "media_player",
  commands: { command: NAV.concat(TRANSPORT, DIGITS, ["ON", "OFF"]) },
  capabilities: {
    navigator_display_option: {
      proxybindingid: 5001, type: "media_player",
      translation_url: "controller://driver/appleTV/tr",
      display_icons: ["controller://driver/appleTV/icon.png"]
    }
  }
}
const c4zCaps = parseRemoteCapabilities(c4zItem)
assert(c4zCaps.hasNavigation && c4zCaps.hasTransport && c4zCaps.hasDigits, "c4z commands")
assert(c4zCaps.showTransport === null, "c4z missing show_transport is not false")
assert(c4zCaps.displayIcons.join(",") === "controller://driver/appleTV/icon.png", "c4z display_icons")

const cableItem = {
  id: 20, name: "Cable DVR", proxy: "cable",
  commands: { command: DIGITS.concat(["CHANNEL_UP", "CHANNEL_DOWN"]) },
  capabilities: { has_channel_up_down: true, has_discrete_channel_select: "1" }
}
const cableCaps = parseRemoteCapabilities(cableItem)
assert(cableCaps.hasDigits && cableCaps.hasChannelUpDown && cableCaps.hasDiscreteChannelSelect, "cable channel flags")
assert(!cableCaps.hasNavigation && !cableCaps.hasTransport, "cable no nav/transport")

assert(parseRemoteCapabilities(null).hasNavigation === false, "null item")
assert(parseRemoteCapabilities({}).commands.length === 0, "no commands")
assert(parseRemoteCapabilities({ name: "Apple TV", model: "Apple TV", manufacturer: "Apple" }).hasNavigation === false,
  "name is not a gate")

const single = parseRemoteCapabilities({ commands: { command: { name: "UP" } } })
assert(single.commands.length === 1 && single.nav.up === true && single.hasNavigation, "single object command")
assert(parseRemoteCapabilities({ commands: { command: [{ "#text": "MENU" }, { "#text": "UP" }] } }).nav.menu === true,
  "xml #text command name")
assert(parseRemoteCapabilities({ commands: ["UP", "DOWN"] }).nav.up === true, "commands as top-level array")

const parentOnly = { id: 294, parentId: null, commands: { command: ["ON"] } }
const childNav = { id: 295, parentId: 294, commands: { command: NAV } }
const resolvedChild = itemForWatchRemote([parentOnly, childNav], 294)
assert(resolvedChild && Number(resolvedChild.id) === 295, "watch remote follows child with nav")
const resolvedSelf = itemForWatchRemote([parentOnly, childNav], 295)
assert(resolvedSelf && Number(resolvedSelf.id) === 295, "watch remote prefers the selected nav item")
const childNoNav = { id: 432, parentId: 431, commands: {} }
const parentNav = { id: 431, commands: { command: NAV } }
assert(Number(itemForWatchRemote([childNoNav, parentNav], 432).id) === 431, "watch remote follows parent with nav")
assert(findItemById({ items: [dvdItem] }, 295).name === "Office Apple Tv", "findItemById unwraps items.items")
assert(matchWatchSourceId([{ id: 295 }], [parentOnly, childNav], 295) === 295, "matchWatchSourceId list id")
assert(matchWatchSourceId([{ id: 295 }], [parentOnly, childNav], 294) === 295, "matchWatchSourceId parent walks to child in list")
assert(matchWatchSourceId([{ id: 294 }], [parentOnly, childNav], 295) === 294, "matchWatchSourceId child device maps to parent list id")
assert(matchWatchSourceId([{ id: 295 }], [parentOnly, childNav], 999) === null, "matchWatchSourceId unknown")
assert(matchWatchSourceId([{ id: 295 }], [parentOnly, childNav], null) === null, "matchWatchSourceId null")

const receiverItem = {
  id: 370, name: "Base Fam Sony Reciever", proxy: "receiver",
  capabilities: {
    has_discrete_surround_mode_select: true,
    surround_modes: {
      type: "xml",
      surround_mode: [
        { id: 1, name: "2ch: Stereo" },
        { id: 2, name: "2ch: Analog Direct" },
        { id: 3, name: "A.F.D: Auto" },
        { id: 4, name: "Multi Stereo" },
        { id: 9, name: "Movie/Music: Dolby Surround" },
        { id: 10, name: "Movie/Music: Neural:X" }
      ]
    }
  }
}
const receiverCaps = parseRemoteCapabilities(receiverItem)
assert(!receiverCaps.hasNavigation && receiverCaps.commands.length === 0, "receiver has no nav commands")
assert(!receiverCaps.hasTransport, "receiver has no transport")
assert(receiverCaps.hasDiscreteSurroundModeSelect === true, "receiver discrete surround flag")
assert(receiverCaps.surroundModes.length === 6, "receiver six surround modes")
assert(receiverCaps.surroundModes[0].id === 1 && receiverCaps.surroundModes[0].name === "2ch: Stereo", "receiver first mode")
assert(receiverCaps.surroundModes[4].id === 9 && receiverCaps.surroundModes[4].name === "Movie/Music: Dolby Surround", "receiver dolby")
assert(hasWatchRemoteUi(receiverCaps) === true, "receiver opens remote on surround")
assert(hasWatchRemoteUi(c4zCaps) === true, "apple tv still opens remote")
assert(hasWatchRemoteUi(cableCaps) === true, "cable opens remote on channel flags")
const digitsOnlyCaps = parseRemoteCapabilities({ commands: { command: DIGITS } })
assert(digitsOnlyCaps.hasDigits && !digitsOnlyCaps.hasChannelUpDown && !digitsOnlyCaps.hasDiscreteChannelSelect,
  "digits-only has no channel flags")
assert(hasWatchRemoteUi(digitsOnlyCaps) === false, "digits without channel flags do not open")
assert(!dvdCaps.hasChannelUpDown && !dvdCaps.hasDiscreteChannelSelect, "dvd digits are not a channel pad")
assert(!receiverCaps.hasChannelUpDown && !receiverCaps.hasDiscreteChannelSelect, "receiver has no channel pad")
const playOnlyCaps = parseRemoteCapabilities({ commands: { command: ["PLAY"] } })
assert(playOnlyCaps.hasTransport && !playOnlyCaps.hasNavigation, "play-only is transport")
assert(hasWatchRemoteUi(playOnlyCaps) === true, "transport-only opens remote")
const showTransportFalse = parseRemoteCapabilities({
  commands: { command: ["PLAY", "PAUSE"] },
  capabilities: { navigator_display_option: { show_transport: false } }
})
assert(showTransportFalse.showTransport === false, "explicit show_transport false is recorded")
assert(showTransportFalse.hasTransport && showTransportFalse.transport.play && showTransportFalse.transport.pause,
  "show_transport false does not hide declared keys")
assert(hasWatchRemoteUi(showTransportFalse) === true, "show_transport false still opens")
assert(Number(itemForWatchRemote([receiverItem], 370).id) === 370, "watch remote keeps surround source")

assert(parseRemoteCapabilities(c4zItem).surroundModes.length === 0, "apple tv has no surround rows")
assert(parseRemoteCapabilities({
  capabilities: { surround_modes: { surround_mode: { id: 3, name: "A.F.D: Auto" } } }
}).surroundModes.length === 1, "single-object surround_mode")
assert(parseRemoteCapabilities({
  capabilities: { surround_modes: { surround_mode: [{ id: "x" }, { id: 2 }, { name: "Nope" }, { id: 4, name: "  Multi Stereo  " }] } }
}).surroundModes.map(function(m) { return m.id + ":" + m.name }).join(",") === "4:Multi Stereo",
  "skip malformed surround entries")

const sm = surroundModeParams(3)
assert(sm && sm.SURROUNDMODE === 3 && sm.OUTPUT === 4000, "surroundModeParams")
assert(surroundModeParams("nope") === null, "surroundModeParams rejects NaN")

assert(MAX_CREDENTIALS_FILE_BYTES === 65536, "credentials byte cap")
assert(MAX_FOCUS_FILE_BYTES === 4096, "focus byte cap")
assert(STATE_FILE_PYTHON === "/usr/bin/python3", "absolute python path")
const readCmd = stateFileReadCommand("/tmp/creds.json", 1024)
assert(readCmd[0] === "/usr/bin/python3" && readCmd[2].includes("O_NOFOLLOW")
  && readCmd[2].includes("O_NONBLOCK")
  && readCmd[3] === "/tmp/creds.json" && readCmd[4] === "1024", "stateFileReadCommand")
const writeCmd = stateFileWriteCommand("/tmp/focus.json", 4096)
assert(writeCmd[0] === "/usr/bin/python3" && writeCmd[2].includes("mkstemp")
  && writeCmd[2].includes("os.replace") && !writeCmd[2].includes("O_TRUNC")
  && writeCmd[3] === "/tmp/focus.json" && writeCmd[4] === "4096", "stateFileWriteCommand")

const stateDir = fs.mkdtempSync(path.join(require("os").tmpdir(), "c4-state-"))
const statePath = path.join(stateDir, "focus.json")
const payload = "{\"roomId\": 9}\n"
const writeCmdRt = stateFileWriteCommand(statePath, MAX_FOCUS_FILE_BYTES)
const writeRun = spawnSync(writeCmdRt[0], writeCmdRt.slice(1), {
  input: payload,
  encoding: "utf8"
})
assert(writeRun.status === 0, "state file write round-trip writes")
const readCmdRt = stateFileReadCommand(statePath, MAX_FOCUS_FILE_BYTES)
const readRun = spawnSync(readCmdRt[0], readCmdRt.slice(1), {
  encoding: "utf8"
})
assert(readRun.status === 0 && readRun.stdout === payload, "state file write round-trip reads")
const st = fs.statSync(statePath)
assert((st.mode & 0o777) === 0o600, "state file write mode 0600")
fs.rmSync(stateDir, { recursive: true, force: true })

const fifoDir = fs.mkdtempSync(path.join(require("os").tmpdir(), "c4-fifo-"))
const fifoPath = path.join(fifoDir, "focus.json")
assert(spawnSync("mkfifo", ["-m", "600", fifoPath]).status === 0, "mkfifo for FIFO read test")
const fifoReadCmd = stateFileReadCommand(fifoPath, MAX_FOCUS_FILE_BYTES)
const fifoRead = spawnSync(fifoReadCmd[0], fifoReadCmd.slice(1), { encoding: "utf8" })
assert(fifoRead.status === 1, "state file read rejects FIFO without blocking")
fs.rmSync(fifoDir, { recursive: true, force: true })

const panelQml = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8")
assert(!/[\u25B6\u23F8\u23ED\u23EE\u23EA\u23E9]/.test(panelQml),
  "transport labels must not use color-emoji media symbols")
assert(panelQml.includes('label: "Play"') && panelQml.includes('label: "Pause"')
  && panelQml.includes('label: "Next"'),
  "transport keys use word labels")
assert(!/fittedContentHeight\([\s\S]*Style\.space\(720\)/.test(panelQml),
  "panel height must not be capped at Style.space(720)")
assert(!/width:\s*2[\s\S]{0,160}haloAccent/.test(panelQml),
  "HaloRow must not paint a 2px orange leading edge")
assert(panelQml.includes("fillColor: root.haloAccent")
  && panelQml.includes("knobColor: root.haloAccent"),
  "volume slider keeps halo accent")

const serviceQml = fs.readFileSync(path.join(__dirname, "..", "Service.qml"), "utf8")
assert(!serviceQml.includes("FileView"), "state files must not use FileView")
assert(serviceQml.includes("stateFileReadCommand"), "bounded state read")
assert(serviceQml.includes("stateFileWriteCommand"), "bounded state write")

console.log("ok")
