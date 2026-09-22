extends Node
## THE CONSUMABLE SPEND, END TO END, OVER A REAL SOCKET.
##
##     make godot-consumable-live
##
## Everything else about consumables is checked in two halves that never
## meet: `bridge/tests/test_consumable_slot.py` drives the transition
## with Python arithmetic, and `godot/tests/consumable_driver.gd` drives
## the client with `assume_sent` and a hand-written snapshot. Both can
## pass while the pair is broken, because neither has ever sent a byte.
##
## **THE QUESTION THIS ONE ASKS IS THE ONLY ONE THAT MATTERS.** Not "did
## the client deduct one", not "was an intent logged" -- HOW MANY EFFECTS
## RAN, AND HOW MANY CHARGES DID THE SAVE AUTHORISE. The first number is
## counted from `EchoRuntime.action_used`, which fires when something is
## actually put in the world; the second is read out of the snapshot's
## `consumable_uses`, which is the engine's own record of what it
## accepted. A local deduction is not evidence about either, and neither
## is a message that was sent.
##
## The campaign owns a consumable because `tools/give_consumable.py` put
## one in the save before the bridge started -- one more interpretation,
## through the real models. The fallback provider does not emit one yet
## (the slot is staged), and this suite is about the expenditure rather
## than about generation.
##
## **THE DISCONNECT IS REAL.** `_socket.close()` on the live client, not
## a flag: the socket goes down, sends fail for real, the client's own
## backoff brings it back up, and `resend_unconfirmed` runs from
## `_process` because the state machine reached STATE_OPEN. Nothing here
## simulates the half it is testing.
##
## **WHAT THIS SUITE DOES NOT PROVE, stated rather than implied.** Two
## sabotages were run against it. Removing the generation check from
## `spend_charge` fails it twice, and the second failure is the exact
## harm that check exists to prevent -- "3 authorised, 2 run", a charge
## taken off the save for an effect that never happened. But restoring
## `_in_flight.clear()` on the disconnect path -- the defect the owner
## named -- passes here, because this sequence can only reach the
## transition with nothing held: it closes the socket FIRST and presses
## after, so the clear fires before there is anything to lose. The
## window that defect lives in is launch, then lose the connection, and
## a real socket to a local process does not drop a message that was
## accepted for sending. `consumable_driver.gd` constructs that state
## directly and fails three checks under the same sabotage, which is
## where that property is proven. This suite proves the other half: that
## the two ends agree over a wire.

const CID := "act_live_charge"

var failures := 0
var notes: Array[String] = []

## HOW MANY TIMES SOMETHING WENT INTO THE WORLD. Counted from the
## runtime's own signal, so a press that returned early on a cooldown or
## an empty supply is not counted -- those are not effects.
var _effects := 0

## Every refusal the engine sent, by the domain key it named.
var _refusals: Array[String] = []

## HOW OFTEN THE EMPTY SUPPLY SAID SO. On the node rather than in the
## closure: a GDScript lambda captures a local by VALUE, so a counter
## incremented inside one and read outside it reads zero forever -- the
## shape that makes a check pass while measuring nothing.
var _exhausted_said := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)


func _note(message: String) -> void:
	notes.append(message)
	print("  NOTE: " + message)


func _ready() -> void:
	BridgeClient.error_received.connect(_on_error)
	_run()


func _on_error(err: Dictionary) -> void:
	_refusals.append(str(err.get("about", "")))


func _finish(code: int) -> void:
	if code == 0 and failures == 0:
		print("GODOT CONSUMABLE LIVE TESTS OK (%d notes)" % notes.size())
	else:
		print("GODOT CONSUMABLE LIVE TESTS: %d failure(s)" % maxi(
				failures, 1))
	get_tree().quit(0 if code == 0 and failures == 0 else 1)


