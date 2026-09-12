extends SceneTree
## The shot runner. One command, a JSON shot list, a folder of PNGs.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s shoot.gd -- <assets_root> <out_dir> <shotlist.json>
##
## or, in practice, `tools/shoot.sh <shotlist.json>`.
##
## ## Why this exists
##
## Every review image in this project so far came from a purpose-built
## script -- `ComposedRoom.gd`, `EnemyFamily.gd`, `AnchorUse.gd`,
## `StyleBoard.gd`, `EpsilonViews.gd`, `HubRoom.gd` -- each with its cameras
## written into GDScript. Moving one camera 40 cm meant editing a source
## file and re-running a build. Across Batch 002 that cost more wall-clock
## than the modelling did.
##
## A shot is data. It names a scene, a camera and some variants, and this
## runs the list. Adding one is a JSON object; nudging one is a number.
##
## ## The shot list
##
## ```json
## {
##   "defaults": { "size": [1440, 810], "lens": 24, "ambient": 0.10 },
##   "shots": [
##     { "name": "hub_spawn", "scene": "hub",
##       "eye": [0, 0, 3.0], "yaw": 0, "game_lens": true,
##       "caption": "THE HUB FROM SPAWN" },
##
##     { "name": "epsilon_wide",
##       "scene": "model:batch002/epsilon/epsilon_installation.glb",
##       "frame": 0.75, "azimuth": 0, "elevation": 4,
##       "variants": ["grey", "silhouette"] }
##   ]
## }
## ```
##
## ### Scenes
##
##   `hub`                 the Hub, from `hub_scene.gd` -- shell, fixtures,
##                         lights, all at hub.gd's own numbers
##   `hub + model:<...>`   the same, with assets standing in it
##   `void`                a backdrop and lights, nothing else
##   `model:<rel path>`    one .glb on the backdrop, floor-anchored at origin
##   `model:<a> + <b>`     several, in one frame. Each may carry an
##                         `@x,y,z` offset and a `#yaw` in degrees:
##                         `model:hall.glb + hall.glb@4,0,0#90`
##
## ### Camera, pick ONE of
##
##   `frame`     fraction of frame height the subject fills; distance solved
##   `orbit`     [radius, azimuth, elevation] around `target`
##   `eye`       [x, y, z] floor position; add `yaw` and optional `pitch`
##   `look`      [[from], [at]] -- the raw case
##
## `azimuth` and `elevation` apply to `frame` and `orbit`. `target` moves
## what is being looked at; it defaults to the subject's centre.
##
## ### Lens
##
##   `lens`        35 mm equivalent focal length. Default 24.
##
## ### Lighting
##
##   `ambient`     ambient light energy. Default 0.10.
##   `key_energy`  the three-light rig's key. Default 1.25. Lower it for an
##                 open-topped ROOM shell, where the key reaches a wall it
##                 would never reach on a backdrop. Both are scene-group
##                 options: they are read from the group's first shot.
##   `game_lens`   true to shoot at the engine's own fov instead. Use this
##                 for anything claiming to show what the player sees.
##
## ### Variants
##
## ### Backdrop
##
##   `backdrop`  "full" (default) floor and wall, "floor" for the slab
##               only, "none" for neither. Read from the FIRST shot of each
##               scene group, like `size` and `ambient`. A composed scene
##               brings its own walls and the bench's wall cuts through it.
##
## ### Variants
##
##   `grey`        the same frame desaturated -- does it compose without hue
##   `silhouette`  black on light -- shape read
##   `clay`        untextured -- form without surface
##   `guides`      thirds, centre and horizon over the lit frame
##
## Variants are derived from the SAME camera, and `grey` is derived before
## captions go on: desaturating a captioned frame measures the caption
## (ART_LESSONS L-38).

const DEFAULT_SIZE := Vector2i(1440, 810)

