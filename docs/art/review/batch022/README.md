# Batch 022 — PROPOSAL: the navigation language

**Status: PENDING.** Art does not mark its own work. Nothing here is
approved, and 020 and 021 remain PENDING alongside it.

## The finding that shrank this batch

The engine already has navigation, and it lives in the HUD.
`zone_controller._process` picks the nearest actionable Check — ranking
`available` over `locked` — and calls:

```gdscript
hud.set_waypoint(pos,  "CHECK 042 · SENDING", Color(1.0, 0.9, 0.4))
hud.set_waypoint(pos,  "CHECK 042 · READY",   Color(0.45, 1.0, 0.9))
hud.set_waypoint(pos,  "CHECK 042",           Color(0.72, 0.78, 0.85))
hud.set_waypoint(exit, "EXIT",                Color(0.5, 1.0, 0.6))
hud.set_objective_text("CHECKS %d/%d CLAIMED")
```

So **which objective, how far, what state, and where the exit is** are all
answered already. A world objective-marker system would be a second,
worse copy of a system that works.

What the HUD cannot answer is the two questions asked while walking:

| | |
|---|---|
| **which way from HERE** | a screen-space arrow points through walls and cannot say which of the two doors ahead it means |
| **what IS this place** | the HUD names the Check. It never names the room. |

That is the entire world-side gap, and this batch is that and no more.

## Why the family carries no hue

`F_collapse.png` is the evidence, and it is arithmetic rather than taste.
Luminance of every colour the project has committed:

| | luma | |
|---|---|---|
| HAZARD `#e8541f` | 0.479 | this will hurt you |
| SIGNAL `#39d7c8` | 0.648 | this is a capability |
| EPSILON `#57ff1f` | 0.702 | Epsilon, nothing else |
| HUD LOCKED | 0.770 | `zone_controller` waypoint |
| **HUD EXIT** | **0.805** | `zone_controller` waypoint |
| NAV FIELD `#c9ced6` | 0.806 | this batch |
| **HUD READY** | **0.824** | `zone_controller` waypoint |
| SEND `#ffd45c` | 0.827 | leaves for the multiworld |
| HUD SENDING | 0.873 | `zone_controller` waypoint |

HUD EXIT and HUD READY are **two percent apart**. SEND and HUD READY are
**three tenths of a percent apart**. Those distinctions are carried by hue
and by essentially nothing else, which means the hue channel is spent.

The sheet also refuses the easy version of this argument: the signage
field is **not** a spare value — at 0.806 it sits directly beside EXIT
green. It does not need one. Its meaning is the glyph and where it is
bolted, so it never asks the player for a distinction the colour channel
has already run out of room to make. That satisfies the owner's rule
directly: nothing here requires telling Epsilon green from EXIT green, or
affordance cyan from READY cyan, by colour.

## The family — four modules, one language

Same plate thickness, same cap and sill, same neutral field.

| module | tris | size (m) | job |
|---|---|---|---|
| `nav_blade` | 60 | 1.17 × 0.30 × 0.52 | perpendicular to the wall, read along a corridor. Carries runtime text. |
| `nav_panel` | 60 | 1.04 × 0.23 × 0.55 | flush beside a threshold at eye height. Carries runtime text. |
| `nav_chevron` | 68 | 0.51 × 0.21 × 0.36 | direction, as an ink arrowhead on a pale field. Butts against a blade end or stands alone. |
| `nav_hanger` | 84 | 1.10 × 0.13 × 0.98 | the ceiling-hung blade, for a junction with no wall to carry one. |

All four at 64.0 texels/m, prop tier. Every face is a **blank field**:
wording is runtime data, exactly as `chamber_builders` already does for
the transit sign and `hub.gd` for the campaign board.

**Direction is not baked.** The blade carried an arrow in the first pass,
and the junction render showed the cost: a blade with an arrow in it is a
blade that can only ever mean "right". Which way `STAIR C` lies is a fact
about where the player is standing, not about the mesh. So the chevron is
its own module, oriented at placement: `[← WEST WING]`, `[PUMP HALL →]`.

## What the renders changed

Five things were wrong and the shots caught them, in this order:

1. **Everything was on the floor.** Exported with the `wall` anchor, which
   re-bases Z to the lowest point and threw away the authored 2.60 m head.
   Now `module_floor`, which is the "height is part of what it is" case.
