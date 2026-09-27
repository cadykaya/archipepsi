class_name FaceEquipment
extends RefCounted
## EQUIPMENT (the Inventory): LEAF, art-directed as ROUTE AND ECHO.
##
## The shape language is taken from what an Archipepsi ability IS: an item
## from another world, read into this one, and carried on a key.
##
## * RELATIONS RUN ON THE ROUTE. One stroke, with 45-degree corners, runs
##   from the key you press, down the drawer's rail to the selected item,
##   and under that item's name at full size. It is the comparison made
##   visible: from what is on the key to what you are looking at. It
##   carries the movement; the words hold still.
## * AN ECHO REPEATS. The selected item's name is set large, and behind it
##   lie its echoes: one for every item that went into it (its Mk),
##   stepped back along the diagonal toward the rail it came from.
## * INFORMATION STAYS SQUARE. Everything you read is level, aligned and at
##   the face's own sizes; only relations take the diagonal.
##
## Down the left, the LOADOUT: Production's five keys (SLOT_NAMES, with the
## bindings SlotKeycaps names), each with what is seated on it, and ALWAYS
## ON -- passives take no key. The focused key's candidates stand on the
## RAIL in a fixed order (the save's occupant first). A preview never
## reorders them and selecting never moves them, so a mouse target holds
## still. The selected item's detail UNFOLDS FROM IT, along the route, into
## the composition on the right: its name and echoes, how it was read and
## where it came from, what it does, and the comparison with what is on its
## key NOW (Production's own lines, EquipmentQuery.comparison), aligned.
##
## Equipping is a LOCAL PREVIEW, labelled: it re-seats the key on this wall
## and nowhere else (no request, no save). Production's equip is a request
## with states; the preview says NOT SENT, which is one of them.

# ---- the loadout
const LOAD_X := 48.0
const LOAD_W := 232.0
const ROW_Y0 := 108.0
const ROW_PITCH := 70.0
const ALWAYS_Y := 468.0
const KEY_SHELF := 56.0          # a key row's shelf, below its top
# ---- the rail
const RAIL_X := 314.0            # the spine
const NAME_X := 334.0            # a station's words
const NAME_W := 222.0
const VIEW_TOP := 150.0
const VIEW_BOTTOM := 684.0
const STATION := 50.0            # the rail's pitch
const SHELF := 42.0              # a station's shelf, below its top
# ---- the composition
const GUTTER_X := 590.0          # where the route rises, under the echoes
const FOCUS_X := 612.0
const FOCUS_W := 620.0
const KICKER_Y := 88.0
const NAME_TOP := 130.0
const ACTION_Y := 636.0
const COL_L_W := 262.0
const COL_R := 900.0
const COL_R_W := 332.0
const LINE := 20.0
# ---- the route
const STROKE := 6.0
const CORNER := 10.0
const ROUTE_LIFT := 0.05         # in front of the rail's edges, seen in place
## THE NAME PLATE and its ECHOES. The name is printed on a plate of the
## keycaps' own material -- the thing you put on a key -- standing off the
## wall; behind it, one plate for every item that went into it (its Mk),
## each a step further down the diagonal and nearer the wall, fading to
## the wall's own grey. A frozen frame shows what the ability is, and how
## many things made it.
const PLATE_TONE := Color("#d3d9e2")
const ECHO_TONES := [Color("#8f98a7"), Color("#606978"), Color("#434a57"),
	Color("#323843")]
const PLATE_Z := 0.1             # the plate's face, off the wall
const ECHO_DZ := 0.011           # each echo that much nearer the wall
const ECHO_STEP := 12.0          # ... and that far down the diagonal, page px
const PLATE_T := 0.006           # a plate's thickness
const MOUSE_SYMBOL := {"RMB": "mouse_right", "MMB": "mouse_middle",
	"LMB": "mouse_left"}


## The route's moving parts, page px. `go()` glides them; the mesh is
## rebuilt from them whenever they change.
class RouteState:
	extends RefCounted
	var key_y := 0.0             # the focused key's shelf
	var sel_y := 0.0             # the selected station's shelf, held to the view
	var name_y := 0.0            # the name's underline
	var name_w := 0.0            # ... and its length


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
var note := ""                # a transient line (preview done)

var _loadout: Node3D
var _rows := []               # per key row: {ground, name, tag, y}
var _focus_bar: MeshInstance3D
var _drawer: Node3D
var _list: Node3D
var _strips := {}             # id -> {node, ground, y, h, name}
var _order: Array = []        # ids on the rail, in order
var _more_up: Node3D
var _more_down: Node3D
var _spine: MeshInstance3D
var _scroll_px := 0.0
var _focus: Node3D            # the composition for the selected item
var _focus_info := {}         # what the composition drew (for state())
var _echoes: Array = []       # the echo copies' nodes
var _route: MeshInstance3D
var _route_parts: Node3D      # its terminals and the focus mark
var _rs := RouteState.new()
var _route_sig := ""


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("equipment")
	_route = MeshInstance3D.new()
	_route.material_override = kit.flat(Kit.INK)
	_route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(_route)


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
	return saved(slot)


func saved(slot: String) -> String:
	for key: Dictionary in keys():
		if str(key["slot"]) == slot:
			var holds: Variant = (key["view"] as Dictionary).get("holds")
			return "" if holds == null else str(holds)
	return ""


## The rail's items for a key: what the SAVE has on it first, then the rest
## in the fold's own order. A preview never reorders the rail -- the item
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


# ------------------------------------------------------------ the loadout

func _row_y(i: int) -> float:
	return ROW_Y0 + ROW_PITCH * i if i < keys().size() else ALWAYS_Y


