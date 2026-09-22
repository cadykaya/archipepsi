extends Node
## EX50-021 COUNTERFIRE ARCADE (`make godot-counterfire`).
##
## The specification is paper
## (`docs/design-library/EX50_entries/EX50-021.md`) and it names its own
## critical dependency: "**projectile-source acceptance at the
## receiver**" (§12), with §10 insisting it be settled first — "First
## verify a real hostile projectile can hit the receiver and produce the
## same input pulse as a player projectile, without double-counting
## impact or changing damage provenance."
##
## So that is the first case, and it is asked of the primitive before any
## room is built around it. The answer, before this batch, was **no**:
## `EnemyProjectile` delivered damage to the player and to nothing else,
## and anything that was not the player simply stopped the shot. §3
## warned about exactly that — "Existing player-only target filters must
## not be assumed to support this" — and it was right.
##
## The bars this suite holds the room to:
##
##   §11  a committed hostile projectile passes through the vacated
##        stance and hits the actual receiver while the player reaches
##        cover; a counterpart puts a real blocker between muzzle and
##        receiver and the shutter must NOT open; and killing the gunner
##        before any hit must still leave the route completable.
##   §4   a missed shot changes no machine state, and a projectile
##        intercepted by cover cannot also trigger what stood behind it.
##   §3   the hood is physical directionality, not an owner-ID
##        exception: a shot from the arrival side stops on steel and the
##        same shot from the gunner's side operates the plate.
##   §8   the receiver is not destructible, and a player in the doorway
##        is not crushed when the interval expires.
##   §9   the manual release is persistent and the timer is not.
##
## **Evidence classes are kept apart.** `_the_committed_shot`,
## `_the_blocked_counterpart` and `_the_fallback_route` are continuous
## play: the gunner is the real enemy with its real cooldown and its
## real line-of-sight test, the dodge is a keypress made in reaction to
## seeing the projectile, and every metre is walked. The primitive cases
## construct a projectile directly and say so.
##
## **What this does not measure is whether the bait is fair.** §12 says
## it plainly and it is still true: the margin between a shot leaving
## the muzzle and arriving at the stance is reported as a number, and a
## number is not a playtest.

const STEP := 1.0 / 60.0
const HAND_FRAMES := 1800

