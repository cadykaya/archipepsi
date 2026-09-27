class_name FaceEquipment
extends RefCounted
## EQUIPMENT (the Inventory), LEAF refined: THE DRAWER.
##
## One composition around the selected module and its key:
##
## * Down the left, the LOADOUT: Production's five keys (SLOT_NAMES, with
##   the bindings SlotKeycaps names), each with what is seated on it, and
##   ALWAYS ON below them -- passives take no key.
## * The focused key's DRAWER slides out of its socket: every owned item
##   that fits that key, and nothing else. Only one key's candidates are
##   ever on the wall, so there is no table.
## * The selected module UNFOLDS WHERE IT IS -- its description, what it
##   does, how it is used, what it costs -- and beside that, the comparison
##   with what is on its key NOW: Production's own lines
##   (EquipmentQuery.comparison), against the item a preview put there too.
##
## Mouse targets hold still: hovering only lights a strip. A click unfolds
## it, and the drawer moves around the clicked strip so it stays under the
## pointer. The keyboard/pad row movement is never done on hover.
##
## Equipping is a LOCAL PREVIEW, labelled: it re-seats the key on this wall
## and nowhere else (no request, no save). Production's equip is a request
## with states; the preview says NOT SENT, which is one of them.

const LOAD_X := 48.0
const LOAD_W := 266.0
const ROW_Y0 := 106.0
const ROW_PITCH := 74.0
const ALWAYS_Y := 494.0
const DRAWER_X := 340.0
const LIST_X := 362.0
const LIST_W := 858.0
const VIEW_TOP := 134.0
const VIEW_BOTTOM := 688.0
const STRIP_H := 46.0
const LINE := 20.0
const COL_L := 16.0          # card columns, relative to the strip
const COL_L_W := 380.0
const COL_R := 440.0
const COL_R_W := 400.0
const MOUSE_SYMBOL := {"RMB": "mouse_right", "MMB": "mouse_middle",
	"LMB": "mouse_left"}

var kit: Kit
var shell: Shell
var face: Node3D
var data: Dictionary          # sample.equipment[variant]
var items := {}               # id -> row
var preview := {}             # slot -> id (the local preview)
var key_index := 0            # 0..4 the keys, 5 ALWAYS ON
var zone := "keys"            # keys | drawer
var sel := {}                 # key -> selected id (each key remembers)
var scroll := {}              # key -> scroll px (each key remembers)
var hover := ""               # "key:<i>" or an item id
var unfolded := ""
var note := ""                # a transient line on the card (preview done)

var _loadout: Node3D
var _rows := []               # per key row: {ground, name, tag, y}
var _focus_bar: MeshInstance3D
var _drawer: Node3D
var _list: Node3D
var _link: MeshInstance3D
var _strips := {}             # id -> {node, ground, y, h, card}
var _order: Array = []        # ids in the drawer, in order
var _more_up: Node3D
var _more_down: Node3D
var _scroll_px := 0.0


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("equipment")


func load_data(d: Dictionary) -> void:
	data = d
	items.clear()
	for row: Dictionary in data["items"]:
		items[str(row["id"])] = row
	for slot: String in preview.keys():
		if not items.has(str(preview[slot])):
			preview.erase(slot)
	_build_loadout()
	_open_drawer(true)


# ------------------------------------------------------------ the data

func keys() -> Array:
	return data["keys"]


func key_count() -> int:
	return keys().size() + 1       # + ALWAYS ON


func slot_of(index: int) -> String:
	return "" if index >= keys().size() else str(keys()[index]["slot"])


## What is on a key now: the preview's item, else the save's.
func seated(slot: String) -> String:
	if preview.has(slot):
		return str(preview[slot])
	for key: Dictionary in keys():
		if str(key["slot"]) == slot:
			var holds: Variant = (key["view"] as Dictionary).get("holds")
			return "" if holds == null else str(holds)
	return ""


func saved(slot: String) -> String:
	for key: Dictionary in keys():
		if str(key["slot"]) == slot:
			var holds: Variant = (key["view"] as Dictionary).get("holds")
			return "" if holds == null else str(holds)
	return ""


