class_name Shunter
extends Enemy
## THE SHUNTER: one freight machine, one arena (D-20 revision 2, Dess,
## 2026-10-10; unified integration 1).
##
## **Not a new enemy framework.** It is the game's own `Enemy` -- the
## charger's stats, envelope, collider, damage path, statuses, tint,
## knockback and telegraph signals -- with D-20's per-instance test profile
## as the per-frame behaviour. `enemy.gd` is untouched, so the campaign's
## charger and every other role behave exactly as before.
##
## **The loop** (D-20 §3):
##   WORK --notice--> HORN 0.6 s --> CLOSE (3 m/s, stops 11.2 m out)
##     --> BRACE 0.7 s --> RUSH <= 1.1 s at 13 m/s
##   RUSH ends on the player (0.7 s) | open floor (1.1 s) | a crate (1.1 s,
##   the crate bursts) | steel: pillar, wall, gate (1.8 s)
##     --> RECOVER --> RE-AIM (180 deg/s, plough up) --> CLOSE or BRACE
##
## **Prototype decisions** (owner, 2026-10-16; recorded in the report, not
## campaign rules):
##   * 40 HP, unchanged;
##   * a HEAVY hit is a single damage event at or over the PLOUGH'S RATING,
##     14, measured before armour: the owner's "a threshold above 12" (the
##     Sightline's 12 stays light), at the rating Dess gave the plough in
##     her D-20 addendum (§13, a4b58a41) -- one rating for every heavy
##     reaction, and panels keep their 12;
##   * NO per-target cap: the Mass Driver does its 14-60 here as anywhere
##     (owner, 2026-10-17, dropping the earlier 30 cap; D-20 §13.5);
##   * Dess's recommendations accepted: heavy hits break a brace once per
##     cycle and never stop a rush; the freight gate is a planned tool.
##
## **The look** is a code blockout of Arty's pose study variant B (her
## 2026-10-09 report): body lift and pitch, plough lip and lean, a brow
## lamp bar, two vent flaps with a plume and rear glow. No art model
## exists yet; the README lists it.

signal state_changed(from: String, to: String)
## The horn sounded: it noticed the player (the music's `engage` hook).
signal horned
## A heavy hit landed: `state` is where it landed, `raw` its size.
signal heavy_hit(state: String, raw: float)
## A recovery window opened: `kind` is hit / miss / crate / steel.
signal recovery_opened(kind: String, seconds: float)
## It is down (the music's `victory` hook).
signal powered_down
## The fight's telemetry is ready (after DOWN): `fight_summary`.
signal fight_recorded(summary: Dictionary)

# -- D-20's numbers (rev 2), and the owner's prototype decisions ------------
const HP := 40.0
const RUSH_DAMAGE := 14.0
const SHOVE := 8.0                      # m/s along the rush
const NOTICE_RADIUS := 18.0
const INTEREST_SECONDS := 4.0
const JOB_SPEED := 1.35                 # 3 x 0.45
const CLOSE_SPEED := 3.0
const STOP_AT := 11.2
const BRACE_FROM := 14.0                # rushes at <= 14 m with a clear line
const HORN_SECONDS := 0.6
const HORN_HEAVY_EXTRA := 0.3
const BRACE_SECONDS := 0.7
const PLOUGH_DROP := 0.25               # the plough reaches the deck
const RUSH_SECONDS := 1.1
const RUSH_SPEED := 13.0
const COOLDOWN := 3.0                   # from the start of the wind-up
const TURN_RATE := deg_to_rad(180.0)
const REAIM_SECONDS := 0.6
const HALT_SECONDS := 0.3
const HALT_SHOVE := 1.0                 # metres, through `take_damage`
const RECOVER := {"hit": 0.7, "miss": 1.1, "crate": 1.1, "steel": 1.8}
const PLUME_FADE := 0.2
const ARMOUR_TAKEN := 0.25              # frontal hits take 25 %
const ARMOUR_DOT := 0.35
const TEND_PAUSE := 1.5
const DOCK_SECONDS := 3.0
const TOTE_NUDGE := 40.0                # N.s, a butt that moves a 20 kg tote
## Contact hit test (D-20 §3.3): beside the line, along it, feet below.
const HIT_LATERAL := 1.0
const HIT_ALONG := 1.35
const HIT_FEET := 1.05
## The plough's rating (D-20 §13.3): the owner's "above 12" -- Sightline
## (12) refused, Foundry (15) accepted.
const HEAVY_AT := 14.0
const HEARING := 18.0

const STATES := ["work", "dock", "horn", "close", "brace", "rush", "recover",
		"reaim", "down"]

