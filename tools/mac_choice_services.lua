-- Observe original fixed-choice service contracts. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DIALOG / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('DIALOG / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
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
  if line:find('unknown command') or line:find('Error') then print('FAIL dialog debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DIALOG / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 for _,site in ipairs({{'MODAL',0x30fe,0xa991},{'ITEM',0x348a,0xa98d},{'DISPOSE',0x3452,0xa983},{'WORLD',0x313c,0xab1d}}) do
  local label,offset,trap=table.unpack(site)
  local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(13)..';temp7=d@('..base(7)..'+3f94)&ffffff;temp1=d@(sp+8)&ffffff;temp2=d@(sp+c)&ffffff;temp3=d@(sp+10)&ffffff;logerror "SERVICE_ENTER label='..label..' seq=%X sp=%X port=%X windows=%X main=%X filterOffset=%X'..regs..'\\n",temp8,temp0,d@temp7,d@9d6,d@8a4,(temp2-a5)&ffffff'..values..';'..dump('SERVICE_ARGS','temp0',6)
  local returned='logerror "SERVICE_RETURN label='..label..' seq=%X sp=%X port=%X windows=%X'..regs..'\\n",temp8,sp,d@temp7,d@9d6'..values..';'
  if label=='MODAL' then
   entered=entered..dump('MODAL_BEFORE','temp1',1)
   returned=returned..dump('MODAL_AFTER','temp1',1)
  elseif label=='ITEM' then
   entered=entered..'logerror "ITEM_REQUEST number=%X dialog=%X handle=%X\\n",w@(sp+14),d@(sp+16)&ffffff,d@((d@(d@((d@(sp+16)&ffffff)+9c)&ffffff)&ffffff)+1a)&ffffff;'
   returned=returned..'logerror "ITEM_RESULT type=%X handle=%X rect=%08X%08X\\n",w@temp3,d@temp2,d@temp1,d@(temp1+4);'
  end
  if label=='WORLD' then returned=returned..'logerror "PASS original fixed-choice services\\n";quit' else returned=returned..'g' end
  entered=entered..string.format('bpset temp6+0x%x,1,{',offset+2)..returned..'};g'
  cpu.debug:bpset(0xdd60,appcond..string.format(' && w@(d@(sp+2))==0x%x && (d@(sp+2)&ffffff)==',trap)..base(13)..string.format('+0x%x',offset),entered)
 end
 armed=true;print('ARM dialog dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'DIALOG / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'DIALOG / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('DIALOG / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
