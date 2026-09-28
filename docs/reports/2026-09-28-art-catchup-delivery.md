# The art catch-up: what is now in the game

*Prod — 2026-09-28. The brief (`docs/ledgers/assignments/PROD_ART_CATCHUP_ASSIGNMENT.txt`),
reconciled against the work that already existed.*

**The delivery:**
- **The build:** `archipepsi-0.4-ART-CATCHUP-<rev>.zip`, pinned. The
  revision is in `ART-CATCHUP_BUILD_NOTE.txt` inside it.
- **This report,** with the before/after gallery (`images/`), in one
  archive.
- **The table:** every family, integrated or not, with its evidence and
  lane, in `docs/reports/2026-09-28-art-catchup-reconciliation.md`.

**Recovery points, all kept:**
- The menu-only checkpoint `ce6ea3bd`: its build, report and CK11 record,
  on `review/menu-int-ck11-ce6ea3b`.
- The finishing pass `e708c5fa`, with CK12 at 92 of 92. It is now the
  0.4 head, `e0421aaa`.
- Each art family is its own commit on `wip/0.4-art-catchup`.

## What you will see

Here is what is new in normal play.

**Enemies:**
- Every enemy wears the approved art body, in its room's value band:
  standard, or darker in rusted_industrial and void_glitch.
- These keep working as before:
  - the red/orange eye (idle, alert, windup);
  - the flinch and the wound tint;
  - facing and the weak side;
  - the collider, speed, reach, damage and spawns.
- Shots start at the art's muzzle.

**The Hub and the Echo Lab:**
- Epsilon's installation stands in its back-wall bay beside the portal.
  The two boards now have their approved housings.
- In the Echo Lab:
  - The height wall's call-outs sit at 1.0 m (a step) and 1.333 m (a
    jump).
  - The runway's reach mark sits at 4.667 m, a flat jump.
  - The hazard crate is the striped warning crate; its light says armed
    or safe.
  - The dummy is a plain facility post.

**In every Zone:**
- The exit portal is the approved wound. Sealed, it is grown over; open,
  it is torn back. The difference is in the shape, not the colour.
- Breakable panels, bounce pads and wind columns wear the one affordance
  family (signal colour, different shapes). A hit panel glows brighter
  as it weakens, as before.
- Each theme's dressing is the approved prop:
  - gothic: sconces with their flame;
  - rusted: drums (stacked sometimes) or valves;
  - neon: transit signs, whose text is on the lit face;
  - temple: roots and stumps;
  - concrete: the warning plate.
- Concrete and neon rooms carry the course-ruled walls and ceilings.

## Already integrated before this (not redone)

- The hanging light housings, one family per theme.
- The base materials.
- The twelve shipped room shells.

## Integrated, but conditional

- The value band follows the theme. A theme the band map does not name
  keeps the code-built enemy.
- Panels, pads and wind columns appear only where Epsilon places those
  features.
- **Some wall dressing is newly visible.** The code versions of the
  warning plate, valve and most of the sconce were built inside the wall
  and could not be seen. The approved props now sit on the wall's face.
  Nothing was added or moved, but you will notice the concrete warning
  plates (see decision 7).

## What remains blocked, and why

These are in short form; the reasons and numbers are in the table.
- **Blocked by a fit or a rule** (each is a decision below):
  - the Check;
  - the door lining;
  - the Hub's shop, archive and abandon stations;
  - the Lab's moving target and reset pad;
  - the moving-platform deck and wind perch;
  - the water basin;
  - the keys;
  - the wall-light housings;
  - the melee device.
- **Needs code work before it fits:**
  - the rail beam and curved rails;
  - the ramps and stairs.
- **No place in today's game** (not forced in):
  - navigation signs;
  - architecture modules;
  - the other props;
  - decoys, secret cues and gates.
- **Waiting on your review of Arty's package, and not promoted:**
  - 023–028;
  - 043, 049, 053;
  - 044;
  - 045–052;
  - the source-game packs.
- **Held, with the hold kept:**
  - the projectiles;
  - the room kits;
  - the EchoPart forms.

## Owner decisions

Arty's own "decide these first" list is in
`docs/art/review/owner_review_2026-09-28/START_HERE.md` on the art branch.
These are only the questions integration raised:

1. **The Check.**
   - **Asset:** `check_item_*` (005-R).
   - **Evidence:** `legibility_driver.gd`'s `forms_read_apart`. Available
     and confirmed differ by 7 cm at the top and 1.25× in height; the
     rule asks for 0.35 m or 1.8×.
   - **Question:** reshape the confirmed husk, or relax Production's rule
     for the Check?
   - **Recommendation:** have Arty reshape confirmed (it is the one
     failing pair); keep the rule.
2. **The door lining.**
   - **Asset:** `door_standard` (006).
   - **Evidence:** walls meet back to back at seams, so linings would
     double up.
   - **Question:** line once per seam (a small room-generation change),
     or leave doorways bare?
   - **Recommendation:** line once per seam, in the ordinary-room work,
     not here.
3. **The Hub stations.**
   - **Assets:** the shop counter, archive terminal and abandon station
     (003).
   - **Question (still open):** grow the counters to the art, or ask
     Arty for counter-height versions?
   - **Recommendation:** counter-height versions, which keep the reach
     and labels players know.
4. **The wall-light housings.**
   - **Assets:** 014's five wall and bracket housings.
   - **Evidence:** there is no wall-light slot, and adding lights changes
     exposure.
   - **Question:** add wall-mounted positions that replace some hung
     lights, or keep hung only?
   - **Recommendation:** keep hung only for now.
5. **The melee device.**
   - **Assets:** `vm_device_melee` and `vm_device_stowed` (032).
   - **Question:** should the stowed device replace the Static Pulse's
     code-built device in first person now, before a melee exists?
   - **Recommendation:** yes, as presentation only, if you are happy with
     the view; otherwise wait for the melee.
6. **The keys.**
   - **Assets:** 031's keys and receivers, structural coding.
   - **Evidence:** today's keys are colour-coded ("RED KEY").
   - **Question:** move the keys to structural coding (the labels change)?
   - **Recommendation:** yes, in a small follow-up that changes the key
     names and art together.
7. **The now-visible wall dressing.**
   - **Asset:** the warning plate above all.
   - **Question:** keep the dressing on the wall face, or set it back to
     where it was drawn, which is invisible?
   - **Recommendation:** keep it. The plate is warning-only, and one or
     two per concrete room.
8. **Projectiles.** Unchanged: the hold stands until you rule on
   `reads_apart` against the art rule (AF:552).

## Evidence, and its scope

- **Scripted:** each family's suite, run on its own:
  - `godot-enemy-art`
  - `godot-lab`
  - `godot-affordance`
  - `godot-exit-reach`
  - `godot-integration`
  - `godot-legible`
  - `godot-zone-audit`
  - and the others named in each commit

  The new checks were proven with sabotage runs: a shared tint, a moved
  runway, a shared panel glow, and a changed drum collider.
- **The combined build:** CK13, the full frontier, on the art head.
  Result: *(to be filled from the run)*.
- **Visual:** the before/after frames in `images/`, from the same camera
  and state. They are renders, not play.
- **Not done:** nobody has played this build. There is no performance
  measurement for the added meshes, and no claim about frame time is
  made.
