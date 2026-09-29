-- Observe original SANE positioning operands and results. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SANE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('SANE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6','sr'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local function dump(label,address,count)
 local format,args='',''
 for i=0,count-1 do format=format..'%08X';args=args..string.format(',d@((%s)+0x%x)',address,i*4) end
 return 'logerror "'..label..' seq=%X data='..format..'\\n",temp8'..args..';'
end
local armed=false
local consoleSeen=0
emu.register_frame_done(function()
 -- Retain console errors: malformed debugger actions otherwise look like hangs.
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL SANE debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'SANE / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(7)..';temp1=d@(sp+2)&ffffff;temp2=d@(sp+a)&ffffff;temp3=if(w@(sp+8)==16,temp2,d@(sp+e)&ffffff);temp5=w@(sp+8);logerror "SANE_ENTER seq=%X offset=%X sp=%X op=%X dest=%X source=%X fp=%X'..regs..'\\n",temp8,temp1-temp6,temp0,temp5,temp2,temp3,w@a4a'..values..';'..dump('SANE_DEST_BEFORE','temp2',3)..dump('SANE_SOURCE','temp3',3)
 local returned='logerror "SANE_RETURN seq=%X sp=%X fp=%X'..regs..'\\n",temp8,sp,w@a4a'..values..';'..dump('SANE_DEST_AFTER','temp2',3)..'g'
 entered=entered..'bpset temp1+2,1,{'..returned..'};bpset temp6+4858,1,{logerror "PASS original SANE positioning calls=%X\\n",temp8;quit};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a9eb && (d@(sp+2)&ffffff)>='..base(7)..'+47c2 && (d@(sp+2)&ffffff)<='..base(7)..'+4852',entered)
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==aa2a','bpset '..base(7)..'+479e,1,{logerror "POSITION_INPUT shadow=%d instruction=%08X rect=%08X%08X selected=%X main=%X\\n",w@baa,d@pc,d@(a6-8),d@(a6-4),d@(a6+10),a4;g};g')
 armed=true;print('ARM SANE dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'SANE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'SANE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('SANE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
