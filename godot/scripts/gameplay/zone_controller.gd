class_name ZoneController
extends Node3D

## Metres between two Checks in the same room. Far enough that a player
## claims one at a time and can see there are two; close enough that a
## room holding three still reads as one space.
const REWARD_SPACING := 4.0
## Owns one loaded Zone instance: enemies, objective latching, rewards, the
## exit portal, and the player. Transient by design — nothing here survives
## leaving the Zone, which is why leaving resets objectives (§14.3).

signal exit_requested

## A reached, working station wants a destination chosen. Carries the
## station's id, its label and the eligible destinations.
signal travel_panel_requested(from_id: String, from_label: String,
		options: Array)

## A destination was chosen and taken. Announced rather than inferred:
## `godot-boot` has to be able to see that the panel's choice reached
## THIS controller, and reading the player's position cannot tell a warp
## from a fall.
signal station_warped(from_id: String, to_id: String)
## The bridge refused this Zone's layout; it is not safe to play.
signal layout_refused(zone_id: String)
## The player moved into a different chamber's bounds — the rule engine's
## `chamber_enter` event. Fires for the first chamber on the first frame.
signal chamber_entered(index: int)

var zone: Dictionary = {}
var zone_id := ""
## The proposal this controller is building, captured by `setup` and
## echoed on `layout_result`. `""` when the bridge offered none.
var proposal_id := ""
## WHICH ATTEMPT at that proposal this build is -- the Zone's refusal
## count when `setup` started, echoed with the result.
##
## `proposal_id` is CONTENT identity, and two tries at the same content
## hash the same: the deterministic provider recomposes the same Zone
## after a refusal, so a replaced build's late result still matches.
## What separates them is the attempt it belongs to, and a refusal is
## exactly what ends one attempt and begins the next. `-1` when the
## bridge holds no record to read it from.
var attempt := -1
var player: Player
var tones: Tones = null          # set by main; null in headless tests
var hud: Hud = null              # set by main; null in headless tests

## Which movement package this Zone builds (Stage 3A, R6/R7).
##
## Set by whoever entered the Zone, BEFORE `setup`. The default is
## `none`, so an ordinary Zone entered by an ordinary player constructs
## no movement geometry and behaves exactly as it did before 3A. Since
## 3B `--movement-package` reaches ordinary generated Zones too, not the
## showcase alone.
##
## It is an operator control and nothing more: not an Archipelago item,
## not progression, not saved, not part of the Zone schema. See
## `MovementSelection`.
var movement_package := MovementSelection.DEFAULT_MODE

## Why this Zone has no geometry, or "" when it built.
##
## Set when `ZoneBuilder` reports that a room could not be routed clear
## of the ones before it. Nothing else in the controller runs after that:
## a half-built Zone with an unplaced room is the state this exists to
## make impossible.
var layout_failed := ""

## What the offer stage actually did, for the operator log and for tests.
##
## `declared` counts manifest entries; `judged` counts verdicts, which is
## smaller because a launch PAIR is one verdict over two authored points;
## `built` counts nodes that now exist, which is smaller again because a
## grapple point is accepted and constructs nothing. Three different
## facts, kept in three different fields on purpose.
## SEVEN TERMS, SEVEN FACTS, AND NONE OF THEM IS ANOTHER.
##
##   declared  -- manifest entries the rooms carry
##   judged    -- verdicts returned; smaller, because a launch PAIR is
##                one verdict measuring two authored points
##   accepted  -- verdicts that measured true
##   selected  -- accepted offers the package chose to build; smaller
##                again, because a mode considers only its own kinds
##   built     -- selected offers a NODE now exists for; smaller still,
##                because a grapple point constructs nothing
##   declined  -- offers that measured false
##   refused   -- rooms that could not be measured at all
##
## `judged_before_first_build` is the lifecycle itself, measured: how
## many rooms had a verdict recorded before the first node was
## constructed. In the three-phase lifecycle that is every room; in a
## per-room validate-then-construct it is one.
var offer_census := {"declared": 0, "judged": 0, "accepted": 0,
		"selected": 0, "built": 0, "declined": 0, "refused": 0,
		"judged_before_first_build": 0}

## What the selector chose, as `{chamber, kind, offer}` identities.
var offer_selection: Array = []

## The rooms as `ZoneBuilder` placed them: `{chamber, node, build, xform}`
## per entry.
##
## Kept because the offer stage and anything auditing it need the SAME
## records -- the live node, the build result it came from, and the
## chamber that asked for it. `_chambers` below is the objective/enemy
## bookkeeping and deliberately carries neither the node nor the build,
## so re-deriving them would be a second answer to a question that
## already has one.
var offer_rooms: Array = []
## Set by main before setup(). The Zone geometry is whatever the schema
## said; this only changes how the last transmission is presented.
var is_finale := false

var _chambers: Array = []      # {chamber, objective, satisfied, enemies,
                               #  reward, goal_area}
var _exit_portal: ExitPortal
var _zone_anchors := {}
## What the activity being played currently reads, mirrored onto the
## objective line. Empty when no attempt is in progress.
var _activity_note := ""

## `room_id -> world AABB`, from the committed layout.
var room_bounds := {}

## THE ZONE'S REVERSIBLE CONFIGURATION (D-8). Declared by
## `Zone.zone_state`, set by a control the player operates, read by
## machinery in other rooms.
var zone_state: ZoneState = null
var _zone_state_built := {}
var zone_state_refusals: Array[String] = []
## What the snapshot said the variables held. Assigned before `setup`
## exactly as `latches_carried` and `keys_carried` are.
var macro_carried := {}

## THE ZONE'S DECLARED RAILWAYS, and what the engine refused to build.
##
## `rail_refusals` is deliberately public and deliberately not an error:
## a declaration the carrier cannot honour is a finding about the Zone,
## and a suite that can read it is how that finding becomes a report
## instead of a silence.
var _rail := {}
var rail_refusals: Array[String] = []
## Each room's committed frame: `{position, yaw, arrival}` in world
## space, off the same layout `room_bounds` comes from.
var room_places := {}
## The room the appended exit room hangs off, whose `exit` face the
## engine cuts open even when the composer declared it SEALED -- see
## `ZoneBuilder._with_zone_exit_open`. The ONE face where declared usage
## and built geometry are meant to disagree.
var exit_departs_from := ""
## `"<room_id>/<socket_id>" -> world position of that doorway.`
##
## The builder already computes this so the lock slab and the door probe
## cannot disagree about where a socket is; a suite walking a real body
## from one opening of a junction to another needs the same answer, and
## deriving it a second time from room bounds is how the third answer
## starts. Empty on a Zone with no door assignments.
var door_positions := {}
## MONOTONE, and that is what makes a resume safe. A Zone's key set and
## its opened-lock set only ever grow, so a reload can never put the
## player back behind a door they already opened.
var _keys_held := {}
## Latches this Zone has already reported, by `package_id/latch_id`.
## The bridge is idempotent on these and a resend is the normal case
## after a dropped connection, but a machine that re-reported on every
## rebuild would be sending the bridge back what the bridge just sent.
var _latches_fired := {}
var _locks_open := {}
var _zone_locks: Array = []
var _stations: Array = []
## Reached-ness is progress, so this only ever grows. `resume_anchor` is
## the exception the contract names: a POSITION, overwritten rather than
## accumulated, and losing it costs a walk rather than a run.
var _stations_reached := {}
## The manifest the bridge committed for this Zone, if it has one. Set
## before `setup`; empty means this is the first visit and the layout is
## solved rather than replayed.
var committed_manifest := {}
## What the bridge said about the layout this session sent, for a caller
## or a suite to read: "", "ACCEPTED", "LAYOUT_REFUSED", ...
var layout_verdict := ""

## The aperture polarity this client measured and sent, `room/socket ->
## is a hole`. Kept because it is the evidence behind the bridge's
## refusal, and a suite that falsifies a door needs to be able to say
## the falsification actually carved something rather than pass on
## somebody else's refusal.
var measured_apertures := {}
## The placement outcome this client measured and sent, per plug
## `edge_id` (`AMALGAM_BRIDGE.md` §5.9). Kept for the same reason as
## `measured_apertures`: a suite that drives a room to `NO_CANDIDATE`
## has to be able to say the ENGINE reported it, rather than reading a
## bar off the bridge and calling that a measurement.
var measured_placement := {}
## How long to hold before treating silence as a refusal.
## HOW LONG THE PLACEMENT SEARCH MAY RUN BEFORE IT IS A REFUSAL.
##
## `ZoneBuilder` has had a budget and a `LAYOUT_TIMEOUT` status all
## along and this, its only caller, passed 0.0 -- no budget at all. The
## search then runs on the main thread for as long as it likes, and a
## Zone that took FORTY SECONDS to decide it was infeasible held the
## thread past the websocket's keepalive: the bridge dropped the client
## mid-build, the `build_failed` that followed went into a dead socket,
## and the campaign sat waiting for a verdict nobody could send. The
## Zone was refused correctly; the connection did not survive being
## told.
##
## SIX SECONDS, against measurement rather than taste. Across the
## declared twenty-Zone sample the whole solve takes a median of 321 ms,
## 711 ms at p90 and 2070 ms at worst -- so this is roughly three times
## the slowest Zone that routes, and a third of the keepalive it has to
## stay inside. A Zone that spends it is one the bridge recomposes,
## which is the recovery that already exists.
##
## A COMMITTED REPLAY IS NEVER TIMED OUT: `ZoneBuilder` exempts it,
## because a manifest is laid down rather than searched for, and a save
## must not become unenterable because a machine was busy.
const PLACEMENT_BUDGET_MS := 6000.0

