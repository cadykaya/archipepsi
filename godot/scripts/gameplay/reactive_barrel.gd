class_name ReactiveBarrel
extends StaticBody3D
## A barrel that goes off when hit, hurting whatever is close to it.
##
## An option the room offers, never a step it demands: nothing checks
## whether a barrel was used, and no progression depends on one. Damage
## stays BALANCE and never becomes LOGIC.

const GROUP := "environment_objects"

const HP := 12.0
const RADIUS := 4.5
const DAMAGE := 34.0
const SIZE := Vector3(0.8, 1.1, 0.8)

signal detonated(at: Vector3)

var hp := HP
var _spent := false

static func create(_theme: String) -> ReactiveBarrel:
	var barrel := ReactiveBarrel.new()
	barrel.name = "ReactiveBarrel"
	barrel._build()
	return barrel

func _build() -> void:
	var mesh := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = SIZE.x / 2.0
	body.bottom_radius = SIZE.x / 2.0
	body.height = SIZE.y
	mesh.mesh = body
	# Hazard language, honestly spent. This genuinely hurts you, which is
	# the one thing the reserved orange is FOR -- a decorative barrel
	# wearing it would be the misuse the 2026-08-28 ruling forbids.
	mesh.material_override = ThemeMaterials.glow_material(
			Color(1.0, 0.45, 0.12), 1.1)
	add_child(mesh)
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = SIZE.x / 2.0 + 0.06
	ring.bottom_radius = ring.top_radius
	ring.height = 0.16
	band.mesh = ring
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.11, 0.10)
	dark.roughness = 1.0
	band.material_override = dark
	add_child(band)
	var shape := CollisionShape3D.new()
	var collider := CylinderShape3D.new()
	collider.radius = SIZE.x / 2.0
	collider.height = SIZE.y
	shape.shape = collider
	add_child(shape)
	add_to_group(Damageable.GROUP)
	add_to_group(GROUP)

func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO,
		_knockback: float = 0.0) -> bool:
	if _spent:
		return false
	hp -= amount
	if hp > 0.0:
		return false
	detonate()
	return true

## Split from `take_damage` so a test can set one off without staging a
## weapon, the same way `LocalRewardPickup.collect()` is split.
func detonate() -> void:
	if _spent:
		return
	_spent = true
	var at := global_position
	Blast.spawn(get_parent(), at, RADIUS, Color(1.0, 0.55, 0.2))
	# EVERYTHING damageable in range, the player included. A barrel that
	# only hurt enemies would be a free button, and a free button is not
	# a decision.
	for node in get_tree().get_nodes_in_group(Damageable.GROUP):
		var other := node as Node3D
		if other == null or other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = other.global_position - at
		var reach := away.length()
		if reach > RADIUS:
			continue
		Damageable.hit(other, DAMAGE * (1.0 - reach / RADIUS),
				away.normalized() if reach > 0.01 else Vector3.UP, 0.0)
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D and player.has_method("take_damage"):
		var to_player: Vector3 = (player as Node3D).global_position - at
		if to_player.length() <= RADIUS:
			player.take_damage(DAMAGE * (1.0 - to_player.length() / RADIUS))
	detonated.emit(at)
	queue_free()
