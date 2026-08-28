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

## The doorway through to the Lab. Shared with `EchoLab.OFFSET`, which is
## how the two rooms line up; `lab_driver.gd` pins that they still do.
const LAB_DOOR_Z := 6.0
const LAB_DOOR_WIDTH := 3.0
const LAB_DOOR_HEIGHT := 3.2

## `name -> Transform3D`, in Hub-local space. Rotation is the yaw a thing
## placed here should face; a wall station faces into the room.
static func defaults() -> Dictionary:
	return {
		"main_portal": _at(Vector3(0, 0, D - 1.2), 0.0),
		# Reserved. Beside the portal, facing the room: where a presence
		# would stand to watch the player leave.
		"epsilon_presence": _at(Vector3(-3.2, 0, D - 3.2), 0.0),
		"shop": _at(Vector3(-W / 2.0 + 1.6, 0, D * 0.45), -PI / 2.0),
		"archive_loadout": _at(Vector3(W / 2.0 - 1.6, 0, D * 0.45), PI / 2.0),
		"lab_entrance": _at(Vector3(-W / 2.0, 0, LAB_DOOR_Z), -PI / 2.0),
		"progression_display": _at(Vector3(0, 4.2, D - 1.4), 0.0),
		"postgame": _at(Vector3(W / 2.0 - 3.0, 0, D - 1.2), 0.0),
		"generation_loading": _at(Vector3(-W / 2.0 + 2.4, 0, D - 2.4), 0.0),
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
