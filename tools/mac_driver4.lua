-- Original selector-4 song status and isolated state/condition-code fixtures.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER4 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER4 / NO JUMP ENTRY')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/driver4-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local regs={'SR','D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='arm';local entry;local call;local ret;local originalSP;local scratch;local stack
local function capture(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER4_%s sp=%X selector=%X following=%X entry=%X',label,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u32(cpu.state.A7.value+4),entry)..tail)
 save(label:lower()..'-state',entry+0x4200,0x3048)
end
local cases={{0,0x1234,0,0x0f00},{0xff00,1,-1,0},{1,0,0,0x0f00},{0xff00,0,23,0x0100},{0xff00,0,-1,0},{0xff00,0,7,0x8000},{0xff00,0,0,0x00ff}}
local index=0
function nextcase()
 index=index+1
 if index>#cases then done=true;print('PASS original driver4 status cases=7');dbg:command('quit');return end
 local c=cases[index];local state=entry+0x4200
 cpu.state.SR.value=(cpu.state.SR.value&0xffe0)|0x071f
 mem:write_u16(state+0x36,c[1]);mem:write_u16(state+0x38,c[2])
 for i=0,23 do mem:write_u16(state+0x1a28+i*4,0)end
 if c[3]>=0 then mem:write_u16(state+0x1a28+c[3]*4,c[4])end
 mem:write_u32(stack,4);mem:write_u32(stack+4,0x12345678)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch
 print(string.format('DRIVER4_CASE n=%d enabled=%X control=%X slot=%d track=%X',index,c[1],c[2],c[3],c[4]))
 capture('FIXTURE'..index..'_ENTER');dbg.execution_state='run'
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
   call=base(3)+0x1fc8;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);ret=call+2;originalSP=cpu.state.A7.value
   assert(bytes(call-8,12)=='48780004206DF9544E90588F','DRIVER4 / CALLER BYTES');print('DRIVER4_BYTES '..bytes(call-8,12));print('DRIVER4_ENTRY_BYTES '..bytes(entry,12));save('driver',entry,0x7248)
   capture('ENTER');dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==originalSP);capture('RETURN');dbg:command('bpclear')
   scratch=(originalSP-16384)&0xfffffc;stack=scratch+8192
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0x4eb9);mem:write_u32(scratch+4,entry);mem:write_u16(scratch+8,0x4e71)
   cpu.debug:bpset(scratch+8,'1','');phase='fixture';nextcase()
  else
   assert(cpu.state.A7.value==stack);capture('FIXTURE'..index..'_RETURN');nextcase()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('DRIVER4 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
