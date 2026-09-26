# A10 — the ten-role enemy roster: readiness, anchors, and one blocker

> **CORRECTED 2026-09-26 — two claims below were not true of the shipped
> models until today.**
>
> 1. **The models faced +Z.** Their anchors and `enemy.gd` both face -Z,
>    so every shield, emitter and arm pointed away from its own anchors:
>    the bulwark's `anchor_weak` sat on its SHIELD side, not behind it.
>    A silhouette is the same from front and back, and item 5 of the
>    readiness harness ("which way does it face") was listed but never
>    implemented. Both are fixed: the geometry is turned to -Z at build
>    time, with a per-role front-part assertion, and the readiness gate
>    now refuses any front anchor that is not in front, or weak anchor that
>    is not behind.
> 2. **"Embedded inside the body" was inside the body's BOX.** Some markers
>    stood 1–2 px proud of the surface at 18 m (9 pixels across 7 views
>    before, 8 across 6 after the turn). Each is now walked into an actual
>    part, and the silhouette harness renders every view with the anchors
>    hidden and requires the same silhouette to the pixel.
> 3. **The 30 review frames were stale, and are regenerated.** The
>    runtime frames showed the pre-band skin, and the outlines still
>    carried the anchor bumps. They are rebuilt from today's models:
>    * each role in its standard value band (Tier 1, RULED);
>    * `ranged` and `bulwark` in their Tier 2 re-cut, which is for owner
>      review and inside the same envelopes;
>    * no anchor showing.
>
>    `readiness.json` changed only in those two roles' size and
>    triangle count.
>
> Nothing about the envelopes, the colliders or the anchor NAMES changed.
> See `2026-09-26-enemy-value-bands-and-L08.md`.

**Arty**

**To:** Prod (integration)
**Art head:** this commit, branch `claude/archipepsi-art`
**Checked against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

---

## What this is

A10.1–A10.3 and A10.6. **No new roster was invented and no approved
identity was replaced.** Batch 030's ten roles are reused as-is; what
changed is that each now exports named attachment nodes, and that the
whole roster has been put through Production's own consumer rules
rather than only through build-time assertions.

Evidence: `tools/content/run_enemy_readiness.sh` →
`docs/art/review/enemy_readiness_2026-09-22/readiness.json`, and 30
review frames in the same folder.

---

## 1 · THE BLOCKER: an authored enemy would take no damage tint

`Enemy._collect_tint_parts` walks the tree and takes **only** meshes
whose `material_override` is a `StandardMaterial3D`:

```gdscript
if child is MeshInstance3D:
    var shared: Material = child.material_override
    if shared is StandardMaterial3D:
        ...
```

**A glTF import puts its materials on the mesh SURFACES and leaves
`material_override` null.** So the rule finds nothing.

Measured, by applying your rule verbatim to each imported role:

```
artillery 0   beacon 0   brute 0   bulwark 0   charger 0
diver 0       drifter 0  melee 0   ranged 0    scuttler 0
```

**Ten roles, zero tintable parts.** Your own comment beside that
function says a damage tint that never appears is a bug with a test
against it — this is the same bug, arriving by a different door.

**This is yours, and I have not worked around it.** Art could ship
overrides baked into the scene, but that would be a second source of
material behaviour on an asset whose materials are already authored, and
this lane has made that mistake before. The smallest change, for you to
accept, amend or refuse:

> In `_collect_tint_parts`, when `material_override` is null, also
> consider `mesh.surface_get_material(i)` — duplicating it and assigning
> it back as the override, exactly as the current branch does. That
> keeps the unshare-once behaviour and makes it work for any authored
> visual, not just these ten.

`enemy_readiness.gd` will report the count as non-zero the moment that
lands, and it is gated in `check_art_current.sh`, so nobody has to
remember.

---

## 2 · A10.3 — every role now has named anchors

**They all used to arrive as one joined mesh.** The readiness harness
found that before anything else: ten roles, `nodes: 1` each, no named
attachment point anywhere. `build_enemy_roles.py` joined every material
bucket and then joined those into a single body, which is fine for a
silhouette and useless for hanging a muzzle flash on.

Each role now exports its anchors as **their own objects**:

| role | anchors |
|---|---|
| melee | `anchor_strike`, `anchor_warn`, `anchor_effect` |
| ranged | `anchor_muzzle`, `anchor_warn`, `anchor_effect` |
| brute | `anchor_strike`, `anchor_warn`, `anchor_weak`, `anchor_effect` |
| charger | `anchor_strike`, `anchor_warn`, `anchor_weak`, `anchor_effect` |
| bulwark | `anchor_shield`, `anchor_weak`, `anchor_warn`, `anchor_effect` |
| scuttler | `anchor_strike`, `anchor_warn`, `anchor_effect` |
| artillery | `anchor_muzzle`, `anchor_warn`, `anchor_weak`, `anchor_effect` |
| beacon | `anchor_muzzle`, `anchor_warn`, `anchor_effect` |
| diver | `anchor_muzzle`, `anchor_warn`, `anchor_effect` |
| drifter | `anchor_warn`, `anchor_effect` |

