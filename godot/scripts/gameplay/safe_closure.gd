class_name SafeClosure
extends RefCounted
## §21.2'S INTERLOCK, AUTHORED ONCE.
##
## `01_RELIABLE_CORE.md` §21.2, pinned unchanged by the Amalgam:
##
## > `safe_closure = true` (the default) means: if closing would
## > intersect the player or any `required = true` object, the door
## > **stops and reverses to fully open**, then retries after `1.0 s`. It
## > repeats indefinitely. It never crushes.
##
## **WHY THE REVERSAL IS THE LOAD-BEARING HALF, and not a flourish on top
## of "stop".** A door that only stops has parked a panel halfway across
## the doorway it was asked to clear, and it holds that position for as
## long as the obstruction lasts. The player standing under it is given
## no signal that stepping aside is what the machine is waiting for, the
## opening they walked through is now narrower than it was, and anything
## being carried through may no longer fit. Reversing to FULLY open puts
## the door back in the state the player can act from, and the 1.0 s
## retry is what makes the wait legible: the door tries, visibly, again.
##
## This class is the rule and holds only the rule's state. What "blocked"
## means is the caller's -- a doorway volume, a swept-path query, a list
## of required bodies -- and so is how the panel moves. That split is why
## `ServiceShutter` (accelerating, `StopTravel`-driven) and `Actuator`
## (linear, `1/travel_time`) can obey the same interlock without sharing
## a motion law, in the same way `StopTravel` is shared without sharing a
## machine.
##
## `safe_closure = false` is NOT this class. §21.2 makes that an authored
## crusher hazard that deals `HAZARD` damage and does not reverse; a door
## that wants it simply does not own one of these.

## What the machine should do with the panel this frame.
enum Order {
	PROCEED,    ## Move as commanded. Nothing is in the way.
	REVERSE,    ## Travel toward fully open, whatever the input says.
	HOLD_OPEN,  ## Fully open and counting down the retry.
}

## The panel reached fully open after a blocked closure and is now
## waiting out the retry interval. Carries how many closures have been
## refused so far, so a consumer can tell one interruption from a door
## being repeatedly denied.
signal reopened(refusals: int)

## §21.2's "retries after 1.0 s".
var retry_seconds := Constants.SAFE_CLOSURE_RETRY_SECONDS

## True from the moment a closure is refused until the retry fires.
var reversing := false
## Seconds left of the retry interval. Only counts down once FULLY open,
## because "retries after 1.0 s" is measured from the reversal being
## finished, not from the refusal.
var retry_left := 0.0
## How many closures have been refused. Never reset -- it is a tally of
## interruptions, and a door closing successfully does not un-refuse the
## ones before it.
var refusals := 0
## Seconds this door has wanted to be shut and has not been, because of
## the interlock. Cleared when the input stops asking for a closure.
var overrun := 0.0


## Decide this frame.
##
## `wants_shut` is what the input commands, `blocked` is whether the
## interlock sees something it may not crush, and `fully_open` is whether
## the panel has finished reversing. All three are the caller's to
## measure; none of them is remembered here between frames except through
## the state this returns.
func order(delta: float, wants_shut: bool, blocked: bool,
		fully_open: bool) -> Order:
	if not wants_shut:
		# THE COMMAND WENT AWAY. Nothing is being refused any more, so
		# there is nothing to retry and nothing to count.
		reversing = false
		retry_left = 0.0
		overrun = 0.0
		return Order.PROCEED
	if not reversing:
		if not blocked:
			return Order.PROCEED
		# STOP AND REVERSE. The first refusal of this episode.
		reversing = true
		refusals += 1
		retry_left = retry_seconds
		overrun += delta
		return Order.REVERSE
	overrun += delta
	if not fully_open:
		# STILL TRAVELLING BACK. §21.2 reverses "to fully open", so a
		# doorway that clears mid-reversal does not cancel it -- the
		# panel finishes going up, and only then does the clock start.
		# That is also why `retry_left` is not touched until here.
		return Order.REVERSE
	retry_left = maxf(retry_left - delta, 0.0)
	if retry_left > 0.0:
		return Order.HOLD_OPEN
	# THE RETRY FIRES. "It repeats indefinitely": an attempt made against
	# a doorway that is still occupied is refused again and re-armed,
	# which is why `refusals` keeps ticking for as long as somebody
	# stands there rather than counting one interruption and going quiet.
	#
	# The attempt is refused BEFORE any motion rather than after a
	# frame of it. A panel that dips a centimetre every second at
	# somebody standing under it is not what "never crushes" should look
	# like, and the outcome is identical either way: the door shuts
	# within `retry_seconds` of the doorway clearing.
	if blocked:
		refusals += 1
		retry_left = retry_seconds
		return Order.HOLD_OPEN
	reversing = false
	reopened.emit(refusals)
	return Order.PROCEED
