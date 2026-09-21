class_name RailwayScenario
extends Node3D
## THE RAILWAY, PLAYABLE (`--railway`). **Development scaffolding.**
##
## **What this is.** Everything M1 built, in a place a person can stand:
## board the skiff at S1, shoot FORWARD, ride to S2, find S2 to S3
## refused for want of track, climb the gantry, pull the alignment lever,
## watch the span swing home and lock, ride to S3. The plan calls M1
## "independently playable" and until this existed nothing let anyone
## walk into it.
##
## **What this is NOT, and the distinction is load bearing.** This is not
## a Zone. It is not composed, it carries no Checks, no exit and no
## Archipelago logic, nothing here is multiworld-safe, and no campaign is
## touched: it runs before `boot()` and never opens a bridge connection.
## It exists for the same reason `ShowcaseZone` does and under the same
## rule -- **it runs only when an operator asks for it by name, and
## nothing can arrive here by accident.**
##
## **Why the gantry has stairs.** The approved configuration reaches the
## alignment control by GRAPPLE, from an acquisition branch that grants
## the Echo. That branch is M2 and does not exist. Stairs are a
## placeholder for it and are labelled as one in the scenario itself,
## because a scenario that quietly walked the player up to a control the
## design says is grappled to would be misrepresenting the design it
## exists to show.

## Where the rail sits above the yard floor, and the deck's thickness.
## The dock platforms are built to `RAIL_Y + DECK.y` so stepping aboard
## is a step onto a level surface rather than a hop.
const RAIL_Y := 0.6
const DECK := Vector3(4.0, 0.4, 4.0)
## How far to the side of the track a dock platform stands. Its inner
## edge meets the deck's outer edge exactly.
const DOCK_OUT := 4.0
const DOCK := Vector3(4.0, 0.4, 7.0)
## The gantry's deck. Out of reach on purpose -- a standing jump tops
## out at 1.33 m and there is no mantle -- and close enough to the dock
## that a 14 m/s pull, which is the number the schema's own example
## authors, actually carries a body onto it. Both halves were measured
## rather than chosen: at 4.6 m and ten metres out, the pull peaked 2.7 m
## up and the player landed back where they started.
const GANTRY_Y := 3.1
## How far the gantry stands from the track, measured like the docks.
const GANTRY_OUT := 7.5
## How far out the acquisition branch runs from the S2 junction.
const BRANCH_OUT := 20.0
## The plate the hookshot bites, above the gantry's INNER lip: a pull
## aimed at the middle of the deck arcs over it, and one aimed at the
## near edge lands on it.
const GANTRY_PLATE_Y := 7.2
const STEP_RISE := 0.25
const STEP_TREAD := 0.55
const THEME := "concrete_facility"

var rail: RailPath = null
var carrier: RailCarrier = null
var controls: RailControls = null
var junction: RailJunction = null
var span: RailSpan = null
var lever: AlignmentControl = null
var grant: EchoGrant = null
## The plate above the gantry that the hookshot bites.
var grapple_plate: StaticBody3D = null
var player: Player = null
var dock_offsets := PackedFloat32Array()

var _span_sign: Label3D = null
var _refusal_sign: Label3D = null
var _refusal_left := 0.0


func _ready() -> void:
	name = "RailwayScenario"
	_environment()
	rail = RailPath.from_points(PackedVector3Array([
		Vector3(0, RAIL_Y, 0),
		Vector3(16, RAIL_Y, 0),
		Vector3(24, RAIL_Y, 6),
		# THE STRAIGHT THE SPAN BRIDGES. Catmull-Rom takes its tangent at
		# a control point from that point's NEIGHBOURS, so the leg after
		# a corner bows unless a point past the corner squares it up.
		# Three collinear points do that, and the span then covers track
		# that really is straight.
		Vector3(24, RAIL_Y, 12),
		Vector3(24, RAIL_Y, 26),
	]))
	# S2 sits PAST the corner, so the gap it looks across is straight and
	# a straight span can bridge it.
	dock_offsets = PackedFloat32Array([
		0.0,
		rail.nearest_offset(Vector3(24, RAIL_Y, 12)),
		rail.length(),
	])
	_yard()
	_track()
	# THE CARRIER BEFORE THE DOCKS: the docks hang their shootable
	# controls on `controls`, so the station has to exist first.
	_carrier()
	_docks()
	_gantry()
	_branch()
	_spawn_player()
	_legend()


