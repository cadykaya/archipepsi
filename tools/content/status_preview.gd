extends SceneTree
## The status graphic kit, on real room geometry, under the game's own light.
##
##   godot --path godot -s _harness/status.gd -- <kit> <derelict> <models> <out>
##
## PRESENTATION SCAFFOLDING. NOT AN IMPLEMENTATION OF THE STATUS SYSTEM.
##
## Every status in this preview is a line in a hand-written table below. No
## roll is made, no duration counts down mechanically, no compound forms from
## a rule, nothing is applied to anything, and no §15.4 pipeline exists here.
## What is being demonstrated is whether the ART reads -- and the only honest
## way to demonstrate that is to put the art in a room and look at it.
##
## THE LIGHT IS THE SHIPPED MODEL AND NOT A STUDIO RIG. `ZoneBuilder` sets
## ambient 0.35 with fog; `ChamberBuilders` adds one `OmniLight3D` per fixture
## at `omni_range` 12.0 and no shadows. THERE IS NO DIRECTIONAL LIGHT IN A
## BUILT ZONE. An earlier preview in this lane lit an enclosed room with an
## unshadowed sun, which lit it THROUGH ITS WALLS and made every value
## judgement taken from it wrong. That mistake is not repeated: omnis only.
##
## WHAT A STILL CANNOT SHOW. These are static frames. They do not prove
## combat visibility, they do not prove the markers are flicker-free in
## motion, and they do not prove readability while the player is turning.
## The frame sequence at the end is twelve rendered frames of one change and
## is the nearest this can get; it is still not play.

const MARKER_PX := 32
const TIER_PROXIMATE_M := 12.0     # §33.10
const TIER_FULL_COUNT := 12        # §33.10 rule 2: the nearest twelve

var _kit: String
var _derelict: String
var _models: String
var _out: String
var _bench: GDScript
var _tex := {}
var _log := {}
var _legal := {}          ## status id -> the §15.2 target list, from the kit
var _checked := 0

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_kit = a[0]
	_derelict = a[1]
	_models = a[2]
	_out = a[3]
	_bench = load("res://_harness/artbench.gd") as GDScript
	_load_target_lists()
	_run.call_deferred()


func _load_target_lists() -> void:
	## §15.2's `targets` column, read from the kit's OWN metadata.
	##
	## THE PREVIEW MUST NOT BE ABLE TO CONTRADICT THE KIT IT IS PREVIEWING.
	## The first version of this file put `confused` on an oil drum and
	## `rooted` on a utility box. Both are actor-only, and status_kit.json
	## said so on the line above -- the metadata was right and the picture
	## was wrong, which is the worst way round because the picture is what
	## gets looked at. Every marker placed below now goes through
	## `_marker()`, which fails the run rather than render an illegal pair.
	var text := FileAccess.get_file_as_string("%s/status_kit.json" % _kit)
	var kit: Dictionary = JSON.parse_string(text)
	for raw: Variant in kit.get("glyphs", []):
		var g: Dictionary = raw
		_legal[g["id"]] = g["targets"]

# -- the shipped surface roles, per background -----------------------------

const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]
const PREFIX := "cl"

func _role_of(name: String) -> String:
	var stem := name
	var dot := stem.rfind(".")
	if dot > 0 and stem.substr(dot + 1).is_valid_int():
		stem = stem.substr(0, dot)
	if not stem.begins_with(PREFIX + "_"):
		return ""
	var tail := stem.substr(PREFIX.length() + 1)
	return tail if tail in ROLES else ""

func _field(ground: String, role: String) -> String:
	## `dark` wears Batch 042's derelict fields, which is the hardest ground
	## the kit has to survive: the wall is the palest large surface in the
	## room and the structure goes to near-black, so a marker has both a
	## bright field and a near-black one to sit against IN THE SAME SHOT.
	if ground == "dark":
		var d := {"floor": "derelict_floor", "wall": "derelict_wall",
				"ceiling": "derelict_wall", "trim": "derelict_trim",
				"accent": "derelict_accent", "hazard": "derelict_accent"}
		var f := "%s/%s.png" % [_derelict, d.get(role, "derelict_wall")]
		if FileAccess.file_exists(f):
			return f
	return "res://content/shells/shell_corner_left_room_concrete_facility_%s.png" % role

