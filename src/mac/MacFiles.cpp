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
    count_=0;defaultRef_=0;defaultDirectory_=0;application=system=preferences=saves=data=0;
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
        directory=defaultDirectory_ ? defaultDirectory_ : application;
        return directory ? noErr : dirNFErr;
    }
    if(ref==applicationWD && application) { directory=application;return noErr; }
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
        forks_[i]={(int16_t)(128+i),id,0,resource,writable,false,false,false};return forks_[i].ref;
    }
    return -42; // tmfoErr
}
int16_t MacFiles::openData(uint32_t id,uint8_t permission,bool locked,int16_t& ref) {
    ref=0;
    if(permission>4)return unsupported;
    if(!entry(id) || entry(id)->directory)return fnfErr;
    if(locked && permission>1)return -54; // permErr, measured local HFS Open.
    bool writable=permission!=1 && !locked;
    if(writable)for(uint16_t i=0;i<maxOpen;++i) {
        const Fork& f=forks_[i];
        if(f.ref && f.id==id && !f.resource && f.writable && !(permission==4 && f.shared)) {
            ref=f.ref;return -49; // The failed Open returns the existing writer ref.
        }
    }
    int16_t result=open(id,false,writable);
    if(result<0)return result;
    ref=result;Fork* f=const_cast<Fork*>(fork(ref));f->shared=permission==4;f->locked=locked;
    return noErr;
}
int16_t MacFiles::volume(int16_t ref,const char* name) const {
    // A full pathname's volume prefix overrides the reference. A bare name
    // is ignored by the reference FlushVol; ref zero then selects the default.
    if(name && *name!=':')for(const char* end=name;*end;++end)if(*end==':') {
        const char* expected=entry(2)->name;const char* p=name;
        while(p<end && *expected && fold(*p)==fold(*expected)) { ++p;++expected; }
        return p==end && !*expected ? noErr : nsvErr;
    }
    if(ref==1)return noErr; // Single native volume is virtual drive 1.
    uint32_t directory=0;return directoryFor(ref,directory);
}
void MacFiles::modified(int16_t ref) {
    Fork* f=const_cast<Fork*>(fork(ref));if(f)f->modified=true;
}
void MacFiles::flushed(uint32_t id) {
    for(uint16_t i=0;i<maxOpen;++i)if(forks_[i].ref && forks_[i].id==id && !forks_[i].resource)forks_[i].modified=false;
}
const MacFiles::Fork* MacFiles::fork(int16_t ref) const {
    for(uint16_t i=0;i<maxOpen;++i)if(forks_[i].ref && forks_[i].ref==ref)return &forks_[i];
    return 0;
}
int16_t MacFiles::queryFork(int16_t volume,int16_t index,int16_t ref,const Fork*& found) const {
    found=0;
    if(index<0)return unsupported;
    if(!index) { found=fork(ref);return found ? noErr : rfNumErr; }
    uint32_t directory=0;
    if(volume && volume!=1 && directoryFor(volume,directory))return nsvErr;
    // Single catalogued volume, drive 1. Index only live forks, not table holes.
    for(uint16_t i=0;i<maxOpen;++i)if(forks_[i].ref && !--index) {
        found=&forks_[i];return noErr;
    }
    return -38; // fnOpnErr, measured on System 7.5.5 for an exhausted index.
}
int16_t MacFiles::close(int16_t ref) {
    for(uint16_t i=0;i<maxOpen;++i)if(forks_[i].ref && forks_[i].ref==ref) { forks_[i].ref=0;return noErr; }
    return rfNumErr;
}
int16_t MacFiles::initializeDirectories() {
    if(!entry(application) || !entry(system) || !entry(application)->directory || !entry(system)->directory)return dirNFErr;
    for(uint16_t i=0;i<maxWD;++i)if(wd_[i].ref)return unsupported;
    // SysEnvirons reports this reference; System 7.5.5 identifies its owner as ERIK.
    wd_[0]={systemWD,system,0x4552494b};return noErr;
}
int16_t MacFiles::queryWD(int16_t& ref,int16_t index,uint32_t& process,uint32_t& directory) const {
    if(index<=0) {
        int16_t actual=ref ? ref : volumeRef;
        uint32_t found=0;
        int16_t error=directoryFor(actual,found);
        if(error)return error;
        ref=actual;directory=found;process=wdProcess(actual);return noErr;
    }
    uint32_t ignored=0;
    if(ref && directoryFor(ref,ignored))return nsvErr;
    if(application && !process && !--index) {
        ref=applicationWD;directory=application;process=0;return noErr;
    }
    for(uint16_t i=0;i<maxWD;++i)if(wd_[i].ref && (!process || wd_[i].process==process) && !--index) {
        ref=wd_[i].ref;process=wd_[i].process;directory=wd_[i].directory;return noErr;
    }
    return nsvErr;
}
int16_t MacFiles::openWD(uint32_t directory,uint32_t process,bool* created) {
    if(created)*created=false;
    if(!entry(directory) || !entry(directory)->directory)return fnfErr;
    if(directory==application)return applicationWD;
    if(directory==2)return volumeRef;
    for(uint16_t i=0;i<maxWD;++i)
        if(wd_[i].ref && wd_[i].directory==directory)return wd_[i].ref;
    for(uint16_t i=0;i<maxWD;++i)if(!wd_[i].ref) {
        wd_[i]={(int16_t)(-31999+i),directory,process};if(created)*created=true;return wd_[i].ref;
    }
    return -121; // tmwdoErr
}
int16_t MacFiles::closeWD(int16_t ref) {
    if(ref==volumeRef || (ref==applicationWD && application))return noErr;
    for(uint16_t i=0;i<maxWD;++i)if(wd_[i].ref && wd_[i].ref==ref) { wd_[i].ref=0;return noErr; }
    return rfNumErr;
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
    defaultDirectory_=directory;
    return noErr;
}

