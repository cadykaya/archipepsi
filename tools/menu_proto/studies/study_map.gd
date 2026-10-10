class_name StudyMap
extends FaceMap
## The Map for the direction studies: the prototype's own LENS -- the same
## truthful miniature, the same lens, tags, frames and link ring -- with the
## surround and the detail left to the direction. A study draws the wall
## round the window its own way, and its own detail panel; nothing inside
## the window is restyled, rearranged or recoloured.


var frames: Array[MeshInstance3D] = []


## The prototype's own opening -- the wall round the window, its reveal, the
## strips that shut the gap above and below the wall, the dark far behind
## and the miniature's light -- with the wall's pieces kept, so the
## direction's own wall can dress them.
func _window() -> void:
	port = false
	super._window()
	for c: Node in face.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == kit.wall_material():
			frames.append(c)


## Dress the wall round the window in the direction's own wall.
func dress(m: Material) -> void:
	for n: MeshInstance3D in frames:
		n.material_override = m


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
