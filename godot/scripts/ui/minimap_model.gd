class_name MinimapModel
extends RefCounted
## WHAT THE MAPS DRAW, asked without a Control (H-MINIMAP, `04` §6-§7).
##
## **Two sources, one each for shape and for state.**
## - **Shape** is the built level: `ZoneController.room_bounds` (each
##   room's real envelope) and `room_joins` (each connector's two sockets
##   and the chain of pieces between them, entry to exit). A connector is
##   drawn where it runs -- turning and climbing -- and never as a straight
##   line between room centres (04 §6).
## - **State** is the bridge's map (`CampaignSnapshot.zone_map`, Dess's
##   H-MAP-DATA): which rooms are discovered and what they are called,
##   which connectors are known, each gate's state and reason, and which
##   circuit it belongs to. Nothing here decides a gate; a colour is not a
##   permission.
##
## **Discovery is the bridge's record plus this session's walking.** A
## room the player is standing in is on the map now, not after the round
## trip; `ZoneController` has already told the bridge (D-2).
##
## **Undiscovered things are not drawn.** A room is drawn only when
## discovered; a connector only when the bridge lists it (the bridge
## already withholds one that cannot be walked from a found room).

## Rooms whose floors differ by less than this share a floor. A connector
## step or a platform path's rise is not a storey.
const FLOOR_STEP := 2.5

## Provisional circuit colours (H-CIRCUITS is Arty's). A key circuit uses
## its key's colour where the colour has a name; any other circuit takes a
## colour from its id, stable across sessions.
const KEY_COLOURS := {
	"red": Color(0.95, 0.30, 0.28),
	"blue": Color(0.35, 0.55, 1.0),
	"green": Color(0.35, 0.90, 0.45),
	"gold": Color(1.0, 0.82, 0.25),
	"yellow": Color(1.0, 0.90, 0.30),
	"purple": Color(0.75, 0.45, 0.95),
	"white": Color(0.92, 0.92, 0.92),
}
## For circuits that are not keys: colours chosen to be none of the key
## colours, so a power circuit never reads as the green key's door.
const PALETTE := [
	Color(0.30, 0.90, 0.95), Color(1.0, 0.55, 0.15), Color(0.95, 0.40, 0.75),
	Color(0.20, 0.72, 0.60), Color(0.72, 0.95, 0.25),
]


## The rooms to draw: `{id, name, type, rect (XZ), floor_y, here}`.
##
## `floors` is each room's standing height -- its ARRIVAL, where a body
## actually stands (`ZoneController.room_places`). Not the envelope's
## bottom: a room with a pit has a box that reaches far below its floor,
## and the first draft of this read a pit as a storey 70 m down.
static func rooms(zone_map: Dictionary, room_bounds: Dictionary,
		entered: Dictionary, current: String,
		floors: Dictionary = {}) -> Array:
	var discovered := {}
	var names := {}
	var types := {}
	for raw: Variant in zone_map.get("rooms", []):
		var row: Dictionary = raw
		var rid := str(row.get("room_id", ""))
		types[rid] = str(row.get("type", ""))
		if bool(row.get("discovered", false)):
			discovered[rid] = true
			names[rid] = str(row.get("name", ""))
	var out: Array = []
	for rid: Variant in room_bounds:
		var id := str(rid)
		if not (discovered.has(id) or entered.has(id)):
			continue
		var box: AABB = room_bounds[rid]
		out.append({
			"id": id,
			# A room walked this session that the bridge has not echoed
			# back yet has no name from it; its type is what is known.
			"name": str(names.get(id, "")) if names.has(id)
					else str(types.get(id, "")).replace("_", " ").capitalize(),
			"type": str(types.get(id, "")),
			"rect": Rect2(box.position.x, box.position.z, box.size.x,
					box.size.z),
			"floor_y": float(floors.get(id, box.position.y)),
			"here": id == current,
		})
	return out


## The connectors to draw: the bridge's list, each given its real path.
## `{edge_id, realization, path (XZ points), ys, state, reason, gates,
## circuits, mark_at, symbol}`.
##
## A connector with no join -- a return plug, which is a device and not a
## corridor (`traversal_only`) -- keeps an empty path and is marked where
## the device stands (`plugs`, `ZoneController.plug_positions`). One the
## build has no device for keeps `mark_at` at `Vector2.INF` and is not
## drawn: the map does not guess where a way back is.
static func connectors(zone_map: Dictionary, joins: Dictionary,
		plugs: Dictionary = {}) -> Array:
	var out: Array = []
	for raw: Variant in zone_map.get("connectors", []):
		var row: Dictionary = raw
		var eid := str(row.get("edge_id", ""))
		var points := PackedVector2Array()
		var ys := PackedFloat32Array()
		var join: Variant = joins.get(eid)
		if typeof(join) == TYPE_DICTIONARY:
			for at: Vector3 in path_of(join as Dictionary):
				points.append(Vector2(at.x, at.z))
				ys.append(at.y)
		var mark := midpoint(points)
		var device: Variant = plugs.get(eid)
		if points.is_empty() and device is Vector3:
			mark = Vector2((device as Vector3).x, (device as Vector3).z)
			ys.append((device as Vector3).y)
		out.append({
			"edge_id": eid,
			"realization": str(row.get("realization", "")),
			"room_a": str(row.get("room_a", "")),
			"room_b": str(row.get("room_b", "")),
			"path": points,
			"ys": ys,
			"state": str(row.get("state", "unknown")),
			"reason": str(row.get("reason", "")),
			"gates": row.get("gates", ["none"]),
			"circuits": row.get("circuits", []),
			"mark_at": mark,
			"symbol": symbol(row.get("gates", ["none"])),
		})
	return out


