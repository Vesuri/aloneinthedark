# Sourced at MacLoader::run; CODE 3 is not loaded until original LoadSeg runs.
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
# CODE 1+$AA is reached after CREL and before its original jump-table fill.
if g_startupCode == 0 || g_code3Base != 0 || g_loadedCodeMask != 3 || *(unsigned long *)(g_startupCode+0xaa) != 0x4eba013a
  echo boot FAIL: startup residency or loader byte mismatch\n
  detach
  quit 1
end
set $boot_loaded=g_startupCode+0xaa
tbreak *$boot_loaded
continue
if $pc != (unsigned long)$boot_loaded || g_code3Base == 0 || g_loadedCodeMask != 11
  echo boot FAIL: Core loader endpoint not reached\n
  detach
  quit 1
end
set $main=g_code3Base+0x3e4
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
