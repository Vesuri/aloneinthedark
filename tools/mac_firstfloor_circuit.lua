-- Original connected first-floor circuit, with ordinary input and living-state guards.
-- Set AITD_CIRCUIT_ENDURANCE=1 for continuous ten-minute active coverage.
-- AITD_CIRCUIT_DIR selects the existing local capture directory.
-- AITD_CIRCUIT_LOAD=1 loads slot zero through ordinary game input.
-- AITD_CIRCUIT_STOP_AT_ROOM5=1 ends at the first published room5 entrance.
local repeatCircuit=os.getenv('AITD_CIRCUIT_ENDURANCE')=='1'
local loadCheckpoint=os.getenv('AITD_CIRCUIT_LOAD')=='1'
local folder=os.getenv('AITD_CIRCUIT_DIR') or (repeatCircuit and 'tmp/m3-endurance' or 'tmp/m3-circuit')
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local activity=dofile('tools/mame_active_gameplay.lua')(mac,mem,repeatCircuit and 'firstfloor-endurance' or 'firstfloor-circuit')
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
 local f=assert(io.open(folder..'/hallway-session-lamp-use-mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
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
  if loadCheckpoint then
   key('o',true);state('checkpoint-load-choice',slot);key('Return')
   assert(mac.wait_for('ordinary first-floor checkpoint Load',function()
    local vars=ptr(world-0xcbcc)
    return mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12 and
     mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x30)==3 and
     mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 and mem:read_i16(vars+42)>0
   end,3600),'first-floor checkpoint')
  end
  activity.start(world,actor)
  local objects=world-0x115f2
  local function lamp()return mem:read_u16(objects+13*52+12)end
  local function report(label)
   local vars=ptr(world-0xcbcc);local values={};for i=0,99 do values[#values+1]=tostring(mem:read_i16(vars+i*2))end
   print('ROOM5_VARS phase='..label..' values='..table.concat(values,','))
   print(string.format('EXPLORE phase=%s tick=%d x=%d z=%d beta=%d anim=%d room=%d floor=%d key=%d action=%d',label,mem:read_u32(0x16a),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x2a),mem:read_i16(actor+0x3e),mem:read_i16(actor+0x30),mem:read_i16(actor+0x2e),mem:read_i16(world-0x11af4),mem:read_i16(world-0xd868)))
   capture(label)
   print(string.format('LAMP_USE_STATE phase=%s body=%d selected=%d track=%d',label,mem:read_i16(actor+2),mem:read_i16(world-0xd8a8),mem:read_i16(actor+0x52)))
   print(string.format('LAMP_STATE phase=%s flags=%X count=%d slot0=%d slot1=%d stage=%d room=%d',label,lamp(),mem:read_i16(world-0xd8a6),mem:read_i16(world-0xd8a4),mem:read_i16(world-0xd8a2),mem:read_i16(objects+13*52+28),mem:read_i16(objects+13*52+30)))
   local f=assert(io.open(folder..'/hallway-session-lamp-use-'..label..'-a5.bin','wb'));for i=0,75615 do f:write(string.char(mem:read_u8(world-75616+i)))end;f:close()
  end
  local function move(name,label,fn)
   local function alive()return mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12 and mem:read_i16(ptr(world-0xcbcc)+42)>0 end
   mac.key_down(name);local reached=mac.wait_for(label,function()return fn() or not alive()end,3600);mac.key_up(name)
   if not alive()then report(label..'-hero-lost');error('hero lost during '..label)end
   if not reached then report(label..'-blocked')end;assert(reached,label)
   assert(mac.wait_for('released '..label,function()return mem:read_i16(actor+0x3e)==4 or mem:read_i16(actor+0x3e)==287 end,1200));mac.wait(30);report(label)
  end
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
  local function face(target,label)
   local delta=(target-mem:read_i16(actor+0x2a))&1023
   if delta>16 and delta<1008 then
    move(delta>512 and 'Left Arrow' or 'Right Arrow',label,function()local d=(target-mem:read_i16(actor+0x2a))&1023;return d<=16 or d>=1008 end)
   end
  end
  local vars=ptr(world-0xcbcc)
  if not loadCheckpoint then
  assert(mem:read_i16(objects+13*52+8)==10 and mem:read_i16(objects+13*52+10)==201,'original lamp record')
  assert(lamp()==0x609 and mem:read_i16(world-0xd8a6)==1 and mem:read_i16(world-0xd8a4)==2,'initial inventory before pickup')
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
  -- Hold ordinary keys until the published menu/selection acknowledges them.
  -- Short frame-count pulses can fall entirely between original game polls.
  local function key_until(name,label,ready,published)
   mac.wait(2);mac.key_down(name)
   local ok=mac.wait_for(label,ready,1800)
   mac.key_up(name);if not ok then report(label.."-timeout")end;assert(ok,label);mac.wait(30)
   if published then assert(mac.wait_for(label.." published",published,1800),label.." publication")end
   report(label)
  end
  key_until('Return','inventory-open',function()
   return pixels({{165,160,0xcaa169},{200,160,0},{320,245,0xc1c1b4}})
  end)
  key_until('Down Arrow','lamp-selected',function()return pixels({{287,186,0xffffff},{307,186,0xffffff}})end)
  local function action_pane()
   local raw,w,h=screen:pixels();assert(w==640 and h==480)
   local rows={};for y=258,338 do rows[#rows+1]=raw:sub(4*(y*w+330)+1,4*(y*w+468))end
   return table.concat(rows)
  end
  local beforeActions=action_pane()
  key_until('Return','lamp-actions',function()return action_pane()~=beforeActions end)
  key_until('Return','lamp-first-action',function()
   return mem:read_i16(actor+2)==11 and mem:read_i16(world-0xd8a8)==13 and mem:read_i16(actor+0x3e)==287
  end,function()
   -- The original paints the restored scene progressively. Require the bottom
   -- of the room and the actual message ink, not only its first restored row.
   return pixels({{400,300,0x71584a}}) and
    (pixels({{266,316,0xe2c7ae},{374,324,0xe2c7ae},{313,326,0xe2c7ae}}) or
     pixels({{266,332,0xe2c7ae},{374,340,0xe2c7ae},{313,342,0xe2c7ae}}))
  end)
  assert(mem:read_i16(actor+2)==11 and mem:read_i16(world-0xd8a8)==13 and mem:read_i16(actor+0x3e)==287,'lamp Use animation and selected object')
  mac.wait(120)
  assert(mem:read_i16(actor+0x3e)==287 and mem:read_i16(actor+0x52)==1,'empty lamp stance')
  report('lamp-feedback')
  mac.key_down('Down Arrow')
  assert(mac.wait_for('move after lamp Use',function()return mem:read_i16(actor+0x20)>=-3500 end,1200))
  mac.key_up('Down Arrow');mac.wait(90)
  assert(mem:read_i16(actor+0x3e)==287 and mem:read_i16(actor+0x52)==1,'lamp stance after movement')
  report('hallway-session-lamp-use-complete')
  mac.key_down('o');mac.wait(120);mac.key_up('o')
  assert(mac.wait_for('Open/Search walking stance',function()return mem:read_i16(actor+2)==12 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('walking-mode')
  move('Down Arrow','back',function()return mem:read_i16(actor+0x20)>=1000 end)
  move('Left Arrow','east',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<512 end)
  move('Up Arrow','partition-side',function()return mem:read_i16(actor+0x1c)>=4100 end)
  move('Left Arrow','south',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<768 end)
  move('Up Arrow','stair-opening',function()return mem:read_i16(actor+0x20)>=3600 end)
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
  print('PASS original lamp Use, stairs and first-floor hallway')
  move('Up Arrow','hallway-room5-line',function()return mem:read_i16(actor+0x1c)<=3400 end)
  align('x',2720,2900,false)
  move('Right Arrow','hallway-south',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<=528 end)
  move('Up Arrow','room5-door-approach',function()return mem:read_i16(actor+0x20)>=200 end)
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30)
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('room5-open')
  mac.key_down('Up Arrow')
  local entered=mac.wait_for('room5 entrance',function()return mem:read_i16(actor+0x30)==5 and mem:read_i16(actor+0x2e)==1 end,1800);mac.key_up('Up Arrow')
  if not entered then report('FAIL-room5-entry')end;assert(entered,'room5 entry')
  assert(mac.wait_for('room5 manual idle',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('first-floor-room5')
  print('PASS original southern first-floor room5 manual gameplay')
  if os.getenv('AITD_CIRCUIT_STOP_AT_ROOM5')=='1' then
   activity.finish();print('PASS original first-room audio route');dbg:command('quit');return
  end
  report('room5-encounter-start')
  assert(mac.wait_for('Fight input gate',function()return mem:read_i16(world-0xd864)==1 end,1200))
  mac.key_down('f');mac.wait(120);mac.key_up('f');mac.wait(30)
  assert(mem:read_i16(vars+180)==16,'room5 actual Fight choice');report('room5-fight-selected')
  move('Up Arrow','room5-clear-door',function()return mem:read_i16(actor+0x20)>=-1200 end)
  move('Left Arrow','room5-east',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<=272 end)
  move('Up Arrow','room5-front-x',function()return mem:read_i16(actor+0x1c)>=-1600 end)
  move('Right Arrow','room5-south',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<=528 end)
  move('Up Arrow','room5-front-z',function()return mem:read_i16(actor+0x20)>=-200 end)
  move('Right Arrow','room5-west',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=752 and b<=784 end)
  local npcSlot=mem:read_i16(objects+62*52);assert(npcSlot>=0,'natural room5 actor62');local npc=world-0xb292+npcSlot*160
  mac.key_down('Up Arrow')
  local active=mac.wait_for('room5 enemy activation or approach',function()return mem:read_i16(npc+0x34)==84 or mem:read_i16(actor+0x1c)<=-1650 end,1800)
  mac.key_up('Up Arrow');assert(active,'bounded room5 approach')
  assert(mac.wait_for('approach released',function()return mem:read_i16(actor+0x3e)==4 end,1800));mac.wait(30);report('room5-before-kicks')
  move('Right Arrow','room5-north',function()local b=mem:read_i16(actor+0x2a)&1023;return b<=16 or b>=1008 end)
  move('Up Arrow','room5-near-enemy',function()return mem:read_i16(actor+0x20)<=-650 or mem:read_i16(vars+42)<20 end)
  local won=false
  for attempt=1,32 do
   if mem:read_i16(objects+62*52)<0 then won=true;break end
   local dx=mem:read_i16(npc+0x1c)-mem:read_i16(actor+0x1c)
   local dz=mem:read_i16(npc+0x20)-mem:read_i16(actor+0x20)
   local target=math.abs(dx)>math.abs(dz) and (dx>0 and 256 or 768) or (dz>0 and 512 or 0)
   local delta=(target-mem:read_i16(actor+0x2a))&1023
   if delta>16 and delta<1008 then
    local turn=delta>512 and 'Left Arrow' or 'Right Arrow'
    mac.key_down(turn)
    local aimed=mac.wait_for('room5 face enemy',function()local d=(target-mem:read_i16(actor+0x2a))&1023;return d<=16 or d>=1008 end,1800)
    mac.key_up(turn);assert(aimed,'room5 enemy turn');mac.wait(30)
    print(string.format('ROOM5_AIM tick=%d target=%d beta=%d',mem:read_u32(0x16a),target,mem:read_i16(actor+0x2a)))
   end
   assert(mem:read_i16(vars+42)>0,'living observer hero')
   local kick=false
   mac.key_down('Space');mac.key_down('Up Arrow')
   for tick=1,180 do
    if not kick and mem:read_i16(actor+0x3e)==262 then
     kick=true;print(string.format('ROOM5_KICK attempt=%d tick=%d animation=262',attempt,mem:read_u32(0x16a)))
    end
    mac.wait(1)
   end
   mac.key_up('Space');mac.key_up('Up Arrow')
   assert(mac.wait_for('room5 kick release',function()return mem:read_i16(actor+0x3e)==4 or mem:read_i16(vars+42)<=0 end,1800));mac.wait(30)
   print(string.format('ROOM5_ENEMY attempt=%d object=%d body=%d life=%d animation=%d room=%d x=%d z=%d',attempt,mem:read_i16(npc),mem:read_i16(npc+2),mem:read_i16(npc+0x34),mem:read_i16(npc+0x3e),mem:read_i16(npc+0x30),mem:read_i16(npc+0x1c),mem:read_i16(npc+0x20)))
   report('room5-kick-'..attempt)
  end
  assert(won and mem:read_i16(objects+62*52)<0 and mem:read_i16(vars+114)<=0 and mem:read_i16(vars+40)==0 and mem:read_i16(vars+42)>0,'room5 actual victory and living hero')
  assert(mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1,'room5 restored manual gameplay')
  report('room5-combat-result')
  print('PASS original room5 encounter: natural enemy, Fight, aiming, damage, death/removal and living manual gameplay')
  mac.key_down('o');mac.wait(120);mac.key_up('o')
  assert(mac.wait_for('actual return Open/Search',function()return mem:read_i16(vars+180)==64 end,1200));mac.wait(30);report('return-open-mode')
  face(0,'wardrobe-north')
  move('Up Arrow','wardrobe-z',function()return mem:read_i16(actor+0x20)<=0 end)
  align('z',-280,-100,false)
  face(768,'wardrobe-west')
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('wardrobe-search-after-combat')
  local count=mem:read_i16(world-0xd8a6)
  report('wardrobe-return')
  print('WARDROBE inventory-before='..count..' after='..mem:read_i16(world-0xd8a6))
  face(512,'room4-door-south')
  move('Up Arrow','room4-door-z',function()return mem:read_i16(actor+0x20)>=600 end)
  align('z',650,850,true)
  face(768,'room4-door-west')
  move('Up Arrow','entered-room4',function()return mem:read_i16(actor+0x30)==4 end)
  assert(mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x52)==1,'actual room4 living manual')
  report('room4-manual')
  face(768,'room4-center-west')
  move('Up Arrow','room4-center-x',function()return mem:read_i16(actor+0x1c)<=100 end)
  align('x',-200,100,false)
  face(0,'room4-exit-north')
  move('Up Arrow','room4-exit-z',function()return mem:read_i16(actor+0x30)==1 or mem:read_i16(actor+0x20)<=-1600 end)
  if mem:read_i16(actor+0x30)==4 then
   mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('room4-hall-door-open')
   move('Up Arrow','room4-hallway',function()return mem:read_i16(actor+0x30)==1 end)
  end
  assert(mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x1c)<1300,'actual hallway west of gap')
  report('hallway-west-side')
  face(768,'room3-door-west')
  move('Up Arrow','room3-door-x',function()return mem:read_i16(actor+0x1c)<=-650 end)
  align('x',-900,-700,false)
  face(0,'room3-door-north')
  move('Up Arrow','room3-door-z',function()return mem:read_i16(actor+0x30)==3 or mem:read_i16(actor+0x20)<=-850 end)
  if mem:read_i16(actor+0x30)==1 then
   mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120);report('room3-door-open')
   move('Up Arrow','entered-room3',function()return mem:read_i16(actor+0x30)==3 end)
  end
  assert(mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x52)==1,'living manual room3')
  else
   assert(lamp()==0x8609 and mem:read_i16(world-0xd8a6)==2 and
    mem:read_i16(world-0xd8a4)==2 and mem:read_i16(world-0xd8a2)==13 and mem:read_i16(world-0xd8a8)==2,
    'checkpoint Actions/lamp inventory')
   assert(mem:read_i16(objects+62*52)==-1 and mem:read_i16(vars+114)<=0 and mem:read_i16(vars+40)==0,
    'checkpoint completed room5 death')
   assert(mem:read_i16(objects+35*52)==-1 and mem:read_i16(vars+80)==10 and mem:read_i16(vars+180)==64,
    'checkpoint before bedroom encounter in Open/Search')
   report('loaded-checkpoint')
  end
  report('room3-manual')
  local cycle=0;local originalReport=report
  if repeatCircuit then report=function(label)originalReport('cycle-'..cycle..'-'..label)end end
  repeat
   cycle=cycle+1;assert(cycle<=30,'bounded circuit count')
   report('cycle-start')
  face(512,'circuit-bathroom-south')
  move('Up Arrow','circuit-bathroom-hallway',function()return mem:read_i16(actor+0x30)==1 end)
  move('Up Arrow','circuit-west-hall-z',function()return mem:read_i16(actor+0x20)>=0 end)
  face(256,'circuit-west-hall-east')
  move('Up Arrow','circuit-room4-door-x',function()return mem:read_i16(actor+0x1c)>=200 end)
  align('x',100,500,true)
  face(512,'circuit-room4-south')
  move('Up Arrow','circuit-enter-room4',function()return mem:read_i16(actor+0x30)==4 end)
  move('Up Arrow','circuit-room4-z',function()return mem:read_i16(actor+0x20)>=650 end)
  -- Centre the real doorway: edge alignment can drift into its north frame.
  align('z',900,1050,true)
  face(256,'circuit-room5-east')
  move('Up Arrow','circuit-enter-room5',function()return mem:read_i16(actor+0x30)==5 end)
  move('Up Arrow','circuit-clear-room5-west-door',function()return mem:read_i16(actor+0x1c)>=-1800 end)
  align('x',-1700,-1550,true)
  face(0,'circuit-room5-north')
  move('Up Arrow','circuit-room5-exit-z',function()return mem:read_i16(actor+0x20)<=-1500 end)
  face(256,'circuit-room5-door-east')
  align('x',-2400,-2200,true)
  face(0,'circuit-room5-door-north')
  mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120)
  move('Up Arrow','circuit-east-hallway',function()return mem:read_i16(actor+0x30)==1 end)
  move('Up Arrow','circuit-bedroom-door-z',function()return mem:read_i16(actor+0x30)==2 or mem:read_i16(actor+0x20)<=-850 end)
  if mem:read_i16(actor+0x30)==1 then
   mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120)
   move('Up Arrow','circuit-bedroom',function()return mem:read_i16(actor+0x30)==2 end)
  end
  move('Up Arrow','circuit-bedroom-north',function()return mem:read_i16(actor+0x20)<=800 end)
  if not repeatCircuit or mem:read_i16(vars+80)>0 then
  assert(mac.wait_for('bedroom natural enemy',function()return mem:read_i16(objects+35*52)>=0 end,1200),'bedroom actual enemy spawn')
  mac.key_down('f');local selectedFight=mac.wait_for('bedroom actual Fight',function()return mem:read_i16(vars+180)==16 end,1200);mac.key_up('f');assert(selectedFight,'bedroom Fight');mac.wait(30);report('circuit-bedroom-fight')
  face(512,'circuit-bedroom-south')
  move('Up Arrow','circuit-bedroom-encounter-line',function()
   local slot=mem:read_i16(objects+35*52)
   return mem:read_i16(actor+0x20)>=900 or (slot>=0 and mem:read_i16(world-0xb292+slot*160+0x30)==2)
  end)
  align('z',1200,1380,true)
  face(768,'circuit-bedroom-door-west')
  align('x',600,800,false)
  face(512,'circuit-bedroom-door-south')
  mac.key_down('f');assert(mac.wait_for('bedroom Fight before doorway',function()return mem:read_i16(vars+180)==16 end,1200));mac.key_up('f');mac.wait(30);report('circuit-bedroom-before-reopen')
  mac.key_down('Up Arrow')
  local bedroomOpened=mac.wait_for('bedroom real Fight doorway',function()return mem:read_i16(vars+60)==1 or mem:read_i16(vars+42)<=0 end,1800)
  mac.key_up('Up Arrow');assert(bedroomOpened and mem:read_i16(vars+42)>0 and mem:read_i16(vars+60)==1,'actual Fight doorway')
  assert(mac.wait_for('bedroom open release',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1200));mac.wait(30);report('circuit-bedroom-reopened')
  local bedroomWon=false
  for attempt=1,32 do
   if mem:read_i16(vars+80)<=0 then
    assert(mac.wait_for('bedroom enemy removal',function()return mem:read_i16(objects+35*52)<0 and mem:read_i16(vars+40)==0 end,1800),'bedroom actual removal');bedroomWon=true;break
   end
   local slot=mem:read_i16(objects+35*52);assert(slot>=0 and slot<50,'bedroom live enemy slot')
   local npc=world-0xb292+slot*160
   if mem:read_i16(npc+0x30)==mem:read_i16(actor+0x30) then
    local dx=mem:read_i16(npc+0x1c)-mem:read_i16(actor+0x1c)
    local dz=mem:read_i16(npc+0x20)-mem:read_i16(actor+0x20)
    face(math.abs(dx)>math.abs(dz) and (dx>0 and 256 or 768) or (dz>0 and 512 or 0),'circuit-bedroom-aim-'..attempt)
   end
   local pressed=mem:read_u32(0x16a);mac.key_down('Space');mac.key_down('Up Arrow')
   local kicked=mac.wait_for('bedroom kick or interrupted press',function()return mem:read_i16(actor+0x3e)==262 end,180)
   print(string.format('BEDROOM_COMBAT attempt=%d tick=%d kick=%d',attempt,mem:read_u32(0x16a),kicked and 1 or 0))
   local remaining=180-(mem:read_u32(0x16a)-pressed);if remaining>0 then mac.wait(remaining)end
   mac.key_up('Up Arrow');mac.key_up('Space')
   assert(mac.wait_for('bedroom attack released',function()return mem:read_i16(actor+0x3e)==4 or mem:read_i16(vars+42)<=0 end,1800),'bedroom attack release')
   assert(mem:read_i16(vars+42)>0 and mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12,'living bedroom hero');mac.wait(30);report('circuit-bedroom-kick-'..attempt)
  end
  assert(bedroomWon and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1,'bedroom actual victory/manual control');report('circuit-bedroom-victory')
  else
   assert(mem:read_i16(objects+35*52)<0 and mem:read_i16(vars+80)<=0 and mem:read_i16(vars+40)==0,'bedroom enemy remains removed')
   report('circuit-bedroom-already-clear')
  end
  mac.key_down('o');mac.wait(120);mac.key_up('o');assert(mac.wait_for('bedroom actual Open/Search',function()return mem:read_i16(vars+180)==64 end,1200),'bedroom return action')
  face(512,'circuit-bedroom-return-south')
  move('Up Arrow','circuit-bedroom-door-return',function()return mem:read_i16(actor+0x30)==1 or mem:read_i16(actor+0x20)>=1600 end)
  if mem:read_i16(actor+0x30)==2 then
   mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120)
   move('Up Arrow','circuit-bedroom-hallway',function()return mem:read_i16(actor+0x30)==1 end)
  end
  face(256,'circuit-return-hall-door-east')
  align('x',2800,2900,true)
  face(512,'circuit-return-hall-door-south')
  move('Up Arrow','circuit-return-room5',function()return mem:read_i16(actor+0x30)==5 end)
  move('Up Arrow','circuit-return-room5-north-door-clear',function()return mem:read_i16(actor+0x20)>=-1200 end)
  face(256,'circuit-return-room5-east')
  move('Up Arrow','circuit-return-room5-clear-door',function()return mem:read_i16(actor+0x1c)>=-1800 end)
  align('x',-1700,-1550,true)
  face(512,'circuit-return-room5-south')
  move('Up Arrow','circuit-return-room5-z',function()return mem:read_i16(actor+0x20)>=650 end)
  align('z',650,850,true)
  face(768,'circuit-return-room4-west')
  move('Up Arrow','circuit-return-room4',function()return mem:read_i16(actor+0x30)==4 end)
  move('Up Arrow','circuit-return-room4-x',function()return mem:read_i16(actor+0x1c)<=100 end)
  align('x',-200,100,false)
  face(0,'circuit-return-hall-north')
  move('Up Arrow','circuit-return-hall-z',function()return mem:read_i16(actor+0x30)==1 or mem:read_i16(actor+0x20)<=-1600 end)
  if mem:read_i16(actor+0x30)==4 then
   mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120)
   move('Up Arrow','circuit-return-west-hall',function()return mem:read_i16(actor+0x30)==1 end)
  end
  assert(mem:read_i16(actor+0x1c)<1300 and mem:read_i16(actor+0x2e)==1,'completed real western hallway circuit')
  report('circuit-complete')
  if repeatCircuit then
  face(0,'circuit-repeat-hall-north')
  move('Up Arrow','circuit-repeat-hall-clear-door',function()return mem:read_i16(actor+0x30)==1 and mem:read_i16(actor+0x20)<=0 end)
  align('z',-150,0,false)
  face(768,'circuit-repeat-bathroom-west')
  move('Up Arrow','circuit-repeat-bathroom-x',function()return mem:read_i16(actor+0x1c)<=-650 end)
  align('x',-900,-700,false)
  face(0,'circuit-repeat-bathroom-north')
  move('Up Arrow','circuit-repeat-bathroom-z',function()return mem:read_i16(actor+0x30)==3 or mem:read_i16(actor+0x20)<=-850 end)
  if mem:read_i16(actor+0x30)==1 then
   mac.key_down('Space');mac.wait(120);mac.key_up('Space');mac.wait(120)
   move('Up Arrow','circuit-repeat-bathroom-entry',function()return mem:read_i16(actor+0x30)==3 end)
  end
  assert(mem:read_i16(actor+0x30)==3 and mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 and mem:read_i16(vars+42)>0,'living bathroom cycle return')
  report('circuit-repeat-bathroom-manual')
   print(string.format('CIRCUIT_CYCLE cycle=%d tick=%d active=%d hp=%d',cycle,mem:read_u32(0x16a),activity.active_ticks(),mem:read_i16(vars+42)))
  end
  until not repeatCircuit or activity.active_ticks()>=36000
  if repeatCircuit then assert(activity.active_ticks()>=36000,'continuous ten-minute active gate')end
  activity.finish()
  print(repeatCircuit and 'PASS original continuous firstfloor tenminute circuit' or 'PASS original connected firstfloor circuit');dbg:command('quit')

 end)
 if not ok then print('FAIL '..tostring(err));activity.finish();manager.machine:exit()end
end)
dbg.execution_state='run'
