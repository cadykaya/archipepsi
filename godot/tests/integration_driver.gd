extends Node
## Full-campaign integration driver against a LIVE bridge (mock AP,
## fallback Epsilon): plays the whole game headlessly.
##
## Pass 1 (detailed): first zone with objective-gating assertions
## (tests 58/59), echo grant, equip.
## Pass 2 (campaign): loops zones to the finale and postgame, buying shop
## stock when affordable (with a double-buy refusal probe — test O),
## until ALL_CHECKS_CLEARED.
##
##     make bridge-mock &
##     godot --headless --path godot -- --integration-test

var failures := 0
var _bought_once := false
var _double_buy_probed := false
var _error_count := 0
## S9 vacuity guards. A campaign whose Zones happened to carry no
## features would sail through every affordance assertion above having
## checked nothing.
var _affordances_seen := 0
var _local_rewards_earned := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	BridgeClient.error_received.connect(
			func(_err: Dictionary) -> void: _error_count += 1)
	_run()

func _finish(code: int) -> void:
	print("GODOT INTEGRATION %s" % ("OK" if code == 0 else "FAILED"))
	get_tree().quit(code)

func _await_condition(what: String, predicate: Callable,
		timeout := 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	_check(false, "timed out waiting for " + what)
	return false

func _run() -> void:
	await get_tree().process_frame
	if not await _await_condition("bridge connection",
			func() -> bool: return BridgeClient.online, 10.0):
		_finish(1)
		return
	print("bridge online")

	BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await_condition("ZONE_AVAILABLE",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_AVAILABLE"):
		_finish(1)
		return

	# ---- ONE CONTROL, AT THE SCALE ITS SUBJECT NEEDS --------------------
	#
	# `make godot-integration` runs a whole campaign at PROTOTYPE scale,
	# where a Zone is three rooms -- and three rooms cannot carry a
	# branch, so they carry no return device and there is no host to
	# bar. Measured: four consecutive Zones with no plug at all. The
	# re-selection journey needs a branched Zone, so `make
	# godot-return-journey` runs THIS DRIVER against a bridge started at
	# `--mock-scale=default`, and runs that one control. Same harness,
	# same helpers, same live bridge; the only difference is the size of
	# the Zones the campaign hands out.
	if OS.get_cmdline_user_args().has("--return-journey"):
		var travelled := await _test_reselection_and_return_journey()
		print("  %d assertion failure(s) in the re-selection journey"
				% failures)
		_finish(0 if travelled and failures == 0 else 1)
		return

	_check(BridgeClient.snapshot.get("scouted", []).size() == 30,
			"30 locations scouted")
	await _check_hub_builds()
	_check_enemy_silhouettes()
	_check_hit_confirmation()
	_check_epsilon_voice()
	_test_reveal_splits_the_two_halves()
	_check_input_bindings()
	_check_camera_feel()
	_check_empty_slot_claims_no_world()
	_check_theme_agreement()

	if not await _play_one_zone(true):
		_finish(1)
		return

	# ---- The refusal control, before the campaign runs on ----------------
	if not await _test_a_refused_layout_is_not_playable():
		_finish(1)
		return
	# and the Zone it left recomposed is then played normally.
	if not await _play_one_zone(false, true):
		_finish(1)
		return

	# ---- The lifetime control: a Zone discarded mid-certification --------
	if not await _test_a_zone_survives_being_torn_down_mid_certification():
		_finish(1)
		return

	# ---- The recovery control: a Zone that can never be built ------------
	if not await _test_a_failed_zone_is_discarded_and_its_checks_come_back():
		_finish(1)
		return
	# AND THE ZONE IT ASKED FOR IS PLAYED, not left standing. The control
	# proves the campaign can generate again after a discard, which
	# leaves a Zone READY -- and the pass below only knows how to act on
	# ZONE_AVAILABLE and FINALE_ONLY, so a READY Zone it never asked for
	# spins it forever waiting for a mode nobody is going to send.
	if not await _play_one_zone(false, true):
		_finish(1)
		return

	# ---- Pass 2: play the campaign to the end -----------------------------
	var zones_played := 2
	var stock_ever_seen := false
	while zones_played < 40:
		var mode := BridgeClient.hub_mode()
		if mode == "ALL_CHECKS_CLEARED":
			break
		if mode == "WAITING_FOR_AP":
			# Mock AP only delivers on checks; this should clear itself as
			# deliveries land. Give it a moment.
			await _await_condition("WAITING_FOR_AP to clear",
					func() -> bool:
						return BridgeClient.hub_mode() != "WAITING_FOR_AP",
					10.0)
			continue
		if not BridgeClient.snapshot.get("shop", {}).get("stock",
				[]).is_empty():
			stock_ever_seen = true
			await _try_shop_purchase()
		if mode in ["ZONE_AVAILABLE", "FINALE_ONLY"]:
			if not await _play_one_zone(false):
				_finish(1)
				return
			zones_played += 1
			continue
		await get_tree().process_frame

	var snapshot := BridgeClient.snapshot
	_check(BridgeClient.hub_mode() == "ALL_CHECKS_CLEARED",
			"campaign reaches ALL_CHECKS_CLEARED (after %d zones)"
			% zones_played)
	_check(snapshot.get("checked_location_ids", []).size() == 30,
			"all 30 checks confirmed")
	_check(bool(snapshot.get("hub", {}).get("goal_sent", false)),
			"goal reported")
	var foreign := 0
	for scout: Dictionary in snapshot.get("scouted", []):
		if not scout.get("recipient_is_self", false):
			foreign += 1
	var interpretations: Array = snapshot.get("interpretations", [])
	# GDScript has no implicit adjacent-string concatenation; the `+` is
	# load-bearing, not style.
	_check(interpretations.size() == foreign,
			("%d foreign checks -> %d interpretations, none missing, "
			+ "none duplicated") % [foreign, interpretations.size()])
	# The log is the save; the fold is what the game plays. Both have to be
	# whole, and the sequence has to be the unique, gapless thing the
	# ordering depends on.
	var seqs: Array = []
	for entry: Dictionary in interpretations:
		seqs.append(int(entry.get("interpretation_seq", -1)))
	seqs.sort()
	var expected_seqs: Array = []
	for i in interpretations.size():
		expected_seqs.append(i)
	_check(seqs == expected_seqs,
			"interpretation_seq is unique and gapless across the campaign")
	# The two halves of the snapshot elision, checked together on a real
	# campaign rather than on a mock: the bridge DID stop re-sending the
	# lifetime Echo log (or this counter is zero and the checks above are
	# proving nothing), and the log this client holds is still whole (or
	# the checks above have already failed).
	# Combat timing, measured rather than assumed. Playtest 2.5's Zone had
	# ten arenas and reported ONE encounter, because the live-enemy count
	# an encounter closes on was ZONE-wide: it could only reach zero when
	# the last enemy anywhere died, so nine fights were never timed.
	var timings: Array = []
	for intent: Dictionary in BridgeClient.sent_intents:
		if intent.get("type", "") == "zone_timing":
			timings.append(intent)
	var fights := 0
	var hoggers := 0
	for t: Dictionary in timings:
		var seconds: Array = t.get("encounter_seconds", [])
		fights += seconds.size()
		for one in seconds:
			# The old bug's signature: a single "encounter" covering most
			# of the Zone, because it started at the first blow and could
			# not close until the Zone ran out of enemies.
			if float(one) > float(t.get("elapsed_seconds", 0.0)) * 0.8:
				hoggers += 1
	print("integration: %d zone timings, %d encounters, %d Zone-spanning"
			% [timings.size(), fights, hoggers])
	_check(timings.size() > 0, "no zone_timing intent was ever sent")
	# NOT asserted: `fights > 0`. This driver clears Zones without the
	# player ever landing a blow, so no encounter is ever started and the
	# count is honestly zero. Encounter TIMING therefore still has no
	# automated coverage -- recorded here as a known gap rather than
	# asserted as a pass. What is covered is the shape below, which is
	# what the Zone-wide-count bug produced.
	_check(hoggers == 0,
			"%d encounter(s) covered over 80%% of their Zone; that is the "
			% hoggers + "Zone-wide live-enemy count reappearing")

	_check(BridgeClient.elided_snapshot_count > 0,
			"the bridge elided the unchanged Echo log %d times"
			% BridgeClient.elided_snapshot_count)
	# Checked continuously rather than here: the log is whole again on
	# every snapshot that carries it, so a reattach that never happened is
	# invisible by the end of the campaign. Only a client watching each
	# snapshot as it lands can see the archive go briefly empty.
	_check(not BridgeClient.echo_log_shrank,
			"the Echo log never went backwards across %d snapshots"
			% BridgeClient.elided_snapshot_count)
	# NOT "a component per interpretation" any more: since S6 an
	# interpretation may EVOLVE what is owned instead of adding to it, so
	# counting components would fail exactly when dispositions work. The
	# invariant that assertion was reaching for survives intact and is
	# stronger: every interpretation must have LANDED somewhere, which the
	# fold records as its sequence appearing in some component's
	# provenance. Nothing silently dropped, nothing double-counted.
	var credited: Dictionary = {}
	for entry: Dictionary in BridgeClient.mechanics().get("owned", []):
		for link: Dictionary in entry.get("provenance", []):
			credited[int(link.get("interpretation_seq", -1))] = true
	var uncredited: Array = []
	for seq in seqs:
		if not credited.has(seq):
			uncredited.append(seq)
	_check(uncredited.is_empty(),
			"every interpretation left a mark on the fold (uncredited: %s)"
			% str(uncredited))
	# The mock seed deterministically holds Estus Shard and Power Star as
	# foreign checks, so a full campaign always grants resource channels
	# (S3) and rules (S4). This is the end-to-end proof the pipeline needs:
	# fallback -> grant -> fold -> snapshot, in the shipped campaign rather
	# than a fixture.
	var owned_kinds: Dictionary = {}
	for entry: Dictionary in BridgeClient.mechanics().get("owned", []):
		var kind := str(entry.get("component", {}).get("kind", ""))
		owned_kinds[kind] = int(owned_kinds.get(kind, 0)) + 1
	_check(int(owned_kinds.get("resource", 0)) >= 1,
			"the campaign owns at least one folded resource channel")
	_check(int(owned_kinds.get("rule", 0)) >= 1,
			"the campaign owns at least one folded rule")
	_check(BridgeClient.mechanics().get("channel_order", []).size() >= 1,
			"the fold assigned the resource a HUD channel")
	# S5: the mock seed's Magic Meter and Stamina Ring make powered
	# actions, so a full campaign ends with a real link graph — the button
	# actually spends the bar it arrived with.
	var powers := 0
	for link: Dictionary in BridgeClient.mechanics().get("links", []):
		if str(link.get("link", "")) == "powers":
			powers += 1
	_check(powers >= 1, "the campaign owns at least one powers link")
	# S6: the mock seed pairs items whose verbs collide (Wing Cap then
	# Metal Cap, REP then Fresh Rep), so a full campaign evolves rather
	# than only accumulating — the fold reports it as an Mk above I with a
	# provenance chain naming every item responsible.
	var dispositions := 0
	for entry: Dictionary in interpretations:
		for operation: Dictionary in entry.get("operations", []):
			if str(operation.get("op", "")) != "create":
				dispositions += 1
	var evolved := 0
	var longest_chain := 0
	for entry: Dictionary in BridgeClient.mechanics().get("owned", []):
		if int(entry.get("mk", 1)) > 1:
			evolved += 1
		longest_chain = maxi(longest_chain,
				int(entry.get("provenance", []).size()))
	# S7: a campaign that only ever fills RMB has not tested four slots.
	# The mock seed's items declare mobility and utility verbs, so a full
	# run should reach more than one — and every Action it owns must
	# declare a slot that has a key.
	var slots_used: Dictionary = {}
	for entry: Dictionary in BridgeClient.mechanics().get("owned", []):
		var component: Dictionary = entry.get("component", {})
		if str(component.get("kind", "")) != "action":
			continue
		var slot := str(component.get("slot", ""))
		slots_used[slot] = true
		_check(slot in Constants.SLOT_NAMES,
				"Action %s declares a real slot (%s)"
				% [component.get("component_id", "?"), slot])
	_check(slots_used.size() >= 2,
			"the campaign's Actions reach more than one slot (%s)"
			% str(slots_used.keys()))
	# S10: every interpretation in a finished campaign read its item as
	# something, and labelled itself truthfully. Before S10 the fallback
	# shipped an empty concept tuple and a hardcoded "literal", so §15's
	# chain was unexercised by exactly this run.
	var modes_seen: Dictionary = {}
	for interpretation: Dictionary in BridgeClient.snapshot.get(
			"interpretations", []):
		var item := str(interpretation.get("source_item_name", "?"))
		var concepts: Array = interpretation.get("concepts", [])
		_check(not concepts.is_empty(),
				"'%s' was read as something (§15)" % item)
		var mode := str(interpretation.get("mode", ""))
		modes_seen[mode] = true
		# The mode has to be earned: the archive shows it as "how Epsilon
		# read it", so one the operations do not support is a lie.
		var ops: Dictionary = {}
		var made: Dictionary = {}
		for operation: Dictionary in interpretation.get("operations", []):
			ops[str(operation.get("op", ""))] = true
			if str(operation.get("op", "")) == "create":
				made[str(operation.get("component", {}).get("kind", ""))] = true
		var touches := ops.has("link") or ops.has("merge") or ops.has("modify")
		if mode == "systemic":
			_check(touches or made.has("rule"),
					"'%s' claims systemic and earns it" % item)
		elif mode == "literal":
			_check(not touches and made.size() <= 1 and made.has("action"),
					"'%s' claims literal and earns it" % item)
	_check(modes_seen.size() >= 2,
			"a full campaign reads items in more than one mode (%s)"
			% str(modes_seen.keys()))
	_check(dispositions >= 1,
			"the campaign emitted at least one non-create operation (%d)"
			% dispositions)
	_check(evolved >= 1,
			"at least one component reached Mk II or better (%d did)"
			% evolved)
	_check(longest_chain >= 2,
			"a provenance chain names more than one item (longest %d)"
			% longest_chain)
	# S8: the Lab is Hub geometry, so a campaign that never notices it is a
	# campaign where it silently failed to build. Cheap end-to-end check
	# only — the fixtures themselves are `make godot-lab`'s business.
	# Awaited into a local first: `_check(await ...)` passes a coroutine
	# where a bool belongs, and the run hangs instead of failing.
	var lab_ok: bool = await _lab_built_and_changed_nothing()
	_check(lab_ok,
			"the Hub's Echo Lab exists and the visit changed no campaign truth")
	# S9: the campaign must actually have offered affordances and paid out
	# a local reward. Base-kit tags are unlocked from the first Zone, so
	# zero here means the feature path quietly stopped working.
	_check(_affordances_seen > 0,
			"the campaign offered affordance features (%d)" % _affordances_seen)
	_check(_local_rewards_earned > 0,
			"a local reward was earned and recorded in the save (%d)"
			% _local_rewards_earned)
	_check(stock_ever_seen, "shop stocked at least once during the campaign")
	if stock_ever_seen:
		_check(_bought_once, "at least one shop purchase completed")
		_check(int(snapshot.get("coins_spent", 0)) > 0,
				"coins were genuinely spent")
	_finish(0 if failures == 0 else 1)

# ---------------------------------------------------------------------------

## The Hub is authored, not generated, so nothing else in this driver
## exercises it — but it is where the player spends half their time, and
## its board reads live campaign state.
func _check_hub_builds() -> void:
	var hub := HubController.new()
	get_tree().root.add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hub.player != null, "hub spawns the player")
	_check(hub._board_cells.size() == Constants.LOCATION_COUNT,
			"campaign board has one cell per Check (%d)"
			% hub._board_cells.size())
	hub.refresh()
	await get_tree().process_frame
	var legend: String = hub._board_legend.text
	_check(legend.contains("sent") and legend.contains("key-locked"),
			"campaign board legend reads live state: '%s'" % legend)
	var lit := 0
	for cell: MeshInstance3D in hub._board_cells:
		if cell.material_override != null:
			lit += 1
	_check(lit == Constants.LOCATION_COUNT,
			"every board cell is tinted (%d)" % lit)
	await _hub_epsilon_speaks(hub)
	hub.queue_free()

## Epsilon designed every Zone the player just played and then waited here
## while they played them. It was silent in the Hub until now — the one
## room where the player stands still and reads was the one room the
## designer never spoke in.
##
## Two properties matter and neither is "a line appeared": the greeting
## must not land under the arrival fade, and a change bark must fire on the
## EDGE of a change rather than every frame the condition holds — a
## designer who announces your key count once a frame is a status bar.
func _hub_epsilon_speaks(hub: HubController) -> void:
	var voice_hud := Hud.new()
	get_tree().root.add_child(voice_hud)
	await get_tree().process_frame
	hub.hud = voice_hud
	hub._voice_greeted = false
	hub._voice_idle = 0.0

	# Silent while the arrival is still on screen.
	hub._process(1.0)
	_check(not hub._voice_greeted, "Epsilon waits out the arrival fade")
	hub._process(2.0)
	_check(hub._voice_greeted, "Epsilon greets you in the Hub")

	# A change fires once, on the edge. The first refresh only takes a
	# baseline: on arrival every value is "new", and three barks at once
	# would be worse than silence.
	hub._seen_completed = -1
	voice_hud._voice.reset()
	hub._voice_on_change()
	var baseline := voice_hud._voice._last_line
	hub._voice_on_change()
	_check(voice_hud._voice._last_line == baseline,
			"an unchanged Hub says nothing new")

	# Now move a Signal Key and watch it land exactly once.
	var before: Variant = BridgeClient.snapshot.get("signal_keys", 0)
	BridgeClient.snapshot["signal_keys"] = int(hub._seen_keys) + 1
	voice_hud._voice.reset()
	hub._voice_on_change()
	var spoken: String = voice_hud._voice._last_line
	_check(spoken in EpsilonVoice.LINES["hub_key_landed"],
			"a Signal Key gets a line ('%s')" % spoken)
	voice_hud._voice.reset()
	hub._voice_on_change()
	_check(voice_hud._voice._last_line == "",
			"...and only once, on the edge")
	BridgeClient.snapshot["signal_keys"] = before

	voice_hud.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

## The client colours a game by re-deriving the bridge's theme rule. If
## the two ever disagree, the Hub board and reveal cards would tint a game
## differently from the Zone the bridge actually built for it.
##
## Expectations are generated by the bridge's own `_theme_for`; see
## bridge/tests/test_theme_agreement.py, which pins the same pairs.
func _check_theme_agreement() -> void:
	var expected := {
		"Ocarina of Time": "temple_ruin",       # pinned hint
		"Archipepsi": "void_glitch",            # pinned hint
		"Hollow Knight": "void_glitch",         # sha256-hashed
		"Celeste": "temple_ruin",
		"Factorio": "void_glitch",
		"A Link to the Past": "rusted_industrial",
		"Slay the Spire": "neon_transit",
	}
	for game: String in expected:
		var got := ThemeMaterials.theme_for_game(game)
		_check(got == expected[game],
				"theme for '%s' matches the bridge (%s)" % [game, got])

## An enemy's visible body must stay inside its collision box: geometry
## reaching past it clips through walls and doorframes, and every corridor
## lane budget is sized to the collider, not to the silhouette.
func _check_enemy_silhouettes() -> void:
	for kind: String in Constants.ENEMY_ARCHETYPES:
		var enemy := Enemy.create(kind, "gothic_stone")
		var half_width := 0.0
		for child in enemy.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				half_width = child.shape.size.x / 2.0
		var worst := 0.0
		for child in enemy.get_children():
			if not (child is MeshInstance3D):
				continue
			var mesh: Mesh = child.mesh
			var extent := 0.0
			if mesh is BoxMesh:
				extent = (mesh as BoxMesh).size.x / 2.0
			elif mesh is PrismMesh:
				extent = (mesh as PrismMesh).size.x / 2.0
			else:
				continue
			worst = maxf(worst, absf(child.position.x) + extent)
		_check(half_width > 0.0 and worst <= half_width + 0.001,
				"%s silhouette fits its collider (%.2f <= %.2f)"
				% [kind, worst, half_width])
		if kind == "brute":
			# Secret ledges are placed to pass over the tallest actor, and
			# that budget is a constant in the builders. This is where the
			# two are held together: a taller brute has to move the ledges.
			var height := 0.0
			for child in enemy.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D:
					height = child.shape.size.y
			_check(height > 0.0 and ChamberBuilders.TALLEST_ACTOR >= height,
					"TALLEST_ACTOR (%.2f) still covers the brute (%.2f)"
					% [ChamberBuilders.TALLEST_ACTOR, height])
		enemy.free()

## An Echo is somebody else's item, reinterpreted, and it should look like
## it. Half of that is checkable before a campaign exists — an empty slot
## must claim no world — and half needs a real owned component, because in
## v0.8 the source game lives in the FOLD's provenance rather than on the
## component. The second half runs in `_check_slotted_action_tint`, after
## the first Zone has actually granted something.
func _check_empty_slot_claims_no_world() -> void:
	var player := Player.create()
	add_child(player)
	var runtime: EchoRuntime = player.echo_runtime
	_check(runtime.source_color().is_equal_approx(Color(0.85, 0.88, 0.92)),
			"an empty slot claims no world's colour")
	var part: MeshInstance3D = player.viewmodel.get_node("EchoPart")
	_check(not part.visible, "an empty slot shows no attachment")
	player.free()

## The other half, with a component the campaign really owns.
func _check_slotted_action_tint(runtime: EchoRuntime) -> void:
	var component_id := str(runtime.equipped.get("component_id", ""))
	var game := BridgeClient.component_source_game(component_id)
	_check(game != "", "a slotted action knows the world it came from")
	_check(runtime.source_color().is_equal_approx(
				ThemeMaterials.color_for_game(game)),
			"the slotted action wears its source world's colour (%s)" % game)
	var part: MeshInstance3D = runtime.player.viewmodel.get_node("EchoPart")
	var tip: MeshInstance3D = part.get_node("EchoTip")
	_check(part.visible, "a slotted action shows its attachment")
	var body_mat := part.material_override as StandardMaterial3D
	var tip_mat := tip.material_override as StandardMaterial3D
	_check(body_mat != null and tip_mat != null,
			"body and tip are both painted")
	_check(body_mat != null and tip_mat != null
				and not body_mat.albedo_color.is_equal_approx(
					tip_mat.albedo_color),
			"source colour and slot colour stay distinguishable")

## Head bob is the classic way to make a first-person walk feel like a
## walk and the classic way to make people motion-sick, so its bounds are
## asserted rather than eyeballed — and standing still must put the eye
## exactly where every other number in the game assumes it is.
func _check_camera_feel() -> void:
	var still := Player.camera_feel_offset(2.3, 0.0, 0.0)
	_check(still.is_equal_approx(Vector3.ZERO),
			"standing still leaves the eye exactly at eye height")
	var worst := 0.0
	var lowest := 0.0
	for i in 400:
		var phase := TAU * float(i) / 40.0
		var offset := Player.camera_feel_offset(phase, 1.0,
				Player.LAND_DIP_MAX)
		worst = maxf(worst, maxf(absf(offset.x), absf(offset.y)))
		lowest = minf(lowest, offset.y)
	_check(worst <= Player.BOB_RISE + Player.LAND_DIP_MAX + 0.001,
			"the view never strays more than %.3f m from the eye" % worst)
	_check(lowest >= -(Player.BOB_RISE + Player.LAND_DIP_MAX) - 0.001,
			"the deepest dip is bounded (%.3f m)" % lowest)
	_check(Player.BOB_RISE + Player.LAND_DIP_MAX
				< Constants.PLAYER_EYE_HEIGHT * 0.15,
			"the whole effect stays a fraction of eye height")

## project.godot's InputMap is hand-edited text; a malformed event object
## is dropped silently at load, and the first symptom is a control that
## does nothing. Assert the bindings the Hub's controls board promises.
func _check_input_bindings() -> void:
	var wheel_up := MOUSE_BUTTON_WHEEL_UP
	var wheel_down := MOUSE_BUTTON_WHEEL_DOWN
	var arrows := {"move_forward": KEY_UP, "move_back": KEY_DOWN,
			"move_left": KEY_LEFT, "move_right": KEY_RIGHT}
	for action: String in arrows:
		_check(InputMap.has_action(action)
					and _binds_key(action, arrows[action]),
				"%s is also on its arrow key" % action)
	_check(_binds_key("cycle_echo", KEY_Q)
				and _binds_button("cycle_echo", wheel_down),
			"cycle Echo is on Q and the wheel")
	_check(InputMap.has_action("cycle_echo_back")
				and _binds_button("cycle_echo_back", wheel_up),
			"the wheel scrolls the archive back as well as forward")

func _binds_key(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _binds_button(action: String, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func _test_reveal_splits_the_two_halves() -> void:
	## DESIGN §16: the card has to make it unmistakable that the other
	## player got the real item and you got Epsilon's reinterpretation. The
	## split is on the blank line the bridge writes between them, and the
	## failure that matters is misattribution — an item name landing under
	## Epsilon's heading, or the reinterpretation reading as what was sent.
	var reveal: Array = RevealLayer.split_halves(
			["Conference Call", "Borderlands 2", "",
			"EPSILON ECHO ACQUIRED", "Conference Call", "12 pellets"])
	_check(reveal[0] == ["Conference Call", "Borderlands 2"],
			"the sent half is what the bridge put before the break")
	_check(reveal[1] == ["EPSILON ECHO ACQUIRED", "Conference Call",
			"12 pellets"],
			"the Echo half is everything after it")

	# A self-recipient check has no Echo half at all.
	var own: Array = RevealLayer.split_halves(
			["Signal Key", "Delivered to you."])
	_check(own[0].size() == 2 and own[1].is_empty(),
			"a check with no Echo renders as one block, not two")

	# Only the FIRST blank divides; blank lines inside the Echo half are
	# spacing the bridge chose, not a second boundary.
	var spaced: Array = RevealLayer.split_halves(
			["Item", "Game", "", "ECHO", "", "12 pellets"])
	_check(spaced[0] == ["Item", "Game"]
			and spaced[1] == ["ECHO", "", "12 pellets"],
			"a later blank line does not start a third block")

	_check(RevealLayer.split_halves([])[0].is_empty(),
			"an empty card splits into nothing rather than erroring")

## Epsilon is meant to be an occasional voice, not a status bar. Two things
## keep it that way and both are easy to lose: the throttle, and never
## saying the same line twice running.
func _check_epsilon_voice() -> void:
	var voice := EpsilonVoice.new()
	var previous := voice.line_for("room_cleared")
	_check(not previous.is_empty(), "Epsilon speaks when a room clears")
	_check(voice.line_for("room_cleared").is_empty(),
			"a second line inside the cooldown is withheld")
	var repeated := ""
	var withheld := false
	for i in 24:
		voice.tick(EpsilonVoice.COOLDOWN)
		var next := voice.line_for("room_cleared")
		if next.is_empty():
			withheld = true
			break
		if next == previous:
			repeated = next
			break
		previous = next
	_check(not withheld, "a line lands once the cooldown has expired")
	if repeated.is_empty():
		_check(true, "Epsilon never repeats a line back to back (24 draws)")
	else:
		_check(false, "Epsilon said '%s' twice running" % repeated)
	voice.tick(EpsilonVoice.COOLDOWN)
	_check(voice.line_for("no_such_event_at_all").is_empty(),
			"an unknown event says nothing")
	# An unknown event returns early WITHOUT arming the throttle, so
	# asserting reset() straight after it proved nothing — the throttle was
	# already clear either way. Arm it with a real line first.
	_check(not voice.line_for("room_cleared").is_empty(),
			"a real line arms the throttle")
	_check(voice.line_for("room_cleared").is_empty(),
			"the throttle is genuinely armed")
	voice.reset()
	_check(not voice.line_for("room_cleared").is_empty(),
			"reset drops the throttle for the next Zone")
	# Payoff lines must not be swallowed by ambient chatter: dying arms six
	# seconds of silence and the respawn lands 1.5 s later, which made the
	# revival lines literally unreachable.
	voice.reset()
	_check(not voice.line_for("long_walk").is_empty(), "an aside lands")
	_check(not voice.line_for("died").is_empty(),
			"death interrupts whatever was being said")
	_check(not voice.line_for("revived").is_empty(),
			"getting back up is never swallowed by the death line")
	_check(not voice.line_for("secret_found").is_empty(),
			"reaching a secret is never swallowed either")
	_check(voice.line_for("long_walk").is_empty(),
			"ambient lines still wait their turn")

## The kill flag on a hit confirmation has to come from the hit that did
## the killing, not from reading hp afterwards — otherwise every later
## shot into a corpse re-reports a kill and the crosshair keeps stamping
## an X at a body that is already sinking through the floor.
func _check_hit_confirmation() -> void:
	var enemy := Enemy.create("brute", "concrete_facility")
	add_child(enemy)                 # take_damage tweens, so it needs a tree
	_check(not enemy.take_damage(1.0, Vector3.FORWARD, 0.0),
			"a survivable hit is not reported as a kill")
	_check(enemy.take_damage(100000.0, Vector3.FORWARD, 0.0),
			"the fatal hit reports the kill")
	_check(not enemy.take_damage(100000.0, Vector3.FORWARD, 0.0),
			"shooting a corpse never re-reports a kill")
	enemy.queue_free()

## A LAYOUT THE BRIDGE REFUSES, through the real client and the real
## intent, and what the game does about it.
##
## The refusal half of the exchange had only ever been driven from
## Python. What that left unproven is the half the player lives in:
## `handle_layout_result` refused a manifest and sent a `zone_abandoned`
## NOTIFICATION, `main.gd` showed it as a toast, and the Zone carried on
## being playable and claimable. A refusal nobody acts on is a refusal in
## name.
##
## NO TEST SEAM IN THE ENGINE. The falsification is in this driver's own
## COPY of the Zone: one declared door is DROPPED before the controller
## builds it. The engine then builds the room exactly as it would have --
## a socket nobody declares is sealed by omission either way -- and
## honestly reports a measurement for every door it was given, which is
## one fewer than the bridge composed. The bridge refuses, because "a
## door the layout does not report is refused rather than skipped" is
## what makes its aperture probe inverted rather than optional.
##
## Nothing in the message is doctored: the two copies genuinely disagree
## about which doors exist, and every line of the path between them is
## the shipping one.
##
## It used to flip an arena's SEALED `side_left` to `USED` and rely on
## `_perimeter` carving the hole. Every arena the composer builds now
## adopts an authored shell, an authored shell declares two doorway
## sockets and no sides, and the search found nothing to flip -- so the
## falsification stopped falsifying and the test went red rather than
## vacuous, which is the only reason this was noticed.
func _test_a_refused_layout_is_not_playable() -> bool:
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_condition("ZONE_READY for the refusal control",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return false
	var record := BridgeClient.active_zone()
	var zone_id := str(record.get("zone_id", ""))
	var allocated: Array = (record.get("allocated_location_ids", [])
			as Array).duplicate()
	var falsified: Dictionary = (record.get("zone", {}) as Dictionary) \
			.duplicate(true)
	# WHICH DOOR, and why that one.
	#
	# An arena's SEALED `side_left`: a wall in the bridge's copy, carved
	# open in this client's. It has to be a door that carries NO edge,
	# because `placement_plan` refuses a JOINED edge whose room seals its
	# door -- that makes the Zone unbuildable rather than wrong, and the
	# controller then never reaches the bridge at all. And it has to be
	# an arena, because `_perimeter` is what reads a side socket out of
	# the cut plan and a corridor raises its own walls.
	#
	# So the engine honestly carves a hole, honestly measures it as one,
	# and says so; the bridge is still holding SEALED. Nothing in the
	# message is doctored.
	# WHICH DOOR, and why that one.
	#
	# A SEALED door carrying NO edge. No edge, because `placement_plan`
	# refuses a JOINED edge whose room drops its door -- that makes the
	# Zone unbuildable rather than wrong, and the controller then never
	# reaches the bridge at all. SEALED, because a sealed socket is
	# sealed by omission too, so the room this client builds is the same
	# room, down to the geometry: the ONLY difference is that one
	# aperture goes unmeasured.
	var dropped := ""
	for raw_chamber: Variant in falsified.get("chambers", []):
		var chamber: Dictionary = raw_chamber
		if dropped != "":
			continue
		var kept: Array = []
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			if dropped == "" and str(door.get("usage", "")) == "SEALED" \
					and door.get("edge_id") == null:
				dropped = "%s/%s" % [str(chamber.get("id", "?")),
						str(door.get("socket_id", "?"))]
				continue
			kept.append(door)
		if dropped != "":
			chamber["doors"] = kept
	_check(dropped != "",
			"a sealed, edge-less door (%s) was dropped from this "
			% dropped + "client's copy only")
	if dropped == "":
		return false

	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zone_id})
	if not await _await_condition("ZONE_ACTIVE for the refusal control",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false
	var controller := ZoneController.new()
	var refusals: Array[String] = []
	controller.layout_refused.connect(
			func(refused_id: String) -> void: refusals.append(refused_id))
	get_tree().root.add_child(controller)
	controller.setup(falsified)
	var refused := func() -> bool:
		var state := str(BridgeClient.active_zone().get("layout_state", ""))
		return state == "REFUSED" or BridgeClient.active_zone().is_empty()
	if not await _await_condition("the bridge refuses the falsified layout",
			refused, 20.0):
		controller.queue_free()
		return false
	# THE FALSIFICATION ACTUALLY FALSIFIED SOMETHING.
	#
	# A drop the client measured anyway leaves the two copies agreeing
	# about that door, and any refusal then came from somewhere else --
	# which is a test passing on somebody else's evidence. The engine's
	# own measurement says which apertures it reported.
	_check(not controller.measured_apertures.has(dropped),
			"this client reported no measurement for %s, which is the "
			% dropped + "disagreement under test; it reported %s"
			% str(controller.measured_apertures.get(dropped)))
	_check(controller.measured_apertures.size() > 0,
			"the client measured no apertures at all, so the missing "
			+ "one proves nothing")
	# The controller polls the same snapshot this driver does, so seeing
	# REFUSED here says nothing about whether its own loop has come
	# round yet. Give it frames before asking what it did.
	for _i in 30:
		await get_tree().process_frame
	_check(refusals == [zone_id],
			"the controller raised `layout_refused` for %s, and it "
			% zone_id + "raised %s" % str(refusals))
	_check(controller.player == null or controller.player.input_frozen,
			"the player is held while the layout is unaccepted")
	# AND THE TWO HOLDS COMPOSE. `Main._update_modal` and this controller
	# both used to write one boolean, so whichever wrote last won: closing
	# the inventory released an acceptance hold, and an acceptance
	# released a pause. Opened and closed here while the verdict hold
	# stands, which is the case that was broken.
	if controller.player != null:
		controller.player.hold("modal")
		controller.player.release("modal")
		_check(controller.player.input_frozen,
				"closing a menu released the acceptance hold: holds are "
				+ "%s" % str(controller.player.holds()))
		_check(controller.player.holds().has(
					ZoneController.LAYOUT_HOLD),
				"the acceptance hold is not named among %s"
				% str(controller.player.holds()))

	# AND THE REFUSED ZONE CANNOT CLAIM A CHECK. The intent is the real
	# one, sent the way a reward sends it; the bridge's Zone is no longer
	# ACTIVE, so it must come back unclaimed.
	var claimed := int(allocated[0]) if not allocated.is_empty() else 0
	BridgeClient.send_intent({"type": "claim_check", "zone_id": zone_id,
			"location_id": claimed})
	for _i in 30:
		await get_tree().process_frame
	_check(not (claimed in BridgeClient.snapshot.get(
				"checked_location_ids", [])),
			"a refused Zone cannot claim check %d" % claimed)
	controller.queue_free()
	await get_tree().process_frame

	# AND ITS CHECKS SURVIVE. Recovering safely means recomposing the
	# Zone against the ids it already holds, not spending them.
	if not await _await_condition("the refused Zone is composed again",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_READY", 30.0):
		return false
	var again := BridgeClient.active_zone()
	_check(str(again.get("zone_id", "")) == zone_id,
			"the recomposed Zone is still %s" % zone_id)
	var kept: Array = again.get("allocated_location_ids", [])
	allocated.sort()
	kept.sort()
	_check(kept == allocated,
			"the refused Zone kept its Checks: %s, and it holds %s"
			% [str(allocated), str(kept)])
	return true


## THE WHOLE RECOVERY, DRIVEN: a Zone that can never be built, the
## console that discards it, and the campaign carrying on.
##
## `AMALGAM_BRIDGE.md` §5.7a defect 1 and §5.7b. A fresh proposal that
## exhausts its layout attempts goes to `ZONE_FAILED` holding its
## Checks, and the Hub used to answer that with "RETURN TO ZONE" -- into
## geometry the validator had refused three times. Entering succeeded,
## the client sent a layout, it was refused, and round it went; the
## escape at the abandon console was hidden in that mode and, reading
## `active_zone` for a Zone nobody is standing in, had nothing to send.
##
## Every refusal here is a real one from the real validator: the same
## falsification the refusal control uses, sent again and again until
## the budget is spent. What is asserted is what a player standing in
## the Hub can DO -- and that the first press changes nothing.
func _test_a_failed_zone_is_discarded_and_its_checks_come_back() -> bool:
	# LET GO OF WHATEVER IS HELD FIRST. The control before this one
	# leaves a Zone active, and `request_next_zone` is refused while the
	# campaign holds one -- so this would wait thirty seconds for a
	# ZONE_READY nobody was going to send.
	var held := str(BridgeClient.hub().get("resume_zone_id", ""))
	if held == "":
		held = str(BridgeClient.active_zone().get("zone_id", ""))
	if held != "" and BridgeClient.hub_mode() != "ZONE_AVAILABLE":
		BridgeClient.send_intent({"type": "abandon_zone",
				"zone_id": held})
		if not await _await_condition("the held Zone is let go",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_AVAILABLE",
				30.0):
			return false
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_condition("ZONE_READY for the discard control",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return false
	var failed_id := str(BridgeClient.active_zone().get("zone_id", ""))
	var reserved: Array = (BridgeClient.active_zone().get(
			"allocated_location_ids", []) as Array).duplicate()
	var checks_before: Array = BridgeClient.snapshot.get(
			"checked_location_ids", []).duplicate()

	# 1. SPEND THE BUDGET. A refusal recomposes the Zone against the same
	#    ids, so each round is a fresh shape falsified the same way.
	#    Bounded by `MAX_LAYOUT_REFUSALS` + 1 with room to spare; a run
	#    that does not reach ZONE_FAILED has not measured this and says
	#    so rather than passing.
	for round_number in 6:
		if BridgeClient.hub_mode() == "ZONE_FAILED":
			break
		# WAIT FOR A ZONE TO FALSIFY. A refusal sends the record to
		# PENDING_GENERATION with `zone` cleared, and the recompose lands
		# a moment later -- so a round that started inside that window
		# read a null Zone, found no door in it, and reported "nothing to
		# falsify" for a Zone that was merely not back yet. A race, not a
		# shape: it surfaced when composition timing shifted under it.
		if not await _await_condition("a Zone to falsify in round %d"
					% round_number,
				func() -> bool:
					# `active_zone()` is safe -- it returns {} for a
					# non-Dictionary. `.get("zone")` is NOT: a record in
					# PENDING_GENERATION carries a null there, and
					# `null as Dictionary` throws "Invalid cast: could
					# not convert value to 'Dictionary'". That error was
					# printed on every run of this suite and ignored,
					# because nothing failed a run on a script error
					# until this batch.
					if BridgeClient.hub_mode() == "ZONE_FAILED":
						return true
					var pending: Variant = BridgeClient.active_zone() \
							.get("zone")
					return typeof(pending) == TYPE_DICTIONARY \
						and not (pending as Dictionary).is_empty(), 40.0):
			return false
		if BridgeClient.hub_mode() == "ZONE_FAILED":
			break
		if BridgeClient.hub_mode() == "ZONE_READY":
			BridgeClient.send_intent({"type": "enter_zone",
					"zone_id": failed_id})
			if not await _await_condition("ZONE_ACTIVE for round %d"
						% round_number,
					func() -> bool:
						return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
				return false
		var falsified := _a_zone_with_one_door_dropped(
				BridgeClient.active_zone().get("zone", {}))
		if falsified.is_empty():
			_check(false, "no sealed edge-less door to drop, so this "
					+ "control cannot falsify anything")
			return false
		var doomed := ZoneController.new()
		get_tree().root.add_child(doomed)
		doomed.setup(falsified)
		if not await _await_condition("a verdict in round %d"
					% round_number,
				func() -> bool: return doomed.layout_verdict != "", 30.0):
			doomed.queue_free()
			return false
		_check(doomed.layout_verdict == "REFUSED",
				"round %d's falsified layout was refused, and it was "
				% round_number + "'%s'" % doomed.layout_verdict)
		doomed.queue_free()
		await get_tree().process_frame
		await _await_condition("the campaign settles after round %d"
					% round_number,
				func() -> bool:
					return BridgeClient.hub_mode() in ["ZONE_READY",
							"ZONE_FAILED", "GENERATING"], 30.0)
	if BridgeClient.hub_mode() != "ZONE_FAILED":
		_check(false, "six falsified layouts did not exhaust the budget; "
				+ "the Hub is in %s" % BridgeClient.hub_mode())
		return false

	# 2. THE HUB SHOWS THE FAILURE AND NAMES WHAT TO DISCARD.
	var hub := BridgeClient.hub()
	_check(str(hub.get("discard_zone_id", "")) == failed_id,
			"the Hub names %s as the Zone to discard, and it names '%s'"
			% [failed_id, str(hub.get("discard_zone_id", ""))])
	_check(str(hub.get("resume_zone_id", "")) == "",
			"and offers no resume id for it, so nothing can enter it by "
			+ "accident: resume_zone_id is '%s'"
			% str(hub.get("resume_zone_id", "")))
	_check(not bool(hub.get("portal_enabled", true)),
			"the portal is disabled in ZONE_FAILED")

	# 3. AND A FRESH CLIENT FINDS THE SAME CONTROL. Built here rather
	#    than reused: a console that only works because it happened to
	#    be standing when the Zone failed is not a recovery a player
	#    who restarts can reach.
	var room := HubController.new()
	get_tree().root.add_child(room)
	await get_tree().process_frame
	room.refresh()
	await get_tree().process_frame
	var asked: Array[int] = [0]
	room.enter_zone_requested.connect(func() -> void: asked[0] += 1)
	_check(not room.portal().interact_prompt().contains("[E]"),
			"the portal offers no way in: '%s'"
			% room.portal().interact_prompt())
	room._on_portal_activated()
	_check(asked[0] == 0,
			"and activating it asks for nothing (asked %d times)"
			% asked[0])
	var console := room.abandon_console()
	_check(console != null and console.visible,
			"the discard console is visible in ZONE_FAILED")
	if console == null:
		room.queue_free()
		return false

	# 4. THE FIRST PRESS ASKS, AND CHANGES NOTHING.
	var before_mode := BridgeClient.hub_mode()
	console.interact(null)
	for _i in 30:
		await get_tree().process_frame
	_check(console.interact_prompt().to_upper().contains("CONFIRM"),
			"the first press asks for confirmation: '%s'"
			% console.interact_prompt())
	_check(BridgeClient.hub_mode() == before_mode,
			"and changed no campaign state: the Hub is still %s"
			% BridgeClient.hub_mode())
	_check(str(BridgeClient.hub().get("discard_zone_id", "")) == failed_id,
			"and the Zone is still held")

	# 5. THE SECOND PRESS DISCARDS THAT ZONE, and 6. the ids come back.
	console.interact(null)
	if not await _await_condition("the failed Zone is discarded",
			func() -> bool:
				return BridgeClient.hub_mode() != "ZONE_FAILED", 30.0):
		room.queue_free()
		return false
	_check(BridgeClient.hub_mode() == "ZONE_AVAILABLE",
			"discarding it leaves the Hub able to generate again, and "
			+ "it is in %s" % BridgeClient.hub_mode())
	var checks_now: Array = BridgeClient.snapshot.get(
			"checked_location_ids", []).duplicate()
	checks_before.sort()
	checks_now.sort()
	_check(checks_before == checks_now,
			"discarding claimed nothing on the player's behalf: %s "
			% str(checks_before) + "before, %s after" % str(checks_now))
	var missing: Array = BridgeClient.snapshot.get(
			"missing_location_ids", [])
	var stranded: Array = []
	for id: Variant in reserved:
		if not missing.has(id):
			stranded.append(id)
	_check(stranded.is_empty(),
			"the discarded Zone's %d reserved location(s) are back in "
			% reserved.size() + "the pool; stranded: %s" % str(stranded))

	# 7. AND THE NEXT ZONE CAN BE ASKED FOR.
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_condition("the next Zone after a discard",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			40.0):
		room.queue_free()
		return false
	_check(str(BridgeClient.active_zone().get("zone_id", "")) != failed_id,
			"and it is a new Zone, not the discarded one")
	room.queue_free()
	await get_tree().process_frame
	return true


## A copy of `zone` with one sealed, edge-less door dropped, or empty.
##
## The falsification both the refusal control and the discard control
## use. A SEALED door carrying NO edge: no edge, because
## `placement_plan` refuses a JOINED edge whose room drops its door --
## that makes the Zone unbuildable rather than wrong, and the controller
## never reaches the bridge at all. SEALED, because a sealed socket is
## sealed by omission too, so the room this client builds is the same
## room down to the geometry and the ONLY difference is that one
## aperture goes unmeasured.
func _a_zone_with_one_door_dropped(zone: Variant) -> Dictionary:
	if typeof(zone) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = (zone as Dictionary).duplicate(true)
	var dropped := ""
	for raw_chamber: Variant in out.get("chambers", []):
		var chamber: Dictionary = raw_chamber
		if dropped != "":
			continue
		var kept: Array = []
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			if dropped == "" and str(door.get("usage", "")) == "SEALED" \
					and door.get("edge_id") == null:
				dropped = "%s/%s" % [str(chamber.get("id", "?")),
						str(door.get("socket_id", "?"))]
				continue
			kept.append(door)
		if dropped != "":
			chamber["doors"] = kept
	return {} if dropped == "" else out


## THE WHOLE RECOVERY FROM AN UNHOSTABLE HOST, AND THE RETURN THAT
## FOLLOWS IT -- measurement, bar, re-selection, a late result from the
## proposal that was replaced, acceptance, a walk onto the device, and a
## restart that replays it. §5.9 and §5.7.
##
## TWO KINDS OF EVIDENCE, LABELLED APART. The BRIDGE CONTROLS below
## assert what the campaign did with the engine's verdict; the PHYSICAL
## EVIDENCE asserts what a body in the accepted Zone can actually do. A
## helper that posts a layout on the client's behalf establishes the
## first and nothing whatever about the second, which is why the return
## is walked into rather than asserted from a field.
##
## THE FALSIFICATION, AND WHY IT HAS TO BE ONE. After the lattice repair
## in `room_audit.gd` -- both axes carry a zero offset now -- **no room
## the composer may propose fails placement any more.** Measured: every
## arena from `PROCEDURAL_ARENA_MIN_SPAN` (10 m) upward places, a
## `platform_path` places on its declared ledges, and the cliff is at
## 6 m square. The one schema-legal shape that genuinely cannot host a
## return is a minimum corridor, 6 x 4, and the composer does not make
## corridors into branch destinations. That is the repair working. It
## also means the recovery path can no longer be reached by asking for
## Zones until one breaks, so this client builds the branch host at
## 5.5 m square -- smaller than the composer may propose, HONESTLY built
## and HONESTLY measured, with the bridge still holding the room it
## really sent. The engine's verdict is its own.
func _test_reselection_and_return_journey() -> bool:
	# A ZONE WITH A BRANCH, because a Zone with none has no host to bar.
	# The composer branches when the chambers can carry one and returns
	# a plain chain when they cannot, and by this point in the run the
	# campaign has spent several Zones -- so ask until one has a return
	# rather than failing on the draw. Bounded, and a run that never
	# sees one says exactly that.
	var record := {}
	var host := ""
	for _attempt in 4:
		BridgeClient.send_intent({"type": "request_next_zone",
				"finale": false})
		if not await _await_condition(
				"ZONE_READY for the re-selection control",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_READY", 30.0):
			return false
		record = BridgeClient.active_zone()
		host = _first_plug_host(record.get("zone"))
		if host != "":
			break
		# Put it back and ask again. Abandoning returns its Checks to
		# the pool, so nothing is spent by looking.
		BridgeClient.send_intent({"type": "abandon_zone",
				"zone_id": str(record.get("zone_id", ""))})
		if not await _await_condition("the unbranched Zone is released",
				func() -> bool:
					return BridgeClient.active_zone().is_empty(), 20.0):
			return false
	if host == "":
		_check(false, "four Zones in a row carried no return plug, so "
				+ "there was no host to bar and this control measured "
				+ "nothing")
		return false
	var zone_id := str(record.get("zone_id", ""))
	var proposal_a := BridgeClient.proposal_for(zone_id)
	_check(proposal_a != "",
			"the bridge issued an identity for the Zone it offered, on "
			+ "the carrier the build path reads")
	var shrunk := _with_a_host_too_small_for_a_return(
			record.get("zone"), host)
	var rooms_a := _room_ids(record.get("zone"))

	# ---- BRIDGE CONTROL 1: the engine measures, the bridge bars -------
	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zone_id})
	if not await _await_condition("ZONE_ACTIVE for the re-selection control",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false
	var a := ZoneController.new()
	get_tree().root.add_child(a)
	a.setup(shrunk)
	if a.layout_failed != "":
		_check(false, "the shrunk Zone would not lay out at all (%s), "
				% a.layout_failed + "so nothing was measured and this "
				+ "control proves nothing")
		a.queue_free()
		return false
	var attempt_a := BridgeClient.attempt_for(zone_id)
	_check(a.proposal_id == proposal_a,
			"the controller bound the identity of the proposal it is "
			+ "building (%s) and it bound %s" % [proposal_a, a.proposal_id])
	_check(a.attempt == attempt_a and a.attempt >= 0,
			"and the ATTEMPT that identity belongs to (%d), which is "
			% attempt_a + "what separates two tries at the same content "
			+ "-- it bound %d" % a.attempt)
	# `_publish_layout` is deferred -- two physics frames, then the
	# settle -- so the evidence is not on the controller the instant
	# `setup` returns. Waited for rather than read: the first version of
	# this assertion read an empty dictionary and failed while the bar
	# it was about arrived correctly a second later.
	var edge := _plug_edge(record.get("zone"))
	if not await _await_condition("the engine measures the shrunk host",
			func() -> bool:
				return (a.measured_placement as Dictionary).has(edge),
			20.0):
		a.queue_free()
		return false
	var told: Dictionary = a.measured_placement
	_check(str((told.get(edge, {}) as Dictionary).get("outcome", ""))
				== "NO_CANDIDATE",
			"the engine measured the shrunk host and reported "
			+ "NO_CANDIDATE -- the one outcome that may bar a host "
			+ "(%s)" % str(told.get(edge, {})))
	# ---- BRIDGE CONTROL 2: the bridge recovers, and says how ---------
	#
	# TWO RECOVERIES, AND WHICH ONE IS NOT THIS CONTROL'S TO CHOOSE.
	# `_reselect_hosts` moves the branch when the same arrangement can
	# be rebuilt without it, and STANDS DOWN when it cannot -- the
	# ordinary bounded refusal takes the Zone back to Epsilon instead.
	# Both are designed, both are reported, and which one a given host
	# gets is a property of that Zone's spare capacity, not of this
	# harness. Measured on a default-scale Zone after the capacity was
	# corrected: 1 of 8 hosts can be re-selected with the branch count
	# preserved, where the flat four-socket table claimed 8 of 8 by
	# planning routes through walls.
	#
	# So this asserts the RECOVERY and names the path. Re-selection's
	# own properties -- the bar recorded, the branch moved, the count
	# preserved -- are bridge controls and live in
	# `test_amalgam_end_to_end.py`, where the host can be chosen for the
	# property under test. What only this control can establish is that
	# a real engine measurement reached a real campaign and a
	# replacement came back.
	if not await _await_condition("the bridge recovers the Zone",
			func() -> bool:
				var az := BridgeClient.active_zone()
				if az.is_empty():
					return false
				# THREE WAYS TO SEE A RECOVERY, and the third is the
				# one this batch added: a deterministic recompose can
				# return byte-identical content, so the digest does not
				# move and only the ATTEMPT says a new try has begun.
				return (az.get("unhostable_rooms", []) as Array).has(host) \
					or BridgeClient.proposal_for(zone_id) != proposal_a \
					or BridgeClient.attempt_for(zone_id) > attempt_a, 60.0):
		a.queue_free()
		return false
	var barred_host := (BridgeClient.active_zone().get(
			"unhostable_rooms", []) as Array).has(host)
	print("  RECOVERY: %s" % ("the host was barred and the branch "
			+ "re-selected" if barred_host
			else "re-selection stood down; the Zone was refused and "
			+ "composed again, which is the other designed recovery"))

	if not await _await_condition("the replacement is offered",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_READY" \
					and str(BridgeClient.active_zone().get(
						"zone_id", "")) == zone_id, 40.0):
		a.queue_free()
		return false
	var replacement := BridgeClient.active_zone()
	var proposal_b := BridgeClient.proposal_for(zone_id)
	var host_b := _first_plug_host(replacement.get("zone"))
	_check(_room_ids(replacement.get("zone")) == rooms_a,
			"the replacement keeps the CONTENT -- the same rooms, the "
			+ "same Checks (%s)" % str(rooms_a))
	_check(_plug_count(replacement.get("zone"))
				== _plug_count(record.get("zone")),
			"and the branch count is preserved: %d returns before and "
			% _plug_count(record.get("zone"))
			+ "%d after" % _plug_count(replacement.get("zone")))
	if barred_host:
		_check((BridgeClient.active_zone().get("unhostable_rooms", [])
					as Array) == [host],
				"and exactly the room the engine named is barred (%s)"
				% str(BridgeClient.active_zone().get("unhostable_rooms",
					[])))
		_check(host_b != "" and host_b != host,
				"and the branch moved to another host (%s, was %s)"
				% [host_b, host])
		_check(proposal_b != "" and proposal_b != proposal_a,
				"and the re-graphed Zone is a different proposal "
				+ "(%s vs %s)" % [proposal_a, proposal_b])
	else:
		# IDENTICAL CONTENT, RE-COMPOSED. The fallback provider is
		# deterministic, so the replacement may hash exactly as the
		# original did -- which is correct, and is why the ATTEMPT is
		# what separates them here.
		_check(BridgeClient.attempt_for(zone_id) > attempt_a,
				"and the attempt moved on (%d, was %d), which is what "
				% [BridgeClient.attempt_for(zone_id), attempt_a]
				+ "separates two tries at content that hashes the same")

	# ---- BRIDGE CONTROL 3: A reports late, and nothing moves ---------
	_check(a.proposal_id == proposal_a and a.attempt == attempt_a,
			"A still carries the identity AND the attempt it started "
			+ "with; an old coroutine must never acquire the "
			+ "replacement's (%s, attempt %d)" % [a.proposal_id, a.attempt])
	_check(a.proposal_id != proposal_b
				or a.attempt != BridgeClient.attempt_for(zone_id),
			"and at least one of the two tells it apart from the "
			+ "replacement -- the digest when the content changed, the "
			+ "attempt when it did not")
	var attempt_b := BridgeClient.attempt_for(zone_id)
	var before := int(BridgeClient.active_zone().get("layout_refusals", -1))
	var state_before := str(BridgeClient.active_zone().get(
			"layout_state", ""))
	var barred_before: Array = (BridgeClient.active_zone().get(
			"unhostable_rooms", []) as Array).duplicate()
	# AND NOBODY IS RELEASED BY IT. A verdict is what lifts the
	# acceptance hold -- `_await_verdict` holds the player until the
	# bridge answers -- so "no verdict came back for the late result" is
	# the same fact as "no player's hold was released by it". Counted
	# rather than reasoned about.
	var verdicts: Array[String] = []
	a.layout_refused.connect(
			func(refused: String) -> void: verdicts.append(refused))
	var stale := ZoneBuilder.build(shrunk)
	if stale.has("failed"):
		_check(false, "the shrunk Zone would not lay out again: %s"
				% str(stale["failed"]))
		a.queue_free()
		return false
	a.send_layout_result(stale)
	for _i in 60:
		await get_tree().process_frame
	var after := BridgeClient.active_zone()
	_check(int(after.get("layout_refusals", -1)) == before,
			"A's late result spent none of the replacement's refusal "
			+ "budget (%d, was %d)"
			% [int(after.get("layout_refusals", -1)), before])
	_check(str(after.get("layout_state", "")) == state_before,
			"and changed none of its layout state (%s, was %s)"
			% [str(after.get("layout_state", "")), state_before])
	_check(after.get("manifest") == null,
			"and committed nothing: a late result must not commit the "
			+ "layout of the Zone it replaced")
	_check((after.get("unhostable_rooms", []) as Array) == barred_before,
			"and barred nothing further (%s, was %s)"
			% [str(after.get("unhostable_rooms", [])), str(barred_before)])
	_check(_first_plug_host(BridgeClient.active_zone().get("zone"))
				== host_b,
			"and changed none of its graph")
	_check(BridgeClient.attempt_for(zone_id) == attempt_b,
			"and did not advance its attempt (%d, was %d)"
			% [BridgeClient.attempt_for(zone_id), attempt_b])
	_check(verdicts.is_empty(),
			"and drew no verdict at all: a stale result the bridge "
			+ "ignores cannot release the hold its replacement's player "
			+ "is standing in (%s)" % str(verdicts))
	(stale["root"] as Node3D).queue_free()
	a.queue_free()
	await get_tree().process_frame

	# ---- BRIDGE CONTROL 4: the replacement completes its acceptance ---
	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zone_id})
	if not await _await_condition("ZONE_ACTIVE for the replacement",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false
	var b := ZoneController.new()
	get_tree().root.add_child(b)
	b.setup(replacement.get("zone"))
	_check(b.proposal_id == proposal_b,
			"the replacement's build bound its own identity (%s) and "
			% proposal_b + "bound %s" % b.proposal_id)
	_check(b.attempt == BridgeClient.attempt_for(zone_id),
			"and its own attempt (%d vs %d)"
			% [b.attempt, BridgeClient.attempt_for(zone_id)])
	var accepted := await _await_condition("the replacement is accepted",
			func() -> bool:
				return str(BridgeClient.active_zone().get(
						"layout_state", "")) == "ACCEPTED", 60.0)
	_check(accepted, "the replacement completed its own acceptance "
			+ "after A's late result was ignored")
	if not accepted:
		# WHAT IS BLOCKING IT, said here rather than left as a timeout.
		#
		# The re-selection itself is proved above. What stops the
		# replacement being ACCEPTED is a different, older defect:
		# `platform_path` declares two side doorways and raises solid
		# walls where they are, so any Zone the composer branches off
		# one is refused on aperture polarity. That is `godot-reload`'s
		# PHASE 1 refusal and `godot-zone-audit`'s counted waiver.
		print("  JOURNEY BLOCKED after re-selection: the replacement "
				+ "was not accepted, so the walk onto the return and "
				+ "the restart replay did not run. Bridge said: %s"
				% str(BridgeClient.snapshot.get("last_generation_error",
					"(see the bridge log for the refusal)")))
		b.queue_free()
		return false
	var manifest: Variant = BridgeClient.active_zone().get("manifest")
	_check(manifest != null, "and committed its own manifest")

	# ---- PHYSICAL EVIDENCE: the return is walked into and it works ----
	#
	# What the body does, in the Zone the bridge just accepted. The walk
	# under test is ARRIVAL -> DEVICE, which is the §5.7 journey and the
	# thing the placement search exists to make possible; crossing the
	# Zone to reach the room is measured elsewhere (`godot-graphs`) and
	# is not what a placement control is about, so the body starts where
	# a player entering that room arrives.
	var walked := await _the_return_carries_a_body_home(b, host_b)
	# WHERE THE ACCEPTED BUILD PUT THE DEVICE, read while that build is
	# still alive. A typed `ZoneController` parameter is type-checked
	# BEFORE the function body runs, so asking a freed controller is a
	# script error and not something `is_instance_valid` can catch
	# inside the callee.
	var stood_at: Vector3 = b._zone_anchors.get(
			"room:%s:return" % host_b, Vector3.INF)
	b.queue_free()
	await get_tree().process_frame

	# ---- BRIDGE CONTROL 5: a cold restart replays what was committed --
	#
	# A fresh controller, handed the committed manifest the way a
	# restarted client is, lays the same pieces down -- return device
	# included, in the same room, at the same place.
	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zone_id})
	if not await _await_condition("ZONE_ACTIVE for the replay",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false
	var replayed := BridgeClient.active_zone()
	var c := ZoneController.new()
	c.committed_manifest = (replayed.get("manifest", {}) as Dictionary)
	get_tree().root.add_child(c)
	c.setup(replayed.get("zone"))
	_check(c.layout_failed == "",
			"the committed manifest was replayed (%s)" % c.layout_failed)
	# LET THE REPLAY REACH THE POINT THE ACCEPTED BUILD WAS READ AT.
	#
	# `stood_at` is a SETTLED anchor: `_publish_layout` waits for the
	# physics to exist, measures, and `RoomAudit._settle_return_anchors`
	# moves the device off anything it should not be standing on. That
	# happens two physics frames after `setup` returns and is not
	# awaited by it, so reading the device here read the builder's first
	# reservation and compared it against a settled one -- and once the
	# settle started moving pads off the arrival-to-content line, the
	# two genuinely differed by 4.1 m. `measured_placement` is the
	# controller's own statement that it has measured; waiting on it
	# compares like with like, and makes this control say the stronger
	# thing: the SETTLE is reproducible from the committed layout, not
	# merely the reservation.
	if not await _await_condition("the replay measured its own layout",
			func() -> bool:
				return not c.measured_placement.is_empty()):
		return false
	var replug := _a_return_in(c, host_b)
	_check(replug != null,
			"and the return device is back, in the same room (%s)"
			% host_b)
	if replug != null and stood_at != Vector3.INF:
		_check(replug.global_position.distance_to(stood_at) < 0.01,
				"and at the same place a cold restart replays it to: "
				+ "%v, and the accepted build stood it at %v"
				% [replug.global_position, stood_at])
	_check(str(BridgeClient.active_zone().get("layout_state", ""))
				== "ACCEPTED",
			"and the Zone is still accepted after the replay")
	c.queue_free()
	await get_tree().process_frame

	# LEAVE THE CAMPAIGN AS IT WAS FOUND. The next control asks for a
	# Zone, and `request_next_zone` is refused while one is held.
	BridgeClient.send_intent({"type": "abandon_zone", "zone_id": zone_id})
	await _await_condition("the control's Zone is released",
			func() -> bool:
				return BridgeClient.active_zone().is_empty() \
					or str(BridgeClient.active_zone().get(
						"zone_id", "")) != zone_id, 20.0)
	return walked


## THE RETURN, USED ON PURPOSE. Not "the device exists" and not "an
## event fired": a body put where a player entering this room arrives,
## walked into the trigger, and then FOUND somewhere else.
func _the_return_carries_a_body_home(controller: ZoneController,
		host: String) -> bool:
	var plug := _a_return_in(controller, host)
	var body: Player = controller.player
	if plug == null or not is_instance_valid(body):
		_check(false, "PHYSICAL: no return device in %s, or no player, "
				% host + "so nothing can be walked")
		return false
	var fired: Array[String] = []
	plug.traversed.connect(func(edge: String, _to: String) -> void:
			fired.append(edge))
	var arrival: Vector3 = controller._zone_anchors.get(
			"room:%s:arrival" % host, Vector3.INF)
	var home: Vector3 = controller._zone_anchors.get("zone_start",
			Vector3.INF)
	if arrival == Vector3.INF or home == Vector3.INF:
		_check(false, "PHYSICAL: the accepted Zone published no arrival "
				+ "for %s or no start anchor" % host)
		return false
	body.velocity = Vector3.ZERO
	body.global_position = arrival + Vector3(0.0, 0.2, 0.0)
	for _settle in 40:
		await get_tree().physics_frame
	_check(fired.is_empty(),
			"PHYSICAL: a body standing at the arrival is NOT inside the "
			+ "device -- the return must not fire on the way in (%s)"
			% str(fired))
	_check(body.is_on_floor(),
			"PHYSICAL: and the arrival holds it up")
	var pad := plug.global_position
	await _walk_to(body, Vector3(pad.x, body.global_position.y, pad.z),
			func() -> bool: return not fired.is_empty())
	_check(fired.size() == 1,
			"PHYSICAL: walking into the pad raised exactly one "
			+ "traversal and it raised %d %s" % [fired.size(), str(fired)])
	for _settle in 30:
		await get_tree().physics_frame
	var gap := Vector2(body.global_position.x - home.x,
			body.global_position.z - home.z).length()
	_check(gap < 3.0,
			"PHYSICAL: and the production consumer put the body at the "
			+ "Zone start: %.1f m away" % gap)
	return fired.size() == 1 and gap < 3.0


## Steer a body toward a point until it arrives or the caller's
## condition fires. The stopping condition is the device's own trigger,
## never a distance guess: a four-metre tolerance is how a walk that
## stopped short of a 1.4 m trigger read as "could not get back".
func _walk_to(body: Player, goal: Vector3, until: Callable,
		frames := 420) -> void:
	var still := 0
	var last := body.global_position
	# THE SAME STEERING AS `graph_driver._walk`: the real input action,
	# so the body moves the way `Player._physics_process` moves it and
	# not by assignment. A driver that sets `global_position` proves the
	# trigger can be placed on top of a body, which is not the question.
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		if until.call():
			break
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < 0.3:
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		# A body wedged on furniture jumps, then gives up rather than
		# spending the whole budget pressed against a crate.
		if (here - last).length() < 0.012:
			still += 1
			if still == 24 and body.is_on_floor():
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
				still = 0
		else:
			still = 0
		last = here
		if still > 90:
			break
		await get_tree().physics_frame
	Input.action_release("move_forward")


## The return device standing in one room of a built Zone.
func _a_return_in(controller: ZoneController, host: String) -> ReturnPlug:
	for node: Node in controller.find_children("*", "ReturnPlug", true,
			false):
		var plug: ReturnPlug = node
		if str(plug.get_meta("room_id", "")) == host:
			return plug
	return null

## The room the first return plug in a Zone proposal stands in.
func _first_plug_host(zone: Variant) -> String:
	if typeof(zone) != TYPE_DICTIONARY:
		return ""
	for raw: Variant in (zone as Dictionary).get("plugs", []):
		return str((raw as Dictionary).get("room_id", ""))
	return ""

func _plug_edge(zone: Variant) -> String:
	if typeof(zone) != TYPE_DICTIONARY:
		return ""
	for raw: Variant in (zone as Dictionary).get("plugs", []):
		return str((raw as Dictionary).get("edge_id", ""))
	return ""

func _plug_count(zone: Variant) -> int:
	if typeof(zone) != TYPE_DICTIONARY:
		return -1
	return ((zone as Dictionary).get("plugs", []) as Array).size()

## Every room id a Zone proposal declares, sorted.
func _room_ids(zone: Variant) -> Array:
	var out: Array = []
	if typeof(zone) != TYPE_DICTIONARY:
		return out
	for raw: Variant in (zone as Dictionary).get("chambers", []):
		out.append(str((raw as Dictionary).get("id", "")))
	out.sort()
	return out

## The same Zone with one room too small to stand a return in.
##
## 5.5 m square: measured, the cliff is at 6.0. Only the branch host is
## touched and only its span -- the type, the doors and everything else
## are the Zone's own, so the room this client builds is the room the
## bridge sent in every respect but the one under test.
func _with_a_host_too_small_for_a_return(zone: Variant,
		host: String) -> Dictionary:
	if typeof(zone) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = (zone as Dictionary).duplicate(true)
	for raw: Variant in out.get("chambers", []):
		var chamber: Dictionary = raw
		if str(chamber.get("id", "")) != host:
			continue
		if chamber.has("width"):
			chamber["width"] = 5.5
		if chamber.has("depth"):
			chamber["depth"] = 5.5
		if chamber.has("length"):
			chamber["length"] = 5.5
	return out


## THE ZONE GOES AWAY WHILE ITS LAYOUT IS BEING CERTIFIED, twice, and a
## replacement then completes its own acceptance.
##
## `_publish_layout` is not awaited by anything. It settles, certifies
## each chain by replaying a real crate against a real plate, sends the
## result and then waits on a verdict -- seconds of asynchronous work
## belonging to a Zone the player can leave at any point inside it. The
## first symptom was a SIGABRT in `ChainCertificate._settle` on a freed
## node; guarding that stopped the crash and left the rest, which does
## not crash and is worse:
##
## * the half-finished certification was SENT ANYWAY, because
##   `_certify_physics` returned early and `send_layout_result` on the
##   next line did not care why;
## * the abandoned `_await_verdict` kept spinning in a frame loop for a
##   Zone nobody was in, and answered by holding or releasing a `player`
##   that had been freed -- `!= null` is not alive in GDScript;
## * and a stale REFUSED from that loop would have sent the REPLACEMENT
##   player back to the Hub out of a Zone that was accepted.
##
## Torn down at two offsets on purpose: early, inside the settle and the
## replay, and later, while the verdict is outstanding. Process survival
## is the least of what is asserted -- what matters is that nothing the
## discarded attempt did reaches the bridge, the player, or the campaign.
func _test_a_zone_survives_being_torn_down_mid_certification() -> bool:
	BridgeClient.send_intent({"type": "request_next_zone",
			"finale": false})
	if not await _await_condition("ZONE_READY for the teardown control",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return false
	var record := BridgeClient.active_zone()
	var zone_id := str(record.get("zone_id", ""))
	var zone_dict: Dictionary = record.get("zone", {})
	# WHAT THE CAMPAIGN HELD BEFORE ANY OF THIS. Certification drives
	# real crates onto real plates; if that were ever mistaken for a
	# player solving the puzzle, this is the number that would move.
	var checks_before: Array = BridgeClient.snapshot.get(
			"checked_location_ids", []).duplicate()
	var allocated_before: Array = record.get(
			"allocated_location_ids", []).duplicate()

	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zone_id})
	if not await _await_condition("ZONE_ACTIVE for the teardown control",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false

	for offset: int in [3, 14]:
		var doomed := ZoneController.new()
		var refusals: Array[String] = []
		doomed.layout_refused.connect(
				func(id: String) -> void: refusals.append(id))
		get_tree().root.add_child(doomed)
		doomed.setup(zone_dict)
		for _i in offset:
			await get_tree().physics_frame
		var caught := doomed.layout_verdict
		var ghost: Player = doomed.player
		doomed.free()
		# FRAMES AFTER THE FREE, which is the whole point: an abandoned
		# `_publish_layout` resumes on the NEXT frame, not on this one.
		for _i in 40:
			await get_tree().process_frame
		_check(not is_instance_valid(ghost),
				"the torn-down Zone's player went with it (offset %d)"
				% offset)
		_check(refusals.is_empty(),
				"the discarded attempt raised no verdict of its own, "
				+ "and it raised %s (offset %d)" % [str(refusals), offset])
		# WHAT IT HELD, AND WHAT IT MUST NOT HAVE. The early offset tears
		# the Zone down inside the settle and the replay, before any
		# verdict; the later one can legitimately catch an ACCEPTED,
		# because a fast round trip beats fourteen physics frames. What
		# neither may leave behind is a REFUSAL -- that is the answer
		# that sends a player back to the Hub, and a discarded attempt
		# has no standing to give it.
		_check(caught != "REFUSED",
				"the discarded attempt left no refusal behind (it held "
				+ "'%s', offset %d)" % [caught, offset])
		_check(BridgeClient.hub_mode() == "ZONE_ACTIVE",
				"the campaign is still in %s after the teardown, and it "
				% zone_id + "is in %s (offset %d)"
				% [BridgeClient.hub_mode(), offset])
		_check(str(BridgeClient.active_zone().get("layout_state", ""))
					!= "REFUSED",
				"no partial certification from the discarded attempt was "
				+ "refused as if this Zone had sent one: layout_state is "
				+ "'%s' (offset %d)"
				% [str(BridgeClient.active_zone().get(
						"layout_state", "")), offset])

	# AND THE REPLACEMENT COMPLETES ITS OWN ACCEPTANCE, normally, from
	# the same committed Zone the discarded attempts were building.
	var heir := ZoneController.new()
	get_tree().root.add_child(heir)
	heir.setup(zone_dict)
	if not await _await_condition("the replacement Zone gets a verdict",
			func() -> bool: return heir.layout_verdict != "", 30.0):
		heir.queue_free()
		return false
	_check(heir.layout_verdict == "ACCEPTED",
			"the replacement Zone reached its own ACCEPTED verdict, and "
			+ "it reached '%s'" % heir.layout_verdict)
	_check(not is_instance_valid(heir.player)
				or not heir.player.holds().has(ZoneController.LAYOUT_HOLD),
			"no stale verdict left the replacement player held: %s"
			% (str(heir.player.holds())
				if is_instance_valid(heir.player) else "no player"))
	# NOTHING THE CERTIFIER DID IS PLAYER PROGRESS. It replayed crates
	# onto plates three times per chain, twice discarded and once for
	# real, and the campaign holds exactly what it held before.
	var checks_after: Array = BridgeClient.snapshot.get(
			"checked_location_ids", []).duplicate()
	checks_before.sort()
	checks_after.sort()
	_check(checks_before == checks_after,
			"certification and replay awarded no Check: the campaign "
			+ "held %s and now holds %s"
			% [str(checks_before), str(checks_after)])
	var allocated_after: Array = BridgeClient.active_zone().get(
			"allocated_location_ids", []).duplicate()
	allocated_before.sort()
	allocated_after.sort()
	_check(allocated_before == allocated_after,
			"the teardown stranded no allocated location: %s before, %s "
			% [str(allocated_before), str(allocated_after)] + "after")
	heir.queue_free()
	await get_tree().process_frame
	return true


## `already_ready` plays the Zone the campaign is ALREADY holding rather
## than asking for a new one -- which the Hub refuses while one is ready,
## and which is the state the refusal control leaves behind.
func _play_one_zone(detailed: bool, already_ready := false) -> bool:
	var mode := BridgeClient.hub_mode()
	# finale_offered stays true in postgame by schema construction (both its
	# operands remain honestly true); the goal being missing is the extra
	# client-side condition. See docs/IMPLEMENTATION_DECISIONS.md.
	var goal_missing := false
	for loc in BridgeClient.snapshot.get("missing_location_ids", []):
		if int(loc) == Constants.GOAL_LOCATION_ID:
			goal_missing = true
	var finale := goal_missing and (mode == "FINALE_ONLY"
			or bool(BridgeClient.hub().get("finale_offered", false)))
	if not already_ready:
		BridgeClient.send_intent({"type": "request_next_zone",
				"finale": finale})
	if not await _await_condition("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return false
	var record := BridgeClient.active_zone()
	var zone_dict: Dictionary = record.get("zone", {})
	if detailed:
		_check(not zone_dict.is_empty(), "zone content arrived")
	print("zone %s: '%s' (%s)%s checks %s" % [record.get("zone_id"),
			zone_dict.get("display_name"), zone_dict.get("theme"),
			" [FINALE]" if record.get("is_finale") else "",
			str(record.get("allocated_location_ids", []))])

	# ENTER, THEN WAIT FOR THE LAYOUT VERDICT.
	#
	# A refused layout is no longer a toast over a Zone that keeps
	# playing: the bridge sends the Zone back to be composed again
	# against the ids it already holds, and the Zone this client is
	# holding is stale the moment that happens. So the client does what a
	# client has to do -- drop it, wait for the new one, and try again.
	# Bounded, because `MAX_LAYOUT_REFUSALS` bounds the other side.
	var controller: ZoneController = null
	for attempt in 4:
		BridgeClient.send_intent({"type": "enter_zone",
				"zone_id": record.get("zone_id", "")})
		if not await _await_condition("ZONE_ACTIVE",
				func() -> bool:
					return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
			return false
		controller = ZoneController.new()
		get_tree().root.add_child(controller)
		controller.setup(zone_dict)
		# THE CONTROLLER'S OWN VERDICT, WAITED FOR.
		#
		# This sampled `layout_state` off the shared snapshot after
		# twelve physics frames, and both halves of that were a guess.
		# The snapshot can still be carrying the PREVIOUS round's
		# REFUSED -- which is the exact hazard `_await_verdict` has its
		# `layout_refusals` guard for, and reading the raw field walks
		# straight past that guard. And twelve frames is a bet on how
		# long a solve, a certification pass of real replayed crates and
		# a socket round trip take; the placement ladder made the solve
		# longer and the bet started losing, which is how a Zone that
		# was accepted came to be read as refused and then waited on for
		# a recomposition nobody had asked for.
		if not await _await_condition("a layout verdict for %s"
					% str(record.get("zone_id", "")),
				func() -> bool: return controller.layout_verdict != "",
				30.0):
			return false
		if controller.layout_verdict != "REFUSED":
			break
		print("zone %s: layout refused, composing again (attempt %d)"
				% [str(record.get("zone_id", "")), attempt + 1])
		controller.queue_free()
		controller = null
		await get_tree().process_frame
		# OR IT RAN OUT OF ATTEMPTS, which is a real outcome and not a
		# hang. `MAX_LAYOUT_REFUSALS` spent on a Zone that was never
		# accepted sends it to ZONE_FAILED, and waiting for a
		# recomposition after that waits forever -- which is exactly
		# what this did when `zone_006` genuinely could not be laid out
		# three times running. The recovery is the one a player has:
		# discard it and ask for another.
		if not await _await_condition("a recomposition or a failure",
				func() -> bool:
					return BridgeClient.hub_mode() in ["ZONE_READY",
							"ZONE_FAILED"], 30.0):
			return false
		if BridgeClient.hub_mode() == "ZONE_FAILED":
			var lost := str(BridgeClient.hub().get("discard_zone_id", ""))
			print("zone %s: exhausted its layout attempts; discarding"
					% lost)
			BridgeClient.send_intent({"type": "abandon_zone",
					"zone_id": lost})
			if not await _await_condition("the failed Zone is discarded",
					func() -> bool:
						return BridgeClient.hub_mode() == "ZONE_AVAILABLE",
					30.0):
				return false
			return await _play_one_zone(detailed, false)
		record = BridgeClient.active_zone()
		zone_dict = record.get("zone", {})
	if controller == null:
		_check(false, "every layout this client sent was refused")
		return false
	# THE ACCEPTED CONTROL, asserted rather than assumed. Everything
	# after this line reads as a Zone that is being played; the thing
	# that makes it one is the bridge having ACCEPTED the layout this
	# client measured and sent.
	_check(str(BridgeClient.active_zone().get("layout_state", ""))
				== "ACCEPTED",
			"the Zone this client is playing has an accepted layout (%s)"
			% str(BridgeClient.active_zone().get("layout_state", "?")))
	# AND THE HOLD IS GONE, but only that one. A pause the player opens
	# now is theirs to close.
	#
	# WAITED FOR, not counted in frames. `layout_state` going ACCEPTED is
	# the bridge answering; the controller releasing its hold is a
	# separate event one turn of its own loop later, and a fixed twelve
	# physics frames is a guess about a round trip over a socket. The
	# controller records the verdict it acted on, so that is what is
	# waited for.
	if not await _await_condition("the controller acts on the verdict",
			func() -> bool:
				return controller.layout_verdict != "", 10.0):
		return false
	_check(controller.layout_verdict == "ACCEPTED",
			"the controller acted on an ACCEPTED verdict, and it acted "
			+ "on '%s'" % controller.layout_verdict)
	_check(controller.player == null
				or not controller.player.holds().has(
					ZoneController.LAYOUT_HOLD),
			"the acceptance hold outlived the acceptance: %s"
			% str(controller.player.holds()))
	if controller.player != null:
		controller.player.hold("modal")
		_check(controller.player.input_frozen,
				"a menu opened after acceptance does not hold the player")
		controller.player.release("modal")
		_check(not controller.player.input_frozen,
				"the player is still held with no claim standing: %s"
				% str(controller.player.holds()))
	await get_tree().process_frame
	await get_tree().process_frame

	if detailed:
		_check(controller.player != null, "player spawned")
		_check(controller._exit_portal != null, "exit portal appended")
		# COMPLETION REACHES THE SCREEN, asserted on the live object
		# graph and not by reading a source file.
		#
		# `ActivityRuntime` clocks, says DONE and grants a local reward,
		# and it emitted `completed` to NOBODY -- which is why a
		# playtester finished four activities and perceived none of it.
		# Checking that the signal has a listener is the property; a
		# test that greps the controller for a `connect` call would pass
		# on a connection to a function that does nothing.
		var runtimes := get_tree().get_nodes_in_group(
				ActivityRuntime.GROUP)
		var unheard := 0
		for node: Node in runtimes:
			var runtime := node as ActivityRuntime
			if runtime == null:
				continue
			if runtime.completed.get_connections().is_empty():
				unheard += 1
		_check(not runtimes.is_empty(),
				"the Zone built no activities, so nothing here is tested")
		_check(unheard == 0,
				"%d of %d activities complete into silence: `completed` "
				% [unheard, runtimes.size()]
				+ "has no listener, so finishing one tells the player "
				+ "nothing")
		await _check_affordances_and_local_rewards(controller, zone_dict)
		_check(controller._exit_portal.unlocked == false,
				"exit portal starts sealed")
		controller = await _test_leave_and_resume(controller, zone_dict)
		if controller == null:
			return false

	for chamber_record: Dictionary in controller._chambers:
		await _process_chamber(controller, chamber_record, detailed)

	if not await _await_condition("zone completes",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			15.0):
		return false
	controller.refresh()
	if detailed:
		_check(controller._exit_portal.unlocked, "exit portal unlocked")
		var actions: Array = BridgeClient.owned_components("action")
		if not actions.is_empty():
			var action: Dictionary = actions[0].get("component", {})
			var slot := str(action.get("slot", "echo_a"))
			var component_id := str(action.get("component_id", ""))
			BridgeClient.send_intent({"type": "slot_action", "slot": slot,
					"component_id": component_id})
			await _await_condition("action slotted",
					func() -> bool:
						return str(BridgeClient.slots().get(slot)) \
								== component_id)
			controller.player.echo_runtime.set_equipped(
					BridgeClient.slotted_action(slot))
			controller.player.echo_runtime.activate()
			_check(controller.player.echo_runtime.cooldown_remaining >= 0.0,
					"a slotted action activates on demand")
			_check_slotted_action_tint(controller.player.echo_runtime)
			# Only Actions occupy slots. A trait is on because it is owned,
			# which is the whole reason a Check can matter unequipped.
			for entry: Dictionary in BridgeClient.owned_components("trait"):
				_check(not (str(entry.get("component", {}).get(
						"component_id", "")) in BridgeClient.slots().values()),
						"a trait never occupies a slot")
	# THE REAL EXIT, TAKEN RATHER THAN SIMULATED.
	#
	# This used to jump straight to the timing intent with a comment
	# admitting the driver "never takes the real exit path". The first
	# human playtest then cleared every Check, walked into the portal,
	# and the game CRASHED -- `camera_ray` read `.direct_space_state`
	# off a null `get_world_3d()` on the first frame after the player
	# left the tree with the Zone. A suite that reaches
	# ALL_CHECKS_CLEARED through intents cannot see that, because the
	# portal is the one thing it never touches.
	#
	# So the portal is interacted with the way a player interacts with
	# it, and the frames AFTER it are stepped with the player detached,
	# which is the state the crash lived in.
	var left := []
	controller.exit_requested.connect(func() -> void: left.append(true))
	var leaver := Player.create()
	controller.add_child(leaver)
	await get_tree().physics_frame
	controller._exit_portal.interact(leaver)
	await get_tree().process_frame
	_check(left.size() == 1,
			"EXIT: interacting with the portal asks to leave the Zone "
			+ "(%d request(s))" % left.size())
	# The teardown `main.gd::_on_exit_zone` performs, in its order: the
	# timing intent, then the Zone goes.
	var timing: Dictionary = controller.playtime.to_intent(
			str(zone_dict.get("zone_id", "")), true)
	if not timing.is_empty():
		BridgeClient.send_intent(timing)
	controller.remove_child(leaver)
	controller.queue_free()
	await get_tree().process_frame
	# AND THE FRAMES AFTER IT. The player is out of the tree and its
	# world is gone; this is exactly where the crash was.
	for _i in 12:
		await get_tree().physics_frame
	_check(is_instance_valid(leaver),
			"EXIT: and the player survives the frames after the Zone "
			+ "is torn down")
	_check(leaver.camera_ray(3.0).is_empty(),
			"EXIT: with its probe answering empty rather than reading a "
			+ "world that is not there")
	_check(str(BridgeClient.hub_mode()) != "",
			"EXIT: and the campaign still reports a mode (%s)"
			% str(BridgeClient.hub_mode()))
	leaver.free()
	await get_tree().process_frame
	return true

## S9, end to end through the live bridge: the fallback offers only what
## the campaign can use, the client builds it off the mandatory path, and
## collecting what it holds records a LOCAL reward and no AP truth.
##
## Everything below runs against a real generated Zone rather than a
## fixture, which is the point: `make godot-affordance` proves the rules
## in isolation, and this proves a provider, a validator, a builder and a
## save actually agree about one Zone.
func _check_affordances_and_local_rewards(_controller: ZoneController,
		zone_dict: Dictionary) -> void:
	var offered: Array = []
	for chamber: Dictionary in zone_dict.get("chambers", []):
		for feature: Dictionary in chamber.get("features", []):
			offered.append(str(feature.get("tag", "")))
			# §13.2 on the wire, not just in the validator: a feature must
			# never share a chamber with a Check.
			_check(chamber.get("reward_location_id") == null,
					"no feature shares a chamber with an AP reward")
	if offered.is_empty():
		# Base-kit tags are always unlocked, so an empty set means the
		# fallback stopped placing features and the rest of this proves
		# nothing. Worth failing on rather than skipping past.
		_check(false, "a generated Zone offered no affordance at all")
		return
	_affordances_seen += offered.size()

	# I12 through the whole stack: the bridge told the client what the
	# campaign owns, and nothing outside that set was offered.
	var usable: Array = []
	for entry: Dictionary in BridgeClient.owned_components("affordance"):
		usable.append(str(entry.get("component", {}).get("tag", "")))
	for tag: String in offered:
		# THE BASE KIT, FROM THE CONTRACT. This was a hand-written pair
		# here and a tuple in `bridge/tests/test_affordances.py`, which
		# is two places recording one decision -- so the day
		# `powered_door` joined the kit the engine offered it correctly
		# and this line failed the Zone for offering it. One definition,
		# exported, read by both sides.
		_check(tag in Constants.BASE_KIT_TAGS or tag in usable,
				"'%s' was offered without the capability that pays for it"
				% tag)

	# The builder turned them into geometry, off the walking lane.
	var built := get_tree().get_nodes_in_group(AffordanceFeatures.GROUP)
	_check(built.size() > 0, "the client built the offered affordances")

	# ...and each one hung a LOCAL reward, never an AP one. Collecting it
	# has to reach the save through the bridge and come back in a snapshot.
	var pickups := get_tree().get_nodes_in_group(LocalRewardPickup.GROUP)
	_check(pickups.size() > 0, "the affordances hold local rewards")
	if pickups.is_empty():
		return
	var before := _local_reward_count()
	var checked_before: Array = BridgeClient.snapshot.get(
			"checked_location_ids", []).duplicate()
	(pickups[0] as LocalRewardPickup).collect()
	if await _await_condition("local reward recorded",
			func() -> bool: return _local_reward_count() > before, 10.0):
		_local_rewards_earned += 1
	# I13: it moved nothing of Archipelago's.
	_check(BridgeClient.snapshot.get("checked_location_ids", [])
			== checked_before,
			"earning a local reward checked no AP location")

func _local_reward_count() -> int:
	var rewards: Variant = BridgeClient.snapshot.get("local_rewards", [])
	return (rewards as Array).size() if typeof(rewards) == TYPE_ARRAY else 0

## Satisfy one chamber's objective honestly, then claim its reward.
func _process_chamber(controller: ZoneController,
		chamber_record: Dictionary, detailed: bool) -> void:
	var reward: RewardObject = chamber_record["reward"]
	if reward != null and BridgeClient.is_checked(reward.location_id):
		return                                    # confirmed on a prior visit
	match chamber_record["objective"]:
		"kill_all":
			if detailed and reward != null and reward.state == "locked":
				reward.interact(controller.player)
				await get_tree().process_frame
				_check(not BridgeClient.is_pending(reward.location_id),
						"locked reward refuses interaction (test 58)")
			for enemy in chamber_record["enemies"]:
				if is_instance_valid(enemy):
					enemy.die()
			await get_tree().process_frame
		"platform_to_goal":
			controller._on_goal_area_entered(controller.player,
					chamber_record)
			await get_tree().process_frame
	if reward == null:
		return
	if not await _await_condition("reward %d available" % reward.location_id,
			func() -> bool: return reward.state == "available", 5.0):
		return
	if detailed:
		controller.player.take_damage(10000.0)
		await get_tree().process_frame
		_check(reward.state == "available",
				"objective stays latched through death (test 59)")
	reward.interact(controller.player)
	await _await_condition("check %d confirmed" % reward.location_id,
			func() -> bool:
				return BridgeClient.is_checked(reward.location_id), 15.0)

## Acceptance Test I: leave and resume. Clears ONE chamber, leaves via the
## pause path, verifies the Zone goes DORMANT and still blocks a new one,
## then rebuilds the scene and verifies transient reset + persistence.
##
## **Leaving no longer keeps the Zone ACTIVE.** The bridge lane separated
## the two questions a single state used to answer: a Zone walked out of
## with work outstanding becomes `DORMANT` and `active_zone_id` is
## cleared, and it is re-entered rather than resumed-in-place. It still
## reserves its Checks -- `holds_locations` is "not terminal" and DORMANT
## is not terminal -- so the one-Zone-at-a-time rule is unchanged and is
## what this still asserts.
##
## The old assertion read the snapshot BEFORE the leave landed, so a mode
## that was still `ZONE_ACTIVE` from the previous frame satisfied it and
## the real post-leave state was never examined.
func _test_leave_and_resume(controller: ZoneController,
		zone_dict: Dictionary) -> ZoneController:
	var first: Dictionary = {}
	for chamber_record: Dictionary in controller._chambers:
		if chamber_record["reward"] != null:
			first = chamber_record
			break
	if first.is_empty():
		return controller
	await _process_chamber(controller, first, true)
	var claimed: int = first["reward"].location_id
	_check(BridgeClient.is_checked(claimed), "first check confirmed")
	# The pedestal has not repainted yet — refresh drives that — so do it
	# here and watch for the beam the confirming transition should fire.
	first["reward"].refresh_from_snapshot()
	_check(first["reward"].get_node_or_null(RewardObject.BEAM_NAME) != null,
			"confirming a check fires its transmission beam")

	var zone_id := controller.zone_id
	controller.queue_free()
	await get_tree().process_frame
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": zone_id})
	await get_tree().process_frame
	# WAIT FOR THE LEAVE TO LAND, not for a mode that was already true.
	if not await _await_condition("snapshot after leave",
			func() -> bool:
				return BridgeClient.hub_mode() != "ZONE_ACTIVE", 5.0):
		return null
	var after_leave := BridgeClient.hub_mode()
	_check(after_leave != "ZONE_ACTIVE",
			"the Zone was left and the Hub still calls it active (test I)")

	var errors_before := _error_count
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	var refused := await _await_condition("second zone request refused",
			func() -> bool: return _error_count > errors_before, 5.0)
	_check(refused,
			"a second Zone was requested while a DORMANT one still holds "
			+ "its locations and nothing refused it (test I)")
	# AND NOTHING STARTED. A refusal that still generated would show up
	# here and nowhere else.
	_check(BridgeClient.hub_mode() != "GENERATING"
				and BridgeClient.hub_mode() != "ZONE_READY",
			"a new Zone began generating while a DORMANT one still holds "
			+ "its locations: mode is '%s' (test I)"
			% BridgeClient.hub_mode())

	# RE-ENTRY IS AN INTENT NOW, not a rebuild of the scene.
	#
	# A DORMANT Zone is re-entered rather than resumed in place: the
	# bridge moves it back to ACTIVE and makes it the active Zone again,
	# and nothing the player does inside it counts until it has. The old
	# flow rebuilt the controller and went straight on claiming Checks,
	# which the bridge now refuses because the Zone it names is not the
	# one in play.
	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zone_id})
	if not await _await_condition("re-entry makes the Zone active again",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE", 5.0):
		return null
	_check(str(BridgeClient.active_zone().get("zone_id", "")) == zone_id,
			"re-entering the DORMANT Zone made a different Zone active "
			+ "(test I)")

	var resumed := ZoneController.new()
	get_tree().root.add_child(resumed)
	resumed.setup(zone_dict)
	await get_tree().process_frame
	await get_tree().process_frame
	for chamber_record: Dictionary in resumed._chambers:
		var reward: RewardObject = chamber_record["reward"]
		if reward == null:
			continue
		if reward.location_id == claimed:
			_check(reward.state == "confirmed",
					"confirmed reward stays disabled after resume (test I)")
			# A resumed Zone rebuilds every pedestal straight into its
			# final state. Those are not transmissions happening now, so
			# none of them may fire the send beam.
			_check(reward.get_node_or_null(RewardObject.BEAM_NAME) == null,
					"resuming does not replay the transmission beam")
		elif chamber_record["objective"] != "reach_reward":
			_check(reward.state == "locked",
					"objectives reset on resume (test I)")
	_check(resumed._exit_portal.unlocked == false,
			"exit portal stays locked until every check confirms (test I)")
	return resumed

func _try_shop_purchase() -> void:
	var snapshot := BridgeClient.snapshot
	var coins := int(snapshot.get("coins_available", 0))
	for item: Dictionary in snapshot.get("shop", {}).get("stock", []):
		var cost := int(item.get("cost", 0))
		if coins < cost:
			continue
		var location := int(item.get("location_id", 0))
		var spent_before := int(snapshot.get("coins_spent", 0))
		BridgeClient.send_intent({"type": "buy_shop_stock",
				"location_id": location})
		if not _double_buy_probed:
			# Test O: the second intent for the same location must be
			# refused and charge nothing.
			_double_buy_probed = true
			BridgeClient.send_intent({"type": "buy_shop_stock",
					"location_id": location})
		var confirmed := await _await_condition(
				"purchase %d confirms" % location,
				func() -> bool: return BridgeClient.is_checked(location),
				15.0)
		if confirmed:
			_bought_once = true
			var spent_after := int(
					BridgeClient.snapshot.get("coins_spent", 0))
			_check(spent_after == spent_before + cost,
					"double buy charged exactly once (test O)")
		return


## The Lab is built with the Hub, so this asks the Hub for it and then
## asserts the one thing that would be catastrophic: that having it there
## moved campaign truth. Everything else about the Lab is proven by
## `make godot-lab`.
func _lab_built_and_changed_nothing() -> bool:
	var before := JSON.stringify({
		"checked": BridgeClient.snapshot.get("checked_location_ids", []),
		"mechanics": BridgeClient.mechanics(),
		"slots": BridgeClient.slots()})
	var hub := HubController.new()
	get_tree().root.add_child(hub)
	await get_tree().process_frame
	var ok := hub.lab != null and hub.lab.dummy != null \
			and hub.lab.fixture("hazard") != null
	hub.lab.reset(hub.player)
	var after := JSON.stringify({
		"checked": BridgeClient.snapshot.get("checked_location_ids", []),
		"mechanics": BridgeClient.mechanics(),
		"slots": BridgeClient.slots()})
	hub.queue_free()
	await get_tree().process_frame
	return ok and before == after
