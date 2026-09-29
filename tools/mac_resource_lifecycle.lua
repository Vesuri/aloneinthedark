-- CPU-only Resource Manager handle contract, on a disposable emulator session.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
os.remove('tmp/mac-purged-resource.bin')
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE LIFECYCLE / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE LIFECYCLE / ORIGINAL BYTES')
 local handle='sp=sp-4;d@(sp)=temp3;'
 local lookup='sp=sp-a;w@(sp)=d;d@(sp+2)=4352454c;d@(sp+6)=cccccccc;'
 local steps={
  {'lookup',0xa81f,lookup},
  {'state-loaded',0xa069,'a0=temp3;'},
  {'purge',0xa04d,'d0=ffffff;'},
  {'state-purged',0xa069,'a0=temp3;'},
  {'reload',0xa9a2,handle},
  {'state-reloaded',0xa069,'a0=temp3;'},
  {'lock',0xa029,'a0=temp3;'},
  {'purge-locked',0xa04d,'d0=ffffff;'},
  {'state-locked',0xa069,'a0=temp3;'},
  {'release-locked',0xa9a3,handle},
  {'lookup-after-locked-release',0xa81f,lookup},
  {'unlock',0xa02a,'a0=temp3;'},
  {'release',0xa9a3,handle},
  {'lookup-after-release',0xa81f,lookup},
  {'empty',0xa02b,'a0=temp3;'},
  {'state-empty',0xa069,'a0=temp3;'},
  {'lock-empty',0xa029,'a0=temp3;'},
  {'hpurge-empty',0xa049,'a0=temp3;'},
  {'unlock-empty',0xa02a,'a0=temp3;'},
  {'setstate-empty',0xa06a,'a0=temp3;d0=e0;'},
  {'release-empty',0xa9a3,handle},
  {'lookup-after-empty-release',0xa81f,lookup},
  {'empty-for-detach',0xa02b,'a0=temp3;'},
  {'detach-empty',0xa992,handle},
  {'load-empty-detached',0xa9a2,handle},
  {'release-detached',0xa9a3,handle},
  {'load-nil',0xa9a2,'sp=sp-4;d@(sp)=0;'},
  {'detach-nil',0xa992,'sp=sp-4;d@(sp)=0;'}
 }
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@220=7777;d0=12345678;'..q[3]..string.format('temp0=0x%x;w@(temp2+400)=%x;pc=temp2+400;g',n,q[2])
 end
 local setup=string.format('temp1=d@(sp);sp=sp-600;temp2=sp;temp3=temp1;w@(temp2+402)=4ef9;d@(temp2+404)=%x;',base+0x3cde)
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local lookupCall=q[2]==0xa81f
  local prefix=lookupCall and 'temp3=d@(sp);' or ''
  local report=string.format('logerror "RLIFE label=%s stage=%%X handle=%%08X master=%%08X error=%%04X memerror=%%04X d0=%%08X sp=%%08X expectedsp=%%08X\\n",temp0,temp3,d@(temp3),w@a60,w@220,d0,sp,temp2%s;',q[1],lookupCall and '-4' or '')
  if q[1]=='reload' then report=report..'save tmp/mac-purged-resource.bin,(d@(temp3)&ffffff),508;' end
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource lifecycle capture complete\\n";quit'
  cpu.debug:bpset(base+0x3cde,string.format('temp0==0x%x',n),prefix..report..nextaction)
 end
 armed=true;print('ARM resource-lifecycle Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE LIFECYCLE / LAUNCH FAILED');mac.wait(3600);error('RESOURCE LIFECYCLE / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
