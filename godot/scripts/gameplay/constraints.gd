class_name Constraints
extends Node3D
## THE EIGHT CONSTRAINT KINDS — Amalgam §14.8 and §26.5, pinned from
## Design 2.
##
## *"This is what Design 1 deferred and Design 2 ships."* A crane here is
## a `PULLEY` with a load on one end and a `WINCH` driving it, and its
## cargo **swings**. Design 1's crane was a `PATH_MACHINE` whose cargo was
## a child transform and could not. The Amalgam calls that "the single
## most visible difference between the two proposals in play", so it is
## the thing this class has to actually deliver rather than approximate.
##
## **TWO SOLVERS, AND THE SPLIT IS THE SUBSTRATE'S, NOT A PREFERENCE.**
## Godot has a hinge joint and a slider joint, with real angular and
## linear limits, genuinely simulated — so `HINGE`, `SLIDER`, `SEESAW`
## and a hinge `PENDULUM` are those. It has nothing for a TAUT-ONLY
## distance constraint (§14.8: "resists extension, not compression") or
## for two ropes sharing a total length through a fixed point, so `ROPE`,
## `CHAIN`, `PULLEY` and `COUNTERWEIGHT` are solved here, in
## `_physics_process`, at §14.8's **fixed eight iterations per tick**.
##
## Fixed, and not adaptive, because §23.5 check 20 replays a reference
## solution and a solver whose effort varied with load would make that
## replay mean nothing.
##
## **`breakable_at` IS ONLY OFFERED WHERE A FORCE IS REAL.** §14.8 checks
## it "against the solver's reported constraint force". The four kinds
## solved here report one exactly — it is the impulse this class applied,
## over the tick. A Godot joint does not expose its reaction, and the
## obvious proxy (a body's velocity change against free-fall) counts every
## contact the body made that tick as well. So `breakable_at` on a joint
## kind is **refused by name**, in the same way `Actuator` refuses the
## three kinds it cannot build: a number that is not the constraint's
## force would be worse than no number.
##
## A `Node3D` rather than a `Node`, although it renders nothing: the
## joints it builds are `Node3D`s placed by absolute coordinate, and a
## plain `Node` in the parent chain breaks `global_transform`
## propagation, so the joints and the bodies they join would be
## positioned in two different frames that happen to agree until somebody
## moves the room.
##
## **NOTHING IS CREATED AT RUNTIME EXCEPT A TETHER.** §14.8's rule, and
## the reason check 20 can replay anything at all: every other constraint
## is authored into the room, so the setup a replay runs against is known
## before the player touches it.

## §14.8: on break "the constraint is removed, `broken` is set, and both
## bodies keep their current velocity."
signal broke(constraint_id: String, at_force: float)
## §14.8 with §10.5: "A broken constraint on a `required` object rebuilds
## with the object at `home_transform`."
signal rebuilt(constraint_id: String)

const ITERATIONS := Constants.CONSTRAINT_SOLVER_ITERATIONS
const CORRECTION := Constants.CONSTRAINT_CORRECTION
## How hard a brake holds. Large enough to stop a §14.4-legal mass at a
## §14.4-legal speed, which is the heaviest thing a player can set moving.
const BRAKE_IMPULSE := 4000.0


