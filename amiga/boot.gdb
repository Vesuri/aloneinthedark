# Sourced at MacLoader::run, after the current resident CODE loading.
# CODE 0 JT69: 03e0 3f3c 0003 a9f0 -> CODE 3+$03e4 (header-inclusive).
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
  silent
  if g_stageBState == 2
    printf "boot FAIL loud stop: %s / %s CODE %u\n", g_trapManager, g_trapRoutine, g_trapSegment
  else
    printf "boot FAIL loud stop: %s / %s CODE %u+$%04x\n", g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  end
  detach
  quit 1
end
set $main=s_segments[3].begin+0x3e4
if s_segments[3].begin == 0
  echo boot FAIL: CODE 3 not resident; update observer for on-demand loading\n
  detach
  quit 1
end
# Original LINK A6,#-256 / BSR.W bytes, checked against the resource fork.
if *(unsigned long *)$main != 0x4e56ff00 || *(unsigned long *)($main+4) != 0x4ebafd7c
  echo boot FAIL: CODE 3 main byte mismatch\n
  detach
  quit 1
end
break *$main
commands
  silent
  printf "boot PASS: reached CODE 3+$03e4\n"
  detach
  quit 0
end
continue
# A signal, unexpected breakpoint, or interrupt is not main entry.
echo boot FAIL: unexpected debugger stop\n
detach
quit 1
