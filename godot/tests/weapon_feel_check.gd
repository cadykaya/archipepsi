class_name WeaponFeelCheck
extends Node
## THE WEAPON-FEEL RANGE, CHECKED IN THE REAL GAME.
##
##   godot --headless --fixed-fps 60 --path godot -- --weapon-feel \
##       --weapon-feel-check [--feel=a]
##
## Beside the real `Main`, through the startup a tester's launch takes. The
## player fires by the input a tester presses (`fire_pulse`); the check
## aims by setting the look angles, as the Impact Relay's does. It
## measures, it does not judge feel:
##
## 1. **Isolation and build:** no bridge socket; no enemies; the one
##    target, damageable; the player's own shot feedback found and handed
##    to the treatments; the starting treatment is the one asked for.
## 2. **One shot at the target, per treatment:** frame by frame for 0.75 s
##    at 60 fps -- the viewmodel's offset and turn, the camera's lift, roll
##    and field of view, the muzzle light and bloom, which sounds start
##    and when, the impact, the target's figure, the hit marker -- and the
##    aim, which must not move. The baseline must be the shipped feedback
##    exactly; A, B and C must do what their numbers say and be back at
##    rest before the next shot can fire.
## 3. **The same weapon under all four:** the trigger held for 2.1 s at the
##    target -- the same shots on the same frames, the same hit points,
##    6 damage a hit, the same damage total; then one shot into the back
##    wall -- no hit, no damage, and the miss's impact where the ray ends.
## 4. **Switching:** keys 1-4 switch, mid-recoil included, and leave
##    nothing behind; the paused menu fires nothing; RESTART keeps the
##    treatment.

const FLAG := "--weapon-feel-check"
const AIM_TARGET := Vector3(0, 1.2, -10)
const AIM_WALL := Vector3(3.5, 2.0, -22)
const SAMPLE_FRAMES := 45
const HOLD_SECONDS := 2.1
const FPS := 60.0
const TF := preload("res://scripts/content/weapon_feel_treatments.gd")

var failures := 0
var host: WeaponFeel
var body: Player
var feel: WeaponFeelTreatments
var _shot_frame := -1
var _hit_frame := -1


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "WeaponFeelCheck"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var existing := get_tree().root.get_node_or_null("WeaponFeelCheck")
	if existing != null and existing != self:
		queue_free()
		return
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("[feel]   ok    " if ok else "[feel]   FAIL  ") + what)
	if not ok:
		failures += 1


func _note(what: String) -> void:
	print("[feel]   note  " + what)


func _phase(name_in: String) -> void:
	print("[feel] --- %s" % name_in)


func _run() -> void:
	reparent(get_tree().root)
	await _settle(10)
	if not _bind():
		_check(false, "the range was built")
		get_tree().quit(1)
		return
	await _isolation_and_build()
	_phase("one shot at the target, per treatment")
	var timelines := {}
	for id in TF.IDS:
		timelines[id] = await _one_shot(id)
	_judge_baseline(timelines["baseline"])
	for id in ["a", "b", "c"]:
		_judge_treatment(id, timelines[id])
	_check(_distinct(timelines), "the four treatments are measurably "
			+ "different from one another")
	_sound_table()
	await _same_weapon()
	await _switching()
	print("[feel] %s -- %d failure(s)" % ["PASS" if failures == 0 else "FAILED",
			failures])
	Input.action_release("fire_pulse")
	get_tree().quit(1 if failures > 0 else 0)


func _bind() -> bool:
	var scene := get_tree().current_scene
	host = scene.get_node_or_null("WeaponFeel") as WeaponFeel \
			if scene != null else null
	if host == null:
		return false
	body = host.player
	feel = host.feel
	return body != null and feel != null and host.dummy != null


# ============================================================ 1. build

