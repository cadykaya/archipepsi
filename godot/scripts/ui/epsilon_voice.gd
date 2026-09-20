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
	"finale_open": [
		"Last one. I built this before I knew how you played. Sorry.",
		"This is the finale. I did not have long, and I only had you.",
		"Everything after this is bookkeeping. Enjoy the bookkeeping.",
	],
	## D3's completion beat. **WORDING NOT LOCKED** -- the owner decision
	## fixes the STRUCTURE (a short acknowledgement, then back to the Hub,
	## no cinematic and no forced credits) and leaves the words open. These
	## are placeholders in the established voice so the hook is exercised;
	## replacing them changes nothing but the text.
	"goal_sent": [
		"That is Check 030. It is somebody else's now.",
		"Sent. The last one I had to give you, and you took it properly.",
		"Done. I will keep the lights on while the others finish.",
	],
	## Fired once, when every Archipepsi Check is cleared. The Hub is
	## FINISHED BUT STILL ALIVE: Epsilon has run out of campaign to build,
	## not out of existence. **WORDING NOT LOCKED.**
	"campaign_complete": [
		"That is all thirty. I have nothing left to build you.",
		"Transmission complete. Stay as long as you like; I am not going anywhere.",
		"I am finished constructing this one. The multiworld is not finished with you.",
	],
	"finale_brute": [
		"That was the biggest thing I know how to make.",
		"It is down. Take Check 030 and go be somebody else's item.",
		"I have nothing bigger. I checked twice.",
	],
	"secret_found": [
		"You got up here. I did not leave anything. Read the wall.",
		"Nobody was supposed to reach that. Well. Nobody was required to.",
		"Every item in this campaign belongs to someone. This does not.",
		"There is no reward. There is a view. Take the view.",
	],
	"long_walk": [
		"Take your time. I have nowhere to be.",
		"I put something on a wall around here. Find it or do not.",
		"This corridor is longer than I remember specifying.",
	],

	# -- the Hub. Epsilon designed every Zone you have been through and
	# then had to wait here while you played them, which is most of its
	# personality. Same rules as everything above: each line reacts to
	# something already on screen, and none of them reads, reports or
	# could disagree with Archipelago about anything.
	"hub_arrived": [
		"You are back. I have been here the whole time. Obviously.",
		"Welcome to the room I did not design. It came with the building.",
		"Back already. I had barely finished being nervous about it.",
	],
	"hub_zone_done": [
		"That one went better than the draft. There was a draft.",
		"I have taken notes. You will not enjoy the notes.",
		"Another relay closed. Somebody, somewhere, got a parcel.",
		"I am told that counted. I am not told much.",
	],
	"hub_coins_idle": [
		"You are carrying coins. The kiosk is right there. It is lonely.",
		"Spending them is allowed. I checked the rules. I wrote the rules.",
		"Those coins do not appreciate in value. Nothing here does.",
	],
	"hub_key_landed": [
		"A Signal Key. That opens a tier, which opens a door I have not built yet.",
		"Key received. I will start worrying about the next one immediately.",
	],
	"hub_finale_ready": [
		"The finale is open. I would like it noted that I asked for more time.",
		"That is the last door. Everything past it is somebody else's game.",
	],
	"hub_idle": [
		"Take your time. I have literally nothing else scheduled.",
		"The board is over there. It has not changed since you last looked.",
		"I could design another one. I am going to anyway.",
		"There is a test chamber through the west wall. I built it for you. Mostly.",
	],
}

#: Events worth interrupting for. Everything else is ambient colour and
#: waits its turn. Without this, "died" set the six-second throttle and
#: the respawn 1.5 s later was always swallowed — the revival lines were
#: literally unreachable, and so was the payoff for reaching a secret if
#: anything at all had been said in the previous six seconds.
const PRIORITY := ["died", "revived", "secret_found",
		"finale_open", "finale_brute", "hub_key_landed",
		"hub_finale_ready",
		# D3: both fire once per campaign, at the two moments the player
		# most deserves an answer. Losing either to an ambient bark's
		# throttle would silently delete the ending.
		"goal_sent", "campaign_complete"]

#: Hub lines are ambient rather than reactive: nothing is trying to kill
#: you, so a bark every six seconds would be pestering rather than
#: commentary. `hub_idle` in particular waits this long between airings.
const HUB_IDLE_INTERVAL := 42.0

var _last_line := ""
var _cooldown := 0.0

func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

## Returns the line to show, or "" when Epsilon should stay quiet. Callers
## name the event; deciding whether it is worth saying is this object's job,
## so no caller has to carry its own throttle.
func line_for(kind: String) -> String:
	if not LINES.has(kind):
		return ""
	if _cooldown > 0.0 and not (kind in PRIORITY):
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
