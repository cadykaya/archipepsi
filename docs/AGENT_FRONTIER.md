# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## THE ACTIVE FRONTIER: v0.9 — production and the authored-content transition

**`docs/design-packet-v0.9/IMPLEMENTATION_PLAN.md` is what wake-ups
execute.** S1–S10 (Echoes 2.0) are complete and are history below; the
plan is NOT exhausted.

The governing rule, from `docs/design-packet-v0.8/AUTHORED_CONTENT.md`
(normative, outranks the v0.9 plan): **humans make the alphabet, Godot
enforces the grammar, Epsilon writes sentences.** Epsilon is a composer,
never an asset generator. Do not manufacture "final art" procedurally to
claim a stage. Existing primitive geometry and materials are valid
TESTABLE placeholders and stay. Graybox `.tscn` scenes are legitimate
deliverables and must say in-file that they are not final art.

Dependency order (S21/S22 are independent of the asset pipeline, and are
the work that continues if an art gate blocks the rest):

```
S11  CI                        ── independent, first
S12  registry + asset contract ── the foundation S13-S19 consume
 ├── S13 instantiation pipeline
 │     ├── S14 Hub + Echo Lab migration
 │     ├── S15 room shells + connectors ── S16 encounter/traversal vocabulary
 │     ├── S17 interactable/presentation contracts
 │     └── S18 enemy/player/affordance visual interfaces
 └── S19 material/VFX/audio/lighting registries
S20  campaign spine (human-decision gates)
S21  settings/input/a11y       ── INDEPENDENT
S22  packaging/first-run       ── mostly independent
S23  release hardening         ── last
```

**Stage status:** see the plan document. Nothing started yet beyond this
handoff.

**Heartbeat behaviour:** while v0.9 has unfinished INDEPENDENT stages,
continue the next real frontier item. Once everything left is blocked on
human-authored assets or design decisions, record the exact remaining
gates here and make wake-ups no-ops until the user provides feedback or
assets.

---

## Completed: v0.8 Echoes 2.0 (S1–S10) and the pre-playtest pass

## Art branch — canonical

The single authoritative art lane is **`claude/archipepsi-art`**, and
**PR #5** (base `claude/archipepsi-build-inzshp`) is its canonical PR —
that base is what keeps the art diff properly scoped.

`claude/archipepsi-art-setup-9qsbss` was a temporary setup branch. It was a
clean linear continuation and has been **fast-forwarded into
`claude/archipepsi-art`** (merge base 649a6cc, no force, no history
rewritten, no commits lost). PR #6, opened from it against `main`, is
**superseded** — it showed the whole stacked project history rather than an
art diff. Do not maintain two active art branches.

## Art batches — state 2026-09-02, with 2026-09-13 and 2026-09-22 head notes

**2026-09-22 — THE ART LANE IS PRODUCING AGAIN.** The owner opened the
**0.4 Arty Overnight assignment**: 38 packages, 228 explicit actions, in a
stated priority order. `docs/art/ART_FRONTIER.md` **§11** is the art lane's
live frontier as of 2026-09-24 (§10 is the assignment it continues);
read that, not this section, for what art does next.

**2026-09-24 — the art lane's named technical risk is closed.** A Glyph
bitmap font and a Glyph nine-slice both import into **Godot 4.5.1** with
their metrics intact, measured in the engine by
`tools/content/run_font_import.sh` and `tools/content/run_nine_slice.sh`.
The guide's own proof named 4.3, so this was the thing the whole
interface track stood on. Two engine facts other lanes need are in §11:
a font parsed with `load_bitmap_font()` at runtime does not scale unless
you set `fixed_size_scale_mode`, and the importer's mode allows
fractional scaling of a pixel face.

**2026-09-25 — an instrument error, and a finding for Production.** The
art lane's enemy-value harness computed CIE L\* by summing a viewport
image's **sRGB-encoded** channels as if they were linear light
(`#777777` read as 0.740, not 0.500), and lit every room with one room's
lamp. Every enemy VALUE number before this date is on that wrong scale,
including the Tier 1 ceilings the owner ruled on; the replacement
(`tools/content/run_enemy_contrast.sh`) calibrates against known greys
before it measures. **Any lane computing L\* from `get_image()` pixels
must linearise first** (`Color.srgb_to_linear()`). And Production's
shipping enemies are built in code in the room's own accent and trim
(`enemy.gd`), which L-08 forbids; art-lane value bands take effect only
when its models are integrated. Tier 1 is back with the owner — §11.

Two things from it that other lanes need:

* **Batch 045 delivers visual identities for the four 0.4 setpieces**
  (Blindside, Passing Platforms, Counterfire Arcade, Unweighted Switch),
  fitted against Production `claude/archipepsi-0-4-blindside` @ `f404410`.
  Handoff: `docs/art-requests/2026-09-22-setpiece-visual-handoff.md`.
  They are CANDIDATES — imported and fit-checked, **not** runtime-bound
  and **not** owner-approved.
* ~~**A handrail at a natural height on a rideable deck would break the
  gantry guarantee.**~~ **STRUCK 2026-09-22.** `GANTRY_Y` 3.1 is measured
  above the RAIL at 0.6, so the gantry platform spans world **3.50–3.90**,
  and it is **3.5 m away horizontally** from the skiff deck. Nothing on
  that deck reaches it. **If you are reaching for a 0.4 constant, check
  what it is relative to** — this one cost Batch 045 its headline finding
  and left the skiff's guard rails half a metre below the cover welded
  beside them.
* **Batch 046 delivers the Blindside junction** — track, docks, the
  repairable span and the gantry machinery, fourteen assets. Handoff:
  `docs/art-requests/2026-09-22-yardkit-handoff.md`. Same CANDIDATE
  state.
* **Three measured findings in the 0.4 yard, all Production's to
  decide.** The gantry column tops at 3.10 against a platform underside
  at 3.50, a 0.40 m gap. The track floats 0.425 m over the yard floor
  with nothing under it. And a landmark on the acquisition branch cannot
  be taller than a person without crossing somebody's view of the
  grapple ring.
* **The theme-pack library target is now EVERY included Archipelago
  game, not the packet's eighteen.** Dated snapshot in
  `docs/art/theme-packs/catalogue.json`: **81 included games**, 63
  beyond the first wave, taken from `https://archipelago.gg/games` with
  the page's SHA-256 recorded. Community-only APWorlds are deliberately
  separate and not counted. Ledger: `docs/art/theme-packs/COVERAGE.md`,
  gated by `tools/content/check_pack_coverage.py`. **Every row is not
  started.**
* **`Constants.THEME_BY_GAME_HINT` is a per-game hook that selects one
  of six HOUSE THEMES** -- a tint, not a pack -- and `ThemePack` loads
  one descriptor from a fixed path. A library of 81 packs needs a keyed
  lookup and a pack-aware hint. Integration dependency for Prod/Dess;
  Art has not built a second loader.