func _isolation_and_build() -> void:
	_phase("isolation and build")
	_check(BridgeClient.isolated and not BridgeClient.online,
			"the bridge client is isolated and offline (no socket opened)")
	_check(ReviewIsolation.active() and ReviewIsolation.weapon(),
			"the range is an isolated review build")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "no enemies")
	var targets := get_tree().get_nodes_in_group(Damageable.GROUP)
	_check(targets.size() == 1 and targets[0] == host.dummy, "one target, damageable: the Lab's dummy "
			+ "at %s (%d damageable in the scene)" % [_v(host.dummy.global_position),
			targets.size()])
	_check(host.bound and feel.default_feedback.is_valid(),
			"the player's own shot feedback (Player._ready's handler) was found "
			+ "and handed to the treatments")
	_check(feel.current == WeaponFeel.requested_treatment()
			or (WeaponFeel.requested_treatment() not in TF.IDS
				and feel.current == "baseline"),
			"the range starts in the treatment asked for (%s)" % feel.current)
	_check(is_equal_approx(Constants.STATIC_PULSE_DAMAGE, 6.0)
			and is_equal_approx(Constants.STATIC_PULSE_COOLDOWN, 0.35)
			and is_equal_approx(body.damage_dealt_mult, 1.0),
			"the weapon is the game's: %.0f a hit, one shot per %.2f s, "
			% [Constants.STATIC_PULSE_DAMAGE, Constants.STATIC_PULSE_COOLDOWN]
			+ "damage multiplier %.1f" % body.damage_dealt_mult)


# ============================================================ 2. one shot

## One shot at the target, sampled every frame from the shot on.
func _one_shot(id: String) -> Dictionary:
	feel.select(id)
	host.recover()
	await _settle(30)
	_aim(AIM_TARGET)
	await _settle(4)
	var aim := -body.camera.global_basis.z
	var expected := body.camera_ray(Constants.STATIC_PULSE_RANGE)
	var collider_at: Transform3D = host.dummy.global_transform
	var log_from := feel.played.size()
	var absorbed := host.dummy.absorbed
	_shot_frame = -1
	_hit_frame = -1
	body.fired_pulse.connect(_mark_shot)
	body.hit_confirmed.connect(_mark_hit)
	var base_fov: float = feel._base_fov
	var visual: Node3D = feel._target_visual
	var t := {"id": id, "vm_pos": [], "vm_rot": [], "lift": [], "roll": [],
			"fov": [], "flash": [], "bloom": [], "impact": [], "wobble": [],
			"marker": [], "aim": []}
	Input.action_press("fire_pulse")
	var first := -1
	for i in SAMPLE_FRAMES + 4:
		await get_tree().process_frame
		if i == 1:
			Input.action_release("fire_pulse")
		if _shot_frame < 0:
			continue
		if first < 0:
			first = Engine.get_process_frames()
		var vm := body.viewmodel
		t["vm_pos"].append((vm.position - TF.REST_POS).length())
		t["vm_rot"].append((vm.rotation_degrees - TF.REST_ROT).length())
		t["lift"].append(body.camera.v_offset)
		t["roll"].append(rad_to_deg(body.camera.rotation.z))
		t["fov"].append(body.camera.fov - base_fov)
		t["flash"].append(feel._flash.light_energy)
		t["bloom"].append(1.0 if feel._bloom.visible else 0.0)
		t["impact"].append(1.0 if is_instance_valid(feel.last_impact) else 0.0)
		t["wobble"].append(rad_to_deg(absf(visual.rotation.x))
				if visual != null else 0.0)
		t["marker"].append(feel._marker.strength() if feel._marker.visible
				else 0.0)
		t["aim"].append(rad_to_deg(aim.angle_to(-body.camera.global_basis.z)))
		if t["vm_pos"].size() >= SAMPLE_FRAMES:
			break
	body.fired_pulse.disconnect(_mark_shot)
	body.hit_confirmed.disconnect(_mark_hit)
	t["shot"] = _shot_frame
	t["first"] = first
	t["hit_after"] = _hit_frame - _shot_frame if _hit_frame >= 0 else -1
	t["cues"] = []
	for entry in feel.played.slice(log_from):
		t["cues"].append([entry[0], int(entry[1]) - _shot_frame, entry[2]])
	t["damage"] = host.dummy.absorbed - absorbed
	t["impact_at"] = feel.last_impact_at
	t["expected"] = expected
	t["collider_still"] = host.dummy.global_transform.is_equal_approx(
			collider_at)
	t["flash_color"] = feel._flash.light_color
	t["flash_range"] = feel._flash.omni_range
	_note("%s: shot on frame %d, sampled from frame %d; cues %s" % [id,
			_shot_frame, first, str(t["cues"])])
	return t


