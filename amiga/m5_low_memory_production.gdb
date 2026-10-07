set pagination off
set confirm off
tbreak MacLoader::preparationError
continue
printf "M5_LOW_PRODUCTION reason=%s application=%X system=%X\n",s_preparationError,s_applicationArena,s_systemArena
if s_applicationArena || s_systemArena
 echo FAIL low memory arena cleanup\n
 detach
 quit 1
end
echo PASS production low memory startup rejection\n
detach
quit 0
