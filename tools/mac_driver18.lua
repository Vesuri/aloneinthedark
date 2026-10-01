-- Original targeted-effect stop fixture, following normal Enter and effect play.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER18 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER18 / NO JUMP ENTRY')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/driver18-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local skip=false;local armed=false;local done=false;local phase='arm';local entry;local call;local ret;local originalSP;local playCall
local function capture(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER18_%s sp=%X selector=%X ignored=%X entry=%X',label,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u32(cpu.state.A7.value+4),entry)..tail)
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
  if phase=='skip' then
   skip=true;dbg:command('bpclear');playCall=base(3)+0x17fc;cpu.debug:bpset(playCall,'1','');phase='play';dbg.execution_state='run'
  elseif phase=='arm' then
   call=base(3)+0x1828;dbg:command('bpclear');cpu.debug:bpset(0xdd60,'w@(d@(sp+2))==0xa891','');phase='skip';dbg.execution_state='run'
  elseif phase=='play' then
   assert(cpu.state.PC.value==playCall,'play fixture caller')
   originalSP=cpu.state.A7.value;dbg:command('bpclear');cpu.debug:bpset(playCall+2,'1','');phase='played';dbg.execution_state='run'
  elseif phase=='played' then
   assert(cpu.state.PC.value==playCall+2 and cpu.state.A7.value==originalSP,'play fixture return')
   -- Invoke the unchanged original stop call with the just-played packet.
   -- This diagnostic fixture changes arguments/PC, never original instructions.
   mem:write_u32(originalSP,18);cpu.state.A0.value=ptr(cpu.state.A5.value-0x6ac);cpu.state.PC.value=call
   print('DRIVER18_FIXTURE active effect immediately after selector 17')
   phase='entry'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);ret=call+2;originalSP=cpu.state.A7.value
   assert(bytes(call-8,12)=='48780012206DF9544E90508F','caller bytes');print('DRIVER18_BYTES '..bytes(call-8,12));print('DRIVER18_ENTRY_BYTES '..bytes(entry,12));save('driver',entry,0x7248)
   local packet=ptr(originalSP+4);print('DRIVER18_PACKET '..bytes(packet,26));save('packet',packet,26)
   capture('ENTER');dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==originalSP);capture('RETURN')
   done=true;print('COMPLETE original driver18 targeted stop');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return');print('DRIVER18_SKIP Return released');mac.wait(42000);error('DRIVER18 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