## The drawer's items for a key: what the SAVE has on it first, then the
## rest in the fold's own order. A preview never reorders the drawer --
## the item previewed stays where it is (and says so), so nothing moves
## out from under a pointer that just clicked it. ALWAYS ON: the passives.
func candidates(index: int) -> Array:
	var out := []
	var slot := slot_of(index)
	if slot == "":
		for row: Dictionary in data["items"]:
			if not bool(row["slotted"]):
				out.append(str(row["id"]))
		return out
	var on := saved(slot)
	if on != "":
		out.append(on)
	for row: Dictionary in data["items"]:
		var id := str(row["id"])
		if id != on and (row["fits"] as Array).has(slot):
			out.append(id)
	return out


func _name(id: String) -> String:
	return str(items[id]["name"])


## An item from the authored layout-stress Echoes, not Production's
## fixture: tagged where it is drawn, so no sample passes for game content.
func _authored(id: String) -> bool:
	return bool(items[id].get("authored", false))


func _mk(id: String) -> String:
	return "MK " + _roman(int(items[id]["mk"]))


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
		"X"][clampi(n, 0, 10)]


# ------------------------------------------------------------ the loadout

func _build_loadout() -> void:
	if _loadout != null:
		_loadout.queue_free()
	_loadout = Node3D.new()
	face.add_child(_loadout)
	_rows.clear()
	for i in key_count():
		var y := ROW_Y0 + ROW_PITCH * i if i < keys().size() else ALWAYS_Y
		var ground := kit.card(_loadout, Vector2(LOAD_X - 12, y - 10),
				Vector2(LOAD_W + 24, 62), 0.002, kit.own(Kit.PLATE, 0.0))
		var row := {"ground": ground, "y": y}
		if i < keys().size():
			var key: Dictionary = keys()[i]
			_keycap(_loadout, str(key["keycap"]), Vector2(LOAD_X, y))
			kit.label(_loadout, str(key["title"]), Vector2(LOAD_X + 74, y + 1),
					2, Kit.INK_FAINT)
		else:
			kit.label(_loadout, "ALWAYS ON", Vector2(LOAD_X, y + 1), 2,
					Kit.INK_FAINT)
			kit.label(_loadout, "NOT A SWITCH", Vector2(LOAD_X + 138, y + 1),
					2, Kit.DEAD)
		_rows.append(row)
		_row_text(i)
	_focus_bar = kit.card(_loadout, Vector2(LOAD_X - 16, 0), Vector2(4, 62),
			0.004, kit.flat(Kit.SIGNAL))
	_place_focus_bar(true)


## The keycap as the Glyph kit draws one, set into the wall: the binding's
## own name (SlotKeycaps), and for a mouse button its device symbol too.
func _keycap(parent: Node3D, cap: String, at: Vector2) -> void:
	var up := cap.to_upper()
	var w := maxf(40.0, kit.measure(up, 2) + 16.0)
	if MOUSE_SYMBOL.has(up):
		w = 66.0
	kit.plate(parent, at, Vector2(w, 26), 0.001, kit.lit(Color("#c9d0db")),
			0.004)
	if MOUSE_SYMBOL.has(up):
		kit.sprite(parent, MOUSE_SYMBOL[up], at + Vector2(14, 13), 2,
				Kit.SHADE, 0.0065)
		kit.label(parent, up, at + Vector2(28, 5), 2, Kit.SHADE, 0.0065)
	else:
		kit.label(parent, up, at + Vector2(8, 5), 2, Kit.SHADE, 0.0065)


func _row_text(i: int) -> void:
	var row: Dictionary = _rows[i]
	for key in ["name", "tag"]:
		if row.has(key) and is_instance_valid(row[key]):
			(row[key] as Node).queue_free()
	var y: float = row["y"]
	if i >= keys().size():
		var names := []
		for id: String in candidates(i):
			names.append(_name(id))
		row["name"] = kit.label(_loadout, kit.fit(", ".join(names), 2, LOAD_W),
				Vector2(LOAD_X, y + 26), 2, Kit.INK_DIM)
		return
	var slot := slot_of(i)
	var on := seated(slot)
	if on == "":
		row["name"] = kit.label(_loadout, "EMPTY", Vector2(LOAD_X, y + 30), 2,
				Kit.DEAD)
	else:
		row["name"] = kit.label(_loadout, kit.fit(_name(on), 2, LOAD_W - 8),
				Vector2(LOAD_X, y + 30), 2, Kit.INK)
		if preview.has(slot):
			row["tag"] = kit.label(_loadout, "PREVIEW",
					Vector2(LOAD_X + LOAD_W - kit.measure("PREVIEW", 2), y + 1),
					2, Kit.INK)


