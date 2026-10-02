-- Measure the real 8-bit QuickDraw cursor over every palette index.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'CURSOR / DEBUGGER REQUIRED')
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local function ptr(a)return mem:read_u32(a)&0xffffff end
local armed,done=false,false;local phase='entry';local step=0
local scratch,stack,shape,pixels,clut,x,y
local traps={0xa850,0xa852,0xa851,0xa853}
local function save(label,kind,a,n)
 local f=assert(io.open('tmp/cursor-invert-reference-'..label..'-'..kind..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local function capture(label)
 save(label,'pixels',pixels,307200);save(label,'clut',clut,2056)
 print(string.format('CURSOR_INVERT phase=%s x=%d y=%d visible=%u level=%d obscured=%u',label,x,y,mem:read_u8(0x8cc),mem:read_i16(0x8d0),mem:read_u8(0x8d2)))
end
local function call(trap)
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,trap);mem:write_u16(scratch+4,0x4e71)
 if trap==0xa851 then mem:write_u32(stack,shape)end
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch
 cpu.debug:bpset(scratch+4,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02,'CURSOR / DISPATCHER')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa856','');armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  dbg:command('bpclear')
  if phase=='entry' then
   local pm=ptr(ptr(ptr(ptr(0x8a4))+22));clut=ptr(ptr(pm+42));pixels=mem:read_u32(pm)
   assert(mem:read_u16(pm+32)==8 and (mem:read_u16(pm+4)&0x3fff)==640 and mem:read_u16(clut+6)==255,'CURSOR / EIGHT BIT DEVICE')
   scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192;shape=scratch+256
   for i=0,67 do mem:write_u8(shape+i,i<32 and 255 or 0)end
   save('fixture','shape',shape,68)
   phase='calls';step=1;call(traps[step])
  elseif phase=='calls' then
   assert(cpu.state.PC.value==scratch+4,'CURSOR / TRAP RETURN')
   assert(cpu.state.A7.value==stack+(traps[step]==0xa851 and 4 or 0),'CURSOR / STACK CLEANUP')
   if step==2 then
    assert(mem:read_i16(0x8d0)==-1,'CURSOR / HIDDEN')
    x=mem:read_i16(0x82e);y=mem:read_i16(0x82c)
    assert(x>=0 and x<=624 and y>=0 and y<=464,'CURSOR / FIXTURE BOUNDS')
    for row=0,15 do for col=0,15 do mem:write_u8(pixels+(y+row)*640+x+col,row*16+col)end end
    capture('hidden')
   end
   step=step+1
   if step<=#traps then call(traps[step])
   else
    mem:write_u16(scratch+4,0x60fe);phase='settle';dbg.execution_state='run'
   end
  elseif phase=='capture' then
   assert(cpu.state.PC.value==scratch+4,'CURSOR / SETTLED RETURN')
   capture('visible');phase='restore';call(0xa852)
  elseif phase=='restore' then
   assert(cpu.state.PC.value==scratch+4 and cpu.state.A7.value==stack,'CURSOR / HIDE RETURN')
   capture('restored');done=true;print('PASS original 256-index cursor inversion and restoration');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  for i=1,3600 do if phase=='settle' then break end;mac.wait(1)end
  assert(phase=='settle','CURSOR / FIXTURE DEADLINE');mac.wait(4)
  phase='capture';cpu.debug:bpset(scratch+4,'1','')
 end)
 if not ok and not done then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
