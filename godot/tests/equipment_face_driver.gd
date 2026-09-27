extends Node
## MENU-INT: THE EQUIPMENT WALL AS APPROVED -- C's cabinet with its
## inspection window and selector, D's grafted rack -- asked every question
## the old Control wall answered (H-INVENTORY's nine requirements and the
## archive's own tests), and the ones the integration adds (§6, §12): a
## snapshot landing mid-browse, clearing a key, an answer for another key,
## undo, long lists to their last item, real campaign data, the back
## ladder, and the pointer landing on raised hardware where it is drawn.
##
## Every snapshot is a real one. `equipment_snapshot.json` is built by the
## bridge's own model (`make equipment-fixture`); `bomb_snapshots.json` is
## the owner's candidate campaign played to its first consumable (`make
## bomb-fixture`): 55 to 60 real items, 28 of them always on. Both are
## delivered through `BridgeClient._handle`, the path a websocket frame
## takes. The four walls are mounted exactly as `Main` mounts them.
##
## What the player does goes in as the engine receives it --
## `Input.parse_input_event` for keys, the pad and the mouse -- and a click
## is aimed where the part is DRAWN (`MenuShell.screen_of_node`), after
## checking that the part is what the pointer is over there. What is
## asserted is what the wall shows (its words, as drawn), what it sent
## (`BridgeClient.sent_intents`) and its `state()`.
##
## **Declared harness steps.** `BridgeClient.assume_sent` stands the link
## up or down. A refusal arrives as an `error` frame through `_handle`,
## carrying the `about` key the bridge attaches to a `slot_action` refusal
## (`server.py`'s `_about`, answering N-11). One NOT SENT is
## made by a stub sender, because with the real client a send cannot fail
## while `can_send()` says it would succeed. `face.select` puts the wall on
## an item where a case is not about how it got there.

const FIXTURE := "res://tests/fixtures/equipment_snapshot.json"
## The owner's candidate campaign (H-BOMBS' fixture).
const CAMPAIGN := "res://tests/fixtures/bomb_snapshots.json"
const SHOTS_FLAG := "--shots="
## `--equipment-only=<case>` runs one case, for iterating on it.
const ONLY_FLAG := "--equipment-only="
const CASES := [
	"_one_item_one_module",
	"_the_cabinet",
	"_an_offline_equip_says_so",
	"_pending_then_accepted",
	"_refusals_a_lost_link_and_back",
	"_the_consumable_key",
	"_a_new_item_is_marked",
	"_the_detail_answers",
	"_the_keys_and_always_on",
	"_search_and_sort",
	"_history_and_reads",
	"_a_search_keeps_its_place",
	"_typing_is_not_playing",
	"_keyboard_and_controller",
	"_the_mouse",
	"_turns_and_closes",
	"_an_empty_spare_is_not_offered",
	"_clearing_a_key",
	"_an_answer_for_another_key",
	"_undo_is_another_request",
	"_the_back_ladder",
	"_long_lists_to_the_last_item",
	"_a_snapshot_mid_browse",
	"_real_items_fit",
]

var shell: MenuShell
var face: EquipmentFace
var pause: PauseMenu
var variants: Dictionary = {}
var campaign: Dictionary = {}
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
	_run.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_leaked_keys += 1


func _arg(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag):
			return arg.substr(flag.length())
	return ""


func _run() -> void:
	await get_tree().process_frame
	# A headless window is 64 x 64 whatever project.godot says.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	variants = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	campaign = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN))
	EquipmentSeen._reset_for_test()
	Favourites._reset_for_test()
	shell = MenuShell.new()
	add_child(shell)
	# Mounted exactly as `Main` mounts them.
	pause = PauseMenu.new()
	shell.add_child(pause)
	var settings := SettingsFace.new()
	settings.bind_pause(pause)
	shell.mount("settings", settings)
	face = EquipmentFace.new()
	shell.mount("equipment", face)
	var map := MapFace.new()
	shell.mount("map", map)
	var journal := JournalFace.new()
	journal.bind_map(map)
	shell.mount("journal", journal)
	await get_tree().process_frame
	var shots := _arg(SHOTS_FLAG)
	if shots != "":
		await _shoot(shots)
		_finish("EQUIPMENT FACE SHOTS")
		return
	var only := _arg(ONLY_FLAG)
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

func _deliver(variant: String, source: Dictionary = {}) -> void:
	var from: Dictionary = variants if source.is_empty() else source
	BridgeClient._handle(JSON.stringify(from[variant]))
	await _frames(2)


## Opened as `Main._open_menu` opens it.
func _open(variant: String, online := true, page := "equipment",
		source: Dictionary = {}) -> void:
	BridgeClient.assume_sent = online
	await _deliver(variant, source)
	pause.open(false)
	face.open()
	shell.open(page)
	await _frames(3)


## Between cases: the menu closed, the link down, nothing a case left
## outstanding carried into the next, and the wall back at its first key.
## A request is REAL state -- it survives a close on purpose -- so a case
## that leaves one would otherwise decide the next case's answers.
func _close() -> void:
	shell.close()
	face.close()
	face.requests = EquipRequests.new()
	face._unattributed = ""
	BridgeClient.assume_sent = false
	BridgeClient._in_flight.clear()
	face.set_search("")
	face.set_sort(0)
	face.history_open = false
	face.sel.clear()
	face.anchor.clear()
	face.key_index = 0
	face.zone = "keys"
	face.unfolded = ""
	face.note = ""
	face.typing = false
	await _frames(2)


func _item(source: Dictionary, variant: String, cid: String) -> Dictionary:
	for raw: Variant in source[variant]["inventory"]["items"]:
		if str((raw as Dictionary).get("component_id", "")) == cid:
			return raw
	return {}


func _intents_since(before: int) -> Array:
	return BridgeClient.sent_intents.slice(before)


func _st() -> Dictionary:
	return face.state()


func _focus() -> Dictionary:
	return face.state()["focus"]


func _cap(slot: String) -> String:
	return SlotKeycaps.of(slot).to_upper()


# ---------------------------------------------------------------------------
# Reading the wall
# ---------------------------------------------------------------------------

## Whether a node is on the wall now: in the tree, shown, and not on its
## way out (a rebuilt part is freed at the end of the frame).
func _alive(n: Node) -> bool:
	var at: Node = n
	while at != null:
		if at.is_queued_for_deletion():
			return false
		at = at.get_parent()
	return n.is_inside_tree() and (not (n is Node3D)
			or (n as Node3D).is_visible_in_tree())


## Every word under `root`, in the order drawn, with the no-break spaces
## that keep a unit on its number's line read as the spaces they are.
func _words(root: Node) -> Array:
	var out: Array = []
	if root == null or not is_instance_valid(root):
		return out
	for n: Node in root.find_children("*", "Label3D", true, false):
		if _alive(n):
			out.append((n as Label3D).text.replace(" ", " "))
	return out


func _said(root: Node) -> String:
	return " ".join(_words(root))


## Whether `root` says `sentence` (the wall draws in capitals; a wrapped
## sentence is its lines in order).
func _says(root: Node, sentence: String) -> bool:
	return _said(root).contains(sentence.to_upper().replace(" ", " "))


func _readout() -> Node3D:
	return face._readout


## A change as `_table` sets it: the label, now, the arrow and this in a
## row; or, when now or this is too wide for the row, the label and now,
## and "→ this" under them.
func _change_drawn(label: String, now: String, this: String) -> bool:
	var w := _words(_readout())
	for i in w.size() - 2:
		if w[i] != label.to_upper() or w[i + 1] != now.to_upper():
			continue
		if w[i + 2] == "→ " + this.to_upper():
			return true
		if i + 3 < w.size() and w[i + 2] == "→" and w[i + 3] == this.to_upper():
			return true
	return false


