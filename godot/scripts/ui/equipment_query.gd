class_name EquipmentQuery
extends RefCounted
## WHAT THE EQUIPMENT FACE SHOWS, asked without a Control (H-INVENTORY,
## `04_3D_MENU_MAP_AND_GLYPH.md` §5).
##
## `equipment_face.gd` builds widgets; every answer with a right or wrong
## to it is here, where a driver can ask it directly: which items there
## are, which fit a key, what a search finds, what a comparison says, why
## an equip would be refused, and what state a consumable is in.
##
## **ITEMS, NOT EVENTS.** The Echo archive this replaces listed Echoes --
## the events -- so an upgrade-only Echo was a row of its own, with an
## equip button for the Action it upgraded: one Action, two equippable
## rows. An item here is one entry of `CampaignSnapshot.inventory` (Dess's
## H-UI-DATA projection), joined to its fold entry by component id.
## Upgrades are that item's history, never another item.
##
## **THE AUTHORITY'S ANSWERS, READ RATHER THAN RESTATED.** Which keys an
## item goes on is the view's `compatible_slots`, which Dess's suite
## proves is exactly what `slot_action` accepts; nothing here derives it
## from the component a second time. A consumable's count is the view's
## too, and the face shows the client's own reduced count beside it only
## for uses still in flight.

enum Sort { NEWEST, NAME, SOURCE_GAME }

## What the sort control offers, in `Sort` order.
const SORT_LABELS := ["Newest first", "Name A-Z", "Source game"]

const SLOT_TITLES := {
	"echo_a": "ECHO A",
	"echo_b": "ECHO B",
	"mobility": "MOBILITY",
	"utility": "UTILITY",
	"consumable": "CONSUMABLE",
}

## A word for each kind of thing, for the provisional icon. Glyph's kit
## (H-GLYPH-KIT) replaces the icon; the word says what the icon will mean.
const _FAMILY_OF_PRIMITIVE := {
	"melee_swing": "MELEE", "melee_thrust": "MELEE", "slam_ground": "MELEE",
	"hitscan_damage": "RANGED", "projectile_damage": "RANGED",
	"burst_fire": "RANGED", "charge_shot": "RANGED",
	"beam_sustained": "BEAM", "arc_lob": "THROWN",
	"dash": "MOVE", "air_dash": "MOVE", "double_jump": "MOVE",
	"wall_kick": "MOVE", "hover": "MOVE", "glide": "MOVE", "blink": "MOVE",
	"grapple_to_surface": "GRAPPLE", "grapple_pull_target": "GRAPPLE",
	"grapple_swing": "GRAPPLE",
	"shield": "GUARD", "block": "GUARD", "parry": "GUARD",
	"heal_self": "HEAL", "cleanse": "HEAL",
	"scan_mark": "TOOL", "restore_resource": "TOOL", "pull_pickup": "TOOL",
	"place_marker": "TOOL",
}
const _FAMILY_OF_KIND := {
	"trait": "TRAIT", "resource": "POOL", "rule": "RULE",
	"status": "STATUS", "affordance": "ACCESS", "info": "INFO",
}