func _surface(ground: String, role: String) -> StandardMaterial3D:
	var key := "%s|%s" % [ground, role]
	if _tex.has(key):
		return _tex[key]
	var path := _field(ground, role)
	var img: Image
	if path.begins_with("res://"):
		var t := load(path) as Texture2D
		img = null if t == null else t.get_image()
	else:
		img = Image.load_from_file(path)
	var mat := StandardMaterial3D.new()
	if img != null:
		mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.resource_name = "%s/%s" % [ground, role]
	_tex[key] = mat
	return mat

func _bind(root: Node, ground: String) -> int:
	var missed := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var role := _role_of("" if src == null else src.resource_name)
			if role == "":
				missed += 1
				continue
			mi.set_surface_override_material(i, _surface(ground, role))
	return missed

# -- markers ---------------------------------------------------------------

func _status_of(image: String) -> String:
	## The status id inside a marker/glyph/example image name.
	for prefix: String in ["marker_", "glyph_"]:
		if image.begins_with(prefix):
			return "glyph_" + image.substr(prefix.length())
	if image.begins_with("example_"):
		# `example_slippery_38pct_player`
		var tail := image.substr("example_".length())
		return "glyph_" + tail.split("_")[0]
	return ""


func _assert_legal(image: String, kind: String) -> void:
	var id := _status_of(image)
	if id == "" or not _legal.has(id):
		return                                  # a frame, a tick, an atlas
	var allowed: Array = _legal[id]
	if kind not in allowed:
		push_error("[status] ILLEGAL EXAMPLE: %s on a %s target. §15.2 "
				% [id.substr(6), kind]
				+ "allows %s only. The preview may not contradict the kit."
				% ", ".join(allowed))
		quit(3)
	_checked += 1


func _marker(parent: Node3D, at: Vector3, image: String,
		kind: String = "object") -> Sprite3D:
	## A world-anchored, screen-fixed marker.
	##
	## `fixed_size` is the whole argument for authoring at 32 px: the marker
	## occupies the same screen area at 3 m and at 11 m, so the size it was
	## DRAWN at is the size it is READ at, and a distant target does not get
	## a smaller, mushier version of the same picture -- it gets the reduced
	## treatment instead, which is a different picture (§33.10 rule 2).
	_assert_legal(image, kind)
	var s := Sprite3D.new()
	var img := Image.load_from_file("%s/png/%s.png" % [_kit, image])
	s.texture = ImageTexture.create_from_image(img)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.no_depth_test = false
	# 0.0032 puts the 32 px marker at 32 screen px in a 700 px tall viewport,
	# which is the size it was drawn at. The first pass used 0.0022 and the
	# reduced 16 px glyphs came out at about eleven pixels -- unreadable, and
	# a false negative about the reduced treatment rather than a true one.
	s.pixel_size = 0.0032
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	parent.add_child(s)
	s.global_position = at
	return s

# -- the target candidates -------------------------------------------------
#
# Existing Batch 001 / 010 props, reused rather than replaced. §15.1's five
# target kinds are ACTOR, PLAYER, OBJECT, SURFACE, VOLUME; three of them have
# a candidate in the current catalogue and two do not, and the preview says
# which is which rather than dressing a crate up as an enemy.

const TARGETS := {
	"crate": "batch001/props/prop_crate.glb",
	"drum": "batch010/dressing/prop_oil_drum.glb",
	"machinery": "batch001/props/prop_machinery_unit.glb",
	"utility": "batch001/props/prop_utility_box.glb",
	"terminal": "batch001/props/prop_terminal.glb",
	"debris": "batch001/props/prop_debris.glb",
}

func _top_of(node: Node3D) -> float:
	## The highest point of a target's visible geometry, in world Y.
	##
	## A marker parked at a fixed height above the floor sits ON a tall prop
	## and a metre above a low one. The first pass did exactly that and the
	## debris marker floated free of the debris. The AABB is cheap and it is
	## the only thing that makes one placement rule work for six props.
	var top := -INF
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.mesh.get_aabb()
		for i in 8:
			var corner: Vector3 = mi.global_transform * box.get_endpoint(i)
			top = maxf(top, corner.y)
	return 0.0 if top == -INF else top


