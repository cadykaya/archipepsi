# Hand-cannon candidate: the SigmAudio cues it needs

*Prod → Condi, 2026-10-10. For the hand-cannon candidate (mode H of the
weapon-feel range, branch `review/hand-cannon`). The owner asked for H's
sound to come from your SigmAudio effects instead of more tones generated
in code. These are the slots H already has, waiting for the files.*

## Where the files go

- **Folder:** `godot/audio/sigmaudio/hand_cannon/`. The game reads it as
  `res://audio/sigmaudio/hand_cannon`.
- **Names:** one file per cue, `<cue>.ogg` or `<cue>.wav` (`.mp3` also
  loads).
- **Variants:** for random variation, number them: `fire_01.ogg`,
  `fire_02.ogg`, `fire_03.ogg` and so on. Each shot picks one at random.
- **Other files** in the folder are ignored. The check proves it.
- **Missing cues are fine.** A cue with no file stays a placeholder (the
  report and hit use Heavy Report's existing sounds) or stays silent. The
  screen says how many cues are SigmAudio's.

Nothing else is needed from you. Prod imports the files, runs the check,
packages, and the owner gets the playable comparison.

## The cues

| Cue | When it plays | Where | Suggested length | Variants |
|---|---|---|---|---|
| `fire` | On the shot's own frame. Pitch varies ±4 %. | At the player, not positional | 0.2–0.6 s; a hard transient, then body | 3–4 |
| `fire_tail` | On the shot's frame, with `fire` | At the player | 0.6–1.5 s; the room's echo and decay only | 1–2 |
| `mech_ready` | When the next shot becomes ready: 0.12 s before it. At the default cadence that is 0.43 s after the shot. | At the player | ≤ 0.15 s; a cylinder or hammer click | 2 |
| `hit_confirm` | On the frame the hit confirms (the shot's frame) | At the player | ≤ 0.15 s; must read through the report | 1–2 |
| `impact_metal` | At the hit point, on the shot's frame | 3D, positional (unit size 6 m) | 0.2–0.5 s; ricochet or ping | 3 |
| `impact_stone` | as above | 3D | 0.2–0.5 s; crack and grit | 3 |
| `impact_wood` | as above | 3D | 0.2–0.5 s; thock and splinter | 3 |
| `impact_flesh` | as above | 3D | 0.15–0.4 s; wet and dull, not gory | 2–3 |

**Cadence.** H fires once per 0.35, 0.55 (default) or 0.80 s; the player
changes it with C. `fire` plus `fire_tail` should not smear into the next
shot at 0.55 s.

## Levels

- **Master each file to peak about −1 dBFS.** The game sets the mix.
  Every cue is played at 0 dB except a placeholder (−5 dB).
- **For reference,** from the weapon-feel range (as played):
  - the Static Pulse's blip peaks at −20 dBFS;
  - Heavy Report's report at −6.9;
  - an enemy shot at −10.
- **A caution from the last comparison:** the louder treatment can win
  for being louder. If the `fire` set comes in much hotter than the
  references, Prod will level it in game, and the report will say so.

## What H does on screen, for timing the sound

| Event | Time from the shot |
|---|---|
| Recoil peak | on the shot's frame |
| Gun settled | about 0.27 s |
| Muzzle flame | about 0.05 s |
| Light | gone in about 0.12 s |
| Smoke | lingers about 1 s |
| Bullet streak | reaches 10 m in about 30 ms |
| Impact debris | 0.35–0.9 s depending on material |
