class_name FaceEquipment
extends RefCounted
## EQUIPMENT (the Inventory): LEAF, as the hybrid's CABINET -- the owner's
## rulings of 2026-09-27: C's cabinet arrangement, with D's grafted rack.
##
## * THE INSPECTION WINDOW (original station hardware): what the item being
##   read IS, and what changes if it goes on the key. It swaps whole, in the
##   frame the input arrives -- no shutter, nothing to wait for.
## * THE KEY SELECTOR (original, the cabinet's oldest part): Production's
##   five keys (SLOT_NAMES, with the bindings SlotKeycaps names) and ALWAYS
##   ON -- passives take no key -- round one knob. Its pointer is the key
##   being looked at; each key's backlit window says what is on it. It is
##   driven by the ordinary selection inputs (UP / DOWN, a click, the wheel
##   over it): there is nothing to drag round.
## * THE RACK (salvaged, grafted into the cabinet's cut-down old bay): the
##   focused key's items as one clean list of modules. The one ON the key
##   is SEATED and its window says so; the one being READ is PULLED toward
##   you; a PREVIEW says NOT SENT. The rack keeps a fixed order (the save's
##   occupant first), and selecting never moves a row, so a click target
##   holds still. It scrolls a whole row at a time.
## * The joins: the brass bus -> its terminal -> a lead -> an adapter board
##   -> a ribbon -> the backplane; and the backplane's own ribbon, on round
##   the corner into Settings.
##
## Equipping is a LOCAL PREVIEW, labelled: it re-seats the key on this wall
## and nowhere else (no request, no save). Production's equip is a request
## with states; the preview says NOT SENT, which is one of them.

# ---- the cabinet
const WIN := Rect2(40, 108, 1200, 280)     # the inspection window
const MID_X := 640.0                       # its divider
const BUS_Y := 414.0
const BUS_END := 540.0
const TERM := Rect2(536, 400, 44, 28)      # the bus's terminal block
const ADAPTER := Rect2(542, 440, 38, 36)   # the adapter board under it
# ---- the key selector
const KNOB := Vector2(100, 572)
const BEZEL := 62.0
const ARC := Vector2(72, 110)              # the keys stand on this arc round it
const KEY_PITCH := 42.0
const KEY_WIN_X := 344.0                   # the keys' windows, one column
const KEY_WIN_W := 184.0
# ---- the rack
const BAY := Rect2(596, 424, 656, 290)     # the cabinet's old bay, as rebuilt
const OLD_BAY_END := 1004.0                # where the old bay's frame is cut
const ROW_X := 640.0
const ROW_END := 1180.0
const ROW_Y0 := 456.0
const ROW_PITCH := 28.0
const ROW_H := 25.0
const SHOWN := 9                           # rows the rack shows at once
const PULL := 26.0                         # how far a pulled module comes out
const BZ := 0.018                          # the backplane's face
const SEAT_Z := BZ + 0.006
const PULL_Z := BZ + 0.032
const TRACK := Rect2(1188, ROW_Y0, 8, ROW_PITCH * SHOWN - 3)   # the scroll pot
# ---- the readout
const COL_L := 64.0
const COL_L_W := 552.0
const COL_R := 668.0
const COL_R_W := 548.0
const TOP := 130.0
const BOTTOM := 380.0
const ACT_H := 36.0
const LINE := 20.0
const Z := 0.0022                          # the readout's words, in the window
const MOUSE_SYMBOL := Parts.MOUSE_SYMBOL

var kit: Kit
var shell: Shell
var face: Node3D
var data: Dictionary          # sample.equipment[variant]
var items := {}               # id -> row
var preview := {}             # slot -> id (the local preview)
var key_index := 0            # 0..4 the keys, 5 ALWAYS ON
var zone := "keys"            # keys | drawer (the rack)
var sel := {}                 # key -> selected id (each key remembers)
var scroll := {}              # key -> first row shown (each key remembers)
var hover := ""               # "key:<i>", "action", or an item id
var unfolded := ""            # the item being read
var note := ""                # a transient line (preview done)

var _order: Array = []        # the rack's ids, in order
var _first := 0               # the first row shown
var _stick_px := 0.0          # the right stick's scroll, not yet a row
var _keys: Array = []         # per key: {anchor, y, hit, bar, tick, plate}
var _keys_node: Node3D
var _pivot: Node3D            # the knob's pointer turns in this
var _rows := {}               # id -> {node, face_mat, tab_mat, hit, slot}
var _rack: Node3D
var _knob: Node3D             # the scroll pot's knob
var _readout: Node3D          # the composition for the selected item
var _info := {}               # what the readout drew (for state())


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("equipment")
	_build_cabinet()
	_build_dial()


func load_data(d: Dictionary) -> void:
	data = d
	items.clear()
	for row: Dictionary in data["items"]:
		items[str(row["id"])] = row
	for slot: String in preview.keys():
		if not items.has(str(preview[slot])):
			preview.erase(slot)
	_build_keys()
	_open_rack()


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
	return saved(slot)


func saved(slot: String) -> String:
	for key: Dictionary in keys():
		if str(key["slot"]) == slot:
			var holds: Variant = (key["view"] as Dictionary).get("holds")
			return "" if holds == null else str(holds)
	return ""


## The rack's items for a key: what the SAVE has on it first, then the rest
## in the fold's own order. A preview never reorders the rack -- the item
## previewed stays where it is (and says so), so nothing moves out from
## under a pointer that just clicked it. ALWAYS ON: the passives.
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


func _cap() -> String:
	return "" if slot_of(key_index) == "" \
			else str(keys()[key_index]["keycap"]).to_upper()


func _charges(id: String) -> String:
	var row: Dictionary = items[id]
	if bool(row.get("consumable", false)) and row.get("charges_max") != null:
		return "%d/%d" % [int(row["charges_left"]), int(row["charges_max"])]
	return ""


## Where an item stands with the focused key, in words: the same words on
## its module's window, in the readout's kicker, and in state().
func _stands(id: String) -> String:
	var slot := slot_of(key_index)
	if slot == "":
		return "ALWAYS ON · NO KEY"
	if seated(slot) == id:
		return "PREVIEW · NOT SENT" if preview.has(slot) else "ON " + _cap()
	if preview.has(slot) and saved(slot) == id:
		return "SAVED ON " + _cap()
	return ""


# ============================================================ the cabinet

