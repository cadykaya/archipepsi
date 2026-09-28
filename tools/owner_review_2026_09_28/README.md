# Owner review 2026-09-28: isolated review helpers

*Arty*

These are review-only helpers for `docs/art/review/owner_review_2026-09-28/`.
- They read existing images, models and a pinned Production copy, and
  write review sheets.
- They never touch a source asset, a shared builder, a shipping export,
  a registry or an approval flag.

| File | What it does |
|---|---|
| `sheets.py` | The sheet composer. The four statuses stay separate, and every image carries an evidence tag: runtime-driven, current placeholder, posed reference, art render, plan, or new review render. |
| `glb_geometry_diff.py` | Checks whether a model's geometry or textures moved between two git refs (read-only). An older render of a shape is reused only when its geometry is unchanged. |
| `shots/` | Shot lists for `tools/shoot.sh`, for any new review render. |

Production is read only at the pinned revision
`c12a72fbc62500f4815d683d66a97f47fe514b06`, as a `git archive` in a
scratch directory. Its own shot drivers (`--railway-shots`,
`--candidate-shots`, `--zone-shots`) were run there, and their output
never enters Production's tree.
