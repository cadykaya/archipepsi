class_name RangeImpacts
extends Node
## THE FIVE-WEAPON RANGE'S IMPACTS: what a shot does to the surface it
## actually hits. The material comes from the collider, never from the
## weapon: a node's `impact_material` meta (its own or an ancestor's), an
## enemy reads as organic, and anything untagged is `unknown`, counted and
## shown as plain dust so a missing tag is visible rather than guessed.
##
## Prod's lane (02_EFFECTS_AND_IMPACT_CONTRACT): the 3D sparks, chips,
## fibres, dust, light and the persistent marks. Arty's authored 2D
## layers, when they land, sit on top of these, not instead of them.
##
## **Marks persist.** One per hit (a scattergun's pellets share a central
## one and a few chips), aligned to the hit's normal, parented to the
## body that was hit so they ride a moving target or a pushed crate and
## go when it goes. They stay until the range restarts; past `MARK_CAP`
## the oldest is recycled.

const MATERIALS: Array[String] = ["metal", "stone", "organic", "wood"]
## H's gel block says "flesh"; the five-weapon contract says organic.
const ALIASES := {"flesh": "organic"}
const MARK_CAP := 160
## Live effect roots at once; a carbine's stream recycles the oldest.
const EFFECT_CAP := 40

var marks: Array = []
var effects: Array = []
var unknown_hits := 0
var counts := {}
## The last impact, for the check: material, position, normal, the root
## node of its effect, the sparks node (or null), marks added.
var last := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5150


static func material_of(collider: Variant) -> String:
	var node := collider as Node if is_instance_valid(collider) else null
	while node != null:
		if node.has_meta("impact_material"):
			var kind := String(node.get_meta("impact_material"))
			return String(ALIASES.get(kind, kind))
		if node.is_in_group("enemies"):
			return "organic"
		node = node.get_parent()
	return "unknown"


## One impact. `power` scales the debris and light (a carbine round is
## about 0.3, a hand cannon 1.0, a full Mass Driver slug 1.5); `mark`
## scales the mark (0 for none); `light` allows the impact flash.
func impact(at: Vector3, normal: Vector3, collider: Variant, power: float,
		mark := 1.0, light := true) -> Dictionary:
	var kind := material_of(collider)
	counts[kind] = int(counts.get(kind, 0)) + 1
	if kind == "unknown":
		unknown_hits += 1
	var root := Node3D.new()
	root.name = "Impact_" + kind
	_world().add_child(root)
	root.global_position = at + normal * 0.02
	effects.append(root)
	while effects.size() > EFFECT_CAP:
		var old: Variant = effects.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	var sparks: Node = null
	var life := 0.6
	match kind:
		"metal":
			sparks = _spray(root, normal, maxi(4, roundi(26 * power)), 0.35,
					Vector2(4.0, 9.0) * clampf(0.7 + 0.3 * power, 0.7, 1.3), 55.0,
					Vector3(0.008, 0.008, 0.07), HandCannon._additive(
					Color(1.0, 0.75, 0.35)), true, "Sparks")
			if light:
				_light(root, normal, Color(1.0, 0.7, 0.35), 3.5 * power, 0.12)
			_puff(root, Color(0.45, 0.45, 0.45, 0.3), 0.35 * power, 0.5)
			_glow(root, normal, 0.12 * clampf(power, 0.4, 1.5))
			life = 0.5
		"stone":
			_spray(root, normal, maxi(3, roundi(22 * power)), 0.7,
					Vector2(2.0, 5.0), 55.0, Vector3(0.04, 0.03, 0.04) * clampf(
					0.6 + 0.4 * power, 0.5, 1.4), HandCannon._lit(
					Color(0.3, 0.29, 0.27)), false, "Chips")
			_puff(root, Color(0.42, 0.38, 0.33, 0.7), 1.3 * power, 0.9)
			life = 0.9
		"wood":
			_spray(root, normal, maxi(3, roundi(18 * power)), 0.6,
					Vector2(1.8, 4.0), 50.0, Vector3(0.016, 0.016, 0.1),
					HandCannon._lit(Color(0.9, 0.78, 0.55)), false, "Splinters")
			_puff(root, Color(0.8, 0.68, 0.5, 0.55), 0.8 * power, 0.7)
			life = 0.7
		"organic":
			# Soft: pale padding fibres that drift rather than fly, and a
			# dull puff. No sparks, no light, no gore.
			var fibres := _spray(root, normal, maxi(3, roundi(14 * power)), 0.8,
					Vector2(0.8, 2.2), 70.0, Vector3(0.01, 0.01, 0.05),
					HandCannon._lit(Color(0.86, 0.8, 0.68)), false, "Fibres")
			(fibres as CPUParticles3D).gravity = Vector3(0, -2.5, 0)
			(fibres as CPUParticles3D).damping_min = 2.0
			(fibres as CPUParticles3D).damping_max = 3.0
			_puff(root, Color(0.62, 0.55, 0.48, 0.55), 0.7 * power, 0.45)
			life = 0.8
		_:
			_puff(root, Color(0.5, 0.5, 0.5, 0.5), 0.5 * power, 0.5)
			life = 0.5
	var timer := root.create_tween()
	timer.tween_interval(life)
	timer.tween_callback(root.queue_free)
	var added := 0
	if mark > 0.0:
		_mark(at, normal, kind, collider, mark)
		added = 1
	var parts: Array = []
	for child in root.get_children():
		parts.append("Light" if child is OmniLight3D else String(child.name))
	last = {"material": kind, "at": at, "normal": normal, "root": root,
			"sparks": sparks, "parts": parts, "marks": added,
			"collider": collider}
	return last


