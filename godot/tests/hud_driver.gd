extends Node
## The S3 HUD suite (`make godot-hud`): the §7.1 safe palette, the §12
## source identity package (glyph, sound family, particle style), the §7
## pressure valve, and the §15.4 / ECHOES §11 archive provenance chains.
##
## Boots the real project (`--hud-test`) because ResourceMeters,
## ResourcePool and InventoryLayer all read the BridgeClient autoload and a
## `--script` run never instantiates it. Needs no bridge: the snapshot is a
## fixture injected directly — derived from a REAL fold on the Python side
## (create Magic Meter ← Ocarina of Time; create Vigor ← Dark Souls;
## upgrade Magic Meter +40 max ← Estus Shard, Dark Souls) and JSON-parsed
## here, so every number is a float exactly as production sees them. The
## upgrade gives Magic Meter a two-entry provenance chain and Mk II: legal
## fold data today, producible by providers only when dispositions land, so
## the renderers are proven ahead of the content.
##
## The meters and pool are driven OFF the scene tree, `_process` called by
## hand with a fixed 1/60 step: the valve's whole contract is about time,
## and a wall-clock frame rate would make every threshold flaky.

const FIXTURE := """{"type":"campaign_snapshot","interpretations":[{"schema_version":8,"echo_id":"echo_89100003","interpretation_seq":0,"source_location_id":89100003,"source_item_name":"Magic Upgrade","source_game":"Ocarina of Time","source_recipient_name":"oot_player","concepts":["magic","green","capacity"],"mode":"literal","display_name":"Magic Meter","description":"It does a thing.","tags":[],"operations":[{"op":"create","component":{"component_id":"res_magic","display_name":"Magic Meter","description":"Green means magic.","kind":"resource","max_value":100.0,"initial_fraction":1.0,"regen_per_second":4.0,"regen_delay":1.0,"presentation":"bar","pip_count":null,"palette_color":"moss"}}]},{"schema_version":8,"echo_id":"echo_89100011","interpretation_seq":1,"source_location_id":89100011,"source_item_name":"Green Blossom","source_game":"Dark Souls","source_recipient_name":"ds_player","concepts":["stamina","herb"],"mode":"literal","display_name":"Vigor","description":"It does a thing.","tags":[],"operations":[{"op":"create","component":{"component_id":"res_vigor","display_name":"Vigor","description":"Legs.","kind":"resource","max_value":5.0,"initial_fraction":1.0,"regen_per_second":0.0,"regen_delay":0.0,"presentation":"pips","pip_count":5,"palette_color":"sulphur"}}]},{"schema_version":8,"echo_id":"echo_89100007","interpretation_seq":2,"source_location_id":89100007,"source_item_name":"Estus Shard","source_game":"Dark Souls","source_recipient_name":"ds_player","concepts":["capacity","shard"],"mode":"mechanical","display_name":"Deeper Reserves","description":"It does a thing.","tags":[],"operations":[{"op":"upgrade","target":"res_magic","field":"max_value","delta":40.0}]}],"mechanics":{"owned":[{"component":{"component_id":"res_magic","display_name":"Magic Meter","description":"Green means magic.","kind":"resource","max_value":140.0,"initial_fraction":1.0,"regen_per_second":4.0,"regen_delay":1.0,"presentation":"bar","pip_count":null,"palette_color":"moss"},"mk":2,"provenance":[{"interpretation_seq":0,"source_location_id":89100003,"source_item_name":"Magic Upgrade","source_game":"Ocarina of Time","source_recipient_name":"oot_player","operation":"create","note":"Magic Meter"},{"interpretation_seq":2,"source_location_id":89100007,"source_item_name":"Estus Shard","source_game":"Dark Souls","source_recipient_name":"ds_player","operation":"upgrade","note":"+40 max_value"}]},{"component":{"component_id":"res_vigor","display_name":"Vigor","description":"Legs.","kind":"resource","max_value":5.0,"initial_fraction":1.0,"regen_per_second":0.0,"regen_delay":0.0,"presentation":"pips","pip_count":5,"palette_color":"sulphur"},"mk":1,"provenance":[{"interpretation_seq":1,"source_location_id":89100011,"source_item_name":"Green Blossom","source_game":"Dark Souls","source_recipient_name":"ds_player","operation":"create","note":"Vigor"}]}],"aliases":[],"links":[],"channel_order":["res_magic","res_vigor"]},"slots":{"echo_a":null,"echo_b":null,"mobility":null,"utility":null}}"""

