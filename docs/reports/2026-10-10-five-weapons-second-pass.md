# Five weapons, second pass: heavier, timed, and heard

*Prod — 2026-10-10. Your five-weapon playtest notes, answered in one
updated, isolated range, with Condi's SigmAudio sounds. Prototype
numbers, not balance. Nobody has played this pass by hand or heard it
in the game yet.*

- **Branch:** `review/five-weapons-v2`, on top of the first pass
  (`review/five-weapons`, PR #33), so the diff is only this pass.
- **Build:** `9eb0ce1f`, product `Archipepsi-Five-Weapons`. It replaces the
  first build in Condi's launcher.
- **Not merged.** No campaign change, no inventory, loot, ammo, reload or
  economy. The Static Pulse, G1, the weapon-feel range and the other
  playtests are untouched (Vera's boundary check: no red line crossed;
  the Static Pulse's values and code are byte-identical).

## What to try first

| Key | What changed | Try |
|---|---|---|
| **1 Foundry** | Same 0.72 s rhythm, a much heavier shot. The gun heaves back 28 cm and 29° and holds there for a beat. The view kicks 2.2°. The gun eases home by 0.58 s, the view by 0.65 s, and the cylinder turns as it comes home. The hammer cocks at 0.66 s; ready at 0.72 s. A brighter, harder flash, a pressure ring, smoke. | Click in rhythm. The next shot should be ready right as the hammer cocks, not after a wait. |
| **2 Sightline** | Now a real rifle: 12 a hit (8 before), one per 0.48 s (0.34 before), reach 60 m, the longest of the conventional guns. A hard snap (10 cm, 9°, a 1.1° view kick), a white flash with shadows, a heavier tracer, and the bolt on Condi's two clicks. **Hold RMB to aim:** an open ring sight, 48° zoom. | Turn round: four shots drop the 40 HP target at 35 m; the plate at 55 m rings. |
| **3 Switchback** | Untouched: same rhythm, same spread. **Hold RMB to aim:** tighter (at most 1.8° against 3.9° from the hip) and a calmer gun. **Press 3 again: HARD hip-fire**, a heavier kick and a view that climbs about 0.9° and wanders while you hold, then comes home. | Same burst, hip against aimed, then steady against hard. |
| **4 Bulkhead** | **Two scatterguns. Press 4 again to swap** (a second launcher starts on the Sweeper). **BREACHER:** 10 pellets × 6 every 1.0 s, a huge heave (32 cm, 24°), the pump racked as the gun comes home, the blast shoving loose bodies. Point-blank it drops the 40 HP target in one. **SWEEPER:** 7 × 4 every 0.5 s, box-fed, no pump, lighter. Two shots for the 40 HP target. | Both at the 40 HP target from close, then at 10 m. |
| **5 Mass Driver** | Longer reach, more damage, less kick, as asked. 14–60 damage over a 1.2 s charge (10–45 over 1.1 s before). The kick is 13 cm and 4° (31 cm before), with a heavy, slow heave. **Hold RMB to aim.** It still shoves loose bodies: the crate 2.3 m, the weight 0.4 m. | Charge, aim down the lane and lead the 55 m plate: the slug takes about 0.9 s to get there. |
| **6 / 0** | Heavy Report and the Static Pulse, exactly as before. | For comparison. |

**Also:**
- **M** turns off camera motion (no view climb either).
- **N** turns all weapon sound off.
- **B** puts aiming on V only.
- **Esc → RESTART** resets every target and mark.

## Your notes, one by one

- **Foundry rocks back convincingly.** Each shot is now a timed curve,
  not just a spring: a fast kick, a held peak (the weight), and a slow,
  eased return that dips past rest and settles.
- **Foundry recovers too early.** It used to be home in 0.28 s, then
  waited 0.44 s. Now the gun is home at 0.58 s, the aim at 0.65 s, the
  hammer cocks at 0.66 s, and it is ready at 0.72 s.
- **Separate mechanism, recoil and aim, but connected.** These are
  three clocks, chained and measured on every weapon (table below). A
  click up to 0.15 s early still fires the moment the gun is ready.
- **Sightline the weakest.** It now hits for 12 (8 before), has the
  longest reach, and is the quickest of the semi-automatics. Its kick is
  three times the first pass's, and it aims.
- **Switchback: keep it, try aiming and a harder hip-fire.** Its rhythm
  and spread are unchanged. Both experiments are opt-in: RMB to aim, and
  3 again for hard hip-fire.
- **Bulkhead: undecided.** Both versions are in, on one key.
- **Mass Driver: Sightline-class range, more damage, less kick.** All
  three are done. The charged slug and the shove are kept.
  - **Range** is limited by flight time, not by a cap. The slug flies at
    60 m/s, the `charge_shot` primitive's top speed, so it takes 0.9 s
    to reach 55 m. Faster needs that limit raised, which is Dess's call.
  - **Damage:** 60 for a full charge (45 before).
  - **Kick:** 13 cm (31 cm before).
- **Sound.** Condi's sounds now play, as she delivered them; nothing
  else is level-matched on top. See "The sound" below.
- **Right click.** See the next section.

## Right click: there is a conflict, and it is fenced off

**What RMB does in the campaign.** It fires the first Echo slot
(`fire_echo`), and grapple and tether Echoes live in that slot. A tether
swing even ends the moment RMB comes up (`player.gd`, `_update_swing`).
So aiming on RMB in the campaign would collide with the grapple whenever
one is slotted.

**What this range does:**
- **Aiming lives only in this range.** It is on two input actions the
  range creates for itself at runtime; the project's input map is not
  touched.
- **RMB aims only while the first Echo slot is empty.** In this range
  that slot is always empty, so RMB is free here.
- **If an Echo is slotted, RMB stays the Echo's:** it reaches the Echo
  and never aims, and the screen says "RMB belongs to …". The check
  proves this with a tether equipped.
- **V or a mouse side button always aims.** **B** switches to V only.

**Not decided here:** which button aims in the campaign. That is a
design call for you or Dess, made before aiming leaves this range. Three
options:
- RMB aims and the grapple moves;
- RMB aims only when no grapple is slotted;
- aiming gets its own button.

## The sound

**Condi's set, as she delivered it.** It is all 17 events, 19 WAVs:
the five guns, the carbine's release tail, the Bulkhead pump, the Mass
Driver's charge, held loop, two releases and power-down, and the metal,
stone and organic impacts, with the Mass Driver's own heavier impacts.

**Imported unchanged.** Her folder is kept byte for byte in
`handoff/five_weapon_audio/`, with her sources, projects and
measurements. The game's copies are hash-checked against her
`SHA256SUMS.txt` and played as uncompressed PCM.

**Played the way her `events.json` says.** That means her voice counts,
the A/B carbine rounds, the held loop and its crossfade, the release
fades and her impact rules. Everything plays at one level (−2 dB on
her −21 LUFS masters), so no gun wins by being louder.

**Three gaps, filled for now:**
- The two wooden crates borrow her stone impact.
- The Sweeper plays her Bulkhead shot at pitch 1.1.
- Foundry's visible hammer is on my timing, not hers.

I've asked her for a wood impact, a lighter Sweeper shot and her
ratchet's time (`docs/FIVE_WEAPON_RUNTIME_CONTRACT.md`, "Second pass").
In the recorded clip the mix peaks at −3.1 dBFS, with no sample clipped (after the fix below).

## What was tested

**The check: 108 parts (109 when launched on the Sweeper), PASS in all
three environments, in every launcher mode.** It drives the real game by its real inputs (the mouse
buttons, V, B and the number keys). What it covers:
- **Each weapon:** its damage, its tracer and its hit truth.
- **The three clocks** (in order, no early snap, no dead wait), and the
  view climb coming back to exactly 0.000000°.
- **Condi's event** for each shot, at the one level.
- **Both variant pairs:** Bulkhead Breacher and Sweeper, Switchback
  steady and hard.
- **Aiming:** zoom, kick, tighter spread, still on the crosshair's line.
- **The RMB conflict:** the tether keeps RMB; V and B behave.
- **The long lane:** Sightline reaches 55 m and Foundry does not; the
  Mass Driver's slug flies there; Sightline drops the far target in four.
- **Sound order and levels:** the Mass Driver's full sequence, the
  carbine's A/B rounds and single tail, the Breacher's impacts and pump.
- **Everything from the first pass:** materials, marks, the 40 HP
  target, the pushes, the references, pause and restart.

**The three clocks, measured:**

| | Gun home | Aim home | Last mechanical beat | Ready |
|---|---|---|---|---|
| Foundry | 583 ms | 650 ms | 650 ms, hammer | 733 ms |
| Sightline | 367 ms | 400 ms | 167 ms, bolt | 483 ms |
| Bulkhead Breacher | 700 ms | 767 ms | 900 ms, pump slam | 1000 ms |
| Mass Driver | 633 ms after release | 617 ms | — | — |
| Switchback, each round | 83 ms | (none, steady) | — | 150 ms |

**The probe and the builds** (the source run is the code commit
`026ec19e`; the exported runs are the delivered `9eb0ce1f`, which adds
only the impact-level cap and the launcher names):

| | Source tree | Exported Linux | Windows `.exe` under Wine |
|---|---|---|---|
| Six launcher modes (incl. Bulkhead Sweeper), live check each | **6 of 6 PASS** | **6 of 6 PASS** | **6 of 6 PASS** |
| Bridge connections | 0 | 0 | 0 |
| The player's three files | byte-identical | byte-identical | byte-identical |

**Other checks:**
- **Packaging:** Condi's `validate --strict` passes; her launcher
  installs it with six modes, Foundry recommended.
- **Wine fresh-folder test:** both parts unzipped into a new folder,
  then each launcher double-clicked. The parts join to the matching
  sha256 (`2470e403…`), each of the six launchers starts its own weapon
  (the Sweeper launcher on the Sweeper) and is still running at 40–60 s,
  with 0 connections.
- **Regressions:** the weapon-feel range's own check still passes.
- **Licences:** the packaging test passes, with Condi's files registered.
- **Vera's audio meter** agrees with Condi's numbers. Every gun's fire
  sound peaks at −21.0 LUFS momentary, starts within 1–5 ms of its
  event, and none clips.
- **Vera's boundary check:** AMBER, no RED. The amber items are the
  expected ones: shared plumbing, and the Pulse holstered from the
  range, as in the first pass.

**Two bugs found and fixed on the way:**
- **Springs blowing up.** In a slow-frame render, the stiffer springs
  blew up and threw the camera into the void. A hitch on a real machine
  could have done the same. The springs now step at 240 Hz with a cap on
  the frame length.
- **A clipped mix.** The first recording touched 0 dBFS on the
  Breacher's point-blank shot. Godot's 3D sound lifts a sound above its
  set level when the listener is close (+6 dB at 4 m), so the impact
  landed hot on the shot. Impacts are now capped at their level, so
  distance only ever lowers them.

**The check bites.** Five deliberate sabotages fail it 20 times:
- the view climb never coming home;
- Foundry's recovery back at the old 0.28 s;
- aiming taking RMB from the tether;
- one gun 4 dB louder;
- the variant keys broken.

## Not done, honestly

- **Nobody has played or heard this pass.** The check proves timing,
  order and levels, not feel.
- **Art:** placeholder guns, now with sights, a hammer and a feed box.
  Arty's Batch 068 models and effects are not wired: you asked to test
  feel first, and her design exploration is reworking the guns.
- **Mouse sensitivity is not slowed while aiming.** The player's look
  code is outside this range, and I did not touch it.
- **The Mass Driver's slug speed** is at the primitive's limit
  (60 m/s).
- **Pre-existing:** F and the middle mouse button also fire the
  equipped weapon through the engine's slot, without the range's
  presentation. That was true in the first pass too.

## For you to decide

1. **Bulkhead:** Breacher or Sweeper, or is there a third shape between
   them?
2. **Switchback:** steady or hard from the hip, and does aiming earn its
   place?
3. **Foundry:** heavy enough now, or does the heave need more hang?
4. **Aiming in the campaign:** which button (see "Right click" above).
