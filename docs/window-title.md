# Hidden window titles

The measured hidden-window title and text contracts pass startup/intro acceptance; no
Mac window chrome is displayed.

The original Misc1+$1296 SetWTitle call renames WIND 131, the invisible "Background
Hider", from `New Window` to `Hider`. This is compatibility state; it draws no window
chrome, dialog or menu bar. Original game instructions stay unchanged.

## Reference contract

`tools/mac_window_title.lua` observes the real call and its return in headless MAME.
`tools/check_window_title.py` verifies the original Misc1+$128C–$1297 bytes (SHA-256
`e2db8225b409eb6628d60db59a5148cd1b2229bd52caa216af43e59e794479b0`), allowing only the
measured relocation of the Pascal-string address. It also checks the complete original
WIND 131 body.

The title handle and body stay stable. The six-byte result is `\x05Hider`; GetHandleSize
returns six. Only the titleWidth word at window offset 138 changes, from 85 to 34. The
156-byte window record is otherwise unchanged, as are the five region headers, WMgrPort,
current-port identity and input string.

The reference calls StringWidth with font 0, face 0 and size 0. A CPU-executed fixture
measures all 95 printable ASCII advances under that same port state. The checker
verifies the complete fixture instructions, stack balance, output extent, the installed
advances, and both title sums. These numeric metrics feed the system compatibility
font. It supplies title metrics only; titles are not drawn.
Other faces retain their compatibility advances.

## Native service

WIND construction reads the title at offset 18, goAway at 12 and refCon at 14. It
allocates an owned title handle and obtains its width through the installed system font.
SetWTitle supports hidden, owned non-dialog windows and printable ASCII titles. It
copies input before resizing to allow an aliased input pointer, updates the title and
cached width, and draws nothing. Other forms stop by name; allocation failures also stop
explicitly. Disposal releases the owned handle; zone teardown clears ownership pointers.

`amiga/window_title.gdb` observes the original native call without injecting inputs. The
paired checker verifies the complete record delta, input and port preservation, stable
handle/body, title allocation sizes 11 then 6, unchanged regions and logical screen, and
original MDRV absence. These checks do not prove rendered display acceptance. The run
advances to SetPalette at Misc1+$10FA, a separate window-palette binding request.

For paired checks, retain `title-reference-*.bin` and `title-native-*.bin` in
ignored `tmp/`. Require normal observer completion and verify record deltas,
metrics and ownership; these checks do not establish visible window rendering.