* **AND THERE IS NOWHERE TO PUT A PACK'S PIXELS.** Sharper than the
  missing hook, and a different problem. `THEME_PACK.json` is a flat
  `themes` list of six with `textures` keyed `"<theme>/<role>"` -- no
  pack namespace. A game pack's materials can enter it only by becoming
  a SEVENTH HOUSE THEME, and 39 files here name `temple_ruin`
  (navigation, lights, landmarks, dressing, secrets, the content export,
  four verifiers). Eighty-one packs cannot be seventy-five more entries
  in that list. Pack CONTENT -- meshes, motifs, dressing, control
  housings -- is not blocked; a pack's MATERIAL SET is. Prod/Dess pick:
  packs become themes, or `THEME_PACK.json` grows a `packs` namespace
  and `ThemePack` resolves one. Art has not picked, because picking by
  writing files is a second loader through the back door.
  `docs/art/theme-packs/COVERAGE.md` §3.
* **An authored enemy would take NO damage tint.**
  `Enemy._collect_tint_parts` takes only meshes whose
  `material_override` is a `StandardMaterial3D`, and a glTF import puts
  its materials on the surfaces. Measured across all ten roles: zero
  tintable parts. Production's to fix; the proposed one-line fallback is
  in `docs/art-requests/2026-09-22-enemy-readiness-handoff.md`.
* **The ten enemy roles now carry named attachment anchors** and are
  gated by `tools/content/run_enemy_readiness.sh`. Req 31 is unchanged:
  seven are art-ready and not spawnable.
* **Batch 047 delivers the skiff's fitted parts** — shield, end guard,
  traction truck, and a bare hull variant. Handoff:
  `docs/art-requests/2026-09-22-skiffkit-handoff.md`.
* **Their track beam is 0.175 m inside the bottom of the carrier deck**
  (track spans 0.425–0.775, deck 0.600–1.000), so nothing fits under
  the deck. The traction trucks hang beside the beam at ±0.45.
* **The gap between S2 and S3 is 14.048 m and no constant says so** —
  three of the rail's five control points sit on a Catmull-Rom corner.
  `tools/content/run_yard_measure.sh` evaluates it with Production's own
  `RailPath`, read-only, into `assets/models/batch046/yard_fit.json`.
  Anything fitting that yard should read that file rather than a
  remembered number.

* **The status kit drew the DESTINATION and the runtime runs the
  ORIGIN.** `Constants.ECHO_STATUS_KINDS` is a closed vocabulary of 24
  that `StatusEffects.apply` refuses anything outside;
  `ECHO_STATUS_KINDS_IMPLEMENTED` names the 13 with a runtime effect.
  Batch 043 drew Design 6 §15.2's thirteen and **the overlap was two**.
  Batch 052 draws the other eleven, so the kit now covers the whole
  vocabulary, gated by `tools/content/run_status_readiness.sh` — which
  reads Production's constants AND their `apply()` guards and refuses
  to keep checking a guard they have rewritten.
* **Three implemented statuses have nowhere on screen to go.** `haste`,
  `low_profile` and `regenerating` are implemented on `self` **alone**,
  and the kit's whole model is a marker anchored to a target. The
  player is the camera. `STATUS_runtime_*.png` places ten of thirteen
  and says so. **The persistent HUD tier is the answer and it has no
  owner** — an integration question for Prod, in
  `docs/art-requests/2026-09-22-status-readiness-handoff.md`.

* **§10.3 draws the carry line at 60 kg and
  `Constants.ENVELOPE_MASS_KG` is 120.** Batch 043's physics props
  signal what a HAND could do, and the game lifts with a 700 N field at
  20 m. Three props the envelope can carry -- plate 60, drum 70, girder
  95 -- wear the "a device has to" language. **CORRECTED by the owner:
  the two numbers govern DIFFERENT MECHANISMS** -- §10.3 is ordinary
  pickup (carriable AND <= 60 kg), ENVELOPE_MASS_KG 120 is the qualified
  manipulation-provider envelope beside force and range. Both right, the
  grips are right, nothing needs redesigning. Art distinguishes hand
  handling from device/constraint attachment.
* **`phys_cart` at 180 kg is exactly the heaviest thing the envelope can
  push** -- 700.0 N against 700 N -- and **`phys_movable_cover` at 220
  cannot be pushed at all**, though its own docstring says it exists to
  be got behind. `lightened` rescues neither: it changes CLASS, not
  kilograms, and `receive_force` is unscaled.
  `tools/content/run_manipulation_readiness.sh` measures all of it with
  Production's own constants, ladder, friction derivation and project
  gravity. Handoff:
  `docs/art-requests/2026-09-22-manipulation-handoff.md`.

* **The Glyph toolchain candidate was trialled, not adopted; the
  addendum's `87db9e2` has now been taken too.** Separate worktree,
  baseline `6c80b63` unmoved and re-verified. The authoring build does
  NOT move: Batches 043 and 052 record that SHA beside every asset.
  `check_tiling` is worth having as a REPORTING step. Both addendum
  repairs verified over real stdio JSON-RPC, not in process: 35 tools on
  the default surface with `transaction` **required** on all nine
  mutations that take one, and `memory_query`, `candidate_submit`,
  `comment_list`, `question_raise`, `question_list` all present. One
  edit -> commit -> image LOOKED AT -> reopen -> export cycle ran end to
  end as a granted artist distinct from the owner, and `memory.promote`
  on my own candidate refused: *reserved to the Lead Owner and not
  available under any grant*, even with `scopes:["*"]`. Five interface
  frictions reported, one of them a real gap (`palette.create` answers a
  malformed colour with an internal TypeError where
  `palette.create_entry` preconditions it). **Opening a `.glyph` writes
  to it** -- five `verify` runs modified six tracked fixtures by
  checkpointing their WAL; restored.
  `docs/art/reports/2026-09-22-glyph-toolchain-trial.md` §5.
* **THE PACK BLOCKER IS ANSWERED. D-11 IS DELIVERED AND CONSUMED.**
  Read from source at the packet's review ref `a7456373`, unchanged at
  that branch's head `d92b637`: `Zone.theme_pack` (optional, `^[a-z0-9_]+$`,
  <= 24), a flat sibling `pack_textures` table keyed `<pack>/<theme>/<role>`
  **whose rows are exactly a `textures` row** (this lane's already are),
  exact-pack-key-then-family resolution with **no pack role hop**,
  `hazard` protected as universal, partial packs legal, and
  `theme_packs.pack_table_problems()` written as the art lane's gate.
  Status ladder `candidate` -> `selectable` -> `approved` (owner only);
  `THEME_PACK_STATUS` is `{}`.
  **No seventh house theme, no second loader, and none was built.**
  Two of my own findings change: the **family runway is superseded** (a
  pack ships its own rows; the family is the backstop for roles it does
  not ship, not its identity), and the **T05 Twilight-vs-Forest finding
  becomes actionable** -- that is the pair D-11 separates.
* **POST-PLAYTEST HANDOFF v1.0 RECEIVED (2026-09-24). ASSIGNMENT
  ACKNOWLEDGED; PLAN ONLY, NOTHING STARTED.** The owner played 0.4: more
  fun, the power-cell installation is a keeper, and the inventory is
  miserable. Art's order is now **A** the Glyph interface family (fonts,
  nine-slice panels, icons, and the shared circuit / blocked-exit /
  control symbols for a LIVE inventory face -- never a painted
  whole-screen image), **B** a distance-readable enemy lineup judged
  without audio or collider overlays, **C** machinery placeholders
  against revised puzzle bounds (receiver z-fight fixed in source
  during replacement, not as its own task), **D** consume D-11 and
  finish T01 + T05, then **E** the A15-A19 reserve.
  **Track D is the only one ready today; C is blocked on Prod/Dess's
  revised puzzle bounds.** Four unresolved decisions and six cross-lane
  dependencies are named in `docs/art/ART_PLAN_2026-09-24.md`.
  No watchers, subscriptions or scheduled work exist or were created.
