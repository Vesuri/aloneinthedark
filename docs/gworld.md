# Eight-bit offscreen worlds

The first original request is Misc2+$0074, QDExtensions selector 0. It asks for
8-bit pixels, flags 8 (`keepLocal`), no explicit device, a supplied 256-entry
colour table and bounds (0,0)–(648,401). The allocator now creates real current-zone
storage; unsupported depth/flags/table forms and allocation failures stop at
NEWGWORLD. The original instructions remain unchanged.

The result has a 108-byte fixed colour port and 27 independently owned movable
handles: two PixMaps, pixels, a copied colour table, visibility and clip regions,
GrafVars, a private GDevice and inverse table, and three complete PixPat trees.
Both device and port PixMaps share the pixel and colour-table handles. All new
handles are unlocked and non-purgeable. Pixel contents are uninitialized; they
are not accepted as a rendered frame. The subsequent original initialization now binds and clears the world, then
restores the visible game port. Pixel-address access and the first original image-row copy also pass; the next
queue item is the startup menu-list reset.

Measured allocation details:

- 652-byte rows: rounded-up 32-bit row alignment plus the extra four-byte word
  inherited from Vette. Pixel storage is 261,452 bytes.
- The unlocked PixMaps store the pixel **handle** in baseAddr and version 2.
  Pixel depth and component size are 8, component count 1, resolution 72 dpi.
- The port version is `$C001`, visibility is the full world and clipping is
  initially (−32767,−32767)–(32767,32767).
- The supplied 2,056-byte colour table is copied exactly, including its seed.
  Its handle is temporarily protected against purging during allocation; the
  caller's original flags are restored before return.
- The private GDevice has its own PixMap and 4-bit-resolution inverse table.
  NewGWorld leaves the current device, main GDevice and screen unchanged.
- The Pascal call pops 22 argument bytes and leaves the zero OSErr result.
  D0–D2 are zero, A0 is the output pointer, A1 is the visibility-region body;
  D3–D7/A2–A6 are preserved.

The registry refreshes cached movable body addresses whenever the Memory
Manager refreshes its views. Cleanup disposes every owned handle and the fixed
port before resetting the zones. Capacity and unsupported allocations remain
explicit stops rather than guessed Macintosh errors.

## Inverse colour lookup

Direct Manhattan and Euclidean nearest-colour comparisons did not match the
original table. Instrumenting the System 7.5.5 MakeITable entry established the
actual algorithm: quantize colours to a padded cube, seed first/last/intermediate
palette entries in that order, record same-cell collision rings, and fill unused
cells breadth-first. The neighbour order reverses on every dequeued cell.

`GWorld8.h` implements that integer algorithm. Its resolution-4 result matches
all 4,096 original lookup bytes, the seed/resolution header, collision count 85
and all 256 collision links. The final 256 scratch bytes in the allocated table
are undefined on the Mac and are cleared natively; they are excluded from the
semantic comparison. The separate grey-only builder remains unsupported.
Resolution 5 has host coverage; its original-call acceptance remains with the
broader QuickDraw work when reached.

## Verification

Original Misc2+$0050–$0075 has SHA-256
`4a24b196d92950126c330581d9d5c728c555769313b05bcbfd61cd0c9699d5a5`.

`tools/mac_newgworld.lua` captures the constructor and queries all auxiliary
handles with CPU-executed Memory Manager calls. `amiga/newgworld.gdb` captures the
native records and owning heap. `tools/check_newgworld.py` validates all defined
record bytes, pointer relationships, master slots, block ownership, flags,
lengths, call ABI, colour-copy independence and unchanged screen/device state.
`tools/check_gworld8.py --reference` also compares the pure inverse builder with
the local Mac capture; its normal host test covers layout bounds, every valid
row width, exact PixMap bytes and both supported inverse resolutions.

The local reference is `tmp/m2-newgworld-ownership-all.log`; its dumps and the
MakeITable disassembly remain under ignored `tmp/`. No original resources,
System software bytes or captures are committed.

## Offscreen initialization

