class_name CounterfireArcadeRoom
extends Node3D
## EX50-021's ROOM, whoever owns it (O05-06.3).
##
## Everything `--counterfire` built between its sky and its player, moved
## here whole: the arcade and its gallery, the lane and its alcove, the
## hooded receiver and its conduit, the timed service shutter, the annex
## with its upper flank and permanent release, and -- when its owner asks
## for one -- the gunner. The development scenario owns one of these at
## the origin; a composed Zone hosts one through `CounterfireArcadeHosted`.
## One implementation, two owners.
##
## **IN ITS OWN FRAME.** Every part is placed with `position`, never
## `global_position`: the scenario put its room at the world origin, where
## the two agree, and a Zone does not.
##
## **The gunner is the owner's decision.** EX50-021 §9: "Enemy position
## and health follow the source encounter persistence rather than a new
## puzzle-owned copy." The scenario has no encounter, so it asks the room
## for one; a Zone's gunner is the chamber's own declared enemy, spawned
## and persisted by the Zone, and the hosted room builds none.

signal said(text: String)
## The permanent release was pulled by a player -- never on restore.
signal release_engaged

## §2: 24 by 18 m.
const ROOM_HALF := Vector2(12.0, 9.0)
const ROOM_HEIGHT := 8.0
const SLAB := 0.6

## The lane, running north-south down x = 0.
const LANE_HALF := 1.5
## Where the gunner stands, and how high its gallery is.
const GALLERY_Y := 1.0
const GUNNER := Vector3(0.0, GALLERY_Y, 7.5)
const GALLERY_SOUTH := 6.0
## The bait stance: in the lane, with the receiver behind it.
const STANCE := Vector3(0.0, 0.0, -4.8)
## The receiver, and the height its plate has to sit at for a shot aimed
## at a standing player's chest to still be on the plate 2.2 m further
## south. Solved from the muzzle and the aim point, then measured.
const RECEIVER_Z := -7.0
const RECEIVER_Y := 0.85
## The alcove: one short step west of the stance, shielded from the north.
const ALCOVE := Vector3(-2.9, 0.0, -5.0)
const ALCOVE_X := Vector2(-4.8, -1.7)
const ALCOVE_Z := Vector2(-6.4, -4.2)

## The service shutter, in the east wall, and the annex behind it.
const SHUTTER_X := ROOM_HALF.x
const SHUTTER_Z := -2.0
const SHUTTER := Vector3(0.4, 2.6, 2.4)
## §2's "proposed eight-second interval". The window itself is the
## declared TIMER's `duration` (O05-07); `counterfire_driver` checks the
## two agree, so the room's statement and the contract cannot drift.
const OPEN_SECONDS := 8.0
const FLANK_Y := 3.0
const ANNEX_X := Vector2(ROOM_HALF.x, 17.5)
## The goal, on the flank beyond the release.
const GOAL := Vector3(16.4, FLANK_Y, 3.0)

const STEP_RISE := 0.25

var theme := "concrete_facility"
## `--blocked` is §11's counterpart: a real blocker between the muzzle
## and the receiver. Everything else about the room is identical.
var blocked := false
## Whether the room builds its own gunner (the scenario) or leaves it to
## the owner's encounter (a Zone).
var with_gunner := true
## The scenario's signs name it a development scenario; a hosted room
## does not say that about itself.
var development_signs := true

var receiver: ImpactReceiver = null
var shutter: ServiceShutter = null
## O05-07: THE ROOM'S CHAIN, RUN BY THE SHARED GRAPH. EX50-021 §3 names
## it -- "the receiver emits one pulse per valid hit", "the eight-second
## TIMER refreshes on another valid receiver hit. Its output opens the
## service shutter", and the manual release makes the route permanent --
## and the minor's occurrence contract declares it (`schemas/minors.py`,
## exported as `Constants.MINOR_SIGNAL_GRAPHS`):
##
##     receiver (SHOOTABLE_TARGET) -> TIMER (window, 8 s) --.
##                                                          OR -> shutter
##     release_lever (PULSE_BUTTON) -> LATCH (release) -----'
##
## The room binds its receiver, lever and shutter to the declaration's
## ids and keeps what is presentation: its lines, and the stair the
## release adds.
var graph: SignalGraph = null
var gunner: Enemy = null
var release: CallLever = null
var goal_plate: ActivityElement = null

