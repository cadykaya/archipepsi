# Five weapons: ready before the aim settles

*Prod — 2026-10-13. Your correction after Vera's review of the second
pass, in one corrected candidate. Nobody has played it by hand yet.*

- **Branch:** `review/five-weapons-v3`, on top of the second pass
  (`review/five-weapons-v2`). The second pass's build `9eb0ce1f` is
  kept, unchanged, for comparison.
- **Build:** `0db36cdb`. Isolated as before: no campaign change. The sound
  is still Condi's set, unchanged, and the aiming/grapple separation
  still works.

## What was wrong

The second pass made Foundry's recovery fill the cooldown, and its own
check required the aim to settle **before** the next shot was
available. You asked for the opposite: the mechanism ready first, with
some settling still going on.

Vera also asked whether automatic recovery fights the player's hand.
On the second-pass build it did. A player who pulled the mouse down
against the kick was pulled down a second time by the recovery. Real
mouse events, Foundry, from the same aim:

| You pull the mouse | Second pass ends | This build ends |
|---|---|---|
| nothing | on target | on target |
| down 1.0° | **1.0° low** | on target |
| down 1.5° | **1.5° low** | on target |
| down 2.2° (the whole climb) | **2.2° low** | 0.3° low |
| down 4.0° | **4.0° low** | 1.9° low |
| up 1.0° | 1.0° high | 1.0° high |

In the last three rows of this build, the amount below target is your
own pull beyond the climb still left when you made it. Recovery doesn't
add to it, and pulling up is kept as yours.

## How firing works now

**Foundry, still one shot per 0.72 s:**

| | When |
|---|---|
| The gun heaves back and comes home | 0.52 s |
| The cylinder turns | 0.30–0.50 s |
| The hammer cocks: the readiness cue | 0.70 s |
| **Ready** | 0.73 s, with about 0.17° of the 2.2° kick still settling |
| The view fully settled | about 1.0 s |

- **Fire on readiness:** the shot goes exactly where the crosshair is at
  that moment. Nothing snaps back to the old aim; the leftover climb
  just keeps settling under the new kick.
- **The view climb is your own look, moved.** Recovery gives back only
  what the kick lifted and you haven't already taken back yourself.
- **The other guns keep their own feel:**
  - Sightline's sight settles before it is ready, for quick, precise
    follow-ups.
  - The Breacher's settles just before its pump.
  - Switchback, the Sweeper and the Mass Driver are unchanged.
- **F and the middle mouse button** now fire the weapon exactly like
  left click, with its tracer, sound and recoil. Before, they bypassed
  all of that. Put the weapon away (6 or 0) and they go back to being
  the Echo slot's keys. Right click and the grapple are untouched.

## What was tested

**The check:** 119 parts in the real game by real input, PASS in
the source tree, the exported Linux build and the Windows build under Wine, in all six launcher modes (120 on the Sweeper launch). New parts:
- **Readiness doesn't wait for the aim.** Foundry: about 0.17° still
  settling at ready. Sightline and the Breacher: settled before ready.
  The hammer and the pump are followed by readiness with no dead wait.
- **Foundry fired again the moment it's ready**, 0.733 s after the first
  shot:
  - the shot lands on the line of the look of that very frame, 0.17°
    from the first shot's aim;
  - the look moves only 0.016° from the frame before;
  - both hits land, and hands off, the view then settles back exactly.
- **The hand on the mouse**, as in the table above. The headless check
  moves the look exactly as the player's mouse code does, because
  headless Godot can't capture a mouse. The table itself comes from a
  separate run under a virtual display, with real mouse events through
  the player's own code, on both builds.
- **F, the middle button, and F held on the Mass Driver** all fire
  through the range with the full presentation. With the weapon put
  away, F does nothing in the range, as before.

**The check bites.** Four deliberate breaks each fail it:
- recovery ignoring your pull;
- snapping the aim back at the shot;
- readiness waiting for the aim;
- F left on the Echo slot.

**Also:**
- **the probe** in all three: 0 bridge connections, your files byte-identical;
- **Condi's validator** passes;
- **the Wine fresh-folder run:** both parts join to the right sha256, all six launchers start their weapon, 0 connections; Condi's launcher keeps the second pass beside it, both playable;
- **the weapon-feel range's own check** passes;
- **Vera's boundary check:** no red line crossed, and the Static Pulse
  is byte-identical.

## Not done

- **Not played by hand.** The numbers say the behaviour is right; only
  you can say whether 0.17° of settling at readiness feels right, or
  should be more or less.
- **Mouse sensitivity still isn't slowed while aiming.**
- **Unchanged from the second pass:** the guns are still placeholder
  shapes, and Condi's three open asks (a wood impact, a lighter Sweeper
  sound, the ratchet's timing) still stand.
