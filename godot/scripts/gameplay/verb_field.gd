class_name VerbField
extends Node
## §14.3 `LIGHTEN_FIELD` / `ANCHOR_FIELD` -- RUNTIME ONLY (O05-08.4).
##
## "Scales `mass_kg` of every eligible object whose origin is inside a
## sphere of `radius` at the aim point, for `duration`. `LIGHTEN_FIELD`
## uses `magnitude < 1.0`; `ANCHOR_FIELD` uses `magnitude > 1.0`. Fields do
## not stack. An object inside two fields takes the one applied later.
## Fields never move objects. They change what other forces can do to
## them." §14.4: a field radius ceiling of 8.0 m, and a multiplier range
## of 0.30 to 3.00.
##
## **KILOGRAMS, NOT CLASS.** A field scales the body's actual mass, and its
## class follows from the kilograms (§10.2: "Derivation rather than
## declaration means `LIGHTEN` has a defined effect on any object"). The
## `lightened` and `anchored` Statuses (Design 5 §15.2) do the other
## thing -- they step the CLASS and leave the kilograms alone -- and the two
## are kept apart: a field never touches `statuses`, a Status never touches
## `mass`, and a body under both reads the class its scaled kilograms
## derive, stepped by its Status.
##
## **MEMBERSHIP IS CONTINUOUS -- a reading, stated.** "Every eligible
## object whose origin is inside a sphere ... for `duration`" and "an
## object inside two fields" read as a volume that governs what is in it
## while it lasts: a body that comes in is scaled, one that leaves gets its
## own mass back, and one that a later field takes returns to an earlier
## one still running when the later one ends.
##
## **NOT STACKED.** The scale always applies to the body's OWN mass
## (`ManipulableBody.own_mass`), never to an already-scaled one.
##
## **ELIGIBLE** is judged on the body's own mass, not the scaled one, or an
## ANCHOR_FIELD that took a 180 kg cart to 450 kg would make it FIXED and
## drop it from the very field that did so. A `ManipulableBody` whose own
## class is not FIXED (§14.2 -- which a Status `anchored` makes it), and
## not a required object whose package withholds physics. The profiles
## have no `verb_mass_limit`. An enemy has no `mass_kg` here to scale and
## is left alone; the player never.
##
## Cast time (0.15 s) is the activation's (§12.2/§12.3), and nothing
## delivers the verb; a field begins when invoked.

signal ended(reason: String)

const PROFILES := {
	"ab_mass_light": {"range_m": 20.0, "radius_m": 7.0, "duration": 10.0,
			"magnitude": 0.35},
	"ab_mass_heavy": {"range_m": 20.0, "radius_m": 6.0, "duration": 8.0,
			"magnitude": 2.50},
}
const RADIUS_CEILING := 8.0
const MULTIPLIER_MIN := 0.30
const MULTIPLIER_MAX := 3.00
## How many bodies one volume query may return. A room holds far fewer.
const MAX_BODIES := 256

const LIGHTEN := "LIGHTEN_FIELD"
const ANCHOR := "ANCHOR_FIELD"
## Why a field was refused.
const WRONG_DIRECTION := "wrong_direction"
const NOT_A_FIELD := "not_a_field"
## Why a field ended.
const EXPIRED := "expired"

var verb := ""
var centre := Vector3.ZERO
var radius := 0.0
var magnitude := 1.0
var left := 0.0
var end_reason := ""
## The order fields were applied in: the later one wins a body.
var applied_at := 0
## The bodies this field scales now.
var governed: Array = []

static var _applied := 0