const VERDICT_TIMEOUT := 10.0

## The name this controller holds the player under while a graph Zone's
## layout is unaccepted. Its own claim, so a menu opening and closing
## beside it changes nothing.
const LAYOUT_HOLD := "layout_verdict"
## Every Check this Zone holds, from its own chambers.
var _zone_locations: Array[int] = []
## PROGRESS CARRIED IN, set before `setup` by whoever is remembering.
##
## `locked_door.gd` already states the rule this serves: opened locks are
## "a growing set, which is what makes a resume safe: a reload can never
## put the player back behind a door they have already opened". Stations
## were being carried and these were not, so walking out of a Zone and
## back in re-locked every door and took the keys away -- and the player
## could be standing on the far side of one when it happened.
var keys_carried := {}
var locks_carried := {}
## Latches this Zone has already fired, by `package_id/latch_id`, as the
## snapshot's `progress.latched` reports them. A machine reads this at
## BUILD time and recomputes what the latch implies; nothing about the
## consequence is separately saved (§5.4a).
var latches_carried := {}
## activity id -> the room it stands in, for station repair.
var _activity_room := {}
var resume_anchor := ""
## Stations already online when this Zone is entered, by id. Set before
## `setup` by whoever is carrying progress; empty on a first entry.
var stations_online := {}
var _first_kill_seen := false
var _portal_was_locked := true
var _quiet_time := 0.0
var _last_claimed := -1
var _current_chamber := -1

## WHICH ROOMS THE PLAYER HAS ACTUALLY BEEN IN, this session.
##
## Not a map and not persisted. `_track_chamber` already decides which
## chamber the body is in every frame; this remembers the answers so an
## unlock message can name a place the player has SEEN without naming
## one they have not. `docs/AGENT_FRONTIER.md` has no exploration
## authority and this does not become one -- on a reload it starts
## empty, and an unlock message then says "somewhere in this Zone"
## rather than inventing a room the player may not remember.
var _rooms_entered := {}

## Locks opened since the last time anybody asked. `_on_lock_opened`
## fills it; `_on_key_collected` drains it into ONE message.
var _opened_since := []
## Which chamber the in-flight encounter is being timed for, latched on
## the first blow so walking next door does not retarget the count. -1
## when no fight is running.
var _encounter_chamber := -1
## Union of every chamber and connector AABB the builder placed.
## `blink` tests its landing point against this: outside it is
## outside the level, wall or no wall (invariant I14).
var _world_bounds := AABB()
var _has_bounds := false
## Measures how long this Zone actually takes (CAMPAIGN_SCALE.md 13).
## Never read by anything in the Zone: it observes and reports, and the
## Zone plays identically without it.
var playtime := PlaytimeLog.new()
const _QUIET_BEFORE_ASIDE := 75.0

