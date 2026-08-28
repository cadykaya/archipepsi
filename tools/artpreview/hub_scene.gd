class_name HubScene
extends RefCounted
## The Hub, assembled out of authored assets. Shared, not duplicated.
##
##   HubScene.build(root, assets_root)   ->   authored triangle count
##
## `HubRoom.gd` renders the batch-003 review sheets from this and `shoot.gd`
## builds it for any shot whose scene is `"hub"`. It lived inside HubRoom
## first, which meant the shot runner would have had to either duplicate 90
## lines of placement or re-derive it -- and a second copy of the Hub is a
## second Hub to keep in step with `hub.gd`.
##
## EVERY dimension and position here is read out of `godot/scripts/hub/hub.gd`.
## Nothing in it is a composition choice:
##
##   room            22 x 16 x 5 m
##   spawn           (0, 0.8, 3.0)
##   shop            (-W/2 + 1.6, 0, D * 0.45), yaw -90
##   archive         (W/2 - 1.6, 0, D * 0.45), yaw +90
##   abandon         (-W/2 + 2.4, 0, D - 2.4)
##   campaign board  (-W/2 + 0.35, 2.3, D * 0.62)
##   controls board  (W/2 - 0.35, 2.2, D * 0.62)
##   lab doorway     -X wall at z 6.0, a 3.0 x 3.2 m opening
##   portal          (0, 0, D - 1.2)
##   lights          two, at (+/-W/4, H - 0.4, D/2), theme energy, range 16
##
## with ONE exception, marked where it happens: the Epsilon installation's
## position is an art proposal, because hub.gd has no fixture for it.

const W := 22.0
const D := 16.0
const H := 5.0
const MODULE := 4.0

static var tris := 0

static var _assets := ""


## Build the whole room under `root`. Returns the authored triangle count.
static func build(root: Node3D, assets: String) -> int:
	_assets = assets
	tris = 0
	_build_shell(root)
	_place_fixtures(root)
	_place_lights(root)
	return tris


## The shell, on the module grid, with pilasters absorbing the remainder.
static func _build_shell(root: Node3D) -> void:
	# Floor and ceiling: whole 4 m slabs, plus a part row, because 22 is not
	# a multiple of 4 and the floor has to reach the wall either way.
	var nx: int = int(ceil(W / MODULE))
	var nz: int = int(ceil(D / MODULE))
	for ix in nx:
		for iz in nz:
			var x: float = -W / 2.0 + MODULE * 0.5 + ix * MODULE
			var z: float = MODULE * 0.5 + iz * MODULE
			_add(root, "batch001/architecture/arch_floor_slab.glb",
					Vector3(x, 0, z))
			_add(root, "batch001/architecture/arch_ceiling_beam.glb",
					Vector3(x, H, z))

	# The four walls. Each run is whole modules; the leftover goes into the
	# pilasters, which is what they are for.
	for iz in nz:
		var z: float = MODULE * 0.5 + iz * MODULE
		for side in [-1.0, 1.0]:
			var x: float = side * W / 2.0
			# The Lab doorway takes the -X wall's bay at z 6.
			if side < 0.0 and absf(z - 6.0) < MODULE * 0.5:
				_add(root, "batch003/architecture/hub_lab_doorway.glb",
						Vector3(x, 0, 6.0), 90.0)
				continue
			_add(root, "batch001/architecture/arch_wall_panel.glb",
					Vector3(x, 0, z), 90.0 * side)
			_add(root, "batch003/architecture/arch_wall_upper.glb",
					Vector3(x, MODULE, z), 90.0 * side)
	for ix in nx:
		var x: float = -W / 2.0 + MODULE * 0.5 + ix * MODULE
		for spec in [[0.0, 0.0], [D, 180.0]]:
			_add(root, "batch001/architecture/arch_wall_panel.glb",
					Vector3(x, 0, float(spec[0])), float(spec[1]))
			_add(root, "batch003/architecture/arch_wall_upper.glb",
					Vector3(x, MODULE, float(spec[0])), float(spec[1]))
		# A pilaster on every module joint, and the corners get one too.
		_add(root, "batch003/architecture/arch_pilaster.glb",
				Vector3(x - MODULE * 0.5, 0, 0.25))
		_add(root, "batch003/architecture/arch_pilaster.glb",
				Vector3(x - MODULE * 0.5, 0, D - 0.25), 180.0)

	# Trim rail along the base of the long walls, and a pipe run overhead.
	for iz in nz:
		var z: float = MODULE * 0.5 + iz * MODULE
		for side in [-1.0, 1.0]:
			_add(root, "batch001/architecture/arch_trim_rail.glb",
					Vector3(side * (W / 2.0 - 0.24), 0, z), 90.0 * side)
	for ix in nx:
		var x: float = -W / 2.0 + MODULE * 0.5 + ix * MODULE
		_add(root, "batch001/architecture/arch_pipe_run.glb",
				Vector3(x, 0, D - 0.55), 180.0)

