extends Node
## H-JOURNAL (CP4): THE JOURNAL WALL AND THE SETTINGS WALL, on the real
## shell (`--journal-face`).
##
##     make godot-journal-face
##
## The walls are mounted exactly as `Main` mounts them: the pause menu and
## `SettingsFace` on Settings, `JournalFace` on Journal. Snapshots arrive
## through `BridgeClient._handle`, the path a real one takes, and are the
## model's own (`journal_snapshot.json`, `make journal-fixture`). The
## candidate Zone is built for real so a real player's camera is the one
## the field of view reaches.
##
## **What each check expects is worked out here from the snapshot**, never
## by asking `JournalQuery`: a rule tested against itself proves nothing.
##
## **Declared harness steps.** `user://settings.cfg` is saved before the
## options case and put back byte for byte after it.

const FIXTURE := "res://tests/fixtures/journal_snapshot.json"
const MAPS := "res://tests/fixtures/map_snapshot.json"
const CANDIDATE := "res://tests/fixtures/candidate_zone.json"

var shell: MenuShell
var journal: JournalFace
var settings: SettingsFace
var pause_menu: PauseMenu
var zone: ZoneController
var variants: Dictionary = {}
## Every room's name, from the map of the fully walked Zone: what an
## unfound room would be called, so the suite can look for leaks.
var all_names := {}
var _checks := 0
var _failures := 0
var _notes := 0


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
	journal = JournalFace.new()
	shell.page_root("journal").add_child(journal)
	settings = SettingsFace.new()
	shell.page_root("settings").add_child(settings)
	pause_menu = PauseMenu.new()
	shell.page_viewport("settings").add_child(pause_menu)
	await _frames(3)
	var shots := _shots_dir()
	if shots != "":
		get_window().size = _shots_size()
		await _frames(3)
		await _shoot(shots)
		_finish()
		return
	await _the_walls_are_filled()
	await _objectives()
	await _what_you_did_here()
	await _nothing_unfound_is_named()
	await _still_shut()
	await _places()
	await _notes_are_earned()
	await _it_follows_the_snapshot()
	await _the_settings_wall()
	await _the_options_do_what_they_say()
	await _keys()
	_finish()


func _finish() -> void:
	shell.close()
	print("")
	if _failures == 0:
		print("GODOT JOURNAL FACE OK (%d checks, %d notes)" % [_checks,
				_notes])
		get_tree().quit(0)
		return
	print("GODOT JOURNAL FACE TESTS: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


# ---------------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _deliver(variant: String) -> void:
	BridgeClient._handle(JSON.stringify(variants[variant]))
	await _frames(2)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


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


# ---------------------------------------------------------------------------
# The cases
# ---------------------------------------------------------------------------

func _the_walls_are_filled() -> void:
	print("  -- the walls are filled")
	var empty: Array = []
	for page: String in MenuShell.PAGES:
		if shell.page_root(page).get_node_or_null("Incomplete") != null:
			empty.append(page)
	_check(empty.is_empty() and MenuShell.INCOMPLETE.is_empty(),
			"no wall says it is not built yet: %s" % [empty])
	_check(shell.page_root("journal").get_node_or_null("JournalFace")
			== journal and shell.page_root("settings").get_node_or_null(
				"SettingsFace") == settings,
			"the journal and the settings faces are on their walls")


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
## on the journal, by name or by save id.
func _nothing_unfound_is_named() -> void:
	print("  -- nothing unfound is named")
	for variant: String in ["arrived", "progressed", "latched", "hub"]:
		await _deliver(variant)
		var found := _discovered(variant) if variants[variant].get(
				"zone_map") != null else {}
		var leaks: Array = []
		for rid: String in all_names:
			if found.has(rid):
				continue
			var unfound_name := str(all_names[rid])
			# A found room's name can contain an unfound one's ("Arena 1"
			# inside "Arena 12"); match whole names only.
			for line: String in journal.lines():
				var at := line.find(unfound_name)
				while at != -1:
					var end := at + unfound_name.length()
					if end >= line.length() or not line[end].is_valid_int():
						leaks.append("%s in '%s'" % [unfound_name, line])
						break
					at = line.find(unfound_name, end)
		var ids: Array = []
		var pattern := RegEx.create_from_string("\\bc0\\d\\d\\b")
		for line: String in journal.lines():
			if pattern.search(line) != null:
				ids.append(line)
		_check(leaks.is_empty() and ids.is_empty(),
				"%s: no unfound room named, no save id: %s %s" % [variant,
					leaks, ids])


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
	var titles: Array = []
	var box := journal.find_child("NOTES", true, false)
	for child: Node in box.get_children():
		if str(child.name).begins_with("Title"):
			titles.append((child as Label).text)
	var newest: Array = echo_log.duplicate()
	newest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["interpretation_seq"]) > int(b["interpretation_seq"]))
	var want: Array = newest.map(func(r: Dictionary) -> String:
		return str(r["display_name"]))
	_check(titles == want, "one note per Echo in the log, newest first "
			+ "(%d): %s" % [want.size(), titles])
	var reads: Array = echo_log.filter(func(r: Dictionary) -> bool:
		return not _has(journal.lines(), str(r["description"])))
	_check(reads.is_empty(), "each with Epsilon's read, word for word")


