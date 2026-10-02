class_name ThemePack
extends RefCounted

## THE AUTHORED TEXTURE PACK, BOUND BY ROLE.
##
## `docs/art-requests/2026-09-12-theme-pack-binding-contract.md` is the
## agreed contract and this is its engine half. The art lane exports
## `godot/content/theme/<theme>_<role>.png` plus `THEME_PACK.json`; this
## answers `(theme, role) -> Texture2D` and `ThemeMaterials` is the only
## caller. No builder learns about the pack and no scene names a `.png`.
##
## **HAZARD IS UNIVERSAL AND IS NOT IN HERE.** The descriptor says it in
## as many words -- `universal_roles: {"hazard": "resolve to the shared
## universal material; a pack must not paint its own"}` -- and
## `ASSET_INVENTORY.md` says why: a theme-tinted hazard stripe is one the
## player has to re-learn in every theme, so the treatment is shared.
## Clause 3 of the contract listed `hazard` among the roles a theme must
## ship, which contradicted that and made the pack unsatisfiable by
## design. **The reconciliation: a theme must ship authored pixels for
## `floor`, `wall`, `trim` and `accent`. `hazard` is required AT RUNTIME
## and resolved from the shared material, in every theme, by
## `ThemeMaterials.hazard_mat`.** Removing it from the per-theme floor
## removes nothing at runtime; it removes an obligation that could only
## be met by breaking the rule it was meant to protect.
##
## A pack that ships a per-theme `hazard` row is REFUSED rather than
## bound, because binding it is how the shared signal quietly becomes six
## different ones.
##
## **GAME PACKS (D-11), over the same file.** A Zone may name a
## `theme_pack` beside its family `theme`. Its rows live in the
## descriptor's flat `pack_textures` table, keyed `<pack>/<theme>/<role>`
## with the same row schema as `textures`, and resolve in exactly this
## order (`theme_packs.resolution_order` on the bridge side):
##
##   1. `<pack>/<theme>/<role>` -- the exact row, and **no role hop**;
##   2. otherwise the family, exactly as it resolved before packs
##      existed, including its one hop.
##
## A pack ships a role or yields the whole role to the family: there is
## never a `<pack>/<theme>/<fallback role>`, which would be a texture
## chosen for neither this pack's role nor by the family. A partial pack
## is legal for the same reason, since `disqualified` stays about the
## family. A pack row painting a universal role is refused like a
## family's (`pack_refusals`). And a pack binds only in a state a Zone may
## name it in, `selectable` or `approved` (`THEME_PACK_STATUS`). The
## runtime reads that state and never moves it.

## Where the exported pack lives, as the contract names it.
const ROOT := "res://content/theme"
const DESCRIPTOR := ROOT + "/THEME_PACK.json"

## The roles a theme must ship authored pixels for. Hazard is NOT one;
## see the header. A theme missing any of these is disqualified for that
## role, falls back to `ProcTextures`, and says so once -- the pack
## still binds for every other theme and every other role.
const REQUIRED_ROLES := ["floor", "wall", "trim", "accent"]

## Resolved from the shared material and never from a per-theme or
## per-pack texture. The bridge's exported list, not a copy of it.
const UNIVERSAL_ROLES := Constants.THEME_UNIVERSAL_ROLES

## The descriptor table a pack's rows live in.
const PACK_TABLE := Constants.THEME_PACK_TABLE

## The states a Zone may name a pack in, and so the only ones that bind.
## `candidate` is authored rows only -- viewable in review, nameable by no
## Zone -- and a pack the registry does not list is a candidate at most.
const BINDABLE_STATES := ["selectable", "approved"]

static var _descriptor: Dictionary = {}
static var _loaded := false
static var _warned := {}
static var _cache := {}

## A test seam. `_descriptor_override` lets a suite install a pack with a
## required row REMOVED and observe the documented fallback -- which is
## the control this whole file needs and which cannot be produced by
## deleting a shipped file.
static var _descriptor_override: Dictionary = {}

## The second test seam: a status registry for DISPOSABLE, TEST-SCOPED
## packs. Production reads `Constants.THEME_PACK_STATUS`, which is `{}`
## -- no pack has been reviewed -- and nothing here writes to it.
static var _status_override: Dictionary = {}
static var _status_overridden := false

## Forgets everything loaded. For a suite that installs an override.
static func reset() -> void:
	_descriptor = {}
	_loaded = false
	_warned = {}
	_cache = {}

static func use_descriptor(descriptor: Dictionary) -> void:
	reset()
	_descriptor_override = descriptor

static func clear_descriptor() -> void:
	_descriptor_override = {}
	reset()

static func use_pack_status(status: Dictionary) -> void:
	_status_override = status.duplicate()
	_status_overridden = true
	reset()

