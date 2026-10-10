extends Node
## WebSocket client for the Python bridge. The bridge is the authority;
## this node holds the last full campaign snapshot and re-emits messages.
##
## Reconnects with backoff (0.5/1/2/4 capped at 5s). An in-flight
## generation request is abandoned, not retried, on reconnect — the next
## snapshot reports the Zone's real state.

signal bridge_state_changed(online: bool)
signal snapshot_received(snapshot: Dictionary)
signal zone_ready_received(zone: Dictionary, used_fallback: bool)
signal notification_received(note: Dictionary)
signal error_received(err: Dictionary)

var online := false
var snapshot: Dictionary = {}

## Session flavor memory: the zone most recently completed, so the Hub can
## quote Epsilon back at the player. Client-side only; lost on restart.
var last_completed_zone: Dictionary = {}
var _held_zone: Dictionary = {}

var _socket := WebSocketPeer.new()
var _retry_delay := 0.5
var _retry_timer := 0.0
var _was_connecting := false

func _ready() -> void:
	_open()

func _open() -> void:
	_socket = WebSocketPeer.new()
	var url := "ws://%s:%d" % [Constants.BRIDGE_HOST, Constants.BRIDGE_PORT]
	var err := _socket.connect_to_url(url)
	_was_connecting = err == OK
	if err != OK:
		push_warning("bridge connect failed immediately: %s" % err)

func _process(delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not online:
			online = true
			_retry_delay = 0.5
			bridge_state_changed.emit(true)
			send_intent({"type": "hello", "client_version": "0.1.0"})
		while _socket.get_available_packet_count() > 0:
			_handle(_socket.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if online:
			online = false
			bridge_state_changed.emit(false)
		if _was_connecting:
			_was_connecting = false
			_retry_timer = _retry_delay
			_retry_delay = minf(_retry_delay * 2.0, 5.0)
		_retry_timer -= delta
		if _retry_timer <= 0.0:
			_open()

## Every intent this client sends, most recent last. Kept because the
## interesting question about a new subsystem is often "did it talk to the
## bridge at all" — the Echo Lab's whole contract is that it does not —
## and a log of what was SENT answers that without a test-only hook in the
## send path. Bounded: this is a diagnostic, not a queue.
var sent_intents: Array[Dictionary] = []
const _INTENT_LOG_CAP := 64

func send_intent(intent: Dictionary) -> bool:
	sent_intents.append(intent)
	if sent_intents.size() > _INTENT_LOG_CAP:
		sent_intents.pop_front()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_warning("intent '%s' dropped: bridge offline" % intent.get("type", "?"))
		return false
	_socket.send_text(JSON.stringify(intent))
	return true

func _handle(raw: String) -> void:
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("unparseable bridge message")
		return
	var message: Dictionary = data
	match message.get("type", ""):
		"bridge_ready":
			pass
		"campaign_snapshot":
			var previous_count := int(snapshot.get("completed_zone_count", 0))
			snapshot = message
			if int(message.get("completed_zone_count", 0)) > previous_count \
					and not _held_zone.is_empty():
				last_completed_zone = _held_zone
			# `zone` is null while PENDING_GENERATION; .get's default does
			# not apply to an explicit null.
			var zone_content: Variant = active_zone().get("zone")
			if typeof(zone_content) == TYPE_DICTIONARY \
					and not zone_content.is_empty():
				_held_zone = zone_content
			snapshot_received.emit(message)
		"zone_ready":
			zone_ready_received.emit(message.get("zone", {}),
					bool(message.get("used_fallback", false)))
		"notification":
			notification_received.emit(message)
		"error":
			push_warning("bridge error [%s]: %s" % [
					message.get("scope", "?"), message.get("message", "")])
			error_received.emit(message)
		_:
			push_warning("unknown bridge message type")

## Convenience accessors over the last snapshot -----------------------------

func hub() -> Dictionary:
	return snapshot.get("hub", {})

func hub_mode() -> String:
	return hub().get("mode", "NO_CAMPAIGN")

func active_zone() -> Dictionary:
	var zone: Variant = snapshot.get("active_zone")
	return zone if typeof(zone) == TYPE_DICTIONARY else {}

## The folded component set. The BRIDGE folds; nothing here re-derives it.
func mechanics() -> Dictionary:
	var m: Variant = snapshot.get("mechanics")
	return m if typeof(m) == TYPE_DICTIONARY else {}

## Every owned component, already folded: `{component, mk, provenance}`.
func owned_components(kind := "") -> Array:
	var out: Array = []
	for entry: Dictionary in mechanics().get("owned", []):
		var component: Dictionary = entry.get("component", {})
		if kind == "" or component.get("kind", "") == kind:
			out.append(entry)
	return out

func owned_component(component_id: String) -> Dictionary:
	for entry: Dictionary in mechanics().get("owned", []):
		if entry.get("component", {}).get("component_id", "") == component_id:
			return entry
	return {}

func slots() -> Dictionary:
	var s: Variant = snapshot.get("slots")
	return s if typeof(s) == TYPE_DICTIONARY else {}

## The Action in a slot, as the runtime wants it. Empty when the slot is
## clear — which is a legal, playable state: the Static Pulse is never the
## thing in a slot.
func slotted_action(slot := "echo_a") -> Dictionary:
	var id: Variant = slots().get(slot)
	if id == null:
		return {}
	return owned_component(str(id)).get("component", {})

## What an Echo was interpreted from, for tints and provenance. Reads the
## folded provenance rather than the log, so an upgraded component still
## answers with the world that created it.
func component_source_game(component_id: String) -> String:
	var provenance: Array = owned_component(component_id).get("provenance", [])
	if provenance.is_empty():
		return ""
	return str(provenance[0].get("source_game", ""))

func scout_for(location_id: int) -> Dictionary:
	for scout: Dictionary in snapshot.get("scouted", []):
		if int(scout.get("location_id", 0)) == location_id:
			return scout
	return {}

func is_checked(location_id: int) -> bool:
	# JSON numbers parse as floats; `int in [float]` is not equality.
	for loc in snapshot.get("checked_location_ids", []):
		if int(loc) == location_id:
			return true
	return false

func is_pending(location_id: int) -> bool:
	for pending: Dictionary in snapshot.get("pending_checks", []):
		if int(pending.get("location_id", 0)) == location_id:
			return true
	return false

## Resource ids in HUD-channel order, straight from the fold.
##
## The client does NOT work this out for itself. It could — `owned` is
## already ordered — but then "which resource is channel 3" would be derived
## in two languages, and the whole reason the fold lives on the bridge is
## that the thing which must be identical everywhere gets computed once.
func resource_channels() -> Array:
	var order: Variant = mechanics().get("channel_order")
	return order if typeof(order) == TYPE_ARRAY else []
