# Graphics-device startup

The logical device now has a real 640×480, eight-bit screen in fast RAM, as
specified in design.md §4.7. Original device selection passes; native startup
passes SetDepth, GetGWorld and hidden dialog creation. It stops next at
Engine+$47C2 FP68K selector $200E, while positioning the hidden dialog. Drawing and AGA
presentation are not accepted by this prerequisite.

## Measured original selection

`mac_device_startup.lua` observes the original Core selection routine, from
+$4B32 through +$4DC0, without changing instructions or arguments. The checker
fingerprints that complete original byte range and verifies the five instrumented
trap-site instruction pairs. The bounded System 7.5.5 run reaches the second
Times lookup with these four paired calls:

| Core offset | Call | Arguments/result | Argument cleanup |
| --- | --- | --- | --- |
| $4B48 | GetDeviceList | Returns the one device handle | 0 |
| $4D70 | HasDepth, PaletteDispatch selector $0A14 | Depth 8, whichFlags 1, whichValues 0; returns mode **$83** | 10 |
| $4DA2 | OffsetRect | Local copy of device bounds; horizontal/vertical offsets both 0 | 8 |
| $4B8E | GetNextDevice | Same device; returns nil | 4 |

GetDeviceList/GetNextDevice preserve D0. HasDepth returns D0=8 in addition to
its word result in the caller's reserved stack slot. D2–D7/A2–A6 are preserved
across all four calls. A0/A1 and D1 are volatile; their captured values are not
native pointer identities. The original selection returns the captured handle
with one suitable device, avoiding the monitor picker. The requested minimum
size is 320×200. The original directly reads GDevice bounds at +34/+38 and
passes the local copy to OffsetRect before checking width and height.

Core+$4D4A TestDeviceAttribute is instrumented but **not called** on this path:
the original color-only argument is zero. It and other traversal sites must
be measured if later startup reaches them. These four calls do not establish
all device APIs or all graphics startup behavior.

## Device records

All pointers below are relationships checked in the capture, not addresses to
copy into the Amiga. Mac heap handle pointers are masked to 24 bits for debugger
reads; the video base address retains all 32 bits.

- GDevice: indexed `gdType=0`, inverse-table resolution 4, flags `$B921`,
  `gdNextGD=nil`, rectangle `(top,left,bottom,right)=(0,0,480,640)`, mode `$83`.
  Its +22 field points to the PixMap handle.
- PixMap: base `$F9000A00` on the reference card, rowBytes `$8280` (640 with the
  PixMap flag), same bounds, 72 dpi in both directions, indexed pixelType 0,
  pixelSize 8, cmpCount 1, cmpSize 8, no packing or planeBytes. Its +42 field
  points to the color-table handle.
- CTable: device-table flags `$8000`, final index 255, hence 256 entries. This
  probe establishes the header only. Full realized palette values and output
  color transfer remain M2.7/M2.7a; it does not claim palette acceptance.

## Native implementation and limits

The main GDevice points to the window manager's eight-bit PixMap, backed by a
307,200-byte buffer. The PixMap and GDevice share 640×480 bounds and mode $83;
the table has space for 256 entries. The old-style window-manager BitMap uses the same backing and 640-byte stride.
QuickDraw screenBits is an 80-byte monochrome view over that same backing,
matching the reference; both have the same bounds. Clip/visible/gray region bounds are updated.
GetGDevice, GetGWorld and GetDeviceList use the same stable master pointer; GetNextDevice
reads its actual next pointer. HasDepth validates the measured depth/flags/device
request and returns the stored mode; unsupported requests remain named stops.
OffsetRect adds the signed offsets to each coordinate modulo 65536. The paired
original call checks its zero-offset rectangle result; broader rectangle and
rendering acceptance remains queued.

The device color table has the measured header, but its zero-filled entries are
**un-realized storage**, not a reproduced Mac palette. Palette/drawing operations
remain explicit stops. The inherited GWorld paths are also stopped before they
could copy 256 colors into their sixteen-entry storage. Eight-bit pixels never
enter the inherited four-bit presenter: dirty pixel publication stops explicitly;
startup with no drawn pixels retains the bootstrap display without claiming an
eight-bit frame. InitMenus does not draw a bar (D7).

