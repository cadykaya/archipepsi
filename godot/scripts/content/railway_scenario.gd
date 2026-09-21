class_name RailwayScenario
extends Node3D
## THE RAILWAY, PLAYABLE (`--railway`). **Development scaffolding.**
##
## **What this is.** The whole first loop, in a place a person can stand.
## Board the skiff at S1, shoot the chevron pointing down the track, ride
## to S2, find S2 to S3 refused for want of track. The gantry that lowers
## the span is overhead and out of reach; the branch that supplies the
## tool leaves the same dock and passes under it. Take the hookshot, try
## it on the ledge beside the pedestal, come back, pull yourself to the
## ring, throw the lever, and ride to S3. Then leave and come back, and
## find the repair still there and everything else at its default.
##
## **What this is NOT, and the distinction is load bearing.** This is not
## a Zone. It is not composed, it carries no Checks, no exit and no
## Archipelago logic, nothing here is multiworld-safe, and no campaign is
## touched: it runs before `boot()` and never opens a bridge connection.
## It exists for the same reason `ShowcaseZone` does and under the same
## rule -- **it runs only when an operator asks for it by name, and
## nothing can arrive here by accident.**
##
## **The Echo is granted by a pedestal, and that is the ONLY shortcut.**
## In the real loop the featured Echo arrives through the campaign: an AP
## Check, the interpretation fold, a snapshot, `set_equipped`. That
## contract is M2's completion requirement and is not built. Everything
## else here is the real runtime -- the real interact verb, the real
## mobility slot, the real damage path, the real latch -- and the one
## shortcut is labelled on a sign in the world as well as here.
##
## **There is no walking bypass to the gantry, deliberately.** An earlier
## cut had a flight of stairs as a placeholder, and a placeholder that
## lets you skip the loop is not a placeholder for the loop.

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
## Chest-high: cover you stand behind, not a wall you hide in.
const SHIELD_HEIGHT := 1.25
const THEME := "concrete_facility"
const GANTRY_BINDING := "gantry"
const BRACING_BINDING := "bracing"

var rail: RailPath = null
var carrier: RailCarrier = null
var controls: RailControls = null
var junction: RailJunction = null
var span: RailSpan = null
var lever: AlignmentControl = null
var grant: EchoGrant = null
## The plate above the gantry that the hookshot bites.
var grapple_plate: StaticBody3D = null
var plinth: ReturnPlinth = null
var shield: MeshInstance3D = null
## The shooters beside the S1-to-S2 leg. Rebuilt with the yard.
var shooters: Array[Enemy] = []
var player: Player = null
var hud: Hud = null
## WHICH RELATIONSHIP RELEASES THE SPAN. `"gantry"` is the approved
## first configuration: a control you can see from the junction and
## cannot reach, and a branch that supplies the tool. `"bracing"` is the
## second binding -- `ranged_hit` on eligible bracing, which the base
## kit already does. They are ALTERNATIVES, never both: see `_bracing`.
var binding := GANTRY_BINDING
var bracing: ActivityElement = null
var dock_offsets := PackedFloat32Array()

## EVERYTHING THE RAILWAY IS MADE OF, under one node.
##
## So that coming back can be a REBUILD rather than a reset. The claim
## M1 makes is that the accepted repair is recomputed from its latch
## when the Zone is built again -- not that a span object remembers
## being moved -- and the only honest way to show that to a person
## standing in it is to throw the machinery away and build it afresh.
var _world: Node3D = null
## The latch refs this yard has accepted, standing in for the
## `progress.latched` a campaign would carry. In memory only: there is
## no save here, and nothing here pretends there is.
var _accepted := {}

var _span_sign: Label3D = null
var _refusal_sign: Label3D = null
var _refusal_left := 0.0


func _ready() -> void:
	name = "RailwayScenario"
	_environment()
	_world = Node3D.new()
	_world.name = "Yard"
	add_child(_world)
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
	_shield()
	_docks()
	if binding == BRACING_BINDING:
		_bracing()
	else:
		_gantry()
		_branch()
	_readouts()
	_gauntlet()
	_plinth()
	_spawn_player()
	_hud()
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
	_world.add_child(made)
	made.global_position = head
	made.basis = Basis.looking_at(-along, Vector3.UP)
	controls.add(made)


