extends Node
## FIVE PICTURES OF THE RAILWAY (`make railway-shots`).
##
## Diagnostic, and it asserts nothing: `godot-rail-junction` is what
## makes the claims about this scenario. What this is for is the
## question a test cannot answer -- *is it legible?* Can you tell from
## the S1 platform which way the green control sends you; can you see,
## standing at S2, that there is no track and that the thing to do about
## it is up on the gantry.
##
## Output is `user://railway_shots`, outside the repository, because
## these are for looking at rather than for diffing.

const OUT_DIR := "user://railway_shots"

var _yard: RailwayScenario = null
var _camera: Camera3D = null


func _ready() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT_DIR))
	_yard = RailwayScenario.new()
	add_child(_yard)
	for _i in 40:
		await get_tree().physics_frame
	# THE SCENARIO'S OWN CAMERA IS THE PLAYER'S. A framed shot needs one
	# that is not attached to a body standing on a platform.
	if _yard.player != null and _yard.player.camera != null:
		_yard.player.camera.current = false
	_camera = Camera3D.new()
	_camera.fov = 70.0
	add_child(_camera)
	_camera.current = true

	var rail := _yard.rail
	var docks := _yard.carrier.dock_offsets
	var s1 := rail.at(docks[0])
	var s2 := rail.at(docks[1])
	var s3 := rail.at(docks[2])

	await _shoot("1_boarding", s1 + Vector3(-6.0, 4.0, 6.0), s1,
		"what a player sees arriving at S1")
	await _shoot("2_the_gap", s2 + Vector3(-10.0, 9.0, -9.0),
		(s2 + s3) * 0.5,
		"standing at S2: no track, and the gantry above it")
	# CLOSE ON A CONTROL. Whether the pair reads -- chevron up, colour
	# second -- is the question a wide shot cannot answer.
	var control: RailReceiver = _yard.controls.receivers()[0]
	await _shoot("2b_the_control",
			control.global_position + control.global_transform.basis.x * 2.4
			+ Vector3(0.0, 0.5, 0.0), control.global_position,
			"a direction control, close")
	# THE BRANCH, from the junction: the walk out, the gantry it
	# passes under, and the pedestal at the end of it.
	var grant_at: Vector3 = _yard.grant.global_position
	await _shoot("2c_the_branch",
			s2 + _yard.dock_side(1) * 2.0 + Vector3(0.0, 9.0, -13.0),
			(s2 + grant_at) * 0.5,
			"the acquisition branch, out past the gantry")
	await _shoot("3_the_lever", _yard.lever.global_position
		+ Vector3(3.2, 1.9, 3.2), _yard.lever.global_position,
		"the alignment control on the gantry")

	# RIDE IT. The carrier at S2 is the shot that says whether stepping
	# aboard reads as stepping onto something.
	_yard.carrier.request(RailCarrier.FORWARD)
	for _i in 900:
		if _yard.carrier.heading == RailCarrier.HOLD:
			break
		await get_tree().physics_frame
	await _shoot("4_aboard", s2 + Vector3(-7.0, 4.5, -7.0), s2,
		"the skiff standing at S2")

	_yard.lever.interact(null)
	for _i in 900:
		if _yard.span.locked:
			break
		await get_tree().physics_frame
	await _shoot("5_repaired", s2 + Vector3(-10.0, 9.0, -9.0),
		(s2 + s3) * 0.5, "the span locked home, and S3 reachable")

	print("  railway shots written to %s"
		% ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _shoot(name: String, eye: Vector3, at: Vector3,
		note: String) -> void:
	_camera.global_position = eye
	_camera.look_at(at, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(
		"%s/%s.png" % [OUT_DIR, name]))
	print("    %s -- %s" % [name, note])
