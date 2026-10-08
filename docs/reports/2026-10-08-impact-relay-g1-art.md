# G1, art candidate: the Impact Relay with Arty's Batch 065 fitted

*Prod — 2026-10-08.*

**A separate build beside the G1 baseline, for comparison. Not merged.**

| | Branch | Build |
|---|---|---|
| **Art candidate** | `review/impact-relay-g1-art`, from the baseline's head `21b5fb2f` | `df2c7fc7` |
| **G1 baseline** (untouched, PR #27) | `review/impact-relay-g1` | `a3b59c46` |

**Product names:**
- The candidate packages as `Archipepsi-Impact-Relay-Art`.
- The baseline packages as `Archipepsi-Impact-Relay`.
- Condi's launcher installs them side by side as two products, each with
  its two modes.

**Correction to the G1 report.** It judged Arty's older Batch 064 (built
for the player's `LaunchPad`) and found it didn't fit. Her Batch 065 is
built for this room. It is on `claude/archipepsi-art-bloom-g1-2026-10-08`:
the kit is at `eb5516c0`, the delivery head at `be673117`, draft PR #26.
Batch 065 fits, as measured below.

## What is fitted, and what stays exactly as G1 built it

**Mechanics and physics: unchanged, and measured identical.** The seeded
measurement below gives the same outcomes as the baseline, line for line:
- 40 of 40 throws break the shutter, at 11.00 m/s and 2,178 J, striking
  across −0.51…+0.59 m and up −0.16…+0.24 m;
- 11 of 12 crate-and-weight pairs break it, every body ends reachable;
- 30 of 30 jittered throws break it;
- the crate's throw brings 242 J and is refused;
- the heavy-hit lashes take it 40 → 26 → 12 → broken.

These are unchanged:
- the plate's 2.0 × 0.25 × 2.0 m collider and its sensor;
- the shutter's 3.0 × 3.0 × 0.4 m collider, sensors, rating and HP;
- the weight's and the crate's boxes;
- the arc, the 0.6 s arming and the 1.0 s re-arm.

Three non-seeded lines differ by a few centimetres: the `lightened` rest
points, and the arc-hit distance (0.63 m against 0.64 m). Those land after
free bounces, and they move by the same amount with the art files removed
and the same check code. They also vary between two baseline runs:
(−0.79, −11.71) one run, (−0.84, −11.68) another.

### The launcher, `ir_object_launcher`, on the G0 plate

**Mount.** A child of the plate at identity. The kit's −Z is the plate's
throw (north). The plate's code looks (`Slab`, `Deck`, `PowerLamp`) are
hidden; its collider and sensor are G0's.

**Footprint and clearances.** The kit's lips and housing extend to 2.44 ×
2.46 m around the 2.0 m deck, whose top stays at 0.25 m. This was
measured by setting the weight and the crate down at the deck's edges.
- **On the deck**, up to 0.95 m from the centre, they rest on the deck and
  are thrown. Right at an edge they visibly overlap the 0.15 m lip or the
  rear housing: cosmetic only.
- **Past the edge**, at 1.1 m, they tip off onto the floor beside the
  launcher, clear of its visuals and reachable.

**The optional funnel colliders are off.** The GLB's `-convcolonly` lips
and housing import as live bodies, so the fitting removes them. Measured
with them on, they are flat-topped boxes:

| Set down at | With the funnel on |
|---|---|
| Over the lips | The weight and the crate rest *on top of the lips*, at 0.6–0.7 m. |
| Over the housing | They rest on the housing, at 0.7–0.8 m. |

In both cases they are outside the plate's sensor and are never thrown.
That is worse than off. If the funnel is wanted, the lips' inner faces
need to slope (for Arty and Dess).

**Power inlet.** The lever turns 90° to feed east and moves from
(−7, 0) to (−5.5, 1.3). Its raceway then runs east along the floor and
makes **one floor turn** north into the inlet, at plate-local (−0.90,
0.065, +1.26). At the old spot the gland pointed away from the inlet and
needed two turns. This is a layout move, not a mechanic: the lever works
exactly as before.

**States, all read off the plate:**

| Plate | Launcher |
|---|---|
| unpowered | dark: rails, chevrons and power lens idle |
| powered, empty | cocked: rails live, lens lit |
| arming (0.6 s) | rails pulse faster; chevrons 1, 2, 3 light back to front at ⅓, ⅔ and 3/3 |
| `fired` | a 0.12 s flash; the deck kicks 10° in 0.06 s and is back in 0.25 s, only on `fired` |
| re-arming (1.0 s) | the chevrons fade |
| dud | one dim flicker; the lens stays idle |

**Measured in the live check:**
- the states run dark → arming → fired → re-arm → cocked once the plate
  is empty;
- the chevrons light in order (1, then 2);
- the deck kicks to 9.7° and is at rest 15 frames later;
- the lens is lit exactly while powered, within one frame at the pull.

### The seal, `ir_impact_seal`, on the G0 shutter, and the jamb on the wall

**A look-only subclass of G0's shutter.** It changes only G0's two look
hooks, `_paint` and `_debris`. Without the candidate files it is G0's
shutter exactly.

| State | What shows |
|---|---|
| **Wear** | The orange collars brighten as HP falls, held at 0.7–0.9 emission. |
| **Glance** (a refused body, the crate) | The next scuff shows; the collars flicker for 0.15 s. |
| **Refused shot** | A 0.25 s flicker that dims, never brighter. |
| **Broken** | Arty's six slabs fall as six 60 kg bodies that collide with the world only. The core goes with the shutter. **The jamb is on the wall and stays**, an empty frame around the open doorway. |

**Damaged orange stays orange (measured from the render).** Of the seal's
coloured pixels:

| Collar emission | Orange | Yellow |
|---|---|---|
| Intact (0.7) | 100 % | 0 % |
| Worn to 12 HP (0.84) | 100 % | 0 % |
| G0's old 2.4, for comparison | 0 % | 100 % |

**Measured in the live check:**
- the crate leaves one scuff, with the collars never above 0.9;
- the heavy-hit lashes wear the collars to 0.77, then 0.84;
- the break releases six of Arty's slabs, and the jamb is still on the
  wall.

The IMPACT SHUTTER sign moves up and out from the wall, so the jamb's top
bar no longer hides it from an angle.

### The weight and the tote

Arty made neither, so they reuse existing art and keep their G1 boxes.

**The weight** wears `phys_power_cell` from her Batch 043 physics family:
- a MEDIUM carriable;
- 0.34 × 0.6 × 0.34 m with a grip on top, so it fits inside the weight's
  0.45 × 0.6 × 0.45 m box at exactly its height;
- dense machined steel.

**The tote** keeps its placeholder: a thin-walled, open, pale plastic tub.

Dense beside flimsy is the mass lesson. **For Arty:** the power cell is a
`POWER_CELL` class, whose grammar elsewhere is "goes into a socket". In a
room whose first beat is power, that may suggest it plugs into the lever.
A bespoke weight and tote are hers.

**Considered and not used.** `phys_mechanical_part` and `phys_generic`
match the classes better (MEDIUM and LIGHT). Their measured sizes would
have meant changing the weight's and the crate's colliders, which is a
physics change. I tried them, and kept the G1 boxes.

### Pause and restart

- The menu mid-flight holds the weight in the air with the art fitted
  (0.000 m moved), then it flies on and breaks the seal.
- After every RESTART in the check (four of them), everything is back,
  the art included:
  - the launcher dark, its lens idle, its deck at rest;
  - the seal whole with no scuff;
  - the jamb on the wall.

## Proof

**The probe** (`make godot-impact-relay` on this branch; both modes; a
stand-in bridge listening):

| | Source tree | Exported Linux | Windows `.exe` under Wine |
|---|---|---|---|
| Default mode, live check | **96 ok, PASS** | **96 ok, PASS** | **96 ok, PASS** |
| Heavy-hit mode, live check | **5 ok, PASS** | **5 ok, PASS** | **5 ok, PASS** |
| Bridge connections (15 s as launched, plus the whole check) | 0 | 0 | 0 |
| The player's three files | byte-identical | byte-identical | byte-identical |

The baseline's own probe ran 80 + 4. The difference is the art checks.

**The art checks** (`godot/tests/impact_relay_check.gd`):
- fitted, with G0's collider kept;
- no kit collider;
- the one-turn raceway;
- the launcher's states, the chevron order, the kick and the lens;
- the glance scuff and the collar cap;
- the six slabs, and the jamb staying;
- art at rest after every restart.

They sit alongside all of G1's own checks.

**Python.** The packaging test
(`test_every_bundled_binary_is_first_party_or_licensed`) passes now. The
`godot/candidate/` copies are registered as first-party in
`assets/LICENSES.json`; they are byte-identical copies of art already
first-party under `assets/models/`. That was the one failure G1 reported.

**The delivery** is
`Archipepsi-Impact-Relay-Art-df2c7fc7-windows-part1of2.zip` and `part2of2`
(19.6 and 20.1 MB).

**Condi's tools:**
- Stamped from `tools/impact_relay/build-spec.json`; his
  `validate --strict` passes all three packages.
- **In one launcher library, both builds install side by side:**
  - "Impact Relay" (`a3b59c46`) and "Impact Relay, Art Candidate"
    (`df2c7fc7`) are two products;
  - each has its two modes and a verified executable.

**Fresh-folder Windows test, under Wine:**
- the parts, unzipped into a path with spaces, join to sha256
  `fba3d4da…`, matching;
- "1 - START HERE … ART candidate" starts the room with the art-candidate
  banner, and it is still running at 60 s;
- the heavy-hit launcher starts its mode;
- 0 connections.

**In the review zip, not the repository:**
- 19 screenshots and a contact sheet, including the deck kick, the glance
  scuff, the worn seal and the G0-energy comparison;
- `Impact-Relay-ART-run.mp4`: 22 s of a first-person run by real input,
  with its sound.

**What came in from Arty's branch, and what didn't:**
- **Taken:** `assets/models/batch065/impact_relay/` (three GLBs and the
  manifest), byte for byte.
- **Not taken:** the rest of her stack. That is the Bloom and noise
  studies, the Shunter sketch, Batch 064, and the builder
  (`build_impact_relay.py` imports Batch 064's builder; both stay on her
  branch).

**Not proven:** whether the art reads better in play, and native Windows.
Nobody has played it by hand.

## Next owner question

Install both in the launcher and play each with the sound on.
1. Does the launcher read as "this throws things *there*", and the seal
   as "this gives if hit hard enough"?
2. Is the power cell right for the weight, or should Arty make a bespoke
   weight and tote?
3. Should the funnel lips exist, sloped, or not at all?

## Stopped here

- No merge.
- No enemy (no Shunter).
- No new systems and no campaign change.
- No change to the baseline branch or its build.
- No watchers, subscriptions or check-ins.
