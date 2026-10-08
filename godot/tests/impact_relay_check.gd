class_name ImpactRelayCheck
extends Node
## THE IMPACT RELAY, CHECKED IN THE REAL GAME (G1, D-18 v2 §7.4).
##
##   godot --headless --fixed-fps 60 --path godot -- --impact-relay \
##       --impact-relay-check [--only=route|cases|ledge|escape|measure]
##   ... -- --impact-relay --heavy-hit --impact-relay-check
##
## Beside the real `Main`, through the same startup a tester's launch takes.
## The route phases move the player only by what a tester presses (steer,
## walk, jump, aim, fire, use, swing). The escape sweep and the measurement
## place the player or an object directly, and say so. It proves
## correctness, not fun:
##
## 1. **Isolation and build:** no bridge socket; no enemies; everything at
##    its start; the tether equipped (and nothing else); the shot wired to
##    a sound; the eye line from the gallery to the Check passes only the
##    window's glass.
## 2. **Lever first:** off the gallery, down the stair, the lever: the
##    crate on the plate is thrown and refused, the shutter unharmed. The
##    Pulse is refused too. The Check can't be claimed through the window.
##    The loop's gallery door does not open from the gallery.
## 3. **The weight breaks it:** carried from its stand, set down, thrown;
##    one blow. Through the doorway, the Check claimed on the dais; the
##    onward door; the latch opens the loop (from the vault only); the
##    corridor climbs back to the gallery.
## 4. **The cases D-18 v2 §4 names:** RESTART resets all of it; weight
##    first, then the lever -- with the crate still on the plate (two
##    bodies at once); a player standing in the arc; the menu mid-flight;
##    a `lightened` weight's overshoot: where it settles.
## 5. **The ledge:** no base-kit reach (measured); the tether gets there.
## 6. **No escape:** swings in every direction from every space.
## 7. **Recovery:** out of the hall and the vault, things come home.
## 8. **The measurement:** G0's 40 seeded throws, in this room; crate and
##    weight together, seeded; jittered throws, every rest point reachable.
## 9. **Heavy-hit mode** (`--heavy-hit`): the Braided Lash wears the
##    shutter open, 14 a hit.

const FLAG := "--impact-relay-check"
const STILL_STEP := 0.01
const STUCK_FRAMES := 45
const ARRIVE := 0.6
const TRIALS := 40
const PAIRS := 12
const SCATTER := 30
const WALKABLE := ["Floor", "Stair", "GalleryDeck", "Stand", "Slab", "VaultFloor",
		"Dais", "DaisStep", "AnteFloor", "LoopFloor", "LoopStep", "LoopLanding",
		"ArrivalFloor"]
const PL := ImpactLabParts.ObjectPlate
const SH := ImpactLabParts.ImpactShutter

var failures := 0
var host: ImpactRelay
var room: ImpactRelayRoom
var body: Player


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "ImpactRelayCheck"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var existing := get_tree().root.get_node_or_null("ImpactRelayCheck")
	if existing != null and existing != self:
		queue_free()
		return
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("[relay]   ok    " if ok else "[relay]   FAIL  ") + what)
	if not ok:
		failures += 1


func _note(what: String) -> void:
	print("[relay]   note  " + what)


func _phase(name_in: String) -> void:
	print("[relay] --- %s" % name_in)


func _run() -> void:
	reparent(get_tree().root)
	await _settle(10)
	if not _bind():
		_check(false, "the room was built")
		get_tree().quit(1)
		return
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	if host.heavy:
		await _heavy_hit()
	else:
		if only == "" or only == "route":
			await _isolation_and_build()
			await _lever_first()
			await _the_weight_and_the_route()
		if only == "" or only == "cases":
			await _restart()
			await _the_cases()
		if only == "" or only == "ledge":
			await _restart()
			await _the_ledge()
		if only == "" or only == "escape":
			await _restart()
			await _no_escape()
		if only == "" or only == "measure":
			await _restart()
			await _recovery()
			await _measure()
	print("[relay] %s -- %d failure(s)" % ["PASS" if failures == 0 else "FAILED",
			failures])
	_release_all()
	get_tree().quit(1 if failures > 0 else 0)


func _bind() -> bool:
	var scene := get_tree().current_scene
	host = scene.get_node_or_null("ImpactRelay") as ImpactRelay \
			if scene != null else null
	if host == null:
		return false
	room = host.room
	body = host.player
	return room != null and body != null


func _restart() -> void:
	var before := host.get_instance_id()
	host.restart()
	await _settle(12)
	_check(_bind() and host.get_instance_id() != before,
			"RESTART builds a fresh room")
	_fresh("and everything is back: unpowered, line dark, lever OFF, shutter "
			+ "whole, weight on its stand, crate on the plate, loop latched, "
			+ "the Check unclaimed")


# ============================================================ 1. build

