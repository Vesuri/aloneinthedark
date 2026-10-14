# MONSTERPROFILE=1 FIXEDRNG=1 C2PVERIFY=1; correctness only, not timings.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL bounds loud stop\n
 detach
 quit 1
end
break aitdC2PVerifyFailed
commands
 silent
 echo FAIL fight C2P pixels\n
 detach
 quit 1
end
# First hit animation, independent of how many expensive verified frames preceded
# the encounter. Actor records: Carnby slot 1, monster slot 12, animation at $3e.
break AitdScreen::queueFrame if g_ingameStage==5 && *(short*)(s_currentA5-0xb292+160+0x3e)==237 && *(short*)(s_currentA5-0xb292+12*160+0x3e)>=0
continue
delete $bpnum
set $seen=0
break AitdScreen::queueFrame
commands
 silent
 printf "BOUNDS scene=%u crop=%d,%d dirty=%u converted=%u\n",g_macSceneFramesCompleted,top,left,s_dirtyRectCount,this->m_syncCount
 set $i=0
 while $i<s_dirtyRectCount
  set $r=s_dirtyRects[$i]
  printf "DIRTY %d %d %d %d\n",$r.top,$r.left,$r.bottom,$r.right
  set $i=$i+1
 end
 set $i=0
 while $i<this->m_syncCount
  set $r=this->m_syncRects[$i]
  printf "CONVERTED %d %d %d %d\n",$r.top,$r.left,$r.bottom,$r.right
  set $i=$i+1
 end
 set $seen=$seen+1
 if $seen==40
  if g_c2pVerifyFailures || g_c2pPartialFrames<40 || g_macBookFrameActive || g_macSceneFrameOwner
   echo FAIL fight C2P verification or unfinished frame\n
   detach
   quit 1
  end
  printf "PASS fight C2P bounds frames=40 verified=%u partial=%u failures=%u\n",g_c2pVerifiedFrames,g_c2pPartialFrames,g_c2pVerifyFailures
  detach
  quit 0
 end
 continue
end
continue
