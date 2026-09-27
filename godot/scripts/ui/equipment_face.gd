class_name EquipmentFace
extends Node
## H-INVENTORY, AS THE APPROVED HYBRID (MENU-INT): THE EQUIPMENT WALL IS
## THE STATION'S CABINET -- the owner's rulings of 2026-09-27: C's cabinet
## arrangement with D's grafted rack (`tools/menu_proto/face_equipment.gd`,
## `5b03f6d`, the reference) -- on the campaign's real items and real
## equip requests (`04_3D_MENU_MAP_AND_GLYPH.md` §5).
##
## * THE INSPECTION WINDOW (original station hardware): what the item being
##   read IS, and what changes if it goes on the key. It swaps whole, in the
##   frame the input arrives -- no shutter, nothing to wait for.
## * THE KEY SELECTOR (original): the game's five keys
##   (`Constants.SLOT_NAMES`, named by the real bindings, `SlotKeycaps`)
##   and ALWAYS ON round one knob. ALWAYS ON is the sixth position to
##   BROWSE only: it is not a key, not a binding, not a slot and not Gear.
##   Each key's backlit window says what the bridge last CONFIRMED is on
##   it, with the state of any request for it.
## * THE RACK (salvaged, grafted into the cabinet's cut-down old bay): the
##   focused key's items as one list of modules. The one ON the key is
##   SEATED and its window says so; the one being READ is PULLED toward
##   you. It keeps its order while you browse -- the key's occupant first
##   -- and scrolls a whole row at a time.
## * THE TOOL STRIP under the bus: FIND (a label-maker tape that searches
##   names, games, items and what Epsilon read) and SORT (as found, newest,
##   name, game). A new item carries a NEW sticker until it is read; a key
##   with one has its name in the same yellow.
## * THE NOTICE on the harness above the cabinet: offline, and a refusal
##   the bridge did not attribute to any request.
##
## **Everything is read from the bridge's own projection** through
## `EquipmentQuery` -- which items there are, which fit a key, what a
## search finds, what a comparison says, why an equip would be refused,
## what state a consumable is in. This file only sets those answers on the
## hardware.
##
## **An equip is a request, not a result** (`EquipRequests`). Reading an
## item does not equip it. Sending one does not change the key: its window
## keeps what the bridge last confirmed, beside the request's state (SENT,
## ✓, ✗, ?), until a snapshot says otherwise. A comparison is always
## against the CONFIRMED occupant. Undo is another request: the item a key
## held before an accepted change reads PUT BACK. One request per key;
## the newest wins; an answer for one key never touches another's.

# ---- the cabinet
const WIN := Rect2(40, 108, 1200, 280)     # the inspection window
const MID_X := 640.0                       # its divider
const BUS_Y := 414.0
const BUS_END := 540.0
const TERM := Rect2(536, 400, 44, 28)      # the bus's terminal block
const ADAPTER := Rect2(542, 440, 38, 36)   # the adapter board under it
# ---- the tool strip, under the bus
const STRIP_Y := 422.0
const FIND_CAP := Vector2(120, STRIP_Y)
const FIND := Rect2(164, STRIP_Y + 1, 192, 24)
const SORT_CAP := Vector2(366, STRIP_Y)
const SORT := Rect2(410, STRIP_Y, 110, 26)
const SORT_WORDS := ["AS FOUND", "NEWEST", "NAME A-Z", "BY GAME"]
const FIND_MAX := 24                       # characters a search holds
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
const TOGGLES_H := 30.0                    # the left column's foot: HISTORY, WHEEL
const Z := 0.0022                          # the readout's words, in the window
# ---- the notice on the harness
const NOTICE_X := 420.0
const NOTICE_W := 760.0
# ---- what the words say, by colour. Never green: that is Epsilon's.
const SENT_C := Color("#f0c060")           # a request on its way
const WARN_C := Color("#ff9e59")           # refused, not sent, lost, empty, offline
const NEW_C := Color("#e6c84a")            # a new item's sticker
const NEW_INK := Color("#1b1c1e")

## What each request state shows at a key's window.
const MARKS := {EquipRequests.PENDING: "→", EquipRequests.ACCEPTED: "✓",
	EquipRequests.REFUSED: "✗", EquipRequests.NOT_SENT: "✗",
	EquipRequests.LOST: "?"}

var requests := EquipRequests.new()
var kit: MenuKit
var shell: MenuShell
var face: Node3D
var key_index := 0            # 0..4 the keys, 5 ALWAYS ON
var zone := "keys"            # keys | drawer (the rack)
var sel := {}                 # key -> selected id (each key remembers)
var anchor := {}              # key -> the id of its first row shown
var hovered := ""             # the pick target under the pointer
var unfolded := ""            # the item being read
var note := ""                # a transient line (what just changed)
var search := ""
var sort_mode := 0            # SORT_WORDS
var history_open := false
var typing := false

var _open := false
var _front := false
var _rows: Array = []         # EquipmentQuery.items, the snapshot on the wall
var _by_id := {}
var _campaign := ""
## The last refusal that named nothing this face asked for, shown as the
## bridge's and not attributed to any key.
var _unattributed := ""
## slot -> what it held before a change the bridge accepted (this visit):
## the undo, which is another request.
var _was := {}
var _order: Array = []        # the rack's ids, in order
var _total := 0               # how many the key takes before a search
var _first := 0               # the first row shown
var _more_first := 0          # the history view's first line
var _stick_px := 0.0          # the right stick's scroll, not yet a row
var _keys: Array = []         # per key: {anchor, y, ...materials}
var _keys_node: Node3D
var _tools: Node3D
var _notice: Node3D
var _pivot: Node3D            # the knob's pointer turns in this
var _rows_drawn := {}         # id -> {node, face, tab, name, tags, ...}
var _rack: Node3D
var _knob: Node3D             # the scroll pot's knob
var _knob_h := 0.0
var _readout: Node3D          # the composition for the selected item
var _info := {}               # what the readout drew (for state())
var _info_more := [0, 0]


func _ready() -> void:
	name = "EquipmentFace"
	BridgeClient.snapshot_received.connect(_on_snapshot)
	BridgeClient.error_received.connect(_on_bridge_error)
	BridgeClient.bridge_state_changed.connect(_on_link)


## The shell hands its kit over when the wall is mounted: the fixed
## hardware is built once.
func setup(k: MenuKit, s: MenuShell) -> void:
	kit = k
	shell = s
	face = shell.face_node("equipment")
	_build_cabinet()
	_build_dial()
	_tools = Node3D.new()
	_tools.name = "Tools"
	face.add_child(_tools)
	_notice = Node3D.new()
	_notice.name = "Notice"
	face.add_child(_notice)
	rebuild()


# ============================================================ the API

func open() -> void:
	requests.forget_answers()
	_unattributed = ""
	_was.clear()
	note = ""
	_open = true
	rebuild()


func close() -> void:
	_open = false
	typing = false


func is_open() -> bool:
	return _open


## Read the snapshot again and rebuild the hardware that shows it, keeping
## what the player was doing BY IDENTITY: the key, the item being read,
## the first row shown, the search and the sort all survive.
func rebuild() -> void:
	var snapshot: Dictionary = BridgeClient.snapshot
	_campaign = EquipmentSeen.campaign_key(snapshot)
	_rows = EquipmentQuery.items(snapshot, BridgeClient.interpretations())
	_by_id.clear()
	var ids: Array = []
	for row: Dictionary in _rows:
		var cid := str(row.get("component_id", ""))
		_by_id[cid] = row
		ids.append(cid)
	EquipmentSeen.baseline(_campaign, ids)
	if kit == null:
		return
	var reading := unfolded
	_build_keys()
	_open_rack(true)
	if reading != "" and not _by_id.has(reading):
		note = "WHAT YOU WERE READING IS NO LONGER OWNED."
		_compose()
	_build_tools()
	_build_notice()


## Read an item: the selector turns to the key it goes on (ALWAYS ON for
## one that takes none), and its module is pulled.
func select(component_id: String) -> void:
	var row: Dictionary = _by_id.get(component_id, {})
	if row.is_empty():
		return
	var home := EquipmentQuery.home_slot(row)
	var index := Constants.SLOT_NAMES.find(home) if home != "" \
			else Constants.SLOT_NAMES.size()
	if index < 0:
		return
	if search != "" and not EquipmentQuery.matches(row, search):
		set_search("")
	if index != key_index:
		_focus_key(index, true)
	zone = "drawer"
	_select(component_id)
	_mark_keys()
	_mark_rows()


func selected() -> String:
	return unfolded


## The key being looked at ("" for ALWAYS ON).
func focused_slot() -> String:
	return slot_of(key_index)


## THE EQUIP: put the item being read on the focused key. Returns the
## request's state, or "" when nothing was sent (and why is on the wall).
func equip_selected() -> String:
	if unfolded == "" or not _can_act(unfolded):
		return ""
	return _act(unfolded)


## Take the item being read off its key.
func unequip_selected() -> String:
	var row: Dictionary = _by_id.get(unfolded, {})
	var slot := EquipmentQuery.equipped_in(row)
	if slot == "" or requests.is_pending(slot) or not BridgeClient.can_send():
		return ""
	return _send(slot, null, "restore")


func clear_slot(slot: String) -> String:
	if slot == "" or confirmed(slot) == "" or requests.is_pending(slot) \
			or not BridgeClient.can_send():
		return ""
	return _send(slot, null, "restore")


func set_search(text: String) -> void:
	search = text.substr(0, FIND_MAX)
	if kit == null:
		return
	_open_rack(true)
	_build_tools()


func set_sort(mode: int) -> void:
	sort_mode = posmod(mode, SORT_WORDS.size())
	if kit == null:
		return
	_open_rack(true)
	_build_tools()


func sort_label() -> String:
	return str(SORT_WORDS[sort_mode])


# ============================================================ the data

func key_count() -> int:
	return Constants.SLOT_NAMES.size() + 1       # + ALWAYS ON


func slot_of(index: int) -> String:
	return "" if index >= Constants.SLOT_NAMES.size() \
			else str(Constants.SLOT_NAMES[index])


## What the bridge last confirmed is on a key: the authority, not a wish.
func confirmed(slot: String) -> String:
	var holds: Variant = BridgeClient.slots().get(slot)
	return "" if holds == null else str(holds)


## The rack's items for a key, after the search: the key's confirmed
## occupant first, then the rest in the chosen order (AS FOUND is the
## fold's own). ALWAYS ON: every item that takes no key.
func candidates(index: int) -> Array:
	var slot := slot_of(index)
	var pool: Array = []
	for row: Dictionary in _rows:
		if slot == "":
			if not EquipmentQuery.is_slotted(row):
				pool.append(row)
		elif (row.get("compatible_slots", []) as Array).has(slot):
			pool.append(row)
	_total = pool.size()
	var found: Array = []
	for row: Dictionary in pool:
		if EquipmentQuery.matches(row, search):
			found.append(row)
	if sort_mode > 0:
		found = EquipmentQuery.sorted_items(found, sort_mode - 1)
	var out: Array = []
	var on := confirmed(slot) if slot != "" else ""
	for row: Dictionary in found:
		if str(row.get("component_id", "")) == on:
			out.append(on)
	for row: Dictionary in found:
		var cid := str(row.get("component_id", ""))
		if cid != on:
			out.append(cid)
	return out