var _failures := 0
var _checks := 0
var _notes := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	await _the_primitive()
	await _the_extension_is_bounded()
	await _cover_intercepts()
	await _the_hood_is_steel()
	await _the_committed_shot()
	await _the_blocked_counterpart()
	await _the_fallback_route()
	await _the_interlock()
	await _the_release_is_permanent()
	print("")
	if _failures == 0:
		print("GODOT COUNTERFIRE OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	printerr("GODOT COUNTERFIRE FAILED (%d of %d)" % [_failures, _checks])
	get_tree().quit(1)


func _settle(frames := 30) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _room(blocked := false) -> CounterfireArcade:
	var made := CounterfireArcade.new()
	made.blocked = blocked
	add_child(made)
	return made


# ----------------------------------------------------- the primitive

## §10's first task, asked of the primitive and nothing else.
##
## **SYNTHETIC:** a receiver on its own, and a projectile placed in front
## of it by hand. No room, no gunner, no player. What it answers is
## whether the two hit paths arrive at the same place, which is a
## question about the code and not about the encounter.
func _the_primitive() -> void:
	print("  -- PRIMITIVE: does a hostile shot reach a machine input?")
	var stage := Node3D.new()
	add_child(stage)
	var receiver := ImpactReceiver.create(0.0)
	stage.add_child(receiver)
	receiver.global_position = Vector3.ZERO
	await _settle(6)
	var body := receiver.element.get_node_or_null("TargetBody")
	_check(body != null, "the receiver has a target body a shot can hit")
	_check((body as Node).is_in_group(Damageable.GROUP),
		"which is damageable, as every shot element's is")
	_check((body as Node).is_in_group(Damageable.HOSTILE_INPUT),
		"and which has DECLARED that it accepts hostile fire")

	# A PLAYER'S HIT, through the ordinary path every weapon uses.
	_check(Damageable.hit(body, 6.0, Vector3.FORWARD),
		"a player-path hit lands on it")
	await _settle(2)
	_check(receiver.hits == 1, "and produces one pulse")
	for _i in 40:
		receiver.advance(STEP)
	_check(receiver.armed(), "the receiver re-arms, because the interval "
			+ "it drives refreshes on another hit")

	# A HOSTILE SHOT, fired for real at the active face.
	var before := receiver.hits
	var shot: Node3D = await _hostile_shot(stage, Vector3(0.0, 0.0, -4.0),
			Vector3(0.0, 0.0, 1.0))
	for _i in 60:
		await get_tree().physics_frame
		if receiver.hits > before:
			break
	_check(receiver.hits == before + 1,
		"a hostile projectile produces the SAME pulse, from the same "
			+ "call with the same arguments")
	await _settle(4)
	_check(not is_instance_valid(shot),
		"and the projectile is spent, so one impact is counted once")
	# NOT DESTRUCTIBLE (§8). Ten more hits change nothing but the count.
	for i in 10:
		receiver.advance(1.0)
		Damageable.hit(body, 999.0, Vector3.FORWARD)
		await get_tree().physics_frame
	_check(is_instance_valid(receiver) and receiver.element != null
			and is_instance_valid(body),
		"the receiver survives being shot to pieces -- it is a machine "
			+ "input with durable housing, not a destructible")
	stage.queue_free()


## The extension is BOUNDED, and this is the case that says so.
##
## An ordinary shot element -- not wrapped by `ImpactReceiver`, so it has
## never declared anything -- is damageable, is hit by every player
## weapon, and must be untouched by a hostile shot. Without this the
## change would not be "an enemy can operate this receiver", it would be
## "an enemy can operate every damageable thing in the game", starting
## with the breakable panel an affordance's capability is charged for.
func _the_extension_is_bounded() -> void:
	print("  -- BOUNDED: what a hostile shot may NOT operate")
	var stage := Node3D.new()
	add_child(stage)
	var plain := ActivityElement.create(ActivityElement.SHOT, 0,
			ActivityElement.TARGET_SIZE, Color(0.6, 0.8, 1.0))
	stage.add_child(plain)
	plain.global_position = Vector3.ZERO
	await _settle(6)
	var body := plain.get_node_or_null("TargetBody")
	_check(body != null and (body as Node).is_in_group(Damageable.GROUP),
		"an ordinary shot element is damageable")
	_check(not (body as Node).is_in_group(Damageable.HOSTILE_INPUT),
		"and has not declared that it accepts hostile fire")
	var shot: Node3D = await _hostile_shot(stage, Vector3(0.0, 0.0, -3.0),
			Vector3(0.0, 0.0, 1.0))
	for _i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(shot):
			break
	_check(not plain.is_set,
		"so a hostile projectile does not set it")
	_check(not is_instance_valid(shot),
		"though the shot still stops on it, as it stops on anything")
	# ...and the same element answers a player's hit exactly as before.
	_check(Damageable.hit(body, 6.0, Vector3.FORWARD) and plain.is_set,
		"while a player's hit works unchanged")
	stage.queue_free()


## §4: "A projectile intercepted by the player's cover cannot also
## trigger the receiver behind it."
func _cover_intercepts() -> void:
	print("  -- COVER: a shot stopped on the way does not arrive")
	var stage := Node3D.new()
	add_child(stage)
	var receiver := ImpactReceiver.create(0.0)
	stage.add_child(receiver)
	receiver.global_position = Vector3.ZERO
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.4)
	shape.shape = box
	wall.add_child(shape)
	stage.add_child(wall)
	wall.global_position = Vector3(0.0, 0.0, -2.0)
	await _settle(6)
	var shot: Node3D = await _hostile_shot(stage, Vector3(0.0, 0.0, -5.0),
			Vector3(0.0, 0.0, 1.0))
	for _i in 90:
		await get_tree().physics_frame
		if not is_instance_valid(shot):
			break
	_check(receiver.hits == 0,
		"the receiver behind the cover was not tripped")
	_check(not is_instance_valid(shot), "and the shot stopped there")
	stage.queue_free()


