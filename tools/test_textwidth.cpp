#include "../src/mac/Times14Metrics.h"
#include <cassert>
#include <cstdio>
#include <cstring>
int main() {
    uint8_t text[32768]={};uint16_t out=0;
    assert(Times14Metrics::width(nullptr,0,0,out) && out==0);
    assert(!Times14Metrics::width(nullptr,0,1,out));
    assert(!Times14Metrics::width(text,-1,1,out));
    assert(!Times14Metrics::width(text,0,-1,out));
    for(unsigned c=0;c<256;++c) {
        memset(text,c,192);
        assert(Times14Metrics::width(text,0,1,out));printf("TW_CHAR code=%X width=%X\n",c,out);
        assert(Times14Metrics::width(text,0,192,out));printf("TW_REPEAT code=%X width=%X\n",c,out);
    }
    memcpy(text,"!Alone in the Dark",18);
    for(unsigned n=1;n<=17;++n) {
        assert(Times14Metrics::width(text,1,n,out));printf("TW_REPEAT code=%X width=%X\n",255+n,out);
    }
    assert(out==99); // Round the accumulated title, not each character.
    memset(text,'W',sizeof(text));assert(!Times14Metrics::width(text,0,32767,out));
}
