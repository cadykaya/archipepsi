# Batch 026 — PROPOSAL: the checkpoint / re-entry station

**Status: PENDING. Visual language only.** Nothing here decides spawn
mechanics, healing amount, fast-travel rules or save semantics.

## The audit

Read-only against `claude/archipepsi-echoes-continuation-b1adno`. The closest
thing that exists is in `godot/scripts/gameplay/player.gd`:

```
var _spawn_transform: Transform3D
func set_spawn(xform: Transform3D) -> void
```

plus `RESPAWN_DELAY = 1.5` and a HUD death overlay reading SIGNAL LOST.

That is **one slot holding one transform, with no identity.** No checkpoint
entity, no checkpoint state, and nowhere to record *which* station is
current — so of the three states proposed here, **zero have a runtime
representation.** `set_spawn()` is the seam a station would call, and it
would have to carry an id before "current re-entry anchor" could be something
the world can show. **Interface requirement 27.**

## The colour problem, and why the answer is no colour

The brief says avoid confusion with Check cyan/white, Epsilon green and
hazard orange. Every saturated family in `art_palette.json` is already spoken
for — `signal`, `hazard`, `identity`, `send`, `glitch`, `dead`. There is no
unspent hue, and Batch 022 settled that the answer is not to spend one anyway.

So:

> **The checkpoint is the one important object in the room that does not glow.**

In a world where everything that matters emits, a tall achromatic structure
that *reflects* is more distinctive than another lit thing, not less. It
cannot be confused with the three the brief names because it is not competing
in their channel at all.

| state | mast | bands | light |
|---|---|---|---|
| inactive | folded flat into the pad | dark | none |
| activated | raised, cross-arms out, stays braced | high value | none |
| current re-entry anchor | raised + canopy ring deployed | high value | **one** achromatic lamp, under the canopy |

The pad's rim also rises with the state (0.05 → 0.13 → 0.22 m), so a player
looking down at their feet still gets an answer.

## Two rules, not styles

**Bands are horizontal.** `hazard` marking is diagonal striping. The two must
stay different objects at distance in a dark room, and the reliable guarantee
is that they differ in *geometry* rather than only in hue — a grey-scaled
hazard stripe and a grey-scaled survey band still have to be distinguishable.

**Posture carries the state, not surface.** Three different silhouettes read
at any distance and in any lighting. A surface change does not. This is the
same argument Batch 022 made for navigation.

## Universal, not themed

System furniture, like the Check: the same object in all six themes, so *can
I come back here?* is never a question about which Zone you are standing in.

## Metrics

| asset | state | tris | size (m) | emits |
|---|---|---|---|---|
| `checkpoint_inactive` | inactive | 200 | 2.51 × 2.51 × 0.41 | no |
| `checkpoint_activated` | activated | 308 | 2.51 × 2.51 × 3.08 | no |
| `checkpoint_anchor` | current anchor | 448 | 2.51 × 2.51 × 3.08 | one lamp |

Exported at the **`interactable`** tier (900), not `prop` (300). The first
build failed the prop ceiling at 308 triangles. The standing rule is to
delete geometry rather than raise a ceiling — but that applies to an asset in
the right tier to begin with. A 2.5 m station the player activates is an
interactable, exactly like the Check; cutting bands off a survey mast to fit a
hand-prop budget would have been fixing a labelling mistake with the wrong
tool.

## Sheets

| | |
|---|---|
| `A_checkpoint_states.png` | three states, identical camera, 1.8 m rod |
| `B_checkpoint_neighbours.png` | the station beside Check cyan, Epsilon green and hazard orange — **and the same frame again in Rec. 709 luma** |

## What sheet B shows, including something it was not looking for

The station reads as completely distinct in **both** rows, which is the
claim: its identity is shape, so removing colour costs it nothing.

The luma row also shows something about the *existing* palette that was not
what the test was for: **Check cyan and Epsilon green collapse to nearly the
same value**, with hazard orange only slightly darker. A player who cannot
separate those hues cannot separate those three signals by value either.

That is stated as an observation and not as a finding: the neighbours in this
sheet are deliberately crude lit boxes standing in for the three families, not
the real assets, so it is evidence about the *hues* and not about the Check or
the Epsilon installation as built. Whether it matters is the owner's call, and
it is outside this batch's scope.

## What the render changed

The lamp was first mounted on top of the mast head, where the deployed canopy
hid it in every view — a panel captioned "one lamp lit" showing no lamp. It
now hangs beneath the canopy, which is also where the object would really put
a light meant to illuminate the pad you arrive on.
