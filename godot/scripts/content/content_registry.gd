class_name ContentRegistry
extends RefCounted
## The authored-content registry (v0.9 S12): what exists, by stable id.
##
## `AUTHORED_CONTENT.md` says humans make the alphabet and Godot enforces
## the grammar. This is where the alphabet is read and where the grammar
## starts being enforced — the manifests under `res://content/registry/`
## are authored beside the scenes they describe, so adding an asset is a
## scene plus a manifest entry and never a change to generator logic.
##
## The Python half (`schemas/content.py`) validates the manifest's SHAPE
## and is what a provider's output is checked against. This half is the
## physical authority: it is the only one that can ask whether a scene
## actually loads, and it refuses a manifest that claims one that does not.
##
## Ids are the contract. Nothing outside a manifest ever names a file, and
## `Epsilon` never sees a path at all.

const REGISTRY_DIR := "res://content/registry"

## Categories that must carry a socket something can join to. Mirrors
## `_NEEDS_SOCKETS` in `schemas/content.py`; the two are pinned together
## by `test_content_registry.py`, which reads this file.
const NEEDS_SOCKETS := ["room_shell", "connector"]

## Which content levels each category may declare. Mirrors `_LEVELS`.
const LEVELS := {
	"prop": [0],
	"module": [1],
	"connector": [1],
	"fixture": [2],
	"affordance_visual": [2],
	"interactable": [0, 1, 2],
	"room_shell": [3],
	"landmark": [4],
}

var entries: Dictionary = {}          ## id -> entry Dictionary
var errors: Array[String] = []        ## every refusal, in discovery order

## Load every manifest under `REGISTRY_DIR`. Returns whether the registry
## is usable; `errors` says why not.
##
## A refusal is collected rather than thrown. A manifest with three
## mistakes should report three mistakes: an artist fixing them one run at
## a time is the workflow this is supposed to support.
func load_all(directory: String = REGISTRY_DIR) -> bool:
	entries.clear()
	errors.clear()
	var dir := DirAccess.open(directory)
	if dir == null:
		errors.append("no content registry at %s" % directory)
		return false
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		_load_manifest("%s/%s" % [directory, file])
	_check_cross_references()
	return errors.is_empty()

func _fail(where: String, message: String) -> void:
	errors.append("%s: %s" % [where, message])

