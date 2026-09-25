extends Node
## H-INVENTORY (CP3): THE EQUIPMENT WALL, asked `04_3D_MENU_MAP_AND_GLYPH.md`
## §5's questions on the real widget, mounted on the real 3D shell.
##
## Every snapshot is a real one: `tests/fixtures/equipment_snapshot.json`
## is `CampaignSnapshot`s built by the bridge's own model (`make
## equipment-fixture`), delivered through `BridgeClient._handle` -- the
## path a websocket frame takes -- so the face reads the inventory Dess's
## projection actually emits.
##
## The first nine cases are the nine requirements the old wall
## (`InventoryLayer`, cb8dbd6) failed in the reproduction
## (`H-INVENTORY_before.log`), measured the same way. The rest are the
## archive's own tests, carried over to the item face, and the input the
## packet asks for: mouse, keyboard, controller, and typing that never
## plays.
##
## **Declared harness steps.** `BridgeClient.assume_sent` stands the link
## up or down (a driver has no socket; `can_send()` reads the same seam
## `send_intent` does). A refusal arrives as an `error` frame through
## `_handle`, carrying the `about` key the bridge does NOT yet attach to a
## `slot_action` (N-11): that case proves the client half. One NOT SENT is
## produced by a stub sender, because with the real client a send cannot
## fail while `can_send()` says it would succeed. The controller case
## focuses the EQUIP button directly before pressing A: Tab is the shell's
## own key, so there is no focus-next to walk there with.

const FIXTURE := "res://tests/fixtures/equipment_snapshot.json"
const SHOTS_FLAG := "--shots="
## `--equipment-only=<case>` runs one case, for iterating on it.
const ONLY_FLAG := "--equipment-only="
const CASES := [
	"_one_item_one_tile",
	"_three_regions",
	"_an_offline_equip_says_so",
	"_pending_then_accepted",
	"_refusals_and_a_lost_link",
	"_the_consumable_key",
	"_a_new_item_is_marked",
	"_the_detail_answers",
	"_the_split_and_the_filter",
	"_history_and_reads",
	"_the_search_box_keeps_its_place",
	"_typing_is_not_playing",
	"_keyboard_and_controller",
	"_the_mouse",
	"_turns_and_closes",
	"_an_empty_spare_is_not_offered",
]

var shell: MenuShell
var face: EquipmentFace
var variants: Dictionary = {}
var _checks := 0
var _failures := 0
var _notes := 0
## Key events that got past the shell to `_unhandled_input`.
var _leaked_keys := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_leaked_keys += 1


func _only() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ONLY_FLAG):
			return arg.substr(ONLY_FLAG.length())
	return ""


func _shots_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SHOTS_FLAG):
			return arg.substr(SHOTS_FLAG.length())
	return ""


func _run() -> void:
	await get_tree().process_frame
	# A headless window is 64 x 64 whatever project.godot says.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	variants = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	EquipmentSeen._reset_for_test()
	Favourites._reset_for_test()
	shell = MenuShell.new()
	add_child(shell)
	# Mounted exactly as `Main` mounts it.
	face = EquipmentFace.new()
	shell.page_root("equipment").add_child(face)
	shell.page_changed.connect(func(page: String) -> void:
		if page == "equipment":
			face.take_focus())
	await get_tree().process_frame
	var shots := _shots_dir()
	if shots != "":
		await _shoot(shots)
		_finish("EQUIPMENT FACE SHOTS")
		return
	var only := _only()
	for case: String in CASES:
		if only == "" or case == only:
			await call(case)
	_finish("GODOT EQUIPMENT FACE")


func _finish(what: String) -> void:
	shell.close()
	print("")
	if _failures == 0:
		print("%s OK (%d checks, %d notes)" % [what, _checks, _notes])
		get_tree().quit(0)
		return
	print("%s TESTS: %d failures in %d checks" % [what, _failures, _checks])
	get_tree().quit(1)


# ---------------------------------------------------------------------------
# Standing it up
# ---------------------------------------------------------------------------

func _deliver(variant: String) -> void:
	BridgeClient._handle(JSON.stringify(variants[variant]))
	await _frames(2)


func _open(variant: String, online := true, page := "equipment") -> void:
	BridgeClient.assume_sent = online
	await _deliver(variant)
	face.open()
	shell.open(page)
	await _frames(3)


## Between cases: the menu closed, the link down, and nothing a case left
## outstanding carried into the next. A request is REAL state -- it
## survives a close on purpose -- so a case that leaves one would
## otherwise decide the next case's answers.
func _close() -> void:
	shell.close()
	face.close()
	face.requests = EquipRequests.new()
	face._unattributed = ""
	BridgeClient.assume_sent = false
	BridgeClient._in_flight.clear()
	await _frames(2)


