# Archipepsi 0.4 — Arty Overnight 01: setpiece production, enemy readiness, and Archipelago-inspired asset packs

## Execution brief: a large production queue, not a concept-only exercise

I will be unavailable for roughly ten hours. Prod and Dess have the separate **Overnight 04** implementation programme. This is Arty's complementary production assignment. Execute ready work in this finite queue, deliver useful assets early, and keep going after the first batch instead of returning a proposal and waiting for me. The queue deliberately exceeds what may fit in one session; it is not a promise that every entry finishes in ten hours.

The primary outcome is **the working 0.4 rooms receiving a coherent visual identity without their gameplay changing**. The second is a substantial library of finished, inspectable, compatible game-inspired kits that Production can bind rather than leave in a folder. Neither is satisfied by mood boards, colour swaps, beauty renders without loadable assets, or an inventory of things someone could make later.

This authorizes modelling, texture authoring, visual-only rigging/animation, art-side import/export tooling, isolated presentation scenes, validation, and development candidate packs within the existing art direction. It does not authorize rewriting gameplay, AP logic, level topology, acquisition rules, collision truth, saves, or Production's material-selection code. Original asset construction is authorized; new visual candidates still need the owner's subjective review before becoming owner-PASS production defaults.

**Keep the roles straight.** Arty owns models, textures, visual assemblies and animation resources. Prod owns gameplay geometry, placement, runtime animation/state timing, collision, machinery, enemy behaviour, presentation wiring and overall game integration. Dess owns agreed design/bridge contracts and game/pack selection data. Art supplies clear requirements and reliable assets; it does not turn a model into another independent implementation of the mechanic.

### What should not stop the assignment

A completed setpiece kit, one import success, one rendered theme, one review request, a new commit, a context compaction, or one unavailable Prod answer is not the end of this queue. Preserve the result, update its status, and select another ready unit. A missing vehicle dimension can block the affected vehicle variant without blocking enemy rigs, compatible fixtures, material work, or a different pack.

Stop only when all ready work has been completed and verified, only precise unavailable inputs/owner decisions remain, the user interrupts, or a real session/tool/resource limit requires a checkpoint. Reserve enough remaining active time to preserve the best deliverables. Do not manufacture variations to fill the clock and do not claim execution continues after the session ends.

**No heartbeat, watcher, subscription, scheduled check-in, polling-until-owner-returns, or automatic re-arming.** Older Art Frontier instructions say to resume hourly production heartbeats; this current instruction overrides that scheduling text. Record the override near the current art frontier so the next wake-up does not resurrect it. Do not touch another project's scheduling.

## 1. Starting facts and authority

The preparation read Art at `claude/archipepsi-art` / **1a9f1c9fd21c30d57f9f0d702f81a3eacf60b199** and Production at `claude/archipepsi-0-4-blindside` / **68eb947a65f6dd72e150831322fc76c655e963fe**. These are observations for provenance, **not reset targets**. Both branches may have advanced by the time you start. Establish actual current heads and the working tree before taking action.

The Art branch is not the 0.4 branch. Its historical production excerpts may describe older runtime, missing consumers that now exist, and resolved blockers. Read the actual consumer in the current 0.4 branch before concluding an asset cannot be used.

### Read only what is relevant to the unit being built

Start with `docs/art/ART_FRONTIER.md`, the current approved art review, the relevant sections of `ART_BIBLE.md`, `ASSET_AUTHORING.md`, `ASSET_INVENTORY.md`, and the specific setpiece/runtime handoff. Use the existing ledgers and export scripts rather than drafting a competing standard. Read the effective Amalgam sections for semantic visuals and physical families. The complete Amalgam is a reference, not a requirement to audit every line before drawing the first mesh.

Important existing work to preserve and reuse:

- Style Lock is passed. The cold, human facility and the asymmetric neon-green Epsilon intrusion are distinct visual languages. Preserve the owner's Check, portal, anchor and enemy-family decisions. Do not redesign the Epsilon installation.
- Enemy models exist beyond the initial three. The early batch002 proposals are not necessarily the integration versions: the Art Frontier records **batch030 fits for all ten declared roles**. Find the latest approved applicable exports before commissioning any replacement.
- Batch043 already created Status/compound graphic work, state-addressable machinery pieces and candidates for twelve physical-object classes. Its inventory is a **before/after historical record**, not permission to remake everything labelled NO ASSET at the start of that batch.
- The six base-theme material families, dressing and light-fixture families already exist. The Deep-Space Derelict/theme-binding work also exists. Extend, finish or repair what is actually present; do not reclassify it as new production.
- `ThemeMaterials._material()` already calls `ThemePack.texture_for(theme, role)` in the current production read. There is a real binder. Do not author another one because an old report said it was absent.
- The current binder requires per-theme `floor`, `wall`, `trim`, `accent`; `hazard` is universal and is not a per-theme texture. It has existing fallbacks and physical tile coverage. Read its current shape before exporting.
- The authoring sources are the existing Python/Blender build scripts and dependencies, not an undocumented manual `.blend`. Deliver source that actually rebuilds the export. A supplemental working blend is optional and never substitutes for the recorded source pipeline.
- Existing authoring rules specify albedo-oriented low-resolution materials, not new normal/AO/roughness-map sets. Preserve them unless an explicit newer owner ruling supersedes them. Do not turn the batch into a PBR renderer migration.

The additional theme designs, asset groupings, queue order and acceptance checks in this document are **new proposed production instructions**, not claims that the references already contained those exact assets or that the owner already reviewed them. Source notes at the back distinguish verified project facts from proposed art direction.

## 2. The visual target

**Recognisable, useful, low-poly worlds—not abstract texture soup.** Use the project's established retro 3D language: legible silhouettes, deliberate proportions, textured surface hierarchy and readable machinery. Low polygon count does not excuse a skiff that looks like random boxes, a solid wall masquerading as a doorway, or a tube that appears disconnected from what it powers.

The four situations retain their own identity:

- **Blindside:** a substantial railway service junction that can be understood on the first visit and read differently after the branch and featured Echo. The vehicle should feel like something built to carry a person through a working facility, not an unadorned test platform.
- **Passing Platforms:** a vertical transport well and crossing carrier with visually distinct routes and obvious transfer edges. The visual structure must make the timing opportunity and recovery area understandable without adding a new shortcut.
- **Counterfire Arcade:** a controlled firing/service installation whose protection and receiver hood explain where a projectile can travel. It must look intentional rather than like targets dropped into a box.
- **Unweighted Switch:** a material-handling recess, a credible weight-class sensor and a shutter whose contradictory relationship to the crate is visible. The crate remains a step during LIGHTENED; the model must not shrink or dissolve to suggest otherwise.

Do not encode a particular objective solution into all variants. A gantry is a spatial machine; whether a shot, lever, acquired Echo or another accepted input operates it belongs to Epsilon's declared configuration and Prod's runtime. Provide separately addressable parts and mounting options that can express those configurations without drawing a new room every time.

### Similar mechanisms may have good visual variants

The owner explicitly accepts visually distinct variants of the same mechanism. Do not reject a useful harbour hoist and a foundry carrier merely because both carry a player. Conversely, a hue change of identical geometry is not a new asset family. Record base meshes, variants, state meshes and assemblies separately; never inflate the number of unique models by counting exports or every colour as a new invention.

## 3. Scope and ownership

Work in the Art lane, using a clean branch/worktree and the repository's accepted integration practice. Protect existing sources and review checkpoints. Prod keeps the 0.4 runtime branch; the 0.3 comparison and `review/0.4-m2mech-snapshot` are not advanced or overwritten by this art assignment.

Read Production's current branch as a pinned dependency for fit and harness tests. Do not blindly merge its entire tree into Art and later send it back as an art delivery. If imports require a combined checkout, use an isolated worktree and record both source refs. Changes destined for Production should be explicit assets/wrappers/manifests or an agreed bounded presentation hook, not unrelated code churn.

One writer per shared manifest, exporter and material contract. If helper agents are available and permitted, divide by asset family or isolated pack folders. Do not create independent edits to the same palette, material registry or enemy skeleton and reconcile them by guessing later. Arty integrates Art's combined output.

Existing scene/export interfaces may need a small addition for addressable nodes, clips, skins or presentation selection. Prepare the exact file/symbol proposal for Prod or Dess, use the agreed names once delivered, and keep other asset production moving. Do not build a private replacement content loader. No paid service, new account, credential acquisition or unapproved external asset purchase is authorized.

## 4. Definition of a completed art delivery

Every production unit must include the actual mesh/texture/animation resource, its reproducible source and dependencies, a valid import/export path, fit/protected-space information, state/attachment naming, measured resource costs, and inspectable evidence. Include only metadata the actual runtime schema supports in its manifest; keep extra provenance in the art handoff, not invented fields that a strict parser discards or refuses.

Use independent status columns:

`source-built | export-valid | imported | fit-checked | state-addressable | rendered-in-engine | runtime-bound | owner-reviewed`