func _carrier() -> void:
	carrier = RailCarrier.create(rail, dock_offsets,
		PackedStringArray(["S1", "S2", "S3"]), [true, false], DECK, THEME)
	_world.add_child(carrier)
	controls = RailControls.create(carrier)
	_world.add_child(controls)
	junction = RailJunction.create(carrier, "yard_junction")
	_world.add_child(junction)
	# THE SPAN, pivoting at the S2 end of the gap it bridges. The parent
	# carries the aim along the track; the span's own yaw is the swing,
	# which is why it needs a frame of its own to swing inside.
	var pivot := Node3D.new()
	pivot.name = "SpanPivot"
	_world.add_child(pivot)
	pivot.global_position = rail.at(dock_offsets[1])
	pivot.basis = Basis.looking_at(-rail.tangent(dock_offsets[1]),
		Vector3.UP)
	span = RailSpan.create("span_aligned", 1,
		dock_offsets[2] - dock_offsets[1], THEME)
	pivot.add_child(span)
	junction.add(span, null)
	controls.refused.connect(_on_refused)
	# THE ACCEPTED CONSEQUENCE, kept the way a campaign would keep it:
	# the latch ref, not the state of any object that produced it.
	junction.latch_fired.connect(
		func(pkg: String, latch: String) -> void:
			_accepted["%s/%s" % [pkg, latch]] = true)
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
	_world.add_child(lever)
	lever.global_position = deck_centre \
		+ Vector3(0.0, 0.4 * 0.5 + AlignmentControl.BASE.y * 0.5, 0.0)
	lever.look_at(Vector3(where.x, lever.global_position.y, where.z),
		Vector3.UP)
	lever.operated.connect(func(_c: AlignmentControl) -> void: span.begin())
	_sign("ALIGNMENT GANTRY", deck_centre + Vector3(0, 3.0, 0),
		Color(1.0, 0.85, 0.5), 64)
	_sign("reached with the hookshot from the branch\n"
		+ "below -- aim at the ring",
		deck_centre + Vector3(0, 2.1, 0), Color(0.7, 0.7, 0.75), 28)


## The two readouts the yard keeps whichever way the span is released.
func _readouts() -> void:
	var where := rail.at(dock_offsets[1])
	var side := dock_side(1)
	_span_sign = _sign("SPAN: STOWED  --  NO TRACK BEYOND S2",
			rail.at(lerpf(dock_offsets[1], dock_offsets[2], 0.3))
				+ Vector3(0, 2.6, 0), Color(1.0, 0.6, 0.45), 48)
	_refusal_sign = _sign("", where + side * DOCK_OUT
			+ Vector3(0, RAIL_Y + DECK.y + 2.2, 0),
			Color(1.0, 0.7, 0.55), 40)


## THE SECOND BINDING: bracing, and a gun you already have.
##
## **A different relationship, not a relabel.** The gantry configuration
## asks the player to REACH a control and operate it. This one asks them
## to remove what is holding the span up: a clamp on the raised beam,
## visible from the junction, shot from the dock with the base kit. The
## span then goes home under its own weight and locks, and the accepted
## consequence -- the same latch, the same commissioned link -- is
## identical. What differs is the verb and what it is aimed at.
##
## **It is NOT a second acquisition loop**, and the plan's addendum is
## explicit about why: `ranged_hit` establishes no newly acquired
## capability, because the starting player already shoots the transport
## receivers. This is an existing-tool objective variant.
##
## **It is never built alongside the gantry.** A yard offering both
## would be a yard where the acquisition branch is optional, which is
## the guaranteed walking bypass under another name.
func _bracing() -> void:
	bracing = ActivityElement.create(ActivityElement.SHOT, 90,
			ActivityElement.TARGET_SIZE, Color(1.0, 0.62, 0.42))
	# ON THE SPAN ITSELF, so it rises with it and reads as the thing
	# holding it up rather than as one more control on a post.
	span.add_child(bracing)
	bracing.position = Vector3(0.0, 0.5, 4.5)
	bracing.rotation.y = PI * 0.5
	bracing.triggered.connect(func(_e: ActivityElement) -> void:
			span.begin())
	_sign("BRACING", span.global_position + Vector3(0, 6.0, 0),
			Color(1.0, 0.62, 0.42), 56)
	_sign("shoot it: the span is held, not parked",
			span.global_position + Vector3(0, 5.2, 0),
			Color(0.7, 0.7, 0.75), 26)


func _spawn_player() -> void:
	player = Player.create()
	add_child(player)
	_place_player()
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Stand the player on S1, facing the track. Where they arrive, and
## where they arrive again.
func _place_player() -> void:
	var start := rail.at(dock_offsets[0])
	var along := rail.tangent(dock_offsets[0])
	var side := Vector3.UP.cross(along).normalized()
	var at := start + side * DOCK_OUT \
			+ Vector3(0.0, RAIL_Y + DECK.y + 1.2, 0.0)
	# `set_spawn`, NOT an assignment to `global_position`. The player
	# respawns at its spawn transform after `RESPAWN_DELAY`, and that
	# transform is captured in `_ready` -- so a player merely MOVED
	# here would come back at the world origin the first time the
	# shooters killed them, which in a yard with enemies in it is the
	# difference between a scenario and a trap.
	player.set_spawn(Transform3D(
			Basis(Vector3.UP, atan2(-side.x, -side.z) + PI), at))
	player.velocity = Vector3.ZERO


