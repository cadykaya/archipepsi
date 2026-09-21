class_name CounterfireArcade
extends Node3D
## EX50-021 COUNTERFIRE ARCADE, PLAYABLE (`--counterfire`).
## **Development scaffolding, and a minor situation, not a Zone.**
##
## **What the room asks.** An emergency impact trip stands at the south
## end of a long firing lane, hooded against the side you arrive from.
## A gunner covers the lane from the north gallery. Stand in the lane,
## let it commit a shot, and step aside: the projectile carries on down
## the lane you vacated and trips the receiver, which opens a service
## shutter for eight seconds.
##
## **Nothing here recognises "baited".** There is no enemy state, no
## scripted miss and no quick-time prompt. The gunner aims at a visible
## player with its ordinary attack; the projectile's direction is fixed
## at the muzzle; the receiver is operated by a real impact on a real
## plate. The player's contribution is entirely where they were standing
## and where they went.
##
## **And the ordinary route is not a consolation prize.** The west stair
## reaches the gallery through open ground, and from the gunner's side
## the receiver's face is addressable by an ordinary Static Pulse. §6
## requires that: killing the gunner must never remove the only way to
## finish the room. What the bait buys is not access, it is not having to
## stand in the firing line with your back to the gunner.
##
## **The specification is `docs/design-library/EX50_entries/EX50-021.md`
## and it is paper.** Its projectile speed, its eight seconds and its
## encounter layout are proposals. §11's "actual fairness of the bait
## remains unverified" is still true after this file: what
## `godot-counterfire` measures is that the relationship works, not that
## it is fun.
##
## **What this is NOT.** Not composed, no Checks, no exit, no campaign,
## no save, no bridge connection. An operator asks for it by name or it
## does not exist.

## §2: 24 by 18 m.
const ROOM_HALF := Vector2(12.0, 9.0)
const ROOM_HEIGHT := 8.0
const THEME := "concrete_facility"
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
const OPEN_SECONDS := 8.0
const FLANK_Y := 3.0
const ANNEX_X := Vector2(ROOM_HALF.x, 17.5)

const STEP_RISE := 0.25

var receiver: ImpactReceiver = null
var shutter: ServiceShutter = null
var gunner: Enemy = null
var release: CallLever = null
var goal_plate: ActivityElement = null
var player: Player = null
var hud: Hud = null

## Pulled once and never withdrawn (§9): the service connection is
## permanently open and a fixed stair joins the flank to the arcade.
var released := false
var reached_goal := false
## `--blocked` is §11's counterpart: a real blocker between the muzzle
## and the receiver. Everything else about the room is identical.
var blocked := false

var _world: Node3D = null
var _readout: Label3D = null


func _ready() -> void:
	name = "CounterfireArcade"
	_environment()
	_world = Node3D.new()
	_world.name = "Arcade"
	add_child(_world)
	_floors()
	_lane()
	_the_receiver()
	_the_shutter()
	_the_annex()
	_the_gunner()
	_signs()
	_spawn_player()
	_hud()


func _environment() -> void:
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(THEME)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = ThemeMaterials.void_color(THEME).lightened(0.1)
	env.fog_density = 0.005
	holder.environment = env
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-20.0), 0.0)
	sun.light_energy = 0.9
	add_child(sun)


func _floors() -> void:
	var floor_mat := ThemeMaterials.floor_mat(THEME)
	# The arcade floor, from the south wall up to the gallery.
	_ground(-ROOM_HALF.x, ROOM_HALF.x, -ROOM_HALF.y, GALLERY_SOUTH,
			0.0, floor_mat)
	# The gunner's gallery, a metre up.
	_ground(-ROOM_HALF.x, ROOM_HALF.x, GALLERY_SOUTH, ROOM_HALF.y,
			GALLERY_Y, ThemeMaterials.trim_mat(THEME))
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
					GALLERY_SOUTH), ThemeMaterials.wall_mat(THEME))
	_walls()


func _walls() -> void:
	var mat := ThemeMaterials.wall_mat(THEME)
	var mid := ROOM_HEIGHT * 0.5
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y * 2.0),
			Vector3(-ROOM_HALF.x, mid, 0.0), mat)
	for side: float in [-1.0, 1.0]:
		_slab(Vector3(ROOM_HALF.x * 2.0, ROOM_HEIGHT, 0.5),
				Vector3(0.0, mid, ROOM_HALF.y * side), mat)
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