func _mark_shot() -> void:
	if _shot_frame < 0:
		_shot_frame = Engine.get_process_frames()


func _mark_hit(_killed: bool) -> void:
	if _hit_frame < 0:
		_hit_frame = Engine.get_process_frames()


## Peak of a series, the sample it peaks on, and the first sample from
## which it stays within `eps` of rest for good (-1: never in the window).
static func _shape(series: Array, eps: float) -> Dictionary:
	var peak := 0.0
	var at := 0
	for i in series.size():
		if absf(float(series[i])) > absf(peak):
			peak = float(series[i])
			at = i
	var rest := -1
	for i in range(series.size() - 1, -1, -1):
		if absf(float(series[i])) > eps:
			rest = i + 1 if i + 1 < series.size() else -1
			break
		rest = i
	return {"peak": peak, "at": at, "rest": rest}


static func _ms(frames: int) -> String:
	return "never" if frames < 0 else "%d ms" % int(round(frames * 1000.0 / FPS))


## The shipped feedback, to the frame: `kick_viewmodel(0.05)` puts the
## viewmodel (0, 0.02, 0.10) off rest and eases it home over 0.12 s;
## `muzzle_flash(1.6, ...)` lights 1.6 and fades over 0.09 s; the pulse
## and the confirm tones start on the shot; nothing else moves.
func _judge_baseline(t: Dictionary) -> void:
	_phase("baseline: the shipped feedback")
	var vm := _shape(t["vm_pos"], 0.001)
	var flash := _shape(t["flash"], 0.01)
	_check(absf(vm["peak"] - Vector3(0, 0.02, 0.1).length()) < 1e-4
			and vm["at"] == 0 and absf(_shape(t["vm_rot"], 0.01)["peak"]) < 1e-3,
			"recoil: kick_viewmodel(0.05) -- %.3f m back and up on the shot "
			% vm["peak"] + "frame, no turn")
	_check(vm["rest"] > 0 and vm["rest"] <= ceili(0.12 * FPS) + 1,
			"recovery: at rest after %s (the tween's 0.12 s)" % _ms(vm["rest"]))
	_check(absf(flash["peak"] - 1.6) < 1e-3 and flash["at"] == 0
			and flash["rest"] > 0 and flash["rest"] <= ceili(0.09 * FPS) + 1
			and t["flash_color"].is_equal_approx(TF.DEFAULT_COLOR)
			and is_equal_approx(t["flash_range"], TF.LIGHT_RANGE),
			"muzzle: the light at %.1f, dark after %s, the shipped colour and "
			% [flash["peak"], _ms(flash["rest"])] + "range")
	var still := true
	for key in ["lift", "roll", "fov", "bloom", "impact", "wobble", "marker"]:
		still = still and _shape(t[key], 1e-6)["peak"] == 0.0
	_check(still, "nothing else: no camera jolt, no bloom, no impact "
			+ "effect, no target rock, no extra marker")
	_check(_cues(t) == [["pulse", 0, true], ["confirm", 0, true]],
			"sound: the pulse tone and the confirm tick, both on the shot's "
			+ "frame (%s)" % str(_cues(t)))
	_check(t["hit_after"] == 0 and is_equal_approx(t["damage"], 6.0),
			"the hit confirms on the shot's frame and the target takes 6")
	_check(_shape(t["aim"], 1e-4)["peak"] < 1e-4 and t["collider_still"],
			"the aim and the target's collider never move")