## The fixed hardware: built once. What changes with the data is built by
## _build_keys and _open_rack; what changes with the selection, by
## _compose.
func _build_cabinet() -> void:
	var f := Node3D.new()
	f.name = "Cabinet"
	face.add_child(f)
	# ---- the harness feeds the cabinet: a branch off the trunk into an
	# original cable gland on the window's top
	var gx := 1200.0
	Parts.wire(f, [Vector2(gx, Parts.TRUNK_Y), Vector2(gx, WIN.position.y - 18)],
			Parts.WIRE, 3.5)
	Parts.sleeve(f, Vector2(gx, WIN.position.y - 30), true, 6.0, 14, Parts.WIRE_Z,
			Parts.mat(Color("#202225"), 0.05, 0.7))
	Parts.disc(f, Vector2(gx, WIN.position.y - 14), 11.0, 0.0, 0.016,
			Parts.mat(Parts.RIVET, 0.6, 0.4), 6)
	Parts.disc(f, Vector2(gx, WIN.position.y - 14), 6.5, 0.016, 0.022,
			Parts.mat(Parts.CAB_HI, 0.4, 0.5), 16)
	# ---- the inspection window and its divider
	Parts.window(f, WIN)
	Parts.block(f, Rect2(MID_X - 4, WIN.position.y, 8, WIN.size.y), 0.0, 0.012,
			Parts.mat(Parts.CAB_HI, 0.35, 0.5))
	# ---- the original bus, to its terminal block
	var brass := Parts.mat(Parts.BRASS, 0.7, 0.35)
	Parts.block(f, Rect2(40, BUS_Y - 5, BUS_END - 40, 10), 0.014, 0.022, brass)
	for x: float in [62.0, 300.0]:
		Parts.disc(f, Vector2(x, BUS_Y), 6.0, 0.0, 0.014, Parts.mat(Color("#1b1d1f"),
				0.2, 0.6), 14)
	Parts.slab(f, Parts.rrect(TERM, 3), 0.0, 0.02, Parts.mat(Parts.BAKELITE.lightened(
			0.05), 0.1, 0.45))
	for i in 2:
		Parts.disc(f, Vector2(TERM.position.x + 12 + 20 * i, BUS_Y), 5.0, 0.02, 0.026,
				brass, 12)
	# the selector's strap up to the bus
	Parts.block(f, Rect2(KNOB.x - 5, BUS_Y, 10, KNOB.y - BEZEL - BUS_Y + 4), 0.006,
			0.012, brass)
	_build_bay(f)


## The rack's fixed parts: the old bay, the adapter plate, the backplane and
## its connector, the scroll pot, and both joins.
func _build_bay(f: Node3D) -> void:
	# the cabinet's own bay: a recess only as wide as its old card cage was,
	# its riveted frame kept on the top and the left -- and the top bar cut
	# off where the rebuilt rack outgrew it: a bright cut face, and past it
	# the empty holes of the rivets that went with the rest of the bar
	var m := Parts.mat(Parts.CAB_HI, 0.35, 0.5)
	var old := Rect2(BAY.position.x, BAY.position.y, OLD_BAY_END - BAY.position.x,
			BAY.size.y)
	Parts.block(f, old, 0.0, 0.0008, Parts.mat(Parts.RECESS, 0.0, 0.95), false)
	Parts.block(f, Rect2(old.position.x - 12, old.position.y - 12, old.size.x + 12, 12),
			0.0, 0.014, m)
	Parts.block(f, Rect2(old.end.x, old.position.y - 12, 3, 12), 0.0, 0.014,
			Parts.mat(Color("#c7cbce"), 0.7, 0.3))
	Parts.block(f, Rect2(old.position.x - 12, old.position.y, 12, old.size.y), 0.0, 0.014, m)
	for p: Vector2 in [Vector2(old.position.x - 6, old.position.y - 6),
			Vector2(old.position.x + 200, old.position.y - 6),
			Vector2(old.position.x - 6, old.end.y - 10)]:
		Parts.rivet(f, p, 0.014)
	for x: float in [old.end.x + 60.0, old.end.x + 164.0]:
		Parts.disc(f, Vector2(x, old.position.y - 6), 3.0, 0.0, 0.0006,
				Parts.unlit(Color("#08090a")), 10, false)
	# the adapter plate: bare aluminium, bolted into the old bay
	var plate := Rect2(old.position.x + 4, old.position.y + 2, old.size.x - 2,
			old.size.y - 4)
	Parts.block(f, plate, 0.0008, 0.003, Parts.mat(Parts.PLATE, 0.55, 0.45))
	# the backplane: salvaged paper phenolic, past the bay to the wall's edge
	var bp := PackedVector2Array([Vector2(BAY.position.x + 16, BAY.position.y + 2),
		Vector2(1216, BAY.position.y + 2), Vector2(1216, 692), Vector2(1194, 714),
		Vector2(BAY.position.x + 40, 714), Vector2(BAY.position.x + 16, 690)])
	Parts.board(f, bp, Parts.PHENOLIC, BZ, [Vector2(BAY.position.x + 28, BAY.position.y
			+ 14), Vector2(1204, BAY.position.y + 14), Vector2(BAY.position.x + 28, 700),
			Vector2(1182, 702)])
	# the edge connector every module plugs into
	Parts.header(f, Rect2(ROW_X - 14, ROW_Y0 - 2, 12, ROW_PITCH * SHOWN - 1), BZ)
	# the scroll: a repurposed slide pot; its knob is placed by _place_knob
	Parts.block(f, TRACK, BZ, BZ + 0.004, Parts.mat(Color("#0b0b0b"), 0.1, 0.8))
	_knob = Node3D.new()
	f.add_child(_knob)
	# ---- the join back into the cabinet: the bus's terminal, a short lead,
	# an adapter board, and a ribbon into the backplane's own connector
	Parts.board(f, Parts.rrect(ADAPTER, 3), Parts.BLACK_MASK, 0.018,
			[ADAPTER.position + Vector2(9, 9)])
	Parts.block(f, Rect2(ADAPTER.position.x + 20, ADAPTER.position.y + 5, 20, 10), 0.018,
			0.028, Parts.mat(Parts.TERMINAL, 0.1, 0.5))
	Parts.wire(f, [Vector2(TERM.position.x + 32, BUS_Y + 4), Vector2(TERM.position.x + 32,
			ADAPTER.position.y + 10)], Parts.IVORY.darkened(0.25), 1.8, 0.024, 4.0)
	Parts.header(f, Rect2(ADAPTER.end.x - 12, ADAPTER.position.y + 14, 8, 22), 0.018)
	Parts.ribbon(f, [Vector2(ADAPTER.end.x - 8, ADAPTER.position.y + 25),
			Vector2(ROW_X - 8, ADAPTER.position.y + 25)], 0.034)
	# ---- and on round the corner into Settings: the backplane's ribbon
	Parts.header(f, Rect2(1203, Parts.RIBBON_Y - 12, 10, 24), BZ)
	Parts.ribbon(f, [Vector2(1208, Parts.RIBBON_Y), Vector2(Parts.RUN_END,
			Parts.RIBBON_Y)], Parts.RIBBON_Z)
	var grey := Parts.mat(Parts.RIBBON, 0.1, 0.6)
	for kk in 6:
		Parts.corner(shell, face, shell.face_of("settings"), Parts.RIBBON_Y
				+ (float(kk) - 2.5) * 3.4, 1.7, grey, Parts.RIBBON_Z)


# ============================================================ the selector

## Where key `i` stands: on an arc round the knob, a detent apart.
func _anchor(i: int) -> Vector2:
	var dy := KEY_PITCH * (float(i) - 2.5)
	var s := clampf(dy / ARC.y, -1.0, 1.0)
	return KNOB + Vector2(ARC.x * sqrt(1.0 - s * s), dy)


## The pointer's angle for key `i` (0 = right, down is +): at the key.
func _angle(i: int) -> float:
	var d := _anchor(i) - KNOB
	return atan2(d.y, d.x)


