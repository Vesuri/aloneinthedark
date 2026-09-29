// Resource-file services share the File Manager's streams/catalog. Included by
// MacLoader after dispatchFileData so all mutations use the same ownership.
static DataFork* resourceStream(uint16_t key) {
    int16_t ref=s_resourceFileRefs[key];
    for(auto& f:s_dataForks)if(ref && f.ref==ref)return &f;
    return 0;
}
static bool remapResourceHandles() {
    int16_t remap[ResourceForks::kMaximumResources];
    MacHeap::Handle old[ResourceForks::kMaximumResources];
    for(uint16_t i=0;i<ResourceForks::kMaximumResources;++i)old[i]=s_resourceHandles[i];
    if(!s_resourceForks.refresh(remap))return false;
    for(auto& h:s_resourceHandles)h=0;
    for(uint16_t i=0;i<ResourceForks::kMaximumResources;++i)if(old[i]) {
        if(remap[i]>=0)s_resourceHandles[remap[i]]=old[i];
        else { MacHeap* zone=handleZone(old[i]);if(!zone || zone->disposeHandle(old[i]))return false; }
    }
    g_resourceCount=s_resourceForks.resourceCount();return true;
}
static int32_t resourceStreamRead(void* context,uint32_t offset,uint8_t* bytes,uint32_t count,uint32_t& actual) {
    auto& f=*(DataFork*)context;
    // Resource metadata reads must not fill the File Manager cache with bodies.
    return f.source ? f.source->writes.read(offset,bytes,count,actual) : FileAccess::readStream(&f.stream,offset,bytes,count,actual);
}
static ResourceForks::Source resourceStreamSource(uint16_t key) {
    const auto* f=s_files.fork(s_resourceFileRefs[key]);
    return {resourceStream(key),s_files.entry(f->id)->resourceSize,resourceStreamRead};
}
static int32_t resourceHandleRead(void* context,uint32_t offset,uint8_t* bytes,uint32_t count,uint32_t& actual) {
    actual=0;auto handle=(MacHeap::Handle)context;MacHeap* zone=handleZone(handle);
    if(!zone || !*handle || offset>zone->handleSize(handle) || count>zone->handleSize(handle)-offset)return -32760;
    volatile uint8_t* destination=bytes;
    for(uint32_t i=0;i<count;++i)destination[i]=(*handle)[offset+i];
    actual=count;return 0;
}
struct ResourcePublication {
    ResourceStage stage;DataFork* stream;char path[192];uint32_t size=0;
    static int32_t begin(void* p,uint32_t size) {
        auto& r=*(ResourcePublication*)p;r.size=size;auto sink=r.stage.sink();return sink.begin(sink.context,size);
    }
    static int32_t write(void* p,uint32_t at,const uint8_t* bytes,uint32_t size,uint32_t& actual) {
        auto& r=*(ResourcePublication*)p;auto sink=r.stage.sink();return sink.write(sink.context,at,bytes,size,actual);
    }
    static int32_t finish(void* p,bool publish) {
        auto& r=*(ResourcePublication*)p;auto sink=r.stage.sink();
        if(!publish)return sink.finish(sink.context,false);
        if(FileAccess::closeStream(r.stream->stream))return -32760;
        int32_t error=sink.finish(sink.context,true);
        if(FileAccess::openStream(r.path,r.stream->stream))return -32760;
        return error;
    }
};
static int32_t updateResourceFile(uint16_t key) {
    auto* directory=s_resourceForks.directory();
    if(!directory->dirty(key))return 0;
    auto* stream=resourceStream(key);const auto* fork=s_files.fork(s_resourceFileRefs[key]);
    if(!stream || !fork || !fork->writable || !stream->source || stream->source->writes.dirty())return -32760;
    // Mixing raw resource-fork streams with Resource Manager updates is not yet measured.
    for(const auto& other:s_dataForks)if(other.ref && &other!=stream && other.source==stream->source)return -32760;
    ResourcePublication publication;publication.stream=stream;
    if(s_files.forkPath(fork->id,true,publication.path,sizeof(publication.path)) || !publication.stage.bind(publication.path))return -32760;
    ResourceWriter::Sink sink={&publication,ResourcePublication::begin,ResourcePublication::write,ResourcePublication::finish};
    int32_t error=directory->serialize(key,sink);if(error)return error;
    if(s_files.setSize(fork->ref,publication.size,true))return -32760;
    auto& source=*stream->source;
    source.writes.clear();
    if(source.writes.bind(publication.size,readDataSource,&source,allocateFilePage,releaseFilePage))return -32760;
    source.storedSize=publication.size;
    if(directory->rebase(key,resourceStreamSource(key)) || !remapResourceHandles())return -32760;
    s_files.flushed(fork->id,true);s_files.touchMetadata(fork->id,FileAccess::metadataTime());
    const auto* entry=s_files.entry(fork->id);
    error=FileAccess::storeMetadata(entry->path,entry->metadata);
    if(!error)s_files.metadataFlushed(fork->id);
    return error;
}
static int32_t closeResourceFile(uint16_t key) {
    if(!key)return -32760; // Application closure semantics remain unmeasured.
    int32_t error=updateResourceFile(key);if(error)return error;
    uint8_t pb[80]={};uint32_t regs[15]={};write16(pb+24,s_resourceFileRefs[key]);regs[8]=(uint32_t)pb;
    if(!dispatchFileData(0xa001,regs))return -32760;
    error=(int16_t)read16(pb+16);if(error)return error;
    int16_t older=0;
    if(s_currentResourceFork==key && !s_resourceForks.directory()->older(key,older))return -32760;
    if(s_resourceForks.directory()->close(key) || !remapResourceHandles())return -32760;
    s_resourceFileRefs[key]=0;if(s_currentResourceFork==key)s_currentResourceFork=older;
    return 0;
}
static int32_t openResourceFile(const uint8_t* name,int16_t volume,uint32_t parent,uint8_t permission,bool create,int16_t& result) {
    result=-1;if(!name || (permission!=0 && permission!=3))return -32760;
    char path[256];for(uint16_t i=0;i<name[0];++i)path[i]=name[i+1];path[name[0]]=0;
    uint32_t id=0;int32_t error=s_files.resolve(volume,parent,path,id,true);if(error)return create ? -32760 : error;
    const auto* entry=s_files.entry(id);if(!entry || entry->directory)return -32760;
    auto* directory=s_resourceForks.directory();
    for(uint16_t key=0;key<ResourceForks::kForkCount;++key)if(directory->active(key)) {
        const auto* fork=s_files.fork(s_resourceFileRefs[key]);
        if(fork && fork->id==id) { if(create)return -32760;s_currentResourceFork=key;result=fork->ref;return 0; }
    }
    if(create && entry->resourceSize)return -32760;
    uint16_t key=1;while(key<ResourceForks::kForkCount && directory->active(key))++key;
    if(key==ResourceForks::kForkCount)return -32760;
    uint8_t pb[80]={};uint32_t regs[15]={};write32(pb+18,(uint32_t)name);write16(pb+22,volume);write32(pb+48,parent);pb[27]=permission;regs[8]=(uint32_t)pb;
    if(!dispatchFileData(0xa20a,regs))return -32760;
    error=(int16_t)read16(pb+16);if(error)return error;
    s_resourceFileRefs[key]=(int16_t)read16(pb+24);
    if(!s_files.fork(s_resourceFileRefs[key])->writable) {
        if(!dispatchFileData(0xa001,regs) || (int16_t)read16(pb+16))return -32760;
        s_resourceFileRefs[key]=0;return -32760;
    }
    error=create ? directory->create(key) : directory->open(key,resourceStreamSource(key),s_files.fork(s_resourceFileRefs[key])->writable);
    if(error) {
        if(!dispatchFileData(0xa001,regs) || (int16_t)read16(pb+16))return -32760;
        s_resourceFileRefs[key]=0;return -32760; // Unmeasured malformed-map/error contract.
    }
    if(!remapResourceHandles())return -32760;
    if(create)return closeResourceFile(key);
    s_currentResourceFork=key;result=s_resourceFileRefs[key];return 0;
}
static uint32_t dispatchResourceFiles(uint16_t trap,uint32_t* regs,uint8_t* stack) {
    int32_t error=0;uint16_t pop=0;bool preserve=false;
    if(trap==0xa997 || trap==0xa9c4 || trap==0xa81a || trap==0xa9b1 || trap==0xa81b) {
        bool create=trap==0xa9b1 || trap==0xa81b;int16_t result=-1;
        uint32_t name=0,parent=0;int16_t volume=0;uint8_t permission=0;
        if(trap==0xa997 || trap==0xa9b1) { name=read32(stack);pop=4; }
        if(trap==0xa9c4) { permission=stack[0];volume=(int16_t)read16(stack+2);name=read32(stack+4);pop=8; }
        if(trap==0xa81a) { permission=stack[0];name=read32(stack+2);parent=read32(stack+6);volume=(int16_t)read16(stack+10);pop=12; }
        if(trap==0xa81b) { name=read32(stack);parent=read32(stack+4);volume=(int16_t)read16(stack+8);pop=10; }
        error=openResourceFile((uint8_t*)name,volume,parent,permission,create,result);
        if(error==-32760)return 0;
        if(!create)write16(stack+pop,result);
        preserve=trap==0xa997;if(create)regs[0]=pop;
        else if(!preserve)regs[0]=(uint16_t)error;
    } else if(trap==0xa999 || trap==0xa99a) {
        int16_t ref=(int16_t)read16(stack);uint16_t key=0;
        while(key<ResourceForks::kForkCount && (!s_resourceForks.directory()->active(key) || s_resourceFileRefs[key]!=ref))++key;
        error=key==ResourceForks::kForkCount ? -193 : trap==0xa999 ? updateResourceFile(key) : closeResourceFile(key);
        if(error==-32760)return 0;
        pop=2;preserve=trap==0xa999;
        if(!preserve)regs[0]=(uint16_t)error;
    } else if(trap==0xa9ab) {
        auto handle=(MacHeap::Handle)read32(stack+10);auto* zone=handleZone(handle);const uint8_t* name=(const uint8_t*)read32(stack);
        if(!zone || !*handle || !name || resourceHandleIndex(handle)>=0)return 0;
        uint32_t size=zone->handleSize(handle),identity=0;
        ResourceWriter::Entry entry={read32(stack+6),(int16_t)read16(stack+4),0,name+1,name[0],{handle,size,resourceHandleRead},0,size};
        error=s_resourceForks.directory()->add(s_currentResourceFork,entry,identity);
        if(error)return 0; // Additional AddResource errors await reference fixtures.
        if(!remapResourceHandles())return 0;
        for(uint32_t i=0;i<s_resourceForks.resourceCount();++i)if(s_resourceForks.identity(i)==identity) { s_resourceHandles[i]=handle;break; }
        zone->setState(handle,(zone->state(handle)|0x20)&~0x40);regs[0]=0;pop=14;
    } else return 0;
    resourceResult(error);return pop+1;
}
