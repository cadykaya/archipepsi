extends Node
## THE SEVEN ADDITIONAL ENEMY ROLES (`make godot-roster`).
##
## OV04 P06. The approved production family is TEN roles; three had
## behaviour and seven were names in a generated constant with envelopes
## and no runtime (H1, and the art lane's own note: "seven of the ten
## roles have no collider, and the telegraph has no node").
##
## **THE SPEC IS RECOVERED, NOT INVENTED.** Each role's identity is its
## one-line brief from the approved roster (`docs/art/ART_REVIEW.md`),
## and each case below asks whether the runtime does THAT:
##
##   charger    one telegraphed rush
##   bulwark    cannot be fought frontally
##   drifter    (flyer) owns the ceiling
##   diver      (flyer) contests the grapple arc
##   scuttler   costs attention
##   artillery  indirect, denies ground
##   beacon     makes everything near it worse
##
## **Tuning is provisional and is not what this measures.** Whether a
## charger's rush is too fast is a playtest question. Whether it commits,
## cannot steer, and leaves an opening is a behaviour question, and that
## is what is asked here.
##
## **SYNTHETIC, and it says so.** Each case builds one or two enemies on
## a floor with a player-shaped target and drives the real
## `_physics_process`. No encounter, no Zone, no walked route: what is
## under test is the role, and whether encounters USE these roles is
## P08's question and a different suite's.

const STEP := 1.0 / 60.0

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
	_run()


