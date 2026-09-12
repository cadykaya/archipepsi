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

## CURRENT STATE — 2026-09-04

Read this before any section below. Where an older section disagrees, it
is history and this is the state.

1. **All twelve authored room shells are `review: "pass"`.** Nothing in
   the content pack is `pending` except the three projectile
   substitutions.
2. **Hall, Plenum, Yard and Span were promoted by the owner on
   2026-09-04**, after Production's technical certification at
   **`7e13f44`** and the independent audit at **`f97545f`**. Promotion
   commit `ab74f5e`.
3. **Wave 1 is COMPLETE. Wave 2 has NOT started** and requires its own
   owner brief. The Wave 1 verdict is a promotion, not an instruction to
   continue.
4. **Req 40 is RESOLVED.** `ShellValidator` is kind-aware through
   `TraversalLaw`; it no longer applies jump bounds to continuous walks
   or to ramps. Implemented before the promotion, so no room in the
   library is refused by it. The "OPEN" section further down is
   superseded history.
5. **`launch_source.radius` is RESOLVED**, settled at Production
   `833fe80` and guarded at `7e13f44`:
   * `launch_source.position` is the exact foot-contact launch origin;
   * `launch_source.radius` reserves space for the constructed pad;
   * it is **not** a disc of possible ballistic origins.
   All four large-room pads are correct as authored. Art's earlier
   question about the disc reading is answered and closed.
6. **The plenum collar convex-disc defect is RESOLVED.** Each collar is
   decomposed into twelve convex ring sectors, the holes are physically
   open, and the independent audit verified the decomposition.
7. **The one remaining milestone is Production's, and it is
   intentional: the player-facing movement-package consumer.** Shell
   promotion does not implement rails, launches or grapples in ordinary
   gameplay. A passing shell can be placed, entered and walked end to end
   today with nothing installed; the offers it carries are reservations.

8. **Theme Pack: prepared and proved, not built.** Since 2026-09-10 the
   role contract is reconciled against the authority draft, all 597
   shipped material slots classify, and one shipped room has been shown
   wearing two themes at once by per-surface override. What remains is
   **Production's**: a `hazard` ruling, the material-mode and
   `protected_materials` fields, somewhere for the six-theme texture set
   to ship, and the binder. See the Batch 041 section below.

9. **FRONTIER, 2026-09-13 — where this lane actually is.** Report:
   `docs/art/reports/2026-09-13-presentation-study.md`. Production read at
   `claude/archipepsi-echoes-continuation-b1adno` `05dd5d6`.

   * **Batch 044's three branching rooms are PROPOSALS.** Nothing is
     approved and nothing is promoted. `shell_junction_cross` has had the
     presentation pass; the triad and the terminus have **not**, and their
     surfaces carry the same defect the cross's did — the block painted in
     the room's architecture material, so it reads as corridor wall.
     **That is the next Art task.**
   * **The theme pack BINDS, proved against the real exported files**, by
     a reference binder that is a proposal and is **not wired into the
     game**: `tools/content/theme_binder.gd`, interrogated by
     `tools/content/theme_bind_proof.gd`, gated in `check_art_current.sh`.
     Three controls — a missing required texture, a wrong-pixels file, a
     missing optional one — move real files aside and put them back.
   * **The yard's two doorways are REFUSED by Production's current
     manifest rule** and are not repaired. They sit 0.395 m past the
     shell's declared 85.20 m size; `shells.doorways_off_the_body` allows
     0.005 m of rounding, not the 0.405 m this lane's gate used to carry.
     The gate now carries 0.005. **The repair is one line and needs Prod's
     and the owner's word**, because it rewrites an approved manifest.
   * **Production reads sockets by kind and by NAME now**, so a three- or
     four-connection room is readable — the blocker the Batch 044 handoff
     named is theirs, and gone. **A four-connection asset is still not a
     four-neighbour room in a generated Zone.**
   * **Span is closed on completion, not on walkability.** Sixteen jumps,
     one per riser. The capsule limits (0.12 m step, 1.50 m jump, 46°
     ramps) are a measurement of the shipped constants by one harness —
     **not** a rule forbidding slopes or vertical rooms, and **not** a
     licence to raise `MAX_VERTICAL_STEP`.

**There is no Art-side blocker.** The lane is idle by intent, not by
obstruction.

### Theme Pack PREPARATION — done 2026-09-10. The infrastructure is NOT.

Inspection, baselines and documentation only, against art `7ecd3fe` and
Production `2f727a7`. **No ThemePack schema, compiler or runtime binder
exists, and none was built.** Report:
`docs/art/reports/2026-09-10-theme-pack-preparation.md`; baselines in
`docs/art/review/theme_baseline_2026-09-10/`.

What it established:

* **The theme is baked at Blender export.** Eleven shells hard-code
  `THEME = "concrete_facility"` and the plenum `"rusted_industrial"`, so a
  second theme of a room means a second `.glb` today.
