define m5_snapshot
 printf "M5_MACHINE clockHz=%u cpuFlags=%u chip=%u fast=%u initialChip=%u initialFast=%u\n",g_m5Audit.clockHz,g_m5Audit.cpuFlags,g_m5Audit.totalChip,g_m5Audit.totalFast,g_m5Audit.initialChip,g_m5Audit.initialFast
 printf "M5_MEMORY liveChip=%u liveFast=%u peakChip=%u peakFast=%u minChip=%u minFast=%u allocations=%u failures=%u errors=%u appZone=%u systemZone=%u\n",g_m5Audit.liveChip,g_m5Audit.liveFast,g_m5Audit.peakChip,g_m5Audit.peakFast,g_m5Audit.minFreeChip,g_m5Audit.minFreeFast,g_m5Audit.allocations,g_m5Audit.failures,g_m5Audit.accountingErrors,g_m5Audit.zonePeak[0],g_m5Audit.zonePeak[1]
 printf "M5_IRQ calls=%u totalClocks=%u maxClocks=%u minInterval=%u maxInterval=%u maxLateEClocks=%u musicTicks=%u events=%u eventLate=%u busy=%u effects=%u\n",g_m5Audit.irqCalls,g_m5Audit.irqClocks,g_m5Audit.irqMaxClocks,g_m5Audit.irqMinInterval,g_m5Audit.irqMaxInterval,g_m5Audit.irqMaxLateEClocks,g_musicTicks,g_song.events,g_song.maxDeliveryLateness,g_song.busyFields,g_effectStarts
 printf "M5_GAP traps=%u maxClocks=%u from=%X to=%X trap=%X musicTicks=%u\n",g_m5Audit.traps,g_m5Audit.maxGap,g_m5Audit.gapFrom,g_m5Audit.gapTo,g_m5Audit.gapTrap,g_m5Audit.gapMusicTicks
 printf "M5_NOTES count=%u late=%u maxLate=%u activeGap=%u activeTicks=%u song=%u\n",g_m5Audit.noteCount,g_m5Audit.noteLateCount,g_m5Audit.noteMaxLate,g_m5Audit.activeGap,g_m5Audit.activeGapTicks,g_m5Audit.activeGapSong
 dump binary memory ../tmp/m5/note-log.bin g_m5NoteLog (char*)g_m5NoteLog+sizeof(g_m5NoteLog)
 dump binary memory ../tmp/m5/music-stack.bin (char*)aitd_song_stack (char*)aitd_song_stack+8192
 dump binary memory ../tmp/m5/deferred-stack.bin (char*)aitd_song_deferred_stack (char*)aitd_song_deferred_stack+8192
end
