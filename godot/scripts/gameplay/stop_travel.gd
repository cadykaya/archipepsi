class_name StopTravel
extends RefCounted
## One step of travel between ordered stops on a scalar axis.
##
## **Shared because two different machines need the same arithmetic and
## must not author it twice.** `RailCarrier` runs an offset along a
## curved `RailPath` with its deck turned to face the way it is going;
## `ShuttleDeck` runs a LEVEL deck along a straight world axis. Those are
## genuinely different machines — a rail carrier on a vertical path would
## stand its deck on end and drop the passenger — but how either one gets
## from one stop to the next is the same question, and EX50-011 §9 asks
## for exactly that: behaviour "consistent with the shared machinery
## contract" rather than two schedules that happen to agree today.
##
## Static, and holding no state. What moves belongs to the machine.

## ARRIVE, DO NOT STALL. The obvious loop -- accelerate, and shed speed
## once inside `v^2 / 2a` -- undershoots by about `v * delta / 2` on a
## discrete timestep, which at 7 m/s and 60 Hz is 0.058 m: further than
## a carrier's arrival tolerance. The machine halts just short of the
## stop and then creeps in, stuttering, because each frame it
## re-accelerates.
##
## Capping the speed at the one this stopping distance can still shed
## instead is self-correcting: as the gap closes the cap closes with it,
## and the implied braking is never harsher than `accel`.
##
## Returns `(offset, speed)`. Arrival is the caller's to notice -- it is
## the caller that knows what arriving means -- and `offset` is snapped
## to `goal` once it is within `epsilon`, so the test is exact.
static func step(offset: float, goal: float, speed: float, delta: float,
		accel: float, top: float, epsilon: float) -> Vector2:
	var remaining := absf(goal - offset)
	if remaining <= epsilon:
		return Vector2(goal, 0.0)
	var ceiling := sqrt(2.0 * accel * remaining)
	var moved := minf(minf(speed + accel * delta, top), ceiling)
	var travelled := minf(moved * delta, remaining)
	var now := offset + travelled * signf(goal - offset)
	if absf(goal - now) <= epsilon:
		return Vector2(goal, 0.0)
	return Vector2(now, moved)