## The pickables alive on the wall for `target`.
func _parts(target: String) -> Array:
	var out: Array = []
	for w: WeakRef in shell.kit._picks.get("equipment", []):
		var n := w.get_ref() as Node3D
		if n != null and is_instance_valid(n) and _alive(n) \
				and str(n.get_meta("pick", "")) == target:
			out.append(n)
	return out


func _part(target: String) -> Node3D:
	var found := _parts(target)
	return null if found.is_empty() else found[0]


## Aim at a part where it is drawn, and press. First the pointer there must
## be over THAT part, nothing drawn in front of it; a case that clicks on
## faith would prove nothing about what a player can reach.
func _click_part(target: String, what: String, node: Node3D = null) -> bool:
	var n := node if node != null else _part(target)
	if n == null:
		_check(false, "%s is on the wall to click (%s)" % [what, target])
		return false
	var at := shell.screen_of_node(n)
	var under := str(shell.pick_at(at).get("target", ""))
	if under != target:
		_check(false, "%s: the pointer where it is drawn (%v) is over '%s', not "
				% [what, at.snapped(Vector2.ONE), under] + "'%s'" % target)
		return false
	await _click(at)
	await _frames(2)
	return true


## The screen rect the front wall's page covers.
func _wall_rect() -> Rect2:
	var a := shell.screen_of(shell.front(), Vector2.ZERO)
	var b := shell.screen_of(shell.front(), Vector2(MenuShell.PAGE_PIXELS))
	return Rect2(a, b - a).abs()


## The words drawn anywhere off the wall's page: a line run past the
## cabinet's edge.
func _off_wall(root: Node) -> Array:
	var out: Array = []
	var wall := _wall_rect().grow(1.0)
	for n: Node in root.find_children("*", "Label3D", true, false):
		if not _alive(n) or (n as Label3D).text.strip_edges() == "":
			continue
		var l := n as Label3D
		var box := l.get_aabb()
		for i in 8:
			var corner := l.global_transform * box.get_endpoint(i)
			if not wall.has_point(shell.camera().unproject_position(corner)):
				out.append(l.text)
				break
	return out


# ---------------------------------------------------------------------------
# R1 -- one item, one module, one way to equip it
# ---------------------------------------------------------------------------

func _one_item_one_module() -> void:
	print("  -- R1: items, not events")
	await _open("swapped")
	var where := {}           # id -> the keys whose rack shows it
	var twice: Array = []
	var wrong: Array = []
	for i in face.key_count():
		await _to_key(i)
		var slot := face.slot_of(i)
		var order: Array = _st()["order"]
		for id: String in order:
			if (where.get(id, []) as Array).has(i):
				twice.append(id)
			if not where.has(id):
				where[id] = []
			(where[id] as Array).append(i)
		for raw: Variant in variants["swapped"]["inventory"]["items"]:
			var row: Dictionary = raw
			var fits := not EquipmentQuery.is_slotted(row) if slot == "" \
					else (row.get("compatible_slots", []) as Array).has(slot)
			var cid := str(row["component_id"])
			if fits != order.has(cid):
				wrong.append("%s on %s" % [cid, slot if slot != "" else "ALWAYS ON"])
	var ids: Array = []
	for raw: Variant in variants["swapped"]["inventory"]["items"]:
		ids.append(str((raw as Dictionary)["component_id"]))
	var shown := where.keys()
	shown.sort()
	ids.sort()
	_check(shown == ids and twice.is_empty() and wrong.is_empty(),
			"every inventory item has a module, once, under the key it goes on "
			+ "(or ALWAYS ON): %d of %d, twice %s, misplaced %s"
			% [shown.size(), ids.size(), twice, wrong])
	var all_words := ""
	for i in face.key_count():
		await _to_key(i)
		all_words += " " + " ".join(_st()["row_words"].values())
	_check(not all_words.contains("LEATHER GRIP"),
			"the upgrade-only Echo is not a module of its own")
	# THE REPRODUCTION'S MEASURE: every equip control on the wall, pressed,
	# and the intents that would put Braided Lash on a key counted.
	face.select("act_lash")
	await _frames(2)
	var controls := _parts("action")
	var before := BridgeClient.sent_intents.size()
	for n: Node3D in controls:
		await _click_part("action", "the action plate", n)
	var offers := 0
	for intent: Dictionary in _intents_since(before):
		if intent.get("component_id") == "act_lash":
			offers += 1
	_check(controls.size() == 1 and offers == 1,
			"one control offers to equip Braided Lash (%d plate), and it "
			% controls.size() + "sends one request, got %d (the old wall had 2)"
			% offers)
	face.requests = EquipRequests.new()
	await _key(KEY_H)
	_check(face.history_open and _says(_readout(),
			"Mk II +4 damage ← Longshot (Ocarina of Time)"),
			"Leather Grip's upgrade is Braided Lash's history instead")
	await _close()


# ---------------------------------------------------------------------------
# R2 -- the cabinet: the keys, the rack, the window
# ---------------------------------------------------------------------------

func _the_cabinet() -> void:
	print("  -- R2: the keys, the rack and the inspection window")
	await _open("base")
	var st := _st()
	var titles: Array = []
	for e: Dictionary in face._keys:
		titles.append((e["title"] as Label3D).text)
	var expected: Array = []
	for slot: String in Constants.SLOT_NAMES:
		expected.append(EquipmentQuery.slot_title(slot).to_upper())
	expected.append("ALWAYS ON")
	_check(titles == expected,
			"a key for each of the game's %d keys, and ALWAYS ON last: %s"
			% [Constants.SLOT_NAMES.size(), titles])
	_check(str(st["windows"][0]).begins_with("BRAIDED LASH")
			and str(st["windows"][1]) == "EMPTY"
			and str(st["windows"][5]) == "NO KEY · 3",
			"each key's window says what the bridge confirmed on it: %s"
			% [st["windows"]])
	_check(st["unfolded"] == "act_lash" and st["order"] == ["act_lash", "act_bolt"],
			"opening on the first key reads what is on it, and its rack holds "
			+ "what fits it, the occupant first: %s" % [st["order"]])
	_check(_says(_readout(), "Braided Lash") and _words(_readout()).has("DOES")
			and _words(_readout()).has("USE") and _words(_readout()).has("COST"),
			"the window reads the item: its name, what it does, how it is used, "
			+ "what it costs")
	_check(_off_wall(face.face).is_empty(),
			"nothing on the cabinet is drawn off the wall: %s" % [_off_wall(face.face)])
	_check(float(st["text_scale_min"]) >= 0.999 and int(st["compositions"]) == 1
			and bool(_focus()["fits"]),
			"no word squashed (%.3f), one readout, and it fits its window"
			% float(st["text_scale_min"]))
	_check(_readout().get_parent() == shell.face_node("equipment")
			and face.face == shell.face_node("equipment"),
			"all of it on the Equipment wall of the box")
	await _close()


# ---------------------------------------------------------------------------
# R3 -- offline, and a send that did not leave
# ---------------------------------------------------------------------------

