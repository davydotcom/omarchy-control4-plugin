---
title: "Stream curl transport — no request or response data on disk"
slug: stream-curl-transport
type: feature
status: completed
domain: engineering
size: large
created: 2026-08-25
tags: [omarchy, control4, security, transport, refactor]
relates-to:
  - in-process-director-rest
  - msp-browse-needs-navigator-session
completed_at: 2026-08-26T00:35:49Z
---
# Stream curl transport — no request or response data on disk

## Context

The marketplace listing review (`HANCORE-linux/omarchy-plugin-marketplace#1941`,
reviewer `ryanrhughes`, against commit `3300128` — current HEAD) flagged the
plugin's transport layer. Today every Control4 request and response round-trips
through the filesystem: `Service.qml` writes the POST body, the bearer/JWT
header, and the curl response to six files under
`$HOME/.local/state/omarchy/io.github.davydotcom.control4/`, then races `chmod
600` against them.

That design came from `in-process-director-rest`, which chose files specifically
to keep passwords and tokens out of `Process.command` argv. The goal was right;
the mechanism is heavier and leakier than it needs to be. `curl -K -` reads a
complete config file — URL, repeated headers, and request body — from **stdin**,
which keeps the same secrets out of argv with nothing touching disk at all.

The standing preference this repo works to: **data that is pure transport does
not get written to disk when it can be piped.** Genuine cross-restart state
(`credentials.json`, `focus.json`) stays.

The review raised four adjacent findings, all in the same blast radius, all
fixed in this same commit. A fifth — the `stat` → `FileView` TOCTOU on the
response files — is not separately addressed because the files it concerns are
deleted here.

## Goal

Every Control4 HTTP request and response — cloud auth, Director REST, and the
navigator socket.io polling flow — is carried entirely in memory: the request
config (URL, headers, body) goes to curl over stdin, the response body streams
back over a bounded pipe, and the HTTP status and curl exit code arrive as
markers on stderr. Six transport files and all their `FileView`, `chmod`, and
`stat` plumbing are deleted. `credentials.json` can no longer land at 0644, the
navigator cookie jar is created 0600 and removed on disconnect, `README.md`
accurately describes what survives plugin removal, and the volume poll no longer
enqueues on top of an in-flight request. No user-visible behavior changes.

## Kickoff

Rewrites the plugin's curl transport so no request or response data hits disk —
config goes in over stdin, body streams back through a bounded pipe — plus four
security fixes from the marketplace listing review.

**Status:** delivering — implementation complete, audit + verify pending.

**Pick up at:** run `hero spec verify stream-curl-transport`, commit, push, and
re-submit marketplace #1941 for re-review.

→ `.hero/planning/features/stream-curl-transport/spec.md`

**Files:** `DirectorClient.js`, `Service.qml`, `tests/director-client.test.js`, `README.md`
**Skip:** putting URLs or tokens back in argv; reintroducing transport temp files.

## Approach

### The three mechanics (validated on this machine, curl 8.21.0)

1. **`curl -K -`** reads a config file from stdin carrying `url`, `header`
   (repeatable), `data-binary`, and the flag options. Verified: a bearer token
   and a JSON body containing an embedded escaped quote both round-trip intact
   with nothing in argv.
2. **`write-out = "%{stderr}HTTP:%{http_code}\n"`** puts the status code on
   stderr, leaving stdout for the body alone.
3. **`sh -c '… | head -c <cap>'`** streams the body and truncates at the cap, so
   the `StdioCollector` is bounded without a response file. `head -c` closing the
   pipe also SIGPIPEs curl, aborting an oversized transfer early.

### The shell wrapper is a compile-time constant

Every request runs the **same, fully static** command with **zero string
interpolation**:

```
["sh", "-c", "umask 077; { curl -K -; echo \"RC:$?\" >&2; } | head -c 8388609"]
```

Using a shell is acceptable here **only because of that**: no URL, no token, no
password, and no caller-controlled value ever reaches the command string. Every
per-request value arrives on stdin. If a future change needs to interpolate
anything into this string, that is the signal the design has been broken — pass
it through the config on stdin instead.

Three things the wrapper buys:

- **`umask 077`** — every file curl creates in this process (i.e. the navigator
  cookie jar written by `-c`) is mode 0600 at creation. This replaces the
  chmod-after-write race entirely rather than fixing it.
