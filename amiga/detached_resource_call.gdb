tbreak dispatchMacTrap if trap==0xa992
continue
set $args=(unsigned long)userStack
set $det_base=(unsigned long)s_segments[13].begin
set $det_return=*(unsigned long*)(frame+2)+2
set $det_handle=*(unsigned long*)$args
if $det_return!=$det_base+0x212 || $det_handle==0
 echo FAIL detached original caller/handle\n
 detach
 quit 1
end
set $det_body=*(unsigned long*)$det_handle
if *(unsigned long*)($det_body-20)!=2056 || *(unsigned long*)($det_body-12)!=2
 echo FAIL detached table allocation\n
 detach
 quit 1
end
set $det_flags=g_applicationZoneBase+*(unsigned long*)($det_body-8)
set $det_state=*(unsigned char*)$det_flags
if $det_state!=1
 echo FAIL detached table flags\n
 detach
 quit 1
end
set $ri=0
while $ri<g_resourceCount
 if s_resourceHandles[$ri]==$det_handle
  echo FAIL detached table still resource-owned\n
  detach
  quit 1
 end
 set $ri=$ri+1
end
printf "DET_ENTER label=original sp=%X handle=%X master=%X res=%X mem=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$args,$det_handle,*(unsigned long*)$det_handle,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "DET_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($det_base+0x20e),*(unsigned short*)($det_base+0x210),*(unsigned short*)($det_base+0x212),*(unsigned short*)($det_base+0x214),*(unsigned short*)($det_base+0x216),*(unsigned short*)($det_base+0x218),*(unsigned short*)($det_base+0x21a),*(unsigned short*)($det_base+0x21c),*(unsigned short*)($det_base+0x21e),*(unsigned short*)($det_base+0x220)
dump binary memory ../tmp/detached-native-before.bin $det_body $det_body+2056
tbreak *$det_return
continue
if $pc!=$det_return || *(unsigned long*)$det_handle!=$det_body || $a0!=0 || *(unsigned char*)$det_flags!=$det_state
 echo FAIL detached return/master/A0\n
 detach
 quit 1
end
printf "DET_RETURN label=original sp=%X handle=%X master=%X res=%X mem=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,$det_handle,*(unsigned long*)$det_handle,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/detached-native-after.bin $det_body $det_body+2056
echo PASS native detached resource original call\n
