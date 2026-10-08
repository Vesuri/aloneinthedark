/* Diagnostic Workbench-protocol launcher; original OS media stays external. */
#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/execbase.h>
#include <dos/dosextens.h>
#include <dos/dostags.h>
#include <workbench/startup.h>
struct ExecBase* SysBase;
struct DosLibrary* DOSBase;
int main(void) {
    SysBase=*(struct ExecBase**)4;
    DOSBase=(struct DosLibrary*)OpenLibrary((CONST_STRPTR)"dos.library",37);
    if(!DOSBase)return 20;
    if(!FindTask((CONST_STRPTR)"Workbench")) {
        Execute((CONST_STRPTR)"DF0:c/LoadWB",0,0);
        Delay(100);
    }
    if(!FindTask((CONST_STRPTR)"Workbench")) {CloseLibrary((struct Library*)DOSBase);return 20;}
    BPTR directory=Lock((CONST_STRPTR)"DH1:",ACCESS_READ);
    BPTR segment=LoadSeg((CONST_STRPTR)"DH1:Alone");
    struct MsgPort* reply=CreateMsgPort();
    if(!directory || !segment || !reply)return 20;
    struct TagItem tags[]={
        {NP_Seglist,segment},{NP_FreeSeglist,FALSE},{NP_Name,(ULONG)"Alone"},
        {NP_Cli,FALSE},{NP_StackSize,65536},{NP_HomeDir,DupLock(directory)},
        {NP_CurrentDir,DupLock(directory)},{NP_WindowPtr,(ULONG)-1},{TAG_DONE,0}};
    struct Process* child=CreateNewProc(tags);
    if(!child)return 20;
    struct WBArg arg={directory,(STRPTR)"Alone"};
    struct WBStartup startup={0};
    startup.sm_Message.mn_Node.ln_Type=NT_MESSAGE;
    startup.sm_Message.mn_Length=sizeof(startup);
    startup.sm_Message.mn_ReplyPort=reply;
    startup.sm_Process=&child->pr_MsgPort;
    startup.sm_Segment=segment;startup.sm_NumArgs=1;startup.sm_ArgList=&arg;
    PutMsg(&child->pr_MsgPort,&startup.sm_Message);
    WaitPort(reply);
    if(GetMsg(reply)!=&startup.sm_Message)return 20;
    /* The child forbids task switching between reply and Process termination. */
    UnLoadSeg(segment);UnLock(directory);DeleteMsgPort(reply);
    BPTR done=Open((CONST_STRPTR)"DH1:QuitWorkbench.done",MODE_NEWFILE);
    if(!done)return 20;
    static const char message[]="PASS Workbench startup reply received after game cleanup\n";
    LONG written=Write(done,(APTR)message,sizeof(message)-1);
    Close(done);CloseLibrary((struct Library*)DOSBase);
    return written==sizeof(message)-1 ? 0 : 20;
}
