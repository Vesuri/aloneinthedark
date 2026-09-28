#include <cassert>
#include <cstdio>
#include <cstring>
#include "../src/mac/MacFiles.h"
int main() {
    MacFiles c;c.reset();assert(c.count()==1 && c.entry(2)->parent==1);
    c.application=c.add(2,"Game","PROGDIR:",true);
    c.data=c.add(c.application,"Alone Data","data",true);
    c.system=c.add(2,"System Folder","",true);
    auto file=c.add(c.data,"ITD_RESS.PAK","data/ITD_RESS.PAK",false,123456,765);
    uint32_t id=999;
    assert(c.resolve(0,0,":Alone Data:itd_ress.pak",id)==0 && id==(uint32_t)file);
    assert(c.resolve(0,0,"Alone:Game:Alone Data:",id)==0 && id==c.data);
    assert(c.resolve(0,c.data,"::",id)==0 && id==c.application);
    assert(c.resolve(0,2,"::",id)==c.dirNFErr);
    assert(c.resolve(0,c.data,":ITD_RESS.PAK:",id)==c.dirNFErr);
    assert(c.resolve(0,0,":Alone Movies:",id)==c.fnfErr);
    assert(c.resolve(0,0,":Unexpected:",id)==c.unsupported);
    assert(c.resolve(0,c.data,"MISSING.PAK",id)==c.fnfErr);
    assert(c.resolve(0,c.data,"\xff",id)==c.unsupported);
    assert(c.resolve(0,0,"\xff:Game:",id)==c.unsupported);
    assert(c.resolve(22,0,"",id)==c.nsvErr);
    assert(c.resolve(0,file,"",id)==c.dirNFErr);
    assert(c.resolve(-1,0,"",id)==0 && id==2);
    bool created=false;
    auto wd=c.openWD(c.data,0x41495444,&created);assert(created);
    assert(c.directoryFor(wd,id)==0 && id==c.data);
    assert(c.wdProcess(wd)==0x41495444);
    assert(c.resolve(wd,0,"itd_ress.pak",id)==0 && id==(uint32_t)file);
    assert(c.openWD(c.data,0x41495444,&created)==wd && !created);
    assert(c.openWD(c.data,0x41495445)!=wd);
    assert(c.setDefault(wd)==0 && c.defaultRef()==wd);
    assert(c.resolve(0,0,"itd_ress.pak",id)==0 && id==(uint32_t)file);
    assert(c.setDefault(42)==c.nsvErr && c.defaultRef()==wd);
    assert(c.setDefault(0)==0 && c.defaultRef()==wd);
    assert(c.setDefault(wd,"Alone")==0 && c.defaultRef()==wd);
    assert(c.setDefault(c.volumeRef,"Unknown")==c.unsupported && c.defaultRef()==wd);
    assert(c.setDefault(c.volumeRef)==0 && c.directoryFor(0,id)==0 && id==2);
    assert(c.closeWD(wd)==0 && c.directoryFor(wd,id)==c.nsvErr);
    assert(c.closeWD(wd)==c.nsvErr);
    assert(c.openWD(file,0)==c.dirNFErr);
    assert(c.openWD(2,0)==c.volumeRef);
    auto r=c.open(file,true,true), d=c.open(file,false,false);
    assert(r>0 && d>0 && r!=d && c.fork(0)==nullptr);
    assert(c.fork(r)->resource && c.fork(r)->writable && c.fork(r)->position==0);
    assert(c.entry(c.fork(r)->id)->resourceSize==765);
    assert(!c.fork(d)->resource && !c.fork(d)->writable);
    assert(c.entry(c.fork(d)->id)->dataSize==123456);
    assert(c.seek(d,1,65530)==0 && c.fork(d)->position==65530);
    assert(c.seek(d,3,-30)==0 && c.fork(d)->position==65500);
    assert(c.seek(d,2,-7)==0 && c.fork(d)->position==123449);
    assert(c.seek(d,1,-1)==-40 && c.fork(d)->position==123449);
    assert(c.seek(d,3,0x7fffffff)==-39 && c.fork(d)->position==123456);
    assert(c.seek(d,1,(int32_t)0x80000000)==-40 && c.fork(d)->position==123456);
    assert(c.seek(d,9,0)==c.unsupported);
    assert(c.seek(0,1,0)==c.rfNumErr);
    assert(c.close(r)==0 && !c.fork(r) && c.close(r)==c.rfNumErr);
    assert(c.open(c.data,false,false)==c.fnfErr);
    for(int i=1;i<c.maxOpen;++i)assert(c.open(file,false,false)>0);
    assert(c.open(file,false,false)==-42);
    auto n=c.count();
    assert(c.add(c.data,"itd_ress.pak","",false)==c.paramErr);
    assert(c.add(c.data,"bad:name","",false)==c.paramErr);
    assert(c.add(file,"child","",false)==c.paramErr);
    assert(c.add(c.data,"abcdefghijklmnopqrstuvwxyz123456","",false)==c.unsupported);
    char path[161];memset(path,'x',160);path[160]=0;
    assert(c.add(c.data,"too-long-path",path,false)==c.unsupported);
    assert(c.count()==n);
    for(int i=n;i<c.maxEntries;++i) { char name[32];snprintf(name,sizeof(name),"entry%d",i);assert(c.add(c.data,name,"",false)>0); }
    assert(c.add(c.data,"overflow","",false)==c.unsupported && c.count()==c.maxEntries);
    c.reset();c.application=c.add(2,"Game","",true);
    for(int i=0;i<c.maxWD;++i) { auto w=c.openWD(c.application,i);assert(c.directoryFor(w,id)==0); }
    assert(c.openWD(c.application,99)==c.unsupported);
    c.reset();assert(c.count()==1 && c.fork(d)==nullptr && c.directoryFor(wd,id)==c.nsvErr);
    puts("PASS mac-files: paths, fork identity, working directories, errors, atomic capacity limits");
}