func setup(zone_dict: Dictionary) -> void:
	zone = zone_dict
	zone_id = zone.get("zone_id", "")
	# WHICH PROPOSAL THIS BUILD IS OF, taken NOW and not when the result
	# is sent (`AMALGAM_BRIDGE.md` §5.9).
	#
	# `_publish_layout` awaits physics frames and then settles every
	# physics package, which is long enough for Epsilon to compose new
	# content or for `reselect_hosts` to regraph this Zone onto other
	# hosts. Reading the current identity at send time would hand this
	# build the REPLACEMENT's id -- and the bridge would then spend the
	# replacement's refusal budget on an old build's verdict, bar the
	# replacement's rooms, or commit a layout of the Zone it replaced.
	# Captured here, the old build carries the old id however long it
	# takes to come back, and is ignored outright.
	proposal_id = BridgeClient.proposal_for(zone_id)
	# THE SAME CARRIER AND THE SAME MOMENT. Both are read here, off the
	# record the build is being made from, so the content identity and
	# the attempt it belongs to cannot come from two different states.
	attempt = BridgeClient.attempt_for(zone_id)
	# AND AN OMISSION IS NEVER SILENT. Absent on the wire means "cannot
	# be checked" -- the documented behaviour for a client older than
	# the field -- so a current client that binds nothing looks exactly
	# like one. If the bridge held this Zone and offered no identity for
	# it, that is a carrier that did not reach the build path and it is
	# said out loud rather than discovered later as an unexplained
	# acceptance.
	if proposal_id == "" and zone_id != "" \
			and str(BridgeClient.active_zone().get("zone_id", "")) == zone_id:
		push_warning("zone: %s is being built with no proposal identity; "
				% zone_id + "a late result for it cannot be told from a "
				+ "current one (AMALGAM_BRIDGE.md 5.9)")
	var theme: String = zone.get("theme", "void_glitch")
	# A COMMITTED MANIFEST IS REPLAYED, NOT RE-SOLVED. `ZoneReady` carries
	# one on every visit after the first, and laying those transforms back
	# down is what makes a revisited Zone the same Zone -- a re-search
	# would be a second layout for a place the player already knows.
	var build := ZoneBuilder.build(zone, "", PLACEMENT_BUDGET_MS,
			ZoneBuilder.layout_from_json(committed_manifest) \
			if not committed_manifest.is_empty() else {})
	# A ZONE THAT COULD NOT BE LAID OUT IS NOT A ZONE. `ZoneBuilder`
	# reports a routing failure rather than attaching a room on top of
	# another one, and the honest thing to do with that report is to
	# refuse the Zone -- not to enter a level whose Check is inside a
	# wall. `layout_failed` is what a caller and the suites read.
	if build.has("failed"):
		layout_failed = str(build["failed"])
		push_error("zone: %s could not be laid out -- %s"
				% [zone_id, layout_failed])
		# AND THE BRIDGE HAS TO HEAR IT. Returning here is right -- a
		# Zone that could not be laid out is not a Zone -- but returning
		# was ALL this did, and the silence was the bug. No
		# `layout_result` is ever sent for a build that did not happen,
		# so the record stayed ACTIVE waiting for a verdict that was not
		# coming: the Hub stayed ZONE_ACTIVE offering a way back into a
		# Zone that cannot be built, and the campaign could not move.
		#
		# `build_failed` and not a synthesised `layout_result`: there is
		# no geometry, and sending an empty or part-built layout would
		# have the validator report a geometry error for geometry that
		# was never laid down.
		send_build_failed(layout_failed)
		return
	add_child(build["root"])
	_exit_portal = build["exit_portal"]
	for box: AABB in build["bounds_list"]:
		_world_bounds = box if not _has_bounds \
				else _world_bounds.merge(box)
		_has_bounds = true
	offer_rooms = build["chambers"]
	playtime.begin(build["chambers"].size())
	# THE OFFER BINDING (owner ruling, 2026-09-03). The Zone's root is in
	# the tree now, so its colliders are about to be real -- one physics
	# frame from here. Deferred to that frame rather than run inline,
	# because a probe against a body the physics server has not yet
	# registered answers "nothing there", and this stage exists precisely
	# so no movement offer is ever blessed by geometry nobody could see.
	_validate_offers.call_deferred(build["chambers"])
	_exit_portal.exit_requested.connect(func() -> void: exit_requested.emit())
	# RETURN PLUGS. A dead end's way back, and the only movement in the
	# game that is not the player's own: the device names a destination
	# ANCHOR and the builder has already resolved every anchor to a
	# place, so nothing here invents a coordinate either.
	_zone_anchors = build.get("anchors", {})
	# WHERE EACH ROOM IS, in world space, off the committed layout. The
	# builder already resolved it and the manifest already carries it;
	# anything that needs to ask "is this point in that room" asks here
	# rather than re-deriving a transform.
	for rid: String in build.get("rooms", {}) as Dictionary:
		var place: Dictionary = (build["rooms"] as Dictionary)[rid]
		room_bounds[rid] = place.get("bounds", AABB())
		# AND ITS FRAME, not only its envelope. The builder resolved a
		# position, a yaw and an arrival for every room and the manifest
		# already carries all three; keeping only the AABB meant anything
		# asking "which way does this room face" had to rebuild the
		# transform from a constant it copied out of the builder -- which
		# is the second computation the paragraph above forbids.
		room_places[rid] = {
			"position": place.get("position", Vector3.ZERO),
			"yaw": float(place.get("yaw", 0.0)),
			"arrival": place.get("arrival", Vector3.ZERO)}
	# THE DECLARED CROSS-ROOM RELATIONSHIPS (D-8). Before the railways,
	# because both read `room_places` and this one owns state the rest of
	# the Zone may read.
	zone_state = ZoneState.new()
	zone_state.name = "ZoneState"
	add_child(zone_state)
	zone_state.declare(zone_dict.get("zone_state", []) as Array)
	# THE SAVED VALUES, BEFORE ANYTHING IS BUILT, so every mechanism
	# comes up in the position the snapshot implies rather than at its
	# initial and then jumping.
	zone_state.restore(macro_carried)
	_zone_state_built = ZoneStateBuild.build(self,
			zone_dict.get("zone_state", []) as Array, zone_state,
			room_places, room_bounds,
			str(zone_dict.get("theme", "concrete_facility")))
	for why: String in _zone_state_built.get("refused", []) as Array:
		zone_state_refusals.append(why)
		push_warning("zone_state refused: %s" % why)
	zone_state.changed.connect(_on_zone_state_changed)

	# THE DECLARED RAILWAYS (D-4). Built here and not in the chamber
	# loop, because a network spans ROOMS: its docks are in different
	# chambers and its path is only computable once every one of them has
	# a committed place. `room_places` is that commitment, read rather
	# than re-derived.
	_rail = RailNetworks.build(self, zone_dict.get("rail_networks", []),
			room_places, str(zone_dict.get("theme", "concrete_facility")))
	for why: String in _rail.get("refused", []) as Array:
		# REPORTED, NOT RAISED. A network the engine cannot honour is a
		# composition finding for whoever authored the Zone; crashing a
		# player out of a Zone over it would be the wrong end of the
		# problem, and building half of one would be worse.
		rail_refusals.append(why)
		push_warning("rail network refused: %s" % why)
	for raw_junction: Variant in _rail.get("junctions", []) as Array:
		var junction: RailJunction = raw_junction
		junction.latch_fired.connect(_on_rail_latch)
		# RECOMPUTED FROM THE LATCH, never restored from a saved span.
		# §5.4a: the decision persists and the machine is rebuilt from
		# it, so a span commissioned last visit is commissioned again
		# here without the engine being told the state of any object.
		junction.restore_from(latches_accepted())
	door_positions = (build.get("doors", {}) as Dictionary).duplicate()
	exit_departs_from = str(build.get("exit_departs_from", ""))
	for raw: Variant in build.get("plugs", []):
		var plug: ReturnPlug = raw
		plug.traversed.connect(_on_plug_traversed)
	for raw_key: Variant in build.get("keys", []):
		var key: ZoneKey = raw_key
		# A KEY ALREADY COLLECTED IS NOT REBUILT.
		#
		# Collecting it again is harmless -- `_keys_held` is a set and
		# the intent is idempotent -- which is exactly why nothing
		# noticed: a Zone reopened in a second process put the red key
		# back on its pedestal, and a player who had already carried it
		# through the door was looking at a Check-shaped object that
		# meant nothing. Progress is monotone, so the thing it unlocked
		# stays unlocked and the thing it was stays gone.
		if keys_carried.has(key.key_id):
			key.queue_free()
			continue
		key.collected.connect(_on_key_collected)
	_stations = build.get("stations", [])
	for raw_station: Variant in _stations:
		var station: WarpStation = raw_station
		station.reached.connect(_on_station_reached)
		station.warp_requested.connect(_on_warp_requested)
		station.panel_requested.connect(_on_station_panel_requested)
		# ALREADY ONLINE FROM A PREVIOUS VISIT. Reached-ness is progress
		# and progress is monotone, so a station a player switched on
		# before they walked out does not switch off behind them.
		if stations_online.has(station.station_id):
			# A station the player repaired stays repaired: the puzzle
			# was solved, and re-entering the Zone does not unsolve it.
			station.repair()
			station.mark_reached()
			_stations_reached[station.station_id] = true
	# KEYS FIRST, so a lock wired below opens on the same frame rather
	# than standing shut until the player touches something.
	for key_id: Variant in keys_carried:
		_keys_held[str(key_id)] = true
	_zone_locks = build.get("locks", [])
	for raw_lock: Variant in _zone_locks:
		var lock: LockedDoor = raw_lock
		lock.opened.connect(_on_lock_opened)
	# A DOOR ALREADY OPENED STAYS OPENED, whatever opened it. A
	# capability gate the player passed with an Echo they have since
	# unequipped is still a door they have been through.
	for raw_lock: Variant in _zone_locks.duplicate():
		var lock: LockedDoor = raw_lock
		if locks_carried.has("%s/%s" % [lock.room_id, lock.socket_id]):
			lock.open()
	_open_what_the_keys_allow()
	# A RESUME IS NOT AN EVENT. Everything opened above was opened by a
	# key the player already had, so announcing it would greet a
	# returning player with a list of doors they opened last night.
	_opened_since.clear()

	player = Player.create()
	add_child(player)
	# THE HOLD GOES ON HERE, not when the verdict wait begins.
	#
	# `_publish_layout` awaits two physics frames before it measures and
	# sends, and `_await_verdict` only ran after that -- so a graph Zone
	# handed the player two live frames before anyone had checked its
	# geometry. Two frames is a jump. The claim is made the moment the
	# body exists and is dropped by the verdict, so there is no window at
	# all.
	if not (zone.get("edges", []) as Array).is_empty():
		player.hold(LAYOUT_HOLD)
	# RESUME AT THE STATION, when there is one to resume to.
	#
	# `handle_leave_zone` is already non-destructive on the bridge --
	# "no persistent change; Godot resets transient state itself" -- so
	# walking out and back in kept every Check and lost only WHERE YOU
	# WERE. That is the whole of what a save station adds, and it is why
	# the station had to come first.
	var spawn_at: Transform3D = build["spawn_transform"]
	var resume := _station_by_id(resume_anchor)
	if resume != null:
		spawn_at = Transform3D(spawn_at.basis,
				resume.global_position + Vector3(0, 0.3, 2.0))
	player.set_spawn(spawn_at)

	# The measurement hooks (CAMPAIGN_SCALE.md 13). An encounter starts
	# when someone actually engages -- a shot that connects, or a hit
	# taken -- rather than when a room is entered, because a room you
	# sprint through is not a fight and would otherwise report a
	# thirty-second one.
	player.died.connect(func() -> void: playtime.note_death())
	player.hit_confirmed.connect(func(_killed: bool) -> void:
		_note_engagement())
	player.damaged_from.connect(func(_source: Vector3) -> void:
		_note_engagement())
	player.died.connect(func() -> void: _encounter_chamber = -1)

	# Optional ledges (DESIGN §19). Walked, not searched: nothing is
	# reported anywhere, so reaching one only ever earns a remark.
	for node in _collect_group(build["root"], ChamberBuilders.SECRET_GROUP):
		var area := node as Area3D
		area.body_entered.connect(_on_secret_entered.bind(area))

	# THE MEASURED HALF OF THE LAYOUT RESULT, taken from the Zone that
	# was actually built and while it is standing in the tree.
	#
	# The bridge cannot measure any of this -- whether a standing capsule
	# fits at an anchor, or whether a declared door is a hole -- and it
	# refuses a layout that does not carry it rather than assuming. A
	# coordinate is not evidence a body fits there.
	# MEASURED AND SENT ONCE THE PHYSICS EXISTS, which is two frames
	# after the scene goes in and not the same frame.
	#
	# A collider is registered by the physics server on the next step, so
	# a probe fired in the frame a room was added comes back CLEAN --
	# every aperture a hole, every arrival supported, because there is
	# nothing there to hit yet. That is the most dangerous kind of pass,
	# and this file's own audit says so in as many words: "a probe
	# against [a detached node] comes back clean because there is nothing
	# there to hit".
	_publish_layout(build)
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var xform: Transform3D = entry["xform"]
		var result: Dictionary = entry["build"]
		var record := {
			"chamber": chamber,
			"objective": _objective_of(chamber),
			"satisfied": false,
			"enemies": [] as Array,
			"reward": null,
			# Grown a metre so a doorway seam cannot flicker between
			# chambers frame to frame.
			"bounds": ZoneBuilder._world_aabb(result["bounds"], xform.origin,
					xform.basis.get_euler().y).grow(1.0),
		}

		# The activities this room built, registered for measurement only
		# (CAMPAIGN_SCALE.md 13). The log never reaches back into a
		# runtime, so a Zone plays identically with the whole of it gone.
		for built: Variant in result.get("activities", []):
			if typeof(built) != TYPE_DICTIONARY:
				continue
			var runtime := (built as Dictionary).get("runtime") as \
					ActivityRuntime
			if runtime != null:
				runtime.room_index = _chambers.size()
				playtime.watch_activity(runtime)
				# COMPLETION HAS TO REACH THE SCREEN.
				#
				# `ActivityRuntime` has done its half since the activity
				# batch: it clocks a `time_limit`, says DONE, sends
				# `grant_local_reward` and emits `completed`. The
				# playtest finished four activities and perceived none
				# of it, and the reason is here -- `completed` had NO
				# LISTENER anywhere in the project, and the only
				# acknowledgement was a Label3D on the activity itself,
				# which is behind you the moment you touch the last
				# element. A key toasts and a lock toasts; finishing a
				# puzzle did not.
				runtime.completed.connect(_on_activity_completed)
				# AND SO DOES FAILURE. `failed` had no listener either,
				# so running out of time silently reset every element
				# and the player was left to infer it from the geometry
				# going dark. The playtest reported exactly that.
				runtime.failed.connect(_on_activity_failed)
				# AND ONTO THE SCREEN WHILE IT IS BEING PLAYED. The
				# activity's own label sits above where it starts, which
				# is not where a player shooting its third target is
				# looking. The objective line is already on screen.
				runtime.progressed.connect(_on_activity_progressed)
				# The per-hit cue needs the bank the same way completion
				# does; the runtime is what knows a hit COUNTED.
				runtime.tones = tones
				# WHICH ROOM A PUZZLE IS IN, so a broken station in that
				# room can be repaired by solving it. Kept here rather
				# than re-derived from the activity id, because the id
				# format is `Activities.build`'s business and agreeing
				# with it from a distance is how the two drift apart.
				_activity_room[runtime.activity_id] = runtime.room_id

		# NOBODY SPAWNS IN A DOORWAY, WHOEVER BUILT THE ROOM.
		#
		# `ContentInstantiator._enemy_spawns` pushes an authored room's
		# spawns clear of its openings, and the procedural builders --
		# four of them, each laying its own ring of spawn points --
		# never did: `Vector3(cos(a) * width * 0.3, ...)` clears the
		# wall by `0.2 * width`, which is 1.2 m in a six-metre room and
		# smaller than the doorway it has to clear. One enemy standing
		# in `c002/entry` is what turned `godot-integration` red for
		# three runs, and that one was in an authored room.
		#
		# Applied HERE, in the runtime placement path, because this is
		# the one place every producer's spawns become a body. A room
		# whose producer already cleared them is unchanged: the nudge is
		# a no-op on a point that is already out of every doorway.
		var mouths: Array = []
		for plan: Variant in result.get("doors", []):
			mouths.append((plan as Dictionary).get("position",
					Vector3.ZERO))
		var middle: Vector3 = (result["bounds"] as AABB).position \
				+ (result["bounds"] as AABB).size / 2.0
		for spawn: Dictionary in result.get("enemy_spawns", []):
			var enemy := Enemy.create(spawn["archetype"], theme)
			add_child(enemy)
			enemy.global_position = xform * ContentInstantiator \
					.out_of_any_doorway(spawn["position"], mouths, middle)
			record["enemies"].append(enemy)
			enemy.enemy_died.connect(_on_enemy_died.bind(record))

		# Every Check the room holds, each its own pedestal.
		#
		# CAMPAIGN_SCALE.md 7 lets a large room carry two or three, and
		# each must be earned SEPARATELY -- two ids on one pedestal would
		# be one interaction sending two Checks, which tells the
		# multiworld a player found an item they never reached. Distinct
		# positions are what make them distinct completion edges.
		var locations: Array = []
		var primary: Variant = chamber.get("reward_location_id")
		if primary != null:
			locations.append(int(primary))
		for extra: Variant in chamber.get(
				"additional_reward_location_ids", []) as Array:
			locations.append(int(extra))
		# THE ZONE'S OWN CHECKS, kept where the Zone can be asked about
		# them without the bridge having to call it the active one.
		for location: Variant in locations:
			_zone_locations.append(int(location))

		var anchor: Vector3 = result.get("reward_position", Vector3(0, 0, 1))
		record["rewards"] = []
		for index in locations.size():
			var reward := RewardObject.create(
					int(locations[index]), zone_id, theme)
			add_child(reward)
			# Spread along the room's axis, staying on the walking lane
			# the affordance rule keeps features OFF (see
			# `affordance_driver._a_check_sits_on_the_lane...`). Offsetting
			# sideways instead would push a Check into the band a feature
			# may occupy, and put one behind a rail.
			var offset := Vector3(
					0.0, 0.0, float(index) * REWARD_SPACING)
			reward.global_position = xform * (anchor + offset)
			record["rewards"].append(reward)
			if index == 0:
				record["reward"] = reward

		if record["objective"] == "platform_to_goal":
			var area := Area3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(7.0, 4.0, 3.0)
			shape.shape = box
			area.add_child(shape)
			add_child(area)
			area.global_transform = Transform3D(xform.basis,
					xform * result.get("goal_area_position",
						result["exit_offset"]))
			area.body_entered.connect(
					_on_goal_area_entered.bind(record))

		_chambers.append(record)
	_evaluate_objectives()
	refresh()
	if is_finale and hud != null:
		hud.say_line("finale_open")

