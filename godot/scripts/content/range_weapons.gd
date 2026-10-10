class_name RangeWeapons
extends Node
## THE FIVE WEAPONS (01_FIVE_WEAPONS.md), as five firing behaviours in one
## isolated range. Working names, not lore; prototype numbers, not
## balance.
##
## **The shot is the engine's.** Each weapon is an Echo action equipped on
## the player's second Echo slot and fired through `EchoRuntime`'s own
## primitives:
## - Foundry and Sightline: single-pellet `hitscan_damage`;
## - Switchback: `hitscan_damage` re-armed while the trigger is held, its
##   spread growing as it fires;
## - Bulkhead: `hitscan_damage` with ten pellets (Breacher) or seven
##   (Sweeper), the owner's two scatterguns to compare;
## - Mass Driver: `charge_shot`.
## Damage, the rays, the hits and the hit confirmation are all
## `EchoRuntime`'s and `Damageable`'s. Nothing new decides a hit.
##
## **The presentation is this range's.** The left button drives the
## equipped action (the Static Pulse is held off while a weapon is out
## and handed back exactly when it is put away). `EchoRuntime`'s own
## tracers are hidden as they spawn, and each one's resolved end is read
## back. That is the hit this range draws to, from the visible muzzle of
## `RangeRig`. Its kick and flash act on the player's own viewmodel,
## which is hidden while a weapon is out.
##
## **Second pass (the owner's playtest):** each shot's recoil, view climb
## and mechanism are timed as one chain (`RangeRig.RECOIL`, `_mechanics`);
## Sightline, Switchback and the Mass Driver aim down the sights on a
## binding that never takes RMB from an Echo; the sound is Condi's
## SigmAudio set, played by `events.json` (`RangeAudio`).
##
## **Mass Driver's push** is a seam, not engine behaviour. `EchoProjectile`
## frees itself on a world hit and pushes nothing, so the range follows
## the real projectile and, where it ends on a `ManipulableBody`, calls
## that body's own `receive_impulse` (the existing API). The report says
## so.

signal changed(id: String)

const SLOT := "echo_b"
const IDS: Array[String] = ["foundry", "sightline", "switchback", "bulkhead",
		"driver"]
