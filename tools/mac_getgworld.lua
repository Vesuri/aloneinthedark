-- Observe original GetGWorld before the second Times lookup. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'GETGWORLD / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]) end end
 error('GETGWORLD / NO JUMP ENTRY')
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
  if line:find('unknown command') or line:find('Error') then print('FAIL getgworld debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GETGWORLD / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local entered='temp8=temp8+1;temp0=sp+8;temp1=d@(sp+8)&ffffff;temp2=d@(sp+c)&ffffff;temp6='..base(13)..';temp7=d@('..base(7)..'+3f94)&ffffff;logerror "WORLD_ENTER seq=%X sp=%X deviceOut=%X portOut=%X opcode=%08X selectorBytes=%08X qdPort=%X mainDevice=%X wmgrPort=%X'..regs..'\\n",temp8,temp0,temp1,temp2,d@(temp6+30e2),d@(temp6+30de),d@temp7,d@8a4,d@9de'..values..';'..dump('WORLD_PORT_BEFORE','d@temp7&ffffff',27)..dump('WORLD_SCREEN','temp7-7a',4)
 local returned='temp3=d@temp2&ffffff;temp4=d@temp1&ffffff;logerror "WORLD_RETURN seq=%X sp=%X expected=%X port=%X device=%X qdPort=%X mainDevice=%X wmgrPort=%X'..regs..'\\n",temp8,sp,temp0+8,temp3,temp4,d@temp7,d@8a4,d@9de'..values..';'..dump('WORLD_PORT','temp3',27)..dump('WORLD_DEVICE','d@temp4&ffffff',16)..'logerror "PASS GetGWorld reference calls=%X\\n",temp8;quit'
 entered=entered..'bpset temp6+30e4,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==ab1d && (d@(sp+2)&ffffff)=='..base(13)..'+30e2',entered)
 armed=true;print('ARM getgworld dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'GETGWORLD / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'GETGWORLD / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('GETGWORLD / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
