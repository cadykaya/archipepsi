extends SceneTree
## A14 -- can the game's manipulation actually take Art's twelve props?
##
##   godot --path godot -s _harness/manipready.gd -- <models> <out.json>
##
## Batch 043 built twelve physics props around a stated rule: "A hand
## grip means a hand can lift it." That is a rule about HANDS. The game
## does not manipulate with hands. `Constants.MANIPULATE_VERBS` are HOLD,
## PULL and PUSH, performed by a force envelope -- `ENVELOPE_FORCE_N`
## newtons, `ENVELOPE_MASS_KG` kilograms, at up to `ENVELOPE_RANGE_M`
## metres -- and the envelope's limits are not a hand's.
##
## So this asks four questions of every prop, all of them with
## Production's own numbers and Production's own code:
##
## 1. **What class is it**, through their real `MassClass.of_mass`.
## 2. **Can the envelope HOLD it**: is its mass within `ENVELOPE_MASS_KG`.
## 3. **Can the envelope PUSH it**: `ENVELOPE_FORCE_N` against
##    `mu * m * g`, where `mu` is `ManipulableBody.envelope_friction()`'s
##    own derivation. Their comment records the engine measuring this the
##    hard way -- "700 N moved 120 kg by 0.00 m" under Godot's default
##    friction -- so the number is load-bearing and is computed, not
##    assumed.
## 4. **What `lightened` does to it**, through their real `MassClass.read`.
##    It is the ONE status `ECHO_STATUS_SUPPORTED_TARGETS` implements on
##    an `object`, so it is the only status any of these props can
##    actually carry.
##
## WHAT IT REFUSES TO ASSUME. Their ladder's three thresholds, the
## friction derivation and the gravity their bodies fall under are all
## required to still be what this harness thinks they are -- checked
## against their source text and their project file, not remembered. A
## threshold that has moved makes every answer below wrong in a way that
## would not show.

var _models: String
var _out: String
var _problems: Array[String] = []
var _notes: Array[String] = []
var _log := {}
var _mass_class: GDScript = null
var _force := 0.0
var _hold_kg := 0.0
var _range_m := 0.0
var _verbs: Array = []
var _gravity := 9.8
var _mu := 0.0
var _lightened_impulse := 0.0

## `ManipulableBody.envelope_friction()`, as they derive it. Required to
## still be in their file: this harness computes the same thing with the
## same inputs, and it is not entitled to keep doing that against a
## derivation they have changed.
const GRAZE_N := 0.5

const FRICTION_EXPR := \
	"FRICTION_HEADROOM * Constants.ENVELOPE_FORCE_N"

## `lightened` changes the CLASS and never the kilograms, and
## `receive_force` is deliberately UNSCALED -- their comment says so and
## says why. This harness reports that a lightened body is no easier to
## PUSH, which is only true while that line is still this line.
const UNSCALED_FORCE := "apply_central_force(force)"

## And the other half of the same distinction: an IMPULSE is scaled.
const IMPULSE_SCALED := "apply_central_impulse(impulse * impulse_scale())"

## `MassClass`'s ladder, Design 2 §10.2. THE VALUES ARE PINNED HERE AND
## THE HOME IS NOT.
##
## This used to require the literals `const LIGHT_BELOW := 30.0` and its
## two siblings verbatim in `mass_class.gd`, and on 2026-09-24 that
## refused a correct Production: the thresholds moved out of the file and
## into the generated `Constants` as `MASS_LIGHT_BELOW` and friends. The
## **values did not change** -- 30 / 120 / 400 either way -- so no art was
## stale and the only thing wrong was where this harness was looking.
##
## Following the value to the generated constants is also the better
## source: it is the schema-backed one, and a file that delegates cannot
## drift from it. So two assertions now, and they catch different things:
##
##   * `LADDER_VALUES` -- the numbers themselves, from `Constants`. If
##     Design 2 §10.2 is ever renumbered, every class boundary this lane
##     drew is stale and this is what says so.
##   * `LADDER_DELEGATES` -- that `mass_class.gd` still reads them from
##     `Constants` rather than holding its own copy. Two homes for one
##     number is how they come apart.
const LADDER_VALUES := {
	"MASS_LIGHT_BELOW": 30.0,
	"MASS_MEDIUM_BELOW": 120.0,
	"MASS_HEAVY_BELOW": 400.0,
}
const LADDER_DELEGATES := [
	"const LIGHT_BELOW := Constants.MASS_LIGHT_BELOW",
	"const MEDIUM_BELOW := Constants.MASS_MEDIUM_BELOW",
	"const HEAVY_BELOW := Constants.MASS_HEAVY_BELOW",
]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("[manipready] usage: -- <models-dir> <out.json>")
		quit(2)
		return
	_models = a[0]
	_out = a[1]
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[manipready] FAIL: %s" % what)


