extends Node
## MENU-INT: THE JOURNAL WALL AND THE SETTINGS WALL AS APPROVED -- B's
## journal on its harness, C's salvaged boards -- on the real shell
## (`--journal-face`).
##
##     make godot-journal-face
##
## The four walls are mounted exactly as `Main` mounts them: the pause
## menu's switches on SettingsFace's PAUSED board, the Map bound to the
## candidate Zone (built for real, so a real player's camera is the one
## the field of view reaches), the Journal bound to the Map. Snapshots
## arrive through `BridgeClient._handle`, the path a real one takes, and
## are the model's own (`journal_snapshot.json`, `make journal-fixture`).
##
## Every guarantee of H-JOURNAL's suite is kept: objectives in the Hub's
## own words, what was done and what it opened, nothing unfound named,
## what is still shut and why, places, earned notes, the wall following
## the snapshot, the pause menu's actions and the Abandon warning, the
## options doing what they say. Added (§7, §8): the identity rows and the
## strings are one list; a link is by id, followed onto the Map and back;
## a passage that vanishes is explained and unlinked; the Journal->Map
## wire; Hub and Zone action sets; the Abandon guard; held-direction
## acceleration; MOTION at once; Epsilon never a control.
##
## **What each check expects is worked out here from the snapshot**, never
## by asking `JournalQuery`: a rule tested against itself proves nothing.
##
## **Declared harness steps.** `user://settings.cfg` is saved before the
## options cases and put back byte for byte after them. QUIT GAME's
## `get_tree().quit()` is stood in for (`set_quit_for_test`).

const FIXTURE := "res://tests/fixtures/journal_snapshot.json"
const MAPS := "res://tests/fixtures/map_snapshot.json"
const CANDIDATE := "res://tests/fixtures/candidate_zone.json"

var shell: MenuShell
var journal: JournalFace
var settings: SettingsFace
var pause_menu: PauseMenu
var map_face: MapFace
var zone: ZoneController
var variants: Dictionary = {}
## Every room's name, from the map of the fully walked Zone: what an
## unfound room would be called, so the suite can look for leaks.
var all_names := {}
var _checks := 0
var _failures := 0
var _notes := 0
var _signals: Array = []
var _saved_settings := PackedByteArray()
var _had_settings := false


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


func _run() -> void:
	await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	variants = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var maps: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(MAPS))
	for raw: Variant in maps["all_rooms"]["zone_map"]["rooms"]:
		all_names[str(raw["room_id"])] = str(raw["name"])
	zone = ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	zone.add_child(pool)
	get_tree().root.add_child(zone)
	zone.setup(JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE)))
	shell = MenuShell.new()
	add_child(shell)
	# Mounted exactly as `Main` mounts them.
	pause_menu = PauseMenu.new()
	shell.add_child(pause_menu)
	pause_menu.set_quit_for_test(func() -> void: _signals.append("quit"))
	for sig: String in ["resumed", "return_to_hub_requested", "abandon_confirmed"]:
		pause_menu.connect(sig, func() -> void: _signals.append(sig))
	settings = SettingsFace.new()
	settings.bind_pause(pause_menu)
	shell.mount("settings", settings)
	shell.mount("equipment", EquipmentFace.new())
	map_face = MapFace.new()
	shell.mount("map", map_face)
	journal = JournalFace.new()
	journal.bind_map(map_face)
	shell.mount("journal", journal)
	map_face.bind(zone)
	await _frames(3)
	var shots := _arg("--shots=")
	if shots != "":
		var size := _arg("--shots-size=").split("x")
		if size.size() == 2:
			get_window().size = Vector2i(int(size[0]), int(size[1]))
		await _frames(3)
		await _shoot(shots)
		_finish("JOURNAL FACE SHOTS")
		return
	await _the_walls_are_filled()
	await _objectives()
	await _what_you_did_here()
	await _nothing_unfound_is_named()
	await _still_shut()
	await _places()
	await _notes_are_earned()
	await _rows_and_strings_are_one_list()
	await _it_follows_the_snapshot()
	await _show_it_on_the_map_and_back()
	await _a_passage_that_vanishes()
	await _the_journal_keys()
	await _the_settings_wall()
	await _hub_and_zone_actions()
	await _abandon_asks_first()
	_keep_settings()
	await _the_options_do_what_they_say()
	await _a_held_direction_speeds_up()
	await _motion_at_once()
	await _epsilon_is_not_a_control()
	_put_settings_back()
	await _open_and_close_again()
	_finish("GODOT JOURNAL FACE")


func _finish(what: String) -> void:
	shell.close()
	print("")
	if _failures == 0:
		print("%s OK (%d checks, %d notes)" % [what, _checks, _notes])
		get_tree().quit(0)
		return
	print("%s TESTS: %d failures in %d checks" % [what, _failures, _checks])
	get_tree().quit(1)


func _arg(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag):
			return arg.substr(flag.length())
	return ""


