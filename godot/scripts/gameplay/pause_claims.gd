class_name PauseClaims
extends RefCounted
## H-PAUSE: WHO IS HOLDING THE WORLD STILL (`04_3D_MENU_MAP_AND_GLYPH.md`
## §4, "pause is a world boundary, not an input hold").
##
## `SceneTree.paused` is one boolean, and a boolean has no owners: the
## second thing to pause the world would set it running again when it let
## go, with the first still open. So a pause is a named claim, as the
## player's input holds are (`Player.hold`), and the world runs again only
## when nobody holds one.
##
## **What a paused world is here.** Every node that has not said otherwise
## stops: the dungeon, its AI, projectiles, machinery, cooldowns, and the
## lifetimes of temporary effects, whose SceneTree timers are created to
## pause with it. The physics server stops with the tree. What keeps
## running says so with `PROCESS_MODE_ALWAYS`: the pause interface itself
## (`MenuShell`) and the bridge client -- the AP world is not paused, so
## the connection and anything legitimately delivered stay live.

static var _claims := {}


static func claim(tree: SceneTree, owner: String) -> void:
	_claims[owner] = true
	tree.paused = true


static func release(tree: SceneTree, owner: String) -> void:
	_claims.erase(owner)
	tree.paused = not _claims.is_empty()


static func held_by(owner: String) -> bool:
	return _claims.has(owner)


static func owners() -> Array:
	return _claims.keys()
