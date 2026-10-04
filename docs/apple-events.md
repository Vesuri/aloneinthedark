# Apple Event registration and launch delivery

M2.1c3c2c5b2c2b3a measures the original four calls and a separate table fixture.
Native registration and lookup pass M2.1c3c2c5b2c2b3b acceptance. Native launch
delivery now calls the original handler at a user-mode safe point. M3.4 still
requires the ten-minute manual first-floor session.

## Launch delivery [M]

Finder supplies one high-level EventRecord: what 23, class `aevt`, ID `oapp`
in the `where` field, modifiers zero. The timestamp is platform-specific.
Engine+$21E8 calls AEProcessAppleEvent (`$A816`, selector `$021B`), consuming
the four-byte EventRecord pointer and returning OSErr zero in the reserved
word and D0. D3–D7/A2–A6 survive. The registered Engine+$04EA handler takes
Pascal `(event, reply, refCon)`, with refCon zero and the original A5. It clears
the result word and returns with `rtd #12`; including the return PC, SP advances
16 bytes. The event descriptor has type `aevt` and an owned data handle; the
reply is `null` with no handle.

The port queues this no-document launch event on `oapp` registration and
delivers it once through the high-level-event mask (`$0400`). AEProcess validates
the queued packet and prepares owned descriptors. After the service bridge has
consumed its parked frame and cleared its active flag, the Pascal bridge calls
the original handler in user mode. Ordinary nested traps may use the service
bridge; recursive event processing remains unsupported. The result reaches the
original caller and the descriptor handle is disposed before returning.

Descriptor data is manager-owned opaque storage. The native launch payload holds
its class/ID; it does not reproduce the Mac's private transport packet. The
measured launch handler never inspects that payload. Document-open parameters,
external event transport, quit delivery and unmeasured descriptor selectors
remain unsupported named stops; this is not general Apple Event support.

`tools/mac_apple_delivery.lua` observes unchanged original code and input.
`amiga/apple_delivery.gdb` checks the same original caller/handler on a clean
`MENUPROBE=1 PROBES=1` build, with `DIAG_AUDIO=1 EXTRA_ARGS=--warp_mode=0`.
It also observes all five implemented SANE selectors in the integrated route
(30 calls), and normal Save/Load/Quit restoration. Accepted captures are
`tmp/m3-toolbox/mac-apple-delivery.log` and `native-apple-gdb.log`, with both
runner exit statuses zero. Reproduce the paired check with:

```sh
python3 tools/check_apple_delivery.py tmp/m3-toolbox/mac-apple-delivery.log \
  tmp/m3-toolbox/native-apple-gdb.log --reference-status 0 --native-status 0
```

The observer and checker require single delivery, exact Pascal stack cleanup,
ten preserved registers, safe callback context, result zero, descriptor
ownership, shutdown reset and positive SANE coverage. Timeouts never pass.

For the outstanding manual acceptance, clean and build `INGAME=1 PROBES=1`
without menu/gameplay input fixtures. Run:

```sh
DIAG_AUDIO=1 EXTRA_ARGS=--warp_mode=0 GDBSCRIPT=manual_play.gdb \
  amiga/diag_run.sh 900
```

The read-only observer records `MANUAL_READY` after boot input has stopped,
and elapsed Mac ticks when the owner quits (36,000 ticks is ten minutes).
It stops immediately on a named failure. Its duration record does not prove
first-floor coverage or rendered stability: those still need the owner's manual
observations. Normal quit must also pass OS restoration checks. A timeout or an
unattended run cannot close M3.4.

## Original calls [M]

Engine+$1038/+$1056/+$1074/+$1092 execute Pack8 (`$A816`) with D0.W `$091F`.
The four event IDs under class `aevt` are, in order, `oapp`, `pdoc`, `odoc`,
`quit`. Their callbacks are A5+$AC2, A5+$AC2, A5+$AD2, A5+$ACA respectively.
All use refCon zero and the application table (`isSysHandler=false`).

At entry SP points to an 18-byte argument block: Boolean byte plus unspecified
padding byte, refCon long, handler pointer long, event ID long, event class long.
The result word follows. All four return zero in that slot and advance SP by 18.
D3–D7 and A2–A6 are preserved. D0–D2/A0–A1 are volatile. In particular the
first call’s Boolean padding byte is not zero, so testing the whole word is incorrect.

The input fork's Engine bytes `$1000:$1096` have SHA-256
`08e0465b1dca0398dd3c55550ceb5b09e10c36360dc48f6b02630d7851e5438e`.
The checker verifies this fingerprint and live selector/trap words for each call.
No original instructions or inputs are changed in normal capture mode.

## Table fixture [M]

After all four original returns, optional fixture mode runs 17 calls from scratch
stack memory, then exits. It does not resume game execution. It verifies:

