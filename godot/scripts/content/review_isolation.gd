class_name ReviewIsolation
extends RefCounted
## THE ISOLATED REVIEW BUILDS, named in one place.
##
## Three launches promise "no bridge connection, and none of the player's
## files written": the concourse-pier playtest (`RoomPlaytest`), Crossing
## D's review build (`CrossingD`), the Impact Lab (`ImpactLab`), the Impact
## Relay (`ImpactRelay`) and the weapon-feel range (`WeaponFeel`). Every guard -- the bridge
## client before it opens a socket, and the three client-file writers --
## asks `active()`, so the promise is kept by the same four lines for both.
##
## A leaf on purpose: the bridge client asks this from its own `_ready`,
## before the main scene exists, so it names Crossing D's switches as
## plain strings rather than loading the Crossing's scripts to read them.

## Crossing D by name, from a source checkout or a launcher.
const CROSSING_FLAG := "--crossing-d"
## Crossing D as an exported build: the export preset's custom feature,
## so the review executable starts straight into it with no arguments.
const CROSSING_FEATURE := "crossing_review"
## The Impact Lab (the post-D G0 fixture), by name and as an export.
const LAB_FLAG := "--impact-lab"
const LAB_FEATURE := "impact_lab"
## The Impact Relay (G1, D-18's room), by name and as an export.
const RELAY_FLAG := "--impact-relay"
const RELAY_FEATURE := "impact_relay"
## The weapon-feel range (the Static Pulse's firing-feedback experiment).
const WEAPON_FLAG := "--weapon-feel"
const WEAPON_FEATURE := "weapon_feel"


static func crossing() -> bool:
	return CROSSING_FLAG in OS.get_cmdline_user_args() \
			or OS.has_feature(CROSSING_FEATURE)


static func lab() -> bool:
	return LAB_FLAG in OS.get_cmdline_user_args() \
			or OS.has_feature(LAB_FEATURE)


static func relay() -> bool:
	return RELAY_FLAG in OS.get_cmdline_user_args() \
			or OS.has_feature(RELAY_FEATURE)


static func weapon() -> bool:
	return WEAPON_FLAG in OS.get_cmdline_user_args() \
			or OS.has_feature(WEAPON_FEATURE)


static func active() -> bool:
	return RoomPlaytest.requested() or crossing() or lab() or relay() \
			or weapon()
