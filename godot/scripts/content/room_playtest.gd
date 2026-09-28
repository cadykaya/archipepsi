class_name RoomPlaytest
extends RefCounted
## THE CONCOURSE-PIER PLAYTEST (owner brief, 2026-09-28): Arty's one
## ordinary room, `shell_concourse_pier` (art `697fd8af`), in a short
## route of the real game, in two modes.
##
##   godot --path godot -- --concourse-pier              empty
##   godot --path godot -- --concourse-pier --populated  one encounter
##
## THE ROUTE is the real Zone flow, the one `ShowcaseZone` already uses:
## `ZoneBuilder` lays the Zone's own arrival, an ordinary procedural
## corridor as the approach, the room, and the Zone's own exit portal.
## `Main` runs it with the real `Player`, HUD and menu. Whatever would
## take the player to the Hub -- the exit portal, RETURN TO HUB, ABANDON
## -- builds the route again from its start instead: that is the reset.
## (Offline, the Hub is a dead end: its portal is disabled.)
##
## SCAFFOLDING, on the showcase's terms. The room is named by hand. That is
## not composition, and it says nothing about whether generation should
## choose it. Nothing here runs unless an operator asks for it by name.
##
## ISOLATED BEFORE ANYTHING CONNECTS. `BridgeClient` checks `requested()`
## in its own `_ready`, before any socket exists, and then opens none and
## retries none. So a campaign bridge left running on the machine never
## hears from this launch, and nothing it does can reach a campaign save.
## The client's own three preference files (settings, favourites, seen
## items) are read but never written while `requested()`.
##
## THE LOAD EXCEPTION. The room is `review: pending`, and the game refuses
## to build a pending shell (`VisualOwnership.is_shippable`). The owner
## authorized loading it for this isolated playtest only, so `admit()`
## lifts the gate for this one id, in this process's in-memory registry,
## and for nothing else. The catalogue file stays `pending`, the bridge
## still refuses to offer it (`shells.py`), and no other launch ever
## calls `admit()`.
##
## ONE CONTROLLED DIFFERENCE. Both modes build the same route, the same
## lights, the same objective (`reach_reward`) and the same exit. Only
## the populated mode has enemies, and killing them is never needed to
## leave: the question is whether combat improves the space, not a new
## gate.

const FLAG := "--concourse-pier"
const POPULATED_FLAG := "--populated"

const SHELL_ID := "shell_concourse_pier"
const ZONE_ID := "playtest_concourse_pier"
const ROOM_ID := "cp_room"
const APPROACH_ID := "cp_approach"
const THEME := "concrete_facility"

## The approach: an ordinary procedural corridor, the room the game builds
## everywhere, at the width the fixtures' corridors use.
const APPROACH_WIDTH := 6.0

## The same objective in both modes. `reach_reward` is the arena's own
## default, and nothing about it needs the encounter to be killed.
const OBJECTIVE := "reach_reward"

## The room's floor-to-roof height, as its handoff states it (Arty,
## `docs/art/reports/2026-09-28-ordinary-room.md`: "7.0 m to the roof").
## Not derived from `size`, which also carries the floor and roof slabs.
const INTERIOR_HEIGHT := 7.0

## THE ENCOUNTER, populated mode only: two existing roles, placed through
## the existing `enemy_spawn` volume mechanism, one volume each, in this
## order (`ContentInstantiator._enemy_spawns` deals volumes round-robin).
## - `ranged` holds the pier top. It does not walk, so its position is its
##   whole plan: it covers both floor lanes and the bridge, and the pier's
##   own mass, the gallery and the parapets are the cover against it.
## - `melee` starts behind the pier on the exit side, on the floor, and
##   walks at the player. Enemies steer directly (no navmesh), so what it
##   does around the pier and at the stairs is measured by the live check,
##   not assumed from the riser height.
const ENCOUNTER := [
	{"archetype": "ranged", "count": 1},
	{"archetype": "melee", "count": 1},
]
## Room-local, as the registry entry writes positions: x across, y the
## standing surface, z from the entry wall. Laid over the in-memory entry
## by `admit()`; the catalogue entry declares none.
const SPAWN_VOLUMES := [
	# 0.6 m back from the pier's open front edge (z 8.0). Set back 1.2 m,
	# every shot at a player below the pier's front clipped that edge (the
	# shot is a 0.2 m sphere; measured, room-local (-0.58, 3.68, 7.95)).
	{"name": "playtest_pier_top", "kind": "enemy_spawn",
		"center": [-1.0, 3.5, 8.8], "size": [0.4, 0.0, 0.4]},
	{"name": "playtest_behind_pier", "kind": "enemy_spawn",
		"center": [4.8, 0.0, 16.5], "size": [0.4, 0.0, 0.4]},
]


## Whether this launch asked for the playtest.
static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


static func populated_requested() -> bool:
	return POPULATED_FLAG in OS.get_cmdline_user_args()


