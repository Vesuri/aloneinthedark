local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger);local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local meta=dofile('tmp/mac-trap-map.lua')
local readingPC,currentPage,lastPage,pageVisits
pageVisits=0
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
 local f=assert(io.open('tmp/m3-explore/book-session-mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
 print('DIALOG_STATE '..name..' ticks='..mem:read_u32(0x16a))
end
local function state(name,fn)
 assert(mac.wait_for(name,fn,1800),'DIALOG STATE '..name);capture(name)
end
-- Read-only observer of the original reading input wait. Normal keys advance it.
emu.register_periodic(function()
 if not readingPC or dbg.execution_state~='stop' then return end
 assert((cpu.state.PC.value&0xffffff)==readingPC,'reading observer PC')
 currentPage=cpu.state.D3.value&65535;lastPage=(cpu.state.D5.value&65535)~=0
 pageVisits=pageVisits+1
 print(string.format('BOOK_PAGE visit=%d page=%d last=%s tick=%d',pageVisits,currentPage,tostring(lastPage),mem:read_u32(0x16a)))
 dbg:command('bpclear');cpu.debug:bpset(readingPC,'d3!='..currentPage,'');dbg.execution_state='run'
end)
local function armReading()
 for i,j in ipairs(meta.jt)do if j[1]==12 then
  local entry=ptr(0x904)+32+(i-1)*8
  assert(mem:read_u16(entry+2)==0x4ef9,'loaded Dan1')
  readingPC=ptr(entry+4)-j[2]+0x4870
  assert(mem:read_u32(readingPC)==0x4eba199c,'original reading wait bytes')
  cpu.debug:bpset(readingPC,'1','');return
 end end
 error('missing reading segment')
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
   local f=assert(io.open('tmp/m3-explore/book-session-'..label..'-a5.bin','wb'));for i=0,75615 do f:write(string.char(mem:read_u8(world-75616+i)))end;f:close()
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
  local function move(name,label,fn)
   mac.key_down(name);local moved=mac.wait_for(label,fn,1200);mac.key_up(name)
   if not moved then report('FAIL-'..label)end;assert(moved,label)
   assert(mac.wait_for('released '..label,function()return mem:read_i16(actor+0x3e)==4 end,1200));mac.wait(30);report(label)
  end
  move('Down Arrow','book-approach-clear-z',function()return mem:read_i16(actor+0x20)>=-1800 end)
  move('Right Arrow','book-west',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=752 and b<=784 end)
  move('Up Arrow','book-x',function()return mem:read_i16(actor+0x1c)<=-1600 end)
  move('Left Arrow','book-north',function()local b=mem:read_i16(actor+0x2a)&1023;return b<=16 or b>=1008 end)
  move('Up Arrow','book-search-approach',function()return mem:read_i16(actor+0x20)<=-3100 end)
  move('Left Arrow','book-facing-east',function()local b=mem:read_i16(actor+0x2a)&1023;return b>=240 and b<=272 end)
  move('Up Arrow','book-west-contact',function()return mem:read_i16(actor+0x1c)>=-1650 end)
  mac.key_down('o');mac.wait(120);mac.key_up('o');mac.wait(30)
  mac.key_down('Space');local found=mac.wait_for('book actual Find',function()return pixels({{195,185,0xd6ae71},{200,190,0x84653b},{440,310,0xab844f}})end,1800);mac.key_up('Space');mac.wait(300);report('book-search');assert(found,'book Find not reached')
  print('BOOK_STATE flags='..mem:read_u16(objects+12*52+12)..' body='..mem:read_i16(objects+12*52+8)..' name='..mem:read_i16(objects+12*52+10))
  assert(mem:read_u16(objects+12*52+12)==0x604,'original unplaced book flags during Find')
  key('Return');assert(mac.wait_for('book taken',function()return mem:read_u16(objects+12*52+12)==0x8604 and mem:read_i16(world-0xd8a6)==3 end,1800));mac.wait(90);report('book-taken')
  assert(mac.wait_for('book pickup visibly returned gameplay',function()return not pixels({{195,185,0xd6ae71},{200,190,0x84653b},{440,310,0xab844f}}) and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1800));mac.wait(60);report('book-pickup-complete')
  key('Return');mac.wait(180)
  local function bookSelected()
   local raw,w,h=screen:pixels();local white=0
   for y=185,203 do for x=280,355 do if(string.unpack('I4',raw,4*(y*w+x)+1)&0xffffff)==0xffffff then white=white+1 end end end
   return white>10
  end
  mac.key_down('Down Arrow');local selected=mac.wait_for('actual book inventory highlight',bookSelected,1200);mac.key_up('Down Arrow')
  if not selected then report('FAIL-book-selection')end;assert(selected,'book selection');mac.wait(120);report('book-selected')
  key('Return');mac.wait(120);report('book-actions')
  armReading()
  key('Return');assert(mac.wait_for('book first reading page',function()return currentPage==0 end,1800));mac.wait(300);report('book-reading');assert(mem:read_i16(world-0xd868)==4,'actual Read action')
  key('Right Arrow');assert(mac.wait_for('book page1',function()return currentPage==1 end,1800));mac.wait(300);report('book-page1')
  key('Left Arrow');assert(mac.wait_for('book previous page',function()return currentPage==0 end,1800));mac.wait(300);report('book-previous-page')
  local completed=false
  for page=1,32 do
   if lastPage then
    key('Return');assert(mac.wait_for('book reading ended',function()return mem:read_i16(world-0xd868)==0 and mem:read_i16(objects+12*52+10)==550 end,1800));completed=true;break
   end
   key('Right Arrow');assert(mac.wait_for('book forward page '..page,function()return currentPage==page end,1800));mac.wait(300);report('book-forward-'..page)
  end
  assert(completed,'book page bound exceeded');dbg:command('bpclear');readingPC=nil;mac.wait(120)
  assert(mac.wait_for('book Read returned',function()return mem:read_i16(objects+12*52+10)==550 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1 end,1800));mac.wait(60);report('book-read-complete')
  print('PASS original book forward/backward pages, last-page Return and manual gameplay');dbg:command('quit')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
