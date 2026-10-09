# Font Manager

Reached visible Times/plain/14 and Times/plain/36 use raw glyph bitmaps captured from
the original Macintosh renderer under D6. Lowercase, serifs, accents and punctuation
retain their original ink and bearings. Hidden startup font definitions supply
compatibility metrics; they are not used as substitute artwork for reached visible text.

## Bundled Times/14 bitmap

`tools/mac_times_bitmap.lua` calls the original DrawText service in scratch fixtures
after the first real Times/plain/14 draw. It captures all MacRoman characters 32–255
into `tmp/m3-menu/glyph-NNN.bin`; the original game instructions are unchanged. Create
that directory and use the documented headless Mac IIx debugger command with this script
as `-autoboot_script`. Require `PASS original Times14 glyphs=224` and terminal exit
zero.

`tools/times14_bitmap.py --capture-dir tmp/m3-menu` converts those bounded monochrome
captures into `resources/times14-bitmap.json` and the compiled `Times14Bitmap.h`. Only
bitmap artwork is bundled; the Mac font suitcase and outline font are local inputs.
`--check` verifies the generated table. `Text8.h` uses each glyph's original bearing and
rows directly, with the existing measured fractional advances. It does not stretch ink
into cells or convert lowercase into capitals.

`tools/check_text8.py --reference-dir tmp` passes sanitizer checks and compares the
compiled renderer against the original intro-caption buffer, including clipping,
untouched pixels and row padding: **zero differing bytes**. The original caption
contains 664 changed pixels. Existing font-family metrics and unsupported-face loud
stops remain unchanged. Compatibility resources are described below; their artwork does not supply visible Times text.

## Bundled Times/36 pause bitmap

`resources/times36-bitmap.json` contains all MacRoman glyphs 32–255, original bearings,
integer advances and FontInfo (30, 9, 39, 0). Generate the packed `Times36Bitmap.h` with
`python3 tools/times36_bitmap.py`; `--check` checks the bundle, and `--capture-dir`
imports the bounded original glyph captures. `Times36Text.h` clips glyph coverage
against map, port, visibility and clipping bounds and returns explicit dirty bounds. It
implements the reached srcOr path with foreground index zero (displayed white in the
game palette).

The pause helper at (Dan2, $1222) draws into the actual window. Its measured TextWidth
is 294, pen starts at (13,81), and ends at x307. Native TextWidth, GetFontInfo and
DrawText use the captured metrics/artwork. CopyBits accepts an owned window as source so
the original game can save and restore its pause background using its existing GWorld.
There is no game-code patch or generated replacement pause screen.

`tools/check_times36.py --reference-dir tmp/m6/fonts` runs sanitizer-backed
compiled-renderer checks against the original pause buffer, clipping and pen state.
`tools/check_pause_font.py` checks original/native paired text-service captures, all
307,200 output bytes, physical Amiga publication, stable pause and ordinary gameplay
resumption on 68020 and 68030. The Mac fixture uses the native starting pixels and
verifies the same port and string before calling the original DrawText, then restores
the Mac pixels. This isolates text state from different interpolation phases in the
room's idle animation.

## Compatibility resources

`resources/compatibility-glyphs.json` contains port-owned 5×7 shapes inherited
from Vette, plus punctuation and symbols drawn for this port. Lowercase shares
uppercase shapes. These are inputs to valid classic font resources and parser
fixtures, not the game's visible Times artwork.

`tools/compatibility_font.py` encodes Times family 20 as a 60-byte FOND with a
plain 14-point association to NFNT 128. The 2,842-byte NFNT retains its resource
layout, character widths and bounds. `tools/startup_fonts.py` generates the
additional faces from `resources/startup-fonts.json`:

| Family | Sizes | Styles |
| --- | --- | --- |
| 0 | 12 | plain, bold, italic, condensed, bold-condensed |
| 3 | 9 | same five styles |
| 21 | 9, 18, 36 | same five styles |

These 25 faces provide measured ascent, descent, maximum width, leading and
advances for zero and space. Family 0/plain also supplies all 95 measured
printable ASCII advances for [hidden window titles](window-title.md). Other
advances are compatibility defaults, not claimed original Mac measurements.
There is no synthesized scaling or guessed style increment.

`tools/build_overlay.py` combines the four FONDs, 26 NFNTs and native Jnth 11
entry into the 83,050-byte `resources/overlay.rsrc`. The executable embeds it;
resource bodies are loaded lazily from memory into owned handles. Regenerate
with `python3 tools/build_overlay.py`; `--check` requires byte-identical output.

## Service contracts

GetFNum traverses the resource chain and validates the matching FOND and linked
NFNT. Both original Dan1 calls request Times and return family 20. Name matching
is ASCII case-insensitive with exact length: leading/trailing spaces do not
match. Missing names return family zero and resource error -192.

`BitmapFont.h` validates association ordering, exact size/style selection,
flags, extents, glyph locations and width entries. Unsupported optional tables,
malformed data and unavailable selections are rejected. GetFontInfo and
CharWidth use the selected compatibility resource except for the explicit
Times/14 FontInfo and captured Times/36 metrics. Point size is distinct from
ascent plus descent.

Times/14 TextWidth and DrawText use `Times14Metrics.h` fractional advances.
DrawText validates the selected resource at the service boundary, then passes
only pixel buffers, clipping, text and pen state to `Text8.h`. The renderer has
no dependency on the compatibility font object or glyph source. It uses the
captured `Times14Bitmap.h` rows and bearings. Its reached character set remains
ASCII plus MacRoman â, bullet, copyright and dot-above. Unsupported characters,
faces and modes remain explicit failures. DrawChar/DrawString remain unsupported.

The copyright line begins at x37 with fraction $8000 and advances to x285,
fraction $1C00. Repeated draws retain the fractional pen. Credits issue separate
word calls; their spacing must not be reconstructed by joining strings.

## Verification

`make host-tests` checks generated resources and bitmap headers, parser bounds,
malformed/truncated resources, every startup face, name lookup and text clipping,
fractional endpoints, padding and atomic rejection. `check_text8.py` can compare
the original caption buffer; `check_times36.py` can compare the pause buffer as
shown above. The frame comparator requires exact viewport pixels and offers no
exception for substitute lettering.

`mac_font_lookup.lua`, `mac_font_metrics.lua` and their paired checkers retain
the original byte, call-order, stack and register contracts. The combined native
`font_lookup.gdb` / `driver_startup.gdb` observer shares `menu_lifecycle.gdb`;
its later RGB checkpoint needs maintenance described by TEST.1 in
[open work](open-work.md). Passing its initial font checks alone is not completion
of that combined observer.
