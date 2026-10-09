tbreak aitdLineADispatch if (*(unsigned short*)*(unsigned long*)(frame+2))==0xaa2c
continue
set $da_args=(unsigned long)userStack
set $da_return=*(unsigned long*)(frame+2)+2
set $da_device=*(unsigned long*)($da_args+2)
set $da_body=*(unsigned long*)$da_device
if $da_return!=(unsigned long)s_segments[9].begin+0xe3c || $da_device!=(unsigned long)&s_mainDeviceMaster
 echo FAIL original device attribute caller/handle\n
 detach
 quit 1
end
printf "DA_BYTES data=%04X%04X%04X%04X%04X\n",*(unsigned short*)($da_return-10),*(unsigned short*)($da_return-8),*(unsigned short*)($da_return-6),*(unsigned short*)($da_return-4),*(unsigned short*)($da_return-2)
printf "DA_ENTRY fixture=-1 sp=%X attribute=%X device=%X result=%04X flags=%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$da_args,*(unsigned short*)$da_args,$da_device,*(unsigned short*)($da_args+6),*(unsigned short*)($da_body+20),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/device-attribute-native-entry.bin $da_body $da_body+62
tbreak *$da_return
continue
if $pc!=$da_return
 echo FAIL device attribute return\n
 detach
 quit 1
end
printf "DA_RETURN fixture=-1 sp=%X attribute=%X device=%X result=%04X flags=%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,*(unsigned short*)$da_args,$da_device,*(unsigned short*)($da_args+6),*(unsigned short*)($da_body+20),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/device-attribute-native-return.bin $da_body $da_body+62
echo PASS native TestDeviceAttribute original=1\n