# ---------------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while (shell.kit.busy() or shell.is_turning()) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _frames(2)


func _deliver(variant: String) -> void:
	BridgeClient._handle(JSON.stringify(variants[variant]))
	await _frames(2)


## Opened as `Main._open_menu` opens it.
func _open(page: String, in_zone := true) -> void:
	pause_menu.open(in_zone)
	shell.open(page)
	await _frames(3)
	await _settle()


func _key(code: Key, echo := false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		event.echo = echo and down
		Input.parse_input_event(event)
		await get_tree().process_frame


## A key held: its press, `repeats` echoes, then its release.
func _hold_key(code: Key, repeats: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	for i in repeats:
		var again := event.duplicate() as InputEventKey
		again.echo = true
		Input.parse_input_event(again)
		await get_tree().process_frame
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _click(at: Vector2, double := false) -> void:
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
		event.double_click = double and down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


## Aim at a part of the front wall where it is drawn -- checked to be what
## the pointer is over there -- and press.
func _click_part(page: String, target: String, what: String, double := false) -> bool:
	var node := shell.kit.targets(page).get(target) as Node3D
	if node == null:
		_check(false, "%s is on the wall to click (%s)" % [what, target])
		return false
	var at := shell.screen_of_node(node)
	var under := str(shell.pick_at(at).get("target", ""))
	if under != target:
		_check(false, "%s: the pointer where it is drawn is over '%s', not '%s'"
				% [what, under, target])
		return false
	await _click(at, double)
	await _frames(2)
	return true


func _discovered(variant: String) -> Dictionary:
	var out := {}
	for raw: Variant in variants[variant]["zone_map"]["rooms"] \
			if variants[variant].get("zone_map") != null else []:
		if bool(raw["discovered"]):
			out[str(raw["room_id"])] = str(raw["name"])
	return out


func _has(lines: Array, text: String) -> bool:
	for line: String in lines:
		if line.contains(text):
			return true
	return false


## Every word drawn under a node, in order.
func _words(root: Node) -> Array:
	var out: Array = []
	for n: Node in root.find_children("*", "Label3D", true, false):
		var dead := false
		var at: Node = n
		while at != null:
			dead = dead or at.is_queued_for_deletion()
			at = at.get_parent()
		if not dead and (n as Label3D).is_visible_in_tree():
			out.append((n as Label3D).text)
	return out


# ---------------------------------------------------------------------------
# The journal
# ---------------------------------------------------------------------------

func _the_walls_are_filled() -> void:
	print("  -- the walls are filled")
	var mounted: Array = []
	for page: String in MenuShell.PAGES:
		if shell.controller(page) != null:
			mounted.append(page)
	_check(mounted == MenuShell.PAGES and shell.controller("journal") == journal
			and shell.controller("settings") == settings,
			"all four walls hold their faces: %s" % [mounted])


## §8: "real active objectives". The Hub's own words in the Hub; in a
## Zone, the Zone and its Checks, counted here from the snapshot.
func _objectives() -> void:
	print("  -- objectives")
	await _deliver("hub")
	var hub: Dictionary = variants["hub"]["hub"]
	var said := journal.section("OBJECTIVES")
	_check(said.size() >= 2 and said[0] == hub["headline"]
			and said[1] == hub["detail"],
			"in the Hub: the Hub's own headline and detail, word for word: "
			+ "%s" % [said])
	_check(_has(said, "%d of %d" % [int(hub["finale_progress"]),
			int(hub["finale_required"])]),
			"and the finale's count, %d of %d" % [int(hub["finale_progress"]),
				int(hub["finale_required"])])
	await _deliver("progressed")
	var snap: Dictionary = variants["progressed"]
	var here: Array = snap["active_zone"]["allocated_location_ids"]
	var checked := {}
	for loc: Variant in snap["checked_location_ids"]:
		checked[int(loc)] = true
	var got := here.filter(func(l: Variant) -> bool:
		return checked.has(int(l))).size()
	said = journal.section("OBJECTIVES")
	var zone_name := str(snap["active_zone"]["zone"]["display_name"])
	_check(_has(said, zone_name) and _has(said, "%d of %d confirmed" % [got,
			here.size()]),
			"in a Zone: its name and its Checks, %d of %d confirmed: %s"
			% [got, here.size(), said])
	_check(not _has(said, str(snap["hub"]["detail"])),
			"and not the Hub's 'step back through the portal' while in it")


## §8: "completed consequences" -- each from the Zone's record, with what
## it opened; and nothing the record does not hold.
func _what_you_did_here() -> void:
	print("  -- what you did here")
	await _deliver("arrived")
	_check(journal.section("WHAT YOU DID HERE") == ["Nothing yet."],
			"arrived: nothing yet: %s" % [journal.section("WHAT YOU DID HERE")])
	await _deliver("progressed")
	var done := journal.section("WHAT YOU DID HERE")
	var progress: Dictionary = variants["progressed"]["active_zone"]["progress"]
	var names := _discovered("progressed")
	var expected: Array = []
	for key: Variant in progress["collected_keys"]:
		expected.append("Picked up the %s key." % str(key))
	expected.append("Unlocked the blue door in %s." % names["c005"])
	expected.append("Installed the power cell in %s." % names["c005"])
	var missing: Array = expected.filter(func(e: Variant) -> bool:
		return not done.has(e))
	_check(missing.is_empty(), "the keys, the blue door and the cell, "
			+ "each in the room it happened in: missing %s from %s"
			% [missing, done])
	_check(_has(done, "Span alignment: lowered, set in %s. Open now: %s to %s."
			% [names["c002"], names["c002"], names["c003"]]),
			"the span: lowered in %s, and the way it opened named" % names["c002"])
	_check(_has(done, "Cell power: powered, set in %s. Open now: %s to %s."
			% [names["c005"], names["c005"], JournalQuery.UNWALKED]),
			"the power: on in %s; the way it opened leads somewhere not yet "
			% names["c005"] + "walked, and says so")
	# One line per thing the record holds, and no more: 2 keys, 1 lock, 1
	# object, 2 settings away from their start.
	_check(done.size() == 6, "six lines for six things done: %d" % done.size())
	await _deliver("stowed")
	done = journal.section("WHAT YOU DID HERE")
	_check(not _has(done, "Span alignment") and done.size() == 5,
			"the span put back: a setting at its start again is not listed "
			+ "(%d lines)" % done.size())
	await _deliver("latched")
	done = journal.section("WHAT YOU DID HERE")
	names = _discovered("latched")
	_check(_has(done, "A latch held in %s. Open now: %s to %s." % [
			names["c009"], names["c009"], JournalQuery.UNWALKED]),
			"latched: the latch in %s, and the way it holds open" % names["c009"])
	_check(_has(done, "Open now: %s to %s." % [names["c005"], names["c006"]]),
			"and once %s is found, the power line names it" % names["c006"])


## §8: "must not ... spoil unvisited rewards ... should not reveal an
## undiscovered solution". No room the bridge's map has not named appears
## on the journal -- in its lines or anywhere drawn on the wall -- by name
## or by save id.
func _nothing_unfound_is_named() -> void:
	print("  -- nothing unfound is named")
	await _open("journal")
	for variant: String in ["arrived", "progressed", "latched", "hub"]:
		await _deliver(variant)
		await _frames(2)
		var found := _discovered(variant) if variants[variant].get(
				"zone_map") != null else {}
		var shown: Array = journal.lines() + _words(shell.face_node("journal"))
		var leaks: Array = []
		for rid: String in all_names:
			if found.has(rid):
				continue
			var unfound_name := str(all_names[rid])
			var needles := [unfound_name, unfound_name.to_upper()]
			# A found room's name can contain an unfound one's ("Arena 1"
			# inside "Arena 12"); match whole names only.
			for line: String in shown:
				for needle: String in needles:
					var at := line.find(needle)
					while at != -1:
						var end := at + needle.length()
						if end >= line.length() or not line[end].is_valid_int():
							leaks.append("%s in '%s'" % [needle, line])
							break
						at = line.find(needle, end)
		var ids: Array = []
		var pattern := RegEx.create_from_string("\\b[cC]0\\d\\d\\b")
		for line: String in shown:
			if pattern.search(line) != null:
				ids.append(line)
		_check(leaks.is_empty() and ids.is_empty(),
				"%s: no unfound room named, no save id: %s %s" % [variant,
					leaks, ids])
	shell.close()


## "A control's recorded discovery can remind the player which door it
## affects": the bridge's blocked gates, with its reasons.
func _still_shut() -> void:
	print("  -- still shut")
	await _deliver("walked")
	var shut := journal.section("STILL SHUT")
	var reasons: Array = []
	for raw: Variant in variants["walked"]["zone_map"]["connectors"]:
		if str(raw["state"]) != "open":
			reasons.append(str(raw["reason"]))
	var told := reasons.filter(func(r: Variant) -> bool:
		return str(r) != "" and _has(shut, str(r)))
	_check(not reasons.is_empty() and shut.size() == reasons.size()
			and told.size() == reasons.size(),
			"every gate the map lists shut, each with the bridge's reason "
			+ "(%d): %s" % [reasons.size(), shut])
	await _deliver("progressed")
	_check(journal.section("STILL SHUT") == [
			"Nothing you have found is shut."],
			"and once all three are open, it says nothing found is shut")


func _places() -> void:
	print("  -- places")
	await _deliver("progressed")
	var want: Array = _discovered("progressed").values()
	_check(journal.section("PLACES FOUND") == want,
			"the places found, by the bridge's names: %s" % [want])
	await _deliver("hub")
	_check(journal.section("PLACES FOUND") == [
			"Places are listed inside a Zone."],
			"in the Hub, it says places are listed inside a Zone")


## §8: "appropriately earned notes": each Echo's read, newest first.
func _notes_are_earned() -> void:
	print("  -- notes")
	await _deliver("progressed")
	var echo_log: Array = variants["progressed"]["interpretations"]
	var newest: Array = echo_log.duplicate()
	newest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["interpretation_seq"]) > int(b["interpretation_seq"]))
	var notes := journal.section("NOTES")
	var in_order := notes.size() == newest.size()
	for i in mini(notes.size(), newest.size()):
		var row: Dictionary = newest[i]
		in_order = in_order and str(notes[i]).begins_with(str(row["display_name"]))
	_check(in_order, "one note per Echo in the log, newest first (%d): %s"
			% [newest.size(), notes])
	var reads: Array = echo_log.filter(func(r: Dictionary) -> bool:
		return not _has(notes, str(r["description"])))
	_check(reads.is_empty(), "each with Epsilon's read, word for word")