2. **The panel did not fit.** Authored above the door; the manifest showed
   it topping out at 4.03 m under a 3.60 m ceiling. `door_height` 3.2
   leaves 0.40 m of wall above a doorway. It moved beside the jamb at eye
   height — better ergonomics anyway, and it widens the gap to the blade:
   overhead means *that way*, eye height means *this is here*.
3. **The blade was too big for the corridor.** 1.30 m of face put two
   opposing blades 0.48 m apart in a `corridor_width_min` 4.0 m corridor —
   narrower than `player_diameter`. Now 0.78 m.
4. **The chevron was a fold, and read as a peak.** Two wedges meeting in a
   V, on the theory that the shadow would carry direction. At eye height
   it read as a mountain. A thing that must mean "left" cannot be
   symmetrical about the axis it describes. Now an arrowhead.
5. **Every inset field was on the back of its own sign.** Blender −Y maps
   to Godot +Z, so the recessed pale grounds and the arrowhead all faced
   the wall. The chevrons rendered as plain trim blocks.

A sixth is worth recording because it is a general rule rather than a
bug: the arrowhead read as a solid block even after the material was
fixed, because a 0.20 m glyph on a 0.22 m field leaves a 10 mm margin that
vanishes at distance. A mark needs the ground around it as much as it
needs contrast against it.

## Known limit, not hidden

At the 5.4 m gameplay distance of `A_junction.png`, **the arrow carries and
the text does not**. That is the honest read and the signs were not
inflated to disguise it. It is also how real wayfinding behaves, and it is
the argument for the two-part split: the chevron is the distance read, the
text is the close confirmation.

## The sheets

| | |
|---|---|
| `A_junction.png` | which way from here, from a 1.6 m eye at 90° FOV |
| `B_threshold.png` | what is this place, on a run of doors |
| `C_hue.png` | every committed colour in one corridor, plus the signage |
| `C2_hue_desaturated.png` | the same frame with hue removed |
| `D_themes.png` | **all six themes.** Each module is built in its own theme and wears that theme's trim — not one concrete sign re-lit six ways. Camera, lens, lighting and distance identical in every panel, on a neutral backdrop held constant so the signage is the only variable. |
| `E_family.png` | the four modules at reading distance |
| `F_collapse.png` | the luminance table above |
| `G_hazard_collision.png` | **a finding.** In `rusted_industrial` the family inherits hazard striping — see below. |


## Batch 022-R — what the six-theme sheet changed

The original `D_themes` showed three themes and said the other three were
behind the Style Lock gate. **That caption was stale, not the claim.**
Style Lock passed, Batch 012 built the remaining treatments, and all six
carry the `trim` and `wall` roles this family is made of. Every module is
now built once per theme — 4 × 6 = 24 assets.

### Finding 1 — the blade's text was mis-centred

`nav_blade`'s bracket hangs off −X, so `module_floor` centring leaves the
pale field 0.155 m to the +X side of the object origin. Every early sheet
placed text at the object position, so it sat that far left of its own
field and overran the frame at one end. The builder now records
`face_centre_x_m`, `face_width_m`, `text_usable_width_m` and a character
budget; the scenes read them. L-67 again: a number an asset is designed
around belongs in its manifest.

### Finding 2 — hazard striping in one theme. NOT FIXED; owner's call.

`materials._rust_trim` paints a **universal** hazard band into the
`rusted_industrial` trim texture — deliberately and correctly, because in
that theme a walkway edge is the thing most likely to kill you, and it uses
`pal.universal("hazard")` so the player does not re-learn it per theme.

The navigation family is built from `trim`, so in one of six themes a
wayfinding sign wears hazard stripes. The palette's rule for that colour is
*"this will hurt you. Never used decoratively, in any theme, for any
reason."* `G_hazard_collision.png` shows it beside a theme whose trim
carries no band.

Not fixed unilaterally, because the fix touches a locked rule. Options:

1. **Add a `trim_plain` role** — the same per-theme trim without the
   walkway-edge safety band, for fixtures that are not walkway edges.
   Additive, no approved asset changes, the family keeps theme-owned trim,
   collision gone. **Recommended.**
2. **Build the family from `wall`** — neutral in all six, but the signs
   would read as building fabric rather than as fixtures.
3. **Accept it** — rejected here; it breaks a locked rule.
