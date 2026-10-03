# Menu records

D7 keeps menu data and keyboard commands without drawing a menu bar. The
original Engine startup loops over MENU 128–131, counts their items, reads their
Pascal labels and removes the `|command` suffix through SetMenuItemText. The
port implements those record operations; the game's code still interprets and
stores the commands. Menu rendering and Mac MDEF execution are not involved.

## Gameplay keyboard route (M3.2 in progress)

The original keyboard run returns MENU 129/item 2 for Command-S, item 1 for
Command-O and item 4 for Command-Q. The native Right-Amiga route returns the
same packed results. S and M reach the game's sound/music feedback; M stops
and resumes song 137. SetItemMark uses the actual packed menu item mark byte.

The 68030 native fixture entered `m3test` and Return in the save prompt,
returned to gameplay, opened Load and cancelled back to gameplay. The save
created a 36,254-byte data fork containing that name and a thumbnail resource
fork. This is an in-session save/Load-menu check; reset-and-load acceptance
remains M3.6. Quit reaches Core+$1DCC driver selector 8, which remains a named
stop. M3.2 remains open until that cleanup and the paired viewport audit pass.

The reached save path additionally needs PBCreate's standard version byte at
offset 26 (27 is the open-permission byte), InsetRect, contained indexed
CopyBits scaling and picture recording. OpenPicture/ClosePicture record one
same-world CopyBits into the requested frame without changing visible pixels.
`PictureRecord8.h` writes a bounded v2 PackBits picture retaining source
pixels, rectangles, palette and mode. Its encoding can differ from QuickDraw's
padding/compression; the independently decoded source pixels and colours
match the original save picture exactly. Other recording operations remain
unsupported. Staging buffers use owned handles; the compiled copy/record
helper's frame, including saved registers, is 368 bytes.

`tools/mac_picture_record.lua` captures the original save operation through
normal keyboard input. After capturing, run
`python3 tools/check_picture_record8.py --reference-dir tmp` to compare its
record with the native writer under address/undefined-behaviour sanitizers.
The native keyboard fixture is `MENUPROBE=1 PROBES=1`; clean before changing
these flags. It uses ordinary raw key events, including `m3test` plus Return,
and never writes game flags or invokes original game functions directly.

## Original contract

`mac_menu_records.lua` observes original Engine+$2DEE CountMItems,
+$2E0C GetMenuItemText and +$2EC2 SetMenuItemText. It changes no instructions,
arguments, menu data or RNG. Original bytes through the loop's return are
fingerprinted by `check_menu_reference.py`.

The bounded reference reaches the second Times lookup with 33 menu calls:
4 counts, 17 reads and 12 text replacements. Counts are 3/4/6/4. Every count
returns a word in the caller's reserved slot, popping four argument bytes;
text calls pop ten. D0 returns zero, and D3–D7/A2–A6 are preserved. Volatile
registers, including D1/D2 and A0/A1, are not a preservation contract. Native
calls preserve additional scratch registers; the original loop does not depend
on their reference clobbers.

Count/read leave the menu record unchanged. SetMenuItemText replaces only the
requested label, preserving all item icon/key/mark/style bytes, other labels,
title, flags and MDEF field. It invalidates cached width/height to -1. The input
Pascal string is unchanged. The capture checks the actual records before and
after every call, rather than assuming the result from the returned count.

### System-only item

The reference System appends `\0\0Control Panels` to Apple MENU 128 through
AddResMenu. It is absent from the original application MENU resource. The native
application/data/overlay resource chain contains no DRVR resources and appends
nothing. Its Apple count is therefore **2**, and it performs 32 calls: four
counts, sixteen reads and the same twelve mutations. No count is invented to
match a different resource set.

This System-only label has no `|` command suffix. The original loop's null
`strchr('|')` branch skips registration; its leading NUL also converts to an
empty C label. It provides no game command, key equivalent or menu bar in D7's
native environment. The paired checker requires exactly this reference-only
extra item and compares every application item, including its metadata. It
never ignores other count/text differences.

Mac menu dimensions/MDEF pointers established by the system before these calls
are platform-specific. Native GetMenu retains the original resource values and
D7 does not draw the bar or execute MDEF code. The comparison therefore checks
ID/title/flags and all packed items; within each run, count/read preserve the
whole record, and replacements must invalidate dimensions and preserve MDEF.

## Native implementation

