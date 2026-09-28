extends SceneTree
## A13 -- is the Batch 043 status kit READY for the runtime that exists?
##
##   godot --path godot -s _harness/statusready.gd -- <kit-dir> <out.json>
##
## Batch 043 drew thirteen Statuses and eight compounds from Design 6
## §15.2 and checked every example against §15.2's OWN target lists. That
## is the right check against the design. It is not a check against the
## engine, and the two turn out to name different statuses.
##
## `StatusEffects.apply` refuses in three places, in this order:
##
##   1. the kind is not in `Constants.ECHO_STATUS_KINDS`         -- unknown
##   2. `ECHO_STATUS_SUPPORTED_TARGETS` has no entry for it      -- designed,
##      ...their words: "NO STATUS BEFORE ITS EFFECT."              not built
##   3. the container's `side` is not in that entry              -- wrong target
##
## So a marker is only ever seen if the kind clears all three. This asks,
## for every glyph Art drew, whether it would.
##
## FOUR THINGS IT REFUSES TO DO, each of which would make it worthless:
##
## * It does not restate their constants. It loads their real
##   `constants.gd`, fetched read-only by the runner.
## * It does not restate their guards either. It reads their real
##   `status_effects.gd` and REQUIRES the three conditions above to still
##   be in it, verbatim. A guard Production rewrites is a guard this
##   harness is no longer entitled to check for them.
## * It does not translate between the two target vocabularies from
##   memory. The map lives in `status_kit.json` as data, and both of its
##   sides are checked against their sources.
## * It does not fail the kit for drawing the DESIGN. A glyph whose design
##   targets are wider than today's runtime support is correct art ahead
##   of a staged runtime, and it is reported as a note. Only a claim about
##   the RUNTIME that is wrong about the runtime is a failure.

var _kit_dir: String
var _out: String
var _kit := {}
var _kinds: Array = []
var _implemented: Array = []
var _targets := {}
var _cleanse := {}
var _problems: Array[String] = []
var _notes: Array[String] = []
var _log := {}

## The three refusals, as `status_effects.gd` spells them. Each is one or
## more SUBSTRINGS of their source, ALL required to be found there.
##
## Re-read at Production `d82a36e` ("H-STATUS slice 2"), which moved the
## supported-targets table into a member so its tests can substitute it.
## The runtime default is still the generated constant, so the guard is
## the same rule; it is pinned as three parts now -- the member's source,
## the lookup through it, and the refusal itself, which the one-line pin
## this replaced never required at all.
const GUARDS := {
	"unknown kind":
		["if not kind in Constants.ECHO_STATUS_KINDS:"],
	"designed but unimplemented":
		["var supported: Dictionary = Constants.ECHO_STATUS_SUPPORTED_TARGETS",
		 "var targets: Array = supported.get(kind, [])",
		 "if targets.is_empty():"],
	"unsupported target":
		["if not side in targets:"],
}

## The five target kinds Amalgam §15.1 names, as `status_effects.gd`'s own
## comment lists them. Required to be found, for the same reason.
const SIDES_COMMENT := "`self`, `enemy`, `object`, `surface`, `volume`"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("[statusready] usage: -- <kit-dir> <out.json>")
		quit(2)
		return
	_kit_dir = a[0]
	_out = a[1]
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[statusready] FAIL: %s" % what)


func _note(what: String) -> void:
	_notes.append(what)


func _run() -> void:
	if not _load_production():
		_finish()
		return
	if not _load_kit():
		_finish()
		return
	_check_vocabularies()
	_check_coverage()
	_check_claims()
	_finish()


## ---------------------------------------------------------------- inputs

