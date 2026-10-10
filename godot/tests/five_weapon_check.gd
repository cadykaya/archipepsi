class_name FiveWeaponCheck
extends Node
## THE FIVE-WEAPON RANGE, CHECKED IN THE REAL GAME.
##
##   godot --headless --fixed-fps 60 --path godot -- --five-weapons \
##       --five-weapon-check [--weapon=sightline]
##
## Beside the real `Main`. Fires by the input a tester presses (the left
## button, held or clicked; the number keys); aims by setting the look
## angles. It proves mechanics and presentation timing, not fun:
##
## 1. **Isolation and the range:** no bridge, no enemies, every target and
##    its material tag, the loose bodies are the game's `ManipulableBody`,
##    the Static Pulse's numbers unchanged.
## 2. **Each weapon, one shot:** selected by its key; fired through its
##    `EchoRuntime` primitive (the Pulse held); the damage the primitive
##    says; the engine's tracer hidden and the range's drawn from the
##    visible muzzle to the engine's resolved hit; the aim never moves;
##    the recoil and when it settles; the material event and its mark;
##    the fire cue and its level.
## 3. **Cadence:** clicked or held, each weapon fires at its own rate;
##    the carbine's spread grows; the semi-automatics fire once a press.
## 4. **Materials:** metal sparks, stone chips, organic fibres (no sparks,
##    no light), wood splinters, a grazing hit's mark on the surface; no
##    untagged surface anywhere.
## 5. **Marks:** they outlast the old 8 s fade, ride a moving target,
##    recycle the oldest past the cap, and go with a reset target.
## 6. **The 40 HP target, Mass Driver, Bulkhead's range:** a kill and a
##    stand-up; early versus full charge, travel time, and a push that
##    moves the light crate further than the steel weight; close blasts
##    landing more pellets than far ones.
## 7. **Switching, motion, pause, restart, references:** mid-charge
##    switches leave nothing held; reduced motion stills the camera; the
##    menu fires nothing; RESTART resets targets and marks; Heavy Report
##    and the Static Pulse are the delivered ones.

const FLAG := "--five-weapon-check"
const FPS := 60.0
const AIM_DUMMY := Vector3(0, 1.2, -10)
const RW := preload("res://scripts/content/range_weapons.gd")
const RI := preload("res://scripts/content/range_impacts.gd")
const RA := preload("res://scripts/content/range_audio.gd")
const KEYS := {"foundry": KEY_1, "sightline": KEY_2, "switchback": KEY_3,
		"bulkhead": KEY_4, "driver": KEY_5}
## What one shot at the dummy should deal (the Mass Driver's full charge).
const DAMAGE := {"foundry": 15.0, "sightline": 8.0, "switchback": 3.5,
		"bulkhead": 4.5, "driver": 45.0}

var failures := 0
var host: WeaponFeel
var body: Player
var weapons: RangeWeapons
var _pulses := 0
var _kills := 0


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "FiveWeaponCheck"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var existing := get_tree().root.get_node_or_null("FiveWeaponCheck")
	if existing != null and existing != self:
		queue_free()
		return
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("[five]   ok    " if ok else "[five]   FAIL  ") + what)
	if not ok:
		failures += 1


func _note(what: String) -> void:
	print("[five]   note  " + what)


func _phase(name_in: String) -> void:
	print("[five] --- %s" % name_in)


func _run() -> void:
	reparent(get_tree().root)
	await _settle(10)
	if not _bind():
		_check(false, "the range was built")
		get_tree().quit(1)
		return
	await _isolation_and_range()
	var shots := {}
	for id in RW.IDS:
		shots[id] = await _one_shot(id)
	_distinct(shots)
	await _cadence()
	await _materials()
	await _marks()
	await _mannequin()
	await _driver()
	await _bulkhead_range()
	await _switching()
	await _pause_restart()
	print("[five] %s -- %d failure(s)" % ["PASS" if failures == 0 else "FAILED",
			failures])
	Input.action_release("fire_pulse")
	get_tree().quit(1 if failures > 0 else 0)


