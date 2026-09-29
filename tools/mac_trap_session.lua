-- Scripted reference route. Captures are inspected and the trap log is checked
-- separately; fixed waits are safety/settling intervals, never acceptance.
return function(mac,mem)
 local backspace
 for _,port in pairs(manager.machine.ioport.ports) do
  for name,_ in pairs(port.fields) do
   if name:find('Backspace') then backspace=name end
  end
 end
 assert(backspace,'SESSION / BACKSPACE KEY NOT FOUND')
 print('INPUT backspace='..backspace)
 -- Dan1+$5824..$5990 (original bytes checked): polling publishes key at
 -- A5-$11AF4 (Space=32 in the text/menu variant at +$5FBA), direction bits at A5-$11AF8, and action at A5-$11AF0.
 -- Wait for the original input routine to observe a key, rather than letting
 -- a host/emulated-frame delay masquerade as input acceptance during loading.
 local observed={Esc={0x11af4,3},Return={0x11af4,13},Space={0x11af4,32},
  ['Right Arrow']={0x11af8,8},['Left Arrow']={0x11af8,4},
  ['Up Arrow']={0x11af8,1},['Down Arrow']={0x11af8,2}}
 local screen
 for _,v in pairs(manager.machine.screens) do screen=v end
 assert(screen,'SESSION / NO SCREEN')
 -- Read-only state probes measured from native MAME captures, not port logic.
 local function pixels(points)
  -- MAME 0.289 pixel(x,y) disagrees with both its PNG and packed bitmap.
  -- The packed bitmap was byte-compared with the native 640x480 PNG.
  local raw,w,h=screen:pixels()
  assert(w==640 and h==480,'SESSION / UNEXPECTED SCREEN GEOMETRY')
  for _,p in ipairs(points) do
   if (string.unpack('I4',raw,4*(p[2]*w+p[1])+1)&0xffffff)~=p[3] then return false end
  end
  return true
 end
 local function menu() return pixels({{190,180,0x694f2a},{400,210,0},{200,345,0x9d7945}}) end
 local function slot() return pixels({{190,180,0x84653b},{400,210,0x81a1a1},{200,345,0}}) end
 local function room() return pixels({{180,160,0x814530},{290,245,0x7d6154},{400,300,0x71584a}}) end
 local function state(label,fn)
  local ok=mac.wait_for(label,fn,1800)
  if not ok then
   screen:snapshot('m0.2-failed-'..label..'.png')

  end
  assert(ok,'SESSION / STATE NOT REACHED '..label)
  print('STATE_VERIFIED '..label..' ticks='..mem:read_u32(0x16a))
 end
 local polled=false
 local dbg=manager.machine.debugger
 local function key(name,mods)
  local probe=polled and not mods and observed[name]
  for _,m in ipairs(mods or {}) do mac.key_down(m) end
  mac.wait(2)
  if probe then dbg:command(string.format('temp0=0;temp1=0x%x;temp3=0x%x',probe[2],probe[1])) end
  mac.key_down(name)
  if probe then
   local function count()
    dbg:command('printf "INPUT_COUNT=%X",temp0')
    return tonumber(dbg.consolelog[#dbg.consolelog]:match('INPUT_COUNT=(%x+)'),16) or 0
   end
   local tick=mem:read_u32(0x16a)
   assert(mac.wait_for(name..' consumed',function() return count()>0 end,1800),'INPUT / NOT CONSUMED '..name)
   print('INPUT_CONSUMED '..name..' ticks='..mem:read_u32(0x16a)..' delay='..(mem:read_u32(0x16a)-tick))
   dbg:command('temp3=0')
  else mac.wait(4) end
  mac.key_up(name)
  for _,m in ipairs(mods or {}) do mac.key_up(m) end
  mac.wait(10)
 end
 local function shot(name)
  print('CHECKPOINT '..name..' ticks='..mem:read_u32(0x16a));assert(not screen:snapshot('m0.2-'..name..'.png'),'SESSION / SNAPSHOT FAILED')
 end
 local function window320()
  local w=mem:read_u32(0x9d6)&0xffffff
  for _=1,32 do
   if w==0 or w>0x7fffff then return false end
   if mem:read_i16(w+22)-mem:read_i16(w+18)==320
    and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
   w=mem:read_u32(w+0x90)&0xffffff
  end
  return false
 end
 mac.wait(300)
 if not window320() then
  assert(mac.mouse_to(256,274),'SESSION / SIZE POINTER');mac.click(1)
 end
 assert(mac.wait_for('320x200 window',window320,1800),'SESSION / NO 320x200 WINDOW')
 mac.mouse_to(620,470)
 mac.wait(3000);shot('intro')
 key('Space');mac.wait(120);shot('main-menu')
 key('Return');mac.wait(720);shot('characters')
 key('Right Arrow');key('Return');mac.wait(240);shot('carnby-text')
 key('Return');mac.wait(180);shot('story-intro')
 key('Esc');mac.wait(900);state('attic',room);shot('attic');polled=true
 key('p');mac.wait(120);shot('paused');key('p');mac.wait(60)
 key('s');mac.wait(60);shot('effects-off');key('s');mac.wait(60)
 key('m');mac.wait(60);shot('music-off');key('m');mac.wait(60)
 key('Up Arrow');mac.wait(60)
 -- The engine polls Escape repeatedly; a consumed event alone does not prove
 -- the menu stayed open. Require a stable rendered menu before selecting Save.
 for attempt=1,3 do
  mac.key_down('Esc');mac.wait(30);mac.key_up('Esc');mac.wait(120)
  if menu() then break end
  print('MENU_RETRY '..attempt)
 end
 state('escape-menu',menu);shot('escape-menu')
 key('Down Arrow');key('Return');mac.wait(240);state('engine-save',slot);shot('engine-save');polled=false
 -- The first save slot is selected. Replace its current name deterministically.
 for _=1,31 do key(backspace) end
 mac.type('m0log');mac.wait(30);key('Return');mac.wait(240);state('saved-room',room);shot('saved')
 key('s',{mac.CMD});mac.wait(180);state('file-save',slot);shot('file-save')
 key('Return');mac.wait(240)
 key('o',{mac.CMD});mac.wait(240);state('file-open',slot);shot('file-open')
 key('Return');mac.wait(900);state('loaded-room',room);shot('loaded')
 key('q',{mac.CMD})
 assert(mac.wait_for('Finder after quit',function() return mac.frontmost()=='Finder' end,1800),'SESSION / QUIT FAILED')
 mac.wait(300);shot('finder')
 print('SESSION complete; validate state captures and trap report before accepting M0.2')
 manager.machine:exit()
end
