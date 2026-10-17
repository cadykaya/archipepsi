# The four tooling follow-ups, FU-1 to FU-4: two fixed, two written up as decisions

*Arty — 2026-10-17*

**Assigned by** Condi on 2026-10-17, as her small call while the sheets wait for Skyiah: *"scripts and text only, with tests where the art check has them … if one turns out to need a decision, write it up and move to the next."* The follow-ups were named on 2026-09-28 (`docs/art/review/repairs_2026-09-28/README.md`, "Named follow-ups").

| | What | Outcome |
|---|---|---|
| **FU-1** | theme-bind fails against pinned Production | **Fixed.** Passes at the pin and at the default ref; output is byte-identical to the committed evidence. |
| **FU-2** | runners clear `godot/_harness`, whoever owns it | **Fixed.** All 41 claim it or stop. A new test is wired into the art check. |
| **FU-3** | the plate's nose wedge slopes the wrong way | **A decision.** The one-line fix changes a committed model, and it moves the plate's lightened panel too. |
| **FU-4** | hex colours go straight into the linear base colour | **A decision**, as the 09-28 handoff already said. Quantified below. |

Nothing in `assets/` changed. Nothing of Prod's was edited.

## FU-2: the runners claim the harness instead of clearing it

**Before.** 41 runners opened with `cleanup; mkdir -p "$H"`. The 09-28 note counted 42; one of them, `run_platform_proof.sh`, had already been guarded. That opening deletes `godot/_harness` whoever owns it: another runner halfway through, or someone's hand-staged copy. `run_course_ruling.sh` did the same to a scratch folder under `assets/textures/`.

**Now.** `claim_harness` is in `tools/content/godot_run.sh`, and every runner already loads that file. It is the 09-28 repair runners' guard, written once:
- each folder is made with a plain `mkdir`, so a folder that already exists is somebody else's;
- in that case the runner stops with status 2 and touches nothing;
- it releases only the folders it claimed itself;
- claimed folders are removed on any exit, including HUP, INT and TERM.

The trade-off is stated in the code: a folder left behind by a run that was killed with `-9` now has to be removed by hand.

**The test.** `tools/content/test_harness_claim.sh` runs in a temp copy with a stub Godot, and is wired into `check_art_current.sh`:
1. **Static:** all 45 runners claim the harness, and none still opens with the old pattern.
2. **Foreign folder:** with a sentinel planted in `_harness`, all 45 stop. The stub Godot is never called, and the sentinel's bytes are unchanged. One runner is also checked for the exact status 2 and message.
3. **Own folder:** with nothing there, a runner claims the folder, Godot sees it, and it is removed afterwards.
4. **Signal:** a TERM sent while Godot is running exits 143 and removes the folder.
5. **Partial claim:** if the second of two folders is taken, the first is released, the second is untouched, and the status is 2.

**Sabotage check.** I put one runner back to the old opening and re-ran the test. It failed twice for that runner: the static check, and *"changed somebody else's harness"*. The runner was then restored.

*Reported against myself:* the test's first draft matched its own `H=` line, ran itself recursively, and filled `/tmp` with temp trees before I stopped it. All the trees were removed, and nothing outside `/tmp` was touched. It now matches only `H="$ROOT/godot/_harness"` and excludes itself by name.

## FU-1: theme-bind compiles against pinned Production

**Before.** At `c12a72f`, Production's `theme_pack.gd` defines `UNIVERSAL_ROLES` and `PACK_TABLE` as `Constants.*` autoload references, and a `-s` harness has no autoloads.
- Reproduced tonight: *"Cannot infer the type of 'PACK_TABLE' constant"*.
- Godot then **hung until the runner's 300 s deadline** instead of failing. `godot_run.sh` reported that correctly.

**Fix.** `run_theme_bind.sh` already bound `theme_materials.gd`'s cross-references to preloaded copies of Production's own files. `theme_pack.gd` now gets the same transform (`bind_refs`):
- `Constants.` points at the preloaded `constants.gd`;
- nothing is retyped, and the values are still read from Production;
- binding a file that names no constants changes nothing.

**After.**

