extends Node
## D-11 — A ZONE'S GAME PACK, THROUGH THE REAL MATERIAL PATH (`--theme-pack`).
##
##     make godot-theme-pack
##
## `Zone.theme_pack` is consumed by the one loader there is: `ThemePack`,
## asked only by `ThemeMaterials`, asked by every builder. Each case below
## builds a real Zone through `ZoneController.setup` -- or the real Hub --
## and reads the albedo of the meshes the builders actually made. A lookup
## helper answering correctly would pass none of these on its own.
##
## **THE PACKS ARE DISPOSABLE AND TEST-SCOPED.** Their rows are the
## shipped descriptor's own rows for OTHER families, re-keyed under
## `test_pack_*` in an in-memory descriptor (`ThemePack.use_descriptor`),
## and their status comes from an in-memory registry
## (`ThemePack.use_pack_status`). No file is written, `THEME_PACK.json` is
## untouched, the production `THEME_PACK_STATUS` stays `{}`, and no pack
## is marked approved.

const FAMILY := "concrete_facility"
const PACK_A := "test_pack_a"      # selectable: wall + trim, and a forged hazard
const PACK_B := "test_pack_b"      # selectable: wall only
const PACK_C := "test_pack_c"      # candidate: authored, nameable by no Zone
const UNLISTED := "test_pack_z"    # not in the registry at all

var failures := 0
var checks := 0
var notes: Array[String] = []

## What each pack row points at, so a check can name the pixels it means.
var _wall := {}


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)


