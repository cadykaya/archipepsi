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
| **P04** restart persistence | `.1 .3 .4 .6` bridge half done; `.2 .5` are engine |
| **P16** transported objects | declaration, save, intent, authority, recovery — `.2` (moving it) is Prod's |
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
