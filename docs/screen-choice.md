# Fixed screen-size selection

**Status, 2026-10-02:** The fixed 320×200 startup path passes M2. Broader dialog replacements remain
M3.3.

The checkpoint sections below preserve service-level evidence. References to
an intermediate startup stop or a then-pending M2 gate are historical; current
acceptance is recorded in [development.md](development.md), and remaining work
is in [open-work.md](open-work.md). Unsupported contracts remain unsupported
unless a later section explicitly verifies them.

D4 requires 320×200 and no displayed size dialog. Hidden construction,
positioning, automatic item-2 selection, item lookup/disposal and restoration of
the main world are implemented. Native startup passes default palette binding,
WIND 131 ("Background Hider") and its hidden title update; see
[window-title.md](window-title.md). It now stops at window-palette binding,
Misc1+$10FA. Fresh and existing-preference startup now prove the original
WIND 128 request at Misc1+$109A. Both input size flags match the Mac selection
contract, with only the size preference byte changed.
No Mac dialog presentation is authorized (D5).

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
The WIND 128 request now passes the integrated checks below; full
window/viewport/frame acceptance remains pending.

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
  --native tmp/m2-title-accepted-choice_services.log --native-status 0
```

The subsequent GetFontInfo/CharWidth calls now pass; see [font-manager.md](font-manager.md).
The current stop is `PALETTE MANAGER / SETPALETTE`,
Misc1+$10FA, trap $AA95. The integrated observer now proves the actual WIND 128 request as well as preference zero.
Full drawing, replacement in-game interfaces, window/viewport and frame acceptance
remain required by the queue.

Native evidence uses `tmp/m2-choice-native.log`, `tmp/m2-choice-fresh.log` and
`tmp/m2-choice-low.log`, all normal exits with positive completion. The fresh
run creates the default size-one PREF; existing inputs one and zero both become
zero with all nine unrelated bytes preserved. The tests restore the original
on-disk preferences. Those selection-only captures ended with 36/62 windows and 43/51 completed
services. Current startup reaches window-palette binding with 68/94 windows and 124/132
services; original resource bodies total 32 / 130,692 bytes. The checker also
rejects visibility, cleanup, preference, duplicate-capture and timeout failures.


## Integrated main-window acceptance

`amiga/choice_services.gdb` now continues from hidden item selection through the
actual Misc1+$109A GetNewCWindow call. It distinguishes that call from the earlier
WIND 131 background-hider request at +$1272. The previous attempt that stopped at
131 remains rejected; title-state support removed its prerequisite.

The accepted call requests WIND 128, null storage and behindWindow=-1, with an
initial zero result slot and size preference zero. The checker normalizes only
the verified A5-relative address relocation in the 44 original bytes at
Misc1+$1070–$109B (SHA-256
`474f8a03c2ddd2d18c9367305105c552f8e79613077ee7cb114d754752f9e5fe`).
It validates the live site, full instruction bytes and operand=A5−$11B54.

Existing size-one, fresh preferences and existing size-zero runs all pass with
actual exit zero: `tmp/m2-wind-native-existing.log`,
`tmp/m2-wind-final-fresh.log` and `tmp/m2-wind-final-low.log`.
The complete before/after preference bytes and requested window match the two
Mac captures. Hidden dialog state, item selection, disposal and world restoration
remain checked, and the next stop is window SetPalette at Misc1+$10FA.
Original preferences are restored.

```sh
python3 tools/check_choice_services.py tmp/m2-choice-services-reference.log --status 0 \
  --native tmp/m2-wind-native-existing.log --native-status 0 \
  --selection-reference tmp/m2-screen-choice-reference.log --selection-status 0
```

For the size-zero native capture, use `tmp/m2-screen-choice-low-reference.log`.
Checker fixtures reject wrong sites/IDs/instructions, unrelated preference
changes, mismatched inputs, visibility, incomplete runs and timeouts. The native
executable is unchanged from the fully validated title commit, so its twenty
startup regressions, host suite, boot/resource-read and no-float audits remain
applicable. This proves selection, not window geometry, viewport or rendering.