func _an_offline_equip_says_so() -> void:
	print("  -- R3: no link")
	await _open("base", false)
	face.select("act_bolt")
	await _frames(2)
	_check(_parts("action").is_empty() and str(_focus().get("action_words", ""))
			.begins_with("OFFLINE: A CHANGE OF EQUIPMENT NEEDS THE BRIDGE'S ANSWER"),
			"offline, no action is offered and the window says why: '%s'"
			% _focus().get("action_words", ""))
	var before := BridgeClient.sent_intents.size()
	var state := face.equip_selected()
	await _key(KEY_ENTER)
	_check(state == "" and BridgeClient.sent_intents.size() == before,
			"and neither the call nor ENTER sends anything")
	_check((_st()["notice"] as Array).has(
			"OFFLINE — THE KEYS SHOW WHAT THE BRIDGE LAST CONFIRMED."),
			"the notice on the harness says the link is down: %s" % [_st()["notice"]])
	# A send that fails although the link looked up: the stub sender.
	BridgeClient.assume_sent = true
	face.requests.send("utility", "act_lens",
			func(_intent: Dictionary) -> bool: return false)
	face._refresh_after_request()
	await _frames(2)
	face.select("act_lens")
	await _frames(2)
	_check(str(_st()["windows"][3]).ends_with("✗")
			and _says(_readout(), "✗ NOT SENT — NO LINK TO THE BRIDGE.")
			and _st()["stands"].get("act_lens", "") == "NOT SENT",
			"a send that did not leave is NOT SENT on its key and its module, "
			+ "not silent: '%s'" % _st()["windows"][3])
	await _close()


# ---------------------------------------------------------------------------
# R4 -- pending until the snapshot says so
# ---------------------------------------------------------------------------

func _pending_then_accepted() -> void:
	print("  -- R4: pending, then accepted by a snapshot")
	await _open("base")
	face.select("act_bolt")
	await _frames(2)
	var key := _cap("echo_a")
	_check(str(_focus().get("action_words", "")) == "REPLACE BRAIDED LASH ON %s"
			% key, "the action names the key and what it replaces: '%s'"
			% _focus().get("action_words", ""))
	_check(_says(_readout(), "IF ON %s, IN PLACE OF BRAIDED LASH" % key)
			and _change_drawn("Kind", "projectile damage", "hitscan damage")
			and _change_drawn("Damage", "18", "9")
			and _change_drawn("Range", "—", "40 m")
			and _change_drawn("Cooldown", "1.2 s", "0.8 s")
			and _change_drawn("Mk", "2", "1"),
			"the comparison is against what is on the key, now → this")
	_check(not _says(_readout(), "Pellets") and not _says(_readout(), "Flight time"),
			"and a field only one kind of attack has is not listed as a "
			+ "difference")
	var before := BridgeClient.sent_intents.size()
	await _key(KEY_ENTER)
	var sent := _intents_since(before)
	_check(sent.size() == 1 and sent[0] == {"type": "slot_action",
			"slot": "echo_a", "component_id": "act_bolt"},
			"ENTER sends one slot_action, for Arc Bolt on echo_a: %s" % [sent])
	_check(str(_st()["windows"][0]) == "BRAIDED LASH →",
			"the key still shows what the bridge confirmed, marked sent: '%s'"
			% _st()["windows"][0])
	_check(_says(_readout(), "→ SENT: ARC BOLT ON %s. WAITING FOR THE BRIDGE; %s "
			% [key, key] + "STILL HOLDS BRAIDED LASH.")
			and _st()["stands"].get("act_bolt", "") == "SENT · WAITING"
			and _says(_readout(), "SENT · NOT ON THE KEY YET"),
			"and says the request is waiting, on the module and in the window")
	_check(str(_focus().get("compared", "")) == "act_lash"
			and _change_drawn("Damage", "18", "9"),
			"while it waits, the comparison is still against the confirmed "
			+ "occupant")
	_check(_parts("action").is_empty(),
			"a second request is not offered while it waits")
	await _key(KEY_ENTER)
	_check(BridgeClient.sent_intents.size() == before + 1,
			"and a second ENTER sends nothing")
	await _deliver("base")
	_check(face.requests.is_pending("echo_a"),
			"an unrelated snapshot answers nothing")
	await _deliver("swapped")
	_check(str(_st()["windows"][0]) == "ARC BOLT ✓",
			"the snapshot that carries it moves the key: '%s'" % _st()["windows"][0])
	_check(face.requests.answer("echo_a").get("state") == EquipRequests.ACCEPTED
			and _says(_readout(), "✓ THE BRIDGE CONFIRMED IT: ARC BOLT ON %s." % key),
			"and the request reads ACCEPTED")
	_check(str(_focus().get("action_words", "")) == "TAKE OFF %s" % key,
			"Arc Bolt now offers to come off its key")
	# Unequip is a request too.
	before = BridgeClient.sent_intents.size()
	await _click_part("action", "TAKE OFF")
	sent = _intents_since(before)
	_check(sent.size() == 1 and sent[0]["component_id"] == null
			and face.requests.is_pending("echo_a")
			and str(_st()["windows"][0]) == "ARC BOLT →",
			"TAKE OFF sends a clear, and the key keeps Arc Bolt until it is "
			+ "answered: %s" % [sent])
	await _close()


# ---------------------------------------------------------------------------
# R5 -- refusals, attributed only on an exact key; a lost link; back again
# ---------------------------------------------------------------------------

func _error(message: String, about: String) -> void:
	BridgeClient._handle(JSON.stringify({"type": "error", "scope": "bridge",
			"recoverable": true, "message": message, "about": about}))
	await _frames(2)


func _refusals_a_lost_link_and_back() -> void:
	print("  -- R5: refused, the link lost, and back")
	await _open("base")
	face.select("act_bolt")
	await _frames(2)
	await _key(KEY_ENTER)
	await _error("the bridge is busy", "")
	_check(face.requests.is_pending("echo_a"),
			"an error with no `about` resolves nothing")
	_check((_st()["notice"] as Array).has(
			"THE BRIDGE REFUSED A REQUEST: THE BRIDGE IS BUSY"),
			"it is shown as the bridge's, unattributed: %s" % [_st()["notice"]])
	await _error("not this one", "slot_action:echo_a:act_lash")
	_check(face.requests.is_pending("echo_a"),
			"a refusal naming another request resolves nothing")
	await _error("'act_bolt' is not owned", "slot_action:echo_a:act_bolt")
	_check(face.requests.answer("echo_a").get("state") == EquipRequests.REFUSED
			# the bridge's own words; the wall's font has no underscore, so
			# the id it quotes reads with a space
			and _says(_readout(), "✗ REFUSED — 'act bolt' is not owned")
			and str(_st()["windows"][0]) == "BRAIDED LASH ✗"
			and _st()["stands"].get("act_bolt", "") == "REFUSED",
			"the exact key is REFUSED, with the bridge's reason, on the key, "
			+ "the module and in the window")
	_check(str(_st()["windows"][0]).begins_with("BRAIDED LASH"),
			"and the key never showed Arc Bolt")
	_check(_parts("action").size() == 1,
			"the action is offered again after the refusal")
	await _key(KEY_ENTER)
	BridgeClient.assume_sent = false
	BridgeClient.bridge_state_changed.emit(false)
	await _frames(2)
	_check(face.requests.answer("echo_a").get("state") == EquipRequests.LOST
			and not face.requests.is_pending("echo_a")
			and str(_st()["windows"][0]) == "BRAIDED LASH ?"
			and _says(_readout(), "? THE LINK DROPPED BEFORE THE BRIDGE ANSWERED."),
			"a link lost mid-request is LOST, not pending forever, and says so")
	_check((_st()["notice"] as Array).has(
			"OFFLINE — THE KEYS SHOW WHAT THE BRIDGE LAST CONFIRMED.")
			and _parts("action").is_empty(),
			"offline, the notice says so and no action is offered")
	# BACK: the link returns, and the next snapshot is the truth.
	BridgeClient.assume_sent = true
	BridgeClient.bridge_state_changed.emit(true)
	await _deliver("base")
	_check(str(_st()["windows"][0]).begins_with("BRAIDED LASH")
			and not (_st()["notice"] as Array).has(
				"OFFLINE — THE KEYS SHOW WHAT THE BRIDGE LAST CONFIRMED.")
			and _parts("action").size() == 1
			and _st()["unfolded"] == "act_bolt",
			"reconnected: the key as the bridge says, the notice gone, the "
			+ "action offered again, and still reading Arc Bolt")
	await _close()


