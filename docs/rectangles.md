# Rectangle operations

**Status, 2026-10-02:** The rectangle services used by startup and intro pass M2; the full intro and
paired frame checks are complete.

The checkpoint sections below preserve service-level evidence. References to
an intermediate startup stop or a then-pending M2 gate are historical; current
acceptance is recorded in [development.md](development.md), and remaining work
is in [open-work.md](open-work.md). Unsupported contracts remain unsupported
unless a later section explicitly verifies them.

## UnionRect

The original Dan2+$01DA loop runs twenty times while preparing image bounds.
The original bytes at +$01BC–+$01DF have SHA-256
`6830d1818ab1ca6c4ac1c282e846b0edb808292d4d20c07f630430fa1a67618b`.
Both live captures match these bytes; no game instructions change.

The measured operation takes signed 16-bit minima of top/left and maxima of
bottom/right. It does this even for zero-size and inverted inputs; discarding
an empty input would disagree with the reference. Either source can alias the
destination. `RectBounds::unite` reads both inputs before writing exactly eight
bytes. Null pointers retain the runtime named stop.

The original/native results agree for all twenty calls. Pascal cleanup consumes
12 argument bytes. D0 and D1 contain the resulting top/left and bottom/right
longwords; A1 points just past source 2. D2–D7/A2–A6 are preserved. The Mac
scratch fixtures also show A0 is the return PC; the native dispatcher supplies
its original trap address plus two. Eleven isolated reference fixtures cover
negative/extreme coordinates, empty/inverted rectangles and both destination
aliases. The native helper matches all 31 pairs under address/undefined-behavior
sanitizers, with surrounding bytes and null rejection checked.

Reproduce after sourcing `amiga/env.sh`, using the standard headless MAME command
with `-autoboot_script tools/mac_unionrect.lua`. Run the native combined observer
with `GDBSCRIPT=menu_lifecycle.gdb` and `./diag_run.sh 300`. Then:

```sh
python3 tools/check_unionrect.py tmp/m2-unionrect-reference-final.log --status 0 \
  --native tmp/m2-unionrect-native-final.log --native-status 0
python3 tools/check_rect_bounds.py
python3 tools/check_native_font.py tmp/m2-unionrect-native-final.log --status 0
python3 tools/check_aga_capture.py startup tmp/m2-unionrect-native-final.log --status 0
```

Use actual terminal statuses, never assumed zero. The accepted reference and
native captures both exited 0. An earlier reference shutdown emitted its marker
twice and was rejected; a completion guard fixes that observer callback.
The native discovery run reached the new stop and failed its old endpoint
assertion; it is not acceptance. The final combined run passes the rectangle,
font, native-driver and AGA checks, with no original MDRV resident. A5 matches
all 75,616 bytes and both link audits pass. Counts are 101 OS handbacks, 163
completed services and 62 original resource reads / 265,454 bytes. The extra
20 reads belong to the newly executed preparation loop.

At rectangle acceptance the next stop was DetachResource at Dan2+$0210.
That call now passes its measured already-detached error; the shared observer
continues to NewGWorld at Dan2+$0234 (M2.3g6). Historical log commands above
describe the rectangle checkpoint; use the current combined capture for current
endpoint checks. No intro or rendered-font acceptance
is claimed. Fresh-preference endpoint counts (127/171) retain the previously
measured +26 windows/+8 services difference; this change's native acceptance
uses existing preferences.

## SectRect

M2.3g13 implements signed rectangle intersection, including zero output and false
for empty, touching or inverted intersections. Either input may alias the output;
all inputs are read before the eight destination bytes are written. Null pointers
retain the named stop. Original Misc1+$0E80–+$0E91 bytes are
`4227205248680022486efff4486effeca8aa`; game instructions are unchanged.

Two original calls at Misc1+$0E90 select the drawing device. The device rectangle
(0,0,480,640) intersects first with the background (-8000,-8000,8000,8000), then
with the game window (150,160,350,480), in top/left/bottom/right order. Both return
true and the expected device/game rectangle respectively. Fourteen Mac fixtures
cover signed extremes, empty/inverted inputs, touching edges and destination
aliasing. All sixteen retained pairs pass the actual helper under ASan/UBSan.

The Boolean occupies the first byte of the caller's result word; padding is
preserved. Stack cleanup consumes twelve bytes. D0's low word becomes 14 while
its upper word and D1–D7/A2–A6 are preserved. Native A0/A1 remain preserved;
Mac scratch addresses are not reproduced. Native destination guards are unchanged.

Use the documented headless MAME command with `tools/mac_sectrect.lua`, and the
combined native `menu_lifecycle.gdb` observer. Accepted reference and native logs
both exit 0 with positive completion markers. Reproduce the checks with:

```sh
python3 tools/check_sectrect.py tmp/m2-sectrect-reference-final.log --status 0
python3 tools/check_sectrect.py tmp/m2-sectrect-native-final.log --status 0 --native
python3 tools/check_sectrect_helper.py --reference tmp/m2-sectrect-reference-final.log --status 0
```

Supply actual terminal statuses. The native observer preserves the first
background binding/coordinate captures while collecting both intersections.
Startup now stops at WaitNextEvent, Engine+$44F0; intro acceptance remains open.

M2.3g14 advances the combined observer through four event polls. This repeats
the background/game device-selection pair four times, giving eight checked
SectRect calls. Use `tmp/m2-event-native-final.log` with the current checker;
the earlier two-call capture describes the preceding checkpoint.

Beyond cursor obscuring, the game repeats device selection during idle polls.
The current checker validates every alternating background/game pair and its
individual guards; it requires an even count rather than pinning idle timing.
The accepted cursor run contains twenty intersections.
