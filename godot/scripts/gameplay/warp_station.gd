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
## A broken station reads as dead at a distance, so a player does not
## walk across a room for a warp that was never on offer.
const BROKEN_TINT := Color(0.70, 0.40, 0.35)

var station_id := ""
var label_text := ""
## THE ROOM WHOSE PUZZLE REPAIRS THIS STATION, or "" for a station that
## is working when the player finds it.
##
## §30.12.4 allows a station to start broken; the owner ruling attached
## the repair to a puzzle, because the Zone already had puzzles and they
## already did nothing. A room, not an activity id: the builder knows the
## room it is standing in, and `ActivityRuntime` already carries
## `room_id`, so nothing here has to agree with anyone about how an
## activity id is spelled.
##
## A broken station is NEVER a gate on progression. Warp only ever moves
## a player between stations they have already reached on foot, so every
## place a station could take them is a place they have already walked
## to. The entrance station is never broken, so a Zone always has one
## save point from the moment it is entered.
var repair_room := ""
## Set by the controller: the stations this player has reached, in the
## order they were placed, so the prompt can name where E goes next.
var cycle: Callable = Callable()

var _ring: MeshInstance3D
var _post: MeshInstance3D
var _sign: Label3D
var _is_reached := false
var _is_broken := false

static func create(id: String, label: String, theme: String,
		repair_room_in := "") -> WarpStation:
	var station := WarpStation.new()
	station.name = "WarpStation_%s" % id
	station.station_id = id
	station.label_text = label
	station.repair_room = repair_room_in
	station._is_broken = repair_room_in != ""
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

	_post = MeshInstance3D.new()
	_post.name = "Post"
	var column := CylinderMesh.new()
	column.top_radius = RADIUS * 0.5
	column.bottom_radius = RADIUS * 0.5
	column.height = HEIGHT
	_post.mesh = column
	_post.position = Vector3(0, HEIGHT / 2.0, 0)
	_post.material_override = ThemeMaterials.glow_material(
			BROKEN_TINT if _is_broken else Color(0.55, 0.95, 0.75),
			0.15 if _is_broken else 0.5)
	add_child(_post)

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var disc := TorusMesh.new()
	disc.inner_radius = RADIUS
	disc.outer_radius = RADIUS + 0.18
	_ring.mesh = disc
	_ring.position = Vector3(0, 0.1, 0)
	_ring.material_override = ThemeMaterials.glow_material(
			BROKEN_TINT if _is_broken else Color(0.35, 0.55, 0.6),
			0.15 if _is_broken else 0.3)
	add_child(_ring)

	_sign = Label3D.new()
	_sign.name = "StationLabel"
	_sign.text = label_text
	_sign.position = Vector3(0, HEIGHT + 0.5, 0)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font_size = 30
	_sign.pixel_size = 0.005
	_sign.modulate = BROKEN_TINT if _is_broken else Color(0.55, 0.95, 0.75)
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
	if _is_reached or _is_broken or not body.is_in_group("player"):
		return
	mark_reached()
	reached.emit(station_id)

func is_broken() -> bool:
	return _is_broken

## THE PUZZLE IS THE SWITCH.
##
## Repairing does not merely permit activation, it performs it: the
## player who just solved the room's puzzle is standing in the room, and
## making them then walk onto the pad would be a second, invisible step
## for a thing they have already earned. Monotone and idempotent, like
## reaching -- solving the same activity twice is one repair.
##
## Returns whether this call was the one that repaired it, so the
## controller knows whether there is anything to announce.
func repair() -> bool:
	if not _is_broken:
		return false
	_is_broken = false
	if _post != null:
		_post.material_override = ThemeMaterials.glow_material(
				Color(0.55, 0.95, 0.75), 0.5)
	if _sign != null:
		_sign.modulate = Color(0.55, 0.95, 0.75)
	mark_reached()
	return true

## Monotone, and idempotent: reaching a reached station is not an event.
##
## A BROKEN STATION REFUSES. `repair()` clears the flag before it calls
## this, so the only way past is the puzzle -- and a caller that reaches
## for `mark_reached` directly cannot light a station the player has not
## earned, which is the hole an unguarded version would leave.
func mark_reached() -> void:
	if _is_reached or _is_broken:
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
	if _is_broken:
		# Names the repair rather than the mechanism, because the player
		# has no vocabulary for "activity in room c007" and does have one
		# for the thing glowing on the far side of the room.
		return "%s — BROKEN: solve this room's puzzle" % label_text
	if not _is_reached:
		return "[E] ACTIVATE %s" % label_text
	var to := _next()
	if to == "":
		return "%s — no other station reached yet" % label_text
	return "[E] WARP TO %s" % to.to_upper()

func interact(_player: Node) -> void:
	if _is_broken:
		return
	if not _is_reached:
		mark_reached()
		reached.emit(station_id)
		return
	var to := _next()
	if to == "":
		return
	warp_requested.emit(station_id, to)
