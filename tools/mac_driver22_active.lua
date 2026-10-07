-- Observe an ordinary stop-effects call with genuine active sample ownership.
-- Inputs are ADB only; every guest memory/register access below is read-only.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'ACTIVE DRIVER22 / DEBUGGER REQUIRED')
local folder=os.getenv('AITD_DRIVER22_ACTIVE_DIR') or 'tmp/m4-driver22-active/mac'
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('ACTIVE DRIVER22 / NO SEGMENT')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8((a+i)&0xffffff))end;return table.concat(t)end
local function save(name,a,n)
 local f=assert(io.open(folder..'/'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8((a+i)&0xffffff)))end;f:close()
end
local entry,state,call,ret,sp
local armed,done=false,false;local phase='arm';local ignored=0
local function effects()
 if not state then return 0 end
 local count=0
 for i=6,7 do
  local active=mem:read_u16(state+0x24d2+i*4)
  if active>0 and active<0x8000 and ptr(state+0x22d2+i*4)~=0 then count=count+1 end
 end
 return count
end
local function capture(label)
 local tail=''
 for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER22_ACTIVE_%s sp=%X selector=%X ignored=%X entry=%X tick=%X effects=%d',label,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u32(cpu.state.A7.value+4),entry,mem:read_u32(0x16a),effects())..tail)
 save(label:lower()..'-state',state,0x3048)
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
   call=base(3)+0x1a74;assert(bytes(call-8,12)=='48780016206DF9544E90588F','ACTIVE DRIVER22 / CALLER BYTES')
   dbg:command('bpclear');cpu.debug:bpset(call,'1','');phase='entry'
  elseif phase=='entry' then
   assert(cpu.state.PC.value==call);entry=ptr(cpu.state.A5.value-0x6ac);state=entry+0x4200
   if effects()==0 then
    ignored=ignored+1;print('DRIVER22_ACTIVE_SKIP inactive='..ignored)
   else
    sp=cpu.state.A7.value;ret=call+2
    print('DRIVER22_ACTIVE_BYTES '..bytes(call-8,12));print('DRIVER22_ACTIVE_ENTRY_BYTES '..bytes(entry,12))
    save('driver',entry,0x7248);capture('ENTER')
    dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return'
   end
  else
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==sp)
   capture('RETURN');done=true;print('PASS original ordinary active driver22 call');dbg:command('quit');return
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
local function key(name)mac.wait(2);mac.key_down(name);mac.wait(8);mac.key_up(name);mac.wait(10)end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('genuine intro effect',function()return effects()>0 end,6000),'ACTIVE DRIVER22 / NO INTRO EFFECT')
  print('DRIVER22_ACTIVE_INPUT Space intro-effect');key('Space');mac.wait(120)
  key('Return');mac.wait(720);key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180);key('Esc')
  assert(mac.wait_for('genuine gameplay effect',function()return effects()>0 end,7200),'ACTIVE DRIVER22 / NO GAMEPLAY EFFECT')
  print('DRIVER22_ACTIVE_INPUT S gameplay-effect');key('s');mac.wait(3600)
  error('ACTIVE DRIVER22 / NO ACTIVE STOP')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
