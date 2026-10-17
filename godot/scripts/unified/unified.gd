class_name Unified
extends RefCounted
## THE UNIFIED INTEGRATION BUILD (integration/unified-1, owner 2026-10-16).
##
## ONE SWITCH, `--unified` on Godot's command line, which only the unified
## launcher passes. Without it nothing below is built: no weapons on the
## player, no Freight Bay annex, no music. The D-22 slice it runs on is
## switched separately, by its own bridge (`D22Slice.active()`).
##
## Every rule this build adds is a PROTOTYPE decision for the owner's
## playtest, never a campaign rule; `docs/reports/` lists them.

const FLAG := "--unified"


static func active() -> bool:
	return FLAG in OS.get_cmdline_user_args()
