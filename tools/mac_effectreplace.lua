-- Measure the first original replacement of the sole occupied effect slot.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER17 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER17 / NO JUMP ENTRY')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/effectreplace-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local priorClock=nil;local lastFirst=nil;local ignoredCall=false
local armed=false;local done=false;local phase='arm';local entry;local call;local ret;local originalSP;local loopCounter;local startTick
local function capture(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER17_%s sp=%X selector=%X ignored=%X entry=%X',label,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u32(cpu.state.A7.value+4),entry)..tail)
 save(label:lower()..'-state',entry+0x4200,0x3048)
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed then return end
 if dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='arm' then
   call=base(3)+0x17fc;dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);ret=call+2;originalSP=cpu.state.A7.value
   local state=entry+0x4200;local first=mem:read_u16(state+0x11c0);local count=mem:read_u16(state+0x11c4)
   local occupied=count>0
   for i=0,count-1 do if mem:read_u16(state+0x24d2+(first+i)*4)>=0x8000 then occupied=false end end
   if not occupied then
    ignoredCall=true;lastFirst=first;dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run';return
   end
   local clock=mem:read_u32(state+0x1880);local age=mem:read_u16(state+0x24d2+first*4)
   assert(priorClock,'EFFECT REPLACE / MISSING START CLOCK')
   print(string.format('EFFECT_AGE clock=%X started=%X elapsed=%X age=%X',clock,priorClock,clock-priorClock,age))
   assert(age==0x7ffe-(clock-priorClock),'EFFECT REPLACE / AGE CLOCK')
   print(string.format('EFFECT_REPLACE first=%u count=%u age0=%X age1=%X ticks=%X',first,count,mem:read_u16(state+0x24d2+first*4),mem:read_u16(state+0x24d2+(first+1)*4),mem:read_u32(0x16a)))
   print('DRIVER17_BYTES '..bytes(call-18,22));print('DRIVER17_ENTRY_BYTES '..bytes(entry,12));save('driver',entry,0x7248)
   local packet=ptr(originalSP+4);print('DRIVER17_PACKET '..bytes(packet,26));save('packet',packet,26)
   local sample=ptr(packet);local size=mem:read_u32(packet+4);assert(size>0 and size<1048576,'DRIVER17 / SAMPLE SIZE');save('sample',sample,size)
   loopCounter=ptr(packet+20);startTick=mem:read_u32(0x16a);print(string.format('DRIVER17_LOOP word=%X tick=%X',mem:read_u16(loopCounter),startTick));capture('ENTER');dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==originalSP)
   if ignoredCall then
    ignoredCall=false;priorClock=mem:read_u32(entry+0x4200+0x1880)
    assert(mem:read_u16(entry+0x4200+0x24d2+lastFirst*4)==0x7ffe,'EFFECT REPLACE / START AGE')
    dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry';dbg.execution_state='run';return
   end
   capture('RETURN')
   done=true;print('COMPLETE original occupied effect replacement');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(42000);error('DRIVER17 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
