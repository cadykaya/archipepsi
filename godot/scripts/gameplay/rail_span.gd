class_name RailSpan
extends Node3D
## A section of track that swings into place and locks.
##
## **THE ONE PIECE OF THIS RAILWAY THAT PERSISTS.** Everything else the
## junction holds is live: which way the carrier is heading, how long a
## receiver has left to re-arm, how far through its travel a span has
## got. A span that has LOCKED is different in kind -- it is an accepted
## consequence, it survives leaving and reloading, and it is the thing
## the latch records. The owner ruling of 2026-09-05 (§5.4a) is exactly
## this line: accepted consequences persist, raw live signal values do
## not, and a system that saved both would be saving a photograph of a
## moment instead of a decision.
##
## **Aligned is not commissioned; LOCKED is.** The span travels for
## `TRAVEL_SECONDS` and the lock engages only at the end of it. A span
## resting in the right place with nothing holding it would shift under
## a loaded carrier, and a railway that let you ride an unlocked span
## would be teaching the player that the lock is decoration.
##
## **`restore()` is not `begin()` replayed.** Returning to a Zone whose
## latch has already fired puts the span straight into its locked pose
## and emits NOTHING. The latch is already recorded; a restore that
## re-emitted it would be the client reporting to the bridge a fact the
## bridge just told the client.

## Once it is locked, `locked_home` has been emitted exactly once, and
## the junction turns that into the latch.
signal locked_home(span: RailSpan)

## Long enough to watch a heavy thing move, short enough that a player
## who is being shot at is not held still by it.
const TRAVEL_SECONDS := 2.2
## How far aside the span rests when it is stowed. Far enough that
## "there is no track there" is legible from the dock.
const STOWED_DEGREES := 62.0
const BEAM_THICKNESS := 0.45

## Unique within the junction's package. Globally the latch is
## `package_id/latch_id` -- see `RailJunction.latch_ref`.
var latch_id := "span_aligned"
## Which of the carrier's links this span IS. `links[link]` joins dock
## `link` to dock `link + 1`.
var link := 0
var locked := false
var travelling := false

var _t := 0.0
var _gap := 6.0
var _body: StaticBody3D = null
var _theme := "concrete_facility"


static func create(latch_in: String, link_in: int, gap: float,
		theme := "concrete_facility") -> RailSpan:
	var made := RailSpan.new()
	made.latch_id = latch_in
	made.link = link_in
	made._gap = maxf(gap, 0.5)
	made._theme = theme
	made.name = "RailSpan_%s" % latch_in
	return made


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Span"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BEAM_THICKNESS, BEAM_THICKNESS, _gap)
	shape.shape = box
	_body.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.trim_mat(_theme)
	_body.add_child(mesh_node)
	# The span pivots at one end, so the beam's own centre is half a gap
	# along it: a span that rotated about its middle would sweep through
	# the dock behind it.
	_body.position = Vector3(0.0, 0.0, _gap * 0.5)
	add_child(_body)
	_place()


## Is this span track a carrier may cross?
##
## LOCKED, not aligned. Mid-travel is not "nearly commissioned"; it is
## not commissioned.
func commissioned() -> bool:
	return locked


func progress() -> float:
	return _t


## Send the span home. False when there was nothing to start.
func begin() -> bool:
	if locked or travelling:
		return false
	travelling = true
	return true


## One step of travel. Split out so a suite can step the machine by
## hand, in the idiom the carrier and the receivers already use.
func advance(delta: float) -> void:
	if not travelling:
		return
	_t = minf(_t + delta / TRAVEL_SECONDS, 1.0)
	_place()
	if _t < 1.0:
		return
	travelling = false
	locked = true
	locked_home.emit(self)


## THE RE-ENTRY PATH. Put the span where the accepted latch says it
## already is, and tell nobody: this is a recomputation, not an event.
func restore() -> void:
	_t = 1.0
	travelling = false
	locked = true
	_place()


func _physics_process(delta: float) -> void:
	advance(delta)


func _place() -> void:
	rotation.y = deg_to_rad(STOWED_DEGREES * (1.0 - _t))
