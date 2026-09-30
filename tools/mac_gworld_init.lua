-- Original offscreen initialization: eight calls and their owned drawing records.
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
local armed=false
local offsets={0x8e,0x98,0xa8,0xb0,0xbe,0xcc,0xd4,0x114}
local step=1;local returning=false;local world,pmh,pixelh
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function dump(label,a,n)
 local f=assert(io.open('tmp/gworld-init-reference-'..label..'.bin','wb'))
 local bytes={};for i=0,n-1 do bytes[#bytes+1]=string.char(mem:read_u8(a+i)) end
 f:write(table.concat(bytes));f:close()
end
local function arm()
 dbg:command('bpclear')
 dbg:command('bpset 0xdd60,'..cond..' && (d@(sp+2)&0xffffff)=='..base(10)..string.format('+0x%x',offsets[step]))
end
emu.register_frame_done(function()
 if step<0 or armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GWINIT / DISPATCHER BYTES')
 arm();armed=true
end)
emu.register_periodic(function()
 if not armed or dbg.execution_state~='stop' then return end
 local sp=cpu.state.SP.value&0xffffff
 local phase=returning and 'after' or 'before'
 local offset=offsets[step]
 local pc=returning and cpu.state.PC.value or ptr(sp+2)
 if not returning then sp=sp+8 end
 if not world then
  world=ptr(sp+4);pmh=ptr(world+2);pixelh=ptr(ptr(pmh))
  dump('original-code',pc-offset+0x76,0xa0)
 end
 local label=string.format('%03X-%s',offset,phase):lower()
 local registers=""
 for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}) do registers=registers..string.format(' %s=%08X',r,cpu.state[r].value) end
 print(string.format('GWINIT offset=%X phase=%s sp=%X pc=%X world=%X pmh=%X pixelh=%X pixelState=%X currentDevice=%X',offset,phase,sp,pc,world,pmh,pixelh,mem:read_u32(pixelh)>>24,ptr(0xcc8))..registers)
 dump(label..'-stack',sp,32);dump(label..'-port',world,108);dump(label..'-pm',ptr(pmh),50)
 local gd=ptr(ptr(ptr(world+8))+26)
 dump(label..'-device',ptr(gd),62);dump(label..'-device-pm',ptr(ptr(ptr(gd)+22)),50)
 local clip=ptr(ptr(world+28));dump(label..'-clip',clip,mem:read_u16(clip))
 dump(label..'-pixels',ptr(pixelh),261452)
 if returning then
  step=step+1
  if step>#offsets then armed=false;step=-1;print('PASS original offscreen initialization');dbg:command('quit');return end
  returning=false;arm()
 else
  returning=true;dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',pc+2))
 end
 dbg.execution_state='run'
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'GWINIT / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'GWINIT / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('GWINIT / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