* **T07 (Dark Souls III, THE HIGH WALL OF LOTHRIC) IS THE LAST PACK WITH
  A HOUSE FAMILY OF ITS OWN.** Batch 061, `gothic_stone`. T06 counted
  two families remaining and was wrong: **`void_glitch` is unusable** --
  it is Archipepsi's own missing-texture theme, an editor checkerboard
  with the word `null` across it, mapped to Archipepsi itself. A game
  pack painted in it would mean "this texture failed to load".
  **So every pack from T08 must share pixels with an earlier pack or
  wait for the namespace, and 74 packs are behind.** T06's report
  carries the correction in place.
* **A FOURTH GATE: `packgates.assert_fits_corridor`.** Nothing a pack
  ships may exceed `corridor_height` (3.6). T02's dial mark reached
  3.78, T03's shutter head 3.62, T07's springers 3.68 -- three packs
  poking through a ceiling, and the only thing that ever noticed was a
  human reading the manifest's `size` field. Unconditional in
  `packkit.build`; caught T07 and cleared the other six.
* **And one thing no gate can say.** T07's buttress springing was two
  stepped wedges, `assert_parts_touch` was satisfied by a 14 cm overlap,
  and the frame showed a staircase hanging in mid-air. **A gate can say
  a thing is attached; it can never say it is legible.** That is the
  case for the in-engine frames existing at all.
  `docs/art/review/lothric_2026-09-22/README.md`.
* **T06 (DOOM 1993, THE UAC TECHBASE) makes six packs -- AND THE FAMILY
  RUNWAY IS NOW A DEADLINE.** Batch 060, `concrete_facility`.
  T05 proved two packs sharing a house family read as one place. The
  workaround since has been one unused family per pack. There are SIX
  families: `temple_ruin` (T01, T05), `rusted_industrial` (T02, T04),
  `neon_transit` (T03), `concrete_facility` (T06). **`gothic_stone` and
  `void_glitch` are unused and 75 packs remain, so the workaround runs
  out at T08 and every pack from T09 must share pixels or wait.**
  A deadline rather than an opinion; recorded per pack as
  `family_runway`.
  Also: `concrete_facility`'s accent marks a thing as SIGNIFICANT and
  its own docstring says a colour that marks everything marks nothing,
  so it is spent on the blast chevrons and the keycard lamps and
  nowhere else. Third family whose trim/accent semantics had to be read
  before use.
  `docs/art/review/foundry_2026-09-22/README.md`.
* **T04 (Super Metroid, THE WRECKED SHIP) and T05 (Kingdom Hearts 2,
  TWILIGHT TOWN SERVICE ALLEY) make it five packs, one shell, four
  cameras, and the switch housing in the same place on the same wall in
  all five.** Batches 058 and 059.
  **T04: the hint covers 6 of 81 games.** T02's disagreement was an
  argument; this is a number. 75 of 81 -- Super Metroid among them --
  have no hint at all, so for nine games in ten there is nothing to
  agree or disagree with. And the pressure door's COAMING was refused:
  a 0.10 m sill across the doorway is FLOOR, floor is Production's
  whatever its height, and a 0.10 m step is under the 0.12 m walk-up so
  the foothold rule would never have seen it.
  **T05 WAS AN EXPERIMENT AND IT FAILED USEFULLY.** It shares
  `temple_ruin` with T01 on purpose, to test the owner's "a variant is
  not a duplicate merely because its construction is shared". The shapes
  ARE different and legible as different -- and the frame still reads as
  a warmer Forest Temple, because `temple_ruin`'s accent is mossy stone
  so awning canvas reads as foliage. **The geometry says "boarded-up
  shopfront", the pixels say "overgrown temple", the pixels win.**
  Strongest argument in five packs for the pack namespace, and it is a
  picture rather than an assertion. The awning's valance was refused for
  hanging 6 cm below the door head -- T04's coaming and T05's valance
  are the same rule seen from both ends of the same opening.
  `docs/art/review/wreck_2026-09-22/`, `.../twilight_2026-09-22/`.
* **T03 (Bomb Rush Cyberfunk, BRINK TERMINAL AFTER HOURS) makes it three
  packs, three subthemes, one shell.** Six assets (Batch 057), four
  frames from the same cameras as T01 and T02.
  **THE HINT IS USUALLY RIGHT AND THAT IS THE PROBLEM:** T01 agreed, T03
  agreed, T02 did not. A hint that is always wrong gets noticed; one
  right two times in three does not.
  **Two checks got stricter, neither found by reading code.**
  `assert_opening_clear` grazed in height but not width and called a
  shutter guide tangent at exactly 1.20 m an intrusion "by 0.000 m"; and
  the in-engine check tested VERTICES, which cannot see a box spanning
  0 to 3.2 -- **its own sabotage step caught that**, three packs late.
  Per triangle now; T01 and T02 re-verified.
  `tools/blender/packkit.py` joins `packgates`: all three builders share
  the Painter and the build loop, and `build_forest_temple` rebuilds
  byte-identical through it.
  `docs/art/review/brink_2026-09-22/README.md`.
* **T02 (Super Mario 64, TICK TOCK CLOCK) likewise -- and it found two
  things T01 could not.** Six assets (Batch 056), four frames from the
  SAME cameras in the SAME shell as T01 so the packs compare frame for
  frame. (1) **The per-game hint and the pack's material disagree:**
  `THEME_BY_GAME_HINT` says `concrete_facility`, a clock movement's
  nearest family by material is `rusted_industrial`. The hint picks by
  GAME; a treatment follows what a pack is MADE OF. Two questions, one
  field. (2) **`rusted_industrial`'s `trim` IS the universal hazard
  band**, and the colour is never decorative in any theme for any
  reason -- the first pass shipped a clock movement in warning stripes.
  `trim_plain` is trim minus danger. Every later pack reaching for that
  family will hit it.
  Shared now, because 79 packs remain: `tools/blender/packgates.py`
  (the three Blender gates) and `tools/content/pack_views.gd` +
  `packlayouts/<pack>.json` (the shell and the imported-geometry check;
  the layout is art and is data).
  `docs/art/review/clockwork_2026-09-22/README.md`.
* **T01 (Ocarina of Time, Forest Temple) has content AND context; it is
  not complete.** Six assets, four in-engine frames dressing a
  Production-grey shell with a 2.4 x 3.2 opening, and a fourth gate that
  runs in the ENGINE on the imported `.glb` -- 120 vertices against the
  opening, sabotage-tested in the same run. Photographing it changed the
  art: `tp_ft_root_mass` read as fallen timber and was rebuilt as growth.
  **Missing: its material treatment**, because `THEME_PACK.json` has no
  pack namespace. Prod/Dess's seam; no second loader.
  **Catalogue and completion coverage are now separate numbers**:
  catalogue 81/81, completed 0/81, in progress 1.
  `docs/art/review/forest_temple_2026-09-22/README.md`,
  `docs/art/theme-packs/COVERAGE.md`.
