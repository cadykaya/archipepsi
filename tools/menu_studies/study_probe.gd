extends RefCounted
## A kit check, not a study: text at 2x / 3x, a card, an icon, a ribbon,
## on the equipment wall at rest, and the start of a turn. Kept so a kit
## change can be looked at before three studies are re-captured.

var kit: RefCounted
var overlay: RefCounted


func _init(k: RefCounted, o: RefCounted, _content: Dictionary,
		_layout: Dictionary) -> void:
	kit = k
	overlay = o
	kit.call("face", "equipment")
	var f: Node3D = kit.call("face_of", "equipment")
	kit.call("face_title", "equipment")
	kit.call("card", f, Vector2(48, 110), Vector2(420, 220), 0.002,
			Color("#262a31"))
	kit.call("label", f, "BRAIDED LASH  MK II", Vector2(64, 126), 3,
			Color("#e8eef6"))
	kit.call("label", f, "18 damage projectile\nOn a key: RMB (ECHO A). "
			+ "Press it to use.\nCooldown 1.2 s. Range: — → 40 m; ok",
			Vector2(64, 170), 2, Color("#9ba5b6"), 0.003, 380.0)
	kit.call("sprite", f, "blocked", Vector2(560, 150), 4, Color("#39d7c8"))
	kit.call("ribbon", f, [kit.call("at", Vector2(520, 300), 0.003),
		kit.call("at", Vector2(900, 300), 0.003),
		kit.call("at", Vector2(1000, 420), 0.003)], 0.006, Color("#39d7c8"))
	overlay.call("prompts", [["Q", "turn left"], ["E", "turn right"],
		["ESC", "close"]])
	overlay.call("show_pointer", Vector2(900, 500))


func title() -> String:
	return "PROBE -- KIT CHECK"


func timeline() -> Array:
	return [[0.0, func() -> void: pass, "rest"],
		[0.5, func() -> void: kit.call("turn", 1)]]


func duration() -> float:
	return 0.8


func stills() -> Array:
	return [[0.0, "rest"]]
