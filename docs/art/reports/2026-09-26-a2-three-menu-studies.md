# Track A2: three ways the menu can move

*Arty*

**Branch `claude/archipepsi-art`, PR #5. Three studies, for your
selection. Nothing is approved, and I have stopped here.** No
production-menu redesign has started, and neither have the Glyph
requirements nor the handoff. Those follow your choice.

In this archive:
* `review/` is `docs/art/review/menu_studies_2026-09-26/`.
  `review/README.md` is the review, study by study.
* Start with `review/leaf/motion.mp4`, `review/lens/motion.mp4` and
  `review/thread/motion.mp4`, about 9 s each.

| | Face | The idea |
| --- | --- | --- |
| **1 · LEAF** | Inventory | The thing opens where it is, and each row is a key. |
| **2 · LENS** | Map | The wall is a window. Focus moves; the rooms never do. |
| **3 · THREAD** | Journal → Map | A line on one wall points round the corner at its place on the next. |

## The decision I need

**Which idea, or ideas, to take further.** They are not exclusive.
LEAF and LENS are each a way to compose one face, and THREAD is a way
for faces to refer to one another. So your choice can be read in two
ways:
* one idea as the principle for every face;
* one idea per face, with THREAD as the link between them.

Please say which you mean, and name anything in a study that should
not survive the choice.

## Evidence scope

**Scripted input over Production's own sample data**, rendered by an
isolated art-lane prototype in Godot 4.5.1:
* at 1920 × 1080, with Production's menu box at Production's numbers;
* in two runs per study: motion, and reduced motion.

It is **not** Production's runtime and **not** integrated gameplay, and
nobody has played it by hand with a mouse or a pad. The numbers it
reports are about the captures: frame counts, settle times, and how
the two runs' settled frames differ.

## What you asked for, and where it is

**Groundwork first.** I read Production's current menu and its
inventory and map contracts, read-only, at **`3b96bc4`**
(`origin/claude/archipepsi-0-4-blindside`, "CK8 checkpoint: 92 of 92").

Files read:
* the menu: `menu_shell.gd`, and the four faces (`equipment_face.gd`,
  `map_face.gd`, `journal_face.gd`, `settings_face.gd`, with
  `pause_menu.gd`);
* the queries: `equipment_query.gd`, `journal_query.gd`,
  `minimap_model.gd`, `equip_requests.gd`, `equipment_seen.gd`;
* the settings: `player_settings.gd`;
* the Python contracts `inventory_view.py`, `map_view.py` and
  `gear.py`;
* the fixtures `equipment_snapshot.json`, `map_snapshot.json`,
  `journal_snapshot.json` and `candidate_zone.json`.

**The equipment vocabulary is NOT missing.** I re-checked it, and the
blocker is not carried forward.
* The five keys are there (`SLOT_NAMES`: echo_a, echo_b, mobility,
  utility, consumable), and so are the four Gear territories (HEAD,
  TORSO, ARMS, LEGS).
* What does not exist yet is a Gear piece: `SUPPORTED_GEAR_DOMAINS` is
  empty.
* So no study draws the territories, and none invents a slot or a
  state.

**Three genuinely different studies**, with Map covered by LENS,
Inventory by LEAF, and a cross-face link in THREAD:

