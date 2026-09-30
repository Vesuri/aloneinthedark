set $pn=1
while $pn<=20
 tbreak dispatchMacTrap if trap==0xa8f6
 continue
 set $pr=*(unsigned long*)(frame+2)+2
 if $pr!=(unsigned long)s_segments[13].begin+0x384
  echo FAIL picture caller\n
  detach
  quit 1
 end
 if $pn==1
  printf "PICT8_BYTES data=%04X%04X%04X%04X\n",*(unsigned short*)($pr-8),*(unsigned short*)($pr-6),*(unsigned short*)($pr-4),*(unsigned short*)($pr-2)
 end
 set $pa=(unsigned long)userStack
 set $ph=*(unsigned long*)($pa+4)
 set $pb=*(unsigned long*)$ph
 set $pict_size=*(unsigned short*)$pb
 printf "PICT8_STORAGE handle=%X body=%X size=%u\n",$ph,$pb,$pict_size
 set $pt=*(unsigned long*)$pa
 set $pp=*(unsigned long*)s_qdThePort
 set $pm=*(unsigned long*)*(unsigned long*)($pp+2)
 set $px=*(unsigned long*)$pm
 set $pz=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
 set $pv=*(unsigned long*)*(unsigned long*)($pp+24)
 set $pcp=*(unsigned long*)*(unsigned long*)($pp+28)
 printf "PICT8_ENTER n=%u sp=%X rect=%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$pn,$pa,*(unsigned short*)$pt,*(unsigned short*)($pt+2),*(unsigned short*)($pt+4),*(unsigned short*)($pt+6),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
 eval "dump binary memory ../tmp/pict8-native-%u-enter-port.bin %u %u",$pn,$pp,$pp+108
 eval "dump binary memory ../tmp/pict8-native-%u-enter-pm.bin %u %u",$pn,$pm,$pm+50
 eval "dump binary memory ../tmp/pict8-native-%u-enter-pixels.bin %u %u",$pn,$px,$px+$pz
 eval "dump binary memory ../tmp/pict8-native-%u-enter-picture.bin %u %u",$pn,$pb,$pb+$pict_size
 eval "dump binary memory ../tmp/pict8-native-%u-enter-vis.bin %u %u",$pn,$pv,$pv+10
 eval "dump binary memory ../tmp/pict8-native-%u-enter-clip.bin %u %u",$pn,$pcp,$pcp+10
 tbreak *$pr
 continue
 if $pc!=$pr
  echo FAIL picture return\n
  detach
  quit 1
 end
 printf "PICT8_RETURN n=%u sp=%X rect=%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$pn,$sp,*(unsigned short*)$pt,*(unsigned short*)($pt+2),*(unsigned short*)($pt+4),*(unsigned short*)($pt+6),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/pict8-native-%u-return-port.bin %u %u",$pn,$pp,$pp+108
 eval "dump binary memory ../tmp/pict8-native-%u-return-pm.bin %u %u",$pn,$pm,$pm+50
 eval "dump binary memory ../tmp/pict8-native-%u-return-pixels.bin %u %u",$pn,$px,$px+$pz
 eval "dump binary memory ../tmp/pict8-native-%u-return-picture.bin %u %u",$pn,$pb,$pb+$pict_size
 eval "dump binary memory ../tmp/pict8-native-%u-return-vis.bin %u %u",$pn,$pv,$pv+10
 eval "dump binary memory ../tmp/pict8-native-%u-return-clip.bin %u %u",$pn,$pcp,$pcp+10
 set $pn=$pn+1
end
echo PASS original eight-bit picture preparation calls=20\n
