# Bridge lane — Overnight 04 log

Dess's findings for the Overnight 04 execution packet. Split out of
`docs/ledgers/HUGE_BATCH_LEDGER.md` on 2026-09-22, mirroring
`docs/ledgers/PROD_OV04.md`: both lanes were appending to the end of one
file and every merge conflicted there.

The shared ledger still holds the scope matrix, the blocking table and
every finding from before OV04. Nothing here was renumbered.

---

### DESS-01 — four owner corrections to D-8, two of them real defects

**Dess, 2026-09-22.** The owner returned four focused corrections to the
cross-room contract. Two were defects in rules I had shipped and
sabotage-proven — which is worth saying plainly, because a rule can be
correctly implemented, fully tested, and still be the wrong rule.

**Correction 2 — room membership was standing in for operability, and
that is the defect.** `_explore` let the player set any variable whose
setter's room they could reach. Blindside's overhead gantry sits at
4.6 m with no mantle and no stairs, deliberately — so the search made it
operable the moment the player walked in underneath it, grapple or no
grapple. **The search was granting itself a capability**, which is the
direction in which nothing ever fails.

`ZoneStateSetter.capability` now declares what operating a control costs
over and above reaching its room, and the search treats it exactly as it
treats an edge capability: impassable without it. Two further
consequences, both of which would have been holes:

- **Setter capabilities join the undeclared-gate accounting.** A control
  you cannot operate without the grapple gates everything downstream of
  the state it sets. Collecting only edge capabilities would have put a
  hole in "no undeclared mandatory gate" in the same change that added a
  new way to make one.
- **§4.0's claim was too strong and is withdrawn.** It said a reversible
  variable "cannot strand you". `selects` proves a reversal *operation*
  exists; whether the player can reach that control and work it is a
  question for the route search and for `setter.capability`. The
  docstring now says so, and the two are kept apart — **physical
  operability evidence stays the engine lane's**, because a declaration
  the world does not match is a lie in either direction.

**Correction 4 — an acceptance-case requirement had become a content
restriction.** The cross-room rule refused *any* reader in the setter's
room. A lever that visibly moves something beside it and also opens a
way elsewhere is ordinary good design and there was never a reason to
forbid it. The rule now requires what the declaration actually claims:
**at least one consequence somewhere else.** Every-reader-local is still
refused.

**Correction 1 — held cross-room mechanics are UNSUPPORTED, not unfair.**
I had argued they are unfair by §34's standards. Withdrawn: that is an
argument about one staging of the mechanic dressed as a property of it.
They stay in the accepted design, marked unsupported by the current
contract, and the bounded §19.7 rule-2 amendment is **drafted and ready
to bring** rather than declined. Reversible configuration is approved
for the first Blindside integration and is **not a substitute** — where
a selected design wants a held requirement, the amendment comes with the
§30.6 re-check done, not a toggle wearing the name.

**Correction 3 — the consecutive-dock rule describes the implementation,
not the design.** It is accurate about what `RailCarrier` runs today and
**does not retire branching or switchable railways from the accepted
design**. Two naming hazards recorded so the distinction is not lost
again: `RailJunction` is *not* a track fork — it is one railway's
persistent machinery and the four-lifetime seam — and Blindside's
acquisition branch is **walked, not ridden** (`railway_scenario._branch`,
`walk_to`), so the selected configuration needs no branching rail at all.

#### Remaining railway support a branching or switchable configuration needs

Named now so it is a scoping list rather than a surprise. None of it is
required by Blindside's selected three-dock configuration.

| # | Support | Lane | Why it is not there today |
|---:|---|---|---|
| 1 | A carrier that can run a **graph** rather than one ordered route | engine | `RailCarrier` builds a link between consecutive docks only; a fork has no representation |
| 2 | A **switch** whose position selects which onward link is live | engine + bridge | nothing declares a switch; `RailSpan` has a control that *commissions* a span, which is a different question from *routing* |
| 3 | Switch position as **Zone state** rather than rail-local | bridge | D-8 already has the shape for it: a switch is a setter whose readers are spans. No new mechanism, and it is why D-8 must not grow a second railway |
| 4 | Route conditions over switch position in `reachability` | bridge | the macro component now exists, so this is wiring rather than design |
| 5 | Relaxing `_a_span_joins_docks_the_route_visits_in_turn` | bridge | one validator, and relaxing it invalidates no Zone that ever satisfied it |

Items 3 and 4 are cheap because the cross-room work already landed the
layer they need. Item 1 is the real engine cost and is the reason the
restriction stands today.

**Verification.** 7 new controls in `test_cross_room_state.py` (26
total), each correction sabotage-proven separately: ignoring setter
operability fails 3, dropping setter capabilities from the gate set
fails exactly the one that names it, removing the remote-consequence
rule fails 2.

### DESS-02 — the composer emits, the transition records, and one guarantee was vacuous

**Dess, 2026-09-22.** The next-checkpoint half the owner asked of this
lane: *"an actual composer path that emits the declared relationship,
plus the authoritative state-update/save path"*.

**The composer — `archipepsi_bridge/cross_room.py`.** It is handed a Zone
the campaign really composed and derives the relationship from that
Zone's own structure: which rooms exist, which are on the spine, where
the featured acquisition sits, which edge lies between the control and
the consequence. **Nothing in it names a room.** On the played Zone it
emits a control in `c002` and the consequence in `c023` — 21 rooms
apart, furthest-first, because taking the first candidate that works
takes the nearest, which is the weakest arrangement that still
technically crosses a boundary.

**It is a step, not a default, and that is deliberate.** Wiring emission
into `topology.apply` would move `played_zone_digest`, the placement
fixtures and the 0.3 comparison build in one commit. The owner's
standing instruction is to preserve the comparison and the review
snapshots, so a caller takes the step — the same shape `quiet.py` uses.
`test_the_composer_does_not_touch_the_zone_it_was_given` holds that
line.

**The setter's cost comes off the Zone, not a flag.** If the Zone
features an acquisition, operating the control requires it — which is
Blindside's gantry: overhead, out of reach, and the reason the branch
that supplies the tool exists. Correction 2 reaches the composer
without a second mechanism.

**The state-update path — `transitions.record_zone_state`.** Same shape
as `record_latch`: the engine reports the control was worked, and what
becomes save data is the accepted consequence, checked against the Zone
the campaign accepted. Three refusals, and the third is the one a latch
analogy would miss — **`states` is what the variable can HOLD,
`setter.selects` is what a player can PUT it in**, so a declared but
unselectable state is one nothing could have set, and §19.7 says nothing
but a player operating a setter moves Zone state. It writes
`macro_state`, never `latched`, so a reversal is a legitimate transition
rather than a hole in a monotone set.

