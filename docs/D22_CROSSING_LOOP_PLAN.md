# D-22 — The Crossing loop: Forge, Epsilon and Archipelago, reconciled

**Dess → Skyiah, for Prod, Arty and Condi. 2026-10-14. A plan, not an
implementation.** Nothing is merged and no code is changed.

It answers the owner's campaign-structure decision of 2026-10-14, and her
release-scope clarification:

> "For Archipepsi's initial release, the Crossings are the main
> attraction. … the Forge partially fleshed out and genuinely usable,
> with Epsilon participating in Crossing construction. The space station
> should mostly remain grayboxed and placeholder … functional navigation,
> machinery interactions and progression."

**Code read:** the 0.4 team head `claude/archipepsi-0-4-blindside`
`a266d5da`. That branch holds the campaign, bridge and apworld; the
review branches don't touch them. Refs below are relative to its root.

**Story canon read:** `docs/ledgers/post_playtest_v1.0/` (08, 06) and its
`references/RIFT_DIRECTION_v0.3.1_original.md`, cited as **[RIFT]**.

**Labels:**
- **[built]** means read in code.
- **[spec]** means a document.
- **[ruled]** means an owner ruling, quoted.

---

## 0. The answer in five lines

1. **Most of the loop already exists under the name "Zone".** A Zone is
   requested, written by Epsilon, composed, proven, laid out, committed,
   entered, left, resumed and completed. A Crossing is that Zone.
2. **The Forge as specified is an item recomposer, not a
   Crossing-builder, and none of it is built.** The release Forge should
   be a **Crossing-construction console**, assembled from the existing
   Zone pipeline. Its item conversions stay later.
3. **Archipelago decides *which* Checks a Crossing holds.** The player
   and Epsilon decide *where they are and what the place is*. Keep that
   line and the AP contract doesn't change.
4. **Station progress should count *untethered* Crossings.** That counter
   already exists (`completed_zone_count`). Station areas hold **no
   Checks** in this release, so they can never strand one.
5. **The first milestone:** one graybox station area with a Forge, two
   constructed Crossings and one unlocked second area, offline, on the
   existing campaign engine.

---

## 1. What exists today

### 1.1 The Crossing (today's "Zone") pipeline [built]

| Step | Where |
|---|---|
| The player asks for the next Zone (Hub portal). The request carries only `finale: bool`. | `RequestNextZone`, `schemas/protocol.py:2161-2176` |
| Checks are allocated **before** Epsilon is called: a deterministic, seeded pick from the eligible pool. The eligible pool is the Signal Key tiers ∩ AP-missing, minus held, pending and shop ids. One source-game "track" at a time, round-robin. | `campaign.py:474-538`; `T.start_generation`, `schemas/transitions.py:94` |
| **One Zone holds Checks at a time:** "still holds locations; finish or abandon it first" | `transitions.py:100-107` |
| Epsilon writes the Zone, then it is validated, repaired once, or replaced by the deterministic fallback | `epsilon/base.py:81-187` |
| Python composes the topology and proves reachability (base kit, §29.5a, DESS-28) | `campaign.py:237-284`; `topology.py:1767` |
| Accepted → GENERATED, then Godot lays it out, the bridge validates the layout and **commits** it: "a committed layout is replayed, never replaced" | `transitions.py:138, 365`; `layout.py:408` |
| Checks can't be claimed until the layout is committed | `transitions.py:1367-1372` |
| **Leaving:** "The exit does not require every Check … the Zone goes dormant", and the player can come back | `campaign.py:1456-1469` |
| **Resuming:** DORMANT and COMPLETE Zones can be re-entered (COMPLETE re-enters as VISITING, holding nothing). Progress persists in `ZoneProgress`. | `transitions.py:201-236`; `protocol.py:153-260` |
| **Completion:** "a Zone with every assigned Check confirmed completes automatically, wherever the player is." The effects are bookkeeping only: COMPLETE, `completed_zone_count` +1, the track cursor +1. | `transactions.py:194-212`; `transitions.py:1248` |
| **Abandoning** returns unclaimed Checks to the pool | `transitions.py:1283-1306` |
| **The Hub:** one hand-built space with the portal, status board, shop (from 2 completed Zones), Echo terminal, abandon console and Echo Lab | `godot/scripts/hub/hub.gd` |