* **THE COURSE RHYTHM BREAKS AT THE TILE EDGE, AND IT TOOK THREE TRIES
  TO SAY WHY.** A 128 px tile covers 4 m; anything drawn with
  `range(0, size, step)` repeats at `step` inside the tile and at
  `size % step` across its edge. **Three live paths** compute such a
  step: `materials.surface_for()`'s seams at 1.2 m = 38 px (which paint
  no line, but aim `near_seams()` speckle at thirteen call sites, place
  every `bolts()` row and start two weep-streak loops);
  `paintkit.panel_grid`, at 1.2/1.35/2.0/0.90/0.60/0.55/0.40/0.30 m per
  treatment and per axis; and inline loops inside the treatments at
  dimensions `panel_grid` never sees -- ribs 1.0 m, soffit ribs 0.6 m,
  station tile 0.30 m, mortar joint 0.42 m, masonry course/block pairs,
  seven bolt pitches from 0.18 to 0.5 m. `paintkit.panel_seams` is the
  only dead one.
  **The first two accounts of this were wrong and are recorded as wrong**
  in `check_theme_courses.py` and `build_theme_candidate.py`: "it is
  `surface_for`" and then, over-correcting, "`surface_for` paints
  nothing, it is `panel_grid`". A `panel_grid`-only shim left
  `concrete_facility_wall_ribbed` byte-identical -- that branch takes no
  `panel_grid` call at all and still measures a 38 px rhythm -- which is
  how the incompleteness was caught rather than argued.
  **CANDIDATE PREPARED, NOT APPLIED.** `paintkit.SNAP_COURSES` (off by
  default) snaps every wrapping pitch to a divisor of the tile;
  `build_theme_candidate.py` turns it on and writes 37 textures to
  `assets/textures/theme_candidate/`. Shipped measures 4 broken
  axis/texture pairs, the candidate 0. The shipped set rebuilds
  byte-identical with the flag off, proven by `check_art_current.sh`,
  not asserted. **The cost is real:** the divisors of 128 are the powers
  of two, so 1.35 m has nowhere nearer than 1.0 m and gothic_stone's
  masonry lands on an exact 2:1 course-to-block that reads more
  mechanical than the laid wall it replaces. 18 of 22 pitches move.
  **A LOOK DECISION FOR THE OWNER.** Evidence:
  `docs/art/review/course_candidate_2026-09-22/` (24 m of wall, six
  repeats, shipped above and candidate below in one frame, plus the
  shipped shell twice with one set each);
  `docs/art/reports/2026-09-22-course-candidate.md`.
  `tools/content/check_theme_courses.py` prints the measurement on every
  suite run; `--strict` turns it into a gate the day somebody rules, and
  it refuses (exit 3) if any of the three paths changes under it.
* **CI is red repository-wide and it is not the art branch's.** Both
  checks die in 3-6 seconds with logs that 404, on PR #5 and equally on
  PR #12's unrelated branch -- before any test body runs. One re-run
  spent, same result. `tools/check_art_current.sh` is green locally on
  every art head. Explained on PR #5.

**Scheduling override (owner, 2026-09-22): heartbeat, watchers,
subscriptions, scheduled check-ins and automatic re-arming stay OFF.**
This overrides the older "resume the routine the moment a task exists"
rule in `docs/art/ART_FRONTIER.md`. A large queue existing is **not** a
reason to re-arm.

~~**THE ART LANE IS WAITING ON AN OWNER VERDICT, NOT IDLE-WITH-WORK-TO-DO.**
Do not start work in it on a wake-up. Read this section and stop.~~
Superseded 2026-09-22 by the assignment above. Batches 023–030 and 044
remain pending owner review; that is unchanged and is not a blocker.

**2026-09-13 — three things another lane may need, from
`docs/art/reports/2026-09-13-presentation-study.md`:**

1. ~~**`shell_yard_gantry`'s two doorways are refused.**~~ **WRONG,
   withdrawn same day.** `shells.is_offerable` *reports*
   `doorways_off_the_body` and returns regardless, because a manifest
   rule cannot see floor and the assembled crossing decides. Art's gate
   now reports the 0.395 m without failing. **No socket repair is
   requested.**
2. ~~**The binder used to prove it is a proposal not wired into the
   game.**~~ **WRONG, withdrawn same day: the runtime binder exists.**
   `ThemeMaterials._material` asks `ThemePack.texture_for` first and
   falls back to `ProcTextures` on null. The art-side binder is deleted.
   What survives is the check nothing else makes — the pixels the GPU
   samples, against the authored PNG, through the real import — run
   against the material Production builds.
3. **Production reads shell sockets by kind and by name**, so a three- or
   four-connection room is readable. **A four-connection asset is still
   not a four-neighbour room in a generated Zone.**
4. **Every opening now declares its own arrival region**, named after its
   socket — Art's half of §11.3. Handoff:
   `docs/art-requests/2026-09-13-capacity-and-arrival-handoff.md`. It
   also corrects the capacity claim for `shell_bay_terminus`, which has
   **no `exit` socket** and is a destination, not a through-room.
5. ~~**Lettering cannot be fixed in UVs.**~~ **WRONG, withdrawn.**
   An authored `.glb` shell keeps the materials Blender baked:
   `ContentInstantiator` performs no material operation at all
   ("material" appears zero times in it), while `chamber_builders.gd`
   names `ThemeMaterials` 46 times. Themed materials are the PROCEDURAL
   path. The UV repair therefore lands, and is proved on both faces of a
   two-sided sign and with the room rotated. **The mirrored stencil is
   still real on the procedural path** — that is a separate, unfiled
   item, not Batch 044's.
6. **"LEAF" IS NOT "DEAD END".** A branch destination in this
   implementation can still host onward branches. Production's
   `dead_ends` is a measured degree (`n == 1` adjacency); Art's
   `dead_end` is a shape tag describing a treatment, and **nothing in
   Production reads it**. Measured: from the Terminus's approach the
   one-neighbour and two-neighbour states are pixel-identical (the mouth
   hides both side openings); from inside, an assigned branch is plainly
   a way on. Evaluate a one-neighbour assignment separately.
7. **`shell_bay_terminus` cannot be composed at all today**, and it is a
   PRODUCER limit, not a door count: `topology.compose_chain` returns
   `edges=()` when any chamber lacks the literal `entry`+`exit` pair, and
   `compose_with_branch` calls it first and returns immediately. So one
   destination room in the list seals every room's doors. A leaf is
   rejected before it can become a leaf. Dess's and Prod's to resolve.

**ALL TWELVE AUTHORED ROOM SHELLS PASS** (owner, 2026-09-04). The eight
P2 shells passed on 2026-09-02 after Production certified them at
`6640d86`; the hall and the three Wave 1 rooms were promoted on
2026-09-04 with owner form approval, Production's technical certification
at `7e13f44` and an independent audit at `f97545f` all agreeing. Nothing
in the pack is `pending` except the three projectile substitutions.

**`pass` DOES NOT MEAN THE MOVEMENT OFFERS ARE LIVE.** The four large
rooms carry `rail_route`, `launch_source`/`launch_target` and
`grapple_point` declarations reserved against a player-facing
movement-package consumer that is **not implemented**. A passing shell
can be placed, entered and walked end to end today; nobody can ride its
rail. Report:
`docs/art/reports/2026-09-04-wave1-promotion.md`.

