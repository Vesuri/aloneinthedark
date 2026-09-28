| AmigaOS version string for Alone in the Dark.
|
| AmigaDOS Version and archive-inspection tools find this by scanning the load
| image for the "$VER: " marker; no code references it.  SHF_GNU_RETAIN keeps
| the otherwise unreferenced section alive through --gc-sections.
|
| Keep the date hardcoded so identical source trees produce identical builds.
| amiga/Makefile checks the version number against the repository VERSION file.
	.section .rodata.version,"aR"
	.balign 2
	.asciz "$VER: Alone in the Dark 0.01 (27.09.2026)"
	.balign 2
