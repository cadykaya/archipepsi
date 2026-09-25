extends Node
## WHAT THE ECHO ARCHIVE SHOWS (`make godot-archive`).
##
## The owner played the menu and reported it as "a scrolling list with no
## search or sort, and mixed passives with actives". `ArchiveQuery` is the
## half of the repair with answers in it — whether a search finds a thing,
## what order rows come out in, and which side of the actives/passives
## split an Echo lands on — and this is where those answers are checked.
##
## **NO WIDGETS HERE ON PURPOSE.** Splitting the question from the
## painting means the question can be asked directly rather than by
## reading text off a panel.
##
## The panel these answers were built for, the Echo archive, is gone:
## H-INVENTORY replaced it with an item face (`EquipmentQuery`, tested by
## `equipment_face_driver.gd`). The product still asks `ArchiveQuery.matches`
## -- of every Echo that touched an item -- and the rest stays tested here
## until it is retired deliberately.

var _failures := 0
var _checks := 0
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
	_the_split()
	_search_reaches_every_line_on_the_row()
	_the_sort_orders()
	_the_slot_filter()
	_counts_say_what_is_hidden()
	print("")
	if _failures == 0:
		print("GODOT ARCHIVE OK (%d checks, %d notes)" % [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT ARCHIVE: %d failures in %d checks" % [_failures, _checks])
	get_tree().quit(1)


## One interpretation, in the shape the snapshot sends.
func _echo(seq: int, name: String, game: String, slot := "echo_a",
		item := "Thing", words: Array = [], about := "") -> Dictionary:
	var operations: Array = []
	if slot != "":
		operations.append({"op": "create", "component": {
			"kind": "action", "component_id": "act_%d" % seq,
			"display_name": name, "slot": slot}})
	else:
		# A PASSIVE: it created something, and nothing you can equip.
		operations.append({"op": "create", "component": {
			"kind": "trait", "component_id": "trait_%d" % seq,
			"display_name": name}})
	return {
		"interpretation_seq": seq, "display_name": name,
		"source_game": game, "source_item_name": item,
		"source_recipient_name": "Skyiah", "description": about,
		"concepts": words, "mode": "literal", "operations": operations,
	}


func _sample() -> Array:
	return [
		_echo(0, "Hookshot", "Ocarina of Time", "echo_a", "Hookshot",
				["reach"], "Latch onto geometry."),
		_echo(1, "Blink Step", "Bomb Rush Cyberfunk", "mobility", "Boostpack",
				["displacement"], "Step through."),
		_echo(2, "Iron Boots", "Ocarina of Time", "", "Iron Boots",
				["weight"], "Heavier."),
		_echo(3, "Grenade", "Borderlands 2", "consumable", "Grenade Mod",
				["blast"], "Boom."),
		_echo(4, "Ammo Regen", "Borderlands 2", "", "Ammo Regen",
				["supply"], "Refills slowly."),
	]


func _names(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append(str(row.get("display_name", "")))
	return out


## THE OWNER'S COMPLAINT, directly. An Echo that made no Action cannot be
## equipped at all, so listing it among the ones that can is scrolling
## past things that were never decisions.
func _the_split() -> void:
	print("\n-- actives and passives are two lists --")
	var found := ArchiveQuery.rows(_sample(), "", ArchiveQuery.Sort.NEWEST, "")
	var actions := _names(found["actions"])
	var passives := _names(found["passives"])
	_check(actions.size() == 3 and passives.size() == 2,
			"three equippable, two always-on (%s | %s)" % [actions, passives])
	_check(passives.has("Iron Boots") and passives.has("Ammo Regen"),
			"the trait-only Echoes are the passives")
	_check(not actions.has("Iron Boots"),
			"…and a passive never appears among the things you can equip")
	for row: Dictionary in found["passives"]:
		_check(ArchiveQuery.is_passive(row),
				"'%s' contributed no Action" % row.get("display_name", "?"))


## Searching only the name would leave "Ocarina" finding nothing while the
## word is on screen twice.
func _search_reaches_every_line_on_the_row() -> void:
	print("\n-- search reaches every line the row shows --")
	var cases := {
		"hook": "the name",
		"ocarina": "the source game",
		"boostpack": "the item that caused it",
		"blast": "a concept Epsilon read",
		"latch": "the description",
	}
	for needle: String in cases:
		var found := ArchiveQuery.rows(_sample(), needle,
				ArchiveQuery.Sort.NEWEST, "")
		var total: int = (found["actions"] as Array).size() \
				+ (found["passives"] as Array).size()
		_check(total > 0, "'%s' matches on %s" % [needle, cases[needle]])
	_check(ArchiveQuery.rows(_sample(), "HOOK",
			ArchiveQuery.Sort.NEWEST, "")["actions"].size() == 1,
			"…and it does not care about case")
	var nothing := ArchiveQuery.rows(_sample(), "zzzz",
			ArchiveQuery.Sort.NEWEST, "")
	_check((nothing["actions"] as Array).is_empty()
			and (nothing["passives"] as Array).is_empty(),
			"a search that matches nothing returns nothing, not everything")
	var blank := ArchiveQuery.rows(_sample(), "   ",
			ArchiveQuery.Sort.NEWEST, "")
	_check((blank["actions"] as Array).size() == 3,
			"…and an empty search is not a filter")


func _the_sort_orders() -> void:
	print("\n-- the three orders --")
	var newest := _names(ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NEWEST, "")["actions"])
	_check(newest[0] == "Grenade" and newest[-1] == "Hookshot",
			"newest first is the log in reverse (%s)" % [newest])
	var by_name := _names(ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NAME, "")["actions"])
	_check(by_name == ["Blink Step", "Grenade", "Hookshot"],
			"by name is A-Z (%s)" % [by_name])
	var by_game: Array = ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.SOURCE_GAME, "")["actions"]
	var games: Array = []
	for row: Dictionary in by_game:
		games.append(str(row.get("source_game", "")))
	_check(games == ["Bomb Rush Cyberfunk", "Borderlands 2",
			"Ocarina of Time"],
			"by source game groups a game's Echoes together (%s)" % [games])