## Pulled once and never withdrawn (§9): the service connection is
## permanently open and a fixed stair joins the flank to the arcade.
var released := false
var reached_goal := false
## The fixed stair the release adds, kept together so it can be counted.
var release_stair: Node3D = null
## H-COUNTERFIRE (PT-04): the room says what its machines do to each other.
## The conduit from the receiver to the shutter carries the window: it is
## lit while the window runs and for good once the release is thrown. The
## readout at the shutter says whether it is shut, how long it has, or
## that the release holds it.
var shutter_readout: Label3D = null
var _conduit_runs: Array[MeshInstance3D] = []
var _conduit_dark: Material = null
var _conduit_lit: Material = null
var _conduit_on := false

## What the release says once it is thrown (D-07's permanence, as a bolt).
const RELEASE_LABEL := "SERVICE RELEASE -- HOLDS THE SHUTTER OPEN"
const RELEASE_DONE := "RELEASE THROWN -- SHUTTER HELD OPEN, STAIR DOWN"
const TRIP_SIGN := "IMPACT TRIP\nA HIT ON ITS FACE OPENS\nTHE SERVICE SHUTTER FOR %d s"


func build() -> void:
	_floors()
	_lane()
	_the_receiver()
	_the_shutter()
	_the_annex()
	_the_graph()
	if with_gunner:
		_the_gunner()
	_signs()


## §9: "The permanent manual release is restored through its accepted
## state, not by replaying a projectile event." Nothing is announced.
func restore_release() -> void:
	if released:
		return
	if graph != null:
		graph.restore_latch("release")
		# ALREADY OPEN, not opening: a route the campaign's record says is
		# open is open when the room appears.
		graph.evaluate(true)
	_release(false)


## The TIMER's time left: how long the service shutter stays commanded
## open by the last valid hit. 0 when the window is shut.
func window_left() -> float:
	return graph.timer_left("window") if graph != null else 0.0


## Where the gunner's muzzle is, which is where a committed shot starts.
func muzzle() -> Vector3:
	return to_global(GUNNER + Vector3.UP * 1.2)


## Where a shot aimed at a standing body at `at` crosses the plate's
## plane. Arithmetic in the room's frame, and it is checked against a real
## projectile rather than trusted.
func shot_height_at_receiver(at: Vector3) -> float:
	var from := GUNNER + Vector3.UP * 1.2
	var aim := to_local(at) + Vector3.UP
	var span := aim - from
	if is_zero_approx(span.z):
		return to_global(from).y
	var t := (RECEIVER_Z - from.z) / span.z
	return to_global(Vector3(0.0, from.y + span.y * t, RECEIVER_Z)).y


# ---------------------------------------------------------------- build

func _floors() -> void:
	var floor_mat := ThemeMaterials.floor_mat(theme)
	# The arcade floor, from the south wall up to the gallery.
	_ground(-ROOM_HALF.x, ROOM_HALF.x, -ROOM_HALF.y, GALLERY_SOUTH,
			0.0, floor_mat)
	# The gunner's gallery, a metre up.
	_ground(-ROOM_HALF.x, ROOM_HALF.x, GALLERY_SOUTH, ROOM_HALF.y,
			GALLERY_Y, ThemeMaterials.trim_mat(theme))
	# THE WEST STAIR, and it is deliberately long and in the open. §6
	# calls the route it serves the conservative solution: ordinary
	# cover, ordinary combat, and a receiver face you can address
	# yourself once you are on the gunner's side.
	_stair(Vector3(-10.0, 0.0, 1.0), Vector3(-10.0, GALLERY_Y,
			GALLERY_SOUTH + 0.3), 2.4)
	# The gallery's parapet, on the flanks only. Nothing crosses the
	# lane: a committed shot that clipped its own cover would be a
	# different room.
	for span: Vector2 in [Vector2(-ROOM_HALF.x, -2.5),
			Vector2(2.5, ROOM_HALF.x)]:
		_slab(Vector3(span.y - span.x, 0.7, 0.35),
				Vector3((span.x + span.y) * 0.5, GALLERY_Y + 0.35,
					GALLERY_SOUTH), ThemeMaterials.wall_mat(theme))
	_walls()


