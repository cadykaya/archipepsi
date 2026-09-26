class_name BombsDriver
extends Node
## A NATURALLY ACQUIRED BOMB, AS THE PLAYER SEES IT (`make godot-bombs`).
##
## H-BOMBS, PT-09 and V-15: "Natural candidate claim, not injected
## component. Item discoverable, compatible equip and real authorized
## use; absent/owned/empty cases distinguished."
##
## **NOTHING HERE IS TYPED IN.** `bomb_snapshots.json` is the engine's own
## snapshot of the candidate campaign the owner played, played again
## (`make bomb-fixture`): the Bomb Bag is the Echo of Check 89100140 in
## its sixth Zone, created by the fallback provider, slotted by
## `handle_slot_action` and spent through the real consumable handlers.
## Its notices are the ones the claim produced, delivered verbatim.
##
## **THROUGH THE REAL `Main`, beside it**, as the reload and machine-life
## proofs run. What a player is told is `Main`'s wiring -- which signal
## reaches the HUD -- so a suite that built a HUD of its own would be
## testing a copy of the wiring and could not see a signal nobody
## connected.
##
## What it asks, per state the packet names:
##   - the consumable key on the HUD: none owned, owned and not carried,
##     carried with its count, and empty, each reads differently;
##   - pressing the key in each: the player is told why nothing happened,
##     in the equipment wall's own words, once, or the use is asked for;
##   - the Bomb Bag arriving: its card, and a word pointing at the key --
##     and no such word for a campaign first met already owning it;
##   - equipping it from the equipment wall: the compatible key offered,
##     one request, the engine's answer shown;
##   - a use the engine refused: said once, in the engine's words;
##   - a use the engine granted: exactly one bomb, one report, the count;
##   - the next Zone: the supply refilled on the key.
##
## **ALL OF IT IN THE HUB**, where `Main` puts a player whose Campaign is
## loaded and where the Echo Lab is for trying a new thing. The press
## and its answer are the same code in a Zone.

const FLAG := "--bombs"
const FIXTURE := "res://tests/fixtures/bomb_snapshots.json"

var main: Node = null
var checks := 0
var failures := 0
var _fixture: Dictionary = {}
#: `Player.exhausted`, counted: the consumable suites' contract for a
#: refused press with a supply on the key, which this change keeps.
var _exhausted := 0


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	_run()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: " + message)
	else:
		failures += 1
		print("FAIL: " + message)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(30)
	BridgeClient.assume_sent = true
	# The player's own files are not a suite's to write.
	EquipmentSeen._reset_for_test()
	Favourites._reset_for_test()
	main._to_hub()
	await _frames(60)
	_player().exhausted.connect(func(_name: String) -> void: _exhausted += 1)
	_fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_provenance()
	await _the_key_on_the_hud()
	await _pressing_the_key()
	await _the_arrival()
	await _first_sight_is_not_news()
	await _equipping_it()
	await _a_refused_use()
	await _a_granted_use()
	await _the_refill()
	print("")
	if failures == 0:
		print("GODOT BOMBS OK (%d checks)" % checks)
		get_tree().quit(0)
	else:
		print("GODOT BOMBS TESTS: %d failures in %d checks"
				% [failures, checks])
		get_tree().quit(1)


# ---------------------------------------------------------------------------

func _meta() -> Dictionary:
	return _fixture.get("meta", {}) as Dictionary


func _cid() -> String:
	return str(_meta().get("component_id", ""))


func _deliver(variant: String) -> void:
	BridgeClient._handle(JSON.stringify(_fixture[variant]))
	await _frames(3)


func _player() -> Player:
	return main.hub.player if main.hub != null else main.zone.player


## The consumable key's row AS IT IS ON SCREEN: the HUD label `Main`
## repainted, not the text recomputed here, so a repaint nobody triggers
## is a stale row this reads.
func _key_row() -> String:
	var keycap := SlotKeycaps.of("consumable")
	for row: String in main.hud._echo_label.text.split("\n"):
		if row.substr(2).begins_with(keycap):
			return row
	return ""


func _toasts() -> Array[String]:
	var out: Array[String] = []
	for child: Node in main.hud._toast_box.get_children():
		if child is Label and not child.is_queued_for_deletion():
			out.append((child as Label).text)
	return out


func _clear_toasts() -> void:
	for child: Node in main.hud._toast_box.get_children():
		child.queue_free()


