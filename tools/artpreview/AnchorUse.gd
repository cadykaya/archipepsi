extends SceneTree
## Batch 002 E -- what each grapple anchor is FOR.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s AnchorUse.gd -- <assets_root> <out_dir>
##
## The 001-R review kept both anchors and gave them jobs:
##
##   A soffit  ceiling / common
##   B jib     wall / side / directional variant
##
## A review sheet shows an object; it cannot show a job. This shows the job:
## each anchor mounted where it is meant to be mounted, at the height it is
## meant to be mounted at, with a 1.8 m player rod standing where the player
## would stand and a marked arc showing where the swing goes.
##
## Every distance in the scene is read from engineering, never chosen:
##
##   player height / eye     1.8 m / 1.6 m
##   jump apex               how high you get WITHOUT a grapple
##   jump flat reach         how far you get without one
##   corridor height         where a ceiling anchor's plate goes
##
## which is the point of the shot. An anchor is only worth placing where it
## reaches somewhere a jump does not.

const SHOT := Vector2i(1400, 900)

var _assets := ""
var _out := ""
var _dim := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: AnchorUse.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	# The numbers come from the art budgets file, which derive_budgets.py
	# writes out of engine_truth. Nothing here is typed.
	var f := FileAccess.open("%s/art_budgets.json" % _assets, FileAccess.READ)
	if f == null:
		push_error("AnchorUse: no assets/art_budgets.json")
		quit(2)
		return
	_dim = JSON.parse_string(f.get_as_text()).get("dimensions", {})

	await _shot("A", "batch001/affordance/anchor_a_soffit.glb")
	await _shot("B", "batch002/affordance/anchor_b_wall_jib.glb")
	print("[anchoruse] 2 usage shots -> %s" % _out)
	quit()

func _num(key: String, fallback: float) -> float:
	return float(_dim.get(key, fallback))

