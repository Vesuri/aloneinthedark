-- CPU-only async ABI probe. Owns only .AITD Async Probe; deletes and flushes it.
-- Set AITD_ASYNC_CLOBBER=1 to test legal completion scratch-register clobbers.
local clobber=os.getenv("AITD_ASYNC_CLOBBER")=="1"
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'ASYNC / DEBUGGER REQUIRED')
local armed=false
emu.register_frame_done(function()
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 local base
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if j[1]==3 and mem:read_u16(e)==3 and mem:read_u16(e+2)==0x4ef9 then base=(mem:read_u32(e+4)&0xffffff)-j[2];break end
 end
 if not base then return end
 local sites={{0x3f54,0xa40c},{0x40e4,0xa660},{0x40fa,0xa660},{0x410c,0xa615},
  {0x411e,0xa614},{0x4134,0xa660},{0x414a,0xa660},{0x415c,0xa60a},
  {0x416e,0xa608},{0x4180,0xa60c},{0x4192,0xa60d}}
 for _,site in ipairs(sites) do
  assert(mem:read_u32(base+site[1])==(site[2]<<16|0x3e80),'ASYNC / CALLER BYTES')
 end
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'ASYNC / ORIGINAL BYTES')
 local function name(text)
  text=string.char(#text)..text;local out=''
  for i=1,#text do out=out..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
  return out
 end
 local h='d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;w@(a0+1c)=0;'
 local steps={
  {'hgetvol',0xa614,0,'d@(a0+12)=0;'},
  {'hgetvol-null',0xa614,0,'d@(a0+c)=0;d@(a0+12)=0;'},
  {'hgetvol-sync',0xa214,0,'d@(a0+12)=0;'},
  {'hsetvol',0xa615,0,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;'},
  {'hsetvol-error',0xa615,0,'d@(a0+12)=0;w@(a0+16)=1234;d@(a0+30)=temp1;'},
  {'getinfo',0xa40c,0,'d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+1c)=0;'},
  {'getinfo-sync',0xa00c,0,'d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+1c)=0;'},
  {'hgetinfo',0xa60c,0,h},
  {'hgetinfo-error',0xa60c,0,h..'w@(a0+16)=1234;'},
  {'getwd',0xa660,7,'d@(a0+12)=0;w@(a0+16)=0;w@(a0+1a)=0;'},
  {'getwd-error',0xa660,7,'d@(a0+12)=0;w@(a0+16)=1234;w@(a0+1a)=0;'},
  {'getfcb',0xa660,8,'w@(a0+16)=0;d@(a0+12)=0;w@(a0+18)=0;w@(a0+1c)=1;'},
  {'getfcb-error',0xa660,8,'d@(a0+12)=0;w@(a0+18)=0;w@(a0+1c)=0;'},
  {'openwd',0xa660,1,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;d@(a0+1c)=41495444;'},
  {'closewd-app',0xa660,2,''},
  {'closewd-app-sync',0xa260,2,''},
  {'openwd-root',0xa660,1,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=2;'},
  {'closewd-root',0xa660,2,''},
  {'openwd-new',0xa660,1,'d@(a0+12)=sp+200;'..name(':Alone Data:')..'w@(a0+16)=ffff;d@(a0+30)=temp1;d@(a0+1c)=41495444;'},
  {'closewd-new',0xa660,2,''},
  {'closewd-error',0xa660,2,''},
  {'openwd-error',0xa660,1,'d@(a0+12)=0;w@(a0+16)=1234;d@(a0+30)=temp1;'},
  {'create',0xa608,0,h..name('.AITD Async Probe')},
  {'create-error',0xa608,0,h},
  {'scratch-info',0xa60c,0,h},
  {'setinfo',0xa60d,0,h..'d@(a0+20)=54455354;d@(a0+24)=41495444;'},
  {'scratch-readback',0xa60c,0,h},
  {'setinfo-error',0xa60d,0,h..'w@(a0+16)=1234;'},
  {'openrf',0xa60a,0,h..'b@(a0+1b)=1;'},
  {'close',0xa001,0,''},
  {'openrf-error',0xa60a,0,h..'w@(a0+16)=1234;b@(a0+1b)=1;'},
  {'delete',0xa009,0,'d@(a0+12)=sp+200;w@(a0+16)=0;'},
  {'flush',0xa013,0,'d@(a0+12)=0;w@(a0+16)=ffff;'}
 }
 local function enter(n)
  local q=steps[n]
  return 'a0=temp6;d@(a0+c)=temp8;w@(a0+10)=7777;temp7=0;d1=11223344;d2=22334455;a1=33445566;'..q[4]..string.format('temp0=0x%x;d0=%x;w@(sp+400)=%x;pc=sp+400;g',n,q[3],q[2])
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;temp6=a0;temp8=sp+500;'
 for i=0,31 do setup=setup..string.format('d@(a0+%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=%x;w@(sp+500)=203c;d@(sp+502)=deadbeef;w@(sp+506)=223c;d@(sp+508)=aabbccdd;w@(sp+50c)=243c;d@(sp+50e)=bbccddee;w@(sp+512)=207c;d@(sp+514)=ccddee00;w@(sp+518)=227c;d@(sp+51a)=ddee0011;w@(sp+51e)=4e75;',base+0x4146)
 if not clobber then setup=setup..'w@(sp+500)=4e75;' end
 local text=string.char(17)..'Alone In The Dark'
 for i=1,#text do setup=setup..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..'bpset temp8,1,{temp7=temp7+1;logerror "ASYNC CALLBACK stage=%X d0=%08X result=%04X a0=%08X pb=%08X sr=%04X\\n",temp0,d0,w@(a0+10),a0,temp6,sr;g};'..enter(1))
 for n,q in ipairs(steps) do
  local report=string.format('logerror "ASYNC label=%s stage=%%X d0=%%08X result=%%04X completion=%%08X callbacks=%%X a0=%%08X pb=%%08X sr=%%04X d1=%%08X d2=%%08X a1=%%08X type=%%08X creator=%%08X volume=%%04X ref=%%04X id=%%08X\\n",temp0,d0,w@(temp6+10),d@(temp6+c),temp7,a0,temp6,sr,d1,d2,a1,d@(temp6+20),d@(temp6+24),w@(temp6+16),w@(temp6+18),d@(temp6+30);',q[1])
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS async capture complete\\n";quit'
  if q[1]=='create' or q[1]=='delete' or q[1]=='flush' then
   cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && w@(temp6+10)!=0',n),report..'logerror "FAIL async scratch ownership/cleanup\\n";quit')
   cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && w@(temp6+10)==0',n),report..nextaction)
  else
   cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x',n),report..nextaction)
  end
 end
 armed=true;print('ARM async bytes=7008a2606004 sites=11 clobber='..(clobber and '1' or '0'))
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'ASYNC / LAUNCH FAILED');mac.wait(3600);error('ASYNC / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