`MenuRecords.h` parses bounded title/item records. Native CountMItems reads the
actual handle; GetMenuItemText copies the selected Pascal label. SetMenuItemText
saves its input before any handle relocation, grows before moving a tail and
shrinks afterward, keeping the same master pointer. Byte copies use a volatile
intermediate to avoid the known GCC shared-base postincrement defect.

Nil/malformed records, invalid item numbers and empty replacement labels remain
named trap stops until their behavior is required and measured. Host sanitizer
checks cover 510 length-changing replacements (1–255 bytes, both first and last
items), exact metadata/tails, output guards, empty menus and truncated records.
The native original-call observer validates all 32 calls and compares each
record and text with the Mac. The next stop is Engine+$47C2 screen-size-selection; this is
not second-font, graphics or complete startup acceptance.

## Reproduce

The reference probe reuses the shared MAME input library and byte-verified
System 7.5.5 dispatcher. It reads the internal debugger console to expose action
errors. Earlier missing-call runs were rejected; the console identified an
unsupported conditional debugger command before the probe moved to the three
original call-site breakpoints. See MAME's
[debugger Lua API](https://docs.mamedev.org/luascript/ref-debugger.html).

```sh
. amiga/env.sh
SDL_VIDEODRIVER=dummy timeout -k 5 90 mame maciix \
  -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 180 \
  -snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
  -nvram_directory ref/mame/nvram -debug -debugger none -oslog \
  -autoboot_script tools/mac_menu_records.lua >tmp/m2-menu-reference.log 2>&1
reference_status=$?
python3 tools/check_menu_reference.py tmp/m2-menu-reference.log \
  --status "$reference_status"
(cd amiga && GDBTAIL=300 EXTRA_ARGS=--warp_mode=1 \
  GDBSCRIPT=menu_records.gdb ./diag_run.sh 60) >tmp/m2-menu-native.log 2>&1
native_status=$?
python3 tools/check_native_menu.py tmp/m2-menu-native.log \
  --status "$native_status" --reference tmp/m2-menu-reference.log \
  --reference-status "$reference_status"
```

Both checkers require normal status, exact call order/count, original bytes,
positive completion, stack/register evidence and complete records. The paired
checker also rejects deliberately corrupted versions of the actual capture.
Logs, record dumps and original data remain local-only.


The capture-literal audit regenerated `tmp/m2-literals-menu-reference.log`.
Bare $A0/$A4/$D0/$D4 dump offsets formerly read registers, but only in padding:
all 33 calls retain exactly the same menu bodies (at most 97 bytes) and text
(at most 30 bytes). The corrected full dumps pass the original checker and
pair with the accepted native records. See the impact inventory in
[mac-reference-loop.md](mac-reference-loop.md).


## Hidden startup menu-list lifecycle

The original Engine+$2B06 ClearMenuBar, four +$2B32 InsertMenu calls and
+$2B44 DrawMenuBar now complete. Reset removes membership without disposing
MENU handles or changing their records. Insertions retain the original order
128, 129, 130, 131 and return zero with the measured stack cleanup. DrawMenuBar
returns successfully without drawing any pixels under D7. Callee-preserved
registers match; system-internal volatile pointers are not portable outputs.

The Mac automatically appends System menus −16490 and −16489 after the first
insertion. They are absent from the port's menu registry and have no native
presentation. The comparison identifies these exact two IDs separately; it
still checks every game menu, title, flag and packed item. Apple menu 128's
reference-only Control Panels item is the existing documented System addition.
Menu dimensions and MDEF pointers remain platform-specific as above.

`tools/mac_menu_lifecycle.lua` captures each list transition and a CPU-executed
nonempty reset of the same four live menus. That fixture confirms their records
survive unchanged. `amiga/menu_lifecycle.gdb` captures the original native setup,
with both font lookups, driver initialization, main/A5 and AGA checks in the
same bounded run. `tools/check_menu_lifecycle.py` requires original/live bytes,
six call results, ordered identities, unchanged application items and no native
screen changes. The original Mac game client also stays unchanged across its
DrawMenuBar call. These memory checks do not claim rendered-video acceptance.

Original Engine+$2B04–$2B45 SHA-256:
`d302ea1079ba3557d446a85bc8faafa1f23e92b2152cf06fab8daa8bb2a29e51`.
Reference: `tmp/m2-menu-lifecycle-reference-final.log`; native:
`tmp/m2-menu-lifecycle-native-final.log`. Supply each actual exit status with
`--reference-status` and `--native-status` to the paired checker.
Startup now stops at QUICKDRAW / UNIONRECT, Dan2+$01DA.
