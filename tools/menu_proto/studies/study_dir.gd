class_name StudyDir
extends RefCounted
## What every direction study shares: the words, read from the sample the
## same way the prototype reads them, and the few drawing habits that must
## not differ between directions for the comparison to be fair -- the
## keycap (a Glyph piece), the aligned comparison table, wrapped text.
## A direction adds only its own shapes.

const MOUSE_SYMBOL := {"RMB": "mouse_right", "MMB": "mouse_middle"}
const LINE := 20.0

var ctx: Dictionary
var kit: Kit
var G := StudyGeo


func setup(c: Dictionary) -> void:
	ctx = c
	kit = c["kit"]


func face(page: String) -> Node3D:
	return ctx["faces"][page]


# ------------------------------------------------------------ the words

func item(id: String) -> Dictionary:
	return ctx["items"][id]


func name_of(id: String) -> String:
	return str(item(id)["name"]).to_upper()


func mk(id: String) -> String:
	return "MK " + ["", "I", "II", "III", "IV", "V"][clampi(int(item(id)["mk"]), 0, 5)]


func authored(id: String) -> bool:
	return bool(item(id).get("authored", false))


func does(id: String) -> Array:
	return item(id).get("does", [])


func use_lines(id: String) -> Array:
	return item(id).get("use", [])


func cost(id: String) -> Array:
	return item(id).get("cost", [])


func desc(id: String) -> String:
	return str(item(id).get("description", ""))


## Production's history, as the prototype sets it: "MK  note ← item (game)".
func history(id: String) -> Array:
	var out := []
	for link: Dictionary in item(id).get("history", []):
		var what := "← %s (%s)" % [str(link["item"]), str(link["game"])]
		if str(link.get("operation", "")) != "create":
			what = "%s %s" % [str(link["note"]), what]
		out.append([str(link["mark"]).to_upper(), what.to_upper()])
	return out


func concepts(id: String) -> String:
	var echoes: Array = item(id).get("echoes", [])
	if echoes.is_empty():
		return ""
	return " / ".join(PackedStringArray((echoes[0] as Dictionary).get("concepts", []))).to_upper()


func key_of(slot: String) -> Dictionary:
	for k: Dictionary in ctx["keys"]:
		if str(k["slot"]) == slot:
			return k
	return {}


func cap_of(slot: String) -> String:
	return str(key_of(slot).get("keycap", "")).to_upper()


func seated(slot: String) -> String:
	return str(ctx["seated"].get(slot, ""))


func charges(id: String) -> String:
	var row := item(id)
	if bool(row.get("consumable", false)) and row.get("charges_max") != null:
		return "%d/%d" % [int(row["charges_left"]), int(row["charges_max"])]
	return ""


# ------------------------------------------------------------ drawing

## The miniature's own light is meant for the miniature alone, but the
## renderer these stills use ignores a light's cull mask, so it also falls
## on the Map's wall (and, glancing, the Journal's). A PALE surface there is
## toned by this much, so one card reads the same on every wall; nothing
## dark needs it.
func stray(f: Node3D) -> float:
	if f == face("map"):
		return 0.74
	if f == face("journal"):
		return 0.86
	return 1.0


func toned(colour: Color, f: Node3D) -> Color:
	var k := stray(f)
	return Color(colour.r * k, colour.g * k, colour.b * k)

## Words on a face, `z` off the wall.
func text(f: Node3D, s: String, at: Vector2, k: int, colour: Color, z := 0.003,
		numerals := false) -> Label3D:
	return kit.label(f, s, at, k, colour, z, numerals)


## Wrapped words; returns the y below them.
func para(f: Node3D, s: String, at: Vector2, width: float, k: int, colour: Color,
		z := 0.003, pitch := -1.0) -> float:
	var y := at.y
	var step := pitch if pitch > 0.0 else 8.0 * k + 4.0
	for line in kit.wrap(s, k, width):
		kit.label(f, line, Vector2(at.x, y), k, colour, z)
		y += step
	return y


