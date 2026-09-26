extends RefCounted
## STUDY 1 -- LEAF: THE THING OPENS WHERE IT IS.   (the INVENTORY face)
##
## **The idea.** The item you pick is not described somewhere else: it
## unfolds in place, and what was folded inside it is its detail. A header
## leaf swings out of its right edge, and a body leaf folds out from under
## it -- DOWN, or UP when the row sits low, always toward the free wall.
## Its neighbours on the row step aside to make room; the rows it hangs
## over drop back in value behind it. Move away and it folds up again.
##
## **The layout is the data's own: each row is a KEY.** Production's five
## keys (`SLOT_NAMES`) start the rows with their real bindings; the item on
## a key sits in the socket beside it; what else could go on that key
## follows along the row. "What is on RMB, and what else could be" is one
## glance, and the detail's comparison (now -> this) is with the leaf in
## the same row. ECHO B has no candidate in the sample and says so; ALWAYS
## ON is a row without a key, because passive is not switchable. Nothing
## is laid out that the data does not have: the four Gear territories
## exist in the contract and can hold nothing yet, so they are not drawn.
##
## Every word is `EquipmentQuery`'s answer on Production's fixture.
## Keyboard/controller in this capture: focus is the signal bar that slides
## under a leaf (its spine turns signal, its ground comes up), ENTER opens,
## moving away folds, Q/E turn.

const Kit := preload("res://_harness/study_kit.gd")
const Overlay := preload("res://_harness/study_overlay.gd")
const Plan := preload("res://_harness/study_plan.gd")

const SLOTS: Array[String] = ["echo_a", "echo_b", "mobility", "utility",
	"consumable"]
const ROW_Y := {"echo_a": 92.0, "echo_b": 184.0, "mobility": 276.0,
	"utility": 368.0, "consumable": 460.0, "always": 574.0}
const KEYS_X := 48.0
const SOCKET_X := 250.0
const LEAF := Vector2(220, 64)
const GAP := 40.0
const RIGHT_W := 300.0
const BODY_W := 640.0
const LINE := 20.0
## Production's bindings for the five keys (project.godot, the sample's
## revision): fire_echo RMB, fire_echo_b F, fire_mobility Shift,
## fire_utility C, fire_consumable Q.
const BINDING := {"echo_a": "RMB", "echo_b": "F", "mobility": "SHIFT",
	"utility": "C", "consumable": "Q"}

var kit: Kit
var overlay: Overlay
var face: Node3D
var items := {}          # id -> Production's answers for the item
var titles := {}         # slot -> "ECHO A" ...
var leaves := {}         # id -> {root, x, row, card, labels: []}
var rows := {}           # row -> [ids], left to right
var ring: Node3D
var focused := ""
var opened := ""
var _sheets := {}        # id -> {right, body, body_down, height}


func _init(k: Kit, o: Overlay, content: Dictionary, _layout: Dictionary) -> void:
	kit = k
	overlay = o
	var eq: Dictionary = content["equipment"]["base"]
	for it: Dictionary in eq["items"]:
		items[str(it["id"])] = it
	for key: Dictionary in eq["keys"]:
		titles[str(key["slot"])] = str(key["title"])
	for page: String in Kit.PAGES:
		kit.face_title(page)
	face = kit.face_of("equipment")
	kit.face("equipment")
	_build_rows(eq)
	_build_ring()
	# The neighbour a turn LEFT arrives at: the map, at rest.
	Plan.new(kit, kit.face_of("map"), content["map"]["walked"],
			Rect2(Vector2(64, 96), Vector2(1152, 580)))
	overlay.prompts([["ARROWS", "move"], ["ENTER", "open"],
		["Q", "turn left"], ["E", "turn right"], ["ESC", "close"]])
	_focus("act_lash", true)


func title() -> String:
	return "STUDY 1 -- LEAF: THE THING OPENS WHERE IT IS (INVENTORY)"


# ------------------------------------------------------------ building

