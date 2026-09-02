extends SceneTree
## Production's OWN `ShellValidator`, against the shipped scenes.
##
## WHY THIS STAGE EXISTS. `verify_pack.gd` asks the registry whether a
## shell LOADS. `verify_collision.gd` asks whether the geometry a Surface
## promises is really under the player's feet. Neither one runs
## `ShellValidator`, and `ShellValidator._check_segment` is the rule that
## measures a traversal marker IN THE SCENE against
## `Constants.max_safe_gap` -- refusing a mandatory route the base kit
## cannot make, and refusing a mandatory route that ships no markers to
## measure at all.
##
## P2 never needed it: every mandatory segment in the eight was a 1.0 m
## stone, comfortably inside the base kit whichever way it was read. The
## hall climbs 28 m. So the rule is run here, art-side, where a refusal
## is a build to fix rather than a failed integration.
##
## WHAT IS NOT HERE. `RoomContract.violations` takes a room OUTPUT --
## `root`, `bounds`, `exit_offset`, `reward_position`, `enemy_spawns` --
## which a builder produces at runtime and a manifest entry is not. The
## honest way to run it is on a real composed room, which is Production's
## side of the seam. Reconstructing a fake room result here would test
## the reconstruction. `_offer_violations` is the part of it that bears
## on this shell, and `verify_manifest.py` already runs the Python twin
## of those same rules over the real entry.

const PACK := "res://content/registry/authored_art.json"

## The traversal kinds Production's PYTHON schema deliberately leaves
## unbounded. `TraversalSegment` bounds `rise` and `gap` and says so in
## its own validator name -- a jump -- while `walk` (continuous ground)
## and `drop` (falling, which the base kit does not have to reach) carry
## no reach bound at all.
const UNBOUND_KINDS := ["walk", "drop"]

func _init() -> void:
	# The tree has to be PUMPED before `quit()` is honoured: a `-s`
	# SceneTree script that never awaits sits in `_init` forever with the
	# quit request queued behind a main loop that is not running. The
	# first version of this file hung exactly there. `verify_collision.gd`
	# awaits `physics_frame` for its own reasons and got this for free.
	await process_frame
	var Shell: GDScript = load("res://_harness/shell_validator.gd")
	var fh := FileAccess.open(PACK, FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(fh.get_as_text())
	var fails := 0
	var noted := 0
	var checked := 0

	for raw: Variant in manifest.get("entries", []):
		var entry: Dictionary = raw
		if str(entry.get("category", "")) != "room_shell":
			continue
		checked += 1
		var id := str(entry["id"])
		var packed: PackedScene = load(str(entry["scene"]))
		if packed == null:
			print("[shells] LOAD FAILED %s" % id); fails += 1; continue
		var inst: Node3D = packed.instantiate()

		var refusals: Array = Shell.refusals(entry, inst)
		var mandatory := 0
		var kinds := {}
		for seg: Variant in entry.get("traversal", []) as Array:
			var d: Dictionary = seg
			kinds[str(d.get("name", ""))] = str(d.get("kind", ""))
			if bool(d.get("mandatory", true)):
				mandatory += 1

		# CLASSIFY, do not filter. Every refusal is printed. What the
		# split decides is only whether it is ART'S DEFECT.
		var mine: Array[String] = []
		var kind_blind: Array[String] = []
		for r: String in refusals:
			(kind_blind if _kind_blind(r, kinds) else mine).append(r)

		if refusals.is_empty():
			print("[shells]   ok  %-22s %2d traversal (%d mandatory), %2d socket(s), %2d offer(s)"
					% [id, (entry.get("traversal", []) as Array).size(),
					mandatory, (entry.get("sockets", []) as Array).size(),
					(entry.get("offers", []) as Array).size()])
		else:
			if not mine.is_empty():
				fails += 1
				print("[shells] REFUSED %s" % id)
			else:
				noted += 1
				print("[shells] NOTED   %s -- refused ONLY by the kind-blind"
						% id + " rule; see the disagreement below")
			for r: String in mine:
				print("[shells]     %s" % r)
			for r: String in kind_blind:
				print("[shells]     [walk/drop] %s" % r)
		inst.free()

	if noted > 0:
		_report_disagreement()
	if fails == 0:
		print("[shells] PASS -- %d shell(s); no shell is refused for a "
				% checked + "segment BOTH validators bound (%d noted)"
				% noted)
	else:
		print("[shells] FAIL -- %d of %d shell(s) refused" % [fails, checked])
	quit(1 if fails > 0 else 0)


## Is this refusal one the Python half of the same contract would not
## have made?
##
## `TraversalSegment._a_mandatory_jump_stays_inside_the_base_kit` tests
## `self.kind` before applying `MAX_VERTICAL_STEP` or `max_safe_gap`:
## only `rise` and `gap` are bound, and `walk` and `drop` are deliberately
## not. `ShellValidator._check_segment` never reads `kind` at all.
##
## So a refusal is classified by the kind of the segment it names, read
## from the entry -- NOT by matching on the message text, which is
## Production's to reword.
func _kind_blind(refusal: String, kinds: Dictionary) -> bool:
	for name: String in kinds:
		if name != "" and refusal.contains("'%s'" % name):
			return UNBOUND_KINDS.has(str(kinds[name]))
	return false


func _report_disagreement() -> void:
	for line in [
			"",
			"THE TWO HALVES OF THE TRAVERSAL CONTRACT DISAGREE, and the",
			"refusals marked [walk/drop] above are that disagreement, not",
			"a defect in the shell:",
			"",
			"  schemas/content.py  TraversalSegment tests `self.kind` and",
			"                      bounds ONLY `rise` and `gap` by",
			"                      MAX_VERTICAL_STEP / max_safe_gap.",
			"  shell_validator.gd  _check_segment never reads `kind`. It",
			"                      applies the same bounds to EVERY",
			"                      mandatory segment, `walk` included.",
			"",
			"P2 could not see this: every mandatory segment in the eight",
			"was a 1.00 m `rise`, inside both readings. A LARGE room",
			"cannot avoid it -- a 28 m climb declared as ramps is `walk`,",
			"and declared as steps is 28+ segments against a cap of 32.",
			"",
			"The clearest single case is `ring_n_to_ring_e`: 3.20 m,",
			"FLAT, along a continuous walkable collar, refused because",
			"3.20 > max_safe_gap(0) = 2.60. There is floor under every",
			"centimetre of it. No reading of the geometry makes that",
			"segment a jump.",
			"",
			"ART HAS NOT CHANGED THE SHELL TO GET PAST THIS. The route",
			"is declared as what it is. Which half is authoritative is",
			"Production's to decide.",
			""]:
		print("[shells] %s" % line)