func _isolation_and_build() -> void:
	_phase("isolation and build")
	_check(BridgeClient.isolated and not BridgeClient.online,
			"the bridge client is isolated and offline (no socket opened)")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "no enemies")
	_fresh("everything at its start: unpowered, line dark, lever OFF, shutter "
			+ "whole, weight on its stand, crate on the plate, loop latched")
	_check(room.lever.kit_model != null and _pieces() > 0,
			"the kit lever and the kit raceway (%d lit-able pieces)" % _pieces())
	_check(not (body.runtimes["echo_a"] as EchoRuntime).equipped.is_empty()
			and (body.runtimes["echo_b"] as EchoRuntime).equipped.is_empty(),
			"the swing tether is equipped from the start, and nothing else")
	_check(room.crate.mass_class() == MassClass.LIGHT
			and room.weight.mass_class() == MassClass.MEDIUM,
			"the crate reads LIGHT (%.0f kg), the weight MEDIUM (%.0f kg)"
			% [room.crate.mass, room.weight.mass])
	await _hold(1.0)
	_check(room.duds_announced == 0 and not room.plate.powered,
			"at load, the crate resting on the dark plate says nothing (the "
			+ "plate's own count: %d quiet dud)" % room.plate.duds)
	var pulse: AudioStreamPlayer = host.tones._players.get("pulse")
	await _aim_and_fire(Vector3(0.0, 7.5, 8.0))
	await _settle(1)
	_check(pulse != null and (pulse.playing or pulse.get_playback_position() > 0.0),
			"a shot plays the pulse sound (the bank D's host never built)")
	var eye := Vector3(0.0, 6.1, 7.0)
	var crossed := _line_crosses(eye, room.check.global_position
			+ Vector3(0, 0.6, 0))
	_check(crossed == ["Window"], "the eye line from the gallery (%s) to the "
			% _v(eye) + "Check crosses only the window's glass (%s)"
			% ", ".join(crossed))


func _fresh(what: String) -> void:
	var crate_at := room.crate.global_position - room.plate.global_position
	_check(not room.powered and not room.plate.powered and not room.line_live()
			and _lit() == 0 and not room.lever.locked
			and absf(room.lever.handle_degrees() + 55.0) < 2.0
			and is_instance_valid(room.shutter) and not room.shutter_broken
			and is_equal_approx(room.shutter.hp, SH.HP)
			and room.weight.global_position.distance_to(room.WEIGHT_HOME) < 0.3
			and absf(crate_at.x) < 0.8 and absf(crate_at.z) < 0.8
			and not room.loop_open and not room.vault_door.is_open
			and not room.gallery_door.is_open and not room.check.claimed, what)


## Every collider along a line, by its block's name.
func _line_crosses(from: Vector3, to: Vector3) -> Array:
	var names := []
	var space := body.get_world_3d().direct_space_state
	var exclude: Array[RID] = [body.get_rid()]
	for _i in 8:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var node := hit["collider"] as CollisionObject3D
		if node == room.check or room.check.is_ancestor_of(node):
			break
		names.append(_block_name(node))
		exclude.append(node.get_rid())
	return names


## A room block is a mesh with its body under it (`ChamberBuilders._box`):
## the mesh carries the name.
func _block_name(node: Node) -> String:
	if node == null:
		return "?"
	if node is StaticBody3D and node.get_parent() is MeshInstance3D:
		return String(node.get_parent().name)
	return String(node.name)


# ===================================================== 2. lever first

func _lever_first() -> void:
	_phase("lever first: the crate")
	_check(await _walk(Vector3(0.0, 0, 8.0), 0.5), "onto the gallery")
	_check(await _walk(Vector3(9.2, 0, 8.0), 0.3), "to the loop's gallery door")
	await _use(room.gallery_door.global_position)
	await _hold(0.5)
	_check(not room.gallery_door.is_open and body.global_position.x < room.HALL.end.x,
			"it does not open from the gallery (\"OPENS FROM THE OTHER SIDE\")")
	_check(await _down_the_stair(), "down the stair to the hall floor (at %s)"
			% _v(body.global_position))
	_check(await _walk(room.LEVER_AT + Vector3(0, 0, 1.4), 0.4), "to the lever")
	await _use(room.lever.global_position + Vector3(0, 0.05, 0))
	await _hold(0.3)
	_check(room.powered and room.line_live() and _lit() == _pieces()
			and room.lever.locked and CrossingDParts.is_lit(room.lever._kit_pilot),
			"the lever powers the plate: its line lit end to end, its pilot up")
	var thrown := await _until(func() -> bool: return room.plate.launches > 0, 2.0)
	_check(thrown >= PL.SETTLE_SECONDS - 0.35,
			"the crate already on it arms and is thrown (%.2f s after the pull)"
			% (thrown + 0.3))
	await _until(func() -> bool: return not room.last_impact.is_empty(), 2.0)
	await _hold(1.0)
	_check(room.shutter.refused >= 1 and is_equal_approx(room.shutter.hp, SH.HP)
			and not room.shutter_broken,
			"the crate is refused, the shutter unharmed (%s: a %.1f HP blow, "
			% [_impact_text(), float(room.last_impact.get("joules", 0.0))
				/ SH.JOULES_PER_HP] + "under the %.0f a blow needs)" % SH.MIN_HIT)
	_check(await _walk(Vector3(-0.5, 0, -8.5), 0.5), "up to the shutter")
	var refused := room.shutter.refused
	for _i in 3:
		await _aim_and_fire(room.shutter.global_position)
		await _hold(0.4)
	_check(room.shutter.refused >= refused + 3
			and is_equal_approx(room.shutter.hp, SH.HP),
			"three pulses on the shutter are refused and cost it nothing")
	_check(_reachable(room.crate.global_position),
			"the crate lies where the player can reach it (%s)"
			% _v(room.crate.global_position))
	# THROUGH THE WINDOW: seen, not claimed.
	_check(await _walk(Vector3(5.0, 0, -10.6), 0.4), "to the window")
	_aim(room.check.global_position + Vector3(0, 0.6, 0))
	await _settle(4)
	var target: Variant = body._interact_target
	await _use(room.check.global_position + Vector3(0, 0.6, 0))
	_check(not room.check.claimed and target == null,
			"the Check can't be claimed through the window (E reaches nothing)")
	var hit := body.camera_ray(Constants.STATIC_PULSE_RANGE)
	_check(not hit.is_empty() and _block_name(hit["collider"]) == "Window",
			"and a shot at it stops on the glass")


