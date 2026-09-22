class_name Actuator
extends Node3D
## THE COMMON ACTUATOR CONTRACT -- Amalgam §21.1, and the reason it is
## one class rather than twelve.
##
## §21.1's transition table is introduced as "the complete answer to what
## happens when a signal changes mid-motion, and it applies to every
## actuator kind". The engine had six concrete machines built one room at
## a time -- `ServiceShutter`, `RailCarrier`, `ShuttleDeck`,
## `RailJunction`, `PoweredLink`'s door, `LaunchSolver`'s pad -- and no
## two of them answered "the input reversed halfway" or "the power went
## out" the same way, because none of them had ever been asked. This is
## that answer, written once.
##
## **KINEMATIC, ALWAYS.** §21.1: machinery "moves along `path` by
## interpolating `t`, and is never physics-simulated. It pushes actors it
## collides with rather than being blocked by them, except as §21.2
## constrains." So `driven` is expected to be an `AnimatableBody3D` with
## `sync_to_physics` when it carries anybody, and this class never
## applies a force.
##
## **THE STATE IS `t` AND `direction`, which is exactly what §5.10 saves.**
## Nothing else here survives a reload, and nothing else needs to: the
## input is a live signal (§5.4a), the interlock's countdown is a
## fraction of a second, and power is a property of the room.
##
## **NINE OF THE TWELVE KINDS BUILD.** `Constants.ACTUATOR_KINDS` is the
## full twelve, because §21.1.1's power-loss table covers all twelve and
## a table with holes is worse than one with a refusal in it. The three
## constraint-driven kinds (§21.10 `WINCH`, `BRAKE`, `DRIVER`) drive a
## solver this engine does not have yet, so `create` REFUSES them by name
## rather than building something that moves but is not what the document
## describes. That refusal is the honest report of where the substrate
## ends; see `docs/ledgers/PROD_OV04.md`.

## Reached the position the input commands, and stopped.
signal arrived(at_t: float)
## A `LIFT` reached an indexed stop (§21.4).
signal stop_reached(index: int)
## §21.2: a closure was refused and the panel is going back up. Carries
## how long this door has wanted to be shut and could not be.
signal held_open(seconds: float)
## §21.2: fully open again after a refusal, retry interval elapsed.
signal reopened(refusals: int)
## `safe_closure = false` -- §21.2's authored crusher. Emitted EVERY
## frame the closure is in contact, because §25.1 hazard damage is a
## rate: the caller multiplies by its own delta. The body is the
## caller's to damage; this class never applies damage itself.
signal crushed(body: Node3D)
## Power came or went. §21.1.1's answer has already been applied when
## this fires.
signal power_changed(on: bool)
## §21.6: a branch change could not take effect because the rail was not
## clear, and is now queued.
signal branch_queued(index: int)
## §21.6: the queued (or immediate) branch change took effect.
signal branch_changed(index: int)
## §21.8: the controller turned its hazard on or off.
signal hazard_changed(running: bool)

const EPSILON := Constants.ACTUATOR_EPSILON

## One of `Constants.ACTUATOR_KINDS`.
var kind := "PATH_MACHINE"
## §21.1's kinematic waypoints, length >= 2. A `LIFT`'s entries are its
## stops (§21.4); a `RAIL_SWITCH`'s are its branches (§21.6).
var path: Array[Transform3D] = []
## Seconds for a full `0 -> 1` sweep. Zero means instant, which is what
## a controller with no geometry to move wants.
var travel_time := Constants.ACTUATOR_TRAVEL_SECONDS
## Where `reset()` animates back to, and where `t` starts.
var initial_t := 0.0
## §21.2. False marks an authored crusher and is legal only where a
## package declares one.
var safe_closure := true
## What this actuator moves. Null for a controller that moves nothing.
var driven: Node3D = null
## The volume §21.2's interlock watches. Only a `DOOR` needs one.
var obstruction: Area3D = null
## Actors whose distance from this junction decides §21.6's clearance.
## The carrier and the player, typically -- measured, not declared.
var rail_actors: Array[Node3D] = []

