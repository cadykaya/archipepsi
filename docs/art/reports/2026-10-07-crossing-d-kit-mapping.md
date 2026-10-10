# Fitting the readability kit to Crossing D: the handoff for Prod

*Arty — 2026-10-07*

**HANDOFF, then STOP.** Prod's trial of the kit isn't on any pushed branch yet. I checked the other 25 remote branches today, and none of them loads `batch063`. `wip/crossing-d-review` is still at `4462be29`. That means there was no fitted piece to review at player height in D.

What's here instead:
- the one source repair the kit needed;
- the exact mappings Prod needs to wire it;
- what I'd flag in D as it stands.

The runtime wiring is Prod's.

**Conventions.** Positions are in Crossing D's room frame, the node `crossing_d_room.gd` builds into, in metres. Sizes are Godot width × height × depth (x × y × z). Heights are from the floor.

**Sources.** I read Dess's brief (`docs/D17_CROSSING_D_ROOM_BRIEF.md` on `claude/archipepsi-0-4-blindside`) for context only. Every mechanism, number and state hook below comes from D's code at `4462be29`:
- `crossing_d_parts.gd`, `crossing_d_room.gd`;
- `call_lever.gd`, `player.gd`, `constants.gd`.

## The kit against D's mechanisms

| D's mechanism | Kit piece | Fit |
|---|---|---|
| `Lever` (the lock lever and the gate lever) | `ck_floor_lever` | **Didn't fit; repaired** (below) |
| `conduit()` straights | none; D's runs are any length | Prod builds the straights in code, to the kit's profile |
| Corners and line ends | `ck_raceway_inside`, `ck_raceway_turn`, `ck_raceway_terminal` | Fit as authored |
| The plate, socket, bridge housings, glass door, lift and gate | none | A line stops at the thing's face; a terminal marks what it powers |

## The one repair: the lever, volume for volume

**Why it was needed.** D's interact ray (`player.gd`, `_update_interact_target`) only takes the collider it hits if that node itself has `interact()` (or `install_refusal()`). It doesn't walk up to a parent. So D's `Lever` has to keep its own colliders, and the kit has to be drawn exactly over them.

**What was wrong.** The 2026-10-02 lever wasn't drawn over them:
- its head was 0.34 m deep, under the code's 0.70 m `BASE` collider, which left 18 cm of invisible collider in front of it and behind it;
- its arm turned 0.31 m in front of D's.

| Part | D's code | Kit, 2026-10-02 | Kit, 2026-10-07 |
|---|---|---|---|
| Foot | 0.70 × 0.10 × 0.70, floor to 0.10 | 0.70 × 0.06 × 0.70 | as D |
| Pedestal | 0.46 × 0.825 × 0.46, floor to 0.825 | 0.40 × 0.84 × 0.40, 0.06 to 0.90 | as D |
| Head: `CallLever.BASE`, the collider the ray finds | 0.70 × 0.35 × 0.70, 0.825 to 1.175 | 0.70 × 0.26 × 0.34, 0.90 to 1.16 | as D |
| Arm pivot | top centre of the head, 1.175 up | 1.17 up and 0.31 in front | as D |
| Arm and grip | arm 0.12 × 0.80 × 0.12; grip 0.26 × 0.15 × 0.18 | grip 0.22 × 0.12 × 0.13 | arm 0.84, which adds a 4 cm heel below the pin; grip as D |
| Pilot | housing centred 0.69 up, 0.245 in front | 0.70 up | turns about (0, 0.69, 0.256), on a 2 cm bezel |

D's `Lever` origin stands 1.0 m above the floor. The kit's origin is on the floor.

**The rebuilt piece.** 168 tris; 0.70 wide × 0.72 deep × 2.01 m tall; 32.0 texels/m.

