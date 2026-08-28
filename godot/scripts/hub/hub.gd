class_name HubController
extends Node3D
## The authored Hub: portal, status board, shop counter, Echo terminal, and
## the Hub-side abandon console. Every displayed fact is read off the
## snapshot — portal_enabled, finale_offered, generation_in_progress are
## computed by the bridge and never re-derived here.

signal enter_zone_requested
signal open_inventory_requested
signal open_shop_requested

const THEME := "concrete_facility"
# Room dimensions live with the anchors that derive from them, so a
# change to the room moves the stations instead of stranding them.
const W := HubAnchors.W
const D := HubAnchors.D
const H := HubAnchors.H

var player: Player
var _portal: HubPortal
var _finale_portal: HubPortal
var _abandon: AbandonConsole
var _shop: SimpleStation
var _terminal: SimpleStation
## S14: where things go. Logic asks by name; `HubAnchors`
## decides where, from the procedural defaults or from an
## authored scene's markers.
var _anchors := HubAnchors.new()
var _board: Label3D
var _sub_board: Label3D
var _static_root: Node3D
var _static_count := -1
var _fuzz: ColorRect
## The campaign board: all 30 Checks, one cell each, laid out by tier.
var _board_cells: Array[MeshInstance3D] = []
var _board_legend: Label3D
var _board_pulse := 0.0
var _working_line := 0
## The Echo Lab annexe. Built with the room; never a Zone, never a Check.
var lab: EchoLab

# --- Epsilon between Zones -------------------------------------------------
#
# Epsilon designed every Zone the player has been through and then had to
# wait here while they played them, which is most of its personality. It
# was silent in the Hub until now: `EpsilonVoice` only ever fired from
# inside a Zone, so the one room where the player stands still and reads
# was the one room the designer never spoke in.
#
# Everything below reacts to campaign state the boards ALREADY display, so
# a bark cannot tell the player anything Archipelago has not confirmed —
# the same rule the in-Zone lines follow. Nothing here reads, reports,
# invents or reorders a location, an item, a coin or an Echo.

#: Set by main when the Hub is built, so the barks land in the HUD's own
#: voice line rather than in a second overlapping label.
var hud: Hud = null

var _voice_idle := 0.0
var _voice_greeted := false
#: Snapshot values from the previous refresh, so a bark fires on the EDGE
#: of a change rather than every frame the condition is true.
var _seen_completed := -1
var _seen_keys := -1
var _seen_finale := false
## D3: the two once-per-campaign beats. Edges, not levels -- `goal_sent`
## and ALL_CHECKS_CLEARED both stay true forever once reached, so a level
## test would say them on every snapshot until the player left.
var _seen_goal_sent := false
var _seen_complete := false

func _ready() -> void:
	_build_room()
	player = Player.create()
	add_child(player)
	# Face +Z: the portal and boards are on the far wall.
	player.set_spawn(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.8, 3.0)))
	refresh()

func _process(delta: float) -> void:
	if hud == null:
		return
	_voice_idle += delta
	if not _voice_greeted:
		# Not on the first frame: the arrival fade and the zone-complete
		# reveal are both still on screen, and a line under them is a line
		# nobody reads.
		if _voice_idle > 2.5:
			_voice_greeted = true
			_voice_idle = 0.0
			hud.say_line("hub_arrived" if _seen_completed <= 0
					else "hub_zone_done")
		return
	if _voice_idle < EpsilonVoice.HUB_IDLE_INTERVAL:
		return
	_voice_idle = 0.0
	# Coins first: an unspent coin is the one thing in the Hub the player
	# can act on immediately, and the kiosk is easy to walk past.
	if int(BridgeClient.snapshot.get("coins_available", 0)) > 0:
		hud.say_line("hub_coins_idle")
	else:
		hud.say_line("hub_idle")