## The knob: bezel, detent marks, skirt, and the pointer -- which turns in
## `_pivot`, about the knob's centre as the eye sees it.
func _build_dial() -> void:
	var f := Node3D.new()
	f.name = "Selector"
	face.add_child(f)
	Parts.disc(f, KNOB, BEZEL, 0.0, 0.005, Parts.mat(Parts.CAB_HI, 0.3, 0.55), 40)
	Parts.ring(f, KNOB, BEZEL - 4, BEZEL + 1, 0.005, Parts.mat(Parts.BRASS, 0.7, 0.35))
	Parts.disc(f, KNOB, 40, 0.005, 0.02, Parts.mat(Parts.BAKELITE.lightened(0.08), 0.1,
			0.45), 36)
	Parts.disc(f, KNOB, 30, 0.02, 0.05, Parts.mat(Parts.BAKELITE, 0.1, 0.4), 32)
	var z1 := 0.056
	_pivot = Node3D.new()
	_pivot.name = "Pointer"
	f.add_child(_pivot)
	var centre := Kit.at(Kit.lifted(KNOB, z1), 0.0)
	_pivot.position = centre
	var arm := Node3D.new()
	_pivot.add_child(arm)
	arm.position = -centre
	Parts.pointer(arm, KNOB, 0.0, 6, 42, 5.0, 0.05, z1, Parts.mat(Color("#e9e4d6"), 0.1,
			0.5))


## Each key round the knob: its detent mark, its keycap and name, and its
## backlit window -- what is on it now.
func _build_keys() -> void:
	if _keys_node != null:
		_keys_node.queue_free()
	_keys_node = Node3D.new()
	face.add_child(_keys_node)
	_keys.clear()
	for i in key_count():
		var a := _anchor(i)
		var y := a.y
		var entry := {"anchor": a, "y": y}
		var tick_mat := Parts.own(Parts.FAINT)
		Parts.pointer(_keys_node, KNOB, _angle(i), 48, 58, 1.8, 0.005, 0.007, tick_mat)
		entry["tick"] = tick_mat
		var hit := Rect2(a.x - 4, y - 16, KEY_WIN_X + KEY_WIN_W - a.x + 8, 32)
		entry["hit"] = hit
		# the hover ground: light only, never movement
		var ground := Parts.own(Parts.CAB_HI.lightened(0.12))
		ground.albedo_color.a = 0.0
		Parts.block(_keys_node, hit, 0.0, 0.0012, ground, false)
		entry["ground"] = ground
		# the keys' focus: a SIGNAL bar at the key, while the keys have it
		var bar := Parts.own(Kit.SIGNAL)
		Parts.block(_keys_node, Rect2(a.x, y - 11, 4, 22), 0.0012, 0.004, bar, false)
		entry["bar"] = bar
		var x := a.x + 10.0
		if i < keys().size():
			var key: Dictionary = keys()[i]
			x += Parts.keycap(kit, _keys_node, str(key["keycap"]), Vector2(x, y - 13),
					0.002) + 10.0
			entry["title"] = Parts.text(kit, _keys_node, str(key["title"]), Vector2(x,
					y - 8), 2, Parts.DIM, 0.003)
		else:
			entry["title"] = Parts.text(kit, _keys_node, "ALWAYS ON", Vector2(x, y - 8), 2,
					Parts.DIM, 0.003)
		var words := _key_words(i)
		var fw := Rect2(KEY_WIN_X, y - 11, KEY_WIN_W, 22)
		var count := str(words[2])
		var cw := kit.measure(count, 2) + 8.0 if count != "" else 0.0
		var l := Parts.flag_window(kit, _keys_node, fw.grow_individual(0, 0, -cw, 0),
				words[0], words[1], 0.004)
		if count != "":
			# a consumable's charges: always shown, never cut
			Parts.block(_keys_node, Rect2(fw.end.x - cw - 3, fw.position.y, cw + 3, fw.size.y),
					0.004, 0.0046, Parts.mat(Parts.RECESS, 0.0, 0.95), false)
			Parts.text(kit, _keys_node, count, Vector2(fw.end.x - cw, fw.position.y + 3), 2,
					words[1], 0.0058)
		entry["words"] = (l.text + (" " + count if count != "" else "")).strip_edges()
		_keys.append(entry)
	_mark_keys(true)


## A key's window: what is on it (a preview says so first), or EMPTY; and
## a consumable's charges, apart.
func _key_words(i: int) -> Array:
	var slot := slot_of(i)
	if slot == "":
		return ["NO KEY · %d" % candidates(i).size(), Parts.LIT_DIM, ""]
	var on := seated(slot)
	if on == "":
		return ["EMPTY", Parts.LIT_FAINT, ""]
	var words := _name(on)
	if preview.has(slot):
		words = "PREVIEW: " + words
	return [words, Parts.LIT, _charges(on)]


## The selector's state on the wall: the pointer at the key being looked at
## (a detent's turn), its mark lit, its words bright; the SIGNAL bar while
## the keys have the focus; a faint ground under a hovered key.
func _mark_keys(at_once := false) -> void:
	var to := -_angle(key_index)
	if at_once:
		_pivot.rotation.z = to
	else:
		kit.go(_pivot, "rotation:z", to, 0.1, "out")
	for i in _keys.size():
		var e: Dictionary = _keys[i]
		var here := i == key_index
		(e["tick"] as StandardMaterial3D).albedo_color = Parts.INK if here else Parts.FAINT
		(e["bar"] as StandardMaterial3D).albedo_color = Color(Kit.SIGNAL, 1.0
				if here and zone == "keys" else 0.0)
		(e["ground"] as StandardMaterial3D).albedo_color = Color(Parts.CAB_HI.lightened(
				0.12), 0.9 if hover == "key:%d" % i and not here else 0.0)
		(e["title"] as Label3D).modulate = Parts.INK if here else Parts.DIM


# ============================================================ the rack

## The focused key's rack: its modules, in order, from the row the key
## remembers; what it holds is SEATED, what is being read is PULLED.
func _open_rack() -> void:
	_order = candidates(key_index)
	var slot := slot_of(key_index)
	var remembered: String = sel.get(key_index, "")
	if remembered == "" or not _order.has(remembered):
		remembered = seated(slot) if slot != "" else ""
	unfolded = remembered
	_first = int(scroll.get(key_index, 0))
	_stick_px = 0.0
	_keep_in_view()
	_build_rows()
	_compose()


func _max_first() -> int:
	return maxi(0, _order.size() - SHOWN)


## Keyboard and pad: the selected row is always shown (a hand scroll moves
## only the rack).
func _keep_in_view() -> void:
	var at := _order.find(unfolded)
	if at >= 0:
		if at < _first:
			_first = at
		elif at >= _first + SHOWN:
			_first = at - SHOWN + 1
	_first = clampi(_first, 0, _max_first())
	scroll[key_index] = _first


func _row_y(i: int) -> float:
	return ROW_Y0 + ROW_PITCH * float(i - _first)


