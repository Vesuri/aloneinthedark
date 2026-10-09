dump binary memory ../tmp/window-rgb-native-clut-before.bin s_windowManagerColors s_windowManagerColors+2056
set $rgb_args=(unsigned long)userStack
set $rgb_return=*(unsigned long*)(frame+2)+2
set $rgb=*(unsigned long*)$rgb_args
set $rgb_port=*(unsigned long*)s_qdThePort
if $rgb_return!=(unsigned long)s_segments[12].begin+0x624c
 echo FAIL original RGB caller\n
 detach
 quit 1
end
printf "WRGB_ENTER original=1 fixture=0 trap=AA14 sp=%X rgb=%04X%04X%04X fore=%X back=%X port=%X fields=%04X%04X%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$rgb_args,*(unsigned short*)($rgb+0),*(unsigned short*)($rgb+2),*(unsigned short*)($rgb+4),*(unsigned long*)($rgb_port+80),*(unsigned long*)($rgb_port+84),$rgb_port,*(unsigned short*)($rgb_port+36),*(unsigned short*)($rgb_port+38),*(unsigned short*)($rgb_port+40),*(unsigned short*)($rgb_port+42),*(unsigned short*)($rgb_port+44),*(unsigned short*)($rgb_port+46),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "WRGB_BYTES original=1 data=%04X%04X%04X%04X\n",*(unsigned short*)($rgb_return-8),*(unsigned short*)($rgb_return-6),*(unsigned short*)($rgb_return-4),*(unsigned short*)($rgb_return-2)
dump binary memory ../tmp/window-rgb-native-1-enter-port.bin (char*)$rgb_port (char*)$rgb_port+108
tbreak *$rgb_return
continue
if $pc!=$rgb_return
 echo FAIL RGB return\n
 detach
 quit 1
end
printf "WRGB_RETURN original=1 fixture=0 trap=AA14 sp=%X rgb=%04X%04X%04X fore=%X back=%X port=%X fields=%04X%04X%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,*(unsigned short*)($rgb+0),*(unsigned short*)($rgb+2),*(unsigned short*)($rgb+4),*(unsigned long*)($rgb_port+80),*(unsigned long*)($rgb_port+84),$rgb_port,*(unsigned short*)($rgb_port+36),*(unsigned short*)($rgb_port+38),*(unsigned short*)($rgb_port+40),*(unsigned short*)($rgb_port+42),*(unsigned short*)($rgb_port+44),*(unsigned short*)($rgb_port+46),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/window-rgb-native-1-return-port.bin (char*)$rgb_port (char*)$rgb_port+108
tbreak aitdLineADispatch if (*(unsigned short*)*(unsigned long*)(frame+2))==0xaa15
continue
set $rgb_args=(unsigned long)userStack
set $rgb_return=*(unsigned long*)(frame+2)+2
set $rgb=*(unsigned long*)$rgb_args
set $rgb_port=*(unsigned long*)s_qdThePort
if $rgb_return!=(unsigned long)s_segments[12].begin+0x6254
 echo FAIL original RGB caller\n
 detach
 quit 1
end
printf "WRGB_ENTER original=2 fixture=0 trap=AA15 sp=%X rgb=%04X%04X%04X fore=%X back=%X port=%X fields=%04X%04X%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$rgb_args,*(unsigned short*)($rgb+0),*(unsigned short*)($rgb+2),*(unsigned short*)($rgb+4),*(unsigned long*)($rgb_port+80),*(unsigned long*)($rgb_port+84),$rgb_port,*(unsigned short*)($rgb_port+36),*(unsigned short*)($rgb_port+38),*(unsigned short*)($rgb_port+40),*(unsigned short*)($rgb_port+42),*(unsigned short*)($rgb_port+44),*(unsigned short*)($rgb_port+46),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "WRGB_BYTES original=2 data=%04X%04X%04X%04X\n",*(unsigned short*)($rgb_return-8),*(unsigned short*)($rgb_return-6),*(unsigned short*)($rgb_return-4),*(unsigned short*)($rgb_return-2)
dump binary memory ../tmp/window-rgb-native-2-enter-port.bin (char*)$rgb_port (char*)$rgb_port+108
tbreak *$rgb_return
continue
if $pc!=$rgb_return
 echo FAIL RGB return\n
 detach
 quit 1
end
printf "WRGB_RETURN original=2 fixture=0 trap=AA15 sp=%X rgb=%04X%04X%04X fore=%X back=%X port=%X fields=%04X%04X%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,*(unsigned short*)($rgb+0),*(unsigned short*)($rgb+2),*(unsigned short*)($rgb+4),*(unsigned long*)($rgb_port+80),*(unsigned long*)($rgb_port+84),$rgb_port,*(unsigned short*)($rgb_port+36),*(unsigned short*)($rgb_port+38),*(unsigned short*)($rgb_port+40),*(unsigned short*)($rgb_port+42),*(unsigned short*)($rgb_port+44),*(unsigned short*)($rgb_port+46),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/window-rgb-native-2-return-port.bin (char*)$rgb_port (char*)$rgb_port+108
echo PASS native original window RGB foreground/background\n
dump binary memory ../tmp/window-rgb-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
dump binary memory ../tmp/window-rgb-native-inverse.bin s_mainDeviceITable s_mainDeviceITable+4620
printf "WRGB_INVERSE valid=%u base=%X\n",s_mainDeviceITableValid,s_mainDeviceITable
