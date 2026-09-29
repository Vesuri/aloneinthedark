-- Observe original GetMainDevice. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'GETMAINDEVICE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]) end end
 error('GETMAINDEVICE / NO JUMP ENTRY')
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
  if line:find('unknown command') or line:find('Error') then print('FAIL main-device debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GETMAINDEVICE / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(7)..';temp7=d@(temp6+3f94)&ffffff;logerror "MAIN_ENTER sp=%X opcode=%X main=%X current=%X port=%X'..regs..'\\n",temp0,d@(temp6+4782),d@8a4,d@cc8,d@temp7'..values..';'..dump('MAIN_BEFORE','d@(d@8a4&ffffff)&ffffff',16)
 local returned='temp3=d@sp&ffffff;logerror "MAIN_RETURN sp=%X result=%X main=%X current=%X port=%X'..regs..'\\n",sp,temp3,d@8a4,d@cc8,d@temp7'..values..';'..dump('MAIN_AFTER','d@temp3&ffffff',16)..'logerror "PASS original GetMainDevice\\n";quit'
 entered=entered..'bpset temp6+4784,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==aa2a && (d@(sp+2)&ffffff)=='..base(7)..'+4782',entered)
 armed=true;print('ARM main-device dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'GETMAINDEVICE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'GETMAINDEVICE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('GETMAINDEVICE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
