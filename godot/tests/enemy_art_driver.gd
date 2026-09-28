extends Node
## THE ART LANE'S ENEMIES IN THE GAME (`make godot-enemy-art`), ART-CATCHUP.
##
## The ten roles of batch 030 in their two value bands (Tier 1, RULED
## 2026-09-26) and the re-cut ranged and bulwark (Tier 2, ACCEPTED
## 2026-09-26), loaded by `Enemy.create` from `res://content/enemies`
## (`tools/import_enemy_models.sh`). What the ruling asks integration to
## carry across, asked of each role in each band:
##
##   the body       the role's own model, from its room's band's folder
##                  (`enemy_value_bands.json`, read, never restated)
##   the collider   unchanged: `ENEMY_ENVELOPES`, outside the model, and
##                  nothing solid inside the model
##   the eye        Production's own, kept: one, on the OUTSIDE of the
##                  body, dim / alert / flaring with the windup
##   damage         the body reddens as it is hurt (the A10 blocker)
##   the muzzle     a shot starts at the art's `anchor_muzzle`
##   the facing     -Z: strike, muzzle and shield in front, weak behind
##
## A room the band map does not name keeps the code-built body.

const ROOMS := ["concrete_facility", "gothic_stone", "neon_transit",
	"temple_ruin", "rusted_industrial", "void_glitch"]

var _failures := 0
var _checks := 0
var _notes := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_the_bands_are_the_art_lanes()
	await _every_role_in_every_band()
	await _the_eye_and_the_wound()
	await _a_wound_is_one_enemys()
	_the_muzzle_is_inside_the_collider()
	_a_room_without_a_band()
	print("GODOT ENEMY ART %s (%d checks, %d notes)" % [
		"OK" if _failures == 0 else "FAILED: %d" % _failures, _checks, _notes])
	get_tree().quit(0 if _failures == 0 else 1)


func _the_bands_are_the_art_lanes() -> void:
	print("  -- the value bands")
	var bands := {}
	for room: String in ROOMS:
		bands[room] = Enemy.band_for(room)
	_check(bands["rusted_industrial"] == "deep" and bands["void_glitch"] == "deep"
			and bands["concrete_facility"] == "standard"
			and bands["gothic_stone"] == "standard"
			and bands["neon_transit"] == "standard"
			and bands["temple_ruin"] == "standard",
			"each room's band is the ruled one, read from the art's map: %s" % [bands])


func _every_role_in_every_band() -> void:
	print("  -- every role, in every room")
	var bad: Array = []
	var built := 0
	var darker := {}
	for room: String in ROOMS:
		for kind: String in Constants.ENEMY_ARCHETYPES:
			var enemy := Enemy.create(kind, room)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(enemy)
			var model := enemy.visual.get_node_or_null("Model") as Node3D
			var want := "res://content/enemies/%s/enemy_role_%s.glb" % [
					Enemy.band_for(room), kind]
			if model == null or model.scene_file_path != want:
				bad.append("%s/%s: no art body from %s" % [room, kind, want])
				enemy.queue_free()
				continue
			built += 1
			var env: Dictionary = Constants.ENEMY_ENVELOPES[kind]
			# THE COLLIDER: the envelope's box, on the body, not the model.
			var box := Vector3.ZERO
			for child: Node in enemy.get_children():
				if child is CollisionShape3D:
					box = ((child as CollisionShape3D).shape as BoxShape3D).size
			var solid := model.find_children("*", "CollisionObject3D", true,
					false).size() + model.find_children("*", "CollisionShape3D",
					true, false).size()
			if not box.is_equal_approx(env["size"]) or solid != 0:
				bad.append("%s/%s: collider %s (want %s), %d solid in the model"
						% [room, kind, box, env["size"], solid])
			# THE FIT: the model's body inside the collider (a tolerance of
			# 4 cm a side: the art lane measured the brute 6.7 cm over its
			# width head-on, 3.35 cm a side, and asked Production to rule).
			var aabb := _body_aabb(enemy)
			var half: Vector3 = (env["size"] as Vector3) / 2.0
			var lo := Vector3(-half.x, float(env["bottom_y"]), -half.z) \
					- Vector3.ONE * 0.04
			var hi := Vector3(half.x, float(env["top_y"]), half.z) \
					+ Vector3.ONE * 0.04
			if not (Rect_in(aabb, lo, hi)):
				bad.append("%s/%s: the body %s leaves the collider %s..%s"
						% [room, kind, aabb, lo, hi])
			# THE FACING, from the anchors: front ones at -Z, weak behind.
			for a: String in ["anchor_strike", "anchor_shield"]:
				var n := enemy.anchor(a)
				if n != null and Enemy._in(enemy, n).z >= 0.0:
					bad.append("%s/%s: %s is not in front" % [room, kind, a])
			# A muzzle is never behind (the beacon's is on its crown, on the
			# centreline: it emits all round).
			var m := enemy.anchor("anchor_muzzle")
			if m != null and Enemy._in(enemy, m).z > 0.001:
				bad.append("%s/%s: anchor_muzzle is behind" % [room, kind])
			var weak := enemy.anchor("anchor_weak")
			if weak != null and Enemy._in(enemy, weak).z <= 0.0:
				bad.append("%s/%s: anchor_weak is not behind" % [room, kind])
			# THE MUZZLE: a shot starts where the player sees it fire from.
			var muzzle := enemy.anchor("anchor_muzzle")
			if muzzle != null:
				var at := Enemy._in(enemy, muzzle)
				if enemy.to_local(enemy.muzzle()).distance_to(at) > 0.001:
					bad.append("%s/%s: the shot starts %s, the muzzle is at %s"
							% [room, kind, enemy.to_local(enemy.muzzle()), at])
			# THE EYE: one, and on the outside of the body.
			var eyes := enemy.visual.find_children("Eye*", "MeshInstance3D",
					true, false)
			if eyes.size() != 1 or not _outside(enemy, eyes[0] as Node3D, kind):
				bad.append("%s/%s: %d eye(s), or the eye is inside the body"
						% [room, kind, eyes.size()])
			darker["%s/%s" % [Enemy.band_for(room), kind]] = _lightness(model)
			enemy.queue_free()
	await get_tree().process_frame
	_check(built == ROOMS.size() * Constants.ENEMY_ARCHETYPES.size() and bad.is_empty(),
			"all %d roles in all %d rooms wear the art body of their band, on "
			% [Constants.ENEMY_ARCHETYPES.size(), ROOMS.size()]
			+ "the unchanged collider, facing -Z, the eye outside, the shot "
			+ "from the muzzle (%d built): %s" % [built, bad])
	var lighter: Array = []
	for kind: String in Constants.ENEMY_ARCHETYPES:
		if float(darker.get("deep/" + kind, 1.0)) >= float(darker.get(
				"standard/" + kind, 0.0)):
			lighter.append(kind)
	_check(lighter.is_empty(), "the deep band is darker than the standard in "
			+ "every role (the value treatment): %s" % [lighter])


