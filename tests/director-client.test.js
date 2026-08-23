#!/usr/bin/env node
"use strict"

const fs = require("fs")
const path = require("path")
const vm = require("vm")
const src = fs.readFileSync(path.join(__dirname, "..", "DirectorClient.js"), "utf8")
  .replace(/^\.pragma library\s*/, "")
const ctx = vm.createContext({})
vm.runInContext(src, ctx)
const {
  parseHttp, parseAccountToken, parseControllerCommonName, parseDirectorToken,
  classifyProbe, classifyCloudStatus, commandBody, curlArgs, withAuthHeader,
  networkErrorMessage, isTransientCurl,
  normalizeHost, credentialsComplete, statusTextFor, accountAuthBody,
  APPLICATION_KEY, STATUS_NOT_CONFIGURED, STATUS_NOT_CONNECTED,
  STATUS_SIGN_IN_FAILED, STATUS_DIRECTOR_401, STATUS_CONNECTED,
  extractRooms, isRoomHidden, parseFocusFile, sortRoomsByNameThenId,
  extractSources, sourceArray, parseRoomVolume,
  parseEngineIoSid, parseSocketIoClientId, parseMspResponse, parseMspResponses, mspArgXml,
  parseMspTabs, parseMspList, parseMspNextScreen, isAppleMusicItem, mspPlayCommand, curlNavArgs,
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

const args = curlArgs({ url: "https://example", insecure: true, bodyPath: "/tmp/body.json" })
assert(args.indexOf("-k") !== -1, "curl -k")
assert(args.indexOf("-f") === -1, "no curl -f")
assert(args.join(" ").indexOf("secret") === -1, "no secret in argv template")
assert(JSON.stringify(args).indexOf("password") === -1, "no password in argv template")

const authed = withAuthHeader(["curl", "https://x"], "TOKEN")
assert(authed.indexOf("-H") !== -1, "auth header flag")
assert(authed.indexOf("Authorization: Bearer TOKEN") !== -1, "auth header value")

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
const navArgs = curlNavArgs({ url: "https://x/socket.io", insecure: true, maxTime: 35 })
assert(navArgs.indexOf("-k") !== -1 && navArgs.indexOf("--max-time") !== -1, "curlNavArgs")

console.log("ok")
