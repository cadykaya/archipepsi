class_name VerbRelations
extends RefCounted
## §14.4's `max_relations` and §31.2's relation exclusivity, for one
## caster -- RUNTIME ONLY, like the verbs that use it (O05-08.2).
##
## "`max_relations` (held, pinned, tethered, combined): `3`, raised to at
## most `6` by `RULE_RELATION_COUNT`" (§14.4). "A single object may be
## under at most **one** player relation at a time. Activating a second
## relation on an object already held, pinned, or tethered by the player
## releases the first. This is separate from `max_relations`, which caps
## relations across *different* objects." (§31.2)
##
## A relation is a `VerbHold`, a `VerbPin` or a `VerbTether`: anything
## with `bodies()`, `active()` and `release(reason)`. ROTATE is not one;
## §14.4 lists held, pinned and tethered.

const DEFAULT_MAX := 3
const CEILING := 6
## Why the ledger, rather than the relation itself, ended one.
const OVER_MAX := "max_relations"
const EXCLUSIVE := "superseded"

var max_relations := DEFAULT_MAX
## Oldest first. Untyped: a relation may be freed while it is listed.
var _relations: Array = []

## The ledger for a direct invocation with nobody casting.
static var _nobody: VerbRelations = null


## `caster`'s ledger, made on first use and kept on the caster, so it
## goes when the caster does.
static func of(caster: Object) -> VerbRelations:
	if caster == null or not is_instance_valid(caster):
		if _nobody == null:
			_nobody = VerbRelations.new()
		return _nobody
	if not caster.has_meta(&"verb_relations"):
		caster.set_meta(&"verb_relations", VerbRelations.new())
	return caster.get_meta(&"verb_relations")


## `RULE_RELATION_COUNT`: `max_relations` `+magnitude`, "capped at `6`
## total". No rule reaches this yet; the cap is the contract's.
func raise_by(magnitude: int) -> int:
	max_relations = clampi(DEFAULT_MAX + maxi(magnitude, 0), DEFAULT_MAX,
			CEILING)
	return max_relations


## Take `relation` on. First §31.2: a relation already on one of its
## bodies is released. Then §14.4: while the count is at the cap, the
## oldest goes.
func admit(relation: Object) -> void:
	_prune()
	for other: Variant in _relations.duplicate():
		if other != relation and _share_a_body(other, relation):
			(other as Object).call("release", EXCLUSIVE)
	_prune()
	while _relations.size() >= max_relations:
		var oldest: Object = _relations.pop_front()
		oldest.call("release", OVER_MAX)
		_prune()
	_relations.append(relation)


func count() -> int:
	_prune()
	return _relations.size()


## The live relations, oldest first.
func relations() -> Array:
	_prune()
	return _relations.duplicate()


func _prune() -> void:
	_relations = _relations.filter(func(held: Variant) -> bool:
		return is_instance_valid(held) and bool(
				(held as Object).call("active")))


static func _share_a_body(first: Object, second: Object) -> bool:
	var theirs: Array = second.call("bodies")
	for body: Variant in first.call("bodies"):
		if theirs.has(body):
			return true
	return false