## How many of each key's items a search finds, for the rack's word when
## the focused key has none: [[key words, count]].
func _matches_elsewhere() -> Array:
	var out: Array = []
	for i in key_count():
		if i == key_index:
			continue
		var slot := slot_of(i)
		var n := 0
		for row: Dictionary in _rows:
			var fits := not EquipmentQuery.is_slotted(row) if slot == "" \
					else (row.get("compatible_slots", []) as Array).has(slot)
			if fits and EquipmentQuery.matches(row, search):
				n += 1
		if n > 0:
			out.append("%s (%d)" % [_cap_of(i) if slot != "" else "ALWAYS ON", n])
	return out


func _name(id: String) -> String:
	return EquipmentQuery.name_of(_by_id.get(id, {"component_id": id}))


func _mk(id: String) -> String:
	return "MK " + EquipmentQuery.mk_roman(int((_by_id.get(id, {}) as Dictionary)
			.get("mk", 1)))


func _cap_of(index: int) -> String:
	var slot := slot_of(index)
	return "" if slot == "" else SlotKeycaps.of(slot).to_upper()


func _cap() -> String:
	return _cap_of(key_index)


func _charges(id: String) -> String:
	var row: Dictionary = _by_id.get(id, {})
	if not EquipmentQuery.is_consumable(row):
		return ""
	var left := BridgeClient.charges_left(id) if confirmed("consumable") == id \
			else int(row.get("charges_left", 0))
	return "%d/%d" % [left, int(row.get("charges_max", 0))]


func _is_new(id: String) -> bool:
	return EquipmentSeen.is_new(_campaign, id)


func _key_has_new(index: int) -> bool:
	var slot := slot_of(index)
	for row: Dictionary in _rows:
		var fits := not EquipmentQuery.is_slotted(row) if slot == "" \
				else (row.get("compatible_slots", []) as Array).has(slot)
		if fits and _is_new(str(row.get("component_id", ""))):
			return true
	return false


## Where an item stands with the focused key, in words: the same words on
## its module's window, in the readout's kicker, and in state().
func _stands(id: String) -> String:
	var slot := slot_of(key_index)
	if slot == "":
		return ""
	var pending := requests.pending(slot)
	if not pending.is_empty() and _same(pending.get("component_id"), id):
		return "SENT · WAITING"
	if confirmed(slot) == id:
		return "ON " + _cap()
	var answer := requests.answer(slot)
	if not answer.is_empty() and _same(answer.get("component_id"), id):
		match str(answer["state"]):
			EquipRequests.REFUSED:
				return "REFUSED"
			EquipRequests.NOT_SENT:
				return "NOT SENT"
			EquipRequests.LOST:
				return "LOST"
	if str(_was.get(slot, "")) == id:
		return "WAS ON " + _cap()
	return ""


static func _same(a: Variant, id: String) -> bool:
	return a != null and str(a) == id


func _stands_colour(words: String) -> Color:
	if words.begins_with("SENT"):
		return SENT_C
	if words in ["REFUSED", "NOT SENT", "LOST"]:
		return WARN_C
	if words.begins_with("ON "):
		return MenuParts.LIT
	return MenuParts.LIT_DIM


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
	MenuParts.wire(f, [Vector2(gx, MenuParts.TRUNK_Y), Vector2(gx, WIN.position.y - 18)],
			MenuParts.WIRE, 3.5)
	MenuParts.sleeve(f, Vector2(gx, WIN.position.y - 30), true, 6.0, 14,
			MenuParts.WIRE_Z, MenuParts.mat(Color("#202225"), 0.05, 0.7))
	MenuParts.disc(f, Vector2(gx, WIN.position.y - 14), 11.0, 0.0, 0.016,
			MenuParts.mat(MenuParts.RIVET, 0.6, 0.4), 6)
	MenuParts.disc(f, Vector2(gx, WIN.position.y - 14), 6.5, 0.016, 0.022,
			MenuParts.mat(MenuParts.CAB_HI, 0.4, 0.5), 16)
	# ---- the inspection window and its divider
	MenuParts.window(f, WIN)
	MenuParts.block(f, Rect2(MID_X - 4, WIN.position.y, 8, WIN.size.y), 0.0, 0.012,
			MenuParts.mat(MenuParts.CAB_HI, 0.35, 0.5))
	# the whole window answers to the wheel (the history view scrolls)
	kit.pick_rect("equipment", f, WIN, 0.0, 0.0008, "readout")
	# ---- the original bus, to its terminal block
	var brass := MenuParts.mat(MenuParts.BRASS, 0.7, 0.35)
	MenuParts.block(f, Rect2(40, BUS_Y - 5, BUS_END - 40, 10), 0.014, 0.022, brass)
	for x: float in [62.0, 300.0]:
		MenuParts.disc(f, Vector2(x, BUS_Y), 6.0, 0.0, 0.014,
				MenuParts.mat(Color("#1b1d1f"), 0.2, 0.6), 14)
	MenuParts.slab(f, MenuParts.rrect(TERM, 3), 0.0, 0.02,
			MenuParts.mat(MenuParts.BAKELITE.lightened(0.05), 0.1, 0.45))
	for i in 2:
		MenuParts.disc(f, Vector2(TERM.position.x + 12 + 20 * i, BUS_Y), 5.0, 0.02,
				0.026, brass, 12)
	# the selector's strap up to the bus
	MenuParts.block(f, Rect2(KNOB.x - 5, BUS_Y, 10, KNOB.y - BEZEL - BUS_Y + 4), 0.006,
			0.012, brass)
	_build_bay(f)


## The rack's fixed parts: the old bay, the adapter plate, the backplane and
## its connector, the scroll pot, and both joins.
func _build_bay(f: Node3D) -> void:
	# the cabinet's own bay: a recess only as wide as its old card cage was,
	# its riveted frame kept on the top and the left -- and the top bar cut
	# off where the rebuilt rack outgrew it: a bright cut face, and past it
	# the empty holes of the rivets that went with the rest of the bar
	var m := MenuParts.mat(MenuParts.CAB_HI, 0.35, 0.5)
	var old := Rect2(BAY.position.x, BAY.position.y, OLD_BAY_END - BAY.position.x,
			BAY.size.y)
	MenuParts.block(f, old, 0.0, 0.0008, MenuParts.mat(MenuParts.RECESS, 0.0, 0.95),
			false)
	MenuParts.block(f, Rect2(old.position.x - 12, old.position.y - 12, old.size.x + 12,
			12), 0.0, 0.014, m)
	MenuParts.block(f, Rect2(old.end.x, old.position.y - 12, 3, 12), 0.0, 0.014,
			MenuParts.mat(Color("#c7cbce"), 0.7, 0.3))
	MenuParts.block(f, Rect2(old.position.x - 12, old.position.y, 12, old.size.y), 0.0,
			0.014, m)
	for p: Vector2 in [Vector2(old.position.x - 6, old.position.y - 6),
			Vector2(old.position.x + 200, old.position.y - 6),
			Vector2(old.position.x - 6, old.end.y - 10)]:
		MenuParts.rivet(f, p, 0.014)
	for x: float in [old.end.x + 60.0, old.end.x + 164.0]:
		MenuParts.disc(f, Vector2(x, old.position.y - 6), 3.0, 0.0, 0.0006,
				MenuParts.unlit(Color("#08090a")), 10, false)
	# the adapter plate: bare aluminium, bolted into the old bay
	var plate := Rect2(old.position.x + 4, old.position.y + 2, old.size.x - 2,
			old.size.y - 4)
	MenuParts.block(f, plate, 0.0008, 0.003, MenuParts.mat(MenuParts.PLATE, 0.55, 0.45))
	# the backplane: salvaged paper phenolic, past the bay to the wall's edge
	var bp := PackedVector2Array([Vector2(BAY.position.x + 16, BAY.position.y + 2),
		Vector2(1216, BAY.position.y + 2), Vector2(1216, 692), Vector2(1194, 714),
		Vector2(BAY.position.x + 40, 714), Vector2(BAY.position.x + 16, 690)])
	MenuParts.board(f, bp, MenuParts.PHENOLIC, BZ, [Vector2(BAY.position.x + 28,
			BAY.position.y + 14), Vector2(1204, BAY.position.y + 14),
			Vector2(BAY.position.x + 28, 700), Vector2(1182, 702)])
	# the rack as a whole answers to the wheel
	kit.pick_rect("equipment", f, Rect2(BAY.position.x + 16, BAY.position.y + 2,
			1200 - BAY.position.x, 288), BZ - 0.004, BZ, "rack")
	# the edge connector every module plugs into
	MenuParts.header(f, Rect2(ROW_X - 14, ROW_Y0 - 2, 12, ROW_PITCH * SHOWN - 1), BZ)
	# the scroll: a repurposed slide pot; its knob is placed by _place_knob
	var track := MenuParts.block(f, TRACK, BZ, BZ + 0.004,
			MenuParts.mat(Color("#0b0b0b"), 0.1, 0.8))
	kit.pickable("equipment", track, "track")
	_knob = Node3D.new()
	f.add_child(_knob)
	# ---- the join back into the cabinet: the bus's terminal, a short lead,
	# an adapter board, and a ribbon into the backplane's own connector
	MenuParts.board(f, MenuParts.rrect(ADAPTER, 3), MenuParts.BLACK_MASK, 0.018,
			[ADAPTER.position + Vector2(9, 9)])
	MenuParts.block(f, Rect2(ADAPTER.position.x + 20, ADAPTER.position.y + 5, 20, 10),
			0.018, 0.028, MenuParts.mat(MenuParts.TERMINAL, 0.1, 0.5))
	MenuParts.wire(f, [Vector2(TERM.position.x + 32, BUS_Y + 4),
			Vector2(TERM.position.x + 32, ADAPTER.position.y + 10)],
			MenuParts.IVORY.darkened(0.25), 1.8, 0.024, 4.0)
	MenuParts.header(f, Rect2(ADAPTER.end.x - 12, ADAPTER.position.y + 14, 8, 22), 0.018)
	MenuParts.ribbon(f, [Vector2(ADAPTER.end.x - 8, ADAPTER.position.y + 25),
			Vector2(ROW_X - 8, ADAPTER.position.y + 25)], 0.034)
	# ---- and on round the corner into Settings: the backplane's ribbon
	MenuParts.header(f, Rect2(1203, MenuParts.RIBBON_Y - 12, 10, 24), BZ)
	MenuParts.ribbon(f, [Vector2(1208, MenuParts.RIBBON_Y), Vector2(MenuParts.RUN_END,
			MenuParts.RIBBON_Y)], MenuParts.RIBBON_Z)
	var grey := MenuParts.mat(MenuParts.RIBBON, 0.1, 0.6)
	for kk in 6:
		var run := MenuParts.corner(shell.box(), face, shell.face_node("settings"),
				MenuParts.RIBBON_Y + (float(kk) - 2.5) * 3.4, 1.7, grey,
				MenuParts.RIBBON_Z)
		run.name = "Ribbon_equipment_settings_%d" % kk


