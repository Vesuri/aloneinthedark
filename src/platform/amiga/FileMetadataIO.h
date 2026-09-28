#ifndef AITD_FILE_METADATA_IO_H
#define AITD_FILE_METADATA_IO_H
#include "mac/FileMetadata.h"
namespace FileAccess {
// Initialize before takeover. Runtime time follows the existing corrected Mac ticks.
void initializeMetadataClock();
uint32_t metadataTime();
// Startup/restored-OS only: absence is explicit, malformed metadata is an error.
int32_t forkSizeRestored(const char* path,uint32_t& size,bool& found);
int32_t loadMetadataRestored(const char* path,FileMetadata::Record& record,bool& found);
int32_t createFile(const char* path,const char* parent,bool materializeParent,FileMetadata::Record& record);
int32_t deleteFile(const char* path,bool resourceIsBase=false);
int32_t fileProtection(const char* path,bool& locked);
int32_t storeMetadata(const char* path,const FileMetadata::Record& record,bool restored=false);
}
#endif