## THE OFFER STAGE: THREE PHASES, IN THIS ORDER, AND THE ORDER IS THE
## POINT.
##
## The Zone root is already in the tree -- `setup` put it there -- and
## ONE physics frame is awaited first, because a probe against a body the
## physics server has not registered answers "nothing there", and a
## movement offer blessed by geometry nobody could see is the vacuous
## pass this stage exists to remove.
##
##   PHASE 1, VALIDATE -- every declared offer of EVERY room is purely
##     measured against real geometry, all kinds, whatever the selected
##     mode is. Nothing is constructed and nothing is chosen. The census
##     therefore describes the ROOMS rather than the selection, and every
##     verdict is taken against a Zone with no offer geometry in it.
##   PHASE 2, SELECT -- the package decides which accepted offers it
##     will build, by identity, with every room's verdict already in.
##     One decision for the Zone, not a decision per room as each is
##     measured.
##   PHASE 3, CONSTRUCT -- exactly the selected identities are built,
##     from the verdict phase 1 took. Nothing is re-judged, so no room
##     is ever measured against another room's output, and a second
##     construction into the same room is refused rather than doubled.
##
## MEASURING, CHOOSING AND BUILDING ARE THREE VERBS. Validation once
## returned `consume`, so merely looking at a Zone put a pad and a beam
## into every room that offered one; construction once took a KIND, so
## "build what was chosen" and "build everything that matches" were the
## same call. Nothing here is called "built" unless a node was made, or
## "selected" unless the selector named it.
##
## A DECLINED OFFER IS NOT A BROKEN ZONE. A rail that cannot be built is
## a rail the room plays without -- "a large room whose traversal quietly
## did not appear is the worst version of this failure", so it is said
## out loud and the Zone carries on.
## The player arrives at the anchor the plug named.
##
## The destination is checked against the resolved anchor table rather
## than trusted: a plug naming an anchor this Zone does not have is a
## composition error, and moving the player to the origin would hide it
## as a strange teleport instead of reporting it.
## A Zone-local key, and the intent that records it.
##
## `key_collected` is idempotent by `key_id` because the target set is
## monotone: the same key twice is one key, a resend after a dropped
## connection is the normal case, and neither is an error.
func _on_key_collected(key_id: String) -> void:
	if _keys_held.has(key_id):
		return
	_keys_held[key_id] = true
	BridgeClient.send_intent({"type": "key_collected",
			"zone_id": zone_id, "key_id": key_id})
	_opened_since.clear()
	_open_what_the_keys_allow()
	if hud != null:
		hud.toast(_what_that_key_did(key_id), ZoneKey.tint(key_id), 4.5)

## A physics latch fired in this Zone, and the intent that records it.
##
## THE CLIENT HAS NEVER SENT ONE. `ZoneProgress.latched`, `LatchFired`
## and `record_latch` have been on the bridge since the physics slice
## landed -- monotone, idempotent by `package_id/latch_id`, and refusing
## any latch the committed manifest does not declare -- and every
## `latched` in this lane was prose in a comment. This is the client
## half.
##
## **Only an accepted consequence reaches here.** A machine reports when
## its latch condition is genuinely satisfied, never when a Zone is
## rebuilt from a latch that already fired: §5.4a persists the decision,
## and re-reporting it would be the engine telling the bridge a fact the
## bridge told the engine.
func report_latch(package_id: String, latch_id: String) -> void:
	var ref := "%s/%s" % [package_id, latch_id]
	if _latches_fired.has(ref):
		return
	_latches_fired[ref] = true
	BridgeClient.send_intent({"type": "latch_fired",
			"zone_id": zone_id, "package_id": package_id,
			"latch_id": latch_id})

## A Zone-state variable changed, because a player operated its control.
##
## **P-3's gap, closed from the other side.** This reported nothing
## outward for one checkpoint, because `ZoneProgress.with_macro` existed
## and no message could reach it -- the engine had a selection it could
## not send. The bridge lane's `zone_state_selected` is that message,
## and it is deliberately NOT `latch_fired`: idempotent by
## `(variable_id, state)` and not monotone, because a reversible
## variable going back is the mechanic working rather than a replay to
## be rejected.
##
## Sent on the CHANGE and not on every selection: `ZoneState.select`
## absorbs a re-selection of the state a variable already holds (§19.7
## rule 5), so this signal only fires when something actually moved.
func _on_zone_state_changed(variable_id: String, state: String) -> void:
	zone_state_changes.append([variable_id, state])
	BridgeClient.send_intent({"type": "zone_state_selected",
			"zone_id": zone_id, "variable_id": variable_id,
			"state": state})

## Every change this Zone has seen, in order. Live, not saved: the
## VALUES are what persist, and the sequence that produced them is
## exactly the history `with_macro` overwrites rather than accumulates.
var zone_state_changes: Array = []

## The relationships this Zone actually built.
func zone_state_setters() -> Array:
	return (_zone_state_built.get("setters", []) as Array).duplicate()

func zone_state_readers() -> Array:
	return (_zone_state_built.get("readers", []) as Array).duplicate()

