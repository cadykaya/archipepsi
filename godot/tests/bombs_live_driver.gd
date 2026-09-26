class_name BombsLiveDriver
extends "res://tests/candidate_live_driver.gd"
## H-BOMBS, SLICE 2 -- THE BOMB BAG THE CAMPAIGN GIVES, CLAIMED, CARRIED,
## THROWN AND REFILLED THROUGH A REAL BRIDGE (`--bombs-live=<phase>`).
##
##     make godot-bombs-live
##
## V-15: "Natural candidate claim, not injected component | Item
## discoverable, compatible equip and real authorized use;
## absent/owned/empty cases distinguished." `godot-bombs` checks the
## client on the engine's own snapshots of that claim; this is the claim
## itself, over a socket, by the client, in the Zone the campaign puts it
## in. **Nothing is given**: no `give_consumable.py`, no fixture, no
## component typed in. The bridge is the candidate launcher's -- mock
## AP, the fallback provider, DEFAULT scale, `--candidate=all` -- so the
## campaign is the owner's, and its first consumable is a Bomb Bag.
##
## **WHICH ZONE HOLDS IT IS FOUND, NOT ASSUMED.** Walked with a layout
## that always succeeds, the campaign reaches its first Bomb Bag in Zone
## 6. Played by this client it long did not: the engine could not lay out
## its fourth Zone, a player's only way on was to discard it, and that
## returned its Checks to the pool, so with HB-F4b the first Bomb Bag was
## zone_007's. HB-F4a lays zone_004 out, and it is zone_006's again with
## no Zone discarded on the way. This finds it wherever it is rather than
## being told the Zone.
##
## Three runs against one disposable save, each a new client beside a new
## bridge; only the save crosses:
##
##   reach   a new campaign. Zone after Zone: designed at the portal,
##           entered, built and accepted by the bridge, each Check
##           claimed, out through the exit. A Zone the bridge gives up on
##           (ZONE_FAILED) is discarded at the Hub's console, as its
##           headline tells a player to. No consumable is owned at any
##           point; the key reads "—". It stops at the first Zone whose
##           Checks hold a Bomb Bag: built, accepted, and left unclaimed.
##   claim   that Zone, entered. The pedestal of its first Bomb Bag Check
##           is walked to and claimed with [E]. The Bomb Bag arrives: its
##           card, its row ("owned, not carried"), the word pointing at
##           Q. Q pressed with nothing on it says so. EQUIPMENT opened
##           with its key; the Bomb Bag's tile, EQUIP ON Q, the bridge's
##           answer. Q thrown until empty, each use authorised first and
##           counted by the save on disk, the key counting down to EMPTY;
##           one more press says so and asks for nothing.
##   refill  both processes new: the bag still on Q, still empty. Its
##           Zone resumed and finished, out through the exit, the next
##           Zone that builds entered: the supply refilled, and one more
##           bomb thrown from it.
##
## **HARNESS STEPS, declared, and none of them touches the item:**
##   - The Zones before the Bomb Bag's, and the rest of its Zone in
##     `refill`: each Check is claimed by the intent its pedestal sends,
##     without the walk to it -- the walk is not what this proves, and
##     five Zones of it would be the whole run.
##   - WHERE THE BOMB BAGS ARE is HARNESS KNOWLEDGE (`--bombs-bag-ids`,
##     from the mock multiworld's own placement). The client is not told
##     what an unclaimed Check holds, so the suite is told, the way a test
##     knows its answer; it checks the client is NOT told before the claim
##     and IS told after it. Knowing is what lets the walk stop at the
##     Bomb Bag's Zone instead of claiming it by intent.
##   - Leaving a Zone through its exit calls the exit portal's own handler
##     (`Main._on_exit_zone`) without the walk to the portal.
##   - In `claim`, the player is PLACED at the arrival of the room the Bomb
##     Bag's pedestal stands in, as `candidate-live` places it at a minor.
##     A platform room's course is not jumped: the player is stood on its
##     goal landing and the room's own goal area sees them arrive.
##     From there it is the player's own input: the room's fight with the
##     Static Pulse, the walk, [E], Tab, the equipment wall's buttons, Q.
##   - A card holds the controls, so Q waits for the cards to be read, as
##     a player would, and the log says each time it had to (HB-O1).

