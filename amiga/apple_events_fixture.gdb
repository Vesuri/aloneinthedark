set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
echo ARM native Apple Event CPU fixture\n
tbreak aitdAECase1
continue
if $pc!=aitdAECase1
 echo FAIL fixture entry\n
 detach
 quit 1
end
if g_appleEventHandlers.count!=4
 echo FAIL fixture seed\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=1 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=1 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase1Returned
continue
if $pc!=aitdAECase1Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=original-6f617070 seq=1 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase2
continue
if $pc!=aitdAECase2
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=2 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=2 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase2Returned
continue
if $pc!=aitdAECase2Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=original-70646f63 seq=2 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase3
continue
if $pc!=aitdAECase3
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=3 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=3 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase3Returned
continue
if $pc!=aitdAECase3Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=original-6f646f63 seq=3 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase4
continue
if $pc!=aitdAECase4
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=4 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=4 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase4Returned
continue
if $pc!=aitdAECase4Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=original-71756974 seq=4 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase5
continue
if $pc!=aitdAECase5
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=5 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=5 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase5Returned
continue
if $pc!=aitdAECase5Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=absent seq=5 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase6
continue
if $pc!=aitdAECase6
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=6 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=6 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase6Returned
continue
if $pc!=aitdAECase6Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=install seq=6 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase7
continue
if $pc!=aitdAECase7
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=7 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=7 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase7Returned
continue
if $pc!=aitdAECase7Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=get-installed seq=7 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase8
continue
if $pc!=aitdAECase8
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=8 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=8 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase8Returned
continue
if $pc!=aitdAECase8Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=replace-refcon seq=8 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase9
continue
if $pc!=aitdAECase9
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=9 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=9 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase9Returned
continue
if $pc!=aitdAECase9Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=get-refcon seq=9 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase10
continue
if $pc!=aitdAECase10
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=A sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=A data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase10Returned
continue
if $pc!=aitdAECase10Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=replace-handler seq=A sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase11
continue
if $pc!=aitdAECase11
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=B sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=B data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase11Returned
continue
if $pc!=aitdAECase11Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=get-handler seq=B sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase12
continue
if $pc!=aitdAECase12
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=C sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=C data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase12Returned
continue
if $pc!=aitdAECase12Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=other-class seq=C sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase13
continue
if $pc!=aitdAECase13
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=D sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=D data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase13Returned
continue
if $pc!=aitdAECase13Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=system-separate seq=D sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase14
continue
if $pc!=aitdAECase14
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=E sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=E data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase14Returned
continue
if $pc!=aitdAECase14Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=null-handler seq=E sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase15
continue
if $pc!=aitdAECase15
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=F sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=F data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase15Returned
continue
if $pc!=aitdAECase15Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=get-after-null seq=F sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase16
continue
if $pc!=aitdAECase16
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=10 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=10 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase16Returned
continue
if $pc!=aitdAECase16Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=odd-handler seq=10 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAECase17
continue
if $pc!=aitdAECase17
 echo FAIL fixture entry\n
 detach
 quit 1
end
printf "AE_FIX_ENTER seq=11 sp=%X selector=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_FIX_ARGS seq=11 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($sp+0),*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
tbreak aitdAECase17Returned
continue
if $pc!=aitdAECase17Returned
 echo FAIL fixture return\n
 detach
 quit 1
end
printf "AE_FIX_RETURN label=get-after-odd seq=11 sp=%X result=%X before=%X handler=%X refcon=%X after=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($a4+256),*(unsigned long*)($a4+260),*(unsigned long*)($a4+264),*(unsigned long*)($a4+268),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdAEProbeDone
continue
if $pc!=aitdAEProbeDone || g_appleEventHandlers.count!=5
 echo FAIL fixture completion\n
 detach
 quit 1
end
if *(unsigned short *)((unsigned long)_start+0x58)!=0x4eb9 || *(unsigned long *)((unsigned long)_start+0x5a)!=(unsigned long)main
 echo FAIL fixture CRT guard\n
 detach
 quit 1
end
tbreak *((unsigned long)_start+0x5e)
continue
if $pc!=(unsigned long)_start+0x5e || $d0!=0 || g_appleEventHandlers.count!=0 || g_macLineAInstalled!=0 || g_resourceSourceOpen!=0 || g_overlaySourceOpen!=0
 echo FAIL Apple Event fixture ownership cleanup\n
 detach
 quit 1
end
echo AE_FIX_CLEANUP count=0 sources=0/0 lineA=0 result=0\n
echo PASS Apple Event table fixture calls=11\n
detach
quit
