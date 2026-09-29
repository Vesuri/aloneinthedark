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


## Window palette state and first client clear [M]

MoveWindow at Misc1+$0FAC changes palette byte 6 from $E0 to $C0 and long +8
from zero to one. Private data, device records, CLUT and physical pixels remain
unchanged. ShowWindow at +$10E6 changes each entry's private word at +10 to
$800A, realizes the device CLUT, and writes its new seed to the private allocation.
The private header fields' broader meaning is not inferred from these values.

The native initial device table contains the complete measured system palette.
Its seed-independent SHA-256 is
`8bde63f387a037ed68a9a1b659571162634834d079dd17e593df446b53aabb19`.
The realization helper assigns explicit non-endpoint colours and retains
protected white/black duplicate slots without hardcoding game indices. For the
original palette these are slots 1, 15 and 191, plus endpoints 0 and 255.
Sanitizer fixtures cover different duplicate positions, malformed inputs,
repeat-realization rejection and mutation atomicity. Unsupported forms stop.

Original `wctb` 128/131 supply black client backgrounds. Part zero is the
content background, as documented in Apple's
[Window Color Table reference](https://dev.os9.ca/techpubs/mac/Toolbox/Toolbox-295.html).
ShowWindow clears only the global client rectangle (160,150)–(480,350), marks
it dirty, and updates visibility/hilite state. No Mac chrome is drawn.
The reference's software arrow explains 43 white pixels inside the otherwise
black client area; the checker requires its complete measured 16×16 pattern.
Native hardware cursor presentation remains separate.

The MoveWindow helper bytes +$0F94–$0FB3 have SHA-256
`ac7b10b44ab334076f90cb605411a22f4d82b7cb09e3e91470942a38dea74d5a`;
the ShowWindow call +$10E2–$10E7 has SHA-256
`fbb2f10eed30f3a3ccbb42f116e135a329de15963a39307a540398422a54a59c`.
`tools/mac_window_palette_state.lua`, `amiga/window_palette_state.gdb` and
`tools/check_window_palette_state.py` verify original/live bytes, arguments,
stack/register preservation, full palette/CLUT transitions, private seed
consistency, loaded window colours and client pixels. Only opaque addresses and
allocated seeds are normalized, after identity/seed relationships are checked.
The helper also reproduces the complete captured Mac transition byte-for-byte.

Use the documented bounded headless MAME command with the Lua observer, and
`GDBSCRIPT=window_palette_state.gdb ./diag_run.sh 300` for the native capture.
Preserve captures before subsequent runs. Supply actual runner statuses:

```sh
python3 tools/check_window_palette_state.py REFERENCE.log NATIVE.log \
  --reference-status 0 --native-status 0
```

All 21 startup observers and paired contracts, existing/fresh/low preference
variants, host tests, clean boot/resource-read and no-float/78-symbol audits
pass. The clean executable matches the suite's executable. A5 remains exact
across 75,616 bytes; low-memory validation/applied counts remain 58/55.
Existing/fresh runs complete 70/96 OS windows and 124/132 services; original
resource bodies total 34 / 130,788 bytes, overlay bodies 31 / 80,650. Original
preferences are restored. The checker rejects timeouts, missing completion,
CLUT/palette/private-seed corruption and writes outside client content.

Accepted evidence: `tmp/m2-window-state-reference-cursor.log`,
`tmp/m2-window-state-dirty-pair.log`, `tmp/m2-window-state-final-suite.log`
(all native observers), `tmp/m2-window-state-final-paired.log` (paired checks),
`tmp/m2-window-state-final-preferences.log`, `tmp/m2-window-state-final-host.log`,
`tmp/m2-window-state-boot.log` and `tmp/m2-window-state-resource-read.log`.
The suite's first paired pass rejected a zero-padding mismatch in its device
checker; the corrected expectation passed against the same successful capture.

The display path now consumes the dirty rectangle and queues the first AGA
frame before window binding; see [aga-display.md](aga-display.md). Rendered
intro acceptance remains pending. The original subsequent
SetPalette call at Misc1+$10FA is measured to leave the already-realized state
unchanged, with GetPalette(window) returning the default handle. Its instruction
range +$10E8–$10FB has SHA-256
`41c4b669d4c6ce8e4889fb470c9a76c753d11fe61bd4e1285be68a20b6db8a23`.
The native window binding now assigns the already-active default handle and
records the update flag. It accepts only a visible front window with no explicit
binding and a valid realized palette/private seed; unmeasured forms stop loudly.
It preserves all palette, private, window, device, logical pixel and copper data.
The next original call is ActivatePalette at Misc1+$1100, currently unsupported.

`tools/mac_window_binding.lua` captures the original call and executes a scratch
GetPalette(window) query through the Mac CPU to verify its result.
`amiga/window_binding.gdb` records original arguments and live relocated bytes,
then captures the native service after the dispatcher publishes the preceding
client clear. This boundary matters: capturing at dispatcher entry would count
the prior clear as a SetPalette display mutation. The observer checks that no
binding exists yet at its service boundary.

`tools/check_window_binding.py REFERENCE.log NATIVE.log --reference-status 0
--native-status 0` checks the actual runner statuses, original bytes including
the relocated A5 operand, stack/register contract, full state preservation,
complete palette/CLUT pairing, binding identity, and next named stop. Captures
remain local under `tmp/windowpalette-*`. The accepted service capture is
`tmp/m2-window-binding-native-final.log`, paired with
`tmp/m2-window-binding-reference.log`; both exited normally. Rejection checks
cover timeout status, missing completion, incorrect query results, changed
original instructions and CLUT corruption. Broader activation remains queued.


Window-binding regression evidence: `tmp/m2-window-binding-regressions.log`
(default binding, client clear, original startup, native driver and first AGA
frame with paired checkers), `tmp/m2-window-binding-preferences.log`,
`tmp/m2-window-binding-host-tests.log`, and the corresponding `boot` and
`resource-read` logs. All exit zero with positive completion. A5 matches all
75,616 bytes; resource counts and 70/96 OS-window totals remain unchanged.
Original preferences are restored. The activation-checkpoint production SHA-256 is
`c2fbc390d5d3591733342635ea5652edd57e6ed23cecf02454504e34ddebe181`.


## Already-realized window activation

The original Misc1+$1100 ActivatePalette request contains the window pointer
and pops four argument bytes. Its original +$10FC–$1101 instruction range is
`2F2C0008AA94`, SHA-256
`37df3a67690b54fed3ec5919c7018e887f19a8b44f900795abb6d548120a2370`.
The Mac's palette, private seed, window, window PixMap, device, main PixMap,
logical CLUT, physical pixels and hardware colours are all unchanged. ShowWindow
has already realized the bound palette; this call does not allocate colours.

The native service accepts the measured visible front window with update-enabled
binding to its already-active default palette, validated ownership, realized
header and matching private/device seed. It preserves the complete state and
queues no additional frame. Other eight-bit activation states remain explicit
stops rather than falling through Vette's sixteen-colour allocator.

`mac_window_activation.lua`, `window_activation.gdb` and
`check_window_activation.py REFERENCE.log NATIVE.log --reference-status 0
--native-status 0` pair original bytes, stack/registers, binding and complete
before/after captures. The accepted reference/native calls are in
`tmp/m2-window-activation-reference.log` and
`tmp/m2-window-activation-native-final.log`, both normal exits with positive
completion. Captures stay under `tmp/activation-*`. Rejection checks cover
failed/timeout status, missing completion, changed bytes, an extra publication
and palette corruption. The subsequent ShowHide service now passes without
changing palette or viewport pixels; SetGWorld also passes, and the next stop is TickCount at Dark+$41F4.


Activation regressions: `tmp/m2-window-activation-regressions.log` contains six
bounded startup observers and paired checks; `tmp/m2-window-activation-host-tests.log`,
`tmp/m2-window-activation-preferences.log`, and the `boot`/`resource-read` logs
also pass. Original preferences are restored. A5 matches 75,616 bytes exactly;
resource and system-window totals are unchanged. No-float and 78-symbol audits
pass. The activation-checkpoint production SHA-256 is
`ef4492241f7f0fa1f8e8c519c9708ac08e5e62c738eabbbdf2584e44a7fff81e`.
