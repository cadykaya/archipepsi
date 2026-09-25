class_name Player
extends CharacterBody3D
## First-person controller. Every number comes from Constants (generated
## from schemas/constants.py) — do not invent movement values here.
##
## LMB is ALWAYS Static Pulse, never rebound. The four Echo slots take
## RMB / MMB+F / Shift / C (ECHOES §9), one runtime each.

signal hp_changed(hp: float, shield: float)
signal died
signal interact_prompt_changed(text: String)
signal fired_pulse
## One of the player's own attacks connected. `killed` marks the shot that
## finished the target: the crosshair and the mixer each say something
## different about that one.
signal hit_confirmed(killed: bool)
## Emitted with the world position damage came from, so the HUD can show
## which way to turn. `Vector3.INF` means "no direction" (falls, etc).
signal damaged_from(source_position: Vector3)
## `kind` is "step_a" / "step_b" / "land"; main routes it to the mixer.
signal footstep(kind: String)
## The frame a deliberate jump actually launched (buffered input resolving
## against coyote time) — the rule engine's `jump` event, not the input.
signal jumped

## Rail ride boundaries, for the operator log and for a test that has to
## prove a rail was RIDDEN rather than merely built (Stage 3A). Emitted
## by the ride itself, so nothing can report a catch that did not happen.
signal rail_caught(at: Vector3)
signal rail_released(at: Vector3)
## The consumable slot was pressed with nothing left. Carries the name so
## the HUD can say which supply and that entering a Zone refills it.
signal exhausted(supply_name: String)
## What the hand did or refused, for the HUD: "CARRYING · 18 kg",
## "TOO HEAVY TO CARRY · 61 kg (limit 60 kg)", "DROPPED", ...
signal carry_feedback(text: String, ok: bool)

#: ECHOES §9's control grammar, one binding per slot. LMB is the Static
#: Pulse and appears nowhere here: its identity is untouchable, so it is
#: not a slot and cannot be rebound to one.
const SLOT_ACTIONS := {
	"echo_a": "fire_echo",
	"echo_b": "fire_echo_b",
	"mobility": "fire_mobility",
	"utility": "fire_utility",
	# THE ONE THAT RUNS OUT. Its own key rather than a mode on another,
	# because a consumable you have to cycle to is a consumable you
	# forget you are carrying.
	"consumable": "fire_consumable",
}

const MOUSE_SENSITIVITY := 0.0022
#: Metres between footfalls. Paced by distance so it tracks speed Echoes.
const STEP_DISTANCE := 2.2
#: A landing needs real airtime AND real downward speed, so stair seams
#: and the first frame after a spawn do not thump.
const LAND_MIN_AIRTIME := 0.18
const LAND_MIN_SPEED := 3.0

## Head bob, paced by distance travelled like the footsteps are, so the
## dip and the footfall stay in phase at any speed multiplier — a bob on a
## wall-clock timer drifts away from the sound it is supposed to be part
## of. Small on purpose: this is a walk, not a boat.
const BOB_RISE := 0.032
const BOB_SWAY := 0.020
#: Deepest a hard landing may drop the view, in metres.
const LAND_DIP_MAX := 0.15

var hp: float = Constants.PLAYER_MAX_HP
## NAMED REASONS THIS BODY IS BEING HELD STILL.
##
## `input_frozen` was one boolean with two owners: `Main._update_modal`
## wrote it on every menu open and close, and `ZoneController` wrote it
## while waiting for the bridge's layout verdict. Whichever wrote last
## won, so closing the inventory released an acceptance hold and an
## acceptance released a pause. A hold is not a state, it is a CLAIM,
## and claims compose.
var _holds := {}

## Held while ANY claim stands. Read by everything that was reading the
## boolean; assigning it still works and takes the unnamed claim, which
## is what a test or a single-reason caller wants.
var input_frozen: bool:
	get:
		return not _holds.is_empty()
	set(value):
		if value:
			_holds["direct"] = true
		else:
			_holds.erase("direct")

## Claim this body, under a name only this holder uses.
func hold(reason: String) -> void:
	_holds[reason] = true

## Drop one claim. The body moves again when the last one goes.
func release(reason: String) -> void:
	_holds.erase(reason)

## Which claims stand, for a test or a diagnostic that needs to say why.
func holds() -> Array:
	var out: Array = _holds.keys()
	out.sort()
	return out

## Whether one named claim stands, for a reader that means that claim and
## not the others -- `enemy.gd` asks about the layout verdict only.
func held_by(reason: String) -> bool:
	return _holds.has(reason)

var gravity_mult := 1.0
var speed_mult := 1.0
## The rest of the S5 derived stat stack, refreshed every physics frame
## from `stat_stack`. Base is 1.0 for each; the stack owns floors/clamps.
var jump_mult := 1.0
var air_control_mult := 1.0
var friction_mult := 1.0
var damage_dealt_mult := 1.0
var damage_taken_mult := 1.0
var knockback_resist_mult := 1.0
var regen_mult := 1.0

var stat_stack := StatStack.new()
var statuses := StatusEffects.new()

## Set by EchoRuntime while a `glide` is held. 0 means not gliding. The
## runtime owns the decision; the player owns the physics, so a glide
## survives here as two numbers rather than as a reference to an ability.
var glide_fall_speed := 0.0
var glide_forward_speed := 0.0
## Set by EchoRuntime while a `hover` is held; 1.0 otherwise. Applied on
## top of the trait stack's gravity, same ownership split as the glide.
var hover_gravity_scale := 1.0

## Set by EchoRuntime when a `slam_ground` is committed to, and paid out on
## landing. It has to resolve HERE because only the body knows the frame it
## touched down on, and a slam that detonates on the way down is just a
## fast fall.
var pending_slam: Dictionary = {}

## `grapple_swing` tether: anchor, pull strength and the time it has left.
var _swing_anchor := Vector3.ZERO
var _swing_force := 0.0
var _swing_time := 0.0

## WHICH SLOT STARTED EACH PLAYER-SIDE EFFECT, or "" for none.
##
## Cleanup is shared; cancellation is not. Death ends everything the body
## is carrying. Unequipping ONE Echo ends only what THAT Echo started --
## and without a name on each effect those are the same call, so swapping
## a combat Echo would drop the tether a mobility Echo is holding you on.
##
## `_launch_flight` deliberately carries no owner: a launch pad started
## it, no Echo owns it, and no slot change may drop you out of the sky.
var _swing_owner := ""
var _slam_owner := ""

var _pulse_cooldown := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _dead := false
var _spawn_transform: Transform3D
var _interact_target: Node = null
## ORDINARY HAND CARRY (Design 2 §10.3-10.4). Not an Echo: every player
## has hands.
var carry: HandCarry = null
var _last_prompt := ""
var _step_accumulator := 0.0
var _step_toggle := false
var _airborne_time := 0.0
var _bob_phase := 0.0
var _bob_weight := 0.0
var _land_dip := 0.0

@onready var camera: Camera3D = $Camera3D
## slot -> EchoRuntime, one per `SLOT_NAMES`. Filled by `create()`, which
## is where the nodes are made — an `@onready` collection read the tree
## back and came up empty, and a dictionary that is sometimes empty is a
## loadout that sometimes silently has no buttons.
var runtimes: Dictionary = {}
## The slot the wheel cycles and the viewmodel shows. Every slot fires on
## its own key regardless; this is only "which one are you looking at".
var highlighted_slot := "echo_a"

## The highlighted slot's runtime. The HUD's cooldown bar, the viewmodel
## and the favourites wheel all mean this one; anything that must reach
## every slot iterates `runtimes` instead.
var echo_runtime: EchoRuntime:
	get:
		return runtimes.get(highlighted_slot, runtimes.get("echo_a"))

func set_highlighted_slot(slot: String) -> void:
	if slot in runtimes and slot != highlighted_slot:
		highlighted_slot = slot
		for runtime: EchoRuntime in runtimes.values():
			runtime.refresh_viewmodel()

## Total shield across every slot: two Echoes granting one each should
## read as two, and a hit should eat both before it reaches hp.
func total_shield() -> float:
	var total := 0.0
	for runtime: EchoRuntime in runtimes.values():
		total += runtime.shield_hp
	return total

