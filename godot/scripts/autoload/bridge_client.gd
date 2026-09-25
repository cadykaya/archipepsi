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
## AN AUTHORISED CHARGE, and the moment the effect may run.
##
## D-9: the press asks and launches nothing. The engine moves `spent`,
## writes the save and broadcasts; THIS is that broadcast arriving, and
## it is the only thing that may start an irreversible effect. Emitted
## once per authorisation.
signal consumable_authorized(component_id: String, use_index: int)
## The press was refused, and nothing happened. `why` is the engine's
## own message, or a local one when there was no link to ask down.
signal consumable_denied(component_id: String, use_index: int,
		why: String)

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
	# THE AP WORLD IS NOT PAUSED (H-PAUSE). A paused game keeps its
	# connection and takes what is legitimately delivered while the pause
	# interface is open; snapshots, notifications and refusals still arrive.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
			# THE REPORTS THAT NEVER ARRIVED, sent again. A launched
			# effect the bridge never heard about cannot be settled by
			# the snapshot that follows -- the count it would be checked
			# against was never moved -- so this is the only thing that
			# can resolve it.
			resend_unconfirmed()
		while _socket.get_available_packet_count() > 0:
			_handle(_socket.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if online:
			online = false
			_abandon_awaiting()
			# **THE RESERVATIONS SURVIVE THE SOCKET, and the previous
			# version clearing them here was the defect.** A launched
			# effect whose report was lost cannot be reconciled by the
			# snapshot after the reconnect: the bridge never learned of
			# the expenditure, so its count will never move, and reading
			# an unchanged count as "it did not happen" refunds work
			# that did. Dropping a local dictionary is not
			# reconciliation. They are retransmitted on reconnect.
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

## WHETHER AN INTENT SENT NOW WOULD LEAVE THIS PROCESS -- exactly
## `send_intent`'s own test, so a control that asks this before offering
## itself cannot be told one thing and then do another. `assume_sent`
## counts here as it does there: a headless driver stands a menu in its
## online state the same way it stands a send in its sent one.
func can_send() -> bool:
	return assume_sent \
			or _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

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
			_release_refused(str(message.get("about", "")),
					str(message.get("message", "REFUSED")))
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

## H-UI-DATA: the menu's items and slots as the bridge projected them
## (`CampaignSnapshot.inventory`, Dess's `inventory_view.py`). The menu
## joins it to `mechanics.owned` by component id and derives nothing the
## view already answers. Empty from a bridge older than the field.
func inventory_view() -> Dictionary:
	var view: Variant = snapshot.get("inventory")
	return view if typeof(view) == TYPE_DICTIONARY else {}

## The Action in a slot, as the runtime wants it. Empty when the slot is
## clear — which is a legal, playable state: the Static Pulse is never the
## thing in a slot.
func slotted_action(slot := "echo_a") -> Dictionary:
	var id: Variant = slots().get(slot)
	if id == null:
		return {}
	return owned_component(str(id)).get("component", {})

#: RESERVATIONS HELD AGAINST A CONSUMABLE, as
#: `{component_id: [{generation, index, launched, disputed}, ...]}`.
#:
#: **A LIST, AND THE LIST IS THE SECOND CORRECTION.** This held ONE
#: reservation per component, and that quietly lost launched work:
#: with several charges and a real cooldown, launching use 1 and then
#: pressing again during the cooldown made `reserve_consumable`
#: OVERWRITE use 1's entry with use 2's, and the cancel that followed
#: the refused press erased the pair. One grenade in the world, and the
#: count said nothing had been spent.
#:
#: So a cancel now removes exactly the attempt it is cancelling, and
#: only if that attempt never launched. Earlier launched expenditures
#: are not the cancel's business.
#:
#: `launched` is what separates the two: false means `activate()` has
#: not yet been reached or returned early, true means the effect is in
#: the world and the charge is spent whatever anyone says afterwards.
#: `disputed` means the engine refused the report — the expenditure
#: still happened, and the mark only stops the client waiting for a
#: `spent` that will never arrive.
#:
#: **The generation is half the key.** Without it a reservation survives
#: a refill and goes on subtracting from the new supply, and a refusal
#: cannot be told from one belonging to an older press.
#:
#: Settled by: a snapshot under a different generation (the supply was
#: replaced), a snapshot whose `spent` has reached the index (it landed),
#: or a cancel before launch. A refusal marks rather than settles.
#:
#: **Not cleared on a disconnect.** An effect that launched and whose
#: report never arrived cannot be reconciled by a later snapshot,
#: because the bridge never learned of it — so dropping the reservation
#: there is not reconciliation, it is a refund of work that happened.
#: They are RETRANSMITTED on reconnect instead, which the engine's
#: (generation, index) compare-and-swap makes idempotent: a report that
#: already landed is refused as a duplicate, and one that never arrived
#: applies.
var _in_flight: Dictionary = {}


## Reservations held for a component, newest last. Never null.
func _held(component_id: String) -> Array:
	var list: Variant = _in_flight.get(component_id)
	return list if list is Array else []


## How many of a component's reservations the engine has NOT yet counted.
## Those are the ones the displayed count has to subtract; one whose
## index the engine's `spent` has already passed is in the snapshot.
func _outstanding(component_id: String, spent: int) -> int:
	var n := 0
	for raw: Variant in _held(component_id):
		if int((raw as Dictionary).get("index", 0)) > spent:
			n += 1
	return n


## The domain key of one spend, matching what the bridge puts in
## `BridgeError.about`. Built from the intent's own fields on both sides,
## never an opaque token this client invented -- the same rule as
## `key_id` and `LatchFired.(package_id, latch_id)`.
static func use_key(component_id: String, generation: int,
		index: int) -> String:
	return "use_consumable:%s:%d:%d" % [component_id, generation, index]


## RESERVE A CHARGE, BEFORE ANYTHING IRREVERSIBLE HAPPENS.
##
## **THE ORDER IS THE FIRST CORRECTION.** This used to run after
## `EchoRuntime.action_used`: the effect launched, and THEN the client
## tried to pay for it. An offline press ran an unpaid activation, and a
## refusal refunded a charge whose effect was already in the world.
##
## Returns the reservation, or `{}` when there is nothing left to
## reserve — and `{}` means the press may not fire. It APPENDS, so a
## second reservation taken while a first is outstanding is a second
## charge and not a replacement for the first.
func reserve_consumable(component_id: String) -> Dictionary:
	if charges_left(component_id) <= 0:
		return {}
	var spent := charges_total(component_id) \
			- _snapshot_charges_left(component_id)
	var held := {"generation": int(snapshot.get(
					"consumable_generation", 0)),
			"index": spent + _outstanding(component_id, spent) + 1,
			"launched": false, "disputed": false}
	var list := _held(component_id)
	list.append(held)
	_in_flight[component_id] = list
	return held


## THE PRESS RESOLVED INTO NOTHING, so give THAT charge back.
##
## **EXACTLY THE ATTEMPT BEING CANCELLED, and only if it never
## launched.** `activate()` returns early on a cooldown, an unmet
## condition and a closed gate; none of those put anything in the world,
## and nothing has been sent for them either, which is what makes the
## refund safe.
##
## It used to erase the component's whole entry, which with one entry
## per component meant a cancel could forget an earlier LAUNCHED use.
## The newest reservation is the one this press took, so that is the one
## removed — and a launched one is never removed here at all.
func release_reservation(component_id: String) -> void:
	var list := _held(component_id)
	if list.is_empty():
		return
	var last: Dictionary = list[list.size() - 1]
	if bool(last.get("launched", false)):
		return                 # already in the world: not a cancel's business
	list.pop_back()
	if list.is_empty():
		_in_flight.erase(component_id)
	else:
		_in_flight[component_id] = list


## ASK FOR THE CHARGE. **Nothing irreversible may happen until the
## answer comes back** — D-9 §2, and the whole reason the order changed.
##
## The press used to launch and then report, which meant an expenditure
## the engine never heard of lived only in this process's memory: kill
## Godot between the two and the charge was spendable again. Asking
## first makes a lost message an effect that never happened, and there
## is nothing for a dead process to lose.
##
## Returns false when there was no link to ask down. *Offline firing is
## not a requirement* — the press is refused, like an empty supply.
func authorize_consumable(component_id: String) -> bool:
	var list := _held(component_id)
	if list.is_empty():
		return false
	var held: Dictionary = list[list.size() - 1]
	var sent := send_intent({"type": "authorize_consumable",
			"component_id": component_id,
			"use_index": int(held["index"]),
			"generation": int(held["generation"])})
	if not sent:
		# NOTHING WAS ASKED, so there is nothing to give back but the
		# local reservation, and the press cost nothing.
		release_reservation(component_id)
		consumable_denied.emit(component_id, int(held["index"]),
				"NO LINK TO THE BRIDGE")
		return false
	held["awaiting"] = true
	list[list.size() - 1] = held
	_in_flight[component_id] = list
	return true


## THE EFFECT LAUNCHED, against an authorisation the engine already
## counted. The report SETTLES the authorisation; it spends nothing
## more, so a lost one costs a refund and never a second charge.
##
## **AND THE RESERVATION IS DONE.** Under the old ordering it had to
## stay: it was the only record that the charge had been spent. It is
## not any more -- the engine counted the charge before the effect ran,
## and the count is on the snapshot -- so holding it would subtract the
## same charge twice, once from `spent` and once from `_outstanding`.
func commit_consumable(component_id: String) -> bool:
	var list := _held(component_id)
	if list.is_empty():
		return false
	var held: Dictionary = list.pop_back()
	if list.is_empty():
		_in_flight.erase(component_id)
	else:
		_in_flight[component_id] = list
	return _report(component_id, held)


## THE AUTHORISED PRESS RESOLVED INTO NOTHING. A cooldown, an unmet
## condition, a closed gate — `activate()` returned before anything
## reached the world — so the charge comes back.
##
## **This is the only refund there is**, and it is a claim only this
## process can make: whether the effect launched is known here and
## nowhere else. The engine enforces that the attempt being cancelled is
## the newest one, which is what stops a relaunched client refunding a
## dead process's expenditure.
func release_authorization(component_id: String) -> bool:
	var list := _held(component_id)
	if list.is_empty():
		return false
	var held: Dictionary = list[list.size() - 1]
	if bool(held.get("launched", false)):
		return false
	list.pop_back()
	if list.is_empty():
		_in_flight.erase(component_id)
	else:
		_in_flight[component_id] = list
	return send_intent({"type": "release_consumable_authorization",
			"component_id": component_id,
			"use_index": int(held["index"]),
			"generation": int(held["generation"])})


## TEST SEAM: swallow the settle report, as a lost message would.
##
## `godot-consumable-restart` needs the state D-9 exists for -- an
## authorisation the engine counted and a report it never received --
## and the only honest way to produce it is for the report not to
## arrive. Never set by anything the player can reach.
var drop_reports := false


func _report(component_id: String, held: Dictionary) -> bool:
	if drop_reports:
		return false
	return send_intent({"type": "use_consumable",
			"component_id": component_id,
			"use_index": int(held["index"]),
			"generation": int(held["generation"])})


## RETRANSMIT EVERY LAUNCHED, UNCONFIRMED REPORT.
##
## **This is the reconciliation a cleared dictionary was pretending to
## be.** A launched effect whose report was lost cannot be reconciled by
## a later snapshot — the bridge never learned about it, so its count
## will never move, and waiting is waiting for nothing. Sending again is
## the only thing that can settle it.
##
## Safe to repeat because the engine's transaction is a compare-and-swap
## on (generation, index): a report that already landed is refused as a
## duplicate and changes nothing, and one that never arrived applies.
func resend_unconfirmed() -> void:
	for component_id: Variant in _in_flight.keys():
		for raw: Variant in _held(str(component_id)):
			var held: Dictionary = raw
			if bool(held.get("launched", false)):
				_report(str(component_id), held)


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
## THE LINK WENT DOWN WITH A PRESS UNANSWERED.
##
## It may not fire: a grenade that goes off ten seconds late, when the
## socket happens to come back, is worse than one that does not go off.
## And it may not be refunded here either, because the client cannot
## know whether the engine counted it before the drop.
##
## So it is marked and left for the reconnect snapshot, which IS the
## answer: `spent` past it means the engine took the charge (gone, and
## nothing fires), `spent` short of it means the request never landed
## (the charge was never taken). `_settle_in_flight` reads the mark.
func _abandon_awaiting() -> void:
	for component_id: Variant in _in_flight.keys():
		var list := _held(str(component_id))
		for i in list.size():
			var held: Dictionary = list[i]
			if bool(held.get("awaiting", false)):
				held["awaiting"] = false
				held["abandoned"] = true
				list[i] = held
		_in_flight[component_id] = list


## Authorisations confirmed by the snapshot being settled, announced
## AFTER the walk rather than during it: a handler that pressed again
## would be mutating `_in_flight` inside the loop that is rebuilding it.
var _authorized: Array = []


func _settle_in_flight() -> void:
	var generation := int(snapshot.get("consumable_generation", 0))
	_authorized.clear()
	for component_id: Variant in _in_flight.keys():
		var cid := str(component_id)
		var spent := charges_total(cid) - _snapshot_charges_left(cid)
		var kept: Array = []
		for raw: Variant in _held(cid):
			var held: Dictionary = raw
			# RETIRED: the supply was replaced, so this reservation is
			# about a supply that no longer exists.
			if int(held.get("generation", -1)) != generation:
				continue
			# ABANDONED: the link dropped with this press unanswered,
			# and this snapshot is the answer. Either way it is
			# finished: counted means the charge is gone and nothing
			# fires, uncounted means it never arrived and the charge was
			# never taken. Both are "stop holding it".
			if bool(held.get("abandoned", false)):
				continue
			# LANDED: the engine has counted it.
			if spent >= int(held.get("index", 0)):
				# **AND IF IT WAS WAITING TO BE ALLOWED TO FIRE, THIS IS
				# THE MOMENT.** The engine has moved `spent` and written
				# the save, so the charge is paid for and the effect may
				# now happen. The reservation is KEPT while the effect
				# runs -- `commit_consumable` or `release_authorization`
				# closes it -- because a press still deciding what it did
				# is not a press that is finished.
				if bool(held.get("awaiting", false)):
					held["awaiting"] = false
					kept.append(held)
					_authorized.append([cid, int(held.get("index", 0))])
				continue
			kept.append(held)
		if kept.is_empty():
			_in_flight.erase(component_id)
		else:
			_in_flight[component_id] = kept
	for raw: Variant in _authorized:
		var pair: Array = raw
		consumable_authorized.emit(str(pair[0]), int(pair[1]))
	_authorized.clear()


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
func _release_refused(about: String, why := "REFUSED") -> void:
	if about.is_empty():
		return
	for component_id: Variant in _in_flight.keys():
		var list := _held(str(component_id))
		for i in list.size():
			var held: Dictionary = list[i]
			if use_key(str(component_id),
					int(held.get("generation", -1)),
					int(held.get("index", 0))) == about:
				# **A REFUSED AUTHORISATION IS A PRESS THAT NEVER
				# HAPPENED.** Nothing launched -- that is the point of
				# asking first -- so the reservation goes, the charge was
				# never taken, and the player is told. A refused REPORT is
				# the other thing entirely: the effect is in the world and
				# the charge stays gone, so that one is only marked.
				if bool(held.get("awaiting", false)):
					list.remove_at(i)
					if list.is_empty():
						_in_flight.erase(component_id)
					else:
						_in_flight[component_id] = list
					consumable_denied.emit(str(component_id),
							int(held.get("index", 0)), why)
					return
				held["disputed"] = true
				list[i] = held
				_in_flight[component_id] = list
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
	# EVERY RESERVATION THE ENGINE HAS NOT COUNTED comes off, not just
	# the newest one. With a list there can be several at once -- two
	# fast presses inside one round trip are two charges -- and
	# subtracting only the highest index would let the second fire free.
	var spent := int(charges) - left
	return maxi(left - _outstanding(component_id, spent), 0)

## Uses asked for and not yet answered (D-9 §2): the press is waiting on
## the bridge, and nothing has reached the world. What the equipment face
## shows as PENDING AUTHORISATION -- a fact about this process's requests,
## which the bridge deliberately does not mirror (D-9 §3).
func awaiting_authorization(component_id: String) -> int:
	var n := 0
	for raw: Variant in _held(component_id):
		if bool((raw as Dictionary).get("awaiting", false)):
			n += 1
	return n

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