## The numbers a comparison reads, in the order it reads them, with what
## to call each one. A field not listed still compares, under its own
## name: a new primitive must not vanish from "differences from equipped".
const FIELD_LABELS := {
	"damage": ["Damage", ""],
	"min_damage": ["Least damage", ""],
	"max_damage": ["Most damage", ""],
	"damage_per_second": ["Damage a second", ""],
	"pellets": ["Pellets", ""],
	"shots": ["Shots", ""],
	"range": ["Range", " m"],
	"reach": ["Reach", " m"],
	"radius": ["Radius", " m"],
	"arc_degrees": ["Arc", "°"],
	"spread_degrees": ["Spread", "°"],
	"speed": ["Speed", " m/s"],
	"lifetime": ["Flight time", " s"],
	"fuse": ["Fuse", " s"],
	"launch_force": ["Throw strength", ""],
	"force": ["Force", ""],
	"pull_force": ["Pull", ""],
	"tether_force": ["Tether", ""],
	"descent_force": ["Slam speed", ""],
	"amount": ["Amount", ""],
	"duration": ["Duration", " s"],
	"max_duration": ["Longest use", " s"],
	"charge_time": ["Charge time", " s"],
	"interval": ["Between shots", " s"],
	"window": ["Window", " s"],
	"reduction": ["Damage blocked", ""],
	"drain_per_second": ["Drain a second", ""],
	"max_target_hp": ["Heaviest pull", " HP"],
	"extra_jumps": ["Extra jumps", ""],
	"uses_per_airtime": ["Uses per jump", ""],
	"count": ["Statuses cleared", ""],
	"gravity_multiplier": ["Gravity while hovering", ""],
	"fall_speed": ["Fall speed", " m/s"],
	"forward_speed": ["Glide speed", " m/s"],
	"outward_fraction": ["Push off", ""],
	"clearance": ["Clearance", " m"],
	"gravity_scale": ["Drop", ""],
	"bounces": ["Bounces", ""],
	"cooldown": ["Cooldown", " s"],
	"charges": ["Uses per supply", ""],
}
const _WHOLE_NUMBERS := ["pellets", "shots", "extra_jumps",
		"uses_per_airtime", "count", "bounces", "charges"]
## The numbers worth naming when only ONE side has them. Across two kinds
## of attack every other field is one-sided -- a hitscan has pellets and
## no flight time -- and listing each ("Pellets: — → 1") buried the lines
## that decide anything. The kind change is its own line.
const KEY_FIELDS := ["damage", "damage_per_second", "range", "reach",
		"radius", "amount", "duration", "cooldown", "charges"]


static func slot_title(slot: String) -> String:
	return str(SLOT_TITLES.get(slot, slot.replace("_", " ").to_upper()))