func _place_focus_bar(at_once := false) -> void:
	var y: float = _rows[key_index]["y"] - 10.0
	var to := Kit.at(Vector2(LOAD_X - 16 + 2, y + 31), 0.004)
	if at_once:
		_focus_bar.position = to
	else:
		kit.go(_focus_bar, "position", to, 0.14, "out")
	for i in _rows.size():
		var ground: MeshInstance3D = _rows[i]["ground"]
		var lit := i == key_index or hover == "key:%d" % i
		var a := 1.0 if i == key_index else (0.55 if lit else 0.0)
		kit.go(ground.material_override, "albedo_color",
				Color(Kit.PLATE, a), 0.12)


# ------------------------------------------------------------ the drawer

## The focused key's drawer: its strips slide out of the socket.
func _open_drawer(at_once := false) -> void:
	if _drawer != null:
		_drawer.queue_free()
	_drawer = Node3D.new()
	face.add_child(_drawer)
	_strips.clear()
	_order = candidates(key_index)
	var slot := slot_of(key_index)
	var y0: float = _rows[key_index]["y"]
	# The socket's line out to the drawer, and the drawer's spine.
	_link = kit.ribbon(_drawer, [Kit.at(Vector2(LOAD_X + LOAD_W + 12, y0 + 21), 0.002),
			Kit.at(Vector2(DRAWER_X, y0 + 21), 0.002),
			Kit.at(Vector2(DRAWER_X, VIEW_TOP - 18), 0.002),
			Kit.at(Vector2(DRAWER_X, VIEW_BOTTOM), 0.002)],
			2.0 * Kit.px(), kit.flat(Kit.INK_FAINT))
	var head := "WHAT GOES ON %s" % str(keys()[key_index]["keycap"]).to_upper() \
			if slot != "" else "ALWAYS ON WHILE YOU OWN IT"
	kit.label(_drawer, head, Vector2(LIST_X, VIEW_TOP - 36), 2, Kit.INK_FAINT)
	var count := "%d" % _order.size()
	kit.label(_drawer, count, Vector2(LIST_X + LIST_W - kit.measure(count, 2,
			true), VIEW_TOP - 36), 2, Kit.INK_FAINT, 0.003, true)
	if slot != "" and seated(slot) == "":
		kit.label(_drawer, "NOTHING IS ON %s NOW" % str(keys()[key_index][
				"keycap"]).to_upper(), Vector2(LIST_X + 300, VIEW_TOP - 36),
				2, Kit.DEAD)
	_list = Node3D.new()
	_drawer.add_child(_list)
	for id: String in _order:
		_strip(id)
	_more_up = _more(true)
	_more_down = _more(false)
	# Which item is unfolded: the key remembers its own; a key with
	# something on it opens on that, the rest on nothing until entered.
	var remembered: String = sel.get(key_index, "")
	if remembered == "" or not _order.has(remembered):
		remembered = seated(slot) if slot != "" else ""
	unfolded = remembered
	_scroll_px = float(scroll.get(key_index, 0.0))
	_layout(at_once, y0)


func _strip(id: String) -> void:
	var node := Node3D.new()
	_list.add_child(node)
	var ground := kit.card(node, Vector2(0, 0), Vector2(LIST_W, STRIP_H - 4),
			0.002, kit.own(Kit.PLATE, 0.0), true)
	var slot := slot_of(key_index)
	var name := kit.label(node, kit.fit(_name(id), 2, 520), Vector2(COL_L, 14),
			2, Kit.INK, 0.004, false, true)
	kit.label(node, _mk(id), Vector2(COL_L + kit.measure(name.text, 2) + 14, 14),
			2, Kit.INK_FAINT, 0.004, false, true)
	var row: Dictionary = items[id]
	var right := LIST_W - 16
	if _authored(id):
		right -= kit.measure("AUTHORED", 2)
		kit.label(node, "AUTHORED", Vector2(right, 14), 2, Kit.DEAD, 0.004,
				false, true)
		right -= 24
	if bool(row.get("consumable", false)) and row.get("charges_max") != null:
		var n := "%d/%d" % [int(row["charges_left"]), int(row["charges_max"])]
		right -= kit.measure(n, 2, true)
		kit.label(node, n, Vector2(right, 14), 2, Kit.INK_DIM, 0.004, true, true)
		right -= 24
	if slot != "" and seated(slot) == id:
		var tag := ("PREVIEW ON %s, NOT SENT" if preview.has(slot)
				else "ON %s") % str(keys()[key_index]["keycap"]).to_upper()
		right -= kit.measure(tag, 2)
		kit.label(node, tag, Vector2(right, 14), 2,
				Kit.INK if preview.has(slot) else Kit.INK_FAINT, 0.004, false, true)
	_strips[id] = {"node": node, "ground": ground, "y": 0.0, "h": STRIP_H,
		"card": null}