func _walls() -> void:
	var mat := ThemeMaterials.wall_mat(theme)
	var mid := ROOM_HEIGHT * 0.5
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y * 2.0),
			Vector3(-ROOM_HALF.x, mid, 0.0), mat)
	_slab(Vector3(ROOM_HALF.x * 2.0, ROOM_HEIGHT, 0.5),
			Vector3(0.0, mid, ROOM_HALF.y), mat)
	_south_wall(mat)
	# THE EAST WALL IS IN THREE PIECES: the shutter's opening, and a low
	# section beside it so the upper flank actually overlooks the arcade
	# rather than opening onto a corridor with a view of plaster.
	var gap := Vector2(SHUTTER_Z - SHUTTER.z * 0.5,
			SHUTTER_Z + SHUTTER.z * 0.5)
	_slab(Vector3(0.5, ROOM_HEIGHT, gap.x + ROOM_HALF.y),
			Vector3(ROOM_HALF.x, mid, (gap.x - ROOM_HALF.y) * 0.5), mat)
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y - 2.0 - gap.y),
			Vector3(ROOM_HALF.x, mid, (gap.y + ROOM_HALF.y - 2.0) * 0.5),
			mat)
	# Above the doorway.
	_slab(Vector3(0.5, ROOM_HEIGHT - SHUTTER.y, SHUTTER.z),
			Vector3(ROOM_HALF.x, SHUTTER.y + (ROOM_HEIGHT - SHUTTER.y)
				* 0.5, SHUTTER_Z), mat)
	# The low section the flank looks over.
	_slab(Vector3(0.5, 2.6, 2.0), Vector3(ROOM_HALF.x, 1.3,
			ROOM_HALF.y - 1.0), mat)


## The arrival wall. Whole in the scenario, which spawns its player
## inside; a hosted room cuts its way in here.
func _south_wall(wall: Material) -> void:
	_slab(Vector3(ROOM_HALF.x * 2.0, ROOM_HEIGHT, 0.5),
			Vector3(0.0, ROOM_HEIGHT * 0.5, -ROOM_HALF.y), wall)


## The lane: flanking baffles, and the paint that says what it is.
func _lane() -> void:
	var mat := ThemeMaterials.wall_mat(theme)
	for z: float in [4.0, 1.0, -2.0]:
		for side: float in [-1.0, 1.0]:
			_slab(Vector3(0.3, 1.7, 1.6),
					Vector3((LANE_HALF + 0.2) * side, 0.85, z), mat)
	# THE ALCOVE, one short step west of the stance. Its north wall is
	# what makes it cover: it stands between the alcove and the gallery,
	# so a player inside it is out of the gunner's line rather than
	# merely out of the projectile's path.
	_slab(Vector3(ALCOVE_X.y - ALCOVE_X.x, 2.2, 0.4),
			Vector3((ALCOVE_X.x + ALCOVE_X.y) * 0.5, 1.1, ALCOVE_Z.y),
			mat)
	_slab(Vector3(0.4, 2.2, ALCOVE_Z.y - ALCOVE_Z.x),
			Vector3(ALCOVE_X.x, 1.1, (ALCOVE_Z.x + ALCOVE_Z.y) * 0.5),
			mat)
	# Facility paint down the lane. Architecture, not an instruction:
	# §11 warns that a stance marked "stand here now" turns the room into
	# a quick-time event, so nothing here says where to stand -- only that
	# this strip is the one the gunner covers.
	var stripe := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(0.5, 0.02, GALLERY_SOUTH - RECEIVER_Z)
	stripe.mesh = plane
	stripe.material_override = ThemeMaterials.hazard_mat(theme)
	add_child(stripe)
	stripe.position = Vector3(0.0, 0.01,
			(GALLERY_SOUTH + RECEIVER_Z) * 0.5)


