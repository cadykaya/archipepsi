# Weapon feel: the Static Pulse under three firing-feedback treatments

*Prod — 2026-10-09. An overnight experiment: three treatments and a
baseline, against one fixed target, packed as one isolated review build.
It changes how a shot feels, not what a shot does.*

- **Branch:** `review/weapon-feel`, from the G1 baseline's head
  (`21b5fb2f`).
- **Build:** `b8295b6a`. It packages as `Archipepsi-Weapon-Feel`.
- **Untouched:** the G1 baseline (`review/impact-relay-g1`, build
  `a3b59c46`) and the art candidate (`review/impact-relay-g1-art`, build
  `df2c7fc7`). Neither branch nor build is changed. The weapon-feel range
  is a third product beside them in Condi's launcher.
- **Not merged.** No campaign change, no new enemy, no new weapon system.

## Two names that aren't in the repository

**"The Echo hand-cannon".** No weapon by that name exists. I used the
**Static Pulse**: the left-click weapon the player always holds, with the
handheld viewmodel, muzzle light and tracer. Damage and rate of fire are
`Constants`' (6 a hit, one shot per 0.35 s).

The nearest Echo is the fixture campaign's **Arc Bolt**: a hitscan on the
first Echo slot, 9 a hit, 0.8 s cooldown. I didn't use it. The Static
Pulse's feedback is connected by a signal, so a treatment can replace it
without touching shared code. An Echo's kick and flash are written inside
`EchoRuntime`, which every Echo and the campaign share. Changing them
would be a G1 and campaign modification. If the hand-cannon means the
Arc Bolt, the winning treatment can be ported to it as a separate change.

**"SigmaAudio".** Nothing by that name is on any branch. The sounds come
from the game's own procedural bank, `Tones`: each treatment's report and
hit sound is a recipe rendered by `Tones._synth` (22,050 Hz, 16-bit) and
played through a player that `Tones._make_player` makes. No audio engine
was built, and no recorded audio was added.

## What is built

- **The range** (`godot/scripts/content/weapon_feel.gd`). `--weapon-feel`,
  or the export's `weapon_feel` feature. It is isolated through
  `ReviewIsolation` as G1 is: no bridge connection, none of the player's
  files written.
  - A 12 × 26 m concrete hall with dim overhead light, so a muzzle flash
    shows.
  - The game's own `Player` stands on a firing mark.
  - **The fixed target** is the Echo Lab's own dummy,
    `LabFixtures.LabDummy`, unchanged, 10 m down range. It absorbs and
    counts damage and never dies. The Lab hits it through `Enemy`'s
    interface; the range also enrols it as `damageable`, which is what
    the Pulse asks for. The back wall is 22 m away, for misses.
  - The overlay shows the treatment and a running "damage taken · shots ·
    hits" counter. Keys **1–4** switch treatments in play;
    `--feel=baseline|a|b|c` picks the one it starts in. RESTART keeps the
    treatment. Esc pauses.
- **The treatments** (`godot/scripts/content/weapon_feel_treatments.gd`).
  They answer the two signals the shot already emits, `fired_pulse` and
  `hit_confirmed`, and nothing else. Every treatment's numbers are one
  table in that file (`SPEC`).
  - **The baseline is the game as it ships.** The player's own feedback
    handler stays connected: `kick_viewmodel(0.05)` and
    `muzzle_flash(1.6, …)`. The `pulse` and `confirm` tones play as
    `Main` wires them.
  - **A, B and C** disconnect that one handler while they are selected
    and do the feedback themselves. Switching back reconnects it.
  - **The view jolts; the aim never moves.** The camera feedback uses
    only three things, and none of them turns the line of sight, so the
    next shot's ray is this one's:
    - `v_offset`, which shifts the picture, not the camera;
    - a roll about the line of sight;
    - the field of view.
- **Not changed:** `Player`, `EchoRuntime`, `Tones`, `Hud`, `LabDummy`,
  `Constants`, and every G1 file. The HUD's own crosshair punch on a hit
  and the dummy's own red flash run in all four treatments.

## The four treatments