# ---------------------------------------------------------------------------
# R6-R8 -- the consumable key's six states
# ---------------------------------------------------------------------------

func _consumable(variant: String, online := true, waiting := false) -> Dictionary:
	BridgeClient.assume_sent = online
	await _deliver(variant)
	if waiting:
		BridgeClient.reserve_consumable("act_cinder")
		BridgeClient.authorize_consumable("act_cinder")
	pause.open(false)
	face.open()
	shell.open("equipment")
	await _frames(3)
	await _to_key(4)
	var out := {"state": str(face._consumable_state()["state"]),
			"window": str(_st()["windows"][4]), "said": _said(_readout()),
			"rack": _said(face._rack), "unfolded": _st()["unfolded"]}
	await _close()
	return out


func _the_consumable_key() -> void:
	print("  -- R6-R8: the consumable key's six states")
	var q := _cap("consumable")
	var none := await _consumable("none_owned")
	var spare := await _consumable("unequipped")
	_check(none["state"] == "none_owned" and none["window"] == "EMPTY"
			and str(none["said"]).contains("NO CONSUMABLE OWNED YET. ONE ARRIVES "
				+ "AS AN ECHO, LIKE ANY OTHER ITEM.")
			and str(none["rack"]).contains("NOTHING YOU HOLD GOES ON %s" % q),
			"none owned says so, and its rack is empty: %s" % none["said"])
	_check(spare["state"] == "owned_not_equipped"
			and str(spare["said"]).contains("NOTHING ON %s. YOU OWN 2 " % q
				+ "CONSUMABLES: PICK ONE TO CARRY."),
			"owned but not equipped says so: %s" % spare["said"])
	_check(none["said"] != spare["said"] and none["rack"] != spare["rack"],
			"and the two read differently (the old key read '—' for both)")
	var empty := await _consumable("exhausted")
	_check(empty["state"] == "equipped_empty"
			and str(empty["window"]).ends_with("0/3")
			and str(empty["said"]).contains("0 OF 3 USES LEFT.")
			and str(empty["said"]).contains("EMPTY. IT STAYS ON %s, AND ENTERING "
				% q + "A ZONE REFILLS IT."),
			"equipped and empty: 0/3 on the key, still on it, and what refills "
			+ "it: %s" % empty["window"])
	var ready := await _consumable("base")
	_check(ready["state"] == "ready" and str(ready["window"]).ends_with("2/3")
			and str(ready["said"]).contains("2 OF 3 USES LEFT."),
			"ready: '%s'" % ready["window"])
	var offline := await _consumable("base", false)
	_check(offline["state"] == "disconnected"
			and str(offline["window"]).ends_with("2/3")
			and str(offline["said"]).contains("OFFLINE: A USE NEEDS THE BRIDGE'S "
				+ "ANSWER, SO NONE CAN BE MADE UNTIL IT IS BACK.")
			and offline["said"] != ready["said"],
			"disconnected says so, the count kept")
	var waiting := await _consumable("base", true, true)
	_check(waiting["state"] == "pending" and str(waiting["window"]).ends_with("1/3")
			and str(waiting["said"]).contains("1 USE WAITING FOR THE BRIDGE'S "
				+ "ANSWER."),
			"a use awaiting the bridge says so, beside the count the HUD shows: "
			+ "'%s'" % waiting["window"])
	var states := [none["state"], spare["state"], empty["state"], ready["state"],
			offline["state"], waiting["state"]]
	_check(states == ["none_owned", "owned_not_equipped", "equipped_empty", "ready",
			"disconnected", "pending"], "all six, each its own: %s" % [states])
	# THE CLIENT'S COUNT AND THE VIEW'S AGREE with nothing in flight: the
	# bridge's `charges_left` and `BridgeClient.charges_left` are two
	# computations of one number.
	for variant: String in ["base", "exhausted", "unequipped", "spent_spare"]:
		await _deliver(variant)
		for cid: String in ["act_cinder", "act_flask"]:
			var item := _item(variants, variant, cid)
			_check(BridgeClient.charges_left(cid)
					== int(item.get("charges_left", -1)),
					"%s %s: the client counts %d, the view %s" % [variant,
					cid, BridgeClient.charges_left(cid),
					item.get("charges_left")])


# ---------------------------------------------------------------------------
# R9 -- the new item says so
# ---------------------------------------------------------------------------

func _a_new_item_is_marked() -> void:
	print("  -- R9: a new item")
	EquipmentSeen._reset_for_test()
	await _open("base")
	await _to_key(4)
	_check((_st()["new"] as Array).is_empty() and not bool(face._keys[4]["new"]),
			"a campaign met for the first time marks nothing new: %s"
			% [_st()["new"]])
	await _deliver("acquired")
	_check(_st()["new"] == ["act_glow"] and bool(face._keys[4]["new"])
			and _said(face._rack).contains("1 NEW"),
			"Glow Seed arrives with a NEW sticker, and only it; the rack counts "
			+ "it and its key's name turns the sticker's yellow: %s" % [_st()["new"]])
	var others := 0
	for i in 4:
		if bool(face._keys[i]["new"]):
			others += 1
	_check(others == 0, "and no other key says it holds something new")
	face.select("act_glow")
	await _frames(2)
	_check((_st()["new"] as Array).is_empty() and not bool(face._keys[4]["new"])
			and not _said(face._rack).contains("NEW"),
			"reading it is noticing it: the sticker comes off")
	await _close()
	# THE CONTROL: the marker is about arrival after the campaign was met,
	# not about the item.
	EquipmentSeen._reset_for_test()
	await _open("acquired")
	await _to_key(4)
	_check((_st()["new"] as Array).is_empty(),
			"met for the first time already holding it, it is not new")
	await _close()


# ---------------------------------------------------------------------------
# What the window says
# ---------------------------------------------------------------------------