## Every owned item, joined: the view's entry, plus the fold's component,
## Mk and history, plus the Echoes that touched it (for their concepts and
## for search). In the view's order, which is the fold's.
##
## An item the view names and the fold does not is SKIPPED, with a
## warning, rather than drawn from what the view alone says: the two come
## from one snapshot and cannot disagree, and if they ever do, an item
## with no name, no description and no history is a fabrication.
static func items(snapshot: Dictionary) -> Array:
	var view: Variant = snapshot.get("inventory")
	if typeof(view) != TYPE_DICTIONARY:
		return []
	var owned := {}
	var mechanics: Variant = snapshot.get("mechanics")
	if typeof(mechanics) == TYPE_DICTIONARY:
		for raw: Variant in (mechanics as Dictionary).get("owned", []):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = raw
			owned[str(entry.get("component", {}).get("component_id", ""))] \
					= entry
	var echoes := {}
	for raw: Variant in snapshot.get("interpretations", []):
		if typeof(raw) == TYPE_DICTIONARY:
			echoes[int((raw as Dictionary).get("interpretation_seq", -1))] \
					= raw
	var out: Array = []
	for raw: Variant in (view as Dictionary).get("items", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		var cid := str(item.get("component_id", ""))
		var entry: Dictionary = owned.get(cid, {})
		if entry.is_empty():
			push_warning("inventory names %s and the fold does not" % cid)
			continue
		var provenance: Array = entry.get("provenance", [])
		var touched: Array = []
		var newest := -1
		for link: Variant in provenance:
			var seq := int((link as Dictionary).get("interpretation_seq", -1))
			newest = maxi(newest, seq)
			var echo: Variant = echoes.get(seq)
			if echo != null and not touched.has(echo):
				touched.append(echo)
		var row := item.duplicate()
		row["component"] = entry.get("component", {})
		row["mk"] = int(entry.get("mk", 1))
		row["provenance"] = provenance
		row["echoes"] = touched
		row["newest_seq"] = newest
		out.append(row)
	return out


static func item_by_id(rows: Array, component_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("component_id", "")) == component_id:
			return row
	return {}


static func name_of(row: Dictionary) -> String:
	return str(row.get("component", {}).get("display_name",
			row.get("component_id", "?")))


static func kind_of(row: Dictionary) -> String:
	return str(row.get("component", {}).get("kind", ""))


static func is_slotted(row: Dictionary) -> bool:
	return str(row.get("activation", "")) == "slotted"


static func is_consumable(row: Dictionary) -> bool:
	return row.get("charges_max") != null


## Where it is equipped now, or "". The view sends `null` for "nowhere".
static func equipped_in(row: Dictionary) -> String:
	var slot: Variant = row.get("equipped_in")
	return "" if slot == null else str(slot)


## The one key it goes on, or "" for an always-on item.
static func home_slot(row: Dictionary) -> String:
	var fits: Array = row.get("compatible_slots", [])
	return "" if fits.is_empty() else str(fits[0])


static func family(row: Dictionary) -> String:
	var component: Dictionary = row.get("component", {})
	if kind_of(row) == "action":
		return str(_FAMILY_OF_PRIMITIVE.get(
				str(component.get("primitive", {}).get("type", "")), "ACTION"))
	return str(_FAMILY_OF_KIND.get(kind_of(row), kind_of(row).to_upper()))


## The world that created it: the first link of its history.
static func source_game(row: Dictionary) -> String:
	var provenance: Array = row.get("provenance", [])
	return "" if provenance.is_empty() \
			else str((provenance[0] as Dictionary).get("source_game", ""))


## Does this item answer to what was typed? Every line the face can show
## for it: its name and description, what kind of thing it is, its key,
## every item and game in its history, and the Echoes that touched it
## (their names, sources and the concepts Epsilon read).
static func matches(row: Dictionary, needle: String) -> bool:
	var want := needle.strip_edges().to_lower()
	if want == "":
		return true
	var component: Dictionary = row.get("component", {})
	var hay: Array[String] = [
		str(component.get("display_name", "")),
		str(component.get("description", "")),
		kind_of(row),
		family(row),
	]
	for slot: Variant in row.get("compatible_slots", []):
		hay.append(slot_title(str(slot)))
	for link: Variant in row.get("provenance", []):
		var l: Dictionary = link
		hay.append(str(l.get("source_item_name", "")))
		hay.append(str(l.get("source_game", "")))
		hay.append(str(l.get("source_recipient_name", "")))
		hay.append(str(l.get("note", "")))
	for field: String in hay:
		if field.to_lower().contains(want):
			return true
	for echo: Variant in row.get("echoes", []):
		if ArchiveQuery.matches(echo, needle):
			return true
	return false


## Newest first by the last thing that happened to it, so a fresh upgrade
## brings an old item back to the top along with a new one.
static func sorted_items(rows: Array, mode: int) -> Array:
	var out := rows.duplicate()
	match mode:
		Sort.NAME:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return name_of(a).to_lower() < name_of(b).to_lower())
		Sort.SOURCE_GAME:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ga := source_game(a).to_lower()
				var gb := source_game(b).to_lower()
				if ga != gb:
					return ga < gb
				return name_of(a).to_lower() < name_of(b).to_lower())
		_:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var na := int(a.get("newest_seq", 0))
				var nb := int(b.get("newest_seq", 0))
				if na != nb:
					return na > nb
				return name_of(a).to_lower() < name_of(b).to_lower())
	return out


## The grid, in one pass: what goes on a key and what is simply on.
##
## `total_*` rides with each list because "3 of 19" is the line that tells
## a player their search is hiding things. A count of what survived the
## filter, alone, looks identical to owning three.
##
## A key filter hides the always-on half entirely (asking "what goes on
## SHIFT" and being shown seven things that go nowhere is the interleaving
## the old screen was criticised for) -- and the face says it is hidden,
## with the way back beside it.
static func grid(rows: Array, search: String, mode: int,
		slot_filter: String) -> Dictionary:
	var slotted: Array = []
	var always: Array = []
	var total_slotted := 0
	var total_always := 0
	for row: Dictionary in rows:
		var on_a_key := is_slotted(row)
		if on_a_key:
			total_slotted += 1
		else:
			total_always += 1
		if not matches(row, search):
			continue
		if on_a_key:
			if slot_filter != "" \
					and not (row.get("compatible_slots", []) as Array).has(
						slot_filter):
				continue
			slotted.append(row)
		elif slot_filter == "":
			always.append(row)
	return {
		"slotted": sorted_items(slotted, mode),
		"always_on": sorted_items(always, mode),
		"total_slotted": total_slotted,
		"total_always_on": total_always,
	}


