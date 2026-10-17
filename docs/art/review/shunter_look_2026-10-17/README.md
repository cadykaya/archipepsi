# The Shunter's look: the variant sheet

*Arty — 2026-10-17*

These are **disposable concept** images. There is no production model. Nothing is approved; Skyiah picks after she has played the fight. The report is `docs/art/reports/2026-10-17-shunter-look-sheet.md`.

The sheet shows seven looks against C0, the control (pose-study B), and R, a reference replica of Prod's graybox in `unified-1`. Each look changes one variable against C0. Every look uses the same poses, envelope, yard, cameras and the game's 90° view.

**The images are not in git** (Skyiah, relayed by Condi, 2026-10-17: git space is limited, so review renders and sheets stay out of the repo). They were sent to her in chat. `tools/shunter_looks.sh` regenerates them exactly, and the numbers below are the record.

| File (sent in chat; regenerated, not committed) | What it is |
|---|---|
| `SL0_overview_DISPOSABLE.jpg` | **Start here.** Per look, the four moments that must read: the horn at 20 m, the brace at 14 m, the side silhouette at 8 m, the vents from behind at 6 m. Each has its number. |
| `SL1_front_20m_DISPOSABLE.jpg` | front, 20 m: all four states per look |
| `SL2_front_14m_DISPOSABLE.jpg` | front, 14 m: all four states per look |
| `SL3_side_8m_DISPOSABLE.jpg` | side, 8 m: all four states per look |
| `SL4_rear_6m_DISPOSABLE.jpg` | rear quarter, 6 m: all four states per look |
| `shunter_look_numbers.json` (committed) | every number on the sheets |

How the cells and numbers are made:
- Cells are cut from the in-engine frames and enlarged nearest-neighbour, so no detail is invented.
- The numbers are grey-level changes larger than 24, counted inside the crop:
  - for work, the silhouette against the empty yard;
  - for the other states, the change from that look's own work frame.
- The brace is measured without its lit lane, which is the same in every look. The images still show the lane.
- The images are JPEG at q92 with no chroma subsampling.

Everything is regenerated from source with `tools/shunter_looks.sh`, using `study_shunter_looks.py`, `shunter_looks.py` and `dcap.gd`. Nothing is retouched.