## §5.10's saved pair.
var t := 0.0
var direction := 0

var input_on := false
## §21.4's `VALUE` input. Ignored by every other kind.
var selector := 0
var powered := true

var _interlock: SafeClosure = null
var _resetting := false
var _live := true
var _hazard := false
var _wind_up := 0.0
var _branch := 0
var _queued := -1
var _last_stop := -1
var _refused: Array[String] = []


static func create(actuator_kind: String, waypoints: Array[Transform3D],
		seconds := Constants.ACTUATOR_TRAVEL_SECONDS) -> Actuator:
	var made := Actuator.new()
	made.name = "Actuator_%s" % actuator_kind
	made.kind = actuator_kind
	made.path = waypoints
	made.travel_time = seconds
	if not actuator_kind in Constants.ACTUATOR_KINDS:
		made._refused.append("'%s' is not one of §21.1's twelve kinds"
				% actuator_kind)
	if actuator_kind in ["WINCH", "BRAKE", "DRIVER"]:
		# §21.10's three drive a constraint solver rather than a `path`.
		# They are declared in the vocabulary and in the power-loss table
		# and they are NOT built here; see P13.
		made._refused.append(("'%s' is constraint-driven (§21.10) and "
				+ "needs the solver P13 owns") % actuator_kind)
	if waypoints.size() < 2 and not actuator_kind in [
			"HAZARD_CONTROLLER", "LAUNCHPAD"]:
		made._refused.append("§21.1 requires path length >= 2, got %d"
				% waypoints.size())
	return made


## Why this actuator will not run, empty when it will. A refused
## actuator holds still and reports; it never half-works.
func violations() -> Array[String]:
	return _refused.duplicate()


func buildable() -> bool:
	return _refused.is_empty()


func _ready() -> void:
	t = clampf(initial_t, 0.0, 1.0)
	if kind == "DOOR" and safe_closure:
		_interlock = SafeClosure.new()
		_interlock.reopened.connect(func(n: int) -> void: reopened.emit(n))
	_place()


## §21.1 row 1 and 2: the input is what commands the position.
func set_input(on: bool) -> void:
	input_on = on
	_resetting = false
	if kind == "HAZARD_CONTROLLER":
		_set_hazard(on and powered)
	if kind == "RAIL_SWITCH":
		_want_branch(1 if on else 0)


## §21.4's selector. Changing it mid-travel redirects immediately, which
## is the transition table's "reverse mid-motion" row read for a lift:
## nothing completes its current leg first.
func select(index: int) -> void:
	selector = clampi(index, 0, maxi(path.size() - 1, 0))
	_resetting = false


## §21.6's branch request. Applies now if the rail is clear within
## `RAIL_SWITCH_CLEARANCE_M`, and is QUEUED rather than refused if not.
func switch_to(index: int) -> void:
	_resetting = false
	_want_branch(clampi(index, 0, maxi(path.size() - 1, 0)))


func branch() -> int:
	return _branch


func queued_branch() -> int:
	return _queued


## §21.1.1. The kind decides, and the decision is applied here rather
## than folded into `_goal` so that "power lost mid-motion" is one event
## with one visible consequence.
func power(on: bool) -> void:
	if on == powered:
		return
	powered = on
	if not on:
		match Constants.ACTUATOR_POWER_LOSS.get(kind, "hold"):
			"close":
				# Doors close -- under the interlock, which is the whole
				# reason this is safe (§21.1.1).
				direction = -1
			"inert":
				_live = false
			"disable":
				_set_hazard(false)
			"unlit":
				direction = -1 if t > 0.0 else 0
			_:
				# EVERYTHING THAT CARRIES THE PLAYER HOLDS. The danger is
				# the motion itself, and no interlock helps with a lift
				# that drops or a bridge that retracts mid-crossing.
				direction = 0
	else:
		_live = true
		if kind == "HAZARD_CONTROLLER":
			_set_hazard(input_on)
	power_changed.emit(on)


