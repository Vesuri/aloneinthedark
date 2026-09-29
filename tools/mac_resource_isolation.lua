-- CPU-only WriteResource isolation: two dirty resources in one exclusive scratch file.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
-- The scratch file is created exclusively and deleted after its resource fork closes.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE ISOLATION / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE ISOLATION / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,result,after,guard)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',result=result or '0',after=after or '',guard=guard}
 end
 local function pb(name) return 'a0=temp2+100;d@(a0+12)=temp2+'..name..';w@(a0+16)=0;b@(a0+1b)=0;' end
 local function refcall(label,trap,ref) add(label,trap,'sp=sp-2;w@(sp)='..ref..';') end
 local function handle(label,trap,setup,guard)
  add(label,trap,(setup or '')..'sp=sp-4;d@(sp)=temp3;',nil,nil,guard)
 end
 local function lookup(label,id)
  add(label,0xa81f,string.format('sp=sp-a;w@(sp)=0x%x;d@(sp+2)=49534f4c;d@(sp+6)=cccccccc;',id),'d@(sp)','temp3=d@(sp);','w@a60==0 && d@(sp)!=0 && (d@(d@(sp))&ffffff)!=0')
 end
 local function open(label,name,ref)
  add(label,0xa997,'sp=sp-6;d@(sp)=temp2+'..name..';w@(sp+4)=cccc;','w@(sp)',ref..'=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 end
 local function allocate(label,value)
  add(label,0xa122,'d0=4;','a0','temp3=a0;d@((d@(temp3)&ffffff))='..value..';','(d0&ffff)==0 && a0!=0')
 end
 local function attach(label,id,slot) add(label,0xa9ab,string.format('sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=0x%x;d@(sp+6)=49534f4c;d@(sp+a)=temp3;',id),nil,'d@(temp2+'..slot..')=temp3;','w@a60==0') end
 local function current(label) add(label,0xa994,'sp=sp-2;','w@(sp)') end
 local function select(slot) return 'temp3=d@(temp2+'..slot..');' end
 local function change(label,slot,body) handle(label,0xa9aa,select(slot)..'d@((d@(temp3)&ffffff))='..body..';','w@a60==0') end
 local function write(label,slot) handle(label,0xa9b0,select(slot),'w@a60==0') end
 local function state(label,slot) add(label,0xa9a6,select(slot)..'sp=sp-6;d@(sp)=temp3;w@(sp+4)=cccc;','w@(sp)') end
 local function empty(label,slot) add(label,0xa02b,select(slot)..'a0=temp3;',nil,nil,'(d0&ffff)==0') end
 local function load(label,slot) handle(label,0xa9a2,select(slot),'w@a60==0 && (d@(temp3)&ffffff)!=0') end
 add('application',0xa994,'sp=sp-2;','w@(sp)','temp1=w@(sp);')
 add('create',0xa008,pb('200'),nil,nil,'(d0&ffff)==0')
 add('map',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
 open('open','200','temp4')
 allocate('allocate-a','41414141');attach('add-a',128,'300')
 allocate('allocate-b','42424242');attach('add-b',129,'304')
 refcall('update-baseline',0xa999,'temp4')
 change('change-a','300','43434343');change('change-b','304','44444444')
 write('write-a','300');state('attrs-written-a','300');state('attrs-dirty-b','304')
 empty('empty-a','300');load('reload-a','300')
 empty('empty-b','304');state('attrs-empty-b','304');load('reload-b','304');state('attrs-reloaded-b','304')
 refcall('update-discarded',0xa999,'temp4');refcall('close-first',0xa99a,'temp4')
 open('reopen-first','200','temp4');lookup('lookup-first-a',128);steps[#steps].after=steps[#steps].after..'d@(temp2+300)=temp3;'
 lookup('lookup-first-b',129);steps[#steps].after=steps[#steps].after..'d@(temp2+304)=temp3;'
 change('change-again-a','300','45454545');change('change-again-b','304','46464646')
 write('write-b','304');state('attrs-dirty-a','300');state('attrs-written-b','304')
 empty('empty-written-b','304');load('reload-written-b','304')
 refcall('update-both',0xa999,'temp4');refcall('close-second',0xa99a,'temp4')
 open('reopen-second','200','temp4');lookup('lookup-final-a',128);lookup('lookup-final-b',129)
 refcall('close-final',0xa99a,'temp4')
 add('delete',0xa009,pb('200'),nil,nil,'(d0&ffff)==0');current('current-final')
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=0x%x;pc=temp2+400;g',n,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=0x%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+0x%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,'AITD Resource Isolation'},{0x280,'Scratch'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+0x%x)=0x%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RISOLATE label=%s stage=%%X result=%%08X error=%%04X mem=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X ref=%%04X handle=%%08X other=%%08X master=%%08X body=%%08X\\n",temp0,%s,w@a60,w@220,d0,sp,temp2,temp1,temp4,temp3,temp5,d@(temp3),d@((d@(temp3)&ffffff));',q.label,q.result)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource isolation capture complete; scratch deleted\\n";quit'
  local cond=string.format('temp0==0x%x',n)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource isolation scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('ARM resource-isolation Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE ISOLATION / LAUNCH FAILED');mac.wait(3600);error('RESOURCE ISOLATION / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
