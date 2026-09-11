# Amalgam slice 1 — engine lane

**Branch:** `claude/archipepsi-amalgam-slice1`
**Started from:** `c8ed2e9` (Production; the playable checkpoint branch is
`claude/archipepsi-echoes-continuation-b1adno`, head `8bb6a05`)
**Lane:** Prod — Godot implementation and integration only. No bridge
schema, no graph, no AP allocation; those are Dess's column and nothing
here implements them.

---

## 1. What is playable

Run the game with `--slice1` and the Zone you enter carries, in addition
to everything it carried before:

- **A three-door junction.** One wide arena uses `entry`, `exit` and
  `side_left`, and declares `side_right` `SEALED`. Three apertures are
  cut; the fourth wall is solid and is *measured* as solid.
- **A red lock and a red key.** `side_left` is `LOCKED`. Its slab stands
  in a carved opening — walk into it without the key and it stops you.
  The key is placed in an earlier room, in space that room reserved for
  it, and picking it up opens every lock it admits anywhere in the Zone.
- **A return plug.** In the last wide room, a pad that lands you back at
  the Zone start. Walking in returns you; walking out re-arms it.

Everything else about the Zone is unchanged. The fixture adds an
assignment; it never changes a room's dimensions or removes content.

**Without `--slice1` nothing above exists** and an ordinary run is
byte-for-byte what it was.

## 2. How to run it

The bridge and the Windows launchers are unchanged. From a checkout of
this branch:

```
# 1. the bridge, as usual
python -m archipepsi_bridge --ap mock --epsilon fallback \
    --save-dir slice1

# 2. the game, with the flag
godot-bin/godot --path godot -- --slice1
```

Both movement flags still apply, so `--slice1 --movement-package=rail`
composes the slice inside a rail Zone.

On Windows the existing `Play 3AB - none (Windows).bat` works if you add
`--slice1` to the Godot line; the launcher was not changed, because
changing it would change the playable checkpoint's launcher too.

**Headless, if you only want to see it compose:**

```
make godot-room-contract
```

The slice's own checks print `ESCAPE`/junction lines and the suite fails
if any of them regress.

## 3. What is implemented and proved

Each of these has a test that fails when the thing it guards is removed;
that was verified by removing them.

| Piece | Where | Proof |
|---|---|---|
| Joining sockets resolved by **id**, not name | `content_instantiator.gd` `socket_by_id` / `socket_for_edge` | every existing shell still composes through the legacy alias path |
| A procedural room **declares four joining sockets** | `chamber_builders.gd` `procedural_sockets` | the junction's side doors land on opposite walls |
| **N apertures carved** from the assignment | `chamber_builders.gd` `cut_plan`, `_perimeter` | three carved, one not |
| **The seal is measured, inverted** | `room_audit.gd` `_assigned_doors_match_their_usage` | a solid wall re-declared `USED` is caught; deleting the probe turns the suite red |
| **A lock is content in a carved opening** | `locked_door.gd`, `space_probe.gd` | the slab blocks with no key and is gone with one; the aperture still measures as a hole |
| **Zone-local keys** | `zone_key.gd`, arena reservation | the key's space is reserved by the room that holds it |
| **Return plugs** | `return_plug.gd`, `zone_builder.gd` anchors | a plug naming an unknown anchor is refused; the destination admits a standing capsule |
| **`LayoutResult` commits the whole chain** | `zone_builder.gd` | `rooms` + `links` per edge, with every connector and corner |
| **Timeout ≠ infeasible** | `zone_builder.gd` | a 0.001 ms budget yields `LAYOUT_TIMEOUT` with candidates remaining |
| **Infeasible is exhausted** | `zone_builder.gd` | a Zone that doubles back into its own arm exhausts the **shipping** policy and reports it; a tightened policy exhausts too, which is what makes the result mean "this space is empty" |
| **Warp stations** | `warp_station.gd` | placed at entrance, exit and large rooms; an unreached station is never a destination; no prompt offers loadout editing |
| **Key reachable before its own lock, by walking** | `room_contract_driver.gd` | flooded walk-only from spawn; the room beyond the lock is *not* reached |