`device_startup.gdb` checks original bytes, all four calls' preserved registers
and stack, HasDepth mode, rectangle preservation, nil chain end, and the actual
one-device selection. It dumps the full 307,200-byte backing and device records.
`check_native_device.py` compares relevant fields and D0 results with the checked
Mac capture, validates extent/untouched pixels, and rejects corrupted acceptance
inputs. OS-specific driver references, pointers and unrealized palette colors
are not claimed equal. No frame, palette or full M2.3/M2.4 acceptance is implied.

## Reproduce and acceptance

```sh
. amiga/env.sh
SDL_VIDEODRIVER=dummy timeout -k 5 90 mame maciix \
  -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 180 \
  -snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
  -nvram_directory ref/mame/nvram -debug -debugger none -oslog \
  -autoboot_script tools/mac_device_startup.lua >tmp/m2-device-reference.log 2>&1
run_status=$?
python3 tools/check_device_startup.py tmp/m2-device-reference.log \
  --status "$run_status"
```

The checker requires normal exit, one positive completion marker, original
bytes, exact call order/count, paired registers/stacks, device/PixMap/CLUT
pointer relationships and headers, rectangle preservation, and the original
one-device selection result. It rejects eight corrupted captures, including
missing/duplicate completion, timeout/missing status, a changed instruction,
Boolean HasDepth result, wrong stride and wrong selected-device count.

An initial probe had a Lua format-escaping error and no completion; it was
rejected despite MAME exiting with status zero. The corrected bounded capture
passes. Dumps and original inputs remain local-only. The original reference contract remains independent of the native implementation.

For the native comparison, run the production observer after the reference:

```sh
(cd amiga && GDBTAIL=300 EXTRA_ARGS=--warp_mode=1 \
  GDBSCRIPT=device_startup.gdb ./diag_run.sh 60) >tmp/m2-device-native.log 2>&1
native_status=$?
python3 tools/check_native_device.py tmp/m2-device-native.log \
  --status "$native_status" --reference tmp/m2-device-reference.log \
  --reference-status "$run_status"
```

The native marker also requires the exact next screen-size-selection caller/selector and
balanced services. Initial palette realization, other device APIs and
the second original Times call remain separate work.

## Already-active SetDepth

Original Core+$04FC uses `MOVE.W #$0A13,D0`, preserving the upper half of the
register, then calls PaletteDispatch at +$0500. The arguments are the selected
device, depth 8, whichFlags 1 and whichValues 1. The reference returns a zero
OSErr in the reserved word slot, pops ten argument bytes and clears D0. D3–D7
and A2–A6 are preserved. D2, D1, A0 and A1 are volatile; the native implementation
preserves extra scratch registers rather than reproducing pointer-dependent
reference clobbers.

The reference GDevice, PixMap and **full 2,056-byte color table are unchanged**.
Native SetDepth validates the matching device/master/PixMap/backing, current
mode $83, depth 8 and measured flags; it returns zero without changing records
or pixels. Other requests retain the named SetDepth stop. This implements the
already-active logical mode, not a new physical Amiga display mode or palette
realization. Both before/after native records and all 307,200 pixel bytes are
checked. Original MDRV remains forbidden and the second Times lookup is still
pending behind fixed screen-size selection.

`mac_setdepth.lua` and `check_setdepth.py` fingerprint the original request,
observe the exact register/stack result, and compare the before/after records
and full color-table dumps. Run the same bounded MAME command above with
`-autoboot_script tools/mac_setdepth.lua`, saving its normal exit status, then:

```sh
python3 tools/check_setdepth.py tmp/m2-setdepth-reference.log --status "$run_status"
(cd amiga && GDBTAIL=250 EXTRA_ARGS=--warp_mode=1 \
  GDBSCRIPT=setdepth.gdb ./diag_run.sh 60) >tmp/m2-setdepth-native.log 2>&1
native_status=$?
python3 tools/check_setdepth.py tmp/m2-setdepth-reference.log --status "$run_status" \
  --native tmp/m2-setdepth-native.log --native-status "$native_status"
```

The native observer also checks the new named stop and exact bounded service/
resource counts. Captures with timeout/missing status, absent or duplicate
completion, wrong arguments or a nonzero result are rejected. The host suite
includes incomplete-capture checks. An initial checker incorrectly compared
all of incoming D0; the original MOVE.W proves that only its low word is the
selector. The native upper half retains its selected-device pointer bits.

## Original GetGWorld

Dan2+$30E2 calls QDOffscreen selector 5 with D0=$00080005. The two output
addresses are adjacent local longs: the device output is first on the stack,
then the port output. The reference pops eight bytes and preserves D0–D7/A2–A6.
It returns the actual QuickDraw current port, also WMgrPort, and the same main
GDevice selected earlier. The complete 108-byte port record is unchanged.