## One constraint. Holds §5.10's saved pair for a constraint —
## `current_value` and `broken` — and nothing else that outlives a tick.
class Link extends RefCounted:
	var id := ""
	var kind := "ROPE"
	## Either body may be null, which means "anchored to the world at
	## `anchor`". A rope with both ends free is legal; one with neither
	## body is not, and `declare` refuses it.
	var a: RigidBody3D = null
	var b: RigidBody3D = null
	var anchor_a := Vector3.ZERO
	var anchor_b := Vector3.ZERO
	## The pivot a `PULLEY` runs over. Unused by the other kinds.
	var pivot := Vector3.ZERO
	## Rest length for the distance kinds; the authored total for a pulley.
	var length := 1.0
	var length_min := 0.1
	var length_max := 20.0
	var limit_lower := -PI
	var limit_upper := PI
	## NAN for unbreakable, which is the default.
	var breakable_at := NAN
	var required := false
	var home := Transform3D.IDENTITY
	var damping := 0.0

	var broken := false
	## §5.10's `current_value`: the rope's extension, the hinge's angle,
	## the slider's offset.
	var value := 0.0
	var last_value := 0.0
	var force := 0.0
	var joint: Node3D = null
	## WHO IS HOLDING THIS LOCKED, not whether anyone is.
	##
	## §23.5 rule 28 puts a real `BRAKE` on the same hinge as a
	## mandatory-route `DRIVER`, and §21.1.1 gives that driver an
	## implicit brake of its own on power loss. With one boolean, power
	## coming back means whichever of the two is serviced last decides
	## whether a suspended drawbridge is still held -- and the losing
	## order drops it. A set of holders has no such order.
	var holders: Dictionary = {}
	var locked := false
	var lock_at := 0.0
	var rest := Basis()

	func point_a() -> Vector3:
		return a.global_position if a != null else anchor_a

	func point_b() -> Vector3:
		return b.global_position if b != null else anchor_b

	func inv_mass(body: RigidBody3D) -> float:
		if body == null or body.freeze:
			return 0.0
		return 1.0 / body.mass if body.mass > 0.0 else 0.0


var _links: Dictionary = {}
var _order: Array[String] = []
var _refused: Array[String] = []


## Build the authored constraints. Returns what it refused and why; a
## refusal names the constraint rather than the batch, because one bad
## row must not cost the room its other seven.
func declare(specs: Array) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in specs:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var refusal := _add(raw as Dictionary)
		if refusal != "":
			out.append(refusal)
	_refused.append_array(out)
	return out


func _add(spec: Dictionary) -> String:
	var id := str(spec.get("constraint_id", ""))
	if id == "" or _links.has(id):
		return "constraint '%s' has no usable id" % id
	var kind := str(spec.get("kind", "")).to_upper()
	if not kind in Constants.CONSTRAINT_KINDS:
		return "'%s' is not one of §14.8's eight kinds (%s)" % [id, kind]
	var link := Link.new()
	link.id = id
	link.kind = kind
	link.a = spec.get("a", null) as RigidBody3D
	link.b = spec.get("b", null) as RigidBody3D
	if link.a == null and link.b == null:
		return "'%s' constrains nothing to nothing" % id
	link.anchor_a = spec.get("anchor_a", Vector3.ZERO) as Vector3
	link.anchor_b = spec.get("anchor_b", Vector3.ZERO) as Vector3
	link.pivot = spec.get("pivot", Vector3.ZERO) as Vector3
	link.limit_lower = float(spec.get("limit_lower", -PI))
	link.limit_upper = float(spec.get("limit_upper", PI))
	link.damping = float(spec.get("damping", 0.0))
	link.required = bool(spec.get("required", false))
	link.breakable_at = float(spec.get("breakable_at", NAN))
	if not is_nan(link.breakable_at) \
			and not kind in Constants.CONSTRAINT_BREAKABLE_KINDS:
		return ("'%s' asks for `breakable_at` on a %s, whose force this "
				% [id, kind] + "engine does not measure (§14.8)")
	link.length = float(spec.get("length",
			link.point_a().distance_to(link.point_b())))
	link.length_min = float(spec.get("length_min", 0.1))
	link.length_max = float(spec.get("length_max", maxf(link.length, 20.0)))
	if link.b != null:
		link.home = link.b.global_transform
		link.rest = link.b.global_transform.basis
	# §14.8'S CHAIN CAP, checked BEFORE anything is built. "A pulley
	# feeding a seesaw feeding a hinge is three", so what is counted is
	# the number of constraints reachable through shared bodies — the
	# chain this one would join, not the room's total.
	var chain := _chain_size(link) + 1
	if chain > Constants.CONSTRAINT_CHAIN_CAP:
		return ("'%s' would make a chain of %d linked constraints; §14.8 "
				% [id, chain] + "caps it at %d"
				% Constants.CONSTRAINT_CHAIN_CAP)
	_links[id] = link
	_order.append(id)
	if kind in Constants.CONSTRAINT_JOINT_KINDS:
		_build_joint(link)
	link.value = _measure(link)
	link.last_value = link.value
	return ""


