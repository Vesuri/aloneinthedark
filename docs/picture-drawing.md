# Eight-bit picture preparation

M2 picture/intro acceptance is complete, supported by state-matched Mac frames and
owner-rendered output.

The original Dan2 loop draws PICT 10000–10019 into a locked 138×542 GWorld with row
stride 144. The unchanged caller at +$037C–$0383 is `2f0b486efff8a8f6`; +$0382 is
DrawPicture. Images are detached before drawing, so their bounds come from the owned
heap allocation, not resource association.

The measured resources use PICT v2, rectangular frame clips, indexed eight-bit
PackBitsRect, complete 256-entry device colour tables and srcCopy. Vette's PackBits
decoder and integer coordinate mapping are reused. Eight-bit output uses the owned
world's actual inverse colour table and collision rings, plus its port/visibility/clip
bounds. Direct index copying is incorrect for pictures 10014 and 10019. Unsupported
formats and complex picture clips remain stops. The reached route is unscaled; broader
scaling acceptance is not claimed.

`tools/mac_drawpicture8.lua` captures all twenty original calls and complete
before/after records and pixels. `amiga/picture8_calls.gdb` captures the same calls
read-only inside the combined startup observer. The independent
`tools/check_picture8.py` decodes the original bytes and computes RGB mapping. It checks
1,560,960 destination bytes per platform, including untouched pixels and row padding,
all D0–D7/A0–A6 registers, eight-byte stack cleanup, unchanged port/PixMap/regions and
original picture bodies. Native acceptance also requires the shared startup
endpoint/MDRV guard. Captures stay under ignored `tmp/`.

Run the reference with the documented headless MAME command and
`tools/mac_drawpicture8.lua`; run the native combined `menu_lifecycle.gdb` observer
through `amiga/diag_run.sh 300`. Check actual terminal statuses:

```
python3 tools/check_picture8.py tmp/m2-pict8-reference.log --status 0
python3 tools/check_picture8.py tmp/m2-pict8-native-final.log --status 0 --native
```

These are offscreen pixel comparisons, not rendered-window or intro acceptance.

## Presentation window picture

D9 now bypasses this standalone MACPLAY routine. The following describes the original
Mac service contract; its call-site observer is not reached by production startup.

PICT 1500, MacPlay (small), is a 16,358-byte indexed PackBits picture with frame
(0,0)–(192,256). The original Dark2+$20EC bytes are `2e8b486effe4a8f6`, calling
DrawPicture at +$20F2 with destination (4,32)–(196,288). It preserves D0–D7/A0–A6 and
pops eight argument bytes.

The existing renderer now accepts owned visible eight-bit window destinations. It uses
the actual main-device colour table and existing inverse-table builder, with rectangular
port/visibility/clip bounds. Window pixels share the logical screen; dirty bounds
translate from port coordinates to that buffer. Offscreen worlds retain their own colour
matching. No Mac chrome is drawn.

`mac_presentpicture.lua` captures the original call and the subsequent clear before
palette restoration at Dark2+$214C. `presentpicture_calls.gdb` captures the native call
and fifth AGA publication before continuing startup. The independent decoder in
`check_presentpicture.py` checks the entire 307,200-byte buffer, unchanged records,
original bytes and caller ABI. Its native check also compares the 64,000-byte client and
CLUT with the Mac, verifies eight bitplanes and all copper colours for the picture, and
requires the integrated MDRV guard. Memory/AGA captures do not satisfy the
owner-deferred rendered-window check.

Accepted runs: `tmp/m2-presentpicture-reference-next.log` and
`tmp/m2-presentpicture-native-complete.log`, both terminal exit zero. The latter
preserves the full debugger transcript because the wrapper's 5,000-line tail omits
earlier controls during the picture's event loop. The 12,144 changed pixels match; the
fifth AGA publication contains the picture and the sixth contains the original black
clear. These commands pass:

```
python3 tools/check_presentpicture.py tmp/m2-presentpicture-reference-next.log --status 0
python3 tools/check_presentpicture.py tmp/m2-presentpicture-native-complete.log --status 0 --native
python3 tools/check_aga_capture.py startup tmp/m2-presentpicture-native-complete.log --status 0
```

