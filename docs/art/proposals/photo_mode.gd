class_name PhotoMode
extends Node
## A detachable free camera, for players and for development.
##
## ## THIS FILE IS A PROPOSAL. THE ART LANE DID NOT INSTALL IT.
##
## It belongs at `godot/scripts/ui/photo_mode.gd` and the art lane does not
## write to `godot/`. It is delivered here, complete and ready to drop in,
## so that adding it is engineering's decision and engineering's commit.
##
## To install:
##
##   1. move this file to `godot/scripts/ui/photo_mode.gd`
##   2. add `PhotoMode` to the scene that owns the player camera -- in the
##      Hub that is `hub.gd`, and a Zone gets one from its own builder:
##
##          var photo := PhotoMode.new()
##          add_child(photo)
##
##   3. bind a key. `_unhandled_input` below listens for F2 directly rather
##      than an InputMap action, so nothing has to be added to the project
##      settings for it to work; swap that for an action if you would
##      rather it be rebindable.
##
## It touches no gameplay state. It pauses the tree, remembers whichever
## camera was current, and puts it back on exit.
##
## ## Two jobs, one implementation
##
## **For players** -- pause, fly anywhere, frame a shot, hide the interface,
## save a PNG. The thing every game of this shape ends up wanting.
##
## **For development** -- `frame()` and `frame_orbit()` let a script place
## this camera deliberately. The art lane's own bench does the equivalent in
## `tools/artpreview/camera_rig.gd`, which is where the framing maths here
## comes from; this is the in-game half of the same idea, so a shot composed
## in one can be reproduced in the other.
##
## ## Controls
##
##   F2              toggle
##   WASD            move; Q / E down and up
##   Shift / Ctrl    faster / slower
##   mouse           look
##   Z / X           roll, and C to level it
##   wheel           lens, 14 mm to 135 mm
##   H               hide the interface
##   Enter           save a PNG to user://photos
##   Esc             leave

const MOVE_SPEED := 6.0
const FAST := 4.0
const SLOW := 0.2
const LOOK := 0.0022
const ROLL_SPEED := 1.4
const SHOT_DIR := "user://photos"

## 35 mm equivalents, and the range a wheel scrolls through.
const LENS_MIN := 14.0
const LENS_MAX := 135.0
const SENSOR_W := 36.0

@export var enabled := true

var camera: Camera3D
var _active := false
var _previous: Camera3D
var _hidden := false
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _lens := 35.0
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = false
	add_child(camera)
	_build_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F2:
				toggle()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE when _active:
				close()
				get_viewport().set_input_as_handled()
			KEY_H when _active:
				set_interface_hidden(not _hidden)
				get_viewport().set_input_as_handled()
			KEY_ENTER when _active:
				var path := capture()
				if path != "":
					print("[photo] %s" % path)
				get_viewport().set_input_as_handled()
			KEY_C when _active:
				_roll = 0.0
				get_viewport().set_input_as_handled()
	if not _active:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * LOOK
		_pitch = clampf(_pitch - event.relative.y * LOOK, -1.55, 1.55)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_lens(_lens * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_lens(_lens / 1.1)


func _process(delta: float) -> void:
	if not _active:
		return
	var speed := MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FAST
	elif Input.is_key_pressed(KEY_CTRL):
		speed *= SLOW
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_E): move.y += 1.0
	if Input.is_key_pressed(KEY_Q): move.y -= 1.0
	if Input.is_key_pressed(KEY_Z): _roll -= ROLL_SPEED * delta
	if Input.is_key_pressed(KEY_X): _roll += ROLL_SPEED * delta

	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	camera.global_position += basis * move.normalized() * speed * delta
	camera.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, _roll))
	_update_hint()


# ----------------------------------------------------------------------
# opening and closing
# ----------------------------------------------------------------------

func toggle() -> void:
	if _active:
		close()
	else:
		open()


func open() -> void:
	if _active or not enabled:
		return
	_previous = get_viewport().get_camera_3d()
	if _previous != null:
		camera.global_transform = _previous.global_transform
		var e := _previous.global_basis.get_euler()
		_pitch = e.x
		_yaw = e.y
		_roll = 0.0
	camera.current = true
	_active = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hint.visible = not _hidden
	_update_hint()


func close() -> void:
	if not _active:
		return
	_active = false
	camera.current = false
	if _previous != null and is_instance_valid(_previous):
		_previous.current = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_interface_hidden(false)
	_hint.visible = false


func is_active() -> bool:
	return _active