# --- Affordance volumes (ECHOES §13) --------------------------------------
#
# Water, wind and rails influence movement while you are inside them. They
# are kept apart from the stat stack on purpose: `_refresh_derived_stats`
# rewrites every multiplier from the fold each frame, so a volume that
# wrote into those fields would be either erased or permanent depending on
# frame order. This layer is applied AFTER the stack and lasts exactly as
# long as the overlap.
#
# A volume may never strand you. Nothing here can pin you in place: lift is
# upward-only, drag is bounded, and speed is floored — see
# `MIN_VOLUME_SPEED_SCALE`. Combined with §13.2 (no feature on the mandatory
# path), that keeps the base kit sufficient no matter what a Zone offers.

## The hard floor on how slow any volume may make you. A volume is optional
## content; one that could stop you moving would be a trap, and the fact
## that features are off the mandatory path would stop being enough.
const MIN_VOLUME_SPEED_SCALE := 0.4
const MAX_VOLUME_DRAG := 6.0
## The slipperiest a volume may make the ground. A rail is meant to carry
## you further, not to be a surface you can never stop on.
const MIN_VOLUME_FRICTION_SCALE := 0.05

var _volumes: Dictionary = {}

## Called by an affordance volume's own Area3D on overlap. Keyed by the
## node so overlapping volumes cannot leave a stale influence behind when
## one of them is freed mid-overlap.
## Flying an authored launch arc: the state, and the protected motion.
##
## THREE THINGS THAT MUST STAY DISTINCT (owner ruling, 2026-09-09):
##
##   * BALLISTIC CARRIER MOTION -- `_launch_carrier`, the horizontal half
##     of the velocity the pad fired, supplied by the validated authored
##     solution and protected from the ordinary airborne lerp. It is
##     stored rather than left in `velocity` precisely so that nothing
##     which edits `velocity` can quietly erode it.
##   * BOUNDED PLAYER CORRECTION -- a modest airborne contribution
##     LAYERED ON TOP of the carrier each frame, capped at
##     `Constants.LAUNCH_CORRECTION_SPEED`. It may bend the arc. It may
##     not overwrite, erase or reverse it.
##   * ORDINARY MOVEMENT -- resumes untouched the moment the launch state
##     ends, which is what `_end_launch_flight` is for.
##
## WHY THE CARRIER NEEDS PROTECTING, MEASURED BEFORE IT WAS WRITTEN.
## `LaunchSolver` solves a BALLISTIC arc -- two free-fall halves, no
## horizontal loss -- and the pad fires exactly that velocity. The
## airborne walk solve lerps horizontal velocity toward the input
## direction every frame at `AIR_CONTROL`, so a player who lets go of the
## stick keeps `(1 - 0.16)^n` of it: over the hall pad's 1.43 s ascent
## that is 3.7e-7. The first measurement rose 24.21 m and travelled
## 0.00 m horizontally -- the player came straight back down onto the
## pad. Every authored launch was a bounce, which is the one thing
## `LaunchSolver` exists to distinguish itself from: "a bounce pad is a
## local vertical opportunity ... a launch pad is an EDGE -- source and
## destination are both part of the contract".
##
## AND WHY THE PLAYER STILL STEERS. The base player can always modestly
## correct in the air, and a launch that took that away would be a
## cutscene wearing a traversal's name. This is not homing, not
## path-following, not an Echo, and not a movement-package rule: it is
## the ordinary air correction, bounded, applied to a motion it cannot
## cancel.
var _launch_flight := false
var _launch_carrier := Vector3.ZERO

## Riding a rail, or null. The whole ride lives in `RailRider`, which## Riding a rail, or null. The whole ride lives in `RailRider`, which
## owns no node and reads no input, so it can be driven frame-exact in a
## headless test instead of only by a human on a controller.
var _rider: RailRider = null

## A rail lane offering itself as the player passes through it.
##
## AN OFFER, NOT AN ORDER: `RailRider.catch` decides, and it refuses a
## player who is too far off the path, below it, already past its end, or
## not moving along it. Walking sideways into a rail does nothing, which
## is what stops the room shoving people down it.
## `to_world` is the room's own transform: the path is authored local and
## the player is in world, and comparing the two directly is how a rail
## in a placed Zone came to be catchable from across the map.
func offer_rail(rail: RailPath, to_world := Transform3D.IDENTITY) -> void:
	if _rider != null or _dead:
		return
	var caught := RailRider.catch(rail, global_position, velocity, to_world)
	if caught.is_empty():
		return
	_rider = caught["rider"]
	# The rail owns the body now, so the arc is over whether or not the
	# ground was reached.
	_end_launch_flight()
	global_position = _rider.body_position()
	rail_caught.emit(global_position)
	Telemetry.rail_caught(global_position)

func riding_rail() -> bool:
	return _rider != null

## Flying an authored launch arc. Set by the pad that fired it, cleared
## by the landing, rail, respawn or spawn that ends it.
func in_launch_flight() -> bool:
	return _launch_flight

## The protected ballistic component, for a caller that has to prove it
## was not eroded. Horizontal only; the vertical half is plain gravity
## and was never in danger.
func launch_carrier() -> Vector3:
	return _launch_carrier

## Begin an authored launch arc. Called by `AffordanceNodes.LaunchPad`
## immediately after it applies the solved velocity, so the flight that
## happens is the flight that was validated.
func begin_launch_flight() -> void:
	_launch_flight = true
	_launch_carrier = Vector3(velocity.x, 0.0, velocity.z)

## End it, from wherever it ended.
##
## ONE PLACE, because "cleared on landing" and "cleared on respawn" being
## two different lines is how one of them comes to be forgotten. Called
## by the landing, by catching a rail, by respawn -- which is also the
## out-of-bounds recovery, since falling past `FALL_KILL_Y` kills -- and
## by `set_spawn`, which is Zone entry and replacement.
func _end_launch_flight() -> void:
	_launch_flight = false
	_launch_carrier = Vector3.ZERO

## THE CARRIER, PLUS WHAT THE PLAYER ADDS, MINUS NOTHING.
##
## `wish` is the ordinary input direction, already normalized by the walk
## solve, and zero when there is none. The correction is recomputed from
## the carrier every frame rather than accumulated, so holding a
## direction is a steady bend and letting go returns the arc exactly to
## the one that was validated.
##
## THE CARRIER MAY NOT BE CANCELLED (owner ruling, 2026-09-09). An
## earlier version clamped the RESULT's axial component at zero, which
## prevented reversal and still permitted cancellation: a 1 m/s carrier
## opposed by a 2 m/s correction stopped moving forward while the carrier
## sat privately stored and did nothing. A carrier preserved in a
## variable but absent from the velocity is not preserved.
##
## So the correction is DECOMPOSED against the authored axis before it is
## applied, and the opposing half is removed rather than clamped
## afterwards:
##
##   * the component ALONG the authored direction may only be positive --
##     bounded and additive, never subtractive;
##   * the component ACROSS it is free, bounded the same way, and bends
##     the arc;
##   * so the applied axial speed is `|carrier| + forward * SPEED`, never
##     less than the carrier's own.
##
## Holding directly backward therefore contributes no axial correction at
## all: it cannot slow the crossing, cancel it, or reverse it. The
## guarantee is arithmetic rather than tuned, and holds for a 1 m/s
## carrier as surely as a 20 m/s one.
func _carry_launch(wish: Vector3) -> void:
	var steer := Vector3(wish.x, 0.0, wish.z)
	if steer.length() > 1.0:
		steer = steer.normalized()
	var carrier := Vector3(_launch_carrier.x, 0.0, _launch_carrier.z)
	if carrier.length() < CARRIER_AXIS_EPS:
		# A PURELY VERTICAL LAUNCH HAS NO AUTHORED HORIZONTAL AXIS, and
		# inventing one would be authoring a direction the pad never
		# named. The carrier -- zero -- is preserved exactly, and the
		# whole bounded correction is available as lateral steering.
		velocity.x = steer.x * Constants.LAUNCH_CORRECTION_SPEED
		velocity.z = steer.z * Constants.LAUNCH_CORRECTION_SPEED
		return
	var axis := carrier.normalized()
	var axial := steer.dot(axis)
	var forward := maxf(axial, 0.0)
	var lateral := steer - axis * axial
	var applied := carrier \
			+ axis * (forward * Constants.LAUNCH_CORRECTION_SPEED) \
			+ lateral * Constants.LAUNCH_CORRECTION_SPEED
	velocity.x = applied.x
	velocity.z = applied.z