A technical pass never becomes owner-PASS. `runtime-bound` names the actual consumer and revision; an isolated preview or descriptor override is not normal generation. Existing approved assets keep their approval. New heroes/themes stay review-pending and are available in an explicitly labelled review path without lying to the production registry.

### Technical obligations

- Use metres and the current Blender-to-Godot axes/origin conventions; validate the exported result rather than guessing sign conventions from prose. Declare floor, wall, ceiling, moving-deck, hinge and centre anchors deliberately. All moveable visual pieces have their own useful pivots.
- Visual replacements for enemies, carriers, controls and projectiles do not smuggle in a second collider, body, trigger, light, camera, gameplay script or root-motion authority. Room shells and structural modules have the separately approved authored-collision contract; read it rather than applying the prop rule to the room.
- Fit the **current physical envelope and swept space**, not only a static AABB. Boarding points, railings, projectile origins, crouch-free headroom, routes, socket approaches, cover edges, lift gaps and interaction rays stay usable. Decorative holes are not promised walkable openings.
- Do not change masses, target classes, timings, cooldowns, ranges, receiver filters, macro states, damage or acquisition requirements to accommodate art. Produce different fitted art or surface the exact conflict.
- Read the actual visual state hooks. State regions requiring independent motion/visibility must survive GLB export as named nodes or a supported equivalent, not disappear into one merged mesh/material region. A material index is not a hinge.
- Use appropriate connected surfaces for objects that should be continuous; intentionally articulated rigid parts may remain separate. Inspect orphan geometry and undocumented disconnected shells. Do not merge functioning pivots merely to reduce a mesh count.
- Use the existing nearest/filter/tile/mipmap rules and measure their actual imported state. Test directional markings after rotation and on opposite walls. Author front/back sign faces when needed; do not rely on mirror tricks that reverse text.
- Prefer baked textures only where the approved pipeline permits them; existing albedo and semantic-emission slots are the starting point. No new PBR map suite. Preserve universal gameplay glyphs/colours, Epsilon identity, Check identity and attack warnings across theme swaps.
- New filenames are case-safe: lowercase source/output IDs, consistent path spelling, no case-only pair. The prior `WALL_FIELD_3x3.png` versus `wall_field_3x3.png` collision must never be reproduced, and new export work must retain the repaired `_sheet` naming.
- Measure triangles, vertices, material surfaces, texture sizes and visible instances against current project budgets. Derive budgets from the actual use case; do not raise limits to pass your own assets or announce an arbitrary FPS target was met without a measured platform and scene.
- Every scene is freshly imported in a clean test project/cache as well as loaded in the working harness. No success obtained only because a stale class/resource cache kept an old registration alive.

## 5. Game-inspired pack membership and intent

For this packet, “core verified” means **the source title was checked against Archipelago's official Currently Supported Games page, which describes games included with the software**. It does not mean we ran that game's client, certified its randomizer, cleared its assets for redistribution, or proved Archipepsi supports its exact metadata. Record those as separate questions.

The 18 reference titles below were present on that official page during preparation. Recheck the title's setup/game entry before production and record the observed source/release or date. Do not classify community worlds as included merely because a repository exists. Existing project inspirations not on that list remain legitimate art references but do not acquire a false core-support badge.

These are **new Archipepsi environment-kit proposals inspired by the references**, not ripped levels or a promise of exact reproduction. Study original-game reference material available through official screenshots/trailers/manuals or clearly identified in-game captures. Keep reference provenance. Do not extract game archives, download anonymous ripped model packs, or claim AP support grants asset rights. A game's recognisable atmosphere can be translated through shape, construction, motif, material hierarchy and authored landmarks. Avoid copying full source levels, branded logos or unreviewed character families into this environment assignment. Existing approved Archipepsi enemies stay the combat roster.

A pack is not just four textures. For each, build a coherent room-scale slice and the needed architecture-facing treatment, useful props, stateful-control housings, material roles and original motif/dressing vocabulary. Produce one complete slice before broad variation. Reuse compatible assets honestly and do not duplicate them solely to hit counts. Complete packs are development candidates pending owner visual acceptance, not automatic production defaults.

### Presentation packs are not necessarily gameplay theme IDs

Current code resolves material roles from an existing theme key, and game-to-theme mapping is separately controlled. Eighteen new folders do not automatically become eighteen selectable runtime themes. Agree a **presentation-pack selection/export interface** with Prod/Dess; do not widen enums or change AP/game classification from Art.

While that integration is unavailable, author independent candidate descriptors and render them through the real binder's declared review/test seam in an isolated project. Label the result honestly. Do not replace the one production `THEME_PACK.json` repeatedly and report that the library is installed simultaneously. Keep stable pack IDs and show exactly how each pack can later be selected. A missing selector is an integration task, not a reason to stop producing an otherwise complete, correctly shaped kit.

## 6. Work selection and milestones

Maintain the queue below in the existing art ledger or an additive current work-order file. Reuse existing task IDs where one already represents the same item; reference this packet's IDs rather than renumbering other lanes' findings. New findings use `ART-...` identifiers to avoid the shared F-number collisions.

The first priority is usable setpiece and enemy delivery. Start the live fit/export canary before mass-producing the rest; complete one good supported assembly, then finish its family. The next priorities are current-system feedback and the first six game packs, followed by the remaining listed packs and independent art breadth. If an exact fit input is absent, select another ready unit rather than improvise a gameplay dimension or wait silently.

Milestones are checkpoints, not stop-and-ask gates:

- **ART-M1:** a fit-checked Blindside moving assembly and essential controls import against the current runtime, with one explicit integration handoff.
- **ART-M2:** all four setpiece visual kits are complete candidates, plus the existing enemy family is handed over with its required nodes/clips and actual readiness state.
- **ART-M3:** a reusable shared machinery/Status/prop visual library is corrected or extended from existing work, and the first theme kit is bound and demonstrable.
- **ART-M4:** continue the finite 18-pack reference queue, maintaining coherent kits and meaningful variants instead of stopping at one.
- **ART-M5:** deliver the best verified collection, contact index and installation manifest, with remaining ready work and real blockers explicit. Human acceptance is not manufactured.

The quantities below define work scope, not an export-count scoring system. Each numbered action must be discharged by a concrete asset, measurement, confirmed reuse, integration delivery, or a precise block—not a paragraph promising future work.

## 7. Production packages — 38 packages, 228 explicit actions


### A00 — Recover current work once; establish the production baseline

**Outcome:** An accurate ready-work queue that starts from existing art instead of making replacements for missed files.


**A00.1** Read current Art/Production refs and the active worktrees. Preserve uncommitted work and review refs; record which branch supplies each input. Do not restore either branch to the historical SHA in this brief.


**A00.2** Compare the asset inventory with actual exports and current consumers. For every requested family use four distinct outcomes: reusable as-is, extend/adapt, art-ready/runtime-missing, or no suitable asset. Check later approved batches before the original concept batch.


**A00.3** Recover the four setpiece specifications, latest asset handoff dimensions and relevant model-state contracts into durable repository references. The attached originals are backups, not a claim the current build has their measurements.


**A00.4** Confirm the available Blender/Godot/export toolchain from project pins and executable versions. Preserve tool versions and rebuild commands; do not upgrade the engine because an older tool path is inconvenient.


**A00.5** Agree exclusive Art ownership for source generators, new pack folders, state metadata and any shared export edits. Prepare the two short handoffs for Prod/Dess without pretending they accepted or received them automatically.


**A00.6** Record the scheduling override and create an ordered ready queue. Close genuine already-built items with their actual paths and tests, then immediately start a missing production unit. Do not spend the run regenerating the entire historical inventory.


**Completion boundary:** Baseline refs, reuse decisions and first executing asset unit are recorded; no protected ref moved.


### A01 — One visual integration contract and an early fit canary

**Outcome:** New art can replace an actual placeholder without changing what the player collides with or what the machine does.


**A01.1** Choose the current skiff deck or another high-priority supported visual seam as the first canary. Read its collider, render parent, sockets, local axes and animation ownership from the actual consumer, and record them as input to the model generator.


**A01.2** Make a compact art-side fit record: requested asset ID, consumer/path@revision, static envelope, swept exclusion regions, attachment transforms, material roles and exported state-node names. Keep this record outside strict runtime manifests unless the schema supports it.


**A01.3** Build one native asset with separate required rigid parts, useful pivots and stable attachment points. Preserve draw/collision separation and protect raycastable controls, projectile muzzles, boarding edges and the player camera.


**A01.4** Import with the existing exporter and prove the final GLB/scene—not the Blender working view—contains the requested nodes, materials and units. Add one deliberate missing-node or wrong-scale control to the importer/fit harness.


**A01.5** Instantiate alongside or under the actual Production consumer in an isolated combined checkout. If its hook is absent, supply the exact hook request to Prod and keep the canary marked imported/unbound; do not implement a private gameplay controller.


**A01.6** Deliver the canary and the manifest slice early. Request a named integration acknowledgment once, continue ready art while waiting, and carry any mismatch back into the shared fit contract before cloning the family.


**Completion boundary:** At least one real pipeline canary imports correctly; integration status names the tested consumer or exact missing hook.


### A02 — Export, provenance, material and Windows-safe delivery pipeline

