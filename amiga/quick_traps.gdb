# Build LINEAPROBE=1. Test native quick entries before ordinary game startup.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL quick traps loud stop: %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdQuickTrapProbeComplete
commands
 silent
 set $q=(unsigned char*)&g_quickTrapProbe
 set $i=0
 while $i<15
  if *(unsigned long*)($q+328+$i*4)!=0x11110000+$i || *(unsigned long*)($q+392+$i*4)!=0x11110000+$i || *(unsigned long*)($q+456+$i*4)!=0x11110000+$i
   echo FAIL quick traps live registers\n
   detach
   quit 1
  end
  set $i=$i+1
 end
 if (*(unsigned short*)($q+388)&31)!=31 || (*(unsigned short*)($q+452)&31)!=31 || (*(unsigned short*)($q+516)&31)!=31
  echo FAIL quick traps CCR\n
  detach
  quit 1
 end
 if *(unsigned long*)($q+320)!=*(unsigned long*)($q+324) || *(unsigned long*)($q+320)!=*(unsigned long*)($q+528) || *(unsigned long*)($q+256)!=0x12345678 || *(unsigned long*)($q+260)!=0x00030004 || *(unsigned short*)($q+264)!=11 || *(unsigned long*)($q+524)!=1
  echo FAIL quick traps Pascal stack, pen state or patch routing\n
  detach
  quit 1
 end
 if *(unsigned long*)($q+536)!=1 || *(unsigned long*)($q+540)!=(unsigned long)g_applicationZoneBase || *(unsigned long*)($q+544)!=(unsigned long)g_applicationZoneBase
  echo FAIL quick GetZone alias patch and restored A0 result\n
  detach
  quit 1
 end
 echo PASS quick traps: all 15 registers, CCR, Pascal stack, pen state, patched callable originals, OS aliases and restored entries\n
 detach
 quit 0
end
continue
