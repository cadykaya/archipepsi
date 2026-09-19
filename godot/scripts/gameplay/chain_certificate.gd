class_name ChainCertificate
extends RefCounted

## THE ENGINE CERTIFYING A CHAIN IT BUILT, in the contract's own models.
##
## A chamber declares INTENT -- `features: [{tag: "powered_door"}]`, an
## ordinary optional affordance -- and `AffordanceFeatures` builds the
## crate, the plate, the signal and the door that intent asks for. That
## the thing was built is not evidence that it works, and the bridge has
## no geometry with which to find out: `AMALGAM_BRIDGE.md` §5.6a is the
## agreed answer, and this is its engine half.
##
## **It replays IN THE ROOM, on the real chain.** Not a reconstruction
## of one: a reconstruction agrees with the generator by construction,
## and the failure worth catching is the one where the room put a pylon
## between the crate and the plate. `ReplayHarness` reads `stage.bodies`
## and `stage.plates` and never touches `stage.root` except to free it,
## so a run's stage is the room's own crate with its state reset and a
## marker node for the harness to drop.
##
## **Three runs, each from the same reset setup.** §23.5 check 20. The
## room is not rebuilt between them -- the chain's physical state is,
## which is what "a fresh stage" is protecting: three runs that continue
## one another are one run read three times.
##
## **It costs entry time and that is the trade.** The player is held by
## `ZoneController.LAYOUT_HOLD` from the moment their body exists until
## the verdict, and a chain adds roughly three seconds of crate-pushing
## inside that hold. Certifying a claim about physics requires running
## the physics.

## How long a settle may take. Short on purpose: the latch fires while
## the crate is crossing the plate, so a settle is the tail of the run
## and not its substance, and `ReplayHarness` breaks out of one the
## moment every body is at rest.
const SETTLE_TIMEOUT_S := 0.75

## Body id inside the package. The crate's NODE name carries the reward
## it guards; the package's body id is the contract's, and the contract
## allows `^[a-z0-9_]+$`.
const CRATE_ID := "crate"

## Every `powered_door` chain this room declared, certified, declined or
## refused -- one entry per declared feature, so an unreported one is a
## hole the bridge can see. `bounds` is the room's committed world
## envelope, which is what makes "within the room" decidable.
static func of_room(tree: SceneTree, zone_id: String,
		chamber: Dictionary, node: Node3D, bounds: AABB) -> Array:
	var rid := str(chamber.get("id", ""))
	var declared := 0
	for raw: Variant in chamber.get("features", []):
		if str((raw as Dictionary).get("tag", "")) == "powered_door":
			declared += 1
	if declared == 0:
		return []
	var chains := chains_in(node)
	var out: Array = []
	for i in declared:
		if i >= chains.size():
			# A LEGAL OUTCOME, not a defect. `AffordanceFeatures.fits`
			# drops a tag a corridor is too narrow for rather than
			# cramming the rig into a wall, and the bridge is told so
			# instead of being left to read silence.
			# DECLINED, and the bridge is told by the absence rather
			# than by a word. `AffordanceFeatures.fits` drops a tag a
			# corridor is too narrow for; the composer's own feature
			# count and the offered package count then disagree, and
			# `layout.validate` refuses -- which is the right answer,
			# because a Zone that declared a chain and built nothing is
			# a Zone whose content was quietly downgraded.
			push_warning("zone: room '%s' declared a powered_door the "
					% rid + "room could not host; no package is offered "
					+ "and the layout will be refused")
			continue
		if not _still_there(node):
			return out
		var certified := await certify(tree, zone_id, rid, i, chains[i],
				node, bounds)
		if not certified.is_empty():
			out.append(certified)
	return out

## EVERY CHAIN IN A BUILT ZONE, certified in one pass.
##
## The loop `ZoneController` kept to itself, moved here because a second
## caller needed it and a copy would have drifted. The sample harness
## stands a Zone up, measures it with the same `RoomAudit.measure_layout`
## a played Zone uses, and then emitted a manifest with `packages: []` --
## so `layout.validate` refused every Zone that declares a `powered_door`
## for "the layout offers 0", which is a fact about the harness and not
## about the Zone. One implementation, two callers.
##
## `alive` is asked before each room, because certifying takes seconds
## and the Zone can be torn down underneath it. It returns what it has
## so far and the CALLER decides whether a partial answer may be sent:
## publishing one under a committed Zone's name is the defect that guard
## exists for.
static func of_build(tree: SceneTree, zone_id: String,
		build: Dictionary, alive := Callable()) -> Array:
	var out: Array = []
	var rooms: Dictionary = build.get("rooms", {})
	for raw: Variant in build.get("chambers", []):
		var entry: Dictionary = raw
		var chamber: Dictionary = entry["chamber"]
		var placed: Dictionary = rooms.get(
				str(chamber.get("id", "")), {})
		if alive.is_valid() and not alive.call():
			return out
		# AND THE ROOM ITSELF, BEFORE ANYTHING CASTS IT.
		#
		# THIS LOOP IS NOT A NODE'S ANY MORE, and that is the whole
		# hazard. While it lived on `ZoneController`, a Zone torn down
		# mid-certification took the coroutine with it: Godot cancels a
		# node's `await` when the node is freed, so the next iteration
		# never ran. A static function has no node to be cancelled with,
		# so it resumes after the Zone is gone and casts a freed room --
		# `godot-playtest3a` and `godot-integration` said so, five times
		# each, in the words this file already uses: "Trying to cast a
		# freed object."
		#
		# `alive` is not enough on its own. It asks about the CALLER --
		# the controller is still in the tree while the Zone it built is
		# being replaced -- and `_still_there` asks about the room this
		# iteration is about to hand to `of_room`, untyped and
		# `is_instance_valid` first, for the reason written below it.
		if not _still_there(entry.get("node")):
			return out
		for certified: Variant in await of_room(tree, zone_id, chamber,
				entry["node"] as Node3D,
				placed.get("bounds", AABB()) as AABB):
			out.append(certified)
	return out

