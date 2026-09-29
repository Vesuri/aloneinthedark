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
break aitdResourceFilesPersisted
commands
 silent
 shell python3 ../tools/check_resource_file_outputs.py
 continue
end
break aitdResourceMutationRolledBack
commands
 silent
 if g_resourceMutationStep < 1000
  shell python3 ../tools/check_resource_mutation_outputs.py rollback
 else
  if g_resourceMutationStep < 1200
   shell python3 ../tools/check_resource_mutation_outputs.py map-rollback-empty
  else
   shell python3 ../tools/check_resource_mutation_outputs.py map-rollback-peers
  end
 end
 continue
end
break aitdResourceMutationPersisted
commands
 silent
 if g_resourceMutationStep == 48
  shell python3 ../tools/check_resource_mutation_outputs.py mutation
 else
  if g_resourceMutationStep == 138
   shell python3 ../tools/check_resource_mutation_outputs.py isolation
  else
   if g_resourceMutationStep == 209
    shell python3 ../tools/check_resource_mutation_outputs.py map-selected
   else
    if g_resourceMutationStep == 214
     shell python3 ../tools/check_resource_mutation_outputs.py map-peers
    else
     shell python3 ../tools/check_resource_mutation_outputs.py map-final
    end
   end
  end
 end
 continue
end
break aitdResourcePermissionsPersisted
commands
 silent
 shell python3 ../tools/check_resource_mutation_outputs.py permissions
 continue
end
break aitdResourceDirtyPersisted
commands
 silent
 shell python3 ../tools/check_resource_dirty_outputs.py
 continue
end
tbreak aitdFileProbeFinished
continue
if g_fileProbeDone != 1 || g_fileProbeError != 0 || g_fileProbeStage != 59 || g_resourceDirtyStep != 46 || g_resourceDirtyWindows != 96 || g_resourcePermissionStep != 60 || g_resourcePermissionWindows != 107 || g_resourceMutationStep != 238 || g_resourceMutationWindows != 316 || g_resourceMutationFaultChecks != 6 || g_resourceMutationLifecycleChecks != 3 || g_resourceFileStep != 65 || g_resourceFileWindows != 78 || g_resourceFileStackError != 0 || g_resourceStageStep != 10 || g_resourceStageWindows != 56 || g_resourceStageHash != 0xa04280df || g_resourceStageFault != 0 || g_resourceStageError != 0 || g_resourceEnumerationStep != 45 || g_resourceEnumerationHash != 0x8d35d0be || g_resourceLifecycleStep != 29 || g_resourceLifecycleHash != 0x8d35d0be || g_resourceHandleStep != 19 || g_resourceHandleHash != 0x20ac017e || g_resourceLookupStep != 21 || g_resourceLookupHash != 0x54b9dc7d || g_resourceRuntimeReads != 11 || g_resourceRuntimeBytes != 9344 || g_fileAsyncStep != 67 || g_fileAsyncCallbacks != 51 || g_fileAsyncNestedOK != 1 || g_macFileCompletionDepth != 0 || g_fileVInfoProbeStep != 12 || g_fileOpenDFProbeStep != 17 || g_fileVolumeProbeStep != 35 || g_fileProbeWindows != 1039 || g_fileIndexProbeStep != 9 || g_fileInstalledProbeStep != 10 || g_fileForkProbeStep != 14 || g_fileCatalogProbeStep != 15 || g_fileOpenHandles != 2 || g_fileReadCalls != 237 || g_fileReadBytes != 871061 || g_fileReadMax != 65536 || g_macServiceActive != 0 || g_macServiceEntered != g_macServiceCompleted
 printf "volume-info: step=%u\n",g_fileVInfoProbeStep
 printf "resource dirty: step=%u value=%08x error=%04x memory=%04x windows=%u D0=%08x\n",g_resourceDirtyStep,g_resourceDirtyValue,g_resourceDirtyError,g_resourceDirtyMemory,g_resourceDirtyWindows,g_resourceLookupD0
 printf "resource permissions: step=%u value=%08x error=%04x memory=%04x windows=%u D0=%08x\n",g_resourcePermissionStep,g_resourcePermissionValue,g_resourcePermissionError,g_resourcePermissionMemory,g_resourcePermissionWindows,g_resourceLookupD0
 printf "resource mutation: step=%u value=%08x error=%04x memory=%04x windows=%u D0=%08x\n",g_resourceMutationStep,g_resourceMutationValue,g_resourceMutationError,g_resourceMutationMemory,g_resourceMutationWindows,g_resourceLookupD0
 printf "resource files: step=%u result=%08x stack=%d windows=%u D0=%08x total=%u reads=%u bytes=%u flushes=%u\n",g_resourceFileStep,g_resourceFileResult,g_resourceFileStackError,g_resourceFileWindows,g_resourceLookupD0,g_systemWindows,g_fileReadCalls,g_fileReadBytes,g_fileFlushCalls
 printf "resource staging: error=%d step=%u windows=%u hash=%08x fault=%u total=%u\n",g_resourceStageError,g_resourceStageStep,g_resourceStageWindows,g_resourceStageHash,g_resourceStageFault,g_systemWindows
 printf "FAIL file-write: stage=%u step=%u catalog=%u forks=%u installed=%u index=%u error=%u windows=%u reads=%u bytes=%u max=%u services=%u/%u\n",g_fileProbeStage,g_fileWriteProbeStep,g_fileCatalogProbeStep,g_fileForkProbeStep,g_fileInstalledProbeStep,g_fileIndexProbeStep,g_fileProbeError,g_fileProbeWindows,g_fileReadCalls,g_fileReadBytes,g_fileReadMax,g_macServiceEntered,g_macServiceCompleted
 detach
 quit 1
end
if g_fileWriteProbeStep != 23 || g_fileWriteCalls != 25 || g_fileWriteBytes != 470085 || g_fileWriteMax != 65536 || g_fileFlushCalls != 19
 printf "FAIL file-write: step=%u writes=%u bytes=%u max=%u flushes=%u\n",g_fileWriteProbeStep,g_fileWriteCalls,g_fileWriteBytes,g_fileWriteMax,g_fileFlushCalls
 detach
 quit 1
end
tbreak aitdFileCleanupFinished
continue
if g_fileWriteCalls != 25 || g_fileWriteBytes != 470085 || g_fileFlushCalls != 19 || g_resourceSourceOpen != 0 || g_resourceSourceCloseErrors != 0 || g_fileCloseErrors != 0 || g_fileOpenHandles != 0 || g_fileRestoredCloses != 2 || g_macLineAInstalled != 0 || ((struct ExecBase*)SysBase)->TDNestCnt != -1
 echo FAIL file-write: OS restoration or remaining stream cleanup\n
 detach
 quit 1
end
printf "PASS file-write: Line-A/backend bytes=exact windows=1039 writes=25 max=65536 flushes=19 EOF=17/3 cleanup=2 sharing=coherent permissions=0-4/locked volume=name/ref catalog=metadata/durable forks=independent installed=original index=HFS volparms=exact opendf=dot/aliases vinfo=native/catalog async=51/nested/user resources=406/exact permission-steps=59 mutation-faults=6 staging=9/exact\n"
detach
quit 0
