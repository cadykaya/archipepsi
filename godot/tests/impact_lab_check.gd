class_name ImpactLabCheck
extends Node
## THE IMPACT LAB, CHECKED IN THE REAL GAME, and the G0 measurement.
##
##   godot --headless --fixed-fps 60 --path godot -- --impact-lab \
##       --impact-lab-check
##
## Beside the real `Main`, through the same startup a tester's launch takes;
## the player is moved only by what a tester presses (steer, walk, aim,
## fire, use). It proves correctness, not fun:
##
## 1. **Isolation and build:** the bridge client never opened; no enemies;
##    the plate unpowered, its line dark, the lever at OFF, the shutter
##    whole, the weight at home; the shot is wired to a sound.
## 2. **The Pulse:** three shots on the shutter are refused and cost it
##    nothing; a shot at the reward through the window stops on the glass.
## 3. **Weight first, then power:** carried and set down on the unpowered
##    plate, the weight gets a dud and stays put; pulling the lever arms it,
##    the plate throws it, and its impact breaks the shutter. The weight
##    ends somewhere the player can reach.
## 4. **Power first, then weight** (after RESTART, which must bring the
##    whole lab back): standing on the powered plate does nothing to the
##    player; holding the weight over it does nothing; set down, it is
##    thrown -- and the menu opened mid-flight holds it in the air. Then
##    through the opened door to the stand-in.
## 5. **Recovery:** a weight under the floor comes home.
## 6. **The measurement:** seeded trials across the plate's area, every
##    yaw, reporting hit rate, impact speed and energy, where it hit, double
##    firing and where the weight came to rest; a `lightened` weight and a
##    10 kg crate, for what the plate does with them.

const FLAG := "--impact-lab-check"
const STILL_STEP := 0.01
const STUCK_FRAMES := 45
const ARRIVE := 0.6
const TRIALS := 40

var failures := 0
var host: ImpactLab
var room: ImpactLabRoom
var body: Player


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "ImpactLabCheck"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var existing := get_tree().root.get_node_or_null("ImpactLabCheck")
	if existing != null and existing != self:
		queue_free()
		return
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("[lab]   ok    " if ok else "[lab]   FAIL  ") + what)
	if not ok:
		failures += 1


func _note(what: String) -> void:
	print("[lab]   note  " + what)


func _phase(name_in: String) -> void:
	print("[lab] --- %s" % name_in)


func _run() -> void:
	reparent(get_tree().root)
	await _settle(10)
	if not _bind():
		_check(false, "the lab was built")
		get_tree().quit(1)
		return
	await _isolation_and_build()
	await _the_pulse()
	await _weight_first()
	await _power_first()
	await _recovery()
	await _measure()
	print("[lab] %s -- %d failure(s)" % ["PASS" if failures == 0 else "FAILED",
			failures])
	_release_all()
	get_tree().quit(1 if failures > 0 else 0)


func _bind() -> bool:
	var scene := get_tree().current_scene
	host = scene.get_node_or_null("ImpactLab") as ImpactLab \
			if scene != null else null
	if host == null:
		return false
	room = host.room
	body = host.player
	return room != null and body != null


# ============================================================ 1. build

func _isolation_and_build() -> void:
	_phase("isolation and build")
	_check(BridgeClient.isolated and not BridgeClient.online,
			"the bridge client is isolated and offline (no socket opened)")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "no enemies")
	_fresh("the plate unpowered, its line dark, the lever at OFF, the "
			+ "shutter whole, the weight at home")
	_check(room.lever.kit_model != null and _pieces() > 0,
			"the kit lever and the kit raceway (%d lit-able pieces)" % _pieces())
	var pulse: AudioStreamPlayer = host.tones._players.get("pulse")
	await _aim_and_fire(Vector3(0, 6.0, -4.0))
	_check(pulse != null and pulse.playing,
			"a shot plays the pulse sound (the bank D's host never built)")


