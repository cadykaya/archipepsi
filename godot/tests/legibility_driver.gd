extends Node
## Can the player READ the writing on the walls? (`make godot-legible`)
##
## Playtest 1 reached the Hub and found every wall sign mirrored --
## "THE MULTIWORLD" rendered as its own reflection, the control list
## unreadable, the portal sign backwards. Nine suites were green. Not one
## of them had ever asked which WAY a piece of text faced, because every
## assertion in this project was about state, geometry or protocol, and a
## sign is correct in all three of those while being backwards.
##
## A Label3D draws on its local XY plane and reads correctly only from
## its local +Z side. Mounted flat on a wall it therefore has a right
## answer and a wrong one that differ by a sign, which is exactly the
## kind of detail that survives review by looking plausible.
##
## So: build the Hub, walk every Label3D, and check the text faces the
## room the player stands in. Billboarded labels are exempt -- they turn
## to the camera by construction.

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub := HubController.new()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var labels: Array[Label3D] = []
	_collect(hub, labels)
	_check(labels.size() >= 6,
			"found only %d Label3D in the Hub; this suite would pass "
			% labels.size() + "vacuously on an empty room")

	# The player spawns here (hub.gd), so this is the side every sign has
	# to be legible from.
	var eye := Vector3(0.0, 1.6, 3.0)
	var checked := 0
	for label: Label3D in labels:
		if label.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			continue                      # turns to face the camera anyway
		if label.text.strip_edges() == "":
			continue
		checked += 1
		# A Label3D reads correctly from its local +Z side.
		var facing := label.global_transform.basis.z.normalized()
		var to_player := (eye - label.global_position)
		to_player.y = 0.0
		if to_player.length() < 0.01:
			continue
		to_player = to_player.normalized()
		var alignment := facing.dot(to_player)
		_check(alignment > 0.0,
				"\"%s\" faces away from the player and renders MIRRORED "
				% label.text.split("\n")[0].substr(0, 34)
				+ "(facing %.2v, player is %.2v away, dot %.2f)"
				% [facing, to_player, alignment])

	_check(checked >= 4,
			"only %d fixed-rotation labels were checked; if the Hub went "
			% checked + "all-billboard this suite stopped proving anything")
	print("legibility: checked %d fixed labels of %d total"
			% [checked, labels.size()])
	_the_lab_doorway_is_a_hole_not_a_picture_of_one(hub)
	_the_lab_corridor_has_walls(hub)
	_the_hub_board_shows_the_whole_campaign()
	_the_three_projectiles_read_apart_in_silhouette()
	_the_silhouette_is_decided_by_flight_not_by_colour()
	_a_silhouette_cannot_move_a_hitbox()
	await _a_check_says_its_state_with_its_shape()
	_finish()


# === Checks: the state is the shape (art requirement 11) =================
#
# The requirement is NOT "the destination ring must exist". It is that a
# player across a room can tell a Check they have not opened from one
# they already sent, and that they can do it without the two channels
# that were carrying it: the label, which is words and unreadable at
# distance, and the item's tint, which went from (0.35, 0.35, 0.4) to
# (0.25, 0.3, 0.28) -- two greys a fraction of a shade apart, and the
# same grey to anyone who does not separate those hues.
#
# So the states have different FORMS, and this measures the forms. Any
# authored cradle and any authored spent mass answer it the same way the
# placeholders do; nothing here pins a particular mesh.