## Ground, sky and light. Lifted from `ZoneBuilder`'s own recipe rather
## than invented, so the scenario looks like the game it is part of.
func _environment() -> void:
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(THEME)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = ThemeMaterials.void_color(THEME).lightened(0.1)
	env.fog_density = 0.006
	holder.environment = env
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	sun.light_energy = 0.9
	add_child(sun)


func _yard() -> void:
	_slab(Vector3(90.0, 1.0, 90.0), Vector3(14.0, -0.5, 12.0),
		ThemeMaterials.floor_mat(THEME))


## The visible track, laid where the ride actually goes.
##
## THE SHAPE COMES FROM THE ONE SWEEPER. `AffordanceFeatures.rail_sweep_points`
## is what `build_rail` uses, so the beam under the carrier follows the
## same curve the carrier follows -- which is the repair P2b landed, and
## on this bent route the difference is 0.74 m. What is NOT reused is
## `build_rail` itself: its ride volumes are the grind affordance, and a
## low-friction lane at ankle height across a yard people walk around in
## is a different thing from a rail a vehicle runs on.
func _track() -> void:
	var points := AffordanceFeatures.rail_sweep_points(rail)
	var beam := ThemeMaterials.trim_mat(THEME)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		# THE GAP IS REAL. Nothing is laid across the link the span
		# covers, so "there is no track there" is something the player
		# sees before anything refuses them.
		var along := rail.nearest_offset((a + b) * 0.5)
		if along > dock_offsets[1] + 1.0 and along < dock_offsets[2] - 1.0:
			continue
		var piece := _slab(Vector3(0.5, 0.35, a.distance_to(b)),
			(a + b) * 0.5, beam)
		var run := b - a
		if run.length() > 0.001:
			piece.basis = Basis.looking_at(-run.normalized(), Vector3.UP)


func _docks() -> void:
	var names := ["S1", "S2", "S3"]
	var top := RAIL_Y + DECK.y
	for i in dock_offsets.size():
		var where := rail.at(dock_offsets[i])
		var along := rail.tangent(dock_offsets[i])
		var side := Vector3.UP.cross(along).normalized()
		var centre := where + side * DOCK_OUT \
			+ Vector3(0.0, top - RAIL_Y - DOCK.y * 0.5, 0.0)
		var pad := _slab(DOCK, centre, ThemeMaterials.wall_mat(THEME))
		pad.basis = Basis.looking_at(-along, Vector3.UP)
		# Up from the yard onto the platform, on the side away
		# from the track: steps must not stand where the deck goes.
		var lip := centre + side * (DOCK.x * 0.5) \
				+ Vector3(0.0, DOCK.y * 0.5, 0.0)
		_stair(lip + side * 2.0 - Vector3(0.0, top, 0.0), lip, 3.0)
		_sign(names[i], where + side * DOCK_OUT + Vector3(0, top + 3.2, 0),
			Color(0.75, 0.9, 1.0), 96)
		# BOTH DIRECTIONS AT EVERY DOCK. Which of them the railway can
		# honour is the railway's answer to give, out loud, and not
		# something to hide by leaving a control off a platform.
		for direction: int in [RailCarrier.FORWARD, RailCarrier.BACK]:
			_receiver(i, direction, where, along, side, top)


