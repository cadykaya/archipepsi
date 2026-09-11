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

	# AND THE VAULT IS A ROOM, not a name on a door.
	#
	# `slice1:vault` used to be an edge id on a locked door with nothing
	# on the other side of it: the door opened onto the outside of the
	# room's wall. A branch is a real chamber now, placed off that side
	# socket by the same route search the chain uses, so the slice can be
	# WALKED -- through the lock, into the branch, and back out through
	# its plug.
	#
	# IT HOLDS NO CHECK, and that is deliberate rather than an oversight.
	# The owner's design puts Checks in a gated dead end, and a Check id
	# is an AP allocation: inventing one here would be this file claiming
	# a decision that belongs to the bridge. It carries a puzzle instead,
	# which needs no allocation, and the real vault gets its Checks when
	# `RoomAssignment` arrives.
	junction["branches"] = [{
		"socket_id": "side_left",
		"return_to": "zone_start",
		"chamber": {
			"id": "vault", "type": "arena",
			"width": 14.0, "depth": 12.0, "wall_height": 5.0,
			"objective": "reach_exit", "enemies": [],
			"activities": [{"kind": "target_challenge",
					"element_count": 3}],
			"features": [], "reward_location_id": null,
			"additional_reward_location_ids": [],
		},
	}]

	# The key goes in an EARLIER room than the lock it opens, which is
	# the ordering `R ⊆ E` guarantees logically and the engine's walk
	# check proves physically.
	var holder: Dictionary = chambers[arenas[0]]
	holder["keys"] = [{"key_id": "red", "colour": "red"}]

	# THE RETURN PLUG IS IN THE DEAD END, which is the only place a
	# return plug means anything.
	#
	# It used to stand in the last room of the CHAIN -- a room the player
	# walks out of anyway -- so the feature was placed where it could
	# never be needed. The vault has one way in and the plug is the way
	# back, which is the owner's ruling: "its ok to dead end, but if it
	# does, it needs to end with some way to get back to the entrance".
	out["plugs"] = [{
		"edge_id": "slice1:return",
		"room_id": "vault",
		"source_anchor": "room:vault:arrival",
		"destination": "zone_start",
		"device": "pad",
	}]
	return out
