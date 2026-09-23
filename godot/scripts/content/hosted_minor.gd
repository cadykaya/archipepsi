class_name HostedMinor
extends Node3D
## O05-06. WHAT A MINOR OFFERS THE ZONE THAT HOSTS IT, and nothing else.
##
## A hosted minor is a registry room shell (`godot/content/minors/`)
## whose scene builds a development scenario's own room -- one
## implementation, two owners. The Zone owns what a Zone owns: which
## latches the campaign accepted, and the HUD. So a minor says two things
## outward and is told one thing back:
##
## * `latched(latch_id)` when a PLAYER fires one of its declared latches
##   (the bridge records it as `minor_<room>/<latch_id>`, and accepts
##   only the latches the minor's occurrence contract declares);
## * `said(text)`, its own machinery's lines, for the Zone's HUD;
## * `restore(latch_ids)`, the accepted latches, before anyone sees the
##   room. A restored latch announces nothing, so nothing is reported
##   back that the bridge has just sent.
##
## A minor whose contract declares CARRIERS (EX50-011 §9: "Carrier poses,
## destinations and hold states are package-local") also says
## `carrier_rested` when one comes to rest -- never while it moves -- and
## is handed the accepted rests in `restore_carriers` before the player
## arrives. `player_died` is where a minor applies its own death rule.

signal latched(latch_id: String)
signal said(text: String)
signal carrier_rested(carrier_id: String, t: float, destination: String,
		held: bool)


## Put the room back from the latches the campaign accepted. Each minor
## overrides it for the latches its contract declares.
func restore(_latch_ids: Array) -> void:
	pass


## `{carrier_id: [t, destination, held]}`, the rests the campaign
## accepted. Silent, like `restore`.
func restore_carriers(_states: Dictionary) -> void:
	pass


## The Zone's player died. Most minors have nothing to do.
func player_died() -> void:
	pass


func _marker(marker_name: String, at: Vector3, yaw: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	marker.rotation.y = deg_to_rad(yaw)
	add_child(marker)
