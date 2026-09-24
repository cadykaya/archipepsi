class_name Enemy
extends CharacterBody3D
## Stat-driven from Constants.ENEMY_STATS, sized from
## Constants.ENEMY_ENVELOPES.
## melee: walks at the player, short-range hits.
## ranged: holds position, fires slow visible projectiles.
## brute: large, slow, high-health — the POC boss.
##
## Those three are the roles that can be PLACED. The approved art family is
## ten (`Constants.ENEMY_ROLES`), and every one of them has an agreed
## physical envelope so models can be built against it — but a role with an
## envelope and no stat block still has no behaviour, and `create()` refuses
## it rather than inventing one. Physical integration first (art req 7).
##
## Direct steering plus collision recovery; no navmesh (EPSILON_SPEC §5).
## An enemy below ENEMY_FALL_KILL_Y counts as dead, so a steered-off enemy
## can never leave kill_all unsatisfiable.

signal enemy_died(enemy: Enemy)

## An attack's windup began (art requirement 14). `kind` names the attack,
## `duration` is how long the promise lasts in seconds.
##
## A TELEGRAPH IS A PROMISE. This pair is the seam an authored telegraph
## attaches to: it fires from the real attack state, so a presentation
## that listens cannot drift from the attack it is announcing, and it
## never needs a clock of its own. Read `telegraph_progress()` for 0..1.
signal telegraph_started(kind: String, duration: float)
## The windup ended. `completed` is true when the attack actually landed
## and false when the enemy died or was removed part-way through — so a
## presentation can end differently for a promise kept and one broken,
## and either way it is TOLD rather than left to time out.
signal telegraph_finished(kind: String, completed: bool)

var archetype := "melee"
## This role's physical envelope, from `Constants.ENEMY_ENVELOPES`. Read by
## anything that needs to know how much room this enemy takes without
## measuring its collider back out of the tree.
var envelope: Dictionary = {}
var hp := 24.0
## Starting HP, kept so an ability can ask how heavy this is.
## `grapple_pull_target` refuses a brute by asking this rather
## than by naming archetypes, so a future heavy enemy is
## covered without touching the primitive.
var max_hp := 24.0
var stats: Dictionary = {}
var _attack_cooldown := 0.0
var _dead := false
var _knockback := Vector3.ZERO
# Collision recovery (EPSILON_SPEC §5): sidestep briefly when walled.
var _sidestep_timer := 0.0
## Helpless after a swing (`BULWARK_RECOVERY_SECONDS`). Zero for every
## role that does not declare one.
var _recovery := 0.0
var _sidestep_dir := Vector3.ZERO
var _sidestep_flip := false
# Per-instance materials for the damage tint, unshared once on first hit.
var _tint_parts: Array[StandardMaterial3D] = []
var _tint_base_energy: Array[float] = []
var _tint_base_albedo: Array[Color] = []
var _voice: AudioStreamPlayer3D = null
var _has_noticed := false
# Brute slam windup.
## HOW LONG EACH ARCHETYPE COMMITS BEFORE ITS ATTACK LANDS.
##
## A table rather than literals at the call sites, because "how long is
## the brute's windup" is a question a designer asks and a suite
## measures, and it was previously answerable only by reading the middle
## of `_try_attack`.
##
## **`melee` is absent on purpose.** The contact attack is the cheap one
## and its reach is a body-length; a windup there is a mob standing next
## to you doing nothing. The brute's slam is the telegraphed melee and
## that is the distinction the roster draws. Recorded as a decision so
## the gap is not read as the same defect F-14 named.
const TELEGRAPH_SECONDS := {
	"brute": 0.5,
	# THE RANGED WINDUP (F-14, H2). This archetype fired the instant its
	# cooldown allowed, from any distance inside its reach, with nothing
	# to see first -- `godot-counterfire` measured it and reported
	# "windup: none" as a finding rather than a number. A shot you cannot
	# see coming is not dodgeable, and EX50-021's whole §11 case is a
	# player stepping out of a committed shot's way.
	#
	# 0.45 s: shorter than the brute's, because the projectile's own
	# flight already gives the player most of a second on top, and a
	# ranged enemy planted for half a second at range reads as an easy
	# target rather than as a threat.
	"ranged": 0.45,
	# ONE TELEGRAPHED RUSH is the charger's entire brief, so its windup
	# is the longest here: the rush is unsteerable and heavy, and a
	# player who cannot see it coming has been hit by something they
	# could not have answered.
	"charger": 0.7,
	# An artillery piece ranges before it fires. Long, because the shell
	# lands where you WERE and leaving is the counterplay.
	"artillery": 0.8,
	# A diver commits from above; short, because it is already visible
	# and the fall does the telegraphing.
	"diver": 0.35,
	# PT-13: THE DRIFTER'S SHOT IS THE RANGED ONE'S, from above, and it
	# fired the instant its cooldown allowed with nothing to see first --
	# the F-14 defect the ranged role had, left on the one that shoots
	# down at you. Same windup, same reason.
	"drifter": 0.45,
}

## How close a diver's body has to come to the player's for its dive to
## land. One number, used by the dive and by the reach it commits from.
const DIVE_CONTACT := 1.6

## PT-13: WHAT AN ENEMY IS DOING, VISIBLE IN ITS EYE. Multiples of the
## eye's authored glow (`EYE_ENERGY`). Every role's eye flares while it
## telegraphs. A flyer's also says whether it has noticed the player: a
## diver waiting for the player to leave the ground looked, to the
## player, exactly like one that was broken.
const EYE_ENERGY := 2.4
const EYE_IDLE := 0.45
const EYE_WATCHING := 1.0
const EYE_FLARE := 2.6
var _eye_level := EYE_WATCHING

var _windup := 0.0
## OV04 P06 role state. One block, because seven roles each carrying a
## private field scattered through this file is how the three-archetype
## version became hard to read.
##
## `_rush` is the charger's remaining commit; `_recover` its helpless
## window afterwards. `_dive` is the diver's. `_beacon_beat` paces the
## beacon's refresh so it is not an every-frame broadcast.
var _rush := 0.0
var _rush_dir := Vector3.ZERO
var _recover := 0.0
var _dive := 0.0
var _beacon_beat := 0.0
## Where a flyer holds station. Resolved once from the floor under it,
## because a flyer that recomputed its own hover height every frame
## drifts upward over a slope.
var _hover_y := 0.0
var _hover_set := false

## OV04 P07: THE JOB. Where this enemy belongs, what it does there, and
## how long it stays interested once it has seen you.
##
## `post` is captured on the first physics frame rather than at
## `create`, because a composer places an enemy after building it and a
## post recorded at construction would be the origin.
var post := Vector3.ZERO
var _post_set := false
var job := ""
## Seconds of interest left. Above zero, the enemy is engaged even if
## the player has stepped out of its radius.
var _interest := 0.0
## Patrol bookkeeping: which end of the beat it is walking to, and how
## long it is pausing there.
var _beat := Vector3.ZERO
var _beat_set := false
var _pause := 0.0
## True while walking back to the post after losing interest. Public,
## because "did it go back to work" is the question P07.4 asks.
var returning := false
## Presentation-only container. EVERY mesh hangs off this and nothing
## else does, so a hit flinch or a windup swell scales the LOOK and can
## never move the collider -- which is what `scale` on the body did, and
## it grew the brute's hitbox 12% for the half second it was winding up.
var visual: Node3D = null
## Where an authored telegraph attaches. A `Marker3D` at the collider's
## centre (`Constants.ENEMY_ENVELOPES[role].centre_y`), outside `visual`
## so a flinch does not drag the telegraph around with it.
var telegraph_origin: Marker3D = null
## The attack currently being telegraphed, "" when none.
var telegraph_kind := ""
var telegraph_duration := 0.0