func _build_rows(eq: Dictionary) -> void:
	for slot: String in SLOTS:
		var y: float = ROW_Y[slot]
		_keycap(slot, y)
		var holds: Variant = null
		for key: Dictionary in eq["keys"]:
			if str(key["slot"]) == slot:
				holds = key["view"].get("holds")
		var ids: Array = []
		if holds != null:
			ids.append(str(holds))
		for it: Dictionary in eq["items"]:
			if str(it["home_slot"]) == slot and str(it["id"]) != str(holds):
				ids.append(str(it["id"]))
		rows[slot] = ids
		var x := SOCKET_X
		if holds == null:
			_empty_socket(slot, y, ids.is_empty())
			x += LEAF.x + GAP
		for id: String in ids:
			_leaf(id, slot, x, y)
			x += LEAF.x + GAP
		kit.card(face, Vector2(KEYS_X, y + LEAF.y + 10), Vector2(1184, 2),
				0.001, Kit.EDGE)
	var y_on: float = ROW_Y["always"]
	kit.label(face, "ALWAYS ON", Vector2(KEYS_X, y_on + 6), 2, Kit.INK_DIM)
	kit.label(face, "NOT A SWITCH", Vector2(KEYS_X, y_on + 32), 2,
			Kit.INK_FAINT)
	var on: Array = []
	var x := SOCKET_X
	for it: Dictionary in eq["items"]:
		if str(it["activation"]) == "always_on":
			on.append(str(it["id"]))
			_leaf(str(it["id"]), "always", x, y_on)
			x += LEAF.x + GAP
	rows["always"] = on


func _keycap(slot: String, y: float) -> void:
	var key: String = BINDING[slot]
	var w: float = maxf(44.0, kit.measure(key, 2) + 20.0)
	kit.card(face, Vector2(KEYS_X, y + 4), Vector2(w, 28), 0.002,
			Color("#717985"))
	kit.card(face, Vector2(KEYS_X, y + 28), Vector2(w, 4), 0.0021,
			Color("#4a4f57"))
	kit.label(face, key, Vector2(KEYS_X + 10, y + 10), 2, Color("#26292d"),
			0.0025)
	kit.label(face, str(titles.get(slot, slot)), Vector2(KEYS_X, y + 42), 2,
			Kit.INK_FAINT)


func _empty_socket(slot: String, y: float, nothing_owned: bool) -> void:
	kit.card(face, Vector2(KEYS_X + 96.0, y + 30), Vector2(SOCKET_X - KEYS_X
			- 104.0, 2), 0.003, Kit.DEAD)
	kit.card(face, Vector2(SOCKET_X, y + 6), Vector2(5, LEAF.y - 12), 0.003,
			Kit.DEAD)
	kit.label(face, "EMPTY", Vector2(SOCKET_X + 20, y + 12), 2, Kit.DEAD)
	if nothing_owned:
		kit.label(face, "NOTHING YOU OWN GOES ON %s" % BINDING[slot],
				Vector2(SOCKET_X + LEAF.x + GAP, y + 24), 2, Kit.INK_FAINT)


func _leaf(id: String, row: String, x: float, y: float) -> void:
	var it: Dictionary = items[id]
	var root := Node3D.new()
	root.position = Kit.at(Vector2(x, y), 0.004)
	face.add_child(root)
	# At rest a leaf is FOLDED: its spine and its name on the key's shelf,
	# nothing boxed. The ground behind it only appears when it is focused,
	# and becomes the sheet when it opens.
	var card := kit.card(root, Vector2(-8, 0), LEAF + Vector2(8, 0), -0.0005,
			Kit.SHEET_HI, 0.0, true, true)
	var on_key := str(it["equipped_in"]) != ""
	var spine := kit.card(root, Vector2(0, 6), Vector2(5 if not on_key else 7,
			LEAF.y - 12), 0.0, Kit.INK if on_key else Kit.INK_FAINT, 1.0,
			true, true)
	var labels: Array = []
	labels.append(kit.label(root, str(it["name"]), Vector2(20, 12), 2,
			Kit.INK, 0.001, 0.0, false, true))
	var mk := "MK %s" % ["I", "II", "III", "IV"][clampi(int(it["mk"]) - 1, 0, 3)]
	labels.append(kit.label(root, mk, Vector2(20, 38), 2, Kit.INK_FAINT,
			0.001, 0.0, false, true))
	if it.get("charges_max") != null:
		var left := int(it["charges_left"])
		labels.append(kit.label(root, "%d/%d" % [left, int(it["charges_max"])],
				Vector2(LEAF.x - 50, 38), 2, Kit.INK if left > 0 else Kit.DEAD,
				0.001, 0.0, true, true))
	if on_key:
		# The wire from the key's binding to what is on it.
		kit.card(face, Vector2(KEYS_X + 96.0, y + 30), Vector2(x - KEYS_X - 104.0,
				2), 0.003, Kit.INK_FAINT)
	leaves[id] = {"root": root, "x": x, "y": y, "row": row, "card": card,
		"spine": spine, "labels": labels, "on_key": on_key}
	_sheets[id] = _build_sheet(id, root, row)


