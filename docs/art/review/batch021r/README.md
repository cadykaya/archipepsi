# Batch 021-R — `arch_duct` evidence

**Status: PENDING.** Evidence only. **The asset is unchanged** — no
geometry, no material, no dimension. The owner passed five of the six
Batch 021 modules and held `arch_duct` for one reason: `S_services_family`
rendered it edge-on and small beside the vent, so silhouette, construction,
attachment and section seams were not actually reviewable.

These two shots are those four things and nothing else.

| Sheet | What it answers |
|---|---|
| `R_duct_detail.png` | silhouette and construction. Flanges at both ends and mid-run, two hangers with straps, the 0.62 × 0.46 section hung 0.22 clear — inside `CEILING_GAP` 0.5, which is what makes it service rather than structure. |
| `R_duct_run.png` | attachment and repeated sections. Two sections chained under two `arch_ceiling_plain` bays, seen from below. |

## Why the run shot is composed the way it is

The duct module is **4.0 m** and `arch_ceiling_plain` is **4.0 × 4.0**, so
sections and bays share one grid. That is the claim a repeated-section shot
has to test, and the frame shows the seam landing on a flange rather than
on a gap.

It is shot from **below**, at negative elevation. The first attempt used
+10 and rendered the top face of the ceiling bays with the ducts hidden
underneath — a view no player will ever have of a ceiling service.

Both shots use `backdrop: "none"`. `arch_duct` and `arch_ceiling_plain` are
**ceiling**-anchored, so their geometry hangs below the origin and the
runner's default floor slab sits on top of them. The first attempt rendered
a tilted grey plane with two dark specks on it. That is L-63 again: an
asset that is not an object standing on a floor must not be given a floor
to stand on.

## No problem found

The renders were made to expose a problem if one existed. They did not.
The flange reads at both ends and mid-run, the hangers meet the ceiling
they hang from, and the chained seam is a flange rather than a gap. So the
asset was not touched — per the owner's instruction not to change it merely
to justify the revision.