func _bind() -> bool:
	var scene := get_tree().current_scene
	host = scene.get_node_or_null("WeaponFeel") as WeaponFeel \
			if scene != null else null
	if host == null or not host.five:
		return false
	body = host.player
	weapons = host.weapons
	if not body.fired_pulse.is_connected(_count_pulse):
		body.fired_pulse.connect(_count_pulse)
	if not body.hit_confirmed.is_connected(_count_kill):
		body.hit_confirmed.connect(_count_kill)
	return weapons != null and body != null


func _count_pulse() -> void:
	_pulses += 1


func _count_kill(killed: bool) -> void:
	if killed:
		_kills += 1


# ======================================================= 1. the range

func _isolation_and_range() -> void:
	_phase("isolation and the range")
	_check(BridgeClient.isolated and not BridgeClient.online,
			"the bridge client is isolated and offline (no socket opened)")
	_check(ReviewIsolation.active() and ReviewIsolation.five(),
			"the five-weapon range is an isolated review build")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "no enemies")
	var tags := {
		"the metal dummy": [host.dummy, "metal"],
		"the 40 HP target": [host.mannequin, "organic"],
		"the gel block": [host.gel, "organic"],
		"the moving dummy": [host.mover, "metal"],
		"the loose crate": [host.loose_crate, "wood"],
		"the loose steel weight": [host.loose_weight, "metal"],
		"the concrete pillar": [host.get_node("Range/ConcretePillar"), "stone"],
		"the back wall": [host.get_node("Range/BackWall"), "stone"],
		"the floor": [host.get_node("Range/Floor"), "stone"],
		"the steel plate": [host.get_node("Range/SteelPlate"), "metal"],
	}
	var wrong := []
	for what in tags:
		var entry: Array = tags[what]
		if RI.material_of(entry[0]) != entry[1]:
			wrong.append(what)
	_check(wrong.is_empty(), "every surface reads its material: %s (wrong: %s)"
			% [", ".join(tags.keys()), str(wrong)])
	_check(host.loose_crate is ManipulableBody
			and host.loose_weight is ManipulableBody
			and is_equal_approx(host.loose_crate.mass, 12.0)
			and is_equal_approx(host.loose_weight.mass, 36.0),
			"the loose bodies are the game's ManipulableBody (12 kg crate, "
			+ "36 kg weight)")
	_check(is_equal_approx(Constants.STATIC_PULSE_DAMAGE, 6.0)
			and is_equal_approx(Constants.STATIC_PULSE_COOLDOWN, 0.35),
			"the Static Pulse is the game's: 6 a hit, one per 0.35 s")
	_check(weapons.current == WeaponFeel.requested_weapon()
			or (WeaponFeel.requested_weapon() not in RW.IDS
				and weapons.current == "foundry"),
			"the range starts in the weapon asked for (%s)" % weapons.current)


# ===================================================== 2. one shot each