## Below this a launch has no authored horizontal direction to protect.
const CARRIER_AXIS_EPS := 0.001

## What the carrier contributes along its own axis, and what the velocity
## ACTUALLY APPLIED to the body contributes along it.
##
## Named so a proof can compare the two rather than infer the comparison
## from a landing position. "The carrier is preserved" means these agree
## every frame; a carrier living only in a private variable fails it.
func launch_axis_speed() -> float:
	var carrier := Vector3(_launch_carrier.x, 0.0, _launch_carrier.z)
	if carrier.length() < CARRIER_AXIS_EPS:
		return 0.0
	return Vector3(velocity.x, 0.0, velocity.z).dot(carrier.normalized())

func launch_carrier_axis_speed() -> float:
	return Vector3(_launch_carrier.x, 0.0, _launch_carrier.z).length()

## One step of a grind. Position comes from the path, velocity is what
## the player leaves with, and `move_and_slide` is deliberately NOT
## called: while riding, the rail is the collision.
func _ride(delta: float) -> void:
	var jump := not input_frozen \
			and Input.is_action_just_pressed("jump")
	var step: Dictionary = _rider.advance(delta, jump)
	global_position = step["position"]
	velocity = step["velocity"]
	if not bool(step["riding"]):
		_rider = null
		rail_released.emit(global_position)
		Telemetry.rail_released(global_position)
		# Off a rail is airborne, and a coyote frame here would give a
		# free second jump to anyone who let go near the ground.
		_coyote = 0.0
		_jump_buffer = 0.0
	_update_camera_feel(delta)

func enter_volume(volume: Node, influence: Dictionary) -> void:
	_volumes[volume] = influence

func exit_volume(volume: Node) -> void:
	_volumes.erase(volume)

## Merge every overlapping volume into one influence. Scales multiply so
## two volumes compose, lift sums, drag and terminal fall take the
## strongest claim, and the result is clamped to what cannot trap.
func environment_influence() -> Dictionary:
	var out := {"gravity_scale": 1.0, "speed_scale": 1.0, "lift": 0.0,
			"drag": 0.0, "terminal_fall": INF, "friction_scale": 1.0}
	for volume: Variant in _volumes.keys():
		if not is_instance_valid(volume):
			continue
		var influence: Dictionary = _volumes[volume]
		out["gravity_scale"] = float(out["gravity_scale"]) \
				* float(influence.get("gravity_scale", 1.0))
		out["speed_scale"] = float(out["speed_scale"]) \
				* float(influence.get("speed_scale", 1.0))
		out["lift"] = float(out["lift"]) + float(influence.get("lift", 0.0))
		out["drag"] = maxf(float(out["drag"]),
				float(influence.get("drag", 0.0)))
		out["terminal_fall"] = minf(float(out["terminal_fall"]),
				float(influence.get("terminal_fall", INF)))
		out["friction_scale"] = minf(
				float(out["friction_scale"]),
				float(influence.get("friction_scale", 1.0)))
	out["speed_scale"] = maxf(float(out["speed_scale"]),
			MIN_VOLUME_SPEED_SCALE)
	out["drag"] = minf(float(out["drag"]), MAX_VOLUME_DRAG)
	out["lift"] = maxf(float(out["lift"]), 0.0)
	# Floored, for the same reason speed is: a surface with no friction at
	# all is one you can never stop on, which is a trap wearing a rail's
	# clothes.
	out["friction_scale"] = clampf(
			float(out["friction_scale"]), MIN_VOLUME_FRICTION_SCALE, 1.0)
	return out
@onready var viewmodel: Node3D = $Camera3D/Viewmodel

static func create() -> Player:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/gameplay/player.gd"))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = Constants.PLAYER_HEIGHT
	capsule.radius = Constants.PLAYER_RADIUS
	shape.shape = capsule
	shape.position = Vector3(0, Constants.PLAYER_HEIGHT / 2.0, 0)
	player.add_child(shape)
	# Snap matched to the step the body can now climb, so ground within
	# one step stays underfoot on slopes and small undulations.
	#
	# It does NOT on its own make walking down a tread stop being a
	# short fall -- every precondition Godot documents was already met
	# and the body fell anyway. `_follow_the_step_down` is what fixes
	# that half, and the comment there records why the snap cannot.
	player.floor_snap_length = float(Constants.MAX_VERTICAL_STEP)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, Constants.PLAYER_EYE_HEIGHT, 0)
	camera.fov = PlayerSettings.shared().value("field_of_view")
	player.add_child(camera)

	# The viewmodel: a crude handheld transmitter, very 1998. The Static
	# Pulse emitter is always there; the Echo attachment appears when a
	# primary Echo is equipped.
	var viewmodel := Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = Vector3(0.34, -0.3, -0.62)
	viewmodel.rotation_degrees = Vector3(0, 8, -4)
	var device := MeshInstance3D.new()
	device.name = "Device"
	var device_mesh := PrismMesh.new()
	device_mesh.size = Vector3(0.14, 0.16, 0.4)
	device.mesh = device_mesh
	device.rotation_degrees = Vector3(-90, 0, 0)
	device.material_override = ThemeMaterials.glow_material(
			Color(0.35, 0.42, 0.5), 0.25)
	viewmodel.add_child(device)
	var tip := MeshInstance3D.new()
	tip.name = "Tip"
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.05, 0.05, 0.08)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.02, -0.24)
	tip.material_override = ThemeMaterials.glow_material(
			Color(0.75, 0.85, 1.0), 1.6)
	viewmodel.add_child(tip)
	var echo_part := MeshInstance3D.new()
	echo_part.name = "EchoPart"
	var echo_mesh := BoxMesh.new()
	echo_mesh.size = Vector3(0.10, 0.08, 0.26)
	echo_part.mesh = echo_mesh
	echo_part.position = Vector3(-0.11, 0.0, -0.05)
	echo_part.visible = false
	# The attachment's emitter tip. EchoRuntime paints the body with the
	# source world's colour and this with the archetype's.
	var echo_tip := MeshInstance3D.new()
	echo_tip.name = "EchoTip"
	var echo_tip_mesh := BoxMesh.new()
	echo_tip_mesh.size = Vector3(0.05, 0.04, 0.05)
	echo_tip.mesh = echo_tip_mesh
	echo_tip.position = Vector3(0, 0, -0.15)
	echo_part.add_child(echo_tip)
	viewmodel.add_child(echo_part)
	camera.add_child(viewmodel)

	# Muzzle flash: a one-frame light at the barrel. Without it a shot in
	# an unlit corridor lights nothing, which reads flat and cheap.
	var flash := OmniLight3D.new()
	flash.name = "MuzzleFlash"
	flash.position = Vector3(0, 0.02, -0.3)
	flash.omni_range = 9.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	viewmodel.add_child(flash)

	# S7: one runtime per slot (ECHOES §9). Cooldowns, held state and
	# airtime budgets belong to the Action, so each button needs its own —
	# sharing one would let a dash and a grapple contend for a single
	# cooldown, which is the bug the per-slot loadout exists to make
	# impossible.
	for slot: String in Constants.SLOT_NAMES:
		var runtime := Node.new()
		runtime.name = "EchoRuntime_" + slot
		runtime.set_script(load("res://scripts/gameplay/echo_runtime.gd"))
		player.add_child(runtime)
		runtime.slot = slot
		runtime.player_ref = player
		player.runtimes[slot] = runtime
		if slot == "consumable":
			# THE ANSWER IS WHAT FIRES IT, so the player listens for the
			# answer. Connected here, where the runtimes are built, so a
			# player that exists at all has this wire.
			if not BridgeClient.consumable_authorized.is_connected(
					player._on_consumable_authorized):
				BridgeClient.consumable_authorized.connect(
						player._on_consumable_authorized)
			if not BridgeClient.consumable_denied.is_connected(
					player._on_consumable_denied):
				BridgeClient.consumable_denied.connect(
						player._on_consumable_denied)
			# DID THE PRESS ACTUALLY PUT SOMETHING IN THE WORLD?
			# `activate()` returns early on cooldown, on an unmet
			# condition and on a closed gate, and a press that resolved
			# into nothing must not be paid for. This is what tells the
			# two apart; `press_slot` reads it.
			runtime.action_used.connect(player._note_launch)
	return player


