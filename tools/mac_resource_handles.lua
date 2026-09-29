-- CPU-only Resource Manager handle contract, on a disposable emulator session.
-- Original bytes are checked; synthetic calls run from scratch on the Mac stack.
os.remove('tmp/mac-loaded-resource.bin')
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESOURCE HANDLES / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cdc)==0xa820245f,'RESOURCE HANDLES / ORIGINAL BYTES')
 local info='sp=sp-10;d@(sp)=temp2+100;d@(sp+4)=temp2+90;d@(sp+8)=temp2+80;d@(sp+c)='
 local handle='sp=sp-4;d@(sp)='
 local steps={
  {'info-general',0xa9a8,info..'temp1;'},
  {'info-nil',0xa9a8,info..'0;'},
  {'load-off',0xa99b,'sp=sp-2;w@(sp)=0;'},
  {'lookup-unloaded',0xa81f,'sp=sp-a;w@(sp)=7d1;d@(sp+2)=53545223;d@(sp+6)=cccccccc;'},
  {'named-unloaded',0xa9a1,'sp=sp-c;d@(sp)=temp2+200;d@(sp+4)=53545223;d@(sp+8)=cccccccc;'},
  {'info-unloaded',0xa9a8,info..'temp3;'},
  {'load-explicit',0xa9a2,handle..'temp3;'},
  {'info-loaded',0xa9a8,info..'temp3;'},
  {'empty',0xa02b,'a0=temp3;'},
  {'info-emptied',0xa9a8,info..'temp3;'},
  {'reload',0xa9a2,handle..'temp3;'},
  {'load-on',0xa99b,'sp=sp-2;w@(sp)=100;'},
  {'empty-again',0xa02b,'a0=temp3;'},
  {'lookup-enabled',0xa81f,'sp=sp-a;w@(sp)=7d1;d@(sp+2)=53545223;d@(sp+6)=cccccccc;'},
  {'detach',0xa992,handle..'temp3;'},
  {'info-detached',0xa9a8,info..'temp3;'},
  {'load-detached',0xa9a2,handle..'temp3;'},
  {'release-nil',0xa9a3,handle..'0;'}
 }
 local function enter(n)
  local q=steps[n]
  return 'sp=temp2;w@a60=8888;w@(temp2+80)=cccc;d@(temp2+90)=cccccccc;d@(temp2+100)=cccccccc;d@(temp2+104)=cccccccc;d@(temp2+108)=cccccccc;d@(temp2+10c)=cccccccc;'..q[3]..string.format('temp0=0x%x;d0=12345678;w@(temp2+400)=0x%x;pc=temp2+400;g',n,q[2])
 end
 local setup=string.format('temp1=d@(sp);sp=sp-600;temp2=sp;temp3=temp1;d@(temp2+200)=0e457272;d@(temp2+204)=6f72204d;d@(temp2+208)=65737361;d@(temp2+20c)=67657300;w@(temp2+402)=4ef9;d@(temp2+404)=0x%x;',base+0x3cde)
 cpu.debug:bpset(base+0x3cde,'temp0==0',setup..enter(1))
 for n,q in ipairs(steps) do
  local prefix=q[1]=='lookup-unloaded' and 'temp3=d@(sp);' or ''
  local report=string.format('logerror "RHANDLE label=%s stage=%%X handle=%%08X data=%%08X error=%%04X d0=%%08X sp=%%08X expectedsp=%%08X id=%%04X type=%%08X name0=%%08X name1=%%08X name2=%%08X name3=%%08X resload=%%02X\\n",temp0,temp3,(d@(temp3)&ffffff),w@a60,d0,sp,temp2%s,w@(temp2+80),d@(temp2+90),d@(temp2+100),d@(temp2+104),d@(temp2+108),d@(temp2+10c),b@a5e;',q[1],(q[1]=='lookup-unloaded' or q[1]=='named-unloaded' or q[1]=='lookup-enabled') and '-4' or '')
  if q[1]=='named-unloaded' or q[1]=='lookup-enabled' then report=report..'logerror "RHANDLE LOOKUP result=%08X expected=%08X\\n",d@(sp),temp3;' end
  if q[1]=='reload' then report=report..'save tmp/mac-loaded-resource.bin,(d@(temp3)&ffffff),fb;' end
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS resource handle capture complete\\n";quit'
  cpu.debug:bpset(base+0x3cde,string.format('temp0==0x%x',n),prefix..report..nextaction)
 end
 armed=true;print('ARM resource-handles Engine+$3CDC bytes=a820245f')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'RESOURCE HANDLES / LAUNCH FAILED');mac.wait(3600);error('RESOURCE HANDLES / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