## One shootable control, on a post at the platform's inner edge.
func _receiver(dock: int, direction: int, where: Vector3, along: Vector3,
		side: Vector3, top: float) -> void:
	var lateral := 2.6
	var down_track := 1.9 * float(direction)
	var head := where + side * lateral + along * down_track \
		+ Vector3(0.0, top + 1.5, 0.0)
	_slab(Vector3(0.16, top + 1.5, 0.16),
		Vector3(head.x, (top + 1.5) * 0.5, head.z),
		ThemeMaterials.glow_material(ActivityElement.HARDWARE, 0.0))
	# The plate looks ACROSS the track at the platform it is shot from;
	# the arrow points along the track. Two different questions, which
	# is why `face_yaw` exists.
	var made := RailReceiver.create(direction, dock * 2 + (
		0 if direction == RailCarrier.FORWARD else 1),
		Color(0.55, 0.9, 0.7) if direction == RailCarrier.FORWARD
			else Color(1.0, 0.72, 0.45), PI * 0.5)
	add_child(made)
	made.global_position = head
	made.basis = Basis.looking_at(-along, Vector3.UP)
	controls.add(made)


func _carrier() -> void:
	carrier = RailCarrier.create(rail, dock_offsets,
		PackedStringArray(["S1", "S2", "S3"]), [true, false], DECK, THEME)
	add_child(carrier)
	controls = RailControls.create(carrier)
	add_child(controls)
	junction = RailJunction.create(carrier, "yard_junction")
	add_child(junction)
	# THE SPAN, pivoting at the S2 end of the gap it bridges. The parent
	# carries the aim along the track; the span's own yaw is the swing,
	# which is why it needs a frame of its own to swing inside.
	var pivot := Node3D.new()
	pivot.name = "SpanPivot"
	add_child(pivot)
	pivot.global_position = rail.at(dock_offsets[1])
	pivot.basis = Basis.looking_at(-rail.tangent(dock_offsets[1]),
		Vector3.UP)
	span = RailSpan.create("span_aligned", 1,
		dock_offsets[2] - dock_offsets[1], THEME)
	pivot.add_child(span)
	junction.add(span, null)
	controls.refused.connect(_on_refused)
	junction.commissioned.connect(_on_commissioned)


func _gantry() -> void:
	var where := rail.at(dock_offsets[1])
	var along := rail.tangent(dock_offsets[1])
	var side := Vector3.UP.cross(along).normalized()
	var top := RAIL_Y + DECK.y
	var deck_centre := where + side * GANTRY_OUT \
		+ Vector3(0.0, GANTRY_Y, 0.0)
	var platform := _slab(Vector3(4.0, 0.4, 4.0), deck_centre,
		ThemeMaterials.wall_mat(THEME))
	platform.basis = Basis.looking_at(-along, Vector3.UP)
	# NO STAIRS. The approved configuration reaches this control by
	# GRAPPLE, and the owner's direction is explicit: do not add a
	# guaranteed ordinary walking bypass to avoid the acquisition
	# work. An earlier cut of this scenario had a flight of steps
	# here as a placeholder, and a placeholder that lets you skip
	# the loop is not a placeholder for the loop.
	# ABOVE THE DECK'S INNER LIP, and the height is ballistics rather
	# than taste. A 14 m/s pull under this gravity tops out 4.45 m
	# above where it started, so a deck 3.8 m up was at the edge of
	# the envelope and the player clipped its underside on the way.
	grapple_plate = _anchor(deck_centre - side * 2.0,
			GANTRY_PLATE_Y - deck_centre.y, 0.0, Vector3.ZERO)
	# Something holding it up: a platform floating on nothing
	# reads as an unfinished scene rather than as a gantry.
	_slab(Vector3(0.6, GANTRY_Y, 0.6),
			Vector3(deck_centre.x, GANTRY_Y * 0.5, deck_centre.z),
			ThemeMaterials.trim_mat(THEME))
	lever = AlignmentControl.create("ALIGN THE SPAN", THEME)
	add_child(lever)
	lever.global_position = deck_centre \
		+ Vector3(0.0, 0.4 * 0.5 + AlignmentControl.BASE.y * 0.5, 0.0)
	lever.look_at(Vector3(where.x, lever.global_position.y, where.z),
		Vector3.UP)
	lever.operated.connect(func(_c: AlignmentControl) -> void: span.begin())
	_sign("ALIGNMENT GANTRY", deck_centre + Vector3(0, 3.0, 0),
		Color(1.0, 0.85, 0.5), 64)
	_sign("(stairs stand in for the grapple: the\n"
		+ "acquisition branch that grants it is M2)",
		deck_centre + Vector3(0, 2.1, 0), Color(0.7, 0.7, 0.75), 28)
	_span_sign = _sign("SPAN: STOWED  --  NO TRACK BEYOND S2",
		rail.at((dock_offsets[1] + dock_offsets[2]) * 0.5)
			+ Vector3(0, 3.4, 0), Color(1.0, 0.6, 0.45), 48)
	_refusal_sign = _sign("", where + side * DOCK_OUT
		+ Vector3(0, RAIL_Y + DECK.y + 2.2, 0), Color(1.0, 0.7, 0.55), 40)