func _fresh(what: String) -> void:
	_check(not room.powered and not room.plate.powered and not room.line_live()
			and _lit() == 0 and not room.lever.locked
			and absf(room.lever.handle_degrees() + 55.0) < 2.0
			and is_instance_valid(room.shutter) and not room.shutter_broken
			and is_equal_approx(room.shutter.hp, ImpactLabParts.ImpactShutter.HP)
			and room.weight.global_position.distance_to(room.WEIGHT_HOME) < 0.3,
			what)


# ============================================================ 2. the pulse

func _the_pulse() -> void:
	_phase("the pulse")
	_check(await _walk(Vector3(0, 0, -7.0)), "up to the shutter")
	for _i in 3:
		await _aim_and_fire(room.shutter.global_position)
		await _hold(0.4)
	_check(room.shutter.refused >= 3 and is_equal_approx(room.shutter.hp,
			ImpactLabParts.ImpactShutter.HP),
			"three pulses on the shutter are refused (%d) and cost it nothing"
			% room.shutter.refused)
	_check(await _walk(Vector3(5.0, 0, -8.5)), "to the window")
	_aim(Vector3(5.0, 1.8, room.REWARD_AT.z))
	await _settle(4)
	var hit := body.camera_ray(Constants.STATIC_PULSE_RANGE)
	var collider: Node = hit.get("collider")
	var through := collider != null and collider.get_parent() != null \
			and String(collider.get_parent().name) == "Window"
	_check(through, "a shot through the window, into the room behind, stops "
			+ "on the glass (it hits %s)" % (str(collider.get_parent().name)
				if collider != null else "nothing"))


# ===================================== 3. weight first, then power

func _weight_first() -> void:
	_phase("weight first, then power")
	_check(await _carry_weight(), "the weight picked up")
	await _set_down_on_plate()
	await _hold(1.6)
	_check(room.plate.launches == 0 and room.plate.duds == 1
			and _on_plate(), "on the unpowered plate it gets a dud and stays "
			+ "(%d launch(es), %d dud(s))" % [room.plate.launches,
				room.plate.duds])
	_check(await _walk(room.LEVER_AT + Vector3(0, 0, 1.4), 0.4),
			"to the lever")
	await _use(room.lever.global_position + Vector3(0, 0.05, 0))
	await _hold(0.6)
	_check(room.powered and room.line_live() and _lit() == _pieces()
			and room.lever.locked and CrossingDParts.is_lit(room.lever._kit_pilot),
			"the lever powers the plate: its line lit end to end, its pilot up")
	var fired_at := await _until(func() -> bool: return room.plate.launches > 0,
			3.0)
	_check(fired_at >= 0.0, "the weight already resting there arms and is "
			+ "thrown (%.2f s after power)" % fired_at)
	await _until(func() -> bool: return room.shutter_broken, 3.0)
	await _hold(2.0)
	_check(room.shutter_broken, "its impact breaks the shutter (%s)"
			% _impact_text())
	_check(_reachable(room.weight.global_position),
			"and the weight comes to rest where the player can reach it (%s)"
			% _v(room.weight.global_position))


# ===================================== 4. power first, then weight

