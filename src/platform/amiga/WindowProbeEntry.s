	.section .text.aitd_window_probe,"ax"
	.even
	.globl aitd_window_probe
aitd_window_probe:
	.word 0xa1fc
	rts

| Native positive control for the production C-to-resload bridge.
    .section .text.aitdResloadBridgeProbe,"ax"
    .even
    .globl aitdResloadBridgeProbe
aitdResloadBridgeProbe:
    movem.l d2-d7/a2-a6,-(sp)
    move.l #285212672,d2
    move.l #285212673,d3
    move.l #285212674,d4
    move.l #285212675,d5
    move.l #285212676,d6
    move.l #285212677,d7
    move.l #285212678,a2
    move.l #285212679,a3
    move.l #285212680,a4
    move.l #285212681,a5
    move.l #285212682,a6
    clr.l -(sp)
    pea (sp)
    move.l #0x55667788,-(sp)
    move.l #0x11223344,-(sp)
    move.l #0x789abc,-(sp)
    move.l #0x123456,-(sp)
    clr.l -(sp)
    pea .resloadFixture
    jsr aitdResloadCall
    lea 28(sp),sp
    cmp.l #0xaabbccdd,d0
    bne .bridgeBad
    cmp.l #0x10203040,(sp)
    bne .bridgeBad
    cmp.l #285212672,d2
    bne .bridgeBad
    cmp.l #285212673,d3
    bne .bridgeBad
    cmp.l #285212674,d4
    bne .bridgeBad
    cmp.l #285212675,d5
    bne .bridgeBad
    cmp.l #285212676,d6
    bne .bridgeBad
    cmp.l #285212677,d7
    bne .bridgeBad
    cmpa.l #285212678,a2
    bne .bridgeBad
    cmpa.l #285212679,a3
    bne .bridgeBad
    cmpa.l #285212680,a4
    bne .bridgeBad
    cmpa.l #285212681,a5
    bne .bridgeBad
    cmpa.l #285212682,a6
    bne .bridgeBad
    moveq #1,d0
    bra .bridgeDone
.bridgeBad:
    moveq #0,d0
.bridgeDone:
    addq.l #4,sp
    movem.l (sp)+,d2-d7/a2-a6
    rts
.resloadFixture:
    cmp.l #0x123456,d0
    bne .fixtureBad
    cmp.l #0x789abc,d1
    bne .fixtureBad
    cmpa.l #0x11223344,a0
    bne .fixtureBad
    cmpa.l #0x55667788,a1
    bne .fixtureBad
    move.l #-1,d2
    move.l #-1,d3
    move.l #-1,d4
    move.l #-1,d5
    move.l #-1,d6
    move.l #-1,d7
    move.l #-1,a2
    move.l #-1,a3
    move.l #-1,a4
    move.l #-1,a5
    move.l #-1,a6
    move.l #0xaabbccdd,d0
    move.l #0x10203040,d1
    rts
.fixtureBad:
    moveq #0,d0
    rts