## ONE SLOT'S BUTTON GOING DOWN, gate and all.
##
## Named rather than left inline in `_physics_process` so the tests press
## the REAL gate instead of a copy of it. The consumable path has two
## counts that must stay equal -- charges accepted and actions run -- and
## a test that reimplemented this decision would be measuring its own
## arithmetic rather than the game's.
func press_slot(slot: String) -> void:
	set_highlighted_slot(slot)
	# AN EMPTY SUPPLY REFUSES BEFORE IT COSTS ANYTHING. Like an unmet
	# condition, not like a miss: no cooldown is charged and no effect
	# runs, because a press that could never have resolved must not be
	# paid for. The supply stays equipped at 0 -- exhausted, not gone.
	if slot != "consumable":
		runtimes[slot].activate()
		return

	# THE PRESS ASKS. IT DOES NOT FIRE.
	#
	# D-9: the expenditure is authorised BEFORE anything irreversible
	# happens, because an effect that launched and whose report was lost
	# lives only in this process's memory -- kill Godot between the two
	# and the charge is spendable again. Asking first makes a lost
	# message an effect that never happened.
	#
	# The two things knowable WITHOUT the engine are checked here, so an
	# obviously dead press never reaches the bridge: nothing left in the
	# supply, and the Action's own cooldown. Everything else --
	# conditions, gates, link costs -- is `activate()`'s to refuse, and
	# it refuses on the far side of the authorisation, which is what
	# `release_authorization` is for.
	var component_id := str(BridgeClient.slotted_action(
			"consumable").get("component_id", ""))
	if BridgeClient.reserve_consumable(component_id).is_empty():
		_say_exhausted()
		return
	var runtime: EchoRuntime = runtimes[slot]
	if runtime.cooldown_remaining > 0.0:
		BridgeClient.release_reservation(component_id)
		return
	BridgeClient.authorize_consumable(component_id)


## THE CHARGE IS PAID FOR. **Now** the effect may happen.
##
## Reached from `BridgeClient.consumable_authorized`, which fires on the
## snapshot in which the engine moved `spent` and wrote the save. A
## press that resolves into nothing here still costs nothing: the
## authorisation is released, which is the only refund there is.
## THE PRESS WAS REFUSED, and nothing happened. Said out loud for the
## same reason an empty supply is: a button that does nothing in silence
## reads as broken.
func _on_consumable_denied(_component_id: String, _use_index: int,
		_why: String) -> void:
	_say_exhausted()


func _on_consumable_authorized(component_id: String,
		use_index: int) -> void:
	# AN ANSWER THAT LANDS WHILE THE WORLD IS PAUSED WAITS FOR IT (H-PAUSE,
	# `04_3D_MENU_MAP_AND_GLYPH.md` §4). The charge is paid -- the engine
	# moved `spent` and wrote the save -- so it is not refunded. But the
	# effect does not go into a stopped world: an instant one would change
	# it while it is stopped. It is kept, with its reservation still open,
	# and fires once, on the first step the world takes again.
	if is_inside_tree() and get_tree().paused:
		_answered_while_paused.append([component_id, use_index])
		return
	var slotted := str(BridgeClient.slotted_action("consumable").get(
			"component_id", ""))
	if component_id != slotted:
		# The slot changed between the press and the answer. Nothing
		# will fire, so give it back rather than firing the wrong thing.
		BridgeClient.release_authorization(component_id)
		return
	_launched = false
	runtimes["consumable"].activate()
	if not _launched:
		BridgeClient.release_authorization(component_id)
		return
	BridgeClient.commit_consumable(component_id)


## THE PLAYER'S OWN MASS CLASS: `PLAYER_MASS_KG` on the exported ladder,
## which is `MEDIUM` at 80 kg.
##
## **Only a plate that opts in ever reads it.** `ClassPlate` skips the
## player group unless its declaration sets `counts_player`, so EX50-033's
## object-only plate is untouched; and every other class consumer is typed
## to `ManipulableBody` (`manipulation.gd`, `affordance_nodes.gd`), while
## the sensors that sum weight read `.mass`, which a `Player` does not
## have. Adding this method changes what exactly one thing can see.
##
## **No Status moves it.** The bridge's route validator reads the player
## at `PLAYER_MASS_KG` with nothing applied (D-10 §6), and a route it
## certified must open for the body the runtime actually has. If a Status
## ever changes the player's class, that is a transient the validator
## does not model, and this is the line that would have to say so.
func mass_class() -> String:
	return MassClass.of_mass(Constants.PLAYER_MASS_KG)


## Is there anything left in the consumable slot? Counts what is in
## flight, so two presses inside one round trip cannot both fire.
func _has_a_charge() -> bool:
	var action: Dictionary = BridgeClient.slotted_action("consumable")
	if action.is_empty():
		return false
	return BridgeClient.charges_left(
			str(action.get("component_id", ""))) > 0


## Say why nothing happened, and what brings it back. An exhausted
## supply that refuses in silence reads as a broken button.
func _say_exhausted() -> void:
	var action: Dictionary = BridgeClient.slotted_action("consumable")
	if action.is_empty():
		return
	exhausted.emit(str(action.get("display_name", "Supply")))


## THE CONSUMABLE'S EFFECT REACHED THE WORLD.
##
## Set by `EchoRuntime.action_used`, read by `press_slot`, and that is
## the whole of it: the distinction between a press that fired and a
## press that returned early is what separates an expenditure from a
## refund, and this flag is where it lives.
var _launched := false

## Authorisations that arrived while the world was paused, as
## `[component_id, use_index]`, fired on the next physics step.
var _answered_while_paused: Array = []

func _note_launch() -> void:
	_launched = true


func _ready() -> void:
	add_to_group("player")
	carry = HandCarry.new(self)
	_spawn_transform = global_transform
	statuses.side = "self"
	stat_stack.statuses = statuses
	fired_pulse.connect(func() -> void:
		kick_viewmodel(0.05)
		muzzle_flash(1.6, Color(0.75, 0.85, 1.0)))

## Evaluate the stack and let statuses breathe. Runs at the top of every
## physics frame so `scaled_by` traits track live fractions.
func _refresh_derived_stats(delta: float) -> void:
	statuses.tick(delta)
	stat_stack.tick(delta)
	stat_stack.hp_fraction = hp / Constants.PLAYER_MAX_HP
	var stats := stat_stack.evaluate()
	speed_mult = float(stats["move_speed"])
	gravity_mult = float(stats["gravity"])
	jump_mult = float(stats["jump_height"])
	air_control_mult = float(stats["air_control"])
	friction_mult = float(stats["ground_friction"])
	damage_dealt_mult = float(stats["damage_dealt"])
	damage_taken_mult = float(stats["damage_taken"])
	knockback_resist_mult = float(stats["knockback_resist"])
	regen_mult = float(stats["regen"])
	var dot := statuses.dot_per_second()
	if dot > 0.0 and not _dead:
		take_damage(dot * delta, Vector3.INF, false)
	var regen := statuses.regen_per_second()
	if regen > 0.0 and not _dead and hp < Constants.PLAYER_MAX_HP:
		heal(regen * delta)

## A brief light at the barrel, sized to the shot.
func muzzle_flash(energy: float, color: Color) -> void:
	if viewmodel == null:
		return
	var flash: OmniLight3D = viewmodel.get_node_or_null("MuzzleFlash")
	if flash == null:
		return
	flash.light_color = color
	flash.light_energy = energy
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.09)

func kick_viewmodel(strength: float) -> void:
	if viewmodel == null:
		return
	var rest := Vector3(0.34, -0.3, -0.62)
	viewmodel.position = rest + Vector3(0, strength * 0.4, strength * 2.0)
	var tween := create_tween()
	tween.tween_property(viewmodel, "position", rest, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_spawn(xform: Transform3D) -> void:
	_spawn_transform = xform
	global_transform = xform
	# Zone entry and Zone replacement both come through here, and a
	# carrier that outlived its Zone would steer the next one.
	_end_launch_flight()

func _unhandled_input(event: InputEvent) -> void:
	if input_frozen or _dead:
		return
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# S21: sensitivity and invert-Y are preferences, read live so a
		# change in the pause menu takes effect without a reload.
		var settings := PlayerSettings.shared()
		var sensitivity := settings.value("mouse_sensitivity")
		var invert := -1.0 if settings.flag("invert_look_y") else 1.0
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity * invert)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

