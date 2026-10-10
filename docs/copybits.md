# Eight-bit intro copy

Intro CopyBits and full/partial presentation pass M2, including all 956 intro frames and
separately verified PAL/NTSC rendered output.

The first original intro CopyBits displays the Infogrames logo. Misc2+$24D2 calls it
with bytes `20502f102047486800022f0b486b0008426742a7a8ec` at +$24BE. Arguments are a
direct source PixMap, destination game-port bitmap, (0,0)–(200,320) source and
destination rectangles, srcCopy and nil mask. The source is a locked 648×401 GWorld,
stride 652. The destination uses the 640×480 logical screen with local bounds
(-150,-160)–(330,480), a 320×200 port and visibility rectangle, and the broad
rectangular clip. The Mac returns D0=0, pops 22 bytes and preserves D2–D7/A2–A6;
D1/A0/A1 are scratch.

Source and destination tables have the same ctSeed even though their stored RGB entries
differ. As in Vette, that means preserve indices. `CopyBits8.h` uses Vette's unscaled
clipping equations with byte pixels, bounded buffer sizes and explicit translated dirty
bounds. The dispatcher accepts this owned locked GWorld-to-visible-window form. Other
modes, masks, scaling, source/destination forms remain loud stops pending measured
contracts. Different seeds now use the measured mapping described below.

`mac_copybits8.lua` and the read-only `copybits8_call.gdb` capture the actual call.
`check_copybits8.py` independently computes every destination byte and checks
source/records unchanged, caller bytes/ABI, paired source pixels and complete
64,000-byte client plus both CLUTs. The source has four padding bytes per row outside
its 648-pixel bounds: all 1,604 differ between Mac and native, but neither platform
changes them and they are not copied. All source pixels inside the bounds match. The
ninth AGA publication contains the exact logo.

Accepted runs are `tmp/m2-copybits8-reference.log` and
`tmp/m2-copybits8-native-final.log`, both terminal exit zero:

```
python3 tools/check_copybits8.py tmp/m2-copybits8-reference.log --status 0
python3 tools/check_copybits8.py tmp/m2-copybits8-native-final.log --status 0 --native
python3 tools/check_aga_capture.py startup tmp/m2-copybits8-native-final.log --status 0
```

The helper has 61 full-buffer clipping fixtures, including negative coordinates,
source-edge clipping and row padding, plus rejected scaling/capacity checks; `make
host-tests` runs them with address/undefined-behaviour sanitizers. The helper also
matches the complete original reference destination capture.

## Copyright presentation colour mapping

Dark+$1DBC copies from the same owned GWorld to the selected game window. Original bytes
+$1DA8–$1DBD are `486c0002486b0002486efff8486efff8426742a7a8ec`. Both arguments use the
colour-port bitmap form. Source and destination rectangles are (0,0)–(201,321), srcCopy,
nil mask; the 320×200 port/visibility bounds clip the extra row and column. D0 returns
zero, 22 argument bytes are removed, and D2–D7/A2–A6 are preserved. Source pixels, maps,
tables, port and regions are unchanged by the original.

Unlike the earlier logo copy, the tables have different seeds ($450/$75D on the
reference, $2/$7 on the paired native entry). All 256 RGB entries and the flags agree
between systems. The Mac remaps source colours through the current device's
resolution-four inverse table and collision rings. The existing `GWorld8::inverse` and
`colorIndex` reproduce all 4,364 defined inverse-table bytes and the complete original
destination buffer, including 63,671 changed pixels from 70 source indices. There is no
guessed nearest-colour search.

The copy path builds a 256-byte translation only when the seeds differ, using the
existing measured device lookup. `CopyBits8::copy` applies that table inside its
established clipping loop. Identical seeds still preserve indices. Other transfer modes,
masks, scaling and unsupported source table layouts stop loudly. Host fixtures cover 122
direct/remapped clipped copies and preservation cases. `mac_copylate.lua`,
`copylate_call.gdb` and `check_copylate.py` capture and compare the original call; the
checker accepts only explained D6 copyright-glyph pixel differences between systems, not
arbitrary frame differences.

## Post-intro offscreen copy

