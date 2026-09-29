# Startup palette construction

The original NewPalette request is measured by `tools/mac_palette.lua` and
validated by `tools/check_palette.py`. Native construction remains
M2.1c3c2c5b2c2b3d2; activation and device/video colour realization remain M2.7/M2.7a.
Vette has GetNewPalette resource loading but no NewPalette constructor to reuse.

## Original request and returned record [M]

Engine+$114A clears the result slot, pushes 256, the detached colour-table handle
at A4+$20, and the long `$0000000A`, then executes `AA91` at +$1158. The stack
contains tolerance 0, usage `$000A` (pmTolerant + pmExplicit), source handle,
entry count 256 and the nil result slot. At +$115A, SP has advanced ten bytes
and holds a nonnil palette handle. D3–D7/A2–A6 are preserved; D0–D2/A0–A1 are
volatile. The original bytes from +$114A through +$116F have SHA256
`9c49481e014b240b50e4f2c2441e3382ae48f8955171df072cd946e7ae3b5d30`.
Both the original fork and live instruction bytes are checked.

The palette allocation is 4,112 bytes: a 16-byte header and 256 16-byte entries.
Each entry contains the matching source RGB16 values, usage word `$000A`,
tolerance word zero and six zero private bytes. The complete source table is
unchanged. Its index words already contain 0–255 and its flags are zero from
the preceding original mutation loop.

The header contains entry count 256, then bytes `00000000000200000000`, then
a handle at offset 12. That private handle owns a separate four-byte zero block.
Its absolute address is runtime-dependent. The measured private header bytes
are initialization evidence, not an interpretation of later palette realization
or attachment state.

## Ownership and lifecycle fixture [M]

`AITD_PALETTE_FIXTURE=1` runs twelve scratch-code calls after capturing the
original return, then exits without resuming original execution. It establishes:

- Palette and source handles are distinct, unlocked and nonpurgeable. Their
  allocated sizes are 4,112 and 2,056 bytes respectively; the private block is
  four bytes. GetResAttrs on the palette reports -192 (not a resource); its
  failed result word is unspecified.
- Changing the first source red word to `$1234` leaves the entire palette
  unchanged. Changing the first palette red word to `$5678` leaves the source
  unchanged. Full dumps check that these are the only mutations.
- DisposePalette pops four argument bytes, preserves D3–D7/A2–A6 and returns
  D0=0/MemError=0 with ResError unchanged. It frees both palette and private
  handles: subsequent GetHandleSize calls return -111/MemError=-111 for each.
  The source retains its size and exact mutated contents.

The checker verifies all actual fixture inputs, order, stack cleanup, preserved
registers, memory/resource errors, exact body extents and independent ownership.
No original instructions or on-disk resources are modified. These captures do
not establish nil palettes, other counts/usages/tolerances, allocation failures,
window attachment, activation or rendered output; those remain unsupported until
implemented with evidence.

## Reproduction and accepted evidence

Use the bounded headless MAME command in [mac-reference-loop.md](mac-reference-loop.md)
with `tools/mac_palette.lua`. Omit the fixture variable for the original capture;
set it to 1 for lifecycle checks. Preserve each run's `tmp/palette-reference-*.bin`
files before another run overwrites them. Require actual status zero and the
matching positive completion marker; timeouts never pass.

```sh
python3 tools/check_palette.py tmp/m2-palette-reference-accepted.log --status 0 \
  --folder tmp/palette-reference-accepted
python3 tools/check_palette.py tmp/m2-palette-ownership-accepted.log --fixture \
  --status 0 --folder tmp/palette-ownership-accepted
make host-tests
```

Both accepted capture modes exit normally. All 46 maintained Mac scripts pass
syntax and literal audits. The checker rejects missing/duplicate records,
timeouts/missing status, changed request arguments and changed live bytes.
Its initial broad error-word rejection caught missing emulator floppy sound
samples; validation now distinguishes those startup messages from capture errors.
The native executable remains at Engine+$1158 NEWPALETTE, so the previous native
regression evidence remains applicable. Raw captures and original data stay local.
