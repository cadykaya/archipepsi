class_name ClassPlate
extends Node3D
## A pressure plate that reads an object's mass CLASS, not its kilograms.
##
## **The distinction is the room.** EX50-033 §8: "Optional debris cannot
## accumulate into HEAVY on this semantic plate; the source contract
## explicitly distinguishes that from summed mass." So this never adds
## anything up. It asks whether any single occupant is of the required
## class or heavier, and ten crates of the wrong class are still the
## wrong class.
##
## **The player does not count — unless the plate says it does.** §3:
## "the player's own mass class does not count toward its threshold IN
## THIS ARRANGEMENT." That was EX50-033's arrangement, and it was applied
## to every plate: nothing could be opened by walking onto it. D-10 made
## it a declared property instead: `SensorNode.counts_player`, default
## `false`, so EX50-033 and every plate built before it keep exactly the
## behaviour they had. A plate that sets it reads the player's own class
## (`Player.mass_class()`, `MEDIUM` at 80 kg) like any other occupant's.
##
## The exclusion is still written down rather than left to depend on a
## threshold: now that the player HAS a class, the group check is the
## only thing keeping an object-only `MEDIUM` plate object-only.
##
## **It decides nothing.** It reports whether it is satisfied; the room
## decides that a satisfied plate closes a shutter. `PoweredLink` wired
## its plate straight to its door and could therefore only ever be that
## one machine.

## Whether a qualifying occupant is present has changed.
signal occupancy_changed(satisfied: bool)

const LAMP := Vector3(0.28, 0.06, 0.28)

## The class an occupant must be, or heavier.
var requires := MassClass.HEAVY
## Whether the player's own body is an occupant. `false` is the object-
## only plate EX50-033 describes and the default for every plate.
var counts_player := false
var size := Vector3(2.4, 0.12, 2.4)

var _sensor: Area3D = null
var _lamp: MeshInstance3D = null
var _satisfied := false
var _theme := "concrete_facility"


static func create(plate_size: Vector3, needs := MassClass.HEAVY,
		theme := "concrete_facility", player_counts := false) -> ClassPlate:
	var made := ClassPlate.new()
	made.name = "ClassPlate"
	made.size = plate_size
	made.requires = needs
	made._theme = theme
	made.counts_player = player_counts
	return made


func _ready() -> void:
	var kerb := StaticBody3D.new()
	kerb.name = "Kerb"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	kerb.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.accent_mat(_theme)
	kerb.add_child(mesh_node)
	add_child(kerb)
	# THE SENSING VOLUME sits ON the plate rather than inside it, so what
	# it counts is what is resting on the plate.
	_sensor = Area3D.new()
	_sensor.name = "Sensor"
	var sense := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(size.x, 0.6, size.z)
	sense.shape = volume
	_sensor.add_child(sense)
	_sensor.position = Vector3(0.0, size.y * 0.5 + 0.3, 0.0)
	add_child(_sensor)
	# The class glyph. §4 wants the plate's own reading legible, so a
	# player can tell "released because the class changed" from "broken".
	_lamp = MeshInstance3D.new()
	_lamp.name = "Glyph"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = LAMP
	_lamp.mesh = lamp_mesh
	_lamp.position = Vector3(size.x * 0.5 - 0.3, size.y * 0.5 + 0.04,
			size.z * 0.5 - 0.3)
	add_child(_lamp)
	_paint()


func _physics_process(_delta: float) -> void:
	var now := satisfied()
	if now == _satisfied:
		return
	_satisfied = now
	_paint()
	occupancy_changed.emit(now)


## Every body resting on the plate that has a mass class at all.
func occupants() -> Array[Node]:
	var out: Array[Node] = []
	if _sensor == null:
		return out
	for body in _sensor.get_overlapping_bodies():
		if body.is_in_group("player") and not counts_player:
			continue
		if MassClass.of_node(body) == "":
			continue
		out.append(body)
	return out


## Is there a qualifying occupant right now?
##
## ANY ONE OF THEM, never all of them added together.
func satisfied() -> bool:
	for body in occupants():
		if MassClass.at_least(MassClass.of_node(body), requires):
			return true
	return false


## What the plate is reading, for a readout and for a suite.
func reading() -> Dictionary:
	var classes: Array[String] = []
	for body in occupants():
		classes.append(MassClass.of_node(body))
	return {"requires": requires, "classes": classes,
			"counts_player": counts_player, "satisfied": satisfied()}


func _paint() -> void:
	if _lamp == null:
		return
	_lamp.material_override = ThemeMaterials.glow_material(
			Color(1.0, 0.45, 0.35) if _satisfied
			else Color(0.4, 0.85, 1.0), 2.4 if _satisfied else 0.9)
