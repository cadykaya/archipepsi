class_name EpsilonVoice
extends RefCounted
## Epsilon's running commentary during play.
##
## Authored client-side, exactly like the wall graffiti. This is
## presentation and nothing else: no line here reads, reports, invents or
## reorders a location, an item, a coin or an Echo. Every line reacts to
## something the player has already watched happen on screen, so a bark
## can never disagree with Archipelago about anything.
##
## Deliberately quiet. A designer who talks over every corridor stops being
## a character and becomes a status bar, so lines are rate-limited, never
## repeat back to back, and stay out of the way of the reveal cards.

#: Seconds of silence enforced between any two lines.
const COOLDOWN := 6.0
#: How long a line stays on screen.
const DWELL := 4.0

const LINES := {
	"first_blood": [
		"There. That is the shape of the room.",
		"Good. I was worried I had made it too polite.",
		"One down. I built more. Obviously.",
	],
	"room_cleared": [
		"Room clear. I will pretend that was the intended route.",
		"That is everything I put in here. Sorry about the wallpaper.",
		"Cleared. Take the thing. It is not mine to give, but take it.",
		"Nothing left standing. This is the part I am good at.",
	],
	"portal_open": [
		"The way out is open. It was always going to be.",
		"Portal live. Go on, before I redecorate.",
		"Done. Somewhere, someone else just got a package.",
	],
	"hurt": [
		"You are leaking. That was not in the brief.",
		"Structurally, you are fine. Emotionally, I am concerned.",
		"The Pulse still works. It always still works.",
	],
	"died": [
		"That was a load-bearing mistake.",
		"I will leave the room exactly as it was. It seems fairer.",
		"Nothing was lost. I checked. I check constantly.",
		"You died. The multiworld did not notice.",
	],
	"revived": [
		"Back on your feet. The enemies did not reset. Neither did I.",
		"Try the doorway this time.",
	],
	"long_walk": [
		"Take your time. I have nowhere to be.",
		"I put something on a wall around here. Find it or do not.",
		"This corridor is longer than I remember specifying.",
	],
}

var _last_line := ""
var _cooldown := 0.0

func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

## Returns the line to show, or "" when Epsilon should stay quiet. Callers
## name the event; deciding whether it is worth saying is this object's job,
## so no caller has to carry its own throttle.
func line_for(kind: String) -> String:
	if _cooldown > 0.0 or not LINES.has(kind):
		return ""
	var pool: Array = LINES[kind]
	# Never the same line twice running. With a pool of two that means
	# strict alternation, which is still better than repeating.
	var choices: Array = []
	for candidate: String in pool:
		if candidate != _last_line:
			choices.append(candidate)
	if choices.is_empty():
		choices = pool
	var picked: String = choices[randi() % choices.size()]
	_last_line = picked
	_cooldown = COOLDOWN
	return picked

## Drop the throttle — used when a Zone ends, so the first line of the next
## one is not swallowed by the tail of the last one's cooldown.
func reset() -> void:
	_cooldown = 0.0
	_last_line = ""
