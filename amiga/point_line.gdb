# POINTLINEPROBE=1: CPU-owned pixels/pen fixture; debugger only observes.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL POINT %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdPointLineBefore
continue
up
set $args=g_pointLineArguments
set $point_ret=*(unsigned long*)(frame+2)+2
set $reg1=regs[1]
set $reg2=regs[2]
set $reg3=regs[3]
set $reg4=regs[4]
set $reg5=regs[5]
set $reg6=regs[6]
set $reg7=regs[7]
set $reg9=regs[9]
set $reg10=regs[10]
set $reg11=regs[11]
set $reg12=regs[12]
set $reg13=regs[13]
set $reg14=regs[14]
if g_pointLineStage!=1 || g_pointLineBytes!=261452 || *(unsigned long*)$args || $point_ret!=(unsigned long)s_segments[6].begin+0x354c
 echo FAIL POINT fixture/caller layout\n
 detach
 quit 1
end
printf "POINT_NATIVE_ENTER sp=%X port=%X pixels=%X bytes=%u\n",$args,g_pointLinePort,g_pointLinePixels,g_pointLineBytes
dump binary memory ../tmp/m3-death/point-native-enter-port.bin (char*)g_pointLinePort (char*)g_pointLinePort+108
dump binary memory ../tmp/m3-death/point-native-enter-pixels.bin (char*)g_pointLinePixels (char*)g_pointLinePixels+g_pointLineBytes
set $pm=**(unsigned long**)(g_pointLinePort+2)
dump binary memory ../tmp/m3-death/point-native-enter-pm.bin (char*)$pm (char*)$pm+50
set $clut=**(unsigned long**)($pm+42)
dump binary memory ../tmp/m3-death/point-native-enter-clut.bin (char*)$clut (char*)$clut+2056
tbreak *$point_ret
continue
if $pc!=$point_ret || $d0 || $sp!=$args+4 || g_pointLineStage!=2 || $d1!=$reg1 || $d2!=$reg2 || $d3!=$reg3 || $d4!=$reg4 || $d5!=$reg5 || $d6!=$reg6 || $d7!=$reg7 || $a1!=$reg9 || $a2!=$reg10 || $a3!=$reg11 || $a4!=$reg12 || $a5!=$reg13 || $a6!=$reg14
 echo FAIL POINT trap ABI\n
 detach
 quit 1
end
dump binary memory ../tmp/m3-death/point-native-return-port.bin (char*)g_pointLinePort (char*)g_pointLinePort+108
dump binary memory ../tmp/m3-death/point-native-return-pixels.bin (char*)g_pointLinePixels (char*)g_pointLinePixels+g_pointLineBytes
echo PASS native point2 pixel capture and trap ABI preserved=13 result=0 stack=4\n
detach
quit 0