# ================================== 3. the weight, then the route

func _the_weight_and_the_route() -> void:
	_phase("the weight breaks it; the route")
	_check(await _carry(room.weight), "the weight from its stand (36 kg)")
	_check(body.carry.speed_factor() < 1.0,
			"it slows the carrier (x%.2f)" % body.carry.speed_factor())
	var before := room.plate.launches
	await _set_down_on_plate()
	var thrown := await _until(func() -> bool:
		return room.plate.launches > before, 3.0)
	_check(thrown >= PL.SETTLE_SECONDS - 0.05,
			"set down, it arms and is thrown (%.2f s after it was let go)" % thrown)
	await _until(func() -> bool: return room.shutter_broken, 3.0)
	_check(room.shutter_broken and room.blows == 1,
			"its one blow breaks the shutter (%s)" % _impact_text())
	await _hold(2.5)
	_check(_reachable(room.weight.global_position),
			"the weight comes to rest where the player can reach it (%s)"
			% _v(room.weight.global_position))
	_check(await _walk(Vector3(0.0, 0, -11.0), 0.5)
			and await _walk(Vector3(2.5, 0, -15.0), 0.4),
			"through the broken doorway into the vault")
	_check(await _walk(Vector3(3.95, 0, -16.0), 0.25)
			and absf(body.global_position.y - room.DAIS_TOP) < 0.15,
			"up the step onto the dais (at %s)" % _v(body.global_position))
	await _use(room.check.global_position + Vector3(0, 0.6, 0))
	_check(host.found.has("relay_vault") and room.check.claimed,
			"the Check claimed on the dais (a stand-in: nothing sent)")
	_check(await _walk(Vector3(-4.0, 0, -16.5), 0.4)
			and await _walk(Vector3(-4.0, 0, -20.0), 0.4),
			"through the onward door")
	_check(await _walk(Vector3(-4.0, 0, -16.5), 0.4)
			and await _walk(room.LATCH_AT + Vector3(-1.3, 0, 0), 0.4),
			"back into the vault, to the latch")
	await _use(room.latch.global_position + Vector3(0, 0.05, 0))
	await _hold(1.6)
	_check(room.loop_open and room.vault_door.is_open and room.gallery_door.is_open,
			"lifting the latch, from the vault, opens the loop at both ends")
	_check(await _walk(Vector3(7.4, 0, -15.0), 0.4)
			and await _walk(Vector3(12.0, 0, -15.0), 0.5)
			and await _walk(Vector3(12.0, 0, 8.0), 0.5)
			and await _walk(Vector3(8.0, 0, 8.0), 0.5),
			"the corridor climbs back to the gallery (at %s)"
			% _v(body.global_position))
	_check(body.global_position.y > room.GALLERY_Y - 0.2, "on the gallery again")


# ============================================ 4. the cases D-18 names