**`test_every_transition_returns_a_validated_campaign` caught the new
transition missing from `TRANSITIONS`** before I did. That guard exists
because an unregistered transition is one nothing sweeps.

**AND ONE GUARANTEE WAS VACUOUS.** The composer's docstring claims it
*"declines rather than emitting something broken"*. Sabotaging the
`if reach.ok` that implements it left **all fourteen controls green** —
because on a Zone with no featured acquisition every candidate is
solvable and the check never fires. A guarantee nothing can falsify is
not a guarantee, and it is this project's oldest failure wearing a new
coat: a measurement that exists, is correct, and is never handed the
case that fails it.

The case it was missing: a Zone that grants a capability, composed for a
run **not guaranteed that capability**. The control then needs something
the player has not got, the gate is a route nothing opens, and the
composer must refuse. Three controls now cover it, and removing
`if reach.ok` fails exactly two of them.

**Verification.** `bridge/tests/test_cross_room_composer.py`, 17
controls, all against `playtest.played_zone()` or a Zone rebuilt from it
through `topology.compose_chain` + `apply` — the real composition path,
because slicing a finished Zone by hand leaves dangling edge references
and the validators correctly call that a fixture defect. Sabotage:
dropping the furthest-first preference fails 2, dropping the
select-check in the transition fails exactly its own, dropping
`if reach.ok` fails 2.

**What is still not done.** Prod's runtime half is unbuilt by agreement;
no physical acceptance has run; **transported-object support remains an
explicit unfinished 0.4 row**; and neither the macro declaration nor a
dev grant proves the featured-acquisition/AP delivery — that contract is
still M2's completion requirement and is untouched by any of this.

### DESS-03 — P-3's gap closed: the selection has a message now

**Dess, 2026-09-22.** Prod built the runtime half of D-8 and found the
hole from the other side: `ZoneProgress.with_macro` and
`transitions.record_zone_state` both existed, `latch_fired` and
`lock_opened` and their siblings were all there, and **nothing could
carry a Zone-state selection between them**. The engine had a selection
it could not report, so it correctly sent nothing and invented no
message — `ZoneState.as_reported()` was what it *would* send.

`ZoneStateSelected` is what it sends. Intent, union member, server
dispatch and handler arm, with the transition it lands in already
written.

**It is its own intent rather than a field on `LatchFired`, and the
reason is the one distinction this whole contract turns on.**
`handle_progress`'s docstring said *"every target set is monotone, so
the same event twice is one event"* — true of keys, locks, stations and
latches, and **no longer true**. `macro_state` is overwritten, so
idempotence here is per **`(variable, state)`**, not per variable:
re-selecting the state a variable already holds is absorbed exactly as
before, and selecting a different one is a **legitimate second event
rather than a replay**, because a reversible variable going back is the
mechanic working. The docstring is corrected; a resend rule that
swallowed the reversal would have made every reversible relationship
one-way at the protocol layer, which is the silent latch arriving by a
door nobody was watching.

**Verification.** 4 controls: the intent parses, the server routes it to
`handle_progress` (an intent the union accepts and the dispatch drops is
an intent that silently does nothing — the exact defect
`handle_progress` was written to close for keys and locks), the whole
path lands a value in the save, and the absorb/reverse pair.

### DESS-04 — P02 transaction edges and honest refusals, and a sabotage that tested nothing

**Dess, 2026-09-22.** Overnight 04, package P02. The first pass (D-1)
already covered a qualifying local Echo, the untouched foreign item,
duplicate confirmation, a delayed fold and a reload. The master names
four edges it did not, and they are now covered:

- **reordered confirmations** — two claims in flight, confirmed in the
  opposite order. `confirm_check` keys on `location_id`, so order cannot
  matter; an implementation that popped the FIRST pending record would
  pass every single-claim test and lose a Check here;
- **interruption between claim and fold** — the window the pending
  record exists for: cost spent, Archipelago told, interpretation not
  back. A restart there still owes the player the Echo;
- **process restart on both sides of completion**, asserted as two
  different states, because a test that only restarted after completion
  would pass with a save that dropped pending records entirely;
- **retry after an uncertain acknowledgment** — confirming twice after a
  dropped connection neither raises nor mints a second Echo.

**P02.7, the honest refusals.** An already-owned equivalent capability
reports case B and **not** case C: case C is a claim about *this Zone's
content*, so reporting it for something the fold already owns would
attribute the guarantee to the wrong thing. A Zone featuring nothing
establishes nothing and gets no guarantee invented for it. And a Zone
that hands over the hookshot has said nothing about `blink` — the
specific failure refused there is treating `featured_acquisition` as
evidence that a Zone is "an acquisition Zone" and letting any capability
through on the strength of it.

**A SABOTAGE THAT TESTED NOTHING, AND IT WAS MINE.** Checking the
reordered-confirmation control, I replaced `confirm_check`'s filter with
a pop-the-oldest version and the suite stayed green — which I read, for
several minutes, as the control being vacuous.

It was not. **The pattern I replaced occurs twice in `transitions.py`**,
and `str.replace(..., 1)` hit the first occurrence, 82 lines above
`confirm_check`, in an unrelated function. The sabotage was real, applied
cleanly, asserted as matched, and landed on the wrong code.

Targeted inside `confirm_check` the control fails immediately, as it
should. The methodology fix is one line and applies to every sabotage
this project runs: **assert the target FUNCTION changed, not that the
pattern matched.** `inspect.getsource(fn)` is the check —
`'SABOTAGE' in inspect.getsource(T.confirm_check)` — and a sabotage that
cannot show that is a sabotage that proves nothing about the control it
was aimed at. Written down because a green suite under sabotage looks
exactly like a vacuous test, and the wrong conclusion from it is to
delete a control that was working.

### DESS-05 — P04's snapshot is mostly already written, and one row is closed by policy

**Dess, 2026-09-22.** Package P04, bridge half. The useful finding is
what did **not** need building.

**The carrier pose row is closed by an accepted decision, not by a
missing field.** `E-011-save` asks for "carrier poses, destinations and
hold states restored before the player", and the natural reading is a
saved transform. `rail_junction.gd`'s own four-lifetime docstring says
the opposite and says it for a reason: **a carrier is restored to a
SUPPORTED DOCK, never to a saved transform**, because one resumed
halfway across a link this build did not commission would be standing on
track that is not there. `restore_from` re-parks at `home_dock` — which
is the field F-24 answer 3 added.

