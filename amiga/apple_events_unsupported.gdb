# APPLEEVENTPROBE=1 APPLEEVENTFORM=1..6 constructs arguments on the CPU.
set pagination off
set confirm off
break AitdScreen::showLoudStop
break aitdAEUnsupportedReturned
tbreak aitdAEUnsupportedCall
continue
set $ae_form=g_aeProbeForm
set $ae_expected=0x91f
set $ae_result=$sp+18
if $pc!=aitdAEUnsupportedCall || $ae_form<1 || $ae_form>6 || g_appleEventHandlers.count!=0 || *(unsigned short*)$ae_result!=0xeeee
 echo FAIL unsupported fixture setup\n
 detach
 quit 1
end
if $ae_form==4
 set $ae_expected=0x21b
end
if $ae_form>=5
 set $ae_expected=0x921
end
printf "AE_UNSUPPORTED_INPUT form=%u selector=%X data=%08X%08X%08X%08X%08X\n",$ae_form,$d0,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned long*)($sp+12),*(unsigned long*)($sp+16)
if $d0!=$ae_expected || ($ae_form==1 && *(unsigned char*)$sp!=1) || ($ae_form==2 && *(unsigned long*)($sp+14)!=0x2a2a2a2a) || ($ae_form==3 && *(unsigned long*)($sp+10)!=0x2a2a2a2a) || ($ae_form>=5 && *(unsigned long*)($sp+6)!=$ae_form-5)
 echo FAIL unsupported input readback\n
 detach
 quit 1
end
continue
printf "AE_UNSUPPORTED form=%u state=%u trap=%X selector=%X manager=%s routine=%s count=%u result=%X\n",$ae_form,g_stageBState,g_trapWord,g_trapSelector,g_trapManager,g_trapRoutine,g_appleEventHandlers.count,*(unsigned short*)$ae_result
if g_stageBState!=3 || g_trapWord!=0xa816 || g_trapSelector!=$ae_expected || g_appleEventHandlers.count!=0 || *(unsigned short*)$ae_result!=0xeeee
 echo FAIL unsupported Apple Event state\n
 detach
 quit 1
end
echo PASS unsupported Apple Event form\n
detach
quit 0
