# ART FRONTIER — where the art lane is, right now

**Read this first on every heartbeat.** It is the cheap wake-up state for
the Archipepsi art lane. Everything else in `docs/art/` is reference; this
file is the only one that says what to *do next*.

---

## THE GATE

> ## STYLE LOCK IS PASSED. PRODUCTION IS UNLOCKED.

The owner's Batch 002-R verdict passed the revised Epsilon installation and
locked the whole visual language. `ART_REVIEW.md` opens with the locked DNA;
`ART_BIBLE.md` §1z carries the same text as a build rule. **Neither is
reopened by this lane.**

### What is now allowed

- Produce assets in coherent **batches**, in the priority order below.
- Re-skin approved geometry into approved themes.
- Extend an approved module family with more instances of the same kind.
- Build the six theme kits, room shells, and the enemy production family.

### What still needs a review sheet

| Needs review | Can move faster |
| --- | --- |
| Major hero assets | Routine variations that clearly inherit locked DNA |
| New enemy families or roles | More instances of an approved module family |
| New theme landmarks | Re-skins of approved geometry into an approved theme |
| **Anything establishing new visual DNA** | Fixes to something already approved |

### What is still forbidden, and always was

- Declaring a visual concept approved. `PASS` is still the owner's word
  alone, and Style Lock passing did not delegate it.
- Deleting a rejected or superseded alternative.
- Symmetrizing or tidying the Epsilon intrusion.
- Redesigning the locked installation, unless an **integration problem**
  proves it necessary — and then the conflict is surfaced, not resolved
  quietly.
- Changing gameplay truth or an engineering contract to make an asset
  convenient. Surface the conflict and work elsewhere.
- Inventing a subjective owner decision. If a genuinely new style question
  appears: **state it, and continue on something else.**

### The production order

Assets that let the game replace its procedural / debug-looking presentation
with the approved authored vocabulary come first.

| # | Tier | State |
| --- | --- | --- |
| 1 | Hub / permanent spaces, and the Epsilon installation | **done** — installation locked, Batch 003 `PASS` (the Hub's eight fixtures and modules), Batch 004 `PASS` (the Lab's seven). Epsilon has its reserved bay (req 4 resolved). Shells themselves remain `hub.gd` / `echo_lab.gd` geometry |
| 2 | Core interactables | **done** — Batch 005/005-R the Check in four states, 006 the portal and `door_standard`, 022 the navigation language (`PASS` 2026-08-29: `nav_blade`, `nav_panel`, `nav_chevron`, `nav_hanger`, in all six themes). `objective_marker` was **struck** — no current objective type needs a world marker |
| 3 | Common architecture | **done** — Batches 001 and 007 the Pri-A modules, 020 the structural Pri-B seven (`PASS`), 021 the services and openings (`PASS`, `arch_duct` cleared by the 021-R evidence). **Three rows were struck rather than built**, each because nothing places it: `arch_affordance_socket` (req 22 — each affordance owns its own mounting language), `arch_objective_socket` and `arch_signage_mount` (2026-08-29 — the approved navigation family owns its own mounting, and a generic mount would recreate the rejected universal socket). `arch_vista_socket` remains blocked with no contract at all. |

| 4 | The enemy production family | **UNBLOCKED 2026-08-29, and the old wording here was stale.** ~~Seven of the ten roles wait on colliders (req 7) and the telegraph on a node that does not exist (req 14).~~ Both are RESOLVED in current Production: `Constants.ENEMY_ENVELOPES` publishes an agreed envelope for all ten roles, and `enemy.gd` carries `telegraph_started` / `telegraph_finished` / `telegraph_progress()` plus a `telegraph_origin` Marker3D at the collider centre. Batch 030 built all ten to those exact numbers and asserts the fit. What remains is req 31: `ENEMY_ARCHETYPES` is still `("melee", "ranged", "brute")`, so seven have a body and no way to be spawned |
| 5 | Movement affordances | **done** — Batch 009 built the six remaining fixtures, all in the `signal` family the approved anchors wear |
| 6 | Universal props | **done as far as it can go** — **corrected** — §8's 22-prop library is placed by nothing. Batch 010 built the three the generator actually places whose theme family exists; three more wait on their theme kits |
| 7 | Room-shell vocabulary | **done and `PASS`** — 19 shells across all six families (015–019), approved 2026-08-28 as legal authored vocabulary for Epsilon / Godot integration. Expansion is allowed but **not by count**: a new variant must create a meaningfully different route, combat problem, vertical relationship, sightline, traversal problem, Check-placement opportunity or optional-space opportunity |
| 8 | The six theme kits | **6 of 6 material families, dressing (013 `PASS`), a light fixture family per theme (014 `PASS`), and `trim_plain` added 2026-08-29 (theme trim without hazard semantics)**. Landmarks proposed as Batch 023 and **PENDING** |
| 9 | Presentation / polish | **started** — Batch 024 proposes the Epsilon presentation states (six) and the presentation arc (three stages), **PENDING**. One of the six has a runtime signal today (req 25) |

**Tooling:** `tools/shoot.sh` runs a JSON shot list through
`camera_rig.gd` — lenses in millimetres, `frame` solving its own distance,
grey / silhouette / clay / guides variants, several models per scene with
`@x,y,z` offsets and a `#yaw`, a `backdrop` of `full` / `floor` / `none`
so a composed scene is not sliced by the bench's own wall, a `key_energy`
so an open-topped room shell is not blown out by a rig meant for an object
on a backdrop, and
`hub + model:<...>` to stand an asset in the real room. Prefer it over writing a new
bench script; the six that exist are each a camera nobody could afford to
move. `docs/art/proposals/photo_mode.gd` is the in-game half, delivered as
a proposal because it belongs in `godot/`.

**Heartbeats now do production work** in this order, one coherent batch at a
time, and stop for review only where the table above says a review sheet is
needed.

