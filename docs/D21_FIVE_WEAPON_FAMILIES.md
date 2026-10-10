# D-21 — Five weapon families: roles, honest numbers, overlaps

**Dess → Prod, Arty and Condi, for Skyiah. 2026-10-10.**

This is the design reference for the five-weapon overnight range. It
covers **review-range prototypes only**: no campaign change, no loot,
inventory, ammo or AP schema. These are suggestions for the other lanes,
not blockers on their experiments. The five frozen families are kept; I
found no defect that justifies replacing one.

**Code baseline:** `review/hand-cannon` `da0a859e`, which is Prod's
Heavy Report candidate, mode H. Sources:
- **[ER]** `godot/scripts/gameplay/echo_runtime.gd`
- **[EP]** `godot/scripts/gameplay/echo_projectile.gd`
- **[SC]** `bridge/archipepsi_bridge/schemas/echo.py` (primitive bounds)
- **[K]** `bridge/archipepsi_bridge/schemas/constants.py` (enemy stats)
- **[HC]** `docs/reports/2026-10-10-hand-cannon-candidate.md`

---

## 1. What exists, and what each family would need

| Fact | Value | Ref |
|---|---|---|
| **Static Pulse** (unchanged) | 6 damage every 0.35 s (17.1 per second), hitscan, 40 m, no knockback. Repeats while held. | `player.gd` ~1086-1100 |
| **`hitscan_damage`** | Damage 1–25, pellets 1–16, spread 0–30°, range 5–60 m. Square random spread. **One damage call per pellet; knockback is always 0.** The tracer starts at a fixed camera offset, not the gun's muzzle. One hit confirmation per trigger pull. | [SC] :124-129; [ER] :714-746 |
| **`burst_fire`** | 2–8 shots, 0.04–0.4 s apart, **one burst per press** | [SC] :150-156; [ER] :791-800 |
| **`charge_shot`** | Damage scales from `min` (1–20) to `max` (1–60) over a 0.3–3.0 s charge. Speed is 10–60 m/s, × (0.6 + 0.4 × charge). **An early release fires weaker, never nothing.** | [SC] :160-171; [ER] :806-817 |
| **Projectile knockback** | Via the `knockback_target` modifier, **on enemies only** (`apply_knockback`) | [ER] `_launch`; [EP] `_on_body_entered` |
| **Projectile hitting a movable crate** | **Treated as a wall: it vanishes and the crate doesn't move.** No impulse path exists. | [EP] `_on_body_entered` |
| **The rated rule** | `BreakablePanel` and the Impact Relay's `ImpactShutter` both refuse any single hit under **12**, and break at **40** total | `affordance_nodes.gd` ~177; `impact_lab_parts.gd` ~346 |
| **`DestructibleCover`** | 40 HP; **every** hit counts | `destructible_cover.gd` |
| **Mode H measurements** | Kick 0.196 m and 19.1°; springs settle in 267 ms; **aim unchanged (0.000000°)**; cadence key 0.35, 0.55 or 0.80 s; **still 6 damage a hit** | [HC] |
| **Enemy HP** | scuttler 12, ranged 16, diver 20, melee 24, artillery 30, beacon 36, charger 40, drifter 44, bulwark 90 (blocks 85 % from the front), brute 120 | [K] :1086-1100 |

**Per family, what exists and what would be new:**

| Family | Exists | New in the range (small, review-host only) |
|---|---|---|
| Foundry | Mode H: feel, cadence key, material impacts | Higher damage per hit (§2) |
| Sightline | `hitscan_damage`, one pellet, range 60 | Nothing mechanical |
| Switchback | Hitscan with spread | **Repeat while the trigger is held.** No Echo primitive does this; `burst_fire` is one burst per press. |
| Bulkhead | Pellets and spread | **One damage call per target per trigger**, adding up its pellets (§3, overlap 4). Optional small knockback through the existing argument. |
| Mass Driver | `charge_shot`; knockback on enemies | **A push for movable crates and weights** (`ManipulableBody.receive_impulse`, which already exists) |

---

## 2. Suggested range numbers

All within the schema bounds. These are for the range only, not balance.

