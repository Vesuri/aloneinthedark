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
14-point association to NFNT 128. The 1,254-byte NFNT contains printable ASCII
plus a missing-character box: a 480×14 monochrome bitmap, 97 location words and
97 offset/width words. The fixed advance is six pixels, ascent twelve and descent
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
additional families, and the native Jnth driver stub (81,612 bytes total).
Its metadata-only preparation uses 33 reads / 572 bytes; the first lookup reads the two bodies in two bounded
windows / 1,314 bytes. Startup retains 243 resource entries before preferences, including the fonts and stub.
GetFNum traverses the resource chain, validates the matching FOND and linked NFNT,
and returns the installed family ID. It preserves D0 and the measured error
behavior; unsupported collation, formats and missing linked definitions stop
explicitly. Inherited font-independent DrawChar/DrawString/DrawText now remain
named trap stops pending M2.9 instead of silently drawing the Vette fixed font.

The native observer checks the live original trap bytes, Pascal Times name,
result 20, eight-byte stack cleanup, D0 and error globals at Dan1+$0014. It dumps
both installed bodies for exact host comparison and requires the next named
`AEINSTALLEVENTHANDLER` stop at Engine+$1038, with no original MDRV body resident. The original
second lookup has not been reached natively: graphics initialization and further
startup services lie between these calls. The two native driver calls now pass. This is partial M2.1c3 acceptance, not a completed font/startup item.

`amiga/font_lookup.gdb` plus `tools/check_native_font.py LOG --status STATUS`
provide that bounded first-call check; `--prepare` removes old diagnostic dumps.
The checker rejects missing/duplicate completion, bad status and observer errors.
M2.1c3 retains the second-call requirement after the newly reached services.


Startup counters distinguish two measured inputs. With the original default
`PREF` 128 already present, the event-registration boundary uses 64 OS windows and 118/118
service entries/completions. Without preferences, original startup creates the
file and uses 90 windows and 126/126 services. All services complete before the
graphics stop. Both paths read 28 original resource bodies / 123,387 bytes plus
31 overlay bodies / 80,800 bytes. `check_startup_prefs.py` classifies
the starting fixture before launch and supplies exact expected counters; it
rejects partial, nonregular or unmeasured preference contents without deleting
them. These observer restrictions do not alter production preference handling.

The native checker additionally fingerprints Core's original Jnth/MDRV loader
and entry-handle/entry-pointer sequence. It does not count the exploratory
`.BD_PAS16` stop as acceptance: that path entered the forbidden original mixer.


Integration verification: the complete host suite, six native regression cases
and four startup observers pass. Both preference-start modes pass resource-byte
checks; all 75,616 original A5 bytes match. The font observer and independent
body checker pass with normal completion. This verifies the implementation and
first original call, while retaining the second-call acceptance in the queue.


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
match the Mac. Other character advances are explicitly placeholder design, not
claimed Mac measurements: space uses its measured width, M/W/@ and the missing
box use maximum width, and other ASCII characters use the zero-character width.
Bold/italic forms are owned bitmap variants; full legibility/layout and display
acceptance remain M2.9, and no drawing trap is enabled by this work.

`BitmapFont` validates bounded association tables, unique ordered size/style
keys, flags, bitmap extents, glyph locations and proportional offset/width
entries. Point size is distinct from ascent+descent. It rejects unsupported
associations, optional tables and invalid bounds. The original Times definition
remains byte-identical. Sanitizer fixtures cover every required face, every
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
and returns zero. It then stops at Engine+$1038 Pack8/$091F, now named
`APPLE EVENT MANAGER / AEINSTALLEVENTHANDLER`. The second Times lookup and WIND
128 request remain unverified behind that next dependency. Original MDRV is
absent. These are metric/data contracts, not rendered-font acceptance.
