# Batch 032 — AUDIT: baseline melee and the first-person visual seam

**Status: AUDIT COMPLETE, and the contract is better than expected.** A
viewmodel exists, is named, and is already painted from semantic data. The
melee proposal below is PENDING.

## The five questions, answered

### Does a first-person viewmodel contract exist?

**Yes.** `godot/scripts/gameplay/player.gd`:

```gdscript
@onready var viewmodel: Node3D = $Camera3D/Viewmodel
# position (0.34, -0.3, -0.62), rotation (0, 8, -4)
```

with four **named** children, which is the seam art can author to:

| node | mesh | what it is |
|---|---|---|
| `Device` | PrismMesh 0.14 × 0.16 × 0.40 | the Static Pulse emitter — *always there* |
| `Tip` | Box 0.05 × 0.05 × 0.08 | the emitter tip, glow 1.6 |
| `EchoPart` | Box 0.10 × 0.08 × 0.26 | the Echo attachment, **hidden until one is equipped** |
| `EchoTip` | Box 0.05 × 0.04 × 0.05 | the attachment's emitter tip |

The source comment says what it is aiming at: *"a crude handheld
transmitter, very 1998."*

### How are Echo Actions visually expressed?

Through `EchoRuntime.refresh_viewmodel()`, and the semantics are explicit in
the source:

- **`EchoPart` body** is painted `source_color()` — the world the Echo was
  reinterpreted **from**, in the same colour the campaign board and the
  reveal card use for that game, *"so an Echo is visibly a piece of somebody
  else's world that you are holding."*
- **`EchoTip`** keeps the **slot**, *"so 'which button is this' and 'where
  did it come from' stay separate."*

Only the highlighted slot paints, deliberately — *"or four runtimes would
fight over the same mesh."*

### Does the player see a weapon / tool / body representation?

**A tool, yes; a body, no.** There are no hands, no arms and no first-person
body. The device floats at the camera. That is period-correct for 1998 and is
not a gap.

### Is there an attachment / animation seam?

**An attachment seam, yes** — named children under one `Viewmodel` node, with
one already toggling `visible`. **An animation seam, no**: no AnimationPlayer,
no bob, no recoil, no swing. Nothing moves.

### What would a permanent melee bind to?

`Device` is the answer, and the source says why: the Static Pulse emitter is
**always there**. A baseline melee is the other thing that is always there,
so it belongs on the same object rather than as a fifth sibling that appears
from nowhere.

---

## THE FORGE CONSEQUENCE — and this is the important finding

The owner asked: if an Echo changes family from RANGED to GRAPPLE or MELEE,
what currently tells the player its family changed?

**Nothing. The viewmodel cannot express family at all.**

| channel | carries | changes on a reforge? |
|---|---|---|
| `EchoPart` body colour | the **source world** | **no** — same source item |
| `EchoTip` colour | the **slot** | **no** — same button |
| `EchoPart` geometry | fixed 0.10 × 0.08 × 0.26 box | **no** |
| anything else | — | there is nothing else |

So a player who spends scarce Epsilon Coins to reinterpret a ranged Echo into
a grapple gets **a viewmodel that looks exactly the same as before**. The one
operation the Forge exists to perform is the one thing the first-person view
cannot show.

**Interface requirement 32.** The reusable seam art needs is narrow and it is
NOT hundreds of Echo weapons:

> **`EchoPart` needs to be swappable by FAMILY, not just tintable by source.**
> Seven families → seven attachment silhouettes, worn on the same device, in
> the same slot, keeping the same source colour. Family is read from **form**;
> source stays **colour**; slot stays the **tip**. Three channels, three
> meanings, no collisions — and it composes with the Forge's own seven-position
> dial from Batch 025, which is the same seven families.

That is a bounded ask: one node, seven forms, and the two existing colour
channels untouched.

## The baseline melee proposal

**It is not a weapon. It is the device you already hold, used as one.**

The reasoning, made explicit as asked:

- **A fantasy sword** has no place in an abandoned research facility.
- **A crowbar** is a specific other game's object, and the brief forbids
  copying one.
- **A military knife** says soldier, and the player is not one — the fiction
  is somebody wearing a facility transmitter that an alien intelligence has
  grown into.
- **A separate tool** would have to appear from somewhere, and the player
  carries no visible body to carry it on.

So the baseline melee is the **Static Pulse emitter's own discharge fork**:
a short two-tine prong that folds out of the `Device` housing. It is a
facility instrument's grounding fork — the thing you would use to discharge a
capacitor bank safely — repurposed as a weapon because it is what is in your
hand. Human-built, facility-plausible, and it earns its place by already
being on the object.

Epsilon has **not** modified it. That is deliberate: the Static Pulse is the
one thing in the game that is *yours*, and the batch's Epsilon-intrusion DNA
belongs on Epsilon's own installations, not on the player's baseline.

`hazard` orange is **not** used. Telegraph orange stays reserved for danger
directed *at* the player.

**Built:** `melee_fork_stowed` and `melee_fork_deployed` — the same device in
two postures, at true viewmodel scale, so the difference is a fold rather
than an appearance. No timing, no damage, no combo, no hit detection.

Status: **PENDING OWNER REVIEW.**
