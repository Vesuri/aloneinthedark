#include "../src/mac/SoundDriver.h"
#include "../src/mac/SoundEffect.h"
#include "../src/platform/amiga/VideoTiming.h"
#include <vector>
#include <cassert>
#include <cstring>
#include <cstdio>
#include <initializer_list>
int main() {
    SoundDriver statusDriver;uint16_t songResult=0x1234;uint32_t scratch=0x12345678;
    assert(statusDriver.songStatus(false,0,songResult,scratch));
    assert(songResult==0x1234 && scratch==0x12345678);
    assert(!statusDriver.initialize(6,2,2));
    struct StatusCase {bool enabled;uint16_t control;uint32_t tracks;uint16_t result;uint32_t scratch;};
    const StatusCase statusCases[]={
        {false,0x1234,1,0,0x12345678},{true,1,0,0xffff,0x12345678},
        {true,0,1,0xffff,23},{true,0,1UL<<23,0xffff,0},
        {true,0,0,0,0xffff},{true,0,1UL<<7,0xffff,16},{true,0,0,0,0xffff}};
    for(const auto& c:statusCases) {
        statusDriver.songControl=c.control;SoundDriver before=statusDriver;scratch=0x12345678;
        assert(!statusDriver.songStatus(c.enabled,c.tracks,songResult,scratch));
        assert(songResult==c.result && scratch==c.scratch);
        assert(SoundDriver::songStatusCCR(songResult)==(c.result ? 8 : 4));
        assert(!std::memcmp(&before,&statusDriver,sizeof(before)));
    }
    assert(statusDriver.songStatus(true,0x1000000,songResult,scratch));

    const uint32_t flagValues[]={0,1,0x8000,0x10000,0x80000000u,0x89abcdefu,0xffffffffu};
    const uint16_t flagResults[]={4,0,0,0,8,8,8};
    for(unsigned i=0;i<7;++i)assert(SoundDriver::clockCCR(flagValues[i])==flagResults[i]);
    SoundDriver clock;uint32_t value=0x13579bdf;
    assert(clock.clock(0,value) && value==0x13579bdf);
    assert(!clock.initialize(6,2,2,0xfffffff0u));
    const SoundDriver unchanged=clock;
    for(uint32_t delta:{0u,1u,60u,0x89abcdefu,0xffffffffu}) {
        assert(!clock.clock(0xfffffff0u+delta,value) && value==delta);
        assert(!std::memcmp(&clock,&unchanged,sizeof(clock)));
    }
    assert(!clock.quality(0x10b));assert(!clock.stopEffects());
    assert(!clock.clock(0x50,value) && value==96);
    clock.reset();assert(!clock.clockOrigin && clock.clock(0,value));

    // Raw effect data can resemble Vette's eight-byte header: do not strip it.
    std::vector<uint8_t> pcm(30783),converted(30786);
    for(unsigned i=0;i<pcm.size();++i)pcm[i]=(uint8_t)(i*17);
    pcm[6]=(uint8_t)((pcm.size()-8)>>8);pcm[7]=(uint8_t)(pcm.size()-8);
    PaulaSample::Layout layout;uint16_t period;uint32_t ticks;
    assert(!SoundEffect::describe(pcm.data(),pcm.size(),8000u<<16,0,0,layout,period,ticks,3546895));
    assert(layout.pcm==pcm.data() && layout.size==pcm.size() && layout.attackBytes==30784);
    assert(layout.allocated==30786 && layout.reloadOffset==30784 && layout.reloadBytes==2);
    assert(period==443 && ticks==231);
    PaulaSample::convert(layout,converted.data());
    for(unsigned i=0;i<pcm.size();++i)assert(converted[i]==(pcm[i]^0x80));
    assert(!converted[30783] && !converted[30784] && !converted[30785]);
    assert(SoundEffect::describe(pcm.data(),0,8000u<<16,0,0,layout,period,ticks,3546895));
    assert(SoundEffect::describe(pcm.data(),131071,8000u<<16,0,0,layout,period,ticks,3546895));
    assert(SoundEffect::describe(pcm.data(),4,(8000u<<16)|1,0,0,layout,period,ticks,3546895));
    assert(SoundEffect::describe(pcm.data(),4,1u<<16,0,0,layout,period,ticks,3546895));
    assert(SoundEffect::describe(pcm.data(),4,65535u<<16,0,0,layout,period,ticks,3546895));
    assert(SoundEffect::describe(pcm.data(),4,8000u<<16,1,3,layout,period,ticks,3546895));
    assert(SoundEffect::describe(pcm.data(),4,8000u<<16,0,0,layout,period,ticks,1));
    for(bool pal: {false,true}) {
        uint32_t clock=VideoTiming::paulaClock(pal);
        uint16_t remainder=0;uint32_t macTicks=0;
        for(unsigned fields=1;fields<=6000;++fields) {
            macTicks+=VideoTiming::tickDelta(pal,remainder);
            assert(macTicks==(pal ? fields*6/5 : fields));
        }
        assert(VideoTiming::startLine(pal)==(pal ? 72 : 44));
        assert(VideoTiming::stopLine(pal)==(pal ? 272 : 244));
        assert(VideoTiming::diwHigh(pal)==(pal ? 0x2100 : 0x2000));
        for(unsigned hz: {55u,8000u,11025u,22050u,28000u}) {
            assert(!SoundEffect::describe(pcm.data(),131070,hz<<16,0,0,layout,period,ticks,clock));
            assert(period==(clock+hz/2)/hz);
            uint64_t clocks=uint64_t(layout.attackBytes)*period*60;
            uint32_t exact=(clocks+clock-1)/clock;
            assert(ticks==exact);
        }
    }
    std::puts("PASS PAL/NTSC timing: 6000 fields, centred windows, raw PCM/padding and exact integer effect pitch/duration");
    SoundDriver driver;uint16_t status=0x1234;
    assert(driver.effectStatus(0x8000,status) && status==0x1234);
    assert(!driver.initialized);
    assert(!std::strcmp(driver.setSongControl(1),"NOT INITIALIZED") && !driver.songControl);
    assert(!std::strcmp(driver.stopEffects(),"NOT INITIALIZED"));
    assert(!std::strcmp(driver.quality(0x10b),"NOT INITIALIZED"));
    assert(!driver.initialized && !driver.requestedRate);
    for(unsigned field=0;field<3;++field) {
        assert(!std::strcmp(driver.initialize(field==0?4:6,field==1?1:2,field==2?4:2),"VOICE CONFIG"));
        assert(!driver.initialized && !driver.songLimit && !driver.normalizedLimit && !driver.effectLimit);
    }
    assert(!driver.initialize(6,2,2));
    assert(driver.initialized && driver.songLimit==6 && driver.normalizedLimit==2 && driver.effectLimit==2);
    assert(driver.requestedRate==22 && driver.interpolation==0);
    for(auto voice:driver.songs)assert(!voice.active && !voice.sample && voice.channel==-1);
    for(auto voice:driver.effects)assert(!voice.active && !voice.sample && voice.channel==-1);
    for(auto channel:driver.channels)assert(channel==-1);
    for(auto value:{0u,11u,22u,0x116u,0x30bu}) {
        assert(!std::strcmp(driver.quality(value),"QUALITY CONFIG"));
        assert(driver.requestedRate==22 && driver.interpolation==0);
    }
    assert(!driver.quality(0x10b));
    assert(driver.requestedRate==11 && driver.interpolation==1);
    driver.songs[0].active=1;driver.songs[0].sample=0x1234;driver.channels[0]=0;
    assert(!std::strcmp(driver.initialize(6,2,2),"REINITIALIZE"));
    assert(driver.songs[0].active==1 && driver.songs[0].sample==0x1234 && driver.channels[0]==0);
    driver.effects[0].active=1;driver.effects[0].sample=0x5678;
    driver.effectIds[0]=0x8000;driver.effectIds[1]=0x8000;
    assert(!driver.effectStatus(0x8000,status) && status==0);
    assert(!driver.effectStatus(0x1234,status) && status==1);
    driver.effects[0].active=0;driver.effects[1].active=1;
    assert(!driver.effectStatus(0x8000,status) && status==1);
    driver.effectIds[0]=0x1234;
    assert(!driver.effectStatus(0x8000,status) && status==0);
    driver.effects[0].active=1;
    driver.effects[1].active=1;driver.effects[1].sample=0x9abc;
    assert(!driver.stopEffects());
    assert(!driver.effects[0].active && !driver.effects[1].active);
    assert(!driver.effectStatus(0x8000,status) && status==1);
    assert(driver.effectIds[0]==0x1234 && driver.effectIds[1]==0x8000);
    assert(driver.effects[0].sample==0x5678 && driver.effects[1].sample==0x9abc);
    assert(driver.songs[0].active==1 && driver.songs[0].sample==0x1234 && driver.channels[0]==0);
    assert(driver.requestedRate==11 && driver.interpolation==1 && driver.initialized);
    assert(!driver.stopEffects());
    driver.effects[0].active=1;driver.effects[0].channel=2;
    assert(!std::strcmp(driver.stopEffects(),"EFFECT DMA STOP"));
    assert(driver.effects[0].active==1 && driver.effects[0].channel==2);
    SoundDriver expected=driver;
    for(uint32_t value:{0x12345678u,0xffff0000u,0xffffffffu,0u}) {
        assert(!driver.setSongControl(value));
        expected.songControl=(uint16_t)value;
        assert(!std::memcmp(&driver,&expected,sizeof(driver)));
    }
    assert(!driver.setSongControl(1));
    driver.reset();assert(!driver.songControl);
    assert(!driver.initialized && !driver.requestedRate && !driver.songLimit);
    for(auto voice:driver.songs)assert(!voice.active && !voice.sample && voice.channel==-1);
    for(auto channel:driver.channels)assert(channel==-1);
    assert(!driver.initialize(6,2,2));
    std::puts("PASS native driver state: initialization/quality, effect-stop isolation/idempotence and loud unsupported DMA rejection");
}
