#include <stdint.h>
#include <assert.h>
#include <fstream>
#include <iterator>
#include <vector>
#include <string>
#include <stdio.h>
#include "../src/mac/Times36Text.h"
static std::vector<uint8_t> read(const std::string& name) {
    std::ifstream in(name,std::ios::binary);assert(in);
    return std::vector<uint8_t>(std::istreambuf_iterator<char>(in),{});
}
int main(int argc,char** argv) {
    assert(argc==2);std::string dir=argv[1];
    auto before=read(dir+"/pause-before.bin"),after=read(dir+"/pause-after.bin");
    auto port=read(dir+"/pause-port.bin"),pm=read(dir+"/pause-pm.bin");
    auto vis=read(dir+"/pause-region24.bin"),clip=read(dir+"/pause-region28.bin");
    assert(before.size()==307200 && after.size()==before.size());
    const uint8_t text[]="The game is paused!";uint8_t dirty[8];uint16_t width=0;
    assert(Times36Text::width(text,0,sizeof(text)-1,width) && width==294);
    auto draw=[&](std::vector<uint8_t>& pixels,const uint8_t* clipping) {
        int16_t pen=int16_t(RectBounds::word(port.data()+50));
        assert(Times36Text::draw(pixels.data(),pixels.size(),640,pm.data()+6,port.data()+16,
            vis.data()+2,clipping,text,0,sizeof(text)-1,int16_t(RectBounds::word(port.data()+48)),pen,dirty));
        assert(pen==307);
    };
    auto actual=before;draw(actual,clip.data()+2);assert(actual==after);
    int changed=0;
    for(int y=0;y<480;++y)for(int x=0;x<640;++x)if(before[y*640+x]!=after[y*640+x]) {
        ++changed;int localX=x-160,localY=y-150;
        assert(localY>=int16_t(RectBounds::word(dirty)) && localY<int16_t(RectBounds::word(dirty+4)));
        assert(localX>=int16_t(RectBounds::word(dirty+2)) && localX<int16_t(RectBounds::word(dirty+6)));
    }
    assert(changed>100);
    uint8_t limited[]={0,65,0,30,0,80,0,200};actual=before;draw(actual,limited);
    for(int y=0;y<480;++y)for(int x=0;x<640;++x)
        assert(actual[y*640+x]==((y>=215 && y<230 && x>=190 && x<360) ? after[y*640+x] : before[y*640+x]));
    uint8_t empty[8]={};actual=before;draw(actual,empty);assert(actual==before);
    for(uint8_t v:dirty)assert(v==0);
    int16_t pen=13;actual=before;uint8_t control[]={1};
    assert(!Times36Text::draw(actual.data(),actual.size(),640,pm.data()+6,port.data()+16,vis.data()+2,clip.data()+2,control,0,1,81,pen,dirty));
    assert(actual==before && pen==13);
    puts("PASS Times36 compiled renderer: original buffer and pen exact; clip, dirty bounds and rejected input checked");
}
