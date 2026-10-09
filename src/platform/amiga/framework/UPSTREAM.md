# Framework provenance and integration

The framework derives from **dA JoRMaS / Template**, through the Rescue on
Fractalus!, Revs and Vette ports. The immediate source was Vette
`src/platform/amiga/framework`; its `VETTE_*` / `vette_*` identifiers were
renamed to `AITD_*` / `aitd_*`. Preserve upstream attribution in the source.

Included classes are AmigaHardware, Bitmap, CopperList, Sprite, Palette and
Util, with SASCCompat and compatibility headers. The game uses its own
GCCRuntime and main loop; production/part/demo orchestration and tracker
replay modules are not included. Audio uses the native SoundMusicSys driver.

## Compiler and assembly interface

The handwritten Util, AmigaHardware, Bitmap and CopperList assembler files
retain the template implementations with dotted local labels sanitized for
vasm. They assemble as ELF with `vasmm68k_mot -m68010`; `movec vbr,d0` is the
instruction requiring more than 68000 in these framework files. The game itself
targets 68020 and may use native integer multiplication/division.

GCC uses explicit register-marshalling bridges under
`ASSEMBLER && !__SASC`. `AITD_SASC_ALIAS` binds C++ statics to the SAS/C symbol
names expected by assembly. Sprite and Palette are C++. `isLongFrame()` always
uses its C++ VPOSR bit test: there is no matching assembly entry point.
Partial-link checks help expose references otherwise hidden by `--gc-sections`.

`ASSEMBLER` is enabled by default. `CPPFLAGS+=-DNO_ASSEMBLER` selects portable
C++ bodies. Clean-build when changing this or any other compilation flag.
Keep the no-float and probe-symbol audits enabled.

## Bitmap and display constraints

Bitmap storage is row-interleaved by construction; non-interleaved assembly
arms execute ILLEGAL rather than silently returning. Do not reintroduce a
layout selector without implementing and validating both representations.

The inherited setPlayfield helpers derive LACE, row modulo, display windows
and DIWHIGH from geometry instead of relying on prior register state. Their
generic AGA FMODE-3 branch is not the port's accepted display path and must not
be treated as validated merely because the OCS/ECS formulas work. AitdScreen
owns the game's AGA display setup; see [architecture](../../../../docs/amiga-arch.md).
