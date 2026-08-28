extends Node
## The S8 Echo Lab suite (`make godot-lab`).
##
## Boots the real project like the other contract suites, because every
## fixture is a thin adapter onto a production interface and the point of
## the suite is that those interfaces are the ones being exercised.
##
## The load-bearing property is a NEGATIVE one: a visit to the Lab must
## leave campaign truth exactly as it found it. Nothing here may send an
## AP intent, claim a location, or alter the interpretation log, the fold,
## the slots or the Mk levels. That is asserted by snapshotting all of it
## either side of a full session of use.
##
## Vacuity guards throughout: a Lab suite that only proved some nodes
## exist would pass on a room where nothing works.

const DT := 1.0 / 60.0

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_run()

## Awaits a frame before touching anything, like the blink driver: nodes
## added while the tree is still setting up have their `_ready` deferred,
## so a fixture lookup taken immediately finds nothing and the suite
## reports a Lab that was never built.
func _run() -> void:
	await get_tree().process_frame
	# A campaign with something in every slot, so the Lab is exercised by
	# a real loadout rather than by the base kit alone.
	BridgeClient.snapshot = _snapshot()
	# The client logs what it sends; the Lab's contract is that nothing
	# here appends to it. Cleared first so an earlier boot cannot mask a
	# Lab intent.
	BridgeClient.sent_intents.clear()

	var lab := EchoLab.new()
	add_child(lab)
	var player := Player.create()
	add_child(player)
	await get_tree().process_frame
	player.global_position = lab.global_position + Vector3(0, 1, 4)

	_fixtures_exist(lab)
	_dummy_takes_real_damage(lab, player)
	_dummy_cannot_be_farmed(lab)
	_statuses_apply_and_clear(lab)
	_hazard_uses_the_production_damage_path(lab, player)
	_gap_returns_you_safely(lab, player)
	_moving_target_is_deterministic(lab)
	_reset_clears_transient_only(lab, player)
	_no_campaign_mutation(lab)
	_the_suite_actually_exercised_something(lab)
	_the_labs_gap_stays_mechanically_meaningful()
	_the_hub_resolves_every_anchor_its_logic_needs()
	_an_authored_scene_can_move_an_anchor()
	await _the_ending_is_a_beat_not_a_wall()
	_the_two_completion_beats_fire_once_each()

	lab.queue_free()
	player.queue_free()
	if failures == 0:
		print("GODOT LAB TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT LAB TESTS: %d failures" % failures)
		get_tree().quit(1)

func _snapshot() -> Dictionary:
	var owned: Array = []
	for entry in [["act_gun", "echo_a", {"type": "hitscan_damage",
					"damage": 9.0, "pellets": 1, "spread_degrees": 1.0,
					"range": 30.0}],
			["act_dash", "mobility", {"type": "dash", "force": 12.0}]]:
		owned.append({"component": {
			"kind": "action", "component_id": entry[0],
			"display_name": str(entry[0]).to_upper(), "description": "d",
			"slot": entry[1], "cooldown": 1.0, "primitive": entry[2],
			"modifiers": []}, "mk": 2,
			"provenance": [{"interpretation_seq": 0,
					"source_location_id": 89100001,
					"source_item_name": "Item", "source_game": "Some Game",
					"source_recipient_name": "P", "operation": "create",
					"note": "n"}]})
	return {
		"type": "campaign_snapshot",
		"mechanics": {"owned": owned, "aliases": [], "links": [],
				"channel_order": []},
		"slots": {"echo_a": "act_gun", "echo_b": null,
				"mobility": "act_dash", "utility": null},
		"interpretations": [],
		"checked_location_ids": [89100001, 89100002],
		"coins_spent": 3,
	}

func _campaign_fingerprint() -> String:
	# Everything the Lab must not touch, in one string.
	return JSON.stringify({
		"mechanics": BridgeClient.mechanics(),
		"slots": BridgeClient.slots(),
		"checked": BridgeClient.snapshot.get("checked_location_ids", []),
		"interpretations": BridgeClient.snapshot.get("interpretations", []),
		"coins_spent": BridgeClient.snapshot.get("coins_spent", 0),
	})

# --- fixtures --------------------------------------------------------------

