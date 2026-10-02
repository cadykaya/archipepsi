class_name MachineLifeDriver
extends Node
## NOTHING ACCRUES ACROSS REPEATED LIFECYCLES (`make godot-machine-life`).
##
## O05-10.4, the part of ownership and isolation with no dedicated
## measurement: "counters or resources do not accrue repeated effects
## after several enter/leave/restart cycles". The candidate-live chain
## restarts the process eight times and asserts nothing is announced
## twice, "but no counter is read across cycles" (PROD_OV05, O05-10).
##
## **THROUGH THE REAL `Main`, BESIDE IT**, as the reload proof runs. What
## outlives a Zone is `Main`'s: the HUD, the minimap, the map and journal
## faces, the rule runtime, the resource pool, the tones, and the
## `BridgeClient` autoload. So a cycle is `Main`'s own `_to_zone` and
## `_to_hub`, with the Zone record a bridge would serve
## (`BridgeClient.snapshot`), and not a controller built beside it.
##
## **A ROUND:** the Hub, then each Zone, then the Hub again.
## - The Zones are the played candidate and the Passing Platforms Zone.
##   Between them they hold every occurrence this line has built:
##   - the reversible doorway (`span_alignment`);
##   - the carried power cell and its consumer;
##   - c009's latched route;
##   - the Unweighted Switch and the Counterfire Arcade;
##   - EX50-011's carriers.
## - The first round enters fresh. Every later round re-enters with the
##   progress a save would carry (`RESTORED`: a state variable and two
##   latches), which is the restore path a restart takes.
## - In each Zone: pull every zone-state lever once, then die and come
##   back `DEATHS` times. The deaths are the in-Zone restart, and the
##   minors' own death rules run on them.
## - Each Zone is left the way a player leaves it, through the pause
##   menu's return to the Hub.
##
## **READ AT THE SAME POINT EVERY TIME**, at the Hub after each round and
## in each Zone after its operations:
## - the engine's counts: nodes, orphan nodes, objects, resources;
## - every signal connection on `BridgeClient`, and in and out of each of
##   `Main`'s long-lived nodes;
## - group membership over the whole tree, and running tweens;
## - the static caches the builders keep.
##
## Every later round must read what the second did, at the Hub and in each
## Zone. The first round is the fresh one and fills the caches, so it is
## reported but not compared. What one operation does must not grow
## either: one lever pull sends one `zone_state_selected`, and one death
## makes one respawn.

const FLAG := "--machine-life"
const ROUNDS := 5
const DEATHS := 2
const ZONES := {
	"candidate": "res://tests/fixtures/candidate_zone.json",
	"passing": "res://tests/fixtures/passing_zone.json",
}
## What a save carries into every round after the first, per Zone: the
## reversible variable as a pull left it, and the two latches the
## candidate's machinery records (the arcade's release and c009's held
## route). A record, not a mechanism: the Zone recomputes what each
## implies when it is built (§5.4a).
const RESTORED := {
	"candidate": {"macro_state": [["span_alignment", "lowered"]],
			"latched": ["minor_c025/release", "graph_c009/held"],
			"defeated": []},
	"passing": {"defeated": []},
}
## Transient UI (a toast, a fade) is given this long to finish before a
## Hub reading, so a reading is of what stays.
const HUB_SETTLE_FRAMES := 360
## THE ONE COUNTER READ WITH SLACK: the engine's object count moves by up
## to 8 between identical rounds (short-lived RefCounted objects: query
## parameters, timers). It is the coarse check: a leak of 8 objects a
## round is past this by round 5. A node, a connection, a group member or
## an orphan is caught exactly, by its own counter.
const SLACK := {"objects": 24}

