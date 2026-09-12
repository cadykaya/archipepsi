# Presentation, separated from room design — and three things Production moved

**Arty**

*2026-09-13. Art head `86f6369` and this commit. Production read at
`claude/archipepsi-echoes-continuation-b1adno` `05dd5d6`, which is 12
commits past the `612a7d2` the last handoff was written against.*

**Everything about the three Batch 044 rooms is still a proposal. Nothing
here is owner approval, and nothing here promotes anything.**

---

## 1 · The study the brief asked for

> *"Before a major redesign, separate missing presentation from room
> design: show one representative existing room with its intended
> runtime-compatible furnishing and lighting."*

One room — `shell_junction_cross`, the four-way — carried through three
states. All five final images are in
`docs/art/review/furnished_2026-09-13/`; the earlier two states are kept
beside them in `study/` rather than deleted, because the argument is the
sequence.

### What "furnished" means here, exactly

`tools/content/furnished_view.gd` **places nothing of its own invention.**
Every prop stands at a point the shell declares — a `cover` socket, a
`reactive` socket, an `enemy_high` socket, an `objective` volume, an
`enemy_spawn` volume — and each names a consumer that runs today:
`DestructibleCover`, `ReactiveBarrel`, the ranged-enemy placement loop,
the composer's reward and its enemy budget.

The lighting is the shipped Zone's: `ZoneBuilder`'s ambient 0.35 and fog
0.012, one shadowless `OmniLight3D` per fixture at `omni_range` 12.0 from
`ChamberBuilders`, and **no `DirectionalLight3D`**, because a built Zone
has none.

**Every image is stamped `PREVIEW ONLY — STAGED, NOT GENERATED`** and
`props stand only at points the shell declares`. A staged arrangement
shown as ordinary output is the most expensive kind of wrong picture: it
gets believed, and then the real Zone looks nothing like it. If the room
looks empty in one of these, the room **is** empty to the runtime, and
that is the finding rather than a lighting problem.

### Stage 1 — the plant centred. It was a corridor bent into a square.

`study/STAGE1_centred_plant_the_west_side.png`

A 5 m ambulatory the whole way round. The props stood correctly at every
declared point and the space between them was still five metres of
passage with nowhere to be. **Furnishing did not fix it and was not going
to** — which is the brief's own test, applied and failed.

### Stage 2 — the plant shifted north-east by 2.5 m. The plan worked.

`study/STAGE2_offset_plant_*.png`

The same block, off centre, makes two different places out of one uniform
one: a **7.5 m working bay** on the south and west, and a **2.5 m service
passage** on the north and east. The four doors do not move. The approach
view stopped being symmetrical and the route choice became a real one.

**And it still read as a hallway from inside.** That is the honest
judgement of stage 2 and it is why there is a stage 3.

### Stage 3 — the surface stopped lying about what the block is

The plan was already right. **The plant was painted in the room's
ARCHITECTURE material**, so from inside either route the machine was
indistinguishable from the shell around it, and both routes read as
corridor walls. Five changes, each one the object saying what it is:

| | what | why it is not colour-coding |
|---|---|---|
| skin | `wall` → `trim`, the theme's ribbed **plating** | `trim` tiles at 4 m, so ribs at ~0.4 m pitch across an 8 m face — machine scale. `accent` was the other candidate and is the theme's **labelled** panel: an 8 m face would repeat its stencil four times. It stays on fittings. |
| base | a **bund** on the south and west, 0.30 m proud | A wall meets the floor flush; a machine stands on a base. On the bay side only, because that side drains — the sump is out at (−6, 9.6) — and because run all the way round it caught a body at both passage turns (below). |
| top | a **hood**, set back 0.9 m, 5.4 → 6.6 m | The silhouette steps instead of running flat into the 8 m ceiling. |
| face | a **gauge board** on the south face | That face is what the entry line meets at 7.5 m, and it was bare. A plant's public face carries one thing. |
| plumbing | two **trunk lines** leaving west at 5.6 m | They cost no floor, give the wide side a ceiling the narrow side has not got, and point the way the room is organised. |

