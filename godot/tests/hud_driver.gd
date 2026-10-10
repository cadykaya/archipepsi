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

	if failures == 0:
		print("GODOT HUD TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT HUD TESTS: %d failures" % failures)
		get_tree().quit(1)

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
