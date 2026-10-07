#include "platform/amiga/M5Audit.h"
#include <proto/dos.h>
#include <proto/exec.h>
#include <dos/dosextens.h>
#include <exec/memory.h>
#include "FileAccess.h"
#include "mac/MacVolume.h"
#include "SystemWindow.h"
#ifdef AITD_FILE_WRITE_PROBE
extern "C" { volatile uint32_t g_volumeBackingProbe[6]={}; }
#endif
static bool macDate(const struct DateStamp& stamp,uint32_t& result) {
    if(stamp.ds_Days<0 || stamp.ds_Minute<0 || stamp.ds_Minute>=1440 || stamp.ds_Tick<0 || stamp.ds_Tick>=60*TICKS_PER_SECOND)return false;
    unsigned long long value=2335305600ULL+(unsigned long long)stamp.ds_Days*86400+(uint32_t)stamp.ds_Minute*60+(uint32_t)stamp.ds_Tick/TICKS_PER_SECOND;
    if(value>0xffffffffULL)return false;
    result=(uint32_t)value;return true;
}
static int32_t queryBacking(void* context) {
    MacVolumeBacking result={};int32_t error=0;
    BPTR lock=Lock((CONST_STRPTR)"PROGDIR:",ACCESS_READ);
    if(!lock)return -36;
    InfoData* info=(InfoData*)M5_ALLOC_MEM(sizeof(InfoData),MEMF_PUBLIC|MEMF_CLEAR);
    FileInfoBlock* folder=(FileInfoBlock*)AllocDosObject(DOS_FIB,0);
    if(!info || !folder)error=-108;
    else if(!Info(lock,info) || !Examine(lock,folder))error=-36;
    else if(info->id_NumBlocks<=0 || info->id_NumBlocksUsed<0
        || info->id_NumBlocksUsed>info->id_NumBlocks || info->id_BytesPerBlock<=0
        || (info->id_DiskState!=ID_VALIDATED && info->id_DiskState!=ID_WRITE_PROTECTED)
        || !info->id_VolumeNode || !macDate(folder->fib_Date,result.modified))error=-32760;
    else {
        DosList* list=LockDosList(LDF_VOLUMES|LDF_READ);
        if(!list)error=-36;
        else {
            const DosList* volume=(const DosList*)BADDR(info->id_VolumeNode);
            if(volume->dol_Type!=DLT_VOLUME || !macDate(volume->dol_misc.dol_volume.dol_VolumeDate,result.created))error=-32760;
            UnLockDosList(LDF_VOLUMES|LDF_READ);
        }
        result.blocks=info->id_NumBlocks;result.used=info->id_NumBlocksUsed;
        result.blockBytes=info->id_BytesPerBlock;result.locked=info->id_DiskState==ID_WRITE_PROTECTED;
    }
    if(folder)FreeDosObject(DOS_FIB,folder);
    if(info)M5_FREE_MEM(info,sizeof(InfoData));UnLock(lock);
    if(!error) {
        *(MacVolumeBacking*)context=result;
#ifdef AITD_FILE_WRITE_PROBE
        g_volumeBackingProbe[0]=result.blocks;g_volumeBackingProbe[1]=result.used;
        g_volumeBackingProbe[2]=result.blockBytes;g_volumeBackingProbe[3]=result.created;
        g_volumeBackingProbe[4]=result.modified;g_volumeBackingProbe[5]=result.locked;
#endif
    }
    return error;
}
int32_t FileAccess::volumeBacking(MacVolumeBacking& result) { return aitdSystemWindow(queryBacking,&result); }