var main: Node
static var _DIGITS := RegEx.create_from_string("[0-9]+")
var checks := 0
var failures := 0
## Per round, read at the Hub.
var _hub: Array[Dictionary] = []
## Zone key -> per round, read in the Zone after its operations.
var _in_zone: Dictionary = {}
## Zone key -> per round, what the operations did.
var _effects: Dictionary = {}


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	_run()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: " + message)
	else:
		failures += 1
		print("FAIL: " + message)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(30)
	var was_assumed: bool = BridgeClient.assume_sent
	BridgeClient.assume_sent = true
	main._to_hub()
	await _frames(HUB_SETTLE_FRAMES)
	var baseline := _read()
	for key: String in ZONES:
		_in_zone[key] = []
		_effects[key] = []
	for turn in ROUNDS:
		for key: String in ZONES:
			await _visit(key, turn)
			# LEFT THE WAY A PLAYER LEAVES: the pause menu's "return to the
			# Hub", which sends the timing, remembers the progress in
			# `Main`'s own dictionaries and sends `leave_zone`.
			main._on_return_to_hub()
			await _frames(30)
		await _frames(HUB_SETTLE_FRAMES)
		_hub.append(_read())
	BridgeClient.assume_sent = was_assumed
	_report(baseline)
	if failures == 0:
		print("GODOT MACHINE LIFE OK (%d checks, %d rounds)" % [checks, ROUNDS])
	else:
		print("GODOT MACHINE LIFE TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


## One Zone, entered the way `Main` enters it, operated, restarted.
func _visit(key: String, turn: int) -> void:
	var zone_dict: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(str(ZONES[key])))
	var zid := str(zone_dict.get("zone_id", ""))
	var progress: Dictionary = (RESTORED[key] as Dictionary).duplicate(true) \
			if turn > 0 else {"defeated": []}
	BridgeClient.snapshot = {"active_zone": {"zone_id": zid,
			"layout_state": "ACCEPTED", "progress": progress}}
	BridgeClient.sent_intents.clear()
	var sent_before: int = BridgeClient.sent_total
	# EVERY ENEMY THAT DIES HERE, AND WHERE. Nobody fights in this suite,
	# so a death is the world's doing, and it is named. Watched from the
	# moment each enemy enters the tree: encounters spawn theirs late.
	var fallen: Array = []
	var watch := func(node: Node) -> void:
		if node is Enemy:
			var foe: Enemy = node
			foe.enemy_died.connect(func(dead: Enemy) -> void:
				fallen.append("%s member '%s' died at %v (room %s), %.1f s in"
						% [dead.name, dead.member, dead.global_position,
							_room_at(main.zone, dead.global_position),
							Time.get_ticks_msec() / 1000.0]))
	get_tree().node_added.connect(watch)
	main._to_zone(zone_dict)
	var zone: ZoneController = main.zone
	_tracking = true
	_track(zone, "%s round %d" % [key, turn + 1])
	for _i in 900:
		if zone.layout_verdict != "":
			break
		await get_tree().physics_frame
	await _frames(30)
	var effects := {"verdict": zone.layout_verdict}
	# EVERY ZONE-STATE LEVER, PULLED ONCE.
	var pulls := 0
	for setter: Variant in zone.zone_state_setters():
		if is_instance_valid(setter) and (setter as Node).has_method("interact"):
			(setter as Node).interact(zone.player)
			pulls += 1
			await _frames(10)
	effects["pulls"] = pulls
	# DIE AND COME BACK. Counted from the player's own signals, through
	# a container: a lambda's captured int is a copy.
	var seen := {"died": 0, "respawned": 0}
	var player: Player = zone.player
	player.died.connect(func() -> void: seen["died"] += 1)
	for _d in DEATHS:
		player.take_damage(1.0e6, Vector3.INF, false)
		for _i in 240:
			await get_tree().physics_frame
			if player.hp >= Constants.PLAYER_MAX_HP and not player._dead:
				seen["respawned"] += 1
				break
		await _frames(10)
	effects["died"] = seen["died"]
	effects["respawned"] = seen["respawned"]
	# What the Zone's own listeners counted: a death rule wired twice
	# would count a death twice here and nowhere else.
	effects["deaths logged"] = zone.playtime._deaths
	await _frames(30)
	(_in_zone[key] as Array).append(_read())
	var by_type := {}
	for intent: Dictionary in BridgeClient.sent_intents:
		var kind := str(intent.get("type", "?"))
		by_type[kind] = int(by_type.get(kind, 0)) + 1
	effects["sent"] = BridgeClient.sent_total - sent_before
	effects["by type"] = by_type
	effects["state changes"] = zone.zone_state_changes.size()
	effects["enemies died"] = fallen
	_tracking = false
	get_tree().node_added.disconnect(watch)
	(_effects[key] as Array).append(effects)


var _tracking := false


