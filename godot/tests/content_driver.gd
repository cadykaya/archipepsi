extends Node
## The authored-content registry suite (`make godot-content`), v0.9 S12.
##
## Python's `test_content_registry.py` validates the manifest's shape. This
## side holds the half only Godot can: whether a scene a manifest claims is
## actually there, and whether the S13 selection rule
##
##     AUTHORED SCENE IF AVAILABLE -> VALIDATED PLACEHOLDER OTHERWISE
##
## picks what it says it picks. A registry that validates in Python and
## then fails at instantiation has moved the error to the worst possible
## moment, which is the reason both halves exist.
##
## Synthetic manifests are written under `user://` and loaded from there,
## so a refusal can be provoked without committing a broken manifest to
## the tree the game actually ships.

const SCRATCH := "user://content_test"

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_the_committed_registry_loads()
	_the_committed_registry_covers_every_chamber_the_game_builds()
	_a_category_at_the_wrong_level_is_refused()
	_a_room_nothing_can_connect_to_is_refused()
	_a_scene_that_is_not_there_is_refused()
	_a_scene_outside_the_content_root_is_refused()
	_claiming_both_procedural_and_a_scene_is_refused()
	_an_id_defined_twice_is_refused()
	_a_dangling_variant_or_fallback_is_refused()
	_a_fallback_cycle_is_refused()
	_every_mistake_is_reported_not_just_the_first()
	_resolution_prefers_authored_and_degrades_to_the_placeholder()
	_resolution_of_an_unknown_id_is_empty_not_a_guess()
	_queries_are_sorted_so_selection_is_deterministic()
	_cleanup()
	if failures == 0:
		print("GODOT CONTENT TESTS OK")
		get_tree().quit(0)
	else:
		print("CONTENT FAILURES: %d" % failures)
		get_tree().quit(1)

# --- scratch manifests -----------------------------------------------------

func _socket(name: String = "entry") -> Dictionary:
	return {"name": name, "kind": "doorway",
			"position": [0.0, 0.0, 0.0], "width": 2.4, "height": 3.2}

func _entry(over: Dictionary = {}) -> Dictionary:
	var base := {
		"id": "shell_test", "level": 3, "category": "room_shell",
		"display_name": "Test", "procedural_fallback": true,
		"sockets": [_socket()],
	}
	base.merge(over, true)
	return base

## Writes one manifest into a fresh scratch directory and loads it.
## Returns the registry so the caller can read `errors`.
func _load(entries: Array, pack: String = "test") -> ContentRegistry:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var file := FileAccess.open("%s/%s.json" % [SCRATCH, pack],
			FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "pack": pack,
			"entries": entries}))
	file.close()
	var registry := ContentRegistry.new()
	registry.load_all(SCRATCH)
	return registry

func _refuses(entries: Array, fragment: String, what: String) -> void:
	var registry := _load(entries)
	var joined := "\n".join(registry.errors)
	_check(joined.contains(fragment),
			"%s should be refused with '%s'; errors were: %s"
			% [what, fragment, joined if not joined.is_empty() else "(none)"])

func _cleanup() -> void:
	var dir := DirAccess.open(SCRATCH)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(SCRATCH)

# --- the committed registry ------------------------------------------------

func _the_committed_registry_loads() -> void:
	var registry := ContentRegistry.new()
	var ok := registry.load_all()
	_check(ok, "the committed registry does not load: %s"
			% "\n".join(registry.errors))
	_check(not registry.entries.is_empty(), "the committed registry is empty")

func _the_committed_registry_covers_every_chamber_the_game_builds() -> void:
	## A registry describing only some of the game is a registry the S13
	## fallback chain can fall out of — and it falls out at generation
	## time, in a zone the player is standing in.
	var registry := ContentRegistry.new()
	registry.load_all()
	var shells := registry.ids_of_category("room_shell")
	for chamber in ["corridor", "arena", "platform_path", "tower",
			"treasure_room"]:
		var found := false
		for id: String in shells:
			if id.contains(chamber):
				found = true
				break
		_check(found, "no room shell registered for chamber type '%s'; "
				% chamber + "registered: %s" % str(shells))

# --- refusals --------------------------------------------------------------

func _a_category_at_the_wrong_level_is_refused() -> void:
	_refuses([_entry({"level": 1})], "that category is level",
			"a room_shell declared at level 1")

func _a_room_nothing_can_connect_to_is_refused() -> void:
	_refuses([_entry({"sockets": []})], "nothing could connect",
			"a room shell with no joining socket")

