# Production timing build: no PROBES/C2PVERIFY. Read-only original boundaries.
set pagination off
set confirm off
set width 0
set $paces=0
set $bookSeen=0
set $logoSeen=0
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL pacing loud stop\n
 detach
 quit 1
end
# The common raster entry observes both direct and general CopyBits dispatch.
tbreak copyPortBits8
continue
set $dark2=(unsigned long)s_segments[5].begin
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned short*)($dark2+0x1d52)!=0x2f39 || *(unsigned long*)($dark2+0x1f46)!=0x2f0b4eb9 || *(unsigned long*)($dark+0x5220)!=0x600001b8
 echo FAIL pacing original boundary bytes\n
 detach
 quit 1
end
break AitdScreen::paceFrame
commands
 silent
 if g_macBookFrameActive || g_macSceneFrameOwner
  echo FAIL pacing inside incomplete drawing batch\n
  detach
  quit 1
 end
 set $paces=$paces+1
 continue
end
define logo_complete
 if $paces-$logoPaces!=1 || (unsigned short)(g_macFramesQueued-$logoQueued)!=1
  printf "FAIL logo boundary waits=%u publications=%u\n",$paces-$logoPaces,(unsigned short)(g_macFramesQueued-$logoQueued)
  detach
  quit 1
 end
 printf "PACE_LOGO n=%u fields=%u waits=%u publications=%u\n",$logoSeen,(unsigned short)(g_vbiCount-$logoField),$paces-$logoPaces,(unsigned short)(g_macFramesQueued-$logoQueued)
end
break *($dark2+0x1d52)
commands
 silent
 if $logoSeen
  logo_complete
 end
 set $logoSeen=$logoSeen+1
 set $logoPaces=$paces
 set $logoQueued=g_macFramesQueued
 set $logoField=g_vbiCount
 continue
end
break *($dark2+0x1f46)
commands
 silent
 if !$logoSeen
  echo FAIL logo animation skipped\n
  detach
  quit 1
 end
 logo_complete
 continue
end
break beginBookFrame
commands
 silent
 if !g_macBookFrameActive
  set $bookPaces=$paces
  set $bookQueued=g_macFramesQueued
  set $bookField=g_vbiCount
  set $bookMode=mode
  set $bookColumn=column
 end
 continue
end
break AitdScreen::queueFrame
commands
 silent
 if g_macBookFramesCompleted>$bookSeen
  if g_macBookFramesCompleted!=$bookSeen+1 || g_macBookFrameActive || $paces-$bookPaces!=1 || g_macFramesQueued!=$bookQueued || this->m_syncCount!=1 || s_dirtyRectCount!=1
   echo FAIL book partial publication, extra wait or dirty bounds\n
   detach
   quit 1
  end
  set $bookSeen=g_macBookFramesCompleted
  set $r=this->m_syncRects[0]
  set $left=(s_dirtyLeft-left)&~15
  set $right=$left+((s_dirtyRight-left-$left+31)&~31)
  if $right>320
   set $left=$left-($right-320)
   set $right=320
  end
  if $r.left!=$left || $r.right!=$right || $r.top!=s_dirtyTop-top || $r.bottom!=s_dirtyBottom-top
   echo FAIL book conversion exceeds coordinate-derived alignment\n
   detach
   quit 1
  end
  printf "PACE_BOOK n=%u mode=%u column=%u fields=%u dirty=%d,%d,%d,%d c2p=%d,%d,%d,%d\n",$bookSeen,$bookMode,$bookColumn,(unsigned short)(g_vbiCount-$bookField),s_dirtyTop-top,s_dirtyLeft-left,s_dirtyBottom-top,s_dirtyRight-left,$r.top,$r.left,$r.bottom,$r.right
 end
 continue
end
break *($dark+0x5220)
commands
 silent
 if $bookSeen!=840 || g_macBookFramesCompleted!=840 || g_macBookFrameActive
  echo FAIL incomplete book pacing coverage\n
  detach
  quit 1
 end
 printf "PASS frame boundaries: logo=%u book=%u waits=%u\n",$logoSeen,$bookSeen,$paces
 detach
 quit 0
end
continue
