# RGB drawing colours

**Status, 2026-10-02:** Intro drawing and matched car/frog rendering pass M2, including rendered
PAL/NTSC display checks.

The checkpoint sections below preserve service-level evidence. References to
an intermediate startup stop or a then-pending M2 gate are historical; current
acceptance is recorded in [development.md](development.md), and remaining work
is in [open-work.md](open-work.md). Unsupported contracts remain unsupported
unless a later section explicitly verifies them.

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


## Intro offscreen PaintRect (M2.3g27a)

Dark2+$1E3E pushes the A5-relative rectangle ($FFFF4D58 before CREL), then
+$1E44 calls PaintRect. The reached GWorld is 648×401, stride 652, locked,
eight-bit, with rectangular visible/clip regions. The pen is solid $FF,
mode 8, visible, foreground index 255. The rectangle is (0,0)–(320,140).

The native path reuses `FillRect8::solid`, clips against map/port/visible/clip
bounds, and writes only foreground indexes into owned pixel storage. It does
not mark the screen dirty until presentation. Other patterns, modes, hidden
pens or complex regions remain unsupported. Port, PixMap, CLUT, regions and
adjacent rectangle bytes stay unchanged. D0=0, D1's low word is 8, A1 is the
port; D3–D7/A2–A6 and four-byte stack cleanup match the original.

`tmp/m2-paintworld-reference.log` and
`tmp/m2-driver20-prefix-native-named.log` exit zero. `check_paintworld.py`
verifies the 44,800-pixel fill, complete buffer preservation (including row
padding), and every paired pixel column across 648×401. Reference padding is
not compared to native allocator contents. The native intro next reaches
LineTo at Dark3+$337E. No full intro acceptance is claimed.


## Intro LineTo (M2.3g28)

The original Dark3+$3376 bytes `3f2effc63f2effc4a891` push the target
and call LineTo at +$337E. The first call draws (251,84) to (238,74), index
26, into a locked 648×401 eight-bit world with stride 652. It uses a visible,
solid 1×1 mode-8 pen and rectangular clipping. Only the pen location changes
in the port. D0 becomes zero; D1–D7/A1–A6 are preserved and four argument
bytes are removed. A0 is scratch; dead argument-stack bytes are not preserved.

Vette has no reusable QuickDraw line rasterizer. After two rejected raster
models, instruction and register traces established the original signed 16.16
slope, top-to-bottom normalization, half-open spans and diagonal branch.
`Line8::solid` implements these rules using integer/fraction components, without
an FPU or 64-bit arithmetic. It clips against map, port, visible and clip bounds;
updates the requested pen position even when fully clipped; and leaves screen
publication to CopyBits. Other ports, pen sizes/modes/patterns and complex
regions retain the named stop.

`tools/mac_lineto.lua` captures the original call and 48 isolated slope,
reversal, zero-length and clipping fixtures. `check_line8.py` compares the
production helper with the complete original call buffer and the fixtures'
64×64 captures, plus independent buffer-preservation cases. The native call's
complete 648×401 pixel columns and CLUT match the Mac; each side's row padding
and all nondrawn bytes are preserved. Port/ABI checks pass on both systems.
Reference `tmp/m2-lineto-registers-reference.log` and native
`tmp/m2-lineto-native-accept.log` exit zero. The trace diagnostics stay in `tmp/`.

The native route advances through the effect's actual completed query to
PaintRect at Dan2+$0D52. The nine-frame startup AGA capture now runs at its
measured first-LineTo boundary; subsequent intro frames do not overwrite it.
This is not acceptance of the whole rendered intro.


## Later mode-0 PaintRect (M2.3g29)

The same Dan2+$0D52 caller (`486efff0a8a2` at +$0D4E) later draws into an
owned GWorld using a solid mode-0 pen. At the matched state it fills
(top=192,left=117,bottom=200,right=181) with index 18: 512 covered pixels,
430 changed. The selected world is 648×401, stride 652, locked and eight-bit,
with rectangular visible/clip regions. This is game drawing, not a Mac dialog.

The original confirms mode 0 uses the existing solid-fill result. Native
`paintGWorldRect` now accepts 0 or 8; its other pattern/region/ownership guards
remain. Pen mode stays zero. Port, PixMap, CLUT, regions, rectangle guards and
all surrounding bytes are unchanged. The existing PaintRect ABI also applies:
D0=0, D1 low word=8, A1=port, D3–D7/A2–A6 preserved, four argument bytes removed.

`mac_paintlater.lua` and `paintlater_call.gdb` capture the corresponding state;
`check_paintlater.py` checks original bytes, ABI, actual contrasting writes,
complete-buffer preservation, all paired 648×401 pixel columns and logical
CLUT. Original `tmp/m2-paintlater-reference-mode.log` and native
`tmp/m2-paintlater-native-accept.log` both exit zero with positive markers.
The first four calls at this address clear a window; the measured mode-0 call
is later. A different rectangle at the same caller is not the same state.

The next call, DrawText at Dan1+$0346, exposed an inherited zero-return guard.
It now takes the normal named-stop path. Text rendering is M2.3g30; this fill
acceptance does not claim the full intro is complete.

## Game-window LineTo (M2.3g33)

The original Dan2+$0B5A call follows the credits. Bytes +$0B52–$0B5B are
`3eae000c3f2e000ea891`. It selects the 320×200 game window over the 640×480
screen, with PixMap bounds (-150,-160,330,480), stride 640, a solid 1×1 patCopy
pen and foreground index 16. From (v0,h260) to (v200,h260), QuickDraw writes
exactly 200 pixels: global x420, y150–349. The endpoint at y200 is clipped, but
the returned pen still reaches it. All remaining 307,000 screen bytes and
port fields are preserved; D0 becomes zero, four argument bytes are popped,
and D1–D7/A1–A6 are preserved. The original visible and clip regions are
(0,0,200,320) and (-32767,-32767,32767,32767).

The window adapter reuses `Line8::solid`, accepts only the existing implicit
solid window pen, and rejects dialogs, hidden windows, other pen sizes/modes,
complex regions and unsupported pixel storage. The helper now reports its exact
clipped footprint. The adapter converts that footprint through the PixMap
origin before queuing native screen work. Empty clips still advance the pen
without publishing pixels. Host fixtures cover translated origins, boundary
clipping and empty clips; all 48 original slope/reversal fixtures also check
the reported footprint against an independent scan.

Use `AITD_WINDOW_LINE=1` with `tools/mac_lineto.lua` to capture the original
call without the GWorld scratch fixtures. `tools/check_windowline.py` checks
its complete screen buffer and the native rasterizer; paired acceptance also
checks `amiga/windowline_call.gdb`'s ABI, dirty bounds and queued/active AGA
buffers. Both complete input screens must equal their previously verified title
captures, retaining the documented hidden-desktop and placeholder-text
differences. The line's changed coordinates and colour are identical.

The first native discovery run captured the correct line and AGA publication,
but reached its 240-second ceiling later in pixel conversion. It is rejected
as a complete run. The instrumented follow-up exits normally after 112 window
lines and 848 publications, reaching the next named text stop. The full native
regression also exits normally; all 32 integrated comparisons pass. Its first
line queues and publishes frame 117: the complete 64,000 planar bytes decode
to the exact line-return framebuffer, all 256 colours match, copper pointers
and queued/active buffers agree, and publication occurs at VBI line zero.
Rendered-video acceptance remains owner-deferred.