## §14.8: "No constraint may be created at runtime except `TETHER`."
##
## The verb is P12's; this is the seam it will come through, and it is
## deliberately the ONLY door into `_links` that is not `declare`.
func tether(id: String, a: RigidBody3D, b: RigidBody3D,
		length: float, breakable_at: float) -> String:
	return _add({
		"constraint_id": id, "kind": Constants.CONSTRAINT_RUNTIME_CREATABLE[0],
		"a": a, "b": b, "length": length, "breakable_at": breakable_at,
	})


func ids() -> Array[String]:
	return _order.duplicate()


func has(id: String) -> bool:
	return _links.has(id)


func kind_of(id: String) -> String:
	return (_links[id] as Link).kind if _links.has(id) else ""


## §5.10's `current_value`.
func value_of(id: String) -> float:
	return (_links[id] as Link).value if _links.has(id) else 0.0


## The force this class applied over the last tick, for the four kinds it
## solves. Zero for a slack rope, and zero for a joint kind, which does
## not report one.
func force_of(id: String) -> float:
	return (_links[id] as Link).force if _links.has(id) else 0.0


func is_broken(id: String) -> bool:
	return (_links[id] as Link).broken if _links.has(id) else false


func refusals() -> Array[String]:
	return _refused.duplicate()


## §14.8: "Constrained objects never sleep while their constraint value
## is changing by more than `0.01` per tick." A body that fell asleep
## mid-swing would come to rest in mid-air.
func settled(id: String) -> bool:
	if not _links.has(id):
		return true
	var link: Link = _links[id]
	return absf(link.value - link.last_value) <= Constants.CONSTRAINT_SETTLED_DELTA


# -- §21.10's three actuators reach in here ---------------------------------

## `WINCH`: shorten or lengthen a rope at `rate` while its input is ON,
## between `length_min` and `length_max`. At a limit it stops and holds;
## it does not wrap or error.
func wind(id: String, metres: float) -> float:
	if not _links.has(id):
		return 0.0
	var link: Link = _links[id]
	link.length = clampf(link.length + metres, link.length_min,
			link.length_max)
	return link.length


func length_of(id: String) -> float:
	return (_links[id] as Link).length if _links.has(id) else 0.0


func length_min_of(id: String) -> float:
	return (_links[id] as Link).length_min if _links.has(id) else 0.0


func length_max_of(id: String) -> float:
	return (_links[id] as Link).length_max if _links.has(id) else 0.0


## `BRAKE`: lock a hinge or slider AT ITS CURRENT VALUE, whatever it is.
## §21.10: "A `BRAKE` engaging mid-swing locks at the current value. It
## does not snap to a limit."
func lock(id: String, on: bool, holder := "brake") -> void:
	if not _links.has(id):
		return
	var link: Link = _links[id]
	if on:
		link.holders[holder] = true
	else:
		link.holders.erase(holder)
	var now := not link.holders.is_empty()
	if now == link.locked:
		return
	link.locked = now
	link.lock_at = link.value
	_apply_lock(link)


func is_locked(id: String) -> bool:
	return (_links[id] as Link).locked if _links.has(id) else false


## `DRIVER`: apply torque toward a target. Torque, not position — it can
## be resisted by mass and it can stall.
func drive(id: String, toward: float, rate: float, torque: float) -> void:
	if not _links.has(id):
		return
	var link: Link = _links[id]
	if link.joint == null or not (link.joint is HingeJoint3D):
		return
	if link.locked:
		# A DRIVER CANNOT TURN A LOCKED HINGE. §23.5 rule 28 puts a
		# `BRAKE` on the same hinge as a mandatory-route `DRIVER`, so the
		# two meeting is a designed situation rather than a mistake --
		# and the brake wins, which is what stalls the driver instead of
		# letting the last writer to the motor decide.
		return
	var hinge := link.joint as HingeJoint3D
	if torque <= 0.0:
		hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		return
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
			signf(toward - link.value) * absf(rate))
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, torque)


