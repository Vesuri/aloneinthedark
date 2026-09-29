-- Catch startup calls in the verified dispatcher: segment-frame callbacks are too late.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'FONT LOOKUP / DEBUGGER REQUIRED')
-- Fixture mode replays GetFNum in scratch stack memory after the first real call.
-- It is contract evidence only; normal mode executes both original call sites.
local fixture=os.getenv('AITD_FONT_FIXTURE')=='1'
local armed=false
local base
for i,j in ipairs(meta.jt) do
 if j[1]==12 then base=string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]);break end
end
assert(base,'FONT LOOKUP / NO JUMP ENTRY')
local app='Alone In The Dark';local condition=string.format('b@910==%x',#app)
for i=1,#app do condition=condition..string.format(' && b@%x==%x',0x910+i,app:byte(i)) end
condition=condition..' && w@(d@(sp+2))==a900 && ((d@(sp+2)&ffffff)=='..base..'+12 || (d@(sp+2)&ffffff)=='..base..'+38)'
local report='logerror "FONT_ORIGINAL return=%X result=%04X d0=%08X res=%04X mem=%04X sp=%X expected=%X\\n",temp4-temp9,w@temp1,d0,w@a60,w@220,sp,temp2+8;'
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'FONT LOOKUP / DISPATCHER BYTES')
 dbg:command('temp0=0;temp8=0')
 local action='temp9='..base..';temp1=d@(sp+8);temp2=sp+8;temp4=(d@(sp+2)&ffffff)+2;temp8=temp8+1;logerror "FONT_ORIGINAL entry=%X out=%X name=%08X tail=%04X sp=%X bytes=%08X d0=%08X\\n",temp4-temp9-2,temp1,d@(d@(sp+c)&ffffff),w@((d@(sp+c)&ffffff)+4),temp2,d@temp4,d0;'
 if fixture then
  local names={'Times','times','TIMES','tImEs','AITD Missing Font','','Times ',' Times'}
  local function enter(n)
   local name=string.char(#names[n])..names[n]
   local out='sp=temp2-8;d@sp=temp2+80;d@(sp+4)=temp2+100;w@(temp2+7e)=abcd;w@(temp2+80)=cccc;w@(temp2+82)=dcba;w@a60=8888;w@220=7777;'
   for i=1,#name do out=out..string.format('b@(temp2+%x)=%x;',0x100+i-1,name:byte(i)) end
   return out..string.format('temp0=%x;d0=12345678;pc=temp2+400;g',n)
  end
  local setup='sp=sp-800;temp2=sp;w@(temp2+400)=a900;w@(temp2+402)=4ef9;d@(temp2+404)=temp4;'
  action=action..'bpset temp4,temp0==0,{'..report..setup..enter(1)..'};'
  for n in ipairs(names) do
   local row=string.format('logerror "FONT_CASE stage=%X result=%%04X before=%%04X after=%%04X d0=%%08X res=%%04X mem=%%04X sp=%%X expected=%%X\\n",w@(temp2+80),w@(temp2+7e),w@(temp2+82),d0,w@a60,w@220,sp,temp2;',n)
   action=action..string.format('bpset temp4,temp0==%x,{',n)..row..(n<#names and enter(n+1) or 'logerror "PASS font lookup fixture complete\\n";quit')..'};'
  end
 else
  action=action..'bpset temp4,temp8==1,{'..report..'g};bpset temp4,temp8==2,{'..report..'logerror "PASS original font lookup complete\\n";quit};'
 end
 cpu.debug:bpset(0xdd60,condition..(fixture and ' && temp8==0' or ' && temp8<2'),action..'g')
 armed=true;print('ARM font lookup dispatcher bytes=2f0a2f02246f000a; Dan1 live jump-table attribution')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'FONT LOOKUP / LAUNCH')
  mac.wait(300)
  if not fixture then
   assert(mac.mouse_to(256,274),'FONT LOOKUP / SIZE POINTER');mac.click(1)
  end
  mac.wait(3600)
  for _,screen in pairs(manager.machine.screens) do assert(not screen:snapshot('m2-font-wait.png')) end
  dbg:command('logerror "FONT_WAIT pc=%X sp=%X a6=%X\\n",pc,sp,a6')
  error('FONT LOOKUP / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
