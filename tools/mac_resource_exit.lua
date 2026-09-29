-- CPU-only dirty-resource persistence across Mac application exit and relaunch.
-- Enter byte-checked CODE 1 main-return/unpatch path; never run game quit/prefs code.
-- Exclusively create one scratch file, then close/delete it after exact readback.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE EXIT / DEBUGGER REQUIRED')
local scratchPath=os.getenv('AITD_RESOURCE_EXIT_PATH') or 'AITD Exit Resource Probe'
assert(#scratchPath>0 and #scratchPath<128,'RESOURCE EXIT / SCRATCH PATH LENGTH')
local armed=false
local phase=1
local exitSeen=false
emu.register_frame_done(function()
 if armed and phase==1 and mac.frontmost()=='Finder' then
  phase=2;armed=false;exitSeen=true;print('REXIT Finder after original runtime exit')
 end
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 local base
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if j[1]==7 and mem:read_u16(e)==7 and mem:read_u16(e+2)==0x4ef9 then base=(mem:read_u32(e+4)&0xffffff)-j[2];break end
 end
 if not base then return end
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE EXIT / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,result,after,guard)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',result=result or '0',after=after or '',guard=guard}
 end
 local function pb(name) return 'a0=temp2+100;d@(a0+12)=temp2+'..name..';w@(a0+16)=0;b@(a0+1b)=0;' end
 local function refcall(label,trap,ref) add(label,trap,'sp=sp-2;w@(sp)='..ref..';') end
 local function attrs(label) add(label,0xa9a6,'sp=sp-6;d@(sp)=temp3;w@(sp+4)=cccc;','w@(sp)') end
 local function lookup(label)
  add(label,0xa81f,'sp=sp-a;w@(sp)=80;d@(sp+2)=4c494645;d@(sp+6)=cccccccc;','d@(sp)','temp3=d@(sp);','w@a60==0 && d@(sp)!=0 && (d@(d@(sp))&ffffff)!=0')
 end
 local function open(label,name,ref)
  add(label,0xa997,'sp=sp-6;d@(sp)=temp2+'..name..';w@(sp+4)=cccc;','w@(sp)',ref..'=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 end
 local function allocate(label,value)
  add(label,0xa122,'d0=4;','a0','temp3=a0;d@((d@(temp3)&ffffff))='..value..';','(d0&ffff)==0 && a0!=0')
 end
 local function attach(label) add(label,0xa9ab,'sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=80;d@(sp+6)=4c494645;d@(sp+a)=temp3;',nil,nil,'w@a60==0') end
 local function current(label) add(label,0xa994,'sp=sp-2;','w@(sp)') end
 add('application',0xa994,'sp=sp-2;','w@(sp)','temp1=w@(sp);')
 if phase==1 then
  add('create',0xa008,pb('200'),nil,nil,'(d0&ffff)==0')
  add('map',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
  open('open','200','temp4');allocate('allocate','45584954');attach('add-dirty');attrs('attrs-dirty')
 else
  open('reopen','200','temp4');lookup('lookup-after-exit')
  refcall('close',0xa99a,'temp4')
  add('delete',0xa009,pb('200'),nil,nil,'(d0&ffff)==0')
  current('current-final')
 end
 local unpatch=mem:read_u32(a5+0x6c)&0xffffff
 local code1=unpatch-0x4aa
 assert(mem:read_u32(code1+0x48)==0x2a780904 and mem:read_u32(code1+0x4c)==0x206d006c and mem:read_u32(code1+0x50)==0x4e90a9f4,'RESOURCE EXIT / ORIGINAL RETURN BYTES')
 local unpatchBytes={0x226d,0x0068,0x303c,0xa9f0,0x2069,0x0008,0xa047,0x303c,0xa9f1,0x2069,0x0014,0xa047,0x303c,0xa9f4,0x2069,0x0020,0xa047,0x2049,0xa01f,0x4e75}
 for i,v in ipairs(unpatchBytes) do assert(mem:read_u16(unpatch+(i-1)*2)==v,'RESOURCE EXIT / ORIGINAL UNPATCH BYTES') end
 local firstStage=phase==1 and 0 or 0x1000
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=0x%x;pc=temp2+400;g',n+firstStage,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=0x%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+0x%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,scratchPath},{0x280,'Scratch'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+0x%x)=0x%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,string.format('temp0==0x%x',firstStage),setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "REXIT label=%s stage=%%X result=%%08X error=%%04X mem=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X ref=%%04X handle=%%08X other=%%08X master=%%08X body=%%08X\\n",temp0,%s,w@a60,w@220,d0,sp,temp2,temp1,temp4,temp3,temp5,d@(temp3),d@((d@(temp3)&ffffff));',q.label,q.result)
  local nextaction=n<#steps and enter(n+1) or (phase==1 and string.format('logerror "REXIT original-runtime-exit dirty-open=1\\n";temp0=1000;pc=0x%x;g',code1+0x48) or 'logerror "PASS resource exit capture complete; scratch deleted\\n";quit')
  local cond=string.format('temp0==0x%x',n+firstStage)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource exit scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('REXIT path='..scratchPath);print('ARM resource-exit Engine+$3CDC bytes=a820245f CODE1+$0048/$04AA checked')
end)
mac.run(function()
 local ok,err=pcall(function()
  local launched=mac.launch()
  assert(launched or exitSeen,'RESOURCE EXIT / FIRST LAUNCH FAILED')
  assert(mac.wait_for('exit to Finder',function() return exitSeen end,3600),'RESOURCE EXIT / NO FINDER')
  assert(mac.launch(),'RESOURCE EXIT / RELAUNCH FAILED')
  mac.wait(3600);error('RESOURCE EXIT / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