### 1.2 Epsilon's part [built]

- **Zones.** Epsilon writes the name, theme, designer note and chambers:
  shell, enemies, activities and features. All of it stays inside the
  request's catalogue and budget (`requests.py:127-213`; `claude.py:59-109`).
- **What Epsilon never decides:** Python decides the topology and the
  proof; Godot decides coordinates. "Epsilon never chooses world
  coordinates" (`zone_builder.gd:4-5`).
- **Checks.** At each Check release, Epsilon writes an Echo interpretation
  of the foreign item. The item itself still goes to its owner.
- **Providers:**
  - **fallback**, deterministic, and the default (`__main__.py:56`);
  - **claude**, live, which drops to the fallback when there's no key;
  - mock and sample.
- **[ruled]** "The game owns the requirement; Epsilon names and styles
  within it; a deterministic fallback always qualifies" (D-02,
  `DESS_POST_PLAYTEST.md:994`).

### 1.3 The Forge [spec only, not built]

- **What the spec says.** A Hub-only machine with four conversions
  (Consolidate, Elevate, Recompose, Reclaim), paid in Epsilon Static. It
  remakes Echoes and items, and **never builds Zones**
  (`design-proposals/04_EPSILON_IS_THE_CONTENT.md:941-993`, pinned into
  `06_THE_AMALGAM.md` §18; proposals, "not canon").
- **No code exists.** `forge_constructible` is "Deferred"
  (`mechanics.py:742-780`). There's Blender proposal art (a four-stage
  bench and a seven-family dial).
- **[ruled]** "Approve no Forge or Static acquisition path. For this
  scope, Gear comes only from Archipelago items' Echoes"
  (`DESS_POST_PLAYTEST.md:1285-1287`).
- **The Forge/Static economy** is "not started — decision pending"
  (`HUGE_BATCH_LEDGER.md:911`).
- **The owner's own wish:** "static should let the player re randomize a
  zone, or craft new echoes … OR they can have epsilon use the static to
  re create a zone" (`PLAYTEST_DIAGNOSTIC_RESULT.md:108-112`). 288 of a
  default campaign's 450 items are Static.

### 1.4 Archipelago [built]

- **Regions:** Start → Tier 1 → Tier 2. The only rules are Signal Key
  counts (`apworld/archipepsi/__init__.py:57-123`).
- **Locations:** a fixed id universe of 600; a seed uses
  `location_count` of them (default 450). Options include
  `zone_target_checks` (default 15).
- **Zones aren't in the AP model.** They are created at runtime, after the
  seed exists (`docs/AP_CAPABILITY_LOGIC.md:84-93`).
- **Finale:** 2 keys and 80 % of Checks confirmed (`constants.py:87,
  243-245`).

### 1.5 Story canon that already governs this [ruled / accepted direction]

- **Persistent Crossings.** "completing transfers does not delete a
  Crossing … The player gains a usable part of the station rather than
  losing a dungeon as a reward for finishing it" ([RIFT] §3.4, R-04).
- **Two separate accomplishments.** "Destination secured and transfers
  cleared are separate accomplishments"; "Do not turn 'secure
  destination' and 'all transfers cleared' into one invisible event"
  (`08_STORY_AND_CHAPTER_HANDOFF.md:31`).
- **Checks are release events.** "Completing a Check is the release event
  that sends its original item onward" ([RIFT] :268).
- **Epsilon is a genuine author.** "Epsilon genuinely constructs and
  stabilizes a physical passage … His choices meaningfully shape paths,
  branches, supporting structures" ([RIFT] :150). "Stabilizing commits
  the arrangement to a physical place" (:156).