## Fire the lines that mark a change, on the edge rather than the level.
## Called from `refresh`, which every snapshot already runs.
func _voice_on_change() -> void:
	if hud == null:
		return
	var snapshot := BridgeClient.snapshot
	var completed := int(snapshot.get("completed_zone_count", 0))
	var keys := int(snapshot.get("signal_keys", 0))
	var finale := bool(BridgeClient.hub().get("finale_unlocked", false))
	# First refresh establishes the baseline and says nothing: every value
	# is "new" on arrival, and greeting the player with three barks at once
	# would be worse than silence.
	var first := _seen_completed < 0
	var hub := BridgeClient.hub()
	var goal_sent := bool(hub.get("goal_sent", false))
	var complete := str(hub.get("mode", "")) == "ALL_CHECKS_CLEARED"
	if not first:
		# D3, and in this order: finishing the campaign outranks sending
		# the goal, which outranks everything ambient. On the snapshot
		# where the last Check is also the goal, the player hears the
		# bigger of the two rather than both at once.
		if complete and not _seen_complete:
			hud.say_line("campaign_complete")
		elif goal_sent and not _seen_goal_sent:
			hud.say_line("goal_sent")
		elif keys > _seen_keys:
			hud.say_line("hub_key_landed")
		elif finale and not _seen_finale:
			hud.say_line("hub_finale_ready")
	_seen_goal_sent = goal_sent
	_seen_complete = complete
	_seen_completed = completed
	_seen_keys = keys
	_seen_finale = finale

## The west wall is solid by default; the Lab needs a way through. Built
## as two wall segments with a gap rather than by moving the perimeter,
## so the Hub's own geometry stays exactly as it was.
func _cut_lab_doorway(b, root: Node3D) -> void:
	# The doorway's Z is the `lab_entrance` anchor's, and its metrics are
	# HubAnchors' -- the Lab lines up against the same numbers, so they
	# have one home rather than two that drift.
	var door_z := _anchors.origin("lab_entrance").z
	var door_w := HubAnchors.LAB_DOOR_WIDTH
	var door_h := HubAnchors.LAB_DOOR_HEIGHT
	# No decorative pane in the opening any more. It existed to imply a
	# door on a solid wall; the wall now has a real hole, so the same box
	# would just stand in it.
	#
	# The corridor between the two rooms: floor, ceiling and SIDES. It
	# had no sides, so the Lab was reached down an open-walled slot with
	# the void either hand.
	var link := Node3D.new()
	add_child(link)
	var run := 3.4
	# Butted against the Hub floor, not overlapping it. At `- 1.6` the
	# corridor floor reached x = -10.9 while the room floor reaches -11,
	# so 0.1m of the two top faces were coplanar -- which is the
	# z-fighting shimmer at the doorway.
	var mid_x := -W / 2.0 - run / 2.0
	b._box(link, Vector3(run, 0.5, door_w), Vector3(mid_x, -0.25, door_z),
			ThemeMaterials.floor_mat(THEME))
	b._box(link, Vector3(run, 0.4, door_w),
			Vector3(mid_x, door_h, door_z),
			ThemeMaterials.trim_mat(THEME))
	for side: float in [-1.0, 1.0]:
		b._box(link, Vector3(run, door_h, ChamberBuilders.WALL_THICKNESS),
				Vector3(mid_x, door_h / 2.0,
				door_z + side * (door_w / 2.0)),
				ThemeMaterials.wall_mat(THEME))
	var sign_plate := Label3D.new()
	sign_plate.text = "ECHO LAB"
	sign_plate.font_size = 34
	sign_plate.pixel_size = 0.007
	sign_plate.position = Vector3(-W / 2.0 + 0.4, door_h + 0.5, door_z)
	sign_plate.rotation_degrees = Vector3(0, 90, 0)
	sign_plate.modulate = Color(0.6, 1.0, 0.85)
	add_child(sign_plate)