func _the_detail_answers() -> void:
	print("  -- the detail")
	await _open("base")
	face.select("act_cinder")
	await _frames(2)
	var q := _cap("consumable")
	# A NUMBER KEEPS ITS UNIT ON ITS LINE: wrapped where the break would
	# fall between them, "1.5" and "s" go down together.
	var kit := face.kit
	var tight := kit.wrap(EquipmentFace._units("after 1.5 s"), 2,
			kit.measure("AFTER 1.5", 2) + 1.0)
	_check(tight.size() == 2 and tight[1].replace("\u00a0", " ") == "1.5 S",
			"a number keeps its unit on its line (a no-break space): %s" % [tight])
	_check(_words(_readout()).has("THROWN: BURSTS FOR 30 DAMAGE WITHIN 3.0 M AFTER "
			+ "1.5 S"), "and is drawn as an ordinary space")
	for line: String in [
			"Thrown: bursts for 30 damage within 3.0 m after 1.5 s",
			"Hits leave burning for 3.0 s",
			"On a key: %s (CONSUMABLE). Press it to use." % q,
			"The status lands on enemies it hits.",
			"2 of 3 uses left.",
			"Cooldown 1 s.",
			"3 uses per supply. Entering a Zone refills it."]:
		_check(_says(_readout(), line), "Cinder Charge: '%s'" % line)
	face.select("trait_ward")
	await _frames(2)
	_check(_says(_readout(), "Only while Arc Bolt is on a key. It is not, so "
			+ "this does nothing right now."),
			"a trait that needs an Action says it is doing nothing now")
	_check(_parts("action").is_empty() and str(_focus().get("action_words", ""))
			.contains("IS ALWAYS ON WHILE YOU OWN IT"),
			"and, being always on, offers no switch and says why")
	await _deliver("swapped")
	face.select("trait_ward")
	await _frames(2)
	_check(_says(_readout(), "Only while Arc Bolt is on a key. It is, on %s."
			% _cap("echo_a")), "with Arc Bolt on its key, it says it is on")
	face.select("act_lens")
	await _frames(2)
	_check(str(_focus().get("action_words", "")) == "EQUIP ON %s" % _cap("utility")
			and _says(_readout(), "NOTHING ON %s TO COMPARE" % _cap("utility")),
			"an empty key's candidate reads EQUIP ON %s, with nothing to "
			% _cap("utility") + "compare: '%s'" % _focus().get("action_words", ""))
	await _close()


# ---------------------------------------------------------------------------
# The keys, ALWAYS ON, search and sort
# ---------------------------------------------------------------------------

func _the_keys_and_always_on() -> void:
	print("  -- the keys and ALWAYS ON")
	await _open("base")
	var on_keys := 0
	for i in 5:
		on_keys += face.candidates(i).size()
	var always := face.candidates(5)
	_check(on_keys == 6 and always.size() == 3,
			"six things go on keys and three are simply on: %d, %s"
			% [on_keys, always])
	await _to_key(5)
	_check(face.slot_of(5) == "" and face.focused_slot() == ""
			and _st()["windows"][5] == "NO KEY · 3",
			"ALWAYS ON is the sixth place to look, not a key: no slot, no keycap")
	_check(_st()["unfolded"] == "" and _says(_readout(), "NO KEY · NOT A SLOT"),
			"and it says so when nothing on it is read")
	var before := BridgeClient.sent_intents.size()
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(_st()["zone"] == "drawer" and _parts("action").is_empty()
			and BridgeClient.sent_intents.size() == before,
			"an always-on item has no action; ENTER on it sends nothing")
	_check(not Constants.SLOT_NAMES.has("always_on")
			and not InputMap.has_action("slot_always_on"),
			"there is no ALWAYS ON slot or bindable action to press")
	face.select("act_lash")
	await _key(KEY_H)
	_check(_says(_readout(), "ALSO FROM THE SAME ECHO Sure Grip (always on)"),
			"the mixed Echo's Action names its other half")
	await _key(KEY_H)
	face.select("trait_grip")
	await _key(KEY_H)
	_check(_says(_readout(), "ALSO FROM THE SAME ECHO Braided Lash (on %s)"
			% _cap("echo_a")), "and its Trait names the Action -- neither half "
			+ "dropped")
	await _key(KEY_H)
	await _close()


func _search_and_sort() -> void:
	print("  -- search and sort")
	await _open("base")
	await _key(KEY_SLASH, "/")
	_check(face.typing and _st()["search"] == "", "/ starts a search")
	for c: String in "shard":
		await _key(OS.find_keycode_from_string(c.to_upper()), c)
	_check(_st()["search"] == "shard" and (_st()["order"] as Array).is_empty(),
			"'shard' finds nothing on the first key")
	_check(_said(face._rack).contains("NOTHING ON %s MATCHES “SHARD”" % _cap("echo_a"))
			and _said(face._rack).contains("IT MATCHES ON: ALWAYS ON"),
			"and says where it does match: %s" % _said(face._rack))
	await _key(KEY_ENTER)
	await _to_key(5)
	_check(_st()["order"] == ["res_magic"],
			"on ALWAYS ON, searching an upgrade's item finds the item it upgraded: "
			+ "%s" % [_st()["order"]])
	face.set_search("ocarina")
	var found: Array = []
	for i in face.key_count():
		for id: String in face.candidates(i):
			found.append(id)
	found.sort()
	_check(found == ["act_cinder", "act_lash", "act_lens", "res_magic", "trait_grip",
			"trait_ward"], "a game's name finds everything from it: %s" % [found])
	face.set_search("zzz")
	await _to_key(0)
	_check(_says(_readout(), "NOTHING HERE MATCHES “ZZZ”.")
			or _said(face._rack).contains("NOTHING ON %s MATCHES “ZZZ”"
				% _cap("echo_a")), "no match says so")
	await _click_part("find_clear", "the search's ✕")
	_check(_st()["search"] == "" and _st()["order"] == ["act_lash", "act_bolt"],
			"✕ clears it, and the rack is whole again")
	# SORT: S, the pad's X, or a click on its window; the occupant first.
	var words: Array = [_st()["sort"]]
	await _key(KEY_S)
	words.append(_st()["sort"])
	await _pad(JOY_BUTTON_X)
	words.append(_st()["sort"])
	await _click_part("sort", "the SORT window")
	words.append(_st()["sort"])
	_check(words == ["AS FOUND", "NEWEST", "NAME A-Z", "BY GAME"],
			"S, X and a click each turn the sort: %s" % [words])
	await _key(KEY_S)
	_check(_st()["sort"] == "AS FOUND", "and it comes round again")
	await _close()


func _history_and_reads() -> void:
	print("  -- history and what Epsilon read")
	await _open("base")
	face.select("res_magic")
	await _frames(2)
	_check(str(_focus().get("history_words", "")).begins_with("HISTORY 2 ▸"),
			"history starts folded, with its count: '%s'"
			% _focus().get("history_words", ""))
	await _click_part("history", "HISTORY")
	var said := _said(_readout())
	var first := said.find("MK I ← MAGIC UPGRADE (OCARINA OF TIME)")
	var second := said.find("MK II +40 MAXIMUM ← ESTUS SHARD (DARK SOULS)")
	_check(face.history_open and first >= 0 and second > first
			and said.count("← ESTUS SHARD") == 1,
			"the whole chain, in order, once, its upgrade in words (the fold's "
			+ "note, N-21)")
	_check(_says(_readout(), "WHAT EPSILON READ")
			and _says(_readout(), "read literal: magic / green / capacity")
			and _says(_readout(), "read mechanical: capacity / shard"),
			"with what Epsilon read for each")
	await _pad(JOY_BUTTON_Y)
	_check(not face.history_open and _says(_readout(), "Magic Meter"),
			"the pad's Y folds it again")
	await _close()


func _a_search_keeps_its_place() -> void:
	print("  -- a search keeps its place across a snapshot")
	await _open("base")
	await _key(KEY_SLASH, "/")
	for c: String in "lash":
		await _key(OS.find_keycode_from_string(c.to_upper()), c)
	var reading: String = _st()["unfolded"]
	_check(face.typing and _st()["search"] == "lash" and _words(face._tools).has("LASH")
			and face._caret != null and _alive(face._caret),
			"typing 'lash' onto the FIND tape, the caret after it")
	await _deliver("acquired")
	_check(face.typing and _st()["search"] == "lash" and _st()["unfolded"] == reading
			and _st()["key"] == 0 and _words(face._tools).has("LASH")
			and face._caret != null and _alive(face._caret),
			"a snapshot mid-search keeps the typing, the text and the item read")
	await _key(KEY_ESCAPE)
	await _close()


