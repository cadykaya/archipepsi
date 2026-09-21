class_name RailJunction
extends Node
## One railway's persistent machinery, and the seam that keeps four
## different lifetimes apart.
##
## **The four lifetimes, which are not one thing.** The owner's addendum
## asks that these be distinguished and tested separately, because a
## system that treated them alike would either lose a repair the player
## earned or resurrect a moment they did not:
##
##   ACCEPTED SPAN REPAIR   persists across leave, return and reload.
##                          A latch fires; the commissioned link is
##                          RECOMPUTED from that latch at build time and
##                          is never separately saved (§5.4a).
##   A SPAN MID-TRAVEL      live only. The lever was pulled and the span
##                          never locked, so no latch fired and there is
##                          nothing to come back to. This is the case
##                          that makes "accepted consequence" mean
##                          something narrower than "something happened".
##   RECEIVER TIMERS        live only, and ephemeral by §5.4a. A control
##                          comes back armed.
##   CARRIER POSITION       restored to a SUPPORTED DOCK, never to a
##                          saved transform. Safe-machinery policy: a
##                          carrier resumed halfway across a span that
##                          this build has not commissioned would be a
##                          vehicle standing on track that is not there.
##
## **Why this is not `RailControls`.** That object arbitrates commands --
## which receiver fired, what happens when two fire at once -- and every
## byte of its state dies with the frame. This one owns the only state
## on the railway that outlives the session. Folding them together would
## put the two lifetimes in one class and make the boundary a matter of
## reading rather than of structure.
##
## **The junction never talks to the bridge.** It emits `latch_fired`
## and something above it decides whether there is a campaign to report
## to. A machine that sent its own intents could not be tested without
## one, and would report during a restore.

## The accepted consequence, once per span, ever.
signal latch_fired(package_id: String, latch_id: String)
## A link became crossable. Emitted for a latch AND for a restore,
## because the railway is equally open either way -- what differs is
## whether anything is reported, which is `latch_fired`'s job.
signal commissioned(link: int, latch_id: String)

var carrier: RailCarrier = null
## `^[a-z0-9_]+$`, at most 32 characters: the bridge's own rule for a
## package id, checked here so a malformed one is refused where it is
## built instead of at the far end of a WebSocket.
var package_id := "junction"

var _spans: Array[RailSpan] = []
var _controls: Array[AlignmentControl] = []


static func create(for_carrier: RailCarrier,
		package := "junction") -> RailJunction:
	var made := RailJunction.new()
	made.name = "RailJunction"
	made.carrier = for_carrier
	made.package_id = package
	return made


## Put a span, and the lever that sends it, on this junction.
func add(span: RailSpan, control: AlignmentControl) -> void:
	if span in _spans:
		return
	_spans.append(span)
	span.locked_home.connect(_on_locked)
	if control != null:
		_controls.append(control)
		control.operated.connect(_on_operated.bind(span))


func spans() -> Array[RailSpan]:
	return _spans


func controls() -> Array[AlignmentControl]:
	return _controls


## The global identity of a span's latch. A bare `latch_id` is not one:
## two packages may both call a latch `span_aligned`.
func latch_ref(span: RailSpan) -> String:
	return "%s/%s" % [package_id, span.latch_id]


