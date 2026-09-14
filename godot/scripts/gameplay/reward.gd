class_name RewardObject
extends StaticBody3D
## A Check's reward pedestal. Interactable only once its chamber objective
## is satisfied; claiming sends the intent and the bridge decides truth.
## States: locked → available → sending → confirmed.

signal claim_requested(location_id: int)

#: Node name of the transmission beam, so tests can assert one fired — or,
#: on a resumed Zone, that none did.
const BEAM_NAME := "SendBeam"

#: Where the floating item rests. `_process` bobs it around this; the
#: silhouette measured below uses the REST height, because the shape a
#: state has is not a function of which frame you looked on.
const ITEM_REST_Y := 1.7

#: Node holding the geometry that says which STATE this Check is in,
#: rebuilt on every state change. Its own container so the measurement
#: below has something to measure and art has something to replace.
const STATE_FORM_NAME := "StateForm"

#: Two Check states read apart when their forms differ by this much in
#: height, in metres...
const LEGIBLE_TOP_GAP := 0.35

#: ...or when one is this many times taller than the other. Either is
#: enough, and both are SHAPE. The gap is wider than twice the item's
#: 0.12 m bob on purpose: two states that only separated by less than the
#: idle animation would cross each other every second.
const LEGIBLE_HEIGHT_RATIO := 1.8

var location_id := 0
var zone_id := ""
var objective_satisfied := false
var state := "locked"

var _item_visual: MeshInstance3D
var _label: Label3D
var _ring: MeshInstance3D
var _state_form: Node3D
## Which state `_state_form` currently holds the geometry for.
var _form_state := ""
var _spin := 0.0
var _last_state := ""
## A Zone rebuilt on resume walks straight to "confirmed" for everything
## already sent. Those are not transmissions happening now, so the beam
## stays disarmed until the first visual pass is behind us.
var _transitions_live := false

