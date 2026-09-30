set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
if g_loadedCodeMask != 3 || g_startupCode == 0 || g_code3Base != 0
 echo startup FAIL: initial CODE residency\n
 detach
 quit 1
end
# Original CODE 1+$AA: JSR $01E6, after CREL and before jump-table fill.
if *(unsigned long *)(g_startupCode+0xaa) != 0x4eba013a
 echo startup FAIL: original loader bytes\n
 detach
 quit 1
end
tbreak *(g_startupCode+0xaa)
continue
# Original CODE 3 header $800a/$803c; first CREL $000e contains $ffff3db6.
if g_loadedCodeMask != 11 || g_code3Base == 0 || *(unsigned short *)g_code3Base != 10 || *(unsigned long *)(g_code3Base+0xe) != (unsigned long)($a5+0xffff3db6)
 echo startup FAIL: original Core relocation\n
 detach
 quit 1
end
printf "startup CREL PASS: header=$%04x Core+$000e=$%08x A5=$%08x\n",*(unsigned short *)g_code3Base,*(unsigned long *)(g_code3Base+0xe),$a5
set $startup_entry=g_code3Base+0x3e4
if *(unsigned long *)$startup_entry != 0x4e56ff00 || *(unsigned long *)($startup_entry+4) != 0x4ebafd7c
 echo startup FAIL: original main bytes\n
 detach
 quit 1
end
tbreak *$startup_entry
continue
if $pc != (unsigned long)$startup_entry
 echo startup FAIL: unexpected debugger stop\n
 detach
 quit 1
end
set $startup_main=1
set $startup_a5=$a5
printf "startup A5=$%08x STRS=$%08x bytes=75616\n",$startup_a5,*(unsigned long *)(g_startupCode+8)
dump binary memory ../tmp/amiga-a5-globals.bin $startup_a5-75616 $startup_a5
# Preserve M1.5's paired heap checkpoint before the first identity query.
tbreak *(g_code3Base+0x3d36)
continue
if $d0 != 0x73797376
 echo startup FAIL: heap checkpoint selector\n
 detach
 quit 1
end
dump binary memory ../tmp/amiga-heap.bin g_applicationZoneBase g_applicationZoneBase+3145728
printf "heap app=$%08x sys=$%08x free=%u largest=%u system-free=%u error=%d\n",g_applicationZoneBase,g_systemZoneBase,g_heapFree,g_heapLargest,g_heapSystemFree,g_heapError
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xab1d && (regs[0]&65535)==15 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x2da
continue
set $code=(unsigned long)s_segments[10].begin
set $handle=*(unsigned long*)userStack
set $pm=*(unsigned long*)$handle
set $pixels=*(unsigned long*)$pm
set $bytes=(*(unsigned short*)($pm+4)&16383)*(*(unsigned short*)($pm+10)-*(unsigned short*)($pm+6))
dump binary memory ../tmp/pixbase-native-original-code.bin $code+0x2ac $code+0x2dc
dump binary memory ../tmp/pixbase-native-screen-before.bin (char*)s_colorScreen (char*)s_colorScreen+307200
set $spx=(unsigned long)userStack
printf "PBASE phase=locked-before sp=%X pc=%X handle=%X pm=%X pixels=%X bytes=%X result=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2da,$handle,$pm,$pixels,$bytes,*(unsigned long*)$spx,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/pixbase-native-locked-before-pm.bin $pm $pm+50
dump binary memory ../tmp/pixbase-native-locked-before-pixels.bin $pixels $pixels+$bytes
dump binary memory ../tmp/pixbase-native-locked-before-stack.bin $spx $spx+16
tbreak *($code+0x2dc)
continue
if $pc!=$code+0x2dc
 echo FAIL GetPixBaseAddr return\n
 detach
 quit 1
