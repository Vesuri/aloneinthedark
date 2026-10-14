# MONSTERPROFILE=1 FIXEDRNG=1 SCENEFRAMEVERIFY=1; bounded real-game fast hits.
# Create tmp/quick-pen-state and validate with tools/check_quick_pen_state.py.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL quick pen loud stop\n
 detach
 quit 1
end
set $moves=0
set $sizes=0
set $modes=0
set $n=0
break aitdStateQuickPen
set $penbp=$bpnum
continue
while $moves<8 || $sizes<8 || $modes<8
 if $pc!=(unsigned long)aitdStateQuickPen
  echo FAIL quick pen checkpoint\n
  detach
  quit 1
 end
 set $regs=(unsigned long*)$sp
 set $frame=(unsigned char*)($sp+60)
 set $args=(unsigned char*)$a2
 set $ret=*(unsigned long*)($frame+2)+2
 set $ccr=*(unsigned short*)$frame&31
 set $port=*(unsigned char**)s_qdThePort
 set $trap=$d7&65535
 set $argc=4
 if $trap==0xa89c
  set $argc=2
 end
 if $trap!=0xa893 && $trap!=0xa89b && $trap!=0xa89c
  echo FAIL quick pen trap\n
  detach
  quit 1
 end
 set $n=$n+1
 printf "QUICK_PEN n=%u trap=%04X first=%u second=%u\n",$n,$trap,*(unsigned short*)$args,*(unsigned short*)($args+2)
 eval "dump binary memory ../tmp/quick-pen-state/%u-before.bin $port $port+108",$n
 set $saved_d0=$regs[0]
 set $saved_d1=$regs[1]
 set $saved_d2=$regs[2]
 set $saved_d3=$regs[3]
 set $saved_d4=$regs[4]
 set $saved_d5=$regs[5]
 set $saved_d6=$regs[6]
 set $saved_d7=$regs[7]
 set $saved_a0=$regs[8]
 set $saved_a1=$regs[9]
 set $saved_a2=$regs[10]
 set $saved_a3=$regs[11]
 set $saved_a4=$regs[12]
 set $saved_a5=$regs[13]
 set $saved_a6=$regs[14]
 disable $penbp
 tbreak *$ret
 continue
 if $pc!=$ret || $sp!=(unsigned long)$args+$argc || ($sr&31)!=$ccr
  echo FAIL quick pen return stack or CCR\n
  detach
  quit 1
 end
 if $d0!=$saved_d0 || $d1!=$saved_d1 || $d2!=$saved_d2 || $d3!=$saved_d3 || $d4!=$saved_d4 || $d5!=$saved_d5 || $d6!=$saved_d6 || $d7!=$saved_d7 || $a0!=$saved_a0 || $a1!=$saved_a1 || $a2!=$saved_a2 || $a3!=$saved_a3 || $a4!=$saved_a4 || $a5!=$saved_a5 || $a6!=$saved_a6
  echo FAIL quick pen registers\n
  detach
  quit 1
 end
 eval "dump binary memory ../tmp/quick-pen-state/%u-after.bin $port $port+108",$n
 if $trap==0xa893
  set $moves=$moves+1
 end
 if $trap==0xa89b
  set $sizes=$sizes+1
 end
 if $trap==0xa89c
  set $modes=$modes+1
 end
 if $moves<8 || $sizes<8 || $modes<8
  enable $penbp
  continue
 end
end
printf "PASS quick pen ABI moves=%u sizes=%u modes=%u all-registers CCR stack\n",$moves,$sizes,$modes
detach
quit 0
