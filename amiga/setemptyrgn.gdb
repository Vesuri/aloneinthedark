set pagination off
set confirm off
break AitdScreen::showLoudStop
# The public injection wrapper is inlined and its standalone body is discarded.
# Break on the linked queue writer; never a stale debug-info-only address.
tbreak *recordKey
continue
set $target=(unsigned long)s_segments[5].begin+0x5768
if *(unsigned short*)$target!=0xa8dd
 echo FAIL original SetEmptyRgn site\n
 detach
 quit 1
end
tbreak *$target
continue
if $pc!=$target
 echo FAIL original SetEmptyRgn caller not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap
continue
if g_stageBState==3
 echo FAIL SetEmptyRgn not reached\n
 detach
 quit 1
end
set $er_sp=(unsigned long)userStack
set $er_call=*(unsigned long*)(frame+2)
set $er_handle=*(unsigned long*)$er_sp
set $er_body=*(unsigned long*)$er_handle
set $er_size=*(unsigned short*)$er_body
set $er_zone=(unsigned long)s_applicationZone.arena_
dump binary memory ../tmp/setemptyrgn-native-caller.bin (char*)$er_call-6 (char*)$er_call+2
dump binary memory ../tmp/setemptyrgn-native-enter-region.bin (char*)$er_body (char*)$er_body+$er_size
printf "SETEMPTYRGN_ENTER sp=%X call=%X handle=%X body=%X size=%X result=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$er_sp,$er_call,$er_handle,$er_body,$er_size,*(unsigned short*)($er_sp+4),$er_zone,s_memoryError,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
tbreak *($er_call+2) if $sp==$er_sp+4
continue
if $pc!=$er_call+2
 echo FAIL SetEmptyRgn return\n
 detach
 quit 1
end
printf "SETEMPTYRGN_RETURN sp=%X call=%X handle=%X body=%X size=%X result=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$er_call,$er_handle,*(unsigned long*)$er_handle,*(unsigned short*)*(unsigned long*)$er_handle,*(unsigned short*)($er_sp+4),$er_zone,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $er_after=*(unsigned long*)$er_handle
dump binary memory ../tmp/setemptyrgn-native-return-region.bin (char*)$er_after (char*)$er_after+10
echo PASS native original SetEmptyRgn region and ownership\n
detach
quit 0