static func _place_fixtures(root: Node3D) -> void:
	# Positions straight out of hub.gd. The yaws are hub.gd's too, converted
	# from radians: shop -PI/2, archive +PI/2.
	_add(root, "batch003/hub/hub_shop_counter.glb",
			Vector3(-W / 2.0 + 1.6, 0, D * 0.45), -90.0)
	_add(root, "batch003/hub/hub_archive_terminal.glb",
			Vector3(W / 2.0 - 1.6, 0, D * 0.45), 90.0)
	_add(root, "batch003/hub/hub_abandon_station.glb",
			Vector3(-W / 2.0 + 2.4, 0, D - 2.4))
	# The boards are centre-anchored, so their hub.gd Y is their centre.
	_add(root, "batch003/hub/hub_campaign_board.glb",
			Vector3(-W / 2.0 + 0.35, 2.3, D * 0.62), -90.0)
	_add(root, "batch003/hub/hub_controls_board.glb",
			Vector3(W / 2.0 - 0.35, 2.2, D * 0.62), 90.0)

	# The portal, at hub.gd's (0, 0, D - 1.2).
	_add(root, "batch002/portal/portal_b2_wound.glb",
			Vector3(0, 0, D - 1.2), 180.0)

	# EPSILON. This position is a PROPOSAL, and the only one in the scene.
	#
	# hub.gd has no fixture for the installation and the generic terminal
	# envelope it does have is 2.0 x 3.0 x 0.8 m -- the installation is
	# 9.02 x 3.48 x 3.55. It needs a reserved bay. The back wall left of the
	# portal is the only 9 m of wall in the room that is not already spoken
	# for, and it puts Epsilon in the player's eyeline on the turn from
	# spawn, which is where the thing that talks to you belongs.
	#
	# It does clash with the abandon console at (-8.6, 0, 13.6), and that
	# clash is the interface item, not something art resolves quietly.
	_add(root, "batch002/epsilon/epsilon_installation.glb",
			Vector3(-5.5, 0, D - 1.8), 180.0)

static func _place_lights(root: Node3D) -> void:
	# hub.gd: two omnis at (+/-W/4, H - 0.4, D/2), theme energy, range 16.
	# Its own _light helper sets shadows off, and so does this.
	for side in [-1.0, 1.0]:
		var at: Vector3 = Vector3(side * W / 4.0, H - 0.4, D / 2.0)
		_add(root, "batch001/architecture/arch_light_fixture.glb",
				at + Vector3(0, 0.4, 0))
		var lamp := OmniLight3D.new()
		lamp.position = at - Vector3(0, 0.35, 0)
		lamp.light_energy = 3.0
		lamp.light_color = Color(0.918, 0.949, 1.0)
		lamp.omni_range = 16.0
		lamp.shadow_enabled = false
		root.add_child(lamp)

	# And the locked lighting rule: the room stays cold, and the warmth is
	# local. Three utility lamps on the long walls, dimmer than the ceiling
	# and on a range that falls off inside the room.
	for at in [Vector3(-W / 2.0, 2.1, 3.2), Vector3(W / 2.0, 2.1, 9.0),
			Vector3(-W / 2.0, 2.1, 12.4)]:
		var yaw: float = 90.0 if at.x < 0.0 else -90.0
		_add(root, "batch002/architecture/arch_utility_lamp.glb", at, yaw)
		var pool := OmniLight3D.new()
		pool.position = at + Vector3(0.45 if at.x < 0.0 else -0.45, -0.12, 0)
		pool.light_energy = 1.4
		pool.light_color = Color(1.0, 0.784, 0.451)
		pool.omni_range = 2.6
		pool.shadow_enabled = false
		root.add_child(pool)

static func _add(root: Node3D, relative: String, at: Vector3,
		yaw: float = 0.0) -> Node3D:
	var node: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, relative])
	if node == null:
		push_error("HubRoom: missing %s" % relative)
		return null
	ArtBench.force_nearest(node)
	node.position = at
	node.rotation_degrees = Vector3(0, yaw, 0)
	root.add_child(node)
	tris += _count(node)
	return node

static func _count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			for s in child.mesh.get_surface_count():
				total += child.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
		total += _count(child)
	return total