## Pond-scene polygon recording

The Enter-skipped idle run reaches the pond background at tick 21,202, 279/279
publications, then stops at OpenPoly (Dark+$3396). The buffer decoded as
`tmp/story-openpoly-stop.png` is the owner's frog-scene starting view; logical pixels
and the software-selected bitplanes/copper agree. This is not complete
car-endpoint/frog-animation acceptance or proof of hardware palette execution. The
diagnostic run exits 1 (`tmp/m2-story-skip-idle.log`).

Original `tmp/m2-polygon-reference-owned.log` exits zero after normal Return skips the
book. It records OpenPoly, MoveTo, ten LineTo calls and ClosePoly at
Dark+$3396/$33B8/$33CE/$33DC. The first point is (7,199); the last returns there.
OpenPoly produces ten zero-initialized bytes except polySize=10, hides the pen (0 to
-1), and puts flag 1 in CGrafPort.polySave. The actual PolyHandle is separate. The first
line stores both endpoints, each later line appends its endpoint, and bounds remain zero
during recording. ClosePoly restores the pen and clears the flag; the final 54-byte
record has bounds (0,136)–(22,199). CPU-executed GetHandleSize/HGetState/HandleZone
queries prove size 54, flags 0 and current-zone ownership. All 261,452 drawing-buffer
bytes remain unchanged.

`PolygonRecord.h` models the connected, explicitly closed recording. The native layer
owns/resizes the handle and leaves it live for the following FramePoly. Nested
recording, picture/region recording overlap, MoveTo after recording has started,
disconnected chains and implicit closing remain named stops. The reached D0/D1/D2
results and D3–D7/A2–A6 preservation are checked. MoveTo's original A0 and ClosePoly's
A1 are implementation scratch pointers, unused by the following original instructions;
native code does not fabricate Mac ROM addresses for them. Semantic port/handle/global
pointers are checked separately.

`tools/check_polygon.py` passes the original byte sequence, polygon/port model, heap
query results, signed-coordinate bounds and non-mutating rejection checks. It rejects
timeout, missing completion, wrong-point and wrong-result evidence. The existing Line8
host regression also passes. The native `INTROSKIP=1` build passes no-float and
88-symbol audits. `tmp/m2-polygon-native-instructions.log` exits zero: all 13 paired
calls pass, the native 54-byte polygon and changed port fields match, the handle has
normal application-zone ownership, all 261,452 drawing bytes remain unchanged and no
extra frame is queued. The observer confirms zero book batches and reaches the named
OpenRgn stop at Dark+$33E8. Four invalid native evidence cases are rejected as well.

The first native observer failed with an invalid debugger reply while testing a
condition on every Mac trap; it is not accepted. The maintained observer now breaks at
original instruction addresses before observing each service. The first comparison also
exposed an overstrict checker: incoming pen positions were (18,91) on the Mac and
(21,97) natively. OpenPoly preserves each incoming position; MoveTo then sets the same
recorded first point on both. The checker now verifies that preservation plus exact
changed fields, instead of copying unrelated incoming state from the reference.

```sh
python3 tools/check_polygon.py --reference tmp/m2-polygon-reference-owned.log \
  --status 0 --native tmp/m2-polygon-native-instructions.log --native-status 0
```

## Pond polygon-to-region recording

The original calls NewRgn at Dark+$33E0, OpenRgn at +$33E8, FramePoly at +$33EC and
CloseRgn at +$33F0. The caller bytes are checked against the extracted CODE resource.
OpenRgn hides the pen (`pnVis=-1`) and sets `rgnSave=1`; FramePoly records the closed
contour without drawing pixels. CloseRgn publishes the region into the caller's owned
handle and restores both port fields to zero. FramePoly also moves the pen to the last
polygon point, even during recording.

`tools/mac_regionrecord.lua` captures these original calls, checks the resulting handle
with GetHandleSize/HGetState/HandleZone, then executes ten diagnostic
OpenRgn/FramePoly/CloseRgn fixtures through the original Macintosh services. The
fixtures cover rectangles, both steep and shallow slopes, positive and negative
diagonals, concavity, negative coordinates, an empty horizontal contour and a
self-crossing contour. Recording ignores pixel clipping.