func _build_loadout() -> void:
	if _loadout != null:
		_loadout.queue_free()
	_loadout = Node3D.new()
	face.add_child(_loadout)
	_rows.clear()
	for i in key_count():
		var y := _row_y(i)
		var ground := kit.card(_loadout, Vector2(LOAD_X - 12, y - 10),
				Vector2(LOAD_W + 24, KEY_SHELF + 16), 0.002, kit.own(Kit.PLATE, 0.0))
		var row := {"ground": ground, "y": y}
		if i < keys().size():
			var key: Dictionary = keys()[i]
			var w := _keycap(_loadout, str(key["keycap"]), Vector2(LOAD_X, y))
			kit.label(_loadout, str(key["title"]), Vector2(LOAD_X + w + 12, y + 5),
					2, Kit.INK_FAINT)
		else:
			kit.label(_loadout, "ALWAYS ON", Vector2(LOAD_X, y + 5), 2,
					Kit.INK_FAINT)
			kit.label(_loadout, "NOT A SWITCH", Vector2(LOAD_X + LOAD_W
					- kit.measure("NOT A SWITCH", 2), y + 5), 2, Kit.INK_FAINT)
		# Every key stands on a shelf; the focused one's is the route.
		kit.card(_loadout, Vector2(LOAD_X, y + KEY_SHELF - 1), Vector2(LOAD_W, 2),
				0.002, kit.flat(Kit.DEAD))
		_rows.append(row)
		_row_text(i)
	_focus_bar = kit.card(_loadout, Vector2(LOAD_X - 20, 0), Vector2(5,
			KEY_SHELF + 6), 0.004, kit.own(Kit.SIGNAL))
	_place_focus_bar(true)


## The keycap as the Glyph kit draws one, set into the wall: the binding's
## own name (SlotKeycaps), and for a mouse button its device symbol too.
## Returns its width.
func _keycap(parent: Node3D, cap: String, at: Vector2) -> float:
	var up := cap.to_upper()
	var w := maxf(40.0, kit.measure(up, 2) + 16.0)
	if MOUSE_SYMBOL.has(up):
		w = 66.0
	kit.shadow(parent, at, Vector2(w, 26), 0.35)
	kit.plate(parent, at, Vector2(w, 26), 0.001, kit.lit(Color("#c9d0db")),
			0.004)
	if MOUSE_SYMBOL.has(up):
		kit.sprite(parent, MOUSE_SYMBOL[up], at + Vector2(14, 13), 2,
				Kit.SHADE, 0.0065)
		kit.label(parent, up, at + Vector2(28, 5), 2, Kit.SHADE, 0.0065)
	else:
		kit.label(parent, up, at + Vector2(8, 5), 2, Kit.SHADE, 0.0065)
	return w


func _row_text(i: int) -> void:
	var row: Dictionary = _rows[i]
	for key in ["name", "tag"]:
		if row.has(key) and is_instance_valid(row[key]):
			(row[key] as Node).queue_free()
		row.erase(key)
	var y: float = row["y"]
	if i >= keys().size():
		var names := []
		for id: String in candidates(i):
			names.append(_name(id))
		row["name"] = kit.label(_loadout, kit.fit(", ".join(names), 2, LOAD_W),
				Vector2(LOAD_X, y + 34), 2, Kit.INK_DIM)
		return
	var slot := slot_of(i)
	var on := seated(slot)
	if on == "":
		row["name"] = kit.label(_loadout, "EMPTY", Vector2(LOAD_X, y + 34), 2,
				Kit.INK_FAINT)
	else:
		row["name"] = kit.label(_loadout, kit.fit(_name(on), 2, LOAD_W),
				Vector2(LOAD_X, y + 34), 2, Kit.INK)
		if preview.has(slot):
			row["tag"] = kit.label(_loadout, "PREVIEW",
					Vector2(LOAD_X + LOAD_W - kit.measure("PREVIEW", 2), y + 5),
					2, Kit.INK)


## The keys' focus: a SIGNAL bar beside the focused key while the keys have
## the focus; in the rail, the focus is the mark on the selected station.
func _place_focus_bar(at_once := false) -> void:
	var y: float = _rows[key_index]["y"] - 6.0
	var to := Kit.at(Vector2(LOAD_X - 20 + 2.5, y + (KEY_SHELF + 6) * 0.5), 0.004)
	if at_once:
		_focus_bar.position = to
	else:
		kit.go(_focus_bar, "position", to, 0.14, "out")
	kit.go(_focus_bar.material_override, "albedo_color",
			Color(Kit.SIGNAL, 1.0 if zone == "keys" else 0.0), 0.1)
	for i in _rows.size():
		var ground: MeshInstance3D = _rows[i]["ground"]
		var a := 0.55 if hover == "key:%d" % i and i != key_index else 0.0
		kit.go(ground.material_override, "albedo_color", Color(Kit.PLATE, a), 0.12)


# ------------------------------------------------------------ the rail