* **But every slot is classifiable.** 597 of 597 material names across the
  twelve approved shells parse as `<prefix>_<role>` with a texture, and
  `ComposedRoom._retheme` already performs the swap in Godot — for
  procedural modules. The gap is a checked convention, a shipped texture
  set and a runtime path, not a rebuild.
* **The six-theme texture set (37 PNG) ships nowhere**; its only consumer
  is the preview tool.
* **Nine agency primitives exist and ship nowhere** — no seam. Their state
  plate survives export as a material slot rather than an addressable node.
* **Three of six themes share a value structure** (concrete, neon, gothic).

`ARCHIPEPSI_THEME_PACK_SYSTEM_AUTHORITY_20260903.txt` was **not available
when the preparation report was written**, so it made no contract
comparison. The document arrived later the same day; the reconciliation is
Batch 041, below.

### Batch 041 — DONE 2026-09-10. Still a preview proof, not infrastructure.

Against art `a2b6d59` and Production `2f727a7` (read-only, not merged).
Report: `docs/art/reports/2026-09-10-batch041-two-themes.md`; evidence in
`docs/art/review/theme_baseline_2026-09-10/`.

* **The role contract is reconciled and mirrored in the tool.**
  `inspect_materials.py` now carries §8.1's five required roles and §8.2's
  five optional roles with their fallbacks, verbatim. `trim_plain` and
  `wall_ribbed` stay **Art texture variants, not roles**.
* **All 597 shipped material names classify; none is guessed.** Zero
  canonical, 597 legacy, 0 unknown, 0 refused — the mapping is
  `role_map.json`, tied to each `.glb`'s git blob id. `--selftest` drives
  ten probes through the classifier, including the refusals.
* **Godot preserves every name exactly** — 597 surfaces, 597 named, 0
  blank, same order as the glTF in all twelve. The role is recoverable at
  runtime with no manifest field.
* **One shipped room wears two themes at once**, by per-surface override:
  the shared mesh never changes, a third-theme rebind of A leaves B
  untouched, and the collision digest (10 bodies, 10 shapes, 22 nodes,
  instance-local transforms) is identical before and after.
* **No asset was rebuilt.** Twelve shells byte-identical; no schema,
  manifest, runtime or review change.

**REMAINING PRODUCTION DEPENDENCY — the Theme Pack cannot proceed on Art
alone.** Four things are Production's, and every one of them blocks a
shipped binder:

1. **A `hazard` ruling.** §8.1 makes it a required per-theme role; the art
   lane's standing rule is that hazard is a *universal* colour no theme may
   re-tint, and no theme has a hazard texture. Production decides whether
   `hazard` resolves to the universal ramp for every pack.
2. **Material-mode and `protected_materials` fields.** §8.3 and §8.4
   require every asset to declare `themed`/`hybrid`/`authored` and to list
   hero materials. Neither field exists in the registry entry schema, and
   Art was told not to add one.
3. **Where the six-theme texture set lands.** 37 PNG ship nowhere; a
   binder cannot bind textures the game does not have.
4. **The binder itself** — §8.5's walk, per-surface override, unresolved
   reporting, and the "complete before the first visible frame"
   guarantee.

**HAZARD IS SETTLED (owner, 2026-09-10).** Every pack must **resolve** the
`hazard` role, but may resolve it to the **same shared universal material**.
Separate theme-coloured hazard textures are **not required**, and none was
painted. G1 above is answered; it was the one gap that looked like a
collision with the art lane's own rule and it is not one.

### ECMS Glyph PR #3 — stood down, and the watcher is deleted (2026-09-11)

`cadykaya/ECMS-GLYPH` PR #3, branch `claude/archipepsi-glyph-tooling`, head
`6c80b63`, base `main` at `727129e`. **Open, draft, and finished from this
lane's side.** Do not re-arm a check-in on it.

* The only red check is `Build, test, conformance` on **`GLA-PRF-001`** —
  *"expected 108.08 to be less than or equal to 100"*. It is red on `main`
  at `727129e` too, `HANDOFF.md` documents it as deterministic (read from a
  stored measurement, so a re-run cannot move it), and **no fix exists to
  port**. 337 passed / 1 failed on both heads, identical figure. The other
  three checks are green. `mergeable_state` "unstable" means CI red with
  **no merge conflict**.
* The failure was **not weakened, relabelled or worked around**, per the
  owner's standing instruction. The stand-down comment is posted on the PR
  and both comments there are this lane's.
* **Six consecutive quiet checks** with `updated_at` frozen at
  2026-09-10T18:11:12Z. The Batch 043 brief then said *"No recurring
  check-ins, PR watchers or heartbeat tasks"*, so the routine
  (`trig_017uJk2bXe2vzD8HjXnmQGEP`) was **deleted rather than re-armed**.
* Batch 043 used Glyph at `6c80b63` and **changed nothing in it**. Two
  limitations were met and worked around with the established art tools
  rather than by extending Glyph mid-batch: a project holds one variant, so
  a 70-asset kit is 70 project files; and `easel.study` composites a view
  over a ground but cannot composite two Glyph documents, so every composed
  marker is authored as its own document instead.

