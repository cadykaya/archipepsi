extends Node
## THE FIRST PERSISTENT MACHINE CHAIN (`make godot-rail-junction`)
##
## A player pulls a lever; a span of track swings home and locks; the
## link it spans becomes crossable; a latch is reported; and coming back
## later finds the railway repaired. That is M1, and what it is really
## testing is the boundary the owner's addendum asked to be kept
## visible: **which of these four things survives leaving, and which
## does not.**
##
##   ACCEPTED SPAN REPAIR   persists. A latch fires and the commissioned
##                          link is RECOMPUTED from it at build time.
##   A SPAN MID-TRAVEL      does not. The lever was pulled and the span
##                          never locked, so nothing was accepted. This
##                          is the case that stops "accepted consequence"
##                          collapsing into "something happened".
##   RECEIVER / LEVER STATE does not. A control comes back armed.
##   CARRIER POSITION       is restored to a SUPPORTED DOCK, never to a
##                          saved transform.
##
## **One saved latch does not prove general persistence, and this suite
## does not claim it does.** What is measured here is one chain, end to
## end, including the four counterexamples. The live-bridge half -- the
## intent actually crossing the WebSocket into a real campaign's
## `ZoneProgress.latched` -- is a separate piece of evidence.

const STEP := 1.0 / 60.0
const HAND_FRAMES := 1200

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
	_shape()
	await _the_player_pulls_the_lever()
	_reported_once()
	_re_entry()
	_nothing_was_accepted()
	_another_packages_latch()
	_the_carrier_is_parked_not_resumed()
	await _the_scenario_is_walkable()
	await _the_grapple_opens_the_gantry()
	await _fighting_from_the_deck()
	await _walked_end_to_end()
	await _the_second_binding()
	_finish()


## THE RAILWAY UNDER TEST. Three docks; link 0 is already track and link
## 1 is the span the lever sends home.
func _junction() -> Dictionary:
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(16, 0, 0)]))
	var carrier := RailCarrier.create(rail,
		PackedFloat32Array([0.0, 8.0, rail.length()]),
		PackedStringArray(["S1", "S2", "S3"]), [true, false],
		Vector3(4.0, 0.4, 4.0), "concrete_facility")
	add_child(carrier)
	carrier.set_physics_process(false)
	var junction := RailJunction.create(carrier, "s2_junction")
	add_child(junction)
	var span := RailSpan.create("span_aligned", 1, 8.0)
	add_child(span)
	span.set_physics_process(false)
	var control := AlignmentControl.create()
	add_child(control)
	control.set_process(false)
	junction.add(span, control)
	return {"carrier": carrier, "junction": junction, "span": span,
		"control": control}


func _free(kit: Dictionary) -> void:
	for key: String in ["control", "span", "junction", "carrier"]:
		var node: Node = kit[key]
		node.queue_free()


## Ride the one link that IS track, so the carrier is standing where a
## player who has come this far would be standing: at S2, looking at the
## gap. Every refusal below is measured from there.
func _to_s2(carrier: RailCarrier) -> void:
	carrier.request(RailCarrier.FORWARD)
	_drive(carrier)


func _drive(carrier: RailCarrier, frames := HAND_FRAMES) -> int:
	for i in frames:
		if carrier.heading == RailCarrier.HOLD:
			return i
		carrier.advance(STEP)
	return -1


## A LATCH THE BRIDGE WOULD REFUSE IS REFUSED HERE.
##
## `record_latch` turns down any `package_id/latch_id` the committed
## manifest does not declare, and the id patterns are the bridge's own.
## Discovering that after a player has pulled the lever means the repair
## has visibly happened and the campaign disagrees.
func _shape() -> void:
	print("  -- SHAPE: a latch the bridge would refuse")
	var kit := _junction()
	var junction: RailJunction = kit["junction"]
	_check(junction.violations().is_empty(),
		"a well-formed junction has nothing to refuse, got %s"
			% [junction.violations()])
	var pkg := junction.package()
	_check(pkg["package_id"] == "s2_junction", "the package names itself")
	var conditions: Array = pkg["latch_conditions"]
	_check(conditions.size() == 1
		and conditions[0]["latch_id"] == "span_aligned"
		and conditions[0]["kind"] == "CONSTRAINT_STATE",
		"and declares the latch the manifest must carry, got %s"
			% [conditions])
	_check(junction.latch_ref(kit["span"]) == "s2_junction/span_aligned",
		"the latch's global identity is package-qualified")

	junction.package_id = "S2 Junction"
	_check(junction.violations().size() == 1,
		"a package id the bridge's pattern refuses is caught here")
	junction.package_id = "s2_junction"
	var twin := RailSpan.create("span_aligned", 1, 8.0)
	add_child(twin)
	twin.set_physics_process(false)
	junction.add(twin, null)
	_check(junction.violations().size() >= 1,
		"two spans sharing one latch id are indistinguishable, and "
			+ "saying so is this method's job")
	twin.queue_free()
	_free(kit)