## The focused key's rail: its stations appear down the spine from the
## route's arrival, and the route re-runs to the new key.
func _open_drawer(at_once := false) -> void:
	if _drawer != null:
		_drawer.queue_free()
	_drawer = Node3D.new()
	face.add_child(_drawer)
	_strips.clear()
	_order = candidates(key_index)
	var slot := slot_of(key_index)
	var head := "WHAT GOES ON %s" % _cap() if slot != "" \
			else "ALWAYS ON WHILE YOU OWN IT"
	_over(kit.label(_drawer, head, Kit.lifted(Vector2(NAME_X, VIEW_TOP - 40),
			ABOVE_CLIP), 2, Kit.INK_FAINT, ABOVE_CLIP))
	var count := "%d" % _order.size()
	_over(kit.label(_drawer, count, Kit.lifted(Vector2(NAME_X + NAME_W
			- kit.measure(count, 2, true), VIEW_TOP - 40), ABOVE_CLIP), 2,
			Kit.INK_FAINT, ABOVE_CLIP, true))
	_list = Node3D.new()
	_drawer.add_child(_list)
	for i in _order.size():
		_strip(_order[i], i)
	# The spine: one thin line from the first station's shelf to the last,
	# held to the rail's view (_update_spine, every frame, as the rail moves).
	_spine = kit.card(_drawer, Vector2(RAIL_X - 1, VIEW_TOP), Vector2(2, 2), 0.0028,
			kit.flat(Kit.DEAD))
	_clip()
	_more_up = _more(true)
	_more_down = _more(false)
	# Which item is selected: the key remembers its own; a key with
	# something on it opens on that, the rest on nothing until entered.
	var remembered: String = sel.get(key_index, "")
	if remembered == "" or not _order.has(remembered):
		remembered = seated(slot) if slot != "" else ""
	unfolded = remembered
	_scroll_px = float(scroll.get(key_index, 0.0))
	_layout(true)
	_compose()
	var key_y: float = _rows[key_index]["y"] + KEY_SHELF
	if at_once or kit.reduced:
		_rs.key_y = key_y
	else:
		kit.go(_rs, "key_y", key_y, 0.16, "out")
		# The stations come down the spine behind the route: each appears
		# whole as the drawer reaches it -- nothing is scaled or squashed.
		for i in _order.size():
			var node: Node3D = _strips[_order[i]]["node"]
			if node.visible:
				node.visible = false
				kit.later(0.02 + 0.016 * mini(i, 12), func() -> void:
					if is_instance_valid(node):
						node.visible = _strip_shows(_order.find(_id_of(node))))
	_aim_route(at_once)


func _id_of(node: Node3D) -> String:
	return str(node.get_meta("id", ""))


func _strip(id: String, i: int) -> void:
	var node := Node3D.new()
	node.set_meta("id", id)
	_list.add_child(node)
	var ground := kit.card(node, Vector2(10, -6), Vector2(NAME_X + NAME_W + 8
			- RAIL_X - 10, SHELF + 4), 0.002, kit.own(Kit.PLATE, 0.0), true)
	# The station: a tick across the spine at its shelf.
	kit.card(node, Vector2(-7, SHELF - 1.5), Vector2(14, 3), 0.003,
			kit.flat(Kit.DEAD), true)
	var slot := slot_of(key_index)
	var name := kit.label(node, kit.fit(_name(id), 2, NAME_W),
			Vector2(NAME_X - RAIL_X, 0), 2, Kit.INK_DIM, 0.004, false, true)
	# Its second line: the Mk, and what the review must say about it.
	var tags := [_mk(id)]
	var bright := false
	if slot != "" and seated(slot) == id:
		tags.append("PREVIEW, NOT SENT" if preview.has(slot) else "ON " + _cap())
		bright = true
	elif slot != "" and preview.has(slot) and saved(slot) == id:
		tags.append("SAVED ON " + _cap())
	var row: Dictionary = items[id]
	if bool(row.get("consumable", false)) and row.get("charges_max") != null:
		tags.append("%d/%d" % [int(row["charges_left"]), int(row["charges_max"])])
	if _authored(id):
		tags.append("AUTHORED")
	kit.label(node, kit.fit(" · ".join(tags), 2, NAME_W), Vector2(NAME_X - RAIL_X,
			20), 2, Kit.INK if bright else Kit.INK_FAINT, 0.004, false, true)
	if bright:
		# What is on the key now: a solid node on the spine.
		kit.card(node, Vector2(-6, SHELF - 6), Vector2(12, 12), 0.0035,
				kit.flat(Kit.INK), true)
	_strips[id] = {"node": node, "ground": ground, "y": STATION * i,
		"h": STATION, "name": name}


## The rail's window edges: two patches of the wall laid just in front of the
## rail, above VIEW_TOP and below VIEW_BOTTOM. A station partly scrolled out
## of view slides UNDER them and stays drawn where it shows -- it never
## vanishes whole and leaves a hole.
const CLIP_LIFT := 0.045              # in front of everything on the rail
const ABOVE_CLIP := 0.055             # the rail's own words, over the edges
const CLIP_TOP := 50.0                # the top edge's height: a station and more


func _clip() -> void:
	var x0 := RAIL_X - 12.0
	var x1 := NAME_X + NAME_W + 12.0
	for r: Rect2 in [Rect2(Vector2(x0, VIEW_TOP - CLIP_TOP), Vector2(x1 - x0,
				CLIP_TOP)), Rect2(Vector2(x0, VIEW_BOTTOM), Vector2(x1 - x0,
				Kit.PAGE.y - VIEW_BOTTOM))]:
		var k := Kit.lift_scale(CLIP_LIFT)
		var edge := kit.card(_drawer, Kit.lifted(r.position, CLIP_LIFT), r.size * k,
				CLIP_LIFT, kit.wall_patch(r))
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One of the rail's own words, over its edges: shrunk by its lift so it is
## seen at its page size, where it would be on the wall.
func _over(node: Node3D) -> void:
	node.scale = Vector3.ONE * Kit.lift_scale(ABOVE_CLIP)
	node.set_meta("own_scale", Kit.lift_scale(ABOVE_CLIP))


func _more(up: bool) -> Node3D:
	var node := Node3D.new()
	_drawer.add_child(node)
	var y := VIEW_TOP - 18 if up else VIEW_BOTTOM + 12
	var cx := NAME_X + NAME_W * 0.5
	_over(kit.sprite(node, "arrow_up" if up else "arrow_down", Kit.lifted(
			Vector2(cx - 40, y + 6), ABOVE_CLIP), 2, Kit.INK_DIM, ABOVE_CLIP))
	var l := kit.label(node, "", Kit.lifted(Vector2(cx - 24, y - 2), ABOVE_CLIP),
			2, Kit.INK_DIM, ABOVE_CLIP)
	_over(l)
	node.set_meta("label", l)
	node.visible = false
	return node


