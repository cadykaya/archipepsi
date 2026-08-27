class_name EchoProjectile
extends Area3D
## A simple slow projectile: damages the first enemy hit, despawns on hit
## or lifetime. No physics simulation beyond straight flight.

var damage := 10.0
var speed := 15.0
var lifetime := 3.0
var knockback := 0.0
var direction := Vector3.FORWARD
## The source world's colour, set before the node enters the tree — after
## _ready has built the visual, assigning it paints nothing.
var tint := Color(1.0, 0.55, 0.2)
## Who fired it. A projectile can outlive its shooter's zone, so this is
## checked with `is_instance_valid` before it is used.
var shooter: Player

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	visual.mesh = mesh
	visual.material_override = ThemeMaterials.glow_material(tint, 2.5)
	add_child(visual)
	monitoring = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemies"):
		var enemy := body as Enemy
		var killed := enemy.take_damage(damage, direction, 0.0)
		if is_instance_valid(shooter):
			shooter.report_hit(killed)
		if knockback > 0.0:
			enemy.apply_knockback(direction * knockback)
	queue_free()
