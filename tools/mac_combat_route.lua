local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local fightPC,fightSeenPC,fightWorld,fightAccepted=nil,nil,nil,false
emu.register_periodic(function()
 local debugger=manager.machine.debugger
 if fightPC and debugger.execution_state=='stop' and (cpu.state.PC.value&0xffffff)==fightPC then
  fightAccepted=true;print('FIRSTFLOOR_FIGHT_ACCEPTED tick='..mem:read_u32(0x16a));debugger.execution_state='run'
 elseif fightSeenPC and debugger.execution_state=='stop' and (cpu.state.PC.value&0xffffff)==fightSeenPC then
  print(string.format('FIGHT_KEY_COMPARE tick=%d d7=%d gate=%d char=%d',mem:read_u32(0x16a),cpu.state.D7.value,mem:read_i16(fightWorld-0xd864),mem:read_i16(fightWorld-0xd84c)));debugger.execution_state='run'
 end
end)
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
 local f=assert(io.open('tmp/m3-combat/key-session-lamp-use-mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
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
   local f=assert(io.open('tmp/m3-combat/key-session-lamp-use-'..label..'-a5.bin','wb'));for i=0,75615 do f:write(string.char(mem:read_u8(world-75616+i)))end;f:close()
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
  print('PASS original lamp Use, hallway and bedroom key pickup')
  local vars=ptr(world-0xcbcc)
  local function enemy(label)
   local idx=mem:read_i16(objects+35*52);local e=idx>=0 and world-0xb292+idx*160 or nil
   print(string.format('COMBAT_STATE phase=%s tick=%d var20=%d var21=%d var30=%d var31=%d var40=%d var24=%d var90=%d npc=%d npcFloor=%d npcRoom=%d npcAnim=%d npcLife=%d npcX=%d npcZ=%d',label,mem:read_u32(0x16a),mem:read_i16(vars+40),mem:read_i16(vars+42),mem:read_i16(vars+60),mem:read_i16(vars+62),mem:read_i16(vars+80),mem:read_i16(vars+48),mem:read_i16(vars+180),idx,e and mem:read_i16(e+0x2e) or -1,e and mem:read_i16(e+0x30) or -1,e and mem:read_i16(e+0x3e) or -1,e and mem:read_i16(e+0x34) or -1,e and mem:read_i16(e+0x1c) or 0,e and mem:read_i16(e+0x20) or 0))
  end
  enemy('closed-door');report('closed-door')
  assert(mem:read_i16(vars+60)==0 and mem:read_i16(vars+62)==1 and mem:read_i16(objects+35*52)>=0,'natural key-route door closure and enemy spawn')
  move('Right Arrow','combat-east',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<=272 end)
  move('Up Arrow','combat-x-line',function()return mem:read_i16(actor+0x1c)>=600 end)
  move('Left Arrow','combat-south',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<=528 end)
  move('Up Arrow','combat-z-line',function()return mem:read_i16(actor+0x20)>=900 end)
  align('z',1200,1380,true)
  move('Left Arrow','combat-west',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=752 and b<=784 end)
  move('Up Arrow','combat-door-x',function()return mem:read_i16(actor+0x1c)<=850 end)
  align('x',600,800,false)
  report('door-center-aligned')
  move('Right Arrow','bedroom-facing-door',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=496 and b<=528 end)
  key('Return');mac.wait(180);key('Return');mac.wait(180);report('close-action-menu')
  local function selectAction(lo,hi,label)
   local function selected()
    local raw,w,h=screen:pixels();local white=0
    for y=lo,hi do for x=365,445 do if(string.unpack('I4',raw,4*(y*w+x)+1)&0xffffff)==0xffffff then white=white+1 end end end
    return white>10
   end
   mac.key_down('Down Arrow');local reached=mac.wait_for(label,selected,1200);mac.key_up('Down Arrow');mac.wait(120);report(label);assert(reached,label)
  end
  selectAction(278,292,'open-action-selected')
  selectAction(295,309,'close-selected')
  key('Return');mac.wait(120);print('CLOSE_SELECTED var90='..mem:read_i16(vars+180));assert(mem:read_i16(vars+180)==128,'actual Close mode')
  local meta=dofile('tmp/mac-trap-map.lua');local dark
  for i,j in ipairs(meta.jt)do if j[1]==4 then dark=(mem:read_u32(world+36+(i-1)*8)&0xffffff)-j[2];break end end
  assert(dark and mem:read_u32(dark+0x599a)==0x42272f0c,'original Fight accepted branch bytes')
  fightPC=dark+0x599a;fightSeenPC=dark+0x58e8;fightWorld=world
  assert(mem:read_u32(fightSeenPC)==0x0c790066,"Fight key compare bytes")
  for _,alias in ipairs({0,0x80000000})do cpu.debug:bpset(fightPC|alias,'','');cpu.debug:bpset(fightSeenPC|alias,string.format('w@0x%x==0x66 || w@0x%x==0x46',world-0xd84c,world-0xd84c),'')end
  assert(mac.wait_for('input gate enabled',function()return mem:read_i16(world-0xd864)==1 end,1800));mac.key_down('f');assert(mac.wait_for('Fight accepted',function()return fightAccepted end,1200));mac.key_up('f');mac.wait(30);enemy('fight-selected-before-door')
  assert(mem:read_i16(vars+180)==16,'Fight selected before encounter')
  print('DOOR_GATE var24='..mem:read_i16(vars+48)..' var90='..mem:read_i16(vars+180))
  local doorSlot=mem:read_i16(objects+33*52);local doorActor=world-0xb292+doorSlot*160
  print(string.format('DOOR_BOX slot=%d x1=%d x2=%d z1=%d z2=%d life=%d',doorSlot,mem:read_i16(doorActor+8),mem:read_i16(doorActor+10),mem:read_i16(doorActor+16),mem:read_i16(doorActor+18),mem:read_i16(doorActor+52)))
  mac.key_down('Up Arrow');local opened=mac.wait_for('actual door reopen',function()return mem:read_i16(vars+60)==1 end,1800);mac.key_up('Up Arrow');enemy('reopened-door');report('reopened-door');assert(opened,'door reopen')
  assert(mac.wait_for('open released',function()return mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1800));mac.wait(30)
  enemy('before-fight')
  print('PLAYER_VAR21 before-fight='..mem:read_i16(vars+42))
  report('first-floor-fight')
  mac.key_down('Space');mac.key_down('Up Arrow')
  assert(mac.wait_for('actual first-floor kick',function()return mem:read_i16(actor+0x3e)==262 end,1200));report('first-floor-kick')
  mac.wait(120);mac.key_up('Up Arrow');mac.key_up('Space')
  assert(mac.wait_for('kick released',function()return mem:read_i16(actor+0x3e)==4 end,1800));report('kick-released')
  local seenActive=true;local won=false;local turnTest=false
  for attempt=1,31 do
   local idx=mem:read_i16(objects+35*52)
   if idx>=0 then seenActive=true end
   if seenActive and idx<0 and mem:read_i16(vars+80)<=0 and mem:read_i16(vars+40)==0 then won=true;break end
   assert(mem:read_i16(vars+42)>0,'hero died during combat')
   enemy('attack-'..attempt)
   if mem:read_i16(vars+80)<=0 then
    assert(mac.wait_for('enemy death completes',function()return mem:read_i16(objects+35*52)<0 end,1800))
   else
    local npc=world-0xb292+idx*160
    if mem:read_i16(npc+0x2e)==mem:read_i16(actor+0x2e) and mem:read_i16(npc+0x30)==mem:read_i16(actor+0x30) then
     if not turnTest then
      turnTest=true
      local delta=(768-mem:read_i16(actor+0x2a))&1023
      if delta>16 and delta<1008 then
       local turn=delta>512 and 'Left Arrow' or 'Right Arrow'
       mac.key_down(turn)
       local turned=mac.wait_for('deliberate combat turn',function()local d=(768-mem:read_i16(actor+0x2a))&1023;return d<=16 or d>=1008 end,1800)
       mac.key_up(turn);assert(turned,'deliberate turn');mac.wait(30)
       print(string.format('COMBAT_TURN tick=%d target=768 beta=%d',mem:read_u32(0x16a),mem:read_i16(actor+0x2a)))
      end
     end
     local dx=mem:read_i16(npc+0x1c)-mem:read_i16(actor+0x1c)
     local dz=mem:read_i16(npc+0x20)-mem:read_i16(actor+0x20)
     local target=math.abs(dx)>math.abs(dz) and (dx>0 and 256 or 768) or (dz>0 and 512 or 0)
     local delta=(target-mem:read_i16(actor+0x2a))&1023
     if delta>16 and delta<1008 then
      local turn=delta>512 and 'Left Arrow' or 'Right Arrow'
      mac.key_down(turn)
      local aimed=mac.wait_for('face enemy',function()local d=(target-mem:read_i16(actor+0x2a))&1023;return d<=16 or d>=1008 end,1800)
      mac.key_up(turn);assert(aimed,'enemy turn');mac.wait(30)
     end
     print(string.format('COMBAT_AIM tick=%d target=%d beta=%d',mem:read_u32(0x16a),target,mem:read_i16(actor+0x2a)))
    end
    report('before-attack-'..attempt)
    local pressed=mem:read_u32(0x16a)
    mac.key_down('Space');mac.key_down('Up Arrow')
    local kicked=mac.wait_for('aimed kick or interrupted press',function()return mem:read_i16(actor+0x3e)==262 end,180)
    print(string.format('COMBAT_PRESS tick=%d kick=%d',mem:read_u32(0x16a),kicked and 1 or 0))
    local remaining=180-(mem:read_u32(0x16a)-pressed)
    if remaining>0 then mac.wait(remaining)end
    mac.key_up('Up Arrow');mac.key_up('Space')
   end
   assert(mac.wait_for('attack released',function()return mem:read_i16(actor+0x3e)==4 or mem:read_i16(vars+42)<=0 end,1800));mac.wait(30)
  end
  enemy('combat-result');report('combat-observed')
  assert(seenActive and won and mem:read_i16(vars+42)>0 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1,'actual victory and living manual actor')
  print('PASS original bedroom encounter: spawned enemy, Close selection, Fight, damage, death and manual gameplay');dbg:command('quit')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