| What you asked for | How |
| --- | --- |
| Motion, in a small art-lane prototype | `tools/menu_studies/` runs in `godot/_harness`, which is deleted after every run. Production's menu files are untouched. |
| Short captures | An MP4 per run, about 9 s, 30 fps, full size. Also a half-size animated preview. |
| A reduced-motion / resting view alongside | `reduced.mp4`, plus `settled.png`: every settled moment, motion beside reduced. |
| Rest, select with useful information, change, adjacent face, return | Each capture shows all five, and each is also a full-size still. |
| The map stays the main content | LENS: at rest the Zone fills the face. The only panel is a card, and it exists only while a place is picked. |
| Real data shapes, labelled sample data | Every word comes from Production's own code on Production's own fixtures, extracted by `extract_sample.sh`. Every frame says SAMPLE DATA. |
| Truthful connectivity | LENS moves the miniature only as one rigid thing. THREAD lands on the passage its line names, because they are the same record from the same save. THREAD's thread is drawn so that it cannot pass for a route. |
| Existing Glyph work where useful | The text faces, keycaps, page arrows and map symbols. New pieces only where an interaction needs them, all in flat colour. |
| Readable at gameplay size | 2× Glyph on the walls. The MP4s and stills are 1:1. |
| Mouse and controller focus | LEAF shows keys and pad. LENS shows the mouse, then the pad, with the prompts following the device. THREAD shows the mouse, plus E/Q. |
| No drifting controls | LENS zooms around the pointer. THREAD moves nothing on the wall. **LEAF's mouse variant must not slide its row**; it is flagged in the README. |
| Interruptible; no cinematic | Every change animates from where things are *now*. The longest settle is 0.6 s. |
| Reduced motion keeps the same information and actions | The same steps at the same times, cut. It is measured below. |

**Reduced motion, measured.** The difference between each settled frame
of the motion run and the same frame of the reduced run, below the
caption band:

| Study | rest | select | change | adjacent | return |
| --- | --- | --- | --- | --- | --- |
| **LEAF** | identical | identical | identical | identical | identical |
| **LENS** | 0.024 / 0.017% | identical | 0.163 / 0.112% | identical | 0.068 / 0.047% |
| **THREAD** | identical | identical | identical | identical | identical |

Each cell reads *mean absolute difference (0–255) / share of pixels
more than 8 levels apart*. "Identical" means not one pixel differs.

**LEAF and THREAD are identical at every moment.** **LENS differs only
at its gate marks**, and `lens/differs/` shows them in red. The motion
run's gates pulse at Production's 1.2 Hz, and reduced motion holds them
still at the same size and emphasis. That is the one difference the
study intends. Nothing else differs: no room, no card, no text.

## Found on the way

The detail is in the README, under "Found on the way". In short:

* **Glyph gaps, found by Production's own strings.**
  * `ui_text` has no `;` `—` `→` `[` `]`. The studies show stand-ins.
    `[` and `]` are `MapFace`'s own keys for the next and previous
    place.
  * There are no mouse or pad symbols, so the keycaps spell them out.
  * The circuit letters K, P and M are mapped provisionally to Glyph
    symbols.
* **Signal has a near twin.** The provisional `state:span_alignment`
  colour, #4de6f2, is ΔE2000 10.1 from signal. The next closest circuit
  colour is 21.8.
* **For Production, at handoff time.** `MapFace._pulse` does not
  consult reduced motion; only `MenuShell`'s turn reads
  `motion_intensity`.

## What I did not do

* I edited no Production-owned file. I started and messaged no other
  session. Watchers, subscriptions and scheduled work stay off.
* I did not start the full production-menu redesign, the Glyph
  requirements or the state/transition handoff. Those wait for your
  choice.
* I did not open 0.5, Track C or Track E.

## Checks

* **`tools/check_art_current.sh` passes on this tree**, with its engine
  checks run in Godot 4.5.1: "every generated asset matches its
  source". It changed nothing. The studies are not in the suite; like
  every review sheet, they are renders, rebuilt by their own runner.
* **The studies' own checks:**
  * A study script that does not compile stops the run.
  * An assembly with a missing frame, or with the two runs disagreeing
    on their stills, stops.
  * Every README link resolves (21 of 21).
* **The packaging check**, `tools/art_package.sh`, now counts MP4 and
  WebP, and matches each file by its path, not its basename. Several
  study folders share names, so a basename match could have let one
  study's file stand in for another's missing one.

## Commits

* `14da706`: the sample data, answered by Production's own code.
* `370a683`: the packaging check, for moving captures and by path.
* The commit carrying this report: the prototype, the three studies'
  captures, the review, the frontier and three lessons.