func _build_rows(at_once := true) -> void:
	if _rack != null:
		_rack.queue_free()
	_rack = Node3D.new()
	face.add_child(_rack)
	_rows.clear()
	var slot := slot_of(key_index)
	var head := "FITS %s · %d" % [_cap(), _order.size()] if slot != "" \
			else "ALWAYS ON · NO KEY · %d" % _order.size()
	Parts.text(kit, _rack, head, Vector2(ROW_X, BAY.position.y + 10), 2, Parts.SILK, BZ
			+ 0.0006)
	var above := _first
	var below := maxi(0, _order.size() - _first - SHOWN)
	var mx := ROW_END
	for pair: Array in [[below, "arrow_down", "%d MORE BELOW"], [above, "arrow_up",
			"%d MORE ABOVE"]]:
		if int(pair[0]) <= 0:
			continue
		var words := kit.display(str(pair[2]) % int(pair[0]))
		var w := kit.measure(words, 2)
		Parts.text(kit, _rack, words, Vector2(mx - w, BAY.position.y + 10), 2,
				Parts.SILK_DIM, BZ + 0.0006)
		Parts.sprite(kit, _rack, str(pair[1]), Vector2(mx - w - 12, BAY.position.y + 18),
				2, Parts.SILK_DIM, BZ + 0.0008)
		mx -= w + 34.0
	_info_more = [above, below]
	if _order.is_empty():
		var words := "NOTHING YOU HOLD GOES ON %s" % _cap()
		Parts.tape(kit, _rack, Vector2(ROW_X + 20, ROW_Y0 + 14), words, BZ)
	for i in range(_first, mini(_first + SHOWN, _order.size())):
		_module(_order[i], i)
	_place_knob(at_once)
	_mark_rows(true)


var _info_more := [0, 0]


## One module: its face on the backplane, its gold contacts in the
## connector, its pull, its name and tags, and -- if it is on the key -- its
## window, which says so.
func _module(id: String, i: int) -> void:
	var y := _row_y(i)
	var node := Node3D.new()
	node.set_meta("id", id)
	_rack.add_child(node)
	var r := Rect2(ROW_X, y, ROW_END - ROW_X, ROW_H)
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Parts.MODULE
	face_mat.metallic = 0.15
	face_mat.roughness = 0.55
	face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Parts.slab(node, Parts.rrect(r, 2), BZ + 0.0005, SEAT_Z, face_mat)
	Parts.block(node, Rect2(r.position.x - 8, y + 6, 10, ROW_H - 12), SEAT_Z - 0.003,
			SEAT_Z - 0.0012, Parts.mat(Parts.GOLD, 0.8, 0.3), false)
	var tab_mat := StandardMaterial3D.new()
	tab_mat.albedo_color = Parts.BAKELITE
	tab_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Parts.block(node, Rect2(r.position.x + 6, y + 5, 10, ROW_H - 10), SEAT_Z, SEAT_Z + 0.014,
			tab_mat)
	var zt := SEAT_Z + 0.0008
	var stands := _stands(id) if slot_of(key_index) != "" else ""
	var right := r.end.x - 8.0
	if stands != "":
		var ww := kit.measure(stands, 2) + 16.0
		var fw := Rect2(right - ww, y + 3, ww, ROW_H - 6)
		Parts.block(node, fw, SEAT_Z, SEAT_Z + 0.0006, Parts.mat(Parts.RECESS, 0.0, 0.95),
				false)
		Parts.text(kit, node, stands, fw.position + Vector2(8, 2), 2, Parts.LIT if
				stands.begins_with("ON") or stands.begins_with("PREVIEW")
				else Parts.LIT_DIM, SEAT_Z + 0.0018)
		right = fw.position.x - 10.0
	var tags := [_mk(id)]
	if _charges(id) != "":
		tags.append(_charges(id))
	if _authored(id):
		tags.append("AUTHORED")
	var t := " · ".join(tags)
	var tw := kit.measure(t, 2)
	var tag_l := Parts.text(kit, node, t, Vector2(right - tw, y + 5), 2, Parts.SILK_FAINT, zt)
	var name_w := right - tw - 16.0 - (r.position.x + 26.0)
	var name_l := Parts.text(kit, node, kit.fit(_name(id), 2, name_w), Vector2(r.position.x
			+ 26, y + 5), 2, Parts.SILK_DIM, zt)
	var c := r.get_center()
	var out := Parts.P(c + Vector2(-PULL, 0), PULL_Z) - Parts.P(c, SEAT_Z)
	_rows[id] = {"node": node, "face": face_mat, "tab": tab_mat, "name": name_l,
		"tags": tag_l, "out": out, "hit": Rect2(r.position.x - PULL, y, r.size.x + PULL,
		ROW_H), "index": i, "stands": stands, "words": "%s | %s" % [name_l.text,
		tag_l.text]}


## The rack's state on the wall: the module being read pulled out (its tab
## SIGNAL while the rack has the focus), every other one home; a hovered
## one's face lit a little -- light only, never movement.
func _mark_rows(at_once := false) -> void:
	for id: String in _rows:
		var r: Dictionary = _rows[id]
		var node: Node3D = r["node"]
		var pulled := id == unfolded
		var to: Vector3 = r["out"] if pulled else Vector3.ZERO
		if at_once:
			node.position = to
		else:
			kit.go(node, "position", to, 0.1, "out")
		(r["tab"] as StandardMaterial3D).albedo_color = Kit.SIGNAL if pulled \
				and zone == "drawer" else (Parts.BAKELITE.lightened(0.25) if pulled
				else Parts.BAKELITE)
		var lit := pulled or id == hover
		(r["face"] as StandardMaterial3D).albedo_color = Parts.MODULE.lightened(0.09
				if lit else 0.0)
		var bright := pulled or str(r["stands"]) != ""
		(r["name"] as Label3D).modulate = Parts.SILK if bright else Parts.SILK_DIM
		(r["tags"] as Label3D).modulate = Parts.SILK_DIM if pulled else Parts.SILK_FAINT


## The scroll pot's knob: its length the share of the rack shown, its
## place the share scrolled past. Built at the top of its track; a scroll
## slides it (at once when motion is reduced).
var _knob_h := 0.0


func _place_knob(at_once := false) -> void:
	var n := maxi(_order.size(), 1)
	var h := maxf(24.0, TRACK.size.y * minf(1.0, float(SHOWN) / float(n)))
	var z := BZ + 0.012
	if absf(h - _knob_h) > 0.01:
		for c: Node in _knob.get_children():
			c.queue_free()
		Parts.block(_knob, Rect2(TRACK.position.x - 4, TRACK.position.y, 16, h),
				BZ + 0.004, z, Parts.mat(Color("#cfd2cf"), 0.2, 0.5))
		_knob_h = h
		at_once = true
	var dy := (TRACK.size.y - h) * float(_first) / float(_max_first()) \
			if _max_first() > 0 else 0.0
	var to := Parts.P(Vector2(TRACK.position.x, TRACK.position.y + dy), z) \
			- Parts.P(Vector2(TRACK.position.x, TRACK.position.y), z)
	if at_once:
		_knob.position = to
	else:
		kit.go(_knob, "position", to, 0.08, "out")


# ============================================================ the readout

## The item being read, composed: built whole and at once -- the words
## never scale or slide; the rack and the selector carry the movement.
func _compose() -> void:
	if _readout != null:
		_readout.queue_free()
	_readout = Node3D.new()
	_readout.set_meta("composition", true)
	face.add_child(_readout)
	_info = {}
	if unfolded == "":
		_compose_key()
	else:
		_compose_item(unfolded)