## Press a button the way its signal fires, but only if a player could:
## `pressed.emit()` on a disabled button would run the handler anyway and
## prove something no player can do.
func _press(button: Button, what: String) -> bool:
	if button == null or button.disabled or not button.is_visible_in_tree():
		_check(false, "%s can be pressed (%s)" % [what,
				"missing" if button == null else "disabled or hidden"])
		return false
	button.pressed.emit()
	await _frames(2)
	return true


func _select(component_id: String) -> void:
	face.select(component_id)
	await _frames(2)


## What a node says, with the no-break spaces that keep a unit on its
## number's line read as the ordinary spaces they stand for.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text.replace("\u00a0", " "))
	elif node is Button:
		out.append((node as Button).text.replace("\u00a0", " "))
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


func _has(texts: Array[String], needle: String) -> bool:
	for text: String in texts:
		if text.contains(needle):
			return true
	return false


func _button(root: Node, node_name: String) -> Button:
	var found := root.find_children(node_name, "Button", true, false)
	return null if found.is_empty() else found[0] as Button


func _slot_panel(slot: String) -> Control:
	return face.slot_rows().get_node_or_null("Slot_%s" % slot) as Control


func _request_state(root: Node) -> String:
	for node: Node in root.find_children("Request", "Label", true, false):
		return str(node.get_meta("request_state", ""))
	return ""


func _holds(slot: String) -> String:
	var panel := _slot_panel(slot)
	var label := panel.find_children("Holds", "Label", true, false)
	return "" if label.is_empty() else (label[0] as Label).text


func _item(variant: String, cid: String) -> Dictionary:
	for raw: Variant in variants[variant]["inventory"]["items"]:
		if str((raw as Dictionary).get("component_id", "")) == cid:
			return raw
	return {}


func _intents_since(before: int) -> Array:
	return BridgeClient.sent_intents.slice(before)


# ---------------------------------------------------------------------------
# R1 -- one item, one tile, one way to equip it
# ---------------------------------------------------------------------------

func _one_item_one_tile() -> void:
	print("  -- R1: items, not events")
	await _open("swapped")
	var tiles := face.tiles()
	var ids: Array = []
	for raw: Variant in variants["swapped"]["inventory"]["items"]:
		ids.append(str((raw as Dictionary)["component_id"]))
	# COUNTED AS BUTTONS, not through `tiles()`: a dictionary keyed by id
	# folds two tiles for one item into one, which is the defect this
	# case exists to catch.
	var drawn: Array = []
	for node: Node in face.find_children("*", "Button", true, false):
		if node.has_meta("component_id"):
			drawn.append(str(node.get_meta("component_id")))
	drawn.sort()
	ids.sort()
	_check(drawn == ids, "one tile per inventory item, %d of %d: %s"
			% [drawn.size(), ids.size(), drawn])
	var names: Array[String] = []
	for tile: Button in tiles.values():
		names.append_array(_texts(tile))
	_check(not _has(names, "Leather Grip"),
			"the upgrade-only Echo is not a tile of its own")
	# THE REPRODUCTION'S MEASURE: press every equip control on the wall
	# and count the intents that would put Braided Lash on a key.
	await _select("act_lash")
	var before := BridgeClient.sent_intents.size()
	for node: Node in face.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.disabled and (button.text.begins_with("EQUIP")
				or button.text.begins_with("REPLACE")):
			button.pressed.emit()
	await _frames(2)
	var offers := 0
	for intent: Dictionary in _intents_since(before):
		if intent.get("component_id") == "act_lash":
			offers += 1
	_check(offers == 1, "one control offers to equip Braided Lash, "
			+ "got %d (the old wall had 2)" % offers)
	face._history_open = true
	face._queue_repaint()
	await _frames(2)
	_check(_has(_texts(face.detail_root()),
			"Mk II  +4 damage ← Longshot  (Ocarina of Time)"),
			"Leather Grip's upgrade is Braided Lash's history instead")
	face._history_open = false
	await _close()


# ---------------------------------------------------------------------------
# R2 -- three regions, on the wall, in the page
# ---------------------------------------------------------------------------