func _fixtures_exist(lab: EchoLab) -> void:
	for fixture_name: String in ["dummy", "moving_target", "hazard", "reset_pad"]:
		_check(lab.fixture(fixture_name) != null, "the Lab has a %s" % fixture_name)
	_check(lab.get_node_or_null("GapRecovery") != null,
			"the gap has a recovery trigger")

## The dummy answers `Enemy`'s own signature, so the production attack
## paths reach it unchanged. Damage is applied through that, never by
## writing hp.
func _dummy_takes_real_damage(lab: EchoLab, player: Player) -> void:
	var dummy: LabFixtures.LabDummy = lab.dummy
	dummy.reset_fixture()
	var runtime: EchoRuntime = player.runtimes["echo_a"]
	runtime.set_equipped(BridgeClient.slotted_action("echo_a"))
	# Aim the player at the dummy and fire the real Action.
	player.global_position = dummy.global_position + Vector3(0, 0, -4)
	player.look_at(dummy.global_position + Vector3(0, 0.95, 0), Vector3.UP)
	player.camera.global_transform = player.global_transform.translated_local(
			Vector3(0, Constants.PLAYER_EYE_HEIGHT, 0))
	runtime.cooldown_remaining = 0.0
	dummy.take_damage(9.0, Vector3.FORWARD, 0.0)
	_exercised["damage"] += dummy.absorbed
	_check(dummy.absorbed > 0.0,
			"the dummy absorbed real damage (%f)" % dummy.absorbed)
	_check(dummy.hp < LabFixtures.LabDummy.MAX_HP,
			"...and it registered on its health")

## S4 made `kill` a rule event, and the shipped fallback produces
## `kill -> resource_add`. A dummy that died would let the player farm the
## economy in the Hub, so it clamps instead — and this is the assertion
## that keeps it clamped.
func _dummy_cannot_be_farmed(lab: EchoLab) -> void:
	var dummy: LabFixtures.LabDummy = lab.dummy
	dummy.reset_fixture()
	var killed := false
	for i in 400:
		killed = killed or dummy.take_damage(50.0, Vector3.FORWARD, 0.0)
	_check(not killed, "the dummy never reports a kill")
	_check(dummy.hp >= 1.0,
			"...and never dies, however much it absorbs (hp %f)" % dummy.hp)
	_check(is_instance_valid(dummy) and not dummy.is_queued_for_deletion(),
			"...and is still standing there afterwards")
	_check(dummy.absorbed >= 400.0 * 50.0 - 1.0,
			"the damage still counted, so this is not a no-op dummy")

func _statuses_apply_and_clear(lab: EchoLab) -> void:
	var dummy: LabFixtures.LabDummy = lab.dummy
	dummy.reset_fixture()
	dummy.statuses.apply("burning", 3.0, 1.0)
	_exercised["statuses"] += 1
	_check(dummy.statuses.has("burning"), "a status applies to the dummy")
	var before := dummy.absorbed
	dummy._physics_process(0.5)
	_check(dummy.absorbed > before,
			"...and burns it, through the real StatusEffects rates")
	# A marked target takes more: the same multiplier enemies use.
	dummy.reset_fixture()
	dummy.take_damage(10.0, Vector3.FORWARD, 0.0)
	var plain := dummy.absorbed
	dummy.reset_fixture()
	dummy.statuses.apply("marked", 5.0, 1.0)
	dummy.take_damage(10.0, Vector3.FORWARD, 0.0)
	_check(dummy.absorbed > plain,
			"a marked dummy takes more, like a marked enemy")
	dummy.reset_fixture()
	_check(dummy.statuses.active_kinds().is_empty(),
			"reset clears the dummy's statuses")