## THE TOOL STRIP: FIND and SORT, each with its own key on it. Rebuilt when
## either changes, or the device does.
func _build_tools() -> void:
	if _tools == null:
		return
	for n: Node in _tools.get_children():
		n.queue_free()
	var holder := Node3D.new()
	_tools.add_child(holder)
	# FIND: the key that starts a search, then the tape it is typed on
	_tool_cap(holder, FIND_CAP, "/", "")
	var tape := MenuParts.block(holder, FIND, 0.004, 0.0052,
			MenuParts.mat(MenuParts.TAPE if typing or search != ""
				else MenuParts.TAPE.darkened(0.25), 0.1, 0.45))
	kit.pickable("equipment", tape, "find")
	var room := FIND.size.x - 16.0 - (22.0 if search != "" else 0.0)
	var words := search.to_upper() + ("_" if typing else "")
	if words == "":
		words = "FIND"
	var shown := words
	while shown.length() > 1 and kit.measure(shown, 2) > room:
		shown = shown.substr(1)         # the end being typed stays in view
	MenuParts.text(kit, holder, shown, FIND.position + Vector2(8, 4), 2,
			MenuParts.TAPE_INK if (typing or search != "") else MenuParts.TAG_DIM,
			0.0064)
	if search != "":
		var x := Rect2(FIND.end.x - 22, FIND.position.y + 3, 18, 18)
		var clear := MenuParts.block(holder, x, 0.0052, 0.0072,
				MenuParts.mat(MenuParts.TAPE.darkened(0.35), 0.1, 0.5))
		MenuParts.text(kit, holder, "✕", x.position + Vector2(3, 1), 2,
				MenuParts.TAPE_INK, 0.0084)
		kit.pickable("equipment", clear, "find_clear")
	# SORT: its key, and a backlit window with the order in force
	_tool_cap(holder, SORT_CAP, "S", "pad_face_west")
	var sw := MenuParts.flag_window(kit, holder, SORT, str(SORT_WORDS[sort_mode]),
			MenuParts.LIT, 0.004)
	sw.set_meta("sort", sort_mode)
	kit.pick_rect("equipment", holder, SORT.grow(3.0), 0.0, 0.0046, "sort")


## A keycap on the strip; on the pad, the button that does the same, or
## nothing where the pad has none (a search is typed).
func _tool_cap(holder: Node3D, at: Vector2, key: String, pad_icon: String) -> void:
	if kit.device == "pad":
		if pad_icon != "":
			MenuParts.sprite(kit, holder, pad_icon, at + Vector2(20, 13), 2,
					MenuParts.INK, 0.004)
		return
	MenuParts.keycap(kit, holder, key, at, 0.002)


## THE NOTICE: a warm tag hung from the harness above the cabinet, only
## while there is something to say -- that the link is down, and a
## refusal the bridge attributed to no request of this wall's.
func _build_notice() -> void:
	if _notice == null:
		return
	for n: Node in _notice.get_children():
		n.queue_free()
	var lines: Array = []
	if not BridgeClient.can_send():
		lines.append("OFFLINE — THE KEYS SHOW WHAT THE BRIDGE LAST CONFIRMED.")
	if _unattributed != "":
		for line in kit.wrap("THE BRIDGE REFUSED A REQUEST: %s" % _unattributed, 2,
				NOTICE_W - 40.0):
			lines.append(line)
	if lines.is_empty():
		return
	lines = lines.slice(0, 3)
	var w := 0.0
	for line: String in lines:
		w = maxf(w, kit.measure(line, 2))
	var r := Rect2(NOTICE_X, 56, minf(w + 40.0, NOTICE_W), 26.0 + LINE * lines.size())
	var holder := Node3D.new()
	_notice.add_child(holder)
	MenuParts.tag(holder, r, 0.034, true, float(shell.shade.get("equipment", 1.0)))
	var y := r.position.y + 14.0
	for line: String in lines:
		MenuParts.text(kit, holder, kit.fit(line, 2, r.size.x - 40.0),
				Vector2(r.position.x + 20, y), 2, MenuParts.FLAG_INK, 0.0352)
		y += LINE


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
	MenuParts.disc(f, KNOB, BEZEL, 0.0, 0.005, MenuParts.mat(MenuParts.CAB_HI, 0.3, 0.55),
			40)
	MenuParts.ring(f, KNOB, BEZEL - 4, BEZEL + 1, 0.005,
			MenuParts.mat(MenuParts.BRASS, 0.7, 0.35))
	MenuParts.disc(f, KNOB, 40, 0.005, 0.02, MenuParts.mat(
			MenuParts.BAKELITE.lightened(0.08), 0.1, 0.45), 36)
	var cap := MenuParts.disc(f, KNOB, 30, 0.02, 0.05, MenuParts.mat(MenuParts.BAKELITE,
			0.1, 0.4), 32)
	kit.pickable("equipment", cap, "dial")
	var z1 := 0.056
	_pivot = Node3D.new()
	_pivot.name = "Pointer"
	f.add_child(_pivot)
	var centre := MenuKit.at(MenuKit.lifted(KNOB, z1), 0.0)
	_pivot.position = centre
	var arm := Node3D.new()
	_pivot.add_child(arm)
	arm.position = -centre
	MenuParts.pointer(arm, KNOB, 0.0, 6, 42, 5.0, 0.05, z1,
			MenuParts.mat(Color("#e9e4d6"), 0.1, 0.5))


## Each key round the knob: its detent mark, its keycap and name, and its
## backlit window -- what the bridge last confirmed is on it, its charges,
## and the state of a request for it.
func _build_keys(at_once := true) -> void:
	if _keys_node != null:
		_keys_node.queue_free()
	_keys_node = Node3D.new()
	_keys_node.name = "Keys"
	face.add_child(_keys_node)
	_keys.clear()
	for i in key_count():
		var a := _anchor(i)
		var y := a.y
		var entry := {"anchor": a, "y": y, "new": _key_has_new(i)}
		var tick_mat := MenuParts.own(MenuParts.FAINT)
		MenuParts.pointer(_keys_node, KNOB, _angle(i), 48, 58, 1.8, 0.005, 0.007, tick_mat)
		entry["tick"] = tick_mat
		var hit := Rect2(a.x - 4, y - 16, KEY_WIN_X + KEY_WIN_W - a.x + 8, 32)
		entry["hit"] = hit
		# the hover ground: light only, never movement
		var ground := MenuParts.own(MenuParts.CAB_HI.lightened(0.12))
		ground.albedo_color.a = 0.0
		var ground_node := MenuParts.block(_keys_node, hit, 0.0, 0.0012, ground, false)
		kit.pickable("equipment", ground_node, "key:%d" % i)
		entry["ground"] = ground
		# the keys' focus: a SIGNAL bar at the key, while the keys have it
		var bar := MenuParts.own(MenuKit.SIGNAL)
		MenuParts.block(_keys_node, Rect2(a.x, y - 11, 4, 22), 0.0012, 0.004, bar, false)
		entry["bar"] = bar
		var x := a.x + 10.0
		var slot := slot_of(i)
		if slot != "":
			var cap_w := MenuParts.keycap(kit, _keys_node, _cap_of(i), Vector2(x, y - 13),
					0.002)
			kit.pick_rect("equipment", _keys_node, Rect2(x, y - 13, cap_w, 26), 0.0,
					0.006, "key:%d" % i)
			x += cap_w + 10.0
			entry["title"] = MenuParts.text(kit, _keys_node,
					EquipmentQuery.slot_title(slot), Vector2(x, y - 8), 2, MenuParts.DIM,
					0.003)
		else:
			entry["title"] = MenuParts.text(kit, _keys_node, "ALWAYS ON", Vector2(x, y - 8),
					2, MenuParts.DIM, 0.003)
		var words := _key_words(i)
		var fw := Rect2(KEY_WIN_X, y - 11, KEY_WIN_W, 22)
		var tail := str(words[2])
		var mark := str(words[3])
		var tail_w := kit.measure(tail, 2) + 8.0 if tail != "" else 0.0
		var mark_w := 20.0 if mark != "" else 0.0
		var clear := i == key_index and _can_clear(slot)
		var clear_w := 22.0 if clear else 0.0
		var l := MenuParts.flag_window(kit, _keys_node, fw.grow_individual(0, 0,
				-(tail_w + mark_w + clear_w), 0), words[0], words[1], 0.004)
		kit.pick_rect("equipment", _keys_node, fw.grow(3.0), 0.0, 0.0046, "key:%d" % i)
		var tx := fw.end.x - tail_w - mark_w - clear_w
		if tail_w + mark_w + clear_w > 0.0:
			MenuParts.block(_keys_node, Rect2(tx - 3, fw.position.y, fw.end.x - tx + 3,
					fw.size.y), 0.004, 0.0046, MenuParts.mat(MenuParts.RECESS, 0.0, 0.95),
					false)
		if tail != "":
			# a consumable's charges: always shown, never cut
			MenuParts.text(kit, _keys_node, tail, Vector2(tx, fw.position.y + 3), 2,
					words[4], 0.0058)
			tx += tail_w
		if mark != "":
			MenuParts.text(kit, _keys_node, mark, Vector2(tx + 2, fw.position.y + 3), 2,
					words[5], 0.0058)
			tx += mark_w
		if clear:
			var b := Rect2(fw.end.x - 20, fw.position.y + 2, 18, 18)
			var btn := MenuParts.block(_keys_node, b, 0.0046, 0.0076,
					MenuParts.mat(MenuParts.CAB_HI.lightened(0.1), 0.3, 0.5))
			MenuParts.text(kit, _keys_node, "✕", b.position + Vector2(3, 1), 2,
					MenuParts.INK, 0.0088)
			kit.pickable("equipment", btn, "clear:%d" % i)
		entry["words"] = (l.text + (" " + tail if tail != "" else "")
				+ (" " + mark if mark != "" else "")).strip_edges()
		entry["holds"] = l.text
		_keys.append(entry)
	_mark_keys(at_once)


## A key's window: what the bridge last confirmed is on it, or EMPTY; a
## consumable's charges, apart; and the mark of a request for it.
## [words, colour, tail, mark, tail colour, mark colour].
func _key_words(i: int) -> Array:
	var slot := slot_of(i)
	if slot == "":
		return ["NO KEY · %d" % _count_always_on(), MenuParts.LIT_DIM, "", "",
			MenuParts.LIT, MenuParts.LIT]
	var on := confirmed(slot)
	var mark := ""
	var mark_c := MenuParts.LIT
	var pending := requests.pending(slot)
	var answer := requests.answer(slot)
	if not pending.is_empty():
		mark = MARKS[EquipRequests.PENDING]
		mark_c = SENT_C
	elif not answer.is_empty():
		var state := str(answer["state"])
		mark = str(MARKS.get(state, ""))
		mark_c = MenuParts.LIT if state == EquipRequests.ACCEPTED else WARN_C
	if on == "":
		return ["EMPTY", MenuParts.LIT_FAINT, "", mark, MenuParts.LIT, mark_c]
	var tail := ""
	var tail_c := MenuParts.LIT
	if slot == "consumable":
		var st := _consumable_state()
		tail = str(st["count"]).replace(" ", "")
		if str(st["state"]) in ["equipped_empty", "disconnected"]:
			tail_c = WARN_C
	return [_name(on), MenuParts.LIT, tail, mark, tail_c, mark_c]


func _count_always_on() -> int:
	var n := 0
	for row: Dictionary in _rows:
		if not EquipmentQuery.is_slotted(row):
			n += 1
	return n


func _consumable_state() -> Dictionary:
	var holds: Variant = BridgeClient.slots().get("consumable")
	var cid := "" if holds == null else str(holds)
	return EquipmentQuery.consumable_state(_rows, holds,
			BridgeClient.charges_left(cid) if cid != "" else 0,
			BridgeClient.awaiting_authorization(cid) if cid != "" else 0,
			BridgeClient.can_send())