var _assets := ""
var _out := ""
var _list := {}
var _defaults := {}
var _made := 0
## The floor and wall the subject stands on. Tracked because the
## silhouette pass must not paint them black -- the first run produced a
## file called `_silhouette` that was a completely black rectangle, which
## is technically a silhouette of the backdrop.
var _backdrop: Array[MeshInstance3D] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: shoot.gd -- <assets_root> <out_dir> <shotlist.json>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)

	var f := FileAccess.open(args[2], FileAccess.READ)
	if f == null:
		push_error("shoot: cannot read %s" % args[2])
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("shoot: %s is not a JSON object" % args[2])
		quit(2)
		return
	_list = parsed
	_defaults = _list.get("defaults", {})

	var shots: Array = _list.get("shots", [])
	if shots.is_empty():
		push_error("shoot: the list has no shots in it")
		quit(2)
		return

	# Group by scene so a scene is built once however many shots use it.
	# The Hub is 300-odd nodes; rebuilding it per shot is most of the run.
	var order: Array = []
	var by_scene := {}
	for shot in shots:
		var scene: String = str(_opt(shot, "scene", "void"))
		if not by_scene.has(scene):
			by_scene[scene] = []
			order.append(scene)
		by_scene[scene].append(shot)

	for scene in order:
		await _run_scene(scene, by_scene[scene])

	print("[shoot] %d images -> %s" % [_made, _out])
	quit()


func _run_scene(scene: String, shots: Array) -> void:
	var size: Vector2i = _size(shots[0])
	var vp := ArtBench.make_viewport(self, size, float(_opt(shots[0], "ambient", 0.10)))
	var root := Node3D.new()
	vp.add_child(root)
	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	var rig := CameraRig.new(cam, size)

	var subject := _build(scene, root, vp,
			str(_opt(shots[0], "backdrop", "full")),
			float(_opt(shots[0], "key_energy", 1.25)))

	for shot in shots:
		await _take(shot, vp, root, rig, subject)

	vp.queue_free()
	await process_frame


## Returns the AABB of whatever the shots are about, in world space.
func _build(scene: String, root: Node3D, vp: SubViewport,
		backdrop: String = "full", key_energy: float = 1.25) -> AABB:
	_backdrop.clear()
	if scene == "hub" or scene.begins_with("hub +"):
		HubScene.build(root, _assets)
		# `hub + model:<...>` stands assets in the real room. A prop shot on
		# the bench's grey slab answers "what shape is it"; the same prop in
		# the Hub answers "can you see it", which for anything that has to
		# be TRACKED is the only question that matters.
		if scene.begins_with("hub +"):
			var rest := scene.substr(5).strip_edges()
			if rest.begins_with("model:"):
				rest = rest.substr(6)
			return _load_models(rest, root)
		# The Hub's subject is the room itself: 22 x 16 x 5 at hub.gd's
		# origin, which is not the room's centre.
		return AABB(Vector3(-11, 0, 0), Vector3(22, 5, 16))

	# Everything else stands on the backdrop.
	# `key_energy` is a scene-group option like `ambient`. The rig is
	# built for a subject standing on a backdrop, where the key clears
	# the model and dies on the floor. A ROOM the size of the rig's own
	# scale does not behave that way: a corridor's ceiling occludes the
	# key, and an open-topped shell -- an arena, a platform path -- lets
	# it hit one wall square-on and blow it out (L-56).
	ArtBench.add_lights(root, key_energy)
	var env: Environment = (vp.get_node("WorldEnvironment")
			as WorldEnvironment).environment
	env.background_color = Color(0.56, 0.57, 0.60)
	# Big enough to still be under and behind the camera at the Check's
	# review distance. At 60 x 40 the floor ended at z -34 and a camera at
	# -39.6 m stood off the end of it, so the bottom half of the frame was
	# the underside of the backdrop.
	# "full" (default) is a floor and a wall behind the subject. "floor"
	# drops the wall and "none" drops both, and neither is a nicety: a
	# COMPOSED scene -- a corridor run, a room built from modules -- brings
	# its own walls, and the bench's wall then stands at z 1.55 slicing
	# through the middle of it. That is what put a two-storey pale slab in
	# the centre of the first junction sheet, and it looked like a wall the
	# module was supposed to have.
	if backdrop != "none":
		_slab(root, Vector3(200, 0.2, 160), Vector3(0, -0.1, -64.0),
				Color(0.42, 0.43, 0.46))
	if backdrop == "full":
		_slab(root, Vector3(200, 44, 0.3), Vector3(0, 22, 1.55),
				Color(0.56, 0.57, 0.60))

	if scene.begins_with("model:"):
		return _load_models(scene.substr(6), root)

	return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))


