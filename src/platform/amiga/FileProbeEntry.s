    .section .text.aitdFileProbeTraps,"ax"
    .even
    .macro filetrap name,opcode
    .globl \name
\name:
    move.l 4(sp),a0
    .word \opcode
    move.w ccr,g_fileProbeCCR
    rts
    .endm
    filetrap aitdProbeOpen,0xa000
    filetrap aitdProbeHOpen,0xa200
    filetrap aitdProbeRead,0xa002
    filetrap aitdProbeClose,0xa001
    filetrap aitdProbeEOF,0xa011
    filetrap aitdProbeSeek,0xa044
    filetrap aitdProbePosition,0xa018
    filetrap aitdProbeGetVol,0xa014
    filetrap aitdProbeSetVol,0xa015
    .globl aitdProbeOpenWD
aitdProbeOpenWD:
    move.l 4(sp),a0
    moveq #1,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeFCB
aitdProbeFCB:
    move.l 4(sp),a0
    moveq #8,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    filetrap aitdProbeHGetVol,0xa214
    filetrap aitdProbeHSetVol,0xa215
    .globl aitdProbeGetWD
aitdProbeGetWD:
    move.l 4(sp),a0
    moveq #7,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeCloseWD
aitdProbeCloseWD:
    move.l 4(sp),a0
    moveq #2,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeWriteBackend
aitdProbeWriteBackend:
    .word 0xa0fb
    move.w ccr,g_fileProbeCCR
    rts

    filetrap aitdProbeWrite,0xa003
    filetrap aitdProbeSetEOF,0xa012
    filetrap aitdProbeFlush,0xa013

    filetrap aitdProbeCreate,0xa008
    filetrap aitdProbeHCreate,0xa208
    filetrap aitdProbeDelete,0xa009
    filetrap aitdProbeHDelete,0xa209
    filetrap aitdProbeInfo,0xa00c
    filetrap aitdProbeHInfo,0xa20c
    filetrap aitdProbeSetInfo,0xa00d
    filetrap aitdProbeHSetInfo,0xa20d

    filetrap aitdProbeOpenRF,0xa00a
    filetrap aitdProbeHOpenRF,0xa20a

    .globl aitdProbeVolParms
aitdProbeVolParms:
    move.l 4(sp),a0
    moveq #0x30,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts

    .globl aitdProbeOpenDF
aitdProbeOpenDF:
    move.l 4(sp),a0
    moveq #0x1a,d0
    .word 0xa060
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeHOpenDF
aitdProbeHOpenDF:
    move.l 4(sp),a0
    moveq #0x1a,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts

    filetrap aitdProbeHGetVInfo,0xa207

    .section .text.aitdFileAsyncProbe,"ax"
    filetrap aitdProbeAsyncInfo,0xa40c
    filetrap aitdProbeAsyncHInfo,0xa60c
    filetrap aitdProbeAsyncCreate,0xa608
    filetrap aitdProbeAsyncSetInfo,0xa60d
    filetrap aitdProbeAsyncOpenRF,0xa60a
    filetrap aitdProbeAsyncGetVol,0xa614
    filetrap aitdProbeAsyncSetVol,0xa615
    .macro asyncdispatch name,selector
    .globl \name
\name:
    move.l 4(sp),a0
    moveq #\selector,d0
    .word 0xa660
    move.w ccr,g_fileProbeCCR
    rts
    .endm
    asyncdispatch aitdProbeAsyncOpenWD,1
    asyncdispatch aitdProbeAsyncCloseWD,2
    asyncdispatch aitdProbeAsyncGetWD,7
    asyncdispatch aitdProbeAsyncFCB,8
    .globl aitdFileAsyncCompletion
aitdFileAsyncCompletion:
    addq.l #1,g_fileAsyncCallbacks
    move.l a5,g_fileAsyncA5
    move.l a0,g_fileAsyncPB
    move.l d0,g_fileAsyncResult
    tst.l g_fileAsyncNested
    beq.s 1f
    movem.l d0/a0,-(sp)
    jsr aitdFileAsyncNestedCall
    movem.l (sp)+,d0/a0
1:  tst.l g_fileAsyncClobber
    beq.s 2f
    move.l #0xdeadbeef,d0
    move.l #0xaabbccdd,d1
    move.l #0xbbccddee,d2
    move.l #0xccddee00,a0
    move.l #0xddee0011,a1
2:  rts

    .globl aitdProbeAsyncRegisters
