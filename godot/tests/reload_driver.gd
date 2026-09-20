class_name ReloadDriver
extends Node
## A CAMPAIGN REOPENED IN A NEW PROCESS, through the real Main.
##
## What this exists to catch: `ZoneProgress` has been persisted on every
## `key_collected`, `lock_opened` and `station_reached` since it landed,
## and `Main._to_zone` read none of it -- it read three in-memory
## dictionaries whose own docstring says they do not survive quitting. So
## the save held the progress and the game walked past it, and relaunching
## put a player back in front of a lock they had already opened with a key
## that was no longer there to collect. Nothing could see it, because
## every automated proof of a resume lived inside ONE process, and one
## process is exactly where the in-memory copy is right.
##
## So this is TWO Godot processes against one bridge and one save
## directory. The first plays; the second is launched cold, boots the real
## `Main`, reconnects, loads the campaign off disk and re-enters. The only
## thing carried between them is the save.
##
## Everything goes through the shipping path: `main._on_enter_zone()`
## sends the intent, `Main._on_snapshot` notices `ZONE_ACTIVE` and calls
## `_to_zone`, and `_to_zone` is where the recovery either happens or
## does not.

const PHASE_FLAG := "--reload-phase="
## WHICH GENERATION THE NAMED PROPOSAL IS SERVED AS; see `_advance_to`.
const AT_FLAG := "--named-case-at="
## THE FILE THE PROPOSAL CAME FROM, so the report can name the identity
## it was DUMPED under beside the one it was SERVED under.
const SOURCE_FLAG := "--named-case-source="
const WALK_FRAMES := 900
const ARRIVED := 1.4

## Untyped on purpose: `Main` names this class to start it, and naming
## `Main` back would be a cycle the parser refuses.
var main: Node
var _failures := 0
var _checks := 0


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _finish(code: int) -> void:
	if code == 0 and _failures == 0:
		print("GODOT RELOAD TESTS OK (%d checks)" % _checks)
	else:
		print("GODOT RELOAD FAILED (%d of %d checks)"
				% [_failures, _checks])
	get_tree().quit(1 if (code != 0 or _failures > 0) else 0)


## WHAT THE BRIDGE ACTUALLY SAID, so a phase failure names a reason.
## The controller records the verdict it acted on and the engine records
## why a layout could not be built; a timeout that prints neither sends
## the next person to the log file.
func _say_why(zone: ZoneController) -> void:
	if zone == null:
		print("    (no controller: the Zone was never built)")
		return
	print("    verdict '%s'; engine said '%s'; the bridge's Zone is in "
			% [zone.layout_verdict, zone.layout_failed]
			+ "state '%s' with %d refusal(s)"
			% [str(BridgeClient.active_zone().get("layout_state", "?")),
				int(BridgeClient.active_zone().get("layout_refusals", 0))])

static func phase_from_cmdline() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PHASE_FLAG):
			return arg.substr(PHASE_FLAG.length())
	return ""


## WHICH GENERATION TO SERVE THE NAMED PROPOSAL AS. 1 (the default) is
## the campaign's first Zone; see `_advance_to` for why it matters.
static func at_from_cmdline() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(AT_FLAG):
			return maxi(1, int(arg.substr(AT_FLAG.length())))
	return 1


## HAS THE CLIENT TOLD THE BRIDGE IT COULD NOT BUILD THIS ZONE?
##
## Read off `sent_intents` -- the client's own log of what it put on the
## wire -- rather than inferred from a state that several things can
## produce. A build failure and a bounded refusal both end with the
## player in the Hub, and only one of them ever sends this.
## THE `zone_id` THE NAMED CASE WAS DUMPED UNDER, or "" if not given.
static func source_id_from_cmdline() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with(SOURCE_FLAG):
			continue
		var where := arg.substr(SOURCE_FLAG.length())
		if not FileAccess.file_exists(where):
			return ""
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(where))
		if typeof(parsed) != TYPE_DICTIONARY:
			return ""
		return str((parsed as Dictionary).get("zone_id", ""))
	return ""


## HAS THE BRIDGE PARKED THIS ZONE? Read off the HUB, not the record.
##
## `CampaignSnapshot` carries `active_zone` and no list of the others,
## and a Zone the bridge parks stops being the active one -- so the
## record of the Zone whose outcome is being watched is the one thing
## not on the wire. `ZONE_FAILED` plus `discard_zone_id` is the same
## fact stated where the player reads it: this Zone cannot be built, and
## here is the way out of it.
func _parked(zid: String) -> bool:
	return BridgeClient.hub_mode() == "ZONE_FAILED" \
			and str(BridgeClient.hub().get("discard_zone_id", "")) == zid


## AN ORDERED RECORD OF WHAT HAPPENED, IN THE STAGES THAT ARE
## DIFFERENT FROM EACH OTHER.
##
## Reporting labels over what the driver already observes -- not a new
## event framework and not instrumentation inside the runtime. The
## stages exist because they are routinely conflated: a proposal the
## provider-side validator accepted is not a layout the bridge
## accepted, an engine build that failed is not a refused layout, and a
## Zone that exhausted its budget is not a Zone that generated.
var _timeline: Array[String] = []
var _clock := 0.0


func _stamp(what: String) -> void:
	_timeline.append("%7.2fs  %s" % [_clock_now(), what])


func _clock_now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0 - _clock


func _build_failure_reported() -> Dictionary:
	for raw: Variant in BridgeClient.sent_intents:
		var intent: Dictionary = raw
		if str(intent.get("type", "")) == "build_failed":
			return intent
	return {}


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	# THE HANDOFF PHASE NEEDS NO BRIDGE, and waiting twenty seconds for
	# one it will not use would make a fast gate slow. What it exercises
	# is entirely inside the client: a Zone the engine cannot build,
	# handed to the real `Main`.
	if phase_from_cmdline() == "build-failure":
		await _build_failure()
		return
	if not await _await("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		_finish(1)
		return
	match phase_from_cmdline():
		"record":
			await _record()
		"resume":
			await _resume()
		"named-case":
			await _named_case()
		"ordinary":
			await _ordinary()
		_:
			_check(false, "no --reload-phase was named")
			_finish(1)


## A ZONE THE ENGINE CANNOT BUILD, HANDED TO THE REAL `Main`.
##
## **The crash this gates.** `ZoneController.setup` returns early when
## `ZoneBuilder` cannot route the rooms, without creating a player --
## and `Main._to_zone` carried straight on into
## `hud.bind_player(zone.player)` and four `zone.player.<signal>.connect`
## calls against a null. The run died halfway through a handoff, with
## the Hub already torn down by `_clear_world` and the unbuildable Zone
## still in the tree.
##
## **The failure is real and is not injected.** `zone_08` of the
## declared sample, served under the id it was dumped as, is content the
## router genuinely cannot place -- the offline census has reported no
## manifest for it since it was dumped, and the live
## `godot-named-case CASE=zone_08 AT=8` run reproduces it through a
## bridge. Nothing here forces a failure or fakes a return value; the
## router is asked the same question and gives the same answer.
##
## **If this Zone ever starts routing, this gate fails LOUDLY** rather
## than passing on a build that succeeded. What it guards is the
## HANDOFF, not the routing, so the fixture would have to be replaced
## with another engine-failure case -- not deleted, and not quietly
## satisfied by a Zone that built.
func _build_failure() -> void:
	const CASE := "res://tests/fixtures/sample/zone_08.json"
	if not FileAccess.file_exists(CASE):
		_check(false, "the engine-failure fixture %s is missing" % CASE)
		_finish(1)
		return
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CASE))
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "%s did not parse as a Zone" % CASE)
		_finish(1)
		return
	var zone: Dictionary = parsed
	var zid := str(zone.get("zone_id", ""))
	print("  CASE: %s, served as '%s' -- the id it was dumped under, so "
			% [CASE, zid] + "the placement seed is the one it failed on")
	var before := BridgeClient.sent_intents.size()

	# THE REAL ENTRY PATH, not a controller built beside it. `_to_zone`
	# is the function that crashed and is the one under test.
	main._to_zone(zone)
	await get_tree().process_frame

	var failure := _build_failure_reported()
	_check(not failure.is_empty(),
			"the engine's failure was reported to the bridge rather than "
			+ "swallowed (this Zone must NOT route; if it now does, "
			+ "replace the fixture with another engine-failure case)")
	if failure.is_empty():
		_finish(1)
		return
	print("  ENGINE SAID: %s" % str(failure.get("reason", "(none)")))
	_check(str(failure.get("zone_id", "")) == zid,
			"the failure named the Zone that failed")
	_check(BridgeClient.sent_intents.size() > before,
			"the report went out on this entry, not an earlier one")
	# NO CRASH, NO HALF-BUILT LEVEL, NO WAITING.
	_check(main.zone == null,
			"the unbuildable Zone was torn down rather than left in the "
			+ "tree with no player in it")
	_check(main.hub != null,
			"the player was put back in a Hub that exists")
	_check(main.hub != null and main.hub.player != null,
			"there is a live player to bind to, rather than the null the "
			+ "failed Zone never created")
	_finish(0 if _failures == 0 else 1)


