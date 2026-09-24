# Archipepsi: from populated rooms to memorable places

## A source-grounded design investigation and prototype program

**Research date:** September 21, 2026, America/New_York. Repository timestamps can read September 22 in UTC.

**Inspected development snapshot:** `cadykaya/archipepsi`, branch `claude/archipepsi-0-4-blindside`, commit **`68eb947a65f6dd72e150831322fc76c655e963fe`**. This report does not silently advance with the branch.

**Scope:** all 33 games in the supplied comparison set have individual entries. Thirteen entries receive extended contrasting treatment. Additional transfer studies cover the requested adjacent genres. Evidence gaps, edition differences, and unverified mechanisms are identified rather than filled with invented play experience.

**Execution boundary:** this is a source-code, documentation, and published-evidence investigation. I did not play Archipepsi, run its Godot/Python suites, watch the embedded gameplay videos, or conduct new human playtests. Test results below are repository-reported unless explicitly described as proposed. The repository was not modified. The stored Zone examined is a checked-in regression fixture, not a level freshly generated during this investigation.

**How to read the report:** repository facts have `R` references; external evidence has `G` or `X` references. “Interpretation,” “proposal,” and “prediction to test” identify my reasoning rather than something established by a source. The source register at the end contains persistent links and evidence qualifications.

## Navigation

