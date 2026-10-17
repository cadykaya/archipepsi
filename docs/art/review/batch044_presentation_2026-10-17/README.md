# Batch 044's triad and terminus: the presentation variant sheet

*Arty — 2026-10-17*

These are **disposable review** images. Nothing is approved, and the committed rooms in `assets/models/batch044/shells/` have not changed. Skyiah picks. The report is `docs/art/reports/2026-10-17-batch044-presentation-variants.md`.

Each sheet shows the control (as built and committed, outlined in yellow) and seven variants, all from the same camera, one variable per tile:

1. skin
2. base
3. top
4. face
5. board
6. trunks
7. all of them together

**The images are not in git** (Skyiah, relayed by Condi, 2026-10-17: git space is limited). They were sent in chat. `tools/batch044_presentation.sh` regenerates them exactly, and the numbers file is the record.

| File (sent in chat; regenerated, not committed) | What it is |
|---|---|
| `B44_0_overview.jpg` | **Start here.** Control against all, in all four views. |
| `B44_1_junction_triad_1_the_approach.jpg` | triad, 2 m inside the entry, looking up the spine |
| `B44_2_junction_triad_2_the_decision_point.jpg` | triad, the middle, looking into the west bay |
| `B44_3_bay_terminus_1_one_neighbour_both_branches_sealed.jpg` | terminus, from the door |
| `B44_4_bay_terminus_3_the_open_branch.jpg` | terminus, from the chamber, towards the open branch |
| `batch044_presentation_numbers.json` (committed) | view-change shares per view and variant, and the route walk per variant |

How the frames and numbers are made:
- The frames are `furnished_view.gd`'s stamped previews: props only at declared points, capsules for occupancy. They are not edited.
- The number on each tile is the share of the frame whose grey moves by more than 24 against the control. It measures how loud the part is, not whether it is better.
- The images are JPEG at q92 with no chroma subsampling.
