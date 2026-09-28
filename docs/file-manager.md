# File Manager reference contract

M2.1a adds full 80-byte parameter blocks to the existing byte-checked MAME
logger and corrects the initial diagnostic. M2.1b1 implements the catalog/identity subset below; the remaining File Manager
services are M2.1b2b; integrated read acceptance is M2.1c after M2.2.

## First call: application file control block

Core+$4142 is `7008` (`MOVEQ #8,D0`), followed by `$A260` at +$4144.
Selector 8 is **PBGetFCBInfo**; selector 7 is PBGetWDInfo. The census already
had the correct mapping. The old runtime diagnostic and current-state docs
incorrectly called selector 8 GetWDInfo; those names are corrected.

The parameter layout follows Apple's [File Manager C/assembly summary](https://dev.os9.ca/techpubs/mac/Files/Files-301A.html),
under FCBPBRec. The System 7.5.5 reference returns the following at that site:

| Field | Byte offset | Observed value |
| --- | ---: | ---: |
| ioResult | 16 | 0 |
| ioRefNum (input and output) | 24 | $05E2 |
| ioFCBIndx (input) | 28 | 0 |
| ioFCBFlNm | 32 | 1705 |
| ioFCBFlags | 36 | $0300 |
| ioFCBStBlk | 38 | $0D4F |
| ioFCBEOF | 40 | 1,424,934 |
| ioFCBPLen | 44 | 1,449,984 |
| ioFCBCrPs | 48 | 1,407,018 |
| ioFCBVRefNum | 52 | -1 |
| ioFCBClpSiz | 54 | $0001D800 |
| ioFCBParID | 58 | 1671 |

The logical length equals the original application's resource fork. Allocation
blocks, current position, file IDs and references are observations of this
reference run, not constants to paste into the port. The catalog must model
identities and the file table must model open forks. The subsequent OpenWD
of `:Alone Data:` succeeds with working-directory reference $8063; the optional
`:Alone Movies:` lookup returns fnfErr (-43). Preserve ordinary missing-file
errors for known optional paths; unknown/unimplemented path handling stays loud.

The pre-implementation native observer captured the same caller's request with **ioRefNum=0,
ioFCBIndx=0**. Engine+$4092 (`3178 0900 0072`) reads CurApRefNum ($0900)
into its object, then Engine+$40B2 copies that value to the FCB request. The
existing byte-checked low-memory rewrite already redirects it to shadow offset
132. CurResFile separately supplies the object's next field. M2.1b1 initializes
both from one real open-fork reference; merely changing CurResFile left the
request at zero and correctly produced rfNumErr (-51) in the first probe.
No new game instruction patch is needed.

## Reproducible evidence

Run the existing headless reference route in `mac-reference-loop.md`, using
`tools/mac_traps.lua`, then:

```sh
python3 tools/check_file_reference.py tmp/m2-file-full-reference.log
```

The checker attributes each input via live jump-table addresses and original
trap bytes, pairs returns by resume PC and parameter-block address, requires
all 80 bytes and equal ioResult/D0.W, and rejects missing completion or pending
calls. It ignores unrelated system calls and untaken alternate-glue return
sites. It requires positive application-FCB, data-directory, missing-movies
and ITD_RESS.PAK read evidence. `--require-file present.pak` additionally requires
that file; a missing read fails. Its negative fixtures run in `make host-tests`.
This verifies calls and returned counts, not read-payload checksums.

Local full-route evidence: 1,279 paired direct File Manager calls; play, save,
load and Finder checkpoints complete in 181 emulated seconds, with normal
termination. It reads 108,928 bytes cumulatively from ITD_RESS.PAK, plus the
world tables, room/actor PAKs and SAVE0.ITD. **No PRESENT.PAK open/read occurs on
this route.** A shorter startup capture similarly omits it. M2.1b retains the
original acceptance requirement while identifying a real path that reaches
that file, or documenting why the file is unused; do not synthesize a game read
to make an acceptance line pass.

Native validation: clean `window-core` and production `boot` pass on 68020.
`original_startup.gdb` checks the original bytes, records the request, then
reports the corrected `FILE MANAGER / GETFCBINFO`, Core+$4144 stop. A5 $00787240
and STRS $004442C8 give zero mismatches in 75,616 bytes. Heap accounting retains
zero unexplained bytes. This is a diagnostic/reference checkpoint, not progress
past the File Manager stop or a successful game launch.

## Implemented catalog checkpoint (M2.1b1)