func _power_first() -> void:
	_phase("restart; power first, then weight")
	var before := host.get_instance_id()
	host.restart()
	await _settle(12)
	_check(_bind() and host.get_instance_id() != before,
			"RESTART builds a fresh lab")
	_fresh("nothing of the last run survives it")
	_check(await _walk(room.LEVER_AT + Vector3(0, 0, 1.4), 0.4), "to the lever")
	await _use(room.lever.global_position + Vector3(0, 0.05, 0))
	await _hold(0.6)
	_check(room.powered, "the plate powered")
	_check(await _walk(room.PLATE_AT, 0.3), "onto the powered plate")
	var stood := body.global_position.y
	await _hold(2.0)
	_check(room.plate.launches == 0 and absf(body.global_position.y - stood)
			< 0.05, "standing on it does nothing to the player")
	_check(await _carry_weight(), "the weight picked up")
	_check(await _walk(room.PLATE_AT + Vector3(0, 0, 1.6), 0.3),
			"holding it beside the plate")
	_aim(room.PLATE_AT + Vector3(0, 0.6, 0))
	await _hold(2.0)
	_check(room.plate.launches == 0 and body.carry.holding(),
			"held over the powered plate, it is not thrown")
	await _set_down_on_plate(false)
	var fired_at := await _until(func() -> bool: return room.plate.launches > 0,
			3.0)
	_check(fired_at >= ImpactLabParts.ObjectPlate.SETTLE_SECONDS - 0.05,
			"set down, it arms and is thrown (%.2f s after it was let go)"
			% fired_at)
	await _settle(15)
	await _press("pause")
	await _settle(2)
	var held_at := room.weight.global_position
	await _settle(40)
	var paused_ok := host.menu_open() and get_tree().paused
	var moved := room.weight.global_position.distance_to(held_at)
	var held := paused_ok and moved < 0.001 and held_at.y > 0.8
	await _press("pause")
	await _until(func() -> bool: return room.shutter_broken, 3.0)
	_check(held and room.shutter_broken, "the menu opened mid-flight holds it "
			+ "in the air (at %s); closed, it flies on and breaks the shutter"
			% _v(held_at) + " (menu %s, moved %.3f m, broken %s)" % [paused_ok,
				moved, room.shutter_broken])
	await _hold(1.5)
	_check(await _walk(Vector3(0, 0, -11.0), 0.4)
			and await _walk(room.REWARD_AT + Vector3(0, 0, 1.4), 0.4),
			"through the opened doorway")
	await _use(room.reward.global_position + Vector3(0, 0.8, 0))
	_check(host.found.has("impact_lab_reward"),
			"the stand-in found, and nothing sent")


# ============================================================ 5. recovery

func _recovery() -> void:
	_phase("recovery")
	var before := room.respawns
	room.weight.global_position = Vector3(0, -6.0, 0)
	await _settle(4)
	_check(room.respawns == before + 1
			and room.weight.global_position.distance_to(room.WEIGHT_HOME) < 0.3,
			"a weight under the floor comes home")


# ======================================================= 6. measurement

func _measure() -> void:
	_phase("the measurement (%d trials)" % TRIALS)
	room.weight.global_position = room.WEIGHT_HOME
	if not room.powered:
		room._on_lever(room.lever)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6083
	var hits := 0
	var doubles := 0
	var strays := 0
	var speeds: Array[float] = []
	var joules: Array[float] = []
	var lateral: Array[float] = []
	var height: Array[float] = []
	var shutter_centre := Vector3(0, room.DOOR_TOP * 0.5, 0)
	var yaw_of: Array[float] = []
	for i in TRIALS:
		var offset := Vector3(rng.randf_range(-0.6, 0.6), 0,
				rng.randf_range(-0.6, 0.6))
		yaw_of.append(rng.randf() * TAU)
		var outcome := await _trial(offset, yaw_of[i])
		if outcome["fired"] != 1:
			doubles += 1 if int(outcome["fired"]) > 1 else 0
		var impact: Dictionary = outcome["impact"]
		if not impact.is_empty() and float(impact["into"]) < 10.0:
			_note("trial %d, set down %s turned %.0f deg: struck at %.1f m/s "
					% [i, _v(offset), rad_to_deg(yaw_of[i]), float(impact["into"])]
					+ "into the face, at %s" % _v(impact["at"]))
		if outcome["broken"] and not impact.is_empty():
			hits += 1
			speeds.append(float(impact["speed"]))
			joules.append(float(impact["joules"]))
			var at: Vector3 = impact["at"]
			lateral.append(at.x - shutter_centre.x)
			height.append(at.y - shutter_centre.y)
		if not outcome["reachable"]:
			strays += 1
			_note("trial %d: the weight came to rest at %s" % [i,
					_v(outcome["rest"])])
	_check(hits == TRIALS, "%d of %d throws break the shutter" % [hits, TRIALS])
	_check(doubles == 0, "one throw per set-down (%d trial(s) fired twice)"
			% doubles)
	_check(strays == 0, "every weight comes to rest where the player can "
			+ "reach it (%d did not)" % strays)
	_note("impact speed %s m/s; energy %s J (the shutter breaks at %.0f J "
			% [_spread(speeds), _spread(joules),
				ImpactLabParts.ImpactShutter.HP
					* ImpactLabParts.ImpactShutter.JOULES_PER_HP]
			+ "in one blow)")
	_note("where it struck, from the shutter's centre: across %s m, up %s m "
			% [_spread(lateral), _spread(height)]
			+ "(the shutter is 3.0 x 3.0 m)")
	# What the plate does with other things on it, for the report.
	var light := await _trial(Vector3.ZERO, 0.0, "lightened")
	_note("a LIGHTENED weight (impulse x2): fired %d, broke the shutter %s, "
			% [light["fired"], light["broken"]]
			+ "came to rest at %s" % _v(light["rest"]))
	var crate := ManipulableBody.create("lab_crate", 10.0,
			Vector3(0.45, 0.45, 0.45))
	crate.carriable = true
	room.add_child(crate)
	var weight := room.weight
	room.weight = crate
	var small := await _trial(Vector3.ZERO, 0.0)
	_note("a 10 kg crate: fired %d, struck with %.0f J (accepted: %s), "
			% [small["fired"], float((small["impact"] as Dictionary).get(
				"joules", 0.0)), (small["impact"] as Dictionary).size() > 0
				and room.shutter.hp < ImpactLabParts.ImpactShutter.HP]
			+ "broke it: %s" % small["broken"])
	room.weight = weight
	crate.queue_free()