## §3: "a shot from behind hits the hood; a shot from the gunner side can
## hit the active plate. This is physical directionality, not an
## owner-ID exception."
##
## Asked with the REAL Static Pulse from two real standing positions, so
## what is being tested is the geometry rather than a branch.
func _the_hood_is_steel() -> void:
	print("  -- HOOD: which side of the receiver a shot can address")
	var room := _room()
	await _settle(40)
	room.gunner.queue_free()
	room.gunner = null
	await _settle(4)
	var body: Player = room.player
	var plate := room.receiver.element.global_position
	# FROM THE ARRIVAL SIDE. The hood is between the muzzle and the
	# plate, and the shot stops on it.
	body.global_position = Vector3(0.0, 1.2,
			CounterfireArcade.RECEIVER_Z - 2.6)
	body.velocity = Vector3.ZERO
	await _settle(12)
	_aim(body, plate)
	await _pulse(body)
	await _settle(10)
	_check(room.receiver.hits == 0,
		"a Static Pulse from the arrival side does not reach the plate")
	_check(room.shutter.is_shut(), "and the shutter stays shut")
	# FROM THE GUNNER'S SIDE, up the lane. Same weapon, same plate.
	body.global_position = Vector3(0.0, 1.2,
			CounterfireArcade.RECEIVER_Z + 5.0)
	body.velocity = Vector3.ZERO
	await _settle(12)
	_aim(body, plate)
	await _pulse(body)
	await _settle(10)
	_check(room.receiver.hits == 1,
		"the same weapon from the lane side operates it")
	_check(not room.shutter.is_shut(),
		"and the shutter starts to open")
	room.queue_free()


# --------------------------------------------------- continuous play

## §11, THE POSITIVE RUN. The gunner is real, the dodge is a keypress.
##
## **Nothing here knows the enemy is about to fire.** The player walks
## into the lane, stands there, and starts moving the moment a
## projectile exists in the world -- which is the only cue a human has,
## because the ranged archetype has no windup (F-14). The projectile's
## direction was fixed at the muzzle, so it carries on into the stance
## the player has left.
func _the_committed_shot() -> void:
	print("  -- COMMITTED: bait the gunner, leave, and let the shot land")
	var room := _room()
	await _settle(40)
	var out := await _bait(room)
	_check(bool(out["fired"]), "the gunner committed a shot")
	_check(bool(out["dodged"]), "and the player reached the alcove")
	_check(room.receiver.hits == 1,
		"the projectile carried on into the vacated stance and hit the "
			+ "receiver")
	for _i in 180:
		await get_tree().physics_frame
		if room.shutter.is_open():
			break
	_check(room.shutter.is_open(), "the service shutter opened")
	_check(is_equal_approx(room.player.hp, float(out["hp_at_stance"])),
		"and the player was not hit doing it (%0.f HP)" % room.player.hp)
	_note("the shot needed %.2f s to reach the stance; the step into "
			% out["flight"] + "cover took %.2f s" % out["dodge"])
	# THE NOTE THIS REPLACES SAID THE OPPOSITE, and was true when it was
	# written: "the ranged archetype has NO windup". That was F-14, and
	# H2 repaired it -- the archetype now plants and telegraphs `aim` for
	# `Enemy.TELEGRAPH_SECONDS["ranged"]` before the projectile leaves.
	# A note that went on asserting the defect after the repair would be
	# this suite reporting history as measurement.
	_note("the ranged archetype telegraphs `aim` for %.2f s before "
			% float(Enemy.TELEGRAPH_SECONDS["ranged"])
			+ "firing, so the player has that plus the %.2f s flight. "
			% out["flight"]
			+ "Whether the total margin is fair is still a playtest "
			+ "question and is still not answered here")
	room.queue_free()


## §11's counterpart: "A counterpart adds a real blocker between muzzle
## and receiver; the shutter must not open."
func _the_blocked_counterpart() -> void:
	print("  -- BLOCKED: the same bait with steel across the lane")
	var room := _room(true)
	await _settle(40)
	var out := await _bait(room)
	_check(bool(out["fired"]), "the gunner committed the same shot")
	_check(bool(out["dodged"]), "the player reached the same alcove")
	_check(room.receiver.hits == 0,
		"the receiver was NOT tripped -- the blocker took the shot")
	_check(room.shutter.is_shut(),
		"and the shutter did not open, so the positive run was "
			+ "measuring the lane and not its own commands")
	room.queue_free()


