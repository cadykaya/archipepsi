class_name ReviewIsolation
extends RefCounted
## THE ISOLATED REVIEW BUILDS, named in one place.
##
## Three launches promise "no bridge connection, and none of the player's
## files written": the concourse-pier playtest (`RoomPlaytest`), Crossing
## D's review build (`CrossingD`) and the Impact Lab (`ImpactLab`). Every guard -- the bridge
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


static func crossing() -> bool:
	return CROSSING_FLAG in OS.get_cmdline_user_args() \
			or OS.has_feature(CROSSING_FEATURE)


static func lab() -> bool:
	return LAB_FLAG in OS.get_cmdline_user_args() \
			or OS.has_feature(LAB_FEATURE)


static func active() -> bool:
	return RoomPlaytest.requested() or crossing() or lab()