The independent catalog/identity portion of M2.1b is complete. `MacFiles` models
128 catalog entries, 16 open forks and 16 working directories. ASCII names are
case-insensitive; unsupported names, unknown application paths, nested native
directories, `.rsrc` companions and capacity exhaustion stop explicitly. The
measured optional `Alone Movies` lookup and absent files inside known directories
return fnfErr. Finder information and resource companions remain M2.1b2.

The native builder enumerates names and sizes with Lock/Examine/ExNext before
takeover, without Read. The original data directory contains 32 files totaling
5,315,994 bytes; the complete virtual catalog has 39 entries. Application,
System, Preferences, saves and data directories have distinct IDs. Missing
optional save/prefs directories are represented as empty; other DOS errors fail
startup. The application still uses its existing whole-fork buffer until M2.2.

The application resource fork is ref 128, catalog ID 8, parent 3. CurApRefNum,
CurResFile and UseResFile share its identity. GetFCBInfo returns the exact
1,424,934-byte length, name, resource/writable flags $0300 and volume -1.
Virtual physical length equals logical length; allocation block/clump and
position are zero because this buffered resource implementation has performed
no file-table seeks. Those fields differ from HFS allocation and Resource
Manager disk-read position on the Mac; the original caller uses parent/volume.
Resource writes remain unsupported; $0100 describes the writable application
fork, not a claim that write traps are implemented.

The first original OpenWD has null name, vRefNum **0**, process 0, and the
application parent ID. The Mac returns its already-open WD ($8043, created=0);
the native table creates -32000 (created=1), preserving the input directory ID.
The original passes that returned reference directly to SetVol, which remains
`FILE MANAGER / SETVOL`, Core+$4066. No original data PAK has been read yet.

`file_catalog.gdb` checks original caller bytes and both real returns, including
the full Pascal application name and the subsequent SetVol argument. It requires
one FCB and one OpenWD result, two completed user services and zero runtime OS
windows. Unsupported selectors, indexed FCB requests and async operations remain
stops. Host ASan/UBSan tests cover paths, errors, separate fork identities, WD
reuse/close and atomic capacity limits through `make host-tests`.

The startup observer and all identity checks pass. A5 $0078F1B0 and STRS
$0044C238 match all 75,616 globals; paired heap accounting has zero unexplained
bytes (Mac 2,821,316 free; native 3,096,720). This is progress past the old stop,
not completion of M2.1's original PAK read/checksum acceptance.

Clean 68020 `make regression` passes both `window-core` (including exact
bitplane snapshots) and production `boot`. Host tests and link audits pass.

## Startup directories (M2.1b2a)

SetVol now changes the default working-directory reference in `MacFiles`.
Reference zero resolves through that state. Invalid references or unsupported
volume names leave it unchanged; the host tests check those failures and actual
relative-path resolution after switching directories. The native handler supports
synchronous basic SetVol; GetVol, hierarchical and async forms remain pending.
The mapping follows Apple's [PBSetVol contract](https://leopard-adc.pepas.com/documentation/mac/pdf/Files/File_Manager.pdf),
with names restricted to the catalogued volume.

FindFolder ($A823, selector 0) implements the original `'pref'` query on the
system volume ($8000 or the mapped volume -1). It returns the catalogued virtual
Preferences directory, ID 5, volume -1. That directory already exists in the
virtual catalog even when the native prefs directory has not been created;
this is not a claim of a native directory write. Native creation/writes remain
in the queued file/resource backends. Other folder types/selectors stop loudly.
See Apple's [FindFolder contract](https://developer.apple.com/documentation/coreservices/1389175-findfolder).

The fresh reference logger byte-checks Core+$4350 (`2F0C 2F0B 7000 A823`) and
captures the live output pointers retained in A4/A3. Mac Preferences is directory
920, volume -1; the native directory ID differs, while identity and call results
agree. The original subsequently passes the returned values to OpenWD.
Run the reference check with:

```sh
python3 tools/check_file_reference.py tmp/m2-directory-reference.log --startup-directories
```

The bounded reference completes normally and yields 98 paired direct file calls.
Its first seven are GetFCBInfo, application OpenWD, SetVol, data OpenWD,
Preferences OpenWD, SetVol and missing-movies OpenWD. The checker verifies that
sequence, arguments and results, plus FindFolder's captured outputs. The native
`file_catalog.gdb` observes those same original calls: three successful WDs,
two SetVol returns, FindFolder's output and 16-byte Pascal stack cleanup, and
fnfErr (-43) for `:Alone Movies:`. Seven user services complete; zero runtime OS
windows are needed for these metadata operations.