## A small chip mark without debris: a scattergun's secondary pellets.
func chip(at: Vector3, normal: Vector3, collider: Variant) -> void:
	_mark(at, normal, material_of(collider), collider, 0.45)


func _spray(root: Node3D, normal: Vector3, amount: int, life: float,
		speed: Vector2, spread: float, grain: Vector3, material: Material,
		streaks: bool, label: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = label
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3(0, 0, 1)
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0, -9.8, 0)
	p.particle_flag_align_y = streaks
	var box := BoxMesh.new()
	box.size = Vector3(grain.x, grain.z, grain.y) if streaks else grain
	p.mesh = box
	p.material_override = material
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	root.add_child(p)
	p.global_basis = Basis.looking_at(-normal, Vector3.UP
			if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	p.emitting = true
	return p


func _light(root: Node3D, normal: Vector3, color: Color, energy: float,
		seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 3.0
	root.add_child(light)
	light.position = normal * 0.25
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _puff(root: Node3D, color: Color, size: float, seconds: float) -> void:
	var puff := _billboard(color, 0.12)
	root.add_child(puff)
	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * maxf(1.0, size / 0.12),
			seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff.material_override, "albedo_color:a", 0.0,
			seconds)


## The brief hot glow of a struck metal surface (the dent's heat).
func _glow(root: Node3D, normal: Vector3, size: float) -> void:
	var glow := _billboard(Color(1.0, 0.55, 0.2, 0.9), size)
	(glow.material_override as StandardMaterial3D).blend_mode = \
			BaseMaterial3D.BLEND_MODE_ADD
	root.add_child(glow)
	glow.position = normal * 0.01
	var tween := glow.create_tween()
	tween.tween_property(glow.material_override, "albedo_color:a", 0.0, 0.4)


func _billboard(color: Color, size: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	node.mesh = quad
	var material := HandCannon._alpha(color)
	material.albedo_texture = HandCannon._tex_soft()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# ================================================================== marks

## A mark on the surface that was hit, parented to the body that owns it.
func _mark(at: Vector3, normal: Vector3, kind: String, collider: Variant,
		scale: float) -> void:
	var owner_node := collider as Node3D if is_instance_valid(collider) \
			else null
	var decal := Decal.new()
	decal.name = "Mark_" + kind
	var across: float = {"metal": 0.2, "stone": 0.3, "wood": 0.24,
			"organic": 0.3}.get(kind, 0.2) * scale
	decal.size = Vector3(across, 0.2, across)
	decal.texture_albedo = mark_texture(kind)
	if kind == "metal" and scale >= 0.6:
		decal.texture_emission = HandCannon._tex_glow()
		decal.emission_energy = 2.5
	if owner_node != null:
		owner_node.add_child(decal)
	else:
		_world().add_child(decal)
	decal.global_position = at
	decal.global_basis = WeaponFeelTreatments._axis_onto(normal) \
			.rotated(normal.normalized(), _rng.randf_range(0.0, TAU))
	decal.set_meta("mark_kind", kind)
	marks.append(decal)
	_trim()
	if decal.emission_energy > 0.0:
		# The hot rim cools; the hole stays.
		var tween := decal.create_tween()
		tween.tween_property(decal, "emission_energy", 0.0, 1.5)


func _trim() -> void:
	var live: Array = []
	for decal in marks:
		if is_instance_valid(decal):
			live.append(decal)
	marks = live
	while marks.size() > MARK_CAP:
		var old: Variant = marks.pop_front()
		(old as Node).queue_free()


## Marks still on screen (the cap, freed owners and recycling applied).
func live_marks() -> int:
	_trim()
	return marks.size()


## Every mark and live effect cleared (the check's reset between phases;
## a RESTART rebuilds the whole range anyway).
func clear() -> void:
	for decal in marks:
		if is_instance_valid(decal):
			decal.queue_free()
	marks.clear()
	for root in effects:
		if is_instance_valid(root):
			root.queue_free()
	effects.clear()


static func mark_texture(kind: String) -> Texture2D:
	match kind:
		"metal":
			return HandCannon._cached("range_metal", _make_metal)
		"organic":
			return HandCannon._cached("range_organic", _make_organic)
		"stone", "wood":
			return HandCannon._tex_mark(kind)
	return HandCannon._tex_mark("stone")


static func _make_metal() -> Texture2D:
	return HandCannon._paint(64, _metal_px)


## A dark hole, a jagged ring of chipped finish showing bright metal, and
## a faint scorch.
static func _metal_px(u: float, v: float) -> Color:
	var r := sqrt(u * u + v * v)
	var angle := atan2(v, u)
	var jag := 0.06 * sin(angle * 9.0) + 0.05 * sin(angle * 17.0 + 1.3)
	var hole := clampf((0.22 + jag * 0.3 - r) / 0.05, 0.0, 1.0)
	var chip := clampf(1.0 - absf(r - (0.36 + jag)) / 0.08, 0.0, 1.0)
	var scorch := clampf(1.0 - r, 0.0, 1.0) * 0.35
	if hole > 0.0:
		return Color(0.03, 0.03, 0.03, maxf(hole, scorch))
	if chip > 0.25:
		return Color(0.72, 0.72, 0.7, chip * 0.85)
	return Color(0.08, 0.07, 0.06, scorch)


static func _make_organic() -> Texture2D:
	return HandCannon._paint(64, _organic_px)


## A dull, soft-edged dent: darker padding, no red.
static func _organic_px(u: float, v: float) -> Color:
	var r := sqrt(u * u + v * v)
	var angle := atan2(v, u)
	var soft := clampf((0.6 + 0.06 * sin(angle * 5.0) - r) / 0.35, 0.0, 1.0)
	return Color(0.22, 0.18, 0.15, soft * 0.75)


func _world() -> Node:
	return get_tree().current_scene