## IS THE ROOM STILL THERE? Certifying a chain takes seconds, not
## frames, and it is started from `_publish_layout`, which nobody
## awaits. So the Zone can be torn down underneath it -- a suite that
## builds a Zone, looks at it and frees it does exactly that -- and
## every line below this one then touches a freed node. `godot-playtest3a`
## found it the honest way: SIGABRT inside `_settle`, on a crate that had
## stopped existing between two physics frames.
## **UNTYPED ON PURPOSE.** A `Node`-typed parameter is type-checked
## before the body runs, and a freed object fails that check -- so the
## guard written to survive a freed node was itself the thing that
## raised on one. `Variant` in, `is_instance_valid` first, and the cast
## only after it is known to be safe.
static func _still_there(node: Variant) -> bool:
	if not is_instance_valid(node):
		return false
	var live := node as Node
	return live != null and live.is_inside_tree()

## The chains built under `node`, in tree order.
static func chains_in(node: Node3D) -> Array:
	var out: Array = []
	for child: Node in node.find_children("*", "Node3D", true, false):
		var link := child as PoweredLink
		if link == null:
			continue
		out.append({"link": link, "crate": _crate_of(link)})
	return out

## The crate belonging to a link: a manipulable body under the same rig.
static func _crate_of(link: PoweredLink) -> ManipulableBody:
	var rig := link.get_parent() as Node3D
	if rig == null:
		return null
	for child: Node in rig.find_children("*", "RigidBody3D", true, false):
		var body := child as ManipulableBody
		if body != null:
			return body
	return null

## One chain, replayed.
static func certify(tree: SceneTree, zone_id: String, rid: String,
		index: int, chain: Dictionary, room: Node3D,
		bounds: AABB) -> Dictionary:
	var link: PoweredLink = chain["link"]
	var crate: ManipulableBody = chain["crate"]
	if crate == null:
		push_warning("zone: the chain in '%s' has a plate and a door "
				% rid + "and no body to put on either")
		return {}
	# SETTLE, THEN FREEZE THE SETUP. The digest records velocity and
	# sleep state, so a digest taken two frames after the crate was
	# created is a digest of a moment that depends on when it was taken.
	# Letting the crate come to rest and then zeroing it makes the setup
	# the same setup every time this runs.
	await _settle(tree, crate)
	if not _still_there(crate) or not _still_there(room):
		return {}
	var home := crate.global_transform
	_reset(crate, home)
	var package := _package(rid, index, link, crate, room, bounds, home)
	var evidence: Dictionary = await ReplayHarness.replay(tree, package,
			func() -> ReplayHarness.Stage:
				return _stage(link, crate, home))
	# AND PUT THE ROOM BACK. The player is held while this runs and has
	# not seen any of it; they must not walk in on a crate that ended a
	# replay against the alcove wall. Unless the room went away while the
	# replay ran, in which case there is nothing to put back and nothing
	# to report.
	if not _still_there(crate):
		return {}
	_reset(crate, home)
	if evidence.has("refused"):
		# A BUILT CHAIN THIS ENGINE CANNOT REPLAY IS NOT OFFERED, and
		# the absence is what refuses the layout. Offering the package
		# without its evidence would be offering a claim and calling it
		# a certificate.
		push_warning("zone: the chain in '%s' was built and could not "
				% rid + "be certified: %s" % str(evidence["refused"]))
		return {}
	package["evidence"] = evidence
	# DESS'S CARRIER (`AMALGAM_BRIDGE.md` §5.6, option 2): a
	# `PlacedPackage`, bound to the Zone, the room and the declared
	# content it realizes, travelling in `layout_result` and committed
	# with the manifest. The three identities are checked on the other
	# side, which is why they are stated here rather than implied.
	return {
		"package_id": str(package["package_id"]),
		"zone_id": zone_id,
		"room_id": rid,
		"content_ref": "feature:powered_door",
		"package": package,
	}