func _more(up: bool) -> Node3D:
	var node := Node3D.new()
	_drawer.add_child(node)
	var y := VIEW_TOP - 14 if up else VIEW_BOTTOM + 2
	kit.sprite(node, "arrow_up" if up else "arrow_down",
			Vector2(LIST_X + LIST_W * 0.5 - 40, y + 6), 2, Kit.INK_DIM, 0.004)
	var l := kit.label(node, "", Vector2(LIST_X + LIST_W * 0.5 - 24, y - 2), 2,
			Kit.INK_DIM)
	node.set_meta("label", l)
	node.visible = false
	return node


## Where every strip goes, given what is unfolded; then the scroll that
## keeps the selected card in view; then the moves, all interruptible.
## `from_y`: strips start there (the socket) when the drawer first opens.
func _layout(at_once := false, from_y := -1.0, by_hand := false) -> void:
	var y := 0.0
	for id: String in _order:
		var s: Dictionary = _strips[id]
		var h := STRIP_H
		if id == unfolded:
			if s["card"] == null or not is_instance_valid(s["card"]):
				s["card"] = _card(id, s["node"])
			h = float((s["card"] as Node3D).get_meta("height"))
		elif s["card"] != null and is_instance_valid(s["card"]):
			var old: Node3D = s["card"]
			s["card"] = null
			kit.go(old, "scale:y", 0.001, 0.1, "in")
			kit.go(old, "visible", false, 0.0, "linear", 0.1)
			if kit.reduced:
				old.queue_free()
			else:
				_free_later(old, 0.12)
		s["y"] = y
		s["h"] = h
		y += h + 4.0
	var total := y
	var view := VIEW_BOTTOM - VIEW_TOP
	if unfolded != "" and _strips.has(unfolded) and not by_hand:
		var top: float = _strips[unfolded]["y"]
		var bottom: float = top + float(_strips[unfolded]["h"])
		if top < _scroll_px:
			_scroll_px = top
		elif bottom > _scroll_px + view:
			_scroll_px = minf(top, bottom - view)
	_scroll_px = clampf(_scroll_px, 0.0, maxf(0.0, total - view))
	scroll[key_index] = _scroll_px
	for id: String in _order:
		var s: Dictionary = _strips[id]
		var page_y: float = VIEW_TOP + float(s["y"]) - _scroll_px
		var to := Kit.at(Vector2(LIST_X, page_y), 0.0)
		var node: Node3D = s["node"]
		if from_y >= 0.0 and not kit.reduced:
			node.position = Kit.at(Vector2(LIST_X, from_y), 0.0)
			node.scale = Vector3(1, 0.001, 1)
			var i := _order.find(id)
			kit.go(node, "position", to, 0.22, "out", 0.018 * mini(i, 10))
			kit.go(node, "scale", Vector3.ONE, 0.16, "out", 0.018 * mini(i, 10))
		elif at_once:
			node.position = to
			node.scale = Vector3.ONE
		else:
			kit.go(node, "position", to, 0.18, "out")
			node.scale = Vector3.ONE
		var inside := page_y >= VIEW_TOP - 1.0 and \
				page_y + float(s["h"]) <= VIEW_BOTTOM + 1.0
		node.visible = inside
	var above := 0
	var below := 0
	for id: String in _order:
		var s: Dictionary = _strips[id]
		var page_y: float = VIEW_TOP + float(s["y"]) - _scroll_px
		if page_y < VIEW_TOP - 1.0:
			above += 1
		elif page_y + float(s["h"]) > VIEW_BOTTOM + 1.0:
			below += 1
	_set_more(_more_up, above)
	_set_more(_more_down, below)
	_mark_strips()


func _set_more(node: Node3D, n: int) -> void:
	node.visible = n > 0
	var l: Label3D = node.get_meta("label")
	l.text = kit.display("%d MORE" % n)


