class_name EchoProjectile
extends Area3D
## A projectile with three shapes in one node, because the schema describes
## them as one primitive family rather than three:
##
##   straight     `projectile_damage` with gravity_scale 0, bounces 0 (v0.7)
##   falling      `projectile_damage` with gravity_scale > 0
##   lobbed       `arc_lob` — fully gravity-affected, fused, explodes
##
## Movement integrates a velocity rather than stepping along a fixed
## direction, which is what lets gravity and reflection exist at all. World
## collision is a swept ray over the frame's step: an Area3D reports overlap
## with bodies but not the surface normal, and a bounce without a normal is
## a guess.

var damage := 10.0
var speed := 15.0
var lifetime := 3.0
var knockback := 0.0
var direction := Vector3.FORWARD
## 0 flies straight; 1 falls at full world gravity.
var gravity_scale := 0.0
## Reflections off world geometry remaining before it expires on contact.
var bounces := 0
## > 0 makes this a lob: it detonates for `damage` in this radius on fuse
## expiry or first contact, instead of damaging one body.
var blast_radius := 0.0
## Seconds until detonation, for a lob. <= 0 means "no fuse", and lifetime
## is what ends it.
var fuse := 0.0
## The source world's colour, set before the node enters the tree — after
## _ready has built the visual, assigning it paints nothing.
var tint := Color(1.0, 0.55, 0.2)
## Who fired it. A projectile can outlive its shooter's zone, so this is
## checked with `is_instance_valid` before it is used.
var shooter: Player

var _velocity := Vector3.ZERO
var _spent := false

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var scale_up := 1.0 if blast_radius <= 0.0 else 1.5
	mesh.radius = 0.22 * scale_up
	mesh.height = 0.44 * scale_up
	visual.mesh = mesh
	visual.material_override = ThemeMaterials.glow_material(tint, 2.5)
	add_child(visual)
	monitoring = true
	body_entered.connect(_on_body_entered)
	_velocity = direction.normalized() * speed

func _physics_process(delta: float) -> void:
	if _spent:
		return
	if gravity_scale > 0.0:
		_velocity.y -= Constants.GRAVITY * gravity_scale * delta

	var step := _velocity * delta
	if step.length() > 0.0001:
		var query := PhysicsRayQueryParameters3D.create(
				global_position, global_position + step)
		# Enemies are handled by the Area3D overlap, which knows which body
		# it hit; this ray is only asking about the world.
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and not _is_actor(hit.get("collider")):
			_on_world_hit(hit)
			if _spent:
				return
		else:
			global_position += step
	# `direction` stays the truth about where it is going, so knockback and
	# the enemy hit direction follow the arc instead of the launch angle.
	if _velocity.length() > 0.0001:
		direction = _velocity.normalized()

	lifetime -= delta
	if fuse > 0.0:
		fuse -= delta
		if fuse <= 0.0:
			_detonate()
			return
	if lifetime <= 0.0:
		# A lob that ran out of lifetime still goes off. Silently vanishing
		# would read as a dud rather than as a timing you can learn.
		if blast_radius > 0.0:
			_detonate()
		else:
			queue_free()

func _is_actor(collider: Variant) -> bool:
	return is_instance_valid(collider) and collider is Node \
			and ((collider as Node).is_in_group("enemies")
					or (collider as Node).is_in_group("player"))

func _on_world_hit(hit: Dictionary) -> void:
	if blast_radius > 0.0:
		_detonate()
		return
	if bounces <= 0:
		queue_free()
		_spent = true
		return
	bounces -= 1
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	# Step back off the surface before reflecting, or the next frame starts
	# inside the wall and the ray immediately reports another hit.
	global_position = hit["position"] + normal * 0.28
	_velocity = _velocity.bounce(normal) * 0.85

func _on_body_entered(body: Node3D) -> void:
	if _spent or body.is_in_group("player"):
		return
	if blast_radius > 0.0:
		_detonate()
		return
	if body.is_in_group("enemies"):
		var enemy := body as Enemy
		var killed := enemy.take_damage(damage, direction, 0.0)
		if is_instance_valid(shooter):
			shooter.report_hit(killed)
		if knockback > 0.0:
			enemy.apply_knockback(direction * knockback)
		_spent = true
		queue_free()
		return
	# A non-enemy body is world geometry that the swept ray did not catch
	# (it started inside, or the body moved into us). Treat it as a wall.
	if bounces <= 0:
		_spent = true
		queue_free()

## Radial damage, then gone. Falls off linearly to the rim so standing at
## the edge of a blast is meaningfully better than standing in it.
func _detonate() -> void:
	if _spent:
		return
	_spent = true
	var hit_any := false
	var killed_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if distance > blast_radius:
			continue
		var falloff := 1.0 - clampf(distance / maxf(blast_radius, 0.001),
				0.0, 1.0) * 0.6
		var away := (enemy.global_position - global_position)
		away = away.normalized() if away.length() > 0.001 else Vector3.UP
		if enemy.take_damage(damage * falloff, away, 0.0):
			killed_any = true
		hit_any = true
		if knockback > 0.0:
			enemy.apply_knockback(away * knockback)
	if hit_any and is_instance_valid(shooter):
		shooter.report_hit(killed_any)
	Blast.spawn(get_tree().current_scene, global_position, blast_radius, tint)
	queue_free()