## A declared railway's span locked. The junction has already decided the
## consequence is accepted; this is only the reporting half, and
## `report_latch` is idempotent by `package_id/latch_id`, so a span that
## locks twice in one session still tells the bridge once.
func _on_rail_latch(package_id: String, latch_id: String) -> void:
	report_latch(package_id, latch_id)

## The railways this Zone actually built, for a suite that has to ask
## whether a declaration became a machine.
func rail_junctions() -> Array:
	return (_rail.get("junctions", []) as Array).duplicate()

func rail_carriers() -> Array:
	return (_rail.get("carriers", []) as Array).duplicate()

## Every latch this Zone has reported. A copy: the set is this Zone's.
func latches_fired() -> Dictionary:
	return _latches_fired.duplicate()

## Every latch this Zone should treat as already fired: what came in
## with the snapshot, plus anything reported since it was taken.
##
## UNION, for the same reason keys and stations are a union: an intent
## sent in the same breath as leaving may not be in the snapshot yet,
## both sides are monotone, and taking both can neither lose progress
## nor invent it.
func latches_accepted() -> Array:
	var out := {}
	for ref: Variant in latches_carried:
		out[str(ref)] = true
	for ref: Variant in _latches_fired:
		out[str(ref)] = true
	var refs: Array = out.keys()
	refs.sort()
	return refs

## Every lock the held keys AND capabilities admit, opened at once.
##
## Driven by the key set rather than by touching a door, so a key picked
## up on the far side of the Zone opens its lock without the player
## walking back to watch it happen. Capability gates ride the same path:
## a gate whose capability the player already has is open the moment the
## Zone is built, which is what makes a Zone re-entered WITH the Missile
## simply passable rather than needing a second mechanism.
func _open_what_the_keys_allow() -> void:
	var capabilities := held_capabilities()
	for raw: Variant in _zone_locks:
		if not is_instance_valid(raw):
			continue
		var lock: LockedDoor = raw
		lock.try_open(_keys_held, capabilities)

## What the player can currently do, from the ONE place that knows.
##
## `available_capabilities` on the bridge snapshot is what
## `ActivityRuntime` already reads to decide NOT_YET. A gate asking a
## different oracle would be a second answer to the same question, and
## the two would disagree the first time a loadout changed.
func held_capabilities() -> Dictionary:
	var out := {}
	var available: Variant = BridgeClient.snapshot.get(
			"available_capabilities", [])
	if typeof(available) == TYPE_ARRAY:
		for capability: Variant in available as Array:
			out[str(capability)] = true
	return out

func _on_lock_opened(room: String, socket: String) -> void:
	var ref := "%s/%s" % [room, socket]
	if _locks_open.has(ref):
		return
	_locks_open[ref] = true
	_opened_since.append(room)
	BridgeClient.send_intent({"type": "lock_opened",
			"zone_id": zone_id, "room_id": room, "socket_id": socket})
	# NO TOAST HERE, deliberately. This fires once per LOCK, and one key
	# opening three doors sent three identical "UNLOCKED" cards with no
	# room on any of them -- which is how the owner finished a playtest
	# holding three keys and reporting they had "found no door that uses
	# them". The message is assembled once, by `_on_key_collected`, out
	# of what this collected.

## WHICH ROOMS HAVE BEEN WALKED, for a reader that is not this file.
##
## A copy, so nothing outside can grow the set. Session-only by
## construction: `_rooms_entered` starts empty on every `setup`.
func rooms_entered() -> Dictionary:
	return _rooms_entered.duplicate()

## Which room the body is in right now, or "".
func current_room() -> String:
	return _room_id_of(_current_chamber)

## The room id of a chamber index, for the entered-rooms set.
func _room_id_of(index: int) -> String:
	if index < 0 or index >= _chambers.size():
		return ""
	var chamber: Dictionary = _chambers[index].get("chamber", {})
	return str(chamber.get("id", ""))

## HOW TO NAME A PLACE THE PLAYER HAS BEEN, and how not to name one
## they have not.
##
## A room id is not a label -- the owner read `c018` off a return pad
## and asked what c018 was -- so the chamber's own `type` carries the
## meaning and the id stays for precision. A room the player has NOT
## entered gets neither: naming it would hand out the shape of a route
## they have not found, and this feature is worth less than that.
func _room_label(room_id: String) -> String:
	if room_id == "" or not _rooms_entered.has(room_id):
		return ""
	for record: Dictionary in _chambers:
		var chamber: Dictionary = record.get("chamber", {})
		if str(chamber.get("id", "")) != room_id:
			continue
		var kind := str(chamber.get("type", "")).replace("_", " ")
		return "the %s (%s)" % [kind, room_id] if kind != "" else room_id
	return room_id

## WHAT THAT KEY ACTUALLY DID, in one line.
##
## Four truthful answers and no fifth. A key that opened nothing says
## so, and says WHICH of the two nothings it was, because "no door here
## answers to this" and "the door it opens is already open" send a
## player to two different places.
func _what_that_key_did(key_id: String) -> String:
	var name := "%s KEY" % key_id.to_upper()
	if _opened_since.is_empty():
		var here := 0
		for raw: Variant in _zone_locks:
			if is_instance_valid(raw) and (raw as LockedDoor).key_id \
					== key_id:
				here += 1
		if here == 0:
			return "%s   nothing in this Zone is locked with it" % name
		return "%s   its door here is already open" % name
	# One room may hold more than one lock this key opened; the player
	# cares about PLACES, not about socket count.
	var named: Array[String] = []
	var unseen := 0
	for room: Variant in _opened_since:
		var label := _room_label(str(room))
		if label == "":
			unseen += 1
		elif not named.has(label):
			named.append(label)
	if named.is_empty():
		return "%s   opened %d door%s elsewhere in this Zone" \
				% [name, unseen, "" if unseen == 1 else "s"]
	var where := ", ".join(named)
	if unseen > 0:
		where += " and %d elsewhere" % unseen
	return "%s   opened the way in %s" % [name, where]

## Gates the player cannot open yet, as "room/socket" -> what is missing.
##
## "NOT YET is good gameplay" (§0-bis), and a player who cannot tell
## NOT YET from BROKEN is playing a different, worse game. This is what
## a readout asks.
func gates_not_yet_open() -> Dictionary:
	var capabilities := held_capabilities()
	var out := {}
	for raw: Variant in _zone_locks:
		if not is_instance_valid(raw):
			continue
		var lock: LockedDoor = raw
		var missing := lock.unmet(_keys_held, capabilities)
		if not missing.is_empty():
			out["%s/%s" % [lock.room_id, lock.socket_id]] = missing
	return out

## Screen-level acknowledgement for a finished activity.
##
## Deliberately NOT a new reward or a new rule: the reward already went
## out as `grant_local_reward` from the runtime, keyed by the activity's
## identity so the same completion twice is one grant. This is the part
## that was missing -- telling the player it happened.
func _on_activity_completed(activity_id: String, seconds: float,
		_attempts: int) -> void:
	# THE CONSEQUENCE FIRST, so the one message can carry it.
	#
	# A room may hold more than one activity and they SHARE the station
	# in it: the first solved repairs it and every later one finds it
	# already online. Before this, all of them said the same
	# "<ID> COMPLETE" and the difference was invisible -- so a player
	# who solved the second puzzle in a room had no way to learn whether
	# it had done anything. This says which it was. It grants nothing
	# extra, marks nothing complete and makes nothing compulsory; the
	# local reward each activity already sends is untouched.
	var consequence := _repair_station_for(activity_id)
	if hud != null:
		hud.toast("%s COMPLETE   %.1fs%s"
				% [activity_id.to_upper(), seconds,
				"" if consequence == "" else "   " + consequence],
				Color(0.55, 0.95, 0.75), 3.0)
	if tones != null and tones.has_method("play"):
		# "secret", not "secret_found". The bank keys its chime as
		# `secret`; `secret_found` is a line id in `epsilon_voice.gd`,
		# and an identifier carried between two systems with different
		# vocabularies made `Tones.play` look up a name that is not
		# there and return silently. A solved activity has been mute
		# ever since. `test_every_tone_a_caller_asks_for_exists` now
		# refuses the next one of these.
		tones.play("secret")
	_activity_note = ""

## AND THE OTHER OUTCOME, which had no listener at all.
##
## An attempt that runs out of time clears every element and returns the
## activity to IDLE. With nothing watching `failed`, the only report was
## the geometry going dark, which reads as a bug rather than a reset --
## the owner's words for this were "the game told me nothing".
func _on_activity_progressed(text: String) -> void:
	_activity_note = text if text != "DONE" else ""

func _on_activity_failed(activity_id: String, reason: String) -> void:
	_activity_note = ""
	if hud != null:
		hud.toast("%s FAILED   %s" % [activity_id.to_upper(), reason],
				Color(1.0, 0.55, 0.45), 3.0)
	if tones != null and tones.has_method("play"):
		tones.play("denied")