func _spawn_player() -> void:
	player = Player.create()
	add_child(player)
	var start := rail.at(dock_offsets[0])
	var along := rail.tangent(dock_offsets[0])
	var side := Vector3.UP.cross(along).normalized()
	player.global_position = start + side * DOCK_OUT \
		+ Vector3(0.0, RAIL_Y + DECK.y + 1.2, 0.0)
	player.rotation.y = atan2(-side.x, -side.z) + PI
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _legend() -> void:
	print("")
	print("  ARCHIPEPSI 0.4 -- THE RAILWAY, development scenario")
	print("  Not a Zone: no Checks, no exit, no campaign, no bridge.")
	print("")
	print("    WASD / space     move")
	print("    left mouse       Static Pulse -- shoot a direction control")
	print("    E                take the hookshot / pull the lever")
	print("    right-hand mouse / the mobility key   fire the hookshot")
	print("    Esc              quit")
	print("")
	print("  S1 --commissioned-- S2 - - - broken - - - S3")
	print("                      |")
	print("                      +-- the branch: a hookshot, and a ledge")
	print("                          to learn it on")
	print("")
	print("  Board at S1 and shoot the chevron pointing down the track.")
	print("  At S2 the railway refuses S3: the span is up. The gantry that")
	print("  lowers it is overhead and out of reach -- cross the junction,")
	print("  take the hookshot, try it on the ledge, come back, and pull")
	print("  yourself up to the ring. The repair is what would survive")
	print("  leaving, if this were a Zone.")
	print("")


func _on_refused(reason: String, detail: String) -> void:
	if _refusal_sign == null:
		return
	_refusal_sign.text = "%s: %s" % [reason.to_upper(), detail]
	_refusal_left = 4.0
	print("  railway: %s -- %s" % [reason, detail])


func _on_commissioned(link: int, _latch: String) -> void:
	if link == 1 and _span_sign != null:
		_span_sign.text = "SPAN: LOCKED HOME  --  S3 IS REACHABLE"
		_span_sign.modulate = Color(0.6, 1.0, 0.7)
		print("  railway: the span locked home; the latch would be "
			+ "reported as 'yard_junction/span_aligned'")


func _process(delta: float) -> void:
	if _refusal_left > 0.0:
		_refusal_left -= delta
		if _refusal_left <= 0.0 and _refusal_sign != null:
			_refusal_sign.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


## --- the acquisition branch (M2-mech) ---------------------------------

