class_name HubAnchors
extends RefCounted
## Where things go in the Hub, by name (v0.9 S14).
##
## The Hub used to compute a world coordinate at each placement site, so
## its logic and its geometry were the same 749 lines. Moving a station a
## metre meant editing the file that also decides what the portal does;
## replacing the room with an authored scene meant editing it too. This
## is the seam: **logic asks for an anchor by name, geometry decides where
## the anchor is.**
##
## Two sources, the S13 rule applied to a room rather than a chamber:
##
##     AUTHORED SCENE'S MARKERS IF PRESENT
##             -> THE PROCEDURAL DEFAULTS OTHERWISE
##
## An authored (or graybox) Hub scene supplies anchors as `Marker3D` nodes
## named for the anchor. Anything it does not name keeps the default, so a
## graybox can be migrated one anchor at a time.
##
## Anchors are a CONTRACT, not a suggestion: `REQUIRED` is the list the
## Hub's logic actually looks up, and a scene that resolves them all can
## host the Hub. `epsilon_presence` is in it with nothing occupying it yet
## — Epsilon is a voice in the Hub today. The hook exists so the eventual
## presence has a determined home rather than a guessed one.

## Anchors the Hub's logic looks up. Every one must resolve, or the Hub
## cannot be built; `missing()` says which.
const REQUIRED := [
	"main_portal",          # the way into a Zone
	"epsilon_presence",     # reserved: Epsilon is a voice here today
	"shop",                 # QUESTIONABLE GOODS
	"archive_loadout",      # ECHO ARCHIVE
	"lab_entrance",         # the doorway through to the Echo Lab
	"progression_display",  # the campaign board
	"postgame",             # the finale portal
	"generation_loading",   # the abandon console: the only exit from GENERATING
]

## Room dimensions. Geometry, and the only numbers the defaults derive
## from — so a scene that changes the room's size changes the anchors
## with it, instead of leaving stations embedded in a wall.
const W := 22.0
const D := 16.0
const H := 5.0

## How far a wall-hugging fixture stands off the wall. One number, so a
## bay and a station cannot disagree about where the wall is.
const WALL_CLEARANCE := 0.4

## The portal's doorway, which nothing may stand in front of.
const PORTAL_DOOR_WIDTH := 3.0

## The doorway through to the Lab. Shared with `EchoLab.OFFSET`, which is
## how the two rooms line up; `lab_driver.gd` pins that they still do.
const LAB_DOOR_Z := 6.0
const LAB_DOOR_WIDTH := 3.0
const LAB_DOOR_HEIGHT := 3.2

## Epsilon's reserved bay (art requirement 4).
##
## Owner ruling 2026-08-28, in the installation's favour: *the room-scale
## Epsilon installation is a hero asset and should keep the proposed
## prominent back-wall presence.* Do NOT shrink it, move it somewhere
## visually secondary, or redesign it around the abandon station.
##
## So the bay is RESERVED rather than negotiated. These are the art
## lane's declared installation dimensions, and engineering's job is to
## keep the space free — `intruders()` says who is standing in it.
##
## Authoring order is [width, depth, height]; the room is Y-up, so depth
## is the z extent and height the y one.
const EPSILON_BAY_WIDTH := 8.8
const EPSILON_BAY_DEPTH := 2.61
const EPSILON_BAY_HEIGHT := 3.55

## `name -> Transform3D`, in Hub-local space. Rotation is the yaw a thing
## placed here should face; a wall station faces into the room.
static func defaults() -> Dictionary:
	return {
		"main_portal": _at(Vector3(0, 0, D - 1.2), 0.0),
		# Epsilon's bay: the back wall, left of the portal, facing the
		# room. Was (-3.2, D - 3.2), which was fine for the 2.0 x 3.0
		# terminal that used to stand there and is not fine for an 8.80 m
		# installation -- centred at -3.2 it spanned x -7.6 to +1.2 and
		# ran straight through the portal's own doorway.
		#
		# Centred so the bay sits between the left wall and the portal
		# with clearance at both ends. Everything else on this wall moves
		# around Epsilon, not the other way round (art requirement 4).
		"epsilon_presence": _at(
				Vector3(-W / 2.0 + WALL_CLEARANCE + EPSILON_BAY_WIDTH / 2.0,
					0, D - WALL_CLEARANCE - EPSILON_BAY_DEPTH / 2.0), 0.0),
		# Forward of the Lab doorway, not across it. At D * 0.45 the
		# counter spanned z 6.0-8.4 and the doorway spans 4.5-7.5, so
		# the shop stood in two thirds of the only way into the Echo
		# Lab -- which is how playtest 1 found the Lab unreachable
		# even once the wall had a hole in it.
		"shop": _at(Vector3(-W / 2.0 + 1.6, 0, D * 0.15), -PI / 2.0),
		"archive_loadout": _at(Vector3(W / 2.0 - 1.6, 0, D * 0.45), PI / 2.0),
		"lab_entrance": _at(Vector3(-W / 2.0, 0, LAB_DOOR_Z), -PI / 2.0),
		# Clear of the portal, not inside it. The main door is 3 x 4 x 0.8
		# centred on `main_portal` at z = D - 1.2, so it fills z from
		# D - 1.6 to D - 0.8 and y from 0 to 4. At (4.2, D - 1.4) the
		# status board was embedded in that slab and its sub-lines hung
		# down through the door -- which is why playtest 1 read the
		# headline as letters buried in a wall.
		"progression_display": _at(Vector3(0, 4.55, D - 2.2), 0.0),
		"postgame": _at(Vector3(W / 2.0 - 3.0, 0, D - 1.2), 0.0),
		# The abandon console: the only exit from GENERATING and
		# ZONE_READY, which have no pause menu to reach. It used to sit
		# at x = -8.6, inside what is now Epsilon's bay.
		#
		# Moved to the OTHER side of the portal rather than shrunk or
		# tucked away: the ruling asks for it *outside Epsilon's
		# footprint while keeping it obvious and reachable near the Zone
		# workflow*, and the portal is the Zone workflow. Clear of the
		# portal's 3 m doorway on one side and of `postgame` on the other.
		"generation_loading": _at(Vector3(3.6, 0, D - 2.4), 0.0),
	}

