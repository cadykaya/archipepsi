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
	var weapon := String(weapons.get("current"))
	if node is Decal and String(node.name).begins_with("Mark_"):
		_mark.call_deferred(node, weapon)
	elif node is Node3D and String(node.name).begins_with("Impact_"):
		_impact.call_deferred(node, weapon)


func _impact(root: Node3D, weapon: String) -> void:
	if not is_instance_valid(root):
		return
	var kind := String(root.name).trim_prefix("Impact_")
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
	var at := root.global_position
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
			"frame": Engine.get_physics_frames(), "layers": names})


func _mark(decal: Decal, weapon: String) -> void:
	if not is_instance_valid(decal):
		return
	var kind := String(decal.name).trim_prefix("Mark_")
	var mat := String(MATERIAL_OF.get(kind, "stone"))
	var small := decal.size.x < 0.12            # a scattergun's stray chip
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