The next named stop is **Get1NamedResource, Engine+$3CDC ($A820)**. This is a
measured dependency before original PAK reads. The remaining file implementation
stays first in M2.1b2b; its native fixture acceptance cannot substitute for the
original-game acceptance, retained as M2.1c after M2.2 resource services.

Clean 68020 window-core/boot and host tests pass. The startup A5 world matches
all 75,616 bytes (A5 $0078F608, STRS $0044C690); heap accounting has zero
unexplained bytes. Identity now includes the seventh natural `fold` query from
Core+$4324 before FindFolder, in addition to the original six and eleven Engine
capability flags. No original instruction is changed by these services.

## Read-only data-fork core (M2.1b2b)

Synchronous Open ($A000), HOpen ($A200), Read ($A002), GetEOF ($A011),
GetFPos ($A018), SetFPos ($A044) and Close ($A001) now operate on the shared
fork table. Only permission 1 (read-only data fork) is implemented. Resource
forks, other permissions, asynchronous requests and positioning flags beyond
modes 0–3 remain unsupported; they are not reported as successful transfers.
The original Misc3 bytes include Open+$0FBE, Read+$111E and GetEOF+$0FFA.
No original instruction is patched by these services.

An open fork owns a persistent DOS handle and one 65,536-byte fast-RAM buffer.
Opening does not read payloads. Small reads reuse cached ranges; crossing the
range refills the remaining part on demand. Large requests bypass the cache,
with each DOS Read capped at 65,536 bytes, all within one OS window. Files are
opened, filled and closed in user-mode service windows using the M1.7 mechanism.
The existing bounded resload adapter is unchanged; actual WHDLoad stream
binding/integration remains M7.2 and is not claimed by these DOS tests.

