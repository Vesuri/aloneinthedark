# INTROSKIP=1 FIXEDRNG=1 CIAMUSIC=1; no broad profiler.
# Read-only mask checkpoints and polygon/region captures. Fourteen user
# breakpoints plus four reserved internal entries fit the installed debugger.
# Create tmp/corridor-mask before running.
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
set $call=0
set $actor=-1
set $poly=0
set $incall=0
if *(unsigned short*)($dark+0x3fba)!=0x4eba
 echo FAIL mask begin bytes\n
 detach
 quit 1
end
break *($dark+0x3fba)
if *(unsigned short*)($dark+0x319a)!=0x4a39
 echo FAIL mask clip-done bytes\n
 detach
 quit 1
end
break *($dark+0x319a)
if *(unsigned short*)($dark+0x3266)!=0x6000
 echo FAIL mask setup-done bytes\n
 detach
 quit 1
end
break *($dark+0x3266)
if *(unsigned short*)($dark+0x3354)!=0x2850
 echo FAIL mask cache bytes\n
 detach
 quit 1
end
break *($dark+0x3354)
if *(unsigned short*)($dark+0x3394)!=0x42a7
 echo FAIL mask build bytes\n
 detach
 quit 1
end
break *($dark+0x3394)
if *(unsigned short*)($dark+0x33ec)!=0xa8c6
 echo FAIL mask polygon bytes\n
 detach
 quit 1
end
break *($dark+0x33ec)
if *(unsigned short*)($dark+0x33ee)!=0x2f0a
 echo FAIL mask polygon-done bytes\n
 detach
 quit 1
end
break *($dark+0x33ee)
if *(unsigned short*)($dark+0x33f2)!=0x2f0a
 echo FAIL mask close-done bytes\n
 detach
 quit 1
end
break *($dark+0x33f2)
if *(unsigned short*)($dark+0x33fa)!=0x2046
 echo FAIL mask inset-done bytes\n
 detach
 quit 1
end
break *($dark+0x33fa)
if *(unsigned short*)($dark+0x346c)!=0xa8ec
 echo FAIL mask copy bytes\n
 detach
 quit 1
end
break *($dark+0x346c)
if *(unsigned short*)($dark+0x346e)!=0x95ca
 echo FAIL mask copy-done bytes\n
 detach
 quit 1
end
break *($dark+0x346e)
if *(unsigned short*)($dark+0x3fbe)!=0x4eba
 echo FAIL mask end bytes\n
 detach
 quit 1
end
break *($dark+0x3fbe)
while 1
 continue
 set $known=0
 if $pc==$dark+0x3fba
  set $known=1
  set $incall=1
  set $call=$call+1
  set $actor=*(short*)$a3
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=begin ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x319a
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=clip-done ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x3266
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=setup-done ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x3354
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=cache ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x3394
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=build ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x33ec
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=polygon ticks=%u\n",$step,$call,$actor,g_macTicks
  set $poly=$poly+1
  set $record=*(unsigned long*)*(unsigned long*)$sp
  set $bytes=*(unsigned short*)$record
  if $bytes<26 || $bytes>270
   echo FAIL polygon extent\n
   detach
   quit 1
  end
  eval "dump binary memory ../tmp/corridor-mask/amiga-poly-%03u.bin $record $record+$bytes",$poly
  end
 end
 if $pc==$dark+0x33ee
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=polygon-done ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x33f2
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=close-done ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x33fa
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=inset-done ticks=%u\n",$step,$call,$actor,g_macTicks
  set $record=*(unsigned long*)$a2
  set $bytes=*(unsigned short*)$record
  if $bytes<10 || $bytes>4096
   echo FAIL region extent\n
   detach
   quit 1
  end
  eval "dump binary memory ../tmp/corridor-mask/amiga-region-%03u.bin $record $record+$bytes",$poly
  end
 end
 if $pc==$dark+0x346c
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=copy ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x346e
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=copy-done ticks=%u\n",$step,$call,$actor,g_macTicks
  end
 end
 if $pc==$dark+0x3fbe
  set $known=1
  if $incall
  printf "MASK_STAGE step=%u call=%u actor=%d stage=end ticks=%u\n",$step,$call,$actor,g_macTicks
  set $incall=0
  end
 end
 if $pc==$dark+0x5658
  set $known=1
  if *(unsigned short*)($a5-0xcd68)!=1 || *(unsigned short*)($a5-0xcd70)!=2
   if $step<5 || !$call
    echo FAIL mask incomplete\n
    detach
    quit 1
   end
   echo PASS natural corridor mask stages\n
   detach
   quit 0
  end
  set $step=$step+1
 end
 if !$known
  printf "FAIL mask checkpoint pc=%X\n",$pc
  detach
  quit 1
 end
end