var state := "work"
var state_time := 0.0
## The work lane: the crate stack end and the dock end, declared by the
## arena, never chosen at random (D-20 §2: "declared ends are new").
var lane_stack := Vector3.ZERO
var lane_dock := Vector3.ZERO
var tote: Node3D = null
var dock_cable: Node3D = null
## Set by the arena: true while a Mass Driver charge is audible -- the
## position of the charging gun, or Vector3.INF when nothing charges.
var charge_source: Callable = func() -> Vector3: return Vector3.INF
## Set by the arena: the weapon the player has out ("pulse" when none), for
## the fight telemetry only -- no weapon is treated differently.
var weapon_out: Callable = func() -> String: return "pulse"
## Telemetry (D-20 §13, Dess): per weapon, the damage it did and the
## rushes the Shunter made while it was out; and the time from the horn to
## DOWN. `fight_summary` is filled at DOWN.
var fight := {}
var fight_summary := {}
var _fight_from := -1.0

var _heading_to_dock := true
var _tend := 0.0
var _horn_length := HORN_SECONDS
var _cooldown_left := 0.0
var _brace_dir := Vector3.FORWARD
var _brace_broken_this_cycle := false
var _brace_locked := false
var _halt := 0.0
var _recover_kind := ""
var _recover_length := 0.0
var _away := 0.0
var _pending_raw := 0.0
var _pending_from := Vector3.ZERO
var _pending_state := ""
var _was_hit := false
var _rush_rest := Vector3.ZERO
var _heavy_notice := false
## The speed it meant to move at this frame (0 when holding), for the
## base enemy's displacement test that turns a block into a sidestep.
var _intended := 0.0
## The longest it has pushed against something without moving (D-20
## §8.A10: never more than 2 s against a pillar or the gate).
var grind := 0.0
var grind_max := 0.0
var _reaim_min := 0.15
## Telemetry (D-20 §7.6): every state change and hit, and per-window damage.
var events_log: Array = []
var window_damage := 0.0
var rushes_taken := 0
var distance_moved := 0.0

# -- the blockout (variant B) ---------------------------------------------
var _body: Node3D
var _plough: Node3D
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _flaps: Array[Node3D] = []
var _plume: MeshInstance3D
var _plume_mat: StandardMaterial3D
var _glow: OmniLight3D
var _lane: MeshInstance3D
var _flash := 0.0
var _jolt := Vector3.ZERO
var _audio: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
## Seconds a sidestep keeps its side while the way stays blocked.
var _blocked_streak := 0.0

const HORN_STREAM := "res://audio/sfx/shunter/shunter-horn-tuned.wav"


## The Shunter, built the way `Enemy.create` builds a charger: the same
## stats, envelope, collider, `Visual` and telegraph origin.
static func make() -> Shunter:
	var s := Shunter.new()
	s.archetype = "charger"
	s.name = "Shunter"
	var block: Dictionary = (Constants.ENEMY_STATS["charger"] as Dictionary) \
			.duplicate()
	block["hp"] = HP
	s.stats = block
	s.hp = HP
	s.max_hp = HP
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES["charger"]
	s.envelope = envelope
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = envelope["size"]
	shape.shape = box
	shape.position = Vector3(0, float(envelope["centre_y"]), 0)
	s.add_child(shape)
	var body_visual := Node3D.new()
	body_visual.name = "Visual"
	s.add_child(body_visual)
	s.visual = body_visual
	var origin := Marker3D.new()
	origin.name = "TelegraphOrigin"
	origin.position = Vector3(0, float(envelope["centre_y"]), 0)
	s.add_child(origin)
	s.telegraph_origin = origin
	s._build_blockout()
	return s


func _ready() -> void:
	super._ready()
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	_audio.max_distance = 50.0
	add_child(_audio)
	_horn = AudioStreamPlayer3D.new()
	_horn.unit_size = 14.0
	_horn.max_distance = 80.0
	_horn.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	if ResourceLoader.exists(HORN_STREAM):
		_horn.stream = load(HORN_STREAM)
	add_child(_horn)
	_lane = MeshInstance3D.new()
	_lane.name = "LaneTelegraph"
	var strip := PlaneMesh.new()
	strip.size = Vector2(float(envelope["size"].x), RUSH_SPEED * RUSH_SECONDS)
	_lane.mesh = strip
	var lane_mat := StandardMaterial3D.new()
	lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lane_mat.albedo_color = Color(1.0, 0.12, 0.08, 0.45)
	_lane.material_override = lane_mat
	_lane.top_level = true
	_lane.visible = false
	add_child(_lane)
	_log("spawn", {})


func set_lane(stack: Vector3, dock: Vector3, the_tote: Node3D = null) -> void:
	lane_stack = stack
	lane_dock = dock
	tote = the_tote