[Diagnosis](#1-executive-diagnosis) · [Project audit](#2-what-was-actually-inspected) · [Pipeline](#3-the-corrected-campaign-to-room-pipeline) · [Integration matrix](#4-capability-to-campaign-integration-matrix) · [Coverage ledger](#5-evidence-method-and-coverage-ledger) · [33 game dossiers](#6-per-game-dossiers-and-extended-contrasts) · [Transfer studies](#7-targeted-transfer-studies-why-these-additions-earn-space) · [Genre synthesis](#8-genre-synthesis-compatible-mechanisms-and-real-conflicts) · [Room vocabulary](#9-a-relational-room-vocabulary--tools-not-quotas) · [Before/after concepts](#10-concrete-archipepsi-beforeafter-concepts) · [Prototype program](#11-prioritized-prototype-program) · [Technical acceptance](#12-technical-acceptance-what-must-be-true-before-interpreting-a-playtest) · [Epsilon](#13-epsilon-and-the-authored-alphabet-the-smallest-useful-extension) · [Roadmap](#14-dependency-ordered-codecontent-roadmap) · [Conclusions](#15-final-recommendations-and-open-uncertainties) · [Sources](#16-source-register-and-inspection-limits)

---

# 1. Executive diagnosis

## 1.1 The strongest current hypothesis

**Archipepsi is better at proving that a room can exist and contain enough activity than at specifying why its contents belong together.** This is a diagnosis of the inspected composition surfaces, not proof that every generated room is bad. The content-value model prices enemy counts, activity elements, timing, ordering, and elevation. The encounter signature distinguishes enemy types and counts. The activity placer solves physically admissible positions. These are useful constraints, but none establishes the relationship “cross this exposed lane to silence the enemy covering the return route.” [R06][R07][R09][R19]

The important unit to prototype is therefore a **situation**, not another ingredient. A situation is something the player can understand in terms of a relationship: the crate that would make a step also shuts the door; an enemy's shot can operate machinery; repairing a route changes the next journey; a movement ability changes which side of an encounter can be approached safely.

That distinction already exists inside the project. **Unweighted Switch** and **Counterfire Arcade** specify such relationships explicitly. Their executable development scenarios are stronger evidence of an available design direction than an abstract promise of universal systemic interaction. They are not, however, evidence that ordinary campaigns regularly compose those situations. [R26][R30]

**Recommended emphasis, as a proposal rather than a new owner ruling:** make the hybrid primarily about **understanding and changing a place**, with expressive movement and combat as ways to act on that understanding. Curiosity motivates entering; a bounded situation supplies the decision; a visible consequence gives the place a memory. Some rooms can be combat spaces, some thinking spaces, and some quiet connectors. They do not all need all three pressures.

## 1.2 Findings, confidence, and competing explanations

| Finding | Status and confidence | What would weaken or change it? |
|---|---|---|
| Ordinary composition represents content quantities more explicitly than causal or tactical relationships. | **Confirmed source fact, high confidence** in inspected request/fallback/placement code. Enjoyment consequence remains a hypothesis. [R06][R07][R08][R09][R19] | A current ordinary-campaign sample showing the missing relationships produced consistently through another path. |
| The engine's usable vocabulary exceeds what the default fallback normally asks it to build. | **Confirmed integration distinction, high confidence** for EX50 scenarios, rail declarations, and opt-in cross-room composition. [R09][R12][R23][R26][R30] | A newly landed producer, with provenance and end-to-end evidence, that includes those systems in normal campaigns. |
| Some reported frustration was caused by uncommunicated or broken consequences rather than insufficient complexity. | **Historical evidence, medium confidence for generalization.** The September 13 playtest contrasts satisfying station repair with interactions that appeared to do nothing. [R15] | A current playtest with clear feedback where the same interactions remain equally unsatisfying. |
| “Branching exists” does not settle whether route choices are understandable or worthwhile. | **Confirmed distinction; experiential claim untested.** Topology proves reachability, not player preference. [R16][R17] | Players remembering branches, explaining different reasons for choosing them, and appreciating their consequences. |
| Increasing enemy variety may help, but is not the first causal test. | **Proposal, medium confidence.** Three behavior families exist; their arrangement can still be tested before expanding AI. [R13][R14] | Same-roster layouts fail to produce distinct decisions, or enemies cannot sustain their intended roles even in a curated layout. |
| Freshly implemented cross-room state is not the missing subsystem the older notes imply. | **Confirmed current correction, high confidence.** State construction, restore, and a distinct selection message are present at the pinned head. [R20][R21][R22][R31] | A runtime execution failure would change readiness, but not erase the implementation already present. |
| The largest remaining unknown is whether the authored situations are enjoyable with real players and ordinary Echo loadouts. | **Evidence gap, high confidence.** Technical checks and scenario walkthrough automation do not answer that question. [R23][R32] | Recorded, versioned human sessions across relevant loadouts. |

Alternative explanations must remain live. Weak gun feel, cramped input affordances, unclear visual hierarchy, inadequate enemy reactions, excessive setup time, or progression fatigue could outweigh composition. An encounter relationship that is excellent on paper can fail because aiming, movement, or feedback makes executing it unpleasant. Conversely, a very simple room can be enjoyable because the underlying action feels excellent. The prototype program separates these possibilities rather than treating one explanation as settled.

## 1.3 What should not be “fixed” again

Do not begin by adding a ranged windup: ranged enemies already have one. Do not describe activities as universally inert: the runtime builds them. Do not propose restoring persistent keys, opened locks, and repaired stations as if that work is absent. Do not build a second global state service merely because a frontier note predates the newest merge. Do not assume moving-platform passenger carry is broken; the ledger records direct tests contradicting that earlier hypothesis. [R14][R19][R20][R21][R22][R32]

There can still be tuning, coverage, or lifecycle defects in these systems. The distinction is between **verifying and improving an implementation** and **misdiagnosing it as nonexistent**.

---

# 2. What was actually inspected

## 2.1 Branch and time discipline

The supplied baseline was `98c54776a46b55f96ecf517470b2b2733de1a306`. The connected branch listing returned the newer `68eb947a65f6dd72e150831322fc76c655e963fe`; open pull requests identified PR #12 as the active 0.4 line and PR #4 as the older comparison line. The older `claude/archipepsi-echoes-continuation-b1adno` was still at `19c5d8eab475a893a1ea544c7ce1fef3b744f8e7`. These are separate builds, not interchangeable evidence. [R02][R03]

The material newer change verified here is the D-8 consumption/protocol merge. The head commit is timestamped **2026-09-22 02:46:01 UTC**, or **September 21, 10:46:01 p.m. Eastern**. It adds the `ZoneStateSelected` reporting path and integrates reversible state with the runtime. A nearby owner-directed commit preserves transported-object support as unfinished M7 work. The baseline already included railway/home-dock work; this report does not incorrectly attribute all railway integration to the later delta. The compare response was not an exhaustive readable audit of every changed line. [R05][R22]

## 2.2 Authority and evidence are different

Current executable code is the strongest evidence of implementation. Current owner-approved ledger entries establish intended scope. Older playtests establish what happened in those sessions. Design proposals establish possible direction, not shipped functionality. A generated-data schema, a hand-built development scenario, and an ordinary campaign producer each answer a different question.

The Amalgam document is especially easy to misuse. Its header and historical substrate warning do not describe all subsequent work. Its owner-amended determinism rules distinguish deterministic bridge decisions, first-generation model choice, and committed manifest replay. Those are useful current constraints, but they do not establish that its entire physics/signal design is implemented. The September 4 engine reconciliation is explicitly historical. [R24][R25]

## 2.3 Inspected source surface and remaining blind spots

The inspection covered branch/PR metadata, frontier and ledger excerpts, historical playtests, request and fallback generation, composition/value guards, activity schemas, logical topology, layout validation, content instantiation, activity placement, enemy behavior, controller setup/re-entry, cross-room composition and construction, two EX50 scenario implementations, and the beginning of a checked-in played-Zone fixture. Source ranges and links are listed in the register. (see the repository inspection register in §16.1)

It did **not** exhaustively trace every AP allocation branch, every Echo primitive, every saved-manifest field, or every geometry builder. In particular, reading the controller's call sites does not certify every downstream interaction. The capability matrix therefore distinguishes “source path present” from “ordinary production observed” and “new execution verified.” None of the last category occurred in this investigation.

---

# 3. The corrected campaign-to-room pipeline

## 3.1 Allocation and capability proof

The campaign layer owns persistent state and constructs requests informed by acquired components and capabilities. The request surface distinguishes owned optional affordances from guaranteed capabilities that may support mandatory requirements. These are not interchangeable: owning a useful movement option now is different from guaranteeing its acquisition for the relevant progression route. [R08][R29]

The historical four proof categories—permanent baseline, already possessed, established in Zone, and forge-constructible—are useful vocabulary, but their presence in an interface is not evidence of a producer for each case. The current railway acquisition scenario uses its own grant; it must not be cited as a full AP acquisition loop. Forge policy and return-later progression remain unresolved in the ledger. [R23][R25]

**Design implication:** author a requirement and its provider together. Test what happens before acquisition, after acquisition, after unequipping, after re-entry, and in the multiworld assignment model. Do not solve uncertainty by banning every capability gate, nor by assuming any visually suitable Echo makes a gate logically safe.

## 3.2 Epsilon request and selection

The request supplies a bounded catalog, rules, progression context, and shell information. The owner-amended direction gives Epsilon a real role in selecting authored shells; replacing that path with an undisclosed always-authored fallback would violate the architectural intent. Accepted model output becomes part of committed content identity rather than being assumed reproducible from the seed alone. [R08][R24]

**Design implication:** the next authoring vocabulary should express relationships that can be validated, not ask a model for arbitrary GDScript, invented asset paths, or unrestricted geometry. An explicit experimental set-piece selector can be an informative comparator, but should identify itself as such.

## 3.3 Fallback and content-value repair

The inspected fallback chooses ordinary chamber and activity content, respects available constraints, and attempts to satisfy a content budget. Its four activity families are switch sequences, target challenges, pressure routing, and timed runs. It can increase a landmark's value by adding activities or enemies. The value model caps the contribution from floor area, so it is not simply rewarding empty size, but it still prices many quantities without knowing their experiential meaning. [R07][R09]

This creates a concrete experimental trap: removing disliked activities can cause a budget-repair step to replace their value elsewhere. The result may be a denser fight, not a cleaner comparison. A content experiment must freeze the ingredient set or explicitly account for the repair pass.

**Preserve:** minimum-content and degeneracy checks catch real problems. **Change:** do not use their pass/fail result as a claim that a room is interesting. Do not replace the scalar with another unvalidated scalar called “fun.”

## 3.4 Topology and physical realization

The topology layer works with logical connections, keys, exits, and reachability. It can decline branching where the room/socket structure cannot support it. The geometry is built and measured in Godot; the bridge validates the resulting evidence and can refuse the layout. The accepted manifest supports stable replay instead of reshuffling a known place on every visit. [R16][R17][R21]

**Design implication:** keep logical reachability, physical traversability, and legible navigation separate. A graph loop is not necessarily recognizable as a shortcut. A traversable corridor is not necessarily comfortable at the player's speed. A remembered door is not necessarily easy to relocate.

## 3.5 Instantiation and local activities

Authored and procedural room paths feed the content instantiator. Activities are built with runtime rules, not merely decorative boxes. Placement now considers occupied space, actual solids, suitable surfaces, and target mounting/facing concerns. The ordinary placement pattern nevertheless remains principally a layout of activity elements, not an authored dependency between an object, a route, a threat, and a later consequence. [R18][R19]

This is **missing authoring/composition vocabulary**, not evidence that all the underlying interaction code needs replacement.

## 3.6 Runtime, feedback, persistence, and return

The controller restores persistent keys, opened locks, repaired/reached stations, latches, and macro selections through distinct paths. Transient runtime objects and objectives are not all persistent merely because one repair latch is. Macro state is restored before its mechanisms are constructed. Session-only room-visit tracking is used for contextual messages; it is not a persistent exploration map. [R20][R21]

The D-8 constructor currently has a **closed mechanism vocabulary of barriers and lamps**. Readers bind to a state variable's identity, not to another room's transient control node. Its current placement uses arrival-relative offsets clamped to room bounds. This is useful implemented infrastructure, but not a universal machine network. [R31]

**Verification question, not an observed bug:** does each proposed barrier actually block the intended physical route, and does the setter's required operation have the corresponding runtime enforcement? A logical edge condition plus a barrier somewhere in the room is not by itself proof of the intended interaction. Test the geometry and real player operation together.

---

# 4. Capability-to-campaign integration matrix

“Present” means implementation or a direct call path was read. “Reported tests” means repository evidence, not tests run for this report.

| Capability | Current inspected evidence | Ordinary-campaign reach | Immediate design implication |
|---|---|---|---|
| Authored shells with procedural alternatives | Catalog/selection and instantiation surfaces present. [R08][R18][R24] | Part of the intended real generation path; individual offered/selected/built outcomes must remain distinguishable. | Improve compositions on existing shells before arbitrary mesh generation. |
| Four ordinary activity families | Real builders and rules; placement includes physical constraints. [R19] | Generated by fallback. [R09] | Rearranging a row is not automatically a puzzle. |
| Target mounting, facing, and actionable feedback | Repairs documented and source paths present. [R04][R19] | Relevant to ordinary activities. | Preserve fixes; test comprehension rather than prescribing them again. |
| Three enemy behavior families | Melee, ranged, brute; ranged/brute tells; limited steering. [R13][R14] | Ordinary encounters. | First test geometry and assignments; patrol/perception expansion is additional AI work. |
| Richer visual-role catalog | Broader than behavioral implementation in current frontier. [R04] | A visual label does not establish a new combat behavior. | Do not count skins as tactical roles. |
| Local keys and persistent opened locks | Controller restore and topology rules present. [R16][R21] | Ordinary graph Zones. | Give branches a visible reason and a comprehensible return, not just a color. |
| Warp-station repair and return | Historical liked interaction; restore paths present. [R15][R21] | Campaign mechanism exists. | Strong candidate for consequence-based exploration. |
| Movement offers/packages | Validated offers and operator package selection present. [R20] | Can affect ordinary Zones when selected, but package is not itself an AP item or saved progression. | Do not confuse a launch flag with capability acquisition. |
| Rail transport and permanent span repair | Real carrier/junction, declared-Zone construction, restore; reported technical checks. [R21][R23] | Build path present; inspected ordinary fallback does not compose rail networks. | Integration/content work, not “invent a train system.” |
| Railway grapple acquisition loop | Continuous scenario automation reported; local `EchoGrant`. [R23] | Development scenario, not certified ordinary AP acquisition. | Keep the satisfying loop; replace the temporary grant with proper progression integration before claiming M2 complete. |
| Counterfire Arcade | Ordinary enemy projectile operates a receiver; baseline alternative; temporary shutter and far-side release. [R30] | Explicit operator-selected development scenario. | Test bait readability and optional execution before generalization. |
| Passing Platforms | Lift/shuttle situation; recovery floor and patient route already built according to ledger. [R23] | Development scenario, not ordinary composed campaign. | Tune and compare existing routes; do not propose its already-built low-pressure solution as new. |
| Unweighted Switch / object `lightened` | Real status target boundary, class-sensitive plate, persistent-in-scene bolt; source and reported checks. [R26][R32] | Development scenario, not saved campaign proof. | Excellent causal-puzzle experiment; integrate lifecycle separately. |
| Reversible cross-room configuration | `ZoneState`, construction/restoration, distinct selection intent present at head. [R21][R22][R31] | Opt-in composition helper; not evidence of default production prevalence. [R12] | Use bounded barriers/lamps first; prove route realization and reversibility. |
| Transporting manipulated objects between rooms | Explicit unfinished M7 owner scope. [R22] | Not discharged by D-8. | Do not build a required carry-across-Zone puzzle on assumed support. |
| Broad physics/status/machine design | Selected bounded pieces implemented; historical proposals much broader. [R24][R25][R32] | Mixed and incomplete; per-kind/per-target eligibility matters. | Every proposal must name the particular supported operation and target. |
| Persistent player-facing map/remembered-gate UI | Session visit memory is not this feature. [R20] | Not established by this inspection. | Treat a durable map/gate ledger as bounded new UI/data work after testing need. |
| Return-later progression policy and Forge/Static economy | Explicitly unresolved in current ledger. [R23] | Cannot be assumed. | Do not rewrite the economy or progression policy to rescue a prototype. |

The most important distinction is not “has feature / lacks feature.” It is **declared → built → reached through campaign → physically correct → persistent/recoverable → understood → enjoyed**. Evidence at one stage does not automatically advance the later stages.

---

# 5. Evidence method and coverage ledger

This is a purposive convenience sample, selected for identifiable spatial mechanisms and counterexamples—not a survey of all players. It includes original developer commentary and design accounts, first-hand reviews, original community discussions, and guides that establish concrete mechanics. Store pages are used for release/early-access status, not satisfaction. Several obscure-game entries have weaker spatial or independent-negative evidence. Those are marked.

A review can supply both praise and criticism without becoming two independent accounts. Comments in one thread are likewise not an independent population sample. Where an extended study lacks independent positive and negative accounts, the ledger says so. No reception percentages, causal effect sizes, consensus claims, video timestamps, or personal gameplay claims are inferred.

**Depth:** E = extended contrast; M = focused mini-dossier. **Gap:** the precise unresolved evidence question, not a verdict against the game.

| # | Original title | Depth | Concrete material examined | Principal evidence qualification |
|---|---|---|---|---|
| 1 | Portal | E | Chamber 13; Escape Part 4; commentary redesigns | Developer-reported playtest outcomes, not independently observed sessions. |
| 2 | Portal 2 | E | Repulsion Intro; Propulsion Flings; Old Aperture | Developer commentary plus original review; room-specific reception is thinner. |
| 3 | The Talos Principle 2 | E | Contained device puzzles versus bridge-building interludes | Named individual device-puzzle reconstruction remains a gap. |
| 4 | Outer Wilds | E | Brittle Hollow investigation; Hourglass Twins; late execution problem | Late puzzle unnamed by review; not relabelled from memory. |
| 5 | The Witness | E | Local teaching banks; environmental perspective; closing puzzles | Main review used a pre-release build with acknowledged non-final material. |
| 6 | Antichamber | M | Window/perspective transitions; later block-gun puzzles | Exact room labels and independent negative sample not verified. |
| 7 | Manifold Garden | M | Gravity-oriented cube puzzles; looping falls | Negative reception gap; transfer risks are analysis, not reported complaints. |
| 8 | Superliminal | E | Perspective placement; Whitespace chess frustration | Developer account plus original community testimony; exact build unspecified in testimony. |
| 9 | Viewfinder | E | Reoriented photo geometry; copying a teleporter | Strong concrete review examples, but exact stage labels and independent dissent gap. |
| 10 | Lunacid | E | Castle Le Fanu; coffin-spell traversal | Post-1.0 PC review; second region label not established. |
| 11 | Legend of Grimrock 2 | E | Island/dungeon clue hunt; serpent-staff progression puzzle | Two independent first-hand reviews; exact puzzle-room label missing. |
| 12 | Arx Fatalis | M | Cooking as world interaction | Modern retrospective/modded-play context; no full room walkthrough reconstructed. |
| 13 | Verho – Curse of Faces | M | Nameless Village; shortcuts; enemy pressure during dialogue | 2026 PS5 review not silently generalized to 2025 PC launch. |
| 14 | Cryptmaster | M | Chest clue/word loop; altar interaction | Original reviews; keyboard versus console controls kept distinct. |
| 15 | Vaporum | M | Mechanical keys/wheels and combat corridors | Original 2017 game, not Lockdown; named-room evidence gap. |
| 16 | King's Field IV / The Ancient City | M | Holy Forest; deep-city encounters and sensory navigation | 2002 PS2 review; slow controls are version-specific. |
| 17 | Monomyth | M | Early-access interconnected-dungeon exploration | Current EA status verified; named room and robust negative reconstruction incomplete. |
| 18 | Metroid Prime Remastered | E | Artifact Temple/hunt contrasted with incremental exploration | 2023 Switch-specific critique; regional guide provides location support. |
| 19 | Metroid Prime 2: Echoes | M | Regional temple keys contrasted with Sky Temple-key caches | Original game guides and dated player debate, not an invented remaster. |
| 20 | Supraland | M | Red Crystal Tower / Volcano guide; puzzle-combat balance | Guide originated before 1.0; current exact puzzle state not independently tested. |
| 21 | Supraland Six Inches Under | M | Cagetown's vertical social/route structure | Separate 2022 PC and 2023 console evidence. |
| 22 | Frogmonster | M | Balsam encounter discussion; navigation/aim complaints | Original community sample; builds and room details incomplete. |
| 23 | Journey to the Savage Planet | M | Exploration/scanning/progression loop | Original release reviews, not sequel; named room reconstruction incomplete. |
| 24 | Vomitoreum | M | Movement unlocks, larval passages, cleared return routes | 2021 PC/Linux first-hand review; independent negative gap. |
| 25 | Supraworld | M | Opening walk/jump/crouch progression; environmental combat | September 2025 early-access first act; not a verdict on all 2026 content. |
| 26 | DUSK | E | Opening farm/industrial spaces; Ruins Access framing; Escher Labs | 2018 base-game review and 2025 original discussion; not DUSK HD. |
| 27 | ULTRAKILL | M | 4-2 God Damn the Sun challenge route | 2021 player guide; current EA status separately checked. |
| 28 | Turbo Overkill | E | Rooftops; late Episode 3 finale | 2022 EA and 2023 1.0 reviews explicitly separated. |
| 29 | AMID EVIL | M | Gear maze; astral water-globe encounter; spiral platforming | 2019 review, not later VR or expansion; some map labels unavailable. |
| 30 | CULTIC | M | Chapter 2 mall/mannequin segment; finale | December 2025 review covers both chapters, not just original Chapter 1. |
| 31 | Quake | E | E1M1 Slipgate Complex; E1M2 Castle of the Damned | First-hand designer analysis of original maps, not a controlled reception study. |
| 32 | Prodeus | M | Black Magic Society custom map; campaign pacing/checkpoints | Custom map labelled; 2021 checkpoint criticism not assumed current. |
| 33 | Selaco | M | Parking-garage navigation; tactical FPS spaces | 2024 EA reception; current EA status checked separately. |

The ledger represents **complete title coverage, not complete evidence saturation**. In particular, several mini-dossiers do not meet the stronger standard of a fully reconstructed named room plus independent positive and negative accounts. Their lessons should be treated as lower-confidence inputs, not dropped from the comparison or inflated into certainty.

---

# 6. Per-game dossiers and extended contrasts

The game descriptions below are evidence summaries. The proposed mechanisms and Archipepsi transfers are my interpretations. Persistent revisit consequences are not invented for games whose examples are primarily linear levels; replaying for mastery is explicitly different from returning inside a persistent world.

## 6.1 Portal — extended: density of relationships, not density of objects

**Evidence and version.** Valve's original developer-commentary transcript describes specific chamber decisions and reported playtest revisions. This is developer evidence about intent and observed development problems, not an independent sample of finished-game players. [G01]

**Contrast A: Test Chamber 13.** The commentary presents this compact chamber as a combination of previously introduced elements. Cube availability also protects against losing a necessary object. Its value is not that it is small or that it contains several devices; it asks the player to organize familiar possibilities in a shared space. **Contrast B: Escape Part 4.** Valve describes reducing a large turret confrontation when it did not fit the skills the preceding game had taught, and strengthening the use of portal/flinging knowledge instead. Elsewhere, a rail that looked walkable but killed players was changed because the visual invitation was misleading. [G01]

**Mechanism reconstruction—interpretation.** In the compact test, entry permits a survey; recognized objects produce plausible hypotheses; a placement changes reachable options; feedback makes the next inference possible. In the escape encounter, expectation changes from laboratory exercise to applying an established toolset under danger. Combat is useful when it tests that toolset, not merely when it adds threat. These are linear sequences: their lasting consequence is advancement and learning, not an invented persistent world state.

**What this challenges.** A high content-value score can coexist with a poor teaching sequence. Conversely, a small room can support substantial thinking because its pieces constrain one another. Complexity should be measured descriptively in dependencies the player must understand, not prescribed as an ingredient quota.

**Archipepsi transfer.** Keep Unweighted Switch's contradiction visible in one inspectable space. Let the player establish the crate's useful height and the plate's obstructive consequence before asking for the status solution. Do not add enemies merely to make the chamber's value comparable to a combat arena. Retain reliable object recovery. This is existing capability needing better content/communication and later campaign integration, not a demand for Portal's portal-rendering technology.

**Reject the transfer** if players understand the contradiction but find performing the solution tedious. That would argue for shortening setup or improving manipulation, not more clues or a more elaborate logical graph.

## 6.2 Portal 2 — extended: teaching a physical rule versus guiding its execution

**Evidence and version.** Valve commentary names Repulsion Intro and Propulsion Flings. A 2011 PC Gamer review independently praises the broader puzzle repertoire while finding some gel uses and painting less compelling. [G02][G03]

**Contrast A: Repulsion Intro.** The developer account distinguishes preserving incoming velocity from a fixed bounce, and explains why simply walking onto gel should not always cause an unwanted bounce. **Contrast B: Propulsion Flings.** Speed and steering assistance were tuned so players could execute the intended motion. Old Aperture changes the spatial and narrative presentation; the review nevertheless considers some gel applications less interesting than the new funnels and bridges. [G02][G03]

**Mechanism reconstruction—interpretation.** The first encounter asks, “What rule governs this material?” The second asks, “Can I deliberately use that rule to produce a trajectory?” Conceptual difficulty and execution difficulty are separate axes. A player should not have to relearn whether movement input will cooperate every time the conceptual relationship is reused.

**Praise/criticism boundary.** The review's mixed response is not evidence that gel puzzles generally fail, and developer tuning is not proof that every player found them comfortable. It does establish a useful design distinction: a consistent mechanic can still need substantial assistance at the input/geometry boundary.

**Archipepsi transfer.** Passing Platforms already includes both a moving transfer and a patient solution. Compare them as alternate experiences of the same machinery: observation and scheduling versus precise movement. Preserve the low-pressure route rather than “discovering” it again. Use the actual player envelope and carrier motion, not idealized jump distances. [R23]

A success condition should identify the learned relationship. A player who says “I stopped the shuttle where the lift meets it” has understood something different from one who says “I jumped when the marker flashed.” Both can be legitimate, but they should not be mistaken for the same puzzle. Test discovery and execution separately, then test whether a second arrangement rewards the learned rule rather than memorizing a timing script.

## 6.3 The Talos Principle 2 — extended: meaningful recombination versus connective busywork

**Evidence and version.** Dominic Tarason's November 2, 2023 PC review describes the launch game's contained device puzzles and bridge-building interludes. Marcus Stewart's November 17 review independently reports strong puzzling but increasing fatigue near the end. Exact individual device-puzzle names were not established in this sample. [G04][G05]

**Contrast A: device-puzzle areas.** New tools such as color manipulation, stored energy, drilling, and body transfer change what combinations are possible. The PC review values this expansion and notes the absence of the earlier game's mines/turrets. **Contrast B: bridge-building interludes.** The same reviewer finds the connector-building exercises less interesting. The second review's fatigue complicates any simple prescription to add more puzzles or exploration. [G04][G05]

**Mechanism reconstruction—interpretation.** A contained challenge can give the player a bounded hypothesis space: inspect sources, destinations, obstructions, and tool effects; change a dependency; observe which constraint is now satisfied. A connection task outside that structure can become useful pacing—or an obligation that repeats an already-understood operation. Its location between “real puzzles” does not automatically justify it.

**Archipepsi transfer.** A switch that repairs an obvious bridge can be valuable without being an insight puzzle. Call it a repair, reveal, commitment, or route change. Its payoff may be seeing a destination become available, not proving the player clever. Conversely, a target row should not be described as a puzzle solely because it has an order or timer.

The bounded prototype is to keep two controls and one moving route, but compare direct operation against a causal dependency that requires understanding a shared state. Do not prescribe every room as a device puzzle. A quiet room with a clear destination can provide better connective tissue than another task.

**Evidence gap and limit.** This study supports the contrast between mechanism-rich challenges and connective work; it does not reconstruct two fully named Talos chambers. The exact teaching sequence should not be copied from this evidence alone. The independent accounts are reviews, not representative measurements of player fatigue.

## 6.4 Outer Wilds — extended: curiosity needs both an unanswered question and recoverable knowledge

**Evidence and version.** Phil Savage's May 29, 2019 PC review describes his own investigation through signals, ruins, the ship log, and changing planets. It also reports a late puzzle where a correct conceptual answer was obscured by execution uncertainty. That puzzle is not named in the review and is not relabelled here. [G06]

**Contrast A: Brittle Hollow investigation.** A signal and unfamiliar phenomenon suggest a destination; ruins lead to further questions; discoveries survive as recorded information. **Contrast B: the Hourglass Twins.** Sand transfer makes access change with time. Revisiting is not simply retracing a corridor: knowing when a place is accessible changes the plan. The critical counterexample is the reviewer's unnamed late puzzle: inadequate feedback made a correct idea look wrong. [G06]

**Mechanism reconstruction—interpretation.** Entry presents a discrepancy the player wants to explain. Perception supplies evidence, not a complete instruction. The player chooses which question to pursue, acts on a hypothesis, and keeps knowledge even when the physical situation resets. Returning becomes a new test because the player's model has changed.

**Transfer without copying the wrong substrate.** Archipepsi does not need a solar-system simulation or a universal time loop. It can expose a destination before access, show an observable reason for the obstruction, and let another room change that reason. The existing macro-state infrastructure can support a modest version. It needs a legible local consequence and a rememberable remote one, not maximal setter-to-reader distance. [R12][R31]

A major caution is that knowledge-gated progress is fragile under procedural variation. A clue must refer to the actual committed arrangement, not to a generic story about a machine that the selected shell does not realize. Save/load must preserve both the world consequence and any player-facing recorded discovery deliberately promised by the design.

**Playtest discriminator.** Ask the player what they are curious about before giving a hint. “I want to know where that lowered track goes” is productive uncertainty. “I forgot which of the indistinguishable corridors had a door” is information loss. Neither time spent wandering nor the absence of a waypoint distinguishes them by itself.

## 6.5 The Witness — extended: space can teach a rule, and can also become the problem

**Evidence and version.** Edwin Evans-Thirlwell's January 25, 2016 PC review explicitly discusses a pre-release build with some non-final material. Its observations about local puzzle teaching and environmental perspective are useful; its closing-section criticism must retain that build qualification. [G08]

**Contrast A: local teaching banks.** Related panels introduce and combine rules with little verbal explanation. Progression between panels provides feedback about whether an inferred rule was adequate. **Contrast B: environmental perspective and late challenges.** The surrounding landscape can become part of what the player must read, rather than mere scenery around a screen. The reviewer also finds some closing challenges more like artificial interference or endurance than new understanding. [G08]

**Mechanism reconstruction—interpretation.** At first, the player perceives a local formal system. Later, the relevant boundary expands: perhaps the environment, sightline, or vantage point belongs to that system. The memorable event is not another solution of the old form; it is revising what counts as evidence.

**Archipepsi transfer.** Introduce one status effect where its result is unmistakable, then reuse it in a situation where the useful consequence is different. For example, learning that a class-sensitive sensor stops recognizing an object is different from learning that an impulse affects that object more strongly. Those are already distinct approved effects of `lightened`; they must not be blurred into “the box became lighter in every physical sense.” [R32]

The rule-transfer test is crucial: create a second arrangement that has the same relevant relation but different superficial geometry. Do not reward the player merely for repeating the same lever sequence. Equally, do not hide necessary affordances with arbitrary visual exceptions and call that discovery.

**Accessibility and limits—proposal.** A world-reading puzzle needs redundant cues where a single color, tiny contrast edge, or audio-only signal would exclude a player. That is a design recommendation, not a claim about an accessibility failure demonstrated in this review. The study does not establish the finished game's final puzzle balance or a consensus that its closing section is weak.

## 6.6 Antichamber — mini-dossier: surprise must become usable knowledge

David Valjalo's January 31, 2013 PC review describes an early window/perspective transition that changes where the player is, and contrasts the startling non-Euclidean exploration with later block-gun problem solving that felt more conventional. It also reports moments of obscurity. The map's rapid return function helps leave a problem and pursue another. Exact room labels were not verified. [G09]

**Interpretation:** the initial pleasure comes from revising spatial assumptions. The longer-term challenge is turning surprise into a learnable rule rather than requiring players to distrust every visual cue indefinitely. An unexplained exception can create a memorable first encounter and still be a poor reusable grammar.

**Archipepsi lesson:** a strange shortcut or one-way reveal should teach a reliable relationship. Preserve committed geography on return. Give players a way to defer a question without losing their record of it. Non-Euclidean geometry itself is a substantial new subsystem and poor first response to the current integration problem. A normal doorway that reveals a familiar room from an unexpected angle can test the memory payoff without that technology.

## 6.7 Manifold Garden — mini-dossier: removing death does not remove spatial stakes

Rachel Watts's October 28, 2019 PC review describes gravity-oriented cubes, color-associated orientations, and repeating falls that return the player through an endlessly recurring structure. It praises the architecture, movement, and feedback. This sample does not establish a credible independent negative account; no negative reception is manufactured. [G10]

**Concrete contrast:** carrying a cube under the appropriate gravity is a local constraint problem; deliberately falling through repeated space turns what would usually be failure into navigation. The consequence is a changed understanding of reachable geometry rather than an enemy kill or loot event.

**Archipepsi lesson—interpretation:** test recovery floors and intentional drops as parts of a route, not as apologies for a failed jump. A failed transfer can leave the player somewhere useful and comprehensible. However, infinite wrapping gravity is not “just placement”; it would be a major spatial/physics change. The transferable element is the meaning of the fall and the visibility of recovery, not the literal technology. Color-only state communication and disorienting camera behavior are risks to test, not defects claimed from this source.

## 6.8 Superliminal — extended: the rule can be simple while its physical implementation is difficult

**Evidence and version.** Albert Shih's account in a January 16, 2020 Game Developer interview explains perspective-based object placement and why robust collision/placement behavior was difficult. A November 2021 original community post describes prolonged difficulty with the Whitespace chess sequence; a separate patient-gaming discussion records enjoyment of the perspective surprises. [G11][G12][G13]

**Contrast A: object rescaling through perspective.** The apparent size held in view is preserved while placement at a different distance changes world scale. Developer discussion stresses tolerances and dense placement checks rather than treating this as a trivial visual trick. **Contrast B: Whitespace chess.** The cited player reports spending hours on the sequence. This establishes one experience of frustration, not a population verdict or a complete reconstruction of its solution. [G11][G12]

**Mechanism reconstruction—interpretation.** The player is invited to treat an image-space relationship as physically meaningful. A successful experiment revises the perceived affordance of ordinary objects. But when the intended inference is opaque, or valid placement feels inconsistent, the player cannot easily tell whether the idea or the execution is wrong.

**Archipepsi transfer.** Make the causal result of a status visible at the sensor and at the affected route. If a crate still looks solid and step-like, it should remain solid and step-like unless the rule explicitly says otherwise. Unweighted Switch's unchanged collision shape is valuable because it lets the player separate class detection from physical support. [R26][R32]

Do not add “clever perspective puzzles” by asking Epsilon to scale arbitrary props. That would require a new placement, collision, and perceptual contract. First test an existing mechanically honest contradiction with forgiving execution and a short reset.

**Falsification test.** After one failed attempt, ask what the player believes went wrong. A hypothesis such as “the effect expired before I reached the opening” is actionable. “The game ignored me” indicates missing feedback or an unreliable interaction, even if a technical replay succeeds. The negative chess testimony does not prove the latter happened there; it motivates separating those failure categories in Archipepsi.

## 6.9 Viewfinder — extended: changing the problem is often more memorable than solving it conventionally

**Evidence and version.** Robin Valentine's July 17, 2023 PC review provides concrete examples of reorienting photographed geometry and copying a teleporter instead of reaching the original. It praises the novelty but finds that some introduced ideas end before receiving deeper development. Exact stage labels are absent from the inspected account. [G14]

**Contrast A: photographed geometry.** Rotating an image can make a tower serve as a bridge. **Contrast B: teleporter copying.** A problem initially framed as reaching a destination can instead be answered by reproducing the useful destination. These are different inferences even though both involve photographs. The criticism is not insufficient spectacle but limited subsequent development of certain ideas. [G14]

**Mechanism reconstruction—interpretation.** Entry suggests a conventional obstacle. The player discovers that the tool changes the question: not “how do I jump farther?” but “which geometry should count as the route?” or “must I reach that particular instance?” Readable feedback validates the reframing.

**Archipepsi transfer.** Counterfire has an analogous, already-implemented reframing: the projectile is not only a threat to avoid; it can become an input to a receiver. A second authored situation should test that understood relationship in a new arrangement rather than add a new status for every room. The same enemy and receiver can offer another decision if their relative positions change. [R30]

The limit is essential. General photograph-to-world reconstruction is a major new subsystem. The transferable design method is to reuse an established operation in a surprising but consistent relationship. It does not authorize duplication of AP rewards, keys, or persistent state.

**Prototype question.** Does the second use create recognition—“I know what this shot can operate”—while still requiring a new spatial decision? If the player simply repeats a memorized stance and dodge, the pattern may be too rigid. If they cannot recognize the relevant receiver, it may not communicate its grammar. Independent negative reception beyond the cited review remains a gap.

## 6.10 Lunacid — extended: a place can mean something different to a different build

**Evidence and version.** Ben Love's February 9, 2024 PC review is post-1.0. It describes Castle Le Fanu's class-sensitive resource interpretation, traversal using coffin spells, rewarding exploration, and technical/obtuse-secret frustrations. A separate Startmenu review questions the patience required by combat. [G15][G16]

**Contrast A: Castle Le Fanu.** Blood fountains and holy water mean different things to a vampire character. A resource's value is contextual, not fixed by its appearance or category. **Contrast B: coffin-spell traversal.** Producing climbable objects allows access that ordinary movement would not provide. The review also observes that movement-related growth changes how spaces are crossed. The precise second region was not named in the inspected account. [G15]

**Mechanism reconstruction—interpretation.** Entry presents an environment whose meaning depends on the player. Perception recognizes a possible resource or route; build knowledge changes whether it is desirable; action tests that interpretation. On return, movement growth can turn previously careful traversal into confident passage.

**Archipepsi transfer.** Variable Echo loadouts are an opportunity to create different approaches to the same place, not merely to require a different colored key. A mobility-rich player might attack a gallery from above; a baseline player might use covered ground. Both routes still need physical and progression proof. An optional ability can make execution easier without being required for another player's AP progression.

Do not copy coffin construction into mandatory cross-room puzzles before transported-object authority and persistence are implemented. The current M7 boundary is explicit. Similarly, a build-specific fountain would require an authorized resource/status interaction, not an invented change to Static. [R22][R23]

**What to test.** Ask whether a shortcut made possible by an Echo feels earned or whether it makes the room irrelevant. These are different responses. Do not automatically patch out bypasses because the player spent less time in the room. The external criticism also warns that atmospheric exploration will not compensate indefinitely for combat whose ordinary action loop feels like waiting.

## 6.11 Legend of Grimrock 2 — extended: mystery about a solution is not the same as losing a required object

**Evidence and version.** Matt Thrower's November 3, 2014 PC review and Kinglink's July 5, 2018 retrospective are independent first-hand accounts. They agree that exploration and puzzle rewards can be compelling, but identify different sources of friction. [G17][G18]

**Contrast A: island-to-dungeon investigation.** Thrower describes following attractive branches into hidden dungeons, then losing track of the original question. Some answers depend on distant clues, leaving uncertainty over whether a puzzle can be solved now. **Contrast B: the serpent-staff progression puzzle.** Kinglink describes a weak-seeming weapon that is important for progression; discarding or misplacing such an object can turn a puzzle into extensive retracing. Exact room labels for these examples were not verified. [G17][G18]

Combat provides another instructive disagreement. Thrower values enemies that disrupt easy circling and make scenery useful; Kinglink is less enthusiastic about the dodge-based style. This is a preference contrast, not something to average into one ideal combat speed. [G17][G18]

**Mechanism reconstruction—interpretation.** Exploration can create a productive chain: distant question → optional investigation → clue recognition → return with an answer. It becomes administrative when the player already knows the answer but cannot locate the previously acquired input. The causal puzzle has been solved; the interface has failed to preserve useful information.

**Archipepsi transfer.** Keep local keys monotone and required mechanism inputs recoverable. For future physical carryables, specify allowed volume, reset behavior, and what happens to their location on re-entry before building content around them. A persistent gate note should remember observed information without revealing unexplored rooms. [R20][R22]

Do not import grid-based circle-strafing assumptions into a fast continuous-movement FPS. Transfer the relationship between enemy attack and safe position, not the tile timing. Test navigational uncertainty separately from causal uncertainty: “I have not found the information” differs from “I have it but cannot find the door” and from “I discarded the object because nothing identified its continuing role.”

## 6.12 Arx Fatalis — mini-dossier: ordinary world interactions can establish trust

A March 2023 first-hand retrospective highlights cooking bread as a surprising interaction with the world: an ordinary domestic setup produces a useful food item rather than being wholly decorative. This is testimony about a player experience, not a verified recipe specification; the post's ingredient wording should not be copied as implementation documentation. A 2021 patch-author account praises exploration while criticizing rough voice work and underdeveloped systems such as archery. Modern patches/modded play must be distinguished from the original 2002 release. [G19][G20]

**Interpretation:** a room can be memorable because an apparently mundane object behaves sensibly. The reward is partly trust: a kitchen is somewhere actions make sense, not just a collection of props with occasional glowing exceptions.

**Archipepsi lesson:** make a small set of environmental verbs consistent and consequential. A local operation can establish atmosphere without becoming a full puzzle or AP reward. Do not interpret this as permission to simulate every object. The exact kitchen layout, version, and independent room-specific negative account remain evidence gaps; this entry supports the value of believable interaction, not a complete Arx room reconstruction.

## 6.13 Verho – Curse of Faces — mini-dossier: return anchors and interruptions

Verho is not an unreleased comparison. The inspected store listing dates the PC release to November 10, 2025; Matt Wardell's July 28, 2026 review concerns **PS5**. It describes Nameless Village as an inhabited anchor, shrines and shortcuts supporting exploration, and improving movement. It also reports enemies interrupting dialogue, troublesome flying enemies, and repetitive attack patterns. Those are observations of that reviewed version, not automatically the PC launch state. [G21][G21S]

**Concrete mechanism:** a hub acquires identity through recurring services and people; returning has a reason beyond crossing a graph node. Pressure that intrudes on an interaction can instead make an otherwise atmospheric place annoying.

**Archipepsi lesson—interpretation:** decide where observation, conversation-like UI, or machine inspection is intended to be safe. Enemies need jobs relative to the place, but “always attacking” is not the only job. Current AI cannot be assumed to patrol or protect a control intelligently; such behavior needs implementation. First test a spatially protected inspection point and clearly bounded engagement region. Do not adopt deliberate sluggishness merely because the reference's atmosphere is effective.

## 6.14 Cryptmaster — mini-dossier: an action vocabulary can make a room feel authored

Original reviews describe examining chests through clues and guessing words, with discovered letters feeding the party's available actions. They also describe expressive interactions with altars. The attraction is not only solving a lock: language gives the environment a personality and connects exploration to what the player can do. The sampled reviews also raise visual-readability and input concerns. COGconnected specifically discusses PC typing and controller practicality; that does not establish the behavior of a later console port. [G23][G24]

**Interpretation:** the player notices an object, requests evidence, forms a hypothesis, and receives a response that belongs to the world's fiction. That can make a tiny encounter distinct without complex geometry. Repetition becomes a risk when the linguistic discovery loop stops changing and only action cost remains.

**Archipepsi lesson:** a machinery receiver should communicate what kind of interaction it accepts and what it changed. An expressive response can strengthen a simple operation without adding another puzzle layer. A free-text parser with broad semantic promises would be a substantial new subsystem and is not recommended here. The exact chest/altar room names were not established in the inspected evidence; do not turn a reported verb example into a universal parser capability.

## 6.15 Vaporum — mini-dossier: coherence can carry familiar mechanics

Michael Duhacek's October 10, 2017 PC review concerns **Vaporum**, not the later Lockdown game. It describes mechanical keys, wheels, doors, equipment choices, and increasingly demanding grid combat. Material consistency helps ordinary mechanisms belong to the setting rather than look like detached game tokens. The sampled account praises the puzzles and atmosphere; a strong independent named-room criticism was not established. [G25]

**Interpretation:** a familiar key-and-door operation can still be satisfying when it supports anticipation, material logic, and a coherent route. Novelty is not required in every interaction. A dark corridor also imposes an information cost, which must be justified by the tension or discovery it creates.

**Archipepsi lesson:** improve the causal and visual relationship between the control, mechanism, and route before inventing new puzzle families. A powered door should look and respond like part of a working place. Avoid treating a decorative feature tag as progression-critical machinery. This study does not support importing Lockdown-specific features, a particular time-control option, or an unverified room solution into the original game.

## 6.16 King's Field IV / The Ancient City — mini-dossier: sensory geography versus sluggish control

The April 2002 RPGFan PS2 review praises the Holy Forest's light, the scale and solitude of subterranean spaces, and sound that locates danger outside the narrow visible view. It also finds early combat cumbersome and turning frustratingly slow. A memorable large hall here is not simply an arena waiting to be filled; scale, partial information, and distant threat are part of its function. [G26]

**Interpretation:** sound can make unseen space consequential. A player may pause because an approaching threat or a distant opening deserves attention, not because the room contains a required interaction. But sensory uncertainty and controller friction are different costs.

**Archipepsi lesson:** use directional cues and recognizable structural silhouettes to support navigation and threat reading. Preserve quiet intervals where players can notice them. Do not slow Archipepsi's movement to imitate the reference's atmosphere, and do not assume every imposing room needs additional targets. First test whether a quiet reveal improves destination recall or anticipation. This is not a claim that the 2002 control scheme remains unchanged in every modern emulation or modification.

## 6.17 Monomyth — mini-dossier with a substantial evidence gap

The current official page still identifies Monomyth as **Early Access**, begun October 3, 2024. Early player discussion describes interconnected dungeon exploration and finding paths without constant instruction. That is useful first-hand testimony, but this investigation did not establish a sufficiently complete, named room/encounter reconstruction or a robust independent critical account. A surfaced preview could not be fully retrieved. [G27][G28]

**What can responsibly transfer:** interconnected discovery is worth testing in a compact authored Zone, especially where a new route makes a known room meaningful again. **What cannot responsibly be claimed:** that a particular Monomyth puzzle proves a specific implementation pattern, or that its current 2026 build has the same content and flaws as launch EA.

**Archipepsi question:** when an apparent dead end is later connected from another side, do players recognize the location and feel their spatial knowledge rewarded? That question is justified as an experiment, not presented as a proven Monomyth-derived causal result. The entry remains in the ledger rather than being silently replaced by another dungeon game.

## 6.18 Metroid Prime Remastered — extended: exploration's rewards can become an unexpected obligation

**Evidence and version.** Jesse Lab's February 18, 2023 Switch-specific essay praises atmosphere and updated controls but strongly dislikes the mandatory Chozo Artifact hunt. A contemporaneous artifact guide establishes the concrete regional collection structure. The essay acknowledges the opposing argument that artifacts can be collected along the journey, but that is not a separately sampled positive reception study. [G29][G30]

**Contrast A: Hall of the Elders, Chozo Ruins.** The artifact guide describes three beam-colored Morph Ball slots. With the Plasma Beam, activating the red slot moves the statue and reveals a doorway to an artifact. This is a concrete local revisit whose new capability changes a remembered object; its satisfaction is an interpretation to test, not a separate player testimonial. **Contrast B: Artifact Temple and the final collection requirement.** Twelve artifacts are necessary to reach the end; the critic experienced the hunt as an unwelcome change from voluntary discovery to obligatory retracing. A veteran who plans acquisition along the way has a different informational situation from a newcomer who recognizes the requirement late. [G29][G30]

**Mechanism reconstruction—interpretation.** The same route can support two experiences. In one, the player remembers a possibility and chooses to investigate it with a new ability. In the other, a late checklist sends the player back through already-understood spaces. The physical act of backtracking is similar; its motivation, timing, and expectation are not.

**Archipepsi transfer.** Make the role of a visible local gate understandable before asking the player to return. Use accepted repairs and shortcuts to reduce the burden of already-solved travel. Keep AP-required progression distinct from optional mastery or curiosity rewards. Do not introduce a late completion tax as a substitute for a satisfying finale.

This does **not** justify banning return-later capability gates. That is an unresolved project policy, and a deliberately planned revisit can be valuable. It argues for explicit guarantees, early communication, stable geography, and a worthwhile changed interaction. [R23]

**Test with two audiences.** First-time players reveal whether the map teaches its future possibilities. Repeat players reveal whether planning and route knowledge make revisits satisfying. A design that works only when the player has external knowledge should not be credited with teaching itself. Conversely, a shortcut that makes a familiar journey trivial can be a legitimate progression payoff rather than a broken challenge.

## 6.19 Metroid Prime 2: Echoes — mini-dossier: delayed availability changes a key hunt

The guide distinguishes regional temple keys from the nine remaining Sky Temple keys. Trial Tunnel and the Ing Hive’s Aerial Training Site contain regional keys; they are not Sky Temple-key caches. For the later hunt, Dark Oasis is a concrete example where the guide calls for a Power Bomb and the Light Suit, while the Dark Visor reveals the cache. Dated player discussion disputes the burden of the late hunt, particularly restrictions that limit how much can be collected during earlier exploration. This is the original game, not an assumed remaster. [G31][G32]

**Interpretation:** two superficially similar key hunts can differ because of when the player can act on remembered information. A clue noticed early is less useful if a late ability prevents every meaningful follow-through until the end.

**Archipepsi lesson:** record not just the existence of a gate but when its provider becomes guaranteed and when the player can reasonably know that. Mandatory progression must agree with the campaign/AP model. A global late unlock should not accidentally turn many earlier branches into one long cleanup pass. The sample is narrower than a full Sanctuary Fortress study; this entry does not substitute the first Prime's spaces or reception for Echoes.

## 6.20 Supraland — mini-dossier: exploration can be excellent while combat interrupts it

The inspected hint guide includes Red Crystal Tower and Volcano puzzle material; its early creation date means it is not independent proof of every current detail. An original review praises exploration and puzzle solving while finding combat and collection obligations less compelling. A world with many discoverable routes can therefore still suffer when the recurring interruption asks for an unrelated skill or resource payment. [G33][G34]

**Interpretation:** an action-puzzle hybrid is not improved merely by alternating combat and puzzles at a fixed interval. Combat should either create a meaningful spatial problem or provide an enjoyable action rhythm in its own right. It should not be defended solely because the genre label contains “action.”

**Archipepsi lesson:** test one puzzle route without combat, one with an enemy whose position changes the route decision, and one with an unrelated fight inserted between operations. Keep rewards and travel constant. The experiment can reveal whether combat is integrated, independently enjoyable, or only interruptive. Do not infer that the correct result is a universally combat-free game.

## 6.21 Supraland Six Inches Under — mini-dossier: vertical structure can carry more than traversal

This is a separate game, not a substitute entry for Supraland. The January 2022 PC review and later console reviews describe **Cagetown**, whose vertical arrangement connects route progression with a social hierarchy. Reaching higher parts of the settlement carries narrative meaning as well as geometric advancement. Reviews praise its puzzle/exploration qualities while some report getting lost or camera discomfort. Those platform/version differences remain relevant. [G35][G36]

**Interpretation:** “up” can mean a destination, a status change, a new perspective on a familiar hub, and a route constraint at once. That gives elevation identity beyond assigning a numerical content bonus.

**Archipepsi lesson:** a gallery or upper platform should change what can be seen, approached, or understood. Merely adding a ramp and placing enemies upstairs may diversify a silhouette without diversifying the player's decision. Reuse a visible vertical landmark across a short route so players can identify where they are relative to it. Do not copy a coin economy or social-fiction premise into Archipepsi without owner authority.

## 6.22 Frogmonster — mini-dossier: encounter identity is not identical to navigation identity

Original discussions name **Balsam**, a tree-like boss praised for its visual/animation character, while other threads describe aim difficulty and periods of aimless navigation. Developer responses in the sampled discussion address difficulty assistance and attack behavior. These are individual accounts with incompletely specified builds, not a representative verdict. [G37][G38]

**Interpretation:** a game can have memorable encounters while players struggle to understand the connecting world. Improving a boss roster would not necessarily fix route uncertainty. Conversely, a clear map cannot compensate for an unreadable attack.

**Archipepsi lesson:** test encounter recall and route recall separately. Ask players to identify what changed their positioning in a fight, then ask them to reconnect that room to neighboring places. A named visual enemy is not automatically a new tactical role; its attack timing and geometry must create a different response. No exact Balsam attack sequence or numerical tuning is imported here because the inspected evidence does not support a full reconstruction.

## 6.23 Journey to the Savage Planet — mini-dossier: curiosity can be lighter than dungeon tension

Original Xbox One and Switch reviews describe exploration, scanning, upgrades, and comic environmental discovery. These concern the original game, not its sequel or an assumed later edition. This sample supports the overall exploration loop more strongly than any named room; a sufficiently detailed room reconstruction and independent room-specific criticism remain gaps. [G39][G40]

**Interpretation:** motivation need not always come from threat, resource scarcity, or a locked door. A strange organism or visible oddity can invite investigation because the player expects a surprising response. That can support low-pressure spaces between demanding encounters.

**Archipepsi lesson:** test a quiet branch with a visible oddity and a coherent response rather than another mandatory target challenge. The response might reveal an alternate route or strengthen a location's fiction; it need not invent a new economy or grant another AP check. Measure voluntary investigation and remembered detail. Do not claim that a scanning subsystem is necessary: it would be new interface/content work, and a smaller observable interaction may answer the same question.

## 6.24 Vomitoreum — mini-dossier: clearing a place can turn danger into infrastructure

John Walker's October 8, 2021 PC/Linux review describes infinite ammunition, rechargeable healing resources, movement upgrades including double jump and larval access, and enemies that do not repopulate cleared areas. He specifically values the transition from careful first traversal to rapid later movement. The inspected review is strongly positive; an independent negative account was not established. [G41]

**Interpretation:** a return journey can reward the player's earlier work by becoming easy. It does not always need new enemies, a new hazard, or another puzzle. A formerly hostile route can become useful infrastructure.

**Archipepsi lesson:** compare a persistent cleared route with a respawned route while keeping progression and rewards identical. Do not assume the latter has more value because it contains more action. Also do not copy the reference's ammunition/healing economy: it supports the non-respawning design and may not match Archipepsi. The relevant question is whether required returns feel like ownership and mastery or repeated clearance labor.

## 6.25 Supraworld — mini-dossier: a larger possibility space can still feel underused

The official page remains Early Access, beginning August 15, 2025. Dayten Rose's September 8, 2025 critique concerns the opening EA act, not all content available in September 2026. It discusses progression that initially grants basic actions such as walking and jumping, movement that can feel good, and isolated inventive situations that do not always develop into a broader toolkit. It also reports visual/camera discomfort and frustration with conventional combat/progression demands. [G42][G43]

**Interpretation:** withholding an ability is not automatically a meaningful capability gate. Its value depends on whether acquisition changes interpretation and creates worthwhile new action, rather than granting permission for an obvious routine.

**Archipepsi lesson:** prefer an acquisition loop that changes how a remembered place can be approached. The railway's grapple premise is a more promising test than repeatedly denying basic interactions. However, its current scenario grant is not the complete campaign integration. [R23] Do not claim Supraworld's 2025 criticisms are current bugs, and do not treat one negative review as consensus about the whole project.

## 6.26 DUSK — extended: anticipation, release, and controlled changes in spatial expectation

**Evidence and version.** Ian Birnbaum's December 12, 2018 PC review concerns the original base game. An independent 2019 review and a later original Escher Labs discussion broaden the sample. This is not a study of DUSK HD. [G44][G45][G46]

**Contrast A: opening farm/industrial spaces.** The launch reviewer emphasizes movement through projectile pressure and enemies that can be grouped or redirected around the environment. **Contrast B: Ruins Access and Escher Labs.** The review describes a warning and breathing behind a closed door creating fear before a fight. The Escher Labs discussion identifies a different remembered segment, where changing expectations and horror presentation dominate recall. That discussion is anecdotal; no video of the level was inspected. [G44][G45]

**Mechanism reconstruction—interpretation.** In the fast encounter, the player reads a changing field of trajectories and chooses a movement path. In the threatening approach, the player has time to form a prediction about unseen space. Silence and restraint give later action a contrast that adding enemies continuously would erase.

**Archipepsi transfer.** A quiet approach to a railway yard can establish the route, the raised span, and the gunner's position before the ride starts. Then moving cover can change the immediate action problem. These should be distinct moments, not an inspection task continuously interrupted by damage.

The reference does not imply that very simple AI is always sufficient. It suggests testing whether the current ranged/melee/brute vocabulary can create different pressures through placement before committing to a much larger behavior catalog. If the same behavior fails to hold a flank or recognize a player behind cover, record that precise limitation and extend it deliberately.

**Counterexample discipline.** A visually bizarre room is not automatically good; it must still communicate what action is possible. This sample has stronger positive and mechanism evidence than independent negative evidence for the exact two named segments. Do not present them as universally successful templates or infer that Archipepsi should become a horror shooter.

## 6.27 ULTRAKILL — mini-dossier: mastery can reframe an encounter's objective

The official store still identifies ULTRAKILL as Early Access. A June 2021 player challenge guide describes **4-2: God Damn the Sun**, including a route that uses the Insurrectionist's jump and breakable glass to achieve an unusually fast kill. The guide also treats movement constraints in 4-1 as a separate mastery problem. These are documented player routes in that era, not verified behavior of every subsequent build. [G47][G48]

**Interpretation:** the interesting outcome is not simply higher damage. The player interprets enemy behavior, environmental fragility, position, and timing as a combined tool. Optional challenges can ask a player to revisit a familiar space with a different optimization target.

**Archipepsi lesson:** Counterfire already provides a modest analogous relationship without special “baited” AI. Test whether players discover it and whether experienced players deliberately repeat it. Do not import extreme movement or competitive timing quotas into every room. A spectacular bypass that is acceptable in an optional challenge can still be invalid if it duplicates rewards, skips required state, or strands multiworld progression.

## 6.28 Turbo Overkill — extended: expressive movement needs room, but continuous escalation has a cost

**Evidence and version.** Darragh Murphy's April 30, 2022 review covers Early Access Episode 1. Zoey Handley's August 11, 2023 review covers the 1.0 game. A 2025 console review is a separate later perspective. Their differences are not falsely presented as simultaneous opinions on one identical build. [G49][G50][G51]

**Contrast A: Rooftops.** The EA review describes jump pads, aerial movement, hostile fire, and falling risk producing a different demand from tighter corridors. **Contrast B: late Episode 3.** The 1.0 review finds the climax overextended and the continuous intensity tiring, despite enjoying the core action. It also questions whether the large arsenal produces proportionately distinct choices. [G49][G50]

**Mechanism reconstruction—interpretation.** In a movement-rich arena, the player perceives several useful heights and trajectories, commits to one, and manages exposure while moving. The expressive choice is valuable because geometry gives it consequences. At campaign scale, however, extending the same high-intensity demand can reduce appetite rather than increase payoff.

**Archipepsi transfer.** Preserve the room height and movement qualities the owner liked where they serve meaningful approach choices. Do not shrink every room to eliminate emptiness. Instead, ask what moving across the large space lets the player do: change firing angle, bypass a lane, reach a useful overlook, or return quickly through a repaired connection.

Then test a quiet observation beat before or after the movement encounter. Its value is not “less content”; it may make the player's next decision clearer and the preceding intensity more memorable. A campaign composed entirely of landmark-value encounters risks removing the contrast that makes a landmark distinctive.

**Prototype discriminator.** Keep the same shell, enemy roster, and weapon loadout. Change only enemy positions and route access. Ask whether the movement choices felt purposeful, not merely whether the player used a dash. A dash count alone cannot tell deliberate repositioning from habitual movement. The earlier EA review's specific bugs are not current 1.0 defects unless retested.

## 6.29 AMID EVIL — mini-dossier: a harmless fall can still be an expensive failure

Tyler Wilde's June 26, 2019 PC review describes a visually impressive moving-gear area whose route changes were difficult to follow, an astral encounter involving enormous serpents and a floating water globe, and narrow/disappearing-platform traversal that interrupted the fast shooting rhythm. Falling without health damage could still mean an irritating climb back. Exact map labels for those segments were not established. [G52]

**Interpretation:** conceptual difficulty, precision difficulty, and recovery cost are independent. A failure can be nonlethal yet too expensive in repetition. Conversely, a large unusual arena can earn its scale through an encounter that uses it, rather than through floor area alone.

**Archipepsi lesson:** Passing Platforms' recovery floor is a good start, but measure time and effort from landing there to making another informed attempt. Do not equate “not softlocked” with “good retry.” For remote machinery, make the direction of the consequence evident enough that an already-solved operation does not become a hunt for the route it opened.

## 6.30 CULTIC — mini-dossier: combat and interaction can support horror without constant fighting

Ted Litchfield's December 11, 2025 PC review covers **both chapters**, including Chapter 2's mall and mannequin sequence. It contrasts memorable varied spaces and strong combat with an overlong final stretch. The mall's unsettling interaction is not simply another enemy wave; the possibility of threat changes how an object-focused segment is read. [G53]

**Interpretation:** tension can come from expectation rather than continuous attack. The release into ordinary combat can feel good partly because the preceding segment asked for a different kind of attention. A familiar building type also gives actions and objects contextual meaning.

**Archipepsi lesson:** a room can legitimately omit combat while preparing its geography and stakes. An enemy used as a machine input should not require simultaneous searching through unreadable controls. Separate the reveal, the decision, and the execution where helpful. Do not copy scripted horror or a mansion aesthetic as a substitute for relational design; those would be new content choices, not evidence-based necessities.

## 6.31 Quake — extended: the same small roster can produce different spatial decisions

**Evidence and version.** Level designer Andrew Yoder's November 23, 2017 first-hand analysis examines original Quake maps. It is close spatial criticism, not a developer-intent statement or representative reception study. [G54]

**Contrast A: E1M1, Slipgate Complex.** A dog pressures the bridge while ranged danger occupies the far side; water and its recovery route alter the cost of losing position. **Contrast B: E1M2, Castle of the Damned.** The initial elevated view changes how combat begins, while an ogre, grenades, low ground, water, and stairs change which positions remain safe. Enemy identity alone does not describe either encounter. [G54]

**Mechanism reconstruction—interpretation.** Entry position gives or withholds observation. A route exposes the player to a particular threat. Movement changes the relative safety of that threat rather than merely reducing the distance to it. Recovery geometry influences whether taking a risk is attractive. The player can therefore face a small enemy vocabulary and still make different decisions.

**Archipepsi transfer.** Use the existing c002 arena as a controlled specimen, not a finished design exemplar. It already has ranged enemies and a gallery. One arrangement can allow all enemies to be fought from the doorway; another can let gallery access interrupt a firing lane or create a new angle. Keep roster and damage constant. The important changed variable is the relationship between approach, exposure, and enemy position. [R27]

This does not authorize copying Quake's movement envelope. Test Archipepsi's actual capsule, jump, grapple, and firing behavior. Nor does it mean every arena needs water, a bridge, or an ogre-equivalent. These are ways to reason about a situation, not ingredients for a mandatory room recipe.

**Falsification.** If players choose the same doorway strategy in every arrangement, investigate whether the alternative is unreadable, unrewarding, physically awkward, or unsupported by enemy behavior. Do not immediately add another enemy type. If a new behavior is genuinely necessary, define its job—holding a lane, displacing a stationary player, protecting an approach—and implement the bounded support it needs.

## 6.32 Prodeus — mini-dossier: replayable spaces and failure policy are separate decisions

Mitch Vogel's November 3, 2022 Switch review praises the mixture of combat and exploration and specifically describes **Black Magic Society**, a user-created map with constricting passages, traps, and moving walls. That is a custom map, not an unnamed official campaign level. A 2021 EA discussion separately disputes checkpoint behavior: some players value reduced punishment, while others feel retained progress after death removes meaningful stakes. The latter is dated evidence, not proof of the current checkpoint implementation. [G55][G56]

**Interpretation:** supporting authored community situations can produce spatial variety, but failure rules determine how those situations are experienced. The same room can feel demanding, permissive, or tedious under different retry policies.

**Archipepsi lesson:** distinguish retrying a local interaction, respawning in the Zone, leaving/re-entering, and reloading a save. A permanent repair can remain while enemies or temporary machinery reset according to the intended contract. Do not assume “everything resets” or “nothing resets” is the only coherent policy. Test whether the resulting retry preserves both learning and a meaningful consequence.

## 6.33 Selaco — mini-dossier: excellent combat does not automatically make a map readable

The current store still labels Selaco Early Access. First-hand 2024 coverage strongly praises its action and environment, while an original September 2024 player post describes becoming badly lost around the parking-garage escape. That is one player's experience, not a frequency estimate or evidence that later updates have not changed navigation. [G57][G58][G59]

**Interpretation:** combat quality and navigation quality can diverge. More detailed scenery may strengthen place identity while increasing the number of plausible-looking but irrelevant routes. A player can know what the objective is and still not know which already-explored connection reaches it.

**Archipepsi lesson:** run route-recall tests even when an encounter is liked. Use distinct silhouettes, meaningful sightlines, consistent doors, and consequences that point toward their affected space. Do not treat a map overlay as an automatic cure: first determine whether the failure is visual recognition, forgotten information, hidden state change, or genuinely interesting uncertainty. Complex squad behavior is additional AI/system work, not something generated by assigning a richer enemy label.

---

# 7. Targeted transfer studies: why these additions earn space

## 7.1 Prey (2017) and Mooncrash: alternative solutions must exist in the implementation

A first-hand Prey review recounts entering a locked office by shooting foam darts through a window at a terminal's door controls. The keycard route also existed. The critic praises that creative access while finding combat weaker. This is a concrete case where a tool's environmental use matters more than its damage category. [X01]

Ricky Llamas's own Mooncrash design account identifies limited lateral mobility as a combat problem made worse by low gravity. His early propulsion prototype was still too slow; a later version made lateral movement broad and fast. An upward-thrust feature was cut when changes to **Crater** removed much of the geometry that would justify it. Separately, Ricardo Bare describes the corruption timer and delay items as an attempt to balance pressure with exploration. [X02][X03]

**Transfer—interpretation:** optional routes need supported operations, not just textual permission to be creative. Movement should be evaluated with the rooms it serves. Archipepsi should not add vertical tools after flattening every room, or add a timer to every puzzle because a roguelike uses one. Counterfire's alternate receiver access is a small implemented example worth testing. A permanent expedition-wide pressure meter would be a new campaign system and an unresolved taste choice, not a bounded fix.

## 7.2 Dishonored 2: changing geometry can create discovery and completionist confusion

An original Clockwork Mansion account describes moving walls and floors producing opportunities to enter the spaces between arrangements. An independent player discussion contrasts the mansion with Stilton's Manor: some enjoy exploring the machinery, while others find ghosting, laboratory access, or final collectible searches tedious. [X04][X05]

**Transfer—interpretation:** a mutable room needs a stable reference model. Players should know what the control affects even when they do not yet know the optimal sequence. A compact barrier-and-lamp configuration can test that before building a transforming mansion. Allowing an observation window or local reader is not a violation of cross-room design; local feedback may make the distant consequence understandable. [R31]

This addition earns space because it combines multiple approach styles with changing spatial state. It does not establish that Archipepsi needs time travel, moving entire rooms, stealth scoring, or collectible quotas. The first two would be substantial new subsystems; the latter two could conflict with the intended flow.

## 7.3 Titanfall 2: prototype an experience before committing to its production grammar

Christopher Dionne's GDC 2018 session description identifies **Into the Abyss** and **Effect and Cause**, and says the team used “action blocks” to escape familiar results from its earlier process. **Only the published session abstract was inspected, not the talk or slides.** It supports the existence and stated purpose of the method, not detailed claims about every prototype or production decision. [X06]

**Transfer—proposal:** build a small playable block around one proposition—riding changes the cover angle; an object has two conflicting uses; a repair shortens the return. Evaluate that experience before committing its parameters to a generation schema. This is not a recommendation to make a parade of disconnected set pieces. The final integration test must connect blocks into an ordinary campaign journey and check whether their transitions and revisits remain meaningful.

## 7.4 Neon White: execution mastery needs a short, legible learning loop

An original August 2022 review describes weapon cards whose disposal provides traversal actions, making route planning and action execution inseparable. A separate August 2022 first-hand essay admires the game but reports fatigue as later levels grow longer and a mistake means replaying more already-solved execution. [X07][X08]

**Transfer—interpretation:** a short optional mastery route can invite repetition when the next attempt is immediate and its improvement is intelligible. That is different from requiring every explorer to perform a long flawless sequence. Archipepsi can offer a faster moving-platform transfer alongside a patient route, or a more direct combat approach for strong movement loadouts. Do not import disposable cards, rankings, or a race quota; those would change the economy and purpose of play.

## 7.5 Bomb Rush Cyberfunk: a room's rails are a route vocabulary, not thematic decoration

The original PC review praises movement across city spaces and the breadth of routes while noting a disorienting map and a gap between written story and environmental storytelling. An original August 2023 discussion explains why players search for new corners and wallrides to grow a combo, and reports confusion when collisions break it, including in **Versum Hill**. [X09][X10]

**Transfer—interpretation:** traversal objects become meaningful when their relationship supports a route the player wants to compose. A rail placed in a room labelled `neon_transit` is not equivalent to that experience. The checked-in Archipepsi fixture explicitly names Bomb Rush Cyberfunk, but that provenance is not proof that its movement/score relationships were transferred. [R27]

This is a **third-person transfer study**. A third-person camera makes upcoming rail turns, body alignment, and recovery differently readable. Archipepsi must verify first-person sightlines and camera comfort. Borrow route continuity and environmental opportunities, not the entire scoring loop or camera behavior.

## 7.6 Zelda's Water Temple: redesign friction without discarding the central idea

Nintendo's development interview for Ocarina of Time 3D identifies easier Iron Boots switching and map access as central repairs to the Water Temple experience. This is direct developer evidence about a revision, not proof that every original complaint was caused by the interface. [X11]

**Transfer—interpretation:** a cross-room configuration puzzle can be conceptually sound yet unpleasant because it requires excessive menu work, repeated setup, or checking forgotten information. Archipepsi should test the speed and clarity of operating a known control independently from the difficulty of understanding what it does. A known configuration change should not demand navigating a debug-style variable identifier without meaningful world feedback.

The transferable case is the revision principle. A full water-level simulation, fluid transport, and a multi-floor Zelda dungeon are not required to test it. Existing typed macro state is enough for a bounded experiment. Preserve difficulty that comes from understanding relationships; remove accidental difficulty that merely prevents acting on understanding.

## 7.7 Spelunky and Dead Cells: procedural variation needs constraints with experiential meaning

Derek Yu's original EXPLORER.GMK book excerpt explains how destructible terrain and finite tools support alternative routes and change what level generation can safely produce. His account also argues that theme helps players understand rules. Motion Twin's early development description explicitly contrasts routes such as sewers and ramparts in terms of difficulty, length, and playstyle, while allowing quieter exploration. That page is historical development intent, **not evidence that Dead Cells is currently unreleased** or that every promised relationship shipped exactly as described. [X12][X13]

**Transfer—interpretation:** choose what must remain invariant before allowing variation. A route should retain the relationship that makes it desirable; a hazard should retain a visible response opportunity; a required object should retain recovery. Merely randomizing room count is not equivalent to varying a strategic route.

Both are **2D transfer studies**. Their information visibility, traversal, and collision assumptions do not directly apply to first-person 3D. Archipepsi should borrow constrained recombination and build-sensitive choice, not assume universal destruction makes AP progression safe. Arbitrary destructibility would be a major new system, especially with validated geometry and persistent state.

## 7.8 Resident Evil HD Remaster: a compact map can carry a changing route cost

Andy Kelly's January 19, 2015 review describes the Spencer mansion as a place where finite resources, item capacity, locked access, and potentially returning enemies make repeated journeys consequential. Burning bodies can affect later danger. The review values that tension while acknowledging clunky controls and the frustration of lost progress. This is the 2015 version of the 2002 remake, not the unchanged 1996 map. [X14]

**Transfer—interpretation:** a small set of rooms can remain meaningful when their cost and accessibility change. But copying scarce saves or inventory pressure would conflict with low-cost experimentation unless deliberately chosen. Archipepsi can first test a repaired shortcut, a permanently cleared route, and a reversible obstruction. This retains changing route meaning without inventing survival-horror economics.

The fixed-camera third-person presentation is another transfer limit. A blind corner's suspense in Resident Evil does not justify an unreadable off-screen attack in a high-speed first-person experiment.

---

# 8. Genre synthesis: compatible mechanisms and real conflicts

## 8.1 Puzzle games

The most useful pattern is a stable rule producing a changing inference. Teaching, testing, and recontextualization are different tasks. The reviewed examples also show a recurring distinction between understanding an answer and getting the interface or timing to execute it. [G01][G02][G06][G11]

**Proposed implication:** give a puzzle a bounded question. Remove unrelated pressure while teaching it, then test whether adding pressure later deepens the learned relationship. Do not assume an ordered activity is an insight puzzle.

## 8.2 Dungeon games

The strongest transferable qualities are locality, material coherence, incomplete but recoverable knowledge, and remembered routes. The failure modes include difficulty determining whether a solution is presently possible, losing the location of a known input, and combat friction that outlasts its atmosphere. [G15][G17][G18][G26]

**Proposed implication:** make the Zone a place with state and memory, not a bag of independent challenges. Protect required objects and distinguish deferred possibilities from missing information.

## 8.3 Metroidvania/exploration hybrids

The useful mechanism is reinterpreting a known place with a new capability, resource relationship, or route. The dangerous substitute is a late checklist that makes previously optional-looking exploration mandatory. Cleared routes can also become intentionally easy. [G29][G31][G35][G41]

**Proposed implication:** permit earned trivialization where it expresses growth. Progression safety should protect the campaign contract, not force every old obstacle to remain equally difficult forever.

## 8.4 Boomer shooters and related FPS

The useful pattern is immediate spatial pressure: who can hit from where, what movement changes that, which threats overlap, and what recovery exists. The counterexamples concern unclear changed routes, precision platforming with long recovery, and escalation that becomes tiring. [G44][G49][G50][G52][G54]

**Proposed implication:** first give the existing enemy roster spatial jobs. Only add behavior when a tested encounter needs it and the current implementation cannot provide it.

## 8.5 Conflicts that cannot be solved by combining every feature

| Pressure | Works when… | Conflicts with… | Resolution to test |
|---|---|---|---|
| Urgency | The player understands the action and wants an execution challenge. | First-time rule inference and careful world inspection. | Safe observation first; optional fast execution after understanding. |
| Open exploration | Several questions and routes remain useful. | Requiring one exact hidden action before anything else can proceed. | A small number of legible deferrable leads, not maximum branching. |
| Powerful movement | It changes approach, pace, and mastery. | A puzzle whose sole challenge is an unprotected jump distance. | Protect essential state rather than every intended physical route; accept legal bypasses. |
| Persistent consequences | They let effort and memory matter. | Automatically resetting every interaction for replayability. | Classify temporary, reversible, permanent, and progression state explicitly. |
| Resource scarcity | It creates meaningful commitment and route choice. | Cheap experimentation with unclear rules. | Do not add scarcity until the rule and its feedback are understood. |
| Procedural novelty | Relationships survive variation. | Clues and memories tied to an unstable arrangement. | Commit validated manifests; vary bounded parameters and compatible situations. |
| Completionist content | Optional search remains interesting and trackable. | Hidden mandatory cleanup after apparent completion. | Keep mandatory obligations clear; preserve discovered information. |

These are design hypotheses and decision tools, not universal laws established by the convenience sample.

---

# 9. A relational room vocabulary — tools, not quotas

A room does not need every item in this vocabulary. Use a term only when it describes what a player can actually perceive or do.

| Term | Operational meaning | A useful authoring/test question |
|---|---|---|
| **Situation** | A relationship that changes what action makes sense. | Can the player explain the room without listing its objects? |
| **Safe observation** | A position or interval from which necessary evidence can be inspected without involuntary punishment. | Can a first-time player understand the relevant options before committing? |
| **Pressure lane** | A region where a particular threat changes the cost of movement or exposure. | Which enemy can act here, and what action changes that fact? |
| **Commitment** | Choosing an action temporarily removes or worsens another option. | Is the consequence predictable enough to feel chosen? |
| **Dual-use conflict** | One object is useful in two ways that cannot initially be satisfied together. | Does the player discover a real conflict, or just perform two chores? |
| **Reveal** | A new view or response changes the player's model of the place. | What becomes newly understood, rather than merely newly visible? |
| **Mutable route** | A supported state change alters reachable or useful connections. | Does the actual geometry agree with the declared state in both directions? |
| **Cross-room consequence** | An action here changes something meaningful elsewhere. | Can the player recognize the relationship without omniscient exposition? |
| **Landmark** | A stable, distinctive reference used for orientation or anticipation. | Can players place it relative to routes after leaving? |
| **Secret** | An optional reward for observation, inference, or mastery. | Is its discovery different from exhaustive wall checking? |
| **Recovery** | A reliable path from a failed attempt back to meaningful choice. | How much solved work must be repeated? |
| **Quiet space** | A room or interval supporting anticipation, orientation, relief, or atmosphere. | What does the player attend to here? |
| **Return dividend** | Earlier effort or later growth makes a revisit newly useful or satisfyingly easier. | What is different about this journey from the last one? |
| **Information debt** | A design asks the player to remember more than it helps them organize. | Is the player missing an answer, or merely the location of known information? |

The vocabulary leads to a better authoring question than “does this room have a puzzle, combat, traversal, and loot?” Ask instead: **what should change in the player's understanding or available action, and what makes that change legible?**

## 9.1 Explicit answers to the brief's recurring questions

**What gives a room identity?** A distinctive relationship among what is perceived, chosen, performed, and changed. Theme and shape support that relationship, but neither substitutes for it. A purely atmospheric room can still have identity through a unique reveal or reference point.

**When is a small room satisfying?** When a small amount of space creates a clear, consequential interaction or frames a memorable view. **When is a large room worthwhile?** When distance, elevation, visibility, scale, or movement materially changes the experience. “Empty” must be judged against that function, not object density.

**What is an insight puzzle?** A task where the player must revise or combine an understanding of rules to find an action. Operating an obvious control can still be valuable as an earned repair, pacing beat, or commitment; it need not be mislabelled a puzzle.

**How should rules be taught and inverted?** Make the first causal result unmistakable, vary the surface arrangement, and test transfer. An inversion should follow the same rule under changed conditions, not introduce an arbitrary exception.

**When does combat belong?** When its action loop is enjoyable on its own or its spatial pressure changes a meaningful decision. A room can legitimately have no combat. Unrelated enemies are not automatically “integration.”

**What motivates a room?** A visible destination, unanswered question, useful route, needed resource, satisfying action, optional mastery, or coherent fiction can each suffice. The project does not need a new currency to motivate every branch.

**Which revisits work?** Those that reward memory, reveal an implication, alter a route, or let earlier effort pay off. Repeating solved work because the player missed an undisclosed obligation is a different proposition.

**How should navigation aids cooperate?** Silhouette and sightline orient; doors and signs distinguish connections; audio can identify direction; a map preserves discovered relations; a gate note preserves a known deferred question. None should silently reveal unvisited content unless that is an explicit design choice.

**What if movement makes old content easy?** That can be progression's reward. Reject a bypass for violating the progression/state contract, not merely for reducing traversal time. Test whether the remaining interaction is still meaningful.

**What makes failure informative?** A perceivable cause and a cheap route to another hypothesis. Separate the idea being wrong from the input being late, the object being lost, the camera hiding the cue, or the setup being tedious.

**What permits systemic surprise?** Shared implemented rules, bounded exceptions, visible consequences, and recovery. Do not promise global object transport, fluid behavior, or arbitrary destruction merely because a scenario suggests it.

**What should be authored?** The relationships that make the situation intelligible, including observation, required operation, consequence, and recovery. Parameters may vary only inside the tested envelope. A silhouette or route can vary more widely when it does not break those relations.

**Whose enjoyment?** A novice may value safe inference; an expert may value rapid execution; a completionist may need reliable discovered-state tracking; an explorer may prefer multiple unanswered questions; a speedrunner may celebrate a legal bypass; an accessibility-sensitive player may need alternate signals or input tolerance. Record these differences instead of collapsing them into one taste.

---

# 10. Concrete Archipepsi before/after concepts

All new titles and layouts below are **proposals**, not names of shipped rooms. Existing scenario names retain their source meanings. Numerical geometry from a fixture is reported as source data, not a fresh physical measurement.

## 10.1 c002: from declared contents to two different fights

**Actual baseline inspected.** The checked-in `played_zone.json` describes c002 as a roughly **13.8 × 15.8 m arena**, with **five ranged enemies**, a kill-all objective, **two target challenges of five and two elements**, red and gold keys, and a raised left-side gallery. The fixture names Bomb Rush Cyberfunk and a neon-transit theme. The enemy world positions and full committed layout manifest were not inspected. This is not a claim that a current randomly generated c002 has those same properties. [R27]

**Proposed variant A — “Doorway Battery.”** Use the fixture's shell dimensions, gallery, roster, target counts, keys, and reward assignment, but author an experimental arrangement in which the player can fight all five gunners from essentially the same doorway approach. This is an intentionally simple comparator, not an assertion that the shipped room already has that arrangement.

**Proposed variant B — “Gallery Crossfire.”** Keep those ingredients and health/damage values. Move the gunners into assignments that make gallery access change the firing relationship: a position safe from one lane is exposed to another; gaining the gallery creates a useful angle rather than just bringing the player closer. Use existing geometry where possible; any added cover must be identical across A and B. The target tasks should remain equally legible and should not secretly become new machinery puzzles in only one condition.

**What the player does:** observes from an entry position; identifies a safer approach; chooses between pressuring the near gunner and taking the longer gallery route; uses actual movement to change exposure; understands why the chosen position worked.

**Surface/cost:** an explicit experimental placement harness first; bounded encounter-role/anchor authoring for production later. The current archetype/count declaration is not itself an enemy-position authoring API. Relevant surfaces are `composition.py`, generation/content placement, and `enemy.gd`, with physical validation retained. [R06][R13][R19]

**Risk/rejection:** the alternatives may be unreadable, current stationary enemies may allow one dominant solution, or strong Echoes may erase the intended distinction. Test those outcomes before adding patrols or suppressors. Success is different explained decisions and preferable play, not a longer completion time.

## 10.2 Unweighted Switch: compare causality without adding ingredients

**Actual baseline.** The crate is simultaneously a needed step and a class-sensitive plate input. Lightening changes the sensed class while preserving the collision shape. The temporary opening and far-side bolt create a before/after route relationship. This already exists in the development scenario; the scenario does not certify ordinary campaign save/load. [R26][R32]

**Proposed comparator A — “Useful Weight.”** With the same crate, plate, sill, shutter, applicator, service drive, and far-side release, let the heavy state open the shutter. The player positions the useful step and follows a straightforward action sequence.

**Proposed comparator B — existing dual-use conflict.** The heavy state closes the shutter. The player must preserve the step while changing what the sensor recognizes. Change the relevant wiring relationship, not the number of props. The simpler version is not automatically inferior; it may be a better repair beat even if the conflict version is a better insight puzzle.

**Control conceptual versus timing difficulty.** First compare generous-duration versions so a correct inference is not obscured by a short window. Then separately compare the normal temporary effect. Counterbalance order where possible, but do not pretend that someone who has learned the solution is a fresh novice for the next variant.

**What the player does:** tests the crate's support; notices the door response; explains why the obvious useful position also prevents passage; applies the status; crosses; operates the far-side release; sees that return no longer requires repeating the temporary sequence.

**Surface/cost:** existing scenario and status capability; bounded parameter/wiring experiment. Campaign placement, recovery, snapshots, and re-entry are a separate integration task. Do not add mandatory cross-room crate carrying before M7.

## 10.3 Counterfire Arcade: from functional trick to understandable choice

**Actual baseline.** A real ranged enemy's projectile can hit a receiver and open a temporary service route. The player has a baseline alternative through the gallery/receiver side, so killing the gunner does not remove completion. The far-side bolt supports return. The gunner does not have a special “baited” behavior. [R30]

**Proposed revision — “Borrowed Shot.”** Improve presentation around the existing relationship: a protected observation point shows the receiver and the blocked route; the bait position makes the intended alignment plausible; receiver activation produces a distinct local response and an obvious route consequence. An optional first harmless demonstration can be tested separately rather than assumed necessary.

**Critical execution detail:** the current enemy aims at the player when releasing the shot, not at the beginning of its windup. Therefore the relevant action is **let the shot release, then leave its trajectory**, not “dodge as soon as the tell starts.” Tuning must respect that actual behavior. [R14]

**What the player does:** recognizes an input the receiver could accept; chooses whether to use the gunner or take the alternative; aligns a shot; leaves the path after release; sees why the receiver activated; reaches the route; opens the permanent return.

**Surface/cost:** existing content needing better communication and tuning, then campaign integration. A new projectile-perception AI, universal signal network, or new status is not required for this experiment.

**Risk/rejection:** a precision bait may feel like waiting or tricking an unreliable system. Players may understandably shoot the gunner immediately. Treat that as legitimate unless the presentation successfully establishes another choice. Preserve the alternative; do not punish an ordinary combat response with a softlock.

## 10.4 Blindside railway: make the return the payoff

**Actual baseline.** The ledger records a ride, a blocked continuation, a walking branch, grapple acquisition, return, grapple operation, and continued travel. Carrier/home-dock and repair persistence have received implementation work. The grant remains a scenario-level acquisition rather than a complete AP flow. [R21][R23]

**Proposed revision — “The Route You Repair.”** Before departure, show enough of the raised continuation that the first ride creates anticipation rather than surprise administrative refusal. The walking branch should expose another view of the same structure. After acquisition, let the player recognize why the earlier obstacle is now actionable. The resumed ride should visibly use the route whose repair they earned.

**What the player does:** predicts a destination; rides under changing pressure; understands the specific obstruction; takes a motivated branch; acquires a relevant capability; returns by a legible connection; operates the mechanism; experiences a changed journey.

**Surface/cost:** presentation/content and proper acquisition integration, not a new railway. No branchable rail network is assumed: the implemented railway's ordered docks and the walking branch are different topology concepts. Test solo and multiworld separately.

**Risk/rejection:** the acquisition may arrive from AP at a different time; returning may require too much unchanged travel; a powerful optional Echo may legally bypass the intended climb. Protect the required state and other-player progression, not a single cinematic route.

## 10.5 Cross-room configuration: replace maximum distance with legible consequence

**Actual baseline.** `cross_room.py` is an opt-in composer. It can choose a setter early in the spine and a reader farther away; D-8 has current state/runtime/protocol support. `ZoneStateBuild` currently instantiates closed-vocabulary barriers and lamps relative to room arrivals. [R12][R22][R31]

**Proposed six-room test — “Return Line.”** Use the same small rooms, checks, content, and state variable in three route arrangements. In one, the control's consequence is remote and reached by retracing a chain. In another, a loop brings the player back to the affected route from a recognizable side. In a third, a nearby sightline or local indicator makes the remote consequence easier to identify while preserving the same required travel.

**What the player does:** sees a blocked route; forms a hypothesis about its control; follows a motivated branch; changes the configuration; recognizes what changed; uses the new connection; later returns without relearning the whole map.

**Surface/cost:** existing macro capability plus bounded semantic placement/edge-binding authoring. The geometry must prove that the barrier occupies the intended cut, that both selectable states are physically safe, and that the player can recover after a reversal. A lamp is feedback, not proof of passability.

**Risk/rejection:** local indicators may over-explain; distant effects may be satisfying for experts but confusing for novices; a loop may win merely by being shorter. The three-condition design helps distinguish those causes. No arbitrary hydraulics, fluid volumes, or carryable propagation is assumed.

## 10.6 Passing Platforms: strengthen two existing ways to succeed

**Actual baseline.** The ledger already records a patient route, moving transfers, a lift/shuttle arrangement, and a lower recovery floor. [R23]

**Proposed revision — “Choose Your Crossing.”** Make the patient route recognizable without labelling it the inferior option. Let the fast transfer reward timing and movement, while the stopped-shuttle route rewards understanding and planning. On recovery, return the player to a position where the relevant motion can be observed again rather than requiring a long blind climb.

**What the player does:** watches one complete cycle; identifies a meeting point or a way to stop the machinery; chooses execution risk; either transfers quickly or configures a stable route; recovers without losing the conceptual progress of the attempt.

**Surface/cost:** existing content and tuning; campaign support remains separate. Test camera motion, deck dimensions, timing cues, and recovery effort with the actual player, not paper distances. Success is preference plus understood choice, not maximizing the proportion of players who use the fastest route.

---

# 11. Prioritized prototype program

These are **proposed experiments**, not claims that a human study has already been run. Start with small observational sessions; do not pretend a few friends establish statistical significance.

## 11.1 Freeze the evidence before changing the design

For each trial record: commit, scenario/Zone identifier, provider (model/fallback/authored experimental fixture), request and response identities where available, committed manifest, shell IDs, capabilities, equipped Echoes, local/AP progression state, input device, relevant display settings, and whether the player has seen the solution before.

Keep the original fixture unchanged. Create explicitly named experimental derivatives. Disable or account for content-budget top-ups. Do not regenerate a known layout between attempts. A different room, different loadout, and different camera setting cannot all be introduced while calling the result a test of one encounter relationship.

## 11.2 The core controlled comparisons

| Priority | Question | Controlled comparison | Keep fixed | Observe | Result that would reject the current hypothesis |
|---|---|---|---|---|---|
| P1 | Can geometry make the current roster interesting? | c002 doorway arrangement versus gallery-related assignments. | Shell/cover, roster, HP/damage, loadout, checks, target tasks. | Chosen approach and reason, exposure changes, enjoyment, dominant strategy. | No meaningful choice difference after both layouts are understood; AI or core combat may be the binding problem. |
| P2 | Does causal conflict improve the puzzle? | Same Unweighted ingredients with straightforward versus conflicting sensor consequence. | Object set, dimensions, generous initial duration, entry/reward. | Inference, explanation, transfer to a new arrangement, frustration cause. | More steps without a valued insight; simpler operation may be the better pacing beat. |
| P3 | Does route structure make return meaningful? | Same six rooms as chain, recognizable loop, and information-improved loop/control. | Rooms, encounters, checks, capability provider, selected state. | Recall, path choice, repeat travel, anticipation, lost-but-curious versus lost-and-annoyed. | Gains disappear when distance is matched; fix travel cost rather than claiming deeper map identity. |
| P4 | Is Counterfire readable and voluntary? | Current presentation versus clearer receiver/route feedback; optional demonstration as a separate factor. | Gunner, timing, alternative route, damage, geometry except the specified cue. | First hypothesis, shot-release timing, willingness to use gunner, fairness. | Players understand it but dislike baiting; keep it optional or retire the situation. |
| P5 | Does existing movement deepen or erase the situation? | Baseline, relevant strong movement, and different useful optional Echo. | Same committed room and progression requirements. | Different legitimate approaches, bypass meaning, broken state, preference. | Every loadout uses the same action, or strong movement removes all valued decisions. |
| P6 | Do situations survive actual campaign integration? | The selected prototypes as ordinary committed Zone content, not dev-mode teleport destinations. | Tested local parameters and an explicit progression contract. | Request→build→play→reward→save→re-entry→continue. | Setup, AP timing, rewards, or re-entry destroy the local experience. |

## 11.3 Order, participants, and novelty

Use an exploratory sample spanning the owner, people comfortable with fast FPS movement, and people more interested in puzzles/exploration. A modest first round of roughly 6–12 people can expose failure categories; that is a practical proposal, **not a power calculation** or a promised representative sample.

Counterbalance A/B order across players. For insight puzzles, learning is partly irreversible: use separate first-exposure groups or structurally similar but non-identical transfer problems. Record repeated-player results as mastery data, not fresh discovery. Run a delayed return to a previously seen room to separate first-time novelty from durable route memory. Do not tell players which variant is intended to be “better.”

Use brief post-segment interviews rather than requiring continuous verbal commentary during precise action. Continuous commentary can itself change attention and performance. Collect spontaneous remarks, then ask neutral questions. Keep accessibility and input needs in the record without turning them into a ranking of player competence.

## 11.4 Questions and observable evidence

| Topic | Neutral question | Observable evidence | Common misinterpretation to avoid |
|---|---|---|---|
| Motivation | “What made you go that way?” | Voluntary branch entry before an explicit reward cue. | Exploration time alone means interest. |
| Route choice | “What did the other route offer?” | Can name a tradeoff and deliberately switch approaches. | Two graph branches mean two meaningful choices. |
| Learning | “What rule did you use?” | Applies it to a changed arrangement without identical instructions. | Repeating a memorized sequence proves understanding. |
| Combat | “What made you move from that position?” | Identifiable threat/angle change. | More dashes or more damage taken means better action. |
| Ability growth | “What did your Echo let you do differently?” | A distinct approach or satisfying shortcut. | Any bypass is a design failure. |
| Fairness | “What caused that failure?” | Explanation matches actual cause; next attempt changes accordingly. | A successful bot route proves human readability. |
| Navigation | “What are you trying to find right now?” | Distinguishes unanswered question from forgotten known location. | All wandering is bad, or all wandering is exploration. |
| Return | “What changed since you were last here?” | Uses repair, shortcut, cleared path, or newly meaningful view. | Faster return alone proves a more memorable map. |
| Recall | “Describe or sketch the places you passed.” | Relations and landmarks, not just color names. | Exact metric memory is required for enjoyment. |
| Retry | “What did you have to repeat before trying again?” | Time spent redoing solved setup versus testing a new idea. | No death penalty means low failure cost. |
| Replay | “Which part would you choose to do again?” | Voluntary replay without pressure to please the developer. | Agreeing that a concept is clever means wanting to play it. |

Do not combine these into a single “fun score.” Report patterns by participant and condition, quotations with context, and the contradictory cases. Technical defects should be tagged separately; they can explain an experience without making the dissatisfaction irrelevant.

---

# 12. Technical acceptance: what must be true before interpreting a playtest

A test does not need a finished game, but it needs an honest account of what is functioning. The following are proposed acceptance checks, not newly executed results.

**Physical correctness.** The actual capsule can enter, observe, operate, cross, fall, and recover. Projectiles hit the intended receiver; barriers obstruct the intended route; platforms carry the real player; target faces are actionable. Check alternate approaches and extreme supported movement, not only a prerecorded ideal path.

**Causal correctness.** Disconnecting the intended relationship must make its expected consequence fail. The existing Unweighted/Counterfire negative controls illustrate why this matters: a scene can appear successful while another route or signal accidentally supplies the result. [R26][R30]

**Lifecycle correctness.** Test initial generation, failed placement/refusal, re-entry, death, fresh save load, repeated state selection, state reversal, ability unequip, and permanent latch preservation. Test a selection message separately from a permanent latch event. The newly landed `ZoneStateSelected` exists for that distinction. [R22]

**Progression correctness.** Validate capability guarantees through the actual campaign/AP path. A local debug grant is not an AP item. Ensure checks cannot be duplicated, required routes do not depend on unavailable optional abilities, local keys remain recoverable, and another player's progression is not stranded by a reversible selection or an object lost in unloaded space.

**Recovery correctness.** Kill the Counterfire gunner, move the crate to awkward allowed positions, let effects expire mid-attempt, leave while machinery is in transit, save with the route in each configuration, and return after an ability changes. Every intended supported state needs a defined escape or restore policy.

**Communication correctness.** A developer message saying “state changed” is not the same as readable game feedback. Verify the world-facing response, labels, sound, camera visibility, and persistence of remembered information. Technical logs should diagnose defects, not become the player's required navigation interface.

Passing these checks licenses an enjoyment experiment. It does not pass that experiment in advance.

---

# 13. Epsilon and the authored alphabet: the smallest useful extension

## 13.1 Start with curated situations, not a universal puzzle compiler

The immediate proposal is an explicit catalog of a few tested situations with bounded roles and dependencies. Each entry should name what is already implemented, its compatible shells, required and optional capabilities, geometric anchors, intended consequence, reset/persistence class, recovery conditions, and the evidence needed for acceptance.

These are **proposed fields**, not a claim that a current schema accepts them. They should be introduced only where the first prototypes demonstrate a need. For example:

```text
situation: authored_counterfire_variant_01        # proposed identifier
roles: observation, threat, receiver, crossing, recovery
requires: the approved receiver/projectile interaction
optional_approaches: the tested baseline gallery route
consequence: temporary opening + separate permanent return release
lifetime: explicit per component, not one blanket reset flag
placement: compatible authored anchors and measured constraints
proof: real shot path, baseline completion, save/re-entry contract
```

An accepted relationship can then be expressed through the existing bounded engine vocabulary. Epsilon may select among tested situations, compatible shells, or approved relations; it does not gain arbitrary code execution or permission to invent unsupported mechanics.

## 13.2 Compare two approaches explicitly

**Authored set-piece selection** is sufficient when the fun is tightly coupled to geometry, timing, or a particular reveal. It is cheaper to understand and validate, and makes an excellent baseline. Its risks are repetition, obvious modular seams, and limited loadout adaptation.

**Validated relational composition** earns its complexity when varying compatible relationships produces genuinely different, enjoyable decisions without breaking communication, recovery, or progression. It needs better authoring contracts, more geometry evidence, and robust refusal paths. Adding descriptive labels without enforcing their physical meaning would only rename the problem.

The test should compare these approaches in the same pipeline, with provenance visible. Do not replace the owner's real Epsilon shell selection with an undisclosed deterministic picker. An experimental authored picker is a declared comparator, not a silent production fallback. [R08][R24]

## 13.3 Do not turn examples into a new mandatory template

Do not require every room to contain safe observation, two routes, a cross-room dependency, a combat encounter, a secret, and a permanent reward. That would recreate the ingredient-quota problem under better vocabulary.

Instead, author what a particular situation depends on. A quiet reveal may need only a stable sightline and destination. A short fight may need a pressure lane and recovery. A causal puzzle may need a controlled observation sequence and a persistent return. At Zone scale, compose contrasts and consequences without insisting every room reproduce the same structure.

---

# 14. Dependency-ordered code/content roadmap

| Order | Work | Classification | Why now / information gained | Stop or change direction when… |
|---|---|---|---|---|
| 1 | Freeze manifests, provenance, and experimental ingredient controls. | Bounded test/tooling work. | Makes later comparisons interpretable; prevents fallback top-up confounds. | Recorded variants are not actually comparable. |
| 2 | Run same-shell/roster encounter variants and Unweighted causal variants. | Existing capability, better authored content. | Separates composition from missing mechanics and core feel. | Clear relationships do not improve preference or understanding. |
| 3 | Test Counterfire presentation and Passing Platforms recovery/route choice. | Existing capability, tuning/communication. | Tests whether the strongest scenarios are understandable and worth repeating. | Correctly understood interactions remain unpleasant. |
| 4 | Prove D-8's physical route binding, setter operation, reversal, and persistence in a compact Zone. | Existing capability integration; bounded anchor support if needed. | Tests a real changed place without inventing a global machine simulation. | Logical state and physical route cannot be kept coherent at acceptable authoring cost. |
| 5 | Integrate one winning situation through normal request/build/reward/save/re-entry. | Existing capability needing campaign integration. | Exposes lifecycle and AP issues hidden by development scenarios. | Local fun disappears under ordinary acquisition or repeated travel. |
| 6 | Add narrowly defined encounter or situation authoring roles. | Small bounded schema/placement extension. | Encodes relationships demonstrated to matter. | Labels cannot be physically validated or produce no useful variation. |
| 7 | Extend one AI behavior only where a tested role requires it. | Bounded AI extension, potentially substantial if navigation/perception grows. | Answers a measured limitation instead of filling a catalog. | Existing geometry or tuning solves the same problem more simply. |
| 8 | Expand varied situations and multiworld/loadout coverage. | Content plus integration. | Tests diversity and campaign coherence beyond novelty. | Repetition, contradictions, or optional-loadout assumptions dominate. |
| 9 | Consider broader object transport or other new systems under explicit owner approval. | Substantial subsystem/authority work. | Only justified by proven content needs and M7 scope. | The desired situation can be delivered with existing bounded state and local mechanics. |

## 14.1 What not to build yet

Do not build a universal physics puzzle generator, arbitrary geometry generator, broad fluid simulation, all-purpose perception/navmesh AI, global signal language, or a new economy as the first response. Do not multiply enemy skins and call the result new behavior. Do not add mandatory map-wide timers, collectible taxes, or a rigid per-room ingredient checklist. Do not redefine Static or Integrity Faults. Do not treat the historical no-DOT design language and current runtime status behavior as permission to make an unreviewed policy change. [R13][R23][R24]

Do not abandon technical validation. The historical playtest demonstrates why local tests alone can miss assembly failures; that is an argument for better integration evidence, not fewer tests. [R15]

## 14.2 Choosing an emphasis within the hybrid

**Curiosity-led exploration:** an ordinary session would center on noticing a destination, deciding which question to pursue, and returning with knowledge or access. This requires distinctive landmarks, stable remembered information, and enough freedom to defer. It risks wandering without meaningful actions if the content relationships stay shallow.

**Systemic dungeon manipulation:** a session would center on reading a local machine, testing a rule, changing a route, and using the consequence elsewhere. This has the closest fit to the currently promising EX50/D-8 work, but needs careful recovery and campaign integration. It risks becoming a sequence of slow switch chores if every operation is obvious or reset-heavy.

**Expressive traversal/combat:** a session would center on choosing angles, chaining movement, exploiting enemy/environment relationships, and voluntarily repeating for mastery. It uses the owner's interest in powerful movement, but requires strong feel and geometry that makes alternatives matter. It risks turning discovery spaces into interruptive arenas or rendering simple obstacle puzzles irrelevant.

**Recommendation:** use the second as the organizing logic of places, the first as motivation, and the third as an important set of ways to act—not as three mandatory ingredients in each room. This is a proposed emphasis to test, not a replacement of the owner's creative authority. The comparative sample supports the compatibility questions; only Archipepsi playtests can establish whether this balance is the right taste for this game.

---

# 15. Final recommendations and open uncertainties

The best next deliverable is **one small, ordinary, saved-and-revisited Zone whose connected situations are enjoyable**, not another catalog of possible mechanics. Use the existing strong scenarios as experiments, not as proof that the campaign problem is solved.

The three highest-information tests are: **same shell/roster, different pressure relationships; same puzzle ingredients, different causality; same small room set, different route and revisit structure.** Keep content, loadouts, progression, and provenance explicit enough to explain the result.

The largest uncertainties are the real feel of the current player/combat loop; first-time comprehension of Counterfire and Unweighted; the physical enforcement of composed cross-room state; campaign acquisition/save/re-entry behavior for scenario-derived content; the acceptable role of powerful bypasses; and the owner's preferred ratio of discovery, manipulation, and execution.

The research is strongest where it has concrete source behavior, developer revisions, or independent first-hand accounts. It is weaker for several obscure games' named rooms and for broad claims about audience preference. Those gaps are not filled with confidence. The artifact contains all requested titles, but it does not claim all of their room-level evidence questions have been fully resolved.

**The decision rule is not “does this feature exist?” It is “does this place give the player a legible, worthwhile relationship to act on—and does the game preserve the consequence?”**


---

# 16. Source register and inspection limits

The supplied Archipepsi research brief defines the requested scope; it is not independent evidence for its preparatory hypotheses. Repository sources were accessed through the connected GitHub app. Web sources were searched for the exact title plus combinations of review, level, puzzle, developer commentary, navigation, criticism, and named examples. Selection was purposive: concrete mechanisms and counterexamples were favored. This is not a systematic review with a reproducible complete search-result census.

**Retrieval precision:** “text inspected” means the relevant written passages were available and read, not that the assistant played the game or watched footage. “Retrieved excerpts” means the claim was restricted to the text surfaced by search; it does not claim the entire article/thread was opened. Date/build uncertainty is retained. Same-page references and multiple commenters in one thread do not increase the number of independent sources. Source links can change or require the reader’s repository access.

## 16.1 Repository inspection register

All linked source files use the pinned commit. Line ranges below describe the source ranges requested, not the wrapper line numbers in chat citations. Partial/truncated retrieval is stated explicitly.

| Reference | Source | Inspection scope and qualification |
|---|---|---|
| [R02] | `Repository branch listing` | Connected GitHub metadata read at research time; branch heads are mutable. The inspected content is frozen to the SHA above. |
| [R03] | `Open pull requests` | Connected GitHub metadata; PR #12 active development, PR #4 older comparison. Descriptions are not proof of current implementation. |
| [R04] | `docs/AGENT_FRONTIER.md` | Opening frontier entries inspected; response truncated. Some entries precede the head merge and are explicitly superseded by code in this report. |
| [R05] | `Comparison with supplied baseline` | Connected compare API inspected; large response was truncated. Used for ancestry/context, not claimed as exhaustive line-by-line delta review. |
| [R06] | `bridge/archipepsi_bridge/composition.py` | Complete returned module: composition_errors, encounter signature, landmark and connector guards. |
| [R07] | `bridge/archipepsi_bridge/content_value.py` | Retrieved module text: provisional weights, room_value, budget_band, budget_errors. |
| [R08] | `bridge/archipepsi_bridge/epsilon/requests.py` | Requested source lines 1–330; output partly truncated. ZoneGenerationRequest, live shell catalog, constraints and capability declarations inspected. |
| [R09] | `bridge/archipepsi_bridge/epsilon/fallback.py` | Source lines 1–480 retrieved in two ranges: fallback_zone_attempt, activity families and budget top-up composition. Not the entire file. |
| [R10] | `bridge/archipepsi_bridge/epsilon/fallback.py` | Second retrieved range, source lines 270–480; same file as R09, not an independent source. |
| [R11] | `bridge/archipepsi_bridge/schemas/zone.py` | Source lines 1–240: procedural sockets, affordances, ActivityKind and ActivityPrimitive. Not the entire Zone schema. |
| [R12] | `bridge/archipepsi_bridge/cross_room.py` | Complete returned helper: opt-in compose_zone_state, candidate selection, reachability and emission. Source reading, not execution. |
| [R13] | `godot/scripts/enemies/enemy.gd` | Source lines 1–260: three placeable behavior families, physical envelopes, telegraph state and presentation. |
| [R14] | `godot/scripts/enemies/enemy.gd` | Source lines 260–490: movement, attack initiation, windup resolution, line of sight, projectile aim and firing. Same file as R13. |
| [R15] | `docs/PLAYTEST_SESSION_SYNTHESIS.md` | Source lines 1–230. Historical September 13, 2026 playtest on cd620f0; report is read testimony, not a session conducted for this investigation. |
| [R16] | `bridge/archipepsi_bridge/topology.py` | Source lines 1–220: graph/reachability contract, branch parameters, refusal vocabulary and socket selection. Full graph implementation not exhaustively inspected. |
| [R17] | `bridge/archipepsi_bridge/layout.py` | Source lines 1–165: physical-evidence boundary, acceptance/refusal model and manifest contract. Not a newly executed layout validation. |
| [R18] | `godot/scripts/content/content_instantiator.gd` | Source lines 1–230: build_chamber, activity/environment ordering, authored/procedural path and placement contracts. |
| [R19] | `godot/scripts/generation/activities.gd` | Source lines 1–260: ActivityRuntime construction, occupancy/surface-aware placement and target mounting. Not the whole placement module. |
| [R20] | `godot/scripts/gameplay/zone_controller.gd` | Source lines 1–270: state fields, carried progress, movement operator modes, room tracking and layout acceptance state. |
| [R21] | `godot/scripts/gameplay/zone_controller.gd` | Source lines 300–570 requested; response partly truncated. Setup path, state restore/construction, railway restore, keys/locks/stations and player setup inspected. |
| [R22] | `Pinned head commit and nearby history` | Connected commit-history API read: 2026-09-22 02:46:01 UTC head; D-8 consumption and ZoneStateSelected protocol. Nearby 16c198b80cc08ce0c9b0d418900660fced7be723 preserves unfinished M7. Reported tests were not rerun. |
| [R23] | `docs/ledgers/HUGE_BATCH_LEDGER.md` | Retrieved opening/task-table and selected later ranges, some truncated. Owner-approved scope and author-reported scenario tests; not independent play evidence. |
| [R24] | `docs/design-proposals/06_THE_AMALGAM.md` | Source lines 1–190 requested, partly truncated. Proposal framing and owner-amended determinism/selection rules; not proof of the whole design being implemented. |
| [R25] | `docs/design-proposals/07_ENGINE_RECONCILIATION.md` | Source lines 1–125. Explicitly dated September 4, 2026, df2bb58; historical findings, not current engine inventory. |
| [R26] | `godot/scripts/content/unweighted_switch.gd` | Source lines 1–170. Executable development scenario description, constants, setup, shell and plate. No personal runtime test. |
| [R27] | `godot/tests/fixtures/played_zone.json` | Source lines 1–180. Checked-in regression data, including c001 and c002. File SHA 967ec6f50c174794629ab7135fc17d6b162ff867. Not fresh generation or a complete physical manifest. |
| [R28] | `docs/ledgers/HUGE_BATCH_LEDGER.md` | Source lines 230–330: return test, railway and grapple findings. Same ledger as R23, not an independent source. |
| [R29] | `bridge/archipepsi_bridge/campaign.py` | Source lines 1–200: persistence boundary, imported generation/logic components, relevance helpers and beginning of _with_graph. Not the complete allocation implementation. |
| [R30] | `godot/scripts/content/counterfire_arcade.gd` | Source lines 1–145. Development scenario, ordinary projectile interaction, baseline alternative route and geometry constants. No personal runtime test. |
| [R31] | `godot/scripts/generation/zone_state_build.gd` | Source lines 1–190. Closed barrier/lamp builders, variable-ID binding, placements and setter construction. Source presence is not physical acceptance. |
| [R32] | `docs/ledgers/HUGE_BATCH_LEDGER.md` | Source lines 95–190 and related task rows: Unweighted status/room checks and moving-platform passenger findings. Author-reported technical evidence. |

## 16.2 Original comparison games: external evidence

| Reference | Source | Date, edition and evidence qualification |
|---|---|---|
| [G01] | Valve, Portal developer commentary (transcript) | Original-game developer audio transcribed on a community wiki; relevant transcript text read. Developer intent and reported development outcomes, not independent reception. |
| [G02] | Valve, Portal 2 developer commentary (transcript) | Relevant transcript text read, including Repulsion Intro and Propulsion Flings. Community-hosted transcription; embedded gameplay was not watched. |
| [G03] | PC Gamer, Portal 2 review | 2011 first-hand review text inspected. Praise and criticism in one review are one account, not independent samples. |
| [G04] | Dominic Tarason, The Talos Principle 2 review | PC Gamer, November 2, 2023; launch-period PC review text inspected. |
| [G05] | Marcus Stewart, The Talos Principle II — Profoundly Puzzling | Game Informer, November 17, 2023; retrieved search excerpts from a first-hand review. Not claimed as a full-text room walkthrough. |
| [G06] | Phil Savage, Outer Wilds review | PC Gamer, May 29, 2019; PC review text inspected. The late execution complaint does not name its puzzle, and this report does not invent that name. |
| [G08] | Edwin Evans-Thirlwell, The Witness review | PC Gamer, January 25, 2016; review text inspected. The review explicitly discusses non-final review-build material. |
| [G09] | David Valjalo, Antichamber review | PC Gamer, January 31, 2013; review text inspected. Exact labels of all described rooms were not established. |
| [G10] | Rachel Watts, Manifold Garden review | PC Gamer, October 28, 2019; review text inspected. Independent negative reception remains a gap. |
| [G11] | Bryant Francis, Designing the mind-bending perspective puzzles of Superliminal | Game Developer, January 16, 2020; original Albert Shih interview text inspected. Developer explanation, not a controlled player study. |
| [G12] | Player account: Whitespace chess attempts | Original Reddit post, November 20, 2021; retrieved excerpt. Build unspecified; anecdotal frustration, not a measured prevalence. |
| [G13] | Player account: Superliminal, an enjoyable puzzle solver | Original patientgamers post, late December 2022; retrieved excerpt. Independent positive account; not a complete room audit. |
| [G14] | Robin Valentine, Viewfinder review | PC Gamer, July 17, 2023; PC launch review text inspected. Concrete examples are the reviewer’s observations, not assistant play. |
| [G15] | Ben Love, Lunacid review | RPGFan, February 9, 2024; post-1.0 PC review text inspected. |
| [G16] | Lunacid — In the Shadow of Alucard | Startmenu, launch-period 2023 review excerpts retrieved; exact date/build not established in the retrieved portion. |
| [G17] | Matt Thrower, Legend of Grimrock 2 review | PC Gamer, November 3, 2014; full relevant review text inspected. First-hand account of island exploration, clues and combat. |
| [G18] | Kinglink, Legend of Grimrock 2 review | July 5, 2018; original retrospective text inspected. Independent of G17; exact game build unspecified. |
| [G19] | First-hand retrospective including Arx Fatalis | Original truegaming post, March 9, 2023; retrieved excerpt. Cooking testimony is not used as an authoritative recipe specification. |
| [G20] | Zomb’s Lair, Definitive Edition Patcher: Arx Fatalis | April 12, 2021; patch-author retrospective excerpts. Modern patched/modded context, not unmodified launch behavior. |
| [G21] | Matt Wardell, Verho – Curse of Faces review | RPGFan, July 28, 2026; PS5 review text inspected. Platform/date kept distinct from PC release. |
| [G21S] | Verho – Curse of Faces, developer/publisher Steam listing | Retrieved listing reports November 10, 2025 PC release. Used for release status only, not player satisfaction. |
| [G23] | God is a Geek, Cryptmaster review | October 10, 2024; original review excerpts retrieved. Full platform/control comparison was not established. |
| [G24] | Mark Steighner, Cryptmaster Review — Typing Be Damned | COGconnected, May 18, 2024; PC review text inspected, including chests, altars, visual readability and typing/controller concerns. |
| [G25] | Michael Duhacek, Review: Vaporum | Indie Game Reviewer, October 10, 2017; original PC-game review text inspected, not Vaporum: Lockdown. |
| [G26] | RPGFan, King’s Field: The Ancient City review | April 2002 PS2 review text inspected. Original edition’s sensory geography and control criticism, not modern emulation performance. |
| [G27] | Monomyth, developer/publisher Steam listing | Current listing checked: Early Access, initially October 3, 2024. Intended features/status, not reception or a named-room proof. |
| [G28] | Original DRPG discussion of Monomyth | October 30, 2024; original early-access player discussion excerpts. Named-room and independent-negative evidence incomplete. |
| [G29] | Jesse Lab, Metroid Prime Remastered is a masterpiece except for the Chozo Artifacts | The Escapist, February 18, 2023; first-hand critique text inspected. Its acknowledgement of opposing preferences is not a second independent sample. |
| [G30] | Reese Anderson, Metroid Prime Remastered Chozo Artifact Guide | Forever Classic Games, February 28, 2023; written location/solution guide inspected. Embedded video not watched; used for spatial mechanics, not enjoyment. |
| [G31] | Metroid Recon, Dark Temple and Sky Temple Key locations | Original player-authored guide, page updated May 1, 2014; relevant written sections inspected. Distinguishes regional temple keys from the nine remaining Sky Temple keys. |
| [G32] | Original player debate: Sky Temple keys | March 27, 2024; retrieved discussion excerpts. Opposing preferences within one thread, not population proportions. |
| [G33] | God is a Geek, Supraland review | November 3, 2020; original review excerpts retrieved, including praise for puzzles and criticism of combat interruptions. Exact reviewed platform not established here. |
| [G34] | Player-authored Supraland guide | Steam Community guide created June 9, 2018; retrieved excerpts name Red Crystal Tower and Volcano. Later revision/build coverage not established. |
| [G35] | Supraland Six Inches Under review | January 14, 2022 PC review, now hosted by Prima Games; retrieved excerpts describe Cagetown. Original publication migration distinguished from a new review. |
| [G36] | Supraland Six Inches Under — Quick Time Review | We The Nerdy, May 23, 2023; Xbox Series S review excerpts. Console camera/navigation observations not silently applied to PC launch. |
| [G37] | Frogmonster player boss discussion | Original 2024 Steam discussion excerpts, including Balsam. Individual preferences; exact build/arena reconstruction incomplete. |
| [G38] | Frogmonster navigation/difficulty discussion | Original July 2024 Steam discussion excerpts. Player frustration and developer response are distinguished; not a broad reception survey. |
| [G39] | ZTGD, Journey to the Savage Planet review (XB1) | February 4, 2020; original Xbox One review excerpts. No complete named-room reconstruction retrieved. |
| [G40] | Danvers Library, Chris’ game review: Journey to the Savage Planet on Switch | February 3, 2021; original first-hand Switch review excerpts. Not sequel or later-edition evidence. |
| [G41] | John Walker, Vomitoreum | Buried Treasure, October 8, 2021; first-hand PC/Linux review text inspected. Independent negative account remains a gap. |
| [G42] | Dayten Rose, Supraworld early-access review | Thinky Games, September 8, 2025; first-act early-access review text inspected. Not a verdict on unexamined later additions. |
| [G43] | Supraworld, developer/publisher Steam listing | Current Early Access status checked; initial EA release August 15, 2025. Listing not used as reception evidence. |
| [G44] | Ian Birnbaum, DUSK review | PC Gamer, December 12, 2018; original base-game review text inspected, not DUSK HD. |
| [G45] | Original player discussion: The Escher Labs | March 1, 2025; retrieved original discussion excerpts. Concrete testimony, not assistant-observed gameplay or timestamps. |
| [G46] | Flobknocker, DUSK review | HonestGamers, August 21, 2019; independent positive review excerpts. Not evidence of consensus. |
| [G47] | ULTRAKILL player challenge guide | Steam Community guide dated June 28, 2021; relevant Layer 4 challenge excerpts inspected. Not proof of all current balance/content. |
| [G48] | ULTRAKILL, developer/publisher Steam listing | Current Early Access status checked separately from the 2021 guide; no general reception inference from store ratings. |
| [G49] | Darragh Murphy, Turbo Overkill review | Laptop Mag, April 30, 2022; first-hand early-access Episode 1 review excerpts. Rooftops and vehicle issues are historical observations, not presumed current defects. |
| [G50] | Zoey Handley, Review: Turbo Overkill | Destructoid, August 11, 2023; original 1.0 PC review text retrieved in search results, including late Episode 3 fatigue. |
| [G51] | Matt Gander, Turbo Overkill review | Games Asylum, February 11, 2025; later console-era first-hand review excerpts. Exact platform/build not established here. |
| [G52] | Tyler Wilde, AMID EVIL review | PC Gamer, June 26, 2019; original game review text inspected. Does not cover later VR or expansion content. |
| [G53] | Ted Litchfield, CULTIC review | PC Gamer, December 11, 2025; review text inspected, covering both chapters. Not a Chapter 1-only launch assessment. |
| [G54] | Andrew Yoder, Quake’s Moats and Bridges | November 23, 2017; original first-hand level-design analysis text inspected. Analyst interpretation, not original id Software developer intent. |
| [G55] | Mitch Vogel, Prodeus review (Switch) | Nintendo Life, November 3, 2022; original review text retrieved in search results. Black Magic Society is custom content; platform criticism is version-specific. |
| [G56] | Original Prodeus checkpoint discussion | November 2021 early-access Steam discussion excerpts. Historical policy/reaction, not verified present checkpoint behavior. |
| [G57] | GamingOnLinux, Selaco early-access impressions | GamingOnLinux, originally May 31, 2024; page bears a later June 2026 update. Retrieved first-hand excerpts; not a claim that every sentence is unchanged since launch. |
| [G58] | Original player discussion: struggling with Selaco | September 2024; original discussion excerpts, including parking-garage navigation. Anecdotal and build-limited. |
| [G59] | Selaco, developer/publisher Steam listing | Current Early Access status checked. Not evidence that a particular later chapter or roadmap milestone has shipped. |

## 16.3 Targeted transfer studies: external evidence

| Reference | Source | Date, edition and evidence qualification |
|---|---|---|
| [X01] | PC Gamer, Prey review | 2017 PC review text inspected, including the office foam-dart/terminal interaction and alternative keycard access. First-hand reviewer evidence. |
| [X02] | Ricky Llamas, Prey: Mooncrash systems design account | Undated original designer portfolio retrospective; text inspected. Propulsion-suit revisions are author-reported. Embedded videos were not watched. |
| [X03] | Bethesda, Mooncrash Rogue Moon update and roguelike influences | September 4, 2018; official developer-interview excerpts retrieved. Developer intentions are distinct from player satisfaction. |
| [X04] | Inverse, Dishonored 2’s Clockwork Mansion | November 22, 2016; original first-hand article excerpts, used for the moving-mansion experience, not developer intent. |
| [X05] | Original Dishonored 2 level discussion | April 13–14, 2017; original thread text retrieved, including Clockwork Mansion and Stilton preferences. One discussion is not independent consensus. |
| [X06] | Christopher Dionne, Designing Unforgettable Titanfall Single Player Levels with Action Blocks | GDC 2018 listing and abstract inspected. The talk/transcript was NOT inspected; no detailed undocumented method is attributed to it. |
| [X07] | Frostilyte, Neon White review — Do Not Sleep on This | August 17, 2022; original first-hand review excerpts, including card-discard traversal and replay. |
| [X08] | Epilogue Gaming, Neon White: Player Fatigue and Gaming Burnout | August 26, 2022; original first-hand text retrieved in search results. Fatigue is personal testimony, not a measured audience effect. |
| [X09] | PC Gamer, Bomb Rush Cyberfunk review | 2023 first-hand review text inspected, including movement and navigational criticism. Not a room-by-room walkthrough. |
| [X10] | Original Bomb Rush Cyberfunk route/combo discussion | August 24, 2023; original Steam discussion excerpts concerning Versum Hill and route/combo use. Not assistant-observed footage. |
| [X11] | Nintendo Iwata Asks: I’ve Got to Fix the Water Temple! | 2011 official development interview text inspected. Ocarina of Time 3D revisions, not a claim that the N64 interface already had them. |
| [X12] | Derek Yu, EXPLORER.GMK: An Excerpt From the Spelunky Book | Game Developer, March 23, 2016; original designer book-excerpt text retrieved. Development reasoning, not independent player reception. |
| [X13] | Motion Twin, Dead Cells development description | Official historical itch.io development page; text inspected. Used for stated route-design intention, not present release status. |
| [X14] | Andy Kelly, Resident Evil HD Remaster review | PC Gamer, January 19, 2015; review text inspected. The 2015 remaster of the 2002 remake, not an unmodified description of the 1996 game. |

## 16.4 What this investigation did not establish

No new Archipepsi build, full-suite run, production seed generation, user study, accessibility validation or multiworld session was performed. Only the beginning of one checked-in Zone fixture was inspected, not a representative generated-layout corpus. Source tracing reached representative contracts and implementations, not every caller or every acceptance test. Some extended comparisons contrast segments or interaction classes rather than two fully named, independently observed rooms. Several obscure-game entries lack an independently sourced negative account. Video-based observation and a larger, explicitly sampled reception study remain gaps in the requested evidence, not work claimed as completed.

The implementation roadmap and prototypes are nevertheless usable: their assumptions, relevant code surfaces, test controls and rejection criteria are explicit. The strongest next decisions concern experiments with existing capabilities; weaker external evidence is not used to authorize a new creative direction or a large subsystem.

<!-- Reference definitions: source labels in the report resolve to these links. -->

[R02]: https://api.github.com/repos/cadykaya/archipepsi/branches?per_page=100 "Repository branch listing"
[R03]: https://api.github.com/repos/cadykaya/archipepsi/pulls?state=open&per_page=30 "Open pull requests"
[R04]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/AGENT_FRONTIER.md "docs/AGENT_FRONTIER.md"
[R05]: https://github.com/cadykaya/archipepsi/compare/98c54776a46b55f96ecf517470b2b2733de1a306...68eb947a65f6dd72e150831322fc76c655e963fe "Comparison with supplied baseline"
[R06]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/composition.py "bridge/archipepsi_bridge/composition.py"
[R07]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/content_value.py "bridge/archipepsi_bridge/content_value.py"
[R08]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/epsilon/requests.py "bridge/archipepsi_bridge/epsilon/requests.py"
[R09]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/epsilon/fallback.py "bridge/archipepsi_bridge/epsilon/fallback.py"
[R10]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/epsilon/fallback.py "bridge/archipepsi_bridge/epsilon/fallback.py"
[R11]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/schemas/zone.py "bridge/archipepsi_bridge/schemas/zone.py"
[R12]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/cross_room.py "bridge/archipepsi_bridge/cross_room.py"
[R13]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/enemies/enemy.gd "godot/scripts/enemies/enemy.gd"
[R14]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/enemies/enemy.gd "godot/scripts/enemies/enemy.gd"
[R15]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/PLAYTEST_SESSION_SYNTHESIS.md "docs/PLAYTEST_SESSION_SYNTHESIS.md"
[R16]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/topology.py "bridge/archipepsi_bridge/topology.py"
[R17]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/layout.py "bridge/archipepsi_bridge/layout.py"
[R18]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/content/content_instantiator.gd "godot/scripts/content/content_instantiator.gd"
[R19]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/generation/activities.gd "godot/scripts/generation/activities.gd"
[R20]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/gameplay/zone_controller.gd "godot/scripts/gameplay/zone_controller.gd"
[R21]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/gameplay/zone_controller.gd "godot/scripts/gameplay/zone_controller.gd"
[R22]: https://github.com/cadykaya/archipepsi/commit/68eb947a65f6dd72e150831322fc76c655e963fe "Pinned head commit and nearby history"
[R23]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/ledgers/HUGE_BATCH_LEDGER.md "docs/ledgers/HUGE_BATCH_LEDGER.md"
[R24]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/design-proposals/06_THE_AMALGAM.md "docs/design-proposals/06_THE_AMALGAM.md"
[R25]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/design-proposals/07_ENGINE_RECONCILIATION.md "docs/design-proposals/07_ENGINE_RECONCILIATION.md"
[R26]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/content/unweighted_switch.gd "godot/scripts/content/unweighted_switch.gd"
[R27]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/tests/fixtures/played_zone.json "godot/tests/fixtures/played_zone.json"
[R28]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/ledgers/HUGE_BATCH_LEDGER.md "docs/ledgers/HUGE_BATCH_LEDGER.md"
[R29]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/bridge/archipepsi_bridge/campaign.py "bridge/archipepsi_bridge/campaign.py"
[R30]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/content/counterfire_arcade.gd "godot/scripts/content/counterfire_arcade.gd"
[R31]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/godot/scripts/generation/zone_state_build.gd "godot/scripts/generation/zone_state_build.gd"
[R32]: https://github.com/cadykaya/archipepsi/blob/68eb947a65f6dd72e150831322fc76c655e963fe/docs/ledgers/HUGE_BATCH_LEDGER.md "docs/ledgers/HUGE_BATCH_LEDGER.md"
[G01]: https://theportalwiki.com/wiki/Portal_developer_commentary "Valve, Portal developer commentary (transcript)"
[G02]: https://theportalwiki.com/wiki/Portal_2_developer_commentary "Valve, Portal 2 developer commentary (transcript)"
[G03]: https://www.pcgamer.com/portal-2-review/ "PC Gamer, Portal 2 review"
[G04]: https://www.pcgamer.com/the-talos-principle-2-review/ "Dominic Tarason, The Talos Principle 2 review"
[G05]: https://gameinformer.com/review/the-talos-principle-ii/profoundly-puzzling "Marcus Stewart, The Talos Principle II — Profoundly Puzzling"
[G06]: https://www.pcgamer.com/outer-wilds-review/ "Phil Savage, Outer Wilds review"
[G08]: https://www.pcgamer.com/the-witness-review/ "Edwin Evans-Thirlwell, The Witness review"
[G09]: https://www.pcgamer.com/antichamber-review/ "David Valjalo, Antichamber review"
[G10]: https://www.pcgamer.com/manifold-garden-review/ "Rachel Watts, Manifold Garden review"
[G11]: https://www.gamedeveloper.com/design/designing-the-mind-bending-perspective-puzzles-of-i-superliminal-i-/ "Bryant Francis, Designing the mind-bending perspective puzzles of Superliminal"
[G12]: https://www.reddit.com/r/Superliminal/comments/qy1fdf/after_two_hours_of_attempts_whitespace_chess/ "Player account: Whitespace chess attempts"
[G13]: https://www.reddit.com/r/patientgamers/comments/zzywcx/superliminal_a_really_enjoyable_puzzle_solver_and/ "Player account: Superliminal, an enjoyable puzzle solver"
[G14]: https://www.pcgamer.com/viewfinder-review/ "Robin Valentine, Viewfinder review"
[G15]: https://www.rpgfan.com/review/lunacid/ "Ben Love, Lunacid review"
[G16]: https://www.startmenu.co.uk/home/review-lunacid-in-the-shadow-of-alucard "Lunacid — In the Shadow of Alucard"
[G17]: https://www.pcgamer.com/legend-of-grimrock-2-review/ "Matt Thrower, Legend of Grimrock 2 review"
[G18]: https://kinglink-reviews.com/2018/07/05/legend-of-grimrock-2-review/ "Kinglink, Legend of Grimrock 2 review"
[G19]: https://www.reddit.com/r/truegaming/comments/11ms6zb/deus_ex_system_shock_2_and_arx_fatalis_aka_the/ "First-hand retrospective including Arx Fatalis"
[G20]: https://www.zombs-lair.com/post/definitive-edition-patcher-arx-fatalis "Zomb’s Lair, Definitive Edition Patcher: Arx Fatalis"
[G21]: https://www.rpgfan.com/review/verho-curse-of-faces/ "Matt Wardell, Verho – Curse of Faces review"
[G21S]: https://store.steampowered.com/app/3017330/Verho__Curse_of_Faces/ "Verho – Curse of Faces, developer/publisher Steam listing"
[G23]: https://godisageek.com/reviews/cryptmaster-review/ "God is a Geek, Cryptmaster review"
[G24]: https://cogconnected.com/review/cryptmaster-review/ "Mark Steighner, Cryptmaster Review — Typing Be Damned"
[G25]: https://indiegamereviewer.com/review-vaporum/ "Michael Duhacek, Review: Vaporum"
[G26]: https://www.rpgfan.com/review/kings-field-the-ancient-city-2/ "RPGFan, King’s Field: The Ancient City review"
[G27]: https://store.steampowered.com/app/908360/Monomyth/ "Monomyth, developer/publisher Steam listing"
[G28]: https://www.reddit.com/r/DRPG/comments/1gf4vp5/monomyth/ "Original DRPG discussion of Monomyth"
[G29]: https://www.escapistmagazine.com/metroid-prime-remastered-is-a-masterpiece-except-for-the-chozo-artifacts/ "Jesse Lab, Metroid Prime Remastered is a masterpiece except for the Chozo Artifacts"
[G30]: https://foreverclassicgames.com/features/2023/2/metroid-prime-remastered-chozo-artifact-guide-88dge "Reese Anderson, Metroid Prime Remastered Chozo Artifact Guide"
[G31]: https://metroid.retropixel.net/games/mprime2/items6.php "Metroid Recon, Dark Temple and Sky Temple Key locations"
[G32]: https://www.reddit.com/r/Metroid/comments/1bov0s8/what_is_peoples_issue_with_the_sky_temple_keys/ "Original player debate: Sky Temple keys"
[G33]: https://godisageek.com/reviews/supraland-review/ "God is a Geek, Supraland review"
[G34]: https://steamcommunity.com/sharedfiles/filedetails/?id=1407074713 "Player-authored Supraland guide"
[G35]: https://primagames.com/featured/supraland-six-inches-under-review "Supraland Six Inches Under review"
[G36]: https://wethenerdy.com/supraland-six-inches-under-quick-time-review/ "Supraland Six Inches Under — Quick Time Review"
[G37]: https://steamcommunity.com/app/1853760/discussions/0/6324828960574204002/ "Frogmonster player boss discussion"
[G38]: https://steamcommunity.com/app/1853760/discussions/0/4416424435095152391/ "Frogmonster navigation/difficulty discussion"
[G39]: https://ztgd.com/reviews/journey-to-the-savage-planet-xb1/ "ZTGD, Journey to the Savage Planet review (XB1)"
[G40]: https://danverslibrary.org/chris-game-review-journey-to-the-savage-planet-on-switch/ "Danvers Library, Chris’ game review: Journey to the Savage Planet on Switch"
[G41]: https://buried-treasure.org/2021/10/vomitoreum/ "John Walker, Vomitoreum"
[G42]: https://thinkygames.com/reviews/supraworld-early-access-review-a-puzzle-adventure-that-does-too-little-with-too-much/ "Dayten Rose, Supraworld early-access review"
[G43]: https://store.steampowered.com/app/1869290/Supraworld/ "Supraworld, developer/publisher Steam listing"
[G44]: https://www.pcgamer.com/dusk-review/ "Ian Birnbaum, DUSK review"
[G45]: https://www.reddit.com/r/Dusk_The_Game/comments/1j0xlfq/the_escher_labs/ "Original player discussion: The Escher Labs"
[G46]: https://www.honestgamers.com/14514/pc/dusk/review.html "Flobknocker, DUSK review"
[G47]: https://steamcommunity.com/sharedfiles/filedetails/?id=2530534235 "ULTRAKILL player challenge guide"
[G48]: https://store.steampowered.com/app/1229490/ULTRAKILL/ "ULTRAKILL, developer/publisher Steam listing"
[G49]: https://www.laptopmag.com/reviews/turbo-overkill-review "Darragh Murphy, Turbo Overkill review"
[G50]: https://www.destructoid.com/reviews/review-turbo-overkill/ "Zoey Handley, Review: Turbo Overkill"
[G51]: https://www.gamesasylum.com/2025/02/11/turbo-overkill-review/ "Matt Gander, Turbo Overkill review"
[G52]: https://www.pcgamer.com/amid-evil-review/ "Tyler Wilde, AMID EVIL review"
[G53]: https://www.pcgamer.com/games/fps/cultic-review/ "Ted Litchfield, CULTIC review"
[G54]: https://andrewyoderdesign.blog/2017/11/23/quakes-moats-and-bridges/ "Andrew Yoder, Quake’s Moats and Bridges"
[G55]: https://www.nintendolife.com/reviews/nintendo-switch/prodeus "Mitch Vogel, Prodeus review (Switch)"
[G56]: https://steamcommunity.com/app/964800/discussions/0/4962398753449278429/ "Original Prodeus checkpoint discussion"
[G57]: https://www.gamingonlinux.com/2024/05/selaco-is-now-in-early-access-one-of-the-best-shooters-ive-played-in-forever/ "GamingOnLinux, Selaco early-access impressions"
[G58]: https://www.reddit.com/r/boomershooters/comments/1fca9i3/anyone_else_struggle_with_selaco/ "Original player discussion: struggling with Selaco"
[G59]: https://store.steampowered.com/app/1592280/Selaco/ "Selaco, developer/publisher Steam listing"
[X01]: https://www.pcgamer.com/prey-review/ "PC Gamer, Prey review"
[X02]: https://www.rickyllamas.com/prey-systems-927369.html "Ricky Llamas, Prey: Mooncrash systems design account"
[X03]: https://bethesda.net/en/article/6JDDcpLoooMaoMgwYaUuoW/prey-mooncrash%27s-new-rogue-moon-update-celebrates-indie-roguelikes "Bethesda, Mooncrash Rogue Moon update and roguelike influences"
[X04]: https://www.inverse.com/article/24208-dishonored-2-clockwork-mansion-kirin-jindosh "Inverse, Dishonored 2’s Clockwork Mansion"
[X05]: https://steamcommunity.com/app/403640/discussions/0/133262487495599300/?l=brazilian "Original Dishonored 2 level discussion"
[X06]: https://www.gdcvault.com/play/1025105/Designing-Unforgettable-Titanfall-Single-Player "Christopher Dionne, Designing Unforgettable Titanfall Single Player Levels with Action Blocks"
[X07]: https://frostilyte.ca/2022/08/17/neon-white-review-do-not-sleep-on-this/ "Frostilyte, Neon White review — Do Not Sleep on This"
[X08]: https://epiloguegaming.com/neon-white-player-fatigue-and-gaming-burnout/ "Epilogue Gaming, Neon White: Player Fatigue and Gaming Burnout"
[X09]: https://www.pcgamer.com/bomb-rush-cyberfunk-review/ "PC Gamer, Bomb Rush Cyberfunk review"
[X10]: https://steamcommunity.com/app/1353230/discussions/0/3815165632069427539/ "Original Bomb Rush Cyberfunk route/combo discussion"
[X11]: https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-The-Legend-of-Zelda-Ocarina-of-Time-3D/Vol-4-Development-Staff/3-I-ve-Got-to-Fix-the-Water-Temple-/3-I-ve-Got-to-Fix-the-Water-Temple--235888.html "Nintendo Iwata Asks: I’ve Got to Fix the Water Temple!"
[X12]: https://www.gamedeveloper.com/design/explorer-gmk-an-excerpt-from-the-spelunky-book "Derek Yu, EXPLORER.GMK: An Excerpt From the Spelunky Book"
[X13]: https://motiontwin.itch.io/dead-cells "Motion Twin, Dead Cells development description"
[X14]: https://www.pcgamer.com/resident-evil-hd-remaster-review/ "Andy Kelly, Resident Evil HD Remaster review"
