# The hybrid: original station hardware, kept alive by Epsilon

*Arty*

This is the one hybrid visual checkpoint from the fourth ruling of
2026-09-27. **It selects a composition. It is not final visual acceptance
or hands-on acceptance, and I have stopped here so you can confirm it.**

- The four studies (`8b13aa7`) are untouched.
- The working prototype (build `66e18b2`) is untouched.
- The hybrid uses the same sample, states, comparison, map place and
  Journal link as the four studies.

**Start with `H_0_overview.png`.** It shows the four walls as one device,
with the two joins marked. Under the walls, each join is seen in 3D.

| File | What it shows |
|---|---|
| `H_0_overview.png` | The cross-wall overview. (1) is the harness and the Journal → Map link; (2) is the Equipment → Settings transition. |
| `H_1_equipment_normal.png` | Equipment, 1280 × 720: ARC BOLT inspected against BRAIDED LASH on RMB. |
| `H_2_equipment_stress.png` | Equipment, 1280 × 720: the long-name, long-description item against the same comparison. |
| `H_3_map_detail.png` | The Map, 1280 × 720: Arena 1 picked, its detail open, the Journal's link ringed. |
| `H_4_journal.png` | The Journal, 1280 × 720. |
| `H_5_settings.png` | Settings, 1280 × 720. |
| `H_6_turn_journal_map.png`, `H_7_turn_equipment_settings.png` | The two joins at full size, half-way through each turn. |

## Original and salvaged: how the parts relate

**Original station hardware** is formal, square, riveted and evenly
spaced. It is:
- the graphite enamel enclosure on every wall;
- Equipment's cabinet: the inspection window, the key selector, the
  brass bus and its terminal block, and the ALWAYS ON strip;
- the Map's heavy port.

The key selector is the oldest and most formal part. Its pointer is the
focused key, and each key's backlit window says what that key holds.

**The harness** is the shared infrastructure. One laced trunk runs round
all four walls and every corner, held by the same saddle clamps
everywhere.
- Every wall's title is a warm flag label on it.
- The Map's detail is a warm tag hung from it.
- The Journal's findings hang from its runs.
- The focused finding's ivory link is laced along the trunk round the
  corner, and drops into the Map's port over the passage.
- It feeds the cabinet through a gland on Equipment, and the maintenance
  boards on Settings (through Epsilon).

**Salvaged electronics** are the parts that were added or rebuilt.

*Equipment's item rack.* The cabinet's own bay was narrower. Its riveted
frame survives on the top and the left, and the top bar is cut off where
the rebuilt rack outgrew it: a bright cut face, then the empty holes of
the rivets that went with the rest of the bar.
- An aluminium adapter plate is bolted into the old bay.
- A paper-phenolic backplane stands on brass standoffs and runs out past
  the bay to the wall's edge.
- The modules plug into it as one clean list, with no dragging and no
  wiring.
- It is wired back into the original bus: the bus's terminal, a short
  lead, an adapter board, then a ribbon to the backplane.
- Its second ribbon runs round the corner into Settings.

*Settings.* It is nearly all replacement boards, of three stocks over the
old enclosure:
- bare FR4 for PAUSED;
- paper phenolic, the rack's own stock, carrying a salvaged character
  display for CAMPAIGN; the rack's ribbon lands on this board;
- black mask for OPTIONS.

The boards are joined by tinned bridges and a short ribbon, and the old
enclosure shows between them. The controls are repurposed: push switches,
slide pots and a bat switch, each at its real value, each labelled by hand
on embossed tape. The values sit in the same backlit windows as the keys.
It looks salvaged, not broken: there are no faults, no chores and no
puzzles.

**A few joins, each one legible:**
- bus → terminal → adapter board → ribbon → backplane;
- backplane → ribbon → round the corner → Settings' phenolic board;
- trunk → gland → cabinet;
- trunk → Epsilon → Settings' terminal;
- the Journal's tag → the ivory link → the Map's port.

**What unifies them** without averaging them:
- the harness;
- one typeface at one set of sizes;
- SIGNAL for what is focused or can act, on every wall: the pulled
  module's tab, the preview button, RESUME, and the focused finding's bar;
- the backlit window for what something is: a key's item, "ON RMB", a
  setting's value;
- recurring mountings: rivets on original parts, brass standoffs on
  salvaged ones, and saddle clamps on the harness.

**Equipped versus inspected** stays C's. The module on the key is seated in
the rack, and its window says ON RMB; the key's own window says BRAIDED
LASH. The module being read is pulled out, its tab lit, and the window
above reads it. A's panels, sockets and cable are not used.

## Epsilon

- **One restrained point, on Settings,** the maintenance side. Near-black
  plating bursts through an ordinary bolted grey plate of the old
  enclosure. It is asymmetric, with identity green only from inside,
  through its seams, and one aperture. These are the Style Lock's own terms
  (ART_BIBLE §1a).
- **The harness's drop to the maintenance boards runs through him:** he is
  in the machine's wiring, not beside it.
- **Nothing is written on it.** It is not a slot, a setting or a status
  light, and nothing suggests his transfer between the suit and the
  terminal.
- **Green is his alone.** The art bible reserves green for Epsilon
  ("Nothing else may be green"). So the salvaged boards here are paper
  phenolic, black and bare FR4, instead of D's green, and his is the only
  green in the menu. If you want D's green boards back, it is one constant.

## Proposed motion

Physical parts never make browsing wait.
- **Rapid selection (UP/DOWN in the rack):** the readout's words swap
  whole, in the frame the input arrives. The pulled module slides out in
  about 0.1 s, and the last one slides home at the same time; nothing
  waits for either. There is no shutter.
- **A key change:** the selector clicks one detent in about 0.1 s, and the
  rack's list swaps at once.
- **Preview (ENTER):** the pulled module seats, and "PREVIEW, NOT SENT"
  reads at once.
- **Page turns:** they turn as they do now, and the harness carries the eye
  round the corner.
- **SHOW ON THE MAP:** it frames the destination, with the way back, as the
  prototype does. A short pulse along the ivory link plays during the turn
  and never delays it. Q and E are plain travel, and keep the view.
- **Equipment → Settings:** nothing animates; the ribbon and the shared
  phenolic carry the eye.
- **Tags and flags:** they are rigid. They never swing, and their words
  never move.
- **Reduced motion:** no slides, pulses or clicks. Every state is a still
  with the same information.

## Evidence and limits

| Scope | Status |
|---|---|
| Implemented | `tools/menu_proto/studies/dir_h.gd`, in the isolated study scene beside the four studies. |
| Exercised by scripted input through the real input path | **None.** The scene reads no input. |
| Hands-on | **Not done.** |

- **Motion:** described here, not animated. There are no videos.
- **The rack:** it shows 9 of the 13 items ("4 MORE BELOW"), as C did. The
  prototype's rail scrolls too.
- **Lighting:** pale surfaces on the Map and Journal walls are toned for the
  renderer's light leak, as in the studies.
- **Scope:** not integrated, and no Production-owned file was edited.

To regenerate every image here from source:

    tools/menu_proto/studies/stage_hybrid.sh docs/art/review/hybrid_checkpoint_2026-09-27
