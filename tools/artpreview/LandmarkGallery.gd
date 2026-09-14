extends "Landmarks.gd"
## Batch 023 -- per-place panel export, for presentation surfaces.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s LandmarkGallery.gd -- <assets_root> <out_dir>
##
## Same six places, same rig, same two viewpoints as the comparative
## sheets -- it calls Landmarks.gd's own _panel() rather than
## reimplementing it, so a gallery panel and its sheet cell cannot drift.
## What differs is only packaging: one file per place per view, at 3:2 so
## the framing is identical, and WITHOUT the burned-in captions, because a
## surface that sets its own typography should not inherit a contact
## sheet's.
##
## This renders the SAME PROPOSAL. It is not evidence of a second pass and
## it is not integration-ready; see Landmarks.gd's header and req 24.

const GALLERY := Vector2i(1200, 800)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: LandmarkGallery.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var f := FileAccess.open("%s/art_budgets.json" % _assets, FileAccess.READ)
	if f != null:
		_dim = JSON.parse_string(f.get_as_text()).get("dimensions", {})
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())

	var made := 0
	for name in ORDER:
		for view in [["eye", true], ["long", false]]:
			var img: Image = await _panel(name, GALLERY, bool(view[1]))
			if img == null:
				continue
			img.save_png("%s/%s_%s.png" % [_out, name, view[0]])
			made += 1
	print("[gallery] %d panels -> %s" % [made, _out])
	quit()