## Nothing selected: the key itself, in the same window.
func _compose_key() -> void:
	var slot := slot_of(key_index)
	var title := str(keys()[key_index]["title"]) if slot != "" else "ALWAYS ON"
	var x := COL_L
	var y := TOP
	if slot != "":
		x += Parts.keycap(kit, _readout, str(keys()[key_index]["keycap"]),
				Vector2(COL_L, y - 5), Z) + 12.0
	Parts.text(kit, _readout, "A KEY" if slot != "" else "NO KEY", Vector2(x, y), 2,
			Parts.LIT_DIM, Z)
	y += 30.0
	Parts.text(kit, _readout, title, Vector2(COL_L, y), 5, Parts.LIT, Z)
	y += 58.0
	var words := []
	if slot != "":
		var on := seated(slot)
		words.append("NOTHING IS ON %s NOW." % _cap() if on == ""
				else "%s IS ON %s NOW." % [_name(on), _cap()])
	if _order.is_empty():
		words.append("NOTHING YOU HOLD GOES HERE.")
	else:
		words.append("%d FIT. MOVE INTO THE RACK TO READ ONE." % _order.size())
	for w: String in words:
		for line in kit.wrap(w, 2, COL_L_W):
			Parts.text(kit, _readout, line, Vector2(COL_L, y), 2, Parts.LIT_DIM, Z)
			y += LINE
	_info["bottom"] = y
	_info["fits"] = y <= BOTTOM
	_info["id"] = ""


## The read item: on the left what it IS (where it stands with the key, its
## name, what it does, what it is, how it is used and what it costs); on
## the right what CHANGES if it goes on the key (Production's own lines,
## EquipmentQuery.comparison, aligned) and where it came from; at the foot
## on the right, the one action. Every block is placed, never dropped: if a
## column would overflow, its sizes step down (the name first, never below
## 3x; then what it does, never below 2x), and the history goes wherever
## there is room.
func _compose_item(id: String) -> void:
	var row: Dictionary = items[id]
	var slot := slot_of(key_index)
	var on := seated(slot) if slot != "" else ""
	# ---- the right column's blocks, measured
	var right: Array = []           # [kind, payload] in order
	var head := ""
	var compare: Array = []
	if slot == "":
		head = "NO KEY · NOTHING TO COMPARE"
	elif on == id:
		head = "ON THE KEY"
		var words := "It is on %s now." % str(keys()[key_index]["keycap"])
		if preview.has(slot):
			words = "Previewed on %s. Not sent: the save still has %s." % [
					str(keys()[key_index]["keycap"]),
					_name(saved(slot)) if saved(slot) != "" else "nothing"]
		right.append(["words", [words]])
	elif on == "":
		head = "NOTHING ON %s TO COMPARE" % _cap()
	else:
		head = "IF ON %s, IN PLACE OF %s" % [_cap(), _name(on)]
		compare = ((data["comparisons"] as Dictionary).get(slot, {}) as Dictionary).get(id,
				{}).get(on, [])
		_info["compared"] = on
	var act := _action(id)
	var can := act != "" and _can_preview(id)
	# the foot: a button for an action that can be taken; a refusal's own
	# words, whole, for one that cannot
	var refusal: PackedStringArray = kit.wrap(act, 2, COL_R_W - 150.0) \
			if act != "" and not can else PackedStringArray()
	var foot := BOTTOM
	if can or note != "":
		foot = BOTTOM - ACT_H - 6.0
	elif not refusal.is_empty():
		foot = BOTTOM - LINE * refusal.size() - 6.0
	var hist := _history(id)
	var r_h := LINE * kit.wrap(head, 2, COL_R_W).size() + 8.0
	for b: Array in right:
		for w: String in b[1]:
			r_h += LINE * kit.wrap(w, 2, COL_R_W).size()
	var t_pitch := LINE
	var t_h := _table_h(compare, COL_R_W, t_pitch)
	var h_h := LINE * hist.size()
	# ---- the left column, at the largest sizes that fit
	var plan := {}
	var left_room := BOTTOM - TOP
	for option: Array in [[5, 3], [4, 3], [5, 2], [4, 2], [3, 2]]:
		plan = _left_plan(id, int(option[0]), int(option[1]))
		if float(plan["h"]) <= left_room:
			break
	# the history on the right under the comparison if it fits there; else
	# under the left column if it fits there; else the comparison closes up
	var hist_left := false
	var h_gap := 10.0 if h_h > 0.0 else 0.0
	if TOP + r_h + t_h + h_gap + h_h > foot:
		if float(plan["h"]) + 12.0 + h_h <= left_room:
			hist_left = true
		else:
			t_pitch = 18.0
			if TOP + r_h + _table_h(compare, COL_R_W, t_pitch) + h_gap + h_h > foot:
				hist_left = float(plan["h"]) + 12.0 + h_h <= left_room
	# ---- the left column, drawn
	var y := _draw_left(id, plan)
	if hist_left:
		y += 12.0
		y = _draw_history(hist, COL_L, y, COL_L_W)
	_info["left_bottom"] = y
	# ---- the right column, drawn
	var ry := TOP
	for line in kit.wrap(head, 2, COL_R_W):
		Parts.text(kit, _readout, line, Vector2(COL_R, ry), 2, Parts.LIT_DIM, Z)
		ry += LINE
	ry += 8.0
	for b: Array in right:
		for w: String in b[1]:
			for line in kit.wrap(w, 2, COL_R_W):
				Parts.text(kit, _readout, line, Vector2(COL_R, ry), 2, Parts.LIT, Z)
				ry += LINE
	if not compare.is_empty():
		ry = _table(compare, COL_R, ry, COL_R_W, t_pitch)
	if not hist_left and not hist.is_empty():
		ry = _draw_history(hist, COL_R, ry + 10.0, COL_R_W)
	_info["right_bottom"] = ry
	# ---- the foot: the one action, always in the same place
	var ay := BOTTOM - ACT_H
	if can:
		var words := kit.fit(act, 2, COL_R_W - 104.0)
		var rect := Rect2(COL_R - 4, ay, kit.measure(words, 2) + 110.0, ACT_H)
		Parts.slab(_readout, Parts.rrect(rect, 6), 0.0, 0.01, Parts.mat(Parts.ACT, 0.1,
				0.6))
		_prompt_cap(Vector2(COL_R + 6, ay + 5), 0.01)
		Parts.text(kit, _readout, words, Vector2(COL_R + 94, ay + 10), 2, Kit.SIGNAL,
				0.0112)
		_info["action"] = rect
		_info["action_words"] = words
	elif not refusal.is_empty():
		var fy := BOTTOM - LINE * refusal.size()
		for line in refusal:
			Parts.text(kit, _readout, line, Vector2(COL_R, fy), 2, Parts.LIT_DIM, Z)
			fy += LINE
		_info["action_words"] = " ".join(refusal)
	elif note != "":
		Parts.text(kit, _readout, note, Vector2(COL_R, ay + 10), 2, Parts.LIT, Z)
		_info["note"] = note
	if _authored(id):
		var tag := "AUTHORED SAMPLE"
		Parts.text(kit, _readout, tag, Vector2(WIN.end.x - 24 - kit.measure(tag, 2), ay + 10),
				2, Parts.LIT_FAINT, Z)
	_info["id"] = id
	_info["name_k"] = plan["name_k"]
	_info["name_lines"] = (plan["name"] as PackedStringArray).size()
	_info["does_k"] = plan["does_k"]
	_info["table_pitch"] = t_pitch
	_info["history_left"] = hist_left
	_info["bottom"] = maxf(float(_info["left_bottom"]), ry)
	_info["foot"] = foot
	# nothing crosses the foot or the window's edge, and nothing was dropped
	_info["fits"] = float(_info["left_bottom"]) <= BOTTOM + 0.5 and ry <= foot + 0.5
	_info["stands"] = _stands(id)


