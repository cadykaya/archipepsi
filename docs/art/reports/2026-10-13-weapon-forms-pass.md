# Four weapons, two forms each: a comparative pass at the Foundry standard

*Arty — 2026-10-13*

**Status: FORMS FOR REVIEW. Stop for the owner's choice.**
- These are proposed forms in clay, not final models. Nothing is textured, and nothing goes to production until you pick.
- Work is on the isolated art branch. No merges, no campaign changes, and no new systems.
- Prod's branch was only ever run, from a read-only checkout of `review/five-weapons-v3` (`ef157061`). Every swap happened in the capturing process's memory.
- I did not touch the Foundry's gameplay. The playable build with Condi's sounds is Prod's to make. My side of it is a written note, not a message to his session.

**Your direction (Skyiah, 2026-10-13):**
- The Foundry's visual direction is **APPROVED**, and it is the new quality benchmark: detail, texture richness, material quality and believable construction.
- Every other weapon gets its own silhouette, mechanism, personality and material character. Don't make them all look like the Foundry.
- Begin with a small comparative design pass that takes in the latest gameplay feedback, and show the forms before final production:
  - Sightline: a substantial, powerful long-range rifle.
  - Switchback: keep its automatic-fire personality.
  - Bulkhead: room for both the quick scattergun and the heavy shotgun.
  - Mass Driver: a charged kinetic weapon with reduced recoil and a strong mechanical identity.

## What to look at first