The risers also moved: centred on the plant's corners and run
floor-to-roof they put a 0.40 m post into the ambulatory at each corner,
and once the plant became plating they stopped reading as risers at all —
same material, same face, so below the deck they were pilasters on a
wall. Inset onto the plant's own corners and started at its deck, they are
four stacks rising off the machine past its hood.

### Judged from the approach and the decision point

> *"Can the player distinguish the routes? Is there something recognisable
> about the place beyond its doors? Is there useful space to occupy?"*

**Routes: yes, and not by colour.** `1_the_approach` and
`2_the_decision_point` show a machine ahead with the ambulatory turning
round it. `3_the_working_bay` and `4_the_service_passage` are two
obviously different places — one is 7.5 m of open floor with a working
face along it, the other is a 2.5 m squeeze between plating and a wall,
with the declared spawns standing in it. **They differ by width, by what
stands on them and by where the machine faces**, and they would still
differ if the block were painted like the walls; it just would not be
legible.

**Recognisable: yes.** It is a plant room. A plated machine on a bund,
with a gauge board, a working face on one side and service gear on the
other, and its trunk lines leaving west.

**Useful space: yes, and deliberately left empty.** The bay's 7.5 m is
open floor with declared `cover`, `reactive`, `objective` and
`enemy_spawn` points in it. Nothing was scattered to fill it. The room
declares where things go and leaves the runtime to choose what.

### Two things I am not claiming, and two I am reporting against myself

- **Stills are stills.** They show framing, legibility and occupancy. They
  do not show combat visibility and they do not show flicker-free motion.
- **This is one room.** The triad and the terminus have not had the same
  pass, and their surfaces have the same defect stage 2 had.
- **The stencil text reads mirrored on half of every surface in the
  library.** `common.uv_project_world` projects each face from the world
  axis it most faces and **ignores the normal's sign**, so a −Z face and a
  +Z face get the same UVs and one of them is seen reversed. That is
  deliberate and load-bearing — it is what makes a wall tile seamlessly
  into the wall next to it whatever order the modules are placed in — but
  any authored texture carrying text or a directional glyph pays for it.
  Visible on the gauge board and on the sump band. **Not touched**: it
  would regenerate every asset in the library, and it is a decision above
  this pass.
- **`trim`'s ribs run horizontally on Z-facing faces and vertically on
  X-facing ones**, from the same projection. It happens to help — the
  passage wall and the bay face read differently, from the geometry's
  orientation rather than a colour choice — but it was **noticed, not
  designed**, and it is recorded as such.

---

## 2 · Both through-routes walk with no jumps, at a stricter tolerance

The passage route reported one jump and then two, and I diagnosed it twice
by reading geometry and guessing. Both guesses were wrong. So the walker
now records **where** it jumped:

```
before   jumps 2   at (6.9, 12.7) and (7.3, 21.5)
after    jumps 0   both through-routes, arrived_within 0.5
```

Both jump points were the corner posts, at the passage's two turns. And
the last one was the harness: **`ARRIVED` was 1.2 m, in a 2.5 m passage**,
so the body could turn a corner 1.2 m early and walk into the machine. It
is now a property of the walk, and both cross through-routes pass a
**tighter** one — 0.5 m — than the rest of the suite. Tighter is stricter:
the body has to reach each waypoint more nearly and may cut less.

---

## 3 · The theme pack actually binds — proved, with three controls

> *"Prove a real exported theme actually binds authored floor/wall
> textures. 'The Zone still builds' is insufficient."*

It was insufficient for a precise reason: **the shipped `ThemeMaterials`
builds every material from `ProcTextures`**, so a Zone builds identically
whether the pack is present, corrupt, or absent. "It still builds" is the
symptom being invisible.

So there is now a reference binder — `tools/content/theme_binder.gd`,
**a proposal, not wired into the game** — implementing the descriptor's
own rules, and `tools/content/theme_bind_proof.gd` interrogating the
materials it produces from the **real exported files**:

1. every theme binds, every role the contract requires pixels for;
2. the bound material is **not** carrying the procedural texture;
3. **the pixels survived the import** — the texture the material carries,
   read back and compared byte for byte against the authored PNG decoded
   straight from its own file bytes. This is the part no Python validator
   can reach;