- **Requirements are fixed before the seed.** "requirements controlling
  access to allocated AP Checks must be declared and proved before seed
  generation. Local keys, new breachpoint shards, bosses, and featured
  Echoes cannot become extra hidden requirements" ([RIFT] :549).
- **Revisits are future direction.** "The future campaign permits
  unfinished-Crossing revisits, while the existing 0.4 all-Checks/abandon
  policy remains until its explicit progression work changes it" (08:31).

---

## 2. The loop, mapped onto what exists

| Owner's step | What it is in the game | Built? |
|---|---|---|
| 1. Explore a station area | A graybox, hand-built area. **No AP Checks** in this release. | The Hub is one area. Others are new (graybox). |
| 2. Activate a Crossing interface | The area's **Forge console**. Reaching and powering it is the area's machinery task. | New, small |
| 3. Construct with the Forge and Epsilon | §3: the player picks a signal; Epsilon drafts; the player accepts or redraws; then commit. | The pipeline is built. The choices and the draft card are new. |
| 4. Enter, explore, fight, release Checks | Today's Zone play | **Built** |
| 5. Complete and untether | §4: **Secure** (reach the destination) and **Untether** (all transfers released). Two visible events. | Completion is built (bookkeeping). The Secure and Untether presentation is new. |
| 6. Unlock the next station area | **Area *n* opens when `completed_zone_count ≥ n − 1`.** Derived, so there's no new save field. | The counter is built; the door is new. |
| 7. Repeat | Any unlocked Forge builds from the shared pool | Built |

---

## 3. Construction: what the player chooses, and what Epsilon does

**The rule that keeps AP intact:** allocation stays exactly as built.
Deterministic, seeded, and drawn from the eligible pool before Epsilon
is called. **The player's choices steer which part of the pool and what
kind of place, never which ids or whether a Check exists.**

### 3.1 Release choices (all safe for Archipelago)

1. **Which world-signal to follow.** Today's track is chosen round-robin.
   The release lets the player pick among tracks that still have eligible
   Checks. Each track is a source game, so this picks the Crossing's
   theme pack, music and world flavour (D-11's pack identity already
   exists).
   - **AP-safe:** every allocated Check is still base-kit reachable, and
     unpicked tracks stay available.
   - **Story fit:** "researchers followed different signals" ([RIFT] :96).
2. **Epsilon's draft: accept, or redraw.** After allocation, Epsilon's
   written Zone is shown as a **draft card**:
   - its name;
   - its designer note, in Epsilon's voice;
   - the number of rooms and Checks;
   - the theme and pack;
   - its notable hazards, machinery and enemies.

   The player **accepts**, which commits it, or asks for a **redraw** (at
   most 2 per Crossing). A redraw re-runs generation **with the same
   allocated Checks** and a new variation seed. It reuses the existing
   PENDING_GENERATION retry path (`transitions.py:388`).
   - This is where Epsilon visibly participates: "He can choose useful
     approaches" ([RIFT] §3.3).
   - **AP-safe:** the same ids, re-proven every time.
3. **Contact level** (*should*, the first cut). Narrow / standard / deep
   changes the Crossing's Check count and room budget around
   `zone_target_checks` (for example ×0.67, ×1, ×1.33, inside the option's
   1–30 bounds).
   - **Story fit:** "the isolation-versus-item-access trade-off" (v0.3.1,
     accepted).
   - **AP-safe:** the count only changes how the pool is spread.

**Not in the release:**
- spending Static (§7, D3);
- picking specific Checks or rooms;
- editing a committed Crossing.

### 3.2 Commit, and becoming playable

```
Forge: pick signal (+ contact) --> allocate (built) --> Epsilon drafts (built)
   --> compose + prove (built) --> DRAFT CARD: accept | redraw (new, at most 2)
   --> Godot lays out --> layout validated and COMMITTED (built: replayed, never replaced)
   --> the Forge's gate opens: enter (built)
```