func _the_receiver() -> void:
	# FACING NORTH: `ImpactReceiver`'s active face is local -Z, so half a
	# turn puts it up the lane and the hood on the arrival side.
	receiver = ImpactReceiver.create(PI, Color(1.0, 0.55, 0.3), theme)
	add_child(receiver)
	receiver.position = Vector3(0.0, RECEIVER_Y, RECEIVER_Z)
	# Its housing: a plinth under it, so the plate reads as mounted
	# equipment at the end of the lane rather than as a floating sign.
	_slab(Vector3(1.9, RECEIVER_Y - 0.7, 1.2),
			Vector3(0.0, (RECEIVER_Y - 0.7) * 0.5, RECEIVER_Z),
			ThemeMaterials.wall_mat(theme))
	# The conduit: the visible reason the shutter is the thing that
	# opens. §7 wants the relationship readable from the architecture.
	_conduit()
	# §11's counterpart, and the ONLY difference the flag makes: a real
	# blocker in the lane between the muzzle and the plate.
	# SOUTH OF THE STANCE, so it takes the shot and nothing else. A
	# blocker north of the stance would also break the gunner's line of
	# sight and the counterpart would fail because no shot was ever
	# fired -- which is a different claim, and a weaker one.
	if blocked:
		_slab(Vector3(LANE_HALF * 2.0, 2.4, 0.4),
				Vector3(0.0, 1.2, RECEIVER_Z + 1.2),
				ThemeMaterials.hazard_mat(theme))


func _conduit() -> void:
	var mat := ThemeMaterials.accent_mat(theme)
	_conduit_dark = mat
	_conduit_lit = ThemeMaterials.glow_material(Color(1.0, 0.55, 0.3), 2.2)
	var run := MeshInstance3D.new()
	run.name = "ConduitRun"
	var box := BoxMesh.new()
	box.size = Vector3(ROOM_HALF.x, 0.16, 0.16)
	run.mesh = box
	run.material_override = mat
	add_child(run)
	run.position = Vector3(ROOM_HALF.x * 0.5, 0.12, RECEIVER_Z + 0.9)
	var rise := MeshInstance3D.new()
	rise.name = "ConduitRise"
	var up := BoxMesh.new()
	up.size = Vector3(0.16, 0.16, absf(SHUTTER_Z - RECEIVER_Z - 0.9))
	rise.mesh = up
	rise.material_override = mat
	add_child(rise)
	rise.position = Vector3(ROOM_HALF.x - 0.4, 0.12,
			(SHUTTER_Z + RECEIVER_Z + 0.9) * 0.5)
	_conduit_runs = [run, rise]


## The conduit and the readout follow the machine every frame: what the
## window is doing is shown where the player is looking, not only by the
## panel it moves.
func _physics_process(_delta: float) -> void:
	var on := released or window_left() > 0.0
	if on != _conduit_on:
		_conduit_on = on
		for run: MeshInstance3D in _conduit_runs:
			run.material_override = _conduit_lit if on else _conduit_dark
	if shutter_readout != null:
		var text := "SERVICE SHUTTER\nSHUT"
		if released:
			text = "SERVICE SHUTTER\nHELD OPEN BY THE RELEASE"
		elif window_left() > 0.0:
			text = "SERVICE SHUTTER\nOPEN · %d s" % ceili(window_left())
		elif shutter != null and not shutter.is_shut():
			text = "SERVICE SHUTTER\nCLOSING"
		if shutter_readout.text != text:
			shutter_readout.text = text


func _the_shutter() -> void:
	shutter = ServiceShutter.create(
			Vector3(SHUTTER_X, SHUTTER.y * 0.5, SHUTTER_Z),
			SHUTTER, SHUTTER.y, theme)
	add_child(shutter)
	shutter.opened.connect(func() -> void: said.emit("SERVICE SHUTTER OPEN"))
	shutter.closed.connect(func() -> void: said.emit(""))


