-- CPU-only dirty resource-handle lifecycle contract; exclusively created scratch files.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
-- Scratch names are created exclusively and deleted only after both forks close.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE DIRTY / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE DIRTY / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,result,after,guard)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',result=result or '0',after=after or '',guard=guard}
 end
 local function pb(name) return 'a0=temp2+100;d@(a0+12)=temp2+'..name..';w@(a0+16)=0;b@(a0+1b)=0;' end
 local function refcall(label,trap,ref) add(label,trap,'sp=sp-2;w@(sp)='..ref..';') end
 local function handle(label,trap,setup,guard)
  add(label,trap,(setup or '')..'sp=sp-4;d@(sp)=temp3;',nil,nil,guard)
 end
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
 add('create-a',0xa008,pb('200'),nil,nil,'(d0&ffff)==0')
 add('map-a',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
 open('open-a','200','temp4');allocate('allocate-a','41414141');attach('add-a');refcall('update-a',0xa999,'temp4')
 handle('change-release',0xa9aa,'d@((d@(temp3)&ffffff))=42424242;');handle('release-dirty',0xa9a3)
 lookup('lookup-released');attrs('attrs-released')
 handle('change-detach',0xa9aa,'d@((d@(temp3)&ffffff))=43434343;')
 handle('detach-dirty',0xa992);attrs('attrs-still-dirty')
 handle('write-before-detach',0xa9b0)
 handle('detach-written',0xa992,'d@(temp2+300)=temp3;','w@a60==0')
 attrs('attrs-detached');lookup('lookup-detached')
 add('dispose-detached',0xa023,'a0=d@(temp2+300);',nil,nil,'(d0&ffff)==0')
 handle('change-empty',0xa9aa,'d@((d@(temp3)&ffffff))=44444444;')
 add('empty-dirty',0xa02b,'a0=temp3;')
 attrs('attrs-empty')
 handle('load-empty',0xa9a2,nil,'w@a60==0 && (d@(temp3)&ffffff)!=0');attrs('attrs-loaded')
 refcall('update-loaded',0xa999,'temp4')
 handle('change-close',0xa9aa,'d@((d@(temp3)&ffffff))=45454545;')
 refcall('close-dirty',0xa99a,'temp4');open('reopen-a','200','temp4');lookup('lookup-closed')
 add('create-b',0xa008,pb('240'),nil,nil,'(d0&ffff)==0')
 add('map-b',0xa9b1,'sp=sp-4;d@(sp)=temp2+240;',nil,nil,'w@a60==0')
 open('open-b','240','temp5');allocate('allocate-b','46464646');attach('add-b')
 refcall('use-app',0xa998,'temp1');refcall('close-noncurrent-a',0xa99a,'temp4');current('current-after-a')
 refcall('close-noncurrent-dirty-b',0xa99a,'temp5');current('current-after-b')
 open('reopen-b','240','temp5');lookup('lookup-noncurrent-closed');refcall('close-b',0xa99a,'temp5')
 add('delete-a',0xa009,pb('200'),nil,nil,'(d0&ffff)==0')
 add('delete-b',0xa009,pb('240'),nil,nil,'(d0&ffff)==0')
 current('current-final')
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=%x;pc=temp2+400;g',n,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,'AITD Dirty Resource A'},{0x240,'AITD Dirty Resource B'},{0x280,'Scratch'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+%x)=%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RDIRTY label=%s stage=%%X result=%%08X error=%%04X mem=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X ref=%%04X handle=%%08X other=%%08X master=%%08X body=%%08X\\n",temp0,%s,w@a60,w@220,d0,sp,temp2,temp1,temp4,temp3,temp5,d@(temp3),d@((d@(temp3)&ffffff));',q.label,q.result)
  local data=''
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource dirty lifecycle capture complete; scratch deleted\\n";quit'
  local cond=string.format('temp0==0x%x',n)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..data..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource dirty lifecycle scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('ARM resource-dirty Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE DIRTY / LAUNCH FAILED');mac.wait(3600);error('RESOURCE DIRTY / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
