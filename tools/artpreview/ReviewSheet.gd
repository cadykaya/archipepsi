extends SceneTree
## The Archipepsi asset review sheet. One command, eight shots, identical for
## every asset so two of them can be compared rather than each being judged
## from its own best angle.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s ReviewSheet.gd -- <abs.glb> <out.png> <label> <judge_distance_m>
##
## The eight, and what each is FOR:
##
##   1 front        the view everything gets tuned in, and therefore the one
##                  view that lies
##   2 three-quarter
##   3 side
##   4 rear         mario-3 shipped an approved model with a bare strip of
##                  skull no front view could ever have shown
##   5 silhouette   flat black, unlit. Removes paint, shading and colour at
##                  once. If the object only becomes itself once it is
##                  painted, the form is not finished
##   6 clay         untextured neutral. Paint hides form
##   7 scale        beside a 1.8 m player rod with a 1 m band on it
##   8 PLAY         at the distance the asset is actually judged from, with
##                  the MEASURED pixel height printed on it
##
## Shot 5 is the exam. Shot 8 is the one that decides whether the design
## works at all, and it is measured off the render rather than projected --
## a projected bounding box is how mario-3 got five identical numbers for
## five different poses.

const SHOT := Vector2i(420, 420)
const GAP := 6
const COLS := 4

var _bench := preload("res://artbench.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: ReviewSheet.gd -- <abs.glb> <out.png> <label> [dist_m]")
		quit(2)
		return
	var model_path: String = args[0]
	var out_path: String = args[1]
	var label: String = args[2]
	var judge_distance: float = float(args[3]) if args.size() > 3 else 0.0

	var subject: Node3D = ArtBench.load_glb(model_path)
	if subject == null:
		quit(1)
		return
	var filters: Dictionary = ArtBench.force_nearest(subject)

	var vp := ArtBench.make_viewport(self, SHOT)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root)
	root.add_child(subject)
	var box: AABB = ArtBench.aabb_of(subject)

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)

	# A ground plane, so an object is standing on something rather than
	# floating in a void. An object judged in a void is an object whose
	# contact with the floor nobody checked.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = ArtBench.flat_material(Color(0.10, 0.10, 0.12))
	ground.position = Vector3(0, box.position.y, 0)
	root.add_child(ground)

	var shots: Array = []
	var measured := 0

	# 1-4: the four turntable angles, textured.
	for entry in [["front", 0.0], ["34", 35.0], ["side", 90.0], ["rear", 180.0]]:
		ArtBench.frame_camera(cam, box, float(entry[1]), 12.0, 1.30, 40.0)
		shots.append([str(entry[0]), await _grab(vp)])

	# 5: silhouette. Black form on a LIGHT field, and the ground hidden.
	# The first version drew black on the bench's near-black background and
	# the shot was almost empty -- a silhouette test that cannot show a
	# silhouette. A silhouette against a lit FLOOR is no better: that is a
	# silhouette with a horizon line drawn through it.
	ground.visible = false
	var env: Environment = (vp.get_node("WorldEnvironment")
			as WorldEnvironment).environment
	var was_bg: Color = env.background_color
	var was_ambient: float = env.ambient_light_energy
	env.background_color = Color(0.78, 0.79, 0.82)
	env.ambient_light_energy = 0.0
	ArtBench.apply_override(subject, ArtBench.flat_material(Color.BLACK))
	ArtBench.frame_camera(cam, box, 35.0, 12.0, 1.30, 40.0)
	shots.append(["silhouette", await _grab(vp)])
	env.background_color = was_bg
	env.ambient_light_energy = was_ambient

	# 6: clay.
	ArtBench.apply_override(subject, ArtBench.clay_material())
	ground.visible = true
	ArtBench.frame_camera(cam, box, 35.0, 12.0, 1.30, 40.0)
	shots.append(["clay", await _grab(vp)])

	# 7: scale, against a real 1.8 m player rod.
	ArtBench.apply_override(subject, null)
	_restore_materials(subject, model_path)
	var rod := _player_rod()
	rod.position = Vector3(box.position.x + box.size.x * 0.5 + 0.9,
			box.position.y, 0.0)
	root.add_child(rod)
	var scale_box := box.merge(AABB(rod.position, Vector3(0.4, 1.8, 0.4)))
	ArtBench.frame_camera(cam, scale_box, 20.0, 6.0, 1.20, 40.0)
	shots.append(["scale 1.8m", await _grab(vp)])
	rod.queue_free()
	await process_frame

	# 8: the play-distance shot, in the GAME's lens and at the GAME's eye
	# height, with the measured height printed on it.
	if judge_distance > 0.0:
		cam.fov = 90.0
		var centre := box.get_center()
		var eye := Vector3(0.0, 1.6, judge_distance)
		cam.look_at_from_position(eye, Vector3(centre.x, centre.y, centre.z),
				Vector3.UP)
		# Measure with the ground HIDDEN. The first version measured the
		# render with the floor in it, so it reported 694 px for a 1 m crate
		# that is genuinely 180 px -- a bench measuring the one thing that
		# fills the frame whatever the subject does. Then re-render WITH the
		# ground for the picture, because contact with the floor is part of
		# what the shot is for.
		ground.visible = false
		var measure_image: Image = await _grab(vp)
		measured = ArtBench.measured_height_px(measure_image)
		ground.visible = true
		var play_image: Image = await _grab(vp)
		# The bench renders at 420 px tall; the number the art bible quotes
		# is for a 1080p screen, so scale it there rather than quoting a
		# figure nobody plays at.
		var at_1080 := int(round(float(measured) * 1080.0 / float(SHOT.y)))
		ArtBench.label(play_image, "%.0f M  %d PX" % [judge_distance, at_1080],
				Vector2i(8, SHOT.y - 22), Color(1.0, 0.83, 0.36))
		shots.append(["play %.0fm" % judge_distance, play_image])

	_composite(shots, out_path, label, filters)
	print("[sheet] %s -> %s (%d shots)" % [label, out_path, shots.size()])
	if measured > 0:
		print("[sheet]   measured %d px at %.0f m (bench %d px tall)"
				% [int(round(float(measured) * 1080.0 / float(SHOT.y))),
				judge_distance, SHOT.y])
	var histogram: Dictionary = filters["before"]
	var names := {"0": "NEAREST", "1": "LINEAR", "2": "NEAREST+MIP",
			"3": "LINEAR+MIP", "4": "NEAREST+MIP+ANISO", "5": "LINEAR+MIP+ANISO"}
	var parts: Array = []
	for key in histogram:
		parts.append("%s x%d" % [names.get(key, key), int(histogram[key])])
	if parts.is_empty():
		# A histogram with nothing in it means the walk found no materials at
		# all, which would make "forced 0" a report of success from a check
		# that never ran. Say so loudly instead.
		print("[sheet]   WARNING: no BaseMaterial3D found -- the filter check "
				+ "did not run and its result means nothing")
	else:
		print("[sheet]   texture filter as loaded: %s (forced to NEAREST+MIP: %d)"
				% [", ".join(parts), int(filters["forced"])])
	quit()