## The lane: flanking baffles, and the paint that says what it is.
func _lane() -> void:
	var mat := ThemeMaterials.wall_mat(THEME)
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
	# a quick-time event, so nothing here says where to stand — only that
	# this strip is the one the gunner covers.
	var stripe := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(0.5, 0.02, GALLERY_SOUTH - RECEIVER_Z)
	stripe.mesh = plane
	stripe.material_override = ThemeMaterials.hazard_mat(THEME)
	_world.add_child(stripe)
	stripe.global_position = Vector3(0.0, 0.01,
			(GALLERY_SOUTH + RECEIVER_Z) * 0.5)


func _the_receiver() -> void:
	# FACING NORTH: `ImpactReceiver`'s active face is local -Z, so half a
	# turn puts it up the lane and the hood on the arrival side.
	receiver = ImpactReceiver.create(PI, Color(1.0, 0.55, 0.3), THEME)
	_world.add_child(receiver)
	receiver.global_position = Vector3(0.0, RECEIVER_Y, RECEIVER_Z)
	receiver.struck.connect(_on_struck)
	# Its housing: a plinth under it, so the plate reads as mounted
	# equipment at the end of the lane rather than as a floating sign.
	_slab(Vector3(1.9, RECEIVER_Y - 0.7, 1.2),
			Vector3(0.0, (RECEIVER_Y - 0.7) * 0.5, RECEIVER_Z),
			ThemeMaterials.wall_mat(THEME))
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
				ThemeMaterials.hazard_mat(THEME))


func _conduit() -> void:
	var mat := ThemeMaterials.accent_mat(THEME)
	var run := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ROOM_HALF.x, 0.16, 0.16)
	run.mesh = box
	run.material_override = mat
	_world.add_child(run)
	run.global_position = Vector3(ROOM_HALF.x * 0.5, 0.12, RECEIVER_Z + 0.9)
	var rise := MeshInstance3D.new()
	var up := BoxMesh.new()
	up.size = Vector3(0.16, 0.16, absf(SHUTTER_Z - RECEIVER_Z - 0.9))
	rise.mesh = up
	rise.material_override = mat
	_world.add_child(rise)
	rise.global_position = Vector3(ROOM_HALF.x - 0.4, 0.12,
			(SHUTTER_Z + RECEIVER_Z + 0.9) * 0.5)


func _the_shutter() -> void:
	shutter = ServiceShutter.create(
			Vector3(SHUTTER_X, SHUTTER.y * 0.5, SHUTTER_Z),
			SHUTTER, SHUTTER.y, OPEN_SECONDS, THEME)
	_world.add_child(shutter)
	shutter.opened.connect(func() -> void: _say("SERVICE SHUTTER OPEN"))
	shutter.closed.connect(func() -> void: _say(""))


## Behind the shutter: a short supported route to the upper flank, the
## manual release, and the goal beyond it.
func _the_annex() -> void:
	var trim := ThemeMaterials.trim_mat(THEME)
	_ground(ANNEX_X.x, ANNEX_X.y, -4.5, 0.5, 0.0, trim)
	_stair(Vector3(13.2, 0.0, -2.0), Vector3(15.6, FLANK_Y, -2.0), 2.2)
	_ground(15.6, ANNEX_X.y, -4.5, ROOM_HALF.y - 1.0, FLANK_Y, trim)
	# The flank's own floor reaches back west over the low wall, so the
	# arcade really is overlooked from it.
	_ground(ROOM_HALF.x - 0.4, 15.6, ROOM_HALF.y - 3.0,
			ROOM_HALF.y - 1.0, FLANK_Y, trim)
	for side: float in [-4.5, ROOM_HALF.y - 1.0]:
		_slab(Vector3(ANNEX_X.y - 15.6, ROOM_HEIGHT, 0.4),
				Vector3((15.6 + ANNEX_X.y) * 0.5, ROOM_HEIGHT * 0.5, side),
				ThemeMaterials.wall_mat(THEME))
	_slab(Vector3(0.4, ROOM_HEIGHT, ROOM_HALF.y + 3.5),
			Vector3(ANNEX_X.y, ROOM_HEIGHT * 0.5,
				(ROOM_HALF.y - 5.5) * 0.5), ThemeMaterials.wall_mat(THEME))
	release = CallLever.make("SERVICE RELEASE", Color(0.55, 1.0, 0.7),
			THEME)
	_world.add_child(release)
	release.global_position = Vector3(16.4, FLANK_Y
			+ CallLever.BASE.y * 0.5, -1.0)
	release.pulled.connect(_on_release)
	goal_plate = ActivityElement.create(ActivityElement.STAND, 0,
			ActivityElement.PLATE_SIZE, Color(0.55, 1.0, 0.7))
	_world.add_child(goal_plate)
	goal_plate.global_position = Vector3(16.4, FLANK_Y, 3.0)
	goal_plate.triggered.connect(func(_w: ActivityElement) -> void:
		reached_goal = true
		_say("GOAL REACHED"))