func _a_check_says_its_state_with_its_shape() -> void:
	BridgeClient.snapshot = {"scouted": [{
		"location_id": 89100011, "location_name": "Archipepsi Check 011",
		"revealed": true, "item_name": "Hookshot",
		"recipient_game": "Ocarina of Time"}]}
	var reward := RewardObject.create(89100011, "zone_1", "void_glitch")
	add_child(reward)
	await get_tree().process_frame

	# `sending` is a sub-second transient between two of these, so it is
	# not one of the forms a player reads across a room. These three are.
	var resting := ["locked", "available", "confirmed"]
	var forms: Dictionary = {}
	for state: String in resting:
		reward.state = state
		reward._refresh_visual()
		var form := RewardObject.state_profile(reward)
		forms[state] = form
		_check(int(form["parts"]) > 0,
				"the '%s' Check has no form at all: nothing on the "
				% state + "pedestal says what state it is in")
		print("check %-10s top %.2f height %.2f width %.2f parts %d"
				% [state, form["top"], form["height"], form["width"],
				form["parts"]])

	# The one the requirement names, stated first and on its own.
	_check(RewardObject.forms_read_apart(forms["locked"], forms["confirmed"]),
			("a LOCKED Check and a CONFIRMED one are the same shape "
			+ "(top %.2f vs %.2f, height %.2f vs %.2f); across a room "
			+ "they differ only in two near-identical greys and a word")
			% [forms["locked"]["top"], forms["confirmed"]["top"],
			forms["locked"]["height"], forms["confirmed"]["height"]])

	for i in resting.size():
		for j in range(i + 1, resting.size()):
			var a: String = resting[i]
			var b: String = resting[j]
			_check(RewardObject.forms_read_apart(forms[a], forms[b]),
					"'%s' and '%s' are the same shape (top %.2f vs %.2f)"
					% [a, b, forms[a]["top"], forms[b]["top"]])

	# And it is SHAPE doing it. Paint every state the same colour at the
	# same emission and the forms must still be the ones measured above:
	# if any of this was the material talking, it stops here.
	for state: String in resting:
		reward.state = state
		reward._refresh_visual()
		var flat := ThemeMaterials.glow_material(Color(0.5, 0.5, 0.5), 1.0)
		for node in _meshes_under(reward):
			node.material_override = flat
		var repainted := RewardObject.state_profile(reward)
		_check(str(repainted) == str(forms[state]),
				"the '%s' Check's form depends on its material (%s vs %s)"
				% [state, str(repainted), str(forms[state])])

	reward.queue_free()
	BridgeClient.snapshot = {}

func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_meshes_under(child))
	return out


## The Hub must describe the campaign it is IN, at any scale.
##
## Playtest 2.5 ran 450 locations and the Hub said "CHECKS 15/30" while
## the wall board showed the first thirty Checks and nothing else --
## 6.7% of the multiworld, presented as the multiworld. Both numbers were
## typed in when thirty was the only scale there was, which is the CS8b
## shape one more time: the options scaled and a consumer did not.
func _the_hub_board_shows_the_whole_campaign() -> void:
	var cells := Constants.TIER_COUNT * Constants.TIER_SIZE
	for total in [30, 120, 450, Constants.LOCATION_COUNT_MAX]:
		var bucket := HubController.board_bucket_size(total, cells)
		# Every Check must fall inside some cell. A board that covers less
		# than the campaign is the bug this replaced.
		_check(bucket * cells >= total,
				"a %d-Check campaign needs %d cells at bucket %d, and the "
				% [total, ceili(float(total) / bucket), bucket]
				+ "wall has %d: Checks past the end are invisible" % cells)
		# ...and no more than one cell may be entirely wasted, or the
		# board is mostly empty space pretending to be content.
		_check((bucket - 1) * cells < total,
				"bucket %d over %d cells wastes more than a cell of a "
				% [bucket, cells] + "%d-Check campaign" % total)

	# The prototype must be untouched: one Check per cell, exactly as
	# before. That property is why bucketing was a fix and not a redesign.
	_check(HubController.board_bucket_size(30, cells) == 1,
			"a thirty-Check campaign no longer puts one Check in a cell, "
			+ "so this changed the prototype's board as a side effect")

	# And the status line's denominator comes from the snapshot.
	var snap := {"checked_location_ids": [1, 2, 3],
			"missing_location_ids": range(447)}
	_check(HubController.campaign_check_total(snap) == 450,
			"the Hub counts %d Checks in a 450-Check campaign"
			% HubController.campaign_check_total(snap))


