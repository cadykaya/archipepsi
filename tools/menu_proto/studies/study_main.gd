extends Node3D
## THE DIRECTION STUDIES (Track A2, third ruling of 2026-09-27): the whole
## four-wall menu as ONE hand-built Echo device, four ways -- A patchbay,
## B harness, C relay cabinet, D salvaged workbench.
##
## An ISOLATED review scene. It builds the box with one direction's four
## faces from the very sample the prototype uses, and takes stills. It is
## not the prototype: it changes none of the prototype's faces, reads no
## input, and implements nothing a direction only draws.
##
##   godot --path tools/menu_proto res://studies/study.tscn -- --dir=A \
##       --state=normal --shots="equipment=/abs/eq.png;map=/abs/map.png"
##
## A shot is `<page>=<png>`, or `turn:<from>><to>@<0..1>=<png>` for the eye
## part-way through a page turn. Every direction shows the SAME state:
## * Equipment, RMB (Echo A) focused, BRAIDED LASH on it. `normal`: ARC BOLT
##   (the fixture's own) inspected against it. `stress`: the longest name,
##   with a long description, inspected against it.
## * Map: Arena 1 (c002) picked, MapFace's detail open, the Journal's link --
##   the shut way Arena 1 -> Platform Path 1, e:c002:c003 -- ringed.
## * Journal: that entry focused. Settings: Production's own items.

const SAMPLE := "res://sample/sample.json"
const DIRS := {"A": "res://studies/dir_a.gd", "B": "res://studies/dir_b.gd",
	"C": "res://studies/dir_c.gd", "D": "res://studies/dir_d.gd"}
const PROMPTS := {
	"equipment": [["move", "items"], ["accept", "preview on rmb"], ["out", "keys"],
		["wheel", "scroll"], ["turn_left", "turn left"], ["turn_right", "turn right"],
		["close", "close"]],
	"map": [["place", "places"], ["click", "pick"], ["detail", "less"],
		["overview", "overview"], ["zoom", "zoom"], ["orbit", "turn"],
		["turn_left", "turn left"], ["turn_right", "turn right"], ["close", "close"]],
	"journal": [["move", "entries"], ["move_h", "columns"], ["click", "pick"],
		["accept", "show on the map"], ["turn_left", "turn left"],
		["turn_right", "turn right"], ["close", "close"]],
	"settings": [["move", "rows"], ["change", "change"], ["accept", "change"],
		["turn_left", "turn left"], ["turn_right", "turn right"], ["close", "close"]],
}

var args := {}
var kit: Kit
var shell: Shell
var overlay: Overlay
var map: StudyMap
var direction: RefCounted
var ctx := {}
var _shots: Array = []
var _clock := 0.0
var _wait := 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Kit.BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#5c6570")
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	kit = Kit.new(_asset_dir())
	kit.reduced = args.has("reduced")
	shell = Shell.new()
	add_child(shell)
	shell.setup(kit)
	# The walls' titles are the prototype's; each direction sets its own.
	for page: String in Kit.PAGES:
		for c: Node in shell.face_of(page).get_children():
			if c is Label3D:
				c.queue_free()
	overlay = Overlay.new()
	add_child(overlay)
	overlay.setup(kit)
	var key := str(args.get("dir", "A")).to_upper()
	direction = load(DIRS[key]).new()
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	_context(sample, str(args.get("state", "normal")))
	direction.call("build", ctx)
	overlay.caption("DIRECTION STUDY %s -- %s -- AN ART-LANE STUDY, NOT THE GAME'S MENU"
			% [key, str(direction.call("title"))],
			"SAMPLE DATA: PRODUCTION A2B9DF6 FIXTURES, + LAYOUT-STRESS ECHOES "
			+ "TAGGED AUTHORED. A STILL COMPOSITION: NOTHING HERE IS WIRED.")
	for spec: String in str(args.get("shots", "")).split(";", false):
		var kv := spec.split("=", true, 1)
		_shots.append([kv[0], kv[1]])
	_aim(_shots[0][0] if not _shots.is_empty() else "equipment")


## The Glyph assets, where the prototype finds them.
func _asset_dir() -> String:
	var here := ProjectSettings.globalize_path("res://")
	for d: String in [here.path_join("ui"), here.path_join("../../assets/ui")]:
		if FileAccess.file_exists(d.path_join("ui_text.fnt")):
			return d.simplify_path()
	return here


