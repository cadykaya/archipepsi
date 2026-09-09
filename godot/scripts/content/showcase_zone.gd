class_name ShowcaseZone
extends RefCounted
## THE STAGE 3A SHOWCASE, and it is scaffolding (Road to Playable 0.3, R2).
##
## WHAT THIS IS FOR. Stage 3A has to prove that a player can ride an
## authored rail and use an authored launch pad. It cannot do that in an
## ordinary generated Zone, because an ordinary generated Zone contains no
## authored rooms at all: every chamber Epsilon emits carries
## `shell_id: null`, and `ContentInstantiator.SHELL_FOR_TYPE` then routes
## every one of them to a procedural builder. So the four offer-bearing
## authored rooms are named here explicitly, and that naming is the whole
## of the scaffolding.
##
## WHAT THIS IS NOT. Naming a `shell_id` by hand is not composition. It
## does not satisfy A1 (an authored room appears in an actually played
## Zone through the real path) and it does not satisfy A2 (a real Zone is
## composed from approved authored rooms). Those are Stage 3B's, and 3B
## is defined by Epsilon emitting these ids itself. Nothing here teaches
## it to; nothing here runs unless an operator asks for it by name.
##
## WHY IT IS A ZONE DICTIONARY AND NOT A SCENE. Everything downstream of
## this is the real runtime: `ZoneBuilder` places and aligns the rooms,
## `ContentInstantiator` resolves each `shell_id` through the registry and
## instantiates the authored scene, the physics server registers the
## authored colliders, `OfferBinding` measures the declared offers against
## them, and the real `Player` walks in. A hand-built scene would prove
## that a hand-built scene works.
##
## CONNECTORS DO THE ALIGNMENT. Room order is chosen here; entry and exit
## offsets, vertical offset, yaw and overlap avoidance are `ZoneBuilder`'s
## and are not restated -- a second copy of the placement arithmetic is
## how the composer and the builder come to disagree.

## The showcase's id. Fixed, because `ZoneBuilder` seeds its layout RNG
## from it: one id is one deterministic chain, every run.
const ZONE_ID := "playtest3a_showcase"

## The four approved offer-bearing rooms, in the order they are chained.
##
## Recorded here rather than derived, so the chain a report describes is
## the chain the code builds. Every id is `review: pass` and is measured
## by the room-contract suite like any other approved shell.
const ROOMS := [
	{"id": "p3a_hall", "shell_id": "shell_hall_transit", "type": "arena"},
	{"id": "p3a_plenum", "shell_id": "shell_plenum_helix", "type": "tower"},
	{"id": "p3a_yard", "shell_id": "shell_yard_gantry", "type": "arena"},
	{"id": "p3a_span", "shell_id": "shell_span_basin", "type": "arena"},
]

## The theme the showcase renders in. One of the approved set; the choice
## is cosmetic and changes no geometry.
const THEME := "concrete_facility"

## The curated Zone, built from the live registry.
##
## Dimensions come from each shell's own `size`, so the chamber asks for
## the room the art lane actually authored rather than a number copied
## here that could drift away from it.
static func build(registry: ContentRegistry = null) -> Dictionary:
	var reg := registry
	if reg == null:
		reg = ContentRegistry.new()
		reg.load_all()
	var chambers: Array = []
	for raw: Variant in ROOMS:
		var spec: Dictionary = raw
		var entry := reg.get_entry(str(spec["shell_id"]))
		if entry.is_empty():
			push_warning("playtest3a: the registry does not carry '%s'; "
					% str(spec["shell_id"]) + "the showcase will build a "
					+ "procedural room in its place")
		var size: Array = entry.get("size", [12.0, 6.0, 12.0])
		var chamber := {
			"id": str(spec["id"]),
			"type": str(spec["type"]),
			# THE SCAFFOLDING, IN ONE FIELD. `shell_id` is the schema
			# field Epsilon will fill in 3B; here an operator fills it.
			"shell_id": str(spec["shell_id"]),
			"objective": "reach_exit",
			"enemies": [],
			"activities": [],
			"width": float(size[0]),
			"wall_height": float(size[1]),
			"depth": float(size[2]),
		}
		if str(spec["type"]) == "tower":
			var fits: Array = entry.get("fits_floors", [])
			chamber["floors"] = int(fits[0]) if not fits.is_empty() else 3
		chambers.append(chamber)
	return {
		"schema_version": 1,
		"zone_id": ZONE_ID,
		"display_name": "Playtest 3A showcase",
		"theme": THEME,
		"target_game": "Archipepsi",
		"designer_note": "Stage 3A scaffolding: the four approved "
				+ "offer-bearing authored rooms, named by hand. Not "
				+ "composition, and not evidence for A1 or A2.",
		"chambers": chambers,
	}

## The shell ids this showcase asks for, for a caller that wants to check
## what it got against what it requested.
static func shell_ids() -> Array:
	var out: Array = []
	for raw: Variant in ROOMS:
		out.append(str((raw as Dictionary)["shell_id"]))
	return out
