-- Count actual sequencer entries and compare each live note at that boundary.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SONG CLOCK / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('SONG CLOCK / NO SEGMENT')
end
local function bytes(a,n)a=a&0xffffff;local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local armed=false;local done=false;local phase='arm';local entry;local state;local midi;local count=0;local steps=0;local rootret
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
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x138c,'1','');phase='call'
  elseif phase=='call' then
   assert(bytes(cpu.state.PC.value-10,14)=='2F2E000842A7206DF9544E90508F')
   entry=mem:read_u32(cpu.state.A5.value-0x6ac);state=(entry&0xffffff)+0x4200
   assert(bytes(entry+0x3b6e,4)=='4BEC0072' and bytes(entry+0x312e,4)=='4A6C2C30' and bytes(entry+0x30dc,6)=='082C000011BA')
   rootret=cpu.state.PC.value+2;dbg:command('bpclear');cpu.debug:bpset(rootret,'1','');phase='begin'
  elseif phase=='begin' then
   assert(cpu.state.PC.value==rootret and cpu.state.D0.value==0);midi=ptr(state+0x6e)
   print(string.format('SONG_CLOCK_BEGIN tick=%X',mem:read_u32(0x16a)))
   dbg:command('bpclear')
   for _,offset in ipairs({0x186e,0x312e,0x30dc})do
    cpu.debug:bpset(entry+offset,'1','');cpu.debug:bpset((entry+offset)&0xffffff,'1','')
   end
   phase='events'
  elseif ((cpu.state.PC.value-entry)&0xffffff)==0x186e then
   steps=steps+1
   if steps<=20 or steps%500==0 then
    print(string.format('SONG_CLOCK_STEP n=%d tick=%X mix=%X countdown=%X step=%X track=%X',steps,mem:read_u32(0x16a),mem:read_u32(state+0x118c),mem:read_u32(state+0x1cc8),mem:read_u32(state+0x195a),mem:read_u8(state+0x1a28)))
   end
  else
   assert(mem:read_u16(state+0x2c30)==0,'SONG CLOCK / PREFLIGHT')
   local on=((cpu.state.PC.value-entry)&0xffffff)==0x312e
   assert(on or ((cpu.state.PC.value-entry)&0xffffff)==0x30dc)
   local position=(cpu.state.A1.value&0xffffff)-midi
   assert(position>=22 and position<=15320,'SONG CLOCK / MIDI RANGE')
   count=count+1
   print(string.format('SONG_CLOCK_EVENT n=%d on=%d offset=%X instrument=%X note=%X velocity=%X channel=%X sequence=%X tick=%X step=%X countdown=%X',count,on and 1 or 0,position,cpu.state.D0.value&0xffff,cpu.state.D1.value&0xffff,cpu.state.D3.value&0xffff,cpu.state.D5.value&0xffff,steps,mem:read_u32(0x16a),mem:read_u32(state+0x195a),mem:read_u32(state+0x1cc8)))
   if count==3736 then
    done=true;print(string.format('PASS original song clock events=%d steps=%d',count,steps));dbg:command('quit');return
   end
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('SONG CLOCK / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
