set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL file-read: %s / %s stage=%u\n",g_trapManager,g_trapRoutine,g_fileProbeStage
 detach
 quit 1
end
tbreak aitdFileProbeFinished
continue
if g_fileProbeDone != 1 || g_fileProbeError != 0 || g_fileProbeStage != 39 || g_fileProbeWindows != 10 || g_fileOpenHandles != 1 || g_fileReadCalls != 6 || g_fileReadBytes != 262168 || g_fileReadMax != 65536 || g_macServiceActive != 0 || g_macServiceEntered != g_macServiceCompleted
 printf "FAIL file-read: stage=%u error=%u windows=%u reads=%u bytes=%u max=%u services=%u/%u\n",g_fileProbeStage,g_fileProbeError,g_fileProbeWindows,g_fileReadCalls,g_fileReadBytes,g_fileReadMax,g_macServiceEntered,g_macServiceCompleted
 detach
 quit 1
end
tbreak aitdFileCleanupFinished
continue
if g_resourceSourceOpen != 0 || g_resourceSourceCloseErrors != 0 || g_fileCloseErrors != 0 || g_fileOpenHandles != 0 || g_fileRestoredCloses != 1 || g_macLineAInstalled != 0 || ((struct ExecBase*)SysBase)->TDNestCnt != -1
 echo FAIL file-read: OS restoration or remaining stream cleanup\n
 detach
 quit 1
end
printf "PASS file-read: Line-A open/read/seek/EOF/position/close bytes=exact CCR=checked windows=10 DOS-reads=6 max=65536 cleanup=1 GetVol=WD/root/null-name FCB=index/exact/errors HVol=directory/state/errors WD=query/close/filter\n"
detach
quit 0
