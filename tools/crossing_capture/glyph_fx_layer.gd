extends Node
## THE LAYERED GLYPH WEAPON EFFECTS ON PROD'S FIVE-WEAPON RUNTIME.
## (Arty, 2026-10-14.) A reference adapter, used by the art lane's range
## captures; Prod's to adopt, rewrite or ignore -- the runtime is his.
##
## It plays `assets/fx/weapons/fx.json` (Batch 068's 37 Glyph sheets) on
## the events his v3 runtime already has, adding NO events:
##
##   fired      `RangeWeapons.shots` went up: the weapon's flash layers at
##              its `Muzzle` (they ride the kick), the afterglow; his own
##              procedural flame petals are hidden for that shot (the
##              authored flash replaces them), his light, smoke, shock
##              ring and recoil stay
##   impact     an `Impact_<kind>` node appeared (`RangeImpacts.impact`):
##              the authored 2D layers for that material and weapon, on
##              top of his 3D sparks, chips, fibres and light
##   mark       a `Mark_<kind>` Decal appeared (`RangeImpacts._mark`): its
##              texture becomes the authored mark for that material and
##              weapon (a random variant); his size, roll, parenting and
##              cap are kept
##
## Sheets are one row, frame 0 at the left; frames advance by
## `durations_ms`; NEAREST filtering; `add` or `mix` blending; `order` is
## the draw order (render priority).

## shared material sheets scale per weapon (the Batch 068 handoff)
const IMPACT_SCALE := {"foundry": 1.0, "sightline": 0.6, "switchback": 0.45,
	"bulkhead": 1.0, "driver": 1.0}
const MATERIAL_OF := {"metal": "metal", "stone": "stone", "wood": "wood",
	"organic": "flesh", "unknown": "stone"}

var fx := {}
var fx_dir := ""
var weapons: Node = null
var rig: Node3D = null
var events: Array = []
var _shots := 0
var _tex := {}
var _rng := RandomNumberGenerator.new()
var _done := {}


func setup(fx_json: String, the_weapons: Node) -> void:
	fx = JSON.parse_string(FileAccess.get_file_as_string(fx_json))
	fx_dir = fx_json.get_base_dir()
	weapons = the_weapons
	rig = weapons.get("rig")
	_shots = int(weapons.get("shots"))
	_rng.seed = 6800
	get_tree().node_added.connect(_on_node_added)


func _physics_process(_delta: float) -> void:
	if weapons == null:
		return
	var shots := int(weapons.get("shots"))
	if shots != _shots:
		_shots = shots
		_fired(String(weapons.get("current")), shots)
	# the authored flash replaces his petals for the shot's life
	var flame: Node3D = rig.get("flame")
	if flame != null and flame.visible:
		flame.visible = false


func _fired(weapon: String, shot: int) -> void:
	var muzzle: Node3D = (rig.get("muzzles") as Dictionary).get(weapon)
	if muzzle == null:
		return
	var names: Array = []
	match weapon:
		"foundry":
			names = ["foundry_flash_flare", "foundry_flash_core",
					"foundry_afterglow"]
		"sightline":
			names = ["sightline_flash"]
		"switchback":
			names = ["switchback_flash_a" if shot % 2 == 1
					else "switchback_flash_b"]
		"bulkhead":
			names = ["bulkhead_flash"]
		"driver":
			names = ["massdriver_release"]
	# a model with a mouth per barrel (the Fan's Bore0..3, children of its
	# Muzzle) flashes from each barrel, smaller; otherwise one flash
	var mouths: Array = []
	for child in muzzle.get_parent().find_children("Bore*", "", true, false):
		mouths.append(child)
	for n in names:
		var spec: Dictionary = fx[n]
		var delay := 0.034 if n == "foundry_afterglow" else 0.0
		if weapon == "bulkhead" and not mouths.is_empty():
			for m in mouths:
				_play(n, spec, m, Vector3.ZERO, 0.55, delay)
		else:
			_play(n, spec, muzzle, Vector3.ZERO, 1.0, delay)
	events.append({"event": "fired", "weapon": weapon, "shot": shot,
			"frame": Engine.get_physics_frames(), "layers": names})


func _on_node_added(node: Node) -> void:
	if weapons == null:
		return
	if node is Node3D:
		_classify.call_deferred(node, String(weapons.get("current")))


## By membership, not by name: Godot renames a node added beside a live
## sibling of the same name (`@Node3D@12`), so a second `Impact_metal` or
## a second `Mark_metal` on the same body loses its name. His own lists
## say what it is: `impacts.effects` holds the impact roots, `impacts.marks`
## the decals (each with its `mark_kind` meta).
func _classify(node: Node, weapon: String) -> void:
	if not is_instance_valid(node) or _done.has(node.get_instance_id()):
		return
	var impacts: Object = weapons.get("impacts")
	if node is Decal and (impacts.get("marks") as Array).has(node):
		_done[node.get_instance_id()] = true
		_mark(node, weapon)
	elif node is Node3D and (impacts.get("effects") as Array).has(node):
		_done[node.get_instance_id()] = true
		_impact(node, weapon)


## The material of an impact root or a mark.
func _kind(node: Node) -> String:
	if node.has_meta("mark_kind"):
		return String(node.get_meta("mark_kind"))
	var last: Dictionary = (weapons.get("impacts") as Object).get("last")
	if last.get("root") == node:
		return String(last.get("material", "unknown"))
	var n := String(node.name)
	if n.contains("Impact_"):
		return n.substr(n.find("Impact_") + 7).get_slice("@", 0)
	return "unknown"


func _impact(root: Node3D, weapon: String) -> void:
	if not is_instance_valid(root):
		return
	_impact_at(_kind(root), weapon, root.global_position, String(root.name))


