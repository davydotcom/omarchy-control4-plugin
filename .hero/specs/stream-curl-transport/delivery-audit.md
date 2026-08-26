# Delivery audit — stream-curl-transport

**Audited:** `git diff HEAD` (uncommitted working tree)
**Verdict:** SHIP
**Surface:** noteworthy

## Acceptance criteria

- [✓] AC-1 constant curl command — `DirectorClient.js:37`; tests `:198-209`
- [✓] AC-2 secrets on stdin only — `curlConfigText`/`curlNavConfigText`; `Service.qml:1496-1530`
- [✓] AC-3 no transport files — six paths/FileViews/Processes deleted from `Service.qml`
- [✓] AC-4 escape order — `DirectorClient.js:224-226`; round-trip tests
- [✓] AC-5 `@` body rejected — `_rejectAtBody`; tests `:163-169`
- [✓] AC-6 oversized pipe cap — wrapper `head -c`; `isOversizedResponse` in finish paths
- [✓] AC-7 stderr markers — `parseStderrMarkers`; `httpProc.onExited`
- [✓] AC-8 markers with curl noise — tests `:217-226`
- [✓] AC-9 wire behavior preserved — config builders + tests `:141-196`
- [✓] AC-10 queue/abort guards — `_pump`, `_ignoreHttpExit`, `_navIgnoreExit`
- [✓] AC-11 stdin lifecycle — `onStarted` write+close on both procs
- [✓] AC-12 credentials 0600 — `blockWrites: true`; `chmodProc`
- [✓] AC-13 nav cookie 0600 — `umask 077` in wrapper
- [✓] AC-14 disconnect rm cookie — `rmProc` in `disconnect()`
- [✓] AC-15 volume coalescing — `_volumePending`
- [~] AC-16 behavior unchanged — transport-only; unit tests pass; live Director smoke not run in delivery environment

## Changes

- [✓] Items 1–22 — all present in diff; knowledge doc amended

## Open items (if any)

- AC-16 / exercise — manual Quickshell + Director validation (spec steps 7–16) deferred to user pre-marketplace resubmit. Concrete reason: no live Director in CI/agent environment.

## Audit notes

- Security review: safe to ship; Ryan Hughes findings 1–4 addressed.
- Residual: pre-upgrade `nav-cookies.txt` at 0644 not auto-fixed until disconnect/rm; operational note only.
- Navigator flow rewrite has no automated integration tests — highest manual QA risk.
