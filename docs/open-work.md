# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## M6 Completion

- **M6.1 Full manual play-through,** in MAME and on `a1200-020`, with the runtime
  trap log. Implement every new trap and path it finds.

  *Done when* the game can be finished on the Amiga with no loud stop.
- **M6.2 State-keyed fidelity set.** Frame compares for representative rooms,
  inventory, book/reading views, fights, death, new-game restart and the ending.
  Pair idle animation frame and interpolation phase before exact restart pixels.

  *Done when* all of them pass.
- **M6.3 Stairs check.**
  - Add the `stairs` regression (attic → storeroom descent) on every config,
    including `a1200-060`.
  - No frame cap (D3). If the descent fails anywhere, file a separate item for
    the owner, with the measured frame rate.

  *Done when* the case runs on all configs and its result is recorded.
- **M6.4 Quit and cleanup.** A `quit` regression: all ledgers empty, the OS
  restored, and both Workbench and Shell starts work.

  *Done when* it passes on all configs.
- **M6.5 Remaining visible Mac font faces (D6).** Capture and bundle raw
  original bitmaps for reached visible families/sizes beyond Times/plain/14,
  including pause. Preserve glyph bearings, styles and measured text layout.

  *Done when* every reached visible Mac-font draw uses the original bitmap
  artwork and state-matched text captures agree with MAME.

## M7 Release

- **M7.1 Installer:** Vette's `install-data` extractor, an Installer script and
  icons, run against `AloneInTheDark.img_.sit` with the known hashes checked.
- **M7.2 WHDLoad slave,** from `VetteSlave.s`: EmulLineA, a 64 KB stack, the
  resload file backend (chunked reads, saves), with the WHDLoad test modes.
  Bind the persistent read-stream API/cache to resload rather than DOS; pass the
  same read/seek/EOF/cache fixture under WHDLoad with zero OS-window entries.
- **M7.3 Packaging and 1.0:**
  - a deterministic LHA;
  - `make release-check`;
  - README requirements from measured numbers;
  - VERSION 1.0.
