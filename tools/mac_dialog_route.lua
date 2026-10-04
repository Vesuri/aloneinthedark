-- Observe Dialog Manager/StandardFile while the original game supplies its UI.
-- Ordinary keyboard route only: no instruction, resource or game-state edits.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a)
 local name='Alone In The Dark';local guard={string.format('b@910==0x%x',#name)}
 for i=1,#name do guard[#guard+1]=string.format('b@0x%x==0x%x',0x910+i,name:byte(i))end
 local trap='w@(d@(sp+2))'
 -- A992 is DetachResource, interleaved with this trap range, not a dialog.
 cpu.debug:bpset(0xdd60,table.concat(guard,' && ')..' && (( '..trap..'>=a97b && '..trap..'<=a993 && '..trap..'!=a992) || '..trap..'==a9ea)',
  'logerror "DIALOG_ROUTE trap=%04X pc=%08X p0=%08X p1=%08X p2=%08X\\n",w@(d@(sp+2)),d@(sp+2),d@(sp+8),d@(sp+c),d@(sp+10);g')
 armed=true;print('DIALOG_ROUTE_ARM bytes=2f0a2f02246f000a')
end)
local function key(name,command)
 if command then mac.key_down(mac.CMD)end
 mac.wait(2);mac.key_down(name);mac.wait(8);mac.key_up(name)
 if command then mac.key_up(mac.CMD)end
 mac.wait(10)
end
local function pixels(points)
 local raw,w,h=screen:pixels();assert(w==640 and h==480)
 for _,p in ipairs(points)do
  if(string.unpack('I4',raw,4*(p[2]*w+p[1])+1)&0xffffff)~=p[3]then return false end
 end
 return true
end
local function room()return pixels({{180,160,0x814530},{290,245,0x7d6154},{400,300,0x71584a}})end
local function slot()return pixels({{190,180,0x84653b},{400,210,0x81a1a1},{200,345,0}})end
local function capture(name)
 local raw,w,h=screen:pixels();assert(w==640 and h==480)
 local f=assert(io.open('tmp/m3-dialog/mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
 print('DIALOG_STATE '..name..' ticks='..mem:read_u32(0x16a))
end
local function state(name,fn)
 assert(mac.wait_for(name,fn,1800),'DIALOG STATE '..name);capture(name)
end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());assert(armed);mac.wait(300)
  local function window320()
   local w=mem:read_u32(0x9d6)&0xffffff
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=mem:read_u32(w+0x90)&0xffffff
   end
   return false
  end
  if not window320()then assert(mac.mouse_to(256,274));mac.click(1)end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  mac.wait(3000);key('Space');mac.wait(120);capture('main-menu')
  key('Return');mac.wait(720);capture('new-game')
  key('Right Arrow');key('Return');mac.wait(240);capture('character-story')
  key('Return');mac.wait(180);key('Esc');state('attic',room)
  key('s',true);state('save-cancel',slot);key('Esc');state('save-cancelled',room)
  key('s',true);state('save-name',slot)
  local backspace
  for _,port in pairs(manager.machine.ioport.ports)do for name,_ in pairs(port.fields)do
   if name:find('Backspace')then backspace=name end
  end end
  assert(backspace);for _=1,31 do key(backspace)end
  mac.type('dialog');key('Return');state('saved',room)
  -- Saving the same slot again exercises the overwrite route. Any warning is logged.
  key('s',true);state('overwrite',slot);key('Return');state('overwritten',room)
  key('o',true);state('load-cancel',slot);key('Esc');state('load-cancelled',room)
  key('o',true);state('load',slot);key('Return');state('loaded',room)
  key('q',true);assert(mac.wait_for('Finder',function()return mac.frontmost()=='Finder'end,1800))
  print('PASS original dialog route newgame save cancel overwrite load quit');manager.machine:exit()
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
