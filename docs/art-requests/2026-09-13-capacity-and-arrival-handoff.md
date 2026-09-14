# Batch 044 — corrected capacity, per-socket arrivals, and what is left

**Arty**

**To:** Prod and Dess
**Art head:** this commit. **Production read at:**
`claude/archipepsi-echoes-continuation-b1adno` `7c78487`.

**All three rooms are PROPOSALS. Nothing here is owner approval and
nothing promotes them.** Their review status is unchanged and explicit,
and the presentation polish still outstanding on two of them is **not** a
requirement for finishing Playable 0.3.

---

## 1 · Per-socket arrival regions — Art's half is done

All three rooms carried **one** `player_entry` volume called `arrival`,
in front of the front door, including the four-door Cross. That is the
pre-§11.3 shape: one answer however many openings a room has.

**The naming is the whole contract, and it is the socket's name exactly.**
`ContentInstantiator._player_entry` matches `volume.name == arriving`,
where `arriving` comes from `socket_for_edge(entry, chamber,
"arrive_edge")` — the same lookup `_entry_offset` uses, so the region and
the attachment point cannot come from different doors. Anything else
falls through to the first region, which is the old behaviour wearing a
new name.

| shell | joinable sockets | `player_entry` regions, named |
|---|---|---|
| `shell_junction_cross` | entry, exit, branch_east, branch_west | **all four** |
| `shell_junction_triad` | entry, exit, branch_east | **all three** |
| `shell_bay_terminus` | entry, branch_east, branch_west | **all three** |

Each is a 2.4 × 2.0 × 2.4 m standing box centred 3.0 m inward from its
socket's own plane — the wall's outer face — so it spans 1.8–4.2 m in and
clears a 0.60 m wall by 1.20 m. **`entry`'s is emitted first in every
room**, deliberately: `_player_entry` falls back to the FIRST region when
the composer names no arriving socket, so a chain that says nothing gets
what these rooms gave before.

### Measured, against the imported geometry, by your rule

`tools/content/run_arrival_test.sh` →
`docs/art/review/arrival_2026-09-13/arrivals.json`.

It applies `RoomAudit.arrival_is_supported` and nothing else: ray down
from the region's centre by `0.5 + MAX_VERTICAL_STEP`, require ground,
then require a standing capsule at that ground to be unblocked. **Both
halves**, because they were once split and an anchor over a hole passed
the empty-space half alone.

**And a body is then placed AT the region and walks in.** A
default-entry-to-side-door walk is not a side-door-arrival test, so the
body never starts at the front door.

```
10 openings.  Every one supported and clear, and walked into the room
              from, with 0 jumps.
floor_y       -0.06 on spine regions (the 0.06 m groove channel) and
              0.00 on arm regions.  Both inside the 0.12 m walk-up.
colliders      77 / 56 / 43, from the shells' own -convcolonly nodes
```

**It bites.** Sabotage-tested three ways against a doctored manifest: a
region renamed back to `arrival` → *"branch_east has no arrival region
named after it"*; a region moved into the air → *"no ground within
1.50 m"*; a region buried inside the Cross's machine → *"a standing
capsule does not fit"*.

One note on the harness, because it changed the answer: it builds
**convex** bodies from each shell's `-convcolonly` nodes rather than a
trimesh over the visible meshes. A trimesh box is a *surface*, so a
capsule fully inside one reports no intersection — the buried-region
sabotage passed the support half until this was fixed, and `RoomAudit`
runs against real convex bodies.

---

## 2 · `shell_bay_terminus` has no `exit`, and the earlier sentence was wrong

**The correction, plainly:** the handoff said all three rooms preserve
the legacy `entry`/`exit` pair. **That is not true of the Terminus.** It
declares `entry`, `branch_east`, `branch_west` — three joinable sockets
and no socket named `exit`. No `exit` has been invented and no opening
has been cut to make the old sentence true.

**Its intended role is a DESTINATION.** ~~— a leaf.~~ The word was doing
work it should not: **"leaf" in this implementation can still host onward
branches**, so a room at a branch destination is not thereby a graph dead
end, and this handoff should not have implied it was.

