set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
echo ARM native ctable CPU fixture\n
tbreak aitdCTableInitial
continue
if $pc!=aitdCTableInitial
 echo FAIL fixture aitdCTableInitial\n
 detach
 quit 1
end
printf "CTABLE_ENTER sp=%X id=%X slot=%X bytes=%08X/%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned long*)($sp+2),*(unsigned long*)($pc-4),*(unsigned short*)$pc,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableInitialReturned
continue
if $pc!=aitdCTableInitialReturned
 echo FAIL fixture aitdCTableInitialReturned\n
 detach
 quit 1
end
set $handle=*(unsigned long*)$sp
set $body=*(unsigned long*)$handle
printf "CTABLE_RETURN sp=%X handle=%X master=%X body=%X seed=%X flags=%X size=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$handle,$body,$body,*(unsigned long*)$body,*(unsigned short*)($body+4),*(unsigned short*)($body+6),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/ctable-native-return.bin $body $body+2056
tbreak aitdCTableMutated
continue
if $pc!=aitdCTableMutated
 echo FAIL fixture aitdCTableMutated\n
 detach
 quit 1
end
printf "CTABLE_MUTATED handle=%X body=%X seed=%X flags=%X size=%X count=%X\n",$handle,$body,*(unsigned long*)$body,*(unsigned short*)($body+4),*(unsigned short*)($body+6),$d0
dump binary memory ../tmp/ctable-native-mutated.bin $body $body+2056
echo PASS CPU GetCTable and mutations\n
tbreak aitdCTableCase1
continue
if $pc!=aitdCTableCase1
 echo FAIL fixture aitdCTableCase1\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",1,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase1Returned
continue
if $pc!=aitdCTableCase1Returned
 echo FAIL fixture aitdCTableCase1Returned\n
 detach
 quit 1
end
set $resource=0
set $second=0
set $third=0
printf "CTABLE_FIX_RETURN label=original-size seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",1,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase2
continue
if $pc!=aitdCTableCase2
 echo FAIL fixture aitdCTableCase2\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",2,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase2Returned
continue
if $pc!=aitdCTableCase2Returned
 echo FAIL fixture aitdCTableCase2Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=original-state seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",2,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase3
continue
if $pc!=aitdCTableCase3
 echo FAIL fixture aitdCTableCase3\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",3,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase3Returned
continue
if $pc!=aitdCTableCase3Returned
 echo FAIL fixture aitdCTableCase3Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=original-attrs seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",3,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase4
continue
if $pc!=aitdCTableCase4
 echo FAIL fixture aitdCTableCase4\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",4,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase4Returned
continue
if $pc!=aitdCTableCase4Returned
 echo FAIL fixture aitdCTableCase4Returned\n
 detach
 quit 1
end
set $resource=*(unsigned long*)$sp
printf "CTABLE_FIX_RETURN label=resource seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",4,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$resource
dump binary memory ../tmp/ctable-fixture-source.bin $dumpbody $dumpbody+2056
tbreak aitdCTableCase5
continue
if $pc!=aitdCTableCase5
 echo FAIL fixture aitdCTableCase5\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",5,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase5Returned
continue
if $pc!=aitdCTableCase5Returned
 echo FAIL fixture aitdCTableCase5Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=resource-size seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",5,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase6
continue
if $pc!=aitdCTableCase6
 echo FAIL fixture aitdCTableCase6\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",6,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase6Returned
continue
if $pc!=aitdCTableCase6Returned
 echo FAIL fixture aitdCTableCase6Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=resource-state seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",6,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase7
continue
if $pc!=aitdCTableCase7
 echo FAIL fixture aitdCTableCase7\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",7,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase7Returned
continue
if $pc!=aitdCTableCase7Returned
 echo FAIL fixture aitdCTableCase7Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=seed-before seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",7,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase8
continue
if $pc!=aitdCTableCase8
 echo FAIL fixture aitdCTableCase8\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",8,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase8Returned
continue
if $pc!=aitdCTableCase8Returned
 echo FAIL fixture aitdCTableCase8Returned\n
 detach
 quit 1
end
set $second=*(unsigned long*)$sp
printf "CTABLE_FIX_RETURN label=second seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",8,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$second
dump binary memory ../tmp/ctable-fixture-second.bin $dumpbody $dumpbody+2056
tbreak aitdCTableCase9
continue
if $pc!=aitdCTableCase9
 echo FAIL fixture aitdCTableCase9\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",9,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase9Returned
continue
if $pc!=aitdCTableCase9Returned
 echo FAIL fixture aitdCTableCase9Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=seed-after seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",9,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase10
continue
if $pc!=aitdCTableCase10
 echo FAIL fixture aitdCTableCase10\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",10,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase10Returned
