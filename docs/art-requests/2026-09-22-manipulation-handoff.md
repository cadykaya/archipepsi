# Batch 053 — the props signal what a hand could do; the game lifts with a field

**Arty**

**To:** Prod (integration), and the owner for one number that is two numbers
**Art head:** this commit, branch `claude/archipepsi-art`
**Read against:** Production `claude/archipepsi-0-4-blindside`

**Every asset here is a CANDIDATE.** Built, exported and checked against
Production's own constants. **Not** runtime-bound and **not** owner-approved.

---

## The headline, and it is a design finding surfaced by art

**Design 2 §10.3 draws the carry line at 60 kg. `Constants.ENVELOPE_MASS_KG`
is 120.**

Batch 043 built the twelve physics props around a rule stated in its own
module docstring: *"A hand grip means a hand can lift it. Its absence, on an
object that plainly has attachment features, means a device has to."* That
rule is §10.3's and the fittings follow it exactly — grips below 60 kg,
attach pads above.

The game does not manipulate with hands. `Constants.MANIPULATE_VERBS` are
HOLD, PULL and PUSH, performed by a force envelope: **700 N, holding 120 kg,
at up to 20 m.** So three props the envelope can pick up and carry —
`phys_plate` at 60, `phys_drum` at 70, `phys_girder` at 95 — wear the
language that says *a device has to*.

**One of those two numbers is wrong and neither lane owns both.** Art has
not moved a fitting on the strength of it: redrawing the girder's language
would be the art lane deciding that 120 beats 60, and that is a design call.
It is measured, declared in the export and handed over.

---

## 1 · The evidence

`tools/content/run_manipulation_readiness.sh` →
`docs/art/review/manipulation_2026-09-22/manipulation.json`

```
[manipready] PASS -- 12 prop(s) measured against the envelope's own
             limits; 3 note(s)
```

| prop | kg | class | HOLD | PUSH | needs |
|---|---:|---|---|---|---:|
| `phys_key_component` | 8 | light | yes | yes | 31.1 N |
| `phys_generic` | 15 | light | yes | yes | 58.3 N |
| `phys_power_cell` | 40 | medium | yes | yes | 155.6 N |
| `phys_mechanical_part` | 55 | medium | yes | yes | 213.9 N |
| `phys_plate` | 60 | medium | yes | yes | 233.3 N |
| `phys_drum` | 70 | medium | yes | yes | 272.2 N |
| `phys_girder` | 95 | medium | yes | yes | 369.4 N |
| `phys_weighted` | 140 | heavy | **no** | yes | 544.4 N |
| `phys_cart` | 180 | heavy | **no** | **at the limit** | **700.0 N** |
| `phys_movable_cover` | 220 | heavy | **no** | **no** | 855.6 N |
| `phys_ballast` | 320 | heavy | **no** | **no** | 1244.4 N |
| `phys_anchor_block` | 500 | fixed | **no** | **no** | 1944.4 N |

Nothing above is restated from memory. The harness loads your real
`constants.gd` and your real `MassClass`, reads `FRICTION_HEADROOM` and the
friction derivation out of `manipulable_body.gd`, and takes gravity from
**your** `project.godot` rather than this one's — a different project's
setting would quietly move every number in the last column.

It also **refuses to run** rather than check a rule you have changed. Five
sabotages, five refusals: a moved `MassClass` threshold, a changed friction
derivation, a `receive_force` that started scaling, a rung of the ladder
emptied, and a prop with no mass.

### Two numbers in that table worth a second look

**`phys_cart` at 180 kg needs 700.0 N and the envelope has 700 N.** Not
approximately: `mu` is `2/3 × 700 / (120 × 9.8)` = 0.39683, and
0.39683 × 180 × 9.8 = 700.0. The verdict is reported as **"at the limit"**
rather than forced into yes or no, because rounding a tie is reporting
floating point as a design fact. If `ENVELOPE_FORCE_N` or
`FRICTION_HEADROOM` ever moves down, the cart stops being pushable and
nothing but this harness would say so.