**Two senses of "dead end", and only one is Art's.** Production's
`dead_ends` is a MEASURED degree — `graph_driver.gd` counts adjacency and
calls `n == 1` a dead end. Art's `dead_end` is a **shape tag describing a
treatment**: the channel comes in from the entry, opens into a turning
circle, and stops at a blank end wall with a maintenance recess. The two
are unrelated, and **the tag is consumed by nothing**: every `dead_end`
hit in Production is `side_dead_ends`, the measured property, or a test
fixture. Whether a shape tag that reads like a degree claim is worth
renaming is the matcher's owners' call, not Art's — flagged, not changed.

### The treatment, evaluated against BOTH graph states

Rendered separately, as asked, in `docs/art/review/furnished_2026-09-13/`:

| frame | state | reads |
|---|---|---|
| `BAY_TERMINUS_1_one_neighbour_both_branches_sealed` | degree 1 | the line stops here |
| `BAY_TERMINUS_2_same_view_one_branch_open` | degree 2 | **pixel-identical to frame 1** |
| `BAY_TERMINUS_3_the_open_branch` | degree 2, from inside | plainly a way on |

**From the approach the two states are the same picture — 0 of 921,600
pixels differ.** Not a harness failure: the seal count is 2 against 1, so
the closure ran and simply is not visible. The 8 m mouth hides both side
openings until a player is inside the chamber, so the dead-end treatment
survives an onward branch *from the approach* whatever the degree.

**From inside, an assigned branch is obviously a doorway** and the "it
stops here" reading does not survive it. So the treatment is a claim
about the CHANNEL terminating, not about the room's degree — which is
the distinction to keep, and the reason a one-neighbour assignment has to
be evaluated on its own rather than inferred from the tag.

One connection is used; the others are the composer's to seal, and an
unassigned socket is `SEALED` and gets a slab, which needs no special
schema.

**The mismatch is in the PRODUCER, and it is not small.** ~~`_exit_offset`
resolves `depart_edge` first, so the fallback is the problem.~~ That was
my reading and it is insufficient — corrected after the owner pointed at
`compose_with_branch`, and confirmed at `topology.py`:

```python
SPINE_SOCKETS = ("entry", "exit")
unfit = [c.id for c in chambers
         if not set(SPINE_SOCKETS) <= set(_sockets_for(c, caps))]
if unfit:
    return GraphProduct(edges=(), doors={... _seal_the_rest ...}, ...)
```

`compose_with_branch` calls `compose_chain` FIRST and returns `base`
immediately when `base.edges` is empty. So one Terminus in the chamber
list means **no chain, no branches, and every room's doors sealed** —
not just the Terminus's own placement. And a room can only be moved to a
branch after it is on the spine, because `_branch_routes` picks
destinations from chambers whose sockets leave one SPARE beyond
`SPINE_SOCKETS`. **A leaf-compatible room is rejected before it can
become a leaf.**

`_exit_offset`'s fallback to `Vector3(0, 0, size.z)` — the middle of this
room's blank end wall — is a second, smaller thing behind the same door.
Fixing only it changes nothing, because composition never gets that far.

**Art is not proposing the fix**: the producer and its consumer are
Dess's and Prod's. What Art can state is the capacity, truthfully: three
joinable sockets, none named `exit`, role `destination`/`dead_end`. **No
`exit` will be fabricated, no further door cut, and the room will not be
made a through-room to preserve an inaccurate sentence.**

### The capacity, as declared

| shell | class | tags | joinable | placement sockets | volumes |
|---|---|---|---|---|---|
| `shell_junction_cross` | medium | junction, branching | entry, exit, branch_east, branch_west | cover ×2, reactive ×2 | 4 arrival, 2 enemy_spawn, 1 objective, 1 no_build |
| `shell_junction_triad` | medium | junction, branching | entry, exit, branch_east | cover ×2, reactive ×1, enemy_high ×1 | 3 arrival, 1 enemy_spawn, 1 objective, 1 no_build |
| `shell_bay_terminus` | small | destination, dead_end¹ | entry, branch_east, branch_west | cover ×2, reactive ×1 | 3 arrival, 1 enemy_spawn, 1 objective |