#: Pinned from BOTH sides, like the theme rule: the same table lives in
#: `bridge/tests/test_hud_contract.py` as sha256 indices. A glyph that
#: silently changed under the player would break the one thing it is for.
const PINNED_GLYPHS := {
	"Ocarina of Time": "□",
	"Dark Souls": "■",
	"Borderlands 2": "✚",
	"Archipepsi": "○",
	"Hollow Knight": "▲",
	"Some Game": "★",
}

const DT := 1.0 / 60.0

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	var snapshot: Variant = JSON.parse_string(FIXTURE)
	_check(typeof(snapshot) == TYPE_DICTIONARY, "the fixture parses")
	BridgeClient.snapshot = snapshot

	_palette_distances()
	_glyph_pins()
	_source_identity_package()
	_pressure_valve()
	_archive_provenance()
	_the_loadout_rows()
	await _the_travel_panel()
	_the_navigation_schematic()

	if failures == 0:
		print("GODOT HUD TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT HUD TESTS: %d failures" % failures)
		get_tree().quit(1)

## EVERY SLOT HAS A ROW, AND EVERY ROW HAS A KEYCAP.
##
## `Hud._loadout_text` had no test at all — it was the one slot-facing
## surface with none — and it is exactly the shape that rots quietly: it
## iterates `Constants.SLOT_NAMES` but looked its keycaps up in a private
## table, so adding a fifth slot produced a row reading "? —" that
## nothing would have caught.
func _the_loadout_rows() -> void:
	print("  -- LOADOUT: one row per slot, each with a real keycap")
	var hud := Hud.new()
	add_child(hud)
	var rows := hud._loadout_text("echo_a").split("\n")
	_check(rows.size() == Constants.SLOT_NAMES.size(),
			"a row per slot (%d of %d)"
			% [rows.size(), Constants.SLOT_NAMES.size()])
	for row: String in rows:
		_check(not row.contains("?"),
				"no row is labelled with an unknown keycap: '%s'" % row)
	for slot: String in Constants.SLOT_NAMES:
		# AGAINST THE ONE AUTHORITY, not against the exported default.
		# `SlotKeycaps.of` reads the real binding and falls back to the
		# constant; comparing the row to the constant would pass while
		# the two disagreed, which is the bug being prevented.
		var keycap := SlotKeycaps.of(slot)
		var seen := false
		for row: String in rows:
			if row.contains(keycap):
				seen = true
		_check(seen, "'%s' shows its key, %s" % [slot, keycap])
	_check(hud._loadout_text("mobility").contains("▸"),
			"the highlighted slot is marked")

	# AND THE LABEL FOLLOWS A REBIND. S21 lets the player move a slot to
	# another key; a fixed table would keep saying the old one, which is
	# worse than no label because it is confidently wrong.
	var action: String = Player.SLOT_ACTIONS["utility"]
	var before := SlotKeycaps.of("utility")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_F9
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, rebound)
	var after := SlotKeycaps.of("utility")
	_check(after != before and after.contains("F9"),
			"rebinding the utility slot moves its label (%s -> %s)"
			% [before, after])
	_check(hud._loadout_text("echo_a").contains(after),
			"…and the HUD row shows the new key, not the old default")
	InputMap.action_erase_events(action)
	_check(SlotKeycaps.of("utility")
			== str(Constants.SLOT_KEYCAPS["utility"]),
			"…and with no binding at all it falls back to the exported "
			+ "default rather than to nothing")
	hud.queue_free()


# --- the station travel panel ---------------------------------------------

## PRESSING E OPENS A CHOICE, AND CHOOSING IS WHAT MOVES YOU.
##
## The owner's note after the playtest: warp stations "should really have
## a menu popup instead of just warping me instantly". Pressing a reached
## station used to teleport you to whichever reached station came next in
## build order, so travel was a cycle you learned by riding it.
##
## What this holds, in the order the panel can break it: opening moves
## nobody, cancel moves nobody, a choice moves you ONCE, an unreached
## station is never on the list, and nothing on it edits a loadout.
func _button_texts(panel: StationPanel) -> Array[String]:
	var out: Array[String] = []
	for node in panel.find_children("*", "Button", true, false):
		out.append((node as Button).text)
	return out

