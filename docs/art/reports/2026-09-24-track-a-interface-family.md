# Track A — the interface family, first slice

*Arty*

**2026-09-24.** Branch `claude/archipepsi-art`, PR #5.

The approved plan named one open technical risk in this track, and said
it was the first thing to test:

> the trial proved an edit → commit → image → reopen → export cycle at
> `87db9e2`. It proved nothing about **bitmap-font and nine-slice import
> into Godot 4.5.1**. The guide's font proof names 4.3.

Both halves are now measured in the engine. Both pass. This report is
what was built, what the engine said, what bit me, and the two things I
want ruled on.

---

## 1. What landed

| Artifact | What it is |
| --- | --- |
| `assets/ui/ui_numerals.fnt` + `.png` | Twelve glyphs — `0123456789/x` — on 6x8 cells, declared baseline 6. |
| `assets/ui/panel_{panel,well,selected}.png` + `panels.json` | Three nine-slice treatments, 10x10, 3 px border, 4 px stretchable centre. |
| `tools/glyphui/` | `glyphrun.py` (shared plumbing), `author_numerals.py`, `author_panels.py`. |
| `tools/content/run_font_import.sh`, `run_nine_slice.sh` | The two gates. In the suite's named-gate list, so neither can be quietly dropped. |
| `tools/content/run_interface_face.sh` | The evidence sheets. Not a gate. |
| `docs/art/review/interface_2026-09-24/` | Two sheets and a README, for the owner. |

Everything regenerates from source. The glyph rows are text in the
Python, so the art is diffable; the `.fnt` and the four PNGs rebuild
byte-identical and `tools/check_art_current.sh` now regenerates them and
lets `git diff` judge, announcing a skip when no Glyph checkout is
present rather than passing silently.

The `.glyph` projects are **not** committed. Their revision identifiers
are fresh on every run, so they can never rebuild identical and have no
business in the tree pretending to be a source.

---

## 2. What the engine said

Godot **4.5.1.stable.official.f62fdbde1**, both paths a game can use:
`load()` on the imported resource, and `FontFile.load_bitmap_font()` at
runtime.

```
ascent 6.0   height 8.0   "11" 8.0   "00" 10.0   "3/8" 15.0
has_char: 12 of 12 authored, 0 of 4 never drawn
```

The declared baseline comes back as the ascent, the alphabet answers
correctly, and the per-glyph advances compose — `"11"` is 2 px narrower
than `"00"` because `1` carries three columns of ink where the rest
carry four. That was the point of drawing it that way.

Nine-slice, each panel drawn at 40x24 — not a multiple of 10, not square,
because a bug that happened to work at an exact 2x would survive a nicer
number:

```
corners byte-exact against the authored art
edges resample on one axis only
centre flat, outline unbroken all the way round
textures arrive lossless
```

### Two engine facts other lanes need

**A font parsed at runtime does not scale.** The editor's BMFont
importer sets `fixed_size_scale_mode`; `load_bitmap_font()` leaves it at
the default, which is not to scale at all. The same file renders a 2x
panel correctly when `load()`ed as a resource and silently at 1x when
parsed in code. The harness names the property and proves it by applying
it — setting the importer's mode on the parsed font makes it measure
identically — rather than reporting "20 vs 10" and leaving the next
person to guess.

**The importer's mode is ENABLED, not INTEGER_ONLY.** At 1.5x the font
duly measures 15 px. The engine will scale a pixel face to a fractional
size if asked. A pixel UI must ask only for multiples of 8, or set
`INTEGER_ONLY` itself. That is a UI-theme decision, and it is cheap now
and expensive after a hundred panels.

---

## 3. What bit me

**`check_font` caught a defect before the engine ever saw the font.**
The advance table was derived from each glyph's **top** row. `1`'s top
row is two columns and its base serif is three, so the pen stopped
inside its own ink and the next character would have overlapped it.
Fixed in the art and in the arithmetic: a glyph is as wide as its widest
row, never as wide as its first.

**The palette caught an invisible bevel before a pixel was drawn.**
`selected` first took its shadow from the `signal` ramp's darkest step,
which separates from the face by **0.017 L\*** against the palette's
required 0.10. A bevel that is not there — and not there in the way that
survives review, because the screenshot still looks fine. The shadow is
neutral now, which is also what a shadow is. Every colour in these
panels is read out of `assets/art_palette.json` and checked against the
palette's own `min_value_separation` before authoring starts.

**A sabotage run found a check grading its own input.** The nine-slice
harness compared the rendered corners against the imported image — the
same file. Corrupting a corner pixel in the committed art passed,
because both sides of the comparison moved together. It reads
`panels.json` now — the declared sizes, insets and the colour of every
ring — and a ring painted anything else fails however well it stretches.
The margins-0 sabotage (which must make the corner check fail, and does)
proves the other half: that the harness is measuring nine-slice
behaviour and not just that an image was drawn.

**Two process-lifetime traps in Glyph, one per session.** A transaction
lives in the process that opened it, and so does an export preset —
`glyph run` starts a process per call, so both die between calls. The
answers are `glyph batch` for a transaction and the CLI's own `export`
subcommand, re-running a preset from the `preset_declaration` an export
record carries. Both are now in `glyphrun.py` with the reasoning beside
them, because rediscovering either costs an hour.

**A separate find, already committed.** The course ruling left four
theme-bind evidence renders stale in the working tree. The suite was
green and right to be: it says review sheets are not covered, and its
reasoning does not reach a render whose source texture changed while
rebuilding byte-identical. Recorded in `ART_LESSONS.md` with the shape
that would catch it.

---

## 4. Two decisions I want

**1. Interface chrome has no universal palette family.** There are six —
`signal`, `hazard`, `identity`, `dead`, `send`, `glitch` — and every one
carries a load-bearing meaning. None means "chrome". These panels use
the `dead` ramp, which is defensible: a frame is not for you, its
contents are. But `dead` also means *unpowered, locked, spent, offline*,
and if a locked slot and the frame around it are both `dead`, the locked
slot stops reading. Either a seventh family for chrome, or a rule that
chrome takes `dead`'s dark half and item state takes its light half. I
have not changed the palette — it is generated, shared, and not mine to
extend unilaterally.

**2. One pixel of bevel.** In isolation on a dark background, `panel`
and `well` take a moment to tell apart; in context, wells on a panel
read as recesses at once. If you want them distinct in isolation too,
that is a 2 px bevel, a 4 px border and a larger minimum cell. Say so
and I will bring both at the same scale.

---

## 5. What is next in this track, and what is deferred

Still to author: body text, headings and keycaps; the shared circuit,
blocked-exit and control symbols; page arrows.

**Deferred by ruling 3**, and I am holding the line on it: item art,
state art and anything that needs a slot's meaning waits for
Production's real runtime/fold vocabulary. The grid in the evidence
sheet has empty cells because the vocabulary has not arrived, not
because the art is unfinished.

**Ruling 4 (reduced motion)** is noted and costs nothing yet: the same
3D scene, page order and interface states, with the transition motion
reduced or replaced, and a static alternative only where animation would
otherwise be the sole carrier of information. Nothing authored so far
carries information in motion.

Then **Track D** — `pack_textures` rows for T01 + T05 at `candidate`
status, validated by `theme_packs.pack_table_problems` — and then
**Track B**. C stays blocked on the revised machinery/puzzle bounds; E
stays reserve.
