class_name RailCarrier
extends AnimatableBody3D
## A passenger-carrying platform that travels a `RailPath` between docks.
##
## **Why this is an `AnimatableBody3D` and not a `RailRider`.** `RailRider`
## is a player-grind state machine: `player.gd` assigns `global_position`
## directly and deliberately never calls `move_and_slide` while riding, so
## the rail IS the collision and there is no body to stand on. A carrier is
## the opposite problem -- it must exist in physics so that the engine's own
## mover carries whoever is aboard. `AffordanceNodes.MovingPlatform` already
## established the shape (`AnimatableBody3D` + `sync_to_physics`), and
## `godot-passenger-carry` measured that it genuinely works: four cases,
## passenger grounded on 300 of 300 frames, returning to its starting offset
## on the deck. This class is that platform with a path instead of a cosine
## loop.
##
## **The deck is sized by the caller, deliberately.** `MovingPlatform` is a
## 2.4 m square, and the same measurement found a walking rider crosses that
## in about four tenths of a second. A carrier whose passenger moves to aim
## or take cover needs a deck sized from the rider's movement, so `deck` is a
## parameter and 2.4 m is not inherited.
##
## **Commissioning is a property of the LINK, not of the carrier.** Docks are
## ordered; `links[i]` joins dock `i` to dock `i+1`. A link that is not
## commissioned is missing rail, and no amount of shooting the control makes
## the carrier glide over it -- the request is refused at the dock, visibly,
## with the reason. Restoring a link is somebody else's job (a latch, a
## repair); this class only ever reads it.

signal departed(from_id: String, direction: int)
signal arrived(dock_id: String)
## A command that could not be honoured, with a reason a player can act on.
signal refused(reason: String, detail: String)

## Travel speed once up to pace. Chosen for a ride that reads as
## deliberate rather than a tram simulation; tune against a played route.
const SPEED := 7.0
## How hard the carrier may change speed. THIS IS THE PASSENGER-COMFORT
## NUMBER: `godot-passenger-carry` measured 0.609 m of transient drift on
## `MovingPlatform`'s cosine loop, whose peak acceleration is roughly
## 4.7 m/s^2. A rider is dragged along by friction, so the gentler this
## is, the less they slide while the deck picks up speed.
const ACCEL := 3.0
## Close enough to a dock to call it arrival.
const DOCK_EPSILON := 0.05
## Directions. `HOLD` is a real state, not "no input": a fail-safe stop
## holds a loaded carrier still, and that is different from a carrier
## waiting at a dock for a command.
const FORWARD := 1
const BACK := -1
const HOLD := 0

## The route, in the space `to_world` maps from.
var path: RailPath = null
var to_world := Transform3D.IDENTITY
## O05-06.2. Take `to_world` from the parent when entering the tree. A
## railway laid in a ROOM's frame (EX50-011's shuttle, hosted in a Zone)
## knows its frame only once that room has been placed, which is after
## the carrier was built. Off by default: the Zone's own railways lay
## their paths in world coordinates and are unchanged.
var frame_from_parent := false
## Dock offsets along `path`, ascending, with their ids.
var dock_offsets: PackedFloat32Array = PackedFloat32Array()
var dock_ids: PackedStringArray = PackedStringArray()
## `commissioned[i]` is the link from dock `i` to dock `i+1`.
var commissioned: Array[bool] = []
## The deck a passenger stands on. Sized by the caller -- see the note above.
var deck := Vector3(4.0, 0.4, 4.0)
## SERVICE SPEED, per carrier. `SPEED` and `ACCEL` stay the railway
## skiff's numbers and stay the defaults; a maintenance shuttle running
## a 21 m room at 1.5 m/s is a different vehicle, not a different class,
## and EX50-011 §2 authors its speed in the situation rather than here.
var top_speed := SPEED
var accel := ACCEL

var offset := 0.0
var heading := HOLD
## Current speed along the path, always positive; `heading` carries sign.
var speed := 0.0
## Where this journey is going. -1 when the carrier is parked.
var target_dock := -1
var held := false
var _unpowered := false
var _errand := -1
var _bearing := HOLD

