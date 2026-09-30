#include "../src/mac/CursorVisibility.h"
#include <cassert>
#include <iostream>
int main() {
    CursorVisibility state;
    char op;int visible,level,obscured,changed;unsigned count=0;
    while(std::cin>>op>>visible>>level>>obscured>>changed) {
        bool result=false;
        switch(op) {
        case 'I':state.init();break;
        case 'O':result=state.obscure();break;
        case 'H':assert(state.hide());break;
        case 'S':state.show();break;
        case 'M':state.moved();break;
        default:assert(false);
        }
        assert(state.visible()==bool(visible));assert(state.level==level);
        assert(state.obscured==bool(obscured));assert(result==bool(changed));++count;
    }
    assert(count==11);
    // Movement must not override explicit hiding, and a full hide count must not wrap.
    state.init();assert(state.hide());state.obscure();state.moved();assert(!state.visible());
    state.level=-32768;assert(!state.hide());assert(state.level==-32768);
    std::cout<<"PASS cursor visibility: eleven measured states, movement while hidden, overflow rejection\n";
}
