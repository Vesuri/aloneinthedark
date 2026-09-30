set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
source .run/startup-state.gdb
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
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x2b06
continue
set $code=(unsigned long)s_segments[7].begin
dump binary memory ../tmp/menulist-native-original-code.bin $code+0x2b04 $code+0x2b46
dump binary memory ../tmp/menulist-native-screen-before.bin (char*)s_colorScreen (char*)s_colorScreen+307200
set $spx=(unsigned long)userStack
printf "MLIST seq=1 phase=before sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b06,s_menuManager.count,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=1 phase=before index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
tbreak *($code+0x2b08)
continue
if $pc!=$code+0x2b08
 echo FAIL menu-list return\n
 detach
 quit 1
end
set $spx=$sp
printf "MLIST seq=1 phase=after sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b08,s_menuManager.count,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=1 phase=after index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x2b32
continue
set $code=(unsigned long)s_segments[7].begin
set $m1=*(unsigned long*)(userStack+2)
set $spx=(unsigned long)userStack
printf "MLIST seq=2 phase=before sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b32,s_menuManager.count,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=2 phase=before index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-2-before-menu1.bin $body $end+1
tbreak *($code+0x2b34)
continue
if $pc!=$code+0x2b34
 echo FAIL menu-list return\n
 detach
 quit 1
end
set $spx=$sp
printf "MLIST seq=2 phase=after sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b34,s_menuManager.count,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=2 phase=after index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-2-after-menu1.bin $body $end+1
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x2b32
continue
set $code=(unsigned long)s_segments[7].begin
set $m2=*(unsigned long*)(userStack+2)
set $spx=(unsigned long)userStack
printf "MLIST seq=3 phase=before sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b32,s_menuManager.count,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=3 phase=before index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-3-before-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-3-before-menu2.bin $body $end+1
tbreak *($code+0x2b34)
continue
if $pc!=$code+0x2b34
 echo FAIL menu-list return\n
 detach
 quit 1
end
set $spx=$sp
printf "MLIST seq=3 phase=after sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b34,s_menuManager.count,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=3 phase=after index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-3-after-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-3-after-menu2.bin $body $end+1
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x2b32
continue
set $code=(unsigned long)s_segments[7].begin
set $m3=*(unsigned long*)(userStack+2)
set $spx=(unsigned long)userStack
printf "MLIST seq=4 phase=before sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b32,s_menuManager.count,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=4 phase=before index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-4-before-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-4-before-menu2.bin $body $end+1
set $body=*(unsigned long*)$m3
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-4-before-menu3.bin $body $end+1
tbreak *($code+0x2b34)
continue
if $pc!=$code+0x2b34
 echo FAIL menu-list return\n
 detach
 quit 1
end
set $spx=$sp
printf "MLIST seq=4 phase=after sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b34,s_menuManager.count,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=4 phase=after index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-4-after-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-4-after-menu2.bin $body $end+1
set $body=*(unsigned long*)$m3
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-4-after-menu3.bin $body $end+1
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x2b32
continue
set $code=(unsigned long)s_segments[7].begin
set $m4=*(unsigned long*)(userStack+2)
set $spx=(unsigned long)userStack
printf "MLIST seq=5 phase=before sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b32,s_menuManager.count,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=5 phase=before index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-before-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-before-menu2.bin $body $end+1
set $body=*(unsigned long*)$m3
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-before-menu3.bin $body $end+1
set $body=*(unsigned long*)$m4
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-before-menu4.bin $body $end+1
tbreak *($code+0x2b34)
continue
if $pc!=$code+0x2b34
 echo FAIL menu-list return\n
 detach
 quit 1
end
set $spx=$sp
printf "MLIST seq=5 phase=after sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b34,s_menuManager.count,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=5 phase=after index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-after-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-after-menu2.bin $body $end+1
set $body=*(unsigned long*)$m3
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-after-menu3.bin $body $end+1
set $body=*(unsigned long*)$m4
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-5-after-menu4.bin $body $end+1
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x2b44
continue
set $code=(unsigned long)s_segments[7].begin
set $spx=(unsigned long)userStack
printf "MLIST seq=6 phase=before sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b44,s_menuManager.count,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=6 phase=before index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-before-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-before-menu2.bin $body $end+1
set $body=*(unsigned long*)$m3
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-before-menu3.bin $body $end+1
set $body=*(unsigned long*)$m4
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-before-menu4.bin $body $end+1
tbreak *($code+0x2b46)
continue
if $pc!=$code+0x2b46
 echo FAIL menu-list return\n
 detach
 quit 1
end
set $spx=$sp
printf "MLIST seq=6 phase=after sp=%X pc=%X count=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2b46,s_menuManager.count,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<s_menuManager.count
 set $h=(unsigned long)s_menuManager.entries[$i].handle
 printf "MLIST_ENTRY seq=6 phase=after index=%X handle=%X id=%X bar=%X\n",$i,$h,*(unsigned short*)*(unsigned long*)$h,s_menuManager.entries[$i].inMenuBar
 set $i=$i+1
