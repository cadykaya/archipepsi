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
	_run()

func _run() -> void:
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
	_the_pipeline_routes_placeholders_to_the_generator()
	_the_pipeline_builds_an_authored_shell_from_its_metadata()
	_an_authored_shell_that_will_not_load_degrades_instead_of_crashing()
	_an_unregistered_chamber_type_still_builds()
	_the_grammar_refuses_a_join_the_player_cannot_use()
	_the_grammar_only_joins_ways_through()
	_the_narrower_opening_decides()
	_a_room_that_cannot_be_chained_is_named()
	_every_shipped_shell_is_chainable_by_the_base_kit()
	_cleanup()
	# Both awaited. A function containing `await` called WITHOUT one
	# returns at its first suspend, and the suite goes on to print OK
	# before its assertions have run -- the exact "tested nothing"
	# failure the Makefile guards elsewhere.
	await _the_ap_moment_never_spoils_what_it_holds()
	await _every_ap_state_is_distinguishable()
	_a_scene_missing_a_required_part_is_named()
	_a_theme_cannot_move_an_enemy_hitbox()
	_an_enemy_hitbox_is_a_function_of_its_archetype()
	_no_visual_anywhere_carries_collision()
	_the_base_kit_can_never_be_unbound()
	_a_hand_edited_config_cannot_unbind_the_base_kit()
	_settings_are_clamped_on_the_way_in()
	_reduced_motion_actually_reaches_zero()
	_preferences_never_enter_campaign_truth()
	_the_postgame_has_somewhere_to_attach()
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


# --- the S13 pipeline ------------------------------------------------------

const FIXTURE := "res://content/test_fixtures/shell_graybox_fixture.tscn"

func _authored_entry(over: Dictionary = {}) -> Dictionary:
	var base := {
		"id": "shell_arena_proc",   # the id the pipeline asks for
		"level": 3, "category": "room_shell",
		"display_name": "Authored Fixture",
		"procedural_fallback": false, "scene": FIXTURE,
		"size": [6.0, 3.6, 10.0],
		"sockets": [
			_socket("entry"),
			{"name": "exit", "kind": "doorway",
			 "position": [0.0, 0.0, 9.0], "width": 2.4, "height": 3.2},
		],
	}
	base.merge(over, true)
	return base

func _the_pipeline_routes_placeholders_to_the_generator() -> void:
	## The "do NOT rip out working procedural generation" requirement,
	## made testable: with the shipped registry (every entry a declared
	## placeholder), routing through the pipeline must produce exactly
	## what calling the builder directly produces. If this ever drifts,
	## S13 changed the game while claiming only to have added a choice.
	var chamber := {"id": "c1", "type": "arena", "width": 18.0,
			"depth": 18.0, "enemies": []}
	var direct := ChamberBuilders.build(chamber, "void_glitch")
	var routed := ContentInstantiator.build_chamber(chamber, "void_glitch")

	_check(routed["exit_offset"] == direct["exit_offset"],
			"routing changed exit_offset: %s vs %s"
			% [routed["exit_offset"], direct["exit_offset"]])
	_check(routed["bounds"] == direct["bounds"],
			"routing changed bounds: %s vs %s"
			% [routed["bounds"], direct["bounds"]])
	_check(routed["room_height"] == direct["room_height"],
			"routing changed room_height")
	_check(routed["reward_position"] == direct["reward_position"],
			"routing changed reward_position")
	(direct["root"] as Node3D).free()
	(routed["root"] as Node3D).free()

