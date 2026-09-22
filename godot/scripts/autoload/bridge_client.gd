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
## `zone_id -> proposal_id`, from every offer this client has seen.
## The fallback carrier for `proposal_for`; see it for why the snapshot
## comes first.
var _offer_proposals: Dictionary = {}

var _socket := WebSocketPeer.new()
var _retry_delay := 0.5
var _retry_timer := 0.0
var _was_connecting := false

func _ready() -> void:
	_open()

func _open() -> void:
	_socket = WebSocketPeer.new()
	# Before `connect_to_url`, which is when the buffer is allocated.
	#
	# The default is 64 KiB and an oversized message is NOT truncated:
	# the peer closes with 1009 "message too big", reconnects, receives
	# the same snapshot, and closes again forever while the game says
	# BRIDGE OFFLINE. A 450-location campaign's connect snapshot is
	# 110 KB -- 105 KB of it the 450 scouted locations -- so production
	# scale could not connect at all, while the prototype's 8.5 KB
	# always fitted. `test_snapshot_size.py` measures the worst case
	# against this number so the next growth fails a test instead.
	_socket.inbound_buffer_size = Constants.WS_INBOUND_BUFFER_BYTES
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
			# NOTHING SURVIVES THE SOCKET. A spend in flight when the
			# connection dropped either landed or did not, and this
			# client cannot tell which -- but the snapshot that arrives
			# after the reconnect is the authority either way, and
			# holding a stale subtraction against it would misreport the
			# count until the next refill.
			_in_flight.clear()
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

## TEST SEAM: report a send as accepted with no socket behind it.
##
## Headless drivers have no bridge to connect to, so `send_intent`
## correctly fails for every intent they make -- which would leave
## everything that happens AFTER a successful send untestable without
## standing a bridge up. A driver that needs that half sets this for the
## cases that need it and clears it for the case about failing sends.
##
## Never set by anything the player can reach. The one thing it changes
## is the return value; the intent still goes in `sent_intents`, which is
## what the drivers read.
var assume_sent := false

func send_intent(intent: Dictionary) -> bool:
	sent_intents.append(intent)
	if sent_intents.size() > _INTENT_LOG_CAP:
		sent_intents.pop_front()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if assume_sent:
			return true
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
			_reattach_echo_log(message)
			snapshot = message
			# The engine's count is authoritative; anything in flight it
			# has now caught up with, or refused, stops being subtracted.
			_settle_in_flight()
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
			# THE OFFER'S IDENTITY, kept per Zone. `AMALGAM_BRIDGE.md`
			# §5.9 asks the client to capture `proposal_id` when it
			# STARTS a build; this is the fallback carrier for a bridge
			# that puts it only on the offer. The snapshot is the one
			# the build path actually reads -- see `proposal_for`.
			var offered: Dictionary = message.get("zone", {})
			var offer_id := str(message.get("proposal_id", ""))
			if offer_id != "":
				_offer_proposals[str(offered.get("zone_id", ""))] = offer_id
			zone_ready_received.emit(offered,
					bool(message.get("used_fallback", false)))
		"notification":
			notification_received.emit(message)
		"error":
			push_warning("bridge error [%s]: %s" % [
					message.get("scope", "?"), message.get("message", "")])
			# BEFORE the signal, so a listener redrawing the HUD on an
			# error already sees the charge given back.
			_release_refused(str(message.get("about", "")))
			error_received.emit(message)
		_:
			push_warning("unknown bridge message type")

## True while this client has asked for a full snapshot because the Echo
## log it holds did not match the length the bridge reported. Cleared by
## the complete snapshot that answers, so one desync costs one `hello`
## and not one per snapshot forever.
var _echo_log_resync_pending := false

## How many snapshots arrived WITHOUT the Echo log because it had not
## changed since the last one. A diagnostic, and what the integration
## driver asserts against: a full campaign in which this stays zero is
## not exercising the elision at all, so a broken reattach would pass.
var elided_snapshot_count := 0

## True if the Echo log this client holds ever got SHORTER within one
## campaign. It cannot legitimately: the log is lifetime history and only
## ever grows at the end. A shrink means an elided log was not put back,
## and that is invisible from the outside — the archive just looks short,
## and looks right again on the next snapshot that carries the log. This
## is the only cheap way to catch it, so it is checked continuously
## rather than at the end of a run.
var echo_log_shrank := false
var _echo_log_high_water := 0
var _echo_log_campaign := ""