**THE LARGE ROOM LIBRARY IS APPROVED AND WAVE 1 IS BUILT.** The owner
approved the ten-room slate (`docs/art/LARGE_ROOM_SLATE.md`) and the
3 / 4 / 3 wave plan. Wave 1 -- `shell_plenum_helix` (20x72x20, a 129 m
rail), `shell_yard_gantry` (84x16x52) and `shell_span_basin` (30x22x90)
-- is authored, verified and, since 2026-09-04, `review: "pass"`.
Package: `docs/art/review/wave1/`. **Wave 2 is four rooms and does NOT
start on a wake-up.** The Wave 1 verdict it was waiting on has arrived
and is a promotion, not an instruction to continue: Wave 2 needs its own
owner brief.

**`shell_hall_transit` is repaired** against Production's final walk law
at `b37fe07`: two of its three climbs were built backwards, and all three
were single wedges the import-time flood could not see through.
`shell_tower_spiral`'s `platform_8_to_deck` is a `gap`, from Production's
own probe.

**PHYSICAL-TRUTH REPAIR LANDED (2026-09-03).** The seven items of the
plenum/hall/span brief are done and measured:

* the three plenum collars ship as **12 convex sectors each** (117 -> 150
  colliders, same 1656 triangles). `roomcollision.assert_convex` now
  refuses ANY non-convex collider at build time, in all six builders
  that author collision — a
  `-convcolonly` node imports as the convex HULL of its vertices, so an
  annulus was shipping as a filled disc.
* every collar destination is on the band and none on the machine axis:
  three `landing_N_to_collar_K` endpoints, three `enemy_anchors`, the
  `check_anchor`, the `reward` and the launch target, all through one
  `_collar_point`, which now shares `_collar_axis` with the bridge that
  builds the spur.
* **`shell_plenum_helix`'s launch serves the LOW collar now, not the
  middle one.** Measured over 4537 floor stances on a 0.25 m grid: the
  top collar is reachable from none, the middle from five, the low from
  141. The reward stays on the middle collar.
* the plenum rail, the hall rail and the span rail were all rerouted off
  geometry their BAKED curve was inside; the plenum's grapple_1 moved a
  metre inward for its swing room.

New gates, both in `tools/verify_content_pack.sh`:
`tools/content/measure_offers.py` measures every declared rail, launch
and grapple against the shipped collider triangles, and
`tools/content/replay_audited.py` replays the pre-repair pack out of git
and FAILS unless every audited finding still comes back.
`tools/content/sabotage_offers.py` is their negative-control suite and
runs from `tools/sabotage_checks.sh`.

**AND THE TWO LAUNCH PADS, on the owner's ruling of the same day:** keep
both launches, move both pads the least that clears them. The hall's and
the span's flights each went through the platform they land on — 0.08 m
at first contact, 0.643 m and 0.806 m at their worst. An arc's shape is
fixed by its two heights, so neither could be dodged along z: the hall's
pad goes **3.00 m west to (9, 0, 18)** and the span's **7.02 m to
(−7, 0, 45)**, out from under the deck, and onto the basin's face. Both
are the nearest round metre that leaves a flying body the 0.325 m a rail
beam must keep. Targets, landings, routes and radii unchanged, and
`measure_offers.RAISED` is empty again. Reports:
`docs/art/reports/2026-09-03-physical-truth-repair.md` and
`docs/art/reports/2026-09-03-launch-pads.md`.

**RESOLVED 2026-09-04 — `launch_source.radius`.** Settled at Production
`833fe80` and guarded at `7e13f44`: `launch_source.position` is the exact
**foot-contact** launch origin, and `radius` reserves space for the
constructed pad — it is **not** a disc of possible ballistic origins. All
four large-room pads are correct as authored. *Superseded history: this
was previously recorded here as an open Production question.*

**RESOLVED — req 40.** `ShellValidator` is kind-aware through
`TraversalLaw`; it no longer applies base-kit jump bounds to continuous
walks or to ramps. Fixed before the Wave 1 promotion, so no room in the
library is refused by it. *Superseded history: this was previously
recorded here as needing Production.*

**THEME PACK: PREPARED AND PROVED, NOT BUILT (2026-09-10).** Two
inspection-only batches, no asset rebuilt and all twelve shells
byte-identical. The role contract is reconciled against
`ARCHIPEPSI_THEME_PACK_SYSTEM_AUTHORITY_20260903.txt`; all 597 shipped
material slots classify (0 canonical, 597 legacy, 0 unknown) and Godot
preserves every name exactly, so a binder can recover the role at runtime
with no manifest field; and one shipped room has been shown wearing two
themes **at once**, by per-surface override, with the shared mesh
unchanged and the collision digest identical. Reports:
`docs/art/reports/2026-09-10-theme-pack-preparation.md` and
`docs/art/reports/2026-09-10-batch041-two-themes.md`.

**What is left is PRODUCTION's, and there are four of them:** a ruling on
`hazard` (the authority makes it a required per-theme role; the art lane's
standing rule is that hazard is a universal colour no theme may re-tint,
and no theme has a hazard texture), the `material mode` and
`protected_materials` fields the registry entry schema does not have,
somewhere for the 37-PNG theme texture set to ship, and the binder itself.
**Do not start canonical `<role>` renaming on a wake-up** — it would
change all twelve shells' bytes to buy tidiness a legacy-aware binder does
not need.

**ECMS GLYPH IS AVAILABLE AND HAS BEEN RUN (2026-09-10).**
`cadykaya/ECMS-GLYPH` at **`727129e1`** on `main` — the implementation
merge. An earlier note in this lane read the frozen authority snapshot
`0cf872d` and concluded Glyph was "a specification, not a program"; that is
**superseded**, and the difference was the branch, not the project. `npm ci`
and `npm run build` are clean on Node 22, the worked example runs, and one
128 × 128 `concrete_facility` wall has been authored through it on the house
palette and structure, then bound onto real room geometry through Batch
041's override path. **It ships nowhere** and no approved asset changed.
Report: `docs/art/reports/2026-09-10-glyph-first-texture.md`.

Two things a later agent should not have to rediscover. **Glyph's indexed
colour has no partial mix**, and the house look is built from partial mixes,
so a Glyph-authored surface comes out crisper than `materials.py`'s — a
direction question, not a defect. And **the owner has settled `hazard`**:
every pack must resolve the role, but may resolve it to the same shared
universal material; separate theme-coloured hazard textures are not
required.

**001–022 PASS. 031–037 PASS** (031; 032 *with boundary*; 033 *audit, build
nothing*; 034 *the visual principle*; 035-R; 036-R; 037-R *with a documented
caveat*; boss audit *accepted, build nothing*).

**PENDING owner review: 023–030 only.** Nothing about them is actionable
without a verdict.

### The boundary — do NOT start the next art system

Two systems are being designed by the owner and a design collaborator, each
arriving as its own owner-authored brief:

1. **Modular Echo visual construction / kitbash system**
2. **Diegetic in-world interface system**

Until those briefs exist:

