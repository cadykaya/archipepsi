class_name ArchiveQuery
extends RefCounted
## WHAT THE ECHO ARCHIVE IS SHOWING — search, sort and the split between
## what you equip and what is simply true.
##
## Separate from `InventoryLayer` because this is the half with answers in
## it. Whether "grap" finds the Hookshot, whether sorting by source game
## groups the two Ocarina Echoes together, and whether a trait-only Echo
## lands under ALWAYS ON are all questions with a right answer, and none
## of them need a `Control` to ask. `inventory.gd` builds widgets from
## what this returns.
##
## **THE SPLIT IS THE OWNER'S COMPLAINT.** The archive was one scrolling
## list with actives and passives interleaved and no way to search it. An
## Echo that contributed no Action cannot be equipped at all -- §9 makes
## everything but Actions true the moment it is owned -- so mixing the two
## meant scrolling past things that were never decisions to reach the ones
## that were.

enum Sort { NEWEST, NAME, SOURCE_GAME }

## What the sort control offers, in `Sort` order.
const SORT_LABELS := ["Newest first", "Name A-Z", "Source game"]


## The Action components one interpretation created. Empty for a passive.
##
## `create` only: an UPGRADE names a component somebody else's Echo
## created, and listing it here would offer to equip it from two rows.
static func actions_of(echo: Dictionary) -> Array:
	var out: Array = []
	for operation: Variant in echo.get("operations", []):
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = operation
		if str(op.get("op", "")) != "create":
			continue
		var component: Dictionary = op.get("component", {})
		if str(component.get("kind", "")) == "action":
			out.append(component)
	return out


static func is_passive(echo: Dictionary) -> bool:
	return actions_of(echo).is_empty()


## Does this Echo answer to what was typed?
##
## Searches every line the row actually shows -- the name, the item that
## caused it, the game it came from, the description and the concepts
## Epsilon read. Searching only the name would mean "Ocarina" finding
## nothing while the words are on screen.
static func matches(echo: Dictionary, needle: String) -> bool:
	var want := needle.strip_edges().to_lower()
	if want == "":
		return true
	var hay: Array[String] = [
		str(echo.get("display_name", "")),
		str(echo.get("source_item_name", "")),
		str(echo.get("source_game", "")),
		str(echo.get("source_recipient_name", "")),
		str(echo.get("description", "")),
	]
	for concept: Variant in echo.get("concepts", []):
		hay.append(str(concept))
	for field: String in hay:
		if field.to_lower().contains(want):
			return true
	return false


## Did this Echo create an Action for this slot? `""` matches everything.
static func in_slot(echo: Dictionary, slot: String) -> bool:
	if slot == "":
		return true
	for action: Variant in actions_of(echo):
		if str((action as Dictionary).get("slot", "")) == slot:
			return true
	return false


## Newest first is the default because it is the order the archive has
## always had -- the log order -- and changing what the screen does by
## default is not what was asked for.
static func sorted_rows(rows: Array, mode: int) -> Array:
	var out := rows.duplicate()
	match mode:
		Sort.NAME:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _name_of(a) < _name_of(b))
		Sort.SOURCE_GAME:
			# Game first, then name, so a game's Echoes arrive together
			# and in a stable order inside the group rather than in
			# whatever order the log happened to hold them.
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ga := str(a.get("source_game", "")).to_lower()
				var gb := str(b.get("source_game", "")).to_lower()
				if ga != gb:
					return ga < gb
				return _name_of(a) < _name_of(b))
		_:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("interpretation_seq", 0)) \
						> int(b.get("interpretation_seq", 0)))
	return out


static func _name_of(echo: Dictionary) -> String:
	return str(echo.get("display_name", "")).to_lower()


## Everything the screen needs, in one pass.
##
## `shown` and `total` are both returned because "ACTIONS (3 of 19)" is
## the line that tells a player their search is hiding things. A count of
## what survived the filter, alone, looks identical to owning three.
static func rows(echoes: Array, search: String, mode: int,
		slot_filter: String) -> Dictionary:
	var actions: Array = []
	var passives: Array = []
	var total_actions := 0
	var total_passives := 0
	for raw: Variant in echoes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var echo: Dictionary = raw
		var passive := is_passive(echo)
		if passive:
			total_passives += 1
		else:
			total_actions += 1
		if not matches(echo, search):
			continue
		if passive:
			# A SLOT FILTER HIDES PASSIVES ENTIRELY. Asking "what can go
			# on SHIFT" and being shown seven things that go nowhere is
			# the interleaving this screen exists to undo.
			if slot_filter == "":
				passives.append(echo)
			continue
		if not in_slot(echo, slot_filter):
			continue
		actions.append(echo)
	return {
		"actions": sorted_rows(actions, mode),
		"passives": sorted_rows(passives, mode),
		"total_actions": total_actions,
		"total_passives": total_passives,
	}
