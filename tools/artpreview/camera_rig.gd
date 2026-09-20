class_name CameraRig
extends RefCounted
## A camera you can aim in the language a camera is actually aimed in.
##
## Every bench in this project placed its cameras with raw
## `look_at_from_position(Vector3(-5.6, 2.4, -2.4), Vector3(-1.0, 2.1, 1.9))`
## and a 90 degree fov, and every one of them cost three or four
## build-render-look cycles to tune. Worse, two of them computed screen
## positions from a formula about the camera instead of asking the camera,
## and put their labels a third of a frame from the things they named
## (ART_LESSONS L-34).
##
## So this is the vocabulary instead:
##
##   rig.lens(35)                          a 35 mm lens
##   rig.frame(box, 0.8, 25, 10)           fill 80% of frame, from 25 deg round
##                                         and 10 deg up
##   rig.orbit(target, 6.0, 25, 10)        or place it by hand at 6 m
##   rig.eye(Vector3(0, 0, 3), 180)        or stand where the player stands
##   rig.screen(point)                     and ask where something drew
##
## `frame()` is the one that saves the most time. Give it what to look at
## and how much of the frame it should occupy, and the distance is solved
## rather than guessed -- so "a bit closer" is a number between 0 and 1
## instead of another three renders.
##
## ## Lenses, and why they are in millimetres
##
## Godot's `Camera3D.fov` is the VERTICAL angle when `keep_aspect` is
## KEEP_HEIGHT, which is the default. That is the fact both label bugs came
## from, and it makes fov a bad unit to think in: 90 vertical degrees is a
## different picture at 16:9 than at 4:3, and neither matches what anyone
## means by "wide".
##
## Focal length does not have that problem. These are 35 mm equivalents
## against a 36 x 24 mm frame, converted to Godot's vertical fov for the
## viewport's actual aspect, so a 50 mm lens looks like a 50 mm lens at any
## output size.
##
##   14 mm   very wide, visible distortion at the edges
##   24 mm   wide -- architecture, whole rooms
##   35 mm   the honest all-rounder
##   50 mm   normal; roughly what an eye picks out
##   85 mm   a portrait lens; flattens, isolates
##
## The GAME's own camera is not any of these -- `constants.gd` sets 90
## degrees -- so `game_lens()` exists to say "shoot this the way the player
## will actually see it" without pretending that is a focal length.

const SENSOR_W := 36.0
const SENSOR_H := 24.0

var cam: Camera3D
var size: Vector2i


func _init(camera: Camera3D, viewport_size: Vector2i) -> void:
	cam = camera
	size = viewport_size
	cam.keep_aspect = Camera3D.KEEP_HEIGHT


# ----------------------------------------------------------------------
# lens
# ----------------------------------------------------------------------

## Set the lens in 35 mm equivalent millimetres. Returns self, so calls chain.
func lens(mm: float) -> CameraRig:
	# The horizontal angle a 36 mm-wide frame gives at this focal length,
	# then the vertical angle that produces at THIS viewport's aspect --
	# because Godot wants the vertical one and the aspect is not 3:2.
	var h_fov := 2.0 * atan(SENSOR_W * 0.5 / maxf(1.0, mm))
	var aspect := float(size.x) / float(size.y)
	cam.fov = rad_to_deg(2.0 * atan(tan(h_fov * 0.5) / aspect))
	return self


## The game's own lens, from the engine's own constant. Not a focal length,
## on purpose: 90 degrees is a gameplay decision, not a photographic one.
func game_lens(fov_deg: float = 90.0) -> CameraRig:
	cam.fov = fov_deg
	return self


## The vertical half-angle, in radians. Everything below solves against it.
func _half_v() -> float:
	return deg_to_rad(cam.fov) * 0.5


# ----------------------------------------------------------------------
# placement
# ----------------------------------------------------------------------

## Point the camera from one place at another. The raw case, kept because
## sometimes you do just know where the camera goes.
func look(from: Vector3, at: Vector3, up: Vector3 = Vector3.UP) -> CameraRig:
	cam.look_at_from_position(from, at, up)
	return self


## Place the camera on a sphere around a target.
##
##   azimuth   degrees around the target. 0 looks from -Z toward +Z, which
##             is the direction every glb in this project faces after the
##             glTF conversion, so 0 is "the front".
##   elevation degrees above the horizontal. Positive looks down.
func orbit(target: Vector3, radius: float, azimuth: float,
		elevation: float) -> CameraRig:
	return look(target + _offset(azimuth, elevation) * radius, target)


