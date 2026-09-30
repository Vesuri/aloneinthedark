-- Original effect-status polling through natural completion, then isolated
-- driver fixtures for explicit stop and first-matching-identifier semantics.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER20 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/driver20-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER20 / NO JUMP ENTRY')
end
local regs={'D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='arm';local entry;local call;local packet;local sp;local saved={};local count=0;local active=0;local scratch;local stack;local fixture=0
local function before()
 sp=cpu.state.A7.value;packet=ptr(sp+4)
 for _,r in ipairs(regs)do saved[r]=cpu.state[r].value end
end
local function returned()
 assert(cpu.state.A7.value==sp,'DRIVER20 / STACK')
 assert(cpu.state.D1.value==mem:read_u32(sp+4),'DRIVER20 / SCRATCH')
 for _,r in ipairs(regs)do assert(cpu.state[r].value==saved[r],'DRIVER20 / PRESERVED '..r)end
 return cpu.state.D0.value
end
local cases={{'active',0x7ffe,0xffff,0x8000,0}, {'stopped',0xffff,0xffff,0x8000,1}, {'missing',0x7ffe,0xffff,0x1234,1}, {'first-inactive',0xffff,0x7ffe,0x8000,1}}
local function fixtureStart()
 fixture=fixture+1;local c=cases[fixture]
 if not c then done=true;print(string.format('PASS original driver20 status active=%u total=%u fixtures=%u',active,count,#cases));dbg:command('quit');return end
 local voice=entry+0x4200+0x22d2+6*4
 mem:write_u16(voice+0x200,c[2]);mem:write_u16(voice+4+0x200,c[3]);mem:write_u16(voice+0x440,0x8000);mem:write_u16(voice+4+0x440,0x8000)
 mem:write_u16(scratch+256+24,c[4]);mem:write_u32(stack,20);mem:write_u32(stack+4,scratch+256)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch;before()
 save(c[1]..'-enter',entry+0x4200,0x3048)
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
   call=base(3)+0x17c8;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);before();count=count+1
   if count==1 then print('DRIVER20_BYTES '..bytes(call-12,16));save('driver',entry,0x7248);save('packet',packet,26);save('first-enter',entry+0x4200,0x3048)end
   dbg:command('bpclear');cpu.debug:bpset(call+2,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   local result=returned();assert(result==0 or result==1,'DRIVER20 / BOOLEAN')
   if count==1 then assert(result==0,'DRIVER20 / INITIAL ACTIVE');save('first-return',entry+0x4200,0x3048)end
   if result==0 then active=active+1;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
   else
    assert(active>0);print(string.format('DRIVER20_NATURAL calls=%u active=%u result=%u packet=%X id=%X',count,active,result,packet,mem:read_u16(packet+24)));save('complete',entry+0x4200,0x3048)
    scratch=(sp-16384)&0xfffffc;stack=scratch+8192;cpu.state.SR.value=cpu.state.SR.value|0x700
    mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0x4eb9);mem:write_u32(scratch+4,entry);mem:write_u16(scratch+8,0x4e71)
    for i=0,25 do mem:write_u8(scratch+256+i,mem:read_u8(packet+i))end
    fixtureStart()
   end
  else
   local c=cases[fixture];local result=returned();assert(result==c[5],'DRIVER20 / FIXTURE RESULT')
   print(string.format('DRIVER20_FIXTURE name=%s result=%u sp=%X argument=%X',c[1],result,sp,mem:read_u32(sp+4)));save(c[1]..'-return',entry+0x4200,0x3048);fixtureStart()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('DRIVER20 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
