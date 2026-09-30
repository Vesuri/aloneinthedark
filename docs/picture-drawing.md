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
