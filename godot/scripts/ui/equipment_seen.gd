class_name EquipmentSeen
extends RefCounted
## WHICH OWNED ITEMS THE PLAYER HAS LOOKED AT, so that a new one can say so
## (`04` §5: "natural acquisition should draw attention to the actual new
## item without blocking the AP transfer on an animation"). The marker is
## a word on a tile; nothing waits on it.
##
## A client preference, like `Favourites`: nothing mechanical reads it, it
## never touches the save, the log or the bridge, and losing it costs a
## marker rather than a capability.
##
## **Per campaign** (`seed_name/slot_name`), because a component id is
## only unique inside one. **The first time a campaign is seen, what it
## already owns is recorded as seen**: a player who meets this screen
## mid-campaign is not told that twenty old things are new.
##
## An item stops being new when it is INSPECTED -- selected, its detail
## shown -- and not when the menu merely opens, because opening a menu on
## another wall is not noticing an item.

const _PATH := "user://equipment_seen.cfg"

## campaign -> {component id: true}
static var _seen := {}
static var _loaded := false
## Off under the drivers, so a suite never writes the player's file.
static var _persist := true


static func campaign_key(snapshot: Dictionary) -> String:
	return "%s/%s" % [str(snapshot.get("seed_name", "")),
			str(snapshot.get("slot_name", ""))]


## Record everything owned as seen, the first time this campaign is met.
static func baseline(campaign: String, ids: Array) -> void:
	_load()
	if _seen.has(campaign):
		return
	var known := {}
	for id: Variant in ids:
		known[str(id)] = true
	_seen[campaign] = known
	_save()


static func is_new(campaign: String, component_id: String) -> bool:
	_load()
	return _seen.has(campaign) \
			and not (_seen[campaign] as Dictionary).has(component_id)


static func mark_seen(campaign: String, component_id: String) -> void:
	_load()
	if not _seen.has(campaign):
		_seen[campaign] = {}
	if (_seen[campaign] as Dictionary).has(component_id):
		return
	(_seen[campaign] as Dictionary)[component_id] = true
	_save()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(_PATH) != OK:
		return
	for campaign: String in config.get_sections():
		var known := {}
		for id: String in config.get_section_keys(campaign):
			known[id] = true
		_seen[campaign] = known


static func _save() -> void:
	if not _persist:
		return
	var config := ConfigFile.new()
	for campaign: String in _seen:
		# A campaign with nothing owned yet still has to be remembered as
		# met, or its first item would be taken for the old baseline.
		config.set_value(campaign, "_met", true)
		for id: String in _seen[campaign]:
			config.set_value(campaign, id, true)
	# A preference failing to persist is not worth interrupting play for.
	config.save(_PATH)


## Test seam: the suites drive this without touching the player's file.
static func _reset_for_test() -> void:
	_seen.clear()
	_loaded = true
	_persist = false