This exposed a previously unmeasured representation detail: WMgrPort is an
old-style GrafPort whose BitMap points to the eight-bit device backing with
rowBytes=640. QuickDraw's screenBits instead has rowBytes=80, with the **same
base address**, not a separate monochrome allocation. Native records now use
those exact relationships and the measured WMgrPort txSize=0 (system default).
The redundant monochrome buffer is removed. Bounds, flags, patterns, pen/text
state and color fields match the reference; base and region/master pointers
are native addresses. The getter uses live current-port state, preserves it,
and returns the real main-device master. It allocates no GWorld.

`mac_getgworld.lua` observes the verified dispatcher at the original call,
records QuickDraw/WMgr/main-device identities, and captures the port before and
after plus its screen descriptor and device. `check_getgworld.py` fingerprints
the original call and InitGraf argument, checks the exact return contract, and
compares every portable port field with `getgworld.gdb`'s native dumps. The
native observer also proves both views use the device's actual backing.
Run the standard bounded MAME command above with
`-autoboot_script tools/mac_getgworld.lua`, then:

```sh
python3 tools/check_getgworld.py tmp/m2-getgworld-reference.log --status "$run_status"
(cd amiga && GDBTAIL=250 EXTRA_ARGS=--warp_mode=1 \
  GDBSCRIPT=getgworld.gdb ./diag_run.sh 60) >tmp/m2-getgworld-native.log 2>&1
native_status=$?
python3 tools/check_getgworld.py tmp/m2-getgworld-reference.log --status "$run_status" \
  --native tmp/m2-getgworld-native.log --native-status "$native_status"
```

Other QDOffscreen selectors remain named stops. The following GetNewDialog(1000)
now creates real hidden records; see [screen-choice.md](screen-choice.md).
GetMainDevice and integer-only positioning also pass. Full intro acceptance
remains open.

## Main-device query during positioning

Original Engine+$4782 GetMainDevice returns the same main GDevice handle that
the original selection and SetDepth calls used. It leaves the Pascal stack
unchanged (no arguments), preserves D0–D7/A1–A6 in the capture, and changes
neither the full 62-byte device record nor current device/port identities.
The native handler returns its real existing handle without allocation or
state/register writes. Portable device fields match the reference.

`tools/mac_main_device.lua`, `amiga/main_device.gdb` and
`tools/check_main_device.py REFERENCE --status 0 --native NATIVE --native-status 0`
provide the original-byte-guarded pair. The checker rejects bad/missing status,
missing completion, altered opcode, stack, result and preserved state/registers.
The subsequent SANE positioning calls now pass using integer arithmetic,
without an FPU; fixed low-resolution selection is also implemented.

## Binding the game drawing port

Original Engine+$1286 calls SetGWorld with the visible WIND 128 colour port and
nil device. The reference changes the current port from WMgrPort to WIND 128,
keeps the sole screen device, pops eight argument bytes and returns D0=$0008C000,
A0=window, A1=main-device handle. D1–D7/A2–A6 and the complete window, PixMap,
device and pixels remain unchanged. The colour-port flags supply D0's low word.

The native service binds that measured screen-backed window form; the existing
main-WMgr restore remains supported and other layouts remain named stops.
Original Engine+$1276–$1287 has SHA-256
`6cc93f9eb31462a18a6460396cd3b737ec91052179d1062dee0bf78c309f0fb9`.
`mac_world_binding.lua`, `world_binding.gdb` and `check_world_binding.py`
provide the paired byte/ABI/state/pixel checks. MAME framebuffer captures use
program-space video reads; generic debugger `save` reads the wrong address
space here. The checker includes a real-client-pixel positive control.

Both sides pass in `tmp/m2-world-binding-{reference,native}.log`. Original
startup now loads Dark and reaches TickCount ($A975), Dark+$41F4. The measured
existing-preferences totals are 36 resource reads / 161,044 bytes, 72 system
windows and 126 completed services. No original MDRV is loaded.

SetGWorld regression acceptance: original startup passes with existing and
isolated fresh preferences (72/98 system windows, 126/134 completed services).
Original preference files are restored. AGA and resource-read regressions,
host tests, no-float and 78-symbol audits pass. The fresh-start A5 dump matches
all 75,616 bytes exactly. Logs use the `tmp/m2-world-binding-*` prefix.