func _note(message: String) -> void:
	notes.append(message)
	print("  NOTE: " + message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--shots"):
		await _shots()
		return
	_check(Constants.THEME_PACK_STATUS.is_empty(),
			"the production registry selects no pack (THEME_PACK_STATUS "
			+ "is %s), and this suite adds none to it"
			% [Constants.THEME_PACK_STATUS])
	ThemePack.clear_pack_status()
	ThemePack.clear_descriptor()
	ThemeMaterials.reset_cache()
	var shipped := ThemePack.descriptor().duplicate(true)
	_check(ThemePack.bound() and not shipped.has(ThemePack.PACK_TABLE),
			"the shipped descriptor binds and carries no pack table")
	if not ThemePack.bound():
		_finish()
		return
	# THE BASELINE, before any pack table exists anywhere.
	var before := await _paths_of_zone(_zone(null))

	ThemePack.use_descriptor(_fixture_descriptor(shipped))
	ThemePack.use_pack_status({PACK_A: "selectable", PACK_B: "selectable",
			PACK_C: "candidate"})
	ThemeMaterials.reset_cache()

	await _no_pack_is_unchanged(before)
	await _the_exact_pack_role_wins()
	_a_missing_role_is_the_family_s()
	await _two_packs_over_one_family_do_not_share()
	await _no_pack_again_is_the_family_again(before)
	await _the_hub_is_no_zone_s()
	await _the_hazard_override_is_refused()
	await _only_a_nameable_pack_binds()

	ThemePack.clear_pack_status()
	ThemePack.clear_descriptor()
	ThemeMaterials.reset_cache()
	_check(ThemePack.pack_status(PACK_A) == ""
			and Constants.THEME_PACK_STATUS.is_empty(),
			"and when the suite is done, no test pack is known anywhere")
	_finish()


# ---------------------------------------------------------------------------
# The fixture
# ---------------------------------------------------------------------------

## The shipped descriptor plus a `pack_textures` table whose rows are the
## shipped rows of OTHER families: visibly different pixels, real files,
## digests that match -- and nothing new on disk.
func _fixture_descriptor(shipped: Dictionary) -> Dictionary:
	var out := shipped.duplicate(true)
	var textures: Dictionary = shipped.get("textures", {})
	var rows := {
		"%s/%s/wall" % [PACK_A, FAMILY]: "gothic_stone/wall",
		"%s/%s/trim" % [PACK_A, FAMILY]: "gothic_stone/trim",
		# FORGED: a pack painting the universal role.
		"%s/%s/hazard" % [PACK_A, FAMILY]: "temple_ruin/accent",
		"%s/%s/wall" % [PACK_B, FAMILY]: "neon_transit/wall",
		"%s/%s/wall" % [PACK_C, FAMILY]: "rusted_industrial/wall",
	}
	var table := {}
	for key: String in rows:
		table[key] = (textures[rows[key]] as Dictionary).duplicate()
	out[ThemePack.PACK_TABLE] = table
	for pack: String in [PACK_A, PACK_B, PACK_C]:
		_wall[pack] = _path_of(str((textures[rows["%s/%s/wall"
				% [pack, FAMILY]]] as Dictionary)["texture"]))
	_wall[""] = _path_of(str((textures["%s/wall" % FAMILY]
			as Dictionary)["texture"]))
	_wall["hazard"] = _path_of(str((textures["temple_ruin/accent"]
			as Dictionary)["texture"]))
	_wall["floor"] = _path_of(str((textures["%s/floor" % FAMILY]
			as Dictionary)["texture"]))
	_wall["trim_a"] = _path_of(str((textures["gothic_stone/trim"]
			as Dictionary)["texture"]))
	return out


func _path_of(rel: String) -> String:
	return "res://content/" + rel


## One arena, the family `concrete_facility`, and the pack named or not.
## No edges, so there is no layout verdict to wait on.
func _zone(pack: Variant) -> Dictionary:
	return {
		"schema_version": 7, "zone_id": "zone_pack", "seed": 11,
		"theme": FAMILY, "theme_pack": pack,
		"chambers": [{
			"id": "c001", "type": "arena", "theme": FAMILY,
			"width": 16.0, "depth": 14.0, "wall_height": 5.0,
			"objective": "kill_all", "reward_location_id": 89100002,
			"activities": [], "features": [], "enemies": [],
			"rewards": [], "interactables": [],
		}],
	}


# ---------------------------------------------------------------------------
# Building, and reading what was built
# ---------------------------------------------------------------------------

func _build(zone: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	get_tree().root.add_child(controller)
	controller.setup(zone)
	if controller.player != null:
		controller.player.stat_stack.pool = pool
	for _i in 2:
		await get_tree().physics_frame
	return controller


func _drop(node: Node) -> void:
	node.queue_free()
	for _i in 3:
		await get_tree().process_frame


## `albedo path -> [surfaces, one material]` over every mesh a builder
## made under `root`: the materials actually on the geometry.
func _painted(root: Node) -> Dictionary:
	var out := {}
	for node: Node in root.find_children("*", "MeshInstance3D", true,
			false):
		var material := (node as MeshInstance3D).material_override \
				as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var path := str(material.albedo_texture.resource_path)
		if not out.has(path):
			out[path] = [0, material]
		(out[path] as Array)[0] = int((out[path] as Array)[0]) + 1
	return out


func _paths_of_zone(zone: Dictionary) -> Dictionary:
	var controller := await _build(zone)
	var painted := _painted(controller)
	await _drop(controller)
	return painted


func _surfaces(painted: Dictionary, path: String) -> int:
	return int((painted[path] as Array)[0]) if painted.has(path) else 0


func _material(painted: Dictionary, path: String) -> Object:
	return (painted[path] as Array)[1] if painted.has(path) else null


## An identity, printed the way a reviewer reads it.
func _identity(role: String, pack: String) -> String:
	var answer := ThemePack.resolution(FAMILY, role, pack)
	var texture: Texture2D = answer.get("texture")
	return "%s/%s under %s -> source %s, key '%s', status '%s', %s" % [
		FAMILY, role, "'%s'" % pack if pack != "" else "no pack",
		str(answer["source"]), str(answer["key"]), str(answer["status"]),
		texture.resource_path if texture != null else "no texture"]


# ---------------------------------------------------------------------------
# The cases
# ---------------------------------------------------------------------------

## 1. NO PACK IS UNCHANGED -- even with a pack table in the descriptor.
func _no_pack_is_unchanged(before: Dictionary) -> void:
	print("  -- no pack: exactly what a Zone was painted with before")
	var painted := await _paths_of_zone(_zone(null))
	var same := painted.keys()
	same.sort()
	var was := before.keys()
	was.sort()
	_check(same == was and _surfaces(painted, _wall[""]) > 0,
			"a Zone naming no pack is painted from the same files as before "
			+ "the pack table existed (%d surfaces of the family wall)"
			% _surfaces(painted, _wall[""]))
	for path: Variant in same:
		if _surfaces(painted, str(path)) != _surfaces(before, str(path)):
			_check(false, "and on the same number of surfaces: %s %d vs %d"
					% [path, _surfaces(painted, str(path)),
						_surfaces(before, str(path))])
	var answer := ThemePack.resolution(FAMILY, "wall", "")
	_check(str(answer["source"]) == "family"
			and str(answer["key"]) == "%s/wall" % FAMILY,
			"IDENTITY %s" % _identity("wall", ""))


## 2. THE EXACT PACK ROLE WINS, on the geometry.
func _the_exact_pack_role_wins() -> void:
	print("  -- a selectable pack's exact row wins")
	var controller := await _build(_zone(PACK_A))
	_check(ThemeMaterials.bound_pack() == PACK_A,
			"setting up the Zone bound its pack ('%s')"
			% ThemeMaterials.bound_pack())
	var painted := _painted(controller)
	_check(_surfaces(painted, _wall[PACK_A]) > 0
			and _surfaces(painted, _wall[""]) == 0,
			"its walls are the pack's (%d surfaces of %s) and none is the "
			% [_surfaces(painted, _wall[PACK_A]), _wall[PACK_A]]
			+ "family's")
	_check(_surfaces(painted, _wall["trim_a"]) > 0,
			"and so is its trim (%d surfaces)" % _surfaces(painted,
				_wall["trim_a"]))
	var answer := ThemePack.resolution(FAMILY, "wall", PACK_A)
	_check(str(answer["source"]) == "pack"
			and str(answer["key"]) == "%s/%s/wall" % [PACK_A, FAMILY]
			and str(answer["status"]) == "selectable",
			"IDENTITY %s" % _identity("wall", PACK_A))
	# A MISSING ROLE, ON THE SAME GEOMETRY: the pack ships no floor.
	_check(_surfaces(painted, _wall["floor"]) > 0,
			"a role the pack does not ship is the family's: %d floor "
			% _surfaces(painted, _wall["floor"]) + "surfaces of %s"
			% _wall["floor"])
	await _drop(controller)


## 3. A MISSING ROLE YIELDS THE WHOLE ROLE TO THE FAMILY, hop and all --
## and the pack takes no hop of its own.
func _a_missing_role_is_the_family_s() -> void:
	print("  -- a missing role is the family's, and a pack takes no hop")
	var floor_answer := ThemePack.resolution(FAMILY, "floor", PACK_A)
	_check(str(floor_answer["source"]) == "family"
			and str(floor_answer["key"]) == "%s/floor" % FAMILY,
			"IDENTITY %s" % _identity("floor", PACK_A))
	# `metal` hops to `trim` in the family. The pack SHIPS a trim; a pack
	# hop would land on it. It must land on the family's trim instead.
	var metal := ThemePack.resolution(FAMILY, "metal", PACK_A)
	_check(str(metal["source"]) == "fallback"
			and str(metal["key"]) == "%s/trim" % FAMILY,
			"NO PACK HOP: %s -- not '%s/%s/trim', which the pack ships"
			% [_identity("metal", PACK_A), PACK_A, FAMILY])
	_check(ThemePack.resolution(FAMILY, "metal", "")["key"]
			== metal["key"],
			"which is exactly what the family answers with no pack at all")


## 4. TWO PACKS OVER ONE FAMILY NEVER SHARE A CACHED RESULT.
func _two_packs_over_one_family_do_not_share() -> void:
	print("  -- two packs over one family, one after the other")
	var first := await _build(_zone(PACK_A))
	var a_painted := _painted(first)
	var a_wall := _material(a_painted, _wall[PACK_A])
	await _drop(first)
	var second := await _build(_zone(PACK_B))
	var b_painted := _painted(second)
	_check(_surfaces(b_painted, _wall[PACK_B]) > 0
			and _surfaces(b_painted, _wall[PACK_A]) == 0,
			"the second Zone's walls are its own pack's (%s), with "
			% _wall[PACK_B] + "nothing of the first's")
	_check(a_wall != null and _material(b_painted, _wall[PACK_B]) != null
			and a_wall != _material(b_painted, _wall[PACK_B]),
			"and they are different materials, not one cache entry")
	_check(ThemePack.resolution(FAMILY, "wall", PACK_B)["key"]
			== "%s/%s/wall" % [PACK_B, FAMILY],
			"IDENTITY %s" % _identity("wall", PACK_B))
	await _drop(second)


## 5. BACK TO NO PACK IS BACK TO THE FAMILY, the very same material.
func _no_pack_again_is_the_family_again(before: Dictionary) -> void:
	print("  -- no pack again, after two packs")
	var controller := await _build(_zone(null))
	var painted := _painted(controller)
	_check(ThemeMaterials.bound_pack() == "",
			"a Zone naming no pack replaced the last pack's binding")
	_check(_surfaces(painted, _wall[""]) == _surfaces(before, _wall[""])
			and _surfaces(painted, _wall[PACK_A]) == 0
			and _surfaces(painted, _wall[PACK_B]) == 0,
			"its walls are the family's again, on the same %d surfaces"
			% _surfaces(painted, _wall[""]))
	await _drop(controller)


## 6. THE HUB IS NO ZONE'S -- built while a pack Zone is still standing,
## which is the order a hurried teardown can produce.
func _the_hub_is_no_zone_s() -> void:
	print("  -- the Hub, built while a pack Zone still stands")
	var zone := await _build(_zone(PACK_B))
	_check(ThemeMaterials.bound_pack() == PACK_B, "the Zone holds its pack")
	var hub := HubController.new()
	get_tree().root.add_child(hub)
	await get_tree().process_frame
	await get_tree().physics_frame
	var painted := _painted(hub)
	_check(ThemeMaterials.bound_pack() == "",
			"building the Hub bound no pack")
	_check(_surfaces(painted, _wall[""]) > 0
			and _surfaces(painted, _wall[PACK_B]) == 0
			and _surfaces(painted, _wall[PACK_A]) == 0,
			"the Hub (and the Echo Lab inside it) is painted from the family: "
			+ "%d family wall surfaces, none of either pack's"
			% _surfaces(painted, _wall[""]))
	# THE ZONE GOES AFTER THE HUB, and must not clear or reclaim anything.
	await _drop(zone)
	_check(ThemeMaterials.bound_pack() == "",
			"and the Zone leaving afterwards changed nothing")
	await _drop(hub)


## 7. THE UNIVERSAL ROLE CANNOT BE OVERRIDDEN BY A PACK.
func _the_hazard_override_is_refused() -> void:
	print("  -- a pack row painting hazard is refused")
	_check(ThemePack.pack_refusals(PACK_A)
			== ["%s/%s/hazard" % [PACK_A, FAMILY]],
			"the pack's hazard row is named as refused: %s"
			% [ThemePack.pack_refusals(PACK_A)])
	var answer := ThemePack.resolution(FAMILY, "hazard", PACK_A)
	_check(str(answer["source"]) == "universal" and answer["texture"] == null,
			"IDENTITY %s" % _identity("hazard", PACK_A))
	var controller := await _build(_zone(PACK_A))
	_check(not ThemeMaterials.is_authored(ThemeMaterials.hazard_mat(FAMILY)),
			"`hazard_mat` inside the pack's Zone is the shared one")
	_check(_surfaces(_painted(controller), _wall["hazard"]) == 0,
			"and no surface anywhere in that Zone wears the forged row's "
			+ "pixels (%s)" % _wall["hazard"])
	_check(_surfaces(_painted(controller), _wall[PACK_A]) > 0,
			"while the rest of the pack still binds")
	await _drop(controller)


## 8. ONLY A PACK A ZONE MAY NAME BINDS: candidate and unlisted do not,
## and neither does a family's name.
func _only_a_nameable_pack_binds() -> void:
	print("  -- a candidate or unlisted pack binds nothing")
	for pack: String in [PACK_C, UNLISTED]:
		var controller := await _build(_zone(pack))
		var painted := _painted(controller)
		var answer := ThemePack.resolution(FAMILY, "wall", pack)
		_check(_surfaces(painted, _wall[""]) > 0
				and (pack != PACK_C or _surfaces(painted, _wall[PACK_C]) == 0)
				and not bool(answer["pack_binds"])
				and str(answer["source"]) == "family",
				"'%s' (%s): the family paints the Zone -- IDENTITY %s"
				% [pack, "'%s'" % ThemePack.pack_status(pack)
					if ThemePack.pack_status(pack) != "" else "unlisted",
					_identity("wall", pack)])
		await _drop(controller)
	_check(not ThemePack.pack_binds(FAMILY),
			"and a pack id that is a family's name never binds")


# ---------------------------------------------------------------------------
# Rendered, for a reviewer (`make theme-pack-shots`; needs a display)
# ---------------------------------------------------------------------------

const SHOTS_DIR := "user://theme_pack_shots"

## THE SAME WALL, RENDERED, three times: no pack, pack A, pack B -- the
## same Zone built through the same `ZoneController`, a camera in the
## arena looking at its far wall. Diagnostic: it asserts nothing, and
## `godot-theme-pack` is what makes the claims. The light is SHOT
## LIGHTING (a key and a fill), as in `zone_shot_driver`.
func _shots() -> void:
	ThemePack.clear_pack_status()
	ThemePack.clear_descriptor()
	var shipped := ThemePack.descriptor().duplicate(true)
	ThemePack.use_descriptor(_fixture_descriptor(shipped))
	ThemePack.use_pack_status({PACK_A: "selectable", PACK_B: "selectable",
			PACK_C: "candidate"})
	ThemeMaterials.reset_cache()
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(SHOTS_DIR))
	for shot: Array in [["1_no_pack", null], ["2_" + PACK_A, PACK_A],
			["3_" + PACK_B, PACK_B]]:
		var controller := await _build(_zone(shot[1]))
		var box: AABB = controller.room_bounds.get("c001", AABB())
		var floor_y := box.position.y
		var camera := Camera3D.new()
		camera.fov = 70.0
		camera.current = true
		controller.add_child(camera)
		# From just inside the near wall, across the room and off its
		# centre line -- the reward pedestal stands in the middle, is
		# painted with `accent`, and filled the first frame.
		camera.global_position = Vector3(box.position.x + 1.5,
				floor_y + 2.2, box.get_center().z + 3.0)
		camera.look_at(Vector3(box.end.x, floor_y + 1.8,
				box.get_center().z + 3.0), Vector3.UP)
		for spec: Array in [[1.1, Vector3(-42.0, -35.0, 0.0)],
				[0.45, Vector3(-20.0, 140.0, 0.0)]]:
			var light := DirectionalLight3D.new()
			light.light_energy = float(spec[0])
			light.rotation_degrees = spec[1]
			controller.add_child(light)
		# THE SHOT'S CAMERA, not the player's: the Zone's player owns the
		# current camera, and the first version of this captured the
		# player's view three times over.
		if controller.player != null:
			controller.player.camera.current = false
		for _i in 3:
			camera.make_current()
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [SHOTS_DIR, str(shot[0])]
		image.save_png(ProjectSettings.globalize_path(path))
		print("  %s  %s" % [ProjectSettings.globalize_path(path),
				_identity("wall", "" if shot[1] == null else str(shot[1]))])
		await _drop(controller)
	ThemePack.clear_pack_status()
	ThemePack.clear_descriptor()
	ThemeMaterials.reset_cache()
	get_tree().quit(0)


func _finish() -> void:
	if failures == 0:
		print("GODOT THEME PACK TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT THEME PACK TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
