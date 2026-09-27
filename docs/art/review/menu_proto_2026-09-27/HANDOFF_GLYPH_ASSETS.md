# A2 menu prototype — Glyph asset requirements

*Arty, art lane — 2026-09-27*

**Status: for owner review, before any production integration.** This
document covers what the prototype needed from the Glyph text face and
symbol set, what was added, and what Production's own on-screen strings
still need. Every entry is cited to the source line that uses it, at the
stable checkpoint CK9 `a2b9df6`.

**Rules kept.**

- No binding was changed. No string's meaning was altered to get round a
  missing glyph.
- Production's circuit colours are not redefined.
- Every asset is regenerated from source, not hand-edited:
  - authoring: `GLYPH_ROOT=/home/user/glyph-trial python3 tools/glyphui/author_text.py`
    and `author_icons.py`;
  - verifiers: `tools/content/run_font_import.sh` and
    `tools/content/run_ui_icons.sh`.

---

## 1. The text face — added in this pass (commit `48e6b76`)

| Char | Why | Where Production shows it |
|---|---|---|
| `;` | owner-requested | `epsilon_voice.gd:72` ("…Stay as long as you like; I am not going anywhere."), and 118 more string uses |
| `—` | owner-requested | `echo_lab.gd:258` ("NEW MECHANIC DETECTED — TEST CHAMBER UPDATED"); `equipment_face.gd:498,501` ("refused — …", "not sent — …"); `main_menu.gd:98`; 80 string uses |
| `→` | owner-requested | `effect_summary.gd:39` ("%s → %s (%s)"); `equipment_face.gd:482` ("→ %s: sent, waiting for the bridge") |
| `[` `]` | owner-requested | MapFace's own keys, `[` / `]` step place, as prompt keycaps; `equipment_face.gd:823` ("[%s] choose") |
| `°` | a unit Production prints | `effect_summary.gd:96` ("%.0f° arc"); `equipment_face.gd:894` (the unit list) |
| `×` | a product Production prints | `effect_summary.gd:107,117` ("%d pellets × %.0f damage") |
| `…` | an ellipsis Production prints | `hub.gd:585–586` ("reading the item pool…"); `pause_menu.gd:59` ("ABANDON ZONE…") |

The face is now **60 characters**. Two things check it:

- The font-import verifier (`tools/content/run_font_import.sh`) imports the
  face in Godot 4.5.1 with its metrics.
- The prototype reports any character a face asks for and lacks
  (`missing_where`). Both scripted tapes assert that nothing was missing.

## 2. Device symbols — added in this pass, each with a text fallback

These are the controls the prototype actually uses. With PROMPTS: TEXT
(Settings → REVIEW CONTROLS), every symbol shows its fallback in a keycap.
This is scripted-tested on both devices.

| Symbol | Fallback | Symbol | Fallback |
|---|---|---|---|
| `mouse_left` | LMB | `pad_face_south` | A |
| `mouse_right` | RMB | `pad_face_east` | B |
| `mouse_middle` | MMB | `pad_face_west` | X |
| `mouse_wheel` | WHEEL | `pad_face_north` | Y |
| `pad_dpad` | D-PAD | `pad_lb` / `pad_rb` | LB / RB |
| `pad_dpad_up` / `_down` | D-PAD UP / DOWN | `pad_lt` / `pad_rt` | LT / RT |
| `pad_dpad_left` / `_right` | D-PAD LEFT / RIGHT | `pad_lstick` / `pad_rstick` | L-STICK / R-STICK |
| `pad_start` | START | `pad_back` | BACK |
| `you` | YOU | | |

That is 21 device symbols plus `you`. The existing symbols gained fallbacks
too:

| Symbol | Fallback |
|---|---|
| arrows | UP / DOWN / LEFT / RIGHT (the font has no `_`, so `ARROW_UP` cannot be written) |
| `blocked` | SHUT |
| `circuit` | CIRCUIT |
| `control` | CONTROL |
| `exit` | WAY OUT |

The fallbacks live in `icons.json` (`text`), which is written by
`author_icons.py`.

**Limit:** the pad fallbacks name the Xbox layout (A, B, X, Y), which is
what Production's bindings use (`joy A` for `ui_accept`). Other pad
layouts are not covered.

## 3. Still required — Production's on-screen characters the face lacks

These were **not added**. They go beyond the four characters requested, so
they are listed for a decision. They come from a scan of every string
literal under `godot/scripts` at `a2b9df6`, narrowed by reading each line to
the strings that reach the screen. Identifiers, `find_children` patterns,
regexes and debug overlays are excluded.

