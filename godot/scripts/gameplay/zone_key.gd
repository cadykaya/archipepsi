class_name ZoneKey
extends Area3D
## A Zone-local key: a lock state on generated geometry, not an item.
##
## **It never enters the Archipelago pool.** It has no location id, is
## never scouted, never sent, and does not survive the Zone
## (`SOLUTIONS_CATALOGUE.md` §2). That is exactly why it is safe: a key
## that is not an item cannot desynchronise a multiworld, which is what
## lets a Zone have Doom-style coloured locks with no seed risk at all.
##
## The colour is flavour and the id is truth. Epsilon may theme a Zone's
## locks after whatever key-shaped items it sees passing through the
## multiworld; the engine only ever compares ids.

signal collected(key_id: String)

const SIZE := Vector3(0.5, 0.8, 0.2)

## Named colours a composer may choose between. A closed set, because a
## lock and its key have to read as the same thing at a glance and an
## open palette cannot promise that.
const COLOURS := {
	"red": Color(0.95, 0.25, 0.25),
	"blue": Color(0.3, 0.55, 1.0),
	"gold": Color(1.0, 0.82, 0.25),
	"green": Color(0.35, 0.9, 0.45),
}

var key_id := ""
var colour := "gold"
var _taken := false

static func tint(name: String) -> Color:
	return COLOURS.get(name, COLOURS["gold"])

static func create(id: String, colour_name: String) -> ZoneKey:
	var key := ZoneKey.new()
	key.name = "ZoneKey_%s" % id
	key.key_id = id
	key.colour = colour_name if COLOURS.has(colour_name) else "gold"
	key._build()
	return key

func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.6, 1.2)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Bit"
	var body := BoxMesh.new()
	body.size = SIZE
	mesh.mesh = body
	mesh.position = Vector3(0, 1.0, 0)
	mesh.material_override = ThemeMaterials.glow_material(tint(colour), 1.2)
	add_child(mesh)

	var label := Label3D.new()
	label.text = "%s KEY" % colour.to_upper()
	label.position = Vector3(0, 1.7, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.005
	label.modulate = tint(colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var bit := get_node_or_null("Bit")
	if bit != null:
		(bit as Node3D).rotate_y(delta * 1.6)

## ONCE. `_taken` latches rather than relying on `queue_free` landing
## before the next physics frame -- a pickup that fires twice grants one
## key twice, which is harmless for a set and noisy for the log.
func _on_body_entered(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	collected.emit(key_id)
	queue_free()