static func clear_pack_status() -> void:
	_status_override = {}
	_status_overridden = false
	reset()

## A pack's state as the registry records it, or "" for one it does not
## list. Read, never upgraded.
static func pack_status(pack: String) -> String:
	var registry: Dictionary = _status_override if _status_overridden \
			else Constants.THEME_PACK_STATUS
	return str(registry.get(pack, ""))

## May a Zone naming `pack` be painted from it? Only in a state a Zone may
## name it in, and never under a family's name.
static func pack_binds(pack: String) -> bool:
	return pack != "" and not (pack in Constants.THEMES) \
			and pack_status(pack) in BINDABLE_STATES

## The descriptor, or `{}`. **A pack that fails to load is not an
## error** (contract clause 6): the engine falls back to `ProcTextures`
## the way the procedural builders stay behind the shells.
static func descriptor() -> Dictionary:
	if not _descriptor_override.is_empty():
		return _descriptor_override
	if _loaded:
		return _descriptor
	_loaded = true
	if not FileAccess.file_exists(DESCRIPTOR):
		return _descriptor
	var text := FileAccess.get_file_as_string(DESCRIPTOR)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("theme: %s did not parse; the pack is not bound"
				% DESCRIPTOR)
		return _descriptor
	_descriptor = parsed
	return _descriptor

## Is the pack available at all?
static func bound() -> bool:
	return not (descriptor().get("textures", {}) as Dictionary).is_empty()

## The authored texture for `(theme, role)` in a Zone naming `pack`, or
## `null`.
##
## **Role, never path** (clause 1). **One fallback hop, never two**
## (clause 2), through the descriptor's own `optional_role_fallbacks`
## and `variants`, so a chain cannot end somewhere nobody chose.
static func texture_for(theme: String, role: String,
		pack := "") -> Texture2D:
	return resolution(theme, role, pack).get("texture") as Texture2D

## WHERE `(theme, role)` CAME FROM, for a Zone naming `pack` ("" for
## none): an identity a suite or a review screen can show, rather than
## infer from a texture path.
##
##   source      "pack"        the pack's exact row
##               "family"      the family's own row
##               "fallback"    the family's one hop
##               "procedural"  nothing bound; `ProcTextures` paints it
##               "universal"   a universal role; the shared material
##   key         the descriptor key that answered, or ""
##   pack        the pack the Zone named, `status` its registry state as
##               read, and `pack_binds` whether it was allowed to answer
##
## **Cached on (pack, theme, role)**, so a pack and a family -- or two
## packs over one family -- never share an entry.
static func resolution(theme: String, role: String,
		pack := "") -> Dictionary:
	var key := "%s|%s|%s" % [pack, theme, role]
	if _cache.has(key):
		return _cache[key]
	var out := _resolve(theme, role, pack)
	_cache[key] = out
	return out

## Rows a pack ships for a universal role -- `hazard` -- which are
## refused rather than bound, exactly as a family's are (`refusals`).
static func pack_refusals(pack: String) -> Array:
	var out: Array = []
	for key: Variant in _pack_table():
		var parts := str(key).split("/")
		if parts.size() == 3 and parts[0] == pack \
				and parts[2] in UNIVERSAL_ROLES:
			out.append(str(key))
	out.sort()
	return out

## How many metres one tile of `(theme, role)` covers, or 4.0 (clause 5).
## A pack row's own `covers_m` when the pack is what answered.
static func covers_m(theme: String, role: String, pack := "") -> float:
	if pack != "" and str(resolution(theme, role, pack).get("source",
			"")) == "pack":
		return float(_pack_row("%s/%s/%s" % [pack, theme, role]).get(
				"covers_m", 4.0))
	var row := _row(theme, role)
	if row.is_empty():
		var hop := _fallback_role(role)
		row = _row(theme, hop) if hop != "" else {}
	return float(row.get("covers_m", 4.0)) if not row.is_empty() else 4.0

## Which REQUIRED roles this theme does not ship. Empty is the answer
## for a theme that binds.
static func disqualified(theme: String) -> Array:
	var out: Array = []
	for role: String in REQUIRED_ROLES:
		if _row(theme, role).is_empty():
			out.append(role)
	return out

## Roles the descriptor claims a theme ships but should not: a pack
## painting its own hazard is the one that matters, and it is refused
## rather than bound.
static func refusals(theme: String) -> Array:
	var out: Array = []
	for role: String in UNIVERSAL_ROLES:
		if not _row(theme, role).is_empty():
			out.append(role)
	return out

# --- the pieces ----------------------------------------------------------