## Where every station stands, and the scroll that keeps the selected one in
## view (keyboard and pad; a hand scroll moves only the rail). Stations
## never move when the selection moves -- only when the rail scrolls.
func _layout(at_once := false, by_hand := false) -> void:
	var total := STATION * _order.size()
	var view := VIEW_BOTTOM - VIEW_TOP
	if unfolded != "" and _strips.has(unfolded) and not by_hand:
		var top: float = _strips[unfolded]["y"]
		var bottom: float = top + STATION
		if top < _scroll_px:
			_scroll_px = top
		elif bottom > _scroll_px + view:
			_scroll_px = bottom - view
	_scroll_px = clampf(_scroll_px, 0.0, maxf(0.0, total - view))
	scroll[key_index] = _scroll_px
	for i in _order.size():
		var s: Dictionary = _strips[_order[i]]
		var node: Node3D = s["node"]
		var to := Kit.at(Vector2(RAIL_X, VIEW_TOP + float(s["y"]) - _scroll_px), 0.0)
		if at_once:
			node.position = to
		else:
			kit.go(node, "position", to, 0.18, "out")
		node.visible = _strip_shows(i)
	var above := 0
	var below := 0
	for id: String in _order:
		var page_y: float = VIEW_TOP + float(_strips[id]["y"]) - _scroll_px
		if page_y < VIEW_TOP - 1.0:
			above += 1
		elif page_y + STATION > VIEW_BOTTOM + 1.0:
			below += 1
	_set_more(_more_up, above)
	_set_more(_more_down, below)
	_mark_strips()


## A station is drawn wherever any of it shows; the rail's edges cover the
## rest -- so long as all of it stays within their reach.
func _strip_shows(i: int) -> bool:
	if i < 0 or i >= _order.size():
		return false
	var page_y: float = VIEW_TOP + float(_strips[_order[i]]["y"]) - _scroll_px
	return page_y < VIEW_BOTTOM and page_y + STATION > VIEW_TOP \
			and page_y >= VIEW_TOP - CLIP_TOP and page_y + STATION <= Kit.PAGE.y


func _set_more(node: Node3D, n: int) -> void:
	node.visible = n > 0
	var l: Label3D = node.get_meta("label")
	l.text = kit.display("%d MORE" % n)


## Grounds: a hovered station gets a faint ground -- light only, never
## movement. The selected one's name is lit; the route is under it.
func _mark_strips() -> void:
	for id: String in _order:
		var s: Dictionary = _strips[id]
		var ground: MeshInstance3D = s["ground"]
		var a := 0.6 if id == hover and id != unfolded else 0.0
		kit.go(ground.material_override, "albedo_color", Color(Kit.PLATE, a), 0.1)
		(s["name"] as Label3D).modulate = Kit.INK if id == unfolded else Kit.INK_DIM


# ------------------------------------------------------------ the route

## Point the route at what is selected now: the station's shelf (held to the
## rail's view -- past its edge the route turns at the edge), the name's
## underline, and its length.
func _aim_route(at_once := false) -> void:
	var sy := VIEW_TOP - 8.0
	if unfolded != "" and _strips.has(unfolded):
		var page_y: float = VIEW_TOP + float(_strips[unfolded]["y"]) - _scroll_px
		sy = clampf(page_y + SHELF, VIEW_TOP - 8.0, VIEW_BOTTOM + 6.0)
	var ny: float = _focus_info.get("underline", NAME_TOP + 24.0)
	var plate: Rect2 = _focus_info.get("plate", Rect2(FOCUS_X, NAME_TOP, 1, 1))
	var nw: float = plate.position.x + 24.0     # into the plate, under it
	if at_once or kit.reduced:
		_rs.sel_y = sy
		_rs.name_y = ny
		_rs.name_w = nw
		return
	kit.go(_rs, "sel_y", sy, 0.14, "out")
	kit.go(_rs, "name_y", ny, 0.14, "out")
	kit.go(_rs, "name_w", nw, 0.18, "out")


## The route's points, page px, before its corners are cut.
func route_points() -> Array:
	return [Vector2(LOAD_X, _rs.key_y), Vector2(RAIL_X, _rs.key_y),
		Vector2(RAIL_X, _rs.sel_y), Vector2(GUTTER_X, _rs.sel_y),
		Vector2(GUTTER_X, _rs.name_y), Vector2(_rs.name_w, _rs.name_y)]


func _draw_route() -> void:
	var sig := "%.2f/%.2f/%.2f/%.2f/%s" % [_rs.key_y, _rs.sel_y, _rs.name_y,
		_rs.name_w, zone]
	if sig == _route_sig:
		return
	_route_sig = sig
	_route.mesh = Kit.route_mesh(Kit.route_corners(route_points(), CORNER),
			STROKE, ROUTE_LIFT)
	if _route_parts != null:
		_route_parts.queue_free()
	_route_parts = Node3D.new()
	face.add_child(_route_parts)
	# The rail's focus: the selected station's mark, on the route, while the
	# rail has the focus.
	if zone == "drawer" and unfolded != "":
		kit.lifted_card(_route_parts, Vector2(RAIL_X - 8, _rs.sel_y - 8),
				Vector2(16, 16), ROUTE_LIFT + 0.001, kit.flat(Kit.SIGNAL))


# ------------------------------------------------------------ the composition

## The selected item, composed: built whole and at once -- the words never
## scale or slide; the route and the echoes carry the movement.
func _compose() -> void:
	if _focus != null:
		_focus.queue_free()
	_focus = Node3D.new()
	_focus.set_meta("composition", true)
	face.add_child(_focus)
	_echoes.clear()
	_focus_info = {}
	if unfolded == "":
		_compose_key()
	else:
		_compose_item(unfolded)