func _judge_treatment(id: String, t: Dictionary) -> void:
	var s: Dictionary = TF.SPEC[id]
	_phase("%s" % TF.NAMES[id])
	var vm := _shape(t["vm_pos"], 0.001)
	var rot := _shape(t["vm_rot"], 0.05)
	var want_pos := Vector3(0, s["kick_up"], s["kick_back"]).length()
	var want_rot := Vector3(s["kick_pitch"], 0, s["kick_roll"]).length()
	var next_shot := roundi(Constants.STATIC_PULSE_COOLDOWN * FPS)
	_check(absf(vm["peak"] - want_pos) < 1e-3 and vm["at"] == 0
			and absf(rot["peak"] - want_rot) < 0.05 and rot["at"] == 0,
			"recoil: %.3f m and %.1f degrees on the shot's frame"
			% [vm["peak"], rot["peak"]])
	var back := maxi(vm["rest"], rot["rest"])
	_check(vm["rest"] > 0 and rot["rest"] > 0
			and back <= ceili(float(s["recover"]) * FPS) + 1
			and back <= next_shot,
			"recovery: at rest after %s (spec %.2f s), before the next "
			% [_ms(back), s["recover"]] + "shot can fire (%s)" % _ms(next_shot))
	var lift := _shape(t["lift"], 1e-4)
	var roll := _shape(t["roll"], 0.01)
	var fov := _shape(t["fov"], 0.01)
	var cam_back := maxi(maxi(lift["rest"], roll["rest"]), fov["rest"])
	_check(absf(lift["peak"] - s["cam_lift"]) < 1e-4
			and absf(absf(roll["peak"]) - s["cam_roll"]) < 0.01
			and absf(fov["peak"] - s["fov_punch"]) < 0.01
			and cam_back >= 0 and cam_back <= ceili(s["cam_recover"] * FPS) + 1,
			"camera: lift %.3f m, roll %.1f, field of view %+.1f degrees; "
			% [lift["peak"], absf(roll["peak"]), fov["peak"]]
			+ "settled after %s" % _ms(cam_back))
	_check(_shape(t["aim"], 1e-4)["peak"] < 1e-4,
			"the aim never moves (largest change %.6f degrees): the next "
			% _shape(t["aim"], 0.0)["peak"] + "shot's ray is this one's")
	var flash := _shape(t["flash"], 0.01)
	var flares := _flares(t["flash"])
	_check(absf(flash["peak"] - s["flash_energy"]) < 1e-3 and flash["at"] == 0
			and flash["rest"] > 0
			and flash["rest"] <= ceili(s["flash_decay"] * FPS) + 2
			and flares == (2 if s["flash_echo"] > 0.0 else 1),
			"muzzle light: %.1f, %d flare(s), dark after %s"
			% [flash["peak"], flares, _ms(flash["rest"])])
	var bloom := _shape(t["bloom"], 0.5)
	_check(bloom["at"] == 0 and bloom["peak"] == 1.0 and bloom["rest"] > 0
			and bloom["rest"] <= ceili(s["bloom_time"] * FPS) + 2,
			"muzzle bloom (%s): on the shot's frame, gone after %s"
			% [s["bloom"], _ms(bloom["rest"])])
	var impact := _shape(t["impact"], 0.5)
	var at: Vector3 = t["impact_at"]
	var want_at: Vector3 = t["expected"].get("position", Vector3.INF)
	_check(impact["at"] == 0 and impact["rest"] > 0
			and impact["rest"] <= ceili(s["impact_time"] * FPS) + 3
			and at.distance_to(want_at) < 1e-3,
			"impact (%s): at the ray's end %s on the shot's frame, gone "
			% [s["impact"], _v(at)] + "after %s" % _ms(impact["rest"]))
	var wobble := _shape(t["wobble"], 0.05)
	_check(absf(wobble["peak"] - s["wobble"]) < 0.01 and wobble["at"] == 0
			and wobble["rest"] > 0
			and wobble["rest"] <= ceili(s["wobble_time"] * FPS) + 2
			and t["collider_still"],
			"the target's figure rocks back %.1f degrees on the hit's frame, "
			% wobble["peak"] + "still after %s; its collider never moves"
			% _ms(wobble["rest"]))
	var marker := _shape(t["marker"], 1e-4)
	_check(t["hit_after"] == 0 and marker["at"] <= 1 and marker["rest"] > 0
			and marker["rest"] <= ceili(s["marker_time"] * FPS) + 2,
			"hit marker (%s): the hit confirms on the shot's frame, the marker "
			% s["marker"] + "shows, gone after %s" % _ms(marker["rest"]))
	var cues := _cues(t)
	var hit_cue: Array = [] if cues.size() < 2 else cues[1]
	var delay := roundi(float(s["hit_delay"]) * FPS)
	_check(cues.size() == 2 and cues[0] == [id + "_report", 0, true]
			and hit_cue[0] == id + "_hit" and hit_cue[2]
			and absi(int(hit_cue[1]) - delay) <= 1,
			"sound: the report on the shot's frame, the hit sound %s after "
			% _ms(int(hit_cue[1]) if hit_cue.size() > 1 else -1)
			+ "(%s)" % str(cues))
	_check(is_equal_approx(t["damage"], 6.0),
			"the target takes 6, as in the baseline")


