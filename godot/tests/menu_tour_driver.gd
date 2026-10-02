extends Node
## MENU-INT, M6: THE TOUR. The integrated menu, played through the way a
## player plays it, on the owner's own campaign, and recorded by Godot's
## Movie Maker with the game's renderer (`make menu-tour`):
##
##     xvfb-run ... godot --path godot --rendering-driver vulkan \
##         --rendering-method forward_plus --write-movie <out>.avi \
##         --fixed-fps 30 -- --menu-tour
##
## THE DATA IS REAL: `tour_snapshot.json` (`make tour-fixture`) is the
## owner's candidate campaign played again by the bridge's own engine into
## its seventh Zone -- 60 items, the Bomb Bag on its key -- and there a
## first walk from the entrance a player can make: six rooms, their keys
## taken, a control set and a lock opened on the way, and two Checks
## claimed in rooms walked (`meta.did`). The Zone is built by the real
## `ZoneController` from the document the snapshot carries. The walls are
## mounted exactly as `Main` mounts them, with the game's cue bank.
##
## EVERY MOVE IS A KEY, pressed through the engine's input pipeline; the
## pauses between them are the only thing written here. The fixed frame
## rate makes the recording's time the game's own: each turn, glide and
## pull plays at the speed a player sees it, however long a frame took to
## draw. `user://settings.cfg` is put back as it was.

const FIXTURE := "res://tests/fixtures/tour_snapshot.json"

var shell: MenuShell
var equipment: EquipmentFace
var map_face: MapFace
var journal: JournalFace
var settings: SettingsFace
var pause_menu: PauseMenu
var zone: ZoneController
var _saved := PackedByteArray()
var _had := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	var tour: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_had = FileAccess.file_exists(PlayerSettings.PATH)
	_saved = FileAccess.get_file_as_bytes(PlayerSettings.PATH) if _had \
			else PackedByteArray()
	EquipmentSeen._reset_for_test()
	BridgeClient.assume_sent = true
	zone = ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	zone.add_child(pool)
	get_tree().root.add_child(zone)
	# Met on arriving, so what the walk and the claims bring is NEW.
	BridgeClient._handle(JSON.stringify(tour["before"]))
	zone.setup(tour["after"]["active_zone"]["zone"])
	var tones := Tones.new()
	add_child(tones)
	shell = MenuShell.new()
	add_child(shell)
	shell.kit.cue_sink = tones.menu_cue
	pause_menu = PauseMenu.new()
	shell.add_child(pause_menu)
	settings = SettingsFace.new()
	settings.bind_pause(pause_menu)
	shell.mount("settings", settings)
	equipment = EquipmentFace.new()
	shell.mount("equipment", equipment)
	map_face = MapFace.new()
	shell.mount("map", map_face)
	journal = JournalFace.new()
	journal.bind_map(map_face)
	shell.mount("journal", journal)
	map_face.bind(zone)
	await _wait(1.0)
	# The walk: each room entered, as the player walks it.
	for room: String in tour["meta"]["walked"]:
		_stand_in(room)
		await get_tree().process_frame
	_stand_in(str(tour["meta"]["walked"][0]))
	BridgeClient._handle(JSON.stringify(tour["after"]))
	await _wait(1.0)
	await _tour()
	_put_back()
	get_tree().quit(0)


func _stand_in(room: String) -> void:
	if not zone.room_bounds.has(room):
		return
	var box: AABB = zone.room_bounds[room]
	zone.player.global_position = box.get_center() \
			- Vector3(0, box.size.y * 0.5 - 0.2, 0)
	zone._track_chamber()


func _open() -> void:
	pause_menu.open(true)
	equipment.open()
	shell.open("settings")


func _tour() -> void:
	# The world; then the box opens on Settings, as Escape opens it in the
	# game (`Main._open_menu`: the pause menu, the Equipment wall, the box).
	await _wait(1.2)
	_open()
	await _wait(2.6)
	# SETTINGS: down the PAUSED board to the options; FIELD OF VIEW up
	# three and back, its knob sliding.
	for i in 5:
		await _key(KEY_DOWN, 0.22)
	for i in 3:
		await _key(KEY_RIGHT, 0.2)
	for i in 3:
		await _key(KEY_LEFT, 0.2)
	await _wait(0.8)
	# EQUIPMENT: Q, a page turn round the corner post.
	await _key(KEY_Q, 1.8)
	# The selector down to MOBILITY, into its rack; its modules pulled one
	# after another, the window reading each.
	await _key(KEY_DOWN, 0.5)
	await _key(KEY_DOWN, 0.8)
	await _key(KEY_RIGHT, 1.6)
	for i in 3:
		await _key(KEY_DOWN, 1.1)
	# The consumable key: the Bomb Bag, and its whole history.
	await _key(KEY_LEFT, 0.4)
	await _key(KEY_DOWN, 0.4)
	await _key(KEY_DOWN, 0.9)
	await _key(KEY_RIGHT, 1.4)
	await _key(KEY_H, 2.4)
	await _key(KEY_H, 0.6)
	# ALWAYS ON: the longest rack, run down to where it scrolls.
	await _key(KEY_LEFT, 0.4)
	await _key(KEY_DOWN, 0.8)
	await _key(KEY_RIGHT, 0.8)
	for i in 11:
		await _key(KEY_DOWN, 0.16)
	await _wait(1.2)
	# THE MAP: Q again; the lens, a live miniature behind the port.
	await _key(KEY_Q, 2.2)
	await _key(KEY_BRACKETRIGHT, 1.4)
	await _key(KEY_ENTER, 2.0)
	for i in 4:
		await _key(KEY_RIGHT, 0.25)
	await _key(KEY_UP, 0.6)
	await _key(KEY_C, 1.6)
	# THE JOURNAL: Q; an entry's wire runs round the corner into the Map.
	await _key(KEY_Q, 1.6)
	await _key(KEY_DOWN, 0.9)
	await _key(KEY_DOWN, 1.6)
	# SHOW IT ON THE MAP, then BACK TO YOUR VIEW.
	await _key(KEY_ENTER, 2.4)
	await _key(KEY_ESCAPE, 1.6)
	# And out: Escape backs out of what is open, then closes.
	for i in 3:
		if not shell.is_open():
			break
		await _key(KEY_ESCAPE, 0.9)
	await _wait(1.2)


func _key(code: Key, then := 0.0) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	if then > 0.0:
		await _wait(then)


## Game time, which the Movie Maker's fixed frame rate makes the video's.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _put_back() -> void:
	if _had:
		var out := FileAccess.open(PlayerSettings.PATH, FileAccess.WRITE)
		out.store_buffer(_saved)
		out.close()
	else:
		DirAccess.remove_absolute(PlayerSettings.PATH)
	PlayerSettings.reset_shared()
