# Graphics-device startup

The logical device now has a real 640×480, eight-bit screen in fast RAM, as
specified in design.md §4.7. Original device selection passes; native startup
passes the already-active SetDepth request and stops next at Dan2+$30E2
GetGWorld ($AB1D, selector 5). Drawing and AGA
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
the table has space for 256 entries. The classic monochrome screenBits and
window-manager BitMap instead have their own 38,400-byte buffer and 80-byte
stride, with the same bounds. Clip/visible/gray region bounds are updated.
GetGDevice and GetDeviceList use the same stable master pointer; GetNextDevice
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

The native marker also requires the exact next GetGWorld caller/selector and
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
pending behind GetGWorld.

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