## THE CHAIN, WITH A REAL PLAYER AND THE REAL INTERACT VERB.
func _the_player_pulls_the_lever() -> void:
	print("  -- CHAIN: lever -> span -> lock -> latch -> crossable")
	var kit := _junction()
	var carrier: RailCarrier = kit["carrier"]
	var junction: RailJunction = kit["junction"]
	var span: RailSpan = kit["span"]
	var control: AlignmentControl = kit["control"]
	var fired: Array = []
	junction.latch_fired.connect(func(p: String, l: String) -> void:
		fired.append("%s/%s" % [p, l]))
	_to_s2(carrier)

	# BEFORE. The span is stowed and the railway says so.
	_check(not span.commissioned(), "the span starts stowed")
	_check(carrier.at_dock() == 1, "and the carrier is standing at S2")
	var reasons: Array = []
	carrier.refused.connect(func(reason: String, _d: String) -> void:
		reasons.append(reason))
	_check(not carrier.request(RailCarrier.FORWARD),
		"S2 to S3 is refused")
	_check(reasons == ["no_link"],
		"for want of track, got %s" % [reasons])

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(-40, -8.5, -40)
	add_child(floor_body)
	var player := Player.create()
	add_child(player)
	player.global_position = Vector3(-40, -6.0, -40)
	await get_tree().process_frame
	for _i in 30:
		await get_tree().physics_frame
	# Within the interact probe's 3 m, dead ahead.
	control.global_position = player.camera.global_position \
		+ (-player.camera.global_transform.basis.z) * 1.6
	for _i in 3:
		await get_tree().physics_frame

	_check(player.camera_ray(3.0).get("collider") == control,
		"the interact probe finds the lever")
	_check(control.interact_prompt() == "[E] ALIGN THE SPAN",
		"and offers it by name, got '%s'" % control.interact_prompt())

	# THE REAL VERB. `player.gd` consumes `interact` in the same
	# `_physics_process` that set the target on the frame before, so the
	# press has to land on a later frame than the aim.
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame
	_check(control.done, "pressing it throws the lever")
	_check(span.travelling, "and the span starts travelling")

	# MID-TRAVEL IS NOT COMMISSIONED. Nothing has been accepted yet.
	for _i in 30:
		span.advance(STEP)
	_check(span.progress() > 0.0 and span.progress() < 1.0,
		"the span is part way across (%.0f%%)" % (span.progress() * 100.0))
	_check(not span.commissioned(), "and is not track yet")
	_check(fired.is_empty(), "no latch has fired, got %s" % [fired])
	reasons.clear()
	_check(not carrier.request(RailCarrier.FORWARD),
		"the carrier is still refused")
	_check(reasons == ["no_link"], "for want of track, got %s" % [reasons])

	# LOCKED.
	for _i in int(RailSpan.TRAVEL_SECONDS / STEP) + 10:
		span.advance(STEP)
	_check(span.locked, "the span locks home")
	_check(fired == ["s2_junction/span_aligned"],
		"and fires its latch, once, got %s" % [fired])
	_check(carrier.commissioned[1],
		"the link it spans is commissioned")
	_check(carrier.request(RailCarrier.FORWARD),
		"and the same command that was refused now travels")
	var frames := _drive(carrier)
	_check(frames > 0 and carrier.at_dock() == 2, "reaching S3")

	Input.action_release("interact")
	player.queue_free()
	floor_body.queue_free()
	_free(kit)
	await get_tree().process_frame


## THE CLIENT HALF OF A CONTRACT THAT WAS ONLY EVER HALF BUILT.
##
## `ZoneProgress.latched`, `LatchFired` and `record_latch` have been on
## the bridge since the physics slice landed. Every `latched` in this
## lane was prose in a comment: the client has never sent one.
func _reported_once() -> void:
	print("  -- REPORTED: the client sends `latch_fired`")
	var zone := ZoneController.new()
	zone.zone_id = "zone_01"
	add_child(zone)
	BridgeClient.sent_intents.clear()
	zone.report_latch("s2_junction", "span_aligned")
	var sent: Array = BridgeClient.sent_intents.duplicate()
	_check(sent.size() == 1, "one intent, got %d" % sent.size())
	if sent.size() == 1:
		var intent: Dictionary = sent[0]
		_check(intent == {"type": "latch_fired", "zone_id": "zone_01",
			"package_id": "s2_junction", "latch_id": "span_aligned"},
			"with exactly the fields the bridge reads, got %s" % [intent])
	# IDEMPOTENT AT THIS END TOO. The bridge is idempotent by
	# `package_id/latch_id` and a resend after a dropped connection is
	# the normal case -- but a machine that re-reported on every rebuild
	# would be sending the bridge back what the bridge sent it.
	zone.report_latch("s2_junction", "span_aligned")
	_check(BridgeClient.sent_intents.size() == 1,
		"and the same latch twice is still one intent")
	_check(zone.latches_fired().keys() == ["s2_junction/span_aligned"],
		"the Zone knows what it has reported, got %s"
			% [zone.latches_fired().keys()])

	# THE READ-BACK. `main.gd` unions the snapshot's `progress.latched`
	# into `latches_carried` exactly as it already does for keys, locks
	# and stations; a machine asks for the union, because an intent sent
	# in the same breath as leaving may not be in the snapshot yet.
	zone.latches_carried = {"s2_junction/other": true}
	_check(zone.latches_accepted()
		== ["s2_junction/other", "s2_junction/span_aligned"],
		"a Zone accepts the snapshot's latches and its own, got %s"
			% [zone.latches_accepted()])
	var rebuilt := _junction()
	var back: int = (rebuilt["junction"] as RailJunction).restore_from(
		zone.latches_accepted())
	_check(back == 1 and (rebuilt["span"] as RailSpan).locked,
		"and a machine rebuilt from that union comes up repaired")
	_free(rebuilt)
	BridgeClient.sent_intents.clear()
	zone.queue_free()