func _three_regions() -> void:
	print("  -- R2: three regions")
	await _open("base")
	var equipped := face.find_child("Equipped", true, false) as Control
	var owned := face.find_child("Owned", true, false) as Control
	var detail := face.find_child("DetailColumn", true, false) as Control
	_check(equipped != null and owned != null and detail != null,
			"EQUIPPED, OWNED and DETAIL are all there")
	var rows: Array = []
	for slot: String in Constants.SLOT_NAMES:
		if _slot_panel(slot) != null:
			rows.append(slot)
	_check(rows.size() == Constants.SLOT_NAMES.size(),
			"a row for each of the game's %d keys, and no others: %s"
			% [Constants.SLOT_NAMES.size(), rows])
	_check(not owned.find_children("*", "GridContainer", true,
			false).is_empty() and face.tiles().size() > 0,
			"the owned items are a grid of tiles")
	var detail_texts := _texts(face.detail_root())
	var name := EquipmentQuery.name_of(EquipmentQuery.item_by_id(
			EquipmentQuery.items(BridgeClient.snapshot), face.selected()))
	_check(_has(detail_texts, name) and _has(detail_texts, "WHAT IT DOES")
			and _has(detail_texts, "HOW IT IS USED")
			and _has(detail_texts, "WHAT IT COSTS"),
			"the detail shows the selected item (%s): what it does, how it "
			% name + "is used, what it costs")
	var a := equipped.get_global_rect()
	var b := owned.get_global_rect()
	var c := detail.get_global_rect()
	var page := Rect2(Vector2.ZERO, Vector2(MenuShell.PAGE_PIXELS))
	_check(page.encloses(a) and page.encloses(b) and page.encloses(c)
			and a.end.x <= b.position.x and b.end.x <= c.position.x,
			"side by side inside the %s page, not overlapping: %s | %s | %s"
			% [MenuShell.PAGE_PIXELS, a, b, c])
	var title := shell.page_root("equipment").get_node("Title") as Control
	_check(title.get_global_rect().end.y <= face.get_global_rect().position.y,
			"under the wall's title, not over it")
	_check(face.get_viewport() == shell.page_viewport("equipment"),
			"on the Equipment wall's own page, in the box")
	await _close()


# ---------------------------------------------------------------------------
# R3 -- offline, and a send that did not leave
# ---------------------------------------------------------------------------

func _an_offline_equip_says_so() -> void:
	print("  -- R3: no link")
	await _open("base", false)
	await _select("act_bolt")
	var equip := _button(face.detail_root(), "Equip")
	var texts := _texts(face.detail_root())
	_check(equip != null and equip.disabled and _has(texts, "Offline"),
			"offline, EQUIP is not offered and says why: %s"
			% [texts.filter(func(t: String) -> bool: return t.contains(
				"Offline"))])
	var before := BridgeClient.sent_intents.size()
	var state := face.equip_selected()
	_check(state == "" and BridgeClient.sent_intents.size() == before,
			"and the non-drag equip sends nothing")
	var link := face.find_child("LinkLine", true, false) as Label
	_check(link.visible and link.text.begins_with("OFFLINE"),
			"the EQUIPPED column says the link is down: '%s'" % link.text)
	# A send that fails although the link looked up: the stub sender.
	face.requests.send("echo_b", "act_lens",
			func(_intent: Dictionary) -> bool: return false)
	face._queue_repaint()
	await _frames(2)
	_check(_request_state(_slot_panel("echo_b")) == EquipRequests.NOT_SENT
			and _has(_texts(_slot_panel("echo_b")), "not sent"),
			"a send that did not leave is NOT SENT on its key, not silent")
	await _close()


# ---------------------------------------------------------------------------
# R4 -- pending until the snapshot says so
# ---------------------------------------------------------------------------

func _pending_then_accepted() -> void:
	print("  -- R4: pending, then accepted by a snapshot")
	await _open("base")
	await _select("act_bolt")
	var key := SlotKeycaps.of("echo_a")
	var equip := _button(face.detail_root(), "Equip")
	_check(equip != null and equip.text == "REPLACE BRAIDED LASH ON %s" % key,
			"the button names the key and what it replaces: '%s'"
			% (equip.text if equip != null else "none"))
	var texts := _texts(face.detail_root())
	_check(_has(texts, "AGAINST BRAIDED LASH ON %s" % key)
			and _has(texts, "Kind: projectile damage → hitscan damage")
			and _has(texts, "Damage: 18 → 9")
			and _has(texts, "Range: — → 40 m")
			and _has(texts, "Cooldown: 1.2 s → 0.8 s")
			and _has(texts, "Mk 2 → Mk 1"),
			"the comparison is against what is on the key, now → this")
	_check(not _has(texts, "Pellets:") and not _has(texts, "Flight time:"),
			"and a field only one kind of attack has is not listed as a "
			+ "difference")
	var before := BridgeClient.sent_intents.size()
	await _press(equip, "REPLACE")
	var sent := _intents_since(before)
	_check(sent.size() == 1 and sent[0] == {"type": "slot_action",
			"slot": "echo_a", "component_id": "act_bolt"},
			"one slot_action, for Arc Bolt on echo_a: %s" % [sent])
	_check(_holds("echo_a").begins_with("Braided Lash"),
			"the key still shows what the bridge confirmed: '%s'"
			% _holds("echo_a"))
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.PENDING
			and _has(_texts(_slot_panel("echo_a")),
				"Arc Bolt: sent, waiting for the bridge"),
			"and says the request is waiting")
	equip = _button(face.detail_root(), "Equip")
	_check(equip != null and equip.disabled and _has(_texts(
			face.detail_root()), "Waiting for the bridge's answer"),
			"a second press is not offered while it waits")
	await _deliver("base")
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.PENDING,
			"an unrelated snapshot answers nothing")
	await _deliver("swapped")
	_check(_holds("echo_a").begins_with("Arc Bolt"),
			"the snapshot that carries it moves the key: '%s'"
			% _holds("echo_a"))
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.ACCEPTED
			and _has(_texts(_slot_panel("echo_a")),
				"✓ Arc Bolt: the bridge confirmed it"),
			"and the request reads ACCEPTED")
	var off := _button(face.detail_root(), "Unequip")
	_check(off != null and off.text == "TAKE OFF %s" % key,
			"Arc Bolt now offers to come off its key")
	# Unequip is a request too.
	before = BridgeClient.sent_intents.size()
	await _press(off, "TAKE OFF")
	sent = _intents_since(before)
	_check(sent.size() == 1 and sent[0]["component_id"] == null
			and _request_state(_slot_panel("echo_a")) == EquipRequests.PENDING,
			"TAKE OFF sends a clear and waits for it: %s" % [sent])
	await _close()