### ECMS Glyph — available, run, and one texture through it (2026-09-10)

Report: `docs/art/reports/2026-09-10-glyph-first-texture.md`. Package:
`docs/art/review/glyph_trial_2026-09-10/`.

**CORRECTION.** An earlier reconnaissance in this lane inspected
`cadykaya/ECMS-GLYPH` at `0cf872d` and recorded that Glyph *"is a
specification, not a program"*. That was true of the revision fetched and
**false about the project**: `0cf872d` is the frozen authority snapshot, and
the implementation merged to `main` at **`727129e1`**. Glyph exists, builds
and runs.

* `npm ci` exit 0, `npm run build` clean, `node tools/first-edit.mjs`
  produced a project and a PNG, and the container reopens — checked twice,
  once by the script and once through `glyph describe` / `glyph log` on the
  closed file. Node v22.22.2 against the documented `>=22.5.0`.
* **One 128 × 128 `concrete_facility` wall authored through it**, on the
  house palette and the house structural vocabulary, in a dedicated project
  with **Skyiah as Lead Owner and Arty as the agent artist** — both
  identities recorded, neither replacing the other. Six revisions, 936 ms,
  byte-identical on re-run.
* Inspected native, at 8×, tiled 3 × 3, beside the shipped painter, and **on
  real room geometry through Batch 041's per-surface override path** — 0
  unresolved surfaces.
* **It ships nowhere.** `assets/textures/theme/concrete_facility_wall.png`
  is unchanged and no approved asset was touched.

### Theme-pack gap 2 CLOSED on the Art side (2026-09-11)

Report: `docs/art/reports/2026-09-11-theme-role-gate.md`. Tooling and
documentation only; every `.glb` byte-identical.

The role convention is now **declared and enforced** by
`tools/content/check_theme_roles.py`, running inside
`tools/check_art_current.sh`. Two findings got it there:

* **There are 23 shells on disk and the Batch 041 role map covered 12.** The
  eleven arena / corridor / path shells of Batches 015–019 were approved
  vocabulary that nothing had ever classified. They follow the same
  `<prefix>_<role>` convention; each prefix was read from the shell's own
  exported names and is now declared. The role map grows from **597 slots
  across 12** to **894 across 23**, still 0 unknown and 0 refused.
* **Nothing checked the themes at all.** The gate now also asserts that every
  role a shell uses exists in every theme, that an optional role's §8.2
  fallback is present when it is missing, and — enforcing the owner's
  2026-09-10 ruling — that **no theme ships its own `hazard` texture**,
  because a pack must resolve `hazard` to the shared universal material and
  must not re-tint it.

A shell that is neither canonically named nor declared is **refused**. A
thirteenth shell does not inherit the exemption by looking similar.

Sabotage found one hole before the gate was trusted: the universal-role
check ran only for roles a shell uses, no shell uses `hazard`, so a
theme-tinted hazard texture passed silently. It runs unconditionally now.

**Still Production's, and still open:** the material-mode and
`protected_materials` fields, where the six-theme texture set lands, and the
binder itself. ~~Gap 4 (`THEME` as a build argument) remains the next
Art-owned item and is unblocked.~~ **Gap 4 was done on 2026-09-12** — see
below. Gap 3 is now the next Art-owned item.

### Batch 044 — the first branching rooms (2026-09-13)

Report: `docs/art/reports/2026-09-13-branching-rooms.md`. Handoff:
`docs/art-requests/2026-09-13-branching-rooms-handoff.md`. Prod's handoffs
read at `612a7d2`.

`shell_junction_triad` (3 connections), `shell_junction_cross` (4) and
`shell_bay_terminus` (1 used + 2 closable), in `assets/models/batch044/`.
**PENDING; not exported to `godot/content/`; no approval claimed.**

**`entry` and `exit` keep their names**, so all three still work as ordinary
through-rooms under today's two-socket router. Branches are additional and
an unassigned socket is `SEALED`. Not a flag day.

**Every route is flat, and that is a measurement.**
`run_controller_limits.sh` drives Production's capsule at a step: **walking
up, 0.12 m**; jumping, 1.50 m; a ramp, to 46°. `move_and_slide` has no
step-up, so 0.12 m is the whole budget for a walking route. Areas are told
apart by enclosure, ceiling and fittings instead of by height.

The triad's first build was a hall — from the entry you could not tell the
east branch existed. Filling the four corners turned the square into a T, so
the approach is narrow and both arms appear when you arrive. **An interior
view at eye height is what found it.**

The span's stairs: the flight was never short. `sp_landing_0` lay across its
last three treads, 0.38 m of headroom over one and the next one inside the
slab — the playtest's *"the catwalk on top is above the stairs"*. Repaired;
a capsule now completes both routes onto the deck in **16 jumps**, and
cannot walk them, which is the engine's step-up question and Production's.

### Theme-pack gap 3 — the set is described and checked (2026-09-12)

