# Batch 024 — PROPOSAL: Epsilon presentation states and the presentation arc

**Status: PENDING. Presentation only. Nothing here is integration-ready.**

Uses the already-`PASS` Batch 002-R giant-computer DNA. Nothing about that
object is reopened.

## The runtime audit came first, against the RIGHT branch this time

Audited read-only against `claude/archipepsi-echoes-continuation-b1adno`,
current Production — not the art lane's base, which is the mistake L-72 was
written about.

`godot/scripts/ui/epsilon_voice.gd` is the only Epsilon presentation code in
the project. It is a **bark selector**: 18 event kinds, a PRIORITY order, a
6 s cooldown, a 4 s dwell, a 42 s hub idle interval.

> It answers **what Epsilon says.** It does not answer **what the
> installation looks like while it says it.**

There is no presentation-state enum, no visual-state signal, and no binding
from a bark to any material. So these are proposals, and each records
honestly whether a runtime signal for it exists today:

| state | runtime signal today |
|---|---|
| dormant / listening | the ABSENCE of one — no bark airing, no request in flight. Derivable. |
| thinking / generating | bridge-side only. `epsilon/requests.py` knows a request is out; the scene is never told. |
| **speaking** | **EXISTS.** `EpsilonVoice.tick()` holds a line for DWELL seconds. Bindable today. |
| successful interpretation | bridge-side only. A validated provider result is not surfaced. |
| error / refusal | bridge-side only. `epsilon/fallback.py` runs on provider failure; the scene is never told. |
| player attention / focus | **does not exist.** No look-at or proximity test against the installation. |

**One of six is bindable today.** Recorded as interface requirement 25.

## Two inherited rules, not reopened

**Nothing on the human half glows.** Every state is carried by the
intrusion. A state that lit the console would say the facility came back on,
which is a different sentence entirely.

**Emissive saturation 0.40 is the CEILING, not a midpoint.** 002-R swept
0.94 / 0.60 / 0.40 / 0.25 / 0.12 through the bench and found the clip point
between 0.40 and 0.60 — at 0.60 the green channel pins at 255. So the states
modulate *below* it. A language built by turning the green up would have had
two usable steps.

## Six states, told apart without a second colour

`identity` green is the only hue Epsilon gets. So the same arithmetic Batch
022 ran for navigation applies here: the language must be **value, extent,
rhythm, aperture and orientation.**

| state | emissive | where the light is | aperture |
|---|---|---|---|
| dormant | 0.10 | deep in the seams only | flush, closed |
| thinking | 0.22 | interior veins, along the limb | closed, veins proud |
| speaking | 0.34 | out through opened seam faces | splayed toward the room |
| interpreted | 0.28 | a **closed circuit** — continuous, even | ring complete |
| refusal | 0.06 | asymmetric dropout, `dead` plating exposed | clamped shut |
| focus | 0.34 | one narrow directed bore | iris, oriented |

Three things worth naming:

- **`speaking` and `focus` sit at the same 0.34.** They are the tightest pair
  in the set and are told apart only by breadth and direction: speaking is a
  broad undirected field, focus is a single narrow bore that points. On the
  sheet they are distinguishable but they are the pair most at risk, and that
  is stated rather than hidden.
- **`interpreted` is not "brighter than thinking".** It is *closed*. The vein
  ring completes. A player learns "it finished" from a shape, not a level.
- **`refusal` recruits `dead`**, which means "unpowered, locked, spent,
  offline" — exactly what a refusal is. It deliberately does **not** use
  `glitch`: glitch is Epsilon Static and the missing-world checker, and a
  refusal is Epsilon *declining*, not Epsilon corrupted.

## The arc: localized → established → proprietorial

Three dressings of the same bank. **Presentation, not progression** — nothing
here says when a stage applies, what advances it, or that it advances at all.

| stage | what the intrusion has taken | fronts gone |
|---|---|---|
| EARLY | one wrecked bay; it has not left the cabinet line | 3 |
| MIDDLE | the console's right third and the hijacked cable tray | 2, 3 |
| LATE | floor, ceiling and the bank front; the human machine is substrate | 1, 2, 3 |

**Emission is identical (0.24) in all three.** The read is *extent*. A sheet
that let the late stage also be brighter would prove nothing about whether
extent alone carries.

## Metrics

| asset | state / stage | tris | size (m) |
|---|---|---|---|
| `eps_state_dormant` | dormant | 392 | 2.46 × 1.42 × 2.90 |
| `eps_state_thinking` | thinking | 428 | 2.46 × 1.42 × 2.90 |
| `eps_state_speaking` | speaking | 420 | 2.46 × 1.42 × 2.90 |
| `eps_state_interpreted` | interpreted | 480 | 2.46 × 1.42 × 2.90 |
| `eps_state_refusal` | refusal | 380 | 2.46 × 1.42 × 2.90 |
| `eps_state_focus` | focus | 448 | 2.46 × 1.42 × 2.90 |
| `eps_arc_early` | early | 240 | 4.90 × 1.71 × 2.90 |
| `eps_arc_middle` | middle | 288 | 4.90 × 1.71 × 2.90 |
| `eps_arc_late` | late | 516 | 5.29 × 1.71 × 3.89 |

The six states share an **identical footprint**, deliberately. A comparison
sheet whose panels differ in two ways proves nothing about either.

## Sheets

| | |
|---|---|
| `A_epsilon_states.png` | six states, identical geometry, identical camera |
| `B_epsilon_arc.png` | three stages, constant emission, 1.8 m rod |

## What the renders changed

Three failures, all caught by looking at the image rather than the log:

- **The first rig lit the human console brighter than the intrusion.** The
  raked control panel caught the key broadside and read as a *lit control
  surface* — which breaks 002-R's one rule as completely as an emission
  would. Ambient now carries the machine and the key is dropped until the
  rake stops flaring.
- **The first framing cropped to the mass alone**, turning a state language
  that lives on an operator console into six pictures of a lump. The camera
  now holds the whole bay: desk, footwell, monitor and mass.
- **The arc sheet showed no intrusion at all in EARLY** — and the cause was
  in the *asset*, not the camera. `_bank()` built a cabinet front on every
  bay, so the mass sat sealed behind 0.10 m of steel. 002-R is explicit that
  erupted bays have their fronts *gone*; the builder now wrecks the bays the
  intrusion occupies, which is both correct to the DNA and the fix. Two
  camera revisions were spent nudging before the geometry was suspected.
