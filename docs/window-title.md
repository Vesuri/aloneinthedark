# Hidden window titles

The original Misc1+$1296 SetWTitle call renames WIND 131, the invisible
"Background Hider", from `New Window` to `Hider`. This is compatibility state;
it draws no window chrome, dialog or menu bar. Original game instructions stay
unchanged. Full window geometry and viewport acceptance remain M2.4.

## Reference contract

`tools/mac_window_title.lua` observes the real call and its return in headless
MAME. `tools/check_window_title.py` verifies the original Misc1+$128C–$1297
bytes (SHA-256 `e2db8225b409eb6628d60db59a5148cd1b2229bd52caa216af43e59e794479b0`),
allowing only the measured relocation of the Pascal-string address. It also
checks the complete original WIND 131 body.

The title handle and body stay stable. The six-byte result is `\x05Hider`;
GetHandleSize returns six. Only the titleWidth word at window offset 138 changes,
from 85 to 34. The 156-byte window record is otherwise unchanged, as are the
five region headers, WMgrPort, current-port identity and input string.

The reference calls StringWidth with font 0, face 0 and size 0. A CPU-executed
fixture measures all 95 printable ASCII advances under that same port state.
The checker verifies the complete fixture instructions, stack balance, output
extent, the installed advances, and both title sums. These numeric metrics feed
the existing port-owned system placeholder font; no Mac glyph artwork is used.
Other faces retain their existing placeholder advances.

The accepted reference is `tmp/m2-title-reference-contract.log`, with normal
terminal exit zero and both positive completion records. Captures stay local.
The first checker used the wrong WIND title offset (16); original bytes establish
18, after bounds, procID, visible, goAway and refCon. That rejected checker run
is not acceptance evidence.

## Native service

WIND construction reads the title at offset 18, goAway at 12 and refCon at 14.
It allocates an owned title handle and obtains its width through the installed
system font. SetWTitle supports hidden, owned non-dialog windows and printable
ASCII titles. It copies input before resizing to allow an aliased input pointer,
updates the title and cached width, and draws nothing. Other forms stop by name;
allocation failures also stop explicitly. Disposal releases the owned handle;
zone teardown clears ownership pointers.

`amiga/window_title.gdb` observes the original native call without injecting
inputs. The paired checker verifies the complete record delta, input and port
preservation, stable handle/body, title allocation sizes 11 then 6, unchanged
regions and logical screen, and original MDRV absence. These checks do not prove
rendered display acceptance. The run advances to SetPalette at Misc1+$10FA,
a separate window-palette binding request.

The guarded native capture `tmp/m2-title-native-guarded.log` exits zero and passes
the paired checker. It records 68 OS windows, 124 completed services, original
resource bodies 32 / 130,692 bytes, and overlay bodies 31 / 80,650 bytes.
The first native run used the stale generated overlay and was rejected for wrong
widths; regeneration supplies the measured advances. The overlay is now 81,462
bytes, with unchanged 33 metadata reads / 572 bytes.

## Reproduction

Use the headless MAME command in [mac-reference-loop.md](mac-reference-loop.md)
with `-autoboot_script tools/mac_window_title.lua` and a bounded timeout. Require
actual exit zero before passing `--status 0` below.

```sh
python3 tools/check_window_title.py tmp/m2-title-reference-contract.log --status 0
. amiga/env.sh
(cd amiga && EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=window_title.gdb ./diag_run.sh 300)
python3 tools/check_window_title.py amiga/.run/gdb-out.log --native --status 0
```

Keep the reference `title-reference-*.bin` files in `tmp/` for the paired check.
The native runner writes `title-native-*.bin` there. All twenty startup observers
and paired service checks pass (`tmp/m2-title-startup-suite.log`), as do the full
host suite (`tmp/m2-title-host-final.log`), fresh/low preferences, clean boot and
resource-read, and the final paired title run (`tmp/m2-title-native-final.log`).
Every accepted run has a positive completion marker and actual zero exit status.

Existing/fresh preferences complete 68/94 OS windows and 124/132 services;
original preferences are restored. A5 matches all 75,616 bytes, low-memory sites
remain 58 validated / 55 applied, and no-float / 78-symbol audits pass. The clean
production executable matches the startup regression binary. These are service
and startup checks, not intro or rendered-window acceptance.