## Nothing selected: the key itself, in the same composition.
func _compose_key() -> void:
	var slot := slot_of(key_index)
	var title := str(keys()[key_index]["title"]) if slot != "" else "ALWAYS ON"
	var fit := _name_fit(title)
	var bottom := _big_name(fit, 0)
	var y := bottom + 22.0
	var words := []
	if slot != "":
		var on := seated(slot)
		words.append("NOTHING IS ON %s NOW." % _cap() if on == ""
				else "%s IS ON %s NOW." % [_name(on), _cap()])
	words.append("%d ITEMS GO HERE. MOVE INTO THE RAIL TO CHOOSE ONE." % _order.size()
			if not _order.is_empty() else "NOTHING YOU HOLD GOES HERE.")
	for w: String in words:
		for line in kit.wrap(w, 2, FOCUS_W):
			kit.label(_focus, line, Vector2(FOCUS_X, y), 2, Kit.INK_DIM)
			y += LINE
	_focus_info["bottom"] = y
	_focus_info["clear"] = _clear(y)


## Whether the composition keeps to its place: everything above the action
## row, the plate and its echoes inside the wall.
func _clear(bottom: float) -> bool:
	var plate: Rect2 = _focus_info.get("plate", Rect2())
	var reach := minf(ECHO_STEP * float(_focus_info.get("echoes", 0)), 36.0)
	var stack := plate.grow_individual(reach, 0, 0, reach)
	return bottom <= ACTION_Y - 8.0 and stack.position.x > GUTTER_X - 40.0 \
			and stack.end.x <= Kit.PAGE.x - 40.0 and stack.position.y > KICKER_Y + 16.0


## The largest size the name can take in two lines (three, at the smallest):
## a long name wraps rather than shrinking below 4x.
func _name_fit(text: String) -> Array:
	for k: int in [6, 5]:
		var lines := kit.wrap(text, k, FOCUS_W)
		if lines.size() <= 2:
			return [k, lines]
	for k: int in [4, 3]:
		var lines := kit.wrap(text, k, FOCUS_W)
		if lines.size() <= 3:
			return [k, lines]
	return [3, kit.wrap(text, 3, FOCUS_W)]


## The name on its plate, and the plate's echoes behind it; returns the y
## the composition goes on from. The route plugs into the plate's left edge.
func _big_name(fit: Array, echoes: int) -> float:
	var k: int = fit[0]
	var lines: PackedStringArray = fit[1]
	var pitch := 8.0 * k + 8.0
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, kit.measure(line, k))
	var pad := Vector2(2.0 * k + 4.0, 2.0 * k)
	var text_h := pitch * lines.size() - 8.0 - k   # the last line's descent
	var rect := Rect2(Vector2(FOCUS_X, NAME_TOP) - pad, Vector2(widest, text_h)
			+ pad * 2.0)
	_plate(_focus, rect, PLATE_Z, PLATE_TONE)
	for i in lines.size():
		_lifted_label(_focus, lines[i], Vector2(FOCUS_X, NAME_TOP + pitch * i), k,
				Kit.SHADE, PLATE_Z + 0.0008)
	# The echoes: a plate each, stepped back down the diagonal toward the
	# rail and toward the wall. Each is a node of its own, so it can slide
	# out from behind the plate when the name arrives.
	var n := mini(echoes, ECHO_TONES.size())
	var step := minf(ECHO_STEP, 36.0 / maxf(1.0, float(n)))
	for e in n:
		var copy := Node3D.new()
		_focus.add_child(copy)
		var z := PLATE_Z - ECHO_DZ * (e + 1)
		var off := Vector2(-step, step) * (e + 1)
		_plate(copy, Rect2(rect.position + off, rect.size), z, ECHO_TONES[e])
		# Behind the plate, where the echo was when it left: the slide.
		copy.set_meta("rest", Vector3.ZERO)
		copy.set_meta("from", -Kit.rel(off * Kit.lift_scale(z), 0.0))
		_echoes.append(copy)
	_focus_info["name_k"] = k
	_focus_info["name_lines"] = lines.size()
	_focus_info["name_w"] = widest
	_focus_info["plate"] = rect
	_focus_info["underline"] = rect.get_center().y
	_focus_info["echoes"] = _echoes.size()
	return rect.end.y + step * n


## A plate SEEN at `rect` (page px), its face `z` off the wall: a lit box
## that shades what is behind it.
func _plate(parent: Node3D, rect: Rect2, z: float, colour: Color) -> MeshInstance3D:
	var k := Kit.lift_scale(z)
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x * Kit.px() * k, rect.size.y * Kit.px() * k,
			PLATE_T)
	node.mesh = box
	node.material_override = kit.lit(colour)
	node.position = Kit.at(Kit.lifted(rect.get_center(), z), z - PLATE_T * 0.5)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


## Words SEEN at `page`, `z` off the wall (on a plate).
func _lifted_label(parent: Node3D, text: String, page: Vector2, k: int,
		colour: Color, z: float) -> Label3D:
	var l := kit.label(parent, text, Kit.lifted(page, z), k, colour, z)
	l.scale = Vector3.ONE * Kit.lift_scale(z)
	l.set_meta("own_scale", Kit.lift_scale(z))
	return l


