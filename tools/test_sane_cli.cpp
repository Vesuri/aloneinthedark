#include "../src/mac/Sane.h"
#include <array>
#include <cstdio>
#include <iostream>
#include <string>
int main() {
    unsigned op;std::string src,dst;
    while(std::cin>>std::hex>>op>>src>>dst) {
        if(src.size()!=24 || dst.size()!=24)return 1;
        std::array<uint8_t,12> s{},d{};
        for(unsigned i=0;i<12;++i) { s[i]=std::stoul(src.substr(i*2,2),nullptr,16);d[i]=std::stoul(dst.substr(i*2,2),nullptr,16); }
        bool ok=Sane::apply(op,s.data(),d.data());std::printf("%d ",ok);
        for(auto b:d)std::printf("%02x",b);
        std::puts("");
    }
}