var _deck_mesh: MeshInstance3D
var _theme := "concrete_facility"
## Why this carrier is not a railway, if it is not. Non-empty means the
## thing never moves: see `_ready`.
var _malformed: Array[String] = []


static func create(rail: RailPath, offsets: PackedFloat32Array,
		ids: PackedStringArray, links: Array[bool],
		deck_size: Vector3, theme: String,
		frame := Transform3D.IDENTITY) -> RailCarrier:
	var made := RailCarrier.new()
	made.path = rail
	made.to_world = frame
	made.dock_offsets = offsets
	made.dock_ids = ids
	made.commissioned = links
	made.deck = deck_size
	made._theme = theme
	made.offset = offsets[0] if not offsets.is_empty() else 0.0
	return made


func _ready() -> void:
	# A MALFORMED RAILWAY DOES NOT MOVE. It is still built -- an invisible
	# carrier is a harder defect to see than a stationary one -- but it
	# refuses every command and says which fact about its own shape is
	# wrong, rather than driving to a dock that is not where it thinks.
	_malformed = violations()
	if not _malformed.is_empty():
		push_warning("rail carrier refused: %s" % "; ".join(_malformed))
	# The property the measured carry depends on. Without it the deck moves
	# without the physics server knowing, and a passenger is left behind.
	sync_to_physics = true
	if frame_from_parent and get_parent() is Node3D:
		to_world = (get_parent() as Node3D).global_transform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = deck
	shape.shape = box
	add_child(shape)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Deck"
	var mesh := BoxMesh.new()
	mesh.size = deck
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.trim_mat(_theme)
	add_child(mesh_node)
	_deck_mesh = mesh_node
	_place()


## Which dock the carrier is standing at, or -1 while travelling.
func at_dock() -> int:
	for i in dock_offsets.size():
		if absf(offset - dock_offsets[i]) <= DOCK_EPSILON:
			return i
	return -1


func dock_id(index: int) -> String:
	return dock_ids[index] if index >= 0 and index < dock_ids.size() else ""


## Is the link that leaves `from` in `direction` usable?
func link_open(from: int, direction: int) -> bool:
	var link := from if direction == FORWARD else from - 1
	if link < 0 or link >= commissioned.size():
		return false
	return commissioned[link]


## A direction command, as a shot receiver delivers it.
##
## THE COMMAND RULES ARE THE OWNER'S, and each refusal says which one
## applied rather than failing silently:
##
##   * at a dock, FORWARD asks for the next higher dock and BACK the next
##     lower one, and only if that link is commissioned;
##   * repeated commands in the same direction while travelling do NOT
##     queue another journey or skip the next dock -- a shotgun's pellets
##     are one request, not five;
##   * the opposite direction while travelling brakes and reverses toward
##     the dock just left, which is known-safe because the carrier has
##     just traversed it;
##   * a held carrier honours nothing until it is released.
func request(direction: int) -> bool:
	if not _malformed.is_empty():
		refused.emit("not_a_railway", "; ".join(_malformed))
		return false
	if direction != FORWARD and direction != BACK:
		refused.emit("bad_direction", "a command must be FORWARD or BACK")
		return false
	if held:
		refused.emit("held", "the carrier is holding under a fail-safe "
				+ "stop and will not accept travel commands")
		return false
	# RB-F3: AN UNPOWERED CARRIER HOLDS. `power(false)` stops it and keeps
	# its errand for when power returns, but a command during the outage
	# used to fall through to the stranded branch below, set a new errand,
	# and `advance` drove it -- with no power -- while the saved errand
	# waited to overwrite it on restore. §21.1.1: it holds.
	if _unpowered:
		refused.emit("unpowered", "the carrier has no power and holds "
				+ "where it stands")
		return false

	var here := at_dock()
	if here >= 0:
		if not link_open(here, direction):
			# THE HONEST REFUSAL. Missing rail is a fact about the world,
			# and the player is told which fact rather than left to
			# wonder whether they missed the receiver.
			refused.emit("no_link", "no commissioned track leaves %s %s"
					% [dock_id(here),
						"forward" if direction == FORWARD else "back"])
			return false
		var want := here + (1 if direction == FORWARD else -1)
		target_dock = want
		heading = direction
		departed.emit(dock_id(here), direction)
		return true

	# STRANDED BETWEEN DOCKS. A fail-safe stop leaves the carrier here,
	# and the first cut of this method had no branch for it: `heading` was
	# HOLD, `target_dock` was -1, and every subsequent command fell into
	# the reversing arithmetic below and came back "there is no dock
	# behind this carrier". A held carrier that could never be released
	# is not a fail-safe, it is a trap with a passenger in it. Both ends
	# of the segment it is standing in are reachable, because it is
	# standing in that segment.
	if heading == HOLD:
		var link := _segment()
		if link < 0 or not commissioned[link]:
			refused.emit("no_link", "the carrier is stopped on track that "
					+ "is not commissioned")
			return false
		target_dock = link + 1 if direction == FORWARD else link
		heading = direction
		departed.emit(dock_id(link if direction == FORWARD else link + 1),
				direction)
		return true

	# TRAVELLING.
	if direction == heading:
		# Not a refusal worth a klaxon, but not a second journey either.
		refused.emit("already_moving", "already travelling that way")
		return false
	# REVERSING is legal within the segment just traversed: the carrier
	# came from there, so the rail behind it is known good.
	var back_to := target_dock - (1 if heading == FORWARD else -1)
	if back_to < 0 or back_to >= dock_offsets.size():
		refused.emit("no_link", "there is no dock behind this carrier")
		return false
	target_dock = back_to
	heading = direction
	return true


