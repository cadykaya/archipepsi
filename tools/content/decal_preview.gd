extends SceneTree
## The wall layers and the decal kit, on real room geometry.
##
##   godot --path godot -s _harness/decals.gd -- <assets> <trial> <out>
##
## WHY CARDS AND NOT `Decal`. Godot's projected `Decal` node is a Forward+
## feature and does nothing in the Compatibility renderer, which is what
## Archipepsi ships. So a decal here is a surface-aligned quad: a `QuadMesh`
## rotated so its +Z is the receiving surface's normal, lifted off that
## surface by a hair, alpha-blended, and NOT writing depth.
##
## Three settings earn their place and each fixes something visible:
##   LIFT             a card coplanar with a wall z-fights and flickers as
##                    the camera moves. 6 mm is under the 1998 look's own
##                    tolerance and above the depth buffer's.
##   DEPTH_DRAW_DISABLED   two cards that overlap otherwise punch holes in
##                    each other depending on draw order.
##   TEXTURE_FILTER_NEAREST   a decal that is smoothed is a decal from a
##                    different game than the wall behind it.
##
## PREVIEW ONLY. Placements below are written out by hand, one per line,
## because this demonstrates the ART. Production owns the eventual runtime
## placement, the seed policy and any gameplay-effect lifecycle; nothing here
## proposes one.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const THEME := "concrete_facility"
const PREFIX := "cl"
const LIFT := 0.006
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]