**Measured from the export:**
- the three colliders are 0.70 × 0.10 × 0.70, 0.46 × 0.825 × 0.46 and 0.70 × 0.35 × 0.70, at the heights above;
- `lever_hinge` is at (0, 1.175, 0);
- `pilot_hinge` is at (0, 0.69, 0.256).

[The repaired lever, OFF then ON](../review/crossing_kit_2026-10-07/K2_lever_states.png).

## The lever mapping

This applies to each D `Lever`: the lock lever and the gate lever.

**Mount.** Instance `ck_floor_lever.glb` as a child of the `Lever` node, at local (0, −1, 0), with no rotation.

**Colliders.**
- Keep the code's three: the unnamed `CollisionShape3D` from `CallLever`, `PedestalCollision` and `FootCollision`.
- Free the three StaticBody3D nodes the importer makes from the GLB's `lever_foot`, `lever_pedestal` and `lever_head` `-convcolonly` twins. They have the same volumes, but they aren't the `Lever`, so a ray that hits them finds no `interact()`.

**Hide the code's visuals.** All of these are under the `Lever`:
- the `BASE` plinth (the unnamed MeshInstance3D from `CallLever._build`);
- the stick under `Arm`, and `Arm/Grip`;
- `Pedestal`, `Foot` and the four `Bolt`s;
- `Pilot`, with its `Housing` and `Bar`;
- `OFFMark` and `ONMark`.

Keep the `Arm` node itself. It still carries the pose.

**Moving parts and state:**

| GLB node | Set it in | OFF (not `locked`) | ON (`locked`) |
|---|---|---|---|
| `lever_hinge` (it carries `lever_arm` and `lever_grip`) | `advance()`: `rotation.z = _arm.rotation.z` | −55° | +55° |
| `pilot_hinge` (it carries `pilot_bar`) | `_sync()`: `rotation.z` | 0, bar flat | `PI / 2`, bar upright |
| `pilot_bar` material | `_sync()` | `glow_material(POWER_IDLE, 0.06)` | `glow_material(POWER, 0.5)` |

The kit's hinge has the same pin, axis and sign as D's `Arm`, so the angle copies across unchanged.

The pilot runs the other way from D's. D's `Bar` is built upright and turned flat for OFF (`_pilot.rotation.z = 0 if locked else PI / 2`). The kit's is built flat. It looks the same either way.

**Materials that stay as imported:**
- `trim`: the foot, head, bolts, gland, bearing, bezel and arm;
- `wall`: the pedestal;
- `ck_label`: the stencilled ON / OFF plate;
- `ck_neutral`: the grip.

The handle is neutral. On the lever, green is only the pilot and the stencilled ON.

**Power exit.** The rear gland. A line leaves it at (0, 0.065, −0.36) in the GLB's own frame, heading toward −Z.

## The conduit mapping

### Straights

Prod builds the straights in code to the kit's profile, so they meet the GLB fittings. A run lies on a surface with outward normal n, between two pipe-centre points 0.065 off that surface.

| Part | Size: along × across × along n | Centre, off the surface | Material |
|---|---|---|---|
| Carrier | length × 0.18 × 0.02 | 0.01 | `ThemeMaterials.trim_mat(THEME)`, as D's `_hardware` already uses |
| Pipe | length × 0.09 × 0.09 (square) | 0.065 | trim |
| State stripe (carries the `power_signal` meta) | length × 0.04 × 0.012 | 0.116 | D's own: idle `glow_material(POWER_IDLE, 0.08)`, live `glow_material(POWER, 0.5)` |
| Saddle | 0.06 × 0.22 × 0.105, no more than 1.00 m apart | 0.0725 | trim |

**Joins.** Code straights need no couplings: every fitting has a coupling or a gland at its leg end, where the straight meets it. The trim texture is the same image at the same 32 px/m, so code parts and fittings match. Any texture step at a joint falls on that coupling or gland.

**Line state.** `conduit_power()` looks only at direct children. The fittings' state meshes are nested inside each GLB scene:

