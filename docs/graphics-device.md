# Graphics-device startup

The next native prerequisite is the logical 640×480, eight-bit screen in
design.md §4.7. The inherited Vette records still describe 512×320 at four bits;
they must not be relabelled as eight-bit without matching pixel storage and
consistent QuickDraw records. Native startup still stops at GetDeviceList.

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

The native implementation must allocate the real logical screen, keep these
observable fields consistent, and stop at unsupported drawing rather than
letting inherited four-bit paths consume eight-bit pixels. The new device must
remain the same object across traversal and main/current-device APIs. General
rectangle behavior and unmeasured depth requests need real semantics or named
stops. Passing this startup subset does not complete M2.3/M2.4 or rendered
frame comparison.

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
passes. Dumps and original inputs remain local-only. No native runtime behavior
changed in this reference-contract step.
