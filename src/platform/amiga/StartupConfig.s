| Loader-patchable boolean: magic "AITDHIRE", word value, reserved word.
	.section .data.hires,"awR"
	.balign 4
	.long 0x41495444
	.long 0x48495245
	.globl aitd_hires_value
	.type aitd_hires_value,@object
aitd_hires_value:
	.word AITD_HIRES
	.size aitd_hires_value,2
	.word 0