## A join, walked the way the bridge validates it: socket, each piece's
## entry and exit, socket. An empty chain is two rooms abutting.
static func path_of(join: Dictionary) -> Array:
	var out: Array = []
	var a: Variant = join.get("socket_a")
	if a is Vector3:
		out.append(a)
	for raw: Variant in join.get("chain", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var piece: Dictionary = raw
		for key: String in ["entry", "exit"]:
			var at: Variant = piece.get(key)
			if at is Vector3 and (out.is_empty()
					or (out[out.size() - 1] as Vector3).distance_to(at)
						> 0.05):
				out.append(at)
	var b: Variant = join.get("socket_b")
	if b is Vector3:
		out.append(b)
	return out


## Where along a path its gate mark goes: halfway by length, so a turning
## corridor's mark sits on the corridor rather than between its ends.
static func midpoint(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.INF
	var total := length_of(points)
	var half := total * 0.5
	var walked := 0.0
	for i in range(1, points.size()):
		var step := points[i - 1].distance_to(points[i])
		if walked + step >= half and step > 0.0:
			return points[i - 1].lerp(points[i], (half - walked) / step)
		walked += step
	return points[points.size() - 1]


static func length_of(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## THE REASON AS A SYMBOL, beside the colour (04 §6: "supplement colour
## with reason symbols"): K key, P power or setting, M mechanism, E an
## Echo to equip, ? a gate whose state only the room can tell.
static func symbol(gates: Variant) -> String:
	var kinds: Array = gates if gates is Array else [gates]
	if kinds.has("key"):
		return "K"
	if kinds.has("zone_state"):
		return "P"
	if kinds.has("machine"):
		return "M"
	if kinds.has("capability"):
		return "E"
	return ""


## EVERY CIRCUIT'S COLOUR IN THIS ZONE, decided once from what the Zone
## declares (provisional; H-CIRCUITS is Arty's).
##
## 04 §6: "Two unrelated circuits in one place need distinct identity even
## if colours are reused elsewhere." A hash of the id gave the span and the
## power circuit the same colour in the candidate Zone, so colours are
## dealt out instead: a key circuit keeps its key's colour; every other
## circuit takes the next palette colour, in the Zone's declaration order.
## That order is the Zone's content, not the player's discoveries, so a
## circuit's colour never changes as more of the map is found -- and it
## says nothing about circuits not yet found.
static func circuit_colours(zone: Dictionary) -> Dictionary:
	var out := {}
	for raw: Variant in zone.get("chambers", []):
		var chamber: Dictionary = raw
		for door: Variant in chamber.get("doors", []):
			var d: Dictionary = door
			if str(d.get("usage", "")) == "LOCKED":
				var key := str(d.get("key_id", ""))
				out["key:" + key] = key_colour(key, d.get("colour"))
		for key_raw: Variant in chamber.get("keys", []):
			var k: Dictionary = key_raw
			var key := str(k.get("key_id", ""))
			out["key:" + key] = key_colour(key, k.get("colour"))
	var order: Array = []
	for raw: Variant in zone.get("zone_state", []):
		order.append("state:" + str((raw as Dictionary).get("variable_id",
				"")))
	for raw: Variant in zone.get("edges", []):
		var e: Dictionary = raw
		var by: Variant = e.get("opened_by")
		if by == null or str(by) == "":
			continue
		for graph_raw: Variant in zone.get("room_graphs", []):
			var g: Dictionary = graph_raw
			for actuator: Variant in g.get("actuators", []):
				if str((actuator as Dictionary).get("actuator_id", "")) \
						== str(by):
					order.append("machine:%s:%s" % [
							str(g.get("room_id", "")), str(by)])
	var next := 0
	for cid: Variant in order:
		if not out.has(cid):
			out[cid] = PALETTE[next % PALETTE.size()]
			next += 1
	return out


static func key_colour(key_id: String, named: Variant) -> Color:
	var name := (str(named) if named != null else key_id).to_lower()
	return KEY_COLOURS.get(name, KEY_COLOURS.get(key_id.to_lower(),
			Color(0.9, 0.9, 0.9)))


## Which floor a height is on, relative to the floor the player stands on:
## 0 here, +1 above, -1 below.
static func floor_offset(y: float, player_floor_y: float) -> int:
	var delta := y - player_floor_y
	if absf(delta) < FLOOR_STEP:
		return 0
	return 1 if delta > 0.0 else -1


## THE FLOOR MARK, as a shape: a triangle pointing up for a room above,
## down for one below. Drawn, not typed: Godot's default font has no ▲ or
## ▼, and the first draft's marks would have been blanks (§9: an
## unsupported character needs a visible fallback, not a blank).
static func floor_triangle(at: Vector2, level: int,
		r: float = 5.0) -> PackedVector2Array:
	var tip := -1.0 if level > 0 else 1.0
	return PackedVector2Array([at + Vector2(0, tip * r),
			at + Vector2(r, -tip * r * 0.8), at + Vector2(-r, -tip * r * 0.8)])


## The name of the room the player is in, as the map shows it.
static func here_name(rooms_drawn: Array) -> String:
	for row: Dictionary in rooms_drawn:
		if bool(row.get("here", false)):
			return str(row.get("name", ""))
	return ""
