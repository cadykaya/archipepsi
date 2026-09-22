extends Node
## THE CONSUMABLE SLOT, AT RUNTIME (`make godot-consumable`).
##
## `archive_driver.gd` asks what the menu SHOWS. This asks what the fifth
## slot DOES: whether a press fires, whether a charge is spent, and —
## the question the whole spend transaction exists for — whether one
## charge can ever produce two effects.
##
## **TWO COUNTS THAT MUST STAY EQUAL.** Charges the engine accepts, and
## actions that actually ran. They are not the same number and nothing
## makes them equal automatically: the effect runs on the press, the
## spend is a round trip away, and a refusal arrives after the grenade
## has left the hand. So every case here counts BOTH, and the interesting
## failures are the ones where they come apart.
##
## **The real gate, not a copy of it.** Presses go through
## `Player.press_slot`, which is what `_physics_process` calls. A driver
## that reimplemented the exhausted check would be measuring its own
## arithmetic.

const DT := 1.0 / 60.0

var failures := 0
var checks := 0

var _player: Player = null
var _pool: ResourcePool = null
var _floor: StaticBody3D = null
var _target: StaticBody3D = null

## Actions that actually resolved — `EchoRuntime.action_used`, the same
## signal the charge is spent from.
var _effects := 0
## Presses the supply refused, via `Player.exhausted`.
var _refusals := 0


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _ready() -> void:
	_run()


# ---------------------------------------------------------------------------
# The world
# ---------------------------------------------------------------------------

const COMPONENT := "act_nade"
const CHARGES := 3

## A consumable that does something REAL: it damages what it hits and
## leaves `burning` on it. Both halves are implemented runtime effects —
## `hitscan_damage` is a primitive and `burning` is supported on `enemy`
## in `Constants.ECHO_STATUS_SUPPORTED_TARGETS` — so this case is a
## played effect and not a schema that validates.
func _component() -> Dictionary:
	return {
		"kind": "action", "component_id": COMPONENT,
		"display_name": "Cinder Charge", "description": "Boom, then burn.",
		"slot": "consumable", "cooldown": 0.0, "charges": CHARGES,
		"primitive": {"type": "hitscan_damage", "damage": 9.0,
				"pellets": 1, "spread_degrees": 0.0, "range": 40.0},
		"modifiers": [{"type": "apply_status_on_hit", "status": "burning",
				"duration": 3.0, "magnitude": 0.5}],
	}


## The same supply with a REAL cooldown, for the cancel case: the
## zero-cooldown one can never produce a press that resolves into
## nothing, which is the whole situation being tested.
func _component_with_cooldown() -> Dictionary:
	var made := _component()
	made["cooldown"] = 5.0
	return made


## A snapshot with `spent` charges gone and the supply on Q.
func _snapshot(spent: int, generation := 1) -> Dictionary:
	var uses: Array = []
	if spent > 0:
		uses.append({"component_id": COMPONENT, "spent": spent})
	return {
		"type": "campaign_snapshot",
		"mechanics": {"owned": [{"kind": "action", "mk": 1,
				"component": _component(), "provenance": []}]},
		"slots": {"echo_a": null, "echo_b": null, "mobility": null,
				"utility": null, "consumable": COMPONENT},
		"consumable_uses": uses,
		"consumable_generation": generation,
		# THE ECHO THAT GAVE IT. The archive lists interpretations, not
		# owned components -- an owned Action with no Echo behind it is
		# not a row, so there is nothing to equip it from.
		"interpretations": [{
			"schema_version": 8, "echo_id": "echo_89100042",
			"interpretation_seq": 0, "source_location_id": 89100042,
			"source_item_name": "Bombchu", "source_game": "Ocarina of Time",
			"source_recipient_name": "oot_player",
			"concepts": ["fire", "thrown"], "mode": "literal",
			"display_name": "Cinder Charge", "description": "Boom, then burn.",
			"tags": [],
			"operations": [{"op": "create", "component": _component()}],
		}],
	}


## Deliver a snapshot the way the socket would, so `_settle_in_flight`
## runs on the real path rather than being called directly.
func _deliver(snapshot: Dictionary) -> void:
	BridgeClient._handle(JSON.stringify(snapshot))


## Deliver a refusal the way the socket would.
func _refuse(about: String) -> void:
	BridgeClient._handle(JSON.stringify({
		"type": "error", "scope": "bridge", "recoverable": true,
		"message": "refused", "about": about}))


