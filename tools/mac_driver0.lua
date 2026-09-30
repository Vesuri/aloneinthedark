-- Original song request: call ABI, driver state and nested service contracts.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER0 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER0 / NO JUMP ENTRY')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/driver0-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed=false;local done=false;local phase='arm';local entry;local call;local ret;local originalSP;local scratch;local stack
local calls=0;local trapret;local trapargs;local trapword;local trapped
local function capture(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER0_%s sp=%X selector=%X argument=%X entry=%X',label,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u32(cpu.state.A7.value+4),entry)..tail)
 save(label:lower()..'-state',entry+0x4200,0x3048)
end
local function arm_services()
 dbg:command('bpclear');cpu.debug:bpset(ret,'1','')
 cpu.debug:bpset(0xdd60,string.format('(d@(sp+2)&0xffffff)>=0x%x && (d@(sp+2)&0xffffff)<0x%x',entry,entry+0x4200),'')
 dbg.execution_state='run'
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
   call=base(3)+0x138c;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);ret=call+2;originalSP=cpu.state.A7.value
   assert(bytes(call-10,14)=='2F2E000842A7206DF9544E90508F','DRIVER0 / CALLER BYTES')
   print('DRIVER0_BYTES '..bytes(call-10,14));print('DRIVER0_ENTRY_BYTES '..bytes(entry,12));save('driver',entry,0x7248)
   capture('ENTER');phase='services';arm_services()
  elseif cpu.state.PC.value==ret then
   assert(cpu.state.A7.value==originalSP);capture('RETURN');done=true
   print(string.format('PASS original driver0 call and service contracts calls=%d',calls));dbg:command('quit')
  elseif not trapped then
   assert(cpu.state.PC.value==0xdd60);local pc=ptr(cpu.state.A7.value+2)
   trapword=mem:read_u16(pc);trapret=mem:read_u32(cpu.state.A7.value+2)+2;trapargs=cpu.state.A7.value+8
   calls=calls+1;assert(calls<=2048,'DRIVER0 / SERVICE LIMIT')
   print(string.format('DRIVER0_SERVICE_ENTER n=%d offset=%X trap=%X sp=%X args=%s d0=%X a0=%X',calls,pc-entry,trapword,trapargs,bytes(trapargs,20),cpu.state.D0.value,cpu.state.A0.value))
   trapped=true;dbg:command('bpclear');cpu.debug:bpset(trapret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==trapret)
   print(string.format('DRIVER0_SERVICE_RETURN n=%d trap=%X sp=%X args=%s d0=%X a0=%X',calls,trapword,cpu.state.A7.value,bytes(cpu.state.A7.value,20),cpu.state.D0.value,cpu.state.A0.value))
   trapped=false;arm_services()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('DRIVER0 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
