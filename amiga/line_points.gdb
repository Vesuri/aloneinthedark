# INGAME=1. Observe actual assembly particle calls; no debugger writes.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 printf "FAIL line points %s / %s\n",manager,routine
 detach
 quit 1
end
break *aitdLineQuick
set $n=0
while $n<32
 tbreak *aitdLineQuickPoint
 continue
 while $pc==(unsigned long)aitdLineQuick
  set $line_stack=(unsigned long)$a2
  continue
 end
 if $pc!=(unsigned long)aitdLineQuickPoint
  echo FAIL line points checkpoint\n
  detach
  quit 1
 end
 set $n=$n+1
 set $regs=(unsigned long)$sp
 set $frame=(unsigned long)$sp+60
 set $stack=$line_stack
 set $ret=*(unsigned long*)($frame+2)+2
 set $port=(unsigned long)$a0
 set $pm=(unsigned long)$a2
 set $pixels=(unsigned long)$a3
 set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
 printf "POINTABI_ENTER n=%u sp=%X ccr=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$stack,*(unsigned short*)$frame&31,*(unsigned long*)($regs+4),*(unsigned long*)($regs+8),*(unsigned long*)($regs+12),*(unsigned long*)($regs+16),*(unsigned long*)($regs+20),*(unsigned long*)($regs+24),*(unsigned long*)($regs+28),*(unsigned long*)($regs+36),*(unsigned long*)($regs+40),*(unsigned long*)($regs+44),*(unsigned long*)($regs+48),*(unsigned long*)($regs+52),*(unsigned long*)($regs+56)
 eval "dump binary memory ../tmp/line-points/%u-enter-port.bin %u %u",$n,$port,$port+108
 eval "dump binary memory ../tmp/line-points/%u-enter-pm.bin %u %u",$n,$pm,$pm+50
 eval "dump binary memory ../tmp/line-points/%u-enter-pixels.bin %u %u",$n,$pixels,$pixels+$bytes
 set $r=*(unsigned long*)*(unsigned long*)($port+24)
 eval "dump binary memory ../tmp/line-points/%u-enter-region24.bin %u %u",$n,$r,$r+10
 set $r=*(unsigned long*)*(unsigned long*)($port+28)
 eval "dump binary memory ../tmp/line-points/%u-enter-region28.bin %u %u",$n,$r,$r+10
 tbreak *$ret
 continue
 if $pc!=$ret || $d0
  echo FAIL line points return\n
  detach
  quit 1
 end
 printf "POINTABI_RETURN n=%u sp=%X ccr=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$sp,$ps&31,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/line-points/%u-return-port.bin %u %u",$n,$port,$port+108
 eval "dump binary memory ../tmp/line-points/%u-return-pm.bin %u %u",$n,$pm,$pm+50
 eval "dump binary memory ../tmp/line-points/%u-return-pixels.bin %u %u",$n,$pixels,$pixels+$bytes
 set $r=*(unsigned long*)*(unsigned long*)($port+24)
 eval "dump binary memory ../tmp/line-points/%u-return-region24.bin %u %u",$n,$r,$r+10
 set $r=*(unsigned long*)*(unsigned long*)($port+28)
 eval "dump binary memory ../tmp/line-points/%u-return-region28.bin %u %u",$n,$r,$r+10
end
echo PASS native assembly particle points\n
detach
quit 0
