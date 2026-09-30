# RGB drawing colours

Original Dan2+$02BE/$02C6 select RGB black foreground and white background
in the newly allocated offscreen world. The original call/argument instructions
are guarded independently, including their A5-relocated RGB pointers. These
calls update drawing state; they neither draw pixels nor alter the device CLUT.

For the reached eight-bit GWorld, RGBForeColor writes the requested six RGB16
bytes at port+36 and its palette index at +80. RGBBackColor uses +42 and +84.
All other port bytes and the three existing simple pattern records stay intact.
Both consume four argument bytes, return the index in D0/D1 and the destination
index-field pointer in A0. A1 is collision-table scratch. D3–D7/A2–A6 are
preserved; D2 is volatile reference scratch, not a portable pointer result.

The lookup uses the world’s inverse cube and refines its collision ring by
RGB16 Manhattan distance, retaining the first equal-distance entry. This model
matches all 66 captured results: the two original calls and 64 fixture calls
covering palette colours, duplicate endpoints, greys and off-palette colours.
A direct cube lookup disagreed on six colour inputs, establishing that collision
resolution is necessary. The pure helper is checked against all captured values
under address/undefined-behavior sanitizers. Null inputs, seed mismatch,
unsupported resolution/flags and malformed rings fail without publishing a result.

Runtime support is for registered eight-bit offscreen worlds with the reached
simple patterns and valid table/inverse state. Unsupported ports/patterns remain
named stops. Nonidentity explicit palette-value mappings are also rejected.
No black/white special case or hardcoded image palette is used.

Reference capture: `tmp/m2-rgb-reference-final.log`, normal exit 0, from the
standard headless MAME command with `tools/mac_rgb_colors.lua`. It records full
port/pattern transitions for all calls. Native capture:
`tmp/m2-rgb-native-final.log`, normal exit 0, using the shared startup observer
and `amiga/rgb_colors_calls.gdb`. The native original route exercises the two
default-colour calls; the 64 extra colour mutations are Mac fixtures, while
native helper comparison covers their lookup results. This does not claim a
native fixture execution of every nondefault RGB mutation.

```sh
python3 tools/check_rgb_colors.py tmp/m2-rgb-reference-final.log --status 0 \
  --native tmp/m2-rgb-native-final.log --native-status 0
python3 tools/check_rgb_lookup.py
```

Use actual process statuses. Shared world, detachment, rectangle, font/driver,
A5 and AGA checks pass on the same native run. It reaches DrawPicture at
Dan2+$0382 with 101 OS handbacks, 164 completed services and 62 original resource
reads / 265,454 bytes. No original MDRV is resident. Eight-bit picture drawing
remains M2.3g8; this is not rendered intro acceptance.