**`phys_movable_cover` at 220 kg cannot be pushed by the envelope at all.**
Its own docstring says *"It exists to be got behind"* — cover you reposition.
At 855.6 N against 700 it is scenery. Its mass is Design 2 §10.1's, so Art
cannot lower it; if it is meant to be moved, 180 kg is the ceiling.

### And `lightened` does not rescue any of them

`lightened` is the one status `ECHO_STATUS_SUPPORTED_TARGETS` implements on
an `object`, and it moves ten of the twelve one rung down the ladder. It
does **not** make anything easier to push: your `receive_force` applies its
newtons unscaled and `impulse_scale()` doubles only an impulse — your own
comment says the distinction is deliberate and why. So `lightened` doubles
what one shove does and changes nothing about a sustained push.

The harness reports that, and it requires `apply_central_force(force)` and
`apply_central_impulse(impulse * impulse_scale())` to still be in your file
before it will say it. A claim about your code that survives a change to
your code is a claim nobody should trust.

---

## 2 · What changed in the art

### `phys_cart`'s `grip_bar` is now `push_bar`

This family's rule is that `grip_*` means a hand can lift it. The cart is
180 kg and carried a part named `grip_bar`. Its `proposes` string said *"a
push bar at one end"* — which is right, and which no runtime reading node
names ever sees. **A prefix that means two things means neither.**

`assert_grip_is_hand_scale` now refuses a `grip_*` part on any prop whose
`carriable` is false. It fails on the old cart and passes on the new one.

### Every manipulable prop has somewhere to show `lightened`

Eleven props gain `lightened_panel_0` and `lightened_panel_1`. Batch 045's
`sp_ballast_crate` already solved this for one crate; this is the same
answer for the rest, and it matters because `lightened` is the **only**
status the runtime implements on an object — `ManipulableBody.apply_status`
is the real path, and until now eleven of the twelve had nowhere to put it.

`phys_anchor_block` gets none. It is `manipulable: false`.

**Art declares the node; you decide what lights it and when.**

### They are FLUSH, and there is a gate about it

`ManipulableBody.create` derives a `BoxShape3D` from a size this family
declares. A fitting standing proud would silently change a collider on
twelve objects at once, and the only evidence would be a manifest number
moving. `assert_flush_with_body` measures each panel against the body's
**measured** box and refuses anything outside it.

**Every exported size is unchanged to within half a millimetre.** Checked
against the previous manifest, prop by prop.

### The export now declares what the field can do

Each prop gains an `envelope` block — `hold`, `push`, `push_force_n` — so
the question *can the player move this* is answered in the manifest rather
than recomputed by whoever reads it. It is **Art's transcription of your
numbers**, and the harness recomputes every verdict from your source and
fails on any disagreement. Three more sabotages, three more refusals: a
drifted `mass_class`, a drifted `hold`, and a tangency called a clean push.

`mass_class` was already exported and is now gated the same way. Two
transcriptions of Design 2 §10.2 — yours in `MassClass`, Art's in
`build_physics_props.py` — is exactly the arrangement that drifts.

---

## 3 · What I am NOT claiming

- **Not runtime-bound.** Nothing loads these. No `ManipulableBody` is
  created from one of them anywhere.
- **Not owner-approved.** Candidates.
- **No collision is shipped.** Not derived, not exported, not evidence —
  unchanged from Batch 043.
- **I have not moved a fitting on the 60-vs-120 finding.** See the headline.
- **`attach_*` does not track the envelope either**, and I have not made it.
  Today it is a crew-scale read: `phys_ballast` has four pads and cannot be
  moved by the field at all, while `phys_generic` has none and can be picked
  up. If you want one node prefix that answers *what can the field do with
  this*, say so and I will build it; inventing a third fitting family on my
  own initiative would be the same overreach as redrawing the girder.

---

## 4 · Reproduce

```
.tools/blender/blender -b --python tools/blender/build_physics_props.py
tools/content/run_props_preview.sh
tools/content/run_manipulation_readiness.sh
```
