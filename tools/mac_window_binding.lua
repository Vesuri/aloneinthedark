-- Observe original SetPalette binding and device state; query its private extent and binding in scratch code.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SETPALETTE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('SETPALETTE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local armed=false
local function dump(phase)
 local out='temp2=d@temp1&0xffffff;temp3=d@(temp2+0xc)&0xffffff;temp4=d@(d@0x8a4&0xffffff)&0xffffff;temp7=d@(d@(temp4+0x16)&0xffffff)&0xffffff;temp8=d@(d@(temp7+0x2a)&0xffffff)&0xffffff;'
 out=out..'logerror "WSET_STATE phase='..phase..' palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\\n",temp1,temp2,temp3,d@temp3&0xffffff,temp4,temp7,temp8;'
 for _,item in ipairs({{'private','d@temp3&0xffffff',4},{'palette','temp2',0x1010},{'gd','temp4',0x3e},{'pm','temp7',0x32},{'clut','temp8',0x808}}) do
  out=out..string.format('save tmp/windowpalette-reference-%s-%s.bin,%s,0x%x;',phase,item[1],item[2],item[3])
 end
 out=out..'save tmp/windowpalette-reference-'..phase..'-window.bin,temp9,0x9c;'
 out=out..'logerror "WSET_ADDRESS phase='..phase..' base=%X logical=%X physical=%X low=%X default=%X\\n",d@temp7,d@(d@temp7+0x3cc),ppd@(d@temp7+0x3cc),d@0xdcc,d@0xdcc;'
 return out
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'SETPALETTE / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp6='..base(9)..';temp1=d@(temp0+2)&0xffffff;temp9=d@(temp0+6)&0xffffff;logerror "WSET_ENTER sp=%X args=%04X/%08X/%08X'..regs..'\\n",temp0,w@temp0,d@(temp0+2),d@(temp0+6)'..values..';'
 local format,operands='',''
 for offset=0x10e8,0x10fa,2 do format=format..'%04X';operands=operands..string.format(',w@(temp6+0x%x)',offset) end
 entered=entered..'logerror "WSET_BYTES data='..format..'\\n"'..operands..';'..dump('before')
 local returned='logerror "WSET_RETURN sp=%X'..regs..'\\n",sp'..values..';'..dump('after')
 returned=returned..'sp=sp-0x2000;temp5=sp;w@(temp5+0x400)=0xa025;w@(temp5+0x402)=0x4e71;a0=temp3;pc=temp5+0x400;'
 local size='logerror "WSET_PRIVATE_SIZE size=%X mem=%X\\n",d0,w@0x220;save tmp/windowpalette-reference-private.bin,d@temp3&0xffffff,d0;'
 size=size..'sp=temp5-8;d@sp=temp9;d@(sp+4)=0;w@(temp5+0x410)=0xaa96;w@(temp5+0x412)=0x60fe;logerror "WSET_QUERY sp=%X argument=%X result=%X opcode=%X\\n",sp,d@sp,d@(sp+4),w@(temp5+0x410);pc=temp5+0x410;g'
 returned=returned..'bpset temp5+0x402,d0==0 || d0>0x10000,{logerror "FAIL SETPALETTE / PRIVATE SIZE\\n";quit};bpset temp5+0x402,d0>0 && d0<=0x10000,{'..size..'};bpset temp5+0x412,1,{logerror "WSET_BINDING palette=%X result=%X sp=%X expected=%X opcode=%X\\n",temp1,d@sp,sp,temp5-4,w@(temp5+0x410);logerror "PASS original window SetPalette capture\\n";quit}'
 entered=entered..'bpset temp6+0x10fc,1,{'..returned..'}'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==0xaa95 && (d@(sp+2)&0xffffff)=='..base(9)..'+0x10fa',entered)
 armed=true;print('ARM windowpalette dispatcher bytes=2f0a2f02246f000a')
end)

local pixelStage=0
emu.register_periodic(function()
 if not armed or dbg.execution_state~='stop' or pixelStage>=2 then return end
 local pc=cpu.state.PC.value
 if pixelStage==0 and pc~=0xdd60 then return end
 local ok,err=pcall(function()
  if pixelStage==1 then assert(mem:read_u16(pc)==0xa025,'SETPALETTE / AFTER CHECKPOINT') end
  local function ptr(a) return mem:read_u32(a)&0xffffff end
  local pm=ptr(ptr(ptr(ptr(0x8a4))+0x16))
  local address=mem:read_u32(pm)
  assert(address==0xf9000a00 and mem:read_u16(pm+4)==0x8280 and mem:read_u16(pm+32)==8,'SETPALETTE / VIDEO LAYOUT')
  local phase=pixelStage==0 and 'before' or 'after'
  local f=assert(io.open('tmp/windowpalette-reference-'..phase..'-physical.bin','wb'))
  for y=0,479 do
   local row={}
   for x=0,639 do row[#row+1]=string.char(mem:read_u8(address+y*640+x)) end
   f:write(table.concat(row))
  end
  f:close()
  local palette=assert(manager.machine.palettes[':nb9:mdc48'])
  f=assert(io.open('tmp/windowpalette-reference-'..phase..'-hardware.bin','wb'))
  for i=0,255 do f:write(string.pack('>I4',palette:pen_color(i))) end
  f:close()
  print(string.format('WSET_PHYSICAL phase=%s pc=%X base=%X bytes=307200 hardware=256',phase,pc,address))
  pixelStage=pixelStage+1
  dbg.execution_state='run'
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'SETPALETTE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'SETPALETTE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('SETPALETTE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