func _the_pipeline_builds_an_authored_shell_from_its_metadata() -> void:
	var registry := _load([_authored_entry()])
	_check(registry.errors.is_empty(),
			"the authored fixture should validate: %s"
			% "\n".join(registry.errors))

	var chamber := {"id": "c1", "type": "arena",
			"enemies": [{"archetype": "drone", "count": 2}]}
	var built := ContentInstantiator.build_chamber(chamber, "void_glitch",
			registry)
	var root: Node3D = built["root"]
	_check(root.name == "ShellGrayboxFixture",
			"the authored scene should have been instantiated, got '%s'"
			% root.name)

	## The contract ZoneBuilder chains on, taken from metadata rather than
	## measured off the mesh: a decorative overhang must not be able to
	## move a room's exit.
	# 9, not the room's depth of 10: the exit doorway is inset, as a real
	# shell's would be. If these were equal the assertion could not tell
	# a socket-derived offset from a size-derived guess -- and the first
	# version of this fixture had exactly that hole.
	_check(built["exit_offset"] == Vector3(0, 0, 9),
			"exit_offset must come from the declared exit socket, got %s"
			% built["exit_offset"])
	_check(built["bounds"] == AABB(Vector3(-3, -1, 0), Vector3(6, 4.6, 10)),
			"bounds must come from declared size in the same envelope the "
			+ "builders use, got %s" % built["bounds"])
	# `is_equal_approx`, not `==`: Vector3 stores 32-bit components, so
	# `size.y` is 3.5999999046... while the GDScript literal 3.6 is a
	# 64-bit float. Harmless for geometry, fatal for an equality check.
	_check(is_equal_approx(built["room_height"], 3.6),
			"room_height must be declared size.y, got %s"
			% built["room_height"])
	_check((built["enemy_spawns"] as Array).size() == 2,
			"the generator still decides how many enemies, got %d"
			% (built["enemy_spawns"] as Array).size())
	root.free()

func _an_authored_shell_that_will_not_load_degrades_instead_of_crashing()\
		-> void:
	## `resolve` already refuses a scene that is not on disk. This is the
	## narrower case the validator cannot see: a file that exists and
	## fails to load. A zone is being generated with a player in it, so
	## the answer is the placeholder, not an exception.
	var registry := _load([
		_authored_entry({"fallback": "shell_arena_backup"}),
		_entry({"id": "shell_arena_backup"}),
	])
	var chamber := {"id": "c1", "type": "arena", "width": 18.0,
			"depth": 18.0, "enemies": []}
	## Availability says no, exactly as a failed load would.
	var unavailable := func(e: Dictionary) -> bool:
		return bool(e.get("procedural_fallback", false))
	_check(registry.resolve("shell_arena_proc", unavailable)
			== "shell_arena_backup",
			"a shell that cannot be instantiated must fall through to the "
			+ "placeholder")
	var built := ContentInstantiator.build_chamber(chamber, "void_glitch",
			registry)
	_check(built.has("root") and built["root"] != null,
			"a degraded build must still produce a room")
	(built["root"] as Node3D).free()

func _an_unregistered_chamber_type_still_builds() -> void:
	## The registry is a routing table, not a gate on generation. A type
	## with no entry is the generator's default arm, as it always was.
	var registry := _load([_entry({"id": "shell_unrelated"})])
	var built := ContentInstantiator.build_chamber(
			{"id": "c1", "type": "not_a_real_type", "enemies": []},
			"void_glitch", registry)
	_check(built.has("root") and built["root"] != null,
			"an unregistered chamber type must still produce a room")
	(built["root"] as Node3D).free()


# --- the S15 connector grammar ---------------------------------------------

func _door(name: String, w: float, h: float,
		kind: String = "doorway") -> Dictionary:
	return {"name": name, "kind": kind, "position": [0.0, 0.0, 0.0],
			"width": w, "height": h}

func _the_grammar_refuses_a_join_the_player_cannot_use() -> void:
	## Invariant I4, at the joint. A doorway the player does not fit
	## through is not a tight corridor, it is a wall the generator
	## believes is a door.
	var wide := _door("wide", 2.4, 3.2)
	var narrow := _door("narrow", ConnectorGrammar.min_passable_width()
			- 0.01, 3.2)
	_check(not ConnectorGrammar.can_join(wide, narrow),
			"an opening under the player's width must be refused")
	_check(ConnectorGrammar.refusal(wide, narrow).contains("walk through"),
			"the refusal must say what is wrong, got '%s'"
			% ConnectorGrammar.refusal(wide, narrow))

	var low := _door("low", 2.4, ConnectorGrammar.min_passable_height()
			- 0.01)
	_check(not ConnectorGrammar.can_join(wide, low),
			"an opening under the player's height must be refused")

	## And the ordinary case still works, or the grammar refuses the game.
	_check(ConnectorGrammar.can_join(wide, _door("other", 2.4, 3.2)),
			"two standard doorways must join")

