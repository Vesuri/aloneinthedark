-- Ordinary-input room-4 combat recovery measured against the original game.
-- Actor scene coordinates are read only; no game/system memory is written.
return function(mac,mem,world,actor,objects,vars,move,align,report)
  local function faceLive(target,label)
   local delta=(target-mem:read_i16(actor+0x2a))&1023
   if delta>16 and delta<1008 then
    move(delta>512 and 'Left Arrow' or 'Right Arrow',label,function()local d=(target-mem:read_i16(actor+0x2a))&1023;return d<=16 or d>=1008 end)
   end
  end
  mac.key_down('o');mac.wait(120);mac.key_up('o')
  assert(mac.wait_for('live actual Open/Search',function()return mem:read_i16(vars+180)==64 end,1200),'live door action')
  faceLive(256,'live-door-east')
  if mem:read_i16(actor+0x30)==5 and mem:read_i16(actor+0x1c)<-1800 then
   move('Up Arrow','live-door-clear-or-room4',function()return mem:read_i16(actor+0x30)==4 or (mem:read_i16(actor+0x30)==5 and mem:read_i16(actor+0x1c)>=-1800)end)
  end
  if mem:read_i16(actor+0x30)==5 then
   faceLive(512,'live-room5-south')
   move('Up Arrow','live-room5-safe-z',function()return mem:read_i16(actor+0x20)>=900 end)
   align('z',900,1050,true)
   faceLive(768,'live-room5-west')
   move('Up Arrow','live-room4-entry',function()return mem:read_i16(actor+0x30)==4 end)
  end
  assert(mem:read_i16(actor+0x30)==4 and mem:read_i16(vars+42)>0 and mem:read_i16(vars+114)>0,'living room4 with active enemy')
  report('live-recovery-room4')
  mac.key_down('f');mac.wait(120);mac.key_up('f')
  assert(mac.wait_for('living room4 Fight',function()return mem:read_i16(vars+180)==16 and mem:read_i16(actor+0x3e)==4 end,1200),'room4 Fight')
  assert(mem:read_i16(actor+0x30)==4 and mem:read_i16(vars+42)>0,'living actual room4 Fight')
  report('live-recovery-resumed-fight')
  for attempt=1,30 do
   if mem:read_i16(vars+114)<=0 then break end
   assert(mem:read_i16(vars+42)>0,'living recovery combat')
   local slot=mem:read_i16(objects+62*52);assert(slot>=0 and slot<50,'actual enemy slot')
   local npc=world-0xb292+slot*160
   local heroRoom=mem:read_i16(actor+0x30);local enemyRoom=mem:read_i16(npc+0x30)
   -- Both actors' scene-space positions are retained alongside room-local coordinates.
   local dx=mem:read_i16(npc+0x22)-mem:read_i16(actor+0x22)
   local dz=mem:read_i16(npc+0x26)-mem:read_i16(actor+0x26)
   assert(mem:read_i16(npc+0x2e)==1 and mem:read_i16(actor+0x2e)==1,'same actual floor')
   local angle=math.floor(math.atan(dx,-dz)*1024/(2*math.pi)+0.5)&1023
   local target=(math.floor((angle+64)/128)*128)&1023
   print(string.format('RECOVERY_AIM attempt=%d room=%d enemyRoom=%d dx=%d dz=%d target=%d hp=%d enemyHp=%d',attempt,heroRoom,enemyRoom,dx,dz,target,mem:read_i16(vars+42),mem:read_i16(vars+114)))
   faceLive(target,'live-recovery-aim-'..attempt)
   if math.max(math.abs(dx),math.abs(dz))>700 then
    move('Up Arrow','live-recovery-approach-'..attempt,function()
     return math.max(math.abs(mem:read_i16(npc+0x22)-mem:read_i16(actor+0x22)),math.abs(mem:read_i16(npc+0x26)-mem:read_i16(actor+0x26)))<=800 or mem:read_i16(vars+114)<=0
    end)
   end
   mac.key_down('Space');mac.key_down('Up Arrow')
   for _=1,12000 do
    if mem:read_i16(vars+114)<=0 then break end
    if mem:read_i16(vars+42)<=0 then mac.key_up('Space');mac.key_up('Up Arrow');report('live-recovery-hero-lost');error('living recovery combat')end
    mac.wait(1)
   end
   mac.key_up('Space');mac.key_up('Up Arrow')
   assert(mac.wait_for('recovery kick released',function()return mem:read_i16(actor+0x3e)==4 or mem:read_i16(vars+42)<=0 end,1800),'recovery manual control')
   mac.wait(30);report('live-recovery-kick-'..attempt)
  end
  assert(mem:read_i16(vars+114)<=0 and mem:read_i16(vars+42)>0,'living actual recovery victory')
  assert(mac.wait_for('recovery actual enemy removal and manual control',function()
   assert(mem:read_i16(vars+42)>0,'living removal')
   return mem:read_i16(objects+62*52)==-1 and mem:read_i16(actor+0x3e)==4 and mem:read_i16(actor+0x52)==1
  end,1800),'recovery enemy removal')
  report('live-recovery-victory')
  mac.key_down('o');mac.wait(120);mac.key_up('o')
  report('live-recovery-open-request');assert(mem:read_i16(vars+42)>0 and (mem:read_i16(vars+180)==64 or mem:read_i16(vars+180)==16),'actual living Search or retained Fight')
  if mem:read_i16(actor+0x30)==4 then
   if mem:read_i16(actor+0x20)>1050 or mem:read_i16(actor+0x20)<650 then faceLive(0,'live-room4-postcombat-north')end
   if mem:read_i16(actor+0x30)==4 then
    align('z',650,1050,false);report('live-postcombat-door-aligned');assert(mem:read_i16(vars+42)>0 and mem:read_i16(actor+0x30)==4 and mem:read_i16(actor+0x20)>=650 and mem:read_i16(actor+0x20)<=1050,'living post-combat connecting-door corridor')
    faceLive(256,'live-postcombat-east');mac.key_down('Shift');move('Up Arrow','live-postcombat-room5',function()return mem:read_i16(actor+0x30)==5 end);mac.key_up('Shift')
   end
  end
  assert(mem:read_i16(actor+0x30)==5 and mem:read_i16(vars+42)>0 and mem:read_i16(vars+114)<=0,'actual living room5 recovered after enemy removal')
  report('live-recovery-room5-after-victory');mac.key_down('o');mac.wait(120);mac.key_up('o');assert(mac.wait_for('safe room5 actual Open/Search',function()return mem:read_i16(vars+180)==64 or mem:read_i16(vars+42)<=0 end,1200) and mem:read_i16(vars+42)>0 and mem:read_i16(vars+180)==64,'living room5 Search');report('live-recovery-room5-search')
end
