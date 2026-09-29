# Fixed screen-size selection

D4 requires 320×200 and no displayed size dialog. M2.1c3c2c5a establishes the
original contract; M2.1c3c2c5b1 implements hidden construction. Native startup now stops
at FP68K selector $200E, Engine+$47C2, in the original positioning arithmetic.
GetMainDevice is verified by M2.1c3c2c5b2a; fixed selection remains M2.1c3c2c5b2b.

Original bytes establish the following:

- Gloss+$0820–$085E loads PREF 128, requires signature `$FF800001` and length
  ten, and copies it to the preference object's bytes 4–13. The size flag is
  PREF byte 7 (object byte 11). Defaults at Gloss+$0938–$096E set it to one.
- Core+$0502–$0536 passes that flag to JT107 (Dan2+$30A6) unconditionally,
  then compares the returned word with the old flag and stores their equality
  as the new flag. No preference value skips the call.
- Dan2+$30AE–$30D2 sets the default/cancel item identities from the input.
  It calls GetGWorld, constructs DLOG 1000, runs ModalDialog and its original
  item handler, disposes the dialog and restores the previous world.
- ModalDialog item 2 returns word zero for input one, or word one for input
  zero. Core consequently stores zero in either case. D0's upper word is not
  part of the return contract.
- Misc1+$1078 tests the resulting flag. Zero reaches +$1084 and selects
  WIND 128; nonzero reaches +$107E and selects WIND 132. GetNewCWindow is at
  +$109A. Earlier design text incorrectly attributed WIND 128 to +$107E.

The reference pairs are:

| Input PREF | Selected item | Return word | Output PREF | Window |
| --- | --- | --- | --- | --- |
| `FF800001010101010000` | 2 | 0 | `FF800001010101000000` | 128 |
| `FF800001010101000000` | 2 | 1 | `FF800001010101000000` | 128 |

All nine unrelated preference bytes remain unchanged. The second capture uses
an explicitly controlled input: `AITD_SIZE_INPUT=0` changes only the live size
byte at Core+$0502, before original selection. Neither capture changes any
instruction or return value. The first uses the existing reference preference;
the second does not prove fresh-file creation, which remains native acceptance.
Both exit at the original WIND 128 request, before window construction.

`tools/mac_screen_choice.lua` uses the documented headless MAME command with
`-autoboot_script tools/mac_screen_choice.lua`. Run once with the existing size
one and once with `AITD_SIZE_INPUT=0`. Validate each normal exit:

```sh
python3 tools/check_screen_choice.py LOG --status 0 --input 1
python3 tools/check_screen_choice.py LOW_LOG --status 0 --input 0
```

The checker validates original resource bytes, complete capture markers,
selected item, return mapping, unchanged unrelated preferences and WIND 128.
Its rejection tests run in `make host-tests`. Local evidence is
`tmp/m2-screen-choice-reference.log` and
`tmp/m2-screen-choice-low-reference.log`, both normal exit status zero.

The implementation should use the existing D4-authorized ModalDialog seam,
with real logical dialog state and no presentation of DLOG 1000. It must measure
and implement the required constructor, positioning, item and world-binding
services; unrelated unsupported operations retain named stops. Merely returning
a fabricated successful dialog pointer or changing PREF is insufficient.
Fresh/existing native startup, the next named stop and startup regressions
remain required. Full window/viewport and frame acceptance remains M2.4/M2.7.

## Hidden native constructor

The original GetNewDialog at Dan2+$341C has id 1000, nil storage and behind=-1.
It returns a DialogPtr in the Pascal result slot, pops ten bytes, preserves
D3–D7/A2–A6, inserts the dialog at the head of WindowList, and leaves qd.thePort
unchanged. The DLOG is initially hidden. Native creation matches these results.

Unlike the inherited Vette constructor, it is an old-style GrafPort with an
80-byte bitmap stride, screen backing, local portRect (0,0,90,285) and bitmap
bounds translated by (-187,-241). The visible, structure, content and update
regions are empty; clipping spans (-32767,-32767)–(32767,32767). Portable port
fields match the Mac; pointer and opaque implementation fields are compared
by meaning where required rather than numeric addresses.

The source DITL remains unchanged. A private DITL holds two owned button
handles and a separate 51-byte text handle. Button records preserve their
rectangles, titles, owner, value range and reverse creation-order linkage.
All four private handles are real application-zone handles; failed allocation
releases already-created handles. The source DITL is locked during allocations
and its state restored, so compaction/purging cannot invalidate it. Dimensions
are captured before allocation because the source DLOG is also purgeable.
Disposal releases the private handles; integrated original disposal acceptance
remains in the next item.

D4 suppresses ShowWindow for this dialog. Definition handles point to a private
`HIDDEN DEFINITION DRAWING` loud stop; no WDEF/CDEF drawing is claimed. DrawDialog
for this excluded dialog also stops explicitly. WDEF storage and TextEdit state
are absent from this non-presented subset. The original path does not read them
before the next stop. Other constructor forms or malformed resources stop as
SCREEN SIZE SELECTION.

`tools/mac_hidden_dialog.lua` captures the original constructor, records and
regions without changing code or arguments. `amiga/hidden_dialog.gdb` observes
the production native path. Pair them with:

```sh
python3 tools/check_hidden_dialog.py REFERENCE --status 0 --native NATIVE --native-status 0
```

The checker guards original CODE/DLOG/DITL bytes and compares the portable
170-byte port, complete item list, both controls, text and all five regions.
The bounded item parser has sanitizer tests for every truncation, oversized
counts/lengths and trailing bytes. The reference service trace also identifies
GetMainDevice and SANE selectors $200E/$1004/$2000/$0016/$2010 in the original
positioning path. GetMainDevice now passes; the SANE operations remain dependencies, not
successful native services.