## The Glyph keycap, as the prototype draws one; returns its width.
func keycap(f: Node3D, cap: String, at: Vector2, z := 0.001) -> float:
	var up := cap.to_upper()
	var w := maxf(40.0, kit.measure(up, 2) + 16.0)
	if MOUSE_SYMBOL.has(up):
		w = 66.0
	kit.plate(f, at, Vector2(w, 26), z, kit.lit(Color("#c9d0db")), 0.004)
	if MOUSE_SYMBOL.has(up):
		kit.sprite(f, MOUSE_SYMBOL[up], at + Vector2(14, 13), 2, Kit.SHADE, z + 0.0055)
		kit.label(f, up, at + Vector2(28, 5), 2, Kit.SHADE, z + 0.0055)
	else:
		kit.label(f, up, at + Vector2(8, 5), 2, Kit.SHADE, z + 0.0055)
	return w


## Production's comparison lines as a table aligned on the arrow: label,
## what is on the key, the arrow, what this would make it. A change too
## long for a row gets its label, then the old value, then "→ new". The
## words are Production's; only the setting is the study's. Returns the y
## below it.
func table(f: Node3D, lines: Array, x: float, y: float, width: float, z: float,
		ink_old: Color, ink_new: Color, ink_label: Color, pitch := LINE) -> float:
	var rows := []
	var lw := 0.0
	var ow := 0.0
	for raw: Variant in lines:
		var r := change(str(raw))
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
			y = para(f, str(lines[i]), Vector2(x, y), width, 2, ink_new, z, pitch)
			continue
		if not r.get("row", false):
			# The label and what is on the key on one line when they fit,
			# then the arrow and what this would make it.
			var lw2 := kit.measure(r["label"], 2) + 16.0
			if lw2 + kit.measure(r["old"], 2) <= width:
				kit.label(f, r["label"], Vector2(x, y), 2, ink_label, z)
				kit.label(f, r["old"], Vector2(x + lw2, y), 2, ink_old, z)
				y += pitch
				kit.label(f, kit.fit("→ " + str(r["new"]), 2, width - lw2),
						Vector2(x + lw2, y), 2, ink_new, z)
				y += pitch + 4.0
				continue
			kit.label(f, r["label"], Vector2(x, y), 2, ink_label, z)
			y += pitch
			kit.label(f, kit.fit(r["old"], 2, width - 24), Vector2(x + 24, y), 2, ink_old, z)
			y += pitch
			kit.label(f, kit.fit("→ " + str(r["new"]), 2, width - 24), Vector2(x + 24, y),
					2, ink_new, z)
			y += pitch + 4.0
			continue
		kit.label(f, r["label"], Vector2(x, y), 2, ink_label, z)
		kit.label(f, r["old"], Vector2(old_right - kit.measure(r["old"], 2), y), 2,
				ink_old, z)
		kit.label(f, "→", Vector2(arrow_x, y), 2, ink_label, z)
		kit.label(f, r["new"], Vector2(new_x, y), 2, ink_new, z)
		y += pitch
	return y


## "Label: a → b", or "Mk 2 → Mk 1" (the shared word is the label).
static func change(line: String) -> Dictionary:
	var arrow := line.find(" → ")
	if arrow < 0:
		return {}
	var left := line.substr(0, arrow)
	var right := line.substr(arrow + 3)
	var colon := left.find(": ")
	if colon >= 0:
		return {"label": left.substr(0, colon).to_upper(),
			"old": left.substr(colon + 2).to_upper(), "new": right.to_upper()}
	var l := left.split(" ", false)
	var r := right.split(" ", false)
	if l.size() == 2 and r.size() == 2 and l[0] == r[0]:
		return {"label": l[0].to_upper(), "old": l[1].to_upper(), "new": r[1].to_upper()}
	return {}


## How tall `table` will set these lines, without setting them.
func table_height(lines: Array, width: float, pitch := LINE) -> float:
	var h := 0.0
	for raw: Variant in lines:
		var r := change(str(raw))
		if r.is_empty():
			h += pitch * kit.wrap(str(raw), 2, width).size()
		elif kit.measure(r["old"], 2) <= 96.0 and kit.measure(r["new"], 2) <= 96.0:
			h += pitch
		elif kit.measure(r["label"], 2) + 16.0 + kit.measure(r["old"], 2) <= width:
			h += pitch * 2.0 + 4.0
		else:
			h += pitch * 3.0 + 4.0
	return h