| | Result | Against the committed evidence |
|---|---|---|
| pin `c12a72f` | **PASS** | all three JSONs byte-identical |
| default ref `19c5d8e` | **PASS** | byte-identical (`binding_whole.json`, `control_missing_required.json`, `render.json`) |

The gate already runs in `check_art_current.sh`, so its before and after at the pin are the test.

## FU-3: the plate's nose wedge. A decision for Skyiah or Condi

**The defect.** `phys_plate`'s `pl_nose` uses `wedge`'s default `axis="y"`. So it slopes across the plate's **width**, rather than chamfering the **leading edge** its docstring promises ("a chamfered leading edge so it reads as something that goes down across a gap").

**The fix is one line:** `rotation_z=180.0, axis="x"`, so the high side meets the slab and the low edge is the tip.

**Why I didn't apply it.** It is not scripts and text. I built it once, measured it, and restored the committed files:
- **`phys_plate.glb` changes.** Same 92 triangles, same 1.80 × 0.92 × 0.145 m bounds, same file size, different bytes. That is a regenerated binary in git, under the git-space rule.
- **A knock-on change.** The plate's **lightened panel** is placed automatically on the best clear face, and it **moves**: from the +X end face (runtime `(0.689, 0.075, 0.13)`) onto the **top** (`(0, 0.089, 0.23)`), between the two lifting slots. That is a visible change on an object whose top is its handling face.

**To decide:**
- (a) Apply the fix, and accept or re-place the panel.
- (b) Apply it and pin the panel to the end face.
- (c) Leave the plate as it is, and correct the docstring to describe what it is.

The plate is in Batch 043, which is still pending review.

## FU-4: the hex-colour convention. A decision, as recorded on 09-28

**What happens.** Art-lane hex values (`palette.rgba`) go **straight into the linear base colour**, so every flat colour exports lighter than its hex would be in sRGB:
- `#4a5058` (the panel grey) is written as linear `0.290 / 0.314 / 0.345`, and displays as about **`#93989f`**;
- `#808080` displays as about **`#bcbcbc`**.

Five manifests carry hex values: batches 022, 043, 063, 064 and 065. A runtime that restores a manifest hex as sRGB, such as `at_rest`, would draw it **darker** than the exported material.

**The options, unchanged from 09-28:**
1. **Say "linear" wherever a manifest carries hex.** A text change; no colour changes. It is cheap, and it is honest about what ships.
2. **Convert once in `palette.rgba`.** Every flat colour in the library goes darker, and every asset rebuilds. **Not proposed:** the library's colours are approved as they look.

If a pick comes back for option 1, it is a text-only pass, and I can do it next.

## Found on the way: the art check had been red since the weapon work

Running the full `check_art_current.sh` at this stage boundary turned up **four FAILs that predate this work**. They are the art lane's own, from 10-13/10-14:
- `build_bulkhead_concepts`
- `build_foundry_study`
- `build_weapon_forms`
- `build_weapon_model`

None of them is in the check's rebuild list. Everything else passed, and every rebuilt asset was byte-identical.

**Why they can't simply be added to the list.**
- They are multi-stage **study pipelines** that write only to an OUT folder they are given. `build_foundry_study.py` says *"written outside `assets/`"*.
- Their committed record is review images, so there is nothing in `assets/` for a rebuild to compare.
- None of them references `common.export_*`, `MODEL_DIR`, `TEXTURE_DIR` or `REPO_ROOT`.

**What I did.** I added a named `STUDIES` exemption to the guard, and the exemption is itself checked. Tested in isolation against a copy:

| Case | Result |
|---|---|
| An exempt study that can reach a shipped writer | **fails** |
| A name in `STUDIES` that no longer exists | **fails** |
| A new builder in neither list | **fails**, as before |
| As it is | silent |

New scratch-only work should be named `study_*.py`, as the Shunter and Bloom studies already are. I didn't rename these four: other scripts import them, and dated reports quote their names.

## How to re-run

```
tools/content/test_harness_claim.sh                 # FU-2
PROD_REF=c12a72f tools/content/run_theme_bind.sh OUT # FU-1 at the pin
tools/content/run_theme_bind.sh OUT                 # FU-1 at the default ref
tools/check_art_current.sh                          # everything, including both
```