const BOMBS_FLAG := "--bombs-live="
const BOMBS_SAVE_FLAG := "--bombs-save-dir="
const BAG_ITEM := "Bomb Bag"
## HARNESS KNOWLEDGE: every Check the mock multiworld filled with a Bomb
## Bag, from its own placement (`fixtures/mock_placements.py`, passed by
## the Makefile). The client is not told what an unclaimed Check holds,
## so a player finds a Bomb Bag by claiming, and a suite that must walk to
## one has to be told where it is, the way a test knows its answer. The
## suite checks that the client is NOT told, and says when it leans on
## this.
const BAG_IDS_FLAG := "--bombs-bag-ids="
## How many Zones to go through looking for one before giving up.
const ZONE_LIMIT := 12

var _thrown := 0
## The Zone the last `_into_a_zone(true)` discarded, or "".
var _discarded := ""
## EVERY TOAST THE HUD RAISED, in order, as it was raised. Counting the
## ones still on screen races their expiry: a "COULD NOT BE BUILT" from
## the attempt before can time out in the same frame a new one arrives,
## and the count never moves.
var _toast_log: Array[String] = []
## What each attempt of the last `_into_a_zone` was handed, as a digest
## of the Zone content the bridge sent: so "composed again" is measured.
var _compositions: Array[String] = []