int16_t MacFiles::setHierarchicalDefault(int16_t ref,uint32_t directory,const char* path) {
    // Full paths select their own volume/root, including with an invalid input ref.
    bool absolute=false;
    if(path && *path!=':')for(const char* p=path;*p;++p)if(*p==':')absolute=true;
    uint32_t resolved=0;
    int16_t error=resolve(absolute ? volumeRef : ref,absolute ? 2 : directory,path,resolved);
    if(error==dirNFErr)return fnfErr; // HSetVol's missing-directory result on 7.5.5.
    if(error)return error;
    if(!entry(resolved)->directory)return fnfErr;
    defaultDirectory_=resolved;defaultRef_=volumeRef;
    return noErr;
}

int16_t MacFiles::seek(int16_t ref,uint16_t mode,int32_t offset,bool writing) {
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
        if((uint32_t)offset>0x7fffffffUL-base) { if(writing)return paramErr;f->position=size;return -39; }
        base+=(uint32_t)offset;
    }
    f->position=!writing && base>size ? size : base;
    return !writing && base>size ? -39 : noErr;
}
int16_t MacFiles::setSize(int16_t ref,uint32_t size,bool clampPosition) {
    Fork* f=const_cast<Fork*>(fork(ref));
    if(!f)return rfNumErr;
    if(!f->writable)return -61;
    if(size>0x7fffffffUL)return paramErr;
    Entry* e=const_cast<Entry*>(entry(f->id));
    if(size!=(f->resource ? e->resourceSize : e->dataSize))f->modified=true;
    if(f->resource)e->resourceSize=size;else e->dataSize=size;
    if(clampPosition && f->position>size)f->position=size;
    return noErr;
}
void MacFiles::advance(int16_t ref,uint32_t count) {
    Fork* f=const_cast<Fork*>(fork(ref));
    if(f)f->position+=count; // Caller supplies the actual bounded transfer count.
}