end
set $body=*(unsigned long*)$m1
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-after-menu1.bin $body $end+1
set $body=*(unsigned long*)$m2
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-after-menu2.bin $body $end+1
set $body=*(unsigned long*)$m3
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-after-menu3.bin $body $end+1
set $body=*(unsigned long*)$m4
set $end=$body+15+*(unsigned char*)($body+14)
while *(unsigned char*)$end!=0
 set $end=$end+5+*(unsigned char*)$end
end
dump binary memory ../tmp/menulist-native-6-after-menu4.bin $body $end+1
dump binary memory ../tmp/menulist-native-screen-after.bin (char*)s_colorScreen (char*)s_colorScreen+307200
echo PASS native menu-list lifecycle\n
set $dan=(unsigned long)s_segments[12].begin
tbreak *($dan+0x38)
continue
set $args=$sp
set $font_d0=$d0
set $out=*(unsigned long*)$args
set $name=*(unsigned long*)($args+4)
if $pc!=$dan+0x38 || *(unsigned long*)($dan+0x38)!=0xa9003f3c || *(unsigned long*)$name!=0x0554696d || *(unsigned short*)($name+4)!=0x6573
 echo FAIL second original Times call\n
 detach
 quit 1
end
tbreak *($dan+0x3a)
continue
if $pc!=$dan+0x3a || *(short*)$out!=20 || $sp!=(unsigned long)$args+8 || g_soundDriverCalls!=2 || $d0!=$font_d0 || *(short*)(g_macLowMemory+140)!=0 || *(short*)(g_macLowMemory+100)!=0
 echo FAIL second original Times result/stack/driver/register/errors\n
 detach
 quit 1
end
printf "PASS font second: Dan1+003A result=%d stack=$%08x native-driver-calls=%u\n",*(short*)$out,$sp,g_soundDriverCalls
printf "PASS font second ABI: D0=$%08x preserved stack-pop=8 ResErr=0 MemErr=0\n",$d0
source unionrect_calls.gdb
source detached_resource_call.gdb
source gworld_device_call.gdb
source rgb_colors_calls.gdb
source picture8_calls.gdb
source textwidth_calls.gdb
printf "MLIST_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u reads=%u bytes=%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
if g_stageBState!=3 || g_macServiceActive!=1 || s_userService.trap!=0xa0f8
 echo FAIL menu-list progression\n
 detach
 quit 1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
  echo FAIL original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
echo PASS menu-list next-stop original-MDRV=absent\n
if g_trapWord!=0xa0f8 || g_trapSegment!=3 || g_trapOffset!=0x17fc || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed
 echo FAIL menu-list startup endpoint\n
 detach
 quit 1
end
echo startup PASS: original main, next stop SOUND DRIVER / SELECTOR17 CODE 3\n
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
set $screen=s_loudStopScreen
printf "AGA_STOP state=%u trap=%X segment=%u offset=%X queued=%u presented=%u pending=%u\n",g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending
if g_stageBState!=3 || g_trapWord!=0xa0f8 || g_trapSegment!=3 || g_trapOffset!=0x17fc || g_macFramesQueued!=9 || g_macFramesPresented>9
 echo FAIL AGA startup boundary\n
 detach
 quit 1
end
printf "AGA_PENDING front=%X back=%X active=%X next=%X crop=%u/%u sync=%u\n",$screen->m_chip,$screen->m_back,$screen->m_copper,$screen->m_nextCopper,$screen->m_nextCropLeft,$screen->m_nextCropTop,$screen->m_syncRectCount
set $target=$screen->m_framePending ? $screen->m_back : $screen->m_chip
set $copper=$screen->m_framePending ? $screen->m_nextCopper : $screen->m_copper
dump binary memory ../tmp/aga-startup-queued-planes.bin (char*)$target (char*)$target+64000
dump binary memory ../tmp/aga-startup-queued-copper.bin (char*)$copper (char*)$copper+2248
dump binary memory ../tmp/aga-startup-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/aga-startup-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
if g_macFramesPresented<9
 tbreak aitdMacMouseVBI if g_macFramesPresented==9
 continue
end
printf "AGA_ACTIVE front=%X back=%X copper=%X crop=%u/%u queued=%u presented=%u pending=%u line=%u late=%u\n",$screen->m_chip,$screen->m_back,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
if $screen->m_framePending || g_macFramesPresented!=9 || $screen->m_chip!=$target || $screen->m_copper!=$copper || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150 || $screen->m_mouseAllowed
 echo FAIL AGA VBI publication\n
 detach
 quit 1
end
dump binary memory ../tmp/aga-startup-active-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-startup-active-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
echo PASS AGA startup queued and VBI-published next=SELECTOR17\n
detach
quit 0
