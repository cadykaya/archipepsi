extends SceneTree
## Runs PRODUCTION'S OWN ContentRegistry against the exported pack, plus the
## two refusals `ContentInstantiator` applies before it will use an authored
## asset: a housing may carry no `Light3D`, a projectile no collision.
##
## Nothing here re-implements a rule. The validator is Production's file; the
## two mechanical adaptations the copy needs, and why they are safe, are
## documented at the transform in `tools/verify_content_pack.sh`.
##
## Preloaded BY PATH rather than by `class_name`. Godot's global class cache
## does not register a script dropped into the project between runs, and an
## earlier version of this file referenced the globals and passed only
## because a stale cache still held a registration from a previous copy. A
## verifier that passes because of a cache is not a verifier.
const Registry := preload("res://_harness/content_registry.gd")
const Ownership := preload("res://_harness/visual_ownership.gd")

func _initialize() -> void:
	var fails := 0
	var reg: Object = Registry.new()
	var ok: bool = reg.load_all("res://content/registry")
	print("[verify] load_all -> %s" % ok)
	for problem in reg.errors:
		print("[verify]   PROBLEM: %s" % problem)
		fails += 1

	# 1. Every id the runtime asks for resolves to the AUTHORED entry.
	# id -> must it pass the shippable gate?
	#
	# NOT "everything is shippable". Production reverted the authored
	# projectile substitutions after the A/B, so `pending` is the CORRECT
	# state for those three and a verifier that demanded `pass` would block
	# the very fix that records the reversal. What matters is that each
	# family exports the state the owner actually decided.
	var wanted := {
		"fixture_light_concrete_facility": true,
		"fixture_light_rusted_industrial": true,
		"fixture_light_neon_transit": true,
		"fixture_light_gothic_stone": true,
		"fixture_light_temple_ruin": true,
		"fixture_light_void_glitch": true,
		"projectile_straight": false,
		"projectile_falling": false,
		"projectile_lobbed": false,
		# P2: the eight dimensionless F3 shells. Held PENDING per the
		# room-architecture study's §16 -- the owner flips per entry, and
		# they are not player-selectable regardless because
		# `SHELL_FOR_TYPE` still names the `_proc` ids.
		"shell_tower_collapsed": false,
		"shell_tower_spiral": false,
		"shell_tower_gantry": false,
		"shell_treasure_vault": false,
		"shell_treasure_cache": false,
		"shell_treasure_coffer": false,
		"shell_corner_left": false,
		"shell_corner_right": false,
	}
	for id in wanted:
		var want_shippable: bool = wanted[id]
		if not reg.has(id):
			print("[verify]   FAIL: registry has no '%s'" % id); fails += 1; continue
		var chosen: String = reg.resolve(id)
		var entry: Dictionary = reg.get_entry(chosen)
		var authored := not bool(entry.get("procedural_fallback", false))
		var shippable: bool = Ownership.is_shippable(entry)
		if chosen != id or not authored or shippable != want_shippable:
			print("[verify]   FAIL: '%s' resolved to '%s' authored=%s shippable=%s (wanted %s)"
					% [id, chosen, authored, shippable, want_shippable]); fails += 1
			continue
		# 2. The scene loads, is a Node3D, and carries neither of the two
		#    things the instantiator refuses.
		var scene: PackedScene = load(str(entry.get("scene", "")))
		if scene == null:
			print("[verify]   FAIL: '%s' scene did not load" % id); fails += 1; continue
		var inst := scene.instantiate()
		if not (inst is Node3D):
			print("[verify]   FAIL: '%s' is not a Node3D" % id); fails += 1
			inst.free(); continue
		var lights := _count(inst, "Light3D")
		var colliders := _count(inst, "CollisionObject3D")
		var meshes := _count(inst, "MeshInstance3D")
		# THE TWO REFUSALS ARE SCOPED, AND THIS USED TO IGNORE THAT.
		#
		# `ContentInstantiator` refuses a light on a LIGHT HOUSING and
		# refuses collision on a PROJECTILE VISUAL, each in its own
		# function, each with its own reason: a housing that ships a
		# light changes how bright a room is by being installed, and a
		# projectile's hitbox is the engine's because gameplay depends
		# on it. Neither is a statement about room shells, which take a
		# different path entirely and whose collision `RoomAudit`
		# REQUIRES.
		#
		# This check applied both rules to all seventeen and so refused
		# the eight shells the moment they were given the collision they
		# were missing. It was the third place the prop rule had been
		# written down as if it were the lane's rule -- after
		# ASSET_AUTHORING section 5 and the shells themselves.
		var is_shell: bool = str(entry.get("category", "")) == "room_shell"
		if lights > 0:
			print("[verify]   FAIL: '%s' carries %d Light3D; illumination is engine-owned"
					% [id, lights]); fails += 1
		if colliders > 0 and not is_shell:
			print("[verify]   FAIL: '%s' carries %d collision object; hitboxes are engine-owned"
					% [id, colliders]); fails += 1
		if colliders == 0 and is_shell:
			print("[verify]   FAIL: '%s' is a room shell with NO collision; "
					% id + "the audit can only report that nothing is there"); fails += 1
		if meshes == 0:
			print("[verify]   FAIL: '%s' has no mesh -- an invisible asset" % id); fails += 1
		if lights == 0 and meshes > 0 and (colliders > 0) == is_shell:
			print("[verify]   ok  %-32s authored, %d mesh, 0 lights, %d colliders, %s"
					% [id, meshes, colliders,
						"SHIPS" if want_shippable else "held PENDING"])
		inst.free()

	# 3. The procedural entries are still reachable as the fallback.
	for id in ["fixture_light_neon_transit_proc", "shell_corridor_proc"]:
		if not reg.has(id):
			print("[verify]   FAIL: lost procedural '%s'" % id); fails += 1
		else:
			print("[verify]   ok  %-32s still present as fallback" % id)

	# 4. Room shells are NOT exported: nothing authored may sit on the
	#    dimension-bearing seam during the A/B.
	for id in ["shell_corridor_proc", "shell_arena_proc", "shell_tower_proc",
			"shell_platform_path_proc", "shell_treasure_room_proc"]:
		var e: Dictionary = reg.get_entry(reg.resolve(id))
		if not bool(e.get("procedural_fallback", false)):
			print("[verify]   FAIL: '%s' resolves to authored geometry" % id); fails += 1
	print("[verify]   ok  all five room shells still resolve to the procedural builder")

	print("[verify] %s" % ("PASS" if fails == 0 else "FAIL -- %d problem(s)" % fails))
	quit(0 if fails == 0 else 1)

func _count(node: Node, cls: String) -> int:
	var n := 1 if node.is_class(cls) else 0
	for child in node.get_children():
		n += _count(child, cls)
	return n