func _load_manifest(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail(path, "unreadable or empty")
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail(path, "not a JSON object")
		return
	var manifest: Dictionary = parsed
	var pack := str(manifest.get("pack", ""))
	if pack.is_empty():
		_fail(path, "names no pack")
		return
	var listed: Variant = manifest.get("entries", [])
	if typeof(listed) != TYPE_ARRAY or (listed as Array).is_empty():
		_fail(path, "declares no entries")
		return
	for raw: Variant in listed:
		if typeof(raw) != TYPE_DICTIONARY:
			_fail(path, "an entry is not an object")
			continue
		_accept(pack, raw)

func _accept(pack: String, entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if id.is_empty():
		_fail(pack, "an entry has no id")
		return
	if entries.has(id):
		_fail(pack, "id '%s' is already defined; ids are the contract "
				% id + "and must be unique across every pack")
		return

	var category := str(entry.get("category", ""))
	if not LEVELS.has(category):
		_fail(id, "unknown category '%s'" % category)
		return
	var level := int(entry.get("level", -1))
	if not level in (LEVELS[category] as Array):
		_fail(id, "is a %s at level %d; that category is level %s"
				% [category, level, LEVELS[category]])
		return

	if category in NEEDS_SOCKETS and _joining_sockets(entry).is_empty():
		_fail(id, "is a %s and declares no doorway or corridor_end "
				% category + "socket; nothing could connect to it")
		return

	var procedural: bool = bool(entry.get("procedural_fallback", false))
	var scene := str(entry.get("scene", ""))
	if procedural:
		if not scene.is_empty():
			_fail(id, "is marked procedural_fallback and also names a "
					+ "scene; it is one or the other")
			return
	else:
		if scene.is_empty():
			_fail(id, "names no scene and is not procedural_fallback")
			return
		# The physical authority, and the reason this half exists: a
		# manifest can claim any path it likes, and only Godot can say
		# whether the file is there. A registry that passes validation and
		# then fails at instantiation has moved the error to the worst
		# possible moment.
		if not ResourceLoader.exists(scene):
			_fail(id, "names scene '%s', which does not exist" % scene)
			return
		if not scene.begins_with("res://content/"):
			_fail(id, "points at '%s'; authored content lives under "
					% scene + "res://content/ and nowhere else")
			return

	entry["_pack"] = pack
	entries[id] = entry

func _joining_sockets(entry: Dictionary) -> Array:
	var out: Array = []
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var kind := str((socket as Dictionary).get("kind", ""))
		if kind == "doorway" or kind == "corridor_end":
			out.append(socket)
	return out

## Cross-entry rules: a variant or fallback naming nothing, and a fallback
## chain that never terminates.
func _check_cross_references() -> void:
	for id: String in entries:
		var entry: Dictionary = entries[id]
		for variant: Variant in entry.get("variants", []):
			if not entries.has(str(variant)):
				_fail(id, "lists variant '%s', which no pack defines"
						% str(variant))
		var fallback := str(entry.get("fallback", ""))
		if not fallback.is_empty() and not entries.has(fallback):
			_fail(id, "falls back to '%s', which no pack defines. A "
					% fallback + "fallback that does not exist is the "
					+ "failure the fallback was there to prevent")
	for id: String in entries:
		var seen: Array[String] = [id]
		var current := str((entries[id] as Dictionary).get("fallback", ""))
		while not current.is_empty() and entries.has(current):
			if current in seen:
				_fail(id, "fallback cycle: %s" % ", ".join(seen + [current]))
				break
			seen.append(current)
			current = str((entries[current] as Dictionary).get("fallback", ""))

# --- queries ---------------------------------------------------------------

func has(id: String) -> bool:
	return entries.has(id)

func get_entry(id: String) -> Dictionary:
	return entries.get(id, {})

## Every id in a category, sorted, so selection is deterministic wherever
## it happens.
func ids_of_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in entries:
		if str((entries[id] as Dictionary).get("category", "")) == category:
			out.append(id)
	out.sort()
	return out

## Ids carrying every one of `tags`, sorted. The query Epsilon's semantic
## intent turns into, once S15 lets it name intent instead of metres.
func ids_with_tags(tags: Array, category: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in entries:
		var entry: Dictionary = entries[id]
		if not category.is_empty() \
				and str(entry.get("category", "")) != category:
			continue
		var have: Array = entry.get("semantic_tags", [])
		var missing := false
		for tag: Variant in tags:
			if not str(tag) in have:
				missing = true
				break
		if not missing:
			out.append(id)
	out.sort()
	return out

# --- selection -------------------------------------------------------------

## S13's rule, and the reason the fallback chain is validated above:
##
##     AUTHORED SCENE IF AVAILABLE
##             -> VALIDATED PLACEHOLDER / FALLBACK OTHERWISE
##
## `is_available` answers "can this entry actually be instantiated". The
## default asks the resource loader; a test supplies its own. The first
## entry down the chain that answers yes wins, and the chain is known to
## terminate because `_check_cross_references` refused any that did not.
##
## Returns "" when nothing in the chain is available, which is a caller
## error rather than a crash: the caller knows what it was building.
func resolve(id: String, is_available: Callable = Callable()) -> String:
	if not entries.has(id):
		return ""
	var current := id
	var guard := 0
	while not current.is_empty() and entries.has(current):
		# The validator refuses cycles, so this guard is belt and braces --
		# but a hang here would be at the exact moment something was
		# already going wrong, which is the worst time to find out.
		guard += 1
		if guard > entries.size() + 1:
			return ""
		var entry: Dictionary = entries[current]
		var ok: bool = is_available.call(entry) if is_available.is_valid() \
				else _default_available(entry)
		if ok:
			return current
		current = str(entry.get("fallback", ""))
	return ""

func _default_available(entry: Dictionary) -> bool:
	# A procedural entry is always available: it is code, and code is
	# there. That is what makes it a legitimate end to a fallback chain.
	if bool(entry.get("procedural_fallback", false)):
		return true
	var scene := str(entry.get("scene", ""))
	return not scene.is_empty() and ResourceLoader.exists(scene)
