set $ct_args=(unsigned long)userStack
set $ct_ret=*(unsigned long*)(frame+2)+2
if $ct_ret!=(unsigned long)s_segments[5].begin+0x1fde
 echo FAIL clut129 caller\n
 detach
 quit 1
end
printf "CT129_NATIVE_BYTES %04X%04X%04X%04X\n",*(unsigned short*)($ct_ret-8),*(unsigned short*)($ct_ret-6),*(unsigned short*)($ct_ret-4),*(unsigned short*)($ct_ret-2)
set $ct_reg0=regs[0]
set $ct_reg1=regs[1]
set $ct_reg2=regs[2]
set $ct_reg3=regs[3]
set $ct_reg4=regs[4]
set $ct_reg5=regs[5]
set $ct_reg6=regs[6]
set $ct_reg7=regs[7]
set $ct_reg8=regs[8]
set $ct_reg9=regs[9]
set $ct_reg10=regs[10]
set $ct_reg11=regs[11]
set $ct_reg12=regs[12]
set $ct_reg13=regs[13]
set $ct_reg14=regs[14]
tbreak *$ct_ret
continue
if $pc!=$ct_ret || $sp!=$ct_args+2
 echo FAIL clut129 return\n
 detach
 quit 1
end
set $ct_handle=*(unsigned long*)$sp
set $ct_body=*(unsigned long*)$ct_handle
set $ct_size=*(unsigned long*)($ct_body-20)
set $ct_flags=*(unsigned char*)(s_applicationZone.arena_+*(unsigned long*)($ct_body-8))
set $ct_state=$ct_flags&0xe0
printf "CT129_NATIVE_RETURN handle=%X body=%X size=%u state=%X seed=%X flags=%X entries=%u\n",$ct_handle,$ct_body,$ct_size,$ct_state,*(unsigned long*)$ct_body,*(unsigned short*)($ct_body+4),*(unsigned short*)($ct_body+6)+1
if $d0!=$ct_handle || $a0!=$ct_handle || $ct_size!=2064 || $ct_state!=0 || ($ct_flags&1)!=1
 echo FAIL clut129 handle\n
 detach
 quit 1
end
if $d1!=$ct_reg1
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $d2!=$ct_reg2
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $d3!=$ct_reg3
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $d4!=$ct_reg4
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $d5!=$ct_reg5
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $d6!=$ct_reg6
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $d7!=$ct_reg7
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $a2!=$ct_reg10
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $a3!=$ct_reg11
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $a4!=$ct_reg12
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $a5!=$ct_reg13
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
if $a6!=$ct_reg14
 echo FAIL clut129 preserved register\n
 detach
 quit 1
end
set $ct_i=0
while $ct_i<g_resourceCount
 if s_resourceHandles[$ct_i]==$ct_handle || (s_resourceForks.m_items[$ct_i].item.type==0x4d445256 && s_resourceHandles[$ct_i]!=0)
  echo FAIL clut129 ownership or MDRV\n
  detach
  quit 1
 end
 set $ct_i=$ct_i+1
end
dump binary memory ../tmp/ctable129-native-returned.bin (char*)$ct_body (char*)$ct_body+2064
echo PASS native original clut129 bytes/ownership/ABI MDRV=absent\n
