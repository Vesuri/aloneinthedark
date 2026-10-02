# Build INTROSKIP=1 SONGCOST=1; run on the baseline a1200-020.
# Measure menu clear to first subsequent frame; this does not prove host video.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL song cost loud stop: %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak getFontNumber
continue
set $dan=(unsigned long)s_segments[12].begin
if *(unsigned long*)($dan+0x1374)!=0x42a7a975 || *(unsigned short*)($dan+0x13e6)!=0x4227
 echo FAIL song cost original menu bytes\n
 detach
 quit 1
end
tbreak *($dan+0x13e6)
continue
tbreak AitdScreen::presentMacFrame
continue
set $clearTick=g_macTicks
set $clearFrames=g_macFramesPresented
dump binary memory ../tmp/song-cost-clear.bin chunky chunky+307200
dump binary memory ../tmp/song-cost-clear-colors.bin colorTable colorTable+2056
tbreak AitdScreen::presentMacFrame
continue
if g_macFramesPresented!=$clearFrames+1 || g_macTicks<=$clearTick
 echo FAIL song cost frame sequence\n
 detach
 quit 1
end
dump binary memory ../tmp/song-cost-next.bin chunky chunky+307200
dump binary memory ../tmp/song-cost-next-colors.bin colorTable colorTable+2056
printf "SONG_COST_GAP clear=%u next=%u elapsed=%u events=%u noteTicks=%u maxNoteTicks=%u calls=%u serviceTicks=%u maxServiceTicks=%u convertTicks=%u maxConvertTicks=%u\n",$clearTick,g_macTicks,g_macTicks-$clearTick,g_songCost[0],g_songCost[1],g_songCost[2],g_songCost[3],g_songCost[4],g_songCost[5],g_songCost[6],g_songCost[7]
echo PASS song cost measurement: consecutive frame submissions and elapsed game ticks\n
detach
quit 0
