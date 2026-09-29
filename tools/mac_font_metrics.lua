-- Observe original font metrics service contracts. No instruction, argument or state patches.
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
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL metrics debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'METRICS / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 for _,site in ipairs({{'INFO',0x610,0xa88b},{'ZERO',0x618,0xa88d},{'SPACE',0x626,0xa88d}}) do
  local label,offset,trap=table.unpack(site)
  local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(9)..';temp7=d@('..base(7)..'+3f94)&ffffff;temp1=d@(sp+8)&ffffff;temp2=d@temp7;logerror "METRIC_ENTER label='..label..' seq=%X sp=%X port=%X font=%X size=%X face=%X extra=%X'..regs..'\\n",temp8,temp0,temp2,w@(temp2+44),w@(temp2+4a),b@(temp2+46),d@(temp2+4c)'..values..';'..dump('METRIC_ARGS','temp0',3)
  local returned='logerror "METRIC_RETURN label='..label..' seq=%X sp=%X port=%X result=%X'..regs..'\\n",temp8,sp,d@temp7,w@sp'..values..';'
  if label=='INFO' then
   entered=entered..'logerror "METRIC_SAVED seq=%X font=%X size=%X face=%X\\n",temp8,w@(a6-6),w@(a6-c),b@(a6-7);'..dump('METRIC_FONTS','a5-0xf10',8)..dump('METRIC_STYLES','a5-0xef2',3)..dump('METRIC_BEFORE','temp1',3)
   returned=returned..dump('METRIC_AFTER','temp1',3)
   entered=entered..'bpset temp6+660,1,{logerror "METRIC_DONE font=%X size=%X face=%X error=%X\\n",w@(d@temp7+44),w@(d@temp7+4a),b@(d@temp7+46),w@(a6-a);logerror "PASS original font metrics calls=%X\\n",temp8;quit};'
  end
  entered=entered..string.format('bpset temp6+0x%x,1,{',offset+2)..returned..'g};g'
  cpu.debug:bpset(0xdd60,appcond..string.format(' && w@(d@(sp+2))==0x%x && (d@(sp+2)&ffffff)==',trap)..base(9)..string.format('+0x%x',offset),entered)
 end
 armed=true;print('ARM metrics dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'METRICS / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'METRICS / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('METRICS / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