`tmp/m2-regionrecord-fixtures-reference.log` completed with exit zero.
`tools/check_regionrecord.py --reference tmp/m2-regionrecord-fixtures-reference.log
--status 0` compares the production integer encoder with all eleven captured regions
byte for byte; it also checks caller bytes, port changes, unchanged pixels and atomic
rejection of truncated, unclosed and undersized-output records. The first pond region is
252 bytes, with bounds `(top=136,left=0,bottom=199,right=22)`. Empty and rectangular
regions use the canonical ten-byte form. The host checks run with address/undefined
behavior sanitizers.

The native implementation supports one explicitly closed polygon per recording, a
one-pixel pen, at most 64 polygon edges, 16 simultaneous transition edges and 4096
encoded bytes. Other forms remain loud stops. FramePoly/CloseRgn scratch D1/D2/A0/A1
values are not address-for-address Macintosh ROM reproductions; the following original
instructions overwrite them before consumption. Live D3–D7/A2–A6, stack behavior,
results, owned data and port changes must match.

The bounded `amiga/regionrecord.gdb` observer uses `INTROSKIP=1` and original
instruction breakpoints. It checks all four calls, drawing isolation, compiled stack
headroom, unchanged application-heap allocation during FramePoly, and continuation to
DisposeRgn at Dark+$3058. DisposeRgn is implemented; the observer must not wait for the
historical unsupported-service stop.

Current native acceptance is `tmp/intro-region-private-record-retry-full.log` (exit 0).
Its paired checker passes all 252 output bytes, live registers, logical extent/owner,
restored port fields, zero memory errors and unchanged pixels. The encoder has 5,392
bytes of interrupt headroom. Host sanitizer checks also cover malformed bounds, reserved
coordinates and excessive complexity.

## Pond contour expansion

The unchanged game next calls InsetRgn at Dark+$33F8 with distances -1,-1. Original
+$33F2–$33F9 bytes are `2f0a4878ffffa8e1`. The reference observer
`tools/mac_insetrgn.lua` sends normal Enter to skip the book, follows the real pond
polygon/region calls and captures this expansion, then checks allocation size, flags and
owner through original Memory Manager calls.

`tmp/m2-insetrgn-reference.log` exits zero. The 252-byte contour becomes a 244-byte
region with bounds `(135,-1,200,23)`. A separate pixel-set model proves that it is the
union of all source pixels translated by -1,0,+1 in both axes. Port fields, source
polygon and the drawing buffer remain unchanged. The same region handle owns the resized
body, with flags zero in the application zone. The trap pops eight argument bytes; D0=0,
D1.W=$FFFF and D2.W=200; D3–D7/A2–A6 are preserved. A0/A1 are QuickDraw scratch, not
live caller results.

`RegionExpand::one` implements the measured expansion with span unions, without a bitmap
scratch buffer. It stages its result before publishing and rejects unsupported
complexity, overflow and malformed/truncated streams. The runtime accepts only the
measured -1,-1 distances; other distances stay at INSETRGN. The host check compares
exact original region bytes, an independent pixel-set oracle for empty, rectangular,
concave, separated, merging and holed shapes, and atomic rejection. It runs with
address/undefined-behavior sanitizers in `make host-tests`. Native validation in
`amiga/insetrgn.gdb` checks ownership and unchanged pixels, then stops at the original
InsetRgn return. It also records elapsed game ticks. The current forward-cursor
implementation and performance evidence are in
[amiga-arch.md](intro-comparison.md).

The first native InsetRgn attempt fails with SIGBUS before its return. The instrumented
repeat (`tmp/m2-insetrgn-native-dispatch-full.log`, exit 1) proves that trap dispatch is
entered with the expected arguments before the fault; it is not accepted evidence.
Compiled frames showed 4,164 bytes reserved by the dispatcher plus 4,296 bytes in the
expansion helper. The output buffer has therefore moved to a temporary owned handle,
disposed on completion or failed encoding. The dispatcher now reserves 324 bytes. The
rerun reports system-stack bounds $200AA8–$2022A8 (6,144 bytes), less than the two old
frames alone. The corrected frames total 4,620 bytes before call/register overhead.
`tmp/m2-insetrgn-native-heap.log` exits zero, and the complete debugger output is saved
in `tmp/m2-insetrgn-native-heap-full.log`. The paired checker passes all 244 region
bytes, bounds, ABI, handle identity/extent/flags/owner and unchanged port/pixel data.
Queued publications stay 211 and book batches stay zero. Neither failed run is counted
as a pass.