aitdProbeAsyncRegisters:
    movem.l d2/a5,-(sp)
    move.l 12(sp),a0
    move.l #0x11223344,d1
    move.l #0x22334455,d2
    move.l #0x33445566,a1
    move.l #0x12345678,a5
    .word 0xa614
    move.w ccr,g_fileProbeCCR
    cmpi.l #0x11223344,d1
    bne.s 3f
    cmpi.l #0x22334455,d2
    bne.s 3f
    cmpa.l #0x33445566,a1
    bne.s 3f
    cmpa.l #0x12345678,a5
    bne.s 3f
    cmpa.l 12(sp),a0
    beq.s 4f
3:  move.l #0xbad00001,d0
4:  movem.l (sp)+,d2/a5
    rts

    .section .text.aitdResourceLookupProbe,"ax"
    .macro namedtrap name,opcode
    .globl \name
\name:
    move.l 4(sp),d0
    move.l 8(sp),a0
    clr.l -(sp)
    move.l d0,-(sp)
    move.l a0,-(sp)
    move.l #0x12345678,d0
    .word \opcode
    move.l d0,g_resourceLookupD0
    move.l (sp)+,d0
    rts
    .endm
    namedtrap aitdProbeNamed,0xa9a1
    namedtrap aitdProbe1Named,0xa820
    .macro idtrap name,opcode
    .globl \name
\name:
    move.l 4(sp),d0
    move.w 10(sp),d1
    clr.l -(sp)
    move.l d0,-(sp)
    move.w d1,-(sp)
    move.l #0x12345678,d0
    .word \opcode
    move.l d0,g_resourceLookupD0
    move.l (sp)+,d0
    rts
    .endm
    idtrap aitdProbeResource,0xa9a0
    idtrap aitdProbe1Resource,0xa81f

    .section .text.aitdResourceHandleProbe,"ax"
    .globl aitdProbeResInfo
aitdProbeResInfo:
    move.l 4(sp),d0
    move.l 8(sp),d1
    move.l 12(sp),a0
    move.l 16(sp),a1
    move.l d0,-(sp)
    move.l d1,-(sp)
    move.l a0,-(sp)
    move.l a1,-(sp)
    move.l #0x12345678,d0
    .word 0xa9a8
    move.l d0,g_resourceLookupD0
    rts
    .globl aitdProbeResLoad
aitdProbeResLoad:
    move.w 6(sp),d0
    lsl.w #8,d0
    move.w d0,-(sp)
    move.l #0x12345678,d0
    .word 0xa99b
    move.l d0,g_resourceLookupD0
    rts
    .macro handletrap name,opcode
    .globl \name
\name:
    move.l 4(sp),-(sp)
    move.l #0x12345678,d0
    .word \opcode
    move.l d0,g_resourceLookupD0
    rts
    .endm
    handletrap aitdProbeLoadResource,0xa9a2
    handletrap aitdProbeDetachResource,0xa992
    handletrap aitdProbeReleaseResource,0xa9a3
    .globl aitdProbeEmptyResource
aitdProbeEmptyResource:
    move.l 4(sp),a0
    move.l #0x12345678,d0
    .word 0xa02b
    move.l d0,g_resourceLookupD0
    rts

    .section .text.aitdResourceLifecycleProbe,"ax"
    .macro resourceos name,opcode
    .globl \name
\name:
    move.l 4(sp),a0
    move.l 8(sp),d0
    .word \opcode
    move.l d0,g_resourceLookupD0
    rts
    .endm
    resourceos aitdProbeResState,0xa069
    resourceos aitdProbeResLock,0xa029
    resourceos aitdProbeResUnlock,0xa02a
    resourceos aitdProbeResHPurge,0xa049
    resourceos aitdProbeResSetState,0xa06a
    resourceos aitdProbeResPurge,0xa04d

    .section .text.aitdResourceEnumerationProbe,"ax"
    idtrap aitdProbe1IndResource,0xa80e
    .macro counttrap name,opcode
    .globl \name
\name:
    move.l 4(sp),d0
    clr.w -(sp)
    move.l d0,-(sp)
    move.l #0x12345678,d0
    .word \opcode
    move.l d0,g_resourceLookupD0
    moveq #0,d0
    move.w (sp)+,d0
    rts
    .endm
    counttrap aitdProbeCount1Resources,0xa80d
    counttrap aitdProbeCountResources,0xa99c