- **No Batch 038.**
- **Do not design or mass-produce Echo visual parts.** Requirement 32 is
  *only* the architectural seam — the Echo family must be visible through a
  swappable / composable `EchoPart` seam. The three built ranged / melee /
  grapple forms are **proof-of-seam only**, and are explicitly not approval
  of seven fixed family models, a final attachment grammar, a final part
  taxonomy, runtime composition rules, family silhouette rules, or
  provenance / source influence rules.
- **Do not expand the interaction kit** into menus, terminals, Archive UI,
  Forge UI, Zone-selection UI, or any other large physical interface.
- **No heartbeat, no polling, no autonomous expansion.**

### Rules locked by the post-030 review, worth carrying forward

- **If a distinction must survive gameplay distance, the distinguishing
  feature must affect object-scale SILHOUETTE.** Surface is what distance
  takes away first.
- Three channels on any operable object: **silhouette/structure** = what
  kind of thing; **interaction hardware** = yes this one is operable;
  **state treatment** = what it is doing now. The plate/bezel may stay as
  standardized hardware only while it is not the sole source of truth and
  does not rely on hue alone.
- Secrets: **no universal secret colour**; a cue is a **deviation from a
  learned environmental pattern**; a smaller reliable vocabulary beats a
  padded one. **Stop revising secrets until real in-game Zone testing.**
- Enemy surface: **plate** = proud slab / impact-bearing; **mechanism** =
  recessed, ribbed, rodded exposed function. No role colours.
- Accepted caveat: brute vs scuttler surface identity is weak. **Do not
  alter the approved scuttler silhouette or body to force a stronger
  surface distinction** — revisit only with gameplay evidence.

**Still blocked, and deliberately not routed around:** requirement 31 —
`ENEMY_ARCHETYPES` is still `("melee", "ranged", "brute")`, so seven roles
have a body, a collider, a telegraph seat and a surface, and no way to be
spawned.

**The art heartbeat is PAUSED** (`trig_01DSWy2dbCpeSefcx2YGS9Ys`, disabled
2026-08-29) under the owner's rule: pause the routine when there is no work,
resume it when there is a task. **Do not re-enable it on an idle lane.** PR
#5 activity still wakes the session directly, so nothing is missed.

Earlier decisions standing: `objective_marker`, `arch_objective_socket`,
`arch_signage_mount` and `arch_affordance_socket` all struck, each because
nothing places them. `arch_vista_socket` still blocked on a contract.
Requirement 23: engine `trim_mat` maps to authored `trim_plain`. The Batch
023 landmark audit was corrected on 2026-08-29 — Production **has** an
authored-content pipeline (`ContentRegistry`, `ContentInstantiator`,
`landmark` as a real L4 category); what is missing is the `.glb` →
`res://content/` scene step, a `landmark_id`, a placement path and a landmark
envelope. Requirement 24, reworded.

## Open decision, deliberately not guessed
`challenge_marker` (§14.2) and its `challenge_timer` readout (§14.1) have a complete bridge half — grantable, recorded, `best_seconds` improves — and no world half, because neither section says where a run starts, what ends it, or what counts as one. `test_stage_tripwires.py::test_the_challenge_marker_still_has_no_challenge` names the decision and comes due when it is made.

## Stage dependency trap
A live one: a chamber carrying an affordance feature must be at least `MIN_FEATURE_CHAMBER_WIDTH` (5.2 m) wide, and only a corridor can carry one at all — every other chamber type has a Check or a gating objective. A generator that hangs a feature on a default-width connector gets its Zone refused. The fallback widens its own connectors; anything else must too.

Retired at S9: every verb in the catalog runs, and `DEFERRED_PRIMITIVES` is empty (deliberately, so the partition test in `test_schemas.py` stays true rather than vacuous). The rule it encoded still applies to whatever is deferred next — name the LAST required stage, not the first.

## Standing tripwires (deliberate, will fire on stage advance)
- `test_stage_tripwires.py` is now all receipts: the S3 pair fired at S5,
  the S9 pair fired at S9, and each is recorded as discharged. Nothing is
  gated, so `test_the_registry_still_runs_even_though_it_gates_nothing`
  is what keeps the mechanism from being refactored away — it narrows the
  registry by hand and watches it refuse. The same trick keeps the
  primitive gate visible in `test_schemas.py` and `test_s1_review_fixes.py`
  (both pass a narrowed `implemented_primitives` through the seam the
  signature already provides).
- Cross-language pins: glyph indices, palette names, channel count
  (`test_hud_contract.py` ↔ `hud_driver.gd`), theme rule
  (`test_theme_agreement.py` ↔ `integration_driver.gd`), runner arms
  (`test_runner_coverage.py`).

## Resolved at S5 (was the standing unresolved decision)
Traits apply because they are OWNED — unchanged, and now deliberate
rather than inherited. S5 added the escape hatch the contract always
intended: `requires_equipped` makes a trait conditional on a slot, and
I7 now *requires* it for any severe downside (enforced by the trait
model, not merely described). Ownership is the default; equipping is the
modifier. Recorded in `docs/IMPLEMENTATION_DECISIONS.md` (S5).

## Last full green verification
At the pre-playtest checkpoint (this commit):
- `make test`: **487 passed** (schemas + bridge + apworld together)
- `check_packet.py`: green, **11 documents**
- `make dual-real-soak`: 3/3 freshly generated two-Archipepsi multiworlds
- `make smoke`: SMOKE OK
- (was 343 at S9 completion, 362 after the S1–S5 review)
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-hud`: GODOT HUD TESTS OK
- `make godot-rules`: GODOT RULES TESTS OK
- `make godot-stats`: GODOT STATS TESTS OK (I3 sweep, links, S7 slots)
- `make godot-lab`: GODOT LAB TESTS OK (fixtures, and no campaign mutation)
- `make godot-affordance`: GODOT AFFORDANCE TESTS OK (I4 lane sweep, the
  seven built, volumes that cannot trap, readouts that only read)
- `make godot-verbs`: GODOT VERBS TESTS OK (press/release/cancel/death,
  the complete refund, hover claims across four slots, parry vs. DoT,
  shield timers, and rule effects following the highlighted slot)
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign;
  every interpretation credited in some provenance chain, components at
  Mk II+, Actions reaching several slots, the Hub's Lab present and inert,
  affordance features offered and built, a local reward earned and
  recorded without touching a single AP location, and all 26
  interpretations reading their item in four different modes

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->

### v0.8 stage log
- Branch: `claude/archipepsi-build-inzshp`
- v0.7 POC: complete
- Echoes 2.0 S1 + S1.1 + S2 + S3: complete
- S4: complete — the ECHOES §5 rule interpreter (`rule_runtime.gd`,
  `make godot-rules`, I5 proven: edge latches, deferral, cooldown-bounded
  oscillation, per-tick cap, cost atomicity, alias resolution); fold
  validates rule resource references (I11 treatment); capability gate
  opened `rule` with per-piece §5 allowlist gates; game-event wiring
  (incl. new chamber tracking); fallback grants a FLASK (low_health
  auto-heal rule) and a kill-fed CELL (self-discharging shield rule); I8
  proven and the fallback is budget-aware; integration asserts the
  campaign ends owning folded resources AND rules.
- S5: complete — the nine-stat derived stack with I3's floors
  (`stat_stack.gd`, `make godot-stats`), per-target statuses
  (`status_effects.gd`), all four link kinds walking in the runner, the
  last six verbs (`beam_sustained`/`hover`/`block`/`restore_resource`/
  `scan_mark`/`cleanse`), I7 enforced by the trait model, and the
  §5 status rule vocabulary. Both S3 tripwires discharged.
- S6: complete — the operation vocabulary is whole. The capability
  gate admits `upgrade`/`modify`/`merge`; `target_errors` checks a
  disposition can land at GENERATION (repair loop) as well as at fold
  (I11); the request carries the owned component graph with per-field
  upgrade headroom; the fallback evolves families (ECHOES §11's own
  Hookshot→Longshot→Clawshot example is reachable from
  `--epsilon=fallback`); I10 alias soundness proven; §12 identity
  packages complete (sound family, particle style) and pinned from both
  sides.
- S7: complete — four slots, four runtimes, four keys (RMB / MMB+F /
  Shift / C). `IMPLEMENTED_ACTION_SLOTS` is the whole contract;
  `SLOT_NAMES` shared through `constants.py`; the S1.1 `ARCHETYPE_SLOT`
  collapse retired (migrated mobility Echoes go back to Shift); the HUD
  shows all four slots with Mk levels; the archive names the key each
  button lands on, compares against what it would replace, and marks
  favourites (client preference, `user://loadout.cfg`, never campaign
  state); the wheel cycles favourites within the highlighted slot.
