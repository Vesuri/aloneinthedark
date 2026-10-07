-- Authorized RAM-only loop stop/replacement contracts; no instruction or register edits.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local action=tonumber(assert(os.getenv('AITD_LOOP_ACTION')))
local folder=assert(os.getenv('AITD_EFFECT_FOLDER'));assert(action==17 or action==18)
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2]end end
 error('LOOP ACTION / SEGMENT')
end
local function save(name,a,n)
 local f=assert(io.open(folder..'/'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local entry,packet,counter,started,savedsp,ret,oldSelector,oldArgument
local function capture(label)
 local regs=''
 for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do regs=regs..string.format(' %s=%X',r:lower(),cpu.state[r].value)end
 print(string.format('LOOP_ACTION_%s sp=%X tick=%X action=%X packet=%X counter=%X%s',label,cpu.state.A7.value,mem:read_u32(0x16a),action,packet,mem:read_u16(counter),regs))
 save(label:lower()..'-state',entry+0x4200,0x3048)
end
local armed=false;local done=false;local phase='arm'
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
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x17fc,'1','');phase='play'
  elseif phase=='play' then
   entry=ptr(cpu.state.A5.value-0x6ac);packet=ptr(cpu.state.A7.value+4);counter=ptr(packet+20)
   assert(counter>0 and counter<0x800000 and mem:read_u32(packet+4)>=4096,'LOOP ACTION / OWNED PACKET')
   mem:write_u32(packet+4,4096);mem:write_u32(packet+12,512);mem:write_u32(packet+16,1024);mem:write_u16(counter,65535)
   save('sample',ptr(packet),4096);save('driver',entry,0x7248)
   started=mem:read_u32(0x16a)
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x17fe,'1','');phase='wait'
  elseif phase=='wait' then
   dbg:command('bpclear')
   local cond=string.format('d@0x16a>=0x%x',started+30)
   cpu.debug:bpset(entry,cond,'');cpu.debug:bpset(entry|0x80000000,cond,'');phase='action'
  elseif phase=='action' then
   local voice=entry+0x4200+0x22d2+6*4;local sample=ptr(packet)
   assert(mem:read_u16(voice+0x200)<0x8000 and mem:read_u16(counter)==65535,'LOOP ACTION / ACTIVE LOOP')
   assert(ptr(voice)>=sample+512 and ptr(voice)<sample+1024,'LOOP ACTION / REPEATING CURSOR')
   if action==17 then
    -- Isolate the already measured single occupied-slot selection contract.
    mem:write_u16(entry+0x4200+0x11c4,1)
    mem:write_u32(packet+12,0);mem:write_u32(packet+16,0);mem:write_u16(packet+24,0x8001)
   end
   savedsp=cpu.state.A7.value;ret=mem:read_u32(savedsp)
   oldSelector=mem:read_u32(savedsp+4);oldArgument=mem:read_u32(savedsp+8)
   mem:write_u32(savedsp+4,action);mem:write_u32(savedsp+8,packet)
   print(string.format('LOOP_ACTION_FIXTURE original=%X elapsed=%u entry=%X',oldSelector,mem:read_u32(0x16a)-started,entry))
   save('packet',packet,26);capture('ENTER')
   dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return'
  else
   assert(cpu.state.A7.value==savedsp+4,'LOOP ACTION / RETURN STACK');capture('RETURN')
   mem:write_u32(savedsp+4,oldSelector);mem:write_u32(savedsp+8,oldArgument)
   print('PASS original active loop stop/replacement contract');done=true;dbg:command('quit');return
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('LOOP ACTION / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