## Frame a box so it FITS inside `fill` of the frame, and solve the
## distance rather than guessing it.
##
## `fill` is the fraction of the frame the subject may occupy: 1.0 touches
## the edges, 0.8 leaves a comfortable margin, 0.35 is a wide establishing
## shot with the subject small in it.
##
## Whichever axis runs out first decides, so a wide flat subject -- the
## 9.0 x 3.5 m Epsilon installation, say -- ends up bound by WIDTH and sits
## shorter than `fill` vertically. That is fitting working correctly, not a
## miss: the alternative is a subject that fills the height and runs off
## both sides.
##
## The projected half-height is computed from the box's real half-extents
## against the camera's own up and right axes, not from its bounding SPHERE.
## A sphere is easy and wrong: a 9 x 3.5 x 3.5 m installation has a 5.2 m
## bounding radius against a 1.75 m half-height, so sphere-framing puts it
## a third of the way up the frame and every shot needs hand-correcting
## afterwards -- which is exactly what was happening.
func frame(box: AABB, fill: float, azimuth: float, elevation: float,
		target: Vector3 = Vector3.INF) -> CameraRig:
	var centre := box.get_center() if target == Vector3.INF else target
	var dir := _offset(azimuth, elevation)
	# The camera basis this direction implies, before the camera exists.
	var forward := -dir
	var right := Vector3.UP.cross(forward).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := forward.cross(right).normalized()
	var half := box.size * 0.5
	# Half-extent of the box projected onto each screen axis.
	var half_up: float = absf(half.x * up.x) + absf(half.y * up.y) \
			+ absf(half.z * up.z)
	var half_right: float = absf(half.x * right.x) + absf(half.y * right.y) \
			+ absf(half.z * right.z)
	var aspect := float(size.x) / float(size.y)
	# Whichever axis runs out of frame first decides the distance.
	var need_v: float = half_up / maxf(0.01, fill)
	var need_h: float = half_right / maxf(0.01, fill) / aspect
	var distance: float = maxf(need_v, need_h) / tan(_half_v())
	# Plus the box's own depth toward the camera, or a wide lens clips into it.
	var half_fwd: float = absf(half.x * forward.x) + absf(half.y * forward.y) \
			+ absf(half.z * forward.z)
	return look(centre + dir * (distance + half_fwd), centre)


## Stand where the player stands. `at` is a FLOOR position -- the eye height
## is added -- and `yaw` is degrees, 0 looking toward +Z.
func eye(at: Vector3, yaw: float, pitch: float = 0.0,
		eye_height: float = 1.6) -> CameraRig:
	var from := at + Vector3(0, eye_height, 0)
	var yr := deg_to_rad(yaw)
	var pr := deg_to_rad(pitch)
	var dir := Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr))
	return look(from, from + dir)


# ----------------------------------------------------------------------
# relative moves -- for nudging a shot that is nearly right
# ----------------------------------------------------------------------

## Toward or away from what the camera is looking at.
func dolly(metres: float) -> CameraRig:
	cam.position += -cam.global_transform.basis.z * metres
	return self

## Sideways, without turning.
func truck(metres: float) -> CameraRig:
	cam.position += cam.global_transform.basis.x * metres
	return self

## Up or down, without turning.
func pedestal(metres: float) -> CameraRig:
	cam.position += Vector3.UP * metres
	return self

## Roll the frame. Dutch angles are a real tool and this project's subject
## -- a facility with something wrong in it -- is one of the few that earns
## one. Use it sparingly and never on a shot that is measuring something.
func roll(degrees: float) -> CameraRig:
	cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(degrees))
	return self


# ----------------------------------------------------------------------
# asking the camera
# ----------------------------------------------------------------------

## Where a world point drew, in pixels. ASK, never derive: two benches
## computed this from a half-extent formula and put every label in the
## wrong place, because Godot's fov is vertical and the formula assumed
## horizontal.
func screen(world: Vector3) -> Vector2:
	return cam.unproject_position(world)

## Whether a world point is in front of the camera and inside the frame.
func on_screen(world: Vector3) -> bool:
	if cam.is_position_behind(world):
		return false
	var at := screen(world)
	return at.x >= 0 and at.y >= 0 and at.x < size.x and at.y < size.y


# ----------------------------------------------------------------------
# guides
# ----------------------------------------------------------------------

## Composition guides, drawn over a captured frame.
##
## Thirds, a centre cross and a horizon line at the camera's own eye level.
## The horizon is the useful one: it is where the camera is actually
## pointing, and a shot whose horizon is not where it was meant to be is a
## shot that will be re-taken after somebody notices in a week.
static func guides(image: Image, rig: CameraRig,
		colour: Color = Color(1.0, 0.83, 0.36, 1.0)) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var faint := Color(colour.r, colour.g, colour.b, 1.0).lerp(
			Color(0.5, 0.5, 0.5), 0.55)
	for i in [1, 2]:
		_vline(image, w * i / 3, faint)
		_hline(image, h * i / 3, faint)
	# Centre cross.
	for d in range(-14, 15):
		_dot(image, w / 2 + d, h / 2, colour)
		_dot(image, w / 2, h / 2 + d, colour)
	# The horizon: unproject a point straight ahead at the camera's height.
	var ahead: Vector3 = rig.cam.global_position \
			- rig.cam.global_transform.basis.z * 50.0
	ahead.y = rig.cam.global_position.y
	if not rig.cam.is_position_behind(ahead):
		var y := int(rig.screen(ahead).y)
		if y >= 0 and y < h:
			for x in range(0, w, 6):
				_dot(image, x, y, colour)
				_dot(image, x + 1, y, colour)

static func _hline(image: Image, y: int, colour: Color) -> void:
	if y < 0 or y >= image.get_height():
		return
	for x in image.get_width():
		image.set_pixel(x, y, colour)

static func _vline(image: Image, x: int, colour: Color) -> void:
	if x < 0 or x >= image.get_width():
		return
	for y in image.get_height():
		image.set_pixel(x, y, colour)

static func _dot(image: Image, x: int, y: int, colour: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, colour)


# ----------------------------------------------------------------------

## Unit vector FROM the target TO the camera.
func _offset(azimuth: float, elevation: float) -> Vector3:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