Report: `docs/art/reports/2026-09-12-theme-set.md`.

The six-theme set already exists — **37 PNGs, 6 themes, 32 texels/m** at
`assets/textures/theme/`. What it did not have was a description a binder
could be written against, or anything checking it as a set rather than as
whatever the shells happen to use.

`assets/textures/theme/THEME_PACK.json` is generated by
`tools/content/verify_theme_set.py` and regenerates byte-identical or the
check fails — the `art_budgets.json` pattern. It carries every theme/role
→ file, the required roles, the universal ones a pack must NOT paint, the
§8.2 optional fallbacks, the variants, the texel density, a content hash
per texture, and each texture's measured mean value.

**The set is complete against the authority.** Every required role in
every theme except `hazard`, which is universal and correctly unpainted by
all six. `wall_ribbed` is concrete-only and stays a VARIANT, not a role.

Value separation is **reported, not asserted**: the palette's
`min_value_separation` governs adjacent steps within a ramp, not one role
against another, and a role-versus-role rule would be one I invented.

~~**Still Production's, and this is the whole of what blocks gap 3:** where
the set lands in `godot/content/`, and the binding contract.~~ **Answered
2026-09-12** by `docs/art-requests/2026-09-12-theme-pack-binding-contract.md`
and **shipped** to `godot/content/theme/` with the engine's own `.import`
sidecars. The runtime binder is Production's and is not started here.

### Doorway repairs, round 2 (2026-09-12)

Report: `docs/art/reports/2026-09-12-doorway-repair-2.md`.

**A correction first.** `doorways_outside_envelope()` reads **all three
axes** and grows the envelope by `WALL_THICKNESS + SPAN_TOLERANCE` =
**0.405 m**. The yard's 0.40 m is inside it. My envelope rule was stricter
than Production's; it mirrors their number now. Being outside a
zero-tolerance envelope is not a defect and is not a reason to move an
authored socket — what gets repaired is what the assembled crossing
demonstrates.

**Repaired.** The plenum's entry moved to `_corner(0)`, over landing_0,
where the room's own `surface_id` and `player_entry` volume already said
the player arrives. A walkway was measured and refused: `run_0` leaves that
landing along the same wall and a 0.5 m slab at the entry's height would
leave 0.31 m of headroom over tread5. The yard gained `yd_threshold_±1`,
carrying its floor the 1.20 m to the wall face — a player had been falling
at 1.22 m. It stops at the face rather than the socket, because reaching
the socket would have grown the shell from 85.20 m to 86.00 m.

**Three checkers were wrong and each is now proved by sabotage**: the
aperture probe stepped outward (a walled-up doorway passed), `KNOWN`
exempted a doorway's whole identity rather than one defect, and
`theme_for()` read `--theme concrete_facility` as no choice at all.
`test_measure_doorways.py` is new: 14 synthetic cases, open and blocked in
all four wall orientations.

**48 crossings, 0 problems** — every doorway of all twelve shells, both
directions, at the origin and placed and yawed 37°. Four 0.40 m steps stay
reported and unrepaired in `KNOWN`: both corners and both yard doorways,
all crossed.

### Theme-pack gap 4 — `THEME` is a build argument (2026-09-12)

Report: `docs/art/reports/2026-09-12-theme-argument.md`.

Forty-five builders held `THEME = "concrete_facility"` as a module constant.
Thirty-six now read `common.THEME`, set by `--theme <name>` after Blender's
`--` or by `ART_THEME`. Two keep their own semantics and say why in the file:
`build_plenum` is rusted industrial by authorial choice
(`common.theme_for()` preserves it on a default build), and
`build_navigation` writes all six themes in one run.

**The blast radius is the part that is checked.** A non-default theme
redirects under `assets/themed/<theme>/` (gitignored, scratch), the exporter
refuses a path into the shipped tree, an unknown theme name refuses rather
than painting from an empty table, and `check_art_current.sh` refuses to run
at all with a non-default `ART_THEME` set. `verify_theme_argument.py` checks
all three and both its sabotage tests were confirmed failing first.

The default is unchanged: all 52 builders rebuild byte-identical.

**Gap 3 (the six-theme texture set ships nowhere) is the next Art-owned
item**, and it needs a Production decision on where the set lands before the
shipping half can start.

### Three doorways moved back onto their own rooms (2026-09-12)

Report: `docs/art/reports/2026-09-12-doorway-repair.md`. Repairing
Production's `docs/art-requests/2026-09-11-doorways-outside-their-envelope.md`
at `dc4ef39`.

`shell_hall_transit`, `shell_plenum_helix` and `shell_span_basin` each
declared an `exit` 2.0 m past their own back wall, so `ZoneBuilder` joined
the next corridor over a hole. Confirmed from the export — in all three the
wall's OUTER face is exactly at the declared depth, so `size` was right and
the socket was wrong. `exit_offset`, `bounds` depth and the socket all moved
to `D`; the registry was regenerated. The hall's and span's `.glb` files are
byte-identical: their exits are raised and a sill already carried the
threshold. The plenum needed `pl_north_threshold` as well, because its exit
is at floor level and its floor stopped at the wall's inner face.