func _stand_in(parent: Node3D, at: Vector3) -> Node3D:
	## An ACTOR-shaped hole, and it is drawn so nobody can mistake it for art.
	##
	## Eight of the twenty-one statuses are actor-only (§15.2), and Batch
	## 030's ten enemy roles are still unspawnable behind req 31 -- so there
	## is no approved actor to put them on. The alternative to this was
	## putting actor-only statuses on crates, which is what the first pass
	## did and it was wrong.
	##
	## Flat, unshaded, mid grey, no texture, no detail, and a label over its
	## head. It is a placement, not a proposal: nothing here is a sketch of
	## an enemy and no silhouette decision is being made.
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.72
	capsule.radial_segments = 8
	capsule.rings = 2
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.46, 0.50)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = mat
	parent.add_child(body)
	body.global_position = at + Vector3(0, 0.86, 0)
	var tag := Label3D.new()
	tag.text = "PREVIEW STAND-IN\nnot an enemy asset"
	tag.font_size = 44
	tag.pixel_size = 0.0016
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.86, 0.88, 0.91)
	tag.outline_size = 14
	tag.outline_modulate = Color(0.05, 0.06, 0.08)
	# Drawn in front of its own body and never occluded. A label that a
	# stand-in can hide behind is a label that stops saying "stand-in"
	# exactly when the picture starts looking like an enemy.
	tag.no_depth_test = true
	parent.add_child(tag)
	tag.global_position = at + Vector3(0, 0.34, 0.42)
	return body


func _target(parent: Node3D, kind: String, at: Vector3, yaw: float) -> Node3D:
	var node: Node3D = _bench.call("load_glb", "%s/%s" % [_models, TARGETS[kind]])
	if node == null:
		return null
	parent.add_child(node)
	node.global_position = at
	node.rotate_y(deg_to_rad(yaw))
	return node

# -- the room --------------------------------------------------------------

const FIXTURES := [
	{"at": Vector3(-1.8, 2.7, 1.6), "energy": 1.5},
	{"at": Vector3(1.8, 2.7, 4.4), "energy": 1.5},
]

func _light(holder: Node3D, ground: String) -> void:
	for raw: Variant in FIXTURES:
		var f: Dictionary = raw
		var lamp := OmniLight3D.new()
		holder.add_child(lamp)
		lamp.global_position = f["at"]
		lamp.light_energy = f["energy"]
		lamp.omni_range = 12.0
		lamp.shadow_enabled = false
		lamp.light_color = (Color(0.725, 0.812, 0.839) if ground == "dark"
				else Color(0.918, 0.949, 1.0))

func _env(holder: Node3D, ground: String) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = (Color(0.66, 0.75, 0.80) if ground == "dark"
			else Color(0.918, 0.949, 1.0))
	e.ambient_light_energy = 0.17 if ground == "dark" else 0.35
	e.fog_enabled = true
	e.fog_density = 0.012
	e.fog_light_color = e.ambient_light_color * 0.35
	env.environment = e
	holder.add_child(env)

# -- the persistent HUD tier (§33.10) --------------------------------------

