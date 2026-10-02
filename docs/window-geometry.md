# Colour-window geometry and background visibility

**Status, 2026-10-02:** Startup/intro window geometry and presentation pass M2. The dedicated M1.7b2
system-window rendered fixture remains separately deferred.

The checkpoint sections below preserve service-level evidence. References to
an intermediate startup stop or a then-pending M2 gate are historical; current
acceptance is recorded in [development.md](development.md), and remaining work
is in [open-work.md](open-work.md). Unsupported contracts remain unsupported
unless a later section explicitly verifies them.

The ShowHide request at Misc1+$0FC6 is `(WIND 131, true)`, revealing the hidden
background window behind WIND 128. The Mac changes its visible byte from 0 to 1,
rebuilds its visibility/structure/content/update regions, and changes 135,512
physical pixels outside the 320×200 game viewport. No viewport pixel or palette
entry changes. The native service now passes this transition, keeping the
background window with no Mac UI drawn.

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
captures. The maintained native `amiga/showhide.gdb` and paired
`tools/check_showhide.py` now verify actual implementation acceptance: original
bytes/ABI, all five complete regions, desktop clipping, front-window preservation,
222,995 exposed pixels painted black, and unchanged viewport/palette/presentation.
Native pixels outside the exposed region are preserved. The original changes
fewer physical pixels because some exposed pixels were already black.

The frame observer allows the client clear either to remain dirty at ShowWindow
return or to have been queued once by an intervening safe trap boundary. A
read-only trace measured the latter through `$A11A` before the original caller
resumed. Both cases must converge to exactly one queued frame at ShowHide;
`aga_startup.gdb` separately checks the eight planes, copper palette and VBI
publication. A cleared dirty flag alone is never accepted as display evidence.

Bounded `boot` and `resource-read` regressions also pass on `a1200-020`.
Resource reads remain 34/130,788 bytes with 70 system windows and original
MDRV absent. ShowHide now progresses to SetGWorld, QDExtensions selector 6 at
Engine+$1286; intro acceptance remains open.

`RegionRows.h` decodes QuickDraw XOR scan-line transitions and computes the
background content intersected with the desktop minus the front window structure.
The desktop is the measured 640×480 region below the menu strip, including its
five-pixel lower corners. Visibility is the same result translated to local
window coordinates; update remains global. Unsupported region complexity,
window arrangements and visibility requests remain named stops. No displayed
pixel changes, so the off-viewport clear queues no additional AGA frame.

ShowHide validation: `tmp/m2-showhide-reference.log` and
`tmp/m2-showhide-native.log` complete normally and pass the paired checker.
`tmp/m2-showhide-regressions.log` records original startup, client/palette and
AGA publication checks; boot and resource-read also pass. Host tests pass,
A5 has zero differences across 75,616 bytes, and both link audits are clean.


## Reasserting the visible game geometry

The original SizeWindow at Misc1+$0F8C requests the existing 320×200 size
with update=false. The subsequent visible MoveWindow at Engine+$48A2 requests
the existing (160,150) origin with front=false. Both Mac calls preserve the
complete window record, own PixMap, five regions, main device/PixMap, palette,
CLUT and all 307,200 screen pixels. The native services accept those unchanged
geometry forms for the visible front colour window; actual resize/movement,
other arrangements and update/front requests retain explicit stops. No Mac
chrome is drawn. Both calls pop ten argument bytes and preserve D3–D7/A2–A6;
the remaining registers are scratch under the measured Toolbox contract.

Original byte guards (CODE header included in offsets):
- Misc1+$0F78–$0F8D: SHA-256
  `764769fd145c2b1be228275e6c3c34b4a8bf5f494db9e18848a692dd0f8ec59e`.
- Engine+$4890–$48A3: SHA-256
  `91e8cde0ff70b45c93ea24bf275399b06ea38786a44b03df25fcf63cfd5f90a0`.

Use `tools/mac_window_reassert.lua`, `amiga/window_reassert.gdb` and
`tools/check_window_reassert.py` for paired verification. The accepted original
capture is local `tmp/m2-resize-reference-accepted.log`; the observer reads
physical NuBus pixels through program space and needs no host-window capture.
Earlier captures with incomplete or misordered events are rejected.