| | Damage per hit | Cadence | Damage per second | Range | Spread | Clears the rated rule (≥ 12 per hit)? |
|---|---|---|---|---|---|---|
| Pulse (reference) | 6 | 0.35 s | 17.1 | 40 m | 0 | No |
| **Foundry** | **14** | **0.65 s** | 21.5 | 40 m | 0 | **Yes**, 3 hits |
| **Sightline** | **9** | **0.40 s** | 22.5 | **60 m** | 0 | No |
| **Switchback** | **3** | **0.143 s while held** (7 a second) | 21.0 | 40 m | **3°** | No |
| **Bulkhead** | **8 pellets × 4** (32 point-blank) | **1.0 s** | 32 close, about 12 at 10 m | 20 m | **12°** | **Yes, close up**, if pellets add up per target: ≥ 3 pellets on the panel |
| **Mass Driver** | **6 → 30** over a **1.2 s** charge | about 1.6 s a cycle | about 18.8 at full charge | projectile 18 → 30 m/s | 0 | **Yes**, at ≥ 25 % charge (0.3 s); 2 full shots |

**The cadence ladder** is what makes them distinct in grayscale:
- Switchback, every 0.14 s
- Pulse, every 0.35 s
- Sightline, every 0.40 s
- Foundry, every 0.65 s
- Bulkhead, every 1.0 s
- Mass Driver, a 1.2 s charge plus a release

**Shots to kill (and time, first shot at 0):**

| | ranged 16 | melee 24 | charger 40 | brute 120 |
|---|---|---|---|---|
| Pulse | 3 / 0.7 s | 4 / 1.0 s | 7 / 2.1 s | 20 / 6.6 s |
| Foundry | **2** / 0.7 s | **2** / 0.7 s | **3 / 1.3 s** | 9 / 5.2 s |
| Sightline | 2 / 0.4 s | 3 / 0.8 s | 5 / 1.6 s | 14 / 5.2 s |
| Switchback | 6 / 0.7 s | 8 / 1.0 s | 14 / 1.9 s | 40 / 5.6 s |
| Bulkhead at ≤ 3 m | 1 | 1 | 2 / 1.0 s | 4 / 3.0 s |
| Bulkhead at 10 m (≈ 37 % of pellets land) | 2 | 3 | 4 / 3.0 s | — |
| Mass Driver, full | 1 | 1 | 2 / 1.6 s | 4 / 4.8 s |

Two things this shows:
- **Foundry's 3 hits in 1.3 s fit inside the Shunter's 1.4 s recovery**
  (D-20). It is naturally the gun for punishing that window.
- **Bulkhead's falloff comes only from geometry.** With a ±6° spread on a
  0.9 m wide target, about 100 % of pellets land at 3 m, 71 % at 6 m,
  37 % at 10 m and 16 % at 15 m. No falloff rule is needed.

**Foundry's damage.** Mode H still does 6 a hit, and Prod's open
question is whether that should rise with the cadence. My suggestion:
**14 at 0.65 s.** It sits inside the brief's 0.65–0.8 s, it is the only
hitscan gun that clears the rated 12, and it kills 24 HP in two shots.
That is the "look forward to the next shot" breakpoint.

---

## 3. The five cards

### Foundry: hand cannon
| | |
|---|---|
| **Range** | 5–40 m |
| **Handling** | Single shot every 0.65 s. Big kick that overshoots and settles (mode H). Aim stays true. |
| **Consequence** | Each hit matters: 2 shots for anything up to 24 HP, 3 for 40. |
| **Wins when** | One target, a punish window, a rated panel or shutter (14 ≥ 12). |
| **Bad at** | Swarms (a miss costs 0.65 s), fast small movers, beyond 40 m. |
| **Rooms and enemies** | Ranged, diver, a Shunter in recovery, beacons. Fine against the bulwark from behind. |
| **Legal trick** | Breaks a rated panel or the Impact Relay shutter in 3 hits, an alternate route under the real rule. |
| **Read without a tooltip** | The Pulse can't mark a rated panel; Foundry visibly cracks it. Two shots drop a dummy that took four. |
| **Status** | Feel is built (H). Damage 14 is a proposal. |
| **Smallest test** | A 40 HP dummy at 15 m (3 shots), and a rated panel next to it that the Pulse refuses. |

