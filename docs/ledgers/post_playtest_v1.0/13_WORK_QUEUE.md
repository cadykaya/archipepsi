# 13 — Work inventory and dependency map

All rows are prepared work, not executions. The chosen near-term candidate can stop at CP1/CP2 or include CP4; a full UI implementation must not delay shipping a critical combat/resume repair indefinitely. Future rows require explicit activation. Decisions in `09` block only their affected behavior. No task count below is a claim of added features or completion.

## SETUP

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-START — Preserve and reconcile the integrated reference** | Prod | None | Protected working checkpoint, actual profile/branch/save identity, one ownership note. Original save hashes unchanged; current branch read; no full baseline rerun as ritual. See `00_READ_FIRST.md`. |

| **H-SEAMS — Adopt or repair OV05 shared-seam deliveries** | Dess | H-START | Concise reviewed shared-seam table and named ownership. Correct prior work retained; actual defects/tests identified. See `09_CONTRACTS_AND_DECISIONS.md`. |

## REPAIR

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-ARTILLERY — Target acquisition, shell collision and blast cover** | Prod | H-START | Fair indirect-fire path and occlusion repair. V-01–03; actual open-path positive control; geometry blocks sealed-room attacks. See `03_DELIVERY_PLAN.md`. |

| **H-FLYER-HIT — Visible flyer body and damage volume agree** | Prod | H-START | Correct visual/collider/muzzle/hover transform alignment. V-04 normal camera shots; deliberate misses still miss; matching Art review. See `02_PLAYTEST_FINDINGS.md`. |

| **H-FLYER-AI — Identify and test actual flyer attack states** | Prod | H-FLYER-HIT | Role-specific diagnosis/fix and readable waiting/attacking. V-05 with events/deaths; no endpoint-HP or bot-aim fiction. See `02_PLAYTEST_FINDINGS.md`. |

| **H-RESUME-C — Encounter continuation and compatibility contract** | Dess | H-SEAMS; decisions D-06 | Stable identity/defeat/reset/restoration contract using existing save authority. Bridge state and idempotence cases; old absence explicitly handled. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-RESUME-R — Resume a cleared/part-cleared room fairly** | Prod | H-RESUME-C | Defeated membership restored before perception; safe player restoration. V-06–07 two-process lifecycle; object facts preserved; no farming duplicate. See `03_DELIVERY_PLAN.md`. |

| **H-PRESSURE-C — Live pressure versus explicit persistent release** | Dess | H-SEAMS; decisions D-07 | Revised applicable contract and solvable route fixture. Held output and explicit latching interaction distinguished; no unsolvable stand-and-walk gate. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-PRESSURE-R — Replace misleading step-once plate route** | Prod | H-PRESSURE-C | A readable lever/bolt or genuinely held-pressure route. V-08; actual route and closure/restart; general LATCH retained. See `03_DELIVERY_PLAN.md`. |

| **H-RELEASE-C — Hosted minor goal/release/return contract** | Dess | H-SEAMS | Three room cards and legal reward/alternate-route conditions. Allocation/return/known movement modeled; no secret input sequence. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-UNWEIGHTED — Repair Unweighted meaning and direct pickup** | Prod | H-RELEASE-C | Readable dual-use crate, tuned drive, real reward obstruction and safe return. V-09–10/12; hosted normal inputs and expiry; not only standalone driver. See `03_DELIVERY_PLAN.md`. |

| **H-PASSING — Repair Passing goal, controls, pickup and return** | Prod | H-RELEASE-C | Coherent lift/shuttle room with machine outcome and visible return. V-09–10/12 including baseline jump and alternate entry/claim. See `03_DELIVERY_PLAN.md`. |

| **H-COUNTERFIRE — Identify Counterfire and preserve valid fallback** | Prod | H-RELEASE-C | Main and designed alternate route with understandable causality. V-11; actual occurrence identified; gunner-dead condition does not strand reward. See `03_DELIVERY_PLAN.md`. |

