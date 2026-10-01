-- Measure the original Dark EmptyRgn call, then six isolated CPU fixtures.
-- Fixture storage comes from a real NewHandle(64); the game is not resumed.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'EMPTYRGN / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('EMPTYRGN / NO JUMP ENTRY')
end
local function save(name,a,n)local f=assert(io.open('tmp/emptyrgn-variants-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='enter';local stack;local call;local region;local scratch;local fixtureStack;local index=0;local cases={"000A0000000000000000","000AFFFDFFFE00040007","000A0004FFFE00040007","000A0005FFFE00040007","000AFFFD000800040007","00240001000200040008000100020004000600087FFF000400020004000600087FFF7FFF"};
local function capture(label,sp)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 local body=ptr(region);local size=mem:read_u16(body);assert(size>=10 and size<4096,'EMPTYRGN / REGION SIZE')
 print(string.format('EMPTYRGN_%s sp=%X call=%X handle=%X body=%X size=%X result=%X zone=%X memerr=%X',label,sp,call,region,body,size,mem:read_u16(stack+4),ptr(0x118),mem:read_u16(0x220))..tail)
 save(label:lower()..'-region',body,size)
end
local function fixtureCapture(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('EMPTY_VARIANT_%s n=%d sp=%X handle=%X body=%X call=%X result=%X memerr=%X',label,index,cpu.state.A7.value,region,ptr(region),scratch+2,mem:read_u16(fixtureStack+4),mem:read_u16(0x220))..tail)
 save('case'..index..'-'..label:lower(),ptr(region),64)
end
local function nextcase()
 index=index+1
 if index>#cases then done=true;print('PASS original EmptyRgn variants cases=6');dbg:command('quit');return end
 local body=ptr(region);for i=0,63 do mem:write_u8(body+i,0xa5)end
 for i=1,#cases[index],2 do mem:write_u8(body+(i-1)/2,tonumber(cases[index]:sub(i,i+1),16))end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa8e2);mem:write_u16(scratch+4,0x4e71)
 mem:write_u32(fixtureStack,region);mem:write_u16(fixtureStack+4,0xa57e)
 cpu.state.A7.value=fixtureStack;cpu.state.PC.value=scratch;cpu.state.D0.value=0x13579bdf;cpu.state.D1.value=0x89abcdef
 fixtureCapture('ENTER');dbg:command('bpclear');cpu.debug:bpset(scratch+4,'1','');phase='fixture';dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'EMPTYRGN / DISPATCHER BYTES')
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8e2 && (d@(sp+2)&0xffffff)=='..base(4)..'+0x4182','')
 armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='enter' then
   stack=cpu.state.A7.value+8;call=ptr(cpu.state.A7.value+2);region=ptr(stack)
   local raw=bytes(call-8,14);print('EMPTYRGN_BYTES '..raw);save('caller',call-8,14)
   capture('ENTER',stack);dbg:command('bpclear');cpu.debug:bpset(call+2,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==call+2 and cpu.state.A7.value==stack+4,'EMPTYRGN / RETURN STACK')
   capture('RETURN',cpu.state.A7.value)
   scratch=(stack-16384)&0xfffffc;fixtureStack=scratch+8192
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa122);mem:write_u16(scratch+4,0x4e71)
   cpu.state.A7.value=fixtureStack;cpu.state.PC.value=scratch;cpu.state.D0.value=64
   dbg:command('bpclear');cpu.debug:bpset(scratch+4,'1','');phase='allocate';dbg.execution_state='run'
  elseif phase=='allocate' then
   region=cpu.state.A0.value&0xffffff;assert(region~=0 and ptr(region)~=0 and mem:read_u16(0x220)==0,'fixture allocation');nextcase()
  else
   assert(cpu.state.A7.value==fixtureStack+4,'fixture stack');fixtureCapture('RETURN');nextcase()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('EMPTYRGN / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
