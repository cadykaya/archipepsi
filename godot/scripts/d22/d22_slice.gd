class_name D22Slice
extends RefCounted
## THE D-22 SLICE SWITCH (`docs/D22_SLICE_BRIEF.md`).
##
## ONE FACT, READ IN ONE PLACE: a slice run is one whose bridge publishes
## the Forge view. The bridge only does that when it was started with
## `--d22-slice`, so a player's ordinary bridge -- and every suite -- never
## sees any of this, and a Godot started without a slice bridge builds the
## Hub, the exit portal and the menu exactly as before.
##
## `--d22-slice` on GODOT's command line does one more thing and only that:
## it starts the mock campaign without the menu (the slice launcher).

## Mirrors the bridge's `MAX_REDRAWS` (protocol.py). Presentation only:
## the bridge is what refuses a third redraw.
const MAX_REDRAWS := 2
const FLAG := "--d22-slice"


static func active() -> bool:
	return BridgeClient.snapshot.has("forge") \
			and typeof(BridgeClient.snapshot.get("forge")) == TYPE_DICTIONARY


static func forge() -> Dictionary:
	return BridgeClient.snapshot.get("forge", {}) if active() else {}


static func requested_on_cmdline() -> bool:
	return FLAG in OS.get_cmdline_user_args()


## Station progress: Crossings untethered. DERIVED from the snapshot the
## Hub already gets, never saved (brief §2 step 7).
static func untethered_count() -> int:
	return int(BridgeClient.snapshot.get("completed_zone_count", 0))


## Whether the bridge has untethered this Crossing: it is in the Forge's
## Untethered list, which is the COMPLETE records. Nothing local decides it.
static func is_untethered(zone_id: String) -> bool:
	for raw: Variant in forge().get("untethered", []):
		if typeof(raw) == TYPE_DICTIONARY \
				and str((raw as Dictionary).get("zone_id", "")) == zone_id:
			return true
	return false
