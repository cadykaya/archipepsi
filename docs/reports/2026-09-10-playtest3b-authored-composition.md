# PROD — Playable 0.3, Stage 3B: real authored composition

**Archipepsi Production lane · 2026-09-10**

Head before: `2f727a7`. Frozen authority: `docs/ROAD_TO_PLAYABLE_0_3.md`.

> **Superseded in part, 2026-09-11.** §10's "blocked on Art" no longer
> holds: the owner ruled that a chamber adopts its shell's geometry, so
> the existing twelve shells compose arenas as they are. See
> `docs/reports/2026-09-11-3ab-integration.md` §8. The rest of this
> report stands as the record of what 3B measured.

Approved authored room shells now reach a played Zone through ordinary
generation: the offline generator selects them from the request's own
catalog, the shared validator judges them, they survive storage, and the
runtime builds them and says so. Zone 1 of the reproducible campaign
composes **6 of its 23 chambers from authored shells**, and every one of
those six builds the authored scene rather than falling back.

The production Epsilon prompt now states the catalog, the four
compatibility clauses, and what to do when nothing fits — it had carried
`room_shells` since Wave 1 and never mentioned it, so the one provider that
could have made a creative choice was never told there was one to make.

The `--playtest3a` showcase is unchanged and remains a regression fixture.
Nothing in this report rests on it.

---

## 1. What was actually wrong

Stage 3A established that no authored room had ever appeared in a played
Zone. 3B found four distinct reasons, each of which had to be fixed before
the next became visible.

**1. The generator never named a shell.** `shell_id` had been on the
chamber schema since D1 and nothing wrote one. `fallback.py` now selects
one per chamber.

**2. The generator's self-check was held to different rules than its
caller.** `_rule_errors` called `validate_zone` without `legal_shell_ids`,
so the fallback rejected its own valid choices as "not offered" and
retried through eight salts. The measured cost was a played Zone that went
from 35 enemies to 29 and from 922 points to 927 while nothing about its
content had been asked to change. Fixed, and generalised: `shells.offer_of`
is now the single definition of "the shell arguments a request carries",
spread by the acceptance path, the self-check, the preflight guard, the
archive replayer, the baseline fixture and every test helper.

**3. Selection read the registry, not the offer.** The first draft of the
selector called `load_registry()` directly. Production could not show the
bug — the live request is built from that same registry — but a request
offering nothing got shells named anyway, and 68 tests said so.
`shells.offered_for` reads the catalog the request carries.

**4. Selection ran before the geometry was final.** `_add_features`
*widens* a corridor before hanging an affordance on it, and selection ran
first, so shells were judged against a width the room was about to stop
having. Five of the played Zone's eight corridors were refused a corner
shell they then fitted. Selection now runs last.

## 2. One rule, in both languages

`shells.rule_errors(shell_id, rule, chamber)` is the only Python copy of
"does this shell fit this room", and `ContentInstantiator._misfit` is its
GDScript mirror. Four clauses, all from the registry:

| clause | asks |
|---|---|
| `semantic_tags` | is the shell the KIND of room this chamber is? |
| `size` | does the shell's envelope match the chamber's footprint? |
| `provides_elevation` | does it have the band the chamber declares? |
| `fits_floors` | does it have the floor count a tower asks for? |

Godot previously checked `fits_floors` **alone**, so a shell tagged
`treasure_room` named for an `arena` was refused by Python and built by
Godot. `test_godot_judges_a_shell_on_every_field_python_does` fails if a
clause is added to one side and forgotten on the other.

An absent or empty declaration constrains nothing, identically in both —
the same early return `fits_floors` always took. What stops an untagged
shell being selected is the offer, checked one clause earlier against the
request's catalog.

## 3. What the size clause is for, and what it cost

Measured: **no approved arena shell fits any arena the generator asks
for.** The generator's arenas are 12–26 m across; `shell_hall_transit`,
`shell_span_basin` and `shell_yard_gantry` are 31–85 m. Naming one for the
other does not compose a room — it substitutes a space five times the
size, and the Zone's budget, enemy counts, connector rhythm and layout
were all computed from numbers the room then ignores.

The consequences were physical and measured, not theoretical:

* Twelve declared surfaces of the Hall produced **zero** usable placement
  points, the composer fell back to a flat solve, and **22 activity
  elements** were placed at the corners of the bounding box where there is
  no floor.
