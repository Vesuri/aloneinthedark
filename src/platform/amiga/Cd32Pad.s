| CD32 gamepad buttons on port 1: uint16_t aitd_cd32_read(void), result in d0.
|
| The stick reads through JOY1DAT like a joystick. The seven buttons come off
| a shift register on three pins:
|   pin 6 (FIR1) = CIA-A PRA bit 7, DDRA bit 7     clock, driven by us
|   pin 5 (POTX) = POTGO bits 13/12 (OUTRX/DATRX)   driven low: shift mode
|   pin 9 (POTY) = POTGOR bit 14 (DATRY)            serial data, active low
| Ten bits shift out MSB first. Result, bit set = pressed:
|   $0200 blue  $0100 red  $0080 yellow  $0040 green
|   $0020 forward  $0010 reverse  $0008 play  $0003 pad marker bits
|
| The tst.b CIA reads are the protocol's settle time (~1.4 us each, E clock
| synchronised): six before the first bit and eight before each other bit.
| Keep them verbatim; Rescue on Fractalus took this sequence from Attack of
| the PETSCII Robots' readCD32Pad, the version known to work on real pads.
| DDRA bit 7 and the POTGO word are restored. Call with interrupts disabled.
	.section .text.aitd_cd32_read,"ax"
	.even
	.globl aitd_cd32_read
aitd_cd32_read:
	movem.l d2-d5,-(sp)
	lea 0xbfe001,a0
	lea 0xdff000,a1
	move.w 0x16(a1),d2
	moveq #7,d3
	moveq #14,d4
	bset d3,0x200(a0)
	bclr d3,(a0)
	move.w d2,d1
	and.w #0xcfff,d1
	or.w #0x2000,d1
	move.w d1,0x34(a1)
	moveq #0,d0
	moveq #10-1,d5
	bra.s .Lsettle
.Lbit:
	tst.b (a0)
	tst.b (a0)
.Lsettle:
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	tst.b (a0)
	move.w 0x16(a1),d1
	bset d3,(a0)
	bclr d3,(a0)
	btst d4,d1
	bne.s .Lreleased
	bset d5,d0
.Lreleased:
	dbra d5,.Lbit
	bclr d3,0x200(a0)
	move.w d2,0x34(a1)
	movem.l (sp)+,d2-d5
	rts