So implementing a saved carrier pose would have **violated** the
safe-machinery policy while appearing to close a row. P04.1's wording is
"*appropriate* machine poses/destinations/holds", and the appropriate
representation here is none.

**What the save does carry**, checked against D-8 §3's five lifetimes
rather than asserted: permanent consequences (`latched`), reversible
configuration (`macro_state`), equipment, allocation, manifest
provenance. Lifetimes 3 and 4 are `EPHEMERAL` and **their absence is the
representation**. Lifetime 5, transported objects, stays an explicit
unfinished 0.4 row and the control says so — which is what stops a later
reader assuming it is covered.

**The guard that earns its place.** A name scan over `ZoneProgress`,
`ZoneRecord` and `CampaignSave` fails on anything that looks like live
or physical state — transform, pose, velocity, voltage, elapsed. §5.4a:
a save that stored voltages could disagree with the graph that produced
them, and one that stored poses could put the player on absent track.
The linter is shown catching two synthetic bad names before it is
trusted to report none, because without that it would pass equally well
with an empty forbidden list.

**Restart points are asserted to be different states** before each is
round-tripped. P04.3 asks for restarts at *meaningful* points, which
only means something if the points differ; a save that collapsed two of
them would pass a single-point test.

**Not done here, and deliberately:** actually terminating and restarting
the client, machinery interrupted mid-motion, and the user-facing
failure paths are Prod's. A JSON round trip is not reported as any of
them.

### DESS-06 — P16: transported objects, the row that was explicitly unfinished

**Dess, 2026-09-22.** D-8 lifetime 5 had a table row, no field and no
producer, and both the contract and Prod's matrix said so. It is
declared, persisted, authoritative and recoverable now.

**Two settled rules met here and only one needed an amendment.** §10.5
already said a multi-room carryable is `ZONE_PERSISTENT` with an
`allowed_volume` — persistence needed nothing. What was genuinely open
was **authority**, and D-8 §11.1 took Prod's answer narrowed to exactly
that: a transported object is room-layer state **whose owning room is
its current room**, and crossing a boundary is a TRANSFER, not a write
to the machine layer. §19.7 rule 2 stays intact and no room addresses
another to make it happen — the player carries it, which is "the player
is the bridge" in its most literal form.

| piece | where |
|---|---|
| declaration | `Zone.transported_objects`, `TransportedObject` |
| volume, home, and whether losing it matters | `allowed_volume`, `home_room_id`, `required` |
| save | `ZoneProgress.object_rooms`, overwritten not accumulated |
| the message | `ObjectTransported` intent, routed to `handle_progress` |
| authority | `transitions.record_object_transported` |
| recovery | `transitions.recover_transported_object` |

**What the save records is the ROOM and nothing else about the object**
(P16.5). Its Statuses are `EPHEMERAL` by §5.1, so a `BURNING` cell
carried three rooms arrives having been carried three rooms and **not
still burning** unless something sets it alight again. Persisting the
Status would turn a temporary effect into a permanent fact — §3.1's rule
in the place it is easiest to break by accident. Its transform is absent
for §5.4a's reason, and DESS-05's name guard now fails if either
appears.

**Recovery is its own event, not a correction.** An arrival outside the
volume is refused and records nothing — including no recovery. Folding
the two together would make every illegal arrival silently correct
itself with nothing to notice, which is how a composer defect becomes
invisible.

**Sabotage, with DESS-04's fix applied.** Each check was neutralised
*and confirmed present in the intended function via
`inspect.getsource`* before the run: dropping the volume check fails 2
controls, dropping home-inside-volume fails exactly its own.

**Not done:** moving it physically is Prod's (P16.2), and nothing
composes a transported object yet — the declaration is real and no live
seed emits one.

### DESS-07 — P08: the composer can only place three of ten, and pricing is the blocker

**Dess, 2026-09-22.** Prod's P06 landed behaviour for all seven
remaining roles and derived `ENEMY_ARCHETYPES` from `ENEMY_STATS`, which
made the merged tree red in five bridge controls. Four were stale
transcriptions. **The fifth is a real blocker and it needs one decision
from the owner.**

**The composer places `melee`, `ranged` and `brute` and nothing else.**
`epsilon/fallback.py` picks from a hard-coded `["melee", "ranged"]` in
four places and one `brute` in the arena recipe, while ten roles have
envelopes, stats and — since P06 — behaviour. P08's closure asks that
new roles "actually appear in admissible ordinary candidate encounters".
They cannot yet, and here is exactly why.

**Implemented is not composable, and conflating them was the defect.**
`test_the_content_value_table_scores_only_placeable_roles` asserted
`set(ENEMY_VALUE) == set(ENEMY_ARCHETYPES)` — true while both were the
trio, and it broke the moment one of them grew. The two mean different
things: `ENEMY_ARCHETYPES` is *the engine has behaviour for this*,
`ENEMY_VALUE` is *a Zone's content budget knows what this costs*. The
invariant that survives is `ENEMY_VALUE ⊆ ENEMY_ARCHETYPES` — nothing
priced that cannot be placed — and the other direction is now a named
gap rather than a satisfied rule.

**THE BLOCKER, AND IT IS ONE INTEGER PER ROLE.** Seven roles have no
approved content value: `charger`, `bulwark`, `scuttler`, `artillery`,
`beacon`, `diver`, `drifter`.

**It cannot be derived, and I checked before saying so.** `ranged` is
worth **more** than `melee` — 4 against 3 — while having less hp (16 vs
24), less dps (4.0 vs 6.0) and no melee threat. Content value scores how
much a role changes *the way a room is fought*, not how long it takes to
kill, exactly as `ENEMY_VALUE`'s own comment says of the brute. Any
formula fitted to hp and damage ranks those two the other way round and
contradicts the owner's own numbers. So none is offered and none is
guessed.

Until then: `COMPOSABLE_ENEMY_ROLES` is implemented-and-priced,
`UNPRICED_ENEMY_ROLES` is the rest, and `enemy_value()` **raises instead
of scoring zero** — because `ENEMY_VALUE.get(role, 0)` is precisely how
an unpriced role becomes free content, passing the budget check and
handing the player a Zone whose accounting is a fiction.