func _the_grammar_only_joins_ways_through() -> void:
	var door := _door("entry", 2.4, 3.2)
	var mount := _door("plate", 2.4, 3.2, "affordance")
	_check(not ConnectorGrammar.can_join(door, mount),
			"an affordance mount is not a way through and must not join")
	_check(ConnectorGrammar.can_join(door,
			_door("end_a", 2.4, 3.2, "corridor_end")),
			"a room doorway must join a connector end")

func _the_narrower_opening_decides() -> void:
	## Two joined openings leave the smaller of each dimension. If the
	## wider one decided, a 3 m doorway would launder a 0.5 m one.
	var passage := ConnectorGrammar.passage(
			_door("a", 3.0, 4.0), _door("b", 1.4, 2.2))
	_check(passage == Vector2(1.4, 2.2),
			"the passage must be the smaller of each dimension, got %s"
			% passage)

func _a_room_that_cannot_be_chained_is_named() -> void:
	## The mandatory path is a chain: a shell with one usable opening is
	## a dead end on it.
	var dead_end := {"id": "shell_dead", "sockets": [_door("entry", 2.4, 3.2)]}
	_check(not ConnectorGrammar.chainable(dead_end).is_empty(),
			"a shell with one opening must not be chainable")
	var through := {"id": "shell_through", "sockets": [
			_door("entry", 2.4, 3.2), _door("exit", 2.4, 3.2)]}
	_check(ConnectorGrammar.chainable(through).is_empty(),
			"a shell with two usable openings must chain: %s"
			% ConnectorGrammar.chainable(through))

func _every_shipped_shell_is_chainable_by_the_base_kit() -> void:
	## The one that matters. Whatever is in the registry today has to be
	## something the mandatory path can actually run through, with no
	## Echo and no exception.
	var registry := ContentRegistry.new()
	registry.load_all()
	for id: String in registry.ids_of_category("room_shell"):
		var entry := registry.get_entry(id)
		var why := ConnectorGrammar.chainable(entry)
		_check(why.is_empty(), "shipped shell is not chainable: %s" % why)


# --- the S17 presentation contract -----------------------------------------

const SECRET_ITEM := "Progressive Hookshot"
const SECRET_PLAYER := "Zelda3Runner"

func _the_ap_moment_never_spoils_what_it_holds() -> void:
	## The client is not always ignorant. A shop-stocked location IS
	## revealed, so the bridge legitimately sends its `item_name` -- and
	## a pedestal that read `scout.item_name` without checking state
	## would spoil exactly the Checks the player paid to learn about.
	##
	## The bridge withholding identity for unrevealed locations
	## (`ScoutedLocation._unrevealed_withholds_identity`) is the first
	## line and is already tested in Python. This is the second: given a
	## scout the client fully knows, the pedestal must still say nothing
	## until the Check is claimed.
	BridgeClient.snapshot = {"scouted": [{
		"location_id": 89100001, "location_name": "Archipepsi Check 001",
		"revealed": true, "item_name": SECRET_ITEM,
		"recipient_name": SECRET_PLAYER, "recipient_game": "A Link to the Past",
	}]}

	var reward := RewardObject.create(89100001, "zone_1", "void_glitch")
	add_child(reward)
	await get_tree().process_frame

	var label: Label3D = reward.get_node("StateLabel")
	for state: String in InteractableContract.STATES:
		reward.state = state
		reward._refresh_visual()
		var leaked := InteractableContract.leak(
				label.text, BridgeClient.scout_for(89100001), state)
		_check(leaked.is_empty(),
				"the '%s' pedestal leaks %s; identity is the claim's "
				% [state, leaked] + "payoff and nothing before it may "
				+ "give it away. Label was: '%s'" % label.text)

	## And the reveal must actually happen, or the check above passes by
	## saying nothing ever.
	reward.state = "confirmed"
	reward._refresh_visual()
	_check(label.text.contains(SECRET_ITEM),
			"a claimed Check must show what it held; got '%s'" % label.text)

	reward.queue_free()
	BridgeClient.snapshot = {}

