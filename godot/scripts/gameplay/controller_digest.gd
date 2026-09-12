class_name ControllerDigest
extends RefCounted

## WHAT THIS BUILD DOES WHEN YOU PRESS DASH, as sixteen hex characters.
##
## `AP_CAPABILITY_LOGIC.md` §8b-ANSWERED. `SceneDigest` says what a
## replay ran AGAINST; this says what ran. They are different questions
## and the physics package's `scene_digest` does not answer this one:
## change `EchoRuntime._dash` from adding to velocity to replacing it and
## every crossing in a movement table moves while the scene digest of the
## measurement platform stays byte-identical.
##
## **The source of the movement scripts is in it, and that is the half
## that matters.** A constants-only digest is a digest of the numbers
## somebody remembered to list. `player.gd` and `echo_runtime.gd` are
## hashed whole, so a change to the CODE invalidates a measurement the
## same way a change to `WALK_SPEED` does.
##
## **One per build, not one per session.** The thing identified is what
## this executable does, which does not vary within a build; a
## per-session id would make two measurements of the same build
## incomparable, which is the opposite of what the comparison is for.
##
## Opaque to the bridge, which has no controller and no physics frame,
## exactly as `scene_digest` is.

## Bumped BY HAND when what this covers changes shape.
const GENERATOR_VERSION := 1

## The scripts whose BODY decides how far a body goes. Named rather than
## discovered: a glob would silently start or stop covering a file and a
## digest that changes for a reason nobody can name is worse than none.
const MOVEMENT_SCRIPTS := [
	"res://scripts/gameplay/player.gd",
	"res://scripts/gameplay/echo_runtime.gd",
]

## COMPUTED ONCE. "One per build" is the claim §8b makes, so it is a
## cached value rather than a function that happens to return the same
## thing -- and `text()` builds a `Player` to read its `floor_max_angle`,
## which is not something to do on every Zone entry.
static var _cached := ""

static func digest() -> String:
	if _cached == "":
		_cached = text().sha256_text().substr(0, 16)
	return _cached

## The string that gets hashed, so a test can say WHICH field moved
## rather than only that sixteen characters differ.
static func text() -> String:
	var lines: Array[String] = []
	lines.append("version generator=%d godot=%s.%s.%s.%s backend=%s"
			% [GENERATOR_VERSION,
				Engine.get_version_info().get("major", 0),
				Engine.get_version_info().get("minor", 0),
				Engine.get_version_info().get("patch", 0),
				str(Engine.get_version_info().get("status", "?")),
				str(ProjectSettings.get_setting(
						"physics/3d/physics_engine", "DEFAULT"))])
	lines.append("tick %d" % Engine.physics_ticks_per_second)
	lines.append("gravity %s %s"
			% [_num(ProjectSettings.get_setting(
					"physics/3d/default_gravity", 9.8)),
				_vec(ProjectSettings.get_setting(
					"physics/3d/default_gravity_vector", Vector3.DOWN))])
	# THE BODY, which is half of what a lip clears. Read off a real
	# `Player` rather than off the engine default, because a project
	# that sets `floor_max_angle` on the body would otherwise be
	# digested as one that did not.
	var body := Player.create()
	lines.append("capsule height=%s radius=%s floor_max_angle=%s"
			% [_num(Constants.PLAYER_HEIGHT),
				_num(Constants.PLAYER_RADIUS),
				_num(body.floor_max_angle)])
	body.free()
	# THE CONSTANTS THE CONTROLLER READS, named so a reader can see what
	# is covered, sorted so the order of a Dictionary cannot move a
	# digest nothing changed about. Movement only: `PLAYER_MAX_HP` and
	# the pulse numbers are read by the same script and decide nothing
	# about how far a body goes.
	var constants := {
		"AIR_CONTROL": Constants.AIR_CONTROL,
		"COYOTE_TIME": Constants.COYOTE_TIME,
		"GRAVITY": Constants.GRAVITY,
		"JUMP_BUFFER": Constants.JUMP_BUFFER,
		"JUMP_VELOCITY": Constants.JUMP_VELOCITY,
		"LAUNCH_CORRECTION_SPEED": Constants.LAUNCH_CORRECTION_SPEED,
		"MAX_VERTICAL_STEP": Constants.MAX_VERTICAL_STEP,
		"WALK_SPEED": Constants.WALK_SPEED,
	}
	var names: Array[String] = []
	for key: String in constants:
		names.append(key)
	names.sort()
	for key: String in names:
		lines.append("const %s=%s" % [key, _num(float(constants[key]))])
	# AND THE SCRIPTS THEMSELVES.
	for path: String in MOVEMENT_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		lines.append("source %s=%s"
				% [path, "MISSING" if source == ""
					else source.sha256_text().substr(0, 16)])
	return "\n".join(lines)

static func _num(x: float) -> String:
	return "%.4f" % x

static func _vec(v: Vector3) -> String:
	return "%s,%s,%s" % [_num(v.x), _num(v.y), _num(v.z)]
