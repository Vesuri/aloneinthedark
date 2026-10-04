-- Original death-fade call plus isolated gain-table fixtures.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER19 / NO SEGMENT')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/m3-toolbox/driver19-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local armed=false;local done=false;local phase='arm';local entry;local call;local ret;local sp;local scratch;local stack;local gain
local fixture=0
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function capture(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER19_%s sp=%X gain=%X',label,cpu.state.A7.value,gain)..tail..string.format(' sr=%X',cpu.state.SR.value))
 local state=entry+0x4200;local count=mem:read_u16(state+0x2270)
 assert(count==8,'DRIVER19 / MIXER CONFIG')
 save(label:lower()..'-state',state,0x3048)
 save(label:lower()..'-table',ptr(state+0x226c),256*count+4)
end
local function nextFixture()
 fixture=fixture+1
 if fixture>33 then done=true;print('PASS original driver19 death fade and 33 gain fixtures');dbg:command('quit');return end
 gain=256-(fixture-1)*8
 mem:write_u32(stack,19);mem:write_u32(stack+4,gain)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch
 capture('FIXTURE_'..fixture..'_ENTER')
 dbg:command('bpclear');cpu.debug:bpset(scratch+8,'1','');phase='fixture';dbg.execution_state='run'
end
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
   call=base(3)+0x1f0a;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);sp=cpu.state.A7.value;ret=call+2;gain=mem:read_u32(sp+4)
   print('DRIVER19_BYTES '..bytes(call-10,14));save('driver',entry,0x7248)
   assert(mem:read_u32(sp)==19 and gain==248)
   capture('ENTER');dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==sp);capture('RETURN')
   scratch=(sp-16384)&0xfffffc;stack=scratch+8192
   cpu.state.SR.value=cpu.state.SR.value|0x710 -- mask interrupts; seed X for the first fixture
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0x4eb9);mem:write_u32(scratch+4,entry);mem:write_u16(scratch+8,0x4e71)
   nextFixture()
  else
   assert(cpu.state.PC.value==scratch+8 and cpu.state.A7.value==stack)
   capture('FIXTURE_'..fixture..'_RETURN');nextFixture()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
local function key(name) mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name);mac.wait(10) end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  local function window320()
   local w=mem:read_u32(0x9d6)&0xffffff
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=mem:read_u32(w+0x90)&0xffffff
   end
   return false
  end
  if not window320() then assert(mac.mouse_to(256,274));mac.click(1) end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
  key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180)
  key('Esc');mac.wait(18000);error('GAMEPLAY SONG / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
