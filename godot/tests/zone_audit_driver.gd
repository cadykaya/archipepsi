extends Node
## The real-Zone activity audit (`make godot-zone-audit`).
##
## WHY THIS EXISTS. `activity_driver.gd` calls `Activities.build` itself.
## That suite was green while the game built ZERO activities in ZERO
## rooms, because `build_chamber` returned before the loop on every route
## the registry actually takes. It proved the runtime works and nothing
## about whether anything reaches it.
##
## So nothing here constructs an activity. It loads the JSON of the Zone
## a baseline playtest actually walks -- written by
## `python -m archipepsi_bridge.playtest dump`, so it is the same Zone
## with the same digest, not a fixture that resembles one -- hands it to
## `ZoneBuilder.build`, and then measures what came out with physics.
##
## AUDIT, not gameplay. It changes nothing and asserts only about the
## assembled scene.

const ZONE_JSON := "res://tests/fixtures/played_zone.json"
const AUDIT_OUT := "user://zone_activity_audit.json"

## Where a player's chest is ABOVE THE WALKABLE PLANE.
##
## Not above the AABB. A chamber's bounds start `FLOOR_ALLOWANCE` BELOW
## the floor, to hold the slab -- so `bounds.position.y + EYE` is 20 cm
## off the ground, and for a `platform_path` (whose bounds reach 40 m
## down) it is deep underground. The first version of this probe did
## exactly that and reported most of the Zone unreachable, which is the
## same mistake a wall probe in this project made once before: measuring
## from the bottom of the box instead of from the floor.
const EYE := 1.2
const FLOOR_ALLOWANCE := 1.0
## How far outside a chamber's own AABB an element may sit before it is
## in another room's geometry rather than this one's.
const BOUNDS_SLACK := 0.05

var failures := 0
## Placement findings. Recorded and printed, but they do not fail the
## run: they are KNOWN OPEN DEFECTS as of this audit
## (`docs/ZONE_ACTIVITY_AUDIT.md`), and a target that goes red on a
## defect somebody has already written down and decided not to fix
## tonight is a target people learn to ignore.
##
## What DOES fail: structure. A declared activity with no runtime, a
## runtime with the wrong element count, a kind that cannot be completed
## in the assembled Zone, a declared elevation band that is not there,
## and an element with NOTHING UNDER IT. Those are the claims this
## apparatus exists to make, and none of them may quietly stop being
## true. The last one was a note until the defect behind it was fixed;
## the whole point of writing a defect down is being able to promote its
## check the day it is closed.
var notes := 0
var audited := 0
var rows: Array = []
## Every collider belonging to any activity in the Zone, so a
## reachability ray can be asked about the LEVEL alone.
var _all_activity_rids: Array[RID] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

## A placement finding: printed, counted, and not fatal.
func _note(condition: bool, message: String) -> void:
	if not condition:
		notes += 1
		print("  NOTE: " + message)

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame
	BridgeClient.snapshot = {
		"type": "campaign_snapshot",
		"mechanics": {"owned": [], "aliases": [], "links": [],
				"statuses": [], "resources": []},
		"slots": {}, "local_rewards": [],
		"available_capabilities": ["ranged_hit"],
		"coins_received": 0, "coins_spent": 0, "hub": {"state": "IDLE"},
	}

	await _the_placement_outcomes_are_distinguishable()
	await _a_corridor_is_searched_down_its_length()
	await _a_side_door_the_composer_assigned_is_a_hole()
	await _the_return_never_stands_between_arrival_and_content()
	await _a_room_names_only_the_openings_it_builds()

	var zone := _load_zone()
	if zone.is_empty():
		_check(false, "could not load %s -- run `playtest dump` first"
				% ZONE_JSON)
		_finish()
		return

	var declared := _declared_activities(zone)
	print("  Zone %s: %d chambers, %d activities declared"
			% [zone.get("zone_id", "?"), (zone["chambers"] as Array).size(),
			declared.size()])

	var build := ZoneBuilder.build(zone)
	# A ROUTING FAILURE IS A RESULT, and it is this suite's business:
	# the alternative `ZoneBuilder` used to offer was a room attached on
	# top of another one, which is what the Check-in-a-wall failures
	# were. Reported here rather than walked past, because reading
	# `build["root"]` off a failure is a script error and a hung run.
	if build.has("failed"):
		_check(false, "the Zone could not be laid out: %s"
				% str(build["failed"]))
		_finish()
		return
	var root: Node3D = build["root"]
	add_child(root)
	# Two physics frames so every Area3D has registered its overlaps and
	# every static body is in the space before anything is queried.
	await get_tree().physics_frame
	await get_tree().physics_frame

	_audit(build, declared)
	await _drive_one_of_every_kind(build)

	root.queue_free()
	await get_tree().process_frame
	_finish()