func _one_shot(id: String) -> Dictionary:
	_phase(String(RW.PROFILES[id]["name"]))
	await _key(KEYS[id])
	var p: Dictionary = RW.PROFILES[id]
	var rig := weapons.rig
	_check(weapons.current == id and host._which.text == p["name"]
			and (rig.models[id] as Node3D).visible and rig.visible
			and not body.viewmodel.visible
			and weapons.runtime.equipped.get("component_id") == "range_" + id,
			"key %s takes it out: named on screen, its own gun, its action on "
			% OS.get_keycode_string(KEYS[id]) + "the Echo slot")
	host.recover()
	await _settle(30)
	if id == "bulkhead":
		# A scattergun is fired where it belongs: up close (4 m).
		body.set_spawn(Transform3D(Basis(), Vector3(0, 0.05, -6.0)))
		body.velocity = Vector3.ZERO
		await _settle(20)
	_aim(AIM_DUMMY)
	await _settle(6)
	weapons.impacts.clear()
	await _settle(2)
	var aim := -body.camera.global_basis.z
	var absorbed := host.dummy.absorbed
	var pulses := _pulses
	var shots := weapons.shots
	var audio_from := weapons.audio.played.size()
	var marks_before := weapons.impacts.live_marks()
	var t := {"back": [], "pitch": [], "light": [], "aim": [], "rest": []}
	Input.action_press("fire_pulse")
	if id == "driver":
		await _settle(int(1.25 * FPS))
		Input.action_release("fire_pulse")
	# Sampled from the trigger on, so the shot's own frame is in it.
	var visible_tracers := 0
	for i in 64:
		await get_tree().process_frame
		if i == 2 and id != "driver":
			Input.action_release("fire_pulse")
		t["back"].append(rig.spring("back").x)
		t["pitch"].append(rig.spring("pitch").x)
		t["light"].append(rig.light.light_energy)
		t["aim"].append(rad_to_deg(aim.angle_to(-body.camera.global_basis.z)))
		t["rest"].append(0.0 if rig.at_rest() else 1.0)
		if i < 3:
			for node in get_tree().current_scene.find_children("*", "Tracer",
					true, false):
				if (node as Node3D).visible:
					visible_tracers += 1
	await _settle(20)
	var dealt := host.dummy.absorbed - absorbed
	var shot: Dictionary = weapons.last_shot
	var ends: Array = shot.get("ends", [])
	var want: float = DAMAGE[id]
	if id == "bulkhead":
		var on_dummy := 0
		for end in ends:
			if end["hit"].get("collider") == host.dummy:
				on_dummy += 1
		want = 4.5 * on_dummy
		_note("bulkhead: %d of 8 pellets on the dummy at 4 m" % on_dummy)
	_check(weapons.shots == shots + 1 and _pulses == pulses,
			"one shot through its %s primitive, and the Static Pulse held "
			% p["action"]["primitive"]["type"] + "(no Pulse fired)")
	_check(absf(dealt - want) < 0.01 and dealt > 0.0,
			"damage: %.1f (the primitive's %.1f)" % [dealt, want])
	if id != "driver":
		var origin_ok := true
		var truth_ok := true
		for end in ends:
			origin_ok = origin_ok and (end["from"] as Vector3).distance_to(
					shot["muzzle"]) < 1e-3
			if not end["hit"].is_empty():
				truth_ok = truth_ok and (end["to"] as Vector3).distance_to(
						end["hit"]["position"]) < 0.06
		var lined := true
		if float(p["action"]["primitive"]["spread_degrees"]) == 0.0 \
				and not ends.is_empty() and not ends[0]["hit"].is_empty():
			var eye := body.camera.global_position
			lined = rad_to_deg(aim.angle_to((ends[0]["hit"]["position"]
					as Vector3) - eye)) < 0.05
		_check(visible_tracers == 0 and ends.size() == int(
				p["action"]["primitive"].get("pellets", 1)) and origin_ok
				and truth_ok and lined,
				"%d tracer(s) from the visible muzzle to the engine's resolved "
				% ends.size() + "hit; the engine's own beam never shows; a "
				+ "zero-spread shot lands on the crosshair's line")
	var aim_peak := 0.0
	for v in t["aim"]:
		aim_peak = maxf(aim_peak, float(v))
	_check(aim_peak < 1e-4, "the aim never moves (%.6f degrees)" % aim_peak)
	var back := _peak(t["back"])
	var pitch := _peak(t["pitch"])
	var settled := _rest_frame(t["rest"])
	var budget := ceili(float(p["action"]["cooldown"]) * FPS)
	_check(back > 0.0 and pitch > 0.0 and settled > 0
			and (settled <= budget or id == "switchback"),
			"recoil: %.3f m back, %.1f degrees up; settled after %s%s"
			% [back, pitch, _ms(settled), "" if id == "switchback"
				else " (the next shot: %s)" % _ms(budget)])
	_check(_peak(t["light"]) > 0.5, "the muzzle light flares (%.1f)"
			% _peak(t["light"]))
	var info: Dictionary = weapons.impacts.last
	var marks := weapons.impacts.live_marks() - marks_before
	var sparks_ok: bool = info.get("material") == "metal" \
			and "Sparks" in info.get("parts", [])
	_check(sparks_ok and marks >= 1
			and (marks <= 4 if id == "bulkhead" else marks <= 1),
			"on the metal dummy: sparks and %d persistent mark(s)" % marks)
	var fire := ""
	for entry in weapons.audio.played.slice(audio_from):
		if entry[0] == id and entry[1] in ["fire", "release"]:
			fire = "%s (%s)" % [entry[1], entry[3]]
	var cue := "release" if id == "driver" else "fire"
	var slot: Dictionary = weapons.audio.slots[id][cue]
	var level := RA.rms_db_of(slot["streams"][0]) + float(slot["gains"][0])
	_check(fire != "" and (slot["source"] != "placeholder"
			or absf(level - RA.TARGET_RMS_DB) < 1.0),
			"its %s sound plays: %s, level-matched to %.1f dB RMS"
			% [cue, fire, level])
	return {"back": back, "pitch": pitch, "settled": settled}