## §8: identity rows through the note process, no parallel schema. The
## rows the Journal links from ARE the lines it says: the same list, in
## the same order, each carrying an id -- never an id found by matching
## the prose.
func _rows_and_strings_are_one_list() -> void:
	print("  -- the rows are the lines")
	for variant: String in ["progressed", "latched", "walked"]:
		var snap: Dictionary = variants[variant]
		var same := true
		for pair: Array in [
				[JournalQuery.done_here_rows(snap), JournalQuery.done_here(snap)],
				[JournalQuery.still_shut_rows(snap), JournalQuery.still_shut(snap)],
				[JournalQuery.places_rows(snap), JournalQuery.places(snap)]]:
			var texts: Array = (pair[0] as Array).map(func(r: Dictionary) -> String:
				return str(r["text"]))
			same = same and texts == pair[1]
		var ids := {}
		for raw: Variant in snap["zone_map"]["connectors"]:
			ids[str(raw["edge_id"])] = true
		var linked := true
		for row: Dictionary in JournalQuery.still_shut_rows(snap):
			linked = linked and ids.has(str(row["edge_id"]))
		for row: Dictionary in JournalQuery.places_rows(snap):
			linked = linked and _discovered(variant).has(str(row["room_id"]))
		_check(same and linked,
				"%s: each section's rows are its lines, and each row's id is one "
				% variant + "the bridge's map holds")