func _heard(words: String) -> int:
	var n := 0
	for text: String in _toasts():
		if text.contains(words):
			n += 1
	return n


func _sent_since(count: int) -> Array:
	return BridgeClient.sent_intents.slice(count)


func _types(intents: Array) -> Array:
	var out: Array = []
	for intent: Variant in intents:
		out.append(str((intent as Dictionary).get("type", "")))
	return out


func _owned_consumables(variant: String) -> Array:
	var out: Array = []
	var mech: Dictionary = (_fixture[variant] as Dictionary).get(
			"mechanics", {})
	for owned: Variant in mech.get("owned", []) as Array:
		var component: Dictionary = (owned as Dictionary).get("component", {})
		if str(component.get("slot", "")) == "consumable":
			out.append(str(component.get("component_id", "")))
	return out


## THE FIXTURE IS THE PLAYED CAMPAIGN, and says so.
func _provenance() -> void:
	print("  -- PROVENANCE: a Bomb Bag the campaign made, not one given")
	var meta := _meta()
	_check(str(meta.get("item_name", "")) == "Bomb Bag"
			and int(meta.get("location_id", 0)) == 89100140
			and int(meta.get("zone_index", 0)) == 6
			and meta.get("echo_operations", []) == ["CreateOperation"],
			"the Bomb Bag is the Echo of Check %d in Zone %d, created by "
			% [int(meta.get("location_id", 0)), int(meta.get("zone_index", 0))]
			+ "the provider (%s)" % str(meta.get("echo_operations", [])))
	var cid := _cid()
	_check(_owned_consumables("none_owned").is_empty()
			and _owned_consumables("acquired") == [cid],
			"before its Check the campaign owns no consumable; after it, "
			+ "exactly this one (%s)" % cid)
	var slots_after: Dictionary = (_fixture["acquired"] as Dictionary).get(
			"slots", {})
	var slots_carried: Dictionary = (_fixture["carried"] as Dictionary).get(
			"slots", {})
	_check(slots_after.get("consumable") == null
			and str(slots_carried.get("consumable", "")) == cid,
			"nothing puts it on a key for the player; the slot action does")


## THE KEY ON THE HUD, in each state.
func _the_key_on_the_hud() -> void:
	print("  -- THE KEY ON THE HUD: none, owned, carried, empty")
	var rows := {}
	for variant: String in ["none_owned", "acquired", "carried", "spent"]:
		await _deliver(variant)
		rows[variant] = _key_row()
		print("    %-10s %s" % [variant, rows[variant]])
	var charges := int(_meta().get("charges", 0))
	_check(str(rows["none_owned"]) != "" and str(rows["acquired"]) != ""
			and str(rows["none_owned"]) != str(rows["acquired"]),
			"owning a Bomb Bag that is on no key reads differently from "
			+ "owning none ('%s' / '%s')" % [rows["none_owned"],
				rows["acquired"]])
	_check(str(rows["acquired"]).contains("Bomb Bag"),
			"…and names what is owned")
	_check(str(rows["carried"]).contains("%d / %d" % [charges, charges]),
			"carried, the key shows its count (%s)" % rows["carried"])
	_check(str(rows["spent"]).contains("0 / %d" % charges)
			and str(rows["spent"]) != str(rows["carried"]),
			"empty, it shows 0 / %d and reads as empty (%s)"
			% [charges, rows["spent"]])


## PRESSING THE KEY: the player is told why nothing happened, or the use
## is asked for.
func _pressing_the_key() -> void:
	print("  -- PRESSING THE KEY in each state")
	var expect := {
		"none_owned": "No consumable owned yet",
		"acquired": "You own 1 consumable",
		"spent": "Empty",
	}
	for variant: String in ["none_owned", "acquired", "spent"]:
		await _deliver(variant)
		_clear_toasts()
		await _frames(2)
		_player().press_slot("consumable")
		await _frames(3)
		var said := _toasts()
		_check(_heard(str(expect[variant])) == 1,
				"%s: pressing the key says why nothing happened "
				% variant + "('%s' expected, heard %s)" % [expect[variant],
					str(said)])
		# A KEY PRESSED AGAIN AND AGAIN says it once, not a column of it.
		for _i in 3:
			_player().press_slot("consumable")
			await _frames(2)
		_check(_heard(str(expect[variant])) == 1,
				"%s: …and pressing it three more times does not stack it "
				% variant + "(%d on screen)" % _heard(str(expect[variant])))
	await _deliver("carried")
	_clear_toasts()
	await _frames(2)
	_player().press_slot("consumable")
	await _frames(3)
	_check(BridgeClient.awaiting_authorization(_cid()) == 1
			and _toasts().is_empty(),
			"carried with charges left: the press asks the bridge for a use "
			+ "and refuses nothing (awaiting %d, heard %s)"
			% [BridgeClient.awaiting_authorization(_cid()), str(_toasts())])
	# Put the world back as it was: the request is never answered here.
	BridgeClient.release_reservation(_cid())


