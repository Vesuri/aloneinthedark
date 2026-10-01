# FIXEDRNG=1 INTROSKIP=1: observe actual original wrapper continuation.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak aitdFixedRandomCheckpoint
continue
if g_stageBState==3 || g_fixedRandomCalls!=64
 echo FAIL fixed random checkpoint\n
 detach
 quit 1
end
set $engine=(unsigned long)s_segments[7].begin
# A5 is the original register preserved at the Line-A frame, obtained at return.
tbreak *($engine+0x4a44)
continue
if g_stageBState==3 || $pc!=$engine+0x4a44
 echo FAIL fixed random original continuation\n
 detach
 quit 1
end
set $gamea5=$a5
if *(unsigned short*)($gamea5-0x1078)!=g_fixedRandomMixed || *(unsigned short*)($gamea5-0xd8f2)!=0
 echo FAIL fixed random original result or character\n
 detach
 quit 1
end
set $i=0
while $i<64
 printf "FIXED_RANDOM row=%u seed=%X mixed=%X result=%X next=%X segment=%u offset=%X\n",$i,g_fixedRandomRows[$i][0],g_fixedRandomRows[$i][1],g_fixedRandomRows[$i][2],g_fixedRandomRows[$i][3],g_fixedRandomRows[$i][4],g_fixedRandomRows[$i][5]
 set $i=$i+1
end
printf "FIXED_RANDOM_END calls=%u choice=%u mixed=%X ticks=%u frames=%u\n",g_fixedRandomCalls,*(unsigned short*)($gamea5-0xd8f2),*(unsigned short*)($gamea5-0x1078),g_macTicks,g_macFramesPresented
echo COMPLETE native fixed random\n
detach
quit 0