func _hud(vp: SubViewport, size: Vector2i, focus_text: String,
		focus_at: Vector2, note: String) -> void:
	## The persistent tier, mocked, so the proximate tier can be judged
	## against something it is not allowed to cover. It is a MOCK: these are
	## rectangles standing in for Health, Barrier, the weapon and feed, the
	## five abilities and Mobility. No HUD is being designed here.
	var layer := Control.new()
	layer.size = Vector2(size)
	vp.add_child(layer)
	var ink := Color(0.08, 0.09, 0.11, 0.82)
	var lit := Color(0.93, 0.95, 0.96, 0.95)

	var box := func(r: Rect2, c: Color) -> void:
		var cr := ColorRect.new()
		cr.color = c
		cr.position = r.position
		cr.size = r.size
		layer.add_child(cr)

	var w := float(size.x)
	var h := float(size.y)
	# Health / Barrier, bottom left.
	box.call(Rect2(24, h - 78, 232, 54), ink)
	box.call(Rect2(30, h - 72, 180, 16), lit)
	box.call(Rect2(30, h - 50, 132, 10), Color(0.45, 0.72, 0.86, 0.95))
	# Ability row, bottom centre.
	for i in 5:
		box.call(Rect2(w * 0.5 - 150 + i * 62, h - 74, 52, 52), ink)
		box.call(Rect2(w * 0.5 - 146 + i * 62, h - 70, 44, 44),
				Color(0.22, 0.24, 0.27, 0.9))
	# Mobility + weapon/feed, bottom right and top left.
	box.call(Rect2(w - 176, h - 78, 152, 54), ink)
	box.call(Rect2(24, 24, 210, 46), ink)

	# The crosshair, which nothing in the proximate tier may cover.
	var ch := ColorRect.new()
	ch.color = Color(0.95, 0.97, 0.98, 0.9)
	ch.position = Vector2(w * 0.5 - 1, h * 0.5 - 9)
	ch.size = Vector2(2, 18)
	layer.add_child(ch)
	var ch2 := ColorRect.new()
	ch2.color = ch.color
	ch2.position = Vector2(w * 0.5 - 9, h * 0.5 - 1)
	ch2.size = Vector2(18, 2)
	layer.add_child(ch2)

	# §33.7: the sentence prints BESIDE THE TARGET, verbatim, on focus.
	if focus_text != "":
		var plate := ColorRect.new()
		plate.color = Color(0.06, 0.07, 0.09, 0.78)
		plate.position = focus_at + Vector2(26, -12)
		plate.size = Vector2(9.2 * focus_text.length() + 18, 26)
		layer.add_child(plate)
		var lab := Label.new()
		lab.text = focus_text
		lab.position = focus_at + Vector2(35, -10)
		lab.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
		lab.add_theme_font_size_override("font_size", 16)
		layer.add_child(lab)

	if note != "":
		var n := Label.new()
		n.text = note
		n.position = Vector2(26, h - 104)
		n.add_theme_color_override("font_color", Color(0.80, 0.84, 0.88))
		n.add_theme_font_size_override("font_size", 14)
		layer.add_child(n)

# -- a scene -----------------------------------------------------------------

func _scene(ground: String) -> Node3D:
	var world := Node3D.new()
	get_root().add_child(world)
	var shell := (load("res://content/shells/shell_corner_left.tscn")
			as PackedScene).instantiate()
	world.add_child(shell)
	var missed := _bind(shell, ground)
	_light(world, ground)
	_env(world, ground)
	if ground == "busy":
		# A cluttered room: the marker has to survive competing detail, not
		# only a flat wall. Nine props along both walls. The first pass put
		# three of them at z=5.5 and the camera stood INSIDE one -- every
		# `busy` frame was a photograph of the inside of a crate.
		var spots := [
			[Vector3(-2.4, 0, 1.0), 12.0, "machinery"],
			[Vector3(-2.5, 0, 2.6), 0.0, "utility"],
			[Vector3(-2.4, 0, 4.0), 40.0, "terminal"],
			[Vector3(2.5, 0, 1.2), -20.0, "drum"],
			[Vector3(2.5, 0, 2.4), 0.0, "crate"],
			[Vector3(2.4, 0, 3.8), 30.0, "debris"],
			[Vector3(-2.7, 0, 5.2), 0.0, "machinery"],
			[Vector3(2.7, 0, 5.2), 18.0, "utility"],
			[Vector3(-2.7, 0, 0.5), -14.0, "drum"],
		]
		for raw: Variant in spots:
			var s: Array = raw
			_target(world, s[2], s[0], s[1])
	_log["unresolved_%s" % ground] = missed
	return world

# -- shots -------------------------------------------------------------------

func _shot(world: Node3D, at: Vector3, look: Vector3, name: String,
		focus_text: String = "", focus_world := Vector3.INF,
		note: String = "") -> void:
	var size := Vector2i(1120, 700)
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.fov = 70.0
	holder.add_child(cam)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	var focus_screen := Vector2(size) * 0.5
	if focus_world != Vector3.INF:
		focus_screen = cam.unproject_position(focus_world)
	_hud(vp, size, focus_text, focus_screen, note)
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[status] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()