## Load one or more glbs into `root` and return the union of their boxes.
##
## The spec is glbs joined by "+", each with an optional "@x,y,z" offset and
## "#yaw". Batch 005 is why several: reward.gd builds the Check out of a
## mast, an item and a ring as separate nodes, so a picture of one file is a
## picture of a third of a Check.
func _load_models(spec_list: String, root: Node3D) -> AABB:
	var loaded := 0
	var union := AABB()
	if true:
		for spec in spec_list.split("+", false):
			var at := Vector3.ZERO
			var yaw := 0.0
			var rel: String = spec.strip_edges()
			# `<path>[@x,y,z][#yaw]`. The yaw is what makes a corridor kit
			# photographable at all: a junction module's whole point is the
			# branch, and a branch runs along the axis the straights do not.
			if "#" in rel:
				var turn := rel.split("#")
				rel = turn[0].strip_edges()
				yaw = float(turn[1])
			if "@" in rel:
				var bits := rel.split("@")
				rel = bits[0].strip_edges()
				at = _vec(Array(bits[1].split(",")), Vector3.ZERO)
			var node: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, rel])
			if node == null:
				push_error("shoot: missing model %s" % rel)
				continue
			ArtBench.force_nearest(node)
			# Yawed to face -Z, which is where the cameras are. glTF maps
			# Blender +Y to -Z, so a face authored along Blender -Y leaves
			# the exporter pointing at +Z -- the mistake that made a whole
			# sheet of Epsilon views pictures of the back of the bank.
			node.rotation_degrees = Vector3(0, 180.0 + yaw, 0)
			# The offset is expressed in the SAME yawed frame as the model,
			# so `@-1.2,0,0` means "1.2 m to the VIEWER's left" -- which is
			# what anyone arranging four models on a shelf means by it. The
			# first run took the offsets in world space and rendered the
			# four Check states in reverse under a caption naming them
			# left to right (ART_LESSONS L-41, again).
			node.position = Vector3(-at.x, at.y, -at.z)
			root.add_child(node)
			# `node.transform * box`, and NOT `global_position + box.position`.
			# Two reasons, and the second one cost a wrong sheet:
			#
			#  * the node is yawed 180 degrees, so a local AABB's corner is
			#    not its world corner unless the transform is applied; and
			#  * `global_position` is ZERO for a node added this frame. The
			#    root had just been created and never processed, so every
			#    model after the first reported a box at the origin, the
			#    union came out one Check wide instead of four, and `frame`
			#    solved a distance that put half the sheet outside the
			#    picture -- while looking like a perfectly good photograph
			#    of two Checks.
			var here: AABB = node.transform * ArtBench.aabb_of(node)
			union = here if loaded == 0 else union.merge(here)
			loaded += 1
	if loaded == 0:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return union


