# Fixed screen-size selection

D4 requires 320×200 and no displayed size dialog. Hidden construction,
positioning, automatic item-2 selection, item lookup/disposal and restoration of
the main world are implemented. Native startup now passes palette binding and
first requests WIND 131 ("Background Hider") at Misc1+$1272. It stops at that
window's SetWTitle call (+$1296), before the main WIND 128 request (+$109A).
Title-state support is therefore a prerequisite for main-window acceptance. No Mac dialog presentation is authorized (D5).

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

The native implementation uses the D4-authorized ModalDialog seam with real
logical dialog state and no presentation of DLOG 1000. The measured constructor,
positioning, item and restoration services are implemented; unrelated unsupported
operations retain named stops. Fresh/existing native selection passes as below.
WIND 128 request and full window/viewport/frame acceptance remain pending.

## Hidden native constructor

The original GetNewDialog at Dan2+$341C has id 1000, nil storage and behind=-1.
It returns a DialogPtr in the Pascal result slot, pops ten bytes, preserves
D3–D7/A2–A6, inserts the dialog at the head of WindowList, and leaves qd.thePort
unchanged. The DLOG is initially hidden. Native creation matches these results, with the corrected inactive edit-item
sentinel described below.

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
Disposal releases the private handles; the integrated acceptance is below.

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
positioning path. GetMainDevice and all ten SANE calls now pass their paired
contracts; see [sane.md](sane.md). Hidden MoveWindow now passes the contract below. Hidden state does not authorize
drawing the chooser or any Mac dialogs.


## Hidden positioning

Engine+$48A2 calls MoveWindow with h=177, v=205, front=false; the unused low
byte of the Pascal Boolean stack word differs across runs and is ignored.
The original pops ten bytes, preserves D3–D7/A2–A6, current port and WindowList.
Bitmap bounds change from (-187,-241,293,399) to (-205,-177,275,463). The local
port rectangle remains (0,0,90,285). Structure/content/update regions remain
empty but their coordinates translate by (18,-64); visibility and clip regions,
item list, both controls and text remain byte-identical. No pixels are drawn.
The native implementation matches; unsupported front/visible/nonempty-region
forms retain the MoveWindow stop. The subsequent hidden selection is below.

`mac_hidden_move.lua` and `hidden_move.gdb` capture the two sides. Check with:

```sh
python3 tools/check_hidden_move.py REFERENCE --status 0 --native NATIVE --native-status 0
```

The checker guards original Engine+$4858–+$48AB, portable fields, complete
before/after records and positive completion; corruptions and timeout fail.
Use `tmp/m2-literals-hidden_move-reference.log` for the reference. The corrected
constructor reference is `tmp/m2-literals-hidden_dialog-reference.log`.

This work found an error in earlier dialog dumps: bare hexadecimal offsets
`a0` and `a4` were parsed as registers. Explicit `0x` prefixes correct them.
The corrected record establishes editField=-1 (no active edit item), now also
initialized natively. TextEdit handle and unused editOpen/padding remain opaque
implementation state for this button/static-text-only hidden dialog; TextEdit
services are not implemented. Within each machine, every record byte except
bitmap bounds is preserved by MoveWindow. Earlier constructor tail-byte evidence
is superseded; the remaining emitters are now audited, with a maintained regression and
fresh affected captures; see [mac-reference-loop.md](mac-reference-loop.md).


## Hidden fixed-choice services

The original service sequence is Dan2+$30FE ModalDialog, +$348A GetDItem,
+$3452 DisposeDialog and +$313C SetGWorld (selector 6). Original helper bytes
+$344A–+$34F9 are guarded alongside the selection-path hashes. No original
instruction is changed.

D4 returns item 2 immediately for the hidden DLOG 1000 and its measured
A5+$372 filter. It writes only the item word, preserves D3–D7/A2–A6, pops eight
bytes and makes the hidden dialog current. The Mac reference has an initial
item-zero iteration before the scripted click; omitting that visible interaction
is the intentional D4 policy. Other modal forms remain explicit stops.

GetDItem pops eighteen bytes and returns the actual owned second control handle,
button type 4, and local rectangle (60,29,80,129). Disposal pops four bytes,
unlinks the hidden dialog, restores WMgrPort and releases all four owned
allocations (384 physical bytes). Allocation flags clear and the slot is unused;
freed master pointers are linked into the heap free list, not required to stay
nil. SetGWorld pops eight bytes, restores the measured main-device/WMgrPort pair,
returns D0=$00080000 and the port/device in A0/A1. Broader world changes are
unsupported, pending the graphics work.

`mac_choice_services.lua` and `choice_services.gdb` capture both sides;
`check_choice_services.py` checks stack/registers, output extents, pointer
relationships, item fields, private ownership cleanup and preference mapping:

```sh
python3 tools/check_choice_services.py tmp/m2-choice-services-reference.log --status 0 \
  --native tmp/m2-setpalette-accepted-choice_services.log --native-status 0
```

The subsequent GetFontInfo/CharWidth calls now pass; see [font-manager.md](font-manager.md).
The current stop is `WINDOW MANAGER / SETWTITLE`,
Misc1+$1296, trap $A91A. Preference zero does not by itself prove WIND 128 acceptance.
Full drawing, replacement in-game interfaces, window/viewport and frame acceptance
remain required by the queue.

Native evidence uses `tmp/m2-choice-native.log`, `tmp/m2-choice-fresh.log` and
`tmp/m2-choice-low.log`, all normal exits with positive completion. The fresh
run creates the default size-one PREF; existing inputs one and zero both become
zero with all nine unrelated bytes preserved. The tests restore the original
on-disk preferences. Those selection-only captures ended with 36/62 windows and 43/51 completed
services. Current startup also loads the metric fonts, ending with 64/90 windows
and 118/126 services. Original application reads remain 28 / 123,387 bytes. The checker also
rejects visibility, cleanup, preference, duplicate-capture and timeout failures.


## Main-window acceptance dependency

A read-only extension of the selection observer stopped at the first original
GetNewCWindow after selection and palette setup. It measured resource 131 at
Misc1+$1272, not resource 128 at +$109A. The original resource names 131
"Background Hider". Original Misc1+$1250–$1297 bytes have SHA256
`1a1d6c325582244a437981e80f2f0ff7c21f35ab366a9ff238d33be9284cbd52`;
they push 131 for AA46 at +$1272 and reach A91A at +$1296. The existing named
stop prevents reaching the main-window request. This does not invalidate the
Mac reference's two WIND 128 selection captures, but native acceptance is still
unproven. Title-state work now precedes it in the queue.

Local evidence is `tmp/m2-wind-site-probe.log` (an intentionally rejected
main-window capture with explicit actual site/id), and the previously accepted
SetPalette endpoint captures. The attempted observer/checker extensions are
preserved in `tmp/wind-attempt-*`; maintained startup checks remain unchanged.
No runtime code, original instructions, UI policy or owner decision changed.