| Fitting | State meshes |
|---|---|
| `ck_raceway_inside` | `power_core_a`, `power_core_b` |
| `ck_raceway_turn` | `power_core_a`, `power_core_b` |
| `ck_raceway_terminal` | `power_lens`, the destination's lamp |

Make the search recursive (`find_children("*", "MeshInstance3D", true, false)`). Then treat a mesh as state if it carries `power_signal` or its name starts with `power_`.

### The fittings' own frames

These are Godot frames, as imported. Each fitting lies on its surface at y = 0, with +Y out of it.

| Piece | Leg ends, at the pipe centre | Notes |
|---|---|---|
| `ck_raceway_inside` | floor leg (0.5, 0.065, 0); wall leg (0.065, 0.5, 0) | the wall is the plane x = 0, facing +X |
| `ck_raceway_turn` | (0.5, 0.065, 0) and (0, 0.065, −0.5) | both legs on the one surface |
| `ck_raceway_terminal` | (−0.24, 0.065, 0) | the body spans x −0.24 to 0.18; `power_lens` faces +Y |
| `ck_floor_lever` | (0, 0.065, −0.36) | the rear gland |

## Placements in D

**How to read the tables:**
- A fitting is `Transform3D(Basis(X, Y, Z), origin)`, where X, Y and Z are the room directions the piece's own axes point along.
- A straight is given as its two pipe-centre ends plus its surface normal.

Each line's straight ends were checked against its fittings' leg ends with a script, and every basis is a proper rotation. That check is arithmetic against D's constants, not a fitted render.

### `plate`: the plate to the bridge's near housing

**Live while** `plate.satisfied()`. This is D's own route.

| Piece | Where | Basis X, Y, Z, or normal |
|---|---|---|
| straight | (−18.25, 0.065, 6.5) → (−19.1, 0.065, 6.5) | normal +Y |
| turn | (−19.6, 0, 6.5) | +X, +Y, +Z |
| straight | (−19.6, 0.065, 6.0) → (−19.6, 0.065, 5.0) | +Y; it ends in the housing's face |

Joins: 2 of the 4 straight ends meet a fitting. The other two are the plate and the housing.

### `lock`: the far lever to the bridge's far housing

**Live once** `bridge_locked`.

| Piece | Where | Basis X, Y, Z, or normal |
|---|---|---|
| `ck_floor_lever` | (−17.5, 0, −6.5) | +X, +Y, +Z: local (0, −1, 0) under D's lever |
| turn | (−17.5, 0, −7.36) | −X, +Y, −Z (yaw 180°); its leg meets the gland |
| straight | (−18.0, 0.065, −7.36) → (−18.9, 0.065, −7.36) | +Y |
| turn | (−19.4, 0, −7.36) | +Z, +Y, −X (`rotation.y = −PI / 2`) |
| straight | (−19.4, 0.065, −6.86) → (−19.4, 0.065, −5.0) | +Y; it ends in the housing's face |

Joins: 3 of 4; the fourth is the housing.

This replaces D's route, which starts 0.4 m in front of the lever and runs 1.5 m across the floor where the player stands to pull it. The kit's line leaves from behind.

### `power`: the socket, up the Machine Hall's west wall, to the glass door

**Live from** `_on_installed`.

| Piece | Where | Basis X, Y, Z, or normal |
|---|---|---|
| straight | (−14.55, 0.065, −10.5) → (−13.0, 0.065, −10.5) | +Y |
| inside | (−12.5, 0, −10.5) | −X, +Y, −Z (yaw 180°) |
| straight | (−12.565, 0.5, −10.5) → (−12.565, 3.5, −10.5) | −X |
| turn | (−12.5, 4.0, −10.5) | −Y, −X, −Z |
| straight | (−12.565, 4.0, −10.0) → (−12.565, 4.0, −9.14) | −X |
| terminal | (−12.5, 4.0, −8.9) | +Z, −X, −Y |