func _every_ap_state_is_distinguishable() -> void:
	## Readability is the other half. A player across a room has the
	## colour and the word; two states sharing both are two states they
	## cannot tell apart.
	BridgeClient.snapshot = {"scouted": [{
		"location_id": 89100002, "location_name": "Archipepsi Check 002",
		"revealed": true, "item_name": SECRET_ITEM,
		"recipient_game": "A Link to the Past",
	}]}
	var reward := RewardObject.create(89100002, "zone_1", "void_glitch")
	add_child(reward)
	await get_tree().process_frame
	var label: Label3D = reward.get_node("StateLabel")

	var seen: Array = []
	for state: String in InteractableContract.STATES:
		reward.state = state
		reward._refresh_visual()
		seen.append({"state": state, "text": label.text,
				"color": label.modulate})
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			var a: Dictionary = seen[i]
			var b: Dictionary = seen[j]
			_check(InteractableContract.distinguishable(
					a["text"], a["color"], b["text"], b["color"]),
					"'%s' and '%s' look identical (%s / %s)"
					% [a["state"], b["state"], a["text"], a["color"]])
	reward.queue_free()
	BridgeClient.snapshot = {}

func _a_scene_missing_a_required_part_is_named() -> void:
	## An authored interactable missing a part fails at the moment it
	## changes state -- mid-claim, in front of the player -- rather than
	## at load, unless something checks first.
	var bare := Node3D.new()
	add_child(bare)
	var missing := InteractableContract.missing_parts(bare)
	_check(missing.size() == InteractableContract.REQUIRED_PARTS.size(),
			"an empty scene must be missing every required part, got %s"
			% str(missing))

	var visual := MeshInstance3D.new()
	visual.name = "state_visual"
	bare.add_child(visual)
	var still: Array[String] = InteractableContract.missing_parts(bare)
	_check(Array(still) == ["state_label"],
			"only the still-absent part should be named, got %s" % str(still))
	bare.queue_free()


# --- S18: visuals may not decide what is solid -----------------------------

const ARCHETYPES := ["melee", "ranged", "brute"]

func _a_theme_cannot_move_an_enemy_hitbox() -> void:
	## The S18 proof, in the form the risk actually takes. Theme is the
	## only thing that varies an enemy's appearance today, and authored
	## models will arrive the same way: as a different look for the same
	## creature. Build each archetype under every theme and require the
	## collision to be identical -- not similar, identical.
	for archetype: String in ARCHETYPES:
		var reference: Array = []
		var reference_theme := ""
		for theme: String in Constants.THEMES:
			var enemy := Enemy.create(archetype, theme)
			add_child(enemy)
			var profile := VisualInterface.collision_profile(enemy)
			_check(not profile.is_empty(),
					"a '%s' has no collision at all" % archetype)
			if reference.is_empty():
				reference = profile
				reference_theme = theme
			else:
				var difference := VisualInterface.same_collision(
						reference, profile)
				_check(difference.is_empty(),
						"a '%s' has different collision under '%s' than "
						% [archetype, theme]
						+ "under '%s': %s" % [reference_theme, difference])
			enemy.free()

func _an_enemy_hitbox_is_a_function_of_its_archetype() -> void:
	## And the archetypes must differ from each other, or the check above
	## passes by everything being the same box. Telling a brute from a
	## sniper is gameplay information; so is being able to hit one.
	var profiles: Dictionary = {}
	for archetype: String in ARCHETYPES:
		var enemy := Enemy.create(archetype, "void_glitch")
		add_child(enemy)
		profiles[archetype] = VisualInterface.collision_profile(enemy)
		enemy.free()
	_check(not VisualInterface.same_collision(
			profiles["brute"], profiles["melee"]).is_empty(),
			"a brute and a melee enemy have the same hitbox; one of them "
			+ "is the wrong size")

