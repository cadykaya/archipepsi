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


func _finish() -> void:
	print("  MEASURED %d check(s), %d note(s)" % [_checks, _notes])
	if _failures == 0:
		print("GODOT RAIL JUNCTION OK (%d checks)" % _checks)
	else:
		print("GODOT RAIL JUNCTION FAILED (%d of %d checks)"
			% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