func _free_later(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())


## Grounds: the unfolded strip carries the plate; a hovered one a faint
## ground -- light only, never movement.
func _mark_strips() -> void:
	for id: String in _order:
		var s: Dictionary = _strips[id]
		var ground: MeshInstance3D = s["ground"]
		var a := 0.0
		if id == hover:
			a = 0.6
		if id == unfolded:
			a = 0.0          # the card carries its own plate
		kit.go(ground.material_override, "albedo_color", Color(Kit.PLATE, a),
				0.1)


# ------------------------------------------------------------ the card

## The unfolded module. Left: what it is and does. Right: what changes if
## it goes on its key -- against what is on the key NOW.
func _card(id: String, parent: Node3D) -> Node3D:
	var row: Dictionary = items[id]
	var slot := slot_of(key_index)
	var card := Node3D.new()
	parent.add_child(card)
	var content := Node3D.new()
	card.add_child(content)
	# Header: the name at 3x, the Mk, where it came from.
	kit.label(content, kit.fit(_name(id), 3, 640), Vector2(COL_L, 12), 3,
			Kit.INK, 0.03, false, true)
	var mk_x := COL_L + minf(kit.measure(_name(id), 3), 640) + 16
	kit.label(content, _mk(id), Vector2(mk_x, 20), 2, Kit.INK_DIM, 0.03,
			false, true)
	if _authored(id):
		kit.label(content, "AUTHORED FOR LAYOUT STRESS, NOT GAME CONTENT",
				Vector2(LIST_W - 16 - kit.measure(
				"AUTHORED FOR LAYOUT STRESS, NOT GAME CONTENT", 2), 20), 2,
				Kit.DEAD, 0.03, false, true)
	var y := 54.0
	var ly := y
	ly = _block(content, "", [str(row.get("description", ""))], COL_L, ly,
			COL_L_W, Kit.INK)
	ly = _block(content, "DOES", row["does"], COL_L, ly + 8, COL_L_W, Kit.INK)
	ly = _block(content, "HOW IT IS USED", row["use"], COL_L, ly + 8, COL_L_W,
			Kit.INK_DIM)
	ly = _block(content, "COST", row["cost"], COL_L, ly + 8, COL_L_W,
			Kit.INK_DIM)
	var ry := y
	var on := seated(slot) if slot != "" else ""
	if slot == "":
		ry = _block(content, "NO KEY", ["Always on while you own it. There "
				+ "is nothing to equip or turn off."], COL_R, ry, COL_R_W,
				Kit.INK_DIM)
	elif on == id:
		var words := "It is on %s now." % str(keys()[key_index]["keycap"])
		if preview.has(slot):
			words = "Previewed on %s. Not sent: the save still has %s." % [
					str(keys()[key_index]["keycap"]),
					_name(saved(slot)) if saved(slot) != "" else "nothing"]
		ry = _block(content, "ON THE KEY", [words], COL_R, ry, COL_R_W,
				Kit.INK_DIM)
	elif on == "":
		ry = _block(content, "NOTHING ON %s TO COMPARE" % str(keys()[
				key_index]["keycap"]).to_upper(), [], COL_R, ry, COL_R_W,
				Kit.INK_DIM)
	else:
		var lines: Array = ((data["comparisons"] as Dictionary).get(slot, {})
				as Dictionary).get(id, {}).get(on, [])
		ry = _block(content, "AGAINST %s, ON %s NOW" % [_name(on),
				str(keys()[key_index]["keycap"])], lines, COL_R, ry, COL_R_W,
				Kit.INK)
	var from := []
	for h: Dictionary in row.get("history", []):
		from.append("%s  %s, %s" % [str(h["mark"]), str(h["item"]),
				str(h["game"])])
	ry = _block(content, "FROM", from, COL_R, ry + 8, COL_R_W, Kit.INK_DIM)
	ry = _block(content, "READ", row.get("read", []), COL_R, ry + 8, COL_R_W,
			Kit.INK_FAINT)
	var h := maxf(ly, ry) + 16.0
	# The action, where the eye already is: the foot of the card.
	var act := _action(id)
	if act != "":
		var colour := Kit.SIGNAL if _can_preview(id) else Kit.INK_DIM
		if _can_preview(id):
			_prompt_cap(content, "ENTER", Vector2(COL_L, h))
			kit.label(content, act, Vector2(COL_L + 86, h + 5), 2, colour,
					0.03, false, true)
		else:
			kit.label(content, act, Vector2(COL_L, h + 5), 2, colour, 0.03,
					false, true)
		card.set_meta("action", Rect2(Vector2(COL_L - 6, h - 6),
				Vector2(kit.measure(act, 2) + 110, 38)))
		h += 42.0
	if note != "":
		kit.label(content, note, Vector2(COL_R, h - 36), 2, Kit.INK, 0.03,
				false, true)
	h += 10.0
	# The plate it all sits on: raised off the wall, lit, shading it.
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(LIST_W * Kit.px(), h * Kit.px(), 0.008)
	plate.mesh = box
	plate.material_override = kit.lit(Kit.PLATE_HI)
	plate.position = Kit.rel(Vector2(LIST_W, h) * 0.5, 0.018)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	card.add_child(plate)
	# Focus: a signal bar down its left edge -- a shape, not a glow.
	kit.card(card, Vector2(-8, 0), Vector2(5, h), 0.03, kit.flat(Kit.SIGNAL),
			true)
	card.set_meta("height", h)
	card.scale = Vector3(1, 0.001, 1)
	kit.go(card, "scale:y", 1.0, 0.16, "out", 0.04)
	return card