## Lay a field at `aim_point`, or say why not.
static func begin(field_verb: String, eye: Vector3, aim_point: Vector3,
		profile: String, space: PhysicsDirectSpaceState3D, host: Node,
		exclude: Array[RID] = []) -> Dictionary:
	if field_verb != LIGHTEN and field_verb != ANCHOR:
		return {"applied": false, "refused": NOT_A_FIELD}
	if not PROFILES.has(profile):
		return {"applied": false, "refused": Manipulation.UNKNOWN_PROFILE}
	var numbers: Dictionary = PROFILES[profile]
	var scale := clampf(float(numbers["magnitude"]), MULTIPLIER_MIN,
			MULTIPLIER_MAX)
	if (field_verb == LIGHTEN) != (scale < 1.0):
		return {"applied": false, "refused": WRONG_DIRECTION}
	if eye.distance_to(aim_point) > float(numbers["range_m"]):
		return {"applied": false, "refused": Manipulation.OUT_OF_REACH}
	if not Manipulation._clear(space, eye, aim_point, exclude):
		return {"applied": false, "refused": Manipulation.NO_LINE_OF_SIGHT}
	_applied += 1
	var field := VerbField.new()
	field.name = "VerbField_%d" % _applied
	field.verb = field_verb
	field.centre = aim_point
	field.radius = minf(float(numbers["radius_m"]), RADIUS_CEILING)
	field.magnitude = scale
	field.left = float(numbers["duration"])
	field.applied_at = _applied
	host.add_child(field)
	field._take_in(space)
	return {"applied": true, "refused": "", "field": field}


func active() -> bool:
	return end_reason == ""


func end(reason: String) -> void:
	if end_reason != "":
		return
	end_reason = reason
	for body: Variant in governed.duplicate():
		_give_back(body)
	ended.emit(reason)
	queue_free()


func _physics_process(delta: float) -> void:
	if end_reason != "":
		return
	left -= delta
	# A hair under zero-ish, because 600 ticks of 1/60 s sum to a float a
	# hair under 10.0: the field ends on the 600th.
	if left <= 0.0001:
		end(EXPIRED)
		return
	_take_in(get_viewport().world_3d.direct_space_state)


## The field's membership, this tick: give back what left, take what came
## in -- unless a field applied later already has it.
func _take_in(space: PhysicsDirectSpaceState3D) -> void:
	var inside := _eligible_inside(space)
	for body: Variant in governed.duplicate():
		if not is_instance_valid(body) or not inside.has(body):
			_give_back(body)
	for body: ManipulableBody in inside:
		if body.field == self:
			continue
		var holder := body.field
		if holder != null and is_instance_valid(holder) \
				and holder.active():
			if holder.applied_at > applied_at:
				continue
			holder.governed.erase(body)
		_take(body)


func _take(body: ManipulableBody) -> void:
	if body.own_mass < 0.0:
		body.own_mass = body.mass
	body.mass = body.own_mass * magnitude
	body.field = self
	body.sleeping = false
	governed.append(body)


## Give a body its own mass back -- if this field is still the one that
## scaled it.
func _give_back(body: Variant) -> void:
	governed.erase(body)
	if not is_instance_valid(body):
		return
	var held := body as ManipulableBody
	if held.field != self:
		return
	held.mass = held.own_mass
	held.own_mass = -1.0
	held.field = null
	held.sleeping = false


func _eligible_inside(space: PhysicsDirectSpaceState3D) -> Array:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, centre)
	query.collide_with_areas = false
	var out: Array = []
	for hit: Dictionary in space.intersect_shape(query, MAX_BODIES):
		var body := hit.get("collider") as ManipulableBody
		if body == null or out.has(body) \
				or body.global_position.distance_to(centre) > radius:
			continue
		var own := body.own_mass if body.own_mass >= 0.0 else body.mass
		if MassClass.read(own, not body.constrained, body.statuses) \
				== MassClass.FIXED:
			continue
		if body.is_in_group(Constants.REQUIRED_OBJECT_GROUP) \
				and not body.physics_permitted:
			continue
		out.append(body)
	return out


## The field's host left the tree -- the room unloaded -- taking it along.
func _exit_tree() -> void:
	if end_reason == "":
		end_reason = "host_gone"
		for body: Variant in governed.duplicate():
			_give_back(body)
		ended.emit(end_reason)