# =========================================================== the loop

func _physics_process(delta: float) -> void:
	if _dead:
		_present(delta)
		return
	if global_position.y < Constants.ENEMY_FALL_KILL_Y:
		die()
		return
	statuses.tick(delta)
	var dot := statuses.dot_per_second()
	if dot > 0.0:
		_take_dot(dot * delta)
		if _dead:
			return
	if not is_on_floor():
		velocity.y -= Constants.GRAVITY * delta
	# NOTHING STOPS A RAM: a knock that lands mid-rush goes nowhere.
	if state != "rush":
		velocity += _knockback
	_knockback = Vector3.ZERO
	_resolve_pending_hit()
	state_time += delta
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	var player := _find_player()
	var before := global_position
	match state:
		"work":
			_do_work(delta, player)
		"dock":
			_do_dock(delta, player)
		"horn":
			_hold(0.4)
			if state_time >= _horn_length:
				_enter("close")
		"close":
			_do_close(delta, player)
		"brace":
			_hold(0.5)
			if state_time >= BRACE_SECONDS:
				_end_telegraph(true)
				_enter("rush")
		"rush":
			_do_rush(delta, player)
		"recover":
			_hold(0.25)
			if state_time >= _recover_length - PLUME_FADE:
				_fade("shunter.plume_hiss", PLUME_FADE)
			if state_time >= _recover_length:
				_enter("reaim")
		"reaim":
			_do_reaim(delta, player)
	_intended = 0.0 if state != "close" or velocity.length() < 0.5 \
			else Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	if state == "rush":
		_rush_contacts(player)
	_unstick(before, delta, player)
	distance_moved += Vector2(global_position.x - before.x,
			global_position.z - before.z).length()
	_present(delta)


func _enter(next: String) -> void:
	var from := state
	if state == "rush" or state == "brace":
		_lane.visible = false
	state = next
	state_time = 0.0
	_log("state", {"from": from, "to": next})
	match next:
		"horn":
			# A heavy hit that woke it jolts it sideways first: the horn is
			# 0.3 s longer, a longer ambush window (D-20 §3.2).
			_horn_length = HORN_SECONDS + (HORN_HEAVY_EXTRA if _heavy_notice
					else 0.0)
			_heavy_notice = false
			_flash = 0.15
			if _horn.stream != null:
				_horn.play()
			_start_fight()
			horned.emit()
		"brace":
			_cooldown_left = COOLDOWN
			# LOCKED ON WHERE THE PLAYER WAS when the wind-up starts, as the
			# charger's rush always has been ([E] :839-849) -- not on its own
			# facing, which may still be a few degrees off: at 11 m, 6 degrees
			# is 1.15 m, outside the 1.0 m hit band.
			var target := _find_player()
			if target != null:
				var to := target.global_position - global_position
				_brace_dir = Vector3(to.x, 0.0, to.z).normalized()
				rotation.y = atan2(-_brace_dir.x, -_brace_dir.z)
			else:
				_brace_dir = -global_transform.basis.z
				_brace_dir.y = 0.0
				_brace_dir = _brace_dir.normalized()
			_show_lane()
			_begin_telegraph("charge", BRACE_SECONDS)
			_sound("shunter.plough_scrape", "windup")
		"rush":
			_rush_rest = global_position
			_sound("shunter.rush", "melee_hit")
			_tally("rushes", 1.0)
		"recover":
			window_damage = 0.0
			_sound("shunter.plume_hiss", "")
		"reaim":
			if from == "recover":
				# A full cycle has ended: the next brace may be broken again.
				_brace_broken_this_cycle = false
				_brace_locked = false
		"work":
			_heading_to_dock = global_position.distance_to(lane_dock) \
					> global_position.distance_to(lane_stack)
	state_changed.emit(from, next)


## Slows to a stop, holding its facing.
func _hold(weight: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, weight)
	velocity.z = lerpf(velocity.z, 0.0, weight)


# -- before the fight --------------------------------------------------------

func _do_work(delta: float, player: Player) -> void:
	if _noticed(player):
		_notice()
		return
	if _tend > 0.0:
		_tend -= delta
		_hold(0.3)
		return
	var goal := lane_dock if _heading_to_dock else lane_stack
	var flat := Vector3(goal.x - global_position.x, 0.0,
			goal.z - global_position.z)
	if flat.length() < 0.35:
		if _heading_to_dock:
			_enter("dock")
		else:
			# At the stack: nose down, butt the stray tote back into line.
			_tend = TEND_PAUSE
			_nudge_tote()
			_heading_to_dock = true
			_log("tend", {})
		return
	_turn_toward(flat, delta)
	var dir := flat.normalized()
	velocity.x = lerpf(velocity.x, dir.x * JOB_SPEED, 0.2)
	velocity.z = lerpf(velocity.z, dir.z * JOB_SPEED, 0.2)