**Outcome:** A collection that survives a clean checkout and import rather than only working in Arty’s current sandbox.


**A02.1** Extend the existing reproducible source/export scripts only as needed for this batch. Every produced GLB/PNG/animation has a source command and dependencies; source and output changes travel together.


**A02.2** Run both applicable content validators: the actual Python manifest shape and the Godot registry/resource resolution. Keep provenance out of forbidden manifest fields; do not label a custom schema ignored by the game as integrated.


**A02.3** Enforce case-insensitive path uniqueness across added assets and review sheets. Inspect the existing case-collision repair before renaming anything. No whitespace/case-only revisions of an owner-approved stable ID.


**A02.4** Verify missing texture, bad digest, unsupported role, failed import and a pending-review asset produce the intended fallback/refusal. A fallback that hides an absent texture is not evidence the authored pack bound.


**A02.5** Measure imported sampling, texel density, physical tile coverage, directional texture orientation and material slots. Test a wall at a non-cardinal yaw and opposite-facing surfaces; handwritten assumptions about triplanar mapping do not qualify.


**A02.6** Ship an art-only review selection manifest and per-pack content plan that preserves production defaults. Pin its source and consumer revisions, file hashes and review state; do not commit transient .godot caches or private campaign saves.


**Completion boundary:** New deliveries load after clean import, validate through supported interfaces and preserve pending versus owner-approved state.


### A03 — Blindside: skiff body, passenger deck and onboard assemblies

**Outcome:** A recognisable rideable service vessel whose art supports fighting and orientation while moving.


**A03.1** Author or adapt the skiff body around the measured deck, rider envelope and turning sweep. Give its underframe, travel direction and front/back silhouettes an intentional construction; do not add an invisible walkable lip or claim a visual bumper is collision.


**A03.2** Build the onboard shield and railings as fitted parts with their own attachment points. Preserve the actual cover-height and firing gaps; inspect from player eye level, not only outside the vehicle.


**A03.3** Create visible traction/guide assemblies—bogies, rollers, contact shoes or an appropriate counterpart—whose motion can be driven by actual travel. Provide visual pivots/clips without moving the parent, changing speed or authoring root motion.


**A03.4** Make onboard directional-control housings and docking/readiness indicators. Leave arrows, labels and state elements independently addressable so the same model can express accepted, refused, moving, held and interrupted states.


**A03.5** Check boarding/disembark edges, active grapple/camera clearance and hands/weapon sight lines over the shield through curve, stop and reverse states. Supply a swept visual-envelope report and name any view obstruction.


**A03.6** Produce neutral-light and runtime-light review views of the occupied deck and an isolated state strip. Deliver the source, exports, attachment map and measured budgets as an integration-ready candidate before adding decorative variants.


**Completion boundary:** Skiff visuals fit the existing carrier throughout its motion and can communicate runtime state without owning gameplay.


### A04 — Blindside: rails, docks, switches and the physical repair

**Outcome:** A readable junction whose disconnected and restored routes are visible in geometry.


**A04.1** Reuse the existing rail-beam family where appropriate; create compatible straight/curved visual segments, supports, sleepers/contact structure, exposed ends and transition caps against the current path representation. Avoid seams that imply rails connect when runtime says they do not.


**A04.2** Build dock-edge treatment, bollards/buffers, boarding markers and limited service furniture inside the approved footprint. Do not add ramps or stairs to the inaccessible destination as convenient art staging.


**A04.3** Model the repairable span in its actual retracted/misaligned/aligned forms using moving parts, pivot and endpoint references. The aligned mesh must meet both track ends; the unaligned state must not appear like a jumpable alternate bridge unless the geometry actually permits it.


**A04.4** Supply switch points/tongues and position indicators for supported switchable configurations as art components. Keep unsupported routing states labelled candidate; the asset does not advertise graph support the carrier lacks.


**A04.5** Create first-visit and restored-junction presentation arrangements on the same mechanical layout. Tie small inspection labels and visual route IDs to runtime-provided values rather than baking one branch’s answer into every skin.


**A04.6** Verify tiling, endpoint joins, LOD/readability if applicable, cover clearance and route visibility at near/mid distance. Provide the equivalent views with the base greybox for fit comparison.


**Completion boundary:** Track and docking art exposes the true transport/repair state and does not create or remove a path.


### A05 — Blindside: overhead gantry, acquisition branch and return landmarks

**Outcome:** The player recognises the previously inaccessible control when returning with a new tool.


**A05.1** Build a gantry machinery assembly around the existing overhead control placement and grapple attachment. Keep the hookshot target visible from the intended first-visit sightline; do not conceal it behind decorative scaffolding.


**A05.2** Reuse approved soffit/wall anchor designs and adapt mounting structure, not the target function. Show believable load paths to the facility while preserving the actual attachment clearance and aim surface.


**A05.3** Create alignment-lever housing, exposed linkage and power/service-panel visuals whose relevant parts are separately addressable. Do not assume every configuration uses the same input; provide supported mounting variants.


**A05.4** Dress the existing acquisition branch with visual continuity to the junction: cables, service markings, matching machine housings and one memorable nonblocking anchor landmark. No new rooms, routes, Check placements or mandatory puzzle steps.


**A05.5** Make return-route identification work in reverse: different approach views, legible signs from both sides and a consistent branch symbol. A return device uses the existing gameplay symbol and hold/cancel semantics.


**A05.6** Present before-acquisition, post-acquisition access and commissioned-state views from actual gameplay camera positions. Label which state was supplied for a render versus reached by normal play.


**Completion boundary:** The branch and central control read as parts of one place; no art-added access bypass or hardcoded acquisition promise.


### A06 — Passing Platforms: the complete transport-well art kit

**Outcome:** Two moving journeys are visually distinct and their meeting point is understandable.


**A06.1** Build the vertical lift shell, horizontal shuttle shell and their differing guide/drive structures around current collision sizes and trajectories. The two carriers may share manufacturing language but not be indistinguishable slabs.


**A06.2** Create transfer-edge markings and railings that preserve the real step/jump window and the tested deck separation. Decorative cables and counterweights must not look like alternate climbable routes.


**A06.3** Model the call/launch/stop/onboard-restart controls with state-addressable travel and direction indicators. Keep labels driven by real function and preserve the patient alternative solution.


**A06.4** Dress the recovery floor, upper shelf, goal gallery and service-stair hardware without covering landing surfaces. Recovery must read as intentional accessible space, not a visually lethal pit the runtime treats as safe.


**A06.5** Provide visual gate/interlock assemblies only against actual agreed runtime states. If a gate consumer is unfinished, deliver the parts and label the missing hookup instead of adding an animated fake lock to the preview.


**A06.6** Record player-height views at arrival, aboard each carrier, at rendezvous and after a miss. Check moving art at the closest approach, not only separately on turntables.


**Completion boundary:** Complete compatible lift/shuttle/control/recovery kit with motion-safe fit and unambiguous functional distinctions.


### A07 — Counterfire Arcade: firing lane, receiver and shutter kit

**Outcome:** The combat puzzle communicates projectile paths, protected sides and a usable timed service route.


**A07.1** Author a shielded impact-receiver housing around the actual input target and hood geometry. Keep its exposed face and protected back distinguishable from approach and bait positions; do not paint false targets on noninteractive panels.


**A07.2** Build the gunner emplacement and visible muzzle mounting using the current ranged enemy envelope. Art supports the new telegraph hook but does not retime the shot or decide where its aim is committed.


**A07.3** Dress the bait lane and safe alcove so their spatial relationship reads without an instruction wall. Floor/sidewall markings must not require colour discrimination alone and must not obscure a projectile at normal speed.


**A07.4** Make the eight-second service shutter visually operable through exposed tracks, a moving leaf and addressable interval indicator. Use the runtime interval as data; a looping animation is not the countdown authority.


**A07.5** Build the far release and permanent-open state so it is visibly different from a briefly powered opening. Preserve the designed alternate completion when the gunner is killed; do not barricade its access with art.


**A07.6** Capture the real sightline, blocked-counterpart cover, timed-open state and permanently released state. Provide art-off/on alignment views and identify any unsupported animation hook precisely.


**Completion boundary:** Receiver, gunner mount, service shutter and release read consistently and preserve both intended solution routes.


### A08 — Unweighted Switch: semantic-weight machine and crate kit

**Outcome:** The contradiction can be read before the player discovers the Status solution.


**A08.1** Fit the manipulable crate visual to the current 200 kg test body and usable one-metre stepping top, taking actual values from the consumer rather than permanently baking them into every crate. Use the existing physical-object family if suitable.


**A08.2** Build the HEAVY-class plate frame, recess walls and glyph carrier. Its display communicates a semantic class; do not reuse the accumulating-kilogram gauge as though the two sensors mean the same thing.


**A08.3** Create the guided-drive housing and its lever/supports without implying freehand picking up is the only solution. Protect the travel path, parked/engaged positions and footprint that the room tests.


**A08.4** Make LIGHTENED presentation visible through the shared supported marker/state hook. The crate must retain apparent physical height, solid corners and stepping surface; no shrink, ghost collision, float away or mass-label change that contradicts runtime.