## Where a reader stands. Signs face this, not the wall behind them.
func _player_side() -> Vector3:
	return Vector3(0.0, 0.0, 3.0)

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.ambient_light_energy = 0.4
	environment.environment = env
	add_child(environment)

	var b := ChamberBuilders
	var root := Node3D.new()
	add_child(root)
	b._box(root, Vector3(W, 0.5, D), Vector3(0, -0.25, D / 2.0),
			ThemeMaterials.floor_mat(THEME))
	# The Lab doorway is a real hole in the left wall, cut here rather
	# than drawn over a solid one by `_cut_lab_doorway`.
	# `ceiling = false`: the Hub raises its own, two lines below.
	b._perimeter(root, W, D, H, THEME, false, false, 0.0,
			HubAnchors.LAB_DOOR_Z, HubAnchors.LAB_DOOR_WIDTH,
			HubAnchors.LAB_DOOR_HEIGHT, false)
	b._box(root, Vector3(W, 0.4, D), Vector3(0, H, D / 2.0),
			ThemeMaterials.trim_mat(THEME))
	for at in [Vector3(-W / 4.0, H - 0.4, D / 2.0),
			Vector3(W / 4.0, H - 0.4, D / 2.0)]:
		b._light(root, at, THEME, 16.0)

	# The Echo Lab (S8): a walk-in annexe, not a mode. Cut a doorway in the
	# west wall and put the room beyond it, so entering and leaving are
	# both just walking — which is what makes "base movement can always
	# leave the Lab" structural instead of a rule to remember.
	_cut_lab_doorway(b, root)
	lab = EchoLab.new()
	add_child(lab)

	# The Zone portal, centre of the back wall.
	_portal = HubPortal.new()
	_portal.kind = "main"
	add_child(_portal)
	_portal.position = _anchors.origin("main_portal")
	_portal.activated.connect(_on_portal_activated)

	# The finale portal: smaller, redder, only shown when offered.
	_finale_portal = HubPortal.new()
	_finale_portal.kind = "finale"
	add_child(_finale_portal)
	_finale_portal.position = _anchors.origin("postgame")
	_finale_portal.activated.connect(_on_finale_activated)

	# Status board above the portal.
	_board = Label3D.new()
	_board.position = _anchors.origin("progression_display")
	_board.font_size = 96
	_board.pixel_size = 0.008
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ChamberBuilders.face_label(_board, _player_side() - _board.position)
	add_child(_board)
	_sub_board = Label3D.new()
	# Hangs under the board rather than at a coordinate of its own: an
	# authored scene that moves `progression_display` must not leave the
	# legend behind on the far wall.
	# 1.35 below, not 0.8. The headline is 96pt at 0.008 -- 0.77 world
	# units tall -- and the legend runs up to five 40pt lines, 1.6 more.
	# Half of each is 1.18, so 0.8 of separation had them printing
	# through one another; the screenshot showed four readouts in one
	# smear of letters.
	_sub_board.position = _anchors.origin("progression_display") \
			+ Vector3(0, -1.35, 0)
	_sub_board.font_size = 40
	_sub_board.pixel_size = 0.008
	_sub_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_board.modulate = Color(0.75, 0.8, 0.85)
	ChamberBuilders.face_label(_sub_board,
			_player_side() - _sub_board.position)
	add_child(_sub_board)

	# Shop counter, left wall.
	var shop := SimpleStation.new()
	shop.label_text = "QUESTIONABLE GOODS"
	shop.prompt = "[E] BROWSE SHOP"
	shop.station_color = Color(0.9, 0.7, 0.25)
	add_child(shop)
	shop.position = _anchors.origin("shop")
	shop.rotation.y = _anchors.yaw("shop")
	shop.complete_label = "GOODS EXHAUSTED"
	shop.used.connect(func() -> void: open_shop_requested.emit())
	_shop = shop

	# Echo terminal, right wall.
	var terminal := SimpleStation.new()
	terminal.label_text = "ECHO ARCHIVE"
	terminal.prompt = "[E] OPEN ECHO INVENTORY"
	terminal.station_color = Color(0.4, 0.9, 0.85)
	add_child(terminal)
	terminal.position = _anchors.origin("archive_loadout")
	terminal.rotation.y = _anchors.yaw("archive_loadout")
	terminal.used.connect(func() -> void: open_inventory_requested.emit())
	_terminal = terminal

	# Abandon console, next to the portal; the only exit from GENERATING
	# and ZONE_READY, which have no pause menu to reach.
	_abandon = AbandonConsole.new()
	add_child(_abandon)
	_abandon.position = _anchors.origin("generation_loading")

	_build_campaign_board()
	_build_controls_board()

	_static_root = Node3D.new()
	add_child(_static_root)

	# The corruption crawls: re-render the board every couple of seconds.
	var timer := Timer.new()
	timer.wait_time = 2.2
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)

	# Screen fuzz: the Hub itself degrades as Epsilon Static accumulates.
	# Lives on the Hub node so Zones stay clean.
	var fuzz_layer := CanvasLayer.new()
	fuzz_layer.layer = 3
	add_child(fuzz_layer)
	_fuzz = ColorRect.new()
	_fuzz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fuzz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	float n = fract(sin(dot(floor(FRAGCOORD.xy / 2.0)
			+ vec2(floor(TIME * 24.0) * 13.0, 0.0),
			vec2(12.9898, 78.233))) * 43758.5453);
	float scan = sin(FRAGCOORD.y * 1.7 + TIME * 6.0) * 0.5 + 0.5;
	COLOR = vec4(vec3(n), intensity * (0.05 + 0.05 * scan));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_fuzz.material = material
	fuzz_layer.add_child(_fuzz)

