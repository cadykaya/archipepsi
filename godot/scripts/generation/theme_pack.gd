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

## Where the exported pack lives, as the contract names it.
const ROOT := "res://content/theme"
const DESCRIPTOR := ROOT + "/THEME_PACK.json"

## The roles a theme must ship authored pixels for. Hazard is NOT one;
## see the header. A theme missing any of these is disqualified for that
## role, falls back to `ProcTextures`, and says so once -- the pack
## still binds for every other theme and every other role.
const REQUIRED_ROLES := ["floor", "wall", "trim", "accent"]

## Resolved from the shared material and never from a per-theme texture.
const UNIVERSAL_ROLES := ["hazard"]

static var _descriptor: Dictionary = {}
static var _loaded := false
static var _warned := {}
static var _cache := {}

## A test seam, and the only one. `_descriptor_override` lets a suite
## install a pack with a required row REMOVED and observe the documented
## fallback -- which is the control this whole file needs and which
## cannot be produced by deleting a shipped file.
static var _descriptor_override: Dictionary = {}

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

## The authored texture for `(theme, role)`, or `null`.
##
## **Role, never path** (clause 1). **One fallback hop, never two**
## (clause 2), through the descriptor's own `optional_role_fallbacks`
## and `variants`, so a chain cannot end somewhere nobody chose.
static func texture_for(theme: String, role: String) -> Texture2D:
	if role in UNIVERSAL_ROLES:
		return null
	var key := "%s/%s" % [theme, role]
	if _cache.has(key):
		return _cache[key]
	var texture := _resolve(theme, role)
	_cache[key] = texture
	return texture

## How many metres one tile of `(theme, role)` covers, or 4.0 (clause 5).
static func covers_m(theme: String, role: String) -> float:
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

static func _resolve(theme: String, role: String) -> Texture2D:
	if not bound():
		return null
	for refused: String in refusals(theme):
		_warn("theme '%s' ships a '%s' texture and that role is "
				% [theme, refused] + "universal; it is refused rather "
				+ "than bound, or the shared signal becomes six signals")
	var missing := disqualified(theme)
	if role in REQUIRED_ROLES and role in missing:
		_warn("theme '%s' ships no '%s' and that role is required; it "
				% [theme, role] + "falls back to the procedural texture "
				+ "and the rest of the pack still binds")
		return null
	var row := _row(theme, role)
	if row.is_empty():
		var hop := _fallback_role(role)
		if hop == "":
			return null
		row = _row(theme, hop)
		if row.is_empty():
			return null
	return _load(theme, role, row)

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