**A08.5** Build the high shutter frame/leaf, applicator housing, far bolt and return-stair release using separately operable parts. Show temporary open and permanently bolted states distinctly without adding a base-kit stair before completion.


**A08.6** Inspect before/during/after expiry, the disconnected control case and the final bolted state through actual camera positions. Record whether the marker is runtime-bound or a visual-only state demonstration.


**Completion boundary:** The material-handling kit accurately distinguishes mass class, kilograms, collision and permanent versus temporary progress.


### A09 — Cross-room machinery communication and branch identity

**Outcome:** The player can connect a source-room action with a destination-room consequence.


**A09.1** Adapt Batch043 conduit/state assets into straight, elbow, tee, junction-box and wall-penetration visual assemblies. Do not build a gameplay signal bus; the model is a readable presentation of declared relationships.


**A09.2** Build variable-control bezels and reader panels with runtime-populated labels and distinct selected/unselected/blocked/pending appearances. Persistent configuration, a held input and a permanent repair must not share a misleading identical switch pose.


**A09.3** Supply paired branch/room identity plaques and direction blades using approved navigation shapes. Same identifier can appear at source and destination; avoid relying only on a remotely placed popup the player never sees.


**A09.4** Prepare local mechanical acknowledgments—indicator flag, switch detent, gauge needle or visible breaker—whose motion can reflect real accepted/refused/deferred state. Do not animate success ahead of the authoritative result.


**A09.5** Build nonblocking relay/generator/service assemblies that explain why several rooms belong to one installation. Reuse them in the actual branch footprint rather than making a new giant hero room.


**A09.6** Provide a three-view evidence strip from source, connecting route and destination with the same relationship ID. Include an unpowered/deferred state and a reverse traversal view; no private lighting or geometry change to make the connection look obvious.


**Completion boundary:** A reusable branch-scale visual language conveys real relationship state while the runtime remains authoritative.


### A10 — Existing ten-role enemy family: production assets and animation readiness

**Outcome:** Prod receives usable versions of the approved roster instead of another folder of static concepts.


**A10.1** Inventory latest applicable exports for melee, ranged, brute, scuttler, charger, bulwark, artillery, beacon, drifter and diver. Prefer later envelope-fitted production batches over early proposals. Preserve approved identities and record exact source/asset versions.


**A10.2** Inspect topology, normals, material roles, handedness, local front, floor/flight origin and physical envelope for each. Correct source/export defects without replacing the role’s governing silhouette or changing its collider contract.


**A10.3** Provide rigs or articulated rigid-part transforms only where the role needs motion. Export named muzzle, warning, weak-side/shield, body-centre and effect anchors where specified; no hitbox or damage logic inside the model.


**A10.4** Supply appropriate visual-only clips or pose resources for idle/work, locomotion/hover, notice, committed attack, recovery, stagger and death where supported. Do not multiply identical loops across all roles: a charger’s brace and a drifter’s hover serve different reads.


**A10.5** Agree attack-phase markers and animation-control responsibilities with Prod. Gameplay determines attack timing, root translation, interruption and whether an enemy is dead; the art can stretch presentation to an authoritative phase rather than issuing a second damage event.


**A10.6** Deliver role-by-role readiness views at shared gameplay distance, plus silhouette and clay controls, and one actual consumer import per distinct rig/assembly pattern. An unsupported role can be art-ready without being spawnable; state both facts.


**Completion boundary:** All ten existing roles have truthful, fit-checked asset readiness and usable state/attachment resources; no new roster is invented.


### A11 — Enemy jobs and inhabited-space visual support

**Outcome:** The runtime’s pre-combat routines have believable motions and objects to work with.


**A11.1** Take Prod/Dess’s declared jobs and prepare the matching small motion clips: inspect, scan, recharge, service, guard, perch, transport or return-to-post as applicable. Do not invent a new behavioural controller merely to stage an animation.


**A11.2** Build compatible service pedestals, charging sockets, inspection panels, perches and maintenance props inside agreed footprints. Avoid one oversized docking station for every enemy regardless of role.


**A11.3** Make entry/exit blends and interruption-safe rest poses so noticing the player does not leave a hand through a panel or a flyer attached to an invisible point. Runtime transition selection remains Prod’s.


**A11.4** Show where a patrol/inspection routine is going without adding automatic navigation links. Small floor/service cues and tool storage can support the job; decorative marks are not promises of reachable geometry.


**A11.5** Create a readable idle-to-alert comparison for one ground role, one planted role and one flyer using the existing silhouettes. Keep Epsilon optic identity and attack warning semantics separate.


**A11.6** Deliver job props with role/pose compatibility and tested attachment transforms. If no runtime job contract exists yet, mark clips as candidates and continue other roles; do not call the room inhabited solely because objects were placed in it.


**Completion boundary:** Reusable job/prop resources match real or explicitly proposed runtime routines and do not change encounter placement.


### A12 — Projectiles, telegraphs, impacts and support-device presentation

**Outcome:** Combat variety is visible and enemies do not all communicate through the same flash.


**A12.1** Reuse the approved straight, falling and lobbed projectile assets and inspect their current envelopes/origins. Build only missing compatible role presentations, such as a diver approach trail or artillery impact marker, after the role contract is known.


**A12.2** Bind or prepare the shared telegraph node to telegraph_started/finished/progress/origin or its current equivalent. Use existing warning semantics, and prove cancel is distinguishable from attack-completed.


**A12.3** Make charger direction/commitment, bulwark protected face, artillery warned ground, beacon support range and flyer approach legible through shape and motion without inventing extra collider coverage.


**A12.4** Provide wall-hit, shield-hit, body-hit, miss and interruption visual assets where the runtime distinguishes them. Avoid identical response for a refused effect and a damaging hit.


**A12.5** Check that warnings and projectiles remain legible against at least a pale, dark and busy proposed pack. Foreground effects must not cover the player’s weapon aim, target face or landing edge.


**A12.6** Record actual node counts, particles/material passes where used and imported resources. Keep audio composition and gameplay warning timing with their owners; missing audio is a handoff, not a reason to invent a second combat system.


**Completion boundary:** Telegraph/projectile assets are stateful, performant and compatible with the existing enemy pipeline.


### A13 — Reuse and finish the Status/compound visual grammar

**Outcome:** The new object and enemy effects share readable visual semantics rather than per-room inventions.


**A13.1** Recover Batch043’s thirteen Status glyphs, eight compound glyphs, family frames and duration/ownership work. Inspect the exported kit and actual supported target map before declaring a glyph absent or a Status implemented.


**A13.2** Correct or adapt the effective Design 6 list, including exposed and its modified semantics. Legacy burning and Amalgam burning are not visually re-labelled as identical runtime behavior; name the compatibility distinction where it matters.


**A13.3** Provide world-space marker, target attachment and player-display resources that remain legible across object/actor/player/surface/volume contexts actually supported. Do not demonstrate a forbidden target/effect pair as if the engine applied it.


**A13.4** Make duration, refresh, expiry, immunity/refusal and compound anticipation distinguishable by the existing frame/motion grammar. Keep the Status ID separate from the feedback channel ID so one wrong string does not become a silent cue.


**A13.5** For compounds, show constituent-to-compound relationships without requiring a giant matrix. Resource creation is allowed for the accepted catalogue; runtime-unsupported pairs remain preview-only, never emitted or declared supported from Art.


**A13.6** Test marker size/occlusion against the current gameplay camera and three contrasting material backgrounds. Reuse the established glyph generator; do not start a second Status icon vocabulary.


**Completion boundary:** A complete, compatible visual kit exists for the accepted catalogue, with implementation/support status kept separate.


### A14 — Manipulation objects, transport interfaces and constraint hardware

**Outcome:** Physical verbs operate on believable objects with readable handling and attachment points.


**A14.1** Recover the twelve Batch043 physical-object candidates and later revisions: generic, weighted, power cell, key component, mechanical part, movable cover, cart, girder, ballast, plate, drum and anchor block. Decorative siblings stay distinct from interactable bodies.


**A14.2** Add or correct grasp, tether, pin, hinge, payload and socket attachment points against actual consumers. An anchor block and a grapple anchor have different uses despite sharing a word; keep them visually distinguishable.


**A14.3** Build modular winch drum, cable guide, brake caliper, driver housing, hinge, slide, rail clamp and joint-cover pieces for the accepted constraints. Art does not supply constraint forces or limits; it fits their measured sweep.


**A14.4** Prepare transported-object housings and receiver sockets that visually communicate insertion, ownership, carried/parked state and accepted/blocked fit. Do not duplicate an object mesh and call it persistent cross-room transport.


**A14.5** Make permanent attachment, temporary hold, released constraint and blocked motion readable. Preserve collision clarity for objects used as steps or cover; a translucent Status overlay must not make a solid foothold disappear.


**A14.6** Export one inspectable assembly per distinct hardware function plus fit metadata and state endpoints. If a runtime constraint does not yet exist, keep the asset as a dimensioned candidate rather than claim its physical behavior was tested.