func _load_production() -> bool:
	var consts = load("res://_harness/prod_constants.gd")
	if consts == null:
		_fail("Production's constants.gd did not load at all.")
		return false
	# KEY-SHAPE FIRST. A10 taught this the hard way: a harness that reads
	# a key that is not there reports nothing and still prints PASS. If a
	# constant has been renamed, this stops rather than checking air.
	for key: String in ["ECHO_STATUS_KINDS", "ECHO_STATUS_KINDS_IMPLEMENTED",
			"ECHO_STATUS_SUPPORTED_TARGETS"]:
		if not key in consts:
			_fail(("Constants.%s is gone. Every check below would " % key)
					+ "pass on an empty list, which is worse than not "
					+ "running them.")
			return false
	_kinds = consts.ECHO_STATUS_KINDS
	_implemented = consts.ECHO_STATUS_KINDS_IMPLEMENTED
	_targets = consts.ECHO_STATUS_SUPPORTED_TARGETS
	if _kinds.is_empty() or _implemented.is_empty() or _targets.is_empty():
		_fail("one of the three status constants loaded EMPTY.")
		return false

	var source := FileAccess.get_file_as_string(
			"res://_harness/prod_status_effects.gd")
	if source == "":
		_fail("Production's status_effects.gd did not load. The guards "
				+ "this harness checks on their behalf cannot be "
				+ "confirmed to still exist.")
		return false
	for label: String in GUARDS:
		for part: String in GUARDS[label]:
			if not source.contains(part):
				_fail(("StatusEffects.apply no longer contains its '%s' "
						% label) + "guard:\n      %s\n    " % part
						+ "This harness checks that rule on Production's "
						+ "behalf and is not entitled to keep checking a "
						+ "rule they have rewritten. Re-read apply().")
				return false
	if not source.contains(SIDES_COMMENT):
		_fail("status_effects.gd no longer names §15.1's five target "
				+ "kinds as " + SIDES_COMMENT + ", so the vocabulary "
				+ "this harness translates into is unconfirmed.")
		return false

	# Their cleanse order, read from their own script rather than copied.
	var effects := load("res://_harness/prod_status_effects.gd") as GDScript
	if effects != null:
		var map: Dictionary = effects.get_script_constant_map()
		if map.has("_CLEANSE_ORDER"):
			_cleanse = map["_CLEANSE_ORDER"]
	if _cleanse.is_empty():
		_note("StatusEffects._CLEANSE_ORDER did not load; the "
				+ "'watched disappear' note below is not reported.")
	_log["source"] = {
		"constants": "Constants.ECHO_STATUS_* read-only, not restated",
		"guards": "StatusEffects.apply, verified present verbatim",
		"kinds": _kinds.size(),
		"implemented": _implemented.size(),
		"supported_targets": _targets.size(),
	}
	return true


func _load_kit() -> bool:
	var text := FileAccess.get_file_as_string(
			"%s/status_kit.json" % _kit_dir)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("no status_kit.json at %s" % _kit_dir)
		return false
	_kit = parsed
	for key: String in ["glyphs", "markers", "target_vocabularies"]:
		if not _kit.has(key):
			_fail("status_kit.json has no '%s'. This harness compares the "
					% key + "kit's own declarations against Production; "
					+ "it cannot compare a field that is absent.")
			return false
	return true


## ------------------------------------------------------- the vocabularies

## Art's kit speaks §15.2's target words -- `actor`, `player`, `object`,
## `surface`, `volume`. `StatusEffects` speaks §15.1's -- `self`, `enemy`,
## `object`, `surface`, `volume`. They partition actors differently: the
## design says WHAT a target is, the runtime says WHOSE it is.
##
## A map between them that lives only in a reader's head is not a map, so
## the kit declares one and this checks BOTH of its sides: every word Art
## uses must be in the design column, and every word it lands on must be
## one the runtime actually names.
func _check_vocabularies() -> void:
	var vocab: Dictionary = _kit["target_vocabularies"]
	for key: String in ["design", "runtime", "maps_to"]:
		if not vocab.has(key):
			_fail("target_vocabularies has no '%s'" % key)
			return
	var design: Array = vocab["design"]
	var runtime: Array = vocab["runtime"]
	var maps: Dictionary = vocab["maps_to"]

	# The runtime column is checkable against the runtime.
	var seen := {}
	for kind: String in _targets:
		for side: String in _targets[kind]:
			seen[side] = true
	for side: String in seen:
		if not side in runtime:
			_fail(("ECHO_STATUS_SUPPORTED_TARGETS uses target '%s', "
					% side) + "which the kit's runtime vocabulary does "
					+ "not list. The map is out of date with the engine.")

	# Every design word Art actually uses must be mapped, and must land
	# somewhere the runtime names.
	var used := {}
	for glyph: Dictionary in _kit["glyphs"]:
		for side: String in glyph.get("targets", []):
			used[side] = true
	for side: String in used:
		if not side in design:
			_fail("a glyph declares design target '%s', which the "
					% side + "kit's own design vocabulary does not list.")
			continue
		if not maps.has(side):
			_fail("design target '%s' has no entry in maps_to, so a "
					% side + "claim made with it cannot be compared to "
					+ "the runtime at all.")
			continue
		if not str(maps[side]) in runtime:
			_fail(("maps_to['%s'] is '%s', which is not a runtime "
					% [side, maps[side]]) + "target kind.")
	_log["vocabularies"] = {
		"design_used": used.keys(),
		"runtime_seen": seen.keys(),
		"maps_to": maps,
	}


## ---------------------------------------------------------- the coverage

