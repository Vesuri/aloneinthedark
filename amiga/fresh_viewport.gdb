# Integrated M2.4 acceptance: fresh preferences through first AGA publication.
# Read-only target observations; launcher classifies the on-disk fixture.
set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
if $startup_catalog!=42
 echo FAIL fresh viewport requires absent preferences\n
 detach
 quit 1
end
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL fresh viewport loud stop: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
tbreak dispatchMacTrap if trap==0xa97c
continue
set $dan=(unsigned long)s_segments[13].begin
if *(unsigned long*)(frame+2)!=$dan+0x341c || *(unsigned long*)($dan+0x3418)!=0x4878ffff || *(unsigned long*)($dan+0x341c)!=0xa97c285f || *(unsigned short*)(userStack+8)!=1000 || g_macFramesQueued!=0 || g_macFramesPresented!=0
 echo FAIL original fresh dialog entry\n
 detach
 quit 1
end
tbreak *($dan+0x341e)
continue
set $dialog=*(unsigned long*)$sp
if !$dialog || *(unsigned char*)($dialog+110)!=0 || g_macFramesQueued!=0
 echo FAIL size dialog hidden state\n
 detach
 quit 1
end
tbreak *($dan+0x30fe)
continue
if *(unsigned short*)$pc!=0xa991 || s_windowList!=(unsigned char*)$dialog || *(unsigned char*)($dialog+110)!=0
 echo FAIL original hidden ModalDialog call\n
 detach
 quit 1
end
set $choice=*(unsigned long*)$sp
tbreak *($dan+0x3100)
continue
if *(unsigned short*)$choice!=2 || *(unsigned char*)($dialog+110)!=0 || g_macFramesQueued!=0
 echo FAIL hidden low-resolution choice\n
 detach
 quit 1
end
tbreak *($dan+0x3452)
continue
if *(unsigned short*)$pc!=0xa983 || *(unsigned long*)$sp!=$dialog || *(unsigned char*)($dialog+110)!=0 || g_macFramesQueued!=0
 echo FAIL hidden dialog disposal entry\n
 detach
 quit 1
end
tbreak *($dan+0x3454)
continue
set $i=0
while $i<8
 if s_windows[$i].used && s_windows[$i].dialog && s_windows[$i].resourceID==1000
  echo FAIL size dialog still owned\n
  detach
  quit 1
 end
 set $i=$i+1
end
echo FRESH_DIALOG id=1000 choice=2 hidden=1 disposed=1 queued=0\n
tbreak dispatchMacTrap if trap==0xaa46 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0x109a
continue
if *(unsigned short*)(s_segments[9].begin+0x109a)!=0xaa46 || *(unsigned short*)(userStack+8)!=128 || g_macFramesQueued!=0
 echo FAIL original WIND 128 request\n
 detach
 quit 1
end
echo FRESH_WINDOW caller=Misc1+109A id=128\n
tbreak AitdScreen::presentMacFrame
continue
if cropLeft!=160 || cropTop!=150 || chunky!=s_colorScreen || mouseAllowed || g_macFramesQueued!=0
 echo FAIL first game viewport input\n
 detach
 quit 1
end
set $screen=this
set $game=-1
set $i=0
while $i<8
 if s_windows[$i].used && !s_windows[$i].dialog && s_windows[$i].resourceID==128
  if $game!=-1
   echo FAIL duplicate game window\n
   detach
   quit 1
  end
  set $game=$i
 end
 set $i=$i+1
end
if $game<0 || !s_windows[$game].window[110] || *(unsigned long*)(s_windows[$game].contentRegion+2)!=0x009600a0 || *(unsigned long*)(s_windows[$game].contentRegion+6)!=0x015e01e0
 echo FAIL live content rectangle\n
 detach
 quit 1
end
if *(unsigned long*)s_windowManagerPixMap!=(unsigned long)s_colorScreen || *(unsigned short*)(s_windowManagerPixMap+4)!=0x8280 || *(unsigned long*)(s_windowManagerPixMap+6)!=0 || *(unsigned long*)(s_windowManagerPixMap+10)!=0x01e00280 || *(unsigned short*)(s_windowManagerPixMap+32)!=8 || s_mainDeviceMaster!=s_mainDevice
 echo FAIL main screen storage\n
 detach
 quit 1
end
printf "FRESH_VIEWPORT content=160,150,480,350 crop=%u,%u device=640,480,8\n",cropLeft,cropTop
# This callback follows frame publication in the VBI.
tbreak aitdMacMouseVBI if g_macFramesPresented>0
continue
if g_macFramesQueued!=1 || g_macFramesPresented!=1 || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150
 echo FAIL first viewport publication\n
 detach
 quit 1
end
printf "PASS fresh viewport: hidden-choice=2 window=128 content=160,150,480,350 device=640,480,8 queued=%u presented=%u\n",g_macFramesQueued,g_macFramesPresented
detach
quit 0
