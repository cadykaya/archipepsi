class_name D22SliceDriver
extends "res://tests/candidate_live_driver.gd"
## D-22 SLICE — §6.A OF `docs/D22_SLICE_BRIEF.md`, THROUGH A REAL BRIDGE
## AND REAL RESTARTS (`--d22-live=<phase>`).
##
##     tools/d22_slice_check.sh        (or: make godot-d22-slice)
##
## Each phase is a NEW client beside a NEW bridge started exactly as the
## slice launcher starts it (`--ap=mock --mock-scale prototype
## --epsilon=fallback --d22-slice`, its own save folder); only the save --
## and this driver's own notes file -- cross between them:
##
##   forge      the campaign starts from the slice flag; the Hub is the
##              slice's (Forge console, area 2 shut, lamp red). A first
##              draft is ACCEPTED and then ABANDONED from inside: the door
##              stays shut (A9). Then a signal is PICKED at the Forge (A1),
##              the card is held against the Zone (A2), it is redrawn twice
##              and refused a third time (A3). Quit with the draft open.
##   draft      both processes new: the same draft (A6). ACCEPT: first
##              entry commits the layout (A4); a redraw is refused now (A3).
##              One Check released, out through the always-usable exit
##              ("LEAVE — 2 transfers remain"): DORMANT, Checks held, the
##              Forge says RESUME (A5). Re-entered: the layout replays (A4)
##              and the resume point is measured against the exit point
##              (A7, reported). A second Check, then quit mid-Crossing.
##   crossing   both processes new: the Crossing resumes (A6). The last
##              Check: COMPLETE, count 1, the tether lets go with one line,
##              the portal reads RETURN; back at the station the Forge
##              lists it Untethered and area 2's lamp goes red -> green
##              (A8, A9).
##   area_two   both processes new: the door is still open (A9). Walked --
##              not placed -- through the door and corridor to the lever;
##              the lever raises the shutter; on to the second Forge, which
##              builds Crossing 2 from the shared pool (A10). STOP when
##              Crossing 2's first entry commits its layout.
##
## **HARNESS STEPS, declared:** Checks are released by the intent their
## pedestal sends (`claim_check`), not walked to -- the Crossing's rooms
## are not under test, its lifecycle is. The Forge's buttons are pressed
## through the screen's own handlers (`request_draft`, `request_redraw`,
## `accept_draft`), which are what the buttons call. Consoles in the Hub
## are used through `interact`, as other live suites use the portal;
## area 2's route is walked and its lever and Forge are used by the
## player's own interact ray.

const D22_PHASE_FLAG := "--d22-live="
const D22_NOTES_FLAG := "--d22-notes="
## The prototype scale's allocation (bridge `schemas/constants.py`):
## up to 3 of the signal's own Checks, topped up from other signals only
## when it has fewer than 2. Allocation itself is unchanged by the slice.
const PROTOTYPE_TARGET := 3
const PROTOTYPE_MIN := 2

var _state: Dictionary = {}
## `--d22-demo`: the same phases with pauses and captions at the moments
## worth seeing, for the recorded demonstration. Every check still runs.
var _demo := "--d22-demo" in OS.get_cmdline_user_args()
var _caption_label: Label = null


