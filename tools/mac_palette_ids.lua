-- Measure reusable palette identifiers across allocation and disposal.
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
 local entered='temp0=sp+8;temp6='..base(5)..';temp3=d@(temp0+4)&0xffffff;temp4=d@temp3&0xffffff;logerror "PALETTE_ENTER sp=%X args=%08X/%08X/%08X/%04X source=%X body=%X'..regs..'\\n",temp0,d@temp0,d@(temp0+4),d@(temp0+8),w@(temp0+0xc),temp3,temp4'..values..';save tmp/palette129-serial-reference-source.bin,temp4,0x810;'
 local format,operands='',''
 for offset=0x2010,0x201c,2 do format=format..'%04X';operands=operands..string.format(',w@(temp6+0x%x)',offset) end
 entered=entered..'logerror "PALETTE_BYTES data='..format..'\\n"'..operands..';'
 local returned='temp1=d@sp&0xffffff;temp2=d@temp1&0xffffff;logerror "PALETTE_RETURN sp=%X handle=%X body=%X'..regs..'\\n",sp,temp1,temp2'..values..';save tmp/palette129-serial-reference-source-after.bin,temp4,0x810;'
 local serialReturn='temp8=d@sp&0xffffff;temp9=d@temp8&0xffffff;logerror "PAL129_SERIAL n=%X handle=%X header=%08X/%08X/%08X\\n",temp7,temp8,d@temp9,d@(temp9+4),d@(temp9+8);'
 local create='sp=temp5;sp=sp-0xe;w@sp=0;w@(sp+2)=0xa;d@(sp+4)=temp3;w@(sp+8)=0x100;d@(sp+0xa)=0;w@(temp5+0x400)=0xaa91;pc=temp5+0x400;g'
 returned=returned..'logerror "PAL129_ORIGINAL header=%08X/%08X/%08X\\n",d@temp2,d@(temp2+4),d@(temp2+8);sp=sp-0x4000;temp5=sp;temp7=1;w@(temp5+0x402)=0x4e71;'
 returned=returned..'bpset temp5+0x402,temp7==1,{'..serialReturn..'sp=temp5-4;d@sp=temp8;w@(temp5+0x400)=0xaa93;temp7=2;pc=temp5+0x400;g};'
 returned=returned..'bpset temp5+0x402,temp7==2,{logerror "PAL129_DISPOSE d0=%X mem=%X\\n",d0,w@0x220;temp7=3;'..create..'};'
 returned=returned..'bpset temp5+0x402,temp7==3,{'..serialReturn..'temp6=temp8;sp=temp5-4;d@sp=temp1;w@(temp5+0x400)=0xaa93;temp7=4;pc=temp5+0x400;g};'
 returned=returned..'bpset temp5+0x402,temp7==4,{logerror "PAL129_DISPOSE_ORIGINAL d0=%X mem=%X\\n",d0,w@0x220;temp7=5;'..create..'};'
 returned=returned..'bpset temp5+0x402,temp7==5,{'..serialReturn..'logerror "PAL129_RETAINED header=%08X\\n",d@((d@temp6&0xffffff)+4);logerror "PASS palette creation serial after disposal\\n";quit};'..create
 entered=entered..'bpset temp6+0x201e,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==0xaa91 && (d@(sp+2)&0xffffff)=='..base(5)..'+0x201c',entered)
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
