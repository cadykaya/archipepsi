extends StaticBody3D
## A dummy that can be hurt and can burn, for `consumable_driver.gd`.
##
## Deliberately NOT an enemy: the question is whether a consumable's
## damage and its `apply_status_on_hit` modifier reach a target through
## the ordinary `EchoRuntime` path, and an enemy would bring an AI, a
## navigation agent and a death animation to a question that is about
## neither. What it does carry is the two things those paths reach for —
## `take_damage`, via `Damageable`, and a `statuses` bag.

var hp := 100.0
var statuses := StatusEffects.new()


func _init() -> void:
	# `burning` is implemented on `enemy` and not on `object`, and
	# `StatusEffects.apply` refuses a kind at an unsupported target. The
	# side is what makes this a legal host for the Status under test.
	statuses.side = "enemy"


func take_damage(amount: float, _from: Vector3 = Vector3.ZERO,
		_knockback: float = 0.0) -> bool:
	hp -= amount
	return hp <= 0.0


func reset_for_case() -> void:
	hp = 100.0
	statuses = StatusEffects.new()
	statuses.side = "enemy"
