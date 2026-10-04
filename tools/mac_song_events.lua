-- Observe original MIDI preflight, before the driver allocates its instruments.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SONG EVENTS / DEBUGGER REQUIRED')
local song=tonumber(os.getenv('AITD_SONG_EVENTS') or '135')
assert(song==132 or song==135 or song==136,'SONG EVENTS / UNMEASURED SONG')
local prefix=song==135 and 'tmp/song-events-' or song==132 and 'tmp/m3-fight/song132-events-' or 'tmp/m3-toolbox/song136-events-'
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function driver_break(a)
 cpu.debug:bpset(a&0xffffff,'1','')
 cpu.debug:bpset((a&0xffffff)|0x80000000,'1','')
end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('SONG EVENTS / NO SEGMENT')
end
local function bytes(a,n)a=a&0xffffff;local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open(prefix..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local armed=false;local done=false;local phase='arm';local entry;local state;local midi;local count=0
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='arm' then
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x138c,string.format('d@(sp+4)==0x%x',song),'');phase='call'
  elseif phase=='call' then
   assert(bytes(cpu.state.PC.value-10,14)=='2F2E000842A7206DF9544E90508F')
   entry=mem:read_u32(cpu.state.A5.value-0x6ac);state=(entry&0xffffff)+0x4200
   assert(bytes(entry+0x3b6e,4)=='4BEC0072' and bytes(entry+0x312e,4)=='4A6C2C30' and bytes(entry+0x30dc,6)=='082C000011BA')
   dbg:command('bpclear');driver_break(entry+0x3b6e);phase='begin'
  elseif phase=='begin' then
   assert((cpu.state.PC.value&0xffffff)==((entry+0x3b6e)&0xffffff));midi=ptr(state+0x6e)
   local body=ptr(state+0x6a);local midiBytes=22+mem:read_u32(midi+18)
   assert(bytes(midi,4)=='4D546864' and midiBytes<65536)
   save('song',body,18+4*mem:read_u16(body+16));save('midi',midi,midiBytes)
   print(string.format('SONG_EVENTS_BEGIN song=%d midi=%d body=%X',song,mem:read_u16(body),midi))
   dbg:command('bpclear');driver_break(entry+0x312e);driver_break(entry+0x30dc);driver_break(entry+0x3b9e);phase='events'
  elseif (cpu.state.PC.value&0xffffff)==((entry+0x3b9e)&0xffffff) then
   assert(count>0);save('state',state,0x3048);done=true
   print(string.format('PASS original song preflight events=%d',count));dbg:command('quit');return
  else
   assert(mem:read_u16(state+0x2c30)~=0,'SONG EVENTS / NOT PREFLIGHT')
   local on=(cpu.state.PC.value&0xffffff)==((entry+0x312e)&0xffffff)
   assert(on or (cpu.state.PC.value&0xffffff)==((entry+0x30dc)&0xffffff))
   count=count+1;assert(count<10000,'SONG EVENTS / EVENT LIMIT')
   print(string.format('SONG_EVENT n=%d on=%d offset=%X instrument=%X note=%X velocity=%X channel=%X',count,on and 1 or 0,(cpu.state.A1.value&0xffffff)-midi,cpu.state.D0.value&0xffff,cpu.state.D1.value&0xffff,cpu.state.D3.value&0xffff,cpu.state.D5.value&0xffff))
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
  if song==135 or not window320() then assert(mac.mouse_to(256,274));mac.click(1) end
  if song==136 or song==132 then
   assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
   local function key(name)mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name);mac.wait(10)end
   mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
   key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180);key('Esc')
  end
  mac.wait(36000);error('SONG EVENTS / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