static func phase_from_cmdline() -> String:
	return _arg(D22_PHASE_FLAG)


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(err))
	_load_state()
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match phase_from_cmdline():
			"forge":
				await _phase_forge()
			"draft":
				await _phase_draft()
			"crossing":
				await _phase_crossing()
			"area_two":
				await _phase_area_two()
			_:
				_check(false, "no --d22-live phase was named")
	_save_state()
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"move_back", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	for line: String in notes:
		print("  NOTE " + line)
	var phase := phase_from_cmdline().to_upper()
	if failures == 0:
		print("GODOT D22 SLICE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT D22 SLICE %s: %d failures in %d checks"
				% [phase, failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# -- phases ----------------------------------------------------------------------

func _phase_forge() -> void:
	# THE LAUNCHER'S OWN START: `--d22-slice` on Godot's command line is
	# what sends `start_mock_campaign`; this driver sends nothing to start.
	if not await _await_live("the slice flag starts the campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0):
		return
	var hub := await _the_hub()
	if hub == null:
		return
	_check(D22Slice.active(), "the bridge publishes the Forge view")
	_check(bool(BridgeClient.snapshot.get("ap_connected", false))
			and str(BridgeClient.snapshot.get("ap_mode", "")) == "mock",
			"A11: connected to the mock Archipelago, not a real one")
	_check(hub.portal().interact_prompt() == "[E] USE THE FORGE",
			"the portal is the Forge console: '%s'"
			% hub.portal().interact_prompt())
	_check(hub.area_two != null, "station area 2 is built")
	_check(not hub.area_two.door_open() and not hub.area_two.lamp_is_green(),
			"A9: at count 0 area 2's door is shut and its lamp red")
	if _demo:
		await _demo_station_one(hub)
		await _phase_forge_choice(hub)
		return

	# A9, AFTER AN ABANDON. Draft, accept, enter -- and abandon from inside.
	var forge := await _open_forge(hub, 1)
	if forge == null:
		return
	forge.request_draft()
	if not await _drafted():
		return
	var first_id := str(BridgeClient.active_zone().get("zone_id", ""))
	forge.accept_draft()
	var crossing := await _entered(first_id)
	if crossing == null:
		return
	main._on_abandon()
	if not await _await_live("the abandon lands in the Hub",
			func() -> bool:
				return main.hub != null and BridgeClient.hub_mode() \
						== "ZONE_AVAILABLE", 30.0):
		return
	hub = await _the_hub()
	_check(int(BridgeClient.snapshot.get("completed_zone_count", -1)) == 0,
			"A9: an abandon does not count as untethered")
	_check(not hub.area_two.door_open(),
			"A9: after an abandon the door is still shut")
	await _settle(90)
	_check(not hub.area_two.door_open(),
			"A9: and stays shut after the Hub has run a while")
	await _phase_forge_choice(hub)


## A1-A3, from the Forge's signal list to the third redraw refused.
func _phase_forge_choice(hub: HubController) -> void:
	# A1: THE SIGNALS. Only tracks with eligible Checks; pick one that is
	# not the cursor's.
	_caption("Station area 1 · the Forge: pick a signal")
	var forge := await _open_forge(hub, 1)
	await _linger(2.5)
	var view := D22Slice.forge()
	var signals: Array = view.get("signals", [])
	_check(not signals.is_empty(), "A1: the Forge lists signals")
	var all_eligible := true
	for raw: Variant in signals:
		all_eligible = all_eligible and int((raw as Dictionary).get(
				"eligible", 0)) > 0
	_check(all_eligible, "A1: every listed signal has an eligible Check")
	var default := str(view.get("default_track", ""))
	_check(forge.picked_signal() == default,
			"A1: the cursor's signal is pre-selected ('%s')" % default)
	# The richest signal that is not the cursor's, so the pick is visibly
	# the player's and, where the pool allows, a full three-Check frame.
	var chosen := ""
	var chosen_n := 0
	for raw: Variant in signals:
		var entry: Dictionary = raw
		if str(entry["track"]) != default and int(entry["eligible"]) > chosen_n:
			chosen = str(entry["track"])
			chosen_n = int(entry["eligible"])
	var tallies: Array[String] = []
	for raw: Variant in signals:
		tallies.append("%s %d" % [(raw as Dictionary)["track"],
				int((raw as Dictionary)["eligible"])])
	_note("A1: signals offered (eligible Checks): " + ", ".join(tallies))
	_check(chosen != "", "A1: there is a signal other than the cursor's")
	forge.pick_signal(chosen)
	forge.rebuild()
	await _linger(1.2)
	_caption("Epsilon drafts a Crossing around '%s'" % chosen)
	forge.request_draft()
	_check(_intents("request_next_zone").back().get("track", "") == chosen,
			"A1: the request carries the picked signal")
	if not await _drafted():
		return
	var record := BridgeClient.active_zone()
	var ids: Array = record.get("allocated_location_ids", [])
	_check(str(record.get("target_game", "")) == chosen,
			"A1: the Crossing is X's ('%s')" % record.get("target_game", ""))
	var want := maxi(mini(chosen_n, PROTOTYPE_TARGET), PROTOTYPE_MIN)
	_check(ids.size() == want,
			"A1: %d Checks allocated -- %d of '%s''s own%s, as today"
			% [ids.size(), mini(chosen_n, PROTOTYPE_TARGET), chosen,
			"" if chosen_n >= PROTOTYPE_MIN else ", topped up"])
	_note("A1: '%s' had %d eligible, so this Crossing holds %d Checks "
			% [chosen, chosen_n, ids.size()] + "(prototype: up to 3, top-up "
			+ "only below 2)")

	# A2: THE CARD AGAINST THE ZONE.
	_caption("Epsilon's draft card -- read from the Zone itself")
	await _card_matches(forge, record)
	await _linger(3.5)

	# A3: TWO REDRAWS, SAME IDS, DIFFERENT DRAFTS; NO THIRD.
	var drafts := [_fingerprint(record)]
	for n in [1, 2]:
		_check(int(D22Slice.forge().get("redraws_left", -1)) == 3 - n,
				"A3: the card offers %d redraw(s)" % (3 - n))
		_caption("REDRAW %d of 2 -- same Checks, new rooms" % n)
		forge.request_redraw()
		if not await _await_live("redraw %d drafted" % n,
				func() -> bool:
					var r := BridgeClient.active_zone()
					return BridgeClient.hub_mode() == "ZONE_READY" \
							and int(r.get("redraw_count", 0)) == n, 60.0):
			return
		var again := BridgeClient.active_zone()
		_check(again.get("allocated_location_ids", []) == ids,
				"A3: redraw %d keeps the same Check ids" % n)
		_check(not (_fingerprint(again) in drafts),
				"A3: redraw %d is a different draft" % n)
		_check(str(again.get("layout_state", "")) in ["UNCERTIFIED", ""],
				"A3: redraw %d is proved afresh, uncommitted" % n)
		drafts.append(_fingerprint(again))
		await _card_matches(forge, again)
		await _linger(2.5)
	_check(int(D22Slice.forge().get("redraws_left", -1)) == 0,
			"A3: at the cap the Forge offers no redraw")
	_check(not _has_button(forge, "REDRAW"),
			"A3: at the cap the card shows ACCEPT only")
	var errors_before := _errors.size()
	BridgeClient.send_intent({"type": "redraw_zone",
			"zone_id": str(record.get("zone_id", ""))})
	await _await_live("a third redraw refused",
			func() -> bool: return _errors.size() > errors_before, 10.0)
	_check(int(BridgeClient.active_zone().get("redraw_count", 0)) == 2
			and BridgeClient.hub_mode() == "ZONE_READY",
			"A3: a third redraw is refused and changes nothing")
	_state["zone_1"] = str(record.get("zone_id", ""))
	_state["draft_1"] = drafts.back()
	_state["ids_1"] = ids
	_state["name_1"] = str(BridgeClient.active_zone().get("zone", {}).get(
			"display_name", ""))
	_caption("Quit with the draft open...")
	await _linger(1.5)
	_note("A6: quitting with the draft open (redraw 2 on the card)")


func _phase_draft() -> void:
	if not await _campaign():
		return
	var hub := await _the_hub()
	if hub == null:
		return
	var zid := str(_state.get("zone_1", ""))
	var record := BridgeClient.active_zone()
	_check(BridgeClient.hub_mode() == "ZONE_READY"
			and str(record.get("zone_id", "")) == zid,
			"A6: after a relaunch the same Crossing is on offer")
	_check(_fingerprint(record) == str(_state.get("draft_1", "")),
			"A6: and it is the same draft, not a new one")
	_caption("Relaunched: the same draft is waiting. ACCEPT")
	var forge := await _open_forge(hub, 1)
	await _card_matches(forge, record)
	await _linger(2.5)
	forge.accept_draft()
	var crossing := await _entered(zid)
	if crossing == null:
		return
	_caption("Crossing 1 -- the first entry commits its layout")
	await _linger(2.5)
	var committed := _layout_commit()
	_check(committed != "", "A4: the first entry committed the layout")
	_state["layout_1"] = committed
	var errors_before := _errors.size()
	BridgeClient.send_intent({"type": "redraw_zone", "zone_id": zid})
	await _await_live("a redraw after entry refused",
			func() -> bool: return _errors.size() > errors_before, 10.0)
	_check(int(BridgeClient.active_zone().get("redraw_count", 0)) == 2
			and BridgeClient.hub_mode() == "ZONE_ACTIVE",
			"A3: a redraw after the first entry is refused")

	# ONE CHECK, THEN OUT THROUGH THE EXIT EARLY.
	var ids: Array = record.get("allocated_location_ids", [])
	if not await _release(zid, [int(ids[0])]):
		return
	await _settle(10)
	var portal: ExitPortal = crossing._exit_portal
	var out := ids.size() - 1
	_check(portal.unlocked and portal.interact_prompt()
			== "[E] " + _leave_label(out),
			"exit fix: with Checks out the portal is usable: '%s'"
			% portal.interact_prompt())
	_check(not portal.tether_released(), "the Crossing is still tethered")
	var exit_at := await _face_the_exit(crossing)
	_caption("One Check released. The exit is always a way out")
	await _linger(3.5)
	portal.interact(crossing.player)
	if not await _await_live("the Crossing is put down",
			func() -> bool:
				return main.hub != null \
						and BridgeClient.hub_mode() == "ZONE_DORMANT", 30.0):
		return
	hub = await _the_hub()
	var view := D22Slice.forge()
	var resume: Variant = view.get("resume")
	_check(typeof(resume) == TYPE_DICTIONARY
			and str((resume as Dictionary).get("zone_id", "")) == zid
			and int((resume as Dictionary).get("remaining", -1)) == out,
			"A5: DORMANT, and the Forge offers RESUME with %d remaining" % out)
	_check(BridgeClient.active_zone().is_empty(),
			"A5: put down -- no Crossing is active (DORMANT clears it)")
	_caption("Back at the station: the Crossing waits, DORMANT")
	forge = await _open_forge(hub, 1)
	_check(_has_button(forge, "RESUME"), "A5: the Forge shows RESUME")
	_check(not _has_button(forge, "REDRAW"), "A5: and no REDRAW")
	await _linger(2.5)
	forge.accept_draft()
	crossing = await _entered(zid)
	if crossing == null:
		return
	_check(_layout_commit() == str(_state.get("layout_1", "")),
			"A4: re-entry replays the committed layout")
	await _settle(20)
	var spawn := crossing.player.global_position
	var drift := spawn.distance_to(exit_at)
	_state["a7_m"] = drift
	_note("A7: exit point %v, resume spawn %v: %.2f m apart (reported, "
			% [exit_at, spawn, drift] + "not pass/fail)")
	_note("A6: quitting mid-Crossing with %d transfer(s) left" % out)


func _phase_crossing() -> void:
	if not await _campaign():
		return
	var hub := await _the_hub()
	if hub == null:
		return
	var zid := str(_state.get("zone_1", ""))
	var view := D22Slice.forge()
	var resume: Variant = view.get("resume")
	_check(typeof(resume) == TYPE_DICTIONARY
			and str((resume as Dictionary).get("zone_id", "")) == zid,
			"A6: after quitting mid-Crossing the Forge offers it back")
	_check(not hub.area_two.door_open(), "A9: still shut at count 0")
	_caption("Relaunched mid-Crossing: RESUME")
	var forge := await _open_forge(hub, 1)
	await _linger(1.5)
	forge.accept_draft()
	var crossing := await _entered(zid)
	if crossing == null:
		return
	_check(_layout_commit() == str(_state.get("layout_1", "")),
			"A6: resumed into the same committed layout")
	var ids: Array = _state.get("ids_1", [])
	var said := ""
	var portal: ExitPortal = crossing._exit_portal
	var rest := ids.slice(1)
	_check(portal.interact_prompt() == "[E] " + _leave_label(rest.size()),
			"the exit still counts what is out: '%s'"
			% portal.interact_prompt())
	_check(not D22Slice.is_untethered(zid) and not portal.tether_released(),
			"A8: still tethered with a Check out")
	if rest.size() > 1 and not await _release(zid,
			rest.slice(0, rest.size() - 1)):
		return
	await _settle(10)
	_check(not D22Slice.is_untethered(zid),
			"A8: not untethered while any Check is out")
	_caption("The last Check... (mock Archipelago confirms it)")
	await _linger(2.0)
	if not await _release(zid, [rest.back()]):
		return
	if not await _await_live("the bridge untethers the Crossing",
			func() -> bool: return D22Slice.is_untethered(zid), 30.0):
		return
	await _settle(6)
	said = main.hud._voice_label.text
	_check(int(BridgeClient.snapshot.get("completed_zone_count", 0)) == 1,
			"A8: COMPLETE, and the count is 1")
	_check(portal.interact_prompt() == "[E] RETURN",
			"A8: the portal reads RETURN: '%s'" % portal.interact_prompt())
	_check(said.contains("Tether's off"),
			"A8: Epsilon's one line plays: '%s'" % said)
	# THE MOMENT WAITS TO BE SEEN. Far from the exit, the anchor already
	# reads UNTETHERED but has not played its release; walking into the
	# exit room is what plays it.
	var far := crossing.player.global_position.distance_to(
			portal.global_position)
	if far > ExitPortal.SEEN_WITHIN + 3.0:
		await _settle(30)
		_check(portal.tether_release_pending()
				and not portal.tether_released(),
				"A8: %.0f m away, the release waits for the player" % far)
	else:
		_note("A8: the player was already near the exit (%.1f m); the "
				% far + "wait-to-be-seen branch was not exercised")
	_caption("UNTETHERED. Back to the exit: the anchor lets go")
	await _face_the_exit(crossing)
	if not await _await_live("the tether lets go",
			func() -> bool: return portal.tether_released(), 5.0):
		return
	_check(true, "A8: the destination anchor released its tether, in view")
	await _linger(3.0)
	portal.interact(crossing.player)
	if not await _await_live("back in the station",
			func() -> bool: return main.hub != null and main.view == 1, 30.0):
		return
	hub = await _the_hub()
	if _demo:
		_look_at(hub.player, hub.area_two.lamp.global_position
				- Vector3(0, 1.2, 0))
	_caption("Station: area 2's lamp, red -> green")
	_check(not hub.area_two.lamp_is_green(),
			"A8: on arrival the lamp is still red, for the moment to play")
	if not await _await_live("area 2's lamp goes green",
			func() -> bool: return hub.area_two.lamp_is_green(), 5.0):
		return
	await _await_live("area 2's door opens",
			func() -> bool:
				return hub.area_two.door.position.y < -1.0, 5.0)
	_check(hub.area_two.door_open(), "A8/A9: at count 1 the door opens")
	await _linger(2.0)
	_caption("The Forge lists Crossing 1 as UNTETHERED")
	forge = await _open_forge(hub, 1)
	var untethered: Array = D22Slice.forge().get("untethered", [])
	_check(untethered.size() == 1
			and str((untethered[0] as Dictionary).get("zone_id")) == zid,
			"A8: the Forge lists the Crossing as Untethered")
	_check(_label_shown(forge, "UNTETHERED"),
			"A8: and shows it under UNTETHERED")
	await _linger(2.5)
	forge.close()


func _phase_area_two() -> void:
	if not await _campaign():
		return
	var hub := await _the_hub()
	if hub == null:
		return
	_check(hub.area_two.door_open() and hub.area_two.lamp_is_green(),
			"A9: after a relaunch the door is open and the lamp green")
	_check(int(BridgeClient.snapshot.get("completed_zone_count", 0)) == 1,
			"count 1, derived from the save (no door state is saved)")
	var checked_before: int = (BridgeClient.snapshot.get(
			"checked_location_ids", []) as Array).size()
	var player := hub.player
	var a2 := hub.area_two
	_caption("Relaunched: the door stays open. Into station area 2")
	# WALKED, through the Hub door and the corridor, to the lever.
	var route: Array[Vector3] = [Vector3(8.5, 0, StationAreaTwo.DOOR_Z),
			Vector3(13.0, 0, StationAreaTwo.DOOR_Z),
			Vector3(19.5, 0, StationAreaTwo.DOOR_Z)]
	for goal: Vector3 in route:
		if not await _hop_walk(player, goal, 0.6, 900):
			_check(false, "A10: walked to %v (stopped at %v)"
					% [goal, player.global_position])
			return
	_check(player.global_position.x > StationAreaTwo.HUB_WALL_X + 6.0,
			"A10: through the door and corridor into area 2 on foot")
	_check(not a2.shutter.is_open(), "A10: the shutter starts shut")
	var lever_top := a2.lever.global_position \
			+ Vector3(0, CallLever.BASE.y, 0)
	await _hop_walk(player, lever_top + Vector3(-1.2, 0, 0), 0.4, 600)
	var aimed := await _aim(player, a2.lever, lever_top)
	_check(aimed, "A10: the lever is under the player's interact ray")
	_caption("Base-kit machinery: pull the lever, the shutter rises")
	await _linger(1.0)
	await _press("interact")
	await _settle(4)
	_check(a2.lever.pulls == 1, "A10: the lever was pulled by [E]")
	if not await _await_live("the shutter opens",
			func() -> bool: return a2.shutter.is_open(), 6.0):
		return
	_look_at(player, a2.shutter.global_position)
	await _linger(1.5)
	var forge_at := a2.forge.global_position
	for goal: Vector3 in [Vector3(a2.shutter.global_position.x - 1.0, 0,
				StationAreaTwo.DOOR_Z),
			Vector3(forge_at.x - 2.2, 0, forge_at.z)]:
		if not await _hop_walk(player, goal, 0.5, 900):
			_check(false, "A10: walked through the shutter (stopped at %v)"
					% player.global_position)
			return
	var forge_face := forge_at + Vector3(0, 0.9, 0)
	_check(await _aim(player, a2.forge, forge_face),
			"A10: the second Forge is under the interact ray")
	await _press("interact")
	if not await _await_live("area 2's Forge opens",
			func() -> bool: return main.forge_screen.is_open(), 5.0):
		return
	var forge: ForgeScreen = main.forge_screen
	_caption("Station area 2's Forge: construct Crossing 2")
	await _linger(2.0)
	_check(forge.area == 2, "A10: it is area 2's Forge")
	_check(_label_shown(forge, "UNTETHERED"), "and it lists Crossing 1")
	_note("A10: the route used move, jump and interact only -- no Echo "
			+ "was fired or required")
	_check((BridgeClient.snapshot.get("checked_location_ids", []) as Array)
			.size() == checked_before and _intents("claim_check").is_empty(),
			"A10: no station Checks -- nothing was claimed on the way")
	forge.request_draft()
	if not await _drafted():
		return
	var record := BridgeClient.active_zone()
	var zid := str(record.get("zone_id", ""))
	_check(zid != "" and zid != str(_state.get("zone_1", "")),
			"A10: a new Crossing (%s)" % zid)
	var ids: Array = record.get("allocated_location_ids", [])
	var overlap := false
	for raw: Variant in ids:
		overlap = overlap or raw in (_state.get("ids_1", []) as Array)
	_check(ids.size() >= PROTOTYPE_MIN and not overlap,
			"A10: built from the shared pool -- %d fresh Checks" % ids.size())
	await _card_matches(forge, record)
	await _linger(3.0)
	forge.accept_draft()
	var crossing := await _entered(zid)
	if crossing == null:
		return
	_check(_layout_commit() != "",
			"STOP: Crossing 2's first entry committed its layout")
	_caption("Crossing 2 entered, layout committed -- STOP")
	await _linger(3.0)
	_state["zone_2"] = zid


# -- helpers ----------------------------------------------------------------------

func _linger(seconds: float) -> void:
	if _demo:
		await get_tree().create_timer(seconds).timeout


func _caption(text: String) -> void:
	if not _demo:
		return
	if _caption_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_caption_label = Label.new()
		_caption_label.position = Vector2(24, 18)
		_caption_label.add_theme_font_size_override("font_size", 22)
		_caption_label.add_theme_color_override("font_outline_color",
				Color.BLACK)
		_caption_label.add_theme_constant_override("outline_size", 6)
		_caption_label.modulate = Color(1.0, 0.92, 0.6)
		layer.add_child(_caption_label)
	_caption_label.text = "D-22 SLICE  ·  " + text


## HARNESS STEP: placed in the exit room, 3 m in front of the portal and
## facing it and its tether anchor -- the walk there is the Crossing's
## business, not the slice's. Returns where the player stands.
func _face_the_exit(crossing: ZoneController) -> Vector3:
	var portal: ExitPortal = crossing._exit_portal
	var at := portal.global_position
	var room := AABB()
	var nearest := INF
	for raw: Variant in crossing._chambers:
		var bounds: AABB = (raw as Dictionary).get("bounds", AABB())
		if bounds.size == Vector3.ZERO:
			continue
		var d := bounds.get_center().distance_to(at)
		if d < nearest:
			nearest = d
			room = bounds
	var inward := room.get_center() - at
	inward.y = 0.0
	inward = inward.normalized() if inward.length() > 0.01 else Vector3.BACK
	crossing.player.global_position = at + inward * 3.0 + Vector3(0, 0.8, 0)
	crossing.player.velocity = Vector3.ZERO
	await _settle(8)
	for _i in 4:
		_look_at(crossing.player, portal.to_global(Vector3(1.2, 2.2, 0)))
		await get_tree().physics_frame
	var stood := crossing.player.global_position
	_note("HARNESS STEP: placed in the exit room facing the portal at %v"
			% stood)
	return stood


## Demo only: walk from the spawn to the Forge console, and look at it.
func _demo_station_one(hub: HubController) -> void:
	_caption("Station area 1 (graybox). Area 2's door: shut, lamp red")
	_look_at(hub.player, hub.area_two.lamp.global_position)
	await _linger(2.5)
	_caption("Station area 1 · the portal is now the Forge console")
	await _hop_walk(hub.player, hub.portal().global_position
			- Vector3(0, 0, 3.0), 0.6, 600)
	_look_at(hub.player, hub.portal().global_position + Vector3(0, 1.8, 0))
	await _linger(1.0)


static func _leave_label(n: int) -> String:
	return "LEAVE — %d transfer%s remain%s" % [n, "" if n == 1 else "s",
			"s" if n == 1 else ""]


func _the_hub() -> HubController:
	if not await _await_live("the Hub",
			func() -> bool:
				return main.hub != null and (main.hub as HubController) \
						.player != null, 30.0):
		return null
	await _settle(4)
	return main.hub as HubController


func _open_forge(hub: HubController, area: int) -> ForgeScreen:
	if area == 1:
		hub.portal().interact(hub.player)
	else:
		hub.area_two.forge.interact(hub.player)
	if not await _await_live("the Forge screen",
			func() -> bool: return main.forge_screen.is_open(), 5.0):
		return null
	var screen: ForgeScreen = main.forge_screen
	_check(screen.area == area, "the Forge screen is area %d's" % area)
	return screen


func _drafted() -> bool:
	return await _await_live("Epsilon's draft",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			90.0)


func _entered(zid: String) -> ZoneController:
	if not await _await_live("entering %s" % zid,
			func() -> bool:
				return main.zone != null and main.zone.player != null \
						and str(main.zone.zone_id) == zid, 40.0):
		return null
	var controller := main.zone as ZoneController
	if not await _await_live("the bridge accepts the layout",
			func() -> bool: return controller.layout_verdict == "ACCEPTED",
			60.0):
		return null
	await _settle(10)
	return controller


## HARNESS STEP: Checks released by the intent their pedestal sends.
func _release(zid: String, locations: Array) -> bool:
	for raw: Variant in locations:
		BridgeClient.send_intent({"type": "claim_check", "zone_id": zid,
				"location_id": int(raw)})
	var done := func() -> bool:
		for raw: Variant in locations:
			if not BridgeClient.is_checked(int(raw)):
				return false
		return true
	var ok := await _await_live("Checks %s confirmed" % str(locations),
			done, 30.0)
	_note("HARNESS STEP: released %s by claim_check" % str(locations))
	return ok


## The committed layout as the bridge serves it: the manifest's own JSON.
func _layout_commit() -> String:
	var record := BridgeClient.active_zone()
	var manifest: Variant = record.get("manifest")
	if typeof(manifest) != TYPE_DICTIONARY:
		return ""
	return JSON.stringify(manifest, "", true)


func _fingerprint(record: Dictionary) -> String:
	var zone: Variant = record.get("zone")
	if typeof(zone) != TYPE_DICTIONARY:
		return ""
	return JSON.stringify((zone as Dictionary).get("chambers", []), "", true) \
			+ str((zone as Dictionary).get("display_name", ""))


## A2: the card is the Zone's data -- its name and note, its room count,
## its Check count, each room's enemies, activities and features.
func _card_matches(forge: ForgeScreen, record: Dictionary) -> void:
	# The card reveals row by row; let it finish.
	await _await_live("the card is laid down",
			func() -> bool: return not _has_disabled_button(forge), 8.0)
	var zone: Dictionary = record.get("zone", {})
	var text := _screen_text(forge)
	var chambers: Array = zone.get("chambers", [])
	var ids: Array = record.get("allocated_location_ids", [])
	var ok := text.contains(str(zone.get("display_name", "")))
	ok = ok and text.contains(str(zone.get("designer_note", "")))
	ok = ok and text.contains("%d room" % chambers.size())
	ok = ok and text.contains("%d Check" % ids.size())
	ok = ok and text.contains(str(zone.get("target_game", "")))
	var rooms := 0
	for raw: Variant in chambers:
		rooms += 1
		ok = ok and text.contains(ForgeScreen.room_line(raw as Dictionary))
		for e: Variant in (raw as Dictionary).get("enemies", []):
			ok = ok and text.contains("%d %s" % [int((e as Dictionary)["count"]),
					str((e as Dictionary)["archetype"])])
	if bool(record.get("used_fallback", false)):
		ok = ok and text.contains("drafted offline")
	_check(ok, "A2: the card matches '%s' (%d rooms, %d Checks, redraw %d)"
			% [zone.get("display_name", ""), rooms, ids.size(),
			int(record.get("redraw_count", 0))])


func _screen_text(forge: ForgeScreen) -> String:
	var out := ""
	for node: Node in forge.find_children("*", "Label", true, false):
		if (node as Label).visible:
			out += (node as Label).text + "\n"
	return out


func _label_shown(forge: ForgeScreen, text: String) -> bool:
	return _screen_text(forge).contains(text)


func _has_button(forge: ForgeScreen, text: String) -> bool:
	for node: Node in forge.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion() and (node as Button).text \
				.contains(text):
			return true
	return false


func _has_disabled_button(forge: ForgeScreen) -> bool:
	for node: Node in forge.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion() and (node as Button).disabled:
			return true
	return false


func _aim(player: Player, target: Node3D, point: Vector3) -> bool:
	for _i in 60:
		if Vector2(player.velocity.x, player.velocity.z).length() < 0.05:
			break
		await get_tree().physics_frame
	for _i in 40:
		_look_at(player, point)
		await get_tree().physics_frame
		if player._interact_target == target:
			_look_at(player, point)
			await get_tree().physics_frame
			if player._interact_target == target:
				return true
	return player._interact_target == target


func _load_state() -> void:
	var path := _arg(D22_NOTES_FLAG)
	if path == "" or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		_state = parsed


func _save_state() -> void:
	var path := _arg(D22_NOTES_FLAG)
	if path == "":
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_state, "  "))
