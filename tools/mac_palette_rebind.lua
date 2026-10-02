-- Rebind the actual presentation palette after its original default restore.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'REBIND / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('REBIND / SEGMENT')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local armed,done=false,false;local phase=0;local palette,window,old,ret,scratch,stack
local function save(label,name,a,n)
 local f=assert(io.open('tmp/rebind-reference-'..label..'-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local function capture(label)
 local pm=ptr(ptr(ptr(ptr(0x8a4))+22));local ct=ptr(ptr(pm+42))
 for _,v in ipairs({{'palette',ptr(palette),4112},{'private',ptr(ptr(ptr(palette)+12)),4},
                    {'old',ptr(old),4112},{'old-private',ptr(ptr(ptr(old)+12)),4},
                    {'clut',ct,2056},{'pixels',mem:read_u32(pm),307200}})do save(label,v[1],v[2],v[3])end
 print(string.format('REBIND_%s header=%X state=%X oldHeader=%X oldState=%X seed=%X sp=%X',label,mem:read_u32(ptr(palette)+4),mem:read_u32(ptr(palette)+8),mem:read_u32(ptr(old)+4),mem:read_u32(ptr(old)+8),mem:read_u32(ct),cpu.state.A7.value))
end
local function arm(offset)
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xaa95 && (d@(sp+2)&ffffff)=='..base(5)..'+'..string.format('%x',offset),'')
 dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'REBIND / DISPATCHER')
 armed=true;arm(0x20cc)
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  dbg:command('bpclear')
  if phase==0 then
   local args=cpu.state.A7.value+8;palette=ptr(args+2);window=ptr(args+6);old=ptr(0xdcc)
   assert(palette~=old and window~=0,'REBIND / FIRST BINDING');phase=1;arm(0x214c)
  elseif phase==1 then
   local args=cpu.state.A7.value+8
   assert(ptr(args+2)==old and ptr(args+6)==window,'REBIND / ORIGINAL RESTORE')
   ret=ptr(cpu.state.A7.value+2)+2;phase=2;cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  elseif phase==2 then
   assert(cpu.state.PC.value==ret,'REBIND / RESTORE RETURN');capture('enter')
   scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xaa95);mem:write_u16(scratch+4,0x4e71)
   mem:write_u16(stack,0x01a5);mem:write_u32(stack+2,palette);mem:write_u32(stack+6,window)
   cpu.state.A7.value=stack;cpu.state.PC.value=scratch;phase=3
   cpu.debug:bpset(scratch+4,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==scratch+4 and cpu.state.A7.value==stack+10,'REBIND / RETURN')
   capture('return');done=true;print('PASS original reactivated presentation palette');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('REBIND / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