## The "slot first" half: pick a key, see what fits it.
func _the_slot_filter() -> void:
	print("\n-- filtering to one slot --")
	var mobility := _names(ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NEWEST, "mobility")["actions"])
	_check(mobility == ["Blink Step"],
			"asking for SHIFT shows only what goes on SHIFT (%s)" % [mobility])
	var consumable := _names(ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NEWEST, "consumable")["actions"])
	_check(consumable == ["Grenade"],
			"…and the consumable slot has its own candidates (%s)"
			% [consumable])
	var filtered := ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NEWEST, "mobility")
	_check((filtered["passives"] as Array).is_empty(),
			"…and it hides passives entirely — seven things that go "
			+ "nowhere is the interleaving this undoes")
	var empty := ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NEWEST, "utility")
	_check((empty["actions"] as Array).is_empty(),
			"a slot nothing fits shows nothing rather than everything")
	var both := _names(ArchiveQuery.rows(_sample(), "ocarina",
			ArchiveQuery.Sort.NEWEST, "echo_a")["actions"])
	_check(both == ["Hookshot"],
			"search and slot filter compose (%s)" % [both])


## "ACTIONS (3)" and "ACTIONS (1 of 3)" have to be different, or a search
## that is hiding two things looks identical to owning one.
func _counts_say_what_is_hidden() -> void:
	print("\n-- the counts --")
	var all_rows := ArchiveQuery.rows(_sample(), "",
			ArchiveQuery.Sort.NEWEST, "")
	_check(int(all_rows["total_actions"]) == 3
			and int(all_rows["total_passives"]) == 2,
			"the totals count everything owned")
	var one := ArchiveQuery.rows(_sample(), "hook",
			ArchiveQuery.Sort.NEWEST, "")
	_check((one["actions"] as Array).size() == 1
			and int(one["total_actions"]) == 3,
			"…and stay at 3 while a search shows 1, so the heading can "
			+ "say '1 of 3'")
