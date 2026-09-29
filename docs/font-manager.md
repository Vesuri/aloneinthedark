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

The overlay publishes both fonts and the native Jnth driver stub (1,682 bytes
total). Its map preparation uses five reads / 124 bytes; the first lookup reads the two bodies in two bounded
windows / 1,314 bytes. Startup retains 215 resource entries including the fonts and stub.
GetFNum traverses the resource chain, validates the matching FOND and linked NFNT,
and returns the installed family ID. It preserves D0 and the measured error
behavior; unsupported collation, formats and missing linked definitions stop
explicitly. Inherited font-independent DrawChar/DrawString/DrawText now remain
named trap stops pending M2.9 instead of silently drawing the Vette fixed font.

The native observer checks the live original trap bytes, Pascal Times name,
result 20, eight-byte stack cleanup, D0 and error globals at Dan1+$0014. It dumps
both installed bodies for exact host comparison and requires the next named
`SCREEN SIZE SELECTION` stop, with no original MDRV body resident. The original
second lookup has not been reached natively: graphics initialization and further
startup services lie between these calls. The two native driver calls now pass. This is partial M2.1c3 acceptance, not a completed font/startup item.

`amiga/font_lookup.gdb` plus `tools/check_native_font.py LOG --status STATUS`
provide that bounded first-call check; `--prepare` removes old diagnostic dumps.
The checker rejects missing/duplicate completion, bad status and observer errors.
M2.1c3 retains the second-call requirement after the newly reached services.


Startup counters distinguish two measured inputs. With the original default
`PREF` 128 already present, the graphics boundary uses 34 OS windows and 42/42
service entries/completions. Without preferences, original startup creates the
file and uses 60 windows and 50/50 services. All services complete before the
graphics stop. Both paths read 26 original resource bodies / 123,247 bytes plus
three overlay bodies / 1,318 bytes. `check_startup_prefs.py` classifies
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