Joins: 5 of 6; the free end is the socket.

**Where it ends.** The terminal sits 0.22 m short of the glass door's jamb (z −8.5), at 4.0 m, above the door's 3.6 m head. The last run passes 0.11 m under D's `DOOR` badge.

**Why the route changed.** D's route runs along the base of the wall to reach the door. The kit's corners can't do that: to climb from a run parallel to a wall, the run needs 1.0 m of floor between it and the wall (a turn's 0.5 m leg plus an inside corner's). So this line climbs straight up from the socket's run and crosses to the door at 4 m.

### `power_hall`: through the wall, to the lift

**Live from** `_on_installed`.

| Piece | Where | Basis X, Y, Z, or normal |
|---|---|---|
| terminal | (−12.0, 4.0, −8.9) | +Y, +X, −Z; back to back with `power`'s, through the 0.5 m wall |
| straight | (−11.935, 3.76, −8.9) → (−11.935, 0.5, −8.9) | +X |
| inside | (−12.0, 0, −8.9) | +X, +Y, +Z |
| straight | (−11.5, 0.065, −8.9) → (−9.9, 0.065, −8.9) | +Y |
| inside | (−9.4, 0, −8.9) | −X, +Y, −Z (yaw 180°) |
| straight | (−9.465, 0.5, −8.9) → (−9.465, 0.96, −8.9) | −X |
| terminal | (−9.4, 1.2, −8.9) | +Y, −X, +Z; on the shaft's west block, its lamp facing the glass door |

Joins: 6 of 6.

This replaces D's route, which ends on open floor next to the shaft block. On the way, D's route also runs along the glass door's threshold. This route's floor run, at z −8.9, stays in the pocket between the wall and the shaft, clear of the doorway (z −8.5 to −4.5).

### `gate`: the gate lever to the gate's jamb

**Live from** `_on_gate`.

**Turn the gate lever around first** (`rotation.y = PI`). Its front faces the wall across a 0.75 m gap. The player is 0.8 m wide (`PLAYER_RADIUS` 0.4), so nobody can stand where its words and pilot face. The placements below assume it has been turned.

| Piece | Where | Basis X, Y, Z, or normal |
|---|---|---|
| `ck_floor_lever` | (8.4, 9.0, −13.6) | −X, +Y, −Z (yaw 180°): local (0, −1, 0) under the turned lever |
| straight | (8.4, 9.065, −13.24) → (8.4, 9.065, −13.0) | +Y |
| inside | (8.4, 9.0, −12.5) | −Z, +Y, +X (`rotation.y = PI / 2`) |
| straight | (8.4, 9.5, −12.565) → (8.4, 11.1, −12.565) | −Z |
| turn | (8.4, 11.6, −12.5) | +X, −Z, +Y (`rotation.x = −PI / 2`) |
| terminal | (9.14, 11.6, −12.5) | +X, −Z, +Y; its gland meets the turn's leg |

Joins: 4 of 4.

**Where it ends.** The terminal sits on solid wall beside the gate's jamb (x 9.5), 0.8 m under D's `GATE` badge.

This replaces D's route, which climbs 0.1 m inside the gate opening, standing 0.12 m out from the wall in front of the shutter, and stops at 12.0 m on nothing.

## Flags

Nothing in D was changed. These are for Prod and the owner.

**Readability:**
1. **The kit's state stripe is 4 cm wide.** At 20 m it's about 1 px tall at 1080p with a 90° lens. D's whole pipe, which glows, is 12 cm. At a few metres it reads clearly (views below). Check it across the Machine Hall in the fitted review. If it's too thin, the fix is one source constant (`CORE`), a small repair on my side.
2. **The gate lever faces the wall** (see `gate` above).

**Connections, in D as it stands:**

3. **The lift line ends on open floor**, without entering anything.
4. **The gate line runs up the gate opening itself.**
5. **The lock line runs under the player's feet**, right in front of the lever.