## COMING BACK. A FRESH junction, built from nothing, told only what the
## accepted latches were.
func _re_entry() -> void:
	print("  -- RE-ENTRY: the repair is recomputed, not replayed")
	var kit := _junction()
	var carrier: RailCarrier = kit["carrier"]
	var junction: RailJunction = kit["junction"]
	var span: RailSpan = kit["span"]
	var control: AlignmentControl = kit["control"]
	var fired: Array = []
	junction.latch_fired.connect(func(p: String, l: String) -> void:
		fired.append("%s/%s" % [p, l]))

	var restored := junction.restore_from(["s2_junction/span_aligned"])
	_check(restored == 1, "one span is restored, got %d" % restored)
	_check(span.locked and span.commissioned(),
		"the span comes up locked")
	_check(carrier.commissioned[1], "the link comes up commissioned")
	# THE POINT. A restore is a recomputation, not an event: reporting
	# it would be the client telling the bridge a fact the bridge told
	# the client, and on a monotone set that noise is indistinguishable
	# from a real latch.
	_check(fired.is_empty(),
		"and NOTHING is reported, got %s" % [fired])
	# LIVE STATE COMES BACK AT ITS DEFAULT, including the lever: its
	# position is a saved animation, not a decision.
	_check(not control.done, "the lever comes back armed")
	_check(control.thrown() == 0.0, "and standing up")
	_check(carrier.at_dock() == 0,
		"the carrier is parked at a dock, not where it was left")
	_check(carrier.request(RailCarrier.FORWARD) and _drive(carrier) > 0
		and carrier.at_dock() == 1, "and the railway is rideable")
	_free(kit)


## THE COUNTEREXAMPLE THAT GIVES THE ONE ABOVE ITS MEANING.
##
## The player pulled the lever and left while the span was still moving.
## Nothing was accepted, so nothing comes back -- and a system that
## saved "the lever was pulled" instead of "the latch fired" would hand
## back a repair that never completed.
func _nothing_was_accepted() -> void:
	print("  -- NOT ACCEPTED: a span mid-travel leaves nothing behind")
	var first := _junction()
	var span: RailSpan = first["span"]
	(first["control"] as AlignmentControl).interact(null)
	for _i in 30:
		span.advance(STEP)
	_check(span.travelling and not span.locked,
		"the span was left part way across")
	_free(first)

	var kit := _junction()
	var carrier: RailCarrier = kit["carrier"]
	var restored: int = (kit["junction"] as RailJunction).restore_from([])
	_to_s2(carrier)
	_check(restored == 0, "nothing is restored, got %d" % restored)
	_check(not (kit["span"] as RailSpan).commissioned(),
		"the span comes back stowed")
	_check(not carrier.commissioned[1], "the link comes back broken")
	var reasons: Array = []
	carrier.refused.connect(func(reason: String, _d: String) -> void:
		reasons.append(reason))
	_check(not carrier.request(RailCarrier.FORWARD)
		and reasons == ["no_link"],
		"and the crossing is refused again, got %s" % [reasons])
	_free(kit)


## A BARE `latch_id` IS NOT AN IDENTITY.
func _another_packages_latch() -> void:
	print("  -- IDENTITY: another package's latch is not this one's")
	var kit := _junction()
	var restored: int = (kit["junction"] as RailJunction).restore_from(
		["somewhere_else/span_aligned", "s2_junction/other_latch"])
	_check(restored == 0,
		"neither a foreign package nor an unknown latch restores "
			+ "anything, got %d" % restored)
	_check(not (kit["carrier"] as RailCarrier).commissioned[1],
		"and the link stays broken")
	_free(kit)


## SAFE MACHINERY: A CARRIER IS PARKED, NOT RESUMED.
func _the_carrier_is_parked_not_resumed() -> void:
	print("  -- PARKED: the carrier returns to a dock it is supported on")
	var kit := _junction()
	var carrier: RailCarrier = kit["carrier"]
	var junction: RailJunction = kit["junction"]
	carrier.request(RailCarrier.FORWARD)
	for _i in 40:
		carrier.advance(STEP)
	_check(carrier.at_dock() < 0,
		"the carrier is mid-segment (%.2f m)" % carrier.offset)
	junction.park()
	_check(carrier.at_dock() == 0, "parking puts it on S1")
	_check(carrier.heading == RailCarrier.HOLD and carrier.speed == 0.0,
		"with no journey left over")
	junction.park(7)
	_check(carrier.at_dock() == carrier.dock_offsets.size() - 1,
		"a dock this build does not have is clamped to one it does")
	_note("a carrier's position is not saved anywhere: `park` chooses a "
		+ "dock this build supports, because a carrier resumed where it "
		+ "was left could be standing on a span this build has not "
		+ "commissioned")
	_free(kit)


