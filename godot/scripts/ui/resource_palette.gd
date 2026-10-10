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

#: Light/dark pairs, so a fill reads on either ground. Every entry keeps a
#: minimum RGB distance from every RESERVED colour below — enforced by the
#: HUD suite, after the first draft of this palette failed its own claim:
#: `signal` was the cooldown-ready cyan almost exactly, and `ember` sat in
#: danger amber's lap. Signal is a deep teal now, ember a coal-salmon, rust
#: a darker oxide; the names, which are the schema contract, never moved.
const HUES := {
	"moss":    {"fill": Color(0.40, 0.78, 0.44), "dim": Color(0.16, 0.30, 0.18)},
	"signal":  {"fill": Color(0.20, 0.72, 0.68), "dim": Color(0.10, 0.26, 0.24)},
	"ember":   {"fill": Color(0.95, 0.55, 0.50), "dim": Color(0.34, 0.20, 0.18)},
	"violet":  {"fill": Color(0.70, 0.55, 0.95), "dim": Color(0.25, 0.19, 0.36)},
	"bone":    {"fill": Color(0.90, 0.88, 0.80), "dim": Color(0.32, 0.31, 0.28)},
	"rust":    {"fill": Color(0.72, 0.42, 0.26), "dim": Color(0.26, 0.15, 0.09)},
	"tide":    {"fill": Color(0.42, 0.62, 0.92), "dim": Color(0.15, 0.22, 0.34)},
	"sulphur": {"fill": Color(0.88, 0.85, 0.36), "dim": Color(0.32, 0.31, 0.13)},
}

#: Reserved by the HUD for things a resource must never be mistaken for.
#: Grounded in the actual HUD, not invented here: damage is the flash and
#: wedge family, danger the low-warning amber, confirmation the exact
#: cooldown-ready / waypoint cyan (`hud.gd`). Asserted against in
#: `hud_driver.gd`, not merely documented.
const RESERVED := {
	"damage": Color(1.0, 0.25, 0.25),
	"danger": Color(1.0, 0.65, 0.15),
	"confirmation": Color(0.45, 0.95, 0.9),
}

#: The floors the HUD suite holds the table above to. Distances are plain
#: RGB Euclidean — crude as perception but stable as a contract, and the
#: margins are wide enough (worst case 0.31 / 0.29) that the metric's
#: crudeness cannot flip a verdict.
const MIN_RESERVED_DISTANCE := 0.30
const MIN_MUTUAL_DISTANCE := 0.25

static func fill(name: String) -> Color:
	return HUES.get(name, HUES["bone"])["fill"]

static func dim(name: String) -> Color:
	return HUES.get(name, HUES["bone"])["dim"]

## A short mark for the world that contributed this, so one economy built by
## two games shows both. ECHOES.md §12: source identity derives from the
## game name "by the sha256 rule the bridge and client already share" — the
## SAME `prng_seed` rule the campaign board's theme tint uses, not a private
## one. The first draft used a character sum here; that was deterministic
## but a second derivation rule where the packet says there is exactly one.
## Pinned from both sides like the theme rule (`test_hud_contract.py` /
## `hud_driver.gd`).
static func source_glyph(game: String) -> String:
	if game.is_empty():
		return "·"
	const GLYPHS := ["◆", "▲", "■", "●", "★", "◇", "△", "□", "○", "☆",
			"✦", "❖", "⬢", "⬟", "✚", "✜"]
	return GLYPHS[ThemeMaterials._prng_seed_mod(
			"%s|source_glyph" % game, GLYPHS.size())]
