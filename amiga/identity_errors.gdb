# IDENTITYPROBE=1: error cases use real instructions, not GDB register writes.
set pagination off
set confirm off
break aitdIdentityProbeReturned
commands
 silent
 printf "identity-errors FAIL: probe returned, stage=%u\n",g_identityProbeStage
 detach
 quit 1
end
break AitdScreen::showLoudStop
continue
if g_identityProbeStage != 2 || g_trapWord != 0xa1ad || g_trapSelector != 0x78787878
 printf "identity-errors FAIL: stage=%u trap=$%x selector=$%x\n",g_identityProbeStage,g_trapWord,g_trapSelector
 detach
 quit 1
end
echo PASS identity-errors: qtim=-5551 a/ux=-5550 unknown=loud-stop\n
detach
quit 0