## The wall follows the snapshot: a new one refills it, open or not.
func _it_follows_the_snapshot() -> void:
	print("  -- it follows the snapshot")
	await _deliver("arrived")
	await _open("journal")
	var before := journal.fills
	await _deliver("latched")
	_check(journal.fills > before and _has(journal.lines(), "A latch held"),
			"a snapshot refills it (%d -> %d)" % [before, journal.fills])
	shell.close()


func _focus_entry(section: String, starts: String) -> bool:
	for col: int in [0, 1]:
		var list: Array = journal._entries[col]
		for i in list.size():
			var e: Dictionary = list[i]
			if not bool(e["head"]) and str(e["section"]) == section \
					and str(e["text"]).begins_with(starts):
				journal.column = col
				journal.focus[col] = i
				journal._layout()
				await _frames(2)
				return true
	return false


## §8: "the live map model with explicit ids ... Following a journal entry
## frames its destination and keeps the prior view. BACK TO YOUR VIEW
## stays a direct action." And §2: the Journal->Map wire is a cross-wall
## connection whose guide continues into the map window.
func _show_it_on_the_map_and_back() -> void:
	print("  -- show it on the map, and back")
	await _deliver("walked")
	await _open("map")
	map_face.overview()
	await _settle()
	var mine := [map_face.state()["yaw"], map_face.state()["zoom"],
			map_face.state()["target"], map_face.selected]
	await _key(KEY_Q)
	await _settle()
	_check(shell.front() == "journal", "Q turns to the Journal, to the Map's left")
	var shut: Array = JournalQuery.still_shut_rows(variants["walked"])
	var row: Dictionary = shut[0] if not shut.is_empty() else {}
	var focused := await _focus_entry("STILL SHUT", str(row.get("text", "?")))
	await _settle()
	var wire: Dictionary = journal.state()["link_wire"]
	_check(focused and journal.current_link() == {"edge": str(row.get("edge_id", ""))},
			"a STILL SHUT entry links by its passage's id: %s"
			% [journal.current_link()])
	_check(bool(wire.get("wire", false)) and bool(wire.get("inside", false))
			and wire.get("link", {}) == journal.current_link(),
			"its wire runs from the tag round the corner into the map's window, "
			+ "to that passage: %s" % [wire])
	await _key(KEY_ENTER)
	await _settle()
	var there := map_face.target_world({"edge": str(row.get("edge_id", ""))})
	_check(shell.front() == "map" and map_face.can_return()
			and bool(there.get("inside", false)),
			"ENTER shows it on the Map: the page turns, and the passage is in "
			+ "the window")
	await _key(KEY_ESCAPE)
	await _settle()
	var now := [map_face.state()["yaw"], map_face.state()["zoom"],
			map_face.state()["target"], map_face.selected]
	_check(now == mine and shell.is_open(),
			"Escape is BACK TO YOUR VIEW, exactly as it was: %s" % [now])
	# Ordinary travel keeps the view the Map had.
	await _key(KEY_Q)
	await _settle()
	await _key(KEY_E)
	await _settle()
	now = [map_face.state()["yaw"], map_face.state()["zoom"],
			map_face.state()["target"], map_face.selected]
	_check(now == mine and not map_face.can_return(),
			"turning back to the Map by E and Q leaves it as it was")
	shell.close()


