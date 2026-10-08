# G0: the Impact Lab — physics feasibility, D's silence, and the handoff

*Prod — 2026-10-08. The first gate of the post-D crew plan
(`ARCHIPEPSI_POST_D_PLAYTEST_CREW_PLAN_2026-10-07`, `03_PROD_PLAN.md`
P0.1–P0.3).*
- **Branch:** `review/impact-lab-g0`, from readable D (`0e54caab`, the
  branch of the tested build `bb683ce0`).
- **Build:** `3337769d`.
- **References, untouched:** D (`wip/crossing-d-review`, #20) and readable
  D (`review/crossing-d-readability`, #21).

## What changed (what a player experiences)

A small, deliberately plain hall, the **Impact Lab**, with no enemies:
- a kit lever, whose green raceway runs into a blue-accented floor plate;
- a carryable 36 kg weight;
- an orange-banded steel shutter sealing a doorway;
- a glass window showing a stand-in reward behind it.

Set the weight on the powered plate and the plate throws it, on a real
physics arc, into the shutter. The impact breaks the shutter and opens
the doorway. Shooting the shutter does nothing ("NEEDS A HEAVIER HIT").
Shooting through the window stops on the glass.

The shot, footsteps and hit tick make sound again: the lab wires the
game's existing sound bank, which Crossing D never did.

This is a **technical fixture, not the designed room.** That is Dess's
brief, then G1.

## Verdict (P0.2): feasible, narrowly, without touching the player's pads

**The owner's idea works as real physics, with three small pieces and no
framework:**

| Piece | What it is | Lines |
|---|---|---|
| `ObjectPlate` | A separate, narrow device for objects. | ~150 |
| `Flight` | The weight's in-air damping. | ~70 |
| `ImpactShutter` | A rated breakable. | ~170 |

All three are in `godot/scripts/content/impact_lab_parts.gd`.

**`ObjectPlate`:**
- It never looks at a `Player`. The game's `LaunchPad` and `BouncePad`,
  which write `Player.velocity` along a solved player flight, are
  untouched.
- It moves the body through the solver (`ManipulableBody.receive_impulse`).
- A released, settled body arms it for 0.6 s, then it fires.
- Unpowered, it gives a dud click.
- Powering it arms a weight already resting there, so either order works.
- One throw per arrival.
- The arc is solved once, from the plate's centre, on Godot's own
  integrator (gravity, damping, position, per tick).
- It does not aim per object: a weight set down off-centre flies the same
  arc from where it sits, as a catapult would.

**Two engine facts I had to handle, and how:**

1. **The weight brakes in mid-air.** `ManipulableBody` damps every body at
   1.3/s, a stand-in for floor friction so pushed crates stop. In flight
   that brakes a thrown weight to a third of its energy, like syrup.
   - For the flight only, `Flight` removes that damping.
   - It restores it at the first contact with anything but the plate, when
     a hand takes the weight, or on a timeout.
2. **An overlap sensor alone cannot measure an impact.** At 11 m/s a body
   moves 0.18 m a tick. On some ticks the solver has already stopped the
   weight at the face before the overlap is reported, so the "impact" read
   0.9 m/s, or 7.6 m/s one tick late. The shutter instead keeps the last
   three ticks of an approaching body's velocity and uses the speed it
   brought.

**Rated, not bullet-immune.** The shutter uses the game's own
breakable-panel rule (§13.1): a blow under twice the Static Pulse's
damage does nothing, and says so. A body's blow is the kinetic energy it
brings into the face, at 25 J per HP; 40 HP is 1,000 J.
- The plate's throw brings 2,178 J.
- A dropped or pushed weight brings far less.
- A thrown 10 kg crate brings ~600 J: it counts, and two would break it.

### Measured repeatability (the existing-style live check, 40 seeded throws)

The weight was set down anywhere within ±0.6 m of the plate's centre, at
any yaw.

| | Result |
|---|---|
| Throws that break the shutter | **40 of 40** |
| Speed into the face | 11.0 m/s on every throw (2,178 J, **2.2×** the break) |
| Where it struck, from the shutter's centre | across −0.51…+0.59 m, up −0.16…+0.24 m (shutter 3 × 3 m) |
| Throws per set-down | exactly 1 (0 double fires) |
| Weight left out of reach | 0 of 40 |
| Flight | 1.0 s, ~11 m; leaves at 12.4 m/s; peaks 2.3 m up |

The same numbers came out of the source tree, the exported Linux build,
and the Windows executable under Wine.

### Failure cases tried

| Case | Result |
|---|---|
| Unpowered plate | Dud: the plate flickers and clicks, and the weight stays put. |
| Weight held over the powered plate | Not thrown. |
| Player standing on the powered plate | Nothing happens to the player. |
| Pause mid-flight | The weight hangs in the air, then flies on and breaks the shutter. |
| RESTART | Everything comes back: unpowered, line dark, lever at OFF, shutter whole, weight home. |
| Weight out of the hall or under the floor | It comes home. |
| Static Pulse on the shutter | Refused, with "NEEDS A HEAVIER HIT"; costs it nothing. |
| A shot through the window | Stops on the glass. |
| A `lightened` weight (an Echo Status doubling impulses) | Flies twice as hard, overshoots onto the wall above the door, and does not break the shutter. **A design question, not a bug.** |

**Not tried:**
- several objects at once;
- the player standing in the arc (the weight would hit them and land
  short; retry by picking it up);
- a hand-made run, and native Windows.

**Fallback** (P0.2 asks for a comparison): an existing-`Actuator`
lift-and-drop or a pushing piston.
- I did not build it, because the direct throw measured deterministic and
  safe.
- If Dess's room needs a non-ballistic path, either is a day's work on
  pieces the game has.

## D's silence and weak gun feel (P0.3)

**Confirmed at the source:** `crossing_d.gd` never creates a `Tones` bank,
and `Main` connects the shot, footsteps and hit tick to one. So in D
these were silent:
- the player's shot;
- footsteps and landings;
- the hit tick;
- the room ambience.

Only the enemies' own positional voices could sound.

**Reconnecting fixes the silence; it does not fix the weight.** The bank's
own buffers, measured:

| Sound | Length | Peak after its player's volume |
|---|---|---|
| The player's shot (`pulse`) | 50 ms, a 220 Hz square blip | **−20 dBFS** |
| Hit tick (`confirm`) | 30 ms | −32 dBFS (deliberately tiny) |
| Footstep | 90 ms | −26 dBFS |
| An enemy's shot | 90 ms | −10 dBFS, before distance (−6 dB player) |
| Enemy windup | 500 ms | −5 dBFS |

So the player's own gun is about **10 dB quieter and shorter than an
enemy's shot**.

**Recoil** (`Player.kick_viewmodel(0.05)`):
- the viewmodel moves 2 cm up and 10 cm back, and eases home in 0.12 s;
- no camera kick;
- the muzzle light lasts 0.09 s;
- the Pulse fires every 0.35 s.

**Recommendation for G3** (not done here):
- give the player's shot a real report (transient, low body, short tail)
  and a small camera kick that does not move the hit ray;
- add a kill sound;
- then judge the feel before touching damage or HP.

## Handoff

### For Dess (to choose the G1 room)

**What the mechanism can promise:**
- **An object plate** throws a released object along **one fixed arc**,
  to any target point in the room. Tested: ~11 m and 1.0 s, peaking
  2.3 m up.
- **Objects only:**
  - never the player;
  - never a held object;
  - only after it rests there for 0.6 s.
- **Power** comes from any existing control. Both orders work: object
  first, or power first.
- **A rated shutter** opens to a real impact (≥1,000 J, which is 36 kg at
  ≥7.5 m/s into its face) and refuses the Pulse.
  - Glass gives a sightline without a line of fire.
  - Neither is bullet immunity by rule.
- **Dimensions, all physical** (a scale to design to, not a fixed kit):
  - plate 2.0 × 0.25 × 2.0 m;
  - weight 0.45 × 0.6 × 0.45 m, 36 kg (it slows a carrier to 0.85);
  - shutter 3.0 × 3.0 × 0.4 m in a 3 m doorway.
- **Recovery:** a lost object comes home, and RESTART resets everything.

**What it cannot promise:**
- aiming at a moving target;
- a throw through a tight gap if the object can be set down off-centre
  (it lands ±0.6 m wide, the same as its placement);
- an outcome under every Echo Status: `lightened` overshoots, and that is
  your call.

### For Arty (state nodes, no runtime edits needed from you)

**Plate** (colliders: a 2.0 × 0.25 × 2.0 m box):
- blue on its moving parts (chevrons, leading lip), not over the slab;
- states: unpowered dark; powered idle; **arming** (0.6 s ramp);
  **throw** flash; dud flicker;
- a green power terminal where the raceway arrives.

**Shutter** (collider: a 3.0 × 3.0 × 0.4 m box):
- orange on bands and seams, a recognisable casing;
- states: intact; wear (the seams brighten as it weakens); a refused-hit
  flash; a **break** into a few slabs, which collide with the world only.

**Weight:** a neutral 0.45 × 0.6 × 0.45 m carryable.

**Placeholders today:** the plate, shutter and weight are code boxes, and
the lever and raceway are your kit as fitted in D. I edited none of your
files.

## Proof

**The live check** (`godot/tests/impact_lab_check.gd`, `make
godot-impact-lab`) passes 33 checks, driven by real input. In:
- the source tree;
- the exported Linux build;
- the Windows executable under Wine.

**Isolation, all three builds:**
- 0 connection attempts to a stand-in bridge, as launched (15 s) and
  through the whole check;
- the player's three files byte-identical;
- the control connects.

**The two-part Windows delivery under Wine** (both zips unzipped into a
fresh folder whose path has spaces, then `START HERE` double-clicked):
- it joins to the identical executable (`0e006640…`);
- it starts the lab, which is still running at 60 s;
- 0 connections.

**Unchanged and re-run:**
- Crossing D's own probe passes, 148 and 114 checks;
- `make godot-boot` and `make godot-import`;
- the 666 Python tests that scan the Godot scripts and tests (including
  CI coverage).

**A 15 s clip** of a real first-person run, recorded by the engine, with
its sound: `Impact-Lab-run.mp4`, in the delivery.

**Not proven:** whether it is fun, and native Windows. Nobody has played
it by hand.

## Next owner question

Play it with the sound on.
1. Without reading anything, did you work out what the plate is for, and
   was the throw-and-break satisfying to watch?
2. Is a **rated shutter plus glass** an acceptable rule for "breakable
   only by the machine", and is the `lightened` overshoot a fun alternate
   or a flaw?
3. Pick Dess's room concept; G1 builds that one room.

## Stopped here

- No campaign merge.
- No changes to `LaunchPad`, `BouncePad` or `ManipulableBody`.
- No combat work.
- No watchers or check-ins.
- Still held: HB-F4g, HB-F4f, the CK9-F1 sweep, and 0.5.