func _on_portal_activated() -> void:
	var hub := BridgeClient.hub()
	match BridgeClient.hub_mode():
		"ZONE_AVAILABLE":
			BridgeClient.send_intent(
					{"type": "request_next_zone", "finale": false})
		"FINALE_ONLY":
			BridgeClient.send_intent(
					{"type": "request_next_zone", "finale": true})
		"ZONE_READY", "ZONE_ACTIVE":
			enter_zone_requested.emit()

func _on_finale_activated() -> void:
	BridgeClient.send_intent({"type": "request_next_zone", "finale": true})

## Applies the latest snapshot to every display in the room.
func refresh() -> void:
	var snapshot := BridgeClient.snapshot
	var hub := BridgeClient.hub()
	var mode := BridgeClient.hub_mode()

	var static_units := int(snapshot.get("static_glitch_units", 0))
	_board.text = _garble(str(hub.get("headline", "")), static_units)
	var lines: Array[String] = []
	var detail := str(hub.get("detail", ""))
	if detail != "":
		lines.append(detail)
	if mode == "GENERATING":
		# A Claude generation can run two minutes. Cycling status keeps it
		# reading as work rather than as a hang.
		_working_line = (_working_line + 1) % _WORKING_LINES.size()
		lines.append("EPSILON: %s" % _WORKING_LINES[_working_line])
	var last := BridgeClient.last_completed_zone
	if not last.is_empty():
		lines.append("LAST TRANSMISSION: %s" % last.get("display_name", "?"))
		var note: Variant = last.get("designer_note")
		if note:
			lines.append("EPSILON: “%s”" % str(note))
	lines.append("CHECKS %d/30   KEYS %d/2   COINS %d" % [
			snapshot.get("checked_location_ids", []).size(),
			int(snapshot.get("signal_keys", 0)),
			int(snapshot.get("coins_available", 0))])
	if hub.get("finale_unlocked", false):
		lines.append("FINALE UNLOCKED")
	elif int(hub.get("finale_progress", 0)) > 0:
		lines.append("FINALE %d/%d + %d/%d KEYS" % [
				int(hub.get("finale_progress", 0)),
				int(hub.get("finale_required", 24)),
				int(hub.get("signal_keys", 0)),
				int(hub.get("signal_keys_required", 2))])
	if not snapshot.get("ap_connected", false):
		lines.append("ARCHIPELAGO OFFLINE")

	# D3: FINISHED BUT STILL ALIVE. Every Archipepsi Check is claimed, so
	# there are no Zones left to build -- but the player is still here,
	# and in an async multiworld the others usually are not done. So the
	# Hub says what has ended and, in the same breath, what has not. No
	# credits, no forced exit, and the alien computer does not switch off
	# because it ran out of campaign.
	if mode == "ALL_CHECKS_CLEARED":
		lines.append("TRANSMISSION COMPLETE")
		if snapshot.get("ap_connected", false):
			lines.append("MULTIWORLD CONNECTION ACTIVE")
		lines.append("LAB AND ARCHIVE REMAIN OPEN")
	_sub_board.text = "\n".join(lines)

	_voice_on_change()
	_portal.refresh(hub, mode)
	# finale_offered stays true in postgame (schema-computed from thresholds
	# that remain met); only offer it while the goal is actually missing.
	var goal_missing := false
	for loc in snapshot.get("missing_location_ids", []):
		if int(loc) == Constants.GOAL_LOCATION_ID:
			goal_missing = true
	_finale_portal.visible = bool(hub.get("finale_offered", false)) \
			and goal_missing and mode == "ZONE_AVAILABLE"
	_finale_portal.refresh(hub, "FINALE_OFFERED")
	# D3: the shop closes when the campaign does. The Archive beside it
	# does NOT -- a finished campaign is still a loadout you can look at.
	if _shop != null:
		_shop.set_complete(mode == "ALL_CHECKS_CLEARED")
	_abandon.refresh(mode, BridgeClient.active_zone())
	_board_pulse = 1.0 - _board_pulse       # slow blink for in-flight cells
	_refresh_campaign_board(snapshot)
	_refresh_static(static_units)
	if _fuzz != null and _fuzz.material is ShaderMaterial:
		(_fuzz.material as ShaderMaterial).set_shader_parameter(
				"intensity", minf(1.0, float(static_units)
					/ float(Constants.STATIC_GLITCH_VISUAL_CAP)))

