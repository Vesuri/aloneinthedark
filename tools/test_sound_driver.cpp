#include "../src/mac/SoundDriver.h"
#include <cassert>
#include <cstring>
#include <cstdio>
#include <initializer_list>
int main() {
    SoundDriver driver;
    assert(!driver.initialized);
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
    driver.reset();assert(!driver.initialized && !driver.requestedRate && !driver.songLimit);
    for(auto voice:driver.songs)assert(!voice.active && !voice.sample && voice.channel==-1);
    for(auto channel:driver.channels)assert(channel==-1);
    assert(!driver.initialize(6,2,2));
    std::puts("PASS native driver state: measured initialization/quality; unsupported configurations preserve state");
}