# === Projectiles: the arc is the shape (art requirement 13) ==============
#
# One primitive family, three flight behaviours, and until now one sphere
# for all of them scaled 1.5x for a lob. The three facts a player has to
# read BEFORE the shot lands -- goes straight / drops / explodes -- were
# not on screen at all.
#
# Colour cannot carry them, and this is the load-bearing half of the
# requirement rather than a style note: an Echo is tinted by the SOURCE
# WORLD whose item it reinterprets, so colour already means provenance.
# Spending it on behaviour would overwrite identity with mechanics and
# lose both. The difference has to survive greyscale.

## Every pair of silhouettes must read apart by SHAPE.
##
## `reads_apart` looks only at elongation and balance -- how needle-like a
## thing is, and where along it the widest part sits. Part count is
## deliberately not a measure: across a room, a shape built from three
## meshes and the same shape built from one look identical.
func _the_three_projectiles_read_apart_in_silhouette() -> void:
	var family := ProjectileSilhouette.FAMILY
	_check(family.size() >= 3,
			"the silhouette family has %d members; this suite would pass "
			% family.size() + "vacuously")

	# ONE tint for all of them. If any pair only reads apart because they
	# are different colours, this is where that shows up.
	var one_colour := Color(0.9, 0.4, 0.2)
	var built: Dictionary = {}
	var shapes: Dictionary = {}
	for name: String in family:
		var node := ProjectileSilhouette.build(name, one_colour)
		built[name] = node
		shapes[name] = ProjectileSilhouette.profile(node)

	for name: String in family:
		var shape: Dictionary = shapes[name]
		_check(int(shape["parts"]) > 0,
				"the '%s' silhouette has no geometry: an invisible shot"
				% name)
		# A projectile that overhangs its own 0.25 m collider by a long
		# way promises a reach it does not have.
		_check(float(shape["length"]) <= 0.9,
				"the '%s' silhouette is %.2f m long against a 0.25 m "
				% [name, shape["length"]] + "hitbox")
		print("silhouette %-9s %.2f x %.2f m  elongation %.2f balance %.2f"
				% [name, shape["length"], shape["cross"],
				shape["elongation"], shape["balance"]])

	for i in family.size():
		for j in range(i + 1, family.size()):
			var a: String = family[i]
			var b: String = family[j]
			_check(ProjectileSilhouette.reads_apart(shapes[a], shapes[b]),
					("'%s' and '%s' are the same shape at distance "
					+ "(elongation %.2f vs %.2f, balance %.2f vs %.2f); "
					+ "they differ only in colour, which already means "
					+ "which world the Echo came from")
					% [a, b, shapes[a]["elongation"], shapes[b]["elongation"],
					shapes[a]["balance"], shapes[b]["balance"]])

	for name: String in family:
		(built[name] as Node3D).free()


