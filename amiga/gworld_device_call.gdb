tbreak dispatchMacTrap if trap==0xab1d && (regs[0]&65535)==0 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[13].begin+0x234
continue
set $code=s_segments[13].begin
set $args=(unsigned long)userStack
set $out=*(unsigned long*)($args+18)
set $bounds=*(unsigned long*)($args+12)
set $input_color_handle=*(unsigned long*)($args+8)
set $colors=*(unsigned long*)*(unsigned long*)($args+8)
printf "GW_ENTER sp=%X flags=%X device=%X ctable=%X bounds=%X depth=%X output=%X result=%X zone=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),$bounds,*(unsigned short*)($args+16),$out,*(unsigned short*)($args+22),s_currentZone->arena_,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "GW_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($code+0x216),*(unsigned short*)($code+0x218),*(unsigned short*)($code+0x21a),*(unsigned short*)($code+0x21c),*(unsigned short*)($code+0x21e),*(unsigned short*)($code+0x220),*(unsigned short*)($code+0x222),*(unsigned short*)($code+0x224),*(unsigned short*)($code+0x226),*(unsigned short*)($code+0x228),*(unsigned short*)($code+0x22a),*(unsigned short*)($code+0x22c),*(unsigned short*)($code+0x22e),*(unsigned short*)($code+0x230),*(unsigned short*)($code+0x232),*(unsigned short*)($code+0x234)
dump binary memory ../tmp/gworld-native-bounds.bin (char*)$bounds (char*)$bounds+8
dump binary memory ../tmp/gworld-native-input-clut.bin (char*)$colors (char*)$colors+2056
dump binary memory ../tmp/gworld-native-before-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/gworld-native-before-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
tbreak *($code+0x236)
continue
if $pc!=$code+0x236
 echo FAIL NewGWorld return\n
 detach
 quit 1
end
source gworld_records.gdb
set $colors=*(unsigned long*)$input_color_handle
dump binary memory ../tmp/gworld-native-input-clut-after.bin (char*)$colors (char*)$colors+2056
echo PASS native device-table NewGWorld allocation\n