static func create(kind: String, theme: String) -> Enemy:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/enemies/enemy.gd"))
	enemy.archetype = kind
	enemy.name = "Enemy_%s" % kind
	assert(Constants.ENEMY_STATS.has(kind),
			"'%s' has a physical envelope but no behaviour; " % kind
			+ "an approved art role is not yet a placeable enemy")
	var block: Dictionary = Constants.ENEMY_STATS[kind]
	enemy.stats = block
	enemy.hp = float(block["hp"])
	enemy.max_hp = float(block["hp"])

	# The envelope is CONTRACT, not a literal (art requirement 7). It used
	# to be three magic vectors in this match, while the art lane built
	# models to boxes it declared in a manifest -- two numbers for one
	# thing, and a model that clips through a door frame is the first time
	# anyone finds out. Both sides now read Constants.ENEMY_ENVELOPES.
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES[kind]
	var size: Vector3 = envelope["size"]
	enemy.envelope = envelope
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	# Half-height for a walker, hover height for a flyer. Asking the
	# contract rather than assuming size.y / 2.0, which is only true of
	# something standing on the floor.
	shape.position = Vector3(0, float(envelope["centre_y"]), 0)
	enemy.add_child(shape)

	# Presentation hangs off `Visual`; the collider does not. Scaling the
	# BODY for a flinch or a windup swell scaled its collision shape too,
	# so the brute's hitbox grew 12% for the half second it telegraphed
	# and shrank to 88% every time it was hit. Presentation is never
	# mechanics truth (art requirement 14), and now it structurally cannot
	# be: there is nothing solid under `Visual` to scale.
	var body_visual := Node3D.new()
	body_visual.name = "Visual"
	enemy.add_child(body_visual)
	enemy.visual = body_visual

	# The attachment contract. A telegraph is authored against a stable
	# origin, and "the collider's centre" is the one point every role
	# already agrees on -- it comes from the same envelope the collider
	# does. Outside `Visual`, so a flinch does not drag it around.
	var origin := Marker3D.new()
	origin.name = "TelegraphOrigin"
	origin.position = Vector3(0, float(envelope["centre_y"]), 0)
	enemy.add_child(origin)
	enemy.telegraph_origin = origin

	# Each archetype gets its own silhouette, because telling a sniper
	# from a charger across a dark room is gameplay information, not
	# decoration. Theme only supplies the palette.
	#
	# PT-12: A FLYER IS DRAWN WHERE IT CAN BE HIT. Its collider hangs at
	# the envelope's hover height above the pivot, and the walker
	# fallback it used to get was built up from the pivot -- so the body
	# the player saw and the box a shot could hit were two different
	# places. A flyer's `Visual` sits at the collider's centre and its
	# silhouette is built inside the collider's box, so a flinch also
	# scales it about its own middle rather than about the floor.
	if bool(envelope["flying"]):
		body_visual.position = Vector3(0, float(envelope["centre_y"]), 0)
		_build_flyer(body_visual, size, theme, kind)
		return enemy
	match kind:
		"ranged": _build_ranged(body_visual, size, theme)
		"brute": _build_brute(body_visual, size, theme)
		_: _build_melee(body_visual, size, theme)
	return enemy