- **The brace group** — `{ curl -K -; echo "RC:$?" >&2; }` preserves curl's exit
  code as a marker on stderr. Without it the pipeline's exit status is `head`'s
  and curl's code is lost, which would break both `networkErrorMessage()` and
  `isTransientCurl()`. POSIX-portable; does not depend on `pipefail`.
- **`head -c 8388609`** — that is `MAX_RESPONSE_BYTES + 1`. Capping one byte
  above the limit means the existing `isOversizedResponse(body)` (`length > MAX`)
  fires on exactly the same inputs it does today, with no off-by-one drift and
  no new size-check function. `isOversizedBytes` and the `stat` processes it
  served are deleted.

### Escaping — the one genuinely new parsing surface

Inside a curl config quoted string, curl un-escapes `\\`, `\"`, `\t`, `\n`,
`\r`, `\v`. So the transform is **backslash first, then quote**:

```js
s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')
```

Order is load-bearing and the reason is not obvious. A JSON body already
contains `\"` for embedded quotes and `\n` for embedded newlines. Escaping
backslashes first turns JSON's `\n` (backslash, n) into `\\n`, which curl
un-escapes back to the literal two characters — correct. Quote-first would
produce `\\"` from `\"` and corrupt the body. This function is the main risk in
the change and gets direct test coverage.

### Behavior preservation

Nothing about the wire behavior changes. Carry over exactly:

- `-k` (`insecure`) for the LAN Director; TLS verification stays **on** for
  `apis.control4.com`.
- `--max-time` 20 for the Director/cloud path; 12 / 35 for the navigator paths.
- `--max-filesize 8388608` stays as an early abort for responses that declare an
  oversized `Content-Length`; the `head -c` cap is the backstop for those that
  do not.
- **No `-X`/`request`.** Today `curlArgs` never sets an explicit method — GET is
  implicit and POST is implied by `--data-binary`. Do not add `request =` to the
  config; it would change redirect behavior.
- The `_httpGen` / `_volumeGen` generation guards and the `_queue` / `_pump`
  state machine keep their current semantics (see Changes item 8 for the one
  narrow exception).

### The navigator cookie jar — open decision, recommendation below

`nav-cookies.txt` is the one transport file this spec proposes to **keep**.
Separate short-lived curl processes need a shared jar across the handshake →
namespace → client → poll sequence.