func _do_dock(delta: float, player: Player) -> void:
	if _noticed(player):
		_notice()
		return
	_hold(0.4)
	# Backed in: facing the wall, its back to the booth.
	var out := lane_dock - lane_stack
	_turn_toward(Vector3(out.x, 0.0, out.z), delta)
	if state_time >= DOCK_SECONDS:
		_heading_to_dock = false
		_enter("work")


func _nudge_tote() -> void:
	if tote == null or not is_instance_valid(tote):
		return
	if tote.global_position.distance_to(global_position) > 2.5:
		return
	if tote.has_method("receive_impulse"):
		var push := tote.global_position - global_position
		push.y = 0.0
		tote.call("receive_impulse", push.normalized() * TOTE_NUDGE)


## It notices within 18 m, when hit, or when it hears a Mass Driver
## charging within 18 m (D-20 §2; A6, a new test-only rule).
func _noticed(player: Player) -> bool:
	if _was_hit:
		return true
	if player == null:
		return false
	if player.global_position.distance_to(global_position) <= NOTICE_RADIUS:
		return true
	var charging: Vector3 = charge_source.call()
	return charging != Vector3.INF \
			and charging.distance_to(global_position) <= HEARING


func _notice() -> void:
	_was_hit = false
	_has_noticed = true
	_enter("horn")


# -- the fight ------------------------------------------------------------------

func _do_close(delta: float, player: Player) -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var distance := flat.length()
	if _lapsed(distance, delta):
		return
	_turn_toward(flat, delta)
	if _halt > 0.0:
		_halt -= delta
		_hold(0.5)
		return
	if distance <= BRACE_FROM and _cooldown_left <= 0.0 \
			and _facing(flat) and _has_line_of_sight(player):
		_enter("brace")
		return
	# NEVER A PERMANENT HIDING PLACE (D-20 §6): without a clear line it does
	# not stop at its stand-off -- it keeps coming, and the unstick carries
	# it round the gate or a pillar until it can see the player again.
	var sees := _has_line_of_sight(player)
	if distance > STOP_AT or not sees:
		var dir := flat.normalized()
		_sidestep_timer = maxf(0.0, _sidestep_timer - delta)
		if _sidestep_timer > 0.0:
			dir = _sidestep_dir
		velocity.x = lerpf(velocity.x, dir.x * CLOSE_SPEED, 0.2)
		velocity.z = lerpf(velocity.z, dir.z * CLOSE_SPEED, 0.2)
	else:
		_hold(0.3)


func _do_rush(_delta: float, _player: Player) -> void:
	velocity.x = _brace_dir.x * RUSH_SPEED
	velocity.z = _brace_dir.z * RUSH_SPEED
	if state_time >= RUSH_SECONDS:
		_end_rush("miss")


## What the rush met this frame: the player (contact volume), a crate, or
## steel. Checked after the move, so a rush never passes through anything.
func _rush_contacts(player: Player) -> void:
	if state != "rush":
		return
	if player != null and _contact(player):
		player.take_damage(RUSH_DAMAGE, global_position)
		player.receive_knockback(_brace_dir * SHOVE)
		rushes_taken += 1
		_log("rush_hit", {"damage": RUSH_DAMAGE})
		_end_rush("hit")
		return
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_normal().y > 0.7:
			continue                        # the floor
		var other := hit.get_collider()
		if other is Player:
			# THE BODY TOUCHED THEM. Capsule and box meet at a centre
			# distance of exactly 0.95 + 0.4 = 1.35 m, D-20's contact
			# length, so rounding can leave `_contact` a hair outside while
			# the bodies are pressed together. Touching is contact -- unless
			# their feet are above the plough (the jump).
			if (other as Player).global_position.y - global_position.y \
					< HIT_FEET:
				(other as Player).take_damage(RUSH_DAMAGE, global_position)
				(other as Player).receive_knockback(_brace_dir * SHOVE)
				rushes_taken += 1
				_log("rush_hit", {"damage": RUSH_DAMAGE, "by": "touch"})
				_end_rush("hit")
				return
			continue
		if other is DestructibleCover:
			(other as DestructibleCover).take_damage(
					(other as DestructibleCover).hp)
			_end_rush("crate")
			return
		if other is RigidBody3D:
			continue                        # a loose tote is shoved aside
		if hit.get_normal().dot(-_brace_dir) > 0.3:
			_end_rush("steel")
			return


