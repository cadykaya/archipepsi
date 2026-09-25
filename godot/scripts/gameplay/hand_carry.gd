class_name HandCarry
extends RefCounted
## ORDINARY HAND CARRY: the base-kit interaction, not an Echo verb.
##
## Design 2 §10.3–10.4, which pin Design 1 §10.2–10.3 with one change to
## eligibility. The Amalgam §10 pins Design 2 §10 entire. So:
##
## - **Eligibility is kilograms.** An object is carriable if its
##   `carriable` flag is set **and** `mass_kg <= CARRY_MASS_KG` (60 kg,
##   Design 2 §10.3). Being `MEDIUM` is not a licence, and neither is the
##   manipulation provider's 120 kg `ENVELOPE_MASS_KG`, which bounds what
##   a PUSH may act on, not what a hand may hold. `LIGHTENED` changes an
##   object's CLASS and never its kilograms, so it does not make a heavy
##   object carriable.
## - **The pose.** The object is held 1.20 m forward of the eye and
##   0.20 m below it, following the view with 0.08 s smoothing.
## - **Collision.** A carried object collides with world geometry and
##   passes through actors. It is swept along the line from the player to
##   its carry position with its own shape, and held at the nearest
##   unoccluded point. If no such point lies 0.40 m or more out from the
##   player, it is dropped at the player's feet. It is never pulled
##   through a wall, a closed gate or an opening smaller than itself.
## - **Movement.** `WALK_SPEED` × 0.85 while the object reads `MEDIUM`,
##   with no penalty for `LIGHT`. This is the class, so a `LIGHTENED` cell
##   costs nothing to walk with even though its kilograms are unchanged.
## - **Blocked while carrying:** the Weapon primary (the Static Pulse)
##   and Mobility (the `mobility` slot). Design 1's list also names
##   melee, the Weapon secondary, weapon cycling and hacking; the game
##   has none of those. **Permitted:** movement, jump, look, Abilities
##   (the Echo, utility and consumable slots), `interact`, pause and the
##   Archive.
## - **Drop is zero-velocity, at the carry position.** There is no throw
##   (§10.4): PUSH is the throw. `interact` while looking at a compatible
##   consumer installs the object instead (§10.3's socket rule).

const FORWARD_M := 1.20
const BELOW_EYE_M := 0.20
const SMOOTHING_S := 0.08
const MEDIUM_SPEED_FACTOR := 0.85
const DROP_CLEARANCE_M := 0.40

## Whatever the player is holding, or null.
var body: ManipulableBody = null
var player: Player = null

## THE VIEW, SMOOTHED -- not the position. The object is carried with the
## player and follows where they look with 0.08 s of lag. Smoothing the
## world position instead trailed it half a metre behind a walking player
## and, after any fast swing, dragged it through the player's own body.
var _dir := Vector3.ZERO
var _dist := FORWARD_M
var _saved_layer := 1
var _saved_mask := 1
## What stopped the last occluded carry, by node name: evidence for a
## drop the player did not ask for. Empty until one happens.
var last_blocker := ""
## Bodies just put down that still overlap the player. They keep a
## collision exception with the player until the two separate, so a drop
## at the player's feet is not resolved as a violent depenetration.
var _released: Array[ManipulableBody] = []


func _init(owner_player: Player) -> void:
	player = owner_player


func holding() -> bool:
	return body != null and is_instance_valid(body)


## Why `target` cannot be picked up, or "" if it can. The order matters:
## an object that is bolted, installed or not handheld is refused for
## that reason before its weight is mentioned.
## What the carry says of an anchored body (Design 5 §15.2's sentence).
const ANCHORED := "FIXED IN PLACE"

static func refusal(target: ManipulableBody) -> String:
	if target == null or not is_instance_valid(target):
		return "NOTHING TO CARRY"
	if target.installed_in != null and is_instance_valid(target.installed_in):
		return "INSTALLED"
	if target.constrained:
		return "BOLTED DOWN"
	if target.anchored():
		return ANCHORED
	if not target.carriable:
		return "CAN'T CARRY THAT"
	if target.mass > Constants.CARRY_MASS_KG:
		return "TOO HEAVY TO CARRY · %s (limit %s)" % [kg(target.mass),
				kg(Constants.CARRY_MASS_KG)]
	return ""


## Kilograms as a reader wants them: whole numbers bare, and anything
## else to two places, so a refusal at 60.01 kg does not read "60 kg".
static func kg(value: float) -> String:
	if absf(value - roundf(value)) < 0.005:
		return "%d kg" % roundi(value)
	return "%.2f kg" % value


static func prompt_for(target: ManipulableBody) -> String:
	var why := refusal(target)
	if why != "":
		return why
	return "[E] PICK UP · %s" % kg(target.mass)


## The speed multiplier carrying imposes right now.
func speed_factor() -> float:
	if holding() and body.mass_class() == MassClass.MEDIUM:
		return MEDIUM_SPEED_FACTOR
	return 1.0


func try_pick_up(target: ManipulableBody) -> bool:
	if holding():
		return false
	var why := refusal(target)
	if why != "":
		player.carry_feedback.emit(why, false)
		return false
	body = target
	body.carried_by = player
	_saved_layer = body.collision_layer
	_saved_mask = body.collision_mask
	# CARRIED, NOT INVENTORIED. It stays a body in the world, moved
	# kinematically along the swept carry line. Layer 0 lets actors and
	# the player's own ray pass through it, and the sweep below is what
	# stops it at geometry.
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	# FROM WHERE IT LAY, swung into the carry pose rather than snapped.
	var rel := body.global_position - _anchor()
	_dist = clampf(rel.length(), DROP_CLEARANCE_M, 3.0)
	_dir = rel.normalized() if rel.length() > 0.01 else _view()
	_released.erase(body)
	player.carry_feedback.emit("CARRYING · %s" % kg(body.mass), true)
	return true


