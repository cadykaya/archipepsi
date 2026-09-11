# Batch 043 / C — Design 2's twelve object classes, mapped

**Arty**

Design 2 §10.1, pinned by Design 6 §4.7. Twelve classes, each with a typical
mass and two flags. Below: what the catalogue already covers, what needs
adaptation, what is missing, and which **six** were taken through to
textured exported candidates.

**Masses, carriable and manipulable are the design's and are quoted.
Everything else in this file is a proposal.**

---

| class | mass | carry | manip | derived class | state | note |
| --- | ---: | --- | --- | --- | --- | --- |
| `GENERIC` | 15 | yes | yes | `LIGHT` | **COVERED** | `prop_crate`, PASS. 1.0 m — exactly `MAX_VERTICAL_STEP`, so it is also a step |
| `WEIGHTED` | 140 | **no** | yes | `HEAVY` | **BUILT** | `phys_weighted`. §10.1 changed this class from carriable *specifically* so it would feel different, so it must not read as a crate that got bigger |
| `POWER_CELL` | 40 | yes | yes | `MEDIUM` | **BUILT** | `phys_power_cell` |
| `KEY_COMPONENT` | 8 | yes | yes | `LIGHT` | **BUILT** | `phys_key_component`. The lightest of the twelve; the read is entirely scale |
| `MECHANICAL_PART` | 55 | yes | yes | `MEDIUM` | **BUILT** | `phys_mechanical_part` |
| `MOVABLE_COVER` | 220 | no | yes | `HEAVY` | **GAP** | `breakwall_panel` is a destructible, not a cover. Different mechanic, similar silhouette — do not reuse |
| `CART` | 180 | no | yes | `HEAVY` | **GAP** | constrained to a floor path or rail; needs wheels or a rail shoe that says so |
| `GIRDER` | 95 | no | yes | `MEDIUM` | **BUILT** | `phys_girder` |
| `BALLAST` | 320 | no | yes | `HEAVY` | **BUILT** | `phys_ballast` |
| `PLATE` | 60 | no | yes | `MEDIUM` | **ADAPT** | `prop_wall_plate` (PASS) is 0.90 × 0.10 × 0.62 — a wall dressing at a tenth of the mass. The name matches and the object does not |
| `DRUM` | 70 | no | yes | `MEDIUM` | **ADAPT** | `prop_oil_drum` (PASS) is 0.78 × 0.78 × 0.95 and rolls. One pass of handling fittings, not a rebuild |
| `ANCHOR_BLOCK` | 500 | no | **no** | `FIXED` | **ADAPT, CAREFULLY** | `anchor_a_soffit` / `anchor_b_jib` are **grapple** anchors. Same word, different mechanic. Reusing them on the name alone would put a grapple point where a world attachment belongs |

`mass_class` is derived from `mass_kg` by §10.2 and never declared. The
derived column above is computed by `build_physics_props.py`, not typed.

---

## Which six, and why those six

The brief named four — `POWER_CELL`, `MECHANICAL_PART`, `GIRDER`, `BALLAST` —
and all four were **GAP**, so nothing was rebuilt that already existed.
`KEY_COMPONENT` and `WEIGHTED` followed with the time that was left, and they
were chosen over `CART` and `MOVABLE_COVER` for one reason: **they complete
the mass ladder.**

    8 kg    40 kg    55 kg   |  95 kg    140 kg    320 kg
    ---- carriable ----------|---------- manipulate only ----------
                        §10.3's 60 kg line

The question a player asks of one of these objects is *"can I lift that"*,
and the answer is only learnable by comparison. Six rungs make the ladder
legible in a single line-up; four left two gaps in the middle of it.
`room/PROPS_lineup.png` is that line-up.

Where an existing candidate would have done, it was left alone: `GENERIC` and
`DRUM` were not touched, and the effort went into the gaps instead.

## The family rule

Design 2 §33.7, always: *"Manipulable objects have a consistent material
treatment; `FIXED` objects visibly do not share it."*

A coloured sticker satisfies the letter of that and fails §50's
no-hue-alone rule the moment the room is dark. So the treatment is
**unpainted dark steel — flat, smooth, and far below any painted body in
value — and it appears only on the surfaces the player's device touches.**

The first attempt used a *light* bare metal, and it failed in the room.
`concrete_facility`'s painted bodies sit at L\* 60–70, and a light steel pad
landed straight on top of them: a 16 cm attach pad on the ballast read as a
stain. Dark is not a style choice, it is the side of the value axis that was
free. It sits about 45 L\* below a painted body, which survives grayscale,
distance and an unlit room.

Nothing decorative in the catalogue carries it — `prop_crate`,
`prop_oil_drum` and `prop_debris` are painted end to end — so *"has a bare
dark fitting"* and *"you can do something to it"* are the same statement.
`room/PROPS_manipulable_vs_decorative.png` is the frame that has to carry it.

The second half of the rule is the read between carriable and merely
manipulable, which §10.3 draws at 60 kg:

| | fitting |
| --- | --- |
| `KEY_COMPONENT` 8, `POWER_CELL` 40, `MECHANICAL_PART` 55 kg | **one hand-scale D-grip**, on top |
| `GIRDER` 95, `WEIGHTED` 140, `BALLAST` 320 kg | **device attach pads**, and no grip at all |

A hand grip means a hand can lift it. Its absence, on an object that plainly
has attachment features, means a device has to.

## The four candidates

| | class | mass | derived | exported size (m) | tris |
| --- | --- | ---: | --- | --- | ---: |
| `phys_key_component` | `KEY_COMPONENT` | 8 | `LIGHT` | 0.25 × 0.20 × 0.35 | 108 |
| `phys_power_cell` | `POWER_CELL` | 40 | `MEDIUM` | 0.34 × 0.34 × 0.60 | 148 |
| `phys_mechanical_part` | `MECHANICAL_PART` | 55 | `MEDIUM` | 0.47 × 0.40 × 0.43 | 136 |
| `phys_girder` | `GIRDER` | 95 | `MEDIUM` | 3.20 × 0.20 × 0.26 | 84 |
| `phys_weighted` | `WEIGHTED` | 140 | `HEAVY` | 0.82 × 0.91 × 0.70 | 108 |
| `phys_ballast` | `BALLAST` | 320 | `HEAVY` | 1.12 × 0.82 × 0.50 | 120 |

All six are at 64 texels/m — the prop budget's target — origin floor-centred,
+X the length and +Z up. Attachment points, with positions and normals, are
in `assets/models/batch043/physics/manifest.json`.

`phys_key_component`'s keyed bit is deliberately **asymmetric** — a symmetric
bit would enter a receiver either way round, which makes it a plug rather
than a key. `phys_weighted` carries its two attach pads on **opposite** faces
because §10.1's own fixtures push it along an axis rather than lift it.

**Every dimension above is a PROPOSED ART DIMENSION.** No runtime contract
for object size or attachment interfaces exists, and this file is not one.
When a contract arrives, these move to fit it.

**No collision.** None is derived, none ships, and nothing here is traversal
or physics evidence. Player physics, mass rules, carry limits and package
schemas are untouched.

## One thing the renders changed

The ballast was first built at 0.86 × 0.66 × 0.66 — near enough a cube that
in the room it read as `prop_crate` in a bigger size, which is the one thing
a 320 kg counterweight must not do. It is now 1.04 × 0.74 × 0.54 with heavier
skids and a crown: a 2:1 footprint-to-height block. **Weight is proportion
before it is texture**, and the flat texture sheet could not have told me
that. The room could.
