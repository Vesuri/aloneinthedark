# Cursor obscuring

Original Engine+$0FF6 calls ObscureCursor after FindWindow identifies content
under the pointer. Bytes at +$0FEA–+$0FF7 are
`0c47000366084a2c00136602a856`; no game instructions change.

The Mac reference separates explicit hide level (CrsrState, $8D0) from temporary
obscuring ($8D2). ObscureCursor sets the latter without changing the hide level.
It clears visibility ($8CC) and returns D0=1 if the cursor was visible; otherwise
D0 is unchanged. D1–D7/A1–A6 and the caller's stack are preserved. A0 is Mac
scratch state; the port preserves it additionally.

`CursorVisibility` retains those independent states. InitCursor resets both.
HideCursor decrements the explicit level, stopping on overflow; ShowCursor
increments a negative level, or clears obscuring when already at zero. The
reference fixtures distinguish ShowCursor after obscuring from ShowCursor after
both explicit hiding and obscuring. Physical mouse movement clears obscuring,
while explicit hiding still suppresses visibility. The native VBI applies that
transition and publishes visibility with position; it never invokes original
callbacks or opens an OS window. Shared state is volatile.

The AGA sprite remains subject to the existing `m_mouseAllowed` gate, which is
false at startup pending M2.5 palette ownership. These checks establish logical
cursor state and publication, not rendered pointer acceptance. SetCursor retains
its inherited visibility-reset behavior; broader cursor lifecycle remains part
of M3's reached input/window work.

Reproduce with the headless MAME command and `tools/mac_obscure_cursor.lua`.
It captures the original call, nine Init/Hide/Show/Obscure fixtures and restoration
through emulated ADB mouse movement. The native combined `menu_lifecycle.gdb`
observer captures the original call and its preserved registers, image and stack.

```sh
python3 tools/check_cursor_visibility.py --reference tmp/m2-cursor-reference-final.log --status 0
python3 tools/check_obscure_cursor.py tmp/m2-cursor-reference-final.log --reference-status 0 \
  --native tmp/m2-cursor-native-acceptance.log --native-status 0
```

Supply actual terminal statuses. The helper's eleven measured states run under
ASan/UBSan, with additional hidden-movement and overflow checks. No host window
capture or host input injection is used.