**Completion boundary:** Existing physical families are usable and constraint/transport art has explicit mechanical fit rather than speculative mass changes.


### A15 — Compositional item, equipment and Forge visual modules

**Outcome:** The approved item systems have usable visual pieces without introducing another mechanic or economy.


**A15.1** Inventory existing item-display, weapon, gear, component and Forge/Hub assets before expanding. Preserve the locked Check identity and source-item attribution; a new prop must not replace the actual AP reward representation.


**A15.2** Build compatible modular housings/attachments for supported projectile, melee, beam or utility item families at their actual camera/display scale. Separate first-person readability from a world pickup silhouette.


**A15.3** Provide sockets for known effect/muzzle/grapple/tether presentation. Do not make a cosmetic barrel length change the hitscan origin, reach, damage or provider qualification.


**A15.4** Create visual holders/trays/clamps for the accepted Forge transactions and their confirmation/result states. Costs, recipes, destruction and currency logic remain outside Art; unknown policy does not justify a fictional screenshot claiming a completed purchase.


**A15.5** Produce clear item-category frames and approved property/state emblems with transparent or neutral backgrounds as the existing UI pipeline requires. Reuse the source-identity and Status kits; no new uncited pseudo-language that conflicts with navigation.


**A15.6** Deliver a modest interoperable parts library and an assembly guide describing which combinations are visual-compatible. Do not promise every combinatorial item is visually unique or count generated permutations as authored models.


**Completion boundary:** Item/Forge art supports existing or explicitly proposed consumers while leaving all build/economy meaning untouched.


### A16 — Finish the six existing theme families and reusable branch dressing

**Outcome:** The base library works through the real binder and supplies the foundations for new game packs.


**A16.1** Audit concrete_facility, rusted_industrial, neon_transit, gothic_stone, temple_ruin and void_glitch against the current binder, latest Art theme exports and Deep-Space Derelict proofs. Record reuse versus missing integration rather than recreate the same tiles.


**A16.2** Ensure floor/wall/trim/accent roles, authored pixel coverage, stable physical tile scale and supported optional fallback roles exist for each applicable pack. The shared hazard material remains universal.


**A16.3** Repair directional materials and front/back signs using the actual surface pipeline: authored UVs and procedural triplanar use are different consumers. Test yawed and opposite surfaces rather than trusting one origin-facing view.


**A16.4** Complete a restrained services/dressing palette for branches: panel bays, vent covers, cable supports, light housings, transit signs, structural wraps and one reusable nonblocking landmark per established visual family where already allowed.


**A16.5** Prove theme swaps on the same geometry and gameplay state. Compare protected materials, control silhouettes, transparent surfaces and route readability without changing lighting to conceal an unreadable pack.


**A16.6** Deliver the corrected base export as a coherent source+assets slice and a table of which runtime consumers already bind it. Use this as the baseline for new packs, not as a reason to overwrite all approved aesthetics.


**Completion boundary:** The current six-family foundation is verified or its precise missing hook is named; reuse is credited honestly.


### T01 — Ocarina of Time — Grove Relay Temple

**Outcome:** A timber-and-weathered-stone temple service network with leafy external silhouettes and deliberately mechanical interiors.


**T01.1** Reference and reuse pass for **Ocarina of Time**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A timber-and-weathered-stone temple service network with leafy external silhouettes and deliberately mechanical interiors. Record this as an original production interpretation, not a claim of an official asset pack.


**T01.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Design paired mossy/maintained material variants and visibly jointed wood; keep decorative carving low enough in contrast that interactable handles win. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T01.3** Build a reusable architectural-facing kit: Root-braced columns, carved lintels, aged plank insets, inset masonry courses and perforated clerestory screens. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T01.4** Build a useful prop and machinery-housing kit: A suspended wooden machine cradle, a carved control dais, rope-and-pulley housings, sealed stone service doors and ceramic counterweight containers. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T01.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Contrast the central vertical mechanism with an acquisition-branch service walk; the pack changes construction language, not the gantry’s reach or the route. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T01.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Blindside gantry/dock treatment plus a neutral temple branch slice; do not reproduce a named dungeon layout. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T02 — Super Mario 64 — Clockwork Garden

**Outcome:** Chunky, bright masonry and oversized readable mechanical parts: a tactile clockwork-garden interpretation in Archipepsi scale.


**T02.1** Reference and reuse pass for **Super Mario 64**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: Chunky, bright masonry and oversized readable mechanical parts: a tactile clockwork-garden interpretation in Archipepsi scale. Record this as an original production interpretation, not a claim of an official asset pack.


**T02.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Use original geometric tile and dial motifs; colour variety belongs to structure and landmarks, never a per-theme redefinition of damage or grapple colours. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T02.3** Build a reusable architectural-facing kit: Broad brick bands, plaster recesses, stone corner blocks, patterned pavers and inset window frames with strong structural hierarchy. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T02.4** Build a useful prop and machinery-housing kit: Large gear casings, pendulum housings, clock-face panel bezels, planter barricade dress and rounded transport control pedestals. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T02.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Passing Platforms receives clockwork housings and readable carrier routes; decorative gears do not become automatic new stepping surfaces. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T02.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Lift/shuttle and one fixed branch composition at unchanged collision; avoid copying castle rooms or official symbols. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T03 — Bomb Rush Cyberfunk — Afterhours Municipal Transit

**Outcome:** A bold transit-maintenance pack that develops the existing neon_transit family rather than repainting it once more.


**T03.1** Reference and reuse pass for **Bomb Rush Cyberfunk**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A bold transit-maintenance pack that develops the existing neon_transit family rather than repainting it once more. Record this as an original production interpretation, not a claim of an official asset pack.


**T03.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Use authored abstract lettering/graphic motifs with legible front/back variants; keep new logos fictional and separate from interaction markers. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T03.3** Build a reusable architectural-facing kit: Concrete platforms, tiled service walls, layered metal shutters, station canopy pieces, vent banks and modular sign rails. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T03.4** Build a useful prop and machinery-housing kit: Ticket/service kiosks, equipment lockers, signal housings, portable barrier props, speaker shells and original graphic panels. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T03.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Blindside becomes an actual transit worksite, with route IDs repeated at distant readers and overhead control access clearly visible. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T03.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: One railway docking corner, one branch relay scene and the same neutral room used for base neon_transit A/B. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T04 — Super Metroid — Pressureworks Derelict

**Outcome:** An alien-industrial pressure facility with rounded containment ribs and organic surface incursions, extending the existing derelict work where useful.


**T04.1** Reference and reuse pass for **Super Metroid**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: An alien-industrial pressure facility with rounded containment ribs and organic surface incursions, extending the existing derelict work where useful. Record this as an original production interpretation, not a claim of an official asset pack.


**T04.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Separate weathered industrial surfaces from living-looking insets with original pixels and material placement, not a borrowed texture atlas. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T04.3** Build a reusable architectural-facing kit: Ribbed bulkhead wraps, segmented tube seams, recessed duct panels, pressure-window frames and nonblocking growth cladding. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T04.4** Build a useful prop and machinery-housing kit: Containment cylinder shells, sealed sample drawers, conduit manifolds, suspended machinery pods and pressure-door service housings. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T04.5** Prepare compatible appearances for supported controls and at least one existing setpiece. A cross-room power relationship can be followed through containment/service language; watery vistas are decorative, not a swimming mechanic. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T04.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Counterfire service branch and a pressure-control room, with all shots and openings unchanged; no morph-ball-sized mandatory passages. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T05 — Kingdom Hearts 2 — Twilight Service District

**Outcome:** A whimsical inhabited municipal district expressed through warm masonry, tall rooflines and transit/service machinery.


**T05.1** Reference and reuse pass for **Kingdom Hearts 2**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A whimsical inhabited municipal district expressed through warm masonry, tall rooflines and transit/service machinery. Record this as an original production interpretation, not a claim of an official asset pack.


**T05.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Make a deliberate daylight/dusk material pair without forcing a renderer change; inherited universal signals keep their meanings. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T05.3** Build a reusable architectural-facing kit: Layered plaster/stone bays, tapered roof canopies, ornamental iron wraps, sloped trim and deep framed windows. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T05.4** Build a useful prop and machinery-housing kit: Clockwork service cabinets, noticeboard housings, baggage carts, lamp brackets, original civic emblems and a tower-machine landmark fragment. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T05.5** Prepare compatible appearances for supported controls and at least one existing setpiece. The same rail junction can look like city infrastructure rather than a factory test: keep deck and camera envelopes while changing visual construction. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T05.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Blindside shelter and acquisition-branch streetside interior; no new characters or copied world map. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T06 — DOOM 1993 — Foundry Containment

**Outcome:** An aggressive retro industrial pack with heavy panels, recessed service hardware and stark containment transitions.


**T06.1** Reference and reuse pass for **DOOM 1993**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: An aggressive retro industrial pack with heavy panels, recessed service hardware and stark containment transitions. Record this as an original production interpretation, not a claim of an official asset pack.


