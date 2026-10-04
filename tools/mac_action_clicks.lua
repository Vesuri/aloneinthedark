-- Original ordinary keyboard/mouse navigation and cancellation.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local dbg=assert(manager.machine.debugger);local active=false
local function ptr(a)return mem:read_u32(a)&0xffffff end
local meta=dofile('tmp/mac-trap-map.lua')
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(ptr(0x904)+36+(i-1)*8)-j[2]end end
 error('ACTION NAV / SEGMENT')
end
local dan;local captured=false
local function armNavigation(capture)
 dbg:command('bpclear')
 for _,alias in ipairs({0,0x80000000})do
  cpu.debug:bpset((dan+0xc92)|alias,'1','logerror "ACTION_NAV_DRAW tick=%d selection=%d\\n",d@16a,w@(sp+4);g')
  cpu.debug:bpset((dan+0x8a8)|alias,'1','logerror "ACTION_NAV_CANCEL tick=%d actions=%x room=%d\\n",d@16a,w@(a5-d868),w@(a5-cd68);g')
  cpu.debug:bpset((dan+0x10ee)|alias,capture and 'd4!=1' or '1','logerror "ACTION_NAV_PREVIEW tick=%d selection=%d mouse=%d,%d\\n",d@16a,d4,w@82e,w@82c;g')
  if capture then cpu.debug:bpset((dan+0x10ee)|alias,'d4==1','')end
 end
 dbg:command('temp0=0')
 cpu.debug:bpset(0xdd60,'w@(d@(sp+2))==a974 && b@172==0 && temp0==0','temp0=1;logerror "ACTION_CLICK_BUTTON tick=%d mouse=%d,%d mb=%x\\n",d@16a,w@82e,w@82c,b@172;g')
end
emu.register_periodic(function()
 if not dan or captured or dbg.execution_state~='stop' then return end
 dofile('tools/mame_mac_frame.lua').rgb('tmp/m3-action/mac-click-rgb.bin')
 captured=true;print('ACTION_NAV_CAPTURE selection=1')
 armNavigation(false);dbg.execution_state='run'
end)
local function key(name,cmd)
 if cmd then mac.key_down(mac.CMD) end
 mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name)
 if cmd then mac.key_up(mac.CMD) end
 mac.wait(10)
end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  local function window320()
   local w=mem:read_u32(0x9d6)&0xffffff
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=mem:read_u32(w+0x90)&0xffffff
   end
   return false
  end
  if not window320() then assert(mac.mouse_to(256,274));mac.click(1) end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
  key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180)
  key('Esc')
  assert(mac.wait_for('attic',function()
   local raw,w,h=screen:pixels();if w~=640 or h~=480 then return false end
   return (string.unpack('I4',raw,4*(160*w+180)+1)&0xffffff)==0x814530
  end,1800))

  mac.key_down('Return');mac.wait(30);mac.key_up('Return');mac.wait(120)
  dan=base(12);assert(mem:read_u32(dan+0xc92)==0x4e56ffee and mem:read_u16(dan+0x8a8)==0x4e75)
  armNavigation(true)
  for _,name in ipairs({'Right Arrow','Down Arrow','Up Arrow'})do
   print('ACTION_NAV_KEY name='..name..' tick='..mem:read_u32(0x16a))
   mac.key_down(name);mac.wait(60);mac.key_up(name);mac.wait(60)
  end
  print('ACTION_NAV_MOUSE tick='..mem:read_u32(0x16a));assert(mac.mouse_to(410,285));mac.wait(120); print('ACTION_CLICK tick='..mem:read_u32(0x16a));mac.mouse_down();mac.wait(120);mac.mouse_up();mac.wait(120)
  assert(mac.mouse_to(620,470));mac.wait(120)
  print('ACTION_NAV_ESCAPE tick='..mem:read_u32(0x16a));mac.key_down('Esc');mac.wait(60);mac.key_up('Esc');mac.wait(120)
  assert(mac.wait_for('returned attic',function()
   local raw,w,h=screen:pixels();return (string.unpack('I4',raw,4*(160*w+180)+1)&0xffffff)==0x814530
  end,1800))
  assert(captured,'ACTION NAV / no selected-action capture')
  print('PASS original action clicks returned attic');dbg:command('quit')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