func _distinct(shots: Dictionary) -> void:
	var seen := {}
	for id in shots:
		seen["%.3f/%.1f" % [shots[id]["back"], shots[id]["pitch"]]] = id
	var parts: PackedStringArray = []
	for id in RW.IDS:
		parts.append("%s %.2f m %.0f°" % [id, shots[id]["back"],
				shots[id]["pitch"]])
	_check(seen.size() == RW.IDS.size(), "five different recoils (back, rise): %s"
			% ", ".join(parts))


# =========================================================== 3. cadence

func _cadence() -> void:
	_phase("cadence")
	for id in ["foundry", "sightline", "bulkhead"]:
		await _key(KEYS[id])
		host.recover()
		await _settle(20)
		_aim(AIM_DUMMY)
		await _settle(int(2.0 * FPS))
		var shots := weapons.shots
		Input.action_press("fire_pulse")
		await _settle(int(1.5 * FPS))
		Input.action_release("fire_pulse")
		var held := weapons.shots - shots
		var frames: Array = []
		for press in 20:
			Input.action_press("fire_pulse")
			await _settle(2)
			Input.action_release("fire_pulse")
			await _settle(4)
			if weapons.shots - shots - held > frames.size():
				frames.append(Engine.get_physics_frames())
		var gaps := _gaps(frames)
		var want := float(RW.PROFILES[id]["action"]["cooldown"]) * FPS
		var even := not gaps.is_empty()
		for gap in gaps:
			even = even and absf(gap - want) <= 6.5
		_check(held == 1 and even,
				"%s: a held trigger fires once; clicking 10 a second fires at "
				% id + "its own pace (gaps %s frames, about %.0f)" % [str(gaps),
				want])
	await _key(KEY_3)
	host.recover()
	await _settle(20)
	_aim(AIM_DUMMY)
	await _settle(30)
	var shots := weapons.shots
	var spreads: Array = []
	Input.action_press("fire_pulse")
	for i in int(1.0 * FPS):
		await get_tree().physics_frame
		if weapons.shots - shots > spreads.size():
			spreads.append(float(weapons.last_shot.get("spread", 0.0)))
	Input.action_release("fire_pulse")
	var fired := weapons.shots - shots
	_check(fired >= 6 and fired <= 8 and spreads.size() > 2
			and float(spreads[-1]) > float(spreads[0]),
			"switchback: held for 1 s it fires %d rounds, the spread growing %.1f"
			% [fired, spreads[0]] + " -> %.1f degrees" % spreads[-1])


# ========================================================= 4. materials

func _materials() -> void:
	_phase("materials")
	await _key(KEY_1)
	var aims := {
		"metal": host.STEEL_AT + Vector3(0, 1.3, 0),
		"stone": host.PILLAR_AT + Vector3(0, 1.3, 0.31),
		"organic": host.GEL_AT + Vector3(0, 0.5, 0),
		"wood": host.CRATE_AT + Vector3(0, 0.5, 0),
	}
	for kind in aims:
		await _shoot_at(aims[kind])
		var info: Dictionary = weapons.impacts.last
		var names: Array = info.get("parts", [])
		var want: String = {"metal": "Sparks", "stone": "Chips",
				"organic": "Fibres", "wood": "Splinters"}[kind]
		var ok: bool = info.get("material") == kind and want in names
		if kind == "organic":
			ok = ok and not "Sparks" in names and not "Light" in names
		_check(ok, "%s: the event is %s (%s)%s" % [kind, want,
				", ".join(names), ": no sparks, no light"
				if kind == "organic" else ""])
	# A grazing hit on the floor: the mark lies on the surface.
	var eye := body.camera.global_position
	await _shoot_at(Vector3(eye.x + 1.0, 0.0, eye.z - 7.0))
	var info: Dictionary = weapons.impacts.last
	var mark: Decal = weapons.impacts.marks[-1]
	var normal: Vector3 = info.get("normal", Vector3.ZERO)
	_check(info.get("material") == "stone"
			and mark.global_basis.y.normalized().dot(normal) > 0.999
			and mark.global_position.distance_to(info["at"]) < 0.01,
			"a grazing hit on the floor: the mark sits at the hit, square to "
			+ "the surface (normal %s)" % _v(normal))
	_check(weapons.impacts.unknown_hits == 0, "no untagged surface was hit")