func _grab(vp: SubViewport) -> Image:
	await process_frame
	await process_frame
	return vp.get_texture().get_image()

func _restore_materials(node: Node, _path: String) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = null
		_restore_materials(child, _path)

## A 1.8 m rod banded every metre. The player's actual height, from
## PLAYER_HEIGHT -- an asset judged without one is an asset judged against
## nothing.
func _player_rod() -> Node3D:
	var rod := Node3D.new()
	for i in 18:
		var seg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.1, 0.12)
		seg.mesh = mesh
		seg.position = Vector3(0, 0.05 + i * 0.1, 0)
		var light := (i / 5) % 2 == 0
		seg.material_override = ArtBench.flat_material(
				Color(0.95, 0.72, 0.22) if light else Color(0.16, 0.13, 0.10))
		rod.add_child(seg)
	return rod

func _composite(shots: Array, out_path: String, label: String,
		filters: Dictionary) -> void:
	var rows := int(ceil(float(shots.size()) / float(COLS)))
	var header := 26
	var caption := 18
	var width := COLS * SHOT.x + (COLS + 1) * GAP
	var height := header + rows * (SHOT.y + caption + GAP) + GAP
	var sheet := Image.create(width, height, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.035, 0.035, 0.042))
	ArtBench.label(sheet, label, Vector2i(GAP + 2, 6), Color(1.0, 0.83, 0.36))
	var mat_count := 0
	for key in (filters["before"] as Dictionary):
		mat_count += int((filters["before"] as Dictionary)[key])
	var note := ("NO MATERIALS FOUND" if mat_count == 0
			else "MATS %d  NEAREST FORCED %d" % [mat_count, int(filters["forced"])])
	ArtBench.label(sheet, note, Vector2i(width - note.length() * 8 - GAP, 6),
			Color(0.22, 0.64, 0.60))
	for i in shots.size():
		var col := i % COLS
		var row := i / COLS
		var x := GAP + col * (SHOT.x + GAP)
		var y := header + row * (SHOT.y + caption + GAP)
		var image: Image = shots[i][1]
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHOT), Vector2i(x, y))
		ArtBench.label(sheet, str(shots[i][0]), Vector2i(x + 2, y + SHOT.y + 4),
				Color(0.72, 0.76, 0.80))
	var dir := out_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	sheet.save_png(out_path)