## §21.1's reset row: move to `initial_t` at `travel_time` rate. It
## animates back; it does not teleport.
##
## **AND IT STAYS THERE UNTIL SOMETHING COMMANDS IT AGAIN.** Arriving is
## not what ends a reset -- if it were, an actuator whose input still
## said `ON` would travel dutifully back to `initial_t` and then set off
## again for `t = 1` the moment it got there, which is a reset that
## resets nothing. A reset parks the actuator at its authored position;
## the next `set_input`, `select` or `switch_to` is what releases it,
## which is what happens when the package's sources are reset too
## (§23.4) and one of them re-commands this input.
func reset() -> void:
	_resetting = true


func is_resetting() -> bool:
	return _resetting


## §21.7: an unpowered launchpad is inert geometry.
func is_live() -> bool:
	return _live


## §21.8.
func hazard_running() -> bool:
	return _hazard


## §21.8's "clears any wind-up".
func wind_up() -> float:
	return _wind_up


## §21.9. Lighting, `0.0` unlit and `1.0` lit.
func light_level() -> float:
	return t


## Seconds this door has wanted to be shut and has not been (§21.2).
func overrun() -> float:
	return _interlock.overrun if _interlock != null else 0.0


func refusals() -> int:
	return _interlock.refusals if _interlock != null else 0


## Seconds until this door tries to shut again (§21.2). Zero when it is
## not holding open for anybody. A readout rather than an internal,
## because "waiting, and for how long" is exactly what a control that
## appears not to work owes the player.
func retry_left() -> float:
	return _interlock.retry_left if _interlock != null else 0.0


## Where a `LIFT` currently is, `-1` between stops.
func at_stop() -> int:
	if path.size() < 2:
		return -1
	var span := 1.0 / float(path.size() - 1)
	var near := int(round(t / span))
	return near if absf(t - float(near) * span) <= EPSILON else -1


func _physics_process(delta: float) -> void:
	advance(delta)


## One step of the transition table.
func advance(delta: float) -> void:
	if not _refused.is_empty():
		return
	if kind == "HAZARD_CONTROLLER":
		_wind_up = _wind_up + delta if _hazard else 0.0
		return
	_apply_queued_branch()
	var goal := _goal(delta)
	if is_equal_approx(goal, t) or absf(goal - t) <= EPSILON:
		if direction != 0:
			t = goal
			direction = 0
			_place()
			arrived.emit(t)
			var stop := at_stop()
			if kind == "LIFT" and stop >= 0 and stop != _last_stop:
				_last_stop = stop
				stop_reached.emit(stop)
		return
	if travel_time <= 0.0:
		t = goal
		direction = 0
		_place()
		arrived.emit(t)
		return
	# §21.1's rate, and the reversal row falls straight out of it:
	# `goal` is recomputed every frame from the CURRENT input, so an
	# input that flips mid-motion simply changes the sign of this step
	# from wherever `t` happens to be. No snap, no pause, no completion
	# of the current leg.
	var step := delta / travel_time
	direction = signi(int(signf(goal - t)))
	t = clampf(t + step * float(direction), 0.0, 1.0)
	if absf(goal - t) <= step * 0.5 + EPSILON:
		t = goal
	_place()
	if is_equal_approx(t, goal):
		direction = 0
		arrived.emit(t)
		var landed := at_stop()
		if kind == "LIFT" and landed >= 0 and landed != _last_stop:
			_last_stop = landed
			stop_reached.emit(landed)