func _block(parent: Node3D, head: String, lines: Array, x: float, y: float,
		width: float, colour: Color) -> float:
	if head != "":
		kit.label(parent, head, Vector2(x, y), 2, Kit.INK_FAINT, 0.03, false,
				true)
		y += 24.0
	for raw: Variant in lines:
		var wrapped := kit.wrap(str(raw), 2, width)
		if wrapped.is_empty():
			continue
		kit.label(parent, "\n".join(wrapped), Vector2(x, y), 2, colour, 0.03,
				false, true)
		y += LINE * wrapped.size()
	return y


func _prompt_cap(parent: Node3D, cap: String, at: Vector2) -> void:
	var w := kit.measure(cap, 2) + 16.0
	var p := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w * Kit.px(), 26 * Kit.px(), 0.004)
	p.mesh = box
	p.material_override = kit.lit(Color("#c9d0db"))
	p.position = Kit.rel(at + Vector2(w, 26) * 0.5, 0.03)
	parent.add_child(p)
	kit.label(parent, cap, at + Vector2(8, 5), 2, Kit.SHADE, 0.034, false, true)


func _can_preview(id: String) -> bool:
	var slot := slot_of(key_index)
	if slot == "":
		return false
	var row: Dictionary = items[id]
	if str(row.get("held_back", "")) != "":
		return false
	if seated(slot) == id:
		return false                    # it is there already
	if preview.has(slot) and saved(slot) == id:
		return true                     # back to the save
	return str((row["refusal"] as Dictionary).get(slot, "")) == ""


## The one action a card offers, in words.
func _action(id: String) -> String:
	var slot := slot_of(key_index)
	if slot == "":
		return ""
	var row: Dictionary = items[id]
	var cap := str(keys()[key_index]["keycap"]).to_upper()
	if str(row.get("held_back", "")) != "":
		return str(row["held_back"])
	if seated(slot) == id:
		return ""
	if preview.has(slot) and saved(slot) == id:
		return "BACK TO THE SAVE: THIS ON %s" % cap
	var refusal := str((row["refusal"] as Dictionary).get(slot, ""))
	if refusal != "":
		return refusal
	return "PREVIEW ON %s" % cap


# ------------------------------------------------------------ actions

func nav(dir: Vector2i) -> void:
	note = ""
	if zone == "keys":
		if dir.y != 0:
			_focus_key(clampi(key_index + dir.y, 0, key_count() - 1))
		elif dir.x > 0 and not _order.is_empty():
			zone = "drawer"
			if unfolded == "":
				_select(_order[0])
		return
	if dir.x < 0:
		zone = "keys"
		return
	if dir.y != 0 and not _order.is_empty():
		var at := _order.find(unfolded)
		_select(_order[clampi(at + dir.y, 0, _order.size() - 1)])


func _focus_key(i: int, pointer := false) -> void:
	if i == key_index:
		return
	sel[key_index] = unfolded
	key_index = i
	zone = "keys" if not pointer else zone
	_place_focus_bar()
	_open_drawer(false)


