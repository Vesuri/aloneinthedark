-- Observe original Apple Event registrations; optional scratch-stack table fixture.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'APPLE EVENTS / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('APPLE EVENTS / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local function dump(label,address,count)
 local format,args='',''
 for i=0,count-1 do format=format..'%08X';args=args..string.format(',d@((%s)+0x%x)',address,i*4) end
 return 'logerror "'..label..' seq=%X data='..format..'\\n",temp8'..args..';'
end
local fixture=os.getenv('AITD_AE_FIXTURE')=='1'
local armed=false
local consoleSeen=0
emu.register_frame_done(function()
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL apple-events debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'APPLE EVENTS / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 for _,offset in ipairs({0x1038,0x1056,0x1074,0x1092}) do
  local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(7)..';logerror "AE_ENTER seq=%X site=%X sp=%X selector=%X engine=%X'..regs..'\\n",temp8,'..string.format('0x%x',offset)..',temp0,d0&ffff,temp6'..values..';'..dump('AE_ARGS','temp0',5)..'logerror "AE_BYTES seq=%X selector=%X trap=%X\\n",temp8,w@(d@(sp+2)-2),w@(d@(sp+2));'
  local returned='logerror "AE_RETURN seq=%X sp=%X result=%X'..regs..'\\n",temp8,sp,w@sp'..values..';'
  if offset==0x1092 then
   returned=returned..'logerror "PASS original Apple Event registrations calls=%X\\n",temp8;'
   if fixture then
    local cases={}
    local function add(label,selector,class,id,handler,refcon,sys)
     cases[#cases+1]={label,selector,class,id,handler,refcon,sys or 0}
    end
    for _,id in ipairs({'6f617070','70646f63','6f646f63','71756974'}) do add('original-'..id,0x0921,'61657674',id) end
    add('absent',0x0921,'61697464','70726231')
    add('install',0x091f,'61697464','70726231','a5+0xac2','0x12345678')
    add('get-installed',0x0921,'61697464','70726231')
    add('replace-refcon',0x091f,'61697464','70726231','a5+0xac2','0xcafebabe')
    add('get-refcon',0x0921,'61697464','70726231')
    add('replace-handler',0x091f,'61697464','70726231','a5+0xaca','0xaabbccdd')
    add('get-handler',0x0921,'61697464','70726231')
    add('other-class',0x0921,'61697465','70726231')
    add('system-separate',0x0921,'61697464','70726231',nil,nil,1)
    add('null-handler',0x091f,'61697464','70726231','0','0')
    add('get-after-null',0x0921,'61697464','70726231')
    add('odd-handler',0x091f,'61697464','70726231','a5+0xac3','0')
    add('get-after-odd',0x0921,'61697464','70726231')
    local function enter(n)
     local q=cases[n]
     return 'sp=temp2-0x14;d@(temp2+0x100)=0xdeadbeef;d@(temp2+0x104)=0xcccccccc;d@(temp2+0x108)=0xdddddddd;d@(temp2+0x10c)=0xfacefeed;'..
      string.format('w@sp=0x%x;d@(sp+2)=%s;d@(sp+6)=%s;d@(sp+0xa)=0x%s;d@(sp+0xe)=0x%s;w@(sp+0x12)=0xeeee;d0=0x%x;temp9=0x%x;',q[7]*256,q[6] or 'temp2+0x108',q[5] or 'temp2+0x104',q[4],q[3],q[2],n)..
      'temp0=sp;logerror "AE_FIX_ENTER seq=%X sp=%X selector=%X'..regs..'\\n",temp9,sp,d0'..values..';logerror "AE_FIX_ARGS seq=%X data=%08X%08X%08X%08X%08X\\n",temp9,d@sp,d@(sp+4),d@(sp+8),d@(sp+0xc),d@(sp+0x10);pc=temp2+0x400;g'
    end
    returned=returned..'sp=sp-0x800;temp2=sp;w@(temp2+0x400)=0xa816;w@(temp2+0x402)=0x4ef9;d@(temp2+0x404)=temp6+0x1094;'..enter(1)
    for n,q in ipairs(cases) do
     local row='logerror "AE_FIX_RETURN label='..q[1]..' seq=%X sp=%X result=%X before=%X handler=%X refcon=%X after=%X'..regs..'\\n",temp9,sp,w@sp,d@(temp2+0x100),d@(temp2+0x104),d@(temp2+0x108),d@(temp2+0x10c)'..values..';'
     entered=entered..string.format('bpset temp6+0x1094,temp9==0x%x,{',n)..row..(n<#cases and enter(n+1) or 'logerror "PASS Apple Event table fixture calls=%X\\n",temp9;quit')..'};'
    end
   else returned=returned..'quit' end
  else returned=returned..'g' end
  entered=entered..string.format('bpset temp6+0x%x,temp9==0,{',offset+2)..returned..'};g'
  cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==0xa816 && (d@(sp+2)&ffffff)=='..base(7)..string.format('+0x%x',offset),entered)
 end
 armed=true;print('ARM apple-events dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'APPLE EVENTS / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'APPLE EVENTS / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('APPLE EVENTS / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