func _the_eye_and_the_wound() -> void:
	print("  -- the eye, and a wound")
	var bad: Array = []
	for kind: String in Constants.ENEMY_ARCHETYPES:
		var enemy := Enemy.create(kind, "concrete_facility")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)
		var eye := enemy.visual.find_children("Eye*", "MeshInstance3D", true,
				false)[0] as MeshInstance3D
		var glow := func() -> float:
			return (eye.material_override as StandardMaterial3D) \
					.emission_energy_multiplier
		enemy._set_eye(Enemy.EYE_IDLE)
		var idle: float = glow.call()
		enemy._set_eye(Enemy.EYE_WATCHING)
		var alert: float = glow.call()
		enemy._begin_telegraph("probe", 0.5)
		var flare: float = glow.call()
		enemy._end_telegraph(false)
		if not (idle < alert and alert < flare):
			bad.append("%s: eye idle %.2f, alert %.2f, windup %.2f" % [kind,
					idle, alert, flare])
		var model := enemy.visual.get_node("Model") as Node3D
		# The wound pulls the tint toward red: green falls (the body's colour
		# is in its texture; the tint multiplies it).
		var before := _green(model)
		enemy.take_damage(float(enemy.stats["hp"]) * 0.6, Vector3.FORWARD, 0.0)
		var after := _green(model)
		var reds := enemy._tint_parts.size()
		if reds == 0 or after >= before:
			bad.append("%s: %d tint parts; red %.3f -> %.3f" % [kind, reds,
					before, after])
		enemy.queue_free()
	await get_tree().process_frame
	_check(bad.is_empty(), "every role's eye still dims, wakes and flares at the "
			+ "windup, and every art body reddens as it is hurt: %s" % [bad])


## Imported surface materials are shared by every instance of a model, so
## a wound must unshare them PER ENEMY: hurting one ranged must not redden
## the ranged beside it.
func _a_wound_is_one_enemys() -> void:
	print("  -- a wound is one enemy's")
	var bad: Array = []
	for kind: String in Constants.ENEMY_ARCHETYPES:
		var hurt := Enemy.create(kind, "concrete_facility")
		var whole := Enemy.create(kind, "concrete_facility")
		for e: Enemy in [hurt, whole]:
			e.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(e)
		var model := whole.visual.get_node_or_null("Model") as Node3D
		if model == null:
			bad.append("%s: no art body" % kind)
		else:
			var before := _green(model)
			hurt.take_damage(float(hurt.stats["hp"]) * 0.6, Vector3.FORWARD, 0.0)
			var after := _green(model)
			if absf(after - before) > 0.0001:
				bad.append("%s: the unhurt one went %.3f -> %.3f" % [kind,
						before, after])
		hurt.queue_free()
		whole.queue_free()
	await get_tree().process_frame
	_check(bad.is_empty(), "hurting one enemy leaves another of its role "
			+ "untouched, in every role: %s" % [bad])