static func create(location_id_in: int, zone_id_in: String,
		theme: String) -> RewardObject:
	var reward := StaticBody3D.new()
	reward.set_script(load("res://scripts/gameplay/reward.gd"))
	reward.location_id = location_id_in
	reward.zone_id = zone_id_in
	reward.name = "Reward_%d" % location_id_in

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.6, 1.4)
	shape.shape = box
	shape.position = Vector3(0, 1.3, 0)
	reward.add_child(shape)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.55
	pedestal_mesh.bottom_radius = 0.75
	pedestal_mesh.height = 1.0
	pedestal.mesh = pedestal_mesh
	pedestal.position = Vector3(0, 0.5, 0)
	pedestal.material_override = ThemeMaterials.trim_mat(theme)
	reward.add_child(pedestal)

	var item := MeshInstance3D.new()
	var item_mesh := PrismMesh.new()
	item_mesh.size = Vector3(0.7, 0.7, 0.7)
	item.mesh = item_mesh
	item.name = "ItemVisual"
	item.position = Vector3(0, ITEM_REST_Y, 0)
	reward.add_child(item)

	# The structural half of the state read (art requirement 11). Empty
	# here and filled by `_refresh_visual`, because what it holds is a
	# function of the state and the state is not known yet.
	var form := Node3D.new()
	form.name = STATE_FORM_NAME
	reward.add_child(form)

	# Destination ring. State and destination are separate questions, so
	# they get separate channels: the floating item says how far along the
	# Check is, the ring says which world receives it — in the same colour
	# the Hub's campaign board uses for that game.
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.86
	ring_mesh.outer_radius = 1.02
	ring.mesh = ring_mesh
	ring.name = "DestinationRing"
	ring.position = Vector3(0, 0.05, 0)
	reward.add_child(ring)

	var label := Label3D.new()
	label.name = "StateLabel"
	label.position = Vector3(0, 2.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.006
	reward.add_child(label)
	return reward

func _ready() -> void:
	_item_visual = get_node("ItemVisual")
	_label = get_node("StateLabel")
	_ring = get_node("DestinationRing")
	_state_form = get_node(STATE_FORM_NAME)
	# _recompute, not _refresh_visual: painting the default "locked" here
	# and only deriving the real state on the next snapshot means an
	# already-sent Check reads LOCKED for a frame — and, worse, the
	# locked→confirmed step that follows looks exactly like a Check
	# confirming, so a resumed Zone replayed a beam for every one of them.
	_recompute()
	_transitions_live = true

func _process(delta: float) -> void:
	if state in ["locked", "available"]:
		_spin += delta * (2.2 if state == "available" else 0.5)
		_item_visual.rotation.y = _spin
		_item_visual.position.y = 1.7 + sin(_spin * 1.7) * 0.12

func set_objective_satisfied(satisfied: bool) -> void:
	objective_satisfied = objective_satisfied or satisfied   # latches
	_recompute()

func refresh_from_snapshot() -> void:
	_recompute()

func _recompute() -> void:
	if BridgeClient.is_checked(location_id):
		state = "confirmed"
	elif BridgeClient.is_pending(location_id):
		state = "sending"
	elif objective_satisfied:
		state = "available"
	else:
		state = "locked"
	_refresh_visual()

func _refresh_visual() -> void:
	if _item_visual == null:
		return
	_rebuild_state_form()
	var scout := BridgeClient.scout_for(location_id)
	var game: String = scout.get("recipient_game", "?") if scout else "?"
	match state:
		"locked":
			_item_visual.material_override = ThemeMaterials.glow_material(
					Color(0.35, 0.35, 0.4), 0.4)
			_label.text = "LOCKED"
			_label.modulate = Color(0.6, 0.6, 0.6)
		"available":
			_item_visual.material_override = ThemeMaterials.glow_material(
					Color(0.4, 1.0, 0.9), 1.8)
			_label.text = "CHECK %03d\n(%s)" % [location_id % 1000, game]
			_label.modulate = Color(0.7, 1.0, 0.95)
		"sending":
			_item_visual.material_override = ThemeMaterials.glow_material(
					Color(1.0, 0.9, 0.3), 1.2)
			_label.text = "SENDING…"
			_label.modulate = Color(1.0, 0.9, 0.4)
		"confirmed":
			_item_visual.material_override = ThemeMaterials.glow_material(
					Color(0.25, 0.3, 0.28), 0.2)
			var item: String = scout.get("item_name", "") if scout else ""
			_label.text = "SENT\n%s" % item if item else "SENT"
			_label.modulate = Color(0.5, 0.55, 0.5)

	# Unknown recipient (no scout yet) gets a dead grey rather than a
	# confident wrong colour. The ring is the DESTINATION channel, not the
	# state channel: what state a Check is in is said by the form above,
	# so this is free to be replaced, moved or dropped by art without
	# taking the state read with it.
	var destination := ThemeMaterials.color_for_game(game) if scout \
			else Color(0.3, 0.32, 0.35)
	_ring.material_override = ThemeMaterials.glow_material(destination,
			0.35 if state == "locked" else 1.5)

	if _transitions_live and state == "confirmed" \
			and _last_state != "confirmed":
		_send_beam(destination)
	_last_state = state

## The SHAPE of a state, art requirement 11.
##
## LOCKED and CONFIRMED have to stay apart across a room, and the two
## channels that used to carry them cannot do it: the label is words, and
## words are unreadable at distance, while the item's colour went from
## `(0.35, 0.35, 0.4)` to `(0.25, 0.3, 0.28)` — two greys eight percent of
## a shade apart, and identical to anyone who does not separate those
## hues. Neither is a state read; both are a state read for someone
## standing next to it.
##
## So the states have different FORMS, in the 005-R language:
##
##   locked     an OPEN CRADLE around the item — held, not yours yet
##   available  the item alone, free, spinning fast — take it
##   sending    the same, mid-transmission, with the beam
##   confirmed  a collapsed, chunky spent mass on the cap — nothing left
##
## What is deliberately NOT the invariant: any particular piece of
## geometry. The destination ring is not load bearing here and never was,
## and none of these placeholders is. The rule is that the FORMS DIFFER,
## and it is stated as a measurement so an authored cradle and an authored
## spent mass answer it the same way these do.
func _rebuild_state_form() -> void:
	if _state_form == null or _form_state == state:
		return
	# Guarded on the state and not on the refresh: `refresh_from_snapshot`
	# runs on every snapshot, and freeing and rebuilding fifteen
	# pedestals' worth of meshes to repaint a label would be churn for
	# nothing.
	_form_state = state
	for child in _state_form.get_children():
		_state_form.remove_child(child)
		child.free()
	# The item itself is the "there is something here" read, so the state
	# that has nothing left does not show one.
	_item_visual.visible = state != "confirmed"
	match state:
		"locked":
			_build_cradle()
		"confirmed":
			_build_spent_mass()

## Three uprights around the item, open at the top: a cradle you can see
## into and cannot reach into. Tall, narrow-barred, and airy — the
## opposite silhouette from the spent mass below.
func _build_cradle() -> void:
	for i in 3:
		var angle := TAU * float(i) / 3.0
		var strut := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.11, 1.45, 0.11)
		strut.mesh = mesh
		strut.position = Vector3(cos(angle) * 0.5, 1.78, sin(angle) * 0.5)
		strut.rotation.y = -angle
		strut.material_override = ThemeMaterials.glow_material(
				Color(0.42, 0.44, 0.5), 0.5)
		_state_form.add_child(strut)

