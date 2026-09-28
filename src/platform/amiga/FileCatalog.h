#ifndef AITD_FILE_CATALOG_H
#define AITD_FILE_CATALOG_H
class MacFiles;
// Before takeover, catalog only: Lock/Examine/ExNext, never Read.
const char* aitdBuildFileCatalog(MacFiles&,const char* applicationPath,uint32_t resourceBytes);
#endif
