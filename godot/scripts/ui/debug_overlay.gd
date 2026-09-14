class_name DebugOverlay
extends CanvasLayer
## F3: the full debug readout (TECHNICAL_ARCHITECTURE §12), straight off
## the snapshot.

var _label: Label

func _ready() -> void:
	layer = 12
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(10, 10)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(_label)

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func refresh() -> void:
	if not visible:
		return
	var s := BridgeClient.snapshot
	var hub: Dictionary = s.get("hub", {})
	var zone: Dictionary = BridgeClient.active_zone()
	var pending: Array = s.get("pending_checks", [])
	var lines := [
		"bridge %s | ap %s (%s) | current %s | race %s" % [
			"on" if BridgeClient.online else "OFF",
			"on" if s.get("ap_connected") else "OFF",
			s.get("ap_mode", "?"), s.get("ap_state_is_current"),
			s.get("race_mode")],
		"seed %s team %s slot %s '%s'" % [s.get("seed_name", ""),
			s.get("team", 0), s.get("slot_id", 0), s.get("slot_name", "")],
		"checked %d/30 | keys %d tier %d | coins %d-%d=%d | static %d" % [
			s.get("checked_location_ids", []).size(),
			s.get("signal_keys", 0), s.get("unlocked_tier", 0),
			s.get("coins_received", 0), s.get("coins_spent", 0),
			s.get("coins_available", 0), s.get("static_received", 0)],
		"pending %s" % [str(pending.map(
			func(p: Dictionary) -> int: return int(p.get("location_id", 0))))],
		"zone %s %s finale=%s locs %s" % [zone.get("zone_id", "-"),
			zone.get("state", "-"), zone.get("is_finale", false),
			str(zone.get("allocated_location_ids", []))],
		"hub %s | portal %s | gen %s | finale u=%s o=%s %d/%d" % [
			hub.get("mode", "?"), hub.get("portal_enabled"),
			hub.get("generation_in_progress"), hub.get("finale_unlocked"),
			hub.get("finale_offered"), hub.get("finale_progress", 0),
			hub.get("finale_required", 24)],
		"echoes %d equipped %s | zones done %d | provider %s" % [
			BridgeClient.interpretations().size(),
			s.get("slots", {}).get("echo_a"),
			s.get("completed_zone_count", 0), s.get("epsilon_provider", "?")],
		"last gen error: %s" % [s.get("last_generation_error")],
	]
	_label.text = "\n".join(lines)
