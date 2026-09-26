extends "res://tests/minor_claim_driver.gd"
## H-COUNTERFIRE (PT-04, D12's card, V-11) — EX50-021 AS THE OWNER MET IT:
## HOSTED IN THE PLAYED ZONE (`--counterfire-hosted`).
##
##     make godot-counterfire-hosted
##
## PT-04: "shot a target, emergency door opened, took Check". The candidate
## profile hosts EX50-021 in more than one Zone -- the minors' offer order
## turns with the Zone's ordinal (`minor_hosting.offer_order`), so zone_001
## hosts it in c025 and zone_002 in c024 -- which is the owner's "possibly
## two Counterfires". The target is its receiver: the sign above it read
## "EMERGENCY IMPACT TRIP / SERVICE SHUTTER". This suite plays the room as
## the Zone hosts it (`candidate_zone.json`, zone_001/c025), not the
## development scenario `godot-counterfire` builds at the origin.
##
## **WHAT IS PLAYED, with the base kit:**
##   reads      what the room says before anything is done, and what it
##              says while the window runs and after the release: the
##              trip names what it opens, the conduit between the receiver
##              and the shutter visibly carries the window, the shutter
##              says how long it has, and the release stays thrown and says
##              so. D12: "Make gunner, receiver, shutter and reward read as
##              one relationship, without printing the answer on entry."
##   kill_first V-11's fallback and the owner's report: the Zone's gunner
##              killed with the base kit, the receiver shot on its face
##              from the lane side, through the shutter inside its window,
##              up to the flank, and the Check claimed. "A dead gunner must
##              not permanently strand the reward."
##   shots      the hood, as a census: from the arrival side no shot trips
##              the receiver, and from the lane side one does.
##   mobility   V-10 at the schema maxima: no blink, double jump or
##              grapple claims the Check from anywhere but the flank.
##   return     R3 after that arrival: the release pulled on the flank
##              stays thrown, lowers its stair, and the player walks down
##              to the arcade floor and back to the arrival.
## The gunner-driven route (the bait) is played live, through the real
## bridge, by `godot-candidate-live`'s MINOR phase.
##
## **HARNESS STEPS, each declared where it happens:** the census places the
## player at each sampled cell before firing (as `ClaimCensus` places its
## eye), and `_mobility` places them for each blink and flight; the player
## is put back at the room's arrival after each of those; `ap_connected`
## is set so a claim can go out with no bridge; and the player's health is
## raised for the mobility sweep only, as `godot-minor-claim` does.

