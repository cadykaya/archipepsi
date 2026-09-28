# The repair pass: 049 hinges, the skiff's ends, the lightened panels

*Arty — 2026-09-28*

**The handoff** is `docs/art/review/repairs_2026-09-28/README.md`, on the
separate branch `claude/archipepsi-art-repairs-2026-09-28`, based on the
reviewed source `a1584c8`.

**What it is:** the narrow technical repairs the owner authorised after
the owner review. Each fixes one objective defect that review
documented, goes through the existing builder, and is kept separable so
Production can take one family without the others.

## Repaired

| Family | Commits | In one line |
|---|---|---|
| 049 hinges | `9231ce3`, `c4dbd90` | Six moving parts hang from real hinges, with positions declared in the manifest; nothing else moved |
| The skiff | `d48c361` | `*_fore` is now RailCarrier's FORWARD (+Z at `c12a72f`); same geometry, names swapped |
| Lightened panels | `e4103ba` | Their own material slot; the nine on fittings moved the shortest clear distance; no size, fitting, mass or class changed |
| Corrections | `dc0d879` | Dated notes on stale records, and on three errors in my own review |

Each family has a verifier, and each verifier fails on the old files.
`tools/check_art_current.sh` passes, so every model rebuilds
byte-identical from its source.

*Clarified 2026-09-28:* those runs read Production's default local ref
(`19c5d8e`), not the pin. They are not a current-Production
compatibility pass. At the pin, one gate fails; see the handoff's "Two
verification results, kept apart".

## Held, with the exact conflict recorded

- The room kits: Passing, Counterfire, Unweighted, and the yard anchor.
- `fx_bulwark_face`. It is a candidate effect, not the approved body.
- The diver trail.
- The danger-mark presentation. The runtime geometry is prepared in
  `DANGER_MARKS.md`.
- The ring, statuses, packs and withheld shells.

## My own corrections

- The bulwark-face wording blurred the effect and the body.
- D2 drew the charger's reach 0.9 m wide; it is 5.6 m.
- The carrier fixes I proposed would have conflicted with the pinned
  Passing room.

## Stopping point

Nothing is promoted, bound or integrated, and no Production file was
touched. There are no watchers.

**I have stopped for your remaining visual decisions.**