## The cues one shot started: [name, frames after the shot, playing].
func _cues(t: Dictionary) -> Array:
	return t["cues"]


## Rising edges in the light: a single shot flares once; C's echo twice.
static func _flares(series: Array) -> int:
	var count := 0
	for i in series.size():
		var before := float(series[i - 1]) if i > 0 else 0.0
		if float(series[i]) > before + 0.05:
			count += 1
	return count


func _distinct(timelines: Dictionary) -> bool:
	var seen := {}
	for id in TF.IDS:
		var t: Dictionary = timelines[id]
		var key := "%.3f/%.1f/%.2f/%d" % [_shape(t["vm_pos"], 0.001)["peak"],
				_shape(t["flash"], 0.01)["peak"], _shape(t["fov"], 0.01)["peak"],
				_shape(t["vm_pos"], 0.001)["rest"]]
		seen[key] = id
	return seen.size() == TF.IDS.size()


## Every cue's length and level, read from its samples: the report's
## sound table.
func _sound_table() -> void:
	_phase("the sounds, as rendered")
	var rows := [["pulse", feel.tones._players["pulse"]],
			["confirm", feel.tones._players["confirm"]]]
	for name_in in ["a_report", "a_hit", "b_report", "b_hit", "c_report",
			"c_hit"]:
		rows.append([name_in, feel.sounds[name_in]])
	var ok := true
	for row in rows:
		var sound: AudioStreamPlayer = row[1]
		var stream := sound.stream as AudioStreamWAV
		var count := int(stream.data.size() / 2.0)
		var peak := 0
		for i in count:
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		var dbfs := linear_to_db(peak / 32767.0)
		ok = ok and peak > 0 and peak < 32767
		_note("%-9s %4d ms, peak %5.1f dBFS in the sample, player at %5.1f dB"
				% [row[0], int(round(count * 1000.0 / stream.mix_rate)), dbfs,
					sound.volume_db])
	_check(ok, "every cue is audible and none clips (its samples peak below "
			+ "full scale)")


# ===================================================== 3. the same weapon