# ---------------------------------------------------------------------------
# Input, as the engine receives it
# ---------------------------------------------------------------------------

func _typing_is_not_playing() -> void:
	print("  -- typing Q, C, E and Tab into a search")
	await _open("base")
	await _click_part("find", "the FIND tape")
	_check(face.typing, "a click on the FIND tape starts a search")
	var before := BridgeClient.sent_intents.size()
	var leaked := _leaked_keys
	await _key(KEY_Q, "q")
	await _key(KEY_C, "c")
	await _key(KEY_E, "e")
	await _key(KEY_TAB)
	await _frames(2)
	_check(_st()["search"] == "qce" and shell.front() == "equipment"
			and not shell.is_turning() and shell.is_open(),
			"the letters go onto the tape ('%s'); the box neither turns nor "
			% _st()["search"] + "closes")
	_check(BridgeClient.sent_intents.size() == before,
			"no intent left: no consumable (Q), no utility (C)")
	_check(_leaked_keys == leaked,
			"and no key event got past the shell to the game (%d leaked)"
			% (_leaked_keys - leaked))
	await _key(KEY_BACKSPACE)
	_check(_st()["search"] == "qc", "Backspace takes one out")
	await _key(KEY_ESCAPE)
	_check(not face.typing and shell.is_open() and _st()["search"] == "qc",
			"Escape stops typing and keeps the menu open")
	await _close()


func _keyboard_and_controller() -> void:
	print("  -- keyboard and controller")
	await _open("base", true, "settings")
	await _key(KEY_Q)
	await _rest()
	_check(shell.front() == "equipment", "Q turns Settings to Equipment")
	_check(_st()["zone"] == "keys" and _st()["key"] == 0
			and is_equal_approx(float(_st()["pointer_at"]),
				float(_st()["pointer_to"])),
			"arriving, the selector points at the first key")
	await _key(KEY_DOWN)
	await _until(func() -> bool: return is_equal_approx(float(_st()["pointer_at"]),
			float(_st()["pointer_to"])))
	_check(_st()["key"] == 1 and is_equal_approx(float(_st()["pointer_at"]),
			float(_st()["pointer_to"])), "an arrow turns the selector one detent")
	await _key(KEY_RIGHT)
	_check(_st()["zone"] == "keys", "an empty key's rack is not entered")
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_RIGHT)
	_check(_st()["key"] == 3 and _st()["zone"] == "drawer"
			and _st()["unfolded"] == "act_lens" and _st()["out"] == ["act_lens"],
			"into the utility rack: its first module pulled and read")
	var before := BridgeClient.sent_intents.size()
	await _key(KEY_ENTER)
	var sent := _intents_since(before)
	_check(sent.size() == 1 and sent[0]["slot"] == "utility"
			and sent[0]["component_id"] == "act_lens",
			"ENTER in the rack takes its action: %s" % [sent])
	# The controller: the d-pad moves, A goes in and acts, B backs out.
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_DPAD_UP)
	_check(_st()["zone"] == "keys" and _st()["key"] == 2,
			"the d-pad backs out of the rack and turns the selector")
	await _pad(JOY_BUTTON_A)
	_check(_st()["zone"] == "drawer" and _st()["unfolded"] == "act_dash",
			"A goes into the rack")
	_check(face.kit.device == "pad" and str(_focus().get("cap", "")) == "pad_face_south",
			"and the action's control is drawn as the pad's A")
	before = BridgeClient.sent_intents.size()
	await _pad(JOY_BUTTON_A)
	sent = _intents_since(before)
	_check(sent.size() == 1 and sent[0]["slot"] == "mobility"
			and sent[0]["component_id"] == null,
			"A on what is on the key takes it off (a request): %s" % [sent])
	await _pad(JOY_BUTTON_B)
	_check(shell.is_open() and _st()["zone"] == "keys", "B backs out to the keys")
	await _pad(JOY_BUTTON_B)
	_check(not shell.is_open(), "and B again closes the menu")
	await _close()


func _the_mouse() -> void:
	print("  -- the mouse, on the hardware where it is drawn")
	await _open("base")
	await _click_part("key:4", "the consumable key's window")
	_check(_st()["key"] == 4 and _st()["zone"] == "keys",
			"a click on a key's window turns the selector to it")
	var module := _part("row:act_flask")
	await _click_part("row:act_flask", "Flask's module", module)
	await _until(func() -> bool: return _st()["out"] == ["act_flask"])
	_check(_st()["unfolded"] == "act_flask" and _st()["zone"] == "drawer"
			and _st()["out"] == ["act_flask"],
			"a click on a module reads it and pulls it out, and puts the one "
			+ "read before back")
	# RAISED HARDWARE: the pulled module stands out of the rack and to the
	# left; its tab stands proud of that. Each is hit where it is drawn.
	var tabs: Array = []
	for n: Node3D in _parts("row:act_flask"):
		if n != module:
			tabs.append(n)
	var tab: Node3D = tabs[0] if not tabs.is_empty() else null
	var at := shell.screen_of_node(tab) if tab != null else Vector2.ZERO
	var plane := shell.page_point(at)
	_check(tab != null and str(shell.pick_at(at).get("target", "")) == "row:act_flask",
			"the pulled module's raised tab is under the pointer where it is "
			+ "drawn (%v; the wall's plane there is page %v)"
			% [at.snapped(Vector2.ONE), plane.snapped(Vector2.ONE)])
	var before := BridgeClient.sent_intents.size()
	await _click_part("action", "REPLACE")
	var sent := _intents_since(before)
	_check(sent.size() == 1 and sent[0]["component_id"] == "act_flask",
			"a click on the action plate sends it: %s" % [sent])
	# Hover lights and never moves: the module under the pointer stays home.
	var cinder := _part("row:act_cinder")
	var home := (cinder.get_parent() as Node3D).position if cinder != null \
			else Vector3.ONE
	await _move(shell.screen_of_node(cinder) if cinder != null else Vector2.ZERO)
	await _frames(4)
	_check(cinder != null and face.hovered == "row:act_cinder"
			and (cinder.get_parent() as Node3D).position == home
			and _st()["out"] == ["act_flask"],
			"hovering a module lights it and moves nothing")
	await _click_part("key:0", "the first key's window")
	await _click_part("key:0", "the first key's window, again")
	_check(_st()["key"] == 0 and _st()["zone"] == "keys",
			"a click on the key already looked at keeps it")
	await _close()


func _turns_and_closes() -> void:
	print("  -- turning away and back, closing and reopening")
	await _open("base")
	face.select("act_bolt")
	await _frames(2)
	await _key(KEY_ENTER)
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
			and _st()["unfolded"] == "act_bolt" and _st()["zone"] == "drawer",
			"to the journal and back: still reading Arc Bolt, in the rack")
	_check(face.requests.is_pending("echo_a"),
			"a turn neither answers nor drops the request")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check(not shell.is_open(), "Escape backs out of the rack, then closes")
	# The answer arrives while the menu is closed.
	await _deliver("swapped")
	pause.open(false)
	face.open()
	shell.open("equipment")
	await _frames(3)
	_check(_st()["unfolded"] == "act_bolt" and str(_st()["windows"][0]) == "ARC BOLT"
			and not face.requests.is_pending("echo_a"),
			"reopened: the same item, the key as the bridge left it: '%s'"
			% _st()["windows"][0])
	await _close()


