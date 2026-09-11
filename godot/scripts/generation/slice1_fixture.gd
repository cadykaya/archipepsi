class_name Slice1Fixture
extends RefCounted
## A composed Zone the engine can build before the bridge can compose one.
##
## **This is scaffolding and says so.** The Amalgam's Layer 2 is the
## bridge's column: which room uses which socket, which edge a door
## carries, where a key goes and which anchor a plug returns to are all
## decisions `RoomAssignment` / `PlugAssignment` will carry, produced
## from the topology graph and the AP allocation. None of that is
## invented here.
##
## What this does is DECORATE an already-composed Zone with one valid
## assignment so the engine half -- N-door carving, the inverted seal
## probe, the lock, the key, the return plug -- can be walked by a human
## and not only asserted by a suite. It is reached by `--slice1` and
## never by ordinary play, and it is expected to be deleted the day the
## bridge sends the real thing.
##
## It changes no room's dimensions and removes no content: every chamber
## keeps the shape it was generated with, so a decorated Zone is the same
## Zone with doors named.

const FLAG := "--slice1"

## The arenas big enough to carry a side door without the opening
## landing on top of the room's own furniture.
const MIN_SPAN := 13.0

static func decorate(zone: Dictionary) -> Dictionary:
	var out := zone.duplicate(true)
	var chambers: Array = out.get("chambers", [])
	var arenas: Array = []
	for i in chambers.size():
		var c: Dictionary = chambers[i]
		if str(c.get("type", "")) != "arena":
			continue
		if float(c.get("width", 0.0)) < MIN_SPAN:
			continue
		arenas.append(i)
	if arenas.size() < 3:
		push_warning("slice1: %d arenas are wide enough; the fixture "
				% arenas.size() + "needs three and is standing down")
		return out

	# The junction: three openings used, the fourth sealed. `side_left`
	# is LOCKED so the slice exercises a gate as well as a third door.
	var junction: Dictionary = chambers[arenas[arenas.size() / 2]]
	junction["doors"] = [
		{"socket_id": "entry", "usage": "USED",
			"edge_id": "slice1:in", "key_id": null},
		{"socket_id": "exit", "usage": "USED",
			"edge_id": "slice1:out", "key_id": null},
		{"socket_id": "side_left", "usage": "LOCKED",
			"edge_id": "slice1:vault", "key_id": "red", "colour": "red"},
		# NOT UNMENTIONED. An unassigned joining socket is a contract
		# violation precisely because "unmentioned" is how an unaudited
		# hole gets into a wall, so the fourth is declared SEALED and is
		# measured with the expectation inverted.
		{"socket_id": "side_right", "usage": "SEALED",
			"edge_id": null, "key_id": null},
	]

	# The key goes in an EARLIER room than the lock it opens, which is
	# the ordering `R ⊆ E` guarantees logically and the engine's walk
	# check proves physically.
	var holder: Dictionary = chambers[arenas[0]]
	holder["keys"] = [{"key_id": "red", "colour": "red"}]

	# The return plug: a dead end's way back, in the last wide room,
	# landing at the Zone start. Both ends are anchors.
	var last_id := str((chambers[arenas[arenas.size() - 1]]
			as Dictionary).get("id", ""))
	out["plugs"] = [{
		"edge_id": "slice1:return",
		"room_id": last_id,
		"source_anchor": "room:%s:arrival" % last_id,
		"destination": "zone_start",
		"device": "pad",
	}]
	return out
