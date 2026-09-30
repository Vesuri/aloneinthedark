# Production build. Sourced at MacLoader::run before original execution.
set pagination off
set confirm off
source .run/startup-state.gdb
set $startup_main=0
break AitdScreen::showLoudStop
commands
 silent
 printf "startup END state=%u selector=%u main=%u windows=%u services=%u/%u active=%u routineWords=%X/%X/%X/%X/%X\n",g_stageBState,g_trapSelector,$startup_main,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_macServiceActive,*(unsigned long*)g_trapRoutine,*(unsigned long*)(g_trapRoutine+4),*(unsigned long*)(g_trapRoutine+8),*(unsigned short*)(g_trapRoutine+12),g_trapRoutine[14]
 if g_macServiceEntered != $startup_entered || g_macServiceCompleted != $startup_completed || g_macServiceActive != 0 || $startup_main != 1 || g_stageBState != 3 || g_trapWord!=0xaa95 || g_trapSegment!=5 || g_trapOffset!=0x20cc || *(unsigned long*)(g_trapRoutine+0)!=0x53455450 || *(unsigned long*)(g_trapRoutine+4)!=0x414c4554 || *(unsigned short*)(g_trapRoutine+8)!=0x5445 || *(unsigned char*)(g_trapRoutine+10)!=0 || g_trapSelector!=-1
  printf "startup FAIL: %s / %s CODE %u+$%04x\n",g_trapManager,g_trapRoutine,g_trapSegment,g_trapOffset
  detach
  quit 1
 end
 set $i=0
 while $i<g_resourceCount
  if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
   echo startup FAIL: original MDRV resident\n
   detach
   quit 1
  end
  set $i=$i+1
 end
 printf "startup COUNTS windows=%u services=%u/%u reads=%u bytes=%u original-MDRV=absent\n",g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
 printf "startup PASS: original main, next stop %s / %s CODE %u\n",g_trapManager,g_trapRoutine,g_trapSegment
 detach
 quit 0
end
if g_loadedCodeMask != 3 || g_startupCode == 0 || g_code3Base != 0
 echo startup FAIL: initial CODE residency\n
 detach
 quit 1
end
# Original CODE 1+$AA: JSR $01E6, after CREL and before jump-table fill.
if *(unsigned long *)(g_startupCode+0xaa) != 0x4eba013a
 echo startup FAIL: original loader bytes\n
 detach
 quit 1
end
tbreak *(g_startupCode+0xaa)
continue
# Original CODE 3 header $800a/$803c; first CREL $000e contains $ffff3db6.
if g_loadedCodeMask != 11 || g_code3Base == 0 || *(unsigned short *)g_code3Base != 10 || *(unsigned long *)(g_code3Base+0xe) != (unsigned long)($a5+0xffff3db6)
 echo startup FAIL: original Core relocation\n
 detach
 quit 1
end
printf "startup CREL PASS: header=$%04x Core+$000e=$%08x A5=$%08x\n",*(unsigned short *)g_code3Base,*(unsigned long *)(g_code3Base+0xe),$a5
set $startup_entry=g_code3Base+0x3e4
if *(unsigned long *)$startup_entry != 0x4e56ff00 || *(unsigned long *)($startup_entry+4) != 0x4ebafd7c
 echo startup FAIL: original main bytes\n
 detach
 quit 1
end
tbreak *$startup_entry
continue
if $pc != (unsigned long)$startup_entry
 echo startup FAIL: unexpected debugger stop\n
 detach
 quit 1
end
set $startup_main=1
set $startup_a5=$a5
printf "startup A5=$%08x STRS=$%08x bytes=75616\n",$startup_a5,*(unsigned long *)(g_startupCode+8)
dump binary memory ../tmp/amiga-a5-globals.bin $startup_a5-75616 $startup_a5
# Preserve M1.5's paired heap checkpoint before the first identity query.
tbreak *(g_code3Base+0x3d36)
continue
if $d0 != 0x73797376
 echo startup FAIL: heap checkpoint selector\n
 detach
 quit 1
end
dump binary memory ../tmp/amiga-heap.bin g_applicationZoneBase g_applicationZoneBase+3145728
printf "heap app=$%08x sys=$%08x free=%u largest=%u system-free=%u error=%d\n",g_applicationZoneBase,g_systemZoneBase,g_heapFree,g_heapLargest,g_heapSystemFree,g_heapError
continue
echo startup FAIL: unexpected debugger stop\n
detach
quit 1
