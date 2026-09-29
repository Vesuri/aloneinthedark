-- Capture the original NewPalette request/return, then query its size in scratch code.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PALETTE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('PALETTE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'PALETTE / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp6='..base(7)..';temp3=d@(temp0+4)&0xffffff;temp4=d@temp3&0xffffff;logerror "PALETTE_ENTER sp=%X args=%08X/%08X/%08X/%04X source=%X body=%X'..regs..'\\n",temp0,d@temp0,d@(temp0+4),d@(temp0+8),w@(temp0+0xc),temp3,temp4'..values..';save tmp/palette-reference-source.bin,temp4,0x808;'
 local format,operands='',''
 for offset=0x114a,0x116e,2 do format=format..'%04X';operands=operands..string.format(',w@(temp6+0x%x)',offset) end
 entered=entered..'logerror "PALETTE_BYTES data='..format..'\\n"'..operands..';'
 local returned='temp1=d@sp&0xffffff;temp2=d@temp1&0xffffff;logerror "PALETTE_RETURN sp=%X handle=%X body=%X'..regs..'\\n",sp,temp1,temp2'..values..';save tmp/palette-reference-source-after.bin,temp4,0x808;'
 local fixture=os.getenv('AITD_PALETTE_FIXTURE')=='1'
 if fixture then
  local steps={
   {'palette-size',0xa025,'a0=temp1;','save tmp/palette-reference-body.bin,temp2,d0;'},
   {'palette-state',0xa069,'a0=temp1;',''},
   {'source-size',0xa025,'a0=temp3;',''},
   {'source-state',0xa069,'a0=temp3;',''},
   {'private-size',0xa025,'a0=temp7;','save tmp/palette-reference-private.bin,d@temp7&0xffffff,d0;'},
   {'palette-attrs',0xa9a6,'sp=sp-6;d@sp=temp1;w@(sp+4)=0xcccc;',''},
   {'mutate-source',0xa069,'w@(temp4+0xa)=0x1234;a0=temp1;','save tmp/palette-reference-source-mutated.bin,temp4,0x808;save tmp/palette-reference-after-source.bin,temp2,0x1010;'},
   {'mutate-palette',0xa069,'w@(temp2+0x10)=0x5678;a0=temp3;','save tmp/palette-reference-mutated.bin,temp2,0x1010;save tmp/palette-reference-source-after-palette.bin,temp4,0x808;'},
   {'dispose-palette',0xaa93,'sp=sp-4;d@sp=temp1;',''},
   {'source-survives',0xa025,'a0=temp3;','save tmp/palette-reference-source-survives.bin,temp4,0x808;'},
   {'disposed-palette-size',0xa025,'a0=temp1;',''},
   {'disposed-private-size',0xa025,'a0=temp7;',''}
  }
  local function enter(n)
   local q=steps[n]
   return 'sp=temp5;d0=0x12345678;w@0xa60=0x8888;w@0x220=0x7777;'..q[3]..string.format('w@(temp5+0x400)=0x%x;temp9=0x%x;',q[2],n)..
    'logerror "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X'..regs..'\\n",temp9,w@(temp5+0x400),sp,d@sp,d@(sp+4)'..values..';pc=temp5+0x400;g'
  end
  returned=returned..'temp7=d@(temp2+0xc)&0xffffff;logerror "PALETTE_PRIVATE handle=%X body=%X\\n",temp7,d@temp7&0xffffff;sp=sp-0x800;temp5=sp;w@(temp5+0x402)=0x4e71;'
  for n,q in ipairs(steps) do
   returned=returned..string.format('bpset temp5+0x402,temp9==0x%x,{',n)..q[4]..
    'logerror "PALETTE_FIX_RETURN label='..q[1]..' seq=%X sp=%X result=%X res=%X mem=%X'..regs..'\\n",temp9,sp,d@sp,w@0xa60,w@0x220'..values..';'..
    (n<#steps and enter(n+1) or 'logerror "PASS NewPalette ownership fixture calls=C\\n";quit')..'};'
  end
  returned=returned..enter(1)
 else
  -- A scratch instruction queries the allocated extent without resuming original code.
  returned=returned..'sp=sp-0x800;temp5=sp;w@(temp5+0x400)=0xa025;w@(temp5+0x402)=0x4e71;a0=temp1;pc=temp5+0x400;bpset temp5+0x402,1,{logerror "PALETTE_SIZE size=%X mem=%X\\n",d0,w@0x220;save tmp/palette-reference-body.bin,temp2,d0;logerror "PASS original NewPalette capture\\n";quit};g'
 end
 entered=entered..'bpset temp6+0x115a,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==0xaa91 && (d@(sp+2)&0xffffff)=='..base(7)..'+0x1158',entered)
 armed=true;print('ARM palette dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'PALETTE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'PALETTE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('PALETTE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