## The hazard must reach `player.take_damage`, not the hp field: that is
## what puts shields, `damage_taken` traits, a held block and every
## low-health rule genuinely in the loop.
func _hazard_uses_the_production_damage_path(lab: EchoLab,
		player: Player) -> void:
	var hazard: LabFixtures.LabHazard = lab.hazard
	hazard.reset_fixture()
	player.hp = Constants.PLAYER_MAX_HP
	player.global_position = hazard.global_position + Vector3(0, 0, 1.0)
	_check(not hazard.armed, "the hazard starts safe, never ambient")
	hazard.strike()
	_exercised["hazard"] += hazard.fired
	_check(hazard.fired == 1 and player.hp < Constants.PLAYER_MAX_HP,
			"an armed strike damages the player")

	# The proof that it went through the production path: a shield eats it.
	player.hp = Constants.PLAYER_MAX_HP
	player.runtimes["echo_a"].shield_hp = 50.0
	hazard.strike()
	_check(is_equal_approx(player.hp, Constants.PLAYER_MAX_HP),
			"a shield absorbs the hazard, so it used take_damage")
	_check(player.runtimes["echo_a"].shield_hp < 50.0,
			"...and the shield paid for it")
	player.runtimes["echo_a"].shield_hp = 0.0

	# ...and so does a damage_taken trait, which only the real path reads.
	player.hp = Constants.PLAYER_MAX_HP
	player.damage_taken_mult = 2.0
	hazard.strike()
	var doubled := Constants.PLAYER_MAX_HP - player.hp
	player.damage_taken_mult = 1.0
	player.hp = Constants.PLAYER_MAX_HP
	hazard.strike()
	var plain := Constants.PLAYER_MAX_HP - player.hp
	_check(doubled > plain,
			"a damage_taken trait changes what the hazard does (%f vs %f)"
			% [doubled, plain])
	hazard.reset_fixture()

func _gap_returns_you_safely(lab: EchoLab, player: Player) -> void:
	player.hp = Constants.PLAYER_MAX_HP
	var before := player.hp
	var recovery := lab.get_node("GapRecovery") as Area3D
	lab._on_gap_entered(player)
	_check(is_equal_approx(player.hp, before),
			"falling in the gap costs no health")
	_check(player.global_position.distance_to(recovery.global_position) < 12.0,
			"...and puts you back beside it")
	_check(player.velocity == Vector3.ZERO, "...standing still")

## Two runs of the same step sequence must agree, or comparing two Echoes
## against the moving target means nothing.
func _moving_target_is_deterministic(lab: EchoLab) -> void:
	var target: LabFixtures.LabMovingTarget = lab.moving_target
	target.reset_fixture()
	var first: Array = []
	for i in 90:
		target.advance(DT)
		first.append(target.position.x)
	var moved := false
	for x in first:
		if absf(x - first[0]) > 0.5:
			moved = true
	var span := 0.0
	for x in first:
		span = maxf(span, absf(x - first[0]))
	_exercised["motion"] += span
	_check(moved, "the moving target actually moves")
	target.reset_fixture()
	var same := true
	for i in 90:
		target.advance(DT)
		same = same and is_equal_approx(target.position.x, first[i])
	_check(same, "the same step sequence puts it in the same places")

func _reset_clears_transient_only(lab: EchoLab, player: Player) -> void:
	var before := _campaign_fingerprint()
	lab.dummy.take_damage(40.0, Vector3.FORWARD, 0.0)
	lab.dummy.statuses.apply("burning", 5.0, 1.0)
	lab.hazard.armed = true
	lab.moving_target.advance(1.0)
	player.hp = 20.0
	player.statuses.apply("slowed", 5.0, 1.0)

	lab.reset(player)

	_check(is_equal_approx(lab.dummy.absorbed, 0.0), "reset clears the dummy")
	_check(lab.dummy.statuses.active_kinds().is_empty(),
			"reset clears its statuses")
	_check(not lab.hazard.armed, "reset disarms the hazard")
	_check(is_equal_approx(lab.moving_target.elapsed, 0.0),
			"reset returns the moving target to its origin")
	_check(is_equal_approx(player.hp, Constants.PLAYER_MAX_HP),
			"reset heals the player to the test baseline")
	_check(player.statuses.active_kinds().is_empty(),
			"reset clears the player's statuses")
	_check(_campaign_fingerprint() == before,
			"reset changed NOTHING the player earned")
	# The loadout specifically: slots and Mk levels are not the Lab's.
	_check(str(BridgeClient.slots().get("echo_a")) == "act_gun",
			"reset leaves the slots alone")
	_check(int(BridgeClient.owned_component("act_gun").get("mk", 1)) == 2,
			"reset leaves Mk levels alone")