## Restores an Echo log the bridge left out of this snapshot.
##
## The log is LIFETIME history — ~390 KiB of a late campaign's ~400 KiB
## snapshot — and it only ever grows at the end, so the bridge stops
## re-sending it once every client has it and sets
## `interpretations_complete` false instead. Putting the cached list back
## before anything reads the snapshot means every consumer of
## `interpretations` still just reads `interpretations`: there is one Echo
## log on this side, not a list and a cache that can disagree.
##
## `interpretation_count` is sent either way, so a client that somehow
## missed an append can SEE that it did rather than quietly rendering a
## short archive. It asks for the whole thing back; `hello` is answered
## with a complete snapshot.
func _reattach_echo_log(message: Dictionary) -> void:
	# Absent means an older bridge that always sends the log — the default
	# is the old behaviour, so nothing here changes for it.
	if not bool(message.get("interpretations_complete", true)):
		message["interpretations"] = snapshot.get("interpretations", [])
		elided_snapshot_count += 1
	else:
		_echo_log_resync_pending = false
	# Within one campaign the log only grows. Across campaigns it starts
	# over, so a reset is only legitimate when the campaign changed too.
	var campaign := "%s/%s/%s" % [message.get("seed_name", ""),
			message.get("team", 0), message.get("slot_id", 0)]
	if campaign != _echo_log_campaign:
		_echo_log_campaign = campaign
		_echo_log_high_water = 0
	var size: int = (message.get("interpretations", []) as Array).size()
	if size < _echo_log_high_water:
		echo_log_shrank = true
		push_warning("Echo log shrank from %d to %d within one campaign"
				% [_echo_log_high_water, size])
	_echo_log_high_water = maxi(_echo_log_high_water, size)

	if not message.has("interpretation_count"):
		return
	var claimed := int(message.get("interpretation_count", 0))
	var held: Array = message.get("interpretations", [])
	if claimed == held.size() or _echo_log_resync_pending:
		return
	push_warning("Echo log out of step: bridge says %d, holding %d" % [
			claimed, held.size()])
	_echo_log_resync_pending = true
	send_intent({"type": "hello", "client_version": "0.1.0"})

## Convenience accessors over the last snapshot -----------------------------

## The lifetime Echo log. Complete whether or not this snapshot carried it.
func interpretations() -> Array:
	return snapshot.get("interpretations", [])

func echo_by_id(echo_id: String) -> Dictionary:
	for echo: Dictionary in interpretations():
		if str(echo.get("echo_id", "")) == echo_id:
			return echo
	return {}

func hub() -> Dictionary:
	return snapshot.get("hub", {})

func hub_mode() -> String:
	return hub().get("mode", "NO_CAMPAIGN")

func active_zone() -> Dictionary:
	var zone: Variant = snapshot.get("active_zone")
	return zone if typeof(zone) == TYPE_DICTIONARY else {}

## WHICH PROPOSAL THIS ZONE IS RIGHT NOW (`AMALGAM_BRIDGE.md` §5.9).
##
## Captured by `ZoneController.setup` when it STARTS a build and echoed
## on that build's `layout_result`, so a result arriving after Epsilon
## replaced the content or `reselect_hosts` regraphed it is recognised
## as being about a Zone that no longer exists -- and spends none of the
## replacement's budget, bars none of its rooms and commits nothing.
##
## THE SNAPSHOT FIRST, because the snapshot is what the build path
## reads. `main.gd::_to_zone` builds from
## `BridgeClient.active_zone()["zone"]`; nothing in this client is
## connected to `zone_ready_received` at all. A cold restart into a Zone
## that was generated and never committed gets a snapshot and no offer,
## so an implementation that only remembered offers would bind nothing
## on exactly the path a restart takes.
##
## The offer is the fallback, for a bridge that carries the identity
## there and not on the snapshot. `""` means this bridge sends no
## identity -- older than the field -- and the client then sends none,
## which is the documented legacy behaviour and NOT a silent omission:
## `ZoneController.proposal_id` is empty and says so.
func proposal_for(zone_id: String) -> String:
	if zone_id == "":
		return ""
	if str(active_zone().get("zone_id", "")) == zone_id:
		var from_snapshot := str(snapshot.get("active_proposal_id", ""))
		if from_snapshot != "":
			return from_snapshot
	return str(_offer_proposals.get(zone_id, ""))

## WHICH ATTEMPT at that proposal the bridge is on, for this Zone.
##
## `ZoneRecord.layout_refusals` — a quantity the record already keeps and
## already sends, on the same `active_zone` the build is made from. A
## refusal ends one attempt and begins the next, so the count IS the
## ordinal; `proposal_id` cannot serve, because two tries at identical
## content hash identically and are supposed to.
##
## `-1` when this bridge holds no record for the Zone, which the
## controller sends as nothing at all.
func attempt_for(zone_id: String) -> int:
	var record := active_zone()
	if zone_id == "" or str(record.get("zone_id", "")) != zone_id:
		return -1
	return int(record.get("layout_refusals", 0))

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