const HOSTED_SHELL := "minor_counterfire_arcade"


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CANDIDATE))
	var controller := await _enter(zone_data)
	var minor := {}
	for raw: Variant in controller.minors:
		if (raw as Dictionary)["hosted"] is CounterfireArcadeHosted:
			minor = raw
	_check(not minor.is_empty(),
			"the played Zone hosts EX50-021: %s"
			% [controller.minors.map(func(m: Dictionary) -> String:
				return "%s:%s" % [m["room_id"], m["hosted"].name])])
	if minor.is_empty():
		_finish()
		return
	if OS.get_cmdline_user_args().has("--counterfire-only=survey"):
		_survey(controller, minor)
		_finish()
		return
	# `--counterfire-only=quick` skips the mobility sweep, for iterating.
	var quick := OS.get_cmdline_user_args().has("--counterfire-only=quick")
	if quick:
		_note("QUICK: the mobility sweep is skipped -- not the suite")
	# IN THIS ORDER: what the room says before anything is done; the
	# owner's route, which kills the gunner; then, with nobody shooting
	# back, the window's reads and the census; V-10; and the way back.
	_counterfire_reads_as_built(minor)
	_counterfire_no_void_edges(controller, minor)
	await _counterfire_kill_first(controller, minor)
	await _counterfire_drop_back(controller, minor)
	await _counterfire_reads_in_window(controller, minor)
	await _counterfire_shots(controller, minor)
	if not quick:
		await _counterfire_mobility(controller, minor)
	await _counterfire_return(controller, minor)
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_back", "move_left",
			"move_right", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	if failures == 0:
		print("GODOT COUNTERFIRE HOSTED OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT COUNTERFIRE HOSTED TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------------------
# Reading the room
# ---------------------------------------------------------------------------

## DIAGNOSTIC ONLY (`--counterfire-only=survey`): the highest surface under
## each 0.5 m cell of the room's north-east corner, in the room's frame,
## from 3.6 m down to 40 m below. ' ' is no surface at all: a void.
func _survey(controller: ZoneController, minor: Dictionary) -> void:
	var room := _room_of(minor)
	var space := room.get_world_3d().direct_space_state
	print("SURVEY room-frame x across (10.0 .. 17.5), z down (-5.0 .. 10.0)")
	for iz in range(0, 31):
		var z := -5.0 + iz * 0.5
		var line := ""
		for ix in range(0, 16):
			var x := 10.0 + ix * 0.5
			var from := room.to_global(Vector3(x, 3.6, z))
			var query := PhysicsRayQueryParameters3D.create(from,
					from + Vector3.DOWN * 44.0)
			query.exclude = [controller.player.get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				line += "    ."
			else:
				line += "%5.1f" % room.to_local(hit["position"]).y
		print("SURVEY z %4.1f %s" % [z, line])

func _room_of(minor: Dictionary) -> CounterfireArcadeRoom:
	return (minor["hosted"] as CounterfireArcadeHosted).room


## Every Label3D the room carries, as `{text, at}` in the room's frame.
func _signs_of(room: CounterfireArcadeRoom) -> Array:
	var out: Array = []
	for found: Node in room.find_children("*", "Label3D", true, false):
		var label := found as Label3D
		out.append({"text": label.text,
				"at": room.to_local(label.global_position)})
	return out


## How brightly each mesh between the receiver and the shutter glows,
## keyed by node path: the conduit, read as a player sees it.
func _glow_on_the_path(room: CounterfireArcadeRoom) -> Dictionary:
	var out := {}
	# From a metre east of the receiver, so its own plate is not counted.
	var lo := Vector3(1.0, -0.5, CounterfireArcadeRoom.RECEIVER_Z - 0.5)
	var hi := Vector3(CounterfireArcadeRoom.ROOM_HALF.x + 0.5, 1.0,
			CounterfireArcadeRoom.SHUTTER_Z + 0.5)
	for found: Node in room.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		var at := room.to_local(mesh.global_position)
		if at.x < lo.x or at.x > hi.x or at.y < lo.y or at.y > hi.y \
				or at.z < lo.z or at.z > hi.z:
			continue
		var mat := mesh.material_override as StandardMaterial3D
		var glow := 0.0
		if mat != null and mat.emission_enabled:
			glow = mat.emission_energy_multiplier
		out[str(room.get_path_to(mesh))] = glow
	return out


func _glowing(glow: Dictionary) -> int:
	return glow.values().filter(func(g: float) -> bool: return g > 0.5).size()


## The readout at the shutter: a Label3D within 3.5 m of its doorway on
## the arcade side, "" when there is none.
func _shutter_readout(room: CounterfireArcadeRoom) -> String:
	var door := Vector3(CounterfireArcadeRoom.SHUTTER_X, 1.3,
			CounterfireArcadeRoom.SHUTTER_Z)
	for sign: Dictionary in _signs_of(room):
		var at: Vector3 = sign["at"]
		if at.distance_to(door) < 3.5 and at.x <= door.x + 0.3:
			return str(sign["text"])
	return ""


## D12: "Make gunner, receiver, shutter and reward read as one
## relationship, without printing the answer on entry" -- asked of the
## room as built, during the window a real hit opens, and once released.
func _counterfire_reads_as_built(minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: what the room says before anything is done" % rid)
	var texts: Array = _signs_of(room).map(func(s: Dictionary) -> String:
		return str(s["text"]).replace("\n", " / "))
	# THE SIGN AT THE RECEIVER: the nearest one to it, whatever it says.
	var near := Vector3(0.0, 2.0, CounterfireArcadeRoom.RECEIVER_Z)
	var trip: Array = _signs_of(room)
	trip.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["at"] as Vector3).distance_to(near) \
				< (b["at"] as Vector3).distance_to(near))
	var trip_text := str((trip[0] as Dictionary)["text"]) \
			if not trip.is_empty() else ""
	_check("OPENS" in trip_text and "SHUTTER" in trip_text
			and not "EMERGENCY" in trip_text,
			"%s: the trip names what it does, and is not an unrelated " % rid
			+ "emergency control: '%s'" % trip_text.replace("\n", " / "))
	_check(not texts.any(func(t: String) -> bool:
				return "BAIT" in t or "GUNNER" in t or "DODGE" in t),
			"%s: and nothing prints the answer on entry (no bait, gunner or "
			% rid + "dodge instruction): %s" % [texts])


## NO EDGE OF THE ROOM DROPS OUT OF THE WORLD. From the arrival and from
## the flank, every cell the base kit reaches is asked whether a step to
## any side -- unobstructed at shin and chest height -- lands on anything
## at all within 45 m. A fall to the fall-kill plane is not a route, and
## the flank's corner once had one (PPT-05).
func _counterfire_no_void_edges(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: no step from anywhere reached drops out of the world"
			% rid)
	var player := controller.player
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var space := room.get_world_3d().direct_space_state
	var starts := {
		"the arrival": RoomGraphs.place_of(controller.room_places,
				rid).get("arrival", box.get_center()),
		"the flank": room.to_global(Vector3(16.4,
				CounterfireArcadeRoom.FLANK_Y, 0.0)),
	}
	var voids: Array = []
	var cells_seen := 0
	for label: String in starts.keys():
		var reach := ClaimCensus.reach(player, box, starts[label], [])
		var cells: Dictionary = reach["cells"]
		for key: Variant in (reach["reached"] as Dictionary).keys():
			var foot: Vector3 = cells[key]
			cells_seen += 1
			for az in 8:
				var a := TAU * float(az) / 8.0
				var step := Vector3(cos(a), 0.0, sin(a)) * 0.6
				var blocked := false
				for rise: float in [0.35, 1.2]:
					var line := PhysicsRayQueryParameters3D.create(
							foot + Vector3.UP * rise,
							foot + step + Vector3.UP * rise)
					line.exclude = [player.get_rid()]
					if not space.intersect_ray(line).is_empty():
						blocked = true
						break
				if blocked:
					continue
				# A PLAYER-SIZED FOOTPRINT with nothing under any of it:
				# a seam a capsule bridges (a doorway's threshold) is not
				# a hole.
				var supported := false
				for off: Vector3 in [Vector3.ZERO,
						Vector3(Constants.PLAYER_RADIUS, 0.0, 0.0),
						Vector3(-Constants.PLAYER_RADIUS, 0.0, 0.0),
						Vector3(0.0, 0.0, Constants.PLAYER_RADIUS),
						Vector3(0.0, 0.0, -Constants.PLAYER_RADIUS)]:
					var down := PhysicsRayQueryParameters3D.create(
							foot + step + off + Vector3.UP * 0.5,
							foot + step + off + Vector3.DOWN * 45.0)
					down.exclude = [player.get_rid()]
					if not space.intersect_ray(down).is_empty():
						supported = true
						break
				if not supported:
					var at := room.to_local(foot + step).snapped(
							Vector3.ONE * 0.1)
					if not voids.has(at):
						voids.append(at)
	_check(cells_seen > 0 and voids.is_empty(),
			"%s: from %d cell(s) reached, no step lands on nothing (void "
			% [rid, cells_seen] + "edges, the room's frame: %s)"
			% [voids.slice(0, 8)])


## R3 WITHOUT THE RELEASE: from the flank, along to its reach over the
## low wall and off it onto the gunner's gallery, then down the lane to
## where the room was entered. Nothing pulled, the shutter shut behind.
func _counterfire_drop_back(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var player := controller.player
	print("  -- %s: back from the flank with nothing pulled" % rid)
	var z := CounterfireArcadeRoom.ROOM_HALF.y - 2.0
	await _along_the_flank(room, player)
	# THE FLANK IS A WALKWAY, NOT A LEDGE BEHIND THE CHECK (PPT-06): its
	# reach over the low wall is walked to from where the stair arrives.
	var on_reach := room.to_local(player.global_position)
	_check(absf(on_reach.y - CounterfireArcadeRoom.FLANK_Y) < 0.3
			and on_reach.x < 15.6 and on_reach.z > 5.8,
			"%s: along the flank, past the Check, to its reach over the low "
			% rid + "wall (%v)" % on_reach.snapped(Vector3.ONE * 0.1))
	# WEST OFF THE REACH'S END, over the low wall, onto the gallery.
	for waypoint: Vector3 in [Vector3(12.6, CounterfireArcadeRoom.FLANK_Y,
				7.5), Vector3(10.2, CounterfireArcadeRoom.GALLERY_Y, 7.5)]:
		await _walk_to(player, room.to_global(waypoint), AABB(), 900, false,
				0.5)
	await _settle(20)
	var local := room.to_local(player.global_position)
	_check(not room.released and absf(local.y
			- CounterfireArcadeRoom.GALLERY_Y) < 0.4
			and local.x < CounterfireArcadeRoom.ROOM_HALF.x,
			"%s: off the flank's reach onto the gallery, nothing pulled (%v)"
			% [rid, local.snapped(Vector3.ONE * 0.1)])
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", player.global_position)
	for waypoint: Vector3 in [Vector3(0.0, CounterfireArcadeRoom.GALLERY_Y,
				z), Vector3(0.0, 0.0, 4.6), Vector3(2.75, 0.0, -3.0)]:
		await _walk_to(player, room.to_global(waypoint), AABB(), 900, false,
				0.5)
	await _walk_to(player, arrival, AABB(), 900, false, 0.8)
	_check(player.global_position.distance_to(arrival) < 1.5 and _deaths == 0,
			"%s: and back to where the room was entered (%.1f m off)"
			% [rid, player.global_position.distance_to(arrival)])


## North along the flank to its reach over the low wall. The flank is
## 1.7 m wide between its edge and the annex wall, so the walk keeps to
## its middle rather than taking a straight line that crosses the edge.
func _along_the_flank(room: CounterfireArcadeRoom, player: Player) -> void:
	var legs: Array = []
	if room.to_local(player.global_position).z < 0.0:
		legs.append(Vector3(16.0, CounterfireArcadeRoom.FLANK_Y, 0.0))
	if room.to_local(player.global_position).z < 5.4:
		legs.append(Vector3(16.0, CounterfireArcadeRoom.FLANK_Y, 5.4))
	legs.append(Vector3(14.6, CounterfireArcadeRoom.FLANK_Y, 6.3))
	for waypoint: Vector3 in legs:
		await _walk_to(player, room.to_global(waypoint), AABB(), 900, false,
				0.4)


## The window, as a player sees it: a hand shot on the receiver's face
## with the gunner dead, so nothing else trips it.
func _counterfire_reads_in_window(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: what the room says while the window runs" % rid)
	for _i in int((CounterfireArcadeRoom.OPEN_SECONDS + 2.5) / DT):
		if room.shutter.is_shut():
			break
		await get_tree().physics_frame
	var shut_glow := _glow_on_the_path(room)
	var shut_read := _shutter_readout(room)
	# A REAL HIT from up the lane: walked there, turned, and fired.
	var player := controller.player
	await _walk_to(player, room.to_global(Vector3(0.0, 0.0,
			CounterfireArcadeRoom.RECEIVER_Z + 4.5)), AABB(), 900, false,
			0.5)
	await _settle(20)
	var hits := room.receiver.hits
	_look_at(player, room.receiver.element.global_position)
	await _settle(2)
	await _pulse_once()
	await _settle(20)
	_check(room.receiver.hits == hits + 1 and room.window_left() > 0.0,
			"%s: a Static Pulse on the receiver's face opens the window "
			% rid + "(%.1f s)" % room.window_left())
	var open_glow := _glow_on_the_path(room)
	var open_read := _shutter_readout(room)
	_check(_glowing(open_glow) > _glowing(shut_glow),
			"%s: the conduit from the receiver to the shutter LIGHTS while "
			% rid + "the window runs (%d glowing, %d before)"
			% [_glowing(open_glow), _glowing(shut_glow)])
	_check(open_read != shut_read and open_read.contains(" s"),
			"%s: and the shutter says how long it has: '%s' (was '%s')"
			% [rid, open_read.replace("\n", " / "),
				shut_read.replace("\n", " / ")])
	# Let the window run out: the conduit goes dark again.
	for _i in int((CounterfireArcadeRoom.OPEN_SECONDS + 2.5) / DT):
		await get_tree().physics_frame
		if room.shutter.is_shut():
			break
	await _settle(10)
	_check(room.shutter.is_shut() and _glowing(_glow_on_the_path(room))
			== _glowing(shut_glow),
			"%s: when the window closes, the conduit goes dark again" % rid)
	player.global_position = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", player.global_position) + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	await _settle(10)


## One Static Pulse, held across a couple of frames as the input reads it.
func _pulse_once() -> void:
	Input.action_press("fire_pulse", 1.0)
	for _i in 3:
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# V-10 on the flank
# ---------------------------------------------------------------------------

## On the flank: the upper floor behind the annex, and its reach west over
## the low wall. Standing there is arriving (D12 R1).
func _on_flank(room: CounterfireArcadeRoom) -> Callable:
	return func(at: Vector3) -> bool:
		var local := room.to_local(at)
		return local.y > CounterfireArcadeRoom.FLANK_Y - 0.3 \
				and local.x > CounterfireArcadeRoom.ROOM_HALF.x - 0.6


func _counterfire_mobility(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: movement assistance, the room as built (V-10)" % rid)
	var reward := _reward_in(controller, rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", box.get_center())
	var hp := controller.player.hp
	controller.player.hp = 100000.0
	var aims: Array = [reward.global_position + Vector3(0.0, 1.3, 0.0),
			room.to_global(Vector3(16.4, CounterfireArcadeRoom.FLANK_Y + 0.5,
				-2.0)),
			room.to_global(Vector3(13.6, CounterfireArcadeRoom.FLANK_Y + 1.0,
				7.0))]
	var tally := await _mobility(controller, rid, box, arrival, reward,
			_on_flank(room), aims)
	controller.player.hp = hp
	_note("%s mobility: %s" % [rid, tally["summary"]])
	_check((tally["claims_off_goal"] as Array).is_empty(),
			"%s: V-10 -- no blink, double jump or grapple puts the Check in "
			% rid + "claim reach from anywhere but the flank (%s); off-flank "
			% tally["summary"] + "claims: %s" % [tally["claims_off_goal"]])


# ---------------------------------------------------------------------------
# V-11: the gunner dead, the receiver shot by hand, the Check claimed
# ---------------------------------------------------------------------------

func _counterfire_kill_first(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var player := controller.player
	print("  -- %s: kill-first -- the gunner dead, the receiver shot by "
			% rid + "hand, the Check claimed (V-11, PT-04)")
	player.hp = Constants.PLAYER_MAX_HP
	_deaths = 0
	_taken = 0.0
	_last_hp = player.hp
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", player.global_position)
	player.global_position = arrival + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	await _settle(20)
	var hits := room.receiver.hits
	var fight := await _clear_room(controller, rid)
	_check(int(fight["left"]) == 0 and _deaths == 0,
			"%s: the Zone's gunner killed with the base kit: %d of %d down "
			% [rid, int(fight["guns"]) - int(fight["left"]),
				int(fight["guns"])] + "in %.1f s, %.0f hp taken, %d death(s)"
			% [float(fight["frames"]) * DT, _taken, _deaths])
	# UP THE LANE, PAST THE RECEIVER, then round to face it.
	var lane := room.to_global(Vector3(0.0, 0.0,
			CounterfireArcadeRoom.RECEIVER_Z + 4.5))
	await _walk_to(player, lane, AABB(), 900, false, 0.5)
	await _settle(20)
	var before := room.receiver.hits
	_look_at(player, room.receiver.element.global_position)
	await _settle(2)
	await _pulse_once()
	await _settle(15)
	_check(room.receiver.hits == before + 1 and room.window_left() > 0.0,
			"%s: a Static Pulse from the lane side trips the receiver " % rid
			+ "(%d hit(s), %d before the fight) and the shutter opens"
			% [room.receiver.hits - before, hits])
	# THROUGH, INSIDE THE WINDOW.
	var through := await _walk_to(player, room.to_global(Vector3(
			CounterfireArcadeRoom.ROOM_HALF.x + 1.4, 0.0,
			CounterfireArcadeRoom.SHUTTER_Z)), AABB(), 600, false, 1.0)
	_check(room.to_local(player.global_position).x
			> CounterfireArcadeRoom.ROOM_HALF.x,
			"%s: through the shutter inside its window (%.1f s left)"
			% [rid, room.window_left()])
	await _walk_to(player, room.to_global(Vector3(16.2,
			CounterfireArcadeRoom.FLANK_Y, -2.0)), AABB(), 900, false, 1.1)
	await _settle(10)
	_check(_on_flank(room).call(player.global_position),
			"%s: up the supported route onto the flank (%v)"
			% [rid, room.to_local(player.global_position).snapped(
				Vector3.ONE * 0.1)])
	# THE CHECK, claimed on the flank with the gunner dead the whole time:
	# along the flank to it, in its north-east corner.
	for waypoint: Vector3 in [Vector3(16.0, CounterfireArcadeRoom.FLANK_Y,
				0.0), Vector3(16.0, CounterfireArcadeRoom.FLANK_Y, 5.2)]:
		await _walk_to(player, room.to_global(waypoint), AABB(), 900, false,
				0.4)
	var reward := _reward_in(controller, rid)
	var was_connected: Variant = BridgeClient.snapshot.get("ap_connected",
			false)
	BridgeClient.snapshot["ap_connected"] = true
	BridgeClient.sent_intents.clear()
	var seen := await _approach(controller, reward, 1.2)
	await _press("interact")
	await _settle(4)
	var claims := BridgeClient.sent_intents.filter(
			func(i: Dictionary) -> bool:
				return str(i.get("type", "")) == "claim_check" \
						and int(i.get("location_id", -1)) == reward.location_id)
	BridgeClient.snapshot["ap_connected"] = was_connected
	_check(seen and claims.size() == 1,
			"%s: the Check %d claimed on the flank, the gunner dead: the "
			% [rid, reward.location_id] + "reward is not stranded (%d "
			% claims.size() + "claim(s))")
	_check(_deaths == 0, "%s: no death on the way (%.0f hp taken)"
			% [rid, _taken])


# ---------------------------------------------------------------------------
# The hood, as a census
# ---------------------------------------------------------------------------

func _counterfire_shots(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var player := controller.player
	print("  -- %s: which side of the receiver a shot trips it" % rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", box.get_center())
	player.global_position = arrival + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	await _settle(10)
	var reach := ClaimCensus.reach(player, box, arrival,
			_living_in(controller, rid))
	var cells: Dictionary = reach["cells"]
	var keys: Array = (reach["reached"] as Dictionary).keys()
	keys.sort()
	var plate := room.receiver.element.global_position
	var arrival_side := {"shots": 0, "trips": 0, "at": []}
	var lane_side := {"shots": 0, "trips": 0}
	for i in range(0, keys.size(), 3):
		var foot: Vector3 = cells[keys[i]]
		var local := room.to_local(foot)
		if local.x > CounterfireArcadeRoom.ROOM_HALF.x \
				or absf(local.y) > 0.5:
			continue
		var side := arrival_side if local.z \
				< CounterfireArcadeRoom.RECEIVER_Z else lane_side
		if side == lane_side and (local.z
				< CounterfireArcadeRoom.RECEIVER_Z + 2.0
				or absf(local.x) > 6.0):
			continue
		# HARNESS STEP: placed on the cell, as the census places its eye.
		player.global_position = foot + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO
		await _settle(3)
		var before := room.receiver.hits
		_look_at(player, plate)
		await _settle(1)
		await _pulse_once()
		await _settle(14)
		side["shots"] += 1
		if room.receiver.hits > before:
			side["trips"] += 1
			if side == arrival_side:
				(arrival_side["at"] as Array).append(local.snapped(
						Vector3.ONE * 0.1))
	_check(int(arrival_side["shots"]) >= 5
			and int(arrival_side["trips"]) == 0,
			"%s: from the arrival side, %d shot(s) at the receiver trip it "
			% [rid, arrival_side["trips"]] + "%d time(s): the hood is steel "
			% arrival_side["trips"] + "(%d shots; tripped from %s)"
			% [arrival_side["shots"], arrival_side["at"]])
	_check(int(lane_side["shots"]) >= 3
			and int(lane_side["trips"]) > 0,
			"%s: from the lane side, %d of %d shot(s) trip it"
			% [rid, lane_side["trips"], lane_side["shots"]])
	player.global_position = arrival + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	await _settle(10)


# ---------------------------------------------------------------------------
# R3: the release on the flank, and the walk back down
# ---------------------------------------------------------------------------

func _counterfire_return(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var player := controller.player
	print("  -- %s: the release, and the way back it lowers (R3)" % rid)
	if not _on_flank(room).call(player.global_position):
		# UP AGAIN the way the owner went: a shot on the face from the
		# lane, and through inside the window.
		await _walk_to(player, room.to_global(Vector3(0.0, 0.0,
				CounterfireArcadeRoom.RECEIVER_Z + 4.5)), AABB(), 900,
				false, 0.5)
		await _settle(20)
		_look_at(player, room.receiver.element.global_position)
		await _settle(2)
		await _pulse_once()
		await _settle(10)
		await _walk_to(player, room.to_global(Vector3(
				CounterfireArcadeRoom.ROOM_HALF.x + 1.4, 0.0,
				CounterfireArcadeRoom.SHUTTER_Z)), AABB(), 600, false, 1.0)
		await _walk_to(player, room.to_global(Vector3(16.2,
				CounterfireArcadeRoom.FLANK_Y, -2.0)), AABB(), 900, false,
				1.1)
	_check(_on_flank(room).call(player.global_position),
			"%s: on the flank again, through a fresh window" % rid)
	var pulled := await _operate_lever(controller, room.release)
	await _settle(60)
	_check(pulled and room.released and room.release_stair_steps() > 0
			and room.shutter.is_open(),
			"%s: the SERVICE RELEASE pulled on the flank: the shutter held "
			% rid + "open and its stair down (%d steps)"
			% room.release_stair_steps())
	_check(room.release.locked
			and not room.release.interact_prompt().begins_with("[E]"),
			"%s: the release STAYS THROWN and says so: '%s'"
			% [rid, room.release.interact_prompt()])
	# ALONG THE FLANK to its reach over the low wall, and down the stair
	# the release lowered: it lands on the gunner's gallery.
	var z := CounterfireArcadeRoom.ROOM_HALF.y - 2.0
	await _along_the_flank(room, player)
	for waypoint: Vector3 in [Vector3(12.6, CounterfireArcadeRoom.FLANK_Y,
				7.5), Vector3(11.6, CounterfireArcadeRoom.FLANK_Y, 7.5),
			Vector3(8.4, CounterfireArcadeRoom.GALLERY_Y, 7.5)]:
		await _walk_to(player, room.to_global(waypoint), AABB(), 900, false,
				0.5)
	await _settle(20)
	var local := room.to_local(player.global_position)
	_check(absf(local.y - CounterfireArcadeRoom.GALLERY_Y) < 0.4
			and local.x < CounterfireArcadeRoom.ROOM_HALF.x - 2.0,
			"%s: down the release's stair onto the gallery (%v)"
			% [rid, local.snapped(Vector3.ONE * 0.1)])
	# OFF THE GALLERY by the lane, where the parapet is open, and back
	# down the arcade to where the room was entered.
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", player.global_position)
	for waypoint: Vector3 in [Vector3(0.0, CounterfireArcadeRoom.GALLERY_Y,
				z), Vector3(0.0, 0.0, 4.6), Vector3(2.75, 0.0, -3.0)]:
		await _walk_to(player, room.to_global(waypoint), AABB(), 900, false,
				0.5)
	await _walk_to(player, arrival, AABB(), 900, false, 0.8)
	_check(player.global_position.distance_to(arrival) < 1.5,
			"%s: and back to where the room was entered (%.1f m off)"
			% [rid, player.global_position.distance_to(arrival)])


## Walk up to a lever, look at it, press the real `interact`.
func _operate_lever(controller: ZoneController, lever: CallLever) -> bool:
	var before := lever.pulls
	var aim := lever.global_position + Vector3(0.0, CallLever.BASE.y * 0.25,
			0.0)
	await _approach(controller, lever, 1.3, aim)
	await _press("interact")
	await _settle(6)
	return lever.pulls > before
