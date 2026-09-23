class_name MinorRooms
extends RefCounted
## O05-06. THE MINORS A BUILT ZONE HOSTS, found in the rooms hosting them.
##
## A minor is a whole room -- the registry shell the builder instantiated
## for a chamber (`minor_unweighted_switch` is `UnweightedSwitchHosted`)
## -- so it is FOUND in that room's node rather than built here. The Zone
## owns only what a Zone owns: persistence. A latch the minor fires
## (`HostedMinor.latched`) is reported as `minor_<room>/<latch>`, which
## the bridge accepts only for a room its ACCEPTED Zone declares a minor
## in, and only the latches that minor's contract declares
## (`schemas/minors.py`). On load the room is put back from the
## campaign's record before anyone sees it.

## The bridge's `MINOR_PACKAGE_PREFIX`, reserved there so no physics
## package can take a name in it.
const PREFIX := "minor_"


static func package_of(room_id: String) -> String:
	return PREFIX + room_id


## `[{room_id, hosted}]` for every minor standing in a built room, in the
## build's room order.
static func hosted_in(build: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in build.get("chambers", []):
		var entry: Dictionary = raw
		var node: Variant = entry.get("node")
		if not is_instance_valid(node):
			continue
		var found := _find(node as Node)
		if found == null:
			continue
		out.append({"room_id": str((entry.get("chamber", {}) as Dictionary)
				.get("id", "")), "hosted": found})
	return out


static func _find(node: Node) -> HostedMinor:
	var own := node as HostedMinor
	if own != null:
		return own
	for child: Node in node.find_children("*", "Node3D", true, false):
		var hosted := child as HostedMinor
		if hosted != null:
			return hosted
	return null


## The latch ids the campaign accepted for this room's minor.
static func accepted_for(room_id: String, refs: Array) -> Array:
	var prefix := package_of(room_id) + "/"
	var out: Array = []
	for ref: Variant in refs:
		if str(ref).begins_with(prefix):
			out.append(str(ref).substr(prefix.length()))
	return out