func _the_cases() -> void:
	_phase("weight first, with the crate still on the plate (two bodies)")
	_check(await _walk(Vector3(0.0, 0, 8.0), 0.5) and await _down_the_stair(),
			"down to the floor")
	_check(await _carry(room.weight), "the weight from its stand")
	await _set_down_on_plate()
	await _hold(1.6)
	var crate_at := room.crate.global_position - room.plate.global_position
	_check(room.plate.launches == 0 and room.duds_announced == 1
			and _on_plate(room.weight),
			"on the unpowered plate beside the crate: a dud (heard), and both stay "
			+ "(weight at %s, crate at %s from its centre)"
			% [_v(room.weight.global_position - room.plate.global_position),
				_v(crate_at)])
	var order := []
	var record := func(b: ManipulableBody, _v: Vector3) -> void:
		order.append(String(b.name))
	room.plate.fired.connect(record)
	_check(await _walk(room.LEVER_AT + Vector3(0, 0, 1.4), 0.4), "to the lever")
	await _use(room.lever.global_position + Vector3(0, 0.05, 0))
	await _until(func() -> bool: return room.plate.launches >= 2, 4.0)
	await _until(func() -> bool: return room.shutter_broken, 3.0)
	await _hold(2.5)
	_note("thrown in order: %s" % ", ".join(order))
	_check(room.plate.launches == 2 and room.shutter_broken,
			"the lever: both are thrown, one at a time, and the weight's blow "
			+ "breaks the shutter (%s)" % _impact_text())
	_check(float(room.last_impact.get("joules", 0.0)) >= 1000.0,
			"the weight still reaches it at >= 1,000 J (%.0f J)"
			% float(room.last_impact.get("joules", 0.0)))
	_check(_reachable(room.weight.global_position) and _reachable(
			room.crate.global_position), "both end where the player can reach "
			+ "them (weight %s, crate %s)" % [_v(room.weight.global_position),
				_v(room.crate.global_position)])
	room.plate.fired.disconnect(record)

	_phase("a player standing in the arc")
	await _restart()
	_check(await _walk(Vector3(0.0, 0, 8.0), 0.5) and await _down_the_stair()
			and await _walk(room.LEVER_AT + Vector3(0, 0, 1.4), 0.4), "to the lever")
	await _use(room.lever.global_position + Vector3(0, 0.05, 0))
	await _until(func() -> bool: return room.plate.launches > 0, 2.0)
	await _hold(1.5)
	_check(await _carry(room.weight), "the weight")
	await _set_down_on_plate()
	# Just past the plate's leading edge, where the arc is still at chest
	# height; from about 2.5 m out it passes over a standing player's head.
	var lane := room.PLATE_AT + Vector3(0, 0, -1.6)
	await _walk(lane, 0.3)
	_aim(room.PLATE_AT + Vector3(0, 0.6, 0))
	var hp := body.hp
	var launches := room.plate.launches
	var thrown := await _until(func() -> bool:
		return room.plate.launches > launches, 3.0)
	var closest := INF
	for _i in 180:
		await get_tree().physics_frame
		closest = minf(closest, (room.weight.global_position - body.global_position
				- Vector3(0, 0.9, 0)).length())
	_check(thrown >= 0.0 and closest < 0.75 and not room.shutter_broken
			and body.hp == hp,
			"standing in the arc, the weight hits the player (%.2f m centre to "
			% closest + "centre), falls short, and does no damage (HP %s -> %s)"
			% [hp, body.hp])
	_check(_reachable(room.weight.global_position),
			"and lands where the player can reach it (%s)"
			% _v(room.weight.global_position))

	_phase("the menu mid-flight")
	_check(await _carry(room.weight), "the weight again")
	await _set_down_on_plate()
	await _walk(room.PLATE_AT + Vector3(2.6, 0, 1.6), 0.3)
	launches = room.plate.launches
	await _until(func() -> bool: return room.plate.launches > launches, 3.0)
	await _settle(25)
	await _press("pause")
	await _settle(2)
	var held_at := room.weight.global_position
	await _settle(40)
	var paused_ok := host.menu_open() and get_tree().paused
	var moved := room.weight.global_position.distance_to(held_at)
	await _press("pause")
	await _until(func() -> bool: return room.shutter_broken, 3.0)
	_check(paused_ok and moved < 0.001 and held_at.y > 0.8 and room.shutter_broken,
			"the menu holds it in the air (at %s, moved %.3f m); closed, it "
			% [_v(held_at), moved] + "flies on and breaks the shutter")

	_phase("a lightened weight: where it settles")
	for trial in 3:
		var outcome := await _trial(room.weight, Vector3(0.2 * (trial - 1), 0,
				0.15 * trial), 0.6 * trial, "lightened")
		_note("lightened %d: thrown %d, broke %s, rests at %s" % [trial,
				outcome["fired"], outcome["broken"], _v(outcome["rest"])])
		_check(outcome["reachable"] and not outcome["broken"],
				"a lightened weight overshoots, misses, and settles where the "
				+ "player can reach it (%s)" % _v(outcome["rest"]))


# ============================================================ 5. ledge

