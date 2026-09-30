-- Measure the original Dark EmptyRgn call.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'EMPTYRGN / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('EMPTYRGN / NO JUMP ENTRY')
end
local function save(name,a,n)local f=assert(io.open('tmp/emptyrgn-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='enter';local stack;local call;local region;
local function capture(label,sp)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 local body=ptr(region);local size=mem:read_u16(body);assert(size>=10 and size<4096,'EMPTYRGN / REGION SIZE')
 print(string.format('EMPTYRGN_%s sp=%X call=%X handle=%X body=%X size=%X result=%X zone=%X memerr=%X',label,sp,call,region,body,size,mem:read_u16(stack+4),ptr(0x118),mem:read_u16(0x220))..tail)
 save(label:lower()..'-region',body,size)
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
  else
   assert(cpu.state.PC.value==call+2 and cpu.state.A7.value==stack+4,'EMPTYRGN / RETURN STACK')
   capture('RETURN',cpu.state.A7.value)
   done=true;print('PASS original EmptyRgn region and Boolean');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('EMPTYRGN / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