## What the input commands this frame, after §21.1.1 and §21.2 have had
## their say. Everything that can override the input does it here, so
## there is exactly one place that decides where the actuator is going.
func _goal(delta: float) -> float:
	if _resetting:
		return initial_t
	if not powered:
		match Constants.ACTUATOR_POWER_LOSS.get(kind, "hold"):
			"close":
				return _closing_goal(delta, 0.0)
			"unlit":
				return 0.0
			_:
				return t
	var commanded := 1.0
	if kind == "LIFT" and path.size() > 1:
		commanded = float(clampi(selector, 0, path.size() - 1)) \
				/ float(path.size() - 1)
	elif kind == "RAIL_SWITCH" and path.size() > 1:
		commanded = float(_branch) / float(path.size() - 1)
	elif not input_on:
		commanded = 0.0
	if kind == "DOOR":
		return _closing_goal(delta, commanded)
	return commanded


## §21.2, for whichever goal the input or power loss produced.
func _closing_goal(delta: float, commanded: float) -> float:
	var shutting := commanded < t or (commanded <= 0.0 and t > 0.0)
	var blocked := _blocked()
	if not safe_closure:
		# THE AUTHORED CRUSHER. It does not reverse; it reports the body
		# so the caller can deal `HAZARD` damage per §25.1.
		if shutting and blocked:
			for body: Node3D in _obstructing():
				crushed.emit(body)
		return commanded
	if _interlock == null:
		return commanded
	var order := _interlock.order(delta, shutting, blocked, t >= 1.0 - EPSILON)
	match order:
		SafeClosure.Order.REVERSE:
			held_open.emit(_interlock.overrun)
			return 1.0
		SafeClosure.Order.HOLD_OPEN:
			held_open.emit(_interlock.overrun)
			return 1.0
		_:
			return commanded


## §21.2's "the player or any `required = true` object". The required
## half is real: `TransportedObjects` puts every object a Zone declared
## `required` into `Constants.REQUIRED_OBJECT_GROUP`, so a crate a puzzle
## cannot finish without is as uncrushable as the player is.
func _blocked() -> bool:
	return not _obstructing().is_empty()


func _obstructing() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if obstruction == null or not is_instance_valid(obstruction):
		return out
	for body: Node3D in obstruction.get_overlapping_bodies():
		if body.is_in_group("player") \
				or body.is_in_group(Constants.REQUIRED_OBJECT_GROUP):
			out.append(body)
	return out


## §21.6. The change waits for the rail to clear; it is never dropped.
func _want_branch(index: int) -> void:
	if index == _branch and _queued < 0:
		return
	if _rail_is_clear():
		_branch = index
		_queued = -1
		branch_changed.emit(index)
		return
	_queued = index
	branch_queued.emit(index)


func _apply_queued_branch() -> void:
	if _queued < 0 or not _rail_is_clear():
		return
	_branch = _queued
	_queued = -1
	branch_changed.emit(_branch)


func _rail_is_clear() -> bool:
	for who: Node3D in rail_actors:
		if who == null or not is_instance_valid(who):
			continue
		if global_position.distance_to(who.global_position) \
				< Constants.RAIL_SWITCH_CLEARANCE_M:
			return false
	return true


func _set_hazard(running: bool) -> void:
	if running == _hazard:
		return
	_hazard = running
	if not running:
		# §21.8: disabling mid-cycle stops it in place and clears any
		# wind-up, so a hazard switched off and straight back on starts
		# its cycle rather than resuming a half-charged one.
		_wind_up = 0.0
	hazard_changed.emit(running)


## Interpolate `path` at `t`. `Transform3D.interpolate_with` is what
## makes a `PATH_MACHINE` able to be rotating machinery (§21.5) rather
## than only a slider.
func at(along: float) -> Transform3D:
	if path.is_empty():
		return global_transform
	if path.size() == 1:
		return path[0]
	var u := clampf(along, 0.0, 1.0) * float(path.size() - 1)
	var i := clampi(int(floor(u)), 0, path.size() - 2)
	return path[i].interpolate_with(path[i + 1], u - float(i))


func _place() -> void:
	if driven == null or not is_instance_valid(driven) or path.size() < 2:
		return
	driven.global_transform = at(t)