| **H-CIRCUITS — Control/destination visual and semantic mapping** | Arty | H-PRESSURE-C, H-RELEASE-C | Shared matching colour/symbol/action-state family. V-13 on actual lever/cell/receiver/door, no conflicting key/power meanings. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-KEYS — Audit local key payoffs and visibility** | Dess | H-SEAMS | Candidate local key/realized lock audit and targeted defect repair. V-14; distinguish no lock from open/unseen lock; no unjustified global rescope. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-BOMBS — Natural consumable acquisition and discoverability** | Prod | H-SEAMS | Matching current-save diagnosis and normal acquisition/equip/use receipt. V-15; absent versus unnoticed distinguished; no artificial grant as evidence. See `02_PLAYTEST_FINDINGS.md`. |

## UI

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-UI-DATA — One live inventory view over current fold** | Dess | H-SEAMS | Resolved current item/slot/state presentation contract. Mixed/upgrade-only/refused/pending fixtures; no second fold. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-GLYPH-KIT — First menu font/panel/icon asset family** | Arty | H-START | New/copy-based Glyph sources, exports and actual target import trial. V-22 in Godot 4.5.1; metadata/source receipts; originals unchanged. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-3D-SHELL — Four real inward-facing rotating menu pages** | Prod | H-START | Real 3D scene, correct face order and live input mapping. V-18; scene transforms plus actual interacted render; not flat tab squeeze. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-PAUSE — Pause ownership, callbacks and authority races** | Prod | H-3D-SHELL | Paused world with usable menu, preserved other holds and safe in-flight accounting. V-16–17; no game-input leakage or delayed grenade launch/free refund. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-INVENTORY — Usable Glyph/Caster-reference equipment face** | Prod | H-UI-DATA, H-GLYPH-KIT, H-PAUSE | Current inventory/equipment/search/detail/compare with real equip authority. V-19/22; human find/compare/equip and empty/owned/charged distinctions. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-MAP-DATA — Shared known room/gate/circuit map facts** | Dess | H-SEAMS, H-RELEASE-C | Stable names/discovery/current gate projection for two maps and journal. Actual known-state fixtures; no auto-solved gate from possession; no secrets leaked. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-MINIMAP — Always-visible normal-play map with named barriers** | Prod | H-MAP-DATA, H-CIRCUITS | Named readable current location/connectors/colour-coded blockers. V-20; actual green circuit transitions and replay; readable floor convention. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-3D-MAP — Interactive miniature of actual built dungeon** | Prod | H-MAP-DATA, H-3D-SHELL, H-GLYPH-KIT | Rotate/zoom/pan/cutaway actual geometry, names and pulsing blockers. V-20–21; turns/heights real; no actors/colliders/reward scripts cloned. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-JOURNAL — Settings and earned objective/journal faces** | Prod | H-MAP-DATA, H-3D-SHELL | Useful actual current objectives/known discoveries and accurate lifecycle controls. No invented campaign, spoilers or altered abandon policy; page navigation/focus works. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-UI-REVIEW — Integrated spatial menu usability and stability** | Prod | H-INVENTORY, H-MINIMAP, H-3D-MAP, H-JOURNAL | One reusable menu with correct input, readable art and stable selected state. Actual owner task; resize/high-DPI/focus/drag/reload; world clocks stopped. See `10_VERIFICATION_AND_OWNER_REVIEW.md`. |

## ART

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-ENEMY-ART — Distance-readable existing enemy lineup** | Arty | H-FLYER-HIT | Distinct silhouettes/weapon/motion family against current collision bounds. Normal-distance/mixed-light frames; no audio/nameplate required for threat distinction. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-MACHINE-ART — Revised selected-room machinery visual replacement** | Arty | H-UNWEIGHTED, H-PASSING, H-COUNTERFIRE, H-CIRCUITS | Readable machinery/cell/receiver assets with unchanged gameplay boundaries. Real occurrence fit/pivots/collision clearance; source-fixed clipping, no new footholds. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-PACKS — Consume delivered D-11 and finish existing treatments** | Arty | H-SEAMS; decisions D-09, D-11 | Updated stale blocker and small material-pack integration candidates. Exact flat pack table/caches/hazard rules; actual authored pixels visible; approval not fabricated. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-COURSES — Obtain and apply only a selected course treatment** | Arty | H-START; decisions D-10 | Treatment-specific review and source change only after ruling. Before/after in repeated geometry; 18/22 changed pitches disclosed. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