The mark follows actual returned bytes. A read crossing EOF reports eofErr (-39)
with its partial count. A negative seek reports posErr (-40) without changing the
mark; a seek beyond EOF clamps to EOF and reports eofErr. Bad refs report -51.
Failed fills are invalidated, so an error cannot become a later cache hit.
See Apple's [FSRead contract](https://dev.os9.ca/techpubs/mac/Files/Files-127.html)
and [file-position rules](https://dev.os9.ca/techpubs/mac/pdf/Files/Intro_to_Files.pdf).
The host sanitizer tests cover all four positioning modes, arithmetic limits,
cache hits, crossings, direct reads, short/error fills and separate-fork caches.

`make regression` now runs `file-read`, `window-core` and production `boot`.
The synthetic 200,003-byte fixture is generated in ignored emulator staging.
Actual native Line-A calls check every returned byte, ioResult/D0, mark/counts
and OS condition codes. The 131,089-byte direct read takes one window and three
DOS reads. The complete read fixture uses six DOS reads (262,168 bytes including
prefetch; maximum transfer 65,536) and ten OS windows, including open/close,
a missing file, HOpen, reopen and a deliberately retained stream. Cleanup after
OS restoration closes that last handle; the observer requires an empty handle
ledger and restored scheduling/Line-A state. Close failure is reported to the
Shell and makes platform cleanup fail rather than silently succeeding.

All three regressions, the host suite, production directory/startup/identity
observers and A5/heap comparisons pass. A5 $007909A8 and STRS $0044DA30 match
75,616 bytes exactly; native free heap remains 3,096,720 with zero unexplained
reference differences. Startup still stops at Get1NamedResource, Engine+$3CDC.
These fixture reads do not establish that the original game has read any PAK;
that acceptance remains M2.1c after the intervening Resource Manager work.

## Default-volume query (M2.1b2c1)

Synchronous GetVol ($A014) returns the selected SetVol working-directory
reference and the virtual volume name `Alone`; a null name pointer is supported.
It makes no OS call. The original Core+$403E trap and its surrounding parameter
setup were checked before implementation; no original instructions changed.
Hierarchical default-directory state and asynchronous forms remain M2.1b2c.

The fresh bounded Mac capture `tmp/m2-getvol-reference.log` completes with 98
paired direct file calls. `check_file_reference.py --getvol` requires a successful
original GetVol, the preceding SetVol identity, the output name and unchanged
pointer, and reuse of that name/reference by a subsequent named SetVol. This
resolves the manual's ambiguous description of the returned name: System 7.5.5
returns the volume name, not the working directory's name. The virtual volume's
name differs intentionally from the reference disk's `7.5.5 2GB (D)`.

The native file fixture now has 18 stages, checking root and WD returns, a null
name pointer, CCR/ioResult, and preservation after a failed SetVol. Read bytes,
six DOS reads, ten OS windows and restored-OS cleanup remain unchanged. Host
fixtures reject missing name round-trips and a substituted volume-root ref.

All host checks, file-read, window-core and production boot pass on 68020.
The original directory observer still reports 39 entries, 32 data files,
5,315,994 bytes, seven successful service completions, zero runtime OS windows
and the unchanged Get1NamedResource stop. No owner decision is required.

## Indexed open-fork queries (M2.1b2c2)

PBGetFCBInfo selector 8 now accepts positive one-based indexes over live open
forks. Closed slots are skipped. Zero indexes retain exact-reference lookup,
which ignores the volume input. Indexed requests accept the single virtual
volume (-1), its drive (1), and any live working-directory reference; zero
indexes all volumes. Unknown volumes return -35, an exhausted positive index
returns -38, and a bad exact reference returns -51. Negative indexes remain a
named GetFCBInfo stop. Errors leave the output identity/length fields unchanged.

`tools/mac_file_queries.lua` is a bounded read-only API fixture. It checks
original Core+$4142–$4147 (`7008 A260 6004`), lets the initial application FCB
query complete, then re-enters that original trap with diagnostic parameters.
It patches no original instructions and terminates after its sixth recorded
return; it does not claim original-game progress. On System 7.5.5, index 1
returned ref 2; exact ref 2 returned the same file ID, flags, EOF and parent.
Index 32767 returned -38, volume $1234 returned -35, and exact ref 0 returned
-51 even with that invalid volume. The reusable checker requires every stage,
matching D0/ioResult, those arguments/results, byte proof and normal completion:

```sh
python3 tools/check_file_queries.py tmp/m2-fcb-query-reference.log --status 0
```

Run the documented headless MAME command with `tools/mac_file_queries.lua` as
its autoboot script; preserve the runner's actual status when checking the log.
The host suite includes rejected-capture fixtures and sanitizer tests of live
fork enumeration, closed-slot skipping, volume/WD lookup and all measured
errors. The native `file-read` fixture now has 22 stages and checks indexed
application/resource and data forks, exact lookup, null output names, returned
lengths/flags, preserved error outputs and CCR. Its six DOS reads, ten windows
and restored-OS cleanup are unchanged. Original startup still stops at
Get1NamedResource, before original-game PAK reads.

The host suite, native file-read, window-core, production boot and original
directory observer all pass on 68020. The directory observer retains all seven
completed services and zero OS windows, ending at the unchanged Resource
Manager stop. No game instruction or owner decision changed.

## Hierarchical default directory (M2.1b2c3)

HSetVol ($A215) now stores a directory ID separately from its returned default
volume reference. HGetVol ($A214) returns the selected directory ID and actual
volume in ioWDDirID/ioWDVRefNum. SetVol retains its working-directory reference;
HSetVol converts it to the volume reference while retaining the resolved
directory. GetVol uses the same state. Relative and full catalog paths resolve
through the existing model; unsupported names/paths remain loud. Missing
directories return -43 and failed changes preserve the previous default.

The expanded `mac_file_queries.lua` directory mode verifies every original
Core trap word before re-entering the corresponding trap directly. It makes
only transient directory-table changes, then exits after 21 recorded returns.
It does not resume the game or claim startup progress. Reproduce with the
usual headless MAME command and `AITD_FILE_QUERIES=directories`, then:

```sh
python3 tools/check_file_queries.py tmp/m2-directory-fields-reference.log --directories --status 0
```

The System 7.5.5 capture establishes two details more precisely than the
manual. HGetVol **leaves ioWDProcID unchanged**, verified with $DEADBEEF input
for both SetVol and HSetVol state; only GetWDInfo returned the WD process ID.
HSetVol with a WD and directory ID zero resolves that WD, then GetVol/HGetVol
return volume -1 with the original directory retained. A nonzero invalid ID
($9999) returns -43 even with a valid WD; the manual's blanket “ID ignored”
description does not match this reference. The implementation follows the
measured behavior.

The native file fixture now has 28 stages. It verifies volume versus WD
returns, retained directory IDs, untouched process fields, missing-directory
errors and relative paths; queries add no OS windows. Host sanitizer tests
also cover full-path volume selection, parent traversal, file-as-directory
rejection and unchanged state after failed calls. The reference checker rejects
wrong process fields, references, arguments, errors and incomplete captures.

The probe also records pending WD work: a freshly opened data WD closes;
subsequent exact GetWDInfo returns -35 and repeated CloseWD returns -51.
The existing application WD instead survived close, so that special identity
must be modeled explicitly before calling WD support complete. Those calls
remain queued and unsupported on native; these reference observations are not
implementation acceptance.

All host tests, the 28-stage native file regression, window-core, production
boot and the original directory observer pass on 68020. Original startup retains
39 catalog entries, 32 data files, seven completed services and zero runtime
OS windows, with the same named Get1NamedResource stop.

## Working-directory queries and lifetime (M2.1b2c4)

Synchronous GetWDInfo (HFSDispatch selector 7) and CloseWD (selector 2) now
operate on the catalog. SysEnvirons' $8053 is a real initial System-directory
entry with process ID `'ERIK'` ($4552494B), as returned by the reference. The
application WD (-32000) is always present and survives CloseWD. The System WD
is ordinary and can be closed. Sixteen ordinary WD slots include that initial
System entry; exhaustion returns tmwdoErr (-121).

The 27-call reference mode (`AITD_FILE_QUERIES=wd`) checks all original trap
words, protected application closure, System closure, same-directory reuse,
positive and negative process filters, ordinary close/errors, and the default
state after closing its WD. `check_file_queries.py LOG --wd --status STATUS`
requires every stage and matching D0/ioResult. The fresh local evidence is
`tmp/m2-wd-index-reference.log`, with normal exit and explicit completion.

Two measured details differ from the manual: OpenWD reuses an existing directory
regardless of the supplied process ID, retaining the first process ID; and a
negative GetWDInfo index behaves like exact lookup. Positive indexes enumerate
live entries, with process zero as a wildcard; nonzero process filters return
only that owner's entries. Exhaustion or invalid query references return -35.
Index zero (or negative) with reference zero returns the volume root, even when
the default directory is elsewhere. Missing CloseWD refs (including zero) return
-51; closing volume -1 succeeds. Closing the current ordinary WD retains the
default reference and directory ID, while querying the closed WD fails. Queries
return the volume name, actual volume, directory ID and stored process ID.

Native indexes enumerate the port's application/System/opened directory table;
they do not reproduce Finder's unrelated open directories or their numeric
references. The original first OpenWD now reuses the preexisting application
WD with created=0, matching the Mac more closely. The original data and
Preferences refs shift by one table slot; callers use the returned refs.
`file_catalog.gdb` checks those identities and the corrected creation flag.

The 39-stage native file fixture checks System identity/lifetime, application
protection, duplicate-open identity, exact/indexed queries, filtered errors,
negative indexes, volume-root lookup, closed-default state, returned names and
CCR. Its ten OS windows and six DOS reads are unchanged. Sanitizer tests cover
slot capacity, query ordering and error-state preservation. Original startup
still ends at Get1NamedResource; this is not PAK-read or launch acceptance.

Host tests, native file-read, window-core, production boot, original directory
startup and the identity observer all pass on 68020. SysEnvRec remains exactly
16 reference bytes, seven Gestalt calls and eleven Engine flags match, and
startup still completes seven file services without runtime OS windows. No
owner decision or original instruction changed.

## Sparse write-buffer helper (M2.1b2c5)

The independently testable `FileWriteBuffer` implements the buffered-write model
needed by the remaining file traps. It is not wired into native writable forks
yet. Open permissions, Create/Delete, Write, SetEOF, FlushVol and Finder/fork
metadata remain M2.1b2c6, including native/Mac argument/result and durable-write
acceptance. The original Misc3+$11A8 SetEOF and +$11CE Write bytes were checked;
no original instructions or trap routing changed here.

Binding the helper performs no payload read. A partial write allocates a 64 KiB
dirty page and fetches its existing prefix on demand; complete-page overwrites
need no backing read. Dirty pages overlay the unchanged file for reads. Holes
and truncated-then-extended ranges read as zeroes. Truncation releases pages
past EOF and clears retained tails so old bytes cannot reappear. This is bounded
buffering, not a whole-file preload: at most 32 dirty pages are retained, with
an explicit unsupported result at capacity. Allocation failure reports -108
and the actual accepted prefix; neither error claims a completed write.

Flush writes dirty pages and zero-filled extension ranges in transfers no
larger than 65,536 bytes, then requests the logical EOF. Only full success
clears the dirty ledger and releases pages. Short/error writes or failed resize
retain all pending state for retry. The caller owns the DOS window around
those callbacks. Explicit `clear` discards buffers for cleanup; rebinding a live
buffer is rejected, and copying the owning object is disabled.

`tools/check_file_write_buffer.py`, included in `make host-tests`, compiles the
actual helper with ASan/UBSan. Byte-vector fixtures cover boundary crossings,
full-page overwrite without reads, sparse growth, truncation/regrowth, truncate
to zero, partial/failed reads, short writes, failed EOF updates, retry, allocation
failure, capacity and complete cleanup. A deterministic 300-operation write/
resize sequence compares every logical byte after each operation and disk bytes
after each successful flush. Backend callbacks assert the 64 KiB transfer bound.
The host suite and clean 68020 build pass, including no-float and probe audits.
These host checks alone do not establish native acceptance; see below.

## Writable data forks and native acceptance (M2.1b2c7)

Synchronous Open/HOpen permission 3 binds a sparse `FileWriteBuffer` to the
persistent DOS stream without loading payloads. Read sees its pending changes;
Write updates actual count, mark and catalog EOF. SetEOF updates logical size
and clamps the mark. FlushVol flushes dirty data streams; Close flushes before
closing, retaining the open handle and dirty pages if that flush fails. At
shutdown dirty forks flush after full OS restoration; any failure is reported.
Each DOS Write is at most 64 KiB, followed by SetFileSize and DOS Flush, and
only complete success clears the ledger.

The original bytes were checked at Misc3+$0FBE (A000 Open), +$11CE (A003 Write),
+$11A8 (A012 SetEOF), +$12EA (A013 FlushVol), Core+$3FA6 (A001 Close), and
Core+$4142 (`7008 A260 6004`, FCB observer). No original instructions change.
`mac_file_mutations.lua` uses owned stack memory for a 21-call API fixture,
starting before the mode dialog. It creates a new named scratch, stops on
unexpected errors and requires Delete/FlushVol before reporting completion.
The strict checker rejects missing/duplicate stages, incorrect results,
timeouts and missing cleanup.

Measured on System 7.5.5: writing four bytes at offset 8 gives EOF/mark 12;
SetEOF(2) clamps the mark to 2; a zero-count positioned Write at 32 extends
both EOF and mark to 32. A relative -1 write of four bytes after a 20-byte read
ends at 23. Read-only Write/SetEOF return -61 without modifying the supplied
actual-count sentinel. Unwritten/re-exposed bytes on HFS are unspecified (the
probe sees reused disk contents); the port fills them with deterministic zeros.
Only explicitly written data is used for cross-platform byte fidelity.

`file-write` executes real Line-A calls with CCR/ioResult checks, plus the
independent DOS backend fixture. It verifies the above EOF/position cases,
zero-filled gaps, flush/readback, a 70,000-byte write flushed on Close, and a
three-byte truncation/write left dirty for shutdown. Host readback checks those
three bytes and the backend fixture's 17-byte final file after normal exit.
Totals: 33 runtime OS windows, 20 DOS reads / 801,145 bytes, 12 writes /
470,015 bytes and six flushes (including shutdown), maximum transfer 65,536.
Both remaining handles close after OS restoration, and the ledger is empty.

## Permissions and coherent shared forks (M2.1b2c8)

Synchronous Open/HOpen now support permissions 0–4 on ordinary data files.
The 222-call System 7.5.5 scratch fixture measures the complete two-open matrix:
readers coexist with any writer; only shared permission 4 coexists with another
writer granted 4. Conflicting opens return -49 **and the existing writer's
reference**, including permission 0. No second reference is created. Permissions
0, 2 and 3 otherwise grant exclusive read/write access; 1 grants read access.
A locked file opens read-only with 0 or 1, while 2–4 return -54. This is the
measured low-level Open behavior, not an assumed fallback from the high-level
API description. DOS write protection maps to that locked state.

All handles for a file use one sparse write ledger once a writer opens. Existing
read caches are released, so readers see writes and EOF changes immediately.
Each open reference retains its own mark: truncation clamps only the caller's
mark. Closing a reader does not flush or clear a writer's modified flag. A
modified writer flushes on close, and the shared backing pointer transfers to
another live stream; that stream can still read or write. FlushVol clears the
modified flags after success. GetFCBInfo reports writable/shared/locked/modified
bits separately, matching the reference's $0100/$1000/$2000/$8000 flags.

FlushVol uses a full pathname's volume prefix in preference to ioVRefNum.
Bare names and partial paths (leading colon) use ioVRefNum instead. Invalid
volumes return -35; case-insensitive `Alone:` names, default/live WD references
and virtual drive 1 select the port's one volume. The reference disk reports
actual drive 8, then accepts that value in FlushVol; the drive identity itself
is intentionally not copied to the Amiga catalog.

Native `file-write` checks the permission matrix, lock errors, cross-reference
bytes and marks, both close orders, writes after the first writer closes,
upgrading a populated read cache, FCB flags and FlushVol paths. DOS protection
is set inside a system window; the stream queries it without reading payloads.
FileInfoBlock must be allocated with AllocDosObject: a stack instance at
alignment 2 was measured returning fields shifted by two bytes. The port's
existing catalog already uses the correct allocation pattern.

The expanded regression totals 172 runtime OS windows, 27 DOS reads / 801,173
bytes, 17 writes / 470,037 bytes and 11 flushes including shutdown. Maximum
transfer remains 65,536. Host readback verifies final backend, shared and
shutdown files; two remaining handles close after OS restoration. Host tests,
file-read, window-core, boot and the directory observer retain their acceptance.

Application data-fork writes remain an explicit Open/HOpen stop: the current
native application path holds its raw resource bytes. M2.1b2c9a separates those
stores before allowing such writes. Metadata, resource forks and async/other
flag variants remain M2.1b2c9. Production still reaches Get1NamedResource after
seven directory services and zero runtime OS windows; these API fixtures do
not claim original-game PAK or save/load acceptance.


## Named catalog mutations and Finder records (M2.1b2c9b)

Synchronous Create/HCreate, Delete/HDelete, named GetFInfo/HGetFInfo and
SetFInfo/HSetFInfo operate on the catalog. Creation preflights capacity and paths,
creates empty data plus metadata, then publishes a fresh ID. Deletion refuses
open files (-47) and DOS-locked files (-45), and removes the data and metadata
before retiring the ID. Freed slots are reusable without reusing IDs during a
session. Duplicate/empty names return -48; missing catalogued-directory files
return -43; a bad directory returns -120. Directory deletion remains a loud stop. Companion-fork lifetime is implemented
below (M2.1b2c9a).

The 36-call System 7.5.5 fixture verifies opaque Finder bytes, creation and
modification dates, fresh zero Finder records, and open-file attributes: $88
for an open data fork, $01 for a locked closed file. SetFInfo succeeds on a
locked file, including changing its date. Write changes EOF immediately but
publishes the modification date only when FlushVol or Close flushes the data.
The port follows that timing. HSetFInfo takes the parent directory in its input
PB; HGetFInfo returns the file ID in the same field. The caller must restore the
parent before the next hierarchical named operation.

A port-owned `name.finfo` stores exactly 32 bytes: `AFI1`, the 16 opaque Finder
bytes, creation/modification Mac-epoch seconds as big-endian longs, and an
FNV-1a checksum of the first 28 bytes. Startup reads and validates companions
without loading payloads; orphan/malformed records and leftover `.finfo.new` or
`.finfo.old` transactions stop loudly. Replacement writes and flushes `.new`,
renames the previous record to `.old`, installs the new record, then removes the
backup. Recoverable failures preserve the pending metadata; incomplete rollback
or cleanup never reports success. Creation dates use DOS time converted from
1978 to 1904 (2,335,305,600 seconds) plus corrected Mac ticks during takeover.
Files without a known Finder record still stop on GetFInfo: installed-file
metadata must come from original inputs, not invented dates or type/creator.

Host sanitizer tests cover slot lifetime/capacity and corruption-safe metadata
decoding. Native `file-write` passes 203 OS windows, 27 stream reads / 801,173
bytes, 18 stream writes / 470,041 bytes, and 12 stream flushes including shutdown;
small metadata I/O is separate from those stream counters. Native assertions
check all Finder bytes and pending-versus-closed dates; host readback checks the
data and metadata after exit. File-read, system-window, boot and original-directory
regressions retain their previous acceptance. Rendered-picture acceptance remains
owner-deferred. These are API fixtures, not original-game PAK/save/load acceptance.


## Independent application and companion forks (M2.1b2c9a)

The existing application resource file keeps its installed name and bytes.
Its data fork uses `Alone In The Dark.data` alongside it. Ordinary data files
keep their native names; their resource forks use `.rsrc` companions. `.finfo`
is shared by both forks. Startup enumerates sizes without reading fork payloads,
rejects orphan resource companions, and reads a persisted application data size.
An absent companion represents a known empty fork; first open materializes it
in a system window. It closes the exclusive DOS MODE_NEWFILE handle and reopens
MODE_OLDFILE before returning, so a second Mac reference can share it.

OpenRF/HOpenRF now use the same bounded streams as data forks. Shared ledgers,
permissions, EOF, marks and modified flags are keyed by file ID **and fork**.
Write conflicts apply only within the selected fork. Read-only references see
pending writes to that fork; closing/flushing data cannot clear the resource
fork's modified flag. Protection follows the containing Mac file, including
an empty resource companion. Delete removes data, resource and Finder records;
partial native failure remains a loud stop rather than a claimed deletion.

The 60-call System 7.5.5 fixture verifies distinct references, 4-byte data versus
6-byte resource payloads, $8C file-info attributes while both forks are open,
independent EOF/marks and $8100/$8300 modified flags. It covers permissions 0–4,
two shared resource writers, and locked-file resource opens: default/readonly
succeed with $2200 flags, writable modes return -54. The original HOpenRF glue
at Core+$4158 is byte-checked ($A20A).

Native `file-write` adds 14 fork checkpoints: pending shared resource reads,
close/reopen, startup companion-size discovery, complete deletion, all resource
permissions, and separate durable host bytes. An application data write/close
leaves its 1,424,934-byte resource at SHA-256
`b5848c063652b7223e3e350905b3a9054247b8536942753f435b1051a6352db2`;
a native resource read also checks its original header. Totals are 263 runtime
windows, 30 stream reads / 866,721 bytes, 23 stream writes / 470,065 bytes and
17 stream flushes including shutdown. The remaining two streams close after OS
restoration. Metadata I/O remains separate from stream counters. Host tests,
file-read, window-core, boot and the original directory observer pass.

The Resource Manager still holds the application fork buffer until M2.2. This
File Manager work does not claim resource-map editing or original-game PAK/save
acceptance. Unsupported resource service calls remain named stops.


## Installed metadata from original inputs (M2.1b2c9c1)

The extractor now emits a validated `.finfo` for the application and all 32 data
files. Types, creators and Finder flags are cross-checked between the raw StuffIt
header, lsar entry and unar's AppleDouble/native Finder record. Remaining Finder
bytes come from that extracted record. Creation/modification dates retain the
original big-endian Mac integers; no current timestamps or inferred metadata
are substituted. Missing Finder records, ambiguous entries and unhandled fork
layouts stop extraction explicitly. Payload bytes remain unchanged.

A read-only original Mac fixture compares four representative installed files.
Types, creators, fork lengths and open attributes agree with native GetFInfo.
The existing reference installation has dates 7200 seconds below the archive
headers (the host extraction/MacBinary timezone conversion), cleared initialized
flags on data files, and application icon x=128. These installation differences
are explicitly checked and documented, not silently normalized in the port.
Native metadata retains the original archive timestamps and extracted Finder
record. The opaque metadata round-trip fixtures separately verify Mac API
preservation of all 16 Finder bytes and both timestamp fields.

Host import validation, actual archive extraction, native installed-file info,
read/write, window-core, production boot and original-directory checks pass.
Unknown metadata on user-provided files still causes a named GetFInfo stop.
Indexed file queries and other census variants remain M2.1b2c9c2.


## Indexed file info in complete directories (M2.1b2c9c2a)

Positive GetFInfo/HGetFInfo indices now select one-based ordinary-file entries,
excluding directories and independent of native enumeration/insertion order.
The Mac's supported printable-ASCII collation folds letters to capitals and
places the grave accent between A and B. A 67-character original-Mac fixture
establishes that order; control/non-ASCII catalog names remain unsupported.
Deleted slots are omitted, so subsequent indices close the gap without changing
remaining file IDs.

The name input is ignored for positive indices. A null output-name pointer is
allowed; other outputs still return the selected file. Negative indices retain
named lookup. Out-of-range indices and bad directory IDs return -43; bad volumes
return -35. An explicit bad directory still fails when a valid WD is supplied.
Classic GetFInfo uses the current default directory and ignores the hierarchical
PB directory field. These cases match the 218-call System 7.5.5 fixture.

The native fixture passes all corresponding Line-A cases and exact returned
names, metadata and lifetime checks. Enumeration of the deliberately incomplete
application/System/root namespaces remains a named stop, not a fabricated empty
listing; their boundaries are queued in M2.1b2c9c2b. All regression gates pass,
with 289 runtime windows in the expanded file-write case and unchanged stream
read/write/flush totals. Production still stops at Get1NamedResource.