func _the_ledge() -> void:
	_phase("the ledge (and the reach around it)")
	# THE BASE KIT, measured. From below: every object in the room stacked,
	# plus a jump. From the stair: the nearest tread high enough to jump to
	# the ledge, against a running jump's reach.
	var g := Constants.GRAVITY * body.gravity_mult
	var jump := Constants.JUMP_VELOCITY * Constants.JUMP_VELOCITY / (2.0 * g)
	var stack := room.WEIGHT_SIZE.y + room.CRATE_SIZE.y
	_check(stack + jump < room.LEDGE_TOP,
			"no base-kit reach from below: the weight and the crate stacked "
			+ "(%.2f m) + a jump (%.2f m) is %.2f m, under the ledge's %.1f m"
			% [stack, jump, stack + jump, room.LEDGE_TOP])
	var reach := Constants.WALK_SPEED * 2.0 * Constants.JUMP_VELOCITY / g
	var tread_z := room.GALLERY_Z - (room.GALLERY_Z - room.STAIR_FOOT_Z) \
			* (room.GALLERY_Y - (room.LEDGE_TOP - jump)) / room.GALLERY_Y
	var stair_gap := tread_z - room.LEDGE.end.y
	_check(stair_gap > reach + 1.0,
			"none from the stair or the gallery: the nearest tread high enough "
			+ "is %.1f m from its edge (a running jump covers under %.1f m)"
			% [stair_gap, reach])
	_check(await _walk(Vector3(0.0, 0, 8.0), 0.5) and await _down_the_stair()
			and await _walk(Vector3(-5.5, 0, -9.0), 0.4), "below the ledge")
	var anchor := Vector3(-7.4, room.HALL_HEIGHT, -9.0)
	var reached := false
	for attempt in 3:
		_aim(anchor)
		await _settle(2)
		await _swing_and_let_go(anchor, room.LEDGE_TOP + 1.0,
				Vector3(-9.3, room.LEDGE_TOP, -8.7))
		if _on_ledge():
			reached = true
			break
		await _walk(Vector3(-5.0 + attempt * 0.5, 0, -9.0), 0.4)
	_check(reached, "the swing tether reaches the ledge (at %s)"
			% _v(body.global_position))
	if reached:
		await _use(room.ledge_reward.global_position + Vector3(0, 0.6, 0))
		_check(host.found.has("relay_ledge"), "its local stand-in found")
		var hp := body.hp
		await _walk_off(Vector3(-5.0, 0, -9.0))
		_check(body.global_position.y < 0.5 and body.hp == hp,
				"off the ledge to the floor, unhurt")


func _on_ledge() -> bool:
	var at := body.global_position
	return room.LEDGE.grow(0.2).has_point(Vector2(at.x, at.z)) \
			and at.y > room.LEDGE_TOP - 0.3 and at.y < room.LEDGE_TOP + 1.3


## Jump, tether to `anchor`; let go once above `height`, and steer onto
## `onto` until a floor.
func _swing_and_let_go(anchor: Vector3, height: float, onto: Vector3) -> bool:
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _settle(7)
	_aim(anchor)
	Input.action_press("fire_echo")
	var swung := false
	var let_go := false
	var top := body.global_position
	for _i in 360:
		await get_tree().physics_frame
		if body.global_position.y > top.y:
			top = body.global_position
		if body._swing_time > 0.0:
			swung = true
		if not let_go and body.global_position.y > height:
			let_go = true
			Input.action_release("fire_echo")
		var goal := onto if let_go else anchor
		var flat := Vector2(goal.x - body.global_position.x,
				goal.z - body.global_position.z)
		if flat.length() > 0.3:
			body.rotation.y = atan2(-flat.x, -flat.y)
			Input.action_press("move_forward", 1.0)
		else:
			Input.action_release("move_forward")
		if body.is_on_floor() and _i > 10:
			break
	Input.action_release("fire_echo")
	Input.action_release("move_forward")
	await _land()
	_note("swing at %s: caught %s, let go %s, highest %s, ended %s" % [
			_v(anchor), swung, let_go, _v(top), _v(body.global_position)])
	return swung


func _land() -> void:
	for _i in 600:
		if body.is_on_floor():
			break
		await get_tree().physics_frame
	await _settle(3)


func _walk_off(goal: Vector3) -> void:
	Input.action_press("move_forward", 1.0)
	for _i in 300:
		var flat := Vector2(goal.x - body.global_position.x,
				goal.z - body.global_position.z)
		if flat.length() < 0.5:
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _land()


## From the gallery, west along it to the stair's head and down to the
## floor.
func _down_the_stair() -> bool:
	return await _walk(Vector3(-9.0, 0, 8.0), 0.5) \
			and await _walk(Vector3(-9.0, 0, -3.0), 0.5) \
			and body.global_position.y < 0.3


# ============================================================ 6. no escape

## THE SWING, EVERYWHERE: from a spot in each of the room's spaces, a jump
## and a swing at each of 16 headings and 3 elevations, holding forward the
## whole tether. Each start is placed directly (not walked to); each
## swing is a real tether on the real solver. Every one must end inside.
## The loop is opened first, so the corridor is part of the room.
func _no_escape() -> void:
	_phase("no escape (the swing everywhere)")
	room._on_latch(room.latch)
	await _hold(1.5)
	var starts := [Vector3(0, 0.1, 0), Vector3(-7, 0.1, -8), Vector3(0, 4.6, 8),
			Vector3(-9, 2.5, 1.5), Vector3(0, 0.1, -15), Vector3(5, 1.1, -15),
			Vector3(12, 0.1, -10), Vector3(12, 4.6, 8), Vector3(-9.4, 5.1, -9.4),
			Vector3(0, 4.6, 13)]
	var swings := 0
	var caught := 0
	var outside := []
	var highest := -INF
	for start: Vector3 in starts:
		for heading in 16:
			for pitch in [0.35, 0.8, 1.25]:
				body.cancel_transient_effects()
				body.velocity = Vector3.ZERO
				body.global_position = start
				await _settle(3)
				var yaw := TAU * heading / 16.0
				var far := start + Vector3(-sin(yaw) * cos(pitch), sin(pitch),
						-cos(yaw) * cos(pitch)) * 20.0
				var took := await _swing_free(far)
				swings += 1
				caught += 1 if took else 0
				var at := body.global_position
				highest = maxf(highest, at.y)
				if not room.inside(at):
					outside.append(_v(at))
	_check(outside.is_empty(), "%d swings (%d caught) from 10 spots all end "
			% [swings, caught] + "inside the room (outside: %s; highest %.1f m)"
			% [", ".join(outside) if not outside.is_empty() else "none", highest])
	_check(caught > swings / 2, "and the tether did catch on most of them")