# ---------------------------------------------------------------------------
# R5 -- refusals, attributed only on an exact key
# ---------------------------------------------------------------------------

func _error(message: String, about: String) -> void:
	BridgeClient._handle(JSON.stringify({"type": "error", "scope": "bridge",
			"recoverable": true, "message": message, "about": about}))
	await _frames(2)


func _refusals_and_a_lost_link() -> void:
	print("  -- R5: refused, and the link lost")
	await _open("base")
	await _select("act_bolt")
	await _press(_button(face.detail_root(), "Equip"), "REPLACE")
	await _error("the bridge is busy", "")
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.PENDING,
			"an error with no `about` resolves nothing")
	var line := face.find_child("BridgeLine", true, false) as Label
	_check(line.visible and line.text
			== "The bridge refused a request: the bridge is busy",
			"it is shown as the bridge's, unattributed: '%s'" % line.text)
	await _error("not this one", "slot_action:echo_a:act_lash")
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.PENDING,
			"a refusal naming another request resolves nothing")
	await _error("'act_bolt' is not owned", "slot_action:echo_a:act_bolt")
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.REFUSED
			and _has(_texts(_slot_panel("echo_a")),
				"✗ Arc Bolt: refused — 'act_bolt' is not owned"),
			"the exact key is REFUSED, with the bridge's reason")
	_check(_holds("echo_a").begins_with("Braided Lash"),
			"and the key never showed Arc Bolt")
	var equip := _button(face.detail_root(), "Equip")
	_check(equip != null and not equip.disabled,
			"EQUIP is offered again after the refusal")
	_note("the live bridge does not attach `about` to a slot_action "
			+ "refusal yet (N-11, Dess's `_about`); this is the client half")
	await _press(equip, "REPLACE, again")
	BridgeClient.bridge_state_changed.emit(false)
	await _frames(2)
	_check(_request_state(_slot_panel("echo_a")) == EquipRequests.LOST
			and not face.requests.is_pending("echo_a"),
			"a link lost mid-request is LOST, not pending forever")
	await _close()


# ---------------------------------------------------------------------------
# R6-R8 -- the consumable key's states
# ---------------------------------------------------------------------------

func _consumable(variant: String, online := true) -> Dictionary:
	await _open(variant, online)
	var panel := _slot_panel("consumable")
	var out := {"state": str(panel.get_meta("consumable_state", "")),
			"texts": _texts(panel), "holds": _holds("consumable")}
	await _close()
	return out


