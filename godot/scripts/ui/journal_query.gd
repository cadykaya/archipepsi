class_name JournalQuery
extends RefCounted
## WHAT THE JOURNAL SAYS, asked without a Control (H-JOURNAL, `04` §8).
##
## "Journal initially lists real active objectives, completed
## consequences, discovered named places and appropriately earned notes.
## ... the near-term delivery must not invent a finished campaign or spoil
## unvisited rewards. A control's recorded discovery can remind the player
## which door it affects; it should not reveal an undiscovered solution."
##
## **Every line is read from the snapshot, never made up.**
## - Objectives are the Hub's own words (`hub`), and in a Zone its Checks
##   (`active_zone.allocated_location_ids` against
##   `checked_location_ids`).
## - What you did here is the Zone's record (`active_zone.progress`): keys,
##   locks, settings, installed objects, latches, and what they opened.
## - Places and reminders are the bridge's map (`zone_map`), which names
##   a room only once it is found and lists a gate only where it can be
##   walked from a found room.
## - Notes are the Echo log's reads (`BridgeClient.interpretations()`):
##   each is earned by a Check.
##
## **Names come only from the bridge's map.** A room the map does not name
## (not found) is "a way not yet walked", never its save id and never a
## name taken from the full Zone.

## A way on whose far room is not found yet.
const UNWALKED := "a way not yet walked"


## THE OBJECTIVES. In the Hub, the Hub's headline and detail. In a Zone,
## the Zone and its Checks. Then the finale's count, when there is one.
static func objectives(snapshot: Dictionary) -> Array:
	var out: Array = []
	var hub: Dictionary = snapshot.get("hub", {}) \
			if typeof(snapshot.get("hub")) == TYPE_DICTIONARY else {}
	var zone := active_zone(snapshot)
	if zone.is_empty():
		for key: String in ["headline", "detail"]:
			var said := str(hub.get(key, ""))
			if said != "":
				out.append(said)
	else:
		var declared: Dictionary = zone.get("zone", {}) \
				if typeof(zone.get("zone")) == TYPE_DICTIONARY else {}
		var zone_name := str(declared.get("display_name", ""))
		if zone_name != "":
			out.append("In %s" % zone_name)
		var here: Array = zone.get("allocated_location_ids", [])
		if not here.is_empty():
			out.append("Checks here: %d of %d confirmed" % [
					confirmed_of(snapshot, here), here.size()])
	var need := int(hub.get("finale_required", 0))
	if need > 0:
		out.append("Toward the finale: %d of %d Checks" % [
				int(hub.get("finale_progress", 0)), need])
	if bool(hub.get("goal_sent", false)):
		out.append("The goal is sent.")
	return out


## How many of `locations` the campaign has confirmed.
static func confirmed_of(snapshot: Dictionary, locations: Array) -> int:
	var checked := {}
	for loc: Variant in snapshot.get("checked_location_ids", []):
		checked[int(loc)] = true
	var n := 0
	for loc: Variant in locations:
		if checked.has(int(loc)):
			n += 1
	return n