## §8: "Preserve focus by identity; when something vanishes, explain it and
## remove the link."
func _a_passage_that_vanishes() -> void:
	print("  -- a passage that vanishes")
	await _deliver("walked")
	await _open("journal")
	var shut: Array = JournalQuery.still_shut_rows(variants["walked"])
	var gone := {}
	var progressed_ids := {}
	for r: Dictionary in JournalQuery.still_shut_rows(variants["progressed"]):
		progressed_ids[str(r["edge_id"])] = true
	for r: Dictionary in shut:
		if not progressed_ids.has(str(r["edge_id"])):
			gone = r
			break
	await _focus_entry("STILL SHUT", str(gone.get("text", "?")))
	var link := journal.current_link()
	# The same passage, now open, is listed under what was done: focus goes
	# with the id if it is still in the journal, with a word on what changed.
	await _deliver("progressed")
	var st := journal.state()
	_check((st["link"] as Dictionary) == link and str(st["note"]) == "NOW OPEN.",
			"the passage you were reading, open now: the focus stays on it by "
			+ "its id, and says what changed: '%s'" % st["note"])
	# Gone altogether (back in the Hub, where no passage is listed): said so,
	# and the wire taken down.
	await _deliver("walked")
	await _focus_entry("STILL SHUT", str((shut[0] as Dictionary)["text"]))
	await _settle()
	var wired: bool = (journal.state()["link_wire"] as Dictionary).get("wire", false)
	await _deliver("hub")
	await _settle()
	st = journal.state()
	_check(wired and str(st["note"]) == "THE PASSAGE YOU FOLLOWED IS NOT IN THE "
			+ "JOURNAL NOW." and not bool((st["link_wire"] as Dictionary).get("wire",
				true)) and (st["link"] as Dictionary).is_empty(),
			"the passage you were reading gone: said so, and its wire taken down: "
			+ "'%s'" % st["note"])
	# A link into the unknown draws nothing.
	journal.map_face.set_link({"edge": "e:c998:c999"})
	_check(map_face.target_local({"edge": "e:c998:c999"}) == Vector3.INF,
			"a link to a passage the map does not know lands on nothing")
	shell.close()


## The page turns are the shell's; the journal's keys move and scroll it.
func _the_journal_keys() -> void:
	print("  -- the journal's keys")
	await _deliver("latched")
	await _open("journal")
	var st := journal.state()
	await _key(KEY_DOWN)
	var moved := journal.state()
	_check(int(moved["index"]) != int(st["index"]) and shell.front() == "journal",
			"Down moves to the next entry, and the page stays")
	await _key(KEY_LEFT)
	_check(int(journal.state()["column"]) == 0, "Left goes to the other column")
	await _key(KEY_RIGHT)
	var scroll: Array = journal.state()["scroll"]
	await _key(KEY_PAGEDOWN)
	var paged: Array = journal.state()["scroll"]
	_check(float(paged[1]) > float(scroll[1]) or float(scroll[1]) > 0.0
			or int(journal.state()["last_index"]) < 12,
			"PgDn pages the column down (%.0f -> %.0f)" % [float(scroll[1]),
				float(paged[1])])
	# Held, Down walks to the last entry and it is always wholly on the wall.
	var seen := true
	for i in 40:
		await _key(KEY_DOWN, i > 0)
		seen = seen and bool(journal.state()["focused_seen"])
	_check(int(journal.state()["index"]) == int(journal.state()["last_index"])
			and seen, "held Down reaches the last entry, each wholly on the wall")
	await _key(KEY_Q)
	await _settle()
	_check(shell.front() == "settings",
			"and Q still turns the page: the journal -> '%s'" % shell.front())
	shell.close()


# ---------------------------------------------------------------------------
# The settings wall and the pause menu
# ---------------------------------------------------------------------------