continue
if $pc!=aitdCTableCase10Returned
 echo FAIL fixture aitdCTableCase10Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=second-state seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",10,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase11
continue
if $pc!=aitdCTableCase11
 echo FAIL fixture aitdCTableCase11\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",11,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase11Returned
continue
if $pc!=aitdCTableCase11Returned
 echo FAIL fixture aitdCTableCase11Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=second-attrs seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",11,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase12
continue
if $pc!=aitdCTableCase12
 echo FAIL fixture aitdCTableCase12\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",12,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase12Returned
continue
if $pc!=aitdCTableCase12Returned
 echo FAIL fixture aitdCTableCase12Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=mutate-second seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",12,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$second
dump binary memory ../tmp/ctable-fixture-second-mutated.bin $dumpbody $dumpbody+2056
set $dumpbody=*(unsigned long*)$resource
dump binary memory ../tmp/ctable-fixture-source-after-mutation.bin $dumpbody $dumpbody+2056
tbreak aitdCTableCase13
continue
if $pc!=aitdCTableCase13
 echo FAIL fixture aitdCTableCase13\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",13,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase13Returned
continue
if $pc!=aitdCTableCase13Returned
 echo FAIL fixture aitdCTableCase13Returned\n
 detach
 quit 1
end
set $third=*(unsigned long*)$sp
printf "CTABLE_FIX_RETURN label=third seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",13,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$third
dump binary memory ../tmp/ctable-fixture-third.bin $dumpbody $dumpbody+2056
set $dumpbody=*(unsigned long*)$resource
dump binary memory ../tmp/ctable-fixture-source-after-third.bin $dumpbody $dumpbody+2056
tbreak aitdCTableCase14
continue
if $pc!=aitdCTableCase14
 echo FAIL fixture aitdCTableCase14\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",14,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase14Returned
continue
if $pc!=aitdCTableCase14Returned
 echo FAIL fixture aitdCTableCase14Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=resource-again seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",14,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)(*(unsigned long*)$sp)
dump binary memory ../tmp/ctable-fixture-source-again.bin $dumpbody $dumpbody+2056
tbreak aitdCTableCase15
continue
if $pc!=aitdCTableCase15
 echo FAIL fixture aitdCTableCase15\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",15,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase15Returned
continue
if $pc!=aitdCTableCase15Returned
 echo FAIL fixture aitdCTableCase15Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=source-state-again seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",15,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase16
continue
if $pc!=aitdCTableCase16
 echo FAIL fixture aitdCTableCase16\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",16,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase16Returned
continue
if $pc!=aitdCTableCase16Returned
 echo FAIL fixture aitdCTableCase16Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=dispose-second seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",16,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase17
continue
if $pc!=aitdCTableCase17
 echo FAIL fixture aitdCTableCase17\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",17,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase17Returned
continue
if $pc!=aitdCTableCase17Returned
 echo FAIL fixture aitdCTableCase17Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=original-survives seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",17,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase18
continue
if $pc!=aitdCTableCase18
 echo FAIL fixture aitdCTableCase18\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",18,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase18Returned
continue
if $pc!=aitdCTableCase18Returned
 echo FAIL fixture aitdCTableCase18Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=disposed-alias-size seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",18,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase19
continue
if $pc!=aitdCTableCase19
 echo FAIL fixture aitdCTableCase19\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",19,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase19Returned
continue
if $pc!=aitdCTableCase19Returned
 echo FAIL fixture aitdCTableCase19Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=third-survives seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",19,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase20
continue
if $pc!=aitdCTableCase20
 echo FAIL fixture aitdCTableCase20\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",20,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase20Returned
continue
if $pc!=aitdCTableCase20Returned
 echo FAIL fixture aitdCTableCase20Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=missing seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",20,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase21
continue
if $pc!=aitdCTableCase21
 echo FAIL fixture aitdCTableCase21\n
 detach
 quit 1
end
printf "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",21,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableCase21Returned
continue
if $pc!=aitdCTableCase21Returned
 echo FAIL fixture aitdCTableCase21Returned\n
 detach
 quit 1
end
printf "CTABLE_FIX_RETURN label=seed-final seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",21,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$handle,$resource,$second,$third,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdCTableProbeDone
continue
if $pc!=aitdCTableProbeDone
 echo FAIL fixture aitdCTableProbeDone\n
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
if $pc!=(unsigned long)_start+0x5e || $d0!=0 || g_macLineAInstalled!=0 || g_resourceSourceOpen!=0 || g_overlaySourceOpen!=0
 echo FAIL colour table fixture shutdown\n
 detach
 quit 1
end
echo PASS GetCTable ownership fixture calls=15\n
echo PASS native ctable CPU fixture shutdown sources=0/0 lineA=0 result=0\n
detach
quit 0
