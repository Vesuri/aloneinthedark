# Startup colour table

The original GetCTable(128) contract is measured by
`tools/mac_ctable.lua` and checked by `tools/check_ctable.py`.
Native GetCTable implements both reached application table forms. Full palette realization
and video colour transfer remain M2.7/M2.7a.

## Original request and mutations [M]

Engine+$110A contains `3f3c0080aa18`: push ID 128, GetCTable. The result slot is
initially nil. At +$1110, SP advances by two bytes and holds a nonnil handle.
D3–D7/A2–A6 are preserved; D0–D2/A0–A1 are volatile. The captured return has
D0/A0 equal to the handle. The handle contains 2,056 bytes: a four-byte seed,
flags `$8000`, size 255, and 256 eight-byte colour entries. All bytes after the
seed equal the application's original `clut` 128. The seed is newly generated;
its observed numeric value is not a constant to bake into the port.

Engine+$1122 clears the table flags. Its loop at +$112C–+$1148 replaces every
entry's value word with its index, 0–255. At +$114A, all RGB components and the
seed are unchanged. NewPalette follows at +$1158, outside this capture's scope.
The checker fingerprints Engine+$1108:$1168:
`36c034625d8e96eef1f4369b65be8f9725950c9b367a845015826f6754e01bbf`.
It also verifies live call bytes and both complete table dumps.

## Ownership fixture [M]

Optional fixture mode runs 21 calls after the original mutation loop and exits
without resuming the game. Its inputs occupy scratch stack memory; original
instructions are unchanged. The observed behavior is:

- The original returned handle is 2,056 bytes, unlocked, nonpurgeable and no
  longer a resource handle (`HGetState=0`, `GetResAttrs` reports `resNotFound`).
- GetResource('clut',128) loads a different handle with the exact original bytes
  and resource state `$20`.
- A second GetCTable(128) returns **that same loaded resource handle**, assigns
  a new seed and clears its resource state. Thus it detaches the loaded resource;
  it does not copy a resident resource while leaving that handle in the map.
- Changing a red component in this second table changes the previously observed
  resource alias, because they are the same handle. A third GetCTable reloads
  the unmodified original bytes in a distinct handle and detaches that one too.
- A later GetResource loads another distinct, resource-owned handle with the
  original bytes. Disposing the second table invalidates its old resource alias
  (`GetHandleSize=-111`), while the original and third tables retain size 2,056.
- Interleaved GetCTSeed calls show one seed consumed per successful GetCTable.
  Relative to the original seed S: the first GetCTSeed returns S+1, the second
  table has S+2, the next GetCTSeed returns S+3, the third table has S+4, and the
  final GetCTSeed returns S+5.
- GetCTable(32766), a missing table on the reference, returns nil with ResError
  zero, leaves MemError unchanged and consumes no seed. This does not establish
  support for system-generated tables or all missing-ID forms.

The checker verifies input readback, stack cleanup, nonvolatile registers,
handle identities/state, resource and memory errors, exact dumps and seed
relationships. GetResAttrs' failed result word is unspecified; only its error
is accepted, not the incidental word observed in the result slot.

## Reproduction and scope

Run `tools/mac_ctable.lua` using the bounded headless command in
[mac-reference-loop.md](mac-reference-loop.md). Normal mode only observes the
original request and mutation loop; set `AITD_CTABLE_FIXTURE=1` for the separate
ownership fixture. Require status zero, the positive completion marker and
`Exited via the debugger`. Preserve each run's dumps before the next run.

```sh
python3 tools/check_ctable.py tmp/m2-ctable-reference-final.log --status 0
python3 tools/check_ctable.py tmp/m2-ctable-ownership-final.log --status 0 \
  --fixture --folder tmp/ctable-fixture-accepted
make host-tests
```