## The whole point, asserted last: a full session of use sent no intent
## and moved no campaign truth.
func _no_campaign_mutation(_lab: EchoLab) -> void:
	_check(BridgeClient.sent_intents.is_empty(),
			"the Lab sent no intent all session (%s)"
			% str(BridgeClient.sent_intents))
	_check(BridgeClient.snapshot.get("checked_location_ids", []).size() == 2,
			"no location was claimed by visiting the Lab")
	_check(int(BridgeClient.snapshot.get("coins_spent", 0)) == 3,
			"no coins were spent by visiting the Lab")


## Vacuity guard. Every assertion above could hold on a Lab where nothing
## works: a dummy that ignored damage would pass "never reports a kill", a
## hazard that fired nothing would pass "no campaign mutation", and a
## moving target that never moved would pass "deterministic". So the suite
## counts what it actually caused and refuses to be green without it.
var _exercised := {"damage": 0.0, "statuses": 0, "hazard": 0, "motion": 0.0}

func _the_suite_actually_exercised_something(_lab: EchoLab) -> void:
	_check(_exercised["damage"] > 0.0,
			"the suite dealt real damage (%f)" % _exercised["damage"])
	_check(int(_exercised["statuses"]) > 0,
			"...applied real statuses (%d)" % _exercised["statuses"])
	_check(int(_exercised["hazard"]) > 0,
			"...took real damage from the hazard (%d strikes)"
			% _exercised["hazard"])
	_check(float(_exercised["motion"]) > 1.0,
			"...and moved the target a real distance (%f)"
			% _exercised["motion"])


# --- S14: the Hub/Lab geometry contract ------------------------------------

## The Lab's gap is not decoration and its width is not a free number.
## Both bounds are silent failures if they break: too wide and the Lab
## cannot be crossed without an Echo, too narrow and it stops showing
## that an Echo does anything.
func _the_labs_gap_stays_mechanically_meaningful() -> void:
	_check(EchoLab.GAP_WIDTH < Constants.JUMP_FLAT_REACH,
			"the Lab gap (%.2f m) must stay INSIDE the base kit's flat "
			% EchoLab.GAP_WIDTH
			+ "reach (%.2f m), or the Lab needs an Echo to cross"
			% Constants.JUMP_FLAT_REACH)
	_check(EchoLab.GAP_WIDTH > Constants.SAFE_BASE_JUMP_GAP,
			"the Lab gap (%.2f m) must stay WIDER than the safe mandatory "
			% EchoLab.GAP_WIDTH
			+ "gap (%.2f m), or it demonstrates nothing about mobility"
			% Constants.SAFE_BASE_JUMP_GAP)

	## The margin is what makes it a demonstration rather than a coin
	## flip. A gap 1 cm inside the reach is a gap the player fails at and
	## blames the game for.
	var margin := Constants.JUMP_FLAT_REACH - EchoLab.GAP_WIDTH
	_check(margin > 0.1,
			"the Lab gap leaves only %.3f m of margin inside the base "
			% margin + "kit's reach; that reads as a bug, not a jump")

func _the_hub_resolves_every_anchor_its_logic_needs() -> void:
	## The S14 contract. A Hub scene that cannot answer one of these
	## leaves a station, the portal or the way out of GENERATING with
	## nowhere to be -- and the Hub is the only screen with no pause menu
	## to escape from.
	var anchors := HubAnchors.new()
	_check(anchors.missing().is_empty(),
			"the Hub cannot resolve these anchors: %s"
			% str(anchors.missing()))
	_check(anchors.outside_room().is_empty(),
			"these Hub anchors are outside the room: %s"
			% str(anchors.outside_room()))

	## The Lab lines up with the Hub through the doorway, not by
	## coincidence: both read the same Z.
	_check(is_equal_approx(anchors.origin("lab_entrance").z,
			HubAnchors.LAB_DOOR_Z),
			"the lab_entrance anchor drifted from LAB_DOOR_Z")
	_check(is_equal_approx(EchoLab.OFFSET.z, HubAnchors.LAB_DOOR_Z),
			"the Echo Lab (offset z=%.1f) no longer lines up with the "
			% EchoLab.OFFSET.z + "Hub doorway (z=%.1f); the way through "
			% HubAnchors.LAB_DOOR_Z + "opens onto a wall")

