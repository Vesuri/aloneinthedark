-- Original selector-15 clock query plus isolated full-width return fixture.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER15 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER15 / NO JUMP ENTRY')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/driver15-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='arm';local entry;local call;local ret;local originalSP;local scratch;local stack
local function capture(label)
 print(string.format('DRIVER15_CLOCK label=%s tick=%X value=%X',label,mem:read_u32(0x16a),mem:read_u32(entry+0x4200+0x1880)))
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER15_%s sp=%X selector=%X argument=%X entry=%X',label,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u32(cpu.state.A7.value+4),entry)..tail)
 save(label:lower()..'-state',entry+0x4200,0x3048)
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
   call=base(3)+0xfc8;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);ret=call+2;originalSP=cpu.state.A7.value
   assert(bytes(call-10,14)=='42A74878000F206DF9544E90508F','DRIVER15 / CALLER BYTES');print('DRIVER15_BYTES '..bytes(call-10,14));print('DRIVER15_ENTRY_BYTES '..bytes(entry,12));save('driver',entry,0x7248)
   capture('ENTER');dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==originalSP);capture('RETURN');dbg:command('bpclear')
   scratch=(originalSP-16384)&0xfffffc;stack=scratch+8192
   -- Run only the driver with interrupts masked; no invented sample pointers.
   cpu.state.SR.value=cpu.state.SR.value|0x700
   -- Seed only the isolated original-driver state; prove the full 32-bit query.
   mem:write_u32(entry+0x4200+0x1880,0x89abcdef)
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0x4eb9);mem:write_u32(scratch+4,entry);mem:write_u16(scratch+8,0x4e71)
   mem:write_u32(stack,15);mem:write_u32(stack+4,0x12345678);cpu.state.A7.value=stack;cpu.state.PC.value=scratch
   capture('FIXTURE_ENTER');cpu.debug:bpset(scratch+8,'1','');phase='fixture';dbg.execution_state='run'
  else
   assert(cpu.state.A7.value==stack);capture('FIXTURE_RETURN');done=true;print('PASS original driver15 selector-15 clock and isolated full-width fixture');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('DRIVER15 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
