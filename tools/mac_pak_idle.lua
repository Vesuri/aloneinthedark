-- Natural idle route: no game code, timer or input state is patched.
-- Used as AITD_MAC_SCENARIO with mac_traps.lua for paired File Manager records.
return function(mac,mem)
 local cpu=manager.machine.devices[':maincpu'];local dbg=manager.machine.debugger
 local meta=dofile('tmp/mac-trap-map.lua');local armed={}
 dbg:command('temp3=0;temp6=0;temp7=0')
 local function guard(base,offset,raw)
  for i=1,#raw,2 do assert(mem:read_u8(base+offset+(i-1)/2)==tonumber(raw:sub(i,i+1),16),'PAK IDLE / ORIGINAL BYTE MISMATCH') end
 end
 emu.register_frame_done(function()
  if mac.frontmost()~='Alone In The Dark' then return end
  local a5=mem:read_u32(0x904)&0xffffff
  if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
  if os.getenv('AITD_PAK_IDLE_DIAG')=='1' and mem:read_u32(0x16a)>0x3000 then
   for _,screen in pairs(manager.machine.screens) do assert(not screen:snapshot('m2-pak-idle-wait.png')) end
   dbg:command('logerror "PAK_IDLE diagnostic pc=%X sp=%X a6=%X\\n",pc,sp,a6')
   local frame=cpu.state['A6'].value&0xffffff
   for i=1,20 do
    if frame<0x100000 or frame>0x7ffff7 then break end
    print(string.format('PAK_IDLE stack frame=%X previous=%X return=%X',frame,mem:read_u32(frame),mem:read_u32(frame+4)))
    frame=mem:read_u32(frame)&0xffffff
   end
   print('DIAGNOSTIC captured idle wait; no route acceptance');manager.machine:exit();return
  end
  if mac.frames()%600==0 then dbg:command('logerror "PAK_IDLE heartbeat ticks=%X pc=%X key=%X buttons=%X\\n",d@16a,pc,w@((d@904&ffffff)-11af4),w@((d@904&ffffff)-11af0)') end
  for index,j in ipairs(meta.jt) do
   if (j[1]==12 or j[1]==13 or j[1]==4) and not armed[j[1]] then
    local entry=a5+32+(index-1)*8
    if mem:read_u16(entry)==j[1] and mem:read_u16(entry+2)==0x4ef9 then
     local base=(mem:read_u32(entry+4)&0xffffff)-j[2]
     if j[1]==12 then
      guard(base,0x137e,'0c80000003846460');guard(base,0x13f8,'30064cee00e0ffee4e5e4e75')
      cpu.debug:bpset(base+0x13fa,'(d0&ffff)==ffff','logerror "PAK_IDLE timeout Dan1+13FA ticks=%X\\n",d@16a;temp7=1;g')
     elseif j[1]==4 then
      guard(base,0x52ac,'4eb9');assert((mem:read_u32(base+0x52ae)&0xffffff)==a5+0x34a,'PAK IDLE / CALL TARGET')
      cpu.debug:bpset(base+0x52ac,'1','logerror "PAK_IDLE caller Dark+52AC timeout=%X\\n",temp7;g')
      guard(base,0x5296,'4a404fef000a');guard(base,0x52a6,'4a40660000f8')
      local opcodes={[0x522a]='1c00',[0x524a]='4eb9',[0x5250]='0240',[0x5266]='2f3c',[0x5278]='4eba',[0x54e4]='4eb9',[0x54ea]='2f0c',[0x54f2]='3eae',[0x5504]='3eae',[0x550e]='4279',[0x5522]='3eae',[0x552c]='4e71',[0x5290]='4eb9',[0x5296]='4a40',[0x52a0]='4eb9',[0x52a6]='4a40'}
      for _,probe in ipairs({{0x522a,'menu-return'},{0x524a,'idle-enter'},{0x5250,'random-return'},{0x5266,'pause-return'},{0x5278,'demo-return'},{0x54e4,'demo-setup'},{0x54ea,'demo-reset'},{0x54f2,'demo-reset-return'},{0x5504,'demo-room-loaded'},{0x550e,'demo-actor-loaded'},{0x5522,'demo-scene-loaded'},{0x552c,'demo-loop-return'},{0x5290,'first-intro-enter'},{0x5296,'first-intro-return'},{0x52a0,'second-intro-enter'},{0x52a6,'second-intro-return'}}) do
       guard(base,probe[1],opcodes[probe[1]])
       cpu.debug:bpset(base+probe[1],'1','logerror "PAK_IDLE stage='..probe[2]..' ticks=%X d0=%X\\n",d@16a,d0;g')
      end
     else
      guard(base,0x2d16,'4e56fcec48e703087e00600000d8')
      guard(base,0x2d28,'3f3c000d2f3c');guard(base,0x2d3e,'70ffd0473f002f3c')
      guard(base,0x2dfa,'0c47000f6d00ff247000')
      local text=mem:read_u32(base+0x2d46)&0xffffff
      for i=1,12 do assert(mem:read_u8(text+i-1)==('present.pak\0'):byte(i),'PAK IDLE / PRESENT NAME') end
      cpu.debug:bpset(base+0x2d16,'1','temp6=0;logerror "PAK_IDLE presentation Dan2+2D16\\n";g')
      cpu.debug:bpset(base+0x2d54,'a4!=0','temp6=temp6+1;logerror "PAK_IDLE image index=%X body=%X\\n",d7,a4;g')
      cpu.debug:bpset(base+0x2d54,'a4==0','logerror "FAIL PAK idle missing image index=%X\\n",d7;quit')
      cpu.debug:bpset(base+0x2e04,'d0==0 && temp6==f && temp7==1','logerror "PASS file-reference captured; natural idle presentation images=15\\n";quit')
      cpu.debug:bpset(base+0x2e04,'d0!=0 || temp6!=f || temp7!=1','logerror "FAIL PAK idle incomplete return=%X images=%X timeout=%X\\n",d0,temp6,temp7;quit')
     end
     armed[j[1]]=true;print(string.format('ARM PAK_IDLE CODE=%d original bytes verified',j[1]))
    end
   end
  end
 end)
 local function window320()
  local w=mem:read_u32(0x9d6)&0xffffff
  for _=1,32 do
   if w==0 or w>0x7fffff then return false end
   if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
   w=mem:read_u32(w+0x90)&0xffffff
  end
  return false
 end
 mac.wait(300)
 if not window320() then assert(mac.mouse_to(256,274),'PAK IDLE / SIZE POINTER');mac.click(1) end
 assert(mac.wait_for('320x200 window',window320,1800),'PAK IDLE / NO GAME WINDOW')
 assert(mac.mouse_to(620,470),'PAK IDLE / POINTER')
 print('PAK_IDLE no further input; wait for original menu timeout and presentation')
 mac.wait(36000);error('PAK IDLE / NO POSITIVE PRESENTATION COMPLETION')
end