func _compose_item(id: String) -> void:
	var row: Dictionary = items[id]
	var slot := slot_of(key_index)
	var on := seated(slot) if slot != "" else ""
	# The kicker: the key itself, as the Glyph kit draws it, and where this
	# item stands with it; and what kind of thing it is.
	var stands := "ALWAYS ON · NO KEY"
	var bright := false
	var sx := FOCUS_X
	if slot != "":
		sx += _keycap(_focus, str(keys()[key_index]["keycap"]), Vector2(FOCUS_X,
				KICKER_Y - 5)) + 12.0
		if on == id:
			stands = "PREVIEW ON THIS KEY, NOT SENT" if preview.has(slot) \
					else "ON THIS KEY NOW"
			bright = true
		elif preview.has(slot) and saved(slot) == id:
			stands = "SAVED ON THIS KEY"
		else:
			stands = "FITS THIS KEY"
	kit.label(_focus, stands, Vector2(sx, KICKER_Y), 2,
			Kit.INK if bright else Kit.INK_DIM)
	var kind := "%s · %s" % [str(row.get("family", "")), _mk(id)]
	kit.label(_focus, kind, Vector2(FOCUS_X + FOCUS_W - kit.measure(kind, 2),
			KICKER_Y), 2, Kit.INK_DIM)
	var y := _big_name(_name_fit(_name(id)), int(row["mk"])) + 18.0
	# How it was read: the concepts of the Echo that made it.
	var echoes: Array = row.get("echoes", [])
	if not echoes.is_empty():
		var concepts: Array = (echoes[0] as Dictionary).get("concepts", [])
		var said := " / ".join(PackedStringArray(concepts))
		for line in kit.wrap(said, 3, FOCUS_W):
			kit.label(_focus, line, Vector2(FOCUS_X, y), 3, Kit.INK_DIM)
			y += 30.0
		y += 4.0
	# Where it came from: every item that went into it, one line each --
	# Production's history, "Mk  note ← item (game)"; the create's note is
	# the name above, so it is not said twice.
	var history: Array = row.get("history", [])
	for link: Dictionary in history:
		var what := "← %s (%s)" % [str(link["item"]), str(link["game"])]
		if str(link.get("operation", "")) != "create":
			what = "%s %s" % [str(link["note"]), what]
		kit.label(_focus, str(link["mark"]), Vector2(FOCUS_X, y), 2, Kit.INK_FAINT)
		for line in kit.wrap(what, 2, FOCUS_W - 72):
			kit.label(_focus, line, Vector2(FOCUS_X + 72, y), 2, Kit.INK_DIM)
			y += LINE
	y += 14.0
	# What it is.
	var desc := kit.wrap(str(row.get("description", "")), 2, FOCUS_W)
	for line in desc:
		kit.label(_focus, line, Vector2(FOCUS_X, y), 2, Kit.INK)
		y += LINE
	_focus_info["desc_lines"] = desc.size()
	y += 18.0
	# Two columns: what it does, and what changes on the key.
	var ly := _block("DOES", row["does"], FOCUS_X, y, COL_L_W, Kit.INK)
	ly = _block("HOW IT IS USED", row["use"], FOCUS_X, ly + 10, COL_L_W, Kit.INK_DIM)
	ly = _block("COST", row["cost"], FOCUS_X, ly + 10, COL_L_W, Kit.INK_DIM)
	var ry := y
	if slot == "":
		ry = _block("NO KEY", ["Always on while you own it. There is nothing "
				+ "to equip or turn off."], COL_R, ry, COL_R_W, Kit.INK_DIM)
	elif on == id:
		var words := "It is on %s now." % str(keys()[key_index]["keycap"])
		if preview.has(slot):
			words = "Previewed on %s. Not sent: the save still has %s." % [
					str(keys()[key_index]["keycap"]),
					_name(saved(slot)) if saved(slot) != "" else "nothing"]
		ry = _block("ON THE KEY", [words], COL_R, ry, COL_R_W, Kit.INK_DIM)
	elif on == "":
		ry = _block("NOTHING ON %s TO COMPARE" % _cap(), [], COL_R, ry, COL_R_W,
				Kit.INK_DIM)
	else:
		var lines: Array = ((data["comparisons"] as Dictionary).get(slot, {})
				as Dictionary).get(id, {}).get(on, [])
		kit.label(_focus, "AGAINST", Vector2(COL_R, ry), 2, Kit.INK_FAINT)
		var against := kit.fit(_name(on), 2, COL_R_W - 110)
		kit.label(_focus, against, Vector2(COL_R + 96, ry), 2, Kit.INK)
		ry += LINE
		kit.label(_focus, "ON %s NOW" % _cap(), Vector2(COL_R + 96, ry), 2,
				Kit.INK_FAINT)
		ry = _table(lines, COL_R, ry + 30, COL_R_W)
		_focus_info["compared"] = on
	_focus_info["bottom"] = maxf(ly, ry)
	_focus_info["clear"] = _clear(maxf(ly, ry))
	# The action: always in the same place, the foot of the composition.
	var act := _action(id)
	if act != "":
		var colour := Kit.SIGNAL if _can_preview(id) else Kit.INK_DIM
		var ax := FOCUS_X
		if _can_preview(id):
			_prompt_cap(_focus, "ENTER", Vector2(FOCUS_X, ACTION_Y))
			ax += 86
		var words := kit.wrap(act, 2, FOCUS_W - (ax - FOCUS_X))
		for i in words.size():
			kit.label(_focus, words[i], Vector2(ax, ACTION_Y + 5 + LINE * i), 2, colour)
		_focus_info["action"] = Rect2(Vector2(FOCUS_X - 6, ACTION_Y - 6),
				Vector2(ax - FOCUS_X + kit.measure(words[0], 2) + 24, 38))
	if note != "":
		kit.label(_focus, note, Vector2(COL_R, ACTION_Y + 5), 2, Kit.INK)
	if _authored(id):
		# The sample label: its own line at the foot, clear of everything.
		var tag := "AUTHORED FOR LAYOUT STRESS, NOT GAME CONTENT"
		kit.label(_focus, tag, Vector2(FOCUS_X + FOCUS_W - kit.measure(tag, 2),
				ACTION_Y + 38), 2, Kit.INK_DIM)
	_focus_info["bottom"] = maxf(float(_focus_info["bottom"]), ACTION_Y + 54)
	_focus_info["id"] = id


func _block(head: String, lines: Array, x: float, y: float, width: float,
		colour: Color) -> float:
	if head != "":
		kit.label(_focus, head, Vector2(x, y), 2, Kit.INK_FAINT)
		y += 24.0
	for raw: Variant in lines:
		for line: String in kit.wrap(str(raw), 2, width):
			kit.label(_focus, line, Vector2(x, y), 2, colour)
			y += LINE
	return y