- Exact lookup (`$0921`) of all four original callback/refCon pairs.
- A missing class/ID returns `$F94B` (−1717), leaving both output longs unchanged.
- Installing a scratch application entry succeeds; lookup returns its exact state.
- Reinstallation replaces refCon, then handler, without losing the other value.
- Another class and the separate system table do not find the application entry.
- Null and odd handlers return `$FFCE` (−50) and preserve the prior entry.
- Every call consumes 18 bytes and preserves D3–D7/A2–A6. Lookup writes only its
  two four-byte outputs; adjacent sentinels remain intact. Failed lookups leave
  the supplied outputs untouched.

This does not measure wildcard dispatch, system-table installation, handler
removal, capacity exhaustion or event delivery. Unsupported native forms must
remain named stops until implemented and verified. Apple documents registration
replacement and separate tables in [AEInstallEventHandler](https://developer.apple.com/documentation/coreservices/1448596-aeinstalleventhandler).
Selector values are from Apple's *Inside Macintosh: Interapplication
Communication*, [chapter 4, assembly summary](https://dev.os9.ca/techpubs/mac/pdf/Interapplication_Communication/Responding_to_AEs.pdf),
printed page 4-129; the Mac runs establish the behavior above.

## Reproduction

Run `tools/mac_apple_events.lua` with the headless MAME command from
[mac-reference-loop.md](mac-reference-loop.md). Set `AITD_AE_FIXTURE=1` for the
separate fixture. Require process exit zero, `Exited via the debugger`, and the
appropriate positive marker; a timeout is never a pass.

```sh
python3 tools/check_apple_events.py tmp/m2-apple-events-reference-final.log --status 0
python3 tools/check_apple_events.py tmp/m2-apple-events-fixture-final.log --status 0 --fixture
make host-tests
```

The checker rejects altered results, inputs, pointers, sentinels, selector/trap
words, missing markers, duplicate captures and missing/nonzero process status.
The fixture run also passes syntax validation of all 44 maintained Mac scripts;
the host suite includes their generated-literal audit. Captures stay local-only.

## Native implementation and acceptance

`AppleEventHandlers` owns up to 32 application registrations, keyed by exact
class/ID. It stores the original callback address and refCon, replaces matching
entries, and resets on application preparation and resource-fork release. It
never invokes callbacks. Capacity exhaustion, system installation, wildcard
forms, unsupported selectors and invalid lookup output pointers remain named
stops. Missing exact lookups preserve caller outputs, including system-table
queries (the port installs no system handlers).

`amiga/apple_events.gdb` observes the four original calls, installed table and
GetCTable stop at Engine+$110E, with original-byte, resource/window/service and
original-MDRV absence guards. `APPLEEVENTPROBE=1` builds a separate CPU-executed
fixture, seeding its own four entries before the 17 measured calls; those seed
calls are not presented as original-game execution. `APPLEEVENTFORM=1..6` selects
CPU-generated unsupported inputs; `apple_events_unsupported.gdb` verifies their
readback and unchanged state at the named stop. Clean when changing probe flags.

The first attempt to drive the native fixture by changing debugger registers
failed and was rejected. A separate attempted memory-write fixture timed out and
was also rejected. Readback instrumentation then proved that this FS-UAE debugger
ignores register and memory writes. All maintained Apple Event observers now use
read-only GDB operations; test arguments are generated by CPU-executed code.

```sh
python3 tools/check_apple_events.py tmp/m2-ae-native-cpu-fixture-final.log --status 0 --fixture-only
# After a clean production build:
python3 tools/check_apple_events.py tmp/m2-ae-native-final-clean.log --status 0 --native
```

Host sanitizer checks cover table capacity, replacement, invalid pointers,
namespace isolation and reset. Native fixture acceptance covers stack/registers,
input readback, outputs and their bounds against the independent Mac capture.
The diagnostic fixture is not linked into production. Native startup still
stops before WIND 128; this is not window, palette, event-delivery or M2 acceptance.

Final acceptance also proves real shutdown clears the table, closes the resource
streams and returns zero from native main. All six unsupported-input runs stop
without changing table/result state. Fresh and both existing preference inputs
pass the original registrations and next-stop checks. All 16 startup observers
and paired contracts, the full host suite, exact A5 globals, clean boot/resource
reads, file-write and eight resource-exit phases pass. The first file-write run
hit its 120-second limit and was rejected; an unchanged clean retry passed under
a 240-second bound. Original preferences and saves are restored.

Native counters remain 64/90 windows and 118/126 completed services for
existing/fresh preferences, 28 original resource reads / 123,387 bytes and 31
overlay bodies / 80,800 bytes. No original MDRV body is resident. Production
no-float and 77-symbol probe audits pass; other processors remain deferred.