func _shot(which: String, model: String) -> void:
	var ceiling := _num("corridor_height", 3.6)
	var apex := _num("jump_apex", 1.333)
	var reach := _num("jump_flat_reach", 4.667)
	var eye := _num("player_eye_height", 1.6)
	var tall := _num("player_height", 1.8)
	# The wall jib's plate height is an art PROPOSAL, and the manifest is
	# where it is recorded. Read it rather than repeating it here.
	var plate := 2.6
	if which == "B":
		var mf := FileAccess.open(
				"%s/models/batch002/affordance/manifest.json" % _assets,
				FileAccess.READ)
		if mf != null:
			var m: Dictionary = JSON.parse_string(mf.get_as_text())
			plate = float(m.get("anchor_b_wall_jib", {}).get(
					"proposed_plate_height_m", plate))

	var vp := ArtBench.make_viewport(self, SHOT, 0.30)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.25)

	# Floor, back wall, and -- for A -- a ceiling to hang from. Grey boxes:
	# this shot is about geometry and distance, not about the kit.
	# SHADED, not flat. Unshaded boxes at these values rendered the whole
	# scene as three dark silhouettes with the anchor floating in the
	# middle of them -- a diagram of nothing.
	_slab(root, Vector3(13, 0.2, 9), Vector3(0, -0.1, 0), Color(0.46, 0.47, 0.50))
	_slab(root, Vector3(13, 6, 0.3), Vector3(0, 3, 3.2), Color(0.58, 0.59, 0.62))
	if which == "A":
		_slab(root, Vector3(13, 0.3, 9), Vector3(0, ceiling + 0.15, 0),
				Color(0.52, 0.53, 0.56))

	var node: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, model])
	if node == null:
		push_error("AnchorUse: missing %s" % model)
		return
	ArtBench.force_nearest(node)
	if which == "A":
		# Ceiling-anchored: origin at the plate, which goes AT the ceiling.
		node.position = Vector3(0, ceiling, 0)
	else:
		# Wall-anchored: origin at the plate, which goes ON the wall.
		#
		# glTF maps Blender +Y to -Z, so the arm -- authored along Blender
		# -Y -- comes out of the export pointing at +Z, which is INTO a
		# wall standing at +Z. Without this yaw the shot is a plate on a
		# wall with the entire cantilever buried behind it, which is what
		# the first render showed.
		node.position = Vector3(0, plate, 3.05)
		node.rotation_degrees = Vector3(0, 180, 0)
	root.add_child(node)

	# The player, standing at the edge of what a JUMP already reaches. An
	# anchor inside that radius is decoration.
	_rod(root, Vector3(-reach, 0, 0), tall, Color(0.86, 0.88, 0.92))
	# And the height a jump already gets you, marked on the same rod: the
	# anchor has to be above this line to be worth anything.
	_box(root, Vector3(0.9, 0.03, 0.03), Vector3(-reach, tall + apex, 0),
			Color(1.0, 0.55, 0.25))

	# The swing arc, in cubes.
	#
	# The rope is the DROP from the ring to the player's eye, not the
	# straight-line distance to where they were standing. Using the latter
	# swung a 4.8 m pendulum that spent most of its arc underground.
	var ring := node.position + (Vector3(0, -0.78, 0) if which == "A"
			else Vector3(0, 0.06, -1.06))
	var rope: float = maxf(0.4, ring.y - eye)
	for i in 17:
		var t := i / 16.0
		# The plane the swing happens in: under a ceiling anchor the player
		# passes beneath it; off a wall jib they swing ALONG the wall, which
		# is the directionality the review asked to see.
		var ang := lerpf(-1.0, 1.0, t) * 1.05
		var p := ring + Vector3(sin(ang) * rope, -cos(ang) * rope, 0.0)
		_box(root, Vector3(0.13, 0.13, 0.13), p, Color(0.34, 1.0, 0.12))
	# And the rope itself at rest, so the arc is anchored to something.
	_box(root, Vector3(0.05, rope, 0.05), ring - Vector3(0, rope * 0.5, 0),
			Color(0.20, 0.62, 0.16))

	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)
	# One camera per shot. A jib projects OUT of its wall, so the ceiling
	# camera -- which looks along that same axis -- sees it end-on and the
	# arm, the brace and the whole reason the variant exists disappear into
	# a 20-pixel square. B is shot from the side instead.
	if which == "A":
		cam.look_at_from_position(Vector3(-6.4, 2.7, -4.6),
				Vector3(-1.6, 1.9, 1.2), Vector3.UP)
	else:
		# A three-quarter view, not a side one. The arm runs along -Z and
		# the swing arc spans X, so a camera aligned with either axis loses
		# one of the two things the shot exists to show.
		cam.look_at_from_position(Vector3(-5.6, 2.4, -2.4),
				Vector3(-1.0, 2.1, 1.9), Vector3.UP)

	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var gold := Color(1.0, 0.83, 0.36)
	var pale := Color(0.72, 0.76, 0.80)
	var teal := Color(0.45, 0.72, 0.68)
	if which == "A":
		ArtBench.label(img, "ANCHOR A SOFFIT - CEILING, COMMON",
				Vector2i(12, 12), gold)
		ArtBench.label(img, "PLATE AT CORRIDOR HEIGHT %.1f M. SWING PASSES UNDER IT."
				% ceiling, Vector2i(12, 34), pale)
	else:
		ArtBench.label(img, "ANCHOR B JIB - WALL, DIRECTIONAL",
				Vector2i(12, 12), gold)
		ArtBench.label(img, "PLATE AT %.1f M PROPOSED. SWING RUNS ALONG THE WALL."
				% plate, Vector2i(12, 34), pale)
	ArtBench.label(img, "ROD 1.8 M AT %.2f M - THE FLAT REACH OF A JUMP" % reach,
			Vector2i(12, img.get_height() - 46), pale)
	ArtBench.label(img, "ORANGE BAR: %.2f M JUMP APEX. THE ANCHOR MUST BEAT IT."
			% apex, Vector2i(12, img.get_height() - 24), teal)
	img.save_png("%s/E_anchor_%s_use.png" % [_out, which.to_lower()])
	vp.queue_free()
	await process_frame

## A lit slab: room surfaces, which need to show form.
func _slab(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	mat.metallic = 0.0
	m.material_override = mat
	m.position = at
	root.add_child(m)

## An unshaded marker: distances and arcs, which must not be shaded at all
## or a reader will mistake a dark face for a dim measurement.
func _box(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = ArtBench.flat_material(colour)
	m.position = at
	root.add_child(m)

## A 1.8 m human reference, banded at the eye line so the shot says which
## height matters.
func _rod(root: Node3D, at: Vector3, tall: float, colour: Color) -> void:
	_slab(root, Vector3(0.36, tall, 0.36), at + Vector3(0, tall * 0.5, 0),
			colour)
	_box(root, Vector3(0.42, 0.04, 0.42),
			at + Vector3(0, _num("player_eye_height", 1.6), 0),
			Color(0.25, 0.30, 0.36))