* Rooms landed inside each other. `c021`'s Check stood inside
  `Chamber_c015`; later `c020`'s stood inside `Chamber_c023`.

So a shell may not exceed the chamber's declared footprint (interior plus
one wall each side) — and, once a chamber carries features, may not be
*smaller* than it either: the fallback widened that room to hold them, and
a 6.8 m corner shell in a corridor widened to 7.9 × 14.4 is under half the
floor the features were placed against. The measured result of the missing
half of that rule was a Zone that offered two affordances and **built
neither** — content dropped without a word.

That is why 6 rooms are authored and not 8: the two corridors carrying
affordances keep the procedural builder, and keep their affordances.

## 4. Three defects this uncovered in code 3B did not touch

**The whole room was one solid.** `all_solid_boxes`'s `everything` flag
meant "also read collision hulls" and *also* switched off the
`ROOM_SCALE_SOLID` architecture filter — two unrelated things behind one
flag. An authored shell is one merged mesh for the whole room, so its
single AABB is the room, and every interior spot read as "inside
geometry". The filter now applies on both paths; hulls are still read
unfiltered, because a deck over a walkway is decisive for clearance.

**The builder knew where the Check goes and the composer did not.**
`reward_clearance` had always been honoured — by the crate placer, in a
local array that never left the builder. `_room_occupancy` now publishes
it. Same shape as four previous defects in this project; the fix is to
publish the one derivation rather than make a second.

**Turns compounded.** A room that bends the route and then a random corner
piece bending it again sent the next room straight back into the arm it
had just left. Invisible while `exit_yaw` was zero on every procedural
builder — the second turn never had a first one to compound. The corner
roll is now skipped exactly once after a room that turned.

The zone builder's six-connector clearance retry is unchanged: pushing
further just marches a corridor *through* the rooms in the way, since a
connector is never itself overlap-checked. What changed is that giving up
is now `push_error` instead of silence.

## 5. Diagnostics: every refusal names itself

`ContentInstantiator` stamps `shell_resolution` on every room —
`{requested, resolved, build, reason}` — with a closed reason vocabulary:
`unknown_shell_id`, `malformed_shell_id`, `incompatible_shell`,
`unresolvable_chain`, `pending_art_review`, `no_authored_shell_for_type`.
None is ever normalised into a valid choice: a refused selection resolves
to nothing.

`build` is the field that settles "was this authored", not the presence of
a requested id. The census read `chamber["shell_id"]` — the *input* — so a
chamber whose shell was refused still reported that shell's name and every
consumer counted a procedural room as authored. `zone_controller` now
reads the stamp.

"Not offered" is deliberately **absent** from the runtime vocabulary. The
offer is the request's catalog, which lives Python-side and never crosses
to the runtime; `validate_zone` refuses an unoffered id before a Zone is
ever stored. A runtime offer check would be a second opinion about a fact
this process does not have.

## 6. Evidence

Three tests were replaced because they asserted **source text**, which
passes on a call site that spells an argument out and fails on one that
spreads it, and says nothing about a call site that passes the wrong
value:

* `test_the_acceptance_path_enforces_what_the_request_offered` now RUNS
  the pipeline. Its payload is the fallback's own output for the request
  with one `shell_id` overwritten, so the shell is the only thing wrong
  with it — a first draft used a hand-written Zone that was *also* under
  budget and *also* missing a reward chamber, and it was refused with the
  shell rule deleted. A refusal that would have happened anyway is not
  evidence. A control run, identical but for that field, must be accepted.
* `test_the_instantiator_reads_what_epsilon_chose` no longer greps a
  variable name.
* `test_godot_judges_a_shell_on_every_field_python_does` is new (§2).

New Godot evidence, all sabotage-verified:

| test | claim |
|---|---|
| `_a_normally_generated_zone_builds_authored_rooms` | every chamber of the *generated* Zone naming a shell builds that exact shell |
| `_every_refusal_says_which_one_it_was` | six outcomes, each with its own reason, none normalised |
| `_a_fallback_room_never_reports_itself_authored` | a refused room carries no `authored_shell` stamp |
| `_test_an_ordinary_generated_zone_honours_the_package` | `--movement-package` reaches a normal Zone in all three modes |

Sabotages run and confirmed red: deleting the footprint clause (5
failures), collapsing the reason vocabulary to one value (1 failure),
removing the offer from the acceptance path (1 failure). Restoring each
returns green.