func _build_world() -> void:
	_floor = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	_floor.add_child(shape)
	add_child(_floor)

	_pool = ResourcePool.new()
	_pool.name = "ResourcePool"
	add_child(_pool)

	_player = Player.create()
	add_child(_player)
	_player.global_position = Vector3(0, 1, 0)
	# Presses are driven by `press_slot`, not by the InputMap: the
	# question is what a press DOES, not which key produced it.
	_player.input_frozen = true
	_player.stat_stack.pool = _pool
	for slot: String in Constants.SLOT_NAMES:
		var runtime: EchoRuntime = _player.runtimes[slot]
		runtime.pool = _pool
	_player.exhausted.connect(func(_name: String) -> void: _refusals += 1)
	_player.runtimes["consumable"].action_used.connect(
			func() -> void: _effects += 1)

	# A DUMMY THAT CAN BE HURT AND CAN BURN. Group membership is what
	# `Damageable.of` asks for, and `statuses` is what the
	# `apply_status_on_hit` modifier reaches into.
	_target = StaticBody3D.new()
	_target.set_script(load("res://tests/support/burnable_target.gd"))
	var t_shape := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(2, 2, 2)
	t_shape.shape = t_box
	_target.add_child(t_shape)
	add_child(_target)
	_target.add_to_group(Damageable.GROUP)

	await get_tree().physics_frame
	await get_tree().physics_frame
	# AT EYE HEIGHT, measured rather than assumed. Parked at the player's
	# own y the box sat below the camera and every shot sailed over it —
	# which made the damage case fail and the Status case pass vacuously.
	_target.global_position = _player.camera.global_position \
			+ Vector3(0, 0, -6)
	await get_tree().physics_frame


## Point the camera at the dummy and re-equip from the snapshot.
func _reset(spent := 0, generation := 1) -> void:
	BridgeClient.snapshot = {}
	BridgeClient._in_flight.clear()
	BridgeClient.sent_intents.clear()
	_effects = 0
	_refusals = 0
	_deliver(_snapshot(spent, generation))
	var runtime: EchoRuntime = _player.runtimes["consumable"]
	runtime.reset_cooldown()
	runtime.set_equipped(_component())
	_player.global_position = Vector3(0, 1, 0)
	_player.camera.global_rotation = Vector3(0, 0, 0)   # looking down -Z
	_target.reset_for_case()
	await get_tree().physics_frame


func _uses_sent() -> int:
	var n := 0
	for intent: Dictionary in BridgeClient.sent_intents:
		if intent.get("type", "") == "use_consumable":
			n += 1
	return n


func _last_use() -> Dictionary:
	for i in range(BridgeClient.sent_intents.size() - 1, -1, -1):
		var intent: Dictionary = BridgeClient.sent_intents[i]
		if intent.get("type", "") == "use_consumable":
			return intent
	return {}


# ---------------------------------------------------------------------------

func _run() -> void:
	await _build_world()

	# Every case but `_a_send_that_failed_is_never_held` needs the send
	# half to succeed, and a headless driver has no bridge to succeed
	# against. That one case clears this again for itself.
	BridgeClient.assume_sent = true

	await _it_damages_and_burns_what_it_hits()
	await _an_empty_supply_refuses_before_it_costs_anything()
	await _two_presses_on_one_charge_fire_once()
	await _a_refusal_does_not_hand_the_charge_back()
	await _a_press_that_never_launched_costs_nothing()
	await _an_unattributed_refusal_releases_nothing()
	await _a_refusal_about_another_use_releases_nothing()
	await _a_snapshot_that_has_not_caught_up_releases_nothing()
	await _a_refill_retires_a_use_still_in_flight()
	await _a_dropped_report_does_not_make_the_charge_free()
	await _a_disconnect_keeps_what_launched()
	await _a_cancel_does_not_forget_an_earlier_launch()
	await _swapping_away_and_back_is_not_a_refill()
	await _the_menu_shows_an_exhausted_supply_and_what_refills_it()
	await _a_held_player_does_not_fire_while_the_archive_is_open()

	BridgeClient.assume_sent = false
	if failures == 0:
		print("GODOT CONSUMABLE TESTS OK (%d checks)" % checks)
		get_tree().quit(0)
	else:
		print("GODOT CONSUMABLE TESTS: %d failures in %d checks"
				% [failures, checks])
		get_tree().quit(1)


# ---------------------------------------------------------------------------
# The effect is real
# ---------------------------------------------------------------------------

