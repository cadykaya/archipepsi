class_name FaceSettings
extends RefCounted
## SETTINGS / PAUSE -- reachable in the four-face order, and NOT DESIGNED
## in this pass. Its treatment is an open design item (A2 ruling,
## 2026-09-27); nothing here implies the studies settled it.
##
## It shows Production's real items, plainly: PauseMenu's actions, the
## CAMPAIGN lines (JournalQuery.campaign over the same save), and
## SettingsFace's OPTIONS. Only two kinds of row do anything:
##
## * MOTION -- Production's own `motion_intensity` option ("Motion (view
##   bob, menu turns)"), previewed locally: FULL, or OFF, which is what
##   MenuShell reads as reduced motion.
## * REVIEW CONTROLS, which are the prototype's and not the game's: the
##   sample save, the equipment sample, symbols or text in the prompts,
##   and clearing the equip previews.

const COL := [48.0, 470.0, 880.0]
const TOP := 150.0
const LINE := 26.0

var kit: Kit
var shell: Shell
var face: Node3D
var proto: Node
var focus := 0
var _root: Node3D
var _rows: Array = []                 # interactive rows: {label, values, get, set}


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("settings")


func bind(p: Node) -> void:
	proto = p


func load_data(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rows = [
		{"label": "MOTION (VIEW BOB, MENU TURNS)", "values": ["FULL", "OFF"],
			"get": func() -> int: return 1 if kit.reduced else 0,
			"set": func(i: int) -> void: proto.call("set_reduced", i == 1),
			"game": true},
		{"label": "SAMPLE SAVE", "values": ["WALKED", "PROGRESSED", "LATCHED"],
			"get": func() -> int: return ["walked", "progressed", "latched"].find(
					str(proto.get("save"))),
			"set": func(i: int) -> void: proto.call("set_save",
					["walked", "progressed", "latched"][i])},
		{"label": "EQUIPMENT SAMPLE", "values": ["FIXTURE", "FIXTURE + STRESS"],
			"get": func() -> int: return 1 if str(proto.get("equipment_variant")) \
					== "stress" else 0,
			"set": func(i: int) -> void: proto.call("set_equipment",
					"stress" if i == 1 else "base")},
		{"label": "PROMPTS", "values": ["SYMBOLS", "TEXT"],
			"get": func() -> int: return 1 if (proto.get("overlay") as Overlay).text_prompts \
					else 0,
			"set": func(i: int) -> void:
				(proto.get("overlay") as Overlay).text_prompts = i == 1
				proto.call("_refresh")},
		{"label": "CLEAR EQUIP PREVIEWS", "values": ["DO IT"],
			"get": func() -> int: return 0,
			"set": func(_i: int) -> void:
				var eq: FaceEquipment = proto.get("faces")["equipment"]
				eq.preview.clear()
				eq.load_data(eq.data)},
	]
	_build()


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Node3D.new()
	face.add_child(_root)
	kit.label(_root, "NOT DESIGNED IN THIS PASS -- ITS TREATMENT IS AN OPEN "
			+ "DESIGN ITEM", Vector2(48, 92), 2, Kit.INK_DIM)
	var y := TOP
	kit.label(_root, "PAUSED", Vector2(COL[0], y), 2, Kit.INK_FAINT)
	for item: String in ["RESUME", "RETURN TO HUB", "ABANDON ZONE…", "QUIT GAME"]:
		y += LINE
		kit.label(_root, item, Vector2(COL[0], y), 2, Kit.INK_DIM)
	kit.label(_root, "(PAUSEMENU'S ACTIONS -- NOT WIRED HERE)", Vector2(COL[0],
			y + LINE + 6), 2, Kit.INK_FAINT)
	y = TOP
	kit.label(_root, "CAMPAIGN", Vector2(COL[1], y), 2, Kit.INK_FAINT)
	var journal: Dictionary = (proto.get("sample")["saves"] as Dictionary)[
			str(proto.get("save"))]["journal"]
	for line: Variant in journal.get("campaign", []):
		y += LINE
		kit.label(_root, kit.fit(str(line), 2, 380), Vector2(COL[1], y), 2,
				Kit.INK_DIM)
	y = TOP
	kit.label(_root, "OPTIONS", Vector2(COL[2], y), 2, Kit.INK_FAINT)
	for item: String in ["MOUSE SENSITIVITY", "FIELD OF VIEW",
			"MASTER VOLUME", "INVERT LOOK UP AND DOWN"]:
		y += LINE
		kit.label(_root, item, Vector2(COL[2], y), 2, Kit.INK_FAINT)
	var ry := 470.0
	kit.label(_root, "REVIEW CONTROLS -- THE PROTOTYPE'S, NOT THE GAME'S",
			Vector2(COL[0], ry - 34), 2, Kit.INK_FAINT)
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var at := Vector2(COL[2], TOP + LINE * 5) if row.get("game", false) \
				else Vector2(COL[0] + (i - 1) % 2 * 600.0, ry + (i - 1) / 2 * 46.0)
		var focused := i == focus
		if focused:
			var size := Vector2(560 if not row.get("game", false) else 360, 36)
			kit.shadow(_root, at - Vector2(12, 8), size, 0.5)
			kit.plate(_root, at - Vector2(12, 8), size, 0.004, kit.lit(Kit.PLATE_HI))
			kit.card(_root, at - Vector2(18, 8), Vector2(4, 36), 0.012,
					kit.flat(Kit.SIGNAL))
		kit.label(_root, str(row["label"]), at, 2, Kit.INK, 0.013)
		var values: Array = row["values"]
		var current: int = (row["get"] as Callable).call()
		var vx := at.x + (300.0 if not row.get("game", false) else 0.0)
		var vy := at.y if not row.get("game", false) else at.y + LINE
		for j in values.size():
			var v := str(values[j])
			var colour := Kit.SIGNAL if j == current and values.size() > 1 \
					else Kit.INK_FAINT
			if values.size() == 1:
				colour = Kit.INK_DIM
			kit.label(_root, v, Vector2(vx, vy), 2, colour, 0.013)
			vx += kit.measure(v, 2) + 22.0


func nav(dir: Vector2i) -> void:
	if dir.y != 0:
		focus = clampi(focus + dir.y, 0, _rows.size() - 1)
	elif dir.x != 0:
		_change(dir.x)
		return
	_build()


func _change(step: int) -> void:
	var row: Dictionary = _rows[focus]
	var n: int = (row["values"] as Array).size()
	var current: int = (row["get"] as Callable).call()
	(row["set"] as Callable).call(posmod(current + step, n))
	_build()


func accept() -> void:
	_change(1)


func back() -> bool:
	return false


func hover_at(_p: Vector2) -> void:
	pass


func click(p: Vector2) -> bool:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var at := Vector2(COL[2], TOP + LINE * 5) if row.get("game", false) \
				else Vector2(COL[0] + (i - 1) % 2 * 600.0, 470.0 + (i - 1) / 2 * 46.0)
		if Rect2(at - Vector2(12, 8), Vector2(560, 60 if row.get("game", false)
				else 36)).has_point(p):
			focus = i
			_change(1)
			return true
	return false


func wheel(_p: Vector2, _d: int) -> bool:
	return false


func prompts() -> Array:
	return [["move", "rows"], ["change", "change"], ["accept", "change"],
		["turn_left", "turn left"], ["turn_right", "turn right"],
		["close", "close"]]


func state() -> Dictionary:
	return {"focus": focus}


func on_device() -> void:
	pass


func tick(_delta: float) -> void:
	pass
