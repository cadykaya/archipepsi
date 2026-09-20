class_name DestructibleCover
extends StaticBody3D
## A block you can shoot away (ROOM_GRAMMAR v0).
##
## The measured problem it answers: an arena carried seven to eleven
## objects and every one was inert, so the player learned very fast that
## objects here do not matter -- and then learned it about the activities
## too.
##
## WHAT IT PAYS IN. Space, not loot. Coins are an Archipelago item and
## nothing here may mint one; the local reward vocabulary today is a
## note, which is not what "break a crate and get something" means. So
## this pays by REMOVING ITSELF: the cover is gone, the line is open, the
## approach changed. That is a real consequence which needs no economy,
## and it leaves the loot question open rather than answering it badly.

const GROUP := "environment_objects"

## How much punishment it takes. Not a gate: every weapon in the game
## contributes, including the permanent Static Pulse floor, so this is
## pacing rather than a capability check.
const HP := 40.0
const SIZE := Vector3(1.5, 1.4, 0.9)

signal broken(at: Vector3)

var hp := HP
var _mesh: MeshInstance3D
var _tint := Color(0.62, 0.66, 0.72)

static func create(theme: String) -> DestructibleCover:
	var piece := DestructibleCover.new()
	piece.name = "DestructibleCover"
	piece._tint = ThemeMaterials.light_color(theme).darkened(0.45)
	piece._build()
	return piece

func _build() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	_mesh.mesh = box
	_mesh.material_override = _material(0.0)
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = SIZE
	shape.shape = collider
	add_child(shape)
	add_to_group(Damageable.GROUP)
	add_to_group(GROUP)

func _material(wear: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _tint.lerp(Color(0.20, 0.20, 0.22), wear)
	material.roughness = 0.9
	return material

## `Enemy`'s signature, so every damage path in the game reaches it
## without knowing what it hit.
func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO,
		_knockback: float = 0.0) -> bool:
	hp -= amount
	if hp > 0.0:
		# Damage reads as damage BEFORE it reads as destruction. A block
		# that looks identical until it vanishes teaches the player
		# nothing about whether shooting it is worth the ammunition.
		if _mesh != null:
			_mesh.material_override = _material(
					1.0 - clampf(hp / HP, 0.0, 1.0))
		return false
	broken.emit(global_position)
	queue_free()
	return true
