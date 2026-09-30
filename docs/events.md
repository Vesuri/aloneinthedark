# Startup events

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
Full gameplay input, broader window lifecycle and high-level events remain M3.

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