func _take(shot: Dictionary, vp: SubViewport, root: Node3D,
		rig: CameraRig, subject: AABB) -> void:
	var name: String = str(shot.get("name", "shot_%d" % _made))

	if bool(_opt(shot, "game_lens", false)):
		rig.game_lens(float(_opt(shot, "fov", 90.0)))
	else:
		rig.lens(float(_opt(shot, "lens", 24.0)))

	var target: Vector3 = _vec(shot.get("target", []), subject.get_center())
	var az := float(_opt(shot, "azimuth", 0.0))
	var el := float(_opt(shot, "elevation", 0.0))

	if shot.has("look"):
		var pair: Array = shot["look"]
		rig.look(_vec(pair[0], Vector3.ZERO), _vec(pair[1], Vector3.ZERO))
	elif shot.has("eye"):
		rig.eye(_vec(shot["eye"], Vector3.ZERO), float(_opt(shot, "yaw", 0.0)),
				float(_opt(shot, "pitch", 0.0)),
				float(_opt(shot, "eye_height", 1.6)))
	elif shot.has("orbit"):
		var o: Array = shot["orbit"]
		rig.orbit(target, float(o[0]), float(o[1]), float(o[2]))
	else:
		rig.frame(subject, float(_opt(shot, "frame", 0.8)), az, el, target)

	if shot.has("dolly"):
		rig.dolly(float(shot["dolly"]))
	if shot.has("truck"):
		rig.truck(float(shot["truck"]))
	if shot.has("pedestal"):
		rig.pedestal(float(shot["pedestal"]))
	if shot.has("roll"):
		rig.roll(float(shot["roll"]))

	var lit: Image = await _grab(vp)
	var variants: Array = _opt(shot, "variants", [])

	# Derived BEFORE captions, always.
	if "grey" in variants:
		_save(_greyscale(lit), name + "_grey",
				"GREYSCALE - DOES IT COMPOSE WITHOUT COLOUR?", "",
				Color(1, 1, 1))
	if "guides" in variants:
		var g := Image.create_from_data(lit.get_width(), lit.get_height(),
				false, lit.get_format(), lit.get_data())
		CameraRig.guides(g, rig)
		_save(g, name + "_guides", "GUIDES - THIRDS, CENTRE, HORIZON", "",
				Color(1.0, 0.83, 0.36))

	_save(lit, name, str(_opt(shot, "caption", name.to_upper().replace("_", " "))),
			str(_opt(shot, "note", "")))

	# These two need the scene restyled, so they come last and are put back.
	if "silhouette" in variants or "clay" in variants:
		# `root` is passed in rather than fished out of the viewport: the
		# WorldEnvironment is child 0, so `vp.get_child(0)` is a
		# WorldEnvironment cast to Node3D, which is null, and the
		# silhouette pass then overrode nothing at all while still saving
		# a file called "_silhouette".
		var env: Environment = (vp.get_node("WorldEnvironment")
				as WorldEnvironment).environment
		var was := env.background_color
		if "silhouette" in variants:
			env.background_color = Color(0.78, 0.79, 0.82)
			for slab in _backdrop:
				slab.visible = false
			_override(root, ArtBench.flat_material(Color.BLACK))
			_save(await _grab(vp), name + "_silhouette", "SILHOUETTE", "",
					Color(0.2, 0.2, 0.2))
		if "clay" in variants:
			env.background_color = was
			_override(root, ArtBench.clay_material())
			_save(await _grab(vp), name + "_clay", "CLAY - FORM WITHOUT SURFACE")
		env.background_color = was
		for slab in _backdrop:
			slab.visible = true
		_restore(root)


func _save(image: Image, name: String, caption: String = "",
		note: String = "", colour: Color = Color(1.0, 0.83, 0.36)) -> void:
	if caption != "":
		ArtBench.label(image, caption, Vector2i(12, 12), colour)
	if note != "":
		ArtBench.label(image, note, Vector2i(12, 34), Color(0.72, 0.76, 0.80))
	image.save_png("%s/%s.png" % [_out, name])
	_made += 1
	print("[shoot] %s" % name)


func _greyscale(source: Image) -> Image:
	var out := Image.create(source.get_width(), source.get_height(), false,
			Image.FORMAT_RGB8)
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(x, y)
			var v: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			out.set_pixel(x, y, Color(v, v, v))
	return out


## Material overrides for the silhouette and clay passes, and the undo.
## Recorded per mesh rather than cleared, because a scene that came out of
## a .glb may legitimately have had an override already.
var _saved := {}

func _override(node: Node, mat: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and not _backdrop.has(child):
			if not _saved.has(child):
				_saved[child] = child.material_override
			child.material_override = mat
		_override(child, mat)

func _restore(node: Node) -> void:
	for mesh in _saved:
		if is_instance_valid(mesh):
			mesh.material_override = _saved[mesh]
	_saved.clear()


func _slab(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	_backdrop.append(m)
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	m.material_override = mat
	m.position = at
	root.add_child(m)


func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## A shot's own value, then the list's defaults, then the built-in.
##
## NOT named `_get`: Object already declares `_get(StringName)`, and an
## override with a different signature is a parse error rather than a
## shadowing warning.
func _opt(shot: Dictionary, key: String, fallback: Variant) -> Variant:
	if shot.has(key):
		return shot[key]
	if _defaults.has(key):
		return _defaults[key]
	return fallback


func _size(shot: Dictionary) -> Vector2i:
	var raw: Variant = _opt(shot, "size", [])
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return DEFAULT_SIZE


func _vec(raw: Variant, fallback: Vector3) -> Vector3:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return fallback
