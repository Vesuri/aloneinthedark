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
 local f=assert(io.open('tmp/m3-explore/key-session-lamp-use-mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
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
  local objects=world-0x115f2
  local function lamp()return mem:read_u16(objects+13*52+12)end
  assert(mem:read_i16(objects+13*52+8)==10 and mem:read_i16(objects+13*52+10)==201,'original lamp record')
  assert(lamp()==0x609 and mem:read_i16(world-0xd8a6)==1 and mem:read_i16(world-0xd8a4)==2,'initial inventory before pickup')
  local function report(label)
   print(string.format('EXPLORE phase=%s tick=%d x=%d z=%d beta=%d anim=%d room=%d floor=%d key=%d action=%d',label,mem:read_u32(0x16a),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x2a),mem:read_i16(actor+0x3e),mem:read_i16(actor+0x30),mem:read_i16(actor+0x2e),mem:read_i16(world-0x11af4),mem:read_i16(world-0xd868)))
   capture(label)
   print(string.format('LAMP_USE_STATE phase=%s body=%d selected=%d track=%d',label,mem:read_i16(actor+2),mem:read_i16(world-0xd8a8),mem:read_i16(actor+0x52)))
   print(string.format('LAMP_STATE phase=%s flags=%X count=%d slot0=%d slot1=%d stage=%d room=%d',label,lamp(),mem:read_i16(world-0xd8a6),mem:read_i16(world-0xd8a4),mem:read_i16(world-0xd8a2),mem:read_i16(objects+13*52+28),mem:read_i16(objects+13*52+30)))
   local f=assert(io.open('tmp/m3-explore/key-session-lamp-use-'..label..'-a5.bin','wb'));for i=0,75615 do f:write(string.char(mem:read_u8(world-75616+i)))end;f:close()
  end
  report('initial')
  mac.key_down('Left Arrow');assert(mac.wait_for('turn toward lamp x',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<512 end,600));mac.key_up('Left Arrow');mac.wait(30);report('turned-left')
  mac.key_down('Up Arrow');assert(mac.wait_for('lamp x',function()return mem:read_i16(actor+0x1c)>=3600 end,1200));mac.key_up('Up Arrow');mac.wait(30);report('lamp-x')
  mac.key_down('Right Arrow');assert(mac.wait_for('face table',function()local b=mem:read_i16(actor+0x2a)&1023;return b<=8 or b>=1016 end,600));mac.key_up('Right Arrow');mac.wait(30);report('facing-table')
  mac.key_down('Up Arrow')
  local last=mem:read_u32(0x16a)
  assert(mac.wait_for('approach lamp',function()
   local t=mem:read_u32(0x16a)
   if t-last>=120 then print(string.format('EXPLORE_WALK tick=%d x=%d z=%d anim=%d',t,mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x3e)));last=t end
   return mem:read_i16(actor+0x20)<=-3800
  end,2400))
  mac.key_up('Up Arrow');mac.wait(30);report('lamp-approach')
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30);report('open-mode')
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(30);report('search-lamp')
  key('Return')
  assert(mac.wait_for('oil lamp taken',function()
   return lamp()==0x8609 and mem:read_i16(world-0xd8a6)==2 and mem:read_i16(world-0xd8a4)==2 and mem:read_i16(world-0xd8a2)==13
  end,1800))
  state('returned-room',function()return pixels({{180,160,0x814530}}) and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end);report('taken-lamp')
  key('Return');mac.wait(180);report('inventory-open')
  key('Down Arrow');mac.wait(120);report('lamp-selected')
  key('Return');mac.wait(120);report('lamp-actions')
  key('Return');mac.wait(180);report('lamp-first-action')
  assert(mem:read_i16(actor+2)==11 and mem:read_i16(world-0xd8a8)==13 and mem:read_i16(actor+0x3e)==287,'lamp Use animation and selected object')
  mac.wait(120)
  assert(mem:read_i16(actor+0x3e)==287 and mem:read_i16(actor+0x52)==1,'empty lamp stance')
  report('lamp-feedback')
  mac.key_down('Down Arrow')
  assert(mac.wait_for('move after lamp Use',function()return mem:read_i16(actor+0x20)>=-3500 end,1200))
  mac.key_up('Down Arrow');mac.wait(90)
  assert(mem:read_i16(actor+0x3e)==287 and mem:read_i16(actor+0x52)==1,'lamp stance after movement')
  report('key-session-lamp-use-complete')
  mac.key_down('o');mac.wait(120);mac.key_up('o')
  assert(mac.wait_for('Open/Search walking stance',function()return mem:read_i16(actor+2)==12 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('walking-mode')
    local function move(name,label,fn)
   mac.key_down(name);assert(mac.wait_for(label,fn,3600),label);mac.key_up(name)
   assert(mac.wait_for('released '..label,function()return mem:read_i16(actor+0x3e)==4 or mem:read_i16(actor+0x3e)==287 end,1200));mac.wait(30);report(label)
  end
  move('Down Arrow','back',function()return mem:read_i16(actor+0x20)>=1000 end)
  move('Left Arrow','east',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<512 end)
  move('Up Arrow','partition-side',function()return mem:read_i16(actor+0x1c)>=4100 end)
  move('Left Arrow','south',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<768 end)
  move('Up Arrow','stair-opening',function()return mem:read_i16(actor+0x20)>=3600 end)
  local function align(axis,low,high,backForHigh)
   local offset=axis=='z' and 0x20 or 0x1c
   local alignStart=mem:read_u32(0x16a)
   while mem:read_i16(actor+offset)<low or mem:read_i16(actor+offset)>high do
    assert(mem:read_u32(0x16a)-alignStart<1800,'alignment deadline')
    local back=(mem:read_i16(actor+offset)>high)==backForHigh
    local name=back and 'Down Arrow' or 'Up Arrow'
    mac.key_down(name)
    assert(mac.wait_for('alignment step begun',function()return mem:read_i16(actor+0x3e)==(back and 256 or 254) end,600))
    mac.key_up(name)
    assert(mac.wait_for('alignment step completed',function()return mem:read_i16(actor+0x3e)==4 end,1200))
    print(string.format('ALIGN_MAC axis=%s tick=%d position=%d',axis,mem:read_u32(0x16a),mem:read_i16(actor+offset)))
   end
  end
  align('z',3920,4070,true)
  move('Right Arrow','east-opening',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<=272 end)
  move('Up Arrow','inside-stairs',function()return mem:read_i16(actor+0x1c)>=6650 end)
  move('Right Arrow','north-stairs',function()local b=mem:read_i16(actor+0x2a)&1023;return b<=32 or b>=992 end)
  mac.key_down('Up Arrow');assert(mac.wait_for('floor transition',function()return mem:read_i16(actor+0x2e)==1 end,3600));mac.key_up('Up Arrow')
  local stable
  assert(mac.wait_for('first-floor manual control',function()
   local t=mem:read_u32(0x16a)
   if mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x30)==6 and (mem:read_i16(actor+0x3e)==4 or mem:read_i16(actor+0x3e)==287) and mem:read_i16(actor+0x52)==1 then
    stable=stable or t;return t-stable>=30
   end
   stable=nil;return false
  end,3600));report('first-floor')
  print('EXPLORE_MANUAL track='..mem:read_i16(actor+0x52))
  if mem:read_i16(actor+0x1c)<-350 or mem:read_i16(actor+0x1c)>0 then
   mac.key_down('Left Arrow');assert(mac.wait_for('stair exit east alignment',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<=272 end,1200));mac.key_up('Left Arrow')
   assert(mac.wait_for('stair alignment released',function()return mem:read_i16(actor+0x3e)==4 end,1200));align('x',-350,0,true)
  end
  local b=mem:read_i16(actor+0x2a)&1023
  if b>16 and b<1008 then
   mac.key_down('Right Arrow');assert(mac.wait_for('stair exit north heading',function()local h=mem:read_i16(actor+0x2a)&1023;return h<=16 or h>=1008 end,1200));mac.key_up('Right Arrow')
   assert(mac.wait_for('stair north released',function()return mem:read_i16(actor+0x3e)==4 end,1200))
  end
  mac.wait(30)
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30)
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('stair-door-open')
  mac.key_down('Up Arrow')
  assert(mac.wait_for('room 0 first floor',function()return mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x30)==0 end,2400))
  mac.key_up('Up Arrow')
  assert(mac.wait_for('room 0 manual idle',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('first-floor-room0')
  move('Up Arrow','room0-door-line',function()return mem:read_i16(actor+0x20)<=3200 end)
  align('z',2720,2900,false)
  move('Right Arrow','room0-west',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=752 and b<=784 end)
  move('Up Arrow','room0-west-approach',function()return mem:read_i16(actor+0x1c)<=0 end)
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30)
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('room0-open-action')
  mac.key_down('Up Arrow')
  local entered=mac.wait_for('room 1 hallway',function()return mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x30)==1 end,2400)
  if not entered then mac.key_up('Up Arrow');report('FAIL-hallway');error('hallway not reached')end
  mac.key_up('Up Arrow');assert(mac.wait_for('hallway manual idle',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('first-floor-hallway')
    move('Up Arrow','hallway-bedroom-line',function()return mem:read_i16(actor+0x1c)<=3400 end)
  align('x',2720,2900,false)
  move('Left Arrow','hallway-north',function()local b=mem:read_i16(actor+0x2a)&1023;return b<=16 or b>=1008 end)
  move('Up Arrow','bedroom-door-approach',function()return mem:read_i16(actor+0x20)<=-850 end)
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30)
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('bedroom-open-action')
  mac.key_down('Up Arrow')
  local entered=mac.wait_for('room 2 bedroom',function()return mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x30)==2 end,2400)
  if not entered then mac.key_up('Up Arrow');report('FAIL-bedroom');error('bedroom not reached')end
  mac.key_up('Up Arrow');assert(mac.wait_for('bedroom manual idle',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('first-floor-bedroom')
  move('Up Arrow','bedroom-north',function()return mem:read_i16(actor+0x20)<=-1000 end)
  move('Right Arrow','bedroom-west',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=752 and b<=784 end)
  move('Up Arrow','key-desk-approach',function()return mem:read_i16(actor+0x1c)<=-500 end)
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30)
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('key-search')
  key('Return')
  local found=mac.wait_for('key 37 taken',function()return mem:read_u16(objects+37*52+12)==0x8601 and mem:read_i16(world-0xd8a6)==3 and mem:read_i16(world-0xd8a2)==37 end,1800)
  if not found then report('FAIL-key');error('key not taken')end
  assert(mac.wait_for('key pickup manual idle',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(180);report('bedroom-key-taken')
  print('PASS original lamp Use, hallway and bedroom key pickup');dbg:command('quit')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