func _can_clear(slot: String) -> bool:
	return slot != "" and confirmed(slot) != "" and not requests.is_pending(slot) \
			and BridgeClient.can_send()


## The selector's state on the wall: the pointer at the key being looked at
## (a detent's turn), its mark lit, its words bright; the SIGNAL bar while
## the keys have the focus; a faint ground under a hovered key; a key
## holding something new, its name in the NEW sticker's yellow.
func _mark_keys(at_once := false) -> void:
	var to := -_angle(key_index)
	if at_once:
		_pivot.rotation.z = to
	else:
		kit.go(_pivot, "rotation:z", to, 0.1, "out")
	for i in _keys.size():
		var e: Dictionary = _keys[i]
		var here := i == key_index
		(e["tick"] as StandardMaterial3D).albedo_color = MenuParts.INK if here \
				else MenuParts.FAINT
		(e["bar"] as StandardMaterial3D).albedo_color = Color(MenuKit.SIGNAL, 1.0
				if here and zone == "keys" else 0.0)
		(e["ground"] as StandardMaterial3D).albedo_color = Color(
				MenuParts.CAB_HI.lightened(0.12), 0.9 if hovered == "key:%d" % i
				and not here else 0.0)
		var title_c := MenuParts.INK if here else MenuParts.DIM
		if bool(e["new"]):
			title_c = NEW_C
		(e["title"] as Label3D).modulate = title_c


# ============================================================ the rack

## The focused key's rack: its modules, in order, from the row the key
## remembers; what it holds is SEATED, what is being read is PULLED.
## `keep`: a rebuild (a snapshot, a search): the item being read and the
## first row shown are kept by identity where they still exist.
func _open_rack(keep := false) -> void:
	_order = candidates(key_index)
	var slot := slot_of(key_index)
	var remembered: String = sel.get(key_index, "")
	if keep and unfolded != "" and _order.has(unfolded):
		remembered = unfolded
	if remembered == "" or not _order.has(remembered):
		var on := confirmed(slot) if slot != "" else ""
		remembered = on if _order.has(on) else ""
		if zone == "drawer" and remembered == "" and not _order.is_empty():
			remembered = str(_order[0])
	unfolded = remembered
	if unfolded != "":
		sel[key_index] = unfolded
	var first_id: String = anchor.get(key_index, "")
	_first = _order.find(first_id) if first_id != "" else 0
	if _first < 0:
		_first = 0
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
	anchor[key_index] = str(_order[_first]) if _first < _order.size() else ""


func _row_y(i: int) -> float:
	return ROW_Y0 + ROW_PITCH * float(i - _first)


func _build_rows(at_once := true) -> void:
	if _rack != null:
		_rack.queue_free()
	_rack = Node3D.new()
	_rack.name = "Rack"
	face.add_child(_rack)
	_rows_drawn.clear()
	var slot := slot_of(key_index)
	var head := "FITS %s · %d" % [_cap(), _total] if slot != "" \
			else "ALWAYS ON · NO KEY · %d" % _total
	if search != "":
		head = "FITS %s · %d OF %d" % [_cap(), _order.size(), _total] if slot != "" \
				else "ALWAYS ON · %d OF %d" % [_order.size(), _total]
	var fresh := 0
	for id: String in _order:
		if _is_new(id):
			fresh += 1
	var hx := ROW_X
	MenuParts.text(kit, _rack, head, Vector2(hx, BAY.position.y + 10), 2,
			MenuParts.SILK, BZ + 0.0006)
	if fresh > 0:
		hx += kit.measure(head, 2) + 12.0
		_sticker(_rack, Vector2(hx, BAY.position.y + 8), "%d NEW" % fresh,
				BZ + 0.0006)
	var above := _first
	var below := maxi(0, _order.size() - _first - SHOWN)
	var mx := ROW_END
	for pair: Array in [[below, "arrow_down", "%d MORE BELOW"], [above, "arrow_up",
			"%d MORE ABOVE"]]:
		if int(pair[0]) <= 0:
			continue
		var words := kit.display(str(pair[2]) % int(pair[0]))
		var w := kit.measure(words, 2)
		MenuParts.text(kit, _rack, words, Vector2(mx - w, BAY.position.y + 10), 2,
				MenuParts.SILK_DIM, BZ + 0.0006)
		MenuParts.sprite(kit, _rack, str(pair[1]), Vector2(mx - w - 12,
				BAY.position.y + 18), 2, MenuParts.SILK_DIM, BZ + 0.0008)
		mx -= w + 34.0
	_info_more = [above, below]
	if _order.is_empty():
		var words := "NOTHING YOU HOLD GOES ON %s" % _cap() if slot != "" \
				else "NOTHING YOU HOLD IS ALWAYS ON"
		if search != "":
			words = "NOTHING ON %s MATCHES “%s”" % [_cap() if slot != ""
					else "ALWAYS ON", search.to_upper()]
		MenuParts.tape(kit, _rack, Vector2(ROW_X + 20, ROW_Y0 + 14), kit.fit(words, 2,
				ROW_END - ROW_X - 60.0), BZ)
		if search != "":
			var elsewhere := _matches_elsewhere()
			if not elsewhere.is_empty():
				MenuParts.text(kit, _rack, kit.fit("IT MATCHES ON: " + ", ".join(
						elsewhere), 2, ROW_END - ROW_X - 40.0), Vector2(ROW_X + 20,
						ROW_Y0 + 52), 2, MenuParts.SILK_DIM, BZ + 0.0006)
	for i in range(_first, mini(_first + SHOWN, _order.size())):
		_module(_order[i], i)
	_place_knob(at_once)
	_mark_rows(true)


## A yellow NEW sticker, stuck on by hand. Returns its width.
func _sticker(parent: Node3D, at: Vector2, words: String, z: float) -> float:
	var w := kit.measure(words, 2) + 12.0
	MenuParts.block(parent, Rect2(at, Vector2(w, 20)), z, z + 0.001,
			MenuParts.mat(NEW_C, 0.0, 0.7))
	MenuParts.text(kit, parent, words, at + Vector2(6, 2), 2, NEW_INK, z + 0.0022)
	return w


## One module: its face on the backplane, its gold contacts in the
## connector, its pull, its name and tags, and -- if it stands anywhere
## with the key -- its window, which says so.
func _module(id: String, i: int) -> void:
	var y := _row_y(i)
	var node := Node3D.new()
	node.name = "Module"
	node.set_meta("id", id)
	_rack.add_child(node)
	var r := Rect2(ROW_X, y, ROW_END - ROW_X, ROW_H)
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = MenuParts.MODULE
	face_mat.metallic = 0.15
	face_mat.roughness = 0.55
	face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slab := MenuParts.slab(node, MenuParts.rrect(r, 2), BZ + 0.0005, SEAT_Z, face_mat)
	kit.pickable("equipment", slab, "row:" + id)
	MenuParts.block(node, Rect2(r.position.x - 8, y + 6, 10, ROW_H - 12), SEAT_Z - 0.003,
			SEAT_Z - 0.0012, MenuParts.mat(MenuParts.GOLD, 0.8, 0.3), false)
	var tab_mat := StandardMaterial3D.new()
	tab_mat.albedo_color = MenuParts.BAKELITE
	tab_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tab := MenuParts.block(node, Rect2(r.position.x + 6, y + 5, 10, ROW_H - 10),
			SEAT_Z, SEAT_Z + 0.014, tab_mat)
	kit.pickable("equipment", tab, "row:" + id)
	var zt := SEAT_Z + 0.0008
	var stands := _stands(id)
	var right := r.end.x - 8.0
	if stands != "":
		var ww := kit.measure(stands, 2) + 16.0
		var fw := Rect2(right - ww, y + 3, ww, ROW_H - 6)
		MenuParts.block(node, fw, SEAT_Z, SEAT_Z + 0.0006,
				MenuParts.mat(MenuParts.RECESS, 0.0, 0.95), false)
		MenuParts.text(kit, node, stands, fw.position + Vector2(8, 2), 2,
				_stands_colour(stands), SEAT_Z + 0.0018)
		right = fw.position.x - 10.0
	var tags := [_mk(id)]
	if _charges(id) != "":
		tags.append(_charges(id))
	var t := " · ".join(tags)
	var tw := kit.measure(t, 2)
	var tag_l := MenuParts.text(kit, node, t, Vector2(right - tw, y + 5), 2,
			MenuParts.SILK_FAINT, zt)
	right -= tw + 10.0
	if _is_new(id):
		var sw := kit.measure("NEW", 2) + 12.0
		_sticker(node, Vector2(right - sw, y + 2), "NEW", zt)
		right -= sw + 8.0
	var name_w := right - 6.0 - (r.position.x + 26.0)
	var name_l := MenuParts.text(kit, node, kit.fit(_name(id), 2, name_w),
			Vector2(r.position.x + 26, y + 5), 2, MenuParts.SILK_DIM, zt)
	var c := r.get_center()
	var out := MenuParts.P(c + Vector2(-PULL, 0), PULL_Z) - MenuParts.P(c, SEAT_Z)
	_rows_drawn[id] = {"node": node, "face": face_mat, "tab": tab_mat, "name": name_l,
		"tags": tag_l, "out": out, "index": i, "stands": stands,
		"words": "%s | %s" % [name_l.text, tag_l.text], "new": _is_new(id)}


## The rack's state on the wall: the module being read pulled out (its tab
## SIGNAL while the rack has the focus), every other one home; a hovered
## one's face lit a little -- light only, never movement.
func _mark_rows(at_once := false) -> void:
	for id: String in _rows_drawn:
		var r: Dictionary = _rows_drawn[id]
		var node: Node3D = r["node"]
		var pulled := id == unfolded
		var to: Vector3 = r["out"] if pulled else Vector3.ZERO
		if at_once:
			node.position = to
		else:
			kit.go(node, "position", to, 0.1, "out")
		(r["tab"] as StandardMaterial3D).albedo_color = MenuKit.SIGNAL if pulled \
				and zone == "drawer" else (MenuParts.BAKELITE.lightened(0.25) if pulled
				else MenuParts.BAKELITE)
		var lit := pulled or hovered == "row:" + id
		(r["face"] as StandardMaterial3D).albedo_color = MenuParts.MODULE.lightened(0.09
				if lit else 0.0)
		var bright := pulled or str(r["stands"]) != ""
		(r["name"] as Label3D).modulate = MenuParts.SILK if bright else MenuParts.SILK_DIM
		(r["tags"] as Label3D).modulate = MenuParts.SILK_DIM if pulled \
				else MenuParts.SILK_FAINT