func _clear(world: Node3D) -> void:
	world.get_parent().remove_child(world)
	world.queue_free()

# -- the demonstration -------------------------------------------------------

func _run() -> void:
	for ground: String in ["bright", "dark", "busy"]:
		await _individual(ground)
		await _compound(ground)
		await _crowd(ground)
	await _frames()
	_log["legal_pairs_checked"] = _checked
	print("[status] %d status/target pairs checked against §15.2" % _checked)
	var f := FileAccess.open("%s/preview_log.json" % _out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_log, "  "))
	f.close()
	quit(0)

func _individual(ground: String) -> void:
	## One example per family, EVERY ONE ON A KIND §15.2 ALLOWS.
	##
	## KINETIC and MATERIAL have object-legal members, so they go on props.
	## PERMISSION has exactly one member that is not actor-only -- `phased`
	## -- so that is the one a crate may wear. COGNITIVE has none at all:
	## all four of its statuses are actor-only, so it goes on a stand-in.
	## That is not a limitation of the preview, it is what §15.2 says
	## COGNITIVE is.
	var w := _scene(ground)
	var rows := [
		[Vector3(-2.05, 0, 2.2), "crate", "marker_lightened",
		 "Lighter than it should be.", "KINETIC"],
		[Vector3(-0.75, 0, 2.5), "utility", "marker_phased",
		 "Passes through.", "PERMISSION"],
		[Vector3(2.05, 0, 2.2), "debris", "marker_burning",
		 "On fire, and setting fire.", "MATERIAL"],
	]
	var focus := Vector3.INF
	var text := ""
	for raw: Variant in rows:
		var r: Array = raw
		var base: Vector3 = r[0]
		var node := _target(w, r[1], base, 14.0)
		if node == null:
			continue
		var top := base
		top.y = _top_of(node) + 0.30
		_marker(w, top, r[2], "object")
		if r[4] == "PERMISSION":
			focus = top
			text = r[3]
	# COGNITIVE, on the only kind it is legal for.
	var actor := Vector3(0.7, 0, 3.0)
	_stand_in(w, actor)
	_marker(w, actor + Vector3(0, 1.95, 0), "marker_blinded", "actor")
	# And a SURFACE target, which is the third of §15.1's five kinds with
	# anything to stand on: `arc_path` is surface-only and this is the only
	# legal place in the room to show it.
	_marker(w, Vector3(-1.15, 0.22, 4.55), "marker_arc_path", "surface")
	# A partly spent duration and the player tick, on its own object target.
	var lone := Vector3(1.55, 0, 4.45)
	var lnode := _target(w, "crate", lone, -22.0)
	if lnode != null:
		_marker(w, Vector3(lone.x, _top_of(lnode) + 0.30, lone.z),
				"example_slippery_38pct_player", "object")
	await _shot(w, Vector3(0.1, 1.62, 5.9), Vector3(0.1, 1.30, 2.4),
			"STATUS_individual_%s" % ground, text, focus,
			"one per family, every pair legal under §15.2 | COGNITIVE is "
			+ "actor-only so it sits on a labelled stand-in | arc_path is "
			+ "surface-only, on the wall | 38% remaining with the tick")
	_clear(w)


func _compound(ground: String) -> void:
	var w := _scene(ground)
	# LEFT: a crate already carrying `lightened`, showing the §33.8 hint --
	# the missing component dimmed, beside what it would become.
	var a := Vector3(-1.2, 0, 2.4)
	var b := Vector3(1.2, 0, 2.4)
	var na := _target(w, "crate", a, 18.0)
	var nb := _target(w, "crate", b, -12.0)
	var ay := _top_of(na) + 0.30
	var by := _top_of(nb) + 0.30
	_marker(w, Vector3(a.x, ay, a.z), "marker_lightened", "object")
	_marker(w, Vector3(a.x, ay + 0.42, a.z), "hint_updraft_needs_burning",
			"object")
	# RIGHT: the same pair, resolved. `updraft` targets actor and object;
	# `lightened` and `burning`, its two components, are both object-legal,
	# so this whole sequence is legal on a crate.
	_marker(w, Vector3(b.x, by, b.z), "marker_updraft", "object")
	await _shot(w, Vector3(0.0, 1.60, 5.6), Vector3(0.0, 1.35, 2.4),
			"STATUS_compound_%s" % ground, "Rising on its own heat.",
			b + Vector3(0, 1.15, 0),
			"left: `lightened` + the §33.8 hint (dimmed `burning`, then"
			+ " `updraft`) | right: the compound, formed")
	_clear(w)

