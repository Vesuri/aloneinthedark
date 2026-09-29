# Production on-demand resource acceptance. Read-only debugger observations.
set pagination off
set confirm off
if g_overlayChainVerified!=1 || g_overlaySourceOpen!=1 || g_overlaySourceReads!=2 || g_overlaySourceBytes!=46 || g_overlayRuntimeReads!=0 || g_overlayRuntimeBytes!=0 || g_resourceSourceOpen != 1 || g_resourceRuntimeReads != 0 || g_resourceRuntimeBytes != 0 || g_resourceSourceReads != 228 || g_resourceSourceBytes != 201058 || g_resourceCount != 212 || g_loadedCodeMask != 3 || g_lowMemoryValidatedSites != 58
 echo FAIL resource-read: preparation, CODE validation or residency\n
 detach
 quit 1
end
if s_resourceForks.m_directory == 0 || s_resourceForks.m_directory->forks_[0].active != 1 || s_resourceForks.m_directory->forks_[0].writable != 0 || s_resourceForks.m_directory->forks_[0].dirty != 0 || s_resourceForks.m_directory->forks_[0].map == 0
 echo FAIL resource-read: mutable directory ownership/state\n
 detach
 quit 1
end
set $ri=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].identity == 0 || s_resourceForks.m_items[$ri].identity != s_resourceForks.m_directory->records_[$ri].identity || s_resourceForks.m_items[$ri].item.size != s_resourceForks.m_directory->records_[$ri].entry.size
  echo FAIL resource-read: directory/cache identity or size mismatch\n
  detach
  quit 1
 end
 if s_resourceForks.m_items[$ri].item.data != 0
  echo FAIL resource-read: retained resource payload pointer\n
  detach
  quit 1
 end
 set $ri=$ri+1
end
# Reach the original directory return before the General lookup.
tbreak *(g_startupCode+0xaa)
continue
tbreak *(g_code3Base+0x4358)
continue
if *(unsigned long*)(s_segments[7].begin+0x3cdc) != 0xa820245f
 echo FAIL resource-read: original Get1NamedResource bytes\n
 detach
 quit 1
end
tbreak *(s_segments[7].begin+0x3cde)
continue
if *(unsigned long*)$sp == 0 || *(short*)(g_macLowMemory+140) != 0 || $d0 != 0
 echo FAIL resource-read: original General lookup result\n
 detach
 quit 1
end
set $general=*(unsigned long*)*(unsigned long*)$sp
if $general == 0
 echo FAIL resource-read: General data missing\n
 detach
 quit 1
end
dump binary memory ../tmp/resource-general.bin $general $general+612
break AitdScreen::showLoudStop
continue
if g_trapWord != 0xa900 || g_trapSegment != 12 || g_trapOffset != 0x12 || g_resourceRuntimeReads != 16 || g_resourceRuntimeBytes != 96648 || g_systemWindows != 16 || g_resourceSourceMax > 65536 || g_macServiceEntered != 23 || g_macServiceCompleted != 23 || g_macServiceActive != 0
 echo FAIL resource-read: runtime stop, service balance or bounded reads\n
 detach
 quit 1
end
set $ri=0
set $samples=1
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
if $samples != 3
 echo FAIL resource-read: missing samples\n
 detach
 quit 1
end
printf "PASS resource-read: maps=212 preparation=201058 runtime=16/96648 windows=16 samples=3 next=GETFNUM\n"
detach
quit 0