## The two leaves folded inside every item, hidden edge-on until opened.
func _build_sheet(id: String, root: Node3D, row: String) -> Dictionary:
	var it: Dictionary = items[id]
	# The header leaf, hinged on the item's right edge.
	var right := Node3D.new()
	right.position = Kit.rel(Vector2(LEAF.x, 0), 0.0)
	right.rotation.y = -PI * 0.5
	right.visible = false
	root.add_child(right)
	kit.card(right, Vector2.ZERO, Vector2(RIGHT_W, LEAF.y), 0.0, Kit.SHEET_HI,
			1.0, false, true)
	var home := str(it["home_slot"])
	var line1 := "ALWAYS ON -- NOTHING TO EQUIP"
	var line2 := "NOT A SWITCH"
	if home != "":
		line1 = "GOES ON %s  %s" % [BINDING[home], titles.get(home, home)]
		if str(it["equipped_in"]) != "":
			line2 = "ON IT NOW"
		elif str(it["compare_to"]) != "":
			line2 = "NOW: %s" % str(it["compare_to"])
		else:
			line2 = "THE KEY IS EMPTY"
	kit.label(right, line1, Vector2(14, 12), 2, Kit.INK, 0.001, 0.0, false, true)
	kit.label(right, line2, Vector2(14, 38), 2, Kit.INK_DIM, 0.001, 0.0,
			false, true)
	# The body leaf: two columns, sized to what it has to say.
	var left_lines := _block("DOES", it["does"]) + _block("USE", it["use"]) \
			+ _block("COST", it["cost"])
	var right_lines: Array = []
	if not (it["comparison"] as Array).is_empty():
		right_lines += _block("VS %s" % str(it["compare_to"]), it["comparison"])
	var hist: Array = []
	for h: Dictionary in it["history"]:
		hist.append("%s  %s, %s" % [h["mark"], h["item"], h["game"]])
	right_lines += _block("FROM", hist)
	var col := (BODY_W - 36.0) * 0.5
	# Rows of text, plus the 6 px each section head adds above itself.
	var height := 36.0 + LINE * float(maxi(_count(left_lines, col),
			_count(right_lines, col) + 2)) + 6.0 * 4.0
	var down := row in ["echo_a", "echo_b", "mobility"]
	var body := Node3D.new()
	body.position = Kit.rel(Vector2(0, LEAF.y if down else 0.0), 0.0)
	body.rotation.x = -PI * 0.5 if down else PI * 0.5
	body.visible = false
	root.add_child(body)
	var top := 0.0 if down else -height
	kit.card(body, Vector2(0, top), Vector2(BODY_W, height), 0.0, Kit.SHEET,
			1.0, false, true)
	kit.card(body, Vector2(0, top if down else top + height - 2),
			Vector2(BODY_W, 2), 0.0005, Kit.EDGE, 1.0, false, true)
	_write(body, left_lines, Vector2(14, top + 14), col)
	_write(body, right_lines, Vector2(24 + col, top + 14), col)
	var prompt := ""
	var refusal := str(it["refusal"])
	if home == "":
		prompt = ""
	elif str(it["equipped_in"]) != "":
		prompt = refusal
	elif str(it["held_back"]) != "":
		prompt = str(it["held_back"])
	else:
		prompt = "PUT ON %s" % BINDING[home]
	if prompt != "":
		var py := top + height - 30.0
		if prompt.begins_with("PUT ON"):
			kit.card(body, Vector2(24 + col, py - 2), Vector2(72, 24), 0.0006,
					Color("#717985"), 1.0, false, true)
			kit.label(body, "ENTER", Vector2(32 + col, py + 2), 2,
					Color("#26292d"), 0.001, 0.0, false, true)
			kit.label(body, prompt, Vector2(106 + col, py + 2), 2, Kit.SIGNAL,
					0.001, 0.0, false, true)
		else:
			kit.label(body, prompt, Vector2(24 + col, py + 2), 2,
					Kit.INK_FAINT, 0.001, col, false, true)
	return {"right": right, "body": body, "down": down, "height": height}