func _the_consumable_key() -> void:
	print("  -- R6-R8: the consumable key")
	var none := await _consumable("none_owned")
	var spare := await _consumable("unequipped")
	_check(none["state"] == "none_owned"
			and _has(none["texts"], "No consumable owned yet"),
			"none owned says so: %s" % [none["texts"]])
	_check(spare["state"] == "owned_not_equipped"
			and _has(spare["texts"], "You own 2 consumables"),
			"owned but not equipped says so: %s" % [spare["texts"]])
	_check(none["texts"] != spare["texts"],
			"and the two read differently (the old key read '—' for both)")
	var empty := await _consumable("exhausted")
	_check(empty["state"] == "equipped_empty"
			and str(empty["holds"]).contains("0 / 3")
			and _has(empty["texts"], "entering a Zone refills it"),
			"equipped and empty: 0 / 3, still on the key, and what refills "
			+ "it: %s" % [empty["texts"]])
	var ready := await _consumable("base")
	var offline := await _consumable("base", false)
	_check(ready["state"] == "ready"
			and str(ready["holds"]).contains("2 / 3"),
			"ready: '%s'" % ready["holds"])
	_check(offline["state"] == "disconnected"
			and _has(offline["texts"], "OFFLINE")
			and str(offline["holds"]).contains("2 / 3")
			and offline["texts"] != ready["texts"],
			"disconnected says so, count kept: %s" % [offline["texts"]])
	await _open("base")
	BridgeClient.reserve_consumable("act_cinder")
	BridgeClient.authorize_consumable("act_cinder")
	face.rebuild()
	await _frames(2)
	var panel := _slot_panel("consumable")
	_check(str(panel.get_meta("consumable_state", "")) == "pending"
			and _has(_texts(panel), "1 use waiting for the bridge's answer")
			and _holds("consumable").contains("1 / 3"),
			"a use awaiting the bridge says so, beside the count the HUD "
			+ "shows: '%s' %s" % [_holds("consumable"), _texts(panel)])
	await _close()
	# THE CLIENT'S COUNT AND THE VIEW'S AGREE with nothing in flight: the
	# bridge's `charges_left` and `BridgeClient.charges_left` are two
	# computations of one number.
	for variant: String in ["base", "exhausted", "unequipped",
			"spent_spare"]:
		await _deliver(variant)
		for cid: String in ["act_cinder", "act_flask"]:
			var item := _item(variant, cid)
			_check(BridgeClient.charges_left(cid)
					== int(item.get("charges_left", -1)),
					"%s %s: the client counts %d, the view %s" % [variant,
					cid, BridgeClient.charges_left(cid),
					item.get("charges_left")])


# ---------------------------------------------------------------------------
# R9 -- the new item says so
# ---------------------------------------------------------------------------

func _new_tiles() -> Array:
	var out: Array = []
	for cid: String in face.tiles():
		if _has(_texts(face.tiles()[cid]), "NEW"):
			out.append(cid)
	return out


func _a_new_item_is_marked() -> void:
	print("  -- R9: a new item")
	EquipmentSeen._reset_for_test()
	await _open("base")
	_check(_new_tiles().is_empty(),
			"a campaign met for the first time marks nothing new: %s"
			% [_new_tiles()])
	await _deliver("acquired")
	_check(_new_tiles() == ["act_glow"],
			"Glow Seed arrives marked NEW, and only it: %s" % [_new_tiles()])
	var title := (face.find_child("Owned", true, false) as Node)
	_check(_has(_texts(title), "OWNED   1 NEW"),
			"the OWNED heading counts it")
	await _select("act_glow")
	_check(_new_tiles().is_empty() and not _has(_texts(title), "NEW"),
			"inspecting it is noticing it: the marker goes")
	await _close()
	# THE CONTROL: the marker is about arrival after the campaign was met,
	# not about the item.
	EquipmentSeen._reset_for_test()
	await _open("acquired")
	_check(_new_tiles().is_empty(),
			"met for the first time already holding it, it is not new")
	await _close()


# ---------------------------------------------------------------------------
# What the detail says
# ---------------------------------------------------------------------------

func _the_detail_answers() -> void:
	print("  -- the detail")
	await _open("base")
	await _select("act_cinder")
	var q := SlotKeycaps.of("consumable")
	var texts := _texts(face.detail_root())
	var raw: Array[String] = []
	for node: Node in face.detail_root().find_children("*", "Label", true,
			false):
		raw.append((node as Label).text)
	_check(_has(raw, "after 1.5\u00a0s"),
			"a number keeps its unit on its line (a no-break space)")
	for line: String in [
			"Thrown: bursts for 30 damage within 3.0 m after 1.5 s",
			"Hits leave burning for 3.0 s",
			"On a key: %s (CONSUMABLE). Press it to use." % q,
			"The status lands on enemies it hits.",
			"2 of 3 uses left.",
			"Cooldown 1 s.",
			"3 uses per supply. Entering a Zone refills it."]:
		_check(_has(texts, line), "Cinder Charge: '%s'" % line)
	await _select("trait_ward")
	texts = _texts(face.detail_root())
	_check(_has(texts, "Only while Arc Bolt is on a key. It is not, so this "
			+ "does nothing right now."),
			"a trait that needs an Action says it is doing nothing now")
	_check(_button(face.detail_root(), "Equip") == null
			and _has(texts, "always on while you own it"),
			"and, being passive, offers no switch and says why")
	await _deliver("swapped")
	await _select("trait_ward")
	_check(_has(_texts(face.detail_root()),
			"Only while Arc Bolt is on a key. It is, on %s."
			% SlotKeycaps.of("echo_a")),
			"with Arc Bolt on its key, it says it is on")
	await _select("act_lens")
	var equip := _button(face.detail_root(), "Equip")
	_check(equip != null and equip.text == "EQUIP ON %s"
			% SlotKeycaps.of("utility"),
			"an empty key's candidate reads EQUIP ON %s: '%s'" % [
				SlotKeycaps.of("utility"), equip.text if equip else ""])
	await _close()


