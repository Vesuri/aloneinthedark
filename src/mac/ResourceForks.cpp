#include "ResourceForks.h"
#include "ResourceDirectory.h"
static int32_t residentRead(void* context,uint32_t at,uint8_t* out,uint32_t size,uint32_t& actual) {
    const uint8_t* input=(const uint8_t*)context+at;
    for(uint32_t i=0;i<size;++i)out[i]=input[i];actual=size;return 0;
}
void ResourceForks::close() {
    delete m_directory;m_directory=0;
    m_count=m_forks=0;m_open=false;
}
bool ResourceForks::appendFork(uint16_t fork,const Source& source,const uint8_t* resident) {
    if(!m_directory) { m_directory=new ResourceDirectory;if(!m_directory)return false; }
    if(m_directory->open(fork,source,false))return false;
    uint16_t count=m_directory->count(fork);
    if(count>kMaximumResources-m_count)return false;
    for(uint16_t i=0;i<count;++i) {
        ResourceDirectory::View view={};if(!m_directory->at(fork,i,view))return false;
        const auto& entry=view.entry;Record& record=m_items[m_count++];
        record.item={fork,entry.id,entry.type,entry.attrs,entry.name,entry.nameLength,resident ? resident+entry.offset : 0,entry.size};
        record.identity=view.identity;
    }
    ++m_forks;return true;
}
bool ResourceForks::finish() {
    // Retain original reference-list order for indexed Resource Manager calls.
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
    if(!m_open)return false;
    for(uint16_t i=0;i<m_count;++i) {
        const Item& found=m_items[i].item;
        if(found.fork==fork && found.type==type && found.id==id) {
            out=found;if(index)*index=i;return true;
        }
    }
    return false;
}
int32_t ResourceForks::read(uint32_t index,uint8_t* out,uint32_t capacity) const {
    if(!m_open || index>=m_count || capacity<m_items[index].item.size)return -50;
    const Record& r=m_items[index];return m_directory->read(r.identity,0,out,r.item.size);
}