func _select(id: String, keep_under_pointer := false) -> void:
	if id == unfolded:
		return
	var anchor := 0.0
	if keep_under_pointer and _strips.has(id):
		anchor = VIEW_TOP + float(_strips[id]["y"]) - _scroll_px
	unfolded = id
	sel[key_index] = id
	if keep_under_pointer:
		# Recompute where it will sit, then scroll so it stays put.
		var y := 0.0
		for other: String in _order:
			if other == id:
				break
			y += STRIP_H + 4.0
		_scroll_px = VIEW_TOP + y - anchor
	_layout()


func accept() -> void:
	if zone == "keys":
		nav(Vector2i(1, 0))
		return
	if unfolded == "" or not _can_preview(unfolded):
		return
	var slot := slot_of(key_index)
	if preview.has(slot) and saved(slot) == unfolded:
		preview.erase(slot)
		note = "BACK TO THE SAVE."
	else:
		preview[slot] = unfolded
		note = "PREVIEWED. NOT SENT."
	_row_text(key_index)
	var keep := unfolded
	_open_drawer(true)
	unfolded = ""
	_select(keep)


func back() -> bool:
	if zone == "drawer":
		zone = "keys"
		return true
	return false


## Hover lights, and never moves anything.
func hover_at(p: Vector2) -> void:
	var was := hover
	hover = _hit(p)
	if hover != was:
		_place_focus_bar()
		_mark_strips()


func click(p: Vector2) -> bool:
	var hit := _hit(p)
	if hit.begins_with("key:"):
		var i := int(hit.trim_prefix("key:"))
		zone = "keys"
		_focus_key(i, true)
		return true
	if hit == "action":
		accept()
		return true
	if hit != "":
		zone = "drawer"
		_select(hit, true)
		return true
	return false


func wheel(p: Vector2, dir: int) -> bool:
	if p.x < DRAWER_X:
		return false
	_scroll_px += 60.0 * dir
	_layout_scroll_only()
	return true


## Scrolling by hand moves the drawer and does not pull the card back
## into view.
func _layout_scroll_only() -> void:
	_layout(false, -1.0, true)


func _hit(p: Vector2) -> String:
	for i in _rows.size():
		var y: float = _rows[i]["y"]
		if Rect2(Vector2(LOAD_X - 12, y - 10), Vector2(LOAD_W + 24, 62)).has_point(p):
			return "key:%d" % i
	if p.x < LIST_X or p.x > LIST_X + LIST_W or p.y < VIEW_TOP or p.y > VIEW_BOTTOM:
		return ""
	for id: String in _order:
		var s: Dictionary = _strips[id]
		var top: float = VIEW_TOP + float(s["y"]) - _scroll_px
		if p.y >= top and p.y <= top + float(s["h"]):
			if id == unfolded and s["card"] != null and is_instance_valid(s["card"]):
				var card: Node3D = s["card"]
				if card.has_meta("action"):
					var r: Rect2 = card.get_meta("action")
					if Rect2(r.position + Vector2(LIST_X, top), r.size).has_point(p):
						return "action"
			return id
	return ""


func prompts() -> Array:
	if zone == "keys":
		return [["move", "keys"], ["into", "what fits"], ["click", "pick"],
			["turn_left", "turn left"], ["turn_right", "turn right"],
			["close", "close"]]
	var out := [["move", "items"]]
	if unfolded != "" and _can_preview(unfolded):
		out.append(["accept", _action(unfolded).to_lower()])
	out += [["out", "keys"], ["wheel", "scroll"], ["turn_left", "turn left"],
		["turn_right", "turn right"], ["close", "close"]]
	return out


func state() -> Dictionary:
	var rects := {}
	for id: String in _order:
		var s: Dictionary = _strips[id]
		rects[id] = [VIEW_TOP + float(s["y"]) - _scroll_px, float(s["h"])]
	return {"key": key_index, "slot": slot_of(key_index), "zone": zone,
		"unfolded": unfolded, "order": _order, "scroll": _scroll_px,
		"preview": preview.duplicate(), "hover": hover, "rects": rects,
		"strip_positions": _positions()}


func _positions() -> Dictionary:
	var out := {}
	for id: String in _order:
		var node: Node3D = _strips[id]["node"]
		out[id] = [snappedf(node.position.x, 0.0001), snappedf(node.position.y, 0.0001)]
	return out


func tick(_delta: float) -> void:
	pass