## Near a wall: the shot starts at the art's muzzle, and the collider is
## what keeps a body out of walls. So the muzzle must be INSIDE the
## collider -- then no enemy can stand where its shot starts inside or
## beyond a wall, whatever it faces.
func _the_muzzle_is_inside_the_collider() -> void:
	print("  -- the muzzle is inside the collider")
	var bad: Array = []
	var armed := 0
	for kind: String in Constants.ENEMY_ARCHETYPES:
		for room: String in ROOMS:
			var enemy := Enemy.create(kind, room)
			add_child(enemy)
			if enemy.anchor("anchor_muzzle") == null:
				# No art muzzle (the melee roles): muzzle() is then the
				# code's old sight point, unchanged by this integration.
				remove_child(enemy)
				enemy.free()
				continue
			var env: Dictionary = enemy.envelope
			var size: Vector3 = env["size"]
			var box := AABB(Vector3(-size.x / 2.0,
					float(env["centre_y"]) - size.y / 2.0, -size.z / 2.0), size)
			armed += 1
			var at := enemy.to_local(enemy.muzzle())
			if not box.grow(0.01).has_point(at):
				bad.append("%s/%s: muzzle %s, collider %s" % [room, kind, at,
						box])
			remove_child(enemy)
			enemy.free()
	_check(bad.is_empty() and armed > 0, "every role with an art muzzle "
			+ "(%d role/band pairs) shoots from inside its own collider: %s"
			% [armed, bad])


func _a_room_without_a_band() -> void:
	print("  -- a room the band map does not name")
	var enemy := Enemy.create("melee", "a_room_no_band_names")
	_check(enemy.visual.get_node_or_null("Model") == null
			and enemy.visual.get_child_count() > 0,
			"keeps the code-built body")
	enemy.free()


# ------------------------------------------------------------------ helpers

## The model's visible body, in the enemy's space, anchors left out.
func _body_aabb(enemy: Enemy) -> AABB:
	var out := AABB()
	var first := true
	for node: Node in enemy.visual.get_node("Model").find_children("*",
			"MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or part.name.begins_with("anchor"):
			continue
		var t := Enemy._xform_to(enemy, part)
		var box := t * part.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func Rect_in(box: AABB, lo: Vector3, hi: Vector3) -> bool:
	return box.position.x >= lo.x and box.position.y >= lo.y \
			and box.position.z >= lo.z and box.end.x <= hi.x \
			and box.end.y <= hi.y and box.end.z <= hi.z


## The eye stands on the body's outside: nothing of the body lies between
## it and a viewer the way the role looks (-Z; below, for the drifter).
func _outside(enemy: Enemy, eye: Node3D, kind: String) -> bool:
	var dir := Vector3.DOWN if kind == "drifter" else Vector3.FORWARD
	var at := Enemy._xform_to(enemy, eye).origin
	for node: Node in enemy.visual.get_node("Model").find_children("*",
			"MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or part.name.begins_with("anchor"):
			continue
		var t := Enemy._xform_to(enemy, part)
		var tri := part.mesh.generate_triangle_mesh()
		var hit: Dictionary = tri.intersect_ray(t.affine_inverse() * at,
				(t.basis.inverse() * dir).normalized())
		if not hit.is_empty():
			return false
	return true


## The model's surfaces' materials, anchors left out.
func _materials(model: Node3D) -> Array:
	var out: Array = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or part.name.begins_with("anchor"):
			continue
		for i in part.mesh.get_surface_count():
			var m := part.get_active_material(i) as StandardMaterial3D
			if m != null:
				out.append(m)
	return out


## The body's mean lightness: its texture's, times its albedo colour.
func _lightness(model: Node3D) -> float:
	var total := 0.0
	var n := 0
	for m: StandardMaterial3D in _materials(model):
		var value := m.albedo_color.get_luminance()
		if m.albedo_texture != null:
			var img := m.albedo_texture.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.resize(8, 8)
				var sum := 0.0
				for y in 8:
					for x in 8:
						sum += img.get_pixel(x, y).get_luminance()
				value *= sum / 64.0
		total += value
		n += 1
	return total / maxf(1.0, float(n))


## The mean green of the body's tint colours.
func _green(model: Node3D) -> float:
	var total := 0.0
	var mats := _materials(model)
	for m: StandardMaterial3D in mats:
		total += m.albedo_color.g
	return total / maxf(1.0, float(mats.size()))
