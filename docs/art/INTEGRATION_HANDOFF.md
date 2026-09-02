# Post-art Zone 1 — the art side, and what Production must wire

**This is integration preparation for the existing A/B, not a new art batch.**
No asset here is new, redesigned or unapproved, and nothing in it starts
Batch 038.

**The A/B is not closed by this document.** It produces the art half of the
post-art side. The owner plays it and closes the freeze.

---

## A. Art branch head

`claude/archipepsi-art` — the audit ran against **`40ed7c9`** ("art: record
the owner verdicts — the post-030 pass is fully PASSED"). The work below is
committed on top of it.

## B. Gameplay branch head, read-only

`claude/archipepsi-echoes-continuation-b1adno` — **`eda4fd9`** ("The eight
shells are in the catalog, and the audit says they are not there") as of the
P2-C collision pass. The section below was written against **`9ac6aad`**
("Batch 1: no active unclaimed location may be orphaned by lifecycle state")
and its statements about that head still hold.

**It has moved since the art lane last audited it** (`b1adno`'s head was
`7565485` at the previous audit). Nothing on that branch was modified, and no
file from it is committed here. The one verifier that reads it fetches it at
run time into a throwaway harness and deletes it afterwards.

## C. The baseline being replayed

From `docs/PLAYTEST_BASELINE.md` on the gameplay branch. **Two artifacts, and
they are not the same Zone** — the document is emphatic about this, and it is
the easiest thing in the whole exercise to get wrong.

| | |
|---|---|
| **The played Zone** | the **mock campaign's Zone 1** at `--mock-scale=default`, from the **fallback** provider on the fixed mock seed |
| Its theme | **`neon_transit`**, because the mock seed's Zone 1 recipient game is *Bomb Rush Cyberfunk* and `Constants.THEME_BY_GAME_HINT` maps it there |
| As recorded | 23 rooms, 15 Checks, 41 enemies, 921 points |
| The launcher | `Playtest 2.5 (Windows).bat` → `--mock-scale=default`, records into `playtest-2.5\` |
| **The corpus** | `docs/baselines/playtest_2_5.json` — a **generator fingerprint** of three synthetic Zones. **Nobody plays it.** It exists to fail when the engine stops building the Zones it recorded |
| The proof of sameness | every playtime record carries a **level id**, sixteen characters of the Zone's own hash. Two records with the same id walked the same generated level |

**The post-art run must produce the same level id as the pre-art run.** That
is the acceptance test for "same Zone", and it is why section E's finding
matters as much as it does.

## D. Approved-art manifest — what this exposes

Exported by `tools/export_content_pack.sh` into `godot/content/`, which is a
**generated artifact**: regenerate it, never hand-edit it.

### Light housings — `fixture` (L2)

| content id | source asset | approval | tris |
|---|---|---|---|
| `fixture_light_concrete_facility` | `batch001/architecture/arch_light_fixture` | Batch 001 **PASS** | 144 |
| `fixture_light_rusted_industrial` | `batch014/lights/light_rusted_cage` | Batch 014 **PASS** | 240 |
| **`fixture_light_neon_transit`** | `batch014/lights/light_neon_channel` | Batch 014 **PASS** | 72 |
| `fixture_light_gothic_stone` | `batch014/lights/light_gothic_corona` | Batch 014 **PASS** | 256 |
| `fixture_light_temple_ruin` | `batch014/lights/light_temple_bowl` | Batch 014 **PASS** | 212 |
| `fixture_light_void_glitch` | `batch014/lights/light_void_absent` | Batch 014 **PASS** | 84 |

**Only `fixture_light_neon_transit` is on Zone 1's path.** The other five are
included because they are the same seam, the same approval and one manifest;
they change nothing in the played Zone.

Each is the **ceiling** fixture of its theme. The wall variants in Batch 014
are approved too and have no seam to arrive through.

### Projectile silhouettes — `projectile_visual` (L0)

| content id | source asset | approval | tris |
|---|---|---|---|
| `projectile_straight` | `batch008/enemy/enemy_projectile_straight` | Batch 008 **PASS** | 104 |
| `projectile_falling` | `batch008/enemy/enemy_projectile_falling` | Batch 008 **PASS** | 152 |
| `projectile_lobbed` | `batch008/enemy/enemy_projectile_lobbed` | Batch 008 **PASS** | 192 |

### The contract each one answers

| field | value | why |
|---|---|---|
| `scene` | `res://content/<kind>/<id>.tscn` | `content_registry.gd` refuses a scene outside `res://content/` and refuses one `ResourceLoader` cannot find |
| `procedural_fallback` | absent | it is one or the other; naming both is a hard refusal |
| `review` | `"pass"` | `VisualOwnership.is_shippable()` refuses `"pending"`. These are inside 001–022, which the owner passed |
| `fallback` (fixtures) | `fixture_light_<theme>_proc` | degrade to the procedural slab if the scene ever goes missing |
| `fallback` (projectiles) | **absent, deliberately** | no procedural registry entry exists for a projectile, and a fallback naming an id no pack defines is a hard registry failure. An unavailable scene resolves to `""`, which `_authored_projectile` already reads as "use the placeholder" |

## E. Art-side blockers — found, and fixed here

**E1. There was no `.glb` → `res://content/` step. FIXED.**
This was the real content of interface requirement 24. The registry demands a
loadable scene under `res://content/`; the art lane builds `.glb` into
`assets/models/`, which is outside `res://`, and the art branch carried **zero
`.tscn`** and no `godot/content/` at all. Now generated by
`tools/export_content_pack.sh`: the approved `.glb` is copied in, Godot
imports it, and **Godot writes the `.tscn`** rather than me hand-authoring a
file format.

**E2. The pack was verified against only ONE of two validators. FIXED, and
this one reached Production.**

This is a **dual-language contract** and the two halves do not police the same
things:

| validator | what it checks |
|---|---|
| `schemas/content.py` | a strict pydantic model — `extra="forbid"`, `MAX_TEXT_LEN` 160 |
| `content_registry.gd` | does the scene EXIST, does the fallback chain terminate |

The first pack passed the GDScript half, was declared ready, and Production's
Python gate rejected it on three counts:

1. the pack `description` was **231 characters** against a 160 limit;
2. every entry carried **`source_asset`**, which `ContentEntry` forbids;
3. every entry carried **`source_batch_review`**, likewise.

Prod stopped correctly. **Verifying one side of a two-sided contract is
verifying nothing**, and the handoff said "verified" on that basis.

Three things changed:

- **The exporter emits only schema fields.** `source_asset` and
  `source_batch_review` are gone from the manifest, and the description is
  133 characters.
- **The provenance moved rather than being dropped.** It lives in
  `godot/content/SCENE_PLAN.json`, which is not a manifest and is not under
  `res://content/registry/`, so the registry never reads it — alongside the
  approval table in section D above.
- **`_check()` in the exporter refuses to write a manifest Production would
  reject**, so the defect fails at export rather than at Prod's gate. It
  mirrors `ContentEntry`'s field set deliberately and is deliberately dumb;
  it is a fast guard, not the authority.

`tools/verify_content_pack.sh` now runs **both** validators in one command,
both of them Production's own files fetched read-only at run time, and it
simulates the other half of the handoff so the whole post-handoff state is
exercised:

```
[verify] --- Production's Python ContentManifest ---
[pyverify]   ok  authored_art.json        9 entries, description 133/160 chars
[pyverify]   ok  legacy_procedural.json   12 entries, description 107/160 chars
[pyverify]   ok  build_registry accepted 21 ids
[pyverify] PASS -- Production's ContentManifest accepts the pack
[verify] --- Production's GDScript ContentRegistry ---
[verify] load_all -> true
[verify]   ok  fixture_light_neon_transit    authored, 1 mesh, 0 lights, 0 colliders
     ... all nine entries ...
[verify]   ok  all five room shells still resolve to the procedural builder
[verify] PASS
```

**A second, quieter defect surfaced while fixing the first.** The GDScript
check had been passing because a stale `.godot` global class cache still held
a registration for a harness copy that no longer declared it; the next
`--import` rebuilt the cache and the script stopped compiling. It now
preloads Production's files **by path**, which does not depend on the cache
at all. A verifier that passes because of a cache is not a verifier.

Nothing from the gameplay branch is committed here; the harness is deleted on
exit.

**Not a blocker, recorded so nobody re-derives it:** the light housings carry
**no `Light3D`** and the projectiles carry **no collision object**, verified
by instantiating every scene. Those are the two things the instantiator
refuses outright, and they are refused because a housing shipping its own lamp
would change how bright a room is by being installed, and a projectile mesh
shipping collision would make the lobbed shot a different weapon from the
straight one.

## F. Integration handoff for Production

### F0. P2-C — the eight shells are now measurable (2026-09-01)

**Take `godot/content/` again.** Nothing else changed and no code change is
needed for any of it.

| | |
|---|---|
| what | the eight room-shell `.glb`s, their `.tscn` wrappers, and `registry/authored_art.json` |
| why | at `eda4fd9` all eight imported with zero colliders, so the audit's 625 findings were all "nothing is there" |
| now | 10–33 convex colliders each, `StaticBody3D` + `CollisionShape3D`, via `-convcolonly` |
| review state | **still `pending`, all eight.** Nothing here approves anything |
| gameplay risk | **none.** No generator logic, no constant, no script |

**SUPERSEDED by F0b below.** Both kinds of finding named here are now
repaired at the source; the table is kept because it is the measurement
the repair was made against.

**What the audit reported before the repair — measured here, so it was not
a surprise.** The two corners came back clean. The rest reported, and both
kinds of finding were about what the manifest CLAIMED rather than about the
approved geometry:

| shell | colliders | findings the probe measured |
| --- | ---: | --- |
| `shell_corner_left` | 10 | none |
| `shell_corner_right` | 10 | none |
| `shell_tower_gantry` | 33 | 2 headroom (`ground`, tightest 0.60 m) |
| `shell_tower_spiral` | 22 | 15 headroom (tightest 0.50 m) |
| `shell_tower_collapsed` | 21 | 27 headroom (tightest 0.50 m) |
| `shell_treasure_vault` | 12 | 9 on `step_low`, 1 headroom |
| `shell_treasure_cache` | 16 | 9 on `step_low`, 1 headroom |
| `shell_treasure_coffer` | 20 | 9 on `step_low`, 1 headroom |

**`step_low` (req 38).** All nine of its samples measure 0.80 where 0.40 is
declared. `_plinth`'s two steps are concentric — 3.0 m at 0.40, 2.2 m at
0.80 — so `step_low`'s remaining tread is a 0.40 m ring against a 0.80 m
player. Art's, and **reported rather than corrected**: the plinth is the
owner-approved F3 geometry and `reward_position` is yours.

**Headroom (req 39).** 47 in total, which is exactly the number the P2
preflight predicted and nothing could confirm while the rooms had no
collision. The cause is structural and it is a vocabulary problem, not a
modelling one: `STEP` is 1.00 m and `routecheck.assert_reachable` validated
the towers' whole climb at that spacing, so a foothold 1.00 m under the next
one is the design working. A P1 `Surface` asserts a player can STAND
somewhere, and `RoomAudit` therefore probes 2.40 m of clearance over every
one. A rung you pass through is a different thing, and there is no word for
it yet. Req 39 states three possible resolutions; Art picked none, because
two of them are yours and the third would silently drop 40-odd rungs from
what the towers say they offer.

**The three fields you applied by hand are now emitted.** `size_class`,
`exit_yaw` and `fits_floors` come out of the exporter with the same values
you set, which the drift check confirms field for field. `size_class` is
recorded as an **owner assignment** in `provenance.json`, not as something
derived from metres, so nobody later "corrects" it against `size`.

**The corners are tagged `corridor` now**, with `corner` kept beside it as a
shape tag — the change you asked for at `eda4fd9`. It is the one field on a
shared id that Art deliberately moved, and it is named in
`verify_manifest.DECLARED_HANDOFF` so the drift check reports it as an
intended handoff instead of failing.

**Nothing about the rooms' appearance changed.**
`tools/content/diff_shell_glb.py` compares accessor payloads byte for byte
across the rebuild — same vertices, normals, UVs, indices, materials, PNGs
in all eight.

### F0b. P2-D — the seven findings that survived C(ii) are repaired

**Take `godot/content/` again.** No code change, and all eight are still
`review: "pending"`.

Your ruling at `1648fa9` took the eight shells from 75 findings to 7. All
seven were ours and all seven are fixed at the source.

| finding | what it was | what changed |
| --- | --- | --- |
| collapsed `rubble_1_0`, `rubble_1_1` | 1.50 m and 0.50 m under the deck | the deck no longer roofs the climb |
| spiral `platform_6` | 1.50 m under the deck | same, same helper |
| treasure `step_low` (x3) | a 0.40 m ring against a 0.80 m player | no longer declared a stand Surface |
| collapsed socket `high_3` | 0.05 m inside the stone above it | sockets are placed where something fits |

**The deck was the defect, not the climbs.** A 0.50 m slab at `rise`
across the back 4 m sat over the last rungs of two different climbs.
Neither climb could move -- the spiral's `inset`/`margin`/`spacing` are
`tower()`'s own so an authored spiral climbs where a procedural one does,
and the collapsed tower's alternating half-floors were already the answer
to a `routecheck` refusal. `_deck_well` cuts the deck out of the column
the climb comes up, derived from the same `stones` and `heights` that
become the Surfaces. Collapsed's deck is now 7.4 x 4.0 and spiral's
8.6 x 4.0; **gantry's is unchanged**, because nothing of its climb is
under it. `routecheck` re-run: worst jumps 0.80 / 1.75 / 0.10 m against
2.00 allowed.

**The plinths are untouched.** Mesh and collision both, and the three
treasure `.glb` files are byte-identical to the previous head. The 0.40 m
riser is legitimate architecture inside `MAX_VERTICAL_STEP` and it still
collides; only the claim that a player can stand on it is gone. The mass
stays declared as the `plinth` `no_build` volume.

**One socket you did not flag also moved.** Spiral's `high_3` sat 0.05 m
clear of the platform above it -- inside your `_buried` box, so it passed,
but that is not a margin. The same derivation that fixed collapsed's
`high_3` moved it 0.225 m. Both moves increase clearance; no socket whose
centre was already clear moved at all.

**Expect a clean audit.** `verify_collision.gd` now asks your own C(ii)
question -- `Placement`'s 9 x 9 grid, the 0.8 m footprint inside the rect,
2.4 m of clearance -- against the shipped `.tscn` files, and reports
**eight shells, zero needing attention**, tightest surface still offering
32 per cent of its spots. That is a prediction of your audit, not a
substitute for it.

**Thirteen fields disagree with your landed pack on purpose.** Each is
named in `verify_manifest.DECLARED_HANDOFF` with its reason; anything not
on that list still fails the drift check.

### F1. Drop in the content pack — **no code change**

| | |
|---|---|
| what | copy `godot/content/` from this branch |
| classification | **INTEGRATION-HANDOFF** |
| gameplay risk | **none.** No generator logic, no constant, no script |

`content_registry.gd`'s own docstring is the warrant: *"the manifests under
`res://content/registry/` are authored beside the scenes they describe, so
adding an asset is a scene plus a manifest entry and never a change to
generator logic."*

**The three projectile ids are free** — `projectile_straight` / `_falling` /
`_lobbed` are defined by no pack today, and `ProjectileSilhouette.content_id()`
already asks for exactly those names. So the projectile half needs **nothing
else at all**: drop the pack in and authored silhouettes are live.

### F2. Free the six fixture ids — **one manifest, six strings**

| | |
|---|---|
| file | `godot/content/registry/legacy_procedural.json` |
| change | rename the six `fixture_light_<theme>` entry ids to `fixture_light_<theme>_proc`. **Nothing else in those entries changes** |
| classification | **INTEGRATION-HANDOFF** |
| gameplay risk | **none.** These entries are reached only through `ContentInstantiator.light_housing()`, which returns a decorative housing or `null` |

Required because `_accept` refuses a duplicate id — *"ids are the contract and
must be unique across every pack"* — and `light_housing()` asks for the
canonical `fixture_light_%s % theme`. After the rename, `resolve()` returns
the authored entry when its scene loads and the renamed procedural one when it
does not, which is the exact fallback pattern the instantiator's own docstring
describes.

> **F1 and F2 are ONE ATOMIC CHANGE.** Landing either half alone fails the
> registry at load: the pack alone collides on six ids, and the pack's
> `fallback` fields alone name ids no pack defines. The failure is loud and at
> load rather than silent, which is the right failure mode — but it is a
> failure, so land them together.

### F3. Room shells — **DO NOT WIRE. Owner decision required.**

| | |
|---|---|
| classification | **GAMEPLAY/RUNTIME** |
| status | **stopped, per the brief. Not attempted, not worked around** |

Nineteen approved authored shells exist (Batches 015–019, all inside 001–022
**PASS**). They are deliberately **not** exported, because exposing them
through `SHELL_FOR_TYPE` would change the Zone.

`ContentInstantiator._from_authored_scene()` takes `size` from the **registry
entry** — one fixed value per entry — and derives from it:

- `exit_offset` → **where the next room is chained**
- `bounds` → the overlap test that lays the Zone out
- `reward_position` → where the objective/Check sits
- `enemy_spawns` → where 41 enemies stand
- `room_height`, and the extents `AffordanceFeatures.place_all()` places into

`ChamberBuilders.corridor()` instead reads `chamber["length"]` and
`chamber["width"]` — **the generator's per-chamber values** — and computes
height as `maxf(CORRIDOR_HEIGHT, AffordanceFeatures.required_height(chamber))`,
deliberately raising a corridor that carries a grapple or bounce feature.

So an authored shell **replaces per-chamber generator dimensions with one
fixed size for every room of that type**. The measured mismatch is not
marginal:

| | procedural | authored (Batch 015) |
|---|---|---|
| corridor length | per chamber, 6–30 m | fixed 14.0–20.0 m |
| corridor height | 3.6 m, raised for features | fixed 4.5–5.9 m |
| corridor width | per chamber, 4–10 m | fixed 4.8–9.6 m |

That moves room chaining, room bounds, Check positions and enemy positions —
**a different Zone with a different level id**, which is exactly the
contamination the freeze exists to prevent. A fixed ceiling could also put an
affordance reward above a solid slab, which is a real playability regression
and the bug the variable height was written to fix.

**What would be needed** (owner's call, not Art's, and not part of this
handoff): either authored shells that declare per-chamber variable geometry,
or a generator that asks an authored shell what sizes it can be. Both are
gameplay/runtime design. Interface requirement 24 already carries the shell
half; this is the specific reason it cannot be closed by the art lane alone.

### F4. Everything else approved has no runtime seam at all

Recorded so it is not mistaken for an art gap. There are exactly **three**
authored-content seams wired into the runtime today:

| seam | caller | status |
|---|---|---|
| room shells | `zone_builder.gd:90` | **F3 — blocked** |
| light housings | `chamber_builders.gd:121` | **exposed by F1+F2** |
| projectile visuals | `echo_projectile.gd:66` | **exposed by F1** |

No seam exists for enemy bodies, Checks, portals, interactables, keys, gates,
secrets, pickups or props. Those approved batches cannot appear in any Zone
regardless of what the art lane does, and that is engineering truth rather
than an art defect.

## G. A/B invariants — what stays identical

Unchanged by F1 and F2, and each one is unchanged *by construction* rather
than by inspection:

- the Zone 1 generation request, seed, provider and `--mock-scale=default`
- **the level id** — no dimension, socket, volume or offset is authored
- room graph, topology, room count, room order, room sizes
- Check count, Check allocation and Check placement
- encounter counts, enemy archetypes, enemy stats, enemy behaviour, spawn positions
- **every collider and hitbox** — no authored scene carries a collision object, and the instantiator refuses one that does
- **all illumination** — `OmniLight3D` colour, energy, range and position are engine-built in both runs; a housing carrying a `Light3D` is refused
- projectile flight, damage, speed and its one 0.25 m sphere hitbox
- traversal numbers, affordance feature placement, `required_height`
- timings, damage, movement, AP logic, save logic, rewards, content scoring
- every generator decision

**The only difference a player can experience is what the light fixture and
the projectiles look like.**

## H. Readiness verdict

> **READY FOR PROD INTEGRATION — at the two seams that cannot move gameplay.**
> **OWNER BLOCKER — for room shells, which are the majority of the visual
> change and cannot be exposed without altering Zone topology.**

Both halves are true and the second is the more important one. Production can
land F1+F2 today and get a genuinely post-art Zone 1 whose level id matches
the baseline. It will be a *narrow* post-art Zone: the fixtures and the
projectiles, not the walls.

If the owner wants the walls in the comparison, that is the F3 decision, and
it is a gameplay/runtime design question rather than an art one.

## Evidence

`docs/art/review/integration/A_content_pack_delta.png` — row A is what
Playtest 2.5 walked: one hardcoded 0.8 × 0.1 × 0.4 box in six tints. Row B is
the approved housing per theme. Row C is the three projectile silhouettes.
**The lamp is identical in both rows and engine-built in both** — same colour,
same energy, same position. Only the housing changes.

## Rebuild and re-verify

```
tools/export_content_pack.sh     # regenerate godot/content/ from approved art
tools/verify_content_pack.sh     # check it with BOTH of Production's validators
                                 #   - schemas/content.py     (pydantic, strict)
                                 #   - content_registry.gd    (scenes, fallbacks)
```