The zone audit was also made specific rather than generic: "stands inside
the room's own geometry" now names the collider, its class, and the room
that owns it — which is how `Chamber_c015` was identified as the body
holding `c021`'s Check.

## 7. Movement package on ordinary Zones

`--movement-package=none|rail|launch` no longer requires `--playtest3a`.
It is read once at boot and applied to every Zone the run enters. A
refused value is reported and never applied — it does not quietly become
`none` — and the showcase additionally does not open.

Measured on the generated Zone, all three modes: **23 rooms judged before
the first build, 0 declared, 0 selected, 0 built, 0 refused.** The
approved shells this Zone composes with declare no movement offers, so the
honest claim is that the offer stage ran and found nothing. A test
asserting rails appeared would be asserting content the art lane has not
shipped.

## 8. Baselines and digests

The pre-3B baseline is preserved verbatim as
`docs/baselines/playtest_2_5.pre_3b.json`. Nothing was overwritten
silently.

| | pre-3B | 3B |
|---|---|---|
| baseline sha256 (16) | `5a7cfdc03da0e59b` | `c1131ac29931cc68` |
| played-zone digest | `6e8d83d0f3ec088b` | `ab57d275eea29018` |
| chambers naming a shell | 0 of 23 | 6 of 23 |

**The digests moved and the content did not.** Machine-checked on all
three baseline Zones: with `shell_id` removed, the new and preserved Zones
are byte-identical, and every recorded measurement matches — 23 rooms, 15
Checks, and 922 / 912 / 913 value with 35 / 26 / 32 enemies. The digest
moves solely because chambers now name the shells they build.

Missing ids have documented handling, and the three cases are distinct:

* **Legacy saved Zones** are not regenerated on load or reconnect. A saved
  Zone naming a shell the registry no longer carries is a downgrade, not a
  corruption: `unknown_shell_id`, and the procedural route still plays.
* **No compatible shell** — every `platform_path`, and every `arena` until
  the art lane ships one at generator scale — is `no_authored_shell_for_type`
  and is the designed outcome.
* **A generation gap** — a chamber that had a compatible offer and took
  none — is what §1 closed. There are none left in the played Zone: all 6
  eligible chambers name a shell.

## 9. Acceptance status

| | status |
|---|---|
| A1 authored rooms in a normally generated Zone | **met** — 6 of 23, both corner variants |
| A2 selection from the offered catalog, validated | **met** — `shells.offered_for`, `validate_zone` |
| A3 one compatibility rule, no contradictory copies | **met** — §2, parity test |
| A4 required content present and reachable | **met** — every required Check, objective and activity still present; zone audit green. *Corrected 2026-09-11: this row originally read "content byte-identical" and offered that as evidence of correctness. It is not. Byte-identical content inside a room that grew to 2712 m² is the defect the Zone 1 playtest found — see `2026-09-11-playtest-zone1-findings.md` §S-7.* |
| A5 explicit diagnostics, no silent normalisation | **met** — §5 |
| A6 old saved Zones preserved | **met** — not regenerated on load or reconnect |
| A7 movement package on ordinary Zones | **met** — §7 |
| A8 evidence preserved, differences explained | **met** — §8 |

## 10. What is blocked, and on whom

**No approved shell can build an arena.** All three arena shells are 2–5×
the size of any arena the generator produces (§3), and five arenas of the
played Zone additionally declare an elevation band no shell provides. Two
things would unblock it, and both are Art-lane decisions, not engineering:

1. **Arena shells at generator scale** — roughly 12–26 m on both floor
   axes.
2. **A shell that declares `provides_elevation`.** The field exists and is
   empty on every approved shell, so a chamber with a band takes the
   procedural builder. A shell declaring `("gallery",)` becomes eligible
   with no code change.

Until then the honest number is 6 of 23, and it is corridors.

**Not attempted, deliberately:** having the generator adopt a selected
shell's fixed dimensions as the chamber's dimensions. That would let
shells of any size be used and is probably the right long-term design, but
it changes every downstream number — budget, enemy counts, pacing — and is
a design decision for the owner rather than something to land inside 3B.

## 11. Gates

* `make test` — **1142 passed**, 627 subtests, 0 failed.
* Full Godot frontier, swept by **exit code**: 18 suites, all 0.
* `docs/design-packet-v0.8/check_packet.py` — passes; the packet's schema
  copies were reconciled to the bridge for `zone.py` and `content.py`.