The placements above fix all three.

**Obstruction:**

6. **No conduit has a collider, D's or the kit's.**
   - Two runs cross a walking line, and D's own routes cross the same walks:
     - `plate`'s last leg, between the plate and the bridge's near end;
     - `lock`'s x −19.4 leg, between the bridge's far end and the lock lever.
   - Either give those two legs a code-side box no taller than the run (0.125 m), which the player steps over (they already step over the gate's 0.4 m sill), or leave them, and feet pass through 12.5 cm of pipe.
   - Nothing in the kit stands in front of a control: both lever lines leave from behind.

**Colour.** D's own treatment is kept for comparison; I'm flagging it, not changing it. The kit uses D's hexes: power `#55e078`, idle `#347b46`, neutral `#d1d5d2`.

7. **The EXIT signs and the lift's beacon are pale green**, `Color(0.6, 1.0, 0.7)`.
   - Where:
     - `crossing_d_room.gd` lines 456 and 458 (the lift head) and 900 and 905 (the yard exit);
     - `ExitDoor`'s EXIT label (`crossing_d_parts.gd` line 552).
   - If the portal art is missing, the door's fallback core also glows `Color(0.5, 1.0, 0.6)`.
   - Next to the `POWER.lightened(0.3)` sign text, an exit reads as a power control.
8. **Both lever handles are solid POWER green at glow 0.25** (`crossing_d_parts.gd` line 272), whatever the state. So the handle says "live" while its line is idle. Fitting the kit lever hides these, because its handle is neutral.
9. **The lift deck (line 404) and the lift-bridge (line 677) use the theme's `accent`**, `#4f6f8f`. That's a grey-blue 13° from movement blue `#3266ee`. You ride them, so a near-blue may be what's wanted. But it is neither the movement blue nor neutral: the owner's call.
10. **On the kit side, for awareness: the stencilled ON is a fixed green legend.** It labels a position, not the state.

## Views

These are bench views, not D. They show the kit's own review scene in Godot 4.5.1, photographed by the shot runner. The fitted review at player height waits for Prod's trial.
- [The repaired lever, OFF then ON](../review/crossing_kit_2026-10-07/K2_lever_states.png)
- [A line from the repaired lever, unpowered](../review/crossing_kit_2026-10-07/K3_route_off.png), then [live](../review/crossing_kit_2026-10-07/K4_route_on.png). The eye is at 1.6 m, with the game lens.

The 2026-10-02 views show the old lever. They're kept as they were.

## Files, revision and checks

**Branch:** `claude/archipepsi-art-crossing-kit-2026-10-02`.

**What changed:**
- **The source:** `tools/blender/build_crossing_kit.py`, the lever's constants and `floor_lever()`.
- **Regenerated from it:** `ck_floor_lever.glb` and `manifest.json`. The manifest records the lever's mount, its colliders and the moved power exit.
- **Docs:** this note; the lever row in `ART_REVIEW.md`, with a dated note; a dated correction in the 2026-10-02 handoff; both frontiers.
- **Views:** the three above.

**Checks:**
- **Pipeline checks:** the build's own, on every part: 32.0 texels/m, flat shading, every part connected, within budget.
- **Rebuild:** byte-identical across all 15 outputs.
- **`check_docs_metrics.py`:** 388 of 388.
- **`check_art_current.sh`:** the usual configuration. Every static rule and gate ran with no failures, and the interface rebuild matched. Its rebuild of every builder was skipped, as it is designed to be while generated assets are uncommitted (exit 2). The kit's own rebuild, above, is the one that changed.
- **Placement arithmetic:** above, for all five lines.

**Not checked:**
- the kit inside D;
- any runtime driver for the hinges or the line state;
- the pinned-Production run, where the theme-bind failure (FU-1) is still open;
- Windows;
- audio, which is Wisp's.