func _run() -> void:
	await get_tree().process_frame
	await _every_declared_role_is_placeable()
	await _the_charger_commits_and_cannot_steer()
	await _the_bulwark_cannot_be_fought_frontally()
	await _the_drifter_owns_the_ceiling()
	await _the_diver_waits_for_the_air()
	await _the_scuttler_costs_attention()
	await _the_artillery_denies_ground()
	await _the_beacon_makes_its_neighbours_worse()
	await _an_unwatched_enemy_does_its_job()
	await _interest_outlives_the_radius()
	await _a_fight_ends_with_a_walk_back_to_work()
	print("")
	if _failures == 0:
		print("GODOT ROSTER OK (%d checks, %d notes)" % [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT ROSTER: %d failures in %d checks" % [_failures, _checks])
	get_tree().quit(1)


func _settle(frames := 10) -> void:
	for _i in frames:
		await get_tree().physics_frame


## A floor to stand on, because "it fell" is not a behaviour finding.
func _stage() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# WIDE ENOUGH FOR THE WHOLE ROSTER IN A ROW. At 80 m this floor
	# spanned x ∈ [-40, +40] and the ten-role row below ran to x = 108,
	# so half the roster spawned in mid-air, fell past
	# `ENEMY_FALL_KILL_Y` and freed itself -- while the case went on
	# "measuring" bodies that no longer existed.
	box.size = Vector3(160.0, 1.0, 80.0)
	shape.shape = box
	ground.add_child(shape)
	root.add_child(ground)
	ground.position = Vector3(0.0, -0.5, 0.0)
	return root


func _enemy(root: Node3D, role: String, at: Vector3) -> Enemy:
	var made := Enemy.create(role, "concrete_facility")
	root.add_child(made)
	made.global_position = at
	return made


func _target(root: Node3D, at: Vector3) -> Player:
	var body := Player.create()
	root.add_child(body)
	body.global_position = at
	body.velocity = Vector3.ZERO
	return body


# ------------------------------------------------------- the roster

## THE DECLARATION. A role with stats is placeable; one with only an
## envelope is art. `Enemy.create` asserts exactly that, so this is the
## check that the assert is now satisfiable for all ten.
func _every_declared_role_is_placeable() -> void:
	print("  -- ALL TEN DECLARED ROLES ARE PLACEABLE")
	_check(Constants.ENEMY_ARCHETYPES.size() == 10,
			"ten archetypes are declared (%d)"
			% Constants.ENEMY_ARCHETYPES.size())
	var missing: Array[String] = []
	for role: String in Constants.ENEMY_ROLES:
		if not role in Constants.ENEMY_ARCHETYPES:
			missing.append(role)
	_check(missing.is_empty(),
			"every role with an envelope now has behaviour: %s" % [missing])
	var root := _stage()
	var built := 0
	for role: String in Constants.ENEMY_ARCHETYPES:
		var made := _enemy(root, role, Vector3(float(built) * 4.0, 1.0, 0.0))
		if made != null and made.hp > 0.0:
			built += 1
		_check(made.stats.has("hp") and made.stats.has("reach"),
				"'%s' carries its own stats" % role)
	_check(built == 10, "all ten build and live (%d)" % built)
	await _settle(4)
	root.queue_free()
	await get_tree().process_frame


## ONE TELEGRAPHED RUSH: it warns, it commits, it cannot re-aim, and
## missing costs it the recovery window.
func _the_charger_commits_and_cannot_steer() -> void:
	print("  -- CHARGER: one telegraphed rush, and no steering in it")
	var root := _stage()
	var foe := _enemy(root, "charger", Vector3(0.0, 1.0, 0.0))
	var mark := _target(root, Vector3(0.0, 1.0, -9.0))
	var kinds: Array = []
	foe.telegraph_started.connect(
			func(kind: String, _s: float) -> void: kinds.append(kind))
	await _settle(30)
	_check(kinds.has("charge"),
			"it telegraphs `charge` before moving: %s" % [kinds])

	# THE COMMIT, MEASURED AS A DIRECTION rather than as an arrival.
	#
	# The first version of this put the target somewhere else and asked
	# where the charger ended up -- and a player is a physical body the
	# charger walks into, climbs and shoves, so the answer was "on top of
	# the player" for reasons that had nothing to do with steering. What
	# the brief actually promises is that the rush is AIMED WHEN IT
	# STARTS, so that is what is asked: the direction is fixed at the
	# telegraph, and the travel runs along it.
	var aimed := foe._rush_dir
	_check(aimed.length() > 0.9 and absf(aimed.x) < 0.05,
			"the rush was aimed when the windup opened, at %v" % aimed)
	# The target leaves, and the runtime is given every chance to re-aim.
	mark.global_position = Vector3(18.0, 1.0, 9.0)
	await _settle(24)
	_check(foe._rush_dir.is_equal_approx(aimed),
			"...and is NOT re-aimed while the windup runs (%v)"
			% foe._rush_dir)
	mark.queue_free()
	await get_tree().process_frame

	# AND IT CARRIES, measured with NOTHING IN THE WAY.
	#
	# **DIRECT HANDLER, and it says so.** The travel was first measured
	# with the player still standing there, and the charger kept ending
	# up ON TOP of it -- a rushing body walks into a player-shaped body,
	# climbs it and stops, so the number measured was the collision and
	# not the commitment. Whether a charger should be able to stand on
	# the player's head is a real question and it is recorded as one
	# (P-4); it is not what this case is for. The aim being fixed at the
	# telegraph is asserted above, against a real player.
	var solo := _enemy(root, "charger", Vector3(-20.0, 1.0, 0.0))
	await _settle(6)
	var from := solo.global_position
	solo._rush_dir = Vector3(0.0, 0.0, -1.0)
	solo._rush = Constants.CHARGER_RUSH_SECONDS
	await _settle(40)
	var travelled := solo.global_position - from
	_check(travelled.length() > 3.0,
			"a commitment carries it %.2f m" % travelled.length())
	var flat := Vector3(travelled.x, 0.0, travelled.z).normalized()
	_check(flat.dot(solo._rush_dir) > 0.95,
			"...straight along the committed direction (dot %.2f)"
			% flat.dot(solo._rush_dir))
	await _settle(50)
	_check(solo._recover > 0.0 or solo._rush <= 0.0,
			"...and the commitment ends rather than running for ever")
	# THE OPENING. After the rush it is recovering and does not
	# immediately commit again.
	var before := kinds.size()
	await _settle(40)
	_check(kinds.size() == before,
			"it does not open a second rush while recovering "
			+ "(%d telegraphs)" % kinds.size())
	_note("recovery is %.1f s; whether that is the right length is a "
			% Constants.CHARGER_RECOVERY_SECONDS + "playtest question")
	root.queue_free()
	await get_tree().process_frame


## CANNOT BE FOUGHT FRONTALLY: the same shot does far less into its
## shield than into its back.
func _the_bulwark_cannot_be_fought_frontally() -> void:
	print("  -- BULWARK: the front is the wrong answer")
	var root := _stage()
	var foe := _enemy(root, "bulwark", Vector3(0.0, 1.0, 0.0))
	await _settle(4)
	foe.rotation.y = 0.0          # facing -Z
	var full := foe.hp

	# FROM THE FRONT: the hit arrives travelling +Z, from in front of it.
	foe.take_damage(20.0, Vector3.BACK, 0.0)
	var after_front := full - foe.hp
	foe.hp = full
	# FROM BEHIND: the same magnitude, arriving the other way.
	foe.take_damage(20.0, Vector3.FORWARD, 0.0)
	var after_back := full - foe.hp

	_check(after_front < after_back * 0.5,
			"a frontal hit does %.1f and a hit from behind does %.1f"
			% [after_front, after_back])
	_check(after_back > 19.0,
			"...and from behind it takes the shot in full (%.1f)"
			% after_back)
	_check(after_front > 0.0,
			"...while the front is armoured, not invulnerable (%.1f)"
			% after_front)

	# AND NOBODY ELSE HAS A SHIELD. A shrug on every role would make
	# every fight a direction puzzle.
	var other := _enemy(root, "melee", Vector3(6.0, 1.0, 0.0))
	await _settle(2)
	var melee_full := other.hp
	other.take_damage(10.0, Vector3.BACK, 0.0)
	_check(is_equal_approx(melee_full - other.hp, 10.0),
			"a melee takes a frontal hit in full (%.1f)"
			% (melee_full - other.hp))
	root.queue_free()
	await get_tree().process_frame


## OWNS THE CEILING: it holds a height and does not come down.
func _the_drifter_owns_the_ceiling() -> void:
	print("  -- DRIFTER: it holds the ceiling")
	var root := _stage()
	var foe := _enemy(root, "drifter", Vector3(0.0, 6.0, 0.0))
	var mark := _target(root, Vector3(0.0, 1.0, -6.0))
	await _settle(90)
	_check(foe.global_position.y > 2.5,
			"it is still in the air after a second and a half (y %.2f)"
			% foe.global_position.y)
	_check(absf(foe.global_position.y - Constants.FLYER_HOVER_Y) < 1.5,
			"...holding near its station height of %.1f m (y %.2f)"
			% [Constants.FLYER_HOVER_Y, foe.global_position.y])
	_check(not foe.is_on_floor(),
			"...and never reaches the floor")
	mark.queue_free()
	root.queue_free()
	await get_tree().process_frame


## CONTESTS THE GRAPPLE ARC: it commits when the player leaves the
## ground, and not before.
func _the_diver_waits_for_the_air() -> void:
	print("  -- DIVER: it answers the air, not the floor")
	var root := _stage()
	var foe := _enemy(root, "diver", Vector3(0.0, 6.0, 0.0))
	var mark := _target(root, Vector3(0.0, 1.0, -5.0))
	var kinds: Array = []
	foe.telegraph_started.connect(
			func(kind: String, _s: float) -> void: kinds.append(kind))
	await _settle(60)
	_check(kinds.is_empty(),
			"a player standing on the floor draws no dive: %s" % [kinds])

	# OFF THE GROUND. Held above the floor, which is what a grapple arc
	# looks like to anything watching.
	for _i in 90:
		mark.global_position = Vector3(0.0, 5.0, -5.0)
		mark.velocity = Vector3.ZERO
		await get_tree().physics_frame
	_check(kinds.has("dive"),
			"...and leaving the ground draws one: %s" % [kinds])
	mark.queue_free()
	root.queue_free()
	await get_tree().process_frame


## COSTS ATTENTION: fast and cheap, not a damage threat.
func _the_scuttler_costs_attention() -> void:
	print("  -- SCUTTLER: cheap, fast, and in your way")
	var root := _stage()
	var foe := _enemy(root, "scuttler", Vector3(0.0, 1.0, -14.0))
	var mark := _target(root, Vector3(0.0, 1.0, 0.0))
	var started := foe.global_position.distance_to(mark.global_position)
	await _settle(120)
	var closed := started - foe.global_position.distance_to(
			mark.global_position)
	_check(closed > 4.0,
			"it closes ground fast: %.1f m in two seconds" % closed)
	_check(float(foe.stats["hp"]) <= 16.0,
			"it dies to about one Static Pulse burst (%.0f hp)"
			% float(foe.stats["hp"]))
	_check(float(foe.stats["damage"]) <= 4.0,
			"...and threatens attention rather than health (%.0f damage)"
			% float(foe.stats["damage"]))
	mark.queue_free()
	root.queue_free()
	await get_tree().process_frame


## INDIRECT, DENIES GROUND: a shell with a flight time and a mark, and
## no answer at all up close.
func _the_artillery_denies_ground() -> void:
	print("  -- ARTILLERY: indirect fire, and a minimum range")
	var root := _stage()
	var foe := _enemy(root, "artillery", Vector3(0.0, 1.0, 0.0))
	var mark := _target(root, Vector3(0.0, 1.0, -20.0))
	var kinds: Array = []
	foe.telegraph_started.connect(
			func(kind: String, _s: float) -> void: kinds.append(kind))
	await _settle(40)
	_check(kinds.has("shell"), "it ranges before firing: %s" % [kinds])
	_note("at 20 m, which is past ENEMY_AGGRO_RADIUS (%.0f m) and "
			% Constants.ENEMY_AGGRO_RADIUS
			+ "inside its own %.0f m reach -- a role notices as far as "
			% float(foe.stats["reach"]) + "it can shoot")
	await _settle(60)
	_check(_shells_in_flight() > 0,
			"a shell is in the air with a real flight time (%d)"
			% _shells_in_flight())

	# THE GROUND IT DENIES IS LEAVABLE: the shell lands where the player
	# WAS, so moving away is the answer and standing still is not.
	var landing := mark.global_position
	mark.global_position = Vector3(12.0, 1.0, -20.0)
	var hp_before := mark.hp
	await _settle(140)
	_check(is_equal_approx(mark.hp, hp_before),
			"a player who left the marked ground is unhurt (%.0f HP)"
			% mark.hp)
	_note("the shell was aimed at %v and the player stepped to %v"
			% [landing, mark.global_position])

	# AND IT CANNOT DEPRESS. Asked of a FRESH piece with the target
	# already inside its minimum range: reusing the one above counted a
	# telegraph it had opened legitimately at long range a moment
	# earlier, which is a stale reading rather than a close-range shot.
	# THE FIRST TARGET GOES FIRST. `_find_player` takes players[0], so a
	# second body left standing 27 m away is the one the fresh piece
	# ranges -- which it is entitled to do, and which has nothing to do
	# with minimum range.
	mark.queue_free()
	await get_tree().process_frame
	var near_foe := _enemy(root, "artillery", Vector3(30.0, 1.0, 0.0))
	var near_kinds: Array = []
	near_foe.telegraph_started.connect(
			func(kind: String, _s: float) -> void: near_kinds.append(kind))
	var hugger := _target(root, Vector3(30.0, 1.0, -3.0))
	await _settle(160)
	_check(near_kinds.is_empty(),
			"inside %.0f m it does not fire at all (%s)"
			% [Constants.ARTILLERY_MIN_RANGE, near_kinds])
	hugger.queue_free()
	root.queue_free()
	await get_tree().process_frame


func _shells_in_flight() -> int:
	var scene := get_tree().current_scene
	if scene == null:
		return 0
	var n := 0
	for child in scene.get_children():
		if child is Enemy.ArtilleryShell:
			n += 1
	return n


## MAKES EVERYTHING NEAR IT WORSE: its neighbours get the ordinary
## `empowered` Status, through the ordinary boundary, and distance
## matters.
func _the_beacon_makes_its_neighbours_worse() -> void:
	print("  -- BEACON: it is what is standing next to it")
	var root := _stage()
	var beacon := _enemy(root, "beacon", Vector3(0.0, 1.0, 0.0))
	var near := _enemy(root, "melee", Vector3(4.0, 1.0, 0.0))
	var far := _enemy(root, "melee",
			Vector3(Constants.BEACON_RADIUS + 8.0, 1.0, 0.0))
	await _settle(90)
	_check(near.statuses.has("empowered"),
			"a neighbour inside %.0f m is empowered"
			% Constants.BEACON_RADIUS)
	_check(not far.statuses.has("empowered"),
			"...and one outside it is not")
	_check(not beacon.statuses.has("empowered"),
			"...and the beacon does not empower itself")
	_note("through the ordinary Status boundary, so it cleanses and "
			+ "expires like any other -- there is no private buff flag")

	# AND IT LAPSES. Killing the beacon must not leave the buff running
	# forever, which a permanent flag would.
	beacon.die()
	await _settle(150)
	_check(not near.statuses.has("empowered"),
			"with the beacon dead the buff expires rather than sticking")
	root.queue_free()
	await get_tree().process_frame



# ------------------------------------------- OV04 P07 jobs and return

## P07.1: an enemy nobody has seen is DOING something.
##
## Before this there was no `else` on the aggro branch, so an enemy
## outside its radius stood exactly where it was placed until the player
## came within 18 m. This is the case that would have caught that, and
## it is asked of every role because the failure was structural.
func _an_unwatched_enemy_does_its_job() -> void:
	print("  -- P07: an unwatched enemy is doing something")
	var root := _stage()
	var made: Array[Enemy] = []
	var at: Array[Vector3] = []
	var i := 0
	for role: String in Constants.ENEMY_ARCHETYPES:
		var foe := _enemy(root, role, Vector3(
				(float(i) - 4.5) * 12.0, 1.0, 0.0))
		made.append(foe)
		i += 1
	await _settle(10)
	for foe in made:
		at.append(foe.global_position)
	_check(made.size() == 10, "ten roles placed, and no player anywhere")

	# Every role has a job, and it is one the runtime implements.
	var known := ["patrol", "watch", "tend", "drift"]
	var jobless: Array[String] = []
	for foe in made:
		if not known.has(foe.job):
			jobless.append("%s:%s" % [foe.archetype, foe.job])
	_check(jobless.is_empty(),
			"every role has an implemented job: %s" % [jobless])

	await _settle(150)
	# STILL THERE TO BE MEASURED. This is the precondition the case used
	# to assume: an enemy that died during the settle is not a patroller
	# that stayed put, and reading `global_position` off a freed body
	# yields a number that can land on either side of a threshold. The
	# check below passed for three commits while half the roster was
	# falling out of the world.
	var gone: Array[String] = []
	for j in made.size():
		if not is_instance_valid(made[j]) or made[j]._dead:
			gone.append(Constants.ENEMY_ARCHETYPES[j])
	_check(gone.is_empty(),
			"all ten are still standing after 2.5 s of doing their job "
			+ "(lost %s)" % [gone])

	# The movers moved; the holders held their post. Both are "doing the
	# job" and asserting only the first would make every watcher a bug.
	var moved := 0
	var held := 0
	for j in made.size():
		var travelled := at[j].distance_to(made[j].global_position)
		if made[j].job == "patrol" or made[j].job == "drift":
			if travelled > 0.4:
				moved += 1
		elif travelled < 2.0:
			held += 1
	var walkers := 0
	for foe in made:
		if foe.job == "patrol" or foe.job == "drift":
			walkers += 1
	_check(moved == walkers,
			"every patrol and drift role went to work (%d of %d)"
			% [moved, walkers])
	_check(held == made.size() - walkers,
			"every watcher and tender held its post (%d of %d)"
			% [held, made.size() - walkers])
	_note("a fixed-role gunner holding its lane is deliberate, not a "
			+ "role that failed to patrol")
	root.queue_free()
	await get_tree().process_frame


## P07.2: interest outlives the radius, so stepping one metre out does
## not switch an enemy off mid-fight.
func _interest_outlives_the_radius() -> void:
	print("  -- P07: interest outlives the aggro radius")
	var root := _stage()
	var foe := _enemy(root, "melee", Vector3(0.0, 1.0, 0.0))
	var mark := _target(root, Vector3(0.0, 1.0, -6.0))
	await _settle(30)
	_check(foe._has_noticed, "it noticed the player at 6 m")

	# THE PLAYER LEAVES FOR GOOD. Moving them merely out of range does
	# not test forgetting: the enemy pursues during its interest window
	# and legitimately catches up, so its interest refreshes and never
	# lapses -- which is the mechanic working, not a defect. (An earlier
	# version moved them to z -60, off the 40 m stage, where they fell,
	# died and respawned back beside the enemy.)
	mark.queue_free()
	await get_tree().process_frame
	await _settle(60)
	_check(foe._has_noticed,
			"a second later it has NOT forgotten them (interest %.2f s)"
			% foe._interest)
	await _settle(240)
	_check(not foe._has_noticed,
			"...and after %.0f s of nothing it does"
			% Constants.ENEMY_INTEREST_SECONDS)
	root.queue_free()
	await get_tree().process_frame


## P07.4: a fight that dragged an enemy across a room does not leave it
## guarding somewhere nobody asked it to guard.
func _a_fight_ends_with_a_walk_back_to_work() -> void:
	print("  -- P07: it goes back to work, and back to its post")
	var root := _stage()
	var foe := _enemy(root, "melee", Vector3(0.0, 1.0, 0.0))
	await _settle(6)
	var home := foe.post
	_check(home.distance_to(Vector3(0.0, 1.0, 0.0)) < 1.5,
			"its post is where it was placed (%v)" % home)

	# Drag it away, the way a chase would.
	var mark := _target(root, Vector3(0.0, 1.0, -14.0))
	await _settle(200)
	var dragged := foe.global_position.distance_to(home)
	_check(dragged > 3.0,
			"the chase pulled it %.1f m off its post" % dragged)

	# The player leaves for good.
	mark.queue_free()
	await get_tree().process_frame
	await _settle(420)
	_check(foe.global_position.distance_to(home)
			<= Constants.ENEMY_PATROL_RADIUS + 1.5,
			"it walked back to within its beat of the post (%.1f m)"
			% foe.global_position.distance_to(home))
	_check(not foe.returning,
			"...and is working again rather than still walking home")
	root.queue_free()
	await get_tree().process_frame
