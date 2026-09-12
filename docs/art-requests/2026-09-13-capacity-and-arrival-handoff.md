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

**Its intended role is a DESTINATION — a leaf.** `shape_tags` say so
(`destination`, `dead_end`) and the room is built to say it: the channel
comes in from the entry, opens into a turning circle, and stops at a
blank end wall with a maintenance recess. One connection is used; the
other two are the composer's to seal, and an unassigned socket is
`SEALED` and gets a slab, which needs no special schema.

**The mismatch to resolve, and it is small.**
`ContentInstantiator._exit_offset` resolves `depart_edge` through
`socket_for_edge` first — so a composer that assigns a departing edge to
`branch_east` or `branch_west` works correctly today. Its fallbacks are
the problem: no `depart_edge` → look for a socket named `exit`/`end_b` →
**`Vector3(0, 0, size.z)`**, which on this room is the middle of the
blank end wall, 22 m in, with no opening.

So: **this room is safe as a leaf, or with an explicit `depart_edge`, and
unsafe only when a composer routes through it while naming no departing
socket.** Whether that is worth a guard is yours — the honest options are
(a) the composer never routes through a `dead_end`-tagged shell, or (b)
`_exit_offset` refuses rather than guessing when no socket answers. Art
has no opinion that should outrank either.

### The capacity, as declared

| shell | class | tags | joinable | placement sockets | volumes |
|---|---|---|---|---|---|
| `shell_junction_cross` | medium | junction, branching | entry, exit, branch_east, branch_west | cover ×2, reactive ×2 | 4 arrival, 2 enemy_spawn, 1 objective, 1 no_build |
| `shell_junction_triad` | medium | junction, branching | entry, exit, branch_east | cover ×2, reactive ×1, enemy_high ×1 | 3 arrival, 1 enemy_spawn, 1 objective, 1 no_build |
| `shell_bay_terminus` | small | destination, dead_end | entry, branch_east, branch_west | cover ×2, reactive ×1 | 3 arrival, 1 enemy_spawn, 1 objective |

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

## 4 · The mirrored stencil: a local repair that works, and cannot reach you

`common.uv_read_right` flips U back, after projection, **inside declared
boxes only** — one piece, the Cross's gauge board. Ordinary tiling is
untouched and the world projection is not rewritten.

**It works, and it is inert at runtime.** Matched pair, same camera,
`docs/art/review/theme_bind_2026-09-13/`:

| frame | materials | reads |
|---|---|---|
| `..._A_glb_materials.png` | the `.glb`'s own | **`SEC 04`** |
| `..._B_themematerials.png` | `ThemeMaterials`, `uv1_triplanar` **on** | mirrored |

**`ThemeMaterials` sets `uv1_triplanar = true`, and triplanar projects in
the shader from world position — it ignores mesh UVs entirely.** So no
UV-level repair, local or global, can change what a built Zone shows. The
world projection is not the runtime cause and rewriting it would have
fixed nothing.

**Reporting the scope rather than taking it**, as asked. The runtime
repair is a material decision and it is yours:

* **turn `uv1_triplanar` off for the roles that carry lettering** —
  smallest change, and it also makes the authored UVs meaningful; or
* **keep text out of tiling textures altogether** and give signage its
  own non-tiling material — larger, and a theme-pack change Art would
  make.

The flip is kept because it is correct for the exported asset and becomes
visible the moment either lands. The sump band is deliberately **not**
flipped: a floor decal has no single correct reading direction.

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