func _same_weapon() -> void:
	_phase("the same weapon under all four")
	var runs := {}
	for id in TF.IDS:
		runs[id] = await _hold_fire(id)
	var base: Dictionary = runs["baseline"]
	for id in TF.IDS:
		var run: Dictionary = runs[id]
		_note("%s: %d shots at frame gaps %s, %d hits, %.0f damage" % [id,
				run["frames"].size(), str(_gaps(run["frames"])), run["hits"],
				run["damage"]])
	var same_shots := true
	var same_points := true
	var same_damage := true
	for id in TF.IDS:
		var run: Dictionary = runs[id]
		same_shots = same_shots and _gaps(run["frames"]) == _gaps(base["frames"]) \
				and run["frames"].size() == base["frames"].size()
		for i in mini(run["points"].size(), base["points"].size()):
			same_points = same_points and (run["points"][i] as Vector3) \
					.distance_to(base["points"][i]) < 1e-4
		same_points = same_points and run["points"].size() == base["points"].size()
		same_damage = same_damage and run["steps"] == base["steps"] \
				and run["hits"] == run["frames"].size()
	var gaps := _gaps(base["frames"])
	var cadence := true
	for gap in gaps:
		cadence = cadence and absi(gap - roundi(0.35 * FPS)) <= 1
	_check(same_shots and cadence and base["frames"].size() >= 6,
			"rate of fire: %d shots in %.1f s at the same frame gaps in all "
			% [base["frames"].size(), HOLD_SECONDS] + "four (%s frames: the "
			% str(gaps) + "0.35 s cooldown, in whole 60 Hz frames)")
	_check(same_points, "every shot lands on the same point in all four "
			+ "(%d points)" % base["points"].size())
	var each_six := true
	for step in base["steps"]:
		each_six = each_six and is_equal_approx(step, 6.0)
	_check(same_damage and each_six,
			"damage: 6 a hit, every shot a hit, %.0f in all in all four"
			% base["damage"])
	var misses := {}
	for id in TF.IDS:
		misses[id] = await _miss(id)
	var miss_ok := true
	for id in TF.IDS:
		var m: Dictionary = misses[id]
		miss_ok = miss_ok and m["hits"] == 0 and m["damage"] == 0.0 \
				and m["shots"] == 1 and m["wobble"] == 0.0
		if id == "baseline":
			miss_ok = miss_ok and not m["impact"]
		else:
			miss_ok = miss_ok and m["impact"] \
					and (m["impact_at"] as Vector3).distance_to(m["ray_end"]) < 1e-3
	_check(miss_ok, "a miss into the back wall: no hit, no damage, no rock "
			+ "in all four; A, B and C put their impact where the ray ends "
			+ "(%s)" % _v(misses["a"]["ray_end"]))


func _hold_fire(id: String) -> Dictionary:
	feel.select(id)
	host.recover()
	await _settle(30)
	host.dummy.reset_fixture()
	_aim(AIM_TARGET)
	await _settle(6)
	var run := {"frames": [], "points": [], "steps": [], "hits": 0}
	var last := [host.dummy.absorbed]
	var on_shot := func() -> void:
		run["frames"].append(Engine.get_physics_frames())
		run["points"].append(body.camera_ray(Constants.STATIC_PULSE_RANGE)
				.get("position", Vector3.INF))
	var on_hit := func(_killed: bool) -> void:
		run["hits"] += 1
		run["steps"].append(host.dummy.absorbed - last[0])
		last[0] = host.dummy.absorbed
	body.fired_pulse.connect(on_shot)
	body.hit_confirmed.connect(on_hit)
	Input.action_press("fire_pulse")
	await _settle(int(HOLD_SECONDS * FPS))
	Input.action_release("fire_pulse")
	await _settle(30)
	body.fired_pulse.disconnect(on_shot)
	body.hit_confirmed.disconnect(on_hit)
	run["damage"] = host.dummy.absorbed
	return run


