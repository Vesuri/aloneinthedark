set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak aitdDriverClockProbeComplete
continue
if g_stageBState==3 || g_clockProbeCount!=7 || g_soundDriverCalls!=7
 echo FAIL driver15 clock fixture completion\n
 detach
 quit 1
end
set $i=0
while $i<7
 printf "DRIVER15_FLAGS_NATIVE n=%u input=%08X result=%08X d1=%08X ccr=%02X\n",$i+1,g_clockProbeRows[$i][0],g_clockProbeRows[$i][1],g_clockProbeRows[$i][2],g_clockProbeRows[$i][3]
 set $i=$i+1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
  echo FAIL original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
echo PASS native driver15 condition-code fixture complete MDRV=absent\n
detach
quit 0
