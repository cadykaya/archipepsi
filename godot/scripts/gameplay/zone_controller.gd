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
## The player moved into a different chamber's bounds — the rule engine's
## `chamber_enter` event. Fires for the first chamber on the first frame.
signal chamber_entered(index: int)

var zone: Dictionary = {}
var zone_id := ""
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
## MONOTONE, and that is what makes a resume safe. A Zone's key set and
## its opened-lock set only ever grow, so a reload can never put the
## player back behind a door they already opened.
var _keys_held := {}
var _locks_open := {}
var _zone_locks: Array = []
var _stations: Array = []
## Reached-ness is progress, so this only ever grows. `resume_anchor` is
## the exception the contract names: a POSITION, overwritten rather than
## accumulated, and losing it costs a walk rather than a run.
var _stations_reached := {}
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
	var theme: String = zone.get("theme", "void_glitch")
	var build := ZoneBuilder.build(zone)
	# A ZONE THAT COULD NOT BE LAID OUT IS NOT A ZONE. `ZoneBuilder`
	# reports a routing failure rather than attaching a room on top of
	# another one, and the honest thing to do with that report is to
	# refuse the Zone -- not to enter a level whose Check is inside a
	# wall. `layout_failed` is what a caller and the suites read.
	if build.has("failed"):
		layout_failed = str(build["failed"])
		push_error("zone: %s could not be laid out -- %s"
				% [zone_id, layout_failed])
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
	for raw: Variant in build.get("plugs", []):
		var plug: ReturnPlug = raw
		plug.traversed.connect(_on_plug_traversed)
	for raw_key: Variant in build.get("keys", []):
		var key: ZoneKey = raw_key
		key.collected.connect(_on_key_collected)
	_stations = build.get("stations", [])
	for raw_station: Variant in _stations:
		var station: WarpStation = raw_station
		station.reached.connect(_on_station_reached)
		station.warp_requested.connect(_on_warp_requested)
		# The station asks the controller where E goes, rather than each
		# station keeping its own copy of who has been reached.
		station.cycle = _next_reached
		# ALREADY ONLINE FROM A PREVIOUS VISIT. Reached-ness is progress
		# and progress is monotone, so a station a player switched on
		# before they walked out does not switch off behind them.
		if stations_online.has(station.station_id):
			# A station the player repaired stays repaired: the puzzle
			# was solved, and re-entering the Zone does not unsolve it.
			station.repair()
			station.mark_reached()
			_stations_reached[station.station_id] = true
	_zone_locks = build.get("locks", [])
	for raw_lock: Variant in _zone_locks:
		var lock: LockedDoor = raw_lock
		lock.opened.connect(_on_lock_opened)

	player = Player.create()
	add_child(player)
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
				# WHICH ROOM A PUZZLE IS IN, so a broken station in that
				# room can be repaired by solving it. Kept here rather
				# than re-derived from the activity id, because the id
				# format is `Activities.build`'s business and agreeing
				# with it from a distance is how the two drift apart.
				_activity_room[runtime.activity_id] = runtime.room_id

		for spawn: Dictionary in result.get("enemy_spawns", []):
			var enemy := Enemy.create(spawn["archetype"], theme)
			add_child(enemy)
			enemy.global_position = xform * spawn["position"]
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
	if hud != null:
		hud.toast("%s KEY" % key_id.to_upper(),
				ZoneKey.tint(key_id), 3.0)
	_open_what_the_keys_allow()

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
	BridgeClient.send_intent({"type": "lock_opened",
			"zone_id": zone_id, "room_id": room, "socket_id": socket})
	if hud != null:
		hud.toast("UNLOCKED", Color(0.6, 1.0, 0.7), 2.5)

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
	if hud != null:
		hud.toast("%s COMPLETE   %.1fs"
				% [activity_id.to_upper(), seconds],
				Color(0.55, 0.95, 0.75), 3.0)
	if tones != null and tones.has_method("play"):
		tones.play("secret_found")
	_repair_station_for(activity_id)

## A solved puzzle switches on the broken station in its own room.
##
## Only its own room: a Zone with two puzzled station rooms must not have
## one puzzle light both, which is the failure a room-blind match would
## produce and the reason the room is carried at all.
func _repair_station_for(activity_id: String) -> void:
	var room := str(_activity_room.get(activity_id, ""))
	if room == "":
		return
	for raw: Variant in _stations:
		var station: WarpStation = raw
		if station.repair_room != room or not station.repair():
			continue
		# Repair activates, so the station is now reached and the rest of
		# the reached bookkeeping has to happen exactly as it would have.
		_station_came_online(station.station_id, "STATION REPAIRED")

## The next reached station after this one, wrapping.
##
## Held by the controller and not by the stations, because "which
## stations have been reached" is one fact and a copy per station is
## several. Returns "" when this is the only one reached, which is what
## the prompt reads to say so rather than offering a warp to itself.
func _next_reached(from_id: String) -> String:
	var order: Array[String] = []
	for raw: Variant in _stations:
		var station: WarpStation = raw
		if station.is_reached():
			order.append(station.station_id)
	if order.size() < 2:
		return ""
	var at := order.find(from_id)
	if at < 0:
		return order[0]
	return order[(at + 1) % order.size()]

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
	if hud != null:
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
	# The bridge auto-completes the Zone when its last Check confirms; the
	# snapshot then reports no active zone (or a different one). That is the
	# exit portal's unlock signal.
	var active := BridgeClient.active_zone()
	var complete: bool = active.is_empty() \
			or active.get("zone_id") != zone_id \
			or _all_checks_confirmed()
	var outstanding := 0
	for location in active.get("allocated_location_ids", []):
		if not BridgeClient.is_checked(int(location)):
			outstanding += 1
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

	if total > 0:
		hud.set_objective_text("CHECKS %d/%d CLAIMED" % [claimed, total])
	else:
		hud.set_objective_text("")

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

func _all_checks_confirmed() -> bool:
	var active := BridgeClient.active_zone()
	if active.is_empty():
		return true
	for location in active.get("allocated_location_ids", []):
		if not BridgeClient.is_checked(int(location)):
			return false
	return true

## The Zone's outer bounds in world space, or null before it is built.
## Returning null rather than a zero AABB matters: an empty box would read
## as "nowhere is inside the level" and refuse every blink.
func world_bounds() -> Variant:
	return _world_bounds if _has_bounds else null
