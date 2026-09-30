set $rr_sp=(unsigned long)userStack
set $rr_ret=*(unsigned long*)(frame+2)+2
set $rr_rect=*(unsigned long*)$rr_sp
set $rr_handle=*(unsigned long*)($rr_sp+4)
set $rr_body=*(unsigned long*)$rr_handle
set $rr_zone=(unsigned long)s_applicationZone.arena_
if $rr_ret!=(unsigned long)s_segments[4].begin+0x3d48 || *(unsigned short*)($rr_ret-18)!=0x2f39 || *(unsigned long*)($rr_ret-16)!=regs[13]-0xbfcc || *(unsigned short*)($rr_ret-12)!=0x2079 || *(unsigned long*)($rr_ret-10)!=regs[13]-0xc24e || *(unsigned long*)($rr_ret-6)!=0x48680016 || *(unsigned short*)($rr_ret-2)!=0xa8df
 echo FAIL RectRgn original relocated caller bytes\n
 detach
 quit 1
end
dump binary memory ../tmp/rectrgn-native-caller.bin (char*)$rr_ret-18 (char*)$rr_ret
dump binary memory ../tmp/rectrgn-native-enter-region.bin (char*)$rr_body (char*)$rr_body+10
dump binary memory ../tmp/rectrgn-native-enter-rect.bin (char*)$rr_rect (char*)$rr_rect+8
printf "RECTRGN_ENTER sp=%X handle=%X body=%X size=%X rect=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$rr_sp,$rr_handle,$rr_body,*(unsigned short*)$rr_body,$rr_rect,$rr_zone,s_memoryError,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
tbreak *$rr_ret if $sp==$rr_sp+8
continue
if $pc!=$rr_ret || *(unsigned long*)$rr_handle!=$rr_body
 echo FAIL RectRgn return or region master pointer\n
 detach
 quit 1
end
printf "RECTRGN_RETURN sp=%X handle=%X body=%X size=%X rect=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$rr_handle,$rr_body,*(unsigned short*)$rr_body,$rr_rect,$rr_zone,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/rectrgn-native-return-region.bin (char*)$rr_body (char*)$rr_body+10
dump binary memory ../tmp/rectrgn-native-return-rect.bin (char*)$rr_rect (char*)$rr_rect+8
set $rr_found=0
set $rr_block=$rr_zone+64
while $rr_block<$rr_zone+s_applicationZone.end_
 set $rr_span=*(unsigned long*)$rr_block
 if $rr_span<24
  echo FAIL RectRgn malformed heap block\n
  detach
  quit 1
 end
 if *(unsigned long*)($rr_block+12)==3
  set $rr_count=*(unsigned long*)($rr_block+8)
  set $rr_masters=$rr_block+24
  if $rr_handle>=$rr_masters && $rr_handle<$rr_masters+4*$rr_count && ($rr_handle-$rr_masters)%4==0
   set $rr_flags=*(unsigned char*)($rr_masters+4*$rr_count+($rr_handle-$rr_masters)/4)
   set $rr_found=1
  end
 end
 set $rr_block=$rr_block+$rr_span
end
if !$rr_found || *(unsigned long*)($rr_body-12)!=2 || *(unsigned long*)($rr_body-16)!=$rr_handle-$rr_zone || *(unsigned long*)($rr_body-20)!=10 || ($rr_flags&0xe0)!=0
 echo FAIL RectRgn heap ownership\n
 detach
 quit 1
end
printf "RECTRGN_NATIVE size=%X flags=%X owner=%X zone=%X memerr=%X\n",*(unsigned long*)($rr_body-20),$rr_flags&0xe0,$rr_zone,$rr_zone,s_memoryError
echo PASS native original RectRgn and ownership\n
