# Static map

Measured from the Alone In The Dark 1.0 application resource fork.

## CODE 0 and the A5 world

CODE 0 is 3,760 bytes: 3,776 bytes above A5, **75,616 bytes below A5**, a
3,744-byte jump table at A5+32 with 468 entries. Every entry is in the standard
unloaded form `offset, MOVE.W #segment,-(SP), _LoadSeg`.

75,616 bytes of globals exceed the ±32 KB reach of `d16(A5)`, so the program
must address part of its globals another way (far model). Vette's redirection of
Page-0 globals to `d16(A5)` slots therefore does not carry over; the runtime
keeps those shadows in a private block (`s_portLowMemory` in `MacLoader.cpp`)
and a patch must use an addressing mode that reaches it.

## Segments

| CODE | Name | Bytes | Header | Jump entries | CREL |
| --- | --- | --- | --- | --- | --- |
| 1 | (unnamed) | 1,234 | `0000 000A` | 0–9 | — |
| 2 | Notes | 4 | `FFFD 8000` | none | — |
| 3 | Core | 20,590 | `800A 803C` | 10–69 | 290 B |
| 4 | Dark | 27,692 | `80AF 8047` | 175–245 | 2,564 B |
| 5 | Dark2 | 26,108 | `80F6 8014` | 246–265 | 3,408 B |
| 6 | Dark3 | 18,502 | `810A 8033` | 266–316 | 2,104 B |
| 7 | Engine | 20,428 | `813D 803F` | 317–379 | 786 B |
| 8 | Gloss | 2,538 | `817C 800B` | 380–390 | 200 B |
| 9 | Misc1 | 4,796 | `8187 802D` | 391–435 | 158 B |
| 10 | Misc2 | 15,226 | `81B4 8020` | 436–467 | 1,482 B |
| 11 | Misc3 | 11,704 | `0046 801E` | 70–99 | — |
| 12 | Dan1 | 25,322 | `8090 801F` | 144–174 | 2,378 B |
| 13 | Dan2 | 17,292 | `8064 802C` | 100–143 | 1,288 B |

The header's first word is the segment's first jump-table index and the second
its entry count; the ranges tile all 468 entries exactly. Bit 15 of the first
word is set on exactly the segments that have a CREL resource (CODE 1 clears
it once relocated); bit 15 of the
second word is set on every segment except CODE 1 (meaning not yet known).
Jump-table routine offsets are relative to the end of the four-byte header, as
in the standard layout. The first entry, CODE 1+$0014, is the application entry.

CREL is a list of 16-bit offsets into the CODE resource (header included),
7,329 entries in all; the Dark, Dark3, Dan1 and Dan2 lists are not sorted.
Each offset names a longword to relocate:

- **Even offset (7,210): add A5.** The stored values are A5-relative: 1,547
  point at a jump-table `JMP` (A5+34+8n), so `JSR $0DDA.l` in Dark calls entry
  439; the other 5,663 lie in the far globals (−75,616..−1). Some are 68020
  `bd.l` base displacements (`([$FFFF3184],D0.L)`), not only `abs.l`
  operands. Measured under MAME: all 608 intact even sites of a loaded Misc2
  held value+A5.
- **Odd offset (119): add the `STRS` resource base.** The longword is at
  offset & ~1; every value (0..1,804) indexes a C string in the 1,810-byte
  `STRS` 0 resource (`"itd_ress.pak"`, `":Alone Data:%s"`, …).

## CODE 1: the THINK C runtime

CODE 1 is the startup and segment runtime; the port runs it unmodified.

- Entry (+$14): clear FPState, compute the address mask (`StripAddress`), take
  the `STRS` base, build the A5 world, patch the segment traps, call `main`
  (A5+$24A = entry 69 = Core+$03E4), unpatch, `_ExitToShell`.
- A5 world (+$0118): from `CurStackBase` ($908, = A5−75,616) up to A5, copy
  `DATA` words; after each zero word clear the number of bytes the next `ZERO`
  word gives (both consumed exactly). Then `DREL` (276 entries): a negative
  word is an A5 offset, otherwise two words form a negative 32-bit offset;
  bit 0 clear adds A5 (255), set adds the `STRS` base (21). 117 of the
  relocated longs are jump-table function pointers.
- Trap patches (+$043E): old-style `GetTrapAddress`/`SetTrapAddress` stubs
  `JSR handler; JMP original` for `_LoadSeg`, `_UnloadSeg` and `_ExitToShell`;
  the stub block pointer is stored at A5+$68, inside loaded entry 9.
  - `_LoadSeg` (+$60): `GetResource('CODE')`, `MoveHHi`/`HLock` if unlocked;
    if header bit 15 is set, clear it and apply `CREL` (base = the CODE
    master pointer, header included); fill the jump-table entries
    (`seg, JMP ptr+4+offset`); flush caches; return into the new `JMP`. The
    system `_LoadSeg` is never called.
  - `_UnloadSeg` (+$CC): `HUnlock` and restore the unloaded entries; no purge.
- Cache flush: `_vCacheFlush` ($A0BD) if implemented; only otherwise the
  privileged `CPUSHA` (CPUFlag ≥ 4) or `MOVEC CACR` (≥ 2) fallback at
  +$0272/+$0276.
- Jump-table entries 4–8 are 32-bit multiply/divide helpers; 1–3 (switch
  helpers) have no callers.

The current runtime loader still resolves every jump-table entry itself and
stops with `SEGMENT LOADER / CREL RELOCATION`; design.md §4.2 replaces that
with CODE 1's own path.

## CPU requirements

`tools/m68k_sweep.py` (recursive descent from all 468 entries, dual 68040/68000
decode, 74.1% of CODE bytes reached) finds **319 68020-only instructions on
reachable paths** in 12 of the 13 segments: `EXTB.L`, `MULU.L`, scaled-index and
memory-indirect addressing, and bitfield instructions. The game requires a 68020
or better; Vette's 68000 target does not apply. The port's C/C++ uses
`-m68020 -mtune=68030 -msoft-float`; GNU as uses `-mcpu=68020 -mno-float`
(no scheduling option exists in this assembler). The no-float link audit rejects
libgcc floating-point helpers; the probe audit remains mandatory. The inherited
vasm framework glue retains its 68010 instruction limit, a subset of the target.

The only privileged instructions are CODE 1's cache-flush fallback (not
reached when `_vCacheFlush` is implemented) and the music driver's legacy
output path (not reached with Sound Manager 3).
