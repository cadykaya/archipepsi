class_name PhysicsPackage
extends RefCounted

## THE ENGINE'S HALF OF THE PACKAGE DIGEST.
##
## `bridge/archipepsi_bridge/schemas/physics.py` is the other half. The
## two lanes must build the same bytes from the same package, because
## `package_digest` is what a replay's evidence is filed under: the
## engine computes it over the package it is about to replay, the bridge
## recomputes it over the package it is about to accept, and a
## disagreement means evidence about one thing read as evidence about
## another.
##
## **CONSTRUCTED, NEVER COPIED.** `physics_digest_vectors.json` carries a
## `canonical` string beside every package, and hashing that string would
## prove the file is self-consistent and nothing whatever about this
## code. Everything here is built from `package` and serialized by this
## file, so a serializer that drifts is a serializer that fails.
##
## This is level 1 of three (`docs/AMALGAM_BRIDGE.md` §6.2b): the two
## lanes agree about bytes. It says nothing about whether `scene_digest`
## describes a real scene, and nothing at all about whether any of it
## can be replayed -- there is no physics runtime yet.

## A latch condition, as far as the digest reasons about one.
class LatchCondition extends RefCounted:
	var latch_id := ""
	var kind := ""
	var detail := ""

## A manipulable body.
class BodySpec extends RefCounted:
	var body_id := ""
	var mass_kg := 0.0
	var constrained := false

## The solver settings a replay ran under.
class SolverConfig extends RefCounted:
	var iterations := 0
	var fixed_step_hz := 0.0
	var settle_timeout_s := 0.0

## The bodies and solver a package's solution is authored against.
class PhysicsSetup extends RefCounted:
	var bodies: Array[BodySpec] = []
	var solver: SolverConfig = null
	var scene_digest := ""

var package_id := ""
var latch_conditions: Array[LatchCondition] = []
var vector_latches: Array[int] = []
var required_latches: Array[String] = []
var on_mandatory_route := false
var setup: PhysicsSetup = null
## Null when the package declares no reference solution, which is not the
## same as an empty list of steps -- the canonical form writes `null` for
## one and `[]` for the other.
var reference_solution: Array[String] = []
var has_reference_solution := false

## The keys each object may carry, so a field this lane does not model is
## REFUSED rather than silently dropped out of the digest. The bridge's
## models are `extra="forbid"`; a producer that quietly ignores a new
## field would compute a digest over less than the bridge hashes, and the
## two would disagree about a package neither could name.
const PACKAGE_KEYS := ["package_id", "latch_conditions", "vector_latches",
		"required_latches", "on_mandatory_route", "setup",
		"reference_solution"]
const LATCH_KEYS := ["latch_id", "kind", "detail"]
const BODY_KEYS := ["body_id", "mass_kg", "constrained"]
const SOLVER_KEYS := ["iterations", "fixed_step_hz", "settle_timeout_s"]
const SETUP_KEYS := ["bodies", "solver", "scene_digest"]
const SOLUTION_KEYS := ["steps"]

## Builds a package, or returns null and appends why to `errors`.
static func from_dict(raw: Dictionary,
		errors: Array[String]) -> PhysicsPackage:
	var out := PhysicsPackage.new()
	_forbid_extra(raw, PACKAGE_KEYS, "package", errors)
	out.package_id = str(raw.get("package_id", ""))
	for entry: Variant in raw.get("latch_conditions", []):
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("a latch_condition is not an object")
			continue
		var spec: Dictionary = entry
		_forbid_extra(spec, LATCH_KEYS, "latch_condition", errors)
		var latch := LatchCondition.new()
		latch.latch_id = str(spec.get("latch_id", ""))
		latch.kind = str(spec.get("kind", ""))
		latch.detail = str(spec.get("detail", ""))
		out.latch_conditions.append(latch)
	for index: Variant in raw.get("vector_latches", []):
		out.vector_latches.append(int(index))
	for name: Variant in raw.get("required_latches", []):
		out.required_latches.append(str(name))
	out.on_mandatory_route = bool(raw.get("on_mandatory_route", false))
	var setup_raw: Variant = raw.get("setup")
	if typeof(setup_raw) == TYPE_DICTIONARY:
		var spec: Dictionary = setup_raw
		_forbid_extra(spec, SETUP_KEYS, "setup", errors)
		var built := PhysicsSetup.new()
		built.scene_digest = str(spec.get("scene_digest", ""))
		for entry: Variant in spec.get("bodies", []):
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("a body is not an object")
				continue
			var body_raw: Dictionary = entry
			_forbid_extra(body_raw, BODY_KEYS, "body", errors)
			var body := BodySpec.new()
			body.body_id = str(body_raw.get("body_id", ""))
			body.mass_kg = float(body_raw.get("mass_kg", 0.0))
			body.constrained = bool(body_raw.get("constrained", false))
			built.bodies.append(body)
		var solver_raw: Variant = spec.get("solver")
		if typeof(solver_raw) != TYPE_DICTIONARY:
			errors.append("a setup with no solver: a replay that cannot "
					+ "say which settings it ran under is not evidence")
		else:
			var solver_spec: Dictionary = solver_raw
			_forbid_extra(solver_spec, SOLVER_KEYS, "solver", errors)
			var solver := SolverConfig.new()
			solver.iterations = int(solver_spec.get("iterations", 0))
			solver.fixed_step_hz = float(
					solver_spec.get("fixed_step_hz", 0.0))
			solver.settle_timeout_s = float(
					solver_spec.get("settle_timeout_s", 0.0))
			built.solver = solver
		out.setup = built
	elif setup_raw != null:
		errors.append("`setup` is present and is not an object")
	var solution_raw: Variant = raw.get("reference_solution")
	if typeof(solution_raw) == TYPE_DICTIONARY:
		var spec: Dictionary = solution_raw
		_forbid_extra(spec, SOLUTION_KEYS, "reference_solution", errors)
		out.has_reference_solution = true
		for step: Variant in spec.get("steps", []):
			out.reference_solution.append(str(step))
	elif solution_raw != null:
		errors.append("`reference_solution` is present and is not an object")
	if not errors.is_empty():
		return null
	return out

