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
word is set on exactly the segments that have a CREL resource; bit 15 of the
second word is set on every segment except CODE 1 (meaning not yet known).
Jump-table routine offsets are relative to the end of the four-byte header, as
in the standard layout. The first entry, CODE 1+$0014, is the application entry.

CREL is a list of 16-bit offsets into the CODE resource (header included).
Measured in Core, Dark and Dan2: every `JSR abs.l` whose target lies inside its
own segment (42, 262 and 202 sites) has its longword operand's offset in that
segment's CREL, and those unrelocated operands are small segment-relative
values (for example `JSR $0522.l`). CREL therefore marks longwords to relocate
by the segment's load address. Not yet known: whether the base includes the
four-byte header, what the non-JSR entries are, and why some lists are not
sorted (Dark, Dan2).

The runtime loader resolves every jump-table entry to a JMP into an aligned
resident copy and stops with `SEGMENT LOADER / CREL RELOCATION` on the first
segment that needs relocation, because resident loading bypasses the original
`_LoadSeg` path that would apply it.

## CPU requirements

`tools/m68k_sweep.py` (recursive descent from all 468 entries, dual 68040/68000
decode, 74.1% of CODE bytes reached) finds **319 68020-only instructions on
reachable paths** in 12 of the 13 segments: `EXTB.L`, `MULU.L`, scaled-index and
memory-indirect addressing, and bitfield instructions. The game requires a 68020
or better; Vette's 68000 target does not apply. The port's own C++ is still built
with `-m68000` and the mul/div audit until that choice is revisited.

The unreached residue of CODE 1 contains `MOVEC CACR` at +$0272/+$027A, a
privileged instruction that traps in Amiga user mode if reached. Confirm when
bring-up reaches CODE 1's startup code.