## THE FOUR PLACEMENT OUTCOMES, DRIVEN.
##
## A room was being barred from branch selection on `plug_clear ==
## false`, and that boolean cannot tell "nothing was measured" from
## "this position is bad" from "no position works". Each control here
## builds a real Zone, puts the return anchor in one of those states,
## and asserts which outcome the engine reports -- because only
## `NO_CANDIDATE` may justify reselecting the host.
func _the_placement_outcomes_are_distinguishable() -> void:
	# WHY THE HOST ROOM IS `c005` AND THE PLUG IS `p:c005:start`.
	#
	# `topology.compose_with_branch` names a return plug
	# `p:<room>:start`, sources it at `room:<room>:return` and sends it
	# to `zone_start`; on a six-chamber Zone the branch lands on `c005`.
	# So the payloads this suite writes out key their placement report
	# under the SAME edge id a production Zone's plug carries, and
	# `bridge/tests/test_placement_contract.py` drops the engine's own
	# dictionary onto that Zone's layout WITHOUT renaming a thing. A
	# fixture whose key had to be rewritten on the way in would prove
	# the wire identity holds by repairing it.
	var zone := {
		"zone_id": "zplace", "theme": "concrete_facility",
		"chambers": [
			{"id": "c004", "type": "corridor", "length": 14.0,
					"width": 7.9, "enemies": [], "activities": [],
					"features": []},
			{"id": "c005", "type": "arena", "width": 18.0, "depth": 18.0,
					"wall_height": 6.0, "objective": "reach_exit",
					"enemies": [], "activities": [], "features": []},
		],
		"plugs": [{"edge_id": "p:c005:start", "room_id": "c005",
				"source_anchor": "room:c005:return",
				"destination": "zone_start", "device": "pad"}],
	}

	# 1. A GOOD HOST IS LEFT ALONE. The builder reserved a spot that
	#    supports a body and clears the arrival, so nothing moves.
	var good := ZoneBuilder.build(zone)
	if good.has("failed"):
		_check(false, "the placement fixture did not lay out: %s"
				% str(good["failed"]))
		return
	add_child(good["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var was: Vector3 = (good["anchors"] as Dictionary)["room:c005:return"]
	var evidence := RoomAudit.measure_layout(good, space)
	var seen: Dictionary = evidence["plug_placement"]
	var good_told: Dictionary = seen.get("p:c005:start", {})
	_check(str(good_told.get("outcome", "")) == RoomAudit.PLACEMENT_PLACED
				and not bool(good_told.get("repaired", true)),
			"a good host reports PLACED, unrepaired, keyed by its EDGE "
			+ "(%s)" % str(good_told))
	_check((good["anchors"] as Dictionary)["room:c005:return"] == was,
			"and its anchor is where the builder put it")
	_check(bool((evidence["plug_clear"] as Dictionary).get(
				"p:c005:start", false)),
			"and a body at its arrival stands outside the device")

	# 2. A STANDABLE PAD TOO CLOSE TO THE ARRIVAL IS REPAIRED, NOT
	#    CONDEMNED. This is the case that used to bar the room: the
	#    settle skipped its search whenever the anchor was standable, so
	#    a pad on solid ground inside its own trigger stayed there and
	#    reported `plug_clear = false`.
	var arrival: Vector3 = (good["rooms"] as Dictionary)["c005"]["arrival"]
	(good["anchors"] as Dictionary)["room:c005:return"] = arrival \
			+ Vector3(0.5, 0.0, 0.5)
	var repaired := RoomAudit.measure_layout(good, space)
	var fixed: Dictionary = (repaired["plug_placement"] as Dictionary) \
			.get("p:c005:start", {})
	_check(str(fixed.get("outcome", "")) == RoomAudit.PLACEMENT_PLACED
				and bool(fixed.get("repaired", false)),
			"a standable pad inside the arrival's clearance is PLACED "
			+ "after repair rather than barred (%s)" % str(fixed))
	_check(bool((repaired["plug_clear"] as Dictionary).get(
				"p:c005:start", false)),
			"and the repaired position clears the arrival")
	_check(int(fixed.get("searched", 0)) > 0
				and int(fixed.get("probed", 0)) > 0,
			"and it says how much of the bounded search ran -- "
			+ "candidates enumerated AND positions put to the world, "
			+ "which are different numbers (%s)" % str(fixed))
	good["plug_clear"] = repaired["plug_clear"]
	good["plug_placement"] = repaired["plug_placement"]
	var repaired_wire := ZoneBuilder.layout_to_json(good)

	# 3. NO ARRIVAL TO MEASURE AGAINST IS NOT A VERDICT ON THE ROOM.
	var blind := (good["rooms"] as Dictionary)["c005"] as Dictionary
	var kept: Vector3 = blind["arrival"]
	blind.erase("arrival")
	(good["anchors"] as Dictionary).erase("room:c005:arrival")
	var nothing := RoomAudit.measure_layout(good, space)
	var unmeasured: Dictionary = (nothing["plug_placement"] as Dictionary) \
			.get("p:c005:start", {})
	_check(str(unmeasured.get("outcome", ""))
				== RoomAudit.PLACEMENT_NO_EVIDENCE,
			"a room with no published arrival reports NO_EVIDENCE -- "
			+ "the engine measured nothing and SAYS so. Silence is "
			+ "reserved for a payload that predates the field, and an "
			+ "engine that speaks this contract must not describe "
			+ "itself as one that does not (%s)" % str(unmeasured))
	_check(not (nothing["plug_clear"] as Dictionary).has("p:c005:start"),
			"and its clearance is ABSENT rather than false: missing "
			+ "evidence must not read as a measured failure")
	_check(int(unmeasured.get("searched", -1)) == 0,
			"and it claims no search, because there was nothing to "
			+ "search against (%s)" % str(unmeasured))
	good["plug_clear"] = nothing["plug_clear"]
	good["plug_placement"] = nothing["plug_placement"]
	var no_evidence_wire := ZoneBuilder.layout_to_json(good)
	blind["arrival"] = kept
	(good["anchors"] as Dictionary)["room:c005:arrival"] = kept

	# 4. AND A SEARCH THAT REALLY FINDS NOTHING SAYS SO -- on the room
	#    that actually produces it rather than a contrived arrival.
	#    `platform_path` is rising islands and two narrow ledges over a
	#    kill pit; `played_zone`'s `c012` is one, and no position in it
	#    both holds a capsule and clears the arrival. That is the ONE
	#    outcome Dess may reselect a host on, so it is measured on the
	#    real thing.
	(good["root"] as Node3D).queue_free()
	await get_tree().process_frame
	var pit_zone := {
		"zone_id": "zpit", "theme": "concrete_facility",
		"chambers": [
			{"id": "c004", "type": "corridor", "length": 14.0,
					"width": 7.9, "enemies": [], "activities": [],
					"features": []},
			{"id": "c005", "type": "platform_path", "enemies": [],
					"activities": [], "features": []},
		],
		"plugs": [{"edge_id": "p:c005:start", "room_id": "c005",
				"source_anchor": "room:c005:return",
				"destination": "zone_start", "device": "pad"}],
	}
	var pit := ZoneBuilder.build(pit_zone)
	if pit.has("failed"):
		_check(false, "the pit fixture did not lay out: %s"
				% str(pit["failed"]))
		return
	add_child(pit["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var empty := RoomAudit.measure_layout(pit,
			get_viewport().world_3d.direct_space_state)
	# THE COPY THE CONTROLLER MAKES, made here too. `measure_layout`
	# returns the evidence; `_measure_layout_evidence` is what puts it
	# ON the build, and `layout_to_json` reads it from there. A harness
	# that measures and serializes without that step sends an empty
	# `plug_placement` and would have proved the opposite of what it set
	# out to -- which is exactly what this assertion caught.
	pit["plug_clear"] = empty["plug_clear"]
	pit["plug_placement"] = empty["plug_placement"]
	var good_wire := ZoneBuilder.layout_to_json(pit)
	var pit_seen: Dictionary = (empty["plug_placement"] as Dictionary) \
			.get("p:c005:start", {})
	# AND THE PIT ROOM CAN HOST ONE. `c012` refused its layout for
	# months of this batch, which made "a room over a kill pit cannot
	# host a return" an easy and WRONG generalisation: the room declares
	# which square metres hold weight, and its end ledge holds a device
	# as well as it holds a player. The finding was about one position,
	# not one kind of room.
	_check(str(pit_seen.get("outcome", "")) == RoomAudit.PLACEMENT_PLACED,
			"a room over a kill pit CAN host a return -- its declared "
			+ "ground is real ground (%s)" % str(pit_seen))
	_check(bool((empty["plug_clear"] as Dictionary).get(
				"p:c005:start", false)),
			"and a body at its arrival stands outside that device")

	# 4b. AND WHEN THERE REALLY IS NO GROUND, the report says so and
	#     says what it looked at. Constructed rather than found, because
	#     no shipping builder produces it any more: the room's declared
	#     stands are taken away and its published arrival lifted clear of
	#     the geometry, so every candidate the bounded search examines is
	#     in the air.
	for raw: Variant in pit.get("chambers", []):
		var entry: Dictionary = raw
		if str((entry["chamber"] as Dictionary).get("id", "")) != "c005":
			continue
		(entry["build"] as Dictionary)["sockets"] = []
	var lifted: Vector3 = (pit["anchors"] as Dictionary)[
			"room:c005:arrival"] + Vector3(0.0, 60.0, 0.0)
	(pit["anchors"] as Dictionary)["room:c005:arrival"] = lifted
	(pit["anchors"] as Dictionary)["room:c005:return"] = lifted
	var box: AABB = (pit["rooms"] as Dictionary)["c005"]["bounds"]
	(pit["rooms"] as Dictionary)["c005"]["bounds"] = AABB(
			box.position + Vector3(0.0, 60.0, 0.0), box.size)
	var none := RoomAudit.measure_layout(pit,
			get_viewport().world_3d.direct_space_state)
	var barren: Dictionary = (none["plug_placement"] as Dictionary) \
			.get("p:c005:start", {})
	_check(str(barren.get("outcome", ""))
				== RoomAudit.PLACEMENT_NO_CANDIDATE,
			"a room with no supported ground reports NO_CANDIDATE, "
			+ "which is the only outcome that may bar the host (%s)"
			% str(barren))
	_check(barren.has("policy") and int(barren.get("searched", -1)) > 0
				and int(barren.get("probed", -1)) > 0,
			"and it states the bounded search it actually ran rather "
			+ "than claiming impossibility (%s)" % str(barren))
	pit["plug_clear"] = none["plug_clear"]
	pit["plug_placement"] = none["plug_placement"]
	var barren_wire := ZoneBuilder.layout_to_json(pit)

	# 4c. AND A SEARCH THAT COULD NOT BE RUN IS NOT A VERDICT EITHER.
	#
	#     `NO_CANDIDATE` says the declared search finished and nothing
	#     held; it is the one outcome that bars a host, so it may only
	#     be said when the search it names actually ran. A room with no
	#     committed envelope has no lattice to bound -- there is nothing
	#     to search INSIDE -- so nothing was established about the room
	#     and the engine says `NO_EVIDENCE`: refuse this layout, do not
	#     condemn the room.
	#
	#     CONSTRUCTED, like 4b, and said so: no shipping builder emits a
	#     room without bounds. The branch exists so that the one outcome
	#     with teeth cannot be reached by an unrun search, and a branch
	#     with no control is a branch nobody has read.
	(pit["rooms"] as Dictionary)["c005"]["bounds"] = AABB(
			(box.position + Vector3(0.0, 60.0, 0.0)), Vector3.ZERO)
	var unrun := RoomAudit.measure_layout(pit,
			get_viewport().world_3d.direct_space_state)
	var rejected: Dictionary = (unrun["plug_placement"] as Dictionary) \
			.get("p:c005:start", {})
	_check(str(rejected.get("outcome", ""))
				== RoomAudit.PLACEMENT_NO_EVIDENCE,
			"a room with no committed envelope reports NO_EVIDENCE: "
			+ "the bounded search never ran, so nothing was "
			+ "established about the room and the one outcome that "
			+ "bars a host must not be said (%s)" % str(rejected))

	# 5. AND THE PAYLOAD THE BRIDGE ACTUALLY RECEIVES CARRIES IT.
	#
	# A field existing in `RoomAudit` proves nothing about the wire.
	# `layout_to_json` is the serializer, and this is where the two
	# vocabularies were: the producer wrote `MEASURED`/`REPAIRED`/
	# `NO_EVIDENCE` keyed by ROOM while `layout.py` read `PLACED`/
	# `CANDIDATE_REJECTED`/`NO_CANDIDATE` keyed by EDGE, so every
	# outcome this lane sent fell through the consumer's `if outcome not
	# in PLACEMENT_OUTCOMES` and every room looked like legacy absence.
	# A `NO_CANDIDATE` was ACCEPTED across that seam.
	# Written out for `bridge/tests/test_placement_contract.py`, which
	# runs the real validator over exactly these bytes.
	var wire := barren_wire
	_check((wire.get("plug_placement", {}) as Dictionary).has(
				"p:c005:start"),
			"the serialized layout carries the placement outcome under "
			+ "the EDGE id the validator iterates (%s)"
			% str((wire.get("plug_placement", {}) as Dictionary).keys()))
	for spelling: String in [RoomAudit.PLACEMENT_PLACED,
			RoomAudit.PLACEMENT_NO_EVIDENCE,
			RoomAudit.PLACEMENT_NO_CANDIDATE]:
		_check(spelling in ["PLACED", "NO_EVIDENCE", "NO_CANDIDATE"],
				"'%s' is spelled the way `layout.PLACEMENT_OUTCOMES` "
				% spelling + "spells it")
	_write_placement_payloads([
			{"file": "supported.json", "wire": good_wire, "zone": pit_zone,
				"outcome": "PLACED",
				"proposal": "a platform_path destination whose builder-"
					+ "reserved spot already supports a body and clears "
					+ "the arrival"},
			{"file": "repaired.json", "wire": repaired_wire, "zone": zone,
				"outcome": "PLACED",
				"proposal": "an arena destination whose return anchor is "
					+ "moved onto the arrival's own clearance, so the "
					+ "reserved spot is standable and unusable and the "
					+ "search must find another"},
			{"file": "no_evidence.json", "wire": no_evidence_wire,
				"zone": zone, "outcome": "NO_EVIDENCE",
				"proposal": "the same arena with its arrival anchor "
					+ "unpublished, so there is nothing to measure "
					+ "clearance against"},
			{"file": "exhausted.json", "wire": barren_wire, "zone": pit_zone,
				"outcome": "NO_CANDIDATE",
				"proposal": "the platform_path destination with its "
					+ "declared stands removed and its envelope lifted "
					+ "60 m, so every candidate the bounded search "
					+ "enumerates is over the void"}])
	(pit["root"] as Node3D).queue_free()
	await get_tree().process_frame

## THE ROOM SHAPE THE LATTICE COULD NOT SEE.
##
## `RETURN_OFFSETS` promises "a narrow room is served by its long axis".
## It was not: the inner loop offered `dx = 0` and the outer loop never
## offered `dz = 0`, so every candidate was at least 2.5 m off the
## arrival on BOTH axes -- and a corridor is 4 to 10 m wide, which
## `bounds.grow(-0.6)` takes down to 2.8 at the low end. Measured before
## the fix: a corridor 8 x 4, a vault and a shaft each reported
## `NO_CANDIDATE` with `tried: 0`. That is the one outcome that BARS a
## host, reported for three ordinary rooms with metres of clear floor
## down their length, on a search that never ran a single query.
##
## Both ends of the range are held here, because a fix that says
## "everything can host a return" is the opposite mistake.
func _a_corridor_is_searched_down_its_length() -> void:
	for probe: Dictionary in [
			{"length": 12.0, "width": 4.0, "hosts": true},
			{"length": 8.0, "width": 4.0, "hosts": true},
			# THE LEGAL MINIMUM, and it genuinely cannot. `Chamber`
			# allows `length >= 6`; `grow(-0.6)` leaves 4.8 m of it, so
			# no square metre is both 2.5 m from the arrival and 0.6 m
			# off a wall. A room this size is too small to be a
			# destination you can leave, which is a COMPOSITION answer
			# and the honest one -- not a search that gave up.
			{"length": 6.0, "width": 4.0, "hosts": false}]:
		var built := ZoneBuilder.build({
			"zone_id": "zlong", "theme": "concrete_facility",
			"chambers": [
				{"id": "c004", "type": "corridor", "length": 14.0,
						"width": 7.9, "enemies": [], "activities": [],
						"features": []},
				{"id": "c005", "type": "corridor",
						"length": probe["length"], "width": probe["width"],
						"enemies": [], "activities": [], "features": []},
			],
			"plugs": [{"edge_id": "p:c005:start", "room_id": "c005",
					"source_anchor": "room:c005:return",
					"destination": "zone_start", "device": "pad"}],
		})
		if built.has("failed"):
			_check(false, "the %.0f m corridor did not lay out: %s"
					% [float(probe["length"]), str(built["failed"])])
			continue
		add_child(built["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var got := RoomAudit.measure_layout(built,
				get_viewport().world_3d.direct_space_state)
		var told: Dictionary = (got["plug_placement"] as Dictionary) \
				.get("p:c005:start", {})
		var outcome := str(told.get("outcome", ""))
		if bool(probe["hosts"]):
			_check(outcome == RoomAudit.PLACEMENT_PLACED,
					"a %.0f x %.0f corridor hosts its return along its "
					% [float(probe["length"]), float(probe["width"])]
					+ "LONG axis -- the lattice must offer a candidate "
					+ "with no cross-room offset at all (%s)" % str(told))
			_check(bool((got["plug_clear"] as Dictionary).get(
						"p:c005:start", false)),
					"and a body at its arrival stands outside it")
		else:
			_check(outcome == RoomAudit.PLACEMENT_NO_CANDIDATE,
					"a %.0f x %.0f corridor is the legal minimum and "
					% [float(probe["length"]), float(probe["width"])]
					+ "has nowhere to put one (%s)" % str(told))
			# AND IT SAYS THE SEARCH RAN. `probed: 0` was the whole
			# tell for the defect above, and it is still 0 here -- no
			# candidate was inside the envelope to query. `searched` is
			# what separates "enumerated the lattice and none of it fits
			# this room" from "never enumerated anything".
			_check(int(told.get("searched", 0)) > 0
						and int(told.get("probed", -1)) == 0,
					"and it says how many candidates the bounded search "
					+ "enumerated, so a NO_CANDIDATE that examined "
					+ "nothing cannot pass for one that examined "
					+ "everything (%s)" % str(told))
		(built["root"] as Node3D).queue_free()
		await get_tree().process_frame

## The engine-produced payloads the bridge-side contract test reads.
##
## REGENERATED BY THIS SUITE, never hand-edited: they exist so the
## Python side validates bytes this engine actually emits rather than a
## dictionary somebody typed to match the prose.
func _write_placement_payloads(captures: Array) -> void:
	var dir := "res://tests/fixtures/placement"
	DirAccess.make_dir_recursive_absolute(dir)
	# WHERE EACH CAPTURE CAME FROM, beside the capture.
	#
	# A payload with no provenance is a payload nobody can re-derive or
	# argue with. `captures.json` carries, per file: the exact Zone
	# proposal handed to `ZoneBuilder.build`, the outcome it was
	# captured to demonstrate, the controller build that measured it,
	# the commit the tree was on, and the one command that regenerates
	# the lot. `ARCHIPEPSI_CAPTURE_COMMIT` is set by
	# `make godot-zone-audit`; an editor run leaves it unknown and says
	# so rather than inventing one.
	var index := {
		"reproduce": "make godot-zone-audit",
		"written_by": "godot/tests/zone_audit_driver.gd",
		"read_by": "bridge/tests/test_placement_contract.py",
		"controller_digest": ControllerDigest.digest(),
		"source_commit": _capture_commit(),
		"captures": [],
	}
	for raw: Variant in captures:
		var capture: Dictionary = raw
		var name := str(capture["file"])
		var file := FileAccess.open("%s/%s" % [dir, name],
				FileAccess.WRITE)
		if file == null:
			_check(false, "could not write the placement payload '%s'; "
					% name + "the bridge-side contract test reads bytes "
					+ "this suite produces, so failing to produce them "
					+ "leaves that test measuring a stale wire")
			continue
		file.store_string(JSON.stringify(capture["wire"], " "))
		file.close()
		(index["captures"] as Array).append({
			"file": name,
			"outcome": str(capture["outcome"]),
			"edge_id": "p:c005:start",
			"room_id": "c005",
			"proposal": str(capture["proposal"]),
			"zone": capture["zone"]})
	var manifest := FileAccess.open("%s/captures.json" % dir,
			FileAccess.WRITE)
	if manifest == null:
		_check(false, "could not write the capture manifest")
		return
	manifest.store_string(JSON.stringify(index, " "))
	manifest.close()

## The commit the tree was on when these bytes were measured, or an
## honest admission that nothing said.
func _capture_commit() -> String:
	var sha := OS.get_environment("ARCHIPEPSI_CAPTURE_COMMIT").strip_edges()
	return sha if sha != "" else "unknown (run `make godot-zone-audit`)"

func _finish() -> void:
	_write_audit()
	print("  %d activities audited, %d structural failures, %d placement "
			% [audited, failures, notes] + "notes")
	if failures == 0:
		print("GODOT ZONE AUDIT OK")
		get_tree().quit(0)
	else:
		print("GODOT ZONE AUDIT: %d failures" % failures)
		get_tree().quit(1)

# --- inputs --------------------------------------------------------------

func _load_zone() -> Dictionary:
	if not ResourceLoader.exists(ZONE_JSON) \
			and not FileAccess.file_exists(ZONE_JSON):
		return {}
	var text := FileAccess.get_file_as_string(ZONE_JSON)
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

## What the GENERATION DATA promises, before anything is built. The audit
## is a comparison against this, so "the game built what the Zone said"
## is a claim with two sides rather than a count of whatever appeared.
func _declared_activities(zone: Dictionary) -> Array:
	var out: Array = []
	var chambers: Array = zone["chambers"]
	for index in chambers.size():
		var chamber: Dictionary = chambers[index]
		var list: Array = chamber.get("activities", []) as Array
		for j in list.size():
			var activity: Dictionary = list[j]
			out.append({
				"room_index": index,
				"room_id": str(chamber.get("id", "")),
				"room_type": str(chamber.get("type", "")),
				"activity_id": "%s_%d" % [str(chamber.get("id", "")), j],
				"kind": str(activity.get("kind", "")),
				"element_count": int(activity.get("element_count", 1)),
				"time_limit": float(activity.get("time_limit", 0.0)),
				"ordered": bool(activity.get("ordered", false)),
				"requires": activity.get("requires", []),
			})
	return out

func _runtimes_under(node: Node, out: Array[ActivityRuntime]) -> void:
	if node is ActivityRuntime:
		out.append(node as ActivityRuntime)
	for child in node.get_children():
		_runtimes_under(child, out)

# --- the audit -----------------------------------------------------------

func _audit(build: Dictionary, declared: Array) -> void:
	var root: Node3D = build["root"]
	var found: Array[ActivityRuntime] = []
	_runtimes_under(root, found)

	_check(found.size() == declared.size(),
			"the Zone declares %d activities and the assembled scene "
			% declared.size() + "holds %d runtimes" % found.size())

	var by_id := {}
	for runtime in found:
		by_id[runtime.activity_id] = runtime

	# Chamber world bounds, so an element can be checked against the room
	# it belongs to rather than against the Zone.
	var room_bounds := {}
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var xform: Transform3D = entry["xform"]
		var local: AABB = (entry["build"] as Dictionary).get("bounds", AABB())
		room_bounds[str(chamber.get("id", ""))] = ZoneBuilder._world_aabb(
				local, xform.origin, xform.basis.get_euler().y)

	_all_activity_rids = []
	for runtime in found:
		for element in runtime.elements:
			_collect_rids(element, _all_activity_rids)

	var space := get_viewport().world_3d.direct_space_state
	for row: Dictionary in declared:
		var id: String = row["activity_id"]
		var runtime: ActivityRuntime = by_id.get(id)
		var record := row.duplicate()
		record["runtime_exists"] = runtime != null
		if runtime == null:
			_check(false, "activity '%s' (%s in room %s) is in the Zone "
					% [id, row["kind"], row["room_id"]]
					+ "data and has no runtime in the scene")
			rows.append(record)
			continue

		var expected: int = runtime.placed_count()
		record["elements_expected"] = expected
		record["elements_built"] = runtime.elements.size()
		_check(runtime.elements.size() == expected,
				"activity '%s' built %d of %d elements"
				% [id, runtime.elements.size(), expected])

		var bounds: AABB = room_bounds.get(row["room_id"], AABB())
		# Every activity element in the WHOLE Zone, so an overlap can be
		# attributed: sharing space with the level is one defect and
		# sharing it with another puzzle is a different one.
		var positions: Array = []
		var outside := 0
		var in_level := 0
		var in_other_activity := 0
		var unreachable := 0
		var no_ground := 0
		var blockers: Array = []
		for element in runtime.elements:
			var p := element.global_position
			positions.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01),
					snappedf(p.z, 0.01)])
			if not _inside(bounds, element):
				outside += 1
			var own: Array[RID] = []
			_collect_rids(element, own)
			for hit: Dictionary in _overlaps(space, element, own):
				if _is_activity_part(hit.get("collider")):
					in_other_activity += 1
				else:
					in_level += 1
			if not _has_ground(space, element, runtime):
				no_ground += 1
			if not _is_reachable(space, element, bounds, runtime):
				unreachable += 1
				var who := _blocker(space, element, bounds, runtime)
				if who != "" and not blockers.has(who):
					blockers.append(who)
		record["positions"] = positions
		record["outside_bounds"] = outside
		record["embedded_in_level"] = in_level
		record["overlapping_another_activity"] = in_other_activity
		record["unreachable"] = unreachable
		record["no_ground_under"] = no_ground
		record["blocked_by"] = blockers
		record["state"] = runtime.state

		_check(outside == 0,
				"activity '%s': %d element(s) sit outside the bounds of "
				% [id, outside] + "room '%s'" % row["room_id"])
		_note(in_level == 0,
				"activity '%s': %d element overlap(s) with wall, floor, "
				% [id, in_level] + "ceiling or prop geometry")
		_note(in_other_activity == 0,
				"activity '%s': %d element overlap(s) with ANOTHER "
				% [id, in_other_activity] + "activity's elements")
		# A FAILURE, not a note, and it earned the promotion. Twenty-three
		# elements across five `platform_path` rooms were standing on
		# nothing, because the row solver read the room's width and depth
		# and a `platform_path` has no floor across them -- its bounds
		# reach forty metres down into a kill pit. That is fixed: the
		# builder now DECLARES its walkable surfaces and the solver
		# places onto them. Nothing about an element hanging in a void is
		# ever acceptable, and this is the check that goes red if the
		# nominal-floor placement comes back.
		_check(no_ground == 0,
				"activity '%s': %d element(s) have nothing to stand on "
				% [id, no_ground] + "within reach below them")
		_note(unreachable == 0,
				"activity '%s': %d element(s) cannot be seen from the "
				% [id, unreachable] + "room's walking space (blocked by %s)"
				% ", ".join(PackedStringArray(blockers)))
		rows.append(record)
		audited += 1

	_check(audited > 0, "the audit examined nothing")
	_audit_bands(build, space)
	_audit_rewards(build, space)

## Every Check the Zone actually allocates, measured where
## `ZoneController` will really put its pedestal (P2-A).
##
## THE BUG. `reward_position` was a fixed point on an arena's centre
## line and the room's cover boxes were scattered independently, so a
## Check pedestal could stand inside a crate -- and `ZoneController`
## places `RewardObject` at that anchor with no clearance test at all.
## Two of four arenas in the P1 conformance suite did it.
##
## This is the assembled-path half of the regression. The conformance
## suite builds rooms; this one walks the Zone a baseline playtest walks,
## reads the SAME `reward_location_id` and `additional_reward_location_ids`
## the controller reads, applies the SAME `REWARD_SPACING`, and puts a
## pedestal-sized box where each one will stand. A structural failure,
## because a Check the player cannot reach is a Zone that cannot be
## finished.
func _audit_rewards(build: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var checks := 0
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var xform: Transform3D = entry["xform"]
		var anchor: Vector3 = (entry["build"] as Dictionary).get(
				"reward_position", Vector3.ZERO)
		var ids: Array = []
		if chamber.get("reward_location_id") != null:
			ids.append(chamber["reward_location_id"])
		ids.append_array(chamber.get(
				"additional_reward_location_ids", []) as Array)
		for index in ids.size():
			checks += 1
			var at: Vector3 = xform * (anchor + Vector3(
					0.0, 0.0, float(index) * ZoneController.REWARD_SPACING))
			var query := PhysicsShapeQueryParameters3D.new()
			var shape := BoxShape3D.new()
			# The pedestal itself, not the space around it: this asks
			# whether the Check is INSIDE something, and a crate one metre
			# away is cover doing its job.
			shape.size = Vector3(ChamberBuilders.REWARD_PEDESTAL,
					ChamberBuilders.REWARD_PEDESTAL_HEIGHT - 0.4,
					ChamberBuilders.REWARD_PEDESTAL)
			query.shape = shape
			# Lifted clear of the floor it stands ON. A pedestal resting
			# on the ground touches the ground, and touching is not
			# being buried.
			query.transform = Transform3D(Basis(), at + Vector3.UP
					* (ChamberBuilders.REWARD_PEDESTAL_HEIGHT / 2.0 + 0.2))
			query.collide_with_areas = false
			# NAME THE COLLIDER. "Stands inside geometry" was true and
			# useless: it does not say whether the pedestal is in its own
			# room's wall, in a prop, or in a NEIGHBOURING room that the
			# chain placed over it, and those are three different bugs
			# with three different fixes.
			var hits := space.intersect_shape(query, 4)
			var named: Array[String] = []
			for hit: Dictionary in hits:
				var body: Node = hit.get("collider") as Node
				if body == null:
					named.append("<freed>")
					continue
				# WHICH ROOM it belongs to, walked up rather than
				# guessed: a pedestal inside its own room's wall and one
				# inside the NEXT room the chain placed over it look
				# identical from the collider alone.
				var chain: Array[String] = []
				var walk: Node = body
				while walk != null and chain.size() < 6:
					chain.append(str(walk.name))
					walk = walk.get_parent()
				named.append("%s [%s]" % [body.get_class(),
						" < ".join(PackedStringArray(chain))])
			_check(hits.is_empty(),
					"Check %s in room '%s' at %v stands inside: %s"
					% [str(ids[index]), str(chamber.get("id", "?")),
						at, ", ".join(PackedStringArray(named))])
	_check(checks > 0, "the Zone allocates no Checks to measure")
	print("  %d Check pedestal(s) measured where they will stand" % checks)

## Every elevation band the ZONE DECLARES, measured in the assembled
## scene (ROOM_GRAMMAR v0).
##
## A structural check, not a placement note. A band is a claim about
## geometry -- "there is a second height here, and you can walk to it" --
## and the way that claim fails is silently: the deck is described, the
## room is built flat, and nothing anywhere disagrees. That is exactly
## how thirty activities came to be described and none built.
##
## The probe drops onto the deck's own `reserved` socket, which is the
## builder's answer to "where is the band", so the audit and the builder
## cannot drift apart on where to look.
func _audit_bands(build: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var bands := 0
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var band: Variant = chamber.get("elevation")
		if typeof(band) != TYPE_DICTIONARY:
			continue
		bands += 1
		var id := str(chamber.get("id", ""))
		var kind := str((band as Dictionary).get("kind", "gallery"))
		var rise := float((band as Dictionary).get("rise", 2.0))
		var xform: Transform3D = entry["xform"]
		var sockets: Array = (entry["build"] as Dictionary).get(
				"sockets", []) as Array
		# BY NAME. The first version took the LAST `reserved` socket,
		# which worked exactly until a room reserved something else --
		# the Check's own space, added in P2 -- and every band in the
		# Zone suddenly measured at the reward anchor's height.
		var deck: Variant = null
		for socket: Variant in sockets:
			if typeof(socket) != TYPE_DICTIONARY:
				continue
			if str((socket as Dictionary).get("name", "")) == "band_deck":
				deck = (socket as Dictionary)["position"]
		if deck == null:
			_check(false, "room '%s' declares a %s band and the builder "
					% [id, kind] + "emitted no socket for it")
			continue
		var at: Vector3 = xform * (deck as Vector3)
		# Above the deck and BELOW THE CEILING. "Well above" was the
		# first version and it measured every band at five metres,
		# because a ray that starts outside the room stops on the roof --
		# the same wrong-reference mistake this file's `EYE` constant
		# already carries a paragraph about.
		var wall := float(chamber.get("wall_height", 6.0))
		var from := at + Vector3.UP * minf(absf(rise) + 2.0, wall - 0.3)
		var query := PhysicsRayQueryParameters3D.create(
				from, at + Vector3.DOWN * (absf(rise) + 4.0))
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			_check(false, "room '%s': nothing to stand on where its %s "
					% [id, kind] + "band is declared")
			continue
		var surface: float = (hit["position"] as Vector3).y - at.y
		var want := rise if kind == "gallery" else -rise
		_check(absf(surface - want) < 0.75,
				"room '%s': its %s band is declared at %.2f m and the "
				% [id, kind, want]
				+ "assembled room has a surface at %.2f m" % surface)
	print("  %d elevation band(s) measured in the assembled Zone" % bands)

## Does the element's whole box sit inside the room it belongs to?
func _inside(bounds: AABB, element: ActivityElement) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var box := _world_box(element)
	var grown := bounds.grow(BOUNDS_SLACK)
	return grown.encloses(box)

func _world_box(element: ActivityElement) -> AABB:
	for child in element.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			return mesh.global_transform * mesh.get_aabb()
	return AABB(element.global_position, Vector3.ZERO)

## Is any ROOM geometry sharing space with the element?
##
## A shape query rather than a raycast: an element fully inside a wall is
## something no ray from outside ever reaches, so asking "does anything
## overlap me" is the question, and asking "can I see it" is not.
func _overlaps(space: PhysicsDirectSpaceState3D,
		element: ActivityElement, exclude: Array[RID]) -> Array:
	var box := _world_box(element)
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	# Shrunk a little: a plate RESTS on the floor and a switch may touch a
	# wall it is mounted on. Touching is mounting; overlapping is being
	# buried, and only the second is a defect.
	shape.size = box.size * 0.8
	query.shape = shape
	query.transform = Transform3D(Basis(), box.get_center())
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	return space.intersect_shape(query, 8)

## Is this collider part of an activity, rather than part of the level?
func _is_activity_part(collider: Variant) -> bool:
	var node := collider as Node
	while node != null:
		if node is ActivityElement:
			return true
		node = node.get_parent()
	return false

func _collect_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_rids(child, out)

## What stopped the CLOSEST probe ray, for the report. Diagnostic only:
## "an element is blocked" is a finding nobody can act on, and "blocked by
## the floor" and "blocked by a prop" have different answers.
func _blocker(space: PhysicsDirectSpaceState3D, element: ActivityElement,
		bounds: AABB, runtime: ActivityRuntime) -> String:
	var target := _world_box(element).get_center()
	var from := Vector3(bounds.get_center().x,
			_floor_under(element, runtime) + EYE, target.z)
	var query := PhysicsRayQueryParameters3D.create(from, target)
	query.collide_with_areas = false
	query.exclude = _all_activity_rids
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return ""
	var node := hit["collider"] as Node
	if node == null:
		return "?"
	# Anonymous StaticBody3Ds are most of a procedural room, so the name
	# alone says nothing. The parent is what was actually built.
	var parent := node.get_parent()
	return "%s/%s" % [parent.name if parent != null else "?", node.name]

## The walkable plane under this element, from the element itself.
##
## NOT from the chamber bounds. That convention was got wrong twice here:
## bounds start `FLOOR_ALLOWANCE` below the floor, and a `platform_path`
## reaches forty metres down, so "bounds bottom plus chest height" put
## the probe underground and reported most of the Zone blocked by the
## platforms above it.
##
## `RULES[kind].height` is what the builder RAISED the element by, so
## subtracting it lands exactly on the plane the builder measured from.
## No convention, no allowance, nothing to get wrong.
func _floor_under(element: ActivityElement,
		runtime: ActivityRuntime) -> float:
	return element.global_position.y - float(runtime.rules()["height"])

## How far below an element there must be something solid.
##
## An element is placed at a known height above the plane the builder
## measured from -- but a `platform_path` HAS NO SUCH PLANE. It is
## discrete platforms rising over a void, so "the floor plus 8 cm" is a
## point in mid-air between two platforms, or a point underneath one.
## The audit was blind to it: a pad floating in a gap is inside its
## chamber, overlaps nothing, and is perfectly visible from the walking
## line, so every other check passed.
const GROUND_REACH := 1.2

## Is there anything solid under this element?
func _has_ground(space: PhysicsDirectSpaceState3D,
		element: ActivityElement, runtime: ActivityRuntime) -> bool:
	var from := _world_box(element).get_center()
	var to := from - Vector3(0.0, GROUND_REACH + float(
			runtime.rules()["height"]), 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = _all_activity_rids
	return not space.intersect_ray(query).is_empty()

## How many points along the walking lane the reachability probe tries.
const PROBE_STEPS := 9

## Can the element be seen from ANYWHERE a player can stand?
##
## Sampled along the room's centre line -- the walking lane every builder
## keeps clear -- rather than from one point. A player walks; an element
## one probe cannot see past a prop is not unreachable, it is behind
## something you step around.
##
## Every activity element is excluded, not just this one's. A ray stopped
## by another puzzle piece is not an element buried in the level, and the
## overlap check above already reports co-location as its own defect.
func _is_reachable(space: PhysicsDirectSpaceState3D,
		element: ActivityElement, bounds: AABB,
		runtime: ActivityRuntime) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var target := _world_box(element).get_center()
	var centre := bounds.get_center()
	var floor_y := _floor_under(element, runtime)
	var near := bounds.position.z
	var span := bounds.size.z
	for step in PROBE_STEPS:
		var t := float(step) / float(PROBE_STEPS - 1)
		var z := near + span * t
		for height: float in [EYE, 0.6]:
			var from := Vector3(centre.x, floor_y + height, z)
			var query := PhysicsRayQueryParameters3D.create(from, target)
			query.collide_with_areas = false
			query.exclude = _all_activity_rids
			if space.intersect_ray(query).is_empty():
				return true
	return false

# --- driving what the Zone built ----------------------------------------

func _drive_one_of_every_kind(build: Dictionary) -> void:
	"""One REAL instance of each kind, taken to completion in the
	assembled Zone. Not a fresh activity built for the test."""
	var found: Array[ActivityRuntime] = []
	_runtimes_under(build["root"], found)
	var seen := {}
	for runtime in found:
		if seen.has(runtime.kind):
			continue
		seen[runtime.kind] = true
		await _drive_to_completion(runtime)
	for kind: String in ActivityRuntime.RULES:
		_check(seen.has(kind),
				"Zone 1 holds no '%s' to drive; the kind is unproven in a "
				% kind + "real Zone")

func _drive_to_completion(runtime: ActivityRuntime) -> void:
	_check(runtime.state == ActivityRuntime.State.IDLE,
			"'%s' (%s) did not start IDLE in the assembled Zone (state %d)"
			% [runtime.activity_id, runtime.kind, runtime.state])
	var total := runtime.elements.size()
	for i in total:
		await _touch(runtime.elements[i])
		if i == 0:
			_check(runtime.state == ActivityRuntime.State.ACTIVE,
					"'%s' did not go ACTIVE after its first element"
					% runtime.activity_id)
		elif i < total - 1:
			_check(runtime.state != ActivityRuntime.State.COMPLETE,
					"'%s' completed at element %d of %d"
					% [runtime.activity_id, i + 1, total])
	_check(runtime.state == ActivityRuntime.State.COMPLETE,
			"'%s' (%s) could not be completed in the assembled Zone "
			% [runtime.activity_id, runtime.kind] + "(state %d)"
			% runtime.state)
	print("    drove %s '%s' to %s" % [runtime.kind, runtime.activity_id,
			"COMPLETE" if runtime.state == ActivityRuntime.State.COMPLETE
			else "state %d" % runtime.state])

func _touch(element: ActivityElement) -> void:
	if element.trigger == ActivityElement.SHOT:
		Damageable.hit(element.get_node("TargetBody"), 1.0, Vector3.FORWARD)
		return
	var body := CharacterBody3D.new()
	body.add_to_group("player")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	shape.shape = box
	body.add_child(shape)
	element.add_child(body)
	body.global_position = element.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	body.queue_free()
	await get_tree().process_frame

# --- the record ----------------------------------------------------------

func _write_audit() -> void:
	var payload := {
		"activities": rows,
		"audited": audited,
		"failures": failures,
		"placement_notes": notes,
	}
	var file := FileAccess.open(AUDIT_OUT, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	print("  audit written to %s" % ProjectSettings.globalize_path(AUDIT_OUT))




## EVERY SIDE DOOR THE COMPOSER ASSIGNED, MEASURED.
##
## `PROCEDURAL_SOCKETS` is four for every procedural room, so
## `compose_with_branch` hangs branches off `side_left` and `side_right`
## as readily as off `entry` and `exit` -- and the bridge refuses the
## WHOLE LAYOUT when a door it declared USED or LOCKED measures solid
## (`layout.py` rule 5, aperture polarity). That refusal is what stops a
## default-scale Zone being accepted at all: it is `godot-reload`'s
## PHASE 1 failure and it is what the live re-selection journey hits
## after the branch has been moved successfully.
##
## Measured on `zone_01` -- the first Zone of a real default-scale
## campaign, regenerated by `make zone-fixtures` -- rather than on a
## fixture written to make a point. Two producers were lying about
## themselves and one still is:
##
## * `corridor` raised two solid slabs and declared a doorway in the
##   middle of each. FIXED: it cuts them now.
## * `arena` cut them correctly and then stood a perimeter crate 0.45 m
##   inside. FIXED: `_greeble_room` keeps clear of an assigned doorway
##   the way it has always kept clear of the exit lane.
## * `platform_path` raises two solid slabs and cannot honestly cut
##   them -- the declared position is over its kill pit and below its
##   walkway. CLOSED AT THE SOURCE: it no longer ADVERTISES them.
##   `Constants.PROCEDURAL_SOCKET_CAPACITY` says which producers carry
##   which sockets, the composer offers only those, and this Zone no
##   longer assigns one. The waiver that used to stand here counted two
##   and now counts none, which is how it said so.

func _a_side_door_the_composer_assigned_is_a_hole() -> void:
	const ZONE := "res://tests/fixtures/generated/zone_01.json"
	if not FileAccess.file_exists(ZONE):
		_check(false, "%s is missing; run `make zone-fixtures`" % ZONE)
		return
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(ZONE))
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "%s did not parse as a Zone" % ZONE)
		return
	var build := ZoneBuilder.build(parsed as Dictionary)
	if build.has("failed"):
		_check(false, "zone_01 did not lay out: %s" % str(build["failed"]))
		return
	add_child(build["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var measured: Dictionary = RoomAudit.measure_layout(build,
			get_viewport().world_3d.direct_space_state)["apertures"]
	var checked := 0
	var beyond: Array = []
	for raw: Variant in build.get("chambers", []):
		var entry: Dictionary = raw
		var chamber: Dictionary = entry["chamber"]
		var rid := str(chamber.get("id", ""))
		var kind := str(chamber.get("type", ""))
		var carried: Variant = Constants.PROCEDURAL_SOCKET_CAPACITY.get(
				kind)
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			var socket := str(door.get("socket_id", ""))
			if not socket.begins_with("side") \
					or str(door.get("usage", "")) == "SEALED":
				continue
			# NO ROOM IS ASSIGNED A DOOR ITS PRODUCER DOES NOT BUILD.
			# The composer is what guarantees this; measured here on a
			# Zone the composer really made, because a guarantee checked
			# only where it is written is the seam this project keeps
			# finding.
			if typeof(carried) == TYPE_ARRAY \
					and not (carried as Array).has(socket):
				beyond.append("%s/%s (%s)" % [rid, socket, kind])
				continue
			checked += 1
			_check(bool(measured.get("%s/%s" % [rid, socket], false)),
					"%s/%s is %s and the engine built a hole there; a "
					% [rid, socket, str(door.get("usage", ""))]
					+ "declared door that measures solid refuses the "
					+ "whole layout (%s)" % kind)
	_check(checked >= 4,
			"zone_01 offered %d assigned side door(s) to measure; a "
			% checked + "control that measures none has not run")
	_check(beyond.is_empty(),
			"this Zone assigns %s, which the producer does not build; "
			% str(beyond) + "the capacity and the composer have drifted "
			+ "apart again")
	(build["root"] as Node3D).queue_free()
	await get_tree().process_frame


## WHAT EACH PROCEDURAL PRODUCER CAN ACTUALLY BE JOINED THROUGH.
##
## `Constants.PROCEDURAL_SOCKET_CAPACITY` is a claim about geometry, and
## a claim about geometry is worth exactly what a physics query says it
## is. One control per chamber type, each a real two-room Zone with ALL
## FOUR sockets assigned, and three questions of every side door the
## producer agrees to name:
##
## 1. is the aperture a HOLE (`RoomAudit.measure_layout`);
## 2. is there FLOOR a metre inside it (`arrival_is_supported`, which is
##    ground within a step AND room to stand);
## 3. and does the room name it at all.
##
## **An open aperture with nothing under it is not a door.** That is the
## whole finding: `platform_path` advertised two, and the middle of its
## side wall is over its kill pit and below its walkway. `tower` is the
## other room that climbs and answers the same way. Both are held here
## to naming NOTHING they cannot build, so the day one grows a landing
## the control says the capacity may change rather than letting it drift.
func _a_room_names_only_the_openings_it_builds() -> void:
	var kinds: Array = [
		{"id": "c005", "type": "corridor", "length": 14.0, "width": 7.9},
		{"id": "c005", "type": "arena", "width": 18.0, "depth": 18.0,
				"wall_height": 6.0, "objective": "reach_exit"},
		{"id": "c005", "type": "platform_path"},
		{"id": "c005", "type": "tower"},
		{"id": "c005", "type": "treasure_room"},
	]
	var flat := 0
	var capped := 0
	for kind: Dictionary in kinds:
		var room: Dictionary = kind.duplicate()
		room["enemies"] = []
		room["activities"] = []
		room["features"] = []
		# EVERY SOCKET ASSIGNED, including the two under test. A room
		# that carries fewer simply reports fewer doors; nothing here
		# asks it to refuse the assignment, because refusing is the
		# COMPOSER's job and this is about what the builder makes.
		room["doors"] = [
			{"socket_id": "entry", "usage": "USED",
				"edge_id": "e:c004:c005"},
			{"socket_id": "exit", "usage": "SEALED"},
			{"socket_id": "side_left", "usage": "USED"},
			{"socket_id": "side_right", "usage": "USED"}]
		var built := ZoneBuilder.build({
			"zone_id": "zcap", "theme": "concrete_facility",
			"chambers": [
				{"id": "c004", "type": "corridor", "length": 14.0,
						"width": 7.9, "enemies": [], "activities": [],
						"features": [], "doors": [
							{"socket_id": "entry", "usage": "USED"},
							{"socket_id": "exit", "usage": "USED",
								"edge_id": "e:c004:c005"},
							{"socket_id": "side_left", "usage": "SEALED"},
							{"socket_id": "side_right", "usage": "SEALED"}]},
				room,
			],
			"edges": [{"edge_id": "e:c004:c005", "room_a": "c004",
					"room_b": "c005", "realization": "JOINED",
					"direction": "A_TO_B"}],
		})
		var kind_name := str(kind["type"])
		if built.has("failed"):
			_check(false, "the %s capacity fixture did not lay out: %s"
					% [kind_name, str(built["failed"])])
			continue
		add_child(built["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := get_viewport().world_3d.direct_space_state
		var apertures: Dictionary = RoomAudit.measure_layout(built,
				space)["apertures"]
		var declared: Array = []
		for raw: Variant in built.get("chambers", []):
			var entry: Dictionary = raw
			if str((entry["chamber"] as Dictionary).get("id", "")) != "c005":
				continue
			var xform: Transform3D = entry["xform"]
			for raw_door: Variant in (entry["build"] as Dictionary) \
					.get("doors", []):
				var door: Dictionary = raw_door
				var socket := str(door.get("socket_id", ""))
				var local: Vector3 = door.get("position", Vector3.ZERO)
				if not socket.begins_with("side"):
					# THE SPINE IS UNTOUCHED, and saying so is half the
					# point: correcting the advertised capacity must not
					# cost a climbing room its real traversal. Its entry
					# and its exit are holes with ground inside them, for
					# every producer, before and after.
					var step := Vector3(0.0, 0.0,
							1.0 if local.z <= 0.0 else -1.0)
					_check(bool(apertures.get("c005/%s" % socket, false))
								== (str(door.get("usage", "")) != "SEALED"),
							"a %s's '%s' is built the way it is declared"
							% [kind_name, socket])
					if str(door.get("usage", "")) != "SEALED":
						_check(RoomAudit.arrival_is_supported(space,
									xform * (local + step)),
								"and a body a metre inside %s/%s has "
								% [kind_name, socket] + "ground under it")
					continue
				declared.append(socket)
				_check(bool(apertures.get("c005/%s" % socket, false)),
						"a %s names '%s' and the builder cut a hole "
						% [kind_name, socket] + "there")
				# A METRE IN FROM THE WALL, which is where a body
				# crossing this doorway puts its feet. An aperture with
				# nothing under it is a hole, not a door.
				var inward := Vector3(-signf(local.x) * 1.0, 0.0, 0.0)
				_check(RoomAudit.arrival_is_supported(space,
							xform * (local + inward)),
						"and a body standing a metre inside %s/%s has "
						% [kind_name, socket] + "ground under it and "
						+ "room to stand")
		var carried: Variant = Constants.PROCEDURAL_SOCKET_CAPACITY.get(
				kind_name)
		if typeof(carried) == TYPE_ARRAY:
			capped += 1
			_check(declared.is_empty(),
					"a %s is declared as carrying %s, so it must name "
					% [kind_name, str(carried)] + "NO side doorway at "
					+ "all -- it named %s" % str(declared))
		else:
			flat += 1
			_check(declared.size() == 2,
					"a %s carries all four sockets, so both sides are "
					% kind_name + "named and measured (%s)" % str(declared))
		(built["root"] as Node3D).queue_free()
		await get_tree().process_frame
	# THE SHAPE OF THE ANSWER, so neither half can quietly empty out. A
	# run where everything is capped proves nothing about doors, and one
	# where nothing is proves nothing about the capacity.
	_check(flat >= 3 and capped >= 2,
			"%d producer(s) carry four sockets and %d carry two; the "
			% [flat, capped] + "control needs both kinds to mean anything")


## THE PAD IS NOT IN THE WAY OF WHAT THE ROOM HOLDS.
##
## `clear_of_arrival` keeps the device off the spot a body appears on.
## It says nothing about the metres between that spot and the room's
## reward -- and a device in the middle of those sends the player home
## on the way to the thing they came for.
##
## MEASURED on the five generated controls, before the rule existed:
##
## | Zone | pad off the arrival->content line | reached the content |
## |---|---|---|
## | `zone_01` `c018` | 7.67 m | yes |
## | `zone_02` `c011` | **0.41 m** | NO -- "took the return home by wandering onto it" |
## | `zone_03` `c011` | **0.15 m** | NO |
##
## Every journey that failed to reach its room's content had the pad
## within a body's width of the straight line to it; the one that
## succeeded had it seven metres clear. That is the whole finding, and
## it is not a steering failure: the device is in the way.
##
## The content is the node the PLAYER'S OWN PROBE would find -- something
## with `interact()` inside the room's envelope -- and not the producer's
## nominal `reward_position`, which is a different point: on `zone_02`'s
## `c011` the two are seven metres apart, so guarding the nominal line
## guards a line nobody walks.
func _the_return_never_stands_between_arrival_and_content() -> void:
	var checked := 0
	for file: String in ["zone_01.json", "zone_02.json", "zone_03.json",
			"zone_04.json", "zone_05.json"]:
		var path := "res://tests/fixtures/generated/%s" % file
		if not FileAccess.file_exists(path):
			_check(false, "%s is missing; run `make zone-fixtures`" % path)
			return
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			_check(false, "%s did not parse as a Zone" % file)
			continue
		var built := ZoneBuilder.build(parsed as Dictionary)
		if built.has("failed"):
			_check(false, "%s did not lay out: %s"
					% [file, str(built["failed"])])
			continue
		add_child(built["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame
		# THE PRODUCTION SEQUENCE: the settle inside `measure_layout` is
		# what moves a badly reserved pad, so a check that reads the
		# anchors without measuring reads the builder's first guess and
		# not what the player gets.
		RoomAudit.measure_layout(built,
				get_viewport().world_3d.direct_space_state)
		var anchors: Dictionary = built["anchors"]
		for raw: Variant in (parsed as Dictionary).get("plugs", []):
			var plug: Dictionary = raw
			var rid := str(plug.get("room_id", ""))
			var arrival: Variant = anchors.get("room:%s:arrival" % rid)
			var pad: Variant = anchors.get("room:%s:return" % rid)
			var content := RoomAudit.content_of(built, rid)
			if arrival == null or pad == null or not content.is_finite():
				continue
			checked += 1
			_check(RoomAudit.clear_of_content_path(pad, arrival, content),
					"%s: %s's return stands on the way from its arrival "
					% [file, rid] + "to what it holds (pad %v, arrival "
					% pad + "%v, content %v)" % [arrival, content])
		(built["root"] as Node3D).queue_free()
		await get_tree().process_frame
	_check(checked >= 5,
			"%d branch destination(s) with an arrival, a return and "
			% checked + "something to reach were measured; a control "
			+ "that finds none has not run")

