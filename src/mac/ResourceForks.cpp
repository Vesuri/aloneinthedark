#include "ResourceForks.h"
#include "ResourceMap.h"
static uint32_t be32(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static int32_t exact(const ResourceForks::Source& source,uint32_t at,uint8_t* out,uint32_t length) {
    if(!source.read || at>source.size || length>source.size-at || (length && !out))return -50;
    while(length) {
        uint32_t n=length<ResourceForks::chunkBytes ? length : ResourceForks::chunkBytes,actual=0;
        int32_t error=source.read(source.context,at,out,n,actual);
        if(error)return error;
        if(actual!=n)return -39;
        at+=n;out+=n;length-=n;
    }
    return 0;
}
static int32_t residentRead(void* context,uint32_t at,uint8_t* out,uint32_t size,uint32_t& actual) {
    const uint8_t* input=(const uint8_t*)context+at;
    for(uint32_t i=0;i<size;++i)out[i]=input[i];actual=size;return 0;
}
void ResourceForks::close() {
    for(uint16_t i=0;i<kForkCount;++i) { delete[] m_maps[i];m_maps[i]=0;m_sources[i]={}; }
    m_count=m_forks=0;m_open=false;
}
bool ResourceForks::before(const Item& a,const Item& b) {
    if(a.fork!=b.fork)return a.fork<b.fork;
    if(a.type!=b.type)return a.type<b.type;
    return a.id<b.id;
}
bool ResourceForks::appendFork(uint16_t fork,const Source& source,const uint8_t* resident) {
    uint8_t header[16];ResourceMap::Layout layout;
    if(exact(source,0,header,16) || !ResourceMap::layout(header,source.size,layout)
        || layout.mapLength>maximumMapBytes)return false;
    m_maps[fork]=new uint8_t[layout.mapLength];if(!m_maps[fork])return false;
    if(exact(source,layout.mapOffset,m_maps[fork],layout.mapLength))return false;
    ResourceMap map;
    if(!map.open(header,source.size,m_maps[fork],layout.mapLength) || map.count()>kMaximumResources-m_count)return false;
    m_sources[fork]=source;
    for(uint16_t i=0;i<map.count();++i) {
        ResourceMap::Entry entry;uint8_t sizeWord[4];uint32_t offset;
        if(!map.entry(i,entry) || exact(source,entry.lengthOffset,sizeWord,4))return false;
        uint32_t size=be32(sizeWord);if(!map.payload(i,size,offset))return false;
        Record& record=m_items[m_count++];
        record.item={fork,entry.id,entry.type,entry.attrs,entry.name,entry.nameLength,resident ? resident+offset : 0,size};
        record.offset=offset;
    }
    ++m_forks;return true;
}
bool ResourceForks::finish() {
    // Preserve the existing stable lookup/handle indices during the I/O change.
    // Resource Manager enumeration will use map order when those calls land.
    for(uint16_t i=1;i<m_count;++i) {
        Record value=m_items[i];uint16_t j=i;
        while(j && before(value.item,m_items[j-1].item)) { m_items[j]=m_items[j-1];--j; }
        m_items[j]=value;
    }
    m_open=true;return true;
}
bool ResourceForks::open(const uint8_t* app,uint32_t appSize,const uint8_t* data,uint32_t dataSize) {
    close();Source a={(void*)app,appSize,residentRead},b={(void*)data,dataSize,residentRead};
    if(!app || !appendFork(0,a,app) || (data && !appendFork(1,b,data))) { close();return false; }
    return finish();
}
bool ResourceForks::open(const Source& app,const Source* data) {
    close();if(!appendFork(0,app) || (data && !appendFork(1,*data))) { close();return false; }
    return finish();
}
bool ResourceForks::item(uint32_t index,Item& out) const {
    if(!m_open || index>=m_count)return false;out=m_items[index].item;return true;
}
bool ResourceForks::find(uint16_t fork,uint32_t type,int16_t id,Item& out,uint32_t* index) const {
    if(!m_open)return false;Item wanted={};wanted.fork=fork;wanted.type=type;wanted.id=id;
    uint16_t first=0,last=m_count;
    while(first<last) { uint16_t mid=first+((last-first)>>1);if(before(m_items[mid].item,wanted))first=mid+1;else last=mid; }
    if(first>=m_count)return false;const Item& found=m_items[first].item;
    if(found.fork!=fork || found.type!=type || found.id!=id)return false;
    out=found;if(index)*index=first;return true;
}
int32_t ResourceForks::read(uint32_t index,uint8_t* out,uint32_t capacity) const {
    if(!m_open || index>=m_count || capacity<m_items[index].item.size)return -50;
    const Record& r=m_items[index];return exact(m_sources[r.item.fork],r.offset,out,r.item.size);
}