- S8: **complete** — the Echo Lab, a walk-in Hub annexe (never a Zone,
  never a Check): dummy that cannot die or farm `kill` events, tall wall
  with height bands, measured runway, gap with a safe return, armed
  hazard through the production damage path, deterministic moving target,
  reset pad that clears transient state only. `make godot-lab` proves it
  and proves the negative: a full session sends no intent and moves no
  campaign truth. ChatGPT/GPT-5.6 Sol's build brief is cherry-picked at
  `docs/proposals/S8_ECHO_LAB_BUILD_BRIEF.md`.
- S9: **complete** — the seven world affordances build as real geometry
  (`affordance_features.gd`, `affordance_nodes.gd`), each paid for by an
  owned capability (I12, `owned_affordance_tags` over OWNED mechanics);
  features never touch the mandatory path (I4 — the schema keeps them out
  of reward chambers and gating objectives, the builder keeps them out of
  the walking lane, and a room too narrow to have a "beside the path" gets
  none); every feature holds a `LocalRewardPickup` and never an AP reward
  (I13); movement volumes write into a player environment layer that
  cannot trap you (`MIN_VOLUME_SPEED_SCALE`, upward-only lift); the ten
  §14.1 readouts draw from the fold in `readouts.gd`, observing only —
  proven by a frozen-world frame that moves nothing and sends no intent.
  `pull_pickup` is implemented, so **nothing is gated any more**:
  `DEFERRED_PRIMITIVES` is empty and every registry equals its contract.
  `make godot-affordance` is the suite.