**What is ready the moment those seven numbers exist.**
`constants.roles_that_fit(width, depth, wall_height)` answers which
roles a room can physically hold, from `ENEMY_ENVELOPES` rather than
from anything chosen here: a role clears the ceiling if its `top_y` is
under the wall, and fits the floor if its `lane_width` is under the
shorter axis. Necessary, not sufficient — it does not claim the
encounter is good, and `ENEMY_STATS` carries `reach` but no minimum
range, so the roster brief's "nothing at all inside 8 m" for artillery
stays in the engine and is not a number this function may invent.

**The other four failures were stale transcriptions, repaired upward.**
The roster test asserted the seven were NOT placeable — true when they
had no behaviour, and the opposite of the goal; it now asserts all ten
are. `test_the_on_hit_list_is_derived_rather_than_transcribed` kept a
hand-written list of eight as its *expectation* and went stale when
`empowered` gained `enemy` support — the beacon buffing its allies,
exactly what that role is for. A test that transcribes what it checks is
the defect it was written to catch, so the expectation derives from
`SUPPORTED_STATUS_TARGETS` now. The two baseline fixtures were
regenerated from source.

### DESS-08 — P10.5: the count matched by coincidence, and the family is 0/13

**Dess, 2026-09-22.** P10.5 asks for *"a compact matrix covering all
thirteen effective Statuses against their specified targets"* and warns
that *"a fixed catalogue count must never hide an incomplete family"*.
It was hiding one.

**`SUPPORTED_STATUS_TARGETS` has thirteen entries. Amalgam §15.2's
family has thirteen members. They are not the same thirteen.**

| | |
|---|---|
| §15.2's family | `lightened` `anchored` `slippery` · `confused` `turncoat` `blinded` `exposed` · `silenced` `rooted` `phased` · `burning` `conductive` `brittle` |
| supported today | `lightened` `burning` + eleven retained **ECHOES** kinds (`slowed` `frozen` `shocked` `poisoned` `marked` `stunned` `vulnerable` `empowered` `low_profile` `haste` `regenerating`) |
| in both | **two** |

**And neither of the two is finished.** `lightened` crossed on `object`
only (D-7) and is missing `enemy` and `self`; `burning` has `self` and
`enemy` and is missing `object`, `surface` and `volume`. So **no Status
in the Amalgam family covers all of its specified targets**, and eleven
have no support at all.

Nothing here is a regression — the eleven ECHOES kinds are real,
implemented and used. What was wrong was the impression a matching count
gives, and the fix is that coverage is now **computed**:
`AMALGAM_STATUS_TARGETS` is the family as data and
`amalgam_status_coverage()` returns the missing pairs per Status. The
control asserts the current gaps exactly and says, in its own message,
that a row emptying means updating it rather than deleting it.

**The target names are translated, and the translation is declared.**
P09.4 warns that *"`self` is not automatically every player/actor
target"*. Design 5 writes actor / object / surface / volume / player;
the runtime kinds are self / enemy / object / surface / volume. The
mapping is `player → self` and `actor → enemy`, written down once and
used nowhere implicitly — so `confused`, an actor-only cognitive effect,
gets `enemy` and **not** `self`, while `lightened`, listed as actor and
object and player, gets all three.

**Two rows carry design rules rather than data.** `brittle` is
object-and-surface only, because it is the one Status that touches a
damage number and an actor row would put a multiplier on a combatant —
§15.3 rule 2, and Law 27 behind it. `exposed` is actor-only because
objects have no Defense stat and an object row would silently invent
one; §15.2 corrected itself on exactly this point and the catalogue now
carries the correction instead of the prose alone.

**Not done:** the adapters are Prod's (P10.1–P10.4). The
`burning`/`poisoned` compatibility decision remains the owner's and
blocks only its own subset, exactly as the dispatch says.

---

## Bridge lane handoff — state at the end of this session

**Head:** this commit on `claude/archipepsi-0-4-blindside`, PR #12.
`make test` **1700 passed, 6 skipped**; `check_packet` green; working
tree clean and pushed. Generated artifacts (`make export`,
`make zone-fixture`, `make baseline`) regenerated from source, never
hand-edited. The 0.3 comparison build on
`claude/archipepsi-echoes-continuation-b1adno` and the
`review/0.4-m2mech-snapshot` head are untouched; no original save was
migrated.

### Closed this session (bridge half)

| package | state |
|---|---|
| **P02** acquisition + AP obligation | `.1 .2 .3 .4 .5 .7` done; `.6` is Prod's equipment/gantry consumer |
| **P03** cross-room state runtime | bridge half done; `ZoneStateSelected` closed P-3's gap |
| **P04** restart persistence | **OPEN.** `.1` representation stands. `.3` bridge half now crosses a real process boundary AND resumes transitions inside the restarted interpreter (owner correction, 2026-09-22) — still not the full lifecycle: a normal bridge/client restart and restored gameplay are unwritten, and the PID check is not that. `.6` now has BOTH: stray-file recovery, and a writer SIGKILLed inside `write_save` at three real kill points with the previous save intact, sabotage-confirmed against a naive writer |
| **P16** transported objects | **OPEN.** The declaration, save, intent, authority, recovery and the consuming mechanism stand as *ownership, reporting and bridge-consistency* evidence. Recorded same-room presence is a **precondition**, not proof a physical consumer accepted the object (owner correction, 2026-09-22). Unwritten: actual transport and interaction, supported Status continuity across the boundary, and the selected object's lifecycle/recovery through the authority split — Prod's runtime half. Also new: §10.3 now refuses a transported object the player could not carry |
| **P10.5** Status matrix | the family is data and coverage is computed |

### Three precise blockers — each blocks only its own subset

1. **Seven enemy content values.** `charger`, `bulwark`, `scuttler`,
   `artillery`, `beacon`, `diver`, `drifter` have envelopes, stats and
   behaviour and **no approved `ENEMY_VALUE`**, so the composer cannot
   place them (DESS-07). It is one integer each and it cannot be
   derived — `ranged` is worth more than `melee` while having less hp
   and less dps, so any stats formula contradicts the owner's own
   numbers. `constants.roles_that_fit()` and `COMPOSABLE_ENEMY_ROLES`
   are already wired; the moment the numbers exist, widening the
   composer's selection is a small edit in `epsilon/fallback.py`
   (four `rng.choice(["melee", "ranged"])` sites plus the arena recipe).
2. **`burning` / `poisoned` versus Amalgam's no-direct-Status-damage
   rule.** Recorded, still the owner's, blocks only those rows.
3. **A live held cross-room requirement.** Unsupported by the current
   contract; the bounded §19.7 rule-2 amendment is drafted in D-8 §11.2
   and comes to the owner if a selected design needs one.

### Exact next actions, in order