## One throw from a set-down at `offset`, turned `yaw`; what happened.
func _trial(offset: Vector3, yaw: float, status := "") -> Dictionary:
	room.reset_trial(offset, yaw)
	if status != "":
		room.weight.apply_status(status, 30.0, 1.0)
	await _settle(2)
	var start := room.plate.launches
	await _until(func() -> bool: return room.shutter_broken, 4.0)
	await _hold(2.5)
	var rest := room.weight.global_position
	var out := {"fired": room.plate.launches - start,
			"broken": room.shutter_broken,
			"impact": room.last_impact.duplicate(),
			"rest": rest, "reachable": _reachable(rest)}
	if status != "" and room.weight.statuses != null:
		room.weight.statuses = null
	return out


# ============================================================ helpers

func _carry_weight() -> bool:
	if not await _walk(room.weight.global_position, 1.3):
		return false
	await _use(room.weight.global_position)
	await _settle(4)
	return body.carry.holding() and body.carry.body == room.weight


## Stand at the plate's near edge, look at its middle, let the carry
## settle there, and put the weight down.
func _set_down_on_plate(walk := true) -> void:
	if walk:
		await _walk(room.PLATE_AT + Vector3(0, 0, 1.6), 0.3)
	_aim(room.PLATE_AT + Vector3(0, 0.6, 0))
	await _settle(30)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await _settle(4)


func _on_plate() -> bool:
	var at := room.weight.global_position - room.plate.global_position
	return absf(at.x) < 1.0 and absf(at.z) < 1.0 and at.y > 0.2 and at.y < 0.9


## On a floor the player walks: the hall, the doorway (once open), or the
## room behind it.
func _reachable(at: Vector3) -> bool:
	if at.y < -0.2 or at.y > 1.2:
		return false
	if room.shutter_broken and at.x > room.DOOR_X.x and at.x < room.DOOR_X.y \
			and at.z <= room.HALL.position.y \
			and at.z >= room.HALL.position.y - room.WALL:
		return true
	var hall := room.HALL
	if at.x > hall.position.x and at.x < hall.end.x \
			and at.z > hall.position.y and at.z < hall.end.y:
		return true
	var back := room.BACK
	return at.x > back.position.x and at.x < back.end.x \
			and at.z > back.position.y and at.z < hall.position.y - room.WALL


func _pieces() -> int:
	return CrossingDParts.kit_power_nodes(room._lines["plate"]).size()


func _lit() -> int:
	var lit := 0
	for node in CrossingDParts.kit_power_nodes(room._lines["plate"]):
		lit += 1 if CrossingDParts.is_lit(node as MeshInstance3D) else 0
	return lit


func _impact_text() -> String:
	var impact: Dictionary = room.last_impact
	if impact.is_empty():
		return "no impact recorded"
	return "%.1f m/s, %.0f J" % [float(impact["speed"]),
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
	for action in ["move_forward", "fire_pulse", "interact"]:
		Input.action_release(action)


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