### Sightline: scout rifle
| | |
|---|---|
| **Range** | 15–60 m |
| **Handling** | Single shot every 0.40 s. Short straight-back snap, fast recovery, no spread. |
| **Consequence** | Steady, forgiving precision: a miss costs only 0.4 s. |
| **Wins when** | Targets are far (40–60 m: beyond the Pulse, and beyond the ranged enemy's own 40 m reach), you track one mover, or you counter-snipe. |
| **Bad at** | Rated gates (9 < 12), close swarms, crate-breaking speed. |
| **Rooms and enemies** | Ranged, artillery (34 m reach), the drifter on the ceiling. Long yards and atriums. |
| **Legal trick** | None of its own, by design. It is reach. |
| **Read without a tooltip** | A distance sign at 55 m whose target only Sightline can hit. |
| **Status** | Uses the existing primitive. Only the presentation is new. |
| **Smallest test** | Targets at 20, 40 and **55 m**, plus one moving target at 30 m. |

### Switchback: automatic carbine
| | |
|---|---|
| **Range** | 3–25 m effective. Spread makes long range readably worse: 3° is ±0.26 m at 10 m and ±0.79 m at 30 m. |
| **Handling** | Hold to fire, 7 a second. A light continuous buzz, a moving part on the gun. **No camera climb that moves the aim.** |
| **Consequence** | Pressure and tracking. Each hit is small (3). |
| **Wins when** | Fast small movers (the 12 HP scuttler at 6.5 m/s, divers), and shredding orange cover: 40 HP falls in about 2 s. |
| **Bad at** | Rated gates (3 < 12), long range, burst damage. |
| **Rooms and enemies** | Scuttlers, swarms, flyers. Mid-size rooms with movement. |
| **Legal trick** | Fastest at clearing `DestructibleCover`, which changes sightlines. |
| **Read without a tooltip** | The marks scatter wider on the far wall than the near one. |
| **Status** | Repeat-while-held is **new in the range host**. Spread exists. |
| **Smallest test** | A target strafing at 10 m, the same target at 30 m, and one orange crate. |

### Bulkhead: scattergun
| | |
|---|---|
| **Range** | 1–8 m. Falloff by geometry (§2). |
| **Handling** | 8 pellets in a 12° cone, every 1.0 s. A heavy upward kick, then a pump-like return, with no ammo or reload. |
| **Consequence** | Huge up close, almost nothing at 15 m. The decision is to close in. |
| **Wins when** | Point-blank against melee, a brute, or a bulwark you've flanked. One-shots anything up to 30 HP. Two shots break orange cover. |
| **Bad at** | Range, rated panels from more than a couple of metres away. |
| **Rooms and enemies** | Tight rooms, corners, ambushes. |
| **Legal trick** | Up close, the pellets add up to one 32 blow: a rated panel breaks in 2 shots. |
| **Read without a tooltip** | One clustered mark on the wall at 2 m, a scatter at 10 m. |
| **Status** | Pellets exist. **Adding up per target is new.** Knockback is optional. |
| **Smallest test** | One dummy at 3, 6 and 10 m with floor distance marks, plus an orange crate at 3 m. |

### Mass Driver: charged kinetic
| | |
|---|---|
| **Range** | 5–30 m. A visible projectile flies: at 20 m that's about 0.7 s at full charge, so you lead moving targets. |
| **Handling** | Hold to charge 1.2 s, release. Strong shove on release, then a short power-down. A tap fires weak (6). |
| **Consequence** | **It moves the world.** Enemy knockback (existing modifier) and, with the new seam, crates and weights. |
| **Wins when** | Shoving a crate or the Impact Relay weight, knocking an enemy off a ledge (the fall-kill plane already exists), opening a rated panel in 2 shots. |
| **Bad at** | Damage per second (≈ Pulse), fast targets, rhythm. |
| **Rooms and enemies** | Physics rooms, ledges, the Impact Relay. Brute or charger at an edge. |
| **Legal trick** | **Push the 36 kg Impact Relay weight into its shutter.** The shutter counts a body's ½·m·v² at 25 J per HP, so a push to 6 m/s brings 648 J (26 HP, counts) and 7.5 m/s brings 1,012 J (breaks it). |
| **Read without a tooltip** | The charge builds visibly. The crate slides. |
| **Status** | Charge and enemy knockback exist. **The body push is the one missing seam.** |
| **Smallest test** | The G0 weight on open floor: measure its speed after a full shot. Plus a rated panel (2 shots) and a tap compared with a full charge. |

---

## 4. Dangerous overlaps

1. **Sightline vs the Static Pulse** is the real hole, more than Sightline
   vs Foundry. Both are single-shot hitscan with a light kick. They
   differ only in **reach (60 vs 40 m), 9 vs 6 a hit, a 0.40 s rhythm,
   and presentation.**
   - Test: if Skyiah can't tell them apart at 20 m but enjoys Sightline
     at 55 m, the family is still worth a slot.
   - If not, tune its rhythm before cutting it.
2. **Sightline vs Foundry.** Kept apart by:
   - the 12 breakpoint: only Foundry clears it;
   - cadence, 0.40 vs 0.65 s;
   - range, 60 vs 40 m;
   - what a miss costs.

   **Keep Foundry's damage per second at or below Sightline's.** At
   0.55 s and 14 a hit (25.5 per second), Foundry would beat Sightline
   everywhere inside 40 m.
3. **Switchback vs Sightline.** Hold vs click, 3° spread vs none, 25 vs
   60 m. One test settles it: at 30 m, Switchback lands roughly half its
   rounds on a 0.9 m target, and Sightline lands all of them.
4. **Bulkhead's stagger. No new stagger is needed.**
   - Its close-range identity is damage density from geometry.
   - If a push is wanted, hitscan already passes a knockback argument to
     `take_damage`; it is just always 0 today. That is a velocity shove,
     not a stun.
   - Don't use `apply_status_on_hit` with `stunned`: that would be an
     unapproved stagger system.
   - A rushing Shunter ignores knockback anyway, because commitment
     overrides it.
   - **Adding pellets up per target** is recommended for three reasons:
     it gives Arty and Prod their "one coherent blast", one hit
     confirmation, and an honest rated outcome. It is the range's one
     real design choice; measure it both ways if cheap.
5. **Foundry vs Mass Driver.** Both deliver a big single hit that opens
   rated things. Kept apart by:
   - instant vs a charge plus travel time;
   - enemies vs the world: **Foundry never pushes anything; the Driver's
     identity is pushing;**
   - the Driver's damage per second staying near the Pulse's.

   **If the body-push seam proves unsafe,** the Driver keeps enemy
   knockback and rated breaks. Report that it's at risk of becoming
   "slow Foundry", and don't fake the push.
6. **Aim truth across all five.** Recoil may move the gun and the camera
   presentation, never the hit ray (mode H's 0.000000°). Switchback's
   inaccuracy is spread, not camera climb. Every tracer starts at the
   **visible muzzle**: hitscan's default offset doesn't, and H already
   replaces it.

---

## 5. For the other lanes (suggestions)

- **Prod:**
  - the numbers in §2;
  - the three small range-host additions (held repeat, adding pellets
    per target, the body push);
  - a rated panel plus targets at 55 m in the range;
  - the smallest test per card;
  - measure the overlaps in §4.
- **Arty: motion signatures that read in grayscale.**

  | Family | Recoil read | Marks |
  |---|---|---|
  | Foundry | Big rock back and overshoot | Hole with a chipped rim |
  | Sightline | Short straight snap | Small, crisp hole |
  | Switchback | Continuous buzz with a moving part | Small, quick marks; no explosion per round |
  | Bulkhead | Heavy kick up, then pump return | **One composite mark plus a few chips** |
  | Mass Driver | Forward creep and accumulator while charging, a big shove, then a sag | A crater or scuff, plus a slide streak on pushed crates |

  Permanent colours keep their meanings: blue movement, green power,
  orange breakable, red enemy.
- **Condi: tails must fit the cadence.**

  | Family | Tail |
  |---|---|
  | Switchback | Under about 140 ms, or a mixed firing loop. **No stacking.** |
  | Sightline | Under 400 ms |
  | Foundry | Up to about 650 ms |
  | Bulkhead | Up to about 1 s |
  | Mass Driver | A 1.2 s charge build, then the release |

  Impact sound follows the material, never the weapon.

---

## 6. Future only: guns and armour from foreign AP items (not designed tonight)

The vision: a Check that holds **another player's progression item** still
sends that exact item to its owner. Separately, Archipepsi could give its
own player a local *interpretation* of it.

The ground rules any later design must keep:
1. **Never duplicate, withhold or delay** the AP item.
2. **Never grant a capability AP logic would need.** Today AP declares
   no capability needs, so a local weapon can't be required for anything
   (`06` §29.5a).
3. **Deterministic for the seed.**
4. **Variants inside these five families,** not new families and not
   replicas of items from other games.

The pipeline already exists: Echo interpretation already turns items into
validated action primitives (`hitscan_damage`, `charge_shot`, …). So the
families could later become constraints on that, without a loot,
rarity, inventory or economy system.

---

## 7. Decisions for Skyiah (after playing)
1. **Foundry:** which cadence, and 14 a hit? Suggested: 0.65 s.
2. **Bulkhead:** pellets adding up per target (opens rated panels up
   close)? Suggested: yes.
3. **Sightline:** keep it if it earns its place at range against the
   Pulse; otherwise retune its rhythm first.
4. **Mass Driver:** if the body push isn't safe tonight, accept enemy
   knockback plus rated breaks for this round?