## Low, wide and solid, sitting on the pedestal cap. Half the height of
## the item it replaces and half again as wide: at distance the pedestal
## visibly went from holding something to being finished with it.
func _build_spent_mass() -> void:
	var mass := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.40
	mesh.bottom_radius = 0.50
	mesh.height = 0.28
	mass.mesh = mesh
	mass.position = Vector3(0, 1.14, 0)
	mass.material_override = ThemeMaterials.glow_material(
			Color(0.25, 0.3, 0.28), 0.2)
	_state_form.add_child(mass)


## The measured silhouette of whatever is saying what state this is in.
##
## Geometry only. No material is read, so the answer is the same in
## colour, in greyscale, and with every emission set to zero — which is
## the whole point of the requirement.
##
## The item is measured at `ITEM_REST_Y` rather than wherever the bob has
## it this frame: the form a state has is not a function of when you
## looked.
static func state_profile(reward: Node3D) -> Dictionary:
	var top := -INF
	var bottom := INF
	var width := 0.0
	var parts := 0
	var item := reward.get_node_or_null("ItemVisual") as MeshInstance3D
	var nodes: Array[Node] = []
	if item != null and item.visible:
		nodes.append(item)
	var form := reward.get_node_or_null(STATE_FORM_NAME)
	if form != null:
		nodes.append_array(form.get_children())
	for node in nodes:
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		parts += 1
		var at := mesh_node.position
		if mesh_node == item:
			at.y = ITEM_REST_Y
		var local := Transform3D(Basis.from_euler(mesh_node.rotation), at)
		var box := mesh_node.mesh.get_aabb()
		for i in 8:
			var corner: Vector3 = local * (box.position + Vector3(
					box.size.x * float(i & 1),
					box.size.y * float((i >> 1) & 1),
					box.size.z * float((i >> 2) & 1)))
			top = maxf(top, corner.y)
			bottom = minf(bottom, corner.y)
			width = maxf(width, maxf(absf(corner.x), absf(corner.z)) * 2.0)
	if parts == 0:
		return {"top": 0.0, "bottom": 0.0, "height": 0.0, "width": 0.0,
				"parts": 0}
	return {"top": top, "bottom": bottom, "height": maxf(top - bottom, 0.0),
			"width": width, "parts": parts}


## Whether two states read as different forms across a room.
##
## Height, or overall reach. Not part count and not colour: three bars
## and one bar look the same from far enough away, and colour is the
## channel this requirement exists because it could not carry.
static func forms_read_apart(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a["top"]) - float(b["top"])) >= LEGIBLE_TOP_GAP:
		return true
	var lo := minf(float(a["height"]), float(b["height"]))
	var hi := maxf(float(a["height"]), float(b["height"]))
	return lo > 0.0 and hi / lo >= LEGIBLE_HEIGHT_RATIO


## The item leaving for whichever world owns it: a column of that world's
## colour, straight up and out. Purely cosmetic — the bridge confirmed the
## Check long before this plays, and nothing here can change that.
func _send_beam(color: Color) -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.40
	mesh.height = 40.0
	beam.mesh = mesh
	beam.name = BEAM_NAME
	beam.position = Vector3(0, 20.0, 0)
	var material := ThemeMaterials.glow_material(color, 4.0)
	beam.material_override = material
	add_child(beam)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(beam, "scale", Vector3(0.06, 1.0, 0.06), 0.85)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.85)
	tween.chain().tween_callback(beam.queue_free)

func interact_prompt() -> String:
	match state:
		"available":
			return "[E] CLAIM CHECK %03d" % (location_id % 1000)
		"locked":
			return "OBJECTIVE INCOMPLETE"
		"sending":
			return "SENDING…"
	return ""

func interact(_player: Node) -> void:
	if state != "available":
		return
	if not BridgeClient.snapshot.get("ap_connected", false):
		# §6: the reward stays claimable after reconnect; no pending is
		# created while offline.
		_label.text = "ARCHIPELAGO OFFLINE\nRECONNECT TO SEND"
		return
	state = "sending"
	_refresh_visual()
	claim_requested.emit(location_id)
	BridgeClient.send_intent({"type": "claim_check", "zone_id": zone_id,
			"location_id": location_id})
