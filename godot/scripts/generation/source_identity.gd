class_name SourceIdentity
extends RefCounted
## A source game's identity package (ECHOES §12).
##
## "Each source game deterministically yields glyph, accent colour, sound
## family and particle style, derived from the game name by the sha256 rule
## the bridge and client already share — so the two cannot disagree, and no
## copyrighted asset is involved."
##
## Glyph and accent already existed (the resource channel's mark, the
## campaign board's tint). S6 adds the other two, because dispositions are
## what make identity worth having: once *Longshot* can evolve *Hookshot*
## into one grapple, the only thing on screen that still says two worlds
## touched it is its identity package.
##
## These mark CONTRIBUTION, not the component's own meaning (§7.1). A
## resource keeps its semantic colour; the world that filled it shows in
## the glyph beside the bar and the particles when it fires.

#: Pitch multipliers, not different samples: the tone bank is procedural
#: and shared, so a family is a *timbre shift* of the same sound. Wide
#: enough to tell apart, narrow enough that nothing turns into a squeak.
const SOUND_FAMILIES := [
	{"name": "low", "pitch": 0.72},
	{"name": "warm", "pitch": 0.86},
	{"name": "plain", "pitch": 1.0},
	{"name": "bright", "pitch": 1.18},
	{"name": "glass", "pitch": 1.41},
	{"name": "chime", "pitch": 1.68},
]

#: How this world's contributions throw particles and draw tracers.
const PARTICLE_STYLES := ["spark", "drift", "shard", "ring", "mote", "streak"]

static func _index(game: String, salt: String, modulus: int) -> int:
	return ThemeMaterials._prng_seed_mod("%s|%s" % [game, salt], modulus)

## Playback pitch for a sound this world contributed. 1.0 when unknown, so
## an unattributed sound is simply the tone bank's own voice.
static func sound_pitch(game: String) -> float:
	if game.is_empty():
		return 1.0
	return float(SOUND_FAMILIES[_index(game, "sound_family",
			SOUND_FAMILIES.size())]["pitch"])

static func sound_family(game: String) -> String:
	if game.is_empty():
		return "plain"
	return str(SOUND_FAMILIES[_index(game, "sound_family",
			SOUND_FAMILIES.size())]["name"])

static func particle_style(game: String) -> String:
	if game.is_empty():
		return "spark"
	return PARTICLE_STYLES[_index(game, "particle_style",
			PARTICLE_STYLES.size())]

## The whole package in one call, for anything that wants to present a
## contribution rather than query one field of it.
static func package(game: String) -> Dictionary:
	return {
		"glyph": ResourcePalette.source_glyph(game),
		"accent": ThemeMaterials.color_for_game(game) if not game.is_empty()
				else Color(0.7, 0.7, 0.7),
		"sound_family": sound_family(game),
		"sound_pitch": sound_pitch(game),
		"particle_style": particle_style(game),
	}