# ============================================================= 5. marks

func _marks() -> void:
	_phase("marks")
	await _key(KEY_1)
	await _shoot_at(host.PILLAR_AT + Vector3(0.2, 1.6, 0.31))
	var kept: Decal = weapons.impacts.marks[-1]
	await _settle(int(9.0 * FPS))
	_check(is_instance_valid(kept) and kept.modulate.a > 0.99,
			"a mark outlasts the old 8 s fade, untouched")
	# Riding a moving target.
	await _key(KEY_2)
	host.recover()
	await _settle(20)
	var on_mover: Decal = null
	for attempt in 6:
		_aim(host.mover.global_position + Vector3(0, 0.2, 0))
		await _settle(2)
		Input.action_press("fire_pulse")
		await _settle(2)
		Input.action_release("fire_pulse")
		await _settle(25)
		for decal in weapons.impacts.marks:
			if is_instance_valid(decal) and decal.get_parent() == host.mover:
				on_mover = decal
		if on_mover != null:
			break
	var was := on_mover.global_position if on_mover != null else Vector3.ZERO
	await _settle(30)
	_check(on_mover != null and on_mover.global_position.distance_to(was) > 0.05,
			"a mark on the moving dummy rides with it (moved %.2f m)"
			% (on_mover.global_position.distance_to(was)
				if on_mover != null else 0.0))
	# The cap: the oldest goes.
	var first: Decal = weapons.impacts.marks[0]
	var wall: Node = host.get_node("Range/BackWall")
	for i in RI.MARK_CAP + 20:
		weapons.impacts.impact(Vector3(-4.0 + (i % 40) * 0.2,
				0.5 + int(i / 40.0) * 0.4,
				-22.0), Vector3(0, 0, 1), wall.get_child(0), 0.1, 0.3, false)
	await get_tree().process_frame
	_check(weapons.impacts.live_marks() == RI.MARK_CAP
			and not is_instance_valid(first),
			"past %d marks the oldest are recycled (%d live)"
			% [RI.MARK_CAP, weapons.impacts.live_marks()])
	weapons.impacts.clear()
	await _settle(2)


# =================================================== 6. targets, driver

func _mannequin() -> void:
	_phase("the 40 HP target")
	await _key(KEY_1)
	host.recover()
	await _settle(20)
	var at := host.MANNEQUIN_AT + Vector3(0, 1.0, 0)
	var kills := _kills
	for i in 3:
		await _shoot_at(at)
		await _settle(int(0.75 * FPS))
	var marked := 0
	for child in host.mannequin.get_children():
		if child is Decal:
			marked += 1
	_check(host.mannequin.down and _kills == kills + 1 and marked >= 1,
			"three Foundry shots (45) drop it: the kill confirms, it falls, "
			+ "its %d mark(s) on it" % marked)
	await _settle(int(3.2 * FPS))
	var left := 0
	for child in host.mannequin.get_children():
		if child is Decal and not child.is_queued_for_deletion():
			left += 1
	_check(not host.mannequin.down and is_equal_approx(host.mannequin.hp, 40.0)
			and host.mannequin.basis.is_equal_approx(Basis()) and left == 0,
			"2.5 s later it stands again at 40 HP, its marks gone with the "
			+ "damage")