## THE REAL HUD, bound to the real player.
##
## A yard with shooters in it and no health readout is a yard where
## being killed is a surprise, and the prompts this scenario depends on
## -- the pedestal, the lever -- are the HUD's to draw. `main.gd` builds
## it exactly this way for a Zone; the only thing left out is the
## resource pool, because there is no campaign here to have one.
func _hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.bind_player(player)
	hud.visible = true


func _legend() -> void:
	print("")
	print("  ARCHIPEPSI 0.4 -- THE RAILWAY, development scenario")
	print("  binding: %s%s" % [binding,
			"  (--bracing selects the other one)"
			if binding == GANTRY_BINDING else ""])
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
	print("  Three shooters stand along that leg, on alternating sides:")
	print("  the deck's shield covers one side at a time and the deck")
	print("  turns, so staying behind it means moving.")
	print("  At S2 the railway refuses S3: the span is up. The gantry that")
	print("  lowers it is overhead and out of reach -- cross the junction,")
	print("  take the hookshot, try it on the ledge, come back, and pull")
	print("  yourself up to the ring.")
	print("")
	print("  Then use the plinth by S1 to leave and come back. The span")
	print("  stays down -- recomputed from the latch it fired -- and")
	print("  everything else is built again: the lever stands up, the")
	print("  controls are armed, the carrier is parked at S1.")
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



## The way out, and back in. OUTSIDE the yard on purpose: it stands for
## the Zone boundary rather than for anything the railway is made of,
## and a node that freed itself from inside its own signal handler would
## be a crash rather than a re-entry.
func _plinth() -> void:
	var where := rail.at(dock_offsets[0])
	var along := rail.tangent(dock_offsets[0])
	var side := Vector3.UP.cross(along).normalized()
	var top := RAIL_Y + DECK.y
	plinth = ReturnPlinth.make(THEME)
	add_child(plinth)
	plinth.global_position = where + side * (DOCK_OUT + 1.2) \
			- along * 2.4 + Vector3(0.0, top + 0.6, 0.0)
	plinth.asked.connect(_on_leave)
	_sign("LEAVE AND COME BACK", plinth.global_position
			+ Vector3(0, 1.6, 0), Color(0.85, 0.75, 1.0), 44, true)
	_sign("stands for the Zone boundary: what the latch\n"
			+ "accepted comes back, everything else is rebuilt",
			plinth.global_position + Vector3(0, 1.0, 0),
			Color(0.7, 0.7, 0.75), 24, true)


## A player asked to leave. DEFERRED, because `reenter` frees the yard
## and this is running inside a node that is standing in it.
func _on_leave() -> void:
	reenter.call_deferred()


## --- something to ride through -----------------------------------------

## Chest-high cover on one edge of the deck.
##
## **The deck rotates, so the cover rotates with it.** That is the whole
## idea: a shield welded to one side of a carrier that turns through a
## corner does not protect the same side for the whole journey, so a
## rider who wants to stay behind it has to move. `godot-passenger-carry`
## recorded that a carrier whose passenger moves to aim or take cover
## needs a deck sized from that movement rather than inherited -- this is
## the movement it was talking about.
##
## Built as part of the carrier's own body rather than as a child node
## standing on it: an `AnimatableBody3D` with `sync_to_physics` carries
## its own shapes exactly, and a separate static body riding along would
## be a second thing to keep in step.
func _shield() -> void:
	var panel := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, SHIELD_HEIGHT, DECK.z)
	panel.shape = box
	# ON THE SIDE AWAY FROM THE DOCKS. The carrier's own +X is the
	# side its platforms stand on, so a shield there would be a wall
	# between the player and the only way aboard.
	panel.position = Vector3(-(DECK.x * 0.5 - 0.15),
		DECK.y * 0.5 + SHIELD_HEIGHT * 0.5, 0.0)
	carrier.add_child(panel)
	shield = MeshInstance3D.new()
	shield.name = "Shield"
	var mesh := BoxMesh.new()
	mesh.size = box.size
	shield.mesh = mesh
	shield.position = panel.position
	shield.material_override = ThemeMaterials.accent_mat(THEME)
	carrier.add_child(shield)