func _miss(id: String) -> Dictionary:
	feel.select(id)
	host.recover()
	await _settle(30)
	_aim(AIM_WALL)
	await _settle(4)
	var ray := body.camera_ray(Constants.STATIC_PULSE_RANGE)
	var before := host.dummy.absorbed
	var shots := feel.shots
	var hits := feel.hits
	var wobble := 0.0
	Input.action_press("fire_pulse")
	await _settle(2)
	Input.action_release("fire_pulse")
	var impact := false
	for _i in 6:
		await get_tree().process_frame
		impact = impact or is_instance_valid(feel.last_impact)
		if feel._target_visual != null:
			wobble = maxf(wobble, absf(feel._target_visual.rotation.x))
	return {"shots": feel.shots - shots, "hits": feel.hits - hits,
			"damage": host.dummy.absorbed - before, "impact": impact,
			"impact_at": feel.last_impact_at,
			"ray_end": ray.get("position", Vector3.INF), "wobble": wobble}


static func _gaps(frames: Array) -> Array:
	var gaps := []
	for i in range(1, frames.size()):
		gaps.append(int(frames[i]) - int(frames[i - 1]))
	return gaps


# ======================================================== 4. switching

func _switching() -> void:
	_phase("switching, pause and restart")
	for entry in [[KEY_2, "a"], [KEY_3, "b"], [KEY_4, "c"], [KEY_1, "baseline"]]:
		await _key(entry[0])
		_check(feel.current == entry[1]
				and host._which.text == TF.NAMES[entry[1]]
				and body.fired_pulse.is_connected(feel.default_feedback)
					== (entry[1] == "baseline"),
				"key %s selects %s, the screen says so, and the player's own "
				% [OS.get_keycode_string(entry[0]), entry[1]]
				+ "feedback is connected only in the baseline")
	# Mid-recoil: fire under A, switch two frames later.
	await _key(KEY_2)
	host.recover()
	await _settle(30)
	_aim(AIM_TARGET)
	await _settle(4)
	Input.action_press("fire_pulse")
	await _settle(2)
	Input.action_release("fire_pulse")
	await get_tree().process_frame
	var moved := (body.viewmodel.position - TF.REST_POS).length() > 0.01
	await _key(KEY_3)
	await get_tree().process_frame
	var vm := body.viewmodel
	_check(moved and vm.position.is_equal_approx(TF.REST_POS)
			and vm.rotation_degrees.is_equal_approx(TF.REST_ROT)
			and is_zero_approx(body.camera.v_offset)
			and is_zero_approx(body.camera.rotation.z)
			and is_equal_approx(body.camera.fov, feel._base_fov)
			and is_zero_approx(feel._flash.light_energy)
			and not feel._bloom.visible and not feel._marker.visible
			and not is_instance_valid(feel.last_impact),
			"switching mid-recoil puts everything back at rest at once")
	# The menu holds fire.
	host._open_menu()
	var shots := feel.shots
	Input.action_press("fire_pulse")
	await _settle(30)
	Input.action_release("fire_pulse")
	_check(host.menu_open() and feel.shots == shots,
			"paused in the menu, the trigger fires nothing")
	host._close_menu()
	await _settle(2)
	# RESTART keeps the treatment.
	var before := host.get_instance_id()
	host.restart()
	await _settle(12)
	_check(_bind() and host.get_instance_id() != before and host.bound
			and feel.current == "b"
			and not body.fired_pulse.is_connected(feel.default_feedback)
			and host._which.text == TF.NAMES["b"],
			"RESTART builds a fresh range and keeps the treatment (b)")
	_check(get_tree().get_nodes_in_group("enemies").is_empty()
			and BridgeClient.isolated and not BridgeClient.online,
			"still no enemies and no bridge after the restart")


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


# ============================================================ helpers

func _aim(at: Vector3) -> void:
	var eye := body.camera.global_position
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	body.rotation.y = atan2(-flat.x, -flat.y)
	body.camera.rotation.x = atan2(at.y - eye.y, flat.length())


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