## §8: "Settings includes resume, current campaign/profile information
## and supported options."
func _the_settings_wall() -> void:
	print("  -- the settings wall")
	await _deliver("progressed")
	var snap: Dictionary = variants["progressed"]
	var checked: int = (snap["checked_location_ids"] as Array).size()
	var total: int = checked + (snap["missing_location_ids"] as Array).size()
	var lines := settings.campaign_lines()
	var want := ["Seed: %s" % snap["seed_name"],
			"Player: %s" % snap["slot_name"],
			"Archipelago: mock, connected", "Epsilon: fallback",
			"Checks confirmed: %d of %d" % [checked, total],
			"Zones completed: %d" % int(snap["completed_zone_count"])]
	var missing := want.filter(func(w: Variant) -> bool:
		return not lines.has(w))
	_check(missing.is_empty(), "the campaign, from the snapshot: missing "
			+ "%s from %s" % [missing, lines])
	_check(_has(lines, "Link to the bridge: down"),
			"and the link, as it is (down here)")
	await _open("settings")
	var drawn: Array = settings.state()["campaign"]
	_check(drawn == lines, "and the CAMPAIGN display draws those lines")
	_check(settings.state()["row"] == "RESUME",
			"opened, the focus is on RESUME: ENTER goes straight back")
	shell.close()


## Hub and Zone each get their own switches; RESUME and QUIT GAME are
## real, and RETURN TO HUB asks for the return.
func _hub_and_zone_actions() -> void:
	print("  -- Hub and Zone actions")
	await _open("settings", false)
	_check(settings.state()["switches"] == ["RESUME", "QUIT GAME"],
			"in the Hub: RESUME and QUIT GAME, nothing about a Zone: %s"
			% [settings.state()["switches"]])
	_signals.clear()
	await _click_part("settings", "switch:QUIT GAME", "QUIT GAME")
	_check(_signals == ["quit"], "QUIT GAME quits: %s" % [_signals])
	shell.close()
	await _open("settings", true)
	_check(settings.state()["switches"] == ["RESUME", "RETURN TO HUB",
			"ABANDON ZONE…", "QUIT GAME"],
			"in a Zone: the pause menu's four actions, as they were: %s"
			% [settings.state()["switches"]])
	_signals.clear()
	await _click_part("settings", "switch:RETURN TO HUB", "RETURN TO HUB")
	_check(_signals == ["return_to_hub_requested"],
			"RETURN TO HUB asks for the return: %s" % [_signals])
	await _focus_row("RESUME")
	_signals.clear()
	await _key(KEY_ENTER)
	_check(_signals.has("resumed"), "and ENTER on RESUME resumes: %s" % [_signals])
	shell.close()


## "Destructive actions need their existing confirmation and accurate
## consequences." §7: "Abandon keeps confirm/cancel, and a carried-over
## confirm press must not arm and confirm at once."
func _abandon_asks_first() -> void:
	print("  -- abandon asks first")
	await _open("settings", true)
	_signals.clear()
	# A double click on ABANDON: its second click is not a press of its own.
	await _click_part("settings", "switch:ABANDON ZONE…", "ABANDON")
	var armed: bool = settings.state()["arming"]
	_check(armed and settings.state()["row"] == "CANCEL"
			and shell.back_words() == "cancel abandon",
			"ABANDON arms: the focus goes to CANCEL, and Escape says it cancels")
	await _click_part("settings", "switch:CONFIRM ABANDON", "CONFIRM", true)
	_check(_signals.is_empty() and settings.state()["arming"],
			"a double click's second click, landing on CONFIRM, confirms nothing")
	var warned := " ".join(_words(shell.face_node("settings")))
	var want := PauseMenu.WARNING.to_upper().replace("\n", " ")
	_check(warned.contains(want.substr(0, 40)) and warned.contains("THIS ZONE IS GONE."),
			"and the board says the same consequences: %s" % PauseMenu.WARNING)
	await _key(KEY_ESCAPE)
	_check(not settings.state()["arming"] and shell.is_open(),
			"Escape cancels, and the menu stays open")
	# ENTER held on ABANDON: the press arms, its echoes confirm nothing.
	await _focus_row("ABANDON ZONE…")
	await _hold_key(KEY_ENTER, 6)
	_check(settings.state()["arming"] and _signals.is_empty(),
			"ENTER held on ABANDON arms it once; its repeats confirm nothing")
	# Armed afresh, then straight down to CONFIRM and pressed at once: too
	# soon to be a decision.
	await _key(KEY_ESCAPE)
	await _focus_row("ABANDON ZONE…")
	await _key(KEY_ENTER)
	var armed_at := Time.get_ticks_msec()
	await _focus_row("CONFIRM ABANDON")
	await _key(KEY_ENTER)
	var elapsed := Time.get_ticks_msec() - armed_at
	var too_soon := _signals.is_empty()
	await get_tree().create_timer(PauseMenu.ARM_GUARD + 0.05).timeout
	await _key(KEY_ENTER)
	if elapsed < int(PauseMenu.ARM_GUARD * 1000.0):
		_check(too_soon and _signals == ["abandon_confirmed"],
				"a CONFIRM pressed %d ms after arming is refused; a deliberate "
				% elapsed + "one, once armed a moment, confirms: %s" % [_signals])
	else:
		_note("this machine took %d ms to reach CONFIRM: the guard was not " % elapsed
				+ "tested")
		_check(_signals.has("abandon_confirmed"), "a deliberate CONFIRM confirms")
	shell.close()