## Production's comparison lines set as a table: the label, what is on the
## key now, the arrow, what this would make it -- values aligned on the
## arrow. A change too long for a row (a kind of damage, say) gets its
## label on one line and the change under it; a line that is not a change
## at all is printed whole. The words are Production's; only the setting
## is ours.
func _table(lines: Array, x: float, y: float, width: float) -> float:
	var rows := []
	var lw := 0.0
	var ow := 0.0
	var nw := 0.0
	for raw: Variant in lines:
		var r := _change(str(raw))
		if not r.is_empty() and kit.measure(r["old"], 2) <= 96.0 \
				and kit.measure(r["new"], 2) <= 96.0:
			r["row"] = true
			lw = maxf(lw, kit.measure(r["label"], 2))
			ow = maxf(ow, kit.measure(r["old"], 2))
			nw = maxf(nw, kit.measure(r["new"], 2))
		rows.append(r)
	var old_right := x + lw + 16.0 + ow
	var arrow_x := old_right + 10.0
	var new_x := arrow_x + kit.measure("→", 2) + 10.0
	for i in rows.size():
		var r: Dictionary = rows[i]
		if r.is_empty():
			for line in kit.wrap(str(lines[i]), 2, width):
				kit.label(_focus, line, Vector2(x, y), 2, Kit.INK)
				y += LINE
			continue
		if not r.get("row", false):
			# Too long for a row: the label, then what is on the key now, then
			# the arrow and what this would make it, each on its own line.
			kit.label(_focus, r["label"], Vector2(x, y), 2, Kit.INK_DIM)
			y += LINE
			for line in kit.wrap(r["old"], 2, width - 24):
				kit.label(_focus, line, Vector2(x + 24, y), 2, Kit.INK_DIM)
				y += LINE
			for line in kit.wrap("→ " + str(r["new"]), 2, width - 24):
				kit.label(_focus, line, Vector2(x + 24, y), 2, Kit.INK)
				y += LINE
			y += 4.0
			continue
		kit.label(_focus, r["label"], Vector2(x, y), 2, Kit.INK_DIM)
		kit.label(_focus, r["old"], Vector2(old_right - kit.measure(r["old"], 2), y),
				2, Kit.INK_DIM)
		kit.label(_focus, "→", Vector2(arrow_x, y), 2, Kit.INK_FAINT)
		kit.label(_focus, r["new"], Vector2(new_x, y), 2, Kit.INK)
		y += LINE
	return y


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


## The composition's own control, for the device in hand: ENTER, or the
## pad's south face button.
func _prompt_cap(parent: Node3D, cap: String, at: Vector2) -> void:
	if kit.device == "pad":
		kit.sprite(parent, "pad_face_south", at + Vector2(20, 13), 2, Kit.INK,
				0.006)
		return
	var w := kit.measure(cap, 2) + 16.0
	kit.plate(parent, at, Vector2(w, 26), 0.001, kit.lit(Color("#c9d0db")), 0.004)
	kit.label(parent, cap, at + Vector2(8, 5), 2, Kit.SHADE, 0.0065)


## The echoes arrive: each slides out from under the name to its place,
## the nearest first. At once when motion is reduced.
func _echo_in() -> void:
	for e in _echoes.size():
		var copy: Node3D = _echoes[e]
		var rest: Vector3 = copy.get_meta("rest")
		if kit.reduced:
			copy.position = rest
			continue
		copy.position = copy.get_meta("from")
		kit.go(copy, "position", rest, 0.2, "out", 0.03 * e)


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


## The one action the composition offers, in words.
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
			_place_focus_bar()
			_route_sig = ""
		return
	if dir.x < 0:
		zone = "keys"
		_place_focus_bar()
		_route_sig = ""
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
	_echo_in()


## Select an item on the rail. Nothing on the rail moves (unless the
## keyboard or pad asks for one out of view); the composition is rebuilt
## whole, and the route and the echoes move to it.
func _select(id: String, by_pointer := false) -> void:
	if id == unfolded:
		return
	unfolded = id
	sel[key_index] = id
	_layout(false, by_pointer)
	_compose()
	_echo_in()
	_aim_route()


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
	# The rail's tags change; its order and its scroll do not.
	var keep := unfolded
	var keep_scroll := _scroll_px
	scroll[key_index] = keep_scroll
	sel[key_index] = keep
	_open_drawer(true)


func back() -> bool:
	if zone == "drawer":
		zone = "keys"
		_place_focus_bar()
		_route_sig = ""
		return true
	return false


## Hover lights, and never moves anything.
func hover_at(p: Vector2) -> void:
	var was := hover
	hover = _hit(p)
	if hover == "action":
		hover = ""
	if hover != was:
		_place_focus_bar()
		_mark_strips()


func click(p: Vector2) -> bool:
	var hit := _hit(p)
	if hit.begins_with("key:"):
		var i := int(hit.trim_prefix("key:"))
		zone = "keys"
		_focus_key(i, true)
		_place_focus_bar()
		_route_sig = ""
		return true
	if hit == "action":
		accept()
		return true
	if hit != "":
		zone = "drawer"
		_select(hit, true)
		_place_focus_bar()
		_route_sig = ""
		return true
	return false


func wheel(p: Vector2, dir: int) -> bool:
	if p.x < RAIL_X - 20.0:
		return false
	_hand_scroll(60.0 * dir)
	return true


## The right stick: the same hand scroll as the wheel, continuous.
func scroll_by(px: float) -> void:
	if zone != "drawer":
		return
	_hand_scroll(px)


## Scrolling by hand moves the rail under its edges; the selection stays
## selected, and the route follows its station to the edge and turns there.
func _hand_scroll(delta: float) -> void:
	_scroll_px += delta
	_layout(false, true)
	_aim_route()


