set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
define saveDeviceRegisters
set $saved_d2=$d2
set $saved_d3=$d3
set $saved_d4=$d4
set $saved_d5=$d5
set $saved_d6=$d6
set $saved_d7=$d7
set $saved_a2=$a2
set $saved_a3=$a3
set $saved_a4=$a4
set $saved_a5=$a5
set $saved_a6=$a6
end
define checkDeviceRegisters
if $d2!=$saved_d2 || $d3!=$saved_d3 || $d4!=$saved_d4 || $d5!=$saved_d5 || $d6!=$saved_d6 || $d7!=$saved_d7 || $a2!=$saved_a2 || $a3!=$saved_a3 || $a4!=$saved_a4 || $a5!=$saved_a5 || $a6!=$saved_a6
 echo FAIL device preserved registers\n
 detach
 quit 1
end
end

break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $core=s_segments[3].begin
if *(unsigned long*)($core+0x4b48)!=0xaa29285f
 echo FAIL native device original bytes\n
 detach
 quit 1
end
if *(unsigned long*)($core+0x4d70)!=0xaaa2301f
 echo FAIL native device original bytes\n
 detach
 quit 1
end
if *(unsigned long*)($core+0x4da2)!=0xa8a8302e
 echo FAIL native device original bytes\n
 detach
 quit 1
end
if *(unsigned long*)($core+0x4b8e)!=0xaa2b285f
 echo FAIL native device original bytes\n
 detach
 quit 1
end
tbreak *($core+0x4b48)
continue
if $pc!=(unsigned long)($core+0x4b48)
 echo FAIL device entry\n
 detach
 quit 1
end
set $entrySP=$sp
saveDeviceRegisters
printf "DEVICE native entry=1 offset=4b48 sp=%X args=%08X/%08X/%08X\n",$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8)
tbreak *($core+0x4b4a)
continue
if $pc!=(unsigned long)($core+0x4b4a) || $sp!=$entrySP+0
 echo FAIL device return stack\n
 detach
 quit 1
end
checkDeviceRegisters
printf "DEVICE native return=1 sp=%X result=%08X D0=%08X\n",$sp,*(unsigned long*)$sp,$d0
set $device=*(unsigned long*)$sp
set $gd=*(unsigned long*)$device
set $pm=**(unsigned long**)($gd+22)
printf "DEVICE native handle=%X body=%X pixmap=%X backing=%X stride=%X depth=%u bounds=%08X/%08X\n",$device,$gd,$pm,*(unsigned long*)$pm,*(unsigned short*)($pm+4),*(unsigned short*)($pm+32),*(unsigned long*)($pm+6),*(unsigned long*)($pm+10)
dump binary memory ../tmp/m2-device-native-gd.bin $gd $gd+62
dump binary memory ../tmp/m2-device-native-pm.bin $pm $pm+50
set $ct=**(unsigned long**)($pm+42)
dump binary memory ../tmp/m2-device-native-ct.bin $ct $ct+2056
set $pixels=*(unsigned long*)$pm
if sizeof(s_colorScreen)!=307200 || $pixels!=(unsigned long)&s_colorScreen
 echo FAIL screen backing extent\n
 detach
 quit 1
end
dump binary memory ../tmp/m2-device-native-pixels.bin $pixels $pixels+307200
tbreak *($core+0x4d70)
continue
if $pc!=(unsigned long)($core+0x4d70)
 echo FAIL device entry\n
 detach
 quit 1
end
set $entrySP=$sp
saveDeviceRegisters
printf "DEVICE native entry=2 offset=4d70 sp=%X args=%08X/%08X/%08X\n",$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8)
tbreak *($core+0x4d72)
continue
if $pc!=(unsigned long)($core+0x4d72) || $sp!=$entrySP+10
 echo FAIL device return stack\n
 detach
 quit 1
end
checkDeviceRegisters
printf "DEVICE native return=2 sp=%X result=%08X D0=%08X\n",$sp,*(unsigned long*)$sp,$d0
if *(unsigned short*)$sp!=0x83 || $d0!=8
 echo FAIL HasDepth mode\n
 detach
 quit 1
end
tbreak *($core+0x4da2)
continue
if $pc!=(unsigned long)($core+0x4da2)
 echo FAIL device entry\n
 detach
 quit 1
end
set $entrySP=$sp
saveDeviceRegisters
set $rect=*(unsigned long*)($sp+4)
set $rect0=*(unsigned long*)$rect
set $rect1=*(unsigned long*)($rect+4)
if *(unsigned long*)$sp!=0 || $rect0!=0 || $rect1!=0x01e00280
 echo FAIL original rectangle arguments\n
 detach
 quit 1
end
printf "DEVICE native entry=3 offset=4da2 sp=%X args=%08X/%08X/%08X\n",$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8)
tbreak *($core+0x4da4)
continue
if $pc!=(unsigned long)($core+0x4da4) || $sp!=$entrySP+8
 echo FAIL device return stack\n
 detach
 quit 1
end
checkDeviceRegisters
if *(unsigned long*)$rect!=$rect0 || *(unsigned long*)($rect+4)!=$rect1
 echo FAIL original rectangle result\n
 detach
 quit 1
end
printf "DEVICE native return=3 sp=%X result=%08X D0=%08X\n",$sp,*(unsigned long*)$sp,$d0
tbreak *($core+0x4b8e)
continue
if $pc!=(unsigned long)($core+0x4b8e)
 echo FAIL device entry\n
 detach
 quit 1
end
set $entrySP=$sp
saveDeviceRegisters
printf "DEVICE native entry=4 offset=4b8e sp=%X args=%08X/%08X/%08X\n",$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8)
tbreak *($core+0x4b90)
continue
if $pc!=(unsigned long)($core+0x4b90) || $sp!=$entrySP+4
 echo FAIL device return stack\n
 detach
 quit 1
end
checkDeviceRegisters
printf "DEVICE native return=4 sp=%X result=%08X D0=%08X\n",$sp,*(unsigned long*)$sp,$d0
if *(unsigned long*)$sp!=0
 echo FAIL device chain end\n
 detach
 quit 1
end
tbreak *($core+0x4d34)
continue
if $d0!=$device || ($d7&0xffff)!=1
 echo FAIL selected device\n
 detach
 quit 1
end
printf "PASS native device selection calls=4 count=1\n"
continue
if g_stageBState!=3 || g_trapWord!=0xab1d || g_trapSelector!=15 || g_trapSegment!=10 || g_trapOffset!=0x2da || *(unsigned long*)(g_trapRoutine+0)!=0x47455450 || *(unsigned long*)(g_trapRoutine+4)!=0x49584241 || *(unsigned long*)(g_trapRoutine+8)!=0x53454144 || *(unsigned short*)(g_trapRoutine+12)!=0x4452 || g_trapRoutine[14]!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_macServiceActive!=0
 echo FAIL device next named stop\n
 detach
 quit 1
end
printf "NEXT state=%u trap=%04X %s/%s caller=%u+%X windows=%u services=%u/%u resources=%u/%u\n",g_stageBState,g_trapWord,g_trapManager,g_trapRoutine,g_trapSegment,g_trapOffset,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
detach
quit 0
