# The yard's launch pad

**Arty** · art lane · branch `claude/archipepsi-art` · 2026-09-03

One authored value, corrected against the finalized launch-source
contract. Vera found all four Wave 1 shells structurally and physically
clean; this was the only number contradicting the contract.

> **Ruling.** `launch_source.position` is the exact room-local
> foot-contact centre from which the constructed launch fires.

---

## 1 · Head before

`468125ed8ef1f68e020406b63b3a7abe35528242`

Independent audit: `f97545f7812d53ad6923b8a4c4ad0cf07925a667`

## 2 · Canonical source changed

`tools/blender/build_yard.py` — the `src` tuple in the offers block, with
a comment naming the ruling. One value.

Also `tools/content/verify_manifest.py`, to declare
`shell_yard_gantry.offers` as a handoff change. Without it pyverify reads
the yard as **drift** against Production's landed pack and fails; the
declaration says what moved and why, so the disagreement is a recorded
handoff rather than an accident.

## 3 · Generated paths changed

* `assets/models/batch040/shells/manifest.json`
* `godot/content/registry/authored_art.json`

Both came from `build_yard.py` → `export_content_pack.sh`. **Nothing was
hand-edited into a mirror.** No `.glb` and no `.tscn` changed — an offer
is a declaration, and it moves no geometry and no markers.

## 4 · Exact before / after

```
shell_yard_gantry / launch_west

  was   (-28.0, 0.5, 26.0)
  now   (-28.0, 0.0, 26.0)
```

`yd_floor`'s top measures **y = 0.00**, so the pad was floating half a
metre over it — neither a stance nor a surface. Verified from the shipped
collider triangles rather than assumed.

`launch_span` moved **63.10 → 63.16 m** as a derived consequence of the
pair, not as a second change.

**Preserved exactly:** x, z, `radius: 3.0`, `target: launch_catwalk`.

## 5 · Validation

| check | result |
| --- | --- |
| `verify_manifest.py` (Production's `ContentManifest`) | **PASS** — 5 declared handoff changes, no other drift |
| `content_registry.gd` (Production's) | **PASS** — 21 entries load |
| `verify_collision.gd` | 12 shells, **0 needing attention** |
| Scene / manifest marker parity | **PASS** — 160 markers, 12 scenes, 0 disagreements |
| Flight surfaces, 0.10 m grid | 19 flights, **0 refused** |
| `replay_audited.py` | **PASS** — 12 audited findings all still found |
| `check_art_current.sh` | **PASS** — every generated asset rebuilds byte-identical |

The manifest and the Production-facing registry were compared field for
field on this entry and **agree**: both carry `launch_west` at
`[-28.0, 0.0, 26.0]`, and the full offers lists are equal.

`check_art_current.sh` came back with nothing to regenerate, so no launch
evidence needed refreshing — the yard has no manifest-derived launch
figure, unlike the hall. The ordinary workflow asked for nothing extra.

## 6 · Offer measurement

```
[offer] shell_yard_gantry   39 colliders, 0 non-convex
    rail_crane       ok       baked curve clears everything
    launch_west      ok       apex 11.5 m, flight 1.52 s
    grapple_0        ok       ground 10.60 m below
    grapple_1        ok       ground 10.60 m below
    grapple_2        ok       ground 10.60 m below

[offer] 24 offer(s) measured against real collision, 0 refused, 0 raised
[offer] PASS -- every declared offer survives the room it is in
```

## 7 · Geometry and yard height unchanged

`diff_shell_glb.py` against `468125e` reads both revisions of all 23
shell `.glb` files: **all 23 byte-identical, 0 malformed.** The yard was
not rebuilt into a different mesh.

| | before | after |
| --- | --- | --- |
| triangles | 516 | **516** |
| colliders | 39 | **39** |
| interior | 84.0 × **16.0** × 52.0 m | 84.0 × **16.0** × 52.0 m |
| `size_godot` | 85.2 × 17.6 × 52.0 | 85.2 × 17.6 × 52.0 |
| traversal | — | **identical** |
| surfaces | — | **identical** |
| sockets | — | **identical** |
| `rail_crane`, `grapple_0/1/2` | — | **identical** |

The ~16 m height, the mandatory route and every other room are untouched.

## 8 · Review states

All twelve unchanged. The eight P2 shells keep the owner's `pass`; the
four Wave 1 rooms — hall, plenum, span, yard — all remain **`pending`**.
Art wrote no verdict.

## 9 · Art commit

**`466fd4e`** — *The yard's launch pad is a foot-contact point, not a
hover* — pushed to `claude/archipepsi-art`.

---

## Note

No Art-side physics system was invented. The contact height was corrected
at the one authored value and measured with the paths that already exist;
the general real-physics contact gate stays Production's.

All four Wave 1 pads read a floor face now, as the hall's always did —
the plenum's and the span's were corrected earlier today under the same
contract (`docs/art/reports/2026-09-03-launch-pads.md`).
