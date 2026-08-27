class_name ResourcePalette
extends RefCounted
## The closed palette a Resource's fill is chosen from (ECHOES.md §7.1).
##
## Named rather than hex in the schema, because the CLIENT owns what each
## name looks like. That is not indirection for its own sake: the palette
## has to stay legible on both grounds and must never collide with the
## HUD's reserved semantics — damage red, danger amber, AP-confirmation
## cyan — and only the client knows what those are.
##
## Semantic colour answers "what is this, in the fiction it came from".
## Source identity — the glyph and accent — answers "which world
## contributed this", and is derived from the game name instead. Conflating
## them is the mistake §7.1 exists to prevent: Ocarina's Magic Meter is
## green because magic meters are green, and stays green when Dark Souls
## later refills it.

#: Light/dark pairs, so a fill reads on either ground. Deliberately none of
#: them a saturated red or amber: those are damage and danger, and a
#: resource that borrowed one would read as a warning every time it dropped.
const HUES := {
	"moss":    {"fill": Color(0.40, 0.78, 0.44), "dim": Color(0.16, 0.30, 0.18)},
	"signal":  {"fill": Color(0.45, 0.85, 0.95), "dim": Color(0.14, 0.30, 0.34)},
	"ember":   {"fill": Color(0.98, 0.62, 0.35), "dim": Color(0.36, 0.22, 0.13)},
	"violet":  {"fill": Color(0.70, 0.55, 0.95), "dim": Color(0.25, 0.19, 0.36)},
	"bone":    {"fill": Color(0.90, 0.88, 0.80), "dim": Color(0.32, 0.31, 0.28)},
	"rust":    {"fill": Color(0.82, 0.47, 0.32), "dim": Color(0.30, 0.17, 0.12)},
	"tide":    {"fill": Color(0.42, 0.62, 0.92), "dim": Color(0.15, 0.22, 0.34)},
	"sulphur": {"fill": Color(0.88, 0.85, 0.36), "dim": Color(0.32, 0.31, 0.13)},
}

#: Reserved by the HUD for things a resource must never be mistaken for.
#: Asserted against in the tests, not merely documented here.
const RESERVED := {
	"damage": Color(1.0, 0.25, 0.25),
	"danger": Color(1.0, 0.65, 0.15),
	"confirmation": Color(0.45, 0.95, 0.9),
}

static func fill(name: String) -> Color:
	return HUES.get(name, HUES["bone"])["fill"]

static func dim(name: String) -> Color:
	return HUES.get(name, HUES["bone"])["dim"]

## A short mark for the world that contributed this, so one economy built by
## two games shows both. Deterministic from the name — the same rule shape
## the campaign board and reward pedestals use, so nothing disagrees about
## who a thing came from.
static func source_glyph(game: String) -> String:
	if game.is_empty():
		return "·"
	const GLYPHS := ["◆", "▲", "■", "●", "★", "◇", "△", "□", "○", "☆",
			"✦", "❖", "⬢", "⬟", "✚", "✜"]
	# A plain character sum rather than `hash()`. GDScript's hash is stable
	# within a build but is not a documented contract across engine
	# versions, and a glyph that silently changed under the player would
	# break the one thing it is for: recognising a world at a glance across
	# a whole campaign. This is inspectable and pinned by a test.
	var total := 0
	for i in game.length():
		total += game.unicode_at(i) * (i + 1)
	return GLYPHS[total % GLYPHS.size()]