## AND IT IS WALKABLE. The scenario an operator launches with
## `--railway`, built headlessly and measured.
##
## **Why a scenario needs a test at all.** It is scaffolding, so nothing
## downstream depends on it -- which is exactly why it would rot
## silently, and a scaffold that has rotted is discovered by the person
## who launched it expecting to play. What is checked here is that the
## place is coherent: the controls are wired and aimed, the platforms
## are at deck height, the player lands on one, and the chain from
## shooting a control to locking the span works where it is built rather
## than only in a fixture.
func _the_scenario_is_walkable() -> void:
	print("  -- SCENARIO: `--railway` is a place a person can stand")
	var yard := RailwayScenario.new()
	add_child(yard)
	for _i in 40:
		await get_tree().physics_frame

	_check(yard.junction.violations().is_empty(),
		"the yard's junction has nothing to refuse, got %s"
			% [yard.junction.violations()])
	_check(yard.controls.receivers().size() == 6,
		"six shootable controls, two per dock, got %d"
			% yard.controls.receivers().size())
	_check(yard.carrier.at_dock() == 0, "the carrier is parked at S1")
	_check(not yard.carrier.commissioned[1],
		"and the gap beyond S2 is not track")

	# AIMED. A receiver whose local +Z is not the direction of
	# increasing offset sends the carrier the other way, and it would
	# look perfectly correct in the scene tree.
	var aimed := 0
	for receiver: RailReceiver in yard.controls.receivers():
		var dock := yard.carrier.dock_offsets[0]
		var best := INF
		for i in yard.carrier.dock_offsets.size():
			var d: float = receiver.global_position.distance_to(
				yard.rail.at(yard.carrier.dock_offsets[i]))
			if d < best:
				best = d
				dock = yard.carrier.dock_offsets[i]
		if receiver.global_transform.basis.z.normalized().dot(
				yard.rail.tangent(dock)) > 0.99:
			aimed += 1
	_check(aimed == 6, "every control points along the track, %d do"
		% aimed)

	# BOARDING IS A STEP, NOT A HOP: the platform and the deck top are
	# the same height, which is a number two builders could disagree
	# about and nothing else would notice until a player could not get
	# on.
	var deck_top: float = yard.carrier.pose().origin.y \
		+ RailwayScenario.DECK.y * 0.5
	_check(absf(deck_top - (RailwayScenario.RAIL_Y
		+ RailwayScenario.DECK.y)) < 0.01,
		"the deck's top is at the platform height (%.2f)" % deck_top)
	_check(yard.player.is_on_floor(),
		"the player lands on the S1 platform")
	_check(absf(yard.player.global_position.y - deck_top) < 2.0,
		"at platform height (%.2f vs %.2f)"
			% [yard.player.global_position.y, deck_top])

	# THE CHAIN, WHERE IT IS ACTUALLY BUILT.
	var forward: RailReceiver = null
	for receiver: RailReceiver in yard.controls.receivers():
		if receiver.direction == RailCarrier.FORWARD \
				and receiver.global_position.distance_to(
					yard.rail.at(yard.carrier.dock_offsets[0])) < 8.0:
			forward = receiver
	_check(forward != null, "S1 has a FORWARD control")
	if forward != null:
		forward.element.take_damage(1.0)
		yard.controls.resolve()
		_check(yard.carrier.heading == RailCarrier.FORWARD,
			"shooting it sends the carrier toward S2")
	_drive(yard.carrier)
	_check(yard.carrier.at_dock() == 1, "and it arrives at S2")

	yard.lever.interact(null)
	_check(yard.span.travelling, "the gantry lever starts the span")
	for _i in int(RailSpan.TRAVEL_SECONDS / STEP) + 10:
		yard.span.advance(STEP)
	_check(yard.span.locked and yard.carrier.commissioned[1],
		"which locks home and commissions the gap")
	# AND IT REACHES. A span that locked in the wrong place would still
	# pass every signal check above and leave the carrier riding air.
	var far: Vector3 = yard.span.global_transform \
		* Vector3(0.0, 0.0, yard.carrier.dock_offsets[2]
			- yard.carrier.dock_offsets[1])
	var s3: Vector3 = yard.rail.at(yard.carrier.dock_offsets[2])
	_check(far.distance_to(s3) < 0.6,
		"and the far end of the span meets S3 (%.2f m off)"
			% far.distance_to(s3))
	_check(yard.carrier.request(RailCarrier.FORWARD)
		and _drive(yard.carrier) > 0 and yard.carrier.at_dock() == 2,
		"the carrier can now ride to S3")

	yard.queue_free()
	await get_tree().process_frame


## Point a body's eyes at something, the way the mouse would.
func _aim(body: Player, at: Vector3) -> void:
	var d: Vector3 = at - body.camera.global_position
	body.rotation.y = atan2(-d.x, -d.z)
	body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## THE INTENDED EXPERIENCE, IN A DEVELOPMENT SCENARIO (M2-mech).