**The heartbeat is paused while the queue is empty** (owner's rule, 2026-08-29).
A heartbeat that would be a no-op is not a cheap no-op -- it is a paid wake-up
that reads four documents to conclude nothing. So when the last unblocked task
is delivered and everything remaining is waiting on the owner, DISABLE the
hourly routine rather than letting it fire into a hold, and say so in the
report. Resume it the moment a task exists: an owner verdict that releases a
batch, a contract that lands, an unblocked tier. Nothing is lost by pausing --
PR events still wake the interactive session directly (see below), and this
file is the state a resumed heartbeat reads.

A heartbeat that is running and finds nothing productive still says so in one
line rather than inventing work, and then pauses itself.

### Traversal: do NOT encode "mandatory means base-kit only" (owner, 2026-08-29)

The old assumption that every mandatory route must remain solvable with the
base kit is **being redesigned by Production and must not be propagated as
art truth.** Archipepsi now intentionally wants genuine Archipelago
progression gates: a player may meet a GRAPPLE REQUIRED route, leave, receive
the progression item later, and come back.

Art does not decide those rules and must not invent them. What art does is
narrower and unchanged in spirit: **provide the spatial opportunity and leave
the mechanic unspecified.** A ledge that a capability could reach is a shape;
whether reaching it is mandatory, optional, or gated is Production's call.

Note that `CLAUDE.md` still lists "Preserve base-kit solvability" as a
load-bearing boundary. That line is Production's to update, not the art
lane's; this note records the owner's correction so no art batch re-encodes
the superseded rule in the meantime.

---

## Status

| | |
| --- | --- |
| Branch | `claude/archipepsi-art`, based on `claude/archipepsi-build-inzshp` |
| Phase | **LARGE ROOM LIBRARY — WAVE 1 DELIVERED, PENDING.** The ten-room slate (`docs/art/LARGE_ROOM_SLATE.md`) is approved and reconciled to Production's final `TraversalLaw` at `b37fe07`. **Wave 1 is three shells** — `shell_plenum_helix` (20 x 72 x 20, a shaft), `shell_yard_gantry` (84 x 16 x 52, a field) and `shell_span_basin` (30 x 22 x 90, a span) — deliberately not three of the same room; package in `docs/art/review/wave1/`. **Wave 2 has NOT started.** `shell_hall_transit` (40 x 38 x 60 m, ~91,000 m3) was authored to `af620d8`, repaired at `3b7bb02` against the `301374d` audit and had its scene regenerated at `058ec8b` against the `94d562d` audit; its P3 package in `docs/art/review/p3_owner/` is the PRE-REPAIR record and is annotated as such. **P2 IS COMPLETE — all eight shells PASS.** **STYLE LOCK PASSED — production.** 001–022 are all `PASS`. **Batch 023 (theme landmarks) is PENDING owner review** and is a PROPOSAL, not production — a landmark CATEGORY exists in Production, but no placement, selection or envelope contract does (req 24, reworded 2026-08-29). **Batches 024–030 are authorised and proceed without waiting on the 023 verdict.** **024-030 delivered and PENDING.** **The post-030 gap pass is fully REVIEWED and fully PASSED (owner, 2026-08-29): 031 PASS; 032 PASS WITH BOUNDARY; 033 PASS AUDIT / BUILD NOTHING; 034 PASS VISUAL PRINCIPLE; 035-R PASS; 036-R PASS; 037-R PASS WITH DOCUMENTED CAVEAT; boss audit ACCEPTED / BUILD NOTHING.** **The art lane is now intentionally IDLE.** No Batch 038, and no Echo visual parts and no diegetic interface work until the owner publishes the two design briefs named below. |
| Owner review | Style Lock passed 2026-08-28. Draft PR [#5](https://github.com/cadykaya/archipepsi/pull/5). |
| Next action | **NOTHING. Wait for two verdicts.** (1) The owner's form verdict on **Wave 1** — `shell_plenum_helix`, `shell_yard_gantry`, `shell_span_basin`; review package in `docs/art/review/wave1/`. All three export `review: "pending"` and Art does not promote them. **Do not start Wave 2** — the owner deferred it explicitly pending that verdict. (2) Production's recertification of `shell_hall_transit` at `058ec8b`, which regenerated the scene the audit at `94d562d` found stale. Everything else the lane could reach for is still closed: no Batch 038, no Echo visual parts, no diegetic interface work until the owner publishes those two briefs. Batches 023-030 remain PENDING review. Req 31 still blocks seven enemy roles and Art has deliberately not routed around it. **Do not invent filler work. No heartbeat, no polling, no autonomous expansion.** |
| ~~Superseded~~ | ~~**Tier 7: the room shells** (`ASSET_INVENTORY.md` §7, L3, nothing built) — started immediately, per the owner's instruction not to idle while 014 waits. Six families, all Pri A: corridor, arena, platform-path, tower, treasure room, corner. They inherit engine-truth dimensions and traversal bounds, differ in scale / verticality / sightline / routing / encounter and Check placement rather than in dressing, and must not be generic stretches of one another where gameplay geometry matters. The approved six material families and the Batch 014 fixture language both apply.~~ Corridors done as Batch 015. |
| ~~Superseded~~ | ~~**Tier 8: the three unbuilt theme material families** (`neon_transit`, `gothic_stone`, `temple_ruin`). It is the highest-leverage unblocked work left — it also unblocks three of the six dressing props §9 needs — and it is routine in the sense that `art_palette.json` already carries all six themes' ramps and `materials.paint()` already builds any of them. **But it is the first look at three themes**, so it wants a review sheet the owner can redirect cheaply, and textures are the cheapest thing in the project to rebuild.~~ Done as Batch 012. |
| Queue depth | **Pending owner review: 023-030 only.** 001-022 and 031-037 are all `PASS` as of 2026-08-29. The hourly heartbeat stays **paused** (`trig_01DSWy2dbCpeSefcx2YGS9Ys`, disabled 2026-08-29) and the PR #5 poll is deleted; PR activity still wakes the session on its own. **Do not re-enable the routine on an idle lane** — re-enable it only when an owner brief, a verdict or a Production contract gives it something to do. |

### What the post-030 gap pass review LOCKED (owner, 2026-08-29)

Four batches are `PASS` and are not open again.

**031 — zone keys. PASS.** Four things are locked:

- **The part the keyway reads is UNIVERSAL** — one shank, one shoulder, one
  keyway relationship, shared by every key and every receiver. Everything
  outboard of that may be themed.
- **Channel coding is STRUCTURAL, never colour** — channel N is N lugs and a
  notch rotated N × 40°. A player counts; they do not match a hue.
- **The grip is themed.** That is where a key is allowed to belong to a world.
- **It is a machined interlock**, not a keycard and not a fantasy artefact.

**032 — the baseline melee. PASS**, and with an explicit boundary. The
ranged / melee / grapple `EchoPart` forms built alongside it are **proof of
the attachment seam and nothing more** — they are *not* approval of a
seven-fixed-forms system, and Art must not expand them into seven production
family models. Requirement 32 now reads *"the Echo family must be visible
through a swappable / composable `EchoPart` seam"*. **The owner will design a
modular Echo kitbash system separately**, and the seam exists to receive it.

**033 — the Zone exit AUDIT. PASS, and BUILD NOTHING.** The recommendation
stands as the outcome: `exit_portal.gd` is already the Zone exit, correctly
scaled and contextually separated from the two Hub portals. Three things are
recorded for Production and are Production's to fix:

- the existing exit portal is sufficient — no new portal asset;
- the lifecycle needs **more than a boolean visual state**;
- **locked / dead must not use hazard-red semantics.** A locked exit is not a
  hazard; `dead` is the family whose own definition contains the word
  *locked*.

**034 — hard gates. The VISUAL PRINCIPLE passes:** an intentional capability
route reads as **finished, installed, deliberate**; broken geometry reads as
**ragged, incomplete, a construction failure**. Blink / teleport remains
**proposal-only** — it has no mechanical contract, so it gets no production
asset.

**The boss audit is accepted and builds nothing.** Its finding stands as a
recorded dependency: the missing piece is a **telegraph vocabulary, not a
body**.

**035-R — interactable vs decorative. PASS.** Two things are locked.

> **If a distinction must survive gameplay distance, the distinguishing
> feature must affect object-scale SILHOUETTE.**

And the redundancy direction, which is now the standing rule for every
operable object:

| channel | question it answers |
|---|---|
| silhouette / structure | **what kind of thing** this is |
| interaction hardware | **yes, this object is operable** |
| state treatment | **what it is doing now** |

The interaction plate / bezel **may remain** as standardized physical
hardware, on two conditions: it is **not the sole source of truth**, and it
**does not rely on hue alone**. The pure-silhouette sheet is accepted
evidence. Breakable vs blind panel is the weakest pair and is still
acceptable.

**036-R — secret cues. PASS.** The corrected eight-cue package is accepted,
and five things are locked:

- **no universal secret colour;**
- a secret cue is a **deviation from a learned environmental pattern**;
- a **smaller reliable vocabulary is preferred over padding the set**;
- `repeated_motif` **remains deleted**;
- the current tiering is accepted.

> **Stop revising this system until it has real in-game Zone testing.**

**037-R — enemy surface role identity. PASS WITH DOCUMENTED CAVEAT.** The
surface construction rule is accepted:

- **plate** = a proud slab, impact-bearing construction;
- **mechanism** = recessed, ribbed, rodded — exposed function.

No role colours. Shared enemy-family ancestry is preserved. The close
comparison sheet demonstrates the system sufficiently.

**The caveat, recorded as accepted rather than outstanding:** brute vs
scuttler surface identity remains weak — the scuttler still reads more
armoured than its description implies. **This is accepted for now.**

> **Do NOT alter the approved scuttler silhouette or body solely to force a
> stronger surface distinction.** Its silhouette already carries substantial
> role identity, so surface treatment may remain *supporting* information
> here. Revisit only if later gameplay testing shows a real recognition
> problem, and only with gameplay evidence.

### Post-art A/B integration prep (2026-08-29, owner-directed)

**Not a batch. Not Batch 038.** No asset is new, redesigned or unapproved.

`docs/art/INTEGRATION_HANDOFF.md` is the deliverable: the art half of the
post-art side of the Playtest 2.5 Zone 1 comparison, plus the exact wiring
Production needs.

- **Exported:** `godot/content/` — six approved light HOUSINGS and three
  approved projectile VISUALS, generated by `tools/export_content_pack.sh`
  and validated by `tools/verify_content_pack.sh` against **BOTH of
  Production's validators** — `schemas/content.py` (strict pydantic) and
  `content_registry.gd` — each fetched read-only at run time.
- **Repaired 2026-08-30 (L-80).** The first pack was verified against the
  GDScript half only and Production's Python gate rejected it: a
  231-character `description` against a 160 limit, plus `source_asset` and
  `source_batch_review`, two fields `ContentEntry` forbids. The exporter now
  emits schema fields only, carries a `_check()` that refuses to write a
  manifest Production would reject, and keeps the provenance in
  `SCENE_PLAN.json` instead. **No approved visual asset changed** — every
  `.glb`, `.tscn`, `.png` and `.import` is byte-identical.
- **Verdict: READY FOR PROD INTEGRATION** at those two seams, which cannot
  move gameplay — the engine builds the lamp and owns the hitbox in both
  runs, and no authored scene carries a light, a collider, a dimension or a
  socket.
- **Verdict: OWNER BLOCKER for room shells.** Batches 015-019 are approved
  and are deliberately **not** exported. `_from_authored_scene` takes one
  fixed `size` per registry entry and derives `exit_offset`, `bounds`,
  `reward_position` and `enemy_spawns` from it, while
  `ChamberBuilders.corridor` reads the generator's **per-chamber**
  length/width and raises height for affordance features. Swapping them
  changes the Zone's topology and therefore its level id, which is the
  contamination the freeze exists to prevent. Art has not routed around it.
- **Also recorded:** only THREE authored seams exist in the runtime at all
  (room shells, light housings, projectile visuals). Enemies, Checks,
  portals, interactables, keys, gates, secrets, pickups and props have no
  seam, so those approved batches cannot appear in a Zone whatever the art
  lane does. Engineering truth, not an art defect.

The boundary below is unchanged by this work.

### P2 — the eight dimensionless shells, retrofitted (2026-09-01)

**Not a batch, not Batch 038, not live.** Source-side retrofit of the eight
already-approved F3 shells to Production's landed P1 room contract
(`99379e5`). All eight export `review: "pending"`; nothing is
player-selectable.

`docs/art/P2_SHELL_RETROFIT.md` is the record. In short:

- **Every field derived** from the variable that placed the geometry.
  `stones` — routecheck's own ordered list, computed, validated against
  `max_safe_gap`, then discarded — is now the towers' `surfaces` AND their
  `traversal`.
- **Zero mesh changes.** Every `.glb`, and every texture, is byte-identical.
  Traversal `Marker3D`s live in the `.tscn` wrapper the exporter generates.
- **The axis conversion is explicit and guarded.** `roomcontract.py` holds
  the one Blender→Godot transform, and `assert_axis_order` states an
  invariant rather than a tolerance.
- **ONE BLOCKER, and it is Production's.** `ShellValidator._check_envelope`
  refuses all eight because the entry door wall sits at z ∈ [−0.4, 0] and
  the envelope starts at z = 0 with 0.15 m of slack. **Production's own
  procedural rooms would fail the same check by 0.05 m** — their front wall
  is centred on z = 0. No mesh was modified to work around it.
  **CLOSED at `eda4fd9`:** Production replaced both opinions with one
  shared `RoomContract.WALL_ALLOWANCE` and now runs the check on both
  producers. Zero envelope violations across the eight.
- **Not emitted, deliberately:** `size_class` (P1 made it optional; a guess
  would dress taste as geometry), `cost`, intent tags.
  **`size_class` is now emitted** — see P2-C below; the owner decided, so
  it is no longer a guess.

### P2-C — collision, and the three fields (2026-09-01)

Production integrated all eight at `eda4fd9` and could measure **none** of
them: every shell imported with one `MeshInstance3D` and zero colliders, so
the audit's 625 probes all reported "nothing is there". Structural
violations were zero — the metadata was well formed and describing a room
that, physically, was not present.

Still `review: "pending"`. Nothing here approves anything.

- **Collision is authored now, and derived.** `tools/blender/roomcollision.py`
  turns each structural `brushkit.block` into a collision-only twin — the
  same eight vertices, so the convex hull IS the box. The role already
  passed to `_paint` decides: `floor`/`wall`/`ceiling` collide, `trim` does
  not. A ninth shell inherits it by being built the way the eight are.
- **`-convcolonly`**, verified against this repo's own Godot rather than
  from memory. Convex because the spec allows trimesh only for decorative
  geometry; `only` because the collider must not render *and* because
  `RoomAudit`'s envelope check reads `MeshInstance3D`s, which this suffix
  leaves none of.
- **The visible art did not change.** `tools/content/diff_shell_glb.py`
  compares accessor payloads byte for byte across the rebuild: same
  vertices, normals, UVs, indices, materials and PNGs in all eight, and the
  eleven unpacked F3 shells byte-identical.
- **Three fields learned.** `size_class` (owner assignment, tabled with its
  provenance and explicitly NOT derived from metres), `exit_yaw` (the
  builder's own `turn × 90`, copied not recomputed), `fits_floors` (the
  authored floor count 2/3/5).
- **The corners are corridors.** `corner` is not a chamber type, so the old
  tag meant they could never be offered. Chamber type is now `corridor`;
  `corner` survives as a shape tag beside it.
- **TWO FINDINGS, both reported and neither corrected.** (1) The three
  treasure rooms declare a `step_low` surface that the plinth's own upper
  step stands on — req 38. (2) The 47 headroom notes P2 could only PREDICT
  are now 47 the engine MEASURES, because a tower's climb is a chain of
  1.00 m footholds and a `Surface` claims you can stand — req 39. Both are
  about what the manifest CLAIMS, not about the approved geometry, and
  neither was quietly dropped to get eight greens.
- **The prop rule was written down a third time, in our own checker.**
  `verify_pack.gd` asserted "hitboxes are engine-owned" against all
  seventeen entries and refused the eight shells the moment they got the
  collision they were missing. Production refuses a light on a light
  housing and collision on a projectile visual — two scoped rules, neither
  about room shells. Found by running the checker, not by reading it.

### THE BOUNDARY — do not start the next art system (owner, 2026-08-29)

The art lane is **intentionally idle**. Two major systems are being designed
by the owner and a design collaborator first, and each will arrive as its own
owner-authored brief:

1. **Modular Echo visual construction / kitbash system**
2. **Diegetic in-world interface system**

**Echo visuals.** Requirement 32 remains **only the architectural seam**: the
Echo family must be visible through a swappable / composable `EchoPart` seam.
The three existing ranged / melee / grapple forms are **proof-of-seam only**.
They are explicitly **not** approval of any of:

- seven fixed family models;
- a final attachment grammar;
- a final part taxonomy;
- runtime composition rules;
- family silhouette rules;
- provenance / source influence rules.

All of those will be specified in the future brief. **Do not begin designing
or mass-producing Echo visual parts.**

**Diegetic interfaces.** Do **not** independently expand the interaction-kit
work into menus, terminals, Archive UI, Forge UI, Zone-selection UI, or any
other large physical interface. That system gets its own brief too.

**No Batch 038. No heartbeat. No polling. No autonomous expansion.**


### What the Batch 002 review LOCKED

Six things are `PASS` and are not open again:

- **Facility architecture** — the baseline human language.
- **The lighting rule** — cold facility, pale surfaces, localized yellow
  utility pools, never a globally warm room.
- **Check A** — its identity stays separate from Epsilon green.
- **Both grapple anchors** — A common/ceiling, B directional/wall.
- **The portal language** — human architecture + alien intrusion. Future
  variants may get stranger; the split does not.
- **The enemy family** — reads at gameplay distance, role diversity good.
  **This roster is the first production family and must not be reduced back
  to melee / ranged / brute.**

And one thing is recorded for later, so it is not re-derived: the long-term
roster target is a broad classic-FPS ecosystem — common, flyers, flankers,
artillery, support, bruisers, elites, specialist weirdos, miniboss-scale —
**inspired by the ROLE COVERAGE** of the classics and never copying their
designs, roughly ~20 types over time, with **flyers as a core category**
because the grapple gives the game verticality. Not now: the roster does not
grow again until Style Lock passes.

### What the Batch 001-R review settled

- **The facility is approved**, with one clarification: the room stays
  **cold** and warm yellow appears only as **localized utility pools and
  fixtures** within it. Not a globally warm room.
- **Both grapple anchors are kept.** A is the ceiling case, B is the
  wall / side / directional one.
- **Check A is approved.** The three enemy silhouettes are preserved.
- **Epsilon had to get bigger**: a room-scale computer installation with the
  alien core erupting through it, not a pedestal or a shrine.
- **The enemy roster expands as ORIGINAL designs**, studying what a classic
  FPS roster covers rather than any specific game's enemies, and flyers are
  wanted because the grapple creates verticality.

### What the Batch 001 review settled

- **The contrast.** Facility = cold grey abandoned research lab. Epsilon =
  alien intrusion, neon green, embedded into it. `ART_BIBLE.md` §1a.
- **Selections:** Epsilon **B**, Check **A**, Portal **B** as direction,
  Anchor **A** primary with **B** kept, and all three enemy concepts kept
  and reinterpreted as **melee / ranged / brute**.
- **Nothing was deleted.** Unselected concepts are `KEPT`.

### Objective state, last verified

| Check | Result |
| --- | --- |
| `python3 tools/blender/engine_truth.py` | PASS |
| `python3 tools/blender/palette.py` | PASS |
| `python3 tools/blender/check_docs_metrics.py` | PASS — every number in ART_REVIEW.md and ASSET_INVENTORY.md matches the build |
| `tools/sabotage_checks.sh` | see the commit for the run |
| `python3 tools/blender/sync_inventory.py` | 134 assets written |
| `tools/check_art_current.sh` | PASS — every asset byte-identical from source |
| Assets built | 134 models + **31 theme textures (six of six families)** + 7 prop skins + review images in `review/batch001` … `batch021` |
| Composed room | 3,272 / 12,000 triangles |

### What a heartbeat cannot see

The hourly routine stores no MCP connectors, so a heartbeat session runs
**without `mcp__github__*` tools** — and `curl` against the GitHub API is
unauthenticated in this sandbox and returns an empty check-run list rather
than an error. A heartbeat therefore **cannot read CI status**, and a poll
loop built on `curl` would report silence forever, which looks exactly like
"still running".

So: a heartbeat does not chase CI. PR events wake the interactive session
directly, and that is where CI is judged. If a heartbeat needs to know, it
should say it cannot rather than guess.

---

## Where the review images are

**[`docs/art/review/batch005r/`](review/batch005r/)** · **[`batch006/`](review/batch006/)** · **[`batch007/`](review/batch007/)** · **[`batch008/`](review/batch008/)** · **[`batch009/`](review/batch009/)** · **[`batch010/`](review/batch010/)** · **[`batch011/`](review/batch011/)** — with the owner now

`batch005r/` is the one required Batch 005 revision: locked against
confirmed at 39.6 m, measured. Start at `R_state_family_far_inset.png`.
`batch006/` is the portal's two core states and the standard door; start at
`P_portal_states.png`. `batch007/` is the five Pri-A traversal modules;
start at `T_corner_turn.png`. `batch008/` is the three projectiles; start at
`X_projectile_family.png`. `batch009/` is the six remaining affordances;
start at `A_affordance_family.png` and its silhouette.

**[`docs/art/review/batch005/`](review/batch005/)** — the Check, in full

| Prefix | What |
| --- | --- |
| `K_state_family` | **start here** — the Check's four states, one camera, one frame |
| `K_state_family_far` · `_far_inset` | the same four at 39.6 m, and those pixels at 4× with no filtering. **The sheet that changes something** |
| `K_check_assembled` | mast + item + ring, with grey / silhouette / clay |
| `K_check_operator` · `_far_read` · `_cage_detail` | walk-up, distance, and the caged head at 85 mm |
| `K_item_family*` | the four items alone — lit, grey, silhouette |
| `K_destination_ring` · `K_send_beam` | the two the engine tints per recipient world |

Its `README.md` carries the three questions the batch is asking.

**[`docs/art/review/batch003/`](review/batch003/)** · **[`batch004/`](review/batch004/)** — the Hub and the Echo Lab.

**[`docs/art/review/batch002/`](review/batch002/)** — the Style Lock batch

| Prefix | What |
| --- | --- |
| `A_epsilon_operator` | **the frontal operator view** — eye height, one pace back. The shot 002-R exists for. |
| `A_epsilon_fusion` · `_oblique` · `_value` | the takeover close up, from the alien end, and with the hue removed |
| `A_epsilon_installation*` | **the room-scale computer installation** — wide sheet, 4 m medium, 2 m close |
| `A_epsilon_in_room*` | the same object standing in a 12 m room, head-on and oblique |
| `I_room_utility_pools*` | **cold room, local warm pools** — lit, greyscale, and standing in one |
| `I_room_warmlight_rejected` | the 001-R globally-warm version, kept and labelled |
| `C_portal_b2_wound` | **the breach, pushed** — the wall is present now |
| `D_enemy_family_*` | **ten roles at 18 m**, lit and silhouette, two ranks of five |
| `E_anchor_{a,b}_use` | **what each anchor is for**, with the jump it has to beat drawn in |
| `F_style_board*` | the two languages in one frame, lit and greyscale |

Start with `A_epsilon_operator.png` and `A_epsilon_in_room.png`.

**[`docs/art/review/batch001/`](review/batch001/)** — the previous batch

| Prefix | What |
| --- | --- |
| `A_epsilon_b_core` | **the revised intrusion** (A and C kept, unrevised) |
| `B_check_a_pedestal` | **the revised signal mast** (B and C kept) |
| `C_portal_b_collar` | **the revised breach** (A kept) |
| `D_enemy_lineup_*` | **all three archetypes in one frame at 18 m** — lit, silhouette, clay |
| `D_enemy_{melee,ranged,brute}_*` | the three individual sheets |
| `E_anchor_a_soffit` | primary; `E_anchor_b_jib` kept as a variant |
| `F_arch_*` | 9 modules, including the new `wall_ribbed` |
| `G_prop_*` | 7 props, re-toned off the base ramp |
| `H_material_*` | 3 theme sheets; `concrete_facility` now has 6 roles |
| `H_probe_*_room` | **in-engine theme probes** — void_glitch (requested) and rusted_industrial |
| `I_room_*` | the revised room — wide, greyscale, near, warm-light proposal, and each Check in the same spot |

Start with `I_room_wide.png` and `I_room_greyscale.png`. They answer whether
the pieces make a place, which is the question the other 31 sheets cannot.

---

## Rebuild and re-render, in full

```sh
B=.tools/blender/blender
for s in materials architecture props concept_epsilon concept_check \
         concept_portal concept_enemy concept_anchor \
         batch002_enemies epsilon_installation hub lab check \
         ways_out traversal projectile affordances dressing \
         rails; do
  $B -b --python tools/blender/build_$s.py
done
tools/batch001_sheets.sh      # ~12 min: 28 sheets
tools/composed_room.sh        # ~2 min: 12 room captures, incl. Epsilon in context
tools/shoot.sh <list.json>    # ANY shot, from a JSON list. Start here.
                              #   tools/shots/batch004_lab.json
                              #   tools/shots/batch005_check.json
                              #   tools/shots/batch005r_check.json
                              #   tools/shots/batch006_ways_out.json
                              #   tools/shots/batch007_traversal.json
                              #   tools/shots/batch008_projectile.json
                              #   tools/shots/batch009_affordances.json
                              #   tools/shots/batch010_dressing.json
                              #   tools/shots/batch011_rails.json
tools/pixel_inset.py          # a region of a render, magnified NEAREST
tools/hub_room.sh             # the Hub, built out of authored assets
tools/epsilon_views.sh        # the operator / oblique / fusion / value views
tools/enemy_family.sh         # the ten-role family sheet
tools/anchor_use.sh           # what each anchor is for
tools/style_board.sh          # the two languages in one frame
tools/check_art_current.sh    # includes the document-metric check
tools/sabotage_checks.sh      # refuses to run against a dirty tree
```

Toolchains are fetched per session into `.tools/` (gitignored) — see
`ASSET_AUTHORING.md` §1. Blender **4.5.9 LTS**, Godot **4.5.1 stable
(f62fdbde1)**.

---

## Open interface requirements — engineering's, not ours

Documented rather than invented. Nothing in Batch 001 depends on any of
them; each is a thing the art lane will need when contracts settle.

| # | Requirement | Why | Blocks |
| --- | --- | --- | --- |
| 1 | **An asset registry keyed by stable asset ID**, mapping ID → resource path + anchor + footprint + category. Epsilon selects an ID; Godot resolves it. **Epsilon never sees a path.** | An Epsilon that can name a resource path can name any file. | All integration |
| 2 | **Editor import settings preserving NEAREST with mipmaps.** The bench proves the *runtime* GLTF path keeps the sampler; the *editor* import path is a different code path and is untested. | An authored asset importing with linear filtering makes the authored/procedural seam the most visible thing in the room. | Integration |
| 3a | **~~A warm `light_color` for `concrete_facility`~~ — WITHDRAWN at 001-R.** The owner's answer was that the room stays cold and the warmth is local, so `THEME_MATERIALS` does not change. What is needed instead is a **second, short-range warm fixture light** the generator can place — energy well under the theme's own and a range around 2.6 m, so its falloff lands inside the room. `I_room_utility_pools.png` is the proposal; `I_room_warmlight_rejected.png` is what it replaces. | A single per-theme light colour cannot express "cold room, warm pools". | placement of `arch_utility_lamp` |
| 3 | **A decision on `TEXTURE_SIZE_MAX` for imported assets.** 128 bounds the runtime generator. Batch 001 stays under it so nothing depends on the answer. | The deferred first-person viewmodel tier needs 256. | `viewmodel_*` |
| 4 | **A footprint contract for the Epsilon presence, and it is now a big one.** `hub.gd` has a generic 2.0 × 3.0 × 0.8 m terminal and no dedicated fixture. Batch 002's installation is **8.80 × 2.61 × 3.55 m** — roughly a third of one 22 m Hub wall. The 001 concepts fit the old envelope; this one does not, on purpose, because the owner asked for an installation rather than a prop. | **RESOLVED 2026-08-28, in the installation's favour.** *The room-scale Epsilon installation is a hero asset and should keep the proposed prominent back-wall presence.* Epsilon gets the reserved bay: do **not** shrink it, move it somewhere visually secondary, or redesign it around the abandon station. Production Engineering moves or reserves the much smaller abandon console outside Epsilon's footprint while keeping it obvious and reachable near the Zone workflow. | `hub_epsilon_presence` |
| 7 | **Collision boxes for seven proposed enemy roles.** `enemy.gd` defines melee, ranged and brute. Batch 002 proposes scuttler, charger, bulwark, artillery, beacon, drifter and diver, each with a declared box and `"engine_box": false` in its manifest, and the two flyers with a proposed hover height. | Nothing past the trio can be placed until its collider exists, and a model built to a box nobody agreed to is a model that will be rebuilt. | every batch002 enemy |
| 9 | **An in-game photo mode.** `docs/art/proposals/photo_mode.gd` is complete and parses clean: a free camera with scripted `frame()` / `frame_orbit()` / `frame_box()` entry points sharing the art bench's framing maths. It belongs at `godot/scripts/ui/photo_mode.gd` and this lane does not write there. | Every screenshot of the running game is currently whatever the player camera happened to be pointing at. | nothing — it is additive |
| 8 | **A wall-mounted grapple anchor.** `affordance_features.gd` only knows the ceiling case. `anchor_b_wall_jib` proposes a 2.6 m plate height. | The directional variant the 001-R review asked to keep cannot be placed without it. | `anchor_b_wall_jib` |
| 10 | **A decision on how `reward.gd` shows the Check's state, and two small consequences of it.** Batch 005 authors state as four meshes rather than one repainted one, because state is a closed set of four and a `material_override` replaces the authored surface. Either integration works. Whichever is chosen: `ItemVisual.position` becomes `Vector3.ZERO` — the item is authored at its true height inside the mast's cage, so the engine must not re-place it — and the ±0.12 m bob must go, because the cage interior is 0.37 m and the item fills 0.31 of it. The spin is fine: every part is rotationally symmetric on purpose. | A mesh swap keeps the authored surface in all four states and gives state a FORM channel as well as a hue one. An override keeps one mesh and loses both. | nothing — `check_item_available` works either way |
| 11 | **The destination ring is load-bearing for the Check's state read at distance, and nothing said so.** At 39.6 m the item is 4 px and locked and confirmed do not separate — `K_state_family_far_inset.png` is the evidence. They separate in the running game only because `reward.gd` drops the ring to 0.35 emission energy when locked and leaves it at 1.5 otherwise, which is 26 px of channel. Also: the ring is 1.90 m across against a 1.4 m collider, so it overhangs by 240 mm a side and a Check cannot sit flush to a wall. | If the ring's locked dimming is ever removed or repurposed, locked and confirmed become the same object across a room, and no test would catch it. | placement of every Check |
| 12 | **`exit_portal.gd`'s `Core` is placed for a solid box frame, not an authored one.** It is a 2.4 × 3.4 mesh at `y 1.9`, so it spans 0.2 to 3.6 — invisible inside a 4.2 m `BoxMesh` `Frame`, and wrong inside an authored frame whose aperture is a real hole from the floor to a 3.4 m lintel. The authored cores are built at true height and anchored `module_floor`, so `Core.position` becomes `Vector3.ZERO`. Same contract as `check_item_*`. Also: the remaining-Checks count stays engineering's `StateLabel` — it is an unbounded integer, and a pip row that saturated at eight would be lying at nine. | A core placed 200 mm high leaves a gap at the threshold and pokes through the lintel. | `portal_core_*` |
| 13 | **`echo_projectile.gd` picks its visual by nothing.** It builds one `SphereMesh` and scales it 1.5× for a lob, so `gravity_scale` and `blast_radius` — the two facts that decide whether the player steps sideways or runs — are invisible. Batch 008 authors one mesh per kind; selecting between them is a `match` on data the node already holds. | Three reactions, one silhouette. The distinction the engine does draw, size, is the least useful of the three. | `enemy_projectile_*` |
| 14 | **There is no node an authored enemy telegraph could be.** `ASSET_INVENTORY.md` §4 asks for one telegraph per archetype, readable at 18 m. `enemy.gd` has exactly one windup — the brute's — and it is `scale = Vector3.ONE * (1.0 + 0.12 * sin(...))` on the whole body. Melee and ranged have a cooldown and no windup at all. An authored telegraph needs either a child node the engine shows during windup, or a second body mesh it swaps to. | *A telegraph is a promise* (`AUTHORED_CONTENT.md`). Two of the three archetypes currently make none. | `enemy_telegraph_*` |
| 15 | **The six affordance tints are six ad-hoc colours and the family rule says they should be one.** `ASSET_INVENTORY.md` §5 states *the seven look the same everywhere or they teach nothing*, and the approved grapple anchors wear `signal`. `affordance_features.gd` gives the breakable wall the theme hazard, water `(0.35, 0.75, 0.95)`, the rail `(0.9, 0.7, 0.95)`, wind `(0.7, 0.95, 0.9)`, and the bounce pad and moving platform the theme accent and trim. Four are absent from `art_palette.json`; two vary per theme; and the rail's violet sits beside `glitch`, which means *cosmetic corruption, no mechanical meaning*. | **DECIDED 2026-08-28, in art's favour.** The owner's ruling: all optional traversal affordances use the approved SIGNAL family; silhouette / form tells the player WHICH affordance it is; SIGNAL colour tells them THIS IS A CAPABILITY OPPORTUNITY; and theme, source-game colour and Epsilon green each do **not** redefine that semantic. Two engine-owned dynamic channels are explicitly preserved: the breakable wall's damage / crack state, and the wind ring count and stack presentation. This is now a requirement for Production Engineering rather than a question, and no gameplay behaviour changes from this branch. | every `batch009` asset |
| 16 | **A rail that turns needs a wider `FOOTPRINT["rail"].half_width`, and every curved rail needs its ride built from `ride_path`.** Two halves of one request. (a) `half_width` is 0.5 and the rail is 0.42 m across, so a lateral swing has 270 mm either side — a weave, never a turn; a banked 90° turn wants roughly 1.6 m of half-width. (b) The lane over a rail is an axis-aligned box `Area3D`, which cannot follow a curve — so each Batch 011 rail is a POLYLINE and its manifest carries `ride_path`, the points the mesh was swept along. One box per segment is implementable with the class that already exists, and building the volume chain from that list keeps the mesh and the ride from drifting apart. | **CONFIRMED 2026-08-28.** The owner approved `ride_path` as *the authoritative geometric path shared by visual mesh and runtime riding geometry* — *"do not independently hand-author visual rail and collision/ride path"* — and confirmed one ride volume per straight polyline segment as a valid integration direction. The footprint half is retained as **future expansion, not a blocker**: broader lateral curves, banked turns and longer linked rail compositions come after a wider legal footprint and ride physics are agreed with engineering, and until then art does not *"fake a dramatic lateral curve inside an invalid footprint"*. | `rail_arc_*`, and any turn |
| 17 | **A playtest check that the three projectiles stay readable in motion, in all six themes.** The owner passed them as art on the 12 m Hub evidence and asked for this explicitly as integration validation: that moving projectiles remain trackable, that straight / falling / lobbed keep reading as three different reactions during actual gameplay, and that it holds in every theme environment. | Not a blocker and not a reason to redesign anything: *"Do not redesign them preemptively unless that test fails."* | nothing — it gates a future revision, not the models |
| 18 | **`concrete_facility` has one dressing prop and it is a warning plate.** `_theme_props` places `prop_wall_plate` as that theme's "put decoration here" slot — one to two per chamber, at a random height between 1.2 and 2.0 m and a random position along the run, with no notion of whether anything there warrants a warning. The owner's ruling: **orange must remain warning / hazard language**, the approved plate must NOT be recoloured to make it generic, and the fix is neutral facility dressing vocabulary of its own plus a placement rule that reserves the plate for warning / hazard / maintenance semantics. | Left alone, the one facility dressing prop becomes facility wallpaper, and the palette's loudest and most specific colour stops meaning anything. | `prop_wall_plate`, and the neutral facility dressing that does not exist yet |
| 19 | **Which chambers get a ceiling is inconsistent, not absent.** `corridor()`, `corner()` and `treasure_room()` close their tops; `arena()` and `tower()` do not. | **RESOLVED 2026-08-28. NORMAL ROOM SHELLS ARE ENCLOSED BY DEFAULT** — corridors, arenas, towers, treasure rooms and corners alike, so the authored arena and tower roofs are correct. Open sky, open roofs, missing ceilings and structural breaches are allowed later only as **explicit authored or semantic variants** (open courtyard arena, collapsed-roof arena, exterior industrial arena, ruined temple chamber, void-open chamber, deliberate breach), each with proper boundary, collision and navigation treatment: *a missing ceiling must never accidentally be interpreted as intentional content.* Platform paths are the deliberate exception and stay open. Production Engineering aligns procedural and fallback chamber construction with this rule. | every `shell_*`, and every room shell after them |
| 20 | **`corner()` paints hazard orange as a navigation marker.** A 0.06 × 1.0 × 2.0 stripe in `ThemeMaterials.hazard_mat` on the inner wall of a turn, purely to say *the corridor bends here*. | **RESOLVED 2026-08-28: REMOVE IT.** *Hazard orange remains reserved for hazard / warning semantics. "A corridor turns here" is not a hazard.* The authored corner's form language is the default — the opening itself, the deep jamb reveal, the stepped chamfer, and the skirting carrying through the turn — and Production Engineering stops applying `hazard_mat` as a generic navigation marker on normal corners. If playtesting later shows turns need more wayfinding it is solved with a non-hazard channel: neutral architectural contrast, light placement, a trim or value change, or the future approved signage / navigation language. **Do not spend hazard orange on ordinary navigation.** **A second site under the same ruling, found while building Batch 020:** `_greeble_room` also lays a `(DOOR_WIDTH + 0.8) × 0.02 × 0.6` strip in `hazard_mat` across the entrance threshold of *every* room it dresses, unconditionally. A threshold marking can be legitimate caution language where there is a step or a lip; applied to every room regardless it is decoration in the loudest colour the palette has. Same fix as the corner: reserve it for thresholds that warrant it, or give it neutral vocabulary. | `shell_corner_left`, `shell_corner_right`, and every room `_greeble_room` dresses |
| 21 | **`prop_sconce_flame` has never been seen with the effect it was designed for.** The art preview runs Godot's Compatibility renderer, which has no glow — so no render in this project, for any batch, has ever shown bloom (L-03). The flame is the one asset whose read genuinely depends on it. | **Owner's integration note on the Batch 013 PASS, and not an art blocker:** the flame gets another visual check inside the real Godot rendering path with its intended glow/bloom, because *the authoring sandbox cannot fairly judge that effect.* **Do not redesign the flame before that test unless an actual in-engine failure appears.** | `prop_sconce_flame` |
| 22 | **`arch_affordance_socket` has nothing to attach to.** §3 lists it as Pri B and it looks buildable, but `affordance_features.place_all` builds each feature as a COMPLETE node and positions it directly on the chamber floor — the grapple anchor makes its own plate as part of itself, not as a separate mount — and `FOOTPRINT` is a clearance rule consumed by `fits()` and `required_width()`, never geometry. There is no socket node, no mount, and no code path that would place one. | **RESOLVED 2026-08-28: do NOT create a universal authored affordance socket / footprint mount.** `arch_affordance_socket` is struck from the required inventory. The footprint stays an **engineering placement / clearance contract, not literal geometry that must be shto the player** — *the footprint being invisible is not itself a UX failure.* The player needs to understand what the affordance is, what it does, and where it is usable; not a physical diagram of the generator's placement clearance. **Each affordance owns the physical attachment language it actually needs**: grapple anchors their own mounting plate / jib / soffit, bounce pads their own base, rails their own supports, moving platforms their own deck, breakable walls are already architectural surfaces, water volumes own their basin, wind fixtures their own perch and ring. If one later proves to need more mounting or support geometry, **extend that approved affordance family** rather than inventing a universal architecture module. | struck from §3 |
| 23 | **`trim_plain` has no engine counterpart, and the engine's `trim` already means what art's `trim_plain` means.** Batch 022-R added an art-side `trim_plain` role: theme-owned trim without hazard semantics. Checking the engine before assuming a contract change was needed turned up the reverse of the expected problem. `generation/theme_materials.gd` already separates them — `trim_mat(theme)` is `_material(theme, "trim", "panel")` and `hazard_mat(theme)` is `_material(theme, "accent", "hazard")` — so the runtime's `trim` has never carried a hazard band. The conflation was **art-side only**, in `materials._rust_trim`. | **No engine change was made and none is needed today**, because nothing runtime-owned was altered: `trim_plain` lives entirely in the art authoring pipeline. The seam matters when the authored materials replace the procedural ones, because the role names will not map one to one: engine `trim_mat` corresponds to art **`trim_plain`**, and art's hazard-bearing `trim` corresponds to where the engine would call `hazard_mat`. A migration that maps `trim` to `trim` will put hazard striping on every rusted-industrial fixture. Recorded for Production Engineering rather than silently resolved. | `materials.py`, `generation/theme_materials.gd` |
| 24 | **REWORDED 2026-08-29 after a read-only audit of current Production (`claude/archipepsi-echoes-continuation-b1adno`), which the original research missed: it searched the art lane's base, 73 commits behind.** Production HAS an authored-content pipeline — `ContentRegistry` loads and validates manifests from `res://content/registry/` (category, level, sockets, footprint, scene existence, fallback cycles), `ContentInstantiator` routes *authored scene → validated fallback* and reads the `shell_id` Epsilon chose, `schemas/content.py` is the shape authority, and **`landmark` is a registered L4 category in both languages.** Room shells are AHEAD of landmarks, not level with them: they have a routing table, an Epsilon-facing id and a fallback chain. `composition.LANDMARK_RATIO` is an unrelated second sense of the word (the biggest ROOM in a Zone) and accounts for most of Production's mentions. **What is actually missing is four steps, of which only step 2 works today:** (1) approved `.glb` → Godot-importable scene under `res://content/` — MISSING, the Godot project contains zero `.glb`, excludes `assets/`, and the registry refuses any scene outside `res://content/`; (2) registry entry — POSSIBLE NOW; (3) selection — MISSING, no `landmark_id` on the chamber schema, though `ids_of_category` / `ids_with_tags` would answer if there were; (4) placement — MISSING, nothing queries category `landmark`, and there is **no envelope**: `NEEDS_FOOTPRINT := ["cluster"]` excludes it and `Constants` publishes `CLUSTER_MAX_WIDTH/HEIGHT/DEPTH` with no `LANDMARK_` equivalent. Batch 023's places reach 25.0 × 25.0 × 12.45 m against a cluster cap of 6.0 × 4.0 × 2.5; they are not clusters and must not inherit those numbers, but nothing publishes what a landmark's numbers should be. **The ask is step 1, step 3's schema field, and step 4's envelope — nothing Production has already built.** ~~ORIGINAL, STRUCK: There is no landmark placement contract, and no engine seam for authored assets at all.~~ Batch 023's audit went looking for one before modelling. `grep -rn landmark` over `godot/`, `bridge/` and `assets/` returns three hits and none is an engine concept: `max_triangles.landmark = 2500` in the derived budgets, and one asset exporting under that tier. So "landmark" today means a POLYGON CEILING. Epsilon cannot select one — `AUTHORED_CONTENT.md` lists *Reusable landmarks and hero props* as a category it would choose from, but no schema field or vocabulary entry implements it. The room shells (015–019, PASS) carry `check_anchor`, `enemy_anchors`, `affordance_anchor`, `bay_anchors`, `bounds`, `interior` and `sightline` — and no landmark anchor among them. | ~~STRUCK, FALSE: The wider finding is the important one, and it is not specific to landmarks: `godot/scripts/` references no `.glb` and reads no manifest. `chamber_builders.gd` builds every room from `BoxMesh` primitives, so the entire authored art pipeline is unwired — the approved room shells sit in exactly the same position as these landmarks.~~ **Every clause of that was wrong, and it was the strongest claim in the batch.** Kept visible rather than deleted, because the failure mode is worth remembering: the audit was rigorous and reproducible and pointed at a branch that was 73 commits stale. Nothing in Batch 023 is registered as integration-ready, and every manifest entry says so in `integration_ready: false`. What Production Engineering would have to decide before landmarks become production: whether a landmark is a chamber property, a shell feature or a standalone placement; what reserves its footprint against the mandatory path; and whether it is Epsilon-selectable. Art is not guessing any of those. | `batch023/landmarks/*`, and every authored asset built so far |
| 25 | **Epsilon has a voice but no presentation state.** Audited read-only against `claude/archipepsi-echoes-continuation-b1adno`. `godot/scripts/ui/epsilon_voice.gd` is the only Epsilon presentation code in the project, and it is a BARK SELECTOR: 18 event kinds, a PRIORITY order, a 6 s cooldown, a 4 s dwell, a 42 s hub idle interval. It answers *what Epsilon says*; it does not answer *what the installation looks like while it says it*. There is no presentation-state enum, no visual-state signal, and no binding from a bark to any material. | Of Batch 024's six proposed states, **exactly one is bindable today**: `speaking`, from `EpsilonVoice.tick()` holding a line for DWELL seconds. `thinking`, `interpretation OK` and `error / refusal` all exist BRIDGE-side (`epsilon/requests.py`, `epsilon/fallback.py`) and are never surfaced to the scene. `dormant` is derivable as the absence of the others. `player attention / focus` does not exist in any form -- there is no look-at or proximity test against the installation. What Production would have to decide: whether the scene gets a single Epsilon presentation-state signal, or whether each state binds separately. Art is not guessing. | `batch024/epsilon/*` |
| 26 | **The Forge has no Hub anchor, and no existence in Production at all.** `hub_anchors.gd` `REQUIRED` lists eight anchors -- `main_portal`, `epsilon_presence`, `shop` (QUESTIONABLE GOODS), `archive_loadout`, `lab_entrance`, `progression_display`, `postgame`, `generation_loading` -- and no forge. There is no Forge scene, script or constant either; its only mention anywhere in Production is `docs/design-packet-v0.10/RESEARCH_MEMO.md` section 7, an open design question. | Batch 025's `forge_bench` is therefore proposal scale with no placement claim. **Questionable Goods is the opposite case and is authored to its real contract**: `shop` at (-9.4, 0, 2.4), 3.0 m of wall run centred on z = 2.4, clearing the Lab doorway (z 4.5-7.5) by 0.6 m -- a clearance the builder asserts, because the anchor's own comment records that overlapping it made the Lab unreachable in playtest 1. What Production would have to decide for a Forge: whether it is a Hub station at all, and if so where. The left wall is already carrying Epsilon's bay, the shop and the Lab doorway, so the anchor is not a free choice and art is not making it. | `batch025/forge/*` |
| 27 | **There is no checkpoint entity, and no way to say WHICH station is current.** `godot/scripts/gameplay/player.gd` carries `var _spawn_transform: Transform3D` and `func set_spawn(xform: Transform3D)`, with `RESPAWN_DELAY = 1.5` and a HUD SIGNAL LOST overlay. That is one slot holding one transform, with **no identity**: no checkpoint entity, no checkpoint state, and nothing anywhere that records which station the player would return to. | Of Batch 026's three proposed states -- inactive, activated, current re-entry anchor -- **zero have a runtime representation.** `set_spawn()` is the seam a station would call, and it would need to carry an id before "current re-entry anchor" could be a thing the world is able to show; with one identity-less transform, every activated station looks the same to the runtime. What Production would have to decide: whether stations are entities with ids, and whether the current one is distinguished at all. Art is not guessing, and no spawn, healing, fast-travel or save rule is proposed here. | `batch026/checkpoint/*` |
| 28 | **Health and ammo are not things in this game yet, and the loot catalog is sealed.** Of Batch 027's five pickups, two are backed by a real Production item -- `ITEM_NAME_EPSILON_COIN` (`EPSILON_COIN_COUNT = 10`) and `ITEM_NAME_EPSILON_STATIC` (18). **Health and a generic combat resource are backed by nothing at all**: no item name, no constant, no entity, no mention. `LOW_HEALTH_FRACTION = 0.33` establishes that the player HAS health; nothing establishes that health is a thing you pick up. | And `godot/scripts/gameplay/local_reward.gd` carries a CLOSED catalog -- `epsilon_note`, `challenge_marker`, `cosmetic_grant`, `hub_decoration`, `lab_fixture`, `flavor_log` -- with the reason in its own comment: the client must not be able to invent a seventh kind. **None of the six is a container**, so a secret cache is not a kind art may add. What Production would have to decide: whether health and a combat resource exist as pickups at all, and whether the loot catalog gains a container kind. This is a design question before it is an art one; the five are built because the brief asked for five, and each records in its manifest whether a real item backs it. | `batch027/pickups/*` |
| 29 | **The interactable contract exists, and its state vocabulary is the AP Check's.** `godot/scripts/content/interactable_contract.gd` publishes `STATES := ["locked", "available", "sending", "confirmed"]`, `IDENTITY_VISIBLE_IN = "confirmed"`, a `leak()` anti-spoiler check, and `REQUIRED_PARTS := {state_visual: MeshInstance3D, state_label: Label3D}`. That is a contract about an AP moment, not about interaction in general. | **None of Batch 028's nine primitives fits those four states** -- a weight button, a door ram, a fuse indicator and a breakable panel are not `sending`. So the nine have no runtime state vocabulary at all. **`REQUIRED_PARTS` is real, though, and the kit is authored to it**: every primitive carries one identifiable `state_visual` region and reserves a place for a `state_label`, which is why the proposed grammar is 'the plate is the state, everything else is the verb'. What Production would have to decide: whether interaction primitives get their own state vocabulary, or whether each primitive declares its own. Art is not guessing, and no mechanic is designed. | `batch028/interaction/*` |
| 30 | **A secret has a socket and a score, but no appearance and no difficulty.** This is the batch with the MOST existing contract, not the least. `schemas/content.py` already has `"secret"` as a Socket `kind` alongside doorway / corridor_end / affordance / spawn / objective / vista / presentation, carrying a `position` and a `yaw`; `content_value.SECRET_VALUE = 8` scores each authored secret as "optional, findable, and the reason to look around"; and `secret_ping` already exists as an Echo readout. | So a shell can declare WHERE a secret is today. **What is missing is what one LOOKS like**: no cue vocabulary, no difficulty grading, and no way for a shell to say "this is a learning-tier cue" so a Zone can teach before it tests. Note the `secret_ping` finding matters to art directly -- the game can already TELL a player where a secret is, so the visual language has to be the primary channel and the ping an Echo-granted assist. A cue that only works once you hold the right Echo is not a cue. What Production would have to decide: whether a secret socket can carry a cue kind and a tier. Art is not guessing, and nothing here decides what a secret contains, how it opens or what it is worth. | `batch029/secrets/*` |
| 31 | **Seven of the ten enemy roles have a body, a collider and a telegraph seat -- and no way to be spawned.** `Constants.ENEMY_ARCHETYPES` is still `("melee", "ranged", "brute")`, and its own neighbour comment is explicit that this is deliberate: *"THIS IS NOT THE LIST OF ENEMIES A ZONE MAY CONTAIN. It is the list of roles that have an agreed physical envelope. `ENEMY_ARCHETYPES` is the placeable set, and it is smaller."* | Batch 030 builds all ten to their published envelopes and asserts the fit, so charger, bulwark, scuttler, artillery, beacon, diver and drifter are art-complete against the contract that exists. What they lack is placement: no Zone can contain one. What Production would have to decide: which roles graduate into `ENEMY_ARCHETYPES`, and what each needs before it can (stats, behaviour, a telegraph kind). **Art is not asking for behaviour and has invented none.** | `batch030/enemies/*` |
| 32 | **The viewmodel cannot express an Echo's FAMILY, so a reforge is invisible.** `player.gd` builds `$Camera3D/Viewmodel` with named `Device`, `Tip`, `EchoPart` and `EchoTip` children, and `EchoRuntime._refresh_viewmodel_attachment()` paints `EchoPart` with `source_color()` (the world the Echo came FROM) and `EchoTip` with the slot. Both channels are correct and neither changes on a reforge -- same source item, same button. | So a player who spends scarce Epsilon Coins to reinterpret a ranged Echo into a grapple sees **an identical viewmodel**. The one operation the Forge exists to perform is invisible in the view the player looks at all game. The ask is narrow and is NOT hundreds of Echo weapons, and after the 2026-08-29 owner review it is narrower still: **the Echo family must be visible through a swappable / composable `EchoPart` seam.** That is the whole requirement. It is explicitly **not** "build exactly seven fixed `EchoPart` models" -- the owner's ruling on Batch 032 is that the three forms built there **prove the attachment seam and nothing more**, and are not approval of a seven-fixed-forms system. Colour keeps source, the tip keeps slot, and form carries family through whatever occupies the seam. **Art must not expand those three into seven production family models.** The 2026-08-29 review enumerates what proof-of-seam is explicitly *not* approval of: seven fixed family models, a final attachment grammar, a final part taxonomy, runtime composition rules, family silhouette rules, or provenance / source influence rules. All of those are specified by a future owner-authored brief for the **modular Echo visual construction / kitbash system**. **Do not begin designing or mass-producing Echo visual parts.** | `batch032/viewmodel/*` |
| 33 | **The Zone exit has a boolean where it needs a state, and its locked colour is in the hazard channel.** `exit_portal.gd` is already the Zone exit -- a themed frame, a recoloured core and a `Label3D` -- with the hook `set_unlocked(value: bool, checks_remaining: int)`. The redesigned lifecycle wants four states (present-not-ready, ready, return-available, cleared) and a boolean cannot carry four. | **Art recommends building no new portal**: the vocabulary exists, is correctly scaled, and is contextually separated from the two Hub portals. Two things are Production's to fix in their own file: the four-state signal, and the locked core's `Color(0.4, 0.2, 0.2)` -- a dark red, in the family whose definition is *"this will hurt you. Never used decoratively, in any theme, for any reason."* A locked exit is not a hazard; it is `dead` (*"unpowered, LOCKED, spent, offline"*). One art note: the `StateLabel` is currently doing all the work, and if four states land the FRAME is where the difference should live. | `review/batch033/README.md` |
| 34 | **The affordance language says "a capability could be used here" and cannot say "you lack it".** The 2026-08-28 owner ruling gives every optional traversal affordance one colour (`AFFORDANCE_SIGNAL_HEX`, art's own `signal` anchor) with FORM carrying which and COLOUR carrying opportunity -- and all seven contracted families (`grapple_anchor`, `breakable_wall`, `rail`, `bounce_pad`, `moving_platform`, `wind_volume`, `water_volume`) are therefore readable in all six themes and unconfusable with decoration. | Two gaps for hard gates. (1) **No "you lack this" state exists** -- `AFFORDANCE_DYNAMIC_CHANNELS` carries breakable damage and wind ring count, and neither is acquisition. (2) **Form carries family only at close range**; at the distance a gate is first seen, a grapple anchor and a rail terminus are both "a cyan thing on a structure". Batch 034 proposes solving the READ without a new channel: build the gate as finished infrastructure missing exactly one thing, because **broken is ragged and installed is neat**. Blink/teleport gets a proposal only and no production asset, since it has no mechanical contract. | `batch034/gates/*` |
| 35 | **Authored CORRIDOR and PATH shells cannot be exposed without changing Zone topology.** `_from_authored_scene` takes one fixed `size` per entry; `ChamberBuilders.corridor` reads the generator's PER-CHAMBER `length` and `width` and raises height for affordance features. A procedural corridor is 6-30 m long and 3.6 m high; the authored ones are a fixed 14.0-20.0 m and 4.5-5.9 m. | Exposing them changes room chaining, Check positions and enemy positions -- a different **level id**, which is the one thing the A/B exists to hold still. The eight dimensionless shells are the case that does NOT have this problem, which is why they are the ones retrofitted. What Production would have to decide: whether an authored shell can declare a size RANGE, or whether the generator can be asked for a chamber that fits an authored one. | every batch015 and batch017 shell |
| 36 | **Activity elements are tinted `ThemeMaterials.light_color(theme)`.** In `neon_transit` -- Zone 1's theme -- that lands **0.17** from `CHECK_SIGNAL` against a `MIN_LAYER_SEPARATION` of **0.45**. | The Check's signal colour is the one thing in the game that means *this is an Archipelago location*. An activity element wearing a near-identical hue in the theme the player sees first is the layer separation rule being broken by the runtime rather than by an asset. Recorded read-only; art changed nothing. | every activity element in `neon_transit` |
| 37 | ~~**`ShellValidator._check_envelope` cannot contain a boundary wall.**~~ **CLOSED at Production `eda4fd9`.** Its envelope started at z = 0 with 0.15 m of slack; authored shells put the entry wall at [-0.4, 0] and procedural rooms centre it on z = 0, so it refused all eight P2 shells and would have refused a procedural room had it ever been applied to one. | Production replaced both private opinions with one shared `RoomContract.WALL_ALLOWANCE` -- a wall thickness plus the old tolerance, because a room's boundary wall belongs to the room -- pointed `RoomAudit` at every mesh rather than only furniture-scale ones, and had `ShellValidator` delegate to the same rule. Zero envelope violations across the eight. `preflight_shells.py` now READS that constant from the ref instead of assuming 0.15, and agrees. | all eight P2 shells |
| 38 | ~~**A two-tier plinth cannot declare both tiers walkable**, and three shipped shells do.~~ **CLOSED by Art at the source.** Production's C(ii) ruling settled what a Surface promises -- one findable placement, not a clear rect -- and `step_low` still had ZERO. The plinth is right and is untouched, mesh and collision both; the DECLARATION was wrong. `step_low` is no longer a stand Surface, the two 0.40 m rises become the one 0.80 m rise a player actually makes, and the mass stays declared as the `plinth` no_build volume, which is what a pedestal step is to a composer. | The riser is legitimate architecture and well inside `MAX_VERTICAL_STEP`; nothing was widened and no collision was invented to manufacture standing room. | `shell_treasure_vault`, `shell_treasure_cache`, `shell_treasure_coffer` |
| 39 | ~~**The towers climb on 1.00 m footholds, and a `Surface` says "stand here".**~~ **CLOSED from both ends.** Production answered the vocabulary question generically at `1648fa9` -- a Surface offers one findable placement, so a rung under the next rung is ordinary architecture and 40 of the 47 stopped being findings. The three that remained were real: collapsed `rubble_1_0` and `rubble_1_1` and spiral `platform_6` had nowhere at all, each because the top deck sat 0.5 m thick directly over them. | Repaired at the source by `_deck_well`: the deck stops short of the column the climb comes up, derived from the same `stones` and `heights` that become the Surfaces. The spiral's helix is the ENGINE's and was not touched; the collapsed tower's alternating half-floors were not touched; a deck that opens over a stairwell is what both shells wanted anyway. | all three `shell_tower_*` |
| 5 | **A larger footprint, or an L2 placement path, for composed clusters.** `PROP_FOOTPRINT` is 1.4 m. | Right for L0, too small for an L2 station or storytelling cluster. | `cluster_*` |
| 6 | **`challenge_marker` world semantics** (`AGENT_FRONTIER.md` still lists this open). | Its visual cannot be specified until its meaning is. | `local_reward_pickup` |

### Req 40 — the traversal contract disagrees with itself (OPEN, Production's)

**`ShellValidator._check_segment` does not read `kind`.** It applies
`Constants.MAX_VERTICAL_STEP` and `Constants.max_safe_gap` to EVERY
mandatory traversal segment. `schemas/content.py`'s `TraversalSegment`
tests `self.kind` and bounds only `rise` and `gap`; `walk` (continuous
ground) and `drop` are deliberately unbounded there.

P2 could not see it: every mandatory segment in the eight was a 1.00 m
`rise`, inside both readings. `shell_hall_transit` is refused on four
segments, the clearest being `ring_n_to_ring_e` — **3.20 m, flat**, along
a continuous walkable collar, refused because 3.20 > `max_safe_gap(0)` =
2.60. There is floor under every centimetre of it.

**This blocks vertical circulation in any LARGE room, not just this one.**
A 28 m climb is `walk` if it is ramps and 28+ segments if it is 1 m steps,
against a schema cap of 32. There is no honest third declaration.

Art has NOT changed the shell to route around it. The route is declared
as what it is; `tools/verify_content_pack.sh` stage 4 runs Production's
own `ShellValidator` on the shipped scenes and prints every refusal,
marked `[walk/drop]`, on every run. Art's own side of the claim is checked
at build time by `_assert_walk_ground` in `build_hall.py`: continuous
collider structure under the whole chord of every mandatory `walk`, at a
height between its two ends, so a wall does not count. Which half of the
contract is authoritative is Production's decision. See L-87.

**Do not edit gameplay logic to make an asset convenient. Do not alter a
mechanical dimension to make an asset prettier.** Collision and traversal
truth remain Godot's.

---

## LARGE ROOM LIBRARY — Wave 1 (2026-09-02, PENDING)

The owner approved the ten-room slate (`docs/art/LARGE_ROOM_SLATE.md`)
and the 3 / 4 / 3 wave plan. **Wave 1 is built and pending; Wave 2 does
NOT start on a wake-up.**

| shell | interior | tris | rail | launch | type / class |
| --- | --- | --- | --- | --- | --- |
| `shell_plenum_helix` | 20 x 72 x 20 | 1320 | **129.4 m** | 28.1 m | `tower` / large |
| `shell_yard_gantry` | 84 x 16 x 52 | 444 | 72.0 m | **63.1 m** | `arena` / large |
| `shell_span_basin` | 30 x 22 x 90 | 544 | 82.9 m | 22.5 m | `arena` / large |

Wave 1 was chosen to stress PROPORTION, not to be the three best ideas:
1 : 3.6 tall, 5.3 : 1 wide, 3 : 1 long. If LARGE only worked at the
hall's proportions it would have cost three rooms to find out.

**`_SIZE_CLASS` is per ENTRY now, not per family.** `shell_plenum_helix`
is a `tower` and it is LARGE while the three P2 towers are medium; a
family-keyed table would have shipped a 72 m shaft labelled the same size
as a 15 m one.

**Shared tooling landed with the repair**: `roomkit` (the axis
convention, a deck by its edges, and `flight()`), and `traversallaw.py`,
which mirrors Production's walk flood over the collision hulls and gates
every export.

## Req 40 — CLOSED at Production `b37fe07`

`ShellValidator` no longer applies jump bounds to a `walk`. `TraversalLaw`
holds each kind to what it claims and proves a walk by a bounded physical
flood over the geometry. **The declared rectangles bound the search and
prove nothing** -- so a climb costs zero declared Surfaces, and Art's
"one Surface per metre" conclusion from the intermediate rule at
`93ddc60` is retracted. See L-90.

---

## P3 — the first LARGE authored room (2026-09-02, PENDING)

`shell_hall_transit`, a vertical transit hall. **ONE shell. Not a family,
not a batch, and it does not promote itself.**

| | |
| --- | --- |
| source | `tools/blender/build_hall.py` -> `batch039/shells` |
| contract | Production's movement seam at `af620d8` |
| type / class | `arena` (tags `transit`, `vertical`) / `large` |
| size | 40 W x 38 H x 60 D m, ~91,000 m3 (vs `shell_tower_gantry` at 2,160) |
| budget | 552 tris, 32.0 texels/m, 41 convex colliders |
| contract data | 14 surfaces, 13 traversal, 10 sockets, 3 volumes, **3 offers** |
| review | **`pending`.** `verify_pack.gd` asserts the pack does NOT ship it. |
| package | `docs/art/review/p3_owner/` — 8 views, 6 overlays, README |

**The exporter now carries review state PER ENTRY.** `SHELL_REVIEW` was a
single constant while every shell shared one verdict; it is a dict keyed
by content id now, so a new shell cannot inherit somebody else's approval
by being added to a table.

**Offers, and what Art did not author.** `OFFER_KINDS` is closed at
`rail_route`, `launch_source`, `launch_target`; `grapple_anchor`,
`platform_route` and `wind_column` are Production's named next arrivals
and no grammar was invented for them. The hall declares `rail_helix`
(11 points, 143.9 m, twice around the landmark, every segment inside
`RailPath`'s 0.5-60 m and 75-degree bounds, asserted at build time) and
the pair `launch_basin` -> `launch_gantry` (24.5 m, inside
`LaunchSolver`'s 0.5-80 m, target radius 3.5 over its 2.5 m minimum).
**No velocity, direction or arc anywhere** — the review overlay draws the
two pads and deliberately nothing between them.

**The sightline is asserted, not hoped for.** `_assert_sightline` walks
400 samples from the entry eye to the top of the exit portal, 64.7 m
away, against every collider. That is why the landmark is a frame — four
columns and three collar rings around a 12 m open shaft — rather than a
solid core: the one thing the player must see from the door sits exactly
where a solid core would be.

**Nothing falls forever.** The basin is one continuous floor at y=0 under
the entire hall, shaft included. A missed rail or launch costs height and
a walk back, never the level. No enemies placed, no encounter authored,
no checkpoint or respawn behaviour, no rail mesh in the shell.

**The eight P2 shells were not touched.** `diff_shell_glb.py` reports all
nineteen shell GLBs byte-identical.

**Two new verification stages** came out of this and stay — though both
have since been replaced, and the replacements are what runs now:

  * `verify_content_pack.sh` stage 4 ran Production's own `ShellValidator`
    against the shipped scenes. `b37fe07` rewrote `shell_validator.gd` and
    the mechanical transform no longer reached; the stage is retired, and
    stage 4 is now `tools/content/verify_markers.py`, which holds every
    scene's `Marker3D` origins against the manifest declaration they came
    from. See L-93.
  * `_assert_walk_ground` proved Art's `walk` declarations at build time by
    testing the chord between endpoints. It was wrong for the same reason
    the deleted third check was wrong — **the chord is not the route; the
    flood goes around** — and it is gone. `tools/blender/traversallaw.py`
    replaced it: a source-side mirror of Production's `b37fe07` bounded
    physical flood, run as a build gate. See L-88 and L-92.

A third check was written, fired on seven of the eight certified P2
shells, was found to be measuring the chord between edge-declared
endpoints rather than the path, and was deleted rather than tuned. See
L-88. Req 40 is CLOSED: `b37fe07` is Production's answer to it.

---

## P2 IS COMPLETE — all eight shells PASS (owner, 2026-09-02)

> ### THE AUTHORED ROOM LIBRARY HAS ITS FIRST EIGHT MEMBERS.

Both gates are cleared. Production certified the eight physically at
`6640d86` — room contract satisfied, **zero findings** — and the owner
then reviewed the actual P2 form from `docs/art/review/p2_owner/` (36
frames) and **approved all eight**:

| family | shells |
| --- | --- |
| corridor (corner-shaped) | `shell_corner_left`, `shell_corner_right` |
| treasure_room | `shell_treasure_vault`, `_cache`, `_coffer` |
| tower | `shell_tower_collapsed`, `_spiral`, `_gantry` |

They export `review: "pass"` from `SHELL_REVIEW` in
`tools/export_content_pack.py`, which is the art source of truth for that
switch. `is_shippable()` no longer refuses them.

**What was approved is spatial FORM** — identity, scale, route and read,
composition usefulness, and the collapsed/spiral deck-well repairs. It is
**not** a claim that dressing is finished. Three non-blocking notes stand,
and none of them is a reason to reopen a shell:

- the collapsed and spiral deck wells may later receive lip / frame /
  railing / support language during dressing;
- `shell_tower_gantry`'s `landing_4`/deck coplanar z-fight is cleanup, not
  a shell defect — it is pre-existing F3 geometry (see the P2 review
  package README);
- `shell_treasure_vault`'s "protected" identity should be strengthened
  with props, barriers, sound and lighting **rather than shell redesign**.

**Still Production's to wire.** Approval opens the seam; it does not use
it. `SHELL_FOR_TYPE` still names the `_proc` ids, so nothing appears in a
Zone until Production points it at the authored ids.

Two shells carry an intentional visible P2 repair (`shell_tower_collapsed`
and `shell_tower_spiral`, the deck well); the other six are byte-identical
to their F3 build, proven at the glTF accessor level and again by
re-rendering the F3 shot list.

**The bench was photographing the colliders.** `ArtBench.load_glb` is a
raw glTF load, not Godot's importer, so the `-convcolonly` twins P2-C
added rendered as untextured white duplicates on top of the real geometry
— every shell frame since P2-C was wrong. Fixed in `artbench.gd`; the F3
captures now reproduce byte-identical. See L-86.

## Known gaps, stated plainly

- **The three treasure rooms declare a surface a player cannot stand on,
  and it is ours.** `_plinth` builds two concentric steps — 3.0 m square
  with its top at 0.40, and 2.2 m square with its top at 0.80 — and the
  P2 retrofit declared BOTH as walkable `Surface`s. The upper step stands
  on the lower one, so what is left of `step_low` is a **0.40 m ring**
  against a player 0.80 m wide: half a capsule. Measured, not inferred —
  with collision present, all nine of `step_low`'s audit samples measure
  0.80 where 0.40 is declared, in `shell_treasure_vault`, `_cache` and
  `_coffer` alike.
  **The plinth is not wrong; the claim about it is.** The geometry is the
  owner-approved F3 shape and `reward_position` is the engine's, so
  nothing was remodelled and nothing was quietly deleted. The surface
  minimum in `roomcontract.surface` did not catch it because it measures
  the declared rectangle (3.0 ≥ 0.8, fine) and not the part of it left
  uncovered by whatever sits on top. See req 38.
- **The towers' climb is footholds, and a `Surface` says "stand here".**
  The P2 preflight PREDICTED 47 headroom notes; with collision authored,
  the engine MEASURES exactly 47 — 27 in `shell_tower_collapsed`, 15 in
  `shell_tower_spiral`, 2 in `shell_tower_gantry`, 1 in each treasure
  room. The tightest are 0.50–0.60 m against a 2.40 m requirement. The
  geometry is right: `STEP` is 1.00 m and `routecheck.assert_reachable`
  validated the whole chain at that spacing, so a slab 1.00 m under the
  next one is the climb working as designed. What is wrong is calling
  every rung a place a player stands. See req 39.
- **void_glitch may be too loud.** The in-engine probe is the evidence. My
  read: the floor works, the walls and ceiling at full-saturation magenta do
  not. Flagged in `ART_REVIEW.md` with a proposed fix; the owner decides.
- **Nothing is rigged or animated.** A telegraph is a promise
  (`AUTHORED_CONTENT.md`), and a promise cannot be judged from a static
  model. This is the next large question after style approval — not before.
- ~~**Three themes are unbuilt.**~~ Built in Batch 012; all six families
  now build, and each has an in-engine probe room.
- ~~**Only `concrete_facility` has a room shot.**~~ All six themes now have
  an in-engine probe room and a greyscale of it.
- **The review sheets are Compatibility-renderer captures**, so every one is
  a lower bound on the owner's Forward+ build.
- **`prop_*` reads blue in `concrete_facility`**, because props paint from
  the theme accent and that accent is `#4f6f8f` in `THEME_MATERIALS`. A
  faithful consequence of engine truth, flagged in `ART_REVIEW.md` because
  it is the most likely thing to feel wrong on sight.

---

## After approval — the order, when the gate opens

Not before. Written down so the first post-approval heartbeat does not have
to decide it.

1. Fold the owner's 001-R notes into `ART_BIBLE.md` and `ART_LESSONS.md`.
2. Finish the selected concepts; the kept alternatives stay in the repo.
3. Complete the remaining three theme material families.
4. Complete the architecture kit (§6 of `ASSET_INVENTORY.md`).
5. Room shells (§7) — the level that stops Epsilon obviously repeating one
   room.
6. Remaining enemy archetypes and their telegraphs, which is where rigging
   becomes unavoidable.
7. The remaining six affordance fixtures.
8. Hub and Echo Lab — last, because they are the largest and the least
   forgiving, and because everything else teaches us how to build them.
