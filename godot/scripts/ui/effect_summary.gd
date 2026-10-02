class_name EffectSummary
extends RefCounted
## The shared Echo effect formatter: the reveal card and the inventory must
## describe an Echo identically (DESIGN §16).

## Describes one INTERPRETATION: every component it contributed, in order.
## An interpretation may contribute more than one, so this concatenates
## rather than branching on a single activation the way v0.7 did.
static func lines(interpretation: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if interpretation.is_empty():
		return out
	for operation: Dictionary in interpretation.get("operations", []):
		out.append_array(operation_lines(operation))
	return out

static func operation_lines(operation: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match str(operation.get("op", "")):
		"create":
			out.append_array(component_lines(operation.get("component", {})))
		"upgrade":
			# Signed and trimmed by hand: GDScript's `%` has no `g`
			# conversion (this arm first RAN when the HUD suite fed it an
			# upgrade), and the rendering must match the fold's provenance
			# note style — "+40", not "+40.0" — so the archive's two
			# descriptions of one upgrade agree.
			var delta := float(operation.get("delta", 0.0))
			var number := str(int(delta)) if delta == floorf(delta) \
					else str(delta)
			if delta >= 0.0:
				number = "+" + number
			out.append("Upgrades %s (%s %s)" % [
					operation.get("target", "?"), number,
					operation.get("field", "?")])
		"modify":
			out.append("Modifies %s" % operation.get("target", "?"))
		"link":
			out.append("%s → %s (%s)" % [operation.get("source", "?"),
					operation.get("target", "?"),
					operation.get("link", "?")])
		"merge":
			out.append("Folds %s into %s" % [operation.get("absorbed", "?"),
					operation.get("survivor", "?")])
	return out

## Describes one owned component. Used by the archive, where what you want
## to read is what you HAVE rather than which operation produced it.
static func component_lines(component: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match str(component.get("kind", "")):
		"action":
			out.append_array(action_does(component))
			out.append("%.1fs cooldown" % float(component.get("cooldown", 0.0)))
			out.append("Slot: %s" % str(component.get("slot", "?")).replace(
					"_", " ").to_upper())
		"trait":
			out.append(_trait_line(component))
			out.append("Always on — no slot needed")
		"resource":
			out.append("%s, max %.0f" % [component.get("display_name", "?"),
					float(component.get("max_value", 0.0))])
		"rule":
			out.append("On %s" % str(component.get("event", "?")).replace(
					"_", " "))
		"status":
			out.append("Applies %s to %s" % [component.get("status", "?"),
					component.get("target", "?")])
		"affordance":
			out.append("Unlocks %s in generated Zones" % str(
					component.get("tag", "?")).replace("_", " "))
		"info":
			out.append("Readout: %s" % str(
					component.get("readout", "?")).replace("_", " "))
	return out

## WHAT AN ACTION DOES, without its slot or its cooldown: the primitive
## and every modifier. The equipment face's detail puts the cooldown and
## the key in lines of their own, and this is the rest.
static func action_does(component: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append_array(_initiator_lines(component.get("primitive", {})))
	for modifier: Dictionary in component.get("modifiers", []):
		var line := _modifier_line(modifier)
		if line != "":
			out.append(line)
	return out

## ALL TWENTY-EIGHT PRIMITIVES. Six had a line; the other twenty-two
## answered "what does it do" with nothing, so an Arc Lob's detail said
## its cooldown and its key and not that it throws a bomb.
static func _initiator_lines(initiator: Dictionary) -> Array[String]:
	var f := func(key: String) -> float: return float(initiator.get(key, 0))
	match initiator.get("type", ""):
		"melee_swing":
			return ["%.0f damage swing, %.1f m reach, %.0f° arc" % [
					f.call("damage"), f.call("reach"), f.call("arc_degrees")]]
		"melee_thrust":
			return ["%.0f damage thrust, %.1f m reach" % [
					f.call("damage"), f.call("reach")]]
		"slam_ground":
			return ["Slams down: %.0f damage within %.1f m" % [
					f.call("damage"), f.call("radius")]]
		"hitscan_damage":
			var pellets := int(initiator.get("pellets", 1))
			if pellets > 1:
				return ["%d pellets × %.0f damage" % [
						pellets, float(initiator.get("damage", 0))]]
			return ["%.0f damage hitscan" % float(initiator.get("damage", 0))]
		"projectile_damage":
			return ["%.0f damage projectile" % float(
					initiator.get("damage", 0))]
		"arc_lob":
			return ["Thrown: bursts for %.0f damage within %.1f m after %.1f s"
					% [f.call("damage"), f.call("radius"), f.call("fuse")]]
		"burst_fire":
			return ["%d shots × %.0f damage" % [
					int(initiator.get("shots", 1)), f.call("damage")]]
		"charge_shot":
			return ["Hold to charge (%.1f s): %.0f to %.0f damage" % [
					f.call("charge_time"), f.call("min_damage"),
					f.call("max_damage")]]
		"beam_sustained":
			return ["Beam: %.0f damage a second" % f.call("damage_per_second")]
		"dash":
			return ["Dash burst (%.0f m/s)" % float(initiator.get("force", 0))]
		"air_dash":
			return ["Dash in the air (%.0f m/s)" % f.call("force")]
		"double_jump":
			var extra := int(initiator.get("extra_jumps", 1))
			return ["%d extra jump%s in the air" % [
					extra, "" if extra == 1 else "s"]]
		"wall_kick":
			return ["Kick off walls (%.0f m/s)" % f.call("force")]
		"hover":
			return ["Hover in the air, up to %.1f s" % f.call("max_duration")]
		"glide":
			return ["Glide: fall at %.1f m/s, %.0f m/s forward" % [
					f.call("fall_speed"), f.call("forward_speed")]]
		"blink":
			return ["Blink up to %.0f m" % f.call("range")]
		"grapple_to_surface":
			return ["Grapple to surfaces within %.0f m" % float(
					initiator.get("range", 0))]
		"grapple_pull_target":
			return ["Pull an enemy to you from up to %.0f m" % f.call("range")]
		"grapple_swing":
			return ["Swing from surfaces within %.0f m" % f.call("range")]
		"heal_self":
			return ["Restores %.0f HP" % float(initiator.get("amount", 0))]
		"shield":
			return ["%.0f shield for %.0fs" % [
					float(initiator.get("amount", 0)),
					float(initiator.get("duration", 0))]]
		"block":
			return ["Block %.0f%% of damage while held" % (
					f.call("reduction") * 100.0)]
		"parry":
			return ["Parry: a %.2f s window" % f.call("window")]
		"cleanse":
			var count := int(initiator.get("count", 1))
			return ["Clears %d status effect%s from you" % [
					count, "" if count == 1 else "s"]]
		"scan_mark":
			return ["Marks enemies within %.0f m for %.0f s" % [
					f.call("range"), f.call("duration")]]
		"restore_resource":
			return ["Restores %.0f of a resource" % f.call("amount")]
		"pull_pickup":
			return ["Pulls pickups within %.0f m to you" % f.call("radius")]
		"place_marker":
			return ["Places a marker where you aim"]
	return []

static func _modifier_line(modifier: Dictionary) -> String:
	match modifier.get("type", ""):
		"recoil_self":
			var force := float(modifier.get("force", 0))
			return "Huge recoil" if force >= 8.0 else "Kicks you backward"
		"knockback_target":
			return "Knocks enemies backward"
		"apply_status_on_hit":
			return "Hits leave %s for %.1f s" % [
					str(modifier.get("status", "?")).replace("_", " "),
					float(modifier.get("duration", 0))]
	return ""

static func _trait_line(component: Dictionary) -> String:
	var multiplier := float(component.get("multiplier", 1.0)) * 100.0
	match str(component.get("stat", "")):
		"gravity":
			return "%.0f%% gravity" % multiplier
		"move_speed":
			return "%.0f%% move speed" % multiplier
	return "%.0f%% %s" % [multiplier,
			str(component.get("stat", "?")).replace("_", " ")]