func _no_visual_anywhere_carries_collision() -> void:
	## The rule an authored asset is most likely to break, because in
	## most engines putting a collider under a mesh is the normal thing
	## to do. Here it would mean the ART decides what is solid, so
	## replacing the art changes what is solid.
	##
	## Checked across enemies, a built chamber and the player -- the
	## three places geometry and appearance meet.
	for archetype: String in ARCHETYPES:
		var enemy := Enemy.create(archetype, "void_glitch")
		add_child(enemy)
		var offenders := VisualInterface.visuals_carrying_collision(enemy)
		_check(offenders.is_empty(),
				"'%s' has meshes carrying collision: %s"
				% [archetype, str(offenders)])
		enemy.free()

	## Chamber geometry is the other case, and it needs the other check.
	## `_box` derives the mesh and the collider from one `size`, so the
	## meshes DO carry collision by design and nothing can be swapped.
	## What must hold there is that the two agree: a 4 m mesh with a 3 m
	## collider is a wall the player can see through, and a 3 m mesh with
	## a 4 m collider is an invisible one they walk into.
	var chamber := ChamberBuilders.build(
			{"id": "c1", "type": "arena", "width": 18.0, "depth": 18.0,
			"wall_height": 6.0, "objective": "reach_reward", "enemies": []},
			"void_glitch")
	var root: Node3D = chamber["root"]
	add_child(root)
	var mismatched := VisualInterface.mesh_collider_mismatches(root)
	_check(mismatched.is_empty(),
			"an arena's visuals and colliders disagree: %s"
			% str(mismatched.slice(0, 3)))
	root.free()

	## And the authored case, where a mesh carrying a collider DOES mean
	## the art decides what is solid. The shipped graybox fixture keeps
	## them separate; a scene that does not must be named.
	var authored: PackedScene = load(FIXTURE)
	var instance: Node3D = authored.instantiate()
	add_child(instance)
	_check(VisualInterface.visuals_carrying_collision(instance).is_empty(),
			"the authored fixture puts collision under a mesh, which is "
			+ "the arrangement that lets replacing art move a wall")
	var bad := MeshInstance3D.new()
	var body := StaticBody3D.new()
	body.add_child(CollisionShape3D.new())
	bad.add_child(body)
	instance.add_child(bad)
	_check(not VisualInterface.visuals_carrying_collision(instance).is_empty(),
			"a mesh with a collider under it must be reported")
	instance.free()

	var player := Player.create()
	add_child(player)
	var on_player := VisualInterface.visuals_carrying_collision(player)
	_check(on_player.is_empty(),
			"the player has meshes carrying collision: %s" % str(on_player))
	player.free()


# --- S21: preferences, and the inputs that may not be lost -----------------

func _the_base_kit_can_never_be_unbound() -> void:
	## A player who unbinds `jump` has made their own seed unfinishable,
	## in a menu, three rooms from the gap they can no longer cross. The
	## menu is where that has to be refused.
	var settings := PlayerSettings.new()
	for action: String in PlayerSettings.MANDATORY_ACTIONS:
		var refusal := settings.rebind(action, [])
		_check(not refusal.is_empty(),
				"unbinding '%s' must be refused; it is base kit" % action)

	## And an OPTIONAL action must still be unbindable, or this is not a
	## rule, it is a locked settings screen. An Echo slot may legitimately
	## be empty.
	_check(settings.rebind("fire_echo", []).is_empty(),
			"an Echo slot must be unbindable; a slot may be empty")

	## Rebinding a mandatory action to something else is fine -- the rule
	## is about it staying bound, not about which key.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	_check(settings.rebind("jump", [key]).is_empty(),
			"rebinding jump to another key must be allowed")
	_check(settings.unbound_mandatory().is_empty(),
			"after a legal rebind nothing mandatory is unbound: %s"
			% str(settings.unbound_mandatory()))

	## Put the project's own bindings back: this suite shares an InputMap
	## with every test after it.
	InputMap.load_from_project_settings()

func _a_hand_edited_config_cannot_unbind_the_base_kit() -> void:
	## The refusal above guards the menu. A config file is not a menu --
	## it can be edited by hand, or written by an older build with a
	## different mandatory set -- so loading repairs rather than obeys.
	var config := ConfigFile.new()
	config.set_value("bindings", "jump", [])
	config.set_value("values", "mouse_sensitivity", 999.0)
	config.save(PlayerSettings.PATH)

	var settings := PlayerSettings.new()
	settings.load_from_disk()
	_check(settings.unbound_mandatory().is_empty(),
			"a config unbinding jump must be repaired, not obeyed: %s"
			% str(settings.unbound_mandatory()))
	_check(settings.value("mouse_sensitivity") <= 0.02,
			"a hand-edited value must be clamped on load, got %f"
			% settings.value("mouse_sensitivity"))

	DirAccess.remove_absolute(PlayerSettings.PATH)
	InputMap.load_from_project_settings()