## The selection reads FLIGHT, and the shape does not read colour.
##
## Two halves of one rule, checked together because breaking either one
## re-couples presentation to the wrong thing: a silhouette chosen from
## anything but the shot's own behaviour is decoration, and a shape that
## changes with the tint is hue doing the job shape was given.
func _the_silhouette_is_decided_by_flight_not_by_colour() -> void:
	# Straight: no gravity, no blast. A plain bolt.
	_check(ProjectileSilhouette.for_behaviour(0.0, 0.0)
			== ProjectileSilhouette.STRAIGHT,
			"a flat bolt does not wear the straight silhouette")
	# Falling: any gravity at all. `gravity_scale` is a schema float in
	# [0, 1], so the smallest legal non-zero value has to count -- a shot
	# that drops slowly still drops.
	for gravity: float in [0.01, 0.35, 1.0]:
		_check(ProjectileSilhouette.for_behaviour(gravity, 0.0)
				== ProjectileSilhouette.FALLING,
				"gravity_scale %.2f does not read as a falling shot"
				% gravity)
	# Lobbed outranks falling: an arc_lob is ALSO fully gravity-affected,
	# and the fuse is the fact that matters.
	_check(ProjectileSilhouette.for_behaviour(1.0, 3.0)
			== ProjectileSilhouette.LOBBED,
			"a fused blast reads as a falling shot; the explosion is the "
			+ "thing the player has to see coming")
	# Total over the family: nothing falls through to a fourth answer.
	for gravity: float in [0.0, 0.5, 1.0]:
		for blast: float in [0.0, 1.0, 6.0]:
			var chosen := ProjectileSilhouette.for_behaviour(gravity, blast)
			_check(chosen in ProjectileSilhouette.FAMILY,
					"gravity %.1f blast %.1f selected '%s', which is not "
					% [gravity, blast, chosen] + "in the family")

	# And the shape is the same shape whatever world tinted it.
	for name: String in ProjectileSilhouette.FAMILY:
		var reference: Dictionary = {}
		for tint: Color in [Color(1, 0, 0), Color(0, 1, 0),
				Color(0.2, 0.4, 1.0), Color(1, 1, 1)]:
			var node := ProjectileSilhouette.build(name, tint)
			var shape := ProjectileSilhouette.profile(node)
			node.free()
			if reference.is_empty():
				reference = shape
				continue
			# Every measure, not just the ratios: a shape scaled by its
			# tint keeps its proportions exactly, so `elongation` and
			# `balance` alone would report it as unchanged. The absolute
			# size is the half that moves.
			var same := true
			for key in ["length", "cross", "elongation", "balance", "parts"]:
				same = same and is_equal_approx(float(shape[key]),
						float(reference[key]))
			_check(same,
					"the '%s' silhouette changes shape with its tint "
					% name + "(%s vs %s); colour is provenance, not "
					% [str(shape), str(reference)] + "behaviour")


## Presentation cannot become mechanics.
##
## The three silhouettes are visibly different sizes, and the collider is
## the thing that must not notice. Built through the real spawn path, so
## this measures what the game does rather than what this suite sets up.
func _a_silhouette_cannot_move_a_hitbox() -> void:
	var profiles: Array = []
	var shapes: Array[String] = []
	for spec: Dictionary in [
			{"gravity": 0.0, "blast": 0.0},
			{"gravity": 1.0, "blast": 0.0},
			{"gravity": 1.0, "blast": 3.0}]:
		var shot := EchoProjectile.new()
		shot.gravity_scale = float(spec["gravity"])
		shot.blast_radius = float(spec["blast"])
		shot.tint = Color(0.4, 0.9, 0.7)
		add_child(shot)
		profiles.append(VisualInterface.collision_profile(shot))
		shapes.append(shot.silhouette)
		# The visual is under a container, so nothing an artist supplies
		# can be the reason a hitbox moved.
		_check(shot.get_node_or_null("Visual") != null,
				"the projectile's presentation is not under a Visual "
				+ "container; a scaled mesh would scale the collider")
		_check(VisualInterface.collision_profile(
				shot.get_node("Visual")).is_empty(),
				"the projectile's visual carries collision")
		shot.free()

	_check(shapes[0] != shapes[1] and shapes[1] != shapes[2],
			"the three shots wore %s: this check would pass on one shape"
			% str(shapes))
	for i in range(1, profiles.size()):
		_check(str(profiles[i]) == str(profiles[0]),
				("the '%s' shot has a different hitbox from the '%s' one "
				+ "(%s vs %s); what a shot looks like decided what it hits")
				% [shapes[i], shapes[0], str(profiles[i]), str(profiles[0])])