## `interact` while holding: install into `target` if it takes this
## object, otherwise put it down where it is.
func on_interact(target: Node) -> void:
	if not holding():
		return
	if target != null and target.has_method("install_refusal"):
		var why: String = target.install_refusal(body)
		if why == "":
			var installing := body
			_detach(false)
			target.install(installing)
			return
		player.carry_feedback.emit(why, false)
		return
	release("drop")


## Put the object down at its current carry position, at rest.
func release(reason: String) -> void:
	if not holding():
		body = null
		return
	var putting := body
	_detach(true)
	player.carry_feedback.emit(
			"DROPPED" if reason == "drop" else "DROPPED · %s" % reason,
			true)
	putting.dropped_by_carry.emit(reason)


func _detach(to_world: bool) -> void:
	var putting := body
	body = null
	_dir = Vector3.ZERO
	putting.carried_by = null
	if not to_world:
		return
	putting.collision_layer = _saved_layer
	putting.collision_mask = _saved_mask
	putting.add_collision_exception_with(player)
	_released.append(putting)
	putting.freeze = false
	putting.linear_velocity = Vector3.ZERO
	putting.angular_velocity = Vector3.ZERO
	putting.sleeping = false


## Once per physics frame, after the camera has moved.
func update(delta: float) -> void:
	_forget_separated()
	if not holding():
		body = null
		return
	# ANCHORED IN THE HANDS: it is fixed where it is, so the hands let go
	# and the anchor holds it there.
	if body.anchored():
		release(ANCHORED)
		return
	var alpha := 1.0 - exp(-delta / maxf(SMOOTHING_S, 0.001))
	var view := _view()
	if _dir == Vector3.ZERO:
		_dir = view
	_dir = _dir.slerp(view, alpha).normalized()
	_dist = lerpf(_dist, FORWARD_M, alpha)
	var anchor := _anchor()
	var free := _free_fraction(anchor, anchor + _dir * _dist)
	# OCCLUDED, AND NO POINT 0.40 M OUT IS CLEAR: at the player's feet.
	# The rule is about geometry in the way; a short unobstructed line is
	# only the swing into the pose.
	if free < 1.0 and _dist * free < DROP_CLEARANCE_M:
		last_blocker = _blocker(anchor, anchor + _dir * _dist)
		var putting := body
		putting.global_position = player.global_position \
				+ Vector3(0.0, _half_height(putting) + 0.02, 0.0)
		_detach(true)
		player.carry_feedback.emit("NO ROOM · DROPPED AT YOUR FEET", false)
		putting.dropped_by_carry.emit("occluded")
		return
	body.global_position = anchor + _dir * _dist * free


## 0.20 m below the eye: the line a carried object is swept along starts
## here.
func _anchor() -> Vector3:
	return player.camera.global_position + Vector3.DOWN * BELOW_EYE_M


func _view() -> Vector3:
	return (-player.camera.global_transform.basis.z).normalized()


## How far along `from -> to` the carried shape can move before it touches
## anything that is not the player, an actor or itself.
func _free_fraction(from: Vector3, to: Vector3) -> float:
	var hull := body.get_node_or_null("hull") as CollisionShape3D
	if hull == null or hull.shape == null:
		return 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.transform = Transform3D(body.global_transform.basis, from)
	query.motion = to - from
	query.collide_with_areas = false
	var exclude: Array[RID] = [player.get_rid(), body.get_rid()]
	for raw: Node in player.get_tree().get_nodes_in_group("enemies"):
		if raw is CollisionObject3D:
			exclude.append((raw as CollisionObject3D).get_rid())
	query.exclude = exclude
	var space := player.get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	if fractions.is_empty():
		return 1.0
	return clampf(fractions[0], 0.0, 1.0)


## Which collider the carried shape meets along `from -> to`, by name.
func _blocker(from: Vector3, to: Vector3) -> String:
	var hull := body.get_node_or_null("hull") as CollisionShape3D
	if hull == null or hull.shape == null:
		return ""
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.transform = Transform3D(body.global_transform.basis, from)
	query.motion = to - from
	query.exclude = [player.get_rid(), body.get_rid()]
	var space := player.get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	if fractions.size() < 2:
		return ""
	query.transform = Transform3D(body.global_transform.basis,
			from + (to - from) * fractions[1])
	query.motion = Vector3.ZERO
	var info := space.get_rest_info(query)
	var hit: Variant = instance_from_id(int(info.get("collider_id", 0))) \
			if not info.is_empty() else null
	return str((hit as Node).get_path()) if hit is Node else "(unnamed)"


func _half_height(target: ManipulableBody) -> float:
	var hull := target.get_node_or_null("hull") as CollisionShape3D
	if hull != null and hull.shape is BoxShape3D:
		return (hull.shape as BoxShape3D).size.y * 0.5
	return 0.35


func _forget_separated() -> void:
	for released: ManipulableBody in _released.duplicate():
		if not is_instance_valid(released):
			_released.erase(released)
			continue
		var reach := Constants.PLAYER_RADIUS + _half_height(released) * 1.8 \
				+ 0.1
		if released.global_position.distance_to(player.global_position) \
				> reach + Constants.PLAYER_HEIGHT * 0.5:
			released.remove_collision_exception_with(player)
			_released.erase(released)