## A pedestal that hands over an Echo.
##
## **THE DEV PATH, and it is labelled as one everywhere it appears.** In
## the real loop the featured Echo arrives through the campaign: an AP
## Check, the interpretation fold, a snapshot, `set_equipped`. That
## contract is M2's and is not built, so this hands the same component
## straight to the same runtime -- which proves the EXPERIENCE (can a
## player acquire a tool and immediately use it to open something they
## could see but not reach) and proves nothing at all about
## progression, logic or multiworld safety.
##
## The component is the one the schema's own tests author, numbers
## included, so the thing handed over here is the thing the bridge would
## hand over rather than a convenient invention.
class EchoGrant extends StaticBody3D:
	signal granted(slot: String)

	const COMPONENT := {
		"kind": "action", "component_id": "dev_hookshot",
		"display_name": "Hookshot", "slot": "mobility",
		"description": "Pull yourself to a surface.", "cooldown": 1.5,
		"primitive": {"type": "grapple_to_surface", "range": 20.0,
			"pull_force": 14.0},
		"modifiers": []}

	var taken := false
	var _lid: Node3D = null

	static func make(theme: String) -> EchoGrant:
		var made := EchoGrant.new()
		made.name = "EchoGrant"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.1, 1.0)
		shape.shape = box
		made.add_child(shape)
		var plinth := MeshInstance3D.new()
		var plinth_mesh := BoxMesh.new()
		plinth_mesh.size = box.size
		plinth.mesh = plinth_mesh
		plinth.material_override = ThemeMaterials.glow_material(
			ActivityElement.HARDWARE, 0.0)
		made.add_child(plinth)
		made._lid = MeshInstance3D.new()
		var lid := BoxMesh.new()
		lid.size = Vector3(0.5, 0.5, 0.5)
		(made._lid as MeshInstance3D).mesh = lid
		made._lid.position = Vector3(0.0, 1.0, 0.0)
		(made._lid as MeshInstance3D).material_override = \
			ThemeMaterials.glow_material(Color(0.6, 0.9, 1.0), 2.2)
		made.add_child(made._lid)
		return made

	func interact_prompt() -> String:
		return "" if taken else "[E] TAKE THE HOOKSHOT"

	func interact(who: Node) -> void:
		if taken or who == null:
			return
		var holder := who as Player
		if holder == null or not holder.runtimes.has("mobility"):
			return
		taken = true
		if _lid != null:
			_lid.visible = false
		# THE REAL SLOT AND THE REAL RUNTIME. Nothing here reaches past
		# `set_equipped`, which is the same call a snapshot makes.
		var runtime: EchoRuntime = holder.runtimes["mobility"]
		runtime.set_equipped(COMPONENT)
		granted.emit("mobility")


## A ceiling plate with a ledge under it: the grapple family reaches it
## and nothing else does.
##
## The shape is `AffordanceFeatures._grapple_anchor`'s -- a plate to
## bite, a ledge to land on, a ring so it reads as a hook -- built here
## rather than called because that one is private to the feature builder
## and carries a reward this scenario has no campaign to grant.
func _anchor(at: Vector3, plate_y: float, ledge_y: float,
		ledge: Vector3) -> StaticBody3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.material_override = ThemeMaterials.glow_material(
		Constants.AFFORDANCE_SIGNAL, 1.8)
	add_child(ring)
	ring.global_position = at + Vector3(0.0, plate_y - 0.32, 0.0)
	if ledge.length() > 0.0:
		_slab(ledge, at + Vector3(0.0, ledge_y, 0.0),
			ThemeMaterials.accent_mat(THEME))
	return _slab(Vector3(1.2, 0.3, 1.2), at + Vector3(0.0, plate_y, 0.0),
		ThemeMaterials.trim_mat(THEME))


