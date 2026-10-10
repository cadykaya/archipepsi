# Five weapons: one range, five ways to shoot

*Prod — 2026-10-10. The overnight five-weapon experiment
(`ARCHIPEPSI_FIVE_WEAPON_OVERNIGHT_2026-10-09`, Prod's assignment). Five
playable firing prototypes in one isolated Windows range. Prototype
numbers, not balance. Placeholder art and sound, labelled as such.*

- **Branch:** `review/five-weapons`, from the hand-cannon candidate
  (`review/hand-cannon`).
- **Build:** `3fc8cf0c`, product `Archipepsi-Five-Weapons`.
- **Not merged.** No campaign change, inventory, ammo, reload or economy.
  The Static Pulse, G1 and the earlier ranges are untouched.

## Play it

Unzip both parts into one folder and run "1 - START HERE … Foundry", or
install them in Condi's launcher. Then:

| Key | Weapon | What it asks of you |
|---|---|---|
| **1** | **Foundry**, heavy hand cannon | One deliberate shot at a time. The gun shoves back 19 cm and rises 19°, a warm flare lights the room, a hot slug streaks out, the target rocks. 15 a hit, one shot per 0.72 s. |
| **2** | **Sightline**, scout rifle | Quick, accurate, light. A short snap (5 cm, 4°) home in 67 ms, a needle-thin fast tracer, a small cold flick. 8 a hit, one per 0.34 s. |
| **3** | **Switchback**, automatic carbine | Hold the trigger. About 7 rounds a second, the gun buzzing and its bolt cycling, tracer specks with a brighter one every third. The spread grows from 1.2° to about 4° as you hold. Track the moving dummy. 3.5 a round. |
| **4** | **Bulkhead**, scattergun | Get close, then commit. Eight pellets in an 11° cone, a big shove (24 cm) and then the pump stroke. One central blast and a few chips where the pellets land, not eight explosions. 4.5 a pellet: 36 up close, about half that at 10 m. |
| **5** | **Mass Driver**, charged kinetic | Hold to charge: an orb grows between the rails, the coils spin and the gun trembles. Release to launch a heavy slug you can see travel (10 frames to cross 10 m). 10–45 damage by charge, and it shoves loose objects. |
| **6** | Heavy Report on the Static Pulse | Exactly as you played it, to compare with Foundry. |
| **0** | The Static Pulse as it ships | For reference. |

**Also:** **M** turns off camera motion (the gun still kicks); **N** mutes
the placeholder sounds; **R** returns you to the mark; **Esc**, then
RESTART, resets every target and mark.

**The range:**
- a metal dummy;
- a 40 HP target that falls when killed and stands up 2.5 s later;
- a gel block (organic);
- a concrete pillar and walls (stone), a steel plate (metal) and a timber
  crate (wood);
- a moving dummy at the back;
- two loose bodies by the right wall for the Mass Driver: a 12 kg crate
  and a 36 kg steel weight.

## What is real, and what is a placeholder

**Real (the engine's own):** every shot is an Echo action fired through
`EchoRuntime`'s primitives:
- Foundry and Sightline: single-pellet `hitscan_damage`;
- Switchback: the same, re-armed while held;
- Bulkhead: eight-pellet `hitscan_damage`;
- Mass Driver: `charge_shot`, including its weaker early release.

The engine decides every hit, its damage and its kill confirmation. The
range holsters the Static Pulse while a weapon is out, and hands it back
exactly when it isn't.

**Real (the range's runtime, Prod's lane):**
- **Movement:** each gun's own recoil springs.
- **The muzzle:** a core and flame tongues, a short dynamic light that
  casts shadows on the heavy guns, smoke left in the world, an
  afterglow.
- **The tracer:** it starts at the visible muzzle and ends at the
  engine's own resolved hit, read back from the engine's tracer, which is
  hidden.
- **The impact, from the surface that was hit:**
  - metal: sparks flying as streaks, a flash of light, a hot dent;
  - stone: chips and dust;
  - wood: splinters;
  - organic: pale fibres that drift and a soft dent, with no sparks and
    no light.
- **Marks:** they persist, aligned to the surface, and ride whatever they
  hit (a moving dummy, a shoved crate). They stay until RESTART; past 160
  the oldest is recycled.

**Placeholders, and labelled on screen:**
- **The guns** are primitive shapes, but five distinct silhouettes with
  moving parts:
  - a revolver;
  - a long scoped rifle;
  - a compact carbine whose bolt cycles;
  - a broad double barrel with a pump;
  - twin rails with coils and an accumulator.

  Arty's silhouettes and layered Glyph flares are not in yet; none had
  landed when this was built. The 3D layers here are designed to sit
  under them.
- **The sounds** are the range's old tones, which you ruled out as
  firearm audio. The screen says "PLACEHOLDER — not SigmAudio". They are
  level-matched (−20 dB RMS, never past −3 dBFS at the peak) so no
  weapon wins by being louder; the recorded clip peaks at −2.4 dBFS. **N**
  mutes them. Condi's SigmAudio renders drop into named slots without
  code changes.

**A seam, honestly.** The Mass Driver's push isn't the engine's: its
projectile frees itself on a wall and pushes nothing. The range follows
the real projectile, and where it lands on a loose body, calls that
body's own `receive_impulse`, the existing API. Measured, a full-charge
slug moves the 12 kg crate 1.57 m and the 36 kg weight 0.25 m.

## What was tested

**`godot/tests/five_weapon_check.gd`: 79 checks**, in the real game by
real input. Keys 1–5 select each weapon, and the screen says so.

**Each weapon, one shot:**
- it fires through its primitive, and no Static Pulse fires;
- it deals exactly the primitive's damage:

  | Weapon | Damage |
  |---|---|
  | Foundry | 15 |
  | Sightline | 8 |
  | Switchback | 3.5 |
  | Bulkhead | 36 (8 of 8 pellets at 4 m) |
  | Mass Driver | 45 (full charge) |

- each tracer runs from the muzzle to the engine's resolved hit, and the
  engine's white beam never shows;
- zero-spread shots land on the crosshair's line, and the aim never
  moves;
- the muzzle light flares, the metal dummy sparks and keeps a mark, and
  the fire sound plays at its matched level.

**Recoil, all five different:**

| Weapon | Shove | Rise | Settled after |
|---|---|---|---|
| Foundry | 0.19 m | 19° | 283 ms |
| Sightline | 0.05 m | 4° | 67 ms |
| Switchback | 0.025 m per round | 1.4° | 83 ms |
| Bulkhead | 0.24 m | 12° | 517 ms |
| Mass Driver | 0.31 m | 6° | 300 ms |

Every semi-automatic is at rest before its next shot can fire.

**Cadence:**
- a held trigger fires Foundry, Sightline and Bulkhead once;
- clicked, they fire at their own pace: 42, about 20 and 60 frames
  apart;
- Switchback fires 7 rounds a second, its spread growing 1.2° → 3.9°.

**Materials:** metal → sparks; stone → chips; organic → fibres, with no
sparks and no light; wood → splinters. A grazing hit on the floor leaves
its mark square to the surface. Not one untagged surface was hit.

**Marks:**
- a mark outlasts the old 8 s fade;
- a mark on the moving dummy rides with it;
- past 160, the oldest are recycled.

**The 40 HP target:** three Foundry shots drop it and the kill confirms.
It stands again at 40 HP, with its marks gone.

**Mass Driver:**
- an early release (0.2 s) still fires, weaker: 15.8 damage;
- a full charge deals 45 and takes 10 frames to arrive;
- the crate is pushed further than the weight.

**Bulkhead:** 36 a shot at 3.5 m, against 18 at 10 m.

**Switching and references:**
- switching mid-charge drops the charge;
- reduced motion keeps the camera still;
- 6 is Heavy Report, at its 22-frame cadence and 6 a hit;
- 0 is the Pulse as it ships;
- taking a weapon out holsters the Pulse again.

**Pause and restart:** the paused menu fires nothing. RESTART brings back
a fresh range, keeps the weapon, clears every mark, and returns the
targets and loose bodies.

**The check bites.** Four sabotages fail it 20 times:
- the Pulse left un-holstered;
- the engine's tracer shown;
- marks fading after 3 s;
- no push.

**No regression:**
- the weapon-feel range's own check (its four treatments and H) still
  passes, with its references unchanged;
- the CI-coverage and packaging tests pass. The silent SigmAudio-loader
  fixtures are now registered as first-party, and the same fix was ported
  to `review/hand-cannon`.

**The probe** (`make godot-five-weapons`) runs five modes, one per
starting weapon, with a stand-in bridge listening: it passes in all three environments:

| | Source tree | Exported Linux | Windows `.exe` under Wine |
|---|---|---|---|
| Each mode starts with its weapon | 5 of 5 | 5 of 5 | 5 of 5 |
| Live check, each mode | **79 ok, PASS** | **79 ok, PASS** | **79 ok, PASS** |
| Bridge connections | 0 | 0 | 0 |
| The player's three files | byte-identical | byte-identical | byte-identical |

**Packaging:**
- Condi's `validate --strict` passes all three packages.
- Her launcher library installs Five Weapons (five modes, Foundry first)
  beside Impact Relay and Weapon Feel.
- **Wine fresh-folder test:** the two parts join to the matching sha256
  (`86f1cc5b…`). Each of the five launchers starts its own weapon and is
  still running at 40–60 s. 0 connections.
- **Python:** the bridge suite passes, 2,143 of 2,143.

**Recorded:** `Five-Weapons-range.mp4`, 31 s with its sound. It shows:
- each weapon firing at several surfaces from the standard distance;
- the carbine tracking the mover;
- the scattergun up close on the 40 HP target;
- the Mass Driver shoving the crate and the weight;
- close-ups of Foundry's marks.

## Not done, honestly

- **Glyph layers and real gun art:** none had landed when this was
  built. The contract (`docs/FIVE_WEAPON_RUNTIME_CONTRACT.md`) gives Arty
  the rig, the muzzle points, the moving parts, the event timings, a
  proposed flipbook folder layout and a mark-texture slot. Wiring the
  flipbooks is Prod's next step when a set lands.
- **SigmAudio:** none had landed. The same contract gives Condi the exact
  file names, events, timing and levels.
- **Not tested here:**
  - Bulkhead pulverising destructible cover;
  - Foundry or the Mass Driver against a rated breakable (the Impact
    Relay's shutter is in G1, not in this range);
  - any of it against live enemies.
- **No stagger, ADS or weak points.** None was asked for, none was added.
- **Balance:** the numbers are first guesses, chosen to make the five
  different, not fair.
- **Feel:** nobody has played it by hand, and nobody has heard real
  audio. Automation proves timing and state, not fun.

## Next owner questions

1. Which of the five do you look forward to firing again, and which feel
   redundant? Dess's cards will help here, if they land.
2. **Foundry against Heavy Report (6):** is the heavier version better,
   or just bigger?
3. Is the Mass Driver's shove the right kind of "changes the world", or
   should it reach further (toppling, rated breakables)?
