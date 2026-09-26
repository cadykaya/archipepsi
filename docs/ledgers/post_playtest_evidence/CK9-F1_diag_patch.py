"""Instrument transport_driver._clear_room for the CK9-F1 diagnosis:
every 120 frames (and at the end), print the player's place and each
living enemy's place, and what the camera ray hits when aimed at it.
Applied to a diagnosis worktree only; never committed."""
import sys
p = sys.argv[1] + "/godot/tests/transport_driver.gd"
s = open(p).read()
old = '''		_track_damage(player)
		await get_tree().physics_frame
		frames += 1
		still = still + 1 if strafing \\
				and was.distance_to(player.global_position) < 0.02 else 0
		was = player.global_position
	Input.action_release(strafe)
	Input.action_release("fire_pulse")
'''
new = '''		_track_damage(player)
		if frames % 120 == 0:
			_diag_clear(controller, room, player, frames, sighted, strafing)
		await get_tree().physics_frame
		frames += 1
		still = still + 1 if strafing \\
				and was.distance_to(player.global_position) < 0.02 else 0
		was = player.global_position
	_diag_clear(controller, room, player, frames, null, strafing)
	Input.action_release(strafe)
	Input.action_release("fire_pulse")
'''
assert s.count(old) == 1, "anchor"
s = s.replace(old, new)
s += '''

func _diag_clear(controller: ZoneController, room: String, player: Player,
		frames: int, sighted: Variant, strafing: bool) -> void:
	var alive := _living_in(controller, room)
	print("DIAG f%d player %s room '%s' floor %s vel %s strafing %s sighted %s alive %d"
			% [frames, str(player.global_position.snapped(Vector3.ONE * 0.01)),
				_room_holding(controller, player.global_position),
				str(player.is_on_floor()), str(player.velocity.snapped(Vector3.ONE * 0.01)),
				str(strafing), str(sighted != null), alive.size()])
	var yaw := player.rotation.y
	var pitch := player.camera.rotation.x
	for raw: Variant in alive:
		var e: Enemy = raw
		_aim_at_enemy(player, e)
		var ray := player.camera_ray(Constants.STATIC_PULSE_RANGE)
		var hit := "nothing"
		if not ray.is_empty():
			var c: Object = ray["collider"]
			hit = "%s (%s) at %s" % [str((c as Node).get_path()) if c is Node else str(c),
					c.get_class(), str((ray["position"] as Vector3).snapped(Vector3.ONE * 0.01))]
		print("DIAG   %s at %s room '%s' dist %.2f vel %s noticed %s dive %.2f hover_y %.2f telegraph '%s' -> ray hits %s"
				% [e.name, str(e.global_position.snapped(Vector3.ONE * 0.01)),
					_room_holding(controller, e.global_position),
					e.global_position.distance_to(player.global_position),
					str(e.velocity.snapped(Vector3.ONE * 0.01)), str(e._has_noticed),
					float(e.get("_dive")), float(e.get("_hover_y")),
					str(e.telegraph_kind), hit])
	player.rotation.y = yaw
	player.camera.rotation.x = pitch
'''
open(p, "w").write(s)
print("patched")
