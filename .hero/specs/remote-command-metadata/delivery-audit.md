# Delivery audit — remote-command-metadata

**Audited:** `git diff -- DirectorClient.js tests/director-client.test.js` (working tree)
**Verdict:** SHIP
**Surface:** clean

## Acceptance criteria
- [✓] AC-1 Nav commands → navigation available — `DirectorClient.js:568-570` sets `hasNavigation` / `nav.*` from `MENU UP DOWN LEFT RIGHT ENTER`; test `dvd nav` (`tests/director-client.test.js:372`)
- [✓] AC-2 No commands → empty caps, no throw — `DirectorClient.js:557-559` returns `_emptyRemoteCapabilities()` for null/non-object; missing `commands` yields `[]` via `_asArray`; tests `null item`, `no commands` (`tests/director-client.test.js:404-405`)
- [✓] AC-3 Single-object `commands.command` → one-element list — `_asArray` + `_commandName` (`DirectorClient.js:512-527`, `560`); test `single object command` (`tests/director-client.test.js:409-410`)
- [✓] AC-4 SHALL NOT use name/model/manufacturer — `parseRemoteCapabilities` reads only `item.commands` and `item.capabilities`; test `name is not a gate` (`tests/director-client.test.js:406-407`)
- [✓] AC-5 Channel entry from capability flags, not `NUMBER_*` — `hasChannelUpDown` / `hasDiscreteChannelSelect` from `_truthyFlag` on capability keys (`DirectorClient.js:588-589`); digits set separately (`576-579`); dvd has digits and channel false (`tests/director-client.test.js:374`); cable flags true (`401`)
- [✓] AC-6 Absent `show_transport` is not false — empty shape starts `showTransport: null` (`DirectorClient.js:544`); only assigned when the key is present (`592-597`); test `c4z missing show_transport is not false` (`tests/director-client.test.js:392`)
- [✓] AC-7 `ON`/`OFF` → power flags — `DirectorClient.js:581-584`; test `dvd power` (`tests/director-client.test.js:375`)

## Changes
- [✓] `DirectorClient.js` — `parseRemoteCapabilities` + `hasRemoteCommand` — added after `_asArray` (`DirectorClient.js:508-633`); MSP/TuneIn parsers unchanged in this work
- [✓] `tests/director-client.test.js` — dvd / c4z / cable / empty / single-object / name-not-a-gate — fixtures and asserts at `tests/director-client.test.js:358-410`; `node tests/director-client.test.js` prints `ok` (exit 0)

## Open items (if any)

None.

## Audit notes

None.