## A CONSUMABLE IS NOT A COUNTER. §9's slot holds a verb that does
## something, and the something has to arrive at a target: damage off the
## primitive and a Status off the modifier, both through the ordinary
## `EchoRuntime` path that every other Action uses.
func _it_damages_and_burns_what_it_hits() -> void:
	print("  -- a real consumable delivers damage AND a Status")
	await _reset()
	var before: float = _target.hp
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_target.hp < before,
			"the dummy took damage (%.1f -> %.1f)" % [before, _target.hp])
	_check(_target.statuses.has("burning"),
			"and is burning, through apply_status_on_hit")
	_check(_effects == 1, "one action resolved")
	_check(_uses_sent() == 1, "and one use was sent")
	var sent := _last_use()
	_check(int(sent.get("use_index", 0)) == 1
			and int(sent.get("generation", -1)) == 1,
			"naming use 1 of supply 1 — the index AND the supply")

	# NORMAL EXPIRY, not just application: a Status that never ends is a
	# different bug wearing the same green tick.
	#
	# **GUARDED, because the first draft of this case passed vacuously.**
	# The shot was missing, so nothing was burning, so "it stopped
	# burning" was true for the wrong reason. An expiry assertion is only
	# evidence if something was there to expire.
	var was_burning: bool = _target.statuses.has("burning")
	for _i in int(3.5 / DT):
		_target.statuses.tick(DT)
	_check(was_burning and not _target.statuses.has("burning"),
			"and the burn ends on its own after its duration")


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------

## AN EXHAUSTED SUPPLY IS STILL EQUIPPED. The owner's correction: the
## slot is not cleared when the last charge goes, so the refusal is about
## USING one, not about holding one.
func _an_empty_supply_refuses_before_it_costs_anything() -> void:
	print("  -- zero charges: refused, and it costs nothing")
	await _reset(CHARGES)
	_check(BridgeClient.charges_left(COMPONENT) == 0, "nothing left")
	var before: float = _target.hp
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 0, "no action resolved")
	_check(_refusals == 1, "the player was told it is exhausted")
	_check(_uses_sent() == 0, "and nothing was sent to the bridge")
	_check(is_equal_approx(_target.hp, before), "the dummy is untouched")
	_check(is_zero_approx(
			(_player.runtimes["consumable"] as EchoRuntime).cooldown_remaining),
			"no cooldown was charged for a press that could not resolve")
	_check(str(BridgeClient.slots().get("consumable", "")) == COMPONENT,
			"and the supply is STILL EQUIPPED at zero")


## THE CASE THE WHOLE TRANSACTION EXISTS FOR. One charge, two presses,
## and the snapshot that would settle the first is a round trip away.
func _two_presses_on_one_charge_fire_once() -> void:
	print("  -- one charge, two presses, no snapshot between them")
	await _reset(CHARGES - 1)
	_check(BridgeClient.charges_left(COMPONENT) == 1, "one charge left")
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"the press is subtracted immediately, before any snapshot")
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 1, "EXACTLY ONE action resolved")
	_check(_refusals == 1, "the second press was refused as exhausted")
	_check(_uses_sent() == 1, "and exactly one use was sent")


## **ONE CHARGE BUYS ONE AUTHORIZED ACTIVATION, and a refusal does not
## buy a second.**
##
## This case used to assert the opposite and call it correct: the
## refusal handed the charge back, a new press fired, and the suite
## reported two effects from one charge as a feature. The effect is
## already in the world by the time any refusal can arrive — a refusal
## says the engine did not RECORD the expenditure, not that the grenade
## came back.
func _a_refusal_does_not_hand_the_charge_back() -> void:
	print("  -- a refusal disputes the charge; it does not refund it")
	await _reset(CHARGES - 1)
	_player.press_slot("consumable")
	await get_tree().physics_frame
	var sent := _last_use()
	_check(_effects == 1 and BridgeClient.charges_left(COMPONENT) == 0,
			"one effect, and the charge is spent")

	_refuse(BridgeClient.use_key(COMPONENT, int(sent["generation"]),
			int(sent["use_index"])))
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"the refusal did NOT give the charge back")
	_check(_effects == 1, "and the effect did not re-run")

	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 1,
			"a press after the refusal fires NOTHING — one charge, one "
			+ "activation, and the refusal did not buy a second")
	_check(_refusals == 1, "the player is told the supply is empty")
	_check(_uses_sent() == 1, "and no second use was sent")


