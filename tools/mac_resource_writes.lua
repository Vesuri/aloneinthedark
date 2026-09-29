-- CPU-only writable-resource mutation contract; exclusively created scratch files.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
-- Scratch names are created exclusively and deleted only after both forks close.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE WRITES / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE WRITES / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,result,after,guard)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',result=result or '0',after=after or '',guard=guard}
 end
 local function refcall(label,trap,ref) add(label,trap,'sp=sp-2;w@(sp)='..ref..';') end
 local function handle(label,trap,h,setup,result)
  add(label,trap,(setup or '')..'sp=sp-4;d@(sp)='..(h or 'temp3')..';',result)
 end
 local function attrs(label) add(label,0xa9a6,'sp=sp-6;d@(sp)=temp3;w@(sp+4)=cccc;','w@(sp)') end
 local function open(label) add(label,0xa997,'sp=sp-6;d@(sp)=temp2+200;w@(sp+4)=cccc;','w@(sp)','temp4=w@(sp);','w@a60==0 && w@(sp)!=ffff') end
 local function lookup(label,id)
  add(label,0xa81f,string.format('sp=sp-a;w@(sp)=%x;d@(sp+2)=5257524b;d@(sp+6)=cccccccc;',id),'d@(sp)','temp3=d@(sp);')
 end
 local function attach(label,id,h)
  add(label,0xa9ab,string.format('sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=%x;d@(sp+6)=5257524b;d@(sp+a)=%s;',id,h or 'temp3'))
 end
 local function count(label) add(label,0xa80d,'sp=sp-6;d@(sp)=5257524b;w@(sp+4)=cccc;','w@(sp)') end
 add('application',0xa994,'sp=sp-2;','w@(sp)','temp1=w@(sp);')
 add('create-file',0xa008,'a0=temp2+100;d@(a0+12)=temp2+200;w@(a0+16)=0;',nil,nil,'(d0&ffff)==0')
 add('create-map',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
 open('open')
 add('allocate',0xa122,'d0=4;','a0','temp3=a0;d@((d@(temp3)&ffffff))=41414141;','(d0&ffff)==0 && a0!=0')
 attach('add',128);attrs('attrs-added')
 handle('changed',0xa9aa,nil,'d@((d@(temp3)&ffffff))=42424242;');attrs('attrs-changed')
 handle('write',0xa9b0);attrs('attrs-written');refcall('update',0xa999,'temp4')
 refcall('close',0xa99a,'temp4');open('reopen');lookup('lookup-written',128);attrs('attrs-reopened')
 handle('write-without-changed',0xa9b0,nil,'d@((d@(temp3)&ffffff))=43434343;')
 refcall('close-unchanged',0xa99a,'temp4');open('reopen-unchanged');lookup('lookup-unchanged',128)
 add('duplicate-allocate',0xa122,'d0=4;','a0','temp5=a0;d@((d@(temp5)&ffffff))=44444444;','(d0&ffff)==0 && a0!=0')
 attach('duplicate-add',128,'temp5');count('count-after-duplicate')
 refcall('update-duplicates',0xa999,'temp4');refcall('close-duplicates',0xa99a,'temp4');open('reopen-duplicates');count('count-reopened-duplicates')
 add('duplicate-index-one',0xa80e,'sp=sp-a;w@(sp)=1;d@(sp+2)=5257524b;d@(sp+6)=cccccccc;','d@(sp)','temp3=d@(sp);')
 add('duplicate-index-two',0xa80e,'sp=sp-a;w@(sp)=2;d@(sp+2)=5257524b;d@(sp+6)=cccccccc;','d@(sp)','temp3=d@(sp);')
 lookup('lookup-duplicate-selected',128)

 attach('nil-add',129,'0');handle('nil-changed',0xa9aa,'0');handle('nil-write',0xa9b0,'0');handle('nil-remove',0xa9ad,'0')
 handle('remove',0xa9ad);attrs('attrs-removed');handle('changed-removed',0xa9aa);handle('write-removed',0xa9b0);handle('remove-again',0xa9ad)
 count('count-removed');attach('readd',129);refcall('invalid-update',0xa999,'1234');refcall('update-readded',0xa999,'temp4')
 refcall('close-readded',0xa99a,'temp4');open('reopen-readded');lookup('lookup-readded',129);lookup('lookup-removed',128)
 refcall('final-close',0xa99a,'temp4')
 add('delete-file',0xa009,'a0=temp2+100;d@(a0+12)=temp2+200;w@(a0+16)=0;',nil,nil,'(d0&ffff)==0')
 add('current-final',0xa994,'sp=sp-2;','w@(sp)')
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=%x;pc=temp2+400;g',n,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,'AITD Resource Write Probe'},{0x280,'Scratch'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+%x)=%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RWRITE label=%s stage=%%X result=%%08X error=%%04X mem=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X ref=%%04X handle=%%08X other=%%08X master=%%08X body=%%08X\\n",temp0,%s,w@a60,w@220,d0,sp,temp2,temp1,temp4,temp3,temp5,d@(temp3),d@((d@(temp3)&ffffff));',q.label,q.result)
  local data=''
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource writes capture complete; scratch deleted\\n";quit'
  local cond=string.format('temp0==0x%x',n)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..data..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource writes scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('ARM resource-writes Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE WRITES / LAUNCH FAILED');mac.wait(3600);error('RESOURCE WRITES / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
