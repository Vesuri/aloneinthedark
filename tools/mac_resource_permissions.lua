-- CPU-only resource permissions/creation contract; exclusively created scratch files.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
-- Scratch names are created exclusively and deleted only after both forks close.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE PERMISSIONS / DEBUGGER REQUIRED')
local armed=false
emu.register_frame_done(function()
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 local base
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if j[1]==7 and mem:read_u16(e)==7 and mem:read_u16(e+2)==0x4ef9 then base=(mem:read_u32(e+4)&0xffffff)-j[2];break end
 end
 if not base then return end
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE PERMISSIONS / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,result,after,guard)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',result=result or '0',after=after or '',guard=guard}
 end
 local function namedPB() return 'a0=temp2+100;d@(a0+12)=temp2+200;w@(a0+16)=0;b@(a0+1b)=0;' end
 local function refcall(label,trap) add(label,trap,'sp=sp-2;w@(sp)=temp4;') end
 local function open(label,permission)
  add(label,0xa9c4,string.format('sp=sp-a;w@(sp)=%x;w@(sp+2)=0;d@(sp+4)=temp2+200;w@(sp+8)=cccc;',permission*256),'w@(sp)','temp4=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 end
 local function lookup(label)
  add(label,0xa81f,'sp=sp-a;w@(sp)=80;d@(sp+2)=5250524d;d@(sp+6)=cccccccc;','d@(sp)','temp3=d@(sp);','w@a60==0 && d@(sp)!=0')
 end
 local function handle(label,trap,setup)
  add(label,trap,(setup or '')..'sp=sp-4;d@(sp)=temp3;')
 end
 add('application',0xa994,'sp=sp-2;','w@(sp)','temp1=w@(sp);')
 add('exclusive-create',0xa008,namedPB(),nil,nil,'(d0&ffff)==0')
 add('open-empty-map',0xa9c4,'sp=sp-a;w@(sp)=300;w@(sp+2)=0;d@(sp+4)=temp2+200;w@(sp+8)=cccc;','w@(sp)',nil,'w@(sp)==ffff')
 add('raw-open',0xa00a,namedPB()..'b@(a0+1b)=3;','w@(a0+18)','temp4=w@(a0+18);','(d0&ffff)==0')
 add('raw-write-bad-map',0xa003,'a0=temp2+100;w@(a0+18)=temp4;d@(temp2+300)=0;d@(temp2+304)=0;d@(temp2+308)=0;d@(temp2+30c)=0;d@(a0+20)=temp2+300;d@(a0+24)=10;w@(a0+2c)=1;d@(a0+2e)=0;','d@(a0+28)',nil,'(d0&ffff)==0 && d@(a0+28)==10')
 add('raw-close',0xa001,'a0=temp2+100;w@(a0+18)=temp4;',nil,nil,'(d0&ffff)==0')
 add('open-malformed-map',0xa9c4,'sp=sp-a;w@(sp)=300;w@(sp+2)=0;d@(sp+4)=temp2+200;w@(sp+8)=cccc;','w@(sp)',nil,'w@(sp)==ffff')
 add('delete-empty',0xa009,namedPB(),nil,nil,'(d0&ffff)==0')
 add('create-absent',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
 open('open-initial',3)
 add('allocate',0xa122,'d0=4;','a0','temp3=a0;d@((d@(temp3)&ffffff))=41424344;','(d0&ffff)==0 && a0!=0')
 add('add',0xa9ab,'sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=80;d@(sp+6)=5250524d;d@(sp+a)=temp3;',nil,nil,'w@a60==0')
 refcall('update',0xa999);refcall('close-initial',0xa99a)
 add('create-existing',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;')
 for permission=0,4 do
  open('open-'..permission,permission);lookup('lookup-'..permission);refcall('close-'..permission,0xa99a)
 end
 open('open-readonly',1);lookup('lookup-readonly')
 handle('changed-readonly',0xa9aa,'d@((d@(temp3)&ffffff))=45464748;')
 add('attrs-readonly',0xa9a6,'sp=sp-6;d@(sp)=temp3;w@(sp+4)=cccc;','w@(sp)')
 handle('write-readonly',0xa9b0)
 add('readonly-allocate',0xa122,'d0=4;','a0','temp5=a0;d@((d@(temp5)&ffffff))=49494949;','(d0&ffff)==0 && a0!=0')
 add('add-readonly',0xa9ab,'sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=81;d@(sp+6)=5250524d;d@(sp+a)=temp5;')
 add('count-readonly-added',0xa80d,'sp=sp-6;d@(sp)=5250524d;w@(sp+4)=cccc;','w@(sp)')
 handle('remove-readonly',0xa9ad);refcall('update-readonly',0xa999);refcall('close-readonly',0xa99a)
 add('current-after-readonly',0xa994,'sp=sp-2;','w@(sp)')

 open('open-after-readonly',3);lookup('lookup-after-readonly')
 add('lookup-readonly-added',0xa81f,'sp=sp-a;w@(sp)=81;d@(sp+2)=5250524d;d@(sp+6)=cccccccc;','d@(sp)')
 refcall('close-after-readonly',0xa99a)
 add('lock',0xa041,namedPB(),nil,nil,'(d0&ffff)==0')
 open('open-locked-default',0);lookup('lookup-locked-default');refcall('close-locked-default',0xa99a)
 open('open-locked-read',1);lookup('lookup-locked-read');refcall('close-locked-read',0xa99a)
 for permission=2,4 do
  add('open-locked-'..permission,0xa9c4,string.format('sp=sp-a;w@(sp)=%x;w@(sp+2)=0;d@(sp+4)=temp2+200;w@(sp+8)=cccc;',permission*256),'w@(sp)',nil,'w@(sp)==ffff')
 end
 add('unlock',0xa042,namedPB(),nil,nil,'(d0&ffff)==0')
 add('delete-file',0xa009,namedPB(),nil,nil,'(d0&ffff)==0')
 add('current-final',0xa994,'sp=sp-2;','w@(sp)')
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=%x;pc=temp2+400;g',n,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,'AITD Resource Perm Probe'},{0x280,'Scratch'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+%x)=%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RPERM label=%s stage=%%X result=%%08X error=%%04X mem=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X ref=%%04X handle=%%08X other=%%08X master=%%08X body=%%08X\\n",temp0,%s,w@a60,w@220,d0,sp,temp2,temp1,temp4,temp3,temp5,d@(temp3),d@((d@(temp3)&ffffff));',q.label,q.result)
  local data=''
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource permissions capture complete; scratch deleted\\n";quit'
  local cond=string.format('temp0==0x%x',n)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..data..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource permissions scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('ARM resource-permissions Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE PERMISSIONS / LAUNCH FAILED');mac.wait(3600);error('RESOURCE PERMISSIONS / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