## The view's own record for one key: `{slot, holds, accepts}`.
static func slot_view(snapshot: Dictionary, slot: String) -> Dictionary:
	var view: Variant = snapshot.get("inventory")
	if typeof(view) != TYPE_DICTIONARY:
		return {}
	for raw: Variant in (view as Dictionary).get("slots", []):
		var row: Dictionary = raw
		if str(row.get("slot", "")) == slot:
			return row
	return {}


## WHY THE AUTHORITY WOULD NOT TAKE THIS ITEM ON THIS KEY, or "" when it
## would. Read off the view's `compatible_slots`, the authority's answer,
## so a refusal the player is shown here is one `slot_action` would give.
static func refusal(row: Dictionary, slot: String) -> String:
	var name := name_of(row)
	if not is_slotted(row):
		return "%s is always on while you own it. It takes no key, and " \
				% name + "it is not a switch."
	var fits: Array = row.get("compatible_slots", [])
	if not fits.has(slot):
		if fits.is_empty():
			return "%s has no key it goes on." % name
		var home := str(fits[0])
		return "%s goes on %s (%s), not on %s (%s)." % [name,
				SlotKeycaps.of(home), slot_title(home), SlotKeycaps.of(slot),
				slot_title(slot)]
	if equipped_in(row) == slot:
		return "%s is already on %s." % [name, SlotKeycaps.of(slot)]
	return ""


## THE ONE EQUIP THIS FACE WILL NOT OFFER THOUGH THE AUTHORITY WOULD TAKE
## IT: a consumable with nothing left, put on the key. It would fire
## nothing, and a control that looks live and does nothing is what the
## charge count exists to prevent. The face says why, and that the supply
## is still the player's.
static func held_back(row: Dictionary) -> String:
	if is_consumable(row) and equipped_in(row) == "" \
			and int(row.get("charges_left", 0)) <= 0:
		return "Empty: there is nothing to throw until entering a Zone " \
				+ "refills it. It is still yours."
	return ""


## WHAT IT DOES: the effect lines, without its key or cooldown (those are
## lines of their own in the detail).
static func does(row: Dictionary) -> Array[String]:
	var component: Dictionary = row.get("component", {})
	if kind_of(row) == "action":
		return EffectSummary.action_does(component)
	var out: Array[String] = []
	for line: String in EffectSummary.component_lines(component):
		if not line.begins_with("Always on"):
			out.append(line)
	return out


## HOW IT IS USED: its activation, then every restriction on its target
## or its use.
static func use_lines(row: Dictionary, rows: Array) -> Array[String]:
	var out: Array[String] = []
	var component: Dictionary = row.get("component", {})
	if is_slotted(row):
		var home := home_slot(row)
		out.append("On a key: %s (%s). Press it to use." % [
				SlotKeycaps.of(home), slot_title(home)])
	else:
		out.append("Always on while you own it. Not a switch: there is " \
				+ "nothing to equip or turn off.")
	var primitive: Dictionary = component.get("primitive", {})
	match str(primitive.get("type", "")):
		"grapple_pull_target":
			out.append("Only pulls enemies of %.0f HP or less." % float(
					primitive.get("max_target_hp", 0)))
		"air_dash":
			out.append("%d per time in the air." % int(
					primitive.get("uses_per_airtime", 1)))
		"hitscan_damage", "burst_fire", "beam_sustained", "scan_mark":
			out.append("Reaches %.0f m." % float(primitive.get("range", 0)))
		"blink":
			out.append("Up to %.0f m, to a spot with room to stand." % float(
					primitive.get("range", 0)))
	for modifier: Variant in component.get("modifiers", []):
		if str((modifier as Dictionary).get("type", "")) \
				== "apply_status_on_hit":
			out.append("The status lands on enemies it hits.")
			break
	var needs: Variant = component.get("requires_equipped")
	if needs != null and str(needs) != "":
		var other := item_by_id(rows, str(needs))
		var other_name := name_of(other) if not other.is_empty() \
				else str(needs)
		if not other.is_empty() and equipped_in(other) != "":
			out.append("Only while %s is on a key. It is, on %s." % [
					other_name, SlotKeycaps.of(equipped_in(other))])
		else:
			out.append("Only while %s is on a key. It is not, so this " \
					% other_name + "does nothing right now.")
	match kind_of(row):
		"status":
			out.append("Applies to: %s." % str(component.get("target", "?")))
		"rule":
			for condition: Variant in component.get("conditions", []):
				out.append("Only when: %s." % str((condition as Dictionary)
						.get("type", "?")).replace("_", " "))
	return out