# ---------------------------------------------------------------------------
# The archive's own tests, on the item face
# ---------------------------------------------------------------------------

func _role(root: Node, role: String) -> Array[String]:
	var out: Array[String] = []
	for node: Node in root.find_children("*", "Label", true, false):
		if node.get_meta("role", "") == role:
			out.append((node as Label).text)
	return out


func _sections() -> Array[String]:
	return _role(face, "section")


func _tile_ids() -> Array:
	var ids := face.tiles().keys()
	ids.sort()
	return ids


func _the_split_and_the_filter() -> void:
	print("  -- the split, the key filter, search")
	await _open("base")
	_check(_sections() == ["ON A KEY (6)", "ALWAYS ON (3)"],
			"six things go on keys and three are simply on: %s" % [_sections()])
	await _select("act_lash")
	_check(_has(_texts(face.detail_root()), "Sure Grip (always on)"),
			"the mixed Echo's Action names its other half")
	await _select("trait_grip")
	_check(_has(_texts(face.detail_root()), "Braided Lash (on %s)"
			% SlotKeycaps.of("echo_a")),
			"and its Trait names the Action -- neither half dropped")
	await _press(_slot_panel("echo_a").find_child("Key", true, false)
			as Button, "the RMB key")
	_check(_tile_ids() == ["act_bolt", "act_lash"],
			"the RMB key shows what goes on it: %s" % [_tile_ids()])
	_check(_sections() == ["ON A KEY (2 of 6)"],
			"counted as 2 of 6, the always-on half hidden: %s" % [_sections()])
	var asked := EquipmentQuery.grid(EquipmentQuery.items(
			BridgeClient.snapshot), "", 0, "echo_a")
	_check((asked["always_on"] as Array).is_empty()
			and (asked["slotted"] as Array).size() == 2,
			"and that is the query's answer, not only the painting's")
	var bar := face.find_child("FilterBar", true, false) as Control
	_check(bar.visible and _has(_texts(bar), "Always-on items are hidden")
			and _button(bar, "ShowAll") != null,
			"and it says so, with the way back beside it")
	_check(face.selected() == "act_lash",
			"picking the key shows what is on it, to compare against")
	face.set_slot_filter("mobility")
	await _frames(2)
	_check(_tile_ids() == ["act_dash"], "MOBILITY: %s" % [_tile_ids()])
	await _press(_button(bar, "ShowAll"), "SHOW ALL")
	_check(_tile_ids().size() == 9, "SHOW ALL brings back all nine")
	face.search_box().text = "shard"
	face._queue_repaint()
	await _frames(2)
	_check(_tile_ids() == ["res_magic"],
			"searching an upgrade's item finds the item it upgraded: %s"
			% [_tile_ids()])
	face.search_box().text = "ocarina"
	face._queue_repaint()
	await _frames(2)
	_check(_tile_ids() == ["act_cinder", "act_lash", "act_lens",
			"res_magic", "trait_grip", "trait_ward"],
			"a game's name finds everything from it: %s" % [_tile_ids()])
	face.search_box().text = "zzz"
	face._queue_repaint()
	await _frames(2)
	_check(_has(_texts(face), "Nothing matches “zzz”."),
			"no match says so")
	face.search_box().text = ""
	await _close()


func _history_and_reads() -> void:
	print("  -- history and what Epsilon read")
	await _open("base")
	await _select("res_magic")
	var toggle := _button(face.detail_root(), "History")
	_check(toggle != null and toggle.text.begins_with("HISTORY ▸"),
			"history starts folded, after the summary")
	await _press(toggle, "HISTORY")
	var rows := _role(face.detail_root(), "history")
	_check(rows == ["Mk I  Magic Meter ← Magic Upgrade  (Ocarina of Time)",
			"Mk II  +40 max_value ← Estus Shard  (Dark Souls)"],
			"the whole chain, in order, once: %s" % [rows])
	var reads := _role(face.detail_root(), "read")
	_check(_has(reads, "read literal: magic / green / capacity")
			and _has(reads, "read mechanical: capacity / shard"),
			"with what Epsilon read for each: %s" % [reads])
	face._history_open = false
	await _close()