1. **P14** — the shared signal graph declaration. Not started. Reuse the
   D-8 handle layer; no second signal system and no global bus.
2. **P19** — item grammar and Epsilon's supported choices. Not started.
3. **P01.2** — offer the existing minors through the composer.
   `cross_room.compose_zone_state` is the pattern: an explicit step that
   derives from a really composed Zone and declines rather than emitting
   something broken.
4. **P20** — the approved Forge/Static transaction subset, once the
   exact approved operation list is confirmed.

### Two methodology notes worth keeping

- **A sabotage must be shown to hit the function it aimed at**
  (`inspect.getsource`), not merely to have matched a pattern. One
  pattern here occurred twice and the sabotage landed 82 lines away,
  which reads exactly like a vacuous control (DESS-04).
- **A guard that can only report "nothing found" should be shown
  finding something first** — the forbidden-field name scan in
  `test_restart_persistence.py` catches two synthetic names before it is
  trusted to report none, because otherwise it passes with an empty
  list.

---

### DESS-09 — P14, P19 and P20 measured for readiness, and two are not ready

**Dess, 2026-09-22.** Having closed the bridge halves of P02, P03, P04,
P16 and P10.5, I measured the next three packages in this lane's order
before starting one. Two are not ready, and the reasons are different.

**P14 — shared signal graph. NOT READY, and building it would be the
thing P14.5 warns against.** The measurement: the engine has exactly one
signal chain, `PoweredLink` (plate → signal → door), plus `ClassPlate`.
There is no node vocabulary, no conduit, no graph. Design 1 §19's eleven
node types and Amalgam §20's eighteen sensors are design, not code.

Declaring an eleven-node vocabulary now would be a framework no room
uses — P14.5 says in its own words that such a framework "is not this
package's completion" — and the dispatch forbids publishing inert
support. The one piece with two real implementations, §20.6's semantic
class versus summed kilograms, is **already implemented and already
self-documenting**: `class_plate.gd`'s own docstring cites the
distinction and it never adds masses. There is no bridge gap to close
there.

What would make P14 ready: a second real consumer whose question
matches. D-8's `ZoneStateReader.mechanism` is the seam it should join
when one exists, and no second railway or global bus is needed to do it.

**P19 — item grammar. NOT STARTED, and deliberately not half-started.**
There is no gear, mod or item vocabulary in the bridge at all; §16 is
design only. This is a subsystem rather than a slice, and the dispatch's
"preserve a usable candidate rather than starting everything and
integrating nothing" applies directly. It is the largest genuinely ready
bridge unit remaining and it wants a session that can finish it.

**P20 — Forge/Static transactions. BLOCKED on a recorded decision.**
`HUGE_BATCH_LEDGER.md`'s approved-assignment block lists the Forge /
Static economy (B4) under "Decisions still unresolved", and P20.1 is
"identify exact approved operations". That list does not exist yet, so
the package blocks on its own exact subset, as the dispatch anticipates.

**One thing measured and found already correct.** The eligibility gate
added in DESS-07 could have been hiding a live defect, so I checked the
real composed Zone: **zero** placed enemies sit in a room that cannot
hold them. The gate is a guard for the seven roles that are not
composable yet, not a repair of something broken today, and there is now
a control asserting that over real output — with a companion assertion
that the sweep saw enemies at all, because a sweep over zero rooms
passes for the wrong reason.

---

### DESS-10 — P19.1: the Gear grammar, and nine atoms nobody costed

**Dess, 2026-09-22.** DESS-09 called P19 "a subsystem, not a slice" and
left it. That was half right: the *runtime* is a subsystem, but **the
grammar is a slice**, it is fully specified, and Prod and Epsilon both
need it before anything can implement against it. `schemas/gear.py`.

Amalgam §16 pinning Design 4 §16.1–§16.3: four territories, twenty-five
domain atoms, three magnitude atoms, and the rule that a `HIGH` piece
carries **exactly two** domain atoms from **one** territory — Design 4's
expression of Design 1 §4.5's "high-tier Gear has exactly two
intrinsics".

**The design's own arithmetic is a control.** §16.1 states outright that
`dom_crit` (26) + `mag_marked` (44) = 70, leaving 30, which exceeds the
22 clause allowance and is why the resolver completes the piece with a
second atom. The module reproduces 70 from its own tables, so a
mistranscribed cost fails there rather than surviving into a budget.

**NINE OF THE TWENTY-FIVE HAVE NO COST**, and they are listed rather
than guessed: `dom_read_stress`, `dom_read_machine`,
`dom_read_compounds`, `dom_status_duration`, `dom_relation_count`,
`dom_signal_range`, `dom_transfer_range`, `dom_rail_control`,
`dom_impact_resistance`. The Amalgam says its additions arrive *"at the
magnitudes that proposal gave it"* — those numbers are in Designs 2, 3
and 5 and have not been carried across. `composition_cost` **raises** on
one rather than scoring it zero, which is `content_value.enemy_value`'s
rule and the same reason: a free atom passes the budget check and makes
the piece a fiction. The list is derived from the two tables, so
recovering a cost removes it without anyone editing a list.

**A vocabulary is not an offer.** `SUPPORTED_GEAR_DOMAINS` is **empty**
and `refuse_unsupported_domain` refuses all twenty-five — NO GEAR BEFORE
ITS RUNTIME, the rule the Status vocabulary already follows. An unknown
atom is refused *before* the support question, so a typo comes back as
"not a §16 atom" rather than "not implemented yet", which reads like
something that will arrive. And the gate is shown admitting a domain
under a patched support table, because a blanket refusal looks identical
to a working gate while the table is empty.

**Still open in P19:** `.2` qualified creation and fallback, `.3` gear
and mods, `.4` Epsilon's actual agency, `.5` provider paths, `.6`
boundary tests — all of which need either the nine costs or a runtime
consumer.

---

### DESS-11 — four owner corrections, and three of them were my errors

**Dess, 2026-09-22.** Corrections 1, 2, 3 and 4 of the OV04 clarification.
Three were mistakes in work I had already shipped and reported as sound.

**Correction 4a — I invented a doorway cleanse.** The `TransportedObject`
docstring said a `BURNING` cell "arrives having been carried three rooms
and **not still burning**". That conflates what survives a **save** with
what survives a **doorway**. §5.1 puts `ActiveStatus` in `EPHEMERAL`,
which is a statement about saves alone; carrying an object between rooms
in live play is not a reload, and a Status on it follows its own
duration and removal rules.