## A PRESS THAT RESOLVED INTO NOTHING IS THE ONE REFUND THERE IS.
##
## `activate()` returns early on a cooldown, and nothing goes into the
## world — so nothing has been paid for, and nothing has been SENT
## either, which is what makes the refund safe. Keeping this distinct
## from "launched and missed" is the whole reason the reservation is
## taken before the effect and released after it fails.
func _a_press_that_never_launched_costs_nothing() -> void:
	print("  -- pre-launch failure: refunded, and never reported")
	await _reset()
	var runtime: EchoRuntime = _player.runtimes["consumable"]
	runtime.cooldown_remaining = 5.0          # it cannot fire
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 0, "nothing launched")
	_check(BridgeClient.charges_left(COMPONENT) == CHARGES,
			"the charge came back — a cooldown is not an expenditure")
	_check(_uses_sent() == 0,
			"and NOTHING was sent, so there is no message for the "
			+ "engine to accept later")
	_check(BridgeClient._in_flight.is_empty(), "no reservation is held")
	runtime.reset_cooldown()


# ---------------------------------------------------------------------------
# What may NOT release a pending use
# ---------------------------------------------------------------------------

## EMPTY MEANS UNCHECKED, NEVER "MINE". Every refusal that existed before
## `about` carries "", and a client that treated those as its own would
## release a spend on the strength of an unrelated failure.
func _an_unattributed_refusal_releases_nothing() -> void:
	print("  -- an error with no `about` releases nothing")
	await _reset(CHARGES - 1)
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_refuse("")
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"the use is still held")
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 1, "so a second press still cannot fire")


func _a_refusal_about_another_use_releases_nothing() -> void:
	print("  -- a refusal about a different use releases nothing")
	await _reset(CHARGES - 1)
	_player.press_slot("consumable")
	await get_tree().physics_frame
	var sent := _last_use()
	var generation := int(sent["generation"])
	var index := int(sent["use_index"])
	# Same component, wrong supply.
	_refuse(BridgeClient.use_key(COMPONENT, generation + 1, index))
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"a key naming another supply is not this use")
	# Same supply, wrong index.
	_refuse(BridgeClient.use_key(COMPONENT, generation, index + 1))
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"and a key naming another index is not either")
	# ...and the right one does REACH it, so the case is about the match
	# and not about the client having stopped listening. Reaching it
	# marks it disputed; it never refunds.
	_refuse(BridgeClient.use_key(COMPONENT, generation, index))
	_check(bool(((BridgeClient._in_flight[COMPONENT] as Array)[0]
			as Dictionary).get("disputed", false)),
			"the exact key marks it disputed")
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"and the charge is STILL spent — disputed is not refunded")


## **NOT ON EVERY SNAPSHOT.** A snapshot generated before the engine saw
## the request says nothing about it. Clearing on one would hand the
## charge back while the spend is still genuinely in flight, and the next
## press would run the effect a second time on it.
func _a_snapshot_that_has_not_caught_up_releases_nothing() -> void:
	print("  -- a snapshot that has not caught up releases nothing")
	await _reset(CHARGES - 1)
	_player.press_slot("consumable")
	await get_tree().physics_frame
	# The same supply, the same count: this frame crossed the request on
	# the wire.
	_deliver(_snapshot(CHARGES - 1))
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"the use is still in flight")
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 1, "and one charge still produced one effect")
	# The snapshot that HAS caught up does settle it.
	_deliver(_snapshot(CHARGES))
	_check(BridgeClient._in_flight.is_empty(),
			"the snapshot whose count reaches the index settles it")
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"leaving the engine's count, not a doubled subtraction")


## A REFILL RETIRES IT. The use can never be applied — its supply is
## gone — so it must stop reducing the new one.
func _a_refill_retires_a_use_still_in_flight() -> void:
	print("  -- a refill retires a use still in flight")
	await _reset(CHARGES - 1)
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(BridgeClient.charges_left(COMPONENT) == 0, "held in flight")
	_deliver(_snapshot(0, 2))         # a new deployment: fresh supply
	_check(BridgeClient._in_flight.is_empty(),
			"the pending use was retired by the new supply")
	_check(BridgeClient.charges_left(COMPONENT) == CHARGES,
			"and the menu shows the FULL new supply, not one short")


# ---------------------------------------------------------------------------
# The transport
# ---------------------------------------------------------------------------