func _block(head: String, lines: Array) -> Array:
	if lines.is_empty():
		return []
	var out: Array = [["head", head]]
	for l: Variant in lines:
		out.append(["line", str(l)])
	return out


func _count(lines: Array, width: float) -> int:
	var n := 0
	for entry: Array in lines:
		n += 1 if entry[0] == "head" else _wrap_rows(str(entry[1]), width)
	return n + 1


func _wrap_rows(text: String, width: float) -> int:
	var rows_n := 1
	var line := ""
	for word in Kit.sanitize(text).split(" "):
		var trial := word if line == "" else line + " " + word
		if kit.measure(trial, 2) > width and line != "":
			rows_n += 1
			line = word
		else:
			line = trial
	return rows_n


func _write(parent: Node3D, lines: Array, at_px: Vector2, width: float) -> void:
	var y := at_px.y
	for entry: Array in lines:
		if entry[0] == "head":
			if y > at_px.y:
				y += 6.0
			kit.label(parent, str(entry[1]), Vector2(at_px.x, y), 2,
					Kit.INK_FAINT, 0.001, width, false, true)
			y += LINE
		else:
			kit.label(parent, str(entry[1]), Vector2(at_px.x, y), 2, Kit.INK,
					0.001, width, false, true)
			y += LINE * float(_wrap_rows(str(entry[1]), width))


func _build_ring() -> void:
	ring = Node3D.new()
	face.add_child(ring)
	kit.card(ring, Vector2(-8, LEAF.y + 2), Vector2(LEAF.x + 8, 4), 0.0,
			Kit.SIGNAL, 1.0, false, true)


# ------------------------------------------------------------ actions

func _focus(id: String, at_once := false) -> void:
	if opened != "" and opened != id:
		_fold(opened)
	if focused != "" and focused != id:
		_mark(focused, false)
	focused = id
	_mark(id, true)
	var leaf: Dictionary = leaves[id]
	# Where the leaf RESTS, not where a slide has it this frame.
	var to := Kit.at(Vector2(float(leaf["x"]), float(leaf["y"])), 0.006)
	if at_once:
		ring.position = to
	else:
		kit.go(ring, "position", to, 0.14, "out")


## Focus is the leaf's ground coming up and its spine turning signal.
func _mark(id: String, on: bool) -> void:
	var leaf: Dictionary = leaves[id]
	var ground: StandardMaterial3D = (leaf["card"] as MeshInstance3D).material_override
	kit.go(ground, "albedo_color", Color(Kit.SHEET_HI, 1.0 if on else 0.0), 0.12)
	var spine: StandardMaterial3D = (leaf["spine"] as MeshInstance3D).material_override
	var rest: Color = Kit.INK if bool(leaf["on_key"]) else Kit.INK_FAINT
	kit.go(spine, "albedo_color", Kit.SIGNAL if on else rest, 0.12)


