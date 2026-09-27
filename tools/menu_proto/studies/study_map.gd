class_name StudyMap
extends FaceMap
## The Map for the direction studies: the prototype's own LENS -- the same
## truthful miniature, the same lens, tags, frames and link ring -- with the
## surround and the detail left to the direction. A study draws the wall
## round the window its own way, and its own detail panel; nothing inside
## the window is restyled, rearranged or recoloured.


## Only what makes the window work: the dark ground far behind the
## miniature, and the miniature's own light. The direction draws the rest.
func _window() -> void:
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(14, 9)
	back.mesh = quad
	back.material_override = kit.flat(Color("#07090b"))
	back.position = Vector3(0, 0, -6.0)
	face.add_child(back)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-62), deg_to_rad(28), 0)
	light.light_energy = 0.9
	light.light_cull_mask = 2
	face.add_child(light)


## The detail is the direction's: its own panel, from MapFace's own text.
func _build_panel() -> void:
	pass


## The study's fixed state: a place picked, its detail open, the lens at
## rest, the Journal's link ringed. `shift` slides the miniature clear of
## the direction's detail panel (page px, negative is left).
func pose(room: String, link_to: Dictionary, shift: float) -> void:
	var keep := kit.reduced
	kit.reduced = true
	pick(room)
	expanded = true
	lens.shift = shift
	set_link(link_to)
	_refresh_marks()
	_apply()
	kit.reduced = keep


func details_of(room: String) -> String:
	return str(data["details"].get(room, ""))
