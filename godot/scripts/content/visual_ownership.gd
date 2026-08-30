class_name VisualOwnership
extends RefCounted
## Which semantic layer owns a colour (v0.9 D6).
##
##     ARCHIPELAGO TRUTH IS NOT EPSILON.
##
## The decision this file exists to make un-forgettable. Epsilon has a
## strong visual language -- neon green, alien, invasive -- and the
## gravitational pull of a strong language is that everything important
## drifts into it. Then a Check looks like an Epsilon organ, the source
## game it belongs to stops being legible, and the player loses the one
## distinction the whole game is about: **this is somebody else's item,
## in somebody else's world, and Epsilon is only the thing interpreting
## it.**
##
## Three layers, and they stay separate:
##
## 1. **EPSILON** — the presence, the portal phenomenon, the fabricated
##    enemy family, interpretation machinery, corruption, alien conduits.
##    Neon green is theirs.
## 2. **ARCHIPELAGO TRUTH** — Checks. Their own universal repeated
##    identity, readable across a room, and NOT Epsilon's green.
## 3. **SOURCE GAME** — per-game identity, derived from the recipient
##    game's theme. Epsilon must not overwrite it.
##
## Echoes and portals are deliberately HYBRID: human/facility mounting or
## architectural collar, plus the alien event inside it. That contrast is
## the point, and it stays expressible because the layers stay separate.
##
## The art lane owns the actual colours. This file owns the fact that
## they are different things.

## Epsilon's active signal. Neon, alien, hostile.
const EPSILON_SIGNAL := Color(0.15, 1.0, 0.35)

## Archipelago truth. Deliberately NOT in Epsilon's hue family: a Check
## is not an Epsilon organ, and a player scanning a room has to be able
## to tell at a glance which of the two they are looking at.
const CHECK_SIGNAL := Color(0.35, 0.85, 1.0)

## The human facility Epsilon has embedded itself into: cold concrete,
## pale walls, yellow utility light. Present so "alien" has something to
## be alien against.
const FACILITY_UTILITY := Color(1.0, 0.85, 0.35)

## Minimum separation between two layers' signals, in RGB distance. Not
## a perceptual model -- a floor. Two signals this close are two signals
## a player reads as one thing under bloom, at distance, in a dark room.
const MIN_LAYER_SEPARATION := 0.45

enum Layer { EPSILON, ARCHIPELAGO, SOURCE_GAME, FACILITY }

static func signal_for(layer: Layer) -> Color:
	match layer:
		Layer.EPSILON: return EPSILON_SIGNAL
		Layer.ARCHIPELAGO: return CHECK_SIGNAL
		Layer.FACILITY: return FACILITY_UTILITY
		_: return Color.WHITE

## Whether a colour is close enough to Epsilon's signal to read as
## Epsilon's. Used to keep other layers out of it.
static func reads_as_epsilon(color: Color) -> bool:
	return _distance(color, EPSILON_SIGNAL) < MIN_LAYER_SEPARATION

## Why these two layers are indistinguishable, or "" if they are fine.
static func collision(a_name: String, a: Color,
		b_name: String, b: Color) -> String:
	var apart := _distance(a, b)
	if apart >= MIN_LAYER_SEPARATION:
		return ""
	return ("%s (%s) and %s (%s) are %.2f apart; separate semantic "
			% [a_name, a, b_name, b, apart]
			+ "layers need at least %.2f or the player reads them as one "
			% MIN_LAYER_SEPARATION + "thing")

static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

## Every signal an activity must not be mistaken for.
##
## Checks and Epsilon only. The facility's utility yellow is deliberately
## NOT here: activity hardware IS facility equipment, so reading as part
## of the building is correct rather than a collision.
const RESERVED_FOR_OTHERS: Array[Color] = [CHECK_SIGNAL, EPSILON_SIGNAL]

## A theme's own colour, pushed clear of the layers it must not
## impersonate.
##
## NOT a universal "activity colour". A Zone's theme is a real identity
## and this keeps it: `concrete_facility` stays pale, `gothic_stone`
## stays warm. What it refuses is the case measured on 2026-08-30 --
## `neon_transit`'s light is `#7cf2ff`, which sits **0.17** from
## `CHECK_SIGNAL` against a floor of 0.45, so in the Zone the owner
## actually plays every switch and target was wearing Archipelago's
## colour.
##
## Structure carries identity FIRST; this only stops the secondary cue
## from lying. The push is along value and saturation rather than hue,
## so the theme still reads as itself.
static func separated_from_reserved(color: Color) -> Color:
	var out := color
	for _attempt in 8:
		var worst := ""
		for reserved in RESERVED_FOR_OTHERS:
			if _distance(out, reserved) < MIN_LAYER_SEPARATION:
				worst = "collides"
				break
		if worst == "":
			return out
		# Toward the facility's own utility warmth and away from the
		# cyan/green signal band, a step at a time. Deterministic: the
		# same theme always lands on the same colour, so two runs of the
		# same Zone look identical.
		out = Color(
			minf(1.0, out.r + 0.12),
			maxf(0.0, out.g - 0.06),
			maxf(0.0, out.b - 0.14),
			color.a)
	return out


# --- D4: the tier presentation arc -----------------------------------------

## How embedded Epsilon looks in the HUB at each progression tier.
##
## **Presentation only.** No Archipelago logic, no progression
## requirement and no Zone theme reads this. The decision is explicit
## that generated Zones must NOT be washed in Epsilon green as tiers
## advance -- source-game identity is a separate layer (D6) and stays
## legible at tier 3 exactly as it was at tier 1.
##
## Tiers stay unnamed to the player; this is atmosphere, not a label.
const TIER_INTRUSION := {
	0: 0.25,   # localized; the facility still reads as abandoned human
	1: 0.6,    # established; visible integration around Epsilon systems
	2: 1.0,    # thoroughly embedded; alien systems occupy the place
}

## 0.0-1.0, how far Epsilon's construction has taken over the Hub.
static func hub_intrusion(tier: int) -> float:
	return float(TIER_INTRUSION.get(clampi(tier, 0, 2), 0.25))

# --- art-lane review gate --------------------------------------------------

## Review states an authored asset can be in. The art lane is in STYLE
## LOCK 001-R and its assets are NOT subjectively approved, so a file
## existing in the tree is not permission to ship it.
const REVIEW_PENDING := "pending"
const REVIEW_PASS := "pass"

## Whether an entry may be instantiated into a real zone.
##
## Absent review status means an entry predates the gate, and those are
## the procedural placeholders that were never art-reviewed because they
## are not art. An entry that explicitly says `pending` is a different
## thing: someone is still deciding, and shipping it would decide for
## them.
static func is_shippable(entry: Dictionary) -> bool:
	var status := str(entry.get("review", ""))
	return status != REVIEW_PENDING