## D-20 §3.3: the player is hit when beside the line by <= 1.0 m, along it
## within +-1.35 m of the body's centre, and with their feet below 1.05 m.
func _contact(player: Player) -> bool:
	var rel := player.global_position - global_position
	var along := rel.x * _brace_dir.x + rel.z * _brace_dir.z
	var side := Vector2(rel.x - _brace_dir.x * along,
			rel.z - _brace_dir.z * along).length()
	var feet := player.global_position.y - global_position.y
	return side <= HIT_LATERAL and absf(along) <= HIT_ALONG and feet < HIT_FEET


func _end_rush(kind: String) -> void:
	_recover_kind = kind
	_recover_length = float(RECOVER[kind])
	velocity.x = 0.0
	velocity.z = 0.0
	_fade("shunter.rush", 0.025)
	if kind == "steel":
		_jolt = -_brace_dir * 0.3
		_sound("shunter.crumple_clang", "slam")
	elif kind == "miss" or kind == "crate":
		_sound("shunter.skid", "default")
	_enter("recover")
	recovery_opened.emit(kind, _recover_length)
	_log("recover", {"kind": kind, "seconds": _recover_length})


func _do_reaim(delta: float, player: Player) -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if _lapsed(flat.length(), delta):
		return
	_hold(0.3)
	_turn_toward(flat, delta)
	if state_time >= REAIM_SECONDS \
			or (state_time >= _reaim_min and _facing(flat)):
		_reaim_min = 0.15
		if flat.length() <= BRACE_FROM and _cooldown_left <= 0.0 \
				and _facing(flat) and _has_line_of_sight(player):
			_enter("brace")
		else:
			_enter("close")


## THE BASE ENEMY'S UNSTICK ([E] ~770-785): meant to move, barely did, so
## slide sideways for a beat, alternating sides -- which is how it walks
## round the closed freight gate rather than grinding into it.
func _unstick(before: Vector3, delta: float, player: Player) -> void:
	if _intended <= 0.0 or player == null:
		grind = 0.0
		return
	var moved := Vector2(global_position.x - before.x,
			global_position.z - before.z).length()
	_blocked_streak = maxf(0.0, _blocked_streak - delta)
	if moved < _intended * delta * 0.35:
		grind += delta
		grind_max = maxf(grind_max, grind)
		if _sidestep_timer <= 0.0:
			var toward := player.global_position - global_position
			var side := Vector3(toward.z, 0.0, -toward.x).normalized()
			if _blocked_streak > 0.0:
				# Still blocked by the same thing: keep going the same way,
				# so the 6 m gate frame is walked round rather than rocked
				# against (alternating only clears something narrower than
				# one step).
				var was := Vector3(_sidestep_dir.x, 0.0, _sidestep_dir.z)
				_sidestep_dir = side if side.dot(was) >= 0.0 else -side
			else:
				_sidestep_flip = not _sidestep_flip
				_sidestep_dir = -side if _sidestep_flip else side
			# Edging off a little as it steps, so its plough's corner does
			# not stay wedged on a frame post or a pillar.
			_sidestep_dir = (_sidestep_dir - toward.normalized() * 0.45).normalized()
			# A second step the same way is a longer one: it is going round.
			_sidestep_timer = 1.0 if _blocked_streak > 0.0 else 0.55
			_blocked_streak = _sidestep_timer + 1.2
	else:
		grind = 0.0


## Out of mind: more than 18 m away for 4 s, back to work (the existing
## "OUT OF MIND" rule, [E] ~730-737).
func _lapsed(distance: float, delta: float) -> bool:
	if distance > NOTICE_RADIUS:
		_away += delta
	else:
		_away = 0.0
	if _away >= INTEREST_SECONDS:
		_away = 0.0
		_has_noticed = false
		_log("lapsed", {})
		_enter("work")
		return true
	return false


func _turn_toward(flat: Vector3, delta: float) -> void:
	if flat.length() < 0.05:
		return
	var want := atan2(-flat.x, -flat.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)


func _facing(flat: Vector3) -> bool:
	var ahead := -global_transform.basis.z
	return Vector2(ahead.x, ahead.z).normalized().dot(
			Vector2(flat.x, flat.z).normalized()) > cos(deg_to_rad(8.0))


# =========================================================== being hit

## The plough soaks damage, not force (D-20 §3.2): armour applies to the
## damage, the heavy-hit reaction reads the raw event.
func _frontal_shrug(from: Vector3) -> float:
	if not state in ["close", "brace", "rush"]:
		return 0.0
	var facing := -global_transform.basis.z
	var incoming := from - global_position
	incoming.y = 0.0
	if incoming.length() < 0.001:
		return 0.0
	if facing.normalized().dot(incoming.normalized()) < ARMOUR_DOT:
		return 0.0
	return 1.0 - ARMOUR_TAKEN