Dan2+$07FA copies a 20×8 block from (156,0)–(164,20) to (62,0)–(70,20), using srcCopy
and no mask. Original caller bytes at +$07E8–$07FB are
`486800022f0c2f2e0008486efff8426742a7a8ec`. Both arguments use colour-port bitmap
records. The source is 138×542, stride 144; the selected destination is a 648×401
GWorld, stride 652. The source and destination tables have different seeds. Rebuilding
the resolution-four lookup from the destination table reproduces every byte of the
original 261,452-byte destination, including its 140 changed pixels. The source, both
maps/tables, selected port and clipping records are unchanged. The original returns
D0=0, removes 22 argument bytes, and preserves D2–D7/A2–A6. D1/A0/A1 are scratch.

The adapter now accepts a locked owned offscreen destination using that world's colour
environment and storage bounds. It reuses the existing unscaled clipping helper and does
not mark the visible screen dirty for an offscreen write. Unsupported transfers remain
loud stops. `mac_postintro_copy.lua`, `postcopy_call.gdb` and `check_postcopy.py`
provide the paired full-buffer and ABI checks. Both the original
`tmp/m2-postcopy-reference.log` and native `tmp/m2-postcopy-native.log` finish normally
(exit zero). All defined destination pixels match between systems, and both complete
byte buffers satisfy the independent copy/preservation model. The source equals the
previously verified 20-picture atlas on each platform. Its 41,973 differing unpainted
bytes are untouched allocator contents; every drawn atlas pixel and every copied source
pixel matches. The destination's 1,604 padding bytes likewise remain untouched. No
visible-screen dirty state or publication changes during this offscreen call.

## Direct destination PixMap

Dark+$1E4A passes direct source and destination PixMap pointers, srcCopy and no mask.
Original +$1E3E–$1E4B bytes are `486efff8486efff8426742a7a8ec`; both rectangles are the
A6−8 local, (65,92)–(69,100). Both owned, locked worlds have 648×401 pixels, stride 652,
and identical colour tables including their seed. The selected destination port owns the
passed destination map. Its visibility is the full world and its clip is
(−1000,−1000)–(1000,1000).

`tmp/m2-stepcopy-reference.log` completes normally. The original changes 17 bytes inside
the 8×4 rectangle, preserves the entire source and all other 261,452-byte destination
storage, pops 22 bytes, returns D0=0 and preserves D2–D7/A2–A6. D1/A0/A1 are scratch.
The adapter extends only the destination pointer guard to accept the selected owned
world's PixMap as well as port+2; existing lock, storage, colour and clipping checks
remain in force.

The final uninterrupted production capture `tmp/m2-stepcopy-production-full.log` exits
zero at the original return, Dark+$1E4C. The paired checker verifies all 32 copied
pixels, both complete buffers, unchanged maps/tables/regions and inverse table, the
calling contract, and unchanged visible dirty/publication state (960/960 queued and
presented). All 42 startup comparisons pass in `tmp/m2-stepcopy-regressions.log`. The
first capture's incorrect port+0 map observer and four stale terminal-marker readers
were corrected; those failed checks are not acceptance. The maintained observers are
`mac_stepcopy.lua`, `stepcopy_call.gdb` and `check_stepcopy.py`. This establishes the
copy contract, not complete story/intro or rendered-window acceptance.

## Streaming masked copies

CopyBits8 validates the complete mask before changing the destination, then uses a
forward row cursor and copies clipped spans. The native adapter owns an eight-entry
validation cache for encoded regions up to 4096 bytes. Every lookup checks allocation
capacity and compares all encoded bytes, including size and bounds. Identical content
can reuse validation even after a handle moves; changed content must validate again.
Rectangles and larger regions use the ordinary validator. Invalid streams never enter
the cache, and malformed tails fail before any destination write.

The cache occupies about 32 KiB of static storage, off the supervisor stack. It stores
region encodings, never framebuffer pixels. The cursor retains only scanline edges;
port/clip limits, colour remapping and explicit dirty bounds are unchanged. Original
game instructions are unchanged.

Host fixtures compare entire destinations against independent pixel models and cover
colour mapping, padding, scaling, every-byte mutations after cache hits, relocation,
capacity changes, eviction and oversized regions. The original Mac service fixture
also exercises a distinctive source image. Native observers check preserved source,
records, registers, stack and unchanged offscreen dirty/publication state. See
[testing](testing.md) for native mask and scene checks.
