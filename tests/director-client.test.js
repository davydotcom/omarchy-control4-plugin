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
  STATUS_SIGN_IN_FAILED, STATUS_DIRECTOR_401, STATUS_CONNECTED
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

console.log("ok")
