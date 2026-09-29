-- Original startup menu-record calls. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'MENU RECORDS / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]) end end
 error('MENU RECORDS / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@%x==%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local function dump(label,address)
 local format,args='',''
 for i=0,63 do format=format..'%08X';args=args..string.format(',d@((%s)+%x)',address,i*4) end
 return 'logerror "'..label..' seq=%X data='..format..'\\n",temp8'..args..';'
end
local armed=false
local consoleSeen=0
emu.register_frame_done(function()
 -- Retain console errors: malformed debugger actions otherwise look like hangs.
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL menu debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'MENU RECORDS / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local setup='temp6='..base(7)..';logerror "MENU_ARM count=%08X get=%08X set=%08X\\n",d@(temp6+2dee),d@(temp6+2e0c),d@(temp6+2ec2);'
 for _,site in ipairs({{0x2dee,0xa950,4},{0x2e0c,0xa946,10},{0x2ec2,0xa947,10}}) do
  local offset,trap,cleanup=table.unpack(site)
  local entered=string.format('temp9=1;temp8=temp8+1;temp0=sp;temp1=pc+2;temp2=%x;temp3=d@(sp+%x)&ffffff;temp4=%s;temp5=%s;',trap,trap==0xa950 and 0 or 6,trap==0xa950 and '0' or 'd@sp&ffffff',trap==0xa950 and '0' or 'w@(sp+4)')
  entered=entered..'logerror "MENU_ENTER seq=%X trap=%04X offset=%X menu=%04X item=%X sp=%X next=%08X'..regs..'\\n",temp8,temp2,temp1-temp6-2,w@(d@temp3&ffffff),temp5,temp0,d@temp1'..values..';'..dump('MENU_BEFORE','d@temp3&ffffff')
  if trap==0xa947 then entered=entered..dump('TEXT_BEFORE','temp4') end
  local returned='logerror "MENU_RETURN seq=%X trap=%04X sp=%X expected=%X result=%04X'..regs..'\\n",temp8,temp2,sp,temp0+'..string.format('%x',cleanup)..','..(trap==0xa950 and 'w@sp' or '0')..values..';'..dump('MENU_AFTER','d@temp3&ffffff')
  if trap~=0xa950 then returned=returned..dump('TEXT_AFTER','temp4') end
  setup=setup..string.format('bpset temp6+%x,temp9==0,{',offset)..entered..'g};'..string.format('bpset temp6+%x,temp9==1,{',offset+2)..returned..'temp9=0;g};'
 end
 setup=setup..'bpset '..base(12)..'+3a,temp8>0 && temp9==0,{logerror "PASS menu reference calls=%X inflight=%X secondTimes=%X\\n",temp8,temp9,w@((d@904&ffffff)-1261c);quit};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a900 && (d@(sp+2)&ffffff)=='..base(12)..'+12',setup)
 armed=true;print('ARM menu dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'MENU RECORDS / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'MENU RECORDS / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('MENU RECORDS / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