func _the_travel_panel() -> void:
	var panel := StationPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var moved: Array[String] = []
	var home: Array[String] = []
	panel.warp_chosen.connect(
			func(f: String, t: String) -> void: moved.append(f + "->" + t))
	panel.return_to_hub_chosen.connect(
			func() -> void: home.append("hub"))

	# Two reached and one that is not. `travel_options` is the
	# controller's rule; the panel renders what it is handed, so the
	# unreached one is simply absent from what is handed over.
	var options: Array = [
		{"id": "st:entrance", "label": "ENTRANCE", "here": true},
		{"id": "st:hall", "label": "HALL", "here": false},
	]
	panel.open("st:entrance", "ENTRANCE", options)
	_check(panel.visible, "the panel did not open")
	_check(moved.is_empty(),
			"opening the panel moved the player: %s" % str(moved))
	var texts := _button_texts(panel)
	var joined := " | ".join(texts)
	_check(joined.contains("HALL"),
			"the reached station elsewhere is not offered: %s" % joined)
	_check(not joined.contains("EXIT") and not joined.contains("st:"),
			"a station that was never reached is on the list, or a raw "
			+ "id is: %s" % joined)
	_check(joined.contains("you are here"),
			"the station being stood at is missing from its own panel: "
			+ "%s" % joined)
	# AND IT NEVER OFFERS A LOADOUT. The in-Zone loadout station is
	# deferred and pinned; travel-and-save must not reopen it by the
	# back door of a menu.
	for banned: String in ["LOADOUT", "EQUIP", "SLOT", "ECHO"]:
		_check(not joined.to_upper().contains(banned),
				"the travel panel offers '%s', which is loadout editing "
				% banned + "and is deferred: %s" % joined)

	# CANCEL MOVES NOBODY.
	panel.close()
	_check(not panel.visible, "the panel stayed open after close")
	_check(moved.is_empty() and home.is_empty(),
			"closing the panel travelled: %s %s" % [str(moved), str(home)])

	# A CHOICE MOVES YOU ONCE, however many times it is pressed.
	panel.open("st:entrance", "ENTRANCE", options)
	panel._choose("st:hall")
	panel._choose("st:hall")
	panel._choose("st:exit")
	_check(moved.size() == 1 and moved[0] == "st:entrance->st:hall",
			"a destination chosen once produced %s" % str(moved))
	_check(not panel.visible, "the panel stayed open after a choice")

	# AND THE STATION YOU ARE STANDING AT IS NOT TRAVEL.
	moved.clear()
	panel.open("st:entrance", "ENTRANCE", options)
	panel._choose("st:entrance")
	_check(moved.is_empty(),
			"warping to the station you are standing at is travel: %s"
			% str(moved))

	# RETURN TO HUB IS ONE EVENT, and it is the pause menu's own
	# handler: `leave_zone` after the resume anchor is remembered, never
	# `abandon_zone`.
	panel.open("st:entrance", "ENTRANCE", options)
	panel._go_home()
	panel._go_home()
	_check(home.size() == 1,
			"Return to Hub fired %d times for one press" % home.size())
	panel.queue_free()
	await get_tree().process_frame

# --- the navigation-schematic prototype -----------------------------------