func take_damage(amount: float, direction: Vector3, knockback: float) -> bool:
	if _dead:
		return false
	var raw := amount
	# One trigger pull is one event: Bulkhead's pellets land in the same
	# frame and are summed for the reaction only (D-20 A3).
	_pending_raw += raw
	_pending_from = global_position - direction
	_pending_state = state
	if state in ["work", "dock"]:
		_was_hit = true
	var armoured := _frontal_shrug(global_position - direction) > 0.0
	if state == "rush":
		knockback = 0.0
	var hp_before := hp
	var killed := super.take_damage(amount, direction, knockback)
	window_damage += hp_before - maxf(hp, 0.0)
	_tally("damage", hp_before - maxf(hp, 0.0))
	_log("hit", {"raw": raw, "taken": hp_before - maxf(hp, 0.0),
			"armoured": armoured})
	# Every hit answers, including mid-wind-up (the base flinch skips it).
	if armoured:
		_flash = 0.08
		_placeholder("melee_hit")           # PLACEHOLDER: armour clang (not in D-20's seven)
	elif visual != null:
		visual.scale = Vector3.ONE * 0.94
		create_tween().tween_property(visual, "scale", Vector3.ONE, 0.1)
	return killed


## The summed event of the last frame, judged once.
func _resolve_pending_hit() -> void:
	if _pending_raw <= 0.0:
		return
	var raw := _pending_raw
	var where := _pending_state
	_pending_raw = 0.0
	if raw < HEAVY_AT or _dead:
		return
	heavy_hit.emit(where, raw)
	_log("heavy", {"state": where, "raw": raw})
	match where:
		"work", "dock":
			# Jolted sideways: the horn is delayed 0.3 s, a longer ambush.
			_jolt = global_transform.basis.x * 0.5
			_heavy_notice = true
		"horn":
			_jolt = (global_position - _pending_from).normalized() * 0.3
			if state == "horn" and _horn_length < HORN_SECONDS + HORN_HEAVY_EXTRA:
				_horn_length = HORN_SECONDS + HORN_HEAVY_EXTRA
		"close":
			_halt = HALT_SECONDS
			var away := global_position - _pending_from
			away.y = 0.0
			velocity += away.normalized() * HALT_SHOVE / HALT_SECONDS
		"brace":
			if _brace_locked or _brace_broken_this_cycle:
				_flash = 0.08               # sparks only: the locked brace
			else:
				_brace_broken_this_cycle = true
				_brace_locked = true
				_end_telegraph(false)
				_fade("shunter.plough_scrape", 0.025)
				_jolt = -_brace_dir * 0.2
				_log("brace_broken", {})
				_reaim_min = REAIM_SECONDS
				_enter("reaim")
		"rush":
			_flash = 0.08                   # sparks and a clang; nothing else
		"recover":
			_jolt = (global_position - _pending_from).normalized() * 0.5
			_sound("shunter.vent_gust", "default")


func die() -> void:
	if _dead:
		return
	_dead = true
	_end_telegraph(false)
	_lane.visible = false
	var was_rushing := state == "rush"
	_enter("down")
	for running: String in ["shunter.rush", "shunter.plume_hiss",
			"shunter.plough_scrape"]:
		_fade(running, 0.025)
	if was_rushing:
		_jolt = _brace_dir * 1.0            # skids a metre
		_sound("shunter.skid", "")
	_sound("shunter.power_down", "slam")
	# After the killing hit has been counted (it is still inside
	# take_damage when this runs).
	_summarise_fight.call_deferred()
	set_collision_layer_value(1, false)
	enemy_died.emit(self)
	powered_down.emit()
	_log("down", {})


# =========================================================== the look

