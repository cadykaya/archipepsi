extends SceneTree
## What the CURRENT player can actually climb, walk up and jump onto.
##
##   godot --path godot -s _harness/limits.gd -- <out>
##
## ## Why this exists
##
## The span-basin request says its stairs stop three risers short and asks
## for three more at 0.875 m. It also says, in a section headed "separately,
## and not yours", that there is **no step-up anywhere in `player.gd`** --
## `move_and_slide` does not climb -- so a player has to jump every riser.
##
## Those two facts together decide whether extending the flight closes the
## finding. The acceptance question is whether the current Player can
## complete the route, so the first thing to establish is what the current
## Player can do, and the honest way to establish it is to drive one at a
## step and see.
##
## Everything here uses Production's own numbers -- `Constants.GRAVITY`,
## `WALK_SPEED`, `JUMP_VELOCITY`, `PLAYER_HEIGHT`, `PLAYER_RADIUS` -- and
## the engine's own `move_and_slide`. It is not `player.gd`: no movement
## packages, no volumes, no assistance. It measures the floor under all of
## that.

const GRAVITY := 24.0            # Constants.GRAVITY
const WALK_SPEED := 7.0          # Constants.WALK_SPEED
const JUMP_VELOCITY := 8.0       # Constants.JUMP_VELOCITY
const PLAYER_HEIGHT := 1.8       # Constants.PLAYER_HEIGHT
const PLAYER_RADIUS := 0.4       # Constants.PLAYER_RADIUS
const FLOOR_MAX_ANGLE := deg_to_rad(46.0)
const STEP := 1.0 / 60.0

var _out: String
var _log := {}
var _problems: Array[String] = []


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[limits] FAIL: %s" % what)


func _slab(root: Node3D, centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.transform = Transform3D(Basis.IDENTITY, centre)
	root.add_child(body)


func _walker(root: Node3D, at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = PLAYER_HEIGHT
	capsule.radius = PLAYER_RADIUS
	shape.shape = capsule
	body.add_child(shape)
	body.floor_max_angle = FLOOR_MAX_ANGLE
	root.add_child(body)
	body.global_position = at + Vector3(0, PLAYER_HEIGHT / 2.0 + 0.05, 0)
	return body


## Walk at one step of height `rise`, optionally jumping at the foot of it.
## Returns the height gained.
func _try_step(rise: float, jumping: bool) -> float:
	var root := Node3D.new()
	get_root().add_child(root)
	# A run-up, then one riser, then a landing long enough to stand on.
	_slab(root, Vector3(0, -0.5, -3.0), Vector3(4.0, 1.0, 6.0))
	_slab(root, Vector3(0, rise / 2.0 - 0.5, 1.5), Vector3(4.0, 1.0 + rise, 3.0))
	var body := _walker(root, Vector3(0, 0, -4.0))

	var jumped := false
	var best := 0.0
	for _i in range(int(3.0 / STEP)):
		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
			# Jump at the foot of the riser, the way a player would: the
			# last moment there is still ground under them.
			if jumping and not jumped and body.global_position.z > -0.9:
				v.y = JUMP_VELOCITY
				jumped = true
		else:
			v.y -= GRAVITY * STEP
		v.x = 0.0
		v.z = WALK_SPEED
		body.velocity = v
		body.move_and_slide()
		if body.is_on_floor():
			best = maxf(best, body.global_position.y - PLAYER_HEIGHT / 2.0)
		if body.global_position.z > 2.5:
			break
	root.free()
	return best


## Walk UP A RAMP of `degrees`, and report the height gained. The
## alternative to a step is a slope, and the engine has an opinion about
## slopes -- `floor_max_angle` -- that a stair does not get to use.
func _try_ramp(degrees: float) -> float:
	var root := Node3D.new()
	get_root().add_child(root)
	var rise := 6.0
	var run := rise / tan(deg_to_rad(degrees))
	_slab(root, Vector3(0, -0.5, -3.0), Vector3(6.0, 1.0, 6.0))
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.6, sqrt(run * run + rise * rise))
	shape.shape = box
	ramp.add_child(shape)
	ramp.transform = Transform3D(
			Basis(Vector3.RIGHT, -deg_to_rad(degrees)),
			Vector3(0, rise / 2.0 - 0.3, run / 2.0))
	root.add_child(ramp)
	_slab(root, Vector3(0, rise - 0.5, run + 3.0), Vector3(6.0, 1.0, 6.0))
	var body := _walker(root, Vector3(0, 0, -4.0))

	var best := 0.0
	for _i in range(int(12.0 / STEP)):
		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
		else:
			v.y -= GRAVITY * STEP
		v.x = 0.0
		v.z = WALK_SPEED
		body.velocity = v
		body.move_and_slide()
		if body.is_on_floor():
			best = maxf(best, body.global_position.y - PLAYER_HEIGHT / 2.0)
		if body.global_position.z > run + 2.0:
			break
	root.free()
	return best


## The tallest riser the body ends up standing on top of.
func _limit(jumping: bool) -> Dictionary:
	var rows := []
	var highest := 0.0
	var rise := 0.02
	while rise <= 2.05:
		var gained := _try_step(rise, jumping)
		var up := gained >= rise - 0.02
		rows.append({"rise": snappedf(rise, 0.01),
				"stood_at": snappedf(gained, 0.003), "climbed": up})
		if up:
			highest = rise
		rise += 0.02 if rise < 0.4 else 0.05
	return {"highest_climbed_m": snappedf(highest, 0.01), "rows": rows}


func _run() -> void:
	var walked := _limit(false)
	var jumped := _limit(true)
	_log["walk_up"] = walked
	_log["jump_up"] = jumped

	var ramps := []
	var steepest := 0.0
	for degrees: float in [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 44.0,
			46.0, 48.0, 50.0]:
		var gained := _try_ramp(degrees)
		var up := gained >= 6.0 - 0.05
		ramps.append({"degrees": degrees, "climbed_m": snappedf(gained, 0.01),
				"reached_the_top": up})
		if up:
			steepest = degrees
	_log["walk_up_a_ramp"] = {"steepest_degrees": steepest, "rows": ramps}
	print("[limits] the steepest ramp walked to the top: %.0f degrees "
			% steepest + "(floor_max_angle is 46)")
	print("[limits] walking, the tallest riser mounted: %.2f m"
			% walked["highest_climbed_m"])
	print("[limits] jumping, the tallest riser mounted: %.2f m"
			% jumped["highest_climbed_m"])
	print("[limits] for reference: MAX_VERTICAL_STEP 1.00, "
			+ "JUMP_APEX_HEIGHT 1.33")

	if walked["highest_climbed_m"] <= 0.0:
		_fail("the walker climbed nothing at all, which is a harness "
				+ "fault rather than a finding")
	if jumped["highest_climbed_m"] < walked["highest_climbed_m"]:
		_fail("jumping reached lower than walking; the jump is not firing")

	if _out != "":
		var f := FileAccess.open("%s/controller_limits.json" % _out,
				FileAccess.WRITE)
		if f == null:
			_fail("could not write controller_limits.json under %s" % _out)
		else:
			f.store_string(JSON.stringify(_log, "  "))
			f.close()
	if _problems.is_empty():
		quit(0)
		return
	quit(1)