end
set $spx=$sp
printf "PBASE phase=locked-after sp=%X pc=%X handle=%X pm=%X pixels=%X bytes=%X result=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$code+0x2da,$handle,$pm,$pixels,$bytes,*(unsigned long*)$spx,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/pixbase-native-locked-after-pm.bin $pm $pm+50
dump binary memory ../tmp/pixbase-native-locked-after-pixels.bin $pixels $pixels+$bytes
dump binary memory ../tmp/pixbase-native-locked-after-stack.bin $spx $spx+16
tbreak dispatchMacTrap if trap==0xa02e && *(unsigned long*)(frame+2)==$code+0x686
continue
if trap!=0xa02e || regs[0]!=512 || regs[9]!=$pixels
 echo FAIL pixel-address first row\n
 detach
 quit 1
end
set $source=regs[8]
dump binary memory ../tmp/pixbase-native-copy-source.bin $source $source+28672
dump binary memory ../tmp/pixbase-native-copy-before.bin $pixels $pixels+$bytes
dump binary memory ../tmp/pixbase-native-copy-code.bin $code+0x668 $code+0x68a
tbreak *($code+0x342)
continue
if $pc!=$code+0x342
 echo FAIL pixel-address row-copy completion\n
 detach
 quit 1
end
dump binary memory ../tmp/pixbase-native-copy-after.bin $pixels $pixels+$bytes
dump binary memory ../tmp/pixbase-native-copy-after-pm.bin $pm $pm+50
dump binary memory ../tmp/pixbase-native-screen-after.bin (char*)s_colorScreen (char*)s_colorScreen+307200
echo PASS native pixel-address row copy\n
continue
printf "PBASE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u reads=%u bytes=%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
if g_stageBState!=3 || g_macServiceActive!=0
 echo FAIL pixel-address progression\n
 detach
 quit 1
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
echo PASS native GetPixBaseAddr original-MDRV=absent\n
if g_trapWord!=0xa0f8 || g_trapSegment!=3 || g_trapOffset!=0x1a74 || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_systemWindows!=$startup_windows
 echo FAIL pixel-address startup endpoint\n
 detach
 quit 1
end
echo startup PASS: original main, next stop MENU MANAGER / CLEARMENUBAR CODE 7\n
set $screen=s_loudStopScreen
printf "AGA_STOP state=%u trap=%X segment=%u offset=%X queued=%u presented=%u pending=%u\n",g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending
if g_stageBState!=3 || g_trapWord!=0xa0f8 || g_trapSegment!=3 || g_trapOffset!=0x1a74 || g_macFramesQueued!=4 || g_macFramesPresented>4
 echo FAIL AGA startup boundary\n
 detach
 quit 1
end
printf "AGA_PENDING front=%X back=%X active=%X next=%X crop=%u/%u sync=%u\n",$screen->m_chip,$screen->m_back,$screen->m_copper,$screen->m_nextCopper,$screen->m_nextCropLeft,$screen->m_nextCropTop,$screen->m_syncRectCount
set $target=$screen->m_framePending ? $screen->m_back : $screen->m_chip
set $copper=$screen->m_framePending ? $screen->m_nextCopper : $screen->m_copper
dump binary memory ../tmp/aga-startup-queued-planes.bin (char*)$target (char*)$target+64000
dump binary memory ../tmp/aga-startup-queued-copper.bin (char*)$copper (char*)$copper+2248
dump binary memory ../tmp/aga-startup-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/aga-startup-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
if g_macFramesPresented<4
 tbreak aitdMacMouseVBI if g_macFramesPresented==4
 continue
end
printf "AGA_ACTIVE front=%X back=%X copper=%X crop=%u/%u queued=%u presented=%u pending=%u line=%u late=%u\n",$screen->m_chip,$screen->m_back,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
if $screen->m_framePending || g_macFramesPresented!=4 || $screen->m_chip!=$target || $screen->m_copper!=$copper || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150 || $screen->m_mouseAllowed
 echo FAIL AGA VBI publication\n
 detach
 quit 1
end
dump binary memory ../tmp/aga-startup-active-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-startup-active-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
echo PASS AGA startup queued and VBI-published next=SELECTOR22\n
detach
quit 0