## Behind the shutter: a short supported route to the upper flank, the
## manual release, and the goal beyond it.
func _the_annex() -> void:
	var trim := ThemeMaterials.trim_mat(theme)
	_ground(ANNEX_X.x, ANNEX_X.y, -4.5, 0.5, 0.0, trim)
	# NORTH OF THE ANNEX, ONE UPPER DECK ON A SOLID MASS (PPT-05, PPT-06).
	# Below the flank and its reach there was only a pocket: floorless in
	# the scenario, floored but open in a hosted room. A player who walked
	# on under the flank, or stepped off its 1.7 m edge, fell out of the
	# world; floored, it was somewhere to double-jump from and claim the
	# Check over the flank's edge. Now it is solid to the flank's height,
	# decked over: the upper level is 5.5 m wide, the Check does not block
	# it, and there is nowhere below it to stand.
	_ground(ANNEX_X.x, 15.6, 0.5, ROOM_HALF.y - 3.0, FLANK_Y, trim)
	_slab(Vector3(ANNEX_X.y - ANNEX_X.x, FLANK_Y - SLAB,
			ROOM_HALF.y - 1.0 - 0.5),
			Vector3((ANNEX_X.x + ANNEX_X.y) * 0.5, (FLANK_Y - SLAB) * 0.5,
				(0.5 + ROOM_HALF.y - 1.0) * 0.5),
			ThemeMaterials.wall_mat(theme))
	_stair(Vector3(13.2, 0.0, -2.0), Vector3(15.6, FLANK_Y, -2.0), 2.2)
	_ground(15.6, ANNEX_X.y, -4.5, ROOM_HALF.y - 1.0, FLANK_Y, trim)
	# The flank's own floor reaches back west over the low wall, so the
	# arcade really is overlooked from it.
	_ground(ROOM_HALF.x - 0.4, 15.6, ROOM_HALF.y - 3.0,
			ROOM_HALF.y - 1.0, FLANK_Y, trim)
	for side: float in [-4.5, ROOM_HALF.y - 1.0]:
		_slab(Vector3(ANNEX_X.y - 15.6, ROOM_HEIGHT, 0.4),
				Vector3((15.6 + ANNEX_X.y) * 0.5, ROOM_HEIGHT * 0.5, side),
				ThemeMaterials.wall_mat(theme))
	_annex_east_wall(ThemeMaterials.wall_mat(theme))
	# THE CORNER NORTH OF THE ANNEX IS SOLID (PPT-05). The low wall the
	# flank overlooks stood beside a strip with nothing under it: from its
	# top, a 0.4 m step down off the flank's reach, a step east fell out of
	# the world. `godot-counterfire-hosted`'s void census holds it.
	_slab(Vector3(ANNEX_X.y - ROOM_HALF.x, ROOM_HEIGHT,
			ROOM_HALF.y + 0.25 - (ROOM_HALF.y - 0.8)),
			Vector3((ROOM_HALF.x + ANNEX_X.y) * 0.5, ROOM_HEIGHT * 0.5,
				(ROOM_HALF.y + 0.25 + ROOM_HALF.y - 0.8) * 0.5),
			ThemeMaterials.wall_mat(theme))
	release = CallLever.make(RELEASE_LABEL, Color(0.55, 1.0, 0.7),
			theme)
	# A PERMANENT ROUTE IS MADE WITH A CONTROL THAT STAYS MADE (D-07): once
	# its LATCH is set the release stays thrown and says so -- restored
	# saves included (`SignalGraph.lock_permanent_levers`).
	release.locks_with = "release"
	release.done_label = RELEASE_DONE
	add_child(release)
	release.position = Vector3(16.4, FLANK_Y + CallLever.BASE.y * 0.5, -1.0)
	goal_plate = ActivityElement.create(ActivityElement.STAND, 0,
			ActivityElement.PLATE_SIZE, Color(0.55, 1.0, 0.7))
	add_child(goal_plate)
	goal_plate.position = GOAL
	goal_plate.triggered.connect(func(_w: ActivityElement) -> void:
		reached_goal = true
		said.emit("GOAL REACHED"))


## The annex's far wall, whole in the scenario; a hosted room cuts its
## way on through it at the flank's height.
func _annex_east_wall(wall: Material) -> void:
	_slab(Vector3(0.4, ROOM_HEIGHT, ROOM_HALF.y + 3.5),
			Vector3(ANNEX_X.y, ROOM_HEIGHT * 0.5,
				(ROOM_HALF.y - 5.5) * 0.5), wall)


## The declared chain, bound to this room's machines by the declaration's
## own ids. The receiver's pulses and the TIMER's window are the graph's;
## the release is its LATCH.
func _the_graph() -> void:
	graph = SignalGraph.bind_declared(Constants.MINOR_SIGNAL_GRAPHS.get(
			"minor_counterfire_arcade", {}),
			{"receiver": receiver, "release_lever": release,
				"shutter": shutter},
			"counterfire arcade")
	add_child(graph)
	graph.fired.connect(_on_fired)
	graph.start()


