-- Original 68030 Mac: ordinary Return input and 20 Actions preview rotations.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local dbg=assert(manager.machine.debugger);local active=false
local function ptr(a)return mem:read_u32(a)&0xffffff end
local frames=0;local started;local captureFrame=false;local elapsed;local entry;local previousAngle;local meta=dofile('tmp/mac-trap-map.lua')
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(ptr(0x904)+36+(i-1)*8)-j[2]end end
 error('ACTION / SEGMENT')
end
emu.register_periodic(function()
 if not active or dbg.execution_state~='stop' then return end
 if captureFrame then
  local gd=ptr(ptr(0x8a4));local pm=ptr(ptr(gd+22));local pixels=mem:read_u32(pm)
  local stride=mem:read_u16(pm+4)&0x3fff
  assert(mem:read_u16(pm+32)==8 and stride>=640)
  local palette=assert(manager.machine.palettes[':nb9:mdc48']);local colors={}
  for i=0,255 do local c=palette:pen_color(i);colors[i]=string.char((c>>16)&255,(c>>8)&255,c&255)end
  local f=assert(io.open('tmp/m3-action/mac-menu-rgb.bin','wb'))
  for y=0,479 do local row={};for x=0,639 do row[#row+1]=colors[mem:read_u8(pixels+y*stride+x)]end;f:write(table.concat(row))end;f:close()
  print('PASS action timing elapsed='..elapsed..' updates=20 hz=60');active=false;dbg:command('quit');return
 end
 local tick=mem:read_u32(0x16a);local angle=mem:read_i16(ptr(0x904)-0xce86)
 if previousAngle and angle~=previousAngle-8 then
  print('FAIL ACTION rotation sequence');active=false;manager.machine:exit();return
 end
 previousAngle=angle;frames=frames+1
 print(string.format('ACTION_PREVIEW n=%u tick=%u angle=%d actor=%d',frames,tick,mem:read_i16(ptr(0x904)-0xce86),mem:read_i16(cpu.state.A6.value+8)))
 if frames==1 then started=tick end
 if frames>=21 then
  elapsed=tick-started;captureFrame=true;dbg:command('bpclear')
  cpu.debug:bpset(entry+0x174,'1','');cpu.debug:bpset((entry+0x174)|0x80000000,'1','');dbg.execution_state='run'
 else dbg.execution_state='run' end
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

  active=false;dbg.execution_state='run'
  print('ACTION_KEY tick='..mem:read_u32(0x16a));mac.key_down('Return');mac.wait(30);mac.key_up('Return');mac.wait(60)
  entry=base(12)+0xf7a;assert(mem:read_u16(entry)==0x5179,'ACTION / preview bytes')
  active=true;cpu.debug:bpset(entry,'1','');cpu.debug:bpset(entry|0x80000000,'1','');dbg.execution_state='run'

  mac.wait(6000);error('ACTION / timing not complete')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
