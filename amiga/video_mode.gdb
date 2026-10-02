# FS-UAE's debugger exposes serialized custom-register values, including
# write-only registers. DIWHIGH's C080 state bits are excluded as in menu_mode.
define check_video_mode
 set $video_pointer_control=(s_loudStopScreen && s_loudStopScreen->m_mouseAllowed) ? 0x010f : 0x0011
 set $video_start=g_videoPAL ? 72 : 44
 set $video_stop=$video_start+200
 if g_videoPAL>1 || g_paulaClock!=(g_videoPAL ? 3546895 : 3579545)
  echo FAIL selected video identity/clock\n
  detach
  quit 1
 end
 if *(unsigned short*)0xdff08e!=(($video_start<<8)|0x81) || *(unsigned short*)0xdff090!=((($video_stop&255)<<8)|0xc1) || (*(unsigned short*)0xdff1e4&0x3f7f)!=(0x2000|($video_stop&0x100))
  echo FAIL centred video geometry\n
  detach
  quit 1
 end
 if *(unsigned short*)0xdff100!=0x0211 || *(unsigned short*)0xdff102!=0 || *(unsigned short*)0xdff104!=0x0024 || (*(unsigned short*)0xdff106&0x1dff)!=0x0c60 || *(unsigned short*)0xdff10c!=$video_pointer_control || *(unsigned short*)0xdff092!=0x38 || *(unsigned short*)0xdff094!=0xd0 || *(unsigned short*)0xdff108!=0x118 || *(unsigned short*)0xdff10a!=0x118 || *(unsigned short*)0xdff1fc!=0
  echo FAIL eight-plane video mode\n
  detach
  quit 1
 end
 printf "VIDEO_MODE pal=%u clock=%u diwstrt=%04X diwstop=%04X diwhigh=%04X fields=%u ticks=%u\n",g_videoPAL,g_paulaClock,*(unsigned short*)0xdff08e,*(unsigned short*)0xdff090,(*(unsigned short*)0xdff1e4&0x3f7f),g_vbiCount,g_macTicks
end
check_video_mode
set $video_fields_start=g_vbiCount
set $video_ticks_start=g_macTicks
