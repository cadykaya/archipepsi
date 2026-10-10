# Hand-cannon candidate: Heavy Report, developed

*Prod — 2026-10-10. The owner played the four weapon-feel treatments and
picked mode 2, Heavy Report, "by far". This develops it into a separate
hand-cannon candidate. **Status: built and measured, waiting on Condi's
SigmAudio cues.** The playable comparison is delivered when the audio is
ready, as asked.*

- **Branch:** `review/hand-cannon`, from the weapon-feel head
  (`6fe82e6c`, build `b8295b6a`).
- **Product:** `Archipepsi-Hand-Cannon`, beside the delivered Weapon Feel
  build in Condi's launcher.
- **Not merged.** No campaign change and no weapon-inventory system. The
  Static Pulse is unchanged.

## What the candidate is

It is **mode H** (key 5) of the weapon-feel range, one fixed target as
before, plus one test surface per material. Modes 1–4 stay exactly as
delivered, as references. Their measurements are line-for-line those of
build `b8295b6a`. The candidate's code is its own
(`godot/scripts/content/hand_cannon.gd`); the treatments driver only hands
it the shot while H is selected.

Each of the owner's five asks:

| Ask | What H does |
|---|---|
| **Stronger physical recoil** | A damped spring per channel, each shot an impulse: shove back, lift, muzzle rise, roll, and the camera's lift, roll and field of view. It overshoots past rest and settles, like a heavy thing in a hand, instead of easing home on a curve. A placeholder revolver (gunmetal frame, barrel, cylinder, wooden grip) replaces the Pulse's transmitter while H is on. |
| **Refined muzzle flash and lighting** | A star core and four flame petals at a random roll and size each shot, for 50 ms. A warm light (7.0) that casts shadows and dies off exponentially in about 0.12 s. Then smoke that stays where the shot left the barrel and drifts up for about a second. |
| **Replace the white tracer** | The Pulse's beam is hidden in H, as it spawns. A hot bullet streak crosses the range at 320 m/s, about 30 ms to the target, with a faint smoke trail that widens and fades. |
| **A slower cadence to test** | Key C cycles one shot per 0.35, 0.55 (default) or 0.80 s. Damage stays the Pulse's 6 a hit, so damage a second falls: 17.1, 10.9, 7.5. The screen shows it. Balance is experimental and only this range sees it. |
| **Impacts by material** | **Metal:** sparks drawn as streaks, a flash of light, a hole with a hot rim that cools. **Stone:** dark chips under gravity and a dust cloud. **Wood:** pale splinters and dust. **Flesh:** a red mist and droplets, no sparks; the new gel block jiggles. Every impact leaves a mark that fades after 8 s (32 at most). |

**The test surfaces.** The range gains a steel plate, a timber crate and
a ballistic-gel block (the flesh stand-in: damageable like the dummy,
never dies, not an enemy). The walls and floor are the stone. The dummy
reads as metal: the sparks you liked on it. They sit left of the line of
fire, so the references' shots and their miss lane are unchanged.

**Hit confirmation** keeps Heavy Report's chunky marker.

## Sound: SigmAudio's, not code's

**No new sound is synthesised for H.** Each cue is a slot filled from
`res://audio/sigmaudio/hand_cannon/`. The handoff to Condi
(`docs/HAND_CANNON_SIGMAUDIO_CUES.md`) names the eight cues:

- the report, `fire`, with variants picked at random;
- its room tail, `fire_tail`;
- a cylinder click when the next shot is ready, `mech_ready`;
- the hit confirmation, `hit_confirm`;
- an impact per material: `impact_metal`, `impact_stone`, `impact_wood`,
  `impact_flesh`, positional at the hit.

The handoff also gives each cue's timing, length and level.

**Until the cues arrive:**
- the report and the hit play Heavy Report's own sounds, and the screen
  labels them as placeholders;
- the other six cues are silent.

**The drop-in is tested.** A fixture folder of silent files proves it:
- `fire_01` and `fire_02` become two variants of the report;
- `impact_metal` fills its slot;
- an unrelated file is ignored;
- missing cues keep their placeholder.

**A correction to the weapon-feel report.** It said "SigmaAudio" was on
no branch. SigmAudio is Condi's external sound-authoring tool (the
toolchain ledgers name it), so it was never going to be code in this
repository. That report is corrected on this branch.

## What was measured

`godot/tests/weapon_feel_check.gd` passes 79 checks. Eighteen of them
cover H. It fires by real input and samples every frame at 60 fps.

| | H | Heavy Report (A) |
|---|---|---|
| Recoil peak | **0.196 m and 19.1°** | 0.168 m and 14.3° |
| Past rest | 0.034 m forward of rest, then back | — (eases home) |
| Every spring at rest | 267 ms (the next shot comes at 550 ms) | 300 ms |
| Muzzle flame | 50 ms | 67 ms (bloom) |
| Muzzle light | 7.0, casting shadows, dark at 117 ms | 5.0, dark at 150 ms |
| Tracer | The Pulse's beam hidden; streak and trail | The Pulse's beam |
| Cadence, held 2.1 s | 0.35 s: 22-frame gaps; 0.55 s: 34; 0.80 s: 48; 6 a hit at each | 22-frame gaps |

**Also checked:**
- **The aim never moves** in H (largest change 0.000000°).
- **Each material reads as itself:** the ray meets the steel plate, the
  crate, the gel or the back wall, the impact is that material's, and a
  mark stays.
- **The gel** takes 6 a hit and jiggles.
- **On the dummy:** metal, the hit confirmed on the shot's frame, 6
  damage.
- **The keys:** key 5 selects H; C steps the cadence and comes round
  after three presses.
- **Leaving H restores the Static Pulse exactly:**
  - its transmitter, light position, range and no shadows;
  - its own feedback handler;
  - its own 22-frame cadence and 6 a hit;
  - every mark cleared.

**The check bites.** With three deliberate sabotages, it failed three
times, once on each:
- a recoil weaker than A's;
- the white tracer left visible;
- the cadence ignored.

**Python:** the CI-coverage and packaging tests pass (13).

**Rendered** (in the review evidence, not the repository):
- H's shot frame by frame;
- close-ups of each material, frames 1, 4 and 30;
- each material's mark, looked at from just aside of the crosshair.

The renders found three problems, all fixed:
- the dust and smoke puffs stayed tiny (a billboard ignores its node's
  scale unless told to keep it);
- the metal mark's glow showed as a square (emission ignores alpha);
- the stone and wood debris was too low in contrast to see.

## Not done yet, on purpose

- **Delivery.** Waiting for SigmAudio's cues, as the owner asked. When
  they arrive:
  1. import them;
  2. run the check;
  3. probe the source tree, exported Linux and Windows under Wine;
  4. run the fresh-folder and launcher tests;
  5. send the two Windows parts and a review zip with a clip with sound.
- **The hand-cannon's art.** The revolver is primitive shapes; a real
  model is Arty's.
- **Not played by hand, and no audio heard.** Numbers and renders are not
  feel.

## Next owner question

When the audio is in: is H the hand-cannon, and which cadence (0.35, 0.55
or 0.80 s)? That decides whether its damage per hit should rise to match.
