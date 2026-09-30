# Font Manager

## GetFNum reference contract

The original Dan1 calls at +$0012 and +$0038 request the Pascal string `Times`
and write family ID 20. Both preserve D0, pop eight argument bytes and leave
ResErr/MemErr zero in this startup context. The second call follows the original
screen-size dialog; choosing 320×200 is required to reach it. No original code
or game state is patched by the original-call observer.

`tools/mac_font_lookup.lua` catches the verified System 7.5.5 Line-A dispatcher
and attributes calls through the live Dan1 jump-table entry. It records the
name bytes, instruction after each trap, output pointer, D0 and stack. The host
checker verifies the original Dan1 routine bytes independently. Frame callbacks
alone miss the early first call and are not sufficient evidence.

The separate `AITD_FONT_FIXTURE=1` diagnostic replays GetFNum in scratch stack
memory after the first original return. These calls measure the service contract;
they do not prove original startup progress. Every call starts with D0=$12345678,
ResErr=$8888, MemErr=$7777 and a $CCCC result surrounded by $ABCD/$DCBA guards.
All eight preserve D0 and both guards and pop exactly eight bytes.

| Name | Result | ResErr | MemErr |
| --- | --- | --- | --- |
| Times, times, TIMES, tImEs | 20 | 0 | $7777 unchanged |
| AITD Missing Font | 0 | -192 | 0 |
| empty string | 0 | -192 | $7777 unchanged |
| Times followed by space | 0 | -192 | 0 |
| space followed by Times | 0 | -192 | 0 |

These are measured names, not a complete international name-collation contract.
The error-global effects are observed System 7.5.5 behavior for these cases.
A matching ID alone is not a font implementation: the native trap still needs
a validated port-owned font definition in the overlay. Full text drawing and
rendered-font acceptance remain M2.9.

The independent M2.1c3a reference prerequisite passes both bounded captures
with process status zero and the full host suite. That reference-only checkpoint did not change runtime code. Native integration
evidence and its remaining startup dependency are recorded below.

## Reproduction

Run each mode sequentially, after sourcing `amiga/env.sh`:

```sh
AITD_FONT_FIXTURE=0 SDL_VIDEODRIVER=dummy timeout -k 5 90 mame maciix \
  -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 180 \
  -snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
  -nvram_directory ref/mame/nvram -debug -debugger none -oslog \
  -autoboot_script tools/mac_font_lookup.lua >tmp/font-original.log 2>&1
font_status=$?
python3 tools/check_font_lookup.py tmp/font-original.log --status "$font_status"
```

Repeat with `AITD_FONT_FIXTURE=1`, a separate log and checker `--fixture`.
The checker requires normal process exit and exactly one positive completion,
rejects incomplete/duplicate/reordered calls, verifies stack/results and D0,
and checks original bytes. Its negative fixtures run in `make host-tests`.
Timeouts and diagnostic wait snapshots are failures. Internal MAME snapshots
are local diagnostics and do not satisfy deferred Amiga rendered-video checks.

## Port-owned placeholder definition

`resources/placeholder-font.json` contains original port-owned 5×7 shapes.
Digits and capitals match the inherited Vette picture font; punctuation is drawn
for this port. Lowercase deliberately shares capital shapes at this prerequisite
stage. This is a placeholder, not Times artwork or an Apple font. Full lowercase,
style/size coverage and rendered placement remain M2.9.

`tools/placeholder_font.py` encodes family 20 as a 60-byte FOND with one plain
14-point association to NFNT 128. The 2,842-byte NFNT contains printable ASCII and the reached MacRoman ©/•/˙
symbols, with missing boxes in unused slots: a 1104×14 monochrome bitmap,
221 location words and 221 offset/width words. The fixed advance is six pixels, ascent twelve and descent
two. Font type $3000 and FOND flags $C000 describe this restricted layout.
The width-table offset is measured in words from the NFNT field at byte 16.

