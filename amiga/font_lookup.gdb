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
continue
if g_stageBState != 3 || g_trapWord!=0xab1d || g_trapSegment!=10 || g_trapOffset!=0x74 || *(unsigned long*)(g_trapRoutine+0)!=0x4e455747 || *(unsigned long*)(g_trapRoutine+4)!=0x574f524c || g_trapRoutine[8]!=0x44 || g_trapRoutine[9]!=0 || g_trapSelector!=0 || g_resourceRuntimeReads!=39 || g_resourceRuntimeBytes!=177820 || g_overlayRuntimeReads!=31 || g_overlayRuntimeBytes!=80650 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_macServiceActive!=0
 echo FAIL font lookup: next named stop or bounded resource counts\n
 detach
 quit 1
end
set $ri=0
set $font_bodies=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].item.type==0x4d445256 && s_resourceHandles[$ri]!=0
  echo FAIL font lookup: original MDRV became resident\n
  detach
  quit 1
 end
 if s_resourceForks.m_items[$ri].item.fork==15 && ((s_resourceForks.m_items[$ri].item.type==0x464f4e44 && s_resourceForks.m_items[$ri].item.id==20) || (s_resourceForks.m_items[$ri].item.type==0x4e464e54 && s_resourceForks.m_items[$ri].item.id==128))
  if s_resourceHandles[$ri]==0 || *s_resourceHandles[$ri]==0
   echo FAIL font lookup: missing installed font body\n
   detach
   quit 1
  end
  set $body=*s_resourceHandles[$ri]
  if s_resourceForks.m_items[$ri].item.type==0x464f4e44
   dump binary memory ../tmp/font-native-fond.bin $body $body+60
   set $font_bodies=$font_bodies+1
  end
  if s_resourceForks.m_items[$ri].item.type==0x4e464e54
   dump binary memory ../tmp/font-native-nfnt.bin $body $body+1254
   set $font_bodies=$font_bodies+1
  end
 end
 set $ri=$ri+1
end
if $font_bodies!=2
 echo FAIL font lookup: font body count\n
 detach
 quit 1
end
printf "PASS font startup prerequisite: first Times=20 overlay=31/80650 next=NEWGWORLD; second call pending graphics services\n"
detach
quit 0
