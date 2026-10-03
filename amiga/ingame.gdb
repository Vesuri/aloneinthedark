set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL INGAME %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputInGameCheckpoint
commands
 silent
 printf "FAST_STAGE stage=%u ticks=%u\n",g_ingameStage,g_macTicks
 if g_ingameStage!=5
  continue
 end
end
continue
if g_ingameStage!=5
 echo FAIL INGAME unexpected stop\n
 detach
 quit 1
end
printf "INGAME ticks=%u stage=%u stamp=%u queued=%u presented=%u\n",g_macTicks,g_ingameStage,g_ingameTick,g_macFramesQueued,g_macFramesPresented
if g_macFramesPresented!=0 || s_keyDown[0x40] || s_keyDown[0x44] || s_keyDown[0x4e] || s_keyDown[0x45]
 echo FAIL INGAME boot publication or retained shortcut key\n
 detach
 quit 1
end
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned short*)($dark+0x5658)!=0x4e56
 echo FAIL original game loop bytes\n
 detach
 quit 1
end
tbreak *($dark+0x5658)
continue
tbreak *($dark+0x5658)
continue
set $world=(unsigned long)s_a5WorldStorage+75616
printf "INGAME_WORLD character=%d room=%d camera=%d mode=%d\n",*(short*)($world-0xd8f2),*(short*)($world-0xcd68),*(short*)($world-0xcd70),*(unsigned char*)($world-0x11b4c)
if *(short*)($world-0xd8f2)!=0 || *(short*)($world-0xcd68)!=0 || *(short*)($world-0xcd70)!=0 || *(unsigned char*)($world-0x11b4c)!=1
 echo FAIL INGAME initial world\n
 detach
 quit 1
end
printf "INGAME_READY ticks=%u frames=%u\n",g_macTicks,g_macFramesPresented
dump binary memory ../tmp/ingame-screen.bin s_colorScreen s_colorScreen+307200
dump binary memory ../tmp/ingame-clut.bin s_windowManagerColors s_windowManagerColors+2056
dump binary memory ../tmp/ingame-actors.bin $world-0xb292 $world-0xb292+16000
echo PASS INGAME original game loop reached\n
detach
quit 0
