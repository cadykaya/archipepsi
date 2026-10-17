# Pre-playtest pass: Unified-1 against D-20 (+ §13, §14) and the D-22 slice

**Dess, 2026-10-17. Read-only design review** of `integration/unified-1`
at `349ef77f` (report `299981ad`):
- `godot/scripts/unified/shunter.gd` and `freight_bay.gd`;
- `godot/tests/shunter_check.gd`;
- the D-22 slice report (`review/d22-slice`,
  `docs/reports/2026-10-16-d22-slice.md`).

**Not checked here:** runtime, which is Vera's lane. Nothing was run.

## Blocker: check before Skyiah plays

**B1. The booth doorway doesn't stop a rushing Shunter.**
- The 5 m rule shuts the door when the Shunter is near (`freight_bay.gd`,
  `DOOR_CLEAR = 5.0`, `_drive_booth_door`), but a rush covers 5 m in
  about 0.4 s and the door needs about 1.5 s to close.
- The doorway is 2.0 m wide; the Shunter is 0.9 m.
- The door's interlock counts only the player and required objects as
  occupants (`service_shutter.gd:240-241`), so it **closes onto a
  Shunter in the doorway**.
- The door also stands **open whenever the player is on the ramp**. A
  braced Shunter aimed at a player on the ramp rushes through the open
  doorway.
- `shunter_check.gd` has no case for the Shunter at the doorway, or for
  the LEAVE lever.
- **The risk:** the Shunter in the ramp channel, the booth or the
  corridor (which leads into Station 1), or wedged in a closing shutter.
  **Unverified.** Vera should try it in the running build.
- **Recommended small fix (Condi's call; it is §13's own design):**
  - make the doorway **physically impassable to the Shunter, passable to
    the player**;
  - cheapest: a collision blocker in the doorway on a layer only the
    Shunter collides with;
  - or a steel post leaving a gap of about 0.85 m: the player's 0.8 m
    capsule passes, the Shunter's 0.90 m body doesn't;
  - keep the LEAVE lever and the 5 m rule as they are.
- **Then** the 5 m rule is a safe stand-in for "a personnel door the
  Shunter can't pass, with a dogleg". **Without the blocker, it is not.**

## Small calls (Condi's; my pick first)

1. **A broken brace waits out the cooldown.** After a heavy hit breaks
   the brace, the Shunter re-aims (0.6 s). The locked re-brace then waits
   for the 3 s cooldown (`_do_reaim`/`_do_close` both need
   `_cooldown_left <= 0`). That buys about 2.3–3 s of safety; D-20 §3.2
   meant about 0.6 s.
   - **Pick:** clear the cooldown when a brace breaks, so the locked
     re-brace follows the re-aim. One line.
2. **A heavy hit during the horn stretches it to 0.9 s.** D-20 said a
   jolt only.
   - **Pick:** accept. It's harmless extra ambush time.
3. **Hearing (18 m) is still in.** It's redundant with notice (§14).
   - **Pick:** leave it for this build and cut it later. It does nothing
     harmful.
4. **Plough rating 14 vs §14's 13.** They behave identically.
   - **Pick:** keep 14. §14 is corrected.

## Matches the specs
- **Numbers:** HP 40, rush damage 14 plus an 8 m/s shove, 0.7 s brace,
  1.1 s rush at 13 m/s, 3 s cooldown.
- **Recovery windows:** 0.7 / 1.1 / 1.1 (crate breaks) / 1.8, with the
  plume fading in the last 0.2 s.
- **Hit rule:** the contact volume (1.0 / 1.35 / 1.05) and the jump-over.
- **Armour:** 25 % frontal in close, brace and rush, with the raw blow
  read for reactions.
- **Heavy hits:** the summed-pellet heavy check. Heavy reactions in
  work/dock (horn +0.3 s), close (0.3 s halt plus 1 m shove), brace
  (broken once per cycle, then locked), rush (nothing), recover (jolt, no
  extra time).
- **Behaviour:** notice on a hit, turn rate 180 °/s, declared tend lane,
  dock and tote nudge.
- **Gate:** 2.05 s to close (accepted, §14). The **6 s hold counts from
  fully shut** (`_on_gate_closed`). It stays up while the Shunter stands
  in the opening.
- **§13:** no Mass Driver cap (owner's call); death in the bay resets it;
  the LAST FIGHT board (time-to-kill, rushes, damage per weapon).

## D-22 slice
- **§6.A A1–A11 all pass** per the report. A7 (resume drift, 52 m) is
  reported, as the brief asked.
- **Its known issues are the expected ones:**
  - the resume spawn is at the Crossing's start: Stage 2;
  - a re-sent layout digest is refused, and the committed layout is kept:
    Vera's lane;
  - area 2's lever remembers its state for the session only. The door is
    derived, so that's fine.
- **"Both Forges can draft" is intended,** not a defect. D-22 §5 rule 2:
  every unlocked Forge builds from the shared pool.
