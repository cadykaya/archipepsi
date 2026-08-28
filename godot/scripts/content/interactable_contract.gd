class_name InteractableContract
extends RefCounted
## What an interactable scene must provide, and what it must never show
## (v0.9 S17).
##
## An AP moment -- a Check going from locked to available to sent -- is
## the payoff the whole design is built around, and it is read off a
## pedestal in a room. So the presentation has two obligations, and they
## pull in opposite directions:
##
## 1. **Readable.** Every state must be distinguishable at a glance, from
##    across a room, without reading. Two states that look alike are a
##    player who does not know whether they claimed the thing.
## 2. **Silent about identity.** What a Check contains is not shown until
##    it is claimed.
##
## The second is already enforced where it matters most -- the bridge
## does not SEND item identity for an unrevealed location
## (`ScoutedLocation._unrevealed_withholds_identity`), so the client
## cannot print what it does not have. This file is the client-side half:
## the client legitimately knows some item names (a shop-stocked location
## is revealed), and a presentation that read `scout.item_name` without
## checking state would spoil exactly those.
##
## Nothing here draws anything. It says what a scene must contain and
## checks that what a scene produced obeys the rules, so an authored
## interactable can replace a procedural one under the S13 selection rule
## without the replacement quietly becoming a spoiler.

## The states an AP moment passes through, in order.
const STATES := ["locked", "available", "sending", "confirmed"]

## The only state in which item identity may be shown. Claiming is the
## reveal; everything before it is anticipation.
const IDENTITY_VISIBLE_IN := "confirmed"

## Named parts an interactable scene must provide. An authored scene that
## is missing one cannot be driven by the state machine, and would fail
## at the moment it changed state rather than at load.
const REQUIRED_PARTS := {
	"state_visual": "MeshInstance3D",  # recoloured per state
	"state_label": "Label3D",          # the words
}

## Parts the scene is missing, or whose type cannot serve the contract.
static func missing_parts(scene_root: Node) -> Array[String]:
	var out: Array[String] = []
	for part: String in REQUIRED_PARTS:
		var node := scene_root.find_child(part, true, false)
		if node == null or not node.is_class(REQUIRED_PARTS[part]):
			out.append(part)
	return out

## Whether `text` gives away what a Check holds, given what the client
## knows about it. Compares against the scout the client actually has, so
## it cannot be fooled by a label that happens to contain a word.
##
## Returns "" when the text is safe, or what it leaked.
static func leak(text: String, scout: Dictionary, state: String) -> String:
	if state == IDENTITY_VISIBLE_IN or scout.is_empty():
		return ""
	for field: String in ["item_name", "recipient_name"]:
		var secret := str(scout.get(field, ""))
		# A one- or two-character name cannot be matched safely: "Y" is a
		# legal AP item name and appears inside almost any sentence.
		if secret.length() > 2 and text.contains(secret):
			return "%s ('%s')" % [field, secret]
	return ""

## Whether two states can be told apart. Readability is the first
## obligation, and a state that shares BOTH its words and its colour with
## another is one the player cannot distinguish.
static func distinguishable(a_text: String, a_color: Color,
		b_text: String, b_color: Color) -> bool:
	return a_text != b_text or not a_color.is_equal_approx(b_color)
