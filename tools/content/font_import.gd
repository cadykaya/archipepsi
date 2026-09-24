extends SceneTree
## Track A -- does a Glyph-authored bitmap font survive the trip into
## Godot 4.5.1?
##
## The Glyph guide's own font proof names 4.3. The approved plan names
## this import as the open technical risk in Track A, and the first thing
## to test: everything else in the interface family -- panels, keycaps,
## headings, item counts -- is built on the assumption that a `.fnt` and
## its page land in the engine with their METRICS intact. A sheet that
## imports as pictures but loses its advances is not a font.
##
## Two paths are tested, because the lane needs both:
##
##   * `load()` on the imported resource -- what a menu scene will do,
##     and what the editor's BMFont importer produces;
##   * `FontFile.load_bitmap_font()` -- the runtime parse, which is the
##     diagnostic when the first disagrees with the file.
##
## They must agree. If they do not, the sidecar is carrying different
## metrics from the source and the committed font is a lie.

const FONT := "res://_harness/ui_numerals.fnt"
## The same font with ONE byte changed: `1` advances 5 like everything
## else. See `_sabotage()`.
const SABOTAGE := "res://_harness/sabotage.fnt"

## Declared in `author_numerals.py`, not measured off the art.
const BASELINE := 6.0
const CELL := Vector2(6, 8)
const SIZE := 8
const CHARACTERS := "0123456789/x"
## Characters the set does NOT contain. `has_char` must say so -- a font
## that answers yes to everything cannot be asked anything.
const ABSENT := "A#z "
## Advances as authored: `1` is three columns of ink, everything else
## four, so a pair of ones is 2 px narrower than a pair of noughts.
const PAIR_ONES := 8.0
const PAIR_NOUGHTS := 10.0

## The keys both paths must report identically: they are the FONT, not
## the engine's handling of it. `noughts_at_2x` is deliberately not here
## -- see `_scaling()`, where the difference is asserted on purpose.
const INTRINSIC := ["ascent", "descent", "height", "characters",
	"ones", "noughts", "count_3_of_8"]
## What `fixed_size_scale_mode` reads as on a font the EDITOR imported.
## TextServer: 0 DISABLE, 1 INTEGER_ONLY, 2 ENABLED. Pinned so that an
## engine upgrade changing the importer's default is a failure here and
## not a surprise in a panel.
const IMPORTER_SCALE_MODE := TextServer.FIXED_SIZE_SCALE_ENABLED

var _faults: Array[String] = []
var _notes := {}


func _bad(what: String) -> void:
	_faults.append(what)
	print("[fontimport] FAULT: %s" % what)