static func _resolve(theme: String, role: String, pack: String) -> Dictionary:
	var out := {"texture": null, "source": "procedural", "key": "",
			"pack": pack, "status": pack_status(pack) if pack != "" else "",
			"pack_binds": pack_binds(pack)}
	if role in UNIVERSAL_ROLES:
		out["source"] = "universal"
		return out
	if not bound():
		return out
	# 1. THE PACK'S EXACT ROW, when the Zone names one it may name.
	if pack != "":
		if not pack_binds(pack):
			_warn("pack '%s' is %s; a Zone may be painted only from a "
					% [pack, "'%s'" % pack_status(pack)
						if pack_status(pack) != "" else "unregistered"]
					+ "selectable or approved pack, so the family answers")
		else:
			for refused: String in pack_refusals(pack):
				_warn("pack row '%s' paints a universal role; it is "
						% refused + "refused rather than bound, or the "
						+ "shared signal becomes a per-pack one")
			var pack_key := "%s/%s/%s" % [pack, theme, role]
			var row := _pack_row(pack_key)
			if not row.is_empty():
				var texture := _load("%s/%s" % [pack, theme], role, row)
				if texture != null:
					out["texture"] = texture
					out["source"] = "pack"
					out["key"] = pack_key
					return out
	# 2. THE FAMILY, EXACTLY AS IT RESOLVED BEFORE PACKS EXISTED.
	out.merge(_family(theme, role), true)
	return out

static func _family(theme: String, role: String) -> Dictionary:
	var none := {"texture": null, "source": "procedural", "key": ""}
	for refused: String in refusals(theme):
		_warn("theme '%s' ships a '%s' texture and that role is "
				% [theme, refused] + "universal; it is refused rather "
				+ "than bound, or the shared signal becomes six signals")
	var missing := disqualified(theme)
	if role in REQUIRED_ROLES and role in missing:
		_warn("theme '%s' ships no '%s' and that role is required; it "
				% [theme, role] + "falls back to the procedural texture "
				+ "and the rest of the pack still binds")
		return none
	var used := role
	var source := "family"
	var row := _row(theme, role)
	if row.is_empty():
		var hop := _fallback_role(role)
		if hop == "":
			return none
		row = _row(theme, hop)
		if row.is_empty():
			return none
		used = hop
		source = "fallback"
	var texture := _load(theme, role, row)
	if texture == null:
		return none
	return {"texture": texture, "source": source,
			"key": "%s/%s" % [theme, used]}

## One hop, through the descriptor's own tables. `glass: null` means NO
## fallback: asking for glass where a theme ships none is a refusal.
static func _fallback_role(role: String) -> String:
	var d := descriptor()
	var variants: Dictionary = d.get("variants", {})
	if variants.has(role):
		return str(variants[role])
	var fallbacks: Dictionary = d.get("optional_role_fallbacks", {})
	if fallbacks.has(role):
		var to: Variant = fallbacks[role]
		return "" if to == null else str(to)
	return ""

static func _row(theme: String, role: String) -> Dictionary:
	var textures: Dictionary = descriptor().get("textures", {})
	var row: Variant = textures.get("%s/%s" % [theme, role])
	return row if typeof(row) == TYPE_DICTIONARY else {}

static func _pack_table() -> Dictionary:
	var table: Variant = descriptor().get(PACK_TABLE, {})
	return table if typeof(table) == TYPE_DICTIONARY else {}

static func _pack_row(key: String) -> Dictionary:
	var row: Variant = _pack_table().get(key)
	return row if typeof(row) == TYPE_DICTIONARY else {}

## **The digest is checked when the bytes are readable** (clause 4).
## That is the editor and every headless run, which is where a mismatched
## export gets caught; an exported build turns the `.png` into a `.ctex`
## and the source bytes are gone, so the check is skipped there rather
## than failing every texture. `tools/content/verify_theme_export.py`
## checks the same digests against the exported pixels at build time,
## which is the half that survives packaging.
static func _load(theme: String, role: String,
		row: Dictionary) -> Texture2D:
	var rel := str(row.get("texture", ""))
	if rel == "":
		return null
	var path := "res://content/" + rel
	if not ResourceLoader.exists(path):
		_warn("theme '%s' declares '%s' at %s and it is not there"
				% [theme, role, path])
		return null
	var want := str(row.get("sha256_16", ""))
	if want != "" and FileAccess.file_exists(path):
		# OF THE FILE'S BYTES, which is what `verify_theme_set.py`
		# hashed when it wrote the row. Hashing the decoded pixels here
		# would be a different number and would refuse every texture.
		var got := FileAccess.get_sha256(path).substr(0, 16)
		if got != want:
			_warn("theme '%s' role '%s': %s digests %s and the "
					% [theme, role, path, got]
					+ "descriptor says %s, so it is not bound" % want)
			return null
	var texture: Texture2D = load(path)
	return texture

static func _warn(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	push_warning("theme: %s" % message)