## **A DROPPED REPORT DOES NOT MAKE THE CHARGE FREE.**
##
## This case used to assert that an offline press ran the effect and left
## the count untouched, and called that correct. It is an unpaid
## activation, repeatable for as long as the bridge stays down.
##
## The grenade left the hand. The engine has not heard and may never
## hear, and the honest state is a charge the player spent against a
## campaign that has not recorded it — never a charge they get to spend
## again. It reconciles on the next authoritative snapshot.
func _a_dropped_report_does_not_make_the_charge_free() -> void:
	print("  -- offline: the effect costs its charge anyway")
	await _reset(CHARGES - 1)
	BridgeClient.assume_sent = false          # no socket, and no pretending
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 1, "the effect ran — the player had a charge")
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"and it COST that charge, though nothing was reported")

	# REPEATED OFFLINE PRESSES buy nothing. This is the case the old
	# assertion would have let through indefinitely.
	for _i in 3:
		_player.press_slot("consumable")
		await get_tree().physics_frame
	_check(_effects == 1,
			"three more offline presses fire NOTHING (%d effects total)"
			% _effects)
	_check(_refusals == 3, "each is refused as exhausted")
	BridgeClient.assume_sent = true

	# ...AND THE RECONNECT RETRANSMITS RATHER THAN REFUNDING. The engine
	# never recorded the expenditure, so its count cannot settle it --
	# reading an unchanged count as "it did not happen" would hand back
	# a charge whose grenade is in the world. The report goes again.
	var before := _uses_sent()
	BridgeClient.online = false
	BridgeClient.resend_unconfirmed()
	_check(_uses_sent() == before + 1,
			"the lost report is sent again, not written off")
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"and the charge stays spent across the disconnect")
	_deliver(_snapshot(CHARGES))              # the retransmit landed
	_check(BridgeClient._in_flight.is_empty(),
			"the snapshot that counts it finally settles it")


## **THE RESERVATIONS SURVIVE THE SOCKET**, and the old case asserting
## that they were dropped was asserting a refund.
##
## A launched effect whose report was lost cannot be reconciled by the
## snapshot after the reconnect: the bridge never learned of it, so its
## count will never move, and treating an unchanged count as proof it
## did not happen gives back a charge whose grenade is in the world.
## Clearing a local dictionary is not reconciliation.
func _a_disconnect_keeps_what_launched() -> void:
	print("  -- a disconnect keeps launched work; reconnect resends it")
	await _reset(CHARGES - 1)
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(not BridgeClient._in_flight.is_empty(), "one reservation held")

	BridgeClient.online = true
	BridgeClient._process(DT)                 # the socket is shut
	_check(not BridgeClient.online, "the client knows it is offline")
	_check(not BridgeClient._in_flight.is_empty(),
			"and the reservation is STILL HELD — the effect happened")
	_check(BridgeClient.charges_left(COMPONENT) == 0,
			"so the charge is still spent")

	var before := _uses_sent()
	BridgeClient.resend_unconfirmed()
	_check(_uses_sent() == before + 1,
			"reconnect retransmits the report the bridge never got")


## **THE CANCEL MUST NOT FORGET A LAUNCHED USE**, which is what one
## reservation per component quietly did.
##
## Several charges and a real cooldown: launch use 1 with the snapshot
## still in transit, then press again while the cooldown is running. The
## second press reserves, `activate()` refuses it, and the cancel that
## follows used to erase the component's whole entry -- taking use 1's
## launched expenditure with it. One grenade in the world, and a count
## that said nothing had been spent.
func _a_cancel_does_not_forget_an_earlier_launch() -> void:
	print("  -- cancel during cooldown keeps the launched use")
	await _reset()                            # three charges, none spent
	var runtime: EchoRuntime = _player.runtimes["consumable"]
	runtime.set_equipped(_component_with_cooldown())

	_player.press_slot("consumable")           # USE 1: launches
	await get_tree().physics_frame
	_check(_effects == 1, "use 1 launched")
	_check(BridgeClient.charges_left(COMPONENT) == CHARGES - 1,
			"and cost a charge (%d left)"
			% BridgeClient.charges_left(COMPONENT))
	_check(_uses_sent() == 1, "and was reported")

	# NO SNAPSHOT YET. The engine has not answered, so use 1 is still
	# outstanding when the second press arrives.
	_player.press_slot("consumable")           # USE 2: refused on cooldown
	await get_tree().physics_frame
	_check(_effects == 1, "the cooldown press launched nothing")
	_check(_uses_sent() == 1, "and reported nothing")
	_check(BridgeClient.charges_left(COMPONENT) == CHARGES - 1,
			"AND USE 1 IS STILL SPENT (%d left, expected %d)"
			% [BridgeClient.charges_left(COMPONENT), CHARGES - 1])

	# ...and the cancelled attempt really was cancelled: once the
	# cooldown clears, the next press is use 2 and not use 3.
	runtime.reset_cooldown()
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 2, "the next press launches")
	_check(int(_last_use().get("use_index", 0)) == 2,
			"as use 2 — the cancelled attempt consumed no index, got %d"
			% int(_last_use().get("use_index", 0)))


