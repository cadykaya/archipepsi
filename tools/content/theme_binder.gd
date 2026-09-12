extends RefCounted
## THE SMALLEST CORRECT BINDER for the six-theme texture pack. A PROPOSAL.
##
## Art does not own the runtime retheme path and this file is not wired into
## the game. It exists because "prove a real exported theme actually binds
## authored floor and wall textures" cannot be answered by a validator that
## only reads bytes off disk, and "the Zone still builds" answers nothing at
## all -- the shipped `ThemeMaterials` builds every material from
## `ProcTextures`, so a Zone builds identically whether the pack is there,
## corrupt, or absent. Something has to actually bind before anything can be
## proved about binding.
##
## So this is the reference: the rules the descriptor states, implemented
## once, against the real exported files, so the proof harness has something
## real to interrogate and Production has something concrete to accept,
## reject or replace.
##
## ## The rules, and where each comes from
##
## 1. **The descriptor is the authority on roles.** `role_contract` says of
##    every role whether the pack must paint it, whether its absence
##    disqualifies the theme, and which engine accessor answers for it. This
##    reads those fields; it hardcodes no role list.
## 2. **A required role missing disqualifies the theme** -- `role_contract`
##    says so, per role. A disqualified theme binds NOTHING and the engine
##    keeps its procedural materials for it. It does not borrow another
##    theme's floor, and it does not bind five roles out of six.
## 3. **Clause 4: a texture whose digest does not match its row is not
##    bound.** The digest is over the PNG's file bytes, which is what
##    `verify_theme_set.py` wrote and `verify_theme_export.py` re-checks
##    against the exported copy. A file that is missing reads as zero bytes
##    and fails this the same way a corrupt one does.
## 4. **A role the pack does not paint is never bound from the pack.**
##    `roles_resolved_without_pack_pixels` names them -- today, `hazard`,
##    which is the theme's own accent colour through
##    `ThemeMaterials.hazard_mat` and, on a shell, the shared universal
##    hazard ramp. A pack that shipped hazard pixels would be the finding,
##    so this refuses them rather than binding them.
## 5. **An optional role missing falls back where the descriptor says.**
##    `optional_role_fallbacks` -- `ceiling` to `wall`, `metal` to `trim`,
##    and so on; a `null` means the role is simply absent and the theme is
##    still good.
## 6. **The material is the theme's material with its pixels replaced.**
##    Roughness, colour policy and every other property stay
##    `ThemeMaterials`', which is the authority on them. The bound material
##    is a DUPLICATE: `ThemeMaterials` caches and hands out one shared
##    instance per (theme, kind), and writing through it would retint the
##    procedural path for everything else in the process.
##
## `texture_filter` and `texture_repeat` are set HERE and not in the `.import`
## sidecars, because in Godot 4 they are sampler state on `BaseMaterial3D`
## and not importer parameters. That is the half of the contract the binder
## owns; the sidecars own mipmaps.

const FILTER := BaseMaterial3D.TEXTURE_FILTER_NEAREST
# `texture_repeat` is a BOOL on BaseMaterial3D in Godot 4, not an enum.
const REPEAT := true


## The descriptor ships INSIDE the pack folder while its texture rows are
## written relative to the content root above it -- a row reads
## `theme/<name>.png`. One argument, then, and the two paths derived from
## it, rather than a caller that has to remember which root is which.
const DESCRIPTOR := "theme/THEME_PACK.json"


