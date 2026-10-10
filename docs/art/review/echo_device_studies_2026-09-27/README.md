# Four directions: DIY Echo electronics

*Arty*

Track A2, the third ruling of 2026-09-27. These are four visual-direction
studies of the four-wall menu as **one hand-built Echo device** that
Epsilon assembled. They are composition and art-direction studies, not
menus. **I have stopped here so you can choose a direction, or particular
elements that work together.**

**Start with `00_compare_equipment.png`, then `00_compare_overviews.png`.**
Those two sheets put the four side by side. Everything else is one
direction at a time.

## What is in the package

Each direction has the same seven images, named `<letter>_<n>_<what>.png`:

| File | What it shows |
|---|---|
| `X_0_overview.png` | The four walls as one device, in the order you meet them turning right: Journal, Map, Equipment, Settings. A magenta ring marks where the Journal's link rounds the corner into the Map. |
| `X_1_equipment_normal.png` | Equipment at 1280 × 720, the normal state. |
| `X_2_equipment_stress.png` | Equipment at 1280 × 720 in the long-name, long-description state, against the same comparison. |
| `X_3_map_detail.png` | The Map at 1280 × 720: Arena 1 picked, its detail open, the Journal's link ringed. |
| `X_4_journal.png` | The Journal at 1280 × 720. This is a rougher study. |
| `X_5_settings.png` | Settings at 1280 × 720. This is a rougher study. |
| `X_6_motion.png` | The annotated motion frames: one press of DOWN (before and after), and two page turns. |

The screens are at gameplay size, so you can judge readability on them.
The overview is extra context and does not replace them. Everything magenta
is a review mark drawn over the picture; it is not part of any direction.

## What is the same in all four

- **The data.** It is Production's `a2b9df6` fixtures, plus the
  layout-stress Echoes, which are tagged AUTHORED wherever they appear.
- **Equipment.**
  - RMB is focused, with BRAIDED LASH on it.
  - In the normal state, ARC BOLT is inspected against BRAIDED LASH.
  - In the stress state, UNDEAD PARISH LONGSHOT OF THE CORRIDOR WHERE
    NOTHING ANSWERS is inspected against it.
  - The comparison lines are Production's, set as a table aligned on the
    arrow.
- **The Map.**
  - Arena 1 is picked and MapFace's own detail is open.
  - The Journal's link is ringed: the shut way from Arena 1 to Platform
    Path 1, held by span alignment.
- **The Journal.** That link is the focused entry.
- **Settings.**
  - Production's own items, at PlayerSettings' own defaults.
  - Each slider sits where its default value falls on its own range. For
    example, mouse sensitivity sits about a tenth of the way along.
- **The words.**
  - The prototype's own words are used: "ON RMB", "FITS RMB",
    "IF ON RMB, IN PLACE OF BRAIDED LASH", "PREVIEW ON RMB",
    "ALWAYS ON · NO KEY".
  - "Echo weapon" and "Echo suit" are never used as names. No slot has been
    added, and no unavailable Gear is shown.
- **The controls.**
  - The prompt line is the prototype's own, on every wall.
  - In every direction the keys are a list to the left of the items that
    fit, and both lists run top to bottom. UP and DOWN, LEFT back to the
    keys, and ENTER to preview all mean what they mean now.
  - There is no dragging and no wiring task.
- **The Map's window.**
  - It shows the prototype's own truthful miniature: FaceMap's lens,
    tags, frames and link ring, with the rooms where they really are.
  - Nothing inside the window is restyled, rearranged or recoloured.
  - Circuit, gate and key colours are untouched.
  - In each direction the Journal's link is a neutral colour: cream,
    ivory, brass or a grey ribbon. It is never a circuit colour.
  - The link ends in the same guide stroke, which comes down onto the
    passage from above.

---

## A — Patchbay / signal bench

**Why it is distinct.** Three separate instruments stand on a warm bench:
the key panel, the module bay, and the readout. The layout is organised
around the one live connection. The focused key's cream cord arches over
the top, from RMB's jack to the jack of the module plugged into it, and the
readout hangs under that arch. A teal test lead runs from the inspected
module's jack into the readout. The same cords carry across the walls:

- The Journal's focused finding has a jack. Its cord rounds the post and
  plugs into the Map's bezel.
- The Map's detail is a readout patched in from the bezel.
- Settings is the bench's calibration surface: faders at their real
  defaults.

**How selection and a page turn move.**

- **DOWN:** the test lead's plug lifts out of one jack and drops into the
  next. The readout reads the new module in place. The key's cord and
  every other jack stay still.
- **Choosing another key:** that key's own cord becomes the lit one.
- **A page turn:** a plain turn. SHOW ON THE MAP is the follow, and the
  turn happens along the cord.
- **Reduced motion:** the plug and the turn simply cut, and the frames are
  the same.

**Main usability risk.** The readout stands between the two lists.
RIGHT from the keys therefore jumps across it, and comparing the lists
means looking past it. Only the focused key's connection is drawn, so what
the other keys hold is read from their rows, not from cords.

## B — Routed harness / cable loom

**Why it is distinct.** There are no panels. One black laced trunk runs
round all four walls at one height and rounds every post, and everything
hangs from it:

- Each wall's title is a flag label on the trunk.
- The readouts are card tags hung from it.
- On Equipment, the key loom drops from the trunk. The focused key's pale
  branch leaves the loom at RMB, runs across and down, and encloses the
  modules that fit RMB. The inspected module's breakout runs on into the
  tag, where what it does and what changes are read first.
