class_name MassClass
extends RefCounted
## What class a thing's mass puts it in, and what a Status does to that.
##
## **The thresholds are pinned, not chosen here.**
## `docs/design-proposals/02_PHYSICS_IS_THE_GAME.md` §10.2 fixes them, and
## they are transcribed rather than reinvented so that a room reading
## "HEAVY" and a verb refusing "too heavy" are reading the same word.
##
## **Class is DERIVED from kilograms, and a Status moves it anyway.**
## That is the whole of EX50-033: `lightened` drops an object one step
## down this ladder (Design 5 §15.2) *without* touching its `mass_kg`, so
## a sensor that reads CLASS releases and a sensor that sums KILOGRAMS
## does not. EX50-033 §10 calls the difference between those two
## vocabularies the room's decisive negative control, and §6 warns that
## "A mass-field ability that changes kilograms without changing the
## plate's semantic class may not release the plate." Both directions of
## that distinction live here.
##
## **This changes nothing that already exists.** No verb consults it yet;
## Design 2 §14.2's manipulation eligibility still reads kilograms, and
## making it read class is `B3` work with its own blast radius. What is
## here is the vocabulary and the ladder, and one room that uses them.

const LIGHT := "light"
const MEDIUM := "medium"
const HEAVY := "heavy"
const FIXED := "fixed"
## Ascending. `step_down` walks it and nothing falls off the bottom.
const LADDER := [LIGHT, MEDIUM, HEAVY, FIXED]

## Design 2 §10.2, READ FROM THE EXPORT rather than transcribed.
##
## The bridge's route validator decides whether a plate accepts the
## player with `physics.plate_accepts_player`, against its own ladder;
## this file decides it again at runtime. Two hand copies of the same
## three numbers is how a route the bridge certified becomes a door the
## runtime will not open, so both now read `schemas/physics.py`'s values
## through `export.py`. Same numbers as the transcription they replace.
const LIGHT_BELOW := Constants.MASS_LIGHT_BELOW
const MEDIUM_BELOW := Constants.MASS_MEDIUM_BELOW
const HEAVY_BELOW := Constants.MASS_HEAVY_BELOW


## The class an object's kilograms put it in.
##
## A thing that cannot be manipulated at all is `FIXED` whatever it
## weighs -- §10.2's second clause, and the reason a bolted 5 kg bracket
## is not `LIGHT`.
static func of_mass(mass_kg: float, manipulable := true) -> String:
	if not manipulable or mass_kg >= HEAVY_BELOW:
		return FIXED
	if mass_kg >= MEDIUM_BELOW:
		return HEAVY
	if mass_kg >= LIGHT_BELOW:
		return MEDIUM
	return LIGHT


static func rank(kind: String) -> int:
	return LADDER.find(kind)


## One step down the ladder, and `LIGHT` stays `LIGHT`.
static func step_down(kind: String, steps := 1) -> String:
	var at := rank(kind)
	if at < 0:
		return kind
	return LADDER[maxi(at - steps, 0)]


## Is `kind` at least as heavy as `than`?
static func at_least(kind: String, than: String) -> bool:
	var a := rank(kind)
	var b := rank(than)
	return a >= 0 and b >= 0 and a >= b


## The class a thing reads as RIGHT NOW, Statuses included.
##
## `anchored` wins over `lightened` because it is absolute: Design 5
## §15.2 says it makes the class `FIXED` outright, where `lightened` only
## moves it one step, and an object that is both is pinned rather than
## floating.
static func read(mass_kg: float, manipulable: bool,
		statuses: StatusEffects) -> String:
	var base := of_mass(mass_kg, manipulable)
	if statuses == null:
		return base
	if statuses.has("anchored"):
		return FIXED
	if statuses.has("lightened"):
		return step_down(base)
	return base


## The class of a node, if it is the kind of thing that has one.
##
## Duck-typed on purpose: `ManipulableBody` answers, and so would any
## later body that grows the same two questions. A node that answers
## neither has no class rather than a default one, because "" is a
## refusal and `LIGHT` would be a guess.
static func of_node(who: Variant) -> String:
	if not is_instance_valid(who):
		return ""
	var node := who as Node
	if node == null or not node.has_method("mass_class"):
		return ""
	return str(node.mass_class())