## A solved puzzle switches on the broken station in its own room.
##
## Only its own room: a Zone with two puzzled station rooms must not have
## one puzzle light both, which is the failure a room-blind match would
## produce and the reason the room is carried at all.
## Returns what to TELL the player about it, or "" when this room has no
## station to repair. Three answers, and the second is the one that was
## missing: this activity repaired it, this activity found it already
## repaired, or there was never one here.
func _repair_station_for(activity_id: String) -> String:
	var room := str(_activity_room.get(activity_id, ""))
	if room == "":
		return ""
	for raw: Variant in _stations:
		var station: WarpStation = raw
		if station.repair_room != room:
			continue
		if station.repair():
			# Repair activates, so the station is now reached and the
			# rest of the reached bookkeeping has to happen exactly as
			# it would have. The note is EMPTY because the completion
			# toast above is carrying it -- two cards for one event is
			# the burst this batch removed from key pickups.
			_station_came_online(station.station_id, "")
			return "STATION %s ONLINE" % station.label_text.to_upper()
		# ALREADY ONLINE, and saying so is the whole point. These
		# activities are alternative ways into the same consequence, and
		# a player who cannot tell that from an independent one with its
		# own payoff will keep looking for a payoff that is not there.
		return "%s was already online" % station.label_text.to_upper()
	return ""

## The next reached station after this one, wrapping.
##
## Held by the controller and not by the stations, because "which
## stations have been reached" is one fact and a copy per station is
## several. Returns "" when this is the only one reached, which is what
## the prompt reads to say so rather than offering a warp to itself.
## A WORKING STATION WAS PRESSED, so somebody should be asked where to.
##
## The controller does not own a screen; it says what the options are
## and `Main` puts them on one. `travel_options` is the single
## eligibility rule and lives on `WarpStation`, so this cannot grow a
## second opinion about which stations are destinations.
func _on_station_panel_requested(from_id: String) -> void:
	var station := _station_by_id(from_id)
	if station == null or not station.is_reached() or station.is_broken():
		return
	travel_panel_requested.emit(from_id, station.label_text,
			WarpStation.travel_options(_stations, from_id))

## Selecting a destination on that panel. ONE warp, through the path a
## station press used to take, so nothing about arriving changed.
func warp_to(from_id: String, to_id: String) -> void:
	_on_warp_requested(from_id, to_id)
	station_warped.emit(from_id, to_id)

## The keys and the opened locks, for whoever is carrying progress out.
func keys_held() -> Dictionary:
	return _keys_held.duplicate()

func locks_opened() -> Dictionary:
	return _locks_open.duplicate()

## Waits for the physics to exist, then measures and sends.
##
## Not awaited by `setup`: the Zone is playable while this runs, and the
## verdict it brings back is what decides whether it stays that way.
func _publish_layout(build: Dictionary) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_measure_layout_evidence(build)
	await _certify_physics(build)
	# THE BOUNDARY BETWEEN CERTIFYING AND SENDING.
	#
	# `_certify_physics` gives up the moment the Zone leaves the tree,
	# which stopped it measuring freed nodes -- and then returned here,
	# where the next line sent the half-measured result anyway. A Zone
	# torn down during settling published a PARTIAL certification under
	# a committed Zone's name, and `_await_verdict` below then sat in a
	# frame loop belonging to a Zone nobody is in, holding and releasing
	# a player who has been replaced. The discarded attempt has to be
	# discarded here too.
	if not is_inside_tree():
		return
	send_layout_result(build)
	await _await_verdict()

## HOLD THE PLAYER UNTIL THE LAYOUT IS ACCEPTED.
##
## A refusal used to change nothing: the bridge logged it, sent a
## notification, and the client went on playing a Zone whose geometry the
## validator had just said does not hold together -- and went on claiming
## its Checks against it. Gameplay waits for the verdict now, and a
## refusal leaves the Zone instead of continuing in it.
##
## A ZONE WITH NO GRAPH IS NOT HELD. There are no edges for the evidence
## to be about, so there is no verdict coming; that Zone is the chain
## that shipped before any of this and it plays exactly as it did.
func _await_verdict() -> void:
	if (zone.get("edges", []) as Array).is_empty():
		layout_verdict = "UNCERTIFIED"
		return
	# `!= null` IS NOT ALIVE. A freed Node is not null in GDScript -- it
	# is a reference that answers every comparison and errors on every
	# call -- so a Zone torn down while its verdict was outstanding put
	# a hold on, or took one off, a player that no longer exists.
	if is_instance_valid(player):
		player.hold(LAYOUT_HOLD)
	# THE PREVIOUS ANSWER IS NOT THIS ONE.
	#
	# A refusal sends the Zone back to be composed again, and the client
	# enters the recomposed Zone and sends a new layout -- while its own
	# snapshot is still carrying `REFUSED` from the round before. This
	# loop read that, announced "layout refused; leaving", and left a
	# Zone the bridge committed a quarter of a second later, with the
	# acceptance hold still on the player.
	#
	# `layout_refusals` counts what the validator has rejected for this
	# Zone, so a REFUSED that has not incremented it is the old answer
	# and is waited past. An ACCEPTED needs no such guard: the only way
	# to be holding a stale one is to be re-entering a Zone whose layout
	# really was accepted, which is the replay path and is the truth.
	var before := int(BridgeClient.active_zone().get(
			"layout_refusals", 0))
	var waited := 0.0
	while waited < VERDICT_TIMEOUT:
		var state := str(BridgeClient.active_zone().get(
				"layout_state", ""))
		if state == "ACCEPTED":
			layout_verdict = state
			if is_instance_valid(player):
				# ONLY THIS CLAIM. Clearing the boolean here released a
				# pause the player had opened while they waited.
				player.release(LAYOUT_HOLD)
			return
		var refusals := int(BridgeClient.active_zone().get(
				"layout_refusals", 0))
		# A refusal clears the active Zone, so the record stops being
		# there at all -- which is the same news arriving a different way.
		if (state == "REFUSED" and refusals > before) \
				or (BridgeClient.active_zone().is_empty()
					and waited > 0.25):
			layout_verdict = "REFUSED"
			push_warning("zone: %s layout refused; leaving" % zone_id)
			layout_refused.emit(zone_id)
			return
		await get_tree().process_frame
		# THE ZONE THIS VERDICT IS ABOUT CAN GO AWAY MID-WAIT. Carrying
		# on would announce a refusal for a Zone nobody is in, and
		# `layout_refused` is what sends the player back to the Hub --
		# from a Zone they have already left, past the replacement they
		# are now standing in.
		if not is_inside_tree():
			return
		waited += get_process_delta_time()
	# NO VERDICT IS NOT AN ACCEPTANCE. A bridge that never answers leaves
	# the player frozen forever, which is worse than the Zone they are
	# standing in; treat silence as a refusal and go back to the Hub.
	layout_verdict = "REFUSED"
	push_warning("zone: %s waited %.1fs for a layout verdict"
			% [zone_id, VERDICT_TIMEOUT])
	layout_refused.emit(zone_id)

## THE CHAINS THIS ZONE BUILT, CERTIFIED. `AMALGAM_BRIDGE.md` §5.6a.
##
## `apertures` says a doorway is a hole; nothing said whether a
## `powered_door` feature's crate can actually be put on its plate in
## the room the composer placed it in. Both are failures a Zone can ship
## with, and neither is visible to the bridge, which has no geometry.
##
## **The engine certifies; the composer only asked.** A chamber declares
## `features: [{tag: "powered_door"}]` and that is intent. What goes on
## the wire here is a `PhysicsPackage` the engine built and the
## `ReplayEvidence` of replaying it three times at exactly the
## manipulation envelope -- the contract's own models, carried in the
## layout proposal that is already committed with the manifest, so
## nothing needed a second carrier.
##
## The previous version of this was a four-word verdict in a key called
## `mechanisms` that `layout_to_json` never forwarded. It measured
## something real and told nobody.
func _certify_physics(build: Dictionary) -> void:
	# THE ZONE CAN GO AWAY WHILE THIS RUNS. Certifying a chain takes
	# seconds and `_publish_layout` is not awaited by anything, so a Zone
	# freed mid-certification leaves the loop measuring nodes that no
	# longer exist. `of_build` stops on that and hands back what it had;
	# leaving `packages` UNSET here is what says the answer is partial,
	# and `_publish_layout` checks the same condition before sending.
	var certified := await ChainCertificate.of_build(
			get_tree(), zone_id, build, self)
	if not is_inside_tree():
		return
	build["packages"] = certified