## The bait, as a player performs it. Returns what happened.
func _bait(room: CounterfireArcade) -> Dictionary:
	var body: Player = room.player
	# INTO THE LANE FROM THE SIDE, at the stance's own depth. Walking
	# straight at the stance from the arcade crosses the ground the
	# counterpart's blocker stands on, and a bait that could not be
	# reached in one of the two rooms would not be the same bait.
	await _walk_to(body, Vector3(3.6, 0.0, CounterfireArcade.STANCE.z),
			0.8)
	await _walk_to(body, CounterfireArcade.STANCE, 0.5)
	# STAND AND FACE THE GUNNER. Nothing is pressed; the enemy's own
	# perception and cooldown decide when.
	_aim(body, room.muzzle())
	var hp_at_stance: float = body.hp
	var shot: Node3D = null
	var fired_at := 0
	var frame := 0
	for _i in HAND_FRAMES:
		await get_tree().physics_frame
		frame += 1
		shot = _shot_in_flight()
		if shot != null:
			fired_at = frame
			break
	if shot == null:
		return {"fired": false, "dodged": false, "flight": 0.0,
				"dodge": 0.0, "hp_at_stance": hp_at_stance}
	# THE DODGE: west, into the alcove, started on seeing the shot.
	var from := shot.global_position
	var dodged := false
	var dodge_frames := 0
	Input.action_press("move_left", 1.0)
	body.rotation.y = 0.0
	for _i in 120:
		await get_tree().physics_frame
		dodge_frames += 1
		if body.global_position.x <= CounterfireArcade.ALCOVE.x + 0.4:
			dodged = true
			break
	Input.action_release("move_left")
	for _i in 180:
		await get_tree().physics_frame
		if room.receiver.hits > 0 or not is_instance_valid(shot):
			break
	var reach := absf(CounterfireArcade.STANCE.z - from.z) \
			/ Constants.RANGED_PROJECTILE_SPEED
	var _unused := fired_at
	return {"fired": true, "dodged": dodged, "flight": reach,
			"dodge": float(dodge_frames) * STEP,
			"hp_at_stance": hp_at_stance}


## §6 and §11: "Killing the gunner before any hit must still leave the
## fallback route completable."
##
## Walked end to end: kill the gunner, walk up the lane past the hood,
## turn and operate the plate with an ordinary Static Pulse, run the
## service route, pull the release and reach the goal.
func _the_fallback_route() -> void:
	print("  -- FALLBACK: the gunner is dead and the room still finishes")
	var room := _room()
	await _settle(40)
	room.gunner.take_damage(999.0, Vector3.FORWARD, 0.0)
	await _settle(40)
	_check(room.receiver.hits == 0, "nothing has tripped the receiver")
	var body: Player = room.player
	# UP THE LANE, PAST THE RECEIVER, then round to face it.
	await _walk_to(body, Vector3(0.0, 0.0,
			CounterfireArcade.RECEIVER_Z + 4.5), 0.8)
	await _settle(8)
	_aim(body, room.receiver.element.global_position)
	await _pulse(body)
	await _settle(10)
	_check(room.receiver.hits == 1,
		"an ordinary Static Pulse from the lane side operates the plate")
	_check(not room.shutter.is_shut(), "and the shutter opens")
	# THROUGH THE SHUTTER, inside its interval.
	var through := await _walk_to(body, Vector3(
			CounterfireArcade.ROOM_HALF.x + 1.4, 0.0,
			CounterfireArcade.SHUTTER_Z), 1.0, 400)
	_check(through and body.global_position.x
			> CounterfireArcade.ROOM_HALF.x,
		"the service route is reachable within the interval "
			+ "(%.1f s left)" % room.shutter.left)
	await _walk_to(body, Vector3(16.2, CounterfireArcade.FLANK_Y, -2.0),
			1.1, 500)
	await _settle(10)
	_check(absf(body.global_position.y - CounterfireArcade.FLANK_Y) < 1.0,
		"the short supported route reaches the upper flank, at y=%.2f"
			% body.global_position.y)
	var pulled := await _pull(body, room.release)
	_check(pulled and room.released,
		"the manual release was operated")
	await _walk_to(body, room.goal_plate.global_position, 0.9, 300)
	await _settle(20)
	_check(room.reached_goal,
		"and the goal beyond it was reached, with the gunner dead the "
			+ "whole time")
	room.queue_free()