## The left column's plan at name size `nk` and DOES size `dk`: its lines
## and its height.
func _left_plan(id: String, nk: int, dk: int) -> Dictionary:
	var row: Dictionary = items[id]
	var name := kit.wrap(_name(id), nk, COL_L_W)
	if name.size() > 2 and nk > 3:
		return {"h": INF, "name": name, "name_k": nk, "does_k": dk}
	var h := 30.0                                   # the kicker
	h += (8.0 * nk + 6.0) * name.size() + 6.0
	var does: Array = []
	for line: Variant in row.get("does", []):
		for l in kit.wrap(str(line), dk, COL_L_W - 64.0):
			does.append(l)
	h += (8.0 * dk + 6.0) * does.size() + 4.0
	var desc := kit.wrap(str(row.get("description", "")), 2, COL_L_W)
	h += LINE * desc.size() + 6.0
	var uses: Array = []
	for line: Variant in row.get("use", []):
		for l in kit.wrap(str(line), 2, COL_L_W - 64.0):
			uses.append(l)
	var costs: Array = []
	for line: Variant in row.get("cost", []):
		for l in kit.wrap(str(line), 2, COL_L_W - 64.0):
			costs.append(l)
	h += LINE * (uses.size() + costs.size())
	return {"h": h, "name": name, "name_k": nk, "does_k": dk, "does": does,
		"desc": desc, "use": uses, "cost": costs}


func _draw_left(id: String, plan: Dictionary) -> float:
	var row: Dictionary = items[id]
	var slot := slot_of(key_index)
	var x := COL_L
	var y := TOP
	# the kicker: the key, where this stands with it, and what kind of thing
	var stands := _stands(id)
	var kick := "FITS THIS KEY" if slot != "" else "ALWAYS ON · NO KEY"
	if stands.begins_with("ON "):
		kick = "ON THIS KEY NOW"
	elif stands.begins_with("PREVIEW"):
		kick = "PREVIEW ON THIS KEY · NOT SENT"
	elif stands.begins_with("SAVED"):
		kick = "SAVED ON THIS KEY"
	if slot != "":
		x += Parts.keycap(kit, _readout, str(keys()[key_index]["keycap"]), Vector2(COL_L,
				y - 5), Z) + 12.0
	Parts.text(kit, _readout, kick, Vector2(x, y), 2, Parts.LIT if stands != ""
			else Parts.LIT_DIM, Z)
	var kind := "%s · %s" % [str(row.get("family", "")), _mk(id)]
	Parts.text(kit, _readout, kind, Vector2(MID_X - 24 - kit.measure(kind, 2), y), 2,
			Parts.LIT_DIM, Z)
	y += 30.0
	var nk: int = plan["name_k"]
	for line: String in plan["name"]:
		Parts.text(kit, _readout, line, Vector2(COL_L, y), nk, Parts.LIT, Z)
		y += 8.0 * nk + 6.0
	y += 6.0
	var dk: int = plan["does_k"]
	Parts.text(kit, _readout, "DOES", Vector2(COL_L, y + (4.0 if dk == 3 else 0.0)), 2,
			Parts.LIT_FAINT, Z)
	for line: String in plan["does"]:
		Parts.text(kit, _readout, line, Vector2(COL_L + 64, y), dk, Parts.LIT, Z)
		y += 8.0 * dk + 6.0
	y += 4.0
	for line: String in plan["desc"]:
		Parts.text(kit, _readout, line, Vector2(COL_L, y), 2, Parts.LIT_DIM, Z)
		y += LINE
	_info["desc_lines"] = (plan["desc"] as PackedStringArray).size()
	y += 6.0
	for block: Array in [["USE", plan["use"]], ["COST", plan["cost"]]]:
		var lines: Array = block[1]
		if lines.is_empty():
			continue
		Parts.text(kit, _readout, block[0], Vector2(COL_L, y), 2, Parts.LIT_FAINT, Z)
		for line: String in lines:
			Parts.text(kit, _readout, line, Vector2(COL_L + 64, y), 2, Parts.LIT_DIM, Z)
			y += LINE
	return y


## Where it came from: every item that went into it, one line each --
## Production's history, "Mk  note ← item (game)"; the create's note is the
## name above, so it is not said twice.
func _history(id: String) -> Array:
	var out := []
	for link: Dictionary in items[id].get("history", []):
		var what := "← %s (%s)" % [str(link["item"]), str(link["game"])]
		if str(link.get("operation", "")) != "create":
			# Production's note can carry a raw field name ("+40 max_value"):
			# the face has no underscore, so it is printed as a space (and
			# reported in the handoff, not hidden)
			what = "%s %s" % [str(link["note"]).replace("_", " "), what]
		out.append([str(link["mark"]), what])
	return out


func _draw_history(hist: Array, x: float, y: float, width: float) -> float:
	for h: Array in hist:
		Parts.text(kit, _readout, str(h[0]), Vector2(x, y), 2, Parts.LIT_FAINT, Z)
		Parts.text(kit, _readout, kit.fit(str(h[1]), 2, width - 64.0), Vector2(x + 64, y), 2,
				Parts.LIT_FAINT, Z)
		y += LINE
	return y


## Production's comparison lines set as a table: the label, what is on the
## key now, the arrow, what this would make it -- values aligned on the
## arrow. A change too long for a row gets its label and old value on one
## line and the arrow and the new value under it; a line that is not a
## change at all is printed whole. The words are Production's; only the
## setting is ours.
func _table(lines: Array, x: float, y: float, width: float, pitch: float) -> float:
	var rows := []
	var lw := 0.0
	var ow := 0.0
	for raw: Variant in lines:
		var r := _change(str(raw))
		if not r.is_empty() and kit.measure(r["old"], 2) <= 96.0 \
				and kit.measure(r["new"], 2) <= 96.0:
			r["row"] = true
			lw = maxf(lw, kit.measure(r["label"], 2))
			ow = maxf(ow, kit.measure(r["old"], 2))
		rows.append(r)
	var old_right := x + lw + 16.0 + ow
	var arrow_x := old_right + 10.0
	var new_x := arrow_x + kit.measure("→", 2) + 10.0
	for i in rows.size():
		var r: Dictionary = rows[i]
		if r.is_empty():
			for line in kit.wrap(str(lines[i]), 2, width):
				Parts.text(kit, _readout, line, Vector2(x, y), 2, Parts.LIT, Z)
				y += pitch
			continue
		if not r.get("row", false):
			var lw2 := kit.measure(r["label"], 2) + 16.0
			Parts.text(kit, _readout, r["label"], Vector2(x, y), 2, Parts.LIT_FAINT, Z)
			if lw2 + kit.measure(r["old"], 2) <= width:
				Parts.text(kit, _readout, r["old"], Vector2(x + lw2, y), 2, Parts.LIT_DIM, Z)
				y += pitch
			else:
				y += pitch
				Parts.text(kit, _readout, kit.fit(r["old"], 2, width - 24), Vector2(x + 24,
						y), 2, Parts.LIT_DIM, Z)
				y += pitch
				lw2 = 24.0
			Parts.text(kit, _readout, kit.fit("→ " + str(r["new"]), 2, width - lw2),
					Vector2(x + lw2, y), 2, Parts.LIT, Z)
			y += pitch + 2.0
			continue
		Parts.text(kit, _readout, r["label"], Vector2(x, y), 2, Parts.LIT_FAINT, Z)
		Parts.text(kit, _readout, r["old"], Vector2(old_right - kit.measure(r["old"], 2), y),
				2, Parts.LIT_DIM, Z)
		Parts.text(kit, _readout, "→", Vector2(arrow_x, y), 2, Parts.LIT_FAINT, Z)
		Parts.text(kit, _readout, r["new"], Vector2(new_x, y), 2, Parts.LIT, Z)
		y += pitch
	return y


