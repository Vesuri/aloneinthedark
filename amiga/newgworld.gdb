set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xab1d && (regs[0]&65535)==0 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x74
continue
set $code=s_segments[10].begin
set $args=(unsigned long)userStack
set $out=*(unsigned long*)($args+18)
set $bounds=*(unsigned long*)($args+12)
set $colors=*(unsigned long*)*(unsigned long*)($args+8)
printf "GW_ENTER sp=%X flags=%X device=%X ctable=%X bounds=%X depth=%X output=%X result=%X zone=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),$bounds,*(unsigned short*)($args+16),$out,*(unsigned short*)($args+22),s_currentZone->arena_,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "GW_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($code+0x50),*(unsigned short*)($code+0x52),*(unsigned short*)($code+0x54),*(unsigned short*)($code+0x56),*(unsigned short*)($code+0x58),*(unsigned short*)($code+0x5a),*(unsigned short*)($code+0x5c),*(unsigned short*)($code+0x5e),*(unsigned short*)($code+0x60),*(unsigned short*)($code+0x62),*(unsigned short*)($code+0x64),*(unsigned short*)($code+0x66),*(unsigned short*)($code+0x68),*(unsigned short*)($code+0x6a),*(unsigned short*)($code+0x6c),*(unsigned short*)($code+0x6e),*(unsigned short*)($code+0x70),*(unsigned short*)($code+0x72),*(unsigned short*)($code+0x74)
dump binary memory ../tmp/gworld-native-bounds.bin (char*)$bounds (char*)$bounds+8
dump binary memory ../tmp/gworld-native-input-clut.bin (char*)$colors (char*)$colors+2056
dump binary memory ../tmp/gworld-native-before-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/gworld-native-before-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
tbreak *($code+0x76)
continue
if $pc!=$code+0x76
 echo FAIL NewGWorld return\n
 detach
 quit 1
end
source gworld_records.gdb
echo PASS native NewGWorld allocation\n
continue
printf "GW_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xa891 || g_trapSelector!=-1 || g_trapSegment!=6 || g_trapOffset!=0x337e || g_macServiceActive!=0
 echo FAIL NewGWorld progression\n
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
echo PASS native NewGWorld next-stop original-MDRV=absent\n
detach
quit 0