A player-shaped body now walks all three joins, at the origin and placed and
yawed 37°, with a 0.000 m dip; the same harness fails all six against the art
as it shipped. Two bugs in that harness were found first, both of which would
have produced a confident wrong report — see the report.

~~Five more doorways are open and unrepaired~~ — **superseded 2026-09-12**,
see the section above. The yard claim was wrong twice: Production's check
reads all three axes and allows 0.405 m of slack, so the yard's 0.40 m was
never the defect. Its floor stopping 1.60 m short of its own doorway was,
and that is repaired, along with the plenum's entry.

`shell_span_basin`'s route/collider hold is NOT lifted by this.

### The verification repair (2026-09-11, revision 4 of Batch 043)

The owner found that `run_import_examples.sh` ended in `|| true`, masking
every Godot failure in the one script `BATCH_043_INTEGRATION.md` quotes as
evidence. `tools/content/godot_run.sh` now backs all four runners: the
engine's own exit status is kept, `SCRIPT ERROR` and `USER ERROR` fail, and
the run has a deadline — because sabotage-testing the first fix showed that
a GDScript fault before `quit()` does not fail, it **hangs**.
`import_examples.gd` fails on a missing model, a renamed part or an example
that comes back short of the figures it claims.

Two claims in the examples became measurements: the anchor block's absent
handling fittings are counted, and the conduit's fixed end stop is read
before and after the fill grows.

Adding the examples to `tools/check_art_current.sh` turned up three builders
missing from its rebuild loop — `build_physics_props`, `build_machinery`,
`build_wave1_repair_overlay` — including both Batch 043 builders. All three
rebuild byte-identical; nothing had proved it. The loop's list is now
compared against `tools/blender/build_*.py` and a missing builder fails.

**No asset changed.** Batch 043 stays pinned at `7ea95e2`.

### Batch 043 — the Amalgam preparation batch (2026-09-11)

Report: `docs/art/reports/2026-09-11-batch043.md`. Packages:
`docs/art/packages/archipepsi-art-batch043-REVIEW.zip` and `-SOURCE.zip`.
Inventory that preceded it: `docs/art/BATCH_043_INVENTORY.md`.

**All of it is a PROPOSAL and joins 023–030 in the pending band.** Nothing
approved, nothing bound to runtime, no mechanic implemented, playable build
unchanged, twelve shipped shells untouched. **Both holds below were
respected**: no junction, closure, return device or warp station, and
`shell_span_basin` was not opened.

Three deliverables, from Design 6 at `a20bf55`:

* **The complete status graphic kit.** 13 statuses, 8 compounds, 4 family
  frames, a compound frame, the player tick, the depletion rule and the
  §33.8 hint in both directions. Native sizes: glyph **16 × 16**, marker
  **32 × 32**, tick **8 × 8** — 32 because the frame must leave a 12 px
  clear radius and a 16 px glyph needs 11.3 at its corners. Neutral colour;
  the four-family hue question is **open and goes to the owner**
  (`review/status_2026-09-11/DECISIONS_FOR_OWNER.md`, five items).
* **The machinery feedback kit.** The five §19.5 conduit states as a static
  channel plus a swappable band, and three pieces carrying them. **No
  audio** — §19.5's hum, arrival click and rising pitch do not exist, and
  `delayed` is the state that suffers for it.
* **The physics-prop family.** **All twelve** Design 2 §10.1 classes built,
  8 kg to 500. Family rule: **unpainted dark steel only where the player's
  device touches** and fully matte so it cannot out-shine the body (measured:
  at least 17.9 L* below it on bright concrete, 13.4 on dark derelict), a
  hand grip only on the classes §10.1 marks `carriable` — which is the flag,
  not the 60 kg threshold: `PLATE` is exactly 60 kg and is not carriable —
  and
  `ANCHOR_BLOCK` `FIXED` with neither — one tether eye and nothing to grab.
  `phys_generic` and `phys_drum` are manipulable siblings of the approved,
  unchanged `prop_crate` and `prop_oil_drum`.

**Revision 3 (2026-09-11)** corrected the exported dimension contract —
`size_runtime_y_up` had been filled from the exporter's authoring-axis triple,
so Y and Z were swapped in all fifteen entries — gave the whole family a
quieter painted skin (`propkit.quiet_painted`, new beside the untouched
`painted_metal`), and made the handling-contrast rule a measurement rather
than a claim. `tools/content/verify_exported_geometry.py` now checks sizes as
well as attach points and refuses to run without an asymmetric object to
expose a swap.

**Revision 2 (2026-09-11) applied the owner's rulings and repaired eight
defects** — the `send` tick, two illegal status/target examples, a lever with
no hinge, a band whose fixed end was assumed, `hazard` on a harmless conduit,
a two-channel rule satisfied by one channel, a mislabelled comparison, and
the claim that audio was the only way to show a delay. Six new checks stand
behind them and each was sabotage-tested. Handoff:
`docs/art/BATCH_043_INTEGRATION.md`.