## How tall `_table` will set these lines, without setting them.
func _table_h(lines: Array, width: float, pitch: float) -> float:
	var h := 0.0
	for raw: Variant in lines:
		var r := _change(str(raw))
		if r.is_empty():
			h += pitch * kit.wrap(str(raw), 2, width).size()
		elif kit.measure(r["old"], 2) <= 96.0 and kit.measure(r["new"], 2) <= 96.0:
			h += pitch
		elif kit.measure(r["label"], 2) + 16.0 + kit.measure(r["old"], 2) <= width:
			h += pitch * 2.0 + 2.0
		else:
			h += pitch * 3.0 + 2.0
	return h


## "Label: a → b", or "Mk 2 → Mk 1" (the shared word is the label).
static func _change(line: String) -> Dictionary:
	var arrow := line.find(" → ")
	if arrow < 0:
		return {}
	var left := line.substr(0, arrow)
	var right := line.substr(arrow + 3)
	var colon := left.find(": ")
	if colon >= 0:
		return {"label": left.substr(0, colon), "old": left.substr(colon + 2),
			"new": right}
	var l := left.split(" ", false)
	var r := right.split(" ", false)
	if l.size() == 2 and r.size() == 2 and l[0] == r[0]:
		return {"label": l[0], "old": l[1], "new": r[1]}
	return {}


## The readout's own control, for the device in hand: ENTER, or the pad's
## south face button.
func _prompt_cap(at: Vector2, z: float) -> void:
	_info["cap"] = "pad_face_south" if kit.device == "pad" else "ENTER"
	if kit.device == "pad":
		Parts.sprite(kit, _readout, "pad_face_south", at + Vector2(20, 13), 2, Parts.INK,
				z + 0.002)
		return
	Parts.keycap(kit, _readout, "ENTER", at, z)


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


## The one action the readout offers, in words.
func _action(id: String) -> String:
	var slot := slot_of(key_index)
	if slot == "":
		return ""
	var row: Dictionary = items[id]
	if str(row.get("held_back", "")) != "":
		return str(row["held_back"])
	if seated(slot) == id:
		return ""
	if preview.has(slot) and saved(slot) == id:
		return "BACK TO THE SAVE: THIS ON %s" % _cap()
	var refusal := str((row["refusal"] as Dictionary).get(slot, ""))
	if refusal != "":
		return refusal
	return "PREVIEW ON %s" % _cap()


# ============================================================ actions

func nav(dir: Vector2i) -> void:
	note = ""
	if zone == "keys":
		if dir.y != 0:
			var to := clampi(key_index + dir.y, 0, key_count() - 1)
			if to == key_index:
				kit.cue("edge")
				return
			_focus_key(to)
		elif dir.x > 0:
			_enter_rack()
		return
	if dir.x < 0:
		zone = "keys"
		kit.cue("tick", 0.75)
		_mark_keys()
		_mark_rows()
		return
	if dir.y != 0 and not _order.is_empty():
		var at := _order.find(unfolded)
		var to := clampi(at + dir.y, 0, _order.size() - 1)
		if to == at:
			kit.cue("edge")
			return
		_select(_order[to])


func _enter_rack() -> void:
	if _order.is_empty():
		kit.cue("edge")
		return
	zone = "drawer"
	kit.cue("tick", 0.85)
	if unfolded == "":
		_select(_order[0])
	_mark_keys()
	_mark_rows()


## Look at another key: the pointer turns one detent (or several, at once
## when motion is reduced), and the rack swaps to that key's modules.
func _focus_key(i: int, pointer := false) -> void:
	if i == key_index:
		return
	sel[key_index] = unfolded
	scroll[key_index] = _first
	key_index = i
	zone = "keys" if not pointer else zone
	kit.cue("detent", 1.0 + 0.05 * float(i))
	_open_rack()
	_mark_keys()


## Select a module. Nothing in the rack moves but the module itself (and
## the rack scrolls a row only if the keyboard or pad asks for one out of
## view); the readout is rebuilt whole.
func _select(id: String, by_pointer := false) -> void:
	if id == unfolded:
		return
	unfolded = id
	sel[key_index] = id
	kit.cue("tick")
	var was := _first
	if not by_pointer:
		_keep_in_view()
	if _first != was:
		_build_rows()
	else:
		_mark_rows()
	_compose()


func accept() -> void:
	if zone == "keys":
		_enter_rack()
		return
	if unfolded == "":
		return
	if not _can_preview(unfolded):
		kit.cue("refuse")
		return
	var slot := slot_of(key_index)
	if preview.has(slot) and saved(slot) == unfolded:
		preview.erase(slot)
		note = "BACK TO THE SAVE."
		kit.cue("restore")
	else:
		preview[slot] = unfolded
		note = "PREVIEWED. NOT SENT."
		kit.cue("preview")
	# The windows change; the rack's order, its scroll and its selection do
	# not.
	_build_keys()
	_build_rows()
	_compose()


func back() -> bool:
	if zone == "drawer":
		zone = "keys"
		kit.cue("tick", 0.75)
		_mark_keys()
		_mark_rows()
		return true
	return false


## Hover lights, and never moves anything.
func hover_at(p: Vector2) -> void:
	var was := hover
	hover = _hit(p)
	if hover == "action":
		hover = ""
	if hover != was:
		_mark_keys()
		_mark_rows()


func click(p: Vector2) -> bool:
	var hit := _hit(p)
	if hit.begins_with("key:"):
		var i := int(hit.trim_prefix("key:"))
		zone = "keys"
		if i == key_index:
			_mark_keys()
			_mark_rows()
		_focus_key(i, true)
		return true
	if hit == "action":
		accept()
		return true
	if hit != "":
		zone = "drawer"
		_select(hit, true)
		_mark_keys()
		_mark_rows()
		return true
	return false


## The wheel: over the rack it scrolls a row a notch; over the selector it
## turns it a detent -- the ordinary selection, not a drag.
func wheel(p: Vector2, dir: int) -> bool:
	if p.x >= ROW_X - PULL - 20.0 and p.y >= BAY.position.y - 12.0:
		_hand_scroll(dir)
		return true
	if p.x < KEY_WIN_X + KEY_WIN_W + 10.0 and p.y >= BAY.position.y - 12.0:
		var to := clampi(key_index + dir, 0, key_count() - 1)
		if to == key_index:
			kit.cue("edge")
		else:
			_focus_key(to, true)
		return true
	return false


