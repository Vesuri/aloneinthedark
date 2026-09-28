set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL file-write: %s / %s stage=%u\n",g_trapManager,g_trapRoutine,g_fileProbeStage
 detach
 quit 1
end
tbreak aitdFileProbeFinished
continue
if g_fileProbeDone != 1 || g_fileProbeError != 0 || g_fileProbeStage != 44 || g_fileProbeWindows != 263 || g_fileForkProbeStep != 14 || g_fileCatalogProbeStep != 15 || g_fileOpenHandles != 2 || g_fileReadCalls != 30 || g_fileReadBytes != 866721 || g_fileReadMax != 65536 || g_macServiceActive != 0 || g_macServiceEntered != g_macServiceCompleted
 printf "FAIL file-write: stage=%u step=%u catalog=%u forks=%u error=%u windows=%u reads=%u bytes=%u max=%u services=%u/%u\n",g_fileProbeStage,g_fileWriteProbeStep,g_fileCatalogProbeStep,g_fileForkProbeStep,g_fileProbeError,g_fileProbeWindows,g_fileReadCalls,g_fileReadBytes,g_fileReadMax,g_macServiceEntered,g_macServiceCompleted
 detach
 quit 1
end
if g_fileWriteProbeStep != 23 || g_fileWriteCalls != 22 || g_fileWriteBytes != 470062 || g_fileWriteMax != 65536 || g_fileFlushCalls != 16
 printf "FAIL file-write: step=%u writes=%u bytes=%u max=%u flushes=%u\n",g_fileWriteProbeStep,g_fileWriteCalls,g_fileWriteBytes,g_fileWriteMax,g_fileFlushCalls
 detach
 quit 1
end
tbreak aitdFileCleanupFinished
continue
if g_fileWriteCalls != 23 || g_fileWriteBytes != 470065 || g_fileFlushCalls != 17 || g_fileCloseErrors != 0 || g_fileOpenHandles != 0 || g_fileRestoredCloses != 2 || g_macLineAInstalled != 0 || ((struct ExecBase*)SysBase)->TDNestCnt != -1
 echo FAIL file-write: OS restoration or remaining stream cleanup\n
 detach
 quit 1
end
printf "PASS file-write: Line-A/backend bytes=exact windows=263 writes=23 max=65536 flushes=17 EOF=17/3 cleanup=2 sharing=coherent permissions=0-4/locked volume=name/ref catalog=metadata/durable forks=independent\n"
detach
quit 0
