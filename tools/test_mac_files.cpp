#include <cassert>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include "../src/mac/MacFiles.h"
static void indexedFiles() {
    MacFiles c;c.reset();c.application=c.add(2,"Game","PROGDIR:",true);
    c.data=c.add(c.application,"Alone Data","PROGDIR:data",true);
    // Reverse ASCII insertion makes catalog allocation order irrelevant.
    for(int ch=126;ch>=32;--ch)if(!(ch>='a' && ch<='z') && ch!='/' && ch!=':') {
        char name[]={'i',(char)ch,'x',0};assert(c.add(c.data,name,"PROGDIR:fixture",false)>0);
    }
    assert(c.add(c.data,"iBdir","",true)>0);
    const char* order=" !\"#$%&'()*+,-.0123456789;<=>?@A`BCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_{|}~";
    uint32_t id=0;int n=0;
    for(;order[n];++n) {
        assert(!c.indexedFile(-1,c.data,n+1,id));assert(c.entry(id)->name[1]==order[n]);
    }
    assert(n==67 && c.indexedFile(-1,c.data,68,id)==-43);
    assert(c.indexedFile(-1,9999,1,id)==-43 && c.indexedFile(99,c.data,1,id)==-35);
    assert(c.indexedFile(-1,c.application,1,id)==c.unsupported);
    assert(c.resolve(-1,c.application,"Missing",id)==c.unsupported);
    c.applicationComplete=true;
    assert(c.indexedFile(-1,c.application,1,id)==-43);
    assert(c.resolve(-1,c.application,"Missing",id)==-43);
    auto appfile=c.add(c.application,"App","PROGDIR:App",false);
    assert(!c.indexedFile(-1,c.application,1,id) && id==(uint32_t)appfile);
    assert(!c.resolve(-1,c.application,"app",id) && id==(uint32_t)appfile);
    assert(c.indexedFile(-1,c.application,2,id)==-43);
    c.system=c.add(2,"System Folder","",true);
    assert(c.resolve(-1,c.system,"Unknown",id)==c.unsupported);
    assert(c.resolve(-1,2,"Unknown",id)==c.unsupported);
    assert(c.indexedFile(-1,c.system,1,id)==c.unsupported);
    assert(c.indexedFile(-1,2,1,id)==c.unsupported);
    assert(c.indexedFile(-1,c.data,0,id)==c.unsupported);
    auto first=c.child(c.data,"i x")->id;assert(!c.remove(first));
    assert(!c.indexedFile(-1,c.data,1,id) && c.entry(id)->name[1]=='!');
    assert(c.add(c.data,"control\x1f","",false)==c.unsupported);
}
static void dualForks() {
    MacFiles c;c.reset();c.application=c.add(2,"Game","PROGDIR:",true);
    auto app=c.add(c.application,"App","PROGDIR:App",false,0,123,true);
    auto file=c.add(c.application,"Save","PROGDIR:Save",false,0,0);
    char path[192];
    assert(!c.forkPath(app,false,path,sizeof(path)) && !strcmp(path,"PROGDIR:App.data"));
    assert(!c.forkPath(app,true,path,sizeof(path)) && !strcmp(path,"PROGDIR:App"));
    assert(!c.forkPath(file,false,path,sizeof(path)) && !strcmp(path,"PROGDIR:Save"));
    assert(!c.forkPath(file,true,path,sizeof(path)) && !strcmp(path,"PROGDIR:Save.rsrc"));
    assert(c.forkPath(file,true,path,8)==c.unsupported);
    int16_t data=0,resource=0,conflict=0;
    assert(!c.openFork(file,false,3,false,data) && !c.openFork(file,true,3,false,resource) && data!=resource);
    assert(c.openFork(file,true,3,false,conflict)==-49 && conflict==resource);
    assert(!c.setSize(data,5,true) && !c.setSize(resource,9,true));
    assert(c.entry(file)->dataSize==5 && c.entry(file)->resourceSize==9);
    assert(!c.seek(data,1,3) && !c.seek(resource,1,7));
    assert(c.fork(data)->position==3 && c.fork(resource)->position==7);
    c.flushed(file,true);assert(c.fork(data)->modified && !c.fork(resource)->modified);
    assert(c.canRemove(file)==-47 && !c.close(data) && c.canRemove(file)==-47);
    assert(!c.close(resource) && !c.remove(file));
}
static void catalogLifetime() {
    MacFiles c;c.reset();c.application=c.add(2,"Game","PROGDIR:",true);
    c.data=c.add(c.application,"Alone Data","PROGDIR:data",true);
    MacFiles::Entry plan={};
    assert(c.planCreate(0,0,":Alone Data:Save.ITD",plan)==0);
    assert(plan.parent==c.data && !strcmp(plan.name,"Save.ITD") && !strcmp(plan.path,"PROGDIR:data/Save.ITD"));
    uint16_t before=c.count();
    auto id=c.add(plan.parent,plan.name,plan.path,false);
    assert(id>0 && c.count()==before+1 && c.entry(id)->dataSize==0 && c.entry(id)->resourceSize==0);
    assert(!c.entry(id)->metadataKnown);
    FileMetadata::Record info={};info.created=0xabcd0102;info.modified=0xabcd0304;info.finder[0]='T';
    assert(c.setMetadata(id,info)==0 && c.entry(id)->metadataKnown && c.entry(id)->metadata.modified==0xabcd0304);
    assert(c.planCreate(0,c.data,"save.itd",plan)==-48);
    auto ref=c.open(id,false,true);assert(ref>0 && c.remove(id)==-47 && c.entry(id));
    assert(c.close(ref)==0 && c.remove(id)==0 && c.count()==before && !c.entry(id) && !c.child(c.data,"Save.ITD"));
    assert(c.remove(id)==c.fnfErr && c.close(ref)==c.rfNumErr);
    assert(c.planCreate(0x1234,0,"Alone:Game:Alone Data:Save.ITD",plan)==0);
    auto replacement=c.add(plan.parent,plan.name,plan.path,false);
    assert(replacement>id && !c.entry(id) && c.entry(replacement) && !c.entry(replacement)->metadataKnown);
    assert(c.remove(c.application)==-47 && c.remove(c.data)==-47);
    assert(c.remove(replacement)==0 && c.canRemove(c.data)==c.unsupported);
    for(int i=0;i<300;++i) {
        auto file=c.add(c.data,"cycled","PROGDIR:data/cycled",false);
        assert(file>replacement && c.remove(file)==0 && !c.entry(file));replacement=file;
    }
    assert(c.count()==before);
    for(const char* path:{"a/b",".","..","file.rsrc","file.finfo","file.finfo.new","file.FINFO.OLD",":Alone Data:"})
        assert(c.planCreate(0,c.data,path,plan)==c.unsupported);
    assert(c.planCreate(0,c.data,"",plan)==-48);
    assert(c.planCreate(0x1234,0,"new",plan)==c.nsvErr);
    assert(c.planCreate(0,0x1234,"new",plan)==c.dirNFErr);
}
int main() {
    indexedFiles();
    dualForks();
    catalogLifetime();
    MacFiles c;c.reset();assert(c.count()==1 && c.entry(2)->parent==1);
    c.application=c.add(2,"Game","PROGDIR:",true);
    c.data=c.add(c.application,"Alone Data","data",true);
    c.system=c.add(2,"System Folder","",true);
    assert(c.initializeDirectories()==0);
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
    assert(c.openWD(c.data,0x41495445)==wd && c.wdProcess(wd)==0x41495444);
    int16_t queried=c.systemWD;uint32_t process=0,directory=0;
    assert(c.queryWD(queried,0,process,directory)==0 && directory==c.system && process==0x4552494b);
    assert(c.closeWD(c.systemWD)==0);
    assert(c.queryWD(queried,0,process,directory)==c.nsvErr);
    assert(c.closeWD(c.systemWD)==c.rfNumErr);
    queried=0;process=0x41495444;
    assert(c.queryWD(queried,1,process,directory)==0 && queried==wd && directory==c.data);
    queried=0;process=0x41495445;
    assert(c.queryWD(queried,1,process,directory)==c.nsvErr && queried==0 && process==0x41495445);
    queried=0;process=0;
    assert(c.queryWD(queried,1,process,directory)==0 && queried==c.applicationWD && directory==c.application);
    assert(c.closeWD(c.applicationWD)==0 && c.directoryFor(c.applicationWD,id)==0);
    assert(c.openWD(c.application,123,&created)==c.applicationWD && !created);
    queried=0;process=0;
    assert(c.queryWD(queried,2,process,directory)==0 && queried==wd);
    queried=0;process=0;
    assert(c.queryWD(queried,32767,process,directory)==c.nsvErr);
    queried=0;
    assert(c.queryWD(queried,-1,process,directory)==0 && queried==c.volumeRef && directory==2);
    assert(c.closeWD(c.volumeRef)==0 && c.closeWD(0)==c.rfNumErr);
    assert(c.setDefault(wd)==0 && c.defaultRef()==wd);
    assert(c.resolve(0,0,"itd_ress.pak",id)==0 && id==(uint32_t)file);
    assert(c.setDefault(42)==c.nsvErr && c.defaultRef()==wd);
    assert(c.setDefault(0)==0 && c.defaultRef()==wd);
    assert(c.setDefault(wd,"Alone")==0 && c.defaultRef()==wd);
    assert(c.setDefault(c.volumeRef,"Unknown")==c.unsupported && c.defaultRef()==wd);
    assert(c.setHierarchicalDefault(c.volumeRef,c.data)==0 && c.defaultRef()==c.volumeRef);
    assert(c.directoryFor(0,id)==0 && id==c.data);
    assert(c.resolve(0,0,"itd_ress.pak",id)==0 && id==(uint32_t)file);
    assert(c.setHierarchicalDefault(wd,0)==0 && c.defaultRef()==c.volumeRef);
    assert(c.setHierarchicalDefault(wd,9999)==c.fnfErr);
    assert(c.directoryFor(0,id)==0 && id==c.data);
    assert(c.setHierarchicalDefault(42,0)==c.nsvErr);
    assert(c.setHierarchicalDefault(c.volumeRef,file)==c.fnfErr);
    assert(c.setHierarchicalDefault(wd,0,"ITD_RESS.PAK")==c.fnfErr);
    assert(c.setHierarchicalDefault(42,9999,"Alone:Game:Alone Data:")==0);
    assert(c.setHierarchicalDefault(0,0,"::")==0 && c.directoryFor(0,id)==0 && id==c.application);
    assert(c.setHierarchicalDefault(0,0,":Alone Data:")==0 && c.directoryFor(0,id)==0 && id==c.data);
    assert(c.setDefault(wd)==0 && c.defaultRef()==wd);
    assert(c.setDefault(c.volumeRef)==0 && c.directoryFor(0,id)==0 && id==2);
    assert(c.closeWD(wd)==0 && c.directoryFor(wd,id)==c.nsvErr);
    assert(c.closeWD(wd)==c.rfNumErr);
    assert(c.openWD(file,0)==c.fnfErr);
    assert(c.openWD(2,0)==c.volumeRef);
    for(uint8_t first=0;first<5;++first)for(uint8_t second=0;second<5;++second) {
        int16_t a=0,b=0;assert(c.openData(file,first,false,a)==0);
        bool conflict=first!=1 && second!=1 && !(first==4 && second==4);
        assert(c.openData(file,second,false,b)==(conflict ? -49 : 0));
        if(conflict)assert(a==b);else { assert(a!=b);assert(c.fork(b)->writable==(second!=1));assert(c.close(b)==0); }
        assert(c.close(a)==0);
    }
    for(uint8_t perm=0;perm<5;++perm) {
        int16_t ref=0;assert(c.openData(file,perm,true,ref)==(perm<2 ? 0 : -54));
        if(perm<2) { assert(c.fork(ref)->locked && !c.fork(ref)->writable);assert(c.close(ref)==0); }
    }
    assert(c.volume(0x1234,"Alone")==-35 && c.volume(0,"Alone")==0);
    assert(c.volume(0x1234,"aLoNe:")==0 && c.volume(-1,"Other:")==-35);
    assert(c.volume(1,0)==0);
    assert(c.volume(0x1234,"Alone:X")==0 && c.volume(-1,":X")==0 && c.volume(0x1234,":X")==-35);
    int16_t reader=0,writer=0;
    assert(c.openData(file,1,false,reader)==0 && c.openData(file,3,false,writer)==0);
    c.advance(reader,4);assert(c.setSize(writer,2,true)==0);
    assert(c.fork(reader)->position==4 && c.fork(writer)->position==0 && c.fork(writer)->modified);
    c.flushed(file);assert(!c.fork(writer)->modified);
    assert(c.setSize(writer,123456,true)==0 && c.close(reader)==0 && c.close(writer)==0);
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
    assert(c.setSize(d,0,true)==-61);
    assert(c.seek(r,1,200000,true)==0 && c.fork(r)->position==200000);
    assert(c.setSize(r,210000,false)==0 && c.entry(file)->resourceSize==210000 && c.fork(r)->position==200000);
    assert(c.setSize(r,12,true)==0 && c.fork(r)->position==12);
    assert(c.seek(r,1,32,true)==0 && c.setSize(r,32,false)==0 && c.fork(r)->position==32);
    assert(c.setSize(r,20,true)==0 && c.fork(r)->position==20);
    assert(c.seek(r,3,0x7fffffff,true)==c.paramErr && c.fork(r)->position==20);
    assert(c.setSize(r,0x80000000UL,true)==c.paramErr && c.entry(file)->resourceSize==20);
    assert(c.setSize(0,0,true)==c.rfNumErr);
    assert(c.setSize(r,765,true)==0);
    const MacFiles::Fork* found=nullptr;
    assert(c.queryFork(0,1,999,found)==0 && found==c.fork(r));
    assert(c.queryFork(-1,2,999,found)==0 && found==c.fork(d));
    assert(c.queryFork(1,2,999,found)==0 && found==c.fork(d));
    auto queryWD=c.openWD(c.data,0);
    assert(c.queryFork(queryWD,2,999,found)==0 && found==c.fork(d));
    assert(c.queryFork(0,3,0,found)==-38 && !found);
    assert(c.queryFork(0,32767,0,found)==-38 && !found);
    assert(c.queryFork(0x1234,1,0,found)==c.nsvErr && !found);
    assert(c.queryFork(0x1234,0,d,found)==0 && found==c.fork(d));
    assert(c.queryFork(0x1234,0,0,found)==c.rfNumErr && !found);
    assert(c.queryFork(0,-1,0,found)==c.unsupported && !found);
    assert(c.close(r)==0 && !c.fork(r) && c.close(r)==c.rfNumErr);
    assert(c.queryFork(0,1,0,found)==0 && found==c.fork(d));
    assert(c.queryFork(0,2,0,found)==-38 && !found);
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
    for(int i=0;i<c.maxWD;++i) {
        char name[32];snprintf(name,sizeof(name),"dir%d",i);
        auto dir=c.add(c.application,name,"",true);auto w=c.openWD(dir,i);assert(c.directoryFor(w,id)==0);
    }
    auto extra=c.add(c.application,"extra","",true);
    assert(c.openWD(extra,99)==-121);
    c.reset();assert(c.count()==1 && c.fork(d)==nullptr && c.directoryFor(wd,id)==c.nsvErr);
    puts("PASS mac-files: paths, fork identity, working directories, errors, atomic capacity limits");
}
