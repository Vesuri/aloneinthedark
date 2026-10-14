# INGAME=1 SCENEFRAMEVERIFY=1. Observe 16 calls per opcode; no debugger writes.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 printf "FAIL thin lines %s / %s\n",manager,routine
 detach
 quit 1
end
break *aitdLineQuickThin
set $thin_bp=$bpnum
break *aitdLineQuickEmpty
set $empty_bp=$bpnum
set $n=0
set $to=0
set $relative=0
while $n<32
 continue
 if (unsigned long)$a5!=(unsigned long)aitdLineNativeReturn
  loop_continue
 end
 set $op=$d7&65535
 if ($op==0xa891 && $to==16) || ($op==0xa892 && $relative==16)
  loop_continue
 end
 if $op==0xa891
  set $to=$to+1
 else
  set $relative=$relative+1
 end
 set $n=$n+1
 set $regs=(unsigned long)$sp
 set $frame=(unsigned long)$sp+60
 set $stack=(unsigned long)$a4
 set $ret=*(unsigned long*)($frame+2)+2
 printf "THIN_TARGET n=%u op=%X target=%08X\n",$n,$op,(($d2&65535)<<16)|($d3&65535)
 set $port=(unsigned long)$a0
 set $pm=(unsigned long)$a2
 set $pixels=(unsigned long)$a3
 set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
 printf "THINABI_ENTER n=%u sp=%X ccr=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$stack,*(unsigned short*)$frame&31,*(unsigned long*)($regs+4),*(unsigned long*)($regs+8),*(unsigned long*)($regs+12),*(unsigned long*)($regs+16),*(unsigned long*)($regs+20),*(unsigned long*)($regs+24),*(unsigned long*)($regs+28),*(unsigned long*)($regs+36),*(unsigned long*)($regs+40),*(unsigned long*)($regs+44),*(unsigned long*)($regs+48),*(unsigned long*)($regs+52),*(unsigned long*)($regs+56)
 eval "dump binary memory ../tmp/thin-lines/%u-enter-port.bin %u %u",$n,$port,$port+108
 eval "dump binary memory ../tmp/thin-lines/%u-enter-pm.bin %u %u",$n,$pm,$pm+50
 eval "dump binary memory ../tmp/thin-lines/%u-enter-pixels.bin %u %u",$n,$pixels,$pixels+$bytes
 set $r=*(unsigned long*)*(unsigned long*)($port+24)
 eval "dump binary memory ../tmp/thin-lines/%u-enter-region24.bin %u %u",$n,$r,$r+10
 set $r=*(unsigned long*)*(unsigned long*)($port+28)
 eval "dump binary memory ../tmp/thin-lines/%u-enter-region28.bin %u %u",$n,$r,$r+10
 disable $thin_bp $empty_bp
 tbreak *$ret
 continue
 enable $thin_bp $empty_bp
 if $pc!=$ret || $d0
  echo FAIL thin lines return\n
  detach
  quit 1
 end
 printf "THINABI_RETURN n=%u sp=%X ccr=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$sp,$ps&31,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/thin-lines/%u-return-port.bin %u %u",$n,$port,$port+108
 eval "dump binary memory ../tmp/thin-lines/%u-return-pm.bin %u %u",$n,$pm,$pm+50
 eval "dump binary memory ../tmp/thin-lines/%u-return-pixels.bin %u %u",$n,$pixels,$pixels+$bytes
 set $r=*(unsigned long*)*(unsigned long*)($port+24)
 eval "dump binary memory ../tmp/thin-lines/%u-return-region24.bin %u %u",$n,$r,$r+10
 set $r=*(unsigned long*)*(unsigned long*)($port+28)
 eval "dump binary memory ../tmp/thin-lines/%u-return-region28.bin %u %u",$n,$r,$r+10
end
if g_sceneFrameEndChecks==0 || g_sceneFrameEndFailures!=0 || g_quickServiceChecks==0
 echo FAIL thin-line frame/service verification\n
 detach
 quit 1
end
printf "THIN_SERVICES scene_checks=%u failures=%u service_checks=%u\n",g_sceneFrameEndChecks,g_sceneFrameEndFailures,g_quickServiceChecks
echo PASS native assembly thin lines\n
detach
quit 0
