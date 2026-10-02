class_name RailControls
extends Node
## Binds shootable receivers to one carrier, and decides between them.
##
## **Why the arbitration is not in the carrier.** The carrier is the
## vehicle: it knows docks, links, and its own brakes. Which controls
## exist, and what happens when two of them are hit at once, is a
## property of the STATION -- so a carrier that owned a list of receivers
## would be a vehicle that knew about the platform it is standing at.
##
## **The conflicting pair.** A shotgun at close range, a splash, or two
## players can set FORWARD and BACK off in the same instant. Whichever
## the engine happened to deliver first would win, and it would win
## differently on another machine and in another frame. So commands are
## collected for a frame and resolved together: one direction travels,
## two opposed directions cancel, and the cancel SAYS so rather than
## quietly doing nothing and leaving the player to shoot again.
##
## **Every refusal comes out of one place.** A receiver's command can be
## turned down by the station (conflict) or by the carrier (no link,
## already moving, held). Both arrive on this object's `refused`, because
## a player-facing readout should not have to know which of the two
## turned them down.

signal refused(reason: String, detail: String)
signal commanded(direction: int)

var carrier: RailCarrier = null

## Commands received since the last resolution. Cleared every frame.
var _pending: Array[int] = []
var _receivers: Array[RailReceiver] = []


static func create(for_carrier: RailCarrier) -> RailControls:
	var made := RailControls.new()
	made.name = "RailControls"
	made.carrier = for_carrier
	if for_carrier != null:
		for_carrier.refused.connect(made._relay)
	return made


## Put a receiver on this station. The receiver keeps its own re-arm
## window; this only listens.
func add(receiver: RailReceiver) -> void:
	if receiver in _receivers:
		return
	_receivers.append(receiver)
	receiver.commanded.connect(_take)


func receivers() -> Array[RailReceiver]:
	return _receivers


func _physics_process(_delta: float) -> void:
	resolve()


## Settle this frame's commands.
##
## SPLIT OUT so a suite can step the station by hand, and because the
## one-frame collection window is the whole mechanism: a resolution that
## ran the instant a receiver fired could never see the second half of a
## conflicting pair.
func resolve() -> void:
	if _pending.is_empty():
		return
	var forward := _pending.has(RailCarrier.FORWARD)
	var back := _pending.has(RailCarrier.BACK)
	_pending.clear()
	if forward and back:
		refused.emit("conflicting", "FORWARD and BACK were commanded in "
			+ "the same moment, so the railway does neither")
		return
	var direction := RailCarrier.FORWARD if forward else RailCarrier.BACK
	commanded.emit(direction)
	if carrier != null:
		carrier.request(direction)


func _take(direction: int) -> void:
	_pending.append(direction)


func _relay(reason: String, detail: String) -> void:
	refused.emit(reason, detail)