4. NEAREST filter, repeat on, and `uv1_scale` matching the pack's declared
   `texels_per_metre` and the texture's own size — 0.25, i.e. 4 m per tile.

**`hazard` comes back unauthored in every theme**, which is the contract
holding: the pack never paints it, and a pack that shipped hazard pixels
would be the finding.

### The controls

| control | what is done to the real pack | what is demanded, and observed |
|---|---|---|
| required role gone | `concrete_facility_floor.png` moved aside | theme **disqualified**, reason named, **nothing** bound — not five roles out of six, and not another theme's floor — and the other five themes unaffected |
| wrong pixels | `concrete_facility_wall.png` replaced with `gothic_stone_wall.png` | clause 4 refuses it on its digest (`5ca5e0ff…` vs `2bef9880…`) and disqualifies the theme, rather than a room quietly coming out in another theme's stone |
| optional role gone | `concrete_facility_ceiling.png` moved aside | theme **still binds**, `ceiling → wall` per `optional_role_fallbacks`, and the ceiling is carrying the **wall pixels** — checked by bytes, not by trusting the label |

The controls move **real files** and put them back from a trap, and the
runner re-runs `verify_theme_export.py` afterwards and refuses to succeed
until the pack is whole. A control that simulates absence tests the
simulation.

**This check has been seen to fail.** Its first version reported all 37
textures as corrupted by the import. The cause was mine: the sidecars ask
for mipmaps, so the imported image carries its whole chain and `get_data()`
comes back about a third longer than the authored PNG's — same width, same
height, different bytes. Clearing the chain compares the base level, which
is the authored pixels. Recorded because a check whose only evidence is a
pass has not been tested, it has been agreed with.

### The correction that still needs to travel

`texture_filter` and `texture_repeat` are **not importer parameters** in
Godot 4; they are sampler state on `BaseMaterial3D`. The sidecars own
mipmaps; the binder owns filter and repeat. Asserting a key that cannot
exist is a check that always fails or one that lies.

---

## 4 · Production moved, and three things reconcile differently now

Read at `05dd5d6`. The "two-socket world" description in the last handoff
is **out of date in Art's favour on two counts and against it on one.**

### 4a · Sockets are read by kind, and by name. Fixed on their side.

`shells.JOINABLE_SOCKET_KINDS = ("doorway", "corridor_end")`, and
`joinable_sockets()` returns **names, not a count** — with a comment
recording that `topology.AUTHORED_SOCKETS` used to hardcode
`("entry", "exit")` and that *"a three-door shell would have been read as
a two-door one."* `declared_sockets(rule)` carries the same names on the
wire, explicitly so a generator *"choosing a shell for a room that will
branch can see which shells can carry a branch."*

**So a three- and four-connection room is now readable.** That was the
blocker named in the Batch 044 handoff and it is Production's, and gone.

### 4b · Arrival is a measured verdict, and missing evidence is not passing evidence

`layout.validate` refuses a graph Zone that arrives without aperture
measurements, bounds or arrival verdicts. An earlier version skipped every
check whose input was absent; theirs now refuses. **Art's `arrival`
regions therefore have to be real, not decorative** — and that is the
right way round.

**A four-connection asset is still not a four-neighbour room in a
generated Zone**, and that sentence should survive into the next handoff.
What is proved on Art's side is that each branch crosses, closes, and is
reachable inside the room.

### 4c · The yard's two doorways are now REFUSED, and this is not a geometry change

Production split one allowance into two, against two different references:

| check | compares a socket to | allows |
|---|---|---|
| `shells.doorways_off_the_body` | the shell's declared **`size`**, which **is** the outer face | `SPAN_TOLERANCE`, **0.005 m** — manifest rounding |
| `layout.SOCKET_PROUD` | the bounds the **engine** reports, which span the walls' **centre** planes | `WALL_THICKNESS + SPAN_TOLERANCE`, **0.405 m** |

Their note names the false negative the single number cost: *"a 0.405
allowance passed [`shell_yard_gantry`] by five millimetres. Arty measured
it and said so."*