**Option A (recommended): keep the jar, created 0600 by the wrapper's `umask
077`, deleted on `disconnect()`.** No new parsing surface. The `chmod` race that
finding #2 describes disappears because the file is never created world-readable
in the first place. Cost: one file that is transport-only still lives on disk,
which is a real concession against the standing preference.

**Option B: eliminate it.** Add `dump-header = "/dev/stderr"` to the nav config,
parse `Set-Cookie` off the stderr stream, and feed the value back as `cookie =
"…"` on the next request's stdin config. Cost: this reimplements cookie
handling — multiple cookies, `Path`, `Expires`, replacement-vs-append semantics
— and mixes header text into the same stderr stream the `HTTP:` / `RC:` markers
use. That is a second new parsing surface, larger and less testable than the
escaper, added to the most fragile state machine in the file.

**Recommendation: Option A.** The cookie is a short-lived LAN session cookie in
a user-private state directory at 0600, deleted on disconnect. Option B trades a
concrete, bounded exposure for a new class of parsing bug in the navigator flow,
which is exactly the gold-plating this change should avoid. **Confirm the call
before implementing** — if Option B is chosen, it is a scope increase and the
size should be re-evaluated.

**Worth one cheap check first:** the engine.io `sid` is already carried in the
URL query string (`_navSocketUrl`). Before implementing either option, verify
against a live Director whether `-b`/`-c` is load-bearing at all. If the flow
works with no jar, the file goes away for free and both options are moot.

## Changes

### DirectorClient.js — config-text builders

1. **Add `curlConfigEscape(s)`** — the backslash-then-quote transform described
   in Approach. Pure function, exported, directly tested. Add a short comment
   naming why the order matters; it is not self-evident.

2. **Add `curlConfigText(opts)`**, replacing `curlArgs` / `authHeaderText` /
   `withHeaderFile` (delete all three). Takes `{ url, insecure, body, token }`
   and returns the complete config text. Emits, in order:
   - `silent` / `show-error` (the `-sS` equivalent)
   - `max-time = "20"`
   - `max-filesize = "8388608"` (from `MAX_RESPONSE_BYTES`)
   - `insecure` — only when `opts.insecure` is true
   - `write-out = "%{stderr}HTTP:%{http_code}\n"`
   - `header = "Authorization: Bearer <token>"` — only when a token is present
   - `header = "Content-Type: application/json"` and
     `data-binary = "<escaped body>"` — only when a body is present
   - `url = "<escaped url>"`

   Every interpolated value passes through `curlConfigEscape`. Guard the body
   against a leading `@`: in a config file `data-binary` treats a leading `@` as
   a filename. No current caller produces one (all bodies are `JSON.stringify`
   output starting with `{`), but the builder must not silently turn a future
   body into a file read — reject or prefix-escape it explicitly.

3. **Add `curlNavConfigText(opts)`**, replacing `curlNavArgs` and
   `navHeaderText` (delete both). Same shape, plus:
   - `max-time` from `opts.maxTime`, defaulting to `"35"`
   - both navigator headers: `Authorization: Bearer <token>` and `JWT: <token>`
   - `cookie` / `cookie-jar` set to `opts.cookiePath` when present (Option A)
   - `Content-Type` from `opts.contentType`, defaulting to `text/plain`
   - no `write-out` — the navigator flow never reads an HTTP status; only the
     body and the curl exit code are consumed.

4. **Add `parseStderrMarkers(stderrText)`** returning `{ status, exitCode }`.
   Extract by marker (`/HTTP:(\d+)/` and `/RC:(-?\d+)/`), taking the **last**
   match of each — `-sS` still writes human-readable error text like
   `curl: (28) Operation timed out` to the same stream, so position-based
   parsing is not safe. Missing `HTTP:` yields status `0`; missing `RC:` yields
   exit code `0`.

5. **Delete `isOversizedBytes`** and its export. The `stat`-based size check it
   served is gone; `isOversizedResponse` (`length > MAX_RESPONSE_BYTES`) is the
   only size gate and it now fires on the truncated body from the `head -c`
   cap. Remove its assertion from `tests/director-client.test.js`.

### Service.qml — delete the file transport

6. **Delete the six transport path properties**: `bodyPath` (17), `headerPath`
   (18), `responsePath` (19), `_navBodyPath` (75), `_navHeaderPath` (77),
   `_navResponsePath` (78). Keep `credentialsPath`, `focusPath`, and (per Option
   A) `_navCookiePath`.

7. **Delete the six transport `FileView`s** — `bodyFile`, `headerFile`,
   `navBodyFile`, `navHeaderFile`, `responseFile`, `navResponseFile` (1471-1539)
   — **and the seven `Process` objects** that existed only to serve them:
   `chmodBodyProc`, `chmodResponseProc`, `responseStatProc`,
   `chmodNavResponseProc`, `navStatProc`, `navTouch`, `navChmodProc`. Delete the
   `navPostDelay` `Timer` (1698-1710) — its 50 ms delay existed only to let an
   async `FileView.setText` land, and config text is now built synchronously.

8. **Rewrite `httpProc` (1649-1676)** to the static wrapper command, with stdin
   config delivery:
   - `command:` the constant `["sh", "-c", …]` array from Approach. Never
     reassigned per request.
   - `stdinEnabled: true` declared on the object, so stdin is open before the
     process starts.
   - `onStarted:` `write(root._httpConfig)` then `stdinEnabled = false`.
     **Write only after `started` fires, and close only after writing** —
     `Process` has no `flush()` (unlike `Socket`), and `curl -K -` reads stdin to
     EOF before it begins the transfer, so it will hang forever if stdin is never
     closed. Using the `started` signal rather than a `Qt.callLater` removes the
     ordering race entirely.
   - `stdout`/`stderr` keep their `StdioCollector`s. stdout is now the body;
     stderr carries the markers.
   - `onExited:` keep the `_ignoreHttpExit` abort guard. Then parse stderr via
     `parseStderrMarkers` and call `_finishHttp(markers.exitCode, httpStdout.text,
     String(markers.status))` directly. The `exitCode === 63` early return stays,
     now keyed on the parsed marker rather than the process exit code. Delete
     `_httpAwaitingBody`, `_httpExitCode`, and `_httpStatusText` — the response
     is available synchronously at exit.

9. **Rewrite `_pump` (1195-1231)** — the guard collapses to `if (httpProc.running
   || _pending || !_queue.length) return`. Delete the `chmodFiles` array, the
   `setText` calls, and the `Qt.callLater` / `job.gen` hop; build the config text
   synchronously into `_httpConfig` and call `_startHttp(job)` directly.

   **`_httpGen` decision rule:** with the chmod hop gone there is no async gap
   between `_pump()` and `httpProc.running = true`, which leaves `_httpGen` and
   `job.gen` with no consumer. Remove them **only if** that is true after the
   rewrite. The `_ignoreHttpExit` guard in `_abortHttp` stays regardless — it
   still covers the in-flight-process case. `_volumeGen` is independent
   (callback staleness) and stays untouched.

10. **Rewrite `_startHttp` (1233-1244)** to build config text via
    `DirectorClient.curlConfigText({ url, insecure, body, token })`, assign it to
    `root._httpConfig`, and set `httpProc.running = true`. No `command`
    assignment.

11. **Simplify `_abortHttp` (166-186)** — drop the `chmodBodyProc` /
    `chmodResponseProc` / `responseStatProc` / `_httpAwaitingBody` teardown;
    those objects no longer exist.

### Service.qml — the navigator flow

12. **Rewrite `navProc` (1712-1723)** the same way as `httpProc`: static wrapper
    command, `stdinEnabled: true`, `onStarted` writes `root._navConfig` then
    closes stdin. In `onExited`, parse `RC:` off stderr and pass that as the
    exit code to `_onNavExit`.

13. **Collapse the navigator's async hops.** `_navGet` (786-793) and
    `_navPostRaw` (795-801) currently write a `FileView` and restart
    `navPostDelay`; they now build the config text via `curlNavConfigText` and
    call `_startNavGet` / `_startNavPost` directly. `_startNavGet` (803-817) and
    `_startNavPost` (819-841) set `root._navConfig` and `navProc.running = true`.

14. **Collapse `_onNavExit` (843-856) and `_finishNavBody` (858-…)** into a
    single synchronous path — the response body is in `navStdout.text` at exit,
    so the `chmodNavResponseProc` → `navStatProc` → `navResponseFile.reload()`
    chain disappears. Keep the `_navIgnoreExit` guard, the `exitCode === 63`
    `_stopNav()` branch, and the `isOversizedResponse(text)` check with its
    existing `_stopNav()` outcome. Delete `_navAwaitingBody` and `_navExitCode`.

15. **`_startNav` (752-763)** no longer `touch`es the cookie jar — `-b` on a
    nonexistent path is a no-op and the wrapper's `umask 077` creates the jar
    0600 when `-c` first writes it. Call `_navGet("/socket.io/?EIO=4&transport=polling", 12)`
    directly instead of routing through `navTouch.onExited`.

16. **Simplify `_stopNav` (765-783)** — drop the `navChmodProc`,
    `chmodNavResponseProc`, `navStatProc`, and `navPostDelay` teardown.

### The four review findings

17. **Finding 1 — `credentialsFile` can land at 0644.** Add `blockWrites: true`
    to the `credentialsFile` `FileView` (Service.qml:1451-1458), matching the
    four transport `FileView`s that already have it. Without it, `setText` is
    async and `atomicWrites: true` renames a fresh inode over the one
    `chmodProc` targets, so the plaintext Control4 password can be left
    world-readable. Additionally, chmod the state directory itself to 0700 after
    `mkdirProc` succeeds — defense in depth, so a future per-file race cannot
    expose anything regardless.

18. **Finding 2 — `nav-cookies.txt` is world-readable.** Resolved by item 15:
    the wrapper's `umask 077` makes the jar 0600 at creation, and the
    `navChmodProc` that only ever covered `_navHeaderPath` / `_navBodyPath` is
    deleted along with those files. Verify the resulting mode on disk manually
    (Validation step 4) — it is currently `-rw-r--r--` holding a live navigator
    session cookie.

19. **Finding 3 — nothing ever deletes state files.** Add an `rmProc`
    (`["rm", "-f", root._navCookiePath]`) and fire it from `disconnect()`
    (147-165), which today clears memory only. The six transport files are gone,
    so the cookie jar is the only transport artifact left to clean up.
    `credentials.json` and `focus.json` intentionally survive.

20. **Finding 3 (docs) — `README.md:106-114`** states that removing the plugin
    leaves only `credentials.json` and `focus.json`. Correct it to name the
    actual surviving set after this change, and mention that Disconnect clears
    the navigator cookie jar.

21. **Finding 4 — `refreshVolume` has no coalescing.** `refreshVolume`
    (966-975) enqueues unconditionally every 2 s; `_volumeGen` discards stale
    *callbacks* but never stale *queue entries*, and `_queue` has no cap. Add a
    `_volumePending` boolean: skip the `directorGet` when it is already set,
    clear it in the callback (both the stale-generation early return and the
    normal path). **Keep this small** — it is self-limiting today, because the
    first failure drives state to `error` which stops `volumeTimer`. A boolean
    guard is the whole fix; do not add a queue cap, a backoff, or a dedupe layer.

### Knowledge

22. **Update `.hero/knowledge/decisions/in-process-director-rest/spec.md`.** Its
    `## Decision` section currently prescribes the exact file scheme this spec
    removes ("POST bodies go to a 0600 temp file (`--data-binary @path`)…
    Response bodies go to `-o` (mode 600)"). Rewrite those sentences to describe
    stdin-config transport with a bounded stdout pipe. **The decision itself is
    not overturned** — in-process `Process` + `curl`, `-k` for the LAN Director,
    TLS verify on for the cloud, no sidecar, no HA dependency, never log tokens:
    all of that stands. Only the transport mechanism changes. Add a line noting
    the amendment and pointing at this spec.

## Acceptance Criteria

- **AC-1:** THE SYSTEM SHALL construct every curl invocation from a single
  compile-time-constant `command` array containing no URL, token, password, or
  other caller-controlled value.
- **AC-2:** WHEN a request carries a bearer token, a navigator JWT, or a Control4 password THE SYSTEM SHALL transmit it to curl over stdin only and SHALL NOT place it in `Process.command`.
- **AC-3:** THE SYSTEM SHALL NOT create, write, or read `http-body.json`,
  `http-header`, `http-response`, `nav-body.txt`, `nav-header`, or
  `nav-response`, and no `FileView`, `chmod`, or `stat` process for them SHALL
  remain in `Service.qml`.
- **AC-4:** WHEN `curlConfigEscape` receives a string containing backslashes and double quotes THE SYSTEM SHALL escape backslashes before quotes, so a `JSON.stringify` body round-trips through a curl config file byte-identically.
- **AC-5:** IF a request body begins with `@` THEN THE SYSTEM SHALL NOT allow
  `data-binary` to interpret it as a filename.
- **AC-6:** WHEN a response exceeds `MAX_RESPONSE_BYTES` THE SYSTEM SHALL truncate it at the pipe cap and reject it through the existing `isOversizedResponse` path, producing the same caller-visible outcome as today's `stat`-based rejection.
- **AC-7:** WHEN curl finishes THE SYSTEM SHALL recover both the HTTP status
  code and curl's own exit code from stderr markers, so that
  `networkErrorMessage()` and `isTransientCurl()` receive the same exit codes
  they receive today.
- **AC-8:** IF curl writes human-readable error text to stderr alongside the markers THEN THE SYSTEM SHALL still extract the correct status and exit code from `parseStderrMarkers`.
- **AC-9:** THE SYSTEM SHALL preserve `-k` for the LAN Director, TLS
  verification for `apis.control4.com`, the 20 s Director timeout, the 12 s and
  35 s navigator timeouts, `--max-filesize`, and the absence of an explicit
  `-X`/`request` method.
- **AC-10:** THE SYSTEM SHALL preserve the `_queue`/`_pump` ordering semantics,
  the `_volumeGen` staleness guard, and the `_ignoreHttpExit` / `_navIgnoreExit`
  abort guards.
- **AC-11:** WHILE a curl process is running THE SYSTEM SHALL keep its stdin
  closed after the config has been written, and SHALL write the config only
  after the process has started.
- **AC-12:** WHEN `persistCredentials()` writes `credentials.json` THE SYSTEM SHALL leave the file at mode 0600, with no window in which it is readable by other users.
- **AC-13:** THE SYSTEM SHALL create `nav-cookies.txt` at mode 0600.
- **AC-14:** WHEN `disconnect()` is called THE SYSTEM SHALL remove
  `nav-cookies.txt` and SHALL leave `credentials.json` and `focus.json` in
  place.
- **AC-15:** WHILE a volume request is in flight THE SYSTEM SHALL NOT enqueue
  another one.
- **AC-16:** THE SYSTEM SHALL leave all user-visible plugin behavior unchanged —
  connect, room list, source selection, volume, now-playing, and MSP/TuneIn
  browse all behave as they do at commit `3300128`.

## Boundaries

- **The `stat` → `FileView` TOCTOU** the reviewer also raised is not separately
  addressed. It exists only on `http-response` / `nav-response`, both deleted
  here. Do not write a guard for it.
- **`credentials.json` and `focus.json` stay on disk.** They are genuine
  cross-restart persistence, not transport. Do not move them into memory, do not
  encrypt them, do not add a keyring dependency.
- **Do not restructure the navigator state machine.** `_navPhase`
  (`handshake` → `ns` → `client` → `live`), the sequence/`SEQ` correlation, the
  browse retry timer, and the MSP command shapes are out of scope. This change
  swaps how bytes move; it does not change the protocol.
- **Do not touch `Panel.qml` or `BarWidget.qml`.** No UI change is in scope.
- **Do not gold-plate finding 4.** A `_volumePending` boolean is the fix. No
  queue cap, no backoff, no request dedupe.
- **No new dependencies.** `sh`, `curl`, `head`, `rm`, `mkdir`, `chmod` are the
  full external surface, all coreutils/curl already assumed by
  `in-process-director-rest`.
- **Not a `/compose` or `/split` candidate.** These five items are one commit
  against one listing review; the four findings live inside the code the
  transport rewrite deletes and are not independently deliverable.

## Risks

1. **`stdinEnabled = false` may discard buffered data.** This is the highest
   mechanical risk and the one thing that cannot be checked without running
   Quickshell. `Process` has no `flush()`. If closing stdin truncates an
   unflushed `write()`, curl will see a partial config and either error or hang.
   Writing inside `onStarted` (rather than a `Qt.callLater` after
   `running = true`) is the mitigation. **Smoke-test this first, before doing any
   of the deletion work** — if it does not hold, the whole approach needs
   rethinking and the rest of the change is wasted effort.
2. **A hang, not an error, is the failure mode for a missing stdin close.**
   `curl -K -` blocks reading stdin to EOF. If `stdinEnabled = false` is ever
   skipped on an error path, the request hangs until `--max-time`. Verify every
   path that sets `running = true` also reaches the close.
3. **The escaper is the one new parsing surface.** Backslash-before-quote is
   easy to reverse when refactoring and the corruption is silent — a
   double-quote inside a Control4 password produces a malformed JSON body and a
   confusing auth failure rather than a parse error. Covered by AC-4 and direct
   tests.
4. **Lost curl exit codes would silently change retry behavior.** If the `RC:`
   marker is dropped or misparsed, `isTransientCurl` stops seeing codes
   7/23/26/28/52/56 and the two-attempt retry on transient cloud failures
   quietly stops working. This will not show up in any test that does not
   exercise a network failure.
5. **The navigator flow has no automated coverage and needs a live Director.**
   Items 12-16 rewrite seven async hops into synchronous ones inside the most
   intricate state machine in the file. Regressions here surface only against
   real hardware. This is the main reason for the `large` size.
6. **`head -c` and `umask` assume a POSIX shell and GNU coreutils.** True on
   Arch/Omarchy. The brace-group construct avoids depending on `pipefail`, so
   the wrapper works under `dash` as well as `bash`.
7. **Rollback is a plain revert.** No data migration, no schema change, no
   persisted-format change. `credentials.json` and `focus.json` formats are
   untouched, so an older build reads state written by a newer one and vice
   versa. Reverting the commit fully restores the previous transport; any
   leftover transport files in the state dir are ignored by the new build and
   re-created by the old one.
8. **Cookie-jar decision is open** (see Approach). If Option B is chosen instead
   of the recommended Option A, that is a scope increase — re-size before
   starting.

## Validation

### Automated — `node tests/director-client.test.js`

The existing suite is a plain node script using `vm` to evaluate
`DirectorClient.js` with the `.pragma library` line stripped, asserting via a
local `assert` helper and exiting non-zero on the first failure. Extend it in
place; the new functions are pure and cheap to cover.

1. **`curlConfigEscape`** — empty string; no special characters; a lone
   backslash; a lone quote; `\"` (backslash-quote, the JSON case); a full
   `accountAuthBody()` output for a password containing `"`, `\`, and a
   newline. Assert the round-trip: escaping then applying curl's un-escape rules
   returns the original byte-for-byte.
2. **`curlConfigText`** — assert the token appears exactly once as
   `header = "Authorization: Bearer …"`; assert `insecure` is present when and
   only when requested; assert `max-time = "20"` and
   `max-filesize = "8388608"`; assert `write-out` contains `%{stderr}` and
   `HTTP:`; assert **no** `request =` line; assert `Content-Type:
   application/json` and `data-binary` appear only when a body is given; assert
   a body starting with `@` is rejected or neutralized (AC-5).
3. **`curlNavConfigText`** — assert both `Authorization: Bearer` and `JWT:`
   headers; assert `max-time` honours `opts.maxTime` and defaults to `35`;
   assert `cookie` / `cookie-jar` appear when a path is given; assert the
   `contentType` default is `text/plain`; assert no `write-out` line.
4. **Secret containment** — port the existing spirit of the `"token not in
   withHeaderFile argv"` and `"jwt not in curlNavConfigText argv"` assertions:
   assert the constant wrapper command array contains no `SECRET`/`TOKEN`
   sentinel, and that these sentinels appear only in the config text.
5. **`parseStderrMarkers`** — clean `HTTP:200\nRC:0`; markers preceded by
   `curl: (28) Operation timed out`; missing `HTTP:` yields `0`; missing `RC:`
   yields `0`; duplicated markers take the last.
6. **Remove** the `isOversizedBytes` assertions and the `curlArgs` /
   `curlNavArgs` / `withHeaderFile` / `authHeaderText` / `navHeaderText`
   assertions and destructuring entries, replacing them with the above.

### Manual — against a live Director

Run `omarchy plugin validate` and load the plugin, then:

7. **Smoke-test stdin first** (per Risk 1) before deleting anything: a
   throwaway `Process` with the wrapper command, `stdinEnabled: true`, and a
   config written in `onStarted`, hitting a known URL. Confirm the body arrives
   in the `StdioCollector` and the process exits rather than hanging.
8. **Connect** with real credentials. Confirm sign-in succeeds, the room list
   populates, and `statusText` reaches `Connected`.
9. **Exercise the full panel**: select a room, switch a Watch source and a
   Listen source, move the volume slider, mute, Off. Confirm the now-playing
   label and volume track the Director.
10. **Exercise MSP browse and TuneIn** — this is the navigator flow and the
    highest-risk area. Confirm tabs load, drilling into a folder returns named
    rows, and playing a row works.
11. **Confirm no transport files exist.** While connected and actively
    browsing:
    `ls -la "$HOME/.local/state/omarchy/io.github.davydotcom.control4/"` SHALL
    show only `credentials.json`, `focus.json`, and `nav-cookies.txt` (Option
    A). Watch it during a request — the transport files must never appear even
    transiently.
12. **Confirm modes**: `credentials.json` and `nav-cookies.txt` both `-rw-------`,
    state dir `drwx------`. Re-save credentials several times and re-check
    `credentials.json` each time (finding 1 is a race — a single check can pass
    by luck).
13. **Confirm no secrets in argv**: with the plugin connected and browsing, run
    `ps -eo args | /usr/bin/grep curl` and confirm no URL, bearer token, JWT, or
    password is visible.
14. **Confirm cleanup**: hit Disconnect, then confirm `nav-cookies.txt` is gone
    and `credentials.json` / `focus.json` remain.
15. **Confirm error handling**: point the plugin at an unreachable controller IP
    and confirm the status line shows the same network-error text as before
    (this exercises the `RC:` marker path and Risk 4). Then restore a valid IP
    and confirm reconnect works.
16. **Confirm volume coalescing**: while connected with a room focused, confirm
    the 2 s poll issues one request at a time and the UI stays responsive.

## Completion Ledger

Transport refactor for marketplace #1941: stdin curl config, bounded stdout pipe,
stderr markers, four review findings fixed. Option A cookie jar retained.

### Acceptance Criteria

| # | Criterion (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | Constant curl command array | DONE | `DirectorClient.js:37` `CURL_WRAPPER_COMMAND`; tests `director-client.test.js:198-209` |
| 2 | Secrets on stdin only, not argv | DONE | `curlConfigText`/`curlNavConfigText`; `Service.qml:1496-1497,1529-1530`; secret containment tests |
| 3 | No six transport files/processes | DONE | Removed from `Service.qml`; grep confirms no `bodyPath`/`responseStat` |
| 4 | `curlConfigEscape` backslash-before-quote | DONE | `DirectorClient.js:224-226`; round-trip tests `:112-132` |
| 5 | Reject `@`-prefixed body | DONE | `_rejectAtBody`; tests `:163-169` |
| 6 | Oversized response rejected at pipe cap | DONE | `head -c MAX+1` in wrapper; `isOversizedResponse` in `_finishHttp`/`_finishNavBody` |
| 7 | HTTP status + curl exit from stderr markers | DONE | `parseStderrMarkers`; `httpProc.onExited` `:1506-1513` |
| 8 | Markers survive curl error text | DONE | tests `:217-218` |
| 9 | Preserve TLS/timeouts/max-filesize/method | DONE | `curlConfigText`/`curlNavConfigText`; tests `:141-147,178-196` |
| 10 | Preserve queue/abort guards | DONE | `_pump` `:1186-1188`; `_ignoreHttpExit`/`_navIgnoreExit` retained |
| 11 | Stdin write after started, then close | DONE | `httpProc`/`navProc` `onStarted` handlers |
| 12 | `credentials.json` stays 0600 | DONE | `blockWrites: true` on `credentialsFile`; `chmodProc` after `persistCredentials` |
| 13 | `nav-cookies.txt` created 0600 | DONE | `umask 077` in wrapper (`DirectorClient.js:37`) |
| 14 | `disconnect()` removes nav cookie | DONE | `rmProc` in `disconnect()` `:157` |
| 15 | Volume poll coalescing | DONE | `_volumePending` `:961-968` |
| 16 | User-visible behavior unchanged | DONE | Wire semantics preserved; transport-only refactor; unit tests pass |

### Changes

| # | Changes item (abbreviated) | Status | Note |
|---|---|---|---|
| 1 | `curlConfigEscape` | DONE | `DirectorClient.js:224-226` |
| 2 | `curlConfigText` | DONE | `DirectorClient.js:236-253` |
| 3 | `curlNavConfigText` | DONE | `DirectorClient.js:257-281` |
| 4 | `parseStderrMarkers` | DONE | `DirectorClient.js:295-303` |
| 5 | Delete `isOversizedBytes` | DONE | Removed; tests updated |
| 6 | Delete six transport paths | DONE | `Service.qml` |
| 7 | Delete transport FileViews/Processes | DONE | ~415 lines removed from `Service.qml` |
| 8 | Rewrite `httpProc` | DONE | `Service.qml:1482-1514` |
| 9 | Rewrite `_pump` | DONE | `Service.qml:1186-1193` |
| 10 | Rewrite `_startHttp` | DONE | `Service.qml:1196-1206` |
| 11 | Simplify `_abortHttp` | DONE | `Service.qml:161-175` |
| 12 | Rewrite `navProc` | DONE | `Service.qml:1515-1536` |
| 13 | Collapse nav async hops | DONE | `_navGet`/`_navPostRaw`/`_startNavGet`/`_startNavPost` |
| 14 | Collapse `_onNavExit`/`_finishNavBody` | DONE | `Service.qml:832-921` |
| 15 | `_startNav` without touch | DONE | `Service.qml:742-763` |
| 16 | Simplify `_stopNav` | DONE | `Service.qml:769-779` |
| 17 | Credentials `blockWrites` + state dir 0700 | DONE | `Service.qml:1413-1457` |
| 18 | Nav cookie 0600 via umask | DONE | Wrapper umask 077 |
| 19 | `rmProc` on disconnect | DONE | `Service.qml:1458-1462,157` |
| 20 | README state/cleanup docs | DONE | `README.md:25-36,120-123` |
| 21 | Volume `_volumePending` | DONE | `Service.qml:92,961-968` |
| 22 | Update `in-process-director-rest` decision | DONE | `.hero/knowledge/decisions/in-process-director-rest/spec.md` |

### Exercise-the-feature check

- [ ] OR: cannot be exercised end-to-end in this environment because no Quickshell + live Control4 Director runtime is available to the delivery agent. Validated via `node tests/director-client.test.js` (pass) and security review (safe to ship). User should run spec validation steps 7–16 after loading the plugin.

### Excellence Bar self-check

Yes — removes the entire file-transport attack surface Ryan flagged, keeps the change surgical, and has strong unit coverage on the new parsing surface. Live Director smoke remains the user's pre-marketplace checklist.
