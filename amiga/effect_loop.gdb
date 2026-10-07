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
tbreak stopNativeEffect if index==0
continue
set $loop_fast=g_m5Audit.liveFast
set $loop_chip=g_m5Audit.liveChip
set $loop_alloc_fast=(sizeof(EffectDma::Stream)+7)&~7
set $loop_alloc_fast=$loop_alloc_fast+4096
set $loop_release=0
if g_effectLoopProbeReleaseTick
 set $loop_release=g_effectLoopProbeReleaseTick-$loop_started
end
printf "EFFECT_LOOP_COMPLETE count=%u elapsed=%u counter=%u release=%u records=%u bytes=%u\n",$loop_count,g_macTicks-$loop_started,*(unsigned short*)g_effectLoopProbeCounter,$loop_release,g_effectStreamRecords,g_effectStreamBytes
if g_effectStreamOverflow || *(unsigned short*)g_effectLoopProbeCounter || !g_effects[0].stream->complete
 echo FAIL stream completion/counter\n
 detach
 quit 1
end
dump binary memory ../tmp/m4/effects/stream/native-trace.bin g_effectStreamTrace (char*)g_effectStreamTrace+g_effectStreamRecords*28
dump binary memory ../tmp/m4/effects/stream/native-pcm.bin g_effectStreamPCM g_effectStreamPCM+g_effectStreamBytes
finish
if g_effects[0].stream || g_effects[0].chip || g_effects[0].allocated || g_soundDriver.effects[0].active || g_soundDriver.effects[0].channel!=-1 || (*(unsigned short*)0xdff002&(1<<$loop_channel))
 echo FAIL stream DMA/logical cleanup\n
 detach
 quit 1
end
if g_m5Audit.liveFast!=$loop_fast-$loop_alloc_fast || g_m5Audit.liveChip!=$loop_chip-256 || g_m5Audit.accountingErrors
 echo FAIL stream allocation cleanup\n
 detach
 quit 1
end
if SysBase->IntVects[$loop_source].iv_Data!=$loop_iv_data || SysBase->IntVects[$loop_source].iv_Code!=$loop_iv_code || SysBase->IntVects[$loop_source].iv_Node!=$loop_iv_node || (*(unsigned short*)0xdff01c&$loop_mask)!=$loop_enable
 echo FAIL stream interrupt restoration\n
 detach
 quit 1
end
echo PASS native effect loop ABI, bounded streaming, counter and DMA/memory cleanup\n
detach
quit 0