## "I'M LOST. I REALIZE WE HAVE MADE A 3D METROIDVANIA WITH NO MAP."
##
## The owner is right and the answer is a design decision they have not
## made. `NavSchematic` is the smallest thing that can be LOOKED AT
## instead: review-only, on the F3/F4 debug route, and nothing in the
## game reads it.
##
## The picture is for the owner to judge. What is asserted here is the
## one rule that makes it safe to look at at all -- it can only ever
## show a room the player has walked, and only ever a link between two
## of them. A prototype that leaked the shape of an unfound route would
## be the map question answered badly rather than left open.
func _the_navigation_schematic() -> void:
	var bounds := {
		"c001": AABB(Vector3(0, 0, 0), Vector3(10, 4, 10)),
		"c002": AABB(Vector3(20, 0, 0), Vector3(10, 4, 10)),
		"c003": AABB(Vector3(40, 0, 0), Vector3(10, 4, 10)),
	}
	var edges: Array = [
		{"edge_id": "e1", "room_a": "c001", "room_b": "c002",
			"realization": "JOINED"},
		{"edge_id": "e2", "room_a": "c002", "room_b": "c003",
			"realization": "JOINED"},
		{"edge_id": "e3", "room_a": "c001", "room_b": "c003",
			"realization": "DOOR_ONLY"},
	]
	var walked := NavSchematic.visible_rooms({"c001": true, "c002": true},
			bounds)
	var want: Array[String] = ["c001", "c002"]
	_check(walked == want,
			"the schematic shows %s, and c003 has not been walked"
			% str(walked))
	var links := NavSchematic.visible_links(edges, walked)
	_check(links.size() == 1 and (links[0] as Array) == ["c001", "c002"],
			"the schematic drew %s: a link with an unwalked end is the "
			% str(links) + "shape of a route the player has not found")
	# A ROOM THE LAYOUT CANNOT PLACE IS NOT ON IT EITHER, so a stale id
	# cannot put a dot at the origin.
	var stale := NavSchematic.visible_rooms(
			{"c001": true, "c099": true}, bounds)
	var only: Array[String] = ["c001"]
	_check(stale == only,
			"a room with no bounds was placed anyway: %s" % str(stale))
	# AND NOTHING WALKED IS NOTHING SHOWN, which is what a reload gives
	# it: the entered set is session-only by construction.
	_check(NavSchematic.visible_rooms({}, bounds).is_empty(),
			"an empty session drew rooms")

# --- §7.1: the safe palette, held to numbers ------------------------------

func _rgb_distance(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2))

## The first run of this check found the claim FALSE: `signal` sat 0.11
## from the cooldown-ready confirmation cyan, and `ember` 0.20 from danger
## amber. The palette moved; the floors keep it moved.
func _palette_distances() -> void:
	for hue_name: String in ResourcePalette.HUES:
		var pair: Dictionary = ResourcePalette.HUES[hue_name]
		for reserved_name: String in ResourcePalette.RESERVED:
			var reserved: Color = ResourcePalette.RESERVED[reserved_name]
			for role: String in ["fill", "dim"]:
				var d := _rgb_distance(pair[role], reserved)
				_check(d >= ResourcePalette.MIN_RESERVED_DISTANCE,
						"%s.%s is %.3f from reserved %s, under the %.2f floor"
						% [hue_name, role, d, reserved_name,
						ResourcePalette.MIN_RESERVED_DISTANCE])
	var names: Array = ResourcePalette.HUES.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var d := _rgb_distance(ResourcePalette.HUES[names[i]]["fill"],
					ResourcePalette.HUES[names[j]]["fill"])
			_check(d >= ResourcePalette.MIN_MUTUAL_DISTANCE,
					"fills %s and %s are %.3f apart, under the %.2f floor"
					% [names[i], names[j], d,
					ResourcePalette.MIN_MUTUAL_DISTANCE])

# --- §12: the source glyph rule -------------------------------------------

func _glyph_pins() -> void:
	for game: String in PINNED_GLYPHS:
		_check(ResourcePalette.source_glyph(game) == PINNED_GLYPHS[game],
				"%s glyphs as %s, pinned %s — the sha256 rule moved; update "
				% [game, ResourcePalette.source_glyph(game),
				PINNED_GLYPHS[game]]
				+ "test_hud_contract.py and this table together")
	_check(ResourcePalette.source_glyph("") == "·",
			"an unknown source shows the neutral dot")

# --- §7: the pressure valve -----------------------------------------------

func _drive(meters: ResourceMeters, frames: int) -> void:
	for i in frames:
		meters._process(DT)

func _height(meters: ResourceMeters, index: int) -> float:
	return float(meters._rows[index]["height"])

