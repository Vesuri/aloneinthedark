# MONSTERPROFILE=1 FIXEDRNG=1; real callback queries, no guest edits.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL quick driver query loud stop\n
 detach
 quit 1
end
set $hits=0
set $calls=0
set $songs=0
set $effects=0
set $fallbacks=0
break *aitdDriverQueryQuick
set $querybp=$bpnum
continue
while $hits<64 || $songs<8 || $effects<8
 if $pc!=(unsigned long)aitdDriverQueryQuick || $calls>=10000
  echo FAIL quick driver query coverage\n
  detach
  quit 1
 end
 set $calls=$calls+1
 set $creturn=*(unsigned long*)$sp
 set $regs=*(unsigned long**)($sp+4)
 set $frame=*(unsigned char**)($sp+8)
 set $args=*(unsigned char**)($sp+12)
 set $ret=*(unsigned long*)($frame+2)+2
 set $selector=*(unsigned long*)($args+4)
 set $initial_sr=*(unsigned short*)$frame
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
 disable $querybp
 tbreak *$creturn
 continue
 if $pc!=$creturn || ($d0!=0 && $d0!=1)
  echo FAIL quick driver query C return\n
  detach
  quit 1
 end
 if $d0==1
  if $regs[2]!=$saved_d2 || $regs[3]!=$saved_d3 || $regs[4]!=$saved_d4 || $regs[5]!=$saved_d5 || $regs[6]!=$saved_d6 || $regs[7]!=$saved_d7 || $regs[8]!=$saved_a0 || $regs[9]!=$saved_a1 || $regs[10]!=$saved_a2 || $regs[11]!=$saved_a3 || $regs[12]!=$saved_a4 || $regs[13]!=$saved_a5 || $regs[14]!=$saved_a6
   echo FAIL quick driver query saved registers\n
   detach
   quit 1
  end
  set $saved_d0=$regs[0]
  set $saved_d1=$regs[1]
  set $flags=*(unsigned short*)$frame&31
  if $selector==4
   set $expected_flags=($saved_d0!=0 ? 8 : 4)
  else
   set $expected_flags=($initial_sr&16)|($saved_d0==0 ? 4 : (($saved_d0&0x8000)!=0 ? 8 : 0))
  end
  if $flags!=$expected_flags || (*(unsigned short*)$frame&0xffe0)!=($initial_sr&0xffe0)
   echo FAIL quick driver query selector CCR\n
   detach
   quit 1
  end
  tbreak *$ret
  continue
  if $pc!=$ret || $sp!=(unsigned long)$args || ($sr&31)!=$flags
   echo FAIL quick driver query stack or CCR\n
   detach
   quit 1
  end
  if $d0!=$saved_d0 || $d1!=$saved_d1 || $d2!=$saved_d2 || $d3!=$saved_d3 || $d4!=$saved_d4 || $d5!=$saved_d5 || $d6!=$saved_d6 || $d7!=$saved_d7 || $a0!=$saved_a0 || $a1!=$saved_a1 || $a2!=$saved_a2 || $a3!=$saved_a3 || $a4!=$saved_a4 || $a5!=$saved_a5 || $a6!=$saved_a6
   echo FAIL quick driver query live registers\n
   detach
   quit 1
  end
  set $hits=$hits+1
  if $selector==4
   set $songs=$songs+1
  end
  if $selector==20
   set $effects=$effects+1
  end
  printf "QUICK_QUERY n=%u selector=%u d0=%X d1=%X ccr=%X\n",$hits,$selector,$d0,$d1,$flags
 else
  set $fallbacks=$fallbacks+1
 end
 if $hits<64 || $songs<8 || $effects<8
  enable $querybp
  continue
 end
end
if $fallbacks==0
 echo FAIL quick driver query fallback coverage\n
 detach
 quit 1
end
printf "PASS quick driver queries hits=%u songs=%u effects=%u registers CCR C-stack\n",$hits,$songs,$effects
detach
quit 0
