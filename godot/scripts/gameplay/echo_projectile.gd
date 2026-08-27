class_name EchoProjectile
extends Area3D
## A simple slow projectile: damages the first enemy hit, despawns on hit
## or lifetime. No physics simulation beyond straight flight.

var damage := 10.0
var speed := 15.0
var lifetime := 3.0
var knockback := 0.0
var direction := Vector3.FORWARD

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
	visual.material_override = ThemeMaterials.glow_material(
			Color(1.0, 0.55, 0.2), 2.5)
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
		body.take_damage(damage, direction, 0.0)
		if knockback > 0.0 and body.has_method("apply_knockback"):
			body.apply_knockback(direction * knockback)
	queue_free()