##
## **What this proves and what it does not.** It proves the loop: a
## control the player can SEE from the junction and cannot reach; a
## branch they can walk to on the base kit alone; a tool acquired there;
## and the same control opened with it on the way back. That is the
## Blindside review's cause B and the owner's approved first
## configuration.
##
## It proves **nothing** about progression. The Echo is handed over by
## the scenario's own pedestal, not by an AP Check, an interpretation
## fold or a snapshot; the acquisition contract is M2's completion
## requirement and is not built. Labelled M2-mech everywhere it appears,
## because a loop that plays is not a loop that is multiworld-safe.
func _the_grapple_opens_the_gantry() -> void:
	print("  -- M2-mech: acquire, return, and open what you could see")
	var yard := RailwayScenario.new()
	add_child(yard)
	for _i in 60:
		await get_tree().physics_frame
	var body: Player = yard.player
	var lever_at: Vector3 = yard.lever.global_position
	var plate: Vector3 = yard.grapple_plate.global_position

	# THE GANTRY IS VISIBLE AND OUT OF REACH. Both halves matter: a
	# control you cannot see is not a promise, and one you can walk to
	# is not a lock.
	var dock: Vector3 = yard.rail.at(yard.carrier.dock_offsets[1])
	body.global_position = dock + yard.dock_side(1) * RailwayScenario.DOCK_OUT \
		+ Vector3(0.0, RailwayScenario.RAIL_Y + RailwayScenario.DECK.y + 1.2,
			0.0)
	body.velocity = Vector3.ZERO
	for _i in 30:
		await get_tree().physics_frame
	# THE RING, not the lever: the lever stands ON the gantry and its
	# own deck hides it from below, which is true of any control on a
	# platform. What a player reads from the junction is the hook.
	_aim(body, plate)
	await get_tree().physics_frame
	_check(body.camera_ray(40.0).get("collider") == yard.grapple_plate,
		"the gantry's hook is visible from the S2 platform")
	_check(lever_at.y - body.global_position.y > 2.5,
		"and %.1f m above it, past anything a jump reaches"
			% (lever_at.y - body.global_position.y))
	_check(not yard.lever.done, "and has not been pulled")

	# BASE KIT ONLY: nothing in the mobility slot yet.
	var mobility: EchoRuntime = body.runtimes["mobility"]
	_check(str(mobility.equipped.get("component_id", "")) == "",
		"the player starts with nothing in the mobility slot, got '%s'"
			% mobility.equipped.get("component_id", ""))

	# THE BRANCH. Walked to on the base kit; the pedestal is taken with
	# the real interact verb.
	body.global_position = yard.grant.global_position \
		+ (yard.grant.global_transform.basis.z * 1.6) + Vector3(0, 0.6, 0)
	body.velocity = Vector3.ZERO
	for _i in 20:
		await get_tree().physics_frame
	_aim(body, yard.grant.global_position)
	for _i in 3:
		await get_tree().physics_frame
	_check(body.camera_ray(3.0).get("collider") == yard.grant,
		"the interact probe finds the pedestal")
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame
	_check(yard.grant.taken, "taking it hands over the Echo")
	_check(str(mobility.equipped.get("component_id", "")) == "dev_hookshot",
		"into the mobility slot, got '%s'"
			% mobility.equipped.get("component_id", ""))
	_check(str((mobility.equipped.get("primitive", {}) as Dictionary)
			.get("type", "")) == "grapple_to_surface",
		"as the primitive the schema's own tests author")

	# AND BACK TO THE JUNCTION, to open what was already visible.
	body.global_position = dock + yard.dock_side(1) * RailwayScenario.DOCK_OUT \
		+ Vector3(0.0, RailwayScenario.RAIL_Y + RailwayScenario.DECK.y + 1.2,
			0.0)
	body.velocity = Vector3.ZERO
	for _i in 30:
		await get_tree().physics_frame
	_aim(body, plate)
	await get_tree().physics_frame
	_check(body.camera_ray(25.0).get("collider") == yard.grapple_plate,
		"the hookshot is aimed at the gantry's plate")
	var before := body.global_position.y
	var pull: EchoRuntime = body.runtimes["mobility"]
	Input.action_press("fire_mobility")
	# THE INPUT PATH, not `activate()` called by hand. A slot that
	# fires only when a test reaches into the runtime is an Echo a
	# player cannot use, and the cooldown is what says the press
	# landed.
	#
	# A FEW FRAMES, not one. `Input.action_press` from a coroutine
	# lands between frames, so `is_action_just_pressed` can fall on
	# the frame after the one this resumes on. Reading the cooldown
	# a single frame later measured a press that had not been
	# delivered yet, and reported the Echo broken while the pull
	# it fired was in the air.
	var landed := false
	for _i in 4:
		await get_tree().physics_frame
		if pull.cooldown_remaining > 0.0:
			landed = true
			break
	Input.action_release("fire_mobility")
	_check(landed,
		"the mobility key fires the hookshot (cooldown %.2f)"
			% pull.cooldown_remaining)
	# AND STEER, because that is what a player does. The pull sets
	# `velocity` outright and `player.gd` then lerps the horizontal
	# part toward the walk intent every frame, so a hookshot fired
	# and then ignored arrives almost straight up. Holding forward
	# -- already aimed at the gantry by `_aim` -- is the input the
	# verb is used with, and measuring it without that would be
	# measuring a player who let go of the keyboard.
	Input.action_press("move_forward")
	var high := before
	for _i in 180:
		await get_tree().physics_frame
		high = maxf(high, body.global_position.y)
		if body.is_on_floor() and body.global_position.y > before + 2.0:
			break
	Input.action_release("move_forward")
	print("    pulled from %.2f m to %.2f m (peak %.2f)"
		% [before, body.global_position.y, high])
	_check(body.global_position.y > yard.lever.global_position.y - 1.5,
		"the pull puts the player on the gantry (%.2f m, lever at %.2f)"
			% [body.global_position.y, yard.lever.global_position.y])
	_check(body.is_on_floor() and body.global_position.y
			> RailwayScenario.GANTRY_Y - 0.5,
		"standing on it rather than back on the dock")

	# AND THE LOOP CLOSES.
	_aim(body, lever_at)
	for _i in 3:
		await get_tree().physics_frame
	_check(body.camera_ray(3.0).get("collider") == yard.lever,
		"the lever is in reach now")
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame
	_check(yard.lever.done, "and pulling it starts the span")
	for _i in int(RailSpan.TRAVEL_SECONDS / STEP) + 10:
		yard.span.advance(STEP)
	_check(yard.span.locked and yard.carrier.commissioned[1],
		"which locks home and opens the way to S3")
	# --- AND LEAVING, AND COMING BACK ---------------------------------
	#
	# The claim M1 actually makes, made visible. Everything the railway
	# is made of is thrown away and built again; what comes back is
	# whatever the accepted latch implies, and nothing else.
	_check(yard.accepted_latches() == ["yard_junction/span_aligned"],
		"one latch was accepted, got %s" % [yard.accepted_latches()])
	var old_span: RailSpan = yard.span
	var old_lever: AlignmentControl = yard.lever
	var old_carrier: RailCarrier = yard.carrier
	yard.reenter()
	await get_tree().physics_frame
	_check(yard.span != old_span and yard.lever != old_lever
		and yard.carrier != old_carrier,
		"coming back rebuilds the railway rather than resetting it")
	_check(yard.span.locked and yard.carrier.commissioned[1],
		"and the span is still home, recomputed from the latch")
	_check(not yard.lever.done,
		"while the lever stands up again: its position was never the "
			+ "thing that persisted")
	_check(yard.carrier.at_dock() == 0,
		"the carrier is parked at S1, not where it was left")
	_check(not yard.grant.taken,
		"and the pedestal is rebuilt -- a dev-path grant is scenery, "
			+ "not progress")
	_check(yard.accepted_latches() == ["yard_junction/span_aligned"],
		"and the rebuild reported nothing new, got %s"
			% [yard.accepted_latches()])
	_check(yard.carrier.request(RailCarrier.FORWARD),
		"the railway is rideable from the first command")
	_check(_drive(yard.carrier) > 0 and yard.carrier.at_dock() == 1,
		"reaching S2")

	yard.queue_free()
	await get_tree().process_frame


