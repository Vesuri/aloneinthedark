# Rectangle operations

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

The next named stop is DetachResource at Dan2+$0210. M2.3g5 retains its measured
ownership/error behavior as pending work. No intro or rendered-font acceptance
is claimed. Fresh-preference endpoint counts (127/171) retain the previously
measured +26 windows/+8 services difference; this change's native acceptance
uses existing preferences.