The full host suite passes in `tmp/m2-insetrgn-host-tests.log`; the added span-merging
boundary fixture also passes. Final no-float and 88-symbol audits pass. Four
corrupt/incomplete original logs and five invalid native logs (including insufficient
stack headroom) are rejected.

## Pond polygon disposal

KillPoly at Dark+$3410 follows the verified expansion. Original caller bytes
+$340E–$3411 are `2f0ca8cd`. `tools/mac_killpoly.lua` captures the real call through the
Enter-skipped route; `tmp/m2-killpoly-reference.log` exits zero. The 54-byte polygon is
released: the Mac's free-memory count increases by 64 bytes, the polygon master is
linked to the former free-master head, and the zone header's head becomes the polygon
handle. Other zone-header bytes remain unchanged. The expanded 244-byte region keeps its
bytes, body, flags and owner; port fields and drawing pixels remain unchanged.

The call pops four bytes, returns D0=0/A0=polygon handle and preserves D1–D7/A2–A6. A1
is Memory Manager scratch. The native implementation uses the existing owned-handle
disposal path, clears MemError and rejects an active recording or resource-owned handle.
Its allocator uses a different block header, so native acceptance checks the freed
allocation's actual span and cleared master ownership rather than requiring the Mac's
64-byte physical size.

`tools/check_killpoly.py` verifies original bytes, calling contract, the exact
zone/free-master transition and region/pixel isolation; four failed/incomplete reference
logs are rejected. The existing heap regression passes allocation, master blocks,
lock/purge, compaction, resizing, moving-high and 2,500 fragmentation operations. Native
acceptance passes in `amiga/killpoly.gdb`; no-float and 88-symbol build audits pass.

`tmp/m2-killpoly-native.log` exits zero; the full observer output is retained in
`tmp/m2-killpoly-native-full.log`. The paired checker passes the original 54-byte
polygon input, disposal ABI, native 80-byte allocation release and cleared master/flags,
unchanged 244-byte expanded region, port and drawing pixels. Publications remain 394
across the call and book batches remain zero. Execution continues to the named masked
COPYBITS stop at Dark+$346C. Five invalid native logs (missing completion, timeout,
explicit failure, corrupted free count and no continuation) are rejected. Run the paired
check with:

```sh
python3 tools/check_killpoly.py --reference tmp/m2-killpoly-reference.log --status 0 --native tmp/m2-killpoly-native-full.log --native-status 0
```

## Pond masked copy

CopyBits at Dark+$346C has original caller bytes `486efff8486efff842672f0aa8ec`
(+$3460–$346D). Mode is srcCopy, with an expanded 244-byte pond region as mask. Source
and destination are distinct 648×401 offscreen PixMaps with 652-byte rows and matching
colour tables/seeds. The native implementation validates owned mask storage and uses the
existing region row decoder to restrict the copy. Malformed streams fail before pixel
writes; unsupported complexity remains a loud stop. No original instructions or
production animation decisions are changed.

The first Mac call uses rectangle `(43,0,160,23)` and covers 380 pixels without changing
their values. A distinctive source fixture changes 379 pixels, proving that doing
nothing cannot pass. The helper matches both complete original buffers under sanitizers.
These first captures are preserved in `tmp/maskcopy-first-reference/`; their log is
`tmp/m2-maskcopy-fixture-reference.log` (exit zero).

The accepted native run uses `(39,0,163,20)` with exactly the same mask bytes. A bounded
original search examined 4,431 calls without finding that rectangle;
`tmp/m2-maskcopy-matched-reference.log` reports FAIL and is not acceptance. The explicit
`AITD_MASKCOPY_REPLAY_RECT` fixture replays the measured native rectangle through the
original service, without replacing original instructions. The selected mask must match
byte-for-byte. This is service-contract evidence, not proof of identical animation
timing.