var _assets: String
var _trial: String
var _out: String
var _cache := {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_assets = args[0]
	_trial = args[1]
	_out = args[2]
	_run.call_deferred()

# -- the wall layers, through Batch 041's per-surface override path ---------

func _role_of(name: String) -> String:
	var stem := name
	var dot := stem.rfind(".")
	if dot > 0 and stem.substr(dot + 1).is_valid_int():
		stem = stem.substr(0, dot)
	if not stem.begins_with(PREFIX + "_"):
		return ""
	var tail := stem.substr(PREFIX.length() + 1)
	return tail if tail in ROLES else ""

func _surface_material(role: String, glyph_field: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [role, str(glyph_field)]
	if _cache.has(key):
		return _cache[key]
	var path := "%s/textures/theme/%s_%s.png" % [_assets, THEME, role]
	if glyph_field and role == "wall":
		path = "%s/wall_field.png" % _trial
	# THE STRUCTURAL TRIM GOES ON THE TRIM ROLE, NOT ON A CARD.
	#
	# The first preview laid the skirting on as two quads at the floor
	# junction and it doubled up: `shell_corner_left` already HAS a kick rail
	# there, as authored geometry, wearing the `trim` role. A card over it is
	# two skirtings, and the clean render shows the one that was already
	# there. So the separated trim layer binds where the geometry is, and
	# cards are left for what has no geometry -- which is decals.
	if glyph_field and role == "trim":
		path = "%s/wall_skirt.png" % _trial
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(
			Image.load_from_file(path))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.resource_name = "%s/%s%s" % [THEME, role,
			"@glyph" if glyph_field and role == "wall" else ""]
	_cache[key] = mat
	return mat

func _bind(root: Node, glyph_field: bool) -> int:
	var unresolved := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var role := _role_of("" if src == null else src.resource_name)
			if role == "":
				unresolved += 1
				continue
			mi.set_surface_override_material(i,
					_surface_material(role, glyph_field))
	return unresolved

# -- ONE placement helper, and every placement goes through it -------------

func _card(parent: Node3D, texture: String, at: Vector3, normal: Vector3,
		metres: Vector2, spin_deg: float, tint: float = 1.0) -> MeshInstance3D:
	## A surface-aligned quad. `at` is ON the surface; the lift is applied
	## here so no caller can forget it and no caller can disagree about it.
	##
	## `spin_deg` turns the card around its own normal. It is the whole of
	## what "any rotation" means for a decal that allows it, and it is
	## refused by the manifest -- not by this function -- for one that does
	## not: an upright drip is upright because `decal_kit.json` says
	## `upright only`, and the caller reads that.
	var mesh := QuadMesh.new()
	mesh.size = metres
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(
			Image.load_from_file(texture))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Two cards that overlap must not punch holes in each other.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.95
	mat.albedo_color = Color(tint, tint, tint, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	# A quad faces +Z, so the basis is built with Z along the surface normal.
	var n := normal.normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var x := up.cross(n).normalized()
	var y := n.cross(x).normalized()
	mi.global_transform = Transform3D(Basis(x, y, n), at + n * LIFT)
	if not is_zero_approx(spin_deg):
		mi.rotate_object_local(Vector3.BACK, deg_to_rad(spin_deg))
	return mi

# -- the room's flat surfaces, from its own contract ------------------------
# floor centre (0,0,3), extent 6x6 -> x -3..3, z 0..6. The entry doorway is
# in the z=0 wall and the exit in the x=+3 wall, so the two unbroken walls
# are WEST (x=-3, normal +X) and NORTH (z=+6, normal -Z).
const WEST := -3.0
const NORTH := 6.0

func _dress(root: Node3D) -> Dictionary:
	var n := 0
	# THE SIX MARKS. Sizes are the manifest's metres, never a pixel count.
	# WEST WALL -- a drip from the 2.0 m joint, and grime gathering low.
	_card(root, "%s/decals/decal_drip.png" % _trial,
			Vector3(WEST, 2.05, 1.9), Vector3.RIGHT, Vector2(0.5, 1.5), 0.0)
	_card(root, "%s/decals/decal_grime.png" % _trial,
			Vector3(WEST, 1.15, 4.3), Vector3.RIGHT, Vector2(1.0, 1.0), 0.0)
	# NORTH WALL -- a scrape at hip height, and the stencil at eye height.
	_card(root, "%s/decals/decal_scuff.png" % _trial,
			Vector3(-1.4, 0.95, NORTH), Vector3.FORWARD, Vector2(0.75, 0.25), 0.0)
	_card(root, "%s/decals/decal_stencil.png" % _trial,
			Vector3(1.3, 1.65, NORTH), Vector3.FORWARD, Vector2(0.75, 0.5), 0.0)
	# FLOOR -- a burn and what came off it. Both allow any rotation, so both
	# are spun, which is the point of allowing it.
	_card(root, "%s/decals/decal_scorch.png" % _trial,
			Vector3(-0.4, 0.0, 3.4), Vector3.UP, Vector2(1.0, 1.0), 34.0)
	_card(root, "%s/decals/decal_splatter.png" % _trial,
			Vector3(0.8, 0.0, 2.5), Vector3.UP, Vector2(0.75, 0.75), 197.0)
	n += 6
	return {"cards": n}

# -- run -------------------------------------------------------------------

func _run() -> void:
	var packed := load(SHELL) as PackedScene
	var world := Node3D.new()
	get_root().add_child(world)

	var clean := packed.instantiate()
	var dressed := packed.instantiate()
	clean.name = "clean"
	dressed.name = "dressed"
	clean.position = Vector3(-40.0, 0.0, 0.0)
	world.add_child(clean)
	world.add_child(dressed)

	var uc := _bind(clean, true)
	var ud := _bind(dressed, true)
	var made: Dictionary = _dress(dressed)
	print("[decals] unresolved surfaces clean=%d dressed=%d | cards=%d"
			% [uc, ud, made["cards"]])

	# CLOSE, DISTANT and OBLIQUE, because a card that behaves at one distance
	# is not a card that behaves. Each pair is the SAME camera geometry
	# relative to its own instance, so the only difference is the dressing.
	var shots := [
		{"n": "wide", "at": Vector3(0.9, 1.7, 5.4), "to": Vector3(-1.4, 1.3, 1.2)},
		{"n": "close", "at": Vector3(-1.6, 1.5, 2.4), "to": Vector3(-3.0, 1.7, 2.1)},
		{"n": "oblique", "at": Vector3(2.2, 1.6, 5.2), "to": Vector3(-2.8, 0.9, 5.6)},
		{"n": "floor", "at": Vector3(1.6, 2.3, 5.0), "to": Vector3(-0.2, 0.0, 3.1)},
	]
	for raw: Variant in shots:
		var s: Dictionary = raw
		var at: Vector3 = s["at"]
		var to: Vector3 = s["to"]
		await _shot(world, at + Vector3(-40, 0, 0), to + Vector3(-40, 0, 0),
				"GODOT_%s_clean" % s["n"])
		await _shot(world, at, to, "GODOT_%s_dressed" % s["n"])
	quit(0)

func _shot(world: Node3D, at: Vector3, look: Vector3, name: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 720)
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
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.07, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# concrete_facility's own light colour, so a mark is judged under the
	# light the room has rather than under a neutral studio lamp.
	e.ambient_light_color = Color(0.918, 0.949, 1.0)
	e.ambient_light_energy = 0.55
	env.environment = e
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	holder.add_child(sun)
	sun.global_position = at + Vector3(0, 8, 0)
	sun.look_at(look, Vector3.UP)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[decals] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()