Misc2+$008E–$0114 binds the new world, sets its rectangular clip, gets the
PixMap, locks its pixels, erases the clipped rectangle, unlocks the pixels and
restores the game window with the explicit main device. Both SetGWorld forms
retain their measured return values. GetGWorld derives the device from the
bound world.

LockPixels changes the real pixel handle state to locked and changes only the
port PixMap from version 2 / handle baseAddr to version 1 / raw pixel baseAddr.
UnlockPixels reverses that transition. The private device PixMap stays in its
original handle form throughout. Refreshing movable-body views preserves this
distinction. The Boolean lock result and both PixMap lookup results match.

EraseRect uses the owned eight-bit pixels, clips against the map, port,
visibility and clip rectangles, and fills the solid background index. The
measured 648×401 world has 259,848 visible bytes; all become zero, while all
1,604 row-padding bytes remain unchanged. Unsupported patterns, complex regions
and unlocked storage stop explicitly. No screen publication is requested.

The original 160-byte sequence starting at Misc2+$0076 has SHA-256
`6c1c59823b41b3d2087b587439adc5b81dc63377ef8dab2eaed88b5813ed8b70`.
`tools/mac_gworld_init.lua`, `amiga/gworld_init.gdb` and
`tools/check_gworld_init.py` compare the live bytes, eight call stack effects,
callee-preserved registers, owned records, real heap lock states and pixel
results. System-internal scratch addresses left in EraseRect's A0/D2 are not
portable return values; the original initialization sequence does not consume these scratch outputs
as results. The comparison does not require their numerical identity.

Run the checker with explicit normal-exit statuses:

```sh
python3 tools/check_gworld_init.py tmp/m2-gworld-init-reference-final.log \
  tmp/m2-gworld-init-native-final.log --reference-status 0 --native-status 0
```

The accepted reference capture exits normally without Lua errors. An earlier
capture's shutdown-callback error and an initial native observer's malformed
memory-dump expression are excluded from acceptance. The next named stop is
GETPIXBASEADDR, QDOffscreen selector 15, Misc2+$02DA. This establishes offscreen
initialization, not rendered logo or intro acceptance.

## Pixel address and original row-copy use

GetPixBaseAddr at Misc2+$02DA now returns the actual owned pixel body without
changing its state. The locked form (PixMap version 1, raw baseAddr) leaves
D0's high word intact, sets its low word to 1, and returns the pixel pointer in
A0 and on the Pascal stack. The unlocked form (version 2, handle baseAddr)
returns the pixel pointer in D0 and on the stack, with A0 holding the pixel
handle. Both leave A1 at the PixMap body, pop four argument bytes, and preserve
the remaining registers. Unsupported or inconsistent layouts stop explicitly.
All 32 bits of native pixel addresses are retained; no 24-bit masking is used.

The original locked call and a CPU-executed unlocked Mac fixture establish both
forms. The pure helper matches both captured register contracts under host
sanitizers; the native original route verifies the locked form. No native
unlocked-call execution is claimed by this capture.

Original instructions then copy 56 rows of 512 bytes into the 520-byte-stride
buffer and unlock it. Paired captures compare all 28,672 source/visible bytes
and preserve the remaining eight bytes of each row (four unused pixels plus
four stride-padding bytes, 448 bytes total). Queries leave the PixMap and pixels
unchanged; the copy leaves the native screen unchanged. This is offscreen image
data, not an accepted rendered intro frame.

The original Misc2+$02AC–$02DB bytes have SHA-256
`1a629f339fc613c783d30253999e7d72daa777d10837e76747eb0dc21c86ba2a`.
The copy-loop guard checks its single relocated JSR operand against A5 plus the
original relocation value before comparing the remaining instruction bytes.

`tools/mac_pixbase.lua` captures the reference; `amiga/pixbase.gdb` combines
original-byte/main/A5, pointer/copy, mixer-exclusion and AGA-publication checks
in one bounded native run. Verify with `tools/check_pixbase.py` and explicit
`--reference-status 0 --native-status 0`, plus `tools/check_gworld8.py
--pixel-reference` and the existing AGA/A5 comparators. Accepted captures are
`tmp/m2-pixbase-reference-copy.log` and `tmp/m2-pixbase-native-final.log`.
The next stop is MENU MANAGER / CLEARMENUBAR, Engine+$2B06.


