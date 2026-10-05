# Development

Unattended `amiga/diag_run.sh` defaults to maximum-speed `a4000-030` and warp.
Use `EXTRA_ARGS=--warp_mode=0` explicitly for real-time diagnostics.
The optional `a4000-060` configuration is an unlimited-speed development pilot,
not full 68060 acceptance.
Use explicit `AMIGA_CONFIG=a1200-020` for baseline acceptance or
`AMIGA_CONFIG=a4000-030-reference` for same-clock Mac comparisons. Normal
interactive launch and the baseline regression keep their existing settings.
Warp and maximum CPU speed are diagnostic aids, not performance evidence.

## Emulator speed pilots — 2026-10-06

The identical bounded ordinary-input pilot reaches the first attic route
checkpoint on unlimited-speed 68030 and 68060, both with warp, the same binary,
2 MB chip/8 MB fast RAM and FPU/MMU/JIT disabled. Both observers exit zero.
Elapsed host times are 62.85 and 64.15 seconds respectively: this short pilot
shows no useful gain from selecting 68060, so keep 68030 as the default.
This is startup-to-checkpoint elapsed time, not scene FPS or full CPU acceptance;
the differing game ticks/frame counts prevent an instruction-throughput claim.
Evidence: `tmp/cpu-speed/{030-paired,060}.log` and `.run-speed*/logs/`.
The core reports 68060, while Kickstart reports AttnFlags=15 (68040 flags),
so full CPU/OS compatibility remains open.

The host reports arm64 but the installed FS-UAE executable is x86_64; it runs
through host translation. A separate 68030 JIT pilot enables the actual 8192 KB
translation cache, then fails during ROM boot with an illegal access at
`40001000`, before the game/debugger connects. Its runner exits one after
3.37 seconds (`tmp/cpu-speed/jit.log`, `.run-speedjit/logs/fs-uae.log.txt`).
No working JIT configuration is retained. A native host build or alternative
emulator with compatible observers is a larger potential improvement, still
requiring a measured pilot; the current evidence does not quantify translation
cost or establish it as the sole bottleneck.

## Unattended capture overhead — 2026-10-05

A paused, read-only A5-world capture on maximum-speed `a4000-030` with warp
costs 0.93 seconds with GDB's default packet size. Forcing 8192-byte reads
costs 1.96 seconds; both 75,616-byte files have identical SHA-256 digests.
The observer exits zero (`tmp/m3-room5-combat/capture-benchmark-gdb.log`).
Keep the default: larger packets do not accelerate this installed debugger.
These are host capture costs, excluded from emulated gameplay timing, and
cannot establish where the game's rendering time goes. Maximum CPU speed
and warp are already enabled for functional pilots; fixed-clock acceptance
still uses its explicit configuration.

## Scripted keyboard transitions — 2026-10-05

Probe input now enqueues only changed held levels. During the room 5 enemy's
original death animation, its controller repeatedly requested releases at
trap boundaries; these generated 10,244 dropped transitions and could lose the
subsequent O command. Duplicate releases no longer fill the 32-entry queue.
Physical keyboard interrupt handling and ordinary game controls are unchanged.

The bounded fast return pilot and full checker exit zero in
`tmp/m3-room5-return/fast-transitions-{run,gdb,checked}.log`, with captures in
`fast-transitions-evidence/`. Every phase has zero drops and the real
Open/Search event is delivered. The 68020 also has zero drops through combat;
its living hero is knocked into room 4, so that observer correctly ends with
an unmet route condition (`020-transitions-gdb.log`), not return acceptance.
Arbitrary-angle steering was rejected: both original and native bounded
observers miss the requested turn condition. Retain the measured controller
until a replacement is verified against the actual original controls.

## Native room 5 return — 2026-10-05

Clean-build `ROOM5RETURN=1`, then use `amiga/room5_return.gdb` and
`tools/check_room5_return.py` with the original `mac_room5_return.lua` observer.
The flag enables the measured combat prefix and a 26-phase continuation through
Open/Search, wardrobe Search, the northern exit and a newly published manual
hallway frame. The doorway approach starts farther inside the original measured
alignment range, allowing for walking drift. Ordinary O retries are bounded and
cannot advance until the real action state is 64; they do not set game variables.

The fast pilot and fixed-clock 68030 observer/checker exit zero:
`tmp/m3-room5-return/{fast,030}-transitions-{run,gdb,checked}.log`. Their captures
are preserved in the corresponding evidence folders. The fixed 68030 retains
12 health, inventory and enemy removal, with zero dropped input transitions and
one delivered Open/Search event. Its conservative activity total is 5,156 ticks
(85.93 seconds): 1,740 movement, 905 turning and 2,511 kicking, from 4,156 samples.
The same binary has clean no-float and 167 data-symbol audits.

The 68020 return remains unaccepted: enemy knockback moves the living hero into
room 4, and the strict observer ends instead of counting an unmeasured route.
This is an optional diagnostic, not completion of the ten-minute M3 gate.

## Original room 5 return and activity timing — 2026-10-05

`tools/mac_room5_return.lua` extends the measured room 5 combat route with
Open/Search, a wardrobe Search and the actual room 5 → hallway transition.
Create `tmp/m3-room5-return/` before using the normal headless MAME command.
The current source observer exits zero in `tmp/m3-room5-return/mac-mode.log`;
Carnby retains 18 health, Actions/lamp inventory and the removed enemy, and
returns to room 1 with animation 4/manual track 1. No Find/Take is invoked at
the empty wardrobe. The mode change must actually reach VAR90=64 before movement.

`tools/mame_active_gameplay.lua` supplies read-only activity timing. It credits
only adjacent samples, at most two ticks apart, with the same first-floor room,
living Carnby body 12, manual control, a held movement/turn/kick key and the
corresponding animation. Idle, release waits, scene changes and unsampled gaps
contribute zero. This route credits 4,942 ticks (82.37 seconds): 1,465 movement,
919 turning and 2,558 kicking, from 4,727 credited samples across rooms 0/1/5/6.
It establishes original-Mac coverage only; the native return extension still
needs both CPU acceptance checks and the ten-minute M3 gate remains open.

## Room 5 encounter — 2026-10-05

Build `ROOM5COMBAT=1` (SOUTHROOMS and its prerequisites), then run
`amiga/room5_combat.gdb`; `tools/mac_room5_combat.lua` supplies the original
Mac route. Ordinary controls take/use the lamp, descend, enter room 5, select
Fight and kick the naturally spawned enemy 62/body 73. Its initial counter
VAR20 is 1, spawn variables 55/56 are 1 and health VAR57 is 10. Life 82/83
leads to active life 84; the original death animation is 57. Removal clears
VAR20/57 and the enemy's world slot/floor/room. Actions and the lamp remain
in inventory, with Actions selected.

The controller releases its approach when enemy damage begins, and each attack
press ends after 180 ticks even when a hit interrupts the attempted kick.
Between attacks it faces the enemy using ordinary turns. The lamp prerequisite
uses the southern-room Mac route's 3600 x waypoint and north tolerance of
8 angle units. Inheriting the bedroom route's 3800 waypoint and releasing at
beta 26 left subsequent quarter-turns off-axis and stalled the baseline stairs
turn; the corrected prefix passes both CPUs. Original game instructions and
state are unchanged.

Original Mac, baseline 68020 and fixed-clock 68030 observers and
`tools/check_room5_combat.py` exit zero. Evidence is
`tmp/m3-room5-combat/mac-reactive.log` and
`{020,030}-aligned-{gdb,checked}.log`, with native captures preserved in the
corresponding `{020,030}-evidence/` folders. The checker retains the complete
lamp/stairs/southern-room prefix and its artwork checks, requires delivered
Fight, actual kicks, damage and removal, then verifies a later published
living manual gameplay frame. Hero health must stay positive and cannot
increase; the enemy can already hit during the approach, so native initial
health need not be exactly 20. Final health is 18 on Mac, 18 on the 68020 and
17 on the 68030. The same binary passes both CPUs with clean no-float and
160 data-symbol audits. This is functional coverage; it does not establish
exact M6 combat pixels, real-time performance or the ten-minute M3 gate.

## Bedroom encounter — 2026-10-05

Clean-build `COMBATROUTE=1` (BEDROOMKEY and its prerequisites), then run
`amiga/combat_route.gdb`. `tools/mac_combat_route.lua` supplies the original
Mac route. Ordinary controls take/use the lamp, descend the stairs and take
the bedroom key. The naturally closed door and spawned enemy are required;
the controller selects Close in the action menu, selects Fight before reopening
the door, and kicks the enemy. Both scripts deliberately turn west once, then
choose a cardinal heading toward the enemy between attacks. Each subsequent attack press ends after 180
ticks even if a hit interrupts the attempted kick; holding input indefinitely
while waiting for that kick stalled the diagnostic. No game state or original
instructions are changed.

`tools/check_combat_route.py` retains the complete lamp/stairs/key prefix,
including its artwork checks. It requires the byte-checked original Fight
branch (Dark+$599A), actual Close/Fight results, a consumed turn, kick animation
262, damage, enemy death/removal, positive hero health and newly completed
manual gameplay after victory. Inventory remains Actions/key/lamp, with Actions
in hand. This is functional coverage, not an exact M6 combat-frame comparison.

The original, baseline 68020 and fixed-clock 68030 observers and checkers
exit zero: `tmp/m3-combat/mac-aim-release.log` and
`tmp/m3-combat/{020,030}-aim-release-{gdb,checked}.log`. Accepted captures are
preserved in `tmp/m3-combat/{020,030}-evidence/`; Carnby ends with 17 health on
the Mac and 18/14 on the Amiga 68020/68030. The same binary passes both CPUs,
with clean no-float and 159 data-symbol audits. The broader first-floor coverage
and the ten-minute
M3 gate remain open; do not count idle waits or these warped runs as real-time
performance evidence.

## Book Take and reading — 2026-10-05

Clean-build `BOOKROUTE=1` (LAMPROUTE/INGAME/PROBES only), then run
`amiga/book_route.gdb`. `tools/mac_book_route.lua` performs the original route.
After lamp Take, ordinary controls cross the attic and search the bookcase
from its west side. The 39-phase continuation takes Book 12, waits for the
Find screen to disappear and a later gameplay publication, selects the actual
Book inventory highlight, executes Read and exits with Escape. It neither
writes game state nor replaces original decisions.

Book 12 is already unplaced: its Find flags are $0604, not $4604. Take changes
flags to $8604 and inventory to (2,12,13); Read changes its name from 205 to
550. The controller waits for the real Find canvas and Read action 4, then
requires idle/manual control, in-hand Actions 2 and a later completed gameplay
frame. `tools/check_book_route.py` verifies both observers' zero status, lamp
ownership, every phase, bookcase contact, insertion and Read result. Exact
original “You Find / A Book” title pixels are checked, along with the entire
320×200 first reading page's artwork and text except its blinking arrow.
The arrow exclusion is x=420–444/y=330–349 in the 640×480 logical captures.
These logical comparisons do not substitute for the deferred system-window
host-capture acceptance.

Accepted evidence: `tmp/m3-explore/{mac-book-route,book-020-gdb,
book-020-checked,book-030-gdb,book-030-checked}.log`, with actual zero observer
and checker statuses. Per-CPU captures are retained in `book-020-evidence/`
and `book-030-evidence/` alongside those logs. The same binary passes both
CPUs; clean no-float and 152 data-symbol audits pass.
`BOOKPAGES=1` additionally runs the original sequence 0→1→0→1→2→3 and
Return on the final page. `tools/mac_book_pages.lua` observes the byte-checked
Dan1+$4870 input wait: D3 is the page and D5 its last-page flag. The native
controller reads those same registers at the validated Engine+$1F84 input
trap/stack chain, adds 19 bounded page phases and uses ordinary arrow/Return
keys. `tools/check_book_pages.py` retains all Take/Read state checks and
compares the entire reading viewport on every visit, excluding only the two
blinking arrow boxes (x=195–219 and 420–444/y=330–349). It verifies the four
pages, the repeated previous page, original last-page flag and published
manual gameplay after normal completion. No production services or original
instructions changed.

Full-reading evidence is `tmp/m3-explore/{mac-book-pages-maintained,
book-pages-020-gdb,book-pages-020-checked,book-pages-030-gdb,
book-pages-030-checked}.log`, all with actual zero observer/checker statuses.
Per-CPU pairs are in `book-pages-020-evidence/` and `book-pages-030-evidence/`.
The same binary passes both CPUs, with clean no-float and 156 data-symbol
audits. These bounded warped runs establish functionality and pixels, not
real-time page-transition performance. Further combat/menu coverage and the
ten-minute M3 gate remain open.

## Southern first-floor room entry — 2026-10-05

Clean-build `SOUTHROOMS=1` (HALLWAY and its prerequisites), then run
`amiga/south_rooms.gdb`. `tools/mac_south_rooms.lua` performs the original route.
After lamp Use, stairs and the hallway, ordinary movement aligns x=2720–2900,
faces south, approaches the opposite doorway and enters floor 1/room 5.
The 52-phase route releases movement and waits for idle/manual control and a
later completed scene. `tools/check_south_rooms.py` retains the full hallway
prefix acceptance, verifies the actual room 1→5 transition, doorway alignment,
original/native entrance coordinates, body 12/idle 4/manual 1 and unchanged
Actions/lamp inventory and ownership. Both captured scene/palette extents and
native scene population are checked; this is not an exact M6 frame comparison.

Accepted local evidence is `tmp/m3-explore/{mac-south,south-020-gdb,
south-020-checked,south-030-gdb,south-030-checked}.log`, all with actual zero
observer and checker statuses. The same binary passes baseline 68020 and
fixed-clock 68030. Clean-build no-float and 153 data-symbol audits pass.
No production services or original instructions changed. Reading, combat/menu
coverage and the ten-minute M3 gate remain open.

## Saber attacks, breakage and blade recovery — 2026-10-05

Clean-build `SABERBREAK=1`, then run `amiga/saber_break.gdb` on `a1200-020`
or fixed-clock `a4000-030-reference`. The option includes SABERROUTE and its
prerequisites. `tools/mac_saber_break.lua` supplies the original reference;
`tools/check_saber_break.py` verifies both observers' actual zero exit statuses,
the entire cabinet prefix and all 115 native phases.

Ordinary Space with Up/Left/Right produces animations 41/37/39. Breakage changes
saber 38's found body/name from 40/208 to 43/580, retaining flags $8601, and
changes Carnby from body 44 to body 45 while the saber remains equipped.
The diagnostic recognises both bodies, releases held attack keys, uses O to
restore body 12/in-hand Actions 2 and walks into the dropped-blade Find state.
Take changes blade 41 from flags $4600 to $8600 and removes it from the room.
Inventory count becomes five, with slots (2,41,38,37,13); a later completed
scene must show idle manual bedroom gameplay. Exact original “You Find / A
Saber Blade” white title pixels and placement are checked alongside the actual
world/inventory changes and dismissal of the Find view.

The original breaks by the third direction in this capture; the accepted 020
needed one additional Up attack and the 030 needed two. The controller waits
120 ticks after each attack animation begins and uses bounded ordinary retries
from manual idle until actual breakage. It never infers success from an attack
count or writes actors. These state-paired captures do not establish the cause
of the differing break timing. All accepted runs and checks exit zero:
`tmp/m3-explore/{mac-blade,saber-break-native-gdb,saber-break-checked,
saber-break-030-gdb,saber-break-030-checked}.log`. Clean-build no-float and
155 data-symbol audits pass. No production services or original game
instructions changed. Further rooms, reading/combat coverage and the ten-minute
M3 gate remain open.

## Cabinet key Use and saber pickup — 2026-10-05

Clean-build `SABERROUTE=1` (BEDROOMKEY and its prerequisites), then run
`saber_route.gdb` on `a1200-020` or fixed-clock `a4000-030-reference`. `tools/mac_saber_route.lua` performs the
paired original session. The 98-phase route retains lamp Use, descent, hallway
and key pickup, crosses east before heading south so movable furniture 32/body
33 remains at (-800,-570), approaches the cabinet and uses inventory key 37.
It waits for the actual Find state before Return, takes saber 38 and equips it.
The original saber found body/name are 40/208; Take changes flags $0601→$8601,
inventory count 3→4 and slots to (2,38,37,13). Use equips body 44/in-hand 38;
a later completed native scene confirms manual bedroom gameplay.

`tools/check_saber_route.py` retains all prefix checks and verifies the actual
Find state, exact original “You Find / An Old Cavalry Saber” text and horizontal
placement, original/native inventory changes, retained key/lamp and final
body/manual state. Accepted local evidence is
`tmp/m3-explore/{mac-saber,saber-native-gdb,saber-checked}.log`, with actual zero
observer/checker statuses. The same binary also passes fixed-clock 68030 with
`saber-030-{gdb,checked}.log`, including the complete prefix, exact Find text,
actual pickup and equipped publication. No-float and 154 data-symbol audits pass.
This remains a prerequisite, not the ten-minute M3 gate.

The cabinet script's primary ListLife 45 data requires contact with Carnby as
well as relative position and key 37. A native first action stopped just short
of contact. The diagnostic now retries ordinary Space only from manual idle
and waits for the measured Find state (A5−$D864=0, track 0), allowing 300 ticks
for painting before Take. The accepted 68020 route needed one retry. Its
attempt order and manual state are checked; an unopened cabinet cannot fall
through to Return and accidentally open inventory. Original instructions and
production services are unchanged.

Captured deadline failures also identified movable furniture, doorframe
clearance and the final stair heading as distinct obstructions. Diagnostics use
actual animation/position checks: the attic alignment range is z=3920–4070,
room-0 west doorway z=2720–2900, hallway bedroom line x=2720–2900, cabinet
z=1200–1380 and approach x=1640–1680. The stair exit corrects x into -350–32
and faces north before walking onward. Bounds account for measured unequal
forward/backward steps; actors and positions are never written by the test.
Failure observers preserve logical frame, palette and A5 state for diagnosis.

Further first-floor rooms are still being measured. The cabinet prerequisite
does not establish the ten-minute M3 gate.

## First-floor bedroom key pickup — 2026-10-05

Clean-build `BEDROOMKEY=1` (HALLWAY/FIRSTFLOOR and their prerequisites),
then run `bedroom_key.gdb` on `a1200-020` or fixed-clock
`a4000-030-reference`. `tools/mac_bedroom_key.lua`
performs the paired original session. It retains lamp pickup/Use, mode switch,
attic descent and the first-floor hallway; approaches the north bedroom doorway,
executes Open/Search, enters floor 1/room 2, walks to the desk, searches and
accepts Take for key 37. The original found body/name are 46/209.

`tools/check_firstfloor_session.py --key` retains all prior route, exact lamp
feedback and door-rotation gates, requires 64 exploration phases and verifies
key flags $0601→$8601, inventory count 2→3 and slots (2,37,13): Actions stays
first, the new key is inserted and the lamp is retained. Captured Carnby must
finish in floor 1/room 2, body 12/idle 4/manual 1 at the desk. The native observer
records a later completed scene after Take. Accepted local evidence is
`tmp/m3-explore/{mac-key,key-native-gdb,key-checked,key-030-gdb,key-030-checked}.log`,
all passing with zero observer exit statuses.
Clean-build no-float and 153-symbol audits pass. No production service or original
instruction changes were needed. This remains a shorter exploration prerequisite,
not the ten-minute M3 gate. Cabinet/key Use and further rooms remain open.

Fixed-coordinate release thresholds proved insufficient for autonomous passage
alignment: movement can continue after release, and slightly diagonal headings
consume more opening clearance. Captured named failures identify upper/lower
attic walls and both bedroom doorframe edges. The diagnostic controller now
uses ordinary single steps, waits for their walking/backward animation and
subsequent idle state, then rechecks position before turning into the passage.
The current attic target is z=3920–4070, the hallway target x=2720–2900; actual source
actors/positions are never written. The paired Mac uses the same correction.
The checker verifies press/release/idle order, advancing ticks and actual
movement direction for each native correction, plus both final alignment bounds.
This bounded correction belongs to the scripted test, not game decisions.


## First-floor hallway and door interaction — 2026-10-05

Clean-build `HALLWAY=1` (FIRSTFLOOR and its prerequisite routes), then run
`hallway_session.gdb` with the diagnostic runner on `a1200-020`.
`tools/mac_hallway_session.lua` performs the paired original session. After
verified lamp pickup/Use/movement, ordinary O input restores Open/Search and
body 12/idle animation 4 before descending. The lamp remains in inventory.
The route enters floor 1/room 0, approaches its west doorway along z≈2800,
executes O/Space, waits for manual control and crosses into room 1.

`tools/check_firstfloor_session.py --hallway` retains exact lamp feedback and
all prior route gates. It requires 30 lamp-control and 39 exploration phases,
captured closed door actor 0 (world object 22/body 25, beta 256, floor 1/room 0),
rotation to beta ≥480 after Open/Search, actual room 0→1 and released manual
idle Carnby in the hallway. Accepted local evidence is
`tmp/m3-explore/{mac-hallway-session,hallway-native-gdb,hallway-checked}.log`,
all passing. The same binary passes fixed-clock `a4000-030-reference`,
with `hallway-030-{gdb,checked}.log`, including original door rotation and
exact lamp feedback. Build no-float and 152-symbol audits pass. No production service
or game instruction changes were needed. Longer first-floor routes remain open.

Two equipped-lamp attempts hit opposite sides of the attic opening. Captured
positions and headings prove those wall collisions; the failures are retained
in `hallway-native-{wall,lower-wall}-failure.log`. Moving a narrow waypoint
alone did not reliably fit the lamp stance through the opening. The retained
route uses the original Open/Search mode switch before the already verified
unarmed descent, then verifies the first-floor door separately. The original
Mac also failed when a west-door approach overshot below its usable opening;
the retained northward release threshold is z=3200, leaving a wider margin.


## Combined lamp-to-first-floor session — 2026-10-05

Clean-build `FIRSTFLOOR=1`, which implies LAMPSTAIRS/LAMPUSE,
EXPLOREROUTE/INGAME/PROBES. Run `firstfloor_session.gdb` with the diagnostic
runner on `a1200-020`; `tools/mac_firstfloor_session.lua` performs the paired
original route. The same session takes the lamp, executes empty-lamp Use,
proves movement afterward, follows the wide attic stair route, restores manual
control in floor 1/room 6, sends O/Space Open/Search input and walks through the
passage into first-floor room 0. Those inputs reset the equipped lamp stance
to body 12/animation 4. No captured world-object change establishes a door
opening, so this gate claims passage and input coverage, not a changed door.

`tools/check_firstfloor_session.py` retains the complete lamp-use state and
exact feedback checks, then requires all 26 exploration phases, actual attic
waypoints, floor 0→1, room 6→0, captured Carnby body/room/floor/manual identity
and populated first-floor scene/palette captures. The equipped idle animation
287 satisfies diagnostic release waits; the original actor animation itself
is never changed. The diagnostic controllers run consecutively, not concurrently.
Accepted evidence is `tmp/m3-explore/{mac-session,session-native-gdb,
session-checked}.log`, all passing. Clean-build no-float and 152-symbol audits
pass. The fixed-clock `a4000-030-reference` session also passes, with
`session-030-{gdb,checked}.log`. Its feedback initially failed a checker that
searched only rows 310–349: an older Open/Search message occupied the bottom
slot, placing the correct empty-lamp message above it. The checker now searches
the complete measured message stack at rows 285–349, retaining exact glyphs,
colour and horizontal position. It accepts variable stack placement, as the
existing sound-toggle feedback checker does; the runtime needed no change.
This remains shorter than ten minutes; hallway, further room interactions
and longer combat/exploration coverage remain open.


## Autonomous empty-lamp Use — 2026-10-05

Clean-build `LAMPUSE=1` (LAMPROUTE/INGAME/PROBES), then use
`lamp_use.gdb` with the diagnostic runner on `a1200-020`.
`tools/mac_lamp_use.lua` runs the paired original route. After taking the lamp,
Return opens inventory, Down selects the lamp, Return selects its actions and
Return executes Use. The original displays “The lamp has no oil”, changes
Carnby to body 11/animation 287 and keeps manual track mode 1. The native route
waits for this measured state and a completed scene, then walks backward at
least 400 units and releases movement into the same lamp stance. A5−$D8A8
is observed as 13 after selection; no game state or instructions are changed.

`tools/check_lamp_use.py` requires both zero statuses, all 27 native phases,
paired pickup/menu/Use captures, retained inventory/world removal, manual
control and actual movement after Use. It also checks the published message
against the original Times/14 glyph mask, exact colour and horizontal position.
Accepted local evidence is `tmp/m3-explore/{mac-lamp-use,lamp-use-native-gdb,
lamp-use-checked}.log`. The clean build passes no-float and 150-symbol audits.
The same binary passes `a4000-030-reference` with
`lamp-use-030-{gdb,checked}.log`, including exact feedback.
No production compatibility service needed a change. This is an attic
object-use prerequisite; ten minutes of actual first-floor exploration remains
open. The observer ends without claiming normal Quit cleanup.

An initial diagnostic incorrectly waited for animation 4 after Use. The
original and native both retain animation 287, so that acceptance failed.
The corrected route positively verifies subsequent movement and return to
the measured lamp stance. Native menu execution can lag the input release;
the first attempt did execute Use, despite an early observation suggesting
a missed key press. State completion, not that intermediate observation,
is now the gate.


## Autonomous oil-lamp pickup — 2026-10-05

Clean-build `LAMPROUTE=1` (INGAME/PROBES), then run
`DIAG_RUN_DIR=.run-saveload AMIGA_CONFIG=a1200-020
GDBSCRIPT=lamp_route.gdb amiga/diag_run.sh 600`. The route uses ordinary
arrows to approach the table, O for Open/Search, Space to search and Return
to accept Take. `tools/mac_lamp_pickup.lua` performs the same route on the
original Mac. It changes diagnostic input only.

`tools/check_lamp_pickup.py` requires actual zero statuses, the complete
phase sequence, captured Carnby identity, real movement, inventory count
1→2 with existing object 2 retained in slot 0 and lamp 13 inserted in slot 1,
object removal from floor/room 0 and idle manual gameplay after Take. The
native observer also requires a later completed scene publication. Accepted
local evidence is `tmp/m3-explore/{mac-lamp,lamp-native-gdb,lamp-checked}.log`.
The same binary also passes fixed-clock `a4000-030-reference`, with
`lamp-030-{gdb,checked}.log`. Build no-float and 150-symbol audits pass.
This verifies pickup; it does not yet verify using the lamp or ten minutes
of first-floor exploration. The observer ends after acceptance without claiming
normal Quit cleanup. No new production service was needed.


## Autonomous attic descent to first-floor manual control — 2026-10-05

Clean-build `EXPLOREROUTE=1`; it implies INGAME/PROBES. Run
`DIAG_RUN_DIR=.run-saveload AMIGA_CONFIG=a1200-020
GDBSCRIPT=explore_route.gdb amiga/diag_run.sh 600`. The same binary also passes
`a4000-030-reference` (fixed-clock 68030). `tools/mac_attic_stairs.lua` performs
the original Mac route with ordinary arrows and state-based completion.
The route backs into the open attic, turns around the stair partition, crosses
its side opening, turns north and walks into the original floor-change zone.
It releases movement at floor 1/room 6, then waits for original track mode 3,
track 31 to finish, manual mode 1/idle animation 4 to return and another complete
native scene publication. It changes only diagnostic controls, not game decisions,
actor positions or original instructions. The captured scenes show the same
first-floor stair entrance; position, beta, pose and Mac chrome differ.

`tools/check_attic_stairs.py` requires both actual zero statuses, all ordinary
move/release waypoints, floor 0→1, room 6, manual control, captured actor/log
position identity and populated scene/palette captures. It rejects wrong floors
and incomplete automatic tracks. Accepted local evidence is
`tmp/m3-explore/mac-stairs.log`, `020/{native-gdb,stairs-checked}.log` and
`030-{gdb,checked}.log`, all passing. Route elapsed time is 2,367 ticks/39.45 s
on Mac, 3,203/53.38 s on 68020 and 3,092/51.53 s on fixed-clock 68030. These
include movement, release waits, loading and scripted stairs; they are not steady
FPS or an attributed loading profile.

Earlier routes hit a stair wall or column. The retained route uses a wide path
rather than a narrow stopping interval. Exact-heading waits also missed the
quarter turn when its starting beta was slightly off-axis; the accepted route
uses a bounded heading tolerance and verifies resulting room/floor state.
A further observer error read actor +$32 (life mode) as floor. Descent exposed
floor 1 at +$2E; all maintained gameplay/death/save observers and captured-state
checkers now use that field. Previous raw attic/save/restart records have been
revalidated there and still pass. Early captures before the automatic stair
track completed are not manual-control acceptance.

This is an M3 first-floor prerequisite, not ten minutes of actual exploration.
Object use, further rooms and the ten-minute gate remain in open work. M6.3's
all-configuration `stairs` regression is also still pending.

## Save durability across abrupt restart — 2026-10-05

`bash amiga/durable_run.sh` repeats the A1200/68020 durability acceptance in
`.run-saveload`. The first SAVELOAD run stops at the first completed gameplay
publication after successful save close. `durable_save.gdb` captures the actor
and exits its observer; the runner kills only its recorded emulator, without
normal game Quit or driver shutdown. This is an abrupt emulator power cycle,
not a warm reset or a normal application restart. The surviving SAVE0.ITD is
36,254 bytes. `LOADONLY=1` then fresh-boots the same volume, moves Carnby at
least 300 units away, and selects Load through ordinary keys. It never saves.
The actual load reads 33,644 bytes and restores actor 1/body 12, (3231,−1548),
floor/room 0, idle animation 4; subsequent Quit cleanup passes.

`tools/check_durable_save.py` requires zero statuses, the save-success/frame
boundary, absence of normal Quit in the first run, real movement and reads in
the second run, identical save bytes before/after Load and captured restored
actor state. Accepted local logs are `tmp/m3-saveload/durable-{save-gdb,
load-gdb,checked}.log`; both bounded runners exit zero. Build no-float/probe
symbol audits also pass. This completes M3.6's immediate-save reset durability
requirement using an abrupt cold restart. No changes to production write/close
semantics were needed. M3's remaining gate is actual first-floor exploration.

## Autonomous save → move → load — 2026-10-05

Clean-build `SAVELOAD=1` and run `DIAG_RUN_DIR=.run-saveload
AMIGA_CONFIG=a1200-020 GDBSCRIPT=saveload.gdb amiga/diag_run.sh 360`.
SAVELOAD implies MENUPROBE/INGAME/PROBES. The diagnostic volume is isolated
from the normal `.run` saves. Ordinary keys toggle sound/music, enter `m3test`
in Save, walk Carnby at least 300 units, release movement, select Load and Quit.
The controller waits for successful save close, completed gameplay publication,
walk/idle animation and actual load reads before advancing. It observes file
services and actor state without editing original game instructions or decisions.

`tools/mac_saveload.lua` runs the same save/move/load route on a copied reference
hard disk. Its IO observer preserves full ROM caller addresses and waits for an
application A5 world with initialized Carnby. Earlier observers incorrectly
masked ROM addresses and sampled an OS A5 world; those failed runs are rejected.
`tools/check_saveload.py` requires zero runner statuses, ordered phases, positive
write/close/read evidence, captured actor identity and restored position/room.
Both machines close 36,254 save bytes, move from (3231,−1548), and restore that
position with actor 1/body 12, floor/room 0 and idle animation 4. Native load
reads 33,644 bytes; the reference also reads slot metadata (38,816 total).
The native run additionally verifies driver 8 register preservation, cleared
Paula/DMA resources, restored display/interrupt state and complete trap cleanup.
Accepted logs: `tmp/m3-saveload/{mac,gdb,checked}.log`, all exit zero.
This completes M3.5 on A1200/68020. The separate abrupt-restart acceptance above closes M3.6; normal Quit and
reload alone are not evidence for that requirement.

## Autonomous death and new-game restart — 2026-10-05

Clean-build `DEATHROUTE=1` and run `GDBSCRIPT=death_route.gdb
amiga/diag_run.sh 600`; select `AMIGA_CONFIG=a1200-020` for baseline acceptance.
The option implies GAMEINPUT/INGAME/PROBES. Ordinary controls first walk, run
and kick, then Back returns Carnby toward the starting area. The route waits
for real death, verifies natural BDISK2 loading, follows the corpse into room
6, returns through the original menu and re-arms diagnostic startup input for
a fresh Carnby game. It never writes game decisions or actor state.

`tools/mac_death_route.lua` performs the corresponding original Mac route.
`tools/check_death_route.py` requires actual zero statuses, real displacement,
13 preserved registers and 0/12 from the death music call, menu/restart phase
ordering, captured actor 1/body 12 at (3231,−1548), floor/room 0 and rendered
attic publication. Both the reference 68030 and baseline A1200/68020 pass.
Accepted local logs are `tmp/m3-death/death-back-mac2.log`,
`death-back-gdb.log`, `death-back-functional-checked.log` and `020/{gdb,checked}.log`.
Their corpse/menu/new-game routes complete without the earlier Line stop.
This closes the reached combat/death prerequisite, not ten minutes of actual
first-floor exploration. The old Line stop lacked pen/caller captures, so its
exact attribution remains unknown; the supported point's independent contract
is documented in [color-drawing.md](color-drawing.md).

The first exploratory Mac observer printed its return twice; the first native
death-only controller timed out when waiting from the control test's far-wall
position. Both were rejected. Returning toward the starting area resolves that
route failure on both selected native CPUs. The initial Mac restart capture
also preceded publication and was black despite initialized actor state.
The maintained capture now waits for the attic picture. Exact-pixel mode still
fails: 494 pixels differ inside Carnby's (303,192)–(334,262) footprint, with
Mac idle frame 1 versus native frame 2 and different interpolation timing.
The checker reports differences and offers `--exact-pixels`; this is functional
new-game acceptance, not a claim of exact restart-pose fidelity (M6.2).

Natural BDISK2 loading takes 490 ticks on the reference 68030 and 542 on the
020, versus 10 on the Mac. These whole-call measurements expose a substantial
M5 preparation cost; they do not attribute it to conversion alone.

## State-keyed first-room controller — 2026-10-05

The fixed-duration GAMEINPUT route missed Fight/kick on both the particle-point
implementation and its unchanged parent. A longer Fight hold passes; the
maintained route now checks delivered Fight input, walking/running/kick/idle
animations and floor/room identity before advancing. The paired Mac and native
checker passes with actual zero runner statuses. See [events.md](events.md).
Accepted logs are `tmp/m3-death/control-consumed-mac2.log`,
`control-consumed-gdb.log`, and `control-consumed-run.log`. Earlier transient
action-bit checks and a Mac debugger condition without explicit hex constants
were rejected; they are not acceptance. Native event delivery and original
Fight dispatch are different observation boundaries, so this is command and
behavior acceptance, not a matched latency measurement.

## M3.4 BDISK2 prerequisite — 2026-10-05

The original natural death sequence reaches SONG 131. Its original loading and
all 1,338 preflight events agree with the host decoder; complete native
interrupt playback, effect priority and cleanup also pass, with all four
runners exiting zero. See [the contract](sound-driver.md#bdisk2-music--2026-10-05).

The older ordinary native attic reproduction stopped at QuickDraw Line at tick
10,594 (`tmp/m3-death/native-observe-gdb.log`, status 1). The measured 2×2
particle point has full paired pixel/ABI acceptance, and the maintained
combat/death/restart route above now completes on both selected CPUs. The old
stop's exact pen attribution is unknown. All observers pin the application A5
world while system callbacks are active; discarded exploratory CurA5 readings
were temporary system-world values. Idle duration is not exploration coverage.

## M3.4 action-menu clicks — 2026-10-05

A held click inside the Actions pane changes no choice on the original Mac.
The Button trap observes MBState zero at (410,284); after release the selected
choice remains zero. Native VBI input at (410,285) yields the same choice and
no keyboard command. Escape executes no action, and Quit verifies full file,
resource, display, interrupt and Paula cleanup. The selected-action pane still
matches all 16,000 pixels, and the keyboard choices retain their paired timings.
Button and StillDown now consume the same VBI-owned state as event polling,
rather than a separate immediate hardware read. The click route reaches Button;
it does not establish a new StillDown caller ABI.

Reproduce with clean `ACTIONCLICK=1`, `amiga/action_clicks.gdb`, and
`tools/mac_action_clicks.lua` on the documented headless Mac setup. Check actual
zero statuses with `tools/check_action_clicks.py`. Accepted local logs are
`click-mac3-run.log`, `click-native-gdb.log` and `click-checked.log` under
`tmp/m3-action`. The first Mac observer watched the menu loop, which the held
button wait does not return to until release; that missing positive-control
capture was rejected. The final observer checks the Button trap itself.

The integrated `MENUPROBE=1 PROBES=1` dialog/keyboard regression also passes
exact startup artwork, Save/Load, four feedback glyphs and Quit restoration.
Its world naturally switches from SUSPENSE to MONSTER before the music toggle.
The checker now requires identical track ID across stop/resume rather than
assuming SUSPENSE persists throughout gameplay. Accepted logs are
`click-menu-gdb.log`, `click-menu-checked.log` and
`click-menu-keyboard-checked.log`; both runners exit zero.

## M3.4 FIGHT music — 2026-10-05

The next reached music prerequisite passes its paired original/native contract
and complete 1,206-event playback. The native natural attic request preserves
all 13 registers, returns 0/12 and owns the expected 38 resources/24 samples.
The full fixture proves interrupt progress without traps, effect priority and
cleanup. All runners exit zero; the combined checker uses the FIGHT reference
prefix (a preliminary check accidentally used MONSTER and was rejected).
See [the contract and reproduction](sound-driver.md#fight-music--2026-10-05).

## M3.4 autonomous action navigation — 2026-10-05

`ACTIONNAV=1` sends ordinary keyboard levels and VBI-owned pointer positions.
The original engine selects action 0, then 1 on Down, then 0 on Up. Key-to-choice
draw intervals are 28/25/26 ticks on Mac and 6/26/18 on Amiga. The navigation
build includes inactive diagnostic probes and file-ledger counters; the separate
ordinary-cost preview benchmark establishes frame rate. The selected-action
pane matches all 16,000 pixels exactly. Hovering over the choices changes no
selection on either platform; native low-memory coordinates and nonzero VBI
sample counts prove pointer input was exercised. Pointer clicks are verified in the route above.

Escape returns to room zero with action flags zero. Native Quit also verifies
all file/resource streams closed, no close errors, complete trap-service drain,
restored display/DMA/interrupt state and silenced Paula channels. Both final
runners exit zero. This covers keyboard navigation, hover and cancellation,
not combat, item use or the ten-minute first-floor route.

Reproduce after creating `tmp/m3-action`: clean-build `ACTIONNAV=1` and run
`GDBSCRIPT=action_navigation.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 240`.
Run `tools/mac_action_navigation.lua` with the same headless Mac IIx/debugger
configuration as the preview fixture, then `tools/check_action_navigation.py`
with both actual statuses. Accepted local logs are `navigation-mac3-run.log`,
`navigation-final-gdb.log` and `navigation-checked.log`. The initial missing
hover marker and unretained file-ledger-symbol runs fail acceptance. The final
fixture explicitly retains every debugger-read counter.


## M3.4 action-menu colour translation — 2026-10-05

Repeated srcCopy calls rebuild an identical 256-entry colour translation for
menu borders and preview updates. `ColorMap8Cache` keeps four owned maps keyed
by source/destination pointers and ctSeeds, inverse-table pointer/resolution
and table flags. Relocation and colour-environment changes miss the cache;
invalid inputs still fail, and an incomplete build is never published. Equal
seeds and the separately measured ditherCopy path retain their existing rules.
The cache adds about 1.2 KiB of static storage and removes a 256-byte trap local.

On the fixed-clock 68030, twenty Actions character-preview updates take
579 ticks after the change versus 1,192 before; the original Mac takes 726.
That is 2.07 versus 1.01 native updates per second, with 1.65 on the Mac.
Return to the first angle decrement takes 127 native ticks versus 231 before
and 106 on Mac (2.12/3.85/1.77 seconds). This is the first-preview boundary,
not an independent proof of when every menu pixel reaches the display.
The comparison uses ordinary-cost builds, emulated 60 Hz ticks, actor index 2
and the identical 0 through -160 rotation sequence. Diagnostic warp changes
only host duration. The completed 21st preview matches all 64,000 Mac viewport
pixels exactly using direct video memory and the hardware palette.

Reproduce after creating `tmp/m3-action`: clean-build `ACTIONPROBE=1`, then
`GDBSCRIPT=action_menu.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 240`.
Run `tools/mac_action_menu.lua` with the documented headless Mac IIx setup,
`-debug -debugger none -oslog` and local jump-table metadata from
`tools/mac_trap_map.py`. Preserve the native observer log and run
`tools/check_action_menu.py` with both actual zero statuses. Accepted captures
and logs are `cache-capture-gdb.log`, `mac-capture-run.log` and `cache-checked.log`
under `tmp/m3-action`. Host sanitizer tests cover exact permutation bytes,
seed/resolution/pointer invalidation, eviction and failed-build retry. The full
host suite and integrated startup/Save/Load/Quit regression pass, including
exact new-game/story frames, audio toggles, shutdown ABI and OS restoration.
The preview speed fix does not establish navigation or first-floor acceptance.

The latest owner stop remains SONG 132 (`FIGHT`), selector 0 at Core+$138C,
10,280 ticks after in-game entry; its status-1 trace is preserved in
`tmp/m3-action/manual-fight-gdb.log`. Its paired acceptance is recorded above.

## M3.4 death fade — 2026-10-04

The owner reports death followed by a loud stop. The captured service is
selector 19, gain 248 at Core+$1F0A, after 9,012 gameplay ticks; the failed
runner exits 1 and its trace is `tmp/m3-toolbox/manual-owner-death-stop-gdb.log`.
The original Mac reaches the same call. Its natural capture and 33 isolated
gain levels pass exact state/table and preserved-register checks. The native
68030 CPU fixture passes all 33 calls, active voice ownership, hardware volume
write values, seven new muted notes and complete song/DMA cleanup. Host
sanitizer checks and both link audits pass. The normal keyboard menu pair also
passes playback toggles, Save/Load, Quit ABI and complete OS restoration with
the gain change; both runners exit zero. Native implementation and the
reproduction procedure are in [the audio contract](sound-driver.md#death-fade-gain--2026-10-04).
The later autonomous death/restart acceptance above passes both selected CPUs.
Ten-minute first-floor coverage remains pending; FIGHT music acceptance is
recorded above.

## M3.4 reached MONSTER music — 2026-10-04

The follow-up owner session reaches the next unsupported music request: SONG
132 (`FIGHT`), selector 0 at Core+$138C, 6,850 ticks after in-game entry. Its
status-1 trace is preserved in `tmp/m3-toolbox/manual-owner-retry1-gdb.log`.
Its paired acceptance is recorded above; the session does not close first-floor acceptance.

The first owner-operated session stops at Core+$138C with `SOUND DRIVER /
SONG UNMEASURED`, 5,420 ticks (about 90 seconds) after automatic in-game entry.
The run exits with status 1; it is not manual acceptance. The trace is preserved
in `tmp/m3-toolbox/manual-owner-stop-gdb.log`. Gameplay music coverage from M4.2
is now a prerequisite. The original observer did not record the song argument;
subsequent loud-stop records include the driver selector and argument.
The idle-attic reproduction identifies SONG 136 / MIDI 906 (`MONSTER`). Its
original loading contract and all 602 preflight notes now match native decoding
and complete native interrupt playback, effect priority and cleanup. See the
[music prerequisite and reproduction](sound-driver.md#reached-monster-music-prerequisite--2026-10-04).
The final original captures are `mac-driver136-alias.log` and
`mac-song136-events-alias.log`; the first incomplete captures are rejected.
`native-song136-gdb.log` passes the full-song fixture, and
`native-song136-gameplay-gdb.log` passes the natural original-game transition,
with all 13 registers preserved and exact resource ownership. All four runners
exit zero. The host suite and both link audits pass. Captures are local-only in
`tmp/m3-toolbox`. M3.4 still requires a successful scripted first-floor route;
other unmeasured songs and effect variants remain loud stops.

## M3.4 launch delivery — 2026-10-04

The native no-document launch event now calls the original `oapp` handler in
user mode after the service bridge has consumed its frame. Paired Mac/native
observers verify event identity, Pascal arguments/result, ten preserved
registers, single delivery and descriptor cleanup. The integrated 68030 run,
with audio on and warp off, also exercises all five integer SANE operations
(30 calls) and passes the existing keyboard Save/Load/Quit checks. See
[the contract and reproduction](apple-events.md#launch-delivery-m).
M3.4 remains open for the ten-minute scripted first-floor route and any new
services it reaches; external Apple Events and document descriptors are not
implemented.
The full host suite and all six maintained regression cases pass on
`a4000-030-reference` (`tmp/m3-toolbox/host-tests.log` and `regression.log`),
including resource-exit fault/cleanup phases, file writes, window-core and
production boot. Existing preferences and saves are isolated and restored by
the regression runner. Both link audits pass.
The manual observer's preflight also passes launch delivery, integrated SANE
and shutdown checks using the guest menu fixture (`manual-preflight-gdb.log`,
runner exit zero). Its 3,759 elapsed ticks are not ten-minute first-floor acceptance.
The prepared live-play build uses `INGAME=1 PROBES=1` without menu/gameplay
fixtures, so only boot navigation is automatic.

## M3.3 reached game interfaces — 2026-10-04

The normal Mac route from new game through typed save, overwrite, cancellation
and reload invokes only the startup size dialog. Native new-game and character
story match all 64,000 viewport pixels; Save/Load retain engine artwork and
input, with no Mac dialog presentation. The 68030 observer keeps audio on and
warp off and requires complete OS restoration. Resource-only new-game and
save-warning templates are not reached interfaces. [Contracts, reproduction
and coverage limits](game-interfaces.md) distinguish this from M3.6 reload and
durability acceptance. M3.4 is next.
The full maintained regression suite passes on `a4000-030-reference` in
`tmp/m3-dialog/regression-final.log`, including file-write, window-core and
production boot. Five save/preference isolation checks and both link audits
pass. The paired checker also rejects missing positive controls, nonzero runner
status, an added alert and altered viewport pixels.

## M3.2 keyboard menus — 2026-10-04

Right-Amiga+S/O/Q returns the original game's Save/Load/Quit menu items. S/M
reaches both sound/music choices; four published feedback messages match Mac
glyphs, display colours and centring. The native 68030 run keeps audio on and
warp off, saves `m3test`, opens/cancels Load and returns through Quit with files,
interrupts, DMA, View and the Line-A hook restored. All captured states preserve
pixels outside the viewport. The menu bar remains undrawn.

Accepted paired logs are `tmp/m3-menu/mac-keyboard.log` and
`native-final-gdb.log`, both with normal runner exit status zero;
`checked-final.log` contains the maintained checker result. The [menu contract
and reproduction](menu-manager.md#gameplay-keyboard-route-m32) describes the
fixture, including its save slot and queued feedback snapshots. Gameplay
restoration and reset durability remain M3.6.
The full host suite, no-float/probe link audits and clean production `boot`
also pass; the boot log is `tmp/m3-menu/production-boot.log`.

## M3.1 completion — 2026-10-04

Carnby's first-room walk, Shift-run, Fight selection, kick and release pass
paired Mac IIx/Amiga 68030 checks. A gameplay bug clearing held keys on disk
access is fixed; the keyboard handler now remains live through DOS windows.
The native run uses audio and no warp. `window-core` verifies 27 keyboard
checks plus the existing file/clock/Paula/display checks, and production `boot`
passes after a clean build. Details and service-coverage boundaries are in
[events.md](events.md).

For the maintained gameplay fixture, create `tmp/m3-input`, clean-build with
`GAMEINPUT=1`, and run `GDBSCRIPT=gameplay.gdb amiga/diag_run.sh 180`.
The Mac counterpart is `tools/mac_gameplay.lua`, using the documented headless
Mac IIx setup with the debugger enabled. Check the paired captures with
`tools/check_gameplay.py`, passing both logs and their actual exit statuses.
Accepted logs are `tmp/m3-input/mac-controls-traps.log` and
`tmp/m3-input/gameplay5-gdb.log` (both exit zero); the OS-window and production
checks are `window-controls-run.log` and `boot-controls-run.log` in that folder.

## M2 completion — 2026-10-02

M2 startup-to-intro acceptance is complete on the baseline `a1200-020`.
The final PAL/NTSC visual fixture passes exact five-frame pixels, 256 colours,
pointer inversion/clipping/hiding, register geometry, publication and cleanup:
`tmp/m2-visual-pal-native-full.log` and `tmp/m2-visual-ntsc-native-full.log`,
both exit 0 and both accepted by `check_cursor_capture.py --inversion --visual`.
Their captures are archived under `tmp/m2-visual-{pal,ntsc}-native/`.

Owner F12+S screenshots provide the separate rendered evidence:
`tmp/m2-owner-ramp-pal/` (23:10–23:11) and `tmp/m2-owner-ramp-ntsc/`
(23:15:22 and 23:15:28). The full ramp and pattern are intact in both standards;
the patterned pointer is visible, moves and clips at the edge without leaving
a visible old-position trail. The differing vertical placement matches the
PAL/NTSC register captures. Six PAL game screenshots under
`tmp/m2-owner-pointer-pal/` additionally show the actual arrow on black, white
and coloured artwork, plus the wait cursor.

Completion audit retains the prior independently scoped evidence:

| Requirement | Accepted evidence |
| --- | --- |
| Full uninterrupted intro and partial conversion | `m2-sync-intro-native-full.log`: 956 frames, 944 partial, 840 book batches, zero failures |
| State-matched Mac rendering | Four paired intro captures and `m2-line-tie-demo-native-full.log`; exact car/frog pixels and palettes, documented owned-font differences only for text |
| Menu/new game/story | `m2-story-pages-final-native-full.log`: normal Enter and all eight letter pages |
| Original demo and data reads | `m2-song-reuse-full-route-native-full.log`: all nine transitions, natural exit, exact PAK payloads and palette reactivation |
| Visible loading and demo reliability | Owner video detailed below: 7.95-second blank interval and visible completion through final room to logo |
| Music and sample ownership | `m2-song-reuse-native-full.log`: all 3,736 events, byte-exact PCM variants, effect priority and cleanup |
| PAL/NTSC sound timing | `m2-video-effect-{pal,ntsc}-native-full.log`: correct periods, duration and natural completion |
| Host/native regressions after loading fix | `m2-movehigh-gap-host-suite.log`, `m2-movehigh-native-regression.log`, `m2-movehigh-heap-native-full.log`: all pass |

The final normal build is recorded in `tmp/m2-complete-production-build.log`.
No fixture flag is part of the production build. M3 gameplay work and the
owner-deferred M1.7b2 system-window rendered fixture remain separate open work.

The service-by-service checkpoint records below retain historical stops and
acceptance boundaries. Their then-pending M2 gates are superseded by the
completion audit above. They do not reopen M2 or close unimplemented gameplay
contracts. The current remaining scope is in [open-work.md](open-work.md).

## Build dependencies

The production game is the Amiga executable; there is no host game renderer.

- GNU make, a shell and Python 3 (plus `capstone` for the 68k sweeps).
- `m68k-amiga-elf-gcc/g++`, `elf2hunk`, vasm and Amiga NDK headers.
- `unar` and `hfsutils` to extract the original release.

`amiga/env.sh` adds the development toolchain under `~/.local` to PATH.
FS-UAE launchers source `amiga/fsuae.sh`, which uses
`${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}` for shared,
PID-scoped process management. The default debugger port is **24377**, outside
the shared helper's 40-port hash range; `DEBUG_PORT` can override it. Only this
project's recorded emulator may be stopped. Any remaining listener causes a
named busy-port failure; it is never killed merely for owning the port.

Keep FS-UAE observers below the installed core's breakpoint capacity. A
corridor observer filled the 20-entry table (including four internal
breakpoints); resuming needed to reinsert the current loop breakpoint and
received an empty `Z0` response. GDB reported conflicting enabled responses.
Use at most 15 simultaneous observer breakpoints to retain a spare slot;
count internal entries from the core log rather than only GDB's visible list.
Also dispatch stopped PCs explicitly inside a GDB `while`/`continue` loop:
breakpoint command lists can run later than that loop expects. Preserve failed
observer logs and require the positive completion marker and normal detach.

This completes M2.3g34a: the shared default collided with Pokeri at 2377.
Default/override/busy-port fixtures pass; a real occupied TCP listener survives
a refused launch, and native startup connects on 24377. The helper remains an
external dependency. `KICKSTART`
selects your local boot ROM. `tools/ghidra` links to the shared Ghidra install.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4
```

The output is `amiga/out/Alone.exe`. The build needs no copyrighted input.
For quick gameplay testing, clean-build with `make -C amiga -j4 INGAME=1`.
This automatically selects Carnby and skips the publisher screens, book, menu,
letter and narrative intro through normal game input. Boot drawing remains
internal; only gameplay is displayed. Required resource loading still runs,
with music enabled and no change to the game clock or emulator speed.
Run it with `amiga/run.sh`. Clean-build without `INGAME=1` to restore full startup.
`GDBSCRIPT=ingame.gdb amiga/diag_run.sh 180` verifies the initial world and key
release; the diagnostic runner's default audio is muted, so use the normal
runner for listening.

Each `amiga/regression.sh` case uses temporary preferences and saves through
`tools/regression_preferences.py`. Existing preferences are moved outside the
emulated drive and restored when the case ends, including failure. Existing
save data, resource forks and directory metadata are preserved too. Probe-created
directories are retained under `.run/regression-{prefs,saves}-*/fixture` for diagnosis.
This prevents an early boot checkpoint's incomplete resource fork from poisoning
the next case, and lets the file-write fixture start with its required absent
preferences directory without deleting existing files. Save isolation also
keeps gameplay saves from changing the file-index fixture's expected catalog.
Always clean when changing build flags or shared headers. Every link runs two audits:
`no-float-audit` (no libgcc floating-point helpers) and `probe-audit` (every
debugger-read global survives `--gc-sections`). C/C++ uses
`-m68020 -mtune=68020 -msoft-float`; GNU as uses `-mcpu=68020 -mno-float`
(it has no `-mtune` option). Integer multiplication/division uses native C/C++;
the 68000 helper header is retired.

## Rendered display fixture (M2.5)

Clean-build with `AGAPROBE=1 CURSORPROBE=1 C2PVERIFY=1 AGAVISUAL=1` for
owner screenshots. The visual variant adds a ramp containing all 256 colour
indices above the bitplane test pattern. Each of the five pointer stages stays
visible for 30 game-clock seconds with the display and interrupts running.
Use the normal launcher and F12+S in both PAL and NTSC. This diagnostic does
not affect production builds.

Automated validation uses `GDB_ENTRY=aitdRunAgaProbe`,
`GDBSCRIPT=cursor_probe.gdb` and a 400-second deadline. Verify the captures with
`tools/check_cursor_capture.py LOG --status 0 --video PAL --inversion --visual`
(select NTSC for the NTSC run). The checker independently reconstructs the
ramp and checks all pixels, colours, sprite data and publication registers.

## Full-intro C2P acceptance (M2.6)

`AMIGA_CONFIG=a1200-020 amiga/regression.sh intro` clean-builds with
`C2PVERIFY=1 FIXEDRNG=1` and no input injection. The diagnostic independently
decodes the complete 320×200 planar frame before each publication and compares
it with the logical viewport, including pixels outside the current dirty
rectangles. It does not replace the production Kalms converter or add a shadow
framebuffer. Host tests inject errors into every plane and check correct and
stale partial updates, clipping and shifted viewports.

The baseline run `tmp/m2-intro-native-full.log` exits 0: 956 frames verified,
944 partial-update frames, zero mismatches, 956 queued/presented frames, and
all 840 original book batches complete. The original Dark+$5220 return has
D0=0, no pending pixels or publication, and no injected intro skip. The run
uses the existing sequencer catch-up loop without its arbitrary 600-tick stop;
original computation and diagnostic overhead can legitimately delay a safe
point. No game instruction is changed. This instrumented run is not a speed
measurement.

`tools/check_intro.py LOG --status 0` checks the full completion record.
Four matching instruction checkpoints are captured for `compare_frames.py`.
The archived source,
palette and display captures are in `tmp/m2-intro-baseline/`.

The paired original run `tmp/m2-intro-text-reference.log` also exits 0.
Dark2+$1C94 and +$1F46 match all 64,000 pixels exactly. Dan2+$2ED4 (title) has
1,015 D6 glyph differences; Dark+$5220 (final credits) has 1,722. All four
palettes and native AGA publications match. The comparator requires every
authored glyph pixel and rejects changed background pixels or ink outside the
measured captions. `AITD_INTRO_TEXT=1` records original DrawText calls, including
each credit word's separately reset fractional pen. The initial comparison's
joined-word assumption was rejected and replaced with those measured calls;
no game text or layout was changed. Reproduce the accepted comparison with:

```sh
python3 tools/compare_frames.py tmp/m2-intro-text-reference.log tmp/m2-intro-native-full.log --reference-status 0 --native-status 0 --allow-placeholder-text
```

The enabled-pointer baseline repeat also passes (`tmp/m2-intro-pointer-native-full.log`,
exit 0): 956 verified/presented frames, 944 partial updates, zero failures,
840/840 book batches and 128,210 ticks. All four checkpoints use BPLCON4 $010F;
the cursor inversion overlay is inactive at those states. The observer records
its mask and position, and the comparator accounts for an active overlay while
still requiring the underlying game pixels to match. Both logos remain exact;
title/credits retain only the same 1,015/1,722 verified owned-glyph differences.
The complete capture set is archived in `tmp/m2-intro-pointer-accepted/`.

```sh
python3 tools/check_intro.py tmp/m2-intro-pointer-native-full.log --status 0
python3 tools/compare_frames.py tmp/m2-intro-text-reference.log tmp/m2-intro-pointer-native-full.log --reference-status 0 --native-status 0 --allow-placeholder-text
```

The four intro states precede the first Engine random call (the existing
64-call entropy fixture covers subsequent menu/demo selection). Car/frog
state-pair acceptance remains open under M2.10; rendered-window acceptance
remains owner-deferred.

## Native car and pond captures (M2.10)

M2.10 passes on the baseline `a1200-020` with `INTROSKIP=1 FIXEDRNG=1` and
the original-game pointer enabled. `m2-line-tie-demo-native-full.log`,
`m2-line-tie-car-reference.log` and `m2-line-tie-frog-reference.log` all exit 0.
Both complete 64,000-pixel frames match the original Mac renderer with matched
model/transform inputs; all 256 palette colours and AGA publications also pass.
Together with the full intro and its four paired states above, this completes
the frame-fidelity gate. Natural sequence and rendered-window acceptance remain
separate requirements.

`amiga/demo_frames.gdb` records the actual model, actor, A5 world and six
transform arguments at original Dark+$3ED4 and the alternate redraw call
Dark+$37AA. The selected draw must immediately precede the captured frame.
The pond capture requires an actual frog draw in camera 3: the original first
camera-3 checkpoint precedes that draw, so its saved actor state alone cannot
pair the visible frog. `tools/mac_demo_frames.lua` uses the same observation.
Dark+$3E6C/+3E88 identify animation resource/frame at actor offsets $3E/$4A;
$54/$58 instead select the movement track resource and word offset, as read
by Dark2+$49F0/+4A08.

Natural native and Mac poses differ with execution timing. The controlled
`tools/mac_demo_model_replay.lua` fixture runs with `AITD_REPLAY_KIND=car` and
then `AITD_REPLAY_KIND=frog`. It copies measured native model/transform inputs
into the original Mac allocation, preserving the dynamic header skipped by
the renderer, and executes unchanged game instructions. No actor pixels are
masked and no comparison tolerance is used. `check_demo_model_replay.py`
checks the actual draw/scene identity, transform equality, complete pixels,
colours and AGA publication. It rejects the pre-fix native car's nine differing
pixels as a negative control.

That car discrepancy exposed descending shallow LineTo boundary rounding.
An original-Mac trace recorded 47 visible calls; three disagreed with `Line8`:
(46,170)–(64,168), (68,221)–(61,222), and (47,189)–(68,186). The second lies
outside the presented viewport. QuickDraw assigns exact descending boundaries
to the following row. Biasing the mirrored half-open span by one 16.16 fraction
unit matches every captured call and all 80 original slope/reversal fixtures,
including 32 added boundary cases. Seven host raster cases and three
window/dirty fixtures also pass, followed by exact native frame verification.

The accepted capture set is archived in `tmp/m2-line-tie-demo-native/`.
Reproduce with a clean `INTROSKIP=1 FIXEDRNG=1` build and
`AMIGA_CONFIG=a1200-020 GDBSCRIPT=demo_frames.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 1800`,
then the two model replays using the documented headless MAME command.

```sh
python3 tools/check_demo_model_replay.py tmp/m2-line-tie-demo-native-full.log tmp/m2-line-tie-car-reference.log tmp/m2-line-tie-frog-reference.log --native-status 0 --car-status 0 --frog-status 0 --folder tmp/m2-line-tie-demo-native
```

## Original data

Put your original archive in ignored `tmp/`, then:

```sh
make extract-original-data ARCHIVE=tmp/AloneInTheDark.img_.sit
make segments
```

The first writes `tmp/runtime-data/Alone In The Dark` (the raw resource fork)
and `tmp/runtime-data/Alone Data/`; see [install-original-data.md](install-original-data.md).
The second dumps the CODE resources to `tmp/segments/` for the 68k sweeps and
Ghidra.

## Running

```sh
cd amiga
. ./env.sh
./run.sh
```

The default is `a4000-030-reference` (`AMIGA_MODEL=A4000`), following the
owner's 2026-10-02 request to use a 68030 for intro performance work. It uses
15.6672 MHz to match MAME's Mac IIx CPU, AGA, 2 MB chip / 8 MB fast, and no
FPU/MMU/JIT. FS-UAE reports `~cycle-exact`; matching clocks does not establish
identical memory-system timing. `AMIGA_CONFIG=a1200-020` (or
`AMIGA_MODEL=A1200`) retains the 14 MHz cycle-exact baseline. Explicit
`AMIGA_CONFIG` takes precedence over the model selector. Unlimited-speed
`a4000-030` and `a4000-020` remain available for diagnostics, not timing claims.
Full 68040/68060 acceptance remains deferred to M5.0; the optional
`a4000-060` speed pilot is available for development. The port still compiles
for 68020 without an FPU. The fixed-clock default passes the original-code boot
observer (`tmp/intro-030-clock-boot.log`, exit 0), and the effective core log
reports 68030 with FPU/MMU/JIT disabled. This is boot evidence, not complete
68030 gameplay acceptance. PAL/NTSC configuration and rejection checks pass.
All three launchers share these settings and write the emulator core log to
`amiga/.run/logs/fs-uae.log.txt`.

`AMIGA_VIDEO=PAL` (default) or `AMIGA_VIDEO=NTSC` selects the video standard
in all three launchers. The installed FS-UAE requires the explicit core
`uae_ntsc` option as well as `ntsc_mode`; the frontend option alone booted PAL
and was rejected by the native mode verifier. On real hardware the runtime
reads `graphics.library`'s PAL flag before taking over the display. It centres
the 200-line viewport at line 72 in PAL and line 44 in NTSC, advances Mac ticks
at 6/5 per PAL field or one per NTSC field, and uses the corresponding Paula
clock (3,546,895 or 3,579,545 Hz) for effects and songs. These clocks follow the
[Commodore Hardware Reference Manual](https://oldcrap.org/wp-content/uploads/2023/04/amiga-all-hw-ref-manual.pdf)
(audio chapter, printed page 138).

M2.5 automated display evidence: `AGAPROBE=1`, `GDB_ENTRY=aitdRunAgaProbe`,
`GDBSCRIPT=aga_probe.gdb` on `a1200-020` passes in both standards. The captures
`tmp/m2-video-pal-native-full.log` and `tmp/m2-video-ntsc-native-full.log`
both exit 0. `check_aga_capture.py fixture` verifies every pixel, plane pointer,
all 256 colours and partial updates across five frames; `check_video_mode.py`
also verifies geometry, field-to-tick conversion and restoration. Archived
buffers are in `tmp/m2-video-pal/` and `tmp/m2-video-ntsc/`. These checks do not
replace the pending rendered-picture and visible-pointer acceptance.

With a normal build (no `INTROSKIP`), `GDBSCRIPT=video_effect.gdb` captures the
first original effect and its natural completion. Both baseline runs pass:
`tmp/m2-video-effect-pal-native-full.log` and
`tmp/m2-video-effect-ntsc-native-full.log` (exit 0). The paired 30,783-byte
sample uses period 443 in PAL and 447 in NTSC, with a 231-tick DMA duration.
The observer verifies the period passed to Paula programming, original driver
ABI, sample conversion, completion at the scheduled tick, DMA shutdown and
sample disposal. AUD0PER is write-only: this debugger returns zero for it, so
reading that address is not valid pitch evidence. Run `check_video_mode.py`
with `--case effect --video PAL|NTSC --status 0`; the paired sample captures
are archived under `tmp/m2-video-effect-pal/` and `tmp/m2-video-effect-ntsc/`.

The M2.5 pointer helper uses BPLCON4's independent playfield XOR and even/odd
sprite banks, as described in the
[AGA register specification transcription](https://www.ikod.se/references/amiga-aga-guide/registers-by-name/#BPLCON4).
XOR 1 paired with `physicalPalette[i ^ 1] = logicalPalette[i]` preserves every
game colour without changing pixel indices. Sprite 0/value 1 uses physical
white slot 1; sprite 7/value 2 uses physical black slot 254 (odd bank 15 plus
pair offset 12). The two masks are disjoint. `check_aga_cursor.py` reconstructs
every copper colour and checks all pointer bits under sanitizers; the existing
palette tests still pass with the default mapping. Native display integration
passes `AGAPROBE=1 CURSORPROBE=1`, `GDB_ENTRY=aitdRunAgaProbe`,
`GDBSCRIPT=cursor_probe.gdb` on baseline `a1200-020` in PAL and NTSC.
Both `tmp/m2-cursor-pal-native-full.log` and
`tmp/m2-cursor-ntsc-native-full.log` exit 0. `check_cursor_capture.py` with
`--status 0 --video PAL|NTSC` verifies five complete frames, all 256 colours,
sprite pointer ownership and DMA rows, upper-left/bottom clipping, hiding,
disabling and released allocations. Captures are archived under
`tmp/m2-cursor-pal/` and `tmp/m2-cursor-ntsc/`; use `--folder` to select them.
Palette-mode publication is gated by game display ownership, so VBI work during
OS handbacks does not change OS registers. Original-game pointer enablement now
passes its first nine publications (`tmp/m2-pointer-game-startup-full.log`,
exit 0), checked by `check_aga_capture.py startup --pointer` with exact client
pixels, all colours and actual BPLCON4=$010F.

Original CURS 132 is reached during startup and has two inversion pixels.
The original 256-index fixture proves XOR 255 with exact restoration and no
palette change. `CursorInvert` applies that operation in the VBI and removes
it from synchronized spans; no saved background or shadow framebuffer is used.
The final baseline fixtures add `C2PVERIFY=1` and verify movement without a new
frame, inverted pixels and clean queued frames. Both
`tmp/m2-cursor-motion-pal-full.log` and `tmp/m2-cursor-motion-ntsc-full.log`
exit 0 and pass `check_cursor_capture.py --inversion --status 0 --video PAL|NTSC`.
Corresponding captures are archived under `tmp/m2-cursor-motion-pal/` and
`tmp/m2-cursor-motion-ntsc/`. Publication reaches at most line 3 and cursor work
finishes by line 17, before the PAL/NTSC picture. See [cursor.md](cursor.md) for
the original measurement and host checks. Rendered verification remains pending.

`stage_original_data.sh` copies the original application folder into `data/`
beneath the executable directory on the emulated hard drive. The port executable
and diagnostic files remain outside this Mac-visible namespace. Override
`AITD_APP_RSRC` and `AITD_DATA_DIR` for extraction locations; the two original
root extras and companions must be beside `AITD_APP_RSRC`. Saves and preferences
retain their separate `Saved Games/` and `prefs/` native mappings. The launcher
also stages the port-owned `resources/overlay.rsrc` beside the executable. A
manual installation must copy that file to `PROGDIR:overlay.rsrc`; a missing or
invalid overlay fails explicitly.

## Debugging

```sh
cd amiga
. ./env.sh
make clean && make -j4 PROBES=1
EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=runtime_status.gdb ./diag_run.sh 60
```

The runner stops early when an event-driven observer finishes; otherwise its
seconds argument is a safety ceiling, not proof of success. Debugger command
files run in batch mode so command errors return a failing process status. It stops only the
emulator it owns and keeps the output in `amiga/.run/gdb-out.log`.
`runtime_status.gdb` reports the stage, tick counters and the loud stop: the
loader's reason and segment, or the trap word, manager, routine and caller
(segment, offset). `wbstartup.gdb` checks the Shell startup branch.
`./debug.sh` gives an interactive source-level session. Both debug launchers (`debug.sh` and
`diag_run.sh`) use FS-UAE’s dummy audio driver, silencing host playback while
keeping emulated Paula/DMA active. Normal `run.sh` audio is unchanged.

The current display owner is `AitdScreen`; the interpreter boundary is
`MacLoader`. Keep changes at the documented interface and verify original
opcodes/operands before changing binary behavior.

## Static analysis

```sh
make host-tests         # host analysis fixtures
make trap-census        # tmp/trap-census.md, live sites and selectors
make m68k-sweep         # 68020-only instructions on reachable paths
make lowmem-scan        # reachable absolute Page-0 references
make entrypoints-check  # ghidra_scripts/entrypoints.csv matches CODE 0
```

The census and low-memory scan read the original resource fork directly, including
CREL, DATA, ZERO and DREL; no scratch scripts or Vette checkout are needed.
The census checks the 1.0 baseline of 1,129 sites / 244 distinct trap words.
Its 115 unresolved static transfers/decode stops remain listed for runtime
verification. D0 selectors are local static evidence, not a data-flow proof.

`lowmem-scan` reports 58 live Page-0 operands at 29 addresses, with original
encodings. CREL address fields and PEA address constants are excluded; genuine
memory operands in the same instruction remain visible. This conservative set
includes fallback paths (such as SysEnvirons glue); M1.4 must reconcile those
with the implemented system services before producing its patch table.

Trap names come from cxmon through `tools/gen_trap_names.py`, reused from Vette.
The generated `tmp/trap_names.lua` remains local-only. The generator accepts a
local cxmon `mon_atraps.h` path for offline use; otherwise it downloads the table.

`ghidra_scripts/` holds the headless Ghidra scripts used by Vette!
(entry marking, names, trap and call-graph dumps, listing export). Their
output belongs under ignored `tmp/` or `disasm/`.

The MAME runtime logger and its bounded session are documented in
[mac-reference-loop.md](mac-reference-loop.md#runtime-trap-evidence).
`make mac-trap-map` generates local original-byte metadata; the report attributes
calls using per-record live jump-table targets and rejects missing state proofs.
M0.2 added the runtime-confirmed CODE 1 cache helper at `$021E`/`$026E` to the
census: `$A0BD` was the new distinct trap; `$A346`/`$A746` were new sites for
already-known words. The original bytes are checked before these extra roots
are walked. The additional low-memory operands both access `CPUFlag` (`$012F`).

M0.3 verification: clean 68020 build linked with `no-float-audit: clean` and
`probe-audit: clean (33 symbols)`. A real soft-float compilation fixture was
rejected for `__addsf3` and `__floatsidf`. A bounded A1200/68020 diagnostic run
reached the unchanged `SEGMENT LOADER / CREL RELOCATION`, CODE 3, state 2,
10 jump entries. This is the expected current stop, not a gameplay/boot pass.

M0.4 verification: clean build and both link audits pass (30 retained probes);
the `PROBES=1 FILLWATCH=1` clean build also passes (78 probes).
The bounded 68020 run still reaches the CODE 3 CREL relocation stop. Captures
made immediately after drawing that same stop compare byte-for-byte equal:
98,304 planar bytes. The launcher now matches its documented A1200, 2 MB chip /
8 MB fast configuration. The eight-plane game display remains M2.4 work.

The Shell message `cannot read Alone In The Dark` / returncode 20 is a startup
failure, not the expected CREL stop. It covers file open, size, allocation and
read failures. Check the staged file and OS-visible memory; the exploratory
68040 configuration produced this failure with its fast RAM unconfigured.

M0.6 verification (68020-only scope per owner): clean build and both audits
pass (30 probes). The bounded default run reports emulator CPU=68020,
FPU/MMU/JIT=0, 24-bit addressing, Exec.AttnFlags=$0003, and 8 MB Z2 fast RAM
at $00200000. It reaches `SEGMENT LOADER / CREL RELOCATION`, CODE 3, state 2,
10 jump entries, before the 45-second ceiling. Shell syntax checks pass;
deferred CPU selections and conflicting CPU overrides are rejected. This is
configuration acceptance only, not the still-unimplemented boot regression.

## Regression

`make regression` (or `amiga/regression.sh boot`) clean-builds, runs a bounded
68020 observer and requires exactly one `boot PASS: reached CODE 3+$03e4`
record. Any loud stop, debugger error, nonzero observer exit or deadline expiry
fails. The observer checks the original main-entry bytes before placing its
breakpoint. The boot test ends at main entry; it does not claim startup or play.

The runner clears stale logs/state, propagates debugger failures, returns 124
on timeout and cleans up its owned processes on exit. Build evidence is in
`amiga/.run/regression-build.log`; the observer log is `amiga/.run/gdb-out.log`.

Harness verification includes ten host acceptance/rejection fixtures and an
intentionally nonterminating observer that returns 124. M1.3a updates the boot
observer to wait for CODE 1+$AA, after the original Core relocation, then checks
the unchanged main bytes before placing its breakpoint. `make regression`
passes on `a1200-020`: exactly one `boot PASS: reached CODE 3+$03e4`, no loud
stop before that endpoint, normal observer exit and both clean-build audits.
Initialization beyond that point still has the named NewHandleClear stop.

## Line-A and stack probe

Clean-build with `make -C amiga LINEAPROBE=1`, then run from `amiga/`:
`EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=line_a.gdb ./diag_run.sh 30`.
The probe uses real native Line-A instructions on the dedicated 64 KB stack;
it does not replace original game instructions.

M1.1 evidence: vector at VBR+$28 ($00000028 on the tested A1200) changes from
$00F80ADE to the port handler and is restored after both RTS and ExitToShell.
D0.W zero/positive/negative returns produce CCR $14/$10/$18 from input $1F;
Toolbox retains $1F. A callback deliberately overwrites CCR and A5, and the
caller still receives CCR $14 and A5 $12345678. QDExtensions selector
$56780001 dispatches as selector 1. The entry SP is exactly stack base+65532.
CurrentA5 $004905F8 minus CurStackBase $0047DE98 is 75,616, matching the original
CODE 0 header. Probe and production link audits pass (36/35 retained symbols).
Low-memory instruction redirection remains M1.4; these values currently live
in the private shadows. Production startup now reaches main (see below).

## A5 initializer model

`make a5world-check` validates the original CODE 0 header and hashes the original
CODE 1+$0118–$0193 initializer before modeling DATA/ZERO and DREL. It checks
exact input consumption and the planning model's golden digests. `make
host-tests` includes malformed/truncated streams, zero-length zero runs,
short/long and STRS-tagged relocations, 32-bit addition wrap and dump mismatch
checks. This is a host model, never a substitute for running CODE 1.

At the first instruction of Core+$03E4, dump exactly `[A5-75616,A5)` and obtain
the actual STRS data pointer (CODE 1+$08 after startup). Then compare with:

```sh
python3 tools/a5world_check.py 'tmp/runtime-data/Alone In The Dark' \
  --a5 <actual-address> --strs <actual-address> --dump tmp/amiga-a5-globals.bin
```

The initializer owns the below-A5 globals. Loaded jump entries above A5, the
CODE 1 trap-patch storage, and the port's shadows are separate M1.3/M1.4 checks.
No mismatching bytes are ignored. The tool reports each of the first twenty
mismatching A5 offsets and fails on a wrong dump length or any mismatch.

M1.2 verification: all host checks pass. The original has 11,418 DATA bytes,
560 ZERO bytes, 280 zero runs, 276 DREL entries (255 A5 / 21 STRS), including
63 long-form offsets. Both streams consume exactly into 75,616 bytes. A local
comparison fixture passes at zero mismatches; corrupting one byte reports
A5−75,516 and exits 1. This fixture is not a live Amiga dump; that evidence is
still required by M1.3.

M1.2a startup-census correction, found while preparing M1.3: explicitly include
CODE 1+$0060 (LoadSeg) and +$00CC (UnLoadSeg). Their original prologues drop a
return address, so the ordinary function-prologue heuristic missed them.
Byte-checked roots add 11 trap sites and the conditional $A9FF Debugger word:
1,129 sites / 244 words, with 115 unresolved transfers still listed. The
low-memory scan adds ResLoad at +$006A and LoadTrap at +$00BE, giving 58
references at 29 addresses. The runtime report now requires every observed
(segment, offset, trap) site to exist in the static census, not merely its
trap word. Acceptance: all 632 sites in the M0.2 reference log are covered;
host fixtures reject an unseen site even when its trap word is known.

M1.2b startup low memory: `LowMemory.h` includes ten original-byte-checked
CODE 1 sites. Patching is atomic and happens before takeover. The A5 allocation
now includes 80 shadow bytes at A5+$0EC0; CurrentA5 and CurStackBase are real
allocation addresses, CPUFlag=3 matches the Mac IIx reference, LoadTrap=0, and
the fallback address mask is $FFFFFFFF (the port's StripAddress identity).
M1.4 extends this to the complete live table, described below.

`make startup-lowmem-check` compiles the actual C++ patcher on the host and
compares its table to the original-resource census. All ten instruction lengths
and operations are preserved; all 44 original-byte mutations are rejected with
no partial patch. `make host-tests` includes the input-free patcher fixtures.

Bounded native check: `GDBSCRIPT=startup_lowmem.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30` from `amiga/` passes for all ten operands (A5 $00490610,
shadows $004914D0, CurStackBase $0047DEB0). A deliberately corrupted local
resource copy returns false before screen initialization, verified with
`GDB_ENTRY=MacLoader::prepareResourceForks GDBSCRIPT=startup_reject.gdb`.
The original file and restored staging copy retain the same SHA-256. Host
checks, the original A5-model check and both link audits pass (38 probes).
The current game reaches the initialization stop described below.


## Original startup and trap patches

M1.3 replaces resident pre-resolution with CODE 1+$14. Only CODE 0 metadata and
CODE 1 are copied at launch; JT entries 0–9 are loaded and the other 458 retain
the original unloaded form. `GetResource(CODE)` creates aligned private copies.
CODE 1 expands DATA/ZERO, applies DREL, patches LoadSeg/UnloadSeg/ExitToShell,
and performs every CREL relocation. Resource handle lock state comes from the
resource attributes. Full zone/purge ownership remains M1.5; disk reads M2.2.

The per-trap callable original is `AFFE, trap-word, RTS`, accepted only within
the port's stub array. OS patches use the register/return conventions measured
from the System 7.5.5 dispatcher at $DD60–$DDE2; the local reference capture is
`tmp/m1.3-dispatch.log` (explicit PASS), with RAM/ROM bytes retained in `tmp/`.
The M0.2 trap log confirms zero D0 from Get/SetTrapAddress, the locked resource
state $A0, and cache-flush success. StripAddress intentionally retains native
32-bit addresses. Unsupported HWPriv selectors and SysError remain named stops.

The expanded `LINEAPROBE=1` / `line_a.gdb` probe verifies callable originals,
OS patch input registers, preservation of D1/D2/A1/A2, both A0-result variants,
D0.W-derived CCR, Toolbox Pascal argument/result cleanup and balanced stacks.
It also exercises vCacheFlush and HWPriv 1/3. All pass, alongside the earlier
Line-A vector, 64 KB stack, callback CCR and QDExtensions selector checks.

For production startup evidence, run from `amiga/`:

```sh
GDBSCRIPT=original_startup.gdb EXTRA_ARGS=--warp_mode=1 ./diag_run.sh 30
```

The observer checks original loader/main bytes, CODE residency and the first
Core CREL long. It dumps `tmp/amiga-a5-globals.bin` at main and prints the actual
A5/STRS bases for `a5world_check.py`. It succeeds only at the expected subsequent
`MEMORY MANAGER / NEWHANDLECLEAR`, Engine+$004A, trap $A322. This stop belongs to
M1.5, and is not a gameplay pass. `runtime_status.gdb` independently reports it.
The boot observer independently reaches main and passes (M1.3a).

Production evidence: A5 $004680D8, STRS $002E88C4, zero mismatches across all
75,616 bytes. Core header becomes $000A; Core+$000E is $0045BE8E, exactly
$FFFF3DB6 + A5 modulo 32 bits. Initial CODE mask $3 becomes $B at main.
The independent status observer reports 68020, FPU/MMU/JIT=0, trap $A322 at
Engine+$004A. Host checks and production link audits pass (40 probe symbols).


## Complete low-memory redirection

`LowMemory.h` extends the Vette same-length A5 redirection to all 58 live
operands at 29 addresses. The shadow area is 160 bytes at A5+$0EC0. The $016C
word shares the low half of $016A Ticks. MOVE destination fields and source
instructions with a trailing destination extension have distinct encodings;
the patcher preserves every other operand and all CREL fields.

`make lowmem-check` compiles the actual C++ patcher, compares its complete
table with `make lowmem-scan`, checks all 13 original CODE fingerprints and
lengths, and verifies no absolute Page-0 operand remains in the census live set.
The static census still reports its 115 unresolved indirect transfers; this
is not a claim that arbitrary unseen code has been proven safe. Modified
original CODE is rejected, including modifications outside the listed sites.
Host fixtures reject all 264 single-byte site corruptions without a partial
patch, wrong lengths, repeat patching and invalid segment IDs. They verify
shadow bounds and permit only the intentional Ticks overlap.

Native acceptance (`GDBSCRIPT=lowmem.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30`) passes: 58 sites validated before takeover, 50 applied to
CODE 1/Core/Engine at the current stop, ten fields advance Ticks by twelve,
and the published shadow equals `g_macTicks`. A changed final byte in CODE 3,
outside every patch site, is rejected before screen takeover using
`startup_reject.gdb`. Restored original staging passes boot regression.

The original-startup dump remains exact (A5 $00468AF0, STRS $002E92DC, zero
mismatches in 75,616 bytes). Both production audits pass (42 probe symbols).
Address redirection does not supply missing subsystem values: zone/error
shadows belong to M1.5, system identity to M1.6, and scrap/sound state to their
services. That low-memory checkpoint reached Engine+$004A; the current stop is listed below.


## Zone allocator core

M1.5 is split into independent core (M1.5a) and runtime integration/reference
acceptance (M1.5b). `MacHeap` owns no host allocations: the caller supplies an
aligned arena, and data blocks plus non-moving master-pointer blocks live
inside it. Pointer and locked-handle barriers bound compaction. Handle flags
live beside master-pointer arrays, never in address bits. Free/largest-space
queries account for actual blocks. Resizing preserves payloads; failed
reallocation preserves the old pointer. Emptying preserves handle identity,
while disposal makes the master slot reusable.

`make host-tests` includes allocation, zeroing, lock/purge interactions, in-place
pointer growth, handle growth/shrink, MoveHHi, reusable master slots, overflow
rejection and 2,500 deterministic fragmentation steps with every live payload
checked after each step. Interleaved master blocks exercise movement around
pinned metadata. `python3 tools/check_mac_heap.py --sanitize` additionally runs
address and undefined-behavior sanitizers; it passes. The core is connected to Memory Manager traps and resource handles.

The API/zone-field reference is Apple's [Inside Macintosh: Memory Manager](https://developer.apple.com/library/archive/documentation/mac/pdf/Memory/Memory_Manager.pdf).
`tools/mac_traps.lua` now records zone, ApplLimit, zcbFree (the FreeMem value),
master-block size, MemErr and raw master-pointer data in its existing trap
action. Using a second breakpoint at the dispatcher would omit game records:
MAME runs only the first matching breakpoint. The local reference capture
`tmp/m1.5-reference.log` finishes with an explicit PASS. At the first
Engine+$004A NewHandleClear, free=$53F8; after MaxApplZone and startup work,
the next call at that same site has free=$2B0820. The 12 MoreMasters calls
allocate 64 master pointers apiece, consuming $108 bytes each. These are
reference observations, not values for the port to return unconditionally.


## Application-zone integration and reference acceptance

The application zone reserves 3,145,728 bytes of fast RAM; a separate 131,072-byte
system zone serves system allocations. Mac globals and stack remain outside the
zone. Resource handles now use its master blocks, flags, allocation and disposal;
whole-fork disk buffering has been replaced by bounded source reads (M2.2b2).
MemErr and ApplLimit are published into private low-memory shadows, and ResError
reads the actual ResErr shadow (including original-code writes).

Clean `HEAPPROBE=1` plus `GDBSCRIPT=heap.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30` passes three native Line-A stages: clear allocation, Ptr size,
handle size/state/lock/movement, Empty/Reallocate/RecoverHandle, system-zone
selection, PtrToHand contents, MemErr and exact FreeMem recovery. The separate
LINEAPROBE run passes register, CCR, callback, stack, vector and callable-original
checks. Production host tests, sanitizers, original-byte checks, boot regression,
low-memory publication and runtime observer all pass on the pinned 68020.
The original A5 dump has zero mismatches across 75,616 bytes (A5 $00786E48,
STRS $00443ED0). The next named stop is Gestalt('sysv'), Core+$3D36.

The paired heap checkpoint is **before the first Core+$3D36 Gestalt('sysv')**.
MAME's zone header reports FreeMem=2,821,316; native FreeMem=3,096,720. A full
block walk independently equals each header. The allowed difference at this
checkpoint is 275,404 bytes, fully accounted for (zero unaccounted margin):

| Source of additional native free space | Bytes |
| --- | ---: |
| Zone span: native 3,145,728 versus Mac 3,025,368 | 120,360 |
| Nine unused Mac CODE blocks, exact original bytes (4–6, 8–13) | 149,260 |
| Other Mac handle blocks, beyond four common resources and the 132-byte handle | 6,628 |
| Additional native 32-byte handle, including header | -56 |
| Larger native headers/alignment for the five common handles | -96 |
| Mac pointer/master blocks 3,872 versus native 4,536 | -664 |
| Zone header/trailer 52 versus 80 | -28 |
| **Total** | **275,404** |

This measures allocation differences; it does not assign guessed purposes to
unidentified Mac manager blocks. The nine unused CODE payloads total 149,180
bytes and are byte-identical in the Mac dump; avoiding these copies follows D1.
The separate native globals/stack and fixed SIZE arena explain the zone-span
difference. No fake FreeMem constant is returned.

`original_startup.gdb` writes the native heap to `tmp/amiga-heap.bin`. The local
MAME capture at the byte-checked $DD60 dispatcher saved [AppZone, bkLim) on
A1AD with D0='sysv' and finished with `PASS heap-dump captured` and
`PASS heap-reference capture completed`. Recheck the paired evidence with:

```sh
python3 tools/check_heap_capture.py tmp/m1.5-mac-heap.bin tmp/amiga-heap.bin \
  'tmp/runtime-data/Alone In The Dark'
```

The observer requires the measured baseline and verified unused resource bytes;
any changed allocation balance requires a new explained capture, not a widened
percentage tolerance. Native master pointers remain clean addresses, with flags
in side storage. Startup and the native probe exercise StripAddress, HGetState
and HSetState without relying on the reference's high-byte pointer flags.


## System identity (M1.6a)

The original reference capture (`tmp/m1.6-reference.log`, explicit PASS) gives:

| Query | D0 | A0 response |
| --- | --- | --- |
| Gestalt `sysv` | 0 | $0755 |
| `proc` | 0 | 4 (Mac reference 68030) |
| `qd  ` | 0 | $0230 |
| `help`, `fold`, `evnt` | 0 | 1 |
| `qtim` | $0000EA51 (-5551 in D0.W) | 0 |
| `a/ux` | $0000EA52 (-5550 in D0.W) | 0 |

SysEnvirons version 1 returns the complete 16-byte record
`00010005 07550004 01010005 003A8053`: version 1, Mac IIx (5), System 7.5.5,
processor 4, FPU and Color QuickDraw present, keyboard 5, AppleTalk driver $3A,
system-volume reference $8053. These describe the Mac reference, not native
Amiga hardware; the Amiga remains 68020 with no FPU. The File Manager catalog
must map the returned Mac volume reference. SysVersion's shadow is $0755.
Unsupported SysEnvirons layouts and unmeasured Gestalt selectors remain stops.

The normal game skips QuickTime's Gestalt call because the QuickTime trap is
absent. A local reference probe queried `qtim` through the original, byte-checked
Core+$3D36 instruction, then restored D0/A0/SR and re-executed the original
query. Its caller received the original result. The remaining answers and
SysEnvRec were captured without intervention. `tools/mac_traps.lua` now
records all SysEnvRec bytes on the original trap return.

`identity.gdb` validates the actual SysEnvirons record and six natural Gestalt
returns, then compares the eleven Engine flags at Engine+$43E2 against MAME:
`01010101 01010100 0101 01` (offsets 4 through 14). This exposed and fixed an
inherited missing WaitNextEvent entry. Its availability now matches the Mac;
execution was still a named stop at this checkpoint. Its later startup and
gameplay implementation is documented in [events.md](events.md). Unknown
Toolbox availability is not claimed from this observation.

A clean `IDENTITYPROBE=1` build with `identity_errors.gdb` executes native
Line-A instructions: QuickTime and A/UX return the exact captured errors, and
an unmeasured selector stops explicitly. An initial debugger-register injection
still executed the original sysv query, so the maintained probe sets arguments
in actual 68020 instructions. No game instruction is patched. The production
identity observer and diagnostic error probe both pass in bounded 68020 runs.

The next stop is HFSDispatch selector 8, GetFCBInfo, at Core+$4144. File Manager
work is M2.1 after M1.7's system windows. Full startup's success/requirements-alert
branches remain beyond that dependency, so **M1.6b retains that acceptance
check** after file/resource integration; matching identity flags is not reported
as a successful application launch.


## User-mode service bridge (M1.7a)

The Line-A handler recognizes a deferred-service result before changing USP or
CCR. It returns via RTE to a trampoline derived from Vette's existing user-mode
VBL trampoline. The trampoline parks D0–D7/A0–A6, CCR and the resume PC, calls
C++ in user mode, then restores the resulting image after moving it over consumed
Pascal parameters. The bridge preserves callable-original Toolbox return PCs
and OS flag variants. OS results set CCR from D0.W; Toolbox preserves CCR.
Nested ordinary traps suppress callback delivery until the outer service ends.
Recursive services and unsupported supervisor/exception frames are named stops.

Clean `SERVICEPROBE=1`, then `GDBSCRIPT=service.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30`, passes: four services, two callable originals, four nested
ordinary traps, one callback, all 15 registers, OS/Toolbox CCR and balanced stack.
The nested traps' saved exception SRs positively establish user-mode execution;
a zero counter cannot pass. Existing LINEAPROBE, clean production boot,
original startup and identity observers pass. HFSDispatch now enters one user
service and reaches the same named GetFCBInfo stop (zero completed services).

This is independently verified bridge work, not OS-window acceptance. The
machine is still taken over during services. M1.7b retains the full 1 MB/64 KB
file-read, checksum, picture, timing and OS-handback acceptance on the 68020.
No disk-read or display-continuity success is inferred from this ABI probe.


## System-window core (M1.7b1)

`make regression` runs `window-core` followed by a clean production `boot`.
The window case generates its 1 MiB fixture in ignored staging, clean-builds
`WINDOWPROBE=1 PROBES=1`, runs a bounded observer, and checks all three 98,304-byte
bitplane snapshots against the generated pattern. A stale file, missing PASS,
nonzero runner status, late display publication or wrong saved-file bytes fails.
The snapshot SHA-256 is
`0482278141cfa90510f767999d9e6b5a21c72429ad8d315b68f224fe1c9b81ba`.
These are chip-memory snapshots, **not captures of rendered video**; M1.7b2
retains actual-picture acceptance. The owner subsequently permitted leaving
that verification pending when the reference capture methods require access
that is not granted; see the pending section in `open-work.md`.

The window restores the OS Line-A and keyboard vectors, adds a priority-127
port VERTB server to the saved OS chain, restores OS interrupt enables while
retaining the port's enables, and permits scheduling. The operation runs in
the user-service task. On return it forbids scheduling, flushes stale keyboard
state while interrupts still run, then briefly masks interrupts to retake the
vectors. Copper/display DMA and Paula vectors are never deliberately replaced.
The existing 50-field/60-tick VBI clock continues through OS windows; the probe
checks the exact field/tick ratio and the private Ticks shadow.

The diagnostic sends a silent 1 KiB chip-memory loop through Paula AUD0 and
counts actual completion interrupts both inside and outside windows. Every one
of the sixteen primary reads must include an audio interrupt. Extra DOS checks
cover missing files, short reads, EOF, a 32-byte save and byte-exact native/host
readback, plus oversized requests rejected without entering a window. The
primary read checksum is FNV-1a `$59BC1DC5`. No original instruction is patched.

The first expanded test exposed a late display update (line 72) when the
128-key flush ran with interrupts disabled. Keeping that loop under the OS
keyboard vector with interrupts enabled removed the measured failure; the
maintained observer now rejects any late update. Window costs include this
flush and scheduler work; the beam epoch uses 256 units per raster line, with
313 PAL lines per field. These are functional-boundary measurements, not an
optimisation profile or a claim about real-time host speed.

`FileAccess::dos` opens/seeks/reads/closes each bounded request inside a window.
`FileAccess::whdload` uses a bound resload table, GetFileSize plus IOERR to
separate an empty file from a missing one, LoadFileOffset, and SaveFile.
Neither backend accepts a transfer above 64 KiB; whole-file saves above that
limit fail explicitly until persistent durable writes (M3.6). An unbound
resload backend returns unavailable. M7.2 must bind the real slave table and
run actual WHDLoad integration tests; this checkpoint makes no claim of an
actual WHDLoad launch. Host sanitizer fixtures exercise adapter outcomes;
a native fixture checks D0/D1/A0/A1 marshalling and preservation of all eleven
C callee-saved registers while the fake entry deliberately clobbers them.

Final core regression: zero late publications, maximum line 4; the primary
reads span 400 fields and 480 ticks. There are 230 Paula interrupts overall,
37 inside windows, and positive audio observations in all 19 successful read
windows (16 primary plus short/EOF/readback). All 21 OS windows together cost
16,059 beam-epoch units entering and 591,506 leaving: about 2.99 and 110.03
raster-line equivalents per window, respectively. Exit includes the interruptible
keyboard flush; it is not 110 lines with interrupts masked. Host checks and
clean production boot pass. The next real game stop remains GetFCBInfo.
Original startup also passes at A5 `$00787228`, STRS `$004442B0`: zero
mismatches across 75,616 bytes, with the paired heap check reporting zero
unaccounted bytes (Mac 2,821,316; native 3,096,720 free).


### Rendered-capture limitation (M1.7b2, owner-deferred)

After the host restart, the committed tree and build were intact. The recovery
observer completed with explicit PASS and byte-identical before/during/after
bitplanes; this still does not establish video appearance. A local app bundle
under ignored `tmp/` made the existing FS-UAE binary discoverable to computer
use, but access was not approved, and the owner explicitly declined it.

The requested reference review found:
- Slicks `amiga/diag_capture.gdb` dumps logical pixels; its
  `src/ui/screen_capture.h` encodes those pixels and a palette as a BMP.
- Revs `docs/headless-fsuae.md` warns that GDB greys/freezes the display.
  Its launcher and Vette's use F12+S with `FSEMU_SCREENSHOTS_DIR`.
- Rescue `docs/boost-cinematic-plan.md` describes live, non-debugger runs
  captured with host Screen Recording permission. Its SDL PNG writer captures
  the separate host renderer, not the Amiga emulator output.

None supplies unattended rendered FS-UAE captures within the granted access.
Do not label a logical export or a paused-debugger image as this acceptance.
M1.7b2 remains pending by the owner's instruction, while M2.1 is the next active
implementation item. No new screen permission or synthetic key posting is used.


## File Manager contract (M2.1a)

The expanded byte-checked reference logger records complete parameter blocks
on both sides of direct File Manager calls. The maintained
`check_file_reference.py` validates the pairing and required positive/negative
controls. See [file-manager.md](file-manager.md) for the measured FCB fields,
reference counts and outstanding implementation requirements. The original
Core+$4144 instruction selects **GetFCBInfo**, not GetWDInfo; the runtime label
is corrected. The native request's reference 0 exposes the inherited internal
Resource Manager index and must be replaced with an open-fork identity in M2.1b.
No File Manager service is claimed implemented by this diagnostic change.


## Catalog and application-fork identity (M2.1b1)

Production `GDBSCRIPT=file_catalog.gdb EXTRA_ARGS=--warp_mode=1 ./diag_run.sh 60`
checks the original GetFCBInfo/OpenWD calls and stops positively at SetVol,
Core+$4066. It requires the 39-entry catalog, 32 data files totaling 5,315,994
bytes, correct application fork/name and the WD reference consumed by SetVol.
See [file-manager.md](file-manager.md) for the Mac comparison and limits.
`make host-tests` includes sanitizer tests of paths, refs and exhaustion.
`original_startup.gdb`, `identity.gdb` and `runtime_status.gdb` retain their
checks at the new stop; two user services complete, with zero OS windows.
A5 and heap comparisons remain exact. Rendered-picture acceptance is still
owner-deferred; this checkpoint does not imply file-read or video acceptance.

Clean 68020 `make regression` passes both `window-core` (including exact
bitplane snapshots) and production `boot`. Host tests and link audits pass.


## Startup directory sequence (M2.1b2a)

`file_catalog.gdb` now runs through the original three successful OpenWD calls,
two SetVol calls, Preferences FindFolder and missing-movies fnfErr. It checks
original bytes, real arguments/results and Pascal stack cleanup, then requires
the named Get1NamedResource stop at Engine+$3CDC. `identity.gdb` expects seven
Gestalt calls because the newly reached FindFolder glue queries `fold` again.

The reference logger records FindFolder outputs from byte-checked glue;
`check_file_reference.py LOG --startup-directories` checks the ordered directory
sequence as well as the existing file contract. The bounded reference completed
normally with 98 paired file calls. Production startup, host tests, exact A5/heap
comparisons and clean 68020 window-core/boot pass. Seven user services complete,
zero metadata OS windows. Rendered screenshot acceptance remains pending.

M2.1b2b implements the remaining file core before M2.2. The original-game PAK
read acceptance is explicitly retained at M2.1c after Resource Manager support;
a native test fixture cannot satisfy that integrated acceptance.


## Buffered data-fork regression (M2.1b2b)

`amiga/regression.sh file-read` generates an ignored 200,003-byte fixture,
clean-builds `FILEPROBE=1`, and runs `file_read.gdb` with the normal bounded
runner. Native assembly wrappers issue real Open/HOpen, Read, Seek, GetFPos,
GetEOF and Close Line-A instructions. `FileProbe.cpp` verifies bytes, errors,
marks, ioActCount, condition codes and exact window counts. The observer also
continues through OS restoration and checks that the intentionally open final
stream is closed, with no remaining handles. Missing PASS or a timeout fails.

`make regression` runs file-write, file-read, window-core and a clean
production boot in that order. Host sanitizer tests cover the pure cache and fork-position model.
The synthetic names exist in the catalog only for the diagnostic build. No
original data is copied into the executable or committed. Production directory,
identity and original-startup observers retain the Get1NamedResource boundary;
M2.1c still requires original PAK reads/checksums. Actual WHDLoad persistent
streams and remaining variants are separate pending work. Writable data forks
are covered by the file-write regression below.

### File Manager query reference

`tools/mac_file_queries.lua` uses the documented headless MAME configuration
with debugger logging to measure indexed/exact PBGetFCBInfo returns. It verifies
original trap bytes and exits positively after six diagnostic calls; it never
counts as original-game PAK-read evidence. Check its log with
`tools/check_file_queries.py LOG --status RUNNER_STATUS`. Capture failures,
missing stages, incorrect errors and timeouts fail acceptance.

Set `AITD_FILE_QUERIES=directories` for the 21-call directory-state reference
fixture. Its HSetVol/HGetVol and WD measurements are checked with
`tools/check_file_queries.py LOG --directories --status RUNNER_STATUS`.
Set `AITD_FILE_QUERIES=wd` for the 27-call WD lifetime/filtering fixture, and
check it with `--wd` instead of `--directories`. The native `file-read` fixture
now covers 39 stages including hierarchical defaults, WD queries and closure.

### Buffered-write and mutation regression

`amiga/regression.sh file-write` adds a DOS backend fixture and real Line-A
Open/HOpen, Write, SetEOF, GetEOF/GetFCBInfo, Read, FlushVol and Close calls after
the read/directory fixture. It requires FILEPROBE=1 and FILEWRITEPROBE=1.
The case checks exact bytes, marks/EOF, CCR, the 25-pair permission matrix,
protected-file defaults/errors, shared writes and close order, cached-reader
coherence and volume-name/reference forms. It requires 387 runtime windows,
24 DOS writes (65,536 maximum), 18 flushes including shutdown and an empty
stream ledger after cleanup. Host readback verifies 17 backend bytes, six
shared-file bytes, four data bytes plus Finder metadata, and three bytes left dirty
until shutdown. Diagnostic files are recreated in
ignored staging for each run. `make regression` includes this case.

Run `tools/mac_file_mutations.lua` with the documented headless MAME command,
then `python3 tools/check_file_mutations.py LOG --status RUNNER_STATUS`.
The bounded reference fixture checks the original startup observer bytes,
runs File Manager traps from owned stack memory, creates only `AITD Port Write
Probe`, and requires successful delete/flush before its PASS. It never selects
a display mode or uses host window access. A failed Create stops without
opening or overwriting an existing file. On any later failure, inspect the log
and stopped disk for that named scratch before retrying. These API fixtures do
not constitute original-game save/load or PAK acceptance.

`tools/mac_file_sharing.lua` is a second scratch-only headless reference fixture;
check it with `tools/check_file_sharing.py LOG --status RUNNER_STATUS`. Its 222
calls cover permissions, shared data/independent marks, modified flags, both
close orders, file locks and volume lookup. The checker requires the actual
debugger stage register to match each row, the existing reference on a failed
conflicting Open, and successful scratch deletion/flush. Stage constants use
`0x` prefixes so values such as D0 cannot be parsed as register names. The
fixture's `AITD Port Sharing Probe` is its only created/deleted file.

The native fixture applies DOS protection to `locked-probe.bin` in a system
window. Host chmod alone is unsuitable: FS-UAE cannot open that read-only host
file through this stream backend. All files and FS-UAE `.uaem` metadata remain
ignored staging inputs. A scratch FileInfoBlock on the word-aligned Mac stack
was observed at alignment 2 and yielded shifted fields; runtime open metadata
uses the catalog's AllocDosObject/FreeDosObject pattern instead.


### Named catalog mutations and Finder metadata (M2.1b2c9b)

`tools/mac_file_catalog_mutations.lua` uses the same headless CPU-only protocol.
Check its 36 calls with `python3 tools/check_file_catalog.py LOG --status STATUS`;
the process must exit normally. The sole created/deleted file is `AITD Port
Catalog Probe`. This measures Create/HCreate, Delete/HDelete, named Get/SetFInfo
and hierarchical variants, duplicate/busy/locked/missing errors, fresh file IDs,
Finder bytes, dates and modification-date publication at FlushVol. Original
Core+$4142 is byte-checked before installing the owned stack stub.

Native `file-write` stage 43 adds 15 catalog checkpoints. It validates normal
startup decoding of a seeded companion, deletion of data plus companion,
locked-file metadata, initially absent Preferences-directory creation, and independent host readback of a created file's four
bytes and checksummed Finder record. The modification date stays unchanged
while data is pending and advances when Close flushes it. Metadata writes use
OS windows and staged replacement; malformed/orphan companions and incomplete
transactions fail explicitly. The host checker removes only verified diagnostic
output before subsequent production runs.

The Finder output test exposed a GCC 15.1 m68k byte-loop miscompile:
`MOVE.B (a0)+,(a0,d0.l)` used the incremented register for its destination,
shifting the returned bytes by one. Catalog memory and disk bytes were exact;
the parameter-block dump and disassembly isolated the error. Four explicit
endian-safe copies replace that loop, and the native fixture checks all 16 bytes.


### Independent fork regression (M2.1b2c9a)

`tools/mac_file_forks.lua` is the owned `AITD Port Fork Probe` reference; run it
with the documented headless MAME command and check the actual process status
using `tools/check_file_forks.py LOG --status STATUS`. All 60 ordered results,
fork bytes, FCB flags, open references and final cleanup are required. It checks
Core+$4142 and HOpenRF at Core+$4158 before running any diagnostic traps.

Native `file-write` stage 44 covers separate data/resource streams and companion
lifetime, including loading a seeded companion on the next startup path. Host
readback compares both durable fork files and hashes the whole application
resource after a data-fork write. Verified diagnostic outputs are removed before
production regressions. The application source remains the existing raw fork;
only its optional `.data` companion stores data-fork changes. Ordinary files
use `.rsrc` and `.finfo`; companions are never separate virtual catalog files.


### Installed-file metadata (M2.1b2c9c1)

Re-run `tools/extract_original_data.py` to create the 36 `.finfo` companions.
Extraction requires `lsar` and `xattr` alongside the existing unar/hfsutils tools.
It compares the archive entry name, fork layout, sizes, compression method,
type/creator/flags and extracted Finder record before emitting a companion.
Original Mac timestamp integers come directly from the checked 112-byte StuffIt
header. Displayed lsar dates and host filesystem timestamps are not substituted.
The current development staging helper requires the application companion and
copies the data-folder companions alongside their unchanged payloads.

Run `tools/mac_file_installed.lua` with the headless reference command, then
`tools/check_file_installed.py LOG tmp/runtime-data --status STATUS`. It is
read-only and compares application, Camera00.PAK, ITD_Ress.PAK and Present.PAK.
The current reference volume's MacBinary import shifted creation/modification
dates by -7200 seconds; Finder also cleared the data files' initialized flag and
placed the application icon at x=128. The checker verifies those exact measured
differences instead of treating all fields as identical. The port preserves the
archive metadata and extraction's Finder bytes; it does not reproduce incidental
host-timezone conversions or the reference Finder's icon placement.

Native `file-write` stage 44 checks all returned Finder fields, original dates,
logical fork sizes and open attributes for the same four files before the fork
mutation fixture (now stage 45). The regression uses 268 runtime windows; stream
read/write/flush counters remain those of the fork fixture. The additional
application metadata is also persisted when its diagnostic data write closes.


### Indexed file-info queries (M2.1b2c9c2a)

`tools/mac_file_index.lua` creates only `AITD Port Index Probe` beneath the
reference application directory, populates it in reverse order with 67 supported
printable-ASCII names plus a subdirectory, queries it, and removes everything.
Run headless and validate with `tools/check_file_index.py LOG --status STATUS`.
The 218-call fixture verifies all returned names/IDs and excludes directories.
It also covers null output-name pointers, negative named indices, classic/default
selection, bad volume/directory and a WD plus bad explicit directory. Successful
cleanup and normal process exit are required; an existing scratch directory is
never reused or overwritten.

Native stage 46 checks ordering against known existing save files, the grave
accent's special position, canonical name outputs, null-name identity, errors,
classic/default selection, WD precedence and reindexing after deletion. Host
sanitizer tests cover all 67 characters and reverse insertion order. `file-write`
is included in the current 387-window regression. The dedicated application directory also supports indexed queries; System/root
and the legacy mixed native directory remain explicit unsupported boundaries.


### Original application-folder files (M2.1b2c9c2b1)

The extractor also preserves `ListBod2.PAK` (268,430 data bytes),
`Quick Reference` (4,973 data / 712 resource bytes), and
`Register Triple A Pack` (0 data / 87,427 resource bytes). Ordinary resource
forks use raw `.rsrc` companions; the application retains its existing raw-fork
layout. Both fork records must agree with the shared original StuffIt header,
including resource-first offsets, lengths, methods and Finder fields. Missing
or duplicate records and invalid AppleDouble extents fail explicitly.

All four nonempty forks compare byte-for-byte with read-only MacBinary exports
from the System 7.5.5 reference application folder. The three full file
(data then resource) SHA-256 values are respectively
`5c552161db462f80e82346494a304d133ca502c92ab299a77b82ca988fd1893e`,
`6173b910b6b572a00bfef3ca40b7e738712ef7a1f533c90c4bc549a200696e69`, and
`a90c4bbebe9615a900ddfbd8f5c5d845ec8e304970a558aea0a663a0c8b7c870`.
The metadata tests cover two-fork records and reject incomplete/mismatched
pairs. These outputs are integrated into staging and the native application catalog.


### Application namespace regression (M2.1b2c9c2b)

`mac_file_installed.lua` now makes 13 read-only calls: seven named original-file
queries, the four application-file indices, end-of-directory and a missing name.
The checker compares indexed IDs/metadata to named results. The three added root
files retain their Finder flags on the reference disk, with icon coordinates
(y=52, x=0/128/256); these measured installation changes are checked explicitly.
Native stage 44 checks their original metadata, fork sizes, canonical indexed
names and both -43 results, finishing at step 10. The complete production catalog
contains 42 entries; directory calls need no DOS windows, while streamed
resources now add 13 runtime windows (M2.2b2). Current File-write totals include the later OpenDF, HGetVInfo and async fixtures below.

After the production boot build, run `python3 tools/check_file_namespace.py` with
`amiga/env.sh` sourced. Its three bounded native startup runs require normal exit:
an unknown ordinary file raises the catalog count to 43, an unknown directory
returns `CATALOG / UNSUPPORTED DIRECTORY`, and an orphan `.rsrc` returns
`CATALOG / ORPHAN COMPANION`. Each fixture owns and cleans only its named scratch.
The observer finishes the real catalog builder before takeover; no game file is
modified and no host window access is used.


### Volume-parameter regression (M2.1b2c9c2c1)

Run `tools/mac_file_volparms.lua` using the documented headless MAME command,
then `python3 tools/check_file_volparms.py LOG --status STATUS` with its actual
exit status. The read-only 22-call fixture checks the original Core+$43F4
`7030 A260` bytes and the standard +$4142 observer bytes. Its initial GetVol
supplies an actual working-directory reference for the round-trip case.
No mode selection, original-code patch or host-window access is used.

Native `file-write` stage 47 finishes with `g_fileVolumeProbeStep=35`; the marker
includes `volparms=exact`. These catalog-only queries add no system windows. Record bytes, untouched buffer tails,
ioActCount, D0/ioResult and CCR are checked. File-read, window-core, boot and the
42-entry original-directory observer remain regression gates.


### OpenDF dispatch regression (M2.1b2c9c2c2)

Run `tools/mac_file_opendf.lua` headless and check the actual process status with
`python3 tools/check_file_opendf.py LOG --status STATUS`. It owns only
`.AITD Port DF Probe`; failed Create stops before any open. The 69-call fixture
checks Core+$3F78 (`701A A060`), both synchronous dispatch encodings, a leading-dot
filename, permissions 0–4, writer conflicts, independent shared marks, locks,
classic/HFS directory selection, errors and deletion/flush before completion.

A060 ignores ioDirID and resolves an explicit volume reference at its root.
The fixture proves it uses the default directory with reference zero and ignores
an invalid ioDirID, while A260 validates the directory ID. The immediate catalog
query and captured name bytes establish the scratch file before either open.
Error probes additionally distinguish bad starting IDs/file parents (-43) from
missing intermediate directories (-120), and prove failed opens clear ioRefNum
except the existing reference returned for a writer conflict. A bare leading-dot
HOpen addresses drivers; the ordinary-file HOpen error probe uses a leading colon.

Native stage 48 reaches `g_fileOpenDFProbeStep=17`, including matching errors for
HOpen/HOpenRF, dot-name read/write, both aliases and protected files. Host checks
verify open-specific path resolution without changing directory-query semantics.
The current file-write totals, including the HGetVInfo/async fixtures below, are 387 windows, 33 reads / 866,733 bytes, and
24 writes / 470,069 bytes with 18 flushes including shutdown. All owned scratch
forks/companions must be absent afterward; the restored stream ledger is empty.
File-read, window-core, production boot and the 42-entry original directory
observer remain required. Original game PAK reads remain separate acceptance.


### HGetVInfo regression (M2.1b2c9c2c3)

Run `tools/mac_file_vinfo.lua` with the documented headless MAME command, then
`python3 tools/check_file_vinfo.py LOG --status STATUS` using its actual exit
status. The 16-call read-only fixture checks both original callers' bytes,
volume/index/name/WD selection, untouched error outputs, the complete HFS record,
and opening/querying its System Finder ID. The reference reports drive 8; the
port's sole virtual drive is 1. Its disk geometry is deliberately mapped from
DOS rather than copied from the reference volume (see file-manager.md).

Host tests cover selection, every output field, guard bytes, live catalog counts,
capacity aggregation and buffered-growth reservation. Native file-write stage 49
reaches `g_fileVInfoProbeStep=12`; each successful record is compared to the same
call's six-field `g_volumeBackingProbe` snapshot. Eight successful queries add
eight OS windows; invalid selections add none. The System lookup checks the
returned WD rather than assuming a reference survives the earlier CloseWD test.
Both globals are retained by the probe link audit.

Acceptance including the async fixture below: file-write passes with 387 windows, 33 reads / 866,733 bytes and
24 writes / 470,069 bytes / 18 flushes including shutdown. File-read, window-core,
production boot and the original 42-entry directory observer remain required;
rendered-picture verification is still owner-deferred. Original initialization
still stops at Engine+$3CDC Get1NamedResource. Seven directory services plus
13 resource services/windows now give 20 total services (M2.2b2). This does not establish original PAK-read acceptance.


### Async reference and native fixtures (M2.1b2c9c2c4)

Run `tools/mac_file_async.lua` with the standard headless MAME command twice,
setting `AITD_ASYNC_CLOBBER=0` then `1`. Check each actual runner status using
`python3 tools/check_file_async.py LOG --status STATUS`. Both modes pass 33 calls
and 25 early callbacks. The checker requires all eleven original caller byte
checks, callback-before-return ordering, PB/result identity, register restoration,
D0/CCR behavior, scratch metadata readback, cleanup and explicit completion.
A normal emulator exit without the completion marker fails.

The clobber mode intentionally changes the callback scratch registers. Its D0
must survive the trap, while D1/D2/A0/A1 must not leak to the caller. The normal
mode checks final errors directly. These paired runs distinguish callback ABI
from ordinary file-service behavior. The reference files remain local-only;
only the fixture and checker are tracked. Native stage 50 checks 67 calls and 51 callbacks, including the synchronous
protected-WD exception and root closure. The final callback makes a nested
synchronous query; assembly sentinels validate D1/D2/A0/A1/A5 after it returns.
The debugger checks supervisor state, completion depth and inactive service state
at every callback entry. `g_fileAsyncStep=67`, `g_fileAsyncCallbacks=51`,
`g_fileAsyncNestedOK=1` and zero final completion depth are required positive
controls, retained by the probe-symbol link audit. Probe assembly has its own
section so file-read/production builds do not retain probe-only references.

File-write requires 387 windows and unchanged final read/write totals; its two
restored closes must leave no open streams. The checker also requires absence
of all `.async-probe` data/resource/metadata companions. Host tests, file-read,
window-core, production boot and the directory observer pass. The original run
still stops at Get1NamedResource; completing census variants is not original
PAK-read or successful-startup acceptance.


### Map-only resource parser (M2.2a)

`make host-tests` includes `tools/check_resource_map.py`. The portable
`ResourceMap` accepts a 16-byte header and a separately retained map; it never
receives a payload pointer or performs allocation/I/O. Its entries preserve the
original type/reference order, signed IDs, attribute bytes and Pascal names.
Each exposes a length-word file offset. Only after the caller reads that word
does `payload` validate the body range and return its stream offset. Zero-length
resources and a valid empty map are supported. Invalid/overlapping map regions,
truncated names/references, duplicate type blocks, capacity overflow and invalid
payload lengths fail explicitly; a failed open leaves no visible entries.

To check local original bytes without committing assets:

```sh
python3 tools/check_resource_map.py --original 'amiga/.run/dh1/data/Alone In The Dark'
```

The ASan/UBSan fixture copies the header/map into separate buffers and compares
all 212 entries against the existing independent Python fork reader, including
name bytes, IDs, attributes, sizes, order and payload FNV checksums. The measured
map is 4,998 bytes; the full application resource fork is 1,424,934 bytes. The
synthetic fixture includes malformed maps, duplicate IDs, empty maps and lengths
that exceed the data region or overflow naive arithmetic.

This is a parser foundation, not completed on-demand loading. Vette's
`ResourceForks` and `PlatformAmiga` also preload whole forks; their parsing
conventions are reused, while bounded I/O must come from this port's File Manager.
The runtime uses file-backed resource sources as of M2.2b2.
Its acceptance must cover direct and indirect resource loads through user-mode
system windows, all original CODE-byte validation, sample resource checksums,
startup window counts and all existing native regressions. Writable maps,
Resource Manager search/handle semantics and overlay support remain M2.2 work.


### Callback-backed resource directory (M2.2b1)

`ResourceForks` now owns validated map copies and accepts a source context, source
length and read callback. Opening reads only the 16-byte header, map and four-byte
length prefixes; each prefix/body range is checked by `ResourceMap`. It retains
metadata and file offsets, with no payload pointer for file sources. Map copies
are capped at 256 KiB and the existing combined 768-resource limit remains;
unsupported sizes fail rather than allocating from untrusted lengths.

The `read` API fills caller-owned storage in transfers of at most 65,536 bytes.
Invalid destination capacity performs no reads, zero-length resources need no
buffer, callback errors propagate, and a short successful transfer returns -39.
The caller must discard incomplete destination contents on error. A failed open
releases partial maps and publishes no entries. Source contexts remain caller-owned
until close. At M2.2b, ResourceForks retained sorted handle indices while
ResourceMap retained original order; M2.2e now preserves map order throughout.

`tools/check_resource_source.py`, included in `make host-tests`, uses ASan/UBSan
and a guarded source that rejects any payload read during open. Its two-resource
fixture opens with four reads totaling 86 metadata bytes, then reads a 100,003-byte
resource in two bounded transfers with guard bytes intact. It covers read errors,
short reads, empty resources, two-fork identities, failure cleanup and the resident
compatibility adapter. The full host suite and all native regression gates remain
required because the adapter now uses the same map parser as file sources.

The resident compatibility adapter remains for host fixtures only. Platform
startup and zone-handle fills use file-backed sources as of M2.2b2 below.


### Streamed startup resources (M2.2b2)

`amiga/regression.sh resource-read` clean-builds a production executable, checks
positive preparation/runtime counters, and captures STRS 0 (1,810 bytes) and
mctb 128 (32 bytes) from their live zone handles. `check_resource_reads.py`
compares both dumps byte-for-byte with the original fork and prints their SHA256
checksums. No completion marker, missing dump, timeout or runner error can pass.

Platform startup keeps one DOS handle, a 4,998-byte map and resource metadata;
it no longer allocates/loads the 1,424,934-byte application fork. Preparation
reads 201,058 bytes in 228 operations: the header/map/length words and one CODE
resource at a time for the existing original-byte validation. All 58 low-memory
sites are checked before takeover; only CODE 0 and CODE 1 remain resident then.
Discarded validation buffers do not serve runtime resource requests.

Original startup subsequently performs 13 source reads / 68,336 bytes in 13 OS
windows before the unchanged Engine+$3CDC Get1NamedResource stop. Its directory
observer now requires 20 balanced services (seven file + thirteen resource).
Source requests are capped at 65,536 bytes; the largest observed startup request
is 27,692 bytes. GetResource, GetNamedResource, InitMenus, GetMenu, GetNewCWindow,
GetNewPalette, GetCursor, GetPicture and GetNewDialog use the user-mode bridge.
An indirect load outside that bridge is `RESOURCE READ OUTSIDE USER SERVICE`,
never a supervisor-mode DOS call. Failed reads empty the incomplete handle and
return the I/O error; later calls can retry. Source close errors are reported.

`g_resourceSourceReads/Bytes/Max` cover preparation plus runtime;
`g_resourceRuntimeReads/Bytes` isolate takeover reads. `g_resourceSourceOpen` and
`g_resourceSourceCloseErrors` make cleanup observable. All are retained by the
link audit. File-read/write fixtures retain their own unchanged transfer counters
and additionally require a closed resource source after OS restoration.
Writable resource maps, remaining Resource Manager calls and overlay semantics
are still M2.2 work; streaming acceptance does not prove original PAK reads.


M2.2b2 validation also reruns `original_startup.gdb`: the host A5 model matches
all 75,616 debugger-dumped bytes (zero mismatches). File-write/read, window-core,
boot, resource-read and the original directory observer complete with explicit
PASS records and normal runner exits. The bitplane snapshot hash is unchanged;
actual rendered-video acceptance remains owner-deferred.


### Named/ID resource lookup reference (M2.2c1)

Run `tools/mac_resource_named.lua` with the documented headless MAME command,
then check its actual exit status:

```sh
python3 tools/check_resource_named.py tmp/LOG --status STATUS \
  --original 'amiga/.run/dh1/data/Alone In The Dark'
```

The observer byte-checks original Engine+$3CDC (`A820 245F`) and its STR# argument,
then captures the original Pascal name `General` and successful handle. It executes
20 read-only calls through a scratch stub without changing original instructions.
Before each call it seeds ResErr ($A60) with $8888 and D0 with $12345678, so stale
success cannot pass. It requires Pascal stack cleanup, cached-handle identity,
errors and D0 results. The captured STR# 128 body must equal all 612 original
bytes (SHA256 `76033c1f20d7086387ee1baf6a7fc255f162961f217421a4c77373ea6e260af1`).
The script removes its owned prior dump before launch; no original file is written.

Measured on this System 7.5.5 volume:

- Get1NamedResource accepts General/general/GENERAL as the same cached handle.
  An accented spelling, absent name, differently cased type code and empty name
  return nil with ResErr -192. Empty names do not select unnamed STRS 0.
- GetNamedResource gives the same named results but preserves incoming D0.
  Get1NamedResource returns the zero-extended ResErr word in D0.
- Get1Resource/GetResource reuse the same General handle by ID. Missing IDs
  (zero, positive and negative) and an absent type return nil with **ResErr 0**,
  clearing the deliberately seeded error. This is measured reference behavior;
  do not replace it with the named lookup's -192 assumption. Their D0 is zero.
- Error Messages resolves to a distinct nonnull handle; later General lookups
  still reuse the original handle and clear the previous named-lookup error.

Original Dan1 Get1Resource callers at +$35CE/+$36EA/+$39E4/+$3A66 all contain
`A81F 285F`; these calls were the next implementation step at this reference checkpoint. Multi-fork search order, SetResLoad/purge/reload,
writable-resource naming and non-ASCII case-pair tests remain M2.2 acceptance;
this single-current-fork fixture does not establish those semantics.


### Native named/ID resource lookup (M2.2c2)

Get1NamedResource/Get1Resource now restrict lookup to the current fork; the
existing chain variants share their resource cache. Named misses and empty
names report -192, while ID misses clear ResErr to zero, matching M2.2c1's seeded
reference. Get1NamedResource and ID lookups expose zero-extended ResErr in D0;
GetNamedResource preserves its incoming D0. Null Pascal-name pointers remain a
named unsupported call. Multi-fork search-order and non-ASCII case-pair fixtures
remain part of the remaining Resource Manager work.

At this checkpoint, native file-write stage 51 reproduced all 20 reference calls. It required
`g_resourceLookupStep=21`, General FNV `$54B9DC7D`, two runtime resource reads /
863 bytes, and 378 total system windows. The other file transfer totals remain
unchanged. The assembly wrappers expose trap D0 and return the Pascal handle;
returning normally through all wrappers also verifies their stack cleanup.

The production `resource-read` observer stops at original Engine+$3CDE, verifies
nonzero General handle/data, ResErr=0 and D0=0, and captures all 612 bytes before
DetachResource. Its three debugger samples (General, STRS and mctb) must exactly
match the original resource bodies. Original startup then reaches Font Manager
GetFNum (`A900`) at Dan1+$0012; original bytes are `A900 4A6E`. This remains a
named stop for M2.9, not a guessed font answer. The OpenResFile helper that returned
-1 without opening anything is removed; it now stops explicitly until implemented.

The new startup totals are 23 balanced user services, 16 runtime resource reads /
96,648 bytes and 16 OS windows. The loaded CODE mask is `$188B`, with 53 applied
low-memory sites and all 58 sites validated. Directory, original-startup,
identity and low-memory observers now use this measured boundary. Earlier
Get1NamedResource/13-window records document the prior checkpoint. `resource-read`
retains the same preparation count (228 reads / 201,058 bytes), proving no new
preloading. Acceptance passed: the full host suite; native file-write, file-read,
window-core, boot and resource-read; catalog, startup, identity and low-memory
observers. Every run exited normally. The startup A5 dump has zero mismatches
across all 75,616 bytes. Rendered-picture verification remains owner-deferred.


### Resource metadata and lazy-handle reference (M2.2d1)

`tools/mac_resource_handles.lua` runs 18 synthetic calls on the System 7.5.5
reference after checking original Engine+$3CDC (`A820 245F`). It uses scratch
stack instructions, without editing the game's code or files. The paired
`tools/check_resource_handles.py` requires normal runner exit, every ordered
result, stack cleanup, output canaries, handle identity and exact reloaded bytes.
It also checks original Gloss SetResLoad sites +$03CC/+$03E0 and GetResInfo +$03F4.

Measured contract:
- GetResInfo returns General's ID/type/Pascal name with ResErr/D0 zero. It also
  returns Error Messages metadata while its resource handle is empty, both
  before its first load and after EmptyHandle.
- A nil or detached handle returns ID -1, type zero, an empty Pascal name and
  ResErr/D0 `$FF40` (-192). Bytes beyond the returned name remain untouched.
- SetResLoad(false/true) writes ResLoad 0/1 and preserves seeded ResErr and D0.
  With loading disabled, ID and named lookups share a nonnull empty handle.
  Re-enabling loading makes lookup fill that same handle.
- LoadResource explicitly fills/reloads the handle even when ResLoad is false,
  clears ResErr and preserves D0. EmptyHandle clears the body while preserving
  the resource association and ResErr. The reloaded 251-byte STR# 2001 body
  matches the original, SHA256
  `3646fd58d4898bbae89c6e1283418c305adf3016bcce50d8f7ce36e865d38341`.
- DetachResource preserves the body and clears ResErr/D0. GetResInfo then reports
  no resource association. LoadResource on this already loaded detached handle
  preserves its body, clears ResErr and preserves D0. ReleaseResource(nil)
  returns -192 while preserving D0.

The final reference run exited zero and its checker passed. This is reference
acceptance only: native implementation and matching probes are M2.2d2. Automatic
heap-pressure purge, unloaded detached handles, valid ReleaseResource disposal,
multi-fork lookup and writable forks are not established by this fixture.


### Native metadata and lazy handles (M2.2d2)

GetResInfo returns metadata independently of resource residency. Missing or
removed associations return the measured -192 and cleared outputs; bytes beyond
returned Pascal names remain untouched. A volatile byte-copy loop avoids the
known m68k overlapping-address copy defect. Null output pointers stop by name.
SetResLoad updates the private ResLoad byte without changing ResErr/D0. Disabled
lookups return an empty associated master pointer without reading the source.
LoadResource runs through the user-mode service bridge and explicitly fills the
same handle regardless of ResLoad. The measured detached loaded-handle case is
successful without reading; unsupported empty/unassociated cases stop by name.
DetachResource now also clears D0. ReleaseResource(nil) returns the measured
-192 and preserves D0; remaining valid release/flag semantics are M2.2d3.

`ResourceHandleProbe.cpp` reproduces the 18 reference calls before the existing
20 lookup calls. The handle fixture is file-write stage 51 and lookup is now
stage 52. The fixture checks errors, D0, metadata canaries, resident/empty state,
master-pointer identity and disk counters after every operation. Error Messages
has FNV `$20AC017E` after both explicit reload and re-enabled lookup, and after
detach. No metadata or disabled lookup reads resource bodies. The combined probe
requires step 19/21, five resource reads / 1,616 bytes and 381 system windows.
File Manager transfer and cleanup totals remain unchanged. M2.2c2's 378-window
record above describes its earlier standalone lookup checkpoint.

Acceptance: full host suite; native file-write, file-read, window-core, boot and
resource-read; catalog, original-startup, identity and low-memory observers all
passed with normal exits. A5 globals match all 75,616 bytes. Original startup
remains at GetFNum Dan1+$0012 with 16 read windows / 96,648 resource bytes,
23 balanced services and 53 applied/58 validated low-memory sites. No owner
decision changed; rendered-picture verification remains deferred.


### Resource purge/release lifecycle (M2.2d3)

The CPU-only `mac_resource_lifecycle.lua` fixture checks original Engine+$3CDC,
then exercises 28 calls using original CREL 13 (attributes `$28`, 1,288 bytes).
`check_resource_lifecycle.py` requires ordered results, stack cleanup, ResErr,
MemErr, D0, empty/resident transitions and 24-bit Mac master-pointer flags. Its
reloaded dump exactly matches the original, SHA256
`bc4576dd01b2ce1faaebe866250d2366ccc5e5435d876182880a3c76c4ed5336`.
The reference exits zero. Timeout, incomplete captures and corrupt results,
flags or stack records are rejected by the checker.

Measured behavior and native implementation:
- CREL's resource/purge flags are `$60`. PurgeMem with an impossible `$FFFFFF`
  request empties it while returning memFullErr (-108); LoadResource restores
  its exact body and flags using the same master pointer.
- HLock gives `$E0`, and the same purge request preserves the locked body.
  ReleaseResource disposes the resource even while locked. A later lookup
  creates/loads a resource again; reusing a freed master slot is permitted.
  Ordinary and already-empty release also succeed and preserve D0.
- HGetState, HLock, HPurge, HUnlock and HSetState on an empty handle return
  nilHandleErr (-109) in MemErr and sign-extended D0. The native OS dispatch now
  applies this contract; internal resource association is maintained separately.
- DetachResource on an empty resource succeeds (ResErr/D0 zero), leaving the
  measured MemErr -109. LoadResource and ReleaseResource on that detached empty
  handle return -192 and preserve D0/MemErr. LoadResource(nil) succeeds without
  changing D0/MemErr. DetachResource(nil) returns -192 in ResErr and `$FF40` in D0.

File-write stage 53 repeats the 28 calls with per-call read/window counters and
checks CREL FNV `$8D35D0BE` at every resident state, including after purge and
release/relookup. The fixture ends at step 29 with five reads / 6,440 bytes.
Together with the prior probes, file-write requires ten resource reads / 8,056
bytes, 386 windows and 66 resource calls. File Manager totals remain unchanged.
Native master pointers remain clean 32-bit addresses; HGetState verifies their
flags through the existing side metadata. Disk errors and unsupported pointers
still stop explicitly; writable dirty-resource disposal belongs with writable
fork support. The earlier checkpoint totals above remain historical records.

Acceptance passed: the full host suite and all five native regression cases,
plus catalog, original-startup, identity and low-memory observers. Every runner
exited normally. The startup A5 comparison has zero mismatches / 75,616 bytes;
production resource counters and the GetFNum boundary are unchanged. Rendered
video remains owner-deferred. No owner decision is needed for this checkpoint.


### Original-order resource enumeration (M2.2e)

`mac_resource_enumeration.lua` captures 44 CPU-only calls after the original
Engine+$3CDC byte check. `check_resource_enumeration.py` derives expected counts
and order directly from the independent original-fork reader, requires normal
exit, and checks stack cleanup, D0/ResErr, metadata and handle reuse. Current-file
counts are CREL 10, CODE 14 and STRS 1; missing-type counts are zero with no error.
CountResources matches for the application-specific CREL type and an absent type.
This does not establish multi-fork duplicate handling, which remains M2.2f.

Get1IndResource follows original reference-list order, not sorted resource IDs.
CREL enumerates `13,12,3,4,5,6,7,8,9,10`; CODE indices 1/2/14 give IDs 2/13/0.
Zero, negative, out-of-range and missing-type indices return nil, ResErr -192
and D0 `$FF40`. Successful counts and indexed lookups clear ResErr/D0. With
ResLoad false, each new CREL lookup returns a distinct empty resource handle;
GetResInfo still returns its ID/type. Re-enabling loading fills the same first
handle with original CREL 13: 1,288 bytes, SHA256
`bc4576dd01b2ce1faaebe866250d2366ccc5e5435d876182880a3c76c4ed5336`.

ResourceForks no longer sorts its records. Its bounded linear ID lookup returns
indices into the original-order directory; resource-handle and payload indices
therefore stay consistent. The host source test checks unsorted positive/negative
IDs, two-fork order and find/index agreement without body reads, under ASan/UBSan.
Native Count1Resources and Get1IndResource use the current fork; CountResources
supports the current single-fork configuration and explicitly stops if multiple
forks are present until M2.2f establishes that contract.

File-write stage 54 reproduces the 44 reference calls. Every count, metadata call
and disabled-load lookup leaves disk counters unchanged. The final enabled lookup
adds one 1,288-byte read, preserving the original empty master pointer. Terminal
step is 45 and FNV is `$8D35D0BE`. The combined resource probes now check 110
calls, eleven reads / 9,344 bytes and 387 total windows, with unchanged File
Manager transfer and cleanup totals. Prior checkpoint counts above are historical.

Acceptance: host suite (including source ASan/UBSan), all five native regressions
and four startup observers passed with normal exits. All 75,616 A5 globals match.
Original startup remains GetFNum Dan1+$0012, 16 runtime resource reads / 96,648
bytes and 23 balanced services. No owner decision changed; rendered-picture
verification remains deferred.


### Resource-file and search reference (M2.2f1)

`mac_resource_files.lua` runs 63 CPU-only calls after checking Engine+$3CDC.
It exclusively creates `AITD Resource Probe A/B` through the File Manager, then
initializes their resource maps with CreateResFile/HCreateResFile. An existing
scratch name aborts before mutation. OpenResFile, OpenRFPerm and HOpenResFile,
AddResource, UpdateResFile, CurResFile, UseResFile and CloseResFile exercise two
independent maps. Both scratch files are closed and deleted on success. The final
run exited zero, and `check_resource_files.py` passed. Its checker rejects a
timeout, missing completion/cleanup and changed counts/current state/data/errors.
No original resource or game file is modified. Native integration remains f3.

Measured rules:
- Opening makes a file current. Reopening already-open A returns the same
  reference. UseResFile changes the lookup start without reordering the chain.
- Named/ID chain lookup starts at the current file, then visits older files.
  B finds its own STR# 128, then A-only data when missing locally. Selecting A
  hides newer B from lookup; selecting the application restores its original
  General resource. Get1Resource remains strictly current-file-only.
- CountResources traverses **all open maps regardless of current file**, and
  counts duplicate IDs separately. The scratch RPRB type has four entries,
  including ID 7 in both A and B; count remains four with B, A or the application
  current. B's Count1Resources is two. The two shadowing STR# 128 entries add
  two to the pre-open STR# count. Reference baseline is 76 (including System
  resources); native acceptance must compare the delta to its own overlay,
  rather than fabricating the reference System's unused resources.
- Closing current B selects A, then closing A selects the application. Invalid
  UseResFile and repeated CloseResFile return -193 with D0 `$FF3F`, preserving
  the current selection. CurResFile preserves seeded ResErr/D0.
- OpenResFile preserves D0 and returns -1 / ResErr -43 when absent. OpenRFPerm
  and HOpenResFile success leave D0 zero; CreateResFile/HCreateResFile leave
  D0 4/10 in these measured calls. UseResFile/CloseResFile/AddResource clear D0
  on success; UpdateResFile preserves it.
- Update/close followed by HOpenResFile yields the exact four-byte A resource
  again. The six added resource handles are independent; repeated lookups reuse
  each file's handle. Cleanup is positively observed, including a missing-open
  after deletion and restored application current-file state.

The checker validates original Core instruction pairs at +$46F2 (`A81A 3D5F`),
+$4830 (`A81B 6000`), +$4780 (`A9C4 3D5F`) and +$48BE (`A9B1 558F`). This fixture
uses read/write permission 3; it does not establish all permission/error/write
variants. F2 first provides the mutable on-demand fork model and serialization;
f3 connects it to the existing streams and reproduces these native calls.


### Streaming resource-fork serialization (M2.2f2a)

`ResourceWriter` accepts immutable entries containing type/ID/attributes, borrowed
names and a source/offset/length for each payload. Added or changed resources can
supply their own source; unchanged originals remain disk-backed. It emits a
canonical header, length-prefixed data and resource map. Type order follows first
appearance; each type's reference order follows the recipe. Named-empty and
unnamed entries stay distinct. No resource payload is retained by the writer.

Duplicate type/ID pairs retain independent bodies and recipe order. Preflight
rejects invalid source ranges, missing source
callbacks, impossible names, resource count overflow, 24-bit data offsets and
16-bit map/name offsets before opening the sink. Memory consists of bounded
position/type tables, a map (capped at 256 KiB) and one 64 KiB transfer buffer.
Each source read and sink write is at most 64 KiB; short I/O is an error.
The sink must stage into storage separate from the original and publish only on
successful completion. Read/write/begin/commit failures trigger abort; the sink
contract requires failed publication to preserve the old target. This is a
portable transaction contract, not yet a claim about native durable writes.

`check_resource_writer.py` compiles the fixture with ASan/UBSan and compares its
output with the independent Python fork reader. Tests cover a 100,003-byte body,
non-ASCII/embedded-NUL and empty/absent names, interleaved input types, an empty
fork, duplicate keys, source/count/offset/name overflows, short reads/writes and
injected failure at every write boundary, source read, begin and commit. The
original target remains exact in every failure case. The Python reader now
recognizes the canonical `$FFFF` zero-type count for empty forks.

The original-file round trip passed all 212 entries, every name/attribute and
all 1,418,832 payload bytes (212 bounded source reads). The full host suite and a
clean 68020 build passed, including no-float/probe link audits. Explicit volatile
byte-copy destinations avoid the known GCC copy defect; the target object audit
found no shared-base postincrement byte-copy instruction. No native runtime
behavior changed; the helper is not connected to resource-file traps yet.
F2b must supply mutable independent maps and stable identity before f3 binds
this writer to staging streams and verifies the Mac/native resource-file calls.


### Mutable resource metadata directory (M2.2f2b)

`ResourceDirectory` owns up to 16 independent maps and 768 resource metadata
records. Payload sources stay caller-owned. Opening reads only the header, map
and length words; it publishes the new fork only after validation succeeds.
Each fork has a reference, open order, write permission and dirty state. Newest/
older traversal supplies the measured chain order without owning current-file
selection. Identical type/ID pairs in the same or different forks have separate
identities; ID lookup selects the earliest surviving insertion.

Resource identities are monotonic and never reused, including after close/clear;
removed slots may be reused without reviving stale identities. Within each fork,
entry insertion order remains stable. Add/replace deep-copy names, retain source
ranges and preflight the complete candidate serialization through the writer's
allocation-free `measure` operation. Failed range/capacity/name limits or
read-only mutations leave the prior directory intact. Replacement
preserves identity; removal invalidates it. Reads remain bounded to 64 KiB.
These are portable model results; native trap error translation remains f3.

Serialization uses the existing staging sink and deliberately retains dirty
state and old sources. `rebase` validates a newly published map's canonical
ordering, keys, names, sizes and attributes before switching all source ranges
and clearing dirty. It retains identities and publishes nothing on parse/read or
metadata mismatch. The caller must retain old readable sources until rebase
succeeds, and owns file closure/publication. Native persistence is not yet wired.

`check_resource_directory.py` tests metadata-only opens/rebases, duplicate IDs
within and across forks, source reads, copied names, stable order/identity,
change/remove/add, read-only and range rejection, failed writes/opens/rebases, close/reopen
and slot reuse, all 16 fork slots and the 768-resource capacity. ASan/UBSan and an
independent reader verify the changed 70,001-byte resource and added/removed
entries. An original-fork run opens and rebases all 212 entries using exactly 214
metadata reads each, retains every identity, and streams an independently exact
round trip of all metadata/payloads. No original bodies are read while opening.

Acceptance: both independent round trips and all host tests passed. A clean
68020 build passed no-float/probe audits. The directory and writer target objects
contain no shared-base postincrement byte-copy instruction. This change supplies
portable helpers; f3 must connect them to native streams, resource handles and
the 63-call Mac resource-file fixture before that API scope is accepted.


### Native directory-backed original resources (M2.2f3a)

ResourceForks now delegates map ownership and source reads to ResourceDirectory.
Its existing Item/index interface maps each native resource-handle slot to the
stable directory identity. The preparation path and all current Toolbox readers
therefore exercise the new directory on the 68020, while preserving resource
order, source callbacks and existing cached-handle indices. Resident compatibility
remains only for host fixtures. Dynamic open/create/write traps remain pending.

The production resource-read observer additionally requires an active read-only,
clean directory map and matching nonzero identities/sizes for all 212 cached
metadata entries. Every retained Item payload pointer is still null. Preparation
remains 228 reads / 201,058 bytes; startup remains 16 resource reads / 96,648
bytes and 23 balanced user services before GetFNum Dan1+$0012.

Acceptance: full host suite, file-write's 110 resource calls, file-read,
window-core, boot, resource-read and all four startup observers passed with normal
exits. All 75,616 A5 globals match. Source opening/error/short-read tests now link
and exercise the same directory/writer implementation used by the native loader.
No owner decision changed; rendered-picture verification remains deferred.



### Native staged resource writes (M2.2f3b)

`ResourceStage` supplies the writer's explicit-lifetime DOS sink. It creates a
separate `.aitd-new` file, writes sequential chunks of at most 64 KiB, then
flushes/closes it before publication. An existing target moves to `.aitd-old`;
publication replaces it and removes the backup. Publication or backup-removal
failure rolls back to the previous target. A failed rollback/abort returns the
explicit recovery-required error (-32760), retains evidence and prevents reuse.
Existing staging/backup names are rejected without touching them. Callers must
close target streams before publication; dynamic resource traps and directory
rebase remain M2.2f3c. This is operation-failure rollback, not a power-loss guarantee.

The sink callbacks require the active user-service bridge. File-write stage 55
uses diagnostic-only trap A0FA to exercise that same bridge and OS-window guard.
The nine cases cover new/replacement publication, explicit/incomplete abort,
injected publication and backup-cleanup failure with different replacement
bytes, stale temporary/backup preservation, and payload-source failure. Native
readback verifies the entire 70,003-byte payload (FNV `$A04280DF`) and resource
metadata. Independent host parsing checks both 70,314-byte output forks, all
payload bytes, no transaction leftovers and unchanged stale-file sentinels.
The stage uses 56 windows; the combined probe requires 443, with prior File
Manager transfer/cleanup totals and 110 resource-call checks unchanged.

ResourceWriter now propagates abort failure instead of hiding it behind the
initial write error. Its sanitizer fixture verifies the recovery error and
preserved target/staging evidence. No original game instructions are patched.

Acceptance: full host suite, all five 68020 regressions and catalog, original
startup, identity and low-memory observers pass with normal exits. The target
copy audit is clean. A5 globals have zero mismatches across 75,616 bytes.
Production startup remains at GetFNum Dan1+$0012 with unchanged resource I/O.
No owner decision is needed; rendered-picture acceptance remains deferred.


### Dynamic resource index remapping (M2.2f3c1)

The ResourceForks view now supports the directory's 16 fork keys. Its mutation
interface exposes the owned directory and an explicit refresh step. Refresh
rebuilds the dense resource index in map-open order and per-map reference order;
search still belongs to the measured current-to-older traversal. It returns an
old-index-to-new-index mapping based only on stable resource identity. Removed
identities map to -1. New/reopened resources cannot inherit a prior association,
even when directory slots or type/ID pairs are reused. Refreshed bodies remain
source-backed, with null resident compatibility pointers.

The caller must refresh after a directory mutation and apply the mapping to
cached handles before indexed access. Native trap integration and disposal of
removed handles remain M2.2f3c2; existing runtime calls have not been enabled or
made to claim success. The sanitizer source fixture covers add, replace, remove,
close, reopen, duplicate keys across files, nonnumeric open order, all 16 maps,
clear/reopen, identity invalidation and exact changed payload reads.

Acceptance: full host suite and the expanded ASan/UBSan source fixture pass.
All five native 68020 regressions and four startup observers exit normally with
unchanged counts and GetFNum boundary. The generated resource-view copy audit
is clean; all 75,616 captured A5 bytes match. No owner decision changed.


### Dynamic resource-file services (M2.2f3c2)

Resource-file open/create/update/close and AddResource now use the File Manager
catalog and persistent streams. ResourceFiles.inc owns that integration within
MacLoader. Maps stay metadata-only, added bodies read from their associated
handles, and resource view refresh remaps all handles by stable identity.
GetResource/GetNamedResource traverse current then older maps without wrapping
into newer maps. CountResources counts every open map, including duplicate IDs,
regardless of current selection. UseResFile returns the measured D0/error state.

Update serializes through ResourceStage while old sources remain readable,
closes the target stream only at publication, then reopens it. Successful writes
reset the sparse data view, validate/rebase directory offsets without changing
identity, and update catalog size and Finder metadata. Closing updates first,
then disposes the closed map's handles and selects the next older map when
necessary. Reopening an already open file returns its existing reference.

The native ResourceFileProbe extends the 63-call reference sequence with the
measured dirty-noncurrent-close and invalid-update contracts, using only
named scratch files under Alone Saved Games. It checks errors, D0, Pascal stack
cleanup, current refs, six independent handles, search identity and exact bytes,
including reopen. Its STR# chain count uses the measured +2 delta to the native
baseline; no unused Apple System resources are fabricated. The debugger invokes
an independent host reader before deletion to verify all six persisted payloads,
General names, attributes, order, empty data forks and absent staging leftovers.
Final host checks require both files and companions deleted.

This measured scope covers default/explicit read-write opens and creating maps
in already-created files. Other permissions/errors, creating absent files and
dirty-handle disposal still need paired coverage. ChangedResource, WriteResource
and RmveResource are now covered by M2.2f4b3b2 below. Unsupported forms stop by
trap name. Unmeasured dirty-handle operations and dirty exit still stop explicitly. Application-file
closure and mixed raw-stream/resource updates remain unmeasured loud stops.

The 64-call fixture adds 78 windows and 24 disk reads / 590 bytes. Combined
file-write acceptance is 174 paired calls, nine staging cases, 521 windows and
57 File Manager reads / 867,323 bytes (maximum 65,536). File Manager write,
flush and restored-close totals remain 24 / 18 / 2; ResourceStage writes are
separately covered by staging/independent disk checks. Production startup retains
212 resources, 16 runtime resource reads / 96,648 bytes and 23 balanced services
before GetFNum Dan1+$0012. Other writable variants are ordered as M2.2f4.

Acceptance: the original-byte/reference checker, full host suite, all five
68020 regression cases and four startup observers pass with normal exits.
The final file-write rerun includes the explicit pending-variant guards and
independent six-resource disk check. A5 globals match all 75,616 bytes. The
resource integration copy audit and clean production no-float/probe audits
pass. No owner decision changed; actual rendered-video verification remains
owner-deferred.


### Writable resource mutation reference (M2.2f4a1)

The CPU-only `mac_resource_writes.lua` fixture exclusively creates one scratch
file and performs 50 calls at the byte-checked Engine+$3CDC gate. Its checker
also validates Gloss+$08AC, +$0906, +$090A, +$09CE and +$09D4 original mutation
instruction pairs. The final MAME run exits normally, deletes the scratch file,
and restores the application current resource file. No original assets change.

Measured contract:
- AddResource accepts two resources with identical type/ID in the same file.
  Both survive UpdateResFile, close and reopen. Get1IndResource returns them in
  insertion order; Get1Resource selects the first. Removing that first handle
  leaves the other resource under the same ID. This contradicts the portable
  earlier map/writer duplicate-rejection assumption; M2.2f4b1 corrects the model.
- AddResource and ChangedResource set attribute bit `$02`; WriteResource clears
  it. GetResAttrs preserves D0 and MemErr. WriteResource without ChangedResource
  succeeds but does not persist a changed body: resident `CCCC` reopens as the
  previously written `BBBB`.
- RmveResource clears the resource handle flag but preserves its four-byte body
  and master pointer. Readding that handle as ID 129 succeeds and persists `BBBB`;
  the duplicate at ID 128 still contains `DDDD` after reopen.
- Nil AddResource returns -194 (`$FF3E`) and clears MemErr. Nil/removed
  ChangedResource and WriteResource return -192 (`$FF40`) while preserving seeded
  MemErr. Nil/repeated RmveResource returns -196 (`$FF3C`). Those calls put the
  zero-extended ResErr in D0. GetResAttrs on the removed handle returns zero with
  -192 while preserving D0/MemErr. Invalid UpdateResFile returns -193 while
  preserving D0/MemErr.
- Successful mutations clear ResErr, MemErr and D0; UpdateResFile preserves D0.
  Cached lookup of the already loaded first duplicate preserves seeded MemErr,
  while lookup that loads its body clears MemErr. The checker distinguishes
  these states and checks stack cleanup, independent handles and resource flags.

The checker passes the actual capture and rejects timeout, missing completion,
and corrupted attribute, duplicate-count, body, handle-flag, error and register
records. This is Mac reference evidence; native mutation/dirty-attribute support
is still pending. Remaining permission and dirty-lifecycle reference cases are
M2.2f4a2, before native integration resumes.

The full host suite passes. No native runtime code changed in this reference
checkpoint; existing native regression results remain the ab2a3ff baseline.
No owner decision is needed.


### Resource permissions and creation reference (M2.2f4a2a)

`mac_resource_permissions.lua` exclusively creates one scratch name, proves
ownership before deleting/recreating it, and captures 59 CPU-only calls. The
final headless MAME run exits zero and deletes/unlocks the scratch file. The
checker validates the Engine gate plus Core+$46F2/$4780/$4830/$48BE original
call pairs, seeded registers/errors, stack, handles and exact reopened bytes.

Measured contract:
- CreateResFile creates an absent file/map. Repeating it on an existing valid
  map returns -48, leaves D0=4 and preserves MemErr; its resource stays intact.
  The earlier resource-file fixture separately covers an existing data file
  with no map. An empty resource fork and a 16-byte all-zero header both fail
  OpenRFPerm with -39 and reference -1. The raw write's actual count is 16;
  this does not establish a universal error for every malformed layout.
- OpenRFPerm permissions 0–4 all open an unlocked file and read the exact
  four-byte `ABCD` resource. On a locked file, permissions 0/1 still open/read;
  2/3/4 return -54 and reference -1, with zero-extended D0 and cleared MemErr.
- On a read-only open, ChangedResource returns -61 without setting the changed
  attribute. WriteResource then succeeds without writing the modified resident
  `EFGH` bytes. AddResource returns -61 and leaves the resource count at one.
- RmveResource on that read-only map succeeds in memory, clears the resource
  flag and preserves the handle/body. UpdateResFile then returns -61 while
  preserving D0/MemErr. CloseResFile also returns -61 but **does close the file**:
  CurResFile is the application afterward. Reopening retrieves original `ABCD`;
  the failed added ID is absent. The detached body still exists independently.
  Native implementation must separate in-memory map mutation from disk write
  permission and must not retain a read-only file just because its update fails.

The strict checker rejects ten timeout/incomplete/corrupted evidence cases,
including bad lock errors, malformed-header write count, read-only count/body/
attributes, current-file restoration, close error and stack cleanup. Native
permission and mutation behavior is still queued in M2.2f4b. Dirty lifecycle
and exit reference coverage remains M2.2f4a2b. No original assets change and no
owner decision is needed.

The full host suite passes. This checkpoint changes reference tooling only;
native runtime regression evidence remains the ab2a3ff baseline.


### Dirty resource lifecycle and exit reference (M2.2f4a2b)

The scratch-only `mac_resource_dirty.lua` capture completes 45 calls and deletes
both exclusively created files. Two bounded CPU-only MAME runs exit zero with
identical results. `check_resource_dirty.py` checks stage order, seeded D0,
ResErr/MemErr, Pascal stack cleanup, live handle identity, flags and exact bytes.
It deliberately does not interpret stale master pointers after a file closes.

- ReleaseResource leaves a dirty handle resident and associated, with attribute
  bit 2 set; it preserves seeded D0/MemErr. Lookup returns that same body/handle.
- DetachResource on the dirty handle returns -198 (`$FF3A`), preserves MemErr,
  and leaves the body/association intact. After WriteResource it detaches
  successfully, clears the resource flag and preserves the body. A later lookup
  creates an independent resource handle containing the written `CCCC` bytes.
- EmptyHandle discards dirty `DDDD`; LoadResource retrieves the previously written
  `CCCC` under the same handle. The captured full GetResAttrs word is `$E002`
  while empty and `$0600` after reload in both runs. These upper bits are recorded,
  not interpreted as portable resource attribute bits; the trace/poison check
  below establishes their uninitialized origin. UpdateResFile then preserves MemErr.
- Closing a current dirty map persists `EEEE`. Closing either a clean or dirty
  noncurrent map preserves the application current file. Reopening the dirty
  noncurrent map retrieves its exact `FFFF` resource, then both files are deleted.

`mac_resource_exit.lua` adds 13 calls around a real Mac application exit. It
checks the Engine+$3CDC gate and all original CODE 1+$0048 main-return and
+$04AA trap-unpatch bytes, exclusively creates a resource containing `EXIT`,
and leaves it dirty/open. It enters that original return path to restore the
runtime's trap patches and call the OS ExitToShell, avoiding game preference
cleanup. Finder is positively observed, then a fresh application launch opens
and reads the exact resource before closing/deleting the scratch file. This
proves OS-exit persistence, not game quit-path or reset/power-loss durability.
The run exits zero; `check_resource_exit.py` requires both launch byte guards,
ordered exit/Finder/reopen evidence, exact body, registers, stack and cleanup.

Both checkers reject a combined 16 timeout, incomplete and corrupted captures.
The full host suite passes. Native runtime code is unchanged, so its five
regressions/four startup observers remain at the ab2a3ff baseline. Native variants
continue in M2.2f4b; application-file closure and mixed raw/resource updates stay
named stops until measured. No owner decision changed.


### Same-file duplicate model correction (M2.2f4b1)

ResourceMap and ResourceWriter now accept repeated type/ID keys within one type
reference list, as measured by the 50-call Mac mutation fixture. Each duplicate
retains its own name, attributes, payload range and insertion position. Existing
range, capacity, overlapping-reference and duplicate-type-block checks remain.
ResourceDirectory selects the lowest surviving insertion identity for ID lookup,
so removing an older entry and reusing its physical slot cannot move a new
entry ahead of an existing duplicate. Rebase retains each entry's identity.

ASan/UBSan fixtures cover parser order, independent duplicate payloads/names,
writer round trips through an independent Python reader, directory remove/add/
replace/rebase/reopen, and native ResourceForks handle-index remapping. Metadata
operations and lookup read no resource bodies. The directory fixture reopens
and rebases the two duplicates using exactly four metadata reads each. The
original-fork checks retain all 212 entries and 1,418,832 payload bytes exactly.

The full host suite, all five native 68020 regressions and all four startup
observers pass with normal exits. File-write retains 173 paired calls, nine
staging cases and 521 windows; resource-read retains 16 runtime reads / 96,648
bytes. All 75,616 A5 bytes match, and the three changed resource-model objects
pass the generated copy audit. Production startup still stops at GetFNum;
remaining resource mutation/permission/lifecycle traps are M2.2f4b. No owner
decision changed; rendered-video verification remains owner-deferred.


### GetResAttrs upper-byte diagnosis (M2.2f4b prerequisite)

Instruction traces of the empty/reloaded dirty-handle calls show the System
7.5.5 wrapper at `$41768` reserving an uninitialized result word. The ROM at
`$408134A0` writes only the low attribute byte (`MOVE.B 4(A2),13(A6)`). The
wrapper copies the entire word back to its caller, exposing old stack contents
as the high byte. The observed `$E002`/`$0600` are not portable attributes.

`AITD_RESOURCE_ATTR_POISON=1` enables two guarded diagnostic breakpoints in
`mac_resource_dirty.lua`. They verify the wrapper/ROM instruction bytes before
setting the internal result's high byte to `$5A` and `$A5`. The full 45-call
fixture returns `$5A02` and `$A500`, with unchanged low attributes, errors,
registers, bodies, close/readback and scratch cleanup. The bounded MAME run exits
zero and `check_resource_dirty.py --poison` passes. The unpoisoned traced run
also exits zero and passes its checker. Native GetResAttrs should zero-extend
the defined attribute byte; it must not reproduce stack garbage. No game
instructions or original files change, and no owner decision is needed.


### Noncurrent resource close and invalid update (M2.2f4b2)

The resource-file dispatcher now allows closing a noncurrent map and returns
-193 for an invalid UpdateResFile reference, preserving D0. Existing closure
updates the requested map, closes its stream and disposes its associated handles;
it changes current selection only when that map was current. Application closure
and unmeasured raw/resource-stream mixing remain explicit stops.

The native fixture now leaves B's three added resources dirty until close while
the application is current. It checks current-file selection after closing B,
a repeated invalid close, and closing clean noncurrent A; resource lookup still
selects the original application's General resource. The independent disk reader
checks all six exact A/B bodies, names/IDs/order and empty data forks before
scratch deletion. A new 64th call checks invalid update's error, D0 and Pascal
stack cleanup. The fixture composes the original 63-call file-reference contract
with the dirty-close and mutation-error reference captures; those checkers also
revalidate original call bytes. Total file-write coverage is 174 calls, nine
staging cases and unchanged 521 windows / 57 reads / 867,323 bytes.

Before implementing WriteResource via the whole-map publisher, M2.2f4b3a must
establish the isolation of one resource write from another dirty resource.
That dependency is explicit rather than assuming UpdateResFile is equivalent.

Acceptance: both Mac reference checkers pass, the full host suite and all five
68020 regressions exit normally, and all four startup observers pass. All
75,616 A5 bytes match. Production resource reads remain 16 / 96,648 bytes before
GetFNum Dan1+$0012; no original instructions changed. No owner decision is
needed. Rendered-video acceptance is still owner-deferred.


### WriteResource isolation reference (M2.2f4b3a)

`mac_resource_isolation.lua` exclusively creates one scratch file with two
resources, then completes 40 calls with original Engine gate guards. Both
resources are dirtied; WriteResource(A) clears only A's changed flag. B remains
dirty. Empty/reload retrieves A's written `CCCC`, but retrieves B's old `BBBB`
instead of its discarded dirty `DDDD`. Update/close/reopen retains those exact
bodies. The second phase changes both resources again, writes B, proves A still
dirty, and reloads B as written `FFFF`. UpdateResFile then writes A's remaining
`EEEE`; both exact bodies survive close/reopen. The scratch file is deleted and
the application current file restored. The bounded CPU-only MAME run exits zero.

The strict checker verifies ordered calls, errors, D0/MemErr, stack, independent
live handle identities, defined attribute bytes, exact bodies and cleanup. It
also checks original Gloss ChangedResource/WriteResource instruction pairs.
Undefined GetResAttrs upper-byte scratch is intentionally excluded, following
the guarded trace/poison diagnosis. Ten incomplete/corrupted captures are rejected.

This establishes that a whole-map update cannot stand in for WriteResource:
unselected dirty bodies must keep their saved source until explicitly written,
while UpdateResFile writes all remaining changes. Selective source-backed
publication and native integration are M2.2f4b3b. Native runtime is unchanged;
its regression baseline remains abbbf61. No owner decision is needed.

The full host suite passes for this reference-tooling checkpoint.


### Selective resource publication model (M2.2f4b3b1)

ResourceDirectory serialization and rebase accept an optional per-identity
payload selector. It can substitute only a body's source, offset and size;
keys, names, attributes and ordering stay unchanged. Selection occurs on a
publication recipe, leaving live metadata and saved sources intact until
successful rebase. Unselected resources stream from their existing saved source.
Rebase validates metadata against that same selection and switches all offsets
while preserving identities. The caller must keep selection and sources stable
through both calls. Calls without a selector retain their prior behavior.

The ASan/UBSan fixture writes A as 70,001 `C` bytes while B remains saved `BBBB`,
then writes B as three `D` bytes while A stays unchanged. An independent Python
reader checks both complete forks, including names, IDs, attributes and order.
Changing the old resident A buffer afterward does not change its saved/reloaded
body. Opens and rebases use four metadata-only reads; body transfers are bounded
to 64 KiB. No pending resource body is copied into retained staging memory.

The fixture rejects selector errors and invalid ranges before staging starts,
and injects failures at every write boundary plus source reads and publication.
Failed serialization keeps the prior target and live metadata intact; failed
rebase and mismatched selection preserve the original metadata/source bindings.
The full host suite and all 212 original resources pass, including exact
original-fork serialization and stable-identity metadata-only rebase. Native
mutation dispatch is the next component, M2.2f4b3b2.

Acceptance: all five native 68020 regressions and four startup observers pass
with normal exits. File-write retains 174 calls / nine staging cases / 521
windows; startup resource reads remain 16 / 96,648 bytes before GetFNum. All
75,616 A5 bytes match, and the changed directory object passes the generated
copy audit. No owner decision changed. This commits the independent publication
model; the native traps remain explicit stops until their integration fixture.


### Native resource mutations and isolation (M2.2f4b3b2)

The loader tracks per-entry dirty/never-published state alongside handles, remapped
by stable identity. ChangedResource marks a resident body without replacing the
saved source. WriteResource selects only that body's handle source for staged
publication; UpdateResFile selects every remaining dirty body. Successful rebase
switches saved offsets and clears only published state. Empty/reload of an
already saved dirty resource reads its old source and discards the pending change.
Map-change bookkeeping remains separate from body dirtiness, preserving the
measured MemErr difference between an initial-map update and a clean update.

AddResource sets the changed attribute. GetResAttrs zero-extends the defined
attribute byte and preserves D0/MemErr; removed handles return zero/-192.
RmveResource invalidates the resource identity and clears its handle association
without freeing the caller's body, allowing re-add under another ID. Nil/add and
nil/removed change/write/remove errors use the measured results. Clean writes
without ChangedResource do not publish resident edits. Dirty release preserves
the handle; dirty detach returns -198 without changing it. Unmeasured operations
retain named stops, including empty/reload of never-published handles.

The native fixture runs the 50-call mutation and 40-call isolation contracts,
checking exact error/register/stack results, defined attributes, body bytes,
independent duplicate handles and first-duplicate lookup. Two injected publication
failures (publish rename and backup cleanup) retain the dirty handle and exact
old empty fork, verified independently before a successful retry. Independent
readers also check the final mutation fork (duplicate ID 128 `DDDD`, re-added ID
129 `BBBB`) and isolation fork (`EEEE`/`FFFF`), names, attributes, reference order,
empty data forks and absent transaction leftovers. Final acceptance requires
both scratch files and companions deleted.

Three additional native calls check dirty ReleaseResource, rejected dirty
DetachResource and retained changed attributes against the dirty-lifecycle Mac
capture. All preserve the handle/body and measured D0/MemErr. Combined acceptance
is 267 paired resource calls, nine existing staging cases and two mutation
rollback cases. The mutation fixture adds 206 windows; complete file-write totals
are 727 windows and 132 File Manager reads / 868,833 bytes, maximum 65,536.

Validation: original-byte/reference checkers, full host suite, all five native
68020 regressions and all four startup observers pass with normal exits. The
final file-write rerun includes direct dirty release/detach checks and both
independent rollback/final-fork readers. All 75,616 A5 bytes match; production
still stops at GetFNum after 16 resource reads / 96,648 bytes. A clean production
build restores the non-probe executable with no-float/probe audits passing.
No owner decision changed; rendered-video acceptance remains owner-deferred.

The final MacLoader object has no shared-base postincrement byte-copy occurrences.
The queued QuickDraw pattern dump remains necessary before accepting M2.3a.


### Pending resource-map write reference (M2.2f4b3c1)

`mac_resource_map_edits.lua` and `check_resource_map_edits.py` establish 44
ordered calls using an exclusively created scratch file. WriteResource(A)
succeeds while B has never been published: A reloads as `AAAA`, while B remains
resident `BBBB` with its changed flag. After removing B, updating and reopening,
A remains exact and B is absent. The second phase publishes both, removes B,
changes A to `CCCC` and writes A while removal is pending. A reloads exactly;
B stays absent before and after update/close/reopen. Both detached B handles
are explicitly disposed, the scratch file is deleted and the application
current resource file is restored. Original Engine and Gloss call bytes match.

Empty/reload of never-published B is **not** a valid saved-body contract.
The observed LoadResource returns -39, clears its changed flag and leaves a
resident resource handle. Guarded ROM instruction and I/O probes explain why:
the first read takes four bytes at fork offset $014E as length $6974, then
ReallocHandle allocates that amount. The body read at $0152 transfers only four
bytes and returns EOF. An independent scratch-fork dump finds `00006974` there,
beyond the old empty map; these are unrelated residual bytes, not B's body or
length. The on-disk header still describes the old empty map after the selected
write. Do not reproduce this accidental allocation size or failed-read bytes.
The native unpublished-empty/reload loud stop remains queued under M2.2f4b5.
`AITD_RESOURCE_MAP_DIAGNOSTICS=1` enables byte-guarded read/allocation logging
for this call without changing the 44-call sequence.

The checker validates errors, D0/MemErr, stack cleanup, stable live handles,
defined low attribute bytes, valid bodies, removals, reopen and final cleanup.
It deliberately excludes failed-read body/size values. Three bounded headless
captures exit zero and pass; ten corrupt/incomplete/timeout variants are
rejected. The separate raw scratch-fork diagnostic also completes with cleanup
and exit zero. The full host suite passes. This reference-only checkpoint
leaves native runtime and its e81915f regression baseline unchanged; native
integration is M2.2f4b3c2. No owner decision changes.


### Native writes amid pending map edits (M2.2f4b3c2)

ResourceDirectory publication can omit an entry from the saved map while keeping
its live identity, metadata and independent source. Rebase retains those entries,
owns any name previously borrowed from the old map, and keeps the directory dirty.
Validation and required name allocations happen before live metadata changes.
WriteResource uses this only for other never-published resources: their resident
bodies are neither read nor saved. A later UpdateResFile publishes them normally.
A pending removal is included in the selected write; the following clean update
preserves MemErr as measured. Newly written additions retain the separate map-work
flag used by the previously measured update contract.

`AITD_RESOURCE_MAP_VALID=1` selects the 37-call valid reference path; the checker
requires `--valid`. It verifies writing A while B is unpublished, A's exact reload,
B's unchanged resident bytes/dirty flag, explicit update followed by B's exact
reload, both resources after reopening, then removal of B and another write/reload
of A. The reference exits zero, restores current-file state and deletes its scratch
file. Both reference modes pass, and ten corrupted/timeout valid-mode captures
are rejected. The undefined unpublished empty/reload case remains a named stop
under M2.2f4b5; its accidental bytes/allocation are not emulated.

The native fixture matches all 37 calls, including errors, MemErr, D0, stack,
handle states and exact bytes. Four new injected failures cover publish rename
and backup removal while a peer is unpublished and while a removal is pending.
Each preserves live dirty state and the previous fork. Independent readers verify
the empty/both-resource rollback targets, the selected-only fork, later both-resource
publication and final single-resource fork, with no transaction leftovers and
complete scratch cleanup. Combined native coverage is 304 paired resource calls,
six mutation rollback cases and nine staging cases; file-write uses 837 windows
and 160 File Manager reads / 869,391 bytes, at most 65,536 per transfer.

The sanitizer fixture verifies omitted bodies are not read, metadata/source identity
survives rebase, later publication/removal is exact, and failed selection/staging/
rebase keeps live state intact. The full host suite passes. The expanded native
fixture exceeded its old 60-second limit; that run failed and was not accepted.
File-write now has a 120-second bound, with all other regression bounds unchanged.
All five native 68020 regressions and all four startup observers pass with normal
exits. All 75,616 A5 bytes match. Production still reaches GetFNum after the same
16 resource reads / 96,648 bytes. Final production link/no-float/probe audits pass;
MacLoader and ResourceDirectory objects have no shared-base postincrement byte
copies. No owner decision changed; rendered-video acceptance remains deferred.


### Native resource permissions and creation (M2.2f4b4)

Resource-file opens now use the File Manager's measured permissions 0–4,
including locked-file read/default opens and rejected locked writes. Resource
metadata and bodies still use direct bounded reads on read-only streams, without
filling the data-fork read cache. CreateResFile creates an absent catalog/data file
before initializing its resource map; an existing valid resource fork returns
-48 and stays intact. Empty forks and the measured 16-byte zero malformed header
return -39 with a failed reference and closed stream. Other malformed layouts,
creation over malformed content, application closure and mixed raw/resource
writes retain their existing loud stops.

ChangedResource and AddResource reject read-only maps with -61 and the measured
MemErr/D0 results. A clean WriteResource remains successful without persisting
resident edits. RmveResource works in memory, detaches the handle and leaves its
body owned by the caller. UpdateResFile then reports -61; CloseResFile reports
the same error but closes the read-only map/stream and restores current-file
selection. Writable publication failures retain their previous close behavior.
The portable directory rejects serialization of a read-only map even after its
in-memory removal; its host fixture verifies the original source remains intact.

The native 59-step fixture follows the Mac capture with exact errors, registers,
stack, attributes, live bodies and reopen checks. Its two lock/unlock setup steps
use native DOS protection through the existing system-window/diagnostic-service
pattern; they do not implement Mac SetFLock/RstFLock game traps. The other 57 calls
are paired traps, bringing combined coverage to 361 calls. Detached and rejected-add
handles are disposed explicitly after the fixture. Three independent disk checks
prove the original `ABCD` resource, name, ID, attributes, empty data fork and absent
transaction leftovers survive create-existing and read-only errors. The scratch
file and companions must be deleted before acceptance.

The permissions fixture adds 107 windows. Complete file-write totals are 944
windows, 207 reads / 870,393 bytes, 25 writes / 470,085 bytes, 19 flushes and two
restored closes; transfers remain at most 65,536 bytes. All six prior mutation
rollback cases and nine staging cases remain required. The original-byte/reference
checker and full host suite pass. All five native 68020 regressions and four
startup observers exit normally and pass. The final file-write rerun also verifies
the guard that limits close-after-permission-error to read-only files. All 75,616
A5 bytes match; production remains at GetFNum after 16 resource reads / 96,648 bytes.
MacLoader/ResourceDirectory generated-copy audits and the restored clean production
build's no-float/probe audits pass. No owner decision changed.


### Complete native dirty lifecycle fixture (M2.2f4b5a)

The independent lifecycle portion now has all 45 Mac-reference calls in one native
fixture: dirty release preserves association/body; dirty detach returns -198;
write followed by detach keeps the caller's body and allows a distinct fresh
resource handle. Empty/reload discards a saved resource's dirty resident edit and
restores its old saved bytes, clearing its changed flag. Dirty current close
persists `EEEE`; dirty noncurrent close persists `FFFF` while leaving the
application selected. Every call checks errors, MemErr, D0 and stack cleanup;
body/handle-state and identity checks cover the live transitions. GetResAttrs
continues to compare only its defined low byte.

An independent parser verifies both closed forks before deletion: exact LIFE 128
bodies, Scratch names, zero attributes, empty data forks and no staging remnants.
Final acceptance requires both scratch files/companions deleted. The fixture adds
96 windows and 45 paired calls: combined file-write coverage is 406 paired calls,
59 permission steps, six mutation rollback cases and nine staging cases. It uses
1,040 windows and 237 File Manager reads / 871,061 bytes; write/flush totals remain
25 / 470,085 bytes / 19. Existing runtime implementations pass the full contract
without another runtime change. Original-byte/reference and full host checks pass.
All five native 68020 regressions and four startup observers pass with normal
exits. All 75,616 A5 bytes match; production still reaches GetFNum after 16
resource reads / 96,648 bytes. Production link/probe/no-float and generated-copy
audits pass. No owner decision changed.

### M2.2f4b5b — dirty resource exit persistence

ExitToShell now enters the user-service bridge and closes/publishes dynamic maps
before switching back to the native host stack. The application source remains
open until restored-OS cleanup. Publication errors stop at `RESOURCE EXIT IO
ERROR`; application-map mutation remains unsupported.

`amiga/regression.sh resource-exit` runs three fresh 68020 processes. The failure
case injects a rename failure, requires ResErr -36, an active service and open
stream, and the exact resident `EXIT` body. The independently parsed disk fork
must remain empty, with no staging remnants, before owned scratch cleanup is
allowed. The successful case leaves LIFE 128 (`Scratch`, body `EXIT`) dirty and
open, then returns through original CODE 1+$48, its unpatch routine at +$4AA and
ExitToShell. A fresh launch reads back the same resource, closes and deletes it.
All thirteen calls retain the measured Mac error/register/stack/body contracts.

The diagnostic build temporarily redirects the guarded Core main entry to the
fixture and immediately restores all original bytes. FS-UAE's remote stub
silently ignores register and memory writes; byte readback established that the
observer cannot inject the call itself. Production contains no diagnostic hook.
Both the original source bytes and the live CODE 1 exit/unpatch bytes are checked;
the only expected difference is the established low-memory rewrite at +$48.
The original return address is verified on the stack before the fixture runs.

Positive exit evidence includes balanced user services, no remaining streams,
closed original source, restored Line-A/vector ownership, callbacks cleared,
multitasking enabled, matching DMA/interrupt/View state and all four Paula voices
zeroed. The observer then requires native main to return zero and positively
reaches the CRT's final return instruction. This proves original-runtime exit
persistence, not the game's menu quit path, Workbench startup or reset/power-loss
durability. Every breakpoint is a positive address check; a timeout is a failure.
The host checker rejects missing statuses, duplicate/incomplete/wrong-phase logs,
unexpected stops and timeout records, and refuses pre-existing scratch files.

Unpublished empty/reload and dirty resize/dispose/purge remain named stops until
required by original execution. Writable prefs/save and overlay integration are
next (M2.2g); no owner decision changed.

Acceptance: all six native regression cases and the four startup observers pass
with normal completion, as does the full host suite. The final production build
passes link/probe/no-float checks; MacLoader and ResourceDirectory generated-copy
audits are clear. All 75,616 A5 bytes match. File-write remains at 406 paired
calls / 1,040 windows; original startup remains at GetFNum with 16 resource reads
/ 96,648 bytes. Both successful exit phases balance 11 user-service calls and
reach native main result zero and the final CRT return. No timeout is counted.

### M2.2g1 — source-backed port overlay foundation

`tools/build_overlay.py` deterministically generates the committed
`resources/overlay.rsrc`: an empty 286-byte classic resource fork containing no
original game data. `--check` verifies regeneration and independent parsing;
`make host-tests` requires it. Fonts and measured dialog layouts remain at their
planned milestones. The narrow Git exception applies only to this port-owned
fork; original resource forks remain ignored.

`ResourceForks::openWithOverlay` opens the overlay at reserved key 15 before the
application at key 0. Both maps are read-only. Later dynamic maps precede the
application, whose older map is the overlay. Sanitized callback-backed fixtures
verify this ordering, no body reads during opening/traversal/remapping, exact
bounded overlay payload reads, rejection of overlay writes, and complete rollback
if either source fails. The generated empty map takes two reads / 46 bytes and
adds no resources to the application view. Existing resource-source fixtures
continue to pass. This independent foundation does not yet wire the overlay into
native startup; M2.2g2 retains that and writable prefs/save path acceptance.
The full host suite and a clean production `resource-read` regression pass with
normal completion. Production still has 212 resources, 201,058 preparation bytes
and 16 runtime reads / 96,648 bytes, with the same GetFNum stop; the new API is
not yet selected by native startup.

### M2.2g2 — native overlay and writable paths

Startup opens the generated overlay read-only as a separate bounded source,
then its map before the application's map. The loader verifies the exact
application → overlay → end chain and leaves the application selected. The
empty overlay has Mac resource-file reference zero, consumes two metadata reads
/ 46 bytes, adds no resources and performs no runtime reads. Its DOS source is
closed during restored-OS cleanup; missing/invalid input and close errors fail
explicitly. Both ID and named searches use the shared tested order. DLOG, DITL
and ALRT search the overlay first under D5, while single-file lookups remain
local. No layouts or placeholder fonts have been invented for this step.

The native `resource-exit` regression now runs failure, original exit and fresh
readback/delete for both `Saved Games/Resource Exit` and `prefs/Resource Exit`.
Every process additionally selects System reference zero, verifies an empty CODE
count, and restores the original application selection. Disk parsing requires
exact LIFE 128 / Scratch / EXIT bytes and no staging leftovers; failures preserve
the old empty fork and live dirty body. Every phase checks both source closures,
service/window state and native main/CRT return. Location-tagged output prevents
a saves result from being accepted as preferences evidence. Two additional
processes require exact `OVERLAY UPDATE` / `OVERLAY CLOSE` stops for attempts to
update/close System reference zero, without creating scratch or closing either
source. Overlay resource mutations also remain a named stop until measured;
the port map is not exposed as a writable File Manager stream.

The same thirteen-call lifecycle also passes on the Mac in its actual blessed
folder, `7.5.5 2GB (D):System 7.5.5 (min):Preferences:`. The first attempt used the
wrong System folder name and returned dirNFErr; it was rejected. An HFS directory
inspection established the exact path before the successful bounded run.
`AITD_RESOURCE_EXIT_PATH` supplies the reference-only scratch path, and the
checker requires that path on both launches. The existing `Alone Prefs` is never
modified. This verifies the file/resource services, not the game's eventual
preferences format, screen-size choice or save/load UI.

M2.2's measured service and integration scope is complete. Unmeasured resource
variants remain named stops as listed in design §4.5. Original-file read
acceptance is next (M2.1c); the production startup stop remains GetFNum.

Acceptance: the full host suite, all six native regression cases and all four
startup observers pass with normal completion. Both explicit overlay-stop cases
also pass their exact reason checks; the final production build passes
resource-read, no-float/probe audits and the MacLoader/ResourceDirectory generated
copy audit. All 75,616 A5 bytes match. Original application preparation remains
228 reads / 201,058 bytes; the separate empty overlay adds 2 reads / 46 bytes.
Original runtime remains 16 resource reads / 96,648 bytes. File-write remains
406 paired calls / 1,040 windows. No timeout or failed exploratory run is counted;
rendered-window acceptance remains owner-deferred. No owner decision changed.

### M2.1c1b — installed data layout

The original installer places ListBod2.PAK in Alone Data. Extraction, staging and
reference population now reproduce this; see `install-original-data.md` for the
original installation evidence and `file-manager.md` for native acceptance.
Fresh/repeated extraction and staging preserve exact bytes and reject conflicting
legacy root copies. All six native 68020 cases, four startup observers and the
full host suite pass. Current catalog totals are 42 entries, 33 data files and
5,584,424 data bytes. File-write's corrected root enumeration uses 1,039 windows;
all other transfer totals remain unchanged. Startup still stops at GetFNum.


### Installed font lookup and native-driver boundary (M2.1c3 implementation)

The overlay now contains the port-owned Times FOND/NFNT. GetFNum loads and
validates the family and linked bitmap before returning its ID. The first
original Dan1 lookup returns 20 with the Mac stack/D0/error contract; both
resident resource bodies compare exactly with the generated source. Unsupported
font layouts/collation and text rendering retain named stops. The second
original lookup is still pending behind M2.1c3c; M2.1c3 is not complete.

Continuing startup exposed execution of the original MDRV and its `.BD_PAS16`
probe. That exploratory run is rejected under D8. Production now stops explicitly
at `NATIVE SOUND DRIVER` before loading any MDRV body. Original bytes identify
Core+$10E2's Jnth search before +$1102's MDRV fallback, +$1CC6's loader call and
+$1CF4's entry-pointer store. Native driver initialization is the next prerequisite.
No original code is patched by this change.

All six native 68020 regression cases, all four startup observers and the full
host suite pass with normal completion. Resource-read passes both fresh and
existing default-preference inputs: 53/27 OS windows and 43/42 or 35/34 service
entries/completions respectively, with one service active at the deliberate stop.
Original application preparation stays at 228 reads / 201,058 bytes. Overlay
preparation is four reads / 100 bytes. Runtime application reads are 20 / 104,340
bytes; font bodies add two / 1,314. File-write retains its 406 paired calls,
1,039 windows, six mutation rollback cases and nine staging cases.

The catalog observer now verifies one GetVol and all four original SetVol calls,
including the preferences selection and named restoration, against the Mac trace.
The identity observer includes the eighth `a/ux` query returning -5550/A0=0,
already measured in M0.2. The 75,616-byte A5 comparison has zero mismatches.
The clean production build passes no-float/probe audits (73 symbols). No timeout
or failed exploratory observer is counted as a pass; rendered-window verification
remains owner-deferred. No owner decision changed.

### Native-driver reference contract (M2.1c3c1)

The bounded original Mac probe now verifies both startup driver calls, their
arguments, resulting configuration, stack and D2–D7/A0–A6 preservation, then
positively reaches the second Times lookup (20). Its fresh 29,256-byte driver
dump matches the original unpacked body exactly. The checker rejects missing
calls, wrong state/registers, early or duplicate completion and nonzero/timeout
status. Reproduction and byte attribution are in `sound-driver.md`.

The complete host suite and fresh reference run pass with normal completion.
This independent measurement changes no native runtime; the prior native
regression results still describe the production stop before MDRV loading.
Native installation remains M2.1c3c2, preserving the full original acceptance
requirement. No owner decision changed.

### Native driver startup subset (M2.1c3c2a)

The original loader now installs the port-owned Jnth 11 entry without any game
patch. Native selectors 21/24 initialize voice/channel state and quality and
match both Mac return contracts, including thirteen preserved registers and
unchanged caller stack. The instruction cache is flushed after the loader's
MoveHHi. Other selectors/configurations remain named stops; MDRV is never
loaded. The next original stop is Engine+$2DEE `MENU MANAGER / COUNTMITEMS`.
The second Times lookup is still pending behind intervening services: its
attempt was rejected at that menu stop. M2.1c3c2 and M2.1c3 retain full integrated
acceptance; menu-record support is the next named prerequisite.

The complete host suite, six native regression cases, four startup observers,
first-font body comparison and both driver-call checks pass normally. Final
production passes the driver/font observers and both fresh/existing-preference
resource boundaries: 55/29 windows and 45/45 or 37/37 paired services. Overlay
preparation is 5 reads / 124 bytes; its three runtime bodies total 1,318 bytes.
Original application preparation remains 228 / 201,058; runtime is now 21 /
104,397 after loading MENU 128. All 75,616 A5 bytes match. File-write remains at
406 paired calls / 1,039 windows, with all rollback and staging cases passing.
Original preferences were preserved before the file-write fixture and restored
exactly after the final fresh-start check.

Final link/no-float/probe audits pass (76 probes). The generated-copy inspection
finds one shared-base postincrement byte copy in the existing initGraf patterns,
the already-queued M2.3a defect; ResourceDirectory has none. No new driver copy
uses that form. No timeout, failed second-font attempt or obsolete overlay-size
observer is counted as passing. Rendered-window acceptance remains owner-deferred;
no render/audio/full-startup acceptance or owner decision changed.

### Startup menu records (M2.1c3c2b)

CountMItems, GetMenuItemText and SetMenuItemText now operate on the actual packed
menu handles. The game still strips its own command suffixes. The bounded Mac
capture checks 33 calls; paired native execution checks 32, with identical game
labels, flags, item attributes and all twelve mutations. The one explicit
difference is the reference System-only Control Panels item, with no command
suffix/key; the native resource chain has no DRVR entries. The game registers
the same application commands. See `menu-manager.md` for byte guards and exact
comparison scope, including preserved registers and cached-dimension invalidation.

The host suite passes, including 510 sanitizer-checked replacements and malformed
record tests. Clean production boot/resource-read and all seven menu, driver,
font, catalog, startup, identity and low-memory observers pass normally. Fresh
and existing preferences use 58/32 OS windows and 48/48 or 40/40 paired services;
original preferences are restored afterward. Application runtime reads are now
24 / 104,667 bytes after all four MENU resources; preparation and overlay
transfer counts are unchanged. All 75,616 A5 bytes match. Link/no-float/probe
audits pass (76 symbols); generated byte-copy inspection finds only the already
queued M2.3a initGraf defect.

The menu checkpoint reached Core+$4B48 GetDeviceList. The logical device
selection below now passes, while integrated driver/font, graphics, PAK and intro
acceptance remain pending. Failed probe actions, missing-call captures and a
wrapped/truncated observer log were rejected before the paired pass. No timeout
or deferred rendered-window check is counted as passing; no owner decision changed.

## Graphics-device reference contract

M2.1c3c2c1's bounded original startup capture validates the four Core device
selection calls, 640×480×8 GDevice/PixMap fields, the 256-entry CLUT header,
HasDepth mode $83, the rectangle result and the original one-device selection
through the second Times lookup. The checker also rejects eight corrupted
captures; its incomplete-capture checks run in `make host-tests`. See
[graphics-device.md](graphics-device.md) for reproduction and exact scope.
The native implementation below uses this independently checked contract.

## Native logical graphics device

M2.1c3c2c2 supplies the real 640×480×8 buffer and consistent GDevice/PixMap,
monochrome screenBits/window-manager bitmap and region bounds. Original
GetDeviceList, HasDepth, OffsetRect and GetNextDevice pass paired Mac/native
checks, preserve their measured stack/register contract, and select one device.
The full 307,200-byte pixel buffer is dumped and checked; all relevant record
fields match the reference. The next named stop is Core+$0500 SetDepth,
PaletteDispatch selector $0A13. The palette is un-realized storage; eight-bit
drawing, palette use, GWorld construction and presentation stop explicitly.

Validation: clean production boot/resource-read, the device/menu/driver/font,
file-catalog/identity/original-startup/low-memory observers, full host suite and
both link audits pass. Menu records and both driver calls retain their paired
Mac results; the first Times result and installed font bytes still match. All
75,616 A5 globals match exactly. Existing preferences use 32 windows and 40/40
services. Fresh-preferences device selection also passes with 58 windows and
48/48 services; the original existing preference files were restored afterward.
Resource reads remain 24/104,667 original bytes and 3/1,318 overlay
bytes. No second Times, palette, rendered frame or full startup acceptance is
claimed. SetDepth remains first in the queue; M2.3/M2.4/M2.7 retain full graphics
acceptance. No owner decision changed.

## SetDepth startup

M2.1c3c2c3 implements the original already-active mode request: selected device,
depth 8, flags 1, values 1. Mac/native captures return zero OSErr with ten-byte
cleanup and preserve D3–D7/A2–A6. Complete device and PixMap records and the full
color table remain unchanged; all 307,200 native pixel bytes also remain
unchanged. Device/master/PixMap/backing identity is checked. Other SetDepth
requests retain the named stop. See [graphics-device.md](graphics-device.md).

Clean boot/resource-read, the SetDepth/device/menu/driver/font and catalog/
identity/original-startup/low-memory observers, the host suite and both link
audits pass. All 75,616 A5 globals match. The new stop is Dan2+$30E2 GetGWorld,
selector 5. Loading Dan2 adds CODE 13 (17,292 bytes) and CREL 13 (1,288 bytes):
26 runtime resource reads / 123,247 bytes in total. Existing preferences use
34 OS windows and 42/42 services. Fresh-preferences SetDepth also passes with
60 windows and 50/50 services; existing preferences were restored afterward.
Overlay reads stay 3 / 1,318 bytes. Dan2 changes
the loaded-segment mask to $3B8B but adds no low-memory sites: 58 validated,
55 applied. The observer's old mask was rejected, then updated from that
measured residency and the original site table; its live patch/tick checks pass.

The SetDepth checker initially required all of incoming D0 to equal $0A13.
Original bytes prove MOVE.W leaves its pointer-dependent upper half intact;
the checker now validates the selector word and tests this case explicitly.
The native handler already used the low word. Timeouts, incomplete captures,
wrong requests/results and duplicated positive records remain failures. Full
palette, offscreen/rendered graphics and the second Times lookup are pending;
no owner decision changed.

## Current-world startup query

M2.1c3c2c4 implements original Dan2+$30E2 GetGWorld. The reference/native pair
returns the current WMgrPort and main GDevice, pops eight bytes, and preserves
D0–D7/A2–A6. All portable bytes of the 108-byte port agree, and the query leaves
it unchanged. The reference revealed that WMgrPort's old-style bitmap has the
eight-bit device's base and 640-byte stride, while screenBits is an 80-byte
monochrome view over the same base. Native records now match, including
WMgrPort's default txSize=0; the redundant separate monochrome buffer is gone.
The live native observer proves both records use the device's real backing.

GetGWorld allocates no synthetic world and leaves current-port state intact.
The next request, GetNewDialog(1000) at Dan2+$341C, stops explicitly as
`DIALOG MANAGER / SCREEN SIZE SELECTION`, selector 1000, before constructing or
showing D4's excluded dialog. The fixed 320×200 choice remains first in the
queue. Further world bindings, drawing, palette realization, viewport output
and the second Times call remain pending. This query does not establish any
rendered-frame acceptance.

Validation: clean production boot/resource-read, GetGWorld/SetDepth/device/menu/
driver/font and catalog/identity/original-startup/low-memory observers, the full
host suite and both link audits pass. All 75,616 A5 globals match exactly.
Existing preferences use 34 windows and 42/42 services; fresh preferences pass
the same query/record checks with 60 windows and 50/50 services. Existing
preferences were restored afterward. Runtime reads remain 26/123,247 original
bytes and 3/1,318 overlay bytes; low-memory checks validate 58 sites with 55
applied. Every bounded acceptance run exited normally with its positive marker.
No owner decision changed.

## Original screen-choice contract

M2.1c3c2c5a separates the original/reference measurement prerequisite from
the pending native D4 implementation. Both original size inputs reach item 2
and WIND 128, with only PREF byte 7 changed to zero. The original call is
unconditional; a preference override cannot remove the dialog. Original-byte
guards cover preference loading/defaults, the selector/caller and window
selection. Both headless captures exit normally with positive markers; the
checker rejects eight malformed/status/input cases. Full host tests pass.
Native behavior is unchanged from the GetGWorld checkpoint; its next stop
remains SCREEN SIZE SELECTION. See [screen-choice.md](screen-choice.md).

## Hidden size-dialog construction

M2.1c3c2c5b1 implements the measured GetNewDialog(1000) dependency while
keeping D4's dialog hidden. The native constructor uses a real old-style port,
private DITL, two control handles and one text handle, and leaves qd.thePort
unchanged. It preserves D3–D7/A2–A6 and pops ten bytes. All portable record
fields, the full item list, controls, text and five regions match the Mac.
The source DITL is byte-identical afterward. Unsupported definition drawing,
presentation and constructor forms remain explicit stops. Owned-handle cleanup
is implemented; integrated original disposal/selection acceptance remains
M2.1c3c2c5b2. See [screen-choice.md](screen-choice.md).

The next named stop is Engine+$4782 QUICKDRAW / GETMAINDEVICE, before the
original SANE positioning calls. No original instructions were changed.
Clean boot/resource-read, the full startup observer set, paired graphics/menu/
driver/font checkers, the host suite and both link audits pass. Final-build A5
globals match all 75,616 bytes. Existing preferences use 36 windows and 43/43
services; fresh preferences use 62 windows and 51/51 services. Both constructor
record checks pass, and existing preferences are restored after the fresh run.
DLOG/DITL 1000 add two reads / 140 bytes: runtime original reads are now
28 / 123,387 bytes; overlay reads remain 3 / 1,318. Low-memory validation remains
58 sites / 55 applied, with segment mask $3B8B. These are logical-record checks,
not viewport/rendered-frame, full screen-selection or second-Times acceptance.
No owner decision changed.

## Main-device query for original positioning

M2.1c3c2c5b2a adds GetMainDevice at Engine+$4782. The original-byte-guarded
Mac/native pair returns the existing main handle with no argument cleanup,
preserves D0–D7/A1–A6, and leaves the full device record and current port intact.
There is no allocation, mode change or synthetic device. The next stop is
Engine+$47C2 SANE / FP68K, selector $200E, before the first positioning
conversion. The remaining arithmetic and fixed-choice requirements stay first
in the queue as M2.1c3c2c5b2b.

The exploratory reference trace `tmp/m2-sane-position-reference.log` completed
all ten original positioning calls normally. Selectors $200E/$1004/$2000/$0016/
$2010 convert a word, multiply by a single, add a word, truncate the extended
value, and convert to a word on this path. In particular, 355 × 0.5 becomes
177.5 and is truncated to 177; the vertical result is 205. This identifies the
next work; it is not native arithmetic acceptance or proof of other operands.

Validation: clean boot/resource-read, all maintained startup observers, paired
main-device/hidden-dialog/world/depth/device/menu/driver/font checks, the full
host suite and both link audits pass. All 75,616 A5 globals match exactly.
Existing and fresh preferences pass with 36/62 windows and 43/51 completed
services; the existing preferences were restored afterward. No new resource
reads are introduced: 28 / 123,387 original bytes and 3 / 1,318 overlay bytes.
The local SANE trace additionally passes exact rational operand/result, register,
stack and destination-bound checks; arithmetic implementation and full D4
selection remain pending. No owner decision changed.


## Integer-only original positioning

M2.1c3c2c5b2b implements the five original SANE operations with integer-only
68020 arithmetic. All ten original calls match the Mac operands/results,
registers, stack, FPState and bounded writes. Paired instrumentation found an
uninitialized MBarHeight shadow; the measured value 20 now produces the original
177/205 position. The native observer checks actual exception-frame flags
because debugger SR at original entry was stale. No FPU, Mac dialog drawing or
menu bar is introduced. See [sane.md](sane.md) for scope and reproduction.

Validation: 2,455 sanitizer/oracle cases, 41 original Mac fixtures, all ten
paired original calls, clean boot/resource-read, all thirteen startup observers
and the full host suite pass. Final link audits pass (76 probes), and all 75,616
A5 bytes match. Existing/fresh preferences pass with 36/62 OS windows and 43/51
completed services; existing preferences were restored. Resource reads remain
28 / 123,387 original bytes and 3 / 1,318 overlay bytes. Low-memory checks remain
58 validated / 55 applied, with live menu-height and ten-field tick checks.
Every accepted bounded run exited normally with its positive marker.

The next named stop is Engine+$48A2 MoveWindow. Remaining hidden positioning,
world binding and fixed-choice/item/disposal work remains M2.1c3c2c5b2c, with
integrated second-Times, viewport and rendering acceptance retained. Separately,
the owner clarified D5: replace all Mac dialog presentation, including new-game
and save/load, with an in-game interface. The updated design and M3.3 acceptance
record that decision; hidden records do not authorize Mac UI rendering.


## Hidden window positioning

M2.1c3c2c5b2c1 implements the original hidden MoveWindow request without drawing.
Its bitmap origin and three empty global regions match the Mac; local content,
items, controls, text, current port and window chain remain unchanged. Stack and
preserved registers pass. The next stop is Dan2+$30FE ModalDialog. Full fixed
selection remains queued, with no change to D4/D5/D7 or rendered acceptance.

A failed record comparison exposed ambiguous hexadecimal offsets in the Mac
capture scripts: `a0`/`a4` were read as registers. Corrected constructor/movement
captures supersede the earlier tail-byte evidence and establish editField=-1,
now initialized natively. A constructor probe/write watchpoint verifies its
preservation. Opaque unused TextEdit state is excluded across implementations,
but every dialog byte except bitmap bounds remains unchanged within each side.
The broader emitter audit is newly queued ahead of continuing selection.

Final clean boot/resource-read, all fourteen startup observers, the full host
suite and paired constructor/movement, SANE, main-device, world/depth/device,
menu, driver and font checks pass. All 75,616 A5 bytes match. Fresh/existing
preferences pass with 62/36 windows and 51/43 completed services, with existing
files restored afterward. Resource reads remain 28 / 123,387 original bytes and
3 / 1,318 overlay bytes; low-memory sites remain 58 validated / 55 applied.
No-float and probe audits pass (76 symbols). Accepted runs use the final stable
build and normal exits with positive markers. An earlier observer run overlapped
a rebuild and timed out; it was discarded, not counted as passing. Evidence and
reproduction are in [screen-choice.md](screen-choice.md); final native logs use
`tmp/m2-hidden-move-accepted-` and the fresh run is `tmp/m2-hidden-move-fresh.log`.


## Reference-capture literal audit

M2.1c3c2c5b2r makes generated hexadecimal operands explicit in 36 emitters,
adds a host regression over all 41 maintained Mac/MAME Lua scripts, and requires
exact input readback in the 41-case original SANE fixture. All sources compile
in MAME; fresh constructor/movement/menu/SANE captures exit normally and pass.
Paired native records remain valid with the corrected references. Menu semantic
bytes were unaffected; only trailing dump padding changed. The full host suite
passes, including source-checker mutations and fixture-input rejection cases.
The native executable is unchanged; the prior native regression results remain
applicable. Detailed exposure and replacement evidence are in
[mac-reference-loop.md](mac-reference-loop.md). Fixed size selection is again
first in the implementation queue; no owner decision changed.

## Hidden fixed-choice services

M2.1c3c2c5b2c2a implements D4's immediate item-2 policy, the original button
lookup, private dialog disposal and main-world restoration. Both existing size
inputs and fresh preferences pass paired service/selection checks; no dialog is
shown and only PREF byte 7 changes. All four private handles are released,
returning 384 physical bytes, with cleared allocation flags and an unused slot.
Original instructions remain unchanged. The next named stop is GetFontInfo,
Misc1+$0610, before WIND 128 creation. The unfinished WIND acceptance is retained
in M2.1c3c2c5b2c2c behind the new font-metrics prerequisite.

The full host suite, clean-build boot/resource-read, fourteen affected startup
observers and their paired contract checks pass. A5 remains exact across 75,616
bytes; low-memory validation/application remains 58/55. The 68020 no-float and
76-symbol probe audits pass. Original MDRV remains absent. Native evidence is
`tmp/m2-choice-accepted-*`; selection/reference reproduction is documented in
[screen-choice.md](screen-choice.md). One menu observer lost its connection
without completion and was rejected; its retry completed and passed the full
paired check. A debugger expression error in the initial choice observer was
also rejected and corrected before the accepted three preference runs.

## Original startup font-metrics contract

M2.1c3c2c5b2c2b1 captures and verifies 25 GetFontInfo records and 50 CharWidth
results for the original five font/size and five style combinations. The bounded
MAME run exits normally; original bytes, input tables, eight-byte output extents,
stack/register preservation and saved text-state restoration all pass. Rejection
checks and the full host suite pass; the literal audit now covers 43 scripts.
The native first-call input and both tables match in a read-only stop snapshot.
This is a reference-only prerequisite: native code and its GetFontInfo stop are
unchanged, so the previous native regression evidence remains applicable.
Installed definitions and native service acceptance remain at the top of the
queue. Reproduction and measured cases are in [font-manager.md](font-manager.md).

## Installed startup font metrics

M2.1c3c2c5b2c2b2 installs 25 port-owned bitmap faces and implements GetFontInfo
and CharWidth from their FOND/NFNT bodies. All 75 original calls match the Mac
contracts, including output bounds, stack/register preservation and restored
text state. Existing, fresh and low-resolution preferences pass; all 30 installed
font bodies match the generator byte-for-byte. The final guarded run is
`tmp/m2-metrics-native-final.log`, paired with
`tmp/m2-font-metrics-reference-accepted.log`. No original instructions changed,
no FPU is required, and these services draw no dialogs. Other glyph advances
remain explicitly placeholder design; rendered-font acceptance remains M2.9.

The full host suite (including font sanitizer checks), fifteen startup observers,
paired service checks and clean production boot/resource-read regressions pass.
File-write and all eight save/preference exit phases pass; original save and
preference directories are restored. A5 matches all 75,616 bytes, low-memory
sites remain 58 validated / 55 applied, and no-float/76-symbol probe audits pass.
Original resource reads remain 28 / 123,387 bytes. Existing/fresh runs complete
64/90 windows and 118/126 services respectively. Overlay metadata preparation
uses 33 reads / 572 bytes; runtime bodies total 31 / 80,800 bytes.

Early observer failures (unloaded segment and debugger macro argument parsing)
were rejected and corrected. A run affected by editing its active launcher was
also rejected; the stable-launcher reruns passed. Evidence uses
`tmp/m2-metrics-accepted-*` and `tmp/m2-metrics-regression-*`.
Startup now stops explicitly at Engine+$1038 AEInstallEventHandler, selector
$091F. Handler registration is the next dependency; WIND 128, the second Times
lookup, rendering and full M2 acceptance remain pending. Original MDRV stays absent.

## Original Apple Event registration contracts

M2.1c3c2c5b2c2b3a measures all four original registrations and 17 separate
lookup/replacement/error fixtures. Both bounded Mac modes exit normally with
positive markers and pass the independent checker, including input readback,
output bounds, stack/registers and malformed-capture rejection. All 44 Mac
scripts pass syntax and literal audits; the full host suite passes. The native
executable is unchanged and still stops at AEInstallEventHandler, so its previous
regression evidence remains applicable. Native state and paired acceptance are
retained as b3b at the top of the queue. See [apple-events.md](apple-events.md).

## Native Apple Event registrations

M2.1c3c2c5b2c2b3b retains the four original callback/refCon registrations in an
application-owned table, with measured exact lookup, replacement and invalid
handler errors. Four original calls and 17 CPU-executed native fixture calls pass
the independent Mac contracts. Six unsupported forms stop explicitly without
changing state. Actual probe shutdown clears the table, closes both resource
streams, removes Line-A and returns zero from native main. Original instructions
are unchanged and no callbacks run from interrupts. Event delivery remains M3.4.

All 16 startup observers and paired service checks pass, as do the full host
suite, clean boot/resource-read, file-write and eight save/preference resource-exit
phases. A5 matches all 75,616 bytes; low-memory sites remain 58 validated / 55
applied. Existing/fresh preferences retain 64/90 windows and 118/126 services.
Original resource reads remain 28 / 123,387 bytes; overlay bodies 31 / 80,800.
Production no-float and 77-symbol probe audits pass. Original preference/save
directories are restored. Evidence is `tmp/m2-ae-accepted-*`,
`tmp/m2-ae-regression-*`, `tmp/m2-ae-native-cpu-fixture-final.log`, and
`tmp/m2-ae-native-final-clean.log`; reproduction is in [apple-events.md](apple-events.md).

Rejected debugger-driven fixtures led to direct write/readback instrumentation:
this FS-UAE debugger ignores register and memory writes. The accepted fixtures
construct inputs on the CPU and use read-only observers. A file-write run hit
its 120-second deadline; the runner interrupt was confirmed in the remote log.
It was rejected, and the unchanged clean retry passed with a 240-second bound.

The next named stop is GetCTable(128), Engine+$110E, before WIND 128 creation.
Colour-table ownership and bytes are the next ordered dependency; palette
realization, the second Times lookup and full M2 acceptance remain pending.

## Original GetCTable ownership contract

M2.1c3c2c5b2c2b3c1 captures the original GetCTable(128) return and all 256
subsequent index mutations, plus 21 separate ownership/seed/disposal calls. The
returned handle is detached from the resource map: when clut 128 is already
loaded, GetCTable returns that same handle, clears its resource state and assigns
a new seed. Subsequent requests reload original bytes into distinct handles.
Mutation and disposal tests prove the alias relationship; seed calls establish
one consumed seed per successful table request and none for the measured missing
ID. This rules out a copy-only implementation that retains the old resource map
entry. See [color-table.md](color-table.md) for exact scope and reproduction.

Both bounded Mac capture modes exit normally and pass byte, input, stack/register,
state and output checks. Syntax/literal audits cover 45 scripts; the full host
suite passes. A checker line-anchoring mistake was corrected before acceptance;
no failed capture was counted as a pass. Native code is unchanged, so the
previous native regression evidence remains applicable. Native detachment and
paired acceptance remain b3c2 at the top of the queue.


## Native startup colour table

M2.1c3c2c5b2c2b3c2 implements the original GetCTable(128) request through the
user-mode resource service. The returned handle is detached, gets a fresh seed,
and survives all 256 original index mutations with its RGB values intact.
The 21 CPU-executed ownership cases match the Mac, including alias mutation,
reload, disposal, missing tables and interleaved seeds. The fixture uncovered
an unsupported disposed-handle size query; released master slots now return the
measured -111 error. Arbitrary pointers remain named stops. No original game
instructions changed. Reproduction and scope are in [color-table.md](color-table.md).

The full host suite, 17 startup observers with paired contracts, clean boot and
resource-read regressions pass. Fresh and existing preference inputs pass;
original preferences are restored. Final fixture and production captures exit
normally with positive markers. All 75,616 A5 bytes match the original model;
low-memory sites remain 58 validated / 55 applied. No-float and 77-symbol link
audits pass. Evidence is `tmp/m2-ctable-accepted-*`, `tmp/m2-ctable-host.log`,
`tmp/m2-ctable-final-runs.log`, `tmp/m2-ctable-native-fixture-final.log` and
`tmp/m2-ctable-native-final.log`; final fixture dumps are preserved separately.

Startup now completes 65/91 OS windows and 119/127 user services for existing/
fresh preferences. Original runtime resource reads total 29 / 125,443 bytes;
overlay bodies remain 31 / 80,800. The next named stop is NewPalette at
Engine+$1158. Original MDRV remains absent. WIND 128, the second Times lookup,
PAK-read acceptance and rendered intro output remain pending. D4/D5/D7 still
exclude Mac dialog/menu presentation; no owner decision is needed here.

## Original NewPalette construction contract

M2.1c3c2c5b2c2b3d1 measures the original 256-entry NewPalette request, full
4,112-byte result and twelve ownership/lifecycle cases. RGBs are copied, usage
is $000A and tolerance is zero. The palette owns a separate four-byte private
allocation; DisposePalette frees both without changing the source table.
Original/live bytes, exact data extents, stack/register preservation, fixture
input readback, mutation isolation and errors pass. See [palette.md](palette.md).

Both bounded Mac captures exit normally, all 46 scripts pass syntax/literal
checks, and the full host suite passes. Accepted evidence is
`tmp/m2-palette-reference-accepted.log`, `tmp/m2-palette-ownership-accepted.log`
and `tmp/m2-palette-reference-host.log`, with each capture's dumps preserved.
A checker initially rejected missing floppy-sound samples as capture errors;
that overly broad check was corrected before the accepted runs. Native code is
unchanged from 5e568da and retains its verified NEWPALETTE stop. Native
construction is b3d2 at the queue head; no palette realization or intro-frame
acceptance is claimed.

## Native palette construction and disposal

M2.1c3c2c5b2c2b3d2 implements the measured NewPalette form and unattached
DisposePalette ownership. The original constructor and twelve CPU-executed
lifecycle cases match the Mac: complete 256-entry records, independent RGB
copies, source preservation, both owned allocations freed, and exact stack/
register/error contracts. Actual probe shutdown releases both zones, closes
resource streams, removes Line-A and returns zero. Other forms remain named
stops. No original instructions changed; see [palette.md](palette.md).

All nineteen startup observers and paired contracts pass, as do the host suite,
fresh/existing preferences, boot/resource-read and final clean fixture/production
runs. The final production executable matches the startup regression binary.
All 75,616 A5 bytes match; low-memory sites remain 58 validated / 55 applied.
No-float and 77-symbol audits pass. Native palette construction adds no resource
reads or OS windows: existing/fresh runs remain 65/91 windows and 119/127
services, original resource bodies 29 / 125,443 bytes, overlay 31 / 80,800.
Original preferences are restored. Evidence is `tmp/m2-palette-accepted-*`,
`tmp/m2-palette-native-host.log`, `tmp/m2-palette-final-runs.log`,
`tmp/m2-palette-native-fixture-final.log` and `tmp/m2-palette-native-final.log`.

The initial SANE observer failed because it inspected released supervisor-stack
storage after a VBL callback. Instrumentation verified CCR=0 before RTE and at
the callback's restore point, while the reused old frame read 4 afterward. The
observer/checker now validate live frames and callback routing/restoration;
no SANE or trap-return runtime code changed. Rejected runs remain local; the
accepted evidence is `tmp/m2-palette-sane-live-frames.log`.

Startup advances to Engine+$1172 SETPALETTE. Its binding and device effects are
the next ordered prerequisite. Original MDRV remains absent; WIND 128, second
Times, original PAK reads, palette realization and intro-frame acceptance remain
pending. There is no Mac UI rendering or owner decision change.


## Original default-palette binding contract

M2.1c3c2c5b2c2b3e1 measures the original SetPalette(-1) request and independently
checks its binding with GetPalette(-1). Only palette byte 6 changes; the private
allocation, device records, logical CLUT, full physical framebuffer and hardware
palette remain unchanged. Stack/registers and original/live bytes pass. The
probe distinguishes physical NuBus video from debugger logical-address aliases.
Incorrect query/opcode and aliased pixel evidence were rejected before acceptance;
see [palette.md](palette.md) for reproduction and the measured contract.

The bounded accepted Mac run exits normally, all 47 scripts pass syntax/literal
checks, and the full host suite passes. Native runtime code is unchanged from
546480a, so its prior regression evidence remains applicable. Native binding and
paired startup acceptance remain e2 at the queue head; no rendered acceptance or
owner decision change is claimed.


## Native default-palette binding

M2.1c3c2c5b2c2b3e2 implements the original SetPalette(-1, palette, true) request.
The default binding, exact palette mutation, private allocation and unchanged
device/screen/palette state match the Mac. Uninitialized calls and unsupported
forms stop explicitly. A CPU fixture leaves a palette bound through actual
shutdown, then verifies cleared binding/zones, closed streams, restored Line-A
and a zero result. Original game instructions are unchanged; see [palette.md](palette.md).

All nineteen startup observers and paired contracts pass on the final binary,
as do fresh/existing preference variants, clean boot/resource-read, the shutdown
fixture and a final full host suite. No-float and 78-symbol audits pass. A5 remains
exact across 75,616 bytes; low-memory sites remain 58 validated / 55 applied.
Existing/fresh startup completes 67/93 OS windows and 121/129 services. Original
resource bodies total 31 / 130,660 bytes; overlay bodies remain 31 / 80,800.
Original preferences are restored and the final production hash is stable.

Shared-host load caused earlier deadlines to expire; those runs were rejected.
After interruption, live processes were checked before resuming the unfinished
observers. The shutdown fixture initially lacked QuickDraw initialization;
instrumentation established depth zero. Normal initialization and explicit
assembly-label addresses corrected its setup/observer. The new uninitialized-call
guard received a complete refreshed final native suite. Evidence and reproduction
are in [palette.md](palette.md); final host evidence is
`tmp/m2-setpalette-host-final.log` and the full native suite is
`tmp/m2-setpalette-final-startup-suite.log`.

The next named stop is Misc1+$1296 SETWTITLE. Original WIND 128 request acceptance
is next in the queue, followed by measured window-title state. Original MDRV is
absent; no Mac dialog/menu presentation or rendered-intro acceptance is claimed.


## Hidden window title state

M2.1c3c2c5b2c2d implements the original hidden title update using owned title
handles and the installed system font's 95 measured printable advances. The
paired original call preserves its input, ports, regions and all window-record
bytes except cached title width (85 to 34); the result is a six-byte Pascal
`Hider` string. WIND title/goAway/refCon offsets are corrected against original
bytes. No original instructions or Mac UI presentation are introduced.
See [window-title.md](window-title.md) for scope and reproduction.

The full host suite, twenty startup observers and paired contracts, fresh/low
preference variants, clean boot/resource-read and final title capture all pass
with normal exits. A5 is exact across 75,616 bytes; low-memory sites remain
58 validated / 55 applied. No-float and 78-symbol audits pass. The clean binary
matches the one used for startup regressions, and original preferences are
restored. Existing/fresh runs complete 68/94 OS windows and 124/132 services;
original resource bodies are 32 / 130,692 bytes, overlay bodies 31 / 80,650.

The initial native capture had stale overlay metrics and was rejected. The
regenerated overlay is 81,462 bytes; the host suite's old exact-size assertion
was updated after independently measuring the new artifact. A reference-checker
WIND offset error was also rejected and corrected. Accepted evidence uses
`tmp/m2-title-reference-contract.log`, `tmp/m2-title-native-final.log`,
`tmp/m2-title-startup-suite.log` and `tmp/m2-title-host-final.log`.

Startup now stops at window SetPalette, Misc1+$10FA, with original MDRV absent.
Integrated WIND 128 selection acceptance is next, followed by the newly queued
window-binding form. Second Times, original PAK reads and rendered intro remain
pending; no owner decision changed.


## Integrated WIND 128 selection

M2.1c3c2c5b2c2c extends the fixed-choice observer to the actual original
Misc1+$109A request, distinguishing it from WIND 131. Existing size-one, fresh
preferences and existing size-zero runs request WIND 128 and match the Mac's
complete preference byte changes. The live instructions and sole relocated
operand pass original-byte checks. Hidden dialog/service checks still pass and
the next stop remains window SetPalette, Misc1+$10FA.

All three bounded runs exit zero with positive markers; checker rejection cases
and original byte checks pass. Original preferences are restored. The runtime
executable is unchanged from 4b54e82, whose full host suite, twenty startup checks,
boot/resource-read and link audits remain applicable. This is selection acceptance,
not viewport or rendered output. See [screen-choice.md](screen-choice.md).


## Window palette and client clear

The original MoveWindow/ShowWindow transitions now match the Mac's complete
palette/private/CLUT effects. Original window colour resources drive the black
320×200 client clear; its exact dirty rectangle is retained. No Mac chrome is
rendered. The next named stop is `8-BIT PRESENTATION`, before window binding.
M2.5a brings the required display path forward; see [palette.md](palette.md).

All 21 startup observers and paired checks, preference variants, host suite,
clean boot/resource-read and link audits pass on the same executable. Original
preferences are restored. A5 remains exact, low-memory sites are 58/55, and
existing/fresh runs use 70/96 OS windows and 124/132 services. Original resource
reads are 34 / 130,788 bytes; overlay reads remain 31 / 80,650. The paired checker
also validates the exact reference cursor exception and rejects corrupt captures.
This is logical state/pixel acceptance; rendered AGA/intro checks remain pending.


## First eight-plane client publication

M2.5a converts the live WIND 128 client rectangle into eight AGA planes and
publishes complete bitmap/palette state during VBI. The first clear matches the
Mac logical CLUT and measured video colours, then startup reaches window
SetPalette at Misc1+$10FA. No original game instruction changes. The integer
reference converter initially used explicit dirty rectangles and Vette's
previous-update synchronization. M2.3g41p1 replaces that runtime loop with Kalms
assembly while preserving the same layout and synchronization.

The independent five-frame native fixture verifies full and partial updates,
palette-only preservation, viewport movement, alternating buffers and restored
OS cleanup. All 21 startup observers and paired contracts, preference variants,
host tests, clean boot/resource-read and system-window memory checks pass.
See [aga-display.md](aga-display.md) for commands, captures and the exact build.
Rendered output, PAL/NTSC and pointer acceptance, and full intro verification
remain in the ordered M2 queue.


## Window palette binding

The original SetPalette(window, default palette, true) now binds the visible
front window without changing its already-realized colours or pixels. Paired
captures verify original/relocated bytes, stack/register behavior, private seed,
full palette/CLUT and display preservation. Capture the native service after
its dispatcher publishes the preceding clear; see [palette.md](palette.md).

Default-binding, client-clear, original-startup, native-driver and first-frame
regressions pass, along with fresh/low preferences, the host suite, clean boot
and resource reads. A5 is still byte-exact, original MDRV is absent, and startup
now stops at ActivatePalette, Misc1+$1100. That measured dependency is next in
the queue; M2 intro and rendered acceptance remain incomplete.


## Already-realized palette activation

ActivatePalette at Misc1+$1100 now accepts the measured already-realized,
active palette bound to the visible front window. The original Mac call leaves
all palette, device and pixel state unchanged; the native service preserves
that state and queues no extra frame. Unmeasured activation states stop loudly.
See [palette.md](palette.md) for the original bytes and paired capture procedure.

Six relevant startup observers and paired checks, host tests, fresh/low
preferences, clean boot/resource reads and exact A5 comparison pass. Original
preferences are restored and original MDRV remains absent. Startup subsequently passes ShowHide, game-port binding, TickCount and unchanged
window geometry; intro and rendered acceptance remain pending.

## Colour-window geometry and background visibility

Use `color_window_geometry.gdb`, `window_move_geometry.gdb` and `showhide.gdb`
with their corresponding Mac observers and paired checkers. The contracts and
local evidence are in [window-geometry.md](window-geometry.md). Host geometry
checks are part of `make host-tests`. ShowHide's background clear is verified
against its full complex region and must leave the viewport, palette and frame
queue unchanged. Current startup observers pin UnionRect at Dan2+$01DA; a timeout or a different stop is not acceptance.


## Startup clock query

TickCount now returns the existing private Macintosh clock with the measured
stack/register contract. Original bytes, the full-width Mac fixture and native
clock source pass paired checks; see [amiga-arch.md](amiga-arch.md). The bounded
window-core run verifies 407 PAL fields / 489 ticks and exact 1 MiB reads across
OS handbacks. Host tests, existing/fresh startup, AGA publication and resource-read
regressions pass. All 75,616 A5 bytes match, both link audits pass, and original
preferences are restored. Existing/fresh startup uses 75/101 OS windows and
129/137 services; original resource reads total 39 / 177,820 bytes. Original
MDRV remains absent. Evidence is in local `tmp/m2-tickcount-*` logs.

The clock query advances into drawing setup. Logo/intro and rendered-window
acceptance remain pending; no owner decision changed.


## Unchanged startup window geometry

The original size/origin requests now preserve the already-correct visible
320×200 window. Paired captures verify original bytes, arguments, stack and
preserved registers, all window/region/device/palette records and all 307,200
screen pixels. No display update or OS handback is added. The native stop is
now QUICKDRAW / SETPT at Dark+$4F88. Actual resize/movement and unsupported
window arrangements remain named stops; no Mac chrome is drawn.

The final paired capture is `tmp/m2-reassert-native-final.log`, checked against
`tmp/m2-resize-reference-accepted.log`. Host tests and both link audits pass.
The relevant startup/display evidence uses `tmp/m2-reassert-*` logs; see
[window-geometry.md](window-geometry.md) for the measured contracts.
Existing/fresh startup and AGA publication checks pass on the final executable:
75/101 OS windows, 129/137 services, one queued/presented frame, all eight planes
and all 256 colours. Original preferences are restored; A5 matches all 75,616
bytes. Original MDRV remains absent. Rendered-window and intro acceptance remain
pending; no owner decision changed.


## Drawing point initialization

SetPt at Dark+$4F88 now writes the original vertical/horizontal words into
the point, with the measured stack/register contract. The paired original/native
check validates live instruction bytes, the exact four-byte write and preserved
neighbouring storage. The final bounded runs in `tmp/m2-setpt-final-*` pass
SetPt, original startup and AGA publication on the same executable. All 75,616
A5 bytes match; no-float and 78-symbol link audits pass. Original resource reads remain 39 / 177,820 bytes, with 75 OS handbacks and
129 services.
Original MDRV is absent. Startup now stops at QUICKDRAW / NEWRGN, Misc2+$1DA6.
See [amiga-arch.md](amiga-arch.md) for the byte guard and contract.


## Empty-region allocation

NewRgn at Misc2+$1DA6 now allocates a real empty ten-byte region in the current
heap. Original Memory Manager queries establish size, flags and owning zone;
the native observer verifies the real master slot and owning block. Paired
bytes, contents, error state and stack/register checks pass. See
[amiga-arch.md](amiga-arch.md) for the contract and original-byte guard.

`tmp/m2-newrgn-final-*` contains normal-exit passes for the paired region call,
original startup and AGA publication on the final executable. The heap suite
passes including 2,500 fragmentation operations; both link audits pass. All
75,616 A5 bytes match. Resource reads remain 39 / 177,820 bytes, with 75 OS
handbacks and 129 services; original MDRV is absent. The next named stop is
QUICKDRAW / NEWGWORLD, selector 0, Misc2+$0074. Full region drawing and intro
acceptance remain pending.


## Owned eight-bit offscreen allocation

NewGWorld at Misc2+$0074 now constructs a real eight-bit world, including its
pixel handle, 27 owned auxiliary handles and private device. Complete defined
records and pointer relationships match the Mac. The measured inverse-table
builder matches all 4,096 entries and 256 collision links; source colour-table
flags are preserved across protected allocation. Main device and screen bytes
remain unchanged. See [gworld.md](gworld.md) for contracts and reproduction.

The full host suite, exact inverse reference comparison, final native allocation,
original startup and AGA publication pass. The accepted final runtime evidence
is `tmp/m2-newgworld-final2-*`; the reference is
`tmp/m2-newgworld-ownership-all.log`. Both link audits pass, and all 75,616 A5
bytes match. Original resource reads remain 39 / 177,820 bytes, with
75 OS handbacks and 129 services. Original MDRV is absent. A stale expected-stop value in an
earlier startup observer was corrected; that rejected run is not acceptance.

The next stop is offscreen SetGWorld, Misc2+$008E. The subsequent original
bind/clip/lock/erase/unlock/restore sequence is one coherent queue item; this
allocation does not claim initialized offscreen pixels or logo/intro acceptance.


## Offscreen buffer initialization

The complete original bind/clip/lookup/lock/erase/unlock/restore sequence now
passes paired record, stack, lock and pixel checks. Its 259,848 visible bytes
clear exactly, all 1,604 padding bytes remain intact, and the native screen
remains unchanged. See [gworld.md](gworld.md) for scope and reproduction.
The production executable now reaches GETPIXBASEADDR at Misc2+$02DA.
Final paired evidence: `tmp/m2-gworld-init-reference-final.log` and
`tmp/m2-gworld-init-native-final.log`, both normal exit 0.
The host suite passes (`tmp/m2-gworld-init-host-final.log`). Startup and AGA
publication pass on the same final executable in
`tmp/m2-gworld-init-startup-final.log` and `tmp/m2-gworld-init-aga.log`.
All 75,616 A5 bytes match, and both link audits pass. Startup now performs
41 original resource reads / 206,540 bytes, with 77 OS handbacks and 131
completed services; original MDRV remains absent. The extra two reads are
newly reached work, not an allocation-side handback. An observer with the old
75/129 counts was rejected, instrumented and corrected. Fresh-preference
endpoint counts are derived as the same prior +26 windows / +8 services;
this change's native acceptance uses the existing-preference route.
This does not claim the remaining M2 acceptance.


## Owned pixel-address access

The original GetPixBaseAddr call now returns the real buffer pointer and the
following original 56-row copy matches the Mac. The pure helper also matches
the measured unlocked reference contract. See [gworld.md](gworld.md) for the
explicit verification scope. The native observer combines startup, paired
copy and AGA checkpoints to avoid repeated launches of the same executable.

A reference probe initially crashed MAME during boot. The macOS crash report
identified a null string passed to the Lua debugger breakpoint binding:
`cpu.debug:bpset` requires an explicit third action argument, even an empty
string. The corrected reference exits normally; crashed runs are not evidence.
The original copy-loop's relocated JSR is validated against A5, not compared
as an unrelocated address literal.

`tmp/m2-pixbase-native-final.log` exits normally and passes the paired pointer
and row-copy check, original main/A5 checkpoint, original-MDRV exclusion and
AGA publication on one executable. All 75,616 A5 bytes match; all eight planes
and 256 colours match the independent display decoder. The helper sanitizer
suite, locked/unlocked reference comparison, Lua literal audit and both link
audits pass. Counts remain 77 OS handbacks, 131 services and 41 original
resource reads / 206,540 bytes. No rendered intro acceptance is claimed.


## Hidden startup menu-list setup

ClearMenuBar, four InsertMenu calls and the suppressed DrawMenuBar now complete
with measured menu order and unchanged application records. The native screen
is unchanged. Reference capture includes a nonempty clear proving that menu
handles/records survive list removal. The final native observer also reaches
both original Times lookups and checks the original native-driver calls in the
same launch; their retained queue acceptances are the next items.
See [menu-manager.md](menu-manager.md) for exact scope and reproduction.

The final reference and native menu-lifecycle captures exit normally. Paired
menu records/order, six call results, unchanged screen, menu-record host suite,
Lua literal audit and both link audits pass. Both original Times lookups return
20; native driver selectors 21/24 retain their measured state/ABI. A5 matches
all 75,616 bytes. The AGA decoder verifies exact pixels, eight plane pointers,
256 colours and VBI publication. Counts are now 81 handbacks, 143 services,
42 original resource reads / 208,858 bytes; overlay remains 31 / 80,650 and
preparation 64 / 81,222. The next stop is UNIONRECT at Dan2+$01DA. This does
not count either pending driver/font acceptance item as removed yet.


## Integrated native driver startup acceptance

M2.1c3c2 is complete using the existing combined native capture
`tmp/m2-menu-lifecycle-native-final.log` (exit 0) and the independent original
`tmp/m2-driver-startup-reference.log` (exit 0). Both original call sequences,
selector arguments, return registers, preserved registers, stack and resulting
native state pass. Second Times returns 20 after exactly two native driver calls;
UnionRect is the next named stop and no original MDRV is resident. The shared
observer also proves inactive voices, unassigned channels, original main/A5 and
AGA memory/publication. The driver observer now delegates to that shared script.
The native acceptance checker requires this integrated endpoint and rejects
missing/reordered calls, wrong results, unfinished services and timeout/error
completion. Sanitizer-backed driver state tests and checker rejection fixtures
pass. No runtime code changed; no repeat emulator launch was necessary.


## Paired installed-font startup acceptance

M2.1c3 is complete. The shared observer now checks the second original call at
Dan1+$0038 directly, preserving its entry D0 for return comparison and requiring
zero ResErr/MemErr. `tmp/m2-font-integrated-native.log` exits 0 and records both
Times=20, eight-byte cleanup, second D0=$00312FF2 preserved and exact installed
FOND/NFNT bodies. Original/reference fixtures, native driver acceptance, font
parser sanitizer tests and checker rejection fixtures pass. AGA publication
still passes and all 75,616 A5 bytes match. Counts and UnionRect endpoint are
unchanged. No runtime code changed; the one new native run fills the missing
second-call ABI evidence. Remaining font rendering is M2.9.


## Original image rectangle preparation

UnionRect now passes all twenty original Dan2 calls against the Mac, including
identical input and output rectangles. The pure helper matches eleven additional
reference edge/alias cases under sanitizers. See [rectangles.md](rectangles.md)
for the contract and reproduction. The final combined native run exits 0 and
also passes both Times calls, native driver checks, AGA pixels/palette/VBI and
75,616-byte A5 comparison. Both link audits and the 65-script MAME literal audit
pass. No original MDRV is resident. Current counts are 101 windows, 163 completed
services and 62 resource reads / 265,454 bytes; next is DetachResource at Dan2+$0210.
The full host suite passes (`tmp/m2-unionrect-host.log`). Observers are pinned
to that new boundary. Fresh-preference counts are derived,
not a newly accepted run. Original PAK payload acceptance remains pending.


## Already-detached resource handles

M2.3g5 accepts the original Dan2+$0210 DetachResource call. GetCTable already
returned an owned table, so the Mac returns ResErr -192 and zero-extended D0
$FF40, clears A0, consumes four bytes and preserves MemErr, other registers and
the handle/body. The native boundary now returns that error for valid owned
handles absent from the resource association table; invalid handles still stop.
Attached and dirty-resource behavior is unchanged.

`mac_detached_resource.lua` measures the original call plus repeat, locked,
empty and nil cases, using CPU-only fixtures. The independent checker guards
original bytes and the live A5-relocated immediate, then checks results and
2,056-byte table preservation. Native flags remain owned/unlocked and unchanged;
no resource association appears. Cross-platform comparison excludes only the
independently allocated four-byte colour seed, as in prior GetCTable acceptance.

Accepted captures: `tmp/m2-detached-reference.log` and
`tmp/m2-detached-native-final.log`, both exit 0. Run
`python3 tools/check_detached_resource.py tmp/m2-detached-reference.log --status 0
--native tmp/m2-detached-native-final.log --native-status 0` with actual statuses.
The native capture uses the shared menu/startup observer. It also passes all
20 rectangle calls, both font lookups, native driver/MDRV guard, 75,616 A5 bytes
and AGA pixels/palette/VBI. Resource map/source/writer/directory/publication host
checks, startup checker tests, 66-script literal audit and both link audits pass.
The discovery capture's obsolete endpoint failed and is not acceptance.

Counts remain 101 windows, 163 services and 62 original resource reads /
265,454 bytes. Next is NewGWorld at Dan2+$0234, selector zero, with GetCTable's
$8000 table flag. Its input-table allocation behavior is queued as M2.3g6.
Locked/empty/nil variants here have reference evidence; this new native original
capture exercises the resident unlocked table. Prior attached/dirty resource
acceptances remain in force; this does not claim intro or audio acceptance.


## Device-table offscreen allocation

M2.3g6 is complete. The allocator accepts the measured $8000 colour-table flag
without altering the independent copy or caller's table. The existing world
capture/checker now supports both original sites; native record dumping is
shared rather than duplicated. See [gworld.md](gworld.md) for contract details.
The final reference/native captures exit 0 and agree on all defined world records,
27 owned handles, 78,048 pixel bytes and inverse-colour data. Both ordinary and
device-table host inverse comparisons pass, with sanitizers. Existing detachment,
20 rectangle calls, both font lookups, native driver/MDRV guard and AGA checks
pass in the same native launch. All 75,616 A5 bytes match; both link audits and
the literal audit pass. Counts remain 101 windows, 163 services and 62 original
resource reads / 265,454 bytes. Next is named RGBForeColor, Dan2+$02BE.


## Offscreen RGB drawing colours

M2.3g7 is complete. RGBForeColor/RGBBackColor use the owned world’s table and
inverse collision rings, update real port fields and preserve simple patterns.
See [color-drawing.md](color-drawing.md) for contract and verification scope.
The native original two-call sequence and reference 64-call colour fixture pass;
the native helper matches all 66 measured lookup results under sanitizers.
The final combined run exits 0 and passes world records/ownership, detachment,
20 rectangle calls, both Times lookups, driver/MDRV guard, AGA and all 75,616 A5
bytes. Offscreen helper regressions, startup checker tests, 67-script literal
audit and both link audits pass. Counts are 101 windows, 164 completed services,
62 original resource reads / 265,454 bytes. Next is DrawPicture at Dan2+$0382.
The discovery run failed its obsolete endpoint and is not acceptance. Fresh
preferences retain derived counts (127 windows / 172 services), not a new run.


## Indexed picture preparation

M2.3g8 is complete. All twenty original Dan2 pictures now draw into the owned
138×542 world using eight-bit PackBits and its actual inverse colour table.
Detached images use their real heap sizes. See [picture-drawing.md](picture-drawing.md)
for the measured format, original-byte guard and reproduction commands.

`tmp/m2-pict8-reference.log` and `tmp/m2-pict8-native-final.log` both exit 0;
the independent oracle verifies 1,560,960 destination bytes on each side,
including unchanged padding and outside pixels, preserved records and ABI.
The final combined capture also passes device-table GWorld records, detachment,
all twenty rectangle calls, both installed-font lookups, native driver/MDRV
exclusion, AGA publication/pixels/palette and all 75,616 A5 bytes. The full host
suite (`tmp/m2-pict8-host.log`), 68-script Lua audit and both link audits pass.
The initial observer failed before drawing because its size variable used a
register name; that run was rejected and the variable renamed. A later discovery
capture passed pixels; final acceptance additionally checks original live bytes,
startup and display on the final executable.

The next stop is QUICKDRAW / TEXTWIDTH at Dan1+$0216. Counts are 113 OS windows,
211 completed services and unchanged 62 resource reads / 265,454 bytes.
Fresh-preference endpoint counts (139 / 219 services) remain derived, not newly
accepted. No rendered intro or broader scaled-picture acceptance is claimed.


## Startup text measurement

M2.3g9 is complete. The original 220 Dan1 TextWidth calls pass paired string,
range, width, port and ABI checks. The native service validates the installed
Times/plain/14 selection and applies measured integer 8.8 accumulation without
FPU operations. Other selections remain named stops. See
[font-manager.md](font-manager.md#startup-textwidth) for contract and limitations.

Reference captures `tmp/m2-textwidth-fractions2.log` (529 fixtures) and
`tmp/m2-textwidth-original-reference.log` (220 original calls), and final native
`tmp/m2-textwidth-native-final.log`, all exit 0 with positive completion.
The compiled helper matches every fixture under sanitizers. The full host suite
(`tmp/m2-textwidth-host.log`), 69-script literal audit and link audits pass.
The same final native run also passes all twenty pictures, installed fonts,
device-table GWorld records, RGB calls, driver/MDRV exclusion, AGA publication
and all 75,616 A5 bytes. A discovery observer failed after reaching its next
stop; its termination check was corrected and it is not final acceptance.

Current stop: QUICKDRAW / SETGWORLD at Misc1+$0E0A, selector 6. Counts are
113 windows, 431 completed services and unchanged 62 resource reads / 265,454
bytes. Fresh-preference counts (139 windows / 439 services) are derived, not
newly accepted. Intro and rendered-window acceptance remain pending.


## Background drawing-port binding

M2.3g10 is complete. SetGWorld now accepts a validated owned visible colour
window even when it is behind the front window. Original bytes and paired
Mac/native capture prove the background-window binding and ABI; every window,
PixMap, device and screen byte is unchanged. Native palette and publication
state are unchanged. See [gworld.md](gworld.md#visible-background-window-binding).

`tmp/m2-world-restore-reference-final.log` and
`tmp/m2-world-restore-native-final.log` both exit 0 and pass the paired checker.
The same final run passes all twenty pictures, 220 text measurements, installed
fonts, driver/MDRV guard, AGA pixels/palette/publication and 75,616 A5 bytes.
Offscreen inverse/layout sanitizer checks, startup checker tests, 70-script Lua
audit and both link audits pass. Early reference attempts used the wrong segment
base and are rejected. The final reference's later clock-shaped cursor is checked
explicitly instead of reusing the earlier arrow's pixel count.

Next is QUICKDRAW / LOCALTOGLOBAL at Misc1+$0E20. Counts remain 113 windows,
431 services and 62 resource reads / 265,454 bytes. Fresh-preference counts
remain derived. No rendered intro acceptance is claimed.


## Background LocalToGlobal points

M2.3g11 is complete. Both original Misc1 corner-point conversions match the Mac,
including all preserved registers, four-byte stack cleanup, point guards and
unchanged port/PixMap records. The conversion reads the actual selected window's
screen-backed PixMap origin. The unused inherited Vette GlobalToLocal constant
is replaced with a named stop and tracked as M2.3b.

`tmp/m2-localglobal-reference.log` and `tmp/m2-localglobal-native-final.log`
exit 0 with required completion markers. The final combined run also passes
background binding, twenty pictures, 220 text measurements, fonts, driver/MDRV
exclusion, AGA pixels/palette/publication and all 75,616 A5 bytes. Geometry helper
sanitizer tests, startup checker tests, 71-script literal audit and both link
audits pass. See [gworld.md](gworld.md#background-point-conversion) for reproduction.

Next is QUICKDRAW / TESTDEVICEATTRIBUTE at Misc1+$0E3A. Counts remain 113
windows, 431 services and 62 original resource reads / 265,454 bytes. Fresh
preferences remain derived, and rendered intro acceptance is still pending.


## Drawing-device attributes

M2.3g12 is complete. The original bit-13 query reads the actual $B921 device
flags and returns a one-byte Boolean with unchanged padding. D0/D1 low words
and preserved upper words match the measured contract; D2–D7/A2–A6 and the
entire device record are unchanged. The implementation accepts bits 0–15 on
the registered main device and stops explicitly for unsupported inputs.

`tmp/m2-device-attribute-reference-final.log` and
`tmp/m2-device-attribute-native-final.log` exit 0 and pass the reference/native
checkers. The reference includes all sixteen flags with register/padding
sentinels; native acceptance exercises the original query. The same final run
passes both coordinate conversions, background binding, 220 text widths, twenty
pictures, fonts, driver/MDRV guard, AGA publication and all 75,616 A5 bytes.
Device inverse/layout sanitizer tests, startup checker tests, the 72-script Lua
audit and both link audits pass. See [gworld.md](gworld.md#drawing-device-attribute-query).

The next stop is QUICKDRAW / SECTRECT at Misc1+$0E90, before the device iterator
can finish. Counts remain 113 windows, 431 services and 62 original resource
reads / 265,454 bytes. Fresh-preference counts remain derived. Intro acceptance
is still pending.


## Drawing-device rectangle intersections

M2.3g13 is complete. Both original SectRect calls match the Mac: background and
game-window intersections, Boolean/padding, stack/register contract and guarded
destination bytes. Original instructions are unchanged. Fourteen additional Mac
fixtures cover empty/touching/inverted rectangles, signed extremes and aliasing.
All sixteen measured pairs pass the compiled helper under ASan/UBSan.

`tmp/m2-sectrect-reference-final.log` and `tmp/m2-sectrect-native-final.log`
exit 0 with required markers. The final combined native run passes device flags,
both background coordinate conversions, background binding, 220 text widths,
twenty pictures, installed fonts, driver/MDRV exclusion, AGA pixels/palette/VBI
publication and all 75,616 A5 bytes. The full host suite, 73-script MAME literal
audit and both clean-build link audits pass. The discovery observer overwrote
first-window captures on the second device-selection sequence; the final observer
preserves those captures and checks both intersections. Discovery is not acceptance.
See [rectangles.md](rectangles.md#sectrect) for the contract and reproduction.

Next is EVENT MANAGER / WAITNEXTEVENT at Engine+$44F0. Counts remain 113
windows, 431/431 services and 62 original resource reads / 265,454 bytes.
Fresh-preference counts remain derived. No rendered intro acceptance is claimed.


## Startup event polling

M2.3g14 is complete. WaitNextEvent now consumes actual pending window activation
and update state, with the measured EventRecord and Boolean/stack/register
contract. The current no-input route returns activation, game-window update,
background-window update and null. The reference also receives Finder's launch
event; the standalone Amiga launcher has no corresponding producer. The obsolete
Vette mouse-coordinate addition is removed because AitdScreen tracks global
coordinates. Sleep remains ignored by design; nonnil mouse-region wakeups stop.

`tmp/m2-event-reference.log` (eight original calls) and
`tmp/m2-event-native-final.log` (four original calls) both exit 0 and pass the
guarded event/ABI checker. The combined capture also passes all eight repeated
rectangle intersections, device flags, background coordinates/binding, 220 text
widths, twenty pictures, fonts, driver/MDRV exclusion, AGA publication and all
75,616 A5 bytes. The full host suite, 74-script Lua audit and both link audits
pass. Initial checker expectations covered only the two pre-event intersections;
the existing trace established four alternating background/game pairs, and the
checker now validates every pair and destination guard. No emulator rerun was
needed for that observer correction. See [events.md](events.md).

Next is QUICKDRAW / OBSCURECURSOR at Engine+$0FF6. Counts remain 113 windows,
431/431 services and 62 original resource reads / 265,454 bytes. The intro still
has not run; no rendered intro or cursor acceptance is claimed.


## Startup cursor obscuring

M2.3g15 is complete. Cursor state now separates explicit hide level from temporary
obscuring, with VBI mouse movement clearing only the latter. The original call
and repeated calls match the conditional D0 result and preserve stack, other
registers and the cursor image. The AGA pointer gate remains disabled.

`tmp/m2-cursor-reference-final.log` exits 0 and covers the original call, nine
Init/Hide/Show/Obscure fixtures, register sentinels and emulated ADB movement.
The compiled helper matches eleven measured states under ASan/UBSan and also
checks movement while explicitly hidden and hide-count overflow rejection.
`tmp/m2-cursor-native-acceptance.log` exits 0 and passes six original obscure
calls, nine event polls, twenty rectangle intersections, device flags,
background coordinates/binding, 220 text widths, twenty pictures, fonts,
driver/MDRV exclusion, AGA publication and all 75,616 A5 bytes. Full host tests,
updated driver/preference checker tests, the 75-script Lua audit and clean-build
link audits pass. See [cursor.md](cursor.md) for reproduction.

The earlier `native-final` run was rejected by the old fixed four-event assertion.
Its trace established the repeated idle route; the observer now validates every
call without fixing its timing-dependent count. No timeout is accepted.
Initial build attempts exposed the platform's injected integer types; the helper
now follows the repository's host-only stdint include convention.

Next is QUICKDRAW / GETFORECOLOR at Dan1+$623C. The original has performed two
additional resource reads: 115 windows, 433/433 services and 64 reads / 294,970
bytes. CODE mask is $3FBB; overlay counts remain 31/80,650 and preparation
64/81,222, with 244 resources and 58 low-memory patches. Fresh-preference counts
141/441 remain derived. No rendered cursor or intro acceptance is claimed.


## Selected-port colour getters

M2.3g16 is complete. The adjacent original GetForeColor/GetBackColor calls now
copy the selected owned colour port's six RGB bytes with the measured ABI.
Both native original calls preserve the full port and output guards. Four Mac
fixtures verify nontrivial component values. The final reference captures
InitGraf's actual pointer; the first probe's cached GWorld pointer was rejected.

`tmp/m2-getcolor-reference-final.log` and `tmp/m2-getcolor-native-final.log`
exit 0 and pass the colour checkers. The same native run passes cursor obscuring,
events, all repeated rectangle intersections, device flags, background
coordinates/binding, 220 text widths, twenty pictures, fonts, driver/MDRV
exclusion, AGA publication and all 75,616 A5 bytes. Full host tests, the
76-script Lua audit and both link audits pass. An interrupt reused one event
call's popped argument area; the corrected checker validates live return state,
not dead stack storage. See [gworld.md](gworld.md#selected-port-rgb-retrieval).

Next is COLOR QUICKDRAW / RGBFORECOLOR at Dan1+$624A: the existing setter supports
GWorlds, while this original call selects the game window. Counts remain 115
windows, 433/433 services and 64 resource reads / 294,970 bytes; CODE mask $3FBB.
Fresh-preference counts remain derived. No intro frame acceptance is claimed.


## Window RGB setters

M2.3g17 is complete. Window RGBForeColor/RGBBackColor use the main device's real
256-colour table, the measured inverse cube/collision builder and RGB16 matching.
The obsolete sixteen-entry main-device builder is removed. Its replacement uses
and releases private-zone scratch without an OS window, and caches by table seed.
Default pattern state is retained; unsupported nondefault window patterns stop.

`tmp/m2-window-rgb-reference.log` and `tmp/m2-window-rgb-native-final.log`
exit 0 and pass paired original setters, exact port changes, unchanged palette
and patterns, all defined inverse-table bytes and ABI checks. The existing
compiled builder/matcher matches the main table and all 66 reference RGB results
under ASan/UBSan. The final run also passes original offscreen setters, colour
getters, cursor state, events, rectangle intersections, device flags, background
coordinates/binding, 220 text widths, twenty pictures, fonts, driver/MDRV guard,
AGA publication and all 75,616 A5 bytes. Full host tests, the 77-script Lua audit
and both link audits pass. Reproduction is in
[gworld.md](gworld.md#window-rgb-updates-and-the-main-inverse-table).

Next is QUICKDRAW / PAINTRECT at Dan2+$0D52. Counts remain 115 windows,
433/433 services and 64 resource reads / 294,970 bytes, with CODE mask $3FBB.
Fresh-preference counts remain derived. Intro frame acceptance is still open.


## Window rectangle fill

M2.3g18 is complete. `tmp/m2-paintrect-reference-colors.log` and
`tmp/m2-paintrect-native-final.log` both exit 0. The production helper passes ten
complete-screen comparisons (three Mac, one native and six independent edge
cases); the original native call passes byte, ABI, guarded-record, palette and
surrounding-pixel checks. The combined run passes the existing colour, cursor,
event, geometry/binding, device, twenty-picture, 220-text-width, font and driver
checks. Both AGA frames publish with the correct eight planes and 256 colours;
all 75,616 A5 bytes match. Full host tests and both link audits pass, as do the
78-script Lua audit and updated endpoint-validator self-tests. Reproduction is
in [gworld.md](gworld.md#window-rectangle-filling).

The next named stop is COLOR QUICKDRAW / GETCTABLE, selector 129, Dark2+$1FDC.
Counts are 116 windows, 434 entered / 433 completed services (the stopped table
service is active), 65 resource reads / 297,034 bytes; CODE mask remains $3FBB.
Fresh-preference counts of 142 windows and 442/441 services remain derived.
The original MDRV is absent. Intro frame acceptance remains pending.


## Colour-table 129

M2.3g19 is complete. The Mac reference (`tmp/m2-ctable129-reference.log`) and
combined native run (`tmp/m2-ctable129-native-final.log`) exit 0 and pass the
original 2,064-byte table, flags, trailing bytes, generated seed, ownership,
handle-state and ABI checks. A separate original-table regression
(`tmp/m2-ctable129-original-table-regression.log`) exits 0 and preserves the
clut 128 GetCTable/mutation behavior. Full host tests, both link audits and the
79-script Lua audit pass. The combined capture passes rectangle fills, both
AGA publications, colour calls, events/cursor, geometry/device/binding, twenty
pictures, 220 text widths, fonts, driver/MDRV guard and all 75,616 A5 bytes.
See [color-table.md](color-table.md#colour-table-129-m).

The next stop is PALETTE MANAGER / NEWPALETTE, Dark2+$201C. Counts are 116 OS
windows, 434/434 services, 65 reads / 297,034 bytes, CODE mask $3FBB. The table
service now completes. Fresh-preference counts remain derived (142 windows,
442/442 services). Intro frame acceptance remains pending.


## Palette from colour-table 129

M2.3g20 is complete. The second constructor accepts the measured larger source
and uses the existing free ownership slot to assign its reusable identifier.
`tmp/m2-palette129-reference.log`, `tmp/m2-palette-serial-holes-reference.log`,
`tmp/m2-palette129-native-final.log` and the independent first-constructor
regression `tmp/m2-palette129-first-palette-regression.log` all exit 0 and pass.
Full palette/private/source bytes, ABI, sizes, ownership/disposal and identifier
reuse are checked. Full host tests, both link audits and the 81-script Lua audit
pass. The integrated capture also passes both table forms' reached state,
rectangle fills, AGA publication, colour calls, cursor/events, geometry/device/
binding, twenty preparation pictures, 220 text widths, fonts, driver/MDRV guard
and all 75,616 A5 bytes. See [palette.md](palette.md#palette-from-colour-table-129).

Next is PALETTE MANAGER / SETPALETTE, Dark2+$20CC. The original has additionally
loaded PICT 1500, MacPlay (small). Counts are 117 windows, 435/435 services,
66 reads / 313,392 bytes and CODE mask $3FBB. Fresh-preference counts remain
derived (143 windows, 443/443 services). Runtime discovery snapshots now include
resource counts to avoid inferring them when advancing the regression boundary.
Intro frame acceptance remains pending.


## Presentation palette binding

M2.3g21 is complete. The new front-window binding reuses Palette8 realization,
changes the association, retains the default palette and publishes new colours.
No Mac title bar is drawn. The original then clears the client white and reaches
QUICKDRAW / DRAWPICTURE at Dark2+$20F2. See
[palette.md](palette.md#presentation-palette-binding) for measured bytes and ABI.

Reference `tmp/m2-binding129-reference-final.log` and native
`tmp/m2-binding129-native-final.log` both terminate with exit zero and positive
acceptance markers. Full palette/private/CLUT and client comparisons pass,
including the following white fill and four complete AGA publications. Host
suite, sanitizer helper comparison, link audits and the 82-script MAME literal
audit pass. Integrated regressions pass both colour-table forms, constructor,
rectangle fills, RGB getters/setters, events/cursor, geometry/device/world
binding, twenty preparation pictures, 220 text widths, fonts, original-MDRV
exclusion and all 75,616 A5 bytes. Counts remain 117 windows, 435/435 services,
66 reads / 313,392 bytes and CODE mask $3FBB. Intro acceptance remains pending.


## MacPlay window picture

M2.3g22 is complete. The existing Vette-derived indexed renderer now supports
owned eight-bit screen windows, their main-device colour matching, rectangular
clipping and translated dirty bounds. Original Dark2+$20F2 preserves all caller
registers and draws PICT 1500 at (4,32)–(196,288). Full-buffer and paired client/
CLUT comparisons pass, including all untouched pixels. The fifth AGA frame
contains the picture; the sixth contains the later original black clear.
See [picture-drawing.md](picture-drawing.md#presentation-window-picture).

Both reference and integrated native runs exit zero. The full native transcript
is `tmp/m2-presentpicture-native-complete.log` (the wrapper tail is insufficient).
Host tests, no-float/probe link audits and the 83-script MAME literal audit pass.
Integrated regressions pass twenty offscreen pictures, 220 text widths, colour
getters/setters, palette construction/binding, table loading, rectangle fills,
geometry/device/world state, fonts, 398 event calls, cursor state, MDRV exclusion
and all 75,616 A5 bytes. Startup stops at SetPalette, Dark2+$214C: 117 windows,
435/435 services, 66 reads / 313,392 bytes, CODE mask $3FBB. The next item measures
palette restoration. Full intro and owner-deferred rendered video remain open.


## Restore the default palette after MacPlay

M2.3g23 is complete. The measured restore uses the existing realization helper
with explicitly validated $800A entry state, updates the incoming private seed,
deactivates the outgoing palette and rebinds the default. Client pixels and
both palette records except that outgoing state word remain unchanged. No Mac
chrome is drawn. See [palette.md](palette.md#presentation-palette-restoration).

Reference `tmp/m2-restorepalette-reference-next.log` and native
`tmp/m2-restorepalette-native-final.log` terminate with exit zero. Full paired
palette/private/CLUT/client and ABI checks pass. Seventh-frame palette-only AGA
publication and the eighth frame at the next stop match the reference. Host
suite, sanitizer comparisons, clean-build no-float/probe audits and the 84-script
MAME literal audit pass. Integrated picture, palette, table, fill, RGB, event,
cursor, geometry, device/world, font, text and A5 checks all pass; original MDRV
remains absent. The observer skips the already-verified repeated event loop
between picture publication and restoration, retaining the initial nine calls.

Next is QUICKDRAW / COPYBITS, Misc2+$24D2. Counts are 128 windows, 463/463
services, 68 reads / 333,998 bytes, CODE mask $3FFB. Fresh-preference counts
remain derived (154 windows, 471/471 services). Full intro acceptance is open.


## First intro CopyBits and Infogrames logo

M2.3g24 is complete. The byte copy preserves indices for the measured equal-seed
colour environments, using Vette's clipping rules with owned buffers and exact
dirty bounds. The entire destination and meaningful source pixels match the Mac;
source row padding is unchanged on each platform. See [copybits.md](copybits.md).

Reference `tmp/m2-copybits8-reference.log` and native
`tmp/m2-copybits8-native-final.log` exit zero. The ninth AGA publication matches
the Infogrames logo, including all planes and colours. Host suite, helper
sanitizers, clean-build no-float/probe audits and 85-script literal audit pass.
Integrated palette/restoration/picture/AGA, table, fill, RGB, font/text, geometry,
device/world, event/cursor and 75,616-byte A5 checks pass; the run observed 612
event calls. Original MDRV remains absent.

Next is native SOUND DRIVER / SELECTOR 22, Core+$1A74. Counts: 128 windows,
68 reads / 333,998 bytes, CODE mask $3FFB. Services are 464 entered / 463
completed with one known $A0F8 call in progress. Fresh-preference counts remain
derived (154 windows, 472/471 services). This stop does not claim service
completion. Full M2 intro and rendered-window acceptance remain open.


## Native effect-stop selector 22

M2.3g25 is complete. Original call/entry/dispatch/body bytes and the full
12,360-byte driver-state transitions establish the stop-effects contract.
The real route is already inactive; an isolated original CPU fixture changes
only the effect flags (and its unused following slot). Native state tests
exercise logical active effects, preserve song/sample/configuration state and
reject assigned physical channels loudly. M4.3 explicitly retains that DMA
stop acceptance. See [sound-driver.md](sound-driver.md#selector-22-stop-effects).

Reference `tmp/m2-driver22-reference.log` and integrated native
`tmp/m2-driver22-native-final.log` exit zero with positive call/return controls.
Native selector 22 is the third completed driver call. Host/sanitizer suite,
clean-build no-float/probe audits, 86-script MAME literal audit, and integrated
logo/CopyBits, picture/palette/AGA, table/fill/RGB, event/cursor, font/text,
geometry/device/world and all 75,616 A5-byte checks pass. The ninth AGA frame
still matches Infogrames. Original MDRV remains absent; the reached stop-effects
call generates no audio event because the effects were inactive.

Next is SOUND DRIVER / SELECTOR 17, Core+$17FC: 135 windows, 480/479 services
with one known driver call in progress, 68 reads / 333,998 bytes, CODE mask
$3FFB. Fresh-preference counts remain derived (161 windows, 488/487 services).
The measured effects playback dependency is next; full M2 remains open.


## Native one-shot effect playback

M2.3g26 is complete. Original selector 17 at Core+$17FC requests 30,783 unsigned
PCM bytes at 8 kHz, no loop, identifier $8000. Full original state/ABI, natural
completion and the entire native sample/converted DMA buffer match their
contracts. The loop-counter pointer is unused on this one-shot route.
Vette's Paula protocol plays period 443, volume 64, with odd-byte padding and
a silent reload. The owned 30,786-byte chip buffer is released only after
quiescing DMA; natural completion and selector 22 share that cleanup.
See [sound-driver.md](sound-driver.md#selector-17-raw-one-shot-effects).

Reference `tmp/m2-driver17-reference-complete.log` and native
`tmp/m2-driver17-native-return-probe.log` both exit zero with positive markers.
Native DMA changes $3F1→$3F0, active/channel become 0/-1, allocation becomes
zero after 232 ticks (231-tick playback plus one VBI-phase allowance). The
host suite, 87-script MAME literal audit, clean no-float/probe link audits and
24 integrated checks pass, including exact effect PCM, nine AGA publications,
logo/CopyBits, pictures/palettes, text/events, geometry/device state and all
75,616 A5 bytes. MDRV remains absent. No rendered-window acceptance is claimed.

Next is SOUND DRIVER / SELECTOR 20, Core+$17C8: 135 windows, 481/480 services
with the known status query in progress, 68 resource reads / 333,998 bytes,
CODE mask $3FFB. Fresh-preference counts remain derived (161, 489/488).
Loops, fractional rates, oversized samples and occupied-voice selection retain
named stops, tracked in M4.3a. Full M2 remains open.


## Effect-status completion and first intro buffer fill

M2.3g27 is complete. Selector 20 returns the first matching identifier's actual
playback state. Original active, completed, stopped-state, missing and duplicate
ID cases pass. Native `tmp/m2-lineto-native-accept.log` (exit zero) observes
199 active query returns followed by the original game's completed query,
with preserved ABI and natural DMA/sample cleanup after 232 ticks. The full
sequence checker passes against `tmp/m2-driver20-reference.log` (exit zero).
No test forces the completed state. See [sound driver](sound-driver.md#selector-20-effect-status).

M2.3g27a is complete: Dark2+$1E44 fills the top 320×140 of the owned GWorld.
Both complete buffers match the expected fill/preservation, and all 648×401
pixel columns match between systems. Port, CLUT, regions and rectangle guards
are preserved. `tmp/m2-paintworld-reference.log` (exit zero) and the same native
run pass the fill check using the existing solid-fill helper. See
[colour drawing](color-drawing.md).

These checks are included in the 27 integrated regressions at the LineTo
checkpoint below. The former 23-query active prefix did not satisfy final
completion acceptance; the 200-query integrated sequence now does.


## Intro line drawing

M2.3g28 is complete. The reached solid one-pixel LineTo at Dark3+$337E
matches the original whole buffer, CLUT, pen-position update and preserved
register/stack contract. Forty-eight original slope/clipping fixtures and five
host buffer cases also pass; see [colour drawing](color-drawing.md).

The instruction/register trace followed two rejected raster hypotheses and
established the Mac's fixed-point edge rule. Reference
`tmp/m2-lineto-registers-reference.log` and integrated native
`tmp/m2-lineto-native-accept.log` exit zero with positive markers. The host
suite, clean no-float/82-symbol probe audits, 90-script MAME literal audit and
27 integrated checks pass, including the full effect-status sequence, exact
PCM/cleanup, offscreen fill, nine startup AGA publications, logo/palette/picture,
text/events, geometry/device state and all 75,616 A5 bytes. The native line
has zero paired pixel mismatches across 648×401.

The new boundary is QUICKDRAW / PAINTRECT, $A8A2, Dan2+$0D52: 139 windows,
689/689 services (baseline 489 plus 200 status queries), none active,
68 resource reads / 333,998 bytes, CODE mask $3FFB, MDRV absent. Fresh-pref
expectations remain derived: 165 windows, baseline 497 plus status queries.
The earlier discovery run reached 115 display publications; only the nine
startup publications have paired AGA acceptance so far.

One observer run (`tmp/m2-lineto-native-final.log`, exit 1) was rejected:
its relocated AGA checkpoint saw eight publications instead of nine. Moving
that observer to the measured first-LineTo state fixed the check without a
runtime change. Repeated cursor observations after the completed sound query
are no longer needed by the startup observer. Full M2 remains open.


## Later intro fill and explicit text boundary

M2.3g29 is complete. The original mode-0 fill at Dan2+$0D52 reuses the
solid eight-bit fill helper. Paired complete buffers/CLUT, 512 covered pixels
(430 changed), surrounding storage, port and ABI checks pass. The matching
state is documented in [colour drawing](color-drawing.md).

The first onward run, `tmp/m2-paintlater-native-discover.log`, timed out
(status 124) and is rejected. Its interrupt snapshot found the Line-A
zero-return loop. A bounded read-only breakpoint at that loop
(`tmp/m2-paintlater-zero-diagnose.log`, exit zero) identified actual DrawText
$A885 at Dan1+$0346; original bytes at +$0342 are `548f3e80a885`.
The disabled-text guard now branches to the existing named-stop report instead
of returning zero. No text rendering or guessed success was introduced.

Original `tmp/m2-paintlater-reference-mode.log` and final native
`tmp/m2-paintlater-native-accept.log` exit zero. Twenty-eight integrated checks
pass: the new fill, prior fill/line/picture/palette/AGA checks, original effect
PCM and real completion, font metrics, events, geometry/device state and all
75,616 A5 bytes. Existing fill-helper host cases, the 91-script MAME literal
audit, no-float/82-symbol probe audits and updated endpoint self-tests also pass.

The fill checkpoint ended at QUICKDRAW / DRAWTEXT, Dan1+$0346, 139 windows,
690/690 services (baseline 490 plus 200 status queries), none active,
68 resource reads / 333,998 bytes, CODE mask $3FFB, original MDRV absent.
Fresh-pref counts remain derived: 165 windows and baseline 498 plus queries.
The selected text state has font 20, size 14, plain face and text mode 1.
Full intro, rendered-window acceptance and M2 remain open.


## Intro copyright text

M2.3g30 is complete. The reached DrawText uses the installed owned font,
measured fractional advances and rectangular clipping. ©/• now have owned
artwork. The obsolete packed four-bit text renderer is removed. No Mac dialog
or menu is drawn. [Font Manager](font-manager.md#intro-drawtext) records the
original string, pen/ABI, pixel bounds and intentional D6 glyph differences.

Original `tmp/m2-drawtext-fixtures-reference.log` exits zero and establishes
natural/repeated text, MoveTo fraction reset and empty-text behavior. Final
native `tmp/m2-drawtext-native-accept.log` exits zero, passes the strict endpoint
and proves the actual DrawText ABI, pen and selected state. Full output bytes
match the independent owned-glyph stencil; visible input columns and CLUT match
the Mac. Allocator row padding differs initially but is preserved independently.
Logical-buffer crops were inspected for coarse placeholder lettering and placement;
this does not replace owner-deferred rendered-window acceptance.

The first discovery run completed normally and passed text, but its audio
observer counted 199 of 201 status queries. It is rejected for full regression
acceptance. Added counter checkpoints show no queries lost across the fill/line
captures in the final run, which observes all 201 queries (200 active, one done)
and natural sample/DMA cleanup after 233 ticks. No acceptance check was relaxed.

The final host suite, 28 integrated regression checks plus DrawText, 92-script
MAME literal audit and no-float/82-symbol probe audits pass. Current boundary:
QUICKDRAW / COPYBITS, Dark+$1DBC, 139 windows, 692/692 services (baseline 491
plus 201 effect-status queries), none active; 68 application resource reads /
333,998 bytes, overlay 31 / 81,214, preparation 64 / 81,786, CODE mask $3FFB,
original MDRV absent. Fresh-pref counts remain derived: 165 windows and baseline
499 plus queries. The owned overlay is 82,026 bytes. Full intro and M2 remain open.


## Title-screen colour copy

M2.3g31 is complete. Dark+$1DBC's srcCopy now remaps different colour seeds
through the existing measured inverse table, preserving the identical-seed
path and existing clipping. [CopyBits](copybits.md#copyright-presentation-colour-mapping)
records original bytes, complete buffers, ABI and D6 pixel differences.

The final native `tmp/m2-copylate-native-callback-safe.log` and original
`tmp/m2-copylate-reference.log` exit zero. The title copy, prior DrawText and
28 earlier integrated checks pass, including the first effect's real completion,
line/fills, logo/palettes, nine AGA publications and all 75,616 initial A5 bytes.
The full host suite, 122 direct/remapped clipping fixtures, 93-script MAME literal
audit, no-float/82-symbol link audits and endpoint/query-accounting rejection
checks pass. Logical client images were inspected; rendered-window acceptance
remains owner-deferred.

Rejected observations are retained locally: the broad conditional discovery
observer timed out before the target; an integrated run hit a GDB “Invalid hex
digit 79” condition error; later runs exposed obsolete endpoint and audio-observer
assumptions. These are not accepted runs. The fill observer now stops at the
original instruction and checks its opcode before entering the dispatcher.
Audio observers match both the original caller return and stack position: a
permitted user-mode VBL callback can enter the shared driver stub first.
Queries during callback/probe intervals are explicitly counted; missing or
inconsistent totals fail. First-effect cleanup checks now run at that completion
point, because the intro subsequently starts a second effect.

A separate bounded post-copy trace (`tmp/m2-copylate-services.log`, exit zero)
explains the variable endpoint count: 64 non-audio services, two non-query driver
calls and additional status queries follow the copy. Six data-file opens and
closes are observed; original PAK payload acceptance remains M2.1c. The constant
service baseline is 557 entered / 556 completed, plus **all** effect-status
queries, including those after the first sound. Fresh-pref baseline 565/564 and
185 windows remain derived, not fresh-start acceptance.

Current boundary: DrawText Dan1+$0346, font 20/plain/14, mode 1, pen (v86,h129),
8 bytes `49fa4d6f74696f6e` (“I˙Motion”). The unowned $FA glyph stops before
rendering. Final counts: 159 windows, 802/801 services with this one active,
245 total status queries; the first effect has 199 observed queries and zero
additional scoped queries in this accepted run. A second effect is active
(starts 2, stops 1, channel 0, 10,202 allocated sample bytes). Resource counts
remain 68 application reads / 333,998 bytes, overlay 31 / 81,214, preparation
64 / 81,786, CODE mask $3FFB, original MDRV absent. M2 remains open.


## Credits spacing and owned dot-above

M2.3g32 is complete. Times/plain/14 GetFontInfo now supplies the measured
12/4/15/0 layout metrics, independently of placeholder bitmap geometry.
The original's line spacing is therefore 16 instead of 14, correcting a
12-pixel baseline error on “I˙Motion”. The owned NFNT includes its dot-above
character; unsupported artwork remains a loud stop. Original instructions
are unchanged. [Font Manager](font-manager.md#credits-line-spacing-and-dot-above)
records bytes, state, fractional pen, ABI and D6 differences.

`tmp/m2-dottext-reference-final.log` (maintained Mac probe with
`AITD_DOT_TEXT=1`) and `tmp/m2-dottext-native-final.log` both exit zero with
positive completion. All 31 integrated checks pass, including both text calls,
title copy, first-effect cleanup, fills/line/logo/palettes, nine AGA publications
and initial A5 bytes. The full host suite, changed-checker selftests, 93-script
MAME literal audit and clean 68020 no-float/82-symbol link audits pass.
Logical credits crops were inspected; rendered-window acceptance is still
owner-deferred. The discovery native run returned the correct text but failed
its obsolete endpoint assertion; it is not an accepted regression run.

After the dot-above DrawText, the accepted observer records nine non-query
services (three each TextWidth, GetResource and DrawText) plus 16 sound-status
queries. No system windows are added. The fixed endpoint baseline is now
566 entered/completed, plus all status queries; fresh-pref 574/574 and 185
windows are derived, not fresh-start acceptance.

Current boundary: LineTo Dan2+$0B5A, 159 windows, 828/828 services, none active,
262 total status queries. The first effect has 201 observed queries and no
additional scoped queries; cleanup completes after 232 ticks. The second effect
is active (starts 2, stops 1, channel 0, 10,202 allocated sample bytes).
The game-window pen (v0,h260) requests (v200,h260), size 1×1, mode 8, fore 16.
Application resources remain 68 reads / 333,998 bytes; overlay 31 / 82,238,
preparation 64 / 82,810, CODE mask $3FFB, original MDRV absent. The owned
font grows by 1,024 bytes; the overlay is 83,050 bytes. M2 remains open.


## Intro game-window lines

M2.3g33 is complete. The visible colour-window adapter reuses the verified
Line8 raster, reports its exact clipped footprint and queues native dirty bounds
through the window PixMap origin. It preserves the offscreen path and rejects
unsupported window/pattern/region states. [Colour drawing](color-drawing.md#game-window-lineto-m23g33)
records the original bytes, complete screen/port contracts and publication.

`tmp/m2-windowline-reference.log`, `tmp/m2-windowline-native-progress.log`
and `tmp/m2-windowline-native-final.log` exit zero with positive completion.
The focused progression run records 112 window lines and 848 publications before
the next stop. The final full run passes all 32 integrated comparisons: the new
window line and AGA publication, both credits text captures, title copy, earlier
line/fills, first-effect completion, logo/palettes, early AGA publications and
all initial A5 bytes. The host suite, three added translated-window/dirty-bound
fixtures, all 48 original slope fixtures, changed-checker selftests, 93-script
MAME literal audit and clean 68020 no-float/82-symbol probe audits pass.

The first native discovery run captured a valid line but expired later in
Planar8 conversion at 240 seconds; it is rejected. The following instrumented
run demonstrates advancing line/frame counters and reaches a named stop normally.
No performance change or game timing change was made. The first line changes
exactly 200 pixels and dirties global (150,420,350,421). Published frame 117
matches that complete framebuffer, with identical queued/active bitplanes and
copper and VBI line zero. Both full input screens equal the preceding title
captures, including their documented Mac-desktop/placeholder differences.

## Accented intro credit and original intro return

M2.3g34 is complete. MacRoman $89 now has owned circumflex-A artwork; the
original `5961896c` (“Yaâl”) bytes and all spacing remain unchanged. The paired
contract and explained placeholder pixels are in [Font Manager](font-manager.md#accented-a-credit-glyph-m23g34).

`tmp/m2-accenttext-reference.log` and `tmp/m2-accenttext-isolated-native.log`
exit zero with positive completion. The native run returns from the original
intro at Dark+$5220 with D0 zero after 5,606 frames. Its next named stop is
CopyBits $A8EC at Dan2+$07FA (M2.3g35). All 33 integrated checks pass in
`tmp/m2-accenttext-regressions.log`: the accented/copyright/dot-above text,
window-line/AGA publication, title colour mapping, fills/lines, first-effect
completion, logo/palettes, earlier publications and all 75,616 A5 bytes. The
full host suite and clean no-float/82-probe build passed for the glyph change;
changed-checker selftests, Python syntax and the 93-script MAME audit pass.

The final capture records 159 system windows, 2,558/2,558 services, none active,
and 1,310 status queries: fixed service baseline 1,248/1,248. The derived fresh
baseline is 1,256/1,256 with 185 windows; this is not fresh-start acceptance.
All sixteen effects have started and stopped, with channel -1 and zero sample
allocation. Driver calls are status queries plus 34. The final publication is
5,607/5,607. Application/overlay counts remain 68 / 333,998 and 31 / 82,238,
preparation 64 / 82,810, CODE mask $3FFB, 58 low-memory sites, 244 resource
records and original MDRV absent.

A 1,200-second timeout, a stale text-only endpoint dump and two interrupted
connections are rejected. M2.3g34a fixes the shared debugger-port collision;
only the isolated normal-completion capture supplies final acceptance. The
legacy standalone AGA observers have stale publication assumptions; M2.10a
records that gap. The integrated frame-9 and window-line frame-117 publication
checks pass. Full intro frame comparison and rendered-window acceptance remain
open; this is not completion of M2.


## Post-intro offscreen CopyBits

M2.3g35 extends the existing owned eight-bit copy adapter to a locked offscreen
destination, using its own colour table/inverse and storage bounds. The original
20×8 call and its exact preservation/ABI contract are in [copybits.md](copybits.md).
There is no new blitter, font substitution or game-code patch. Other unsupported
transfer forms remain loud stops.

`tmp/m2-postcopy-reference.log` and `tmp/m2-postcopy-native.log` both exit zero.
Every defined destination pixel matches the original; full buffers obey the
independent copy/preservation model. All drawn atlas pixels match, while
unpainted allocation bytes and row padding are proved untouched. Native screen
dirty state stays clear and queued/presented counters stay 5,554/5,554 across
this offscreen call. The original startup intro returns D0=0 at Dark+$5220,
with 5,553 frames and 47,451 ticks on the temporary fast A4000/68020 model.
Frame totals differ from the cycle-exact A1200 run; this is state-pair service
evidence, not the pending fixed-seed full-intro acceptance (M2.10).

Execution advances to GetKeys $A976 at Dan1+$583A. The capture reports 194
system windows and 2,721/2,721 completed services, none active, including 1,367
effect-status queries: fixed baseline 1,354/1,354. The derived fresh baseline
is 1,362/1,362 with 220 windows; fresh-start acceptance is still M2.4. All 16
effects have stopped, no sample/channel allocation remains, and original MDRV
is absent. Final publication is 5,556/5,556. The other ledgers remain 68 reads /
333,998 application bytes, 31 / 82,238 overlay bytes, 64 / 82,810 preparation
bytes, 58 low-memory sites, CODE mask $3FFB and 244 resource records.

The full host suite, no-float/82-probe build audits and all 34 integrated
comparisons pass. Changed checker selftests and the 94-script MAME literal
audit pass. The earlier input-only fast capture is rejected: GDB reported
“Cannot execute this command while the target is running,” returned zero and
produced no dump. Only the complete integrated run supplies native acceptance.
The existing standalone AGA observer limitations remain tracked in M2.10a.


## Original GetKeys polling

M2.3g36 implements the original Dan1+$583A call using the current native raw-key
levels and the existing Mac virtual-key translation. This follows Vette's
polling-map approach, independent of queued key events. Aliases such as both
Shift keys are combined. [events.md](events.md) records the measured ABI and
map layout; original game instructions are unchanged.

The original MAME capture `tmp/m2-getkeys-reference.log` exits zero with released,
held A and released A maps. The native `tmp/m2-getkeys-window-core-final.log`
exits zero with eleven guarded key snapshots, ten preserved queued transitions,
and the existing window/file/clock/Paula checks. The production build passes
no-float and 82-probe audits; the host suite, 95-script MAME literal audit and
checker rejection cases pass.

`tmp/m2-getkeys-native.log` exits zero and all 35 integrated comparisons pass,
including the original GetKeys caller, stack, D0.w, preserved registers and
exact guarded output. The startup intro returns D0=0 with 5,563 frames and
47,371 ticks on the temporary A4000/68020 model. Publication ends at 5,566/5,566.
The next stop is native sound-driver selector 13, Core+$137E, argument zero.
That user-mode service is explicitly pending: 2,750 entered / 2,749 completed,
active=1, including 1,363 completed effect-status queries. The fixed baseline
is 1,387/1,386 with 210 system windows. The derived fresh baseline is
1,395/1,394 with 236 windows, still awaiting M2.4 acceptance.

All sixteen effects have stopped and no sample/channel allocation remains.
Driver calls are queries plus 35. Original MDRV remains absent. Application
resource reads advance to 70 / 349,400 bytes; overlay remains 31 / 82,238 and
preparation 64 / 82,810, with 244 resource records, CODE mask $3FFB and 58
low-memory patches. These are resource reads, not M2.1c PAK payload acceptance.
The pending selector is M2.3g37. Full intro-frame and rendered-window acceptance
remain open; the standalone AGA observer limitations remain M2.10a.


## Original sound-driver control word

M2.3g37 adds selector 13’s measured low-word setter. The actual zero argument
and the independent original-CPU $12345678 fixture pass exact full-state and
ABI checks in `tmp/m2-driver13-reference.log` (exit zero). The native model
retains the word without starting a voice; unsupported music calls remain stops.
See [sound-driver.md](sound-driver.md).

The clean 68020 production build passes no-float and 82-symbol audits. All host
tests, 96-script MAME literal audit, checker rejection fixtures and all 36
integrated comparisons pass. `tmp/m2-driver13-native-full.log` preserves the
complete raw debugger output of the exit-zero run; the runner’s displayed
`tmp/m2-driver13-native.log` was limited to its final 3,000 lines. Future full
intro observations should retain the complete output for early-startup checks.

Original intro return is D0=0 at 5,572 frames / 47,493 ticks; the final publication
is 5,575/5,575. The native driver returns from selector 13 and reaches selector 0,
argument $87, at Core+$138C. Counts are 210 system windows and 2,754/2,753 services,
including 1,366 completed effect-status queries and the explicit pending service.
The fixed existing-prefs baseline is 1,388/1,387; fresh 1,396/1,395 and 236 windows
remain derived expectations awaiting M2.4. Driver calls are queries plus 36.
All sixteen effects are stopped with no allocated sample/channel. Resource reads
remain 70/349,400 application bytes, 31/82,238 overlay bytes and 64/82,810
preparation bytes. The 244 records, 58 low-memory patches and CODE mask $3FFB
remain unchanged. MDRV is absent. Rendered acceptance and M2.10a remain pending.


## Song input prerequisite

M2.3g38a provides portable SONG/MIDI/INST/sample descriptions, without changing
the production driver. `tmp/m2-driver0-reference.log` completes at the original
selector-zero return after 285 observed service pairs, with 41 detached, locked,
nonpurgeable resources and MIDI 905 armed. `tmp/m2-song-events-reference.log`
completes its original preflight at 3,736 note events. The C++ helper matches
all events and the seven-instrument/28-sample graph exactly in
`tmp/m2-song-inputs-paired.log`. The captured song/MIDI bytes also match the
original archive. See [sound-driver.md](sound-driver.md) for the format details,
rejected observer and reproducible checker. Runtime sequencing, Paula playback
and selector-zero acceptance remain M2.3g38; this is no claim of working music.

The full host suite exits zero in `tmp/m2-song-inputs-host-tests.log`, including
the 98-script MAME literal audit. Timeout, altered-note and observer-error
rejection checks pass in `tmp/m2-song-inputs-rejections.log`. Production code
does not include the new helper yet, so native acceptance remains the preceding
selector-13 capture rather than an unnecessary replay of unchanged code.


## Song clock prerequisite

M2.3g38b adds a portable integer sequencer clock without changing production.
The original direct-entry observer finishes normally (exit zero) in
`tmp/m2-song-clock-reference.log`. All 3,736 live notes match the helper's event
fields, MIDI positions, tempo steps and exact sequencer entries through pulse
8,785; paired acceptance is `tmp/m2-song-clock-paired.log`. The complete host
suite exits zero in `tmp/m2-song-clock-host-tests.log`, including the 100-script
MAME literal audit. Six negative checks reject timeout, missing completion,
observer error, changed step/note and duplicate events in
`tmp/m2-song-clock-rejections.log`. No unchanged native intro replay is required
for this pure helper. Resource ownership, safe-point scheduling and Paula music
remain M2.3g38, and selector zero still stops explicitly.


## Song sample prerequisite

M2.3g38c adds native sample selection, integer pitch and bounded Paula PCM
conversion. The full live original capture matches 1,860 allocated note-ons,
eight full-voice drops and 1,868 note-offs, including all 128 pitch ratios.
`tmp/m2-song-voices-paired.log` passes the original ownership, preflight, exact
clock and live-voice checks together. Every note's converted PCM passes the
independent stream oracle; 27 synthetic guarded streams cover loop parity and
high-note decimation. Five evidence rejection cases also pass. The host suite
exits zero in `tmp/m2-song-voices-host-tests.log`; standalone 68020 compilation
uses only integer arithmetic. [Sound driver](sound-driver.md) records the
measured clock and D8 waveform conversion. Production remains unchanged and
selector-zero integration is still M2.3g38.


## Native SONG 135 playback

M2.3g38 is complete. The original selector-zero caller returns successfully
with its measured ABI and 41 detached, locked resources. The full native capture
is `tmp/m2-song-runtime-discover-full.log` (exit zero). All 36 prior integrated
checks pass in `tmp/m2-song-runtime-regressions.log`. The intro returns D0=0
at 5,584 frames / 47,708 ticks; final publication is 5,587/5,587. The next named
stop is selector 15, argument zero, Core+$0FC8 (M2.3g39).

The dedicated `SONGPROBE=1` build avoids replaying the intro for full music
validation. `tmp/m2-song-probe-native-full.log` exits zero and matches all
3,736 original timed events, two complete Paula PCM/DMA variants, effect
priority/natural completion and resource/channel cleanup. It runs native code
and original resource data; no MDRV or SMOD code executes. Details and
reproducible checks are in [sound-driver.md](sound-driver.md).

The host suite exits zero in `tmp/m2-song-runtime-final-host-tests.log`, and
eight rejection checks pass in `tmp/m2-song-runtime-rejections.log`. Production
and fixture builds pass no-float audits with 83/88 retained probe symbols.
The initial integration exposed unavailable integer `__udivdi3` at link time;
bounded integer division replaces it, with 2,000 independent host comparisons.
No timeout or failed link is counted as acceptance. The integrated run used a
123-probe build; the focused fixture and final production use their normal
88/83-symbol configurations. The final release-error guard does not change
successful disposal behavior.

At the new stop: 249 system windows, 2,752/2,751 services with one explicit
pending request and 1,363 completed effect queries. The fixed baseline is
1,389/1,388; fresh-pref 1,397/1,396 and 275 windows remain derived, awaiting M2.4.
Driver calls are queries plus 37. All sixteen intro effects are stopped with
no remaining effect allocation. Application resources are 109 reads / 826,832
bytes; overlay 31 / 82,238 and preparation 64 / 82,810. The 244 metadata records,
58 low-memory patches and CODE mask $3FFB remain unchanged. Song ownership is
real, but normal startup reaches the next selector before its first note; the
complete playback evidence comes from the dedicated fixture. M2 and rendered
acceptance remain open.


## Driver clock query

M2.3g39 is complete. Selector 15 returns elapsed driver ticks as a full 32-bit
value, with the measured original register/stack and condition-code contract.
The original query, independent callback-clock count and seven boundary cases
pass in `tmp/m2-driver15-reference.log`, `tmp/m2-driver-clock-reference.log`
and `tmp/m2-driver15-flags-reference.log` (all exit zero).

`tmp/m2-driver15-native-full.log` exits zero after original intro return
(D0=0, 5,564 frames / 47,476 ticks), song ownership and the clock call. The next
named stop is selector 4 at Core+$1FC8. All 36 prior comparisons pass in
`tmp/m2-driver15-regressions.log`. The subsequent flag correction passes the
short real-trap fixture in `tmp/m2-driver15-flags-native-fixed-full.log`; that
corrected fixture, rather than the preceding integrated run, establishes CCR
acceptance. Its initial outside-service resource read is a rejected fixture.
See [sound-driver.md](sound-driver.md) for the exact values and test commands.

Final publication is 5,567/5,567, with 249 system windows and 3,822/3,821
services, one pending. There are 1,364 completed effect-status queries and
1,402 driver calls. All 16 effects are stopped with no remaining effect DMA.
Music is active at 820 events / pulse 1961, with 410 note starts, 152 steals and
zero drops. The 41 owned resource bodies match the original; original MDRV is
absent. Application reads remain 109/826,832 bytes; overlay 31/82,238,
preparation 64/82,810, 244 records, 58 low-memory sites and CODE mask $3FFB.

Live music adds timing-dependent safe-point services. The observed baseline is
2,458/2,457 after subtracting effect queries; observer minima are 1,390/1,389
(existing prefs) and derived 1,398/1,397 (fresh). Exact window/resource counts
and the single-pending-service invariant remain required. Fresh-start, rendered
and full-intro frame acceptance remain open. The full host suite and final
production/fixture no-float and 83/87-probe audits pass.


## Song status query

M2.3g40 is complete. Selector 4 reproduces the original enabled/control/track
scan and D0/D1/CCR result. The original call and seven isolated cases pass in
`tmp/m2-driver4-reference.log`; the native original call passes in
`tmp/m2-driver4-native-full.log` (both exit zero). All 36 prior integrated
comparisons pass in `tmp/m2-driver4-regressions.log`, with song resource
ownership and the clock query separately paired from that same capture.
The first interrupted native run is not accepted evidence.

The intro returns D0=0 at 5,554 frames / 47,452 ticks; final publication is
5,557/5,557. The next stop is RectRgn at Dark+$3D46, outside a deferred service:
3,825 entered/completed, zero pending, 249 windows. There are 1,365 completed
effect queries and 1,408 driver calls; all 16 effects are stopped without
remaining DMA allocation. Song playback is at 820 events / pulse 1963,
410 starts, 154 steals and zero drops. The 41 song resources remain owned,
with application reads 109/826,832 bytes, overlay 31/82,238, preparation
64/82,810, 244 resource records, 58 low-memory sites and CODE mask $3FFB.
Original MDRV remains absent.

The observed service baseline is 2,460/2,460 after effect queries. Endpoint
checks require equal service totals and preserve exact resource/window counts;
timing-dependent music work is not forced to an exact service total. Existing
minimum 1,390/1,390 and fresh derived 1,398/1,398 remain lower bounds.
The production build passes no-float and 83-probe link audits. The host suite
passes in `tmp/m2-driver4-final-host-tests.log`. Standalone endpoint guards
are advanced to the observed stop; their individual emulator replays are not
claimed. Stale standalone AGA publication assumptions remain M2.10a.

## RectRgn transition (M2.3g41)

The next original call at Dark+$3D46 uses `$A8DF`, RectRgn. Original
+$3D36–$3D47 bytes are `2f39ffff40342079ffff3db248680016a8df`.
`tmp/m2-rectrgn-reference.log` exits zero and captures the caller, both complete
regions and the unchanged source rectangle. The owned empty ten-byte region
becomes `000a0000000000c7013f`; the handle and body remain unchanged. All data
registers and A2–A6 are preserved; A0 returns the region handle, A1 its body,
and eight argument bytes are removed. Original CPU-executed GetHandleSize,
HGetState and HandleZone confirm ten bytes, unlocked state and the same heap.
Five rejected-evidence cases cover timeout, absent completion, observer error,
wrong return register and wrong size.

The native implementation covers this owned ten-byte, nonempty rectangular
conversion. Broader resizing and empty/inverted forms remain named RectRgn
stops and are explicitly retained under M2.8. No dialog, menu or screen pixels
are drawn. The production build passes no-float and 83-symbol link audits.
The host suite exits zero in `tmp/m2-rectrgn-host-tests.log`.
`tmp/m2-rectrgn-native-full.log` exits zero and matches the complete original
region/rectangle and register/stack/heap contract. All 36 prior integrated
comparisons pass in `tmp/m2-rectrgn-regressions.log`; song ownership and driver
clock/status checks also pass using that same capture. The new stop is
EmptyRgn at Dark+$4182. Intro return is D0=0 at 5,562 frames / 47,482 ticks;
final publication is 5,565/5,565. There are 249 windows, 5,745/5,745 completed
services, 1,363 effect queries and 2,908 driver calls. All 16 effects have
stopped with no remaining allocation. Music reaches 1,519 events / pulse 3466,
761 starts, 447 steals and zero drops. Resource counts remain 109/826,832 app,
31/82,238 overlay, 64/82,810 preparation, 244 records and 58 low-memory sites.
MDRV remains absent. The owner-requested page-turn speedup is next in the queue;
full M2 acceptance remains open.


## Kalms runtime conversion (M2.3g41p1)

The owner's focused 68020 optimization replaces the scalar runtime C2P loop
with Mikael Kalms' public-domain `normal/c2p1x1_8_c5_gen.s`, unchanged from
upstream commit `d8ecf79a3325615305dd800ae7704b518e0d9dda`. A small C ABI wrapper
converts normalized dirty rows with 640-byte source stride, 320-byte output
stride and 40-byte plane separation. It preserves callee-saved registers and
uses no FPU, blitter, self-modifying code or interrupt callback. The scalar
converter is compiled only for host tests; production has no C fallback.

The five-frame native AGA fixture exits zero in `tmp/m2-kalms-aga-full.log`.
Its independent decoder verifies every pixel, partial-update preservation,
palette-only updates, all eight plane pointers, all 256 colours, alternating
buffers, an unaligned (161,151) source origin, VBI publication and cleanup.
Host tests pass in `tmp/m2-kalms-host-tests.log`. Production passes the no-float
and 83-symbol link audits; its symbol table contains the Kalms entry points
and no `Planar8::convert` implementation.

The first integrated run reached the expected EmptyRgn stop, but its observer
incorrectly checked song *initialization* after playback had started. That run
(`tmp/m2-kalms-intro-full.log`, exit 1) is not acceptance. The unchanged check
now runs immediately after driver initialization, before playback. Removing
exploratory profiling leaves the production executable byte-identical to the
first tested Kalms executable. The clean repeat (`tmp/m2-kalms-final-full.log`)
exits zero, but its saved-state checker exposes another overly broad observer
boundary: the original return trampoline services queued VBL callbacks, so
music voices can progress between original JSR entry and return. Configuration
is unchanged; the changing bytes belong to song voices and channel assignments.
The clock observer now additionally captures the complete 94-byte driver state
at query-dispatch entry and return, before those callbacks. The checker requires
exact equality at that boundary and still checks original caller/return ABI,
clock bounds and configuration preservation across the original call.

The earlier 120-field drawing profile starts during title/credit drawing,
not a proven book-page state. Its different CLUT seeds do not establish that
the book palettes differ. The later book-specific profile and actual palette
comparison are recorded below. Full intro frame acceptance remains M2.6/M2.10; rendered-window
verification remains owner-deferred. No original game instructions, palette
mapping, animation calls or game delays change in this optimization.

Final acceptance: `tmp/m2-kalms-boundary-full.log` exits zero at EmptyRgn,
Dark+$4182. All 40 integrated comparisons pass in
`tmp/m2-kalms-boundary-regressions.log`. The entire query-dispatch state is
unchanged; five corrupted/failed evidence cases are rejected in
`tmp/m2-kalms-query-rejections.log`. All 16 effects stop without residual
allocation, MDRV stays absent, and all 10,901 deferred services complete.
Resource totals remain 109/826,832 app, 31/82,238 overlay, 64/82,810 preparation,
244 records, 58 low-memory sites and 249 OS windows.

The original intro returns D0=0 at 18,262 emulated ticks / 3,823 publications,
compared with 47,482 ticks / 5,562 publications in the accepted scalar run
`tmp/m2-rectrgn-native-full.log`: about 2.60× sooner (61.5% fewer ticks).
Final publication is 3,826/3,826. This is a whole-intro observation on the same
owner-approved A4000/68EC020 test configuration, not isolated book-page cost,
real-hardware timing or a frame-rate claim. The earlier clean repeat returned
at 18,231 ticks, before the observer boundary correction. Explicit dirty bounds,
logical outputs and VBI publication remain unchanged; faster execution can
coalesce a different number of pending presentations.


## Book-frame batching and profile (M2.3g41p2)

`make -C amiga BOOKPROFILE=1` (after clean) and the bounded
`GDBSCRIPT=book_profile.gdb` observer sample the original decreasing book fold
from column 160 to 150. This is six PaintRects and one CopyBits at a repeatable
game state, not a presentation-count trigger. `tools/mac_book_frame.lua`
captures those same two original Mac positions; no random-dependent state
is selected by this book step. `tools/check_book_profile.py` checks original
call bytes, complete native before/after logical buffers and CLUTs, the Mac
client pair and independent AGA bitplane/copper decoding.

The Kalms-only baseline (`tmp/m2-book-profile-baseline-full.log`, exit 0)
takes 721,217 beam-epoch units and four presentations. Batching repeats
(`tmp/m2-book-batch-profile-full.log` and `tmp/m2-book-batch-aga-full.log`,
both exit 0) take 569,859 and 569,998 units, each with one presentation:
about 21.0% less elapsed emulated time. All six baseline/optimized captures
(begin/end full screens and CLUTs, source/destination CLUTs) are byte-identical.
The second repeat independently passes all 64,000 AGA pixels, eight plane
pointers, 256 colours, crop and VBI publication. These are observations on the
owner-approved A4000/68EC020 test configuration with instrumentation, not
real-hardware timings or shipping frame-rate claims.

The repeated profile attributes 151,749 units to back-buffer synchronization,
113,383 to CopyBits (including 38,371 for colour-map construction), 68,018 to
Kalms conversion and 32,247 to six PaintRects. Presentation totals 232,418.
These categories are inclusive/nested and must not be added as independent
costs. Synchronization remains the largest individual measured phase; broad
performance work remains deferred. This change only batches completed steps.

Actual source/destination RGB16 differences in this sample are indices
1, 15 and 191, despite unchanged seeds throughout the interval. The source
values are black, white and black respectively; destination values are
(63479,63479,63479), (25443,25443,25443), and (2056,6168,8481).
Colour translation is retained. This measurement does not assert equality or
differences for every intro palette.

The Mac reference (`tmp/m2-book-reference.log`, exit 0) matches both logical
palettes excluding their process-local seed. Every client pixel matches except
653 beginning / 594 ending copyright pixels: each lies in D6's established
placeholder region and corresponds to a differing title-source glyph pixel.
Native batching introduces no additional differences. Rendered host-window
acceptance remains owner-deferred; full intro frame acceptance remains M2.6/M2.10.

Production acceptance: `tmp/m2-book-production-full.log` exits zero at the
expected EmptyRgn (Dark+$4182). All 840 started book batches complete, with none
active at the endpoint; all 16 effects stop and release their allocation.
All 10,901 deferred services complete, with 249 OS windows and unchanged
resource totals. Original MDRV remains absent. The intro returns D0=0 at
14,938 emulated ticks / 956 publications, versus 18,262 / 3,823 with Kalms
alone: 18.2% fewer ticks on the same test configuration. Final publication is
959/959. Host tests and the production no-float/86-symbol audits pass.
Five corrupt/timeout evidence cases are rejected by the book verifier.

The first 40-check pass exposed one stale observer expectation: window LineTo's
published frame was required to contain only that line. The line's original
ABI, 200-pixel update and full-buffer preservation still pass unchanged.
Publication now correctly contains the entire first book step. A separate
original capture (`AITD_BOOK_COLUMN=260`, `tmp/m2-book-first-reference.log`,
exit 0) establishes its matching completed 260→250 state. The updated checker
requires successful reference status and matches all client pixels/palette,
with only the established D6 copyright exception, before independently decoding
AGA output. All 40 comparisons pass in `tmp/m2-book-production-regressions.log`.
No runtime code was changed to resolve this observer expectation.


## EmptyRgn (M2.3g42)

The original call at Dark+$4182 has bytes
`42272f39ffff4038a8e24a1f6608`: a byte Boolean in a word-aligned result slot,
the region handle at A5−$BFC8, then a test of the returned byte. The Mac capture
`tmp/m2-emptyrgn-reference-abi.log` exits zero with the canonical empty
`000a0000000000000000` region unchanged. It writes result byte 1 while
preserving padding `$12`, pops four argument bytes, returns D1=0,
A0=region body+8 and A1=caller PC+2, and preserves D0/D2–D7/A2–A6 and MemErr.
`tools/mac_emptyrgn.lua` and `tools/check_emptyrgn.py` retain that paired
contract. Seven negative evidence cases reject timeout, missing return,
incorrect Boolean/padding/registers and corrupted caller/region bytes.

The implementation accepts the measured owned ten-byte canonical empty
region, changes only the result byte and measured registers, and leaves its
handle/body and memory error untouched. Other region forms remain named
EmptyRgn stops, with nonempty/complex acceptance explicit in M2.8.
The native observer captures the original caller, complete region and ABI
before allowing the full startup regression to reach its next actual stop.

The first native attempt ended when FS-UAE quit before the post-intro checkpoint;
it is not acceptance. The repeat reached the original intro return address with
a nonzero D0 and was rejected by the observer's uninterrupted-intro assumption.
The owner authorizes Enter to advance service-check runs. The observer now records
D0 at that return and proceeds to the actual service contract; an interrupted
intro cannot count as full-intro/frame/timing acceptance. A PID-targeted host-key
permission check denied event posting, so no key was sent by the agent.

The service run (`tmp/m2-emptyrgn-service-full.log`) captures a matching native
EmptyRgn result: true with native padding `$DE` preserved, identical region,
D1=0, A0=body+8 and A1=caller+2. It proceeds to srcCopy at Dark+$1E4A with
271 OS windows and all 12,004 services completed. Its final observer rejects
the obsolete 249-window endpoint, so that run's exit 1 is not final acceptance.
The corrected observer pins the measured CopyBits site and the additional 22
windows for the final acceptance run. The intro itself returned
D0=0 at 14,936 ticks. At the new stop, effect 17 is active after the earlier 16
completed; this is further original execution, not an intro cleanup claim.

Final acceptance: `tmp/m2-emptyrgn-final-full.log` exits zero at the measured
CopyBits stop, Dark+$1E4A. All 41 comparisons pass in
`tmp/m2-emptyrgn-regressions.log`, including the original/native EmptyRgn pair
and all prior startup contracts. There are 271 OS windows, 12,007/12,007
completed services and 960/960 publications; all 840 book batches complete.
Resource totals remain 109/826,832 application, 31/82,238 overlay,
64/82,810 preparation, 244 records and 58 low-memory sites. Original MDRV
remains absent. Effect 17 is legitimately active at this later stop after the
first 16 have completed. The 68020 no-float/86-symbol build audits and the
updated shared startup-checker rejection test pass. Original call bytes and
all unsupported region forms retain their explicit checks/stops.


## Direct-map CopyBits (M2.3g43)

The original Dark+$1E4A call passes the selected locked GWorld's direct
PixMap. The adapter now accepts that pointer alongside its colour-port bitmap;
all existing ownership, storage, colour and clipping checks still apply.
Original bytes and the measured 8×4 copy contract are in [copybits.md](copybits.md).
The original capture (`tmp/m2-stepcopy-reference.log`) and uninterrupted
production capture (`tmp/m2-stepcopy-production-full.log`) both exit zero.
Full source/destination preservation, all 32 copied pixels, identical palettes,
unchanged records and the original stack/register contract pass. Eight negative
evidence cases reject incomplete/invalid captures. The production build passes
the no-float and 86-symbol audits on the maximum-speed 68030 test configuration.

All 42 integrated comparisons pass (`tmp/m2-stepcopy-regressions.log`), ending
positively at Dark+$1E4C instead of waiting for another unsupported call.
There are 271 OS windows, 11,916/11,916 completed services and 960/960
publications; all 840 book batches complete. Resource totals remain
109/826,832 application, 31/82,238 overlay, 64/82,810 preparation, 244 records
and 58 low-memory sites. Original MDRV remains absent. Four checkers initially
rejected the renamed absence marker; their readers now require the positive
checkpoint marker. No emulator rerun was needed for this evidence-reader fix.
This is not full intro acceptance: black story pages and car/frog progression
remain M2.3g44; rendered-window acceptance is still owner-deferred.


## Story/menu investigation (M2.3g44, incomplete)

Two original Mac framebuffer runs finish normally with 48 captures each:
`tmp/m2-story-reference-sequence.log` leaves input untouched after screen-mode
selection; `tmp/m2-story-newgame-reference.log` presses Return after captures
32 and 33. The first shows the in-game new-game menu, the car approaching the
camera, then the pond/frog scene. The second shows the portraits after the first
Return and the attorney letter after the second. The letter remains waiting
through capture 48. Story pages therefore require their ordinary new-game and
page inputs; they are not part of automatic idle playback. The DOS screenshot
is content context, not the Mac layout oracle.

`tmp/m2-story-native-sequence.log` exits zero after four byte-checked original
checkpoints. At Dark+$5220, D0 is zero, all 840 book batches have completed,
956 frames are published and no dirty data is pending. Independently decoded
software-selected AGA planes and copper colours equal the logical viewport at all four
checkpoints (the logo, end of logo animation, title and end of credits).
The first exploratory observer incorrectly expected Dark2 to be resident before
loading; its byte guard rejected the run. The corrected observer waits for the
first CopyBits before resolving the later segment addresses.

The subsequent menu observer reaches Dan1+$1374 at tick 14,970 and its natural
900-tick timeout at +$13E6, tick 15,870. Both capture the complete in-game menu
with 958/958 publications, no dirty pixels, no pending frame and no active book
batch. Both logical viewports and software-selected AGA planes/copper agree. The border and
three choices are visible in these decoded buffers, with the expected D6
placeholder-font difference. This does not establish host-window appearance or
fix the owner-visible black interval. The idle-demo continuation ends with exit 1 at `SOUND DRIVER / EFFECT VOICE
STEAL`, selector 17, Core+$17FC, tick 26,556. It has 990/990 publications and
no dirty/pending frame. Its last road-scene logical pixels and palette also
match the software-selected AGA planes/copper. Occupied effect-slot replacement is now the
prerequisite M2.3g44a; no complete native car/frog acceptance is claimed.

The occupied single-effect prerequisite M2.3g44a is complete: the final production
run passes the former stop with paired age/ABI/sample ownership checks. All 42
startup comparisons and all 3,736 complete-song events pass. See
[sound-driver.md](sound-driver.md#occupied-effect-replacement-m23g44a). The full
car/frog sequence and reported black interval remain M2.3g44 work.

The earlier snapshots read `m_chip` and `m_copper`, establishing only intended
presentation. M2.3g44j below adds actual colour-RAM readback at the idle menu;
other scene states and actual host-window appearance remain unverified.

The post-DisposeRgn observer (`tmp/m2-story-idle-current-full.log`, exit 1)
reaches an unimplemented relative Line, `$A892` at Dark3+$354A, at tick 21,313.
This prerequisite now passes the relative-Line checks below; it is not sequence acceptance. Its menu checkpoints
at ticks 1,826 and 2,726 have exactly 900 ticks between them, 13 queued/presented
frames and no pending drawing. Both independently decoded AGA buffers match
the logical viewport/palette. The VBI publication range is scanlines 0–1, with
zero late publications; display DMA remains enabled. Book batches remain zero.
The headless original endpoint observer (`tmp/m2-story-endpoint-reference.log`)
exits normally at Dark+$552C, tick 32,015, after the measured pond cleanup.
This validates the endpoint used by the native observer, but does not establish
native car/frog progression or actual hardware palette contents.

## Routine-test Enter skip (M2.3g44b)

Owner priority 2026-10-01: stop repeating the book for routine service checks.
Build with `INTROSKIP=1`; it posts normal Enter down/up through MacInput's queue
at the first intro LineTo. Game instructions and timers remain unchanged. The
key is released at GetKeys or after at most 120 Mac ticks. Production builds
exclude this diagnostic input. Use this flag for routine runs; uninterrupted
book playback is reserved for tests specifically requiring that animation.

`tmp/m2-introskip-native-final.log` exits zero: the original Dark+$53DA skip
branch returns D0=1 at tick 1738 after the key-down at 1668, with zero book
batches. The observer sees key-up at 1788 and then verifies state 2, Enter
released and no pending book batch. `amiga/intro_skip.gdb` guards the original
`4a076700` bytes and requires both skip and release. Build audits pass (no
floating-point instructions, all 88 probe symbols). The first observer waited
at the uninterrupted return, then an early-release assertion and an optimized
breakpoint-condition warning were corrected; only the clean final run counts.

The owner supplied actual FS-UAE logo/title/menu/portrait/letter screenshots
`FS-UAE_Full_261001-0912_01` through `_04` and `FS-UAE_Full_261001-0913_00`.
They establish visible rendering after normal Enter along this route, with the
known placeholder-font differences. The preceding black interval and unattended
car/frog progression remain open. `tmp/m2-story-native-after-effect.log` was
interrupted when switching to this input-driven workflow; it is not a pass.

## Pond polygon recording (M2.3g44c)

The Enter-skipped idle route reaches the pond background. Its first polygon
recording now matches the original across OpenPoly, MoveTo, ten LineTo calls
and ClosePoly, including all polygon bytes, changed/preserved port fields,
calling contract, heap ownership and unchanged drawing buffers. Both accepted
reference and native observers exit zero; native book batches remain zero.
Region recording, one-pixel expansion, polygon disposal and masked copying are
verified (M2.3g44d–g). DisposeRgn at Dark+$3058 now also passes paired cleanup checks;
M2.3g44g1 fixes the intermittent SIGILL by moving polygon scratch storage off
the shared supervisor stack. The forced-interrupt regression and paired
native region/heap checks pass. Contracts, host checks,
rejected evidence and the exact acceptance commands are recorded in
[picture-drawing.md](picture-drawing.md#pond-scene-polygon-recording-m23g44c).

## Pond region disposal (M2.3g44h)

`tools/mac_disposergn.lua` measures DisposeRgn at Dark+$3058 after the masked
pond copy. Original caller bytes at +$3056 are `2f14a8d9429470ff29400004`:
pass the region through A4, dispose it, clear that owning field, then prepare
−1 for the adjacent field. The 128-byte region releases 136 physical Mac heap
bytes. The Mac links the freed master into its free-master chain, returns D0=0,
A0=the disposed handle and MemErr=0, pops four argument bytes, and preserves
D1–D7/A2–A6. A1 is scratch. Port, PixMap, pixels, CLUT and visible/clip regions
are unchanged. The reference run ends normally with its explicit completion
marker in `tmp/m2-disposergn-reference.log`.

The native implementation uses the existing owned-handle allocator. Its
`publish()` reconstructs the free-master chain, so a freed master is not
required to contain zero. The observer measures the disposal after shared
trap-entry work has published any preceding drawing. The native run exits zero, with a 152-byte physical block reclaimed, the
expected free-master link, all retained allocation records unchanged, and no
changes to port, PixMap, pixels, CLUT or visible/clip regions. Original cleanup
continues at Dark+$305E with the owning field cleared; book batches remain zero.
The paired checker passes:

```sh
python3 tools/check_disposergn.py --reference tmp/m2-disposergn-reference.log --status 0 \
  --native tmp/m2-disposergn-native-full.log --native-status 0
```

`make host-tests` and the native no-float/probe-symbol audits pass. Negative
checks reject timeout, missing completion, wrong continuation and missing
allocation records. Earlier observer failures (assuming a zero free master,
and selecting an inline helper frame) are retained locally and are not
acceptance evidence. The service-boundary capture separates shared publication
of preceding drawing from the disposal itself. This proves region cleanup,
not resolution of the owner's black interval or circling-car report.

## Relative Line prerequisite (M2.3g44i)

The first relative Line is `$A892` at Dark3+$354A. The original bytes
`a8932f3c00010001a892` include the preceding MoveTo and pass `(dh,dv)=(1,1)`.
The headless, Enter-skipped reference exits zero in
`tmp/m2-relative-line-reference.log`. Its pen changes from `(−1150,−10625)`
to `(−1149,−10624)`; both endpoints lie above the offscreen PixMap, so the
complete 261,452-byte buffer remains unchanged. D0 returns zero, four argument
bytes are popped, and D1–D7/A1–A6 are preserved. All port bytes except the pen
position, plus PixMap, clipping and colours, are unchanged. This first call
proves clipped-line and relative-pen behaviour; it does not prove visible
line coverage by itself. The implementation reuses the existing tested Line8
rasterizer. The native observer exits zero and proves stack/register/pen contracts and
original continuation, with zero book replay. Its initial pen differs from the
Mac capture: `(−1213,−29334)`. All defined input pixels and colours already
match; 804 differing bytes are row padding at x=648–651, y=200–400. A separate
original-service fixture replays the captured native pen to establish identical
service inputs. The matched-input Mac fixture exits zero and the complete paired checker passes:

```sh
python3 tools/check_relative_line.py --reference tmp/m2-relative-line-reference.log --status 0 \
  --native tmp/m2-relative-line-native-full.log --native-status 0 \
  --paired-reference tmp/m2-relative-line-paired-reference.log --paired-status 0
```

Clipping, PixMap geometry/depth, colours and every defined pixel agree. Both
sides preserve their complete buffers, including their own unused row padding.
Negative checks reject missing completion, timeouts, register corruption and
incorrect fixture input identity. Host regressions and both native link audits
pass. The original point-local overlap below now explains the extreme Y
coordinates; whole-scene animation pairing remains separate.

## Original point-local overlap (M2.3g44v)

Dark3+$3484–$348F contains `3d42fffe3d41fffc3d43fffb`: three original word
stores of D2 to A6−2, D1 to A6−4, and D3 to A6−5. The last unaligned word
store overlaps the high byte of the saved Y coordinate. Consequently the
MoveTo Y is `(D3.lowByte << 8) | D1.lowByte`, not the original D1 word.
The first byte of this colour word is separately tested at +$3510, with zero
replaced by $FF. This is original game behavior, not a port conversion defect;
no game instruction is changed.

Bounded original/native point observers both exit zero and independently verify
the local writes, MoveTo arguments/result, and relative Line's (+1,+1) result
(`tmp/m2-point-locals-reference.log` and
`tmp/m2-point-locals-native-full.log`). Both now reach command bytes
`028dfb0501750061`, X=$FB05 (−1275), Y=$0175 (373), D3=$018D. Both pass
MoveTo pen `$8D75/$FB05` and return from Line with `$8D76/$FB06`. The unused
local byte A6−6 differs ($00/$C0); the written/read local bytes agree. Captures
are `tmp/point-locals-{reference,native}-{packet,stack,a5}.bin`.

The historical native Y −29334 is exactly `$8D6A`, derived from its measured
D3=$008D and Y=$016A. The historical Mac pen `$D67F` has the high byte of its
measured D3=$00D6. Those old point inputs were not a state pair. The current
first point command and service inputs do match, but native has made 247 game
Random calls versus Mac 72; only the first eight packet bytes match, not the
following commands. This closes the point-local/pen explanation, not a complete
actor/animation or framebuffer pair. The observer retains the normal Enter
book skip; the newer Mac run restricts it to Dark3+$337E.

## Read-only idle display-mode observation (M2.3g44w)

Revs' measured debugger method exposes FS-UAE's stored custom registers,
where Amiga-side reads of write-only registers would return floating bus data.
The known startup BPLCON0=$0211 provides a positive control. A bulk
$DFF000–$DFF200 read was rejected by the installed debugger; individual words
and COP1LC reads succeed. The rejected dump is not acceptance evidence.

The exploratory native run exits zero
(`tmp/m2-menu-mode-words-native-full.log`). Startup, menu entry after 135 OS
handbacks, and the original menu exit 900 ticks later all report BPLCON0/1/2/4
=$0211/$0000/$0024/$0011. BPLCON3's owned control bits remain $0C60; its bank
and LOCT fields can vary while the copper writes the palette. DIWSTRT/STOP
=$4881/$10C1, DDFSTRT/STOP=$0038/$00D0, both modulos=$0118 and FMODE=0.
Raster/copper/master DMA remains enabled. Menu entry/exit COP1LC equals the
active port-owned copper pointer. The initial port-object pointer was not yet
bound at MacLoader::run entry and is not used as a control.

The debugger's DIWHIGH snapshot includes serialized state flags, rather than
only the written register bits. The observed $A180/$A100 normalize to the owned
$2100 after excluding $C080. This agrees with the documented `save_custom`
layout in [upstream FS-UAE custom.cpp](https://github.com/FrodeSolheim/fs-uae/blob/main/custom.cpp),
which also serializes COP1LC and the other sampled mode registers. This source
explains the snapshot format; it is not proof of the installed build's exact
source revision.

`amiga/menu_mode.gdb` asserts the mode/geometry/DMA controls without changing any
register, samples a fully published menu frame, checks both COP1LC values and
positively reaches the original 900-tick exit. It uses ordinary `INTROSKIP=1`,
without palette-readback or menu-input options. The maintained run exits zero
(`tmp/m2-menu-mode-final-native-full.log`): menu publication 13 is complete at
tick 1587; the original wait exits at tick 2486, 900 ticks after its first
entry. Independent `check_aga_capture.check_frame` decoding verifies all 64,000
pixels, eight plane pointers and 256 palette colours against the logical menu.
Run with `GDBSCRIPT=menu_mode.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 240`.
This observation rejects a persistent mode-register loss at these checkpoints;
transient handback behavior and host-rendered visibility remain separate
acceptance requirements.

## Menu hardware palette readback (M2.3g44j)

`PALREADFRAME=13 INTROSKIP=1` enables a diagnostic-only Lisa colour-RAM reader.
It waits for two stable fields after publication, then reads one 32-colour bank
per VBI, both high and low nibbles. It suspends copper DMA during each bank,
uses BPLCON2 RDRAM and BPLCON3 BANK/LOCT, restores the owned control values and
prior copper-DMA enable, then resumes ordinary VBI publication. The contract is
also implemented in [FS-UAE's COLOR_READ](https://github.com/FrodeSolheim/fs-uae/blob/main/custom.cpp).
Buffers are static; compiled probe stack use is 12 bytes plus return address.
The probe is absent unless the build option is supplied.

`amiga/palette_read.gdb` positively enters the original Dan1+$1374 menu wait,
captures all eight banks, and reaches its original +$13E6 exit exactly 900 ticks
later. `tools/check_palette_read.py` checks every hardware nibble against the
copper, independently decodes all 64,000 plane pixels against the logical
viewport and checks the full CLUT through the verified video-colour transfer.

The bounded silent native run exits zero (`tmp/m2-palette-read-native-full.log`):
frame 13, 13 queued/published, no pending frame, no book batches, readback at tick
1,831 after menu entry at 1,825. The probe ends by scanline 1; DMA is `$03F1`
before and after. All 256 RGB24 entries match, with 227 distinct colours and
differing high/low components. Timeout, absent completion, disabled copper,
late scanline and corrupted colour negative checks are rejected. Host tests
and no-float/probe-symbol audits pass. The ordinary `INTROSKIP=1` build is
restored after the diagnostic.

This rejects incorrect installed palette contents at the sampled menu. It is
not proof of the host picture, other write-only mode registers, or a fix for the
reported black interval. The reader temporarily sets BPLCON2/3 to known values;
it does not preserve or measure an unknown pre-probe mode setting.

The separate idle-progress diagnostic reaches a house staircase image by tick
34,366 (560 publications), beyond the car/pond scene. That reconstructed image
used a prior CLUT only for inspection, so it is not a paired colour capture.
The earlier endpoint run times out at tick 49,312 without Dark+$552C. Its
success criterion remains unsatisfied. The exploratory Mac sample observer
also reports explicit failure because the scene ends before its requested
fifth sample; emulator exit zero does not override that failure. Do not repeat
that sample-count bound or call these wall-time samples state-paired acceptance.

## Paired demo randomness (M2.3g44k)

The native point/staircase A5 captures contain character choice 0 at A5−$D8F2;
the original point/exit captures contain 1. Original Dark+$524A calls Engine's
random wrapper; +$5250 masks bit zero and +$5254 stores this choice. The local
FITD reference independently names this branch `CHOOSE_PERSO`. Engine+$4A22
reads Ticks.W, masks 511, adds it to A5−$1078, calls Random at +$4A32, XORs its
result into that accumulator and masks `$7FFF`. All original absolute
references to this accumulator are inside that wrapper. A fixed QuickDraw seed
alone therefore cannot establish deterministic game randomness.

A fresh native capture (`tmp/m2-idle-rng-native-full.log`, exit zero) enters
that exact character-selection call at tick 2,734 with seed 1 and mixed input
`$00AE`; original instructions return `$4109` and choose 1. The earlier trace
entered the demo at tick 2,733 and selected 0. A one-frame Enter delay on the Mac
still selected 1 and was explicitly rejected; it is not a paired reference.
The earlier native 1,200-iteration diagnostic times out at tick 57,320, 719
published frames, while in heap-handle lookup. It reports no completed exit.
A separate native heap-compaction observer completed at frame 605: tick 36,292
to 36,294, only two ticks. Host inspection validates all block boundaries and
live master-pointer ownership before (336 blocks) and after (335 blocks). That
sampled compaction does not explain the long delay; this is not a full-sequence
heap or timing acceptance. These exploratory results do not close M2.3g44.


The opt-in `FIXEDRNG=1` diagnostic supplies seed 1 and accumulator 1 at the
first Engine+$4A32 call, then uses the real previous Random result to continue
that isolated stream. It replaces the live clock addition with zero at that
service boundary. The original wrapper XOR/mask and character-selection
instructions still run; production builds do not contain the fixture.
`tools/mac_fixed_random.lua` applies the same inputs only at the original
Engine call, excluding OS-internal Random calls. `amiga/fixed_random.gdb`
observes 64 calls and the original final accumulator/character continuation;
`tools/check_fixed_random.py` requires successful completion, identical inputs,
results and attributed callers, plus an independent arithmetic oracle.
These are diagnostic random inputs, not a proposed change to game behavior.
Both bounded runs exit zero and pass all 64 inputs/results/callers: first
Dark+$5250, then Dark2+$3CAE, character 0 and accumulator $6E59. The original
finishes at tick 15,156; native at tick 24,469, frame 326. Evidence is
`tmp/m2-fixed-random-reference.log` and
`tmp/m2-fixed-random-native-full.log`. Host regressions and build audits pass;
negative checks reject timeout, missing completion/row, altered initial input,
altered result and wrong character. Frames must still be paired by scene/script
state, not by absolute ticks or RNG call count alone.

Reproduce the native fixture with a clean `INTROSKIP=1 FIXEDRNG=1` build and
`GDBSCRIPT=fixed_random.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 1200`.
Run `tools/mac_fixed_random.lua` with the documented headless Mac command.
Preserve the full native `amiga/.run/gdb-out.log` before launching another run;
pass both logs and their actual process exit statuses to
`tools/check_fixed_random.py --reference <log> --reference-status <status>
--native <log> --native-status <status>`. The checker rejects timeouts,
missing completion/rows, changed inputs/results and an incorrect character.
Restore an ordinary build after diagnostic acceptance.


A subsequent fixed-input point investigation also completes on both machines
(`tmp/m2-fixed-point-{reference,native-full}.log`), but is **not a complete
state pair**: at the first Dark3+$347C call both have character 0, room 0,
camera 1 and loop counter 100, yet native has made 122 game Random calls versus 72 on
the Mac. Their packets already differ before QuickDraw:
`028dfb43016a0065` versus `028dfb2d01700063` (projected coordinates
−1213/362 versus −1235/368). Both pass `$008D` in D3.W. The remaining
coordinate difference therefore needs a matching actor/animation state;
matching only character, room and camera is insufficient. The field at
A5−$CC9C previously labelled “actor” is the completed loop counter: original
Dark+$5A6C–$5ADC walks 100 records of 160 bytes starting at A5−$B292.
The value 100 therefore does not identify the actor being drawn.

Original Dark+$5224 calls the game menu; result −1 branches to +$524A and
starts the idle demo, while result 0 branches to +$52B6 and the character-choice
routine. Pressing Enter through the menu and leaving it idle are different
original routes. The portraits/story should not be forced into the timeout
route as a proposed visibility fix.


## Zone-selection overhead (M2.3g44l)

A bounded `PROFILEFRAME=32 PROBEFIELDS=300 INTROSKIP=1 FIXEDRNG=1` diagnostic
attributes 83.9% of its measured beam interval to the existing OtherTrap
category, 13.6% to nested CODE/GWorld view refreshes and 0.27% to C2P.
The per-trap follow-up (`tmp/m2-idle-traps-native-full.log`, exit zero)
attributes 20.7% to SetZone, 14.2% to GetZone, 21.4% to the native driver entry,
13.2% to LineTo and 8.8% to RGBForeColor. Both samples span 300 fields and
11 publications. These instrumented fractions identify work; they are not
shipping frame-rate measurements or state-paired frame acceptance.

GetZone/SetZone do not allocate, dispose, resize or relocate memory. Their
successful paths now update the same result/error fields without rescanning
heaps or rebuilding CODE/GWorld views. All allocation/state-changing operations
retain the existing refresh. The native heap fixture passes all three stages,
including app/system zone selection, allocation, handle movement, error state
and final free-memory restoration (`tmp/m2-zone-fast-heap-full.log`, exit zero).
The after-change sample also exits zero (`tmp/m2-zone-fast-profile-full.log`):
view refreshes fall from 1,085 to 3, with their nested cost falling from
3,279,524 to 8,867 beam units. GetZone's inclusive cost per call falls from
8,817 to 5,118 units; SetZone falls from 6,514 to 5,910. Inclusive trap totals
also contain shared callback/audio work, so these are not isolated microbenchmarks.
Both intervals span 300 fields starting at publication 32, but they are not
identical game states: the latter ends at tick 6,303 instead of 13,537, and has
5 rather than 11 publications. Do not infer a shipping FPS or scene-fidelity
result from those counts. Host regressions pass; the idle endpoint remains open.

`PROFILEFRAME` enables a diagnostic-only start at the requested published frame;
`PROFILEROOM=<room> PROFILECAMERA=<camera>` instead selects original scene state
(both are required). `PROBEFIELDS` bounds the sample in emulated fields.
`MASKPROFILE=1` instead brackets the first pond mask construction, from
Dark+$317C GetGWorld to +$355C SetGWorld in room 0/camera 3, with original-byte
and selector checks. Use `INTROSKIP=1 FIXEDRNG=1` with this diagnostic;
the ordinary build has none of these timing reads.
`amiga/frame_profile.gdb` captures 22 nested phase totals, the ending room/camera,
and bulk per-trap tick/call arrays, then detaches at a
positive frozen-profile checkpoint. It never treats a timeout as completion.
The additional scopes distinguish heap pointer lookup, shared trap services
and original user-mode VBL callbacks. Audio is measured at native song/effect
service boundaries. Callback instrumentation preserves the parked registers
and CCR. Inclusive scopes overlap; do not sum them or quote FPS from a probe
build.

The separate host-window lead remains unproven for the installed executable.
The preserved emulator log `tmp/m2-idle-profile-fsuae.log` repeatedly reports
an invalid OpenGL drawable size with no successful drawable-size message.
The public [FS-UAE 4 display source](https://github.com/FrodeSolheim/fs-uae/blob/fs-uae-4/fsemu/src/fsemu-glvideo.c)
emits that warning while a cached drawable dimension is zero; its setter reads
SDL's drawable size. The [window source](https://github.com/FrodeSolheim/fs-uae/blob/fs-uae-4/fsemu/src/fsemu-sdlwindow.c)
calls the video-size setter in the resize-event handler. The installed binary
reports version 0.0.0 and has no matching public symbols, so this source clue is
not an exact-build diagnosis or proof of the owner-visible black-screen cause.
No host window access, capture or injected host events were attempted.


## Idle window fill (M2.3g44m)

Original Dark+$3C88–$3CCC saves the port, selects FrontWindow, sets the
foreground colour and PenMode 0, paints A5−$108A, then restores the port.
The window implementation now accepts modes 0 and 8 for its owned solid pen;
other patterns, modes and region encodings retain named stops.

The focused native run exits zero at Dark+$3CBA after the original PaintRect
at +$3CB8 (`tmp/m2-idle-paint-native-focused-full.log`). Entry/return ticks are
44,809/44,810, at publication 707. Mode 0, foreground 255 and rectangle
(−1000,−1000,1000,1000) fill precisely the 320×200 client. The complete
307,200-byte buffer matches the fill/preservation oracle; all 64,000 client
pixels and their displayed black RGB match the Mac fixture. Ports, PixMaps,
CLUTs, regions and rectangle bytes remain unchanged. D0=0, D1.W=8, A1=port,
D3–D7/A2–A6 preservation and four-byte argument cleanup match the Mac.

The original idle route did not reach this call in the bounded reference run.
An isolated Mac service fixture therefore supplies the same mode, foreground,
rectangle, map, port and clipping geometry. Three Mac calls and six independent
full-buffer clipping cases pass, as does the existing mode-8 comparison.
This establishes the service contract, not full idle-scene state pairing.
Device CLUTs use entry positions when ctFlags has bit $8000; their ColorSpec
value words are not pixel indices. The checker compares the used black entry
without requiring unused colours from different scene palettes to match.

Reproduce with a clean `INTROSKIP=1 FIXEDRNG=1` build and
`GDBSCRIPT=idle_paint.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 1500`.
Preserve the complete native log before another run. The Mac fixture uses
`AITD_PAINT_MODE=0` with `tools/mac_paintrect.lua` and the documented headless
MAME command; mode 8 remains its default. Validate both actual process statuses:

```sh
python3 tools/check_idle_paint.py tmp/m2-idle-paint-native-focused-full.log --status 0 --reference tmp/m2-window-mode0-maintained-reference.log --reference-status 0
```

An earlier observer syntax failure (exit 1) and combined demo continuation
that timed out (exit 124) are not passes. The corrected dump command passed a
separate startup preflight before the focused acceptance run. Synthetic checker
checks reject unfinished runs, missing completion and corrupted pixels/state.
Build/link audits pass. Full car/frog and rendered-window acceptance remain open.

## Remaining idle-sequence evidence

The Mac fixed-entropy demo reaches Dark+$552C with 1,092 game Random calls and
character 0 (`tmp/m2-fixed-idle-exit-reference.log`, exit 0). Its first
Dark+$5BE8 capture already shows the pond starting background
(`tmp/m2-car-end-reference.log`, exit 0); the historical `car-end-reference`
filename does not establish the final car pose.

The combined native observation continues past the mode-0 fill but times out
before that exit (`tmp/m2-idle-paint-native-accept-full.log`, exit 124). Its
interrupt sample is inside RegionRows::row, capacity 268, y=93. That single
sample identifies a place to measure, not a proven performance cause. The
branch to the fill depends on A5−$BFB8/$BFB6, measured as 1/0; compare the
underlying scene/script state with the Mac rather than pairing elapsed ticks.
Neither the passing service fixture nor the incomplete continuation establishes
the owner-visible black interval's cause.


The original exit-cause observer now positively reaches Dark2+$3F8E, which
sets A5−$D862 after a 120-tick script wait. All three input words are zero;
Dark+$552C follows at tick 25,201 with 1,092 Random calls
(`tmp/m2-idle-exit-cause-reference.log`, exit 0). This is a natural script
completion, not a residual Enter exit.

Two 120-step captures at Dark+$5658 now isolate the car divergence
(`tmp/m2-idle-turn-{reference,native-full}.log`, both exit 0). The first 48
positions agree. At step 49 the native car has committed another 300-unit
animation movement; the Mac still has a 280-unit partial movement. At native
step 54 the car reaches track position 20 at (8208,−204), angle 960. The Mac
reaches that track position at step 56 at (8437,346), angle 1020, and advances
to 24 on its next step. Native remains on 20 through step 119, with positions
tracing a loop; the Mac reaches 52. Both have made exactly one game Random
call throughout these captures. The difference is upstream of QuickDraw.
Dark2+$4C6C compares waypoint distance with 400 and +$4C7A advances the track;
+$4CD2 starts a 15-tick, 64-angle-unit turn. The actor record uses position
words +$1C/+$20, angle +$2A, track offset +$58 and turn timing +$6A–$70.
The measured divergence motivates investigating service cost and animation
sampling; it does not authorize altering the original movement decisions.


## Read-only heap-query overhead (M2.3g44n)

`MacHeap::ptrSize`, `handleSize`, `state` and `recoverHandle` now update the
same error result without rebuilding the zone's free-master chain or rescanning
free space. Every mutating operation retains its original publication.
The new nested `kProfileHeapPublish` category measures that work; it compiles
away outside diagnostic builds. `frame_profile.gdb` reads the actual category
array size instead of assuming sixteen categories.

The bounded `INTROSKIP=1 FIXEDRNG=1 PROFILEFRAME=32 PROBEFIELDS=300`
before/after runs both exit zero. The former reports 931 heap publications,
4,431,368 of 23,971,754 beam units (18.5%); the latter reports zero publications
in its 23,986,936-unit interval. Both measure 300 fields starting at publication
32. Published frames are 5 and 17, respectively, but the resulting scene states
and ticks differ (6,306 versus 5,229). These instrumented intervals demonstrate
removed work, not a controlled shipping frame-rate multiplier. Logs are
`tmp/m2-heap-publish-{before,after}-full.log`.

All host regressions pass, including success/error query checks that preserve
every arena byte and the existing 2,500-step fragmentation checks. The native
heap fixture exits zero with all three stages complete and final app/system
free bytes 3,144,040/130,808 (`tmp/m2-heap-query-native-full.log`). Clean native
builds pass no-float and probe-symbol audits.

The unprofiled fixed-entropy 120-step repetition also exits zero
(`tmp/m2-heap-query-turn-full.log`). Native now reaches track position 20 at
step 60, (8322,374), then 24 at step 61 and 32 at step 64. At step 119 it
reaches track position 52, matching the Mac's script progression rather than
the previous native loop at 20. The measured point is (−1497,589), versus the
Mac's (−1284,126); these different animation samples are not pixel-paired frame
acceptance. There remains only one game Random call throughout. No input is
injected after the initial book-skip Enter. The original movement code is
unchanged. The near-camera endpoint, frog transition and host black-interval
cause remain M2.3g44 work; this bounded improvement does not close them.


## Normal menu Enter fixture (M2.3g44r)

`MENUENTER=1` implies `INTROSKIP=1` and enables one diagnostic Enter press
at the original Dan1+$1376 TickCount menu wait. After thirty ticks it supplies
raw Return through the ordinary input queue, then releases it at a safe trap
boundary at least two ticks later. It never repeats. Ordinary builds exclude
the fixture; the original instructions, menu result and timers are unchanged.
This supports the portraits/story input route, separate from idle-demo checks.

The checked original wait starts `42a7a975` at Dan1+$1374; Dark+$522A starts
`1c001006`, and the new-game branch at +$52B6 tests the relocated A5−$D84E
word. The observer checks both opcode and relocated operand, rather than the
unrelocated file placeholder. The first observer rejected that placeholder
comparison; it is not a successful check.

A clean `MENUENTER=1` build and bounded silent `amiga/menu_enter.gdb` run pass
(`tmp/m2-menu-enter-native-full.log`, exit zero): menu entry tick 1587, press
1617, original result 0 at 1623, original new-game branch reached, Enter released
at 1623 with no held key, and zero book batches. This proves input and branch
selection, not yet portraits/story frame fidelity or host-window appearance.
Use `GDBSCRIPT=menu_enter.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 180`
after sourcing `amiga/env.sh`. Restore the ordinary test build afterward.

The restored `INTROSKIP=1` build passes both link audits, contains none of
`aitdInputMenuEnter`/`g_menuEnter*`, and passes the original intro skip/release
regression (`tmp/m2-menu-enter-skip-regression-full.log`, exit zero).


## Portrait frame acceptance (M2.3g44s)

The normal Enter route now has a state-paired capture at the original portrait
input wait, Dan2+$1EB6 (`4eb9 00000572` before relocation), with Carnby selected
(D7=0) and the menu Enter released. All 64,000 client pixels and all 256 logical
RGB16 colours match the Mac exactly. Native publication 15 becomes active at
tick 1717; the independent decoder verifies every AGA pixel, bitplane pointer
and transferred copper colour. This is memory/publication evidence; it does not
establish host-window appearance or close the idle black interval.

Build `MENUENTER=1` and run `GDBSCRIPT=portraits.gdb EXTRA_ARGS=--warp_mode=1
amiga/diag_run.sh 240` after sourcing the toolchain. Run the documented headless
MAME command with `-autoboot_script tools/mac_portraits.lua`. Preserve the native
full debugger log, then run:

```sh
python3 tools/check_portraits.py tmp/m2-portraits-final-reference.log \
  tmp/m2-portraits-final-native-full.log --reference-status 0 --native-status 0
```

Both maintained observers exit zero with positive endpoints, and the checker
passes. The reference first Enter is keyed to Dark3+$337E, not any LineTo while
the app is frontmost. Instrumentation showed that the earlier broad trigger
hit a system call at $9D1B4 before Dark3 loaded, so the menu was never reached.
The rejected observer runs are not acceptance evidence. The checker excludes
only the known missing optional MAME floppy-mechanism sample messages from its
error scan. No game bytes change. Story text placement/progression and idle-route
visibility remain M2.3g44.


## Normal portrait Enter fixture (M2.3g44t)

`STORYENTER=1` implies `MENUENTER=1` and `INTROSKIP=1`. It supplies one more
normal Return, thirty ticks after reaching the portrait input loop, then releases
it at a safe trap boundary at least two ticks later. No game instruction or
selection result is patched. The trigger recognizes Engine+$1F84 Button through
two bounds-checked A6 frames: return to Dan1+$6230, then Dan2+$1EBC. The observer
checks the original LINK, trap and relocated JSR bytes. Menu and story polling
do not match this call chain. Ordinary builds contain none of this fixture.

`amiga/story_enter.gdb` checks the original menu branch, stable portraits,
Dan1+$4870 story input wait (`4eba199c`), page zero, released Return, absence of a
loud stop and complete AGA publication. Run after a clean `STORYENTER=1` build:

```sh
GDBSCRIPT=story_enter.gdb EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 240
```

The exploratory bounded native run exits zero with press/release at ticks
1746/1748 and story publication 17 active at tick 1839
(`tmp/m2-story-trigger-native-full.log`). The original Mac normal-input observer
also exits zero at Dan1+$4870, page zero, input zero
(`tmp/m2-story-page-reference.log`). Independent AGA decoding matches all 64,000
native client pixels, bitplane pointers and 256 transferred colours. All logical
RGB16 values match the Mac. The 6,007 differing client pixels are inside
(165,11)–(315,184) and each difference substitutes text ink index zero for a
background index 146–159 or vice versa; every other pixel matches. The picture,
background and arrow match, with the expected D6 placeholder glyph differences.
This is not full story-text layout/progression or rendered-window acceptance.

An earlier observer tried requesting input through a debugger memory write.
Its readback guard failed before any input was sent; the rejected run is
`tmp/m2-story-rejected-debugger-write-full.log`. The replacement uses only the
running target's ordinary key queue and requires no debugger mutation.

The maintained `story_enter.gdb` repetition also exits zero and passes its
stronger original-byte, page, key-release and publication guards, with the same
press/release and publication ticks (`tmp/m2-story-enter-final-native-full.log`).
Its captured AGA frame again passes the independent decoder.
The restored `INTROSKIP=1` build passes no-float and 88-symbol audits; its
linked symbol table contains no menu/story input helpers or state.


## Letter text and page progression (M2.3g44u)

The first-page text trace contains fifty DrawText calls. Their strings, integer
positions, half-pixel starting fractions, Times/plain/14 selection, mode and
zero extra spacing match the original exactly across eleven baselines. The
initial native trace contains both supervisor and user-service bridge entries;
each adjacent pair is identical and matches one Mac call. The maintained
observer captures only the user-service entry. No placement correction is needed
for the measured first page; its different ink is the D6 placeholder artwork.

The original Dan1+$4870 reading wait uses D3 as the page number and D5 as the
end-of-text flag. Right Arrow advances reading pages; Return exits this mode.
The Mac normal-input observer measures eight pages, zero through seven, with
D5 set only on the final page, and returns to Dan2+$2086. A test that pressed
Return immediately measured only the first page and does not establish full
reading progression.

`STORYREAD=1` implies `STORYENTER=1`, `MENUENTER=1` and `INTROSKIP=1`. It
recognizes the reading poll through the same bounded original Engine/Dan1 call
chain as the portrait fixture, with caller Dan1+$4874. At Engine+$1F84 the
original prologue has not changed D3/D5. After thirty ticks at each newly reached
page, the fixture supplies normal Right Arrow, or Return for the final page,
and releases it at a safe trap boundary at least two ticks later. Production
builds exclude this diagnostic input.

The maintained observers are `amiga/story_pages.gdb` and
`tools/mac_story_pages.lua`; the independent comparison is
`tools/check_story_pages.py`. The native observer uses event-driven breakpoint
commands: its first exploratory loop stopped on the text breakpoint before
reaching the page guard (`tmp/m2-story-pages-rejected-loop-full.log`, exit 1).
That rejected observer is not progression evidence.

Both maintained full-letter observers exit zero with positive original return
checks (`tmp/m2-story-pages-final-reference.log` and
`tmp/m2-story-pages-final-native-full.log`). All 257 DrawText calls match exactly,
including their text, positions and settings. Native publications 17–24 are
complete and independently decode to the corresponding logical pages. Every
page has identical Mac/native artwork, background, navigation arrows and all
256 RGB16 colours. Differences are exclusively placeholder ink against the
text background, within (165,11)–(316,184); later original glyphs extend one
column farther right than the first page. Difference counts are
6,007/818/5,855/1,626/4,578/5,187/5,958/272 for pages zero through seven.

```sh
python3 tools/check_story_pages.py tmp/m2-story-pages-final-reference.log \
  tmp/m2-story-pages-final-native-full.log --reference-status 0 --native-status 0
```

The checker passes all eight frames, 257 calls and the original input/return
sequence. This completes the measured Carnby-letter layout/progression check;
it does not prove host-window visibility, resolve the reported idle black
interval, or accept unvisited text/UI routes.
The restored ordinary `INTROSKIP=1` build passes both link audits and contains
none of the menu, story-entry or reading fixture symbols.


## SetEmptyRgn cleanup (M2.3g45)

The original Dark2+$5768 caller is `2f39ffff4038a8dd`; the operand relocates
to A5−$BFC8. `tools/mac_setemptyrgn.lua` skips the book through normal Return
and captures the later original cleanup call. The final reference run
(`tmp/m2-setemptyrgn-reference-final.log`, exit zero) has a ten-byte canonical
empty region, `000a0000000000000000`. The handle, body and bytes stay unchanged;
four argument bytes are removed, adjacent stack bytes and D0–D7/A2–A6 are
preserved, A0 becomes the region handle and A1 the body. MemErr stays zero.
There is no Boolean result.

The native implementation accepts owned ten-byte regions, writes their canonical
empty representation and returns the measured registers. It rejects resource
handles, active recording storage and other sizes through the existing named
stop. Larger/complex-region resizing remains M2.8. No allocation, game-code
patch or drawing is needed.

`amiga/setemptyrgn.gdb` uses `INTROSKIP=1` and stops on the linked `recordKey`
entry before arming the original caller. The public injection wrapper is
inlined and its standalone body is discarded in this build; breaking on its
unqualified debug symbol can resolve to unrelated code. The abandoned observer
runs are not acceptance. `tools/check_setemptyrgn.py` checks original and live
caller bytes, stack, registers and the complete region. The native run
(`tmp/m2-setemptyrgn-native-linked-full.log`, exit zero) reaches and returns
from the original cleanup call. The paired checker passes complete bytes,
handle/body identity, adjacent stack, argument cleanup and every required
register. The existing heap checks and MAME literal audit also pass, and six
corrupted/incomplete evidence cases were rejected. Link audits are clean.

```sh
python3 tools/check_setemptyrgn.py tmp/m2-setemptyrgn-reference-final.log --status 0 \
  --native tmp/m2-setemptyrgn-native-linked-full.log --native-status 0
```


## Positive startup requirements acceptance (M1.6b)

`amiga/identity.gdb` now stops at a positive original execution boundary instead
of depending on the retired EmptyRgn loud stop. It guards Core's result store,
+$03F2 branch, +$0460 success instruction and both +$0410/+$044E alert sites.
The original reaches +$0460 with the stored word zero and D0.W zero; the relocated
result address and adjacent success flag agree with A5. Neither alert executes.
All eleven Engine capability flags and SysEnvirons remain checked against the
existing Mac contract. Seven Gestalt calls precede the success branch; the
eighth (A/UX absence) follows it and supplies the final positive endpoint.

`tmp/m2-startup-success-final-full.log` exits zero and passes SysEnvRec=16,
Gestalt=8, Engine-flags=11, startup result=0 and alerts=0, with 27 OS windows
and 33/33 completed services. The earlier observer requiring eight queries at
+$0460 was rejected; it was a test-order error, not a runtime failure.


## Exact default QuickDraw patterns (M2.3a)

The native pre-fix QDGlobals dump has all forty pattern bytes shifted one byte
toward `thePort`: 26 bytes differ from the original Mac. The linked copy is
`move.b (a0)+,(0,a0,d2.l)`, whose destination uses the incremented register.
This is the same measured GCC 15.1 defect as the earlier Finder-info copy.
A volatile byte temporary separates the load and store; no original game
instructions or pattern definitions change.

`tools/mac_qd_patterns.lua` captures the actual Mac InitGraf return. The native
identity observer now also dumps the forty pattern bytes at its positive
startup endpoint. `tools/check_qd_patterns.py` compares all five patterns and
audits the entire linked program for the observed same-register postincrement
copy form. Both captures exit zero, all forty bytes match, and the linked audit
has zero remaining occurrences (`tmp/m2-patterns-reference.log` and
`tmp/m2-patterns-native-full.log`). Native no-float/probe audits, MAME literal
checks and the 68020 boot regression pass.

The required resource-read regression exposed a stale EmptyRgn failure
endpoint. It now uses the byte-checked original Misc2+$24D4 CopyBits return,
independent of later intro progress. Its three byte-exact original samples,
metadata-only preparation, original-MDRV exclusion and bounded reads remain
checked. The 68020 positive run exits zero: 68 application reads / 333,998 bytes,
128 windows, 463/463 services, maximum source read 28,672 bytes. See
`tmp/m2-patterns-resource-positive-full.log`; the earlier timeout at the obsolete
endpoint is not a pass. `check_resource_reads.py --status 0` verifies all three
sample hashes and the new positive completion. The read observer no longer
uses unrelated later-endpoint preference/window totals.


## Consolidated M2 foundations acceptance

M2.3, M2.7, M2.7a and M2.9 no longer represent missing implementations. Their
specified acceptance is supported by the maintained helpers and the paired
captures below; full-intro comparison and rendered-window checks remain open
under M2.6/M2.10 and M2.3g44.

- **M2.3:** the current host suite (`tmp/m2-delivery-host-tests.log`, exit zero)
  passes 122 complete clipped direct/remapped CopyBits cases, irregular masks,
  atomic malformed-input rejection, eight-bit GWorld layouts and bounds.
  Current original execution reaches and returns from SetEmptyRgn well beyond
  GWorld creation. Reached PICT/port/pixel-map adapters use eight-bit storage;
  the Vette four-bit palette cap is not used by these paths.
- **M2.7:** native palette construction, binding, GetCTable, window realization
  and already-realized ActivatePalette have the paired contracts documented in
  [palette.md](palette.md). The full reference/native ShowWindow CLUT captures
  (`windowstate-*-show-after-clut.bin`) are both 2,056 bytes and still agree in
  every byte after the allocated seed. This includes all 256 entries and the
  protected duplicate slots 1, 15 and 191. Current sanitizer tests cover endpoint
  retention and malformed-state atomicity. This is logical palette acceptance,
  not a new rendered-window claim.
- **M2.7a:** the current integer implementation re-passes the maintained original
  exhaustive capture: 65,536 channel values, 257 CPU SetEntries calls, 256 mixed
  colours and 512 startup colours (`tmp/m2-delivery-video-transfer.log`). The
  captured startup palette and ramp use the same exact transfer as the
  Infogrames display; native AGA palette encoding is independently covered by
  all-256-colour host tests. This consolidates the measured transfer already
  implemented under M2.5a, without guessing gamma or altering logical RGB16.
- **M2.9:** all 25 owned font associations, measured metrics/widths and bounded
  glyphs pass the current host suite. Existing title, credits (including the
  dot-above and circumflex), caption and story captures account for the reached
  Mac-font uses. Rechecking `m2-story-pages-final-reference.log` against
  `m2-story-pages-final-native-full.log` passes all eight pages, 257 identical
  text calls/settings/positions, artwork, palette and AGA publication. Only
  documented owned glyph artwork differs. The owner-supplied screenshots also
  establish visible placeholder text on the Enter route. M6.5 retains the
  eventual engine-font replacement; the unrelated black interval stays open.

The historical seven-frame restore-palette log was not accepted by the current
nine-frame AGA checker; it is not new full-intro evidence. The remaining
observer/sequence work stays in M2.10a/M2.10.

### M2.1c4 — measured song stop (selector 5)

Core+$1400 invokes selector 5 after the unattended demo. Original driver +$362
clears song control, all 24 track-status words, and six music-voice slots while
retaining song resources and effect state. D0=0, D1=$FFFF, CCR=4, the caller-owned
stack and D2–D7/A0–A6 match the native return. The native implementation stops
sequencing and quiesces/frees music DMA buffers through the existing voice owner.
It retains resource ownership for the following selector 7 at Core+$140C.

`check_driver5.py` passes the complete original state transition and native
original-call capture (`m2-driver5-reference.log`, `m2-driver5-native-full.log`,
both exit zero). The native song event count remains 3736 across the stop;
configuration, effect state and resource ledger are byte-exact across it. The
original natural call has already exhausted its tracks, but four music-voice
words still change to inactive; this capture does not claim an active-track
playback interruption test. Four invalid status/completion/register/caller
variants are rejected. The native link audits pass. PAK acceptance remains open
until the following resource release and real Present.PAK payload are verified.

### M2.1c4 — measured song-resource release (selector 7)

The following Core+$140C call reaches original driver +$3F18. Its complete state
capture clears the song-enabled word and song/sample resource pointers without
altering effects. The native adapter uses `releaseNativeSong`, the established
owner for sequencer state, music DMA buffers and detached song resources.

`check_driver7.py` passes `m2-driver7-reference.log` and
`m2-driver7-native-corrected-full.log` (both exit zero). All 41 owned handles have
free allocation flags and cleared ledger entries, music is stopped, and effect
state/configuration are unchanged. The original caller's stack, D2–D7/A0–A6,
D0=0, D1=0 and CCR=4 agree. The native link audits pass.

The first native observer wrongly required disposed master-pointer words to be
zero. `MacHeap::publish` instead links free slots through those words;
`isFreeHandleSlot` uses their allocation flags. That rejected diagnostic is
retained as `m2-driver7-native-free-slot-assumption-full.log` and is not acceptance
evidence. The corrected observer checks actual free-slot and owner-ledger
semantics. M2.1c retains the independent requirement to read and compare original
Present.PAK payloads beyond these services.

### M2.3b — verified inverse coordinates

Normal Return input skips the book; a normal mouse click in the main game menu
then reaches Engine+$16E8 GlobalToLocal. `mac_globallocal.lua` limits capture to
original game sites, excluding System 7's own internal conversions. The selected
eight-bit window PixMap has origin (-150,-160): point (253,321) becomes (103,161).
All adjacent bytes and D0–D7/A0–A6 remain unchanged; four argument bytes are
removed from the stack. `check_globallocal.py` passes the maintained capture
`m2-globallocal-reference.log` (exit zero), including original caller bytes and
selected-port records. GlobalToLocal now adds that selected PixMap origin;
LocalToGlobal retains the inverse subtraction. Unsupported port layouts still
stop explicitly.

The baseline `a1200-020` capture `m2-globallocal-native-auto-full.log` exits zero
and passes the same checker with `--native` and `--native-status 0`: the actual
Engine+$16E8 call produces the identical point pair and preserves all guards,
registers and stack behavior. Build with `INTROSKIP=1 MOUSEPROBE=1` and run
`amiga/globallocal.gdb`. The opt-in mouse fixture byte-checks the original menu
wait, then supplies guest coordinates/button through the normal VBI sampler.
It changes no game instruction or service result. Both link audits pass.
Earlier debugger-written mouse attempts did not persist to runtime and provide
no acceptance evidence; the compiled input fixture removes that dependency.

### M2.8 — paired EmptyRgn variants

After observing the real Dark+$4182 query, `mac_emptyrgn_variants.lua` allocates
64 bytes through the original CPU NewHandle trap and runs six isolated queries:
canonical empty, nonempty rectangle, zero/inverted height, inverted width, and a
36-byte complex region with two spans. These are service fixtures; the game is
not resumed from the modified fixture context.

`check_emptyrgn_variants.py` passes `m2-emptyrgn-variants-reference.log` (exit zero).
All 64 body/guard bytes are unchanged in every case. Boolean output preserves its
padding byte. D0.W receives top and D1.W receives left, preserving deliberately
nonzero high words; A0 ends at body+8 when top>=bottom, otherwise body+10. A1 is
the return PC; other registers, stack cleanup and MemError match the checks.
The native adapter now implements this bounding-box query for owned rectangular
and complex regions, validating declared size against allocation size first.
`REGIONPROBE=1` and `amiga/region_variants.gdb` execute the same six inputs through
native Line-A traps, including deliberately nonzero D0/D1 high words and Boolean
padding. `m2-emptyrgn-variants-native-full.log` exits zero on `a1200-020` and passes
the paired checker with all 64 bytes unchanged per case, exact register/stack
results and successful allocation/disposal. Both link audits pass. No debugger
writes to target memory or registers are used.

### M2.8 — paired RectRgn variants

`mac_rectrgn_variants.lua` observes Dark+$3D46, then uses real CPU allocation,
state, RectRgn, size and ownership traps for seven isolated cases. A ten-byte
empty region and 64-byte complex-region allocations become ten-byte rectangles.
Zero/inverted height or inverted width produce canonical empty regions. Locked
and purgeable handles also shrink to ten bytes, preserving their flags and zone.
The input rectangle and its adjacent guards are unchanged.

`check_rectrgn_variants.py` passes `m2-rectrgn-variants-reference.log` (exit zero).
D0 becomes the zero-extended top word, except a horizontal-empty result after a
nonempty vertical comparison returns the left word. D1–D7/A2–A6 are unchanged;
A0 is the handle and A1 is its master-pointer value. The 24-bit Mac includes
handle flags in A1's high byte for the locked/purgeable cases; the port's existing
heap model stores flags separately from clean 32-bit pointers (design §4.4).
The native implementation now shrinks through the owning heap, preserves handle
state and implements the measured empty-region and D0 results. The baseline
`a1200-020` capture `m2-rectrgn-variants-native-full.log` exits zero and passes
`check_rectrgn_variants.py --native ... --native-status 0`. Build with
`REGIONPROBE=1` and run `amiga/rectrgn_variants.gdb`; all seven native CPU cases
match, including allocation size, input guards, state flags and owning zone.
Both link audits pass. The host polygon, region encoding, InsetRgn and all 122
clipped CopyBits cases also pass. Together with the maintained paired pond
region/expansion/masked-copy captures (picture-drawing.md), this closes the
remaining M2.8 acceptance for the screens reached so far. Broader region
operations remain subject to measured callers and named unsupported stops.

### M2.4 — integrated fresh-start viewport acceptance

`amiga/fresh_viewport.gdb` now follows one fresh startup from the original
Dan2 GetNewDialog 1000 through ModalDialog item 2 and disposal, the original
Misc1+$109A WIND 128 request, and first native frame publication. No frame is
queued while the hidden size dialog exists. Its live record remains hidden;
the selected item is 2 and the dialog is disposed before the game window opens.
The first presentation uses WIND 128's live content rectangle
(160,150)–(480,350), a (160,150) crop of the actual 640×480×8 main screen.
VBI publishes exactly that viewport as the first frame.

`m2-fresh-viewport-native-full.log` passes on `a1200-020` with exit zero.
The existing `INTROSKIP=1 FIXEDRNG=1` diagnostic binary was used; acceptance
ends before either input/random fixture is exercised. The launcher classifies
preferences before execution and this observer rejects an existing-preference
fixture. Recognized diagnostic preferences were temporarily isolated and
restored after the run. This verifies the integrated startup/display contract;
it does not replace the owner-deferred visual acceptance in M2.5/M2.3g44.

### M2.10a — positive standalone startup observers

`pixbase.gdb` now finishes its pixel-address/row-copy contract at the original
Misc2+$0342 return, then uses the common `aga_startup.gdb` observer. That observer
stops before the original Dark3+$337E LineTo and captures frame 9 through
`aga_startup_call.gdb`. It exits immediately after verified publication, so later
intro frames cannot overwrite startup evidence. Retired EmptyRgn error stops
and the stale embedded frame-4 expectation are removed.

`m2-pixbase-positive-native-full.log` exits zero on `a1200-020` with `INTROSKIP=1`.
`check_pixbase.py` verifies the paired original bytes, query ABI and unchanged
screen, 28,672 copied bytes and all 448 row-padding bytes. `check_aga_capture.py
startup` verifies exact frame pixels, all eight pointers, all 256 colours and
identical queued/published buffers at the intended frame. Both build audits pass.
The menu checker now requires the already-maintained successful Dark+$1E4C
CopyBits return, balanced services and the preference-specific window count.
It passes the established `m2-effectreplace-native-full.log` capture paired with
`m2-menu-lifecycle-reference-final.log`; the menu runtime observer is unchanged.
All checker success messages now follow their terminal assertions.


## Baseline ordinary demo completion (M2.3g44)

After the display synchronization change in `92a5cdf`, the `a1200-020`
ordinary-randomness run finishes normally (`tmp/m2-sync-ordinary-native-full.log`,
exit 0). Build flags are `INTROSKIP=1 PAKPROBE=1`, without `FIXEDRNG`.
The observer checks the entropy mode, original route instructions, zero input
at each transition and the original natural-exit flag. All nine reference
room/camera pairs occur in order: 0/1, 1/2, 0/1, 5/1, 2/4, 7/3, 1/1, 0/2, 6/0.
Choice is 0; natural exit is at tick 60,426. The temporary observer also guards
against 256 frames remaining at actor 288's track 26, word 59; this guard does
not fire. The earlier stalled coordinates also stall the original Mac when
replayed as diagnostic data, so they did not justify changing game decisions.

The ITD_Ress read returns exactly 1,536 bytes at offset 9,216, and Present
returns exactly 17,920 bytes at offset 512. Palette reactivation matches the
original active state, complete CLUT and private seed. The run records 1,500
system windows, 111 resource reads and 70,729 balanced services. Payloads and
palette captures are archived under `tmp/m2-sync-ordinary-native/`.

The maintained `amiga/pak_reads.gdb` supports both entropy modes. Use
`tools/check_pak_native.py LOG --status STATUS --ordinary-entropy` for the
ordinary run; it requires natural exit and the full route in addition to
payload equality. `check_palette_rebind.py` independently validates the paired
palette captures. Both pass this run. Skipped rooms, wrong cameras, manual
input, missing exit flags, wrong entropy modes and duplicate exits are rejected.

This closes baseline ordinary sequence acceptance. It does not prove a
frame-rate multiplier, diagnose the owner's black interval or replace
rendered-picture acceptance. The final uninterrupted-intro regression after
this display change also passes (`tmp/m2-sync-intro-native-full.log`, exit 0):
956 frames, 944 partial updates, all 840 book batches, zero conversion
mismatches and balanced queued/presented frames. The original return is D0=0
at tick 116,556. Both logos match all 64,000 pixels, palette and publication;
title/credits retain exactly the verified 1,015/1,722 owned-glyph differences.
The captures and build log are archived under `tmp/m2-sync-intro-native/`.

The complete `make host-tests` suite passes after making generated offsets in
`mac_palette_rebind.lua` explicitly hexadecimal (`tmp/m2-final-host-tests-fixed.log`,
exit 0). The first suite run rejected that observer's unprefixed `%x` literal;
the corrected form emits `0x20cc`/`0x214c` for the same original call sites.

The final full `make regression` also passes on `a1200-020`
(`tmp/m2-final-native-regression-isolated.log`, exit 0): resource-exit (all
eight phases), file-write, file-read, window-core, boot and resource-read,
covering 13 native boots. Per-case preference isolation fixes the harness's
cross-case state leak: existing preferences prevented file-write preparation,
and boot's early checkpoint left an incomplete fork for resource-read.
All six original preference files were restored byte-for-byte after the suite.
The isolation helper's four restoration/failure tests and complete host suite
pass (`tmp/m2-final-host-tests-isolated.log`, exit 0). This completes automated
M2 regression acceptance; rendered PAL/NTSC and black-interval checks remain
open under the owner's window-access restriction.

## M2.3g44 rendered acceptance (2026-10-02)

The owner supplied `Screen Recording 2026-10-02 at 22.44.31.mov` from
`~/Pictures/Screenshots`. It lasts 651.942 seconds and contains video only.
This is the normal a1200-020 PAL run from commit 78ff1ca with INTROSKIP=1,
requested by the owner to skip the book, without a debugger or fixed RNG.
The menu-to-landscape black interval runs from video 48.467 to 56.417 seconds
(7.95 seconds), matching the 474-tick diagnostic. It replaces the earlier
six-minute blank interval. Earlier black transitions in this recording are
separate startup transitions, not the menu-to-demo interval.

The recording visibly progresses through the car, pond, mansion, entrance,
stairs and upper corridor. A frame at 620 seconds shows the final room;
at 645 seconds the MacPlay logo is visible again. Thus this visible run
completes the demo rather than circling indefinitely. The unrelated white
cache window is excluded from acceptance, and no audio claim is made.
Extracted contact sheet, sampled frames and blackdetect measurements are in
`tmp/m2-owner-video/`; the original recording remains at its owner path.
This closes the M2.3g44 visual-delay and reported demo-reliability checks,
supported by the earlier complete original-route/native comparisons below.
It does not close M2.5 PAL/NTSC pattern/ramp/pointer rendered acceptance.

### Prior diagnosis and validation

Historical diagnostic evidence

The following records the diagnosis before rendered confirmation arrived. Follow the
host-window restriction under M1.7b2; inspect owner-provided captures, but do
not retry denied autonomous capture or substitute host input injection.

Owner-provided F12+S captures from a normal, unpaused `a1200-020` PAL run on
2026-10-02 are now available in `tmp/m2-owner-screenshots-pal/` (40 PNGs).
Amsterdam timestamps show the menu at 20:45:10, 14 identical all-black captures
from 20:45:25 through 20:51:01, and landscape at 20:51:44. They support the
owner's roughly six-minute black interval, but do not identify its cause.
The owner reports a moving mouse pointer during black output; the saved black
images contain no pointer, so that observation is not independently captured.
Later images show car movement and scene progression through 20:54:09; they
do not alone prove the reported circling or natural completion. The run was
stopped at the owner's request. No Enter was requested: the letter belongs to
the new-game route and is not expected in this idle demo. User-saved screenshot
inspection is authorized; autonomous host capture/input remains restricted.

A subsequent bounded baseline diagnostic (`tmp/m2-black-timeline-native-full.log`,
exit 0; `INTROSKIP=1`, ordinary randomness) reproduces a 21,678-tick gap
between frame submissions: tick 3,296 to 24,974, about 361 seconds. The first
frame's entire viewport is index 255 with RGB (0,0,0). Song/instrument/sample
resource requests occupy ticks 3,444–5,850; no further frame is submitted until
24,974. Follow-up measurements below locate the dominant work in that gap.

Follow-up activity and cost captures identify native music catch-up as the main
delay (`m2-black-activity-native-full.log`, `m2-black-cost-native-full.log`, both
exit 0). Only a handful of original calls progress while song catch-up consumes
17,181 ticks; repeated PCM conversion accounts for 16,697 ticks (278 seconds).
The committed sample-reuse change reduces the same blank-frame submission
gap from 21,663 to 2,976 ticks (361 to 49.6 seconds), with 65 conversion ticks
before the next picture (`m2-black-reuse-native-full.log`, exit 0). The host
original-event comparison and full native playback now pass, including all
3,736 timed events, 25 byte-exact retained PCM variants (458,974 bytes), effect
priority, natural completion and cleanup (`m2-song-reuse-native-full.log`,
exit 0). At that stage normal-route and rendered acceptance were still pending.

Original-Mac cross-check of the owner's artistic-pause hypothesis: the existing
unattended sequence has the menu in `tmp/story-reference-35-reference.png`
(frame 13,381) and landscape in capture 36 (frame 13,681), only 300 emulated
frames apart. The separately completed natural-idle reference trace
`tmp/m2-pak-idle-complete.log` records menu timeout at tick $2DB8 and scene
loaded at $2E28, a 112-tick interval (about 1.9 seconds). Its byte-guarded
observer leaves game code, timers and post-selection input untouched. These
observations do not support an intentional 46–50-second black pause; the
remaining native delay needs assessment as port overhead, while preserving
the original timing and scene progression.

Resource-stage timing then isolated 2,385 ticks (39.75 seconds) in `MoveHHi`,
versus 62 ticks loading all 41 song resources. The captured layout is a sound
handle followed by a large free block, then small movable blocks. Skipping
the free payload while preserving the same rotation/order/final addresses
reduces relocation to 113 ticks and the complete gap to 474 ticks (7.9 seconds),
with exact heap/fragmentation host tests passing
(`m2-song-load-cost-native-full.log`, `m2-movehigh-gap-native-full.log`, exit 0).
The full host suite passes (`m2-movehigh-gap-host-suite.log`, exit 0).
All six baseline native regression cases pass, including eight resource-exit
phases (`m2-movehigh-native-regression.log`, exit 0). The focused native heap
fixture passes all three stages (`m2-movehigh-heap-native-full.log`, exit 0),
and both link audits pass. The compiled move routine uses 36 bytes for locals
and saved registers, with no temporary buffer. Rendered confirmation of this
heap change was pending until the owner recording above. Two narrower, ineffective heap trials were reverted.
