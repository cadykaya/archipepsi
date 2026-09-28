# Appendix · the remaining pending groups, the held work, and corrections

*Arty — 2026-09-28*

The images below are existing review images, copied into
`evidence/appendix/` so they open on a phone. Nothing new was designed or
rebuilt for this appendix. Every "at the pin" fact was re-checked tonight
against Production `c12a72f`.

## 1. The late-August candidates

| Batch | What | Status | Evidence | At the pin | The exact missing decision |
|---|---|---|---|---|---|
| **023** | Six landmark **places**, each a hero structure plus the routes round it, one per theme | PENDING, "proposal scale" (`ART_REVIEW.md:3056`) | [`X023_landmarks_eye.jpg`](evidence/appendix/X023_landmarks_eye.jpg) | `landmark` is a content category, but there is no selection field and no footprint rule: `NEEDS_FOOTPRINT` covers `cluster` only (`content_registry.gd:46`) | Are landmarks *places* rather than objects? The 2,500-triangle landmark tier is defined as an **object** budget, and these are places. Req 24 (selection, placement, envelope) is Production's. |
| **024** | Epsilon presentation: six states and a three-stage arc, one hue, below the 0.40 emissive ceiling | PENDING (`:3147`) | [`X024_epsilon_states.jpg`](evidence/appendix/X024_epsilon_states.jpg) | Only `ui/epsilon_voice.gd`, a bark selector, exists. Only `speaking` has a runtime signal. | Approve the six-state language (value, extent, rhythm, aperture), with the arc as extent rather than brightness? `speaking` and `focus` are the tightest pair. The locked installation is not re-asked. |
| **025** | Questionable Goods counter; the Forge bench (idle and working) | PENDING (`:3219`) | [`X025_forge.jpg`](evidence/appendix/X025_forge.jpg), [`X025_forge_vs_shop.jpg`](evidence/appendix/X025_forge_vs_shop.jpg) | The Hub's `shop` anchor exists (`hub/hub_anchors.gd:32, :99`). There is **no Forge** anywhere: no anchor, scene, script or constant. | Approve the counter's "transaction made opaque" identity for the existing shop anchor? Park the Forge until it has a design. |
| **026** | Checkpoint station: three states, no colour | PENDING, "NOT approved" (`ART_FRONTIER.md:1386`) | [`X026_checkpoint_states.jpg`](evidence/appendix/X026_checkpoint_states.jpg) | There is still **no checkpoint entity**, only the player's one spawn slot (`gameplay/player.gd:220, :841`). | Whether a checkpoint entity should exist at all is a design question, and not the art's. Park. |
| **027** | Pickups: coin, health, resource, special, cache, all on one hex mat | PENDING (`:3314`) | [`X027_pickup_silhouettes.jpg`](evidence/appendix/X027_pickup_silhouettes.jpg) | Epsilon Coin and Epsilon Static are real items (`schemas/constants.py:328-329`). There is no health or ammo item. The local-reward kinds list is closed (`local_reward.gd:22`). | Approve the **coin** and **special (Static)** pickups and the shared mat, the two that have real items? Park health, resource and cache: nothing backs them. |
| **028 (the rest)** | breakable, launcher, door mechanism, key receiver, logic indicator, carryable, machinery | PENDING (`:3412`) | `docs/art/review/batch035/A_recognition.png`, after 035-R | These are code-built where they exist | Fold them into A's control-family decision. The `int_carryable` / `phys_generic` overlap is in B. |

## 2. Held: the older projectile art (Batch 008)

- **The hold stands.** The projectiles were passed "as art assets" on 28 Aug
  (`ART_REVIEW.md:1374`). After the 30 Aug A/B, the owner sent them back to
  pending (Production commit `5f1435fe`, "Owner verdict: the authored
  projectiles go back to pending review"). The registry keeps them
  `pending`, so the game draws its own.
  - [`X008_projectile_family_HELD.jpg`](evidence/appendix/X008_projectile_family_HELD.jpg)
- **Art approval does not make them eligible.** Nothing here revisits the
  hold.
- **The genuinely new evidence, stated separately:**
  - On 22 Sept, 051's legibility scene put the three projectiles against a
    pale, a dark and a busy backdrop, with the same rig
    ([`X008_new_evidence_backdrop_busy.jpg`](evidence/appendix/X008_new_evidence_backdrop_busy.jpg)).
  - The combat-effects handoff names the open question: there are "two
    defensible rules, and they cannot both govern". Either Production's
    `reads_apart` governs and 008 is reshaped, or art's rule governs.
    Art's preference is a third: "elongation OR balance OR a declared
    silhouette family".
  - That question is **waiting for you** (`ART_FRONTIER.md:552`). Until you
    answer it, the hold stands.

## 3. Proof-only work, and partial rulings

- **041** (one shell in two themes): a preview demonstration only. There is
  no owner verdict, and nothing to decide.
- **042** (the `deep_space_derelict` theme): proof only. "Nothing here is
  approved." It is not proposed: no catalogue expansion tonight.
- **055** (the course treatment):
  - concrete_facility and neon_transit: **accepted**
    ([before](evidence/appendix/X055_course_room_before.jpg) /
    [now](evidence/appendix/X055_course_room_now_accepted.jpg)). Production
    still has the older textures; that is Prod's catch-up.
  - gothic_stone: **not accepted**. A 0.5 m / 1.5 m bond is to be
    investigated instead.
  - rusted_industrial, temple_ruin and void_glitch: **pending**, with "no
    owner-facing visual evidence yet". No new render round was made
    tonight.
  - temple_ruin's ruling also decides T01 and T05 (E).
- **001 materials:** the void_glitch loudness question is still yours
  (`ART_FRONTIER.md:2225`).

## 4. Corrections and stale records found tonight

**Corrections to my own records:**
- **My audit** (`docs/art/reports/2026-09-28-art-vs-game.md`) said T01 and
  T05's textures were accepted as candidates. For T05, the ruling accepted
  the accent and calmed the floor; it has no candidate sentence. A dated
  correction is added to the report.
- **The frontiers still say "023–030 remain PENDING".** The 029 and 030
  assets were revised as 036-R and 037-R, and both revisions passed. The
  batch015–022 review READMEs still say PENDING, though those batches later
  passed.

**Stale art-lane records** (all left as they are tonight, and listed here):
- `docs/art/theme-packs/COVERAGE.md` and `docs/art/BATCH_043_INTEGRATION.md`
  are out of date.
- The status counts say 13 implemented; the pin has 15.
- The enemy-readiness captions say "not spawnable"; all ten spawn.
- `batch028/README.md` has numbers from before 035-R.
- `junctions_2026-09-13/CAPACITY.json` is stale against the cross's
  manifest.

**Evidence defects** (the frames were kept out of, or labelled in, the
sheets):
- `MACH_switch_disagreeing.png` uses hazard orange.
- The drifter's idle and alert frames are identical.
- The 22 Sept room-kit frames draw greyboxes that Production never built.

**For Production, not an art change:**
- `enemy.gd`'s comment says `completed` means "actually landed", but the
  code sends true on release.
- `BULWARK_COMMIT_SECONDS` is never read, so the bulwark's promised opening
  after a swing does not exist in play.

## 5. Not reviewed tonight, on purpose

- **Approved work that isn't in the game.** That is Prod's catch-up (the
  audit). It is not re-asked here.
- **The menu, the enemy silhouettes and the Epsilon installation.** They are
  approved or locked, and not re-asked.
- **Anything hands-on or integrated.** Every "today" frame is a Production
  diagnostic render at `c12a72f`. Every art frame is a review scene.
