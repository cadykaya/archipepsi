# Batch 033 — AUDIT: Zone exit / clear-point readability

**Status: AUDIT COMPLETE. One art defect found. No new portal built, and
none should be.**

## Question 1 — can the current portal vocabulary serve as the Zone exit?

**It already IS the Zone exit.** `godot/scripts/gameplay/exit_portal.gd`
builds one after the final chamber:

| part | geometry | material |
|---|---|---|
| `Frame` | 3.2 × 4.2 × 0.6 box at y 2.1 | `ThemeMaterials.trim_mat(theme)` |
| `Core` | 2.4 × 3.4 × 0.2 box at y 1.9 | `glow_material`, recoloured by state |
| `StateLabel` | `Label3D`, billboard, 44 pt, at y 4.6 | — |

So the answer to "should we invent another portal" is **no**. Building a
second exit object would be adding a rival to a thing that works.

## Question 2 — would it be confused with the Hub generation portal?

**There are already three portal-shaped objects, and this is a real risk:**

- `HubPortal` with `kind = "main"` — the way *into* a Zone
- `HubPortal` finale variant — `_finale_portal` in `hub.gd`
- `ExitPortal` — the way *out of* a Zone

Two of the three live in the Hub and one in a Zone, so a player never sees a
main portal and an exit portal in the same room. That containment is what
currently prevents the confusion, and it is worth naming because it is
**contextual, not visual** — the two would be confusable if they ever shared
a space.

## Question 3 — is there a runtime state hook?

**Yes, and it is the narrow gap.**

```
func set_unlocked(value: bool, checks_remaining: int = 0) -> void
```

A **boolean plus a count**. The redesigned lifecycle wants four states —
present-but-not-ready, ready, return-available, cleared — and a boolean
cannot carry four. `checks_remaining` is a number, not a state, and today it
only feeds the label.

**Interface requirement 33:** the exit needs a state, not a flag. Art is not
proposing the enum; Production owns it.

## THE DEFECT: the locked state is painted in the hazard channel

```gdscript
_core.material_override = ThemeMaterials.glow_material(
        Color(0.5, 1.0, 0.6) if unlocked else Color(0.4, 0.2, 0.2),
        2.0 if unlocked else 0.5)
```

The unlocked green is fine and is a known, accepted channel.

**The locked colour `(0.4, 0.2, 0.2)` is a dark red.** `art_palette.json` is
unambiguous about that region: `hazard` means *"this will hurt you. Never
used decoratively, in any theme, for any reason."*

**A locked exit is not a hazard.** It is *not for you right now* — which is
exactly what the `dead` family means: *"unpowered, locked, spent, offline.
The value a fixture drops to when it is not for you right now."* The word
"locked" is literally in that family's definition.

This is a one-line art correction in engineering-owned code, so it is
**recorded and not made**: `Color(0.4, 0.2, 0.2)` → the `dead` family
(`#4a4f57`, or its ramp). Logged as part of requirement 33.

## Question 4 — does the exit need to be a distinct authored place?

**No, and it should not be.** The exit is the one object in a Zone whose job
is to be *found from anywhere*. A place has to be entered to be read; an
object framed in a wall can be seen across a room. The current 3.2 × 4.2 m
frame is already at architectural scale.

## Question 5 — does it need a landmark / navigation relationship?

**It already has one, and nothing needs building.** Batch 022's navigation
family exists precisely for this, and the HUD already carries an EXIT
waypoint colour. The exit does not need its own wayfinding; it needs the
existing wayfinding to be *allowed to point at it*, which is a Production
binding rather than an art asset.

## Verdict

> **Build nothing.** The vocabulary exists, is correctly scaled, has a
> runtime hook, and is contextually separated from the Hub portals. What it
> lacks is a four-state signal (Production's) and one colour correction that
> puts a locked exit in `dead` rather than in `hazard` (also Production's, in
> their file).

The only art-side note worth keeping: **the `StateLabel` is currently doing
all the work.** The frame and core are identical in every state except for
one colour and one energy value. If the four states land, the frame is where
the difference should live — shutter position, iris aperture, how much of the
opening is actually open — because a player reading a billboard label is a
player who was not told by the object.