func _the_search_box_keeps_its_place() -> void:
	print("  -- the search box keeps focus and caret across a snapshot")
	await _open("base")
	var search := face.search_box()
	search.text = "lash"
	face._queue_repaint()
	search.grab_focus()
	search.caret_column = 2
	await _frames(2)
	var viewport := shell.page_viewport("equipment")
	_check(viewport.gui_get_focus_owner() == search,
			"the box has focus to begin with")
	await _deliver("acquired")
	_check(viewport.gui_get_focus_owner() == search
			and search.caret_column == 2 and search.text == "lash",
			"a snapshot mid-search keeps focus, caret %d and text '%s'"
			% [search.caret_column, search.text])
	# WHY, asserted rather than assumed: a repaint empties these three;
	# the box is under none of them.
	var emptied: Array = face.repainted()
	var outside := true
	for root: Node in emptied:
		if root.is_ancestor_of(search):
			outside = false
	_check(outside and search == face.search_box(),
			"because the box is outside everything a repaint empties")
	search.text = ""
	search.release_focus()
	await _close()


# ---------------------------------------------------------------------------
# Input, as the engine receives it
# ---------------------------------------------------------------------------

func _typing_is_not_playing() -> void:
	print("  -- typing Q, C and E into search")
	await _open("base")
	var search := face.search_box()
	await _click(_screen_point_of(search.get_global_rect().get_center()))
	var viewport := shell.page_viewport("equipment")
	_check(viewport.gui_get_focus_owner() == search,
			"a click through the box puts the caret in the search field")
	var before := BridgeClient.sent_intents.size()
	var leaked := _leaked_keys
	await _key(KEY_Q, "q")
	await _key(KEY_C, "c")
	await _key(KEY_E, "e")
	await _frames(2)
	_check(search.text == "qce" and shell.front() == "equipment"
			and not shell.is_turning(),
			"the letters go into the box ('%s') and the box does not turn"
			% search.text)
	_check(BridgeClient.sent_intents.size() == before,
			"no intent left: no consumable (Q), no utility (C)")
	_check(_leaked_keys == leaked,
			"and no key event got past the shell to the game (%d leaked)"
			% (_leaked_keys - leaked))
	search.text = ""
	search.release_focus()
	await _close()


func _focused() -> Control:
	return shell.page_viewport("equipment").gui_get_focus_owner()


func _keyboard_and_controller() -> void:
	print("  -- keyboard and controller")
	await _open("base", true, "settings")
	await _key(KEY_Q)
	await _rest()
	_check(shell.front() == "equipment", "Q turns Settings to Equipment")
	var start := _focused()
	_check(start != null and face.is_ancestor_of(start)
			and str(start.get_meta("focus_key", "")).begins_with("tile:"),
			"arriving, the selected tile holds focus: %s"
			% (start.get_meta("focus_key", "") if start else "nothing"))
	await _key(KEY_RIGHT)
	var moved := _focused()
	_check(moved != null and moved != start and face.is_ancestor_of(moved),
			"an arrow key moves focus to another control on the wall: %s"
			% (moved.get_meta("focus_key", "") if moved else "nothing"))
	# To a tile, and choose it with the keyboard.
	var target: Button = face.tiles()["act_bolt"]
	target.grab_focus()
	await _key(KEY_ENTER)
	await _frames(2)
	_check(face.selected() == "act_bolt",
			"Enter on a tile chooses it: %s" % face.selected())
	# The controller: the d-pad moves, A chooses.
	var from := _focused()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var pad_moved := _focused()
	_check(pad_moved != null and pad_moved != from,
			"the d-pad moves focus: %s" % (pad_moved.get_meta("focus_key",
				"") if pad_moved else "nothing"))
	face.tiles()["act_lens"].grab_focus()
	await _pad(JOY_BUTTON_A)
	await _frames(2)
	_check(face.selected() == "act_lens", "A chooses: %s" % face.selected())
	# The non-drag equip, pressed from the controller.
	(_button(face.detail_root(), "Equip") as Button).grab_focus()
	var before := BridgeClient.sent_intents.size()
	await _pad(JOY_BUTTON_A)
	await _frames(2)
	var sent := _intents_since(before)
	_check(sent.size() == 1 and sent[0]["component_id"] == "act_lens"
			and sent[0]["slot"] == "utility",
			"A on EQUIP sends it: %s" % [sent])
	await _close()


func _the_mouse() -> void:
	print("  -- the mouse, through the box")
	await _open("base")
	var tile: Button = face.tiles()["act_flask"]
	await _click(_screen_point_of(tile.get_global_rect().get_center()))
	await _frames(2)
	_check(face.selected() == "act_flask",
			"a click on a tile, carried through the 3D stage, chooses it")
	var equip := _button(face.detail_root(), "Equip")
	var before := BridgeClient.sent_intents.size()
	await _click(_screen_point_of(equip.get_global_rect().get_center()))
	await _frames(2)
	var sent := _intents_since(before)
	_check(sent.size() == 1 and sent[0]["component_id"] == "act_flask",
			"a click on REPLACE sends it: %s" % [sent])
	var key := _slot_panel("mobility").find_child("Key", true, false) \
			as Button
	await _click(_screen_point_of(key.get_global_rect().get_center()))
	await _frames(2)
	_check(face.slot_filter() == "mobility",
			"a click on a key shows what goes on it")
	face.set_slot_filter("")
	await _close()