static func _part(parent: Node3D, size: Vector3, at: Vector3,
		material: Material, tilt := 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.rotation.x = tilt
	part.material_override = material
	parent.add_child(part)
	return part

static func _eye(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> void:
	_part(parent, size, at, ThemeMaterials.glow_material(color,
			EYE_ENERGY)).name = "Eye"

## Melee: hunched and forward-leaning, with stubby arms — it reads as
## something that wants to be where you are.
static func _build_melee(enemy: Node3D, size: Vector3, theme: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	_part(enemy, Vector3(size.x, size.y * 0.5, size.z * 0.8),
			Vector3(0, size.y * 0.34, -0.06), accent, -0.22)
	# Low, jutting head.
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(size.x * 0.7, size.y * 0.22, size.z * 0.9)
	head.mesh = head_mesh
	head.position = Vector3(0, size.y * 0.66, -size.z * 0.2)
	head.rotation.x = PI / 2.0          # snout forward, not spire upward
	head.material_override = trim
	enemy.add_child(head)
	# Arms stay inside the collider half-width (size.x * 0.5): geometry
	# that reaches past it clips through walls and door frames, and the
	# corridor lane budgets are sized to the collider.
	for side in [-1.0, 1.0]:
		_part(enemy, Vector3(size.x * 0.24, size.y * 0.36, size.z * 0.24),
				Vector3(side * size.x * 0.38, size.y * 0.34, -0.1), trim, -0.4)
	_part(enemy, Vector3(size.x * 0.7, size.y * 0.2, size.z * 0.6),
			Vector3(0, size.y * 0.1, 0), trim)
	_eye(enemy, Vector3(size.x * 0.42, 0.07, 0.05),
			Vector3(0, size.y * 0.66, -size.z * 0.56), Color(1.0, 0.3, 0.2))

## Ranged: a tall tripod that never moves — narrow stalk, big single lens.
static func _build_ranged(enemy: Node3D, size: Vector3, theme: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	for leg in 3:
		var angle := TAU * float(leg) / 3.0
		_part(enemy, Vector3(0.12, size.y * 0.5, 0.12),
				Vector3(sin(angle) * size.x * 0.4, size.y * 0.25,
					cos(angle) * size.z * 0.4), trim)
	_part(enemy, Vector3(0.16, size.y * 0.35, 0.16),
			Vector3(0, size.y * 0.62, 0), trim)
	# The head is the whole point of it: a wide sensor block, kept just
	# inside the collider so it cannot poke through walls.
	_part(enemy, Vector3(size.x * 0.95, size.y * 0.3, size.z * 0.7),
			Vector3(0, size.y * 0.88, 0), accent)
	_eye(enemy, Vector3(size.x * 0.8, 0.14, 0.05),
			Vector3(0, size.y * 0.88, -size.z * 0.38), Color(1.0, 0.6, 0.15))

## Flyers, built about the collider's CENTRE (their `Visual` sits there)
## and inside its box on every axis, because the box is what a shot hits
## and what a doorway has to admit. Provisional engine silhouettes: the
## art lane's models replace the look against the same box, never the
## box.
##
## Diver: a dart -- a fuselage the length of the envelope, swept wings,
## the eye on the nose (-z, the way it faces) and talons underneath.
## Drifter: a wide canopy that owns the space above, an emitter and lens
## underneath that it shoots down from, and hanging vanes.
static func _build_flyer(enemy: Node3D, size: Vector3, theme: String,
		kind: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	if kind == "diver":
		_part(enemy, Vector3(size.x * 0.36, size.y * 0.5, size.z * 0.92),
				Vector3.ZERO, accent)
		for side in [-1.0, 1.0]:
			_part(enemy, Vector3(size.x * 0.32, size.y * 0.12, size.z * 0.42),
					Vector3(side * size.x * 0.34, size.y * 0.06,
						size.z * 0.1), trim)
			_part(enemy, Vector3(size.x * 0.08, size.y * 0.24, size.x * 0.08),
					Vector3(side * size.x * 0.12, -size.y * 0.36,
						-size.z * 0.08), trim)
		_part(enemy, Vector3(size.x * 0.06, size.y * 0.42, size.z * 0.22),
				Vector3(0, size.y * 0.27, size.z * 0.36), trim)
		_eye(enemy, Vector3(size.x * 0.26, size.y * 0.1, 0.04),
				Vector3(0, size.y * 0.08, -size.z * 0.47), Color(1.0, 0.3, 0.2))
		return
	var canopy := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = minf(size.x, size.z) * 0.36
	disc.bottom_radius = minf(size.x, size.z) * 0.49
	disc.height = size.y * 0.34
	canopy.mesh = disc
	canopy.position = Vector3(0, size.y * 0.2, 0)
	canopy.material_override = accent
	enemy.add_child(canopy)
	_part(enemy, Vector3(size.x * 0.34, size.y * 0.12, size.z * 0.34),
			Vector3(0, size.y * 0.42, 0), trim)
	_part(enemy, Vector3(size.x * 0.3, size.y * 0.22, size.z * 0.3),
			Vector3(0, -size.y * 0.08, 0), trim)
	for vane in 4:
		var angle := TAU * float(vane) / 4.0 + PI / 4.0
		_part(enemy, Vector3(0.06, size.y * 0.4, 0.06),
				Vector3(sin(angle) * size.x * 0.3, -size.y * 0.24,
					cos(angle) * size.z * 0.3), trim)
	_eye(enemy, Vector3(size.x * 0.2, 0.05, size.z * 0.2),
			Vector3(0, -size.y * 0.215, 0), Color(1.0, 0.6, 0.15))

## Brute: wide and low-slung, with shoulder blocks and a tiny head, so it
## reads as heavy before it reads as anything else.
static func _build_brute(enemy: Node3D, size: Vector3, theme: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	_part(enemy, Vector3(size.x, size.y * 0.46, size.z * 0.75),
			Vector3(0, size.y * 0.44, 0), accent)
	# Shoulders and arms are held inside the collider half-width
	# (size.x * 0.5). The brute's 1.8 m body already nearly fills a 2.4 m
	# doorway; geometry wider than the collider clips straight through it.
	for side in [-1.0, 1.0]:
		_part(enemy, Vector3(size.x * 0.28, size.y * 0.26, size.z * 0.9),
				Vector3(side * size.x * 0.36, size.y * 0.62, 0), trim)
		# Heavy arms hanging past the waist.
		_part(enemy, Vector3(size.x * 0.24, size.y * 0.42, size.z * 0.28),
				Vector3(side * size.x * 0.37, size.y * 0.26, -0.1), accent)
		# Legs.
		_part(enemy, Vector3(size.x * 0.3, size.y * 0.24, size.z * 0.35),
				Vector3(side * size.x * 0.24, size.y * 0.11, 0), trim)
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(size.x * 0.34, size.y * 0.16, size.z * 0.34)
	head.mesh = head_mesh
	head.position = Vector3(0, size.y * 0.74, -size.z * 0.1)
	head.material_override = trim
	enemy.add_child(head)
	_eye(enemy, Vector3(size.x * 0.22, 0.09, 0.05),
			Vector3(0, size.y * 0.74, -size.z * 0.3), Color(1.0, 0.2, 0.15))

## S5 statuses: this enemy's own conditions. Reset with the enemy, which
## dies or despawns with the Zone — nothing here is ever saved (I9).
var statuses := StatusEffects.new()

func _ready() -> void:
	add_to_group("enemies")
	# ...and the wider group every damage path tests. "enemies" still
	# means enemies, for the paths that mean enemies.
	add_to_group(Damageable.GROUP)
	statuses.side = "enemy"
	statuses.status_applied.connect(func(_kind: String) -> void:
		_refresh_damage_tint())
	# Positional audio: a shot from off-screen should tell you where to
	# look, which the damage indicator can only do after you are already hit.
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 6.0
	_voice.max_distance = 45.0
	_voice.volume_db = -6.0
	add_child(_voice)

func _say(kind: String) -> void:
	if _voice == null:
		return
	_voice.stream = Tones.enemy_stream(kind)
	_voice.play()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y < Constants.ENEMY_FALL_KILL_Y:
		die()                      # counts as dead: kill_all stays satisfiable
		return
	# Shocked nerves recover slower; the cooldown itself is the stagger.
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta
			* (1.0 - 0.5 * clampf(statuses.magnitude_of("shocked"), 0.0, 1.0)))
	statuses.tick(delta)
	var dot := statuses.dot_per_second()
	if dot > 0.0:
		_take_dot(dot * delta)
		if _dead:
			return

	# ANCHORED IS IMMUNE TO ALL IMPULSE (Design 5 §15.2): a knock that
	# lands on it goes nowhere, and it does not slide on from one that
	# landed before. ROOTED is not -- "can still be pushed, pulled, and
	# thrown, unlike `anchored`" -- so its knock is taken as usual.
	if statuses.has("anchored"):
		_knockback = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
	velocity += _knockback
	_knockback = Vector3.ZERO
	# OV04 P06: A FLYER HOLDS A HEIGHT rather than falling to the floor.
	#
	# `is_flying` is the envelope's own field, so this asks the same
	# contract the art toolchain and the spawn placement ask. A drifter
	# that fell would be a walker with a drifter's collider, and "owns
	# the ceiling" would be a description of nothing.
	if bool(envelope.get("flying", false)):
		if _held_in_place():
			# Holding station is a flyer's own power too: held, it stays
			# where it is -- neither climbing back after a knock nor
			# falling, which nothing in §15.2 asks of it.
			velocity.y = lerpf(velocity.y, 0.0, 0.3)
		else:
			_hold_station(delta)
	elif not is_on_floor():
		velocity.y -= Constants.GRAVITY * delta

	_sidestep_timer = maxf(0.0, _sidestep_timer - delta)
	# THE OPENING. A bulwark that has just swung is helpless for
	# `BULWARK_RECOVERY_SECONDS`: it does not turn and it does not
	# attack, which is the window the player's circling is meant to be
	# paid off in.
	_recovery = maxf(0.0, _recovery - delta)
	var intended := Vector3.ZERO
	var position_before := global_position
	var player := _find_player()

	# The slam countdown runs unconditionally: a windup that started must
	# always resolve, even if the player dies or runs out of aggro range
	# during it. Otherwise the brute freezes mid-swell and fires a stale,
	# untelegraphed slam whenever the player next wanders close.
	if _windup > 0.0:
		_windup -= delta
		# The swell is the ENGINE's fallback telegraph, and it scales
		# `visual` rather than the body -- on the body it grew the
		# collider with it. An authored telegraph listening to
		# `telegraph_started` replaces the look and never the timing.
		_set_visual_scale(1.0 + 0.12 * sin(
				(telegraph_duration - _windup) * TAU))
		if _windup <= 0.0:
			_set_visual_scale(1.0)
			# WHAT THE TELEGRAPH WAS FOR, dispatched on the kind. This
			# read `_slam` unconditionally, which is the reason only the
			# brute could telegraph: any other attack that opened a
			# windup would have resolved into the brute's slam.
			var kind := telegraph_kind
			_say(kind)
			if player != null:
				_resolve_telegraph(kind, player)
			_end_telegraph(true)

	if bool(envelope.get("flying", false)):
		_present_flyer(player, delta)
	# OV04 P06: the committed motions, which OVERRIDE the ordinary
	# approach rather than blending with it. A charger mid-rush is not
	# steering, and a diver mid-dive is not reconsidering; that is the
	# whole of both counterplays.
	if _spend_commitment(delta, player):
		move_and_slide()
		return
	if archetype == "beacon":
		_beacon_pulse(delta)

	# OV04 P07: THE POST AND THE JOB, resolved once on the first frame
	# this enemy actually runs -- by which time whatever placed it has
	# put it where it belongs.
	if not _post_set:
		post = global_position
		_post_set = true
		job = str(Constants.ENEMY_JOBS.get(archetype, "watch"))

	if player != null:
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		# `low_profile` on the player shrinks how far this enemy notices —
		# §10's "visibility" channel, a downside's counterpart.
		# AS FAR AS IT CAN SHOOT, and no less. `ENEMY_AGGRO_RADIUS` is
		# 18 m and artillery's declared reach is 34, so a flat radius
		# made the top half of its range unusable: it could never notice
		# anything it was built to hit. A role notices at the greater of
		# the two, which leaves every existing role exactly where it was
		# (melee 2, ranged 40 -- the ranged one gains, correctly, for
		# the same reason).
		var aggro := maxf(Constants.ENEMY_AGGRO_RADIUS,
				float(stats["reach"])) \
				* (1.0 - 0.5 * clampf(
						player.statuses.magnitude_of("low_profile"), 0.0, 1.0))
		# INTEREST OUTLIVES RANGE. Stepping a metre outside the radius
		# used to switch an enemy off mid-fight -- trivially
		# exploitable, and it reads as the enemy forgetting you while
		# looking straight at you.
		if distance <= aggro:
			_interest = Constants.ENEMY_INTEREST_SECONDS
		else:
			_interest = maxf(0.0, _interest - delta)
		if distance <= aggro or _interest > 0.0:
			if not _has_noticed:
				_has_noticed = true
				_say("aggro")
			var flat := Vector3(to_player.x, 0, to_player.z)
			if flat.length() > 0.05:
				_face(flat, delta)
			var speed := float(stats["speed"]) \
					* (1.0 - 0.5 * clampf(
							statuses.magnitude_of("slowed"), 0.0, 1.0))
			if statuses.has("frozen") or statuses.has("stunned"):
				# Held in place, attacks withheld. The two differ in how
				# they were earned and how they read, not in physics.
				velocity.x = lerpf(velocity.x, 0.0, 0.5)
				velocity.z = lerpf(velocity.z, 0.0, 0.5)
			elif _windup > 0.0:
				# Committed: plant and telegraph, whatever the attack is.
				# The countdown itself runs below, outside this branch, so
				# losing aggro mid-swing cannot freeze an enemy
				# mid-telegraph. A ranged enemy planting to aim is what
				# makes its shot readable AND what makes it vulnerable
				# while it takes one.
				velocity.x = lerpf(velocity.x, 0.0, 0.4)
				velocity.z = lerpf(velocity.z, 0.0, 0.4)
			elif _held_in_place():
				# ROOTED OR ANCHORED: no step of its own. What is already
				# moving it -- a knock it took -- runs down exactly as it
				# does for an enemy standing still in reach, and the attack
				# below is not withheld: "attacks continue".
				velocity.x = lerpf(velocity.x, 0.0, 0.3)
				velocity.z = lerpf(velocity.z, 0.0, 0.3)
			elif speed > 0.0 and distance > _standoff():
				var dir := flat.normalized()
				if _sidestep_timer > 0.0:
					dir = _sidestep_dir
				intended = dir * speed
				velocity.x = lerpf(velocity.x, dir.x * speed, 0.2)
				velocity.z = lerpf(velocity.z, dir.z * speed, 0.2)
			else:
				velocity.x = lerpf(velocity.x, 0.0, 0.3)
				velocity.z = lerpf(velocity.z, 0.0, 0.3)
			if _windup <= 0.0 and not statuses.has("frozen") \
					and not statuses.has("stunned"):
				_try_attack(player, distance)
		else:
			# OUT OF MIND: back to work. This branch did not exist, so
			# an enemy outside its radius stood exactly where it was
			# placed, for ever.
			if _has_noticed:
				_has_noticed = false
				returning = true
			_work(delta)
	else:
		# NO PLAYER AT ALL, which is not the same as one out of range and
		# had no path through the code: interest was only decayed inside
		# the `player != null` branch, so an enemy whose player left the
		# scene stayed permanently alert and never went back to work.
		_interest = maxf(0.0, _interest - delta)
		if _interest <= 0.0 and _has_noticed:
			_has_noticed = false
			returning = true
		_work(delta)
	move_and_slide()
	# Collision recovery: wanted to move but barely did -> slide sideways
	# for a beat instead of grinding into the geometry forever.
	#
	# The test is ACTUAL displacement, not post-slide velocity:
	# move_and_slide() rewrites velocity to the slid value, so a head-on
	# wall hit leaves ~0 horizontal velocity and a velocity-based test
	# never fires — precisely the stuck case this exists for.
	if player != null and _sidestep_timer <= 0.0 and intended != Vector3.ZERO:
		var moved := global_position - position_before
		var wanted := intended.length() * delta
		if Vector2(moved.x, moved.z).length() < wanted * 0.35:
			var toward := player.global_position - global_position
			var side := Vector3(toward.z, 0, -toward.x).normalized()
			# Alternate on each attempt: a side that stayed blocked is not
			# retried forever in a concave corner.
			_sidestep_flip = not _sidestep_flip
			_sidestep_dir = -side if _sidestep_flip else side
			_sidestep_timer = 0.55

## TURN TOWARD THE PLAYER, at this role's own rate.
##
## **A ROLE WITH A REAR ARC NEEDS THAT ARC TO BE REACHABLE.** Every role
## used to snap: `look_at` every frame it had noticed you. For the
## `bulwark` that silently cancelled its own brief -- the armour leaves
## the back open, and a player who ran round arrived to find it already
## facing them, so "cannot be fought frontally" became "cannot be
## fought". A declared `turn_rate` caps how fast the facing can change;
## a role without one snaps as before, so nothing else in the roster
## moves.
##
## **AND IT DOES NOT TURN WHILE COMMITTED.** A windup is a commitment
## everywhere else in this file -- the charger's rush direction is fixed
## when the telegraph starts, and the artillery's aim point with it --
## and a body that plants to swing while still tracking is not committed
## to anything. Holding the facing for the windup is what turns the
## telegraph into a readable opening rather than a pause.
func _face(flat: Vector3, delta: float) -> void:
	var wanted := atan2(-flat.x, -flat.z)
	if archetype != "bulwark":
		rotation.y = wanted
		return
	# THE THREE NUMBERS ARE ONE OPENING, and they are declared together
	# in `schemas/constants.py` beside `bulwark_opening()`, which states
	# the arithmetic they produce. A fourth key in `ENEMY_STATS` would
	# have been a turn rate with no commit and no recovery beside it --
	# a third of a design, readable as the whole of one.
	if _windup > 0.0 or _recovery > 0.0:
		return                     # committed, or helpless: no turning
	rotation.y = rotate_toward(rotation.y, wanted,
			deg_to_rad(Constants.BULWARK_TURN_RATE_DEG_S) * delta)


## The player this enemy may act on, or null.
##
## **NOT WHILE THE LAYOUT VERDICT HOLDS THEM.** A graph Zone freezes its
## player from the moment the body exists until the bridge certifies the
## layout, because gameplay waits for the verdict
## (`ZoneController._await_verdict`) -- and the enemies did not wait.
## Certifying a Zone's chains takes seconds, and artillery notices at its
## 34 m reach and fires without line of sight, so the first played run of
## the latched route lost 80 hp at its own arrival point, frozen, before
## it could take a step: five 16 hp shells from the battery in the next
## room. A player the verdict is holding is absent to an enemy. Only that
## claim: every other hold keeps the meaning it had.
func _find_player() -> Player:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var found: Player = players[0]
	if found != null and found.held_by(ZoneController.LAYOUT_HOLD):
		return null
	return found

func _try_attack(player: Player, distance: float) -> void:
	if _attack_cooldown > 0.0 or _recovery > 0.0:
		return
	var reach := float(stats["reach"])
	# OV04 P06: the seven roles from the approved roster. Each is its own
	# branch because each has its own answer to "what does attacking
	# mean", and a shared one would be the three-archetype shape with
	# names added.
	if archetype == "charger":
		# ONE TELEGRAPHED RUSH. The direction is fixed when the windup
		# STARTS, not when it ends: committing to where the player was
		# is what makes side-stepping the counterplay.
		if distance <= reach and _has_line_of_sight(player):
			_attack_cooldown = float(stats["cooldown"])
			var to := player.global_position - global_position
			_rush_dir = Vector3(to.x, 0.0, to.z).normalized()
			_begin_telegraph("charge",
					float(TELEGRAPH_SECONDS["charger"]))
			_say("windup")
		return
	if archetype == "artillery":
		# INDIRECT, AND IT CANNOT DEPRESS. Inside its minimum range it
		# has no answer at all, which is the ground it fails to deny.
		#
		# PT-11 (post-playtest): IT SHELLS WHAT IT CAN SEE, ALONG AN ARC
		# THAT IS REALLY THERE. Distance alone let it shell the next room
		# through a wall and a player under a roof. Knowledge is its own
		# line of sight; the path is the shell's own arc, sampled against
		# the world. Low cover and open ground still get shelled -- this
		# is physics, not a room-ID force field.
		if distance >= Constants.ARTILLERY_MIN_RANGE and distance <= reach:
			if not _has_line_of_sight(player) \
					or not ArtilleryShell.arc_is_clear(get_world_3d()
							.direct_space_state, muzzle(),
							player.global_position, _blast_exclusions()):
				# Look again shortly rather than every frame.
				_attack_cooldown = 0.5
				return
			_attack_cooldown = float(stats["cooldown"])
			_rush_dir = player.global_position
			_begin_telegraph("shell",
					float(TELEGRAPH_SECONDS["artillery"]))
			_say("windup")
		return
	if archetype == "diver":
		# CONTESTS THE AIR: it commits only when the player has left the
		# ground, which is what makes it a counter to traversal rather
		# than another thing shooting at you.
		#
		# PT-13: AND ONLY A DIVE THAT CAN ARRIVE, AT A PLAYER IT CAN SEE.
		# It committed from its whole 18 m notice radius with a dive that
		# carries 6.3 m, so most dives ended in the air short of anyone;
		# and it committed through walls, since nothing asked for sight.
		# `reach` stays what it notices from; `_dive_reach` is what it
		# strikes from.
		if body_centre().distance_to(_centre_of(player)) <= _dive_reach() \
				and _player_is_airborne(player) \
				and _has_line_of_sight(player):
			_attack_cooldown = float(stats["cooldown"])
			_begin_telegraph("dive", float(TELEGRAPH_SECONDS["diver"]))
			_say("windup")
		return
	if archetype == "drifter":
		# OWNS THE CEILING and shoots down from it -- COMMITTED, THEN
		# FIRED, exactly as the ranged role is (see there): sight is
		# checked when the shot is committed, and the "aim" windup
		# resolves into `_fire_projectile`.
		if distance <= reach and _has_line_of_sight(player):
			_attack_cooldown = float(stats["cooldown"])
			_begin_telegraph("aim", float(TELEGRAPH_SECONDS["drifter"]))
			_say("windup")
		return
	if archetype == "beacon":
		# MAKES EVERYTHING NEAR IT WORSE. Its own attack is an
		# afterthought; `_beacon_pulse` is the actual job and runs in
		# `_physics_process` whether or not the player is in reach.
		if distance <= reach:
			_attack_cooldown = float(stats["cooldown"])
			_say("melee_hit")
			player.take_damage(_hit_for(), global_position)
		return
	if archetype == "bulwark" or archetype == "scuttler":
		# Both close in and hit. What distinguishes them is not the
		# attack -- it is the armour (`_frontal_shrug`) and the speed.
		if distance <= reach:
			_attack_cooldown = float(stats["cooldown"])
			_say("melee_hit")
			player.take_damage(_hit_for(), global_position)
		return
	if archetype == "ranged":
		if distance <= reach and _has_line_of_sight(player):
			_attack_cooldown = float(stats["cooldown"])
			# COMMITTED, THEN FIRED. Line of sight is checked HERE, when
			# the shot is committed, and deliberately not again at
			# release: a player who breaks the line during the windup has
			# dodged the shot, and the projectile leaving the muzzle into
			# the cover they reached is the whole of EX50-021 §11. Asking
			# again at release would delete the shot instead, which reads
			# as the enemy changing its mind.
			_begin_telegraph("aim", float(TELEGRAPH_SECONDS["ranged"]))
			_say("windup")
	elif archetype == "brute":
		if distance <= reach:
			# The boss telegraphs: half a second of swelling, then the slam.
			# The growl matters more than the swell — you can hear it while
			# looking somewhere else.
			_attack_cooldown = float(stats["cooldown"])
			_begin_telegraph("slam", float(TELEGRAPH_SECONDS["brute"]))
			_say("windup")
	elif distance <= reach:
		_attack_cooldown = float(stats["cooldown"])
		_say("melee_hit")
		player.take_damage(_hit_for(), global_position)

# ------------------------------------------- OV04 P07 jobs and return

## DO THE JOB, or walk back to it.
##
## Everything here is what an enemy does when it is not fighting, which
## before OV04 P07 was nothing whatsoever: outside the aggro radius the
## movement block had no `else`, so a placed enemy stood motionless
## until the player crossed 18 m. A room of statues that animate on a
## trigger reads as a room of triggers, and it also hides every
## navigation defect until the moment it matters.
##
## RETURNING COMES FIRST. An enemy that lost the player walks back to
## its post before resuming, so a fight that dragged it across a room
## does not leave it guarding somewhere nobody asked it to guard.
func _work(delta: float) -> void:
	if statuses.has("frozen") or statuses.has("stunned"):
		velocity.x = lerpf(velocity.x, 0.0, 0.5)
		velocity.z = lerpf(velocity.z, 0.0, 0.5)
		return
	if _held_in_place():
		# No patrol, no drift and no walk back to the post: all of it is
		# its own legs. A knock runs down as it does for anyone standing.
		velocity.x = lerpf(velocity.x, 0.0, 0.3)
		velocity.z = lerpf(velocity.z, 0.0, 0.3)
		return
	var speed := float(stats["speed"]) * Constants.ENEMY_JOB_SPEED
	if returning:
		var home := Vector3(post.x - global_position.x, 0.0,
				post.z - global_position.z)
		if home.length() <= Constants.ENEMY_POST_TOLERANCE:
			returning = false
			_beat_set = false
			_pause = 0.0
		else:
			_walk(home.normalized(), maxf(speed, 1.0))
			return
	match job:
		"patrol":
			_patrol(delta, speed)
		"drift":
			_drift(delta, speed)
		_:
			# `watch` and `tend` both hold the post; what differs is
			# only how fast they turn, and that is presentation.
			velocity.x = lerpf(velocity.x, 0.0, 0.25)
			velocity.z = lerpf(velocity.z, 0.0, 0.25)
			rotation.y += Constants.ENEMY_SWEEP_RATE * delta \
					* (0.5 if job == "tend" else 1.0)


## ROOTED OR ANCHORED (Design 5 §15.2, O05-09.1): it cannot move under
## its own power. Every own-power motion reads this -- the approach, the
## job walk, a charger's rush, a diver's dive and a flyer's station --
## while turning, attacking and a beacon's pulse do not, because none of
## them moves it. The two differ only in impulse: a rooted enemy is still
## knocked about, an anchored one is not (`_physics_process`).
func _held_in_place() -> bool:
	return statuses.has("rooted") or statuses.has("anchored")


## Walk a beat around the post, pausing at each end.
##
## The ends are picked around the post rather than along a fixed axis,
## so two patrollers placed side by side do not march in lockstep.
func _patrol(delta: float, speed: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		velocity.x = lerpf(velocity.x, 0.0, 0.3)
		velocity.z = lerpf(velocity.z, 0.0, 0.3)
		return
	if not _beat_set:
		var angle := randf() * TAU
		_beat = post + Vector3(cos(angle), 0.0, sin(angle)) \
				* Constants.ENEMY_PATROL_RADIUS
		_beat_set = true
	var toward := Vector3(_beat.x - global_position.x, 0.0,
			_beat.z - global_position.z)
	if toward.length() < 0.6:
		_beat_set = false
		_pause = Constants.ENEMY_PATROL_PAUSE
		return
	_walk(toward.normalized(), speed)


## A flyer circling its station. Slow, and it never descends: "owns the
## ceiling" is a claim about height and a drifter that wandered down to
## the floor between fights would stop meaning it.
func _drift(delta: float, speed: float) -> void:
	if not _beat_set:
		_beat = post
		_beat_set = true
	var around := Time.get_ticks_msec() / 1000.0 * 0.4
	var want := _beat + Vector3(cos(around), 0.0, sin(around)) * 2.5
	var toward := Vector3(want.x - global_position.x, 0.0,
			want.z - global_position.z)
	if toward.length() > 0.2:
		_walk(toward.normalized(), speed)
	var _unused := delta


## One step of ordinary locomotion, facing where it is going.
##
## Shared by the job walks so "how an enemy moves when not fighting" has
## one answer, and so the sidestep recovery above keeps working: it
## measures actual displacement, which a job walk produces exactly as a
## chase does.
func _walk(dir: Vector3, speed: float) -> void:
	velocity.x = lerpf(velocity.x, dir.x * speed, 0.15)
	velocity.z = lerpf(velocity.z, dir.z * speed, 0.15)
	if dir.length() > 0.05:
		look_at(global_position + dir, Vector3.UP)


# ------------------------------------------------ OV04 P06 role work

## Spend a committed motion, and say whether it took the frame.
##
## Returns `true` while the enemy is mid-rush, mid-dive or recovering
## from one -- during which nothing else about it steers, attacks or
## reconsiders. That is what "committed" means and it is why each of
## these roles has an opening: the player's answer is to be somewhere
## else when it lands, and a commitment that could be re-aimed would
## take that answer away.
func _spend_commitment(delta: float, player: Player) -> bool:
	if _recover > 0.0:
		_recover -= delta
		velocity.x = lerpf(velocity.x, 0.0, 0.25)
		velocity.z = lerpf(velocity.z, 0.0, 0.25)
		return true
	if _rush > 0.0:
		_rush -= delta
		if _held_in_place():
			# THE RUSH IS THE CHARGER'S OWN LEGS. Held, the attack still
			# happens -- "attacks continue" -- but where it stands, so it
			# reaches only a player already in contact with it.
			velocity.x = lerpf(velocity.x, 0.0, 0.3)
			velocity.z = lerpf(velocity.z, 0.0, 0.3)
		else:
			velocity.x = _rush_dir.x * Constants.CHARGER_RUSH_SPEED
			velocity.z = _rush_dir.z * Constants.CHARGER_RUSH_SPEED
		if player != null and global_position.distance_to(
				player.global_position) <= float(stats["reach"]) * 0.2:
			player.take_damage(float(stats["damage"]), global_position)
			_say("melee_hit")
			_rush = 0.0
		# A WALL ENDS IT, and ends it worse: running into geometry is the
		# free opening, so the recovery is the same either way and the
		# player who side-stepped gets it for nothing.
		if is_on_wall():
			_rush = 0.0
		if _rush <= 0.0:
			_recover = Constants.CHARGER_RECOVERY_SECONDS
			_say("windup")
		return true
	if _dive > 0.0:
		_dive -= delta
		if _held_in_place():
			# The same for a diver: the dive happens where it hangs.
			velocity = velocity.lerp(Vector3.ZERO, 0.3)
		else:
			velocity = _rush_dir * float(stats["speed"])
		if player != null and _dive_lands_on(player):
			player.take_damage(float(stats["damage"]), body_centre())
			_say("melee_hit")
			_dive = 0.0
		if _dive <= 0.0:
			# Back to station rather than landing: a flyer that ends up
			# on the floor is a walker with the wrong collider.
			_hover_set = false
			_recover = 0.6
		return true
	return false


## Keep a flyer's pivot on the floor beneath it, so its body hangs at
## the envelope's hover height.
##
## PT-12: the envelope's `hover_height` is the collider's CENTRE above
## the FLOOR, and the collider already hangs that far above this pivot.
## Lifting the pivot a further `FLYER_HOVER_Y` (4.2 m) put the diver's
## body 6.1 m up and the drifter's 6.7 m, where no contract and no drawn
## body said they were. So the station is the floor itself.
##
## Resolved ONCE per station rather than every frame: recomputing from
## the floor each tick makes a flyer climb its own correction over a
## slope, which is how one ends up in the ceiling. `_hover_set` is
## cleared when a dive ends, which is the only time the station moves.
func _hold_station(delta: float) -> void:
	if not _hover_set:
		_hover_y = _floor_beneath()
		_hover_set = true
	# A soft hold rather than a teleport, so a flyer knocked off station
	# visibly returns to it instead of snapping.
	velocity.y = clampf((_hover_y - global_position.y) * 2.5, -6.0, 6.0)
	var _unused := delta


## THE WORLD UNDER THIS FLYER, ignoring anything that can walk.
##
## A plain downward ray took the first thing it hit, and the first thing
## it hit was whatever happened to be standing underneath -- so a drifter
## hovering over a charger read the CHARGER's shoulders as the ground and
## held station 4.2 m above them, which on a crowded floor means a flyer
## that rises every time something walks beneath it.
##
## So the ray is re-cast past actors. Bounded to a few tries rather than
## looped: a flyer over a stack of six enemies is a composition problem,
## and spinning here would hide it.
func _floor_beneath() -> float:
	# From the BODY, which is in the air, rather than from the pivot,
	# which sits on the floor and would start the ray at its surface.
	var from := body_centre()
	var skip: Array[RID] = [get_rid()]
	for _try in 5:
		var query := PhysicsRayQueryParameters3D.create(from,
				from + Vector3.DOWN * 60.0)
		query.exclude = skip
		var hit: Dictionary = get_world_3d().direct_space_state \
				.intersect_ray(query)
		if hit.is_empty():
			# Nothing under it: hold where it is rather than guess.
			return global_position.y
		var body := hit["collider"] as Node3D
		if body is StaticBody3D or body is AnimatableBody3D:
			return (hit["position"] as Vector3).y
		if body is CollisionObject3D:
			skip.append((body as CollisionObject3D).get_rid())
	return global_position.y


## The middle of the player's collider: what a dive is aimed at and
## lands on.
static func _centre_of(player: Player) -> Vector3:
	return player.global_position + Vector3.UP * (Constants.PLAYER_HEIGHT
			/ 2.0)


## How far a dive can strike: the distance it carries, plus the contact
## it lands within. A diver commits from here and no further.
func _dive_reach() -> float:
	return float(stats["speed"]) * Constants.DIVER_DIVE_SECONDS + DIVE_CONTACT


## How close this role closes before it stops to fight. Most hold at four
## fifths of their reach; a diver's weapon is its own body, so it holds
## where a dive can land -- WAITING, visibly, within striking distance
## rather than at the edge of what it can see (PT-13).
func _standoff() -> float:
	if archetype == "diver":
		return _dive_reach() * 0.7
	return float(stats["reach"]) * 0.8


## A dive lands on a body it has reached and can see: close enough, and
## nothing solid between. Distance alone let a diver pressed against a
## wall strike whoever stood on the other side of it.
func _dive_lands_on(player: Player) -> bool:
	var at := _centre_of(player)
	if body_centre().distance_to(at) > DIVE_CONTACT:
		return false
	var query := PhysicsRayQueryParameters3D.create(body_centre(), at)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == player


## PT-13: WHAT A FLYER IS DOING, VISIBLE, in its eye. Idle, the eye is
## low; having noticed the player, it burns steady -- a diver waiting for
## the player to leave the ground is WATCHING, and now looks it.
## Committing, it flares (`_begin_telegraph`, for every role), with the
## swell and then the dive itself.
##
## The body does not pitch toward its target, on purpose: `visual`
## turning away from the collider is exactly the mismatch PT-12 was, and
## a nose tilted onto the player pushed the drawn body outside the box a
## shot can hit. The body faces the player (`_face`); the eye says what
## it means to do.
func _present_flyer(_player: Player, _delta: float) -> void:
	if telegraph_kind.is_empty():
		_set_eye(EYE_WATCHING if _has_noticed else EYE_IDLE)


## Set every eye's glow to `level` times its authored energy. Written
## only when it changes: a material write every frame for every enemy is
## cost for nothing.
func _set_eye(level: float) -> void:
	if visual == null or is_equal_approx(level, _eye_level):
		return
	_eye_level = level
	for eye: Node in visual.find_children("Eye*", "MeshInstance3D", true,
			false):
		var material := (eye as MeshInstance3D).material_override \
				as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = EYE_ENERGY * level


## Is the player off the ground far enough to be worth diving at?
##
## Asked of the FLOOR UNDER THEM, not of their absolute height: a player
## standing on a gantry is not airborne, and a diver that thought so
## would spend its life committing at people standing still.
##
## PT-13: the ray is `DIVER_TRIGGER_HEIGHT` long, which is what the
## constant says it is. It used to add 0.2 m to a 1.6 m trigger -- 1.8 m
## of clearance, above the 1.33 m apex of an ordinary jump -- so a
## player who jumped never counted as having left the ground.
func _player_is_airborne(player: Player) -> bool:
	if player.is_on_floor():
		return false
	var from := player.global_position
	var query := PhysicsRayQueryParameters3D.create(from,
			from + Vector3.DOWN * Constants.DIVER_TRIGGER_HEIGHT)
	query.exclude = [player.get_rid(), get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A beacon's actual job: make its neighbours worse.
##
## `empowered` through the ordinary Status boundary, on the ordinary
## `enemy` target, so it cleanses, expires and reads exactly like every
## other application. A private "buffed" flag would have been a second
## status system for one role.
##
## REFRESHED ON A BEAT rather than every frame: the Status refreshes
## rather than stacks, so a per-frame broadcast would be the same effect
## at sixty times the cost.
func _beacon_pulse(delta: float) -> void:
	_beacon_beat -= delta
	if _beacon_beat > 0.0:
		return
	_beacon_beat = Constants.BEACON_REFRESH
	for raw: Node in get_tree().get_nodes_in_group(Damageable.GROUP):
		var other := raw as Enemy
		if other == null or other == self or other._dead:
			continue
		if global_position.distance_to(other.global_position) \
				> Constants.BEACON_RADIUS:
			continue
		other.statuses.apply("empowered", Constants.BEACON_REFRESH * 2.0,
				Constants.BEACON_MAGNITUDE)


## What a shell's path and blast ignore: the actors on the field. Walls,
## floors, roofs and physical objects stop both.
func _blast_exclusions() -> Array[RID]:
	var out: Array[RID] = []
	for raw: Node in get_tree().get_nodes_in_group("enemies"):
		var body := raw as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


## An artillery shell, landing where the player was when it was ranged.
##
## Built as a real projectile with a real flight, because "denies
## ground" is a promise about time: the player has to see where it is
## going and leave. A hitscan at the old position would deny nothing --
## it would just be a delayed hit.
func _lob_shell(at: Vector3) -> void:
	var shell := ArtilleryShell.new()
	shell.name = "ArtilleryShell"
	shell.origin = muzzle()
	shell.target = at
	shell.seconds = Constants.ARTILLERY_FLIGHT_SECONDS
	shell.damage = float(stats["damage"])
	shell.blast = Constants.ARTILLERY_BLAST_RADIUS
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(shell)
	shell.global_position = shell.origin
	_say("shot")


## How much of this hit the armour takes, 0..1.
##
## The bulwark's brief is "cannot be fought frontally", so this is a
## direction question and not a damage-type one: a hit arriving inside
## its shielded arc is mostly shrugged off and one from behind is not.
## Any other role shrugs off nothing, and says so by returning 0.
func _frontal_shrug(from: Vector3) -> float:
	if archetype != "bulwark":
		return 0.0
	var facing := -global_transform.basis.z
	var incoming := from - global_position
	incoming.y = 0.0
	if incoming.length() < 0.001:
		return 0.0
	if facing.normalized().dot(incoming.normalized()) \
			< Constants.BULWARK_SHIELD_DOT:
		return 0.0
	return Constants.BULWARK_FRONTAL_ARMOUR


## A shell in flight. An inner class for the same reason
## `EnemyProjectile` is one: there is no second way to make one, and a
## file of its own would invite a second way.
class ArtilleryShell extends Node3D:
	var origin := Vector3.ZERO
	var target := Vector3.ZERO
	var seconds := 1.6
	var damage := 16.0
	var blast := 3.2
	var _flown := 0.0
	var _marker: MeshInstance3D = null

	func _ready() -> void:
		var mesh := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.22
		ball.height = 0.44
		mesh.mesh = ball
		add_child(mesh)
		# THE GROUND MARK IS THE POINT. A shell you cannot see the
		# landing of denies nothing, so the circle goes down when the
		# shell goes up.
		_marker = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = blast
		disc.bottom_radius = blast
		disc.height = 0.05
		_marker.mesh = disc
		_marker.material_override = ThemeMaterials.glow_material(
				Color(1.0, 0.55, 0.2), 1.8)
		get_parent().add_child.call_deferred(_marker)

	## Where the lob is at `t` in 0..1. One formula for the flight and
	## for the check made before it is fired.
	static func point(from: Vector3, to: Vector3, t: float) -> Vector3:
		return from.lerp(to, t) + Vector3(0.0,
				sin(t * PI) * (from.distance_to(to) * 0.22), 0.0)

	## PT-11: may a shell fired now reach `to`? The arc is sampled in
	## segments against the world; reaching within `ARRIVAL` of the target
	## (its own floor) or the player there counts as arriving.
	static func arc_is_clear(space: PhysicsDirectSpaceState3D,
			from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
		var last := from
		for i in range(1, SAMPLES + 1):
			var next := point(from, to, float(i) / float(SAMPLES))
			var query := PhysicsRayQueryParameters3D.create(last, next)
			query.exclude = exclude
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				return hit["collider"] is Player \
						or (hit["position"] as Vector3).distance_to(to) \
								<= ARRIVAL
			last = next
		return true

	const SAMPLES := 16
	const ARRIVAL := 0.6

	var _last := Vector3.ZERO
	var _started := false
	var _exclude: Array[RID] = []

	func _physics_process(delta: float) -> void:
		if not _started:
			_started = true
			_last = origin
			for raw: Node in get_tree().get_nodes_in_group("enemies"):
				var body := raw as CollisionObject3D
				if body != null:
					_exclude.append(body.get_rid())
		_flown += delta
		var t := clampf(_flown / maxf(seconds, 0.01), 0.0, 1.0)
		if is_instance_valid(_marker):
			_marker.global_position = target + Vector3(0.0, 0.03, 0.0)
		# A LOB, not a line: the arc is what reads as indirect fire.
		var next := point(origin, target, t)
		# PT-11: IT STOPS AT WHAT IT MEETS. The flight used to be set
		# point by point with nothing asked, so a shell passed through
		# walls and roofs, including one raised across it mid-flight.
		var query := PhysicsRayQueryParameters3D.create(_last, next)
		query.exclude = _exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_detonate(hit["position"])
			return
		_last = next
		global_position = next
		if t < 1.0:
			return
		_detonate(target)

	## The blast, with cover. PT-11: a blast was every player within
	## `blast` metres, walls or no walls. It now reaches a player only
	## if something of them can be seen from the burst -- the chest or
	## the knees -- so a wall is cover and low cover is not.
	func _detonate(at: Vector3) -> void:
		var space := get_world_3d().direct_space_state
		var back := (_last - at)
		var burst := at + (back.normalized() * 0.15 if back.length() > 0.001
				else Vector3.ZERO) + Vector3.UP * 0.1
		for raw: Node in get_tree().get_nodes_in_group("player"):
			var body := raw as Player
			if body == null or body.global_position.distance_to(at) > blast:
				continue
			for aim: Vector3 in [body.global_position + Vector3.UP * 1.0,
					body.global_position + Vector3.UP * 0.3]:
				var query := PhysicsRayQueryParameters3D.create(burst, aim)
				query.exclude = _exclude
				var seen := space.intersect_ray(query)
				if seen.is_empty() or seen["collider"] == body:
					body.take_damage(damage, at)
					break
		if is_instance_valid(_marker):
			_marker.queue_free()
		queue_free()


## WHAT A FINISHED TELEGRAPH DOES, by kind.
##
## The seam H2 asks for: an attack hangs a telegraph of its own and says
## here what it becomes. Adding a third is a row in `TELEGRAPH_SECONDS`
## and a branch here, with no change to the countdown, the swell, the
## plant, or the `telegraph_started`/`telegraph_finished` contract an
## authored telegraph binds to.
func _resolve_telegraph(kind: String, player: Player) -> void:
	match kind:
		"slam":
			_slam(player)
		"aim":
			_fire_projectile(player)
		"charge":
			# The commit begins now and steering is over: `_rush` is
			# spent in `_physics_process` and nothing re-aims it.
			_rush = Constants.CHARGER_RUSH_SECONDS
		"shell":
			_lob_shell(_rush_dir)
		"dive":
			_dive = Constants.DIVER_DIVE_SECONDS
			# From its body at theirs: the pivot is on the floor.
			var down := _centre_of(player) - body_centre()
			_rush_dir = down.normalized()
		_:
			push_error("enemy telegraph '%s' has no resolution" % kind)

## The brute's payoff: damage plus a shove if the player lingered.
## WHAT THIS ENEMY'S BLOW IS WORTH RIGHT NOW.
##
## OV04 P06: `empowered` on an ENEMY is the beacon's whole job -- "makes
## everything near it worse" -- and it had no implementation, because
## `stat_stack.gd` reads `empowered` for the PLAYER's `damage_dealt` and
## nothing read it here. So a beacon applying it would have been an
## inert Status, which is the defect the per-target boundary exists to
## refuse: the declaration `empowered: ("self", "enemy")` travels with
## THIS function and not before it.
func _hit_for() -> float:
	return float(stats["damage"]) * (1.0
			+ clampf(statuses.magnitude_of("empowered"), 0.0, 2.0))

func _slam(player: Player) -> void:
	if archetype == "bulwark":
		_recovery = Constants.BULWARK_RECOVERY_SECONDS
	var to_player := player.global_position - global_position
	if to_player.length() <= float(stats["reach"]) * 1.4:
		player.take_damage(_hit_for(), global_position)
		var away := Vector3(to_player.x, 0, to_player.z).normalized()
		player.receive_knockback(away * 7.0 + Vector3.UP * 3.0)

func _has_line_of_sight(player: Player) -> bool:
	# From where its shots start: the same point for a walker as before,
	# and a flyer's body rather than a point on the floor beneath it.
	var from := muzzle()
	var to := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == player

func _fire_projectile(player: Player) -> void:
	fire_at(player.global_position + Vector3.UP)

## Where the muzzle is. Split out because EX50-021 turns a committed shot
## into a machine input, and "where the shot starts" stopped being an
## implementation detail the moment a room had to be built round it.
func muzzle() -> Vector3:
	# PT-12: a flyer's shots start from its BODY, which hangs at its
	# hover height above this pivot. `pivot + 1.2` was chest height for a
	# walker and, for a flyer, a point in the air nowhere near what the
	# player could see firing.
	if bool(envelope.get("flying", false)):
		return body_centre()
	return global_position + Vector3.UP * 1.2

## Where this enemy's body IS: its collider's centre. The pivot is on the
## floor for every role, and a flyer's body hangs its hover height above
## it -- so anything asking "where is the enemy" in order to reach it
## asks this, not `global_position`.
func body_centre() -> Vector3:
	return global_position + Vector3.UP * float(envelope.get("centre_y", 0.0))

## The point of this enemy's collider nearest `point`. What an area
## effect measures to: a blast that meets a flyer's body 2.5 m above its
## pivot is a direct hit, not a blast 2.5 m away.
func nearest_body_point(point: Vector3) -> Vector3:
	var half: Vector3 = (envelope.get("size", Vector3.ZERO) as Vector3) / 2.0
	var centre := Vector3(0, float(envelope.get("centre_y", 0.0)), 0)
	var local := global_transform.affine_inverse() * point
	return global_transform * local.clamp(centre - half, centre + half)

## A point just above the top of the collider, for things drawn OVER the
## enemy -- its damage bar. Every role's top, including a flyer's, which
## `pivot + 2.1` put inside a diver and under a drifter.
func overhead() -> Vector3:
	return global_position + Vector3.UP * (float(envelope.get("top_y",
			1.8)) + 0.3)

## Commit a shot at a point and hand back the projectile.
##
## THE AIM IS TAKEN ONCE, here, and never again: `direction` is fixed at
## the muzzle and nothing steers it afterwards. `_fire_projectile` is the
## AI's caller and passes the player's chest; a suite is the other, and
## passes a point, so the projectile path can be measured without a body
## standing in it.
func fire_at(aim: Vector3) -> Node3D:
	_say("shot")
	var projectile := EnemyProjectile.new()
	projectile.damage = float(stats["damage"])
	projectile.speed = Constants.RANGED_PROJECTILE_SPEED
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle()
	projectile.direction = (aim - projectile.global_position).normalized()
	return projectile

## Returns true when THIS hit was the one that killed it, so the shooter
## can confirm a kill without inspecting hp and racing the death tween.
func take_damage(amount: float, direction: Vector3, knockback: float) -> bool:
	if _dead:
		return false
	# Marked and vulnerable targets take more — the mark is a promise, not
	# just a glow.
	amount *= 1.0 + 0.25 * clampf(statuses.magnitude_of("marked"), 0.0, 2.0)
	amount *= 1.0 + 0.5 * clampf(statuses.magnitude_of("vulnerable"), 0.0, 2.0)
	# OV04 P06: THE BULWARK'S SHIELD, and it is a direction question.
	#
	# `direction` is the vector the hit ARRIVED along, which every caller
	# already passes -- so "was this frontal" is answerable without a new
	# argument or a damage type. A hit inside the shielded arc is mostly
	# shrugged off; one from behind lands in full. Every other role
	# shrugs off nothing.
	amount *= 1.0 - _frontal_shrug(global_position - direction)
	hp -= amount
	if knockback > 0.0:
		_knockback += direction * knockback
	# Crude hit feedback: a scale punch. 1998 did not have hit shaders.
	# Skipped mid-windup so it cannot cancel the brute's telegraph.
	# On `visual`, so being hit no longer shrinks the hitbox to 88%.
	if _windup <= 0.0 and visual != null:
		var tween := create_tween()
		visual.scale = Vector3.ONE * 0.88
		tween.tween_property(visual, "scale", Vector3.ONE, 0.1)
	_refresh_damage_tint()
	if hp <= 0.0:
		die()
		return true
	return false

## Wounded enemies visibly cook: the eye brightens and the body reddens as
## health drops, so "nearly dead" is readable without a health bar.
##
## The per-instance materials are unshared ONCE, on first damage, and then
## mutated in place. Duplicating them on every hit re-uploaded a dozen
## materials per Static Pulse tick and permanently broke batching with the
## cached theme materials.
func _ensure_tint_parts() -> void:
	if not _tint_parts.is_empty():
		return
	# RECURSIVE, because the meshes moved under `Visual`. A non-recursive
	# walk kept compiling and silently found nothing, which is a damage
	# tint that never appears -- there is a test for exactly that.
	_collect_tint_parts(self)

func _collect_tint_parts(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var shared: Material = child.material_override
			if shared is StandardMaterial3D:
				var mine: StandardMaterial3D = shared.duplicate()
				child.material_override = mine
				_tint_parts.append(mine)
				# Capture the base energy BEFORE overwriting it, or the
				# first chip of damage makes the eye dimmer than undamaged.
				_tint_base_energy.append(mine.emission_energy_multiplier)
				_tint_base_albedo.append(mine.albedo_color)
		_collect_tint_parts(child)

func _refresh_damage_tint() -> void:
	var hurt := 1.0 - clampf(hp / maxf(1.0, float(stats["hp"])), 0.0, 1.0)
	var marked := statuses.has("marked")
	if hurt <= 0.0 and not marked:
		return
	_ensure_tint_parts()
	for i in _tint_parts.size():
		var material: StandardMaterial3D = _tint_parts[i]
		if material.emission_enabled:
			# A marked target glows over and above its wounds — scan_mark
			# is only worth a slot if the mark is visible across a room.
			material.emission_energy_multiplier = \
					_tint_base_energy[i] * (1.0 + 1.6 * hurt) \
					* (2.2 if marked else 1.0)
		else:
			var albedo := _tint_base_albedo[i].lerp(
					Color(1.0, 0.4, 0.3), hurt * 0.7)
			if marked:
				albedo = albedo.lerp(Color(1.0, 0.85, 0.3), 0.45)
			material.albedo_color = albedo

func apply_knockback(impulse: Vector3) -> void:
	_knockback += impulse

## Burning and poison chip without the scale-punch flinch: a tween per
## physics frame is a strobe, and a DoT is ambient harm rather than a hit.
func _take_dot(amount: float) -> void:
	hp -= amount
	_refresh_damage_tint()
	if hp <= 0.0:
		die()

# ---------------------------------------------------------------------
# Telegraph seam (art requirement 14)
# ---------------------------------------------------------------------
# Engineering owns the event, the state and the attachment point. Art owns
# what a telegraph LOOKS like. The two meet at `telegraph_started`,
# `telegraph_origin` and `telegraph_progress()`, and nowhere else.

## How far through the current windup, 0.0 to 1.0. Returns 0.0 when
## nothing is being telegraphed.
##
## The reason this exists rather than a presentation timing itself: a
## second clock drifts, and a drifting telegraph is a promise broken by a
## rounding error. There is exactly one countdown and it is the one the
## attack uses.
func telegraph_progress() -> float:
	if telegraph_kind.is_empty() or telegraph_duration <= 0.0:
		return 0.0
	return clampf(1.0 - _windup / telegraph_duration, 0.0, 1.0)

## Whether an attack is being announced right now.
func is_telegraphing() -> bool:
	return not telegraph_kind.is_empty()

func _begin_telegraph(kind: String, duration: float) -> void:
	# A windup that started must always resolve (see `_physics_process`),
	# so a second one cannot open on top of the first.
	if not telegraph_kind.is_empty():
		return
	telegraph_kind = kind
	telegraph_duration = duration
	_windup = duration
	_set_eye(EYE_FLARE)
	telegraph_started.emit(kind, duration)

func _end_telegraph(completed: bool) -> void:
	if telegraph_kind.is_empty():
		return
	var kind := telegraph_kind
	telegraph_kind = ""
	telegraph_duration = 0.0
	_windup = 0.0
	_set_visual_scale(1.0)
	_set_eye(EYE_WATCHING)
	telegraph_finished.emit(kind, completed)

## Presentation scale, applied to `visual` and never to the body. The
## collider is a direct child of the body, so scaling the body scaled the
## hitbox -- the thing this whole seam exists to make impossible.
func _set_visual_scale(factor: float) -> void:
	if visual != null:
		visual.scale = Vector3.ONE * factor

func _exit_tree() -> void:
	# Despawned mid-windup. The listener is told rather than left holding
	# a telegraph for an enemy that no longer exists.
	_end_telegraph(false)

func die() -> void:
	if _dead:
		return
	_dead = true
	# A promise this enemy will not keep. Told, not left to time out: a
	# telegraph running its own clock would finish announcing a slam that
	# is never coming.
	_end_telegraph(false)
	enemy_died.emit(self)
	# Crude death: tip over and sink. 1998 did not have ragdolls either.
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", PI / 2.0, 0.25)
	tween.tween_property(self, "position:y", position.y - 1.5, 0.6)
	tween.tween_callback(queue_free)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)


## A committed shot.
##
## **Its trajectory is fixed at launch** -- `direction` is set once by
## `_fire_projectile` from where the player was standing, and nothing
## afterwards steers it. That is not an incidental property: it is what
## makes an enemy's ordinary attack usable as a machine input, because
## the player can change where the shot is going by standing somewhere
## else and then leave before it arrives. Nothing here may become
## homing, and nothing here may become hitscan.
class EnemyProjectile extends Area3D:
	var damage := 8.0
	var speed := 14.0
	var direction := Vector3.FORWARD
	var _life := 6.0
	## ONE IMPACT. `body_entered` can fire for several bodies in the same
	## frame, and a shot that both hurt the player and tripped the
	## machine behind them would be counting one impact twice.
	var _spent := false

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.2
		shape.shape = sphere
		add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.36
		visual.mesh = mesh
		visual.material_override = ThemeMaterials.glow_material(
				Color(0.9, 0.2, 0.9), 2.0)
		add_child(visual)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		global_position += direction * speed * delta
		_life -= delta
		if _life <= 0.0:
			queue_free()

	func _on_body_entered(body: Node3D) -> void:
		if body is Enemy or _spent:
			return
		_spent = true
		if body.is_in_group("player"):
			# The projectile's own position: the shot came from where it
			# is, which is what the player needs to turn toward.
			body.take_damage(damage, global_position)
			queue_free()
			return
		# A MACHINE THAT HAS DECLARED IT ACCEPTS HOSTILE FIRE gets the
		# same pulse a player's shot would deliver -- same call, same
		# arguments, same resulting machine state (EX50-021 §9). Anything
		# that has not declared it simply stops the shot, which is what
		# cover is: a projectile intercepted on the way cannot also
		# trigger what stood behind it (§4).
		Damageable.hit(Damageable.hostile_input(body), damage, direction)
		queue_free()