## THE ONE EXCEPTION. Returns "" when the room may be built, else why not.
##
## Lifts `review` for `SHELL_ID` only, and only while it says `pending`: if
## the owner passes the room, this becomes a no-op rather than a second
## source of truth. Adds the encounter's spawn volumes to that entry, in
## memory, and touches no other entry.
static func admit(registry: ContentRegistry) -> String:
	if not requested():
		return "the load exception is for a --concourse-pier launch only"
	if registry == null or not registry.has(SHELL_ID):
		return "the registry does not carry '%s'" % SHELL_ID
	var entry: Dictionary = registry.get_entry(SHELL_ID)
	if str(entry.get("review", "")) == VisualOwnership.REVIEW_PENDING:
		entry["review"] = VisualOwnership.REVIEW_PASS
	var volumes: Array = entry.get("volumes", []) as Array
	for raw: Variant in SPAWN_VOLUMES:
		var already := false
		for have: Variant in volumes:
			if typeof(have) == TYPE_DICTIONARY and str((have as Dictionary)
					.get("name", "")) == str((raw as Dictionary)["name"]):
				already = true
		if not already:
			volumes.append((raw as Dictionary).duplicate(true))
	entry["volumes"] = volumes
	return ""


## The Zone. The room's dimensions come from its own entry, as the
## showcase's do: the chamber asks for the room the art lane authored.
static func build(populated: bool,
		registry: ContentRegistry = null) -> Dictionary:
	var reg := registry if registry != null else ContentRegistry.shared()
	var size: Array = reg.get_entry(SHELL_ID).get("size", [16.8, 7.9, 22.8])
	var room := {
		"id": ROOM_ID,
		"type": "arena",
		"shell_id": SHELL_ID,
		"objective": OBJECTIVE,
		"enemies": ENCOUNTER.duplicate(true) if populated else [],
		"activities": [],
		"width": float(size[0]) - 2.0 * ChamberBuilders.WALL_THICKNESS,
		"wall_height": float(size[1]),
		"depth": float(size[2]) - 2.0 * ChamberBuilders.WALL_THICKNESS,
	}
	var approach := {
		"id": APPROACH_ID,
		"type": "corridor",
		"shell_id": null,
		"width": APPROACH_WIDTH,
		"objective": OBJECTIVE,
		"enemies": [],
		"activities": [],
	}
	return {
		"schema_version": 1,
		"zone_id": ZONE_ID,
		"display_name": "Concourse pier playtest" \
				+ (" — populated" if populated else " — empty"),
		"theme": THEME,
		"target_game": "Archipepsi",
		"designer_note": "Owner-authorized playtest of the pending room "
				+ "shell_concourse_pier. Not composition, not saved, "
				+ "not connected.",
		"chambers": [approach, room],
	}


## The room's shell node in a built Zone, found by the meta the
## instantiator stamps on it; null when the shell was not built (a
## procedural substitute carries no such meta).
static func shell_root(zone: Node) -> Node3D:
	if zone == null:
		return null
	if zone is Node3D and zone.has_meta(ContentInstantiator.SHELL_META) \
			and str(zone.get_meta(ContentInstantiator.SHELL_META)) \
				== SHELL_ID:
		return zone as Node3D
	for child: Node in zone.get_children():
		var found := shell_root(child)
		if found != null:
			return found
	return null


## Room-local positions and ranges of the lights: the procedural arena's
## own arrangement (`ChamberBuilders.arena`: two diagonal corners 2 m in
## from the side and end walls at wall height less 0.5 m, range 16, and
## the middle at range 18), measured against this room's interior.
static func light_plan(interior_width: float, depth: float,
		wall_height: float) -> Array:
	var y := wall_height - 0.5
	return [
		[Vector3(-interior_width / 2.0 + 2.0, y, 2.0), 16.0],
		[Vector3(interior_width / 2.0 - 2.0, y, depth - 2.0), 16.0],
		[Vector3(0.0, y, depth / 2.0), 18.0],
	]


## Light the room through the existing fixture (`ChamberBuilders._light`:
## the theme's omni light and its housing), identically in both modes.
## Returns how many lights were placed; 0 means the shell was not found.
static func light(zone: Node, registry: ContentRegistry = null) -> int:
	var root := shell_root(zone)
	if root == null:
		return 0
	var reg := registry if registry != null else ContentRegistry.shared()
	var size: Array = reg.get_entry(SHELL_ID).get("size", [16.8, 7.9, 22.8])
	var wall := ChamberBuilders.WALL_THICKNESS
	var placed := 0
	for spec: Array in light_plan(float(size[0]) - 2.0 * wall,
			float(size[2]) - 2.0 * wall, INTERIOR_HEIGHT):
		ChamberBuilders._light(root, spec[0], THEME, float(spec[1]))
		placed += 1
	return placed