func release(id: String) -> void:
	if not _links.has(id):
		return
	var link: Link = _links[id]
	if link.joint != null and (link.joint is HingeJoint3D) \
			and not link.locked:
		(link.joint as HingeJoint3D).set_flag(
				HingeJoint3D.FLAG_ENABLE_MOTOR, false)


# -- the solver -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	solve(delta)


## One tick. §14.8's eight iterations, then one break check.
##
## **THE ITERATIONS SOLVE AGAINST A WORKING VELOCITY, not against the
## body's.** `apply_central_impulse` outside `_integrate_forces` is
## queued on the physics server and does NOT change `linear_velocity`
## until the next step. So eight Gauss-Seidel passes each read the same
## unchanged velocity, each compute the same full correction, and eight
## full corrections land on a body that needed one: the load is flung
## upward, the rope goes slack, it falls, and the next tick over-corrects
## harder. That diverges to 1e18 in about a second, which is exactly what
## it did.
##
## The fix is what an iterative solver is supposed to do anyway: carry
## the velocity change in hand across the iterations, so each pass sees
## what the passes before it did, and hand the physics server ONE impulse
## per body at the end.
func solve(delta: float) -> void:
	if delta <= 0.0:
		return
	# `body -> Vector3` of velocity change agreed so far this tick.
	var working: Dictionary = {}
	var pull: Dictionary = {}
	for id: String in _order:
		(_links[id] as Link).force = 0.0
		pull[id] = 0.0
	# GAUSS-SEIDEL, EIGHT PASSES, IN DECLARATION ORDER. The order is
	# fixed rather than sorted so two runs of the same room converge the
	# same way, which is the whole reason the count is fixed too.
	for _i in ITERATIONS:
		for id: String in _order:
			var link: Link = _links[id]
			if link.broken or not link.kind in Constants.CONSTRAINT_SOLVED_KINDS:
				continue
			pull[id] = float(pull[id]) + _solve_one(link, delta, working)
	for body: Variant in working:
		var rigid: RigidBody3D = body
		if not is_instance_valid(rigid):
			continue
		rigid.apply_central_impulse((working[body] as Vector3) * rigid.mass)
	for id: String in _order:
		var link: Link = _links[id]
		# THE FORCE IS THE IMPULSE THIS CLASS ACTUALLY APPLIED, summed
		# over the tick's iterations and divided by the tick. That is
		# what §14.8 means by "the solver's reported constraint force",
		# and it is a number no Godot joint can give.
		link.force = absf(float(pull[id])) / delta
		link.last_value = link.value
		link.value = _measure(link)
		# §14.8: "Constrained objects never sleep while their constraint
		# value is changing by more than `0.01` per tick." A body that
		# fell asleep mid-swing would come to rest in mid-air, and the
		# solver would then report nothing because nothing is moving --
		# which is exactly how a hanging load looks like a bug.
		if link.b != null and absf(link.value - link.last_value) \
				> Constants.CONSTRAINT_SETTLED_DELTA:
			link.b.sleeping = false
			if link.a != null:
				link.a.sleeping = false
		if link.locked:
			# A LOCKED JOINT IS HELD AT THE VALUE IT WAS LOCKED AT, and
			# the limits are re-asserted each tick because a `DRIVER` on
			# the same hinge may have moved them.
			_apply_lock(link)
		_check_break(link, delta)


## The velocity this body will have once the impulses agreed so far this
## tick are applied. Null is the world, which does not move.
func _working_velocity(body: RigidBody3D, working: Dictionary) -> Vector3:
	if body == null:
		return Vector3.ZERO
	return body.linear_velocity + (working.get(body, Vector3.ZERO) as Vector3)


func _agree(body: RigidBody3D, working: Dictionary, change: Vector3) -> void:
	if body == null or body.freeze:
		return
	working[body] = (working.get(body, Vector3.ZERO) as Vector3) + change


## Returns the impulse it applied, so the caller can total it.
func _solve_one(link: Link, delta: float, working: Dictionary) -> float:
	match link.kind:
		"PULLEY", "COUNTERWEIGHT":
			return _solve_pulley(link, delta, working)
		_:
			return _solve_rope(link, delta, working)