func _open(id: String) -> void:
	if opened == id:
		return
	if opened != "":
		_fold(opened)
	opened = id
	var s: Dictionary = _sheets[id]
	var right: Node3D = s["right"]
	var body: Node3D = s["body"]
	right.visible = true
	body.visible = true
	var root: Node3D = leaves[id]["root"]
	kit.go(root, "position:z", Kit.at(Vector2.ZERO, 0.03).z, 0.18, "out")
	kit.go(right, "rotation:y", 0.0, 0.18, "out")
	kit.go(body, "rotation:x", 0.0, 0.2, "out", 0.08)
	var leaf: Dictionary = leaves[id]
	# Neighbours on the row step right, out from under the header leaf.
	for other: String in rows[leaf["row"]]:
		var o: Dictionary = leaves[other]
		if float(o["x"]) > float(leaf["x"]):
			kit.go(o["root"], "position:x",
					Kit.at(Vector2(float(o["x"]) + RIGHT_W, 0)).x, 0.2, "out")
	# The rows the body hangs over drop back behind it.
	var span := _body_span(id)
	for other: String in leaves:
		var o: Dictionary = leaves[other]
		if other == id or o["row"] == leaf["row"]:
			continue
		var top: float = o["y"]
		if top + LEAF.y > span.x and top < span.y:
			_tone(other, true)
	overlay.prompts([["ARROWS", "move and fold"], ["ENTER", "put on key"],
		["Q", "turn left"], ["E", "turn right"], ["ESC", "close"]])


func _fold(id: String) -> void:
	var s: Dictionary = _sheets[id]
	var right: Node3D = s["right"]
	var body: Node3D = s["body"]
	# No longer the open one BEFORE the hide is scheduled: in reduced motion
	# the hide runs at once, and must see that this sheet is shut.
	if opened == id:
		opened = ""
	kit.go(body, "rotation:x", -PI * 0.5 if s["down"] else PI * 0.5, 0.14, "in")
	kit.go(right, "rotation:y", -PI * 0.5, 0.14, "in", 0.06)
	kit.go(leaves[id]["root"], "position:z", Kit.at(Vector2.ZERO, 0.004).z,
			0.16, "out", 0.06)
	kit.later(0.22, func() -> void:
		if opened != id:
			right.visible = false
			body.visible = false)
	var leaf: Dictionary = leaves[id]
	for other: String in rows[leaf["row"]]:
		var o: Dictionary = leaves[other]
		if float(o["x"]) > float(leaf["x"]):
			kit.go(o["root"], "position:x", Kit.at(Vector2(float(o["x"]), 0)).x,
					0.18, "out")
	for other: String in leaves:
		_tone(other, false)
	overlay.prompts([["ARROWS", "move"], ["ENTER", "open"],
		["Q", "turn left"], ["E", "turn right"], ["ESC", "close"]])


## The page-y range the open body covers.
func _body_span(id: String) -> Vector2:
	var s: Dictionary = _sheets[id]
	var y: float = leaves[id]["y"]
	var h: float = s["height"]
	return Vector2(y + LEAF.y, y + LEAF.y + h) if s["down"] \
			else Vector2(y - h, y)


func _tone(id: String, dim: bool) -> void:
	var leaf: Dictionary = leaves[id]
	for l: Label3D in leaf["labels"]:
		var ink: Color = l.get_meta("ink", l.modulate)
		l.set_meta("ink", ink)
		kit.go(l, "modulate", ink.darkened(0.62) if dim else ink, 0.18)


# ------------------------------------------------------------ the capture

func timeline() -> Array:
	return [
		[0.0, func() -> void: pass, "rest"],
		[1.2, func() -> void: _focus("act_bolt")],
		[1.6, func() -> void: _open("act_bolt"), "select"],
		[3.6, func() -> void: _focus("act_dash")],
		[3.8, func() -> void: _focus("act_lens")],
		[4.0, func() -> void: _focus("act_flask")],
		[4.4, func() -> void: _open("act_flask"), "change"],
		[6.4, func() -> void: kit.turn(1), "adjacent"],
		[7.9, func() -> void: kit.turn(-1), "return"],
	]


func duration() -> float:
	return 9.0


func stills() -> Array:
	return [[0.9, "rest -- each row is a key, what is on it sits in its socket"],
		[2.4, "select -- Arc Bolt opens where it is; it compares with the leaf on RMB"],
		[5.4, "change -- moving away folded it; Frost Flask opens UP, toward the free wall"],
		[7.3, "adjacent -- a turn left: the map, at rest"],
		[8.7, "return -- Frost Flask is still open, the focus still on it"]]