func _physics_process(delta: float) -> void:
	# A BODY THAT HAS LEFT THE WORLD DOES NOT MOVE THROUGH IT.
	#
	# Taking the exit portal removes the Zone, and this body goes with
	# it -- but a queued physics frame still arrives, and `move_and_slide`
	# on a body whose space has been freed is "Parameter
	# `body->get_space()` is null", which is a hard crash on the most
	# important transition in the game. Measured on a played Zone with
	# every Check claimed: the portal that ends a Zone ended the process
	# instead.
	if not is_inside_tree() or get_world_3d() == null:
		return
	_pulse_cooldown = maxf(0.0, _pulse_cooldown - delta)
	if _dead:
		return
	_refresh_derived_stats(delta)
	# THE WORLD IS RUNNING AGAIN, so an answer that landed during the pause
	# fires now -- once. (This step is the first thing a paused body does.)
	if not _answered_while_paused.is_empty():
		var held := _answered_while_paused.duplicate()
		_answered_while_paused.clear()
		for raw: Variant in held:
			var pair: Array = raw
			_on_consumable_authorized(str(pair[0]), int(pair[1]))

	# ON A RAIL, the rail moves you (P3.0). Not a cutscene: the speed is
	# the speed you brought, gravity still acts along the path so a climb
	# costs and a drop pays, and jump gets you off whenever you like. It
	# returns EARLY because a grind that also ran the walk solve would be
	# two things steering one body.
	if _rider != null:
		_ride(delta)
		return

	var env := environment_influence()
	var gravity := Constants.GRAVITY * gravity_mult * hover_gravity_scale \
			* float(env["gravity_scale"])
	if not is_on_floor():
		velocity.y -= gravity * delta
		_coyote -= delta
	else:
		_coyote = Constants.COYOTE_TIME
		# ONLY A LANDING ENDS THE ARC, and "on the floor" alone is not a
		# landing. `is_on_floor()` carries the last `move_and_slide`'s
		# answer, and a pad fires a player who is STANDING on it -- so on
		# the frame after the launch the flag is still true and the arc
		# would be stripped before it had risen a centimetre. Every
		# launch a player walked onto rather than fell onto would lose
		# its carrier, and only a test that dropped the body onto the pad
		# would fail to notice.
		#
		# A launch that has just fired is rising. A landing is not.
		if velocity.y <= 0.0:
			_end_launch_flight()
	_jump_buffer -= delta

	# Upward-only, and applied whether or not you are grounded: an updraft
	# you have to jump into first is an updraft nobody finds.
	if float(env["lift"]) > 0.0:
		velocity.y += float(env["lift"]) * delta
	velocity.y = maxf(velocity.y, -float(env["terminal_fall"]))
	if float(env["drag"]) > 0.0:
		var damping := 1.0 - minf(0.9, float(env["drag"]) * delta)
		velocity.x *= damping
		velocity.z *= damping

	# A glide caps the fall and adds a push along the look direction. Only
	# ever a CAP: it cannot make you rise, so it stays a descent you steer
	# rather than flight, and no gap becomes trivially crossable.
	if glide_fall_speed > 0.0 and not is_on_floor():
		velocity.y = maxf(velocity.y, -glide_fall_speed)
		var glide_dir := -camera.global_transform.basis.z
		var flat := Vector3(glide_dir.x, 0.0, glide_dir.z).normalized()
		velocity.x = lerpf(velocity.x, flat.x * glide_forward_speed, 0.08)
		velocity.z = lerpf(velocity.z, flat.z * glide_forward_speed, 0.08)

	_update_swing(delta)
	for runtime: EchoRuntime in runtimes.values():
		runtime.set_grounded(is_on_floor())

	if not input_frozen:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = Constants.JUMP_BUFFER
		if _jump_buffer > 0.0 and _coyote > 0.0:
			# Height scales with the square of launch speed, so a
			# jump_height multiplier rides in as its square root.
			velocity.y = Constants.JUMP_VELOCITY * sqrt(jump_mult)
			_jump_buffer = 0.0
			_coyote = 0.0
			jumped.emit()

		var input_dir := Input.get_vector(
				"move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis
				* Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed := Constants.WALK_SPEED * speed_mult \
				* float(env["speed_scale"]) * carry.speed_factor()
		# Friction below base is how a downside is allowed to express
		# (§10): slippier control, never a shorter jump.
		# A grind rail's lane multiplies ground friction down, so a dash
		# along it keeps its speed instead of being lerped back to walking
		# pace. The rail's first influence was `{drag: 0.0, speed_scale:
		# 1.0}` — both the identity element of how these merge, so the
		# whole feature did nothing at all.
		var control := friction_mult * float(env["friction_scale"]) \
				if is_on_floor() \
				else Constants.AIR_CONTROL * air_control_mult
		control = minf(control, 1.0)
		# ONE AUTHORITY FOR "IS THE ARC RUNNING", and it is
		# `_launch_flight`. Asking `is_on_floor()` here as well gave the
		# carry and the ending two different notions of airborne: on the
		# frame after a grounded launch the stale floor flag was true and
		# the arc was still running, so the ordinary lerp ran against a
		# live carrier and drove it to -2.2 m/s in a single frame.
		# `_end_launch_flight` decides when the arc is over; this only
		# asks whether it is.
		if _launch_flight:
			_carry_launch(direction)
		else:
			velocity.x = lerpf(velocity.x, direction.x * speed,
					control * 0.4)
			velocity.z = lerpf(velocity.z, direction.z * speed,
					control * 0.4)
		# HOW HARD THEY ARE TRYING TO WALK, which is not how fast they
		# are going. See `_shove_what_i_walked_into`.
		_walk_intent = Vector3(direction.x * speed, 0.0, direction.z * speed)

		# CARRYING BLOCKS THE WEAPON PRIMARY (Design 1 §10.2).
		if Input.is_action_pressed("fire_pulse") and not carry.holding():
			_fire_static_pulse()
		# The Static Pulse keeps LMB and is never any of these. Each slot
		# owns exactly one binding, so "which button was that" and "which
		# Echo fired" are the same question.
		for slot: String in SLOT_ACTIONS:
			var action: String = SLOT_ACTIONS[slot]
			if Input.is_action_just_pressed(action):
				# ...AND MOBILITY. Abilities stay usable: a defensive one
				# unavailable because you are holding a cube is a death
				# the player cannot explain (Design 1 §10.2).
				if slot == "mobility" and carry.holding():
					carry_feedback.emit("MOBILITY BLOCKED WHILE CARRYING",
							false)
				else:
					press_slot(slot)
			if Input.is_action_just_released(action):
				runtimes[slot].release()
		if Input.is_action_just_pressed("interact"):
			if carry.holding():
				carry.on_interact(_interact_target)
			elif _interact_target != null:
				_interact_target.interact(self)
	elif _launch_flight:
		# A frozen player steers nothing, so the carrier arrives intact.
		_carry_launch(Vector3.ZERO)
	else:
		velocity.x = lerpf(velocity.x, 0.0, 0.2)
		velocity.z = lerpf(velocity.z, 0.0, 0.2)
		_walk_intent = Vector3.ZERO

	var falling_speed := -velocity.y
	var was_airborne := not is_on_floor()
	_climb_a_step_the_law_promises(delta)
	_note_a_step_down_ahead(delta)
	move_and_slide()
	_follow_the_step_down()
	_shove_what_i_walked_into()
	if was_airborne and is_on_floor():
		_resolve_pending_slam()
	_update_footsteps(delta, falling_speed)
	_update_camera_feel(delta)
	carry.update(delta)
	_update_interact_target()

	if global_position.y < Constants.FALL_KILL_Y:
		take_damage(Constants.PLAYER_MAX_HP * 10.0)

## Static Pulse: hitscan, low damage, short cooldown, unlimited, reliable.
func _fire_static_pulse() -> void:
	if _pulse_cooldown > 0.0:
		return
	_pulse_cooldown = Constants.STATIC_PULSE_COOLDOWN
	fired_pulse.emit()
	var hit := camera_ray(Constants.STATIC_PULSE_RANGE)
	if not hit.is_empty():
		var target: Variant = hit["collider"]
		# Anything damageable, not just enemies: the Pulse is how a player
		# discovers that a breakable panel needs a heavier hit, and a
		# panel nothing could shoot was a wall with no feedback at all.
		if Damageable.of(target) != null:
			# §9: the Pulse's identity is untouchable, but a global
			# damage_dealt trait still multiplies it.
			report_hit(Damageable.hit(target,
					Constants.STATIC_PULSE_DAMAGE * damage_dealt_mult,
					-camera.global_transform.basis.z, 0.0))
	_spawn_tracer(hit)

## Attacks that do not originate here — Echo hitscans, Echo projectiles
## still in flight — confirm through this, so "my shot connected" is one
## signal no matter what fired it.
func report_hit(killed: bool) -> void:
	hit_confirmed.emit(killed)

## Footfalls paced by distance travelled, not by a timer, so they stay in
## step with the player at any speed multiplier.
func _update_footsteps(delta: float, falling_speed: float) -> void:
	if not is_on_floor():
		_airborne_time += delta
		return
	# Only a real fall lands. A single-frame loss of floor contact on a
	# stair seam or ramp is not a landing, and treating it as one both
	# replayed the loudest tone and reset the step cadence to silence.
	if _airborne_time > LAND_MIN_AIRTIME and falling_speed > LAND_MIN_SPEED:
		footstep.emit("land")
		# The view drops with the thump, in proportion to the drop.
		_land_dip = clampf(falling_speed / 90.0, 0.04, LAND_DIP_MAX)
		_step_accumulator = 0.0
	_airborne_time = 0.0

	var travelled := Vector2(velocity.x, velocity.z).length() * delta
	if travelled < 0.01:
		return
	_step_accumulator += travelled
	if _step_accumulator >= STEP_DISTANCE:
		_step_accumulator = 0.0
		_step_toggle = not _step_toggle
		footstep.emit("step_a" if _step_toggle else "step_b")

## Head bob and the landing dip. Only the camera's POSITION moves, never
## its rotation: the crosshair is where you aim, and a view that rolled
## with your gait would put shots somewhere other than the cross.
func _update_camera_feel(delta: float) -> void:
	if camera == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var walking := is_on_floor() and speed > 0.6 and not _dead
	if walking:
		_bob_phase += speed * delta / STEP_DISTANCE * PI
	# Weight, not phase, is what fades: cutting the phase would snap the
	# view to wherever the sine happened to be when you stopped.
	_bob_weight = lerpf(_bob_weight, 1.0 if walking else 0.0,
			minf(1.0, delta * 9.0))
	_land_dip = lerpf(_land_dip, 0.0, minf(1.0, delta * 9.0))
	if _bob_weight < 0.001 and _land_dip < 0.001:
		_bob_weight = 0.0
		_land_dip = 0.0
	camera.position = Vector3(0, Constants.PLAYER_EYE_HEIGHT, 0) \
			+ camera_feel_offset(_bob_phase, _bob_weight, _land_dip)

## Pure, so the bounds below can be tested rather than trusted: whatever
## the gait is doing, the view stays within a few centimetres of the eye
## height every other number in the game is derived from.
static func camera_feel_offset(phase: float, weight: float,
		dip: float) -> Vector3:
	# S21 accessibility: `motion_intensity` scales view bob and the
	# landing dip, and 0 turns both off completely. Motion sickness is
	# the reason the option exists, so "off" has to actually be off --
	# a reduced-motion setting with a floor above zero is not one.
	var motion := PlayerSettings.shared().value("motion_intensity")
	return Vector3(sin(phase) * BOB_SWAY * weight * motion,
			sin(phase * 2.0) * BOB_RISE * weight * motion - dip * motion,
			0.0)

## THE STEP THE MOVEMENT LAW ALREADY PROMISED.
##
## `MAX_VERTICAL_STEP` was a number the generator built levels around and
## the body never honoured. `chamber_builders` says so where it raises a
## tower -- "each platform rises `step_rise` <= MAX_VERTICAL_STEP, so the
## mandatory route up is base-kit" -- and this file's own gallery lip
## carries the other half of the evidence: "there is no step-up anywhere
## in `player.gd` [...] so a 0.35 m kerb stops a walking player dead",
## worked around there by notching a gap in the lip rather than by
## giving the body the step.
##
## Measured on the played proposal: pedestal steps rise 0.4 m, the
## gallery deck lip 0.35 m, tower platforms `step_rise`. All of them
## were jumps. `DestructibleCover` is 1.4 m and `ReactiveBarrel` 1.1 m,
## both above the limit, so cover stays cover -- the step does not turn
## a firefight into a stroll over the crates.
##
## Godot's `CharacterBody3D` has no automatic step-up, so this is the
## usual three-probe form: is the foot blocked, is there room to rise,
## is there room to stand once risen. Nothing moves unless all three
## agree, and the body is lifted only as far as the surface it found --
## never the full limit on faith.
func _climb_a_step_the_law_promises(delta: float) -> void:
	if not is_on_floor():
		return
	# WHAT THE PLAYER IS TRYING TO DO, not what the wall left of it.
	#
	# The first version read `velocity`, and `move_and_slide` has already
	# resolved that against the obstacle by the time the next frame
	# arrives: pressed against a 0.8 m ledge the body reported a single
	# frame of intent and then zero, so the probe below almost never ran
	# and the step looked unimplemented. `_walk_intent` is the field this
	# file already keeps for the question "what are they trying to walk
	# into" -- `_shove_what_i_walked_into` reads it for the same reason.
	var wish := Vector3(_walk_intent.x, 0.0, _walk_intent.z) * delta
	if wish.length_squared() < 0.000001:
		return
	# 1. IS THE FOOT ACTUALLY BLOCKED? A clear path needs no step, and
	#    lifting the body on an open floor is how a step-up turns into a
	#    hover.
	if not test_move(global_transform, wish):
		return
	var step := float(Constants.MAX_VERTICAL_STEP)
	# 2. IS THERE ROOM TO RISE? This is the headroom test: a body under a
	#    low ceiling may not step, which keeps a crawl space a crawl
	#    space rather than a staircase.
	if test_move(global_transform, Vector3.UP * step):
		return
	var lifted := global_transform.translated(Vector3.UP * step)
	# PAST THE LIP, NOT UP TO IT. One frame of walking is about 0.12 m
	# and the capsule's axis sits `PLAYER_RADIUS` behind its leading
	# surface, so probing one frame ahead tests a column of air in front
	# of the step and reports "nothing under the landing" while standing
	# against a perfectly good tread. The landing is probed from where
	# the BODY would stand, which is a radius past the edge it is
	# touching.
	var reach := wish.normalized() * (Constants.PLAYER_RADIUS + 0.05)
	# 3. AND ROOM TO STAND ONCE RISEN, at the place the move would end.
	if test_move(lifted, reach):
		return
	# WHERE THE SURFACE ACTUALLY IS. Drop back down from the lifted spot
	# and take the rise the floor gives, so a 0.4 m pedestal costs 0.4 m
	# and not the whole limit.
	var ahead := lifted.translated(reach)
	var probe := KinematicCollision3D.new()
	if not test_move(ahead, Vector3.DOWN * (step + 0.05), probe):
		return                     # nothing under it: that is a ledge
	# A THING YOU ARE MEANT TO PUSH IS NOT A STAIR.
	#
	# The first version of this climbed a 60 kg crate instead of shoving
	# it, and `physics_driver` caught it: three seconds of walking moved
	# the crate 0.01 m because the player was standing on top of it. The
	# step reads STATIC level geometry; anything the game hands the
	# player as manipulable stays an obstacle for
	# `_shove_what_i_walked_into` to deal with.
	if probe.get_collider() is ManipulableBody:
		return
	var rise := step - probe.get_travel().length()
	if rise <= 0.01 or rise > step + 0.001:
		return
	global_position += Vector3.UP * rise


## AND THE SAME STEP, WALKED DOWN.
##
## The ascent above was only half the defect, and the other half read
## like a Godot bug for a batch: `floor_snap_length` is
## `MAX_VERTICAL_STEP`, `velocity.y` is zero, `up_direction` is +Y and
## the motion mode is grounded -- every precondition Godot's own floor
## snap documents -- and a body walking off a 0.4 m tread still left
## the floor and free-fell the drop.
##
## MEASURED, not reasoned about. A probe in `_physics_process` printed
## the state on the frame contact was lost and then called
## `apply_floor_snap()` by hand:
##
##     lost floor y=0.741 vy=+0.0000 down_hit=true trav=0.109
##       after apply_floor_snap: floor=false y=0.741 (moved 0.000)
##
## Ground was 0.341 m below and the cast stopped at 0.109 m, because
## the body has NOT yet cleared the tread it is leaving: the capsule's
## lower hemisphere is still within its radius of that tread's top
## edge, and a straight-down cast from where the body ended hits THE
## EDGE. 0.109 m is the exact capsule-against-corner solution for this
## geometry, so the number named its own cause. The normal off an edge
## is 55 degrees from vertical -- past `floor_max_angle` -- so the snap
## classifies the staircase as a wall and refuses, and the body falls.
## Raising `floor_snap_length` can never help: the obstruction is
## 0.1 m away, not 1 m.
##
## So the drop is measured from a probe placed a radius PAST the edge,
## where the cast reaches real ground, and the body is then walked down
## by that much over the following frames -- through `move_and_collide`,
## so it rides the edge rather than clipping through it, and with
## `velocity.y` held at zero so no fall accumulates into the landing.
##
## WHAT THIS DELIBERATELY DOES NOT DO. There is no adhesion: the budget
## comes from a surface that was actually found, within one step, at a
## standable angle, and a body beside a pit finds nothing and falls as
## before. A rising body is never pulled down -- a jump, a launch pad,
## a rail and a swing each clear the budget on sight. And the limit is
## `MAX_VERTICAL_STEP`, the same number the ascent uses, so the rule is
## the symmetric one: what you can walk up, you can walk down.
func _note_a_step_down_ahead(delta: float) -> void:
	if not is_on_floor():
		return
	# A DELIBERATE DEPARTURE OWNS THE BODY. The jump has already set
	# `velocity.y` by the time this runs, so a rising body is visible
	# here and is never a descent.
	if velocity.y > 0.0 or _launch_flight or _rider != null \
			or _swing_time > 0.0:
		_step_down_left = 0.0
		return
	var wish := Vector3(_walk_intent.x, 0.0, _walk_intent.z) * delta
	if wish.length_squared() < 0.000001:
		return
	var step := float(Constants.MAX_VERTICAL_STEP)
	# PAST THE LIP, for the same reason the ascent probes past it: a
	# cast from where the body stands hits the edge it is standing on.
	var reach := wish.normalized() * (Constants.PLAYER_RADIUS + 0.05)
	# SOMETHING AHEAD IS THE ASCENT'S CASE, not this one.
	if test_move(global_transform, reach):
		return
	var ahead := global_transform.translated(reach)
	var probe := KinematicCollision3D.new()
	if not test_move(ahead, Vector3.DOWN * (step + 0.05), probe):
		return                     # nothing within a step: a real drop
	var drop := probe.get_travel().length()
	# The ground continues under the body, or it falls away further than
	# a step does. Neither is a stair.
	if drop <= 0.02 or drop > step:
		return
	# A SURFACE THAT CANNOT BE STOOD ON IS NOT A TREAD, and a thing the
	# player is meant to shove is not one either.
	if probe.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return
	if probe.get_collider() is ManipulableBody:
		return
	_step_down_left = drop + 0.05


## The other half of the pair, after the walk has happened.
func _follow_the_step_down() -> void:
	if is_on_floor():
		_step_down_left = 0.0
		return
	if _step_down_left <= 0.0:
		return
	if velocity.y > 0.0 or _launch_flight or _rider != null \
			or _swing_time > 0.0:
		_step_down_left = 0.0
		return
	# ONLY ONTO SOMETHING. `move_and_collide` travels the WHOLE distance
	# when nothing stops it, so an unchecked call at the lip of a pit
	# would teleport the body a metre down into it.
	if not test_move(global_transform, Vector3.DOWN * _step_down_left):
		_step_down_left = 0.0
		return
	var before := global_position.y
	move_and_collide(Vector3.DOWN * _step_down_left)
	var travelled := before - global_position.y
	_step_down_left -= travelled
	# The drop is WALKED. Without this the frames spent riding the edge
	# would accumulate speed and arrive as a fall, which is the thump
	# and the camera dip this whole function exists to remove.
	velocity.y = 0.0
	apply_floor_snap()
	if is_on_floor() or travelled < 0.001 or _step_down_left <= 0.01:
		_step_down_left = 0.0


func camera_ray(distance: float, spread_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	if spread_dir != Vector3.ZERO:
		dir = spread_dir
	var to := from + dir * distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	# THE SAME DEPARTURE, ASKED A DIFFERENT WAY. `get_world_3d()` is
	# null for a node outside the tree, and this line read
	# `.direct_space_state` off it without asking -- "Invalid access to
	# property or key 'direct_space_state' on a base object of type
	# 'null instance'". The interact probe and every shot run through
	# here each frame, so the first frame after the portal fires is the
	# one that crashes. An empty result is what "nothing is there"
	# already means to every caller.
	var world := get_world_3d()
	if world == null:
		return {}
	return world.direct_space_state.intersect_ray(query)

func _spawn_tracer(hit: Dictionary) -> void:
	var from := camera.global_position \
			+ camera.global_transform.basis * Vector3(0.15, -0.12, -0.3)
	var to: Vector3 = hit["position"] if not hit.is_empty() \
			else camera.global_position \
			- camera.global_transform.basis.z * Constants.STATIC_PULSE_RANGE
	# Static Pulse is made of the garbage Epsilon leaves behind: the more
	# Static the multiworld has delivered, the more it discolors.
	var units := int(BridgeClient.snapshot.get("static_glitch_units", 0))
	var corruption := minf(1.0, float(units)
			/ float(Constants.STATIC_GLITCH_VISUAL_CAP))
	var color := Color(0.75, 0.85, 1.0).lerp(
			Color(1.0, 0.35, 0.9), corruption * 0.7)
	Tracer.spawn(get_tree().current_scene, from, to, color, 0.06)

## `parryable` is false for damage that is not a hit to read.
##
## A parry is a timed answer to something arriving, and a damage-over-time
## tick is neither timed nor arriving: it is the same status bleeding out
## a sixtieth of a second's worth. Letting it through the parry path meant
## 0.067 damage of burn spent the whole window, so any DoT made parry
## unusable -- and it emitted `parried`, which `main.gd` turns into a free
## `parry_success` rule event, so a burn turned that event into something
## the player could produce by standing still.
func take_damage(amount: float,
		source_position: Vector3 = Vector3.INF,
		parryable: bool = true) -> void:
	if _dead:
		return
	amount *= damage_taken_mult
	# Parry first wherever it is, then shields in slot order — the same
	# precedence one runtime used, spread across four.
	for runtime: EchoRuntime in runtimes.values():
		amount = runtime.absorb_with_shield(amount, parryable)
		if amount <= 0.0:
			break
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, total_shield())
	damaged_from.emit(source_position)
	if hp <= 0.0:
		_die()

## External shoves come through here so `knockback_resist` has one place
## to push back. Self-chosen recoil (the shotgun's travel plan) does not —
## resisting your own movement tech would be a downside wearing a buff.
func receive_knockback(impulse: Vector3) -> void:
	velocity += impulse / maxf(knockback_resist_mult, 0.25)

func heal(amount: float) -> void:
	# `regen` is a multiplier on recovery received — the game has no base
	# trickle for it to scale, and healing-in is the recovery that exists.
	hp = minf(Constants.PLAYER_MAX_HP, hp + amount * regen_mult)
	hp_changed.emit(hp, total_shield())

func _die() -> void:
	_dead = true
	# WHAT THE HAND HELD IS PUT DOWN WHERE IT WAS, at rest. Recovery is
	# the object's own business (§10.5), not a side effect of dying.
	if carry != null and carry.holding():
		carry.release("death")
	# EVERY transient effect, not only the launch arc. See
	# `cancel_transient_effects` for the two that used to survive.
	cancel_transient_effects()
	# `_physics_process` returns early while dead, so the arc would
	# otherwise sit inert until respawn. Ending it here keeps "am I in a
	# launch" answerable at every moment rather than only at the ones
	# physics happens to run.
	_end_launch_flight()
	# Every runtime, not just the highlighted one: all four keep their own
	# `_physics_process`, and this branch is where they stop being polled.
	for runtime: EchoRuntime in runtimes.values():
		runtime.cancel_holds()
	died.emit()
	# PAUSES WITH THE WORLD (H-PAUSE): a SceneTree timer runs through a
	# pause unless it is told not to.
	var timer := get_tree().create_timer(Constants.RESPAWN_DELAY, false)
	timer.timeout.connect(_respawn)

func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	# BELT AND BRACES, and not redundant: `died` is emitted from `_die`
	# and a listener can commit something during the respawn delay.
	cancel_transient_effects()
	# Also the out-of-bounds recovery: falling past `FALL_KILL_Y` kills,
	# so this is where a player who flew off the map comes back, and they
	# must not come back still carrying the arc that threw them.
	_end_launch_flight()
	hp = Constants.PLAYER_MAX_HP
	_dead = false
	hp_changed.emit(hp, total_shield())

func _update_interact_target() -> void:
	var hit := camera_ray(3.0)
	var target: Node = null
	if not hit.is_empty():
		var collider: Variant = hit["collider"]
		if is_instance_valid(collider) and (collider.has_method("interact")
				or collider.has_method("install_refusal")):
			target = collider
	_interact_target = target
	# THE PROMPT IS WHAT `interact` WOULD DO NOW, which depends on the
	# hand as well as on the target -- so it is recomputed every frame and
	# emitted when its text changes, not only when the target does.
	var prompt := ""
	if carry != null and carry.holding():
		if target != null and target.has_method("install_refusal"):
			var why: String = target.install_refusal(carry.body)
			prompt = "[E] INSTALL" if why == "" else why
		else:
			prompt = "[E] DROP"
	elif target != null and target.has_method("interact_prompt"):
		prompt = target.interact_prompt()
	elif target != null and target.has_method("interact"):
		prompt = "[E] INTERACT"
	if prompt != _last_prompt:
		_last_prompt = prompt
		interact_prompt_changed.emit(prompt)

## Pays out a committed `slam_ground` on the frame the body touches down.
## Radial, falling off toward the rim, exactly like `arc_lob` — the two are
## the same shape of hit and should read the same way.
func _resolve_pending_slam() -> void:
	if pending_slam.is_empty():
		return
	var damage := float(pending_slam.get("damage", 0.0))
	var radius := float(pending_slam.get("radius", 0.0))
	var tint: Color = pending_slam.get("tint", Color(1.0, 0.6, 0.3))
	pending_slam = {}
	var hit_any := false
	var killed_any := false
	for node in get_tree().get_nodes_in_group(Damageable.GROUP):
		var struck := node as Node3D
		if struck == null or not is_instance_valid(struck):
			continue
		var offset := struck.global_position - global_position
		var distance := offset.length()
		if distance > radius:
			continue
		var falloff := 1.0 - clampf(distance / maxf(radius, 0.001), 0.0, 1.0) * 0.6
		var away := offset.normalized() if distance > 0.001 else Vector3.UP
		if Damageable.hit(struck, damage * falloff, away, 0.0):
			killed_any = true
		hit_any = true
	if hit_any:
		report_hit(killed_any)
	Blast.spawn(get_tree().current_scene, global_position, radius, tint)
	_land_dip = LAND_DIP_MAX

## Starts a `grapple_swing` tether. The anchor is a point, not a node: the
## geometry it was cast at is static, and holding a reference would keep a
## freed chamber alive across a zone change.
func begin_swing(anchor: Vector3, force: float, duration: float,
		owner := "") -> void:
	_swing_anchor = anchor
	_swing_force = force
	_swing_time = duration
	_swing_owner = owner

## Commit a slam, remembering which slot committed it.
func commit_slam(slam: Dictionary, owner := "") -> void:
	pending_slam = slam
	_slam_owner = owner

## End the tether. `by` is the slot asking; "" is death, and ends it
## whoever owns it.
func end_swing(by := "") -> void:
	if _swing_time <= 0.0:
		return
	if by != "" and by != _swing_owner:
		return
	_swing_time = 0.0
	_swing_force = 0.0
	_swing_anchor = Vector3.ZERO
	_swing_owner = ""

func cancel_slam(by := "") -> void:
	if pending_slam.is_empty():
		return
	if by != "" and by != _slam_owner:
		return
	pending_slam = {}
	_slam_owner = ""

## Everything the body is carrying that must not outlive a death.
##
## Two of these outlived one. `_swing_time` was frozen rather than
## cleared -- `_update_swing` is polled AFTER the `if _dead: return`
## guard, so a player who died mid-swing came back with the timer intact
## and the tether resumed pulling them toward an anchor in a part of the
## room they were no longer in. `pending_slam` did the same: a slam
## committed before dying detonated on the first landing after respawn,
## at the respawn point.
func cancel_transient_effects() -> void:
	end_swing()
	cancel_slam()
	_end_launch_flight()

## A tether pulls you toward the anchor along the rope and leaves the
## tangential component alone — that difference is the whole reason this is
## a swing and not a second grapple. It ends on the timer, on landing, or
## when the key comes up.
func _update_swing(delta: float) -> void:
	if _swing_time <= 0.0:
		return
	_swing_time -= delta
	if _swing_time <= 0.0 or is_on_floor() \
			or not Input.is_action_pressed("fire_echo"):
		_swing_time = 0.0
		return
	var to_anchor := _swing_anchor - global_position
	var distance := to_anchor.length()
	if distance < 0.6:
		_swing_time = 0.0
		return
	var rope := to_anchor / distance
	# Only the part of the pull that is not already along the rope does
	# anything, so the arc accelerates instead of snapping taut.
	velocity += rope * _swing_force * delta
	var along := velocity.dot(rope)
	if along < 0.0:
		velocity -= rope * along * 0.5

## WALKING INTO A CRATE MOVES IT, and every player can do it.
##
## `CharacterBody3D` does not push a `RigidBody3D`: `move_and_slide`
## resolves the collision by sliding the character and leaves the body
## where it was. Without this a crate is a wall that happens to have
## mass, and the only thing in the build that could move one was a
## harness calling `apply_central_force` -- which proves the physics and
## nothing about the game.
##
## **NO CAPABILITY, NO VERB, NO ECHO.** This is the base character
## shoving something with their body, available to every player from the
## first Zone. `Manipulation`'s envelope is a different question --
## whether a HOST qualifies to be relied on by content authored at
## §29.3.2's minimum -- and it stays where it is. Routing an ordinary
## shove through it would have made a crate an undeclared capability
## gate, which is the one thing the environmental-agency chain must not
## become.
##
## The impulse is the momentum the character was carrying into the
## contact, scaled by how much of it was into the body rather than along
## it. A player who walks past a crate does not fling it.
##
## **IT IS THE INTENT, NOT THE ACHIEVED VELOCITY**, and two wrong
## versions got here. Reading `velocity` after `move_and_slide` gives
## zero by construction: resolving the contact is exactly what removes
## the component heading into the body. Reading it BEFORE the slide is
## better and still wrong — a player already pressed against a crate is
## being held there, so their velocity into it is near zero on every
## frame after the first, and a three-second push moved a 60 kg crate
## 0.07 m.
##
## What is constant while somebody leans on something is how hard they
## are trying to walk, and that is `_walk_intent`. It is what a shove
## should be proportional to, and it is what a person means by pushing.
func _shove_what_i_walked_into() -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as ManipulableBody
		if body == null or body.constrained or body.freeze:
			continue
		# INTO the body, not along its face. `get_normal` points back at
		# the character, so the push direction is its negation.
		var into := -hit.get_normal()
		var speed := _walk_intent.dot(into)
		if speed <= 0.0:
			continue
		# THROUGH THE BODY'S OWN FUNNEL. This is an IMPULSE, and Design 5
		# §15.2 gives `lightened` "incoming impulse x2.0" -- so a crate
		# that is carrying it takes twice as much from the same shove.
		# One of only two places in the engine that puts force on a
		# `RigidBody3D`, which is why the scaling can live in the body
		# rather than being remembered at each call site.
		body.receive_impulse(
				into * speed * SHOVE_MASS_KG * get_physics_process_delta_time())

## How hard the player is trying to walk this frame, in m/s, before the
## world has had its say. Zero whenever they are not walking.
var _walk_intent := Vector3.ZERO

## HOW MUCH OF A STEP THE BODY STILL OWES, walking down one. Zero
## except for the two or three frames a descent actually takes; see
## `_note_a_step_down_ahead`.
var _step_down_left := 0.0

## The mass the player shoves WITH.
##
## A character controller has no mass -- it is kinematic -- so the
## momentum it delivers has to be stated. Set to the player's own
## plausible mass: a body shoves a crate about as well as it would in
## life, a 500 kg block barely moves, and nothing here can be tuned into
## a capability by accident.
const SHOVE_MASS_KG := 80.0