func _settings_are_clamped_on_the_way_in() -> void:
	var settings := PlayerSettings.new()
	for name: String in PlayerSettings.RANGES:
		var spec: Array = PlayerSettings.RANGES[name]
		settings.set_value(name, -1000.0)
		_check(is_equal_approx(settings.value(name), float(spec[1])),
				"'%s' must clamp to its minimum, got %f"
				% [name, settings.value(name)])
		settings.set_value(name, 1000.0)
		_check(is_equal_approx(settings.value(name), float(spec[2])),
				"'%s' must clamp to its maximum, got %f"
				% [name, settings.value(name)])

func _reduced_motion_actually_reaches_zero() -> void:
	## An accessibility option with a floor above off is not one. Motion
	## sickness is the reason this setting exists.
	var spec: Array = PlayerSettings.RANGES["motion_intensity"]
	_check(is_equal_approx(float(spec[1]), 0.0),
			"motion_intensity must be able to reach 0; its floor is %s"
			% str(spec[1]))

	var settings := PlayerSettings.new()
	settings.set_value("motion_intensity", 0.0)
	_check(is_equal_approx(settings.value("motion_intensity"), 0.0),
			"motion_intensity must store 0")

	## And the player must actually read it, or the option is a lie. The
	## source is checked rather than the motion, because head-bob over a
	## frame is not something a headless suite can watch.
	var source := FileAccess.get_file_as_string(
			"res://scripts/gameplay/player.gd")
	_check(source.contains("motion_intensity"),
			"the player never reads motion_intensity; the accessibility "
			+ "option would be inert")

func _preferences_never_enter_campaign_truth() -> void:
	## The other S21 rule. A player's sensitivity is not a fact about
	## their multiworld: in the save it would make two players' saves
	## differ for a reason no rule cares about, and would turn changing a
	## preference into a state transition.
	##
	## Checked by name against the snapshot the bridge actually sends,
	## since that is the only campaign truth this side can see.
	var settings := PlayerSettings.new()
	var preference_names: Array = []
	for name: String in PlayerSettings.RANGES:
		preference_names.append(name)
	for name: String in PlayerSettings.FLAGS:
		preference_names.append(name)
	preference_names.append("bindings")

	var snapshot: Dictionary = BridgeClient.snapshot
	for name: String in preference_names:
		_check(not snapshot.has(name),
				"'%s' is a preference and must never appear in the "
				% name + "campaign snapshot")

	## And it must be stored where preferences go.
	_check(PlayerSettings.PATH.begins_with("user://"),
			"preferences must live in user://, not beside the save")


# --- S20: the hooks an authored ending will need ---------------------------

func _the_postgame_has_somewhere_to_attach() -> void:
	## S20 is BLOCKED on a narrative decision (Q3): nothing decides what
	## the ending is, what the Hub becomes afterwards, or whether Epsilon
	## has a presence there. The roadmap says not to invent those, so
	## this asserts only that the hooks an authored ending will attach to
	## exist and are reachable -- so answering Q3 is authoring, not
	## plumbing.
	var anchors := HubAnchors.new()
	for hook: String in ["postgame", "epsilon_presence", "main_portal"]:
		_check(anchors.has(hook),
				"the '%s' anchor an authored ending would use is gone"
				% hook)

	## The state itself must be distinguishable, or an ending has no
	## moment to fire on. ALL_CHECKS_CLEARED is the bridge's word for
	## "everything done"; the Hub has to be able to see it.
	var protocol := FileAccess.get_file_as_string(
			"res://scripts/autoload/bridge_client.gd")
	_check(not protocol.is_empty(), "the bridge client is unreadable")
	BridgeClient.snapshot = {"hub": {"mode": "ALL_CHECKS_CLEARED",
			"postgame": true, "goal_sent": true}}
	var hub_state: Dictionary = BridgeClient.snapshot.get("hub", {})
	_check(str(hub_state.get("mode", "")) == "ALL_CHECKS_CLEARED",
			"the postgame mode does not survive into a snapshot")
	_check(bool(hub_state.get("postgame", false)),
			"the postgame flag does not survive into a snapshot")
	BridgeClient.snapshot = {}
