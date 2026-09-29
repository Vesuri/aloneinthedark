# Apple Event startup registration

M2.1c3c2c5b2c2b3a measures the original four calls and a separate table fixture.
Native registration is still pending in M2.1c3c2c5b2c2b3b. Event delivery remains
M3.4; callbacks must run at user-mode safe points, never from an interrupt.

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