## The authored layers for one hit of `kind` at `at`.
func _impact_at(kind: String, weapon: String, at: Vector3, node_name: String,
		orphan := false) -> void:
	var mat := String(MATERIAL_OF.get(kind, "stone"))
	var scale := float(IMPACT_SCALE.get(weapon, 1.0))
	var names: Array = []
	match weapon:
		"bulkhead":
			names = ["bulkhead_blast"]
		"driver":
			names = ["massdriver_impact"]
		_:
			match mat:
				"metal":
					names = ["impact_metal_flash", "impact_metal_smoke"]
				"stone":
					names = ["impact_stone_dust"]
				"wood":
					names = ["impact_stone_dust"]
				"flesh":
					names = ["impact_flesh_splash"]
			if weapon == "sightline":
				names.append("sightline_pop")
	for n in names:
		var spec: Dictionary = fx[n]
		var s := scale
		if weapon == "sightline" and n != "sightline_pop":
			s = 0.5
		if n == "impact_stone_dust" and mat == "wood":
			s *= 0.5
		_play(n, spec, get_tree().current_scene, at, s, 0.034 if
				n == "impact_metal_smoke" else 0.0,
				Color(0.85, 0.78, 0.66) if mat == "wood" else Color.WHITE)
	events.append({"event": "impact", "weapon": weapon, "material": kind,
			"node": node_name, "orphan": orphan,
			"frame": Engine.get_physics_frames(), "layers": names})


func _mark(decal: Decal, weapon: String) -> void:
	if not is_instance_valid(decal):
		return
	var kind := _kind(decal)
	# his Driver slug lands inside `tree_exiting`, when the scene refuses
	# new children: the impact root he made never entered the tree (no
	# sparks, light or sound of his). The authored layers then play from
	# the mark, where the impact was, and the log says so
	var last: Dictionary = (weapons.get("impacts") as Object).get("last")
	var root: Variant = last.get("root")
	if root is Node3D and is_instance_valid(root) \
			and not (root as Node3D).is_inside_tree() \
			and not _done.has((root as Node3D).get_instance_id()):
		_done[(root as Node3D).get_instance_id()] = true
		_impact_at(String(last.get("material", kind)), weapon,
				last.get("at", decal.global_position) as Vector3 \
				+ (last.get("normal", Vector3.ZERO) as Vector3) * 0.02,
				String((root as Node3D).name), true)
	var mat := String(MATERIAL_OF.get(kind, "stone"))
	# a scattergun's shot is one blast and one mark at the pattern's centre
	# (`impacts.last`), then up to three chips for strays (his `chip()`):
	# the centre gets the pattern, a chip a pock
	var last: Dictionary = (weapons.get("impacts") as Object).get("last")
	var centre: Vector3 = last.get("at", decal.global_position)
	var small := decal.global_position.distance_to(centre) > 0.01
	var name := ""
	match weapon:
		"bulkhead":
			name = "switchback_pock" if small else "bulkhead_mark"
		"driver":
			name = "massdriver_mark"
		"switchback":
			name = "switchback_pock"
		"sightline":
			name = "sightline_mark" if mat == "metal" else ""
	if name == "":
		name = {"metal": "decal_metal_hole", "stone": "decal_stone_crater",
				"wood": "decal_wood_mark", "flesh": "decal_flesh_mark"}[mat]
	var spec: Dictionary = fx[name]
	var frames := int(spec["frames"])
	var pick := _rng.randi_range(0, frames - 1)
	decal.texture_albedo = _frame_texture(name, spec, pick)
	events.append({"event": "mark", "weapon": weapon, "material": kind,
			"sheet": name, "variant": pick, "size": decal.size.x,
		"centre": not small,
			"frame": Engine.get_physics_frames()})


# ============================================================== playing

## One layer: a camera-facing quad that steps through the sheet's frames
## at its own timings, then goes (`once`).
func _play(name: String, spec: Dictionary, parent: Node, at: Vector3,
		scale: float, delay: float, tint := Color.WHITE) -> void:
	var frames := int(spec["frames"])
	var cell: Array = spec["cell"]
	var size := float(spec["size_m"]) * scale
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * float(cell[1]) / float(cell[0]))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if spec["blend"] == "add" \
			else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = _sheet(name, spec)
	m.albedo_color = tint
	m.uv1_scale = Vector3(1.0 / frames, 1.0, 1.0)
	m.render_priority = int(spec.get("order", 1))
	m.no_depth_test = false
	var node := MeshInstance3D.new()
	node.name = "Glyph_" + name
	node.mesh = quad
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = delay <= 0.0
	parent.add_child(node)
	if parent == get_tree().current_scene:
		node.global_position = at
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(node.show)
	var durations: Array = spec["durations_ms"]
	for i in frames:
		tween.tween_callback(func() -> void:
			m.uv1_offset = Vector3(float(i) / frames, 0.0, 0.0))
		tween.tween_interval(float(durations[mini(i, durations.size() - 1)])
				/ 1000.0)
	tween.tween_callback(node.queue_free)


func _sheet(name: String, spec: Dictionary) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var img := Image.load_from_file(fx_dir.path_join(String(spec["file"])))
	var t := ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


## One frame of a sheet as its own texture (a decal takes a whole image).
func _frame_texture(name: String, spec: Dictionary, i: int) -> Texture2D:
	var key := "%s#%d" % [name, i]
	if _tex.has(key):
		return _tex[key]
	var img := Image.load_from_file(fx_dir.path_join(String(spec["file"])))
	var cell: Array = spec["cell"]
	var part := img.get_region(Rect2i(int(cell[0]) * i, 0, int(cell[0]),
			int(cell[1])))
	var t := ImageTexture.create_from_image(part)
	t.resource_name = key
	_tex[key] = t
	return t
