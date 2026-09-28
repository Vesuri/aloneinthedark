-- Dump the original game's indexed screen and CLUT beside a same-frame PNG.
-- Handle/master pointers are tagged in 24-bit mode; video baseAddr is a full
-- NuBus address and must NOT be truncated to 24 bits.
local mac=dofile(os.getenv('AITD_MAC_LIB') or 'tools/mame_mac_input.lua')
local mem=manager.machine.devices[':maincpu'].spaces.program
local function ptr(a) return mem:read_u32(a)&0xffffff end
local out=os.getenv('AITD_FB_OUT') or 'ref/mame/snap/fb'
local screen
for _,s in pairs(manager.machine.screens) do screen=s end
local function pixmap()
 local gd=ptr(ptr(0x8a4))
 return ptr(ptr(gd+22))
end
local function palette(pm)
 local ct=ptr(ptr(pm+42))
 assert(ct~=0,'FRAMEBUFFER / NO CLUT')
 return ct
end
local function capture()
 local pm=pixmap()
 local base=mem:read_u32(pm)
 local rowbytes=mem:read_u16(pm+4)&0x3fff
 local top,left,bottom,right=mem:read_i16(pm+6),mem:read_i16(pm+8),mem:read_i16(pm+10),mem:read_i16(pm+12)
 local width,height=right-left,bottom-top
 local depth=mem:read_u16(pm+32)
 assert(width==640 and height==480 and depth==8,'FRAMEBUFFER / EXPECTED 640x480x8')
 assert(rowbytes>=width,'FRAMEBUFFER / INVALID STRIDE')
 local ct=palette(pm)
 local entries=mem:read_u16(ct+6)+1
 assert(entries==256,'FRAMEBUFFER / EXPECTED 256 COLOURS')
 local device=assert(manager.machine.palettes[':nb9:mdc48'],'FRAMEBUFFER / MDC48 PALETTE MISSING')
 assert(device.entries==256,'FRAMEBUFFER / MDC48 PALETTE SIZE')
 local pf=assert(io.open(out..'-hardware.clut','w'))
 for i=0,255 do
  local c=device:pen_color(i)
  pf:write(string.format('%d %d %d %d %d\n',i,i,((c>>16)&255)*257,((c>>8)&255)*257,(c&255)*257))
 end
 pf:close()
 local f=assert(io.open(out..'.clut','wb'))
 for i=0,entries-1 do
  local e=ct+8+i*8
  f:write(string.format('%d %d %d %d %d\n',i,mem:read_u16(e),mem:read_u16(e+2),mem:read_u16(e+4),mem:read_u16(e+6)))
 end
 f:close()
 f=assert(io.open(out..'.raw','wb'))
 for y=0,height-1 do
  local row={}
  for x=0,rowbytes-1 do row[#row+1]=string.char(mem:read_u8(base+y*rowbytes+x)) end
  f:write(table.concat(row))
 end
 f:close()
 -- screen:snapshot interprets relative paths under snapshot_directory.
 local path=assert(os.getenv('PWD'),'FRAMEBUFFER / PWD REQUIRED')..'/'..out..'-reference.png'
 if out:sub(1,1)=='/' then path=out..'-reference.png' end
 assert(not screen:snapshot(path),'FRAMEBUFFER / SNAPSHOT FAILED')
 f=assert(io.open(out..'.json','w'))
 f:write(string.format('{"width":%d,"height":%d,"rowbytes":%d,"bpp":%d,"base":%d,"frame":%d}\n',width,height,rowbytes,depth,base,mac.frames()))
 f:close()
 print(string.format('FRAMEBUFFER_CAPTURE width=%d height=%d rowbytes=%d bpp=%d base=%08X clut=%d frame=%d',width,height,rowbytes,depth,base,entries,mac.frames()))
end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'FRAMEBUFFER / LAUNCH FAILED')
  mac.wait(300)
  assert(mac.mouse_to(256,274),'FRAMEBUFFER / SIZE POINTER');mac.click(1)
  assert(mac.mouse_to(620,460),'FRAMEBUFFER / CURSOR PARK')
  -- Colour 20 is non-grey in original clut 128. Wait for palette activation,
  -- not just an arbitrary post-launch delay. The report checks all indices.
  assert(mac.wait_for('game palette',function()
   local pm=pixmap()
   if mem:read_u16(pm+32)~=8 then return false end
   local ct=palette(pm)
   local e=ct+8+20*8
   return mem:read_u16(ct+6)==255 and mem:read_u16(e+2)==41891
     and mem:read_u16(e+4)==32639 and mem:read_u16(e+6)==26471
  end,3600),'FRAMEBUFFER / GAME PALETTE NOT ACTIVE')
  local prefix=out
  local count=tonumber(os.getenv('AITD_FB_COUNT') or '1')
  for i=1,count do
   out=count==1 and prefix or prefix..'-'..i
   mac.wait(tonumber(os.getenv('AITD_FB_DELAY') or '900'))
   capture()
  end
 end)
 if not ok then print('FAIL framebuffer '..tostring(err)) end
 manager.machine:exit()
end)
