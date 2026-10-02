class_name ArchiveQuery
extends RefCounted
## WHAT THE ECHO ARCHIVE IS SHOWING — search, sort and the split between
## what you equip and what is simply true.
##
## Whether "grap" finds the Hookshot, whether sorting by source game
## groups the two Ocarina Echoes together, and whether a trait-only Echo
## lands under ALWAYS ON are all questions with a right answer, and none
## of them need a `Control` to ask.
##
## The Echo archive this answered for is gone (H-INVENTORY replaced it with
## the item face). `matches` is still the one test of whether an Echo
## answers to a search: `EquipmentQuery.matches` asks it of every Echo
## that touched an item, so the words on the Echo still find the item.
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


## THE ACTIONS THIS ECHO CONTRIBUTES TO, resolved against what the
## campaign currently owns.
##
## **Not "what it created".** An interpretation that only UPGRADES an
## Action contributes to an Action and is not a passive; reading the
## `create` operations alone filed every upgrade-only Echo under ALWAYS
## ON, which is the same interleaving complaint one layer down. A mixed
## Echo — one that creates a trait AND upgrades a gun — contributes to
## both and has to appear accurately on both sides.
##
## `owned` is the fold (`BridgeClient.mechanics()["owned"]`), so the
## component returned is the CURRENT resolved one: the right slot, the
## right name, the right Mk. A `create` row alone would show the stats it
## had when it was new.
static func actions_of(echo: Dictionary, owned: Array = []) -> Array:
	var wanted: Array[String] = []
	for operation: Variant in echo.get("operations", []):
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = operation
		var verb := str(op.get("op", ""))
		if verb == "create":
			var component: Dictionary = op.get("component", {})
			if str(component.get("kind", "")) == "action":
				wanted.append(str(component.get("component_id", "")))
		elif op.has("target"):
			# UPGRADE / MODIFY / LINK / MERGE all name what they touch.
			wanted.append(str(op.get("target", "")))
	if wanted.is_empty():
		return []
	var out: Array = []
	var seen: Dictionary = {}
	for entry: Variant in owned:
		var row: Dictionary = entry
		var component: Dictionary = row.get("component", {})
		var cid := str(component.get("component_id", ""))
		if cid in wanted and not seen.has(cid) \
				and str(component.get("kind", "")) == "action":
			seen[cid] = true
			out.append(component)
	if not owned.is_empty():
		return out
	# NO FOLD TO RESOLVE AGAINST (a bare fixture, or a snapshot that has
	# not arrived): fall back to what this Echo created, which is the
	# best answer available and never worse than the old one.
	for operation: Variant in echo.get("operations", []):
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op2: Dictionary = operation
		if str(op2.get("op", "")) != "create":
			continue
		var made: Dictionary = op2.get("component", {})
		if str(made.get("kind", "")) == "action":
			out.append(made)
	return out


## A passive contributes to NO Action. A mixed Echo is not passive: it
## appears under ACTIONS for what it can equip, and its other
## contributions are named on the row.
static func is_passive(echo: Dictionary, owned: Array = []) -> bool:
	return actions_of(echo, owned).is_empty()


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
static func in_slot(echo: Dictionary, slot: String,
		owned: Array = []) -> bool:
	if slot == "":
		return true
	for action: Variant in actions_of(echo, owned):
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
		slot_filter: String, owned: Array = []) -> Dictionary:
	var actions: Array = []
	var passives: Array = []
	var total_actions := 0
	var total_passives := 0
	for raw: Variant in echoes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var echo: Dictionary = raw
		var passive := is_passive(echo, owned)
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
		if not in_slot(echo, slot_filter, owned):
			continue
		actions.append(echo)
	return {
		"actions": sorted_rows(actions, mode),
		"passives": sorted_rows(passives, mode),
		"total_actions": total_actions,
		"total_passives": total_passives,
	}