func _an_empty_spare_is_not_offered() -> void:
	print("  -- an empty supply off its key")
	await _open("spent_spare")
	face.select("act_cinder")
	await _frames(2)
	_check(_parts("action").is_empty() and str(_focus().get("action_words", ""))
			== "EMPTY: THERE IS NOTHING TO THROW UNTIL ENTERING A ZONE REFILLS IT. "
				+ "IT IS STILL YOURS.",
			"a spent spare is not offered, and says a Zone refills it: '%s'"
			% _focus().get("action_words", ""))
	_check(str(_st()["row_words"].get("act_cinder", "")).ends_with("0/3"),
			"its module reads 0/3: '%s'" % _st()["row_words"].get("act_cinder", ""))
	await _close()
	await _open("exhausted")
	face.select("act_cinder")
	await _frames(2)
	_check(_parts("action").size() == 1 and str(_focus().get("action_words", ""))
			== "TAKE OFF %s" % _cap("consumable"),
			"the same supply ON its key at 0/3 stays, and can come off")
	await _close()


# ---------------------------------------------------------------------------
# §6 and §12: what the integration adds
# ---------------------------------------------------------------------------

func _clearing_a_key() -> void:
	print("  -- clearing a key")
	await _open("base")
	_check(not _parts("clear:0").is_empty() and _parts("clear:1").is_empty()
			and _parts("clear:4").is_empty(),
			"the key looked at has a ✕ when something is on it; the others none")
	await _to_key(4)
	var holds := str(_st()["windows"][4])
	var before := BridgeClient.sent_intents.size()
	await _click_part("clear:4", "the consumable key's ✕")
	var sent := _intents_since(before)
	_check(sent == [{"type": "slot_action", "slot": "consumable", "component_id": null}]
			and str(_st()["windows"][4]) == holds + " →"
			and _parts("clear:4").is_empty(),
			"✕ sends a clear through the same request; the key keeps what the "
			+ "bridge confirmed until it answers: %s" % [sent])
	await _to_key(2)
	before = BridgeClient.sent_intents.size()
	await _key(KEY_DELETE)
	sent = _intents_since(before)
	_check(sent == [{"type": "slot_action", "slot": "mobility", "component_id": null}],
			"Delete on a key clears it the same way: %s" % [sent])
	await _to_key(1)
	before = BridgeClient.sent_intents.size()
	var edges := int(face.kit.cue_counts.get("edge", 0))
	await _key(KEY_DELETE)
	_check(BridgeClient.sent_intents.size() == before
			and int(face.kit.cue_counts.get("edge", 0)) == edges + 1,
			"an empty key has nothing to clear: Delete sends nothing, and says so")
	# The bridge's snapshot with the consumable key cleared (and Sprint Coil
	# still on its key: that clear is not answered by it).
	await _deliver("unequipped")
	_check(str(_st()["windows"][4]) == "EMPTY ✓"
			and str(_st()["windows"][2]).ends_with(" →")
			and face.requests.is_pending("mobility"),
			"the snapshot that carries a clear empties that key alone: %s, %s"
			% [_st()["windows"][4], _st()["windows"][2]])
	await _close()


func _an_answer_for_another_key() -> void:
	print("  -- an answer for one key does not move another's reading")
	await _open("base")
	face.select("act_bolt")
	await _frames(2)
	await _key(KEY_ENTER)
	face.select("act_lens")
	await _frames(2)
	var before := {"key": _st()["key"], "zone": _st()["zone"],
			"unfolded": _st()["unfolded"], "first": _st()["first"]}
	await _error("'act_bolt' is not owned", "slot_action:echo_a:act_bolt")
	var after := {"key": _st()["key"], "zone": _st()["zone"],
			"unfolded": _st()["unfolded"], "first": _st()["first"]}
	_check(after == before and str(_st()["windows"][0]) == "BRAIDED LASH ✗"
			and _says(_readout(), "Scan Lens"),
			"a refusal for the first key while reading the utility key: the "
			+ "reading stays %s; the first key's window says ✗" % [after])
	face.select("act_bolt")
	await _frames(2)
	await _key(KEY_ENTER)
	face.select("act_lens")
	await _frames(2)
	await _deliver("swapped")
	after = {"key": _st()["key"], "zone": _st()["zone"],
			"unfolded": _st()["unfolded"], "first": _st()["first"]}
	_check(after == before and str(_st()["windows"][0]) == "ARC BOLT ✓"
			and _says(_readout(), "Scan Lens"),
			"and an acceptance for it lands on its key alone: %s" % [after])
	await _close()


func _undo_is_another_request() -> void:
	print("  -- undo is another request")
	await _open("base")
	face.select("act_bolt")
	await _frames(2)
	await _key(KEY_ENTER)
	await _deliver("swapped")
	face.select("act_lash")
	await _frames(2)
	_check(str(_focus().get("action_words", "")) == "PUT BACK ON %s" % _cap("echo_a")
			and _st()["stands"].get("act_lash", "") == "WAS ON %s" % _cap("echo_a"),
			"what the key held before is offered back: '%s'"
			% _focus().get("action_words", ""))
	var before := BridgeClient.sent_intents.size()
	await _key(KEY_ENTER)
	var sent := _intents_since(before)
	_check(sent == [{"type": "slot_action", "slot": "echo_a",
			"component_id": "act_lash"}] and str(_st()["windows"][0]) == "ARC BOLT →",
			"PUT BACK sends a request of its own, and the key waits for it: %s"
			% [sent])
	await _close()
	await _open("swapped")
	face.select("act_lash")
	await _frames(2)
	_check(str(_focus().get("action_words", "")) == "REPLACE ARC BOLT ON %s"
			% _cap("echo_a"), "the next visit has no undo to offer")
	await _close()


func _back_prompt() -> String:
	for p: Dictionary in shell.prompts_shown():
		if str(p["action"]) in ["back", "close"] and "key:ESC" in p["shows"]:
			return str(p["words"])
	return ""


func _the_back_ladder() -> void:
	print("  -- the back ladder: each Escape says what it does, then does it")
	await _open("base")
	face.select("res_magic")
	await _frames(2)
	await _key(KEY_H)
	await _key(KEY_SLASH, "/")
	var said: Array = []
	var did: Array = []
	for step in 4:
		said.append([shell.back_words(), _back_prompt()])
		await _key(KEY_ESCAPE)
		did.append([face.typing, face.history_open, _st()["zone"], shell.is_open()])
	_check(said == [["stop typing", "STOP TYPING"], ["close history", "CLOSE HISTORY"],
			["keys", "KEYS"], ["close", "CLOSE"]],
			"the prompt says what the next Escape does: %s" % [said])
	_check(did == [[false, true, "drawer", true], [false, false, "drawer", true],
			[false, false, "keys", true], [false, false, "keys", false]],
			"and it does it: typing, then HISTORY, then the rack, then the menu")
	await _close()


