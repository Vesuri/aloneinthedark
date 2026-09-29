set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL file-write: %s / %s stage=%u\n",g_trapManager,g_trapRoutine,g_fileProbeStage
 detach
 quit 1
end
break aitdFileAsyncCompletion
commands
 silent
 if ($sr & 0x2000) != 0 || g_macServiceActive != 0 || g_macFileCompletionDepth != 1
  echo FAIL file-write: completion outside safe user-mode boundary\n
  detach
  quit 1
 end
 continue
end
tbreak aitdFileProbeFinished
continue
if g_fileProbeDone != 1 || g_fileProbeError != 0 || g_fileProbeStage != 51 || g_resourceLookupStep != 21 || g_resourceLookupHash != 0x54b9dc7d || g_resourceRuntimeReads != 2 || g_resourceRuntimeBytes != 863 || g_fileAsyncStep != 67 || g_fileAsyncCallbacks != 51 || g_fileAsyncNestedOK != 1 || g_macFileCompletionDepth != 0 || g_fileVInfoProbeStep != 12 || g_fileOpenDFProbeStep != 17 || g_fileVolumeProbeStep != 35 || g_fileProbeWindows != 378 || g_fileIndexProbeStep != 9 || g_fileInstalledProbeStep != 10 || g_fileForkProbeStep != 14 || g_fileCatalogProbeStep != 15 || g_fileOpenHandles != 2 || g_fileReadCalls != 33 || g_fileReadBytes != 866733 || g_fileReadMax != 65536 || g_macServiceActive != 0 || g_macServiceEntered != g_macServiceCompleted
 printf "FAIL file-write: stage=%u step=%u catalog=%u forks=%u installed=%u index=%u error=%u windows=%u reads=%u bytes=%u max=%u services=%u/%u\n",g_fileProbeStage,g_fileWriteProbeStep,g_fileCatalogProbeStep,g_fileForkProbeStep,g_fileInstalledProbeStep,g_fileIndexProbeStep,g_fileProbeError,g_fileProbeWindows,g_fileReadCalls,g_fileReadBytes,g_fileReadMax,g_macServiceEntered,g_macServiceCompleted
 detach
 quit 1
end
if g_fileWriteProbeStep != 23 || g_fileWriteCalls != 24 || g_fileWriteBytes != 470069 || g_fileWriteMax != 65536 || g_fileFlushCalls != 18
 printf "FAIL file-write: step=%u writes=%u bytes=%u max=%u flushes=%u\n",g_fileWriteProbeStep,g_fileWriteCalls,g_fileWriteBytes,g_fileWriteMax,g_fileFlushCalls
 detach
 quit 1
end
tbreak aitdFileCleanupFinished
continue
if g_fileWriteCalls != 24 || g_fileWriteBytes != 470069 || g_fileFlushCalls != 18 || g_resourceSourceOpen != 0 || g_resourceSourceCloseErrors != 0 || g_fileCloseErrors != 0 || g_fileOpenHandles != 0 || g_fileRestoredCloses != 2 || g_macLineAInstalled != 0 || ((struct ExecBase*)SysBase)->TDNestCnt != -1
 echo FAIL file-write: OS restoration or remaining stream cleanup\n
 detach
 quit 1
end
printf "PASS file-write: Line-A/backend bytes=exact windows=378 writes=24 max=65536 flushes=18 EOF=17/3 cleanup=2 sharing=coherent permissions=0-4/locked volume=name/ref catalog=metadata/durable forks=independent installed=original index=HFS volparms=exact opendf=dot/aliases vinfo=native/catalog async=51/nested/user resources=20/exact\n"
detach
quit 0