func _on_fired(_package: String, node_id: String) -> void:
	if node_id == "release" and not released:
		_release(true)


## §9: "the service route remains open after its accepted release."
##
## Two consequences, and both are permanent. The LATCH holds the shutter
## open through the OR whatever the window does -- that is the graph's --
## and a fixed stair joins the flank to the arcade so the way back does
## not need another baited shot, which is this.
func _release(announce: bool) -> void:
	released = true
	var before := get_child_count()
	_stair(Vector3(ROOM_HALF.x - 3.0, 0.0, ROOM_HALF.y - 2.0),
			Vector3(ROOM_HALF.x - 0.6, FLANK_Y, ROOM_HALF.y - 2.0), 1.8)
	release_stair = Node3D.new()
	release_stair.name = "ReleaseStair"
	var steps: Array[Node] = []
	for i in range(before, get_child_count()):
		steps.append(get_child(i))
	add_child(release_stair)
	for step: Node in steps:
		var at := (step as Node3D).transform
		remove_child(step)
		release_stair.add_child(step)
		(step as Node3D).transform = at
	if announce:
		said.emit("SERVICE CONNECTION PERMANENT")
		release_engaged.emit()


## How many treads the release's stair has; 0 before the release.
func release_stair_steps() -> int:
	return 0 if release_stair == null else release_stair.get_child_count()


func _the_gunner() -> void:
	gunner = Enemy.create("ranged", theme)
	add_child(gunner)
	gunner.position = GUNNER


func _signs() -> void:
	_sign("ARRIVAL ARCADE", Vector3(0.0, 2.2, -ROOM_HALF.y + 1.0),
			Color(0.8, 0.85, 0.95), 46)
	# WHAT THE TARGET DOES, not how to make it happen (D12: "without
	# printing the answer on entry"). It was "EMERGENCY IMPACT TRIP",
	# which read as an unrelated emergency control (PT-04).
	_sign(TRIP_SIGN % int(OPEN_SECONDS),
			Vector3(0.0, 2.2, RECEIVER_Z - 0.9), Color(1.0, 0.55, 0.3), 34)
	shutter_readout = _sign("SERVICE SHUTTER\nSHUT",
			Vector3(ROOM_HALF.x - 1.6, 3.2, SHUTTER_Z),
			Color(0.55, 1.0, 0.7), 34)
	shutter_readout.name = "ShutterReadout"
	_sign("GALLERY", Vector3(-6.0, GALLERY_Y + 2.2, GALLERY_SOUTH + 1.2),
			Color(0.8, 0.85, 0.95), 38)
	if development_signs:
		_sign("EX50-021 -- development scenario, not a Zone",
				Vector3(0.0, 1.2, -ROOM_HALF.y + 1.0),
				Color(0.75, 0.7, 0.55), 28)


# ---------------------------------------------------------------- parts

func _ground(x0: float, x1: float, z0: float, z1: float,
		top: float, material: Material) -> StaticBody3D:
	if x1 - x0 <= 0.01 or z1 - z0 <= 0.01:
		return null
	return _slab(Vector3(x1 - x0, SLAB, z1 - z0),
			Vector3((x0 + x1) * 0.5, top - SLAB * 0.5, (z0 + z1) * 0.5),
			material)


func _slab(size: Vector3, centre: Vector3,
		material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	body.add_child(mesh_node)
	add_child(body)
	body.position = centre
	return body


func _stair(foot: Vector3, head: Vector3, width: float) -> void:
	var rise := head.y - foot.y
	var run := Vector3(head.x - foot.x, 0.0, head.z - foot.z)
	if rise <= 0.01 or run.length() < 0.01:
		return
	var steps := maxi(int(ceil(rise / STEP_RISE)), 1)
	var out := run.normalized()
	var tread := run.length() / float(steps)
	var material := ThemeMaterials.trim_mat(theme)
	for i in steps:
		var height := float(i + 1) * rise / float(steps)
		var here := foot + out * (tread * (float(i) + 0.5)) \
				+ Vector3(0.0, height * 0.5, 0.0)
		var step := _slab(Vector3(width, height, tread), here, material)
		step.basis = Basis.looking_at(-out, Vector3.UP)


func _sign(text: String, where: Vector3, tint: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	add_child(label)
	label.position = where
	return label
