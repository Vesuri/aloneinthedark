-- Observe a naturally requested gameplay song through ordinary ADB input only.
-- Opening the action menu pauses gameplay while original music keeps playing.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SONG LIVE / DEBUGGER REQUIRED')
local song=tonumber(os.getenv('AITD_LIVE_SONG') or '137')
local totals={[131]=1338,[132]=1206,[135]=3736,[136]=602,[137]=2250}
local total=assert(totals[song],'SONG LIVE / NATURAL ROUTE ID')
local folder=assert(os.getenv('AITD_LIVE_FOLDER'))
local songLoaded=false
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('SONG LIVE / NO SEGMENT')
end
local function bytes(a,n)a=a&0xffffff;local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open(folder..'/song-live-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local armed=false;local done=false;local phase='arm';local entry;local state;local midi;local count=0;local rootret;local noteReturn;local noteSP;local callbackSeen=false;local reportTick=0
local function arm_notes()
 dbg:command('bpclear')
 for _,offset in ipairs({0x312e,0x30dc})do
  cpu.debug:bpset(entry+offset,'1','');cpu.debug:bpset((entry+offset)&0xffffff,'1','')
 end
 if not callbackSeen then
  cpu.debug:bpset(entry+0x6de,'1','');cpu.debug:bpset((entry+0x6de)&0xffffff,'1','')
 end
 cpu.debug:bpset(rootret-2,'1','')
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed then return end
 if state and phase=='events' then
  local tick=mem:read_u32(0x16a)
  if tick-reportTick>=600 then
   reportTick=tick
   print(string.format('SONG_LIVE_CLOCK tick=%X pulse=%X track=%X cursor=%X pc=%X events=%d',tick,mem:read_u32(state+0x118c),mem:read_u32(state+0x1a28),ptr(state+0x1c68),cpu.state.PC.value,count))
  end
 end
 if dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='arm' then
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x138c,string.format('d@(sp+4)==0x%x',song),'');phase='call'
  elseif phase=='call' then
   assert(bytes(cpu.state.PC.value-10,14)=='2F2E000842A7206DF9544E90508F')
   entry=mem:read_u32(cpu.state.A5.value-0x6ac);state=(entry&0xffffff)+0x4200
   assert(bytes(entry+0x3b6e,4)=='4BEC0072' and bytes(entry+0x312e,4)=='4A6C2C30' and bytes(entry+0x30dc,6)=='082C000011BA')
   rootret=cpu.state.PC.value+2;dbg:command('bpclear');cpu.debug:bpset(rootret,'1','');phase='begin'
  elseif phase=='begin' then
   assert(cpu.state.PC.value==rootret and cpu.state.D0.value==0);midi=ptr(state+0x6e)
   save('initial-state',state,0x3048);songLoaded=true
   print(string.format('SONG_LIVE_BEGIN song=%d midi=%d body=%X tick=%X pulse=%X',song,song+770,midi,mem:read_u32(0x16a),mem:read_u32(state+0x118c)))
   arm_notes();phase='events'
  elseif ((cpu.state.PC.value-entry)&0xffffff)==0x6de then
   callbackSeen=true;print(string.format('SONG_LIVE_CALLBACK pc=%X entry=%X',cpu.state.PC.value,entry));arm_notes()
  elseif phase=='return' then
   assert(cpu.state.PC.value==noteReturn and cpu.state.A7.value==noteSP+4)
   for voice=0,5 do
    local v=state+0x22d2+voice*4
    print(string.format('SONG_VOICE n=%d slot=%d sample=%X step=%X active=%X start=%X finish=%X loop=%X/%X envelope=%X instrument=%X note=%X channel=%X volume=%X',count,voice,ptr(v),mem:read_u32(v+0x40),mem:read_u16(v+0x200),ptr(v+0x280),ptr(v+0x300),ptr(v+0x2c0),ptr(v+0x300),ptr(v+0x340),mem:read_u16(v+0x4c0),mem:read_u16(v+0x480),mem:read_u16(v+0x440),mem:read_u16(v+0x5c0)))
   end
   if count==total then
    save('final-state',state,0x3048);done=true;print('PASS original song live events='..total);dbg:command('quit');return
   end
   phase='events';arm_notes()
  else
   assert(cpu.state.PC.value~=rootret-2,'SONG LIVE / SONG REPLACED id='..mem:read_u32(cpu.state.A7.value+4))
   assert(mem:read_u16(state+0x2c30)==0,'SONG LIVE / PREFLIGHT')
   local on=((cpu.state.PC.value-entry)&0xffffff)==0x312e
   assert(on or ((cpu.state.PC.value-entry)&0xffffff)==0x30dc)
   local position=(cpu.state.A1.value&0xffffff)-midi
   assert(position>=22 and position<65536,'SONG LIVE / DIFFERENT MIDI')
   count=count+1;assert(count<=total,'SONG LIVE / EVENT LIMIT')
   print(string.format('SONG_LIVE_EVENT n=%d on=%d offset=%X instrument=%X note=%X velocity=%X channel=%X tick=%X pulse=%X step=%X countdown=%X',count,on and 1 or 0,position,cpu.state.D0.value&0xffff,cpu.state.D1.value&0xffff,cpu.state.D3.value&0xffff,cpu.state.D5.value&0xffff,mem:read_u32(0x16a),mem:read_u32(state+0x118c),mem:read_u32(state+0x195a),mem:read_u32(state+0x1cc8)))
   noteSP=cpu.state.A7.value;noteReturn=mem:read_u32(noteSP)
   dbg:command('bpclear');cpu.debug:bpset(noteReturn,'1','');phase='return'
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  local function window320()
   local w=ptr(0x9d6)
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=ptr(w+0x90)
   end
   return false
  end
  if not window320() then assert(mac.mouse_to(256,274));mac.click(1)end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  local function key(name)mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name);mac.wait(10)end
  if song~=135 then
   mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
   key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180);key('Esc')
   if song==132 then
    mac.wait(6000);mac.key_down('f');mac.wait(60);mac.key_up('f')
    mac.key_down('Space');mac.key_down('Up Arrow');mac.wait(120);mac.key_up('Up Arrow');mac.key_up('Space')
   end
   assert(mac.wait_for('natural song request',function()return songLoaded end,12000))
   if song==137 or song==136 or song==132 then
    assert(mac.wait_for('attic framebuffer',function()
     local raw,w,h=screen:pixels()
     return w==640 and h==480 and (string.unpack('I4',raw,4*(160*w+180)+1)&0xffffff)==0x814530
    end,1800))
    print('SONG_LIVE_INPUT Return attic menu tick='..mem:read_u32(0x16a))
    mac.key_down('Return');mac.wait(30);mac.key_up('Return')
   end
  end
  mac.wait(36000);error('SONG LIVE / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