## DIAGNOSTIC: every enemy's last few seconds, reported the moment one
## leaves the room it started in or drops 3 m.
func _track(zone: ZoneController, label: String) -> void:
	var tracks := {}
	var reported := {}
	var step := 0
	var t0 := Time.get_ticks_msec()
	while _tracking and is_instance_valid(zone):
		await get_tree().physics_frame
		step += 1
		if step % 15 != 0 or not is_instance_valid(zone):
			continue
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if not (node is Enemy) or not is_instance_valid(node) \
					or not zone.is_ancestor_of(node):
				continue
			var foe: Enemy = node
			var key := "%s@%d" % [foe.member, foe.get_instance_id()]
			var here := _room_at(zone, foe.global_position)
			if not tracks.has(key):
				tracks[key] = {"start": foe.global_position, "room": here,
						"samples": []}
			var track: Dictionary = tracks[key]
			var samples: Array = track["samples"]
			samples.append("%.2fs %v job=%s ret=%s floor=%s dead=%s player=%s" % [
					(Time.get_ticks_msec() - t0) / 1000.0,
					foe.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
					foe.job, foe.returning, foe.is_on_floor(), foe._dead,
					(zone.player.global_position.snapped(Vector3(0.1, 0.1, 0.1))
						if is_instance_valid(zone.player) else Vector3.ZERO)])
			if samples.size() > 40:
				samples.pop_front()
			var start: Vector3 = track["start"]
			if not reported.has(key) and (foe.global_position.y < start.y - 3.0
					or here != str(track["room"])):
				reported[key] = true
				print("  LEFT (%s): %s %s from %v in %s, now %v in %s, post %v"
						% [label, key, foe.archetype, start, track["room"],
							foe.global_position, here, foe.post])
				for line: String in samples:
					print("      " + line)


static func _room_at(zone: ZoneController, at: Vector3) -> String:
	for rid: Variant in zone.room_bounds:
		if (zone.room_bounds[rid] as AABB).grow(0.5).has_point(at):
			return str(rid)
	return "none"


## Everything that could accrue, as numbers.
func _read() -> Dictionary:
	var out := {}
	out["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	out["orphan nodes"] = int(Performance.get_monitor(
			Performance.OBJECT_ORPHAN_NODE_COUNT))
	out["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	out["resources"] = int(Performance.get_monitor(
			Performance.OBJECT_RESOURCE_COUNT))
	out["tweens"] = get_tree().get_processed_tweens().size()
	_connections("BridgeClient", BridgeClient, out)
	for field: String in ["hud", "minimap", "map_face", "journal",
			"equipment", "menu_shell", "rule_runtime", "resource_pool",
			"tones", "world"]:
		var node: Variant = main.get(field)
		if node is Object and is_instance_valid(node):
			_connections("Main." + field, node, out)
	_connections("Main", main, out)
	# `Main`'s in-memory progress, kept per Zone id: bounded by what the
	# Zones hold, so it must stop growing once they have been played.
	for field: String in ["_zone_resume", "_zone_stations", "_zone_keys",
			"_zone_locks_open", "_zone_latches", "_zone_defeats"]:
		var held: Variant = main.get(field)
		var entries := 0
		if typeof(held) == TYPE_DICTIONARY:
			for zid: Variant in held as Dictionary:
				var inner: Variant = (held as Dictionary)[zid]
				entries += (inner as Dictionary).size() \
						if typeof(inner) == TYPE_DICTIONARY else 1
		out["Main." + field] = entries
	var groups := {}
	_groups_under(get_tree().root, groups)
	for group: String in groups:
		out["group " + group] = groups[group]
	out["ThemeMaterials._cache"] = ThemeMaterials._cache.size()
	out["ThemeMaterials._theme_cache"] = ThemeMaterials._theme_cache.size()
	out["ProcTextures._cache"] = ProcTextures._cache.size()
	out["Tones._enemy_cache"] = Tones._enemy_cache.size()
	out["ThemePack._cache"] = ThemePack._cache.size()
	return out


## Out of every signal `who` has, and into `who` from anywhere.
static func _connections(label: String, who: Object, out: Dictionary) -> void:
	var outgoing := 0
	for sig: Dictionary in who.get_signal_list():
		outgoing += who.get_signal_connection_list(str(sig["name"])).size()
	out[label + " out"] = outgoing
	out[label + " in"] = who.get_incoming_connections().size()


static func _groups_under(node: Node, into: Dictionary) -> void:
	for group: StringName in node.get_groups():
		# Godot's own bookkeeping groups are counted like any other: they
		# are nodes. Some carry an instance id (`_vp_input1234`), which a
		# rebuilt viewport changes, so digits are folded: the count is
		# what is compared, not the id.
		var name := _DIGITS.sub(str(group), "#", true)
		into[name] = int(into.get(name, 0)) + 1
	for child: Node in node.get_children():
		_groups_under(child, into)


