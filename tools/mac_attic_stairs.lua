local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger);local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local function ptr(a)return mem:read_u32(a)&0xffffff end
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
 local f=assert(io.open('tmp/m3-explore/stairs-mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
 print('DIALOG_STATE '..name..' ticks='..mem:read_u32(0x16a))
end
local function state(name,fn)
 assert(mac.wait_for(name,fn,1800),'DIALOG STATE '..name);capture(name)
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
  if not window320()then assert(mac.mouse_to(256,274));mac.click(1)end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  mac.wait(3000);key('Space');mac.wait(120);capture('main-menu')
  key('Return');mac.wait(720);capture('new-game')
  key('Right Arrow');key('Return');mac.wait(240);capture('character-story')
  key('Return');mac.wait(180);key('Esc');state('attic',room)
  local world,actor
  assert(mac.wait_for('Carnby',function()
   local w=ptr(0x904);local a=w-0xb292+160
   if a>0 and mem:read_i16(a)==1 and mem:read_i16(a+2)==12 then world=w;actor=a;return true end
  end,1200))
  local function report(label)
   print(string.format('EXPLORE phase=%s tick=%d x=%d z=%d beta=%d anim=%d room=%d floor=%d key=%d action=%d',label,mem:read_u32(0x16a),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x2a),mem:read_i16(actor+0x3e),mem:read_i16(actor+0x30),mem:read_i16(actor+0x2e),mem:read_i16(world-0x11af4),mem:read_i16(world-0xd868)))
   capture(label)
   local f=assert(io.open('tmp/m3-explore/stairs-'..label..'-a5.bin','wb'));for i=0,75615 do f:write(string.char(mem:read_u8(world-75616+i)))end;f:close()
  end
  report('initial')
  local function move(name,label,fn)
   mac.key_down(name);assert(mac.wait_for(label,fn,3600),label);mac.key_up(name)
   assert(mac.wait_for('released '..label,function()return mem:read_i16(actor+0x3e)==4 end,1200));mac.wait(30);report(label)
  end
  move('Down Arrow','back',function()return mem:read_i16(actor+0x20)>=1000 end)
  move('Left Arrow','east',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<512 end)
  move('Up Arrow','partition-side',function()return mem:read_i16(actor+0x1c)>=4100 end)
  move('Left Arrow','south',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<768 end)
  move('Up Arrow','stair-opening',function()return mem:read_i16(actor+0x20)>=3600 end)
  move('Right Arrow','east-opening',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<=280 end)
  move('Up Arrow','inside-stairs',function()return mem:read_i16(actor+0x1c)>=6650 end)
  move('Right Arrow','north-stairs',function()local b=mem:read_i16(actor+0x2a)&1023;return b<=32 or b>=992 end)
  mac.key_down('Up Arrow');assert(mac.wait_for('floor transition',function()return mem:read_i16(actor+0x2e)==1 end,3600));mac.key_up('Up Arrow')
  local stable
  assert(mac.wait_for('first-floor manual control',function()
   local t=mem:read_u32(0x16a)
   if mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x30)==6 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 then
    stable=stable or t;return t-stable>=30
   end
   stable=nil;return false
  end,3600));report('first-floor')
  print('EXPLORE_MANUAL track='..mem:read_i16(actor+0x52))
  print('PASS original attic stairs reached first floor');dbg:command('quit')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
