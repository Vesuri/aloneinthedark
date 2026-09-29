-- Observe original SetDepth before the second Times lookup. No instruction, argument or state patches.
-- A failed debugger save must not reuse evidence from an earlier run.
os.remove('tmp/setdepth-reference-before.clut')
os.remove('tmp/setdepth-reference-after.clut')
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SETDEPTH / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]) end end
 error('SETDEPTH / NO JUMP ENTRY')
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
  if line:find('unknown command') or line:find('Error') then print('FAIL setdepth debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'SETDEPTH / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local setup='temp6='..base(3)..';'
 local sites={{0x500,0xaaa2,10,2}}
 for _,site in ipairs(sites) do
  local off,trap,pop,result=table.unpack(site)
  local ent='temp9=1;temp8=temp8+1;temp0=sp;temp3=d@(sp+6)&ffffff;temp4=d@((d@temp3&ffffff)+16)&ffffff;temp5=d@((d@temp4&ffffff)+2a)&ffffff;logerror "DEPTH_ENTER seq=%X sp=%X args=%08X/%08X/%08X'..regs..'\\n",temp8,sp,d@sp,d@(sp+4),d@(sp+8)'..values..';'..dump('GD_BEFORE','d@temp3&ffffff',16)..dump('PM_BEFORE','d@temp4&ffffff',13)..dump('CT_BEFORE','d@temp5&ffffff',2)..'save tmp/setdepth-reference-before.clut,d@temp5&ffffff,808;g'
  local ret='logerror "DEPTH_RETURN seq=%X sp=%X expected=%X result=%X'..regs..'\\n",temp8,sp,temp0+a,w@sp'..values..';'..dump('GD_AFTER','d@temp3&ffffff',16)..dump('PM_AFTER','d@temp4&ffffff',13)..dump('CT_AFTER','d@temp5&ffffff',2)..'save tmp/setdepth-reference-after.clut,d@temp5&ffffff,808;temp9=0;g'
  setup=setup..'logerror "DEPTH_SITE bytes=%08X before=%08X\\n",d@(temp6+500),d@(temp6+4fc);bpset temp6+500,temp9==0,{'..ent..'};bpset temp6+502,temp9==1,{'..ret..'};'
 end
 setup=setup..'bpset '..base(12)..'+3a,temp8>0 && temp9==0,{logerror "PASS setdepth reference calls=%X inflight=%X secondTimes=%X\\n",temp8,temp9,w@((d@904&ffffff)-1261c);quit};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a900 && (d@(sp+2)&ffffff)=='..base(12)..'+12',setup)
 armed=true;print('ARM setdepth dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'SETDEPTH / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'SETDEPTH / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('SETDEPTH / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