func _swing_free(at: Vector3) -> bool:
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _settle(6)
	_aim(at)
	Input.action_press("fire_echo")
	Input.action_press("move_forward", 1.0)
	var swung := false
	for _i in 260:
		await get_tree().physics_frame
		if body._swing_time > 0.0:
			swung = true
		if (body.is_on_floor() and _i > 12) or not room.inside(body.global_position):
			break
	Input.action_release("fire_echo")
	Input.action_release("move_forward")
	for _i in 240:
		if body.is_on_floor() or not room.inside(body.global_position):
			break
		await get_tree().physics_frame
	return swung


# ============================================================ 7. recovery

func _recovery() -> void:
	_phase("recovery")
	var before := room.respawns
	room.weight.global_position = Vector3(0, -6.0, 0)
	await _settle(4)
	_check(room.respawns == before + 1
			and room.weight.global_position.distance_to(room.WEIGHT_HOME) < 0.3,
			"a weight under the floor comes home to its stand")
	room.weight.global_position = Vector3(12.0, 0.4, -10.0)
	await _settle(4)
	_check(room.respawns == before + 2
			and room.weight.global_position.distance_to(room.WEIGHT_HOME) < 0.3,
			"a weight left in the loop corridor (outside the hall and vault) "
			+ "comes home")
	room.weight.global_position = Vector3(2.0, 0.4, -16.0)
	await _settle(4)
	_check(room.respawns == before + 2, "a weight in the vault stays there")
	room.weight.global_position = room.WEIGHT_HOME
	room.crate.global_position = Vector3(40.0, 3.0, 0)
	await _settle(4)
	_check(room.respawns == before + 3 and _on_plate(room.crate),
			"the crate out of the room comes home to the plate")


# ======================================================= 8. measurement

func _measure() -> void:
	_phase("the measurement (%d throws; %d crate-and-weight pairs; %d jittered)"
			% [TRIALS, PAIRS, SCATTER])
	var rng := RandomNumberGenerator.new()
	rng.seed = 6083
	var hits := 0
	var doubles := 0
	var strays := 0
	var speeds: Array[float] = []
	var joules: Array[float] = []
	var lateral: Array[float] = []
	var height: Array[float] = []
	var centre := Vector3(0, room.DOOR_TOP * 0.5, 0)
	room.crate.global_position = Vector3(-4.0, 0.4, 4.0)
	for i in TRIALS:
		var offset := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var outcome := await _trial(room.weight, offset, rng.randf() * TAU)
		if outcome["fired"] != 1:
			doubles += 1 if int(outcome["fired"]) > 1 else 0
		var impact: Dictionary = outcome["impact"]
		if outcome["broken"] and not impact.is_empty():
			hits += 1
			speeds.append(float(impact["into"]))
			joules.append(float(impact["joules"]))
			var at: Vector3 = impact["at"]
			lateral.append(at.x - centre.x)
			height.append(at.y - centre.y)
		if not outcome["reachable"]:
			strays += 1
			_note("trial %d: the weight came to rest at %s" % [i, _v(outcome["rest"])])
	_check(hits == TRIALS, "%d of %d throws break the shutter" % [hits, TRIALS])
	_check(doubles == 0, "one throw per set-down (%d fired twice)" % doubles)
	_check(strays == 0, "every weight comes to rest where the player can reach "
			+ "it (%d did not)" % strays)
	_note("speed into the face %s m/s; energy %s J (it breaks at %.0f J)"
			% [_spread(speeds), _spread(joules), SH.HP * SH.JOULES_PER_HP])
	_note("where it struck, from the shutter's centre: across %s m, up %s m"
			% [_spread(lateral), _spread(height)])
	# THE CRATE ON ITS OWN, and THE TWO TOGETHER, seeded across the plate.
	var crate_alone := await _trial(room.crate, Vector3.ZERO, 0.0)
	_check(not crate_alone["broken"] and int(crate_alone["fired"]) == 1
			and crate_alone["reachable"],
			"the crate alone, thrown: refused (%s), and not lost"
			% _impact_of(crate_alone["impact"]))
	var pair_breaks := 0
	var pair_lost := 0
	var pair_joules: Array[float] = []
	for i in PAIRS:
		var weight_at := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var crate_at := Vector3(-signf(weight_at.x) * rng.randf_range(0.3, 0.6), 0,
				rng.randf_range(-0.6, 0.6))
		var outcome := await _pair(weight_at, crate_at)
		pair_breaks += 1 if outcome["broken"] else 0
		if float(outcome["weight_joules"]) > 0.0:
			pair_joules.append(float(outcome["weight_joules"]))
		if not (outcome["weight_reachable"] and outcome["crate_reachable"]):
			pair_lost += 1
			_note("pair %d: weight %s, crate %s" % [i, _v(outcome["weight_rest"]),
					_v(outcome["crate_rest"])])
	_check(pair_lost == 0, "crate and weight on the plate together, %d seeded "
			% PAIRS + "set-downs: %d broke it (weight's blow %s J); every body "
			% [pair_breaks, _spread(pair_joules)] + "ends reachable (%d did not)"
			% pair_lost)
	# THE SCATTER: the weight's throw off its solved speed by up to 10 %.
	var scatter_strays := 0
	var scatter_breaks := 0
	for i in SCATTER:
		var jitter := rng.randf_range(0.9, 1.1)
		var offset := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		var outcome := await _trial(room.weight, offset, rng.randf() * TAU, "", jitter)
		scatter_breaks += 1 if outcome["broken"] else 0
		if not outcome["reachable"]:
			scatter_strays += 1
			_note("scatter %d (x%.2f): rest at %s" % [i, jitter, _v(outcome["rest"])])
	_check(scatter_strays == 0, "%d jittered throws (+-10 %% speed): every rest "
			% SCATTER + "point reachable (%d not); %d broke the shutter"
			% [scatter_strays, scatter_breaks])


