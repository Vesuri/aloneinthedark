# Colour-window geometry prerequisite

The ShowHide request at Misc1+$0FC6 is `(WIND 131, true)`, revealing the hidden
background window behind WIND 128. The Mac changes its visible byte from 0 to 1,
rebuilds its visibility/structure/content/update regions, and changes 135,512
physical pixels outside the 320×200 game viewport. No viewport pixel or palette
entry changes. This is not yet implemented natively; the named ShowHide stop
remains. The design keeps the background window, with no Mac UI drawn.

The constructor correction addresses these inherited differences:

| Field | Mac reference and corrected model | Inherited native |
| --- | --- | --- |
| Window kind | 8 | 0 |
| Port rectangle | Local origin, resource width/height | Global resource rectangle |
| PixMap | Separate header per window; bounds translated by minus global origin | Shared device PixMap, unshifted bounds |
| Hidden regions | Visibility/structure/content/update empty, independent handles | Visibility/structure/content nonempty; update empty; visibility aliases content |
| Clip | (−32767,−32767)–(32767,32767) | Resource bounds |

For WIND 131, global bounds (−8000,−8000)–(8000,8000) produce local port bounds
(0,0)–(16000,16000) and PixMap bounds (8000,8000)–(8640,8480), in x/y notation.
WIND 128 initially has local (0,0)–(320,200); its PixMap begins at (−82,−168).
After original positioning, the game window's PixMap begins at (−160,−150).
Both window PixMaps still point to the same logical screen pixels.

`tools/mac_color_window_geometry.lua` captures the original constructors at
Misc1+$1272 and +$109A, including actual arguments, stack cleanup, record, PixMap
and complete regions. `tools/check_color_window_geometry.py LOG --status 0`
verifies the original sites and resource-derived geometry; `--native` applies
the same contract to `amiga/color_window_geometry.gdb` captures. Supply actual
runner status. Both constructor checks pass. Captures are local:
`tmp/m2-window-geometry-reference.log`, `tmp/m2-window-geometry-native.log`
and `tmp/window-geometry-*`.

The direct Engine+$48A2 move capture establishes that the hidden WIND 128 move
from (82,168) to (160,150) translates its empty structure/content/update region
bounds by (+78,−18). Visibility stays canonically empty and clip stays unrestricted.
The immediately following SetWTitle at Misc1+$10E0 resets structure/content to
canonical empty regions, retaining the translated update region. The original
instructions between these calls restore registers and push arguments only.
Engine+$4890–$48A3 has SHA-256
`91e8cde0ff70b45c93ea24bf275399b06ea38786a44b03df25fcf63cfd5f90a0`.
`tools/mac_window_move_geometry.lua`, `amiga/window_move_geometry.gdb` and
`tools/check_window_move_geometry.py` provide the paired direct-move check.
Local captures are `tmp/windowmove-{reference,native}-*`. Both sides pass the
original-byte, argument, coordinate and complete-region checks.

ShowWindow creates local visibility bounds (0,0)–(320,200), global client/update
bounds (160,150)–(480,350), and the measured 44-byte WDEF 4 structure region.
The structure represents the union of the bordered/title rectangle and its
one-pixel shadow; it is metadata only, never drawn. Host sanitizer tests decode
this region independently and check its footprint, coordinate inverses and
range rejection. The paired movement, title, palette and exact client-clear checks pass. The
AGA startup check independently verifies eight-plane pixels, all 256 RGB24
colours and VBI publication. Original startup, native driver and A5 checks pass
(the A5 comparison has zero differences across 75,616 bytes). Host tests and
the no-float/probe-symbol link audits pass. Logs use the
`tmp/m2-window-geometry-*` prefix.

`tools/mac_showhide.lua` separately captures ShowHide's full state/region/pixel
transition. Its original Misc1+$0FB4–$0FC7 bytes have SHA-256
`6ff795aa43796be5965f16c5109e7e26f3d7966698fbeb435d57da5a9c80ba2c`.
The bounded reference run `tmp/m2-showhide-reference.log` and native input run
`tmp/m2-showhide-native-input.log` exited normally. These are investigation
captures, not ShowHide implementation acceptance. Region changes include complex
scan-line data; rectangle-only substitutions must not be treated as a pass.

The frame observer allows the client clear either to remain dirty at ShowWindow
return or to have been queued once by an intervening safe trap boundary. A
read-only trace measured the latter through `$A11A` before the original caller
resumed. Both cases must converge to exactly one queued frame at ShowHide;
`aga_startup.gdb` separately checks the eight planes, copper palette and VBI
publication. A cleared dirty flag alone is never accepted as display evidence.

Bounded `boot` and `resource-read` regressions also pass on `a1200-020`.
Resource reads remain 34/130,788 bytes with 70 system windows and original
MDRV absent. ShowHide remains the next named stop; intro acceptance is open.
