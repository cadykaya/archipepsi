class_name ConnectorGrammar
extends RefCounted
## Whether two sockets may join (v0.9 S15).
##
## `AUTHORED_CONTENT.md` says Godot enforces the grammar. This is the
## grammar: given two openings, may a player walk from one to the other?
##
## The rule that matters is not "do the numbers look plausible" but
## **invariant I4** — the mandatory path must stay walkable with the base
## kit alone. A join the player cannot fit through does not make a zone
## ugly, it makes it unfinishable, and it does so at generation time in a
## seed that already passed every other check. So the fit test is against
## the player's actual capsule, taken from `Constants` rather than from a
## number typed here.
##
## Nothing in this file knows what an asset looks like. It reads declared
## socket metadata, which both languages validated first.

## Which socket kinds can meet which. A doorway meets a doorway (room to
## room) or a corridor end (room to connector); a corridor end meets
## either. Everything else -- an `affordance` mount, a `spawn` point -- is
## not a way through and never joins.
const JOINABLE := {
	"doorway": ["doorway", "corridor_end"],
	"corridor_end": ["doorway", "corridor_end"],
}

## Clearance beyond the player's own capsule. A doorway exactly one
## capsule wide is one the player scrapes through and, with any lateral
## velocity, does not: `move_and_slide` resolves the contact by stopping.
## 0.4 m is a hand's width either side at the narrowest legal opening.
const SIDE_CLEARANCE := 0.4

## Headroom above the capsule, for the same reason in the other axis.
const HEAD_CLEARANCE := 0.2

static func min_passable_width() -> float:
	return Constants.PLAYER_RADIUS * 2.0 + SIDE_CLEARANCE

static func min_passable_height() -> float:
	return Constants.PLAYER_HEIGHT + HEAD_CLEARANCE

## The opening two joined sockets actually leave: the smaller of each
## dimension. Two 2.4 m doorways leave 2.4 m; a 2.4 m doorway meeting a
## 1.0 m one leaves 1.0 m, and the wider one is irrelevant.
static func passage(a: Dictionary, b: Dictionary) -> Vector2:
	return Vector2(
		minf(float(a.get("width", 0.0)), float(b.get("width", 0.0))),
		minf(float(a.get("height", 0.0)), float(b.get("height", 0.0))))

static func can_join(a: Dictionary, b: Dictionary) -> bool:
	return refusal(a, b).is_empty()

## Why these two may not join, or "" if they may. A reason rather than a
## bool because the caller is usually a validator reporting to a human,
## and "cannot join" without a measurement is not something an artist can
## act on.
static func refusal(a: Dictionary, b: Dictionary) -> String:
	var kind_a := str(a.get("kind", ""))
	var kind_b := str(b.get("kind", ""))
	if not JOINABLE.has(kind_a):
		return "'%s' is a %s, which is not a way through" % [
				str(a.get("name", "?")), kind_a]
	if not JOINABLE.has(kind_b):
		return "'%s' is a %s, which is not a way through" % [
				str(b.get("name", "?")), kind_b]
	if not kind_b in (JOINABLE[kind_a] as Array):
		return "a %s cannot meet a %s" % [kind_a, kind_b]

	var opening := passage(a, b)
	if opening.x < min_passable_width():
		return ("joining '%s' (%.2f m) to '%s' (%.2f m) leaves %.2f m, "
				% [str(a.get("name", "?")), float(a.get("width", 0.0)),
				   str(b.get("name", "?")), float(b.get("width", 0.0)),
				   opening.x]
				+ "and the player needs %.2f m to walk through"
				% min_passable_width())
	if opening.y < min_passable_height():
		return ("joining '%s' (%.2f m) to '%s' (%.2f m) leaves %.2f m of "
				% [str(a.get("name", "?")), float(a.get("height", 0.0)),
				   str(b.get("name", "?")), float(b.get("height", 0.0)),
				   opening.y]
				+ "headroom, and the player needs %.2f m"
				% min_passable_height())
	return ""

## Every socket on an entry that something could come through. The query
## the chain uses when it needs to know where a room can be entered.
static func joining_sockets(entry: Dictionary) -> Array:
	var out: Array = []
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		if JOINABLE.has(str((socket as Dictionary).get("kind", ""))):
			out.append(socket)
	return out

## Whether a room can be walked into AND out of by the base kit. A shell
## with one usable opening is a dead end; the mandatory path is a chain,
## so every shell on it needs two the player actually fits through.
##
## Returns "" when the shell is chainable, or the reason it is not.
static func chainable(entry: Dictionary) -> String:
	var usable: Array = []
	for socket: Dictionary in joining_sockets(entry):
		var w := float(socket.get("width", 0.0))
		var h := float(socket.get("height", 0.0))
		if w >= min_passable_width() and h >= min_passable_height():
			usable.append(socket)
	if usable.size() < 2:
		return ("'%s' has %d opening(s) the player fits through; a room on "
				% [str(entry.get("id", "?")), usable.size()]
				+ "the mandatory path needs a way in and a way out")
	return ""