## Prototype numbers. `recoil` names `RangeRig.RECOIL`'s envelope; `fire`
## is Condi's event (`events.json`) for the shot; `ads` (where present)
## scales the kick, the view climb and the spread while aiming down the
## sights. Reaches stay inside `hitscan_damage`'s schema (5-60 m).
const PROFILES := {
	"foundry": {
		"name": "1 · FOUNDRY — heavy hand cannon",
		"hint": "One heavy shot at a time: the gun heaves back, the sight settles, the hammer cocks, then the next.",
		"trigger": "semi", "tracer": "slug", "power": 1.3, "mark": 1.15,
		"marker": "heavy", "recoil": "foundry", "fire": "foundry.fire",
		"action": {"cooldown": 0.72, "primitive": {"type": "hitscan_damage",
			"damage": 15.0, "pellets": 1, "spread_degrees": 0.0,
			"range": 40.0}}},
	"sightline": {
		"name": "2 · SIGHTLINE — scout rifle",
		"hint": "The longest reach and a hard, quick punch. Turn round for the 35 m and 55 m lane; hold RMB to aim.",
		"trigger": "semi", "tracer": "needle", "power": 0.95, "mark": 0.85,
		"marker": "heavy", "recoil": "sightline", "fire": "sightline.fire",
		"ads": {"kick": 0.7, "aim": 0.6},
		"action": {"cooldown": 0.48, "primitive": {"type": "hitscan_damage",
			"damage": 12.0, "pellets": 1, "spread_degrees": 0.0,
			"range": 60.0}}},
	"switchback": {
		"name": "3 · SWITCHBACK — automatic carbine",
		"hint": "Hold to fire about 7 rounds a second. Hold RMB to aim: tighter, steadier. Press 3 again for the hip-fire variant.",
		"trigger": "auto", "tracer": "speck", "power": 0.3, "mark": 0.4,
		"marker": "crisp", "recoil": "", "fire": "switchback.fire",
		"ads": {"kick": 0.5, "aim": 0.35, "spread": 0.4, "bloom": 0.5},
		# base spread, added per round, the most, decay per second idle
		"bloom": [1.2, 0.45, 4.5, 6.0],
		"action": {"cooldown": 0.135, "primitive": {"type": "hitscan_damage",
			"damage": 3.5, "pellets": 1, "spread_degrees": 1.2,
			"range": 32.0}}},
	"bulkhead": {
		"name": "4 · BULKHEAD — scattergun",
		"hint": "",
		"trigger": "semi", "tracer": "pellet", "power": 1.5, "mark": 1.1,
		"marker": "heavy", "recoil": "bulkhead_breacher",
		"fire": "bulkhead.fire", "pump": true, "shove": 22.0,
		"action": {"cooldown": 1.0, "primitive": {"type": "hitscan_damage",
			"damage": 6.0, "pellets": 10, "spread_degrees": 9.0,
			"range": 20.0}}},
	"driver": {
		"name": "5 · MASS DRIVER — charged kinetic",
		"hint": "Hold to charge, release a heavy slug. Long reach, little kick; it shoves loose objects. Hold RMB to aim.",
		"trigger": "charge", "tracer": "", "power": 1.6, "mark": 1.35,
		"marker": "heavy", "recoil": "driver",
		"ads": {"kick": 0.8, "aim": 0.7},
		# impulse (N·s) at no charge and at full charge
		"impulse": [15.0, 90.0],
		"action": {"cooldown": 1.8, "primitive": {"type": "charge_shot",
			"charge_time": 1.2, "min_damage": 14.0, "max_damage": 60.0,
			"speed": 60.0}}},
}
## The owner's comparisons: press a weapon's key again for its next one.
const VARIANTS := {"switchback": ["steady", "hard"],
		"bulkhead": ["breacher", "sweeper"]}
const VARIANT_PROFILES := {
	"switchback": {
		"steady": {"variant_name": "steady hip-fire, as you played it"},
		"hard": {"variant_name": "HARD hip-fire: heavier kick, the view climbs",
			"recoil": "switchback_hard"}},
	"bulkhead": {
		"breacher": {"variant_name": "BREACHER: slow and devastating",
			"hint": "Ten heavy pellets, one shot a second, then the pump. Point-blank it drops the 40 HP target. Press 4 again: Sweeper."},
		"sweeper": {"variant_name": "SWEEPER: fast and lighter",
			"hint": "Seven pellets twice a second, box-fed, no pump. Two shots for the 40 HP target. Press 4 again: Breacher.",
			"recoil": "bulkhead_sweeper", "pump": false, "power": 0.95,
			"mark": 0.8, "shove": 8.0, "fire_pitch": 1.1,
			"action": {"cooldown": 0.5, "primitive": {
				"type": "hitscan_damage", "damage": 4.0, "pellets": 7,
				"spread_degrees": 12.0, "range": 16.0}}}},
}
## The variant each weapon is on; kept across a RESTART.
static var variants := {"switchback": "steady", "bulkhead": "breacher"}
## Aim-down-sights bindings, made at runtime for this range only (never
## in the project's input map). RMB is ALSO the player's first Echo slot
## (`fire_echo`), where grapple and tether Echoes live; it aims here only
## while that slot is empty. V and the mouse side buttons always aim.
const ADS_RMB := "range_ads_rmb"
const ADS_ALT := "range_ads_alt"
## "rmb" (RMB, V or a side button) or "alt" (V or a side button only).
static var ads_binding := "rmb"
## A press this close to the end of a cooldown fires as soon as it ends.
const BUFFER := 0.15