## The scroll pot's knob: its length the share of the rack shown, its
## place the share scrolled past. A scroll slides it (at once when motion
## is reduced).
func _place_knob(at_once := false) -> void:
	var n := maxi(_order.size(), 1)
	var h := maxf(24.0, TRACK.size.y * minf(1.0, float(SHOWN) / float(n)))
	var z := BZ + 0.012
	if absf(h - _knob_h) > 0.01:
		for c: Node in _knob.get_children():
			c.queue_free()
		var knob := MenuParts.block(_knob, Rect2(TRACK.position.x - 4, TRACK.position.y,
				16, h), BZ + 0.004, z, MenuParts.mat(Color("#cfd2cf"), 0.2, 0.5))
		kit.pickable("equipment", knob, "track")
		_knob_h = h
		at_once = true
	var dy := (TRACK.size.y - h) * float(_first) / float(_max_first()) \
			if _max_first() > 0 else 0.0
	var to := MenuParts.P(Vector2(TRACK.position.x, TRACK.position.y + dy), z) \
			- MenuParts.P(Vector2(TRACK.position.x, TRACK.position.y), z)
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
	_readout.name = "Readout"
	_readout.set_meta("composition", true)
	face.add_child(_readout)
	_info = {}
	if unfolded == "" or not _by_id.has(unfolded):
		_compose_key()
		return
	if history_open:
		_compose_more(unfolded)
	else:
		_compose_item(unfolded)
	# READ, and so no longer new -- only while this wall faces the eye.
	if _open and _front and _is_new(unfolded):
		EquipmentSeen.mark_seen(_campaign, unfolded)


## Nothing selected: the key itself, in the same window -- what the bridge
## says is on it, a request for it, and the consumable's own state.
func _compose_key() -> void:
	var slot := slot_of(key_index)
	var title := EquipmentQuery.slot_title(slot) if slot != "" else "ALWAYS ON"
	var x := COL_L
	var y := TOP
	if slot != "":
		x += MenuParts.keycap(kit, _readout, _cap(), Vector2(COL_L, y - 5), Z) + 12.0
	MenuParts.text(kit, _readout, "A KEY" if slot != "" else "NO KEY · NOT A SLOT",
			Vector2(x, y), 2, MenuParts.LIT_DIM, Z)
	y += 30.0
	MenuParts.text(kit, _readout, title, Vector2(COL_L, y), 5, MenuParts.LIT, Z)
	y += 58.0
	var words: Array = []
	if slot != "":
		var on := confirmed(slot)
		words.append(["NOTHING IS ON %s NOW." % _cap() if on == ""
				else "%s IS ON %s NOW." % [_name(on), _cap()], MenuParts.LIT_DIM])
		if slot == "consumable":
			var st := _consumable_state()
			if str(st["count"]) != "":
				words.append(["%s USES LEFT." % str(st["count"]), MenuParts.LIT])
			if str(st["text"]) != "":
				words.append([str(st["text"]), WARN_C if str(st["state"]) in [
						"equipped_empty", "disconnected"] else MenuParts.LIT_DIM])
	else:
		words.append(["WHAT YOU OWN THAT IS ALWAYS ON: IT TAKES NO KEY, AND IS NOT "
				+ "A SWITCH.", MenuParts.LIT_DIM])
	if _order.is_empty():
		words.append([("NOTHING YOU HOLD GOES HERE." if search == ""
				else "NOTHING HERE MATCHES “%s”." % search.to_upper()),
				MenuParts.LIT_DIM])
	else:
		words.append(["%d HERE. MOVE INTO THE RACK TO READ ONE." % _order.size(),
				MenuParts.LIT_DIM])
	if note != "":
		words.append([note, MenuParts.LIT])
	for w: Array in words:
		for line in kit.wrap(str(w[0]), 2, COL_L_W):
			MenuParts.text(kit, _readout, line, Vector2(COL_L, y), 2, w[1], Z)
			y += LINE
	_info["bottom"] = y
	var status := _status_lines(slot)
	var ry := TOP
	if not status.is_empty():
		MenuParts.text(kit, _readout, "REQUESTS FOR THIS KEY", Vector2(COL_R, ry), 2,
				MenuParts.LIT_DIM, Z)
		ry += LINE + 8.0
		for line: Array in status:
			for l in kit.wrap(str(line[0]), 2, COL_R_W):
				MenuParts.text(kit, _readout, l, Vector2(COL_R, ry), 2, line[1], Z)
				ry += LINE
	_info["status"] = _status_words(slot)
	_info["right_bottom"] = ry
	_info["fits"] = y <= BOTTOM + 0.5 and ry <= BOTTOM + 0.5
	_info["id"] = ""


## THE REQUEST FOR THIS KEY, in words: [[line, colour]] -- empty when there
## is none this visit. The same words wherever the key is read.
func _status_lines(slot: String) -> Array:
	if slot == "":
		return []
	var pending := requests.pending(slot)
	if not pending.is_empty():
		var on := confirmed(slot)
		var what := _request_what(pending.get("component_id"))
		return [["→ SENT: %s. WAITING FOR THE BRIDGE; %s STILL HOLDS %s." % [what,
				_cap(), _name(on) if on != "" else "NOTHING"], SENT_C]]
	var answer := requests.answer(slot)
	if answer.is_empty():
		return []
	var what := _request_what(answer.get("component_id"))
	match str(answer["state"]):
		EquipRequests.ACCEPTED:
			return [["✓ THE BRIDGE CONFIRMED IT: %s." % what, MenuParts.LIT]]
		EquipRequests.REFUSED:
			return [["✗ REFUSED — %s" % str(answer.get("message", "")), WARN_C]]
		EquipRequests.NOT_SENT:
			return [["✗ NOT SENT — NO LINK TO THE BRIDGE.", WARN_C]]
		EquipRequests.LOST:
			return [["? THE LINK DROPPED BEFORE THE BRIDGE ANSWERED. %s SHOWS WHAT "
					% _cap() + "IT LAST CONFIRMED.", WARN_C]]
	return []


func _status_words(slot: String) -> String:
	var out: Array = []
	for line: Array in _status_lines(slot):
		out.append(str(line[0]))
	return " ".join(out)


func _request_what(component_id: Variant) -> String:
	if component_id == null:
		return "CLEAR %s" % _cap()
	return "%s ON %s" % [_name(str(component_id)), _cap()]


## The read item: on the left what it IS (where it stands with the key, its
## name, what it does, what it is, how it is used and what it costs); on
## the right what CHANGES if it goes on the key (Production's own lines,
## EquipmentQuery.comparison against the CONFIRMED occupant, aligned) and
## where it came from; at the foot on the right, the request's state and
## the one action. Every block is placed, never dropped: if a column would
## overflow, its sizes step down (the name first, never below 3x; then
## what it does, never below 2x), the history goes wherever there is room,
## and what still does not fit is a HISTORY press away, said so.
func _compose_item(id: String) -> void:
	var row: Dictionary = _by_id[id]
	var slot := slot_of(key_index)
	var on := confirmed(slot) if slot != "" else ""
	# ---- the right column's blocks, measured
	var right: Array = []           # [lines]
	var head := ""
	var compare: Array = []
	if slot == "":
		head = "NO KEY · NOTHING TO COMPARE"
	elif on == id:
		head = "ON THE KEY"
		right.append("IT IS ON %s NOW." % _cap())
	elif on == "":
		head = "NOTHING ON %s TO COMPARE" % _cap()
	else:
		head = "IF ON %s, IN PLACE OF %s" % [_cap(), _name(on)]
		compare = EquipmentQuery.comparison(row, _by_id.get(on, {}))
		_info["compared"] = on
	var act := _action(id)
	var can := _can_act(id)
	var status := _status_lines(slot)
	# the foot: a button for an action that can be taken; the reason, whole,
	# for one that cannot; above it, the request's state
	var refusal: PackedStringArray = kit.wrap(act, 2, COL_R_W - 20.0) \
			if act != "" and not can else PackedStringArray()
	if slot != "" and requests.is_pending(slot) and not can:
		refusal = PackedStringArray()      # the status line says it already
	var status_lines: Array = []
	for line: Array in status:
		for l in kit.wrap(str(line[0]), 2, COL_R_W):
			status_lines.append([l, line[1]])
	var foot := BOTTOM
	if can:
		foot = BOTTOM - ACT_H - 6.0
	elif not refusal.is_empty():
		foot = BOTTOM - LINE * refusal.size() - 6.0
	foot -= LINE * status_lines.size() + (6.0 if not status_lines.is_empty() else 0.0)
	var hist := _history(id)
	var r_h := LINE * kit.wrap(head, 2, COL_R_W).size() + 8.0
	for w: String in right:
		r_h += LINE * kit.wrap(w, 2, COL_R_W).size()
	var t_pitch := LINE
	var t_h := _table_h(compare, COL_R_W, t_pitch)
	var h_h := LINE * hist.size()
	# ---- the left column, at the largest sizes that fit (its foot keeps
	# a row for HISTORY and WHEEL)
	var plan := {}
	var left_room := BOTTOM - TOP - TOGGLES_H
	for option: Array in [[5, 3], [4, 3], [5, 2], [4, 2], [3, 2]]:
		plan = _left_plan(id, int(option[0]), int(option[1]))
		if float(plan["h"]) <= left_room:
			break
	var cut := false
	if float(plan["h"]) > left_room:
		# Still too tall at the smallest sizes: the description is cut where
		# it must be, and said so -- the whole of it is in HISTORY.
		plan = _cut_plan(plan, left_room)
		cut = true
	# the history on the right under the comparison if it fits there; else
	# under the left column if it fits there; else the comparison closes up;
	# else it is in HISTORY only
	var hist_place := "right"
	var h_gap := 10.0 if h_h > 0.0 else 0.0
	if TOP + r_h + t_h + h_gap + h_h > foot:
		if float(plan["h"]) + 12.0 + h_h <= left_room:
			hist_place = "left"
		else:
			t_pitch = 18.0
			if TOP + r_h + _table_h(compare, COL_R_W, t_pitch) + h_gap + h_h > foot:
				hist_place = "left" if float(plan["h"]) + 12.0 + h_h <= left_room \
						else "none"
	if TOP + r_h + _table_h(compare, COL_R_W, t_pitch) > foot:
		t_pitch = 18.0
	# ---- the left column, drawn
	var y := _draw_left(id, plan)
	if hist_place == "left":
		y += 12.0
		y = _draw_history(hist, COL_L, y, COL_L_W)
	_info["left_bottom"] = y
	# ---- the right column, drawn
	var ry := TOP
	for line in kit.wrap(head, 2, COL_R_W):
		MenuParts.text(kit, _readout, line, Vector2(COL_R, ry), 2, MenuParts.LIT_DIM, Z)
		ry += LINE
	ry += 8.0
	for w: String in right:
		for line in kit.wrap(w, 2, COL_R_W):
			MenuParts.text(kit, _readout, line, Vector2(COL_R, ry), 2, MenuParts.LIT, Z)
			ry += LINE
	if not compare.is_empty():
		ry = _table(compare, COL_R, ry, COL_R_W, t_pitch)
	if hist_place == "right" and not hist.is_empty():
		ry = _draw_history(hist, COL_R, ry + 10.0, COL_R_W)
	_info["right_bottom"] = ry
	# ---- the foot: the request's state, then the one action, always in the
	# same place
	var sy := foot + 6.0
	for line: Array in status_lines:
		MenuParts.text(kit, _readout, str(line[0]), Vector2(COL_R, sy), 2, line[1], Z)
		sy += LINE
	var ay := BOTTOM - ACT_H
	if can:
		_action_button(Vector2(COL_R - 4, ay), kit.fit(act, 2, COL_R_W - 104.0))
	elif not refusal.is_empty():
		var fy := BOTTOM - LINE * refusal.size()
		for line in refusal:
			MenuParts.text(kit, _readout, line, Vector2(COL_R, fy), 2,
					WARN_C if act.begins_with("OFFLINE") else MenuParts.LIT_DIM, Z)
			fy += LINE
		_info["action_words"] = " ".join(refusal)
	# ---- the left column's foot: HISTORY, and the wheel's favourite
	_toggles(id, hist_place == "none" or cut)
	_info["id"] = id
	_info["name_k"] = plan["name_k"]
	_info["name_lines"] = (plan["name"] as PackedStringArray).size()
	_info["does_k"] = plan["does_k"]
	_info["table_pitch"] = t_pitch
	_info["history_place"] = hist_place
	_info["cut"] = cut
	_info["bottom"] = maxf(float(_info["left_bottom"]), ry)
	_info["foot"] = foot
	_info["status"] = _status_words(slot)
	# nothing crosses the foot or the window's edge, and nothing was dropped
	_info["fits"] = float(_info["left_bottom"]) <= BOTTOM - TOGGLES_H + 0.5 \
			and ry <= foot + 0.5
	_info["stands"] = _stands(id)


