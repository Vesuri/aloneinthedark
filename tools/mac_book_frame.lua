-- Capture the same original decreasing book-fold positions as book_profile.gdb.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'BOOK / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('BOOK / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local function ptr(a)return mem:read_u32(a)&0xffffff end
local first=tonumber(os.getenv('AITD_BOOK_COLUMN') or '160')
assert(first==160 or first==260,'BOOK / UNSUPPORTED STATE')
local prefix=first==260 and 'book-first-reference-' or 'book-reference-'
local function save(name,a,n)
 local f=assert(io.open('tmp/'..prefix..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local armed=false;local done=false;local column=first
local function arm()
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xaa14 && (d@(sp+2)&ffffff)=='..base(13)..'+0xb46 && (d@(a6+4)&ffffff)=='..base(12)..string.format('+0x3fba && (d7&ffff)==0x%x',column),'')
 dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'BOOK / DISPATCHER')
 armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  local pc=ptr(cpu.state.A7.value+2);local caller=ptr(cpu.state.A6.value+4)
  assert(mem:read_u32(pc-4)==0x486effea and mem:read_u16(pc)==0xaa14,'BOOK / LINE BYTES')
  assert(mem:read_u16(caller-6)==0x4eb9 and ptr(caller-4)==(cpu.state.A5.value+0x46a)&0xffffff,'BOOK / CALLER BYTES')
  local pm=ptr(ptr(ptr(ptr(0x8a4))+22));local ct=ptr(ptr(pm+42))
  assert(mem:read_u16(pm+32)==8 and mem:read_u16(ct+6)==255,'BOOK / SCREEN FORMAT')
  local row=mem:read_u16(pm+4)&0x3fff;assert(row==640,'BOOK / STRIDE')
  local phase=column==first and 'begin' or 'end'
  save(phase..'-screen',mem:read_u32(pm),307200);save(phase..'-clut',ct,2056)
  print(string.format('BOOK_REFERENCE column=%u row=%u pc=%X caller=%X',column,row,pc,caller))
  dbg:command('bpclear')
  if column==first then column=first-10;arm()else done=true;print(string.format('PASS original book frame positions=%u/%u',first,first-10));dbg:command('quit')end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(7200);error('BOOK / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
