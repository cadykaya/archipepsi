extends SceneTree
## Batch 029 -- PROPOSAL: the secret clue language.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s Secrets.gd -- <assets_root> <out_dir>
##
## THE SHEET IS THE TEST, and it is deliberately a game.
##
## A secret cue is a deviation from a pattern, so it cannot be photographed
## on its own -- every panel shows the whole repeating run WITH its single
## deviation somewhere in it. The captions name the pattern and the tier and
## deliberately DO NOT say which bay is wrong. If the reader cannot find it,
## that cue's tier is wrong, and that is the finding.
##
## The camera stands where a player would: 1.6 m eye, the game's own lens,
## raking along the run rather than square to it. A cue that only reads from a three-quarter hero angle
## is not a cue a player walking down a corridor will ever see.

const MODELS := "batch029/secrets"
## Batch 036 (029-R): EIGHT, not nine. `secret_repeated_motif` is gone --
## counting fine surface marks does not resolve at player distance in this
## rendering language, and that is a premise failure rather than a tuning
## one. A smaller reliable grammar beats a larger unreliable one.
const CUES := ["secret_construction_seam", "secret_displaced_panel",
		"secret_service_access", "secret_light_leak",
		"secret_partial_sightline", "secret_wear_traffic",
		"secret_broken_construction", "secret_unreachable_space"]
const TIERS := ["secret_tier_learning", "secret_tier_medium",
		"secret_tier_subtle"]

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: Secrets.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())
	await _cue_sheet()
	await _tier_sheet()
	print("[secrets029] 2 sheets -> %s" % _out)
	quit()

func _shoot(name: String, size: Vector2i, key: float) -> Image:
	var vp := ArtBench.make_viewport(self, size, 0.26)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, key)
	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("secrets029: missing %s" % name)
		vp.queue_free()
		return null
	ArtBench.force_nearest(node)
	root.add_child(node)
	var cam := Camera3D.new()
	cam.current = true
	# The game's own lens and eye height, but RAKING along the wall rather
	# than square to it. Two reasons, and the first pass got both wrong:
	#
	#   1. Square-on at 4.25 m put a 7.2 m wall in the middle 57% of the
	#      frame with floor filling the rest. Most of every panel was floor.
	#   2. More importantly, square-on is the WORST angle for a depth cue.
	#      A panel standing 14 cm proud of its neighbours is nearly
	#      invisible face-on -- it has no silhouette and casts no shadow
	#      you can see. And it is not even the representative angle: a
	#      player walks ALONG a corridor, so its walls are seen obliquely
	#      almost all of the time.
	#
	# Raking is therefore both the fairer test and the honest one.
	cam.fov = 90.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(4.45, 1.72, 2.30),
			Vector3(-1.20, 1.55, -0.10), Vector3.UP)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	await process_frame
	return img

func _cue_sheet() -> void:
	var cell := Vector2i(700, 470)
	# FOUR columns, two rows -- eight cues. This line and the `at` below
	# must agree, and once they did not: the index was moved to four
	# columns while the WIDTH stayed at three, so cues 4 and 8 were blitted
	# at x = 3 * cell.x, off the right edge, and the sheet silently showed
	# six of eight with a blank third row. It was re-rendered and not
	# looked at, which is L-24 exactly.
	var sheet := Image.create(cell.x * 4, cell.y * 2 + 140, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in CUES.size():
		var name: String = CUES[i]
		var e: Dictionary = _mf.get(name, {})
		var tier := str(e.get("tier", ""))
		# The learning tier gets more light on purpose -- it is the one a
		# player is meant to find, and "lit so you cannot miss it" is part
		# of what that tier MEANS rather than a rendering convenience.
		var key: float = 0.78 if tier == "learning" else (
				0.62 if tier == "medium" else 0.48)
		var img: Image = await _shoot(name, cell, key)
		if img == null:
			continue
		var at := Vector2i((i % 4) * cell.x, 140 + int(i / 4) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, str(e.get("cue", "")).to_upper().replace("_", " "),
				at + Vector2i(10, 10), Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, "PATTERN: %s" % str(e.get("the_pattern", "")),
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
		var tone := Color(0.45, 0.72, 0.68)
		if tier == "learning":
			tone = Color(0.34, 1.0, 0.12)
		elif tier == "subtle":
			tone = Color(0.94, 0.62, 0.42)
		ArtBench.label(sheet, "%s  /  %s" % [tier.to_upper(),
				str(e.get("theme", "")).to_upper()],
				at + Vector2i(10, cell.y - 26), tone)
	ArtBench.label(sheet, "A  EIGHT SECRET CUES -- FIND THE DEVIATION",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "A CUE IS NOT A THING, IT IS A DEVIATION FROM A "
			+ "PATTERN -- SO EVERY PANEL SHOWS THE WHOLE RUN AND THE ONE "
			+ "PLACE IT FAILS.", Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "THE CAPTIONS NAME THE PATTERN AND THE TIER AND "
			+ "DO NOT SAY WHICH BAY IS WRONG. IF YOU CANNOT FIND IT, THAT "
			+ "TIER IS WRONG.", Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "PLAYER EYE 1.6 M, THE GAME'S OWN 90 FOV, "
			+ "STRAIGHT ON. NO SECRET COLOUR. NO BEACON. PROPOSAL -- REQ 30.",
			Vector2i(12, 94), Color(0.60, 0.64, 0.68))
	sheet.save_png("%s/A_secret_cues.png" % _out)

func _tier_sheet() -> void:
	var cell := Vector2i(940, 620)
	var sheet := Image.create(cell.x * 3, cell.y + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in TIERS.size():
		var name: String = TIERS[i]
		var e: Dictionary = _mf.get(name, {})
		var tier := str(e.get("tier", ""))
		var key: float = 0.78 if tier == "learning" else (
				0.62 if tier == "medium" else 0.48)
		var img: Image = await _shoot(name, cell, key)
		if img == null:
			continue
		var at := Vector2i(i * cell.x, 116)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, tier.to_upper(), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, "DEVIATION AT %d%% -- KEY AT %.2f" % [
				int(float(e.get("tier_scale", 0.0)) * 100.0), key],
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "B  ONE CUE, THREE TIERS",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "THE SAME DISPLACED PANEL AT 100%, 50% AND 25%. "
			+ "TIERS ARE A MAGNITUDE, NOT THREE MORE CUES.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "THE LEARNING TIER IS ALSO LIT HARDER, BECAUSE "
			+ "'MEANT TO BE FOUND' IS PART OF WHAT THAT TIER IS.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/B_secret_tiers.png" % _out)