## The left column's foot: HISTORY (with its key, and a count), and -- for
## an item on a key, on the keyboard -- the wheel's favourite. `more`:
## something is only in HISTORY, and the toggle says so.
func _toggles(id: String, more: bool) -> void:
	var row: Dictionary = _by_id[id]
	var y := BOTTOM - 26.0
	var x := COL_L
	var n := EquipmentQuery.history(row).size()
	var words := "HISTORY %d %s" % [n, "▾" if history_open else "▸"]
	if more and not history_open:
		words = "HISTORY %d · MORE THERE ▸" % n
	x += _toggle(Vector2(x, y), "H", "pad_face_north", words, "history",
			history_open) + 16.0
	_info["history_words"] = kit.display(words)
	if EquipmentQuery.is_slotted(row) and kit.device != "pad":
		var fav := Favourites.is_favourite(id)
		_toggle(Vector2(x, y), "F", "", ("★" if fav else "☆") + " WHEEL", "favourite",
				fav)
		_info["favourite"] = fav


## A small toggle on the window's sill: its key, then its words on a
## plate that answers to the pointer. Returns its width.
func _toggle(at: Vector2, key: String, pad_icon: String, words: String,
		target: String, on: bool) -> float:
	var x := at.x
	if kit.device == "pad":
		if pad_icon != "":
			MenuParts.sprite(kit, _readout, pad_icon, at + Vector2(12, 13), 2,
					MenuParts.INK, 0.004)
			x += 30.0
	else:
		x += MenuParts.keycap(kit, _readout, key, at, 0.002) + 6.0
	var w := kit.measure(words, 2) + 16.0
	var plate := MenuParts.block(_readout, Rect2(x, at.y, w, 26), 0.002, 0.005,
			MenuParts.mat(MenuParts.CAB_HI.lightened(0.18 if on else 0.06), 0.3, 0.55))
	kit.pickable("equipment", plate, target)
	MenuParts.text(kit, _readout, words, Vector2(x + 8, at.y + 5), 2,
			MenuParts.LIT if on else MenuParts.LIT_DIM, 0.0062)
	return x + w - at.x


## HISTORY, the long answer, in the same window: every item that went into
## this one and what each did; the description whole; what Epsilon read;
## what else the same Echo brought. The foot -- the request's state and
## the one action -- stays where it always is.
func _compose_more(id: String) -> void:
	var row: Dictionary = _by_id[id]
	var left: Array = []                # [text, colour, indent]
	left.append(["HISTORY OF %s" % _name(id), MenuParts.LIT_DIM, 0.0])
	for h: Array in _history(id):
		for line in kit.wrap("%s  %s" % [str(h[0]), str(h[1])], 2, COL_L_W):
			left.append([line, MenuParts.LIT, 0.0])
	var desc := str((row.get("component", {}) as Dictionary).get("description", ""))
	if desc != "":
		left.append(["", MenuParts.LIT, 0.0])
		left.append(["WHAT IT IS", MenuParts.LIT_DIM, 0.0])
		for line in kit.wrap(desc, 2, COL_L_W):
			left.append([line, MenuParts.LIT, 0.0])
	var reads := EquipmentQuery.read_lines(row)
	if not reads.is_empty():
		left.append(["", MenuParts.LIT, 0.0])
		left.append(["WHAT EPSILON READ", MenuParts.LIT_DIM, 0.0])
		for read: String in reads:
			for line in kit.wrap(read, 2, COL_L_W):
				left.append([line, MenuParts.LIT, 0.0])
	var siblings: Array = []
	for sibling: Variant in row.get("siblings", []):
		var other: Dictionary = _by_id.get(str(sibling), {})
		if not other.is_empty():
			siblings.append("%s (%s)" % [EquipmentQuery.name_of(other),
					"always on" if not EquipmentQuery.is_slotted(other) else "on "
					+ SlotKeycaps.of(EquipmentQuery.home_slot(other))])
	if not siblings.is_empty():
		left.append(["", MenuParts.LIT, 0.0])
		left.append(["ALSO FROM THE SAME ECHO", MenuParts.LIT_DIM, 0.0])
		for s: String in siblings:
			for line in kit.wrap(s, 2, COL_L_W):
				left.append([line, MenuParts.LIT, 0.0])
	# Flowed down the left column, then the right above the foot; what is
	# still left is scrolled to (the wheel, the right stick).
	var slot := slot_of(key_index)
	var status := _status_lines(slot)
	var act := _action(id)
	var can := _can_act(id)
	var foot_h := (ACT_H + 6.0) if can else (LINE * kit.wrap(act, 2,
			COL_R_W - 20.0).size() + 6.0 if act != "" else 0.0)
	for line: Array in status:
		foot_h += LINE * kit.wrap(str(line[0]), 2, COL_R_W).size()
	var left_n := int((BOTTOM - TOGGLES_H - TOP) / LINE)
	var right_n := maxi(0, int((BOTTOM - foot_h - 8.0 - TOP) / LINE))
	var room := left_n + right_n
	_more_first = clampi(_more_first, 0, maxi(0, left.size() - room))
	var shown := left.slice(_more_first, _more_first + room)
	for i in shown.size():
		var line: Array = shown[i]
		var col_x := COL_L if i < left_n else COL_R
		var y := TOP + LINE * float(i if i < left_n else i - left_n)
		MenuParts.text(kit, _readout, str(line[0]), Vector2(col_x, y), 2, line[1], Z)
	var hidden_below := maxi(0, left.size() - _more_first - room)
	if _more_first > 0 or hidden_below > 0:
		var words := "%d MORE · WHEEL OR STICK" % (hidden_below if hidden_below > 0
				else _more_first)
		MenuParts.text(kit, _readout, words, Vector2(WIN.end.x - 24 - kit.measure(words, 2),
				WIN.position.y + 6), 2, MenuParts.LIT_FAINT, Z)
	# the foot, as ever
	var sy := BOTTOM - foot_h
	for line: Array in status:
		for l in kit.wrap(str(line[0]), 2, COL_R_W):
			MenuParts.text(kit, _readout, l, Vector2(COL_R, sy), 2, line[1], Z)
			sy += LINE
	var ay := BOTTOM - ACT_H
	if can:
		_action_button(Vector2(COL_R - 4, ay), kit.fit(act, 2, COL_R_W - 104.0))
	elif act != "":
		var fy := BOTTOM - LINE * kit.wrap(act, 2, COL_R_W - 20.0).size()
		for line in kit.wrap(act, 2, COL_R_W - 20.0):
			MenuParts.text(kit, _readout, line, Vector2(COL_R, fy), 2,
					MenuParts.LIT_DIM, Z)
			fy += LINE
		_info["action_words"] = act
	_toggles(id, false)
	_info["id"] = id
	_info["more_lines"] = left.size()
	_info["more_first"] = _more_first
	_info["status"] = _status_words(slot)
	_info["fits"] = true


## The left column's plan at name size `nk` and DOES size `dk`: its lines
## and its height.
func _left_plan(id: String, nk: int, dk: int) -> Dictionary:
	var row: Dictionary = _by_id[id]
	var component: Dictionary = row.get("component", {})
	var name := kit.wrap(_name(id), nk, COL_L_W)
	if name.size() > 2 and nk > 3:
		return {"h": INF, "name": name, "name_k": nk, "does_k": dk}
	var h := 30.0                                   # the kicker
	h += (8.0 * nk + 6.0) * name.size() + 6.0
	var does: Array = []
	for line: String in EquipmentQuery.does(row):
		for l in kit.wrap(_units(line), dk, COL_L_W - 64.0):
			does.append(l)
	h += (8.0 * dk + 6.0) * does.size() + 4.0
	var desc := kit.wrap(str(component.get("description", "")), 2, COL_L_W)
	h += LINE * desc.size() + 6.0
	var uses: Array = []
	for line: String in EquipmentQuery.use_lines(row, _rows):
		for l in kit.wrap(_units(line), 2, COL_L_W - 64.0):
			uses.append(l)
	var costs: Array = []
	var cost_src: Array = EquipmentQuery.cost_lines(row)
	if EquipmentQuery.is_consumable(row):
		cost_src.push_front("%s uses left." % _charges(id).replace("/", " of "))
	for line: String in cost_src:
		for l in kit.wrap(_units(line), 2, COL_L_W - 64.0):
			costs.append(l)
	h += LINE * (uses.size() + costs.size())
	return {"h": h, "name": name, "name_k": nk, "does_k": dk, "does": does,
		"desc": desc, "use": uses, "cost": costs}


## The smallest plan, its description cut to what fits, with "..." --
## HISTORY has it whole.
func _cut_plan(plan: Dictionary, room: float) -> Dictionary:
	var desc: PackedStringArray = plan.get("desc", PackedStringArray())
	var over := float(plan["h"]) - room
	var drop := mini(desc.size(), int(ceilf(over / LINE)) + 1)
	var keep := desc.size() - drop
	var out := plan.duplicate()
	var cut := PackedStringArray()
	for i in maxi(keep, 0):
		cut.append(desc[i])
	if keep >= 0 and not cut.is_empty():
		cut[cut.size() - 1] = kit.fit(cut[cut.size() - 1] + " ...", 2, COL_L_W)
	elif desc.size() > 0:
		cut.append("... (THE REST IS IN HISTORY)")
	out["desc"] = cut
	out["h"] = float(plan["h"]) - LINE * (desc.size() - cut.size())
	return out


## A number keeps its unit on its line: "1.5 s" is never wrapped as "1.5"
## and a lone "s" (Production's `_keep_units`).
static var _unit_rx: RegEx = null


static func _units(text: String) -> String:
	if _unit_rx == null:
		_unit_rx = RegEx.create_from_string("(\\d) (s|m|m/s|HP|°)(?=[\\s.,)]|$)")
	return _unit_rx.sub(text, "$1 $2", true)