## A TAUT-ONLY DISTANCE CONSTRAINT. §14.8: "resists extension, not
## compression" -- so a slack rope does nothing at all, which is what
## makes a suspended load swing rather than hang on a stick.
func _solve_rope(link: Link, delta: float, working: Dictionary) -> float:
	var pa := link.point_a()
	var pb := link.point_b()
	var span := pb - pa
	var dist := span.length()
	if dist <= link.length or dist <= 0.0001:
		return 0.0
	var n := span / dist
	var inv_a := link.inv_mass(link.a)
	var inv_b := link.inv_mass(link.b)
	var denom := inv_a + inv_b
	if denom <= 0.0:
		return 0.0
	var closing := (_working_velocity(link.b, working)
			- _working_velocity(link.a, working)).dot(n)
	var bias := CORRECTION * (dist - link.length) / delta
	var impulse := (-bias - closing) / denom
	if impulse > 0.0:
		# The constraint may only PULL. A positive impulse here would be
		# pushing the ends apart, which is the compression a rope does
		# not resist.
		return 0.0
	_agree(link.b, working, impulse * n * inv_b)
	_agree(link.a, working, -impulse * n * inv_a)
	if link.damping > 0.0 and link.b != null:
		_agree(link.b, working, -_working_velocity(link.b, working)
				* link.damping * delta)
	return impulse


## TWO ROPES SHARING A TOTAL LENGTH THROUGH A FIXED POINT. The
## constraint is on the SUM, which is what makes one end rise as the
## other falls rather than the two being independently tethered.
func _solve_pulley(link: Link, delta: float, working: Dictionary) -> float:
	var pa := link.point_a()
	var pb := link.point_b()
	var d1 := pa.distance_to(link.pivot)
	var d2 := pb.distance_to(link.pivot)
	if d1 + d2 <= link.length or d1 <= 0.0001 or d2 <= 0.0001:
		return 0.0
	var n1 := (pa - link.pivot) / d1
	var n2 := (pb - link.pivot) / d2
	var inv_a := link.inv_mass(link.a)
	var inv_b := link.inv_mass(link.b)
	var denom := inv_a + inv_b
	if denom <= 0.0:
		return 0.0
	var rate := n1.dot(_working_velocity(link.a, working)) \
			+ n2.dot(_working_velocity(link.b, working))
	var bias := CORRECTION * (d1 + d2 - link.length) / delta
	var impulse := (rate + bias) / denom
	if impulse <= 0.0:
		return 0.0
	_agree(link.a, working, -impulse * n1 * inv_a)
	_agree(link.b, working, -impulse * n2 * inv_b)
	return impulse


## §14.8: checked ONCE PER TICK, and on break "the constraint is removed,
## `broken` is set, and both bodies keep their current velocity."
func _check_break(link: Link, _delta: float) -> void:
	if link.broken or is_nan(link.breakable_at):
		return
	if link.force < link.breakable_at:
		return
	link.broken = true
	link.force = 0.0
	broke.emit(link.id, link.breakable_at)
	if not link.required:
		return
	# §10.5: A BROKEN CONSTRAINT ON A `required` OBJECT REBUILDS with the
	# object at `home_transform`. A required object left hanging by a
	# snapped rope is a puzzle nobody can finish.
	link.broken = false
	if link.b != null:
		link.b.global_transform = link.home
		link.b.linear_velocity = Vector3.ZERO
		link.b.angular_velocity = Vector3.ZERO
	rebuilt.emit(link.id)


func _measure(link: Link) -> float:
	match link.kind:
		"PULLEY", "COUNTERWEIGHT":
			return link.point_a().distance_to(link.pivot) \
					+ link.point_b().distance_to(link.pivot)
		"HINGE", "SEESAW", "PENDULUM", "SLIDER":
			return _joint_value(link)
		_:
			return link.point_a().distance_to(link.point_b())