## §9: "the service route remains open after its accepted release."
##
## Two consequences, and both are permanent. The shutter stops being on
## a timer, and a fixed stair joins the flank to the arcade so the way
## back does not need another baited shot.
func _on_release(_who: CallLever) -> void:
	if released:
		return
	released = true
	shutter.open_seconds = INF
	shutter.trip()
	_stair(Vector3(ROOM_HALF.x - 3.0, 0.0, ROOM_HALF.y - 2.0),
			Vector3(ROOM_HALF.x - 0.6, FLANK_Y, ROOM_HALF.y - 2.0), 1.8)
	_say("SERVICE CONNECTION PERMANENT")


func _the_gunner() -> void:
	gunner = Enemy.create("ranged", THEME)
	_world.add_child(gunner)
	gunner.global_position = GUNNER


func _on_struck(_from: Vector3) -> void:
	shutter.trip()


func _say(text: String) -> void:
	if _readout != null:
		_readout.text = text


func _signs() -> void:
	_sign("ARRIVAL ARCADE", Vector3(0.0, 2.2, -ROOM_HALF.y + 1.0),
			Color(0.8, 0.85, 0.95), 46)
	_sign("EMERGENCY IMPACT TRIP\nSERVICE SHUTTER",
			Vector3(0.0, 2.2, RECEIVER_Z - 0.9), Color(1.0, 0.55, 0.3), 34)
	_sign("SERVICE ROUTE", Vector3(ROOM_HALF.x - 1.6, 3.2, SHUTTER_Z),
			Color(0.55, 1.0, 0.7), 34)
	_sign("GALLERY", Vector3(-6.0, GALLERY_Y + 2.2, GALLERY_SOUTH + 1.2),
			Color(0.8, 0.85, 0.95), 38)
	_sign("EX50-021 -- development scenario, not a Zone",
			Vector3(0.0, 1.2, -ROOM_HALF.y + 1.0),
			Color(0.75, 0.7, 0.55), 28)
	_readout = _sign("", Vector3(0.0, 2.8, -ROOM_HALF.y + 1.0),
			Color(0.7, 1.0, 0.8), 34)


func _spawn_player() -> void:
	player = Player.create()
	add_child(player)
	player.set_spawn(Transform3D(Basis(Vector3.UP, 0.0),
			Vector3(3.0, 1.2, -ROOM_HALF.y + 1.4)))
	player.velocity = Vector3.ZERO
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.bind_player(player)
	hud.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


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
	_world.add_child(body)
	body.global_position = centre
	return body


func _stair(foot: Vector3, head: Vector3, width: float) -> void:
	var rise := head.y - foot.y
	var run := Vector3(head.x - foot.x, 0.0, head.z - foot.z)
	if rise <= 0.01 or run.length() < 0.01:
		return
	var steps := maxi(int(ceil(rise / STEP_RISE)), 1)
	var out := run.normalized()
	var tread := run.length() / float(steps)
	var material := ThemeMaterials.trim_mat(THEME)
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
	_world.add_child(label)
	label.global_position = where
	return label


# ------------------------------------------------------- what it knows

## Where the gunner's muzzle is, which is where a committed shot starts.
func muzzle() -> Vector3:
	return GUNNER + Vector3.UP * 1.2


## Where a shot aimed at a standing body at `at` crosses the plate's
## plane. Arithmetic, and it is checked against a real projectile rather
## than trusted.
func shot_height_at_receiver(at: Vector3) -> float:
	var from := muzzle()
	var aim := at + Vector3.UP
	var span := aim - from
	if is_zero_approx(span.z):
		return from.y
	var t := (RECEIVER_Z - from.z) / span.z
	return from.y + span.y * t
