-- CPU-only Resource Manager handle contract, on a disposable emulator session.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
os.remove('tmp/mac-enumerated-resource.bin')
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE ENUMERATION / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE ENUMERATION / ORIGINAL BYTES')
 local steps={}
 local function add(label,kind,trap,typ,index) steps[#steps+1]={label,kind,trap,typ,index} end
 for _,q in ipairs({{'count-crel',0xa80d,0x4352454c},{'chain-count-crel',0xa99c,0x4352454c},{'count-code',0xa80d,0x434f4445},{'count-strs',0xa80d,0x53545253},{'count-missing',0xa80d,0x51515151},{'chain-count-missing',0xa99c,0x51515151}}) do add(q[1],'count',q[2],q[3]) end
 add('load-off','switch',0xa99b,0)
 local function indexed(label,typ,index)
  add(label,'index',0xa80e,typ,index)
  if index>0 and ((typ==0x4352454c and index<=10) or typ==0x434f4445 or typ==0x53545253) then add(label..'-info','info',0xa9a8) end
 end
 indexed('crel-zero',0x4352454c,0);indexed('crel-negative',0x4352454c,-1)
 for i=1,11 do indexed('crel-'..i,0x4352454c,i) end
 indexed('crel-large',0x4352454c,32767);indexed('crel-min',0x4352454c,-32768)
 indexed('type-missing',0x51515151,1)
 indexed('code-first',0x434f4445,1);indexed('code-second',0x434f4445,2);indexed('code-last',0x434f4445,14)
 indexed('strs-first',0x53545253,1)
 add('load-on','switch',0xa99b,1)
 indexed('loaded-first',0x4352454c,1)
 local function enter(n)
  local q=steps[n];local out='sp=temp2;w@a60=8888;d0=12345678;w@(temp2+80)=cccc;d@(temp2+90)=cccccccc;'
  if q[2]=='count' then out=out..string.format('sp=sp-6;d@(sp)=0x%x;w@(sp+4)=cccc;',q[4])
  elseif q[2]=='switch' then out=out..string.format('sp=sp-2;w@(sp)=0x%x;',q[4]*256)
  elseif q[2]=='index' then out=out..string.format('sp=sp-a;w@(sp)=0x%x;d@(sp+2)=0x%x;d@(sp+6)=cccccccc;',q[5]&0xffff,q[4])
  else out=out..'sp=sp-10;d@(sp)=temp2+100;d@(sp+4)=temp2+90;d@(sp+8)=temp2+80;d@(sp+c)=temp3;' end
  return out..string.format('temp0=0x%x;w@(temp2+400)=0x%x;pc=temp2+400;g',n,q[3])
 end
 local setup=string.format('sp=sp-600;temp2=sp;temp3=0;w@(temp2+402)=4ef9;d@(temp2+404)=0x%x;',base+0x3cde)
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local prefix=q[2]=='index' and 'temp3=d@(sp);' or ''
  local result=q[2]=='count' and 'w@(sp)' or 'temp3'
  local report=string.format('logerror "RENUM label=%s kind=%s stage=%%X result=%%08X master=%%08X error=%%04X d0=%%08X sp=%%08X expectedsp=%%08X id=%%04X type=%%08X\\n",temp0,%s,d@(temp3),w@a60,d0,sp,temp2%s,w@(temp2+80),d@(temp2+90);',q[1],q[2],result,q[2]=='count' and '-2' or q[2]=='index' and '-4' or '')
  if q[1]=='loaded-first' then report=report..'save tmp/mac-enumerated-resource.bin,(d@(temp3)&ffffff),508;' end
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource enumeration capture complete\\n";quit'
  cpu.debug:bpset(base+0x3cde,string.format('temp0==0x%x',n),prefix..report..nextaction)
 end
 armed=true;print('ARM resource-enumeration Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE ENUMERATION / LAUNCH FAILED');mac.wait(3600);error('RESOURCE ENUMERATION / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