## The fixed state every direction shows, as data -- never typed in.
func _context(sample: Dictionary, state: String) -> void:
	var eq: Dictionary = sample["equipment"]["stress"]
	var items := {}
	for row: Dictionary in eq["items"]:
		items[str(row["id"])] = row
	var keys: Array = eq["keys"]
	var seated := {}
	for k: Dictionary in keys:
		var holds: Variant = (k["view"] as Dictionary).get("holds")
		seated[str(k["slot"])] = "" if holds == null else str(holds)
	var slot := "echo_a"
	var equipped := str(seated[slot])
	var candidates := [equipped]
	for row: Dictionary in eq["items"]:
		var id := str(row["id"])
		if id != equipped and (row["fits"] as Array).has(slot):
			candidates.append(id)
	var passives := []
	for row: Dictionary in eq["items"]:
		if not bool(row["slotted"]):
			passives.append(str(row["id"]))
	var inspected := "act_bolt" if state == "normal" else "act_s_long"
	var s: Dictionary = sample["saves"]["walked"]
	var link := {"edge": "e:c002:c003"}
	map = StudyMap.new()
	map.setup(kit, shell)
	map.load_data(s["map"], sample)
	map.pose("c002", link, float(direction.call("map_shift")))
	var conn := {}
	for c: Dictionary in s["map"]["connectors"]:
		if str(c["edge_id"]) == "e:c002:c003":
			conn = c
	var names := {}
	for r: Dictionary in s["map"]["rooms"]:
		names[str(r["id"])] = str(r["name"])
	var circuit := str((conn.get("circuits", []) as Array)[0])
	# Each shut way's bead, as the Journal derives it: the connector's own
	# symbol and its first circuit's own colour.
	var beads := []
	for l: Dictionary in s["journal"]["links"].get("still_shut", []):
		var bead := {"icon": "exit", "colour": Kit.INK}
		for c: Dictionary in s["map"]["connectors"]:
			var circuits: Array = c.get("circuits", [])
			if str(c["edge_id"]) == str(l.get("edge_id", "")) \
					and str(c.get("state", "")) != "open" and not circuits.is_empty():
				bead = {"icon": FaceMap.SYMBOL_ICON.get(str(c.get("symbol", "")), "blocked"),
					"colour": Color(str((s["map"]["colours"] as Dictionary).get(
							str(circuits[0]), "#9ba5b6")))}
		beads.append(bead)
	ctx = {
		"kit": kit, "shell": shell, "overlay": overlay, "state": state,
		"faces": {"equipment": shell.face_of("equipment"), "map": shell.face_of("map"),
			"journal": shell.face_of("journal"), "settings": shell.face_of("settings")},
		"items": items, "keys": keys, "seated": seated, "slot": slot, "key_index": 0,
		"equipped": equipped, "inspected": inspected, "candidates": candidates,
		"passives": passives,
		"comparison": ((eq["comparisons"] as Dictionary).get(slot, {}) as Dictionary
				).get(inspected, {}).get(equipped, []),
		"map": map, "map_data": s["map"], "room": "c002",
		"detail": map.details_of("c002"), "link": link,
		"link_page": map.target_world(link).get("page", Vector2.ZERO),
		"journal": s["journal"],
		"link_text": str((s["journal"]["still_shut"] as Array)[0]),
		"explanation": ["BETWEEN %s AND %s" % [names[str(conn["room_a"])].to_upper(),
				names[str(conn["room_b"])].to_upper()],
			"HELD BY: " + circuit.split(":")[-1].replace("_", " ").to_upper(),
			"NOW: " + str(conn["state"]).to_upper(),
			"ON THE MAP, ROUND THE CORNER (E)"],
		"circuit": {"id": circuit, "colour": Color(str(s["map"]["colours"][circuit])),
			"icon": "circuit"},
		"beads": beads,
		# Production's own settings, at PlayerSettings' own defaults (a2b9df6).
		"settings": {
			"paused": ["RESUME", "RETURN TO HUB", "ABANDON ZONE…", "QUIT GAME"],
			"campaign": s["journal"]["campaign"],
			# [label, where the default sits on the slider's own range, words]
			"sliders": [["MOUSE SENSITIVITY", (0.0022 - 0.0002) / (0.02 - 0.0002), "100%"],
				["FIELD OF VIEW", 0.5, "90°"],
				["MOTION (VIEW BOB, MENU TURNS)", 1.0, "FULL"],
				["MASTER VOLUME", 1.0, "100%"]],
			"toggles": [["INVERT LOOK UP AND DOWN", false]]},
	}


## Turn the eye to a page (or part-way through a turn), and put up that
## page's own prompts and turn cues.
func _aim(spec: String) -> void:
	var page := spec
	if spec.begins_with("turn:"):
		var body := spec.trim_prefix("turn:")
		var at := body.split("@")
		var ends := at[0].split(">")
		var a := Kit.PAGES.find(ends[0])
		var b := Kit.PAGES.find(ends[1])
		var step := posmod(b - a, 4)
		if step == 3:
			step = -1
		shell.face(ends[0])
		shell.camera.rotation.y = Kit.yaw_of(a) + float(step) * PI * 0.5 \
				* float(at[1])
		page = ends[0]
	else:
		shell.face(page)
	var i := Kit.PAGES.find(page)
	overlay.edges(Kit.TITLES[Kit.PAGES[posmod(i + 1, 4)]],
			Kit.TITLES[Kit.PAGES[posmod(i - 1, 4)]])
	overlay.prompts(PROMPTS[page])
	overlay.status("INPUT: KEYBOARD AND MOUSE    MOTION: %s" % [
			"REDUCED" if kit.reduced else "FULL"])
	_wait = 4


func _process(delta: float) -> void:
	_clock += delta
	kit.step(delta)
	map.tick(delta)
	if direction.has_method("tick"):
		direction.call("tick", delta)
	if _shots.is_empty() or _clock < 0.8:
		return
	if _wait > 0:
		_wait -= 1
		return
	var shot: Array = _shots.pop_front()
	get_viewport().get_texture().get_image().save_png(str(shot[1]))
	print("[study] %s -> %s" % [shot[0], shot[1]])
	if _shots.is_empty():
		if not kit.missing.is_empty():
			push_warning("[study] characters the face lacks: %s" % str(kit.missing_where))
		get_tree().quit()
		return
	_aim(str(_shots[0][0]))