## INHERITED

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-SELF-ECHO — Implement accepted self-addressed local grant contract** | Dess | H-SEAMS; decisions D-01 | Original delivery plus distinct local grant identity/recovery. Self/foreign/retry/reload cases; no cloned AP item. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-QUALIFY — Qualify actual featured function and fallback** | Dess | H-SELF-ECHO; decisions D-02 | Qualified real range/target/slot/function contract and fallback. Recipient/reward semantics and real function tests, not capability-label proof. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-AP-GATE — Pre-seed representation of earned capability access** | Dess | H-QUALIFY; decisions D-03 | Owner-selected AP/progression representation with generated proof. Acquisition reachable before requirement; recipient unchanged; no live-seed rewrite. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-BLINDSIDE — Finish earned Blindside return loop** | Prod | H-QUALIFY, H-AP-GATE | Branch acquisition→useful gantry→commissioned span→Checks→return/restart. Normal continuous player/AP journey; no injected grapple or mandatory walking bypass. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-ATOM-DELIVERY — Resolve grammar and deliver implemented manipulation** | Dess | H-SEAMS; decisions D-04 | Effective grammar or approved bounded representation plus actual earned consumer. Create/fold/equip/activate/qualify persists; no parallel primitive system. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-GRAPHS — Remaining useful graph nodes and signal verbs** | Prod | H-SEAMS | AND/DIRECT/SEQUENCE and five signal verbs as needed by real consumers. Actual input→consequence, override expiry, persistence and refusal. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-STATUS — Remaining supported Status-target behavior and compounds** | Prod | H-SEAMS | Per-target consumers/delivery for remaining kinetic/material/actor/collision/compound work. Behavior in world; no legacy corruption or actor damage substitute. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-MACHINE-LIFE — Power, assembly and repeated lifecycle evidence** | Prod | H-SEAMS | Real powered/constrained occurrence and ownership isolation. Power loss/restoration, occupied/reversing/reset, weld/assembly scope and repeated counters. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-RAIL-BREADTH — Switchable rail network and safe recall** | Prod | H-SEAMS | Physical branch selection and occupied-switch/recall/restoration. Actual track changes; no teleport across uncommissioned link. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-GEAR — Priced Gear/mod and approved transaction consumers** | Dess | H-SEAMS | Selected legal priced domains routed through current fold/equip. Real source-owned effect, clamps, save and transaction; uncosted domains named. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-PERFORMANCE — Measure assembled candidate and bounded recovery** | Prod | H-UI-REVIEW | Actual menu+combat+machinery resource profile and recovery fixes. Main/physics/render separated; lifecycle leak and refusal denominators; no timeout padding. See `10_VERIFICATION_AND_OWNER_REVIEW.md`. |

## 0.5

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-05-ROOM — One four-pillar situation and quieter connectors** | Dess | H-UNWEIGHTED, H-PASSING, H-COUNTERFIRE | Selected authored situation with shared combat/environment/item/traversal relationships. Human choice explanation and usable returns; not four unrelated activity bins. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-COMPOSE — Purposeful room/connector generation and local-key payoff** | Prod | H-05-ROOM, H-KEYS | Generation uses proven relationships and calm connective space. Normal candidate samples include refusals; all Checks retained and local locks meaningful. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-FACTIONS — Bounded nonrobot faction roles** | Dess | H-ENEMY-ART; decisions D-12 | Native Multiworld and raider role briefs alongside security. Distinct purpose/counterplay/appearance; provisional budgets not difficulty claims. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-LIVING — Perception, routines and real world interaction** | Prod | H-05-FACTIONS | One useful noncombat job, faction relationship and actual mechanism interaction. No telepathy; real consequences; protected permanent state and required-item recovery. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-DEATH — Readable faction-appropriate defeat and aftermath** | Arty | H-05-FACTIONS, H-RESUME-R | Distinct defeat visuals/sound cues, bounded debris and safe hit-state integration. Immediate death recognition; cosmetic blast not automatic damage; no blocked passages. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-SALVAGE — Useful drop loop and agreed upgrade sink** | Dess | H-05-DEATH, H-GEAR; decisions D-14 | One priced useful material loop with once-only transactions. Environmental kills/reload uniqueness/pickup recovery; no meaningless scrap counter. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-SHARDS — Named permanent breachpoint progression rewards** | Dess | H-AP-GATE; decisions D-03, D-12 | Guaranteed intact boss shard access distinct from spending materials. No RNG softlock, no revisit fee, declared pre-seed dependence. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-BRANCH — Gradual setpiece branch rollout** | Prod | H-05-COMPOSE, H-05-LIVING | One developing situation spanning rooms with lasting return payoff. Play/revise before expanding catalogue; not three drills joined together. See `06_VERSION_0_5_PROGRAMME.md`. |