## THE RIDE IS NOT A TRAM RIDE.
##
## Three static shooters beside the S1-to-S2 leg, on alternating sides,
## far enough apart that they arrive one at a time. `ranged` is the
## archetype that does not walk -- reach 40 m, speed 0 -- so what they
## test is whether a player can fight FROM a moving deck, which is the
## question the skiff exists to ask.
##
## They are ordinary `Enemy` instances and find the player themselves.
## Nothing here teaches them about the carrier.
func _gauntlet() -> void:
	var leg := dock_offsets[1] - dock_offsets[0]
	var lean := 1.0
	for fraction: float in [0.3, 0.55, 0.8]:
		var along := dock_offsets[0] + leg * fraction
		var at := rail.at(along)
		var side := Vector3.UP.cross(rail.tangent(along)).normalized() \
			* lean
		var stand := at + side * 7.5
		# A perch, so a shooter that cannot walk is not standing in a
		# hole and is above the deck's own lip.
		_slab(Vector3(3.0, 0.4, 3.0),
			Vector3(stand.x, RAIL_Y + 0.6, stand.z),
			ThemeMaterials.wall_mat(THEME))
		var shooter := Enemy.create("ranged", THEME)
		_world.add_child(shooter)
		shooter.global_position = Vector3(stand.x, RAIL_Y + 0.8, stand.z)
		shooters.append(shooter)
		lean = -lean


## --- leaving, and coming back -----------------------------------------

## A plinth that ends the visit and starts another one.
##
## **Why the scenario needs one.** M1's whole claim is that the accepted
## repair is RECOMPUTED when the place is built again -- and until now
## that was visible only to a test. A player could pull the lever and
## watch the span lock, and had no way to see the part that matters.
class ReturnPlinth extends StaticBody3D:
	signal asked

	var label := "LEAVE AND COME BACK"

	static func make(theme: String) -> ReturnPlinth:
		var made := ReturnPlinth.new()
		made.name = "ReturnPlinth"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.2, 1.0)
		shape.shape = box
		made.add_child(shape)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		mesh_node.mesh = mesh
		mesh_node.material_override = ThemeMaterials.glow_material(
			Color(0.85, 0.75, 1.0), 1.4)
		made.add_child(mesh_node)
		var mount := MeshInstance3D.new()
		var mount_mesh := BoxMesh.new()
		mount_mesh.size = Vector3(1.3, 0.2, 1.3)
		mount.mesh = mount_mesh
		mount.position = Vector3(0.0, -0.7, 0.0)
		mount.material_override = ThemeMaterials.glow_material(
			ActivityElement.HARDWARE, 0.0)
		made.add_child(mount)
		return made

	func interact_prompt() -> String:
		return "[E] %s" % label

	func interact(_who: Node) -> void:
		asked.emit()


## What this visit has accepted, as `package_id/latch_id`. The scenario's
## stand-in for `progress.latched`.
func accepted_latches() -> Array:
	var out: Array = _accepted.keys()
	out.sort()
	return out


## Throw the yard away and build it again from the accepted latches.
##
## **A REBUILD, not a reset**, and the difference is the whole point.
## Nothing that was standing here survives: the carrier, the controls,
## the span, the lever and the pedestal are freed and made afresh. What
## comes back is whatever `restore_from` can work out from the latch
## refs this visit accepted -- which is exactly what a Zone does with
## `progress.latched`, and exactly what a system that remembered the
## LEVER instead of the LATCH would get wrong.
##
## What deliberately does NOT come back: the lever stands up again, the
## controls are armed again, the carrier is parked at S1 rather than
## wherever it was left, and a span that was still travelling when the
## player walked out has left nothing behind.
func reenter() -> void:
	var was := _accepted.size()
	# IMMEDIATE, not queued: a queued free leaves the old railway alive
	# for a frame, and for that frame there are two carriers on one rail.
	_world.free()
	_world = Node3D.new()
	_world.name = "Yard"
	add_child(_world)
	_yard()
	_track()
	shooters.clear()
	_carrier()
	_shield()
	_docks()
	if binding == BRACING_BINDING:
		_bracing()
	else:
		_gantry()
		_branch()
	_readouts()
	_gauntlet()
	_place_player()
	var back := junction.restore_from(_accepted.keys())
	print("  railway: rebuilt the yard; %d of %d accepted latch(es) "
		% [back, was] + "came back")
	if back > 0:
		_on_commissioned(1, "span_aligned")


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
	_world.add_child(ring)
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
	_world.add_child(grant)
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
	_world.add_child(body)
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


## `lasting` keeps a sign out of the yard, so it survives a rebuild.
func _sign(text: String, where: Vector3, tint: Color,
		size: int, lasting := false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.no_depth_test = false
	(self if lasting else _world).add_child(label)
	label.global_position = where
	return label