## THE ACQUISITION BRANCH. Off the S2 junction, away from the gantry,
## walkable on the base kit alone.
##
## **The order is the design's, and it is cause B of the Blindside
## review.** The gantry is visible from S2 before the branch is taken;
## the branch supplies the tool; the player comes back to a junction
## they already know and opens what they had already seen. Nothing in
## the branch needs the grapple to enter, because the branch is where
## the grapple comes from.
func _branch() -> void:
	var where := rail.at(dock_offsets[1])
	var along := rail.tangent(dock_offsets[1])
	var side := Vector3.UP.cross(along).normalized()
	var top := RAIL_Y + DECK.y
	# OUT PAST THE GANTRY, not across the track. An earlier cut put
	# the branch on the far side of the rails and left the player a
	# nine-metre gap and a live railway to cross -- a branch nobody
	# can walk to on the base kit is not an acquisition branch. This
	# one leaves the dock beside the gantry and passes UNDER it,
	# which also keeps the thing the tool opens in view on the way
	# out and on the way back.
	var lane := along * 3.0
	var yard := where + side * BRANCH_OUT + lane \
			+ Vector3(0.0, top, 0.0)
	_slab(Vector3(10.0, 0.4, 10.0), yard - Vector3(0.0, 0.2, 0.0),
			ThemeMaterials.wall_mat(THEME))
	var walk_from := DOCK_OUT
	var walk_to := BRANCH_OUT - 4.0
	var walkway := _slab(
			Vector3(3.0, 0.4, walk_to - walk_from),
			where + side * ((walk_from + walk_to) * 0.5) + lane
				+ Vector3(0.0, top - 0.2, 0.0),
			ThemeMaterials.floor_mat(THEME))
	walkway.basis = Basis.looking_at(-side, Vector3.UP)

	grant = EchoGrant.make(THEME)
	add_child(grant)
	grant.global_position = yard + Vector3(0.0, 0.55, 0.0)
	grant.look_at(Vector3(where.x, grant.global_position.y, where.z),
		Vector3.UP)
	_sign("HOOKSHOT", yard + Vector3(0, 3.4, 0),
		Color(0.6, 0.9, 1.0), 72)
	_sign("dev-path grant: the campaign contract that would\n"
		+ "hand this over is M2 and is not built",
		yard + Vector3(0, 2.6, 0), Color(0.7, 0.7, 0.75), 28)

	# AND SOMETHING TO LEARN IT ON, before it matters. A ledge out of
	# jump reach with nothing required on it: the first pull should be
	# somewhere a miss costs nothing.
	var practice := yard + side * 7.0
	_anchor(practice, 6.4, 2.6, Vector3(3.0, 0.4, 3.0))
	_sign("TRY IT", practice + Vector3(0, 7.4, 0),
		Color(0.75, 0.9, 1.0), 48)


## Which way is "beside the track" at a dock: the unit vector a dock
## platform, its controls and its branch are all laid out along.
##
## Exposed because a caller that recomputed it would be the second copy
## of the arithmetic, and the two would disagree the day the route
## changes.
func dock_side(index: int) -> Vector3:
	var at := clampi(index, 0, dock_offsets.size() - 1)
	return Vector3.UP.cross(rail.tangent(dock_offsets[at])).normalized()


## --- small builders ---------------------------------------------------

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
	body.global_position = centre
	return body


## A flight of steps from `foot` (on the ground) up to `head` (the lip
## of what it serves).
##
## BOTH ENDS ARE GIVEN, and the count and the tread are solved from
## them. The first version took a foot, a height and a direction and
## chose its own tread -- so its top step landed wherever the
## arithmetic put it, which on the gantry was four metres short of the
## platform it was supposed to reach and two metres below it. A stair
## that does not touch what it climbs to is not a stair, and it was the
## screenshots that said so rather than any test.
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
		# Each step is a solid block from the ground to its own tread,
		# so there is nothing to fall through and nothing to trip on.
		var height := float(i + 1) * rise / float(steps)
		var here := foot + out * (tread * (float(i) + 0.5)) \
				+ Vector3(0.0, height * 0.5, 0.0)
		var slab := _slab(Vector3(width, height, tread), here, material)
		slab.basis = Basis.looking_at(-out, Vector3.UP)


func _sign(text: String, where: Vector3, tint: Color,
		size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.no_depth_test = false
	add_child(label)
	label.global_position = where
	return label