## 4. Implemented but not integrated

- **`LayoutResult` is returned and nothing consumes it.** `ZoneController`
  still reads `root` / `chambers` / `bounds_list`. The bridge is the
  intended consumer (commit, then check 19e) and that is Dess's column.
- **Progress intents are sent and nothing receives them.**
  `key_collected` and `lock_opened` go out on the existing intent channel
  with the shapes the contract specifies. `ZoneProgress` does not exist
  yet on the bridge, so they are currently dropped. The engine side is
  idempotent by identity, so a later receiver needs no engine change.
- **`station_reached`** is specified in the contract and not implemented
  here; warp stations are not in this slice.
- **`Slice1Fixture` is scaffolding.** It decorates an already-composed
  Zone with one valid assignment so the engine half can be walked. It
  invents no topology and is expected to be deleted when the bridge sends
  real `RoomAssignment`s.

## 5. What remains

- The bridge column entirely: `TopologyEdge`, `realization`,
  `DoorAssignment` / `PlugAssignment`, `ZoneProgress`, `DORMANT`, the
  `R ⊆ E` verifier, the manifest and check 19e.
- **Authored** multi-door shells. Slice 1 uses only procedural junctions;
  all twelve authored shells remain two-door and remain valid.
- Spatial cycles, warp stations, ability gates, the exit unlock.

## 5a. A live defect found while closing the infeasibility gap

**Two same-direction corner shells in a row make a Zone the router
cannot place.** `shell_corner_left` twice swings the route 180°, the next
room is placed back along the arm it just left, and `_search` exhausts
every clearance push and both turns without finding a clear position.

`zone_builder.gd`'s header says *"turns alternate direction (no U-shapes
by construction)"*. That guarantee covers **route** turns — the ones
`_plan_route` chooses. It does **not** cover **shell** turns, which come
from a chamber's `exit_yaw` and are the composer's choice. Zone 1 never
hit it because its six corner shells happened to alternate.

This is now the fixture that exercises `LAYOUT_INFEASIBLE` under the
shipping policy, so the branch is proved rather than recorded as
unproved. **The defect itself is not fixed here**: whether the router
should absorb a U-turn or the composer should be forbidden from emitting
one is a composition decision that touches Dess's column, and it is
recorded for that conversation rather than settled unilaterally.

## 6. A pre-existing defect found on the way, and not fixed here

An 18 × 12 procedural arena offers a `cover` ground socket at
`(-5.76, 0, 6.24)` that lands inside the room's own crates. It reproduces
**identically when the same chamber is built with no door assignment at
all**, so it is not multi-door composition's doing.

`_test_the_playable_slice_composes_end_to_end` excludes that one finding
**by name** and fails on any other, so the exclusion cannot hide a
regression this lane causes. It belongs to the arena's ground-socket
placement and wants its own repair.

One related fix *was* made, because it was clearly in the same statement:
the ground-socket loop now excludes `claimed` — the Check's pedestal box
and every key's reserved space — and not only the band's declared
regions. The pedestal is built after that loop runs, so `solid_boxes`
cannot see it, and a socket could be offered inside it.

## 7. Interface status

`docs/reviews/2026-09-12-room-contract-prod-review.md` (on the checkpoint
branch, `8bb6a05`) returned changes requested against `cb3bf64`. **This
slice implements only the parts that are invariant across how the
`TRAVERSAL_ONLY` contradiction is resolved** — socket resolution, N-door
carving, the inverted seal probe, the lock, the key, walk-reachability,
and a plug carrying a source and a destination anchor. Whether a plug is
carried by its own record or by a `DoorAssignment` changes a field name
on the bridge side and nothing in the engine geometry.

**One decision is still the owner's:** whether a `COMPLETE` Zone is
re-enterable (`06_THE_AMALGAM.md` §30.12.1 currently says no, and that is
not an owner ruling in evidence).
