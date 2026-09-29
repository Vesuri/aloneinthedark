-- Controlled SANE fixtures at the original first trap. Instructions are unchanged.
-- Uses the hidden dialog's private 51-byte text handle for two bounded operands.
-- Replays the original trap with fixture arguments and exits before game continuation.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'GETMAINDEVICE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('GETMAINDEVICE / NO JUMP ENTRY')
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
  if line:find('unknown command') or line:find('Error') then print('FAIL main-device debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GETMAINDEVICE / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local fixtures=dofile('tmp/sane-fixtures.lua')
 local function writes(address,hex)
  local result=''
  for i=1,#hex,2 do result=result..string.format('b@(%s+0x%x)=0x%s;',address,(i-1)/2,hex:sub(i,i+1)) end
  return result
 end
 for i,v in ipairs(fixtures) do
  local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(7)..';temp4=d@(d@((d@(d@(d@9d6+9c)&ffffff)&ffffff)+32)&ffffff)&ffffff;temp2=temp4+10;temp3=temp4;'..writes('temp3',v.source)..writes('temp2',v.before)..string.format('w@(sp+8)=0x%x;d@(sp+a)=temp2;d@(sp+e)=temp3;',v.op)..'logerror "FIXTURE_ENTER seq=%X op=%X sp=%X sr=%X fp=%X\\n",temp8,w@(sp+8),temp0,sr,w@a4a;'..dump('FIXTURE_SOURCE','temp3',3)..dump('FIXTURE_BEFORE','temp2',3)..'g'
  local returned='logerror "FIXTURE_RETURN seq=%X sp=%X sr=%X fp=%X data=%08X%08X%08X\\n",temp8,sp,sr,w@a4a,d@temp2,d@(temp2+4),d@(temp2+8);'
  if i==#fixtures then returned=returned..'logerror "PASS SANE fixtures calls=%X\\n",temp8;quit'
  else returned=returned..'sp=temp0;pc=temp6+47c2;g' end
  local retbp='bpset '..base(7)..'+47c4,temp8=='..string.format('0x%x',i)..',{'..returned..'};'
  cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a9eb && (d@(sp+2)&ffffff)=='..base(7)..'+47c2 && temp8=='..string.format('0x%x',i-1),retbp..entered)
 end
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