func _pressure_valve() -> void:
	var pool := ResourcePool.new()
	pool.reset_for_zone()
	var meters := ResourceMeters.new()
	meters.pool = pool
	meters._ready()

	# Channel assignment is the fold's order, nothing else.
	_drive(meters, 1)
	_check(str(meters._rows[0]["id"]) == "res_magic",
			"channel 0 is the fold's first resource")
	_check(str(meters._rows[1]["id"]) == "res_vigor",
			"channel 1 is the fold's second resource")
	_check(not meters._rows[2]["row"].visible, "channel 2 has no owner")

	# A channel that just appeared is relevant by definition; a full one
	# that nobody touches then collapses to the idle strip. 2.5 s of
	# relevance + 12 frames of shrink, with margin.
	_check(_height(meters, 0) > meters._IDLE_HEIGHT,
			"a new channel starts expanded")
	_drive(meters, 200)
	_check(is_equal_approx(_height(meters, 0), meters._IDLE_HEIGHT),
			"a full, untouched channel collapses to the idle strip")
	_check(not meters._rows[0]["name"].visible,
			"an idle strip hides its name")
	_check(not meters._rows[0]["glyph"].visible,
			"an idle strip hides its glyph")

	# Spending expands the channel: changed recently AND not full.
	pool.spend("res_magic", 30.0)
	_drive(meters, 20)
	_check(is_equal_approx(_height(meters, 0), meters._FULL_HEIGHT),
			"a spent channel expands to full size")
	_check(meters._rows[0]["name"].visible, "an expanded row shows its name")
	_check(is_equal_approx(_height(meters, 1), meters._IDLE_HEIGHT),
			"the untouched neighbour stays an idle strip")

	# Refilled to full it stays open while the change is recent, then the
	# valve closes again.
	pool.refill("res_magic", 30.0)
	_drive(meters, 60)
	_check(is_equal_approx(_height(meters, 0), meters._FULL_HEIGHT),
			"a fresh change holds the channel open even at full")
	_drive(meters, 200)
	_check(is_equal_approx(_height(meters, 0), meters._IDLE_HEIGHT),
			"full and quiet again, the channel collapses again")

	# The THIRD leg, live since S5: a FULL, quiet channel stays expanded
	# while a slotted Action is powered by it. This is the case
	# test_stage_tripwires.py held open until links landed.
	BridgeClient.snapshot = {
		"mechanics": {
			"owned": BridgeClient.mechanics().get("owned", []),
			"aliases": [], "links": [{"link": "powers",
					"source": "res_magic", "target": "act_wand",
					"strength": 5.0}],
			"channel_order": BridgeClient.resource_channels()},
		# The archive scenario runs after this one and reads them.
		"interpretations": BridgeClient.snapshot.get("interpretations", []),
		"slots": {"echo_a": "act_wand", "echo_b": null,
				"mobility": null, "utility": null},
	}
	_drive(meters, 400)
	_check(is_equal_approx(_height(meters, 0), meters._FULL_HEIGHT),
			"a full, quiet channel stays open while it powers a slotted "
			+ "action")
	_check(is_equal_approx(_height(meters, 1), meters._IDLE_HEIGHT),
			"...and an unpowering neighbour still collapses")

	# A channel that is NOT full stays expanded long after the change
	# stopped being recent — that is the second leg of §7's relevance rule.
	pool.spend("res_vigor", 2.0)
	_drive(meters, 400)
	_check(is_equal_approx(_height(meters, 1), meters._FULL_HEIGHT),
			"a partly-empty channel never collapses")
	_check(str(meters._rows[1]["value"].text) == "3/5",
			"pips count what is lit, got %s" % meters._rows[1]["value"].text)
	_check(meters._rows[1]["pips"].get_child_count() >= 5,
			"the pips row was built")

	# §7.1: the fill is the resource's own semantic colour; the glyph is
	# the world that CREATED it — and stays Ocarina's after Dark Souls
	# upgraded it.
	_check(meters._rows[0]["fill"].color == ResourcePalette.fill("moss"),
			"the fill wears the declared palette colour")
	_check(str(meters._rows[0]["glyph"].text) == PINNED_GLYPHS["Ocarina of Time"],
			"the glyph is the creating world's, got %s"
			% meters._rows[0]["glyph"].text)
	_check("Mk 2" in str(meters._rows[0]["name"].text),
			"an upgraded channel wears its Mk, got '%s'"
			% meters._rows[0]["name"].text)

	meters.free()
	pool.free()

# --- §15.4 / ECHOES §11: provenance in the archive ------------------------

