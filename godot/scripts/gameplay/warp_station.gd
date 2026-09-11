class_name WarpStation
extends StaticBody3D
## Travel and save. **Not loadout editing.**
##
## §30.12.4: stations sit at the Zone entrance, at the exit and in large
## rooms; a player may save at one, return to the Hub from one, and warp
## between stations **already reached within the same Zone**.
##
## The deferral of in-Zone LOADOUT stations is untouched and stays
## pinned. The two features share a word and nothing else: editing a
## loadout mid-Zone would re-specify capabilities §29.4 validated at
## entry, which is why all five proposals deferred it. Travel and save
## touch none of that, so nothing here opens a slot.
##
## **Reached-ness is progress**, so it is monotone: a station is reached
## the first time a player stands in it and never becomes unreached.

signal reached(station_id: String)
signal warp_requested(from_id: String, to_id: String)

const HEIGHT := 2.6
const RADIUS := 1.1

var station_id := ""
var label_text := ""
## Set by the controller: the stations this player has reached, in the
## order they were placed, so the prompt can name where E goes next.
var cycle: Callable = Callable()

var _ring: MeshInstance3D
var _sign: Label3D
var _is_reached := false

static func create(id: String, label: String, theme: String) -> WarpStation:
	var station := WarpStation.new()
	station.name = "WarpStation_%s" % id
	station.station_id = id
	station.label_text = label
	station._build(theme)
	return station

func _build(_theme: String) -> void:
	var shape := CollisionShape3D.new()
	var body := CylinderShape3D.new()
	body.radius = RADIUS * 0.5
	body.height = HEIGHT
	shape.shape = body
	shape.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(shape)

	var post := MeshInstance3D.new()
	post.name = "Post"
	var column := CylinderMesh.new()
	column.top_radius = RADIUS * 0.5
	column.bottom_radius = RADIUS * 0.5
	column.height = HEIGHT
	post.mesh = column
	post.position = Vector3(0, HEIGHT / 2.0, 0)
	post.material_override = ThemeMaterials.glow_material(
			Color(0.55, 0.95, 0.75), 0.5)
	add_child(post)

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var disc := TorusMesh.new()
	disc.inner_radius = RADIUS
	disc.outer_radius = RADIUS + 0.18
	_ring.mesh = disc
	_ring.position = Vector3(0, 0.1, 0)
	_ring.material_override = ThemeMaterials.glow_material(
			Color(0.35, 0.55, 0.6), 0.3)
	add_child(_ring)

	_sign = Label3D.new()
	_sign.name = "StationLabel"
	_sign.text = label_text
	_sign.position = Vector3(0, HEIGHT + 0.5, 0)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font_size = 30
	_sign.pixel_size = 0.005
	_sign.modulate = Color(0.55, 0.95, 0.75)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_sign)

	# Standing in it is what reaches it; looking at it is what warps.
	var pad := Area3D.new()
	pad.name = "Pad"
	var pad_shape := CollisionShape3D.new()
	var volume := CylinderShape3D.new()
	volume.radius = RADIUS + 0.4
	volume.height = 2.2
	pad_shape.shape = volume
	pad_shape.position = Vector3(0, 1.1, 0)
	pad.add_child(pad_shape)
	pad.body_entered.connect(_on_pad_entered)
	add_child(pad)

func _on_pad_entered(body: Node3D) -> void:
	if _is_reached or not body.is_in_group("player"):
		return
	mark_reached()
	reached.emit(station_id)

## Monotone, and idempotent: reaching a reached station is not an event.
func mark_reached() -> void:
	if _is_reached:
		return
	_is_reached = true
	if _ring != null:
		_ring.material_override = ThemeMaterials.glow_material(
				Color(0.45, 1.0, 0.8), 1.1)

func is_reached() -> bool:
	return _is_reached

## WHERE E GOES, named before it is pressed.
##
## A destination the player can read beats a menu they have to learn, and
## it keeps the whole feature inside the interact contract the rest of
## the game already uses. Pressing again at the destination continues
## round the reached set, so every reached station is two or three
## presses from every other.
func _next() -> String:
	if cycle.is_null():
		return ""
	return str(cycle.call(station_id))

func interact_prompt() -> String:
	if not _is_reached:
		return "[E] ACTIVATE %s" % label_text
	var to := _next()
	if to == "":
		return "%s — no other station reached yet" % label_text
	return "[E] WARP TO %s" % to.to_upper()

func interact(_player: Node) -> void:
	if not _is_reached:
		mark_reached()
		reached.emit(station_id)
		return
	var to := _next()
	if to == "":
		return
	warp_requested.emit(station_id, to)