¹ `dead_end` is an **art treatment tag and not a degree claim**, and
nothing in Production reads it. Capacity is **three** joinable sockets:
this room can be assigned one neighbour or three.

`shells.joinable_sockets` reads these by kind and by name, so the three-
and four-connection capacity is visible to the composer as names rather
than a count. **A four-connection asset is still not a four-neighbour
room in a generated Zone**, and that sentence should survive into the
next handoff.

---

## 3 · Two claims in the last report were wrong, and both are withdrawn

### 3a · The Yard's doorways are NOT refused, and no repair is requested

`shells.is_offerable` calls `doorways_off_the_body`, **logs**, and returns
regardless — with the reason written beside it: the same 0.40 m step is
inside the envelope on `shell_corner_left` and outside it on
`shell_yard_gantry`, and the Yard's threshold repair carries its floor
out as **mesh**, which no manifest rule can see. The authority is the
assembled crossing.

**The last report called this a refusal and asked for a socket move. That
request is withdrawn.** No current production failure names these
doorways, so there is nothing to repair. `measure_doorways.py` carried
0.405 m (the *layout* allowance), then 0.005 m as a *failure*, and now
reports the distance without failing — the same position your code
reached, for the same measured reason. The two `:envelope` entries are
gone from `KNOWN`, struck in place, because there is nothing left to be
exempt from.

```
measure-doorways: REPORT -- shell_yard_gantry/entry: 0.395 m past the
  shell's own declared size. The assembled crossing decides, and this
  one crosses.
```

### 3b · The runtime binder is not missing, and there is no art-side one

`ThemeMaterials._material` asks `ThemePack.texture_for(theme, role)`
**first** and falls back to `ProcTextures` only on null. It ships
`is_authored()` and `reset_cache()` for exactly the question the last
report claimed nothing could answer.

**`tools/content/theme_binder.gd` is deleted.** A second binder would be
a second source of material behaviour. `theme_bind_proof.gd` now drives
**your** `ThemePack` and `ThemeMaterials`, fetched read-only at run time
by this lane's two documented moves (`class_name` stripped, cross-refs
bound to preloads).

What is still Art's, and worth keeping: **`ThemePack` verifies
`sha256_16` over the PNG's file bytes, and nothing checks that the
texture the GPU finally samples is those pixels.** Between the last byte
on disk and a wall sit an importer, a sidecar, a loader and a
`.godot/imported` cache. That comparison now runs against the material
*you* build.

```
6 themes, 4 required roles each: authored=true, pixels identical to the
authored PNG through the real import, uv1_scale 0.25 from covers_m 4.0,
NEAREST filter.  hazard: authored=false in every theme.
control (your own `_descriptor_override`, not moved files):
  concrete_facility without its floor row -> disqualified ["floor"],
  floor falls back to ProcTextures, its other three roles and all five
  other themes unaffected.
```

Note for the record: the control shows disqualification is **per role**,
not per theme. The last report said the whole theme was disqualified.

---

## 4 · The mirrored stencil — and a premise of mine that has to be
withdrawn before anyone acts on it

**~~The repair is inert at runtime because `ThemeMaterials` sets
`uv1_triplanar`.~~ Wrong, and the error was mine.** An authored shell
never receives `ThemeMaterials` at all:

```
occurrences of "material" in content_instantiator.gd ....  0
occurrences of "ThemeMaterials." in chamber_builders.gd .. 46
```

`_from_authored_scene` calls `scene.instantiate()` and performs **no
material operation whatsoever**. Themed materials are the PROCEDURAL
half and the gameplay objects — enemies, portals, rewards, powered
links, affordance features. A `.glb` room keeps the materials Blender
baked into it.

My previous frame B forcibly swapped every surface to `ThemeMaterials`
and photographed the result. It is a true picture of a path **these
rooms do not take**, and presenting it as "the production material
binding" put a repair request on Prod that Batch 044 does not need. That
request is withdrawn.

### So the repair is complete, and it is proved where it lands

`common.uv_read_right` flips U back after projection, **inside declared
boxes only**, and **only on the face whose dominant normal is positive**
— one sign has two faces and the projection mirrors exactly one, so
flipping both would turn the good one backwards. Ordinary tiling is
untouched and the world projection is not rewritten.