static func _forbid_extra(raw: Dictionary, allowed: Array,
		what: String, errors: Array[String]) -> void:
	for key: Variant in raw:
		if not str(key) in allowed:
			errors.append("%s carries '%s', which this lane does not "
					% [what, str(key)] + "model; the digest would be "
					+ "computed over less than the bridge hashes")

## EXACTLY WHAT GETS HASHED, and the only canonicalization here.
##
## Split out from `digest` so a test can compare the BYTES. A vector that
## only checks digests cannot say whether two implementations built
## different objects or serialized the same object differently.
func canonical_bytes() -> PackedByteArray:
	return canonical_text().to_utf8_buffer()

func canonical_text() -> String:
	var body := {
		"package_id": package_id,
		"latch_conditions": [],
		"vector_latches": vector_latches.duplicate(),
		# SORTED, because two packages that require the same latches in a
		# different order are the same package.
		"required_latches": required_latches.duplicate(),
		"setup": null,
		"reference_solution": null,
	}
	for latch: LatchCondition in latch_conditions:
		(body["latch_conditions"] as Array).append({
			"latch_id": latch.latch_id, "kind": latch.kind,
			"detail": latch.detail})
	(body["required_latches"] as Array).sort()
	if setup != null:
		var bodies: Array = []
		for spec: BodySpec in setup.bodies:
			bodies.append({"body_id": spec.body_id,
					"mass_kg": spec.mass_kg,
					"constrained": spec.constrained})
		body["setup"] = {
			"bodies": bodies,
			"scene_digest": setup.scene_digest,
			"solver": {} if setup.solver == null else {
				"iterations": setup.solver.iterations,
				"fixed_step_hz": setup.solver.fixed_step_hz,
				"settle_timeout_s": setup.solver.settle_timeout_s},
		}
	if has_reference_solution:
		body["reference_solution"] = reference_solution.duplicate()
	return _json(body)

## Sixteen hex characters. Identity and freshness, not authentication.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(canonical_bytes())
	return ctx.finish().hex_encode().substr(0, 16)

# --- the serializer ------------------------------------------------------
#
# WRITTEN OUT RATHER THAN HANDED TO `JSON.stringify`.
#
# The bytes have to match Python's `json.dumps(body, sort_keys=True,
# separators=(",", ":"))` exactly, and Godot's JSON writer differs in two
# ways that both change the hash: it prints an integral float as `80`
# where Python prints `80.0`, and it emits non-ASCII characters directly
# where Python's default `ensure_ascii=True` escapes them as `\uXXXX`.
# Either would produce a digest the bridge cannot match, for a package
# the two lanes agree about in every other respect.

static func _json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return _float(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return _quote(str(value))
		TYPE_ARRAY:
			var items: Array[String] = []
			for item: Variant in value as Array:
				items.append(_json(item))
			return "[%s]" % ",".join(items)
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var keys: Array = source.keys()
			keys.sort()
			var pairs: Array[String] = []
			for key: Variant in keys:
				pairs.append("%s:%s"
						% [_quote(str(key)), _json(source[key])])
			return "{%s}" % ",".join(pairs)
	push_error("physics digest: %s is not a JSON value"
			% type_string(typeof(value)))
	return "null"

## Python's `repr` for the floats this contract admits.
##
## `mass_kg`, `fixed_step_hz` and `settle_timeout_s` are all bounded well
## inside the range where a shortest round-tripping decimal has no
## exponent, so this is the shortest decimal that reads back as the same
## double, with the `.0` Python keeps and Godot drops.
static func _float(value: float) -> String:
	for places in range(1, 18):
		var text := String.num(value, places)
		if text.to_float() == value:
			return _trim(text)
	return _trim(String.num(value, 17))

## `80.10000` -> `80.1`, and `80` -> `80.0`: a JSON float always carries
## a point, which is the half Godot leaves out.
static func _trim(text: String) -> String:
	if not "." in text:
		return text + ".0"
	while text.ends_with("0") and not text.ends_with(".0"):
		text = text.substr(0, text.length() - 1)
	return text

## A JSON string as Python writes one with `ensure_ascii=True`.
static func _quote(text: String) -> String:
	var out := "\""
	for unit: int in text.to_utf32_buffer().to_int32_array():
		match unit:
			0x22: out += "\\\""
			0x5C: out += "\\\\"
			0x08: out += "\\b"
			0x0C: out += "\\f"
			0x0A: out += "\\n"
			0x0D: out += "\\r"
			0x09: out += "\\t"
			_:
				if unit < 0x20 or unit > 0x7E:
					out += _escape(unit)
				else:
					out += char(unit)
	return out + "\""

## `\uXXXX`, and a surrogate PAIR above the basic plane, which is what
## Python emits and what a naive four-hex-digit escape gets wrong.
static func _escape(unit: int) -> String:
	if unit <= 0xFFFF:
		return "\\u%04x" % unit
	var rest := unit - 0x10000
	return "\\u%04x\\u%04x" % [0xD800 + (rest >> 10),
			0xDC00 + (rest & 0x3FF)]
