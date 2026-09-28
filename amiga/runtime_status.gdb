# General snapshot; a loud stop ends the run immediately.
set pagination off
set confirm off
break AitdScreen::showLoudStop
continue
# Report both the emulator CPU tuple and the OS CPU flags.
shell awk '/^CPU=/{found=1; print "emulator " $0} END{if(!found) print "CPU PROBE / NO EMULATOR CPU RECORD"}' .run/logs/fs-uae.log.txt
set $attn=((struct ExecBase *)SysBase)->AttnFlags
set $cpu=0
if $attn & 2
  set $cpu=68020
end
if $attn & 4
  set $cpu=68030
end
if $attn & 8
  set $cpu=68040
end
if $attn & 128
  set $cpu=68060
end
printf "exec_cpu=%u Exec.AttnFlags=$%04x\n",$cpu,$attn
printf "state=%u depth=%u fields=%u ticks=%u jump-entries=%u\n", g_stageBState, g_stageCDepth, g_vbiCount, g_macTicks, g_jumpEntryCount
printf "frames queued/presented=%u/%u\n", g_macFramesQueued, g_macFramesPresented
if g_stageBState == 2
  printf "loader stop: %s / %s segment=CODE %u\n", g_trapManager, g_trapRoutine, g_trapSegment
end
if g_stageBState == 3
  printf "trap=$%04x %s / %s selector=%d caller=CODE %u+$%04x\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSelector, g_trapSegment, g_trapOffset
end
detach
quit
