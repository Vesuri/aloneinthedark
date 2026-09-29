-- Original eight-bit NewGWorld request and complete drawing records.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'NEWGWORLD / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('NEWGWORLD / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'NEWGWORLD / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp6='..base(10)..';temp9=d@(temp0+0x12)&0xffffff;temp8=d@(temp0+0xc)&0xffffff;temp7=d@(temp0+8)&0xffffff;'
 entered=entered..'logerror "GW_ENTER sp=%X flags=%X device=%X ctable=%X bounds=%X depth=%X output=%X result=%X zone=%X'..regs..'\\n",temp0,d@temp0,d@(temp0+4),temp7,temp8,w@(temp0+0x10),temp9,w@(temp0+0x16),d@0x118'..values..';'
 entered=entered..'save tmp/gworld-reference-bounds.bin,temp8,8;temp7=d@temp7&0xffffff;save tmp/gworld-reference-input-clut.bin,temp7,8+(w@(temp7+6)+1)*8;'
 entered=entered..'save tmp/gworld-reference-before-device.bin,d@(d@0x8a4&ffffff)&ffffff,0x3e;'
 local fmt,args='',''
 for x=0x50,0x74,2 do fmt=fmt..'%04X';args=args..string.format(',w@(temp6+0x%x)',x) end
 entered=entered..'logerror "GW_BYTES data='..fmt..'\\n"'..args..';'
 local returned='temp1=d@temp9&0xffffff;temp2=d@(temp1+2)&0xffffff;temp3=d@temp2&0xffffff;temp4=d@(temp3+0x2a)&0xffffff;temp5=d@temp4&0xffffff;'
 returned=returned..'logerror "GW_RETURN sp=%X result=%X world=%X pmHandle=%X pm=%X clutHandle=%X clut=%X base=%X baseLong=%X zone=%X currentDevice=%X'..regs..'\\n",sp,w@sp,temp1,temp2,temp3,temp4,temp5,d@temp3,d@(d@temp3&ffffff),d@0x118,d@0xcc8'..values..';'
 returned=returned..'save tmp/gworld-reference-port.bin,temp1,0x6c;save tmp/gworld-reference-pm.bin,temp3,0x32;save tmp/gworld-reference-clut.bin,temp5,8+(w@(temp5+6)+1)*8;save tmp/gworld-reference-base.bin,d@temp3&ffffff,0x20;'
 for _,reg in ipairs({{'visibility',0x18},{'clip',0x1c}}) do returned=returned..string.format('temp8=d@(d@(temp1+0x%x)&ffffff)&ffffff;save tmp/gworld-reference-%s.bin,temp8,w@temp8;',reg[2],reg[1]) end
 returned=returned..'save tmp/gworld-reference-after-device.bin,d@(d@0x8a4&ffffff)&ffffff,0x3e;'
 entered=entered..'bpset temp6+0x76,1,{'..returned..'}'
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xab1d && (d@(sp+2)&0xffffff)=='..base(10)..'+0x74',entered)
 armed=true
end)
local stage=0
local queries,index,world,scratch=nil,0,nil,nil
emu.register_periodic(function()
 if not armed or stage<0 or dbg.execution_state~='stop' then return end
 if stage>=2 then
  if not queries then
   local function ptr(a) return mem:read_u32(a)&0xffffff end
   world=ptr(cpu.state.A0.value);local pmh=ptr(world+2);local pm=ptr(pmh)
   queries={{'pixmap',pmh},{'pixels',ptr(pm)},{'ctable',ptr(pm+42)},{'visibility',ptr(world+24)},{'clip',ptr(world+28)},{'grafvars',ptr(world+8)},{'backpat',ptr(world+32)},{'penpat',ptr(world+58)},{'fillpat',ptr(world+62)}}
   for _,pat in ipairs({{'backpat',32},{'penpat',58},{'fillpat',62}}) do
    local body=ptr(ptr(world+pat[2]))
    for _,child in ipairs({{'map',2},{'data',6},{'xdata',10},{'xmap',16}}) do
     queries[#queries+1]={pat[1]..'-'..child[1],ptr(body+child[2])}
    end
   end
   queries[#queries+1]={'grafvars-child',ptr(ptr(ptr(world+8))+26)}
   for _,pat in ipairs({{'backpat',32},{'penpat',58},{'fillpat',62}}) do
    local patmap=ptr(ptr(ptr(ptr(world+pat[2]))+2))
    queries[#queries+1]={pat[1]..'-table',ptr(patmap+42)}
   end
   local gd=ptr(ptr(ptr(ptr(world+8))+26))
   queries[#queries+1]={'device-map',ptr(gd+22)}
   queries[#queries+1]={'device-table',ptr(ptr(ptr(gd+22))+42)}
   queries[#queries+1]={'device-inverse',ptr(gd+6)}
   scratch=(cpu.state.SP.value&0xffffff)-0x400
   mem:write_u16(scratch,0xa025);mem:write_u16(scratch+2,0xa069);mem:write_u16(scratch+4,0xa126);mem:write_u16(scratch+6,0x4e71)
  end
  index=index+1
  if index>#queries then stage=-1;print('PASS original NewGWorld ownership');dbg:command('quit');return end
  local label,h=table.unpack(queries[index]);assert(h~=0,'NEWGWORLD / MISSING AUX HANDLE')
  dbg:command('bpclear')
  dbg:command(string.format('bpset 0x%x,1,{logerror "GW_AUX label=%s handle=%%X body=%%X size=%%X memerr=%%X\\n",0x%x,d@0x%x&ffffff,d0,w@0x220;save tmp/gworld-reference-aux-%s.bin,d@0x%x&ffffff,d0;g}',scratch+2,label,h,h,label,h))
  dbg:command(string.format('bpset 0x%x,1,{logerror "GW_FLAGS label=%s flags=%%X memerr=%%X\\n",d0&ff,w@0x220;g}',scratch+4,label))
  dbg:command(string.format('bpset 0x%x,1,{logerror "GW_OWNER label=%s owner=%%X zone=%%X memerr=%%X\\n",a0,d@0x118,w@0x220}',scratch+6,label))
  dbg:command(string.format('a0=0x%x;pc=0x%x;sp=0x%x;g',h,scratch,scratch-0x100))
  return
 end
 local phase=stage==0 and 'before' or 'after'
 local f=assert(io.open('tmp/gworld-reference-'..phase..'-pixels.bin','wb'))
 for y=0,479 do
  local row={};for x=0,639 do row[#row+1]=string.char(mem:read_u8(0xf9000a00+y*640+x)) end
  f:write(table.concat(row))
 end
 f:close();stage=stage+1
 if stage==2 then print('PASS original NewGWorld allocation') else dbg.execution_state='run' end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'NEWGWORLD / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'NEWGWORLD / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('NEWGWORLD / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
