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

func send_intent(intent: Dictionary) -> bool:
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
			snapshot = message
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

func equipped_echo() -> Dictionary:
	var id: Variant = snapshot.get("equipped_echo_id")
	if id == null:
		return {}
	for echo: Dictionary in snapshot.get("echoes", []):
		if echo.get("echo_id") == id:
			return echo
	return {}

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
