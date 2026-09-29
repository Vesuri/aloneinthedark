-- Observe original Core device selection before the second Times lookup. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DEVICE STARTUP / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]) end end
 error('DEVICE STARTUP / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@%x==%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local function dump(label,address,count)
 local format,args='',''
 for i=0,count-1 do format=format..'%08X';args=args..string.format(',d@((%s)+%x)',address,i*4) end
 return 'logerror "'..label..' seq=%X data='..format..'\\n",temp8'..args..';'
end
local armed=false
local consoleSeen=0
emu.register_frame_done(function()
 -- Retain console errors: malformed debugger actions otherwise look like hangs.
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL device debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DEVICE STARTUP / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local setup='temp6='..base(3)..';'
 local sites={{0x4b48,0xaa29,0,4},{0x4b8e,0xaa2b,4,4},{0x4d4a,0xaa2c,6,1},{0x4d70,0xaaa2,10,2},{0x4da2,0xa8a8,8,0}}
 for _,site in ipairs(sites) do
  local off,trap,pop,result=table.unpack(site)
  local ent=string.format('temp9=1;temp8=temp8+1;temp0=sp;temp2=%x;logerror "DEVICE_ENTER seq=%%X offset=%%X trap=%%X sp=%%X args=%%08X/%%08X/%%08X/%%08X'..regs:gsub("%%","%%%%")..'\\n",temp8,%x,temp2,sp,d@sp,d@(sp+4),d@(sp+8),d@(sp+c)'..values..';g',trap,off)
  local ret=string.format('logerror "DEVICE_RETURN seq=%%X offset=%%X trap=%%X sp=%%X expected=%%X result=%%X'..regs:gsub("%%","%%%%")..'\\n",temp8,%x,temp2,sp,temp0+%x,%s'..values..';',off,pop,result==4 and 'd@sp' or result==2 and 'w@sp' or result==1 and 'b@sp' or '0')
  if trap==0xa8a8 then
   ent=ent:sub(1,-2).."temp7=d@(sp+4)&ffffff;"..dump('RECT_BEFORE','temp7',2)..'g'
   ret=ret..dump('RECT_AFTER','temp7',2)
  end
  if trap==0xaa29 then
   ret=ret..'temp3=d@sp&ffffff;logerror "DEVICE_POINTERS handle=%X body=%X pixmapHandle=%X pixmap=%X clutHandle=%X clut=%X\\n",temp3,d@temp3&ffffff,d@((d@temp3&ffffff)+16)&ffffff,d@(d@((d@temp3&ffffff)+16)&ffffff)&ffffff,d@((d@(d@((d@temp3&ffffff)+16)&ffffff)&ffffff)+2a)&ffffff,d@(d@((d@(d@((d@temp3&ffffff)+16)&ffffff)&ffffff)+2a)&ffffff)&ffffff;'..dump('DEVICE_RECORD','d@temp3&ffffff',16)
   ret=ret..'temp4=d@((d@temp3&ffffff)+16)&ffffff;'..dump('PIXMAP_RECORD','d@temp4&ffffff',13)
   ret=ret..'temp5=d@((d@temp4&ffffff)+2a)&ffffff;'..dump('CTABLE_RECORD','d@temp5&ffffff',2)
  end
  setup=setup..string.format('logerror "DEVICE_SITE offset=%%X bytes=%%08X\\n",%x,d@(temp6+%x);bpset temp6+%x,temp9==0,{',off,off,off)..ent..'};'..string.format('bpset temp6+%x,temp9==1,{',off+2)..ret..'temp9=0;g};'
 end
 setup=setup..'bpset temp6+4d34,temp8>0,{logerror "DEVICE_SELECTED result=%X count=%X\\n",d0,d7&ffff;g};bpset '..base(12)..'+3a,temp8>0 && temp9==0,{logerror "PASS device reference calls=%X inflight=%X secondTimes=%X\\n",temp8,temp9,w@((d@904&ffffff)-1261c);quit};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a900 && (d@(sp+2)&ffffff)=='..base(12)..'+12',setup)
 armed=true;print('ARM device dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'DEVICE STARTUP / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'DEVICE STARTUP / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('DEVICE STARTUP / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
