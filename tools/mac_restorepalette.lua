-- Capture the original presentation palette replacement and query its binding.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RESTOREPAL / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('RESTOREPAL / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local function save(name,a,n)
 local f=assert(io.open('tmp/restorepal-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end

local armed=false;local done=false;local phase='entry';local args;local ret;local window;local palette;local old;local scratch;local stack;local saved={}
local function capture(label)
 local gd=ptr(ptr(0x8a4));local pm=ptr(ptr(gd+22));local ct=ptr(ptr(pm+42))
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('RESTOREPAL_%s sp=%X args=%s window=%X palette=%X default=%X',label,label=='ENTER' and args or cpu.state.A7.value,bytes(args,10),window,palette,ptr(0xdcc))..tail)
 for _,v in ipairs({{'window',window,156},{'windowpm',ptr(ptr(window+2)),50},{'gd',gd,62},{'pm',pm,50},{'clut',ct,2056},{'pixels',mem:read_u32(pm),307200},{'palette',ptr(palette),4112},{'private',ptr(ptr(ptr(palette)+12)),4},{'old',ptr(old),4112},{'old-private',ptr(ptr(ptr(old)+12)),4}})do save(label:lower()..'-'..v[1],v[2],v[3])end
 local video=assert(manager.machine.palettes[':nb9:mdc48']);local f=assert(io.open('tmp/restorepal-reference-'..label:lower()..'-hardware.bin','wb'));for i=0,255 do f:write(string.pack('>I4',video:pen_color(i)))end;f:close()
end
local function query(which)
 scratch=scratch or ((cpu.state.A7.value-16384)&0xfffffc);stack=scratch+8192
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xaa96);mem:write_u16(scratch+4,0x4e71)
 mem:write_u32(stack,window);mem:write_u32(stack+4,0)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch;phase=which;cpu.debug:bpset(scratch+4,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'RESTOREPAL / DISPATCHER')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xaa95 && (d@(sp+2)&0xffffff)=='..base(5)..'+0x214c','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='entry' then
  args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;window=ptr(args+6);palette=ptr(args+2);old=ptr((cpu.state.A5.value-0xb2a0)&0xffffffff)
  assert(window~=0 and palette~=0 and old~=0 and palette~=old,'RESTOREPAL / INPUT')
  print('RESTOREPAL_BYTES '..bytes(ret-16,16));capture('QUERY_BEFORE')
  for _,r in ipairs(regs)do saved[r]=cpu.state[r].value end
  for _,r in ipairs({'A7','PC','SR'})do saved[r]=cpu.state[r].value end
  dbg:command('bpclear');query('query-before')
 elseif phase=='query-before' then
  assert(cpu.state.A7.value==stack+4);print(string.format('RESTOREPAL_BINDING before=%X',ptr(cpu.state.A7.value)))
  dbg:command('bpclear');cpu.state.SR.value=saved.SR
  for _,r in ipairs(regs)do cpu.state[r].value=saved[r]end
  cpu.state.A7.value=saved.A7;cpu.state.PC.value=saved.PC
  for r,v in pairs(saved)do assert(cpu.state[r].value==v,'RESTOREPAL / QUERY REGISTER RESTORE')end
  capture('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 elseif phase=='return' then
  assert(cpu.state.PC.value==ret);capture('RETURN')
  for _,r in ipairs(regs)do saved[r]=cpu.state[r].value end
  for _,r in ipairs({'A7','PC','SR'})do saved[r]=cpu.state[r].value end
  dbg:command('bpclear');query('query-after')
 elseif phase=='query-after' then
  assert(cpu.state.A7.value==stack+4);print(string.format('RESTOREPAL_BINDING after=%X',ptr(cpu.state.A7.value)))
  dbg:command('bpclear');cpu.state.SR.value=saved.SR
  for _,r in ipairs(regs)do cpu.state[r].value=saved[r]end
  cpu.state.A7.value=saved.A7;cpu.state.PC.value=saved.PC
  for r,v in pairs(saved)do assert(cpu.state[r].value==v,'RESTOREPAL / POST QUERY RESTORE')end
  capture('QUERY_AFTER');phase='next'
  cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8ec && (d@(sp+2)&0xffffff)=='..base(10)..'+0x24d2','');dbg.execution_state='run'
 else
  local gd=ptr(ptr(0x8a4));local pm=ptr(ptr(gd+22));local ct=ptr(ptr(pm+42))
  save('next-pixels',mem:read_u32(pm),307200);save('next-clut',ct,2056)
  local video=assert(manager.machine.palettes[':nb9:mdc48']);local f=assert(io.open('tmp/restorepal-reference-next-hardware.bin','wb'));for i=0,255 do f:write(string.pack('>I4',video:pen_color(i)))end;f:close()
  done=true;print('PASS original palette restoration');dbg:command('quit')
 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('RESTOREPAL / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