## Every way this junction could not be reported to a bridge.
##
## Checked HERE because the alternative is discovering it as a refused
## intent after a player has already pulled the lever, at which point
## the repair has visibly happened and the campaign disagrees.
func violations(who := "junction") -> Array[String]:
	var out: Array[String] = []
	var pattern := RegEx.create_from_string("^[a-z0-9_]+$")
	if package_id.length() > 32 or pattern.search(package_id) == null:
		out.append("%s: package id '%s' is not `^[a-z0-9_]+$` within 32 "
			% [who, package_id] + "characters, so the bridge will refuse "
			+ "every latch it carries")
	var seen := {}
	for span: RailSpan in _spans:
		if pattern.search(span.latch_id) == null \
				or span.latch_id.length() > 32:
			out.append("%s: latch id '%s' is not `^[a-z0-9_]+$` within "
				% [who, span.latch_id] + "32 characters")
		if seen.has(span.latch_id):
			out.append("%s: two spans both call their latch '%s', which "
				% [who, span.latch_id] + "makes them indistinguishable "
				+ "to every consumer")
		seen[span.latch_id] = true
		if carrier != null and (span.link < 0
				or span.link >= carrier.commissioned.size()):
			out.append("%s: span '%s' is link %d of a railway with %d"
				% [who, span.latch_id, span.link,
					carrier.commissioned.size()])
	return out


## The package the committed manifest carries, in the contract's words.
##
## This is what makes a latch REPORTABLE: `record_latch` refuses any
## `package_id/latch_id` the committed manifest does not declare,
## because a latch nobody placed would otherwise become permanent save
## data describing nothing -- and monotone sets never give anything
## back.
##
## `vector_latches` and `required_latches` are empty in this slice and
## that is a claim, not an oversight: nothing on a mandatory route
## depends on this span yet. Promoting a latch is a composition
## decision, and the composer has not made it.
func package() -> Dictionary:
	var conditions: Array = []
	for span: RailSpan in _spans:
		conditions.append({
			"latch_id": span.latch_id,
			# The lock engaging IS the condition. Not the span's
			# position: a span resting in the right place with nothing
			# holding it is not track.
			"kind": "CONSTRAINT_STATE",
			"detail": "span locked home across link %d" % span.link})
	return {
		"package_id": package_id,
		"latch_conditions": conditions,
		"vector_latches": [],
		"required_latches": [],
		"on_mandatory_route": false,
	}


## THE REBUILD. Recompute what the accepted latches imply, report
## nothing, and leave every live thing at its default.
##
## Returns how many spans this junction restored, so a caller can tell
## "there was nothing to restore" from "the refs were for another
## package" without reading the set itself.
func restore_from(latched) -> int:
	var accepted := {}
	for ref: Variant in latched:
		accepted[str(ref)] = true
	var count := 0
	for span: RailSpan in _spans:
		if not accepted.has(latch_ref(span)):
			continue
		span.restore()
		_commission(span)
		count += 1
	# EVERY CONTROL COMES BACK ARMED, including the ones whose span is
	# already home: the lever's own position is live state, and a lever
	# that remembered being pulled would be a saved animation.
	park()
	return count


## Put the carrier on a dock this build actually supports.
##
## NOT A SAVED TRANSFORM, and the difference is the whole policy. A
## carrier resumed where it was left could be halfway across a span this
## build has not commissioned -- standing on track that is not there --
## and no amount of care about saving the number would fix that.
## `dock` is clamped to a dock that exists.
func park(dock := 0) -> void:
	if carrier == null or carrier.dock_offsets.is_empty():
		return
	var where := clampi(dock, 0, carrier.dock_offsets.size() - 1)
	carrier.hold(false)
	carrier.heading = RailCarrier.HOLD
	carrier.speed = 0.0
	carrier.target_dock = -1
	carrier.offset = carrier.dock_offsets[where]
	carrier._place()


func _physics_process(_delta: float) -> void:
	pass


func _on_operated(_control: AlignmentControl, span: RailSpan) -> void:
	span.begin()


func _on_locked(span: RailSpan) -> void:
	_commission(span)
	# THE ACCEPTED CONSEQUENCE, reported once. `restore` never reaches
	# here, so returning to a repaired Zone tells the bridge nothing.
	latch_fired.emit(package_id, span.latch_id)


func _commission(span: RailSpan) -> void:
	if carrier != null and span.link >= 0 \
			and span.link < carrier.commissioned.size():
		carrier.commissioned[span.link] = true
	commissioned.emit(span.link, span.latch_id)
