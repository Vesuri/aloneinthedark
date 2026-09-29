-- Observe original GetCTable and the game’s immediate table mutations. Normal mode does not patch original instructions, arguments or state; optional fixture uses scratch stack.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'GETCTABLE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('GETCTABLE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local fixture=os.getenv('AITD_CTABLE_FIXTURE')=='1'
local armed=false
local consoleSeen=0
emu.register_frame_done(function()
 -- Retain console errors: malformed debugger actions otherwise look like hangs.
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL ctable debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GETCTABLE / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local entered='temp8=temp8+1;temp0=sp+8;temp6='..base(7)..';logerror "CTABLE_ENTER sp=%X id=%X slot=%X bytes=%08X/%X'..regs..'\\n",temp0,w@temp0,d@(temp0+2),d@(temp6+0x110a),w@(temp6+0x110e)'..values..';'
 local returned='temp1=d@sp&0xffffff;temp2=d@temp1&0xffffff;logerror "CTABLE_RETURN sp=%X handle=%X master=%X body=%X seed=%X flags=%X size=%X'..regs..'\\n",sp,temp1,d@temp1,temp2,d@temp2,w@(temp2+4),w@(temp2+6)'..values..';save tmp/ctable-reference-return.bin,temp2,0x808;g'
 local mutated='logerror "CTABLE_MUTATED handle=%X body=%X seed=%X flags=%X size=%X count=%X\\n",d@(a4+0x20),d@(d@(a4+0x20)&0xffffff)&0xffffff,d@temp2,w@(temp2+4),w@(temp2+6),w@(a6-2);save tmp/ctable-reference-mutated.bin,temp2,0x808;logerror "PASS original GetCTable and mutations\\n";'
 if fixture then
  local steps={}
  local function add(label,trap,setup,after) steps[#steps+1]={label,trap,setup,after or ''} end
  local function save(label,handle) return 'save tmp/ctable-fixture-'..label..'.bin,d@('..handle..')&0xffffff,0x808;' end
  local function tablecall(label,extra,id)
   add(label,0xaa18,'sp=sp-6;w@sp='..(id or '0x80')..';d@(sp+2)=0xcccccccc;',extra)
  end
  local function resource(label,after) add(label,0xa9a0,'sp=sp-0xa;w@sp=0x80;d@(sp+2)=0x636c7574;d@(sp+6)=0xcccccccc;',after) end
  local function attrs(label,h) add(label,0xa9a6,'sp=sp-6;d@sp='..h..';w@(sp+4)=0xcccc;') end
  add('original-size',0xa025,'a0=temp1;')
  add('original-state',0xa069,'a0=temp1;')
  attrs('original-attrs','temp1')
  resource('resource','temp4=d@sp&0xffffff;'..save('source','temp4'))
  add('resource-size',0xa025,'a0=temp4;')
  add('resource-state',0xa069,'a0=temp4;')
  add('seed-before',0xaa28,'sp=sp-4;d@sp=0xcccccccc;')
  tablecall('second','temp5=d@sp&0xffffff;'..save('second','temp5'))
  add('seed-after',0xaa28,'sp=sp-4;d@sp=0xcccccccc;')
  add('second-state',0xa069,'a0=temp5;')
  attrs('second-attrs','temp5')
  add('mutate-second',0xa069,'w@((d@temp5&0xffffff)+0xa)=0x1234;a0=temp5;',save('second-mutated','temp5')..save('source-after-mutation','temp4'))
  tablecall('third','temp7=d@sp&0xffffff;'..save('third','temp7')..save('source-after-third','temp4'))
  resource('resource-again',save('source-again','d@sp&0xffffff'))
  add('source-state-again',0xa069,'a0=temp4;')
  add('dispose-second',0xa023,'a0=temp5;')
  add('original-survives',0xa025,'a0=temp1;')
  add('disposed-alias-size',0xa025,'a0=temp4;')
  add('third-survives',0xa025,'a0=temp7;')
  tablecall('missing','', '0x7ffe')
  add('seed-final',0xaa28,'sp=sp-4;d@sp=0xcccccccc;')
  local function enter(n)
   local q=steps[n]
   return 'sp=temp3;d0=0x12345678;w@0xa60=0x8888;w@0x220=0x7777;'..q[3]..string.format('temp9=0x%x;w@(temp3+0x400)=0x%x;',n,q[2])..
    'logerror "CTABLE_FIX_ENTER seq=%X sp=%X args=%08X/%08X/%08X'..regs..'\\n",temp9,sp,d@sp,d@(sp+4),d@(sp+8)'..values..';pc=temp3+0x400;g'
  end
  mutated=mutated..'sp=sp-0x800;temp3=sp;temp4=0;temp5=0;temp7=0;w@(temp3+0x402)=0x4ef9;d@(temp3+0x404)=temp6+0x114a;'..enter(1)
  for n,q in ipairs(steps) do
   local returned=q[4]..'logerror "CTABLE_FIX_RETURN label='..q[1]..' seq=%X sp=%X result=%X res=%X mem=%X original=%X resource=%X second=%X third=%X'..regs..'\\n",temp9,sp,d@sp,w@0xa60,w@0x220,temp1,temp4,temp5,temp7'..values..';'
   entered=entered..string.format('bpset temp6+0x114a,temp9==0x%x,{',n)..returned..(n<#steps and enter(n+1) or 'logerror "PASS GetCTable ownership fixture calls=%X\\n",temp9;quit')..'};'
  end
 else mutated=mutated..'quit' end
 entered=entered..'bpset temp6+0x1110,1,{'..returned..'};bpset temp6+0x114a,temp9==0,{'..mutated..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==0xaa18 && (d@(sp+2)&0xffffff)=='..base(7)..'+0x110e',entered)
 armed=true;print('ARM ctable dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'GETCTABLE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'GETCTABLE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('GETCTABLE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
