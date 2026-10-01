-- Original GlobalToLocal call reached by normal Return and menu mouse input.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'GLOBALLOCAL / DEBUGGER REQUIRED')
local function regs()local t='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do t=t..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end;return t end
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function address(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then
  local entry=ptr(0x904)+32+(i-1)*8
  if mem:read_u16(entry+2)~=0x4ef9 then return nil end
  return ptr(entry+4)-j[2]
 end end
end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('missing segment jump entry')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local armed,done,skip,menuSeen=false,false,false,false
local phase=-1;local menu;local qd;local point;local args;local ret;local port;local pm
local function save(name,a,n)
 local f=assert(io.open('tmp/globallocal-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(bytes(0xdd60,8)=='2F0A2F02246F000A','dispatcher bytes');armed=true
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  dbg:command('bpclear')
  if phase==-1 then
   qd=ptr(cpu.state.A7.value+8);phase=0
   cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa891 && (d@(sp+2)&0xffffff)=='..base(6)..'+0x337e','');dbg.execution_state='run';return
  end
  if phase==0 then
   print(string.format('FIRST_LINE ticks=%u call=%X dark3=%X',mem:read_u32(0x16a),ptr(cpu.state.SP.value+2),address(6) or 0));skip=true;phase=1
  end
  if phase==1 then
   local code=address(12)
   if not code then cpu.debug:bpset(0xdd60,cond,'');dbg.execution_state='run';return end
   print(string.format('MENU_ARM ticks=%u base=%X pc=%X',mem:read_u32(0x16a),code,cpu.state.PC.value));menu=code+0x1374;assert(bytes(menu,4)=='42A7A975','menu wait bytes');phase=2
   cpu.debug:bpset(menu,'1','');dbg.execution_state='run';return
  elseif phase==2 then
   assert(cpu.state.PC.value==menu,'menu wait');menuSeen=true;phase=3
   print('GLOBALLOCAL_MENU ticks='..mem:read_u32(0x16a))
  end
  if phase==3 then
   phase=4;cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa871 && ((d@(sp+2)&0xffffff)=='..base(7)..'+0x16e8 || (d@(sp+2)&0xffffff)=='..base(7)..'+0x1852 || (d@(sp+2)&0xffffff)=='..base(13)..'+0x31c4)','');dbg.execution_state='run';return
  end
  if phase==4 then
   args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;point=ptr(args);port=ptr(qd);pm=ptr(ptr(port+2))
   assert(ret-2==address(7)+0x16e8 and bytes(ret-10,10)=='27530004486B0004A871','Engine inverse caller')
   assert(mem:read_u16(pm+32)==8,'selected eight-bit port')
   print(string.format('GL_ENTRY call=%X args=%X point=%X value=%08X port=%X pm=%X bounds=%s caller=%s',ret-2,args,point,mem:read_u32(point),port,pm,bytes(pm+6,8),bytes(ret-10,12))..regs())
   save('inverse-before',point-4,12);save('inverse-port',port,108);save('inverse-pm',pm,50)
   phase=5;cpu.debug:bpset(ret,'1','')
  else
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==args+4,'inverse return')
   print(string.format('GL_RETURN sp=%X value=%08X',cpu.state.A7.value,mem:read_u32(point))..regs());save('inverse-after',point-4,12)
   done=true;print('PASS original GlobalToLocal call');dbg:command('quit');return
  end
  dbg.execution_state='run'

 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return')
  local found=mac.wait_for('game menu',function()return menuSeen end,3600);print(string.format('MENU_WAIT found=%s phase=%u pc=%X ticks=%u base=%X',tostring(found),phase,cpu.state.PC.value,mem:read_u32(0x16a),address(12) or 0));assert(found);mac.wait(30);assert(mac.mouse_to(320,250));mac.click(1)
  mac.wait(3600);error('inverse endpoint absent')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
