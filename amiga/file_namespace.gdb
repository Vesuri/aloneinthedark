# Entered at aitdBuildFileCatalog before any Mac execution or machine takeover.
set pagination off
set confirm off
finish
if $d0 == 0
 printf "NAMESPACE catalog=complete entries=%u\n",g_catalogEntries
else
 printf "NAMESPACE stop=%s\n",(char*)$d0
end
detach
quit 0