## The wall follows the snapshot: a new one refills it, open or not.
func _it_follows_the_snapshot() -> void:
	print("  -- it follows the snapshot")
	await _deliver("arrived")
	var before := journal.fills
	await _deliver("latched")
	_check(journal.fills > before and _has(journal.lines(), "A latch held"),
			"a snapshot refills it (%d -> %d)" % [before, journal.fills])


## §8: "Settings includes resume, current campaign/profile information
## and supported options. Separate return to Hub, abandon current Zone,
## quit ... Destructive actions need their existing confirmation and
## accurate consequences. Do not change the all-Checks/abandon policy
## through a prettier button label."
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
	pause_menu.open(true)
	shell.open("settings")
	await _frames(3)
	var buttons: Array = []
	for node: Node in pause_menu.find_children("*", "Button", true, false):
		buttons.append((node as Button).text)
	_check(buttons == ["RESUME", "RETURN TO HUB", "ABANDON ZONE…",
			"QUIT GAME"],
			"the pause menu's actions, one button each and as they were: %s"
			% [buttons])
	for node: Node in pause_menu.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("ABANDON"):
			(node as Button).pressed.emit()
	await _frames(2)
	var warned := ""
	for node: Node in pause_menu.find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("Abandoning"):
			warned = (node as Label).text
	_check(warned == "Abandoning returns unclaimed Checks to the pool.\n"
			+ "Confirmed Checks stay confirmed. This Zone is gone.",
			"ABANDON still asks first, and says the same consequences")
	pause_menu.open(true)
	shell.close()


## The options change what they say, now, and are kept.
func _the_options_do_what_they_say() -> void:
	print("  -- the options")
	var had := FileAccess.file_exists(PlayerSettings.PATH)
	var saved := FileAccess.get_file_as_bytes(PlayerSettings.PATH) if had \
			else PackedByteArray()
	var fov := settings.slider("field_of_view")
	fov.value = 100.0
	await _frames(1)
	var camera := get_tree().root.get_camera_3d()
	var config := ConfigFile.new()
	config.load(PlayerSettings.PATH)
	_check(is_equal_approx(PlayerSettings.shared().value("field_of_view"),
			100.0) and camera != null and camera.get_parent() is Player
			and is_equal_approx(camera.fov, 100.0)
			and is_equal_approx(float(config.get_value("values",
				"field_of_view", 0.0)), 100.0),
			"field of view 100: set, on the player's camera now, and saved")
	settings.slider("master_volume").value = 0.5
	await _frames(1)
	var bus := AudioServer.get_bus_index("Master")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(bus),
			linear_to_db(0.5)),
			"master volume 50%%: the Master bus at %.1f dB"
			% AudioServer.get_bus_volume_db(bus))
	settings.slider("motion_intensity").value = 0.0
	settings.toggle("invert_look_y").button_pressed = true
	await _frames(1)
	var label := settings.find_child("motion_intensityLabel", true,
			false) as Label
	_check(PlayerSettings.shared().value("motion_intensity") == 0.0
			and label.text.ends_with("off")
			and PlayerSettings.shared().flag("invert_look_y"),
			"motion off (says 'off') and look inverted: both set")
	var offered: Array = []
	for row: Array in SettingsFace.SLIDERS:
		offered.append(str(row[0]))
	_check(not offered.has("captions") and settings.toggle("captions") == null,
			"captions, which nothing reads, is not offered")
	# Put everything back: the player's own file, and the shared copy.
	if had:
		var out := FileAccess.open(PlayerSettings.PATH, FileAccess.WRITE)
		out.store_buffer(saved)
		out.close()
	else:
		DirAccess.remove_absolute(PlayerSettings.PATH)
	PlayerSettings.reset_shared()
	SettingsFace.apply_volume()
	var back := FileAccess.get_file_as_bytes(PlayerSettings.PATH) if had \
			else PackedByteArray()
	_check(back == saved, "and the settings file is put back as it was")


## The page turns are the shell's; the journal's keys scroll it.
func _keys() -> void:
	print("  -- keys")
	await _deliver("latched")
	shell.open("journal")
	await _frames(3)
	journal.scroll().scroll_vertical = 0
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _frames(1)
	_check(journal.scroll().scroll_vertical > 0 and shell.front() == "journal",
			"Down scrolls the journal (%d px), and the page stays"
			% journal.scroll().scroll_vertical)
	await _key(KEY_Q)
	await _frames(20)
	_check(shell.front() == "settings",
			"and Q still turns the page: the journal -> '%s'" % shell.front())
	shell.close()


# ---------------------------------------------------------------------------
# Screenshots (`make journal-face-shots`)
# ---------------------------------------------------------------------------

func _shots_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			return arg.substr("--shots=".length())
	return ""

## `--shots-size=WxH`: the window the screenshots are taken at (CP4's
## "resizing" proof). Absent, the suite's own 1280 x 720.
func _shots_size() -> Vector2i:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-size="):
			var parts := arg.substr("--shots-size=".length()).split("x")
			if parts.size() == 2:
				return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(1280, 720)


func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for shot: Array in [["latched", "journal", "journal_latched"],
			["hub", "journal", "journal_in_the_hub"],
			["progressed", "settings", "settings_in_a_zone"]]:
		await _deliver(str(shot[0]))
		pause_menu.open(true)
		shell.open(str(shot[1]))
		await _frames(10)
		var image := get_viewport().get_texture().get_image()
		var path := dir.path_join("%s.png" % str(shot[2]))
		image.save_png(path)
		_check(image.get_width() > 64, "saved %s" % path.get_file())
		shell.close()
		await _frames(2)