## The stage for one run: the room's own chain, reset.
static func _stage(link: PoweredLink, crate: ManipulableBody,
		home: Transform3D) -> ReplayHarness.Stage:
	var stage := ReplayHarness.Stage.new()
	if not _still_there(link) or not _still_there(crate):
		# An empty stage: `ReplayHarness` refuses a run whose body the
		# stage does not build, which is the honest answer for a chain
		# whose room stopped existing mid-replay.
		return stage
	# The harness frees `root` after each run, so it is a marker and not
	# the rig -- freeing the rig would delete the chain being certified.
	var marker := Node3D.new()
	marker.name = "ReplayRun"
	(link.get_parent() as Node3D).add_child(marker)
	stage.root = marker
	_reset(crate, home)
	stage.bodies[CRATE_ID] = crate
	stage.plates["plate"] = plate_region(link)
	return stage

## The plate, in world space.
##
## `ReplayHarness` asks whether a body's CENTRE is inside this box; the
## door asks whether the body OVERLAPS its own `Area3D`. Centre-inside
## implies overlap, so a latch here implies a powered door -- the
## evidence claims slightly more than the door needs, which is the safe
## direction for it to differ in.
##
## Rooms are laid on right-angle turns, so the box over the rotated
## corners is the rotated box. A room placed at some other angle would
## make this permissive rather than wrong, and the comparison above is
## what keeps that from mattering.
static func plate_region(link: PoweredLink) -> AABB:
	var extent := link.plate_extent
	var local := AABB(Vector3(-extent.x / 2.0, 0.0, -extent.z / 2.0),
			extent)
	var xf := link.global_transform
	var out := AABB(xf * local.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(xf * local.get_endpoint(i))
	return out

## The package: what the engine built, said in the contract's words.
static func _package(rid: String, index: int, link: PoweredLink,
		crate: ManipulableBody, room: Node3D, bounds: AABB,
		home: Transform3D) -> Dictionary:
	var toward := link.plate_position() - home.origin
	toward.y = 0.0
	var gap := toward.length()
	var dir := toward / gap if gap > 0.001 else Vector3.FORWARD
	return {
		"package_id": "%s_pd%d" % [rid, index],
		"latch_conditions": [{
			"latch_id": "plate_loaded",
			"kind": "WEIGHT_THRESHOLD",
			"detail": "plate >= %s" % _num(link.threshold_kg)}],
		# NOTHING IS PROMOTED AND NOTHING IS REQUIRED, because a feature
		# may not lie on the mandatory path (§13.2). `vector_latches` is
		# the verifier's budget for latches a route depends on, and this
		# chain guards a note. Declaring either would be claiming the
		# opposite of what the affordance contract promises.
		"vector_latches": [],
		"required_latches": [],
		"on_mandatory_route": false,
		"setup": {
			"bodies": [{"body_id": CRATE_ID, "mass_kg": crate.mass,
					"constrained": crate.constrained}],
			"solver": {
				"iterations": int(ProjectSettings.get_setting(
						"physics/3d/solver/solver_iterations", 8)),
				"fixed_step_hz": float(
						Engine.physics_ticks_per_second),
				"settle_timeout_s": SETTLE_TIMEOUT_S},
			"scene_digest": SceneDigest.of_room(room, bounds, [crate])},
		"reference_solution": {"steps": [
			"push %s %s %s %s" % [CRATE_ID, _num(dir.x), _num(dir.z),
					_num(_push_seconds(crate.mass, gap))],
			"settle"]},
	}

## How long the reference solution pushes.
##
## The time a body under the envelope's NET force -- 700 N less what
## friction takes back -- needs to cover the gap between where the crate
## sits and where the plate is. It ignores the coast after the push, so
## it errs long: a crate that crosses the plate fast still latches while
## it is over it, and a crate that stops short latches nothing and would
## have the bridge refuse a chain that works. The alcove behind the door
## is what stops the overshoot.
static func _push_seconds(mass: float, gap: float) -> float:
	var net := Constants.ENVELOPE_FORCE_N \
			- ManipulableBody.envelope_friction() * mass \
				* ManipulableBody.gravity()
	if net <= 0.0 or mass <= 0.0:
		# The envelope cannot move this body at all. A push of no length
		# is still emitted: the evidence then says, honestly, that the
		# reference solution latched nothing.
		return 0.05
	return snappedf(sqrt(2.0 * gap * mass / net), 0.05)

## Waits for the crate to stop moving, bounded.
static func _settle(tree: SceneTree, crate: ManipulableBody) -> void:
	for _i in int(SETTLE_TIMEOUT_S * Engine.physics_ticks_per_second):
		# CHECKED EVERY ITERATION, not once at the top: the await below
		# is where the Zone gets freed, so the crate this loop asks
		# about may not exist by the time the question is asked again.
		if not _still_there(crate) or crate.at_rest():
			return
		await tree.physics_frame

## The setup, as the digest recorded it.
static func _reset(crate: ManipulableBody, home: Transform3D) -> void:
	crate.global_transform = home
	crate.linear_velocity = Vector3.ZERO
	crate.angular_velocity = Vector3.ZERO
	crate.sleeping = false

## Four decimals, because the package's text IS the digest: a number
## printed one way here and another way tomorrow invalidates evidence
## about a chain nothing changed about.
static func _num(x: float) -> String:
	return "%.4f" % x