## WALK THE LAST LEG, with the real controller and the real inputs.
##
## Aimed every frame rather than launched on a fixed heading, because a
## body that slides along a wall ends up walking parallel to its goal
## and a fixed heading would call that "no progress". Bounded; the
## return value is the closest it came, so a failure reports a distance
## rather than a verdict it has not earned.
func _walk_the_last_leg(body: Node3D, to: Vector3, frames := 420) -> float:
	var closest := body.global_position.distance_to(to)
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		var flat := Vector3(to.x - body.global_position.x, 0.0,
				to.z - body.global_position.z)
		if flat.length() > 0.01:
			body.rotation.y = atan2(-flat.x, -flat.z)
			var eye := body.global_position + Vector3.UP \
					* Constants.PLAYER_EYE_HEIGHT
			body.camera.rotation.x = clampf(
					atan2(to.y - eye.y, maxf(flat.length(), 0.01)),
					-PI / 3.0, PI / 3.0)
		await get_tree().physics_frame
		closest = minf(closest, body.global_position.distance_to(to))
		if closest <= 1.6:
			break
	Input.action_release("move_forward")
	return closest


## A CHECK, CLAIMED THE WAY A PLAYER CLAIMS ONE.
##
## **A Check is objective-gated, and the gate is the point.** Every
## pedestal in an ordinary Zone starts `locked`; it becomes `available`
## when its chamber's objective is satisfied. Two objectives exist:
## `kill_all`, which needs combat, and `platform_to_goal`, which a
## player satisfies BY ARRIVING. This takes the second one, because
## arriving is a thing a body can do and `enemy.die()` is a test-only
## helper that would make this route a claim about the helper.
##
## Each stage is reported separately because they are routinely
## collapsed: arriving is not addressing, addressing is not claiming,
## and claiming is not the bridge confirming.
func _claim_one_check(zone: ZoneController, _zone_id: String) -> void:
	var body: Node3D = zone.player
	var subject: Node = _first_available(zone)
	if subject == null:
		# THE GATE, OPENED BY WALKING INTO IT. The goal areas are plain
		# `Area3D` children of the controller with `body_entered` wired
		# to `_on_goal_area_entered`; entering one is the whole
		# objective, and entering it with the real body is the whole
		# proof. Nothing calls the handler directly here.
		var gates: Array[Node] = []
		for child: Node in zone.get_children():
			if child is Area3D:
				gates.append(child)
		print("  OBJECTIVE: every pedestal is locked; %d goal area(s) "
				% gates.size() + "in this Zone, walking into them")
		for gate: Node in gates:
			var at := (gate as Node3D).global_position
			var stand := _standable_near(at)
			if stand == Vector3.ZERO:
				continue
			body.global_position = stand
			for _i in 8:
				await get_tree().physics_frame
			var closest := await _walk_the_last_leg(body, at, 240)
			subject = _first_available(zone)
			if subject != null:
				print("  OBJECTIVE: walked into a goal area (closest "
						+ "%.1f m); a Check unlocked" % closest)
				_stamp("goal area entered on foot; a Check unlocked")
				break
	if subject == null:
		print("  CHECK: nothing became claimable. Every pedestal in this "
				+ "Zone is behind an objective this instrument does not "
				+ "satisfy -- combat is `kill_all`, and killing enemies "
				+ "with a test helper would be a claim about the helper. "
				+ "Reported, not forced.")
		return
	var goal: Vector3 = (subject as Node3D).global_position
	# PLACED NEAR, THEN WALKED. Declared as isolation: the route ACROSS
	# the Zone is `godot-traverse`'s measurement and is not claimed here.
	var stand_at := _standable_near(goal)
	if stand_at == Vector3.ZERO:
		print("  CHECK: no standable ground within reach of %s; the last "
				% str(subject.name) + "leg was not walked")
		return
	body.global_position = stand_at
	for _i in 8:
		await get_tree().physics_frame
	var started := body.global_position.distance_to(goal)
	var came := await _walk_the_last_leg(body, goal)
	_stamp("walked the last leg to %s: %.1f m -> %.1f m"
			% [str(subject.name), started, came])
	print("  CHECK: %s  placed %.1f m out (diagnostic isolation), then "
			% [str(subject.name), started]
			+ "WALKED to %.1f m under the real controller" % came)
	var addressed := await _address(body, goal, subject)
	_check(addressed, "the game's own interact ray found %s from where "
			% str(subject.name) + "the body stopped")
	if not addressed:
		return
	print("  CHECK: the prompt reads '%s'"
			% str(subject.call("interact_prompt")))
	var loc := int(subject.get("location_id"))
	_stamp("interact pressed on %s (location %d)" % [str(subject.name), loc])
	subject.call("interact", body)
	var confirmed := await _await("the bridge to confirm location %d" % loc,
			func() -> bool:
				for raw: Variant in BridgeClient.snapshot.get(
						"checked_location_ids", []):
					if int(raw) == loc:
						return true
				return false, 30.0)
	_check(confirmed, "location %d was claimed through `Reward.interact` "
			% loc + "and confirmed by the bridge")
	if confirmed:
		_stamp("bridge confirmed location %d" % loc)


## THE FIRST PEDESTAL A PLAYER COULD PRESS E ON, or null.
func _first_available(zone: ZoneController) -> Node:
	for node: Node in _find_all(zone, "RewardObject"):
		if str(node.get("state")) == "available":
			return node
	return null


## TURN TOWARD A THING UNTIL THE GAME'S OWN RAY FINDS IT.
##
## Proximity is not addressability: the interact ray is what decides
## whether a player standing here could press E, and it is the only
## thing asked.
func _address(body: Node3D, goal: Vector3, target: Node) -> bool:
	for _i in 30:
		var flat := Vector3(goal.x - body.global_position.x, 0.0,
				goal.z - body.global_position.z)
		if flat.length() > 0.01:
			body.rotation.y = atan2(-flat.x, -flat.z)
			var eye := body.global_position + Vector3.UP \
					* Constants.PLAYER_EYE_HEIGHT
			body.camera.rotation.x = clampf(
					atan2(goal.y - eye.y, maxf(flat.length(), 0.01)),
					-PI / 3.0, PI / 3.0)
		await get_tree().physics_frame
		if body.get("_interact_target") == target:
			return true
	return false


