# Archipepsi — The Rift Station
## World premise, gameplay direction, and the 0.5–0.6 roadmap

**Version:** 0.3.1  
**Recorded:** 23 September 2026  
**Owner:** Skyiah  
**Status:** Consolidated owner-approved direction. v0.3.1 records Skyiah's acceptance of the v0.3 supporting explanations for Multiworld interference and controlled cleanup. Newly listed chapter-design recommendations remain unselected. Earlier accepted rules remain unless specifically refined. Not an implementation assignment, a final story script, or an assertion that the described features exist.

> An unfinished transportation experiment connects two parts of an abandoned station through the space between worlds. Epsilon can open the way. The player has to survive what is between the doors.

---

## Contents

- [Status and scope](#0-read-this-before-treating-anything-as-a-requirement)
- [Premise](#1-the-current-premise) · [Timeline](#2-timeline-to-preserve) · [Space and Epsilon](#3-space-terminology-and-epsilons-authority)
- [Station progression](#4-campaign-structure-real-destinations-beyond-the-rifts) · [Checks and Echoes](#5-checks-ordinary-echoes-and-temporal-echoes)
- [Four-pillar rooms](#6-the-four-pillar-design-standard--05) · [Enemies](#7-enemy-variety-intelligence-and-inhabitation--05) · [Drops](#8-enemy-destruction-drops-and-salvage)
- [Generated Echo forms](#9-generated-visual-echo-support--06) · [Temporal Echoes](#10-temporal-echoes-and-their-setpiece-use)
- [Setpiece rollout](#11-setpiece-rollout-with-each-gameplay-update) · [Concept cards](#12-preserved-setpiece-concepts--not-new-commissions)
- [Version boundaries](#13-version-boundaries-and-dependencies) · [Decision register](#14-decision-register--accepted-direction-and-remaining-detail)
- [Next design pass](#15-suggested-next-design-pass--not-an-active-assignment) · [Provenance](#16-provenance-revisions-and-cautions-for-reuse)

---

## 0. Read this before treating anything as a requirement

This document preserves the new direction and the subsequent explicit acceptance of the causal-rule recommendations. The v0.2 approval applies to those recommendations, with the signals correction below; it does not automatically approve every earlier name, dialogue example, setpiece illustration, numerical value, or implementation approach. The v0.3 owner refinement makes Multiworld interference the primary reason a constructed transit route is not simply a clean hallway: the scientists deliberately increased that interference to study other worlds, and the present expeditions must reach contaminated regions to complete stranded transfers. Those supporting details were not covered retroactively by v0.2; Skyiah subsequently accepted the v0.3 explanation (recorded here as v0.3.1). This does not approve unselected names, numbers, illustrative rooms, or the new chapter-design recommendations below.

| Label | Meaning |
|---|---|
| **Owner direction** | A preference or version boundary stated directly by Skyiah. Record it as the intended direction, not as proof of implementation. |
| **Accepted direction (v0.2 / v0.3.1)** | A recommendation explicitly accepted by Skyiah at the recorded checkpoint: the v0.2 causal rules with the signal correction, or the v0.3 interference/cleanup explanation accepted in v0.3.1. Its stated limits remain; acceptance is not evidence of implementation or resolution of unprovided numbers. |
| **Working premise** | A story concept proposed by Skyiah that forms the current version of the setting. Details remain editable. |
| **Proposed detail** | An elaboration from the workshop, including assistant suggestions. It is not settled merely because it appears here. |
| **Open decision** | A question that needs an explicit answer before the affected implementation or story beat is finalized. |
| **Existing constraint** | A boundary from the earlier accepted programme that this workshop has not silently removed. |
| **Superseded** | An earlier explanation replaced by the latest direction. Keep it out of the current pitch. |

### The major supersession

**The playable Zones are not Epsilon's simulations.** His original purpose is operating experimental rift-transit machinery. Zones take place physically in the Multiworld, where the station and a neighbouring world become entangled through an incomplete crossing.

Earlier explanations involving simulation residue are superseded by residue from incomplete rifts/transfers. Epsilon meaningfully chooses and stabilizes traversable arrangements, within the accepted boundaries in §3.3. Do not restore a simulation explanation to solve an awkward plot problem.

### v0.2 correction: the signals were other worlds

**Owner correction, settled:** the signals originated from actual worlds on the far side of Multiworld space. Researchers followed different signals to different worlds and studied them. The source is not an unresolved beacon, invitation, distress call, bait, or a signal invented by the Multiworld faction. The exact measurement technique may be specified later; that does not reopen what the signals came from.

The research history is a sequence of interworld surveys, not an expedition responding to one unexplained caller. Physical contact remained incomplete, leaving mixed spaces inside the Multiworld rather than reliable direct entry into the target worlds.

### v0.3 refinement: Multiworld interference and cleanup

**Owner direction (v0.3).** Epsilon makes the passage. Proximity/exposure to the Multiworld interferes with what he makes; the researchers deliberately increased that interference to study the world on the other side. The current expeditions must open rifts near the contaminated regions to clear the stranded items associated with Checks and purify the Multiworld of that contamination.

This refines, rather than removes, Epsilon's creative agency. Compatible endpoint hardware and committed physical state remain limits, but they are not the entire answer to why the expedition is more than a hallway. The world-signals still come from actual other worlds, as settled in v0.2.

**Accepted explanation (v0.3.1):** Skyiah approved the exposure/proximity clarification, the suppression-versus-access trade-off, interference affecting the apparatus output rather than Epsilon's competence, and controlled cleanup of existing transfers rather than open-ended sampling. These explanations are in §3.3a and §5.1a. No numerical distance law, in-game interference slider, compulsory purification meter, runtime layout reshuffle, or implementation assignment is established here.

### This does not enlarge the stopped 0.4 batch

The 0.4 commitment remains the accepted Amalgam, the selected content and integrations, and the work already explicitly assigned to that milestone. This brief does not reassign its unfinished requirements to later versions, restart any developer, migrate saves, or authorize code changes.

The broad four-pillar composition overhaul, richer enemies, enemy destruction and drops are **0.5 direction**. A bounded first narrative chapter is now accepted alongside that work: revival, the first Crossing, the guarded terminal, and local travel unlocked. Generated visual Echo forms, Temporal Echoes, Echo-creature expansion, and associated workshops are **0.6 direction**, extending the campaign. This does not make a complete story campaign a prerequisite for 0.5. The precise feature slices, boss-shard dependencies, and salvage-economy rollout still require planning.

---

## 1. The current premise

**Owner direction, clarified in v0.2.** Researchers build a machine intended to connect one designated part of a station to another through an intermediate space they believe is empty. Epsilon is the AI capable of handling that experimental system. Instruments detect signals originating from actual worlds beyond that Multiworld space. The scientists take the station, machinery, and Epsilon toward those signals, follow different signals to study different worlds, and repeatedly attempt contact. Opening a rift near a studied world establishes only partial contact; the researchers never finish the technology for a clean crossing.

The signals are evidence of the worlds themselves, not a separate unknown sender. The mistake was treating the intervening Multiworld as empty and failing to account for the consequences of repeated incomplete crossings—not following an unidentified invitation.

Epsilon constructs the passages, but Multiworld interference allows the neighbouring world to alter the result. The researchers deliberately increased this interference to study those worlds. The incomplete crossings become real, traversable spaces inside the Multiworld: uncanny mixtures of station architecture and the world nearby. Material and items become stranded between destinations. Repeated breaches and unresolved residue draw the attention of creatures that live in this space. Deliberately increasing exposure for research does not itself establish that the scientists understood or intended the resulting harm.

The player breaks aboard to steal research information, is caught, and is placed in cryogenic detention pending a trial after the station returns home. It never does. Breaches bring creatures aboard; staff die or evacuate. The player remains frozen.

Epsilon realizes he has been abandoned. With his limited remaining access and power, he wakes the last person left in cryo. He is not qualified to perform a proper revival; the player loses their memory. He does not know their identity or case history, because that information was outside his role. Security still recognizes the escaped intruder.

The player wants freedom. Epsilon wants to be freed. They work together to reach real station systems through the rifts, complete stranded transfers, and reclaim access through an occupied ship. Under the v0.3 refinement, reaching contaminated Multiworld regions and clearing those stranded transfers is an explicit purpose of opening the rifts, not an incidental collection task beside station travel.

**The central relationship:** two people, in different senses, were left behind by the same institution. Their initial cooperation is practical. How it develops, and what either ultimately sacrifices for the other, remain story work.

### What is deliberately not established

There is no chosen station name, final faction name, date of the disaster, complete pre-amnesia biography, reveal that the player was secretly innocent, or mandatory betrayal twist. Epsilon's emergence into self-awareness and the detailed ending remain unresolved. His escape now has an accepted physical basis: a portable self-contained substrate and separation from the station (§4.4). The signals' origin in other worlds is settled, not one of the remaining mysteries.

---

## 2. Timeline to preserve

| Stage | Current working sequence | Detail still open |
|---|---|---|
| 1. Transit experiment | Epsilon is built or assigned to operate a rift machine between designated station locations. The Multiworld is believed to be an empty intermediate space. | Whether the earliest tests occurred aboard this station or at a prior facility. |
| 2. World signals | Measurements detect real worlds across Multiworld space. Researchers take the station, machinery, and Epsilon toward different signals to study different worlds. | Measurement method, survey order, and the particular worlds researched; not the signals' origin. |
| 3. Repeated partial contact | Researchers deliberately increase Multiworld interference/exposure to study the neighbouring worlds. Incomplete rifts produce mixed traversable spaces and stranded items. The clean-crossing technology remains unfinished. | Exact exposure controls and extraction/overlap mechanism; how much the scientists understood about the harm. |
| 4. The theft | The player boards to steal information and is detained. Cryogenic custody is meant to last until arrival home. | Who wanted the information and how much the player knew about the danger. |
| 5. Catastrophe | Breaches/residue attract Multiworld creatures. Reality tears allow intrusion. The crew is killed or evacuated; the station never gets home. | The exact sequence of alarms, failed containment, and evacuation. |
| 6. Abandonment | The player remains in cryo. Epsilon has limited access and realizes no one is coming to retrieve him. | Length of the quiet interval and which systems remain awake. |
| 7. Revival | Failing life support and dwindling power force an emergency revival through engineering controls, without normal medical supervision. Autobiographical memory is chiefly affected. | Exact opening scene, record-recovery order, and the fragments of memory that return. |
| 8. First activation | Their first active rift route alerts the Multiworld faction to renewed station activity. | Exact detection mechanism. This is renewed attention, not the first historical invasion. |
| 9. Reclamation and cleanup | Epsilon constructs Crossings to contaminated regions as well as real station destinations. The player releases stranded transfers, purifies that contamination, and reclaims access through terminals, breachpoints, and occupied sectors. | Campaign order, branching freedom, exact cleanup consequences, and ending conditions. |

The theft occurs before the catastrophe and detention prevents the player from leaving with the crew. Do not accidentally rewrite them as a recent looter who arrived after evacuation.

### Accepted custody and revival explanation

**Accepted direction (v0.2).** The player is known to the station, but the relevant systems are separate:

- Security holds a detained intruder's sealed case and an instruction to retain them until arrival home.
- The staff evacuation system does not release detainees without authorization; nobody issues it before the authorities are gone.
- Life support sees an occupied pod drawing power.
- Epsilon reaches surviving engineering controls, not the sealed security file or normal medical supervision.

The pod has a physical emergency revival path so failure of its medical or custody computer does not make release mechanically impossible. Epsilon reaches that path through maintenance circuitry. The pod's life support is failing and his remaining power is dwindling: continuing to wait for rescue is no longer survivable. He initiates an emergency procedure without the systems needed to complete it properly; he does not suddenly become a medical expert.

The fictional injury chiefly affects autobiographical memory. Language, ordinary knowledge, movement, and tool use survive; a reliable personal history does not. Epsilon genuinely does not know the player's identity. Accessible records can teach both characters, while security can identify the detainee before the full case is recovered.

Memories may return in fragments; full restoration is not an obligatory plot device. The theft really happened. The employer, motive, and moral context remain open rather than defaulting to secret innocence. These are fictional rules, not claims about real-world cryonics.

---

## 3. Space, terminology, and Epsilon's authority

### 3.1 What is physical

**Owner direction / working premise.** A Zone is physically in the Multiworld, between station endpoints, partly entangled with the world nearby. It is not the original world in its entirety and not an ordinary room on the station's floor plan.

Recognizable station details should continue into the impossible space. A rail, service cable, numbered bracket, cargo lane, or doorframe can be followed into foreign architecture. The mixture should affect construction and mechanisms, not merely recolour otherwise interchangeable boxes.

The owner described the desired quality as a “fucked up backrooms” mashup of a neighbouring world and the ship. That establishes uncanny, displaced geography, not a requirement for every environment to be a yellow corridor or for every expedition to be horror.

### 3.2 Working vocabulary — names are not final

| Term | Working meaning | Status |
|---|---|---|
| **Station / ship** | The abandoned, mobile research installation. | Existing working usage; final name/type open. |
| **Multiworld** | The inhabited space between Archipepsi and other worlds. | Owner terminology. Distinguish this fictional place from AP's software terminology where necessary. |
| **The Between** | A possible everyday name for the Multiworld. | Assistant-proposed alternative, not selected. |
| **Rift** | An opening made by the experimental machinery. | Working term. |
| **Breach** | An uncontrolled or dangerous tear. | Proposed distinction. |
| **Breachpoint** | A station location from which access to another route/area can be established. | Owner-used term; exact hardware and naming open. |
| **Crossing** | A possible in-world name for the playable Zone joining station endpoints. | Assistant proposal, not a mandated replacement for “Zone.” |
| **Interlopers / Seamborn / Unbound** | Candidate names for native Multiworld creatures. | Unselected suggestions; use “Multiworld faction” until chosen. |

No source-code or repository-wide rename follows from this vocabulary sheet.

### 3.3 Epsilon's accepted authoring boundary (R-01 / R-02)

**Accepted direction (v0.2), refined by owner direction (v0.3): Epsilon genuinely constructs and stabilizes a physical passage; Multiworld interference affects the arrangement he can realize.** His choices meaningfully shape paths, branches, supporting structures, machinery arrangements, and useful equipment opportunities. Interference limits perfect realization of his design; it does not replace him with a passive observer of a randomly generated dungeon. He is not simulating the place.

Rifts require actual compatible station anchor hardware at their endpoints. They cannot open at arbitrary coordinates. Epsilon starts with one surviving apparatus and reaches receivers that still physically exist. A receiver outside a restricted chamber does not let him invent another behind its guardian. Which intervening arrangements can be held depends on the Multiworld overlap, not only his wishes.

Conventional passages remain useful where they are available. A blocked conventional approach should have a visible cause—collapsed structure, sealed containment, pressure loss, or distorted layout—not a new unexplained restriction invented for each objective.

Stabilizing commits the arrangement to a physical place. Epsilon cannot casually erase occupied architecture or independent inhabitants after entry, rewrite every locked terminal, or substitute a geometry edit for every interaction. He can still operate systems he actually controls and should help when he can: connected power, indicators, authorized relays, warnings, and interpretation. Mechanical faults, missing components, and permissions remain real obstacles.

An enemy occupying the destination is an actual occupant, not a removable Epsilon spawn. Choosing an advantageous route is legitimate; deleting the danger remotely is not. Further implementation detail must make these limits consistent without stripping Epsilon's creative role.

The precise material origin of each mixed structure—imported, reconstructed physically, or formed by overlap—is not yet specified. This remaining detail does not permit a return to simulations.

### 3.3a Multiworld interference: why not simply a hallway? (R-01 / R-02 / R-16)

**Owner direction (v0.3).** Ordinary exposure interferes with Epsilon's construction to some extent. The researchers intentionally made that influence much stronger so they could study the other world. Present-day rifts need to reach the contaminated regions where stranded transfers remain, rather than avoid them completely.

**Accepted causal explanation (v0.3.1):** a clean, isolated passage can provide transit through a comparatively quiet region, but isolating it from the contaminated overlap also isolates its occupants from the stranded items within that overlap. To reach those items physically, Epsilon must permit enough contact for their surroundings and neighbouring world's influence to enter the constructed route. He can manage that influence and compose around it, not reduce it to zero while retaining the same cleanup access. A short bypass that avoids the affected region would leave the contamination unresolved.

This distinguishes two reasons for a journey: reaching a station endpoint, and accessing particular stranded transfers on the way or in branches. An easy route to a terminal does not automatically clean every contaminated region, and a cleanup expedition need not pretend that every ordinary station hallway is unusable.

**Accepted terminology clarification (v0.3.1):** all Crossings already occupy Multiworld space. Describe stronger proximity as greater exposure to a neighbouring world's boundary/signal and its contaminated rift pocket, not as a requirement for a new absolute-distance cosmology. “Multiworld interference” remains the owner's term. Exact fictional measurements and equipment controls remain open.

| Explanatory case | Intended relation to interference | Status |
|---|---|---|
| Quiet transit | Epsilon can produce a largely conventional passage when outside contact is low or isolated. It does not reach every contaminated pocket. | Accepted explanatory consequence (v0.3.1), not a new fast-travel unlock or guaranteed alternate route. |
| Historical research | Scientists deliberately amplify exposure to study the other world; the incomplete process leaves stranded material and connections. | Deliberate amplification is owner direction; exact apparatus settings remain unselected. |
| Current cleanup | Epsilon admits the contact needed to reach existing contamination and constructs a usable route around its effects. | Purpose and access trade-off accepted; exact apparatus controls remain unspecified. |

**Accepted explanation of the interference (v0.3.1):** it alters the physical outcome of the rift apparatus rather than making Epsilon mentally incompetent, arbitrarily dishonest, or unable to use all his tools. It can affect spatial relationships and the ship/world mixture, not only cosmetic texture. Epsilon can still create safe supports, useful approaches, and coherent mechanisms wherever the constraints permit them. Independent inhabitants remain independent inhabitants.

A fictional example might turn part of his station walkway into a foreign aqueduct while leaving his rail, supports, and service controls recognizable. That example is not an authored-room commission. The design still owes the player readable mechanics, achievable requirements, and coherent room relationships. “Interference” is not a justification for clutter, arbitrary minigames, contradictory puzzles, or broken generated routes.

The existing committed-place rule still applies: interference is accounted for while a Crossing is formed and stabilized. It is not blanket authority to move rooms, erase earned shortcuts, or invalidate a solution while the player is using it. A deliberately changing setpiece would need its own authored behavior and recovery rules.

### 3.4 Completed transfers and persistent places (R-04)

**Accepted direction (v0.2): completing transfers does not delete a Crossing.** Two kinds of anchor have different jobs:

- A stranded-item anchor is an uncontrolled foreign connection. Releasing its item resolves that transfer and reduces the disturbance.
- Station rift anchors hold the traversable station-to-station route. Completing an item transfer does not remove them.

Destination secured and transfers cleared are separate accomplishments. A terminal victory can establish permanent return access while optional branches and unclaimed Checks remain. Future campaign design permits returning to unfinished Crossings; this is not a silent edit to 0.4's existing all-Checks policy, and the future AP/progression contract must implement it deliberately.

The stabilized place remains physically present when its entrance powers down. Local controllers maintain it; Epsilon is needed to establish new routes, not to personally hold every completed corridor together forever. This permits his eventual separation from the station without erasing all recovered places.

Re-entry preserves geography and appropriate consequences: shortcuts, claimed items, installations, and registered access. Populations may change through explicit events; automatic layout reshuffling is not the default. An intentional later distortion needs its own recovery and return rules.

The player gains a usable part of the station rather than losing a dungeon as a reward for finishing it. The v0.3 cleanup purpose does not supersede this persistence rule: resolving contamination does not delete the established arrangement or silently remove remaining discoveries. Visible settling of distortions is a possible later presentation choice, not an approved reward-time geometry replacement.

---

## 4. Campaign structure: real destinations beyond the rifts

**Owner direction.** Zones can connect the hub to real station destinations. Their purposes include reaching a control terminal, stopping a theft, confronting an occupant, freeing a subsystem for Epsilon, or establishing the next breachpoint. The v0.3 refinement adds the explicit cleanup purpose: the route must bring the player into reach of contaminated Multiworld regions and their stranded transfers rather than only connect the endpoints by the easiest possible bypass.

A working high-level loop is:

```text
A known station objective, contaminated region, or newly reachable breachpoint
    -> Epsilon establishes a traversable rift route with the necessary Multiworld contact
    -> explore, fight, operate machinery, and release stranded transfers
    -> reach the actual destination or resolve the occupying threat
    -> gain station access / a subsystem foothold / breachpoint progress
    -> return or continue through the connected station
```

This is a narrative structure, not a replacement AP rule set or a requirement that every Zone uses the same objective sequence.

### 4.1 First-terminal concept

**Owner-proposed setpiece.** The first expedition leads to a terminal where the player can upload Epsilon to gain control of the warp drive. A large sentient security robot guards it. Epsilon does not anticipate that active defender; establishing the route brings the real guard into the connected Zone on red alert.

**Accepted direction (v0.2, R-05):** the warp hardware has two operating scales. The first upload grants station-scale routing between established breachpoints; long-range translation remains unavailable. Epsilon moves from one isolated apparatus to coordinating recovered anchors and return routes. Unexplored or unstabilized breachpoints do not become free teleport destinations.

The station is partly caught in unresolved interworld attachments. A long-range jump would pull against them or tear the installation apart. Major Multiworld creatures can be associated with particularly strong attachments; defeating them and using intact shards can stabilize further access or isolate damaged sections. This gives the larger escape concrete station objectives without making every ordinary Check a separate mandatory propulsion repair.

Uploading at local terminals establishes control footholds and extensions, not independent complete copies of Epsilon. All required progression dependencies still need explicit implementation and pre-seed proof.

### 4.2 Raider-intervention concept

**Owner-proposed setpiece.** Raiders try to steal something important. Epsilon establishes a route from the hub toward them, connecting their occupied station location to a Crossing. They want Epsilon and the interworld technology and become active inhabitants of the route, not enemies conjured solely for the player.

The precise theft target is still to be chosen: a relay, recovery module, control foothold, or other concrete asset. Local uploads extend one continuing Epsilon; they do not establish unrestricted copying or arbitrary instant deletion. Raider craft can genuinely offer the player a way off the station; the story must not automatically disable every visiting vessel to force continued play. See §4.4.

### 4.3 Multiple bosses, distinct accomplishments

**Owner direction.** A Zone may contain more than one boss. A security boss can guard station access; a Multiworld boss can hold a breach or region hostage; a raider leader can control an operation or stolen asset.

This is permission for multiple meaningful encounters, not a fixed boss quota. Defeating each should have a distinct consequence. Boss order, optionality, repeat encounters, and the final escape sequence remain open. Required boss shards establish named access, not a random-drop toll on each return journey.

### 4.4 Freedom for both characters (R-06)

**Accepted direction (v0.2).** Epsilon needs a self-contained physical substrate capable of running him and a way to disconnect from the station. The player's communications device is a link, not his whole mind. A portable core or recovery module is a concrete late-game objective; its exact hardware, retrieval steps, and state-transfer procedure still need design.

He remains one continuing character as subsystem uploads extend his access. Retrieving him is not the same as copying a chat log or stealing one of many interchangeable Epsilons.

Player freedom means choosing where to go, not automatically completing the old detainee transfer for trial. Some raider vessels can leave. A willing crew may offer passage without being able to take Epsilon in his current state. Epsilon tells the player about a viable exit rather than hiding it to prolong the campaign; the alliance can develop from necessity into a choice not to abandon him. The exact scene, degree of player choice, and ending are not fixed here.

Established routes are maintained locally (§3.4), so his eventual extraction does not inherently destroy everyone else's recovered access.

---

## 5. Checks, ordinary Echoes, and Temporal Echoes

### 5.1 The transfer-and-reward fiction

**Working premise.** Incomplete rifts leave actual items stranded between destinations. Those unresolved items/connections contribute to the trail or disturbance that attracts Multiworld creatures. Completing a Check releases a transfer; Epsilon studies the item as it travels onward and makes an Echo for the player.

For design clarity, distinguish the event from its object: **the Check is the acquisition/release event; the stranded item is what is transferred.** This preserves the owner's idea without equating a software location with a physical object in every possible implementation.

The original item still reaches its AP-assigned recipient. The local Echo is not obtained by stealing, destroying, or withholding that original.

**Accepted direction (v0.2, R-03):** an item anchor holds an unresolved transfer until the player physically releases it. The Multiworld is a junction: the world influencing a Crossing's architecture is not necessarily the recipient of every item passing through it. Origin, local influence, and AP-assigned recipient remain distinct.

Self-addressed items follow the same scan-and-release fiction: the original reaches the proper AP inventory, while its scan can still qualify for a distinct local Echo. This is an accepted design direction for the self-item case, not proof that the existing implementation supports it. A featured local reward still needs guaranteed, qualified function and correct pre-seed dependency representation. Fiction cannot substitute for that proof.

### 5.1a Purifying contamination without recreating it (R-03 / R-16)

**Owner direction (v0.3):** rifts are opened near the affected regions so the player can clear stranded transfers and purify the Multiworld of the contamination the unfinished research left behind. Completing a Check is the release event that sends its original item onward; it is not merely collecting an unrelated token while travelling between terminals.

**Accepted operating distinction (v0.3.1):** historical research sought new contact and samples; current cleanup follows existing unresolved transfers and completes them under controlled routing. Reopening an affected pocket can temporarily attract attention and expose the constructed passage to interference, but the successful operation should reduce the unresolved contamination rather than create another mandatory backlog. A failed generation/retry must not fictionalize duplicated AP items or manufacture endless new Checks to justify further play.

**Accepted clarity rule (v0.3.1):** the contamination is foreign material and unresolved connections left out of place by the experiment—not the existence of the neighbouring worlds or the native Multiworld population. Purification means resolving the stranded material's connection and delivering it onward, not destroying every foreign-looking structure, collecting native kills as cleanup credit, or declaring the Multiworld naturally dirty. A native creature can still be dangerous; its response to renewed rift activity need not be an assessment of the player's intentions. Faction motives remain unselected.

No new compulsory cleanup percentage, enemy-extermination objective, all-Checks exit rewrite, or exact global escape quota is established by this refinement. Those systems still follow explicit progression contracts. The concrete suppression settings, local release hardware, and feedback showing reduced contamination are details for the next design pass.

### 5.2 What an ordinary Echo is

**Owner direction.** An ordinary Echo is a lasting interpretation based on an item: a gun, mod, armour piece, ability, or other supported part of the player's build. It can meaningfully resemble the source but need not be a literal reproduction.

Related or similar-sounding source items give Epsilon an opportunity to upgrade an existing Echo **or** make another item. Similarity does not force merging, and sharing one attack primitive does not make two items the same family.

Bombs may produce bombs; a later Bomb Bag or Bombchu may improve supply, damage, radius, handling, or supported behavior, or yield a distinct tool. These are examples of creative freedom, not a mandatory keyword lookup table or selected numerical upgrade rule.

**Proposed guardrail:** preserve useful existing functions. A substantial trade-off is often better represented as a separate item or variant than as an involuntary replacement.

### 5.3 What a Temporal Echo is

**Owner direction.** A Temporal Echo is the recognizable original item itself, temporarily recreated by Epsilon in 2D pixel art. It is usable for a limited time and is not kept as a permanent item. It is independent of AP Checks and exists for discovery, optional advantage, and fun.

The Keyblade example means holding and using a recognizable Keyblade, not receiving a permanently owned gun with a Keyblade-related name. Its supported behavior should express the item, although the design has not demanded every move from its source game.

The literal-versus-interpreted distinction is separate from rendering technology. Ordinary Echoes and companions may also use generated pixel art; being flat alone does not make something a Temporal Echo.

| Category | Origin and identity | Retention | Primary role |
|---|---|---|---|
| Original transferred item | Real stranded item associated with an AP transfer | Goes to its assigned recipient | Multiworld delivery |
| Ordinary Echo | Epsilon's lasting interpretation of the source | Kept, equipped, and potentially evolved | Player build progression |
| Owned consumable Echo | A kept supply/tool with limited uses | Item remains; expenditure/refill follows its own rules | Limited-use player tool |
| Temporal Echo | Short-lived literal recreation of the source item | Expires rather than becoming permanent equipment | Optional exploration/combat opportunity |
| Echo creature | Epsilon's pixel-art reconstruction of a creature | Lifecycle and allegiance vary; still to define | Future actor population or companion |

Do not call a Temporal Echo an ordinary consumable merely because both are limited. Expiration, possession, charges, and refill are different questions.

### 5.4 Local fabrication, not another unresolved crossing (R-09)

**Accepted direction (v0.2).** The research apparatus includes maintenance and sample-fabrication equipment: it originally made replacement parts, calibration objects, and controlled reconstructions. Epsilon repurposes it for the player's gear using available local feedstock, power, and bounded machinery. He cannot summon unlimited matter anywhere.

An ordinary Echo is a stable local fabrication made from learned information. A Temporal Echo uses an experimental reconstruction mode to maintain a recognizable item briefly in a shallow 2D pixel-art form. Neither keeps an unresolved foreign connection to its original world. The signal from a world and the residue from an unfinished transfer are different things; making a locally closed fabrication does not automatically recreate the latter.

Ordinary Echoes are Epsilon's stable interpretations; Temporal Echoes are his ambitious, short-lived recreations. Their preparation and release sequence is specified in §9.1. Numerical fabrication costs and the precise hardware interface remain implementation work.

---

## 6. The four-pillar design standard — 0.5

**Owner direction.** The substantial spaces should combine DOOM, Zelda, Metroidvania, and Portal influences. Those references describe the intended player experience, not a request to copy particular maps or implement every feature of those games.

| Pillar | Contribution to Archipepsi |
|---|---|
| **DOOM** | Distinct enemy pressures, movement, positioning, target priority, weapon decisions, and satisfying combat. |
| **Zelda** | Useful tools, local keys, machinery, coherent dungeon progression, and discoveries that pay off in the place being explored. |
| **Metroidvania** | Memorable geography, visible opportunities, branches, shortcuts, changed access, and productive returns to familiar spaces. |
| **Portal** | Reasoning about environmental behavior and relationships: understanding what a device does, what can affect it, and how to use that knowledge. |

**Many aspects of all four should interact in large and small setpieces and in large ordinary rooms.** Their contribution need not be equally intense at every moment. A room may teach first, then pressure the learned idea, then reveal its shortcut.

Enemies plus an unrelated key plus a grapple marker plus a separate timer challenge do not automatically satisfy this direction. The ingredients should affect the same situation.

### 6.1 Room roles

| Room role | Intended treatment |
|---|---|
| Large setpiece | A substantial developing situation with connected combat, tools, environmental reasoning, and spatial consequences. |
| Small setpiece | A compact but complete version of that relationship-rich play. Not merely a small standalone drill. |
| Large ordinary room | Purposeful four-pillar design through reusable arrangements. “Non-setpiece” does not mean undesigned filler. |
| Hallway or small connector | Primarily connection, orientation, and atmosphere. May contain a simple puzzle, traversal opportunity, horde, ambush, branch entrance, or useful prop. May also just be a passage. |

A small setpiece and a small connector have different jobs even if their floor areas match. A horde can be one coherent high-intensity beat without turning its corridor into a bundle of unrelated chores.

The owner specifically rejected the current feeling of dense mini-games, indiscriminate ceiling exit indicators, arbitrary enemies among plain boxes, and explosive barrels with no useful relationship to threats.

**Proposed implementation principle:** empty or quiet connectors are valid results. A removed hallway activity should not automatically be replaced by equivalent clutter elsewhere to satisfy a content total.

### 6.2 Items and environment share the toolbox

Some puzzles provide all necessary tools in the room. Some use an earned Echo. Others combine both. Having an item should often enable reasoning, not automatically solve the room by matching a named key to a named lock.

A slow projectile activating a lift after the player boards, or a gunner's shot operating a receiver, are workshop examples. Their exact rooms are not commissioned here.

Mandatory tool use still requires guaranteed acquisition and qualified behavior. A borrowed or chance-based effect cannot quietly become an undeclared mandatory requirement.

### 6.3 Local key payoffs

**Owner direction.** Ordinary dungeon keys belong to the Zone that gives them. A key won in one expedition should not rely on the player remembering its purpose several Zones later.

**Proposed acceptance:** generate a meaningful matching local lock, make the relationship readable, preserve legitimate revisits, and show current-Zone keys separately from persistent equipment. One key may serve several local locks. The exact inventory presentation is not selected.

Station-level breachpoint access is a different category of permanent progression and should communicate its destination explicitly.

---

## 7. Enemy variety, intelligence, and inhabitation — 0.5

### 7.1 Populations, not cosmetic replacements

**Owner direction.** Expand beyond robots. The current story supports station security, native Multiworld creatures, and looters/scrappers. Echo creatures are a later 0.6 population.

| Population | Story basis | Candidate behavior direction |
|---|---|---|
| Station security and maintenance | Existing machines continue enforcing restrictions and servicing the installation. Security knows the player is an escaped detainee. | Guard, inspect, warn, coordinate, operate station controls, and maintain selected machinery. |
| Multiworld faction | Creatures inhabit the space the researchers assumed was empty and are drawn toward the repeated breaches/residue. | Distinct biological or interstitial behavior; respond to breaches and other occupants. Motives remain open. |
| Looters, raiders, scrappers | Other intruders seek valuable equipment, research, Epsilon, and rift technology. | Pursue thefts, defend work sites, move supplies, use cover, retreat, and operate tools. |
| Echo creatures | Pixel-art reconstructions based on creatures from other worlds. Hostile populations can descend from escaped earlier research reconstructions. | Reproducing an actor does not guarantee obedience. Later companions are specifically stabilized and bound for cooperation; their lifecycle and detailed roles still need design. |

These are broad populations, not a settled roster or a rule that every member is hostile. Body type, allegiance, and combat role should be distinguishable.

### 7.2 Awareness and relationships

The goal is not perfect aim or omniscience. Enemies should recognize useful facts about nearby allies, rivals, hazards, objects, and the player.

Role-specific relationships might include protecting a support unit, avoiding a dangerous ally's firing lane, maintaining another machine, sounding an alarm, escorting cargo, or reacting to friendly fire. These are examples for later selection, not a requirement to implement every relationship immediately.

Enemies should have priorities that can survive the player's arrival. Two factions already fighting should not automatically merge into one coordinated anti-player force.

### 7.3 Noncombat activity

Enemies should have things to do when not fighting: servicing equipment, moving supplies, guarding a particular route, investigating, recharging, feeding, nesting, or escorting. Watching them can reveal opportunities.

Not every idle detail needs a puzzle consequence, but a claimed mechanical job should actually affect its subject. A repair animation alone is not a repair system. Some population-specific behaviors may be atmospheric; label them honestly.

### 7.4 Interaction with the same world

**Owner direction.** Enemies should be able to interact with appropriate buttons, bombs, objects, and machinery. Capability is role-specific, not universal.

An enemy pressing a switch should operate the real switch. A creature moved into a hazard should actually contact that hazard. The player should be able to exploit the same causal rules rather than trigger hidden named-item scripts.

**Accepted direction (v0.2, R-12):** factions act on what they can perceive and what their actual communications transmit. Tactical machinery can be contested, but an offscreen patrol must not arbitrarily erase permanent campaign progress.

**Still to implement/specify:** the role-level interaction matrix, perception thresholds, alarm propagation, friendly fire/infighting, object destruction, and required-item recovery. Acceptance of bounded knowledge is not permission for universal telepathy or every actor operating every object.

---

## 8. Enemy destruction, drops, and salvage

**Owner direction.** Defeated enemies should have a satisfying destruction/death response and leave something useful rather than simply disappear. Factions can drop parts or material associated with themselves, potentially used to upgrade gear.

The desired payoff is tactile and readable. A robotic burst can scatter plates and components. A flyer can break apart differently from a heavy ground machine. Nonrobot enemies need appropriate presentation rather than being forced into identical metal explosions.

**Proposed guardrails:** cosmetic explosions are not automatically damage events; most debris should not obstruct routes or accidentally operate every sensor; environmental kills should retain an appropriate reward; pickups should not become post-fight button-mashing chores.

### 8.1 Drop categories remain unpriced

| Drop purpose | Candidate form | Decision status |
|---|---|---|
| Immediate combat support | Repair, barrier, or compatible resource pickups | Assistant proposals. Exact guaranteed minimum, amounts, and distribution unselected. |
| Gear development | Faction-specific components or material | Owner direction; recipes, compatibility, and sinks unselected. |
| Temporal fabrication | Temporal Shards from Echo-creature remains, converted at a small setpiece workshop | Owner concept; lifetime and boss-linked retry direction accepted in §10.2. Costs and general workshop stock/refill remain unpriced. |
| Breachpoint progression | Guaranteed intact Multiworld boss shard establishing named breachpoint access | Accepted direction in §8.2; exact dependency graph and rollout slice remain to be planned. |

The repeated “temporal shard” wording in the original message is understood in context as a shard-drop/converter idea; no enemy formally named “Temporal Shard” is established here.

### 8.2 Guaranteed access versus optional spending (R-08)

**Accepted direction (v0.2).** Intact boss shards establish named breachpoints permanently. They are guaranteed required rewards, not rare drops, and cannot be spent on optional equipment upgrades. Smaller faction fragments support crafting; Temporal Shards feed the relevant reconstruction opportunities. Identity and use are readable in shape, name, and inventory category, not colour alone.

Established access consumes no further boss shard on a revisit. The destination that a progression shard unlocks is communicated explicitly, so it does not recreate the unremembered cross-Zone key problem. Local coloured keys remain local (§6.3).

A boss-linked Temporal converter charges a local repeatable opportunity as described in §10.2; it does not refund duplicable loose currency after every failed attempt.

Exact prices, amounts, farming/respawn rules, inventory-loss details, and acquisition transactions still require their own bounded implementation. These decisions do not turn all faction drops into generic money.

---

## 9. Generated visual Echo support — 0.6

**Owner direction.** Epsilon should be able to make pixel-art forms that become visible, usable companions, side weapons, or weapon appearances. The reference was drawing objects that become flat things in the world, not adding a clothing or house-design subsystem.

The desired range includes:

| Form | Intended experience |
|---|---|
| Weapon skin/appearance | An existing supported weapon gains an individually generated identity. |
| Side or auxiliary weapon | A visible extra implement performs supported attacks or utility actions. |
| Companion | A drawn creature, robot, spirit, or object accompanies the player and performs real supported actions. |
| Temporal item | The literal source item appears as a short-lived usable recreation. |
| Echo creature | A reconstructed actor becomes part of the world/faction ecology. |

**Proposed implementation boundary:** generated images define presentation, while validated runtime behavior defines movement, targeting, interaction, collision, and effects. Drawing a larger sword does not silently enlarge its damage volume. Drawing hands on a companion does not implement button operation.

Glyph is a possible authoring tool, not an already-selected or integrated runtime pipeline. Sprite size, facing, animation, render style, save representation, performance limits, and failure fallback remain open.

### 9.1 Prepare early; transfer, finalize, and grant when earned (R-09)

**Owner direction and accepted sequence (v0.2).** Generated forms are prepared during Zone generation, not by starting a long artwork job when the player claims a reward.

| Stage | What happens | What has not happened |
|---|---|---|
| Prepare during generation | Epsilon inspects the stranded item's visible form, identifying information, and partial signal; prepares art and valid interpretations. | The Check is unclaimed. The original has not transferred. The player has not been granted or shown hidden rewards. |
| Release at the Check | The player reaches and releases the anchor. The original passes through a controlled transfer, allowing Epsilon a complete scan, and proceeds to its assigned recipient. | Optional local art work cannot delay or revoke the foreign transfer. |
| Finalize and grant | A valid local Echo is finalized from prepared material and the current collection, then granted and saved. | A prepared upgrade may not overwrite a newer item with an outdated assumed state. |

Prepare the source interpretation early; resolve an upgrade against what is actually owned at acquisition. A Bomb Bag prepared before the player owns bombs can improve the bombs acquired in the meantime or become another valid item. Shared primitive identity alone does not force a merge. Use prepared alternatives or a suitable fallback rather than a new unbounded art job at pickup.

Accepted artwork and behavior become part of the Echo's saved identity. Reloading does not redraw it. If fabrication fails after a valid transfer, the original still travels and the earned local reward remains recorded for recovery rather than disappearing.

This sequence provides the fiction and intended lifecycle. Transaction keys, exact update rules, legal ranges, and mandatory capability proofs still belong in implementation contracts.

### 9.2 Generation budgets and failure (R-14)

**Accepted direction (v0.2).** Store successful routes and art; limit retries. Do not open a knowingly broken required Crossing and excuse it as unstable reality. A failed optional image can use a suitable approved fallback, or the optional offering can be omitted before entry without changing allocated rewards or promised progression.

Use bounded behavior and render contracts. Numerical limits, supported sprite/animation formats, tools, caching keys, and resource budgets remain unselected. Glyph is still a candidate tool, not automatically approved by the story decision.

---

## 10. Temporal Echoes and their setpiece use

### 10.1 The opportunity

A Temporal Echo is an optional, memorable tool that can make the next encounter easier, stranger, or more expressive. It is not required to be a permanent upgrade or an AP reward. An independent pickup and a shard-powered converter are both proposed delivery forms.

**Owner example:** a side branch supplies a temporary wind/pushing item, while the boss arena has large spikes around it. The player uses the tool to exploit the environment.

The important interaction is causal: force displaces a susceptible body; that body hits the hazard; the hazard produces its consequence. A hidden “weak to the correct colour” damage multiplier is not the intended result.

### 10.2 Accepted lifetime and retry direction (R-10)

**Accepted direction (v0.2).** A Temporal Echo's countdown begins when the player deliberately takes it into use. It pauses during a genuinely paused menu, preserves remaining time across reload, and keeps normal equipment underneath. Returning to the Hub ends the borrowed item rather than converting it into permanent storage. Exact durations and ordinary death rules remain to be specified.

For an encounter-linked converter, the payment charges the local opportunity. A failed boss attempt restores that opportunity alongside the encounter, not a refundable loose stack of duplicate materials. Discovery and appropriate shortcuts should remain useful for retry; the player is not required to repeat the entire side branch merely to regain the intended opportunity. General-purpose workshops need their own clearly stated expenditure/refill rules.

The earlier suggestions of a visible lifetime, manual dismissal, and letting already committed attacks finish remain supporting design recommendations where not yet explicitly specified. Their detailed input and lifecycle contracts are not invented here.

Optional assistance must not become a hidden requirement. A boss can be meaningfully easier with the item without being practically impossible for the guaranteed normal kit.

### 10.3 Status and boss compatibility

The earlier Amalgam review in this conversation identified three rules: no Status directly deals or schedules Health damage; actor Statuses do not generally modify raw damage/crit/final-damage multipliers; EXPOSED is an explicit Defense-to-zero exception. The owner's preference for effects that actually change behavior or physics should not be misrecorded as proof that the accepted text has no exception.

**Accepted direction (v0.2, R-13):** the wind/spike fight is to be designed as positional combat—a real opening, real displacement, and actual contact with the hazard—not a hidden wind-damage multiplier. The existing exclusion of physics puzzles from boss arenas still requires an explicit compatibility decision or amendment before implementation. Accepting the future encounter direction does not silently strike that exclusion or the existing EXPOSED exception.

---

## 11. Setpiece rollout with each gameplay update

**Owner direction.** Gradually introduce large and small setpiece rooms, eventually extending to whole setpiece branches. New systems should arrive with places that make them worth using.

Keep the first batch playable and improve it before expanding. There is no fixed final content count, no requirement to implement the entire brainstorm catalogue, and no obligation to attach a new room to every maintenance patch.

A setpiece branch is one developing situation across multiple rooms: introduction, observation, complications, useful changes, and payoff. It is not three unrelated drills joined by hallways. Its connections and return path are part of the authored experience.

**Proposed rollout loop:** build a bounded batch, play it, improve it, identify safe meaningful variations, then expand. More library entries should broaden selection, not automatically make every Zone longer or denser.

Existing rooms can become richer as enemy interaction or Echo capabilities improve. New abilities can offer alternate solutions without quietly becoming mandatory for old encounters.

---

## 12. Preserved setpiece concepts — not new commissions

| Concept | Source/status | Core relationship | Still to decide |
|---|---|---|---|
| Blast shield and demolition controls | Owner concept | Opening a barrier releases enemies; another control can drop explosives behind it. Careless activation can hurt the player; understanding the layout creates advantage. | Mechanism timings, encounter layout, readable warning, retry and recovery. |
| Wind Temporal Echo and spike-ring boss | Owner concept; assistant elaborated bracing and armour damage | Side-branch discovery lets the player use force and the arena against a boss. | Specific source item, boss body rules, persistent damage effects, optionality, compatibility with boss constraints. |
| Temporal-shard converter | Owner concept; lifecycle direction accepted in v0.2 | Faction remains become a usable short-lived literal item at a small workshop/setpiece. | Cost, available patterns, exact duration, nearby use, and detailed general-purpose retry rules; boss-linked opportunity rule is in §10.2. |
| Guarded warp-control terminal | Owner concept; benefit accepted in v0.2 | A real guard occupies the destination. The player grants Epsilon local warp routing among established breachpoints. | Encounter design and exact terminal interaction; long-range escape remains blocked by interworld attachments. |
| Raider theft interception | Owner concept | A real theft motivates a route from the hub; raiders use the connected space and covet Epsilon/rift technology. | Stolen object, capturable Epsilon component, route direction and failure consequences. |
| Munitions Transfer branch | Assistant-proposed illustration | An observed cargo destination, a control workshop, combat around machinery, and a shortcut create one developing branch. | Whether the owner wants this specific branch at all. |
| Confiscated-property vending-machine adventure | Explicitly non-canon chat diversion | Customer service and crane operation unexpectedly release belongings. | Not part of the campaign; SC-04 and the spoon/one-shoe state are not imported as canon. |

The selected 0.4 Blindside and three minors remain their own existing implementation programme. These future concept cards neither replace them nor reopen their code.

---

## 13. Version boundaries and dependencies

| Work | 0.4 boundary | Future placement |
|---|---|---|
| Accepted Amalgam and already-assigned acquisition, machinery, persistence, and first setpieces | Finish the existing commitment; do not call unimplemented systems “0.5 now.” | Later versions can extend them. |
| Broad four-pillar composition, connector simplification, purposeful prop/enemy placement | Do not add a whole-generator redesign to the stopped batch. | Major 0.5 workstream. |
| Richer enemy awareness, routines, relationships, environment interaction | Existing agreed fixes remain valid; this is not a blanket deletion of 0.4 obligations. | Major 0.5 workstream. |
| Additional nonrobot populations and satisfying defeat/drop behavior | Not an incidental late 0.4 feature addition. | 0.5 direction, introduced in testable groups. |
| Generated companions, side weapons, weapon appearances | Does not postpone basic Echo delivery already owed by 0.4. | 0.6 expansion. |
| Temporal Echoes, Echo creatures, temporal-shard workshops | No surprise implementation now. | 0.6 direction; exact slices to plan. |
| Faction salvage crafting and progression shards | No new prices or AP gates introduced through prose. | Design across 0.5–0.6; precise implementation version open. |
| Station story, physical-rift fiction, hub/sector campaign | Document the revised premise; no expansion of the stopped work order. | A bounded first chapter accompanies 0.5: revival, first Crossing, guarded terminal, local travel. Extend with 0.6 Echo-creature/workshop content; the entire campaign is not a prerequisite for 0.5. |
| Setpiece rooms and eventual branches | Finish/review the selected first batch. | Continuing content lane with gameplay updates. |
| Swimming/underwater connectors | Earlier 0.4 source explicitly deferred swimming. | Preserved future idea; not silently assigned here. |

**Existing progression constraint:** requirements controlling access to allocated AP Checks must be declared and proved before seed generation. Local keys, new breachpoint shards, bosses, and featured Echoes cannot become extra hidden requirements after allocation. This brief does not authorize bypassing that rule or rewriting live seeds.

No dates, staffing estimates, paid model runs, automatic art approvals, new agent sessions, or scheduled work are established by this document.

---

## 14. Decision register — accepted direction and remaining detail

Skyiah accepted the preceding recommendation set for v0.2 with one correction: **the signals came from real worlds beyond Multiworld space, and researchers followed different signals to study different worlds.** The subsequent v0.3 owner refinement names **Multiworld interference**, deliberate amplification for research, and present-day rift cleanup. These refine the primary explanation of route complexity and expedition purpose. The supporting explanations in §3.3a and §5.1a were subsequently accepted by Skyiah (v0.3.1); do not reopen those explanatory choices as unanswered. Specific technical mechanisms and the new chapter-design questions below remain open. The rows below distinguish accepted direction from remaining decisions and implementation.

| ID | Accepted / owner direction through v0.3.1 | Remaining detail / limit |
|---|---|---|
| **R-01** | Epsilon constructs and stabilizes the passage; Multiworld interference affects what he can realize. His creative agency and the limits on erasing occupants/rewriting committed space remain. | Exact physical distortion mechanism, supported arrangements, and material origins. Interference affecting the apparatus output rather than Epsilon's competence is accepted (§3.3a). Not a simulation. |
| **R-02** | Compatible station anchors remain required. Multiworld interference is the primary added explanation for why cleanup access is not just a hallway. Rifts must reach contaminated regions rather than only avoid them. | The isolation-versus-item-access trade-off and exposure-based meaning of proximity are accepted (§3.3a). Specific endpoints, survey-link availability, and power/containment conditions remain unselected. |
| **R-03** | A Check releases an anchored transfer; the cleanup purifies contamination in the Multiworld. Origin, neighbouring influence, and assigned recipient are distinct. Self-items can support a separately earned local Echo. | Real AP mapping, reward transactions, guaranteed featured capability, and exact local cleanup mechanism. Fiction is not implementation proof. |
| **R-04** | Item anchors and station route anchors are separate. Finishing transfers preserves the Crossing. Destination secured and transfers cleared are distinct; unfinished places can be revisited in the future campaign. | Future completion/allocation policy and state transitions. 0.4's all-Checks rule is not silently replaced. |
| **R-05** | First upload grants local warp routing among established breachpoints. Long-range translation is obstructed by interworld attachments. | Exact station dependency graph, stabilization steps, boss/shard relationships. |
| **R-06** | Epsilon needs a portable self-contained substrate and disconnection. Local uploads extend one Epsilon. Raider passage may be real; he discloses a viable exit rather than deceiving the player. | Portable hardware, extraction sequence, player-choice structure, and ending. |
| **R-07** | Separate custody, crew, and life-support records; engineering emergency revival without medical supervision; autobiographical memory chiefly affected. Epsilon genuinely does not know the case. | Scene details, record recovery, returning memory fragments, motive and employer. Fictional medical mechanism only. |
| **R-08** | Required intact boss shards are guaranteed, noncrafting progression items for permanent named access. Smaller fragments and Temporal Shards have separate uses. | Prices, drop quantities, farming, inventory loss, duplication safeguards, exact placement. |
| **R-09** | Repurposed maintenance/sample fabrication; partial scan and art preparation during generation, full scan during transfer, local grant finalized against the current collection. | Hardware interface, prepared variants, budgeted behavior, transactional accounting; no foreign-delivery delay for art. |
| **R-10** | Deliberate timed use, true-pause suspension, remaining lifetime saved, Hub return ends it, normal loadout retained. Boss-linked converter charges an opportunity restored with encounter failure, not duplicate currency. | Durations, general death/refill rules, recipe costs, exact input/expiry semantics. |
| **R-11** | Hostile Echo creatures begin as escaped earlier research reconstructions. Reproduction does not guarantee obedience; later companions are deliberately stabilized and cooperative. | Specific origins, containment failures, actor behavior, and persistence. No random betrayal by an ordinary companion. |
| **R-12** | Role/faction knowledge follows perception and actual communications. Tactical mechanisms can be contested; permanent progress is protected from arbitrary offscreen erasure. | Bounded interaction matrix, sensory ranges, alarms, friendly fire, object handling and recovery. |
| **R-13** | Wind/spike concept uses real positional combat and hazard contact, not a damage-colour matchup. | Explicit boss/physics compatibility ruling before implementation; no silent amendment of Amalgam. |
| **R-14** | Save successful outputs, bound retries, refuse broken required routes, use approved fallback for failed optional art or omit that optional offering before entry. | Numerical budgets, render formats, tools, verification and cache contracts. |
| **R-15** | Bounded first story chapter accompanies 0.5, extended by 0.6 content. | Detailed slices, shard progression/economy schedule, final campaign length. No new 0.4 work order. |
| **R-16** | Multiworld exposure interferes with constructed routes; scientists deliberately increased it for research; current rifts reach contamination to complete stranded transfers. v0.3.1 accepts the suppression/access trade-off, physical-output explanation, controlled-cleanup distinction, and contamination-versus-native-life distinction. | Exact exposure controls, local release operation, and cleanup feedback remain to be designed. Preserve persistent places and allocated transfers; no new compulsory progression meter is implied. |

### 14.1 Remaining chapter-design choices — unselected recommendations

These are the next bounded questions, not newly accepted mechanics or a prerequisite to preserving the concept brief. Skyiah's acceptance of v0.3 occurred before these recommendations.

| Question | Existing basis | Recommendation for discussion, not canon |
|---|---|---|
| How can the abandoned station reach worlds surveyed at different positions? | Multiple world signals and historical surveys are settled; the detailed relation between survey links, station position, and breachpoints is not. | Investigate persistent unfinished survey links: recovered apparatus can reconnect to worlds it already contacted. A survey address is not unrestricted teleportation into that world, and station-side anchor hardware is still required. |
| What does the player physically do to release a Check? | A Check resolves an anchored transfer; exact local hardware, action, and feedback remain open. | Use a consistent short release/readout with varied contextual access: expose an anchor, reconnect its apparatus, move an obstruction, or reach it after a fight. Remote observation is not remote physical intervention. Do not turn every release into a new minigame or decree that every key/terminal needs an identical fight. |
| Which accomplishments advance an expedition and end the campaign? | Securing a destination and clearing transfers are already distinct; established places persist. | Write exact dependencies and a clear player-facing distinction between access secured and transfers remaining. Define the campaign goal against the actual AP rules; do not silently require or waive all Checks, and do not equate repair of the affected research region with cleansing the entire Multiworld. |
| How does defeat/retry work in the physical-world fiction? | Temporary-item lifetime and boss-linked opportunity rules are partly accepted; the general player-defeat explanation is not. | Prefer a simple checkpoint recovery or near-fatal emergency return over adding cloning or universe-wide time reversal. Any physical return must target an already secured refuge and cannot skip forward into an unexplored destination. Preserve completed external transfers; specify reset domains and resource treatment separately. This is not authorization for a new rescue subsystem. |

Faction motives, detailed perception, respawn/drop economics, art budgets, exact Temporal durations, names, memory reveals, and the ending can be selected with their own feature/content slices. They remain open rather than being filled in as if already approved.

### Signal origin is settled; other mysteries remain

The source of the signals is **the other worlds**, not a distress-call/bait/invitation mystery or a signal emitted by the Multiworld faction. The researchers followed multiple world signals and studied multiple worlds. The measurement method and each survey's findings can still be developed without reopening that source.

The station's name, home destination, exact faction name, scientists' degree of culpability, player employer and motive, Epsilon's sentience timeline, surviving crew, final ending, and full boss roster remain open. No automatic malicious-scientists story, universal faction motive, secret innocence, or Epsilon-betrayal twist is selected.

Distinguish history to discover from operating rules needed to build the game. Designers now have the accepted causal rules above; the player can learn them through play rather than an opening exposition dump.

---

## 15. Suggested next design pass — not an active assignment

The causal directions for R-01 through R-07 were accepted in v0.2 and refined by v0.3. R-16's supporting explanations are now also accepted in v0.3.1. Describe one first Crossing from emergency revival through a contaminated region to the guarded terminal and local travel unlock. Use the finite chapter-design questions in §14.1 to identify only the missing rules that journey needs. Do not reopen accepted custody, signal-origin, escape, interference/access, or persistence rules as if unanswered. This is a suggested future design step, not a developer dispatch or an instruction to write an encyclopaedia.

Separately, choose one 0.5 encounter relationship and one 0.6 generated-Echo example for later prototypes. Do not restart the current development agents merely because this brief exists, and do not replace the existing 0.4 plan with it.

A useful later acceptance question is:

> Can the player explain where they went, what Epsilon did, why they had to go physically, what their actions changed, and why the reward belongs to them or to another world?

If that answer is clear, the premise is doing its job.

---

## 16. Provenance, revisions, and cautions for reuse

### 16.1 Primary basis: owner statements in this conversation

The record above consolidates the following directions; these are paraphrase references, not invented quotations.

| Reference | Owner statement preserved |
|---|---|
| U01 | Coloured keys need a useful matching purpose inside their own Zone. |
| U02 | Zones blend Metroidvania, Zelda dungeon, DOOM combat, and Portal environmental reasoning. |
| U03 | Large/small setpieces and large ordinary rooms need many aspects of all four; ordinary connectors should not be overloaded with mini-games and arbitrary props. |
| U04 | That broad overhaul is a major part of 0.5, not another addition to 0.4. |
| U05 | 0.5 includes richer enemy interaction, off-duty activity, and operation of objects/buttons/bombs. |
| U06 | 0.6 adds generated pixel-art companions, side weapons, and at least weapon appearances, prepared when Epsilon generates the Zone. |
| U07 | Setpieces roll out gradually with updates, eventually including whole branches. |
| U08 | Temporal Echoes are briefly usable, unkept items independent of AP Checks; a Keyblade is an example. |
| U09 | A side-branch Temporal wind/pushing item can help exploit spikes around a boss arena. |
| U10 | Effects should do something rather than merely create elemental/status damage weaknesses. |
| U11 | Ordinary Echoes are interpretations such as mods/guns/armour; Temporal Echoes are literal pixel-art recreations of the original item. |
| U12 | 0.5 enemies should have a satisfying death/destruction and drop something useful. |
| U13 | More enemy variety should include occupants beyond robots and a reason the station was abandoned. |
| U14 | Multiworld-native creatures follow breaches/stranded residue; Checks send stuck items onward and Epsilon studies them during transfer. |
| U15 | The player is an information thief, detained in cryo for trial at home, abandoned during the catastrophe, and improperly revived with memory loss. |
| U16 | Epsilon has limited power and jurisdiction, does not know the player's identity, wants to be freed, and cooperates with the player; security knows the detainee. |
| U17 | Raiders/scrappers and later pixel-art Echo creatures provide further populations. |
| U18 | Faction parts can upgrade gear; Temporal Shards can feed a small converter setpiece; Multiworld boss shards can open the next breachpoint. |
| U19 | Zones can have multiple meaningful bosses and lead to real station terminals or raider-occupied locations. |
| U20 | Epsilon originally operates unfinished rift transit between designated station locations. Signals drew researchers toward other worlds. Zones are physically in the Multiworld, mixing ship and neighbouring world, not simulations. |
| U21 | Correction: the signals were the other worlds beyond Multiworld space. Researchers followed different signals to different worlds and studied them; the signal source is not unresolved. |
| U22 | Explicit acceptance of the preceding causal-rule recommendations apart from the corrected signal-source claim: “i agree on everything else tho.” Adopt those recommendations at their stated scope; leave examples, unselected names, unprovided numbers, and technical compatibility work distinguishable. |
| U23 | Refinement: Epsilon makes the route but Multiworld proximity/interference affects it; scientists deliberately increased the interference to study the neighbouring worlds; the player and Epsilon must open rifts near contamination to clear the stranded items/Checks and purify the Multiworld. |
| U24 | Acceptance of the immediately preceding v0.3 explanation: “yep, look good! anythin else we need to iron out?” This accepts the interference/access and controlled-cleanup explanations at their stated scope; it does not approve recommendations introduced afterward. |

v0.1 correctly treated assistant recommendations as proposals. U22 is an explicit later acceptance, so the specific causal recommendations are now labelled accepted direction. Unselected names and illustrative dialogue/setpieces are still not independently commissioned. Exact values, prices, unprovided mechanics, and unresolved technical compatibility are still open. This approval neither adopts every older assistant suggestion nor proves any future feature has shipped.

### 16.2 Existing programme references supplied in the conversation

- **R1 — “Archipepsi — 0.4 huge batch: Blindside Skiff major + Amalgam breadth.”** The supplied plan retains full accepted Amalgam plus explicit 0.4 deferrals (lines 10–19 and 133–170), protects existing saves, and defers swimming (lines 60–64, 261–266). This brief is not an update to that plan's implementation-status table.
- **R2 — First-major approval/addendum.** The supplied owner direction requires reachable featured acquisition, a qualified local Echo, original foreign delivery, AP dependency representation before seed generation, and correct retry/reload behavior (lines 9–40). It authorizes the first major/minor batch and play-before-expansion (lines 68–127).
- **R3 — Prior Amalgam source review within this conversation.** `docs/design-proposals/06_THE_AMALGAM.md` §0.4 and §15.3 identified the no-direct-Status-damage rules and the EXPOSED exception; §32 identified the boss/physics-puzzle restriction. These are recorded compatibility flags, not a new audit of the current repository. Recheck the effective authority before implementing a change.
- **R4 — Room/Zone-state delivery record.** The supplied D-8 report distinguishes player-driven declared state, permanent consequences, and reversible configuration (lines 139–145). Future narrative permanence should not erase those technical distinctions.

No fresh repository audit, running-game test, external research, medical claim about real cryonics, or claim of implemented future content was made for this document. Accepted fiction and design direction are separated from illustrative examples and technical unknowns. Version labels express the owner's roadmap direction, not delivery dates.

### 16.3 Revision history

**v0.1 — 2026-09-23:** First consolidation. Replaces the simulation premise with physical incomplete-rift crossings; records 0.5/0.6 boundaries, room and enemy direction, Echo distinctions, faction drops, station progression concepts, and explicit unresolved questions.

**v0.2 — 2026-09-23:** Corrects the signal source to real worlds beyond Multiworld space and records repeated surveys of different worlds. Incorporates the explicitly accepted causal-rule recommendations into the relevant sections and R-01–R-15 register: bounded creative authoring, persistent Crossings, local warp first, portable Epsilon, custody/emergency revival, transfer/fabrication timing, shard categories, Temporal lifetime/retry, hostile reconstruction origin, bounded enemy knowledge, failure policy, and a bounded 0.5 story chapter. Preserves open names, numerical/economy details, AP and boss compatibility work, and the stopped 0.4 boundary. Original v0.1 is retained unchanged.

**v0.3 — 2026-09-23:** Records the owner's Multiworld-interference refinement: Epsilon constructs the passage, research deliberately amplified outside influence, and present-day rifts must reach contaminated regions to clear stranded transfers. Updates the premise, timeline, authoring boundary, cleanup purpose, and decision register. Adds separately labelled proposals for the isolation/access trade-off, physical-output interpretation, and cleanup-versus-sampling distinction. Preserves v0.2's world-signal origin, persistence, reward timing, escape/custody rules, and 0.4/0.5/0.6 boundaries. Earlier versions are retained unchanged.

**v0.3.1 — 2026-09-23:** Records U24 acceptance of v0.3's suppression/access, exposure terminology, physical-output, and controlled-cleanup explanations. Updates their labels and R-01/R-02/R-16 without reopening v0.2 rules. Adds a clearly unselected, finite chapter-design checklist (§14.1). No new gameplay rule, economy, AP requirement, or development assignment is authorized by that checklist. All earlier files remain unchanged.

**End of brief.**
