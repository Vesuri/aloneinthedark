# INTROSKIP=1 FIXEDRNG=1 CIAMUSIC=1; no broad profiler.
# Read-only original scene checkpoints. Keep this reduced ten-breakpoint set:
# the installed debugger also reserves four internal entries.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL corridor phase loud stop\n
 detach
 quit 1
end
tbreak aitdInputInjectProbeKey
continue
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned short*)($dark+0x5658)!=0x4e56 || *(unsigned short*)($dark+0x3ed4)!=0x4eb9
 echo FAIL corridor original bytes\n
 detach
 quit 1
end
break *($dark+0x5658)
set $landing=0
set $ready=0
while !$ready
 continue
 if $pc!=$dark+0x5658
  echo FAIL corridor route checkpoint\n
  detach
  quit 1
 end
 if *(unsigned short*)($a5-0xcd68)==7 && *(unsigned short*)($a5-0xcd70)==1
  set $landing=1
 end
 if $landing && *(unsigned short*)($a5-0xcd68)==1 && *(unsigned short*)($a5-0xcd70)==2
  set $ready=1
 end
end
if *(unsigned short*)($a5-0xd8f2)!=0
 echo FAIL corridor character\n
 detach
 quit 1
end
set $step=1
if *(unsigned short*)($dark+0x3cce)!=0x4e56
 echo FAIL scene scene-enter bytes\n
 detach
 quit 1
end
break *($dark+0x3cce)
if *(unsigned short*)($dark+0x3d90)!=0x2f3c
 echo FAIL scene background-done bytes\n
 detach
 quit 1
end
break *($dark+0x3d90)
if *(unsigned short*)($dark+0x3ed4)!=0x4eb9
 echo FAIL scene model bytes\n
 detach
 quit 1
end
break *($dark+0x3ed4)
if *(unsigned short*)($dark+0x3eda)!=0x4fef
 echo FAIL scene model-return bytes\n
 detach
 quit 1
end
break *($dark+0x3eda)
if *(unsigned short*)($dark+0x3fba)!=0x4eba
 echo FAIL scene mask bytes\n
 detach
 quit 1
end
break *($dark+0x3fba)
if *(unsigned short*)($dark+0x3fbe)!=0x4eba
 echo FAIL scene mask-return bytes\n
 detach
 quit 1
end
break *($dark+0x3fbe)
if *(unsigned short*)($dark+0x3fe6)!=0x3039
 echo FAIL scene actors-done bytes\n
 detach
 quit 1
end
break *($dark+0x3fe6)
if *(unsigned short*)($dark+0x41e6)!=0x4cdf
 echo FAIL scene scene-exit bytes\n
 detach
 quit 1
end
break *($dark+0x41e6)
while 1
 continue
 set $known=0
 if $pc==$dark+0x3cce
  set $known=1
  printf "SCENE_STAGE step=%u stage=scene-enter ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),-1,-1
 end
 if $pc==$dark+0x3d90
  set $known=1
  printf "SCENE_STAGE step=%u stage=background-done ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),-1,-1
 end
 if $pc==$dark+0x3ed4
  set $known=1
  printf "SCENE_STAGE step=%u stage=model ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),*(short*)$a3,*(short*)($a3+2)
 end
 if $pc==$dark+0x3eda
  set $known=1
  printf "SCENE_STAGE step=%u stage=model-return ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),*(short*)$a3,*(short*)($a3+2)
 end
 if $pc==$dark+0x3fba
  set $known=1
  printf "SCENE_STAGE step=%u stage=mask ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),*(short*)$a3,*(short*)($a3+2)
 end
 if $pc==$dark+0x3fbe
  set $known=1
  printf "SCENE_STAGE step=%u stage=mask-return ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),*(short*)$a3,*(short*)($a3+2)
 end
 if $pc==$dark+0x3fe6
  set $known=1
  printf "SCENE_STAGE step=%u stage=actors-done ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),-1,-1
 end
 if $pc==$dark+0x41e6
  set $known=1
  printf "SCENE_STAGE step=%u stage=scene-exit ticks=%u room=%u camera=%u actor=%d body=%d\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),-1,-1
 end
 if $pc==$dark+0x5658
  set $known=1
  printf "SCENE_STAGE step=%u stage=next-loop ticks=%u room=%u camera=%u actor=-1 body=-1\n",$step,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  if *(unsigned short*)($a5-0xcd68)!=1 || *(unsigned short*)($a5-0xcd70)!=2
   if $step<5
    echo FAIL scene insufficient steps\n
    detach
    quit 1
   end
   echo PASS native natural corridor scene stages\n
   detach
   quit 0
  end
  set $step=$step+1
 end
 if !$known
  printf "FAIL scene unexpected checkpoint pc=%X\n",$pc
  detach
  quit 1
 end
end