## The largest size a name takes in `lines` lines (never below `least`).
func name_fit(s: String, width: float, big: int, least: int, lines := 2) -> Array:
	for k in range(big, least - 1, -1):
		var w := kit.wrap(s, k, width)
		if w.size() <= lines:
			return [k, w]
	return [least, kit.wrap(s, least, width)]


## Where a face's own run ends at its right edge and begins at its left:
## the corner piece carries it round the post between them.
const RUN_START := 40.0
const RUN_END := 1240.0


## A run round the corner post between page `left` and the page a right
## turn faces from it, at page height `y`, `lift` off the walls (up to
## 0.03): along the left wall from page x RUN_END, round the post's two
## inner faces, and along the right wall to page x RUN_START. A face's own
## run meets it there, at the same height and depth.
func corner(left: String, y: float, r_px: float, material: Material, lift := 0.03) -> void:
	var right: String = Kit.PAGES[posmod(Kit.PAGES.find(left) - 1, 4)]
	var tl: Transform3D = face(left).global_transform
	var post := 0.8727
	var wy := Kit.at(Vector2(0, y), lift).y
	var pts := [tl * Kit.at(Vector2(RUN_END, y), lift),
		tl * Vector3(post - lift, wy, -1.0 + lift),
		tl * Vector3(post - lift, wy, -post + lift),
		tl * Vector3(1.0 - lift, wy, -post + lift),
		face(right).global_transform * Kit.at(Vector2(RUN_START, y), lift)]
	G.tube(ctx["shell"], G.routed3(pts, 0.011, 6), r_px, material, 12)


## The Journal -> Map link where it rounds the corner post (the prototype's
## thread takes the same corner).
func corner_link(y: float, colour: Color, r_px: float, lift := 0.03,
		material: Material = null) -> void:
	corner("journal", y, r_px, material if material != null
			else G.mat(colour, 0.05, 0.6), lift)


## The menu's guide stroke inside the Map's window, from where the link
## comes in (`from`, at the window's edge) along its height, then down (or
## up) to the passage, stopping short of it -- so it never runs along a row
## of the window's words, and it lands on the passage from above.
func guide(f: Node3D, from: Vector2, target: Vector2, colour: Color, z := 0.02,
		width := 5.0) -> void:
	var down := signf(target.y - from.y)
	if down == 0.0:
		down = 1.0
	var pts := [from, Vector2(target.x, from.y), Vector2(target.x, target.y - down * 22.0)]
	if absf(from.x - target.x) < 1.0:
		pts = [Vector2(target.x, from.y), pts[-1]]
	var node := MeshInstance3D.new()
	node.mesh = Kit.route_mesh(Kit.route_corners(pts, 12.0), width, z)
	node.material_override = kit.flat(colour)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(node)
	# its end: a bar across it, just short of the passage's mark
	var end: Vector2 = pts[-1]
	kit.lifted_card(f, end - Vector2(9, 2.5), Vector2(18, 5), z, kit.flat(colour))


## The comparison's head and the readout's kicker, in the prototype's own
## terms, the same in every direction ("what changes if it is on the key").
func against_head() -> String:
	return "IF ON %s, IN PLACE OF %s" % [cap_of(ctx["slot"]), name_of(ctx["equipped"])]


func kicker(id: String) -> String:
	return "FITS %s · %s · %s" % [cap_of(ctx["slot"]), str(item(id).get("family", "")),
			mk(id)]


## The inspected item's action, in Production's words: the preview the
## prototype offers ("PREVIEW ON RMB"), or the refusal, or nothing.
func action(id: String) -> String:
	var slot: String = ctx["slot"]
	if seated(slot) == id:
		return ""
	var refusal := str((item(id).get("refusal", {}) as Dictionary).get(slot, ""))
	if refusal != "":
		return refusal.to_upper()
	return "PREVIEW ON %s" % cap_of(slot)
