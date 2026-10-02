class_name AttachPoint
extends RefCounted
## Design 2 §4.8's `AttachPoint`: where on a body another may be joined.
##
##     AttachPoint:
##       local_transform   : transform
##       accepts_materials : list[enum { METAL, STONE, WOOD, COMPOSITE, GLASS }]
##       occupied_by       : Id? = null
##
## Authored by whatever builds the body. No room authors one today, so
## ATTACH (O05-08.3) has nothing to join at outside its own tests.

var local_transform := Transform3D.IDENTITY
var accepts_materials: Array[String] = []
var occupied_by: ManipulableBody = null


static func at(local: Transform3D, accepts: Array[String]) -> AttachPoint:
	var point := AttachPoint.new()
	point.local_transform = local
	point.accepts_materials = accepts
	return point
