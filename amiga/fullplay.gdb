# Interactive GDB observer. Replace the default capture directory for each run.
# The FIFO wrapper keeps GDB at each checkpoint until the next ordinary-key job.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL FULLPLAY %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputFullPlayCheckpoint
commands
 silent
 if g_fullPlayStatus==65535
  printf "FAIL FULLPLAY invalid command file\n"
  detach
  quit 1
 end
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 set $vars=*(unsigned long*)($world-0xcbcc)
 printf "FULLPLAY_STATE sequence=%u tick=%u status=%u frames=%u actor=%d body=%d x=%d z=%d beta=%d floor=%d room=%d animation=%d track=%d health=%d action=%d\n",g_fullPlaySequence,g_macTicks,g_fullPlayStatus,g_macFramesPresented,*(short*)$actor,*(short*)($actor+2),*(short*)($actor+28),*(short*)($actor+32),*(short*)($actor+42),*(short*)($actor+46),*(short*)($actor+48),*(short*)($actor+62),*(short*)($actor+82),*(short*)($vars+42),*(short*)($vars+180)
 eval "dump binary memory ../tmp/m6/native/current/world-%u.bin %u %u",g_fullPlaySequence,$world-75616,$world
 eval "dump binary memory ../tmp/m6/native/current/vars-%u.bin %u %u",g_fullPlaySequence,$vars,$vars+400
 eval "dump binary memory ../tmp/m6/native/current/screen-%u.bin %u %u",g_fullPlaySequence,s_colorScreen,s_colorScreen+307200
 eval "dump binary memory ../tmp/m6/native/current/clut-%u.bin %u %u",g_fullPlaySequence,s_windowManagerColors,s_windowManagerColors+2056
 eval "shell touch ../tmp/m6/native/current/ready-%u",g_fullPlaySequence
end
continue