**T06.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Create original low-resolution panel/damage textures; a visually hazardous fluid never gets a false damage promise, and universal danger marking stays shared. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T06.3** Build a reusable architectural-facing kit: Bolted panel courses, vent/bulkhead wraps, ribbed steel, concrete bands, inset industrial glazing and damage-safe decorative recesses. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T06.4** Build a useful prop and machinery-housing kit: Breaker consoles, coolant pipe shells, inspection lockers, barrel dressing, warning pylons and compact machine stacks. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T06.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Counterfire’s protected receiver and firing lane should read immediately; do not turn cover/no-cover differences into dark indistinguishable walls. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T06.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Counterfire art-on/off camera set plus a rail service corner. DOOM II is not silently counted as a second wholly new pack. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T07 — Dark Souls III — Cinder Aqueduct

**Outcome:** A ruined stone service landscape with ash, corroded iron and monumental support structures, kept readable under gameplay lighting.


**T07.1** Reference and reuse pass for **Dark Souls III**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A ruined stone service landscape with ash, corroded iron and monumental support structures, kept readable under gameplay lighting. Record this as an original production interpretation, not a claim of an official asset pack.


**T07.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Keep large-value structure and restrained soot variation; avoid flat black-on-black surfaces that conceal routes or enemy silhouettes. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T07.3** Build a reusable architectural-facing kit: Masonry courses, fractured arch wraps, aqueduct pier cladding, corroded metal screens, worn stairs skins and roof-rib ornaments. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T07.4** Build a useful prop and machinery-housing kit: Winch/chain housings, bell-like control shrouds, weathered vessels, sealed utility reliquaries and root-clogged service grilles. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T07.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Present the skiff and gantry as an old hoist service surviving the ruin; decorative collapsed rubble must not restore the inaccessible route. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T07.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Junction/control pair and a minor-room control case. Ruined texture is not permission to introduce collision holes. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T08 — The Wind Waker — Harbour Windworks

**Outcome:** A bold maritime maintenance pack using carved timber, rope, painted metal and wind-service motifs.


**T08.1** Reference and reuse pass for **The Wind Waker**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A bold maritime maintenance pack using carved timber, rope, painted metal and wind-service motifs. Record this as an original production interpretation, not a claim of an official asset pack.


**T08.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Build original broad-painted textures with readable grain direction and restrained edge accents; ropes must meet attachments instead of floating near them. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T08.3** Build a reusable architectural-facing kit: Timber dock wraps, stone quay courses, rope-rail visuals, canvas canopy pieces, slatted vent panels and curved window trims. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T08.4** Build a useful prop and machinery-housing kit: Capstans, wind-vane housings, mooring fittings, cargo crates, pulley blocks, lantern housings and a service mast. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T08.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Blindside’s carrier is visually harbour machinery on rails, not a freely sailing boat; the package does not enable water traversal. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T08.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Skiff/dock/gantry triptych on unchanged runtime geometry, plus a class-sensitive cargo recess. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T09 — Hollow Knight — Lamplight Conservatory

**Outcome:** A subterranean civic conservatory with delicate-looking iron and carved stone translated into robust, legible 3D forms.


**T09.1** Reference and reuse pass for **Hollow Knight**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A subterranean civic conservatory with delicate-looking iron and carved stone translated into robust, legible 3D forms. Record this as an original production interpretation, not a claim of an official asset pack.


**T09.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Translate the reference atmosphere through depth and silhouette rather than flat picture billboards; do not commission realistic spider models or imagery. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T09.3** Build a reusable architectural-facing kit: Narrow arch wraps, layered cornice, ribbed window screens, ceramic tile insets, column collars and hanging planter supports. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T09.4** Build a useful prop and machinery-housing kit: Bell-shaped control casings, bench/service furniture, sealed specimen jars, lamp housings and original ornamental door plaques. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T09.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Branch power/reversible-state indicators sit in decorative housings without hiding their readable states; approved Archipepsi enemies retain their own forms. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T09.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Conservatory service branch and one existing minor dressed at actual first-person scale; no new enemy family. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T10 — Terraria — Layered Mineworks

**Outcome:** A playful but constructed mining/ruins pack that translates layered material identity into the project’s 3D architecture.


**T10.1** Reference and reuse pass for **Terraria**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A playful but constructed mining/ruins pack that translates layered material identity into the project’s 3D architecture. Record this as an original production interpretation, not a claim of an official asset pack.


**T10.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Build the base stone/ore/crystal/lumber hierarchy with distinct scale and original textures; avoid extruding flat sprite art into identical shallow cards. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T10.3** Build a reusable architectural-facing kit: Stratified rock face tiles, brick-retaining frames, mine timber wraps, ore-vein accent pieces, platform-edge supports and service grilles. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T10.4** Build a useful prop and machinery-housing kit: Mine-cart shells, crystal sample housings, hoist drums, furnace casings, tool racks and sealed supply containers. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T10.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Passing Platforms and Unweighted become lifting/material-handling installations. Decorative mine carts do not imply an operable additional vehicle. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T10.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Lift room at unchanged motion envelope plus an Unweighted sensor close view showing semantic-class readability. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T11 — TUNIC — Moss Archive

**Outcome:** A compact geometric ruin/technology pack with weathered stone, moss and ordered buried machinery.


**T11.1** Reference and reuse pass for **TUNIC**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A compact geometric ruin/technology pack with weathered stone, moss and ordered buried machinery. Record this as an original production interpretation, not a claim of an official asset pack.


**T11.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Author an original geometric motif family that cannot be mistaken for gameplay instructions; important interaction glyphs remain the established shared set. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T11.3** Build a reusable architectural-facing kit: Stepped stone cladding, carved panel recesses, ceramic/metal inserts, portal-like structural frames and understated geometric trims. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T11.4** Build a useful prop and machinery-housing kit: Monolith-shaped reader housings, small service pylons, stone equipment cradles, original page/sign plaques and planted drainage features. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T11.5** Prepare compatible appearances for supported controls and at least one existing setpiece. The branch and central junction share a visible service identity; small-scale ornament must not make the player’s actual passage feel too narrow. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T11.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: State setter/reader pair and same-size room A/B with another pack. No copying the reference game’s language or puzzle solutions. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T12 — Sonic Adventure 2 Battle — Gravity Transit

**Outcome:** A crisp high-speed industrial/space-transit presentation with strong direction, bolted hardware and dramatic large-scale framing.


**T12.1** Reference and reuse pass for **Sonic Adventure 2 Battle**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A crisp high-speed industrial/space-transit presentation with strong direction, bolted hardware and dramatic large-scale framing. Record this as an original production interpretation, not a claim of an official asset pack.


**T12.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Use original bold stripe/number systems outside the protected hazard language. Never assume a stripe grants a speed pad or a loop changes gravity. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T12.3** Build a reusable architectural-facing kit: Panelled viaduct wraps, truss cladding, service-bay doors, capsule-window frames, vent panels and angular canopy segments. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T12.4** Build a useful prop and machinery-housing kit: Traffic-control housings, roller/guide machinery, container modules, fan casings, cargo-handling arms and route-marker brackets. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T12.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Make the rail’s curve and docking destinations easy to read from a moving deck without requiring a new camera or faster runtime travel. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T12.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Curved rail/dock review scene plus projectile/telegraph visibility proof on the busiest materials. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T13 — A Link to the Past — Mosaic Waterworks

**Outcome:** A patterned castle/ruin water-service interpretation with strong masonry shapes and colourful inset panels.


**T13.1** Reference and reuse pass for **A Link to the Past**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A patterned castle/ruin water-service interpretation with strong masonry shapes and colourful inset panels. Record this as an original production interpretation, not a claim of an official asset pack.


**T13.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Keep water motifs a presentation layer until a real water consumer exists. Shared receivers must remain recognisable in the ornament. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T13.3** Build a reusable architectural-facing kit: Mosaic bands, masonry arches, carved pier wraps, tiled basins used only where safe and channel-cover cladding. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T13.4** Build a useful prop and machinery-housing kit: Valve-wheel housings, ceramic control faces, sluice casings, storage urns, stone counterweights and original floor medallions. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T13.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Style a reversible branch-control and lift installation, preserving routes and all current interlocks. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T13.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: One full branch slice with source and reader in different existing rooms; not a reconstruction of a source dungeon. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T14 — Factorio — Assembly Annex

**Outcome:** Dense but ordered assembly infrastructure: heavy material handling, processing modules and visible mechanical interfaces.


**T14.1** Reference and reuse pass for **Factorio**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: Dense but ordered assembly infrastructure: heavy material handling, processing modules and visible mechanical interfaces. Record this as an original production interpretation, not a claim of an official asset pack.


**T14.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Mechanical density must remain in nonblocking volumes; do not add a simulated production economy or functional belt merely because its housing exists. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T14.3** Build a reusable architectural-facing kit: Sheet-metal bays, catwalk wraps, riveted beams, recessed utility floors, duct segments and factory partition cladding. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T14.4** Build a useful prop and machinery-housing kit: Assembler shells, pipe junctions, conveyor side housings, crane supports, drum racks and control enclosures. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T14.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Constraint/transport-object and Unweighted visual kits gain shared handling points and clear physical-class signals. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T14.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: One working physical-puzzle composition and a wide/close detail pair; no room clutter added to spend an art budget. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T15 — Subnautica — Pressure-Garden Station