## Playtest 1 could not reach the Echo Lab. `_cut_lab_doorway` added a
## dark box IN FRONT OF the perimeter wall and called it an opening --
## the wall behind kept its collider, so the doorway was a picture of a
## doorway. It looked right from across the room, which is exactly how it
## survived: nothing renders differently, and no suite had ever tried to
## walk through anything.
func _the_lab_doorway_is_a_hole_not_a_picture_of_one(hub: Node) -> void:
	var space: PhysicsDirectSpaceState3D = \
			hub.get_world_3d().direct_space_state
	var door_z: float = HubAnchors.LAB_DOOR_Z
	var eye_y: float = 1.2

	# Straight at the doorway from inside the room, and out the far side.
	# Sweep the doorway's whole width. One ray down the middle would pass
	# a door with a station parked across half of it.
	var half := HubAnchors.LAB_DOOR_WIDTH / 2.0
	for offset: float in [-half + 0.4, 0.0, half - 0.4]:
		var probe := PhysicsRayQueryParameters3D.create(
				Vector3(-4.0, eye_y, door_z + offset),
				Vector3(-HubAnchors.W / 2.0 - 2.5, eye_y, door_z + offset))
		var blocked: Dictionary = space.intersect_ray(probe)
		var by: String = ""
		if not blocked.is_empty():
			var who: Node = blocked.get("collider") as Node
			by = who.get_path() if who != null else "?"
		_check(blocked.is_empty(),
				"the Echo Lab doorway is blocked at z=%.1f (%s) by %s"
				% [door_z + offset, blocked.get("position", Vector3.ZERO), by])

	var from := Vector3(-4.0, eye_y, door_z)
	var to := Vector3(-HubAnchors.W / 2.0 - 2.5, eye_y, door_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(query)
	var blocker: String = ""
	if not hit.is_empty():
		var node: Node = hit.get("collider") as Node
		blocker = node.get_path() if node != null else "?"
	_check(hit.is_empty(),
			"the Echo Lab doorway is blocked at %s by %s -- the player "
			% [hit.get("position", Vector3.ZERO), blocker]
			+ "walks into a wall with a picture of a door on it")

	# And the wall either side must still be solid, or the "fix" was to
	# delete the wall.
	for probe_z: float in [door_z - HubAnchors.LAB_DOOR_WIDTH - 1.5,
			door_z + HubAnchors.LAB_DOOR_WIDTH + 1.5]:
		var wall_query := PhysicsRayQueryParameters3D.create(
				Vector3(-4.0, eye_y, probe_z),
				Vector3(-HubAnchors.W / 2.0 - 2.5, eye_y, probe_z))
		_check(not space.intersect_ray(wall_query).is_empty(),
				"the wall at z=%.1f is missing; the doorway was widened "
				% probe_z + "into an open side of the room")

func _collect(node: Node, out: Array[Label3D]) -> void:
	if node is Label3D:
		out.append(node as Label3D)
	for child in node.get_children():
		_collect(child, out)

func _finish() -> void:
	if failures == 0:
		print("GODOT LEGIBILITY TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT LEGIBILITY TESTS: %d failures" % failures)
		get_tree().quit(1)

## Walking to the Echo Lab, playtest 1 found an open-walled slot with the
## void either hand, shimmering at the threshold.
##
## The corridor was built as a floor and a ceiling and nothing else, and
## its floor overlapped the room's by 0.1m -- two coplanar top faces,
## which is exactly what z-fighting is. Both are the same kind of miss:
## geometry checked by looking at it from the one angle it was authored
## from.
func _the_lab_corridor_has_walls(hub: Node) -> void:
	var space: PhysicsDirectSpaceState3D = \
			hub.get_world_3d().direct_space_state
	var door_z: float = HubAnchors.LAB_DOOR_Z
	var half: float = HubAnchors.LAB_DOOR_WIDTH / 2.0
	var mid_x: float = -HubAnchors.W / 2.0 - 1.7
	var eye_y: float = 1.2

	# Stand in the corridor, look sideways. Something must stop you.
	for side: float in [-1.0, 1.0]:
		var probe := PhysicsRayQueryParameters3D.create(
				Vector3(mid_x, eye_y, door_z),
				Vector3(mid_x, eye_y, door_z + side * (half + 1.5)))
		_check(not space.intersect_ray(probe).is_empty(),
				"the Lab corridor has no wall on the %s side -- you walk "
				% ("+z" if side > 0.0 else "-z")
				+ "to the Lab down an open slot")

	# And a ceiling, or the corridor is a trench.
	var up := PhysicsRayQueryParameters3D.create(
			Vector3(mid_x, eye_y, door_z),
			Vector3(mid_x, HubAnchors.H + 1.0, door_z))
	_check(not space.intersect_ray(up).is_empty(),
			"the Lab corridor is open to the sky")