## A fail-safe stop. Holds a loaded carrier still and safely; it is NOT a
## normal direction command and does not retract, drop or recall anything.
func hold(on: bool) -> void:
	held = on
	if on:
		heading = HOLD
		speed = 0.0
		target_dock = -1


## §21.1.1: a carrier HOLDS on power loss, and remembers where it was
## going.
##
## Deliberately not `hold()`. That is the fail-safe stop, and it clears
## `target_dock` on purpose -- a held carrier has no errand any more.
## Power loss is the other thing: §21.1 says power restored "resumes
## toward the position the current input commands, from wherever power
## loss left it", so the errand has to survive the outage or the carrier
## comes back powered and parked, halfway down a span, with its passenger
## on it and no way to say where it was headed.
func power(on: bool) -> void:
	if on == not _unpowered:
		return
	_unpowered = not on
	if not on:
		_errand = target_dock
		_bearing = heading
		heading = HOLD
		speed = 0.0
		target_dock = -1
		return
	target_dock = _errand
	heading = _bearing
	_errand = -1
	_bearing = HOLD


## Put the carrier at rest on dock `index`, clamped to a dock that exists.
##
## `RailJunction.park` is the POLICY -- which dock; this is the mechanism,
## and it belongs to the carrier because only the carrier knows where its
## docks are (a network carrier's are not all on one path).
func park_at(index: int) -> void:
	if dock_offsets.is_empty():
		return
	var where := clampi(index, 0, dock_offsets.size() - 1)
	hold(false)
	heading = HOLD
	speed = 0.0
	target_dock = -1
	offset = dock_offsets[where]
	_place()


## Which link the carrier is standing in: `_segment()` joins dock
## `_segment()` to `_segment() + 1`. -1 when it is short of the first dock.
func _segment() -> int:
	var link := -1
	for i in dock_offsets.size():
		if offset >= dock_offsets[i] - DOCK_EPSILON:
			link = i
	return mini(link, commissioned.size() - 1)


func _physics_process(delta: float) -> void:
	advance(delta)


