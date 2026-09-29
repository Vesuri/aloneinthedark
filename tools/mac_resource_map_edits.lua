-- CPU-only WriteResource amid new and removed peers in one exclusive scratch file.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
-- The scratch file is created exclusively and deleted after its resource fork closes.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE MAP EDITS / DEBUGGER REQUIRED')
local armed=false
local valid=os.getenv('AITD_RESOURCE_MAP_VALID')=='1'
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE MAP EDITS / ORIGINAL BYTES')
 if not valid and os.getenv('AITD_RESOURCE_MAP_DIAGNOSTICS')=='1' then
  assert(mem:read_u16(0x4081319c)==0xa002 and mem:read_u16(0x408130c8)==0xa027,'UNWRITTEN LOAD / ROM BYTES')
 cpu.debug:bpset(0x4081319c,'temp0==0x10','logerror "UNWRITTEN read req=%08X pos=%08X before=%08X\\n",d@(a0+24),d@(a0+2e),d@(d@(a0+20));g')
 cpu.debug:bpset(0x4081319e,'temp0==0x10','logerror "UNWRITTEN read error=%08X actual=%08X after=%08X\\n",d0,d@(a0+28),d@(d@(a0+20));g')
 cpu.debug:bpset(0x408130c8,'temp0==0x10','logerror "UNWRITTEN realloc size=%08X\\n",d0;g')
 end
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
  add(label,0xa81f,string.format('sp=sp-a;w@(sp)=%x;d@(sp+2)=49534f4c;d@(sp+6)=cccccccc;',id),'d@(sp)','temp3=d@(sp);','w@a60==0 && d@(sp)!=0 && (d@(d@(sp))&ffffff)!=0')
 end
 local function open(label,name,ref)
  add(label,0xa997,'sp=sp-6;d@(sp)=temp2+'..name..';w@(sp+4)=cccc;','w@(sp)',ref..'=w@(sp);','w@a60==0 && w@(sp)!=ffff')
 end
 local function allocate(label,value)
  add(label,0xa122,'d0=4;','a0','temp3=a0;d@((d@(temp3)&ffffff))='..value..';','(d0&ffff)==0 && a0!=0')
 end
 local function attach(label,id,slot) add(label,0xa9ab,string.format('sp=sp-e;d@(sp)=temp2+280;w@(sp+4)=%x;d@(sp+6)=49534f4c;d@(sp+a)=temp3;',id),nil,'d@(temp2+'..slot..')=temp3;','w@a60==0') end
 local function current(label) add(label,0xa994,'sp=sp-2;','w@(sp)') end
 local function select(slot) return 'temp3=d@(temp2+'..slot..');' end
 local function change(label,slot,body) handle(label,0xa9aa,select(slot)..'d@((d@(temp3)&ffffff))='..body..';','w@a60==0') end
 local function write(label,slot) handle(label,0xa9b0,select(slot),'w@a60==0') end
 local function state(label,slot) add(label,0xa9a6,select(slot)..'sp=sp-6;d@(sp)=temp3;w@(sp+4)=cccc;','w@(sp)') end
 local function empty(label,slot) add(label,0xa02b,select(slot)..'a0=temp3;',nil,nil,'(d0&ffff)==0') end
 local function load(label,slot) handle(label,0xa9a2,select(slot),'w@a60==0 && (d@(temp3)&ffffff)!=0') end
 local function missing(label,id)
  add(label,0xa81f,string.format('sp=sp-a;w@(sp)=%x;d@(sp+2)=49534f4c;d@(sp+6)=cccccccc;',id),'d@(sp)',nil,'w@a60==0 && d@(sp)==0')
 end
 add('application',0xa994,'sp=sp-2;','w@(sp)','temp1=w@(sp);')
 add('create',0xa008,pb('200'),nil,nil,'(d0&ffff)==0')
 add('map',0xa9b1,'sp=sp-4;d@(sp)=temp2+200;',nil,nil,'w@a60==0')
 open('open','200','temp4')
 allocate('allocate-a','41414141');attach('add-a',128,'300')
 allocate('allocate-b','42424242');attach('add-b',129,'304')
 write('write-with-unwritten-peer','300');state('attrs-written-a','300');state('attrs-unwritten-b','304')
 empty('empty-written-a','300');load('reload-written-a','300')
 if valid then
  refcall('update-peers',0xa999,'temp4');empty('empty-published-b','304');load('reload-published-b','304');state('attrs-published-b','304')
  refcall('close-first',0xa99a,'temp4');open('reopen-first','200','temp4')
  lookup('lookup-first-a',128);steps[#steps].after=steps[#steps].after..'d@(temp2+300)=temp3;'
  lookup('lookup-first-b',129);steps[#steps].after=steps[#steps].after..'d@(temp2+304)=temp3;'
 else
 empty('empty-unwritten-b','304');state('attrs-empty-unwritten-b','304')
 handle('load-unwritten-b',0xa9a2,select('304'));state('attrs-after-unwritten-load','304')
 add('size-unwritten-loaded',0xa025,'a0=temp3;','d0')
 handle('remove-unwritten-b',0xa9ad,select('304'),'w@a60==0')
 add('dispose-unwritten-b',0xa023,select('304')..'a0=temp3;',nil,nil,'(d0&ffff)==0')
 refcall('update-first',0xa999,'temp4');refcall('close-first',0xa99a,'temp4')
 open('reopen-first','200','temp4');lookup('lookup-first-a',128);steps[#steps].after=steps[#steps].after..'d@(temp2+300)=temp3;'
 missing('lookup-first-removed-b',129)
 allocate('allocate-again-b','42424242');attach('add-again-b',129,'304')
 refcall('update-baseline',0xa999,'temp4')
 end
 handle('remove-stored-b',0xa9ad,select('304'),'w@a60==0')
 change('change-a','300','43434343');write('write-with-removed-peer','300');state('attrs-written-again-a','300')
 empty('empty-again-a','300');load('reload-again-a','300');missing('lookup-removed-b',129)
 refcall('update-second',0xa999,'temp4');refcall('close-second',0xa99a,'temp4')
 open('reopen-second','200','temp4');lookup('lookup-final-a',128);missing('lookup-final-removed-b',129)
 refcall('close-final',0xa99a,'temp4')
 add('dispose-stored-b',0xa023,select('304')..'a0=temp3;',nil,nil,'(d0&ffff)==0')
 add('delete',0xa009,pb('200'),nil,nil,'(d0&ffff)==0');current('current-final')
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q.setup..string.format('temp0=0x%x;w@(temp2+400)=%x;pc=temp2+400;g',n,q.trap)
 end
 local setup=string.format('sp=sp-800;temp2=sp;temp3=0;temp4=0;temp5=0;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 for i=0,31 do setup=setup..string.format('d@(temp2+%x)=0;',0x100+i*4) end
 for _,q in ipairs({{0x200,'AITD Resource Map Edits'},{0x280,'Scratch'}}) do
  local text=string.char(#q[2])..q[2]
  for i=1,#text do setup=setup..string.format('b@(temp2+%x)=%x;',q[1]+i-1,text:byte(i)) end
 end
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RMAPEDIT label=%s stage=%%X result=%%08X error=%%04X mem=%%04X d0=%%08X sp=%%08X base=%%08X app=%%04X ref=%%04X handle=%%08X other=%%08X master=%%08X body=%%08X\\n",temp0,%s,w@a60,w@220,d0,sp,temp2,temp1,temp4,temp3,temp5,d@(temp3),d@((d@(temp3)&ffffff));',q.label,q.result)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource map-edit capture complete; scratch deleted\\n";quit'
  local cond=string.format('temp0==0x%x',n)
  cpu.debug:bpset(base+0x3cde,cond..(q.guard and ' && ('..q.guard..')' or ''),q.after..report..nextaction)
  if q.guard then cpu.debug:bpset(base+0x3cde,cond..' && !('..q.guard..')',report..'logerror "FAIL resource map-edit scratch ownership/setup; retained for recovery\\n";quit') end
 end
 armed=true;print('ARM resource-map-edit Engine+$3CDC bytes=a820245f'..(valid and ' mode=valid' or ''))
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE MAP EDITS / LAUNCH FAILED');mac.wait(3600);error('RESOURCE MAP EDITS / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