| | Baseline | A · Heavy report | B · Crisp snap | C · Echo resonance |
|---|---|---|---|---|
| **Recoil** | 0.10 m back and up | 0.16 m back, 0.05 m up, barrel 14° up, 3° roll | 0.07 m back, 5° up | 0.11 m back, 8° up, 2° roll |
| **Recovery** | 0.12 s, eased | 0.30 s, settles past rest and back | 0.08 s, snaps home | 0.22 s, smooth |
| **Camera** | none | lifts 3.5 cm, rolls 1.2° (alternating), FOV +3°, back in 0.24 s | lifts 1.2 cm, back in 0.06 s | FOV −2° (a pull *in*), back in 0.18 s |
| **Muzzle light** | 1.6, pale blue, 0.09 s | 5.0, warm, wider, 0.14 s | 3.0, cold white, 0.04 s | 3.0, cyan, flares twice (the echo), 0.18 s |
| **Muzzle bloom** | none | a warm fireball, 0.05 s | a small white ball, 0.03 s | a cyan ring opening from the barrel, 0.18 s |
| **Firing sound** | the 50 ms square blip | a low falling boom under a noise blast, 420 ms | a hard crack and a bright ping, 120 ms | a sweeping tone that repeats twice, quieter, 75 ms apart, 360 ms |
| **Impact** | the tracer only | 18 sparks under gravity and a warm splash of light, 0.3 s | a small puff and a white glint, 0.12 s | a ring that opens on the surface, 0.3 s |
| **Target** | its red flash | also rocks back 7°, springs home | also rocks 2°, quick | also rocks 3°, smooth |
| **Hit confirmation** | the crosshair punch and a tiny tick | a chunky warm X and a low knock | a thin white X and a bright tick | a ring around the crosshair and a two-note chime a beat after the hit |

## What was measured

**The live check** (`godot/tests/weapon_feel_check.gd`, 61 checks) fires
by the input a tester presses. It samples every frame at 60 fps for
0.75 s from the shot, so times are ±17 ms. Each row is the peak on the
shot's frame, and the time until it is back at rest for good.

| | Baseline | A | B | C |
|---|---|---|---|---|
| Viewmodel offset | 0.102 m, rest at 117 ms | 0.168 m + 14.3°, rest at 300 ms | 0.072 m + 5.0°, rest at 67 ms | 0.114 m + 8.2°, rest at 217 ms |
| Camera | — | 0.035 m, 1.2°, +3.0° FOV, rest at 233 ms | 0.012 m, rest at 67 ms | −2.0° FOV, rest at 183 ms |
| Muzzle light | 1.6, dark at 100 ms | 5.0, dark at 150 ms | 3.0, dark at 50 ms | 3.0, **two** flares, dark at 183 ms |
| Muzzle bloom | — | gone at 67 ms | gone at 33 ms | gone at 183 ms |
| Impact effect | — | at the ray's end, gone at 317 ms | gone at 133 ms | gone at 317 ms |
| Target rock | — | 7.0°, still at 233 ms | 2.0°, still at 117 ms | 3.0°, still at 233 ms |
| Hit marker | (HUD's own) | gone at 167 ms | gone at 100 ms | gone at 233 ms |
| Report starts | shot frame | shot frame | shot frame | shot frame |
| Hit sound starts | shot frame | shot frame | shot frame | **50 ms** after |

- **The hit confirms on the shot's own frame in all four.** C's chime is
  delayed on purpose (0.06 s; the 60 Hz timer lands it at 50 ms).
- **Every treatment is back at rest before the next shot can fire**
  (350 ms). A is the closest, at 300 ms.
- **The baseline is the shipped feedback to the frame.** The kick is
  (0, 0.02, 0.10) and home in 0.12 s; the light is 1.6, fading over
  0.09 s; the colour and range are as built; both tones play; nothing
  else moves.

**The sounds**, read from their samples:

| Cue | Length | Sample peak | Player gain | Peak as played |
|---|---|---|---|---|
| Baseline pulse | 50 ms | −12.0 dBFS | −8 dB | **−20.0** |
| Baseline confirm | 30 ms | −15.9 | −16 | −31.9 |
| A report | 420 ms | −1.9 | −5 | **−6.9** |
| A hit | 120 ms | −2.6 | −9 | −11.6 |
| B report | 120 ms | −1.7 | −8 | **−9.7** |
| B hit | 40 ms | −6.3 | −12 | −18.3 |
| C report | 360 ms | −2.5 | −8 | **−10.5** |
| C hit (chime) | 300 ms | −7.0 | −12 | −19.0 |

None clips. The first version of A's report did clip at full scale; the
check caught it, and the mix was scaled down.

> **A caution for the comparison: loudness.** Every treatment's report is
> louder than the baseline's. A is 13 dB louder; B and C are about
> 10 dB louder, close to G0's measured enemy shot (−10 dBFS).
>
> - Measured over the recorded clip, the average level per treatment
>   is: baseline −32 dB, A −23, B −32, C −27.
> - A louder shot tends to feel better simply because it is louder. When
>   you compare, it may help to ask of A: "is it better, or only
>   bigger?"
> - If one wins on loudness alone, matching levels is a one-number
>   change per cue, in `SPEC`.

**The same weapon under all four.** The check proves it, not just the
numbers:

- **Rate of fire:** the trigger held 2.1 s at the target gives 6 shots
  in every treatment. They fall on the same frames, 22 apart: the 0.35 s
  cooldown, in whole 60 Hz frames.
- **Hit points:** all six shots land on the same point in all four.
- **Damage:** 6 a hit, every shot a hit, 36 in all, in all four.
- **A miss** into the back wall: no hit, no damage and no rock in any
  treatment. A, B and C put their impact exactly where the ray ends.
- **The aim never moves** during any treatment's jolt (largest change
  0.000000°). The target's collider never moves when its figure rocks.