## Aperture polarity and arrival verdicts, measured and attached.
##
## `apertures` is ARCHITECTURAL: a `LOCKED` door reads as a hole because
## it is one, and the slab standing in it is content. Whether that slab
## currently stops the player is a different question with a different
## answer and is not what this reports.
func _measure_layout_evidence(build: Dictionary) -> void:
	var space := get_world_3d().direct_space_state
	# ONE MEASUREMENT, SHARED. `RoomAudit.measure_layout` is what a
	# played Zone and an offline harness both ask, so a manifest sent
	# from either carries the same evidence measured the same way.
	var evidence := RoomAudit.measure_layout(build, space)
	var apertures: Dictionary = evidence["apertures"]
	for entry: Dictionary in build.get("chambers", []):
		var rid := str((entry["chamber"] as Dictionary).get("id", ""))
		var measured := RoomAudit.aperture_polarity(
				entry["build"] as Dictionary,
				entry["xform"] as Transform3D, space)
		# AND WHAT IS STANDING IN THE ONES THAT DISAGREE.
		#
		# The bridge refuses the whole layout on "door 'c002/entry' is
		# USED and the engine measured it as solid", and that sentence
		# names the door and nothing else -- so a Zone that would not
		# open gave nobody a suspect. The engine is the only side that
		# can see the geometry, so it is the side that says what it saw.
		var blockers := RoomAudit.aperture_blockers(
				entry["build"] as Dictionary,
				entry["xform"] as Transform3D, space)
		for raw_door: Variant in (entry["chamber"] as Dictionary) \
				.get("doors", []):
			var door: Dictionary = raw_door
			var socket := str(door.get("socket_id", ""))
			if str(door.get("usage", "")) == "SEALED":
				continue
			if bool(measured.get(socket, true)):
				continue
			push_warning("zone: door '%s/%s' is %s and measures solid: "
					% [rid, socket, str(door.get("usage", ""))]
					+ str(blockers.get(socket, "nothing the probe could "
						+ "name")))
	build["apertures"] = apertures
	measured_apertures = apertures
	build["arrival_ok"] = evidence["arrival_ok"]
	build["plug_clear"] = evidence["plug_clear"]
	build["plug_placement"] = evidence["plug_placement"]
	measured_placement = evidence["plug_placement"]

## Can a body ARRIVE here? Not "is this space empty".
##
## The first version asked only whether a capsule had room, so an anchor
## over a hole in the floor reported `true` -- a body would appear there
## and fall. `RoomAudit.arrival_is_supported` asks the pair the audit has
## always asked: ground within a step below, and clearance to stand in.
## One measurement, two consumers, so the audit and the wire cannot
## disagree about whether an arrival works.

## THE LAYOUT GOES BACK, which is the half of the exchange that was
## missing. `zone_builder.build()` returned everything the validator
## needs and returned it into Godot, where nothing put it on the wire.
func send_layout_result(build: Dictionary) -> void:
	if zone_id == "":
		return
	var message := {"type": "layout_result", "zone_id": zone_id,
			"layout": ZoneBuilder.layout_to_json(build)}
	# THE IDENTITY THIS BUILD STARTED WITH, and never the current one.
	#
	# Omitted only when the bridge offered none: `LayoutResult` makes it
	# optional so a client older than the field behaves as it always
	# did, and "absent" means "cannot be checked", never "stale". A
	# client that HAD one and left it off would be indistinguishable
	# from that older client, which is why this reads the captured field
	# rather than asking again.
	if proposal_id != "":
		message["proposal_id"] = proposal_id
	if attempt >= 0:
		message["attempt"] = attempt
	BridgeClient.send_intent(message)

## THE BUILD THAT DID NOT HAPPEN, reported for the attempt it belongs to.
##
## The mirror of `send_layout_result`, and deliberately a different
## message. That one carries geometry for the bridge to judge; this one
## says there is none to judge, so the bridge can charge the attempt,
## compose a fresh proposal again inside its budget or park a committed
## one, and stop waiting.
##
## Trimmed here because an over-long reason has already cost this
## project one hang -- a refusal longer than `MAX_TEXT_LEN` made the
## snapshot unserialisable and killed the broadcast that carried it.
## `ZoneBuilder`'s failure reports name rooms and sizes and are not
## bounded, so the bound is applied at the boundary rather than hoped
## for. The bridge trims again; neither side trusts the other.
func send_build_failed(reason: String) -> void:
	if zone_id == "":
		return
	var said := reason
	if said.length() > Constants.MAX_TEXT_LEN:
		said = said.substr(0, Constants.MAX_TEXT_LEN - 1) + "\u2026"
	var message := {"type": "build_failed", "zone_id": zone_id,
			"reason": said}
	# THE IDENTITY THIS BUILD STARTED WITH, on the same terms as
	# `send_layout_result`: captured at the top of `setup`, echoed here,
	# and omitted only when the bridge offered none.
	if proposal_id != "":
		message["proposal_id"] = proposal_id
	if attempt >= 0:
		message["attempt"] = attempt
	BridgeClient.send_intent(message)

## Which stations are online, for whoever is carrying progress out.
func stations_reached() -> Dictionary:
	return _stations_reached.duplicate()

func _station_by_id(id: String) -> WarpStation:
	for raw: Variant in _stations:
		var station: WarpStation = raw
		if station.station_id == id:
			return station
	return null

func _on_station_reached(station_id: String) -> void:
	_station_came_online(station_id, "STATION ONLINE")

## One path onto the reached set, whether a player walked onto the pad or
## solved the puzzle that repaired it. Two paths would be two chances to
## forget the intent or the resume anchor.
func _station_came_online(station_id: String, note: String) -> void:
	if _stations_reached.has(station_id):
		return
	_stations_reached[station_id] = true
	# The station a player last stood at is where a resume puts them.
	resume_anchor = station_id
	BridgeClient.send_intent({"type": "station_reached",
			"zone_id": zone_id, "station_id": station_id})
	if hud != null and note != "":
		hud.toast(note, Color(0.45, 1.0, 0.8), 2.5)

## Travel only. A station provides travel and save and NOT loadout
## editing (§30.12.4), so nothing here opens a slot or touches a
## capability the entry check validated.
func _on_warp_requested(from_id: String, to_id: String) -> void:
	var to := _station_by_id(to_id)
	if to == null or not to.is_reached():
		push_error("zone: warp to '%s' from '%s' is not a reached station"
				% [to_id, from_id])
		return
	player.global_position = to.global_position + Vector3(0, 0.3, 2.0)
	player.velocity = Vector3.ZERO
	resume_anchor = to_id
	if hud != null:
		hud.toast("WARPED TO %s" % to.label_text, Color(0.45, 1.0, 0.8))

func _on_plug_traversed(edge_id: String, destination: String) -> void:
	if not _zone_anchors.has(destination):
		push_error("zone: plug '%s' returns to unknown anchor '%s'"
				% [edge_id, destination])
		return
	var to: Vector3 = _zone_anchors[destination]
	player.global_position = to + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	if hud != null:
		hud.toast("RETURNED", Color(0.42, 0.85, 1.0))

func _validate_offers(chambers: Array) -> void:
	await get_tree().physics_frame
	offer_census = {"declared": 0, "judged": 0, "accepted": 0,
			"selected": 0, "built": 0, "declined": 0, "refused": 0,
			"judged_before_first_build": 0}
	offer_selection = []

	# ---- PHASE 1: measure every room, build nothing ----
	var measured: Array = []
	for entry: Variant in chambers:
		var record: Dictionary = entry
		var node := record.get("node") as Node3D
		var build: Dictionary = record.get("build", {})
		if node == null or build.is_empty():
			continue
		var chamber: Dictionary = record.get("chamber", {})
		var named := str(chamber.get("id", "chamber"))
		var declared: int = (build.get("offers", []) as Array).size()
		offer_census["declared"] += declared
		var seen := OfferBinding.validate(node, build, named)
		var refused := bool(seen.get("refused", false))
		var accepted: Array = seen["accepted"]
		var turned_down: int = (seen["declined"] as Array).size()
		offer_census["judged"] += accepted.size() + turned_down
		offer_census["accepted"] += accepted.size()
		offer_census["declined"] += turned_down
		if refused:
			offer_census["refused"] += 1
		if refused or turned_down > 0:
			push_warning("offers: %s" % OfferBinding.summarise(named, seen))
		# WHAT ACTUALLY BUILT, not what was asked for (3B). This read
		# `chamber["shell_id"]` -- the INPUT -- so a chamber whose
		# authored shell was refused as unknown, incompatible or pending
		# still reported that shell's name, and every consumer of this
		# record called the procedural room authored. A fallback room
		# does not become an authored room because its input still names
		# one; `ContentInstantiator` stamps what happened and this reads
		# the stamp.
		var resolution: Dictionary = build.get("shell_resolution", {})
		measured.append({"chamber": named, "node": node,
				"shell": str(resolution.get("resolved", "")),
				"requested": str(resolution.get("requested", "")),
				"builder": str(resolution.get(
					"build", ContentInstantiator.BUILD_PROCEDURAL)),
				"reason": str(resolution.get("reason", "")),
				"declared": declared, "accepted": accepted,
				"declined": turned_down, "refused": refused})
	# Every room now has a verdict, and no node has been constructed.
	offer_census["judged_before_first_build"] = measured.size()

	# ---- PHASE 2: choose, once, with every verdict in hand ----
	offer_selection = MovementSelection.select(movement_package, measured)
	offer_census["selected"] = offer_selection.size()

	# ---- PHASE 3: build exactly what was chosen ----
	for entry: Variant in measured:
		var room: Dictionary = entry
		var chosen := MovementSelection.offers_for(
				str(room["chamber"]), offer_selection)
		var made := 0
		if not chosen.is_empty() and not bool(room["refused"]):
			var work := OfferBinding.construct_selected(
					room["node"] as Node3D, room["accepted"] as Array,
					chosen, str(room["chamber"]))
			if bool(work.get("refused", false)):
				push_warning("offers: %s refused construction -- %s"
						% [str(room["chamber"]), str(work["declined"])])
			else:
				made = (work["built"] as Array).size()
				offer_census["built"] += made
		Telemetry.room(str(room["chamber"]), str(room["shell"]),
				movement_package, int(room["declared"]),
				(room["accepted"] as Array).size() + int(room["declined"]),
				(room["accepted"] as Array).size(), chosen.size(),
				int(room["declined"]), made, bool(room["refused"]),
				str(room["requested"]), str(room["reason"]))
	Telemetry.selection(movement_package, offer_selection)
	Telemetry.zone_offers(zone_id, movement_package, offer_census)

