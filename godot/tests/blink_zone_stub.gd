class_name BlinkZoneStub
extends Node3D
## Stands in for ZoneController in the blink suite: it answers
## `world_bounds()` the same way and nothing else.
##
## The runtime finds the bounds by walking UP from the player, so what
## matters is that a `world_bounds()` ancestor exists -- not that it is a
## real controller. Using the real one would drag in the bridge, the HUD and
## the objective machinery to test a raycast.

var _bounds := AABB()
var _has_bounds := false

func add_bounds(box: AABB) -> void:
	_bounds = box if not _has_bounds else _bounds.merge(box)
	_has_bounds = true

func world_bounds() -> Variant:
	return _bounds if _has_bounds else null