func _note(what: String) -> void:
	_notes.append(what)


func _run() -> void:
	if not _load_production():
		_finish()
		return
	_measure()
	_finish()


func _load_production() -> bool:
	var consts = load("res://_harness/prod_constants.gd")
	if consts == null:
		_fail("Production's constants.gd did not load.")
		return false
	for key: String in ["ENVELOPE_FORCE_N", "ENVELOPE_MASS_KG",
			"ENVELOPE_RANGE_M", "MANIPULATE_VERBS"]:
		if not key in consts:
			_fail(("Constants.%s is gone. Every limit below would " % key)
					+ "be computed from a default, which is worse than "
					+ "not computing it.")
			return false
	_force = float(consts.ENVELOPE_FORCE_N)
	_hold_kg = float(consts.ENVELOPE_MASS_KG)
	_range_m = float(consts.ENVELOPE_RANGE_M)
	_verbs = consts.MANIPULATE_VERBS

	var ladder := FileAccess.get_file_as_string(
			"res://_harness/prod_mass_class.gd")
	if ladder == "":
		_fail("Production's mass_class.gd did not load.")
		return false
	# READ FROM THE VERBATIM COPY, not the one the runner rewrote to
	# make it loadable here. Checking the rewritten text would be
	# checking this harness's own sed.
	var verbatim := FileAccess.get_file_as_string(
			"res://_harness/prod_mass_class_verbatim.gd")
	if verbatim == "":
		_fail("Production's mass_class.gd was not staged verbatim, so "
				+ "the ladder's delegation could not be read at all.")
		return false
	for line: String in LADDER_DELEGATES:
		if not verbatim.contains(line):
			_fail(("MassClass no longer declares `%s`. Either the ladder "
					+ "moved again or it has taken its own copy of a "
					+ "number that lives in Constants; both are worth "
					+ "stopping for.") % line)
			return false
	var ladder_source := FileAccess.get_file_as_string(
			"res://_harness/prod_constants.gd")
	if ladder_source == "":
		_fail("Production's constants.gd did not load, so the mass "
				+ "ladder's VALUES could not be checked at all -- and a "
				+ "run that checks nothing is not a PASS.")
		return false
	for name: String in LADDER_VALUES:
		var want: float = LADDER_VALUES[name]
		var want_text := "%s = %s" % [name, want]
		if not ladder_source.contains(want_text):
			_fail(("Constants no longer says `%s`. Design 2 section 10.2 "
					+ "has been renumbered, and every class boundary this "
					+ "lane drew against it is stale.") % want_text)
			return false
	_mass_class = load("res://_harness/prod_mass_class.gd") as GDScript
	if _mass_class == null:
		_fail("Production's mass_class.gd did not parse.")
		return false

	var body := FileAccess.get_file_as_string(
			"res://_harness/prod_manipulable_body.gd")
	if body == "":
		_fail("Production's manipulable_body.gd did not load.")
		return false
	for claim: Array in [[UNSCALED_FORCE, "receive_force applies its "
				+ "newtons unscaled, so `lightened` does not help a push"],
			[IMPULSE_SCALED, "receive_impulse scales by impulse_scale(), "
				+ "so `lightened` doubles what one shove does"]]:
		if not body.contains(str(claim[0])):
			_fail(("ManipulableBody no longer contains `%s`. " % claim[0])
					+ "This harness reports that " + str(claim[1])
					+ " -- a claim it is not entitled to keep making "
					+ "about code they have changed.")
			return false
	if not body.contains(FRICTION_EXPR):
		_fail("ManipulableBody no longer derives its friction as `%s "
				% FRICTION_EXPR + "/ (ENVELOPE_MASS_KG * gravity())`. "
				+ "The push limit computed below would be against a "
				+ "coefficient they have replaced.")
		return false
	# `manipulable_body.gd` is read as TEXT and never parsed. Parsing it
	# would drag `MassClass`, `StatusEffects` and a RigidBody3D behind
	# it, and the only thing needed from it is one constant and one
	# expression -- so the constant's own declaration is found and its
	# right-hand side evaluated, which is the same number without
	# standing up half their gameplay to get it.
	var headroom := 0.0
	for line: String in body.split("\n"):
		if not line.strip_edges().begins_with("const FRICTION_HEADROOM"):
			continue
		var rhs := line.split(":=")[1].strip_edges()
		var expr := Expression.new()
		if expr.parse(rhs) == OK:
			headroom = float(expr.execute())
	if headroom <= 0.0:
		_fail("ManipulableBody no longer declares FRICTION_HEADROOM as "
				+ "a constant expression, so the coefficient this "
				+ "harness would push with is not theirs.")
		return false

	# THE GRAVITY THEIR BODIES FALL UNDER, not this project's.
	# `ManipulableBody.gravity()` reads `physics/3d/default_gravity` from
	# ProjectSettings and falls back to 9.8. Reading it HERE would read
	# the ART project's setting, which is a different project; so their
	# project file is fetched and parsed, and the fallback is used only
	# when they really do not set it.
	var proj := FileAccess.get_file_as_string("res://_harness/prod_project")
	if proj == "":
		_fail("Production's project.godot did not load, so the gravity "
				+ "their bodies fall under is unknown.")
		return false
	for line: String in proj.split("\n"):
		if line.begins_with("physics/3d/default_gravity="):
			_gravity = float(line.split("=")[1])
	for line: String in body.split("\n"):
		if line.strip_edges().begins_with("const LIGHTENED_IMPULSE"):
			_lightened_impulse = float(line.split(":=")[1].strip_edges())
	if _lightened_impulse <= 0.0:
		_fail("ManipulableBody.LIGHTENED_IMPULSE did not read.")
		return false
	_mu = headroom * _force / (_hold_kg * _gravity)

	_log["production"] = {
		"envelope_force_n": _force,
		"envelope_mass_kg": _hold_kg,
		"envelope_range_m": _range_m,
		"manipulate_verbs": _verbs,
		"friction_headroom": headroom,
		"gravity": _gravity,
		"envelope_friction": _mu,
		"lightened_impulse_scale": _lightened_impulse,
		"push_limit_kg": _force / (_mu * _gravity),
		"source": "Constants, MassClass and ManipulableBody, read-only",
	}
	return true


