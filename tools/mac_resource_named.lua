-- CPU-only resource lookup contract; no file writes or original instruction edits.
os.remove('tmp/mac-general-resource.bin') -- Never reuse an earlier capture.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE NAMED / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f and mem:read_u32(base+0x3cd2)==0x2f3c5354,'RESOURCE NAMED / ORIGINAL BYTES')
 local steps={
  {'exact',0xa820,0x53545223,'General'},
  {'lower',0xa820,0x53545223,'general'},
  {'upper',0xa820,0x53545223,'GENERAL'},
  {'accent',0xa820,0x53545223,'G'..string.char(0x8e)..'neral'},
  {'missing',0xa820,0x53545223,'Absent AITD resource'},
  {'type-case',0xa820,0x73747223,'General'},
  {'empty-name',0xa820,0x53545253,''},
  {'other-name',0xa820,0x53545223,'Error Messages'},
  {'chain-exact',0xa9a1,0x53545223,'General'},
  {'chain-missing',0xa9a1,0x53545223,'Absent AITD resource'},
  {'id-exact',0xa81f,0x53545223,128},
  {'id-missing',0xa81f,0x53545223,32767},
  {'id-after-error',0xa81f,0x53545223,128},
  {'id-zero',0xa81f,0x53545223,0},
  {'id-negative',0xa81f,0x53545223,-32768},
  {'id-type-missing',0xa81f,0x51515151,128},
  {'chain-id-missing',0xa9a0,0x53545223,32767},
  {'chain-id-type-missing',0xa9a0,0x51515151,128},
  {'chain-empty-name',0xa9a1,0x53545253,''},
  {'id-after-missing',0xa81f,0x53545223,128}
 }
 local function enter(n)
  local q=steps[n];local out='sp=temp2;w@a60=8888;'
  if type(q[4])=='string' then
   local text=string.char(#q[4])..q[4]
   for i=1,#text do out=out..string.format('b@(temp2+%x)=%x;',0x100+i-1,text:byte(i)) end
   out=out..string.format('sp=sp-c;d@(sp)=temp2+100;d@(sp+4)=%x;d@(sp+8)=cccccccc;',q[3])
  else out=out..string.format('sp=sp-a;w@(sp)=%x;d@(sp+2)=%x;d@(sp+6)=cccccccc;',q[4]&0xffff,q[3]) end
  return out..string.format('temp0=0x%x;d0=12345678;w@(temp2+400)=%x;pc=temp2+400;g',n,q[2])
 end
 cpu.debug:bpset(base+0x3cdc,'temp0==0','logerror "RESOURCE ORIGINAL name0=%08X name1=%08X type=%08X\\n",d@(d@(sp)),d@(d@(sp)+4),d@(sp+4);g')
 local setup=string.format('logerror "RESOURCE ORIGINAL result=%%08X error=%%04X\\n",d@(sp),w@a60;temp1=d@(sp);save tmp/mac-general-resource.bin,(d@(temp1)&ffffff),264;sp=sp-600;temp2=sp;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "RNAMED label=%s stage=%%X handle=%%08X error=%%04X d0=%%08X sp=%%08X expectedsp=%%08X original=%%08X\\n",temp0,d@(sp),w@a60,d0,sp,temp2-4,temp1;',q[1])
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS named resource capture complete\\n";quit'
  cpu.debug:bpset(base+0x3cde,string.format('temp0==0x%x',n),report..nextaction)
 end
 armed=true;print('ARM named-resource Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE NAMED / LAUNCH FAILED');mac.wait(3600);error('RESOURCE NAMED / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