#: USES SENT AND NOT YET RESOLVED, per component:
#: `{component_id: {"generation": int, "index": int}}`. One at a time,
#: because a second press is gated on the count this already reduces.
#:
#: **The generation is half the key.** Without it a pending use survives
#: a refill and goes on subtracting from the new supply, and a refusal
#: cannot be told from one belonging to an older press.
#:
#: Resolved by exactly four things: a failed send (never recorded), a
#: refusal whose `about` matches (`_release_refused`), a snapshot under
#: the same generation whose `spent` has reached the index, or a
#: snapshot under a different one (`_settle_in_flight`). Reconnect
#: clears the lot.
#:
#: **RESIDUAL, stated rather than hidden:** a request that is neither
#: applied nor refused -- a frame lost in flight -- matches none of
#: those. It clears on the next reconnect, on the next refill, or when a
#: later use advances `spent` past it. Until then the count under-reports
#: by one, which is the conservative direction: it can refuse a press
#: the engine would have allowed, and it can never permit a second
#: effect. No timeout, because a timeout would be a guess about the
#: network dressed up as a fact about the protocol.
#:
#: A snapshot is a round trip away, so two fast presses would both see
#: the same remaining count and both fire. The engine refuses the second
#: spend -- `use_index` is a compare-and-swap -- but the refusal comes
#: back long after the grenade has already left the hand. So the count
#: this client shows and gates on subtracts what is in flight.
var _in_flight: Dictionary = {}


## The domain key of one spend, matching what the bridge puts in
## `BridgeError.about`. Built from the intent's own fields on both sides,
## never an opaque token this client invented -- the same rule as
## `key_id` and `LatchFired.(package_id, latch_id)`.
static func use_key(component_id: String, generation: int,
		index: int) -> String:
	return "use_consumable:%s:%d:%d" % [component_id, generation, index]


## RESERVE A CHARGE, BEFORE ANYTHING IRREVERSIBLE HAPPENS.
##
## **THE ORDER IS THE WHOLE CORRECTION.** This used to be one call that
## fired after `EchoRuntime.action_used`: the effect launched, and THEN
## the client tried to pay for it. Two things fell out of that and both
## were asserted as correct:
##
##   A FAILED SEND RAN THE EFFECT AND CHARGED NOTHING. Offline, the
##   grenade left the hand, the intent was dropped, and the count was
##   untouched -- an unpaid activation, repeatable for as long as the
##   bridge stayed down.
##   A REFUSAL REFUNDED A CHARGE WHOSE EFFECT HAD ALREADY HAPPENED, and
##   the refund was spendable. One charge, two activations.
##
## Not replaying the effect on a refusal is necessary and it is not
## sufficient. So the charge is taken FIRST, locally, and the effect is
## only allowed to run against a reservation that succeeded.
##
## Returns the reservation, or `{}` when there is nothing left to
## reserve — and `{}` means the press may not fire.
func reserve_consumable(component_id: String) -> Dictionary:
	if charges_left(component_id) <= 0:
		return {}
	var held := {"generation": int(snapshot.get(
					"consumable_generation", 0)),
			"index": charges_total(component_id)
					- charges_left(component_id) + 1,
			"disputed": false}
	_in_flight[component_id] = held
	return held


## THE PRESS RESOLVED INTO NOTHING, so give the charge back.
##
## **THE ONE REFUND THERE IS, and it is a PRE-LAUNCH refund.** `activate()`
## returns early on a cooldown, an unmet condition and a closed gate;
## none of those put anything in the world, so none of them has been paid
## for. Nothing has been sent at this point either, which is what makes
## the refund safe: there is no message for the engine to accept later.
func release_reservation(component_id: String) -> void:
	_in_flight.erase(component_id)


## THE EFFECT LAUNCHED. Tell the engine, and keep the charge spent
## whatever the answer is.
##
## **A FAILED SEND DOES NOT UN-FIRE A GRENADE.** If the socket is shut
## the engine never hears about this use, and the honest state is a
## charge the player spent and a campaign that has not recorded it —
## never a charge they get to spend again. It reconciles on the next
## authoritative snapshot, which is what `online` going false and the
## next `hello` are for.
##
## Returns whether the report actually went out, for callers that want to
## say so; the reservation stands either way.
func commit_consumable(component_id: String) -> bool:
	if not _in_flight.has(component_id):
		return false
	var held: Dictionary = _in_flight[component_id]
	return send_intent({"type": "use_consumable",
			"component_id": component_id,
			"use_index": int(held["index"]),
			"generation": int(held["generation"])})


