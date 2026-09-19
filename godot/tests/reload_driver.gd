class_name ReloadDriver
extends Node
## A CAMPAIGN REOPENED IN A NEW PROCESS, through the real Main.
##
## What this exists to catch: `ZoneProgress` has been persisted on every
## `key_collected`, `lock_opened` and `station_reached` since it landed,
## and `Main._to_zone` read none of it -- it read three in-memory
## dictionaries whose own docstring says they do not survive quitting. So
## the save held the progress and the game walked past it, and relaunching
## put a player back in front of a lock they had already opened with a key
## that was no longer there to collect. Nothing could see it, because
## every automated proof of a resume lived inside ONE process, and one
## process is exactly where the in-memory copy is right.
##
## So this is TWO Godot processes against one bridge and one save
## directory. The first plays; the second is launched cold, boots the real
## `Main`, reconnects, loads the campaign off disk and re-enters. The only
## thing carried between them is the save.
##
## Everything goes through the shipping path: `main._on_enter_zone()`
## sends the intent, `Main._on_snapshot` notices `ZONE_ACTIVE` and calls
## `_to_zone`, and `_to_zone` is where the recovery either happens or
## does not.

const PHASE_FLAG := "--reload-phase="
const WALK_FRAMES := 900
const ARRIVED := 1.4

## Untyped on purpose: `Main` names this class to start it, and naming
## `Main` back would be a cycle the parser refuses.
var main: Node
var _failures := 0
var _checks := 0


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _finish(code: int) -> void:
	if code == 0 and _failures == 0:
		print("GODOT RELOAD TESTS OK (%d checks)" % _checks)
	else:
		print("GODOT RELOAD FAILED (%d of %d checks)"
				% [_failures, _checks])
	get_tree().quit(1 if (code != 0 or _failures > 0) else 0)


## WHAT THE BRIDGE ACTUALLY SAID, so a phase failure names a reason.
## The controller records the verdict it acted on and the engine records
## why a layout could not be built; a timeout that prints neither sends
## the next person to the log file.
func _say_why(zone: ZoneController) -> void:
	if zone == null:
		print("    (no controller: the Zone was never built)")
		return
	print("    verdict '%s'; engine said '%s'; the bridge's Zone is in "
			% [zone.layout_verdict, zone.layout_failed]
			+ "state '%s' with %d refusal(s)"
			% [str(BridgeClient.active_zone().get("layout_state", "?")),
				int(BridgeClient.active_zone().get("layout_refusals", 0))])

