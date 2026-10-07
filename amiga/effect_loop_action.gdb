set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL effect loop %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdEffectLoopReady
continue
set $loop_count=*(unsigned short*)g_effectLoopProbeCounter
source driver17_call.gdb
if !g_effects[0].stream || g_effects[0].allocated!=256 || g_effects[0].period!=443
 echo FAIL stream ownership/period\n
 detach
 quit 1
end
set $loop_source=g_effects[0].stream->source
set $loop_iv_data=g_effects[0].stream->saved.iv_Data
set $loop_iv_code=g_effects[0].stream->saved.iv_Code
set $loop_iv_node=g_effects[0].stream->saved.iv_Node
set $loop_enable=g_effects[0].stream->savedEnable
set $loop_mask=g_effects[0].stream->mask
set $loop_started=g_effects[0].started
set $loop_channel=g_soundDriver.effects[0].channel
tbreak aitdEffectLoopActionReady
continue
set $action=g_effectLoopProbeAction
set $action_sp=(unsigned long)userStack
set $action_return=*(unsigned long*)$action_sp
set $action_arg=*(unsigned long*)(userStack+8)
set $action_fast=g_m5Audit.liveFast
set $action_chip=g_m5Audit.liveChip
set $action_fast_bytes=((sizeof(EffectDma::Stream)+7)&~7)+4096
set $action_reg2=regs[2]
set $action_reg3=regs[3]
set $action_reg4=regs[4]
set $action_reg5=regs[5]
set $action_reg6=regs[6]
set $action_reg7=regs[7]
set $action_reg8=regs[8]
set $action_reg9=regs[9]
set $action_reg10=regs[10]
set $action_reg11=regs[11]
set $action_reg12=regs[12]
set $action_reg13=regs[13]
set $action_reg14=regs[14]
if !g_effects[0].stream || *(unsigned short*)g_effectLoopProbeCounter!=65535 || g_effects[0].stream->cursor.boundaries<2 || g_macTicks-$loop_started<30
 echo FAIL action requires actively looping source\n
 detach
 quit 1
end
set $action_started=g_macTicks
tbreak *$action_return if $sp==$action_sp+4
continue
printf "EFFECT_LOOP_ACTION_RESULT d0=%X d1=%X packet=%X counter=%u\n",$d0,$d1,$action_arg,*(unsigned short*)g_effectLoopProbeCounter
if $d0 || $d1!=($action==18 ? $action_arg : (($action_arg&0xffff0000)|0x7fff)) || *(unsigned short*)g_effectLoopProbeCounter!=65535
 echo FAIL action ABI/counter\n
 detach
 quit 1
end
if $d2!=$action_reg2
 echo FAIL action preserved d2\n
 detach
 quit 1
end
if $d3!=$action_reg3
 echo FAIL action preserved d3\n
 detach
 quit 1
end
if $d4!=$action_reg4
 echo FAIL action preserved d4\n
 detach
 quit 1
end
if $d5!=$action_reg5
 echo FAIL action preserved d5\n
 detach
 quit 1
end
if $d6!=$action_reg6
 echo FAIL action preserved d6\n
 detach
 quit 1
end
if $d7!=$action_reg7
 echo FAIL action preserved d7\n
 detach
 quit 1
end
if $a0!=$action_reg8
 echo FAIL action preserved a0\n
 detach
 quit 1
end
if $a1!=$action_reg9
 echo FAIL action preserved a1\n
 detach
 quit 1
end
if $a2!=$action_reg10
 echo FAIL action preserved a2\n
 detach
 quit 1
end
if $a3!=$action_reg11
 echo FAIL action preserved a3\n
 detach
 quit 1
end
if $a4!=$action_reg12
 echo FAIL action preserved a4\n
 detach
 quit 1
end
if $a5!=$action_reg13
 echo FAIL action preserved a5\n
 detach
 quit 1
end
if $a6!=$action_reg14
 echo FAIL action preserved a6\n
 detach
 quit 1
end
if g_effects[0].stream || g_m5Audit.liveFast!=$action_fast-$action_fast_bytes || g_m5Audit.accountingErrors
 echo FAIL action stream cleanup\n
 detach
 quit 1
end
if SysBase->IntVects[$loop_source].iv_Data!=$loop_iv_data || SysBase->IntVects[$loop_source].iv_Code!=$loop_iv_code || SysBase->IntVects[$loop_source].iv_Node!=$loop_iv_node || (*(unsigned short*)0xdff01c&$loop_mask)!=$loop_enable
 echo FAIL action interrupt restoration\n
 detach
 quit 1
end
printf "EFFECT_LOOP_ACTION action=%u elapsed=%u counter=%u starts=%u stops=%u\n",$action,g_macTicks-$action_started,*(unsigned short*)g_effectLoopProbeCounter,g_effectStarts,g_effectStops
if $action==17
 if !g_soundDriver.effects[0].active || g_soundDriver.effects[0].channel!=$loop_channel || g_effects[0].id!=0x8001 || g_effects[0].allocated!=4098 || g_m5Audit.liveChip!=$action_chip-256+4104 || g_effectStarts!=2 || g_effectStops!=1
  echo FAIL replacement ownership/buffers\n
  detach
  quit 1
 end
 dump binary memory ../tmp/m4/effects/stream/replacement-pcm.bin g_effects[0].chip g_effects[0].chip+4098
 tbreak stopNativeEffect if index==0
 continue
 if g_macTicks<g_effects[0].ends
  echo FAIL replacement early completion\n
  detach
  quit 1
 end
 finish
end
if g_effects[0].chip || g_soundDriver.effects[0].active || g_soundDriver.effects[0].channel!=-1 || (*(unsigned short*)0xdff002&(1<<$loop_channel)) || g_m5Audit.liveChip!=$action_chip-256 || g_m5Audit.accountingErrors
 echo FAIL action final DMA/memory cleanup\n
 detach
 quit 1
end
echo PASS native active loop action ABI, counter, interrupt restoration and DMA/memory cleanup\n
detach
quit 0
