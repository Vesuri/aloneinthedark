# INGAME=1 RGBCACHESABOTAGE=1. Guest code flips the first cached result.
set pagination off
set confirm off
break AitdScreen::showLoudStop
continue
if g_rgbCacheFailures!=1 || g_rgbQuickHits!=1
 echo FAIL RGB sabotage did not detect corrupt result\n
 detach
 quit 1
end
printf "RGB_SABOTAGE manager=%s routine=%s failures=%u\n",manager,routine,g_rgbCacheFailures
echo PASS RGB verifier rejected a deliberately wrong cached index\n
detach
quit 0
