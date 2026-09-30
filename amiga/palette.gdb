set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa91
continue
set $engine=s_segments[7].begin
set $args=(unsigned long)userStack
if *(unsigned long*)(frame+2)!=(unsigned long)$engine+0x1158
 echo FAIL NewPalette entry\n
 detach
 quit 1
end
echo ARM native palette original bytes\n
set $source=*(unsigned long*)($args+4)
set $sourcebody=*(unsigned long*)$source
printf "PALETTE_ENTER sp=%X args=%08X/%08X/%08X/%04X source=%X body=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned short*)($args+12),$source,$sourcebody,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "PALETTE_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($engine+0x114a),*(unsigned short*)($engine+0x114c),*(unsigned short*)($engine+0x114e),*(unsigned short*)($engine+0x1150),*(unsigned short*)($engine+0x1152),*(unsigned short*)($engine+0x1154),*(unsigned short*)($engine+0x1156),*(unsigned short*)($engine+0x1158),*(unsigned short*)($engine+0x115a),*(unsigned short*)($engine+0x115c),*(unsigned short*)($engine+0x115e),*(unsigned short*)($engine+0x1160),*(unsigned short*)($engine+0x1162),*(unsigned short*)($engine+0x1164),*(unsigned short*)($engine+0x1166),*(unsigned short*)($engine+0x1168),*(unsigned short*)($engine+0x116a),*(unsigned short*)($engine+0x116c),*(unsigned short*)($engine+0x116e)
dump binary memory ../tmp/palette-native-source.bin $sourcebody $sourcebody+2056
tbreak *($engine+0x115a)
continue
if $pc!=$engine+0x115a
 echo FAIL NewPalette return\n
 detach
 quit 1
end
set $handle=*(unsigned long*)$sp
set $body=*(unsigned long*)$handle
printf "PALETTE_RETURN sp=%X handle=%X body=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$handle,$body,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "PALETTE_SIZE size=%X mem=%X\n",*(unsigned long*)($body-20),*(unsigned short*)(g_macLowMemory+100)
dump binary memory ../tmp/palette-native-body.bin $body $body+4112
dump binary memory ../tmp/palette-native-source-after.bin $sourcebody $sourcebody+2056
echo PASS native NewPalette capture\n
continue
printf "PALETTE_COUNTS reads=%u bytes=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes
printf "PALETTE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xa976 || g_trapSegment!=12 || g_trapOffset!=0x583a || *(unsigned long*)(g_trapRoutine+0)!=0x434f5059 || *(unsigned long*)(g_trapRoutine+4)!=0x42495453 || g_trapRoutine[8]!=0 || g_macServiceActive!=0
 echo FAIL palette next stop\n
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
echo PASS native palette original-MDRV=absent\n
detach
quit 0