## Their `MassClass.read` asks a status container exactly one question.
## This answers that one question and nothing else -- it is not a stand-in
## for `StatusEffects`, and the runner binds it under a name that says so.
func _carrying(kind: String) -> Object:
	var stub: Object = load("res://_harness/one_status.gd").new()
	stub.set("kind", kind)
	return stub


func _measure() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch043/physics/manifest.json" % _models)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("no batch043 physics manifest at %s" % _models)
		return
	var manifest: Dictionary = parsed
	var rows := {}
	var gripped_beyond_hold: Array = []
	var envelope_undeclared: Array = []
	var holdable_without_grip: Array = []
	for id: String in manifest:
		var prop: Dictionary = manifest[id]
		var mass := float(prop.get("mass_kg", 0.0))
		if mass <= 0.0:
			_fail("%s declares no mass_kg, so nothing about how it can "
					% id + "be manipulated can be answered.")
			continue
		var plain: String = _mass_class.of_mass(mass, true)
		var lightened: String = _mass_class.read(
				mass, true, _carrying("lightened"))
		var anchored: String = _mass_class.read(
				mass, true, _carrying("anchored"))
		var push_force := _mu * mass * _gravity
		var parts: Array = prop.get("parts", [])
		var grips: Array = []
		var attaches: Array = []
		for raw: Variant in parts:
			var part := str(raw)
			if part.begins_with("grip"):
				grips.append(part)
			elif part.begins_with("attach"):
				attaches.append(part)
		var can_hold := mass <= _hold_kg
		# THREE-VALUED, because `phys_cart` lands on the limit exactly:
		# 180 kg x mu x g is 700 N against 700 N of envelope, and in
		# floating point that comes out a hair over. Forcing a tie into
		# "no" would report a rounding error as a design fact -- the
		# same mistake `skiff_sweep` made when it called a tangency an
		# intrusion "by 0.000 m". GRAZE_N is half a newton, which is
		# nothing beside 700 and far more than the arithmetic.
		var can_push := "yes"
		if push_force > _force + GRAZE_N:
			can_push = "no"
		elif push_force > _force - GRAZE_N:
			can_push = "at the limit"
		# THE CROSS-LANE GATE. Art's exporter derives `mass_class` from
		# Design 2 §10.2's thresholds, transcribed into
		# `build_physics_props.py`. Production derives it in
		# `MassClass.of_mass` from the same section. Two transcriptions
		# of one table is exactly the arrangement that drifts, so the
		# export's answer is checked against theirs on every run.
		var declared := str(prop.get("mass_class", "")).to_lower()
		if declared == "":
			_fail("%s exports no mass_class." % id)
		elif declared != plain:
			_fail(("%s exports mass_class %s; MassClass.of_mass(%.0f, "
					% [id, declared.to_upper(), mass])
					+ "%s) says %s. Two transcriptions of Design 2 "
					% [str(prop.get("manipulable", true)), plain.to_upper()]
					+ "§10.2 have drifted apart.")

		# And the ENVELOPE verdict, which the exporter declares because
		# the art is SHAPED by it -- which fitting a prop wears depends
		# on it -- and which is therefore Art's transcription of
		# Production's numbers, verified here against those numbers.
		var env: Dictionary = prop.get("envelope", {})
		if not env.is_empty():
			if bool(env.get("hold", false)) != can_hold:
				_fail("%s declares hold=%s; %.0f kg against the "
						% [id, str(env.get("hold")), mass]
						+ "envelope's %.0f kg says %s."
						% [_hold_kg, str(can_hold)])
			if str(env.get("push", "")) != can_push:
				_fail("%s declares push='%s'; %.1f N against the "
						% [id, str(env.get("push", "")), push_force]
						+ "envelope's %.0f N says '%s'."
						% [_force, can_push])
		else:
			envelope_undeclared.append(id)

		rows[id] = {
			"mass_kg": mass,
			"class": plain,
			"class_lightened": lightened,
			"class_anchored": anchored,
			"hold": can_hold,
			"push": can_push,
			"push_force_n": push_force,
			"grips": grips.size(),
			"attaches": attaches.size(),
		}
		if not grips.is_empty() and not can_hold:
			gripped_beyond_hold.append("%s (%.0f kg)" % [id, mass])
		if grips.is_empty() and can_hold:
			holdable_without_grip.append("%s (%.0f kg)" % [id, mass])
	_log["props"] = rows

	# THE FINDING, REPORTED AND NOT REFUSED.
	#
	# Batch 043's rule was "a hand grip means a hand can lift it", and by
	# that rule every one of these is correct: a hand does not lift a
	# 95 kg girder. The envelope does. Failing the props here would be
	# failing them against a rule they were not built to, which is how a
	# gate gets switched off -- so the disagreement is measured and
	# handed over, and what to do about it is the handoff's question.
	if not gripped_beyond_hold.is_empty():
		_note("carries a hand grip and is beyond the envelope's "
				+ "%.0f kg HOLD limit: " % _hold_kg
				+ ", ".join(gripped_beyond_hold))
	if not holdable_without_grip.is_empty():
		_note("within the envelope's HOLD limit and carries no grip: "
				+ ", ".join(holdable_without_grip))
	# THE ONE HARD RULE ABOUT THE FAMILY ITSELF. These twelve exist to
	# make the mass ladder legible; a ladder with an empty rung is a
	# ladder a player cannot learn. It bites if a prop's mass changes or
	# if Production moves a threshold under it.
	var occupied := {}
	for id: String in rows:
		occupied[rows[id]["class"]] = true
	for rung: String in ["light", "medium", "heavy", "fixed"]:
		if not occupied.has(rung):
			_fail(("no prop in the family reads as %s. " % rung)
					+ "The twelve exist to make the ladder legible and "
					+ "a rung with nothing on it teaches nothing.")

	if not envelope_undeclared.is_empty():
		_note("declares no `envelope` verdict, so what the field can do "
				+ "with it is not in the export: "
				+ ", ".join(envelope_undeclared))

	var by_class := {}
	for id: String in rows:
		var k: String = rows[id]["class"]
		by_class[k] = int(by_class.get(k, 0)) + 1
	_note("class spread: " + str(by_class))
	var moved := []
	for id: String in rows:
		if rows[id]["class_lightened"] != rows[id]["class"]:
			moved.append("%s %s->%s" % [id, rows[id]["class"],
					rows[id]["class_lightened"]])
	_note("`lightened` moves %d of %d: " % [moved.size(), rows.size()]
			+ ", ".join(moved))


func _finish() -> void:
	# A RUN THAT MEASURED NOTHING IS NOT A PASS. A GDScript fault inside
	# the loop below aborts the frame without aborting the harness, and
	# the first version of this file printed "PASS -- 0 prop(s)" on
	# exactly that. `godot_run.sh` caught it by the SCRIPT ERROR, which
	# is the belt; this is the braces.
	var measured: Dictionary = _log.get("props", {})
	if _problems.is_empty() and measured.is_empty():
		_fail("no prop was measured at all. Whatever this run did, it "
				+ "did not check the twelve props against the envelope.")
	_log["problems"] = _problems
	_log["notes"] = _notes
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[manipready] PASS -- %d prop(s) measured against the "
				% (_log.get("props", {}) as Dictionary).size()
				+ "envelope's own limits; %d note(s)" % _notes.size())
		quit(0)
	else:
		printerr("[manipready] %d problem(s)" % _problems.size())
		quit(1)