**After commit:**
- no redraw is possible;
- the Crossing is a persistent place ("Stabilizing commits the
  arrangement", [RIFT] :156).

**Before commit:** the player may walk away. The draft stays held, and
the same draft is offered again, with no free re-roll by leaving. The
player may also **abandon** it (built), which returns its Checks.

---

## 4. Completion and untethering, defined

**"Untether" is defined nowhere in code or spec**; "tether" is only the
grapple verb. This brief proposes a definition that fits the canon.

| Event | Trigger | Effect | Built? |
|---|---|---|---|
| **Secure** | Reaching the Crossing's destination anchor (today's appended exit) | The route is secured and its return access established. The player may leave any time; the Crossing goes DORMANT with what remains. Per [ruled] "Reaching the intended exit completes the Zone's route. It does not require that every allocated Check has been claimed" (`06_THE_AMALGAM.md:2280`). | Bridge: **built**. **Godot's exit is still "Locked until every assigned Check confirms"** (`exit_portal.gd:3-4`), which is a mismatch to fix. |
| **Untether** | Every allocated Check released and AP-confirmed: today's COMPLETE (`transactions.py:194-212`) | The Crossing's foreign connection is fully resolved: "Releasing its item resolves that transfer" ([RIFT] :188). **The place persists and stays revisitable** (R-04): a quiet, settled Crossing, entered as VISITING. **`completed_zone_count` +1, which is what opens station areas.** | Bookkeeping: **built**. The visible untether moment and settling are new. |

**Why the station counts untethered Crossings, not secured ones:**
- it follows the owner's loop exactly ("complete and untether … unlock");
- it is the live 0.4 all-Checks policy, so nothing is silently replaced
  (08:31);
- it fits the one-held-Crossing rule. You leave and resume freely, but
  you finish a Crossing before constructing the next one. So there's no
  need to lift a bridge invariant for the release.

**The untether moment** (presentation, release-required but simple):
- when the last transfer is confirmed, the destination anchor's tether
  visibly releases;
- a short line from Epsilon;
- the Forge back at the station shows the Crossing as *Untethered*;
- the next station door's lamp turns green.