## CAN YOU FIGHT FROM THE SKIFF?
##
## The plan's own sequence puts "one meaningful combat situation" on the
## S1-to-S2 leg, and the skiff's whole claim is that a player does
## something on it other than stand. What is checked here is the part a
## test can hold: the shooters are real enemies, the deck's firing line
## reaches them, a shot from the deck damages one, and the shield stands
## between the deck and an enemy on its side. **Whether the fight is any
## good is a playtest question and is not answered here.**
func _fighting_from_the_deck() -> void:
	print("  -- GAUNTLET: a ride with something on it")
	var yard := RailwayScenario.new()
	add_child(yard)
	for _i in 60:
		await get_tree().physics_frame

	_check(yard.shooters.size() == 3,
		"three shooters stand beside the first leg, got %d"
			% yard.shooters.size())
	var alive := 0
	var sides := {}
	for shooter: Enemy in yard.shooters:
		if is_instance_valid(shooter) and shooter.hp > 0.0:
			alive += 1
		var along := yard.rail.nearest_offset(shooter.global_position)
		var side := yard.rail.at(along).direction_to(
			shooter.global_position)
		sides[signf(side.dot(Vector3.UP.cross(
			yard.rail.tangent(along))))] = true
	_check(alive == 3, "all of them alive, got %d" % alive)
	# ALTERNATING SIDES is what makes the shield worth moving behind: a
	# gauntlet all on one side is a gauntlet you solve by standing still.
	_check(sides.size() == 2,
		"and they are not all on one side of the track, got %d side(s)"
			% sides.size())

	# THE SHIELD IS REAL COVER, and it belongs to the carrier's own body
	# so it turns with the deck.
	_check(yard.shield != null and yard.shield.get_parent() == yard.carrier,
		"the shield is part of the carrier, so it turns with the deck")
	var deck_top: Vector3 = yard.carrier.pose().origin \
		+ Vector3(0.0, RailwayScenario.DECK.y * 0.5 + 0.9, 0.0)
	var outside: Vector3 = deck_top - yard.carrier.pose().basis.x * 6.0
	var space := get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(outside, deck_top)
	var blocked := space.intersect_ray(query)
	_check(not blocked.is_empty() and blocked["collider"] == yard.carrier,
		"a shot at the deck from the shielded side stops at the carrier")
	var open_side: Vector3 = deck_top + yard.carrier.pose().basis.x * 6.0
	var through := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(open_side, deck_top))
	# NOT the carrier: the yard's own furniture stands on that side
	# -- a dock platform, a control post -- and what is being
	# measured is the SHIELD, not an empty field.
	_check(through.is_empty() or through["collider"] != yard.carrier,
		"and nothing on the carrier stops a shot from the other side, "
		+ "which is why the rider has to move")

	# AND THE DECK'S FIRING LINE REACHES THEM. Measured from the deck
	# while the carrier is under way, not from the platform.
	var body: Player = yard.player
	body.global_position = deck_top + Vector3(0.0, 0.2, 0.0)
	body.velocity = Vector3.ZERO
	yard.carrier.request(RailCarrier.FORWARD)
	for _i in 90:
		await get_tree().physics_frame
	var mark: Enemy = yard.shooters[0]
	_aim(body, mark.global_position + Vector3(0.0, 0.7, 0.0))
	await get_tree().physics_frame
	var seen: Variant = body.camera_ray(45.0).get("collider")
	_check(seen == mark,
		"the first shooter is in the deck's line of fire, saw %s" % [seen])
	var hp := mark.hp
	body._fire_static_pulse()
	_check(mark.hp < hp,
		"and a shot from the moving deck damages it (%.1f -> %.1f)"
			% [hp, mark.hp])
	# AND DYING IS NOT A DEAD END. A yard with shooters in it and no way
	# back is a trap, and the player's respawn goes to a transform
	# captured in `_ready` -- so a scenario that only MOVED the player
	# would send them to the world origin the first time they lost.
	# S1's platform, not wherever the body happens to be standing:
	# by this point in the case it is aboard a moving carrier.
	var home: Vector3 = yard.rail.at(yard.carrier.dock_offsets[0]) \
			+ yard.dock_side(0) * RailwayScenario.DOCK_OUT
	body.global_position = yard.rail.at(yard.carrier.dock_offsets[2]) \
		+ Vector3(0.0, 6.0, 0.0)
	await get_tree().physics_frame
	body.take_damage(Constants.PLAYER_MAX_HP * 10.0)
	var waited := 0
	var budget := int((Constants.RESPAWN_DELAY + 1.5) * 60.0)
	while waited < budget and body.hp <= 0.0:
		await get_tree().physics_frame
		waited += 1
	_check(body.hp > 0.0, "the player comes back after %.1f s"
		% (float(waited) / 60.0))
	var off := Vector2(body.global_position.x - home.x,
			body.global_position.z - home.z).length()
	_check(off < 3.0,
		"on S1's platform rather than at the world origin (%.1f m "
			% off + "from its centre)")

	yard.queue_free()
	await get_tree().process_frame


