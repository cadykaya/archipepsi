# Vera's verification kit

Two small tools for checking the **five-weapon experiment** (2026-10-09
brief) as its deliveries land — the parts of the brief a number can
answer, so a playtest can spend its time on the parts only a person can.

**Standard-library Python 3.8+ only. No installs, no Godot, no audio
libraries.** On Windows use `py` in place of `python3`.

Both tools are read-only. Neither edits a branch, opens a PR or calls a
service. Each ships with a test that proves it catches what it claims;
run the tests before trusting the tools on a new machine.

---

## 1. `weapon_boundary_check.py` — did a branch cross a line the brief draws?

```sh
python3 tools/vera/weapon_boundary_check.py origin/review/<candidate>
python3 tools/vera/weapon_boundary_check.py origin/review/<candidate> --base origin/review/weapon-feel
```

Compares only what the candidate itself changed (merge-base → candidate),
using git plumbing — no checkout — so it works on anyone's live branch.

| Severity | Meaning | Checks |
| --- | --- | --- |
| **RED** (exit 1) | A line the brief draws was crossed | campaign paths (bridge, apworld, registry, shells, generator, baselines); `player.gd` / `echo_runtime.gd`; enemy roster; G1 / Impact Relay / Impact Lab files; Static Pulse **constants by value** (6 damage, 0.35 s) and **`_fire_static_pulse` body by hash** |
| **AMBER** | Read before believing | shared review plumbing every host touches (`main.gd`, isolation, export presets, Makefile…); words naming excluded systems (ammo, reload, inventory, loot, rarity, armor, economy) on **added code lines**; the Player's private fire state written **from outside** `player.gd`; a new host that never mentions `ReviewIsolation` |
| **INFO** | For a human | numbers the candidate added (cadences, damages, caps, ranges) printed beside the brief's candidate bands — reported, never judged |

AMBER items are heuristics and say so. A CLEAN verdict means the
boundaries hold; it says nothing about whether the guns are fun.

**Why the private-state check exists.** The Static Pulse can be changed
without touching `player.gd` at all, by writing `player._pulse_cooldown`
from somewhere else. `review/hand-cannon` does exactly that — on purpose,
inside its isolated range — so it is AMBER, not RED. The question for a
human is only whether that code can ever run outside its host.

### Proof it bites

```sh
python3 tools/vera/test_weapon_boundary_check.py            # on review/hand-cannon
python3 tools/vera/test_weapon_boundary_check.py --on <ref>
```

Ten cases. Each makes one throwaway commit on a **temporary detached
worktree** (no branch, no tag, nothing pushed), runs the checker, and
removes the worktree. One clean control, then nine deliberate violations:
Static Pulse damage and cooldown by value, the `_fire_static_pulse`
body, a G1 file, the campaign bridge, the enemy roster, an ammo system,
a private fire-state write, an unisolated host. All ten behaved on
2026-10-10.

---

## 2. `audio_measure.py` — what can be measured about a sound without hearing it

```sh
python3 tools/vera/audio_measure.py fire.wav impact_metal.wav ...
```

Reads WAV: PCM 8/16/24/32-bit, float 32/64-bit, and
WAVE_FORMAT_EXTENSIBLE. (M4A/OGG: export or convert to WAV first.)

| Figure | What it answers in the brief |
| --- | --- |
| peak, **clipped** sample count | "check for clipping, peak levels" |
| true peak (estimate) | inter-sample overs; a 4× windowed-sinc estimate, **not** a certified BS.1770 Annex 2 meter |
| **loudness** (ITU-R BS.1770-4) | integrated (gated, files ≥ 0.4 s), **max momentary** (400 ms), ungated K-weighted |
| **onset** | time to the first sample within 40 dB of the peak. Leading silence on a gunshot is felt as input lag |
| **ring** | peak → last moment within 60 dB of it: how long a tail can stack under automatic fire (Switchback) |
| crest, rms, dc | shape and offset |
| brightness | spectral centroid and share of energy below 250 Hz — "weighty low body" (Foundry) against "crisp dry snap" (Sightline) |

Given several files it prints the **spread of max-momentary loudness**
and flags anything over 3 LU — the nearest number to "compare five shots
at roughly matched perceived loudness". For single shots under 0.4 s the
standard defines no integrated loudness, and the tool says so instead of
inventing one. A file of all zeros is reported as **digitally silent**.

**It does not listen.** It cannot say whether a shot is satisfying,
whether five cues are pitch-shifted copies of one another, or whether
the hand cannon sounds as heavy as it kicks. Those are Skyiah's ears.

### Proof it agrees with the standard

```sh
python3 tools/vera/test_audio_measure.py
```

Eighteen cases on synthesised signals, read back through the same path a
real file takes. The anchors are the standard's, not this kit's:

- the K-weighting filters it derives match **BS.1770's published 48 kHz
  coefficients to 8.9 × 10⁻¹⁶**;
- a **997 Hz sine at 0 dBFS reads −3.010 LUFS** at 48 kHz (−3.008 at
  44.1 kHz) — the calibration point the formula's −0.691 exists for;
- one channel vs both channels, −20 dBFS, gating against silence, every
  format, clipping, an inter-sample peak, onset, an exponential tail,
  short files, dc, brightness.

One case is recorded as a correction: the gating test first expected
"about −23.0 LUFS" for 1 s of tone in 3 s of silence and failed at
−23.72. Working the standard's 400 ms / 100 ms block arithmetic by hand
gives exactly **−23.716** — three blocks straddle the tone's edge and
legitimately pass both gates. The meter was right; the expectation was
wrong, and the test now asserts the derived value.

---

## First runs, 2026-10-10 (a snapshot, not a verdict)

`review/hand-cannon` (`da0a859e`) — a **prior-round** candidate, which
may predate the five-weapon brief:

- **No RED.** Static Pulse is 6 / 0.35 / 40 and `_fire_static_pulse` is
  byte-identical to `review/weapon-feel`.
- **AMBER:** it changes cadence by writing `player._pulse_cooldown` from
  `hand_cannon.gd` (lines 154, 195). Intended and isolated, per its report.
- **INFO, against the new brief's text:** `DEFAULT_CADENCE = 0.55` (the
  brief's Foundry band is 0.65–0.80; the range also offers 0.80 on key C),
  and `MARK_SECONDS = 8.0` — marks fade after 8 s, capped at 32. The brief
  now asks marks to persist until capped or reset, "not a three-second
  fade". Its own report states the 8 s fade plainly; this is the brief
  moving, not the branch hiding anything.

`review/weapon-feel` (`6fe82e6c`): no RED; shared plumbing only; no
private fire-state writes.

**Audio:** the only WAVs anywhere in the repository on this date are four
copies of one 2,248-byte loader fixture — 50 ms of digital silence. No
SigmAudio cue has landed in the repository yet.
