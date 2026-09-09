class_name Telemetry
extends RefCounted
## THE OPERATOR'S VIEW OF STAGE 3A, on one prefix.
##
## WHY A NAMED PLACE RATHER THAN SCATTERED PRINTS. The evidence a
## playtest operator needs -- which mode is active, which authored shell
## a room resolved to, what was declared versus judged versus built,
## whether a rail was actually caught, whether a pad actually fired -- is
## worth nothing if it is spelled three different ways in three files.
## Every line here starts `p3a:` so one grep answers "what did that run
## actually do".
##
## WHAT THIS IS NOT. It is not the interpretation log, it is not an
## Archipelago event, and nothing here is persisted or sent over the
## bridge. `PlaytimeLog` remains the measurement channel that reaches
## Python; this is a local operator console and a Zone plays identically
## with every line of it removed.
##
## PRINT, NOT push_warning. The `make` targets filter WARNING and ERROR
## out of their output, so a warning is the one channel an operator
## running the game through the Makefile cannot see. Declines and
## refusals still warn -- they are problems -- but the ordinary census is
## printed.

const TAG := "p3a"

## The showcase was asked for, and with which selection.
static func showcase(zone_id: String, mode: String,
		shells: Array) -> void:
	print("%s: showcase '%s' requested, movement-package=%s, shells=%s"
			% [TAG, zone_id, mode, ", ".join(PackedStringArray(shells))])

## An operator asked for a movement package that does not exist.
##
## Loud, and it never becomes a selection: a typo that quietly became
## `none` would produce a green run that proved nothing.
static func refused_selection(why: String) -> void:
	push_error("%s: %s" % [TAG, why])
	print("%s: REFUSED -- %s" % [TAG, why])

## One room's offer result, with the shell it actually resolved to.
##
## SEVEN TERMS, PRINTED AS SEVEN. An operator reading one number cannot
## tell an offer that was measured true from one that was chosen from one
## that a node exists for, and those are the three questions a 3A run
## exists to answer separately. The shell id is here because "the room
## offered six things" is not useful evidence unless you know whether the
## room was the authored shell or the procedural stand-in it falls back
## to.
static func room(named: String, shell_id: String, mode: String,
		declared: int, judged: int, accepted: int, selected: int,
		declined: int, built: int, refused: bool) -> void:
	print("%s: room %-10s shell=%-20s mode=%-6s declared=%d judged=%d "
			% [TAG, named, ("(procedural)" if shell_id == "" else shell_id),
				mode, declared, judged]
			+ "accepted=%d selected=%d declined=%d built=%d%s"
			% [accepted, selected, declined, built,
				("  REFUSED" if refused else "")])

## What the selector chose, by identity, once for the Zone.
##
## Named one at a time on purpose: a count cannot distinguish "the rail
## in every room" from "four rails in one room", and the identity is what
## a later run is compared against.
static func selection(mode: String, chosen: Array) -> void:
	if chosen.is_empty():
		print("%s: selection mode=%s -- nothing selected" % [TAG, mode])
		return
	var parts: Array[String] = []
	for raw: Variant in chosen:
		var entry: Dictionary = raw
		parts.append("%s/%s/%s" % [str(entry.get("chamber", "?")),
				str(entry.get("kind", "?")), str(entry.get("offer", "?"))])
	print("%s: selection mode=%s (%d) -- %s"
			% [TAG, mode, chosen.size(), ", ".join(parts)])

## The Zone-wide census, once, after every room.
static func zone_offers(zone_id: String, mode: String,
		census: Dictionary) -> void:
	print("%s: zone %s mode=%s declared=%d judged=%d accepted=%d "
			% [TAG, zone_id, mode, int(census.get("declared", 0)),
				int(census.get("judged", 0)), int(census.get("accepted", 0))]
			+ "selected=%d built=%d declined=%d refused=%d "
			% [int(census.get("selected", 0)), int(census.get("built", 0)),
				int(census.get("declined", 0)), int(census.get("refused", 0))]
			+ "(rooms judged before the first build: %d)"
			% int(census.get("judged_before_first_build", 0)))

## The player caught a rail. This is the line that distinguishes "a rail
## node exists" from "a player rode a rail", which are not the same
## claim and only one of them is Stage 3A's.
static func rail_caught(at: Vector3) -> void:
	print("%s: rail CAUGHT at %v" % [TAG, at])

static func rail_released(at: Vector3) -> void:
	print("%s: rail RELEASED at %v" % [TAG, at])

## A launch pad fired a real player.
static func launch_fired(from: Vector3, velocity: Vector3) -> void:
	print("%s: launch FIRED from %v at %v" % [TAG, from, velocity])
