-- Capture original colour-window construction geometry before any visibility calls.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'WINDOW GEOMETRY / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('WINDOW GEOMETRY / NO SEGMENT')
end
local app='Alone In The Dark';local condition=string.format('b@910==0x%x',#app)
for i=1,#app do condition=condition..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'WINDOW GEOMETRY / DISPATCHER BYTES')
 for _,site in ipairs({{0x1272,131},{0x109a,128}}) do
  local off,id=table.unpack(site)
  local prefix='tmp/window-geometry-reference-'..id
  local entered='temp0=sp+8;temp6='..base(9)..';'
  entered=entered..string.format('logerror "GEOM_ENTER id=%%X site=%%X opcode=%%X sp=%%X behind=%%X storage=%%X result=%%X\\n",w@(temp0+8),0x%x,w@(temp6+0x%x),temp0,d@temp0,d@(temp0+4),d@(temp0+0xa);',off,off)
  local returned='temp1=d@sp&0xffffff;temp2=d@(d@(temp1+2)&0xffffff)&0xffffff;'
  returned=returned..string.format('logerror "GEOM_RETURN id=%X sp=%%X expected=%%X window=%%X pm=%%X kind=%%X visible=%%X next=%%X\\n",sp,temp0+0xa,temp1,temp2,w@(temp1+0x6c),b@(temp1+0x6e),d@(temp1+0x90);',id)
  returned=returned..'save '..prefix..'-window.bin,temp1,0x9c;save '..prefix..'-pm.bin,temp2,0x32;'
  for name,offset in pairs({visibility=0x18,clip=0x1c,structure=0x72,content=0x76,update=0x7a}) do
   returned=returned..string.format('temp3=d@(d@(temp1+0x%x)&0xffffff)&0xffffff;',offset)..'save '..prefix..'-'..name..'.bin,temp3,w@temp3;'
  end
  if id==128 then returned=returned..'logerror "PASS original colour-window geometry calls=2\\n";quit' else returned=returned..'g' end
  entered=entered..string.format('bpset temp6+0x%x,1,{',off+2)..returned..'};g'
  cpu.debug:bpset(0xdd60,condition..' && w@(d@(sp+2))==0xaa46 && (d@(sp+2)&0xffffff)=='..base(9)..string.format('+0x%x',off),entered)
 end
 armed=true;print('ARM colour-window geometry dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'WINDOW GEOMETRY / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'WINDOW GEOMETRY / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('WINDOW GEOMETRY / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