func _labels_under(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_labels_under(child, out)

func _archive_provenance() -> void:
	var inventory := InventoryLayer.new()
	inventory._ready()
	inventory.rebuild()
	var labels: Array[String] = []
	_labels_under(inventory._list, labels)

	_check(_count_containing(labels, "MAGIC METER  Mk II") == 2,
			"the two-entry chain appears under BOTH the creator's row and "
			+ "the upgrader's")
	_check(_count_containing(labels, "Mk I  Magic Meter ← Magic Upgrade  (Ocarina of Time)") == 2,
			"the chain starts with the creating item")
	_check(_count_containing(labels, "Mk II  +40 max_value ← Estus Shard  (Dark Souls)") == 2,
			"the upgrade names its item, its game and the fold's note")
	_check(_count_containing(labels, "VIGOR  Mk I") == 0,
			"a chain of one stays silent")
	# S10 put the mode on the same row. It was worth nothing before —
	# every interpretation said "literal" because the fallback hardcoded
	# it — and now says how far Epsilon travelled from the item.
	_check(_count_containing(
			labels, "read literal: magic / green / capacity") == 1,
			"the concepts Epsilon read are on the row, with the mode")
	_check(_count_containing(labels, "read mechanical: capacity / shard") == 1,
			"an interpretation that reworked something says so")
	# The shared formatter's upgrade arm first RAN under this suite, and it
	# was a Python `%+g` no GDScript understands. Hold the rendered line.
	_check(_count_containing(labels, "Upgrades res_magic (+40 max_value)") == 1,
			"the effect summary renders an upgrade operation")
	_check(_count_containing(labels, "No Echoes yet") == 0,
			"the archive is not empty")

	inventory.free()

func _count_containing(labels: Array[String], needle: String) -> int:
	var count := 0
	for text in labels:
		if needle in text:
			count += 1
	return count


# --- §12: the whole source identity package -------------------------------

#: Pinned from both sides as INDICES in `test_hud_contract.py`, the same
#: way the glyphs are. Two worlds may land on the same sound family or the
#: same particle style — six buckets each, and nothing in §12 promises
#: uniqueness — so what the suite holds is determinism, plus that the
#: PACKAGE as a whole still tells worlds apart.
const PINNED_IDENTITY := {
	"Ocarina of Time": {"sound": "bright", "particle": "drift"},
	"Dark Souls": {"sound": "bright", "particle": "drift"},
	"Borderlands 2": {"sound": "bright", "particle": "shard"},
	"Hollow Knight": {"sound": "plain", "particle": "drift"},
}

func _source_identity_package() -> void:
	for game: String in PINNED_IDENTITY:
		var expected: Dictionary = PINNED_IDENTITY[game]
		_check(SourceIdentity.sound_family(game) == expected["sound"],
				"%s sounds %s, pinned %s" % [game,
				SourceIdentity.sound_family(game), expected["sound"]])
		_check(SourceIdentity.particle_style(game) == expected["particle"],
				"%s throws %s, pinned %s" % [game,
				SourceIdentity.particle_style(game), expected["particle"]])
	_check(is_equal_approx(SourceIdentity.sound_pitch(""), 1.0),
			"an unattributed sound is the bank's own voice")
	_check(SourceIdentity.particle_style("") == "spark",
			"...and its own particles")

	# Determinism, and that a pitch is always a usable one.
	for game: String in PINNED_IDENTITY:
		_check(SourceIdentity.sound_family(game)
				== SourceIdentity.sound_family(game),
				"%s is stable across calls" % game)
		var pitch := SourceIdentity.sound_pitch(game)
		_check(pitch >= 0.7 and pitch <= 1.7,
				"%s pitches inside the audible band (%f)" % [game, pitch])

	# Ocarina and Dark Souls share a sound family AND a particle style —
	# six buckets each, and §12 promises determinism, not uniqueness. The
	# package still separates them, which is the property worth holding.
	var oot: Dictionary = SourceIdentity.package("Ocarina of Time")
	var souls: Dictionary = SourceIdentity.package("Dark Souls")
	_check(oot != souls, "two worlds sharing a sound still differ overall")
	_check(str(oot["glyph"]) != str(souls["glyph"]),
			"...and it is the glyph that separates them here")
	_check(oot.has("accent") and oot.has("sound_pitch"),
			"the package carries all four §12 fields")