static func bombs_phase() -> String:
	return _arg(BOMBS_FLAG)


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(err))
	# The label's words are set before it is added, so this sees them.
	main.hud._toast_box.child_entered_tree.connect(func(node: Node) -> void:
		if node is Label:
			_toast_log.append((node as Label).text))
	# The player's own files are not a suite's to write.
	EquipmentSeen._reset_for_test()
	Favourites._reset_for_test()
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match bombs_phase():
			"reach":
				await _reach()
			"claim":
				await _claim()
			"refill":
				await _refill()
			_:
				_check(false, "no --bombs-live phase was named")
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"move_back", "jump", "fire_pulse", "interact",
			str(Player.SLOT_ACTIONS["consumable"])]:
		Input.action_release(action)
	var phase := bombs_phase().to_upper()
	if failures == 0:
		print("GODOT BOMBS LIVE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT BOMBS LIVE %s: %d failures in %d checks"
				% [phase, failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------------------
# What the player sees and what the save holds
# ---------------------------------------------------------------------------

## The consumable key's row as it is on screen.
func _key_row() -> String:
	var keycap := SlotKeycaps.of("consumable")
	for row: String in main.hud._echo_label.text.split("\n"):
		if row.substr(2).begins_with(keycap):
			return row.strip_edges()
	return ""


func _toasts() -> Array[String]:
	var out: Array[String] = []
	for child: Node in main.hud._toast_box.get_children():
		if child is Label and not child.is_queued_for_deletion():
			out.append((child as Label).text)
	return out


func _heard(words: String) -> int:
	var n := 0
	for text: String in _toasts():
		if text.contains(words):
			n += 1
	return n


## Whether a toast raised since `mark` (an index into `_toast_log`) said
## the Zone could not be stood in.
func _told_it_failed(mark: int) -> bool:
	for text: String in _toast_log.slice(mark):
		if text.contains("COULD NOT BE BUILT") \
				or text.contains("LAYOUT REFUSED"):
			return true
	return false


func _bag() -> Dictionary:
	for component: Dictionary in BridgeClient.owned_consumables():
		return component
	return {}


func _consumable_names() -> Array:
	return BridgeClient.owned_consumables().map(
			func(c: Dictionary) -> String: return str(c.get("display_name", "")))


## The campaign save as the bridge last wrote it, read off the disk.
func _saved() -> Dictionary:
	var dir := _arg(BOMBS_SAVE_FLAG)
	for name: String in DirAccess.get_files_at(dir):
		if not name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(dir.path_join(name)))
		if typeof(parsed) == TYPE_DICTIONARY \
				and (parsed as Dictionary).has("consumable_uses"):
			return parsed
	return {}


func _saved_spent(cid: String) -> int:
	for raw: Variant in _saved().get("consumable_uses", []):
		var use: Dictionary = raw
		if str(use.get("component_id", "")) == cid:
			return int(use.get("spent", 0))
	return 0


func _saved_slot() -> String:
	var held: Variant = (_saved().get("slots", {}) as Dictionary).get(
			"consumable")
	return "" if held == null else str(held)


func _sent_since(count: int, kind: String) -> Array:
	var out: Array = []
	for raw: Variant in BridgeClient.sent_intents.slice(count):
		if str((raw as Dictionary).get("type", "")) == kind:
			out.append(raw)
	return out


## A key the player presses, as an event: Tab is read by `Main`'s input
## handler, not polled.
func _tap(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Zone housekeeping (declared harness steps)
# ---------------------------------------------------------------------------

## HARNESS STEP: every unclaimed Check of the active Zone claimed by the
## intent its pedestal sends.
func _claim_every_check(zid: String) -> bool:
	var ids: Array = BridgeClient.active_zone().get(
			"allocated_location_ids", [])
	var sent := 0
	for raw: Variant in ids:
		if not BridgeClient.is_checked(int(raw)):
			BridgeClient.send_intent({"type": "claim_check",
					"zone_id": zid, "location_id": int(raw)})
			sent += 1
	var all_checked := func() -> bool:
		for raw: Variant in ids:
			if not BridgeClient.is_checked(int(raw)):
				return false
		return true
	var ok := await _await_live("every Check of %s confirmed" % zid,
			all_checked, 90.0)
	_note("HARNESS STEP: %d of %s's %d Checks claimed by intent, not "
			% [sent, zid, ids.size()] + "walked to")
	return ok


## HARNESS STEP: out through the exit portal's own handler.
func _out_through_the_exit(zid: String) -> bool:
	main._on_exit_zone()
	return await _await_live("the Hub after %s" % zid,
			func() -> bool:
				return main.hub != null and main.hub.player != null \
						and BridgeClient.active_zone().is_empty(), 30.0)


## THROUGH THE PORTAL UNTIL A ZONE STANDS, as a player goes.
##
## A composition the engine cannot lay out is not this suite's to judge:
## `ZoneController.setup` reports it (`build_failed`), `Main` puts the
## player back in the Hub, and the bridge composes the proposal again
## inside its budget (the NO-LAYOUT handoff). A player walks back through
## the portal into that, and so does this -- each failure NOTED with the
## engine's reason, and a Zone the bridge gives up on (ZONE_FAILED) is a
## failure here.
func _into_a_zone(may_discard := false) -> ZoneController:
	_discarded = ""
	_compositions.clear()
	var failures_seen := 0
	for attempt in range(1, 6):
		var offered := func() -> bool:
			var standing := main.hub as HubController
			return standing != null and standing.portal() != null \
					and standing.portal().interact_prompt() != "" \
					and BridgeClient.hub_mode() in ["ZONE_READY",
						"ZONE_ACTIVE", "ZONE_DORMANT"]
		if not await _await_live("the Hub's portal (%s)"
				% BridgeClient.hub_mode(), offered, 90.0):
			return null
		_zone_data = BridgeClient.active_zone().get("zone", {})
		var zid := str(BridgeClient.active_zone().get("zone_id", ""))
		_compositions.append(JSON.stringify(_zone_data).sha256_text()
				.left(12))
		var mark := _toast_log.size()
		(main.hub as HubController).portal().interact(main)
		var settled := func() -> bool:
			if _told_it_failed(mark):
				return true
			return main.zone != null and main.zone.player != null \
					and (main.zone as ZoneController).layout_verdict \
						== "ACCEPTED"
		if not await _await_live("%s built and accepted, or refused" % zid,
				settled, 120.0):
			return null
		if main.zone != null and (main.zone as ZoneController) \
				.layout_verdict == "ACCEPTED":
			if (_zone_data.get("chambers", []) as Array).is_empty():
				_zone_data = BridgeClient.active_zone().get("zone", {})
			if failures_seen > 0:
				_note("%s stood on attempt %d, after %d composition(s) the "
						% [zid, attempt, failures_seen] + "engine could not "
						+ "lay out were composed again by the bridge")
			return main.zone as ZoneController
		failures_seen += 1
		_note("%s could not be built on attempt %d; back in the Hub, the "
				% [zid, attempt] + "bridge composes it again (%s)"
				% BridgeClient.hub_mode())
		await _settle(30)
		if BridgeClient.hub_mode() == "ZONE_FAILED":
			if may_discard and await _discard_failed(zid):
				return null
			_check(false, "%s failed past the bridge's budget" % zid)
			return null
	_check(false, "no Zone stood after 5 attempts")
	return null


## A ZONE THE BRIDGE GAVE UP ON, DISCARDED AT THE HUB'S CONSOLE, as its
## headline tells a player to ("Discard it to return its Checks to the
## pool"). HB-F4: it is NOTED with what failed, because it is the
## campaign the owner plays and not this suite's doing.
func _discard_failed(zid: String) -> bool:
	var console: Node3D = (main.hub as HubController).abandon_console()
	var prompt := str(console.call("interact_prompt"))
	var checks_back := (BridgeClient.hub().get("discard_zone_id", "") \
			as String) == zid
	console.call("interact", main.hub.player)        # arm
	await _settle(4)
	console.call("interact", main.hub.player)        # confirm
	var gone := await _await_live("%s discarded" % zid, func() -> bool:
		return BridgeClient.hub_mode() == "ZONE_AVAILABLE", 30.0)
	_check(gone and checks_back and prompt.contains("DISCARD"),
			"%s, failed past the bridge's budget, is discarded at the " % zid
			+ "Hub's console ('%s')" % prompt)
	var distinct := {}
	for digest: String in _compositions:
		distinct[digest] = true
	_note("HB-F4: %s could not be laid out by the engine on any of its " % zid
			+ "%d composition(s), %d distinct (%s); DISCARDED, its Checks " \
			% [_compositions.size(), distinct.size(),
				", ".join(_compositions)]
			+ "back to the pool")
	_discarded = zid
	return gone


## The active Zone's Checks that hold a Bomb Bag, lowest first, off the
## scout table the bridge sends.
func _bag_checks() -> Array[int]:
	var known := {}
	for part: String in _arg(BAG_IDS_FLAG).split(",", false):
		known[int(part)] = true
	var out: Array[int] = []
	for raw: Variant in BridgeClient.active_zone().get(
			"allocated_location_ids", []):
		if known.has(int(raw)):
			out.append(int(raw))
	out.sort()
	return out


## The item name the client holds for a Check, or "" when it holds none.
## An unrevealed Check arrives with `item_name: null`, and `str(null)` is
## "<null>", which is not "".
func _item_of(location_id: int) -> String:
	var name: Variant = BridgeClient.scout_for(location_id).get("item_name")
	return "" if name == null else str(name)


## What the client is told about a Check: whether it is revealed, and
## the item's name if it has one.
func _told(location_id: int) -> String:
	return "revealed=%s item='%s'" % [str(BridgeClient.scout_for(
			location_id).get("revealed", false)), _item_of(location_id)]


## The controller's record of one room: its objective and whether it is
## satisfied.
func _record_of(controller: ZoneController, room: String) -> Dictionary:
	for raw: Variant in controller._chambers:
		var record: Dictionary = raw
		if str((record["chamber"] as Dictionary).get("id", "")) == room:
			return record
	return {}


## The goal area a `platform_to_goal` room built for `record`: the Area3D
## whose `body_entered` the controller bound to that record.
func _goal_area_of(controller: ZoneController, record: Dictionary) -> Area3D:
	for child: Node in controller.get_children():
		if not child is Area3D:
			continue
		for link: Dictionary in (child as Area3D).body_entered \
				.get_connections():
			var bound: Array = (link["callable"] as Callable) \
					.get_bound_arguments()
			if not bound.is_empty() and is_same(bound[0], record):
				return child as Area3D
	return null


## A PLATFORM ROOM'S GOAL, REACHED BY STANDING ON IT. The course itself
## is what the traverse and passing-platform suites prove; this suite's
## subject is the Bomb Bag on the far ledge. So the player is stood on
## the goal landing -- noted as a harness step -- and the room's own
## Area3D sees them arrive, as it would at the end of the jumps. Nothing
## calls the controller's handler.
func _stand_at_goal(controller: ZoneController, record: Dictionary,
		room: String) -> bool:
	var area := _goal_area_of(controller, record)
	_check(area != null, "%s built a goal area for its platform course"
			% room)
	if area == null:
		return false
	var player := controller.player
	player.velocity = Vector3.ZERO
	player.global_position = area.global_position
	_note("HARNESS STEP: stood on %s's goal landing at %s rather than " \
			% [room, str(area.global_position)] + "jumping its course "
			+ "(the traverse suites' subject, not this one's)")
	var reached := await _await_live("%s's goal" % room,
			func() -> bool: return bool(record["satisfied"]), 5.0)
	_check(reached, "the room's own goal area saw the player arrive, and "
			+ "%s's objective is met" % room)
	return reached


## The pedestal of one Check, as the Zone built it.
func _pedestal(controller: ZoneController, location_id: int) -> RewardObject:
	for node: Node in controller.find_children("*", "", true, false):
		var reward := node as RewardObject
		if reward != null and reward.location_id == location_id:
			return reward
	return null


## The room a node stands in, by the controller's own bounds.
func _room_of(controller: ZoneController, node: Node3D) -> String:
	for rid: Variant in controller.room_bounds.keys():
		var box: AABB = controller.room_bounds[rid]
		if box.grow(0.5).has_point(node.global_position):
			return str(rid)
	return ""


## Q, pressed by the player, and the bomb it throws once the bridge has
## counted the charge.
func _throw_one(player: Player) -> bool:
	# A CARD HOLDS THE CONTROLS, and claims queue one card each. They
	# pause with the world while a wall is open, so the claim's card is
	# still up when EQUIPMENT closes; a Q pressed under it does nothing and
	# says nothing. A player waits for the card; so does this, and says
	# when it had to.
	if main.reveal.visible:
		_note("OBSERVED: a card was up when Q was due, holding the "
				+ "controls (a press now would do nothing and say nothing); "
				+ "waited out, as a player would")
		await _await_live("the cards read",
				func() -> bool: return not main.reveal.visible, 120.0)
	var runtime: EchoRuntime = player.runtimes["consumable"]
	await _await_live("the Bomb Bag off cooldown",
			func() -> bool: return runtime.cooldown_remaining <= 0.0, 10.0)
	var before := _thrown
	var sent := BridgeClient.sent_intents.size()
	var at_press := _why_not(player)
	var mark := _toast_log.size()
	await _press(str(Player.SLOT_ACTIONS["consumable"]))
	var thrown := await _await_live("the bomb thrown",
			func() -> bool: return _thrown > before, 10.0)
	var reported := await _await_live("its use reported",
			func() -> bool:
				return not _sent_since(sent, "use_consumable").is_empty(),
			10.0)
	_check(_sent_since(sent, "authorize_consumable").size() == 1
			and thrown and reported and _thrown == before + 1,
			"Q: one authorisation asked, one Bomb Bag thrown after the "
			+ "answer, one use reported (sent %s; at the press: %s; " \
			% [str(BridgeClient.sent_intents.slice(sent).map(
				func(i: Dictionary) -> String: return str(i.get("type", "")))),
				at_press] + "said after it: %s)" % str(_toast_log.slice(mark)))
	return thrown


## Everything that can stand between a press of Q and a request, said in
## one line so a failure names its cause.
func _why_not(player: Player) -> String:
	return "held by %s, card %s, menu %s, paused %s, slot '%s', state %s, " \
			% [str(player._holds.keys()), str(main.reveal.visible),
				str(main.menu_shell.is_open()), str(get_tree().paused),
				str(BridgeClient.slotted_action("consumable").get(
					"component_id", "")),
				str(EquipmentQuery.live_consumable_state().get("state", "?"))] \
			+ "cooldown %.2f, runtime is the player's own: %s" \
			% [(player.runtimes["consumable"] as EchoRuntime) \
				.cooldown_remaining, str(is_same(player,
					(main.zone as ZoneController).player))]


# ---------------------------------------------------------------------------
# reach
# ---------------------------------------------------------------------------

func _reach() -> void:
	if not await _campaign():
		return
	_check(_arg(BAG_IDS_FLAG) != "", "the harness was told where the "
			+ "mock multiworld put its Bomb Bags (%s)" % BAG_IDS_FLAG)
	_check(BridgeClient.owned_consumables().is_empty(),
			"a new campaign owns no consumable")
	var discards := 0
	for _i in ZONE_LIMIT:
		if not await _request_next_zone():
			return
		var controller := await _into_a_zone(true)
		if controller == null:
			if _discarded == "":
				return
			discards += 1
			continue
		var zid := str(_zone_data.get("zone_id", ""))
		var bags := _bag_checks()
		if not bags.is_empty():
			_note("HARNESS KNOWLEDGE: the mock multiworld's own placement "
					+ "puts a Bomb Bag at Check(s) %s of %s; a player " \
					% [str(bags), zid] + "learns it only by claiming them")
			var hidden := bags.all(func(loc: int) -> bool:
				return not bool(BridgeClient.scout_for(loc).get(
						"revealed", true)) and _item_of(loc) == "")
			_check(hidden, "and the client is not told: %s"
					% str(bags.map(func(loc: int) -> String:
						return "%d %s" % [loc, _told(loc)])))
			_check(BridgeClient.owned_consumables().is_empty()
					and _key_row().ends_with("—"),
					"%s holds the campaign's first Bomb Bag Check(s) %s, " \
					% [zid, str(bags)] + "built and accepted; nothing "
					+ "consumable owned yet: '%s'" % _key_row())
			await _leave_zone(zid)
			print("reached: %s holds Bomb Bag Check(s) %s; %d Zone(s) " \
					% [zid, str(bags), discards] + "discarded on the way; "
					+ "no consumable owned")
			return
		if not await _claim_every_check(zid):
			return
		_check(BridgeClient.owned_consumables().is_empty()
				and _key_row().ends_with("—"),
				"after %s, still no consumable: the key reads '%s'"
				% [zid, _key_row()])
		if not await _out_through_the_exit(zid):
			return
	_check(false, "no Zone held a Bomb Bag in %d" % ZONE_LIMIT)


# ---------------------------------------------------------------------------
# claim
# ---------------------------------------------------------------------------

func _claim() -> void:
	if not await _campaign():
		return
	_check(BridgeClient.owned_consumables().is_empty()
			and _key_row().ends_with("—"),
			"restarted, still no consumable: '%s'" % _key_row())
	var controller := await _into_a_zone()
	if controller == null:
		return
	var zid := str(_zone_data.get("zone_id", ""))
	var bags := _bag_checks()
	_check(not bags.is_empty(), "back into %s, which holds Bomb Bag " % zid
			+ "Check(s) %s" % str(bags))
	if bags.is_empty():
		return
	var bag: int = bags[0]
	var player := controller.player
	player.runtimes["consumable"].action_used.connect(
			func() -> void: _thrown += 1)
	var reward := _pedestal(controller, bag)
	_check(reward != null, "Check %d stands in the Zone as a pedestal"
			% bag)
	if reward == null:
		return
	var room := _room_of(controller, reward)
	_check(room != "", "the pedestal stands in a room of the Zone (%s)" % room)
	if room == "":
		return
	await _place_at(controller, room)
	if not _living_in(controller, room).is_empty():
		var fight := await _clear_room(controller, room)
		_note("the room's fight, with the Static Pulse: %s" % str(fight))
	var record := _record_of(controller, room)
	if str(record.get("objective", "")) == "platform_to_goal" \
			and not bool(record.get("satisfied", false)):
		if not await _stand_at_goal(controller, record, room):
			return
	var claimable := await _await_live("the pedestal claimable",
			func() -> bool: return reward.state == "available", 20.0)
	_check(claimable, "the pedestal in %s is claimable once its room " % room
			+ "is dealt with (state '%s')" % reward.state)
	if not claimable:
		return
	var sent := BridgeClient.sent_intents.size()
	var seen := await _approach(controller, reward, 1.2)
	_check(seen and reward.interact_prompt().begins_with("[E] CLAIM"),
			"walked up to the pedestal, which offers '%s'"
			% reward.interact_prompt())
	if not seen:
		return
	var claim_mark := _toast_log.size()
	await _press("interact")
	var arrived := await _await_live("the Bomb Bag", func() -> bool:
		return BridgeClient.is_checked(bag) \
				and not _bag().is_empty(), 20.0)
	var claims := _sent_since(sent, "claim_check")
	_check(arrived and claims.size() == 1
			and int((claims[0] as Dictionary).get("location_id", 0)) \
				== bag,
			"[E] at the pedestal sent one claim for %d, and the campaign "
			% bag + "now owns %s" % str(_consumable_names()))
	if not arrived:
		return
	var cid := str(_bag().get("component_id", ""))
	print("claimed: %s (%s) from Check %d"
			% [str(_bag().get("display_name", "")), cid, bag])
	_check(_item_of(bag) == BAG_ITEM,
			"claimed, Check %d now tells the client what it " \
			% bag + "held (%s)" % _told(bag))

	# NOTICED: the card, the row, the word about the key.
	var card_seen := await _await_live("the Bomb Bag's card",
			func() -> bool:
				var card: Dictionary = main.reveal.shown()
				return bool(card.get("visible", false)) \
						and str(card.get("echo", "")).contains("Bomb Bag"),
			30.0)
	# HB-F5: the card comes before the snapshot that holds the Echo, and
	# fills in its summary when that snapshot lands.
	await _await_live("the Bomb Bag's card says what it is",
			func() -> bool:
				return str(main.reveal.shown().get("echo", "")) \
						.contains("CONSUMABLE"), 10.0)
	var card: Dictionary = main.reveal.shown()
	_check(card_seen and str(card.get("echo", "")).contains("CONSUMABLE"),
			"the card shows the Bomb Bag and its slot (%s)"
			% str(card.get("echo", "")).replace("\n", " | "))
	_check(_key_row().contains("Bomb Bag owned, not carried"),
			"the key's row says it is owned and on no key: '%s'" % _key_row())
	# Counted in the log, not on screen: a toast lives 3.5 s, and "once"
	# is about what was said since the claim, not what is still showing.
	var pointed := _toast_log.slice(claim_mark).filter(
			func(text: String) -> bool:
				return text.contains("Bomb Bag is a consumable for"))
	_check(pointed.size() == 1, "one word points at the key (said since "
			+ "the claim: %s)" % str(_toast_log.slice(claim_mark)))

	# Q WITH NOTHING ON IT says so, and asks for nothing.
	sent = BridgeClient.sent_intents.size()
	await _press(str(Player.SLOT_ACTIONS["consumable"]))
	await _settle(4)
	_check(_heard("You own 1 consumable") == 1
			and _sent_since(sent, "authorize_consumable").is_empty(),
			"Q with nothing on it says why and asks the bridge for nothing "
			+ "(heard %s)" % str(_toasts()))

	# EQUIPPED: Tab, the Bomb Bag's tile, EQUIP ON Q.
	await _tap("inventory")
	var face: EquipmentFace = main.equipment
	var opened := await _await_live("the equipment wall",
			func() -> bool:
				return main.menu_shell.is_open() and face.is_open(), 10.0)
	_check(opened, "Tab opens the equipment wall")
	var tile: Variant = face.tiles().get(cid)
	_check(tile is Button, "the Bomb Bag has a tile on it")
	if tile is Button:
		(tile as Button).pressed.emit()
	await _settle(4)
	var put := face.detail_root().find_child("Equip", true, false) as Button
	var key := SlotKeycaps.of("consumable")
	_check(face.selected() == cid and put != null and not put.disabled
			and put.text == "EQUIP ON %s" % key,
			"its card offers EQUIP ON %s (%s)" % [key,
				"none" if put == null else "'%s'" % put.text])
	if put == null:
		return
	sent = BridgeClient.sent_intents.size()
	put.pressed.emit()
	var equipped := await _await_live("the bag on %s" % key,
			func() -> bool:
				return str(BridgeClient.slots().get("consumable", "")) == cid,
			10.0)
	var asked := _sent_since(sent, "slot_action")
	_check(equipped and asked.size() == 1,
			"one request, and the bridge put it on the consumable key (%s)"
			% str(asked))
	# Escape, which closes from any wall -- Tab closes only when the
	# search box does not have the keyboard.
	await _tap("pause")
	_check(await _await_live("the wall closed",
			func() -> bool:
				return not main.menu_shell.is_open() \
						and not get_tree().paused, 10.0),
			"Escape closes the wall, and the world runs again")
	await _settle(10)
	var full := int(_bag().get("charges", 0))
	_check(_key_row().contains("Bomb Bag  %d / %d" % [full, full])
			and _saved_slot() == cid,
			"the key counts it, and the save holds it on the key: '%s'"
			% _key_row())

	# USED: each throw authorised first and counted by the save.
	for use in range(1, full + 1):
		if not await _throw_one(player):
			return
		await _await_live("the save counts use %d" % use,
				func() -> bool: return _saved_spent(cid) == use, 10.0)
		await _settle(4)
		_check(_saved_spent(cid) == use
				and _key_row().contains("%d / %d" % [full - use, full]),
				"use %d counted by the save on disk (%d spent) and on the " \
				% [use, _saved_spent(cid)] + "key: '%s'" % _key_row())
	_check(_key_row().contains("0 / %d  EMPTY" % full),
			"spent, the key reads EMPTY: '%s'" % _key_row())
	await _await_live("the Bomb Bag off cooldown",
			func() -> bool:
				return (player.runtimes["consumable"] as EchoRuntime) \
						.cooldown_remaining <= 0.0, 10.0)
	sent = BridgeClient.sent_intents.size()
	var thrown := _thrown
	await _press(str(Player.SLOT_ACTIONS["consumable"]))
	await _settle(6)
	_check(_heard("Empty. It stays on") == 1 and _thrown == thrown
			and _sent_since(sent, "authorize_consumable").is_empty(),
			"a press on the empty supply says so, throws nothing and asks "
			+ "for nothing (heard %s)" % str(_toasts()))
	await _leave_zone(zid)


# ---------------------------------------------------------------------------
# refill
# ---------------------------------------------------------------------------

func _refill() -> void:
	if not await _campaign():
		return
	var cid := str(_bag().get("component_id", ""))
	var full := int(_bag().get("charges", 0))
	await _settle(20)
	_check(cid != "" and str(BridgeClient.slots().get("consumable", "")) \
			== cid and _key_row().contains("0 / %d  EMPTY" % full),
			"restarted: the Bomb Bag still owned, still on the key, still "
			+ "empty: '%s'" % _key_row())
	var generation := int(BridgeClient.snapshot.get(
			"consumable_generation", 0))
	var controller := await _into_a_zone()
	if controller == null:
		return
	var zid := str(_zone_data.get("zone_id", ""))
	_check(not _bag_checks().is_empty(),
			"back into %s, where the Bomb Bag was claimed and left" % zid)
	if not await _claim_every_check(zid):
		return
	if not await _out_through_the_exit(zid):
		return
	var next: ZoneController = null
	for _i in ZONE_LIMIT:
		if not await _request_next_zone():
			return
		next = await _into_a_zone(true)
		if next != null or _discarded == "":
			break
	if next == null:
		return
	var next_id := str(_zone_data.get("zone_id", ""))
	_check(next_id != zid, "the next Zone, %s, designed and entered" % next_id)
	next.player.runtimes["consumable"].action_used.connect(
			func() -> void: _thrown += 1)
	full = BridgeClient.charges_total(cid)
	var refilled := await _await_live("the supply refilled",
			func() -> bool:
				return int(BridgeClient.snapshot.get(
						"consumable_generation", 0)) > generation \
						and BridgeClient.charges_left(cid) == full, 20.0)
	await _settle(10)
	_check(refilled and _key_row().contains("%d / %d" % [full, full])
			and not _key_row().contains("EMPTY"),
			"entering it refilled the supply (generation %d -> %d): '%s'"
			% [generation, int(BridgeClient.snapshot.get(
				"consumable_generation", 0)), _key_row()])
	if not await _throw_one(next.player):
		return
	await _await_live("the save counts it",
			func() -> bool: return _saved_spent(cid) == 1, 10.0)
	_check(_saved_spent(cid) == 1
			and _key_row().contains("%d / %d" % [full - 1, full]),
			"one thrown from the new supply, counted by the save: '%s'"
			% _key_row())
	await _leave_zone(next_id)