The format follows Apple's [NFNT description](https://dev.os9.ca/techpubs/mac/Text/Text-250.html),
[font type flags](https://dev.os9.ca/techpubs/mac/Text/Text-251.html), and
[FamRec definition](https://dev.os9.ca/techpubs/mac/Text/Text-215.html).
No optional tables or external font data are used.

`BitmapFont.h` validates the family link, metrics, bitmap bounds and every glyph
location/width before exposing pixels. Unsupported layouts are rejected. Its
ASCII family-name matcher passes the measured Times case/space cases.
`check_bitmap_font.py` compiles that native header under address/undefined-behavior
sanitizers and checks exact A, space and missing-glyph pixels, every truncation
and malformed header/table cases. It runs in `make host-tests`. The complete
host suite passes. A standalone parser translation unit also compiles with the
repository’s 68020 flags and compatibility prelude without unresolved helpers;
this is a compiler check, not native runtime acceptance.

The overlay now publishes the Times definition, 25 startup faces in three
additional families, and the native Jnth driver stub (83,050 bytes total).
Its metadata-only preparation uses 33 reads / 572 bytes; the first lookup reads the two bodies in two bounded
windows / 1,878 bytes. Startup retains 243 resource entries before preferences, including the fonts and stub.
GetFNum traverses the resource chain, validates the matching FOND and linked NFNT,
and returns the installed family ID. It preserves D0 and the measured error
behavior; unsupported collation, formats and missing linked definitions stop
explicitly. DrawChar/DrawString remain named trap stops. DrawText now consumes the selected
owned font for the measured intro path described below.

## Integrated native lookup acceptance

Both original Dan1 calls now return family 20 through the installed FOND/NFNT.
`amiga/font_lookup.gdb` delegates to the shared `menu_lifecycle.gdb` observer:
original call bytes and Pascal names are checked, each result pops eight argument
bytes, and D0 and startup ResErr/MemErr match the reference. The second call
preserves the observed nonzero D0 ($00312FF2 in the accepted run). Installed
60-byte FOND and 2,842-byte NFNT dumps match the generator exactly.

`tools/check_native_font.py LOG --status STATUS` requires both calls in order,
second-call register/error evidence, both native driver calls, the exact UnionRect
stop at Dan2+$01DA, MDRV absence and normal debugger completion. `--prepare`
removes old font dumps before capture. Missing/duplicate controls, wrong results,
wrong error flags, incomplete service counts and timeout/error completion fail.
The checker also fingerprints the original Jnth/MDRV loader and entry store.

Acceptance: `tmp/m2-font-integrated-native.log` exits 0, passes the paired font,
driver and AGA checks, and all 75,616 original A5 bytes match. Reference originals
and eight fixtures pass in `tmp/m2-font-final-0.log` and
`tmp/m2-font-final-1.log` (both exit 0). Font parser sanitizer tests and checker
rejection fixtures pass. Current existing-preference startup counts are 81 OS
handbacks, 143 completed services and 42 original resource reads / 208,858 bytes;
overlay is 31 reads / 80,650 bytes. This completes M2.1c3. It does not claim
original PAK-read, rendered-font or intro acceptance; those remain in the queue.

## Original startup metrics

M2.1c3c2c5b2c2b1 measures the original Misc1+$05A0 initializer after hidden
size selection. Original bytes +$0534–+$066B validate table identities, iterate
five font/size records and five style records, then restore the previous font,
size and face. This initializes text layout data; these calls do not draw text,
dialogs or menus.

| Family ID | Point sizes |
| --- | --- |
| 0 | 12 |
| 3 | 9 |
| 21 | 9, 18, 36 |

Each pair uses styles 0, 1, 2, 32, 33 (plain, bold, italic, condensed and
bold-condensed). The original tables reside at A5−$0F10 and A5−$0EF2. Native
startup reaches the same first input: family 0, size 12, face 0, extra 0.
A read-only native snapshot confirms both tables. The existing Times/family-20
14-point overlay therefore cannot satisfy this new call.

GetFontInfo at +$0610 writes eight bytes (ascent, descent, maximum width,
leading), pops four bytes and preserves D3–D7/A2–A6 and the current port.
CharWidth at +$0618/+$0626 measures '0'/space, pops the two-byte character
argument and returns a word in the caller's preallocated result slot. It
preserves the same registers and port. D0–D2/A0–A1 are volatile; original code
uses the result slot. The 25 FontInfo records and 50 widths are measured facts
in `check_font_metrics.py`, not a runtime shortcut or font artwork.

The values require per-style definitions. For example family 21 at 9 points
has zero-character width 5 in both plain and bold, while space grows 2→3.
At 36 points bold grows both by two pixels. A uniform guessed style increment
would be incorrect. Point size also differs from ascent+descent, and family 0
has leading 1. These properties must be represented by the installed native
font definitions. Placeholder drawing remains D6/M2.9 work.

Run the documented headless MAME command with
`-autoboot_script tools/mac_font_metrics.lua`, then:

```sh
python3 tools/check_font_metrics.py tmp/m2-font-metrics-reference-accepted.log --status 0
```

The accepted reference exits normally with exactly 75 calls and positive
completion. The checker guards original bytes, both tables, call order, all
metrics/widths, output guards, stack/registers and restoration of saved text
state (font/size/face 0/0/0, result zero). It rejects changed values/styles,
missing/duplicate completion and timeout. Native implementation and integrated progression now pass as described below.


## Installed startup faces and native metrics

`resources/startup-fonts.json` describes the 25 measured faces. The generator
`startup_fonts.py` builds proportional monochrome NFNTs and three FONDs with
explicit size/style associations, using only the existing port-owned glyph
shapes. Ascent, descent, maximum width, leading and the two requested advances
match the Mac. The plain system face now also uses all 95 measured printable
advances for [hidden window titles](window-title.md). Other character advances
are explicitly placeholder design, not
claimed Mac measurements: space uses its measured width, M/W/@ and the missing
box use maximum width, and other ASCII characters use the zero-character width.
Bold/italic forms are owned bitmap variants; full legibility/layout and display
acceptance remain M2.9, and no drawing trap is enabled by this work.

`BitmapFont` validates bounded association tables, unique ordered size/style
keys, flags, bitmap extents, glyph locations and proportional offset/width
entries. Point size is distinct from ascent+descent. It rejects unsupported
associations, optional tables and invalid bounds. The original Times association remains unchanged; its owned bitmap now also
contains the two intro symbols. Sanitizer fixtures cover every required face, every
truncation, malformed fields, missing selections, glyph bounds and empty space.
Format details follow Apple's [NFNT record](https://dev.os9.ca/techpubs/mac/Text/Text-250.html),
[font flags](https://dev.os9.ca/techpubs/mac/Text/Text-251.html) and
[FOND record](https://dev.os9.ca/techpubs/mac/Text/Text-269.html).

GetFontInfo and CharWidth run through the user-mode service bridge and find the
selected family in resource search order. They load only its exact intrinsic
size/style definition on demand. Unsupported sizes, styles, missing definitions,
nonzero spaceExtra or malformed data stop under the requested routine name.
There is no guessed scaling, fallback font or native metric-result table.
All 25 records and 50 widths match the reference, including register/stack and
output-bound checks. All 30 installed FOND/NFNT bodies match the generated bytes.

```sh
python3 tools/check_font_metrics.py tmp/m2-font-metrics-reference-accepted.log --status 0 \
  --native tmp/m2-metrics-native-final.log --native-status 0
```

Run `amiga/font_metrics.gdb` with the bounded native diagnostic launcher. The
first entry is read from the actual saved Line-A frame after Misc1 loads; later
calls use sequential original-site breakpoints. The observer never writes game
memory or registers. At completion the original restores font/size/face 0/0/0
and returns zero. It then stops at Engine+$110E GetCTable/$AA18, now named
`COLOR QUICKDRAW / GETCTABLE`. The second Times lookup and WIND
128 request remain unverified behind that next dependency. Original MDRV is
absent. These are metric/data contracts, not rendered-font acceptance.


## Startup TextWidth

The unchanged Dan1+$0216 call measures text in Times/plain/14 with zero extra
spacing. Its original +$0212–$0217 bytes are `548f3e80a886`. All 220 calls
through the subsequent Misc1+$0E0A SetGWorld boundary now match the Mac:
exact byte strings (including extended characters), ranges, widths, eight-byte
stack cleanup and unchanged port records. D3–D7/A2–A6 are preserved by the Mac;
the native service preserves all caller registers. Mac scratch-register values
are not reproduced. No text or Mac dialog is drawn by this service.

The measured font's integer advance units scale by 299/256. Accumulate before
truncation: “Alone in the Dark” measures 99, while adding individually truncated
character widths would give 92. `Times14Metrics.h` retains the 256 measured
spacing values, not font artwork. The selected installed placeholder definition
is validated before use. Other selections, nonzero extra spacing, negative ranges
and signed-width overflow remain explicit TextWidth stops. Existing placeholder
artwork and its intrinsic CharWidth behavior are unchanged; full text drawing
and consistent glyph placement remain M2.9.

`mac_textwidth.lua` defaults to the first original call plus 256 CharWidth calls,
256 repeated-character runs and 17 title prefixes in CPU-only scratch fixtures.
Set `AITD_TEXTWIDTH_CALLS=220` for an unmodified original-call capture instead.
The scratch code, stack and text buffer are separated to avoid overwriting code
inside a deeper Mac service. An earlier overlapping fixture failed and is not
acceptance. `check_textwidth.py` validates the fixture's terminal markers, original
bytes, ABI and accumulation model. `check_text_metrics.py` compiles the actual
native helper under sanitizers; `--reference tmp/m2-textwidth-fractions2.log
--status 0` compares all 529 measured results.

`textwidth_calls.gdb` captures every native call read-only within the shared
startup observer. Compare the final captures with:

```
python3 tools/check_textwidth_startup.py tmp/m2-textwidth-original-reference.log tmp/m2-textwidth-native-final.log --reference-status 0 --native-status 0
```

Pass actual terminal statuses to the checkers; a timeout never passes.


## Intro DrawText

The original Dan1+$0346 call (bytes +$0342 `548f3e80a885`) draws 41 MacRoman
bytes: “©1992 I•Motion/Infogrames, 1994 Interplay”. The selected locked eight-bit
GWorld is 648×401 with stride 652, Times/plain/14, text mode 1, foreground index
26 and zero extra spacing. Its baseline is 196 and initial horizontal pen 37.
The fractional pen at port+14 begins at $8000. The 212 measured advance units
add $00F79C00: the final pen is 285, fraction $1C00. Repeating without MoveTo
ends at 532/$B800; MoveTo resets the fraction to $8000. Empty text preserves
pixels and the whole port. DrawText pops eight bytes, returns D0=0 and preserves
D1–D7/A1–A6. The original fixtures establish these contracts independently of
placeholder artwork.

`Text8.h` draws the installed owned bitmap using these fractional character
positions, the selected foreground and map/port/visible/clip intersections.
It fits each ink shape within its measured cell with one separating column.
The placeholder deliberately uses capitals for lowercase, block shapes instead
of Times serifs, and its own ascent of twelve; © and • are newly authored
5×7 shapes stretched to twelve rows. These D6 differences preserve the baseline,
spacing and resulting pen. No Apple artwork is included. Uninstalled characters,
other fonts/styles/sizes/modes, complex regions and signed pen overflow stop
before changing the buffer. The obsolete packed four-bit text renderer is removed.

`mac_drawtext.lua` captures the original call and repeat/MoveTo/empty fixtures.
`check_drawtext.py REFERENCE --status 0 --native NATIVE --native-status 0`
checks original bytes, paired text state, ABI and pen, and every native output
byte against an independent owned-glyph stencil. Initial visible pixel columns
match; the four unused bytes per row contain different allocator history on each
machine and must remain unchanged on their own side. `check_text8.py` adds
sanitizer coverage of clipping, padding, range/overflow rejection and offset input.
The local logical-buffer crops show placement and coarse placeholder lettering;
they are not rendered FS-UAE screenshots and do not close M1.7b2.


## Credits line spacing and dot-above

Dan1+$013C calls GetFontInfo with Times/plain/14 before laying out the credits.
The checked bytes +$0138–$013D are `486efff8a88b`. The Mac returns ascent 12,
descent 4, maximum width 15 and leading 0, preserving the adjacent four bytes.
The original adds ascent, descent and leading to obtain 16-pixel line spacing.
Returning the owned bitmap's intrinsic 12/2/6/0 changed that spacing to 14;
the sixth credits line consequently began twelve pixels too high. The service
now reports the measured layout metrics while the owned ink retains its own
12-pixel ascent and 14-pixel bitmap.

The reached “I˙Motion” DrawText uses bytes `49fa4d6f74696f6e`, pen (98,129),
fraction $8000 and the same Times/plain/14 mode-1 world as the copyright line.
It returns h179/$B900; a repeat ends at h229/$F200. MoveTo resets h129/$8000,
and empty text preserves it. The new ˙ is an authored top dot; its block shape
and placement within the character cell are D6 placeholder differences. No
original glyph artwork is included. The installed range now extends through
MacRoman $FA, but unowned characters still stop instead of drawing missing boxes.

Use `AITD_DOT_TEXT=1` with `mac_drawtext.lua` and `--dot` with
`check_drawtext.py` for this reference and paired native check. It checks the
original FontInfo bytes/result/extent, drawing ABI, whole-port preservation,
exact fractional pen, colours and the complete native output buffer against
the owned stencil. Before this draw, the preceding “Published by” line differs
only inside its measured placeholder ink bounds; all other visible input pixels
match. Logical 320×200 crops show both credits lines legibly at their measured
baselines. These are logical-buffer images, not rendered-window acceptance.
