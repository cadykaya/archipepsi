extends SceneTree
## Track D -- the game packs' rows, resolved by Production's OWN resolver.
##
## `check_pack_table.py` proves the rows are legal D-11 by running
## Production's `pack_table_problems`. This proves the other half in the
## engine: that the rows the art lane exported are the rows
## `ThemePack` finds, loads and refuses in the right order.
##
## The thing worth proving is the REFUSAL. A candidate pack is authored
## and not selected -- `THEME_PACK_STATUS` is empty, so no Zone may name
## one -- and the art lane granting itself a rung on that ladder is
## exactly the failure the ladder exists to prevent. So this asserts
## that with the real registry the pack does NOT bind and the family
## answers, and only then uses the resolver's own `use_pack_status`
## override -- the hook it provides for a review screen -- to show what
## the rows WOULD paint.

const PACK := preload("res://_harness/prod_theme_pack.gd")
const REVIEW_STATE := "selectable"

var _faults: Array[String] = []
var _notes := {}


func _bad(what: String) -> void:
	_faults.append(what)
	print("[packres] FAULT: %s" % what)


func _init() -> void:
	if not PACK.bound():
		_bad("ThemePack did not load the exported descriptor at "
			 + "res://content/theme/THEME_PACK.json")
		_finish()
		return
	var table: Dictionary = PACK.descriptor().get("pack_textures", {})
	if table.is_empty():
		_bad("the exported descriptor carries no pack_textures table, so "
			 + "there is nothing here to resolve and a pass would mean "
			 + "only that the resolver loaded")
		_finish()
		return

	var packs := {}
	for key: Variant in table:
		packs[str(key).split("/")[0]] = true

	# --- 1. a candidate does not bind ---------------------------------
	for pack: String in packs:
		var status: String = PACK.pack_status(pack)
		if status != "":
			_bad("pack '%s' is registered as '%s'. These rows are
 authored, not selected -- the art lane does not put a pack on the
 ladder" % [pack, status])
		if PACK.pack_binds(pack):
			_bad("pack '%s' BINDS with the real registry. An unregistered "
				 % pack + "pack must not paint a Zone")
		if PACK.pack_refusals(pack) != []:
			_bad("pack '%s' ships a universal role: %s"
				 % [pack, PACK.pack_refusals(pack)])

	# --- 2. ...and the family answers instead -------------------------
	for key: Variant in table:
		var parts := str(key).split("/")
		var pack: String = parts[0]
		var theme: String = parts[1]
		var role: String = parts[2]
		var got: Dictionary = PACK.resolution(theme, role, pack)
		if str(got.get("source")) != "family":
			_bad("%s resolved to '%s' (key %s) while the pack is a "
				 % [key, got.get("source"), got.get("key")]
				 + "candidate; the family should have answered")
		if str(got.get("key")) != "%s/%s" % [theme, role]:
			_bad("%s fell through to '%s', not the family's own row"
				 % [key, got.get("key")])

	# --- 3. the review state, through the resolver's own hook ---------
	var review := {}
	for pack: String in packs:
		review[pack] = REVIEW_STATE
	PACK.use_pack_status(review)
	for key: Variant in table:
		var parts := str(key).split("/")
		var pack: String = parts[0]
		var theme: String = parts[1]
		var role: String = parts[2]
		if not PACK.pack_binds(pack):
			_bad("pack '%s' does not bind even as '%s'"
				 % [pack, REVIEW_STATE])
			continue
		var got: Dictionary = PACK.resolution(theme, role, pack)
		if str(got.get("source")) != "pack":
			_bad("%s resolved to '%s', not its own row, with the pack "
				 % [key, got.get("source")] + "selectable")
			continue
		if str(got.get("key")) != str(key):
			_bad("%s answered with key '%s'" % [key, got.get("key")])
		var texture: Texture2D = PACK.texture_for(theme, role, pack)
		if texture == null:
			_bad("%s resolved but loaded no texture" % key)
			continue
		var row: Dictionary = table[key]
		var want := int(row.get("size_px", 0))
		if texture.get_width() != want or texture.get_height() != want:
			_bad("%s loaded %dx%d and its row declares %d px"
				 % [key, texture.get_width(), texture.get_height(), want])
		var covers: float = PACK.covers_m(theme, role, pack)
		if not is_equal_approx(covers, float(row.get("covers_m", 0.0))):
			_bad("%s covers %s m and its row declares %s"
				 % [key, covers, row.get("covers_m")])
		_notes[key] = {"source": "pack", "size_px": texture.get_width(),
			"covers_m": covers}

	# --- 4. a role the pack does NOT ship still yields to the family ---
	# D-11's clause 2: a pack ships a role or yields the WHOLE role. If a
	# pack could reach the family's fallback under its own name, that
	# would be a texture chosen for neither the pack's role nor by the
	# family.
	var shipped := {}
	for key: Variant in table:
		shipped[str(key)] = true
	for pack: String in packs:
		for role in ["ceiling", "trim", "wall_ribbed"]:
			var theme := "temple_ruin"
			if shipped.has("%s/%s/%s" % [pack, theme, role]):
				continue
			var got: Dictionary = PACK.resolution(theme, role, pack)
			if str(got.get("source")) == "pack":
				_bad("%s/%s/%s is not shipped and resolved to the pack "
					 % [pack, theme, role] + "anyway")
			var plain: Dictionary = PACK.resolution(theme, role)
			if str(got.get("key")) != str(plain.get("key")):
				_bad("%s/%s/%s answered '%s' and the family alone answers "
					 % [pack, theme, role, got.get("key")]
					 + "'%s' -- a pack must not change the chain behind it"
					 % plain.get("key"))

	# --- 5. the override does not leak --------------------------------
	PACK.clear_pack_status()
	for pack: String in packs:
		if PACK.pack_binds(pack):
			_bad("pack '%s' still binds after clear_pack_status(); the "
				 % pack + "review override outlived the review")
	_finish()


func _finish() -> void:
	_notes["engine"] = Engine.get_version_info()["string"]
	_notes["faults"] = _faults
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var fh := FileAccess.open(args[0], FileAccess.WRITE)
		fh.store_string(JSON.stringify(_notes, "\t", true, true))
		fh.close()
	if _faults.is_empty():
		print("[packres] PASS -- %d row(s) resolve through Production's own "
			  % (_notes.size() - 2)
			  + "ThemePack: refused as candidates, the family answering, "
			  + "and painting only under a review override that does not "
			  + "outlive it")
	else:
		push_error("[packres] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
