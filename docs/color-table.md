# Startup colour table

The original GetCTable(128) contract is measured by
`tools/mac_ctable.lua` and checked by `tools/check_ctable.py`.
Native implementation remains M2.1c3c2c5b2c2b3c2. Full palette realization
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
mutation counts. The syntax/literal audits cover all 45 maintained Mac scripts.
This reference prerequisite changes no native behavior; the production stop is
still GetCTable at Engine+$110E. The implementation must preserve detach/reload
ownership and seed identity, with named stops for unsupported forms.