| | |
|---|---|
| [WF0: the family at one scale](../review/weapon_forms_2026-10-13/WF0_family_lineup.png) | the approved Foundry and all eight proposals, as left elevations at one orthographic scale and in the same clay |
| [WF1: Sightline](../review/weapon_forms_2026-10-13/WF1_sightline.png) | A Accelerator rifle and B Reservoir rifle |
| [WF2: Switchback](../review/weapon_forms_2026-10-13/WF2_switchback.png) | A Jacketed carbine and B Pan gun |
| [WF3: Bulkhead](../review/weapon_forms_2026-10-13/WF3_bulkhead.png) | A Twin-bore breacher and B Drum gun, each as Breacher and as Sweeper |
| [WF4: Mass Driver](../review/weapon_forms_2026-10-13/WF4_mass_driver.png) | A Rotor driver and B Coil driver, at rest and mid-charge |
| [WF5: from the player's eye](../review/weapon_forms_2026-10-13/WF5_in_range.png) | all eight in Prod's v3 range, in the same frame |
| [FS5: the Foundry firing on v3](../review/weapon_forms_2026-10-13/foundry_v3/FS5_foundry_on_v3.png) | the approved GLB on Prod's corrected runtime, frame by frame |
| [FS6: the Foundry moving on v3](../review/weapon_forms_2026-10-13/foundry_v3/FS6_foundry_moving_v3.png) | strafing and firing |

Each weapon sheet sets A beside B, and shows for each:
- a three-quarter view and a left elevation;
- two stills from Prod's range, swapped in for his placeholder: at rest, then ADS, the variant, or mid-charge;
- what drives it, and the runtime parts it gives Prod;
- its triangle count, a for-and-against, and a recommendation.

## 1. The Foundry on Prod's corrected runtime

The approved GLB works **unchanged** on v3. Captured in the v3 range, with the times logged from Prod's own clocks:

| Event | Time |
|---|---|
| carousel indexes | 0.30–0.48 s |
| gun home | 0.517 s |
| hammer drawn | from 0.60 s |
| hammer cocks | 0.683 s |
| ready | 0.733 s, with about 0.19° of climb still owed |
| aim home | about 1.05 s |

- Three shots landed 44 frames apart.
- Two shots landed while strafing, and both moving parts kept his times.

So the model and its parts follow his corrected readiness and recoil, and need nothing from me before his playable build.

The coordination is a file, `docs/art-requests/2026-10-13-foundry-v3-integration-note.md`. It holds:
- what was checked;
- Condi's cue: the cock at about 0.68–0.70 s on v3;
- the study's five fit questions, still unanswered;
- one new question about the driver's glow material.

**What I could not do:** I don't message Prod's session or run tests in his environment, so I can't confirm the build is in progress. The note is there when he reads it. Firing, recovering, moving and aiming in a playable build with Condi's sounds is still his step, and yours to judge.

## 2. The construction standard the forms share

The Foundry set the bar, so every proposal is built from the same kit, not from boxes:
- plated receivers with lips and a rounded rear;
- top covers held down by screws;
- welded trigger housings, stiffener ribs and bolted service panels;
- clamp bands with ears, and barrel nuts;
- weld beads where parts were joined in the field;
- Epsilon modules in their own dark material, mounted on station hardware, never moulded into it;
- an Echo core seated somewhere you can see it.

The clay is tinted by material class: painted station steel, bare working steel, barrel steel, Epsilon, ceramic, core, patch and fastener. You can read the material character before there is any texture.

## 3. The proposals

| Weapon | A | B | Recommended |
|---|---|---|---|
| Sightline (substantial, powerful, long range) | **Accelerator rifle**, 4,112 triangles. Three Epsilon stator packs clamped down a long barrel and wired back to the receiver. A slab core seated from below. The bolt handle in a left raceway, where the eye sees the stroke. | **Reservoir rifle**, 2,864 triangles. The barrel rides over a long Epsilon reservoir, joined by a station regulator block with a hand wheel. A slab brake. | **A**, trimmed toward 3,600 triangles. B's regulator block could return as A's repair layer. |
| Switchback (keep the automatic personality) | **Jacketed carbine**, 2,280 triangles. A slatted cooling jacket and a ribbed magazine. The feed motor and core on the left. The bolt races in an open LEFT port, so all 7 shots a second are visible. | **Pan gun**, 2,208 triangles. A flat pan on the left whose hub is the Epsilon feed motor, with the core at its centre. A finned barrel. | **B's pan**, with the bolt port moved to the top-left so the stroke stays in view. Choose A if the motion matters more than the silhouette. |
| Bulkhead (scattergun and heavy shotgun) | **Twin-bore breacher**, 2,012 triangles. Two short bores, one muzzle plate, and an Epsilon charger with its core on top, where the eye looks. The Breacher pumps; the Sweeper takes a feed box. | **Drum gun**, 2,580 triangles. One fat bore with a choke, a hooped station pressure drum with a gauge, and an Epsilon compressor beneath. | **A**: both configurations on one body, and the cheapest geometry, which leaves budget for texture. |
| Mass Driver (charged, low recoil, mechanical) | **Rotor driver**, 3,100 triangles. A heavy rotor in a guard cage spins up with the charge, on open twin rails with Epsilon bridges and ceramic insulators. The accumulator glows. | **Coil driver**, 3,032 triangles. Three caged coils along the rails spin together. | **A**: a single flywheel explains why it barely kicks, and nothing else in the family looks like it. |

The Foundry study's provisional band was 2,500–4,000 triangles. Four forms sit outside it: Sightline A above it (4,112), and Bulkhead A (2,012), Switchback B (2,208) and Switchback A (2,280) below it. The low ones have room for the detail a production pass adds; Sightline A needs trimming.

## 4. They fit Prod's runtime by name

Each GLB is laid out in Prod's RangeRig model space, with a `Muzzle` at his muzzle point. Its moving nodes carry the names his rig animates:

| Weapon | Nodes | Driven by (v3) | Checked in range |
|---|---|---|---|
| Sightline | `Handle` | 0.022 m stroke at 0.13 s | the ring sights sit on his ADS line, y 0.075 |
| Switchback | `Bolt` | 0.035 m stroke every shot | ADS line y 0.065 |
| Bulkhead | `Pump`, `Feed` | pump 0.1 m at 0.72 s (Breacher); feed shown for the Sweeper only | his `set_variant` showed and hid `Feed` on both |
| Mass Driver | `Coils`, `Core` | coils spin about the bore with the charge; core glow | the raised post sits on ADS y 0.13; the coils spun and the core lit mid-charge |

Two things the range taught, both now in the note to Prod:
1. **Runtime-owned children stay.** The driver model carries Prod's `ChargeOrb` and `ChargeLight`. A swap that frees them breaks his charge display. The capture now keeps them, and a production model must not remove them either.
2. **`driver/core` glows through `material_override`.** A GLB mesh carries its material on the mesh, so the capture supplies the override. Which way production goes is Prod's call.

## 5. What stays true from the Foundry

The Foundry is the benchmark for:
- detail with a job;
- richer wear and material variation;
- imperfect welds, repairs and manufacture;
- Epsilon technology bolted into battered station equipment;
- function, not decorative glow.

Green still means active power. The lamps on these forms are where a powered state would show.

None of the forms copies the Foundry's revolver silhouette or its brass-and-hammer character. Each one's dominant shape is its own mechanism:
- the Sightline: stators along the line;
- the Switchback: a racing bolt, or a pan;
- the Bulkhead: twin bores, or a drum;
- the Mass Driver: a rotor, or coils.

## 6. What I need from you

1. **One form per weapon:** A or B, or a named mix (for example "Switchback B with A's bolt port").
2. **Whether the Bulkhead's two configurations stay one body.** My recommendation assumes they do, as in Prod's runtime.
3. **Which weapon goes to production first** at the Foundry's texture standard. I'd suggest the Sightline: its brief is the clearest, and it is the furthest from the Foundry in silhouette.

## How it was made (reproducible)

```
# forms, renders, GLBs (and the Foundry reference in the same clay)
blender -b --python tools/blender/build_weapon_forms.py -- OUT [keys...] foundry
# the range stills: copy weapon_forms.gd into a read-only v3 checkout's tests/
godot ... -s res://tests/_arty_weapon_forms.gd -- --five-weapons \
    --weapon=<id> [--variant=breacher|sweeper] --glb=OUT/<key>/<key>.glb \
    --out=OUT/engine --tag=<key>
python3 tools/crossing_capture/weapon_forms_sheets.py OUT SHEETS
# the Foundry on v3
godot ... foundry_study.gd ... --mode=clip|move
python3 tools/crossing_capture/foundry_study_sheets.py v3 CAPDIR SHEETS
```

The review copies of the renders in `renders/` are reduced to 256 colours to keep the package small. The sources regenerate them at full depth.

**Stop.** No final model until you have chosen.

## Correction, 2026-10-13 (after the owner's ruling)

The owner chose Sightline A, Switchback A and Mass Driver A as approved
directions, and Bulkhead A as provisional only (to be revisited). Two
recommendations above are superseded: Switchback B is not the pick (it is
kept as a possible future weapon in the same archetype), and Sightline A
is not to be trimmed toward 3,600 triangles: counts are provisional, and
optimisation waits for in-game profiling of approved designs.
