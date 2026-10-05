# Startup events

**Status, 2026-10-04:** Startup/menu events pass M2. First-room walking,
Shift-running, Fight selection and kicking are verified on the 68030.
Keyboard menus and the reached game interfaces pass M3.2/M3.3. Broader gameplay
service coverage remains M3.4; newly reached Mac dialogs require D5 replacements.

## Mouse button sampling — 2026-10-05

Button and StillDown consume the VBI-owned button state used by low-memory and
event polling. Action-menu held clicks pass paired original/native checks:
the button is sampled, no action choice changes, and Escape cancels cleanly.
The click route exercises Button; StillDown retains its existing Boolean ABI
but broader caller coverage remains pending. See
[the reproducible route](development.md#m34-action-menu-clicks--2026-10-05).

## Inventory fields used by pickup observers — 2026-10-05

Original Dan2/CODE 13 Take, +$23A2–$243C, uses world objects at
A5−$115F2 with 52-byte records. It increments the inventory count at
A5−$D8A6; slot 0 is −$D8A4 and slot 1 is −$D8A2. When already nonempty,
it preserves slot 0, shifts later entries and inserts the taken object in slot 1.
Carnby starts with count 1 and object 2 in slot 0. Both original/native lamp
captures end with count 2, slots (2,13), lamp found flags $8609 and object
floor/room −1. Take clears flag $4000 and sets $8000. Earlier exploratory
labels incorrectly treated unrelated A5−$D536 as inventory count; acceptance
now reads the actual fields and verifies captured bytes.

## Actor state used by autonomous routes — 2026-10-05

The original actor record is 160 bytes at A5−$B292 plus its slot offset.
Carnby is actor slot 1 (world object 1/body 12). Room position is at +$1C/+$20,
beta at +$2A, floor at +$2E, room at +$30, life mode at +$32, animation at +$3E
and track mode at +$52. Manual movement uses track mode 1; attic descent uses
track mode 3/track 31 before restoring mode 1. Earlier observers mislabeled
+$32 as floor. It happened to be zero in the accepted attic, save/load and
restart captures; their raw actor records have been rechecked at +$2E and
still pass. The floor-transition route exposed and corrected the error.

## First-room controls

`GAMEINPUT=1` implies `INGAME=1` and supplies ordinary keyboard transitions:
Up, release, Shift+Up, release, F, release, Space+Up, release. The keys match
the manual's movement/action controls and its F shortcut for Fight mode.
`amiga/gameplay.gdb` records actor state and internal frames at each boundary;
`tools/mac_gameplay.lua` performs the same sequence on the original Mac IIx.
Create `tmp/m3-input` before running these fixtures.

The controller begins after the first published room with actor 1/body 12 in
floor/room 0. Each phase has a minimum hold/release interval and waits for
the requested walking (254), running (255), kick (262) or idle (4) animation.
Fight is a queued character: native acceptance observes its delivered keyDown
event and then a subsequent GetKeys poll; the Mac observer verifies the
original Dark+$58E8 Fight dispatcher with character $66/$46. The kick is the
resulting behavioral positive control. Every phase has a 1,200-tick deadline;
a missing command fails rather than counting idle time as progress.

The paired runs `tmp/m3-death/control-consumed-mac2.log` and
`control-consumed-gdb.log` exit zero and pass `check_gameplay.py`. Both move
817 units during walk/release; run/release moves 1,014 on the Mac and 824 on
the Amiga, then both kick and return to stationary idle with all keys released.
These are phase displacements, not frame-rate measurements. The native Fight
event arrives 80 ticks after injection versus two on the Mac. Its older
fixed-duration controller could advance to Space before that queued command
arrived; holding Fight longer also passes, independently of the point-drawing
change. No game instructions, actor state or decisions are overridden.

This exposed and fixed a real bug: the old DOS handback cleared held keys and
their queue on every resource read. Keyboard interrupts now remain active
through those windows. `tmp/m3-input/window-controls-run.log` passes all 27
key checks, including hold/release across disk access, plus existing file,
clock, Paula and display-buffer checks. The startup shortcut now uses bounded
Space presses so the game's wait-for-release paths work without accidental
key clearing.

The native first-room interval observes WaitNextEvent (25), GetKeys (26),
Button (25) and ObscureCursor (1). The Mac control interval observes
WaitNextEvent (33), GetNextEvent (33), GetKeys (33) and Button (32); Mac
WaitNextEvent calls the OS GetNextEvent implementation, whereas the native
wrapper calls its shared event helper directly. Native counting includes the
room setup; the Mac trace begins at the first attic frame. ObscureCursor's
startup contract is already verified below. Neither control trace calls
StillDown, FlushEvents or SystemClick. Their absence is not new ABI acceptance;
SystemClick remains unsupported, and broader menu/desktop paths remain outside
this control fixture.

## Direct-game build — 2026-10-03

`INGAME=1` enters Carnby's attic through ordinary queued keys and GetKeys state.
It retains all initialization and original instructions, suppresses boot-frame
publication, and releases its keys before handing control to gameplay. Normal
builds retain the full startup sequence. See the build instructions in
[development.md](development.md).

The audio-on, warp-off 68030 runs `tmp/m3-input/ingame6-run.log` and
`ingame7-run.log` both exit zero after two original Dark+$5658 loop entries,
with character 0, room 0, camera 0 and gameplay mode 1. The captured first room
shows Carnby in the attic, matching the normal Mac new-game route. Suppressing
boot frames leaves that entire 640×480 indexed-screen RGB image unchanged.
The final route reaches the gameplay flag at tick 1940 (about 32 seconds),
with zero frames published before that point; room and song loading follow.
The retained `amiga/ingame.gdb` check passes in
`tmp/m3-input/ingame-final-run.log`: all four injected keys are released,
and the first room is the first published frame at tick 2335 (about 39 seconds).
This verifies automatic entry, not walking/running/action acceptance.

## M3.1 entry investigation — 2026-10-03

The manual's printed pages 6 and 8 specify arrows for forward/backward/turning,
Shift+Up (or a quick second Up press) for running, and Space plus an arrow for
fighting. These raw keys already map to the appropriate Mac virtual keys;
gameplay behavior still needs native verification.

The audio-on, warp-off 68030 observation
`tmp/m3-input/story-return-audio.log` exits zero at the original
Dan2+$2086 return from the letter. Normal input selects New Game at tick 1867,
releases Return at 1866, reaches the Carnby portrait at 2042, and returns from
all eight letter pages at 2920. This verifies entry through the front end, not
the first-room gameplay loop. The original Mac session in
`tools/mac_trap_session.lua` uses Escape after the letter's subsequent story
intro before verifying the attic. `INGAME=1` now covers that transition as well
as the earlier startup scenes.

Earlier `reach` and `state` attempts in that folder timed out and are not
acceptance. Their wrapper appended audio options after the diagnostic runner's
`audio_driver=dummy`; FS-UAE kept the first option. The corrected local wrapper
removes that option before launching, and the accepted core log confirms
CoreAudio, an opened audio device and warp zero. The ordinary owner-facing
full-startup run was not affected by that diagnostic-wrapper issue.

The checkpoint sections below preserve service-level evidence. References to
an intermediate startup stop or a then-pending M2 gate are historical; current
acceptance is recorded in [development.md](development.md), and remaining work
is in [open-work.md](open-work.md). Unsupported contracts remain unsupported
unless a later section explicitly verifies them.

The original Engine+$44F0 WaitNextEvent passes mask $FFFF, a 16-byte
EventRecord, zero sleep and a nil mouse region. Original bytes at
+$44E2–+$44F1 are `42273f3cffff2f2e000c42a742a7a860`; no game instructions
are changed. The measured service consumes fourteen stack bytes, writes
$0100/$0000 to the Boolean result word and D0, and preserves D3–D7/A2–A6.
D1/D2/A0/A1 are scratch registers; the port preserves them additionally.

The Mac startup sequence is activation of the game window, Finder's high-level
`aevt/oapp` launch event, updates for the game and background windows, then null
events. The standalone Amiga process has no Finder launch event. Its sequence is
activation, the same two window updates, then null. This is real pending window
state: showing the front window queues activation; polling consumes it only when
selected by the mask. Updates remain pending while the actual update region is
nonempty and are cleared by EndUpdate. Hidden dialog records do not produce
presentation events. Key and mouse events reuse the inherited native input queue.

Each ordinary event uses the current tick clock, global pointer position and
modifiers. Activation adds activeFlag. The Amiga display already maintains global
pointer coordinates, so the inherited Vette (64,91) addition has been removed
from event records and initial low-memory mouse shadows. Sleep is ignored under
design §4.9; nonnil mouse-region wakeups remain an explicit unsupported trap.
The first-room gameplay extension is described above; broader window lifecycle
and high-level events remain later M3 work.

Reproduce with the documented headless MAME command and
`tools/mac_startup_events.lua`, then the combined native `menu_lifecycle.gdb`
observer. The checker validates caller bytes, every record and its surrounding
bytes, stack cleanup, preserved registers, source windows, clock and coordinates:

```sh
python3 tools/check_startup_events.py tmp/m2-event-reference.log --reference-status 0 \
  --native tmp/m2-event-native-final.log --native-status 0
```

Supply the actual terminal statuses. The reference captures eight calls; native
captures four before its next explicit stop at ObscureCursor, Engine+$0FF6.
No rendered cursor or intro acceptance is implied.

M2.3g15 continues beyond the first idle event. The number of subsequent null
polls depends on emulated tick progress, so the current checker validates every
captured call and requires the measured initial activation/update sequence,
followed only by null events, rather than requiring exactly four native calls.
The accepted cursor run records nine polls before GetForeColor, Dan1+$623C.

At a return-PC breakpoint, already-popped argument slots are no longer live.
An interrupt may reuse them before the observer reads memory. M2.3g16 captured
that case: saved A5/A6 and the return-PC exception frame occupy the old argument
area. Acceptance checks input arguments at entry, the live Boolean at return,
stack position, registers and guarded EventRecord; it does not require dead
argument storage to remain unchanged.

## GetKeys

The first original polling call is Dan1+$583A. Bytes +$5836–$583B are
`486efff0a976`, passing a 16-byte local KeyMap. The reference observer
`mac_getkeys.lua` uses actual ADB input and captures released, held A, and
released A states. A is virtual key zero: byte zero changes from 0 to 1 and
back to 0. All other map bytes remain zero. The call writes exactly 16 bytes,
preserves four guard bytes on each side, pops four argument bytes, clears D0.w
while retaining its upper word, and preserves D2–D7/A2–A6. D1/A0/A1 are scratch.
`tmp/m2-getkeys-reference.log` completes normally with all three states.

The new native adapter follows Vette's current-level snapshot approach. It
uses the existing raw-to-Mac translation and `aitdInputKeyDown`, combines
aliases such as left/right Shift, and leaves queued events untouched. It does
not consume events to derive held state and does not change game instructions.
A nil destination remains a named unsupported GetKeys call.

The native window fixture now verifies eleven guarded snapshots: no keys,
A, A+Space, releases, both Shift aliases with separate releases, and the left
arrow. It then reads back all ten original press/release events in order.
`tmp/m2-getkeys-window-core-final.log` exits zero with the new checks and the
existing 1 MiB read, clock, Paula, DOS, save/readback and bitplane checks.
The production build passes no-float and 82-symbol audits; the host suite and
95-script MAME literal audit also pass.

`tmp/m2-getkeys-native.log` completes normally. Its original GetKeys call matches
the reference's exact output extent, guarded map, D0.w result, preserved
registers and four-byte argument cleanup. All 35 integrated comparisons pass.
Execution advances to native sound-driver selector 13 at Core+$137E, with that
service explicitly pending (2,750 entered / 2,749 completed, active=1). This is
not music-playback acceptance; M2.3g37 covers the next contract. Original MDRV
remains absent.