func _measure(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x


func _init() -> void:
	var out: String = ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]

	# --- path 1: the imported resource --------------------------------
	var imported: Variant = load(FONT)
	if imported == null:
		_bad("load(%s) returned null -- Godot %s did not import the .fnt "
			 % [FONT, Engine.get_version_info()["string"]]
			 + "at all, which is the risk this harness exists to find")
	elif not (imported is FontFile):
		_bad("load(%s) returned a %s, not a FontFile"
			 % [FONT, imported.get_class()])

	# --- path 2: the runtime parse ------------------------------------
	var parsed := FontFile.new()
	var err := parsed.load_bitmap_font(ProjectSettings.globalize_path(FONT))
	if err != OK:
		_bad("load_bitmap_font failed with error %d" % err)

	var fonts := {}
	if imported is FontFile:
		fonts["imported"] = imported
	if err == OK:
		fonts["parsed"] = parsed
	if fonts.is_empty():
		_bad("neither import path produced a font; nothing left to measure")
		_finish(out)
		return

	for how in fonts:
		var font: FontFile = fonts[how]
		var m := {}

		# --- the baseline -------------------------------------------
		# `base=6` in the .fnt is the row the ink rests on, and Godot
		# calls that distance the ascent. If this comes back as the cell
		# height the font is sitting a pixel low and every number in
		# every panel is misaligned against its frame.
		m["ascent"] = font.get_ascent(SIZE)
		if not is_equal_approx(m["ascent"], BASELINE):
			_bad("%s: ascent %s, and the .fnt declares base=%s"
				 % [how, m["ascent"], BASELINE])
		m["descent"] = font.get_descent(SIZE)
		m["height"] = font.get_height(SIZE)

		# --- the alphabet ------------------------------------------
		var missing := ""
		for i in CHARACTERS.length():
			if not font.has_char(CHARACTERS.unicode_at(i)):
				missing += CHARACTERS[i]
		if missing != "":
			_bad("%s: has_char says no to %s, which were authored"
				 % [how, missing])
		var invented := ""
		for i in ABSENT.length():
			if font.has_char(ABSENT.unicode_at(i)):
				invented += ABSENT[i]
		if invented != "":
			_bad("%s: has_char says YES to %s, which were never drawn -- "
				 % [how, invented]
				 + "a font answering yes to everything answers nothing")
		m["characters"] = CHARACTERS.length() - missing.length()

		# --- the advances, composed --------------------------------
		# One glyph's advance is a number in a file. Two glyphs side by
		# side is the thing a menu actually does, and the only way to
		# see whether the number was used.
		m["ones"] = _measure(font, "11")
		m["noughts"] = _measure(font, "00")
		m["count_3_of_8"] = _measure(font, "3/8")
		if not is_equal_approx(m["ones"], PAIR_ONES):
			_bad("%s: \"11\" measures %s, authored %s"
				 % [how, m["ones"], PAIR_ONES])
		if not is_equal_approx(m["noughts"], PAIR_NOUGHTS):
			_bad("%s: \"00\" measures %s, authored %s"
				 % [how, m["noughts"], PAIR_NOUGHTS])
		if m["ones"] >= m["noughts"]:
			_bad("%s: \"11\" is not narrower than \"00\" (%s vs %s) -- the "
				 % [how, m["ones"], m["noughts"]]
				 + "per-glyph advances did not survive the trip")

		# --- does it scale like pixel art? -------------------------
		# Not a gate: a 1998 panel wants integer scale, and whether this
		# engine gives it for a bitmap face is worth knowing before the
		# family is built on top. Reported either way.
		m["noughts_at_2x"] = font.get_string_size(
			"00", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE * 2).x
		m["integer_2x"] = is_equal_approx(
			m["noughts_at_2x"], PAIR_NOUGHTS * 2.0)
		# 1.5x. Not a gate -- evidence for a recommendation. Mode 2 is
		# ENABLED, not INTEGER_ONLY, so the engine will happily scale a
		# pixel face to a fractional size and smear it. Whether it
		# actually does is the difference between "ask for multiples of
		# 8" being advice and being a rule.
		m["noughts_at_1_5x"] = font.get_string_size(
			"00", HORIZONTAL_ALIGNMENT_LEFT, -1, int(SIZE * 1.5)).x
		m["fixed_size"] = font.fixed_size
		m["scale_mode"] = font.fixed_size_scale_mode
		_notes[how] = m
		print("[fontimport] %s: ascent %s height %s | \"11\" %s \"00\" %s "
			  % [how, m["ascent"], m["height"], m["ones"], m["noughts"]]
			  + "\"3/8\" %s | 2x %s%s | 1.5x %s"
			  % [m["count_3_of_8"], m["noughts_at_2x"],
				 "" if m["integer_2x"] else " (NOT integer)",
				 m["noughts_at_1_5x"]])

	# --- the two paths must agree about the FONT ----------------------
	if _notes.has("imported") and _notes.has("parsed"):
		for key in INTRINSIC:
			if not is_equal_approx(_notes["imported"][key],
					_notes["parsed"][key]):
				_bad("the imported resource and the runtime parse disagree "
					 + "about %s: %s vs %s" % [key,
						_notes["imported"][key], _notes["parsed"][key]])

	_scaling()
	_sabotage()
	_finish(out)