## The campaign board: 30 cells on the left wall, one per Check, in three
## rows of ten — which is exactly the tier structure, so the board shows
## you why Tier 2 is dark before it shows you anything else. Each cell is
## tinted by the game that will receive that location's item, so the wall
## is a picture of the multiworld you are embedded in.
func _build_campaign_board() -> void:
	var panel_z := D * 0.62
	var wall_x := -W / 2.0 + 0.35
	var b := ChamberBuilders
	var root := Node3D.new()
	root.name = "CampaignBoard"
	add_child(root)
	# Backing plate and frame.
	b._box(root, Vector3(0.12, 2.6, 5.2), Vector3(wall_x, 2.3, panel_z),
			ThemeMaterials.trim_mat(THEME), false)

	var title := Label3D.new()
	title.text = "THE MULTIWORLD"
	title.font_size = 40
	title.pixel_size = 0.005
	title.position = Vector3(wall_x + 0.09, 3.45, panel_z)
	ChamberBuilders.face_label(title, Vector3(0.0, 0.0, panel_z) - title.position)
	title.modulate = Color(0.8, 0.88, 0.95)
	root.add_child(title)

	var cell := 0.36
	var gap := 0.09
	var tier_names := ["START", "TIER 1", "TIER 2"]
	# Tier shape comes from the generated constants, not from literals —
	# the unlock rule below reads the same source.
	for tier in Constants.TIER_COUNT:
		for column in Constants.TIER_SIZE:
			var quad: MeshInstance3D = b._box(root,
					Vector3(0.05, cell, cell),
					Vector3(wall_x + 0.09,
						3.0 - float(tier) * (cell + gap),
						panel_z - 2.0 + float(column) * (cell + gap)),
					null, false)
			# One material per cell, built once and mutated in place: the
			# board refreshes on a timer AND on every snapshot, and 30
			# fresh materials per refresh churned the GPU for nothing.
			var material := StandardMaterial3D.new()
			material.emission_enabled = true
			quad.material_override = material
			_board_cells.append(quad)
		var tier_label := Label3D.new()
		tier_label.text = tier_names[tier] if tier < tier_names.size() \
				else "TIER %d" % tier
		tier_label.font_size = 22
		tier_label.pixel_size = 0.005
		tier_label.position = Vector3(wall_x + 0.09,
				3.0 - float(tier) * (cell + gap), panel_z - 2.55)
		ChamberBuilders.face_label(tier_label,
				Vector3(0.0, 0.0, panel_z) - tier_label.position)
		tier_label.modulate = Color(0.55, 0.6, 0.68)
		root.add_child(tier_label)

	_board_legend = Label3D.new()
	_board_legend.font_size = 22
	_board_legend.pixel_size = 0.005
	_board_legend.position = Vector3(wall_x + 0.09, 1.15, panel_z)
	ChamberBuilders.face_label(_board_legend,
			Vector3(0.0, 0.0, panel_z) - _board_legend.position)
	_board_legend.modulate = Color(0.62, 0.7, 0.76)
	root.add_child(_board_legend)