**Measured against the current rule, across all fifteen shells:**

```
shell_yard_gantry/entry   0.395 m past the declared 85.20 m size
shell_yard_gantry/exit    0.395 m past the declared 85.20 m size
                          — and nothing else, in the whole library
```

`measure_doorways.py` carried the 0.405 m and therefore passed the yard
exactly the way Production's did. **It now carries 0.005 m**, with the
0.405 struck and the reason written beside it, and it does **not** attempt
the layout rule at all — that one compares against bounds only the engine
reports, and guessing them would be a second derivation of a fact the
engine owns. The synthetic tests gained both sides of the new boundary:
0.004 m must pass, 0.05 m must fail.

**The yard is NOT repaired here.** The repair is one line — both sockets
onto `WALL_FACE`, where the threshold already reaches after the 2026-09-12
repair and where nine of the twelve shells put theirs — but it rewrites an
approved shell's manifest, which is outside what this pass may touch. It
is in `measure_doorways.KNOWN` as `envelope`, reported and unauthorized,
keyed by defect **kind** so a second and different defect at the same
doorway would still fail rather than inherit the exemption.

**The assembled crossing is not what is failing.** Both yard doorways are
crossed in `crossing_test.gd` — at the origin, placed, yawed 37°, and
closed. What Production refuses is the unclaimed volume in front of the
wall, which a crossing harness cannot see. That is why the earlier ruling
("don't move a socket merely because it is outside the envelope") was
right at the time and why the fact has now changed underneath it.

---

## 5 · Span, closed without overclaiming

Full reply in `docs/art-requests/2026-09-13-span-basin-stairs-reply.md`.
In short: **the flights were never short.** All sixteen treads exist and
`tread15` tops at 14.00, the deck's own height; `sp_landing_0` lay on top
of the last three, which is also why rays measured a 2.62 m step that was
not there. The landing was trimmed to the flight's west edge.

**Sixteen jumps is not a walk route and this does not claim one.** The
walk-up limit is 0.12 m against 0.875 m risers, so every riser is a jump.
What is closed is completion, measured — and the per-jump ladder now in
`route_walk.json` is the clearest evidence the treads were always there:
three stands **above** the height the rays reported as the top.

**Scope of the capsule numbers.** `0.12 m` walking up, `1.50 m` jumping,
`46°` ramps are what one harness measures driving one capsule through
`move_and_slide` with no weapons, HUD, movement packages, volumes, Echoes
or step assistance. They are a **measurement of the shipped constants**,
not a design rule. They do not forbid slopes — ramps are walkable to 46°,
which is `floor_max_angle` itself, and `roomkit.flight` uses flat treads
because of L-95, a *gate* limitation. They do not forbid vertical rooms.
And they do not license raising `MAX_VERTICAL_STEP`; no global step-height
change has been made or asked for.

---

## Checks

```
measure-doorways   15 shell(s) at Production's CURRENT manifest allowance
                   (0.005 m); 6 reported and unauthorized in KNOWN
test-doorways      16 synthetic cases, including both sides of the new
                   boundary; the old expectation struck, not deleted
crossing           102 crossings -- 34 doorways, open, placed, yawed 37
                   degrees, and closed; 0 problems
route-walk         11 routes; the two span flights at 16 jumps each, every
                   interior route at 0, both cross through-routes at a
                   tighter 0.5 m arrival tolerance
theme-bind         6 themes bind authored pixels through the real import;
                   3 controls behave; the pack restored and re-verified
verify-theme-set   6 theme(s), 37 texture(s), the description matching
verify-theme-exp   37 texture(s) and the descriptor, every digest matching
check-art          PASS -- every generated asset matches its source
```

## Still open, and whose

- **Owner:** every Batch 044 room, still a proposal. The furnishing pass
  for the triad and the terminus. Whether a sixteen-jump climb is the
  intended Span experience.
- **Prod:** the yard socket repair (one line, needs the word). The runtime
  binder — the reference one here is a proposal and is not wired in.
  Whether a 2.5 m service passage carrying three declared spawn points is
  the intended choke.
- **Art:** the triad and terminus surfaces, which have stage 2's defect.