## §8: "A player already in the doorway is not crushed."
func _the_interlock() -> void:
	print("  -- INTERLOCK: the shutter will not close on somebody")
	var room := _room()
	await _settle(40)
	room.gunner.queue_free()
	room.gunner = null
	var body: Player = room.player
	room.shutter.trip()
	for _i in 200:
		await get_tree().physics_frame
		if room.shutter.is_open():
			break
	_check(room.shutter.is_open(), "the shutter opened")
	body.global_position = Vector3(CounterfireArcade.ROOM_HALF.x, 1.2,
			CounterfireArcade.SHUTTER_Z)
	body.velocity = Vector3.ZERO
	await _settle(20)
	_check(room.shutter.doorway_occupied(),
		"and a body standing in the opening is seen there")
	# RUN THE INTERVAL OUT with the player still in it.
	room.shutter.left = 0.2
	for _i in 200:
		await get_tree().physics_frame
	_check(room.shutter.is_open() and room.shutter.overrun() > 1.0,
		"the interval expired %.1f s ago and the shutter is still open"
			% room.shutter.overrun())
	# STEP CLEAR, and it shuts.
	body.global_position = Vector3(CounterfireArcade.ROOM_HALF.x - 4.0,
			1.2, CounterfireArcade.SHUTTER_Z)
	body.velocity = Vector3.ZERO
	for _i in 400:
		await get_tree().physics_frame
		if room.shutter.is_shut():
			break
	_check(room.shutter.is_shut(),
		"and it shuts once the doorway is clear")
	room.queue_free()


## §9: "the service route remains open after its accepted release", and
## the timer is not what keeps it open.
func _the_release_is_permanent() -> void:
	print("  -- PERSISTENT: what survives the interval running out")
	var room := _room()
	await _settle(40)
	room.gunner.queue_free()
	room.gunner = null
	room._on_release(null)
	await _settle(6)
	_check(room.released, "the release was accepted")
	for _i in 400:
		await get_tree().physics_frame
		if room.shutter.is_open():
			break
	_check(room.shutter.is_open(), "the shutter is open")
	# TWENTY SECONDS, against an eight-second interval.
	for _i in 1200:
		await get_tree().physics_frame
	_check(room.shutter.is_open(),
		"and twenty seconds later -- two and a half intervals -- it is "
			+ "still open, because the release is not a timer")
	_check(room.receiver.hits == 0,
		"and nothing had to be shot again to keep it that way")
	room.queue_free()


# ------------------------------------------------------------ helpers

## A projectile the gunner would have fired, constructed directly.
## Labelled synthetic wherever it is used.
## A projectile the gunner would have fired, from a gunner stood so its
## muzzle is exactly at `from`. Built THROUGH the enemy that owns it --
## `EnemyProjectile` is an inner class and there is no second way to make
## one, which is the point: a suite that constructed its own would be
## testing its own copy.
func _hostile_shot(into: Node, from: Vector3, towards: Vector3) -> Node3D:
	var gunner := Enemy.create("ranged", "concrete_facility")
	into.add_child(gunner)
	gunner.global_position = from - Vector3.UP * 1.2
	await get_tree().physics_frame
	var made := gunner.fire_at(from + towards.normalized() * 40.0)
	gunner.queue_free()
	await get_tree().physics_frame
	return made


## The one projectile in the world, or null. `EnemyProjectile` adds
## itself to the current scene, so this looks where it actually lands.
func _shot_in_flight() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for child in scene.get_children():
		var area := child as Area3D
		if area == null:
			continue
		if area.get("speed") != null and area.get("direction") != null:
			return area
	return null


func _aim(body: Player, at: Vector3) -> void:
	var d: Vector3 = at - body.camera.global_position
	body.rotation.y = atan2(-d.x, -d.z)
	body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## One Static Pulse. `fire_pulse` is read with `is_action_pressed`, so
## the press is held across a couple of frames and then released.
func _pulse(body: Player) -> void:
	Input.action_press("fire_pulse", 1.0)
	for _i in 3:
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	await get_tree().physics_frame
	var _unused := body


func _pull(body: Player, lever: CallLever) -> bool:
	var before := lever.pulls
	_aim(body, lever.global_position + Vector3(0.0, 0.1, 0.0))
	await get_tree().physics_frame
	Input.action_press("interact", 1.0)
	for _i in 12:
		await get_tree().physics_frame
		if lever.pulls > before:
			break
	Input.action_release("interact")
	await get_tree().physics_frame
	return lever.pulls > before


func _walk_to(body: Player, goal: Vector3, within := 1.2,
		frames := 320) -> bool:
	var arrived := false
	var still := 0
	var last := body.global_position
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		body.camera.rotation.x = 0.0
		if (here - last).length() < 0.012:
			still += 1
			if still == 18 and body.is_on_floor():
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
				still = 0
		else:
			still = 0
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	return arrived