## A training-room card on the right wall. Every FPS of the era had one,
## and nothing else in the game tells you that LMB is always Static Pulse.
func _build_controls_board() -> void:
	var panel_z := D * 0.62
	var wall_x := W / 2.0 - 0.35
	var b := ChamberBuilders
	var root := Node3D.new()
	root.name = "ControlsBoard"
	add_child(root)
	b._box(root, Vector3(0.12, 2.4, 4.0), Vector3(wall_x, 2.2, panel_z),
			ThemeMaterials.trim_mat(THEME), false)

	var title := Label3D.new()
	title.text = "OPERATING PROCEDURE"
	title.font_size = 34
	title.pixel_size = 0.005
	title.position = Vector3(wall_x - 0.09, 3.15, panel_z)
	ChamberBuilders.face_label(title, Vector3(0.0, 0.0, panel_z) - title.position)
	title.modulate = Color(0.85, 0.8, 0.55)
	root.add_child(title)

	var body := Label3D.new()
	body.text = """WASD / ARROWS  move        SPACE  jump
LMB   Static Pulse — always, never replaced
RMB   equipped Echo
E     interact / claim
Q / MOUSE WHEEL  cycle Echo
TAB   Echo archive            ESC  pause
F3    diagnostics

Every mandatory path is clearable with
Static Pulse and base movement alone."""
	body.font_size = 26
	body.pixel_size = 0.005
	body.position = Vector3(wall_x - 0.09, 2.0, panel_z)
	ChamberBuilders.face_label(body, Vector3(0.0, 0.0, panel_z) - body.position)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.modulate = Color(0.72, 0.78, 0.82)
	root.add_child(body)

#: Shown one at a time while Epsilon is designing, so a long generation
#: reads as work in progress rather than a hang.
const _WORKING_LINES := [
	"reading the item pool…",
	"deciding how mean to be…",
	"placing a room you will walk through exactly once…",
	"considering the brute…",
	"reconsidering the brute…",
	"choosing a colour for the walls…",
	"checking that you can still jump it…",
	"naming the place…",
	"hiding something you will not find…",
	"aligning the corridor with nothing in particular…",
]

func _refresh_campaign_board(snapshot: Dictionary) -> void:
	if _board_cells.is_empty():
		return
	var keys := int(snapshot.get("signal_keys", 0))
	# Hoist the snapshot's lists into sets once, rather than rescanning
	# them thirty times per refresh.
	var stocked := {}
	for item: Dictionary in snapshot.get("shop", {}).get("stock", []):
		stocked[int(item.get("location_id", 0))] = true
	var checked := {}
	for location in snapshot.get("checked_location_ids", []):
		checked[int(location)] = true
	var pending := {}
	for record: Dictionary in snapshot.get("pending_checks", []):
		pending[int(record.get("location_id", 0))] = true
	var games := {}
	for scout: Dictionary in snapshot.get("scouted", []):
		games[int(scout.get("location_id", 0))] = str(
				scout.get("recipient_game", ""))

	var done := 0
	var flight := 0
	var for_sale := 0
	var open := 0
	var locked := 0
	var unlocked_tiers := mini(keys, Constants.TIER_COUNT - 1)

	for index in _board_cells.size():
		var location: int = Constants.FIRST_LOCATION_ID + index
		var game: String = games.get(location, "")
		var tint: Color = ThemeMaterials.color_for_game(game) if game != "" \
				else Color(0.4, 0.42, 0.46)
		var energy := 0.5
		if checked.has(location):
			# Confirmed: bright, saturated — this one really happened.
			energy = 2.0
			done += 1
		elif pending.has(location):
			tint = Color(1.0, 0.85, 0.35)
			energy = 1.2 + 0.7 * _board_pulse
			flight += 1
		elif stocked.has(location):
			# On the shop counter behind you — purchasable, not in flight.
			# The schema keeps these disjoint; so does the board.
			tint = Color(0.55, 0.95, 0.55)
			energy = 0.9 + 0.4 * _board_pulse
			for_sale += 1
		elif index / Constants.TIER_SIZE > unlocked_tiers:
			# Behind a Signal Key you do not have yet.
			tint = tint.darkened(0.82)
			energy = 0.06
			locked += 1
		else:
			tint = tint.darkened(0.45)
			energy = 0.35
			open += 1
		var material: StandardMaterial3D = _board_cells[index].material_override
		material.albedo_color = tint
		material.emission = tint
		material.emission_energy_multiplier = energy

	var legend := "%d sent · %d in flight" % [done, flight]
	if for_sale > 0:
		legend += " · %d for sale" % for_sale
	legend += " · %d waiting · %d key-locked" % [open, locked]
	_board_legend.text = legend

