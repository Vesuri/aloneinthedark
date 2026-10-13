# INGAME=1 RGBCACHEVERIFY=1. Observe actual gameplay traps, never a timing run.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 echo FAIL RGB ABI loud stop\n
 detach
 quit 1
end
set $rgb_n=0
while $rgb_n<64
 tbreak aitdRGBQuick
 continue
 set $rgb_n=$rgb_n+1
 set $rgb_regs=*(unsigned long*)($sp+4)
 set $rgb_frame=*(unsigned long*)($sp+8)
 set $rgb_stack=*(unsigned long*)($sp+12)
 set $rgb_pc=*(unsigned long*)($rgb_frame+2)
 set $rgb_op=*(unsigned short*)$rgb_pc
 set $rgb_return=$rgb_pc+2
 set $rgb_arg=*(unsigned long*)$rgb_stack
 set $rgb_port=*(unsigned long*)s_qdThePort
 set $rgb_hits=g_rgbQuickHits
 set $rgb_ccr=*(unsigned short*)$rgb_frame&31
 printf "RGBABI_ENTER n=%u trap=%X sp=%X ccr=%X rgb=%04X%04X%04X port=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$rgb_n,$rgb_op,$rgb_stack,$rgb_ccr,*(unsigned short*)$rgb_arg,*(unsigned short*)($rgb_arg+2),*(unsigned short*)($rgb_arg+4),$rgb_port,*(unsigned long*)($rgb_regs+0),*(unsigned long*)($rgb_regs+4),*(unsigned long*)($rgb_regs+8),*(unsigned long*)($rgb_regs+12),*(unsigned long*)($rgb_regs+16),*(unsigned long*)($rgb_regs+20),*(unsigned long*)($rgb_regs+24),*(unsigned long*)($rgb_regs+28),*(unsigned long*)($rgb_regs+32),*(unsigned long*)($rgb_regs+36),*(unsigned long*)($rgb_regs+40),*(unsigned long*)($rgb_regs+44),*(unsigned long*)($rgb_regs+48),*(unsigned long*)($rgb_regs+52),*(unsigned long*)($rgb_regs+56)
 eval "dump binary memory ../tmp/rgb-cache-abi-%u-before.bin %u %u",$rgb_n,$rgb_port,$rgb_port+108
 tbreak *$rgb_return
 continue
 if $pc!=$rgb_return || g_rgbCacheFailures
  echo FAIL RGB ABI return\n
  detach
  quit 1
 end
 set $rgb_inverse=(unsigned long)s_mainDeviceITable
 if g_rgbQuick.world && (unsigned long)g_rgbQuick.world->port==$rgb_port
  set $rgb_inverse=(unsigned long)*g_rgbQuick.world->handles[26]
 end
 set $rgb_expected_a1=$rgb_inverse+6+(1<<(3*(*(unsigned short*)($rgb_inverse+4))))
 printf "RGBABI_RETURN n=%u sp=%X ccr=%X hit=%u expectedA1=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$rgb_n,$sp,$ps&31,g_rgbQuickHits-$rgb_hits,$rgb_expected_a1,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/rgb-cache-abi-%u-after.bin %u %u",$rgb_n,$rgb_port,$rgb_port+108
end
echo PASS RGB cache ABI 64 calls\n
detach
quit 0