## Steer a body toward a point on foot, and say whether it arrived.
##
## THE REAL INPUT, not an assignment. `integration_driver._walk_to` set
## the shape: press the action, turn the body, let
## `Player._physics_process` do the moving, and jump when wedged rather
## than spending the whole budget pressed against something.
func _walk(body: Player, goal: Vector3, within := 1.6,
		frames := 700) -> bool:
	var still := 0
	var last := body.global_position
	var arrived := false
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		if (here - last).length() < 0.012:
			still += 1
			if still == 20 and body.is_on_floor():
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
				still = 0
		else:
			still = 0
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return arrived


## THE WHOLE LOOP, WALKED.
##
## **Why this exists beside the cases above.** Every other case in this
## file puts the body where it needs to be and then measures one thing.
## That is the right instrument for "does the shield stop a shot" and
## the wrong one for "can a person get from the start of this to the end
## of it", and the plan asks for those two kinds of evidence to be kept
## apart rather than blended into one number. **Nothing below teleports
## the player.** Every metre is walked, ridden or pulled, and every
## command is a key.
##
## **One stated simplification:** the shooters are removed first. This
## case is about the ROUTE; the fight has its own case, and a walk that
## fails because the player was killed halfway would report the route
## broken when it is not.
func _walked_end_to_end() -> void:
	print("  -- WALKED: the whole loop on foot, nothing placed")
	var yard := RailwayScenario.new()
	add_child(yard)
	for _i in 60:
		await get_tree().physics_frame
	for shooter: Enemy in yard.shooters:
		shooter.queue_free()
	yard.shooters.clear()
	await get_tree().physics_frame
	var body: Player = yard.player
	var docks := yard.carrier.dock_offsets

	# 1. ABOARD. The deck is level with the platform and touching it, so
	#    this is a walk and not a jump.
	var aboard := await _walk(body, yard.carrier.pose().origin, 1.2)
	_check(aboard, "walks from S1's platform onto the deck")

	# 2. SHOOT THE CONTROL AND RIDE. The station resolves its own
	#    commands here -- nothing in this case calls `resolve`.
	var forward: RailReceiver = null
	for receiver: RailReceiver in yard.controls.receivers():
		if receiver.direction == RailCarrier.FORWARD \
				and receiver.global_position.distance_to(
					yard.rail.at(docks[0])) < 8.0:
			forward = receiver
	_aim(body, forward.element.global_position)
	await get_tree().physics_frame
	body._fire_static_pulse()
	var rode := 0
	while rode < 900 and yard.carrier.at_dock() != 1:
		await get_tree().physics_frame
		rode += 1
	_check(yard.carrier.at_dock() == 1,
		"one pulse at the chevron rides the skiff to S2 (%.1f s)"
			% (float(rode) / 60.0))
	_check(body.is_on_floor(), "with the player still standing on it")

	# 3. REFUSED, and the player is the one who finds out.
	var refusals: Array = []
	yard.controls.refused.connect(
		func(reason: String, _d: String) -> void: refusals.append(reason))
	# WAIT THE COOLDOWN OUT rather than reaching in and clearing it:
	# a player cannot, and the second pulse is the one that has to be
	# refused.
	for _i in 40:
		await get_tree().physics_frame
	_aim(body, forward.element.global_position)
	await get_tree().physics_frame
	body._fire_static_pulse()
	for _i in 6:
		await get_tree().physics_frame
	_check(refusals.has("no_link"),
		"shooting forward again is refused for want of track, got %s"
			% [refusals])

	# 4. OFF AT S2 AND OUT ALONG THE BRANCH.
	var s2_pad: Vector3 = yard.rail.at(docks[1]) \
		+ yard.dock_side(1) * RailwayScenario.DOCK_OUT
	_check(await _walk(body, s2_pad, 1.6),
		"steps off onto S2's platform")
	# THE WALKWAY, NOT THE STRAIGHT LINE. The branch leaves the dock
	# three metres along the track from its centre, so a body steered
	# straight at the pedestal walks off the platform's outer edge
	# before it ever reaches the walkway. A player would see the
	# walkway; the steering has to.
	var onto: Vector3 = yard.rail.at(docks[1]) \
			+ yard.dock_side(1) * 5.0 \
			+ yard.rail.tangent(docks[1]) * 3.0
	_check(await _walk(body, onto, 1.2, 400),
		"turns onto the branch walkway")
	_check(await _walk(body, yard.grant.global_position, 2.0, 900),
		"and walks it to the pedestal")

	# 5. TAKE IT, with the real verb.
	_aim(body, yard.grant.global_position)
	for _i in 3:
		await get_tree().physics_frame
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame
	_check(yard.grant.taken, "takes the hookshot")

	# 6. BACK TO THE JUNCTION, AND UP.
	_check(await _walk(body, onto, 2.0, 900),
		"walks the branch back")
	# CLOSE, not near. The gantry's deck overhangs the platform's
	# outer edge, and a body standing a metre and a half out is under
	# it -- the pull then takes them into its underside rather than
	# over its lip. Where you stand to fire is part of the shot.
	_check(await _walk(body, s2_pad, 0.8, 500),
		"and stands on S2's platform again")
	for _i in 20:
		await get_tree().physics_frame
	_aim(body, yard.grapple_plate.global_position)
	await get_tree().physics_frame
	Input.action_press("fire_mobility")
	var pulled := false
	for _i in 4:
		await get_tree().physics_frame
		if (body.runtimes["mobility"] as EchoRuntime).cooldown_remaining \
				> 0.0:
			pulled = true
			break
	Input.action_release("fire_mobility")
	Input.action_press("move_forward")
	for _i in 150:
		await get_tree().physics_frame
		if body.is_on_floor() and body.global_position.y \
				> RailwayScenario.GANTRY_Y - 0.5:
			break
	Input.action_release("move_forward")
	_check(pulled and body.global_position.y
			> RailwayScenario.GANTRY_Y - 0.5,
		"and pulls itself onto the gantry (%.2f m)"
			% body.global_position.y)

	# 7. THE LEVER, AND THE SPAN.
	_aim(body, yard.lever.global_position)
	for _i in 3:
		await get_tree().physics_frame
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	var locked := 0
	while locked < 600 and not yard.span.locked:
		await get_tree().physics_frame
		locked += 1
	_check(yard.span.locked and yard.carrier.commissioned[1],
		"throws the lever and the span locks home (%.1f s)"
			% (float(locked) / 60.0))

	# 8. DOWN, ABOARD, AND ON TO S3.
	# Off the gantry the short way: its deck overhangs the platform,
	# so walking at the platform steps off onto it.
	_check(await _walk(body, s2_pad, 2.0, 600),
		"comes down onto S2's platform")
	_check(await _walk(body, yard.carrier.pose().origin, 1.4, 600),
		"and steps back aboard")
	_check(body.is_on_floor() and body.global_position.y
			> RailwayScenario.RAIL_Y + RailwayScenario.DECK.y - 0.5,
		"standing on the deck rather than in the yard (%.2f m)"
			% body.global_position.y)
	for _i in 40:
		await get_tree().physics_frame
	_aim(body, forward.element.global_position)
	await get_tree().physics_frame
	body._fire_static_pulse()
	var last_leg := 0
	while last_leg < 900 and yard.carrier.at_dock() != 2:
		await get_tree().physics_frame
		last_leg += 1
	_check(yard.carrier.at_dock() == 2,
		"and the same command that was refused rides to S3 (%.1f s)"
			% (float(last_leg) / 60.0))

	yard.queue_free()
	await get_tree().process_frame