## Epsilon Static slowly eats the status board. Purely cosmetic: the more
## Static the multiworld has delivered, the less legible the Hub becomes.
func _garble(text: String, static_units: int) -> String:
	if static_units < 4 or text.is_empty():
		return text
	var glyphs := "▓▒░#%&@?!"
	var rng := RandomNumberGenerator.new()
	# Reseed every couple of seconds so the corruption crawls.
	rng.seed = hash(text) + int(Time.get_ticks_msec() / 2200.0)
	var chance := minf(0.30, float(static_units) * 0.015)
	var out := ""
	for character in text:
		if character != " " and rng.randf() < chance:
			out += glyphs[rng.randi_range(0, glyphs.length() - 1)]
		else:
			out += character
	return out

## Epsilon Static: permanent cosmetic Hub corruption, one unit per Static.
func _refresh_static(count: int) -> void:
	count = mini(count, int(Constants.STATIC_GLITCH_VISUAL_CAP))
	if count == _static_count:
		return
	_static_count = count
	for child in _static_root.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 891
	for i in count:
		var glitch := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var s := rng.randf_range(0.15, 0.5)
		mesh.size = Vector3(s, s, s)
		glitch.mesh = mesh
		glitch.position = Vector3(rng.randf_range(-W / 2.0 + 1, W / 2.0 - 1),
				rng.randf_range(0.3, H - 0.5),
				rng.randf_range(1.0, D - 1.0))
		glitch.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		glitch.material_override = ThemeMaterials.glow_material(
				Color(1.0, 0.0, 0.9) if i % 2 == 0 else Color(0.0, 1.0, 0.75),
				0.9)
		_static_root.add_child(glitch)


class HubPortal extends StaticBody3D:
	signal activated
	var kind := "main"
	var _core: MeshInstance3D
	var _label: Label3D
	var _enabled := false
	var _prompt := ""

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 4.0, 0.8) if kind == "main" \
				else Vector3(2.0, 3.0, 0.8)
		shape.shape = box
		shape.position = Vector3(0, box.size.y / 2.0, 0)
		add_child(shape)
		var frame := MeshInstance3D.new()
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = box.size + Vector3(0.4, 0.4, -0.2)
		frame.mesh = frame_mesh
		frame.position = Vector3(0, box.size.y / 2.0, 0)
		frame.material_override = ThemeMaterials.trim_mat(HubController.THEME)
		add_child(frame)
		_core = MeshInstance3D.new()
		var core_mesh := BoxMesh.new()
		core_mesh.size = box.size - Vector3(0.4, 0.4, 0.5)
		_core.mesh = core_mesh
		_core.position = Vector3(0, box.size.y / 2.0, 0.2)
		add_child(_core)
		_label = Label3D.new()
		_label.position = Vector3(0, box.size.y + 0.5, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 40
		_label.pixel_size = 0.007
		add_child(_label)

	func refresh(hub: Dictionary, mode: String) -> void:
		if kind == "finale":
			_enabled = bool(hub.get("finale_offered", false))
			_prompt = "[E] GENERATE THE FINALE"
			_label.text = "FINALE"
			_core.material_override = ThemeMaterials.glow_material(
					Color(1.0, 0.25, 0.2), 1.8 if _enabled else 0.3)
			return
		_enabled = bool(hub.get("portal_enabled", false))
		match mode:
			"ZONE_AVAILABLE":
				_prompt = "[E] GENERATE NEXT ZONE"
				_label.text = "PORTAL"
			"FINALE_ONLY":
				_prompt = "[E] GENERATE THE FINALE"
				_label.text = "FINALE"
			"ZONE_READY":
				_prompt = "[E] ENTER ZONE"
				_label.text = "ZONE READY"
			"ZONE_ACTIVE":
				_prompt = "[E] RESUME ZONE"
				_label.text = "ZONE IN PROGRESS"
			"GENERATING":
				_prompt = "EPSILON IS DESIGNING…"
				_label.text = "GENERATING"
			_:
				_prompt = ""
				_label.text = "PORTAL"
		if not _enabled and mode in ["ZONE_AVAILABLE", "FINALE_ONLY"]:
			# The portal is present but unusable: say why, don't show an [E].
			_prompt = "ARCHIPELAGO OFFLINE — RECONNECT TO GENERATE"
		var color := Color(0.4, 0.9, 1.0) if _enabled else Color(0.25, 0.25, 0.3)
		if mode == "GENERATING":
			color = Color(0.9, 0.5, 1.0)
		_core.material_override = ThemeMaterials.glow_material(
				color, 1.8 if _enabled else 0.5)

	func interact_prompt() -> String:
		return _prompt

	func interact(_player: Node) -> void:
		if _enabled:
			activated.emit()


class SimpleStation extends StaticBody3D:
	signal used
	var label_text := ""
	var prompt := ""
	var station_color := Color.WHITE

	## D3: a station that has nothing left to do. The shop reaches this
	## when every Check is claimed -- there is no stock because there are
	## no unclaimed locations to stock it from. It reads as FINISHED
	## rather than broken: dimmed, relabelled, and it declines to open
	## instead of showing an empty list.
	##
	## The Archive and the Echo Lab never take this state. They stay
	## usable in the postgame on purpose.
	var complete := false
	var complete_label := ""
	var _sign: MeshInstance3D
	var _label: Label3D

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 1.4, 1.0)
		shape.shape = box
		shape.position = Vector3(0, 0.7, 0)
		add_child(shape)
		var counter := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 1.1, 0.9)
		counter.mesh = mesh
		counter.position = Vector3(0, 0.55, 0)
		counter.material_override = ThemeMaterials.accent_mat(
				HubController.THEME)
		add_child(counter)
		var placard := MeshInstance3D.new()
		var sign_mesh := BoxMesh.new()
		sign_mesh.size = Vector3(2.2, 0.5, 0.1)
		placard.mesh = sign_mesh
		placard.position = Vector3(0, 2.2, 0)
		placard.material_override = ThemeMaterials.glow_material(
				station_color, 1.2)
		add_child(placard)
		_sign = placard
		var label := Label3D.new()
		label.text = label_text
		label.position = Vector3(0, 2.2, 0.1)
		label.font_size = 36
		label.pixel_size = 0.006
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Local PI, not a world facing: the placard hangs off a station
		# that is itself rotated, and only the TEXT is on the wrong side.
		label.rotation.y = PI
		add_child(label)
		_label = label
		_apply_complete()

	func set_complete(on: bool) -> void:
		if complete == on:
			return
		complete = on
		_apply_complete()

	func _apply_complete() -> void:
		if _sign == null or _label == null:
			return
		_label.text = complete_label if complete and complete_label != "" \
				else label_text
		# Dimmed, not dark: the facility is finished, not switched off.
		_sign.material_override = ThemeMaterials.glow_material(
				station_color.darkened(0.5) if complete else station_color,
				0.35 if complete else 1.2)

	func interact_prompt() -> String:
		return "" if complete else prompt

	func interact(_player: Node) -> void:
		if complete:
			return
		used.emit()


