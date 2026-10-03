# INTROSKIP=1 FIXEDRNG=1 CIAMUSIC=1; no broad profiler.
# Read-only original checkpoints. Create tmp/corridor-phases/amiga first.
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
set $dark3=(unsigned long)s_segments[6].begin
set $sample=0
set $tracking=0
break *($dark+0x3ed4) if *(unsigned short*)$a3==288
if *(unsigned short*)($dark3+0x1da0)!=0x48e7
 echo FAIL corridor model-setup bytes\n
 detach
 quit 1
end
break *($dark3+0x1da0)
if *(unsigned short*)($dark3+0x1e3c)!=0x8040
 echo FAIL corridor vertices-done bytes\n
 detach
 quit 1
end
break *($dark3+0x1e3c)
if *(unsigned short*)($dark3+0x1e66)!=0x3439
 echo FAIL corridor surfaces-prepared bytes\n
 detach
 quit 1
end
break *($dark3+0x1e66)
if *(unsigned short*)($dark3+0x1efe)!=0x41f9
 echo FAIL corridor sort-done bytes\n
 detach
 quit 1
end
break *($dark3+0x1efe)
if *(unsigned short*)($dark3+0x1f2e)!=0x4280
 echo FAIL corridor draw-list-done bytes\n
 detach
 quit 1
end
break *($dark3+0x1f2e)
if *(unsigned short*)($dark+0x3eda)!=0x4fef
 echo FAIL corridor draw-return bytes\n
 detach
 quit 1
end
break *($dark+0x3eda)
while 1
 continue
 set $phase=0
 if $pc==$dark3+0x1da0
  set $phase=1
  if $tracking
   printf "CORRIDOR_PHASE sample=%u phase=model-setup ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  end
 end
 if $pc==$dark3+0x1e3c
  set $phase=1
  if $tracking
   printf "CORRIDOR_PHASE sample=%u phase=vertices-done ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  end
 end
 if $pc==$dark3+0x1e66
  set $phase=1
  if $tracking
   printf "CORRIDOR_PHASE sample=%u phase=surfaces-prepared ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  end
 end
 if $pc==$dark3+0x1efe
  set $phase=1
  if $tracking
   printf "CORRIDOR_PHASE sample=%u phase=sort-done ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  end
 end
 if $pc==$dark3+0x1f2e
  set $phase=1
  if $tracking
   printf "CORRIDOR_PHASE sample=%u phase=draw-list-done ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  end
 end
 if $pc==$dark+0x3eda
  set $phase=1
  if $tracking
   printf "CORRIDOR_PHASE sample=%u phase=draw-return ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
   set $tracking=0
  end
 end
 if !$phase
 if $pc==$dark+0x5658
  printf "CORRIDOR_PHASE sample=%u phase=next-loop ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
  eval "dump binary memory ../tmp/corridor-phases/amiga/%03u-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200",$sample
  if *(unsigned short*)($a5-0xcd68)!=1 || *(unsigned short*)($a5-0xcd70)!=2
   if $sample<5 || $tracking
    echo FAIL incomplete corridor sample\n
    detach
    quit 1
   end
   echo PASS native natural corridor phases\n
   detach
   quit 0
  end
 else
  if $pc!=$dark+0x3ed4
   printf "FAIL unexpected corridor checkpoint pc=%X\n",$pc
   detach
   quit 1
  end
  if *(unsigned short*)($a5-0xcd68)==1 && *(unsigned short*)($a5-0xcd70)==2
   set $sample=$sample+1
   set $tracking=1
   set $body=*(unsigned long*)($sp+12)
   if *(unsigned short*)($a3+2)!=265 || *(unsigned short*)$body!=3
    echo FAIL corridor person model\n
    detach
    quit 1
   end
   printf "CORRIDOR_PHASE sample=%u phase=draw ticks=%u room=%u camera=%u\n",$sample,g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
   eval "dump binary memory ../tmp/corridor-phases/amiga/%03u-body.bin $body $body+3438",$sample
   eval "dump binary memory ../tmp/corridor-phases/amiga/%03u-args.bin $sp $sp+16",$sample
   eval "dump binary memory ../tmp/corridor-phases/amiga/%03u-actor.bin $a3 $a3+160",$sample
  end
 end
end
end