func _driver() -> void:
	_phase("Mass Driver")
	await _key(KEY_5)
	host.recover()
	await _settle(20)
	_aim(AIM_DUMMY)
	await _settle(int(2.0 * FPS))
	var absorbed := host.dummy.absorbed
	Input.action_press("fire_pulse")
	await _settle(int(0.2 * FPS))
	Input.action_release("fire_pulse")
	await _settle(40)
	var early := host.dummy.absorbed - absorbed
	_check(early >= 10.0 and early < 20.0,
			"an early release (0.2 s) still fires, weaker: %.1f damage" % early)
	await _settle(int(2.0 * FPS))
	absorbed = host.dummy.absorbed
	Input.action_press("fire_pulse")
	await _settle(int(1.25 * FPS))
	var release := Engine.get_physics_frames()
	Input.action_release("fire_pulse")
	var landed := -1
	for i in 60:
		await get_tree().physics_frame
		if host.dummy.absorbed > absorbed:
			landed = Engine.get_physics_frames() - release
			break
	_check(absf(host.dummy.absorbed - absorbed - 45.0) < 0.01 and landed >= 3,
			"a full charge deals 45 and takes %d frames to arrive (a slug, not a "
			% landed + "hitscan)")
	var moved := {}
	for item in [["weight", host.loose_weight], ["crate", host.loose_crate]]:
		var thing: ManipulableBody = item[1]
		# From 4.5 m in front of it, along its own lane.
		var start := thing.global_position
		body.set_spawn(Transform3D(Basis(), Vector3(start.x, 0.05,
				start.z + 4.5)))
		body.velocity = Vector3.ZERO
		await _settle(20)
		_aim(start + Vector3(0, 0.05, 0))
		await _settle(int(2.0 * FPS))
		Input.action_press("fire_pulse")
		await _settle(int(1.25 * FPS))
		Input.action_release("fire_pulse")
		await _settle(int(1.5 * FPS))
		moved[item[0]] = thing.global_position.distance_to(start)
		_note("%s: pushed %s, moved %.2f m" % [item[0],
				str(weapons.last_slug.get("pushed")), moved[item[0]]])
	_check(moved["crate"] > 0.4 and moved["weight"] > 0.05
			and moved["crate"] > moved["weight"] and weapons.pushes >= 2,
			"its slug shoves loose bodies through their own receive_impulse: "
			+ "the 12 kg crate %.2f m, the 36 kg weight %.2f m"
			% [moved["crate"], moved["weight"]])


func _bulkhead_range() -> void:
	_phase("Bulkhead at range")
	await _key(KEY_4)
	var near := 0.0
	var far := 0.0
	for spot in [[Vector3(0, 0.05, -6.5), "near"], [Vector3(0, 0.05, 0), "far"]]:
		var total := 0.0
		for i in 3:
			body.set_spawn(Transform3D(Basis(), spot[0]))
			body.velocity = Vector3.ZERO
			await _settle(20)
			_aim(AIM_DUMMY)
			await _settle(int(1.1 * FPS))
			var absorbed := host.dummy.absorbed
			await _click()
			await _settle(10)
			total += host.dummy.absorbed - absorbed
		if spot[1] == "near":
			near = total / 3.0
		else:
			far = total / 3.0
	_check(near > far and near >= 27.0,
			"close (3.5 m) blasts land more pellets than far (10 m) ones: "
			+ "%.1f against %.1f a shot" % [near, far])


# ====================================== 7. switching, pause, restart