func _focus_row(words: String) -> void:
	for i in 12:
		if settings.state()["row"] == words:
			return
		var rows: Array = settings.state()["rows"]
		var to := rows.find(words)
		await _key(KEY_DOWN if to > int(settings.state()["focus"]) else KEY_UP)


func _keep_settings() -> void:
	_had_settings = FileAccess.file_exists(PlayerSettings.PATH)
	_saved_settings = FileAccess.get_file_as_bytes(PlayerSettings.PATH) \
			if _had_settings else PackedByteArray()


func _put_settings_back() -> void:
	if _had_settings:
		var out := FileAccess.open(PlayerSettings.PATH, FileAccess.WRITE)
		out.store_buffer(_saved_settings)
		out.close()
	else:
		DirAccess.remove_absolute(PlayerSettings.PATH)
	PlayerSettings.reset_shared()
	SettingsFace.apply_volume()
	shell.sync_motion()
	var back := FileAccess.get_file_as_bytes(PlayerSettings.PATH) \
			if _had_settings else PackedByteArray()
	_check(back == _saved_settings, "and the settings file is put back as it was")


## The options change what they say, now, and are kept.
func _the_options_do_what_they_say() -> void:
	print("  -- the options")
	await _open("settings", true)
	await _focus_row("FIELD OF VIEW")
	var before := settings.value("field_of_view")
	await _key(KEY_RIGHT)
	var one := settings.value("field_of_view")
	var camera := get_tree().root.get_camera_3d()
	var config := ConfigFile.new()
	config.load(PlayerSettings.PATH)
	_check(is_equal_approx(one, before + 1.0) and camera != null
			and camera.get_parent() is Player and is_equal_approx(camera.fov, one)
			and is_equal_approx(float(config.get_value("values", "field_of_view",
				0.0)), one) and settings.state()["shown"]["field_of_view"]
				== "%d DEGREES" % roundi(one),
			"Right on FIELD OF VIEW: one degree (%.0f -> %.0f), on the player's "
			% [before, one] + "camera now, saved, and shown")
	settings.set_value("field_of_view", 100.0)
	_check(is_equal_approx(camera.fov, 100.0), "set to 100: the camera at 100")
	settings.set_value("master_volume", 0.5)
	var bus := AudioServer.get_bus_index("Master")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)),
			"master volume 50%%: the Master bus at %.1f dB"
			% AudioServer.get_bus_volume_db(bus))
	var ranges := true
	for row: Array in SettingsFace.SLIDERS:
		var key := str(row[0])
		var rg: Array = PlayerSettings.RANGES[key]
		settings.set_value(key, 1.0e9)
		ranges = ranges and is_equal_approx(settings.value(key), float(rg[2]))
		settings.set_value(key, -1.0e9)
		ranges = ranges and is_equal_approx(settings.value(key), float(rg[1]))
	_check(ranges, "every option stays inside PlayerSettings' own range")
	await _focus_row("INVERT LOOK UP AND DOWN")
	var inverted := settings.flag("invert_look_y")
	await _key(KEY_ENTER)
	_check(settings.flag("invert_look_y") != inverted
			and settings.state()["shown"]["invert_look_y"]
				== ("ON" if not inverted else "OFF"),
			"ENTER on INVERT flips it, and says so")
	var offered: Array = []
	for row: Array in SettingsFace.SLIDERS:
		offered.append(str(row[0]))
	_check(not offered.has("captions"),
			"captions, which nothing reads, is not offered")
	shell.close()


## §7: "Bounded held-direction slider acceleration: single presses stay
## precise; it resets on release, direction change or control change; its
## rate is tunable."
func _a_held_direction_speeds_up() -> void:
	print("  -- a held direction speeds up, and only held")
	await _open("settings", true)
	await _focus_row("MOUSE SENSITIVITY")
	settings.set_value("mouse_sensitivity", float(PlayerSettings.RANGES[
			"mouse_sensitivity"][1]))
	var step := 0.0001
	var start := settings.value("mouse_sensitivity")
	for i in 5:
		await _key(KEY_RIGHT)
	var single := settings.value("mouse_sensitivity")
	_check(is_equal_approx(single, start + 5.0 * step),
			"five single presses: five steps exactly")
	await _hold_key(KEY_RIGHT, 8)
	var held := settings.value("mouse_sensitivity")
	var steps := roundi((held - single) / step)
	var want := 1
	for n in range(1, 9):
		want += SettingsFace.steps_for(n)
	_check(steps == want and steps > 9,
			"held for eight repeats: %d steps, faster than one a repeat (%d)"
			% [steps, want])
	_check(int(settings.state()["streak"]) == 0, "and let go, the run is over")
	await _key(KEY_RIGHT)
	_check(is_equal_approx(settings.value("mouse_sensitivity"), held + step),
			"the next single press is one step again")
	await _hold_key(KEY_RIGHT, 4)
	var a := settings.value("mouse_sensitivity")
	await _hold_key(KEY_LEFT, 1)
	_check(is_equal_approx(settings.value("mouse_sensitivity"), a - 2.0 * step),
			"a change of direction starts over at one step")
	_check(SettingsFace.steps_for(0) == 1 and SettingsFace.steps_for(
			SettingsFace.ACCEL_AFTER - 1) == 1 and SettingsFace.steps_for(1000)
			== SettingsFace.ACCEL_MAX,
			"bounded: one step for the first %d repeats, never more than %d"
			% [SettingsFace.ACCEL_AFTER, SettingsFace.ACCEL_MAX])
	shell.close()


