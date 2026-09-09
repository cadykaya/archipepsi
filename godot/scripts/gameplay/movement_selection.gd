class_name MovementSelection
extends RefCounted
## WHICH MOVEMENT PACKAGE A ZONE BUILDS, as an operator control (3A).
##
## STAGE 3A ONLY, AND DELIBERATELY NOT A GAME SYSTEM (Road to Playable
## 0.3, R6). This is a developer / playtest switch and nothing else. It is
## NOT an Archipelago item, NOT progression state, NOT a randomized
## unlock, NOT saved with the player, NOT an Epsilon decision, and NOT a
## field of the Zone schema. Nothing here crosses the bridge, touches AP
## logic, or is written to a save. How a movement package is earned in the
## shipped game is an undecided question, and this must not answer it by
## accident -- so the selection lives in a command-line argument, which is
## the one place a decision cannot accidentally become progression.
##
## THREE SELECTIONS, ZONE-WIDE (R7). `none` builds nothing, `rail` builds
## accepted rail routes, `launch` builds accepted launch sources. A
## `launch_target` is never built independently: it is measured as half of
## its source's contract, which is why it has no mode of its own.
##
## AN UNKNOWN VALUE IS REFUSED, NEVER DEFAULTED. A typo that silently
## became `none` would produce a green run that proved nothing, and a typo
## that silently became `rail` would be worse. The set is closed, and a
## value outside it stops the Zone with a message naming what was asked
## for and what exists.

## The closed set of selections. Adding to this is a design decision, not
## a convenience.
const MODES := ["none", "rail", "launch"]

## The selection when the showcase is asked for without a mode.
const DEFAULT_MODE := "none"

const SHOWCASE_FLAG := "--playtest3a"
const PACKAGE_PREFIX := "--movement-package="

## What each mode asks `OfferBinding.construct` to build.
##
## The value is an offer-kind filter, so a mode can only ever construct
## kinds it names -- `rail` cannot leak a launch pad because it never
## asks for one, and the filter is the same `only` argument the offer
## rules have taken since P3.0.
const BUILDS := {
	"none": [],
	"rail": ["rail_route"],
	"launch": ["launch_source"],
}

## Read the operator's request out of the command line.
##
## Returns `{showcase, mode, refused, why}`. `refused` is true for a
## `--movement-package` value outside `MODES`, and then `mode` is empty
## rather than any real selection -- a caller that ignores `refused` gets
## a mode that builds nothing and matches nothing, instead of quietly
## getting `none`.
static func parse(args: PackedStringArray) -> Dictionary:
	var showcase := false
	var asked := ""
	var seen := false
	for raw: String in args:
		if raw == SHOWCASE_FLAG:
			showcase = true
		elif raw.begins_with(PACKAGE_PREFIX):
			seen = true
			asked = raw.substr(PACKAGE_PREFIX.length())
	if not seen:
		return {"showcase": showcase, "mode": DEFAULT_MODE,
				"refused": false, "why": ""}
	if not MODES.has(asked):
		return {"showcase": showcase, "mode": "", "refused": true,
				"why": "movement package '%s' does not exist; " % asked
					+ "the selections are %s" % ", ".join(MODES)}
	return {"showcase": showcase, "mode": asked,
			"refused": false, "why": ""}

## The same question asked of the live process.
static func from_cmdline() -> Dictionary:
	return parse(OS.get_cmdline_user_args())

## The offer kinds a mode is willing to consider. Unknown modes consider
## nothing, which is the safe answer and never the silent one -- `parse`
## refuses them before a caller gets here.
##
## CONSIDERING IS NOT SELECTING. This is the appetite; `select` below is
## the decision, and construction builds what `select` returned rather
## than everything of a matching kind.
static func builds(mode: String) -> Array:
	return (BUILDS.get(mode, []) as Array).duplicate()

## THE SELECTION: which accepted offers this package will build, named
## one at a time.
##
## `judged` is one entry per room, `{chamber, accepted}`, taken from the
## Zone-wide validation pass -- so the decision is made once, with every
## room's verdict already in, and not room by room as each is measured.
##
## Returns `{chamber, offer, kind}` triples. AN IDENTITY, NOT A FILTER:
## construction is handed these and builds exactly them, so "build every
## accepted offer of a matching kind" is a thing the runtime can no
## longer do by accident. Today the policy takes every accepted offer of
## the mode's kinds, which for this library is one per room -- but the
## selection is still enumerated, because a filter and a list that happen
## to agree are not the same thing, and only one of them can be checked.
##
## DETERMINISTIC BY CONSTRUCTION. The result is sorted on
## `chamber|kind|offer`, so it cannot depend on the order rooms were
## placed in, the order the manifest listed offers in, the order a
## Dictionary iterates, or the order the physics server answered. Two
## Zones with the same content select the same offers in the same
## sequence.
static func select(mode: String, judged: Array) -> Array:
	var kinds := builds(mode)
	if kinds.is_empty():
		return []
	var keys: Array[String] = []
	var by_key: Dictionary = {}
	for raw: Variant in judged:
		var room: Dictionary = raw
		var chamber := str(room.get("chamber", ""))
		for item: Variant in room.get("accepted", []) as Array:
			var offer: Dictionary = item
			var kind := str(offer.get("kind", ""))
			if not kinds.has(kind):
				continue
			var entry := {"chamber": chamber, "kind": kind,
					"offer": str(offer.get("name", ""))}
			var key := key_of(entry)
			if by_key.has(key):
				continue
			keys.append(key)
			by_key[key] = entry
	keys.sort()
	var out: Array = []
	for key: String in keys:
		out.append(by_key[key])
	return out

## The identity of one selected offer, as one comparable string.
static func key_of(entry: Dictionary) -> String:
	return "%s|%s|%s" % [str(entry.get("chamber", "")),
			str(entry.get("kind", "")), str(entry.get("offer", ""))]

## The offer names selected for one chamber, for the construction call
## that room receives.
static func offers_for(chamber: String, selection: Array) -> Array:
	var out: Array = []
	for raw: Variant in selection:
		var entry: Dictionary = raw
		if str(entry.get("chamber", "")) == chamber:
			out.append(str(entry.get("offer", "")))
	return out