func _long_lists_to_the_last_item() -> void:
	print("  -- a long rack on real data, to its last item and back")
	await _open("carried", true, "equipment", campaign)
	await _to_key(5)
	await _key(KEY_RIGHT)
	var count := int(_st()["count"])
	var inside := true
	for i in count + 1:
		if not bool(_st()["card_inside"]):
			inside = false
		await _key(KEY_DOWN)
	var last: String = (_st()["order"] as Array)[count - 1]
	_check(count == 28 and _st()["unfolded"] == last and inside
			and int(_st()["first"]) == count - EquipmentFace.SHOWN,
			"ALWAYS ON's %d, walked with the keyboard to the last: always in "
			% count + "view, the rack scrolled to its end (first %d)"
			% int(_st()["first"]))
	_check(str(_st()["more"][0]) == "%d MORE ABOVE" % (count - EquipmentFace.SHOWN)
			and str(_st()["more"][1]) == "",
			"and it says how many are above: %s" % [_st()["more"]])
	var edges := int(face.kit.cue_counts.get("edge", 0))
	await _key(KEY_DOWN)
	_check(_st()["unfolded"] == last and int(face.kit.cue_counts.get("edge", 0)) > edges,
			"past the last there is nothing, and it says so (the edge)")
	# BY HAND: the wheel scrolls the rack and leaves the reading alone.
	var over := _part("row:" + last)
	var at := shell.screen_of_node(over)
	for i in 3:
		await _wheel(at, -1)
	_check(int(_st()["first"]) == count - EquipmentFace.SHOWN - 3
			and _st()["unfolded"] == last and not bool(_st()["card_inside"]),
			"three notches of the wheel scroll three rows; the last is still "
			+ "read, out of view")
	await _key(KEY_UP)
	_check(bool(_st()["card_inside"])
			and _st()["unfolded"] == (_st()["order"] as Array)[count - 2],
			"the keyboard brings the reading back into view")
	# THE RIGHT STICK scrolls the same rows.
	var first := int(_st()["first"])
	face.scroll_by(-EquipmentFace.ROW_PITCH * 2.0)
	await _frames(2)
	_check(int(_st()["first"]) == first - 2, "the right stick scrolls by rows too")
	# EMPTY: a key nothing fits.
	await _key(KEY_LEFT)
	await _to_key(1)
	_check((_st()["order"] as Array).is_empty()
			and _said(face._rack).contains("NOTHING YOU HOLD GOES ON %s" % _cap("echo_b")),
			"an empty rack says so")
	await _close()


func _a_snapshot_mid_browse() -> void:
	print("  -- a snapshot landing mid-browse, on real data")
	EquipmentSeen._reset_for_test()
	await _open("carried", true, "equipment", campaign)
	await _to_key(2)
	await _key(KEY_RIGHT)
	for i in 30:
		await _key(KEY_DOWN)
	var st := _st()
	var reading: String = st["unfolded"]
	var top: String = (st["order"] as Array)[int(st["first"])]
	_check(int(st["count"]) == 16 and reading == (st["order"] as Array)[15],
			"browsing mobility's 16 to the last")
	await _deliver("refilled", campaign)
	st = _st()
	var arrived: Array = []
	for id: String in st["order"]:
		if _item(campaign, "carried", id).is_empty():
			arrived.append(id)
	_check(int(st["count"]) == 19 and st["unfolded"] == reading and int(st["key"]) == 2
			and st["zone"] == "drawer"
			and (st["order"] as Array)[int(st["first"])] == top,
			"three more arrive: the same item read, the same key, the rack's "
			+ "first row the same item (%s)" % top)
	_check(arrived.size() == 3 and _said(face._rack).contains("3 NEW"),
			"the rack counts the arrivals as new: %s" % [arrived])
	# Scrolled to by hand (reading nothing), they carry their stickers.
	var at := shell.screen_of_node(_part("row:" + reading))
	for i in 3:
		await _wheel(at, 1)
	st = _st()
	var stuck := true
	for id: String in arrived:
		if not (st["shown"] as Array).has(id) or not (st["new"] as Array).has(id):
			stuck = false
	_check(stuck and st["unfolded"] == reading,
			"scrolled into view by hand, each wears a NEW sticker; the reading "
			+ "is unchanged: %s" % [st["new"]])
	await _close()


func _real_items_fit() -> void:
	print("  -- every real item's reading fits, unsquashed, on the wall")
	EquipmentSeen._reset_for_test()
	await _open("refilled", true, "equipment", campaign)
	var missing_before: Dictionary = face.kit.missing.duplicate()
	var bad: Array = []
	var worst := 0
	var read := 0
	for i in face.key_count():
		for id: String in face.candidates(i):
			var t0 := Time.get_ticks_usec()
			face.select(id)
			worst = maxi(worst, Time.get_ticks_usec() - t0)
			await get_tree().process_frame
			read += 1
			var st := _st()
			var off := _off_wall(_readout())
			if not bool(_focus().get("fits", false)) \
					or float(st["text_scale_min"]) < 0.999 or not off.is_empty() \
					or int(st["compositions"]) != 1:
				bad.append("%s fits=%s scale=%s off=%s" % [id, _focus().get("fits"),
						st["text_scale_min"], off])
	_check(read >= 55 and bad.is_empty(),
			"all %d real items read in their window without running over, " % read
			+ "squashing or stacking: %s" % [bad])
	var new_missing: Array = []
	for c: String in face.kit.missing:
		if not missing_before.has(c):
			new_missing.append("%s in '%s'" % [c, face.kit.missing_where.get(c, "")])
	_check(new_missing.is_empty(),
			"and every character of them is in the wall's font: %s" % [new_missing])
	var t1 := Time.get_ticks_usec()
	face.rebuild()
	var rebuild := Time.get_ticks_usec() - t1
	_note("on the candidate campaign's %d items: a rebuild took %.1f ms, the "
			% [read, rebuild / 1000.0] + "slowest reading %.1f ms (headless)"
			% (worst / 1000.0))
	_check(rebuild < 1000000 and worst < 500000,
			"nothing on the wall takes a pathological time to build")
	await _close()


# ---------------------------------------------------------------------------
# Devices
# ---------------------------------------------------------------------------

## Turn the selector to key `i` from the keyboard, the way a player does.
func _to_key(i: int) -> void:
	if face.zone != "keys":
		await _key(KEY_LEFT)
	var guard := 0
	while face.key_index != i and guard < 8:
		await _key(KEY_DOWN if i > face.key_index else KEY_UP)
		guard += 1
	await _frames(1)


## Wait, up to a second, for `done` to hold.
func _until(done: Callable, ms := 1000) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while not bool(done.call()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame


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


func _move(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await get_tree().process_frame


func _click(at: Vector2) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _wheel(at: Vector2, dir: int) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if dir < 0 \
				else MOUSE_BUTTON_WHEEL_DOWN
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


# ---------------------------------------------------------------------------
# Screenshots (`make equipment-face-shots`, under the game's renderer)
# ---------------------------------------------------------------------------

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	EquipmentSeen._reset_for_test()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		await _frames(4)
		await _open("base")
		await _deliver("acquired")
		face.select("act_bolt")
		await _frames(10)
		_save(dir.path_join("equipment_compare_%dx%d.png" % [size.x, size.y]))
		await _key(KEY_ENTER)
		await _frames(10)
		_save(dir.path_join("equipment_pending_%dx%d.png" % [size.x, size.y]))
		face.select("res_magic")
		await _key(KEY_H)
		await _frames(10)
		_save(dir.path_join("equipment_history_%dx%d.png" % [size.x, size.y]))
		await _key(KEY_H)
		await _to_key(4)
		await _frames(10)
		_save(dir.path_join("equipment_consumable_key_%dx%d.png" % [size.x, size.y]))
		await _close()
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	await _open("exhausted")
	await _to_key(4)
	await _frames(10)
	_save(dir.path_join("equipment_exhausted_1280x720.png"))
	await _close()
	await _open("base", false)
	await _frames(10)
	_save(dir.path_join("equipment_offline_1280x720.png"))
	await _close()
	await _open("refilled", true, "equipment", campaign)
	await _to_key(5)
	await _key(KEY_RIGHT)
	for i in 12:
		await _key(KEY_DOWN)
	await _frames(10)
	_save(dir.path_join("equipment_campaign_always_on_1280x720.png"))
	await _close()


func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	_check(image.get_width() > 64, "saved %s (%dx%d)" % [path.get_file(),
			image.get_width(), image.get_height()])
