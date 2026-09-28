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
