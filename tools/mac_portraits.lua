-- Original portrait route, driven only by ordinary Return input.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PORTRAITS / DEBUGGER REQUIRED')
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
local phase=0;local menu,portraits
local function save(name,a,n)
 local f=assert(io.open('tmp/portraits-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(bytes(0xdd60,8)=='2F0A2F02246F000A','dispatcher bytes');armed=true
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa891 && (d@(sp+2)&0xffffff)=='..base(6)..'+0x337e','');dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  dbg:command('bpclear')
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
   print('PORTRAITS_MENU ticks='..mem:read_u32(0x16a))
  end
  if phase==3 then
   local code=address(13)
   if not code then cpu.debug:bpset(0xdd60,cond,'');dbg.execution_state='run';return end
   portraits=code+0x1eb6;assert(bytes(portraits,2)=='4EB9','portrait wait bytes');phase=4
   cpu.debug:bpset(portraits,'1','');dbg.execution_state='run';return
  end
  assert(cpu.state.PC.value==portraits,'portraits wait')
  local a5=cpu.state.A5.value
  print(string.format('PORTRAITS_REFERENCE pc=%X choice=%u ticks=%u input=%u',portraits,cpu.state.D7.value&65535,mem:read_u32(0x16a),mem:read_u16(a5-0x11af4)))
  local pm=ptr(ptr(ptr(ptr(0x8a4))+22));local ct=ptr(ptr(pm+42))
  assert(mem:read_u16(pm+32)==8 and (mem:read_u16(pm+4)&0x3fff)==640,'display layout')
  save('screen',mem:read_u32(pm),307200);save('clut',ct,2056);save('a5',a5-75616,79392)
  done=true;print('PASS original portraits wait capture');dbg:command('quit')
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return')
  local found=mac.wait_for('game menu',function()return menuSeen end,3600);print(string.format('MENU_WAIT found=%s phase=%u pc=%X ticks=%u base=%X',tostring(found),phase,cpu.state.PC.value,mem:read_u32(0x16a),address(12) or 0));assert(found);mac.wait(30);mac.press('Return')
  mac.wait(3600);error('portraits endpoint absent')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
