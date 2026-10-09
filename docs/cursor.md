# Cursor display and obscuring

Original-game presentation now enables the pointer. Two AGA sprites provide black and
white without replacing any game colour: playfield XOR 1 and the matching palette
permutation select existing protected endpoint colours.

Startup reaches original CURS 132, which contains two inversion pixels.
`mac_cursor_invert.lua` measures the real QuickDraw cursor over all 256 indexed values.
Every inversion pixel is XORed with 255; hiding restores every byte, with no palette
changes or writes outside the cursor. The capture `tmp/m2-cursor-invert-reference.log`
exits 0.

`CursorInvert` applies that exact mask to all eight planes after VBI pointer
publication. The next VBI removes the old mask before applying the current
shape/position. Frame synchronization copies one plane span under a short interrupt
guard and removes any applied XOR from the copied bytes. Thus queued bitmaps remain
clean while movement also works without new frames. Only the 16-row mask and position
are retained; no pixel background is saved.

Synchronization copies each rectangle converted for the previous frame unless one
rectangle converted this frame contains it (`Planar8::syncNeeded`); the conversion that
follows overwrites any partial overlap. Copied spans retain the same cursor removal and
interrupt guard; no pixel cache or shadow framebuffer exists. The sanitizer-backed
planar check verifies 400 alternating-buffer frames with merged, overlapping, empty,
full and overflowing updates against complete decoded pixels. The PAL/NTSC cursor
fixtures have not been rerun since this rectangle form replaced row masks.

```sh
python3 tools/check_cursor_invert.py tmp/m2-cursor-invert-reference.log --status 0
python3 tools/check_cursor_capture.py tmp/m2-cursor-motion-pal-full.log --status 0 --video PAL --inversion --folder tmp/m2-cursor-motion-pal
python3 tools/check_cursor_capture.py tmp/m2-cursor-motion-ntsc-full.log --status 0 --video NTSC --inversion --folder tmp/m2-cursor-motion-ntsc
python3 tools/check_aga_capture.py startup tmp/m2-pointer-game-startup-full.log --status 0 --pointer
```

Both baseline native fixtures pass five clean C2P frames, every pixel and all 256
colours, both sprite buffers, inversion, movement without a new frame, clipping, hiding,
disabling and cleanup. Cursor work ends by line 17 in PAL and NTSC, with no late
publications. The original-game first viewport also passes with pointer mode enabled.
Owner-provided F12+S captures on 2026-10-02 now pass rendered acceptance: the game arrow
on black, white and coloured artwork, plus the PAL/NTSC ramp fixtures with movement and
edge clipping. See the M2 completion record in [development.md](development.md).
Autonomous host-window capture remains restricted; these were saved by the owner.

## Obscuring

Original Engine+$0FF6 calls ObscureCursor after FindWindow identifies content under the
pointer. Bytes at +$0FEA–+$0FF7 are `0c47000366084a2c00136602a856`; no game instructions
change.

The Mac reference separates explicit hide level (CrsrState, $8D0) from temporary
obscuring ($8D2). ObscureCursor sets the latter without changing the hide level. It
clears visibility ($8CC) and returns D0=1 if the cursor was visible; otherwise D0 is
unchanged. D1–D7/A1–A6 and the caller's stack are preserved. A0 is Mac scratch state;
the port preserves it additionally.

`CursorVisibility` retains those independent states. InitCursor resets both. HideCursor
decrements the explicit level, stopping on overflow; ShowCursor increments a negative
level, or clears obscuring when already at zero. The reference fixtures distinguish
ShowCursor after obscuring from ShowCursor after both explicit hiding and obscuring.
Physical mouse movement clears obscuring, while explicit hiding still suppresses
visibility. The native VBI applies that transition and publishes visibility with
position; it never invokes original callbacks or opens an OS window. Shared state is
volatile.

The AGA pointer remains subject to the `m_mouseAllowed` gate, now enabled for
original-game presentation. These checks establish logical cursor state and publication,
not rendered pointer acceptance.

Reproduce with the headless MAME command and `tools/mac_obscure_cursor.lua`. It captures
the original call, nine Init/Hide/Show/Obscure fixtures and restoration through emulated
ADB mouse movement. The native combined `menu_lifecycle.gdb` observer captures the
original call and its preserved registers, image and stack.

```sh
python3 tools/check_cursor_visibility.py --reference tmp/m2-cursor-reference-final.log --status 0
python3 tools/check_obscure_cursor.py tmp/m2-cursor-reference-final.log --reference-status 0
```

Supply actual terminal statuses. The helper's eleven measured states run under
ASan/UBSan, with additional hidden-movement and overflow checks. No host window capture
or host input injection is used.

`check_obscure_cursor.py --native` requires a current combined `menu_lifecycle.gdb`
capture with the complete startup ledger. This is separate from the new pointer fixture
and original-game viewport acceptance above.