class AbandonConsole extends StaticBody3D:
	var _visible_modes := ["GENERATING", "ZONE_READY", "ZONE_ACTIVE"]
	var _zone_id := ""
	var _armed := false
	var _label: Label3D

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.3, 1.0)
		shape.shape = box
		shape.position = Vector3(0, 0.65, 0)
		add_child(shape)
		var console := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(1.0, 1.2, 0.8)
		console.mesh = mesh
		console.position = Vector3(0, 0.6, 0)
		console.material_override = ThemeMaterials.glow_material(
				Color(0.8, 0.2, 0.15), 0.8)
		add_child(console)
		_label = Label3D.new()
		_label.position = Vector3(0, 1.7, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 30
		_label.pixel_size = 0.006
		add_child(_label)

	func refresh(mode: String, active_zone: Dictionary) -> void:
		visible = mode in _visible_modes
		_zone_id = str(active_zone.get("zone_id", ""))
		if not visible:
			_armed = false
		_label.text = "ABANDON ZONE" if not _armed \
				else "CONFIRM ABANDON?\nUnclaimed Checks return to the pool"

	func interact_prompt() -> String:
		return "[E] CONFIRM ABANDON — unclaimed Checks return to the pool" \
				if _armed else "[E] ABANDON HELD ZONE"

	func interact(_player: Node) -> void:
		if _zone_id == "":
			return
		if not _armed:
			_armed = true
			_label.text = "CONFIRM ABANDON?"
			return
		_armed = false
		BridgeClient.send_intent(
				{"type": "abandon_zone", "zone_id": _zone_id})