func _build_blockout() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.21, 0.23)
	steel.metallic = 0.6
	steel.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.11, 0.11, 0.12)
	dark.roughness = 0.8
	_body = Node3D.new()
	_body.name = "Body"
	visual.add_child(_body)
	_block(_body, Vector3(0.8, 0.5, 1.6), Vector3(0, 0.6, 0.05), steel)
	_block(_body, Vector3(0.7, 0.18, 0.5), Vector3(0, 0.92, 0.35), dark)
	for x: float in [-0.32, 0.32]:
		for z: float in [-0.55, 0.6]:
			_block(_body, Vector3(0.14, 0.38, 0.18), Vector3(x, 0.19, z), dark)
	# The plough: pivots at its top edge on the body's nose.
	_plough = Node3D.new()
	_plough.name = "Plough"
	_plough.position = Vector3(0, 0.6, -0.85)
	_body.add_child(_plough)
	_block(_plough, Vector3(0.9, 0.5, 0.08), Vector3(0, -0.25, -0.05), steel)
	# The brow lamp bar, about 0.6 m wide, where it reads from the front.
	_lamp = MeshInstance3D.new()
	_lamp.name = "BrowLamps"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.6, 0.08, 0.06)
	_lamp.mesh = lamp_mesh
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp.material_override = _lamp_mat
	_lamp.position = Vector3(0, 0.98, -0.62)
	_body.add_child(_lamp)
	for x: float in [-0.18, 0.18]:
		var flap := Node3D.new()
		flap.position = Vector3(x, 0.86, 0.62)
		_body.add_child(flap)
		_block(flap, Vector3(0.28, 0.03, 0.22), Vector3(0, 0, 0.11), dark)
		_flaps.append(flap)
	_plume = MeshInstance3D.new()
	var plume_mesh := CylinderMesh.new()
	plume_mesh.top_radius = 0.28
	plume_mesh.bottom_radius = 0.12
	plume_mesh.height = 0.7
	_plume.mesh = plume_mesh
	_plume_mat = StandardMaterial3D.new()
	_plume_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plume_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plume_mat.albedo_color = Color(1.0, 0.92, 0.8, 0.0)
	_plume.material_override = _plume_mat
	_plume.position = Vector3(0, 1.25, 0.72)
	_plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_plume)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.65)
	_glow.omni_range = 2.5
	_glow.light_energy = 0.0
	_glow.position = Vector3(0, 0.9, 0.95)
	_body.add_child(_glow)


func _block(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat
	parent.add_child(mesh)


## The pose for the current state (D-20 §5's table), eased toward each
## frame: plough lip and lean, body lift and pitch, lamps, vents, plume.
func _present(delta: float) -> void:
	if _body == null:
		return
	var lip := 0.40
	var lean := -8.0
	var lift := 0.0
	var pitch := 0.0
	var lamp := Color(1.0, 0.62, 0.18)       # amber: working
	var lamp_energy := 1.2
	var vents := 0.0
	var plume := 0.0
	match state:
		"work":
			pitch = -4.0 if _tend > 0.0 else 0.0
		"dock":
			lift = -0.04
			lamp_energy = 0.4
		"horn":
			lip = 0.48
			lean = -14.0
			lift = 0.06
			pitch = 6.0
			lamp = Color(1.0, 0.1, 0.06)
			lamp_energy = 3.0
		"close":
			lip = 0.05
			lean = 12.0
			pitch = -4.0
			lamp = Color(1.0, 0.1, 0.06)
			lamp_energy = 2.2
		"brace":
			var k := clampf(state_time / PLOUGH_DROP, 0.0, 1.0)
			lip = lerpf(0.05, 0.03, k)
			lean = 12.0
			lift = -0.07 * k
			pitch = -4.0
			lamp = Color(1.0, 0.1, 0.06)
			lamp_energy = 2.6
		"rush":
			lip = 0.05
			lean = 15.0
			pitch = -6.0
			lamp = Color(1.0, 0.1, 0.06)
			lamp_energy = 2.6
		"recover":
			lip = 0.48
			lean = -30.0
			lift = -0.06
			pitch = 4.0
			lamp_energy = 0.0
			vents = clampf(state_time / 0.2, 0.0, 1.0)
			# Fades over the LAST 0.2 s: the closing window is visible.
			var left := _recover_length - state_time
			plume = clampf(left / PLUME_FADE, 0.0, 1.0)
			if _recover_kind == "miss" or _recover_kind == "crate":
				lip = 0.0
				lean = 20.0
				pitch = -9.0
		"reaim":
			lip = 0.48
			lean = -14.0
			lamp = Color(1.0, 0.1, 0.06)
			lamp_energy = 1.6
		"down":
			lip = 0.0
			lean = 20.0
			lift = -0.12
			lamp_energy = 0.0
	if _flash > 0.0:
		_flash -= delta
		lamp = Color(1.0, 1.0, 0.95)
		lamp_energy = 4.0
	var w := clampf(delta * 12.0, 0.0, 1.0)
	_plough.position.y = lerpf(_plough.position.y, 0.2 + lip, w)
	_plough.rotation_degrees.x = lerpf(_plough.rotation_degrees.x, -lean, w)
	_body.position.y = lerpf(_body.position.y, lift, w)
	_body.rotation_degrees.x = lerpf(_body.rotation_degrees.x, pitch, w)
	_lamp_mat.albedo_color = lamp * 0.4
	_lamp_mat.emission = lamp
	_lamp_mat.emission_energy_multiplier = lerpf(
			_lamp_mat.emission_energy_multiplier, lamp_energy, w)
	for flap in _flaps:
		flap.rotation_degrees.x = lerpf(flap.rotation_degrees.x, -55.0 * vents, w)
	_plume_mat.albedo_color.a = 0.55 * plume
	_plume.visible = plume > 0.01
	_glow.light_energy = 1.6 * plume
	if _jolt != Vector3.ZERO:
		global_position += _jolt * w
		_jolt = _jolt.lerp(Vector3.ZERO, w)
		if _jolt.length() < 0.01:
			_jolt = Vector3.ZERO


func _show_lane() -> void:
	var length := RUSH_SPEED * RUSH_SECONDS
	var start := global_position + Vector3(0, 0.03, 0)
	_lane.global_position = start + _brace_dir * (length / 2.0)
	_lane.global_rotation = Vector3(0, atan2(-_brace_dir.x, -_brace_dir.z), 0)
	_lane.visible = true


## CONDI'S SHUNTER SOUNDS (draft PR #45, b1235032): the horn is approved;
## the other seven are CANDIDATES, not approved, wired by her `events.json`
## (state, trigger, the 25 ms fades). One 3D player per event on the SFX
## bus at one level, as her level contract asks. A missing file falls back
## to the placeholder tone named beside it.
const SFX_DIR := "res://audio/sigmaudio/shunter/"
static var _sfx_streams := {}
var _sfx := {}


static func _sfx_library() -> Dictionary:
	if _sfx_streams.is_empty() and FileAccess.file_exists(SFX_DIR + "events.json"):
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(SFX_DIR + "events.json"))
		if parsed is Dictionary:
			for row: Dictionary in (parsed as Dictionary).get("events", []):
				var path := SFX_DIR + String(row.get("file", ""))
				if ResourceLoader.exists(path):
					_sfx_streams[String(row["event"])] = load(path)
	return _sfx_streams