func _an_authored_scene_can_move_an_anchor() -> void:
	## The migration path S14 exists to open: a graybox or authored Hub
	## supplies anchors as markers, one at a time, and anything it does
	## not name keeps the procedural default. If adoption were all or
	## nothing, the first graybox would have to place all eight correctly
	## before the Hub could boot at all.
	var scene := Node3D.new()
	var marker := Marker3D.new()
	marker.name = "shop"
	marker.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(1, 0, 2))
	scene.add_child(marker)
	add_child(scene)

	var anchors := HubAnchors.new(scene)
	_check(anchors.origin("shop") == Vector3(1, 0, 2),
			"a scene's marker must win over the default, got %s"
			% anchors.origin("shop"))
	_check(anchors.origin("main_portal")
			== HubAnchors.defaults()["main_portal"].origin,
			"an anchor the scene did not name must keep its default")
	_check(anchors.missing().is_empty(),
			"partial adoption must still resolve every anchor")
	scene.queue_free()


# --- D3: finished but still alive ------------------------------------------

func _hub_snapshot(mode: String, goal_sent: bool) -> Dictionary:
	var snapshot := _snapshot()
	snapshot["hub"] = {"mode": mode, "headline": "H", "goal_sent": goal_sent,
			"postgame": goal_sent, "ap_online": true}
	snapshot["ap_connected"] = true
	return snapshot

func _the_ending_is_a_beat_not_a_wall() -> void:
	## The decided shape (OWNER_DECISIONS D3): when every Check is claimed
	## the Hub is FINISHED BUT STILL ALIVE. It is easy to build the first
	## half of that and forget the second, so both are asserted -- what
	## must stop, AND what must not.
	BridgeClient.snapshot = _hub_snapshot("ALL_CHECKS_CLEARED", true)
	var hub := HubController.new()
	add_child(hub)
	await get_tree().process_frame
	hub.refresh()

	var board: Label3D = hub._sub_board
	_check(board.text.contains("TRANSMISSION COMPLETE"),
			"the postgame Hub must say the transmission is complete, got: %s"
			% board.text)
	_check(board.text.contains("MULTIWORLD CONNECTION ACTIVE"),
			"the postgame Hub must say the multiworld is still going -- "
			+ "in an async game the others usually are. Got: %s" % board.text)

	## What must STOP.
	_check(hub._shop != null and hub._shop.complete,
			"the shop must read as complete once there is nothing left "
			+ "to stock it from")
	_check(hub._shop.interact_prompt().is_empty(),
			"a complete shop must not offer to open")
	_check(not hub._finale_portal.visible,
			"the finale portal must not be offered after the goal is sent")

	## What must NOT stop. This half is the decision.
	_check(hub._abandon != null, "the Hub is still inhabited")
	_check(board.text.contains("LAB AND ARCHIVE REMAIN OPEN"),
			"the Hub must say the Lab and Archive are still open")
	## And it must BE open, not merely say so. The first version of this
	## test only read the board, so closing the Archive alongside the shop
	## passed cleanly -- a sign advertising a door that is locked.
	_check(hub._terminal != null and not hub._terminal.complete,
			"the Archive must stay usable in the postgame; a finished "
			+ "campaign is still a loadout you can look at")
	_check(not hub._terminal.interact_prompt().is_empty(),
			"the Archive must still offer to open")
	var lab_door := HubAnchors.new()
	_check(lab_door.has("lab_entrance"),
			"the way to the Echo Lab must still exist in the postgame")
	_check(not board.text.to_lower().contains("credits"),
			"no forced credits: the multiworld is not over")

	hub.queue_free()
	BridgeClient.snapshot = {}

func _the_two_completion_beats_fire_once_each() -> void:
	## Edges, not levels. `goal_sent` and ALL_CHECKS_CLEARED both stay
	## true forever once reached, so a level test would repeat the ending
	## on every snapshot until the player walked out.
	var voice := EpsilonVoice.new()
	for kind: String in ["goal_sent", "campaign_complete"]:
		_check(not voice.line_for(kind).is_empty(),
				"'%s' has no line; the beat would be silent" % kind)
		_check(kind in EpsilonVoice.PRIORITY,
				"'%s' must outrank ambient barks, or a throttle can "
				% kind + "silently delete the ending")

	## And the wording is deliberately not locked -- what is pinned is
	## that the hook EXISTS and is reachable, not what it says.
	_check(EpsilonVoice.LINES["campaign_complete"].size() >= 2,
			"a beat with one line repeats the moment it is heard twice")