## WHAT YOU DID HERE: the Zone's record, each line with what it opened.
## Empty in the Hub.
static func done_here(snapshot: Dictionary) -> Array:
	var zone := active_zone(snapshot)
	if zone.is_empty():
		return []
	var progress: Dictionary = zone.get("progress", {}) \
			if typeof(zone.get("progress")) == TYPE_DICTIONARY else {}
	var declared: Dictionary = zone.get("zone", {}) \
			if typeof(zone.get("zone")) == TYPE_DICTIONARY else {}
	var map := zone_map(snapshot)
	var names := room_names(map)
	var out: Array = []
	for key: Variant in _sorted(progress.get("collected_keys", [])):
		out.append("Picked up the %s key." % _key_words(declared, str(key)))
	for lock: Variant in _sorted(progress.get("opened_locks", [])):
		var parts := str(lock).split("/")
		var room := parts[0] if parts.size() > 0 else ""
		var key := _door_key(declared, room, parts[1] if parts.size() > 1
				else "")
		out.append("Unlocked the %s door%s." % [
				_key_words(declared, key) if key != "" else "locked",
				_in(names, room)])
	var initial := {}
	for raw: Variant in declared.get("zone_state", []):
		var v: Dictionary = raw
		initial[str(v.get("variable_id", ""))] = str(v.get("initial", ""))
	for raw: Variant in _pairs(progress.get("consumed_objects", [])):
		var pair: Array = raw
		var room := _consumer_room(declared, str(pair[1]))
		out.append("Installed the %s%s." % [_words(str(pair[0])),
				_in(names, room)])
	for raw: Variant in _pairs(progress.get("macro_state", [])):
		var pair: Array = raw
		var variable := str(pair[0])
		var value := str(pair[1])
		# A setting at its declared start is nothing the player did.
		if initial.get(variable, "") == value:
			continue
		var circuit := _circuit(map, "state:" + variable)
		var line := "%s: %s" % [_sentence(_words(variable)), value]
		var setters: Array = []
		for rid: Variant in circuit.get("rooms", []):
			if names.has(str(rid)):
				setters.append(names[str(rid)])
		if not setters.is_empty():
			line += ", set in %s" % ", ".join(setters)
		out.append(line + "." + _opened_by(map, names, circuit))
	for latch: Variant in _sorted(progress.get("latched", [])):
		var package := str(latch).split("/")[0]
		var room := package.trim_prefix("graph_")
		var line := "A latch held%s." % _in(names, room)
		for raw: Variant in map.get("circuits", []):
			var circuit: Dictionary = raw
			if str(circuit.get("circuit_id", "")).begins_with(
					"machine:%s:" % room):
				line += _opened_by(map, names, circuit)
		out.append(line)
	var defeated: Variant = progress.get("defeated")
	if defeated is Array and not (defeated as Array).is_empty():
		out.append("Defeated %d here." % (defeated as Array).size())
	var stations: Array = progress.get("reached_stations", [])
	if not stations.is_empty():
		out.append("Reached %d station%s." % [stations.size(),
				"" if stations.size() == 1 else "s"])
	return out


## STILL SHUT: every gate the bridge's map lists as blocked or unknown,
## with the bridge's reason. The reminder §8 allows: which door a found
## control affects, never where an unfound one is.
static func still_shut(snapshot: Dictionary) -> Array:
	var map := zone_map(snapshot)
	var names := room_names(map)
	var out: Array = []
	for raw: Variant in map.get("connectors", []):
		var row: Dictionary = raw
		var state := str(row.get("state", "open"))
		if state == "open":
			continue
		var reason := str(row.get("reason", ""))
		out.append("%s: %s" % [_way(names, str(row.get("room_a", "")),
				str(row.get("room_b", ""))),
				reason if reason != "" else (
					"shut; only the room can tell" if state == "unknown"
					else "shut")])
	return out


## THE PLACES FOUND, by the bridge's names, in the Zone's order.
static func places(snapshot: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in zone_map(snapshot).get("rooms", []):
		var row: Dictionary = raw
		if bool(row.get("discovered", false)) and str(row.get("name", "")) != "":
			out.append(str(row["name"]))
	return out


## THE NOTES: each Echo's read, newest first. Earned, every one: an Echo
## is in the log only once a Check has delivered it.
static func notes(interpretations: Array) -> Array:
	var rows := interpretations.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("interpretation_seq", 0)) \
				> int(b.get("interpretation_seq", 0)))
	var out: Array = []
	for raw: Variant in rows:
		var row: Dictionary = raw
		var source := str(row.get("source_item_name", ""))
		var game := str(row.get("source_game", ""))
		out.append({
			"title": str(row.get("display_name", "")),
			"text": str(row.get("description", "")),
			"source": ("from %s (%s)" % [source, game]) if source != ""
				else "",
		})
	return out


## THE CAMPAIGN, for the Settings wall: what it is and how far along.
static func campaign(snapshot: Dictionary, online: bool) -> Array:
	var out: Array = []
	if snapshot.is_empty():
		return ["No campaign: connect to Archipelago or start a mock one."]
	var seed := str(snapshot.get("seed_name", ""))
	var slot := str(snapshot.get("slot_name", ""))
	if seed != "":
		out.append("Seed: %s" % seed)
	if slot != "":
		out.append("Player: %s" % slot)
	out.append("Archipelago: %s, %s" % [
			str(snapshot.get("ap_mode", "real")),
			"connected" if bool(snapshot.get("ap_connected", false))
				else "not connected"])
	out.append("Epsilon: %s" % str(snapshot.get("epsilon_provider", "")))
	var checked: Array = snapshot.get("checked_location_ids", [])
	var missing: Array = snapshot.get("missing_location_ids", [])
	out.append("Checks confirmed: %d of %d" % [checked.size(),
			checked.size() + missing.size()])
	out.append("Zones completed: %d" % int(snapshot.get(
			"completed_zone_count", 0)))
	out.append("Link to the bridge: %s" % ("up" if online else "down"))
	return out


