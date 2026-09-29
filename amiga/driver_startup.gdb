# Original call observer: no debugger writes to Mac memory or registers.
set pagination off
set confirm off
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
if g_macServiceActive != 1 || s_userService.trap != 0xa900 || s_segments[12].begin == 0
 echo FAIL font lookup: service or Dan1 residency\n
 detach
 quit 1
end
set $dan=s_segments[12].begin
if *(unsigned long*)($dan+0x10)!=0xfffea900 || *(unsigned long*)($dan+0x14)!=0x4a6efffe || *(unsigned long*)($dan+0x38)!=0xa9003f3c
 echo FAIL font lookup: original call bytes\n
 detach
 quit 1
end
set $args=s_userService.arguments
set $out=*(unsigned long*)$args
set $name=*(unsigned long*)($args+4)
if *(unsigned long*)$name!=0x0554696d || *(unsigned short*)($name+4)!=0x6573
 echo FAIL font lookup: original first Times name\n
 detach
 quit 1
end
tbreak *($dan+0x14)
continue
if $pc!=(unsigned long)($dan+0x14) || *(short*)$out!=20 || $sp!=(unsigned long)($args+8) || $d0!=0 || *(short*)(g_macLowMemory+140)!=0 || *(short*)(g_macLowMemory+100)!=0
 echo FAIL font lookup: first original result or stack\n
 detach
 quit 1
end
printf "PASS font first: Dan1+0014 result=%d stack=$%08x D0=$%08x\n",*(short*)$out,$sp,$d0
if *(unsigned long*)(g_code3Base+0x1d46)!=0x4e90508f || *(unsigned long*)(g_code3Base+0x1d60)!=0x4e90508f || *(unsigned long*)(g_code3Base+0x1cf4)!=0x2b50f954
 echo FAIL driver: original call/store bytes\n
 detach
 quit 1
end
tbreak *(g_code3Base+0x1d46)
continue
if $pc!=(unsigned long)(g_code3Base+0x1d46) || *(unsigned long*)$sp!=21 || $a0!=(unsigned long)*g_soundDriverHandle || *(unsigned long*)$a0!=0xa0f84e75
 echo FAIL driver: call 1 or installed entry\n
 detach
 quit 1
end
set $driver_sp=$sp
set $packet=*(unsigned long*)($sp+4)
if *(unsigned long*)$packet!=0x00060002 || *(unsigned short*)($packet+4)!=2
 echo FAIL driver: initialization packet\n
 detach
 quit 1
end
set $save_d2=$d2
set $save_d3=$d3
set $save_d4=$d4
set $save_d5=$d5
set $save_d6=$d6
set $save_d7=$d7
set $save_a0=$a0
set $save_a1=$a1
set $save_a2=$a2
set $save_a3=$a3
set $save_a4=$a4
set $save_a5=$a5
set $save_a6=$a6
tbreak *(g_code3Base+0x1d48)
continue
if $pc!=(unsigned long)(g_code3Base+0x1d48) || $sp!=$driver_sp || $d0!=0 || $d1!=0 || g_soundDriverCalls!=1 || $d2!=$save_d2 || $d3!=$save_d3 || $d4!=$save_d4 || $d5!=$save_d5 || $d6!=$save_d6 || $d7!=$save_d7 || $a0!=$save_a0 || $a1!=$save_a1 || $a2!=$save_a2 || $a3!=$save_a3 || $a4!=$save_a4 || $a5!=$save_a5 || $a6!=$save_a6
 echo FAIL driver: return registers or stack\n
 detach
 quit 1
end
if g_soundDriver.initialized!=1 || g_soundDriver.songLimit!=6 || g_soundDriver.normalizedLimit!=2 || g_soundDriver.effectLimit!=2 || g_soundDriver.requestedRate!=22 || g_soundDriver.interpolation!=0
 echo FAIL driver: initialized native state\n
 detach
 quit 1
end
printf "PASS native driver call: selector=21 D0=0 D1=0 preserved=13 stack=unchanged rate=22 voices=6/2/2\n"
tbreak *(g_code3Base+0x1d60)
continue
if $pc!=(unsigned long)(g_code3Base+0x1d60) || *(unsigned long*)$sp!=24 || $a0!=(unsigned long)*g_soundDriverHandle || *(unsigned long*)$a0!=0xa0f84e75
 echo FAIL driver: call 2 or installed entry\n
 detach
 quit 1
