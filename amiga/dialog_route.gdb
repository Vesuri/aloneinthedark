# Observe the complete ordinary startup and M3.2 keyboard route.
# Non-size Dialog Manager presentation must not be silently accepted.
set pagination off
set confirm off
set $dialog_size_count=0
set $dialog_boot_stage=0
break newHiddenSizeDialog
commands
 silent
 set $dialog_size_count=$dialog_size_count+1
 printf "DIALOG_NATIVE hidden-size=%u\n",$dialog_size_count
 continue
end
break newDialog
commands
 silent
 echo FAIL DIALOG unexpected Mac dialog constructor\n
 detach
 quit 1
end
break drawDialog
commands
 silent
 echo FAIL DIALOG unexpected Mac dialog presentation\n
 detach
 quit 1
end
break aitdInputInGameCheckpoint
commands
 silent
 if g_ingameStage!=0 && g_ingameStage!=$dialog_boot_stage+1
  echo FAIL DIALOG startup stage order\n
  detach
  quit 1
 end
 set $dialog_boot_stage=g_ingameStage
 printf "DIALOG_BOOT stage=%u tick=%u\n",g_ingameStage,g_macTicks
 if g_ingameStage==2
  dump binary memory ../tmp/m3-dialog/native-new-game-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-dialog/native-new-game-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_ingameStage==3
  dump binary memory ../tmp/m3-dialog/native-character-story-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-dialog/native-character-story-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 continue
end
break aitdInputMenuProbeFinished
commands
 silent
 if $dialog_size_count!=1 || $dialog_boot_stage!=5
  echo FAIL DIALOG missing startup positive control\n
  detach
  quit 1
 end
 echo PASS native dialog route hidden-size=1 newgame=1 save=1 load=1 Mac-presentation=0\n
 continue
end
source menu_keyboard.gdb