## The right stick: the same hand scroll as the wheel, a row at a time as
## the stick's travel adds up.
func scroll_by(px: float) -> void:
	if zone != "drawer":
		return
	_stick_px += px
	while absf(_stick_px) >= ROW_PITCH:
		var dir := signi(int(signf(_stick_px)))
		_stick_px -= ROW_PITCH * float(dir)
		if not _hand_scroll(dir):
			_stick_px = 0.0
			break


## Scrolling by hand moves the rack a whole row under its window; the
## selection stays selected, pulled, and read -- even out of view.
func _hand_scroll(dir: int) -> bool:
	var to := clampi(_first + dir, 0, _max_first())
	if to == _first:
		kit.cue("edge")
		return false
	_first = to
	scroll[key_index] = _first
	kit.cue("scroll")
	_build_rows(false)
	return true


func _hit(p: Vector2) -> String:
	for i in _keys.size():
		if (_keys[i]["hit"] as Rect2).has_point(p):
			return "key:%d" % i
	if _info.has("action") and (_info["action"] as Rect2).has_point(p):
		return "action"
	for id: String in _rows:
		if (_rows[id]["hit"] as Rect2).has_point(p):
			return id
	return ""


## Where a named thing is on this wall now, page px (for a tape): "key:<i>"
## (its window), "row:<id>" (if shown), "action", "rack", "dial",
## "readout". INF when it is not on the wall.
func target_of(name: String) -> Vector2:
	var p := name.split(":", true, 1)
	match p[0]:
		"key":
			var i := int(p[1])
			if i >= 0 and i < _keys.size():
				return Vector2(KEY_WIN_X + KEY_WIN_W * 0.5, float(_keys[i]["y"]))
		"keycap":
			var i := int(p[1])
			if i >= 0 and i < _keys.size():
				return (_keys[i]["anchor"] as Vector2) + Vector2(40, 0)
		"row":
			if _rows.has(p[1]):
				var h: Rect2 = _rows[p[1]]["hit"]
				return Vector2(h.position.x + 200.0, h.get_center().y)
		"action":
			if _info.has("action"):
				return (_info["action"] as Rect2).get_center()
		"rack":
			return Vector2(900, ROW_Y0 + ROW_PITCH * 4.5)
		"dial":
			return KNOB
		"readout":
			return Vector2(COL_L + 200, TOP + 60)
	return Vector2.INF


func prompts() -> Array:
	if zone == "keys":
		return [["move", "keys"], ["into", "the rack"], ["click", "pick"],
			["turn_left", "turn left"], ["turn_right", "turn right"],
			["close", "close"]]
	var out := [["move", "items"]]
	if unfolded != "" and _can_preview(unfolded):
		out.append(["accept", _action(unfolded).to_lower()])
	out += [["out", "keys"], ["wheel", "scroll"], ["turn_left", "turn left"],
		["turn_right", "turn right"], ["close", "close"]]
	return out


# ============================================================ state

func state() -> Dictionary:
	var rects := {}
	for i in _order.size():
		rects[_order[i]] = [_row_y(i), ROW_H]
	var at := _order.find(unfolded)
	var inside := at >= _first and at < _first + SHOWN
	var shown_ids := []
	var hits := {}
	var words := {}
	for id: String in _rows:
		shown_ids.append(id)
		words[id] = _rows[id]["words"]
		var h: Rect2 = _rows[id]["hit"]
		hits[id] = [h.position.x, h.position.y, h.size.x, h.size.y]
	var windows := []
	var key_hits := []
	for e: Dictionary in _keys:
		windows.append(str(e["words"]))
		var h: Rect2 = e["hit"]
		key_hits.append([h.position.x, h.position.y, h.size.x, h.size.y])
	# the module drawn out: the selected one, when its row is shown
	var pulled := unfolded if _rows.has(unfolded) else ""
	var out := []
	for id: String in _rows:
		if (_rows[id]["node"] as Node3D).position.length() > 0.0001:
			out.append(id)
	var seated_rows := {}
	if slot_of(key_index) != "":
		for id: String in _order:
			if _stands(id) != "":
				seated_rows[id] = _stands(id)
	var act: Rect2 = _info.get("action", Rect2())
	return {"key": key_index, "slot": slot_of(key_index), "zone": zone,
		"unfolded": unfolded, "order": _order, "count": _order.size(),
		"first": _first, "scroll": _first * ROW_PITCH, "shown": shown_ids,
		"preview": preview.duplicate(), "hover": hover, "note": note,
		"rects": rects, "row_hits": hits, "key_hits": key_hits,
		"windows": windows, "stands": seated_rows, "pulled": pulled, "out": out,
		"row_words": words,
		"pointer_to": snappedf(-_angle(key_index), 0.0001),
		"pointer_at": snappedf(_pivot.rotation.z, 0.0001),
		"pointer_moving": kit.moving(_pivot, "rotation:z"),
		"rack_moving": _rack_moving(),
		# the selected module's row is inside the rack's window
		"card_inside": inside,
		# the selected item's readout is on the wall
		"card_shown": _readout != null and str(_info.get("id", "")) == unfolded
			and unfolded != "",
		"holes": _holes(),
		"focus": _info.duplicate(),
		"action": [act.position.x, act.position.y, act.size.x, act.size.y]
			if act.size.x > 0.0 else [],
		"text_scale_min": _text_scale_min(),
		"compositions": _live_compositions(),
		"more": ["%d MORE ABOVE" % int(_info_more[0]) if int(_info_more[0]) > 0 else "",
			"%d MORE BELOW" % int(_info_more[1]) if int(_info_more[1]) > 0 else ""],
		"knob": snappedf(_knob.position.y, 0.0001)}


func _rack_moving() -> bool:
	for id: String in _rows:
		if kit.moving(_rows[id]["node"], "position"):
			return true
	return kit.moving(_knob, "position")


## The smallest vertical scale any word on this wall is drawn at, relative to
## its own: 1.0 means no text anywhere is squashed.
func _text_scale_min() -> float:
	var least := 1.0
	var stack: Array = [face]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label3D and (n as Label3D).is_visible_in_tree():
			var s := (n as Node3D).global_transform.basis.get_scale().y
			least = minf(least, s / maxf(0.0001, _own_scale(n as Node3D)))
		stack.append_array(n.get_children())
	return snappedf(least, 0.001)


## A word placed to be SEEN at its page size is scaled ON PURPOSE (Parts
## .text); that is its own scale, not a squash.
static func _own_scale(n: Node3D) -> float:
	var s := 1.0
	var at: Node = n
	while at != null:
		if at is Node3D:
			s *= float(at.get_meta("own_scale", 1.0))
		at = at.get_parent()
	return s


## How many readouts are on the wall right now: one, or the old and the new
## are overlapping.
func _live_compositions() -> int:
	var n := 0
	for c: Node in face.get_children():
		if c is Node3D and c.get_meta("composition", false) \
				and not c.is_queued_for_deletion():
			n += 1
	return n


## Rows the rack shows that leave a gap: the rack is always filled from its
## top, a row to every place, as far as its items go.
func _holes() -> float:
	var want := mini(SHOWN, _order.size() - _first)
	var worst := 0.0
	var seen := {}
	for id: String in _rows:
		seen[int(_rows[id]["index"]) - _first] = true
	for j in want:
		if not seen.has(j):
			worst += ROW_PITCH
	return worst


## The device changed: the readout's control is redrawn for it.
func on_device() -> void:
	_compose()


func tick(_delta: float) -> void:
	pass
