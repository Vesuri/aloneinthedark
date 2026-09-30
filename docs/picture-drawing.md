# Eight-bit picture preparation

The original Dan2 loop draws PICT 10000–10019 into a locked 138×542 GWorld
with row stride 144. The unchanged caller at +$037C–$0383 is
`2f0b486efff8a8f6`; +$0382 is DrawPicture. Images are detached before drawing,
so their bounds come from the owned heap allocation, not resource association.

The measured resources use PICT v2, rectangular frame clips, indexed eight-bit
PackBitsRect, complete 256-entry device colour tables and srcCopy. Vette's
PackBits decoder and integer coordinate mapping are reused. Eight-bit output
uses the owned world's actual inverse colour table and collision rings, plus
its port/visibility/clip bounds. Direct index copying is incorrect for pictures
10014 and 10019. Unsupported formats and complex picture clips remain stops.
The reached route is unscaled; broader scaling acceptance is not claimed.

`tools/mac_drawpicture8.lua` captures all twenty original calls and complete
before/after records and pixels. `amiga/picture8_calls.gdb` captures the same
calls read-only inside the combined startup observer. The independent
`tools/check_picture8.py` decodes the original bytes and computes RGB mapping.
It checks 1,560,960 destination bytes per platform, including untouched pixels
and row padding, all D0–D7/A0–A6 registers, eight-byte stack cleanup, unchanged
port/PixMap/regions and original picture bodies. Native acceptance also requires
the shared startup endpoint/MDRV guard. Captures stay under ignored `tmp/`.

Run the reference with the documented headless MAME command and
`tools/mac_drawpicture8.lua`; run the native combined `menu_lifecycle.gdb`
observer through `amiga/diag_run.sh 300`. Check actual terminal statuses:

```
python3 tools/check_picture8.py tmp/m2-pict8-reference.log --status 0
python3 tools/check_picture8.py tmp/m2-pict8-native-final.log --status 0 --native
```

These are offscreen pixel comparisons, not rendered-window or intro acceptance.


## Presentation window picture

PICT 1500, MacPlay (small), is a 16,358-byte indexed PackBits picture with
frame (0,0)–(192,256). The original Dark2+$20EC bytes are
`2e8b486effe4a8f6`, calling DrawPicture at +$20F2 with destination
(4,32)–(196,288). It preserves D0–D7/A0–A6 and pops eight argument bytes.

The existing renderer now accepts owned visible eight-bit window destinations.
It uses the actual main-device colour table and existing inverse-table builder,
with rectangular port/visibility/clip bounds. Window pixels share the logical
screen; dirty bounds translate from port coordinates to that buffer. Offscreen
worlds retain their own colour matching. No Mac chrome is drawn.

`mac_presentpicture.lua` captures the original call and the subsequent clear
before palette restoration at Dark2+$214C. `presentpicture_calls.gdb` captures
the native call and fifth AGA publication before continuing startup. The
independent decoder in `check_presentpicture.py` checks the entire 307,200-byte
buffer, unchanged records, original bytes and caller ABI. Its native check also
compares the 64,000-byte client and CLUT with the Mac, verifies eight bitplanes
and all copper colours for the picture, and requires the integrated MDRV guard.
Memory/AGA captures do not satisfy the owner-deferred rendered-window check.


Accepted runs: `tmp/m2-presentpicture-reference-next.log` and
`tmp/m2-presentpicture-native-complete.log`, both terminal exit zero. The latter
preserves the full debugger transcript because the wrapper's 5,000-line tail
omits earlier controls during the picture's event loop. The 12,144 changed
pixels match; the fifth AGA publication contains the picture and the sixth
contains the original black clear. These commands pass:

```
python3 tools/check_presentpicture.py tmp/m2-presentpicture-reference-next.log --status 0
python3 tools/check_presentpicture.py tmp/m2-presentpicture-native-complete.log --status 0 --native
python3 tools/check_aga_capture.py startup tmp/m2-presentpicture-native-complete.log --status 0
```