func _turns_and_closes() -> void:
	print("  -- turning away and back, closing and reopening")
	await _open("base")
	await _select("act_bolt")
	await _press(_button(face.detail_root(), "Equip"), "REPLACE")
	await _key(KEY_Q)
	await _rest()
	await _key(KEY_Q)
	await _rest()
	var away := shell.front()
	await _key(KEY_E)
	await _rest()
	await _key(KEY_E)
	await _rest()
	_check(away == "journal" and shell.front() == "equipment"
			and face.selected() == "act_bolt",
			"to the journal and back: still Arc Bolt")
	_check(face.requests.is_pending("echo_a"),
			"a turn neither answers nor drops the request")
	var focus := _focused()
	_check(focus != null and focus.get_meta("focus_key", "") == "tile:act_bolt",
			"and focus is back on its tile")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check(not shell.is_open(), "Escape closes it")
	# The answer arrives while the menu is closed.
	await _deliver("swapped")
	face.open()
	shell.open("equipment")
	await _frames(3)
	_check(face.selected() == "act_bolt" and _holds("echo_a").begins_with(
			"Arc Bolt") and not face.requests.is_pending("echo_a"),
			"reopened: the same item, the key as the bridge left it")
	await _close()


func _an_empty_spare_is_not_offered() -> void:
	print("  -- an empty supply off its key")
	await _open("spent_spare")
	await _select("act_cinder")
	var equip := _button(face.detail_root(), "Equip")
	var texts := _texts(face.detail_root())
	_check(equip != null and equip.disabled and _has(texts, "Empty")
			and _has(texts, "Zone") and _has(texts, "still yours"),
			"a spent spare is not offered, and says a Zone refills it")
	_check(_has(_texts(face.tiles()["act_cinder"]), "0/3"),
			"its tile reads 0/3")
	await _close()
	await _open("exhausted")
	await _select("act_cinder")
	var off := _button(face.detail_root(), "Unequip")
	_check(off != null and not off.disabled
			and not _has(_texts(face.detail_root()), "Empty: there is"),
			"the same supply ON its key at 0 / 3 stays, and can come off")
	await _close()


# ---------------------------------------------------------------------------
# Devices
# ---------------------------------------------------------------------------

## Where on the screen a page pixel of the FRONT wall is drawn.
func _screen_point_of(page_pixel: Vector2) -> Vector2:
	var wall := shell.wall(shell.front())
	var wall_size := shell.wall_size()
	var u := page_pixel.x / float(MenuShell.PAGE_PIXELS.x) - 0.5
	var v := 0.5 - page_pixel.y / float(MenuShell.PAGE_PIXELS.y)
	var world := wall.global_transform \
			* Vector3(u * wall_size.x, v * wall_size.y, 0.0)
	return shell.camera().unproject_position(world)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _rest() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while shell.is_turning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _frames(2)


func _key(code: Key, text := "") -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		if text != "":
			event.unicode = text.unicode_at(0)
		Input.parse_input_event(event)
		await get_tree().process_frame


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await get_tree().process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Screenshots (`make equipment-face-shots`)
# ---------------------------------------------------------------------------

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	EquipmentSeen._reset_for_test()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		await _frames(4)
		await _open("base")
		await _deliver("acquired")
		await _select("act_bolt")
		await _frames(10)
		_save(dir.path_join("equipment_compare_%dx%d.png" % [size.x, size.y]))
		await _select("res_magic")
		face._history_open = true
		face._queue_repaint()
		await _frames(10)
		_save(dir.path_join("equipment_history_%dx%d.png" % [size.x, size.y]))
		face._history_open = false
		face.set_slot_filter("consumable")
		await _frames(10)
		_save(dir.path_join("equipment_consumable_key_%dx%d.png"
				% [size.x, size.y]))
		face.set_slot_filter("")
		await _close()
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	await _open("exhausted")
	await _frames(10)
	_save(dir.path_join("equipment_exhausted_1280x720.png"))
	await _close()
	await _open("base", false)
	await _frames(10)
	_save(dir.path_join("equipment_offline_1280x720.png"))
	await _close()


func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	_check(image.get_width() > 64, "saved %s (%dx%d)" % [path.get_file(),
			image.get_width(), image.get_height()])
