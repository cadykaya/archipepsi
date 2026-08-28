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

	# ---- Pass 2: play the campaign to the end -----------------------------
	var zones_played := 1
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

func _play_one_zone(detailed: bool) -> bool:
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
	BridgeClient.send_intent({"type": "request_next_zone", "finale": finale})
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

	BridgeClient.send_intent({"type": "enter_zone",
			"zone_id": record.get("zone_id", "")})
	if not await _await_condition("ZONE_ACTIVE",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false

	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone_dict)
	await get_tree().process_frame
	await get_tree().process_frame

	if detailed:
		_check(controller.player != null, "player spawned")
		_check(controller._exit_portal != null, "exit portal appended")
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
	controller.queue_free()
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
func _check_affordances_and_local_rewards(controller: ZoneController,
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
		_check(tag in ["bounce_pad", "moving_platform"] or tag in usable,
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
## pause path, verifies the Zone stays ACTIVE and no new Zone can start,
## then rebuilds the scene and verifies transient reset + persistence.
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
	if not await _await_condition("snapshot after leave",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE", 5.0):
		return null
	_check(BridgeClient.hub_mode() == "ZONE_ACTIVE",
			"zone stays ACTIVE after leaving (test I)")

	var errors_before := _error_count
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	await _await_condition("second zone request refused",
			func() -> bool: return _error_count > errors_before, 5.0)
	_check(BridgeClient.hub_mode() == "ZONE_ACTIVE",
			"no new zone can be generated while one is ACTIVE (test I)")

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