func _sound(event: String, fallback: String) -> void:
	var stream: AudioStream = _sfx_library().get(event)
	if stream == null:
		if fallback != "":
			_placeholder(fallback)
		return
	var player: AudioStreamPlayer3D = _sfx.get(event)
	if player == null:
		player = AudioStreamPlayer3D.new()
		player.unit_size = _horn.unit_size
		player.max_distance = _horn.max_distance
		player.bus = _horn.bus
		player.stream = stream
		add_child(player)
		_sfx[event] = player
	player.set_meta("fading", false)
	player.volume_db = 0.0
	player.play()


## Fades a running event out over `seconds` (25 ms for a cut, per Condi).
func _fade(event: String, seconds: float) -> void:
	var player: AudioStreamPlayer3D = _sfx.get(event)
	if player == null or not player.playing or bool(player.get_meta("fading", false)):
		return
	player.set_meta("fading", true)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, seconds)
	tween.tween_callback(player.stop)


## Telemetry: what the weapon out did this fight.
func _tally(what: String, amount: float) -> void:
	_start_fight()
	var w := String(weapon_out.call())
	var row: Dictionary = fight.get(w, {"damage": 0.0, "hits": 0, "rushes": 0})
	if what == "damage":
		row["damage"] = float(row["damage"]) + amount
		row["hits"] = int(row["hits"]) + 1
	else:
		row["rushes"] = int(row["rushes"]) + int(amount)
	fight[w] = row


## The fight starts at the first horn, or the first hit if that came first.
func _start_fight() -> void:
	if _fight_from < 0.0:
		_fight_from = Engine.get_physics_frames() / float(
				Engine.physics_ticks_per_second)


func _summarise_fight() -> void:
	var now := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
	var rushes := 0
	for w: String in fight:
		rushes += int(fight[w]["rushes"])
	fight_summary = {"time_to_kill": now - _fight_from if _fight_from >= 0.0
			else -1.0, "rushes": rushes, "weapons": fight.duplicate(true)}
	print("FREIGHT BAY FIGHT: ", JSON.stringify(fight_summary))
	_log("fight", fight_summary)
	fight_recorded.emit(fight_summary)


## PLACEHOLDER SOUNDS from the game's enemy bank (owner, 2026-10-16:
## labelled placeholders until Condi makes the Shunter's own).
func _placeholder(kind: String) -> void:
	if _audio == null:
		return
	_audio.stream = Tones.enemy_stream(kind)
	_audio.play()


func _log(kind: String, data: Dictionary) -> void:
	var row := data.duplicate()
	row["t"] = Time.get_ticks_msec()
	row["frame"] = Engine.get_physics_frames()
	row["event"] = kind
	row["state"] = state
	row["hp"] = hp
	events_log.append(row)
