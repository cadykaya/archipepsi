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
			out.append("Upgrades %s (%+g %s)" % [
					operation.get("target", "?"),
					float(operation.get("delta", 0.0)),
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
			out.append_array(_initiator_lines(component.get("primitive", {})))
			for modifier: Dictionary in component.get("modifiers", []):
				out.append(_modifier_line(modifier))
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

static func _initiator_lines(initiator: Dictionary) -> Array[String]:
	match initiator.get("type", ""):
		"hitscan_damage":
			var pellets := int(initiator.get("pellets", 1))
			if pellets > 1:
				return ["%d pellets × %.0f damage" % [
						pellets, float(initiator.get("damage", 0))]]
			return ["%.0f damage hitscan" % float(initiator.get("damage", 0))]
		"projectile_damage":
			return ["%.0f damage projectile" % float(
					initiator.get("damage", 0))]
		"dash":
			return ["Dash burst (%.0f m/s)" % float(initiator.get("force", 0))]
		"grapple_to_surface":
			return ["Grapple to surfaces within %.0f m" % float(
					initiator.get("range", 0))]
		"heal_self":
			return ["Restores %.0f HP" % float(initiator.get("amount", 0))]
		"shield":
			return ["%.0f shield for %.0fs" % [
					float(initiator.get("amount", 0)),
					float(initiator.get("duration", 0))]]
	return []

static func _modifier_line(modifier: Dictionary) -> String:
	match modifier.get("type", ""):
		"recoil_self":
			var force := float(modifier.get("force", 0))
			return "Huge recoil" if force >= 8.0 else "Kicks you backward"
		"knockback_target":
			return "Knocks enemies backward"
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
