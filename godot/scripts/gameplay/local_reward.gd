class_name LocalRewardPickup
extends Area3D
## A payoff that is not Archipelago's (ECHOES §14.2).
##
## The distinction this class exists to hold: a `RewardObject` is an AP
## Check and claiming one is campaign truth negotiated with the server. A
## `LocalRewardPickup` is a note, a cosmetic, a log line — earned, recorded
## in the save, and worth exactly zero to Archipelago. They live in
## different groups, take different code paths, and only this one may be
## pulled at range by `pull_pickup`.
##
## Everything it can send is fixed at spawn from the closed §14.2 catalog,
## so there is no shape here that could name an AP item, location or Check
## even by accident.

const GROUP := "local_rewards"

## The §14.2 catalog. Duplicated from the schema deliberately: the client
## must not be able to invent a seventh kind, and a wire-level rejection
## after the pickup has already vanished is a worse failure than never
## offering it.
const KINDS := ["epsilon_note", "challenge_marker", "cosmetic_grant",
		"hub_decoration", "lab_fixture", "flavor_log"]

signal collected(reward_id: String)

var kind := "flavor_log"
var reward_id := "local_reward"
var display_name := "Fragment"
var note := ""

var _claimed := false
var _spin := 0.0
var _core: MeshInstance3D
var _label: Label3D

static func create(kind_in: String, reward_id_in: String,
		display_name_in: String, note_in := "",
		tint := Color(0.6, 1.0, 0.85)) -> LocalRewardPickup:
	var pickup := LocalRewardPickup.new()
	# An unknown kind becomes a flavour log rather than a dropped pickup:
	# the reward still exists, it just files itself under the dullest
	# entry in the catalog. Silently sending an invalid kind would earn a
	# bridge rejection the player would experience as a vanished reward.
	pickup.kind = kind_in if kind_in in KINDS else "flavor_log"
	pickup.reward_id = reward_id_in
	pickup.display_name = display_name_in
	pickup.note = note_in
	pickup._tint = tint
	return pickup

var _tint := Color(0.6, 1.0, 0.85)

func _ready() -> void:
	# Already found? Then it is not here any more.
	#
	# The save has recorded local rewards since S9 and the snapshot has
	# mirrored them since S10, but nothing read the mirror — so a note you
	# picked up reappeared every time you re-entered the Zone, and the
	# bridge silently discarded each re-report as a duplicate. The reward
	# looked repeatable and was not.
	if already_earned(reward_id):
		queue_free()
		return
	add_to_group(GROUP)
	monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	shape.shape = sphere
	add_child(shape)

	_core = MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.42, 0.55, 0.42)
	_core.mesh = mesh
	_core.material_override = ThemeMaterials.glow_material(_tint, 1.7)
	add_child(_core)

	_label = Label3D.new()
	_label.text = display_name
	_label.font_size = 22
	_label.pixel_size = 0.004
	_label.position = Vector3(0, 0.85, 0)
	_label.modulate = _tint
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_spin += delta * 1.8
	if _core != null:
		_core.rotation.y = _spin
		_core.position.y = 0.15 * sin(_spin * 1.3)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collect()

## Whether this reward is already in the campaign's earned list.
##
## Read from the snapshot rather than remembered client-side: the save is
## the authority on what has been found, and a Zone rebuilt after a
## reconnect has to agree with it.
static func already_earned(id: String) -> bool:
	var earned: Variant = BridgeClient.snapshot.get("local_rewards", [])
	if typeof(earned) != TYPE_ARRAY:
		return false
	for record: Dictionary in earned:
		if str(record.get("reward_id", "")) == id:
			return true
	return false

## Split from the signal so a test — and `pull_pickup` delivering one into
## the player — can take it without staging a physics overlap.
func collect() -> void:
	if _claimed:
		return
	_claimed = true
	# The bridge stamps the Zone and owns idempotence; the client's job is
	# to report the find once and stop drawing it.
	BridgeClient.send_intent({
		"type": "grant_local_reward",
		"kind": kind,
		"reward_id": reward_id,
		"display_name": display_name,
		"description": note,
	})
	collected.emit(reward_id)
	queue_free()
