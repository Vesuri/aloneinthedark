#include <proto/dos.h>
#include <dos/dos.h>
#include "mac/MacFiles.h"
#include "FileCatalog.h"
extern "C" {
volatile uint32_t g_catalogEntries=0,g_catalogDataFiles=0,g_catalogDataBytes=0;
}
static bool same(const char* a,const char* b) {
    while(*a && *b) {
        char x=*a++,y=*b++;
        if(x>='A' && x<='Z')x+='a'-'A';
        if(y>='A' && y<='Z')y+='a'-'A';
        if(x!=y)return false;
    }
    return *a==*b;
}
static bool join(char* target,const char* folder,const char* name) {
    uint16_t n=0;
    while(*folder) { if(n==158)return false;target[n++]=*folder++; }
    if(n && target[n-1]!=':' && target[n-1]!='/')target[n++]='/';
    while(*name) { if(n==159)return false;target[n++]=*name++; }
    target[n]=0;return true;
}
static const char* scan(MacFiles& catalog,uint32_t directory,const char* path,bool optional,bool data) {
    BPTR lock=Lock((CONST_STRPTR)path,ACCESS_READ);
    if(!lock) {
        if(optional && IoErr()==ERROR_OBJECT_NOT_FOUND)return 0;
        return "CATALOG / DIRECTORY OPEN";
    }
    FileInfoBlock* info=(FileInfoBlock*)AllocDosObject(DOS_FIB,0);
    const char* error=0;
    if(!info)error="CATALOG / FILE INFO ALLOCATION";
    else if(!Examine(lock,info) || info->fib_DirEntryType<=0)error="CATALOG / EXPECTED DIRECTORY";
    else {
        while(ExNext(lock,info)) {
            // Nested user directories and companion forks require explicit handling.
            if(info->fib_DirEntryType>=0 || info->fib_Size<0) { error="CATALOG / UNSUPPORTED ENTRY";break; }
            const char* name=(const char*)info->fib_FileName;
            const char* suffix=0;
            for(const char* p=name;*p;++p)if(*p=='.')suffix=p;
            if(suffix && same(suffix,".rsrc")) {
                error="CATALOG / COMPANION RESOURCE FORK";break;
            }
            char file[160];
            if(!join(file,path,(const char*)info->fib_FileName)
                || catalog.add(directory,(const char*)info->fib_FileName,file,false,info->fib_Size)<0) {
                error="CATALOG / UNSUPPORTED NAME OR CAPACITY";break;
            }
            if(data) { ++g_catalogDataFiles;g_catalogDataBytes+=info->fib_Size; }
        }
        if(!error && IoErr()!=ERROR_NO_MORE_ENTRIES)error="CATALOG / ENUMERATION";
    }
    if(info)FreeDosObject(DOS_FIB,info);
    UnLock(lock);return error;
}
const char* aitdBuildFileCatalog(MacFiles& catalog,const char* applicationPath,uint32_t resourceBytes) {
    catalog.reset();g_catalogEntries=g_catalogDataFiles=g_catalogDataBytes=0;
    catalog.application=catalog.add(2,"Alone in the Dark","PROGDIR:",true);
    catalog.system=catalog.add(2,"System Folder","",true);
    catalog.preferences=catalog.add(catalog.system,"Preferences","PROGDIR:prefs",true);
    catalog.saves=catalog.add(catalog.application,"Alone Saved Games","PROGDIR:Saved Games",true);
    // Match the already selected installed/development resource location.
    const char* dataPath=same(applicationPath,"PROGDIR:data/Alone In The Dark") ? "PROGDIR:data/Alone Data" : "PROGDIR:Alone Data";
    catalog.data=catalog.add(catalog.application,"Alone Data",dataPath,true);
    if(catalog.add(catalog.application,"Alone In The Dark",applicationPath,false,0,resourceBytes)<0)
        return "CATALOG / APPLICATION ENTRY";
    if(catalog.initializeDirectories())return "CATALOG / SYSTEM WORKING DIRECTORY";
    const char* error=scan(catalog,catalog.data,dataPath,false,true);
    if(!error)error=scan(catalog,catalog.saves,"PROGDIR:Saved Games",true,false);
    if(!error)error=scan(catalog,catalog.preferences,"PROGDIR:prefs",true,false);
#ifdef AITD_FILE_PROBE
    if(!error && catalog.add(catalog.data,"absent-probe.bin","PROGDIR:absent-probe.bin",false,123)<0)
        error="CATALOG / ABSENT PROBE";
    if(!error && catalog.add(catalog.data,"read-probe.bin","PROGDIR:read-probe.bin",false,200003)<0)
        error="CATALOG / READ PROBE";
#endif
    if(!error)g_catalogEntries=catalog.count();
    return error;
}