## WHAT IT COSTS: cooldown, supply, drain.
static func cost_lines(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var component: Dictionary = row.get("component", {})
	match kind_of(row):
		"action":
			out.append("Cooldown %s s." % _number(
					float(component.get("cooldown", 0.0))))
			if is_consumable(row):
				out.append("%d uses per supply. Entering a Zone refills it." \
						% int(row.get("charges_max", 0)))
			var drain := float(component.get("primitive", {}).get(
					"drain_per_second", 0.0))
			if drain > 0.0:
				out.append("Drains %s a second while held." % _number(drain))
		"rule":
			out.append("Cooldown %s s." % _number(
					float(component.get("cooldown", 0.0))))
			for cost: Variant in component.get("costs", []):
				var c: Dictionary = cost
				out.append("Costs %s %s." % [
						_number(float(c.get("amount", 0.0))),
						str(c.get("resource_id", "?"))])
		_:
			out.append("No cost: it is simply on.")
	return out


## WHAT CHANGES IF THIS REPLACES WHAT IS ON ITS KEY: now → this.
static func comparison(candidate: Dictionary,
		occupant: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var now: Dictionary = occupant.get("component", {})
	var this: Dictionary = candidate.get("component", {})
	var now_type := str(now.get("primitive", {}).get("type", ""))
	var this_type := str(this.get("primitive", {}).get("type", ""))
	if now_type != this_type:
		# The family when it differs, the primitive when it does not:
		# "RANGED → RANGED" says nothing about projectile against hitscan.
		if family(occupant) != family(candidate):
			out.append("Kind: %s → %s" % [family(occupant),
					family(candidate)])
		else:
			out.append("Kind: %s → %s" % [now_type.replace("_", " "),
					this_type.replace("_", " ")])
	var a := _numbers(now)
	var b := _numbers(this)
	var keys: Array = []
	for key: String in FIELD_LABELS:
		if a.has(key) or b.has(key):
			keys.append(key)
	for key: Variant in a.keys() + b.keys():
		if not keys.has(key):
			keys.append(key)
	for key: Variant in keys:
		var va: Variant = a.get(key)
		var vb: Variant = b.get(key)
		if va != null and vb != null and is_equal_approx(va, vb):
			continue
		if (va == null or vb == null) and not KEY_FIELDS.has(key):
			continue
		out.append("%s: %s → %s" % [_label(str(key)), _shown(str(key), va),
				_shown(str(key), vb)])
	var mods_now := _modifier_lines(now)
	var mods_this := _modifier_lines(this)
	for line: String in mods_this:
		if not mods_now.has(line):
			out.append("Adds: " + line)
	for line: String in mods_now:
		if not mods_this.has(line):
			out.append("Loses: " + line)
	var mk_now := int(occupant.get("mk", 1))
	var mk_this := int(candidate.get("mk", 1))
	if mk_now != mk_this:
		out.append("Mk %d → Mk %d" % [mk_now, mk_this])
	if out.is_empty():
		out.append("They do the same thing.")
	return out


## ECHOES §11: every AP item responsible for this item, in order, never
## rewritten. `mark` counts Mk the way the archive always has: create,
## upgrade and modify each add one; a link or a merge is named instead.
static func history(row: Dictionary) -> Array:
	var out: Array = []
	var mk := 0
	for link: Variant in row.get("provenance", []):
		var l: Dictionary = link
		var op := str(l.get("operation", ""))
		var mark: String
		if op in ["create", "upgrade", "modify"]:
			mk += 1
			mark = "Mk " + mk_roman(mk)
		else:
			mark = "linked" if op == "link" else "merged"
		out.append({
			"mark": mark,
			"operation": op,
			"note": str(l.get("note", "")),
			"item": str(l.get("source_item_name", "?")),
			"game": str(l.get("source_game", "?")),
			"recipient": str(l.get("source_recipient_name", "?")),
			"location": int(l.get("source_location_id", 0)),
		})
	return out


## §15.4: the concepts Epsilon read, one line per Echo that touched it.
static func read_lines(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in row.get("echoes", []):
		var echo: Dictionary = raw
		var concepts: Array = echo.get("concepts", [])
		if concepts.is_empty():
			continue
		var words: PackedStringArray = []
		for concept: Variant in concepts:
			words.append(str(concept))
		out.append("read %s: %s  (%s)" % [str(echo.get("mode", "literal")),
				" / ".join(words), str(echo.get("display_name", "?"))])
	return out


## THE CONSUMABLE KEY'S STATE, one of the five the packet names (04 §5)
## plus the ordinary one:
##
##   none_owned          no consumable in the inventory at all
##   owned_not_equipped  owned, and nothing on the key
##   disconnected        on the key, and no link to authorise a use
##   pending             on the key, a use asked for and not yet answered
##   equipped_empty      on the key at 0 / max
##   ready               on the key with uses left
##
## `left` is the client's count (`BridgeClient.charges_left`: the view's,
## less uses still in flight), the same number the HUD shows. Every state
## that has a supply on the key says its count.
static func consumable_state(rows: Array, holds: Variant, left: int,
		awaiting: int, online: bool) -> Dictionary:
	var owned: Array = []
	for row: Dictionary in rows:
		if is_consumable(row):
			owned.append(row)
	var key := SlotKeycaps.of("consumable")
	if owned.is_empty():
		return {"state": "none_owned", "count": "",
				"text": "No consumable owned yet. One arrives as an Echo, " \
						+ "like any other item."}
	if holds == null or str(holds) == "":
		return {"state": "owned_not_equipped", "count": "",
				"text": "Nothing on %s. You own %d consumable%s: pick one " \
						% [key, owned.size(), "" if owned.size() == 1
						else "s"] + "to carry."}
	var row := item_by_id(rows, str(holds))
	var count := "%d / %d" % [left, int(row.get("charges_max", 0))]
	if not online:
		return {"state": "disconnected", "count": count,
				"text": "OFFLINE: a use needs the bridge's answer, so none " \
						+ "can be made until it is back."}
	if awaiting > 0:
		return {"state": "pending", "count": count,
				"text": "%d use%s waiting for the bridge's answer." % [
						awaiting, "" if awaiting == 1 else "s"]}
	if left <= 0:
		return {"state": "equipped_empty", "count": count,
				"text": "Empty. It stays on %s, and entering a Zone " % key \
						+ "refills it."}
	return {"state": "ready", "count": count, "text": ""}


static func mk_roman(n: int) -> String:
	const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII",
			"IX", "X", "XI", "XII"]
	return NUMERALS[n - 1] if n >= 1 and n <= NUMERALS.size() else str(n)


static func _numbers(component: Dictionary) -> Dictionary:
	var out := {}
	if component.has("cooldown"):
		out["cooldown"] = float(component["cooldown"])
	var charges: Variant = component.get("charges")
	if charges != null:
		out["charges"] = float(charges)
	var primitive: Dictionary = component.get("primitive", {})
	for key: Variant in primitive:
		var value: Variant = primitive[key]
		if str(key) != "type" and (typeof(value) == TYPE_FLOAT
				or typeof(value) == TYPE_INT):
			out[str(key)] = float(value)
	return out


static func _modifier_lines(component: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for modifier: Variant in component.get("modifiers", []):
		var line := EffectSummary._modifier_line(modifier)
		if line != "":
			out.append(line)
	return out


static func _label(key: String) -> String:
	if FIELD_LABELS.has(key):
		return str(FIELD_LABELS[key][0])
	return key.replace("_", " ").capitalize()


static func _shown(key: String, value: Variant) -> String:
	if value == null:
		return "—"
	var unit := str(FIELD_LABELS[key][1]) if FIELD_LABELS.has(key) else ""
	if key in _WHOLE_NUMBERS:
		return "%d%s" % [int(value), unit]
	return _number(float(value)) + unit


## "12", "1.5", "0.25": no trailing zeros, the fold's own note style.
static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	return text