var current := ""
var player: Player
var feel: WeaponFeelTreatments
var runtime: EchoRuntime
var rig: RangeRig
var impacts: RangeImpacts
var audio: RangeAudio
var reduced_motion := false
var shots := 0
var hits := 0
var pushes := 0
## The last shot: weapon, frame, muzzle, ends (each {from, to, hit}).
var last_shot := {}
## The last Mass Driver slug's end: hit, impulse, body moved.
var last_slug := {}
var charging := false
var bloom := 0.0
## Aiming down the sights this frame.
var aiming := false
## The last shot's clocks, in seconds after it: the gun home, the aim
## home, the mechanism's last beat (hammer cocked, bolt or pump locked),
## the weapon ready (filled in as each happens).
var clocks := {}

var _profile := {}
var _buffer := 0.0
var _caught: Array[Node] = []
var _slugs: Array = []
var _was_held := false
var _burst := 0
var _hold_loop := false
var _shot_frame := -1


func bind(host: WeaponFeel) -> void:
	name = "RangeWeapons"
	player = host.player
	feel = host.feel
	runtime = player.runtimes[SLOT]
	rig = RangeRig.new()
	rig.setup(player)
	impacts = RangeImpacts.new()
	impacts.name = "Impacts"
	add_child(impacts)
	audio = RangeAudio.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup()
	player.hit_confirmed.connect(_on_hit)
	ensure_ads_actions()