**Scale is asserted, not eyeballed.** The flip mirrors each face about
its own U span, and the builder now *checks* the span is unchanged
afterwards and fails the build if it moved. Orientation changed; texel
size did not, and that is a separate claim from what a picture shows.

Evidence, all through the authored materials — the path
`ContentInstantiator` instantiates — in
`docs/art/review/theme_bind_2026-09-13/`:

| frame | what |
|---|---|
| `..._A1_authored_south_board` | the gauge board, head-on |
| `..._A2_authored_north_placard` | **the opposite-facing sign** on the plant's other face |
| `..._A3_..._room_yawed_37` | the same board with the **room rotated 37°** |
| `..._A4_..._room_yawed_37` | the same placard, room rotated |
| `..._B_thememateri_procedural_path` | **kept and relabelled**: `ThemeMaterials` with triplanar, which is the PROCEDURAL path's defect and not this shell's |

Ordinary wall and floor tiling is in every frame and unchanged.

### What is genuinely still Production's, narrowed

The mirrored-lettering defect **is real on the procedural path**: a
surface that gets `accent_mat` shows the theme pack's stencil through
triplanar, which projects from world position and ignores mesh UVs. That
is not a Batch 044 problem and Art is not asking for it now. If it is
ever worth repairing, the smallest asset distinction Art can offer is a
`signage` entry in the descriptor's existing `variants` map — it
resolves to `accent`'s pixels through the one-hop fallback, needs no new
texture, and gives a selectable role name without touching `accent`
everywhere. **Not added in this pass**, because nothing currently
consumes it and an unused vocabulary word with no consumer is exactly
what `player_entry` was.

The sump band is deliberately **not** flipped: a floor decal has no
single correct reading direction.

---

## 5 · What the preview claims, exactly

The red capsules are **occupancy stand-ins, not a played encounter and
not a spawn count.** `furnished_view.gd` draws **three per declared
`enemy_spawn` volume** — three is the harness's own number, chosen to
show a volume's extent. **The shells declare no spawn points at all.**
The count key is `spawn_standins` now, beside `spawn_volumes`, because a
key called `enemy_spawn` reads as a count of spawns the shell declares;
the last report read its own output that way and said "three declared
spawn points". The images carry a third stamp saying so.

`STAGED / NOT GENERATED` stays on every frame.

**The Cross's service passage may well be a deliberate choke, and it has
not been widened.** It is 2.5 m clear between the machine's plating and
the wall, with `fight_passage` declared in it. Whether that is the
encounter you want is a real-player, real-enemy question against the
actual content budget, and it is handed over rather than answered by a
still image.

---

## Remaining integration findings

| # | finding | whose |
|---|---|---|
| 1 | `_exit_offset` falls back to `(0, 0, depth)` — solid end wall on a `dead_end` shell — when no `depart_edge` is named | Prod / Dess |
| 2 | A four-connection asset is not yet a four-neighbour room in a generated Zone | Prod |
| 3 | `uv1_triplanar` discards mesh UVs, so lettering mirrors on half of every pair of opposite faces and no UV repair reaches the runtime | Prod, with Art's two options above |
| 4 | Is a 2.5 m service passage carrying one `enemy_spawn` volume the intended choke? | Prod, by real-player test |
| 5 | `reactive_0` on the Terminus sat on `drum_0`'s own centre — a runtime barrel inside an authored one. Moved to (−4.6, 19.4). Found deriving the arrival regions | Art, fixed |
| 6 | Triad and Terminus still wear the Cross's pre-revision surface — the mass painted in the room's architecture material. **Not** a Playable 0.3 requirement | Art, open |

## Checks

```
arrival            10 openings, each with its own named region, supported,
                   clear, walked in from; 3 sabotages bite
measure-doorways   15 shells; 2 off-body REPORTS, 4 known open findings
test-doorways      16 synthetic cases
crossing           102 crossings, 0 problems
route-walk         11 routes; span flights 16 jumps, interior routes 0
theme-bind         Production's ThemeMaterials binds 6 themes; pixels
                   survive the import; the missing-row control falls back
check-art          PASS -- every generated asset matches its source
```
