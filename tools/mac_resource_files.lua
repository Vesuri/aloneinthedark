-- CPU-only resource-file/search contract; exclusively created scratch files.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
-- Scratch names are created exclusively and deleted only after both forks close.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE FILES / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE FILES / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,result,after,guard)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',result=result or '0',after=after or '',guard=guard}
 end
 local function pb(name)
  return 'a0=temp2+100;d@(a0+12)=temp2+'..name..';w@(a0+16)=0;w@(a0+1c)=0;'
 end
 local function refcall(label,trap,ref) add(label,trap,'sp=sp-2;w@(sp)='..ref..';') end
 local function cur(label) add(label,0xa994,'sp=sp-2;w@(sp)=cccc;','w@(sp)') end
 local function lookup(label,trap,typ,id)
  add(label,trap,string.format('sp=sp-a;w@(sp)=%x;d@(sp+2)=%x;d@(sp+6)=cccccccc;',id,typ),'d@(sp)','temp3=d@(sp);')
 end
 local function count(label,trap,typ) add(label,trap,string.format('sp=sp-6;d@(sp)=%x;w@(sp+4)=cccc;',typ),'w@(sp)') end
 local function newresource(label,typ,id,value)
  add(label..'-allocate',0xa122,'d0=4;','a0','temp3=a0;d@((d@(temp3)&ffffff))='..value..';','(d0&ffff)==0 && a0!=0')
  add(label..'-add',0xa9ab,string.format('sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=%x;d@(sp+6)=%x;d@(sp+a)=temp3;',id,typ),nil,nil,'w@a60==0')
 end
 add('application',0xa994,'sp=sp-2;w@(sp)=cccc;','w@(sp)','temp1=w@(sp);')
 count('baseline-chain-strings',0xa99c,0x53545223);count('baseline-chain-probes',0xa99c,0x52505242)
 add('create-a-file',0xa008,pb('200'),nil,nil,'(d0&ffff)==0')
 add('create-a-map',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
 add('open-a',0xa997,'sp=sp-6;d@(sp)=temp2+200;w@(sp+4)=cccc;','w@(sp)','temp4=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 cur('current-a');count('empty-a',0xa80d,0x52505242)
 newresource('a-shared',0x53545223,128,'41414141')
 newresource('a-duplicate',0x52505242,7,'37373737')
 newresource('a-only',0x52505242,1,'31313131')
 refcall('update-a',0xa999,'temp4')
 add('open-a-again',0xa997,'sp=sp-6;d@(sp)=temp2+200;w@(sp+4)=cccc;','w@(sp)',nil,'w@a60==0')
 add('create-b-file',0xa008,pb('240'),nil,nil,'(d0&ffff)==0')
 add('create-b-map',0xa81b,'sp=sp-a;d@(sp)=temp2+240;d@(sp+4)=0;w@(sp+8)=0;',nil,nil,'w@a60==0')
 add('open-b',0xa9c4,'sp=sp-a;w@(sp)=300;w@(sp+2)=0;d@(sp+4)=temp2+240;w@(sp+8)=cccc;','w@(sp)','temp5=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 cur('current-b');newresource('b-shared',0x53545223,128,'42424242');newresource('b-only',0x52505242,2,'32323232')
 newresource('b-duplicate',0x52505242,7,'77777777')
 refcall('update-b',0xa999,'temp5')
 count('b-chain-strings',0xa99c,0x53545223);count('b-local-strings',0xa80d,0x53545223)
 count('b-chain-probes',0xa99c,0x52505242);count('b-local-probes',0xa80d,0x52505242)
 lookup('b-chain-shared',0xa9a0,0x53545223,128);lookup('b-local-shared',0xa81f,0x53545223,128)
 lookup('b-fallback-a',0xa9a0,0x52505242,1);lookup('b-local-missing',0xa81f,0x52505242,1)
 add('b-named-shared',0xa9a1,'sp=sp-c;d@(sp)=temp2+280;d@(sp+4)=53545223;d@(sp+8)=cccccccc;','d@(sp)','temp3=d@(sp);')
 refcall('use-a',0xa998,'temp4');cur('current-used-a');count('a-chain-probes',0xa99c,0x52505242)
 lookup('a-chain-shared',0xa9a0,0x53545223,128);lookup('a-cannot-see-b',0xa9a0,0x52505242,2)
 add('a-named-shared',0xa9a1,'sp=sp-c;d@(sp)=temp2+280;d@(sp+4)=53545223;d@(sp+8)=cccccccc;','d@(sp)','temp3=d@(sp);')
 refcall('use-app',0xa998,'temp1');cur('current-app');count('app-chain-probes',0xa99c,0x52505242)
 lookup('app-shared',0xa9a0,0x53545223,128)
 refcall('use-invalid',0xa998,'1234');cur('current-after-invalid')
 refcall('use-b-again',0xa998,'temp5');refcall('close-b',0xa99a,'temp5');cur('current-after-close-b')
 lookup('after-close-b-shared',0xa9a0,0x53545223,128)
 refcall('close-b-again',0xa99a,'temp5');cur('current-after-invalid-close')
 refcall('close-a',0xa99a,'temp4');cur('current-after-close-a')
 add('reopen-a',0xa81a,'sp=sp-e;w@(sp)=300;d@(sp+2)=temp2+200;d@(sp+6)=0;w@(sp+a)=0;w@(sp+c)=cccc;','w@(sp)','temp4=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 lookup('reopened-a-bytes',0xa81f,0x53545223,128)
 refcall('close-reopened-a',0xa99a,'temp4')
 add('delete-a',0xa009,pb('200'),nil,nil,'(d0&ffff)==0')
 add('delete-b',0xa009,pb('240'),nil,nil,'(d0&ffff)==0')
 add('open-missing',0xa997,'sp=sp-6;d@(sp)=temp2+200;w@(sp+4)=cccc;','w@(sp)')
 cur('current-final')
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=%x;pc=temp2+400;g',n,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,'AITD Resource Probe A'},{0x240,'AITD Resource Probe B'},{0x280,'General'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+%x)=%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RFILE label=%s stage=%%X result=%%08X error=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X a=%%04X b=%%04X handle=%%08X\\n",temp0,%s,w@a60,d0,sp,temp2,temp1,temp4,temp5,temp3;',q.label,q.result)
  local data=''
  if q.label:find('shared') and not q.label:find('allocate') and not q.label:find('add') or q.label=='b-fallback-a' or q.label=='reopened-a-bytes' then
   data='logerror "RFILE BODY stage=%X bytes=%08X\\n",temp0,d@((d@(temp3)&ffffff));'
  end
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource files capture complete; scratch deleted\\n";quit'
  local cond=string.format('temp0==0x%x',n)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..data..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource files scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('ARM resource-files Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE FILES / LAUNCH FAILED');mac.wait(3600);error('RESOURCE FILES / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
