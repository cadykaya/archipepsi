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
	_every_built_collider_matches_the_envelope_contract()
	_the_envelope_table_covers_the_whole_approved_family()
	await _a_telegraph_derives_from_the_real_attack_state()
	await _presentation_can_never_move_the_hitbox()
	_the_telegraph_attachment_point_is_the_contract()
	await _a_broken_promise_is_reported_rather_than_timed_out()
	_no_visual_anywhere_carries_collision()
	_a_shell_that_tells_the_truth_is_accepted()
	_a_shell_that_lies_about_its_geometry_is_refused()
	_an_unmeasurable_mandatory_route_is_refused()
	_an_optional_route_may_exceed_the_base_kit()
	_the_catalog_offers_only_authored_shells_and_is_sorted()
	_variant_selection_is_deterministic()
	_a_lying_shell_never_reaches_the_player()
	await _archipelago_truth_is_not_epsilon()
	_source_game_identity_survives_epsilon()
	_the_tier_arc_is_presentation_only()
	_a_pending_asset_cannot_ship_itself()
	_the_challenge_marker_hook_is_dormant_not_gone()
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

func _socket(socket_name: String = "entry") -> Dictionary:
	return {"name": socket_name, "kind": "doorway",
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

func _door(field: String, w: float, h: float,
		kind: String = "doorway") -> Dictionary:
	return {"name": field, "kind": kind, "position": [0.0, 0.0, 0.0],
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
	for key: String in PlayerSettings.RANGES:
		var spec: Array = PlayerSettings.RANGES[key]
		settings.set_value(key, -1000.0)
		_check(is_equal_approx(settings.value(key), float(spec[1])),
				"'%s' must clamp to its minimum, got %f"
				% [key, settings.value(key)])
		settings.set_value(key, 1000.0)
		_check(is_equal_approx(settings.value(key), float(spec[2])),
				"'%s' must clamp to its maximum, got %f"
				% [key, settings.value(key)])

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
	## Checked by key against the snapshot the bridge actually sends,
	## since that is the only campaign truth this side can see.
	var settings := PlayerSettings.new()
	var preference_names: Array = []
	for key: String in PlayerSettings.RANGES:
		preference_names.append(key)
	for key: String in PlayerSettings.FLAGS:
		preference_names.append(key)
	preference_names.append("bindings")

	var snapshot: Dictionary = BridgeClient.snapshot
	for key: String in preference_names:
		_check(not snapshot.has(key),
				"'%s' is a preference and must never appear in the "
				% key + "campaign snapshot")

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


# --- D1: the shell declares, Godot measures --------------------------------

const HONEST := "res://content/test_fixtures/shell_traversal_honest.tscn"
const LYING := "res://content/test_fixtures/shell_traversal_lying.tscn"

## The SAME manifest is used for both fixtures. That is the whole point:
## nothing in the metadata distinguishes the honest shell from the one
## that ships an unreachable jump, so only measuring can.
func _traversal_entry(mandatory: bool = true) -> Dictionary:
	return {
		"id": "shell_measured", "level": 3, "category": "room_shell",
		"display_name": "Measured", "procedural_fallback": false,
		"size_class": "medium",
		"sockets": [
			{"name": "entry", "kind": "doorway",
			 "position": [0.0, 0.0, 0.0], "width": 2.4, "height": 3.2},
			{"name": "exit", "kind": "doorway",
			 "position": [0.0, 0.0, 12.0], "width": 2.4, "height": 3.2},
		],
		"traversal": [{
			"name": "hop", "kind": "gap", "mandatory": mandatory,
			"start": [0.0, 0.0, 4.0], "end": [0.0, 0.8, 5.8],
		}],
	}

func _instantiate(path: String) -> Node3D:
	var scene: PackedScene = load(path)
	var node: Node3D = scene.instantiate()
	add_child(node)
	return node

func _a_shell_that_tells_the_truth_is_accepted() -> void:
	var instance := _instantiate(HONEST)
	var refusals := ShellValidator.refusals(_traversal_entry(), instance)
	_check(refusals.is_empty(),
			"an honest shell must validate: %s" % "\n".join(refusals))
	instance.free()

func _a_shell_that_lies_about_its_geometry_is_refused() -> void:
	## D1's load-bearing sentence: "do not trust an art asset merely
	## because its metadata claims it is safe." Both fixtures carry the
	## identical manifest declaring a 1.80 m hop at a 0.80 m rise. The
	## lying one actually places its far marker 3.40 m away across a
	## 1.00 m rise, where the base kit reaches 2.00 m.
	##
	## Python validated the manifest and was right to. The manifest was
	## never the problem.
	var instance := _instantiate(LYING)
	var refusals := ShellValidator.refusals(_traversal_entry(), instance)
	_check(not refusals.is_empty(),
			"a shell whose scene contradicts its manifest must be refused")

	var joined := "\n".join(refusals)
	_check(joined.contains("as built"),
			"the refusal must field what was MEASURED, not what was "
			+ "declared; got: %s" % joined)
	_check(joined.contains("safe reach"),
			"the refusal must field the bound it broke; got: %s" % joined)
	instance.free()

func _an_unmeasurable_mandatory_route_is_refused() -> void:
	## A shell that declares a mandatory jump and ships no markers cannot
	## be checked. Unverifiable is not the same as safe, and on the only
	## route through, the difference is a seed nobody can finish.
	var bare := Node3D.new()
	add_child(bare)
	var refusals := ShellValidator.refusals(_traversal_entry(), bare)
	_check(not refusals.is_empty(),
			"a mandatory route with no markers must be refused")
	_check("\n".join(refusals).contains("cannot be measured"),
			"the refusal must say WHY it could not be checked: %s"
			% "\n".join(refusals))
	bare.free()

func _an_optional_route_may_exceed_the_base_kit() -> void:
	## The other half, and the reason optional content exists. A perch
	## worth an Echo is supposed to be out of reach; refusing it would
	## make every shell base-kit-flat, which is the opposite of the
	## point.
	var instance := _instantiate(LYING)
	var refusals := ShellValidator.refusals(
			_traversal_entry(false), instance)
	for refusal: String in refusals:
		_check(not refusal.contains("safe reach"),
				"an OPTIONAL route must be allowed to exceed the base "
				+ "kit; got: %s" % refusal)
	instance.free()

func _the_catalog_offers_only_authored_shells_and_is_sorted() -> void:
	## Epsilon selects from what it is offered. The offer must exclude
	## procedural placeholders -- "pick an authored shell" cannot be
	## answered with a generator -- and must be stable, because the
	## catalog goes into a prompt and a prompt that reorders itself
	## regenerates differently from the same seed.
	var registry := _load([
		_authored_entry({"id": "arena_large_01", "size_class": "large"}),
		_authored_entry({"id": "arena_large_02", "size_class": "large"}),
		_authored_entry({"id": "arena_small_01", "size_class": "small"}),
		_entry({"id": "shell_arena_proc"}),
	])
	var all: Array[String] = ShellValidator.catalog(registry, "room_shell")
	_check(not all.has("shell_arena_proc"),
			"the catalog must not offer a procedural placeholder as an "
			+ "authored shell; got %s" % str(all))
	_check(Array(all) == ["arena_large_01", "arena_large_02",
			"arena_small_01"],
			"the catalog must be sorted and complete, got %s" % str(all))

	var large: Array[String] = ShellValidator.catalog(
			registry, "room_shell", "large")
	_check(Array(large) == ["arena_large_01", "arena_large_02"],
			"a size class must narrow the offer, got %s" % str(large))

func _variant_selection_is_deterministic() -> void:
	## "Pick a variant" is exactly where a stray randi() breaks the
	## promise that one seed lays out one campaign everywhere.
	var candidates: Array[String] = ["arena_large_02", "arena_large_01",
			"arena_large_03"]
	var first := ShellValidator.pick(candidates, "zone_3|arena")
	for i in 8:
		_check(ShellValidator.pick(candidates, "zone_3|arena") == first,
				"the same seed key must pick the same shell every time")
	## Order of the candidate list must not change the answer either --
	## a registry that enumerates differently is not a different seed.
	var shuffled: Array[String] = ["arena_large_03", "arena_large_01",
			"arena_large_02"]
	_check(ShellValidator.pick(shuffled, "zone_3|arena") == first,
			"candidate order must not change the pick")
	_check(ShellValidator.pick(candidates, "zone_4|arena") != ""
			, "a different seed key must still pick something")


func _a_lying_shell_never_reaches_the_player() -> void:
	## The validator is only worth having if the build path consults it.
	## A shell whose scene contradicts its manifest must degrade to the
	## placeholder rather than becoming a zone with a jump nobody can
	## make.
	var lying := _traversal_entry()
	lying["scene"] = LYING
	lying["id"] = "shell_arena_proc"      # the id the pipeline asks for
	var registry := _load([lying, _entry({"id": "shell_arena_backup"})])
	var chamber := {"id": "c1", "type": "arena", "width": 18.0,
			"depth": 18.0, "wall_height": 6.0, "enemies": []}
	var built := ContentInstantiator.build_chamber(chamber, "void_glitch",
			registry)
	var root: Node3D = built["root"]
	_check(root.name != "ShellTraversalLying",
			"a shell that failed measurement must not be instantiated "
			+ "into the zone; got '%s'" % root.name)
	_check(built.has("exit_offset"),
			"the degraded build must still produce a usable chamber")
	root.free()


# --- D6/D4: separate semantic layers ---------------------------------------

func _archipelago_truth_is_not_epsilon() -> void:
	## The decision, stated as a test because a strong visual language
	## pulls everything into itself. If a Check reads as an Epsilon
	## organ, the player loses the distinction the whole game is about:
	## this is somebody else's item, and Epsilon only interpreted it.
	_check(not VisualOwnership.reads_as_epsilon(
			VisualOwnership.CHECK_SIGNAL),
			"the Check signal reads as Epsilon's; Archipelago truth "
			+ "needs its own identity")
	var clash := VisualOwnership.collision(
			"Epsilon", VisualOwnership.EPSILON_SIGNAL,
			"Check", VisualOwnership.CHECK_SIGNAL)
	_check(clash.is_empty(), clash)

	## And the pedestal in the world must actually use its own layer
	## rather than borrowing Epsilon's.
	BridgeClient.snapshot = {"scouted": [{
		"location_id": 89100003, "location_name": "C", "revealed": false,
		"recipient_game": "A Link to the Past"}]}
	var reward := RewardObject.create(89100003, "zone_1", "void_glitch")
	add_child(reward)
	await get_tree().process_frame
	reward.state = "available"
	reward._refresh_visual()
	var label: Label3D = reward.get_node("StateLabel")
	_check(not VisualOwnership.reads_as_epsilon(label.modulate),
			"an available Check is painted in Epsilon's signal (%s); "
			% label.modulate + "Checks are Archipelago truth, not "
			+ "Epsilon's property")
	reward.queue_free()
	BridgeClient.snapshot = {}

func _source_game_identity_survives_epsilon() -> void:
	## The third layer. A Zone's colours come from the source game, and
	## the decision is explicit that advancing tiers must NOT wash them
	## in Epsilon green.
	var seen: Array = []
	for game: String in ["Super Mario 64", "Ocarina of Time",
			"Dark Souls III", "Bomb Rush Cyberfunk"]:
		var color := ThemeMaterials.color_for_game(game)
		_check(not VisualOwnership.reads_as_epsilon(color),
				"'%s' resolves to a colour that reads as Epsilon's (%s); "
				% [game, color] + "source-game identity must stay its own "
				+ "layer")
		seen.append(color)
	## And they must differ from EACH OTHER, or "per-game identity" is
	## one colour with four names.
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			_check(seen[i] != seen[j],
					"two source games share a colour; per-game identity "
					+ "stops identifying anything")

func _the_tier_arc_is_presentation_only() -> void:
	## D4 allows a Hub atmosphere arc and forbids it touching anything
	## else. Intrusion must rise across tiers...
	var early := VisualOwnership.hub_intrusion(0)
	var late := VisualOwnership.hub_intrusion(2)
	_check(early < late,
			"Epsilon should look more embedded late than early")
	_check(early > 0.0,
			"Epsilon is present from the start; it built the campaign")

	## ...and nothing outside the Hub may read it. A Zone built at tier 2
	## must be identical to the same Zone at tier 0, because the tier is
	## atmosphere and the Zone belongs to its source game.
	var source := FileAccess.get_file_as_string(
			"res://scripts/generation/zone_builder.gd")
	_check(not source.contains("hub_intrusion") and not source.contains("tier"),
			"zone generation reads the tier arc; generated Zones must "
			+ "keep their source-game identity at every tier")

func _a_pending_asset_cannot_ship_itself() -> void:
	## The art lane is in STYLE LOCK 001-R. A file existing in the tree
	## is not approval, and putting a pending asset in a zone decides a
	## question somebody else is still deciding.
	var pending := _authored_entry({"id": "shell_arena_proc",
			"review": "pending"})
	var registry := _load([pending, _entry({"id": "shell_arena_backup"})])
	var built := ContentInstantiator.build_chamber(
			{"id": "c1", "type": "arena", "width": 18.0, "depth": 18.0,
			"wall_height": 6.0, "enemies": []}, "void_glitch", registry)
	var root: Node3D = built["root"]
	_check(root.name != "ShellGrayboxFixture",
			"a PENDING asset was instantiated into a zone; review status "
			+ "is not advisory")
	root.free()

	## A passed asset ships normally, or the gate is a wall.
	var passed := _authored_entry({"id": "shell_arena_proc",
			"review": "pass"})
	var ok_registry := _load([passed])
	var ok_built := ContentInstantiator.build_chamber(
			{"id": "c1", "type": "arena", "enemies": []}, "void_glitch",
			ok_registry)
	_check((ok_built["root"] as Node3D).name == "ShellGrayboxFixture",
			"an approved asset must actually be used")
	(ok_built["root"] as Node3D).free()

func _the_challenge_marker_hook_is_dormant_not_gone() -> void:
	## Deliberately deferred (OWNER_DECISIONS). The hook stays so the
	## eventual semantics have somewhere to attach, and nothing may
	## depend on it in the meantime -- a dormant hook that something
	## quietly started using is how a deferred decision gets made by
	## accident.
	_check("challenge_marker" in LocalRewardPickup.KINDS,
			"the challenge_marker hook was removed from LocalRewardPickup.KINDS; "
			+ "it is deferred, not cancelled")

	## Nothing about AP truth or progression may depend on it. If it ever
	## does, the deferred decision has been made by accident.
	for source: String in ["res://scripts/gameplay/zone_controller.gd",
			"res://scripts/hub/hub.gd"]:
		var text := FileAccess.get_file_as_string(source)
		_check(not text.contains("challenge_marker"),
				"%s reads challenge_marker; no progression may depend on "
				% source + "a hook whose semantics are undefined")


## Art requirement 7. The contract is only worth something if the thing
## the engine actually BUILDS is the thing the contract describes --
## reading `enemy.gd` proves it asks for the right number, not that the
## collider ends up there. So this measures the node.
func _every_built_collider_matches_the_envelope_contract() -> void:
	for archetype: String in ARCHETYPES:
		var envelope: Dictionary = Constants.ENEMY_ENVELOPES[archetype]
		var enemy := Enemy.create(archetype, "concrete_facility")
		add_child(enemy)
		var shape: CollisionShape3D = null
		for child in enemy.get_children():
			if child is CollisionShape3D:
				shape = child
				break
		_check(shape != null, "'%s' has no CollisionShape3D" % archetype)
		if shape != null:
			var box := shape.shape as BoxShape3D
			_check(box != null,
					"'%s' collider is not a BoxShape3D" % archetype)
			if box != null:
				var want: Vector3 = envelope["size"]
				_check(box.size.is_equal_approx(want),
						"'%s' collider is %.3v, contract says %.3v"
						% [archetype, box.size, want])
			_check(absf(shape.position.y - float(envelope["centre_y"]))
					< 0.001,
					"'%s' collider centre is at y=%.3f, contract says %.3f"
					% [archetype, shape.position.y,
						float(envelope["centre_y"])])
		# ...and the enemy carries its own envelope, so anything that needs
		# the role's footprint asks rather than measuring the tree back out.
		_check(enemy.envelope.get("size", Vector3.ZERO)
				== envelope["size"],
				"'%s' did not keep its envelope" % archetype)
		enemy.free()

## The approved family is TEN. This suite only builds the three that have
## behaviour, so without this the export could quietly shrink back to the
## prototype trio and every test above would still pass.
func _the_envelope_table_covers_the_whole_approved_family() -> void:
	var approved := ["melee", "ranged", "brute", "charger", "bulwark",
			"scuttler", "artillery", "beacon", "diver", "drifter"]
	for role: String in approved:
		_check(Constants.ENEMY_ENVELOPES.has(role),
				"'%s' has no envelope; the approved art family is ten "
				% role + "roles and must not be reduced to three")
	_check(Constants.ENEMY_ENVELOPES.size() == approved.size(),
			"ENEMY_ENVELOPES holds %d roles, expected %d"
			% [Constants.ENEMY_ENVELOPES.size(), approved.size()])
	# Floor vs flying has to survive the crossing too: a flyer whose
	# `centre_y` came across as half its height would be buried.
	for role: String in ["diver", "drifter"]:
		var envelope: Dictionary = Constants.ENEMY_ENVELOPES[role]
		_check(bool(envelope["flying"]), "'%s' is not marked flying" % role)
		var size: Vector3 = envelope["size"]
		# `bottom_y` is what flying MEANS physically: the collider's
		# underside clear of the floor. Asserted directly rather than by
		# comparing a hover against half a height, which is a float
		# comparison that can land either way at the boundary.
		_check(float(envelope["bottom_y"]) > 0.0,
				"'%s' rests on the floor; it is not flying" % role)
	for role: String in ["melee", "brute", "bulwark", "scuttler"]:
		_check(not bool(Constants.ENEMY_ENVELOPES[role]["flying"]),
				"'%s' is marked flying" % role)
		_check(is_zero_approx(
				float(Constants.ENEMY_ENVELOPES[role]["bottom_y"])),
				"'%s' walks but does not touch the floor" % role)


## Art requirement 14: a telegraph is a promise, and a promise timed by a
## second clock is a promise broken by a rounding error. There is exactly
## one countdown -- the attack's -- and the presentation reads it.
func _a_telegraph_derives_from_the_real_attack_state() -> void:
	var enemy := Enemy.create("brute", "concrete_facility")
	add_child(enemy)
	var started: Array = []
	var finished: Array = []
	enemy.telegraph_started.connect(
			func(kind: String, duration: float) -> void:
				started.append([kind, duration]))
	enemy.telegraph_finished.connect(
			func(kind: String, completed: bool) -> void:
				finished.append([kind, completed]))

	_check(not enemy.is_telegraphing(),
			"a fresh enemy is already telegraphing something")
	_check(is_zero_approx(enemy.telegraph_progress()),
			"progress is non-zero with nothing being telegraphed")

	enemy._begin_telegraph("slam", 0.5)
	_check(started.size() == 1, "telegraph_started did not fire")
	if started.size() == 1:
		_check(started[0][0] == "slam" and absf(started[0][1] - 0.5) < 0.001,
				"telegraph_started carried %s" % str(started[0]))
	_check(enemy.is_telegraphing(), "the enemy is not telegraphing")
	_check(is_zero_approx(enemy.telegraph_progress()),
			"progress starts at %f, not 0" % enemy.telegraph_progress())

	# A second attack cannot open on top of the first: a windup that
	# started must always resolve, so a re-entrant start would strand it.
	enemy._begin_telegraph("slam", 5.0)
	_check(started.size() == 1,
			"a second telegraph opened on top of a running one")
	_check(absf(enemy.telegraph_duration - 0.5) < 0.001,
			"the re-entrant start overwrote the running duration")

	# Progress tracks the ATTACK's countdown, not wall time.
	enemy._windup = 0.25
	_check(absf(enemy.telegraph_progress() - 0.5) < 0.001,
			"halfway through the windup reads %f, not 0.5"
			% enemy.telegraph_progress())
	enemy._windup = 0.0
	_check(absf(enemy.telegraph_progress() - 1.0) < 0.001,
			"a finished windup reads %f, not 1.0"
			% enemy.telegraph_progress())

	enemy._end_telegraph(true)
	_check(finished.size() == 1 and bool(finished[0][1]),
			"a kept promise did not report completed")
	_check(not enemy.is_telegraphing(), "still telegraphing after the end")
	_check(is_zero_approx(enemy.telegraph_progress()),
			"progress survived the end of the telegraph")
	enemy.free()

## The bug this seam exists to make impossible. `scale` on a
## CharacterBody3D scales its CollisionShape3D child, so the brute's
## hitbox grew 12% for the half second it telegraphed and shrank to 88%
## every time it was hit. Presentation is never mechanics truth.
func _presentation_can_never_move_the_hitbox() -> void:
	var enemy := Enemy.create("brute", "concrete_facility")
	add_child(enemy)
	var before := VisualInterface.collision_profile(enemy)

	enemy._begin_telegraph("slam", 0.5)
	enemy._set_visual_scale(1.12)
	_check(VisualInterface.same_collision(
			before, VisualInterface.collision_profile(enemy)).is_empty(),
			"a windup swell moved the collider")
	_check(enemy.scale.is_equal_approx(Vector3.ONE),
			"the BODY was scaled; that is what moved the hitbox")
	_check(enemy.visual != null and enemy.visual.scale.x > 1.0,
			"the swell did not reach `visual` at all")

	enemy._set_visual_scale(0.88)
	_check(VisualInterface.same_collision(
			before, VisualInterface.collision_profile(enemy)).is_empty(),
			"a hit flinch moved the collider")
	enemy._end_telegraph(true)
	_check(enemy.visual.scale.is_equal_approx(Vector3.ONE),
			"the visual stayed swollen after the telegraph ended")

	_check(VisualInterface.visuals_carrying_collision(enemy).is_empty(),
			"something under `visual` carries collision")
	enemy.free()

	# Every mesh hangs off `visual` and nothing solid does -- which is
	# what makes the rule structural rather than a discipline. Checked for
	# EVERY archetype: each has its own `_build_*`, so checking one leaves
	# the other two free to parent onto the body.
	for archetype: String in ARCHETYPES:
		var built := Enemy.create(archetype, "concrete_facility")
		add_child(built)
		for child in built.get_children():
			if child is MeshInstance3D:
				_check(false,
						"'%s' parents a mesh (%s) to the BODY; scaling it "
						% [archetype, child.name]
						+ "for presentation would move the collider")
		var under_visual := 0
		for child in built.visual.get_children():
			if child is MeshInstance3D:
				under_visual += 1
		_check(under_visual > 0,
				"'%s' has no meshes under `visual` at all" % archetype)
		built.free()

## Art authors against an attachment point, so it has to be one point,
## in one place, derived from the same envelope the collider is.
func _the_telegraph_attachment_point_is_the_contract() -> void:
	for archetype: String in ARCHETYPES:
		var enemy := Enemy.create(archetype, "concrete_facility")
		add_child(enemy)
		_check(enemy.telegraph_origin != null,
				"'%s' has no TelegraphOrigin" % archetype)
		if enemy.telegraph_origin != null:
			var want := float(Constants.ENEMY_ENVELOPES[archetype]["centre_y"])
			_check(absf(enemy.telegraph_origin.position.y - want) < 0.001,
					"'%s' telegraph origin is at y=%.3f, the envelope "
					% [archetype, enemy.telegraph_origin.position.y]
					+ "centre is %.3f" % want)
			# Outside `visual`, or a flinch drags the telegraph with it.
			_check(enemy.telegraph_origin.get_parent() == enemy,
					"'%s' telegraph origin hangs off `visual`" % archetype)
		enemy.free()

	# The three placeable roles are all ground roles, so `centre_y` and
	# half the height are the SAME number for every one of them -- the
	# check above cannot tell the contract from the coincidence, and a
	# flyer cannot be built because it has no behaviour yet. So the source
	# is pinned instead: the origin comes from the envelope.
	var source := FileAccess.get_file_as_string(
			"res://scripts/enemies/enemy.gd")
	_check(source.contains(
			'origin.position = Vector3(0, float(envelope["centre_y"]), 0)'),
			"the telegraph origin is no longer taken from the envelope; "
			+ "half-height only agrees with it for a role that walks")

## Death and despawn mid-windup. The listener is TOLD, because a
## presentation left to time out finishes announcing a slam that is
## never coming.
func _a_broken_promise_is_reported_rather_than_timed_out() -> void:
	var enemy := Enemy.create("brute", "concrete_facility")
	add_child(enemy)
	var finished: Array = []
	enemy.telegraph_finished.connect(
			func(kind: String, completed: bool) -> void:
				finished.append([kind, completed]))
	enemy._begin_telegraph("slam", 0.5)
	enemy.die()
	_check(finished.size() == 1,
			"dying mid-windup reported %d telegraph endings, expected 1"
			% finished.size())
	if finished.size() == 1:
		_check(not bool(finished[0][1]),
				"a promise broken by death reported completed")
	_check(not enemy.is_telegraphing(), "a dead enemy is still telegraphing")

	# ...and despawn, which is the other way a telegraph outlives its
	# enemy. `_exit_tree` closes it.
	var despawned := Enemy.create("brute", "concrete_facility")
	add_child(despawned)
	var closed: Array = []
	despawned.telegraph_finished.connect(
			func(kind: String, completed: bool) -> void:
				closed.append(completed))
	despawned._begin_telegraph("slam", 0.5)
	remove_child(despawned)
	_check(closed.size() == 1 and not bool(closed[0]),
			"despawning mid-windup did not close the telegraph")
	despawned.free()
	await get_tree().process_frame
	enemy.queue_free()
