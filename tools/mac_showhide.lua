-- Capture original ShowHide visibility, regions, palette and display effects.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'WINDOW PALETTE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('WINDOW PALETTE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local events={{0x0fc6,0xa908,'showhide',2}}
local function dump(label,phase)
 local out='temp1=d@0xdcc&0xffffff;temp2=d@temp1&0xffffff;temp3=d@(temp2+0xc)&0xffffff;temp4=d@(d@0x8a4&0xffffff)&0xffffff;temp5=d@(d@(temp4+0x16)&0xffffff)&0xffffff;temp7=d@(d@(temp5+0x2a)&0xffffff)&0xffffff;'
 out=out..'logerror "SH_STATE label='..label..' phase='..phase..' window=%X palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\\n",temp9,temp1,temp2,temp3,d@temp3&0xffffff,temp4,temp5,temp7;'
 for _,item in ipairs({{'palette','temp2',0x1010},{'private','d@temp3&0xffffff',4},{'window','temp9',0x9c},{'gd','temp4',0x3e},{'pm','temp5',0x32},{'clut','temp7',0x808}}) do
  out=out..string.format('save tmp/showhide-reference-%s-%s-%s.bin,%s,0x%x;',label,phase,item[1],item[2],item[3])
 end
 out=out..'save tmp/showhide-reference-'..label..'-'..phase..'-windowpm.bin,d@(d@(temp9+2)&0xffffff)&0xffffff,0x32;'
 for _,region in ipairs({{'visibility',0x18},{'clip',0x1c},{'structure',0x72},{'content',0x76},{'update',0x7a}}) do
  out=out..string.format('temp8=d@(d@(temp9+0x%x)&0xffffff)&0xffffff;',region[2])
  out=out..'save tmp/showhide-reference-'..label..'-'..phase..'-'..region[1]..'.bin,temp8,w@temp8;'
 end
 return out
end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'WINDOW PALETTE / DISPATCHER BYTES')
 for _,event in ipairs(events) do
  local off,trap,label,windowOffset=table.unpack(event)
  local entered='temp0=sp+8;temp6='..base(9)..string.format(';temp9=d@(temp0+0x%x)&0xffffff;',windowOffset)
  entered=entered..'logerror "SH_ENTER label='..label..' sp=%X args=%08X%08X%08X'..regs..'\\n",temp0,d@temp0,d@(temp0+4),d@(temp0+8)'..values..';'..dump(label,'before')
  entered=entered..string.format('logerror "SH_SITE label=%s offset=%%X opcode=%%X\\n",0x%x,w@(temp6+0x%x);',label,off,off)
  local start,finish=0x0fb4,0x0fc8
  local fmt,ops='',''
  for offset=start,finish-2,2 do fmt=fmt..'%04X';ops=ops..string.format(',w@(temp6+0x%x)',offset) end
  entered=entered..'logerror "SH_BYTES label='..label..' data='..fmt..'\\n"'..ops..';'
  local returned='logerror "SH_RETURN label='..label..' sp=%X'..regs..'\\n",sp'..values..';'..dump(label,'after')
  entered=entered..string.format('bpset temp6+0x%x,1,{',off+2)..returned..'}'
  cpu.debug:bpset(0xdd60,appcond..string.format(' && w@(d@(sp+2))==0x%x && (d@(sp+2)&0xffffff)==',trap)..base(9)..string.format('+0x%x',off),entered)
 end
 armed=true;print('ARM window palette state dispatcher bytes=2f0a2f02246f000a')
end)
local stage=0
emu.register_periodic(function()
 if not armed or dbg.execution_state~='stop' or stage>=2 then return end
 local ok,err=pcall(function()
  local event=events[stage//2+1];local label=event[3];local phase=stage%2==0 and 'before' or 'after'
  local pc=cpu.state.PC.value
  if phase=='before' then assert(pc==0xdd60,'WINDOW PALETTE / ENTRY CHECKPOINT') end
  local function ptr(a) return mem:read_u32(a)&0xffffff end
  local pm=ptr(ptr(ptr(ptr(0x8a4))+0x16));local address=mem:read_u32(pm)
  assert(address==0xf9000a00 and mem:read_u16(pm+4)==0x8280 and mem:read_u16(pm+32)==8,'WINDOW PALETTE / VIDEO LAYOUT')
  local prefix='tmp/showhide-reference-'..label..'-'..phase
  local f=assert(io.open(prefix..'-physical.bin','wb'))
  for y=0,479 do local row={};for x=0,639 do row[#row+1]=string.char(mem:read_u8(address+y*640+x)) end;f:write(table.concat(row)) end
  f:close();local palette=assert(manager.machine.palettes[':nb9:mdc48'])
  f=assert(io.open(prefix..'-hardware.bin','wb'));for i=0,255 do f:write(string.pack('>I4',palette:pen_color(i))) end;f:close()
  print(string.format('SH_PHYSICAL label=%s phase=%s pc=%X base=%X bytes=307200 hardware=256 mouse=%X',label,phase,pc,address,mem:read_u32(0x82c)))
  stage=stage+1
  if stage==2 then print('PASS original ShowHide calls=1');dbg:command('quit') else dbg.execution_state='run' end
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'WINDOW PALETTE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'WINDOW PALETTE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('WINDOW PALETTE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