## One throw of `thing` set down at `offset` from the plate's centre.
func _trial(thing: ManipulableBody, offset: Vector3, yaw: float, status := "",
		jitter := 1.0) -> Dictionary:
	if not room.powered:
		room._on_lever(room.lever)
	room.reset_trial(thing, offset, yaw)
	host._bind_shutter()
	if status != "":
		thing.apply_status(status, 30.0, 1.0)
	var on_fire := func(b: ManipulableBody, solved: Vector3) -> void:
		if b == thing and jitter != 1.0:
			b.linear_velocity = solved * b.impulse_scale() * jitter
	room.plate.fired.connect(on_fire)
	await _settle(2)
	var start := room.plate.launches
	await _until(func() -> bool:
		return room.shutter_broken or room.plate.launches > start, 3.0)
	await _until(func() -> bool: return room.shutter_broken, 2.5)
	await _hold(2.5)
	room.plate.fired.disconnect(on_fire)
	var rest := thing.global_position
	var out := {"fired": room.plate.launches - start, "broken": room.shutter_broken,
			"impact": room.last_impact.duplicate(), "rest": rest,
			"reachable": _reachable(rest)}
	if status != "" and thing.statuses != null:
		thing.statuses = null
	return out


## The crate and the weight set down on the plate together, then thrown.
func _pair(weight_at: Vector3, crate_at: Vector3) -> Dictionary:
	room.reset_trial(room.crate, crate_at, 0.0)
	room.reset_trial(room.weight, weight_at, 0.0)
	host._bind_shutter()
	var weight_joules := [0.0]
	var watch := func(_amount: float, _accepted: bool, source: Node3D) -> void:
		if source == room.weight:
			weight_joules[0] = float(room.shutter.last_impact.get("joules", 0.0))
	room.shutter.struck.connect(watch)
	var start := room.plate.launches
	await _until(func() -> bool: return room.plate.launches >= start + 2, 4.0)
	await _until(func() -> bool: return room.shutter_broken, 2.5)
	await _hold(2.5)
	return {"broken": room.shutter_broken, "weight_joules": weight_joules[0],
			"weight_rest": room.weight.global_position,
			"crate_rest": room.crate.global_position,
			"weight_reachable": _reachable(room.weight.global_position),
			"crate_reachable": _reachable(room.crate.global_position)}


# ======================================================= 9. heavy hit

func _heavy_hit() -> void:
	_phase("heavy-hit mode: the Braided Lash")
	var lash := body.runtimes["echo_b"] as EchoRuntime
	_check(not lash.equipped.is_empty() and float(lash.equipped["primitive"]
			["damage"]) >= SH.MIN_HIT, "the Braided Lash is on the second slot "
			+ "(%s per hit)" % lash.equipped.get("primitive", {}).get("damage"))
	_check(await _walk(Vector3(0.0, 0, 8.0), 0.5) and await _down_the_stair()
			and await _walk(Vector3(0.0, 0, -7.0), 0.5), "to the shutter")
	var hp := [room.shutter.hp]
	for i in 6:
		if room.shutter_broken:
			break
		_aim(room.shutter.global_position)
		await _settle(4)
		Input.action_press("fire_echo_b")
		await _settle(2)
		Input.action_release("fire_echo_b")
		await _hold(1.4)
		if is_instance_valid(room.shutter):
			hp.append(room.shutter.hp)
	_note("the shutter's HP after each lash: %s" % str(hp))
	_check(room.shutter_broken and room.blows >= 3,
			"each lash is accepted and wears it; the blows add up and it breaks "
			+ "(%d accepted blows)" % room.blows)
	_check(not room.powered, "with the plate never powered: the skip the rated "
			+ "rule allows")