func _scaling() -> void:
	## The two paths agree about the font and DISAGREE about scaling, and
	## that difference is a fact about this engine the interface family
	## has to be built around, so it is asserted rather than tolerated.
	##
	## The editor's BMFont importer sets `fixed_size_scale_mode`; a font
	## produced by `load_bitmap_font()` at runtime is left at the
	## default, which is not to scale at all. So the same file renders a
	## 2x panel correctly when `load()`ed and silently at 1x when parsed
	## in code -- an unpleasant way to find out, and the reason this
	## harness names the property instead of reporting "20 vs 10".
	if not (_notes.has("imported") and _notes.has("parsed")):
		return
	var imported: Dictionary = _notes["imported"]
	var parsed: Dictionary = _notes["parsed"]

	# A pixel face at 2x must land on whole pixels. This is the mode the
	# family will actually be drawn in, so it is a gate.
	if not imported["integer_2x"]:
		_bad("the imported font does not scale 2x to exactly double "
			 + "(%s for an authored %s) -- a pixel panel at 2x will land "
			 % [imported["noughts_at_2x"], PAIR_NOUGHTS * 2.0]
			 + "on half pixels")

	if imported["scale_mode"] != IMPORTER_SCALE_MODE:
		_bad("the importer set fixed_size_scale_mode %s, not the %s this "
			 % [imported["scale_mode"], IMPORTER_SCALE_MODE]
			 + "lane measured -- re-read what the new default means for a "
			 + "pixel face before trusting any size but 1x")
	if parsed["scale_mode"] == imported["scale_mode"]:
		_bad("both paths report scale mode %s, so the 2x difference has "
			 % parsed["scale_mode"]
			 + "some other cause than this harness claims and the note "
			 + "written beside it is wrong")
		return
	print("[fontimport] scale mode: imported %s, runtime parse %s"
		  % [imported["scale_mode"], parsed["scale_mode"]])

	# And the diagnosis, proved: adopt the importer's mode and the
	# runtime parse scales identically. This is the remedy any code that
	# calls load_bitmap_font() has to apply.
	var fixed := FontFile.new()
	if fixed.load_bitmap_font(ProjectSettings.globalize_path(FONT)) != OK:
		_bad("could not reload the font to test the scale-mode remedy")
		return
	fixed.fixed_size_scale_mode = imported["scale_mode"]
	var scaled := fixed.get_string_size(
		"00", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE * 2).x
	if not is_equal_approx(scaled, imported["noughts_at_2x"]):
		_bad("setting fixed_size_scale_mode to the importer's %s did NOT "
			 % imported["scale_mode"]
			 + "make the runtime parse scale like the imported font "
			 + "(%s vs %s), so the cause of the difference is not the "
			 % [scaled, imported["noughts_at_2x"]]
			 + "property this harness blames")
		return
	_notes["scale_mode_remedy"] = true
	print("[fontimport] and setting that mode on the parsed font makes it "
		  + "measure %s, the same as the imported one" % scaled)


func _sabotage() -> void:
	## Everything above would also pass if `get_string_size` were
	## returning cell widths and ignoring the file. So: the same sheet,
	## the same art, `1`'s xadvance raised from 4 to 5 in the .fnt, and
	## nothing else. A measurement that reads the file must now report
	## "11" as WIDE as "00". One that reports 8 again was never reading
	## the advances and every pass above is meaningless.
	var rigged := FontFile.new()
	if rigged.load_bitmap_font(ProjectSettings.globalize_path(SABOTAGE)) != OK:
		_bad("the sabotage font would not load, so the measurement was "
			 + "never tested against a font it should disagree with")
		return
	var ones := _measure(rigged, "11")
	var noughts := _measure(rigged, "00")
	if is_equal_approx(ones, noughts) and is_equal_approx(ones, PAIR_NOUGHTS):
		print("[fontimport] sabotage: \"11\" became %s, matching \"00\" -- "
			  % ones + "the measurement reads the file's advances")
		_notes["sabotage_detected"] = true
		return
	_bad("sabotage NOT detected: with 1's xadvance raised to 5, \"11\" "
		 + "still measures %s against \"00\" at %s. This harness is not "
		 % [ones, noughts]
		 + "measuring the font's advances and its passes prove nothing")
	_notes["sabotage_detected"] = false


func _finish(out: String) -> void:
	_notes["engine"] = Engine.get_version_info()["string"]
	_notes["faults"] = _faults
	if out != "":
		var fh := FileAccess.open(out, FileAccess.WRITE)
		fh.store_string(JSON.stringify(_notes, "\t", true, true))
		fh.close()
	if _faults.is_empty():
		print("[fontimport] PASS -- the font imports into Godot %s with its "
			  % _notes["engine"] + "metrics intact, by both paths")
	else:
		push_error("[fontimport] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