## THE BOMB BAG ARRIVING, with the notices its claim produced.
func _the_arrival() -> void:
	print("  -- THE ARRIVAL: the card, and a word about the key")
	await _deliver("none_owned")
	await _frames(10)
	_clear_toasts()
	await _deliver("acquired")
	for raw: Variant in _meta().get("notices", []) as Array:
		BridgeClient._handle(JSON.stringify(raw))
		await _frames(2)
	var card: Dictionary = main.reveal.shown()
	_check(bool(card.get("visible", false))
			and str(card.get("echo", "")).contains("CONSUMABLE"),
			"the card shows the Bomb Bag and its slot (%s)"
			% str(card.get("echo", "")).replace("\n", " | "))
	var pointed := 0
	for text: String in _toasts():
		if text.contains("Bomb Bag") and text.contains(
				SlotKeycaps.of("consumable")):
			pointed += 1
	_check(pointed == 1, "a word points at the key it goes on, once "
			+ "(heard %s)" % str(_toasts()))
	_clear_toasts()
	await _deliver("acquired")
	var again := 0
	for text: String in _toasts():
		if text.contains("Bomb Bag"):
			again += 1
	_check(again == 0, "…and the next snapshot does not say it again")


## A CAMPAIGN FIRST MET ALREADY OWNING IT is a baseline, not news: its
## row says it is owned and not carried, and nothing claims it just
## arrived. The same snapshot, as another campaign's first -- which is
## what a restarted game sees.
func _first_sight_is_not_news() -> void:
	print("  -- FIRST SIGHT: a campaign that already owns it is not news")
	var other: Dictionary = (_fixture["acquired"] as Dictionary).duplicate(
			true)
	other["slot_name"] = str(other.get("slot_name", "")) + " (first met)"
	_clear_toasts()
	await _frames(2)
	BridgeClient._handle(JSON.stringify(other))
	await _frames(3)
	_check(_heard("Bomb Bag") == 0,
			"no word says it just arrived (heard %s)" % str(_toasts()))
	_check(_key_row().contains("Bomb Bag owned, not carried"),
			"…while its row still says it is owned and on no key (%s)"
			% _key_row())
	# And back to the played campaign, which is first-met again now.
	await _deliver("acquired")
	_check(_heard("Bomb Bag") == 0, "…nor on returning to the campaign")


## EQUIPPING IT FROM THE EQUIPMENT WALL: the one control a player has
## for putting a consumable on its key.
func _equipping_it() -> void:
	print("  -- EQUIPPING IT from the equipment wall")
	var cid := _cid()
	var key := SlotKeycaps.of("consumable")
	await _deliver("acquired")
	main._open_menu("equipment")
	await _frames(10)
	main.equipment.select(cid)
	await _frames(5)
	var put := main.equipment.detail_root().find_child(
			"Equip", true, false) as Button
	_check(put != null and not put.disabled
			and put.text == "EQUIP ON %s" % key,
			"the Bomb Bag's card offers EQUIP ON %s (%s)" % [key,
				"none" if put == null else "'%s'%s" % [put.text,
					" disabled" if put.disabled else ""]])
	var before := BridgeClient.sent_intents.size()
	if put != null:
		put.pressed.emit()
	await _frames(3)
	var asked := _sent_since(before)
	_check(asked.size() == 1
			and str((asked[0] as Dictionary).get("type", "")) == "slot_action"
			and str((asked[0] as Dictionary).get("slot", "")) == "consumable"
			and str((asked[0] as Dictionary).get("component_id", "")) == cid,
			"pressing it asks the bridge to put it on the consumable key, "
			+ "once (%s)" % str(asked))
	# The engine's answer to exactly that request.
	await _deliver("carried")
	await _frames(5)
	var off := main.equipment.detail_root().find_child(
			"Unequip", true, false) as Button
	_check(off != null and off.text == "TAKE OFF %s" % key,
			"the engine's answer shows it on %s (%s)" % [key,
				"none" if off == null else "'%s'" % off.text])
	main._close_menu()
	await _frames(10)
	_check(_key_row().contains("Bomb Bag  3 / 3"),
			"…and the HUD key counts it (%s)" % _key_row())


