class_name StudyGeo
extends RefCounted
## Geometry for the direction studies, in PAGE PX on a face: blocks, discs
## and rings (jacks, knobs, levers), extruded outlines (boards, tabs,
## shutters) and tubes (cables). Everything is LIT, so the box's one light
## gives it its form and its shadows -- the physical, hand-built quality
## the studies are after comes from real depth, not from drawn bevels.
##
## A face's local frame (Kit.at): x right, y up, the wall at z = -1, depth
## toward the eye. Godot takes CLOCKWISE triangles as front faces; `_tri`
## winds every triangle to face its own normal, so the light is right
## whichever way a shape was traced.


static func mat(colour: Color, metal := 0.0, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = metal
	m.roughness = rough
	m.metallic_specular = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func unlit(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func P(page: Vector2, z: float) -> Vector3:
	return Kit.at(page, z)


static func _node(parent: Node3D, mesh: Mesh, material: Material,
		shadow := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


## A box over a page rect, from depth z0 to z1.
static func block(parent: Node3D, rect: Rect2, z0: float, z1: float,
		material: Material, shadow := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x * Kit.px(), rect.size.y * Kit.px(), maxf(z1 - z0, 0.0005))
	var n := _node(parent, box, material, shadow)
	n.position = P(rect.get_center(), (z0 + z1) * 0.5)
	return n


## A cylinder whose axis points at the eye: a jack's body, a knob, a pin.
static func disc(parent: Node3D, centre: Vector2, r_px: float, z0: float, z1: float,
		material: Material, sides := 28, shadow := true) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_px * Kit.px()
	c.bottom_radius = r_px * Kit.px()
	c.height = maxf(z1 - z0, 0.0005)
	c.radial_segments = sides
	c.rings = 1
	var n := _node(parent, c, material, shadow)
	n.rotation = Vector3(PI * 0.5, 0, 0)
	n.position = P(centre, (z0 + z1) * 0.5)
	return n


## A short cylinder round a cable (a band, a sleeve, a lacing tie): along
## the page's y when `vertical`, else along its x.
static func sleeve(parent: Node3D, centre: Vector2, vertical: bool, r_px: float,
		len_px: float, z: float, material: Material, sides := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_px * Kit.px()
	c.bottom_radius = r_px * Kit.px()
	c.height = len_px * Kit.px()
	c.radial_segments = sides
	c.rings = 1
	var n := _node(parent, c, material)
	if not vertical:
		n.rotation = Vector3(0, 0, PI * 0.5)
	n.position = P(centre, z)
	return n


## A ring facing the eye (a jack's collar, a lamp's bezel).
static func ring(parent: Node3D, centre: Vector2, r_in: float, r_out: float,
		z: float, material: Material, shadow := true) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in * Kit.px()
	t.outer_radius = r_out * Kit.px()
	t.rings = 32
	t.ring_segments = 10
	var n := _node(parent, t, material, shadow)
	n.rotation = Vector3(PI * 0.5, 0, 0)
	n.position = P(centre, z)
	return n


## A flat page polygon extruded from z0 to z1: a board, a tab, a shutter.
## The front face is triangulated; the sides are quads facing outward.
static func slab(parent: Node3D, poly: PackedVector2Array, z0: float, z1: float,
		material: Material, shadow := true) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		_tri(verts, norms, P(poly[idx[i]], z1), P(poly[idx[i + 1]], z1),
				P(poly[idx[i + 2]], z1), Vector3(0, 0, 1))
	var n := poly.size()
	var ccw := _area(poly) > 0.0        # in page px, y down
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var d := (b - a).normalized()
		# outward, in page px (y down): for a clockwise-on-screen outline
		# the outside is to the left of each edge.
		var out2 := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)
		var out3 := Vector3(out2.x, -out2.y, 0).normalized()
		var a0 := P(a, z0)
		var a1 := P(a, z1)
		var b0 := P(b, z0)
		var b1 := P(b, z1)
		_tri(verts, norms, a0, a1, b1, out3)
		_tri(verts, norms, a0, b1, b0, out3)
	return _node(parent, _mesh(verts, norms), material, shadow)


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## A tube through face-local points, `r_px` page px thick: a cable. Frames
## are carried along the path (parallel transport), so it never twists.
static func tube(parent: Node3D, pts: Array, r_px: float, material: Material,
		sides := 10, shadow := true) -> MeshInstance3D:
	var r := r_px * Kit.px()
	var path: Array = []
	for p: Vector3 in pts:
		if path.is_empty() or (path[-1] as Vector3).distance_to(p) > 0.00005:
			path.append(p)
	if path.size() < 2:
		return _node(parent, ArrayMesh.new(), material, shadow)
	var rings: Array = []
	var t0 := ((path[1] as Vector3) - (path[0] as Vector3)).normalized()
	var ref := Vector3(0, 0, 1) if absf(t0.z) < 0.9 else Vector3(0, 1, 0)
	var nrm := t0.cross(ref).normalized()
	for i in path.size():
		var t: Vector3
		if i == 0:
			t = t0
		elif i == path.size() - 1:
			t = ((path[i] as Vector3) - (path[i - 1] as Vector3)).normalized()
		else:
			t = ((path[i + 1] as Vector3) - (path[i - 1] as Vector3)).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm).normalized()
		var ringv: Array = []
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ringv.append(nrm * cos(a) + bin * sin(a))
		rings.append(ringv)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in path.size() - 1:
		var p0: Vector3 = path[i]
		var p1: Vector3 = path[i + 1]
		for s in sides:
			var s2 := (s + 1) % sides
			var n00: Vector3 = rings[i][s]
			var n01: Vector3 = rings[i][s2]
			var n10: Vector3 = rings[i + 1][s]
			var n11: Vector3 = rings[i + 1][s2]
			_tri_n(verts, norms, [p0 + n00 * r, p1 + n10 * r, p1 + n11 * r],
					[n00, n10, n11])
			_tri_n(verts, norms, [p0 + n00 * r, p1 + n11 * r, p0 + n01 * r],
					[n00, n11, n01])
	return _node(parent, _mesh(verts, norms), material, shadow)


## A hanging cable between two page points: a parabola of `sag` px down,
## standing `z_mid` off the wall at its middle and `za`/`zb` at its ends.
static func sag(a: Vector2, b: Vector2, sag_px: float, za: float, zb: float,
		z_mid: float, n := 28) -> Array:
	var out: Array = []
	for i in n + 1:
		var u := float(i) / float(n)
		var p := a.lerp(b, u) + Vector2(0, 4.0 * sag_px * u * (1.0 - u))
		var z := lerpf(za, zb, u) + (z_mid - (za + zb) * 0.5) * 4.0 * u * (1.0 - u)
		out.append(P(p, z))
	return out


## A smooth path through page points (Catmull-Rom), at one depth.
static func smooth(page: Array, z: float, per := 10) -> Array:
	var out: Array = []
	var n := page.size()
	for i in n - 1:
		var p0: Vector2 = page[maxi(i - 1, 0)]
		var p1: Vector2 = page[i]
		var p2: Vector2 = page[i + 1]
		var p3: Vector2 = page[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			out.append(P(p, z))
	out.append(P(page[-1], z))
	return out


## A smooth path through face-local (or world) points (Catmull-Rom).
static func smooth3(pts: Array, per := 8) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[-1])
	return out


## An orthogonal run with a round bend of `radius` px at every corner: how
## a harness is laid, never a sharp kink.
static func routed(page: Array, radius: float, z: float, per := 7) -> Array:
	var out: Array = [P(page[0], z)]
	for i in range(1, page.size() - 1):
		var a: Vector2 = page[i - 1]
		var p: Vector2 = page[i]
		var b: Vector2 = page[i + 1]
		var d1 := (p - a).normalized()
		var d2 := (b - p).normalized()
		var r := minf(radius, minf(a.distance_to(p), p.distance_to(b)) * 0.5)
		var s := p - d1 * r
		var e := p + d2 * r
		for k in per + 1:
			var t := float(k) / float(per)
			# a quadratic through the corner: a round, even bend
			var q := s.lerp(p, t).lerp(p.lerp(e, t), t)
			out.append(P(q, z))
	out.append(P(page[-1], z))
	return out


## `routed` for face-local (or world) points: every corner a round bend of
## `radius` (world units).
static func routed3(pts: Array, radius: float, per := 6) -> Array:
	var out: Array = [pts[0]]
	for i in range(1, pts.size() - 1):
		var a: Vector3 = pts[i - 1]
		var p: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r := minf(radius, minf(a.distance_to(p), p.distance_to(b)) * 0.5)
		var s := p - (p - a).normalized() * r
		var e := p + (b - p).normalized() * r
		for k in per + 1:
			var t := float(k) / float(per)
			out.append(s.lerp(p, t).lerp(p.lerp(e, t), t))
	out.append(pts[-1])
	return out


## A rounded rectangle, as a polygon (page px, clockwise on screen).
static func rrect(r: Rect2, rad: float, seg := 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [[r.position + Vector2(r.size.x - rad, rad), -PI * 0.5],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI]]
	for c: Array in corners:
		for k in seg + 1:
			var a: float = float(c[1]) + (PI * 0.5) * float(k) / float(seg)
			out.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return out


## A circle as a polygon.
static func circle(c: Vector2, r: float, seg := 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in seg:
		var a := TAU * float(k) / float(seg)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _tri(verts: PackedVector3Array, norms: PackedVector3Array, a: Vector3,
		b: Vector3, c: Vector3, n: Vector3) -> void:
	# clockwise front: the right-hand normal points AWAY from `n`
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	verts.append(a)
	verts.append(b)
	verts.append(c)
	for k in 3:
		norms.append(n)


static func _tri_n(verts: PackedVector3Array, norms: PackedVector3Array,
		p: Array, n: Array) -> void:
	var avg: Vector3 = ((n[0] as Vector3) + (n[1] as Vector3) + (n[2] as Vector3)).normalized()
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3)
			- (p[0] as Vector3)).dot(avg) > 0.0:
		p = [p[0], p[2], p[1]]
		n = [n[0], n[2], n[1]]
	for k in 3:
		verts.append(p[k])
		norms.append(n[k])


static func _mesh(verts: PackedVector3Array, norms: PackedVector3Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