- **Switching:**
  - 1–4 switch, and the screen says which treatment is on.
  - The player's own handler is connected only in the baseline.
  - Switching mid-recoil puts everything back at rest at once.
  - The paused menu fires nothing.
  - RESTART keeps the treatment.
- **The check bites.** With a deliberate sabotage, the check failed 10
  times, on the aim, the hit points, the rate of fire, the damage and
  the miss. The sabotage was one real aim kick and a slower cooldown
  added to the treatments, applied and then reverted.

## Proof

**The probe** (`make godot-weapon-feel`). It runs four modes, one per
starting treatment, with each mode's live check measuring all four
treatments. A stand-in bridge listens on the bridge's address.

| | Source tree | Exported Linux | Windows `.exe` under Wine |
|---|---|---|---|
| Each mode starts in its treatment | 4 of 4 | 4 of 4 | 4 of 4 |
| Live check, each mode | **61 ok, PASS** | **61 ok, PASS** | **61 ok, PASS** |
| Bridge connections (15 s as launched, plus every check) | 0 | 0 | 0 |
| The player's three files | byte-identical | byte-identical | byte-identical |

**Python:** the packaging test passes (10 of 10); the full bridge suite
re-run follows in the next commit. The one failure G1 had
(`test_every_bundled_binary_is_first_party_or_licensed`, the
`godot/candidate/crossing_kit/` copies) is fixed here. The fix is the art
branch's own registration line, ported. The boot suite passes.

**The delivery:**
`Archipepsi-Weapon-Feel-b8295b6a-windows-part1of2.zip` and `part2of2`
(19.6 and 20.0 MB). It has four launchers:
- "1 - START HERE … Baseline";
- "2 … A Heavy report";
- "3 … B Crisp snap";
- "4 … C Echo resonance".

**Condi's tools:**
- Stamped from `tools/weapon_feel/build-spec.json`; `validate --strict`
  passes all three packages.
- **In one launcher library, three products install side by side,** each
  with a verified executable:
  - "Impact Relay" (`a3b59c46`), two modes;
  - "Impact Relay, Art Candidate" (`df2c7fc7`), two modes;
  - "Weapon Feel" (`b8295b6a`), four modes.
- The baseline mode is the bare launch. That way the launcher lists
  exactly the four modes and no duplicate "plain executable" entry.

**Fresh-folder Windows test, under Wine:** pending (running when this
was written; the result follows in the next commit).

**In the review zip, not the repository:**
- `Weapon-Feel-four-treatments.mp4`: 16 s, first person, by real input,
  with its sound. Each treatment fires three single shots, then holds the
  trigger for a second.
- A contact sheet of each treatment's shot, frame by frame (before, then
  frames 0, 1, 2, 4, 8 and 12), and the frames themselves.
- The check's log.

**Not proven:**
- how any of it feels: nobody has played it by hand;
- native Windows.

## Next owner question

Play the four with the sound on, ideally with the volume set once and
left alone.

1. Which treatment is most satisfying to fire? Or which *parts* of
   each? The channels are independent numbers, so a mix (say B's recoil
   with A's impact) is a table edit.
2. Is the winner for the Static Pulse only, or should it also reach the
   Echo hitscans (the Arc Bolt)? The second means changing `EchoRuntime`.
   That is a campaign change and its own task.
3. Is a kill confirmation wanted in the comparison? The dummy never
   dies, so none of the four shows one.

## Stopped here

- No merge, and no campaign change.
- No change to G1, the art candidate, or their builds.
- No enemy, and no new weapon system.
- No watchers, subscriptions or check-ins.
