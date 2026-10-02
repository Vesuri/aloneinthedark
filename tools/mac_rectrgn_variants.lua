-- Measure the original Dark RectRgn call and CPU-executed heap queries.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RECTRGN / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('RECTRGN / NO JUMP ENTRY')
end
local function save(name,a,n)local f=assert(io.open('tmp/rectrgn-variants-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='enter';local stack;local call;local region;local rect;local scratch;local fixtureStack;local index=0
local cases={{10,0,"FFFDFFFE00040007"},{64,0,"FFFDFFFE00040007"},{64,0,"0004FFFE00040007"},{64,0,"0005FFFE00040007"},{64,0,"FFFD000800040007"},{64,0x80,"FFFDFFFE00040007"},{64,0x40,"FFFDFFFE00040007"}}
local function capture(label,sp)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 local body=ptr(region);local size=mem:read_u16(body);assert(size>=10 and size<4096,'RECTRGN / REGION SIZE')
 print(string.format('RECTRGN_%s sp=%X handle=%X body=%X size=%X rect=%X zone=%X memerr=%X',label,sp,region,body,size,rect,ptr(0x118),mem:read_u16(0x220))..tail)
 save(label:lower()..'-region',body,size);save(label:lower()..'-rect',rect,8)
end
local function jump(op,phaseName)
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,op);mem:write_u16(scratch+4,0x4e71)
 cpu.state.PC.value=scratch;dbg:command('bpclear');cpu.debug:bpset(scratch+4,'1','');phase=phaseName;dbg.execution_state='run'
end
local function nextcase()
 index=index+1
 if index>#cases then done=true;print('PASS original RectRgn variants cases=7');dbg:command('quit');return end
 cpu.state.A7.value=fixtureStack;cpu.state.D0.value=cases[index][1];jump(0xa122,'allocate')
end
local function variant(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('RECT_VARIANT_%s n=%d sp=%X handle=%X body=%X rect=%X memerr=%X',label,index,cpu.state.A7.value,region,ptr(region),rect,mem:read_u16(0x220))..tail)
 save('case'..index..'-'..label:lower()..'-region',ptr(region),label=='ENTER' and cases[index][1] or 10)
 save('case'..index..'-'..label:lower()..'-rect',rect-4,16)
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'RECTRGN / DISPATCHER BYTES')
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8df && (d@(sp+2)&0xffffff)=='..base(4)..'+0x3d46','')
 armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='enter' then
   stack=cpu.state.A7.value+8;call=ptr(cpu.state.A7.value+2);rect=ptr(stack);region=ptr(stack+4)
   local raw=bytes(call-16,18);print('RECTRGN_BYTES '..raw);save('caller',call-16,18)
   capture('ENTER',stack);dbg:command('bpclear');cpu.debug:bpset(call+2,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==call+2 and cpu.state.A7.value==stack+8,'RECTRGN / RETURN STACK')
   capture('RETURN',cpu.state.A7.value);scratch=(stack-16384)&0xfffffc;fixtureStack=scratch+8192;rect=scratch+256;nextcase()
  elseif phase=='allocate' then
   region=cpu.state.A0.value&0xffffff;assert(region~=0 and ptr(region)~=0 and mem:read_u16(0x220)==0,'fixture allocation')
   local body=ptr(region);for i=0,cases[index][1]-1 do mem:write_u8(body+i,0xa5)end
   local shape=cases[index][1]==10 and '000A0000000000000000' or '00240001000200040008000100020004000600087FFF000400020004000600087FFF7FFF'
   for i=1,#shape,2 do mem:write_u8(body+(i-1)/2,tonumber(shape:sub(i,i+1),16))end
   for i=-4,11 do mem:write_u8(rect+i,0xa5)end
   for i=1,16,2 do mem:write_u8(rect+(i-1)/2,tonumber(cases[index][3]:sub(i,i+1),16))end
   cpu.state.A0.value=region;cpu.state.D0.value=cases[index][2];jump(0xa06a,'state')
  elseif phase=='state' then
   assert(mem:read_u16(0x220)==0,'fixture state')
   mem:write_u32(fixtureStack,rect);mem:write_u32(fixtureStack+4,region)
   cpu.state.A7.value=fixtureStack;cpu.state.D0.value=0x13579bdf;cpu.state.D1.value=0x89abcdef
   variant('ENTER');jump(0xa8df,'fixture')
  elseif phase=='fixture' then
   assert(cpu.state.A7.value==fixtureStack+8,'fixture return stack');variant('RETURN')
   cpu.state.A0.value=region;jump(0xa025,'size')
  elseif phase=='size' then
   print(string.format('RECT_VARIANT_SIZE n=%d size=%X memerr=%X',index,cpu.state.D0.value,mem:read_u16(0x220)))
   cpu.state.A0.value=region;jump(0xa069,'flags')
  elseif phase=='flags' then
   print(string.format('RECT_VARIANT_FLAGS n=%d flags=%X memerr=%X',index,cpu.state.D0.value&255,mem:read_u16(0x220)))
   cpu.state.A0.value=region;jump(0xa126,'owner')
  elseif phase=='owner' then
   print(string.format('RECT_VARIANT_OWNER n=%d owner=%X zone=%X memerr=%X',index,cpu.state.A0.value,ptr(0x118),mem:read_u16(0x220)))
   cpu.state.A0.value=region;jump(0xa023,'dispose')
  else
   assert(mem:read_u16(0x220)==0,'fixture disposal');nextcase()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('RECTRGN / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