end
set $driver_sp=$sp
if *(unsigned long*)($sp+4)!=0x10b
 echo FAIL driver: quality argument\n
 detach
 quit 1
end
set $save_d2=$d2
set $save_d3=$d3
set $save_d4=$d4
set $save_d5=$d5
set $save_d6=$d6
set $save_d7=$d7
set $save_a0=$a0
set $save_a1=$a1
set $save_a2=$a2
set $save_a3=$a3
set $save_a4=$a4
set $save_a5=$a5
set $save_a6=$a6
tbreak *(g_code3Base+0x1d62)
continue
if $pc!=(unsigned long)(g_code3Base+0x1d62) || $sp!=$driver_sp || $d0!=0 || $d1!=1 || g_soundDriverCalls!=2 || $d2!=$save_d2 || $d3!=$save_d3 || $d4!=$save_d4 || $d5!=$save_d5 || $d6!=$save_d6 || $d7!=$save_d7 || $a0!=$save_a0 || $a1!=$save_a1 || $a2!=$save_a2 || $a3!=$save_a3 || $a4!=$save_a4 || $a5!=$save_a5 || $a6!=$save_a6
 echo FAIL driver: return registers or stack\n
 detach
 quit 1
end
if g_soundDriver.initialized!=1 || g_soundDriver.songLimit!=6 || g_soundDriver.normalizedLimit!=2 || g_soundDriver.effectLimit!=2 || g_soundDriver.requestedRate!=11 || g_soundDriver.interpolation!=1
 echo FAIL driver: initialized native state\n
 detach
 quit 1
end
printf "PASS native driver call: selector=24 D0=0 D1=1 preserved=13 stack=unchanged rate=11 voices=6/2/2\n"
continue
if g_stageBState!=3 || g_trapWord!=0xa8d8 || g_trapSegment!=10 || g_trapOffset!=0x1da6 || *(unsigned long*)(g_trapRoutine+0)!=0x4e455752 || g_trapRoutine[4]!=0x47 || g_trapRoutine[5]!=0x4e || g_trapRoutine[6]!=0 || g_soundDriverCalls!=2 || g_macServiceActive!=0 || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_systemWindows!=$startup_windows || g_overlayRuntimeReads!=31 || g_overlayRuntimeBytes!=80650 || g_resourceRuntimeReads!=39 || g_resourceRuntimeBytes!=177820
 echo FAIL driver: next screen-size stop\n
 detach
 quit 1
end
set $ri=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].item.type==0x4d445256 && s_resourceHandles[$ri]!=0
  echo FAIL driver: original MDRV resident\n
  detach
  quit 1
 end
 set $ri=$ri+1
end
set $vi=0
while $vi<6
 if g_soundDriver.songs[$vi].active!=0 || g_soundDriver.songs[$vi].sample!=0 || g_soundDriver.songs[$vi].channel!=-1
  echo FAIL driver: song voice initialization\n
  detach
  quit 1
 end
 set $vi=$vi+1
end
set $vi=0
while $vi<2
 if g_soundDriver.effects[$vi].active!=0 || g_soundDriver.effects[$vi].sample!=0 || g_soundDriver.effects[$vi].channel!=-1
  echo FAIL driver: effect voice initialization\n
  detach
  quit 1
 end
 set $vi=$vi+1
end
set $vi=0
while $vi<4
 if g_soundDriver.channels[$vi]!=-1
  echo FAIL driver: native channel initialization\n
  detach
  quit 1
 end
 set $vi=$vi+1
end
printf "DRIVER_COUNTS prep=%u/%u app=%u/%u overlay=%u/%u windows=%u services=%u/%u lowmem=%u mask=%x resources=%u\n",g_overlaySourceReads,g_overlaySourceBytes,g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_lowMemoryAppliedSites,g_loadedCodeMask,g_resourceCount
printf "PASS native driver startup: Jnth=11 calls=2 first-Times=20 second=pending-graphics next=NEWRGN original-MDRV=absent\n"
detach
quit 0