func _crowd(ground: String) -> void:
	## Sixteen marked targets: twelve objects and four actors.
	##
	## The split is not arbitrary -- §15.2 makes exactly twelve of the
	## twenty-one legal on an OBJECT, which is also §33.10 rule 2's
	## full-render count. The four actor-only ones ride stand-ins at the
	## back, which puts them past the twelve nearest and demonstrates the
	## reduced treatment on the targets that need it most.
	var w := _scene(ground)
	var kinds := ["crate", "drum", "utility", "debris"]
	var object_legal := ["lightened", "anchored", "slippery", "phased",
			"burning", "conductive", "brittle", "updraft", "grounded",
			"spreading", "suspended", "shatterpoint"]
	var actor_only := ["confused", "blinded", "silenced", "floundering"]
	var eye := Vector3(0.0, 1.62, 5.9)
	var placed := []
	var n := 0
	for ix in 4:
		for iz in 3:
			var p := Vector3(-2.4 + ix * 1.6, 0.0, 1.1 + iz * 1.35)
			var tn := _target(w, kinds[n % kinds.size()], p, 20.0 * n)
			placed.append({"at": Vector3(p.x, _top_of(tn) + 0.28, p.z),
					"id": object_legal[n], "kind": "object",
					"d": eye.distance_to(p)})
			n += 1
	for ia in 4:
		var p := Vector3(-2.1 + ia * 1.4, 0.0, 0.55)
		_stand_in(w, p)
		placed.append({"at": p + Vector3(0, 1.95, 0), "id": actor_only[ia],
				"kind": "actor", "d": eye.distance_to(p)})
	placed.sort_custom(func(x, y): return x["d"] < y["d"])
	var reduced := 0
	for i in placed.size():
		var e: Dictionary = placed[i]
		var far: bool = i >= TIER_FULL_COUNT or e["d"] > TIER_PROXIMATE_M
		_marker(w, e["at"], ("glyph_%s" % e["id"]) if far
				else ("marker_%s" % e["id"]), e["kind"])
		if far:
			reduced += 1
	_log["crowd_reduced_%s" % ground] = reduced
	await _shot(w, eye, Vector3(0.0, 1.20, 2.2), "STATUS_crowd_%s" % ground,
			"", Vector3.INF,
			"12 objects + 4 actor stand-ins | nearest %d full, %d reduced"
			% [TIER_FULL_COUNT, reduced]
			+ " to a single glyph (§33.10 rule 2) | crosshair and"
			+ " persistent tier clear | every pair legal under §15.2")
	_clear(w)


func _frames() -> void:
	## Twelve frames of one change: a duration running down, and a compound
	## forming at the end. Stills are what this delivery can honestly claim;
	## these twelve are assembled into a loop outside Godot so there IS
	## something to watch, and each frame stands alone.
	var w := _scene("bright")
	var at := Vector3(0.0, 0, 2.6)
	var tn := _target(w, "crate", at, 16.0)
	var top := Vector3(at.x, _top_of(tn) + 0.30, at.z)
	var hint := top + Vector3(0, 0.42, 0)
	for i in 12:
		var mk := _marker(w, top, "marker_lightened", "object")
		var hn: Sprite3D = null
		if i < 9:
			hn = _marker(w, hint, "hint_updraft_needs_burning", "object")
		if i >= 9:
			mk.texture = ImageTexture.create_from_image(
					Image.load_from_file("%s/png/marker_updraft.png" % _kit))
		await _shot(w, Vector3(0.0, 1.58, 5.2), Vector3(0.0, 1.34, 2.6),
				"SEQ_%02d" % i, "", Vector3.INF,
				"frame %d of 12 -- presentation scaffolding, not a mechanic"
				% (i + 1))
		mk.queue_free()
		if hn != null:
			hn.queue_free()
		await process_frame
	_clear(w)