# ----------------------------------------------------------------------
# the scripted half
# ----------------------------------------------------------------------

## Place the camera deliberately and take over the view, without pausing or
## grabbing the mouse. The entry point for automated shots: no player input
## is involved and the game keeps running.
func frame(from: Vector3, look_at: Vector3, lens_mm: float = 35.0) -> void:
	_previous = get_viewport().get_camera_3d()
	set_lens(lens_mm)
	camera.look_at_from_position(from, look_at, Vector3.UP)
	var e := camera.global_basis.get_euler()
	_pitch = e.x
	_yaw = e.y
	_roll = 0.0
	camera.current = true


## Orbit a point. `azimuth` 0 looks from -Z toward +Z; `elevation` is
## degrees above horizontal.
func frame_orbit(target: Vector3, radius: float, azimuth_deg: float,
		elevation_deg: float, lens_mm: float = 35.0) -> void:
	var az := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	var offset := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	frame(target + offset * radius, target, lens_mm)


## Frame an AABB so it FITS inside `fill` of the frame, solving the distance.
## Same maths as `tools/artpreview/camera_rig.gd`, so a shot composed on the
## art bench reproduces here.
func frame_box(box: AABB, fill: float, azimuth_deg: float,
		elevation_deg: float, lens_mm: float = 35.0) -> void:
	set_lens(lens_mm)
	var az := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	var dir := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	var forward := -dir
	var right := Vector3.UP.cross(forward).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := forward.cross(right).normalized()
	var half := box.size * 0.5
	var half_up: float = absf(half.x * up.x) + absf(half.y * up.y) \
			+ absf(half.z * up.z)
	var half_right: float = absf(half.x * right.x) + absf(half.y * right.y) \
			+ absf(half.z * right.z)
	var vp := get_viewport().get_visible_rect().size
	var aspect: float = vp.x / maxf(1.0, vp.y)
	var need: float = maxf(half_up / maxf(0.01, fill),
			half_right / maxf(0.01, fill) / aspect)
	var half_v := deg_to_rad(camera.fov) * 0.5
	var half_fwd: float = absf(half.x * forward.x) + absf(half.y * forward.y) \
			+ absf(half.z * forward.z)
	var centre := box.get_center()
	frame(centre + dir * (need / tan(half_v) + half_fwd), centre, lens_mm)


## Lens in 35 mm equivalent millimetres, converted to Godot's VERTICAL fov
## for this viewport's aspect. `Camera3D.fov` is the vertical angle under
## the default KEEP_HEIGHT, which is the detail that makes raw fov a bad
## unit to compose in.
func set_lens(mm: float) -> void:
	_lens = clampf(mm, LENS_MIN, LENS_MAX)
	var vp := get_viewport().get_visible_rect().size
	var aspect: float = vp.x / maxf(1.0, vp.y)
	var h_fov := 2.0 * atan(SENSOR_W * 0.5 / _lens)
	camera.fov = rad_to_deg(2.0 * atan(tan(h_fov * 0.5) / aspect))


## Saves the current frame. Returns the path, or "" if it failed.
func capture(path: String = "") -> String:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return ""
	if path == "":
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		path = "%s/%s.png" % [SHOT_DIR,
				Time.get_datetime_string_from_system().replace(":", "-")]
	if img.save_png(path) != OK:
		return ""
	return path


# ----------------------------------------------------------------------
# the interface
# ----------------------------------------------------------------------

func set_interface_hidden(hidden: bool) -> void:
	_hidden = hidden
	var root := get_tree().root
	for child in root.get_children():
		if child is CanvasLayer and child != _hint.get_parent():
			(child as CanvasLayer).visible = not hidden
	_hint.visible = _active and not hidden


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_hint = Label.new()
	_hint.position = Vector2(16, 16)
	_hint.visible = false
	layer.add_child(_hint)


func _update_hint() -> void:
	if not _hint.visible:
		return
	var p := camera.global_position
	_hint.text = "PHOTO  %.0f mm   %.1f, %.1f, %.1f   yaw %.0f  pitch %.0f%s\n" \
			% [_lens, p.x, p.y, p.z, rad_to_deg(_yaw), rad_to_deg(_pitch),
			("  roll %.0f" % rad_to_deg(_roll)) if absf(_roll) > 0.01 else ""] \
			+ "WASD/QE move   SHIFT/CTRL speed   Z/X/C roll   WHEEL lens" \
			+ "   H interface   ENTER save   ESC exit"
