# Eight-bit offscreen worlds

The first original request is Misc2+$0074, QDExtensions selector 0. It asks for
8-bit pixels, flags 8 (`keepLocal`), no explicit device, a supplied 256-entry
colour table and bounds (0,0)–(648,401). The allocator now creates real current-zone
storage; unsupported depth/flags/table forms and allocation failures stop at
NEWGWORLD. The original instructions remain unchanged.

The result has a 108-byte fixed colour port and 27 independently owned movable
handles: two PixMaps, pixels, a copied colour table, visibility and clip regions,
GrafVars, a private GDevice and inverse table, and three complete PixPat trees.
Both device and port PixMaps share the pixel and colour-table handles. All new
handles are unlocked and non-purgeable. Pixel contents are uninitialized; they
are not accepted as a rendered frame. The subsequent original initialization
binds and clears the world and remains the next queue item.

Measured allocation details:

- 652-byte rows: rounded-up 32-bit row alignment plus the extra four-byte word
  inherited from Vette. Pixel storage is 261,452 bytes.
- The unlocked PixMaps store the pixel **handle** in baseAddr and version 2.
  Pixel depth and component size are 8, component count 1, resolution 72 dpi.
- The port version is `$C001`, visibility is the full world and clipping is
  initially (−32767,−32767)–(32767,32767).
- The supplied 2,056-byte colour table is copied exactly, including its seed.
  Its handle is temporarily protected against purging during allocation; the
  caller's original flags are restored before return.
- The private GDevice has its own PixMap and 4-bit-resolution inverse table.
  NewGWorld leaves the current device, main GDevice and screen unchanged.
- The Pascal call pops 22 argument bytes and leaves the zero OSErr result.
  D0–D2 are zero, A0 is the output pointer, A1 is the visibility-region body;
  D3–D7/A2–A6 are preserved.

The registry refreshes cached movable body addresses whenever the Memory
Manager refreshes its views. Cleanup disposes every owned handle and the fixed
port before resetting the zones. Capacity and unsupported allocations remain
explicit stops rather than guessed Macintosh errors.

## Inverse colour lookup

Direct Manhattan and Euclidean nearest-colour comparisons did not match the
original table. Instrumenting the System 7.5.5 MakeITable entry established the
actual algorithm: quantize colours to a padded cube, seed first/last/intermediate
palette entries in that order, record same-cell collision rings, and fill unused
cells breadth-first. The neighbour order reverses on every dequeued cell.

`GWorld8.h` implements that integer algorithm. Its resolution-4 result matches
all 4,096 original lookup bytes, the seed/resolution header, collision count 85
and all 256 collision links. The final 256 scratch bytes in the allocated table
are undefined on the Mac and are cleared natively; they are excluded from the
semantic comparison. The separate grey-only builder remains unsupported.
Resolution 5 has host coverage; its original-call acceptance remains with the
broader QuickDraw work when reached.

## Verification

Original Misc2+$0050–$0075 has SHA-256
`4a24b196d92950126c330581d9d5c728c555769313b05bcbfd61cd0c9699d5a5`.

`tools/mac_newgworld.lua` captures the constructor and queries all auxiliary
handles with CPU-executed Memory Manager calls. `amiga/newgworld.gdb` captures the
native records and owning heap. `tools/check_newgworld.py` validates all defined
record bytes, pointer relationships, master slots, block ownership, flags,
lengths, call ABI, colour-copy independence and unchanged screen/device state.
`tools/check_gworld8.py --reference` also compares the pure inverse builder with
the local Mac capture; its normal host test covers layout bounds, every valid
row width, exact PixMap bytes and both supported inverse resolutions.

The local reference is `tmp/m2-newgworld-ownership-all.log`; its dumps and the
MakeITable disassembly remain under ignored `tmp/`. No original resources,
System software bytes or captures are committed.