## §7: "Motion applies immediately, including running animations and
## secondary effects. Reduced motion doesn't silence audio."
func _motion_at_once() -> void:
	print("  -- MOTION, at once")
	settings.set_value("motion_intensity", 1.0)
	await _open("settings", true)
	shell.turn(1)
	await _frames(2)
	var turning := shell.is_turning()
	settings.set_value("motion_intensity", 0.0)
	await _frames(1)
	_check(turning and not shell.is_turning() and shell.kit.reduced
			and shell.reduced_motion,
			"set to OFF mid-turn: the turn arrives at once, and the menu is "
			+ "reduced from then on")
	var pages := int(shell.kit.cue_counts.get("page", 0))
	shell.turn(-1)
	await _frames(1)
	_check(not shell.is_turning() and int(shell.kit.cue_counts.get("page", 0))
			== pages + 1, "a turn is a cut now, and it still sounds")
	settings.set_value("motion_intensity", 1.0)
	_check(not shell.kit.reduced, "and back on, motion is back at once")
	shell.close()


## §11: Epsilon's component is presentation: not a meter, slot, setting
## or focus target, and his feed stays clear of every control and value.
func _epsilon_is_not_a_control() -> void:
	print("  -- Epsilon is not a control")
	await _open("settings", true)
	var rows: Array = settings.state()["rows"]
	var picks: Array = shell.kit.targets("settings").keys()
	var his := picks.filter(func(t: Variant) -> bool:
		return str(t).to_lower().contains("epsilon") or str(t).contains("terminal"))
	_check(not rows.has("EPSILON") and his.is_empty(),
			"no row and nothing to click is his: %s" % [picks])
	_check(bool(settings.state()["feed_clear"]),
			"and his feed crosses no value's window and no control")
	shell.close()


## §12: "repeated open/close, and performance". Thirty opens and closes on
## every wall, some closed in the middle of a turn: the box holds what it
## held, no pause is left behind, and what an open costs is measured.
func _open_and_close_again() -> void:
	print("  -- opened and closed, again and again")
	await _deliver("latched")
	await _open("settings")
	shell.close()
	await _frames(4)
	var nodes := _count(shell)
	var worst := 0
	var total := 0
	for i in 30:
		var t0 := Time.get_ticks_usec()
		pause_menu.open(true)
		shell.open(MenuShell.PAGES[i % MenuShell.PAGES.size()])
		var took := Time.get_ticks_usec() - t0
		worst = maxi(worst, took)
		total += took
		await _frames(2)
		if i % 3 == 0:
			shell.turn(1)
			await _frames(2)
		shell.close()
		await _frames(2)
	await _frames(4)
	_check(_count(shell) == nodes and not PauseClaims.held_by(MenuShell.PAUSE_CLAIM)
			and not get_tree().paused,
			"thirty opens and closes, a third of them mid-turn: the box holds "
			+ "the same %d nodes (%d now), and no pause is left held"
			% [nodes, _count(shell)])
	_note("an open took %.1f ms on average and %.1f ms at most, headless, "
			% [total / 30000.0, worst / 1000.0] + "with every wall's rebuild")
	_check(worst < 250000, "and no open takes a pathological time")


func _count(root: Node) -> int:
	var n := 1
	for child: Node in root.get_children():
		n += _count(child)
	return n


# ---------------------------------------------------------------------------
# Screenshots (`make journal-face-shots`, under the game's renderer)
# ---------------------------------------------------------------------------

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for shot: Array in [["latched", "journal", "journal_latched", true],
			["hub", "journal", "journal_in_the_hub", false],
			["progressed", "settings", "settings_in_a_zone", true],
			["hub", "settings", "settings_in_the_hub", false]]:
		await _deliver(str(shot[0]))
		await _open(str(shot[1]), bool(shot[3]))
		await _frames(10)
		var image := get_viewport().get_texture().get_image()
		var path := dir.path_join("%s.png" % str(shot[2]))
		image.save_png(path)
		_save_words(path)
		_check(image.get_width() > 64, "saved %s" % path.get_file())
		shell.close()
		await _frames(2)


## What the words on the front wall are, and where, beside the render:
## what `tools/menu_contrast.py` measures the render's contrast from.
func _save_words(png: String) -> void:
	var out := FileAccess.open(png.get_basename() + ".words.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(shell.words_on_screen()))
	out.close()