## SOMEWHERE A BODY CAN STAND WITHIN REACH OF A POINT.
##
## The pedestal's own position is inside the pedestal. This probes a
## ring around it for ground with headroom, which is the same pair
## `RoomAudit.arrival_is_supported` asks.
func _standable_near(goal: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	for radius: float in [2.4, 3.2, 4.0]:
		for step in 12:
			var a := TAU * float(step) / 12.0
			var at := goal + Vector3(cos(a), 0.0, sin(a)) * radius
			var down := PhysicsRayQueryParameters3D.create(
					at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0)
			var hit := space.intersect_ray(down)
			if hit.is_empty():
				continue
			var floor_at: Vector3 = hit["position"]
			var up := PhysicsRayQueryParameters3D.create(
					floor_at + Vector3.UP * 0.2,
					floor_at + Vector3.UP * Constants.PLAYER_HEIGHT)
			if not space.intersect_ray(up).is_empty():
				continue
			return floor_at + Vector3.UP * 0.1
	return Vector3.ZERO


## A STATION, BROUGHT ONLINE ON FOOT AND THEN PRESSED.
##
## The pad is an `Area3D` and `body_entered` is what reaches it, so the
## body WALKS in rather than being put there -- a body placed already
## overlapping is a bet on how the physics server reports it, and the
## bet lost the first time this was written. Pressing the station is the
## station's own `interact`, which is what opens the panel: the
## controller asks `Main` for a screen and `Main` is the one that has
## one, so emitting the controller's signal from here would test the
## panel and skip the wiring.
func _open_a_station(zone: ZoneController) -> void:
	var stations: Array[Node] = _find_all(zone, "WarpStation")
	if stations.is_empty():
		print("  STATION: this Zone composed none; nothing to open")
		return
	var body: Node3D = zone.player
	var station: Node = null
	for candidate: Node in stations:
		var at := (candidate as Node3D).global_position
		var stand := _standable_near(at)
		if stand == Vector3.ZERO:
			continue
		body.global_position = stand
		for _i in 8:
			await get_tree().physics_frame
		await _walk_the_last_leg(body, at, 240)
		if zone.stations_reached().has(str(candidate.get("station_id"))):
			station = candidate
			break
	_check(station != null, "walking onto a station pad brought it "
			+ "online (%d station(s) in this Zone)" % stations.size())
	if station == null:
		return
	var sid := str(station.get("station_id"))
	print("  STATION: %s came online by standing on it" % sid)
	_stamp("station %s online" % sid)
	var addressed := await _address(body,
			(station as Node3D).global_position, station)
	_check(addressed, "the interact ray found station %s" % sid)
	if not addressed:
		return
	station.call("interact", body)
	await get_tree().process_frame
	await get_tree().process_frame
	var opened: bool = main.station_panel != null \
			and bool(main.station_panel.visible)
	_check(opened, "pressing the station opened the travel panel")
	if opened:
		_stamp("travel panel opened from station %s" % sid)
		main.station_panel.close()
		await get_tree().process_frame


## AN ECHO THE CAMPAIGN GAVE, PUT IN A SLOT.
##
## Only if the mock allocation supplied one, and only into a slot that
## Action actually declares. Nothing is granted here: an Echo exists
## because an Archipelago item arrived, and inventing one would make
## this a claim about the harness rather than about the campaign.
## `_cycle_echo` is where the wheel and the inventory screen both end,
## so this goes through it rather than composing its own intent.
func _equip_an_echo() -> void:
	var owned: Array = BridgeClient.owned_components("action")
	if owned.is_empty():
		print("  ECHO: the campaign has granted no Action yet, so there "
				+ "is nothing to equip. Reported, not granted.")
		return
	# AN ACTION BELONGS TO ONE SLOT. Offering a mobility Echo to `echo_a`
	# produces an intent the bridge is obliged to refuse, which is why
	# `_cycle_echo` filters -- and why asking only `echo_a` reported a
	# failure when the one owned Action was a mobility one.
	var slots: Dictionary = {}
	for raw: Variant in owned:
		var entry: Dictionary = raw
		var component: Dictionary = entry.get("component", {})
		var slot := str(component.get("slot", ""))
		if slot != "":
			slots[slot] = true
	if slots.is_empty():
		print("  ECHO: %d Action(s) owned, none declaring a slot; "
				% owned.size() + "nothing to equip")
		return
	for slot: String in slots:
		var before: Variant = BridgeClient.slots().get(slot)
		main._cycle_echo(1, slot)
		var moved := await _await("the %s slot to change" % slot,
				func() -> bool:
					return BridgeClient.slots().get(slot) != before, 15.0)
		if moved:
			print("  ECHO: %s now holds '%s' (of %d owned Action(s), "
					% [slot, str(BridgeClient.slots().get(slot)),
						owned.size()]
					+ "slots offered: %s)" % str(slots.keys()))
			_stamp("equipped '%s' into %s"
					% [str(BridgeClient.slots().get(slot)), slot])
			_check(true, "an owned Action was put in %s through the "
					% slot + "same path the wheel and the inventory "
					+ "screen use")
			return
	_check(false, "an owned Action was put in a slot (tried %s)"
			% str(slots.keys()))


## LEAVE WITHOUT ABANDONING, AND COME BACK.
##
## `leave_zone`, which is what the panel's Return to Hub sends -- not
## `abandon_zone`, which gives the Checks back, and not `exit_zone`,
## which finishes the Zone.
func _leave_and_return(zone_id: String) -> void:
	var held := (BridgeClient.active_zone().get(
			"allocated_location_ids", []) as Array).size()
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": zone_id})
	main._to_hub()
	if not await _await("the Hub after leaving",
			func() -> bool: return main.hub != null, 30.0):
		return
	_stamp("left '%s' without abandoning it" % zone_id)
	_check(main.zone == null, "the Zone was torn down on leaving")
	main._on_enter_zone()
	var back := await _await("the client to re-enter and rebuild",
			func() -> bool:
				return main.zone != null and main.zone.player != null, 90.0)
	_check(back, "the Zone was re-entered after returning to the Hub")
	if not back:
		return
	_stamp("re-entered '%s'" % zone_id)
	var after := (BridgeClient.active_zone().get(
			"allocated_location_ids", []) as Array).size()
	_check(after == held, "leaving and re-entering changed no allocation "
			+ "(%d of %d)" % [after, held])


## ONE ORDINARY ZONE, AT DEFAULT SCALE, THROUGH THE REAL APPLICATION.
##
## **What this is for.** Every other live harness here serves a NAMED
## proposal so a case can be put in front of the client. This one asks
## the campaign for whatever it would ordinarily compose, at the scale
## the diagnostic will actually run at, and then does the things a
## player does in the order a player does them: enter, walk the last
## leg to a Check and press E on it, open a station panel, return to the
## Hub without abandoning, and go back in.
##
## **What it is NOT.** The walk is the LAST LEG only: the body is put at
## a standable point near the pedestal's own room and then walks and
## turns under the real controller with the real input actions. Whether
## a straight-line route across the Zone reaches every Check is
## `godot-traverse`'s question and is reported there, with its own
## BLOCKED and UNRESOLVED outcomes. Saying it here would be borrowing
## one instrument's answer for another's.
##
## Every stage says which of these it is: physically walked · addressed
## by the game's own interact ray · claimed through `Reward.interact` ·
## confirmed by the bridge.
func _ordinary() -> void:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("a campaign",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN", 60.0):
		_finish(1)
		return
	# WHICH RUNTIME THIS IS, before anything is played. A report that
	# does not say which provider composed the Zone cannot be told from
	# one that ran against a fixture.
	var snap := BridgeClient.snapshot
	print("  RUNTIME: epsilon=%s  ap=%s  campaign=%s"
			% [str(snap.get("epsilon_provider", "?")),
				str(snap.get("ap_mode", "?")),
				str(snap.get("seed_name", "?"))])
	print("          (the bridge printed its resolved save directory and "
			+ "scale at startup; it is in this run's log)")
	if BridgeClient.active_zone().is_empty():
		BridgeClient.send_intent({"type": "request_next_zone"})
	# ZONE_READY, NOT "a record exists". `active_zone` is populated at
	# PENDING_GENERATION -- before the provider has composed anything --
	# so a wait on the record returning fires while `zone` is still
	# null, and the enter intent that follows is sent at a Zone that has
	# no content yet. Invisible with the sample provider, which answers
	# instantly; the fallback at default scale takes long enough to
	# expose it, and did.
	if not await _await("an ordinarily composed Zone (ZONE_READY)",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_READY", 120.0):
		_finish(1)
		return
	var record := BridgeClient.active_zone()
	var zone_id := str(record.get("zone_id", "?"))
	var allocated: Array = record.get("allocated_location_ids", [])
	print("  ZONE: '%s' with %d Check(s) -- composed by the live "
			% [zone_id, allocated.size()]
			+ "provider for this campaign, not served from a fixture")

	_clock = float(Time.get_ticks_msec()) / 1000.0
	_stamp("ordinary proposal offered for '%s'" % zone_id)
	main._on_enter_zone()
	if not await _await("the client to build and enter it",
			func() -> bool:
				return (main.zone != null and main.zone.player != null) \
						or not _build_failure_reported().is_empty(), 90.0):
		_finish(1)
		return
	if not _build_failure_reported().is_empty():
		_check(false, "the ordinary Zone for this campaign could not be "
				+ "built by the engine (%s)"
				% str(_build_failure_reported().get("reason", "?")))
		_finish(1)
		return
	_stamp("engine build finished; a player exists")
	var zone := main.zone as ZoneController
	var served: Dictionary = zone.zone
	print("  BUILT: '%s', %d room(s), %d edge(s), theme %s"
			% [str(served.get("display_name", "?")),
				(served.get("chambers", []) as Array).size(),
				(served.get("edges", []) as Array).size(),
				str(served.get("theme", "?"))])
	if not await _await("the bridge's verdict",
			func() -> bool: return zone.layout_verdict != "", 60.0):
		_finish(1)
		return
	_stamp("bridge verdict: %s" % zone.layout_verdict)
	_check(zone.layout_verdict == "ACCEPTED",
			"the ordinary Zone's layout was ACCEPTED (%s)"
			% zone.layout_verdict)
	if zone.layout_verdict != "ACCEPTED":
		_finish(1)
		return

	await _claim_one_check(zone, zone_id)
	await _equip_an_echo()
	await _open_a_station(zone)
	await _leave_and_return(zone_id)

	print("  TIMELINE:")
	for line: String in _timeline:
		print("    %s" % line)
	_finish(0 if _failures == 0 else 1)


## SERVE THE NAMED PROPOSAL AS THE CAMPAIGN'S Nth ZONE.
##
## **This exists because the layout seed is the zone_id.** `ZoneBuilder`
## seeds placement with `hash("<zone_id>|<theme>|layout")` and a campaign
## gives every proposal its own id -- `zone_001` for the first one -- so
## the sample dumped as `zone_008` is laid out here under a pose sequence
## it was never measured with. Four sample contents the offline census
## calls unroutable route on the first attempt that way. That is a fact
## about the seed, and it is also why a case that FAILS offline cannot be
## reproduced live by simply serving its content.
##
## The ids a campaign mints are `zone_{generation_counter + 1:03d}`, and
## the sample was dumped from a campaign's own sequence -- so serving it
## as the Nth generation gives it back the id it failed under, and the
## placement seed with it. Nothing is faked: the campaign really does
## generate N Zones.
##
## The ones before it are generated and ABANDONED, which is the intent a
## player has for a Zone they do not want. Abandoning returns its
## allocated locations to the pool, so the Zone that matters is allocated
## from a full pool exactly as a first Zone would be.
func _advance_to(generation: int) -> bool:
	if generation <= 1:
		return true
	print("  ADVANCING: generating and abandoning %d Zone(s) so the "
			% (generation - 1)
			+ "sample is served as this campaign's Zone %d -- the id it "
			% generation
			+ "was dumped under, and therefore its placement seed")
	for _i in generation - 1:
		if BridgeClient.active_zone().is_empty():
			BridgeClient.send_intent({"type": "request_next_zone"})
		if not await _await("a Zone to stand down (ZONE_READY)",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_READY", 60.0):
			return false
		var zid := str(BridgeClient.active_zone().get("zone_id", ""))
		BridgeClient.send_intent({"type": "abandon_zone", "zone_id": zid})
		if not await _await("'%s' to be abandoned" % zid,
				func() -> bool:
					return BridgeClient.active_zone().is_empty(), 30.0):
			return false
	return true


## ONE NAMED PROPOSAL, IN FRONT OF A REAL CLIENT AND A REAL BRIDGE.
##
## `make zone-sample` judges a manifest offline: the engine builds a
## Zone, measures it, writes the manifest, and `layout.validate` reads
## it. That answers "would the bridge accept this geometry" and nothing
## about what a PLAYER meets -- whether the client enters, whether a
## refusal recovers inside its budget or exhausts it, whether the Hub is
## still usable afterwards and the Zone still holds its Checks.
##
## So the bridge is started with `--epsilon=sample`, which serves one
## named proposal re-keyed to this campaign's own identity and
## allocation, and this walks the ordinary path: ask for a Zone, enter
## it, let the client build and certify it and the bridge judge what
## comes back. Nothing here fabricates a certificate or skips a verdict.
##
## **A BOUNDED REFUSAL IS NOT A FAILED RUN, and it is not a success
## either.** Both outcomes are reported in the same words every time --
## the first verdict, how many refusals the Zone has spent, whether it
## ended ACCEPTED and entered or exhausted its budget, and what the Hub
## and the Check count say afterwards -- so a recovery can never be read
## as a first-attempt acceptance.
func _named_case() -> void:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("a campaign",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN"):
		_finish(1)
		return
	if not await _advance_to(at_from_cmdline()):
		_finish(1)
		return
	if BridgeClient.active_zone().is_empty():
		BridgeClient.send_intent({"type": "request_next_zone"})
	# ZONE_READY, not merely "a record exists": `active_zone` is
	# populated at PENDING_GENERATION, before the provider has composed
	# anything, so the weaker wait sends `enter_zone` at a Zone with no
	# content in it.
	if not await _await("the named proposal (ZONE_READY)",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_READY", 120.0):
		_finish(1)
		return
	var zone: Dictionary = BridgeClient.active_zone()
	var zone_id := str(zone.get("zone_id", "?"))
	var allocated := (zone.get("allocated_location_ids", []) as Array).size()
	_clock = float(Time.get_ticks_msec()) / 1000.0
	# THE BRIDGE ONLY OFFERS A PROPOSAL ITS OWN VALIDATOR ACCEPTED
	# (`generate_zone_validated`), so a record being here at all is that
	# stage having passed. It says nothing about geometry.
	_stamp("provider proposal offered for '%s' and accepted by the "
			% zone_id + "provider-side validator (%d Check(s) allocated)"
			% allocated)
	print("  NAMED CASE: %s, %d Check(s) allocated to it"
			% [zone_id, allocated])
	# WHICH IDENTITY IT LAID OUT UNDER, because that decides the layout.
	#
	# `ZoneBuilder` seeds its placement RNG with
	# `hash("<zone_id>|<theme>|layout")`, and a campaign gives the
	# proposal ITS OWN zone_id. So the same rooms under a different id
	# are a DIFFERENT placement experiment: four sample contents the
	# offline census calls unroutable route on the first attempt that
	# way. Stated as a comparison of two named ids rather than a hedge,
	# because reading a re-keyed success as a repair of the dumped case
	# is exactly the mistake available here.
	var dumped := source_id_from_cmdline()
	if dumped == "":
		print("  IDENTITY: served as '%s'; the source's own zone_id was "
				% zone_id + "not passed, so whether the placement seed "
				+ "matches the one this case was measured under is "
				+ "UNKNOWN from this run")
	elif dumped == zone_id:
		print("  IDENTITY: SEED PRESERVED -- dumped as '%s' and served "
				% dumped + "as '%s', so the placement seed is the one "
				% zone_id + "this case was measured under")
	else:
		print("  IDENTITY: SEED CHANGED -- dumped as '%s', served as "
				% dumped + "'%s'. Same rooms, different pose sequence; "
				% zone_id + "an outcome here is not an outcome for the "
				+ "dumped case")
	_stamp("enter_zone sent; the client begins the engine build")
	main._on_enter_zone()
	# WHAT WAS ACTUALLY SERVED, read from the Zone the CLIENT BUILT.
	# The snapshot carries `zone: null` until the proposal lands, and an
	# earlier version read it there and reported "0 room(s)" for a Zone
	# of twenty-three -- a report about its own timing.
	#
	# EITHER OUTCOME ENDS THE WAIT. `_await` records a timeout as a
	# failed check, and an engine failure that is correctly reported is
	# not a failed run -- it is the other half of what this harness is
	# for. So the predicate accepts both and the branches below say
	# which happened; a timeout now means NEITHER, which is the
	# indefinite wait this path exists to rule out.
	var settled := await _await("the client to build the Zone or report "
			+ "that it cannot",
			func() -> bool:
				return (main.zone != null and main.zone.player != null) \
						or not _build_failure_reported().is_empty(),
			60.0)
	var failure := _build_failure_reported()
	var built := settled and failure.is_empty()
	if built:
		_stamp("engine build finished; a player exists and the layout "
				+ "goes to the bridge for a verdict")
	elif not failure.is_empty():
		_stamp("ENGINE BUILD FAILED -- %s"
				% str(failure.get("reason", "(no reason)")))
		_stamp("client sent build_failed for '%s' proposal %s attempt %s"
				% [str(failure.get("zone_id", "?")),
					str(failure.get("proposal_id", "(none)")),
					str(failure.get("attempt", "(none)"))])
	else:
		_stamp("NEITHER: no player and no reported failure -- the wait "
				+ "this harness exists to rule out")
	# THE FIRST ANSWER, BEFORE ANY RECOVERY. A Zone that is accepted on
	# its first submission and a Zone that is accepted on its third are
	# different results, and only one of them is "this proposal lays
	# out".
	if built:
		var served: Dictionary = main.zone.zone
		print("  SERVED: '%s', %d room(s), %d edge(s)"
				% [str(served.get("display_name", "?")),
					(served.get("chambers", []) as Array).size(),
					(served.get("edges", []) as Array).size()])
	# THE ENGINE COULD NOT CONSTRUCT IT, which is none of the other
	# three things this report can say. Not a generation-stage refusal
	# (that one never reaches a client), not a layout refusal (that one
	# has geometry the bridge judged), and not a hang -- the whole point
	# is that it is SAID.
	if not failure.is_empty():
		print("  BUILD: the engine could not construct this proposal -- %s"
				% str(failure.get("reason", "(no reason)")))
		print("  REPORTED: build_failed for '%s', proposal %s, attempt %s"
				% [str(failure.get("zone_id", "?")),
					str(failure.get("proposal_id", "(none offered)")),
					str(failure.get("attempt", "(none offered)"))])
		_check(str(failure.get("zone_id", "")) == zone_id,
				"the failure was reported for the Zone that failed")
		_check(int(failure.get("attempt", -1)) == 0,
				"the failure was reported for the attempt it belongs to "
				+ "(%s)" % str(failure.get("attempt", "absent")))
		_check(main.zone == null,
				"the client did not enter a Zone it could not build")
	# A GENERATION-STAGE REFUSAL IS NOT A LAYOUT ONE, and reporting only
	# the layout verdict hides it. `generate_zone_validated` refuses a
	# proposal the validator rejects and the campaign composes again --
	# so a Zone can arrive ACCEPTED on its first LAYOUT while a proposal
	# was already refused before it. `layout_refusals` cannot see that;
	# `last_generation_error` is what says it happened.
	# `<null>` IS NOT A REASON. The field is nullable and `str(null)`
	# prints the engine's placeholder, which reads as a refusal nobody
	# made.
	var raw_why: Variant = BridgeClient.snapshot.get("last_generation_error")
	var why := str(raw_why) if raw_why is String else ""
	if why != "":
		print("  GENERATION: a proposal was refused before this one -- %s"
				% why)
	else:
		print("  GENERATION: no proposal was refused; this is the one "
				+ "the provider offered first")
	# NO VERDICT IS COMING FOR A BUILD THAT DID NOT HAPPEN, and waiting
	# thirty seconds for one is this harness reproducing the very hang
	# it is here to rule out. The engine's answer IS the first result.
	var first := "not built" if not built else str(main.zone.layout_verdict)
	if not failure.is_empty():
		first = "BUILD FAILED (no layout was submitted, so there is no "
		first += "verdict to wait for)"
	else:
		await _await("a first verdict",
				func() -> bool:
					return main.zone != null \
							and main.zone.layout_verdict != "", 30.0)
		if main.zone != null:
			first = str(main.zone.layout_verdict)
	print("  FIRST RESULT: %s" % (first if first != "" else "no verdict"))

	# THEN THE BOUNDED RECOVERY, WATCHED RATHER THAN ASSUMED. A refusal
	# sends the Zone back to be composed again; the budget stops it.
	var spent := 0
	var ended := ""
	var tries := 1
	var charged := 0
	for _i in 60:
		var rec: Dictionary = BridgeClient.active_zone()
		var mine := str(rec.get("zone_id", "")) == zone_id
		if mine:
			spent = maxi(spent, int(rec.get("layout_refusals", 0)))
			# THE BRIDGE ACTED ON IT. The count is the record moving,
			# which is the only proof from this side that the message
			# arrived and was charged to this Zone rather than dropped.
			if spent > charged:
				charged = spent
				# The budget itself is the bridge's and is not exported
				# to GDScript, so this reports the charge and lets the
				# bridge's own `layout_exhausted` say when it is spent
				# rather than counting to a number copied over here.
				_stamp("bridge charged attempt %d to '%s'"
						% [charged, zone_id])
		if mine and str(rec.get("layout_state", "")) == "ACCEPTED":
			ended = "ACCEPTED"
			# A FIRST-ATTEMPT ACCEPTANCE IS NOT A RECOVERY, and calling
			# it one would turn the ordinary path into evidence for the
			# failure path.
			_stamp(("REPLACEMENT ACCEPTED and entered: the layout the "
					+ "client built on attempt %d was committed" % tries)
					if tries > 1 or not _build_failure_reported().is_empty()
					else "ACCEPTED and entered on the first attempt; "
					+ "nothing failed and nothing was recomposed")
			break
		# PARKED IS THE OTHER TERMINAL ANSWER, AND THE HUB IS WHERE IT
		# READS. A DORMANT Zone is not the active one -- the bridge
		# clears `active_zone_id` when it parks a Zone -- so
		# `active_zone()` goes empty for exactly the Zone whose outcome
		# is being watched. Measured: an exhausted Zone reported "STILL
		# PENDING" and "0 of 15 Check(s)" while the Hub was already
		# saying ZONE_FAILED, which is a report about where it looked.
		if (mine and (bool(rec.get("layout_exhausted", false))
					or str(rec.get("state", "")) == "DORMANT")) \
				or _parked(zone_id):
			ended = "EXHAUSTED"
			_stamp("EXHAUSTED: the Zone spent its budget and is parked; "
					+ "the Hub offers a discard rather than a way in")
			break
		# A FAILED BUILD PUTS THE PLAYER BACK IN THE HUB, and the
		# recomposed Zone waits there to be entered again. The ladder
		# only advances when someone walks into it, which is the
		# player's part -- so this sends the same intent the portal
		# sends rather than shortcutting past it. `_on_enter_zone`
		# refuses an exhausted Zone itself, so the budget still ends
		# this loop.
		if not _build_failure_reported().is_empty() \
				and main.zone == null \
				and BridgeClient.hub_mode() == "ZONE_READY":
			tries += 1
			_stamp("the recomposed Zone is offered again; entering it "
					+ "(attempt %d) the way the portal does" % tries)
			main._on_enter_zone()
		await get_tree().create_timer(0.5).timeout
	if ended == "":
		ended = "STILL PENDING after the watch window"
	# "AT LEAST", because the count rides on the ACTIVE Zone's record and
	# the charge that parks a Zone is the same act that stops it being
	# active. The last reading before it left the snapshot is therefore
	# one short of the budget, and saying "2 refusals spent" flat would
	# read as a budget that was never finished.
	print("  RECOVERY: %s%d refusal(s) seen over %d entry attempt(s); "
			% ["at least " if ended == "EXHAUSTED" else "",
				spent, tries] + "ended %s" % ended)

	# AND WHAT THE PLAYER IS LEFT WITH, either way.
	var hub := BridgeClient.hub_mode()
	var row: Dictionary = BridgeClient.hub()
	if _parked(zone_id):
		# THE CHECK COUNT IS NOT ON THE WIRE FOR A PARKED ZONE, and
		# printing a 0 read off an empty record would say the opposite
		# of the truth. What IS observable is the consequence of the
		# reservation still standing: the Hub names this Zone as the one
		# to discard, and refuses to start another over it -- which it
		# could only do if these Checks were still spoken for.
		print("  AFTER: hub %s; '%s' is parked, so its record is off the "
				% [hub, zone_id]
				+ "snapshot; the Hub names it as the discard target and "
				+ "refuses a new Zone over it, which is its %d Check(s) "
				% allocated + "still reserved; entered=false")
		_check(str(row.get("discard_zone_id", "")) == zone_id,
				"the Hub offers a way out of the Zone that cannot be built")
		_check(not bool(row.get("accepts_zone_request", true)),
				"the parked Zone still reserves its Checks -- a new Zone "
				+ "is refused over it")
	else:
		var after: Dictionary = BridgeClient.active_zone()
		var still := (after.get("allocated_location_ids", []) as Array).size()
		print("  AFTER: hub %s; the Zone holds %d of its %d Check(s); "
				% [hub, still, allocated]
				+ "entered=%s"
				% str(main.zone != null and main.zone.player != null))
		_check(still == allocated or ended == "ACCEPTED",
				"a refused Zone keeps every Check it was allocated (%d of "
				% still + "%d)" % allocated)
	_check(hub != "", "the Hub still reports a mode")
	_check(ended != "STILL PENDING after the watch window",
			"the Zone reached a terminal answer rather than leaving the "
			+ "client waiting (%s)" % ended)
	_stamp("final: hub %s; %s" % [hub,
			"parked, Checks still reserved" if _parked(zone_id)
			else "the Zone is the active one"])
	print("  TIMELINE:")
	for line: String in _timeline:
		print("    %s" % line)
	print("NAMED CASE %s: first=%s refusals=%d ended=%s"
			% [zone_id, first, spent, ended])
	_finish(0 if _failures == 0 else 1)


## Anything the driver has to hand the next process that the SAVE does
## not carry: which Zone, which lock, which key. Written beside the save
## rather than into it, because the save is the bridge's and this is the
## test's own bookkeeping.
func _notes_path() -> String:
	return "user://reload_notes.json"


func _write_notes(notes: Dictionary) -> void:
	var f := FileAccess.open(_notes_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(notes))
	f.close()


func _read_notes() -> Dictionary:
	if not FileAccess.file_exists(_notes_path()):
		return {}
	var raw := FileAccess.get_file_as_string(_notes_path())
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _await(what: String, predicate: Callable,
		seconds := 30.0) -> bool:
	var waited := 0.0
	while waited < seconds:
		if predicate.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(false, "timed out waiting for %s" % what)
	return false


## A Zone carrying a lock and its key, through the real intents.
##
## Same shape as `bridge/tests/test_amalgam_end_to_end._branching_zone`:
## a branch needs a Zone big enough to spare a room, so ask until one
## comes, and put the ones that do not back.
func _a_locked_zone() -> Dictionary:
	for _attempt in 4:
		BridgeClient.send_intent({"type": "request_next_zone",
				"finale": false})
		if not await _await("ZONE_READY",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_READY"):
			return {}
		var record := BridgeClient.active_zone()
		var zone: Dictionary = record.get("zone", {})
		for raw_chamber: Variant in zone.get("chambers", []):
			var chamber: Dictionary = raw_chamber
			for raw_door: Variant in chamber.get("doors", []):
				var door: Dictionary = raw_door
				if str(door.get("usage", "")) != "LOCKED":
					continue
				var edge_id := str(door.get("edge_id", ""))
				var branch := ""
				for raw_edge: Variant in zone.get("edges", []):
					var edge: Dictionary = raw_edge
					if str(edge.get("edge_id", "")) != edge_id:
						continue
					branch = str(edge["room_b"]) \
							if str(edge["room_a"]) == str(chamber["id"]) \
							else str(edge["room_a"])
				return {"record": record, "room": str(chamber.get("id", "")),
						"socket": str(door.get("socket_id", "")),
						"key": str(door.get("key_id", "")),
						"branch": branch}
		# Not this one. Put it back rather than playing it.
		var zid := str(record.get("zone_id", ""))
		BridgeClient.send_intent({"type": "enter_zone", "zone_id": zid})
		if not await _await("ZONE_ACTIVE before abandoning",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
			return {}
		BridgeClient.send_intent({"type": "abandon_zone", "zone_id": zid})
		if not await _await("the Zone is put back",
				func() -> bool:
					return BridgeClient.active_zone().is_empty()):
			return {}
	_check(false, "no Zone with a lock in four attempts")
	return {}


func _record() -> void:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("a campaign",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN"):
		_finish(1)
		return
	var found := await _a_locked_zone()
	if found.is_empty():
		_finish(1)
		return
	var record: Dictionary = found["record"]
	var zone_id := str(record.get("zone_id", ""))

	# THE REAL ENTRY PATH. `_on_enter_zone` sends the intent; the
	# snapshot handler builds the Zone. Nothing here constructs a
	# `ZoneController`.
	main._on_enter_zone()
	if not await _await("Main builds the Zone",
			func() -> bool:
				return main.zone != null and main.zone.player != null,
			40.0):
		_finish(1)
		return
	# WHICH PHASE FAILED, NAMED. "timed out waiting for the bridge
	# accepts the layout" is the same sentence whether a FRESH Zone
	# could not be built and accepted or an existing MANIFEST could not
	# be laid back down, and those are different repairs in different
	# lanes. This is the first: a fresh proposal, initial acceptance.
	if not await _await("PHASE 1 (initial build + acceptance): the "
				+ "bridge accepts the freshly composed layout",
			func() -> bool: return main.zone.layout_verdict == "ACCEPTED",
			20.0):
		print("  PHASE 1 FAILED -- a fresh proposal was not accepted. "
				+ "Nothing about manifest reconstruction is measured by "
				+ "this run.")
		_say_why(main.zone as ZoneController)
		_finish(1)
		return
	print("  PHASE 1 OK -- a fresh proposal was built and accepted")
	var zone := main.zone as ZoneController

	# COLLECT THE KEY AND OPEN THE LOCK, on the real objects. The walk
	# itself is proved by the branch-journey test in the room-contract
	# suite; what this run is about is what survives the process, so it
	# drives the same collect and the same open the body would and lets
	# the same intents go.
	var key_id := str(found["key"])
	for node: Node in _find_all(zone, "ZoneKey"):
		var key := node as ZoneKey
		if key == null or key.key_id != key_id:
			continue
		zone.player.global_position = key.global_position + Vector3.UP * 1.2
		for _i in 10:
			await get_tree().physics_frame
	_check(zone.keys_held().has(key_id),
			"the key '%s' was collected in the first process" % key_id)
	# The key alone opens its lock -- `_open_what_the_keys_allow` runs on
	# every collection -- so this asserts rather than arranges.
	var opened := "%s/%s" % [str(found["room"]), str(found["socket"])]
	_check(zone.locks_opened().has(opened),
			"collecting the key opened '%s'" % opened)
	# A STATION TOO, so the resume anchor has something to be.
	var station_id := ""
	for node: Node in _find_all(zone, "WarpStation"):
		var station := node as WarpStation
		if station == null:
			continue
		zone.player.global_position = station.global_position \
				+ Vector3.UP * 1.2
		for _i in 10:
			await get_tree().physics_frame
		if zone.stations_reached().has(station.station_id):
			station_id = station.station_id
			break

	# LEAVE THE WAY THE GAME LEAVES, so the bridge writes the save.
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": zone_id})
	if not await _await("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty()):
		_finish(1)
		return
	_write_notes({"zone_id": zone_id, "key": key_id, "lock": opened,
			"room": str(found["room"]), "socket": str(found["socket"]),
			"branch": str(found["branch"]), "station": station_id})
	print("recorded: zone %s, key %s, lock %s, station %s"
			% [zone_id, key_id, opened, station_id])
	_finish(0)


func _resume() -> void:
	var notes := _read_notes()
	_check(not notes.is_empty(),
			"the first process left its notes behind")
	if notes.is_empty():
		_finish(1)
		return
	var zone_id := str(notes["zone_id"])
	# THE BRIDGE RESTARTED TOO, so the campaign is not in anybody's
	# memory. It used to stay up across the two processes and "the
	# campaign loads from disk" meant the CLIENT loading from a bridge
	# that still had everything. Both sides are new now, and the only
	# thing that crossed is the file in `ARCHIPEPSI_SAVE_DIR` -- so this
	# process does what a freshly launched client does: it connects, and
	# the bridge loads the slot's save rather than creating one.
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await("the campaign loads from disk",
			func() -> bool:
				return BridgeClient.hub_mode() != "NO_CAMPAIGN", 30.0):
		_finish(1)
		return
	# AND IT IS THE SAVED ONE, not a fresh campaign under the same name.
	# A `start_mock_campaign` that created rather than loaded would put
	# this process in a brand new campaign that has never heard of the
	# Zone the first one recorded -- which would pass every assertion
	# below about "nothing is remembered" and none of the ones about what
	# came back.
	#
	# Asked of the HUB, not of `active_zone`: a Zone walked out of is
	# dormant, and a dormant Zone is deliberately not the active one.
	# `resume_zone_id` is the bridge naming the Zone the portal leads to,
	# which is the only thing that can name it before the portal is
	# pressed.
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == zone_id,
			"the restarted bridge loaded the save holding %s rather "
			% zone_id + "than creating a new campaign; the Hub offers "
			+ "'%s'" % str(BridgeClient.hub().get("resume_zone_id", "")))

	# THE SAVE IS THE ONLY THING THAT CROSSED. Nothing in this process
	# has ever seen this Zone, so `Main`'s in-memory dictionaries are
	# empty by construction and whatever comes back came from the bridge.
	_check(main._zone_keys.is_empty() and main._zone_locks_open.is_empty()
				and main._zone_resume.is_empty(),
			"this process remembers nothing of its own about any Zone")

	# RE-ENTRY IS THE PORTAL, pressed.
	#
	# This used to set `main._entering_zone` and send the `enter_zone`
	# intent itself, because `_on_enter_zone` read the ACTIVE Zone to
	# find its id and a dormant Zone is not the active one -- the Hub had
	# no affordance for going back to a Zone you walked out of. That gap
	# is closed: the bridge carries `resume_zone_id` and the mode
	# `ZONE_DORMANT`, the Hub's portal branch accepts it, and
	# `_on_enter_zone` reads it. So the driver presses the portal and
	# every step after it -- which id, which intent, which handler --
	# belongs to the shipping path.
	var offered := func() -> bool:
		var standing := main.hub as HubController
		if standing == null or standing.portal() == null:
			return false
		return standing.portal().interact_prompt() != ""
	if not await _await("the Hub offers the way back", offered, 30.0):
		_finish(1)
		return
	var portal: HubController.HubPortal = \
			(main.hub as HubController).portal()
	print("portal: mode %s, prompt '%s'"
			% [BridgeClient.hub_mode(), portal.interact_prompt()])
	_check(BridgeClient.hub_mode() in HubController.ZONE_ENTERABLE_MODES,
			"the Hub is in a mode the portal can enter a Zone from (%s)"
			% BridgeClient.hub_mode())
	var searches_before := ZoneBuilder.searches
	portal.interact(main)
	_check(main._entering_zone,
			"pressing the portal put Main into its entry path")
	if not await _await("ZONE_ACTIVE",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		_finish(1)
		return
	_check(str(BridgeClient.active_zone().get("zone_id", "")) == zone_id,
			"the portal led back into %s, and it led into '%s'"
			% [zone_id, str(BridgeClient.active_zone().get(
				"zone_id", ""))])
	var record := _record_for(zone_id)
	_check(not record.is_empty(),
			"the reloaded campaign still holds %s" % zone_id)
	var progress: Dictionary = record.get("progress", {})
	_check((progress.get("collected_keys", []) as Array)
				.has(str(notes["key"])),
			"the save carries the key '%s'" % str(notes["key"]))
	_check((progress.get("opened_locks", []) as Array)
				.has(str(notes["lock"])),
			"the save carries the opened lock '%s'" % str(notes["lock"]))
	_check(typeof(record.get("manifest")) == TYPE_DICTIONARY
				and not (record["manifest"] as Dictionary).is_empty(),
			"the save carries the committed layout")
	if not await _await("Main rebuilds the Zone",
			func() -> bool:
				return main.zone != null and main.zone.player != null, 40.0):
		_finish(1)
		return
	var zone := main.zone as ZoneController
	_check(ZoneBuilder.searches == searches_before,
			"the Zone was REPLAYED from its manifest: %d route search(es) "
			% (ZoneBuilder.searches - searches_before)
			+ "ran, and a committed layout is rebuilt rather than solved")
	if not await _await("PHASE 2 (reconstruction of an existing "
				+ "manifest): the replayed layout is accepted",
			func() -> bool: return zone.layout_verdict == "ACCEPTED", 20.0):
		print("  PHASE 2 FAILED -- the committed manifest could not be "
				+ "laid back down and accepted. Phase 1 passed, so a "
				+ "fresh proposal is fine and reconstruction is not.")
		_say_why(zone)
		_finish(1)
		return

	# 1. THE PROGRESS CAME BACK, from the bridge and from nowhere else.
	_check(zone.keys_held().has(str(notes["key"])),
			"the player still holds the key they collected last time")
	_check(zone.locks_opened().has(str(notes["lock"])),
			"the lock they opened last time is open")
	if str(notes["station"]) != "":
		_check(zone.stations_reached().has(str(notes["station"])),
				"the station they reached last time is online")

	# 2. AND THE KEY IS NOT THERE TO COLLECT AGAIN. A resume that
	#    respawned it would read as "progress restored" on every counter
	#    above and still hand the player a second copy.
	var loose := 0
	for node: Node in _find_all(zone, "ZoneKey"):
		var key := node as ZoneKey
		if key != null and key.key_id == str(notes["key"]):
			loose += 1
	_check(loose == 0,
			"%d copies of the collected key were rebuilt" % loose)

	# 3. AND THE DOORWAY IS OPEN, with no slab left standing in it.
	#    `LockedDoor.open()` frees the node, so "already opened" is the
	#    absence of one -- and a resume that rebuilt the slab would show
	#    up here and nowhere else.
	var standing := 0
	for node: Node in _find_all(zone, "LockedDoor"):
		var candidate := node as LockedDoor
		if candidate == null:
			continue
		if "%s/%s" % [candidate.room_id, candidate.socket_id] \
				== str(notes["lock"]):
			standing += 1
	_check(standing == 0,
			"%d slab(s) were rebuilt in a doorway the player opened"
			% standing)

	# 4. AND THE PLAYER WALKS THROUGH IT, on foot, with no offers and no
	#    teleport. The two rooms the lock joins are in the manifest; the
	#    walk is from the junction's arrival to the branch room's.
	var from_at: Vector3 = zone._zone_anchors.get(
			"room:%s:arrival" % str(notes["room"]), Vector3.INF)
	var to_at: Vector3 = zone._zone_anchors.get(
			"room:%s:arrival" % str(notes["branch"]), Vector3.INF)
	_check(from_at != Vector3.INF and to_at != Vector3.INF,
			"the manifest carries both rooms' arrivals")
	if from_at == Vector3.INF or to_at == Vector3.INF:
		_finish(1)
		return
	var box: AABB = zone.room_bounds.get(str(notes["branch"]), AABB())
	zone.player.global_position = from_at + Vector3.UP * 0.6
	for _i in 12:
		await get_tree().physics_frame
	# THROUGH THE DOORWAY, not through the wall beside it.
	#
	# This walked a straight line from one arrival to the other, and the
	# two rooms are joined by a door in a wall: the line crosses that
	# wall everywhere except at the opening. PHASE 2 could not run until
	# the socket capacity was corrected, so the leg ran for the first
	# time and the body got to 11.6 m and stopped -- against the wall,
	# which is exactly where a straight line puts it.
	#
	# So the door is a WAYPOINT, the way `graph_driver._walk_into` has
	# always treated it. The claim is unchanged and is still walked on
	# foot: the doorway the key opened is passable.
	var mouth := _doorway_in_world(zone, str(notes["lock"]))
	if mouth != Vector3.INF:
		await _walk(zone.player, mouth)
		# AND THROUGH IT. Steering AT the opening puts a capsule against
		# the frame -- measured, wedged 0.75 m short of the near wall
		# with the doorway as the goal. The second waypoint is a few
		# metres INSIDE, along the line from the opening to the middle
		# of the room it opens onto, so the body is aimed through the
		# gap rather than at it.
		if box.has_volume():
			var inward := (box.position + box.size / 2.0) - mouth
			inward.y = 0.0
			if inward.length() > 0.01:
				await _walk(zone.player,
						mouth + inward.normalized() * 3.5, box)
	var walk := await _walk(zone.player, to_at, box)
	# INSIDE THE ROOM, not within a metre of a point in it.
	#
	# The walk crosses a doorway, a connector and a turn, and a straight
	# line at the far room's arrival is not how anyone walks that -- a
	# body pressed against the last crate before the goal has still gone
	# through the door, which is the claim. So the test asks the
	# question the claim is made of: is the player in the branch room?
	var at: Vector3 = walk["at"]
	_check(box.has_volume() and box.grow(0.5).has_point(at),
			"the player walked from '%s' through the doorway they had "
			% str(notes["room"]) + "already opened and into '%s': they "
			% str(notes["branch"]) + "are at %s and it is %s (%d frames, "
			% [str(at), str(box), int(walk["frames"])]
			+ "%.1f m from its arrival)" % float(walk["closest"]))
	_finish(0)


## Every node of one class under `root`, by class name rather than by a
## group, because a key and a lock declare neither.
func _find_all(root: Node, class_wanted: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.get_script() != null \
			and (root.get_script() as GDScript).get_global_name() \
				== class_wanted:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_find_all(child, class_wanted))
	return out


## One Zone's record out of the snapshot.
##
## Only the ACTIVE Zone is on the wire -- a snapshot carries no list of
## dormant records -- which is why the resume asks for this AFTER the
## `enter_zone` intent rather than before.
func _record_for(zone_id: String) -> Dictionary:
	var active := BridgeClient.active_zone()
	return active if str(active.get("zone_id", "")) == zone_id else {}


## `stop_inside` ENDS THE WALK THE MOMENT IT SUCCEEDS.
##
## A branch room carries a return plug, and a plug sends the player home
## from the dead end they just walked into -- while the finger is still
## on the key. Without this the walk kept going from the Zone start and
## reported a position twelve rooms away as where the walk ended.
## Where a `room/socket` doorway stands, in world space.
##
## Off the room's OWN door plan -- the same `doors` array the aperture
## probe measures -- so the waypoint is the opening the engine built and
## not a second derivation of where one ought to be.
func _doorway_in_world(zone: ZoneController, lock_id: String) -> Vector3:
	var parts := lock_id.split("/")
	if parts.size() != 2:
		return Vector3.INF
	for raw: Variant in zone.offer_rooms:
		var entry: Dictionary = raw
		if str((entry["chamber"] as Dictionary).get("id", "")) != parts[0]:
			continue
		for raw_door: Variant in (entry["build"] as Dictionary) \
				.get("doors", []):
			var door: Dictionary = raw_door
			if str(door.get("socket_id", "")) == parts[1]:
				return (entry["xform"] as Transform3D) \
						* (door.get("position", Vector3.ZERO) as Vector3)
	return Vector3.INF


func _walk(player: Player, goal: Vector3,
		stop_inside := AABB()) -> Dictionary:
	var closest := INF
	var still := 0
	var last := player.global_position
	Input.action_press("move_forward", 1.0)
	var used := 0
	var ended := player.global_position
	for i in WALK_FRAMES:
		used = i + 1
		var here := player.global_position
		ended = here
		if stop_inside.has_volume() and stop_inside.grow(0.5).has_point(here):
			break
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		closest = minf(closest, flat.length())
		if flat.length() <= ARRIVED:
			break
		player.rotation.y = atan2(-flat.x, -flat.y)
		# A BODY PRESSED AGAINST SOMETHING TRIES TO CLIMB IT, which is
		# what `graph_driver._walk` has always done and this walker
		# never learned. PHASE 2 could not run until the socket capacity
		# was corrected, so this leg ran for the first time and ended
		# 11.6 m short after 202 frames -- wedged, not out of budget
		# (`WALK_FRAMES` is 900). The claim under test is that the
		# doorway the key opened is passable; how a harness gets a
		# capsule over a crate on the way is not part of it.
		still = still + 1 if (here - last).length() < 0.012 else 0
		if still == 24 and player.is_on_floor():
			Input.action_press("jump", 1.0)
			await get_tree().physics_frame
			Input.action_release("jump")
			still = 0
		last = here
		if still > 90:
			break
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return {"arrived": Vector2(goal.x - ended.x, goal.z - ended.z).length()
				<= ARRIVED,
			"at": ended, "frames": used, "closest": closest}