Plus `telegraph_seat` on every role, unchanged, at
`ENEMY_ENVELOPES[role].centre_y` — the point your `TelegraphOrigin`
`Marker3D` already sits on.

**They are nodes, not decoration and not behaviour.** 40 mm markers
embedded inside the body, painted in the body material. No hitbox, no
damage logic, nothing that animates.

**"Where specified" was taken literally.** The drifter gets no muzzle
and no weak side, because its whole read is that it gives away no
facing, and an anchor on its front would be Art deciding something the
silhouette deliberately refuses to say. The bulwark's weak side is
behind its shield, which is the role's entire proposition.

**They are placed off the body's MEASURED box, and that is a repair.**
The first cut used envelope fractions — and the bodies do not fill their
envelopes; the scuttler is 0.34 m tall inside a 0.62 m one. Eight
anchors across six roles ended up outside the geometry they are meant to
be points on, and the containment gate refused every one.

---

## 3 · A10.2 — the inspection, and what it found clean

Per role, through the real glTF path, against your published table:

| check | result |
|---|---|
| imports | 10 / 10 |
| fits `ENEMY_ENVELOPES` | 10 / 10, no axis over |
| floor origin | 10 / 10 at 0.000 |
| degenerate triangles | 0 |
| surfaces carrying a material | all |
| declared anchors present and inside the body | 10 / 10 |
| **tintable by your rule** | **0 / 10** — see §1 |

**Flying roles are authored on the floor**, not at hover height:
`diver` and `drifter` have `hover_height` 1.90 and 2.55 in your table
and the runtime lifts them. A mesh already authored at hover height
would be lifted twice. The review frames stand them at hover because
that is what a player sees; the exports do not.

**The harness refuses rather than passes when it cannot check.** Its
first version read `width`/`height`/`depth` from `ENEMY_ENVELOPES`,
which publishes a `size` Vector3 — ten roles threw "Invalid access to
property or key", and the run still printed PASS, because each error
aborted its role's checks after the envelope and before the tint count.
A harness that reports success while every one of its subjects threw is
the same defect as a filter that cannot express failure. The key shape
is verified now, and a missing key is a refusal.

---

## 4 · A10.6 — thirty frames, one camera

Ten roles × three passes, **all from the same camera at 7.5 m and eye
height**. Not framed per asset: framing each to fill the frame is what
makes a roster sheet lie about scale.

* **runtime** — the shipped Zone's ambient 0.35 and fog 0.012, no
  directional light.
* **silhouette** — flat black on light. The only honest test of "can you
  tell a sniper from a charger across a dark room".
* **clay** — form without material, so a shape problem cannot hide
  behind a texture.

Every frame is stamped with both facts A10.6 asks for: fit-checked
against the envelope, and **spawnable or not**. Three are green;
**seven say `NOT spawnable: ENEMY_ARCHETYPES is still
melee/ranged/brute`**, which is requirement 31 and is unchanged. An
unsupported role can be art-ready without being spawnable, and Art has
deliberately not routed around it.

---

## 5 · What is NOT done, precisely

**A10.4 and A10.5 — clips and phase markers — are not delivered**, and
I would rather say so than ship a loop per role to look complete.

Two things have to be settled first, and both are yours:

1. **Where an `AnimationPlayer` lives.** `Enemy.create()` builds
   `visual` as a bare `Node3D` and fills it with `BoxMesh` parts from
   `_build_melee` / `_build_ranged` / `_build_brute`. There is no
   authored-visual path into it, and no animation owner. An art-side
   `AnimationPlayer` inside the `.glb` would be a second thing driving
   presentation next to `_windup`'s swell.
2. **`visual` is scaled by gameplay.** The flinch and the windup swell
   scale that node, deliberately, so the collider never moves. A clip
   that also touches the root's scale fights it. A clip that only
   touches named children does not — which is an argument for
   articulated rigid parts over a skinned rig, and is what A10.3's
   "rigs OR articulated rigid-part transforms" leaves open.

**My proposal, not a decision:** articulated rigid parts, driven by
Production, with the art supplying named nodes and rest poses rather
than clips — the anchors above are the first half of exactly that.
A10.5 says gameplay determines attack timing, root translation,
interruption and death; presentation stretches to an authoritative
phase. If you name the phase signal, I will author to it.

The bodies are still single joined meshes apart from the anchors, so
**articulating them means splitting the buckets that currently join**.
That is a real day of work per role and it should follow the decision,
not precede it.

---

## 6 · What I am NOT claiming

- **Not runtime-bound.** Nothing instantiates these; see §1 and §5.
- **Not owner-approved.** Batch 030's review verdict is unchanged.
- **No identity was changed.** The governing silhouettes, surface
  stories and envelopes are exactly as approved; the triangle counts
  rose only by the anchors.
- **The anchors' positions are Art's reading of each silhouette**, from
  the body's measured box. If a muzzle should be somewhere else on a
  role, that is a one-line change in `ANCHORS` and I would rather be
  told than guess.
- **`anchor_effect` is the weakest of them** — "where a hit effect or a
  status glyph goes" is a presentation decision I have made at the body
  centre for every role, which is defensible and not considered.