## THE SECOND BINDING, AND WHAT MAKES IT A SECOND ONE.
##
## The plan's addendum is careful about this and so is the case: a
## `ranged_hit` on eligible bracing is a DIFFERENT RELATIONSHIP -- remove
## what holds the span up, rather than reach a control and operate it --
## and it is **not** a second acquisition loop, because the starting
## player already shoots the transport receivers. What is checked here is
## that it is genuinely an alternative: the same accepted consequence,
## reached another way, in a yard that offers no grapple at all.
func _the_second_binding() -> void:
	print("  -- BRACING: the same span, a different relationship")
	var yard := RailwayScenario.new()
	yard.binding = RailwayScenario.BRACING_BINDING
	add_child(yard)
	for _i in 60:
		await get_tree().physics_frame

	# ALTERNATIVES, NEVER BOTH. A yard with a gantry AND a clamp the
	# base kit can shoot is a yard where the branch is optional.
	_check(yard.bracing != null, "the bracing is built")
	_check(yard.lever == null and yard.grant == null
		and yard.grapple_plate == null,
		"and this configuration has no gantry, no pedestal and no hook")
	_check(yard.junction.violations().is_empty(),
		"the junction is still well formed, got %s"
			% [yard.junction.violations()])
	_check(not yard.carrier.commissioned[1],
		"and the gap beyond S2 is still not track")

	# THE BRACING RIDES THE SPAN. It is what holds it up, not one more
	# control on a post -- so it is off the ground while the span is.
	var lift: float = yard.bracing.global_position.y \
		- yard.rail.at(yard.carrier.dock_offsets[1]).y
	_check(lift > 2.0,
		"it rides the raised span (%.1f m above the rail)" % lift)

	# AND THE BASE KIT REACHES IT, from the dock the player is refused at.
	var body: Player = yard.player
	var dock: Vector3 = yard.rail.at(yard.carrier.dock_offsets[1])
	body.global_position = dock + yard.dock_side(1) \
		* RailwayScenario.DOCK_OUT \
		+ Vector3(0.0, RailwayScenario.RAIL_Y + RailwayScenario.DECK.y
			+ 1.2, 0.0)
	body.velocity = Vector3.ZERO
	for _i in 30:
		await get_tree().physics_frame
	# Connected BEFORE the shot, or the check below could not fail.
	var fired: Array = []
	yard.junction.latch_fired.connect(
		func(pkg: String, latch: String) -> void:
			fired.append("%s/%s" % [pkg, latch]))
	_aim(body, yard.bracing.global_position)
	await get_tree().physics_frame
	var aimed: Variant = body.camera_ray(40.0).get("collider")
	_check(aimed != null and aimed.get("element") == yard.bracing,
		"the Static Pulse can reach it from S2's platform, saw %s"
			% [aimed])
	body._fire_static_pulse()
	for _i in 4:
		await get_tree().physics_frame
	_check(yard.span.travelling or yard.span.locked,
		"one shot releases the span")

	# THE SAME ACCEPTED CONSEQUENCE, reached another way.
	var landed := 0
	while landed < 600 and not yard.span.locked:
		await get_tree().physics_frame
		landed += 1
	_check(yard.span.locked and yard.carrier.commissioned[1],
		"it locks home and commissions the same link (%.1f s)"
			% (float(landed) / 60.0))
	_check(yard.accepted_latches() == ["yard_junction/span_aligned"],
		"under the same latch, got %s" % [yard.accepted_latches()])
	_check(fired == ["yard_junction/span_aligned"],
		"reported once and only once, got %s" % [fired])

	yard.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("  MEASURED %d check(s), %d note(s)" % [_checks, _notes])
	if _failures == 0:
		print("GODOT RAIL JUNCTION OK (%d checks)" % _checks)
	else:
		print("GODOT RAIL JUNCTION FAILED (%d of %d checks)"
			% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
