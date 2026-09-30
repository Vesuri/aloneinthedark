set $er_sp=(unsigned long)userStack
set $er_call=*(unsigned long*)(frame+2)
set $er_handle=*(unsigned long*)$er_sp
set $er_body=*(unsigned long*)$er_handle
set $er_size=*(unsigned short*)$er_body
set $er_zone=(unsigned long)s_applicationZone.arena_
if $er_call!=(unsigned long)s_segments[4].begin+0x4182 || *(unsigned short*)($er_call-8)!=0x4227 || *(unsigned short*)($er_call-6)!=0x2f39 || *(unsigned long*)($er_call-4)!=regs[13]-0xbfc8 || *(unsigned long*)$er_call!=0xa8e24a1f || *(unsigned short*)($er_call+4)!=0x6608 || $er_size!=10
 echo FAIL EmptyRgn original caller or region\n
 detach
 quit 1
end
dump binary memory ../tmp/emptyrgn-native-caller.bin (char*)$er_call-8 (char*)$er_call+6
dump binary memory ../tmp/emptyrgn-native-enter-region.bin (char*)$er_body (char*)$er_body+$er_size
printf "EMPTYRGN_ENTER sp=%X call=%X handle=%X body=%X size=%X result=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$er_sp,$er_call,$er_handle,$er_body,$er_size,*(unsigned short*)($er_sp+4),$er_zone,s_memoryError,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
tbreak *($er_call+2) if $sp==$er_sp+4
continue
if $pc!=$er_call+2 || *(unsigned long*)$er_handle!=$er_body
 echo FAIL EmptyRgn return or region master pointer\n
 detach
 quit 1
end
printf "EMPTYRGN_RETURN sp=%X call=%X handle=%X body=%X size=%X result=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$er_call,$er_handle,*(unsigned long*)$er_handle,*(unsigned short*)$er_body,*(unsigned short*)($er_sp+4),$er_zone,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/emptyrgn-native-return-region.bin (char*)$er_body (char*)$er_body+$er_size
echo PASS native original EmptyRgn region and Boolean\n