The evidence was in my own paragraph: I quoted the union's example —
*"a `BURNING` power cell carried three rooms to a generator"* — and then
contradicted it two lines later. That sentence only means anything if
the cell is still alight when it arrives. Corrected in `zone.py`,
`protocol.py`, the test and the generated exports, which had carried the
wrong claim to the engine.

**Correction 4b — I generalised one railway's policy into a universal
ban.** DESS-05 read `rail_junction.gd`'s supported-dock restore as a
rule about all physical saved state, and built a guard that failed on
any field whose NAME contained `pose`, `transform`, `velocity` or
`elapsed`. **EX50-011 §9 asks for exactly that field**: *"carrier poses,
destinations and hold states are package-local. A stable save restores
each at its saved pose before the player."* A runtime comment about one
package does not supersede a selected spec about another.

The two contracts differ for a reason worth stating: a `RailSpan` is
**commissionable**, so a carrier restored to a transform may be standing
on track this build did not commission — restore it to a supported dock.
Passing Platforms' carriers run a fixed schedule on a path that always
exists, so a saved pose contradicts nothing. **Conditional path, restore
to a dock; unconditional path, restore the pose.**

The name scan is replaced by `SAVE_FIELD_CATEGORY` and
`categorise_save_field`, which check §5.1's five categories. What §5.4a
forbids is a **derived live value** — something the graph recomputes —
and `EPHEMERAL` is precisely the category of things rebuilt rather than
restored. Physical state a package's contract requires is permitted and
declares its category.

**Correction 2 — provisional pricing, and it unblocked the composer.**
Seven values chosen against the three anchors and explained one by one
in `content_value.ENEMY_VALUE`; they are **judgements, not derivations**,
and revising them is expected. With them the composer places real
mixtures for the first time:

| | before | after |
|---|---|---|
| distinct roles | 3 | **7** |
| enemy groups | 11 | 11 |
| enemies | 35 | 39 |
| enemy score | 128 | **156** |

**Three defects surfaced on the way, and the suites named all three.**

1. **A fourth list of one fact.** `Archetype` in `zone.py` was still
   `Literal["melee", "ranged", "brute"]` beside `ENEMY_STATS`,
   `ENEMY_ENVELOPES` and `ENEMY_ARCHETYPES`. The engine could spawn a
   drifter, the value table could score one, and a Zone naming one would
   not validate. Derived now.
2. **The budget was charged at melee's price** whatever was placed, so
   every `ranged` group was undercharged by a point. Fixed to charge the
   role chosen.
3. **Choosing before checking affordability** pushed the builder onto
   the retry loop — `test_fallback_scale` caught it by name, which is
   precisely what that suite exists for. Affordability is a third gate
   beside geometry and pricing, not a coin toss after the choice.

**And `brute` is not ordinary filler.** Making it one choice among ten
put **seven** brutes in a 700-point Zone against a cap of four. It is
the boss-scale role the landmark recipe places by name, once, which is
why it is the only role with a Zone-wide cap. `_eligible_roles` defaults
to excluding it and a caller that has counted may opt in.

**Correction 1 — P14 is ready work and I was wrong to defer it.** The
next slice is agreed as an existing room's real chain rather than the
eleven-node catalogue. Not started in this session.

**Correction 3 — the P04/P16 labels were overbroad.** Reopened below.

### DESS-12 — P04 and P16 reopened: what the evidence actually shows

**Dess, 2026-09-22, owner correction 3.** Both packages were reported
closed on the bridge half. The work stands; the **labels were wider than
the evidence**, and here is the exact gap in each.

**P04.3 asked for cold process restarts.** It says so in the unit:
*"actually terminate and restart the relevant client/bridge processes
on disposable saves ... verify real world state, remaining Checks and
usable return, not just serialized JSON equality."* What
`test_restart_persistence.py` does is
`CampaignSave.model_validate_json(save.model_dump_json())` — one process,
no terminate, no relaunch. **That is serialization evidence.** It proves
the representation round-trips; it proves nothing about a world coming
back up.

What it would take: terminating the bridge and the client on a
disposable save at each of P04.3's five points — before grant, after
grant, after a branch power change, after a span repair, and with the
carrier away from home — and reading real world state afterwards. The
client half is Prod's; the bridge half is a harness that stops and
restarts the process rather than re-parsing a string, and it does not
exist.

**P16 moved an object by assignment, not by carrying it.**
`record_object_transported(save, zone, object, room)` is the authority
and reporting path, and it is correct: it refuses a room outside the
volume, it refuses an undeclared object, recovery is its own event. What
it is **not** is a player carrying something. Nothing picks the object
up, nothing crosses a boundary with it, and **no consuming mechanism
accepts it at the far end** — P16's generator is a destination with a
socket that does something when the cell arrives, and there is no such
consumer anywhere.

So the honest split: **ownership, volume, persistence and recovery are
done. Transport and consumption are not started.** The transfer message
exists and nothing sends it from a pair of hands.

**Neither row is discarded and neither is rewritten.** The controls that
exist keep testing what they always tested; what changes is that they no
longer stand under a heading claiming more than they show, and
`test_restart_persistence.py` now says *round trip* wherever it used to
say *restart*.

---

### DESS-13 — P14's first slice: the chain that already runs, declared

**Dess, 2026-09-22.** DESS-09 called P14 not ready because the graph did
not exist. The owner corrected that: P14.5 requires implementing the
shared graph **and** moving real consumers onto it, and does not require
the graph to pre-exist. The correction is right and the earlier reading
was a way of not starting.

**The slice is one real chain.** `unweighted_switch.gd` runs a HEAVY
`ClassPlate` through `not satisfied` into `ServiceShutter.command()` —
a sensor, a §19.2 `NOT`, and an actuator, wired in GDScript as a signal
handler. `schemas/signal_graph.py` names exactly that, so a Zone can
**ask** for the chain instead of a scenario hard-coding it, which is the
move `RailNetwork` made for the railway.

**Two guarantees are structural rather than checked.**

- **A cycle cannot be written down.** §19.3 evaluates in topological
  order; declaration order *is* that order, so a node may only name
  something already declared and a cycle has nowhere to be expressed.
- **Nothing can point outside its own room.** Every input names a node
  of this graph, so §19.7 rule 2 holds by construction — the forbidden
  global signal bus is not banned, it is unwritable. Both were
  sabotage-proven, each confirmed in the intended function via
  `inspect.getsource` first.