static func load_pack(content_root: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(
			"%s/%s" % [content_root, DESCRIPTOR])
	if text == "":
		return {}
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func _digest16(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().substr(0, 16)


## The authored texture for one (theme, role), or null with a reason.
##
## `content_dir` is the `res://` ROOT the descriptor's paths hang off --
## `res://content`, because a row's `texture` reads `theme/<name>.png`. It
## has to be a `res://` path and not an OS one: `load()` resolves only
## Godot's own namespaces, so an absolute path returns null and every role
## reports "did not load" for a reason that is not the one being tested.
static func _authored(pack: Dictionary, content_dir: String, theme: String,
		role: String) -> Dictionary:
	var rows: Dictionary = pack.get("textures", {})
	var key := "%s/%s" % [theme, role]
	if not rows.has(key):
		return {"texture": null, "why": "the pack has no row for %s" % key}
	var row: Dictionary = rows[key]
	var path := "%s/%s" % [content_dir, row["texture"]]
	var got := _digest16(path)
	if got == "":
		return {"texture": null, "why": "%s is missing or empty" % path}
	if got != str(row["sha256_16"]):
		# Clause 4. Not bound, and said out loud rather than passed through.
		return {"texture": null,
				"why": "%s digests %s, the descriptor says %s"
						% [key, got, row["sha256_16"]]}
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return {"texture": null, "why": "%s did not load as a Texture2D" % path}
	return {"texture": texture, "why": "", "row": row}


static func _accessor(theme: String, role: String) -> StandardMaterial3D:
	match role:
		"floor": return ThemeMaterials.floor_mat(theme)
		"wall", "wall_ribbed": return ThemeMaterials.wall_mat(theme)
		"accent", "decal", "emissive": return ThemeMaterials.accent_mat(theme)
		"trim", "trim_plain", "metal": return ThemeMaterials.trim_mat(theme)
		"hazard": return ThemeMaterials.hazard_mat(theme)
		"ceiling": return ThemeMaterials.wall_mat(theme)
	return ThemeMaterials.wall_mat(theme)


## Bind one theme. Returns
##   {bound: {role: StandardMaterial3D}, authored: {role: bool},
##    disqualified: bool, why: [..], fell_back: {role: role}}
## `bound` always answers for every contracted role: a disqualified theme's
## roles are the engine's procedural materials, which is what the game has
## today and what it keeps when the pack cannot be trusted.
static func bind(pack: Dictionary, content_dir: String,
		theme: String) -> Dictionary:
	var contract: Dictionary = pack.get("role_contract", {})
	var fallbacks: Dictionary = pack.get("optional_role_fallbacks", {})
	var texels := float(pack.get("texels_per_metre", 32))
	var out := {"bound": {}, "authored": {}, "disqualified": false,
			"why": [], "fell_back": {}, "theme": theme}

	# Pass one: which roles have trustworthy authored pixels, and is any
	# REQUIRED one missing? The verdict has to be reached before a single
	# material is built, or a disqualified theme ends up half-bound.
	var found := {}
	for role: String in contract:
		var rule: Dictionary = contract[role]
		if str(rule.get("pack_pixels", "")) == "never":
			continue  # rule 4: not the pack's to paint.
		var got := _authored(pack, content_dir, theme, role)
		if got["texture"] != null:
			found[role] = got["texture"]
		elif bool(rule.get("disqualifies_theme_if_missing", false)):
			out["disqualified"] = true
			out["why"].append("required role %s: %s" % [role, got["why"]])
		elif fallbacks.has(role) and fallbacks[role] != null:
			out["fell_back"][role] = fallbacks[role]

	# Pass two: the materials.
	for role: String in contract:
		var base: StandardMaterial3D = _accessor(theme, role)
		var material: StandardMaterial3D = base
		var source := role
		if out["fell_back"].has(role):
			source = str(out["fell_back"][role])
		var texture: Texture2D = found.get(source, null)
		if texture != null and not out["disqualified"]:
			# Rule 6: the theme's material, its pixels replaced. DUPLICATE.
			material = base.duplicate() as StandardMaterial3D
			material.albedo_texture = texture
			material.texture_filter = FILTER
			material.texture_repeat = REPEAT
			material.uv1_triplanar = false  # the pack is authored per face
			var covers := float(texture.get_width()) / texels
			material.uv1_scale = Vector3.ONE / covers
			out["authored"][role] = true
		else:
			out["authored"][role] = false
		out["bound"][role] = material
	return out