func _hit(p: Vector2) -> String:
	for i in _rows.size():
		var y: float = _rows[i]["y"]
		if Rect2(Vector2(LOAD_X - 12, y - 10), Vector2(LOAD_W + 24,
				KEY_SHELF + 16)).has_point(p):
			return "key:%d" % i
	if _focus_info.has("action") and (_focus_info["action"] as Rect2).has_point(p):
		return "action"
	if p.x < RAIL_X - 12 or p.x > NAME_X + NAME_W + 8 or p.y < VIEW_TOP \
			or p.y > VIEW_BOTTOM:
		return ""
	for id: String in _order:
		var top: float = VIEW_TOP + float(_strips[id]["y"]) - _scroll_px
		if p.y >= top - 6 and p.y < top + STATION - 6:
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
	var inside := false
	if unfolded != "" and rects.has(unfolded):
		var r: Array = rects[unfolded]
		inside = float(r[0]) >= VIEW_TOP - 1.0 and float(r[0]) + float(r[1]) \
				<= VIEW_BOTTOM + 1.0
	var route := route_points()
	return {"key": key_index, "slot": slot_of(key_index), "zone": zone,
		"unfolded": unfolded, "order": _order, "count": _order.size(),
		"scroll": _scroll_px, "preview": preview.duplicate(), "hover": hover,
		"rects": rects, "strip_positions": _positions(),
		# the selected station is wholly inside the rail's view
		"card_inside": inside,
		# the selected item's composition is on the wall
		"card_shown": _focus != null and str(_focus_info.get("id", "")) == unfolded
			and unfolded != "",
		"holes": _holes(),
		"focus": _focus_info.duplicate(),
		"echo_copies": _echoes.size(),
		"route": {"key_y": snappedf(_rs.key_y, 0.1), "sel_y": snappedf(_rs.sel_y,
			0.1), "name_y": snappedf(_rs.name_y, 0.1), "end_x": snappedf(
			(route[-1] as Vector2).x, 0.1)},
		"route_moving": kit.moving(_rs, "sel_y") or kit.moving(_rs, "key_y")
			or kit.moving(_rs, "name_w"),
		"route_held": _held(),
		"text_scale_min": _text_scale_min(),
		"compositions": _live_compositions(),
		"more": [(_more_up.get_meta("label") as Label3D).text if _more_up.visible
			else "", (_more_down.get_meta("label") as Label3D).text
			if _more_down.visible else ""]}


## Where the selected station is, if the route cannot reach it on the rail:
## "above" or "below" the view (the route turns at that edge), else "".
func _held() -> String:
	if unfolded == "" or not _strips.has(unfolded):
		return ""
	var shelf: float = VIEW_TOP + float(_strips[unfolded]["y"]) - _scroll_px + SHELF
	if shelf < VIEW_TOP:
		return "above"
	if shelf > VIEW_BOTTOM:
		return "below"
	return ""


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


## A word lifted over the rail's edges is shrunk ON PURPOSE, to be seen at
## its page size (_over); that is its own scale, not a squash.
static func _own_scale(n: Node3D) -> float:
	var s := 1.0
	var at: Node = n
	while at != null:
		s *= float(at.get_meta("own_scale", 1.0))
		at = at.get_parent()
	return s


## How many compositions are on the wall right now: one, or the old and the
## new are overlapping.
func _live_compositions() -> int:
	var n := 0
	for c: Node in face.get_children():
		if c is Node3D and c.get_meta("composition", false) \
				and not c.is_queued_for_deletion():
			n += 1
	return n


## The largest empty stretch of the rail's view that has stations beyond it:
## between two drawn stations, or between a drawn station and the view's
## edge when more lies past that edge.
func _holes() -> float:
	var spans: Array = []
	var any_above := false
	var any_below := false
	for id: String in _order:
		var st: Dictionary = _strips[id]
		var top: float = VIEW_TOP + float(st["y"]) - _scroll_px
		var bottom: float = top + float(st["h"])
		if (st["node"] as Node3D).visible:
			spans.append([maxf(top, VIEW_TOP), minf(bottom, VIEW_BOTTOM)])
		elif bottom <= VIEW_TOP + 0.5:
			any_above = true
		elif top >= VIEW_BOTTOM - 0.5:
			any_below = true
		else:
			if top < VIEW_TOP:
				any_above = true
			else:
				any_below = true
	if spans.is_empty():
		return VIEW_BOTTOM - VIEW_TOP if (any_above or any_below) else 0.0
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var worst := 0.0
	for i in range(1, spans.size()):
		worst = maxf(worst, float(spans[i][0]) - float(spans[i - 1][1]))
	if any_above:
		worst = maxf(worst, float(spans[0][0]) - VIEW_TOP)
	if any_below:
		worst = maxf(worst, VIEW_BOTTOM - float(spans[-1][1]))
	return snappedf(worst, 0.1)


func _positions() -> Dictionary:
	var out := {}
	for id: String in _order:
		var node: Node3D = _strips[id]["node"]
		out[id] = [snappedf(node.position.x, 0.0001), snappedf(node.position.y, 0.0001)]
	return out


## The device changed: the composition's control is redrawn for it.
func on_device() -> void:
	_compose()


func tick(_delta: float) -> void:
	_update_spine()
	_draw_route()


## The spine, from the first station's shelf to the last, where the rail
## is seen: it never runs past the rail's view or off the wall.
func _update_spine() -> void:
	if _spine == null or not is_instance_valid(_spine):
		return
	if _order.size() < 2:
		_spine.visible = false
		return
	var first: Node3D = _strips[_order[0]]["node"]
	var last: Node3D = _strips[_order[-1]]["node"]
	var top := maxf(Kit.PAGE.y * 0.5 - first.position.y / Kit.px() + SHELF, VIEW_TOP)
	var bottom := minf(Kit.PAGE.y * 0.5 - last.position.y / Kit.px() + SHELF,
			VIEW_BOTTOM)
	_spine.visible = bottom > top
	if not _spine.visible:
		return
	(_spine.mesh as QuadMesh).size = Vector2(2, bottom - top) * Kit.px()
	_spine.position = Kit.at(Vector2(RAIL_X, (top + bottom) * 0.5), 0.0028)