Logs, raw dumps and original resource data remain local-only. The checker rejects
missing/duplicate captures, timeout/missing status, changed inputs and incorrect
mutation counts. The syntax/literal audits cover the maintained Mac scripts.
The native production observer is `amiga/ctable.gdb`. It checks the original
call and mutation loop, exact returned bytes, detachment from the resource map,
and the next named stop: Engine+$1158 `PALETTE MANAGER / NEWPALETTE`. Original
MDRV stays absent. The table adds one bounded resource read (2,056 bytes) and
one completed user service/window to startup.

`CTABLEPROBE=1` builds the CPU-executed ownership fixture in `CTableProbe.s`.
Its read-only observer is `amiga/ctable_fixture.gdb`; debugger writes are not
used. The same 21 Mac cases check stack/register preservation, bytes, seeds,
aliases and errors, then verify actual native shutdown closes both resource
streams, removes Line-A and returns zero. A disposed master slot now returns
`GetHandleSize=-111`; arbitrary non-handle pointers still stop. Host heap checks
cover free-slot classification, live handles, null, pointers and misalignment.

Supported GetCTable inputs use application IDs (128 or higher), enabled resource
loading, and a clean unlocked table with 256 entries: either 2,056 bytes with
flags `$8000`, or 2,064 bytes with flags `$4000`. Resource state `$20` or the
purgeable resource state `$60` is accepted. The loaded handle is detached, receives one fresh seed and
becomes caller-owned. Missing application tables return nil without consuming a
seed or changing MemError. System-generated IDs, disabled loading, dirty handles
and other table layouts remain named GetCTable stops with the requested ID.
This does not implement palette realization or establish rendered acceptance.

```sh
# Clean when switching between the fixture and production configurations.
. amiga/env.sh
make -C amiga clean
make -C amiga CTABLEPROBE=1
(cd amiga && EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=ctable_fixture.gdb ./diag_run.sh 120)
# Check the saved observer log with its actual terminal status:
python3 tools/check_ctable.py tmp/m2-ctable-native-fixture-final.log --native \
  --fixture --status 0 --folder tmp/ctable-native-fixture-final
make -C amiga clean
make -C amiga
(cd amiga && EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=ctable.gdb ./diag_run.sh 120)
```

The native fixture first exposed the missing disposed-alias error. That rejected
run is retained locally; the corrected run completes all 21 cases with status
zero. Capture checks reject missing/duplicate records, timeouts, changed inputs,
wrong mutations, ownership, errors and seed sequences.


## Colour-table 129 [M]

Dark2+$1FD6 contains `42973f3c0081aa18`: clear the result slot, push ID 129,
GetCTable. The original resource has ctFlags $4000, ctSize 255 and a 2,064-byte
body: 256 entries followed by eight zero bytes. GetCTable preserves every byte
after the seed, including the trailing bytes. It generates a fresh seed,
detaches the loaded handle and clears its purgeable/resource state. The original
returns D0/A0 equal to the handle, preserves D1–D7/A2–A6, and pops two bytes;
A1 is scratch. The native path preserves A1 in addition.

Six isolated Mac fixture calls establish the 2,064-byte size, detached state
zero, GetResAttrs error -192, and a later distinct GetResource handle containing
the exact original body with state $60 (purgeable resource). The native observer
checks the owned allocation size and Mac-visible state without executing guest
fixture writes. The heap's internal allocated bit is separate from that state.

```sh
python3 tools/check_ctable129.py tmp/m2-ctable129-reference.log --status 0 --native tmp/m2-ctable129-native-final.log --native-status 0
python3 tools/check_ctable.py tmp/m2-ctable129-original-table-regression.log --status 0 --native
```

`mac_ctable129.lua` captures the original request and ownership fixtures;
`ctable129_call.gdb` is included in the combined native startup observer.
`ctable129.gdb` is its standalone diagnostic wrapper. Both tables pass exact
body checks and ABI/ownership checks. The following NewPalette at Dark2+$201C also accepts this larger source; see
[palette.md](palette.md#palette-from-colour-table-129).