Settling visuals are later ([RIFT] calls them "a possible later
presentation choice").

**Leaving and revisiting:**
- **Unfinished.** Leave through the exit (Secure), a warp station, or
  Return to Station. **Resume from any unlocked Forge** (built:
  `resume_zone_id`). Progress, claimed Checks, shortcuts and the resume
  anchor persist.
- **Untethered.** Re-enter as VISITING (built in the bridge; Godot never
  reads `revisitable`, `hub.gd:356`). **Release: placeholder.** One "past
  Crossings" list on the Forge. *Should*, not must.
- **Release blocker to fix:** return anchors are recomputed on replay, not
  read from the manifest. A measured case moved 5.89 m
  (`docs/RETURN_ANCHOR_PERSISTENCE.md`). Revisits are core now.

---

## 5. Why station progress can't softlock Archipelago

1. **Station areas hold no AP Checks** in this release. Gating non-AP
   content on local state is the safe precedent: the shop is already gated
   on completed Zones and "never starves the allocator"
   (`campaign.py:1921-1958`).
2. **Every unlocked Forge builds from the same shared pool, again and
   again.** Station gating changes *where* you build, never *which Checks
   you can reach*. Area 1's Forge alone can reach every eligible Check.
3. **The finale stays where it is:** offered at any Forge under the
   existing rule (2 keys, 80 %). **It never requires a station area.** So
   a small seed (`location_count` 30 → about 2 Crossings) just leaves late
   areas locked, cosmetically.
4. **Required station routes are base-kit.** Echoes may open optional
   station shortcuts only. Echoes come from other players' items and
   can't be guaranteed: the same principle as §29.5a and DESS-28.
5. **An empty eligible pool** (waiting for Signal Keys from other worlds)
   pauses construction. That is ordinary multiworld waiting, not a
   softlock: AP logic itself says those locations need the keys. The
   Forge says so plainly.
6. **Abandon stays the escape valve.** A broken or disliked Crossing can
   be abandoned (its Checks return) and rebuilt. Abandoning never counts
   as untethering.
7. **Re-entry must keep working.** §0-bis condition 5 and check 25 are
   load-bearing. That's why the return-anchor fix is a release blocker.

---

## 6. Release scope

| | **The initial release needs** | **Placeholder is fine** | **Later station and Forge development** |
|---|---|---|---|
| **Crossings** | The built pipeline, made reliable. The exit fix (Secure = leave). Return anchors persisted. The untether moment. Packs per signal. | Music per pack (one track each, or Condi's sketches). Untether settling visuals. | Hidden Checks (the 5-of-15 split, paper only today). Changing setpieces. Several held Crossings. |
| **Forge** | The construction console: pick a signal, Epsilon's draft card, accept or redraw (≤ 2), commit, resume, the finale entry. | The console is a graybox terminal with a plain screen. The past-Crossings list. Contact level, if time is short. | Item conversions (Consolidate and the rest, B4). **Static as a currency** (redraw cost, re-create a Crossing). The seven-family dial art. |
| **Epsilon** | Drafting and redraw through the existing providers. One release provider decision (D4). | His lines: short text. | Generated visual Echoes (0.6). Richer authorship (D-5 objective selection). |
| **Station** | 3 graybox areas: navigation, at least one machinery puzzle each (reuse G0/G1 parts: plate, impact shutter, lever, lift), the Forge, and a count-gated door to the next area. The Hub's services in area 1. | All art (graybox, D-17 colour signals only). Story: a sentence or two per area. | Authored chapters (revival, the guarded terminal, warp routing). Breachpoints and boss shards. Station Checks (these need pre-seed designation). Inhabitants. |
| **Archipelago** | **Unchanged contract.** The real AP connection in a packaged build (Vera's R2: today's installable build is mock-only). | — | Station Checks, capability declarations (H-AP-GATE). |

---

## 7. Conflicts that need Skyiah's decision

1. **D1 — The Forge's identity.** The spec's Forge is an item recomposer
   that "never builds Zones"; your loop's Forge constructs Crossings.
   - **Proposal:** the Forge *is* the construction bench. Its
     construction mode is the release. The item conversions stay
     specified and later, and the D-16 ruling (no Forge path for Gear)
     stands untouched.
   - **This also supersedes the old guard** "Do not expand … into Forge
     UI, Zone-selection UI" (`AGENT_FRONTIER.md:6411`) for this console
     only.
2. **D2 — What untethering means.** I propose: all transfers released;
   the foreign connection resolved; **the place persists and can be
   revisited**, per R-04.
   - If you meant the Crossing **disappears**, that reverses an accepted
     direction (R-04), and you'd need to say so.
3. **D3 — Static in the release.** The recommended default is **no Static
   cost**: free redraws, at most 2.
   - The alternative: make redraws the first Static sink, which is your
     own 2026-09 wish. That's a new economy rule (B4 is pending), so it's
     yours to approve.
4. **D4 — Which Epsilon ships.** A live LLM provider in a shipped game
   means API keys, cost, privacy and offline play.
   - **Recommended:** ship the deterministic Epsilon as the default, with
     the live provider optional for players who supply a key.
5. **D5 — Progress counts untethered Crossings** (all Checks), with
   "Secure" as a separate visible step. That's recommended, and it matches
   your wording and the live 0.4 policy.
   - The alternative, progress on "Secure", needs several held Crossings
     at once. That lifts a bridge invariant: bigger, later.

**Not conflicts, just facts to carry:**
- "Crossing" is a working name. Code ids stay `zone` (RIFT :143-146).
- Today's code lets Epsilon choose more (room count, enemies) than
  Amalgam §30.1 proposes. §30.1 isn't canon, so the code stands.

---

## 8. The staged plan

### Stage 0 — Decisions and a contract (Dess, docs only)
- Skyiah answers D1–D5.
- Dess writes the **Crossing lifecycle contract**: the Secure and Untether
  events, the draft and redraw transitions, and the station-unlock
  derivation.
- **No schema change in Stage 0.**

### Stage 1 — The vertical slice (the first milestone)
**One playable loop, twice, offline, on the existing campaign engine
(mock AP), in a new isolated campaign save** (no old-save migration).

1. **Station area 1:** today's Hub, reshaped as graybox.
   - Its portal becomes a **Forge console**: pick one of 2 signals, see
     Epsilon's draft card (fallback provider), accept or redraw once.
   - Its services (shop, Echo terminal) stay as they are.
2. **A small Crossing.** The existing pipeline at a slice scale, for
   example `location_count` 30 and about 5 Checks a Crossing, through
   the existing options.
   - The exit is fixed (Secure = leave).
   - Resume from the Forge.
3. **Untether.** The last Check confirms → the tether-release moment →
   back at the station, area 2's door lamp is green and it opens.
4. **Station area 2:** graybox, with one machinery puzzle reusing the
   Impact Relay's plate and shutter on the route, and its own Forge.
   Construct Crossing 2, and stop there.

**Acceptance:**
- **Scripted:** the loop completes twice. Reload mid-Crossing; resume
  lands at the same anchor. Abandon, then rebuild. A redraw keeps the
  same Check ids. Area 2 stays shut until the untether. 0 bridge
  connections beyond mock. No Checks in station areas.
- **Your playtest:** "Did building a Crossing feel like making something
  with Epsilon? Did untethering feel like an achievement? Did the new
  area feel earned?"

**Who does what:**
- **Prod:** the console, the exit fix, the untether hook, the area 2 door,
  the slice save.
- **Dess:** the contract, the draft-card content rules.
- **Arty:** graybox signals only.
- **Condi:** one untether sting (optional).

### Stage 2 — Release-required
- Return anchors persisted in the manifest.
- The real AP connection in the packaged build.
- 3 station areas.
- Contact level.
- The finale entry at the Forge.
- The past-Crossings list.
- The D4 provider setup.
- Default seed scale back to normal.
- Packaging through the launcher.
- A complete-run soak: start → finale, both offline and against a real AP
  server.

### Stage 3 — Later (not release)
- Forge item conversions and Static (B4).
- Several held Crossings.
- Authored station chapters and story (the first chapter, the guarded
  terminal, warp routing).
- Breachpoints and boss shards.
- Station Checks (pre-seed designation).
- Hidden Checks.
- Final art and music.
- Visual Echoes (0.6).

**Kept out of every stage:** new loot or inventory systems, AP schema
changes, any rename of `zone` in code, and merges without your approval.

---

## 9. What to reuse, and what is genuinely missing

**Reuse (built):**
- the whole Zone pipeline: allocation, Epsilon, composition, proof,
  layout commit, enter, leave, resume, complete, abandon;
- `ZoneProgress` persistence;
- `completed_zone_count` as the station unlock;
- the shop gating precedent;
- the Hub as station area 1;
- G0/G1 machinery (plate, impact shutter, lever, lift) as station puzzles.
  This also answers Vera's worry that the bespoke rooms had no home:
  **hand-built work belongs to the station, generated work to the
  Crossings.**
- D-11 theme packs for signals;
- the Echo interpretation at release.

**Genuinely missing:**
1. The Forge console: signal pick, draft card, redraw, commit.
2. The redraw transition (the same allocation, a new variation seed).
3. The exit fix (Godot leaves on Secure).
4. The untether presentation hook.
5. Count-gated station doors.
6. Graybox station areas 2–3.
7. The return-anchor manifest fix.
8. The past-Crossings list.
9. The real AP connection in packaged builds.
10. The D4 provider setup.