func _draw_left(id: String, plan: Dictionary) -> float:
	var row: Dictionary = _by_id[id]
	var slot := slot_of(key_index)
	var x := COL_L
	var y := TOP
	# the kicker: the key, where this stands with it, and what kind of thing
	var stands := _stands(id)
	var kick := "FITS THIS KEY" if slot != "" else "ALWAYS ON · NO KEY"
	if stands.begins_with("ON "):
		kick = "ON THIS KEY NOW"
	elif stands.begins_with("SENT"):
		kick = "SENT · NOT ON THE KEY YET"
	elif stands != "":
		kick = stands
	if slot != "":
		x += MenuParts.keycap(kit, _readout, _cap(), Vector2(COL_L, y - 5), Z) + 12.0
	var kick_c := MenuParts.LIT_DIM
	if stands != "":
		kick_c = _stands_colour(stands)
	MenuParts.text(kit, _readout, kit.fit(kick, 2, MID_X - x - 180.0), Vector2(x, y), 2,
			kick_c, Z)
	var kind := "%s · %s" % [EquipmentQuery.family(row), _mk(id)]
	if _is_new(id):
		kind = "NEW · " + kind
	MenuParts.text(kit, _readout, kind, Vector2(MID_X - 24 - kit.measure(kind, 2), y), 2,
			NEW_C if _is_new(id) else MenuParts.LIT_DIM, Z)
	y += 30.0
	var nk: int = plan["name_k"]
	for line: String in plan["name"]:
		MenuParts.text(kit, _readout, line, Vector2(COL_L, y), nk, MenuParts.LIT, Z)
		y += 8.0 * nk + 6.0
	y += 6.0
	var dk: int = plan["does_k"]
	if not (plan["does"] as Array).is_empty():
		MenuParts.text(kit, _readout, "DOES", Vector2(COL_L, y + (4.0 if dk == 3
				else 0.0)), 2, MenuParts.LIT_FAINT, Z)
	for line: String in plan["does"]:
		MenuParts.text(kit, _readout, line, Vector2(COL_L + 64, y), dk, MenuParts.LIT, Z)
		y += 8.0 * dk + 6.0
	y += 4.0
	for line: String in plan["desc"]:
		MenuParts.text(kit, _readout, line, Vector2(COL_L, y), 2, MenuParts.LIT_DIM, Z)
		y += LINE
	_info["desc_lines"] = (plan["desc"] as PackedStringArray).size()
	y += 6.0
	for block: Array in [["USE", plan["use"]], ["COST", plan["cost"]]]:
		var lines: Array = block[1]
		if lines.is_empty():
			continue
		MenuParts.text(kit, _readout, block[0], Vector2(COL_L, y), 2, MenuParts.LIT_FAINT, Z)
		for line: String in lines:
			MenuParts.text(kit, _readout, line, Vector2(COL_L + 64, y), 2, MenuParts.LIT_DIM,
					Z)
			y += LINE
	return y


## Where it came from: every item that went into it, one line each --
## Production's history, "Mk  note ← item (game)"; the create's note is the
## name above, so it is not said twice.
func _history(id: String) -> Array:
	var out := []
	for link: Dictionary in EquipmentQuery.history(_by_id[id]):
		var what := "← %s (%s)" % [str(link["item"]), str(link["game"])]
		if str(link.get("operation", "")) != "create" and str(link["note"]) != "":
			what = "%s %s" % [str(link["note"]), what]
		out.append([str(link["mark"]), what])
	return out


func _draw_history(hist: Array, x: float, y: float, width: float) -> float:
	for h: Array in hist:
		MenuParts.text(kit, _readout, str(h[0]), Vector2(x, y), 2, MenuParts.LIT_FAINT, Z)
		MenuParts.text(kit, _readout, kit.fit(str(h[1]), 2, width - 64.0),
				Vector2(x + 64, y), 2, MenuParts.LIT_FAINT, Z)
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
				MenuParts.text(kit, _readout, line, Vector2(x, y), 2, MenuParts.LIT, Z)
				y += pitch
			continue
		if not r.get("row", false):
			var lw2 := kit.measure(r["label"], 2) + 16.0
			MenuParts.text(kit, _readout, r["label"], Vector2(x, y), 2, MenuParts.LIT_FAINT,
					Z)
			if lw2 + kit.measure(r["old"], 2) <= width:
				MenuParts.text(kit, _readout, r["old"], Vector2(x + lw2, y), 2,
						MenuParts.LIT_DIM, Z)
				y += pitch
			else:
				y += pitch
				MenuParts.text(kit, _readout, kit.fit(r["old"], 2, width - 24),
						Vector2(x + 24, y), 2, MenuParts.LIT_DIM, Z)
				y += pitch
				lw2 = 24.0
			MenuParts.text(kit, _readout, kit.fit("→ " + str(r["new"]), 2, width - lw2),
					Vector2(x + lw2, y), 2, MenuParts.LIT, Z)
			y += pitch + 2.0
			continue
		MenuParts.text(kit, _readout, r["label"], Vector2(x, y), 2, MenuParts.LIT_FAINT, Z)
		MenuParts.text(kit, _readout, r["old"], Vector2(old_right - kit.measure(r["old"], 2),
				y), 2, MenuParts.LIT_DIM, Z)
		MenuParts.text(kit, _readout, "→", Vector2(arrow_x, y), 2, MenuParts.LIT_FAINT, Z)
		MenuParts.text(kit, _readout, r["new"], Vector2(new_x, y), 2, MenuParts.LIT, Z)
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


## The one action, on its plate. In the rack it carries its control --
## ENTER, or the pad's A -- because that is what ENTER does there; from
## the keys it is the same plate without one (ENTER goes into the rack),
## and a click still takes it.
func _action_button(at: Vector2, words: String) -> void:
	var armed := zone == "drawer"
	var rect := Rect2(at, Vector2(kit.measure(words, 2) + (110.0 if armed else 24.0),
			ACT_H))
	var btn := MenuParts.slab(_readout, MenuParts.rrect(rect, 6), 0.0, 0.01,
			MenuParts.mat(MenuParts.ACT if armed else MenuParts.ACT.darkened(0.35), 0.1,
				0.6))
	kit.pickable("equipment", btn, "action")
	var x := rect.position.x + 12.0
	if armed:
		_prompt_cap(Vector2(COL_R + 6, at.y + 5), 0.01)
		x = COL_R + 94.0
	MenuParts.text(kit, _readout, words, Vector2(x, at.y + 10), 2,
			MenuKit.SIGNAL if armed else MenuParts.LIT_DIM, 0.0112)
	_info["action"] = rect
	_info["action_words"] = words
	_info["action_armed"] = armed


## The readout's own control, for the device in hand: ENTER, or the pad's
## south face button.
func _prompt_cap(at: Vector2, z: float) -> void:
	_info["cap"] = "pad_face_south" if kit.device == "pad" else "ENTER"
	if kit.device == "pad":
		MenuParts.sprite(kit, _readout, "pad_face_south", at + Vector2(20, 13), 2,
				MenuParts.INK, z + 0.002)
		return
	MenuParts.keycap(kit, _readout, "ENTER", at, z)


## THE ONE ACTION the readout offers for an item, in words; when it cannot
## be taken, the reason (Production's own sentences).
func _action(id: String) -> String:
	var slot := slot_of(key_index)
	var row: Dictionary = _by_id.get(id, {})
	if slot == "":
		return EquipmentQuery.refusal(row, "") if not row.is_empty() else ""
	var on := confirmed(slot)
	var blocker := ""
	if on != id:
		blocker = EquipmentQuery.refusal(row, slot)
		if blocker == "":
			blocker = EquipmentQuery.held_back(row)
	if blocker == "" and not BridgeClient.can_send():
		blocker = "OFFLINE: a change of equipment needs the bridge's answer."
	if blocker == "" and requests.is_pending(slot):
		blocker = "Waiting for the bridge's answer about %s." % _cap()
	if blocker != "":
		return blocker
	if on == id:
		return "TAKE OFF %s" % _cap()
	if str(_was.get(slot, "")) == id:
		return "PUT BACK ON %s" % _cap()
	if on == "":
		return "EQUIP ON %s" % _cap()
	return "REPLACE %s ON %s" % [_name(on), _cap()]


func _can_act(id: String) -> bool:
	var words := _action(id)
	return words.begins_with("TAKE OFF") or words.begins_with("PUT BACK") \
			or words.begins_with("EQUIP ON") or words.begins_with("REPLACE")


## Send the one action for `id`: equip, replace, put back or take off.
func _act(id: String) -> String:
	var slot := slot_of(key_index)
	if slot == "":
		return ""
	if confirmed(slot) == id:
		return _send(slot, null, "restore")
	var undo := str(_was.get(slot, "")) == id
	return _send(slot, id, "restore" if undo else "preview")


func _send(slot: String, component_id: Variant, cue: String) -> String:
	var state := requests.send(slot, component_id, BridgeClient.send_intent)
	note = ""
	kit.cue(cue if state == EquipRequests.PENDING else "refuse")
	_refresh_after_request()
	return state


## A request changed: the keys' windows, the rack's module windows and the
## readout say so. The rack's order, its scroll and its selection do not
## change.
func _refresh_after_request() -> void:
	if kit == null:
		return
	_build_keys()
	_build_rows()
	_compose()
	_build_notice()


# ============================================================ input

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
		_build_keys()
		_mark_rows()
		_compose()
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
	else:
		_compose()
	_build_keys()
	_mark_rows()


## Look at another key: the pointer turns one detent (or several, at once
## when motion is reduced), and the rack swaps to that key's modules.
func _focus_key(i: int, pointer := false) -> void:
	if i == key_index:
		return
	sel[key_index] = unfolded
	_more_first = 0
	key_index = i
	zone = "keys" if not pointer else zone
	kit.cue("detent", 1.0 + 0.05 * float(i))
	_build_keys(false)
	_open_rack()


## Select a module. Nothing in the rack moves but the module itself (and
## the rack scrolls a row only if the keyboard or pad asks for one out of
## view); the readout is rebuilt whole.
func _select(id: String, by_pointer := false) -> void:
	if id == unfolded:
		return
	unfolded = id
	sel[key_index] = id
	_more_first = 0
	kit.cue("tick")
	var was := _first
	if not by_pointer:
		_keep_in_view()
	if _first != was:
		_build_rows()
	else:
		_mark_rows()
	_compose()
	# A NEW sticker comes off what has been read.
	if _rows_drawn.has(id) and bool(_rows_drawn[id]["new"]) and not _is_new(id):
		_build_rows()
		_build_keys()


func accept() -> void:
	if zone == "keys":
		_enter_rack()
		return
	if unfolded == "":
		return
	if not _can_act(unfolded):
		kit.cue("refuse")
		return
	_act(unfolded)


## Back out: a search being typed ends; HISTORY closes; the rack gives the
## focus back to the keys. Whether there was anything to back out of.
func back() -> bool:
	if typing:
		stop_typing()
		return true
	if history_open:
		_toggle_history()
		return true
	if zone == "drawer":
		zone = "keys"
		kit.cue("tick", 0.75)
		_build_keys()
		_mark_rows()
		_compose()
		return true
	return false


## What the next Escape (or B) does here.
func back_words() -> String:
	if typing:
		return "stop typing"
	if history_open:
		return "close history"
	if zone == "drawer":
		return "keys"
	return "close"


func is_typing() -> bool:
	return typing


## The shell asks before it takes Q, E or Tab for a turn.
func typing_active() -> bool:
	return typing


func stop_typing() -> void:
	if not typing:
		return
	typing = false
	_build_tools()


func _start_typing() -> void:
	typing = true
	kit.cue("tick", 1.2)
	_build_tools()


func _toggle_history() -> void:
	if unfolded == "":
		kit.cue("edge")
		return
	history_open = not history_open
	_more_first = 0
	kit.cue("tick", 1.1 if history_open else 0.9)
	_compose()


func _toggle_favourite() -> void:
	var row: Dictionary = _by_id.get(unfolded, {})
	if row.is_empty() or not EquipmentQuery.is_slotted(row):
		kit.cue("edge")
		return
	Favourites.toggle(unfolded)
	kit.cue("toggle")
	_compose()


