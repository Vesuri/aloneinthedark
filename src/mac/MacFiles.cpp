#include "MacFiles.h"
static char fold(char c) { return c>='A' && c<='Z' ? c+('a'-'A') : c; }
static bool equal(const char* a,const char* b) {
    while(*a && fold(*a)==fold(*b)) { ++a;++b; }
    return fold(*a)==fold(*b);
}
static bool copy(char* out,const char* in,uint32_t capacity) {
    if(!in)return false;
    uint32_t i=0;
    for(;in[i];++i) {
        if(i+1>=capacity || (uint8_t)in[i]>=128)return false;
        out[i]=in[i];
    }
    out[i]=0;return true;
}
void MacFiles::reset() {
    count_=0;defaultRef_=0;application=system=preferences=saves=data=0;
    for(uint16_t i=0;i<maxOpen;++i)forks_[i].ref=0;
    for(uint16_t i=0;i<maxWD;++i)wd_[i].ref=0;
    add(1,"Alone","",true); // Virtual volume root has the HFS-reserved ID 2.
}
const MacFiles::Entry* MacFiles::entry(uint32_t id) const {
    return id>=2 && id-2<count_ ? &entries_[id-2] : 0;
}
const MacFiles::Entry* MacFiles::child(uint32_t parent,const char* name) const {
    for(uint16_t i=0;i<count_;++i)
        if(entries_[i].parent==parent && equal(entries_[i].name,name))return &entries_[i];
    return 0;
}
int32_t MacFiles::add(uint32_t parent,const char* name,const char* path,bool directory,uint32_t ds,uint32_t rs) {
    if(count_==maxEntries || !name || !*name)return unsupported;
    if(count_ && (!entry(parent) || !entry(parent)->directory || child(parent,name)))return paramErr;
    Entry candidate={};
    if(!copy(candidate.name,name,sizeof(candidate.name)) || !copy(candidate.path,path,sizeof(candidate.path)))return unsupported;
    for(const char* p=name;*p;++p)if(*p==':')return paramErr;
    candidate.id=count_+2;candidate.parent=parent;candidate.directory=directory;
    candidate.dataSize=ds;candidate.resourceSize=rs;
    entries_[count_++]=candidate;return candidate.id;
}
int16_t MacFiles::directoryFor(int16_t ref,uint32_t& directory) const {
    if(!ref) {
        if(defaultRef_)return directoryFor(defaultRef_,directory);
        directory=application;return application ? noErr : dirNFErr;
    }
    if(ref==volumeRef) { directory=2;return noErr; }
    for(uint16_t i=0;i<maxWD;++i)if(wd_[i].ref==ref) { directory=wd_[i].directory;return noErr; }
    return nsvErr;
}
int16_t MacFiles::resolve(int16_t volume,uint32_t directory,const char* path,uint32_t& id) const {
    uint32_t base;
    if(directoryFor(volume,base))return nsvErr;
    if(directory)base=directory;
    if(!entry(base) || !entry(base)->directory)return dirNFErr;
    if(!path || !*path) { id=base;return noErr; }
    const char* p=path;
    bool absolute=false;
    if(*p==':')++p;
    else { for(const char* q=p;*q;++q)if(*q==':') { absolute=true;break; } }
    if(absolute) {
        char volumeName[32];uint16_t n=0;
        while(*p && *p!=':') { if(n==31 || (uint8_t)*p>=128)return unsupported;volumeName[n++]=*p++; }
        volumeName[n]=0;
        if(!equal(volumeName,entry(2)->name))return nsvErr;
        base=2;++p;
    }
    while(*p) {
        if(*p==':') {
            if(base==2)return dirNFErr;
            base=entry(base)->parent;++p;continue;
        }
        char component[32];uint16_t n=0;
        while(*p && *p!=':') {
            if(n==31 || (uint8_t)*p>=128)return unsupported;
            component[n++]=*p++;
        }
        component[n]=0;
        const Entry* found=child(base,component);
        if(!found) {
            // Only the measured optional application directory may be absent.
            if(base==application && !equal(component,"Alone Movies"))return unsupported;
            return fnfErr;
        }
        base=found->id;
        if(*p==':') { if(!found->directory)return dirNFErr;++p; }
    }
    id=base;return noErr;
}
int16_t MacFiles::open(uint32_t id,bool resource,bool writable) {
    if(!entry(id) || entry(id)->directory)return fnfErr;
    for(uint16_t i=0;i<maxOpen;++i)if(!forks_[i].ref) {
        forks_[i]={(int16_t)(128+i),id,0,resource,writable};return forks_[i].ref;
    }
    return -42; // tmfoErr
}
const MacFiles::Fork* MacFiles::fork(int16_t ref) const {
    for(uint16_t i=0;i<maxOpen;++i)if(forks_[i].ref && forks_[i].ref==ref)return &forks_[i];
    return 0;
}
int16_t MacFiles::close(int16_t ref) {
    for(uint16_t i=0;i<maxOpen;++i)if(forks_[i].ref && forks_[i].ref==ref) { forks_[i].ref=0;return noErr; }
    return rfNumErr;
}
int16_t MacFiles::openWD(uint32_t directory,uint32_t process,bool* created) {
    if(created)*created=false;
    if(!entry(directory) || !entry(directory)->directory)return dirNFErr;
    if(directory==2)return volumeRef;
    for(uint16_t i=0;i<maxWD;++i)
        if(wd_[i].ref && wd_[i].directory==directory && wd_[i].process==process)return wd_[i].ref;
    for(uint16_t i=0;i<maxWD;++i)if(!wd_[i].ref) {
        wd_[i]={(int16_t)(-32000+i),directory,process};if(created)*created=true;return wd_[i].ref;
    }
    return unsupported;
}
int16_t MacFiles::closeWD(int16_t ref) {
    for(uint16_t i=0;i<maxWD;++i)if(wd_[i].ref && wd_[i].ref==ref) { wd_[i].ref=0;return noErr; }
    return nsvErr;
}
uint32_t MacFiles::wdProcess(int16_t ref) const {
    for(uint16_t i=0;i<maxWD;++i)if(wd_[i].ref && wd_[i].ref==ref)return wd_[i].process;
    return 0;
}

int16_t MacFiles::setDefault(int16_t ref,const char* volumeName) {
    if(volumeName && !equal(volumeName,entry(2)->name))return unsupported;
    uint32_t directory=0;
    int16_t error=directoryFor(ref,directory);
    if(error)return error;
    if(ref)defaultRef_=ref;
    return noErr;
}

int16_t MacFiles::seek(int16_t ref,uint16_t mode,int32_t offset) {
    Fork* f=const_cast<Fork*>(fork(ref));
    if(!f)return rfNumErr;
    if(mode>3)return unsupported;
    if(!mode)return noErr;
    const Entry* e=entry(f->id);
    uint32_t size=f->resource ? e->resourceSize : e->dataSize;
    uint32_t base=mode==1 ? 0 : mode==2 ? size : f->position;
    if(offset<0) {
        uint32_t magnitude=0-(uint32_t)offset;
        if(base<magnitude)return -40; // posErr: unchanged mark.
        base-=magnitude;
    } else {
        if((uint32_t)offset>0x7fffffffUL-base) { f->position=size;return -39; }
        base+=(uint32_t)offset;
    }
    f->position=base>size ? size : base;
    return base>size ? -39 : noErr;
}
void MacFiles::advance(int16_t ref,uint32_t count) {
    Fork* f=const_cast<Fork*>(fork(ref));
    if(f)f->position+=count; // Caller supplies the actual bounded transfer count.
}
