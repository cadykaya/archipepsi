class_name EffectSummary
extends RefCounted
## The shared Echo effect formatter: the reveal card and the inventory must
## describe an Echo identically (DESIGN §16).

static func lines(echo: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if echo.is_empty():
		return out
	if echo.get("activation") == "primary":
		out.append_array(_initiator_lines(echo.get("initiator", {})))
		for modifier: Dictionary in echo.get("modifiers", []):
			out.append(_modifier_line(modifier))
		out.append("%.1fs cooldown" % float(echo.get("cooldown", 0.0)))
	else:
		for effect: Dictionary in echo.get("effects", []):
			out.append(_passive_line(effect))
		out.append("Passive — active while equipped")
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

static func _passive_line(effect: Dictionary) -> String:
	match effect.get("type", ""):
		"modify_gravity":
			return "%.0f%% gravity" % (float(effect.get("multiplier", 1)) * 100)
		"modify_speed":
			return "%.0f%% move speed" % (float(effect.get("multiplier", 1)) * 100)
	return ""