func _await(what: String, predicate: Callable, timeout := 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	_check(false, "timed out waiting for " + what)
	return false


## Wait for something, reporting nothing if it never happens.
func _settles(predicate: Callable, timeout := 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


## Feed every runtime the Action the fold says is in its slot -- the
## same body as `Main._equip_all_slots`, because it is the same job.
func _equip(player: Player) -> void:
	for slot: String in Constants.SLOT_NAMES:
		var runtime: EchoRuntime = player.runtimes.get(slot)
		if runtime != null:
			runtime.set_equipped(BridgeClient.slotted_action(slot))


## WHAT THE SAVE HAS AUTHORISED, from the engine's own record.
func _authorised() -> int:
	for raw: Variant in BridgeClient.snapshot.get("consumable_uses", []):
		var use: Dictionary = raw
		if str(use.get("component_id", "")) == CID:
			return int(use.get("spent", 0))
	return 0


func _generation() -> int:
	return int(BridgeClient.snapshot.get("consumable_generation", 0))


## One press through the real gate, waiting out the Action's cooldown
## first so the press is refused by the supply or by nothing at all.
func _press(player: Player) -> void:
	await _await("the cooldown to clear",
			func() -> bool:
				return (player.runtimes["consumable"].cooldown_remaining
						<= 0.0),
			6.0)
	player.press_slot("consumable")
	await get_tree().process_frame


func _run() -> void:
	if not await _await("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		_finish(1)
		return
	BridgeClient.send_intent({"type": "start_mock_campaign"})

	# PHASE ONE: make the campaign and stop. `tools/give_consumable.py`
	# needs a save to put the consumable INTO, and a save exists only
	# once the real path has made one -- with the scale, the track order
	# and the identity the engine chose. Building one by hand here would
	# be a second, drifting copy of `on_ap_ready`.
	if OS.get_cmdline_user_args().has("--seed-only"):
		if not await _await("the campaign to exist",
				func() -> bool:
					return BridgeClient.hub_mode() != "NO_CAMPAIGN", 30.0):
			_finish(1)
			return
		print("campaign created; stopping for the seeding step")
		_finish(0)
		return

	if not await _await("the seeded consumable",
			func() -> bool:
				return BridgeClient.charges_total(CID) > 0, 30.0):
		_finish(1)
		return

	# READ, NOT ASSUMED. The seeding step decides how many, and a suite
	# that hard-coded the number would fail on a supply change rather
	# than on a defect. What matters is that there is more than one:
	# a single charge cannot tell "spent once" from "spent at all".
	var total := BridgeClient.charges_total(CID)
	_check(total >= 3, "the campaign owns a multi-charge consumable (%d)"
			% total)
	_check(str(BridgeClient.slotted_action("consumable").get(
			"component_id", "")) == CID,
			"and it is equipped in the consumable slot")

	var hub := HubController.new()
	get_tree().root.add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Player = hub.player
	if player == null:
		_check(false, "the hub spawns a player to press the button")
		_finish(1)
		return
	# **THE LOADOUT PUSH IS THE HARNESS'S JOB HERE, and it is the real
	# one.** `Main._equip_all_slots` feeds each runtime the Action the
	# fold says is in its slot, and it does that for the ZONE's player;
	# nothing feeds a Hub player, so an unequipped runtime returns from
	# `activate()` before anything happens and every press resolves into
	# nothing. The same call, from the same snapshot, on every snapshot
	# -- which is what `railway_scenario` does for the same reason.
	_equip(player)
	BridgeClient.snapshot_received.connect(
			func(_s: Dictionary) -> void: _equip(player))
	player.runtimes["consumable"].action_used.connect(
			func() -> void: _effects += 1)
	player.exhausted.connect(
			func(_name: String) -> void: _exhausted_said += 1)

	await _an_accepted_use_is_counted_by_the_save(player)
	await _the_deduction_holds_while_the_answer_is_in_flight(player)
	await _a_stale_supply_is_refused_and_names_what_it_refused()
	await _presses_made_offline_are_resent_and_counted_once(player)
	await _the_last_charge_is_the_last_effect(player)

	hub.queue_free()
	await get_tree().process_frame
	_finish(0)


## ONE PRESS, ONE EFFECT, ONE CHARGE OFF THE SAVE.
func _an_accepted_use_is_counted_by_the_save(player: Player) -> void:
	print("  -- an accepted use, all the way to the save")
	var before := _effects
	await _press(player)
	_check(_effects == before + 1, "the press put something in the world")
	if not await _await("the engine to count it",
			func() -> bool: return _authorised() >= 1, 10.0):
		return
	_check(_authorised() == 1,
			"and the save authorised exactly one charge (%d)"
			% _authorised())
	var held := BridgeClient.charges_total(CID)
	_check(BridgeClient.charges_left(CID) == held - 1,
			"one fewer left, from the engine's count and not a local "
			+ "tally (%d of %d)" % [BridgeClient.charges_left(CID), held])


## THE ANSWER TAKES A ROUND TRIP, and the count may not wobble while it
## does. The deduction is visible immediately -- otherwise a second press
## inside the round trip would spend the same charge -- and it must not
## be applied a second time when the snapshot confirming it arrives.
func _the_deduction_holds_while_the_answer_is_in_flight(
		player: Player) -> void:
	print("  -- the deduction while the answer is in flight")
	var authorised := _authorised()
	var left := BridgeClient.charges_left(CID)
	await _press(player)
	_check(BridgeClient.charges_left(CID) == left - 1,
			"the charge is gone the instant the effect launches (%d)"
			% BridgeClient.charges_left(CID))
	if not await _await("the engine to count it",
			func() -> bool: return _authorised() > authorised, 10.0):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_check(BridgeClient.charges_left(CID) == left - 1,
			"and it is not deducted twice when the snapshot lands (%d)"
			% BridgeClient.charges_left(CID))
	_check(_authorised() == _effects,
			"effects run (%d) still equal charges authorised (%d)"
			% [_effects, _authorised()])


## A USE THAT NAMES A SUPPLY THIS SAVE DOES NOT HAVE is refused, and the
## refusal says which one -- which is the whole reason
## `BridgeError.about` was added. Sent directly rather than through a
## press: the client will not mint a wrong generation on purpose, and
## the engine's refusal is what is under test.
##
## **THE DIRECTION IS THE OTHER ONE, and that is a real limit.** A
## genuinely STALE use names a generation OLDER than the current supply,
## and reaching one needs a refill -- which needs a Zone entry this
## sequence does not perform. `generation: int = Field(ge=0)` also means
## generation -1 never reaches `spend_charge` at all: it is refused by
## message validation, which carries no `about` and would prove nothing
## about the correlation. So this sends a generation the save has not
## minted YET, which hits the identical identity check in
## `spend_charge`, and the stale-after-refill direction stays where it
## is already covered -- `TestStaleUsesAcrossARefill` in
## `bridge/tests/test_consumable_slot.py`.
func _a_stale_supply_is_refused_and_names_what_it_refused() -> void:
	print("  -- a supply this save does not have, refused by identity")
	var stale := _generation() + 1
	var authorised := _authorised()
	_refusals.clear()
	BridgeClient.send_intent({"type": "use_consumable",
			"component_id": CID, "use_index": _authorised() + 1,
			"generation": stale})
	if not await _await("the refusal",
			func() -> bool: return not _refusals.is_empty(), 10.0):
		return
	_check(_refusals[0] == BridgeClient.use_key(
			CID, stale, authorised + 1),
			"the refusal names the exact spend it refused ('%s')"
			% _refusals[0])
	_check(_authorised() == authorised,
			"and nothing was spent (%d)" % _authorised())


## PRESSES MADE WITH THE SOCKET DOWN. The effects happen -- a grenade
## does not wait for the network -- and the reports are retransmitted
## when the client reconnects. The measure is the one that matters:
## after the resend, the save has authorised exactly as many charges as
## there were effects, no more and no fewer.
func _presses_made_offline_are_resent_and_counted_once(
		player: Player) -> void:
	print("  -- offline presses, resent on reconnect")
	var authorised := _authorised()
	var before := _effects
	var left := BridgeClient.charges_left(CID)
	if left <= 0:
		_note("no charges left to spend offline; case skipped")
		return

	BridgeClient._socket.close()
	if not await _await("the socket to go down",
			func() -> bool: return not BridgeClient.online, 10.0):
		return
	await _press(player)
	var offline_effects := _effects - before
	_check(offline_effects == 1,
			"the press still fired with the bridge down (%d effects)"
			% offline_effects)
	_check(_authorised() == authorised,
			"and the engine has not counted it, because it never "
			+ "arrived (%d)" % _authorised())
	# PRESSED AGAIN WHILE STILL DOWN. The supply still has one, so this
	# is a second expenditure and not a duplicate of the first.
	await _press(player)
	_note("offline presses fired: %d" % (_effects - before))

	if not await _await("the client to reconnect",
			func() -> bool: return BridgeClient.online, 25.0):
		return
	# Waited for QUIETLY. A timeout here is not a finding of its own --
	# the assertion below is the finding, and reporting the wait as a
	# second failure would make one defect look like two.
	var expected := _effects
	await _settles(func() -> bool: return _authorised() >= expected, 15.0)
	_check(_authorised() == _effects,
			"after the reconnect the save has authorised exactly the "
			+ "effects that ran (%d authorised, %d run)"
			% [_authorised(), _effects])


## THE SUPPLY RUNS OUT, and running out is a refusal BEFORE anything
## happens -- no effect, no cooldown, and the item still equipped.
func _the_last_charge_is_the_last_effect(player: Player) -> void:
	print("  -- the supply runs out")
	var guard := 0
	while BridgeClient.charges_left(CID) > 0 and guard < 6:
		guard += 1
		await _press(player)
		await _await("the engine to catch up",
				func() -> bool: return _authorised() == _effects, 10.0)
	_check(BridgeClient.charges_left(CID) == 0,
			"the supply is empty (%d left)"
			% BridgeClient.charges_left(CID))
	_check(_effects <= BridgeClient.charges_total(CID),
			"no more effects ran than the supply ever held (%d of %d)"
			% [_effects, BridgeClient.charges_total(CID)])
	_check(_authorised() == _effects,
			"and the save authorised every one of them and no others "
			+ "(%d authorised, %d run)" % [_authorised(), _effects])

	var before := _effects
	await _press(player)
	_check(_effects == before,
			"a press at zero puts nothing in the world")
	_check(str(BridgeClient.slotted_action("consumable").get(
			"component_id", "")) == CID,
			"the empty supply is still equipped, at 0 of %d"
			% BridgeClient.charges_total(CID))
	_check(_exhausted_said > 0,
			"and it said so: the exhausted feedback fired %d time(s)"
			% _exhausted_said)