## A USE THE ENGINE REFUSED -- a press that crossed a refill, refused by
## the real server -- is said once, in the engine's words.
func _a_refused_use() -> void:
	print("  -- A REFUSED USE: said once, in the engine's words")
	var cid := _cid()
	var refusal: Dictionary = _fixture["refused"]
	await _deliver("carried")
	_clear_toasts()
	await _frames(2)
	var exhausted := _exhausted
	_player().press_slot("consumable")
	await _frames(3)
	_check(BridgeClient.awaiting_authorization(cid) == 1,
			"the press asks for use 1 of supply %d"
			% int(_meta().get("generation", 0)))
	BridgeClient._handle(JSON.stringify(refusal))
	await _frames(3)
	var words := str(refusal.get("message", ""))
	_check(_heard(words) == 1 and _toasts().size() == 1,
			"the engine's refusal is on screen once, and nothing else is "
			+ "(heard %s)" % str(_toasts()))
	_check(_exhausted == exhausted + 1,
			"the refusal still counts as refused (`Player.exhausted`)")
	_check(BridgeClient.awaiting_authorization(cid) == 0
			and BridgeClient.charges_left(cid) == int(_meta().get(
				"charges", 0)),
			"…and the charge is back: nothing launched (%d left)"
			% BridgeClient.charges_left(cid))


## A USE THE ENGINE GRANTED: the press, the answer, exactly one bomb.
func _a_granted_use() -> void:
	print("  -- A GRANTED USE: the press, the engine's answer, the bomb")
	var cid := _cid()
	var runtime: EchoRuntime = _player().runtimes["consumable"]
	var effects := [0]
	var count := func() -> void: effects[0] += 1
	runtime.action_used.connect(count)
	await _deliver("carried")
	_clear_toasts()
	await _frames(2)
	var before := BridgeClient.sent_intents.size()
	_player().press_slot("consumable")
	await _frames(3)
	_check(BridgeClient.awaiting_authorization(cid) == 1
			and effects[0] == 0,
			"the press asks, and nothing is thrown before the answer")
	await _deliver("authorized")
	await _frames(10)
	var sent := _sent_since(before)
	_check(effects[0] == 1,
			"the engine's answer throws exactly one Bomb Bag (%d thrown; "
			% effects[0] + "the key's runtime holds '%s'; sent %s)"
			% [str(runtime.equipped.get("display_name", "nothing")),
				str(_types(sent))])
	var reports: Array = []
	for intent: Variant in sent:
		if str((intent as Dictionary).get("type", "")) == "use_consumable":
			reports.append(intent)
	_check(reports.size() == 1
			and int((reports[0] as Dictionary).get("use_index", 0)) == 1,
			"…and reports that one use (%s)" % str(reports))
	_check(_key_row().contains("Bomb Bag  2 / 3")
			and not _key_row().contains("EMPTY"),
			"the key counts it: 2 / 3 (%s)" % _key_row())
	_check(_toasts().is_empty(),
			"nothing is refused (heard %s)" % str(_toasts()))
	runtime.action_used.disconnect(count)


## THE NEXT ZONE REFILLS IT, and the key says so.
func _the_refill() -> void:
	print("  -- THE REFILL: spent, then the next Zone")
	var charges := int(_meta().get("charges", 0))
	await _deliver("spent")
	var empty := _key_row()
	await _deliver("refilled")
	var full := _key_row()
	# The supply the refill gives is whatever the component holds NOW:
	# the rest of Zone 6 upgraded it (Mk), and an upgrade may add charges.
	var refilled := BridgeClient.charges_total(_cid())
	_check(empty.contains("0 / %d  EMPTY" % charges)
			and full.contains("Bomb Bag")
			and full.contains("%d / %d" % [refilled, refilled])
			and not full.contains("EMPTY"),
			"spent reads EMPTY on the key, and entering Zone %s refills it "
			% str(_meta().get("refilled_zone_id", "?"))
			+ "('%s' -> '%s')" % [empty.strip_edges(), full.strip_edges()])