### Punctuation and arrows (recommendation: add to the text face)

| Char | Where |
|---|---|
| `·` U+00B7 | `equipment_face.gd:631` (badges " · "), `:659`, `:668`, `:823`; `counterfire_arcade_room.gd:325` ("OPEN · %d s", a world sign); `resource_palette.gd:69` (the no-game source glyph) |
| `“` `”` U+201C/D | `equipment_face.gd:563` ("Nothing matches “%s”."); `hud.gd:294` (title note); `hub.gd:421` ("EPSILON: “%s”") |
| `←` U+2190 | `equipment_face.gd:721` (history line "%s  %s ← %s") |
| `↑` `↓` U+2191/3 | `slot_keycaps.gd:20–21` ("WHEEL↑", "WHEEL↓", keycaps for wheel bindings) |
| `` ` `` backtick | `main_menu.gd:98` ("BRIDGE OFFLINE — start it with `make bridge`"). The line itself is also a candidate for rewording, which is Production's call. |

### Status marks (recommendation: symbols in the Glyph set, with fallbacks)

| Char | Where | Suggested fallback |
|---|---|---|
| `✓` U+2713 | `equipment_face.gd:495` (the bridge confirmed it) | OK |
| `✗` U+2717 | `equipment_face.gd:498,501` (refused, not sent) | NO |
| `✕` U+2715 | `equipment_face.gd:444` (the drop button); `hud.gd:116` (confirm mark) | DROP / X |
| `▸` `▾` U+25B8/BE | `equipment_face.gd:712` (HISTORY ▸/▾); `hud.gd:588` (highlighted slot) | MORE / LESS, `>` |
| `★` `☆` | `equipment_face.gd:782` ("★ WHEEL", favourite) | SET / UNSET |

### HUD geometry (recommendation: sprites, not text)

| Char | Where |
|---|---|
| `▶ ◢ ▼ ◣ ◀ ◤ ▲ ◥` | `hud.gd:33`, damage-direction chevrons by octant |
| `▲` | `hud.gd:207`, the hit marker at font size 34 |
| `◆` | `hud.gd:386`, the waypoint |
| `◆ ▲ ■ ● ★ ◇ △ □ ○ ☆ ✦ ❖ ⬢ ⬟ ✚ ✜` | `resource_palette.gd:70–71`, 16 per-game source glyphs. This is a **shape-identity** set: it wants the same "told by shape, not hue" treatment as the circuits. |
| `▓ ▒ ░` (plus `# & @`) | `hub.gd:724`, a signal-garble effect. It could be drawn from the text face as block glyphs. |

**Not needed on screen so far:** `_` (all 2,967 uses are identifiers and
keys), `*` (only `find_children` patterns), `=`, `|`, `{ }`, `\` and `$`
(code, regex and debug strings).

## 4. Circuit symbols — provisional

MapFace's blockers carry a `symbol` letter. The prototype maps each letter
to an art-lane symbol, drawn on the gate in the circuit's own colour and
repeated on the thread's bead:

| Letter | Symbol |
|---|---|
| K | `blocked` |
| P | `circuit` |
| M | `control` |

These three symbols are **provisional art-lane candidates**, not approved.

## 5. Focus, circuit and player location — told apart by shape and placement

| Mark | Shape | Placement | Colour |
|---|---|---|---|
| Focus | a frame round the picked room; in lists, a bar down the focused item's left edge | on the thing focused | SIGNAL |
| Circuit identity | the circuit's symbol | on its gate, and on the thread's bead | the circuit's (Production's) |
| Player location | the standing figure, plus the YOU tag | in your room; the tag beside the figure | INK |
| The Journal's link | a ring of 18 dots | round the linked gate or room | INK |

**The one colour risk, flagged and not changed:** `span_alignment`
`#4de6f2` is ΔE2000 **10.1** from SIGNAL `#39d7c8`, a near-twin. Shape keeps
them apart: focus is a frame, and a circuit is a symbol on a gate. Whether
to separate them by hue as well is Production's decision.

## 6. Reduced motion covers secondary motion

In the prototype, `Kit.still()` holds every self-driven motion under
reduced motion: the gate pulse, and the thread's cast. The scripted tapes
check that the pulse stays at exactly 1.0 at two different times.

**Carried into the Production handoff:** MapFace's own `_pulse()` ignores
reduced motion (`HANDOFF_STATE_TRANSITIONS.md` §6.1 has the finding and a
suggested shape).