static func ensure_ads_actions() -> void:
	if not InputMap.has_action(ADS_RMB):
		InputMap.add_action(ADS_RMB)
		var rmb := InputEventMouseButton.new()
		rmb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(ADS_RMB, rmb)
	if not InputMap.has_action(ADS_ALT):
		InputMap.add_action(ADS_ALT)
		var v := InputEventKey.new()
		v.physical_keycode = KEY_V
		InputMap.action_add_event(ADS_ALT, v)
		for button in [MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			var side := InputEventMouseButton.new()
			side.button_index = button
			InputMap.action_add_event(ADS_ALT, side)


## What holds RMB in this range: "" when it aims, otherwise the Echo in
## the first slot that owns it.
func rmb_owner() -> String:
	var first: EchoRuntime = player.runtimes.get("echo_a")
	if first == null or first.equipped.is_empty():
		return ""
	return String(first.equipped.get("display_name", "your first Echo"))


func profile() -> Dictionary:
	return _profile


## A weapon's profile with its current variant applied.
static func profile_of(id: String) -> Dictionary:
	if not PROFILES.has(id):
		return {}
	var base: Dictionary = (PROFILES[id] as Dictionary).duplicate(true)
	if VARIANTS.has(id):
		var v := String(variants.get(id, VARIANTS[id][0]))
		base.merge((VARIANT_PROFILES[id][v] as Dictionary).duplicate(true), true)
		base["variant"] = v
	return base


func variant() -> String:
	return String(variants.get(current, ""))


## The current weapon's next variant (pressing its key again).
func next_variant() -> void:
	if not VARIANTS.has(current):
		return
	var list: Array = VARIANTS[current]
	var at := list.find(variants[current])
	set_variant(current, String(list[(at + 1) % list.size()]))


func set_variant(id: String, v: String) -> void:
	if not VARIANTS.has(id) or not v in VARIANTS[id]:
		return
	variants[id] = v
	if current == id:
		select(id)


## A weapon out, or "" to put it away and hand the Static Pulse back.
func select(id: String) -> void:
	if charging:
		_cancel_charge()
	if id != "" and not id in IDS:
		return
	if id == "":
		current = ""
		_profile = {}
		rig.select("")
		rig.release_camera()
		player.viewmodel.visible = true
		runtime.set_equipped({})
		player._pulse_cooldown = 0.0
		aiming = false
		changed.emit("")
		return
	if feel.current != "baseline":
		feel.select("baseline")
	current = id
	_profile = profile_of(id)
	bloom = 0.0
	_buffer = 0.0
	_burst = 0
	player.viewmodel.visible = false
	var action: Dictionary = (_profile["action"] as Dictionary).duplicate(true)
	action["kind"] = "action"
	action["component_id"] = "range_" + id
	action["display_name"] = String(PROFILES[id]["name"]).get_slice(" — ", 0) \
			.get_slice("· ", 1)
	action["slot"] = SLOT
	action["modifiers"] = []
	runtime.set_equipped(action)
	rig.camera_motion = 0.0 if reduced_motion else 1.0
	rig.select(id)
	rig.recoil_key = String(_profile.get("recoil", ""))
	var feed := rig.part("feed")
	if feed != null:
		feed.visible = variant() == "sweeper"
	var hammer := rig.part("hammer")
	if hammer != null:
		hammer.rotation_degrees.x = HAMMER_COCKED
	changed.emit(id)


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	rig.camera_motion = 0.0 if on else 1.0


# ================================================================ input

func _physics_process(delta: float) -> void:
	if current == "":
		return
	# The Pulse stays holstered while a weapon is out.
	player._pulse_cooldown = 999.0
	var held := Input.is_action_pressed("fire_pulse")
	var pressed := Input.is_action_just_pressed("fire_pulse")
	var p := _profile
	_aim_input()
	_clocks()
	match String(p["trigger"]):
		"semi":
			if pressed:
				_buffer = BUFFER
			if _buffer > 0.0:
				if runtime.cooldown_remaining <= 0.0:
					_buffer = 0.0
					_fire()
				else:
					_buffer -= delta
		"auto":
			if held and runtime.cooldown_remaining <= 0.0:
				_fire()
			if not held:
				var spec: Array = p["bloom"]
				bloom = maxf(0.0, bloom - float(spec[3]) * delta)
				if _was_held and _burst >= 2:
					audio.play("switchback.release")
				_burst = 0
		"charge":
			if pressed and not charging and runtime.cooldown_remaining <= 0.0:
				_begin_charge()
			if charging:
				var ratio := runtime.charge_ratio()
				rig.tremble(ratio)
				_charge_look(ratio, delta)
				if ratio >= 1.0 and not _hold_loop:
					_hold_loop = true
					audio.crossfade("massdriver.charge", "massdriver.charge_hold")
				if not held:
					_release()
	_was_held = held
	_follow_slugs()


## Aiming down the sights, for the weapons that have it. RMB aims only
## while the first Echo slot is empty; V and the side buttons always do.
func _aim_input() -> void:
	var wants := false
	if _profile.has("ads"):
		wants = Input.is_action_pressed(ADS_ALT) or (ads_binding == "rmb"
				and rmb_owner() == "" and Input.is_action_pressed(ADS_RMB))
	aiming = wants
	rig.ads_target = 1.0 if wants else 0.0


## How much of a kick (or spread) survives aiming: `key` of the profile's
## `ads`, blended by how far the sights are up.
func _ads_scale(key: String) -> float:
	var ads: Dictionary = _profile.get("ads", {})
	return lerpf(1.0, float(ads.get(key, 1.0)), rig.ads)


## The last shot's clocks: when the gun came home, when the aim did, when
## the weapon was ready again.
func _clocks() -> void:
	if _shot_frame < 0:
		return
	var t := (Engine.get_physics_frames() - _shot_frame) / float(
			Engine.physics_ticks_per_second)
	if not clocks.has("gun") and rig.gun_at_rest():
		clocks["gun"] = t
	if not clocks.has("aim") and rig.aim_settled():
		clocks["aim"] = t
	if not clocks.has("ready") and runtime.cooldown_remaining <= 0.0:
		clocks["ready"] = t


## Calls `call` while catching every node it adds to the tree: the
## engine's tracers and projectiles, spawned inside it.
func _catching(call: Callable) -> Array[Node]:
	_caught.clear()
	get_tree().node_added.connect(_catch)
	call.call()
	get_tree().node_added.disconnect(_catch)
	return _caught.duplicate()


func _catch(node: Node) -> void:
	if node is Tracer or node is EchoProjectile:
		_caught.append(node)
		if node is Tracer:
			(node as Tracer).visible = false


# ================================================================ the shot

func _fire() -> void:
	var p := _profile
	if current == "switchback":
		var spec: Array = p["bloom"]
		runtime.equipped["primitive"]["spread_degrees"] = float(spec[0]) \
				* _ads_scale("spread") + bloom * _ads_scale("bloom")
	var before := runtime.cooldown_remaining
	var caught := _catching(runtime.activate)
	if runtime.cooldown_remaining <= before:
		return  # the engine refused it
	shots += 1
	_burst += 1
	_shot_frame = Engine.get_physics_frames()
	clocks = {}
	var muzzle := rig.muzzle_position()
	var ends: Array = []
	for node in caught:
		if node is Tracer:
			ends.append(_resolve(node as Tracer))
	rig.kick(_ads_scale("kick"), _ads_scale("aim"))
	rig.muzzle_flash()
	audio.play(String(p["fire"]), float(p.get("fire_pitch", 1.0)))
	_mechanics()
	var style := String(p["tracer"])
	for i in ends.size():
		var end: Dictionary = ends[i]
		end["from"] = muzzle
		end["tracer"] = rig.tracer(style, muzzle, end["to"],
				current == "switchback" and shots % 3 == 0)
	_impacts(ends)
	last_shot = {"weapon": current, "variant": variant(),
			"frame": Engine.get_process_frames(), "muzzle": muzzle,
			"ends": ends, "aiming": aiming, "ads": rig.ads,
			"spread": float(runtime.equipped["primitive"].get("spread_degrees", 0))}
	if current == "switchback":
		var spec: Array = p["bloom"]
		bloom = minf(float(spec[2]) - float(spec[0]), bloom + float(spec[1]))


## Where a hidden engine tracer ended, and what the camera's ray meets
## there: the engine's own resolved hit, read back.
func _resolve(tracer: Tracer) -> Dictionary:
	var length := (tracer.mesh as BoxMesh).size.z
	var forward := -tracer.global_basis.z
	var to := tracer.global_position + forward * length * 0.5
	var eye := player.camera.global_position
	var dir := (to - eye).normalized()
	var hit := player.camera_ray(eye.distance_to(to) + 0.05, dir)
	return {"to": to, "hit": hit}


## Condi's impact event for a surface: her three materials; wood has no
## file of its own and plays stone (claves and chips), an untagged
## surface plays stone as her rules suggest. The Mass Driver has its own.
static func impact_event(material: String, driver := false) -> String:
	var heard := material if material in ["metal", "stone", "organic"] \
			else "stone"
	return ("massdriver.impact." if driver else "impact.") + heard


func _impacts(ends: Array) -> void:
	var p := _profile
	var power := float(p["power"])
	var mark := float(p["mark"])
	if current == "bulkhead":
		_scatter(ends, power, mark)
		return
	for end in ends:
		var hit: Dictionary = end["hit"]
		if hit.is_empty():
			continue
		var info := impacts.impact(hit["position"], hit["normal"],
				hit["collider"], power, mark, current != "switchback")
		end["material"] = info["material"]
		audio.play_at(impact_event(String(info["material"])), hit["position"],
				get_tree().current_scene, float(RangeAudio.IMPACT_RULE_DB[
				"switchback"]) if current == "switchback" else 0.0)


## A scattergun's pellets: one coherent blast where most of them landed,
## a chip mark for up to three others, nothing for the rest. A loose body
## the blast lands on is shoved, by its share of the pellets.
func _scatter(ends: Array, power: float, mark: float) -> void:
	var groups := {}
	for end in ends:
		var hit: Dictionary = end["hit"]
		if hit.is_empty():
			continue
		var key: Object = hit["collider"]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(end)
	if groups.is_empty():
		return
	var best: Object = null
	for key in groups:
		if best == null or groups[key].size() > groups[best].size():
			best = key
	var main: Array = groups[best]
	var centroid := Vector3.ZERO
	for end in main:
		centroid += end["hit"]["position"]
	centroid /= main.size()
	var center: Dictionary = main[0]
	for end in main:
		if (end["hit"]["position"] as Vector3).distance_to(centroid) \
				< (center["hit"]["position"] as Vector3).distance_to(centroid):
			center = end
	var hit: Dictionary = center["hit"]
	var pellets := int(_profile["action"]["primitive"]["pellets"])
	var share := float(main.size()) / pellets
	var info := impacts.impact(hit["position"], hit["normal"], hit["collider"],
			power * (0.5 + share), mark, true)
	for end in ends:
		end["material"] = RangeImpacts.material_of(end["hit"].get("collider"))
	var world := get_tree().current_scene
	audio.play_at(impact_event(String(info["material"])), hit["position"], world)
	if best != null and best.has_method("receive_impulse"):
		var dir := ((hit["position"] as Vector3) - player.camera.global_position) \
				.normalized()
		best.receive_impulse(dir * float(_profile["shove"]) * share)
		pushes += 1
	var chips := 0
	for end in ends:
		if chips >= 3 or end == center or end["hit"].is_empty():
			continue
		impacts.chip(end["hit"]["position"], end["hit"]["normal"],
				end["hit"]["collider"])
		# Her rule: at most two extra pellet impacts, 10-14 dB down, 4-13
		# ms behind the blast.
		if chips < 2:
			audio.play_at(impact_event(RangeImpacts.material_of(
					end["hit"]["collider"])), end["hit"]["position"], world,
					float(RangeAudio.IMPACT_RULE_DB["bulkhead_extra"]),
					0.004 + 0.009 * chips)
		chips += 1


# ======================================================= the mechanisms

## Foundry's hammer, cocked (degrees about its pivot) and fallen.
const HAMMER_COCKED := -38.0
## Each gun's mechanism: the readiness the player can see, timed to the
## recoil so that the gun comes home, the sight settles, and THEN the
## mechanism finishes, just as the weapon is ready again.
func _mechanics() -> void:
	match current:
		"foundry":
			# The hammer falls with the shot; the cylinder indexes as the
			# gun comes home (0.38-0.58 s); the hammer is drawn back and
			# cocks at 0.66 s, with a small felt click; ready at 0.72 s.
			var hammer := rig.part("hammer")
			var drum := rig.part("cylinder")
			if hammer != null:
				hammer.rotation_degrees.x = 0.0
				var cock := hammer.create_tween()
				cock.tween_interval(0.56)
				cock.tween_property(hammer, "rotation_degrees:x", HAMMER_COCKED,
						0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				cock.tween_callback(_click.bind("foundry", 0.5, 0.003))
			if drum != null:
				var from := float(drum.get_meta("index", 0.0))
				drum.set_meta("index", from + PI / 3.0)
				var turn := drum.create_tween()
				turn.tween_interval(0.38)
				turn.tween_method(_index_drum.bind(drum), from, from + PI / 3.0,
						0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"sightline":
			# The bolt handle back at 0.13 s and home at 0.18 s: Condi's
			# two baked-in bolt clicks.
			_stroke(rig.part("handle"), 0.022, 0.08, 0.05, 0.0, 0.05)
			_later(0.18, _click.bind("sightline", 0.4, 0.003))
		"switchback":
			_stroke(rig.part("bolt"), 0.035, 0.0, 0.03, 0.0, 0.036)
		"bulkhead":
			if bool(_profile.get("pump", false)):
				# The pump as the gun comes home (0.72 s): back, then
				# slammed forward at 0.90 s, her forward lock 0.18 s into
				# the pump sound. Ready at 1.0 s.
				_later(0.72, _pump)
			else:
				_later(0.08, _click.bind("bulkhead", 0.8, 0.004))


func _index_drum(angle: float, drum: Node3D) -> void:
	drum.basis = Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, angle)


func _pump() -> void:
	if current != "bulkhead" or not bool(_profile.get("pump", false)):
		return
	audio.play("bulkhead.pump")
	_stroke(rig.part("pump"), 0.1, 0.0, 0.16, 0.02, 0.06)
	rig.nudge("roll", 6.0, 80.0)
	_later(0.18, _click.bind("bulkhead", 1.5, 0.012))


## A small felt beat on the gun (a hammer cocking, a bolt or pump
## locking), only if that gun is still out.
func _click(weapon: String, roll: float, back: float) -> void:
	if current != weapon:
		return
	if _shot_frame >= 0:
		clocks["mech"] = (Engine.get_physics_frames() - _shot_frame) / float(
				Engine.physics_ticks_per_second)
	rig.nudge("roll", roll, roll * 20.0)
	rig.nudge("back", back, back * 30.0)


## Moves a part back along the barrel and home: wait `delay`, back over
## `out`, hold `hold`, home over `home`.
func _stroke(part: Node3D, distance: float, delay: float, out: float,
		hold: float, home: float) -> void:
	if part == null:
		return
	if not part.has_meta("rest"):
		part.set_meta("rest", part.position)
	var rest: Vector3 = part.get_meta("rest")
	var tween := part.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(part, "position", rest + Vector3(0, 0, distance), out) \
			.set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(part, "position", rest, home).set_ease(Tween.EASE_IN)


func _later(seconds: float, call: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(call)


func _on_hit(_killed: bool) -> void:
	if current == "":
		return
	hits += 1
	feel._marker.show_mark(String(_profile["marker"]),
			0.16 if _profile["marker"] == "heavy" else 0.08)


# ============================================================ Mass Driver

func _begin_charge() -> void:
	var before := runtime.cooldown_remaining
	_catching(runtime.activate)
	if runtime.cooldown_remaining <= before:
		return
	charging = true
	_hold_loop = false
	audio.play("massdriver.charge")


func _cancel_charge() -> void:
	charging = false
	_hold_loop = false
	runtime.cancel_holds()
	audio.stop("massdriver.charge", RangeAudio.RELEASE_FADE)
	audio.stop("massdriver.charge_hold", RangeAudio.RELEASE_FADE)
	rig.tremble(0.0)
	_charge_look(0.0, 0.0)


func _release() -> void:
	var ratio := runtime.charge_ratio()
	charging = false
	_hold_loop = false
	var caught := _catching(runtime.release)
	audio.stop("massdriver.charge", RangeAudio.RELEASE_FADE)
	audio.stop("massdriver.charge_hold", RangeAudio.RELEASE_FADE)
	audio.play("massdriver.release_full" if ratio >= 0.999
			else "massdriver.release_early")
	_later(0.5, _power_down_cue)
	shots += 1
	_shot_frame = Engine.get_physics_frames()
	clocks = {}
	rig.tremble(0.0)
	rig.show_charge(0.0)
	rig.kick((0.5 + 0.5 * ratio) * _ads_scale("kick"),
			(0.5 + 0.5 * ratio) * _ads_scale("aim"))
	rig.muzzle_flash(0.6 + 0.6 * ratio)
	_power_down()
	for node in caught:
		if node is EchoProjectile:
			_adopt(node as EchoProjectile, ratio, rig.muzzle_position())
	last_shot = {"weapon": "driver", "frame": Engine.get_process_frames(),
			"muzzle": rig.muzzle_position(), "ratio": ratio, "ends": [],
			"aiming": aiming, "ads": rig.ads}


func _power_down_cue() -> void:
	if current == "driver" and not charging:
		audio.play("massdriver.powerdown")


## The accumulator glows and the coils spin up with the charge.
func _charge_look(ratio: float, delta: float) -> void:
	rig.show_charge(ratio)
	var core := rig.part("core")
	if core != null:
		(core.material_override as StandardMaterial3D) \
				.emission_energy_multiplier = 4.0 * ratio
	var coils := rig.part("coils")
	if coils != null:
		coils.rotation.z += delta * (2.0 + 22.0 * ratio)


## After the release the accumulator flares, then dims over 0.7 s.
func _power_down() -> void:
	var core := rig.part("core")
	if core == null:
		return
	var glow := core.material_override as StandardMaterial3D
	glow.emission_energy_multiplier = 7.0
	var tween := core.create_tween()
	tween.tween_property(glow, "emission_energy_multiplier", 0.0, 0.7) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Follows the engine's projectile: a heavier look on it, and where it
## ends, the impact and (on a loose body) the push.
func _adopt(slug: EchoProjectile, ratio: float, muzzle: Vector3) -> void:
	var record := {"node": slug, "last": slug.global_position,
			"dir": slug.direction, "speed": slug.speed, "ratio": ratio}
	_slugs.append(record)
	slug.tree_exiting.connect(_slug_end.bind(record))
	_reskin.call_deferred(slug, ratio, muzzle)


## The engine's projectile flies from the camera's line (aim truth); its
## visible slug starts at the gun's muzzle and closes onto it in 0.12 s.
func _reskin(slug: EchoProjectile, ratio: float, muzzle: Vector3) -> void:
	if not is_instance_valid(slug):
		return
	for child in slug.get_children():
		var conceal := child is Node3D and not (child is CollisionShape3D)
		if conceal:
			(child as Node3D).visible = false
	var body := MeshInstance3D.new()
	body.name = "Slug"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.05 + 0.03 * ratio
	capsule.height = 0.35 + 0.25 * ratio
	body.mesh = capsule
	body.material_override = HandCannon._additive(Color(0.95, 0.93, 1.0), 0.95)
	slug.add_child(body)
	var dir := slug.direction.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	body.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0)
	body.global_position = muzzle
	var close := body.create_tween()
	close.tween_property(body, "position", Vector3.ZERO, 0.12) \
			.set_ease(Tween.EASE_OUT)
	var heat := CPUParticles3D.new()
	heat.name = "Wake"
	heat.amount = 24
	heat.lifetime = 0.35
	heat.local_coords = false
	heat.gravity = Vector3.ZERO
	heat.initial_velocity_min = 0.0
	heat.initial_velocity_max = 0.2
	var puff := QuadMesh.new()
	puff.size = Vector2(0.12, 0.12)
	heat.mesh = puff
	var material := HandCannon._alpha(Color(0.8, 0.78, 0.82, 0.25))
	material.albedo_texture = HandCannon._tex_soft()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	heat.material_override = material
	slug.add_child(heat)
	heat.emitting = true


func _follow_slugs() -> void:
	for record in _slugs:
		var slug: EchoProjectile = record["node"]
		if is_instance_valid(slug) and slug.is_inside_tree():
			record["last"] = slug.global_position
			record["dir"] = slug.direction


func _slug_end(record: Dictionary) -> void:
	_slugs.erase(record)
	if not is_inside_tree() or is_queued_for_deletion() \
			or get_tree().current_scene == null:
		return
	var dir: Vector3 = record["dir"]
	var from: Vector3 = record["last"] - dir * 0.3
	var reach := float(record["speed"]) / 60.0 * 4.0 + 0.6
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		last_slug = {"hit": {}, "pushed": false}
		return
	var ratio := float(record["ratio"])
	var p: Dictionary = PROFILES["driver"]
	impacts.impact(hit["position"], hit["normal"], hit["collider"],
			0.8 + 0.8 * ratio, 0.8 + 0.55 * ratio, true)
	audio.play_at(impact_event(RangeImpacts.material_of(hit["collider"]), true),
			hit["position"], get_tree().current_scene)
	var spec: Array = p["impulse"]
	var impulse := dir * lerpf(float(spec[0]), float(spec[1]), ratio)
	var body: Object = hit["collider"]
	var pushed := false
	if body != null and body.has_method("receive_impulse"):
		body.receive_impulse(impulse)
		pushes += 1
		pushed = true
	last_slug = {"hit": hit, "pushed": pushed, "impulse": impulse,
			"ratio": ratio}
