# Danger marks: what the runtime says, for the presentation decision

*Arty — 2026-09-28*

**What this is:** the geometry and attachment facts the three candidate
ground marks would need, read from Production's pinned revision
(`c12a72fbc62500f4815d683d66a97f47fe514b06`). **No presentation is chosen
here, and no mark was rebuilt.**

The marks are candidates from Batch 051:
- `fx_charger_lane`, 0.9 × 6.0 m;
- `fx_warned_ground`, 2.40 m across;
- `fx_beacon_range`, 3.4 m across.

Each is smaller than what it marks.

## Two kinds of mark, which must not be confused

- **A warning** says *an attack is coming, from here, this way*. It makes
  no claim about reach, so its size is free. It must not look like a
  boundary, though: a crisp ground outline is read as "outside this line
  is safe", whatever the art intends.
- **A boundary** says *the danger reaches exactly here*. It is honest only
  when it is generated from the runtime's own numbers, anchored where the
  runtime anchors the attack, and shown for as long as that attack can
  still land. A boundary smaller than the runtime reach promises safety
  that does not exist.

At their current sizes, all three marks are warnings, not boundaries.

## The charger's rush

| | At `c12a72f` |
|---|---|
| **Starts** | When the player is within `reach` 14 m with line of sight (`constants.gd:272`, `enemy.gd:700-706`) |
| **Direction** | Fixed when the windup **starts**: flat, toward where the player was, and never re-aimed (`enemy.gd:703`, `:1405-1407`) |
| **Windup** | 0.7 s (`TELEGRAPH_SECONDS["charger"]`, `enemy.gd:94`), announced by `telegraph_started("charge", 0.7)` |
| **Travel** | 13 m/s for 1.1 s: up to **14.3 m** of the charger's origin along that line (`constants.gd:40-41`, `enemy.gd:1015`). A wall ends it early (`:1025`). Rooted or anchored, it does not move at all (`:858`, `:1008`). |
| **What hits** | The player's origin within **2.8 m** of the charger's origin at any moment of the rush (`reach` × 0.2, `enemy.gd:1018`). This is 3D distance, so height counts. |
| **True footprint** | Every point within 2.8 m of the travelled segment: on open ground a **stadium 5.6 m wide and up to 19.9 m long**, including 2.8 m behind the start. It is shorter where a wall stops the rush, and a single point when the charger is held. |
| **Art today** | `fx_charger_lane`, 0.9 × 6.0 m: **about a sixth of the width and under a third of the length** |

**Correction to my own review.** The owner review's D2 plan drew the
rush's reach as the 0.9 m art lane stretched to 14.3 m. It is 5.6 m wide.
*(Corrected 2026-09-28.)*

## The artillery shell

| | At `c12a72f` |
|---|---|
| **Starts** | When the player is 8–34 m away, in line of sight, and the arc to them is clear (`constants.gd:21`, `:277`; `enemy.gd:718-722`) |
| **Target** | The player's position when the windup **starts**. "It lands where you WERE." (`enemy.gd:727`) |
| **Windup** | 0.8 s (`enemy.gd:97`); the shell is then lobbed (`:1409`) and flies 1.6 s (`constants.gd:20`) |
| **The runtime's own mark** | **Already a boundary.** A disc of radius exactly `blast` (3.2 m) at the target, placed when the shell is fired and removed when it bursts (`enemy.gd:1295-1302`, `:1347`, `:1386-1387`) |
| **What hits** | The player's origin within **3.2 m** of the burst, and only if the chest (+1.0 m) or the knees (+0.3 m) can be seen from it. A wall is cover; low cover is not (`enemy.gd:1369-1384`). |
| **Where it bursts** | At the target, or earlier where the arc meets something (`enemy.gd:1353-1357`). In that case the disc marked the wrong place. |
| **Art today** | `fx_warned_ground`, about 1.2 m radius: **a warning at most**. Put in place of the runtime disc, it would promise safety between about 1.2 m and 3.2 m. |

## The beacon

| | At `c12a72f` |
|---|---|
| **What the radius is** | **Not a danger to the player.** Every 1.0 s, each other living enemy within **12 m** of the beacon (origin to origin, 3D) gets `empowered` for 2.0 s: +50% damage (`constants.gd:27-29`, `enemy.gd:1204-1217`, `_hit_for`, `:1428`) |
| **The beacon's own blow** | Damage 2 at 2 m reach (`constants.gd:278`). This is the only direct danger, and it is small. |
| **Art today** | `fx_beacon_range`, about 1.7 m radius: **a marker of the beacon**, not of its range |

A 12 m ring would be a boundary of *enemy empowerment*. It would not mark
where the player gets hurt, and it would promise nothing about the
beacon's own attack.

## What each choice would require (not chosen here)

| Mark | As a warning | As a boundary |
|---|---|---|
| Charger | The direction only, at the charger's feet, for the 0.7 s windup. No ground edge that reads as reach. | A 2.8 m-radius stadium along the fixed direction, 14.3 m of travel, cut at the first wall on that line, shown from windup start to rush end |
| Artillery | Something at the target during the 0.8 s windup, before the runtime disc exists | The runtime's own 3.2 m disc, or art built at exactly 3.2 m on the same anchor and for the same 1.6 s |
| Beacon | The beacon itself (the ring as it is) | A 12 m ring, read as "enemies in here hit harder", under a visibility rule the owner sets |

**Binding seam, for every row:** Production's `telegraph_started(kind,
duration)` and `telegraph_finished(kind, completed)` (`enemy.gd:18-32`).
Its own comment says `completed` means "actually landed"; the code sends
true on release, even for a miss.