**Outcome:** A marine-research enclosure with bright structural shells and an organic exterior silhouette seen through framed vistas.


**T15.1** Reference and reuse pass for **Subnautica**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A marine-research enclosure with bright structural shells and an organic exterior silhouette seen through framed vistas. Record this as an original production interpretation, not a claim of an official asset pack.


**T15.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Keep clean/overgrown variants functionally equivalent. Exterior water is visual-only; no swimming, oxygen or flooded-route mechanic is introduced. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T15.3** Build a reusable architectural-facing kit: Rounded station panels, gasket trims, pressure window wraps, ribbed utility floors and modular plant containment cladding. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T15.4** Build a useful prop and machinery-housing kit: Sample lockers, filtered tank housings, specimen racks, hatch frames, service pods and exterior vista-only growth props. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T15.5** Prepare compatible appearances for supported controls and at least one existing setpiece. A cross-room research relay and mechanical lift remain readable through the same controller; wet glass does not occlude targets. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T15.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: Closed station interior on existing collision plus an explicitly decorative external vista; no source model extraction. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T16 — Blasphemous — Processional Foundry

**Outcome:** A solemn stone-and-metal processional works with a strong handmade silhouette and industrial machine readings.


**T16.1** Reference and reuse pass for **Blasphemous**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A solemn stone-and-metal processional works with a strong handmade silhouette and industrial machine readings. Record this as an original production interpretation, not a claim of an official asset pack.


**T16.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Use original ornament and controlled wear. Avoid decorative religious-looking glyphs being confused with Check, ability or hazard states. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T16.3** Build a reusable architectural-facing kit: Carved masonry borders, vertical buttress wraps, aged plaster panels, grilles and arched machinery frames. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T16.4** Build a useful prop and machinery-housing kit: Processional lamp housings, votive-like noninteractive dressing, bell/chain hoists, carved service plaques and battered equipment cases. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T16.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Counterfire and a relay branch become ceremonial machinery spaces without changing projectile fairness or the far release. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T16.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: A complete original branch environment and a stateful shutter render; no new boss or combat role. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T17 — A Hat in Time — Clockwork Station Quarter

**Outcome:** A theatrical compact station/services pack with playful proportions and layered practical construction.


**T17.1** Reference and reuse pass for **A Hat in Time**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: A theatrical compact station/services pack with playful proportions and layered practical construction. Record this as an original production interpretation, not a claim of an official asset pack.


**T17.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Keep decorative text and props subordinate to controls. Whimsy is in form and composition, not random saturation or a new UI palette. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T17.3** Build a reusable architectural-facing kit: Painted wood/brick bay wraps, station awnings, framed wall inserts, brass-like trim and oversized service-panel borders. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T17.4** Build a useful prop and machinery-housing kit: Luggage carts, ticket enclosures, original poster frames, baggage racks, clockwork utility boxes and parcel containers. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T17.5** Prepare compatible appearances for supported controls and at least one existing setpiece. Blindside platforms and Passing Platforms share a station language while the vertical and horizontal carriers remain visibly different. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T17.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: One docking corner and one full minor-camera review with no new routes or passenger NPC simulation. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### T18 — Risk of Rain 2 — Basalt Relay Outpost

**Outcome:** An exposed alien outpost with monumental natural structure and compact industrial equipment embedded into it.


**T18.1** Reference and reuse pass for **Risk of Rain 2**: verify official included-game membership, gather attributable primary visual references, and compare the actual existing packs. Proposed identity: An exposed alien outpost with monumental natural structure and compact industrial equipment embedded into it. Record this as an original production interpretation, not a claim of an official asset pack.


**T18.2** Author the required floor/wall/trim/accent set and compatible optional visual roles. Use restrained painted material blocks and readable long-range silhouettes; approved Epsilon green and enemy warnings retain their meaning. Include physical tile coverage and neutral/production-light swatches. Universal hazard/Check/Epsilon roles are protected and do not become pack-specific pixels.


**T18.3** Build a reusable architectural-facing kit: Basalt-like stratum wraps, fractured retaining panels, equipment plinth skins, angular metal canopies and service-wall insets. Start with approximately 8–12 genuinely useful modules or verified reused equivalents, fitted around the accepted openings and routes. Do not count mirrored exports as new structural inventions.


**T18.4** Build a useful prop and machinery-housing kit: Beacon housings, cargo equipment, field relays, original sensor masts, rock-root vista modules and utility shelter parts. Aim for roughly 6–10 distinct useful items or confirmed compatible reuses, plus one modest original landmark assembly. Mark new hero direction pending review; do not flood a room with every item.


**T18.5** Prepare compatible appearances for supported controls and at least one existing setpiece. A large-room environmental setting shows how the existing machinery reads across distance without placing new climbable terrain or hiding a flyer. Provide state-addressable meshes and pivot/attachment metadata; no new collision, rules, timers, game IDs or required paths.


**T18.6** Complete and import the pack using existing export/ThemePack paths or their agreed presentation-selection addition. Required proof: A fixed-layout major/branch presentation and a three-role enemy-distance lineup on its backgrounds. Supply source/export hashes, a same-camera comparison, a near-surface inspection, and the exact runtime-binding/owner-review status.


**Completion boundary:** A coherent original environment kit and at least one compatible stateful assembly are exported, imported, visually inspected and ready for the named selection path; new visual direction remains review-pending.


### A17 — Reusable architectural detail and natural/industrial dressing library

**Outcome:** The art backlog remains useful after the named setpiece models are delivered.


**A17.1** Fill verified gaps in ordinary-room architectural facing: door reveals, wall corner caps, ceiling transitions, bay terminations and support wraps. Preserve the existing nineteen/succeeding shell families and do not start a new authored-room wave.


**A17.2** Build finite reusable dressing clusters for credible workspaces: maintenance equipment, storage, service benches and damaged-but-nonblocking hardware. Tag footprint, attachment mode and visibility requirements rather than placing arbitrary clutter in the game.


**A17.3** Create natural/ruined cladding for the listed packs—roots, strata, moss masses and broken trim—whose bounds respect traversal and shooting. No realistic spider imagery or extra creature roster.


**A17.4** Provide mixed-theme transition pieces so an Epsilon intrusion or foreign-game accent meets the human facility deliberately. Demonstrate the same material/geometry base with a controlled local treatment, not every material changed at once.


**A17.5** Recover approved scene landmarks and offer compatible close/mid-distance derivatives only when useful. A new large hero proposal can be built as a review candidate, but approval is not inferred from the existing family’s PASS.


**A17.6** Deliver cluster manifests with constituent IDs, shared resources and measured scene costs. A cluster is an assembly of assets, not a collection of new model counts; Production decides when/how it is placed.


**Completion boundary:** Reusable detail fills real gaps without adding room topology, unreviewed enemies or accidental collision.


### A18 — Actual-consumer trials, budget passes and corrective production

**Outcome:** Assets are usable under the game’s materials, camera, motion and imports rather than only in a flattering bench.


**A18.1** Run each major asset family through the current agreed consumer path in a pinned combined test tree. Test representative rotated/non-origin placements and state transitions; name any family still imported but unbound.


**A18.2** For each pack, prove authored pixels are sampled rather than a procedural fallback. Inspect descriptor/role resolution and at least one GPU-visible comparison through the real ThemePack/ThemeMaterials path where applicable.


**A18.3** Compare the same mechanical scene before/after art with identical camera, geometry and runtime lighting. Inspect controls, enemies, cover, landing edges and projectile paths at gameplay distance; do not fix readability by secretly changing gameplay light values.


**A18.4** Run scene-level resource checks: material surfaces, visible triangles, texture memory/import sizes and actual draw/renderer observations when available. Optimize the specific expensive asset or redundant resource while retaining legibility; report hardware and tool versions for performance numbers.


**A18.5** Address verified art faults in their source: missing pivots, clipped muzzle, covered grapple ring, reversed arrows, shimmering texture scale, invisible unpowered state or state node lost in export. Re-test the affected consumer rather than just regenerating a turntable.


**A18.6** Keep deliberately broken controls for import/mapping/visibility contracts focused. A raycast suite belongs to Prod’s gameplay authority; Arty’s fit trials do not declare a route universally solvable, an enemy fair, or the whole Zone complete.


**Completion boundary:** Each delivered family has truthful actual-consumer or exact-blocker evidence and no unreported presentation/fit regression.


### A19 — Final catalogue, integration handoff and continuation checkpoint

**Outcome:** Prod can install the delivery and the owner can review it without spelunking dozens of undocumented folders.


**A19.1** Build a compact review index grouped by the four setpieces, ten existing enemy roles, shared effect/object kits and the 18 reference packs. Each entry opens its actual files and evidence; avoid a single unreadable wall of tiny thumbnails.


**A19.2** Produce source+export manifests with stable asset IDs, sizes, roles, attachments, clips, supported states, source refs, hashes, review state and tested consumer. Keep runtime JSON restricted to its true schema.


