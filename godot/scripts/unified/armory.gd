class_name UnifiedArmory
extends Node
## THE FIVE WEAPONS ON THE GAME'S OWN PLAYER (unified integration 1).
##
## Owner, 2026-10-16: keys 1-5 everywhere -- the station, the Crossings and
## the Freight Bay -- from the start, with no pickups, ammo or inventory;
## holstering hands the Static Pulse back; an Echo in the second slot is
## set aside while a weapon is out and returns when it is holstered.
##
## NOTHING HERE IS A NEW WEAPON SYSTEM. This node stands where the range's
## host (`WeaponFeel`) stood and hands `RangeWeapons` the same two things,
## the player and the feel treatments held at baseline. The firing, the
## recoil, Foundry's readiness, the impacts, the marks and Condi's sounds
## are v3's, unchanged.
##
## One armory per player: Main builds one with every Hub, Crossing and
## annex, and the weapon you had out follows you through the door.

signal weapon_changed(id: String)

const KEYS := {KEY_1: "foundry", KEY_2: "sightline", KEY_3: "switchback",
		KEY_4: "bulkhead", KEY_5: "driver", KEY_0: ""}

## The weapon out, kept across Hub / Crossing / annex transitions (a new
## player is built for each). "" is the Static Pulse.
static var remembered := ""

const FX_JSON := "res://content/fx/weapons/fx.json"

var player: Player
var feel: WeaponFeelTreatments
var weapons: RangeWeapons
## The weapons wearing Arty's art (a missing one keeps its placeholder).
var dressed: Array[String] = []
var fx: GlyphFxLayer
var _target: Node3D
var _label: Label


## Builds the treatments and the weapons on `p`. False when the player's
## shot feedback was not where the treatments look for it (then nothing is
## armed, and the Static Pulse works exactly as it ships).
func setup(p: Player, tones: Tones) -> bool:
	name = "UnifiedArmory"
	player = p
	# The treatments want a target for their own (unused here) dummy feel.
	_target = Node3D.new()
	_target.name = "ArmoryNoTarget"
	add_child(_target)
	feel = WeaponFeelTreatments.new()
	feel.name = "Treatments"
	add_child(feel)
	if not feel.bind(player, tones, _target):
		return false
	feel.select("baseline")
	weapons = RangeWeapons.new()
	add_child(weapons)
	weapons.bind(self)
	# Arty's five weapons and her layered Glyph effects (2026-10-14).
	dressed = WeaponArt.dress(weapons.rig)
	fx = GlyphFxLayer.new()
	fx.name = "GlyphFx"
	add_child(fx)
	fx.setup(FX_JSON, weapons)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_label = Label.new()
	# Above the HP line: below it are the HUD's own Echo rows (LMB, RMB,
	# MMB), which the first version of this label sat on top of.
	_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position = Vector2(20, -150)
	_label.offset_top = -150
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.modulate = Color(0.85, 0.9, 0.95)
	layer.add_child(_label)
	select(remembered)
	return true


func out() -> String:
	return weapons.current if weapons != null else ""


## A weapon by id, or "" for the Static Pulse. The same id again switches
## Switchback's and Bulkhead's variant, as in the range.
func select(id: String) -> void:
	if weapons == null:
		return
	if id != "" and id == weapons.current \
			and RangeWeapons.VARIANTS.has(id):
		weapons.next_variant()
	else:
		weapons.select(id)
	if id == "":
		# The Echo the save says is in the second slot comes back.
		var runtime: EchoRuntime = player.runtimes.get(RangeWeapons.SLOT)
		if runtime != null:
			runtime.set_equipped(BridgeClient.slotted_action(RangeWeapons.SLOT))
	remembered = weapons.current
	_refresh_label()
	weapon_changed.emit(weapons.current)


func _refresh_label() -> void:
	if _label == null:
		return
	var now := "0 · STATIC PULSE"
	if weapons.current != "":
		now = String(weapons.profile().get("name", weapons.current))
		var v := String(weapons.profile().get("variant_name", ""))
		if v != "":
			now += "  —  " + v
	_label.text = now + "\n1 Foundry · 2 Sightline · 3 Switchback · " \
			+ "4 Bulkhead · 5 Mass Driver · 0 Pulse"


func _unhandled_input(event: InputEvent) -> void:
	# Only in play: every menu, the Forge, the shop and the layout
	# acceptance hold the player's input, and so do these keys.
	if player == null or player.input_frozen \
			or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if KEYS.has(key):
		select(KEYS[key])
		get_viewport().set_input_as_handled()