# ============================================================ helpers

func _carry(thing: ManipulableBody) -> bool:
	if not await _walk(thing.global_position, 1.3):
		return false
	var said := [""]
	var listen := func(text: String, _ok: bool) -> void: said[0] = text
	body.carry_feedback.connect(listen)
	await _use(thing.global_position)
	await _settle(4)
	body.carry_feedback.disconnect(listen)
	var ok := body.carry.holding() and body.carry.body == thing
	if not ok:
		_note("no pick-up: it said \"%s\", standing at %s, it at %s"
				% [said[0], _v(body.global_position), _v(thing.global_position)])
	return ok


## Stand at the plate's south edge, look at its middle, and put the object
## down.
func _set_down_on_plate() -> void:
	await _walk(room.PLATE_AT + Vector3(0, 0, 1.6), 0.3)
	_aim(room.PLATE_AT + Vector3(0, 0.6, 0))
	await _settle(30)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await _settle(4)


func _on_plate(thing: ManipulableBody) -> bool:
	var at := thing.global_position - room.plate.global_position
	return absf(at.x) < 1.0 and absf(at.z) < 1.0 and at.y > 0.2 and at.y < 0.9


## A rest point the player can reach: whatever holds it up is a floor the
## player walks (or the plate), and it is within arm's reach of that floor.
## On top of the other object counts if that one is reachable.
func _reachable(at: Vector3) -> bool:
	var space := body.get_world_3d().direct_space_state
	var exclude: Array[RID] = [body.get_rid()]
	for thing in room.homes.keys():
		if is_instance_valid(thing) and (thing as Node3D).global_position \
				.distance_to(at) < 0.05:
			exclude.append((thing as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 4.0)
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var node := hit["collider"] as Node
	if node is ManipulableBody:
		return _reachable((node as Node3D).global_position)
	var named := _block_name(node)
	if not WALKABLE.has(named):
		_note("rests on %s" % named)
		return false
	return at.y - (hit["position"] as Vector3).y < 1.0 and room.inside(at)


func _pieces() -> int:
	return CrossingDParts.kit_power_nodes(room._lines["plate"]).size()


func _lit() -> int:
	var lit := 0
	for node in CrossingDParts.kit_power_nodes(room._lines["plate"]):
		lit += 1 if CrossingDParts.is_lit(node as MeshInstance3D) else 0
	return lit


func _impact_text() -> String:
	return _impact_of(room.last_impact)


func _impact_of(impact: Dictionary) -> String:
	if impact.is_empty():
		return "no impact recorded"
	return "%.1f m/s into the face, %.0f J" % [float(impact["into"]),
			float(impact["joules"])]


func _spread(values: Array[float]) -> String:
	if values.is_empty():
		return "n/a"
	var lo := values[0]
	var hi := values[0]
	var sum := 0.0
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	return "%.2f..%.2f (mean %.2f)" % [lo, hi, sum / values.size()]


## Seconds until `done` holds, or -1 when it never did.
func _until(done: Callable, seconds: float) -> float:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		if done.call():
			return float(i) / Engine.physics_ticks_per_second
		await get_tree().physics_frame
	return -1.0 if not done.call() else seconds


func _aim_and_fire(at: Vector3) -> void:
	_aim(at)
	await _settle(4)
	Input.action_press("fire_pulse")
	await _settle(2)
	Input.action_release("fire_pulse")
	await _settle(2)


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _hold(seconds: float) -> void:
	await _settle(int(seconds * Engine.physics_ticks_per_second))


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _use(at: Vector3) -> void:
	_aim(at)
	await _settle(4)
	_aim(at)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await _settle(4)


func _aim(at: Vector3) -> void:
	var eye := body.camera.global_position
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	body.rotation.y = atan2(-flat.x, -flat.y)
	body.camera.rotation.x = atan2(at.y - eye.y, flat.length())


func _walk(goal: Vector3, within := ARRIVE) -> bool:
	var still := 0
	var last := body.global_position
	var arrived := false
	Input.action_press("move_forward", 1.0)
	for _i in 2400:
		if not is_instance_valid(body):
			break
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		still = still + 1 if (here - last).length() < STILL_STEP else 0
		if still >= STUCK_FRAMES and body.is_on_floor():
			_note("stalled at %s short of %s" % [_v(here), _v(goal)])
			break
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	return arrived


func _release_all() -> void:
	for action in ["move_forward", "fire_pulse", "interact", "fire_echo",
			"fire_echo_b", "jump"]:
		Input.action_release(action)


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