## The wall's own keys: a search being typed takes every letter (Q and E
## included); otherwise / starts one, S or the pad's X changes the sort,
## H or Y opens HISTORY, F marks the wheel's favourite, and Delete clears
## the key being looked at (a request, like any other).
func raw_input(event: InputEvent) -> bool:
	if typing:
		return _type(event)
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_SLASH, KEY_KP_DIVIDE:
				_start_typing()
			KEY_S:
				set_sort(sort_mode + 1)
				kit.cue("toggle")
			KEY_H:
				_toggle_history()
			KEY_F:
				_toggle_favourite()
			KEY_DELETE:
				if zone == "keys" and _can_clear(slot_of(key_index)):
					clear_slot(slot_of(key_index))
				else:
					kit.cue("edge")
			_:
				return false
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_X:
				set_sort(sort_mode + 1)
				kit.cue("toggle")
			JOY_BUTTON_Y:
				_toggle_history()
			_:
				return false
		return true
	return false


## Typing a search: letters and digits go in, Backspace takes one out,
## ENTER or DOWN ends it and reads the first match. Everything else a key
## does is swallowed: typing is not playing.
func _type(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return event is InputEventJoypadButton
	var key := event as InputEventKey
	if not key.pressed:
		return true
	match key.keycode:
		KEY_BACKSPACE:
			if search != "":
				set_search(search.substr(0, search.length() - 1))
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_DOWN:
			stop_typing()
			if not _order.is_empty():
				zone = "drawer"
				if not _order.has(unfolded):
					_select(_order[0])
				_build_keys()
				_mark_rows()
			return true
	if key.unicode >= 32 and search.length() < FIND_MAX:
		set_search(search + char(key.unicode))
	return true


## Hover lights, and never moves anything.
func hover(hit: Dictionary) -> void:
	var was := hovered
	hovered = str(hit.get("target", ""))
	if hovered != was:
		_mark_keys()
		_mark_rows()


func click(hit: Dictionary, button := MOUSE_BUTTON_LEFT) -> bool:
	if button != MOUSE_BUTTON_LEFT:
		return false
	var target := str(hit.get("target", ""))
	if target.begins_with("key:"):
		var i := int(target.trim_prefix("key:"))
		stop_typing()
		var was := zone
		zone = "keys"
		if i == key_index:
			_build_keys()
			_mark_rows()
			if was != zone:
				_compose()
		_focus_key(i, true)
		return true
	if target.begins_with("clear:"):
		clear_slot(slot_of(int(target.trim_prefix("clear:"))))
		return true
	if target.begins_with("row:"):
		stop_typing()
		var was := zone
		zone = "drawer"
		var id := target.trim_prefix("row:")
		if id == unfolded and was != zone:
			_compose()
		_select(id, true)
		_build_keys()
		_mark_rows()
		return true
	match target:
		"action":
			stop_typing()
			if unfolded != "" and _can_act(unfolded):
				_act(unfolded)
			else:
				kit.cue("refuse")
			return true
		"find":
			if not typing:
				_start_typing()
			return true
		"find_clear":
			set_search("")
			kit.cue("tick", 0.9)
			return true
		"sort":
			set_sort(sort_mode + 1)
			kit.cue("toggle")
			return true
		"history":
			_toggle_history()
			return true
		"favourite":
			_toggle_favourite()
			return true
		"track":
			var pos: Vector3 = hit.get("point", Vector3.ZERO)
			var knob_y := _knob.global_position.y
			_hand_scroll(SHOWN if pos.y < knob_y else -SHOWN)
			return true
	return false


## The wheel: over the rack it scrolls a row a notch; over the selector it
## turns it a detent -- the ordinary selection, not a drag; over the
## window in HISTORY, it scrolls the history.
func wheel(hit: Dictionary, dir: int) -> bool:
	var target := str(hit.get("target", ""))
	if target.begins_with("row:") or target in ["rack", "track"]:
		_hand_scroll(dir)
		return true
	if target.begins_with("key:") or target == "dial":
		var to := clampi(key_index + dir, 0, key_count() - 1)
		if to == key_index:
			kit.cue("edge")
		else:
			_focus_key(to, true)
		return true
	if target == "readout" and history_open:
		_more_scroll(dir)
		return true
	return false


func _more_scroll(dir: int) -> void:
	var was := _more_first
	_more_first = maxi(0, _more_first + dir)
	_compose()
	if int(_info.get("more_first", was)) == was:
		kit.cue("edge")
	else:
		kit.cue("scroll")


## The right stick: the same hand scroll as the wheel, a row at a time as
## the stick's travel adds up (the history, when it is open).
func scroll_by(px: float) -> void:
	if zone != "drawer" and not history_open:
		return
	_stick_px += px
	while absf(_stick_px) >= ROW_PITCH:
		var dir := signi(int(signf(_stick_px)))
		_stick_px -= ROW_PITCH * float(dir)
		if history_open:
			_more_scroll(dir)
		elif not _hand_scroll(dir):
			_stick_px = 0.0
			break


## Scrolling by hand moves the rack whole rows under its window; the
## selection stays selected, pulled, and read -- even out of view.
func _hand_scroll(dir: int) -> bool:
	var to := clampi(_first + dir, 0, _max_first())
	if to == _first:
		kit.cue("edge")
		return false
	_first = to
	anchor[key_index] = str(_order[_first])
	kit.cue("scroll")
	_build_rows(false)
	return true


func prompts() -> Array:
	if typing:
		return [["accept", "search"]]
	if zone == "keys":
		var out := [["move", "keys"], ["into", "the rack"], ["click", "pick"]]
		if _can_clear(slot_of(key_index)):
			out.append(["clear", "clear %s" % _cap()])
		return out
	var out := [["move", "items"]]
	if unfolded != "" and _can_act(unfolded):
		out.append(["accept", _action(unfolded).to_lower()])
	out += [["out", "keys"], ["wheel", "scroll"]]
	return out


# ============================================================ the shell's calls

func on_open(is_front: bool) -> void:
	_front = is_front
	if is_front and unfolded != "" and _is_new(unfolded):
		_compose()


func on_close() -> void:
	close()


func on_front(is_front: bool) -> void:
	_front = is_front
	if not is_front:
		stop_typing()
	elif unfolded != "" and _is_new(unfolded):
		_compose()


## The device changed: the controls drawn on the cabinet are redrawn for it.
func on_device() -> void:
	if kit == null:
		return
	_build_tools()
	_compose()


func focus_lost() -> void:
	_stick_px = 0.0


func tick(_delta: float) -> void:
	pass


# ============================================================ signals

func _on_snapshot(snapshot: Dictionary) -> void:
	# The requests are answered whether or not the wall is showing: an
	# equip made just before closing lands after it.
	var slots: Variant = snapshot.get("slots")
	var before := {}
	for slot: String in Constants.SLOT_NAMES:
		before[slot] = confirmed_before(slot)
	var resolved := requests.on_snapshot(slots if typeof(slots) == TYPE_DICTIONARY
			else {})
	for slot: Variant in resolved:
		# What the key held before the change is the undo, for this visit.
		var was := str(before.get(str(slot), ""))
		if was != "":
			_was[str(slot)] = was
		else:
			_was.erase(str(slot))
		if kit != null:
			kit.cue("toggle", 1.2)
	_last_slots = (slots as Dictionary).duplicate() if typeof(slots) == TYPE_DICTIONARY \
			else {}
	if _open:
		rebuild()


## The confirmed occupant before this snapshot landed.
var _last_slots := {}


func confirmed_before(slot: String) -> String:
	var holds: Variant = _last_slots.get(slot)
	return "" if holds == null else str(holds)


func _on_bridge_error(err: Dictionary) -> void:
	var slot := requests.on_error(err)
	if slot == "":
		# NOT ATTRIBUTED. Empty `about` means unchecked; it is shown as the
		# bridge's own latest refusal and resolves nothing here.
		_unattributed = str(err.get("message", ""))
		if kit != null:
			_build_notice()
		return
	if kit != null:
		kit.cue("refuse")
		_refresh_after_request()


func _on_link(online: bool) -> void:
	if not online:
		requests.on_link_lost()
	if kit != null:
		_refresh_after_request()
		_build_tools()


# ============================================================ state

## Everything a suite asserts on, and nothing it could not see.
func state() -> Dictionary:
	var windows := []
	for e: Dictionary in _keys:
		windows.append(str(e["words"]))
	var holds := []
	for e: Dictionary in _keys:
		holds.append(str(e.get("holds", "")))
	var shown := []
	var words := {}
	var out := []
	var stands := {}
	var fresh := []
	for id: String in _rows_drawn:
		shown.append(id)
		words[id] = _rows_drawn[id]["words"]
		if (_rows_drawn[id]["node"] as Node3D).position.length() > 0.0001:
			out.append(id)
		if str(_rows_drawn[id]["stands"]) != "":
			stands[id] = _rows_drawn[id]["stands"]
		if bool(_rows_drawn[id]["new"]):
			fresh.append(id)
	var at := _order.find(unfolded)
	return {"key": key_index, "slot": slot_of(key_index), "zone": zone,
		"unfolded": unfolded, "order": _order.duplicate(), "count": _order.size(),
		"total": _total, "first": _first, "shown": shown, "hover": hovered,
		"note": note, "windows": windows, "holds": holds, "stands": stands,
		"new": fresh, "out": out, "row_words": words, "search": search,
		"typing": typing, "sort": sort_label(), "history_open": history_open,
		"pointer_to": snappedf(-_angle(key_index), 0.0001),
		"pointer_at": snappedf(_pivot.rotation.z, 0.0001) if _pivot != null else 0.0,
		"card_inside": at >= _first and at < _first + SHOWN,
		"focus": _info.duplicate(), "notice": _notice_lines(),
		"more": ["%d MORE ABOVE" % int(_info_more[0]) if int(_info_more[0]) > 0
			else "", "%d MORE BELOW" % int(_info_more[1]) if int(_info_more[1]) > 0
			else ""],
		"compositions": _live_compositions(),
		"text_scale_min": _text_scale_min()}


func _notice_lines() -> Array:
	var out := []
	if _notice == null:
		return out
	for n: Node in _notice.find_children("*", "Label3D", true, false):
		if not n.is_queued_for_deletion() and not n.get_parent().is_queued_for_deletion():
			out.append((n as Label3D).text)
	return out


## How many readouts are on the wall right now: one, or the old and the new
## are overlapping.
func _live_compositions() -> int:
	var n := 0
	for c: Node in face.get_children():
		if c is Node3D and c.get_meta("composition", false) \
				and not c.is_queued_for_deletion():
			n += 1
	return n


## The smallest vertical scale any word on this wall is drawn at, relative to
## its own: 1.0 means no text anywhere is squashed.
func _text_scale_min() -> float:
	var least := 1.0
	var stack: Array = [face]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label3D and (n as Label3D).is_visible_in_tree() \
				and not n.is_queued_for_deletion():
			var s := (n as Node3D).global_transform.basis.get_scale().y
			least = minf(least, s / maxf(0.0001, _own_scale(n as Node3D)))
		stack.append_array(n.get_children())
	return snappedf(least, 0.001)


static func _own_scale(n: Node3D) -> float:
	var s := 1.0
	var at: Node = n
	while at != null:
		if at is Node3D:
			s *= float(at.get_meta("own_scale", 1.0))
		at = at.get_parent()
	return s
