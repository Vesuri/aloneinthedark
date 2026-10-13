| CopyBits retains the ordinary C drawing/validation contract. Skip repeated
| dispatch only inside an unfinished scene with no due callback/effect service.
	.section .text.aitdCopyBitsQuick,"ax"
	.even
	.globl aitdCopyBitsQuick
	.type aitdCopyBitsQuick,@function
aitdCopyBitsQuick:
	.include "../src/platform/amiga/QuickSceneGuard.inc"
	jmp aitdCopyBitsQuickDraw
.miss:
	jmp aitdCopyBitsQuickMiss
	.size aitdCopyBitsQuick,.-aitdCopyBitsQuick