static func phase_from_cmdline() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PHASE_FLAG):
			return arg.substr(PHASE_FLAG.length())
	return ""


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	if not await _await("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		_finish(1)
		return
	match phase_from_cmdline():
		"record":
			await _record()
		"resume":
			await _resume()
		"named-case":
			await _named_case()
		_:
			_check(false, "no --reload-phase was named")
			_finish(1)


## ONE NAMED PROPOSAL, IN FRONT OF A REAL CLIENT AND A REAL BRIDGE.
##
## `make zone-sample` judges a manifest offline: the engine builds a
## Zone, measures it, writes the manifest, and `layout.validate` reads
## it. That answers "would the bridge accept this geometry" and nothing
## about what a PLAYER meets -- whether the client enters, whether a
## refusal recovers inside its budget or exhausts it, whether the Hub is
## still usable afterwards and the Zone still holds its Checks.
##
## So the bridge is started with `--epsilon=sample`, which serves one
## named proposal re-keyed to this campaign's own identity and
## allocation, and this walks the ordinary path: ask for a Zone, enter
## it, let the client build and certify it and the bridge judge what
## comes back. Nothing here fabricates a certificate or skips a verdict.
##
## **A BOUNDED REFUSAL IS NOT A FAILED RUN, and it is not a success
## either.** Both outcomes are reported in the same words every time --
## the first verdict, how many refusals the Zone has spent, whether it
## ended ACCEPTED and entered or exhausted its budget, and what the Hub
## and the Check count say afterwards -- so a recovery can never be read
## as a first-attempt acceptance.
func _named_case() -> void:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("a campaign",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN"):
		_finish(1)
		return
	if BridgeClient.active_zone().is_empty():
		BridgeClient.send_intent({"type": "request_next_zone"})
	if not await _await("the named proposal",
			func() -> bool:
				return not BridgeClient.active_zone().is_empty(), 60.0):
		_finish(1)
		return
	var zone: Dictionary = BridgeClient.active_zone()
	var zone_id := str(zone.get("zone_id", "?"))
	var allocated := (zone.get("allocated_location_ids", []) as Array).size()
	print("  NAMED CASE: %s, %d Check(s) allocated to it"
			% [zone_id, allocated])
	# WHICH IDENTITY IT LAID OUT UNDER, because that decides the layout.
	#
	# `ZoneBuilder` seeds its placement RNG with
	# `hash("<zone_id>|<theme>|layout")`, and a campaign gives the
	# proposal ITS OWN zone_id -- `zone_001` here, not the `zone_007`
	# the sample was dumped as. So the rooms, the graph and the doors are
	# the sample's and the POSE SEQUENCE IS NOT. A case the offline
	# census calls unroutable can route here, and that is a fact about
	# the seed rather than a repair of the case; a case that routes here
	# is not evidence that the dumped one does. Said out loud because
	# reading it the other way would turn a seed into a fix.
	print("  IDENTITY: laid out as '%s' -- the layout seed follows the "
			% zone_id + "campaign's zone_id, not the sample's, so this "
			+ "is that CONTENT under a different pose sequence")

	main._on_enter_zone()
	# WHAT WAS ACTUALLY SERVED, read from the Zone the CLIENT BUILT.
	# The snapshot carries `zone: null` until the proposal lands, and an
	# earlier version read it there and reported "0 room(s)" for a Zone
	# of twenty-three -- a report about its own timing.
	var built := await _await("the client builds it",
			func() -> bool:
				return main.zone != null and main.zone.player != null,
			60.0)
	# THE FIRST ANSWER, BEFORE ANY RECOVERY. A Zone that is accepted on
	# its first submission and a Zone that is accepted on its third are
	# different results, and only one of them is "this proposal lays
	# out".
	if built:
		var served: Dictionary = main.zone.zone
		print("  SERVED: '%s', %d room(s), %d edge(s)"
				% [str(served.get("display_name", "?")),
					(served.get("chambers", []) as Array).size(),
					(served.get("edges", []) as Array).size()])
	# A GENERATION-STAGE REFUSAL IS NOT A LAYOUT ONE, and reporting only
	# the layout verdict hides it. `generate_zone_validated` refuses a
	# proposal the validator rejects and the campaign composes again --
	# so a Zone can arrive ACCEPTED on its first LAYOUT while a proposal
	# was already refused before it. `layout_refusals` cannot see that;
	# `last_generation_error` is what says it happened.
	# `<null>` IS NOT A REASON. The field is nullable and `str(null)`
	# prints the engine's placeholder, which reads as a refusal nobody
	# made.
	var raw_why: Variant = BridgeClient.snapshot.get("last_generation_error")
	var why := str(raw_why) if raw_why is String else ""
	if why != "":
		print("  GENERATION: a proposal was refused before this one -- %s"
				% why)
	else:
		print("  GENERATION: no proposal was refused; this is the one "
				+ "the provider offered first")
	var first := "not built" if not built else str(main.zone.layout_verdict)
	await _await("a first verdict",
			func() -> bool:
				return main.zone != null \
						and main.zone.layout_verdict != "", 30.0)
	if main.zone != null:
		first = str(main.zone.layout_verdict)
	print("  FIRST RESULT: %s" % (first if first != "" else "no verdict"))

	# THEN THE BOUNDED RECOVERY, WATCHED RATHER THAN ASSUMED. A refusal
	# sends the Zone back to be composed again; the budget stops it.
	var spent := 0
	var ended := ""
	for _i in 60:
		var rec: Dictionary = BridgeClient.active_zone()
		spent = int(rec.get("layout_refusals", 0))
		var state := str(rec.get("layout_state", ""))
		if state == "ACCEPTED":
			ended = "ACCEPTED"
			break
		if bool(rec.get("layout_exhausted", false)) \
				or str(rec.get("state", "")) == "DORMANT":
			ended = "EXHAUSTED"
			break
		await get_tree().create_timer(0.5).timeout
	if ended == "":
		ended = "STILL PENDING after the watch window"
	print("  RECOVERY: %d refusal(s) spent; ended %s" % [spent, ended])

	# AND WHAT THE PLAYER IS LEFT WITH, either way.
	var after: Dictionary = BridgeClient.active_zone()
	var hub := BridgeClient.hub_mode()
	var still := (after.get("allocated_location_ids", []) as Array).size()
	print("  AFTER: hub %s; the Zone holds %d of its %d Check(s); "
			% [hub, still, allocated]
			+ "entered=%s" % str(main.zone != null and main.zone.player != null))
	_check(hub != "", "the Hub still reports a mode")
	_check(still == allocated or ended == "ACCEPTED",
			"a refused Zone keeps every Check it was allocated (%d of %d)"
			% [still, allocated])
	_check(ended != "STILL PENDING after the watch window",
			"the Zone reached a terminal answer rather than leaving the "
			+ "client waiting (%s)" % ended)
	print("NAMED CASE %s: first=%s refusals=%d ended=%s"
			% [zone_id, first, spent, ended])
	_finish(0 if _failures == 0 else 1)


## Anything the driver has to hand the next process that the SAVE does
## not carry: which Zone, which lock, which key. Written beside the save
## rather than into it, because the save is the bridge's and this is the
## test's own bookkeeping.
func _notes_path() -> String:
	return "user://reload_notes.json"


func _write_notes(notes: Dictionary) -> void:
	var f := FileAccess.open(_notes_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(notes))
	f.close()


func _read_notes() -> Dictionary:
	if not FileAccess.file_exists(_notes_path()):
		return {}
	var raw := FileAccess.get_file_as_string(_notes_path())
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _await(what: String, predicate: Callable,
		seconds := 30.0) -> bool:
	var waited := 0.0
	while waited < seconds:
		if predicate.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(false, "timed out waiting for %s" % what)
	return false


## A Zone carrying a lock and its key, through the real intents.
##
## Same shape as `bridge/tests/test_amalgam_end_to_end._branching_zone`:
## a branch needs a Zone big enough to spare a room, so ask until one
## comes, and put the ones that do not back.
func _a_locked_zone() -> Dictionary:
	for _attempt in 4:
		BridgeClient.send_intent({"type": "request_next_zone",
				"finale": false})
		if not await _await("ZONE_READY",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_READY"):
			return {}
		var record := BridgeClient.active_zone()
		var zone: Dictionary = record.get("zone", {})
		for raw_chamber: Variant in zone.get("chambers", []):
			var chamber: Dictionary = raw_chamber
			for raw_door: Variant in chamber.get("doors", []):
				var door: Dictionary = raw_door
				if str(door.get("usage", "")) != "LOCKED":
					continue
				var edge_id := str(door.get("edge_id", ""))
				var branch := ""
				for raw_edge: Variant in zone.get("edges", []):
					var edge: Dictionary = raw_edge
					if str(edge.get("edge_id", "")) != edge_id:
						continue
					branch = str(edge["room_b"]) \
							if str(edge["room_a"]) == str(chamber["id"]) \
							else str(edge["room_a"])
				return {"record": record, "room": str(chamber.get("id", "")),
						"socket": str(door.get("socket_id", "")),
						"key": str(door.get("key_id", "")),
						"branch": branch}
		# Not this one. Put it back rather than playing it.
		var zid := str(record.get("zone_id", ""))
		BridgeClient.send_intent({"type": "enter_zone", "zone_id": zid})
		if not await _await("ZONE_ACTIVE before abandoning",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
			return {}
		BridgeClient.send_intent({"type": "abandon_zone", "zone_id": zid})
		if not await _await("the Zone is put back",
				func() -> bool:
					return BridgeClient.active_zone().is_empty()):
			return {}
	_check(false, "no Zone with a lock in four attempts")
	return {}


func _record() -> void:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("a campaign",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN"):
		_finish(1)
		return
	var found := await _a_locked_zone()
	if found.is_empty():
		_finish(1)
		return
	var record: Dictionary = found["record"]
	var zone_id := str(record.get("zone_id", ""))

	# THE REAL ENTRY PATH. `_on_enter_zone` sends the intent; the
	# snapshot handler builds the Zone. Nothing here constructs a
	# `ZoneController`.
	main._on_enter_zone()
	if not await _await("Main builds the Zone",
			func() -> bool:
				return main.zone != null and main.zone.player != null,
			40.0):
		_finish(1)
		return
	# WHICH PHASE FAILED, NAMED. "timed out waiting for the bridge
	# accepts the layout" is the same sentence whether a FRESH Zone
	# could not be built and accepted or an existing MANIFEST could not
	# be laid back down, and those are different repairs in different
	# lanes. This is the first: a fresh proposal, initial acceptance.
	if not await _await("PHASE 1 (initial build + acceptance): the "
				+ "bridge accepts the freshly composed layout",
			func() -> bool: return main.zone.layout_verdict == "ACCEPTED",
			20.0):
		print("  PHASE 1 FAILED -- a fresh proposal was not accepted. "
				+ "Nothing about manifest reconstruction is measured by "
				+ "this run.")
		_say_why(main.zone as ZoneController)
		_finish(1)
		return
	print("  PHASE 1 OK -- a fresh proposal was built and accepted")
	var zone := main.zone as ZoneController

	# COLLECT THE KEY AND OPEN THE LOCK, on the real objects. The walk
	# itself is proved by the branch-journey test in the room-contract
	# suite; what this run is about is what survives the process, so it
	# drives the same collect and the same open the body would and lets
	# the same intents go.
	var key_id := str(found["key"])
	for node: Node in _find_all(zone, "ZoneKey"):
		var key := node as ZoneKey
		if key == null or key.key_id != key_id:
			continue
		zone.player.global_position = key.global_position + Vector3.UP * 1.2
		for _i in 10:
			await get_tree().physics_frame
	_check(zone.keys_held().has(key_id),
			"the key '%s' was collected in the first process" % key_id)
	# The key alone opens its lock -- `_open_what_the_keys_allow` runs on
	# every collection -- so this asserts rather than arranges.
	var opened := "%s/%s" % [str(found["room"]), str(found["socket"])]
	_check(zone.locks_opened().has(opened),
			"collecting the key opened '%s'" % opened)
	# A STATION TOO, so the resume anchor has something to be.
	var station_id := ""
	for node: Node in _find_all(zone, "WarpStation"):
		var station := node as WarpStation
		if station == null:
			continue
		zone.player.global_position = station.global_position \
				+ Vector3.UP * 1.2
		for _i in 10:
			await get_tree().physics_frame
		if zone.stations_reached().has(station.station_id):
			station_id = station.station_id
			break

	# LEAVE THE WAY THE GAME LEAVES, so the bridge writes the save.
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": zone_id})
	if not await _await("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty()):
		_finish(1)
		return
	_write_notes({"zone_id": zone_id, "key": key_id, "lock": opened,
			"room": str(found["room"]), "socket": str(found["socket"]),
			"branch": str(found["branch"]), "station": station_id})
	print("recorded: zone %s, key %s, lock %s, station %s"
			% [zone_id, key_id, opened, station_id])
	_finish(0)


func _resume() -> void:
	var notes := _read_notes()
	_check(not notes.is_empty(),
			"the first process left its notes behind")
	if notes.is_empty():
		_finish(1)
		return
	var zone_id := str(notes["zone_id"])
	# THE BRIDGE RESTARTED TOO, so the campaign is not in anybody's
	# memory. It used to stay up across the two processes and "the
	# campaign loads from disk" meant the CLIENT loading from a bridge
	# that still had everything. Both sides are new now, and the only
	# thing that crossed is the file in `ARCHIPEPSI_SAVE_DIR` -- so this
	# process does what a freshly launched client does: it connects, and
	# the bridge loads the slot's save rather than creating one.
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("the campaign loads from disk",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN", 30.0):
		_finish(1)
		return
	# AND IT IS THE SAVED ONE, not a fresh campaign under the same name.
	# A `start_mock_campaign` that created rather than loaded would put
	# this process in a brand new campaign that has never heard of the
	# Zone the first one recorded -- which would pass every assertion
	# below about "nothing is remembered" and none of the ones about what
	# came back.
	#
	# Asked of the HUB, not of `active_zone`: a Zone walked out of is
	# dormant, and a dormant Zone is deliberately not the active one.
	# `resume_zone_id` is the bridge naming the Zone the portal leads to,
	# which is the only thing that can name it before the portal is
	# pressed.
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == zone_id,
			"the restarted bridge loaded the save holding %s rather "
			% zone_id + "than creating a new campaign; the Hub offers "
			+ "'%s'" % str(BridgeClient.hub().get("resume_zone_id", "")))

	# THE SAVE IS THE ONLY THING THAT CROSSED. Nothing in this process
	# has ever seen this Zone, so `Main`'s in-memory dictionaries are
	# empty by construction and whatever comes back came from the bridge.
	_check(main._zone_keys.is_empty() and main._zone_locks_open.is_empty()
				and main._zone_resume.is_empty(),
			"this process remembers nothing of its own about any Zone")

	# RE-ENTRY IS THE PORTAL, pressed.
	#
	# This used to set `main._entering_zone` and send the `enter_zone`
	# intent itself, because `_on_enter_zone` read the ACTIVE Zone to
	# find its id and a dormant Zone is not the active one -- the Hub had
	# no affordance for going back to a Zone you walked out of. That gap
	# is closed: the bridge carries `resume_zone_id` and the mode
	# `ZONE_DORMANT`, the Hub's portal branch accepts it, and
	# `_on_enter_zone` reads it. So the driver presses the portal and
	# every step after it -- which id, which intent, which handler --
	# belongs to the shipping path.
	var offered := func() -> bool:
		var standing := main.hub as HubController
		if standing == null or standing.portal() == null:
			return false
		return standing.portal().interact_prompt() != ""
	if not await _await("the Hub offers the way back", offered, 30.0):
		_finish(1)
		return
	var portal: HubController.HubPortal = \
			(main.hub as HubController).portal()
	print("portal: mode %s, prompt '%s'"
			% [BridgeClient.hub_mode(), portal.interact_prompt()])
	_check(BridgeClient.hub_mode() in HubController.ZONE_ENTERABLE_MODES,
			"the Hub is in a mode the portal can enter a Zone from (%s)"
			% BridgeClient.hub_mode())
	var searches_before := ZoneBuilder.searches
	portal.interact(main)
	_check(main._entering_zone,
			"pressing the portal put Main into its entry path")
	if not await _await("ZONE_ACTIVE",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		_finish(1)
		return
	_check(str(BridgeClient.active_zone().get("zone_id", "")) == zone_id,
			"the portal led back into %s, and it led into '%s'"
			% [zone_id, str(BridgeClient.active_zone().get(
				"zone_id", ""))])
	var record := _record_for(zone_id)
	_check(not record.is_empty(),
			"the reloaded campaign still holds %s" % zone_id)
	var progress: Dictionary = record.get("progress", {})
	_check((progress.get("collected_keys", []) as Array)
				.has(str(notes["key"])),
			"the save carries the key '%s'" % str(notes["key"]))
	_check((progress.get("opened_locks", []) as Array)
				.has(str(notes["lock"])),
			"the save carries the opened lock '%s'" % str(notes["lock"]))
	_check(typeof(record.get("manifest")) == TYPE_DICTIONARY
				and not (record["manifest"] as Dictionary).is_empty(),
			"the save carries the committed layout")
	if not await _await("Main rebuilds the Zone",
			func() -> bool:
				return main.zone != null and main.zone.player != null, 40.0):
		_finish(1)
		return
	var zone := main.zone as ZoneController
	_check(ZoneBuilder.searches == searches_before,
			"the Zone was REPLAYED from its manifest: %d route search(es) "
			% (ZoneBuilder.searches - searches_before)
			+ "ran, and a committed layout is rebuilt rather than solved")
	if not await _await("PHASE 2 (reconstruction of an existing "
				+ "manifest): the replayed layout is accepted",
			func() -> bool: return zone.layout_verdict == "ACCEPTED", 20.0):
		print("  PHASE 2 FAILED -- the committed manifest could not be "
				+ "laid back down and accepted. Phase 1 passed, so a "
				+ "fresh proposal is fine and reconstruction is not.")
		_say_why(zone)
		_finish(1)
		return

	# 1. THE PROGRESS CAME BACK, from the bridge and from nowhere else.
	_check(zone.keys_held().has(str(notes["key"])),
			"the player still holds the key they collected last time")
	_check(zone.locks_opened().has(str(notes["lock"])),
			"the lock they opened last time is open")
	if str(notes["station"]) != "":
		_check(zone.stations_reached().has(str(notes["station"])),
				"the station they reached last time is online")

	# 2. AND THE KEY IS NOT THERE TO COLLECT AGAIN. A resume that
	#    respawned it would read as "progress restored" on every counter
	#    above and still hand the player a second copy.
	var loose := 0
	for node: Node in _find_all(zone, "ZoneKey"):
		var key := node as ZoneKey
		if key != null and key.key_id == str(notes["key"]):
			loose += 1
	_check(loose == 0,
			"%d copies of the collected key were rebuilt" % loose)

	# 3. AND THE DOORWAY IS OPEN, with no slab left standing in it.
	#    `LockedDoor.open()` frees the node, so "already opened" is the
	#    absence of one -- and a resume that rebuilt the slab would show
	#    up here and nowhere else.
	var standing := 0
	for node: Node in _find_all(zone, "LockedDoor"):
		var candidate := node as LockedDoor
		if candidate == null:
			continue
		if "%s/%s" % [candidate.room_id, candidate.socket_id] \
				== str(notes["lock"]):
			standing += 1
	_check(standing == 0,
			"%d slab(s) were rebuilt in a doorway the player opened"
			% standing)

	# 4. AND THE PLAYER WALKS THROUGH IT, on foot, with no offers and no
	#    teleport. The two rooms the lock joins are in the manifest; the
	#    walk is from the junction's arrival to the branch room's.
	var from_at: Vector3 = zone._zone_anchors.get(
			"room:%s:arrival" % str(notes["room"]), Vector3.INF)
	var to_at: Vector3 = zone._zone_anchors.get(
			"room:%s:arrival" % str(notes["branch"]), Vector3.INF)
	_check(from_at != Vector3.INF and to_at != Vector3.INF,
			"the manifest carries both rooms' arrivals")
	if from_at == Vector3.INF or to_at == Vector3.INF:
		_finish(1)
		return
	var box: AABB = zone.room_bounds.get(str(notes["branch"]), AABB())
	zone.player.global_position = from_at + Vector3.UP * 0.6
	for _i in 12:
		await get_tree().physics_frame
	# THROUGH THE DOORWAY, not through the wall beside it.
	#
	# This walked a straight line from one arrival to the other, and the
	# two rooms are joined by a door in a wall: the line crosses that
	# wall everywhere except at the opening. PHASE 2 could not run until
	# the socket capacity was corrected, so the leg ran for the first
	# time and the body got to 11.6 m and stopped -- against the wall,
	# which is exactly where a straight line puts it.
	#
	# So the door is a WAYPOINT, the way `graph_driver._walk_into` has
	# always treated it. The claim is unchanged and is still walked on
	# foot: the doorway the key opened is passable.
	var mouth := _doorway_in_world(zone, str(notes["lock"]))
	if mouth != Vector3.INF:
		await _walk(zone.player, mouth)
		# AND THROUGH IT. Steering AT the opening puts a capsule against
		# the frame -- measured, wedged 0.75 m short of the near wall
		# with the doorway as the goal. The second waypoint is a few
		# metres INSIDE, along the line from the opening to the middle
		# of the room it opens onto, so the body is aimed through the
		# gap rather than at it.
		if box.has_volume():
			var inward := (box.position + box.size / 2.0) - mouth
			inward.y = 0.0
			if inward.length() > 0.01:
				await _walk(zone.player,
						mouth + inward.normalized() * 3.5, box)
	var walk := await _walk(zone.player, to_at, box)
	# INSIDE THE ROOM, not within a metre of a point in it.
	#
	# The walk crosses a doorway, a connector and a turn, and a straight
	# line at the far room's arrival is not how anyone walks that -- a
	# body pressed against the last crate before the goal has still gone
	# through the door, which is the claim. So the test asks the
	# question the claim is made of: is the player in the branch room?
	var at: Vector3 = walk["at"]
	_check(box.has_volume() and box.grow(0.5).has_point(at),
			"the player walked from '%s' through the doorway they had "
			% str(notes["room"]) + "already opened and into '%s': they "
			% str(notes["branch"]) + "are at %s and it is %s (%d frames, "
			% [str(at), str(box), int(walk["frames"])]
			+ "%.1f m from its arrival)" % float(walk["closest"]))
	_finish(0)


## Every node of one class under `root`, by class name rather than by a
## group, because a key and a lock declare neither.
func _find_all(root: Node, class_wanted: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.get_script() != null \
			and (root.get_script() as GDScript).get_global_name() \
				== class_wanted:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_find_all(child, class_wanted))
	return out


## One Zone's record out of the snapshot.
##
## Only the ACTIVE Zone is on the wire -- a snapshot carries no list of
## dormant records -- which is why the resume asks for this AFTER the
## `enter_zone` intent rather than before.
func _record_for(zone_id: String) -> Dictionary:
	var active := BridgeClient.active_zone()
	return active if str(active.get("zone_id", "")) == zone_id else {}


## `stop_inside` ENDS THE WALK THE MOMENT IT SUCCEEDS.
##
## A branch room carries a return plug, and a plug sends the player home
## from the dead end they just walked into -- while the finger is still
## on the key. Without this the walk kept going from the Zone start and
## reported a position twelve rooms away as where the walk ended.
## Where a `room/socket` doorway stands, in world space.
##
## Off the room's OWN door plan -- the same `doors` array the aperture
## probe measures -- so the waypoint is the opening the engine built and
## not a second derivation of where one ought to be.
func _doorway_in_world(zone: ZoneController, lock_id: String) -> Vector3:
	var parts := lock_id.split("/")
	if parts.size() != 2:
		return Vector3.INF
	for raw: Variant in zone.offer_rooms:
		var entry: Dictionary = raw
		if str((entry["chamber"] as Dictionary).get("id", "")) != parts[0]:
			continue
		for raw_door: Variant in (entry["build"] as Dictionary) \
				.get("doors", []):
			var door: Dictionary = raw_door
			if str(door.get("socket_id", "")) == parts[1]:
				return (entry["xform"] as Transform3D) \
						* (door.get("position", Vector3.ZERO) as Vector3)
	return Vector3.INF


func _walk(player: Player, goal: Vector3,
		stop_inside := AABB()) -> Dictionary:
	var closest := INF
	var still := 0
	var last := player.global_position
	Input.action_press("move_forward", 1.0)
	var used := 0
	var ended := player.global_position
	for i in WALK_FRAMES:
		used = i + 1
		var here := player.global_position
		ended = here
		if stop_inside.has_volume() and stop_inside.grow(0.5).has_point(here):
			break
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		closest = minf(closest, flat.length())
		if flat.length() <= ARRIVED:
			break
		player.rotation.y = atan2(-flat.x, -flat.y)
		# A BODY PRESSED AGAINST SOMETHING TRIES TO CLIMB IT, which is
		# what `graph_driver._walk` has always done and this walker
		# never learned. PHASE 2 could not run until the socket capacity
		# was corrected, so this leg ran for the first time and ended
		# 11.6 m short after 202 frames -- wedged, not out of budget
		# (`WALK_FRAMES` is 900). The claim under test is that the
		# doorway the key opened is passable; how a harness gets a
		# capsule over a crate on the way is not part of it.
		still = still + 1 if (here - last).length() < 0.012 else 0
		if still == 24 and player.is_on_floor():
			Input.action_press("jump", 1.0)
			await get_tree().physics_frame
			Input.action_release("jump")
			still = 0
		last = here
		if still > 90:
			break
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return {"arrived": Vector2(goal.x - ended.x, goal.z - ended.z).length()
				<= ARRIVED,
			"at": ended, "frames": used, "closest": closest}
