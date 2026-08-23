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
  normalizeHost, credentialsComplete, statusTextFor, accountAuthBody,
  APPLICATION_KEY, STATUS_NOT_CONFIGURED, STATUS_NOT_CONNECTED,
  STATUS_SIGN_IN_FAILED, STATUS_DIRECTOR_401, STATUS_CONNECTED,
  extractRooms, isRoomHidden, parseFocusFile, sortRoomsByNameThenId,
  extractSources, sourceArray
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

console.log("ok")