- S10: **complete** — §15's chain (`item -> concepts -> supported systems
  -> validated recipe`) is real. `epsilon/concepts.py` is the
  deterministic reader; it reproduces §15's own three worked examples
  (*Water Tunic*, *BLJ*, *Master Sword*) and a test asserts the prose
  still uses them. The fallback reads every item and labels itself with a
  mode **derived from what its operations did**, so the archive cannot
  misdescribe an Echo; mock Epsilon says the reading out loud. The mode is
  a fact, never a preference — creativity steers via `preferred_modes` in
  the request rather than capping the label. `reading_errors` refuses an
  empty reading and one sharing no vocabulary with the item, and nothing
  else: taste is the provider's job. §16 is now counted in the units the
  prose states (affordances in **distinct tags**), the request carries
  `budget_headroom` and `relevance_hint`, and the Claude prompt states the
  pipeline, the four modes and the budgets instead of leaving them to be
  inferred. The archive shows the mode.
- **Adversarial review of S6–S10: done, all findings fixed.** Two passes
  (client and bridge). The deepest: the affordance geometry was designed
  and tested in an 18×20 arena, which the schema refuses for features —
  **a corridor is the only chamber that can ever host one**, and four of
  seven rewards sat above its 3.6 m ceiling. Reworked around per-tag
  footprints, extent-based lane clearance, and corridors built to the
  height their features declare. Also: an advertised upgrade bound the
  model would not honour (a `FoldError` no retry could pass, the one
  save-integrity bug), a `Damageable` concept that was missing so the
  breakable wall could not be hit by anything, a concept validator wrong
  in both directions, a mode that called self-contained Echoes "systemic",
  a tag dropped from every Zone forever, and claimed rewards respawning.
  All sabotage-proven. See `docs/IMPLEMENTATION_DECISIONS.md`.
- **Secrets reach the vertical chambers.** `platform_path` and `tower`
  grow them now, over the highest FLAT GROUND in each (the end ledge at
  `rise`, the top deck at the summit) — `_secret_alcove` takes a `floor_y`,
  because measuring from absolute zero put the alcove *below* the player
  in both. A tower that grows one is built 1.5 m taller; five metres over
  the summit left it 0.15 m short of standing room and the builder
  declined silently. Epsilon also speaks in the Hub now.
- **Adversarial review of S1–S5: done, all 19 findings fixed.** Three
  passes (the fold/save half, then the runtime engines). Two were
  campaign-destroying and neither was reachable from any existing test:
  - **A legal v7 save destroyed the campaign it migrated.** v7 let a
    passive make you slower (`SPEED_MULT_MIN` 0.9); v8's I3 floor forbids
    it, and the migration copied the multiplier across, so the models
    refused the result. `load_save` caught, tried the `.bak` (the same v7
    file), returned None — and the engine reads None as "no campaign",
    built an empty one, and the next write moved the real save into the
    backup slot. Migration clamps now; "unreadable" and "absent" are no
    longer spelled the same way; the backup is copied rather than renamed
    (a crash between two renames left NO primary); a non-primary recovery
    heals the primary immediately.
  - **A merge left every link pointing at the component it deleted.** The
    fold rewrote aliases, components, provenance, Mk and order — not
    `links` — while `echo_runtime.gd` states in as many words that the ids
    it receives are canonical. A `powers` source merged away reads 0 of 0,
    so the spend always refuses: the Echo stops working for the rest of
    the campaign, silently, because aliases are permanent. Edges are
    rewritten at merge time now, and `powers`/`scales` are enforced
    at-most-one-per-target, which is what both clients already assumed.
  - `target_errors` waved through five refusals the fold then raised on
    (MODIFY had only an existence check; MERGE never asked where
    `max_value` landed, and `capacity` **defaults** to `"sum"`). A
    `FoldError` in `append_interpretation` is a crash, not a rejection,
    and it repeated on every retry, so the Check could never be granted.
  - Ten in the press/release lifecycle and the pool: a `charge_shot` fired
    from a key-up with no press; a refused press kept its cost, paid its
    `fills` link and emitted `action_used`, which made refused presses net
    resource GENERATION; death ended no hold; a slot swap stranded a hover
    (an I3 bypass — `hover_gravity_scale` is applied after `clamp_stat`);
    a failed multi-cost re-armed `regen_delay` sixty times a second and
    stopped regeneration dead.
  - Six more in statuses, latches, parries and shields: a magnitude could
    outlive the duration it came with; `cleanse` stripped the player's own
    `low_profile` stealth; `apply` had no vocabulary guard; an arm was
    kept alive by an unrelated channel and survived Zone entry; a burn
    tick spent the parry window; an absorbed shield froze its timer and
    inflated the next grant.
  - And the per-tick firing cap starved the same rules forever, because
    `_rules` order is fixed.
  New: `make godot-verbs` (a real player over a real floor, driving the
  four real runtimes), and both GDScript fixtures now have generators in
  the tree (`make rules-fixture`, `make verbs-fixture`) with a bridge test
  that regenerates in memory and compares — the rule snapshot claimed to
  be a real fold and was, but its generator had not survived.
- **Adversarial pass over `ap_client.py`** — the top of the correctness
  order, and it had never had a dedicated one. One finding: `on_ap_ready`
  runs on every completed sync, RECONNECTS included, and resumes a Zone in
  `PENDING_GENERATION` — so a socket blip during a provider call built the
  same Zone twice (a second billed Epsilon request) and the loser died of
  `ValueError: Zone is GENERATED, not pending` inside a bare task, where
  nothing surfaces it. Guarded at both ends: no second run for a zone id
  already in flight, and `_run_generation` re-checks the record state after
  its await. The rest of the file came back clean — every `_apply` site
  either has no await before it or re-reads `self.save` after one, the
  race-mode `Get` is sent by `CommonContext.send_connect` (so the scout
  gate cannot hang), and the goal is re-sent on reconnect from
  `on_ap_ready` when `goal_sent` is already persisted.
- **The whole disposition vocabulary now reaches players.** S6 completed
  `UPGRADE`/`MODIFY`/`LINK`/`MERGE` in the validators and the fold, and
  then nothing emitted half of it: no provider in the tree produced a
  MODIFY or a MERGE, so §3's own two examples were shapes a unit test
  could build and a player could never receive — and a bug in either was
  invisible to every integration run (the merge-link bug fixed this
  morning is exactly that). The fallback now tries the most specific
  claim first: a **sequel** (UPGRADE) when it owns the verb, an
  **enhancement** (MODIFY) when the item READS as an element and
  something owned can be hit with, and a **confluence** (CREATE + MERGE)
  when the resource budget is spent, which is §16's rule written down.
  Each returns nothing when it cannot land, so the ordinary CREATE
  survives. `modifiers` joins `upgradable` on the owned-component
  summary, because a MODIFY that cannot see the target's existing two is
  guessing at exactly what it will be refused for. Five words the concept
  lexicon should always have had (`ember`, `ash`, `venom`, `poison`,
  `spark`) mean MODIFY now happens in ordinary mock play.
- **`test_campaign_soak.py`: 25 full campaigns, 25 different seeds.** The
  integration run plays once, always on `"MockSeed"` — and the seed is the
  only input to the track order, the shop draw and the allocator's
  shuffle. Twenty-five playthroughs cost 23 s without Godot, each
  asserting what must hold of EVERY campaign: the goal reached and
  reported once, no location in two live Zones, no Check claimed twice, no
  location yielding two Echoes, the allocator never starving (§11.5), the
  save validating after every transition, and the fold publishing no edge
  that names a component it deleted.
- **Mock Epsilon does S10's other half now.** EPSILON_SPEC §12.2 named it
  and scheduled it: `--epsilon=mock` must exercise resources, rules, links,
  merges and the wider action catalog "or the headless integration run
  stops proving anything about the systems S2–S6 add." It never grew — mock
  delegated its whole echo to `fallback_echo` and added narration. Measured
  across ten campaigns that cost **8 of 28 primitives, 1 of 4 link kinds,
  and no Info readout**: `make godot-blink` fired 23k attempts at a verb
  nothing granted, the hover/beam/block holds in `make godot-verbs` covered
  presses no player could perform, and all ten §14.1 readouts stayed dark
  because only an `info` component turns one on and nothing emitted one.
  Mock now picks a shape from the §15 READING (`beam` → a beam and the
  charge it burns; `revelation` → a radar) and falls through to the
  fallback for an item it cannot read. Every shape is self-contained, so a
  link cannot dangle and the three `POWERED_PRIMITIVES` are expressible at
  last. The roster was the real limit — ten names over 21 fill slots —
  widened to 21, every one a name the reader already understood.
  A mock campaign now reaches **all four link kinds, real readouts, 16 of
  28 primitives**. `test_mock_catalog.py` holds both levels: every row of
  the table folds, and a real campaign reaches the systems.
  Follow-up, from measuring the campaign the growth produced: mock was
  **accumulating where it should evolve**. The disposition chain was not
  run on mock's own catalog shapes — justified as "a table shape is a
  fresh CREATE by construction", which is true about validity and wrong
  about the game — so ten Zones ended with seventeen unrelated Actions
  against a soft budget of twelve. `as_disposition` is shared now, with
  one flag (`enhancement=False`) for a caller that has already made a
  specific reading: "Ice Beam" reads as both `cold` and `beam`, and the
  generic enhancement was swallowing the specific shape. Upgrades 8 → 17,
  merges 1 → 14, resources pinned at exactly the soft budget of six, Mk III
  chains. **The whole disposition vocabulary now reaches a real campaign**,
  merge included, rather than only a crafted request.
- **Dual Archipepsi is proven and supported.** `make dual-real` /
  `make dual-real-soak`: a real MultiServer on a real generated two-slot
  seed, two bridges connected at once, two saves in ONE shared directory
  (the realistic same-machine case), each checking the other's locations.
  Ten properties across three freshly generated multiworlds. Four
  sabotages caught (shared scout cache, shared received list, a campaign
  key dropping the slot, a save path dropping both). The bridge port is
  configurable (`--port`, `BridgeServer(port=...)`), defaulting to the
  generated constant. Two findings, neither a bug: an echo id is unique
  only WITHIN a campaign (both worlds number locations 89100001–89100030,
  so `echo_89100001` exists in both and means different items — the
  correct property is that the other player's state does not MOVE), and a
  Track is a GAME not a slot (`track_key` is `recipient_game`, so a
  location whose item goes to the other Archipepsi player shares the
  "Archipepsi" Track with one that comes back to you; asserted so a change
  would be deliberate).
- **`AUTHORED_CONTENT.md` is in the packet and authoritative.** Humans
  make the alphabet, Godot enforces the grammar, Epsilon writes sentences.
  Reading position 10, authority position 6 (above EPSILON_SPEC on the art
  boundary, silent elsewhere). Epsilon may not author anything whose value
  depends on consistency, readability, identity, repeated exposure or
  exact mechanical dimensions. Five authoring levels, props → set pieces.
  §6 records the debt: **zero imported assets exist and every visual is a
  procedural placeholder**, with seven named file-level conflicts. Not to
  be ripped out — the placeholders are load-bearing for every suite.
  `test_authored_boundary.py` guards the vocabulary (no schema field may
  name a mesh/material/texture; `theme` and `palette_color` must stay
  closed Literals).
- **Playtest ready.** The bridge announces port, AP mode, provider and the
  RESOLVED save path at startup (the save dir is cwd-relative, which is
  the footgun). `test_startup.py` is the launch-shaped suite: bind,
  handshake, mock campaign plays a Zone, save lands where announced, and
  each likely first-run misconfiguration names its own fix.
