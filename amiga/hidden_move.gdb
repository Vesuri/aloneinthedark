set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $engine=s_segments[7].begin
tbreak *($engine+0x48a2)
continue
if *(unsigned long*)$pc!=0xa91b286e
 echo FAIL MoveWindow original opcode\n
 detach
 quit 1
end
set $args=$sp
set $dialog=*(unsigned long*)($sp+6)
printf "MOVE_ENTER sp=%X args=%04X%04X%04X%08X qdPort=%X windows=%X d3=%X d4=%X d5=%X d6=%X d7=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,*(unsigned short*)($sp+2),*(unsigned short*)($sp+4),$dialog,*(unsigned long*)s_qdThePort,s_windowList,$d3,$d4,$d5,$d6,$d7,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/move-native-before-record.bin $dialog $dialog+170
set $items=**(unsigned long**)($dialog+156)
dump binary memory ../tmp/move-native-before-items.bin $items $items+116
set $body=**(unsigned long**)($dialog+24)
dump binary memory ../tmp/move-native-before-vis.bin $body $body+10
set $body=**(unsigned long**)($dialog+28)
dump binary memory ../tmp/move-native-before-clip.bin $body $body+10
set $body=**(unsigned long**)($dialog+114)
dump binary memory ../tmp/move-native-before-struct.bin $body $body+10
set $body=**(unsigned long**)($dialog+118)
dump binary memory ../tmp/move-native-before-content.bin $body $body+10
set $body=**(unsigned long**)($dialog+122)
dump binary memory ../tmp/move-native-before-update.bin $body $body+10
set $body=**(unsigned long**)($items+2)
dump binary memory ../tmp/move-native-before-control1.bin $body $body+50
set $body=**(unsigned long**)($items+26)
dump binary memory ../tmp/move-native-before-control2.bin $body $body+50
set $body=**(unsigned long**)($items+50)
dump binary memory ../tmp/move-native-before-text3.bin $body $body+51
tbreak *($engine+0x48a4)
continue
printf "MOVE_RETURN sp=%X qdPort=%X windows=%X d3=%X d4=%X d5=%X d6=%X d7=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d3,$d4,$d5,$d6,$d7,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/move-native-after-record.bin $dialog $dialog+170
set $items=**(unsigned long**)($dialog+156)
dump binary memory ../tmp/move-native-after-items.bin $items $items+116
set $body=**(unsigned long**)($dialog+24)
dump binary memory ../tmp/move-native-after-vis.bin $body $body+10
set $body=**(unsigned long**)($dialog+28)
dump binary memory ../tmp/move-native-after-clip.bin $body $body+10
set $body=**(unsigned long**)($dialog+114)
dump binary memory ../tmp/move-native-after-struct.bin $body $body+10
set $body=**(unsigned long**)($dialog+118)
dump binary memory ../tmp/move-native-after-content.bin $body $body+10
set $body=**(unsigned long**)($dialog+122)
dump binary memory ../tmp/move-native-after-update.bin $body $body+10
set $body=**(unsigned long**)($items+2)
dump binary memory ../tmp/move-native-after-control1.bin $body $body+50
set $body=**(unsigned long**)($items+26)
dump binary memory ../tmp/move-native-after-control2.bin $body $body+50
set $body=**(unsigned long**)($items+50)
dump binary memory ../tmp/move-native-after-text3.bin $body $body+51
continue
printf "MOVE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xa870 || g_trapSegment!=9 || g_trapOffset!=0xe20 || *(unsigned long*)(g_trapRoutine+0)!=0x4c4f4341 || *(unsigned long*)(g_trapRoutine+4)!=0x4c544f47 || *(unsigned long*)(g_trapRoutine+8)!=0x4c4f4241 || *(unsigned short*)(g_trapRoutine+12)!=0x4c00 || g_trapSelector!=-1 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_resourceRuntimeReads!=62 || g_resourceRuntimeBytes!=265454
 echo FAIL hidden MoveWindow progression\n
 detach
 quit 1
end
echo PASS native hidden MoveWindow next=LOCALTOGLOBAL\n
detach
quit 0