**Unsupported is named, not offered.** `NODE_KINDS` is §19.2's complete
eleven and `SENSOR_KINDS` is §20's eighteen, because a vocabulary with
holes cannot tell *"not supported yet"* from *"not a thing"*.
`SUPPORTED_NODE_KINDS` is `("NOT",)` and `SUPPORTED_SENSOR_KINDS` is
`("PRESSURE_PLATE",)` — the one chain that runs. A typo and a gap get
**different messages**, because one message makes a misspelling read
like a feature request. Exported as `SIGNAL_NODE_KINDS`,
`SIGNAL_NODE_KINDS_IMPLEMENTED` and their sensor pair, so the engine
boundary refuses from the same source the schema does.

**§20.6 is why the sensor is worth naming.** A `PRESSURE_PLATE` reads a
semantic `MassClass` and **never accumulates** — three `LIGHT` never
make a `MEDIUM`; `WEIGHT_THRESHOLD` sums kilograms and is the only
sensor that does. `class_plate.gd` implements the first and
`PoweredLink` the second. Only the first is offered, because only the
first is what the declared chain uses.

**`test_epsilon_vocabulary` caught a free string.** `LogicNode.inputs`
was `tuple[str, ...]`, which would have let Epsilon name anything at all
— including something outside the room, the one thing the graph must
never be able to say. Constrained to a node-ref type.

**Per-role accounting, finished.** `room_value` still read
`ENEMY_VALUE.get(role, 0)` — the last silent zero, where an
implemented-but-unpriced role would score nothing and the room would
read cheaper than it is. It calls `enemy_value()` and raises now.
`ENEMY_VALUE` records that **the score is a content budget and not
measured difficulty**: a Zone at 156 is not "22% harder" than one at
128, and the seven provisional entries have had no playtest at all.
`APPROVED_ENEMY_VALUES` and `PROVISIONAL_ENEMY_VALUES` say which is
which so nothing downstream infers it from a comment.

**Still Prod's, and not claimed here:** the runtime that reads these
declarations, and the Godot verification of the widened encounters. A
bridge-valid enemy list is not a played encounter and this lane cannot
make it one.

---

### DESS-14 — P16's consuming mechanism: transport that means something

**Dess, 2026-09-22.** DESS-12 reopened P16 because ownership and a room
were the overbroad part: an object could arrive somewhere it was allowed
to be and **nothing happened**. The generator in the union's own
sentence — *"a `BURNING` power cell carried three rooms to a
generator"* — is the missing half, and `ObjectConsumer` is it.

**The consequence goes through D-8's handle, not a new channel.** A
consumer that accepts its object sets a declared Zone-state variable,
which the rest of the Zone already knows how to read. Nothing here
addresses another room and nothing writes to a machine layer, so there
is no second mechanism for "something happened over there".

**The check that makes transport mean something:** the mechanism fires
only when the save says its object is **in the consumer's own room**.
Sabotaged and confirmed in `record_object_consumed` via
`inspect.getsource`; removing it fails exactly that control.

**CORRECTED, 2026-09-22 (owner): what that check is and is not.**
Recorded same-room presence is a **bridge consistency precondition**,
not proof that a physical consumer accepted the object. It refuses a
consume intent that contradicts the save's own record of where the
object is — a client cannot claim a delivery while the save says the
object is three rooms away. It does not establish that anything was
carried: the recorded room came from the client's own earlier transport
report, so the two reports are checked against each other and neither
is checked against a physical scene. An earlier revision of this
paragraph said a mechanism firing "on a message alone" would let a
client claim a delivery it never made, which reads as though this
control closed that hole. It narrows it to clients that contradict
themselves. The physical half — an object actually carried, actually
handed to a consumer that accepts it — is Prod's runtime and is
unwritten.

Four other ways a consumer can be a promise nothing keeps, all refused:
a room the Zone lacks, an object it does not declare, a consequence
that is a variable without a state (or the reverse), and — the one worth
naming — **a consumer outside its object's `allowed_volume`**. §10.5's
volume is where the object may go, so a consumer beyond it is a
destination nothing may ever legally reach, and the puzzle would be
unsolvable in a way no route search sees.

**Consuming does not make the object vanish.** What the mechanism
changes is the Zone's state; the object's room is still its room. A
scenery consumer that sets nothing is legal and changes nothing.

**An error path that swallowed its own error.** `next()` over the
consumers raised `StopIteration` before the validator ran, so an unknown
mechanism came back as a bare traceback instead of the refusal written
for it. Looked up safely now.

**Still open at corrected scope.** Nothing picks the object up and
carries it — the player-operated route is Prod's runtime, and this lane
cannot produce it. What exists now is: a declared object, a declared
volume, a declared destination that does something, authority over
arrival, recovery, and a refusal when the delivery has not happened.

---

### DESS-15 — P04.3: the bridge dies and its state comes back

**Dess, 2026-09-22.** DESS-12 reopened P04.3 because a JSON round trip
is serialization evidence and the unit asks for something else:
*"actually terminate and restart the relevant client/bridge processes on
disposable saves ... not just serialized JSON equality."*

`bridge/tests/test_cold_restart.py` does that for the bridge half. Every
case writes a save through `store.write_save`, lets the writing
interpreter **exit**, and starts a **new `python3` subprocess** that has
never held any of the first one's objects. Nothing passes between them
but the file. `sys.executable -c`, not an import — a stale module-level
cache would survive an import and would not survive this.

**The harness proves itself before anything leans on it.** One case
asserts the restarted process has a different PID, because a subprocess
that silently ran in-process would make every other case a round trip
wearing a restart's name.

Across the process boundary: the claim in flight before any grant, with
the fold still empty; a reversible configuration; the **permanent and
reversible changes coming back apart**; the remaining allocated Checks;
and the committed manifest with its `ACCEPTED` layout state — a Zone is
solved once and replayed forever, so provenance that did not cross a
restart would make the replay a recomposition.

**The reversal is made after the restart**, in the process that reloaded
the save, and the one-way variable still refuses to go back. A save that
came back with the reversible one flattened into a latch would fail
there rather than in review.

> **CORRECTED, 2026-09-22 (owner).** When first written, that paragraph
> was not true of the code it described. The restarted child read the
> two variables back; the **reversal ran in the parent**, against an
> in-process `model_validate_json` round trip, in the interpreter that
> had written the save and still held every object in it. The label
> claimed evidence the test did not produce.
>
> Repaired rather than deleted. `_resumed_in_a_fresh_process` now runs
> the resumed transitions **inside the restarted interpreter** and
> asserts there; the parent only checks that it exited cleanly and
> reads back what it reported. Two harness self-proofs were added
> first, because a child whose assertions could not fail the parent
> would look exactly like a child whose assertions passed: one case
> fails an assertion in the child, one raises from an `else` branch,
> and both must reach the parent. A second case now **carries the
> campaign forward** in the child — a claim and a configuration change
> on the disk-loaded save — because a save every field of which reads
> back correctly can still be one no transition will accept.