# ---------------------------------------------------------------------------
# Living with one between presses
# ---------------------------------------------------------------------------

## EXPENDITURE FOLLOWS THE COMPONENT, not the slot. Taking the supply out
## and putting it back must not be a refill — the slot is not a hiding
## place for a fresh one — and the equipped Action resumes live.
func _swapping_away_and_back_is_not_a_refill() -> void:
	print("  -- swap away and back: the count is unchanged")
	await _reset(1)
	_check(BridgeClient.charges_left(COMPONENT) == CHARGES - 1,
			"two of three left")
	var cleared := _snapshot(1)
	cleared["slots"]["consumable"] = null
	_deliver(cleared)
	_check(BridgeClient.slotted_action("consumable").is_empty(),
			"the slot is clear")
	_deliver(_snapshot(1))            # the same supply, back on Q
	_check(BridgeClient.charges_left(COMPONENT) == CHARGES - 1,
			"and it comes back with what it had, not a fresh supply")
	var runtime: EchoRuntime = _player.runtimes["consumable"]
	runtime.set_equipped(_component())
	runtime.reset_cooldown()
	_player.press_slot("consumable")
	await get_tree().physics_frame
	_check(_effects == 1, "the resumed supply fires with no refill")


## THE MENU SAYS WHAT IT IS AND WHAT BRINGS IT BACK. An exhausted
## consumable that reads as gone is the control that looks broken; one
## that reads as live is the control that does nothing.
func _the_menu_shows_an_exhausted_supply_and_what_refills_it() -> void:
	print("  -- the menu: 0 / 3, still equipped, and why")
	await _reset(CHARGES)
	var inventory := InventoryLayer.new()
	add_child(inventory)
	inventory.rebuild()
	await get_tree().process_frame

	var texts := _label_texts(inventory)
	var slot_row := ""
	for text: String in texts:
		if text.contains("Cinder Charge") and text.contains("/"):
			slot_row = text
			break
	_check(slot_row.contains("0 / %d" % CHARGES),
			"the slot row reads '0 / %d', not a blank" % CHARGES)

	var spent_button: Button = null
	for button: Button in _buttons(inventory):
		if button.text == "SPENT":
			spent_button = button
			break
	_check(spent_button != null, "the equip button says SPENT")
	if spent_button != null:
		_check(spent_button.disabled,
				"and is disabled — it cannot fire, so it does not offer to")
		_check(spent_button.tooltip_text.contains("Zone"),
				"and says a Zone refills it: '%s'" % spent_button.tooltip_text)
	inventory.queue_free()


func _label_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		out.append_array(_label_texts(child))
	return out


func _buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		out.append(node as Button)
	for child: Node in node.get_children():
		out.append_array(_buttons(child))
	return out


## TYPING IS NOT PLAYING, on the real input path.
##
## `Main._update_modal` puts a NAMED hold on the player while the archive
## is open, and this is what that hold buys: a genuine
## `fire_consumable` press, read by `_physics_process` from the real
## InputMap, that does nothing at all. A `w` typed into the search box is
## a letter, and a `q` is not a grenade.
##
## Synthetic input rather than `press_slot`, because `press_slot` is
## downstream of the gate this case is about. And the unheld press is
## asserted FIRST: "nothing happened" is only evidence when something
## would otherwise have happened.
func _a_held_player_does_not_fire_while_the_archive_is_open() -> void:
	print("  -- a held player does not fire, through the real input path")
	await _reset()
	_player.input_frozen = false          # `_holds` empty: ordinary play

	await _press_the_key()
	_check(_effects == 1,
			"an unheld player fires on a real `fire_consumable` press")

	# ...and now the archive is open.
	_player.hold("modal")
	await _press_the_key()
	_check(_effects == 1, "the same press, held, does nothing")
	_check(_refusals == 0,
			"and it is not even refused — the press never reached the slot")

	_player.release("modal")
	await _press_the_key()
	_check(_effects == 2, "closing the archive gives the key back")
	_player.input_frozen = true


func _press_the_key() -> void:
	Input.action_press("fire_consumable")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("fire_consumable")
	await get_tree().physics_frame