## One step of travel.
##
## SPLIT OUT so a suite can step the railway by hand, in the idiom
## `MovingPlatform.advance` already set. It matters more here than there:
## `sync_to_physics` makes `global_position` a read of the PHYSICS SERVER
## rather than of what was last assigned, so a test that waited on real
## frames and then read the node would be measuring the server's opinion
## of last frame. `offset` and `pose()` are what this class knows.
func advance(delta: float) -> void:
	if path == null or heading == HOLD or target_dock < 0:
		return
	if not _malformed.is_empty():
		return
	var goal: float = dock_offsets[target_dock]
	# THE ARITHMETIC IS `StopTravel`'s, and it is shared with the
	# lift in EX50-011 rather than copied into it: how a machine gets
	# from one stop to the next is one question, even where the
	# machines differ in everything else.
	var moved := StopTravel.step(offset, goal, speed, delta,
			accel, top_speed, DOCK_EPSILON)
	offset = moved.x
	speed = moved.y
	_place()
	if absf(goal - offset) <= DOCK_EPSILON:
		offset = goal
		speed = 0.0
		heading = HOLD
		var landed := target_dock
		target_dock = -1
		_place()
		arrived.emit(dock_id(landed))


## Every way this is not a railway. Empty is the contract.
##
## REFUSED WHERE IT IS BUILT, in the idiom `RailPath.violations` already
## set: a carrier whose docks are out of order or whose link array is the
## wrong length does not announce itself -- it silently drives to the
## wrong place, or refuses a link that exists, and the defect surfaces as
## a player standing at a dock wondering why the control does nothing.
func violations(who := "carrier") -> Array[String]:
	var out: Array[String] = []
	if path == null:
		out.append("%s: no path" % who)
		return out
	out.append_array(path.violations("%s rail" % who))
	if dock_offsets.size() < 2:
		out.append("%s: a railway needs at least two docks, got %d"
				% [who, dock_offsets.size()])
		return out
	if dock_ids.size() != dock_offsets.size():
		out.append("%s: %d docks but %d names"
				% [who, dock_offsets.size(), dock_ids.size()])
	# ONE LINK PER GAP, and the count is the contract that makes
	# `link_open` answerable: a short array reads as "not commissioned"
	# for the tail of the line, which is indistinguishable from broken
	# track and is therefore refused rather than interpreted.
	if commissioned.size() != dock_offsets.size() - 1:
		out.append("%s: %d docks need %d links, got %d"
				% [who, dock_offsets.size(), dock_offsets.size() - 1,
					commissioned.size()])
	var span := path.length()
	for i in dock_offsets.size():
		var here: float = dock_offsets[i]
		if here < -DOCK_EPSILON or here > span + DOCK_EPSILON:
			out.append("%s: dock %d sits %.2f m along a %.2f m rail"
					% [who, i, here, span])
		if i == 0:
			continue
		var previous: float = dock_offsets[i - 1]
		# FAR ENOUGH APART TO BE TWO PLACES. Inside twice the arrival
		# tolerance `at_dock` cannot tell them apart, and the carrier
		# would report standing at both.
		if here - previous <= DOCK_EPSILON * 2.0:
			out.append("%s: docks %d and %d are %.3f m apart, which is not "
					% [who, i - 1, i, here - previous]
					+ "two docks")
	if deck.x <= 0.0 or deck.y <= 0.0 or deck.z <= 0.0:
		out.append("%s: the deck %v has no volume" % [who, deck])
	return out


## Where the deck intends to be, facing the way it is going.
##
## The deck's own top surface is what a passenger stands on, so the body
## sits half a deck ABOVE the rail rather than centred on it -- a rail
## through the middle of the floor would leave the rider inside it.
##
## THIS, NOT `global_transform`, is what the carrier knows: see `advance`.
func pose() -> Transform3D:
	if path == null:
		return global_transform
	var here := to_world * path.at(offset)
	var along := (to_world.basis * path.tangent(offset)).normalized()
	var up := Vector3.UP
	# A RAIL MAY NOT PITCH PAST 75 DEGREES (`RailPath.MAX_PITCH_DEGREES`),
	# so this branch cannot be reached by a legal path. It is here because
	# the day someone raises that limit, the failure without it is a zero
	# basis vector and a deck that vanishes, which reads as a build bug
	# rather than as the rule it actually violates.
	if absf(along.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var basis := Basis()
	var side := up.cross(along).normalized()
	basis.x = side
	basis.y = along.cross(side).normalized()
	basis.z = along
	return Transform3D(basis, here + basis.y * (deck.y * 0.5))


func _place() -> void:
	if path == null:
		return
	global_transform = pose()