static func _at(where: Vector3, facing: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, facing), where)

var _anchors: Dictionary = {}

func _init(scene_root: Node3D = null) -> void:
	_anchors = defaults()
	if scene_root != null:
		adopt(scene_root)

## Takes anchors from a scene's `Marker3D` children, by node name. An
## anchor the scene does not name keeps its default, so a graybox Hub can
## replace the procedural room one anchor at a time rather than all at
## once.
##
## Markers are read in the scene's own local space. Names outside
## `REQUIRED` are ignored rather than refused: a scene is allowed to
## carry markers for its own purposes.
func adopt(scene_root: Node3D) -> void:
	for name: String in REQUIRED:
		var node := scene_root.find_child(name, true, false)
		if node is Marker3D:
			_anchors[name] = (node as Marker3D).transform

func at(name: String) -> Transform3D:
	return _anchors.get(name, Transform3D())

func origin(name: String) -> Vector3:
	return at(name).origin

## The yaw a thing placed at this anchor should face.
func yaw(name: String) -> float:
	return at(name).basis.get_euler().y

func has(name: String) -> bool:
	return _anchors.has(name)

## Required anchors this set cannot answer for. Empty is the contract.
func missing() -> Array[String]:
	var out: Array[String] = []
	for name: String in REQUIRED:
		if not _anchors.has(name):
			out.append(name)
	return out

## Epsilon's reserved bay as a world-space box, in Hub-local coordinates.
##
## Derived from the `epsilon_presence` anchor, so a scene that moves
## Epsilon moves its bay with it rather than leaving a reservation
## floating where the installation used to be.
func epsilon_bay() -> AABB:
	var centre := origin("epsilon_presence")
	var size := Vector3(EPSILON_BAY_WIDTH, EPSILON_BAY_HEIGHT,
			EPSILON_BAY_DEPTH)
	return AABB(centre - Vector3(size.x / 2.0, 0.0, size.z / 2.0), size)

## Required anchors standing inside Epsilon's bay (art requirement 4).
##
## The ruling is that Epsilon keeps the bay and everything else moves, so
## this names what has to move rather than suggesting Epsilon shrink. The
## abandon console was the one that did: at x = -8.6 it sat squarely
## inside an 8.80 m installation nobody had reserved room for.
##
## `epsilon_presence` is exempt, being what the bay is for.
func intruders() -> Array[String]:
	var out: Array[String] = []
	var bay := epsilon_bay()
	for name: String in REQUIRED:
		if name == "epsilon_presence" or not _anchors.has(name):
			continue
		var p: Vector3 = origin(name)
		# Ground plan only: a board mounted 4.55 m up clears an
		# installation 3.55 m tall, and saying otherwise would move
		# something that is not in the way.
		if p.y >= EPSILON_BAY_HEIGHT:
			continue
		if p.x >= bay.position.x and p.x <= bay.position.x + bay.size.x \
				and p.z >= bay.position.z \
				and p.z <= bay.position.z + bay.size.z:
			out.append(name)
	return out

## Whether the bay fits in the room and clears the portal's doorway.
## Returns "" when it does, or what is wrong.
func bay_problem() -> String:
	var bay := epsilon_bay()
	if bay.position.x < -W / 2.0 \
			or bay.position.x + bay.size.x > W / 2.0:
		return "Epsilon's bay runs through a side wall"
	if bay.position.z < 0.0 or bay.position.z + bay.size.z > D:
		return "Epsilon's bay runs through the back or front wall"
	var portal := origin("main_portal")
	var half_door := PORTAL_DOOR_WIDTH / 2.0
	if bay.position.x + bay.size.x > portal.x - half_door \
			and bay.position.x < portal.x + half_door:
		return "Epsilon's bay stands in the portal doorway"
	return ""

## Required anchors that are outside the room they are supposed to be in.
## A station placed through a wall is reachable by nothing, and the fault
## is in the scene rather than in the code that trusted it.
##
## `lab_entrance` is exempt: it is ON the wall, by definition.
func outside_room() -> Array[String]:
	var out: Array[String] = []
	for name: String in REQUIRED:
		if name == "lab_entrance" or not _anchors.has(name):
			continue
		var p: Vector3 = origin(name)
		if absf(p.x) > W / 2.0 or p.y < 0.0 or p.y > H \
				or p.z < 0.0 or p.z > D:
			out.append(name)
	return out
