-- Original startup menu-list reset, insertions and suppressed redraw contract.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'MENU LIST / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('MENU LIST / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local armed=false;local step=1;local returning=false;local fixture=false
local offsets={0x2b06,0x2b32,0x2b32,0x2b32,0x2b32,0x2b44};local segment,menu,scratch
local menus={}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function dump(label,a,n)
 local f=assert(io.open('tmp/menulist-reference-'..label..'.bin','wb'))
 local bytes={};for i=0,n-1 do bytes[#bytes+1]=string.char(mem:read_u8(a+i)) end
 f:write(table.concat(bytes));f:close()
end
local function menuSize(body)
 local at=15+mem:read_u8(body+14)
 for i=1,128 do local n=mem:read_u8(body+at);if n==0 then return at+1 end;at=at+1+n+4 end
 error('MENU LIST / MALFORMED RECORD')
end
local function arm()
 dbg:command('bpclear')
 dbg:command('bpset 0xdd60,'..cond..' && (d@(sp+2)&0xffffff)=='..base(7)..string.format('+0x%x',offsets[step]))
end
emu.register_frame_done(function()
 if armed or step<0 or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'MENU LIST / DISPATCHER BYTES')
 arm();armed=true
end)
emu.register_periodic(function()
 if not armed or step<0 or dbg.execution_state~='stop' then return end
 local sp=cpu.state.SP.value&0xffffff;local pc=cpu.state.PC.value
 if not returning and not fixture then pc=ptr(sp+2);sp=sp+8 end
 if not segment then segment=pc-offsets[step];dump('original-code',segment+0x2b04,0x42) end
 local phase=returning and 'after' or 'before';local label=tostring(step)..'-'..phase
 local args=step>=2 and step<=5 and not returning
 if args then menu=ptr(sp+2);menus[step-1]=menu else menu=0 end
 local regs='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}) do regs=regs..string.format(' %s=%08X',r,cpu.state[r].value) end
 print(string.format('MLIST seq=%X phase=%s sp=%X pc=%X menu=%X id=%X before=%X list=%X body=%X',step,phase,sp,pc,menu,menu~=0 and mem:read_u16(ptr(menu)) or 0,args and mem:read_u16(sp) or 0,ptr(0xa1c),ptr(ptr(0xa1c)))..regs)
 dump(label..'-list',ptr(ptr(0xa1c)),128)
 local list=ptr(ptr(0xa1c));local count=mem:read_u16(list)//6
 assert(count<16,'MENU LIST / EXTENT')
 for i=0,count-1 do
  local h=ptr(list+6+i*6);local body=ptr(h)
  print(string.format('MLIST_ENTRY seq=%X phase=%s index=%X handle=%X id=%X',step,phase,i,h,mem:read_u16(body)))
  dump(label..'-entry'..tostring(i),body,menuSize(body))
 end
 for i,h in ipairs(menus) do dump(label..'-menu'..tostring(i),ptr(h),menuSize(ptr(h))) end
 if step==6 then
  local f=assert(io.open('tmp/menulist-reference-'..label..'-client.bin','wb'))
  for y=150,349 do local row={};for x=160,479 do row[#row+1]=string.char(mem:read_u8(0xf9000a00+y*640+x)) end;f:write(table.concat(row)) end;f:close()
 end
 if returning then
  if step==7 then step=-1;print('PASS original menu-list lifecycle');dbg:command('quit');return end
  step=step+1;returning=false
  if step==7 then
   -- Measure nonempty reset with the same four live original menu handles.
   fixture=true;scratch=sp-0x400;mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa934);mem:write_u16(scratch+4,0x4e71)
   dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',scratch+2))
   dbg:command(string.format('sp=0x%x;pc=0x%x',scratch-0x100,scratch))
  else arm() end
 else
  returning=true;dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',pc+2))
 end
 dbg.execution_state='run'
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'MENU LIST / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'MENU LIST / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('MENU LIST / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
