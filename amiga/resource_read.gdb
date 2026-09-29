# Production on-demand resource acceptance. Read-only debugger observations.
set pagination off
set confirm off
if g_resourceSourceOpen != 1 || g_resourceRuntimeReads != 0 || g_resourceRuntimeBytes != 0 || g_resourceSourceReads != 228 || g_resourceSourceBytes != 201058 || g_resourceCount != 212 || g_loadedCodeMask != 3 || g_lowMemoryValidatedSites != 58
 echo FAIL resource-read: preparation, CODE validation or residency\n
 detach
 quit 1
end
set $ri=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].item.data != 0
  echo FAIL resource-read: retained resource payload pointer\n
  detach
  quit 1
 end
 set $ri=$ri+1
end
break AitdScreen::showLoudStop
continue
if g_trapWord != 0xa820 || g_trapSegment != 7 || g_trapOffset != 0x3cdc || g_resourceRuntimeReads != 13 || g_resourceRuntimeBytes != 68336 || g_systemWindows != 13 || g_resourceSourceMax > 65536 || g_macServiceEntered != 20 || g_macServiceCompleted != 20 || g_macServiceActive != 0
 echo FAIL resource-read: runtime stop, service balance or bounded reads\n
 detach
 quit 1
end
set $ri=0
set $samples=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].item.type == 0x53545253 && s_resourceForks.m_items[$ri].item.id == 0
  if s_resourceForks.m_items[$ri].item.size != 1810 || s_resourceHandles[$ri] == 0 || *s_resourceHandles[$ri] == 0
   echo FAIL resource-read: STRS handle\n
   detach
   quit 1
  end
  set $sample=*s_resourceHandles[$ri]
  dump binary memory ../tmp/resource-strs.bin $sample $sample+1810
  set $samples=$samples+1
 end
 if s_resourceForks.m_items[$ri].item.type == 0x6d637462 && s_resourceForks.m_items[$ri].item.id == 128
  if s_resourceForks.m_items[$ri].item.size != 32 || s_resourceHandles[$ri] == 0 || *s_resourceHandles[$ri] == 0
   echo FAIL resource-read: mctb handle\n
   detach
   quit 1
  end
  set $sample=*s_resourceHandles[$ri]
  dump binary memory ../tmp/resource-mctb.bin $sample $sample+32
  set $samples=$samples+1
 end
 set $ri=$ri+1
end
if $samples != 2
 echo FAIL resource-read: missing samples\n
 detach
 quit 1
end
printf "PASS resource-read: maps=212 preparation=201058 runtime=13/68336 windows=13 samples=2 next=GET1NAMEDRESOURCE\n"
detach
quit 0