## Device colour-table input

The original Dan2+$0234 NewGWorld call uses the GetCTable result directly, with
ctFlags=$8000. The Mac copies all 2,056 bytes unchanged, including flags and
entry values, into its separately owned table. It preserves the input table.
The allocator now accepts this measured flag as well as zero; other table flags
retain the named stop. There is no colour remapping during this allocation.

Original Dan2+$0216–+$0235 has SHA-256
`c55b6fcf3393bf4e7adbffd132760d18fd9ed1225fc5da8b19077b29a5c5baad`.
The live guard verifies the output-pointer immediate against its original value
plus A5. Bounds are (0,0)–(138,542), rowBytes=144 (including the existing extra
slop word), and pixel storage is 78,048 bytes. All 27 owned handles, fixed port,
PixMaps, regions, patterns, private device and defined inverse-table bytes match
the reference after pointer/seed normalization. Input table, main device and
screen remain unchanged. Native heap metadata proves independent ownership and
unlocked/nonpurgeable states. Return registers and 22-byte argument cleanup match.

The existing reference probe supports this site with
`AITD_GWORLD_DEVICE_TABLE=1`; use it with the standard headless MAME invocation.
It writes `tmp/gworld-device-reference-*`. `amiga/gworld_device_call.gdb` is part
of the combined startup observer and reuses `gworld_records.gdb` for the complete
native record/heap capture. Verify normal process statuses with:

```sh
python3 tools/check_newgworld.py tmp/m2-gworld-device-reference.log \
  tmp/m2-gworld-device-native-final.log --reference-status 0 --native-status 0 \
  --device-table
python3 tools/check_gworld8.py --device-reference
```

Both accepted captures exit 0. The helper's ordinary `--reference` comparison
also passes, protecting the existing table path. The first checker expectation
omitted the established four-byte slop word; both actual captures agreed on
144-byte rows, and the checker was corrected to that evidence. No runtime
layout change was needed. Shared startup, detachment, rectangle, font/driver,
A5 and AGA checks pass. The next named stop is RGBForeColor at Dan2+$02BE;
M2.3g7 retains colour selection acceptance. Earlier sections record their
historical boundaries; current shared observers stop at RGBForeColor.


## Visible background-window binding

The original Misc1+$0E0A SetGWorld call selects the existing background window
with a nil device. Its +$0DFE–$0E0B bytes are
`2f2c000842a7203c00080006ab1d`. The window is visible and owned but is not
frontmost. Binding therefore accepts validated visible screen-backed colour
windows regardless of their position in the window list. It does not reorder
windows, draw anything or change the viewport.

The reference selects the main device, changes only the current-port pointer,
returns D0=$0008C000, A0=port and A1=main-device handle, preserves D1–D7/A2–A6,
and consumes eight bytes. Complete 156-byte window, 50-byte PixMap, 62-byte
device and 307,200 screen bytes are unchanged. The background's local port
rectangle is (0,0)–(16000,16000), with PixMap bounds (8000,8000)–(8480,8640).
Native palette bytes, dirty/publication state and colour seed are also preserved.
The Mac capture includes a 56-pixel clock-shaped cursor at (252,267)–(261,274);
the checker validates its exact footprint. The native viewport remains clear.

`mac_world_restore.lua` captures the original binding. The native
`world_restore_call.gdb` is included within the shared startup observer's text
loop, so all previous picture/text checks run in the same acceptance launch.
The existing checker supports both the front and background cases:

```
python3 tools/check_world_binding.py tmp/m2-world-restore-reference-final.log tmp/m2-world-restore-native-final.log --reference-status 0 --native-status 0 --background
```

Use actual exit statuses; terminal markers and the next named stop/MDRV guard
are required. The next original operation is LocalToGlobal at Misc1+$0E20.