## RESOLVE PENDING SPENDS FROM A SNAPSHOT -- and only the two ways a
## snapshot can actually resolve one.
##
## LANDED: same supply, and the engine's `spent` has reached the index.
## RETIRED: a different supply. The refill happened, so this use can
## never be applied and must stop reducing the NEW supply.
##
## What this deliberately does NOT do is clear on any snapshot that
## arrives. A snapshot generated before the engine saw the request would
## clear a use that is still genuinely in flight, and the next press
## would run the effect a second time against one charge.
##
## A DISPUTED RESERVATION SETTLES THE SAME TWO WAYS and no others. The
## engine refused it, so its `spent` will never reach the index and
## LANDED can never fire — but the effect happened, so the charge stays
## deducted until the supply is REPLACED or the session resyncs. That is
## the conservative direction: it can refuse a press the engine would
## have allowed, and it can never permit a second effect.
func _settle_in_flight() -> void:
	var generation := int(snapshot.get("consumable_generation", 0))
	for component_id: Variant in _in_flight.keys():
		var pending: Dictionary = _in_flight[component_id]
		if int(pending.get("generation", -1)) != generation:
			_in_flight.erase(component_id)
			continue
		var spent := charges_total(str(component_id)) \
				- _snapshot_charges_left(str(component_id))
		if spent >= int(pending.get("index", 0)):
			_in_flight.erase(component_id)


## MARK A RESERVATION DISPUTED — and **do not give the charge back**.
##
## Exact match on the domain key and nothing else: an error with an empty
## `about` is UNCHECKED, not "mine", so it cannot touch a reservation it
## has no evidence about.
##
## **THIS USED TO REFUND, AND THAT WAS THE BUG.** Every reservation that
## can still be refused here has already LAUNCHED — the effect is in the
## world, because `commit_consumable` is only reached after
## `action_used`. Handing the charge back made it spendable again, so one
## charge bought the effect that happened AND a second press. A refusal
## says the engine did not record the expenditure; it does not say the
## grenade came back.
##
## What the mark buys is the thing holding it forever would have cost:
## the client knows this index will never be confirmed, so it stops
## waiting for `spent` to reach it and settles on the next refill or
## resync instead of on nothing.
func _release_refused(about: String) -> void:
	if about.is_empty():
		return
	for component_id: Variant in _in_flight.keys():
		var held: Dictionary = _in_flight[component_id]
		if use_key(str(component_id), int(held.get("generation", -1)),
				int(held.get("index", 0))) == about:
			held["disputed"] = true
			_in_flight[component_id] = held
			return


func _snapshot_charges_left(component_id: String) -> int:
	var component: Dictionary = owned_component(component_id).get(
			"component", {})
	var charges: Variant = component.get("charges")
	if charges == null:
		return 0
	var spent := 0
	for raw: Variant in snapshot.get("consumable_uses", []):
		var use: Dictionary = raw
		if str(use.get("component_id", "")) == component_id:
			spent = int(use.get("spent", 0))
			break
	return maxi(int(charges) - spent, 0)


## HOW MANY USES A CONSUMABLE HAS LEFT. Zero for anything that is not one.
##
## Subtracted from the snapshot rather than counted here: the bridge sends
## what has been SPENT and the component carries what it started with, so
## the client never keeps a tally of its own button presses. A second
## count is a second truth, and the one that drifts is always the one on
## screen.
func charges_left(component_id: String) -> int:
	var component: Dictionary = owned_component(component_id).get(
			"component", {})
	var charges: Variant = component.get("charges")
	if charges == null:
		return 0
	# WHAT THE ENGINE HAS COUNTED, LESS WHAT IS STILL IN FLIGHT. The
	# second half is why one charge cannot fire twice.
	var left := _snapshot_charges_left(component_id)
	if _in_flight.has(component_id):
		var pending: Dictionary = _in_flight[component_id]
		var flying := int(pending.get("index", 0))
		var counted := int(charges) - left
		left = maxi(left - maxi(flying - counted, 0), 0)
	return left

## What it started with, for "2 of 3". Zero when it is not a consumable.
func charges_total(component_id: String) -> int:
	var charges: Variant = owned_component(component_id).get(
			"component", {}).get("charges")
	return 0 if charges == null else int(charges)

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