# ------------------------------------------------------------ helpers

static func active_zone(snapshot: Dictionary) -> Dictionary:
	var zone: Variant = snapshot.get("active_zone")
	return zone if typeof(zone) == TYPE_DICTIONARY else {}


static func zone_map(snapshot: Dictionary) -> Dictionary:
	var map: Variant = snapshot.get("zone_map")
	return map if typeof(map) == TYPE_DICTIONARY else {}


## `room_id -> name`, for the rooms the bridge's map names (found ones).
static func room_names(map: Dictionary) -> Dictionary:
	var out := {}
	for raw: Variant in map.get("rooms", []):
		var row: Dictionary = raw
		if bool(row.get("discovered", false)) and row.get("name") != null \
				and str(row.get("name", "")) != "":
			out[str(row["room_id"])] = str(row["name"])
	return out


## " in <name>" for a found room, and nothing for one the map does not
## name: an unfound room is not named, not even as an id.
static func _in(names: Dictionary, room_id: String) -> String:
	return (" in %s" % names[room_id]) if names.has(room_id) else ""


static func _way(names: Dictionary, a: String, b: String) -> String:
	var from := str(names.get(a, ""))
	var to := str(names.get(b, ""))
	if from == "" and to == "":
		return _sentence(UNWALKED)
	if from == "":
		return "%s to %s" % [_sentence(UNWALKED), to]
	return "%s to %s" % [from, to if to != "" else UNWALKED]


## " Open now: A to B." for each of a circuit's gates the map lists open.
static func _opened_by(map: Dictionary, names: Dictionary,
		circuit: Dictionary) -> String:
	var ways: Array = []
	var edges: Array = circuit.get("connectors", [])
	for raw: Variant in map.get("connectors", []):
		var row: Dictionary = raw
		if str(row.get("edge_id", "")) in edges \
				and str(row.get("state", "")) == "open":
			ways.append(_way(names, str(row.get("room_a", "")),
					str(row.get("room_b", ""))))
	return (" Open now: %s." % "; ".join(ways)) if not ways.is_empty() else ""


static func _circuit(map: Dictionary, circuit_id: String) -> Dictionary:
	for raw: Variant in map.get("circuits", []):
		if str((raw as Dictionary).get("circuit_id", "")) == circuit_id:
			return raw
	return {}


static func _door_key(declared: Dictionary, room: String,
		socket: String) -> String:
	for raw: Variant in declared.get("chambers", []):
		var chamber: Dictionary = raw
		if str(chamber.get("id", "")) != room:
			continue
		for door: Variant in chamber.get("doors", []):
			var d: Dictionary = door
			if str(d.get("socket_id", "")) == socket:
				return str(d.get("key_id", ""))
	return ""


static func _key_words(declared: Dictionary, key_id: String) -> String:
	for raw: Variant in declared.get("chambers", []):
		for key: Variant in (raw as Dictionary).get("keys", []):
			var k: Dictionary = key
			if str(k.get("key_id", "")) == key_id and k.get("colour") != null \
					and str(k.get("colour", "")) != "":
				return str(k["colour"]).to_lower()
	return _words(key_id)


static func _consumer_room(declared: Dictionary, mechanism: String) -> String:
	for raw: Variant in declared.get("object_consumers", []):
		var c: Dictionary = raw
		if str(c.get("mechanism_id", "")) == mechanism:
			return str(c.get("room_id", ""))
	return ""


static func _words(id: String) -> String:
	return id.replace("_", " ")


## First letter up, the rest as written. (`String.capitalize` would give
## every word a capital: "A Way Not Yet Walked".)
static func _sentence(text: String) -> String:
	return text if text == "" else text[0].to_upper() + text.substr(1)


static func _sorted(values: Variant) -> Array:
	var out: Array = (values as Array).duplicate() if values is Array else []
	out.sort()
	return out


static func _pairs(values: Variant) -> Array:
	var out: Array = []
	if values is Array:
		for raw: Variant in values:
			if raw is Array and (raw as Array).size() >= 2:
				out.append(raw)
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return str(a[0]) < str(b[0]))
	return out