`tmp/m2-maskcopy-rectangle-fixture-reference.log` and
`tmp/m2-maskcopy-native-probed-full.log` both exit zero. The paired checker passes all
399 copied pixels, complete destination preservation outside the mask, source/record
isolation, palettes and ABI. The distinctive fixture changes 398 pixels; the actual
helper matches its entire destination. Native queued and presented publications stay
151, dirty state stays empty, and book batches stay zero. The original pops 22 bytes,
returns D0=0 and preserves D2–D7/A2–A6; D1/A0/A1 are scratch. Native mask storage is
borrowed from the validated owner; this matching-palette copy performs no allocation,
resize or disposal.

The native observer positively reaches original `2f14a8d9` at Dark+$3058, then the A8D9
dispatcher and named DISPOSERGN stop. An earlier rerun raised SIGILL at $F80BE0 after
the copy (`tmp/m2-maskcopy-native-named-failed-full.log`, exit one). The added
caller/dispatcher/register probes did not reproduce it; M2.3g44g1 below attributes and
fixes the cause. That failed run is not counted as a pass.

The full host suite passes in `tmp/m2-maskcopy-host-tests.log`. Host fixtures cover
irregular/disjoint mask spans, mapped colours and atomic malformed-mask rejection.
No-float and 88-symbol build audits pass. Five invalid original and five invalid native
logs are rejected (completion, timeout, bytes/ABI, book replay and unexpected
publication). Acceptance command:

```sh
python3 tools/check_maskcopy.py tmp/m2-maskcopy-rectangle-fixture-reference.log --status 0 --native tmp/m2-maskcopy-native-probed-full.log --native-status 0
```

### Polygon interrupt-stack overflow

The apparent post-copy SIGILL originated earlier, during polygon-to-region encoding. GDB
reported $F80BE0, but the diagnostic vector-4 entry captured an untouched exception
frame with SR=$2000, PC=$31BDC4, format/vector=$0010. That address contains QuickDraw
application-heap data, not a CODE segment. The installed debugger rewinds the reported
PC/stack on its illegal-handler breakpoint; its memory-write packets also return empty
replies without changing memory. The temporary probe therefore had to be installed by
native code. The probe and transport captures remain local in `tmp/`.

The system stack is $200AA8–$2022A8 (6,144 bytes). Encoder entry SP=$202078, its
compiled frame used 5,536 bytes plus 16 bytes of saved registers, leaving only 32 bytes
for further calls and interrupts. A diagnostic one-field wait makes the failure
reproducible. `tmp/m2-polygon-stack-stress-full.log` (exit one) catches
`aitdMacMouseVBI` saving D2–D4/A2–A4 at SP=$200A4C, below the stack. The A4 save
overwrites ExecBase+$230 ($200A60) from $F814C4 to $31BDE8. Original ROM bytes at
$F81428 load that scheduler launch pointer into A4; $F814C2 jumps through it. This
attributes the later execution of heap data to a port stack overflow, rather than an
emulator false alarm.

`PolygonRegion::Scratch` keeps the edge array and atomic output staging off that stack.
The runtime now reserves 9.25 KiB of private storage: a recording buffer plus a shared
polygon/expansion workspace. These synchronous services finish before original callbacks
run; native VBI never uses the buffers. The recording stays private until CloseRgn
copies it into the caller-owned handle. Successful memory-error results and
unsupported-input stops are preserved.

`regionrecord.gdb` checks that FramePoly changes neither the number nor total size of
live application allocations. The current native fixture reports 5,392 bytes of encoder
interrupt headroom and passes exact original bytes, ABI, port fields, ownership and
pixel isolation. `POLYGONSTACKSTRESS=1` retains the diagnostic one-field wait; normal
builds do not wait. Historical temporary- handle and forced-overflow experiments are
recorded in Git history.

```sh
python3 tools/check_regionrecord.py --reference tmp/m2-regionrecord-fixtures-reference.log --status 0 --native tmp/intro-region-private-record-retry-full.log --native-status 0
```