## How far a joint has turned or slid from where it was authored.
##
## Measured against the JOINT, not against the body's own axes, because
## the brake sets Godot's limits in the joint's frame and a readout in a
## different frame would be a readout that disagrees with the lock.
func _joint_value(link: Link) -> float:
	if link.b == null or link.joint == null:
		return 0.0
	if link.kind == "SLIDER":
		return (link.b.global_position - link.joint.global_position).dot(
				link.joint.global_transform.basis.x)
	# THE COMPONENT IS THE AXIS `_build_joint` GAVE IT. A gate turns
	# about the vertical (world Y); a seesaw and a pendulum swing about
	# a level bar (world Z). Reading the wrong component gives a number
	# that moves when the joint does not.
	var turned := link.rest.inverse() * link.b.global_transform.basis
	return turned.get_euler().y if link.kind == "HINGE" \
			else turned.get_euler().z


## Godot's own joint for the four kinds it has. `SEESAW` is "a `HINGE`
## with its axis horizontal and its pivot offset authored", and
## `PENDULUM` "a `HINGE` or `ROPE` with an authored rest position and
## damping" -- so three of the four are one joint under different framing,
## exactly as §14.8 describes them.
##
## **THE AXIS IS SET EXPLICITLY** rather than left at the default.
## Godot's hinge turns about its local Z, which at identity is world Z --
## horizontal. That is right for a seesaw and a pendulum and wrong for a
## gate, which turns about the vertical. Leaving it implicit is how a
## door ends up swinging like a cat flap.
func _build_joint(link: Link) -> void:
	if link.b == null:
		return
	var at := link.anchor_a if link.a == null else link.a.global_position
	if link.kind == "SLIDER":
		var slider := SliderJoint3D.new()
		add_child(slider)
		slider.global_position = at
		slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER,
				link.limit_lower)
		slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER,
				link.limit_upper)
		_couple(slider, link)
		link.joint = slider
		return
	var hinge := HingeJoint3D.new()
	add_child(hinge)
	hinge.global_position = at
	if link.kind == "HINGE":
		# Z onto world Y: a gate turns about the vertical.
		hinge.rotate_x(-PI * 0.5)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, link.limit_lower)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, link.limit_upper)
	_couple(hinge, link)
	link.joint = hinge


func _couple(joint: Node3D, link: Link) -> void:
	if link.a != null:
		joint.set("node_a", link.a.get_path())
	joint.set("node_b", link.b.get_path())


## A BRAKE IS A MOTOR HELD AT ZERO, not a pair of limits squeezed onto
## the current angle.
##
## The limits were the obvious implementation and they are wrong: Godot
## measures them in the joint's own reference and this class measures
## `value` in the body's, so "lock it where it is" would have snapped the
## hinge to wherever those two happened to disagree. A motor with a
## target velocity of zero and the brake's holding torque is what a brake
## physically IS, it locks at whatever value the hinge has without
## needing to name it, and it releases by switching off.
##
## A slider has no motor, so that one really is the limits -- and its
## value is measured in the joint's frame above so the two agree.
func _apply_lock(link: Link) -> void:
	if link.joint == null:
		return
	if link.kind == "SLIDER":
		var lower := link.lock_at if link.locked else link.limit_lower
		var upper := link.lock_at if link.locked else link.limit_upper
		(link.joint as SliderJoint3D).set_param(
				SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, lower)
		(link.joint as SliderJoint3D).set_param(
				SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, upper)
		return
	var hinge := link.joint as HingeJoint3D
	if not link.locked:
		hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		return
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, BRAKE_IMPULSE)


## The number of constraints already reachable from either of this one's
## bodies, following shared bodies. §14.8's chain, counted as a chain.
func _chain_size(candidate: Link) -> int:
	var seen: Dictionary = {}
	var bodies: Array = []
	if candidate.a != null:
		bodies.append(candidate.a)
	if candidate.b != null:
		bodies.append(candidate.b)
	var walked: Dictionary = {}
	while not bodies.is_empty():
		var body: RigidBody3D = bodies.pop_back()
		if walked.has(body):
			continue
		walked[body] = true
		for id: String in _order:
			var link: Link = _links[id]
			if link.a != body and link.b != body:
				continue
			if seen.has(id):
				continue
			seen[id] = true
			if link.a != null:
				bodies.append(link.a)
			if link.b != null:
				bodies.append(link.b)
	return seen.size()