func _report(baseline: Dictionary) -> void:
	print("")
	print("  -- AT THE HUB, after each round (round 1 is the fresh one)")
	_table(baseline, _hub, "hub")
	for key: String in ZONES:
		print("")
		print("  -- IN %s, after its operations, each round" % key.to_upper())
		_table({}, _in_zone[key] as Array, key)
	# LIVE READINGS: a Zone must read above the Hub, or nothing here
	# measures anything.
	var zone_nodes := int(((_in_zone["candidate"] as Array)[0]
			as Dictionary).get("nodes", 0))
	_check(zone_nodes > int((_hub[0] as Dictionary).get("nodes", 0)),
			"the readings are live: the candidate Zone holds %d nodes, the "
			% zone_nodes + "Hub %d" % int((_hub[0] as Dictionary)["nodes"]))
	# NOTHING ACCRUES: every later round reads what the second did.
	_compare("at the Hub", _hub)
	for key: String in ZONES:
		_compare("in " + key, _in_zone[key] as Array)
	# ONE OPERATION, ONE EFFECT, in every round.
	for key: String in ZONES:
		var rows: Array = _effects[key]
		print("")
		print("  -- WHAT THE OPERATIONS DID IN %s, each round" % key.to_upper())
		for i in rows.size():
			print("    round %d: %s" % [i + 1, JSON.stringify(rows[i])])
		for i in rows.size():
			var row: Dictionary = rows[i]
			_check(str(row["verdict"]) == "ACCEPTED",
					"%s, round %d: the layout is accepted (%s)"
					% [key, i + 1, row["verdict"]])
			_check(int(row["died"]) == DEATHS and int(row["respawned"]) == DEATHS
					and int(row["deaths logged"]) == DEATHS,
					"%s, round %d: %d deaths made %d deaths, %d respawns and "
					% [key, i + 1, DEATHS, row["died"], row["respawned"]]
					+ "%d logged" % int(row["deaths logged"]))
			var selected := int((row["by type"] as Dictionary).get(
					"zone_state_selected", 0))
			_check(selected == int(row["pulls"]),
					"%s, round %d: %d lever pull(s) sent %d zone_state_selected"
					% [key, i + 1, row["pulls"], selected])
		for i in range(2, rows.size()):
			var now: Dictionary = rows[i]
			var then: Dictionary = rows[1]
			_check(int(now["sent"]) == int(then["sent"])
					and JSON.stringify(now["by type"]) \
						== JSON.stringify(then["by type"]),
					"%s, round %d sends what round 2 sent: %d %s (round 2: %d %s)"
					% [key, i + 1, now["sent"], JSON.stringify(now["by type"]),
						then["sent"], JSON.stringify(then["by type"])])
	var candidate_rows: Array = _effects["candidate"]
	_check(int((candidate_rows[0] as Dictionary)["pulls"]) > 0,
			"the candidate has a zone-state lever to pull (%d)"
			% int((candidate_rows[0] as Dictionary)["pulls"]))


## Every counter in `rows` from the third reading on equals the second.
func _compare(where: String, rows: Array) -> void:
	if rows.size() < 3:
		_check(false, "%s: %d readings, too few to compare" % [where, rows.size()])
		return
	var second: Dictionary = rows[1]
	var grown: Array[String] = []
	var keys := {}
	for row: Dictionary in rows.slice(1):
		for name: String in row:
			keys[name] = true
	for name: String in keys:
		var values: Array = []
		for row: Dictionary in rows.slice(1):
			values.append(row.get(name, "absent"))
		var slack := int(SLACK.get(name, 0))
		for value: Variant in values:
			var base: Variant = second.get(name, "absent")
			var same := str(value) == str(base)
			if not same and slack > 0 and typeof(value) == TYPE_INT \
					and typeof(base) == TYPE_INT:
				same = absi(int(value) - int(base)) <= slack
			if not same:
				grown.append("%s %s" % [name, values])
				break
	_check(grown.is_empty(),
			"%s, rounds 2-%d: every counter reads what round 2 read (%d counters)%s"
			% [where, rows.size(), keys.size(),
				"" if grown.is_empty() else ": " + "; ".join(grown)])


## Each counter whose readings are not all the same, one line each; the
## rest are counted. A counter that differs only in the fresh round (or
## from the baseline) is shown too: that is where caches fill.
func _table(baseline: Dictionary, rows: Array, _label: String) -> void:
	var names := {}
	for name: String in baseline:
		names[name] = true
	for row: Dictionary in rows:
		for name: String in row:
			names[name] = true
	var ordered: Array = names.keys()
	ordered.sort()
	var constant := 0
	for name: String in ordered:
		var cells: Array[String] = []
		if not baseline.is_empty():
			cells.append("base %s" % str(baseline.get(name, "-")))
		for row: Dictionary in rows:
			cells.append(str(row.get(name, "-")))
		var first := cells[0].trim_prefix("base ")
		var same := true
		for cell: String in cells:
			if cell.trim_prefix("base ") != first:
				same = false
		if same:
			constant += 1
			continue
		print("    %-44s %s" % [name, "  ".join(cells)])
	print("    (%d more counters read the same every time; the nodes: %s)"
			% [constant, "  ".join(PackedStringArray(rows.map(
				func(row: Dictionary) -> String: return str(row.get("nodes", "-")))))])