func _objective_of(chamber: Dictionary) -> String:
	# A corridor has no objective; a reward inside one is implicitly
	# reach_reward. treasure_room defaults reach_reward too.
	return str(chamber.get("objective", "reach_reward"))

## The first blow of a fight latches which room it is about; every later
## blow in the same fight leaves that alone.
func _note_engagement() -> void:
	if _encounter_chamber < 0:
		_encounter_chamber = _current_chamber
	playtime.note_engagement(_live_enemy_count())


func _on_enemy_died(enemy: Enemy, record: Dictionary) -> void:
	var remaining := _live_enemy_count()
	playtime.note_enemy_died(remaining)
	if remaining <= 0:
		_encounter_chamber = -1
	if tones != null:
		tones.play("hit")
	_quiet_time = 0.0                # a fight is not a quiet stretch
	# Objectives resolve BEFORE anything is said, so a one-enemy room says
	# "cleared" rather than having first_blood claim the kill and the
	# throttle swallow the line that actually mattered.
	var cleared := false
	if record["objective"] == "kill_all" and not record["satisfied"]:
		_evaluate_objectives()
		cleared = record["satisfied"]
	if hud == null:
		return
	if is_finale and enemy.archetype == "brute":
		# The finale's boss outranks both of the others.
		hud.say_line("finale_brute")
		_first_kill_seen = true
	elif cleared:
		hud.say_line("room_cleared")
		_first_kill_seen = true
	elif not _first_kill_seen:
		_first_kill_seen = true
		hud.say_line("first_blood")

## Walked into a secret. Says one thing, once, and stops watching: a ledge
## you are standing on should not keep congratulating you.
func _on_secret_entered(body: Node3D, area: Area3D) -> void:
	if not (body is Player):
		return
	area.set_deferred("monitoring", false)
	if tones != null:
		tones.play("secret")
	if hud != null:
		hud.say_line("secret_found")

## Walks a freshly built Zone for grouped nodes. `get_tree()` would also
## sweep up the previous Zone's nodes, which are queue_freed but still in
## the tree for the rest of the frame.
static func _collect_group(node: Node, group: String) -> Array[Node]:
	var out: Array[Node] = []
	if node.is_in_group(group):
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_group(child, group))
	return out

func _on_goal_area_entered(body: Node3D, record: Dictionary) -> void:
	if body is Player and not record["satisfied"]:
		record["satisfied"] = true          # latches for this instance
		_push_objective_state(record)

## Enemies still standing in the room this fight is ABOUT.
##
## Zone-wide until playtest 2.5, on the theory that a fight spilling
## between two rooms should count once. The whole Zone is built at once,
## so a Zone-wide count only reaches zero when the LAST enemy anywhere
## dies -- which means exactly one encounter could ever close, at the end
## of the Zone. The 23-room baseline run has ten arenas and recorded ONE
## encounter of 105 seconds: nine fights happened and none were timed.
##
## Scoped to the chamber the fight started in instead. Leaving the room
## and coming back still resolves it when the room is finally cleared,
## which keeps the spilling case the old comment wanted; what it no
## longer does is wait for a room at the other end of the Zone.
func _live_enemy_count() -> int:
	var index := _encounter_chamber if _encounter_chamber >= 0 \
			else _current_chamber
	if index < 0 or index >= _chambers.size():
		return 0
	var alive := 0
	for enemy in (_chambers[index]["enemies"] as Array):
		if is_instance_valid(enemy) and not enemy._dead:
			alive += 1
	return alive

func _evaluate_objectives() -> void:
	for record: Dictionary in _chambers:
		if record["satisfied"]:
			continue
		match record["objective"]:
			"reach_reward":
				record["satisfied"] = true
			"kill_all":
				var alive := false
				for enemy in record["enemies"]:
					if is_instance_valid(enemy) and not enemy._dead:
						alive = true
						break
				record["satisfied"] = not alive
			"platform_to_goal":
				pass                        # area callback drives it
		_push_objective_state(record)

func _push_objective_state(record: Dictionary) -> void:
	var reward: RewardObject = record["reward"]
	if reward != null:
		reward.set_objective_satisfied(record["satisfied"])

## Called on every campaign snapshot while this Zone is loaded.
func refresh() -> void:
	for record: Dictionary in _chambers:
		var reward: RewardObject = record["reward"]
		if reward != null:
			reward.refresh_from_snapshot()
	# THE ZONE'S OWN CHECKS DECIDE, not whether the bridge still calls
	# this Zone active.
	#
	# "No active Zone means this one completed" was sound while the only
	# way to stop being active was to finish. It is not any more: a Zone
	# walked out of with work outstanding goes DORMANT and
	# `active_zone_id` is cleared, so the old inference opened the exit
	# portal on a Zone the player had barely started -- and the label read
	# "0 CHECKS REMAIN" because the outstanding count came from the same
	# empty record.
	var outstanding := 0
	for location: int in _zone_locations:
		if not BridgeClient.is_checked(location):
			outstanding += 1
	var complete := outstanding == 0
	_exit_portal.set_unlocked(complete, outstanding)
	# The unlock is pushed on every snapshot, so remark on the edge only.
	if complete and _portal_was_locked and hud != null:
		hud.say_line("portal_open")
	_portal_was_locked = not complete

## Connector segments belong to no chamber, so the current chamber holds
## until the next one's bounds are genuinely entered — hysteresis for free.
func _track_chamber() -> void:
	if player == null:
		return
	for index in _chambers.size():
		var bounds: AABB = _chambers[index].get("bounds", AABB())
		if bounds.has_point(player.global_position):
			if index != _current_chamber:
				_current_chamber = index
				_rooms_entered[_room_id_of(index)] = true
				playtime.enter_chamber(index)
				playtime.enter_chamber_activities(index)
				chamber_entered.emit(index)
			return

func _process(delta: float) -> void:
	_track_chamber()
	playtime.tick(delta)
	if hud == null or player == null:
		return
	var claimed := 0
	var total := 0
	# Nearest actionable reward wins; a reward whose objective is already
	# satisfied outranks one that still needs clearing, so the waypoint
	# always names the thing you can finish soonest.
	var best: RewardObject = null
	var best_rank := 99
	var best_distance := INF
	for record: Dictionary in _chambers:
		var reward: RewardObject = record["reward"]
		if reward == null:
			continue
		total += 1
		if reward.state == "confirmed":
			claimed += 1
			continue
		var rank := 0 if reward.state == "available" else 1
		var distance := player.global_position.distance_to(
				reward.global_position)
		if rank < best_rank or (rank == best_rank and distance < best_distance):
			best = reward
			best_rank = rank
			best_distance = distance

	var line := ""
	if total > 0:
		line = "CHECKS %d/%d CLAIMED" % [claimed, total]
	# THE ACTIVITY IN HAND, alongside the Zone's standing count. Cleared
	# the moment it completes or fails, so the line never advertises an
	# attempt that is over.
	if _activity_note != "":
		line = ("%s   ·   %s" % [line, _activity_note]) if line != "" \
				else _activity_note
	hud.set_objective_text(line)

	# A long stretch with nothing claimed usually means the player is lost
	# or exploring; either way it is the one moment a designer's aside is
	# welcome rather than an interruption.
	if claimed != _last_claimed:
		if claimed > _last_claimed and _last_claimed >= 0:
			playtime.note_check_confirmed()
		_last_claimed = claimed
		_quiet_time = 0.0
	else:
		_quiet_time += delta
		if _quiet_time >= _QUIET_BEFORE_ASIDE:
			_quiet_time = 0.0
			hud.say_line("long_walk")

	if best != null:
		var label := "CHECK %03d" % (best.location_id % 1000)
		if best.state == "sending":
			hud.set_waypoint(best.global_position, label + " · SENDING",
					Color(1.0, 0.9, 0.4))
		elif best.state == "available":
			hud.set_waypoint(best.global_position, label + " · READY",
					Color(0.45, 1.0, 0.9))
		else:
			hud.set_waypoint(best.global_position, label,
					Color(0.72, 0.78, 0.85))
	elif _exit_portal != null and _exit_portal.unlocked:
		hud.set_waypoint(_exit_portal.global_position + Vector3.UP * 2.0,
				"EXIT", Color(0.5, 1.0, 0.6))
	else:
		hud.clear_waypoint()

## Every Check THIS Zone holds, confirmed. Asked of the Zone's own
## chambers for the same reason the portal is: a Zone that is not the
## active one is not thereby a finished one.
func _all_checks_confirmed() -> bool:
	for location: int in _zone_locations:
		if not BridgeClient.is_checked(location):
			return false
	return true

## The Zone's outer bounds in world space, or null before it is built.
## Returning null rather than a zero AABB matters: an empty box would read
## as "nowhere is inside the level" and refuse every blink.
func world_bounds() -> Variant:
	return _world_bounds if _has_bounds else null