**The measured finding the owner asked for.** Batch 028's `state_visual`
regions are material slots on one merged mesh, confirmed at `327c089` with
the new `tools/content/inspect_glb_nodes.py`. The only handle a runtime has
is `set_surface_override_material(2, …)`, which recolours and nothing else.
Batch 043's machinery exports every state region as its own named node **and**
its own material slot. **Batch 028 was not modified.**

**Pipeline changes, and they are load-bearing.** `common.export_glb(parts=…)`
exports addressable child nodes whose triangles still count against the same
ceiling; `common.set_origin_group()` anchors a body and its parts together —
without it `set_origin` moved a body and left its parts 7 cm behind, which
buried a switch's indicator inside its own housing;
`common.assert_budget_group()` stops a split mesh buying triangles.

### HOLD — no new authoring until two things arrive (owner, 2026-09-11)

After the Zone 1 playtest the owner accepted the multi-door direction and
then **put authoring on hold**. Do not start any of it on a wake-up:

* **No junction shell, dead-end plug or warp station** until **Dess returns
  the doorway contract** — how many doorways a shell may declare, what they
  are named now that `entry`/`exit` no longer describes them, and whether
  the composer relies on an ordering.
* **`shell_span_basin` stays untouched** until **Production supplies the
  precise route/collider finding.** The playtest showed its two
  basin→deck routes are `mandatory: False`, so nothing ever verified the
  14 m climb — but changing geometry against a symptom risks repairing the
  wrong thing.
* **The twelve approved shells are not rebuilt** and their manifests do not
  change. Existing two-door shells remain valid.

**Settled, and these bind when authoring does start:**

