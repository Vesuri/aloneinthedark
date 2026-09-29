# Startup palette construction and binding

The original NewPalette request is measured by `tools/mac_palette.lua` and
validated by `tools/check_palette.py`. Native construction implements the measured startup form; activation and
device/video colour realization remain M2.7/M2.7a.
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
Raw captures and original data stay local.

## Native implementation and verification

NewPalette accepts the measured 256-entry form, usage `$000A`, tolerance zero,
and an indexed source table with flags zero. It allocates and copies the full
record and its four-byte private block, tracking their ownership separately from
Resource Manager handles. Unattached DisposePalette releases both allocations
and preserves the source. Attached/realized disposal, other constructor forms,
allocation failures and exhaustion of the 32-record ownership table stop loudly.
The ownership table is cleared when the zones are released.

`amiga/palette.gdb` observes the original request/return, captures all palette and
source bytes and reaches Misc1+$1296 SETWTITLE, with original MDRV absent.
`PALETTEPROBE=1` builds the CPU-executed twelve-case fixture; its read-only observer
is `amiga/palette_fixture.gdb`. Actual shutdown must return zero, close both
resource streams, remove Line-A and release both zones. No debugger writes or
original-code patches are used.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga PALETTEPROBE=1
(cd amiga && EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=palette_fixture.gdb ./diag_run.sh 120)
# Check a saved log with its actual terminal status and matching preserved dumps:
python3 tools/check_palette.py tmp/m2-palette-native-fixture-final.log --native \
  --fixture --status 0 --folder tmp/palette-native-fixture-final
make -C amiga clean
make -C amiga
(cd amiga && EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=palette.gdb ./diag_run.sh 120)
```

The constructor checks alone do not establish palette binding, activation, video
colour transfer or rendered-intro acceptance. Binding has separate checks below.

## Original default-palette binding [M]

`tools/mac_setpalette.lua` observes SetPalette at Engine+$1172. Original bytes
+$1166–$1173 are `4878FFFF2F2C00241F3C0001AA95`, SHA256
`a37e6695ed61b794457a22240ae74b278380251f2205ec46b1001a7afa0c7a82`.
The arguments are update=true, the constructed palette at A4+$24, and window
-1. The Boolean is the high byte of its stack word; the padding byte is not
an argument. The call pops ten bytes and preserves D3–D7/A2–A6.

SetPalette installs the handle in the default-palette binding (reference low
memory $DCC). GetPalette(-1), trap AA96, returns that same handle and pops its
four-byte argument. The 4,112-byte palette changes only byte 6 from $00 to $E0
(the word at +6 becomes $E002). All handle/body identities remain unchanged.
The separate private allocation remains four zero bytes. The full GDevice,
PixMap, logical CLUT, 307,200 physical framebuffer bytes and all 256 hardware
palette entries are unchanged. Binding does not establish palette activation.

The physical capture runs from MAME's periodic callback at stopped debugger
checkpoints, before the original call and before any subsequent scratch query.
It reads the full NuBus base $F9000A00 directly through Lua's program space.
Debugger logical `save` at that address aliases low memory in 24-bit mode;
an initial apparent pixel mutation was the $DCC binding itself, not video.
The probe logs both logical and physical reads to keep this distinction checked.
An initial query used AA90 (InitPalettes); it was rejected and replaced by AA96
with explicit opcode, input, result and stack readback. A nested debugger
condition failed to complete and was also rejected. No timeout counts as a pass.

Run the standard bounded headless MAME command with `tools/mac_setpalette.lua`,
then check the actual exit status and matching dumps:

```sh
python3 tools/check_setpalette.py tmp/m2-setpalette-reference-accepted.log --status 0
make host-tests
```

The accepted reference capture exits normally and passes original/live bytes,
argument, register/stack, binding, private-state and device/display comparisons.
All 47 Mac scripts pass syntax/literal checks and the host suite passes.
The checker rejects missing/duplicate completion, missing/timeout status,
wrong query opcodes, changed arguments/live bytes and incomplete pixel captures.
Evidence is `tmp/m2-setpalette-reference-accepted.log` and
`tmp/m2-setpalette-reference-host.log`; all raw dumps remain local.
The native implementation now accepts the measured startup binding: a newly
created 256-entry palette, window -1 and update=true. It records the default
handle without activating it, writes only palette byte 6, and clears the binding
when the zones are released. Uninitialized calls stop explicitly. Replacement/repeated bindings, other window/update
forms and disposal of a bound palette remain named stops pending their contracts.

`amiga/setpalette.gdb` and `tools/check_setpalette.py --native` check the original
call, exact paired palette contents apart from the private handle address,
unchanged GDevice/PixMap/CLUT and full logical screen storage, unchanged pending
palette and the current sixteen published copper colour moves, and original MDRV absence. The next
named stop is Misc1+$1296 `WINDOW MANAGER / SETWTITLE` (A91A). Existing preferences
reach it with 67 OS windows and 121 completed services (fresh: 93 and 129); original resource bodies
are 31 / 130,660 bytes, with overlay bodies unchanged at 31 / 80,800.

The CPU palette fixture additionally constructs and binds a live palette before
actual runtime shutdown; its observer requires the binding to clear alongside
zone, resource-stream and Line-A cleanup. All twelve ownership cases and actual
shutdown pass. The fixture needed InitGraf/InitFonts/InitWindows before binding;
instrumentation exposed its initial depth-zero setup and the inherited silent
fallthrough, now rejected explicitly. Its new assembly-label checks use addresses
because GDB resolved the labels as byte values. Rejected captures remain local.

The final 68020 production build passes no-float and 78-symbol audits. All
nineteen startup observers and paired contracts, fresh/existing preference
variants, clean boot/resource-read and the full host suite pass. The final
executable is unchanged through the complete final startup/preference suite.
Prior timeouts and an interrupted run were rejected; only normal exits with
positive markers count. Original preferences are restored. Evidence:
`tmp/m2-setpalette-final-startup-suite.log`, `tmp/m2-setpalette-host-final.log`,
`tmp/m2-setpalette-fixture-final.log`, `tmp/m2-setpalette-boot.log`,
`tmp/m2-setpalette-resource-read.log`, and `tmp/m2-setpalette-final-low.log`.

```sh
python3 tools/check_setpalette.py tmp/m2-setpalette-final-low.log --native --status 0 \
  --folder tmp/setpalette-native-accepted
python3 tools/check_palette.py tmp/m2-setpalette-fixture-final.log --native --fixture \
  --status 0 --folder tmp/setpalette-fixture-final
```

This is binding and ownership acceptance. Palette activation, video colour
transfer, eight-plane output and rendered intro acceptance remain M2.7/M2.7a and
the other queued graphics work.
