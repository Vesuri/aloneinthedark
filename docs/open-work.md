# Open work

Current state: the executable builds, loads the original resource fork, builds
the A5 world and stops at `SEGMENT LOADER / CREL RELOCATION` on CODE 3 "Core".

1. **Segment relocation.** Apply CREL to the resident copies: even offsets +A5,
   odd offsets + segment base (see [static-map.md](static-map.md)); measure the
   odd-entry base from CODE 1's loop at +$01B0.
   Confirm the THINK C / Symantec inference in
   [source-inventory.md](source-inventory.md).
2. **A5 world initialisation.** Establish whether CODE 1 expands `DATA`/`ZERO`
   and applies `DREL` itself, as a far-model runtime would, or expects the
   loader to.
3. **Bring-up by loud stop.** Implement each new Toolbox call as it appears,
   starting with the File Manager for the `.PAK`/`.ITD` files in `Alone Data`.
   The game uses System 7 QDOffscreen calls (`GetGWorldPixMap`), so GWorlds
   follow System 7 semantics.
   Check for the privileged `MOVEC CACR` in CODE 1.
4. **Display.** Replace the four-plane, 16-color path with eight planes and a
   256-entry palette (AGA). Only the game's 320×200 mode is supported, so the
   Vette-derived `HIRES` build option goes.
5. **CPU target.** The original needs a 68020. Decide whether the port's own
   code moves to `-m68020` (retiring the 68000 mul/div audit) or keeps it.
6. **Reference automation.** The System 7.5.5 volume runs the original (see
   [mac-reference-loop.md](mac-reference-loop.md)); give the launch scripts an
   8-bit framebuffer path and re-measure the in-game coordinates.
7. **Audio.** Map the game's Sound Manager and MIDI driver use to Paula.
8. **Release.** WHDLoad slave and standalone installer, adapted from Vette's.