* **Return devices, Zone exits, sealed doors and secrets each get a
  DISTINCT visual identity.** A plug may not borrow `portal_core_*` (that
  is the Zone exit, and confusing "this ends the level" with "this sends me
  back" is an irreversible mistake), and a closure may not borrow the
  batch029 secret language (which means *this can be got through*).
* **A closure is a PLACEMENT, not baked shell geometry**, so doorway usage
  stays selectable.
* **batch026's checkpoint assets are candidates for adaptation and are NOT
  approved.** They remain in the 023–030 PENDING band; no discussion since
  has promoted them.

Readiness detail, with measured sizes:
`docs/art/ASSET_READINESS_MULTIDOOR.md`.

### Batch 042 — deep_space_derelict, proved not shipped (2026-09-10)

Report: `docs/art/reports/2026-09-10-batch042-derelict.md`. Package:
`docs/art/review/derelict_2026-09-10/`. Glyph `6c80b63`. **Visual proof
only: nothing is bound into runtime, `Constants.THEME_MATERIALS` is
unchanged, and theme selection is NOT claimed to work in a played Zone.**

* **One strongly differentiated theme on the same approved shell**, by
  per-surface override alone. Four roles authored — `wall`, `floor`, `trim`,
  `accent` — all at 32 texels/m, all surviving 3 × 3.
* **It is not a darkened concrete, and the CHANGED PATTERNS are what say
  so.** The structure is transposed — vertical stringers at 1.0 m and
  horizontal welds at 2.0 m against concrete's horizontal courses and
  vertical joints, with the bolt line moved from the seams to the stringers
  — and the ramps are re-solved in CIE LCh rather than dimmed. The value
  study supports this by removing HUE, not brightness, which is what makes
  it useful for checking the value hierarchy and the boundaries.
* **A tiling field's structural pitch must divide its own tile.** 1.0 m = 32
  and 2.0 m = 64 both divide 128; this is the same lesson Batch 041 learned
  and it now holds by construction in both themes.
* **`hazard` stays engine-owned** — no theme-specific replacement, no
  decorative stripe. **No warm emergency colour was authored**: the only warm
  semantics available are engine-owned, and inventing a decorative warm near
  them is what the direction forbids. Recorded as a gap.
* **Four new decals, four reused.** `decal_drip` and `decal_splatter` were
  deliberately NOT carried over — a warm run and a splatter belong to a wet
  building, and reusing them would be filling a list.
* **Binding evidence:** 0 unresolved surfaces on all three instances, shared
  mesh unchanged, collision digest unchanged, dressing added 6 cards and no
  collision, and no geometry was duplicated to carry the trim role.
* **`ceiling` resolves to `wall` by the §8.2 optional-role fallback** —
  intentional and resolved, not a missing asset. Do not reopen it as one.

**FOLLOW-UP, same day — the first preview lit the room through its walls.**
`derelict_preview.gd` used a `DirectionalLight3D` whose `shadow_enabled`
defaults to **false**, so an enclosed room was lit by a sun nothing stopped.
**A built Zone has no DirectionalLight3D at all** — `ZoneBuilder` sets
ambient 0.35 plus fog, and `ChamberBuilders` adds one `OmniLight3D` per
fixture at `omni_range` 12.0 with `shadow_enabled = false`. The sun was
preview scaffolding, and darkening the textures to compensate for it was
treating a rendering artifact as an art problem. `derelict_lighting.gd`
drops the sun and lights the room the shipped way: low ambient plus four
labelled preview fixtures under `PREVIEW_LIGHTING_NOT_SHIPPED`, with
emission recorded per fixture rather than painted into any albedo.

**A note for Production:** the shipped fixture builder sets
`shadow_enabled = false`, so the game currently gets no cast shadows in
Compatibility and dark recesses must come from falloff alone. The study
turns them on and says so.

**UV orientation — the first measurement was wrong twice, and is now
corrected** (`tools/content/inspect_uvs.py`). It rotated the coordinates a
SECOND time: **glTF is Y-up by definition** and Godot's frame is Y-up too,
so the file's axes need no conversion — the floor's second component sits at
0.0 and the ceiling's at 3.6, which the tool printed and I read past. And it
divided **128** by `metres_per_uv` on both axes for every role.

Corrected: **32 of 48 wall faces are rotated, not 16.** Per primitive, the
four **Z-thin** slabs around the doorway get V along world up and are
correct; the four **X-thin** slabs — the east and west walls — get V along
+Z, so authored vertical stringers lie on their side. **That is the sideways
left wall, and it is a defect rather than a preference.** And **trim measures
32.0 × 8.0 texels/m**, not 32 × 32: a 128 × 32 strip spanning 4 m per UV
unit is stretched fourfold on V. Declaring 32 texels/m in an asset record
does not establish it after UV mapping.

**Both corrected preview-only, in the override material:** a 90° texture
rotation on the 4 X-thin wall surfaces, `uv1_scale.y = 4.0` on the 8 trim
surfaces, with the facing decided by measuring each surface's own vertices
at bind time. No mesh, UV or approved GLB touched. The ceiling is
deliberately left alone. `floor` tolerates rotation; `wall`, `trim` and
`accent` do not.

**Before this could ship** it needs a runtime binder, a `THEME_MATERIALS`
entry, somewhere for the textures to land, a `ceiling` ruling, canonical
material naming, contracts for the four unbound proposals (emissive mask,
roughness mask, animated display, light colour), a lighting pass, and owner
review. None of that is Art's alone.

### Wall layers and a decal kit — done 2026-09-10

Report: `docs/art/reports/2026-09-10-wall-layers-and-decals.md`. Package:
`docs/art/review/glyph_layers_2026-09-10/`. Glyph `62b0bfd`. **Trial art: it
ships nowhere and no approved asset changed.**

* **The wall is three layers now.** Field (`wall` role), structural trim
  once at the floor junction (`trim` role), decals (cards). Removing the
  baked base course exposed a seam it had been hiding: the shipped course
  pitch of 1.2 m = 38 texels does **not** divide a 128 texel tile, so
  courses never lined up across a vertical repeat. 1.0 m = 32 does. Texel
  density unchanged at 32/m.
* **A mark that specific cannot survive repetition.** The field's first
  pass kept the trial's drips; at 3 × 3 they were all anyone could see. They
  are `decal_drip` now, placed once. The field carries only what bears
  being seen a hundred times.
* **Six decals**, transparent, each at a declared physical size with the
  surfaces and orientations it allows. Physical size is authoritative — a
  card is built from `metres`, never from a pixel count.
* **`tools/content/check_decal_colours.py`** guards the five *chromatic*
  reserved families by chroma and hue. `dead` is deliberately unguarded and
  the reason is in the file: its ramp is neutral grey, so guarding against
  it forbade the whole shared `grime` family the shipped textures use. The
  gate carries eleven negative controls and fails if they do not bite.
* **`Decal` does nothing in Compatibility** — it is a Forward+ node. Decals
  are surface-aligned quads, 6 mm off, depth-write off, nearest filter. No
  z-fighting, flicker or floating edges at four framings.
* **`shell_corner_left` already has a kick rail at the floor junction**, so
  the skirting binds to the `trim` role rather than sitting on a card over
  it. Recorded limitation: the rail is far shorter than the skirting's
  authored 1.00 m, so the texture reads as tone rather than structure there.

**The concrete limitation, for whoever plans the next Glyph work.** Indexed
colour has no partial mix, and the house look is built from partial mixes —
`materials.py` blends at 0.10, 0.26, 0.5, 0.80 and fades streaks
continuously. In indexed mode every one of those must be pre-resolved into a
named palette entry, so an eleven-entry wall comes out **crisper and cleaner
than the shipped one**. Three responses exist — spend more entries, accept
the crisper look, or author in RGBA and give up the palette constraint — and
choosing between them is a direction question for the owner, not a defect.

`GLA-PRF-001` (pixel-edit p95 108.08 ms against 100 ms at the certified
envelope) **remains open and was not touched**. It is a 2048 × 2048 /
131,072-cel workload; a 128 × 128 texture does not approach it.

Until 1–4 land, §8.4 canonical renaming stays **not started**: it would
change all twelve shells' bytes to buy tidiness a legacy-aware binder does
not need. The refreshes the owner flagged for the backlog — Neon Transit,
Void Glitch, and a later cold station theme — follow infrastructure and
migration, not this.

---

## Status

| | |
| --- | --- |
| Branch | `claude/archipepsi-art`, based on `claude/archipepsi-build-inzshp` |
| Phase | **THE AUTHORED ROOM LIBRARY IS COMPLETE THROUGH WAVE 1 AND ALL TWELVE SHELLS ARE `review: "pass"`.** The eight P2 shells passed on 2026-09-02; `shell_hall_transit`, `shell_plenum_helix`, `shell_yard_gantry` and `shell_span_basin` were promoted by the owner on **2026-09-04**, after Production's technical certification at **`7e13f44`** and an independent audit at **`f97545f`**. Nothing in the content pack is `pending` except the three projectile substitutions, which are Production's reversal and stay as they are. **Wave 1 is COMPLETE. Wave 2 has NOT started and requires its own owner brief.** **STYLE LOCK PASSED.** 001-022 and 031-037 are all `PASS`; **023-030 remain PENDING owner review**, and Batch 023 is a PROPOSAL rather than production. **The art lane is intentionally IDLE.** No Batch 038, no Echo visual parts and no diegetic interface work until the owner publishes the two design briefs named below. |
| Owner review | Style Lock passed 2026-08-28. Draft PR [#5](https://github.com/cadykaya/archipepsi/pull/5). |
| Next action | **NOTHING. There is no Art-side blocker and no Art-side work queued.** The three technical questions this lane was carrying are all resolved and none of them is a current blocker: **req 40** — `ShellValidator` is kind-aware through `TraversalLaw` and no longer applies jump bounds to continuous walks or ramps, implemented before the promotion; **`launch_source.radius`** — settled at Production `833fe80` and guarded at `7e13f44`: `position` is the exact foot-contact launch origin and `radius` reserves space for the constructed pad, NOT a disc of possible ballistic origins, so all four pads are correct as authored; **the plenum collar convex-disc defect** — each collar ships as twelve convex ring sectors, the holes are physically open, and the independent audit verified the decomposition. **The one real remaining milestone is Production's, and it is intentional: the player-facing movement-package consumer.** Shell promotion does not implement rails, launches or grapples in ordinary gameplay — the twelve shells can be placed, entered and walked end to end today, and the `rail_route`, `launch_source` / `launch_target` and `grapple_point` offers they carry are reservations against a consumer that does not exist yet. Everything else the lane could reach for is still closed: no Batch 038, no Echo visual parts, no diegetic interface work until the owner publishes those two briefs; 023-030 remain PENDING review; req 31 still blocks seven enemy roles and Art has deliberately not routed around it. **Do not invent filler work. No heartbeat, no polling, no autonomous expansion.** |
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

### ~~Req 40 — the traversal contract disagrees with itself~~ — SUPERSEDED HISTORY

> **RESOLVED. Not a current blocker, and not open.** `ShellValidator` is kind-aware through `TraversalLaw`: it no longer applies jump bounds to continuous `walk`s or to ramps. That was already implemented before the 2026-09-04 promotion, so no room in the library is refused by it. Everything below is the record of the question as it stood, kept because the reasoning is what produced `traversallaw.py`.

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
as what it is. Which half of the contract is authoritative was
Production's decision, and `b37fe07` made it: **req 40 is CLOSED.**

*Both checks named in this section have since been replaced.* Stage 4 ran
Production's own `ShellValidator` until `b37fe07` rewrote it; stage 4 is
now `verify_markers.py` and stage 5 is `measure_flights.py`.
`_assert_walk_ground` proved a `walk` along the CHORD between its
endpoints, which is not the route a flood takes, and it is gone --
`tools/blender/traversallaw.py` mirrors the real bounded flood at build
time instead. See L-87, L-88, L-93 and L-95.

**Do not edit gameplay logic to make an asset convenient. Do not alter a
mechanical dimension to make an asset prettier.** Collision and traversal
truth remain Godot's.

---

## LARGE ROOM LIBRARY — Wave 1 (COMPLETE; PASS, owner 2026-09-04)

The owner approved the ten-room slate (`docs/art/LARGE_ROOM_SLATE.md`)
and the 3 / 4 / 3 wave plan. **Wave 1 is COMPLETE and all three shells
are `review: "pass"`** (owner, 2026-09-04, after Production's technical
certification at `7e13f44` and the independent audit at `f97545f`).
**Wave 2 has not started and requires its own owner brief** — the Wave 1
verdict is a promotion, not an instruction to continue.

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

## P3 — the first LARGE authored room (PASS, owner 2026-09-04)

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
| review | **`pass`** (owner, 2026-09-04), with the three collar `grapple_point` offers and the closed collar walking loop it asked for, both landed. `verify_pack.gd` now asserts the pack DOES ship it. |
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