func _switching() -> void:
	_phase("switching and references")
	await _key(KEY_5)
	host.recover()
	await _settle(int(2.0 * FPS))
	Input.action_press("fire_pulse")
	await _settle(30)
	await _key(KEY_1)
	Input.action_release("fire_pulse")
	await _settle(4)
	_check(weapons.current == "foundry" and not weapons.charging
			and weapons.runtime.charge_ratio() == 0.0
			and (weapons.rig.models["foundry"] as Node3D).visible
			and not (weapons.rig.models["driver"] as Node3D).visible,
			"switching mid-charge drops the charge and changes the gun")
	await _key(KEY_M)
	host.recover()
	await _settle(30)
	_aim(AIM_DUMMY)
	await _settle(10)
	Input.action_press("fire_pulse")
	var still := true
	var kicked := 0.0
	for i in 30:
		await get_tree().process_frame
		if i == 1:
			Input.action_release("fire_pulse")
		kicked = maxf(kicked, absf(weapons.rig.spring("back").x))
		still = still and is_zero_approx(body.camera.v_offset) \
				and is_zero_approx(body.camera.rotation.z) \
				and is_equal_approx(body.camera.fov, weapons.rig._base_fov)
	_check(weapons.reduced_motion and still and kicked > 0.05,
			"M (reduced motion): the gun still kicks, the camera does not move")
	await _key(KEY_M)
	await _key(KEY_6)
	var pulses := _pulses
	host.recover()
	await _settle(30)
	_aim(AIM_DUMMY)
	await _settle(6)
	var absorbed := host.dummy.absorbed
	var frames: Array = []
	var counter := func() -> void: frames.append(Engine.get_physics_frames())
	body.fired_pulse.connect(counter)
	Input.action_press("fire_pulse")
	await _settle(int(1.2 * FPS))
	Input.action_release("fire_pulse")
	await _settle(10)
	body.fired_pulse.disconnect(counter)
	var even := frames.size() >= 3
	for gap in _gaps(frames):
		even = even and gap == 22
	_check(host.feel.current == "a" and weapons.current == ""
			and body.viewmodel.visible and not weapons.rig.visible
			and even and is_equal_approx(host.dummy.absorbed - absorbed,
				6.0 * frames.size()),
			"6 brings back Heavy Report on the Static Pulse as played: its "
			+ "viewmodel, 22-frame cadence, 6 a hit (%d shots)" % frames.size())
	await _key(KEY_0)
	_check(host.feel.current == "baseline" and weapons.current == ""
			and body.fired_pulse.is_connected(host.feel.default_feedback)
			and _pulses > pulses,
			"0 is the Static Pulse as it ships")
	await _key(KEY_2)
	pulses = _pulses
	Input.action_press("fire_pulse")
	await _settle(30)
	Input.action_release("fire_pulse")
	_check(_pulses == pulses and weapons.current == "sightline",
			"taking a weapon out holsters the Pulse again")


func _pause_restart() -> void:
	_phase("pause and restart")
	await _key(KEY_1)
	host.recover()
	await _settle(30)
	await _shoot_at(host.PILLAR_AT + Vector3(0, 1.3, 0.31))
	host.loose_crate.receive_impulse(Vector3(0, 0, -30))
	host.mannequin.take_damage(20.0)
	await _settle(30)
	host._open_menu()
	var shots := weapons.shots
	Input.action_press("fire_pulse")
	await _settle(30)
	Input.action_release("fire_pulse")
	_check(host.menu_open() and weapons.shots == shots,
			"paused in the menu, the trigger fires nothing")
	host._close_menu()
	await _settle(2)
	var before := host.get_instance_id()
	host.restart()
	await _settle(12)
	_check(_bind() and host.get_instance_id() != before
			and weapons.current == "foundry"
			and weapons.impacts.live_marks() == 0
			and is_equal_approx(host.mannequin.hp, 40.0)
			and host.loose_crate.global_position.distance_to(
				host.LOOSE_CRATE_AT) < 0.05,
			"RESTART: a fresh range, the weapon kept, every mark gone, the "
			+ "targets and loose bodies back")
	_check(get_tree().get_nodes_in_group("enemies").is_empty()
			and BridgeClient.isolated and not BridgeClient.online,
			"still no enemies and no bridge after the restart")


# ============================================================ helpers

func _shoot_at(at: Vector3) -> void:
	host.recover()
	await _settle(10)
	_aim(at)
	await _settle(int(1.0 * FPS))
	await _click()
	await _settle(8)


func _click() -> void:
	Input.action_press("fire_pulse")
	await _settle(2)
	Input.action_release("fire_pulse")
	await _settle(2)


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await _settle(2)


func _aim(at: Vector3) -> void:
	var eye := body.camera.global_position
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	body.rotation.y = atan2(-flat.x, -flat.y)
	body.camera.rotation.x = atan2(at.y - eye.y, flat.length())


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


static func _peak(series: Array) -> float:
	var peak := 0.0
	for v in series:
		if absf(float(v)) > absf(peak):
			peak = float(v)
	return peak


## The first sample from which a series stays 0 (at rest) for good.
static func _rest_frame(series: Array) -> int:
	for i in range(series.size() - 1, -1, -1):
		if float(series[i]) > 0.0:
			return i + 1 if i + 1 < series.size() else -1
	return 0


static func _gaps(frames: Array) -> Array:
	var gaps := []
	for i in range(1, frames.size()):
		gaps.append(int(frames[i]) - int(frames[i - 1]))
	return gaps


static func _ms(frames: int) -> String:
	return "never" if frames < 0 else "%d ms" % int(round(frames * 1000.0 / FPS))


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
