class_name RewardObject
extends StaticBody3D
## A Check's reward pedestal. Interactable only once its chamber objective
## is satisfied; claiming sends the intent and the bridge decides truth.
## States: locked → available → sending → confirmed.

signal claim_requested(location_id: int)

var location_id := 0
var zone_id := ""
var objective_satisfied := false
var state := "locked"

var _item_visual: MeshInstance3D
var _label: Label3D
var _spin := 0.0

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
	item.position = Vector3(0, 1.7, 0)
	reward.add_child(item)

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
	_refresh_visual()

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