## 0.6

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-06-VISUAL — Saved generated weapon-appearance pipeline** | Prod | H-GLYPH-KIT, H-ATOM-DELIVERY | One prepared visual skin on supported behavior with stable saved identity. No pickup-time art stall, no redraw on restart, silhouette/collision agreement. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-SIDE — One real auxiliary weapon** | Prod | H-06-VISUAL | Visible auxiliary implement with supported effects and sockets. Own real action/authority, not a decorative sprite claiming a function. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-COMPANION — One useful generated companion** | Prod | H-06-VISUAL, H-05-LIVING | Bounded cooperative actor with observable action and lifecycle. No arbitrary hostility flip, universal interaction or appearance-defined powers. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-TEMPORAL — Literal temporary source item** | Prod | H-06-VISUAL, H-PAUSE; decisions D-14 | Recognizable temporary item over retained ordinary equipment. Start-on-use, pause/reload remaining time, Hub expiry and independent AP identity. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-CREATURE — Echo-creature population and Temporal remains** | Arty | H-06-VISUAL, H-05-DEATH | Distinct reconstruction actor presentation plus validated behavior/drop identity. Native versus Echo recognizable; actual threat and once-only remains. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-CONVERTER — Temporal-shard workshop and retry opportunity** | Prod | H-06-TEMPORAL, H-06-CREATURE, H-05-SALVAGE; decisions D-14 | Small coherent physical converter with agreed stock/cost/lifetime. Boss retry restores opportunity, not refundable duplicable currency. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-WIND-BOSS — Optional wind/displacement/spike encounter** | Prod | H-06-CONVERTER, H-05-SHARDS; decisions D-13, D-14 | Compatibility-approved positional boss and useful side branch. Actual displacement/contact, viable guaranteed kit, no hidden wind multiplier. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

## STORY

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-STORY-LINKS — Resolve remaining first-chapter operating choices** | Dess | H-SEAMS; decisions D-12 | Finite dependency/route explanation with unresolved choices explicit. World signals/physical interference preserved; no invented caller/simulation. See `08_STORY_AND_CHAPTER_HANDOFF.md`. |

| **H-STORY-FIRST — First physical rift chapter** | Prod | H-STORY-LINKS, H-05-COMPOSE, H-05-SHARDS | Revival→real guarded terminal→local warp foothold. World demonstrates objective, Epsilon limit and lasting access without lore dump. See `08_STORY_AND_CHAPTER_HANDOFF.md`. |

| **H-STORY-RAID — Later raid and Epsilon extraction direction** | Dess | H-STORY-FIRST; decisions D-12, D-15 | Chosen theft target/portable substrate and clear consequences. One Epsilon, actual inhabited endpoints, meaningful possible player escape. See `08_STORY_AND_CHAPTER_HANDOFF.md`. |

## DELIVERY

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-FREEZE — Freeze the selected coherent review candidate** | Prod | H-ARTILLERY, H-FLYER-AI, H-RESUME-R, H-PRESSURE-R, H-UNWEIGHTED, H-PASSING, H-COUNTERFIRE | Source-pinned playable handoff with route/answers/raw logs and exact scope. Full current frontier on one revision; Windows status honest; no unattended jobs. See `10_VERIFICATION_AND_OWNER_REVIEW.md`. |

## Machine-readable use

`data/WORK_QUEUE.json` retains dependencies, decisions, primary lane, detail document, deliverable, evidence and legacy IDs. `data/INHERITED_OV05_QUEUE.json` retains all 85 original children and historical/report versus owner-review scope. They are derivative ledgers, not a new game schema. Update status only from actual execution evidence.