**A19.3** Deliver coherent integration slices to Prod throughout the run and a final delta list at handoff. Ask for receipts only through available authorized collaboration; do not claim installation merely because a commit or a ZIP exists.


**A19.4** Separate completely new models, modified/reused assets, shared textures, state variants, assemblies and completed packs in the totals. An eight-state export is not eight unique enemies. List what remains ready, blocked and unfinished.


**A19.5** Commit/push the intended art sources and outputs, verify a clean checkout/import subset and preserve logs/screenshots plus an exact reproducibility command. Finish the affected full art gate on a fixed tree; unrelated runtime CI failure is not a reason to waive an art failure.


**A19.6** Stop with the best coherent delivered checkpoint and a concise next-ready task. No watcher or future wake-up remains. Human review is pending unless an actual owner verdict was received; no “all 0.4 art complete” claim if this queue or its integration is unfinished.


**Completion boundary:** A durable, inspectable, installable art delivery exists with exact limitations and no automatic continuation scheduled.


## 8. Cross-cutting acceptance: the difference between a pack and a folder

### Complete game-pack floor

For each completed reference pack, show its coherent architecture/material/prop vocabulary together at gameplay scale. The target of roughly 8–12 architectural modules and 6–10 useful props is a planning guide, not a demand to make meaningless assets. A verified reusable item can satisfy a need, but the pack must still earn its distinct identity through actual construction, material pattern and original focal assemblies. A pack of existing greyboxes with a different accent is incomplete.

Required export roles and candidate-specific optional roles must resolve deliberately; extra shader channels unsupported by the current pipeline do not become hidden dependencies. The same gameplay object retains its functional silhouette and protected signals across skins. Style choices may differ substantially between the 18 source-inspired kits while remaining compatible with Archipepsi's retro 3D language.

Prioritize original models that solve a present placement or presentation need. Do not make new world layouts, playable creatures, item mechanics or quests to justify a pack. References from 2D games are translated into 3D space and construction, not used as proof that paper sprites are adequate first-person scenery. References from modern games are simplified intentionally, not represented as noisy high-poly meshes compressed into a low-poly budget.

### Technical floor versus human approval

A render at a neutral camera can establish visible geometry and material appearance, not enjoyment. A named animation clip can establish a loadable pose resource, not enemy behavior. A `.glb` import can establish that a resource loads, not that Production selected it. A theme descriptor loaded through a test override can establish binder compatibility, not normal selection in a live seed. Keep every evidence row at its actual level.

If the production registry only accepts owner-PASS assets, keep unreviewed assets in the correct review/candidate path. Do not set `review: pass` to silence the loader. Ask Prod for a bounded development-only selection path if one is needed; it must not change the owner-review truth or normal defaults. Production can integrate previously approved assets immediately when their technical requirements hold.

### No aesthetic evidence laundering

Do not beautify proof shots with a separate lighting setup and imply the game looks like that. Neutral beauty/turntable images are welcome **alongside** the labelled in-engine views, never instead of them. Keep the world pose, camera, renderer settings and material overrides in the capture metadata. An art change that removes dark contrast problems by adding a private directional light changes the experiment.

Fix concrete faults found in captures and re-render their exact comparison, rather than hiding them at another angle. Keep failed examples and supersession notes compact but available. Screenshots should show a person-sized frame of reference; real gameplay camera views are preferred over a scale rod when the actual runtime exists.

## 9. Working with Prod and Dess while they execute Overnight 04

Send a short accepted-lane note with current Art head, work folders and the first delivery target. Request or read their existing asset envelopes, states, attachment requirements and visual selection surfaces. Establish one writer for every shared exporter/manifest. Use current tool-supported collaboration; when no direct message path exists, write the handoff to the repository and report that it awaits acknowledgment instead of pretending it was sent.

Prod's runtime may change during the night. Test a pinned revision, state it, and re-check only the affected art contract when a new delivery changes that revision. Do not perpetually restart work because the branch has advanced; do not use an old fit measurement as proof for new geometry. If a collider or attack envelope changes, preserve the older exported variant for its older consumer until the new one is validated.

**Critical Art handoffs:**

1. Setpiece fit sheet and first canary, then coherent asset-family commits.
2. Existing enemy production readiness, clip names and attachment transforms.
3. Theme-pack selection requirement: authored assets may be prepared now, but multiple named packs need an actual selector/mapping that Prod/Dess own. Do not conclude that six mechanical themes imply only six possible appearances forever.
4. New presentation nodes needed for meaningful state changes, naming the consumer and why a material region is insufficient.

A requested gameplay change is not smuggled in as art. A receiver that needs a larger hitbox, a control that needs to move, a new walkable rail support, a shader requiring another renderer or a pack needing a new macro-state field is a named interface request. Continue assets whose contracts are already known.

## 10. Finite scope, honest pacing

This is a large production programme within an approximately ten-hour owner absence. It deliberately contains more independent work than a single three-hour batch. Work until available resources or the finite ready queue are exhausted, not until an arbitrary output count is reached. Do not run passive loops simply to stay alive.

Use parallel art helpers only where they reduce real independent work and respect available permissions/resources. Maintain one integration owner; compile/import/test one combined source state deliberately. Do not run several incompatible Blender exporters against the same output path. Expensive full checks belong at coherent delivery boundaries, with focused source/export checks on smaller commits.

After the first six packs or any early milestone completes, inspect the remaining listed packs and shared art families; continue ready work. Do not replace that continuation with another general “I can do more” message. If a new hero concept genuinely cannot proceed without an owner decision, retain the candidate and continue established visual families or other explicitly scoped kit work.

Human style/gameplay judgments remain pending while the owner is away. Preserve enough clearly labelled views for a reasonable morning review; do not require the owner to inspect hundreds of near-identical renders to discover which five show the important new things.

## 11. Required final handoff

Start with what was actually produced and what Production can use now. Then provide:

- Art starting/tested/pushed revisions and any combined-consumer revision; branch/PR and exact changed asset families.
- A short install/selection guide using the existing exporter and registry, plus one precise integration status per family.
- A count of actual new meshes, adaptations, reused assets, textures, clips, variants and complete packs, kept separate.
- The review index, same-camera state comparisons and clean-import logs; machine-measured fit/performance notes with their environment.
- Owner-review status, known unsupported runtime hooks, packs selectable only in a review harness, and any contract conflict.
- Remaining ready work, genuinely blocked work and an exact resume point; never compress “unfinished” into “awaiting review” when implementation is missing.
- Confirmation that comparison/review/game saves are untouched and no scheduling/subscription remains.

The user should be able to see a **visually coherent railway and three minors, meaningful enemy presentation, and an expanding set of usable source-inspired environments**. Not all of these must fit the session to make the work valuable, but the final answer must distinguish the completed set from the intended destination.

## 12. Source register and freshness boundary

Project evidence used to prepare this work order:

- `docs/art/ART_FRONTIER.md` at Art `1a9f1c9fd21c30d57f9f0d702f81a3eacf60b199`: Style Lock, existing base families, later enemy-envelope production, the ThemePack consumer correction, and historical scheduling language overridden here.
- `docs/art/ASSET_INVENTORY.md` at that Art ref: actual asset names and approval/readiness history. Generated tables and early introductory claims can describe different moments; check the specific current item rather than infer absence from an old sentence.
- `docs/art/ASSET_AUTHORING.md` at that Art ref: authoring source, units, anchors, material restrictions, naming, import and prop-versus-shell collision distinctions. Confirm current executable pins; no tools were installed or art generated during preparation of this prompt.
- `docs/art/INTEGRATION_HANDOFF.md` at that Art ref: real export-to-content path, strict manifest compatibility, resource existence, separate provenance and review status. Its cited Production revisions are historical, not this run's baseline.
- `docs/art/BATCH_043_INVENTORY.md` at that Art ref: Status/compound, machinery-node and physical-prop work to recover instead of redo.
- `godot/scripts/generation/theme_materials.gd` and `theme_pack.gd` at Production `68eb947a65f6dd72e150831322fc76c655e963fe`: actual authored-pack lookup, required roles, universal hazard and fallback/descriptor behavior.
- Owner-approved Blindside/major-minor directions and recovered original EX50-011, EX50-021 and EX50-033 specifications: supplied as unchanged backups in this packet when available. Newer explicit owner rulings and the current agreed runtime fit govern where a historical plan prescribed superseded implementation.
- Official Archipelago included-games page, read during preparation: all 18 chosen source-game titles appeared. This verifies catalogue membership only. Art interpretation titles and asset lists are newly proposed in this brief.

Public reference for membership (not an asset licence or visual reference capture):

```text
https://archipelago.gg/games
```

Relevant repository references:

```text
https://github.com/cadykaya/archipepsi/tree/1a9f1c9fd21c30d57f9f0d702f81a3eacf60b199/docs/art
https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/generation/theme_pack.gd
https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/generation/theme_materials.gd
```

No repository changes or assignments were made while preparing this packet. Forwarding the execution brief is the owner's dispatch; Arty must acknowledge the lane and coordinate actual shared work before writing it.