## THE ONE THAT FOUND SOMETHING.
##
## `ECHO_STATUS_KINDS` is closed and `apply()` refuses anything outside
## it, so it is the complete set of statuses a player can ever be shown.
## A kind in it with no marker is a condition the game can put on a target
## with nothing on screen to say so.
func _check_coverage() -> void:
	var glyph_ids := {}
	var compounds: Array = []
	for glyph: Dictionary in _kit["glyphs"]:
		var id := str(glyph.get("id", "")).trim_prefix("glyph_")
		glyph_ids[id] = glyph
		if str(glyph.get("family", "")) == "COMPOUND":
			compounds.append(id)
	var marker_ids := {}
	for marker: Dictionary in _kit["markers"]:
		marker_ids[str(marker.get("id", "")).trim_prefix("marker_")] = true

	var missing: Array = []
	var missing_marker: Array = []
	for kind: String in _kinds:
		if not glyph_ids.has(kind):
			missing.append(kind)
		elif not marker_ids.has(kind):
			missing_marker.append(kind)
	if not missing.is_empty():
		_fail(("%d of the %d kinds in Constants.ECHO_STATUS_KINDS have "
				% [missing.size(), _kinds.size()])
				+ "no glyph: " + ", ".join(missing)
				+ ". The vocabulary is CLOSED -- apply() refuses "
				+ "anything outside it -- so these are conditions the "
				+ "game can apply with nothing on screen to say so.")
	if not missing_marker.is_empty():
		_fail("drawn but with no marker: " + ", ".join(missing_marker))

	# A glyph naming neither a status kind nor a declared compound is the
	# same typo apply()'s first guard exists to catch.
	var stray: Array = []
	for id: String in glyph_ids:
		if id in _kinds:
			continue
		if id in compounds:
			continue
		stray.append(id)
	if not stray.is_empty():
		_fail("glyph(s) naming nothing in ECHO_STATUS_KINDS and not "
				+ "declared COMPOUND: " + ", ".join(stray))

	# Reported, not failed: which of the drawn kinds the runtime can
	# actually raise today, and which are drawings of a staged design.
	var live: Array = []
	var staged: Array = []
	for kind: String in _kinds:
		if kind in _implemented:
			live.append(kind)
		else:
			staged.append(kind)
	_note("%d of %d kinds have a runtime effect today; %d are drawings "
			% [live.size(), _kinds.size(), staged.size()]
			+ "of a staged design and apply() refuses them with NO "
			+ "STATUS BEFORE ITS EFFECT: " + ", ".join(staged))

	# Which ones a player will watch a cleanse remove -- the markers that
	# have to read while they are vanishing, not just while they are on.
	for side: String in _cleanse:
		var undrawn: Array = []
		for kind: String in _cleanse[side]:
			if not glyph_ids.has(kind):
				undrawn.append(kind)
		if undrawn.is_empty():
			_note("every status _CLEANSE_ORDER['%s'] removes is drawn."
					% side)
		else:
			_note("_CLEANSE_ORDER['%s'] removes undrawn statuses: "
					% side + ", ".join(undrawn))
	_log["coverage"] = {
		"kinds": _kinds.size(), "drawn": glyph_ids.size() - compounds.size(),
		"compounds": compounds.size(), "implemented": live,
		"staged": staged, "missing_glyph": missing,
	}


## ------------------------------------------------------------- the claims

## What the kit SAYS about the runtime has to be true about the runtime.
## What it says about the design is the design's business, and a glyph
## drawn wider than a staged runtime is correct art, not a defect.
func _check_claims() -> void:
	var vocab: Dictionary = _kit["target_vocabularies"]
	var maps: Dictionary = vocab["maps_to"]
	var rows := {}
	for glyph: Dictionary in _kit["glyphs"]:
		var id := str(glyph.get("id", "")).trim_prefix("glyph_")
		if not id in _kinds:
			continue
		var want: Array = _targets.get(id, [])
		if not glyph.has("runtime_targets"):
			_fail("glyph %s does not declare runtime_targets. Whether "
					% id + "its marker can ever appear is then a "
					+ "question the kit does not answer.")
			continue
		var said: Array = glyph["runtime_targets"]
		var said_sorted := said.duplicate()
		said_sorted.sort()
		var want_sorted := want.duplicate()
		want_sorted.sort()
		if said_sorted != want_sorted:
			_fail(("glyph %s declares runtime_targets %s; "
					% [id, str(said_sorted)])
					+ "ECHO_STATUS_SUPPORTED_TARGETS says %s."
					% str(want_sorted))

		# The design's own claim, translated, against today's support.
		var refused: Array = []
		for side: String in glyph.get("targets", []):
			var runtime_side := str(maps.get(side, ""))
			if runtime_side == "":
				continue
			if not runtime_side in want:
				refused.append("%s (%s)" % [side, runtime_side])
		rows[id] = {
			"design_targets": glyph.get("targets", []),
			"runtime_targets": want,
			"refused_today": refused,
			"implemented": id in _implemented,
		}
		if refused.is_empty():
			continue
		if want.is_empty():
			continue    # already covered by the staged note above
		_note(("%s is drawn for %s, and apply() refuses it on %s today."
				% [id, str(glyph.get("targets", [])), ", ".join(refused)])
				+ " That is the staged runtime, not a wrong drawing.")
	_log["claims"] = rows


func _finish() -> void:
	_log["problems"] = _problems
	_log["notes"] = _notes
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[statusready] PASS -- every kind apply() admits is drawn, "
				+ "and every runtime claim matches the runtime; "
				+ "%d note(s)" % _notes.size())
		quit(0)
	else:
		printerr("[statusready] %d problem(s)" % _problems.size())
		quit(1)
