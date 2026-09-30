set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $core=s_segments[3].begin
if *(unsigned long*)($core+0x500)!=0xaaa22079 || *(unsigned long*)($core+0x4fc)!=0x303c0a13
 echo FAIL SetDepth original bytes\n
 detach
 quit 1
end
printf "DEPTH_SITE bytes=AAA22079 before=303C0A13\n"
tbreak *($core+0x500)
continue
if $pc!=(unsigned long)($core+0x500)
 echo FAIL SetDepth entry\n
 detach
 quit 1
end
set $entrySP=$sp
set $device=*(unsigned long*)($sp+6)
set $gd=*(unsigned long*)$device
set $pm=**(unsigned long**)($gd+22)
set $ct=**(unsigned long**)($pm+42)
set $pixels=*(unsigned long*)$pm
set $saved_d0=$d0
set $saved_d1=$d1
set $saved_d2=$d2
set $saved_d3=$d3
set $saved_d4=$d4
set $saved_d5=$d5
set $saved_d6=$d6
set $saved_d7=$d7
set $saved_a0=$a0
set $saved_a1=$a1
set $saved_a2=$a2
set $saved_a3=$a3
set $saved_a4=$a4
set $saved_a5=$a5
set $saved_a6=$a6
printf "DEPTH_ENTER seq=1 sp=%X args=%08X/%08X/%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/setdepth-native-before-gd.bin $gd $gd+62
dump binary memory ../tmp/setdepth-native-before-pm.bin $pm $pm+50
dump binary memory ../tmp/setdepth-native-before-ct.bin $ct $ct+2056
dump binary memory ../tmp/setdepth-native-before-pixels.bin $pixels $pixels+307200
tbreak *($core+0x502)
continue
if $pc!=(unsigned long)($core+0x502) || $sp!=$entrySP+10
 echo FAIL SetDepth return stack\n
 detach
 quit 1
end
if *(unsigned long*)$device!=$gd || **(unsigned long**)($gd+22)!=$pm || **(unsigned long**)($pm+42)!=$ct || *(unsigned long*)$pm!=$pixels
 echo FAIL SetDepth device/backing identity\n
 detach
 quit 1
end
printf "DEPTH_RETURN seq=1 sp=%X expected=%X result=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,$entrySP+10,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/setdepth-native-after-gd.bin $gd $gd+62
dump binary memory ../tmp/setdepth-native-after-pm.bin $pm $pm+50
dump binary memory ../tmp/setdepth-native-after-ct.bin $ct $ct+2056
dump binary memory ../tmp/setdepth-native-after-pixels.bin $pixels $pixels+307200
continue
printf "DEPTH_NEXT state=%u trap=%X selector=%X segment=%u offset=%X routine=%s windows=%u services=%u/%u resources=%u/%u overlay=%u/%u mask=%X\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_loadedCodeMask
if g_stageBState!=3 || g_trapWord!=0xa934 || g_trapSelector!=-1 || g_trapSegment!=7 || g_trapOffset!=0x2b06 || *(unsigned long*)(g_trapRoutine+0)!=0x434c4541 || *(unsigned long*)(g_trapRoutine+4)!=0x524d454e || *(unsigned long*)(g_trapRoutine+8)!=0x55424152 || g_trapRoutine[12]!=0 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_resourceRuntimeReads!=41 || g_resourceRuntimeBytes!=206540
 echo FAIL SetDepth next stop\n
 detach
 quit 1
end
printf "PASS native SetDepth calls=1 next=CLEARMENUBAR\n"
detach
quit 0
