# INTROSKIP=1 FIXEDRNG=1; preserve captures before another run.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak aitdInputInjectProbeKey
continue
set $ip_dark=(unsigned long)s_segments[4].begin
if *(unsigned short*)($ip_dark+0x3cb2)!=0x2f3c || *(unsigned short*)($ip_dark+0x3cb8)!=0xa8a2 || *(unsigned long*)($ip_dark+0x5528)!=0x4eba00ac
 echo FAIL idle PaintRect original instruction bytes\n
 detach
 quit 1
end
tbreak *($ip_dark+0x3cb8)
continue
if $pc!=$ip_dark+0x3cb8 || *(unsigned long*)($ip_dark+0x3cb4)!=$a5-0x108a
 echo FAIL idle PaintRect original caller\n
 detach
 quit 1
end
set $ip_port=*(unsigned long*)s_qdThePort
set $ip_map=*(unsigned long*)*(unsigned long*)($ip_port+2)
set $ip_clut=*(unsigned long*)*(unsigned long*)($ip_map+42)
set $ip_vis=*(unsigned long*)*(unsigned long*)($ip_port+24)
set $ip_clip=*(unsigned long*)*(unsigned long*)($ip_port+28)
set $ip_rect=*(unsigned long*)$sp
set $ip_sp=$sp
set $ip_pixels=(unsigned long)s_colorScreen
if *(unsigned short*)($ip_port+56)!=0 || *(unsigned short*)$ip_vis!=10 || *(unsigned short*)$ip_clip!=10
 echo FAIL idle PaintRect reached layout\n
 detach
 quit 1
end
printf "IDLE_PAINT_ENTRY ticks=%u frames=%u mode=%u fore=%u state=%u/%u\n",g_macTicks,g_macFramesPresented,*(unsigned short*)($ip_port+56),*(unsigned long*)($ip_port+80),*(unsigned short*)($a5-0xbfb8),*(unsigned short*)($a5-0xbfb6)
info registers
set $ip_d1=$d1
set $ip_d2=$d2
set $ip_d3=$d3
set $ip_d4=$d4
set $ip_d5=$d5
set $ip_d6=$d6
set $ip_d7=$d7
set $ip_a2=$a2
set $ip_a3=$a3
set $ip_a4=$a4
set $ip_a5=$a5
set $ip_a6=$a6
dump binary memory ../tmp/idle-paint-native-entry-port.bin ($ip_port) ($ip_port)+108
dump binary memory ../tmp/idle-paint-native-entry-pm.bin ($ip_map) ($ip_map)+50
dump binary memory ../tmp/idle-paint-native-entry-clut.bin ($ip_clut) ($ip_clut)+2056
dump binary memory ../tmp/idle-paint-native-entry-vis.bin ($ip_vis) ($ip_vis)+10
dump binary memory ../tmp/idle-paint-native-entry-clip.bin ($ip_clip) ($ip_clip)+10
dump binary memory ../tmp/idle-paint-native-entry-rect.bin ($ip_rect) ($ip_rect)+8
dump binary memory ../tmp/idle-paint-native-entry-screen.bin $ip_pixels $ip_pixels+307200
tbreak *($ip_dark+0x3cba)
continue
if $pc!=$ip_dark+0x3cba || $sp!=$ip_sp+4 || $d0!=0 || $d1!=(($ip_d1&0xffff0000)|8) || $a1!=$ip_port
 echo FAIL idle PaintRect return contract\n
 detach
 quit 1
end
if $d3!=$ip_d3
 echo FAIL idle PaintRect preserved d3\n
 detach
 quit 1
end
if $d4!=$ip_d4
 echo FAIL idle PaintRect preserved d4\n
 detach
 quit 1
end
if $d5!=$ip_d5
 echo FAIL idle PaintRect preserved d5\n
 detach
 quit 1
end
if $d6!=$ip_d6
 echo FAIL idle PaintRect preserved d6\n
 detach
 quit 1
end
if $d7!=$ip_d7
 echo FAIL idle PaintRect preserved d7\n
 detach
 quit 1
end
if $a2!=$ip_a2
 echo FAIL idle PaintRect preserved a2\n
 detach
 quit 1
end
if $a3!=$ip_a3
 echo FAIL idle PaintRect preserved a3\n
 detach
 quit 1
end
if $a4!=$ip_a4
 echo FAIL idle PaintRect preserved a4\n
 detach
 quit 1
end
if $a5!=$ip_a5
 echo FAIL idle PaintRect preserved a5\n
 detach
 quit 1
end
if $a6!=$ip_a6
 echo FAIL idle PaintRect preserved a6\n
 detach
 quit 1
end
printf "IDLE_PAINT_RETURN ticks=%u frames=%u\n",g_macTicks,g_macFramesPresented
info registers
dump binary memory ../tmp/idle-paint-native-return-port.bin ($ip_port) ($ip_port)+108
dump binary memory ../tmp/idle-paint-native-return-pm.bin ($ip_map) ($ip_map)+50
dump binary memory ../tmp/idle-paint-native-return-clut.bin ($ip_clut) ($ip_clut)+2056
dump binary memory ../tmp/idle-paint-native-return-vis.bin ($ip_vis) ($ip_vis)+10
dump binary memory ../tmp/idle-paint-native-return-clip.bin ($ip_clip) ($ip_clip)+10
dump binary memory ../tmp/idle-paint-native-return-rect.bin ($ip_rect) ($ip_rect)+8
dump binary memory ../tmp/idle-paint-native-return-screen.bin $ip_pixels $ip_pixels+307200
echo PASS native idle PaintRect original call and return\n
detach
quit 0