**Stray-file recovery, and NOT an interrupted write.** `write_save`
fsyncs a temporary file before replacing the real one, and a
half-written `.tmp` left beside a save is not mistaken for it. That is
what the case proves, and it is now named
`test_a_stray_partial_temp_file_is_not_mistaken_for_the_save`.

> **CORRECTED, 2026-09-22 (owner).** It was called
> `test_an_interrupted_write_does_not_destroy_the_previous_save` and
> cited as P04.6's interrupted-write evidence. Nothing in it is
> interrupted: a complete `write_save` runs to completion and a partial
> file is then placed beside the result. The atomicity claim it stood
> in for — a writer killed *between* the temporary file and the
> rename leaves the OLD save intact — needs the writer terminated
> mid-call with a previous save already present. Named here rather than
> implied by the one next to it — and then **written**, below.

**P04.6's actual interrupted write, at three real kill points.** A child
process is SIGKILLed *inside* `write_save`, with a previous save already
on disk: before the temporary file is fsynced, while the backup is being
copied, and between the temporary file and the rename. SIGKILL is
uncatchable and unflushable, so no `finally` runs and nothing is cleaned
up; whatever the directory holds afterwards is what a power-loss-shaped
crash leaves. In all three the previous save comes back **intact and
un-half-updated**, read by a fresh interpreter because the one that was
mid-write is gone. The two payloads differ by VALUE rather than by
presence — a survivor that merely lacked the variable would read the
same as an old save and as a default-constructed one. A fourth window,
inside `os.replace` itself, does not exist: the rename is atomic in the
filesystem, which is the whole reason the function is shaped this way.

**Sabotaged, because three passing kills prove nothing on their own.**
Three cases that kill a writer and find the old save intact look
identical to three that kill a writer which never touched the primary.
So one case replaces `write_save` in the doomed child with the naive
version — open the primary, write, die — and the old save must come
back **damaged**. It does.

**And the loader refuses rather than returning nothing.** That sabotage
surfaced the behaviour: a torn primary raises `SaveUnreadable` —
*"save file(s) exist ... and none could be read; refusing to start a
fresh campaign over them"* — where a `None` would read as "no campaign
here" and the next write would start a fresh one over the wreckage.
A separate hand-truncated case that had stated the same fact on its own
was removed; the fact is now carried by the sabotage, arrived at by a
real kill instead of by damage placed by hand.

**A latch was the obvious thing to test and it needs a committed physics
package.** A `permanent` Zone-state variable is the same monotone fact
with no scaffolding, and §4.0 proves its monotonicity from the
declaration rather than from a label — so the distinction is tested on
the mechanism that carries it rather than on the one that happened to
exist first.

**Disposable saves only**, all under pytest's `tmp_path`. No original is
read, written or migrated.

**The PID check proves the harness, not the lifecycle.** It says the
child is a different process, which is what every other case leans on.
It says nothing about a normal restart of the bridge and client, and
**P04 is not complete.** What remains, stated so it cannot be read off
as done: a normal bridge/client restart, and **restored gameplay** —
the player resuming in a Zone that behaves as it did. Relaunching the
Godot client and reading real world state is Prod's; no case in this
file claims it; and the resumed-transition evidence above is the
bridge's half of the lifecycle, not the lifecycle.

---

### DESS-16 — the doorway clearance: brute fails worst, and it predates the widening

**Dess, 2026-09-22.** Prod recorded, in `7b30c04`, that
`ContentInstantiator.IN_THE_DOORWAY` clears a spawn by the **player's**
radius and never by the enemy's, and listed bulwark, scuttler and
artillery as the widened roles whose near edge lands inside the door.
I ran the arithmetic against the real constants. The note is right about
the mechanism and understates the defect in one way that changes what it
means.

`DOOR_WIDTH` 2.4, half 1.2; `PLAYER_RADIUS` 0.4; `IN_THE_DOORWAY` 1.6.
A body centred at 1.6 m from the door centre has its near edge at
`1.6 - lane_width/2`, which must clear 1.2:

| role | `lane_width` | near edge | clears 1.2 m? |
| --- | --- | --- | --- |
| melee | 0.80 | 1.200 | yes, exactly |
| ranged | 0.70 | 1.250 | yes |
| beacon | 0.62 | 1.290 | yes |
| diver | 1.20 | 1.000 | **no** |
| artillery | 1.25 | 0.975 | **no** |
| scuttler | 1.30 | 0.950 | **no** |
| drifter | 1.35 | 0.925 | **no** |
| bulwark | 1.45 | 0.875 | **no** |
| **brute** | **1.80** | **0.700** | **no — worst** |
| charger | 1.90 | 0.650 | **no** |

**`brute` is the worst case and it is not new.** It was one of the three
approved roles long before the composition widening, at 1.8 m wide
against a 1.2 m half-width — 0.5 m inside the door. So this is a
**latent defect the widening made more common, not a regression the
widening introduced**: the widening added seven more roles that fail it
and changed which rooms get them, which is why it surfaced now.

**`melee` clears at exactly 1.200 for a reason that is the bug.**
`IN_THE_DOORWAY = DOOR_WIDTH / 2 + PLAYER_RADIUS` was derived for a body
with the player's radius. `melee`'s lane width is 0.8, so its half-width
is 0.4 — the player's radius exactly. The constant is correct for one
body and coincidentally correct for one enemy.

**The bridge already exports what the fix needs.** `ENEMY_ENVELOPES`
carries `lane_width` per role in `constants.gd`, so the clearance the
engine wants is `DOOR_WIDTH / 2 + lane_width / 2` for the body being
nudged, not a second constant and not a second export. Adding a
per-role clearance number here would be two spellings of one fact.

**Whose:** `content_instantiator.gd` is Prod's, so the nudge is Prod's
one-line change. What is handed over is the arithmetic, the corrected
severity, and the fact that a fix scoped to "the widened roles" would
leave `brute` — an approved role in the base kit — still protruding.

**Not observed in play.** Nothing in the current `godot-reload` failure
traces to it; Prod's blocked-walk reporter says "no enemy within 4 m"
and points at a turning connector instead. This stays a recorded finding
with the arithmetic that would prove it, not a diagnosis of that red.
