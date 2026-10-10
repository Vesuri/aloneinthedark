set $engine=s_segments[5].begin
mac-trap-args
set $args=(unsigned long)$mac_stack
if *(unsigned long*)($mac_frame+2)!=(unsigned long)$engine+0x201c
 echo FAIL NewPalette entry\n
 detach
 quit 1
end
echo ARM native palette original bytes\n
set $source=*(unsigned long*)($args+4)
set $sourcebody=*(unsigned long*)$source
mac-trap-args
printf "PALETTE_ENTER sp=%X args=%08X/%08X/%08X/%04X source=%X body=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned short*)($args+12),$source,$sourcebody,$mac_regs[0],$mac_regs[1],$mac_regs[2],$mac_regs[3],$mac_regs[4],$mac_regs[5],$mac_regs[6],$mac_regs[7],$mac_regs[8],$mac_regs[9],$mac_regs[10],$mac_regs[11],$mac_regs[12],$mac_regs[13],$mac_regs[14]
printf "PALETTE_BYTES data=%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($engine+0x2010),*(unsigned short*)($engine+0x2012),*(unsigned short*)($engine+0x2014),*(unsigned short*)($engine+0x2016),*(unsigned short*)($engine+0x2018),*(unsigned short*)($engine+0x201a),*(unsigned short*)($engine+0x201c)
dump binary memory ../tmp/palette129-native-source.bin $sourcebody $sourcebody+2064
tbreak *($engine+0x201e)
continue
if $pc!=$engine+0x201e
 echo FAIL NewPalette return\n
 detach
 quit 1
end
set $handle=*(unsigned long*)$sp
set $body=*(unsigned long*)$handle
printf "PALETTE_RETURN sp=%X handle=%X body=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$handle,$body,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "PALETTE_SIZE size=%X mem=%X\n",*(unsigned long*)($body-20),*(unsigned short*)(g_macLowMemory+100)
dump binary memory ../tmp/palette129-native-body.bin $body $body+4112
dump binary memory ../tmp/palette129-native-source-after.bin $sourcebody $sourcebody+2064
echo PASS native NewPalette capture\n
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
if *(unsigned long*)($privatebody-20)!=4 || $private==$handle || $private==$source || (*(unsigned char*)(s_applicationZone.arena_+*(unsigned long*)($body-8))&0xe0)!=0 || (*(unsigned char*)(s_applicationZone.arena_+*(unsigned long*)($sourcebody-8))&0xe0)!=0
 echo FAIL palette allocation ownership\n
 detach
 quit 1
end
dump binary memory ../tmp/palette129-native-private.bin $privatebody $privatebody+4
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