- The Journal's link is its own ivory wire, laced along the trunk round
  the corner and dropping into the Map's window over its place.
- On Settings, each slider is a sleeve on a taut wire.

It is the strongest "one device" read in the overviews.

**How selection and a page turn move.**

- **DOWN:** the teal tap slides one module down the branch, and the
  breakout's clip slides with it along the tag's edge. The tag reads the
  new module in place and never swings.
- **A page turn:** the eye follows the trunk.
- **SHOW ON THE MAP:** a pulse runs out along the ivory link and down into
  the window before the view settles. Q and E turn along the same trunk
  with no pulse.
- **Reduced motion:** no pulse, and the turn cuts.

**Main usability risk.**

- The pale tag is the brightest thing on the wall. That is right for
  "what it does", but it dominates, and in a dark room it could glare.
- The trunk band takes about a hundred pixels of height on every wall.
- Hanging tags invite a swing that must never move their words.

## C — Relay cabinet / breaker logic

**Why it is distinct.** C is split top and bottom, where the others are
not. A wide inspection window runs across the top of the cabinet, with what
the module does beside what changes on RMB. A brass bus runs under it, and
the mechanism sits below:

- A rotary key selector, with the keys on an arc round its dial.
- A card rack.

Assigned and inspected are told apart by seated and pulled. The card on
RMB is seated and strapped to the bus the selector is on. The card being
read is pulled out.

Every physical state is interface data:

- The pointer is the focused key.
- Each key's flag window shows what the key holds, and its charges.
- The Journal's flag windows show each connector's own state.
- ALWAYS ON is a strip with no switch on it, because there is none.

Nothing shows power, faults, locks or progress.

**How selection and a page turn move.**

- **DOWN:** one card slides home and the next is pulled, a short travel
  with a detent. The window's shutter drops and rises over the change, so
  its words swap while they are covered.
- **A key change:** the selector clicks one detent.
- **SHOW ON THE MAP:** the brass rod's pointer arm drops into the port over
  the passage. Q and E leave it up.
- **Reduced motion:** everything simply sits at its end state.

**Main usability risk.**

- The rack shows 9 of the 13 items and scrolls ("4 MORE BELOW"), with
  cards 33 px apart.
- The arc of keys scans less straight than a column does.
- The mechanical parts invite dragging or pulling where the menu needs only
  a selection. Each hit area has to stay the whole row.

## D — Salvaged Echo workbench / prototype board

**Why it is distinct.** Irregular boards stand on standoffs and overlap:

- A green main board with a header per key, and the module on each key
  seated in its header.
- A bare phenolic add-on, bridged on, for ALWAYS ON.
- The inspected module lifted over the board. It is black, and its gold
  connector edge faces RMB's outlined place, so you see where it would go.
  What it does and what changes are printed on it.
- A spares tray that keeps a slot for every module that fits. The two that
  are out, the one on RMB and the lifted one, leave their slots empty and
  say where they are.

The Map and the Journal are boards of the same assembly, not paper, and a
ribbon cable carries the Journal's link round the corner.

**How selection and a page turn move.**

- **DOWN:** the lifted module drops back into its slot, and the next one
  lifts out to the same reading place. Its words move rigidly with the
  board.
- **SHOW ON THE MAP:** the ribbon's connector seats on the Map's header over
  the passage. Q and E leave it unseated.
- **Reduced motion:** the swap and the seating are cuts.

**Main usability risk.**

- Overlap. The lifted module covers part of the main board, and irregular
  outlines make hit areas less obvious, so targets need clear bounds.
- It is the most layered direction, so it is the one most at risk of
  clutter if more detail is added.
- The tray's two-line cards make a dense, narrow column.

---

## Elements that would combine

If you would rather take parts than a whole direction:

- **Seated versus pulled (C)** answers "assigned versus inspected", and it
  would work in A, B or D.
- **A continuous trunk round the box (B)** can carry any direction's
  Journal link: A's cord, C's rod or D's ribbon.
- **D's lifted module and C's inspection window** are two answers to the
  same question, where to read the inspected item. It is better to pick
  one than to stack them.

## Evidence and limits

| Scope | Status |
|---|---|
| Implemented | An isolated review scene, `tools/menu_proto/studies/`, with one script per direction. Every image here is rendered from it. |
| Exercised by scripted input through the real input path | **None.** The study scene reads no input. The stills are scripted camera shots of static compositions. |
| Hands-on | **Not done.** |

- **The prototype.** It is unchanged apart from one additive caption hook
  in `overlay.gd`, and its 225 checks pass.
- **Motion.** It is described and shown in stills. Nothing animates in the
  study scene, and there are no videos.
- **Lighting.** The renderer used for these stills ignores a light's cull
  mask, so the miniature's own light also falls on the Map's wall and, at
  a glancing angle, on the Journal's. Pale surfaces on those two walls are
  toned down to compensate. This happens only in the studies.
- **Scope.** Nothing is integrated, and no Production-owned file was
  edited. Nothing here opens 0.5, Track C or Track E.
- **The checkpoint.** The inventory pass (build `66e18b2`, delivered at
  `91e5d3f`) is untouched.

To regenerate every image here from source:

    tools/menu_proto/studies/stage.sh docs/art/review/echo_device_studies_2026-09-27

This needs Godot 4.5.1 at `.tools/godot`, `xvfb-run`, and Python with PIL.