func _a_scene_that_is_not_there_is_refused() -> void:
	## The reason this half of the contract exists. Python can check that
	## a path is well formed and inside the content root; only Godot can
	## check that the file is on disk.
	_refuses([_entry({"procedural_fallback": false,
			"scene": "res://content/shells/not_a_real_scene.tscn"})],
			"does not exist", "a manifest claiming a scene that is missing")

func _a_scene_outside_the_content_root_is_refused() -> void:
	## `main.tscn` genuinely exists, so this cannot pass by accident on
	## the existence check above — it must be refused for where it points.
	_refuses([_entry({"procedural_fallback": false,
			"scene": "res://scenes/main.tscn"})],
			"res://content/", "a scene outside the content root")

func _claiming_both_procedural_and_a_scene_is_refused() -> void:
	_refuses([_entry({"procedural_fallback": true,
			"scene": "res://content/shells/x.tscn"})],
			"one or the other", "an entry that is both placeholder and scene")

func _an_id_defined_twice_is_refused() -> void:
	_refuses([_entry(), _entry()], "already defined",
			"the same id twice")

func _a_dangling_variant_or_fallback_is_refused() -> void:
	_refuses([_entry({"variants": ["shell_nowhere"]})],
			"which no pack defines", "a variant naming nothing")
	_refuses([_entry({"fallback": "shell_nowhere"})],
			"which no pack defines", "a fallback naming nothing")

func _a_fallback_cycle_is_refused() -> void:
	## A cycle turns "fall back to something that works" into a hang, at
	## the exact moment something was already going wrong.
	_refuses([
		_entry({"id": "shell_a", "fallback": "shell_b"}),
		_entry({"id": "shell_b", "fallback": "shell_a"}),
	], "fallback cycle", "a fallback chain that loops")

func _every_mistake_is_reported_not_just_the_first() -> void:
	## An artist fixing a manifest one run at a time is the workflow this
	## is meant to support; stopping at the first refusal makes that N
	## runs instead of one.
	var registry := _load([
		_entry({"id": "shell_a", "level": 1}),
		_entry({"id": "shell_b", "sockets": []}),
		_entry({"id": "shell_c", "category": "nonsense"}),
	])
	_check(registry.errors.size() >= 3,
			"three broken entries should report three refusals, got %d: %s"
			% [registry.errors.size(), "\n".join(registry.errors)])

# --- the S13 selection rule ------------------------------------------------

func _resolution_prefers_authored_and_degrades_to_the_placeholder() -> void:
	var registry := _load([
		_entry({"id": "shell_authored", "fallback": "shell_proc"}),
		_entry({"id": "shell_proc"}),
	])
	_check(registry.errors.is_empty(),
			"the resolution fixture should validate: %s"
			% "\n".join(registry.errors))

	var everything := func(_e: Dictionary) -> bool: return true
	_check(registry.resolve("shell_authored", everything) == "shell_authored",
			"authored content must win when it is available")

	var nothing_authored := func(e: Dictionary) -> bool:
		return e.get("id", "") != "shell_authored"
	_check(registry.resolve("shell_authored", nothing_authored)
			== "shell_proc",
			"an unavailable authored scene must degrade to the placeholder, "
			+ "not fail")

	var nothing := func(_e: Dictionary) -> bool: return false
	_check(registry.resolve("shell_authored", nothing) == "",
			"a chain where nothing is available must say so, not guess")

func _resolution_of_an_unknown_id_is_empty_not_a_guess() -> void:
	var registry := _load([_entry()])
	_check(registry.resolve("shell_nope") == "",
			"an unknown id must resolve to nothing, never to a substitute")

func _queries_are_sorted_so_selection_is_deterministic() -> void:
	## Whatever picks content must pick the same thing from the same seed
	## on every machine; a Dictionary's iteration order is not a promise.
	var registry := _load([
		_entry({"id": "shell_c", "semantic_tags": ["ruined"]}),
		_entry({"id": "shell_a", "semantic_tags": ["ruined"]}),
		_entry({"id": "shell_b", "semantic_tags": ["pristine"]}),
	])
	var by_category: Array[String] = registry.ids_of_category("room_shell")
	_check(Array(by_category) == ["shell_a", "shell_b", "shell_c"],
			"ids_of_category must be sorted, got %s" % str(by_category))
	var by_tag: Array[String] = registry.ids_with_tags(["ruined"])
	_check(Array(by_tag) == ["shell_a", "shell_c"],
			"ids_with_tags must be sorted and filtered, got %s" % str(by_tag))
	_check(registry.ids_with_tags(["ruined"], "prop").is_empty(),
			"a category filter that matches nothing must return nothing")
